; started: 8/13/18 
; last edit: 4/30/23 
<CsoundSynthesizer> 
 
<CsOptions> 
; use the following for writing to a file -G is to create a postscript eps output file of function tables 
; -o dac ; live play 
 -o Music/sflib/ball9.wav -W -G -m2 -3 
</CsOptions> 
 
<CsInstruments> 
 giMoved = 0 
 ; I changed the sample rate to the maximum, 24 bit audio -3 option 
 ; sr = 192000 ; my laptop audio supports this high sample rate, but not the docking station 
 sr = 44100 
 ksmps = 5; any higher than 10 and I hear clicks - use 1 for final take 
 ; typically save 5x processing time by increasing ksmps by 10x 
 nchnls = 2 
 instr 1 
 
; p1 is always 1 
; p2 start time 
; p3 duration 
; p4 velocity, 60-80 works best 
; p5 tone - which tone is this note - 1-1200 for cents 
; p6 Octave 
; p7 voice 
; p8 stereo - pan from left = 0 to right = 16 
; p9 envelope - one of several function tables for envelopes 1 - 16 
; p10 glissando - one of several function tables to modify pitch 
; p11 upsample - use a sample higher (>0) or lower (<256) than normal 
; p12 envelope for right channel - if blank, use the left channel envelope for both channels 
; p13 2nd glissando 
; p14 3rd glissando 
; p15 volume 
; 
 if p4 = 1 goto skipVel 
; 
; ; table f2 has the iSampleType values indicating type of sample 
 iSampleType table p7,2 ; from McGill.dat col 6 1: mono 2: stereo 4: Akai MDF??? 5: Gigasample 
; 
 iVelTemp = (p4 > 90 ? 90 : p4) ; make sure p4 velocity not greater than 90 
 iVel = (iVelTemp < 50 ? 50 : iVelTemp) ; nor less than 50 
 iVel = p4
 iVoicet = (iSampleType = 5 ? (p7 + (iVel - 60)/2) : p7) ; alter voice if SampleType is 5, otherwise don't touch it 
 iVoice = round(iVoicet) 
; 
; table f1 has the start location of the sample tables control functions 
 iSampWaveTable table iVoice,1 ; find the location of the sample wave tables base on input p7 
 ipitch table p5, 3 ; look up the cent value in ftable 3 a table of 1200 values from 0.001 to 0.120 
 ioct = p6 ; convert from my octave form to midi standard 
;  iRatioFromCent = cent(p5) ; convert cents to ratio to be multiplied by a base frequency 
 ; 
 iMIDInumber = round(p5 / 100) + (12 * ioct) ; cent value, i.e. 386/100 = rounds to 4 + (12 * 2) = 28. iMIDInumber = 28 for an E 
 ; 
 iFtableTemp table iMIDInumber, iSampWaveTable ; map midi note number to the correct ftable for that note 
 iFtable = iFtableTemp + p11  ; up or down sample by parameter 11 
; The next section added on 5/4/22 to ensure that a sample file out of range is not selected. 
 iLength ftlen iSampWaveTable ; length of the table (128). How many steps it could hold. 
 indx = 0 
 iLowValue table indx, iSampWaveTable 
 iHighValue table iLength, iSampWaveTable 
 loop: 
 iCurValue table indx, iSampWaveTable 
 if iFtable == iCurValue goto iFound ; found the required sample file in the list of sample files, not out of range
 loop_lt indx, 1, iLength, loop ; this is basically a conditional goto statement 
; it's not in the list of valid samples. It could be too low or too high - for now reset it to what it originally was 
; before it went too far 
; if the upsample went to a higher sample file, set it to the maximum in the table 
 giMoved = giMoved + 1 
 ; printf_i "upsample tried to move sample out of range of available samples. originally %i requested %i. declined\n", 1, iFtableTemp, iFtable
 if iFtable > iFtableTemp then 
 iFtable = iHighValue 
 else 
 iFtable = iLowValue 
 endif 
; printf_i "switched to %i. giMoved now: %d\n", 1, iFtableTemp , giMoved 
;                ivoice,          iFtableTemp    iFtable             giMoved   always print
;                  +                        +     +                       +     +
 if iFtable != iFtableTemp then
 printf_i "voice: %i. switched sample from %i to %i. Total moved so far: %i\n", 1, iVoice, iFtableTemp, iFtable, giMoved 
 else
 printf_i "voice: %i. no switch %i == %i\n", 1, iVoice, iFtableTemp, iFtable
 endif

 iFound: 
 
 iamp = ampdb(iVel) * p15 / 5 ; velocity input is 60-80 - convert to amplitude 
 ; End of modification 5/4/22 
 i9 = 298-p9 ; valid envelope table number are 298, 297, 296, 295 etc. - left channel 
 i12 = 298-p12 ; valid envelope table number are 298, 297, 296, 295 etc. - right channel 
 i10 = p10 ; glissando #1 
 i13 = p13 ; valid glissando table number are 1500 since 4/28/23 and are listed with those numbers 
 ; print p10, i10 
 kamp_l oscil iamp, 1/p3, i9 ; create an envelope from a function table for left channel 
 kamp_r oscil iamp, 1/p3, i12 ; create an envelope from a function table for right channel 
 kpan_l tablei p8/16, 4, 1,0,1 ; pan with a sine wave using f table #4 - 2st value is reduced to max 1, normalized 
 kpan_r tablei 1.0 - p8/16, 4, 1,0,1 ; inverse of kpan_l 
 ibasno table iFtable-(3+iSampWaveTable), 1 + iSampWaveTable ; get midi note number the sample was recorded at 
 icent table iFtable-(3+iSampWaveTable), 2 + iSampWaveTable ; get cents to flatten each note 
 iloop table iFtable-(3+iSampWaveTable), 3 + iSampWaveTable ; get loop or not 
 ibasoct = ibasno/12 ; find the base octave 
 ibascps = cpsoct(ibasoct+(icent/1200)) ; flatten amount in icent table 
 ;
 inote = cpspch(ioct + ipitch) ; note plus the decimal fraction of a note from table 
 kcps = cpspch(ioct + ipitch) ; convert oct.fract to Hz at krate 
 if i10 > 0 then ; if glissando #1 is not zero, shift the note by the value of the gliss 
 kcpsm oscili 1, 1/p3, i10 ; create an set of shift multiplicands from table - glissandi 
 kcps1 = kcps * kcpsm ; shift the frequency by values in glissando table 
 else 
 kcps1 = kcps 
 endif 
 if i13 > 0 then ; glissand #2 if not zero cause it to shift the note a second time. 
 kcpsm2 oscili 1, 1/p3, i13 ; create a 2nd set of shift multiplicands from table - glissandi 2 
 kcps2 = kcpsm2 * kcps1 ; shift the frequency by values in 2nd glissando table 
 else 
 kcps2 = kcps1 
 endif 

 ; print p5, ioct, iMIDInumber, iFtable, iSampleType, iloop 
 if iSampleType = 4 goto akaimono 
 if iSampleType = 1 goto noloopm 
 if iloop = 0 goto noloops 
 ; Stereo with loop 
 a3,a4 loscil 1, kcps2, iFtable, ibascps; stereo sample with looping 
 goto skipstereo 
 noloops: 
 ; Stereo without looping - something has happened here between csound 6.4 and 6.11 
 a3,a4 loscil 1, kcps2, iFtable, ibascps, 0, 1, 2 ; stereo sample without looping - note that 1,2 is l 
 goto skipstereo 
 akaimono: 
 if iloop = 0 goto noloopm 
 ; Mono with looping 
 a3 loscil 1, kcps2, iFtable, ibascps ; mono sampling with loop - 
 a4 = a3 
 goto skipstereo 
 noloopm: 
 ; Mono without looping 
 a3 loscil 1, kcps2, iFtable, ibascps,0,1,2 ; mono AIFF sample without loop 
 a4 = a3 
 
 skipstereo: 
 a1 = a3 * kamp_l 
 a2 = a4 * kamp_r 
 ; 
 outs a1 * kpan_l ,a2 * kpan_r 
 skipVel: 
 endin 
 
</CsInstruments> 
 
<CsScore> 
; cents for each step in the scale 
; 1200 edo in cents 
; simplified way to write this table: 
; f# time size 7 a n1 b n2 c ... 
; f3 0 12 -7 0 12 0.1200 
f3 0 1200 -7 0 1200 0.1200 
f4 0 1025 9 .25 1 0 ;The first quadrant of a sine for panning 
; end of function tables included in the .mac file. The rest are system generated to support sampling. 
; first table is a list of the function tables for the samples based on the midi number 
; +1 second is a list of midi numbers representing the base note of the sample files 
; +2 third is cent offset to flatten the note to the correct intonation 
; +3 fourth is loop or not 
f298 0 1025 6 0 1 .5 1 1 496 1 496 1 15 .5 15 0.0 ; e0 - Attack and sustain with a relatively sharp ending 
f297 0 1025 6 0 4 .5 4 1 500 1 500 1 4 .5 4 0.0 ; e1 - Attack and sustain with a relatively sharp ending 
;#5 0 siz exp start take reach take reach 
; lf296 0 512 5 1024 512 1 ; e2 - exponential - dead piano 
; +-- cubic polynomials 
; | +-- start at 0 
; | | +-- take 2 to reach 
; | | | +-- reach 1/2 volumelf296 
; | | | | +-- take 2 to full volume 
; | | | | | +-- reach full volume 
; | | | | | | +-- take 126 
; | | | | | | | +-- half point 
f296 0 256 6 0 2 .5 2 1 32 0.6 32 0.25 32 0.125 32 0.06 32 0.001 
; lf296 0 512 5 1024 512 1 ; e2 - exponential - dead piano 
;#6 0 siz exp min values mid val max val mid val min val mid val max val mid val min 
f295 0 1025 6 0 64 .5 64 1 128 .6 128 .3 128 .5 128 .6 192 .3 192 0 ; e3 big hump, small hump 
f294 0 1025 6 0 64 .15 64 .3 128 .25 128 .2 128 .6 128 1 192 .5 192 0 ; e4 small hump, big hump 
f293 0 1025 6 0 1 .5 1 1 447 .99 447 .98 64 0.5 64 0 ;e5 default woodwind envelope 
f292 0 1025 6 0 1 .5 1 1 447 0.60 447 0.20 32 0.21 32 0.22 32 0.11 32 0.00 ; e6 moving away slowly 
f291 0 1025 6 0 1 .5 1 1 128 0.60 128 0.20 256 0.15 254 0.10 128 0.05 128 0.00 ; e7 moving away faster 
;lf290 0 1025 6 0 2 .5 2 1 501 .6 483 .3 18 .15 18 0 ; e8 hit and drop most 
f290 0 256 6 0 1 .5 1 1 128 .5 126 0 ; e8 hit and drop most 
f289 0 1025 6 0 1 .3 1 .6 479 .8 479 1 32 .5 32 0 ; e9 Start moderately and build, abrupt end 
f288 0 1025 6 0 64 .40 448 1 448 .6 64 0 ; e10 One long hump in the middle 
; +-- cubic polynomials 
; | +-- start at 0 
; | | +-- take 1 to reach 
; | | | +-- reach 1/2 volume 
; | | | | +-- take 1 to full volume 
; | | | | | +-- reach full volume 
; | | | | | | +-- take 368 
; | | | | | | | +-- almost full volume 
; | | | | | | | | +-- take 368 
; | | | | | | | | | +-- almost full volume 
; | | | | | | | | | | +-- take 16 to reach 
; | | | | | | | | | | | +-- 1/2 volume 
; | | | | | | | | | | | | +-- take 16 to reach 
; | | | | | | | | | | | | | +-- zero 
; | | | | | | | | | | | | | | stay there till the end - csound pads with zeros automatically 
f287 0 1025 6 0 1 .5 1 1 368 .99 368 .98 16 .5 16 0 ; e11 hit and sustain 3/4 the normal length 
; 1 1 303 303 16 16 
f286 0 1025 6 0 1 .5 1 1 323 .99 323 .98 16 .5 16 0 ; e12 hit and sustain 2/3 the normal length 
f285 0 1025 6 0 1 .5 1 1 248 .99 248 .98 16 .5 16 0 ; e13 hit and sustain 1/2 the normal length 
f284 0 1025 6 0 1 .5 1 1 124 .99 124 .98 4 .5 4 0 ; e14 hit and sustain 1/4 the normal length 
f283 0 1025 6 0 1 .5 1 1 84 .99 84 .98 1 .5 1 0 ; e15 hit and sustain 1/5 the normal length 
f282 0 1025 6 0 2 .2 2 .4 477 .7 479 1 32 .5 32 0 ; e16 sustain piano sound 
f281 0 1025 6 0 1 .1 1 .2 479 .6 479 1 32 .5 32 0 ; e17 sustain guitar sound 
;lf280 0 1025 6 1 64 .7 64 .4 64 .4 64 .4 384 .7 352 1 16 .5 16 0 ; e18 Sharp attack, then less quiet, build to end 
; +-- cubic polynomials 
; | +-- start at 1 loudest with no normalization 
; | | +-- take 64 to reach .7 
; | | | +-- reach 1/2 way to target 
; | | | | +-- target .4 
; | | | | | +-- take 64 to stay at this level 
; | | | | | | +-- target .4 
; | | | | | | | +-- take another 64 to stay 
; | | | | | | | | +-- target .4 
; | | | | | | | | | +-- take 368 to reach 1/2 way to full volume 
; | | | | | | | | | | +-- 1/2 volume 
; | | | | | | | | | | | +-- take 368 to reach full volume 
; | | | | | | | | | | | | +-- full volume 
; | | | | | | | | | | | | | +-- take 16 to reach half way to zero 
; | | | | | | | | | | | | | | +-- half way to zero 
; | | | | | | | | | | | | | | | +-- take 16 to reach 0 
; | | | | | | | | | | | | | | | | +-- target zero 
f280 0 1025 6 1 64 .7 64 .4 64 .4 64 .4 368 .7 368 1 16 .5 16 0 ; e18 Sharp attack, then less quiet, build to end 
f279 0 1025 6 0 1 .5 1 1.0 128 .7 228 .4 128 .4 28 .4 128 .5 128 .6 128 .3 126 0 ; e19 Moderate attack, then slightly quiet, build to end 
f278 0 1025 6 0 85 0.40 85 0.80 85 0.65 85 0.50 85 0.75 85 1.00 85 0.75 85 0.50 85 0.65 85 0.8 85 0.4 89 0.0 ; e20 3 humps - biggest in middle 
f277 0 1025 6 0 85 0.50 85 1.00 85 0.75 85 0.50 85 0.65 85 0.80 85 0.65 85 0.50 85 0.65 85 0.8 85 0.4 89 0.0 ; e21 3 humps - biggest early 
f276 0 1025 6 0 85 0.40 85 0.80 85 0.65 85 0.50 85 0.65 85 0.80 85 0.65 85 0.50 85 0.75 85 1.0 85 0.5 89 0.0 ; e22 3 humps - biggest late 
f275 0 1025 6 0 1 0.01 84 0.80 84 0.65 84 0.50 84 0.75 84 1.00 84 0.75 84 0.50 84 0.65 84 0.8 84 0.4 183 0.0 ; e24 3 humps - early biggest in middle 
f274 0 1025 6 0 1 0.01 84 1.00 84 0.75 84 0.50 84 0.65 84 0.80 84 0.65 84 0.50 84 0.65 84 0.8 84 0.4 183 0.0 ; e24 3 humps - early biggest early 
f273 0 1025 6 0 1 0.01 84 0.80 84 0.65 84 0.50 84 0.65 84 0.80 84 0.65 84 0.50 84 0.75 84 1.0 84 0.5 183 0.0 ; e25 3 humps - early biggest late 
f272 0 1025 6 0 64 .5 64 1 256 1 512 1 64 .5 64 0 ; e26 slow rise, sustain, slow drop 
; min pts mid pts max pts mid pts min pts mid pts max pts mid pts min 
;p1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 ; 
f265 0 1025 6 0 32 0.20 32 0.40 32 0.30 32 0.20 432 0.60 432 1.00 16 0.50 16 0.00 ; e33 channel one moving in gradually 
f264 0 1025 6 0 206 0.03 206 0.06 205 0.06 205 0.05 85 0.53 85 1.00 16 0.50 16 0.00 ; e34 channel 2 moving in at the end 
;#6 0 siz exp min values mid val max val mid val min val mid val max val mid val min 
f263 0 1025 6 0 2 .2 2 .6 4 .4 4 .3 500 .6 500 1 6 .5 7 0 ; e35 low bass piano inverse of h48 and above 
f262 0 1025 6 0 2 .2 2 .6 4 .4 4 .3 500 .32 500 .33 6 .2 7 0 ; e36 low bass piano inverse of h48 
f261 0 513 5 1024 384 1 ; e37- exponential - dead piano 
; Orchestra: finger piano (112), bass finger piano (159), balloon drums (155, 156, 157), bass flute (96), oboe (10), 
; 9 10 11 
; clarinet (77), bassoon (71), french horn (102) 
; 
f601 0 128 -17 0 605 13 606 17 607 20 608 22 609 25 610 27 611 30 612 32 613 34 614 37 615 39 616 41 617 44 618 46 619 49 620 51 621 53 622 54 623 56 624 61 625 63 626 66 627 68 628 70 629 73 
f602 0 64 -2 0  12  16  19  21  24  26  29  31  33  36  38  40  43  45  48  50  52  53  55  60  62  65  67  69  72 
f603 0 64 -2 0 +0  -4  0   0   0   0   0   0   0   0   -3  +5  +1  0   -1  +1  +4  +6  -1  -1  -1  0   -2  0   -1  
f604 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
; Orchestra: 
; voices instrument csound samples # samples 
; finger_piano_part: McGill instrument number 
; 8 finger piano 1 25 112 
; 8 pizzicato 4 
; violin-pizz 1 19 57 
; viola-pizz 1 11 52 
; cello-pizz 1 14 74 
; 4 marimbas 1 18 8 
; 4 xylophone 1 20 65 
; 4 vibraphone 1 13 47 
; 4 harp 1 20 3 
; 8 martele strings 4 
; violin martele 1 17 56 
; viola martele 1 16 51 
; cello martele 1 20 73 
; woodwind_part: 
; 8 woodwinds 5 
; bassoon 1 6 71 
; clarinet 1 19 77 
; flute no vib 1 14 100 
; oboe 1 15 10 
; french horn 1 17 102 
; 8 bowed strings vib 4 
; violin 1 19 58 
; viola 1 18 53 
; cello 1 20 75 
; ------------------------------------------ 
; total samples 329 
; both parts: Wait a bit before adding the piano. It's terribly complicated and prone to untraceable errors. 
; 8 Bosendorfer 11 494 184 
; ------- 
; 823 samples in total f630 0 128 -17 0 634 44 635 48 636 50 637 52 638 54 639 56 640 58 641 60 642 62 643 64 644 66 645 68 646 70 647 72 648 74 649 76 650 78 651 80 
f630 0 128 -17 0 634 44 635 48 636 50 637 52 638 54 639 56 640 58 641 60 642 62 643 64 644 66 645 68 646 70 647 72 648 74 649 76 650 78 651 80 
f631 0 64 -2 0  43  47  49  51  53  55  57  59  61  63  65  67  69  71  73  75  77  79 
f632 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f633 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f652 0 128 -17 0 656 49 657 52 658 55 659 58 660 64 661 67 662 70 663 73 664 76 665 79 666 82 
f653 0 64 -2 0  48  51  54  57  63  66  69  72  75  78  81 
f654 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   
f655 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 
f667 0 128 -17 0 671 37 672 41 673 46 674 50 675 53 676 60 677 61 678 65 679 67 680 69 681 72 682 75 
f668 0 64 -2 0  36  40  45  49  52  59  60  64  66  68  71  74 
f669 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   
f670 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 
f683 0 128 -17 0 687 30 688 33 689 36 690 39 691 45 692 48 693 51 694 54 695 57 696 60 697 63 698 66 699 69 700 73 701 75 702 78 703 81 704 84 
f684 0 64 -2 0  29  32  35  38  44  47  50  53  56  59  62  65  68  72  74  77  80  83 
f685 0 64 -2 0 -4  +10 +2  +4  -1  -2  +8  +6  -2  -8  +5  +5  +3  +2  +9  +5  +4  +6  
f686 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f705 0 128 -17 0 709 54 710 56 711 58 712 60 713 62 714 64 715 66 716 68 717 70 718 72 719 74 720 76 721 78 722 80 723 82 724 84 725 86 
f706 0 64 -2 0  53  55  57  59  61  63  65  67  69  71  73  75  77  79  81  83  85 
f707 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f708 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f726 0 128 -17 0 730 42 731 46 732 50 733 52 734 55 735 58 736 61 737 64 738 67 739 71 740 74 741 78 
f727 0 64 -2 0  41  45  49  51  54  57  60  63  66  70  73  77 
f728 0 64 -2 0 +6  +4  +6  +4  +3  +2  +2  +2  +3  +3  +5  +4  
f729 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 
f742 0 128 -17 0 746 14 747 16 748 18 749 21 750 24 751 28 752 30 753 35 754 41 755 44 756 47 757 50 758 53 759 57 760 61 761 65 762 68 763 76 764 80 765 84 
f743 0 64 -2 0  13  15  17  20  23  27  29  34  40  43  46  49  52  56  60  64  67  75  79  83 
f744 0 64 -2 0 -28 -36 -22 0   -1  0   -2  -4  -2  -3  -4  +8  +2  -11 +5  -7  +2  -8  0   -21 
f745 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f766 0 128 -17 0 770 44 771 46 772 48 773 50 774 52 775 54 776 56 777 58 778 60 779 62 780 64 781 66 782 68 783 70 784 72 785 74 786 76 
f767 0 64 -2 0  43  45  47  49  51  53  55  57  59  61  63  65  67  69  71  73  75 
f768 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f769 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f787 0 128 -17 0 791 37 792 39 793 41 794 43 795 46 796 49 797 51 798 53 799 55 800 58 801 60 802 62 803 64 804 69 805 71 806 73 
f788 0 64 -2 0  36  38  40  42  45  48  50  52  54  57  59  61  63  68  70  72 
f789 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f790 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f807 0 128 -17 0 811 25 812 27 813 29 814 31 815 33 816 35 817 37 818 39 819 41 820 43 821 47 822 49 823 51 824 53 825 55 826 57 827 59 828 61 829 63 
f808 0 64 -2 0  24  26  28  30  32  34  36  38  40  42  46  48  50  52  54  56  58  60  62 
f809 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f810 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f830 0 128 -17 0 834 23 835 25 836 27 837 29 838 31 839 33 840 35 841 37 842 39 843 41 844 43 845 45 846 47 847 49 848 51 849 53 
f831 0 64 -2 0  22  24  26  28  30  32  34  36  38  40  42  44  46  48  50  52 
f832 0 64 -2 0 +3  +3  +10 +2  -2  +2  +2  -2  0   -4  -12 -8  +4  -3  -3  -2  
f833 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f850 0 128 -17 0 854 39 855 41 856 43 857 45 858 47 859 49 860 53 861 55 862 57 863 59 864 61 865 63 866 65 867 67 868 69 869 71 870 73 871 75 
f851 0 64 -2 0  38  40  42  44  46  48  52  54  56  58  60  62  64  66  68  70  72  74 
f852 0 64 -2 0 -1  +7  +4  +3  +5  -2  -3  -2  -3  +3  +2  -1  0   +1  +5  -1  0   -2  
f853 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f872 0 128 -17 0 876 49 877 51 878 55 879 59 880 65 881 70 882 72 883 74 884 76 885 78 886 80 887 82 888 84 889 85 
f873 0 64 -2 0  48  50  54  58  64  69  71  73  75  77  79  81  83  84 
f874 0 64 -2 0 0   -7  +12 +6  +1  -6  +2  +3  +6  +3  +3  +2  +3  +16 
f875 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f890 0 128 -17 0 894 47 895 49 896 51 897 53 898 55 899 57 900 59 901 61 902 63 903 65 904 69 905 71 906 73 907 75 908 77 
f891 0 64 -2 0  46  48  50  52  54  56  58  60  62  64  68  70  72  74  76 
f892 0 64 -2 0 -13 +5  +3  +5  +7  +10 -12 -6  +14 +6  +4  +1  +12 +12 +16 
f893 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f909 0 128 -17 0 913 27 914 29 915 31 916 33 917 35 918 39 919 41 920 43 921 45 922 47 923 49 924 51 925 53 926 55 927 59 928 61 929 63 
f910 0 64 -2 0  26  28  30  32  34  38  40  42  44  46  48  50  52  54  58  60  62 
f911 0 64 -2 0 0   +4  0   +3  -3  -5  +10 -3  -8  -8  -5   0  +5  -3  -5  +2  +2  
f912 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f930 0 128 -17 0 934 45 935 47 936 49 937 51 938 53 939 55 940 57 941 59 942 62 943 64 944 66 945 68 946 70 947 72 948 74 949 76 950 78 951 80 952 82 
f931 0 64 -2 0  44  46  48  50  52  54  56  58  61  63  65  67  69  71  73  75  77  79  81 
f932 0 64 -2 0 +18 +15 +15 +19 +18 +13 +12 +10 +27 +18 +12 +16 +29 +14 +3  +36 +25 +15 +21 
f933 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f953 0 128 -17 0 957 38 958 39 959 41 960 43 961 45 962 47 963 49 964 51 965 53 966 55 967 57 968 59 969 61 970 65 971 67 972 70 973 72 974 74 
f954 0 64 -2 0  37  38  40  42  44  46  48  50  52  54  56  58  60  64  66  69  71  73 
f955 0 64 -2 0 +3  -14 -7  +1  -18 +5  -9  +16 +4  +5  +9  +13 +7  +0  +8  +3  +5  -7  
f956 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f975 0 128 -17 0 979 26 980 28 981 30 982 32 983 34 984 36 985 38 986 40 987 42 988 44 989 46 990 48 991 50 992 52 993 54 994 56 995 58 996 60 997 62 998 64 
f976 0 64 -2 0  25  27  29  31  33  35  37  39  41  43  45  47  49  51  53  55  57  59  61  63 
f977 0 64 -2 0 2   3   0   -2  2   -1  0   7   6   8   0   7   -1  -6  -1  -9  -4  4   5   -31 
f978 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f999 0 128 -17 0 1003 24 1004 26 1005 28 1006 29 1007 31 1008 33 1009 34 1010 36 1011 38 1012 39 1013 41 1014 43 1015 45 1016 47 1017 48 1018 50 1019 52 1020 54 1021 56 1022 58 1023 60 1024 62 1025 64 1026 66 1027 68 1028 70 1029 72 
f1000 0 64 -2 0  23  25  27  28  30  32  33  35  37  38  40  42  44  46  47  49  51  53  55  57  59  61  63  65  67  69  71 
f1001 0 64 -2 0 -9  -7  -6  -15 -4  -7  -9  +2  -5  -9  -5  +3  -6  +5  -14 -1  -1  +25 +6  -7  +2  -1  -2  +0  -2  -6  +11 
f1002 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1030 0 128 -17 0 1034 29 1035 31 1036 33 1037 34 1038 36 1039 38 1040 39 1041 41 1042 43 1043 44 1044 46 1045 48 1046 49 1047 51 1048 53 1049 55 1050 57 1051 59 1052 61 1053 63 1054 65 1055 67 1056 69 1057 71 1058 73 1059 75 1060 77 1061 79 
  1062 81 1063 83 1064 85 1065 87 1066 91 1067 93 1068 95 1069 97 
f1031 0 64 -2 0  28  30  32  33  35  37  38  40  42  43  45  47  48  50  52  54  56  58  60  62  64  66  68  70  72  74  76  78  80  82  84  86  90  92  94  96 
f1032 0 64 -2 0 -9  0   -3  -4  -3  -10 -3  -4  -4  -6  0   -5  +1  -2  -5  -5  0   -2  0   0   0   +2  -2  -3  0   +1  -1  0   0   -13 -15 -29 -16 -47 +28 -37 
f1033 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1070 0 128 -17 0 1074 12 1075 13 1076 15 1077 17 1078 18 1079 20 1080 22 1081 24 1082 25 1083 27 1084 29 1085 30 1086 32 1087 34 1088 36 1089 37 1090 39 1091 41 1092 42 1093 44 1094 46 1095 48 1096 49 1097 51 1098 53 1099 54 1100 56 1101 58 
  1102 60 1103 61 
f1071 0 64 -2 0  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60 
f1072 0 64 -2 0 +1  +1  -3  -1  +1  -1  0   0   0   0   0   +2  +5  0   0   0   0   -2  -5  0   +1  -1  -1  0   0   -5  -5  0   +3  -3  
f1073 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1104 0 128 -17 0 1108 40 1109 41 1110 45 1111 46 1112 47 1113 48 1114 49 1115 50 1116 51 1117 52 1118 53 1119 55 1120 57 1121 59 1122 61 1123 63 1124 65 1125 67 1126 69 1127 72 1128 74 1129 76 
f1105 0 64 -2 0  39  40  44  45  46  47  48  49  50  51  52  54  56  58  60  62  64  66  68  71  73  75 
f1106 0 64 -2 0 -49 +56 -9  +23 +22 -5  +16 +10 -22 -17 -5  +2  -3  +2  -27 -30 -5  +6  -3  +10 -11 +0  
f1107 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1130 0 128 -17 0 1134 8 1135 9 1136 11 1137 13 1138 15 1139 20 1140 22 1141 25 1142 27 1143 29 1144 31 1145 34 1146 35 1147 37 1148 39 1149 42 1150 45 1151 47 1152 51 1153 55 1154 58 1155 63 
f1131 0 64 -2 0   7   8  10  12  14  19  21  24  26  28  30  33  34  36  38  41  44  46  50  54  57  62 
f1132 0 64 -2 0 +0  -31 -20 -16 +9  +18 +22 -11 -39 +12 +17 -33 -4  +16 +45 -31 +0  +43 -7  -1  +34 -41 
f1133 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1156 0 128 -17 0 1160 43 1161 45 1162 47 1163 49 1164 51 1165 53 1166 55 1167 57 1168 59 1169 61 1170 63 1171 65 1172 67 1173 69 1174 71 1175 73 1176 75 
f1157 0 64 -2 0  42  44  46  48  50  52  54  56  58  60  62  64  66  68  70  72  74 
f1158 0 64 -2 0 -2  0   +4  +9  -8  -2  +1  +3  +2  0   +1  +1  -3  +7  +2  +4  -2  
f1159 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f1177 0 128 -17 0 1181 29 1182 32 1183 35 1184 38 1185 41 1186 44 1187 47 1188 50 1189 53 1190 56 1191 59 
f1178 0 64 -2 0  28  31  34  37  40  43  46  49  52  55  58 
f1179 0 64 -2 0 0   -6  0   -8  -7  +4  -7  +6  +5  0   -5  
f1180 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 
f1192 0 128 -17 0 1196 25 1197 27 1198 30 1199 32 1200 34 1201 36 1202 38 1203 40 1204 42 1205 44 1206 46 1207 48 1208 50 1209 52 1210 54 1211 56 
f1193 0 64 -2 0  24  26  29  31  33  35  37  39  41  43  45  47  49  51  53  55 
f1194 0 64 -2 0 +6  +2  +5  0   +2  +3  +2  -6  +1  0   +2  +3  0   +2  +1  +4  
f1195 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f605 0 0 1 "samples/FingerP/c1.aif" 0 0 0
f606 0 0 1 "samples/FingerP/e1.aif" 0 0 0
f607 0 0 1 "samples/FingerP/g1.aif" 0 0 0
f608 0 0 1 "samples/FingerP/a1.aif" 0 0 0
f609 0 0 1 "samples/FingerP/c2.aif" 0 0 0
f610 0 0 1 "samples/FingerP/d2.aif" 0 0 0
f611 0 0 1 "samples/FingerP/f2.aif" 0 0 0
f612 0 0 1 "samples/FingerP/g2.aif" 0 0 0
f613 0 0 1 "samples/FingerP/a2.aif" 0 0 0
f614 0 0 1 "samples/FingerP/c3.aif" 0 0 0
f615 0 0 1 "samples/FingerP/d3.aif" 0 0 0
f616 0 0 1 "samples/FingerP/e3.aif" 0 0 0
f617 0 0 1 "samples/FingerP/g3.aif" 0 0 0
f618 0 0 1 "samples/FingerP/a3.aif" 0 0 0
f619 0 0 1 "samples/FingerP/c4.aif" 0 0 0
f620 0 0 1 "samples/FingerP/d4.aif" 0 0 0
f621 0 0 1 "samples/FingerP/e4.aif" 0 0 0
f622 0 0 1 "samples/FingerP/f4.aif" 0 0 0
f623 0 0 1 "samples/FingerP/g4.aif" 0 0 0
f624 0 0 1 "samples/FingerP/c5.aif" 0 0 0
f625 0 0 1 "samples/FingerP/d5.aif" 0 0 0
f626 0 0 1 "samples/FingerP/f5.aif" 0 0 0
f627 0 0 1 "samples/FingerP/g5.aif" 0 0 0
f628 0 0 1 "samples/FingerP/a5.aif" 0 0 0
f629 0 0 1 "samples/FingerP/c6.aif" 0 0 0
f634 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP G3.aif" 0 0 0
f635 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP B3.aif" 0 0 0
f636 0 0 1 "samples/VIOLIN-PIZZ/VIOLINPC#4.aif" 0 0 0
f637 0 0 1 "samples/VIOLIN-PIZZ/VIOLINPD#4.aif" 0 0 0
f638 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP F4.aif" 0 0 0
f639 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP G4.aif" 0 0 0
f640 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP A4.aif" 0 0 0
f641 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP B4.aif" 0 0 0
f642 0 0 1 "samples/VIOLIN-PIZZ/VIOLINPC#5.aif" 0 0 0
f643 0 0 1 "samples/VIOLIN-PIZZ/VIOLINPD#5.aif" 0 0 0
f644 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP F5.aif" 0 0 0
f645 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP G5.aif" 0 0 0
f646 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP A5.aif" 0 0 0
f647 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP B5.aif" 0 0 0
f648 0 0 1 "samples/VIOLIN-PIZZ/VIOLINPC#6.aif" 0 0 0
f649 0 0 1 "samples/VIOLIN-PIZZ/VIOLINPD#6.aif" 0 0 0
f650 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP F6.aif" 0 0 0
f651 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP G6.aif" 0 0 0
f656 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZC3.aif" 0 0 0
f657 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZD#3.aif" 0 0 0
f658 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZF#3.aif" 0 0 0
f659 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZA3.aif" 0 0 0
f660 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZD#4.aif" 0 0 0
f661 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZF#4.aif" 0 0 0
f662 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZA4.aif" 0 0 0
f663 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZC5.aif" 0 0 0
f664 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZD#5.aif" 0 0 0
f665 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZF#5.aif" 0 0 0
f666 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZA5.aif" 0 0 0
f671 0 0 1 "samples/CELLO PIZZ/P CELLOC2.aif" 0 0 0
f672 0 0 1 "samples/CELLO PIZZ/P CELLOE2.aif" 0 0 0
f673 0 0 1 "samples/CELLO PIZZ/P CELLOA2.aif" 0 0 0
f674 0 0 1 "samples/CELLO PIZZ/P CELLOC#3.aif" 0 0 0
f675 0 0 1 "samples/CELLO PIZZ/P CELLOE3.aif" 0 0 0
f676 0 0 1 "samples/CELLO PIZZ/P CELLOB3.aif" 0 0 0
f677 0 0 1 "samples/CELLO PIZZ/P CELLOC4.aif" 0 0 0
f678 0 0 1 "samples/CELLO PIZZ/P CELLOE4.aif" 0 0 0
f679 0 0 1 "samples/CELLO PIZZ/P CELLOF#4.aif" 0 0 0
f680 0 0 1 "samples/CELLO PIZZ/P CELLOG#4.aif" 0 0 0
f681 0 0 1 "samples/CELLO PIZZ/P CELLOB4.aif" 0 0 0
f682 0 0 1 "samples/CELLO PIZZ/P CELLOD5.aif" 0 0 0
f687 0 0 1 "samples/MARIMBA/MARIMBA F2.aif" 0 0 0
f688 0 0 1 "samples/MARIMBA/MARIMBAG#2.aif" 0 0 0
f689 0 0 1 "samples/MARIMBA/MARIMBA B2-f.aif" 0 0 0
f690 0 0 1 "samples/MARIMBA/MARIMBA D3-f.aif" 0 0 0
f691 0 0 1 "samples/MARIMBA/MARIMBAG#3-f.aif" 0 0 0
f692 0 0 1 "samples/MARIMBA/MARIMBA B3-f.aif" 0 0 0
f693 0 0 1 "samples/MARIMBA/MARIMBA D4-f.aif" 0 0 0
f694 0 0 1 "samples/MARIMBA/MARIMBA F4-f.aif" 0 0 0
f695 0 0 1 "samples/MARIMBA/MARIMBAG#4-f.aif" 0 0 0
f696 0 0 1 "samples/MARIMBA/MARIMBA B4-f.aif" 0 0 0
f697 0 0 1 "samples/MARIMBA/MARIMBA D5-f.aif" 0 0 0
f698 0 0 1 "samples/MARIMBA/MARIMBA F5-f.aif" 0 0 0
f699 0 0 1 "samples/MARIMBA/MARIMBAG#5.aif" 0 0 0
f700 0 0 1 "samples/MARIMBA/MARIMBA C6-f.aif" 0 0 0
f701 0 0 1 "samples/MARIMBA/MARIMBA D6-f.aif" 0 0 0
f702 0 0 1 "samples/MARIMBA/MARIMBA F6-f.aif" 0 0 0
f703 0 0 1 "samples/MARIMBA/MARIMBAG#6.aif" 0 0 0
f704 0 0 1 "samples/MARIMBA/MARIMBA B6-f.aif" 0 0 0
f709 0 0 1 "samples/XYLOPHONE/XYLO F4.aif" 0 0 0
f710 0 0 1 "samples/XYLOPHONE/XYLO G4.aif" 0 0 0
f711 0 0 1 "samples/XYLOPHONE/XYLO A4.aif" 0 0 0
f712 0 0 1 "samples/XYLOPHONE/XYLO B4.aif" 0 0 0
f713 0 0 1 "samples/XYLOPHONE/XYLO C#5.aif" 0 0 0
f714 0 0 1 "samples/XYLOPHONE/XYLO D#5.aif" 0 0 0
f715 0 0 1 "samples/XYLOPHONE/XYLO F5.aif" 0 0 0
f716 0 0 1 "samples/XYLOPHONE/XYLO G5.aif" 0 0 0
f717 0 0 1 "samples/XYLOPHONE/XYLO A5.aif" 0 0 0
f718 0 0 1 "samples/XYLOPHONE/XYLO B5.aif" 0 0 0
f719 0 0 1 "samples/XYLOPHONE/XYLO C#6.aif" 0 0 0
f720 0 0 1 "samples/XYLOPHONE/XYLO D#6.aif" 0 0 0
f721 0 0 1 "samples/XYLOPHONE/XYLO F6.aif" 0 0 0
f722 0 0 1 "samples/XYLOPHONE/XYLO G6.aif" 0 0 0
f723 0 0 1 "samples/XYLOPHONE/XYLO A6.aif" 0 0 0
f724 0 0 1 "samples/XYLOPHONE/XYLO B6.aif" 0 0 0
f725 0 0 1 "samples/XYLOPHONE/XYLO C#7.aif" 0 0 0
f730 0 0 1 "samples/VIBRAPHONE/VIBES F3.aif" 0 0 0
f731 0 0 1 "samples/VIBRAPHONE/VIBES A3.aif" 0 0 0
f732 0 0 1 "samples/VIBRAPHONE/VIBES C#4.aif" 0 0 0
f733 0 0 1 "samples/VIBRAPHONE/VIBES D#4.aif" 0 0 0
f734 0 0 1 "samples/VIBRAPHONE/VIBES F#4.aif" 0 0 0
f735 0 0 1 "samples/VIBRAPHONE/VIBES A4.aif" 0 0 0
f736 0 0 1 "samples/VIBRAPHONE/VIBES C5.aif" 0 0 0
f737 0 0 1 "samples/VIBRAPHONE/VIBES D#5.aif" 0 0 0
f738 0 0 1 "samples/VIBRAPHONE/VIBES F#5.aif" 0 0 0
f739 0 0 1 "samples/VIBRAPHONE/VIBES A#5.aif" 0 0 0
f740 0 0 1 "samples/VIBRAPHONE/VIBES C#6.aif" 0 0 0
f741 0 0 1 "samples/VIBRAPHONE/VIBES F6.aif" 0 0 0
f746 0 0 1 "samples/HARP/HARP C#1.aif" 0 0 0
f747 0 0 1 "samples/HARP/HARP D#1.aif" 0 0 0
f748 0 0 1 "samples/HARP/HARP F1.aif" 0 0 0
f749 0 0 1 "samples/HARP/HARP G#1.aif" 0 0 0
f750 0 0 1 "samples/HARP/HARP B1.aif" 0 0 0
f751 0 0 1 "samples/HARP/HARP D#2.aif" 0 0 0
f752 0 0 1 "samples/HARP/HARP F2.aif" 0 0 0
f753 0 0 1 "samples/HARP/HARP A#2.aif" 0 0 0
f754 0 0 1 "samples/HARP/HARP E3.aif" 0 0 0
f755 0 0 1 "samples/HARP/HARP G3.aif" 0 0 0
f756 0 0 1 "samples/HARP/HARP A#3.aif" 0 0 0
f757 0 0 1 "samples/HARP/HARP C#4.aif" 0 0 0
f758 0 0 1 "samples/HARP/HARP E4.aif" 0 0 0
f759 0 0 1 "samples/HARP/HARP G#4.aif" 0 0 0
f760 0 0 1 "samples/HARP/HARP C5.aif" 0 0 0
f761 0 0 1 "samples/HARP/HARP E5.aif" 0 0 0
f762 0 0 1 "samples/HARP/HARP G5.aif" 0 0 0
f763 0 0 1 "samples/HARP/HARP D#6.aif" 0 0 0
f764 0 0 1 "samples/HARP/HARP G6.aif" 0 0 0
f765 0 0 1 "samples/HARP/HARP B6.aif" 0 0 0
f770 0 0 1 "samples/VIOLIN-MART/VIOLINM G3.aif" 0 0 0
f771 0 0 1 "samples/VIOLIN-MART/VIOLINM A3.aif" 0 0 0
f772 0 0 1 "samples/VIOLIN-MART/VIOLINM B3.aif" 0 0 0
f773 0 0 1 "samples/VIOLIN-MART/VIOLINMC#4.aif" 0 0 0
f774 0 0 1 "samples/VIOLIN-MART/VIOLINMD#4.aif" 0 0 0
f775 0 0 1 "samples/VIOLIN-MART/VIOLINM F4.aif" 0 0 0
f776 0 0 1 "samples/VIOLIN-MART/VIOLINM G4.aif" 0 0 0
f777 0 0 1 "samples/VIOLIN-MART/VIOLINM A4.aif" 0 0 0
f778 0 0 1 "samples/VIOLIN-MART/VIOLINM B4.aif" 0 0 0
f779 0 0 1 "samples/VIOLIN-MART/VIOLINMC#5.aif" 0 0 0
f780 0 0 1 "samples/VIOLIN-MART/VIOLINMD#5.aif" 0 0 0
f781 0 0 1 "samples/VIOLIN-MART/VIOLINM F5.aif" 0 0 0
f782 0 0 1 "samples/VIOLIN-MART/VIOLINM G5.aif" 0 0 0
f783 0 0 1 "samples/VIOLIN-MART/VIOLINM A5.aif" 0 0 0
f784 0 0 1 "samples/VIOLIN-MART/VIOLINM B5.aif" 0 0 0
f785 0 0 1 "samples/VIOLIN-MART/VIOLINMC#6.aif" 0 0 0
f786 0 0 1 "samples/VIOLIN-MART/VIOLINMD#6.aif" 0 0 0
f791 0 0 1 "samples/VIOLA-MARTEL/VIOLAMC3.aif" 0 0 0
f792 0 0 1 "samples/VIOLA-MARTEL/VIOLAMD3.aif" 0 0 0
f793 0 0 1 "samples/VIOLA-MARTEL/VIOLAME3.aif" 0 0 0
f794 0 0 1 "samples/VIOLA-MARTEL/VIOLAMF#3.aif" 0 0 0
f795 0 0 1 "samples/VIOLA-MARTEL/VIOLAMA3.aif" 0 0 0
f796 0 0 1 "samples/VIOLA-MARTEL/VIOLAMC4.aif" 0 0 0
f797 0 0 1 "samples/VIOLA-MARTEL/VIOLAMD4.aif" 0 0 0
f798 0 0 1 "samples/VIOLA-MARTEL/VIOLAME4.aif" 0 0 0
f799 0 0 1 "samples/VIOLA-MARTEL/VIOLAMF#4.aif" 0 0 0
f800 0 0 1 "samples/VIOLA-MARTEL/VIOLAMA4.aif" 0 0 0
f801 0 0 1 "samples/VIOLA-MARTEL/VIOLAMB4.aif" 0 0 0
f802 0 0 1 "samples/VIOLA-MARTEL/VIOLAMC#5.aif" 0 0 0
f803 0 0 1 "samples/VIOLA-MARTEL/VIOLAMD#5.aif" 0 0 0
f804 0 0 1 "samples/VIOLA-MARTEL/VIOLAMG#5.aif" 0 0 0
f805 0 0 1 "samples/VIOLA-MARTEL/VIOLAMA#5.aif" 0 0 0
f806 0 0 1 "samples/VIOLA-MARTEL/VIOLAMC6.aif" 0 0 0
f811 0 0 1 "samples/CELLOMARTELE/CELLO M C2.aif" 0 0 0
f812 0 0 1 "samples/CELLOMARTELE/CELLO M D2.aif" 0 0 0
f813 0 0 1 "samples/CELLOMARTELE/CELLO M E2.aif" 0 0 0
f814 0 0 1 "samples/CELLOMARTELE/CELLO M F#2.aif" 0 0 0
f815 0 0 1 "samples/CELLOMARTELE/CELLO M G#2.aif" 0 0 0
f816 0 0 1 "samples/CELLOMARTELE/CELLO M A#2.aif" 0 0 0
f817 0 0 1 "samples/CELLOMARTELE/CELLO M C3.aif" 0 0 0
f818 0 0 1 "samples/CELLOMARTELE/CELLO M D3.aif" 0 0 0
f819 0 0 1 "samples/CELLOMARTELE/CELLO M E3.aif" 0 0 0
f820 0 0 1 "samples/CELLOMARTELE/CELLO M F#3.aif" 0 0 0
f821 0 0 1 "samples/CELLOMARTELE/CELLO M A#3.aif" 0 0 0
f822 0 0 1 "samples/CELLOMARTELE/CELLO M C4.aif" 0 0 0
f823 0 0 1 "samples/CELLOMARTELE/CELLO M D4.aif" 0 0 0
f824 0 0 1 "samples/CELLOMARTELE/CELLO M E4.aif" 0 0 0
f825 0 0 1 "samples/CELLOMARTELE/CELLO M F#4.aif" 0 0 0
f826 0 0 1 "samples/CELLOMARTELE/CELLO M G#4.aif" 0 0 0
f827 0 0 1 "samples/CELLOMARTELE/CELLO M A#4.aif" 0 0 0
f828 0 0 1 "samples/CELLOMARTELE/CELLO M C5.aif" 0 0 0
f829 0 0 1 "samples/CELLOMARTELE/CELLO M D5.aif" 0 0 0
f834 0 0 1 "samples/BASSOON/BASSOON A#1.aif" 0 0 0
f835 0 0 1 "samples/BASSOON/BASSOON C2.aif" 0 0 0
f836 0 0 1 "samples/BASSOON/BASSOON D2.aif" 0 0 0
f837 0 0 1 "samples/BASSOON/BASSOON E2.aif" 0 0 0
f838 0 0 1 "samples/BASSOON/BASSOON F#2.aif" 0 0 0
f839 0 0 1 "samples/BASSOON/BASSOON G#2.aif" 0 0 0
f840 0 0 1 "samples/BASSOON/BASS A#2.aif" 0 0 0
f841 0 0 1 "samples/BASSOON/BASS C3.aif" 0 0 0
f842 0 0 1 "samples/BASSOON/BASS D3.aif" 0 0 0
f843 0 0 1 "samples/BASSOON/BASS E3.aif" 0 0 0
f844 0 0 1 "samples/BASSOON/BASS F#3.aif" 0 0 0
f845 0 0 1 "samples/BASSOON/BASS G#3.aif" 0 0 0
f846 0 0 1 "samples/BASSOON/BASS A#3.aif" 0 0 0
f847 0 0 1 "samples/BASSOON/BASS C4.aif" 0 0 0
f848 0 0 1 "samples/BASSOON/BASS D4.aif" 0 0 0
f849 0 0 1 "samples/BASSOON/BASS E4.aif" 0 0 0
f854 0 0 1 "samples/B- CLARINET/CLARBB D3-f.aif" 0 0 0
f855 0 0 1 "samples/B- CLARINET/CLARBB E3-f.aif" 0 0 0
f856 0 0 1 "samples/B- CLARINET/CLARBB F#3-f.aif" 0 0 0
f857 0 0 1 "samples/B- CLARINET/CLARBB G#3-f.aif" 0 0 0
f858 0 0 1 "samples/B- CLARINET/CLARBB A#3-f.aif" 0 0 0
f859 0 0 1 "samples/B- CLARINET/CLARBB C4-f.aif" 0 0 0
f860 0 0 1 "samples/B- CLARINET/CLARBB E4-f.aif" 0 0 0
f861 0 0 1 "samples/B- CLARINET/CLARBB F#4-f.aif" 0 0 0
f862 0 0 1 "samples/B- CLARINET/CLARBB G#4-f.aif" 0 0 0
f863 0 0 1 "samples/B- CLARINET/CLARBB A#4-f.aif" 0 0 0
f864 0 0 1 "samples/B- CLARINET/CLARBB C5-f.aif" 0 0 0
f865 0 0 1 "samples/B- CLARINET/CLARBB D5-f.aif" 0 0 0
f866 0 0 1 "samples/B- CLARINET/CLARBB E5-f.aif" 0 0 0
f867 0 0 1 "samples/B- CLARINET/CLARBB F#5-f.aif" 0 0 0
f868 0 0 1 "samples/B- CLARINET/CLARBB G#5-f.aif" 0 0 0
f869 0 0 1 "samples/B- CLARINET/CLARBB A#5-f.aif" 0 0 0
f870 0 0 1 "samples/B- CLARINET/CLARBB C6-f.aif" 0 0 0
f871 0 0 1 "samples/B- CLARINET/CLARBB D6-f.aif" 0 0 0
f876 0 0 1 "samples/FLUTE NO-VIB/FLUTENV C3.aif" 0 0 0
f877 0 0 1 "samples/FLUTE NO-VIB/FLUTENV D3.aif" 0 0 0
f878 0 0 1 "samples/FLUTE NO-VIB/FLUTENVF#3.aif" 0 0 0
f879 0 0 1 "samples/FLUTE NO-VIB/FLUTENVA#3.aif" 0 0 0
f880 0 0 1 "samples/FLUTE NO-VIB/FLUTENV E4.aif" 0 0 0
f881 0 0 1 "samples/FLUTE NO-VIB/FLUTENV A4.aif" 0 0 0
f882 0 0 1 "samples/FLUTE NO-VIB/FLUTENV B4.aif" 0 0 0
f883 0 0 1 "samples/FLUTE NO-VIB/FLUTENVC#5.aif" 0 0 0
f884 0 0 1 "samples/FLUTE NO-VIB/FLUTENVD#5.aif" 0 0 0
f885 0 0 1 "samples/FLUTE NO-VIB/FLUTENV F5.aif" 0 0 0
f886 0 0 1 "samples/FLUTE NO-VIB/FLUTENV G5.aif" 0 0 0
f887 0 0 1 "samples/FLUTE NO-VIB/FLUTENV A5.aif" 0 0 0
f888 0 0 1 "samples/FLUTE NO-VIB/FLUTENV B5.aif" 0 0 0
f889 0 0 1 "samples/FLUTE NO-VIB/FLUTENV C6.aif" 0 0 0
f894 0 0 1 "samples/OBOE/OBOE A#3-f.aif" 0 0 0
f895 0 0 1 "samples/OBOE/OBOE C4.aif" 0 0 0
f896 0 0 1 "samples/OBOE/OBOE D4-f.aif" 0 0 0
f897 0 0 1 "samples/OBOE/OBOE E4-f.aif" 0 0 0
f898 0 0 1 "samples/OBOE/OBOE F#4.aif" 0 0 0
f899 0 0 1 "samples/OBOE/OBOE G#4-f.aif" 0 0 0
f900 0 0 1 "samples/OBOE/OBOE A#4-f.aif" 0 0 0
f901 0 0 1 "samples/OBOE/OBOE C5-f.aif" 0 0 0
f902 0 0 1 "samples/OBOE/OBOE D5-f.aif" 0 0 0
f903 0 0 1 "samples/OBOE/OBOE E5.aif" 0 0 0
f904 0 0 1 "samples/OBOE/OBOE G#5.aif" 0 0 0
f905 0 0 1 "samples/OBOE/OBOE A#5-f.aif" 0 0 0
f906 0 0 1 "samples/OBOE/OBOE C6-f.aif" 0 0 0
f907 0 0 1 "samples/OBOE/OBOE D6-f.aif" 0 0 0
f908 0 0 1 "samples/OBOE/OBOE E6-f.aif" 0 0 0
f913 0 0 1 "samples/FRENCH HORN/F.HORN D2.aif" 0 0 0
f914 0 0 1 "samples/FRENCH HORN/F.HORN E2.aif" 0 0 0
f915 0 0 1 "samples/FRENCH HORN/F.HORN F#2.aif" 0 0 0
f916 0 0 1 "samples/FRENCH HORN/F.HORN G#2.aif" 0 0 0
f917 0 0 1 "samples/FRENCH HORN/F.HORN A#2.aif" 0 0 0
f918 0 0 1 "samples/FRENCH HORN/F.HORN D3.aif" 0 0 0
f919 0 0 1 "samples/FRENCH HORN/F.HORN E3.aif" 0 0 0
f920 0 0 1 "samples/FRENCH HORN/F.HORN F#3.aif" 0 0 0
f921 0 0 1 "samples/FRENCH HORN/F.HORN G#3.aif" 0 0 0
f922 0 0 1 "samples/FRENCH HORN/F.HORN A#3.aif" 0 0 0
f923 0 0 1 "samples/FRENCH HORN/F.HORN C4.aif" 0 0 0
f924 0 0 1 "samples/FRENCH HORN/F.HORN D4.aif" 0 0 0
f925 0 0 1 "samples/FRENCH HORN/F.HORN E4.aif" 0 0 0
f926 0 0 1 "samples/FRENCH HORN/F.HORN F#4.aif" 0 0 0
f927 0 0 1 "samples/FRENCH HORN/F.HORN A#4.aif" 0 0 0
f928 0 0 1 "samples/FRENCH HORN/F.HORN C5.aif" 0 0 0
f929 0 0 1 "samples/FRENCH HORN/F.HORN D5-f.aif" 0 0 0
f934 0 0 1 "samples/VIOLIN W-VIB/VIOLING#3.aif" 0 0 0
f935 0 0 1 "samples/VIOLIN W-VIB/VIOLINA#3.aif" 0 0 0
f936 0 0 1 "samples/VIOLIN W-VIB/VIOLINC4.aif" 0 0 0
f937 0 0 1 "samples/VIOLIN W-VIB/VIOLIND4.aif" 0 0 0
f938 0 0 1 "samples/VIOLIN W-VIB/VIOLINE4.aif" 0 0 0
f939 0 0 1 "samples/VIOLIN W-VIB/VIOLINF#4.aif" 0 0 0
f940 0 0 1 "samples/VIOLIN W-VIB/VIOLING#4.aif" 0 0 0
f941 0 0 1 "samples/VIOLIN W-VIB/VIOLINA#4.aif" 0 0 0
f942 0 0 1 "samples/VIOLIN W-VIB/VIOLINC#5.aif" 0 0 0
f943 0 0 1 "samples/VIOLIN W-VIB/VIOLIND#5.aif" 0 0 0
f944 0 0 1 "samples/VIOLIN W-VIB/VIOLINF5.aif" 0 0 0
f945 0 0 1 "samples/VIOLIN W-VIB/VIOLING5.aif" 0 0 0
f946 0 0 1 "samples/VIOLIN W-VIB/VIOLINA5.aif" 0 0 0
f947 0 0 1 "samples/VIOLIN W-VIB/VIOLINB5.aif" 0 0 0
f948 0 0 1 "samples/VIOLIN W-VIB/VIOLINC#6.aif" 0 0 0
f949 0 0 1 "samples/VIOLIN W-VIB/VIOLIND#6.aif" 0 0 0
f950 0 0 1 "samples/VIOLIN W-VIB/VIOLINF6.aif" 0 0 0
f951 0 0 1 "samples/VIOLIN W-VIB/VIOLING6.aif" 0 0 0
f952 0 0 1 "samples/VIOLIN W-VIB/VIOLINA6.aif" 0 0 0
f957 0 0 1 "samples/VIOLA W-VIB/VIOLAV C#3.aif" 0 0 0
f958 0 0 1 "samples/VIOLA W-VIB/VIOLAV D3.aif" 0 0 0
f959 0 0 1 "samples/VIOLA W-VIB/VIOLAV E3.aif" 0 0 0
f960 0 0 1 "samples/VIOLA W-VIB/VIOLAV F#3.aif" 0 0 0
f961 0 0 1 "samples/VIOLA W-VIB/VIOLAV G#3.aif" 0 0 0
f962 0 0 1 "samples/VIOLA W-VIB/VIOLAV A#3.aif" 0 0 0
f963 0 0 1 "samples/VIOLA W-VIB/VIOLAV C4.aif" 0 0 0
f964 0 0 1 "samples/VIOLA W-VIB/VIOLAV D4.aif" 0 0 0
f965 0 0 1 "samples/VIOLA W-VIB/VIOLAV E4.aif" 0 0 0
f966 0 0 1 "samples/VIOLA W-VIB/VIOLAV F#4.aif" 0 0 0
f967 0 0 1 "samples/VIOLA W-VIB/VIOLAV G#4.aif" 0 0 0
f968 0 0 1 "samples/VIOLA W-VIB/VIOLAV A#4.aif" 0 0 0
f969 0 0 1 "samples/VIOLA W-VIB/VIOLAV C5.aif" 0 0 0
f970 0 0 1 "samples/VIOLA W-VIB/VIOLAV D#5.aif" 0 0 0
f971 0 0 1 "samples/VIOLA W-VIB/VIOLAV F#5.aif" 0 0 0
f972 0 0 1 "samples/VIOLA W-VIB/VIOLAV A5.aif" 0 0 0
f973 0 0 1 "samples/VIOLA W-VIB/VIOLAV B5.aif" 0 0 0
f974 0 0 1 "samples/VIOLA W-VIB/VIOLAV C#6.aif" 0 0 0
f979 0 0 1 "samples/CELLO W-VIB/CELLOV C#2.aif" 0 0 0
f980 0 0 1 "samples/CELLO W-VIB/CELLOV D#2.aif" 0 0 0
f981 0 0 1 "samples/CELLO W-VIB/CELLOV F2.aif" 0 0 0
f982 0 0 1 "samples/CELLO W-VIB/CELLOV G2.aif" 0 0 0
f983 0 0 1 "samples/CELLO W-VIB/CELLOV A2.aif" 0 0 0
f984 0 0 1 "samples/CELLO W-VIB/CELLOV B2.aif" 0 0 0
f985 0 0 1 "samples/CELLO W-VIB/CELLOV C#3.aif" 0 0 0
f986 0 0 1 "samples/CELLO W-VIB/CELLOV D#3.aif" 0 0 0
f987 0 0 1 "samples/CELLO W-VIB/CELLOV F3.aif" 0 0 0
f988 0 0 1 "samples/CELLO W-VIB/CELLOV G3.aif" 0 0 0
f989 0 0 1 "samples/CELLO W-VIB/CELLOV A3.aif" 0 0 0
f990 0 0 1 "samples/CELLO W-VIB/CELLOV B3.aif" 0 0 0
f991 0 0 1 "samples/CELLO W-VIB/CELLOV C#4.aif" 0 0 0
f992 0 0 1 "samples/CELLO W-VIB/CELLOV D#4.aif" 0 0 0
f993 0 0 1 "samples/CELLO W-VIB/CELLOV F4.aif" 0 0 0
f994 0 0 1 "samples/CELLO W-VIB/CELLOV G4.aif" 0 0 0
f995 0 0 1 "samples/CELLO W-VIB/CELLOV A4.aif" 0 0 0
f996 0 0 1 "samples/CELLO W-VIB/CELLOV B4.aif" 0 0 0
f997 0 0 1 "samples/CELLO W-VIB/CELLOV C#5.aif" 0 0 0
f998 0 0 1 "samples/CELLO W-VIB/CELLOV D#5.aif" 0 0 0
f1003 0 0 1 "samples/Baritone Guitar/H1B-19b.wav" 0 0 0
f1004 0 0 1 "samples/Baritone Guitar/H2C#-6.wav" 0 0 0
f1005 0 0 1 "samples/Baritone Guitar/H2D#-6.wav" 0 0 0
f1006 0 0 1 "samples/Baritone Guitar/H2E-15.wav" 0 0 0
f1007 0 0 1 "samples/Baritone Guitar/H2F#-2.wav" 0 0 0
f1008 0 0 1 "samples/Baritone Guitar/H2G#-7.wav" 0 0 0
f1009 0 0 1 "samples/Baritone Guitar/H2A-8.wav" 0 0 0
f1010 0 0 1 "samples/Baritone Guitar/H2B+3.wav" 0 0 0
f1011 0 0 1 "samples/Baritone Guitar/H3C#-4.wav" 0 0 0
f1012 0 0 1 "samples/Baritone Guitar/H3D-12.wav" 0 0 0
f1013 0 0 1 "samples/Baritone Guitar/H3E-11.wav" 0 0 0
f1014 0 0 1 "samples/Baritone Guitar/H3F#-5.wav" 0 0 0
f1015 0 0 1 "samples/Baritone Guitar/H3G#-6.wav" 0 0 0
f1016 0 0 1 "samples/Baritone Guitar/H3A#+2.wav" 0 0 0
f1017 0 0 1 "samples/Baritone Guitar/H3B-16.wav" 0 0 0
f1018 0 0 1 "samples/Baritone Guitar/H4C#+3.wav" 0 0 0
f1019 0 0 1 "samples/Baritone Guitar/H4D#+0.wav" 0 0 0
f1020 0 0 1 "samples/Baritone Guitar/H4F+24.wav" 0 0 0
f1021 0 0 1 "samples/Baritone Guitar/H4G+5.wav" 0 0 0
f1022 0 0 1 "samples/Baritone Guitar/H4A-5.wav" 0 0 0
f1023 0 0 1 "samples/Baritone Guitar/H4B+3.wav" 0 0 0
f1024 0 0 1 "samples/Baritone Guitar/H5C#+0.wav" 0 0 0
f1025 0 0 1 "samples/Baritone Guitar/H5D#+0.wav" 0 0 0
f1026 0 0 1 "samples/Baritone Guitar/H5F+0.wav" 0 0 0
f1027 0 0 1 "samples/Baritone Guitar/H5G+0.wav" 0 0 0
f1028 0 0 1 "samples/Baritone Guitar/H5A-5.wav" 0 0 0
f1029 0 0 1 "samples/Baritone Guitar/H5B+13.wav" 0 0 0
f1034 0 0 1 "samples/ErnieBall-038/2Em9s.aif" 0 0 0
f1035 0 0 1 "samples/ErnieBall-038/2F#p0s.aif" 0 0 0
f1036 0 0 1 "samples/ErnieBall-038/2G#m3.aif" 0 0 0
f1037 0 0 1 "samples/ErnieBall-030/2Am4.aif" 0 0 0
f1038 0 0 1 "samples/ErnieBall-030/2Bm3.aif" 0 0 0
f1039 0 0 1 "samples/ErnieBall-030/3C#m10s.aif" 0 0 0
f1040 0 0 1 "samples/ErnieBall-022/3Dm3.aif" 0 0 0
f1041 0 0 1 "samples/ErnieBall-022/3Em4.aif" 0 0 0
f1042 0 0 1 "samples/ErnieBall-022/3F#m4.aif" 0 0 0
f1043 0 0 1 "samples/ErnieBall-014/3Gm6.aif" 0 0 0
f1044 0 0 1 "samples/ErnieBall-014/3Ap0.aif" 0 0 0
f1045 0 0 1 "samples/ErnieBall-011/3Bm5.aif" 0 0 0
f1046 0 0 1 "samples/ErnieBall-011/4Cp1.aif" 0 0 0
f1047 0 0 1 "samples/ErnieBall-011/4Dm2.aif" 0 0 0
f1048 0 0 1 "samples/ErnieBall-011/4Em5.aif" 0 0 0
f1049 0 0 1 "samples/ErnieBall-011/4F#m5.aif" 0 0 0
f1050 0 0 1 "samples/ErnieBall-011/4G#p0.aif" 0 0 0
f1051 0 0 1 "samples/ErnieBall-011/4A#m2.aif" 0 0 0
f1052 0 0 1 "samples/ErnieBall-011/5Cp0.aif" 0 0 0
f1053 0 0 1 "samples/ErnieBall-011/5Dp0.aif" 0 0 0
f1054 0 0 1 "samples/ErnieBall-011/5Ep0.aif" 0 0 0
f1055 0 0 1 "samples/ErnieBall-011/5F#p2.aif" 0 0 0
f1056 0 0 1 "samples/ErnieBall-011/5G#m2.aif" 0 0 0
f1057 0 0 1 "samples/ErnieBall-011/5A#m3.aif" 0 0 0
f1058 0 0 1 "samples/ErnieBall-011/6Cp0.aif" 0 0 0
f1059 0 0 1 "samples/ErnieBall-011/6Dp1.aif" 0 0 0
f1060 0 0 1 "samples/ErnieBall-011/6Em1.aif" 0 0 0
f1061 0 0 1 "samples/ErnieBall-011/6F#p0.aif" 0 0 0
f1062 0 0 1 "samples/ErnieBall-011/6G#p0.aif" 0 0 0
f1063 0 0 1 "samples/ErnieBall-008/6A#m13.aif" 0 0 0
f1064 0 0 1 "samples/ErnieBall-008/7Cm15.aif" 0 0 0
f1065 0 0 1 "samples/ErnieBall-008/7Dm29.aif" 0 0 0
f1066 0 0 1 "samples/ErnieBall-008/7F#m16.aif" 0 0 0
f1067 0 0 1 "samples/ErnieBall-008/7G#m47.aif" 0 0 0
f1068 0 0 1 "samples/ErnieBall-008/7A#p28.aif" 0 0 0
f1069 0 0 1 "samples/ErnieBall-008/8Cm37.aif" 0 0 0
f1074 0 0 1 "samples/LongString-024/String0Bp1.aif" 0 0 0
f1075 0 0 1 "samples/LongString-024/String1Cp1.aif" 0 0 0
f1076 0 0 1 "samples/LongString-024/String1Dm3.aif" 0 0 0
f1077 0 0 1 "samples/LongString-024/String1Em1.aif" 0 0 0
f1078 0 0 1 "samples/LongString-024/String1Fp1.aif" 0 0 0
f1079 0 0 1 "samples/LongString-024/String1Gm2.aif" 0 0 0
f1080 0 0 1 "samples/LongString-024/String1Ap0.aif" 0 0 0
f1081 0 0 1 "samples/LongString-024/String1Bp0.aif" 0 0 0
f1082 0 0 1 "samples/LongString-024/String2Cp0.aif" 0 0 0
f1083 0 0 1 "samples/LongString-024/String2Dp0.aif" 0 0 0
f1084 0 0 1 "samples/LongString-024/String2Ep0.aif" 0 0 0
f1085 0 0 1 "samples/LongString-024/String2Fp2.aif" 0 0 0
f1086 0 0 1 "samples/LongString-024/String2Gp5.aif" 0 0 0
f1087 0 0 1 "samples/LongString-024/String2Ap0.aif" 0 0 0
f1088 0 0 1 "samples/LongString-024/String2Bp0.aif" 0 0 0
f1089 0 0 1 "samples/LongString-024/String3Cp0.aif" 0 0 0
f1090 0 0 1 "samples/LongString-024/String3Dp0.aif" 0 0 0
f1091 0 0 1 "samples/LongString-024/String3Em2.aif" 0 0 0
f1092 0 0 1 "samples/LongString-024/String3Fm5.aif" 0 0 0
f1093 0 0 1 "samples/LongString-024/String3Gp0.aif" 0 0 0
f1094 0 0 1 "samples/LongString-024/String3Ap1.aif" 0 0 0
f1095 0 0 1 "samples/LongString-024/String3Bm1.aif" 0 0 0
f1096 0 0 1 "samples/LongString-024/String4Cm1.aif" 0 0 0
f1097 0 0 1 "samples/LongString-024/String4Dp0.aif" 0 0 0
f1098 0 0 1 "samples/LongString-024/String4Ep0.aif" 0 0 0
f1099 0 0 1 "samples/LongString-024/String4Fm5.aif" 0 0 0
f1100 0 0 1 "samples/LongString-024/String4Gm5.aif" 0 0 0
f1101 0 0 1 "samples/LongString-024/String4Ap0.aif" 0 0 0
f1102 0 0 1 "samples/LongString-024/String4Bp3.aif" 0 0 0
f1103 0 0 1 "samples/LongString-024/String5Cm3.aif" 0 0 0
f1108 0 0 1 "samples/Strings/String3D#m49.aif" 0 0 0
f1109 0 0 1 "samples/Strings/String3Fm44.aif" 0 0 0
f1110 0 0 1 "samples/Strings/String3G#m9.aif" 0 0 0
f1111 0 0 1 "samples/Strings/String3Ap23.aif" 0 0 0
f1112 0 0 1 "samples/Strings/String3A#p22.aif" 0 0 0
f1113 0 0 1 "samples/Strings/String3Bm5.aif" 0 0 0
f1114 0 0 1 "samples/Strings/String4Cp16.aif" 0 0 0
f1115 0 0 1 "samples/Strings/String4C#p10.aif" 0 0 0
f1116 0 0 1 "samples/Strings/String4Dm22.aif" 0 0 0
f1117 0 0 1 "samples/Strings/String4D#m17.aif" 0 0 0
f1118 0 0 1 "samples/Strings/String4Em5.aif" 0 0 0
f1119 0 0 1 "samples/Strings/String4F#p2.aif" 0 0 0
f1120 0 0 1 "samples/Strings/String4G#m3.aif" 0 0 0
f1121 0 0 1 "samples/Strings/String4A#p2.aif" 0 0 0
f1122 0 0 1 "samples/Strings/String5Cm27.aif" 0 0 0
f1123 0 0 1 "samples/Strings/String5Dm30.aif" 0 0 0
f1124 0 0 1 "samples/Strings/String5Em5.aif" 0 0 0
f1125 0 0 1 "samples/Strings/String5F#p6.aif" 0 0 0
f1126 0 0 1 "samples/Strings/String5G#m3.aif" 0 0 0
f1127 0 0 1 "samples/Strings/String5Bp10.aif" 0 0 0
f1128 0 0 1 "samples/Strings/String6C#m11.aif" 0 0 0
f1129 0 0 1 "samples/Strings/String6D#p0.aif" 0 0 0
f1134 0 0 1 "samples/Bass FingerP/Piano 0 G +4.aif" 0 0 0
f1135 0 0 1 "samples/Bass FingerP/Piano 0 G# -30.aif" 0 0 0
f1136 0 0 1 "samples/Bass FingerP/Piano 0 A# -21.aif" 0 0 0
f1137 0 0 1 "samples/Bass FingerP/Piano 1 C -11.aif" 0 0 0
f1138 0 0 1 "samples/Bass FingerP/Piano 1 D +9.aif" 0 0 0
f1139 0 0 1 "samples/Bass FingerP/Piano 1 G +17.aif" 0 0 0
f1140 0 0 1 "samples/Bass FingerP/Piano 1 A +22.aif" 0 0 0
f1141 0 0 1 "samples/Bass FingerP/Piano 2 C -10.aif" 0 0 0
f1142 0 0 1 "samples/Bass FingerP/Piano 2 D -38.aif" 0 0 0
f1143 0 0 1 "samples/Bass FingerP/Piano 2 E +14.aif" 0 0 0
f1144 0 0 1 "samples/Bass FingerP/Piano 2 F# +17.aif" 0 0 0
f1145 0 0 1 "samples/Bass FingerP/Piano 2 A -32.aif" 0 0 0
f1146 0 0 1 "samples/Bass FingerP/Piano 2 A# -1.aif" 0 0 0
f1147 0 0 1 "samples/Bass FingerP/Piano 3 C +16.aif" 0 0 0
f1148 0 0 1 "samples/Bass FingerP/Piano 3 D +46.aif" 0 0 0
f1149 0 0 1 "samples/Bass FingerP/Piano 3 F -30.aif" 0 0 0
f1150 0 0 1 "samples/Bass FingerP/Piano 3 G# -1.aif" 0 0 0
f1151 0 0 1 "samples/Bass FingerP/Piano 3 A# +39.aif" 0 0 0
f1152 0 0 1 "samples/Bass FingerP/Piano 4 D -5.aif" 0 0 0
f1153 0 0 1 "samples/Bass FingerP/Piano 4 F# -2.aif" 0 0 0
f1154 0 0 1 "samples/Bass FingerP/Piano 4 A +32.aif" 0 0 0
f1155 0 0 1 "samples/Bass FingerP/Piano 5 D -41.aif" 0 0 0
f1160 0 0 1 "samples/TRUMPET-C/TRUMPETC F#3.aif" 0 0 0
f1161 0 0 1 "samples/TRUMPET-C/TRUMPETC G#3.aif" 0 0 0
f1162 0 0 1 "samples/TRUMPET-C/TRUMPETC A#3.aif" 0 0 0
f1163 0 0 1 "samples/TRUMPET-C/TRUMPETCC4.aif" 0 0 0
f1164 0 0 1 "samples/TRUMPET-C/TRUMPETCD4.aif" 0 0 0
f1165 0 0 1 "samples/TRUMPET-C/TRUMPETCE4.aif" 0 0 0
f1166 0 0 1 "samples/TRUMPET-C/TRUMPETC F#4.aif" 0 0 0
f1167 0 0 1 "samples/TRUMPET-C/TRUMPETC G#4.aif" 0 0 0
f1168 0 0 1 "samples/TRUMPET-C/TRUMPETC A#4.aif" 0 0 0
f1169 0 0 1 "samples/TRUMPET-C/TRUMPETCC5.aif" 0 0 0
f1170 0 0 1 "samples/TRUMPET-C/TRUMPETCD5.aif" 0 0 0
f1171 0 0 1 "samples/TRUMPET-C/TRUMPETCE5.aif" 0 0 0
f1172 0 0 1 "samples/TRUMPET-C/TRUMPETC F#5.aif" 0 0 0
f1173 0 0 1 "samples/TRUMPET-C/TRUMPETC G#5.aif" 0 0 0
f1174 0 0 1 "samples/TRUMPET-C/TRUMPETC A#5.aif" 0 0 0
f1175 0 0 1 "samples/TRUMPET-C/TRUMPETCC6.aif" 0 0 0
f1176 0 0 1 "samples/TRUMPET-C/TRUMPETCD6.aif" 0 0 0
f1181 0 0 1 "samples/TROMBONE-TNR/TNRBONEE2.aif" 0 0 0
f1182 0 0 1 "samples/TROMBONE-TNR/TNRBONEG2.aif" 0 0 0
f1183 0 0 1 "samples/TROMBONE-TNR/TNRBONEA#2.aif" 0 0 0
f1184 0 0 1 "samples/TROMBONE-TNR/TNRBONEC#3.aif" 0 0 0
f1185 0 0 1 "samples/TROMBONE-TNR/TNRBONEE3.aif" 0 0 0
f1186 0 0 1 "samples/TROMBONE-TNR/TNRBONEG3.aif" 0 0 0
f1187 0 0 1 "samples/TROMBONE-TNR/TNRBONEA#3.aif" 0 0 0
f1188 0 0 1 "samples/TROMBONE-TNR/TNRBONEC#4.aif" 0 0 0
f1189 0 0 1 "samples/TROMBONE-TNR/TNRBONEE4.aif" 0 0 0
f1190 0 0 1 "samples/TROMBONE-TNR/TNRBONEG4.aif" 0 0 0
f1191 0 0 1 "samples/TROMBONE-TNR/TNRBONEA#4.aif" 0 0 0
f1196 0 0 1 "samples/TUBA/TUBA C2.aif" 0 0 0
f1197 0 0 1 "samples/TUBA/TUBA D2.aif" 0 0 0
f1198 0 0 1 "samples/TUBA/TUBA F2.aif" 0 0 0
f1199 0 0 1 "samples/TUBA/TUBA G2.aif" 0 0 0
f1200 0 0 1 "samples/TUBA/TUBA A2.aif" 0 0 0
f1201 0 0 1 "samples/TUBA/TUBA B2.aif" 0 0 0
f1202 0 0 1 "samples/TUBA/TUBA C#3.aif" 0 0 0
f1203 0 0 1 "samples/TUBA/TUBA D#3.aif" 0 0 0
f1204 0 0 1 "samples/TUBA/TUBA F3.aif" 0 0 0
f1205 0 0 1 "samples/TUBA/TUBA G3.aif" 0 0 0
f1206 0 0 1 "samples/TUBA/TUBA A3.aif" 0 0 0
f1207 0 0 1 "samples/TUBA/TUBA B3.aif" 0 0 0
f1208 0 0 1 "samples/TUBA/TUBA C#4.aif" 0 0 0
f1209 0 0 1 "samples/TUBA/TUBA D#4.aif" 0 0 0
f1210 0 0 1 "samples/TUBA/TUBA F4.aif" 0 0 0
f1211 0 0 1 "samples/TUBA/TUBA G4.aif" 0 0 0
;              1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20   21   22   23   24   25   26   27
f1 0 64 -2 0 601 630 652 667 683 705 726 742 766 787 807 830 850 872 890 909 930 953 975 999 1030 1070 1104 1130 1156 1177 1192 
f2 0 64 -2 0 1 2 2 2 2 2 2 1 2 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 2 2 2
;Ins Star Dur Vel   Ton   Oct  Voice Stere Envlp Gliss Upsamp R-Env 2nd-gl 3rd Mult Line # ; Channel
;p1  p2   p3  p4    p5    p6   p7    p8    p9    p10   p11    p12   p13   p14  p15; Channel
; i1  0     4   69    000    4   1    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   2    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   3    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   4    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   5    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   6    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   7    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   8    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   9    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   10   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   11   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   12   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   13   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   14   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   15   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   16   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   17   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   18   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   19   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   20   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   21   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   22   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   23   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   24   8     1     0     0     1     0     0    35 ;  

f1500.0 0.0 256.0 -6.0 1.0 128.0 1.006102 128.0 1.012204 
f1501.0 0.0 256.0 -6.0 1.0 128.0 1.002316 128.0 1.004632 
f1502.0 0.0 256.0 -6.0 1.0 128.0 0.9985580000000001 128.0 0.997116 
f1503.0 0.0 256.0 -6.0 1.0 128.0 0.9934015 128.0 0.986803 
f1504.0 0.0 256.0 -6.0 1.0 128.0 1.007566 128.0 1.015132 
f1505.0 0.0 256.0 -6.0 1.0 128.0 1.0020259999999999 128.0 1.004052 
f1506.0 0.0 256.0 -6.0 1.0 128.0 1.0037685 128.0 1.007537 
f1507.0 0.0 256.0 -6.0 1.0 128.0 0.9939715 128.0 0.987943 
f1508.0 0.0 256.0 -6.0 1.0 128.0 0.994257 128.0 0.988514 
;Inst	Sta	Hold	Vel	Ton	Oct	Voi	Ste	En1	Gls	Ups	Ren	2gl	3gl	Vol
i 1	0.00010204081632653097	1.01	61	1093	3	13	9	1	0	1	1	0	0	14.0	
i 1	0.00010204081632653097	1.01	61	209	4	25	2	16	0	2	16	0	0	15.0	
i 1	0.00030612244897959204	1.01	61	707	3	16	11	1	0	2	1	0	0	16.0	
i 1	0.0005102040816326531	1.01	63	707	3	26	8	1	0	2	1	0	0	15.0	
i 1	0.0009183673469387752	1.01	63	707	3	16	9	16	0	1	16	0	0	16.0	
i 1	0.0009183673469387752	1.01	63	707	3	12	3	16	0	2	16	0	0	16.0	
i 1	0.0011224489795918367	1.01	63	707	3	26	12	16	0	2	16	0	0	15.0	
i 1	0.0013265306122448983	1.01	63	209	4	14	11	16	0	2	16	0	0	17.0	
i 1	0.0017346938775510204	1.01	63	1093	3	13	13	1	0	2	1	0	0	14.0	
i 1	0.0021428571428571434	1.01	61	209	4	14	9	1	0	1	1	0	0	17.0	
i 1	0.0035714285714285718	1.01	63	209	4	25	4	16	0	1	16	0	0	15.0	
i 1	0.0035714285714285718	1.01	63	1093	3	25	1	1	0	1	1	0	0	15.0	
i 1	0.003775510204081633	1.01	63	707	3	12	2	16	0	1	16	0	0	16.0	
i 1	0.0037755102040816337	1.01	63	1093	3	25	6	16	0	2	16	0	0	15.0	
i 1	0.004591836734693878	1.01	61	707	3	27	13	16	0	1	16	0	0	16.0	
i 1	0.004795918367346938	1.01	61	707	3	27	8	16	0	2	16	0	0	16.0	
i 1	0.9952040816326531	1.01	63	698	4	25	5	16	0	1	16	0	0	15.0	
i 1	0.9964285714285714	1.01	61	1084	3	16	12	1	0	1	1	0	0	16.0	
i 1	0.9968367346938776	1.01	63	1084	3	26	4	1	0	2	1	0	0	15.0	
i 1	0.998061224489796	1.01	61	382	3	12	5	16	0	2	16	0	0	16.0	
i 1	0.9984693877551021	1.01	61	1084	3	26	11	16	0	1	16	0	0	15.0	
i 1	0.9996938775510205	0.505	61	382	4	13	10	1	0	2	1	0	0	14.0	
i 1	1.0007142857142857	1.01	63	698	4	25	14	1	0	1	1	0	0	15.0	
i 1	1.0009183673469388	1.01	63	698	4	14	9	16	0	2	16	0	0	17.0	
i 1	1.0023469387755102	0.505	61	382	4	25	5	16	0	2	16	0	0	15.0	
i 1	1.0037755102040817	1.01	61	382	3	27	10	1	0	2	1	0	0	16.0	
i 1	1.0043877551020408	0.505	63	382	4	13	3	16	0	2	16	0	0	14.0	
i 1	1.004591836734694	1.01	63	698	4	14	2	16	0	2	16	0	0	17.0	
i 1	1.004795918367347	0.505	61	382	4	25	7	1	0	1	1	0	0	15.0	
i 1	1.005	1.01	63	1084	3	16	13	1	0	1	1	0	0	16.0	
i 1	1.005	1.01	63	382	3	12	5	16	0	1	16	0	0	16.0	
i 1	1.005	1.01	63	382	3	27	12	16	0	1	16	0	0	16.0	
i 1	1.4964285714285714	1.01	63	698	4	25	1	16	0	2	16	0	0	15.0	
i 1	1.4970408163265305	1.01	61	698	4	13	15	16	0	1	16	0	0	14.0	
i 1	1.498469387755102	1.01	61	698	4	13	12	16	0	2	16	0	0	14.0	
i 1	1.504591836734694	1.01	61	698	4	25	15	1	0	1	1	0	0	15.0	
i 1	1.995408163265306	1.01	61	200	3	27	9	16	0	1	16	0	0	16.0	
i 1	1.9968367346938776	1.01	63	200	3	27	15	1	0	1	1	0	0	16.0	
i 1	1.9974489795918366	1.01	63	902	4	14	9	16	0	1	16	0	0	17.0	
i 1	1.9976530612244898	2.525	63	200	4	16	7	16	0	2	16	0	0	16.0	
i 1	1.998061224489796	2.525	63	200	4	26	13	16	0	2	16	0	0	15.0	
i 1	1.998673469387755	1.01	63	902	4	25	1	1	0	1	1	0	0	15.0	
i 1	1.9992857142857143	2.525	61	200	4	16	7	16	0	1	16	0	0	16.0	
i 1	2.0003061224489795	1.01	61	902	4	25	3	1	0	1	1	0	0	15.0	
i 1	2.001530612244898	1.01	63	200	3	12	15	16	0	2	16	0	0	16.0	
i 1	2.0023469387755104	2.525	61	200	4	26	4	16	0	1	16	0	0	15.0	
i 1	2.002551020408163	1.01	61	200	3	12	16	16	0	1	16	0	0	16.0	
i 1	2.0047959183673467	1.01	61	902	4	14	1	1	0	2	1	0	0	17.0	
i 1	2.4970408163265305	0.505	61	586	4	13	5	1	0	2	1	0	0	14.0	
i 1	2.498265306122449	0.505	63	586	4	13	10	1	0	1	1	0	0	14.0	
i 1	2.499285714285714	0.505	63	586	4	25	7	16	0	2	16	0	0	15.0	
i 1	2.5033673469387754	0.505	61	586	4	25	9	1	0	2	1	0	0	15.0	
i 1	2.9970408163265305	0.505	63	698	4	25	7	1	0	1	1	0	0	15.0	
i 1	2.998469387755102	1.01	61	1084	4	25	10	1	0	1	1	0	0	15.0	
i 1	2.998877551020408	0.505	63	698	4	13	9	16	0	2	16	0	0	14.0	
i 1	2.9994897959183673	1.01	63	1084	4	14	14	16	0	2	16	0	0	17.0	
i 1	3.0005102040816327	0.505	61	698	4	25	8	1	0	1	1	0	0	15.0	
i 1	3.000714285714286	1.01	63	698	3	12	8	16	0	1	16	0	0	16.0	
i 1	3.0021428571428572	1.01	63	698	3	27	16	16	0	1	16	0	0	16.0	
i 1	3.0023469387755104	1.01	63	698	3	12	2	1	0	1	1	0	0	16.0	
i 1	3.0033673469387754	1.01	63	1084	4	25	7	16	0	1	16	0	0	15.0	
i 1	3.004591836734694	1.01	63	1084	4	14	8	16	0	2	16	0	0	17.0	
i 1	3.004591836734694	0.505	63	698	4	13	11	16	0	1	16	0	0	14.0	
i 1	3.0047959183673467	1.01	63	698	3	27	16	1	0	2	1	0	0	16.0	
i 1	3.4996938775510205	0.2525	61	586	4	25	14	1	0	1	1	0	0	15.0	
i 1	3.5035714285714286	0.2525	61	586	4	13	8	1	0	2	1	0	0	14.0	
i 1	3.504387755102041	0.2525	63	586	4	25	1	16	0	1	16	0	0	15.0	
i 1	3.505	0.2525	61	586	4	13	8	16	0	1	16	0	0	14.0	
i 1	3.748265306122449	0.2525	61	382	4	13	1	16	0	1	16	0	0	14.0	
i 1	3.7498979591836736	0.2525	63	382	4	25	16	1	0	1	1	0	0	15.0	
i 1	3.751938775510204	0.2525	61	382	4	13	12	1	0	1	1	0	0	14.0	
i 1	3.7533673469387754	0.2525	61	382	4	25	8	1	0	2	1	0	0	15.0	
i 1	3.9952040816326533	0.505	63	200	3	27	7	1	0	1	1	0	0	16.0	
i 1	3.995408163265306	1.01	61	586	4	13	9	16	0	1	16	0	0	14.0	
i 1	3.995408163265306	1.01	61	586	4	25	6	1	0	2	1	0	0	15.0	
i 1	3.9968367346938773	1.01	61	902	4	14	6	1	0	2	1	0	0	17.0	
i 1	3.9972448979591837	0.505	61	200	3	27	10	1	0	1	1	0	0	16.0	
i 1	3.9978571428571428	1.01	63	586	4	25	12	16	0	1	16	0	0	15.0	
i 1	3.998061224489796	0.505	61	200	3	12	9	16	0	2	16	0	0	16.0	
i 1	3.998265306122449	1.01	61	902	4	25	12	16	0	1	16	0	0	15.0	
i 1	3.998469387755102	1.01	61	902	4	14	12	16	0	2	16	0	0	17.0	
i 1	3.9990816326530614	0.505	61	200	3	12	14	1	0	2	1	0	0	16.0	
i 1	3.9990816326530614	1.01	61	902	4	25	8	16	0	1	16	0	0	15.0	
i 1	4.00030612244898	1.01	63	586	4	13	11	16	0	1	16	0	0	14.0	
i 1	4.4954081632653065	0.505	61	1168	3	16	11	16	0	2	16	0	0	16.0	
i 1	4.4960204081632655	0.505	61	1168	3	26	3	1	0	1	1	0	0	15.0	
i 1	4.497448979591836	0.505	63	199	3	12	12	16	0	2	16	0	0	16.0	
i 1	4.49765306122449	0.505	63	199	3	27	9	16	0	1	16	0	0	16.0	
i 1	4.498265306122449	0.505	63	1168	3	26	16	1	0	2	1	0	0	15.0	
i 1	4.499081632653061	0.505	61	1168	3	16	14	1	0	2	1	0	0	16.0	
i 1	4.5039795918367345	0.505	61	199	3	27	9	16	0	1	16	0	0	16.0	
i 1	4.504183673469388	0.505	63	199	3	12	3	1	0	1	1	0	0	16.0	
i 1	4.995204081632653	2.02	63	1084	3	26	7	1	0	1	1	0	0	15.0	
i 1	4.995816326530612	2.02	61	1084	3	16	11	16	0	1	16	0	0	16.0	
i 1	4.996224489795918	2.02	61	698	2	27	1	1	0	2	1	0	0	16.0	
i 1	4.996428571428571	2.02	63	698	2	27	11	1	0	2	1	0	0	16.0	
i 1	4.996836734693877	2.02	61	200	4	25	10	1	0	2	1	0	0	15.0	
i 1	4.997040816326531	2.02	61	698	4	25	15	16	0	2	16	0	0	15.0	
i 1	4.998469387755102	2.02	63	698	2	12	14	1	0	2	1	0	0	16.0	
i 1	4.999081632653061	2.02	63	698	2	12	11	1	0	2	1	0	0	16.0	
i 1	5.0007142857142854	2.02	61	200	4	13	5	1	0	2	1	0	0	14.0	
i 1	5.002551020408164	2.02	63	698	4	14	10	16	0	2	16	0	0	17.0	
i 1	5.002551020408164	2.02	61	698	4	25	4	1	0	1	1	0	0	15.0	
i 1	5.003163265306123	2.02	63	698	4	14	11	1	0	2	1	0	0	17.0	
i 1	5.003367346938775	2.02	61	1084	3	26	7	1	0	2	1	0	0	15.0	
i 1	5.003571428571429	2.02	61	200	4	25	7	16	0	2	16	0	0	15.0	
i 1	5.004183673469388	2.02	61	200	4	13	3	16	0	1	16	0	0	14.0	
i 1	5.005	2.02	61	1084	3	16	15	16	0	2	16	0	0	16.0	
i 1	6.995	2.02	61	195	4	16	5	16	0	1	16	0	0	16.0	
i 1	6.995	1.01	61	195	3	12	13	16	0	1	16	0	0	16.0	
i 1	6.995	1.01	63	195	3	12	3	16	0	1	16	0	0	16.0	
i 1	6.995816326530612	1.01	63	195	3	27	9	1	0	2	1	0	0	16.0	
i 1	6.996428571428571	2.02	63	195	4	26	10	16	0	1	16	0	0	15.0	
i 1	6.997857142857143	1.01	61	897	4	25	3	16	0	1	16	0	0	15.0	
i 1	6.9986734693877555	1.01	63	581	4	13	13	16	0	1	16	0	0	14.0	
i 1	6.999081632653061	1.01	61	897	4	25	8	16	0	2	16	0	0	15.0	
i 1	6.999489795918367	1.01	63	581	4	25	6	16	0	1	16	0	0	15.0	
i 1	7.002551020408164	2.02	63	195	4	16	5	16	0	2	16	0	0	16.0	
i 1	7.002959183673469	1.01	61	897	4	14	4	16	0	1	16	0	0	17.0	
i 1	7.003163265306123	1.01	63	581	4	13	5	1	0	2	1	0	0	14.0	
i 1	7.003367346938775	1.01	61	897	4	14	8	1	0	1	1	0	0	17.0	
i 1	7.003775510204082	2.02	61	195	4	26	3	16	0	1	16	0	0	15.0	
i 1	7.005	1.01	61	581	4	25	7	16	0	2	16	0	0	15.0	
i 1	7.005	1.01	63	195	3	27	5	1	0	2	1	0	0	16.0	
i 1	7.995	1.01	61	693	3	27	6	1	0	1	1	0	0	16.0	
i 1	7.995204081632653	1.5150000000000001	63	693	4	13	14	1	1500	2	1	0	0	14.0	
i 1	7.9960204081632655	1.01	61	1079	4	25	5	16	0	2	16	0	0	15.0	
i 1	7.997244897959184	1.01	61	1079	4	14	7	1	0	2	1	0	0	17.0	
i 1	7.9986734693877555	1.5150000000000001	61	693	4	25	4	16	1500	1	16	0	0	15.0	
i 1	7.99969387755102	1.01	63	693	3	12	16	1	0	1	1	0	0	16.0	
i 1	8.000714285714286	1.01	63	1079	4	14	15	1	0	2	1	0	0	17.0	
i 1	8.000714285714286	1.01	63	693	3	12	16	16	0	2	16	0	0	16.0	
i 1	8.000918367346939	1.01	61	693	3	27	16	16	0	1	16	0	0	16.0	
i 1	8.001326530612245	1.01	61	1079	4	25	4	16	0	2	16	0	0	15.0	
i 1	8.002142857142857	1.5150000000000001	61	693	4	13	15	16	1500	1	16	0	0	14.0	
i 1	8.00295918367347	1.5150000000000001	63	693	4	25	2	1	1500	2	1	0	0	15.0	
i 1	8.995	1.01	63	12	3	27	5	1	0	1	1	0	0	16.0	
i 1	8.995408163265306	1.01	61	398	4	26	13	16	0	2	16	0	0	15.0	
i 1	8.99561224489796	1.01	61	12	5	25	6	1	0	2	1	0	0	15.0	
i 1	8.996020408163265	1.01	61	12	5	14	8	16	0	2	16	0	0	17.0	
i 1	8.997448979591837	1.01	63	398	4	16	6	1	0	2	1	0	0	16.0	
i 1	8.997857142857143	1.01	61	12	5	14	2	16	0	1	16	0	0	17.0	
i 1	8.999285714285714	1.01	63	12	3	12	16	16	0	2	16	0	0	16.0	
i 1	9.000102040816326	1.01	63	12	3	12	9	1	0	2	1	0	0	16.0	
i 1	9.000714285714286	1.01	61	398	4	16	16	1	0	1	1	0	0	16.0	
i 1	9.001938775510204	1.01	61	12	5	25	6	1	0	1	1	0	0	15.0	
i 1	9.001938775510204	1.01	63	12	3	27	7	1	0	1	1	0	0	16.0	
i 1	9.00295918367347	1.01	63	398	4	26	6	16	0	1	16	0	0	15.0	
i 1	9.496020408163265	1.01	63	896	4	13	10	1	0	1	1	0	0	14.0	
i 1	9.49622448979592	1.01	61	896	4	25	16	1	0	2	1	0	0	15.0	
i 1	9.500102040816326	1.01	63	896	4	13	4	16	0	2	16	0	0	14.0	
i 1	9.50377551020408	1.01	63	896	4	25	12	16	0	1	16	0	0	15.0	
i 1	9.995408163265306	1.01	61	194	3	27	9	1	1501	2	1	0	0	16.0	
i 1	9.995816326530612	1.7675	61	194	4	16	3	16	1501	2	16	0	0	16.0	
i 1	9.996428571428572	0.505	63	1127	4	25	2	16	0	2	16	0	0	15.0	
i 1	9.996632653061225	1.01	63	194	3	27	14	1	1501	2	1	0	0	16.0	
i 1	9.996836734693877	0.505	61	1127	4	14	9	16	0	1	16	0	0	17.0	
i 1	9.997244897959183	1.7675	63	194	4	26	8	16	1501	2	16	0	0	15.0	
i 1	9.999285714285714	1.7675	61	194	4	16	11	1	1501	2	1	0	0	16.0	
i 1	10.000510204081632	1.01	63	194	3	12	3	1	1501	1	1	0	0	16.0	
i 1	10.000714285714286	1.7675	61	194	4	26	11	1	1501	1	1	0	0	15.0	
i 1	10.001734693877552	0.505	61	1127	4	14	1	16	0	2	16	0	0	17.0	
i 1	10.003367346938775	0.505	63	1127	4	25	3	1	0	1	1	0	0	15.0	
i 1	10.004183673469388	1.01	63	194	3	12	3	1	1501	1	1	0	0	16.0	
i 1	10.496020408163265	1.01	61	700	4	13	15	1	0	2	1	0	0	14.0	
i 1	10.49704081632653	1.01	61	700	4	13	11	1	0	1	1	0	0	14.0	
i 1	10.499081632653061	1.01	63	700	4	25	2	1	0	2	1	0	0	15.0	
i 1	10.501122448979592	1.01	63	700	4	25	8	1	0	2	1	0	0	15.0	
i 1	10.501530612244897	0.505	61	1086	4	14	7	16	0	1	16	0	0	17.0	
i 1	10.501734693877552	0.505	61	1086	4	14	6	1	0	2	1	0	0	17.0	
i 1	10.502551020408163	0.505	61	1086	4	25	9	1	0	2	1	0	0	15.0	
i 1	10.50438775510204	0.505	63	1086	4	25	7	1	0	1	1	0	0	15.0	
i 1	10.99622448979592	1.01	61	904	4	25	13	1	0	2	1	0	0	15.0	
i 1	10.996836734693877	1.01	63	194	2	27	15	1	1501	2	1	0	0	16.0	
i 1	10.997857142857143	1.01	61	194	2	27	3	1	1501	2	1	0	0	16.0	
i 1	10.998265306122448	1.01	63	904	4	14	16	1	0	2	1	0	0	17.0	
i 1	10.999489795918368	1.01	61	904	4	25	12	16	0	1	16	0	0	15.0	
i 1	11.000306122448979	1.01	63	904	4	14	5	16	0	1	16	0	0	17.0	
i 1	11.002551020408163	1.01	63	194	2	12	1	1	1501	1	1	0	0	16.0	
i 1	11.00295918367347	1.01	63	194	2	12	5	1	1501	1	1	0	0	16.0	
i 1	11.496020408163265	0.505	61	588	4	13	4	1	0	1	1	0	0	14.0	
i 1	11.498877551020408	0.505	61	588	4	25	9	1	0	2	1	0	0	15.0	
i 1	11.499081632653061	0.505	63	588	4	13	11	1	0	1	1	0	0	14.0	
i 1	11.503367346938775	0.505	61	588	4	25	11	1	0	1	1	0	0	15.0	
i 1	11.749285714285714	0.2525	61	1170	3	16	16	1	0	2	1	0	0	16.0	
i 1	11.751530612244897	0.2525	63	1170	3	26	8	1	0	2	1	0	0	15.0	
i 1	11.75295918367347	0.2525	63	1170	3	26	4	16	0	1	16	0	0	15.0	
i 1	11.753163265306123	0.2525	63	1170	3	16	14	16	0	1	16	0	0	16.0	
i 1	11.995408163265306	2.02	63	199	4	13	5	1	0	2	1	0	0	14.0	
i 1	11.996836734693877	2.02	61	1083	3	16	8	16	0	1	16	0	0	16.0	
i 1	11.99704081632653	3.0300000000000002	63	697	2	12	9	16	0	1	16	0	0	16.0	
i 1	11.997857142857143	3.0300000000000002	63	697	2	12	12	1	0	2	1	0	0	16.0	
i 1	11.998265306122448	3.0300000000000002	63	697	2	27	4	16	0	2	16	0	0	16.0	
i 1	11.999081632653061	2.02	63	1083	3	16	2	16	0	1	16	0	0	16.0	
i 1	11.999897959183674	2.02	63	697	4	25	7	16	0	1	16	0	0	15.0	
i 1	12.001326530612245	3.0300000000000002	61	697	2	27	2	1	0	1	1	0	0	16.0	
i 1	12.001734693877552	2.02	63	697	4	25	6	16	0	2	16	0	0	15.0	
i 1	12.001938775510204	2.02	61	697	4	14	15	16	0	2	16	0	0	17.0	
i 1	12.001938775510204	2.02	61	1083	3	26	12	16	0	1	16	0	0	15.0	
i 1	12.002755102040817	2.02	61	697	4	14	1	16	0	1	16	0	0	17.0	
i 1	12.003979591836735	2.02	61	199	4	25	7	16	0	2	16	0	0	15.0	
i 1	12.00438775510204	2.02	63	199	4	13	12	16	0	2	16	0	0	14.0	
i 1	12.004591836734694	2.02	63	199	4	25	7	1	0	1	1	0	0	15.0	
i 1	12.004795918367346	2.02	61	1083	3	26	15	1	0	2	1	0	0	15.0	
i 1	13.995408163265306	3.535	61	697	4	25	13	1	0	1	1	0	0	15.0	
i 1	13.99561224489796	1.01	61	1083	4	14	14	1	0	2	1	0	0	17.0	
i 1	13.996428571428572	2.02	63	199	4	16	11	1	0	1	1	0	0	16.0	
i 1	13.998061224489796	2.02	63	199	4	26	11	16	0	2	16	0	0	15.0	
i 1	13.999693877551021	1.01	61	1083	4	25	1	1	0	1	1	0	0	15.0	
i 1	14.000918367346939	1.01	63	1083	4	14	9	16	0	2	16	0	0	17.0	
i 1	14.001122448979592	1.01	63	1083	4	25	9	1	0	2	1	0	0	15.0	
i 1	14.001530612244897	3.535	61	697	4	25	12	16	0	2	16	0	0	15.0	
i 1	14.002755102040817	2.02	63	199	4	26	4	16	0	2	16	0	0	15.0	
i 1	14.003571428571428	3.535	61	697	4	13	2	1	0	1	1	0	0	14.0	
i 1	14.00438775510204	2.02	63	199	4	16	14	16	0	2	16	0	0	16.0	
i 1	14.005	3.535	63	697	4	13	10	16	0	1	16	0	0	14.0	
i 1	14.996632653061225	2.02	61	199	5	14	10	1	0	1	1	0	0	17.0	
i 1	14.99704081632653	1.01	63	1083	2	27	12	1	0	2	1	0	0	16.0	
i 1	14.99765306122449	1.01	61	1083	2	27	7	1	0	2	1	0	0	16.0	
i 1	14.998061224489796	1.01	61	1083	2	12	12	1	0	1	1	0	0	16.0	
i 1	14.999285714285714	2.02	61	199	5	14	11	16	0	1	16	0	0	17.0	
i 1	14.999693877551021	2.02	63	199	5	25	2	1	0	2	1	0	0	15.0	
i 1	15.000918367346939	1.01	61	1083	2	12	11	16	0	2	16	0	0	16.0	
i 1	15.00377551020408	2.02	63	199	5	25	7	16	0	2	16	0	0	15.0	
i 1	15.996836734693877	1.01	61	1083	3	16	4	1	0	1	1	0	0	16.0	
i 1	15.99765306122449	1.01	61	697	2	12	4	16	0	1	16	0	0	16.0	
i 1	15.998673469387755	1.01	63	697	2	27	1	1	0	1	1	0	0	16.0	
i 1	15.998877551020408	1.01	61	1083	3	26	14	1	0	2	1	0	0	15.0	
i 1	15.999489795918368	1.01	61	1083	3	26	6	1	0	2	1	0	0	15.0	
i 1	16.000918367346937	1.01	63	697	2	27	8	1	0	2	1	0	0	16.0	
i 1	16.0015306122449	1.01	63	1083	3	16	16	1	0	2	1	0	0	16.0	
i 1	16.005	1.01	61	697	2	12	16	1	0	1	1	0	0	16.0	
i 1	16.997448979591837	1.01	61	1195	4	25	7	16	0	1	16	0	0	15.0	
i 1	16.99826530612245	1.01	63	1195	3	26	12	16	0	2	16	0	0	15.0	
i 1	16.998673469387754	0.505	61	879	2	27	14	16	0	2	16	0	0	16.0	
i 1	16.999489795918368	0.505	61	879	2	12	16	16	0	1	16	0	0	16.0	
i 1	16.99969387755102	1.01	63	1195	3	16	11	16	0	1	16	0	0	16.0	
i 1	16.999897959183674	1.01	63	1195	4	14	3	16	0	1	16	0	0	17.0	
i 1	17.000102040816326	0.505	61	879	2	12	13	16	0	1	16	0	0	16.0	
i 1	17.000714285714285	1.01	63	1195	4	14	1	16	0	1	16	0	0	17.0	
i 1	17.002959183673468	1.01	61	1195	3	16	16	1	0	1	1	0	0	16.0	
i 1	17.00316326530612	1.01	61	1195	4	25	12	16	0	2	16	0	0	15.0	
i 1	17.003979591836735	0.505	63	879	2	27	9	1	0	1	1	0	0	16.0	
i 1	17.004591836734694	1.01	63	1195	3	26	3	16	0	1	16	0	0	15.0	
i 1	17.495816326530612	0.505	63	613	4	25	16	1	0	2	1	0	0	15.0	
i 1	17.496224489795917	0.505	61	880	2	27	2	1	0	1	1	0	0	16.0	
i 1	17.500510204081632	0.505	61	613	4	25	12	16	0	2	16	0	0	15.0	
i 1	17.50173469387755	0.505	61	613	4	13	13	16	0	2	16	0	0	14.0	
i 1	17.50173469387755	0.505	63	880	2	12	14	1	0	2	1	0	0	16.0	
i 1	17.50316326530612	0.505	61	880	2	12	15	1	0	2	1	0	0	16.0	
i 1	17.504183673469388	0.505	61	613	4	13	15	1	0	2	1	0	0	14.0	
i 1	17.504795918367346	0.505	61	880	2	27	13	1	0	1	1	0	0	16.0	
i 1	17.995204081632654	2.02	63	705	4	13	9	1	0	1	1	0	0	14.0	
i 1	17.99561224489796	3.0300000000000002	63	207	4	16	2	16	0	1	16	0	0	16.0	
i 1	17.996224489795917	1.01	63	1091	4	25	12	1	0	1	1	0	0	15.0	
i 1	17.996224489795917	2.02	61	705	4	25	16	1	0	2	1	0	0	15.0	
i 1	17.998877551020406	2.02	61	705	4	25	5	1	0	1	1	0	0	15.0	
i 1	17.998877551020406	3.0300000000000002	63	207	4	26	9	16	0	1	16	0	0	15.0	
i 1	17.999081632653063	0.505	61	1091	2	27	1	1	0	2	1	0	0	16.0	
i 1	18.000102040816326	3.0300000000000002	63	207	4	16	11	16	0	1	16	0	0	16.0	
i 1	18.000510204081632	1.01	61	1091	4	14	11	16	0	2	16	0	0	17.0	
i 1	18.001326530612246	0.505	63	1091	2	12	2	1	0	2	1	0	0	16.0	
i 1	18.001326530612246	0.505	63	1091	2	27	16	16	0	1	16	0	0	16.0	
i 1	18.002959183673468	3.0300000000000002	63	207	4	26	15	16	0	2	16	0	0	15.0	
i 1	18.003367346938777	1.01	63	1091	4	14	6	16	0	1	16	0	0	17.0	
i 1	18.003367346938777	2.02	61	705	4	13	2	16	0	2	16	0	0	14.0	
i 1	18.003367346938777	1.01	63	1091	4	25	1	16	0	2	16	0	0	15.0	
i 1	18.003775510204083	0.505	61	1091	2	12	8	16	0	1	16	0	0	16.0	
i 1	18.495	0.505	63	3	3	27	13	16	0	2	16	0	0	16.0	
i 1	18.499897959183674	0.505	63	3	3	12	16	1	0	2	1	0	0	16.0	
i 1	18.50357142857143	0.505	61	3	3	27	14	16	0	2	16	0	0	16.0	
i 1	18.504795918367346	0.505	61	3	3	12	10	16	0	2	16	0	0	16.0	
i 1	18.996020408163265	2.02	61	207	3	27	10	1	0	1	1	0	0	16.0	
i 1	18.99969387755102	2.02	63	909	4	14	15	16	0	1	16	0	0	17.0	
i 1	19.00030612244898	2.02	61	909	4	25	11	1	0	2	1	0	0	15.0	
i 1	19.003367346938777	2.02	63	207	3	12	1	1	0	1	1	0	0	16.0	
i 1	19.00357142857143	2.02	63	909	4	25	1	16	0	1	16	0	0	15.0	
i 1	19.003775510204083	2.02	61	909	4	14	9	16	0	1	16	0	0	17.0	
i 1	19.004795918367346	2.02	63	207	3	27	13	16	0	2	16	0	0	16.0	
i 1	19.005	2.02	63	207	3	12	8	16	0	1	16	0	0	16.0	
i 1	19.995204081632654	2.525	63	593	4	25	2	16	0	1	16	0	0	15.0	
i 1	19.995408163265306	2.525	63	593	4	13	4	16	0	2	16	0	0	14.0	
i 1	19.999897959183674	2.525	63	593	4	25	10	1	0	2	1	0	0	15.0	
i 1	20.000102040816326	2.525	61	593	4	13	8	1	0	2	1	0	0	14.0	
i 1	20.995	1.01	61	277	3	27	14	1	0	1	1	0	0	16.0	
i 1	20.995816326530612	1.01	61	1091	4	14	16	1	0	2	1	0	0	17.0	
i 1	20.995816326530612	2.02	61	1091	3	16	14	1	0	1	1	0	0	16.0	
i 1	20.99683673469388	1.01	61	1091	4	25	2	16	0	2	16	0	0	15.0	
i 1	20.99683673469388	1.01	61	277	3	27	11	1	0	1	1	0	0	16.0	
i 1	20.998061224489796	1.01	63	277	3	12	12	16	0	2	16	0	0	16.0	
i 1	20.998877551020406	2.02	63	1091	3	16	10	16	0	2	16	0	0	16.0	
i 1	20.999489795918368	2.02	63	1091	3	26	6	16	0	2	16	0	0	15.0	
i 1	21.001122448979594	1.01	63	1091	4	14	3	1	0	2	1	0	0	17.0	
i 1	21.001122448979594	1.01	61	277	3	12	1	16	0	1	16	0	0	16.0	
i 1	21.001938775510204	1.01	61	1091	4	25	14	1	0	1	1	0	0	15.0	
i 1	21.002142857142857	2.02	63	1091	3	26	3	16	0	2	16	0	0	15.0	
i 1	21.996020408163265	1.01	61	705	4	14	14	16	0	2	16	0	0	17.0	
i 1	21.998061224489796	1.5150000000000001	61	389	3	12	1	1	1502	2	1	0	0	16.0	
i 1	21.998061224489796	1.01	61	705	4	25	3	1	0	2	1	0	0	15.0	
i 1	21.9984693877551	1.01	63	705	4	14	12	1	0	1	1	0	0	17.0	
i 1	21.998673469387754	1.5150000000000001	61	389	3	12	15	1	1502	2	1	0	0	16.0	
i 1	22.00173469387755	1.5150000000000001	63	389	3	27	16	1	1502	2	1	0	0	16.0	
i 1	22.002959183673468	1.5150000000000001	61	389	3	27	14	16	1502	1	16	0	0	16.0	
i 1	22.003979591836735	1.01	63	705	4	25	14	16	0	2	16	0	0	15.0	
i 1	22.497448979591837	0.505	61	389	4	13	9	1	0	1	1	0	0	14.0	
i 1	22.498673469387754	0.505	63	389	4	25	13	1	0	2	1	0	0	15.0	
i 1	22.49969387755102	0.505	63	389	4	25	10	16	0	1	16	0	0	15.0	
i 1	22.50438775510204	0.505	61	389	4	13	12	16	0	1	16	0	0	14.0	
i 1	22.997857142857143	0.505	61	700	4	25	3	16	0	1	16	0	0	15.0	
i 1	22.998673469387754	0.505	61	700	4	13	14	16	0	2	16	0	0	14.0	
i 1	22.998673469387754	0.505	63	700	4	13	1	1	0	2	1	0	0	14.0	
i 1	22.999081632653063	0.505	63	384	4	16	6	1	0	1	1	0	0	16.0	
i 1	22.999897959183674	1.01	61	1198	4	25	6	16	0	2	16	0	0	15.0	
i 1	23.000102040816326	0.505	61	384	4	26	12	1	0	2	1	0	0	15.0	
i 1	23.00030612244898	1.01	63	1198	4	14	8	1	0	1	1	0	0	17.0	
i 1	23.00030612244898	1.01	61	1198	4	25	4	1	0	1	1	0	0	15.0	
i 1	23.000918367346937	0.505	63	384	4	16	4	16	0	1	16	0	0	16.0	
i 1	23.002755102040815	1.01	63	1198	4	14	15	1	0	2	1	0	0	17.0	
i 1	23.003775510204083	0.505	63	384	4	26	11	1	0	2	1	0	0	15.0	
i 1	23.004795918367346	0.505	61	700	4	25	11	1	0	1	1	0	0	15.0	
i 1	23.495408163265306	2.2725	61	229	4	16	2	16	0	1	16	0	0	16.0	
i 1	23.495408163265306	1.01	61	931	4	25	7	16	0	2	16	0	0	15.0	
i 1	23.495816326530612	2.2725	61	229	4	26	13	1	0	1	1	0	0	15.0	
i 1	23.49969387755102	1.01	61	931	4	25	7	16	0	2	16	0	0	15.0	
i 1	23.500510204081632	2.2725	63	229	4	16	14	16	0	1	16	0	0	16.0	
i 1	23.500510204081632	0.505	63	616	3	27	9	1	0	1	1	0	0	16.0	
i 1	23.500918367346937	1.01	63	931	4	13	6	1	0	1	1	0	0	14.0	
i 1	23.500918367346937	0.505	63	616	3	12	16	16	0	1	16	0	0	16.0	
i 1	23.50234693877551	2.2725	61	229	4	26	10	1	0	2	1	0	0	15.0	
i 1	23.502959183673468	1.01	61	931	4	13	8	16	0	1	16	0	0	14.0	
i 1	23.50316326530612	0.505	63	616	3	27	5	16	0	1	16	0	0	16.0	
i 1	23.50438775510204	0.505	63	616	3	12	5	1	0	2	1	0	0	16.0	
i 1	23.997040816326532	1.01	63	727	3	12	9	1	0	1	1	0	0	16.0	
i 1	23.99826530612245	1.01	63	727	3	27	16	1	0	2	1	0	0	16.0	
i 1	23.999285714285715	1.01	61	1113	4	25	14	1	0	2	1	0	0	15.0	
i 1	23.99969387755102	1.01	61	727	3	27	8	1	0	2	1	0	0	16.0	
i 1	24.00030612244898	1.01	61	1113	4	25	13	16	0	2	16	0	0	15.0	
i 1	24.001326530612246	1.01	63	1113	4	14	14	16	0	2	16	0	0	17.0	
i 1	24.00316326530612	1.01	61	727	3	12	9	1	0	2	1	0	0	16.0	
i 1	24.003367346938777	1.01	61	1113	4	14	14	16	0	2	16	0	0	17.0	
i 1	24.495	1.01	63	727	4	13	3	16	0	2	16	0	0	14.0	
i 1	24.496224489795917	1.01	61	727	4	25	13	1	0	2	1	0	0	15.0	
i 1	24.49969387755102	1.01	63	727	4	13	2	1	0	2	1	0	0	14.0	
i 1	24.499897959183674	1.01	61	727	4	25	12	1	0	2	1	0	0	15.0	
i 1	24.995	1.01	61	229	3	12	7	1	0	1	1	0	0	16.0	
i 1	24.99561224489796	1.01	63	931	4	25	14	16	0	1	16	0	0	15.0	
i 1	24.996020408163265	1.01	63	931	4	14	8	16	0	1	16	0	0	17.0	
i 1	24.997857142857143	1.01	63	931	4	14	1	1	0	1	1	0	0	17.0	
i 1	25.001122448979594	1.01	61	931	4	25	3	1	0	1	1	0	0	15.0	
i 1	25.002551020408163	1.01	63	229	3	27	16	1	0	2	1	0	0	16.0	
i 1	25.00357142857143	1.01	61	229	3	27	10	16	0	1	16	0	0	16.0	
i 1	25.00438775510204	1.01	61	229	3	12	9	16	0	2	16	0	0	16.0	
i 1	25.499489795918368	0.505	63	615	4	25	4	1	0	1	1	0	0	15.0	
i 1	25.50357142857143	0.505	63	615	4	13	6	1	0	1	1	0	0	14.0	
i 1	25.50357142857143	0.505	63	615	4	25	14	1	0	2	1	0	0	15.0	
i 1	25.505	0.505	63	615	4	13	11	1	0	2	1	0	0	14.0	
i 1	25.745816326530612	0.2525	61	1197	3	16	5	1	0	2	1	0	0	16.0	
i 1	25.74765306122449	0.2525	63	1197	3	26	7	16	0	2	16	0	0	15.0	
i 1	25.749081632653063	0.2525	61	1197	3	26	5	16	0	1	16	0	0	15.0	
i 1	25.752755102040815	0.2525	63	1197	3	16	12	16	0	2	16	0	0	16.0	
i 1	25.995816326530612	2.02	61	695	4	25	3	1	1507	2	1	0	0	15.0	
i 1	25.99642857142857	0.505	61	1081	3	16	1	16	0	1	16	0	0	16.0	
i 1	25.99642857142857	0.505	61	1081	3	26	11	16	0	1	16	0	0	15.0	
i 1	25.99683673469388	2.02	61	695	4	14	8	16	1507	1	16	0	0	17.0	
i 1	25.99765306122449	2.02	61	379	3	12	14	1	1507	2	1	0	0	16.0	
i 1	25.999081632653063	1.5150000000000001	63	695	4	13	7	16	1505	2	16	0	0	14.0	
i 1	25.999489795918368	1.5150000000000001	63	695	4	13	2	16	1505	2	16	0	0	14.0	
i 1	25.999489795918368	2.02	61	379	3	27	4	1	1507	1	1	0	0	16.0	
i 1	25.999897959183674	1.5150000000000001	61	695	4	25	8	1	1505	1	1	0	0	15.0	
i 1	26.000510204081632	2.02	63	695	4	25	14	1	1507	2	1	0	0	15.0	
i 1	26.0015306122449	1.5150000000000001	61	695	4	25	3	16	1505	2	16	0	0	15.0	
i 1	26.00173469387755	2.02	63	695	4	14	3	1	1507	2	1	0	0	17.0	
i 1	26.002551020408163	2.02	61	379	3	12	11	16	1507	2	16	0	0	16.0	
i 1	26.003775510204083	0.505	61	1081	3	26	8	1	0	1	1	0	0	15.0	
i 1	26.003979591836735	0.505	63	1081	3	16	2	1	0	2	1	0	0	16.0	
i 1	26.003979591836735	2.02	63	379	3	27	1	1	1507	2	1	0	0	16.0	
i 1	26.495	0.505	61	903	3	16	12	1	0	1	1	0	0	16.0	
i 1	26.49642857142857	0.505	63	903	3	26	10	1	0	2	1	0	0	15.0	
i 1	26.498877551020406	0.505	61	903	3	16	9	1	0	2	1	0	0	16.0	
i 1	26.502959183673468	0.505	61	903	3	26	16	1	0	2	1	0	0	15.0	
i 1	26.996224489795917	0.505	63	1088	3	26	8	1	0	1	1	0	0	15.0	
i 1	26.997857142857143	0.505	63	1088	3	26	4	16	0	1	16	0	0	15.0	
i 1	27.003367346938777	0.505	61	1088	3	16	3	1	0	2	1	0	0	16.0	
i 1	27.005	0.505	61	1088	3	16	15	1	0	1	1	0	0	16.0	
i 1	27.495204081632654	0.2525	63	589	4	25	10	1	0	1	1	0	0	15.0	
i 1	27.495204081632654	0.505	61	91	4	26	16	16	0	2	16	0	0	15.0	
i 1	27.49561224489796	0.2525	61	589	4	25	5	16	0	2	16	0	0	15.0	
i 1	27.49683673469388	0.2525	61	589	4	13	2	1	0	1	1	0	0	14.0	
i 1	27.500102040816326	0.2525	63	589	4	13	15	16	0	1	16	0	0	14.0	
i 1	27.50357142857143	0.505	63	91	4	16	13	1	0	2	1	0	0	16.0	
i 1	27.504591836734694	0.505	63	91	4	16	10	16	0	1	16	0	0	16.0	
i 1	27.504795918367346	0.505	61	91	4	26	11	16	0	1	16	0	0	15.0	
i 1	27.749489795918368	0.2525	63	358	4	25	4	16	0	2	16	0	0	15.0	
i 1	27.750102040816326	0.2525	63	358	4	25	5	16	0	1	16	0	0	15.0	
i 1	27.75438775510204	0.2525	61	358	4	13	2	1	0	1	1	0	0	14.0	
i 1	27.75438775510204	0.2525	63	358	4	13	10	16	0	2	16	0	0	14.0	
i 1	27.995	2.02	61	214	3	27	12	16	0	1	16	0	0	16.0	
i 1	27.99561224489796	2.02	63	600	4	25	13	1	0	1	1	0	0	15.0	
i 1	27.99561224489796	3.0300000000000002	61	214	4	26	13	16	0	1	16	0	0	15.0	
i 1	27.995816326530612	2.02	61	600	4	25	8	16	0	2	16	0	0	15.0	
i 1	27.99683673469388	3.0300000000000002	61	214	4	16	15	1	0	2	1	0	0	16.0	
i 1	27.99683673469388	3.0300000000000002	63	214	4	16	5	1	0	2	1	0	0	16.0	
i 1	27.997040816326532	3.0300000000000002	61	214	4	26	9	1	0	1	1	0	0	15.0	
i 1	27.997244897959185	2.02	61	600	4	13	16	1	0	1	1	0	0	14.0	
i 1	27.997244897959185	2.02	61	214	3	27	6	16	0	1	16	0	0	16.0	
i 1	27.998673469387754	2.02	61	916	4	25	4	16	0	2	16	0	0	15.0	
i 1	27.999897959183674	2.02	61	916	4	14	12	16	0	1	16	0	0	17.0	
i 1	27.999897959183674	2.02	63	600	4	13	6	16	0	2	16	0	0	14.0	
i 1	28.001122448979594	2.02	61	214	3	12	3	16	0	1	16	0	0	16.0	
i 1	28.001122448979594	2.02	63	916	4	25	5	1	0	2	1	0	0	15.0	
i 1	28.00316326530612	2.02	63	916	4	14	10	1	0	1	1	0	0	17.0	
i 1	28.00438775510204	2.02	63	214	3	12	12	1	0	1	1	0	0	16.0	
i 1	29.995408163265306	3.535	61	712	4	13	16	1	1508	2	1	0	0	14.0	
i 1	29.996020408163265	1.01	61	712	3	27	12	1	0	1	1	0	0	16.0	
i 1	29.998061224489796	3.535	63	712	4	25	4	16	1508	2	16	0	0	15.0	
i 1	29.999285714285715	1.01	63	1098	4	25	13	16	0	2	16	0	0	15.0	
i 1	29.999285714285715	1.01	63	1098	4	25	7	1	0	2	1	0	0	15.0	
i 1	30.000510204081632	1.01	63	1098	4	14	13	16	0	1	16	0	0	17.0	
i 1	30.00173469387755	1.01	63	1098	4	14	12	1	0	1	1	0	0	17.0	
i 1	30.001938775510204	1.01	63	712	3	27	9	16	0	1	16	0	0	16.0	
i 1	30.00234693877551	3.535	63	712	4	13	6	16	1508	1	16	0	0	14.0	
i 1	30.002551020408163	3.535	63	712	4	25	8	1	1508	1	1	0	0	15.0	
i 1	30.00316326530612	1.01	63	712	3	12	16	16	0	1	16	0	0	16.0	
i 1	30.00357142857143	1.01	63	712	3	12	11	16	0	2	16	0	0	16.0	
i 1	30.995	0.505	61	10	4	26	6	16	0	2	16	0	0	15.0	
i 1	30.99561224489796	0.505	61	396	3	12	5	16	0	1	16	0	0	16.0	
i 1	30.995816326530612	0.505	61	10	5	14	4	1	1508	2	1	0	0	17.0	
i 1	30.997244897959185	0.505	63	10	5	14	15	1	1508	2	1	0	0	17.0	
i 1	30.997244897959185	0.505	61	396	3	12	8	1	0	1	1	0	0	16.0	
i 1	30.99826530612245	0.505	63	10	4	26	15	16	0	2	16	0	0	15.0	
i 1	30.999081632653063	0.505	63	396	3	27	3	1	0	1	1	0	0	16.0	
i 1	30.999489795918368	0.505	63	10	4	16	5	16	0	1	16	0	0	16.0	
i 1	31.002551020408163	0.505	63	10	5	25	5	16	1508	2	16	0	0	15.0	
i 1	31.002755102040815	0.505	63	10	5	25	5	1	1508	1	1	0	0	15.0	
i 1	31.00316326530612	0.505	61	10	4	16	12	16	0	2	16	0	0	16.0	
i 1	31.004591836734694	0.505	61	396	3	27	12	1	0	1	1	0	0	16.0	
i 1	31.495408163265306	0.505	63	1190	4	14	16	16	0	1	16	0	0	17.0	
i 1	31.49765306122449	0.505	63	376	4	26	12	16	0	2	16	0	0	15.0	
i 1	31.497857142857143	0.505	63	1190	2	12	16	16	0	1	16	0	0	16.0	
i 1	31.498877551020406	0.505	63	376	4	16	9	16	0	1	16	0	0	16.0	
i 1	31.499489795918368	0.505	61	1190	4	14	4	16	0	2	16	0	0	17.0	
i 1	31.500714285714285	0.505	61	1190	2	12	14	1	0	1	1	0	0	16.0	
i 1	31.501326530612246	0.505	63	1190	2	27	15	1	0	1	1	0	0	16.0	
i 1	31.5015306122449	0.505	63	1190	4	25	5	16	0	1	16	0	0	15.0	
i 1	31.501938775510204	0.505	61	1190	4	25	8	1	0	2	1	0	0	15.0	
i 1	31.502551020408163	0.505	63	376	4	16	9	1	0	2	1	0	0	16.0	
i 1	31.502755102040815	0.505	63	1190	2	27	11	1	0	1	1	0	0	16.0	
i 1	31.504591836734694	0.505	63	376	4	26	10	1	0	1	1	0	0	15.0	
i 1	31.99683673469388	1.01	61	1078	4	25	5	16	0	1	16	0	0	15.0	
i 1	31.997040816326532	1.7675	61	194	4	16	6	16	0	1	16	0	0	16.0	
i 1	31.997857142857143	1.01	63	194	3	27	11	1	0	1	1	0	0	16.0	
i 1	31.99826530612245	1.7675	63	194	4	26	6	1	0	1	1	0	0	15.0	
i 1	31.999081632653063	1.7675	61	194	4	16	13	1	0	1	1	0	0	16.0	
i 1	31.999897959183674	1.01	63	194	3	27	13	1	0	2	1	0	0	16.0	
i 1	32.001122448979594	1.01	61	194	3	12	16	16	0	2	16	0	0	16.0	
i 1	32.00173469387755	1.01	61	1078	4	14	9	16	0	1	16	0	0	17.0	
i 1	32.00316326530612	1.01	63	1078	4	14	11	1	0	1	1	0	0	17.0	
i 1	32.003367346938774	1.7675	63	194	4	26	10	16	0	1	16	0	0	15.0	
i 1	32.004183673469385	1.01	61	194	3	12	5	16	0	1	16	0	0	16.0	
i 1	32.005	1.01	63	1078	4	25	5	1	0	1	1	0	0	15.0	
i 1	32.99826530612245	1.01	63	896	4	25	13	1	0	2	1	0	0	15.0	
i 1	32.9984693877551	1.01	61	896	4	25	12	1	0	2	1	0	0	15.0	
i 1	32.99928571428571	1.01	61	194	2	12	14	16	0	1	16	0	0	16.0	
i 1	33.00010204081633	1.01	63	896	4	14	4	16	0	2	16	0	0	17.0	
i 1	33.00030612244898	1.01	61	194	2	12	14	16	0	2	16	0	0	16.0	
i 1	33.00295918367347	1.01	63	194	2	27	7	1	0	2	1	0	0	16.0	
i 1	33.00397959183673	1.01	63	194	2	27	11	1	0	1	1	0	0	16.0	
i 1	33.0045918367347	1.01	63	896	4	14	5	1	0	1	1	0	0	17.0	
i 1	33.49520408163265	0.505	63	580	4	13	13	1	0	2	1	0	0	14.0	
i 1	33.498877551020406	0.505	63	580	4	13	2	1	0	1	1	0	0	14.0	
i 1	33.50071428571429	0.505	61	580	4	25	15	16	0	2	16	0	0	15.0	
i 1	33.5045918367347	0.505	63	580	4	25	8	1	0	2	1	0	0	15.0	
i 1	33.74765306122449	0.2525	61	1162	3	16	14	16	0	2	16	0	0	16.0	
i 1	33.748877551020406	0.2525	61	1162	3	16	16	16	0	1	16	0	0	16.0	
i 1	33.7545918367347	0.2525	61	1162	3	26	2	16	0	1	16	0	0	15.0	
i 1	33.755	0.2525	63	1162	3	26	13	16	0	1	16	0	0	15.0	
i 1	33.9954081632653	3.0300000000000002	63	695	4	14	8	16	0	1	16	0	0	17.0	
i 1	33.995612244897956	3.0300000000000002	61	695	4	25	7	1	0	2	1	0	0	15.0	
i 1	33.996632653061226	3.0300000000000002	61	197	4	25	4	16	0	1	16	0	0	15.0	
i 1	33.99785714285714	3.0300000000000002	63	1081	3	16	15	16	0	2	16	0	0	16.0	
i 1	33.9984693877551	3.0300000000000002	61	1081	3	16	8	16	0	2	16	0	0	16.0	
i 1	33.998673469387754	3.0300000000000002	63	695	4	14	2	1	0	2	1	0	0	17.0	
i 1	33.998673469387754	3.0300000000000002	61	695	2	27	8	16	0	2	16	0	0	16.0	
i 1	33.998877551020406	3.0300000000000002	61	695	4	25	11	1	0	2	1	0	0	15.0	
i 1	33.99908163265306	3.0300000000000002	63	1081	3	26	13	1	0	2	1	0	0	15.0	
i 1	34.00071428571429	3.0300000000000002	63	1081	3	26	8	16	0	1	16	0	0	15.0	
i 1	34.0015306122449	3.0300000000000002	63	695	2	12	16	1	0	1	1	0	0	16.0	
i 1	34.00214285714286	3.0300000000000002	63	695	2	12	15	16	0	2	16	0	0	16.0	
i 1	34.00255102040816	3.0300000000000002	61	197	4	13	4	16	0	1	16	0	0	14.0	
i 1	34.00255102040816	3.0300000000000002	63	695	2	27	3	1	0	1	1	0	0	16.0	
i 1	34.00316326530612	3.0300000000000002	61	197	4	25	10	1	0	1	1	0	0	15.0	
i 1	34.004387755102044	3.0300000000000002	61	197	4	13	1	1	0	1	1	0	0	14.0	
t0 30
</CsScore>
</CsoundSynthesizer>

