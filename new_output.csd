; started: 8/13/18 
; last edit: 4/30/23 
<CsoundSynthesizer> 
 
<CsOptions> 
; use the following for writing to a file -G is to create a postscript eps output file of function tables 
; -o dac ; live play 
 ; -o /home/prent/Music/sflib/ball9.wav -W -G -m2 -3  ; for CoreOS
 -o /home/prent/Music/sflib/ball9.wav -W -G -m2 -3 ; for kubernetes
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

f1500.0 0.0 256.0 -6.0 1.0 128.0 1.000867 128.0 1.001734 
f1501.0 0.0 256.0 -6.0 1.0 128.0 0.9945425 128.0 0.989085 
f1502.0 0.0 256.0 -6.0 1.0 128.0 0.9936864999999999 128.0 0.987373 
;Inst	Sta	Hold	Vel	Ton	Oct	Voi	Ste	En1	Gls	Ups	Ren	2gl	3gl	Vol
i 1	0.00657142857142857	5.3025	71	397	2	4	11	2	0	-1	2	0	0	2.0	
i 1	0.006571428571428572	6.0600000000000005	74	397	2	4	3	2	0	-1	2	0	0	2.0	
i 1	0.0071972789115646255	5.8075	71	895	2	4	2	8	0	-2	8	0	0	2.0	
i 1	0.009074829931972788	11.3625	71	397	2	24	16	2	0	-1	2	0	0	2.0	
i 1	0.009700680272108842	7.575	71	895	2	4	13	8	0	-2	8	0	0	2.0	
i 1	0.010326530612244898	4.545	71	397	2	24	9	2	0	-2	2	0	0	2.0	
i 1	0.012829931972789114	20.4525	71	895	2	24	6	2	0	-2	2	0	0	2.0	
i 1	0.014707482993197279	15.9075	74	895	2	24	16	2	0	-2	2	0	0	2.0	
i 1	4.500312925170068	0.2525	71	397	2	24	7	2	0	-2	2	0	0	2.0	
i 1	4.745306122448979	4.04	71	397	2	24	9	2	0	-2	2	0	0	2.0	
i 1	5.261578231292517	0.2525	71	397	2	4	15	2	0	-1	2	0	0	2.0	
i 1	5.499061224489796	4.04	71	397	2	4	4	2	0	-1	2	0	0	2.0	
i 1	5.734666666666667	0.2525	71	895	2	4	6	8	0	-2	8	0	0	2.0	
i 1	5.992176870748299	2.02	71	895	2	4	1	8	0	-2	8	0	0	2.0	
i 1	5.999687074829932	0.2525	74	397	2	4	4	2	0	-1	2	0	0	2.0	
i 1	6.255319727891156	0.2525	74	397	2	4	3	2	0	-1	2	0	0	2.0	
i 1	6.484666666666667	0.2525	74	397	2	4	15	2	0	-1	2	0	0	2.0	
i 1	6.759074829931973	8.3325	74	397	2	4	9	2	0	-1	2	0	0	2.0	
i 1	7.509074829931973	0.2525	71	895	2	4	1	8	0	-2	8	0	0	2.0	
i 1	7.742802721088435	0.505	71	895	2	4	8	8	0	-2	8	0	0	2.0	
i 1	8.003442176870749	0.2525	71	895	2	4	3	8	0	-2	8	0	0	2.0	
i 1	8.252190476190476	21.4625	71	895	2	4	4	8	0	-2	8	0	0	2.0	
i 1	8.252816326530612	0.505	71	895	2	4	1	8	0	-2	8	0	0	2.0	
i 1	8.745931972789116	0.2525	71	397	2	24	14	2	0	-2	2	0	0	2.0	
i 1	8.759074829931972	0.505	71	895	2	4	14	8	0	-2	8	0	0	2.0	
i 1	9.002816326530612	2.525	71	397	2	24	10	2	0	-2	2	0	0	2.0	
i 1	9.250938775510203	0.2525	71	895	2	4	9	8	0	-2	8	0	0	2.0	
i 1	9.499061224489797	0.7575000000000001	71	895	2	4	16	8	0	-2	8	0	0	2.0	
i 1	9.502816326530612	0.2525	71	397	2	4	9	2	0	-1	2	0	0	2.0	
i 1	9.747183673469388	0.2525	71	397	2	4	8	2	0	-1	2	0	0	2.0	
i 1	9.988421768707482	0.2525	71	397	2	4	10	2	0	-1	2	0	0	2.0	
i 1	10.243428571428572	0.7575000000000001	71	397	2	4	11	2	0	-1	2	0	0	2.0	
i 1	10.264707482993197	0.2525	71	895	2	4	2	8	0	-2	8	0	0	2.0	
i 1	10.495931972789116	0.2525	71	895	2	4	12	8	0	-2	8	0	0	2.0	
i 1	10.735918367346938	0.2525	71	895	2	4	10	8	0	-2	8	0	0	2.0	
i 1	10.987170068027211	23.23	71	895	2	4	10	8	0	-2	8	0	0	2.0	
i 1	11.010326530612245	0.2525	71	397	2	4	1	2	0	-1	2	0	0	2.0	
i 1	11.240925170068028	0.505	71	397	2	4	1	2	0	-1	2	0	0	2.0	
i 1	11.264707482993197	0.2525	71	397	2	24	16	2	0	-1	2	0	0	2.0	
i 1	11.494054421768707	0.2525	71	397	2	24	1	2	0	-2	2	0	0	2.0	
i 1	11.502190476190476	0.7575000000000001	71	397	2	24	5	2	0	-1	2	0	0	2.0	
i 1	11.744680272108843	0.2525	71	397	2	4	9	2	0	-1	2	0	0	2.0	
i 1	11.753442176870749	1.7675	71	397	2	24	5	2	0	-2	2	0	0	2.0	
i 1	11.992802721088436	1.2625	71	397	2	4	9	2	0	-1	2	0	0	2.0	
i 1	12.237170068027211	0.2525	71	397	2	24	14	2	0	-1	2	0	0	2.0	
i 1	12.485292517006803	0.2525	71	397	2	24	15	2	0	-1	2	0	0	2.0	
i 1	12.744680272108843	0.505	71	397	2	24	2	2	0	-1	2	0	0	2.0	
i 1	13.234666666666667	0.2525	71	397	2	4	16	2	0	-1	2	0	0	2.0	
i 1	13.25156462585034	2.7775	71	397	2	24	8	2	0	-1	2	0	0	2.0	
i 1	13.48904761904762	0.7575000000000001	71	397	2	4	14	2	0	-1	2	0	0	2.0	
i 1	13.512204081632653	0.7575000000000001	71	397	2	24	11	2	0	-2	2	0	0	2.0	
i 1	14.234666666666667	0.505	71	397	2	24	1	2	0	-2	2	0	0	2.0	
i 1	14.247809523809524	0.2525	71	397	2	4	9	2	0	-1	2	0	0	2.0	
i 1	14.515333333333333	2.02	71	397	2	4	2	2	0	-1	2	0	0	2.0	
i 1	14.749687074829932	0.2525	71	397	3	24	8	2	0	-2	2	0	0	2.0	
i 1	15.008448979591837	0.505	74	397	2	4	4	2	0	-1	2	0	0	2.0	
i 1	15.010326530612245	7.3225	71	397	2	24	11	2	0	-2	2	0	0	2.0	
i 1	15.486544217687074	2.525	74	397	2	4	1	2	0	-1	2	0	0	2.0	
i 1	15.761578231292518	0.2525	74	895	2	24	3	2	0	-2	2	0	0	2.0	
i 1	15.992176870748299	0.2525	74	895	2	24	15	2	0	-2	2	0	0	2.0	
i 1	16.004068027210884	0.2525	71	397	2	24	8	2	0	-1	2	0	0	2.0	
i 1	16.25344217687075	0.2525	74	895	2	24	6	2	0	-2	2	0	0	2.0	
i 1	16.259700680272108	1.5150000000000001	71	397	2	24	12	2	0	-1	2	0	0	2.0	
i 1	16.508448979591837	11.11	74	895	2	24	9	2	0	-2	2	0	0	2.0	
i 1	16.510326530612247	0.2525	71	397	2	4	16	2	0	-1	2	0	0	2.0	
i 1	16.760952380952382	1.7675	71	397	2	4	12	2	0	-1	2	0	0	2.0	
i 1	17.76408163265306	0.2525	71	397	2	24	2	2	0	-1	2	0	0	2.0	
i 1	17.991551020408163	1.01	71	397	2	24	2	2	0	-1	2	0	0	2.0	
i 1	18.015333333333334	0.2525	74	397	2	4	9	2	0	-1	2	0	0	2.0	
i 1	18.259700680272108	1.01	74	397	2	4	13	2	0	-1	2	0	0	2.0	
i 1	18.510952380952382	0.2525	71	397	2	4	13	2	0	-1	2	0	0	2.0	
i 1	18.7647074829932	1.01	71	397	2	4	1	2	0	-1	2	0	0	2.0	
i 1	19.00657142857143	0.2525	71	397	3	24	9	2	0	-1	2	0	0	2.0	
i 1	19.25344217687075	0.2525	74	397	2	4	5	2	0	-1	2	0	0	2.0	
i 1	19.260326530612247	2.2725	71	397	2	24	4	2	0	-1	2	0	0	2.0	
i 1	19.508448979591837	2.2725	74	397	2	4	4	2	0	-1	2	0	0	2.0	
i 1	19.747183673469387	0.505	71	397	2	4	10	2	0	-1	2	0	0	2.0	
i 1	20.23591836734694	0.2525	71	895	2	24	3	2	0	-2	2	0	0	2.0	
i 1	20.26282993197279	10.1	71	397	2	4	4	2	0	-1	2	0	0	2.0	
i 1	20.487795918367347	0.2525	71	895	2	24	11	2	0	-2	2	0	0	2.0	
i 1	20.754068027210884	0.505	71	895	2	24	2	2	0	-2	2	0	0	2.0	
i 1	21.239673469387753	5.555	71	895	2	24	16	2	0	-2	2	0	0	2.0	
i 1	21.4921768707483	0.2525	71	397	3	24	10	2	0	-1	2	0	0	2.0	
i 1	21.74655782312925	1.7675	71	397	2	24	8	2	0	-1	2	0	0	2.0	
i 1	21.75657142857143	0.2525	74	397	2	4	7	2	0	-1	2	0	0	2.0	
i 1	21.994680272108845	1.01	74	397	2	4	3	2	0	-1	2	0	0	2.0	
i 1	22.237795918367347	0.505	71	397	3	24	13	2	0	-2	2	0	0	2.0	
i 1	22.73717006802721	2.2725	71	397	2	24	13	2	0	-2	2	0	0	2.0	
i 1	23.000938775510203	0.2525	74	397	2	4	12	2	0	-1	2	0	0	2.0	
i 1	23.237795918367347	0.7575000000000001	74	397	2	4	10	2	0	-1	2	0	0	2.0	
i 1	23.508448979591837	0.505	71	397	3	24	15	2	0	-1	2	0	0	2.0	
i 1	23.994680272108845	1.01	74	397	2	4	1	2	0	-1	2	0	0	2.0	
i 1	24.009074829931972	1.2625	71	397	2	24	3	2	0	-1	2	0	0	2.0	
i 1	24.9852925170068	0.2525	71	397	3	24	16	2	0	-2	2	0	0	2.0	
i 1	25.009700680272108	1.5150000000000001	74	397	2	4	10	2	0	-1	2	0	0	2.0	
i 1	25.241551020408163	0.505	71	397	2	24	3	2	0	-2	2	0	0	2.0	
i 1	25.260326530612247	0.2525	71	397	3	24	11	2	0	-1	2	0	0	2.0	
i 1	25.492802721088434	0.505	71	397	2	24	8	2	0	-1	2	0	0	2.0	
i 1	25.7647074829932	0.2525	71	397	3	24	5	2	0	-2	2	0	0	2.0	
i 1	25.992802721088434	0.505	71	397	3	24	9	2	0	-1	2	0	0	2.0	
i 1	26.00469387755102	1.2625	71	397	2	24	6	2	0	-2	2	0	0	2.0	
i 1	26.49405442176871	1.7675	71	397	2	24	2	2	0	-1	2	0	0	2.0	
i 1	26.50469387755102	0.2525	74	397	2	4	12	2	0	-1	2	0	0	2.0	
i 1	26.734666666666666	0.2525	74	397	2	4	14	2	0	-1	2	0	0	2.0	
i 1	26.760952380952382	0.2525	71	895	2	24	15	2	0	-2	2	0	0	2.0	
i 1	26.997809523809522	0.2525	74	397	2	4	8	2	0	-1	2	0	0	2.0	
i 1	27.00469387755102	0.7575000000000001	71	895	2	24	12	2	0	-2	2	0	0	2.0	
i 1	27.236544217687076	4.545	74	397	2	4	12	2	0	-1	2	0	0	2.0	
i 1	27.263455782312924	0.2525	71	397	3	24	16	2	0	-2	2	0	0	2.0	
i 1	27.490925170068028	0.2525	74	895	2	24	13	2	0	-2	2	0	0	2.0	
i 1	27.50469387755102	5.555	71	397	2	24	8	2	0	-2	2	0	0	2.0	
i 1	27.734666666666666	0.2525	71	895	2	24	14	2	0	-2	2	0	0	2.0	
i 1	27.73591836734694	0.2525	74	895	2	24	16	2	0	-2	2	0	0	2.0	
i 1	28.009074829931972	0.2525	74	895	2	24	8	2	0	-2	2	0	0	2.0	
i 1	28.0147074829932	0.505	71	895	2	24	7	2	0	-2	2	0	0	2.0	
i 1	28.25469387755102	0.505	74	895	2	24	7	2	0	-2	2	0	0	2.0	
i 1	28.262204081632653	0.2525	71	397	3	24	14	2	0	-1	2	0	0	2.0	
i 1	28.491551020408163	0.7575000000000001	71	397	2	24	5	2	0	-1	2	0	0	2.0	
i 1	28.50469387755102	0.2525	71	895	2	24	6	2	0	-2	2	0	0	2.0	
i 1	28.75657142857143	0.2525	74	895	2	24	6	2	0	-2	2	0	0	2.0	
i 1	28.76282993197279	0.2525	71	895	2	24	4	2	0	-2	2	0	0	2.0	
i 1	28.986544217687076	0.7575000000000001	74	895	2	24	10	2	0	-2	2	0	0	2.0	
i 1	28.989047619047618	0.2525	71	895	2	24	4	2	0	-2	2	0	0	2.0	
i 1	29.249061224489797	0.2525	71	397	3	24	14	2	0	-1	2	0	0	2.0	
i 1	29.258448979591837	4.04	71	895	2	24	14	2	0	-2	2	0	0	2.0	
i 1	29.484666666666666	3.2825	71	397	2	24	9	2	0	-1	2	0	0	2.0	
i 1	29.509074829931972	0.2525	71	895	2	4	10	8	0	-2	8	0	0	2.0	
i 1	29.752190476190478	1.5150000000000001	71	895	2	4	15	8	0	-2	8	0	0	2.0	
i 1	29.754068027210884	0.2525	74	895	2	24	10	2	0	-2	2	0	0	2.0	
i 1	29.990299319727892	1.01	74	895	2	24	10	2	0	-2	2	0	0	2.0	
i 1	30.24530612244898	0.505	71	397	2	4	15	2	0	-1	2	0	0	2.0	
i 1	30.740925170068028	3.0300000000000002	71	397	2	4	1	2	0	-1	2	0	0	2.0	
i 1	30.98591836734694	0.2525	74	895	2	24	8	2	0	-2	2	0	0	2.0	
i 1	31.24405442176871	0.2525	71	895	2	4	3	8	0	-2	8	0	0	2.0	
i 1	31.24843537414966	1.2625	74	895	2	24	4	2	0	-2	2	0	0	2.0	
i 1	31.490299319727892	0.7575000000000001	71	895	2	4	10	8	0	-2	8	0	0	2.0	
i 1	31.744680272108845	0.2525	74	397	2	4	12	2	0	-1	2	0	0	2.0	
i 1	32.00657142857143	6.565	74	397	2	4	3	2	0	-1	2	0	0	2.0	
i 1	32.25657142857143	0.2525	71	895	2	4	5	8	0	-2	8	0	0	2.0	
i 1	32.50469387755102	0.2525	74	895	2	24	12	2	0	-2	2	0	0	2.0	
i 1	32.51408163265306	1.01	71	895	2	4	11	8	0	-2	8	0	0	2.0	
i 1	32.73591836734694	0.2525	71	397	3	24	6	2	0	-1	2	0	0	2.0	
i 1	32.74655782312925	5.3025	74	895	2	24	11	2	0	-2	2	0	0	2.0	
i 1	32.99843537414966	0.2525	71	397	3	24	1	2	0	-2	2	0	0	2.0	
i 1	33.00469387755102	1.2625	71	397	2	24	3	2	0	-1	2	0	0	2.0	
i 1	33.25344217687075	0.2525	71	895	2	24	3	2	0	-2	2	0	0	2.0	
i 1	33.25719727891156	1.5150000000000001	71	397	2	24	8	2	0	-2	2	0	0	2.0	
i 1	33.49280272108844	0.2525	71	895	2	4	6	8	0	-2	8	0	0	2.0	
i 1	33.50657142857143	1.7675	71	895	2	24	5	2	0	-2	2	0	0	2.0	
i 1	33.75344217687075	0.2525	71	397	3	4	16	2	0	-1	2	0	0	2.0	
i 1	33.76282993197279	1.7675	71	895	2	4	12	8	0	-2	8	0	0	2.0	
i 1	33.98466666666667	0.2525	71	895	2	4	14	8	0	-2	8	0	0	2.0	
i 1	33.9921768707483	1.01	71	397	2	4	9	2	0	-1	2	0	0	2.0	
i 1	34.244680272108845	0.2525	71	895	2	4	8	8	0	-2	8	0	0	2.0	
i 1	34.25594557823129	0.2525	71	397	3	24	4	2	0	-1	2	0	0	2.0	
i 1	34.50031292517007	2.02	71	397	2	24	16	2	0	-1	2	0	0	2.0	
i 1	34.51220408163265	0.2525	71	895	2	4	14	8	0	-2	8	0	0	2.0	
i 1	34.755319727891155	0.2525	71	397	3	24	8	2	0	-2	2	0	0	2.0	
i 1	34.76408163265306	3.0300000000000002	71	895	2	4	1	8	0	-2	8	0	0	2.0	
i 1	35.00156462585034	0.2525	71	397	3	4	7	2	0	-1	2	0	0	2.0	
i 1	35.01533333333333	3.2825	71	397	2	24	2	2	0	-2	2	0	0	2.0	
i 1	35.25469387755102	0.2525	71	895	2	24	1	2	0	-2	2	0	0	2.0	
i 1	35.26032653061225	4.04	71	397	2	4	15	2	0	-1	2	0	0	2.0	
i 1	35.49843537414966	0.2525	71	895	2	4	8	8	0	-2	8	0	0	2.0	
i 1	35.50031292517007	0.2525	71	895	2	24	8	2	0	-2	2	0	0	2.0	
i 1	35.74718367346939	0.2525	71	895	2	4	1	8	0	-2	8	0	0	2.0	
i 1	35.75719727891156	0.2525	71	895	2	24	10	2	0	-2	2	0	0	2.0	
i 1	35.98717006802721	0.2525	71	895	2	24	16	2	0	-2	2	0	0	2.0	
i 1	36.0078231292517	0.2525	71	895	2	4	14	8	0	-2	8	0	0	2.0	
i 1	36.236544217687076	0.2525	71	895	2	24	14	2	0	-2	2	0	0	2.0	
i 1	36.254068027210884	0.7575000000000001	71	895	2	4	2	8	0	-2	8	0	0	2.0	
i 1	36.48466666666667	0.2525	71	397	3	24	5	2	0	-1	2	0	0	2.0	
i 1	36.49718367346939	0.2525	71	895	2	24	2	2	0	-2	2	0	0	2.0	
i 1	36.740925170068024	0.2525	71	895	2	24	10	2	0	-2	2	0	0	2.0	
i 1	36.759074829931976	2.02	71	397	2	24	15	2	0	-1	2	0	0	2.0	
i 1	37.00719727891156	0.505	71	895	2	4	16	8	0	-2	8	0	0	2.0	
i 1	37.01408163265306	0.505	71	895	2	24	8	2	0	-2	2	0	0	2.0	
i 1	37.49342857142857	0.505	71	895	2	4	6	8	0	-2	8	0	0	2.0	
i 1	37.50719727891156	0.2525	71	895	2	24	1	2	0	-2	2	0	0	2.0	
i 1	37.74405442176871	0.2525	71	895	2	24	1	2	0	-2	2	0	0	2.0	
i 1	37.764707482993195	0.2525	71	895	2	4	2	8	0	-2	8	0	0	2.0	
i 1	37.985292517006805	3.2825	74	783	2	24	12	2	0	-1	2	0	0	2.0	
i 1	37.98842176870748	0.2525	74	783	2	24	2	2	0	-2	2	0	0	2.0	
i 1	38.00281632653061	2.02	74	783	2	4	9	2	0	-1	2	0	0	2.0	
i 1	38.00719727891156	2.525	71	783	2	4	1	8	0	-1	8	0	0	2.0	
i 1	38.24155102040816	0.7575000000000001	74	783	2	24	11	2	0	-2	2	0	0	2.0	
i 1	38.26408163265306	0.2525	71	397	3	24	5	2	0	-2	2	0	0	2.0	
i 1	38.50031292517007	0.2525	74	397	3	4	13	2	0	-1	2	0	0	2.0	
i 1	38.50281632653061	1.01	71	397	2	24	3	2	0	-2	2	0	0	2.0	
i 1	38.76095238095238	0.2525	71	397	3	24	16	2	0	-1	2	0	0	2.0	
i 1	38.76157823129252	2.02	74	397	2	4	6	2	0	-1	2	0	0	2.0	
i 1	38.986544217687076	0.7575000000000001	71	397	2	24	10	2	0	-1	2	0	0	2.0	
i 1	38.98967346938775	0.2525	74	783	2	24	12	2	0	-2	2	0	0	2.0	
i 1	39.23466666666667	0.2525	71	397	3	4	9	2	0	-1	2	0	0	2.0	
i 1	39.25970068027211	3.2825	74	783	2	24	7	2	0	-2	2	0	0	2.0	
i 1	39.49280272108844	0.2525	71	397	3	24	12	2	0	-2	2	0	0	2.0	
i 1	39.50844897959184	0.7575000000000001	71	397	2	4	1	2	0	-1	2	0	0	2.0	
i 1	39.73591836734694	2.02	71	397	2	24	12	2	0	-2	2	0	0	2.0	
i 1	39.73779591836735	0.2525	71	397	3	24	16	2	0	-1	2	0	0	2.0	
i 1	40.00281632653061	0.2525	74	783	2	4	8	2	0	-1	2	0	0	2.0	
i 1	40.01408163265306	31.5625	71	397	2	24	8	2	0	-1	2	0	0	2.0	
i 1	40.24718367346939	0.2525	71	397	3	4	3	2	0	-1	2	0	0	2.0	
i 1	40.25344217687075	2.2725	74	783	2	4	4	2	0	-1	2	0	0	2.0	
i 1	40.49968707482993	0.2525	71	783	2	4	4	8	0	-1	8	0	0	2.0	
i 1	40.51220408163265	1.01	71	397	2	4	5	2	0	-1	2	0	0	2.0	
i 1	40.73466666666667	1.7675	71	783	2	4	9	8	0	-1	8	0	0	2.0	
i 1	40.76032653061225	0.505	74	397	3	4	15	2	0	-1	2	0	0	2.0	
i 1	41.24530612244898	0.2525	74	783	2	24	13	2	0	-1	2	0	0	2.0	
i 1	41.25281632653061	0.7575000000000001	74	397	2	4	8	2	0	-1	2	0	0	2.0	
i 1	41.48967346938775	0.2525	71	397	3	4	2	2	0	-1	2	0	0	2.0	
i 1	41.514707482993195	1.01	74	783	2	24	3	2	0	-1	2	0	0	2.0	
i 1	41.7578231292517	0.2525	71	397	3	24	14	2	0	-2	2	0	0	2.0	
i 1	41.76220408163265	0.505	71	397	2	4	8	2	0	-1	2	0	0	2.0	
i 1	41.98842176870748	0.505	71	397	2	24	13	2	0	-2	2	0	0	2.0	
i 1	42.01533333333333	0.2525	74	397	3	4	5	2	0	-1	2	0	0	2.0	
i 1	42.235292517006805	0.2525	71	397	3	4	6	2	0	-1	2	0	0	2.0	
i 1	42.23717006802721	29.29	74	397	2	4	13	2	0	-1	2	0	0	2.0	
i 1	42.48717006802721	0.2525	71	397	3	24	2	2	0	-2	2	0	0	2.0	
i 1	42.48842176870748	0.2525	71	397	2	4	3	2	0	-1	2	0	0	2.0	
i 1	42.49342857142857	29.0375	74	895	2	4	14	8	0	-1	8	0	0	2.0	
i 1	42.50719727891156	29.0375	71	895	2	24	11	2	0	-2	2	0	0	2.0	
i 1	42.51157823129252	29.0375	74	895	2	4	4	8	0	-1	8	0	0	2.0	
i 1	42.51533333333333	29.0375	71	895	2	24	10	2	0	-2	2	0	0	2.0	
i 1	42.744680272108845	28.785	71	397	2	24	11	2	0	-2	2	0	0	2.0	
i 1	42.74780952380952	0.2525	71	397	3	4	14	2	0	-1	2	0	0	2.0	
i 1	42.9921768707483	28.5325	71	397	2	4	3	2	0	-1	2	0	0	2.0	
i 1	71.24593197278912	4.7975	74	895	2	4	12	8	0	-1	8	0	0	3.2903102703027813	
i 1	71.2490612244898	7.8275	74	397	2	4	2	2	0	-1	2	0	0	3.2903102703027813	
i 1	71.25031292517006	4.7975	74	895	2	4	13	8	0	-1	8	0	0	3.2903102703027813	
i 1	71.2509387755102	4.7975	71	895	2	24	13	2	0	-2	2	0	0	3.2903102703027813	
i 1	71.25156462585034	7.8275	71	397	2	24	14	2	0	-1	2	0	0	3.2903102703027813	
i 1	71.25657142857143	7.8275	71	397	2	4	5	2	0	-1	2	0	0	3.2903102703027813	
i 1	71.26032653061225	7.8275	71	397	2	24	9	2	0	-2	2	0	0	3.2903102703027813	
i 1	71.26095238095238	4.7975	71	895	2	24	6	2	0	-2	2	0	0	3.2903102703027813	
i 1	75.98591836734694	4.545	74	579	2	24	14	2	0	-2	2	0	0	3.2903102703027813	
i 1	75.98591836734694	4.545	74	579	2	4	14	8	0	-1	8	0	0	3.2903102703027813	
i 1	75.98842176870748	4.545	71	579	2	4	6	8	0	-2	8	0	0	3.2903102703027813	
i 1	76.00907482993198	4.545	74	579	2	24	5	8	0	-1	8	0	0	3.2903102703027813	
i 1	78.98904761904762	21.715	74	193	2	4	15	8	0	-2	8	0	0	3.2903102703027813	
i 1	78.98967346938775	24.240000000000002	71	193	2	24	2	2	0	-1	2	0	0	3.2903102703027813	
i 1	78.9921768707483	22.9775	71	193	2	4	13	2	0	-1	2	0	0	3.2903102703027813	
i 1	79.00156462585034	26.26	74	193	2	24	9	2	0	-2	2	0	0	3.2903102703027813	
i 1	80.49155102040817	29.795	71	691	2	24	2	2	0	-1	2	0	0	3.2903102703027813	
i 1	80.4990612244898	33.835	71	691	2	4	13	2	0	-2	2	0	0	3.2903102703027813	
i 1	80.50406802721088	24.4925	74	691	2	24	12	8	0	-2	8	0	0	3.2903102703027813	
i 1	80.50844897959183	33.835	74	691	2	4	3	2	0	-1	2	0	0	3.2903102703027813	
i 1	100.50719727891156	0.2525	74	193	2	4	12	8	0	-2	8	0	0	3.2903102703027813	
i 1	100.74342857142857	1.2625	74	193	2	4	4	8	0	-2	8	0	0	3.2903102703027813	
i 1	101.74468027210884	0.2525	71	193	2	4	13	2	0	-1	2	0	0	3.2903102703027813	
i 1	102.00657142857143	0.7575000000000001	71	193	2	4	13	2	0	-1	2	0	0	3.2903102703027813	
i 1	102.0147074829932	0.2525	74	193	2	4	10	8	0	-2	8	0	0	3.2903102703027813	
i 1	102.26345578231293	0.2525	74	193	2	4	3	8	0	-2	8	0	0	3.2903102703027813	
i 1	102.4852925170068	0.2525	74	193	2	4	14	8	0	-2	8	0	0	3.2903102703027813	
i 1	102.7490612244898	1.5150000000000001	74	193	2	4	16	8	0	-2	8	0	0	3.2903102703027813	
i 1	102.76157823129252	0.2525	71	193	2	4	2	2	0	-1	2	0	0	3.2903102703027813	
i 1	103.00657142857143	3.7875	71	193	2	4	8	2	0	-1	2	0	0	3.2903102703027813	
i 1	103.01032653061225	0.2525	71	193	3	24	8	2	0	-1	2	0	0	3.2903102703027813	
i 1	103.2509387755102	1.2625	71	193	2	24	16	2	0	-1	2	0	0	3.2903102703027813	
i 1	104.24092517006802	0.2525	74	193	2	4	13	8	0	-2	8	0	0	3.2903102703027813	
i 1	104.5009387755102	1.2625	74	193	2	4	12	8	0	-2	8	0	0	3.2903102703027813	
i 1	104.50406802721088	0.2525	71	193	3	24	3	2	0	-1	2	0	0	3.2903102703027813	
i 1	104.74843537414966	6.8175	71	193	2	24	9	2	0	-1	2	0	0	3.2903102703027813	
i 1	104.75531972789116	0.2525	74	691	2	24	6	8	0	-2	8	0	0	3.2903102703027813	
i 1	104.98717006802721	0.505	74	691	2	24	15	8	0	-2	8	0	0	3.2903102703027813	
i 1	104.99655782312925	0.2525	74	193	3	24	3	2	0	-2	2	0	0	3.2903102703027813	
i 1	105.23717006802721	8.8375	74	193	2	24	9	2	0	-2	2	0	0	3.2903102703027813	
i 1	105.50657142857143	0.2525	74	691	2	24	1	8	0	-2	8	0	0	3.2903102703027813	
i 1	105.73842176870748	0.2525	74	193	2	4	15	8	0	-2	8	0	0	3.2903102703027813	
i 1	105.74092517006802	1.2625	74	691	2	24	10	8	0	-2	8	0	0	3.2903102703027813	
i 1	106.0078231292517	4.545	74	193	2	4	12	8	0	-2	8	0	0	3.2903102703027813	
i 1	106.75406802721088	0.2525	71	193	2	4	16	2	0	-1	2	0	0	3.2903102703027813	
i 1	106.98842176870748	1.5150000000000001	71	193	2	4	6	2	0	-1	2	0	0	3.2903102703027813	
i 1	106.99342857142857	0.2525	74	691	2	24	6	8	0	-2	8	0	0	3.2903102703027813	
i 1	107.24593197278912	0.2525	74	691	2	24	6	8	0	-2	8	0	0	3.2903102703027813	
i 1	107.51095238095238	0.2525	74	691	2	24	10	8	0	-2	8	0	0	3.2903102703027813	
i 1	107.73904761904762	1.5150000000000001	74	691	2	24	11	8	0	-2	8	0	0	3.2903102703027813	
i 1	108.50344217687075	0.505	71	193	2	4	4	2	0	-1	2	0	0	3.2903102703027813	
i 1	108.9921768707483	5.05	71	193	2	4	16	2	0	-1	2	0	0	3.2903102703027813	
i 1	109.24968707482994	0.7575000000000001	74	691	2	24	12	8	0	-2	8	0	0	3.2903102703027813	
i 1	109.9990612244898	0.2525	74	691	2	24	9	8	0	-2	8	0	0	3.2903102703027813	
i 1	110.01032653061225	0.2525	71	691	2	24	1	2	0	-1	2	0	0	3.2903102703027813	
i 1	110.23591836734694	0.7575000000000001	71	691	2	24	13	2	0	-1	2	0	0	3.2903102703027813	
i 1	110.23842176870748	0.2525	74	691	2	24	10	8	0	-2	8	0	0	3.2903102703027813	
i 1	110.4852925170068	2.525	74	691	2	24	11	8	0	-2	8	0	0	3.2903102703027813	
i 1	110.4902993197279	0.2525	74	193	2	4	1	8	0	-2	8	0	0	3.2903102703027813	
i 1	110.75657142857143	1.01	74	193	2	4	8	8	0	-2	8	0	0	3.2903102703027813	
i 1	111.01220408163265	0.2525	71	691	2	24	10	2	0	-1	2	0	0	3.2903102703027813	
i 1	111.2471836734694	1.01	71	691	2	24	1	2	0	-1	2	0	0	3.2903102703027813	
i 1	111.50344217687075	0.2525	71	193	3	24	14	2	0	-1	2	0	0	3.2903102703027813	
i 1	111.73466666666667	0.2525	74	193	2	4	10	8	0	-2	8	0	0	3.2903102703027813	
i 1	111.74405442176871	0.2525	71	193	2	24	7	2	0	-1	2	0	0	3.2903102703027813	
i 1	111.9921768707483	1.5150000000000001	74	193	2	4	6	8	0	-2	8	0	0	3.2903102703027813	
i 1	112.01282993197279	0.2525	71	193	3	24	2	2	0	-1	2	0	0	3.2903102703027813	
i 1	112.23842176870748	0.2525	71	193	2	24	3	2	0	-1	2	0	0	3.2903102703027813	
i 1	112.24342857142857	0.2525	71	691	2	24	1	2	0	-1	2	0	0	3.2903102703027813	
i 1	112.4852925170068	0.2525	71	193	3	24	1	2	0	-1	2	0	0	3.2903102703027813	
i 1	112.49342857142857	1.5150000000000001	71	691	2	24	1	2	0	-1	2	0	0	3.2903102703027813	
i 1	112.75531972789116	1.2625	71	193	2	24	11	2	0	-1	2	0	0	3.2903102703027813	
i 1	112.98654421768707	0.505	74	691	2	24	1	8	0	-2	8	0	0	3.2903102703027813	
i 1	113.49342857142857	0.2525	74	193	2	4	5	8	0	-2	8	0	0	3.2903102703027813	
i 1	113.49405442176871	0.2525	74	691	2	24	5	8	0	-2	8	0	0	3.2903102703027813	
i 1	113.73904761904762	0.2525	74	193	2	4	13	8	0	-2	8	0	0	3.2903102703027813	
i 1	113.74593197278912	0.2525	74	691	2	24	16	8	0	-2	8	0	0	3.2903102703027813	
i 1	113.98967346938775	1.2625	71	922	2	4	1	8	0	-2	8	0	0	3.2903102703027813	
i 1	113.99968707482994	4.545	71	922	2	4	10	8	0	-2	8	0	0	3.2903102703027813	
i 1	114.0009387755102	0.2525	71	922	2	24	11	2	0	-2	2	0	0	3.2903102703027813	
i 1	114.0028163265306	1.01	71	922	2	24	1	2	0	-2	2	0	0	3.2903102703027813	
i 1	114.00844897959183	3.7875	74	922	2	24	8	2	0	-1	2	0	0	3.2903102703027813	
i 1	114.01220408163265	5.555	71	922	2	4	1	8	0	-2	8	0	0	3.2903102703027813	
i 1	114.01345578231293	4.545	71	922	2	4	15	2	0	-1	2	0	0	3.2903102703027813	
i 1	114.0147074829932	0.2525	71	922	2	24	14	2	0	-1	2	0	0	3.2903102703027813	
i 1	114.2421768707483	0.2525	71	922	2	24	1	2	0	-2	2	0	0	3.2903102703027813	
i 1	114.25907482993198	5.555	71	922	2	24	6	2	0	-1	2	0	0	3.2903102703027813	
i 1	114.48654421768707	2.2725	71	922	2	24	3	2	0	-2	2	0	0	3.2903102703027813	
i 1	114.99780952380952	0.2525	71	922	2	24	9	2	0	-2	2	0	0	3.2903102703027813	
i 1	115.24780952380952	2.02	71	922	2	24	7	2	0	-2	2	0	0	3.2903102703027813	
i 1	115.26345578231293	0.7575000000000001	71	922	2	4	11	8	0	-2	8	0	0	3.2903102703027813	
i 1	115.99280272108844	0.2525	71	922	2	4	2	8	0	-2	8	0	0	3.2903102703027813	
i 1	116.2421768707483	0.2525	71	922	2	4	11	8	0	-2	8	0	0	3.2903102703027813	
i 1	116.49092517006802	0.505	71	922	2	4	7	8	0	-2	8	0	0	3.2903102703027813	
i 1	116.74092517006802	0.2525	71	922	2	24	1	2	0	-2	2	0	0	3.2903102703027813	
i 1	116.98654421768707	0.2525	71	922	2	4	5	8	0	-2	8	0	0	3.2903102703027813	
i 1	117.01032653061225	1.5150000000000001	71	922	2	24	6	2	0	-2	2	0	0	3.2903102703027813	
i 1	117.24280272108844	5.3025	71	922	2	4	5	8	0	-2	8	0	0	3.2903102703027813	
i 1	117.26095238095238	0.2525	71	922	2	24	5	2	0	-2	2	0	0	3.2903102703027813	
i 1	117.49405442176871	1.2625	71	922	2	24	14	2	0	-2	2	0	0	3.2903102703027813	
i 1	117.73967346938775	0.2525	74	922	2	24	16	2	0	-1	2	0	0	3.2903102703027813	
i 1	117.98717006802721	0.505	74	922	2	24	2	2	0	-1	2	0	0	3.2903102703027813	
i 1	118.48779591836735	2.525	71	220	2	24	5	2	0	-2	2	0	0	3.2903102703027813	
i 1	118.49280272108844	6.565	71	220	2	4	10	8	0	-1	8	0	0	3.2903102703027813	
i 1	118.50844897959183	2.7775	74	220	2	24	7	2	0	-1	2	0	0	3.2903102703027813	
i 1	118.50907482993198	9.8475	71	220	2	4	7	8	0	-2	8	0	0	3.2903102703027813	
i 1	118.76157823129252	0.2525	71	922	2	24	16	2	0	-2	2	0	0	3.2903102703027813	
i 1	119.01220408163265	1.01	71	922	2	24	2	2	0	-2	2	0	0	3.2903102703027813	
i 1	119.4971836734694	0.2525	71	922	2	4	8	8	0	-2	8	0	0	3.2903102703027813	
i 1	119.75719727891156	0.2525	71	922	2	24	4	2	0	-1	2	0	0	3.2903102703027813	
i 1	119.75907482993198	1.01	71	922	2	4	8	8	0	-2	8	0	0	3.2903102703027813	
i 1	119.98466666666667	0.2525	71	922	2	24	13	2	0	-2	2	0	0	3.2903102703027813	
i 1	119.9990612244898	5.3025	71	922	2	24	2	2	0	-1	2	0	0	3.2903102703027813	
i 1	120.25531972789116	0.2525	71	922	2	24	12	2	0	-2	2	0	0	3.2903102703027813	
i 1	120.50907482993198	0.2525	71	922	2	24	13	2	0	-2	2	0	0	3.2903102703027813	
i 1	120.7421768707483	0.2525	71	922	2	4	8	8	0	-2	8	0	0	3.2903102703027813	
i 1	120.75406802721088	1.01	71	922	2	24	16	2	0	-2	2	0	0	3.2903102703027813	
i 1	120.99968707482994	6.8175	71	922	2	4	1	8	0	-2	8	0	0	3.2903102703027813	
i 1	121.01157823129252	0.2525	71	220	2	24	13	2	0	-2	2	0	0	3.2903102703027813	
i 1	121.24780952380952	0.7575000000000001	71	220	2	24	10	2	0	-2	2	0	0	3.2903102703027813	
i 1	121.2578231292517	0.2525	74	220	2	24	8	2	0	-1	2	0	0	3.2903102703027813	
i 1	121.5028163265306	0.7575000000000001	74	220	2	24	11	2	0	-1	2	0	0	3.2903102703027813	
i 1	121.75219047619048	0.2525	71	922	2	24	3	2	0	-2	2	0	0	3.2903102703027813	
i 1	122.00719727891156	0.2525	71	220	2	24	11	2	0	-2	2	0	0	3.2903102703027813	
i 1	122.0097006802721	3.7875	71	922	2	24	16	2	0	-2	2	0	0	3.2903102703027813	
i 1	122.2402993197279	0.2525	74	220	2	24	15	2	0	-1	2	0	0	3.2903102703027813	
i 1	122.25844897959183	0.505	71	220	2	24	16	2	0	-2	2	0	0	3.2903102703027813	
i 1	122.49655782312925	1.01	74	220	2	24	4	2	0	-1	2	0	0	3.2903102703027813	
i 1	122.5078231292517	0.2525	71	922	2	4	8	8	0	-2	8	0	0	3.2903102703027813	
i 1	122.74468027210884	0.505	71	922	2	4	16	8	0	-2	8	0	0	3.2903102703027813	
i 1	122.75031292517006	0.505	71	220	2	24	2	2	0	-2	2	0	0	3.2903102703027813	
i 1	123.23591836734694	0.2525	71	922	2	4	7	8	0	-2	8	0	0	3.2903102703027813	
i 1	123.26220408163265	0.7575000000000001	71	220	2	24	10	2	0	-2	2	0	0	3.2903102703027813	
i 1	123.49092517006802	0.2525	74	220	2	24	5	2	0	-1	2	0	0	3.2903102703027813	
i 1	123.5097006802721	1.01	71	922	2	4	2	8	0	-2	8	0	0	3.2903102703027813	
i 1	123.74655782312925	2.525	74	220	2	24	16	2	0	-1	2	0	0	3.2903102703027813	
i 1	124.01157823129252	0.505	71	220	2	24	10	2	0	-2	2	0	0	3.2903102703027813	
i 1	124.48779591836735	0.2525	71	220	2	24	7	2	0	-2	2	0	0	3.2903102703027813	
i 1	124.50469387755102	0.2525	71	922	2	4	13	8	0	-2	8	0	0	3.2903102703027813	
i 1	124.7490612244898	1.2625	71	922	2	4	15	8	0	-2	8	0	0	3.2903102703027813	
i 1	124.7578231292517	0.2525	71	220	2	24	7	2	0	-2	2	0	0	3.2903102703027813	
i 1	125.00469387755102	7.07	71	220	2	24	2	2	0	-2	2	0	0	3.2903102703027813	
i 1	125.00594557823129	0.2525	71	220	2	4	7	8	0	-1	8	0	0	3.2903102703027813	
i 1	125.2352925170068	1.5150000000000001	71	220	2	4	10	8	0	-1	8	0	0	3.2903102703027813	
i 1	125.2402993197279	0.2525	71	922	2	24	6	2	0	-1	2	0	0	3.2903102703027813	
i 1	125.49092517006802	1.7675	71	922	2	24	6	2	0	-1	2	0	0	3.2903102703027813	
i 1	125.73904761904762	0.2525	71	922	2	24	15	2	0	-2	2	0	0	3.2903102703027813	
i 1	126.00406802721088	2.525	71	922	2	24	14	2	0	-2	2	0	0	3.2903102703027813	
i 1	126.01533333333333	0.2525	71	922	2	4	7	8	0	-2	8	0	0	3.2903102703027813	
i 1	126.24468027210884	0.2525	74	220	2	24	9	2	0	-1	2	0	0	3.2903102703027813	
i 1	126.25031292517006	3.7875	71	922	2	4	8	8	0	-2	8	0	0	3.2903102703027813	
i 1	126.49155102040817	2.525	74	220	2	24	15	2	0	-1	2	0	0	3.2903102703027813	
i 1	126.74280272108844	0.2525	71	220	2	4	9	8	0	-1	8	0	0	3.2903102703027813	
i 1	127.01157823129252	1.7675	71	220	2	4	15	8	0	-1	8	0	0	3.2903102703027813	
i 1	127.24342857142857	0.2525	71	922	2	24	14	2	0	-1	2	0	0	3.2903102703027813	
i 1	127.48904761904762	0.505	71	922	2	24	2	2	0	-1	2	0	0	3.2903102703027813	
i 1	127.73654421768707	0.2525	71	922	2	4	13	8	0	-2	8	0	0	3.2903102703027813	
i 1	127.98904761904762	0.2525	71	922	2	24	9	2	0	-1	2	0	0	3.2903102703027813	
i 1	128.0128299319728	2.7775	71	922	2	4	13	8	0	-2	8	0	0	3.2903102703027813	
i 1	128.25970068027212	1.2625	71	922	2	24	2	2	0	-1	2	0	0	3.2903102703027813	
i 1	128.26533333333333	0.2525	71	220	2	4	2	8	0	-2	8	0	0	3.2903102703027813	
i 1	128.4871700680272	5.555	71	220	2	4	2	8	0	-2	8	0	0	3.2903102703027813	
i 1	128.49280272108842	0.2525	71	922	2	24	4	2	0	-2	2	0	0	3.2903102703027813	
i 1	128.75657142857142	1.7675	71	922	2	24	11	2	0	-2	2	0	0	3.2903102703027813	
i 1	128.7647074829932	0.2525	71	220	2	4	14	8	0	-1	8	0	0	3.2903102703027813	
i 1	128.98654421768708	0.505	74	220	2	24	11	2	0	-1	2	0	0	3.2903102703027813	
i 1	129.00844897959183	2.7775	71	220	2	4	12	8	0	-1	8	0	0	3.2903102703027813	
i 1	129.4940544217687	0.2525	71	922	2	24	13	2	0	-1	2	0	0	3.2903102703027813	
i 1	129.49968707482992	0.2525	74	220	2	24	10	2	0	-1	2	0	0	3.2903102703027813	
i 1	129.7352925170068	12.8775	71	922	2	24	5	2	0	-1	2	0	0	3.2903102703027813	
i 1	129.75970068027212	0.2525	74	220	2	24	8	2	0	-1	2	0	0	3.2903102703027813	
i 1	130.00219047619046	0.2525	71	922	2	4	16	8	0	-2	8	0	0	3.2903102703027813	
i 1	130.01220408163266	0.2525	74	220	2	24	5	2	0	-1	2	0	0	3.2903102703027813	
i 1	130.24655782312925	0.7575000000000001	71	922	2	4	10	8	0	-2	8	0	0	3.2903102703027813	
i 1	130.2647074829932	0.2525	74	220	2	24	3	2	0	-1	2	0	0	3.2903102703027813	
i 1	130.49843537414966	2.02	74	220	2	24	12	2	0	-1	2	0	0	3.2903102703027813	
i 1	130.5147074829932	0.2525	71	922	2	24	5	2	0	-2	2	0	0	3.2903102703027813	
i 1	130.74593197278912	0.505	71	922	2	24	13	2	0	-2	2	0	0	3.2903102703027813	
i 1	130.74718367346938	0.2525	71	922	2	4	4	8	0	-2	8	0	0	3.2903102703027813	
i 1	130.99593197278912	0.505	71	922	2	4	5	8	0	-2	8	0	0	3.2903102703027813	
i 1	131.00531972789116	0.2525	71	922	2	4	13	8	0	-2	8	0	0	3.2903102703027813	
i 1	131.23779591836734	0.2525	71	922	2	24	2	2	0	-2	2	0	0	3.2903102703027813	
i 1	131.24342857142858	1.7675	71	922	2	4	15	8	0	-2	8	0	0	3.2903102703027813	
i 1	131.49843537414966	0.2525	71	922	2	4	10	8	0	-2	8	0	0	3.2903102703027813	
i 1	131.49968707482992	3.0300000000000002	71	922	2	24	7	2	0	-2	2	0	0	3.2903102703027813	
i 1	131.7352925170068	3.535	71	922	2	4	4	8	0	-2	8	0	0	3.2903102703027813	
i 1	131.75531972789116	0.2525	71	220	2	4	7	8	0	-1	8	0	0	3.2903102703027813	
i 1	131.99280272108842	0.7575000000000001	71	220	2	4	13	8	0	-1	8	0	0	3.2903102703027813	
i 1	131.9940544217687	0.505	71	220	2	24	3	2	0	-2	2	0	0	3.2903102703027813	
i 1	132.4852925170068	2.525	71	220	2	24	2	2	0	-2	2	0	0	3.2903102703027813	
i 1	132.5059455782313	0.2525	74	220	2	24	7	2	0	-1	2	0	0	3.2903102703027813	
i 1	132.75719727891158	0.2525	71	220	2	4	12	8	0	-1	8	0	0	3.2903102703027813	
i 1	132.75844897959183	2.7775	74	220	2	24	11	2	0	-1	2	0	0	3.2903102703027813	
i 1	132.99530612244897	2.7775	71	220	2	4	5	8	0	-1	8	0	0	3.2903102703027813	
i 1	132.99655782312925	0.505	71	922	2	4	3	8	0	-2	8	0	0	3.2903102703027813	
i 1	133.50719727891158	2.525	71	922	2	4	10	8	0	-2	8	0	0	3.2903102703027813	
i 1	133.99280272108842	0.505	71	220	2	4	11	8	0	-2	8	0	0	3.2903102703027813	
i 1	134.49029931972788	8.08	71	220	2	4	10	8	0	-2	8	0	0	3.2903102703027813	
i 1	134.4990612244898	0.2525	71	922	2	24	10	2	0	-2	2	0	0	3.2903102703027813	
i 1	134.7647074829932	7.8275	71	922	2	24	5	2	0	-2	2	0	0	3.2903102703027813	
i 1	135.01032653061225	0.2525	71	220	2	24	1	2	0	-2	2	0	0	3.2903102703027813	
i 1	135.23904761904762	0.2525	71	922	2	4	5	8	0	-2	8	0	0	3.2903102703027813	
i 1	135.24718367346938	1.01	71	220	2	24	11	2	0	-2	2	0	0	3.2903102703027813	
i 1	135.49092517006804	0.2525	74	220	2	24	8	2	0	-1	2	0	0	3.2903102703027813	
i 1	135.50907482993196	7.07	71	922	2	4	2	8	0	-2	8	0	0	3.2903102703027813	
i 1	135.73779591836734	0.2525	71	220	2	4	5	8	0	-1	8	0	0	3.2903102703027813	
i 1	135.74718367346938	6.8175	74	220	2	24	14	2	0	-1	2	0	0	3.2903102703027813	
i 1	135.9884217687075	6.565	71	220	2	4	7	8	0	-1	8	0	0	3.2903102703027813	
i 1	136.0128299319728	0.2525	71	922	2	4	12	8	0	-2	8	0	0	3.2903102703027813	
i 1	136.23466666666667	6.3125	71	922	2	4	9	8	0	-2	8	0	0	3.2903102703027813	
i 1	136.2578231292517	0.2525	71	220	2	24	11	2	0	-2	2	0	0	3.2903102703027813	
i 1	136.51220408163266	6.0600000000000005	71	220	2	24	7	2	0	-2	2	0	0	3.2903102703027813	
i 1	142.49280272108842	14.14	71	922	2	4	6	8	0	-2	8	0	0	3.87847370399517	
i 1	142.4940544217687	14.14	71	922	2	4	13	8	0	-2	8	0	0	3.87847370399517	
i 1	142.49593197278912	9.595	71	220	2	24	13	2	0	-2	2	0	0	3.87847370399517	
i 1	142.49968707482992	9.595	71	220	2	4	16	8	0	-1	8	0	0	3.87847370399517	
i 1	142.50156462585034	14.14	71	922	2	24	13	2	0	-2	2	0	0	3.87847370399517	
i 1	142.5115782312925	9.595	74	220	2	24	5	2	0	-1	2	0	0	3.87847370399517	
i 1	142.5147074829932	14.14	71	922	2	24	8	2	0	-1	2	0	0	3.87847370399517	
i 1	142.51533333333333	9.595	71	220	2	4	5	8	0	-2	8	0	0	3.87847370399517	
i 1	151.99092517006804	4.545	74	922	2	4	11	2	0	-2	2	0	0	3.87847370399517	
i 1	152.00281632653062	4.545	74	922	2	4	11	8	0	-1	8	0	0	3.87847370399517	
i 1	152.0059455782313	4.545	71	922	2	24	14	8	0	-2	8	0	0	3.87847370399517	
i 1	152.0078231292517	4.545	74	922	2	24	14	2	0	-1	2	0	0	3.87847370399517	
i 1	156.48779591836734	33.835	71	424	2	24	9	8	0	-2	8	0	0	3.87847370399517	
i 1	156.49092517006804	33.835	71	424	2	4	10	2	0	-1	2	0	0	3.87847370399517	
i 1	156.49593197278912	8.08	74	810	2	4	16	2	0	-1	2	0	0	3.87847370399517	
i 1	156.50219047619046	8.08	71	810	2	4	8	8	0	-2	8	0	0	3.87847370399517	
i 1	156.50844897959183	8.08	74	810	2	24	1	2	0	-1	2	0	0	3.87847370399517	
i 1	156.51032653061225	33.835	71	424	2	4	9	2	0	-1	2	0	0	3.87847370399517	
i 1	156.5128299319728	8.08	71	810	2	24	8	8	0	-1	8	0	0	3.87847370399517	
i 1	156.51345578231292	33.835	71	424	2	24	13	2	0	-1	2	0	0	3.87847370399517	
i 1	164.48967346938775	25.755	74	811	2	4	2	8	0	-2	8	0	0	3.87847370399517	
i 1	164.49029931972788	25.755	74	811	2	4	13	8	0	-2	8	0	0	3.87847370399517	
i 1	164.50531972789116	25.755	71	811	2	24	13	2	0	-1	2	0	0	3.87847370399517	
i 1	164.51220408163266	25.755	74	811	2	24	15	2	0	-1	2	0	0	3.87847370399517	
i 1	189.9871700680272	4.545	74	910	2	24	14	8	0	-2	8	0	0	3.87847370399517	
i 1	189.9871700680272	4.545	74	910	2	4	10	8	0	-2	8	0	0	3.87847370399517	
i 1	189.99092517006804	3.0300000000000002	74	594	2	4	5	8	0	-1	8	0	0	3.87847370399517	
i 1	189.99468027210884	3.0300000000000002	71	594	2	24	3	8	0	-2	8	0	0	3.87847370399517	
i 1	190.0009387755102	4.545	71	910	2	4	3	2	0	-2	2	0	0	3.87847370399517	
i 1	190.00469387755103	3.0300000000000002	71	594	2	24	10	2	0	-1	2	0	0	3.87847370399517	
i 1	190.01032653061225	3.0300000000000002	74	594	2	4	5	8	0	-1	8	0	0	3.87847370399517	
i 1	190.01345578231292	4.545	71	910	2	24	8	2	0	-1	2	0	0	3.87847370399517	
i 1	192.98591836734693	1.5150000000000001	72	412	2	24	9	1	0	0	1	0	0	3.87847370399517	
i 1	193.00469387755103	1.5150000000000001	69	412	2	24	9	1	0	-1	1	0	0	3.87847370399517	
i 1	193.00469387755103	1.5150000000000001	69	412	2	4	5	1	0	0	1	0	0	3.87847370399517	
i 1	193.0059455782313	1.5150000000000001	69	412	2	4	13	0	0	-1	0	0	0	3.87847370399517	
i 1	194.4871700680272	11.11	72	208	2	24	10	1	0	-1	1	0	0	3.87847370399517	
i 1	194.49780952380954	0.2525	69	208	2	4	16	0	0	-1	0	0	0	3.87847370399517	
i 1	194.49843537414966	1.7675	72	208	2	4	3	1	0	0	1	0	0	3.87847370399517	
i 1	194.5009387755102	19.4425	72	208	2	4	1	1	0	-1	1	0	0	3.87847370399517	
i 1	194.50469387755103	8.08	69	208	2	24	6	0	0	-1	0	0	0	3.87847370399517	
i 1	194.50719727891158	7.8275	72	208	2	24	4	0	0	0	0	0	0	3.87847370399517	
i 1	194.50719727891158	8.08	69	208	2	24	2	0	0	-1	0	0	0	3.87847370399517	
i 1	194.51095238095238	19.4425	69	208	2	4	8	0	0	-1	0	0	0	3.87847370399517	
i 1	194.73654421768708	0.2525	69	208	2	4	8	0	0	-1	0	0	0	3.87847370399517	
i 1	195.00156462585034	0.7575000000000001	69	208	2	4	1	0	0	-1	0	0	0	3.87847370399517	
i 1	195.75219047619046	0.2525	69	208	2	4	13	0	0	-1	0	0	0	3.87847370399517	
i 1	195.9884217687075	1.7675	69	208	2	4	8	0	0	-1	0	0	0	3.87847370399517	
i 1	196.24843537414966	0.2525	72	208	2	4	7	1	0	0	1	0	0	3.87847370399517	
i 1	196.50469387755103	4.545	72	208	2	4	14	1	0	0	1	0	0	3.87847370399517	
i 1	197.76032653061225	0.505	69	208	2	4	8	0	0	-1	0	0	0	3.87847370399517	
i 1	198.25657142857142	4.2925	69	208	2	4	2	0	0	-1	0	0	0	3.87847370399517	
i 1	201.00719727891158	0.2525	72	208	2	4	6	1	0	0	1	0	0	3.87847370399517	
i 1	201.25281632653062	0.2525	72	208	2	4	9	1	0	0	1	0	0	3.87847370399517	
i 1	201.5009387755102	0.2525	72	208	2	4	11	1	0	0	1	0	0	3.87847370399517	
i 1	201.7440544217687	0.2525	72	208	2	4	12	1	0	0	1	0	0	3.87847370399517	
i 1	201.99530612244897	0.2525	72	208	2	4	6	1	0	0	1	0	0	3.87847370399517	
i 1	202.25219047619046	0.2525	72	208	2	24	5	0	0	0	0	0	0	3.87847370399517	
i 1	202.26345578231292	0.2525	72	208	2	4	4	1	0	0	1	0	0	3.87847370399517	
i 1	202.48654421768708	1.01	72	208	2	24	7	0	0	0	0	0	0	3.87847370399517	
i 1	202.48654421768708	11.3625	69	412	2	4	7	1	0	-1	1	0	0	3.87847370399517	
i 1	202.49280272108842	11.3625	69	412	2	24	11	1	0	0	1	0	0	3.87847370399517	
i 1	202.50219047619046	0.7575000000000001	72	412	2	4	8	0	0	0	0	0	0	3.87847370399517	
i 1	202.50406802721088	11.3625	72	412	2	24	12	1	0	-1	1	0	0	3.87847370399517	
i 1	203.24342857142858	0.2525	72	412	2	4	12	0	0	0	0	0	0	3.87847370399517	
i 1	203.48466666666667	0.2525	72	208	2	24	14	0	0	0	0	0	0	3.87847370399517	
i 1	203.4990612244898	0.505	72	412	2	4	2	0	0	0	0	0	0	3.87847370399517	
i 1	203.7509387755102	3.7875	72	208	2	24	14	0	0	0	0	0	0	3.87847370399517	
i 1	204.00156462585034	0.2525	72	412	2	4	9	0	0	0	0	0	0	3.87847370399517	
i 1	204.2440544217687	9.595	72	412	2	4	10	0	0	0	0	0	0	3.87847370399517	
i 1	205.50970068027212	0.2525	72	208	2	24	11	1	0	-1	1	0	0	3.87847370399517	
i 1	205.7628299319728	2.02	72	208	2	24	12	1	0	-1	1	0	0	3.87847370399517	
i 1	207.50219047619046	0.2525	72	208	2	24	2	0	0	0	0	0	0	3.87847370399517	
i 1	207.73466666666667	0.2525	72	208	2	24	1	1	0	-1	1	0	0	3.87847370399517	
i 1	207.7440544217687	0.505	72	208	2	24	13	0	0	0	0	0	0	3.87847370399517	
i 1	208.00469387755103	5.3025	72	208	2	24	16	1	0	-1	1	0	0	3.87847370399517	
i 1	208.2440544217687	0.2525	72	208	2	24	2	0	0	0	0	0	0	3.87847370399517	
i 1	208.50531972789116	1.01	72	208	2	24	4	0	0	0	0	0	0	3.87847370399517	
i 1	209.49843537414966	0.505	72	208	2	24	16	0	0	0	0	0	0	3.87847370399517	
i 1	210.00281632653062	2.7775	72	208	2	24	5	0	0	0	0	0	0	3.87847370399517	
i 1	212.75907482993196	0.2525	72	208	2	24	14	0	0	0	0	0	0	3.87847370399517	
i 1	212.99843537414966	0.7575000000000001	72	208	2	24	16	0	0	0	0	0	0	3.87847370399517	
i 1	213.26533333333333	0.2525	72	208	2	24	14	1	0	-1	1	0	0	3.87847370399517	
i 1	213.49468027210884	0.2525	72	208	2	24	3	1	0	-1	1	0	0	3.87847370399517	
i 1	213.73654421768708	18.9375	72	208	2	24	9	0	0	0	0	0	0	4.001933553235036	
i 1	213.7384217687075	2.7775	72	208	2	24	11	1	0	-1	1	0	0	4.001933553235036	
i 1	213.7384217687075	6.3125	69	208	2	4	8	0	0	-1	0	0	0	4.001933553235036	
i 1	213.74092517006804	14.3925	69	412	2	24	11	1	0	0	1	0	0	4.001933553235036	
i 1	213.74092517006804	14.3925	69	412	2	4	14	1	0	-1	1	0	0	4.001933553235036	
i 1	213.74843537414966	14.3925	72	412	2	4	14	0	0	0	0	0	0	4.001933553235036	
i 1	213.75469387755103	14.3925	72	412	2	24	6	1	0	-1	1	0	0	4.001933553235036	
i 1	213.75844897959183	9.8475	72	208	2	4	14	1	0	-1	1	0	0	4.001933553235036	
i 1	216.50281632653062	0.2525	72	208	2	24	8	1	0	-1	1	0	0	4.001933553235036	
i 1	216.74780952380954	15.9075	72	208	2	24	6	1	0	-1	1	0	0	4.001933553235036	
i 1	219.99593197278912	0.2525	69	208	2	4	7	0	0	-1	0	0	0	4.001933553235036	
i 1	220.2421768707483	1.2625	69	208	2	4	5	0	0	-1	0	0	0	4.001933553235036	
i 1	221.48904761904762	0.2525	69	208	2	4	3	0	0	-1	0	0	0	4.001933553235036	
i 1	221.73779591836734	1.2625	69	208	2	4	1	0	0	-1	0	0	0	4.001933553235036	
i 1	223.00406802721088	0.2525	69	208	2	4	8	0	0	-1	0	0	0	4.001933553235036	
i 1	223.2440544217687	1.5150000000000001	69	208	2	4	4	0	0	-1	0	0	0	4.001933553235036	
i 1	223.49029931972788	0.2525	72	208	2	4	9	1	0	-1	1	0	0	4.001933553235036	
i 1	223.75907482993196	2.02	72	208	2	4	6	1	0	-1	1	0	0	4.001933553235036	
i 1	224.74530612244897	0.2525	69	208	2	4	6	0	0	-1	0	0	0	4.001933553235036	
i 1	224.99530612244897	2.02	69	208	2	4	4	0	0	-1	0	0	0	4.001933553235036	
i 1	225.73654421768708	0.2525	72	208	2	4	13	1	0	-1	1	0	0	4.001933553235036	
i 1	225.98466666666667	5.05	72	208	2	4	3	1	0	-1	1	0	0	4.001933553235036	
i 1	226.99468027210884	0.2525	69	208	2	4	16	0	0	-1	0	0	0	4.001933553235036	
i 1	227.24155102040817	2.525	69	208	2	4	9	0	0	-1	0	0	0	4.001933553235036	
i 1	227.9871700680272	3.0300000000000002	69	594	2	4	4	0	0	0	0	0	0	4.001933553235036	
i 1	227.9921768707483	3.0300000000000002	72	594	2	24	11	1	0	-1	1	0	0	4.001933553235036	
i 1	227.99780952380954	3.0300000000000002	69	594	2	24	9	1	0	-1	1	0	0	4.001933553235036	
i 1	227.99843537414966	3.0300000000000002	69	594	2	4	9	0	0	0	0	0	0	4.001933553235036	
i 1	229.75719727891158	0.2525	69	208	2	4	2	0	0	-1	0	0	0	4.001933553235036	
i 1	230.0009387755102	2.02	69	208	2	4	1	0	0	-1	0	0	0	4.001933553235036	
i 1	230.98779591836734	1.5150000000000001	72	826	2	4	12	1	0	0	1	0	0	4.001933553235036	
i 1	230.99530612244897	1.5150000000000001	69	826	2	24	1	0	0	0	0	0	0	4.001933553235036	
i 1	230.99655782312925	1.5150000000000001	69	826	2	24	2	0	0	-1	0	0	0	4.001933553235036	
i 1	231.00281632653062	1.5150000000000001	72	826	2	4	12	1	0	-1	1	0	0	4.001933553235036	
i 1	231.0059455782313	0.2525	72	208	2	4	16	1	0	-1	1	0	0	4.001933553235036	
i 1	231.24342857142858	1.2625	72	208	2	4	4	1	0	-1	1	0	0	4.001933553235036	
i 1	231.99780952380954	0.2525	69	208	2	4	6	0	0	-1	0	0	0	4.001933553235036	
i 1	232.2615782312925	0.2525	69	208	2	4	3	0	0	-1	0	0	0	4.001933553235036	
i 1	232.4921768707483	33.835	69	915	2	4	10	1	0	0	1	0	0	4.001933553235036	
i 1	232.4940544217687	8.08	69	101	2	24	16	1	0	-1	1	0	0	4.001933553235036	
i 1	232.50031292517008	33.835	72	915	2	24	7	0	0	0	0	0	0	4.001933553235036	
i 1	232.50406802721088	33.835	72	915	2	24	1	1	0	0	1	0	0	4.001933553235036	
i 1	232.5078231292517	8.08	69	101	2	24	9	0	0	-1	0	0	0	4.001933553235036	
i 1	232.51032653061225	8.08	72	101	2	4	8	1	0	-1	1	0	0	4.001933553235036	
i 1	232.5115782312925	8.08	72	101	2	4	15	1	0	0	1	0	0	4.001933553235036	
i 1	232.51533333333333	33.835	72	915	2	4	11	1	0	0	1	0	0	4.001933553235036	
i 1	240.4921768707483	25.755	69	1119	2	4	13	1	0	0	1	0	0	4.001933553235036	
i 1	240.49655782312925	25.755	69	1119	2	24	10	1	0	-1	1	0	0	4.001933553235036	
i 1	240.51533333333333	25.755	69	1119	2	24	9	1	0	0	1	0	0	4.001933553235036	
i 1	240.51533333333333	25.755	69	1119	2	4	3	1	0	-1	1	0	0	4.001933553235036	
i 1	265.9884217687075	3.0300000000000002	69	101	2	24	12	1	0	0	1	0	0	4.001933553235036	
i 1	266.0003129251701	19.19	69	915	2	4	3	1	0	-1	1	0	0	4.001933553235036	
i 1	266.00156462585034	19.19	72	915	2	24	13	0	0	0	0	0	0	4.001933553235036	
i 1	266.0059455782313	19.19	72	915	2	24	15	0	0	0	0	0	0	4.001933553235036	
i 1	266.0078231292517	3.0300000000000002	69	101	2	4	13	0	0	0	0	0	0	4.001933553235036	
i 1	266.0128299319728	19.19	69	915	2	4	10	1	0	-1	1	0	0	4.001933553235036	
i 1	266.0147074829932	3.0300000000000002	72	101	2	4	9	0	0	0	0	0	0	4.001933553235036	
i 1	266.01533333333333	3.0300000000000002	72	101	2	24	8	0	0	0	0	0	0	4.001933553235036	
i 1	268.98779591836734	1.5150000000000001	69	213	2	24	1	1	0	-1	1	0	0	4.001933553235036	
i 1	268.9990612244898	1.5150000000000001	72	213	2	4	1	0	0	-1	0	0	0	4.001933553235036	
i 1	269.0028163265306	1.5150000000000001	72	213	2	24	4	0	0	0	0	0	0	4.001933553235036	
i 1	269.01533333333333	1.5150000000000001	69	213	2	4	14	0	0	0	0	0	0	4.001933553235036	
i 1	270.48779591836734	14.645	72	417	2	24	15	0	0	0	0	0	0	4.001933553235036	
i 1	270.4928027210884	14.645	69	417	2	4	13	0	0	0	0	0	0	4.001933553235036	
i 1	270.4996870748299	14.645	72	417	2	4	5	0	0	0	0	0	0	4.001933553235036	
i 1	270.5040680272109	14.645	72	417	2	24	6	0	0	-1	0	0	0	4.001933553235036	
i 1	284.9852925170068	19.19	72	915	2	24	1	0	0	0	0	0	0	3.898133070180244	
i 1	284.99155102040817	23.735	72	417	2	24	10	0	0	-1	0	0	0	3.898133070180244	
i 1	284.9934285714286	23.735	72	417	2	24	5	0	0	0	0	0	0	3.898133070180244	
i 1	284.995306122449	5.8075	69	915	2	4	3	1	0	-1	1	0	0	3.898133070180244	
i 1	284.9959319727891	5.3025	69	915	2	4	10	1	0	-1	1	0	0	3.898133070180244	
i 1	284.9990612244898	5.05	69	417	2	4	8	0	0	0	0	0	0	3.898133070180244	
i 1	285.0009387755102	19.19	72	915	2	24	16	0	0	0	0	0	0	3.898133070180244	
i 1	285.0071972789116	6.565	72	417	2	4	16	0	0	0	0	0	0	3.898133070180244	
i 1	290.0009387755102	0.2525	69	417	2	4	7	0	0	0	0	0	0	3.898133070180244	
i 1	290.2440544217687	4.04	69	417	2	4	11	0	0	0	0	0	0	3.898133070180244	
i 1	290.26533333333333	0.505	69	915	2	4	1	1	0	-1	1	0	0	3.898133070180244	
i 1	290.7640816326531	0.2525	69	915	2	4	16	1	0	-1	1	0	0	3.898133070180244	
i 1	290.7647074829932	2.02	69	915	2	4	3	1	0	-1	1	0	0	3.898133070180244	
i 1	290.9996870748299	7.3225	69	915	2	4	16	1	0	-1	1	0	0	3.898133070180244	
i 1	291.4902993197279	0.2525	72	417	2	4	10	0	0	0	0	0	0	3.898133070180244	
i 1	291.7540680272109	1.2625	72	417	2	4	1	0	0	0	0	0	0	3.898133070180244	
i 1	292.754693877551	0.2525	69	915	2	4	4	1	0	-1	1	0	0	3.898133070180244	
i 1	293.0009387755102	1.7675	69	915	2	4	6	1	0	-1	1	0	0	3.898133070180244	
i 1	293.01032653061225	1.01	72	417	2	4	7	0	0	0	0	0	0	3.898133070180244	
i 1	293.9865442176871	2.7775	72	417	2	4	1	0	0	0	0	0	0	3.898133070180244	
i 1	294.26032653061225	0.2525	69	417	2	4	1	0	0	0	0	0	0	3.898133070180244	
i 1	294.5097006802721	0.7575000000000001	69	417	2	4	11	0	0	0	0	0	0	3.898133070180244	
i 1	294.7365442176871	0.2525	69	915	2	4	16	1	0	-1	1	0	0	3.898133070180244	
i 1	294.99843537414966	2.02	69	915	2	4	12	1	0	-1	1	0	0	3.898133070180244	
i 1	295.25344217687075	0.2525	69	417	2	4	8	0	0	0	0	0	0	3.898133070180244	
i 1	295.5040680272109	2.525	69	417	2	4	11	0	0	0	0	0	0	3.898133070180244	
i 1	296.754693877551	0.2525	72	417	2	4	10	0	0	0	0	0	0	3.898133070180244	
i 1	297.0028163265306	0.2525	69	915	2	4	4	1	0	-1	1	0	0	3.898133070180244	
i 1	297.0097006802721	5.555	72	417	2	4	10	0	0	0	0	0	0	3.898133070180244	
i 1	297.2559455782313	2.525	69	915	2	4	11	1	0	-1	1	0	0	3.898133070180244	
i 1	298.0109523809524	0.2525	69	417	2	4	10	0	0	0	0	0	0	3.898133070180244	
i 1	298.2359183673469	2.2725	69	417	2	4	12	0	0	0	0	0	0	3.898133070180244	
i 1	298.2503129251701	0.2525	69	915	2	4	13	1	0	-1	1	0	0	3.898133070180244	
i 1	298.4996870748299	5.555	69	915	2	4	9	1	0	-1	1	0	0	3.898133070180244	
i 1	299.7352925170068	0.2525	69	915	2	4	3	1	0	-1	1	0	0	3.898133070180244	
i 1	300.0059455782313	1.5150000000000001	69	915	2	4	7	1	0	-1	1	0	0	3.898133070180244	
i 1	300.4884217687075	0.505	69	417	2	4	16	0	0	0	0	0	0	3.898133070180244	
i 1	300.9871700680272	1.7675	69	417	2	4	5	0	0	0	0	0	0	3.898133070180244	
i 1	301.50844897959183	0.505	69	915	2	4	7	1	0	-1	1	0	0	3.898133070180244	
i 1	302.0078231292517	1.5150000000000001	69	915	2	4	3	1	0	-1	1	0	0	3.898133070180244	
i 1	302.4884217687075	0.2525	72	417	2	4	13	0	0	0	0	0	0	3.898133070180244	
i 1	302.7421768707483	5.8075	72	417	2	4	11	0	0	0	0	0	0	3.898133070180244	
i 1	302.76032653061225	0.2525	69	417	2	4	16	0	0	0	0	0	0	3.898133070180244	
i 1	302.9890476190476	1.01	69	417	2	4	15	0	0	0	0	0	0	3.898133070180244	
i 1	303.51533333333333	0.505	69	915	2	4	9	1	0	-1	1	0	0	3.898133070180244	
i 1	303.9871700680272	4.545	72	803	2	24	3	0	0	-1	0	0	0	3.898133070180244	
i 1	303.98967346938775	4.545	69	803	2	24	14	0	0	0	0	0	0	3.898133070180244	
i 1	303.9996870748299	4.545	72	803	2	4	2	0	0	0	0	0	0	3.898133070180244	
i 1	304.00156462585034	0.505	69	417	2	4	9	0	0	0	0	0	0	3.898133070180244	
i 1	304.004693877551	4.545	69	803	2	4	3	1	0	-1	1	0	0	3.898133070180244	
i 1	304.50156462585034	3.0300000000000002	69	417	2	4	5	0	0	0	0	0	0	3.898133070180244	
i 1	307.48779591836734	0.2525	69	417	2	4	11	0	0	0	0	0	0	3.898133070180244	
i 1	307.7521904761905	0.7575000000000001	69	417	2	4	10	0	0	0	0	0	0	3.898133070180244	
i 1	308.4865442176871	5.3025	72	404	2	24	2	1	0	0	1	0	0	3.898133070180244	
i 1	308.4959319727891	48.2275	69	902	2	4	2	0	0	0	0	0	0	3.898133070180244	
i 1	308.4971836734694	48.2275	69	404	2	4	16	1	0	0	1	0	0	3.898133070180244	
i 1	308.4996870748299	5.05	69	404	2	24	16	0	0	0	0	0	0	3.898133070180244	
i 1	308.4996870748299	48.2275	72	902	2	24	15	0	0	-1	0	0	0	3.898133070180244	
i 1	308.5009387755102	48.2275	69	902	2	24	2	0	0	-1	0	0	0	3.898133070180244	
i 1	308.5097006802721	48.2275	69	404	2	4	4	0	0	-1	0	0	0	3.898133070180244	
i 1	308.5140816326531	48.2275	69	902	2	4	15	1	0	-1	1	0	0	3.898133070180244	
i 1	313.4865442176871	0.2525	69	404	2	24	7	0	0	0	0	0	0	3.898133070180244	
i 1	313.7540680272109	0.2525	72	404	2	24	8	1	0	0	1	0	0	3.898133070180244	
i 1	313.76032653061225	1.01	69	404	2	24	9	0	0	0	0	0	0	3.898133070180244	
i 1	314.0147074829932	7.07	72	404	2	24	15	1	0	0	1	0	0	3.898133070180244	
i 1	314.7459319727891	0.2525	69	404	2	24	7	0	0	0	0	0	0	3.898133070180244	
i 1	314.98779591836734	0.505	69	404	2	24	2	0	0	0	0	0	0	3.898133070180244	
i 1	315.5059455782313	0.2525	69	404	2	24	12	0	0	0	0	0	0	3.898133070180244	
i 1	315.7597006802721	0.505	69	404	2	24	10	0	0	0	0	0	0	3.898133070180244	
i 1	316.26220408163266	0.2525	69	404	2	24	9	0	0	0	0	0	0	3.898133070180244	
i 1	316.4928027210884	0.2525	69	404	2	24	11	0	0	0	0	0	0	3.898133070180244	
i 1	316.7640816326531	0.2525	69	404	2	24	3	0	0	0	0	0	0	3.898133070180244	
i 1	317.0040680272109	2.2725	69	404	2	24	13	0	0	0	0	0	0	3.898133070180244	
i 1	319.2565714285714	0.2525	69	404	2	24	2	0	0	0	0	0	0	3.898133070180244	
i 1	319.51533333333333	0.2525	69	404	2	24	6	0	0	0	0	0	0	3.898133070180244	
i 1	319.7471836734694	0.2525	69	404	2	24	15	0	0	0	0	0	0	3.898133070180244	
i 1	319.99843537414966	2.2725	69	404	2	24	5	0	0	0	0	0	0	3.898133070180244	
i 1	321.01220408163266	0.2525	72	404	2	24	7	1	0	0	1	0	0	3.898133070180244	
i 1	321.259074829932	35.35	72	404	2	24	9	1	0	0	1	0	0	3.898133070180244	
i 1	322.2365442176871	0.2525	69	404	2	24	11	0	0	0	0	0	0	3.898133070180244	
i 1	322.49468027210884	0.7575000000000001	69	404	2	24	9	0	0	0	0	0	0	3.898133070180244	
i 1	323.2565714285714	0.7575000000000001	69	404	2	24	16	0	0	0	0	0	0	3.898133070180244	
i 1	324.0147074829932	0.7575000000000001	69	404	2	24	1	0	0	0	0	0	0	3.898133070180244	
i 1	324.7365442176871	0.2525	69	404	2	24	2	0	0	0	0	0	0	3.898133070180244	
i 1	325.00531972789116	1.01	69	404	2	24	11	0	0	0	0	0	0	3.898133070180244	
i 1	326.0147074829932	0.2525	69	404	2	24	12	0	0	0	0	0	0	3.898133070180244	
i 1	326.26032653061225	0.2525	69	404	2	24	10	0	0	0	0	0	0	3.898133070180244	
i 1	326.4921768707483	0.2525	69	404	2	24	9	0	0	0	0	0	0	3.898133070180244	
i 1	326.7371700680272	29.795	69	404	2	24	11	0	0	0	0	0	0	3.898133070180244	
i 1	356.2352925170068	28.5325	69	902	2	4	9	0	0	0	0	0	0	3.804515506988663	
i 1	356.2384217687075	28.5325	69	902	2	24	15	0	0	-1	0	0	0	3.804515506988663	
i 1	356.2402993197279	28.5325	69	902	2	4	3	1	0	-1	1	0	0	3.804515506988663	
i 1	356.240925170068	28.5325	72	902	2	24	9	0	0	-1	0	0	0	3.804515506988663	
i 1	356.2471836734694	28.0275	69	404	2	24	12	0	0	0	0	0	0	3.804515506988663	
i 1	356.2597006802721	36.1075	69	404	2	4	6	0	0	-1	0	0	0	3.804515506988663	
i 1	356.2640816326531	31.0575	72	404	2	24	4	1	0	0	1	0	0	3.804515506988663	
i 1	356.26533333333333	36.6125	69	404	2	4	7	1	0	0	1	0	0	3.804515506988663	
i 1	384.0140816326531	0.2525	69	404	2	24	1	0	0	0	0	0	0	3.804515506988663	
i 1	384.2402993197279	2.2725	69	404	2	24	14	0	0	0	0	0	0	3.804515506988663	
i 1	384.4865442176871	1.5150000000000001	72	404	2	24	2	2	0	1	2	0	0	3.804515506988663	
i 1	384.4959319727891	15.655	75	404	2	4	2	2	0	1	2	0	0	3.804515506988663	
i 1	384.50344217687075	1.7675	72	404	2	24	8	2	0	-2	2	0	0	3.804515506988663	
i 1	384.5059455782313	25.25	72	404	2	4	3	2	0	-2	2	0	0	3.804515506988663	
i 1	386.0109523809524	0.2525	72	404	2	24	6	2	0	1	2	0	0	3.804515506988663	
i 1	386.2390476190476	7.07	72	404	2	24	6	2	0	1	2	0	0	3.804515506988663	
i 1	386.245306122449	0.2525	72	404	2	24	12	2	0	-2	2	0	0	3.804515506988663	
i 1	386.504693877551	0.2525	69	404	2	24	10	0	0	0	0	0	0	3.804515506988663	
i 1	386.5128299319728	0.2525	72	404	2	24	9	2	0	-2	2	0	0	3.804515506988663	
i 1	386.7521904761905	0.505	69	404	2	24	3	0	0	0	0	0	0	3.804515506988663	
i 1	386.7634557823129	0.2525	72	404	2	24	1	2	0	-2	2	0	0	3.804515506988663	
i 1	387.0040680272109	0.2525	72	404	2	24	12	1	0	0	1	0	0	3.804515506988663	
i 1	387.0040680272109	1.01	72	404	2	24	5	2	0	-2	2	0	0	3.804515506988663	
i 1	387.245306122449	1.01	72	404	2	24	14	1	0	0	1	0	0	3.804515506988663	
i 1	387.2597006802721	0.505	69	404	2	24	12	0	0	0	0	0	0	3.804515506988663	
i 1	387.73779591836734	0.7575000000000001	69	404	2	24	2	0	0	0	0	0	0	3.804515506988663	
i 1	387.9990612244898	0.2525	72	404	2	24	5	2	0	-2	2	0	0	3.804515506988663	
i 1	388.2421768707483	1.2625	72	404	2	24	12	2	0	-2	2	0	0	3.804515506988663	
i 1	388.2490612244898	0.2525	72	404	2	24	15	1	0	0	1	0	0	3.804515506988663	
i 1	388.5009387755102	0.2525	69	404	2	24	12	0	0	0	0	0	0	3.804515506988663	
i 1	388.5040680272109	0.505	72	404	2	24	5	1	0	0	1	0	0	3.804515506988663	
i 1	388.73779591836734	2.2725	69	404	2	24	9	0	0	0	0	0	0	3.804515506988663	
i 1	388.9990612244898	0.2525	72	404	2	24	3	1	0	0	1	0	0	3.804515506988663	
i 1	389.23779591836734	0.505	72	404	2	24	12	1	0	0	1	0	0	3.804515506988663	
i 1	389.5059455782313	0.2525	72	404	2	24	4	2	0	-2	2	0	0	3.804515506988663	
i 1	389.7521904761905	0.2525	72	404	2	24	4	2	0	-2	2	0	0	3.804515506988663	
i 1	389.7559455782313	0.2525	72	404	2	24	8	1	0	0	1	0	0	3.804515506988663	
i 1	389.9871700680272	0.2525	72	404	2	24	11	1	0	0	1	0	0	3.804515506988663	
i 1	390.00156462585034	0.2525	72	404	2	24	3	2	0	-2	2	0	0	3.804515506988663	
i 1	390.2384217687075	1.01	72	404	2	24	10	2	0	-2	2	0	0	3.804515506988663	
i 1	390.245306122449	0.2525	72	404	2	24	11	1	0	0	1	0	0	3.804515506988663	
i 1	390.49843537414966	2.02	72	404	2	24	7	1	0	0	1	0	0	3.804515506988663	
i 1	390.98466666666667	0.2525	69	404	2	24	16	0	0	0	0	0	0	3.804515506988663	
i 1	391.2352925170068	0.505	72	404	2	24	5	2	0	-2	2	0	0	3.804515506988663	
i 1	391.24655782312925	1.2625	69	404	2	24	10	0	0	0	0	0	0	3.804515506988663	
i 1	391.7528163265306	1.01	72	404	2	24	6	2	0	-2	2	0	0	3.804515506988663	
i 1	391.9890476190476	0.2525	69	404	2	4	4	0	0	-1	0	0	0	3.804515506988663	
i 1	392.2421768707483	0.2525	69	404	2	4	11	0	0	-1	0	0	0	3.804515506988663	
i 1	392.48967346938775	2.525	75	172	2	4	10	2	0	-2	2	0	0	3.804515506988663	
i 1	392.4940544217687	3.0300000000000002	75	172	2	4	14	2	0	-2	2	0	0	3.804515506988663	
i 1	392.5040680272109	0.505	75	172	2	24	3	2	0	-2	2	0	0	3.804515506988663	
i 1	392.50844897959183	3.535	72	172	2	24	6	2	0	-2	2	0	0	3.804515506988663	
i 1	392.7559455782313	0.2525	72	404	2	24	10	2	0	-2	2	0	0	3.804515506988663	
i 1	392.9934285714286	0.2525	75	172	2	24	11	2	0	-2	2	0	0	3.804515506988663	
i 1	393.00344217687075	1.5150000000000001	72	404	2	24	13	2	0	-2	2	0	0	3.804515506988663	
i 1	393.2478095238095	0.2525	72	404	2	24	14	2	0	1	2	0	0	3.804515506988663	
i 1	393.2496870748299	3.535	75	172	2	24	1	2	0	-2	2	0	0	3.804515506988663	
i 1	393.490925170068	0.7575000000000001	72	404	2	24	9	2	0	1	2	0	0	3.804515506988663	
i 1	394.2471836734694	0.2525	72	404	2	24	11	2	0	1	2	0	0	3.804515506988663	
i 1	394.4940544217687	0.505	72	404	2	24	7	2	0	-2	2	0	0	3.804515506988663	
i 1	394.5071972789116	1.2625	72	404	2	24	4	2	0	1	2	0	0	3.804515506988663	
i 1	395.004693877551	0.2525	75	172	2	4	12	2	0	-2	2	0	0	3.804515506988663	
i 1	395.0134557823129	0.2525	72	404	2	24	4	2	0	-2	2	0	0	3.804515506988663	
i 1	395.2490612244898	1.01	75	172	2	4	9	2	0	-2	2	0	0	3.804515506988663	
i 1	395.2503129251701	0.2525	72	404	2	24	13	2	0	-2	2	0	0	3.804515506988663	
i 1	395.4928027210884	1.5150000000000001	72	404	2	24	10	2	0	-2	2	0	0	3.804515506988663	
i 1	395.4978095238095	0.2525	75	172	2	4	10	2	0	-2	2	0	0	3.804515506988663	
i 1	395.75844897959183	2.02	75	172	2	4	5	2	0	-2	2	0	0	3.804515506988663	
i 1	395.7597006802721	0.2525	72	404	2	24	8	2	0	1	2	0	0	3.804515506988663	
i 1	395.9865442176871	2.525	72	404	2	24	11	2	0	1	2	0	0	3.804515506988663	
i 1	395.99155102040817	0.2525	72	172	2	24	7	2	0	-2	2	0	0	3.804515506988663	
i 1	396.2371700680272	0.2525	75	172	2	4	8	2	0	-2	2	0	0	3.804515506988663	
i 1	396.2609523809524	2.525	72	172	2	24	11	2	0	-2	2	0	0	3.804515506988663	
i 1	396.49655782312925	3.7875	75	172	2	4	12	2	0	-2	2	0	0	3.804515506988663	
i 1	396.7352925170068	0.2525	75	172	2	24	13	2	0	-2	2	0	0	3.804515506988663	
i 1	397.0021904761905	4.04	75	172	2	24	11	2	0	-2	2	0	0	3.804515506988663	
i 1	397.0040680272109	0.7575000000000001	72	404	2	24	16	2	0	-2	2	0	0	3.804515506988663	
i 1	397.74468027210884	0.2525	72	404	2	24	10	2	0	-2	2	0	0	3.804515506988663	
i 1	397.76220408163266	0.2525	75	172	2	4	7	2	0	-2	2	0	0	3.804515506988663	
i 1	398.0028163265306	5.8075	75	172	2	4	15	2	0	-2	2	0	0	3.804515506988663	
i 1	398.01533333333333	0.505	72	404	2	24	11	2	0	-2	2	0	0	3.804515506988663	
i 1	398.4928027210884	0.2525	72	404	2	24	2	2	0	1	2	0	0	3.804515506988663	
i 1	398.5009387755102	1.2625	72	404	2	24	8	2	0	-2	2	0	0	3.804515506988663	
i 1	398.74655782312925	0.2525	72	172	2	24	1	2	0	-2	2	0	0	3.804515506988663	
i 1	398.7521904761905	0.505	72	404	2	24	7	2	0	1	2	0	0	3.804515506988663	
i 1	398.9871700680272	3.2825	72	172	2	24	12	2	0	-2	2	0	0	3.804515506988663	
i 1	399.2384217687075	0.2525	72	404	2	24	7	2	0	1	2	0	0	3.804515506988663	
i 1	399.48779591836734	1.2625	72	404	2	24	14	2	0	1	2	0	0	3.804515506988663	
i 1	399.754693877551	0.2525	72	404	2	24	5	2	0	-2	2	0	0	3.804515506988663	
i 1	399.9940544217687	0.2525	75	404	2	4	15	2	0	1	2	0	0	3.804515506988663	
i 1	400.0109523809524	4.545	72	404	2	24	5	2	0	-2	2	0	0	3.804515506988663	
i 1	400.2478095238095	1.2625	75	404	2	4	8	2	0	1	2	0	0	3.804515506988663	
i 1	400.2509387755102	0.2525	75	172	2	4	1	2	0	-2	2	0	0	3.804515506988663	
i 1	400.504693877551	0.7575000000000001	75	172	2	4	1	2	0	-2	2	0	0	3.804515506988663	
i 1	400.7471836734694	0.2525	72	404	2	24	14	2	0	1	2	0	0	3.804515506988663	
i 1	401.00156462585034	0.2525	75	172	2	24	2	2	0	-2	2	0	0	3.804515506988663	
i 1	401.0140816326531	0.7575000000000001	72	404	2	24	7	2	0	1	2	0	0	3.804515506988663	
i 1	401.2421768707483	3.535	75	172	2	24	10	2	0	-2	2	0	0	3.804515506988663	
i 1	401.2509387755102	0.2525	75	172	2	4	3	2	0	-2	2	0	0	3.804515506988663	
i 1	401.48466666666667	0.505	75	172	2	4	16	2	0	-2	2	0	0	3.804515506988663	
i 1	401.4934285714286	0.2525	75	404	2	4	9	2	0	1	2	0	0	3.804515506988663	
i 1	401.7428027210884	0.2525	72	404	2	24	8	2	0	1	2	0	0	3.804515506988663	
i 1	401.7615782312925	1.5150000000000001	75	404	2	4	1	2	0	1	2	0	0	3.804515506988663	
i 1	402.0028163265306	0.2525	75	172	2	4	15	2	0	-2	2	0	0	3.804515506988663	
i 1	402.0109523809524	0.7575000000000001	72	404	2	24	3	2	0	1	2	0	0	3.804515506988663	
i 1	402.2352925170068	0.505	72	172	2	24	8	2	0	-2	2	0	0	3.804515506988663	
i 1	402.24655782312925	4.04	75	172	2	4	6	2	0	-2	2	0	0	3.804515506988663	
i 1	402.74843537414966	0.2525	72	172	2	24	1	2	0	-2	2	0	0	3.804515506988663	
i 1	402.7609523809524	0.2525	72	404	2	24	14	2	0	1	2	0	0	3.804515506988663	
i 1	402.99655782312925	0.2525	72	172	2	24	1	2	0	-2	2	0	0	3.804515506988663	
i 1	402.99843537414966	2.2725	72	404	2	24	5	2	0	1	2	0	0	3.804515506988663	
i 1	403.2384217687075	1.7675	72	172	2	24	16	2	0	-2	2	0	0	3.804515506988663	
i 1	403.2578231292517	0.2525	75	404	2	4	4	2	0	1	2	0	0	3.804515506988663	
i 1	403.5021904761905	0.7575000000000001	75	404	2	4	14	2	0	1	2	0	0	3.804515506988663	
i 1	403.7352925170068	0.505	75	172	2	4	7	2	0	-2	2	0	0	3.804515506988663	
i 1	404.24468027210884	3.535	75	172	2	4	3	2	0	-2	2	0	0	3.804515506988663	
i 1	404.2503129251701	0.2525	75	404	2	4	2	2	0	1	2	0	0	3.804515506988663	
i 1	404.50844897959183	0.2525	72	404	2	24	6	2	0	-2	2	0	0	3.804515506988663	
i 1	404.5140816326531	1.01	75	404	2	4	2	2	0	1	2	0	0	3.804515506988663	
i 1	404.759074829932	2.02	72	404	2	24	16	2	0	-2	2	0	0	3.804515506988663	
i 1	404.76220408163266	0.2525	75	172	2	24	3	2	0	-2	2	0	0	3.804515506988663	
i 1	405.004693877551	0.2525	72	172	3	24	11	2	0	-2	2	0	0	3.804515506988663	
i 1	405.004693877551	3.2825	75	172	2	24	3	2	0	-2	2	0	0	3.804515506988663	
i 1	405.259074829932	0.2525	72	404	2	24	11	2	0	1	2	0	0	3.804515506988663	
i 1	405.2615782312925	2.02	72	172	2	24	3	2	0	-2	2	0	0	3.804515506988663	
i 1	405.4884217687075	0.7575000000000001	75	404	2	4	2	2	0	1	2	0	0	3.804515506988663	
i 1	405.490925170068	3.2825	72	404	2	24	3	2	0	1	2	0	0	3.804515506988663	
i 1	406.2471836734694	0.2525	75	172	2	4	11	2	0	-2	2	0	0	3.804515506988663	
i 1	406.25844897959183	0.2525	75	404	2	4	7	2	0	1	2	0	0	3.804515506988663	
i 1	406.4934285714286	0.2525	75	404	2	4	12	2	0	1	2	0	0	3.804515506988663	
i 1	406.5134557823129	1.5150000000000001	75	172	2	4	11	2	0	-2	2	0	0	3.804515506988663	
i 1	406.74468027210884	3.2825	75	404	2	4	13	2	0	1	2	0	0	3.804515506988663	
i 1	406.7634557823129	0.505	72	404	2	24	8	2	0	-2	2	0	0	3.804515506988663	
i 1	407.2565714285714	0.2525	72	404	2	24	14	2	0	-2	2	0	0	3.804515506988663	
i 1	407.26032653061225	0.2525	72	172	3	24	3	2	0	-2	2	0	0	3.804515506988663	
i 1	407.48466666666667	3.535	72	172	2	24	8	2	0	-2	2	0	0	3.804515506988663	
i 1	407.50844897959183	0.2525	72	404	2	24	12	2	0	-2	2	0	0	3.804515506988663	
i 1	407.73967346938775	0.2525	75	172	2	4	5	2	0	-2	2	0	0	3.804515506988663	
i 1	407.7434285714286	0.7575000000000001	72	404	2	24	11	2	0	-2	2	0	0	3.804515506988663	
i 1	407.9890476190476	0.2525	75	172	2	4	16	2	0	-2	2	0	0	3.804515506988663	
i 1	408.0140816326531	1.01	75	172	2	4	7	2	0	-2	2	0	0	3.804515506988663	
i 1	408.2428027210884	2.525	75	172	2	4	4	2	0	-2	2	0	0	3.804515506988663	
i 1	408.24655782312925	0.2525	75	172	2	24	11	2	0	-2	2	0	0	3.804515506988663	
i 1	408.49155102040817	0.2525	72	404	2	24	11	2	0	-2	2	0	0	3.804515506988663	
i 1	408.4928027210884	1.2625	75	172	2	24	2	2	0	-2	2	0	0	3.804515506988663	
i 1	408.74155102040817	0.505	72	404	2	24	5	2	0	-2	2	0	0	3.804515506988663	
i 1	408.74655782312925	0.2525	72	404	2	24	9	2	0	1	2	0	0	3.804515506988663	
i 1	408.9921768707483	1.2625	72	404	2	24	12	2	0	1	2	0	0	3.804515506988663	
i 1	408.99655782312925	0.2525	75	172	2	4	13	2	0	-2	2	0	0	3.804515506988663	
i 1	409.245306122449	0.2525	72	404	2	24	15	2	0	-2	2	0	0	3.804515506988663	
i 1	409.2634557823129	1.2625	75	172	2	4	6	2	0	-2	2	0	0	3.804515506988663	
i 1	409.495306122449	0.2525	72	404	2	4	11	2	0	-2	2	0	0	3.804515506988663	
i 1	409.5003129251701	5.3025	72	404	2	24	10	2	0	-2	2	0	0	3.804515506988663	
i 1	409.7540680272109	1.7675	72	404	2	4	15	2	0	-2	2	0	0	3.804515506988663	
i 1	409.754693877551	0.2525	75	172	3	24	16	2	0	-2	2	0	0	3.804515506988663	
i 1	409.9940544217687	0.2525	75	404	2	4	8	2	0	1	2	0	0	3.804515506988663	
i 1	410.0147074829932	1.2625	75	172	2	24	4	2	0	-2	2	0	0	3.804515506988663	
i 1	410.24155102040817	0.2525	72	404	2	24	7	2	0	1	2	0	0	3.804515506988663	
i 1	410.2597006802721	2.02	75	404	2	4	13	2	0	1	2	0	0	3.804515506988663	
i 1	410.4884217687075	7.07	72	404	2	24	12	2	0	1	2	0	0	3.804515506988663	
i 1	410.5115782312925	0.2525	75	172	2	4	11	2	0	-2	2	0	0	3.804515506988663	
i 1	410.754693877551	1.01	75	172	2	4	15	2	0	-2	2	0	0	3.804515506988663	
i 1	410.7597006802721	0.2525	75	172	2	4	12	2	0	-2	2	0	0	3.804515506988663	
i 1	411.00156462585034	2.02	75	172	2	4	13	2	0	-2	2	0	0	3.804515506988663	
i 1	411.01032653061225	0.2525	72	172	3	24	2	2	0	-2	2	0	0	3.804515506988663	
i 1	411.2384217687075	2.7775	72	172	2	24	5	2	0	-2	2	0	0	3.804515506988663	
i 1	411.2571972789116	0.2525	75	172	3	24	13	2	0	-2	2	0	0	3.804515506988663	
i 1	411.49655782312925	0.2525	72	404	2	4	9	2	0	-2	2	0	0	3.804515506988663	
i 1	411.5140816326531	3.0300000000000002	75	172	2	24	8	2	0	-2	2	0	0	3.804515506988663	
i 1	411.73967346938775	0.2525	72	404	2	4	7	2	0	-2	2	0	0	3.804515506988663	
i 1	411.74155102040817	0.2525	75	172	2	4	8	2	0	-2	2	0	0	3.804515506988663	
i 1	411.9865442176871	0.2525	72	404	2	4	16	2	0	-2	2	0	0	3.804515506988663	
i 1	412.0040680272109	1.2625	75	172	2	4	10	2	0	-2	2	0	0	3.804515506988663	
i 1	412.2359183673469	0.2525	75	404	2	4	16	2	0	1	2	0	0	3.804515506988663	
i 1	412.2640816326531	0.2525	72	404	2	4	6	2	0	-2	2	0	0	3.804515506988663	
i 1	412.49843537414966	0.505	72	404	2	4	15	2	0	-2	2	0	0	3.804515506988663	
i 1	412.51220408163266	1.2625	75	404	2	4	14	2	0	1	2	0	0	3.804515506988663	
i 1	412.99468027210884	0.2525	75	172	2	4	7	2	0	-2	2	0	0	3.804515506988663	
i 1	413.0021904761905	3.2825	72	404	2	4	6	2	0	-2	2	0	0	3.804515506988663	
i 1	413.2402993197279	0.2525	75	172	2	4	6	2	0	-2	2	0	0	3.804515506988663	
i 1	413.259074829932	0.2525	75	172	2	4	8	2	0	-2	2	0	0	3.804515506988663	
i 1	413.4852925170068	4.545	75	172	2	4	3	2	0	-2	2	0	0	3.804515506988663	
i 1	413.50531972789116	0.2525	75	172	2	4	11	2	0	-2	2	0	0	3.804515506988663	
i 1	413.7402993197279	2.02	75	172	2	4	4	2	0	-2	2	0	0	3.804515506988663	
i 1	413.7402993197279	0.2525	75	404	2	4	7	2	0	1	2	0	0	3.804515506988663	
i 1	414.0071972789116	1.01	75	404	2	4	14	2	0	1	2	0	0	3.804515506988663	
i 1	414.01533333333333	0.505	72	172	3	24	15	2	0	-2	2	0	0	3.804515506988663	
i 1	414.4990612244898	0.2525	75	172	3	24	15	2	0	-2	2	0	0	3.804515506988663	
i 1	414.5021904761905	3.535	72	172	2	24	8	2	0	-2	2	0	0	3.804515506988663	
i 1	414.7528163265306	0.505	75	172	2	24	13	2	0	-2	2	0	0	3.804515506988663	
i 1	414.7628299319728	0.2525	72	404	2	24	14	2	0	-2	2	0	0	3.804515506988663	
i 1	414.9902993197279	0.2525	75	404	2	4	15	2	0	1	2	0	0	3.804515506988663	
i 1	415.00344217687075	0.505	72	404	2	24	9	2	0	-2	2	0	0	3.804515506988663	
i 1	415.24468027210884	0.2525	75	172	3	24	9	2	0	-2	2	0	0	3.804515506988663	
i 1	415.2640816326531	0.7575000000000001	75	404	2	4	16	2	0	1	2	0	0	3.804515506988663	
i 1	415.4859183673469	0.2525	72	404	2	24	4	2	0	-2	2	0	0	3.804515506988663	
i 1	415.50531972789116	1.2625	75	172	2	24	3	2	0	-2	2	0	0	3.804515506988663	
i 1	415.7459319727891	0.2525	75	172	2	4	12	2	0	-2	2	0	0	3.804515506988663	
i 1	415.74655782312925	0.7575000000000001	72	404	2	24	8	2	0	-2	2	0	0	3.804515506988663	
i 1	415.98967346938775	0.2525	75	404	2	4	8	2	0	1	2	0	0	3.804515506988663	
i 1	416.01533333333333	1.7675	75	172	2	4	11	2	0	-2	2	0	0	3.804515506988663	
i 1	416.2352925170068	1.7675	75	404	2	4	10	2	0	1	2	0	0	3.804515506988663	
i 1	416.24155102040817	0.2525	72	404	2	4	10	2	0	-2	2	0	0	3.804515506988663	
i 1	416.5140816326531	0.2525	72	404	2	24	9	2	0	-2	2	0	0	3.804515506988663	
i 1	416.5140816326531	0.505	72	404	2	4	15	2	0	-2	2	0	0	3.804515506988663	
i 1	416.7365442176871	0.2525	75	172	3	24	6	2	0	-2	2	0	0	3.804515506988663	
i 1	416.7634557823129	1.2625	72	404	2	24	7	2	0	-2	2	0	0	3.804515506988663	
i 1	417.0078231292517	0.505	72	404	2	4	2	2	0	-2	2	0	0	3.804515506988663	
i 1	417.01032653061225	1.01	75	172	2	24	3	2	0	-2	2	0	0	3.804515506988663	
i 1	417.50344217687075	0.2525	72	404	2	24	12	2	0	1	2	0	0	3.804515506988663	
i 1	417.5078231292517	0.505	72	404	2	4	10	2	0	-2	2	0	0	3.804515506988663	
i 1	417.745306122449	0.2525	75	172	2	4	5	2	0	-2	2	0	0	3.804515506988663	
i 1	417.7647074829932	0.2525	72	404	2	24	8	2	0	1	2	0	0	3.804515506988663	
i 1	417.98967346938775	2.2725	75	474	2	24	7	2	0	1	2	0	0	3.804515506988663	
i 1	417.990925170068	9.595	72	88	2	24	13	2	0	-2	2	0	0	3.804515506988663	
i 1	417.9971836734694	9.595	72	88	2	4	13	2	0	1	2	0	0	3.804515506988663	
i 1	417.99843537414966	0.2525	75	474	2	4	12	2	0	1	2	0	0	3.804515506988663	
i 1	418.00344217687075	1.01	75	88	2	24	16	2	0	-2	2	0	0	3.804515506988663	
i 1	418.0040680272109	3.7875	72	88	2	4	11	2	0	-2	2	0	0	3.804515506988663	
i 1	418.009074829932	0.2525	72	474	2	4	9	2	0	1	2	0	0	3.804515506988663	
i 1	418.0140816326531	0.7575000000000001	75	474	2	24	13	2	0	1	2	0	0	3.804515506988663	
i 1	418.2402993197279	0.505	72	474	2	4	15	2	0	1	2	0	0	3.804515506988663	
i 1	418.26533333333333	1.01	75	474	2	4	3	2	0	1	2	0	0	3.804515506988663	
i 1	418.7478095238095	0.7575000000000001	72	474	2	4	9	2	0	1	2	0	0	3.804515506988663	
i 1	418.7597006802721	0.2525	75	474	2	24	6	2	0	1	2	0	0	3.804515506988663	
i 1	418.9940544217687	0.2525	75	88	3	24	6	2	0	-2	2	0	0	3.804515506988663	
i 1	418.9990612244898	1.01	75	474	2	24	2	2	0	1	2	0	0	3.804515506988663	
i 1	419.24843537414966	0.2525	75	474	2	4	4	2	0	1	2	0	0	3.804515506988663	
i 1	419.25344217687075	1.2625	75	88	2	24	14	2	0	-2	2	0	0	3.804515506988663	
i 1	419.49655782312925	0.2525	72	474	2	4	8	2	0	1	2	0	0	3.804515506988663	
i 1	419.509074829932	0.2525	75	474	2	4	2	2	0	1	2	0	0	3.804515506988663	
i 1	419.7478095238095	0.2525	75	474	2	4	8	2	0	1	2	0	0	3.804515506988663	
i 1	419.75156462585034	2.7775	72	474	2	4	8	2	0	1	2	0	0	3.804515506988663	
i 1	420.0059455782313	0.7575000000000001	75	474	2	4	6	2	0	1	2	0	0	3.804515506988663	
i 1	420.0134557823129	0.2525	75	474	2	24	11	2	0	1	2	0	0	3.804515506988663	
i 1	420.2597006802721	0.2525	75	474	2	24	9	2	0	1	2	0	0	3.804515506988663	
i 1	420.26533333333333	2.02	75	474	2	24	12	2	0	1	2	0	0	3.804515506988663	
i 1	420.48779591836734	0.2525	75	88	3	24	5	2	0	-2	2	0	0	3.804515506988663	
i 1	420.49468027210884	0.505	75	474	2	24	16	2	0	1	2	0	0	3.804515506988663	
i 1	420.75531972789116	6.8175	75	88	2	24	12	2	0	-2	2	0	0	3.804515506988663	
i 1	420.7634557823129	0.2525	75	474	2	4	2	2	0	1	2	0	0	3.804515506988663	
i 1	420.9928027210884	1.5150000000000001	75	474	2	4	8	2	0	1	2	0	0	3.804515506988663	
i 1	420.9990612244898	0.7575000000000001	75	474	2	24	13	2	0	1	2	0	0	3.804515506988663	
i 1	421.7496870748299	0.7575000000000001	75	474	2	24	8	2	0	1	2	0	0	3.804515506988663	
i 1	421.7496870748299	0.505	72	88	2	4	13	2	0	-2	2	0	0	3.804515506988663	
i 1	422.2471836734694	5.3025	72	88	2	4	14	2	0	-2	2	0	0	3.804515506988663	
i 1	422.2634557823129	0.2525	75	474	2	24	13	2	0	1	2	0	0	3.804515506988663	
i 1	422.4865442176871	0.505	75	586	2	4	8	2	0	1	2	0	0	3.804515506988663	
i 1	422.4884217687075	0.2525	72	586	2	4	15	2	0	1	2	0	0	3.804515506988663	
i 1	422.5109523809524	5.05	72	586	2	24	9	2	0	1	2	0	0	3.804515506988663	
i 1	422.5140816326531	0.2525	75	586	2	24	3	2	0	-2	2	0	0	3.804515506988663	
i 1	422.73466666666667	0.2525	72	586	2	4	10	2	0	1	2	0	0	3.804515506988663	
i 1	422.7390476190476	4.7975	75	586	2	24	13	2	0	-2	2	0	0	3.804515506988663	
i 1	422.99468027210884	0.2525	75	586	2	4	5	2	0	1	2	0	0	3.804515506988663	
i 1	423.0009387755102	4.545	72	586	2	4	13	2	0	1	2	0	0	3.804515506988663	
i 1	423.2509387755102	4.2925	75	586	2	4	3	2	0	1	2	0	0	3.804515506988663	
i 1	427.495306122449	28.785	72	88	2	24	9	2	0	-2	2	0	0	3.958524115818158	
i 1	427.5009387755102	28.785	75	88	2	24	16	2	0	-2	2	0	0	3.958524115818158	
i 1	427.5028163265306	28.785	72	586	2	24	8	2	0	1	2	0	0	3.958524115818158	
i 1	427.50531972789116	28.785	72	586	2	4	15	2	0	1	2	0	0	3.958524115818158	
i 1	427.5059455782313	28.785	72	88	2	4	15	2	0	-2	2	0	0	3.958524115818158	
i 1	427.5065714285714	28.785	75	586	2	4	11	2	0	1	2	0	0	3.958524115818158	
i 1	427.51032653061225	28.785	75	586	2	24	1	2	0	-2	2	0	0	3.958524115818158	
i 1	427.5147074829932	28.785	72	88	2	4	8	2	0	1	2	0	0	3.958524115818158	
i 1	455.98466666666667	3.0300000000000002	72	1099	2	4	6	8	0	1	8	0	0	3.958524115818158	
i 1	455.9871700680272	3.0300000000000002	75	1099	2	24	9	2	0	-2	2	0	0	3.958524115818158	
i 1	455.98779591836734	38.38	72	1099	2	24	5	2	0	-2	2	0	0	3.958524115818158	
i 1	455.9890476190476	38.38	75	1099	2	4	7	8	0	1	8	0	0	3.958524115818158	
i 1	455.9928027210884	3.0300000000000002	72	1099	2	4	8	2	0	1	2	0	0	3.958524115818158	
i 1	455.9940544217687	38.38	72	1099	2	4	12	8	0	-2	8	0	0	3.958524115818158	
i 1	455.99468027210884	3.0300000000000002	72	1099	2	24	3	2	0	1	2	0	0	3.958524115818158	
i 1	456.0115782312925	38.38	75	1099	2	24	16	2	0	-2	2	0	0	3.958524115818158	
i 1	458.9928027210884	1.5150000000000001	72	868	2	24	1	2	0	1	2	0	0	3.958524115818158	
i 1	458.9959319727891	1.5150000000000001	72	868	2	24	9	2	0	1	2	0	0	3.958524115818158	
i 1	459.0109523809524	1.5150000000000001	72	868	2	4	9	2	0	1	2	0	0	3.958524115818158	
i 1	459.01220408163266	1.5150000000000001	72	868	2	4	1	2	0	1	2	0	0	3.958524115818158	
i 1	460.49155102040817	33.835	75	783	2	24	7	2	0	1	2	0	0	3.958524115818158	
i 1	460.4934285714286	33.835	72	783	2	4	4	2	0	-2	2	0	0	3.958524115818158	
i 1	460.495306122449	33.835	75	783	2	24	12	2	0	1	2	0	0	3.958524115818158	
i 1	460.5021904761905	33.835	75	783	2	4	5	2	0	-2	2	0	0	3.958524115818158	
i 1	493.9852925170068	3.0300000000000002	72	579	2	4	8	2	0	-2	2	0	0	3.958524115818158	
i 1	493.9959319727891	3.0300000000000002	72	579	2	24	7	2	0	1	2	0	0	3.958524115818158	
i 1	493.9959319727891	3.0300000000000002	75	579	2	24	16	2	0	-2	2	0	0	3.958524115818158	
i 1	494.0028163265306	4.545	75	895	2	24	5	2	0	1	2	0	0	3.958524115818158	
i 1	494.0128299319728	4.545	75	895	2	4	1	8	0	1	8	0	0	3.958524115818158	
i 1	494.0134557823129	4.545	72	895	2	4	3	2	0	1	2	0	0	3.958524115818158	
i 1	494.0134557823129	3.0300000000000002	75	579	2	4	12	8	0	-2	8	0	0	3.958524115818158	
i 1	494.0147074829932	4.545	72	895	2	24	5	8	0	1	8	0	0	3.958524115818158	
i 1	496.995306122449	1.5150000000000001	75	580	2	4	9	8	0	1	8	0	0	3.958524115818158	
i 1	496.99655782312925	1.5150000000000001	75	580	2	24	14	2	0	-2	2	0	0	3.958524115818158	
i 1	497.0115782312925	1.5150000000000001	75	580	2	4	9	2	0	1	2	0	0	3.958524115818158	
i 1	497.0140816326531	1.5150000000000001	72	580	2	24	1	2	0	-2	2	0	0	3.958524115818158	
i 1	498.4902993197279	0.2525	72	405	2	24	10	2	0	1	2	0	0	3.958524115818158	
i 1	498.49655782312925	0.2525	75	791	2	24	1	2	0	-2	2	0	0	3.958524115818158	
i 1	498.4971836734694	0.2525	72	405	2	4	4	2	0	1	2	0	0	3.958524115818158	
i 1	498.4990612244898	0.2525	72	405	2	24	11	2	0	1	2	0	0	3.958524115818158	
i 1	498.504693877551	0.2525	75	791	2	24	4	2	0	-2	2	0	0	3.958524115818158	
i 1	498.504693877551	0.2525	72	791	2	4	7	2	0	-2	2	0	0	3.958524115818158	
i 1	498.5059455782313	0.2525	75	791	2	4	8	2	0	1	2	0	0	3.958524115818158	
i 1	498.51533333333333	0.2525	75	405	2	4	14	2	0	1	2	0	0	3.958524115818158	
i 1	498.7402993197279	38.1275	75	791	2	4	9	2	0	1	2	0	0	4.5287668464921715	
i 1	498.740925170068	14.645	72	405	2	24	12	2	0	1	2	0	0	4.5287668464921715	
i 1	498.740925170068	33.5825	75	405	2	4	15	2	0	1	2	0	0	4.5287668464921715	
i 1	498.74468027210884	4.04	75	791	2	24	1	2	0	-2	2	0	0	4.5287668464921715	
i 1	498.7471836734694	6.0600000000000005	75	791	2	24	1	2	0	-2	2	0	0	4.5287668464921715	
i 1	498.75344217687075	38.1275	72	791	2	4	1	2	0	-2	2	0	0	4.5287668464921715	
i 1	498.76032653061225	9.595	72	405	2	24	9	2	0	1	2	0	0	4.5287668464921715	
i 1	498.7628299319728	33.5825	72	405	2	4	4	2	0	1	2	0	0	4.5287668464921715	
i 1	502.7540680272109	0.2525	75	791	2	24	14	2	0	-2	2	0	0	4.5287668464921715	
i 1	503.004693877551	0.505	75	791	2	24	1	2	0	-2	2	0	0	4.5287668464921715	
i 1	503.4852925170068	0.2525	75	791	2	24	16	2	0	-2	2	0	0	4.5287668464921715	
i 1	503.7559455782313	1.5150000000000001	75	791	2	24	13	2	0	-2	2	0	0	4.5287668464921715	
i 1	504.754693877551	0.2525	75	791	2	24	10	2	0	-2	2	0	0	4.5287668464921715	
i 1	504.9959319727891	3.7875	75	791	2	24	13	2	0	-2	2	0	0	4.5287668464921715	
i 1	505.2597006802721	0.2525	75	791	2	24	4	2	0	-2	2	0	0	4.5287668464921715	
i 1	505.4996870748299	0.505	75	791	2	24	2	2	0	-2	2	0	0	4.5287668464921715	
i 1	505.99843537414966	0.2525	75	791	2	24	6	2	0	-2	2	0	0	4.5287668464921715	
i 1	506.2440544217687	0.2525	75	791	2	24	16	2	0	-2	2	0	0	4.5287668464921715	
i 1	506.5065714285714	0.2525	75	791	2	24	4	2	0	-2	2	0	0	4.5287668464921715	
i 1	506.74468027210884	1.7675	75	791	2	24	6	2	0	-2	2	0	0	4.5287668464921715	
i 1	508.23967346938775	0.2525	72	405	2	24	16	2	0	1	2	0	0	4.5287668464921715	
i 1	508.5003129251701	0.2525	75	791	2	24	16	2	0	-2	2	0	0	4.5287668464921715	
i 1	508.5065714285714	2.525	72	405	2	24	6	2	0	1	2	0	0	4.5287668464921715	
i 1	508.75531972789116	0.505	75	791	2	24	12	2	0	-2	2	0	0	4.5287668464921715	
i 1	508.7615782312925	0.7575000000000001	75	791	2	24	9	2	0	-2	2	0	0	4.5287668464921715	
i 1	509.2434285714286	1.2625	75	791	2	24	6	2	0	-2	2	0	0	4.5287668464921715	
i 1	509.49155102040817	0.2525	75	791	2	24	10	2	0	-2	2	0	0	4.5287668464921715	
i 1	509.7359183673469	0.2525	75	791	2	24	10	2	0	-2	2	0	0	4.5287668464921715	
i 1	509.9971836734694	0.2525	75	791	2	24	11	2	0	-2	2	0	0	4.5287668464921715	
i 1	510.24843537414966	1.01	75	791	2	24	15	2	0	-2	2	0	0	4.5287668464921715	
i 1	510.5097006802721	0.2525	75	791	2	24	16	2	0	-2	2	0	0	4.5287668464921715	
i 1	510.759074829932	5.8075	75	791	2	24	8	2	0	-2	2	0	0	4.5287668464921715	
i 1	510.9890476190476	0.2525	72	405	2	24	9	2	0	1	2	0	0	4.5287668464921715	
i 1	511.2478095238095	1.5150000000000001	72	405	2	24	2	2	0	1	2	0	0	4.5287668464921715	
i 1	511.2490612244898	0.2525	75	791	2	24	9	2	0	-2	2	0	0	4.5287668464921715	
i 1	511.4871700680272	0.7575000000000001	75	791	2	24	16	2	0	-2	2	0	0	4.5287668464921715	
i 1	512.2528163265306	0.2525	75	791	2	24	4	2	0	-2	2	0	0	4.5287668464921715	
i 1	512.5153333333334	1.01	75	791	2	24	7	2	0	-2	2	0	0	4.5287668464921715	
i 1	512.7359183673469	0.2525	72	405	2	24	10	2	0	1	2	0	0	4.5287668464921715	
i 1	512.9984353741496	1.5150000000000001	72	405	2	24	14	2	0	1	2	0	0	4.5287668464921715	
i 1	513.2346666666666	0.2525	72	405	2	24	1	2	0	1	2	0	0	4.5287668464921715	
i 1	513.4884217687074	1.2625	72	405	2	24	2	2	0	1	2	0	0	4.5287668464921715	
i 1	513.5078231292517	0.2525	75	791	2	24	10	2	0	-2	2	0	0	4.5287668464921715	
i 1	513.7465578231293	2.525	75	791	2	24	8	2	0	-2	2	0	0	4.5287668464921715	
i 1	514.5046938775511	0.2525	72	405	2	24	14	2	0	1	2	0	0	4.5287668464921715	
i 1	514.7459319727891	0.2525	72	405	2	24	10	2	0	1	2	0	0	4.5287668464921715	
i 1	514.7622040816326	0.505	72	405	2	24	2	2	0	1	2	0	0	4.5287668464921715	
i 1	514.9896734693878	17.17	72	405	2	24	15	2	0	1	2	0	0	4.5287668464921715	
i 1	515.2534421768707	0.2525	72	405	2	24	16	2	0	1	2	0	0	4.5287668464921715	
i 1	515.5090748299319	0.505	72	405	2	24	2	2	0	1	2	0	0	4.5287668464921715	
i 1	516.0147074829932	0.2525	72	405	2	24	2	2	0	1	2	0	0	4.5287668464921715	
i 1	516.2352925170068	0.2525	75	791	2	24	14	2	0	-2	2	0	0	4.5287668464921715	
i 1	516.2365442176871	15.9075	72	405	2	24	8	2	0	1	2	0	0	4.5287668464921715	
i 1	516.4846666666666	20.2	75	791	2	24	10	2	0	-2	2	0	0	4.5287668464921715	
i 1	516.4921768707483	0.7575000000000001	75	791	2	24	4	2	0	-2	2	0	0	4.5287668464921715	
i 1	517.2597006802721	19.4425	75	791	2	24	13	2	0	-2	2	0	0	4.5287668464921715	
i 1	531.9846666666666	4.545	72	89	2	24	12	2	0	-2	2	0	0	4.5287668464921715	
i 1	531.9921768707483	4.545	72	89	2	24	1	8	0	-2	8	0	0	4.5287668464921715	
i 1	531.9928027210884	4.545	75	89	2	4	11	2	0	1	2	0	0	4.5287668464921715	
i 1	531.9959319727891	4.545	72	89	2	4	6	8	0	1	8	0	0	4.5287668464921715	
i 1	536.4884217687074	8.08	75	584	2	4	3	2	0	1	2	0	0	4.5287668464921715	
i 1	536.4890476190476	8.08	75	584	2	24	4	2	0	-2	2	0	0	4.5287668464921715	
i 1	536.4921768707483	33.835	72	900	2	4	13	2	0	-2	2	0	0	4.5287668464921715	
i 1	536.4921768707483	8.08	72	584	2	4	4	2	0	-2	2	0	0	4.5287668464921715	
i 1	536.4940544217687	8.08	72	584	2	24	14	2	0	-2	2	0	0	4.5287668464921715	
i 1	536.5046938775511	33.835	75	900	2	4	15	2	0	1	2	0	0	4.5287668464921715	
i 1	536.5109523809524	33.835	75	900	2	24	11	2	1501	-2	2	0	0	4.5287668464921715	
i 1	536.5122040816326	33.835	75	900	2	24	8	8	1501	-2	8	0	0	4.5287668464921715	
i 1	544.4915510204081	25.755	72	402	2	24	8	2	0	-2	2	0	0	4.5287668464921715	
i 1	544.4934285714286	25.755	75	402	2	4	2	2	0	-2	2	0	0	4.5287668464921715	
i 1	544.5109523809524	25.755	75	402	2	24	14	8	0	1	8	0	0	4.5287668464921715	
i 1	544.5153333333334	25.755	72	402	2	4	8	2	0	-2	2	0	0	4.5287668464921715	
i 1	569.9852925170068	3.0300000000000002	75	584	2	4	5	2	0	-2	2	0	0	5.302195649147483	
i 1	569.9859183673469	4.545	72	198	2	24	15	8	1501	-2	8	0	0	5.302195649147483	
i 1	569.9940544217687	4.545	75	198	2	24	13	8	1501	-2	8	0	0	5.302195649147483	
i 1	569.9978095238096	4.545	72	198	2	4	1	8	1500	-2	8	0	0	5.302195649147483	
i 1	570.0071972789116	4.545	75	198	2	4	3	2	1500	1	2	0	0	5.302195649147483	
i 1	570.0084489795919	3.0300000000000002	75	584	2	24	9	2	1500	-2	2	0	0	5.302195649147483	
i 1	570.0109523809524	3.0300000000000002	72	584	2	24	6	8	1500	-2	8	0	0	5.302195649147483	
i 1	570.0140816326531	3.0300000000000002	72	584	2	4	1	2	0	-2	2	0	0	5.302195649147483	
i 1	572.9959319727891	1.5150000000000001	74	752	2	4	5	16	0	2	16	0	0	5.302195649147483	
i 1	572.9984353741496	1.5150000000000001	74	752	2	24	11	17	1500	1	17	0	0	5.302195649147483	
i 1	573.0028163265306	1.5150000000000001	74	752	2	4	7	17	0	2	17	0	0	5.302195649147483	
i 1	573.0053197278911	1.5150000000000001	74	752	2	24	1	16	1500	1	16	0	0	5.302195649147483	
i 1	574.4877959183674	2.02	77	89	2	4	11	16	0	1	16	0	0	5.302195649147483	
i 1	574.4915510204081	8.08	77	903	2	4	14	16	0	1	16	0	0	5.302195649147483	
i 1	574.4965578231293	8.08	77	903	2	24	7	17	1502	1	17	0	0	5.302195649147483	
i 1	574.4996870748299	2.2725	77	903	2	24	5	17	1502	2	17	0	0	5.302195649147483	
i 1	574.5003129251701	2.7775	77	89	2	24	12	16	1501	2	16	0	0	5.302195649147483	
i 1	574.5028163265306	8.08	74	903	2	4	10	17	0	1	17	0	0	5.302195649147483	
i 1	574.5128299319728	8.08	77	89	2	24	4	16	1501	2	16	0	0	5.302195649147483	
i 1	574.5153333333334	4.2925	77	89	2	4	15	17	0	1	17	0	0	5.302195649147483	
i 1	576.5071972789116	0.2525	77	89	2	4	3	16	0	1	16	0	0	5.302195649147483	
i 1	576.7634557823129	0.2525	77	903	2	24	11	17	1502	2	17	0	0	5.302195649147483	
i 1	576.7640816326531	2.525	77	89	2	4	12	16	0	1	16	0	0	5.302195649147483	
i 1	577.0046938775511	0.7575000000000001	77	903	2	24	6	17	1502	2	17	0	0	5.302195649147483	
i 1	577.2578231292517	0.2525	77	89	3	24	8	16	1501	2	16	0	0	5.302195649147483	
i 1	577.5015646258504	0.505	77	89	2	24	9	16	1501	2	16	0	0	5.302195649147483	
i 1	577.7571972789116	0.2525	77	903	2	24	12	17	1502	2	17	0	0	5.302195649147483	
i 1	577.9984353741496	0.7575000000000001	77	89	3	24	10	16	1501	2	16	0	0	5.302195649147483	
i 1	578.0059455782313	4.04	77	903	2	24	10	17	1502	2	17	0	0	5.302195649147483	
i 1	578.7421768707483	0.505	77	89	2	4	8	17	0	1	17	0	0	5.302195649147483	
i 1	578.7540680272109	0.7575000000000001	77	89	2	24	16	16	1501	2	16	0	0	5.302195649147483	
i 1	579.2509387755102	1.01	77	89	2	4	6	17	0	1	17	0	0	5.302195649147483	
i 1	579.2653333333334	0.2525	77	89	2	4	15	16	0	1	16	0	0	5.302195649147483	
i 1	579.5009387755102	0.7575000000000001	77	89	3	24	2	16	1501	2	16	0	0	5.302195649147483	
i 1	579.5147074829932	3.0300000000000002	77	89	2	4	9	16	0	1	16	0	0	5.302195649147483	
i 1	580.2446802721089	0.2525	77	89	2	4	13	17	0	1	17	0	0	5.302195649147483	
i 1	580.2503129251701	0.7575000000000001	77	89	2	24	7	16	1501	2	16	0	0	5.302195649147483	
i 1	580.5040680272109	1.7675	77	89	2	4	8	17	0	1	17	0	0	5.302195649147483	
i 1	580.9871700680272	0.2525	77	89	3	24	16	16	1501	2	16	0	0	5.302195649147483	
i 1	581.2559455782313	0.505	77	89	2	24	5	16	1501	2	16	0	0	5.302195649147483	
i 1	581.7615782312926	0.2525	77	89	3	24	7	16	1501	2	16	0	0	5.302195649147483	
i 1	581.9928027210884	0.2525	77	903	2	24	6	17	1502	2	17	0	0	5.302195649147483	
i 1	582.0046938775511	0.505	77	89	2	24	3	16	1501	2	16	0	0	5.302195649147483	
i 1	582.2584489795919	0.2525	77	903	2	24	4	17	1502	2	17	0	0	5.302195649147483	
i 1	582.2640816326531	0.2525	77	89	2	4	9	17	0	1	17	0	0	5.302195649147483	
i 1	582.4884217687074	5.3025	77	179	2	4	11	17	0	1	17	0	0	5.302195649147483	
i 1	582.4896734693878	1.5150000000000001	77	179	2	4	8	17	0	1	17	0	0	5.302195649147483	
i 1	582.4909251700681	2.02	74	179	2	24	8	16	1501	1	16	0	0	5.302195649147483	
i 1	582.4928027210884	1.7675	74	1148	2	24	11	17	1502	1	17	0	0	5.302195649147483	
i 1	582.4940544217687	3.2825	77	1148	2	4	3	16	0	1	16	0	0	5.302195649147483	
i 1	582.5053197278911	0.505	77	179	2	24	4	17	1501	1	17	0	0	5.302195649147483	
i 1	582.5078231292517	0.7575000000000001	77	1148	2	4	7	17	0	2	17	0	0	5.302195649147483	
i 1	582.5103265306122	0.505	77	1148	2	24	7	17	1502	1	17	0	0	5.302195649147483	
i 1	582.9902993197279	7.07	77	1148	2	24	6	17	1502	1	17	0	0	5.302195649147483	
i 1	582.9978095238096	0.2525	77	179	3	24	5	17	1501	1	17	0	0	5.302195649147483	
i 1	583.2478095238096	0.505	77	1148	2	4	8	17	0	2	17	0	0	5.302195649147483	
i 1	583.2515646258504	3.7875	77	179	2	24	8	17	1501	1	17	0	0	5.302195649147483	
i 1	583.7359183673469	3.535	77	1148	2	4	8	17	0	2	17	0	0	5.302195649147483	
i 1	583.9846666666666	0.2525	77	179	2	4	9	17	0	1	17	0	0	5.302195649147483	
i 1	584.2352925170068	0.7575000000000001	77	179	2	4	13	17	0	1	17	0	0	5.302195649147483	
i 1	584.2446802721089	0.2525	74	1148	2	24	3	17	1502	1	17	0	0	5.302195649147483	
i 1	584.4978095238096	0.505	74	179	3	24	16	16	1501	1	16	0	0	5.302195649147483	
i 1	584.5028163265306	0.7575000000000001	74	1148	2	24	6	17	1502	1	17	0	0	5.302195649147483	
i 1	585.0071972789116	0.505	74	179	2	24	16	16	1501	1	16	0	0	5.302195649147483	
i 1	585.0134557823129	0.2525	77	179	2	4	15	17	0	1	17	0	0	5.302195649147483	
i 1	585.2428027210884	1.5150000000000001	77	179	2	4	14	17	0	1	17	0	0	5.302195649147483	
i 1	585.2559455782313	0.2525	74	1148	2	24	2	17	1502	1	17	0	0	5.302195649147483	
i 1	585.4846666666666	0.2525	74	179	3	24	12	16	1501	1	16	0	0	5.302195649147483	
i 1	585.5040680272109	0.505	74	1148	2	24	1	17	1502	1	17	0	0	5.302195649147483	
i 1	585.7346666666666	3.535	74	179	2	24	13	16	1501	1	16	0	0	5.302195649147483	
i 1	585.7584489795919	0.2525	77	1148	2	4	13	16	0	1	16	0	0	5.302195649147483	
i 1	586.0015646258504	0.7575000000000001	74	1148	2	24	10	17	1502	1	17	0	0	5.302195649147483	
i 1	586.0140816326531	2.02	77	1148	2	4	7	16	0	1	16	0	0	5.302195649147483	
i 1	586.7346666666666	0.7575000000000001	74	1148	2	24	11	17	1502	1	17	0	0	5.302195649147483	
i 1	586.7546938775511	0.2525	77	179	2	4	15	17	0	1	17	0	0	5.302195649147483	
i 1	586.9884217687074	0.2525	77	179	3	24	5	17	1501	1	17	0	0	5.302195649147483	
i 1	587.0053197278911	2.7775	77	179	2	4	2	17	0	1	17	0	0	5.302195649147483	
i 1	587.2384217687074	1.2625	77	179	2	24	7	17	1501	1	17	0	0	5.302195649147483	
i 1	587.2503129251701	0.2525	77	1148	2	4	2	17	0	2	17	0	0	5.302195649147483	
i 1	587.4852925170068	1.2625	77	1148	2	4	6	17	0	2	17	0	0	5.302195649147483	
i 1	587.4934285714286	0.2525	74	1148	2	24	9	17	1502	1	17	0	0	5.302195649147483	
i 1	587.7484353741496	5.555	74	1148	2	24	3	17	1502	1	17	0	0	5.302195649147483	
i 1	587.7571972789116	0.2525	77	179	2	4	9	17	0	1	17	0	0	5.302195649147483	
i 1	587.9859183673469	0.2525	77	179	2	4	16	17	0	1	17	0	0	5.302195649147483	
i 1	588.0103265306122	0.2525	77	1148	2	4	1	16	0	1	16	0	0	5.302195649147483	
i 1	588.2371700680272	0.7575000000000001	77	1148	2	4	16	16	0	1	16	0	0	5.302195649147483	
i 1	588.2503129251701	0.2525	77	179	2	4	3	17	0	1	17	0	0	5.302195649147483	
i 1	588.4884217687074	1.01	77	179	2	4	5	17	0	1	17	0	0	5.302195649147483	
i 1	588.5103265306122	0.2525	77	179	3	24	14	17	1501	1	17	0	0	5.302195649147483	
i 1	588.7446802721089	0.2525	77	1148	2	4	3	17	0	2	17	0	0	5.302195649147483	
i 1	588.7465578231293	1.5150000000000001	77	179	2	24	14	17	1501	1	17	0	0	5.302195649147483	
i 1	588.9877959183674	0.2525	77	1148	2	4	10	16	0	1	16	0	0	5.302195649147483	
i 1	589.0071972789116	4.7975	77	1148	2	4	7	17	0	2	17	0	0	5.302195649147483	
i 1	589.2371700680272	0.2525	74	179	3	24	8	16	1501	1	16	0	0	5.302195649147483	
i 1	589.2434285714286	2.02	77	1148	2	4	16	16	0	1	16	0	0	5.302195649147483	
i 1	589.4871700680272	2.7775	74	179	2	24	10	16	1501	1	16	0	0	5.302195649147483	
i 1	589.4953061224489	0.2525	77	179	3	4	2	17	0	1	17	0	0	5.302195649147483	
i 1	589.7496870748299	0.2525	77	179	2	4	16	17	0	1	17	0	0	5.302195649147483	
i 1	589.7509387755102	1.2625	77	179	2	4	3	17	0	1	17	0	0	5.302195649147483	
i 1	589.9990612244898	0.2525	77	1148	2	24	2	17	1502	1	17	0	0	5.302195649147483	
i 1	590.0115782312926	4.545	77	179	2	4	5	17	0	1	17	0	0	5.302195649147483	
i 1	590.2421768707483	0.2525	77	179	3	24	7	17	1501	1	17	0	0	5.302195649147483	
i 1	590.2484353741496	0.2525	77	1148	2	24	5	17	1502	1	17	0	0	5.302195649147483	
i 1	590.5021904761904	0.505	77	1148	2	24	11	17	1502	1	17	0	0	5.302195649147483	
i 1	590.5059455782313	6.3125	77	179	2	24	5	17	1501	1	17	0	0	5.302195649147483	
i 1	590.9984353741496	4.7975	77	1148	2	24	10	17	1502	1	17	0	0	5.302195649147483	
i 1	591.0078231292517	0.2525	77	179	3	4	12	17	0	1	17	0	0	5.302195649147483	
i 1	591.2490612244898	1.01	77	1148	2	4	16	16	0	1	16	0	0	5.302195649147483	
i 1	591.2509387755102	1.2625	77	179	2	4	11	17	0	1	17	0	0	5.302195649147483	
i 1	592.2565714285714	0.2525	74	179	3	24	1	16	1501	1	16	0	0	5.302195649147483	
i 1	592.2584489795919	1.2625	77	1148	2	4	11	16	0	1	16	0	0	5.302195649147483	
i 1	592.4965578231293	0.2525	74	179	2	24	6	16	1501	1	16	0	0	5.302195649147483	
i 1	592.4996870748299	0.2525	77	179	3	4	14	17	0	1	17	0	0	5.302195649147483	
i 1	592.7371700680272	0.2525	74	179	3	24	1	16	1501	1	16	0	0	5.302195649147483	
i 1	592.7540680272109	0.2525	77	179	2	4	3	17	0	1	17	0	0	5.302195649147483	
i 1	592.9984353741496	0.2525	77	179	3	4	8	17	0	1	17	0	0	5.302195649147483	
i 1	593.0078231292517	5.3025	74	179	2	24	11	16	1501	1	16	0	0	5.302195649147483	
i 1	593.2515646258504	0.2525	74	1148	2	24	9	17	1502	1	17	0	0	5.302195649147483	
i 1	593.2559455782313	0.7575000000000001	77	179	2	4	10	17	0	1	17	0	0	5.302195649147483	
i 1	593.4846666666666	0.2525	77	1148	2	4	3	16	0	1	16	0	0	5.302195649147483	
i 1	593.5153333333334	2.7775	74	1148	2	24	3	17	1502	1	17	0	0	5.302195649147483	
i 1	593.7440544217687	0.505	77	1148	2	4	1	16	0	1	16	0	0	5.302195649147483	
i 1	593.7597006802721	0.2525	77	1148	2	4	13	17	0	2	17	0	0	5.302195649147483	
i 1	593.9902993197279	3.0300000000000002	77	1148	2	4	3	17	0	2	17	0	0	5.302195649147483	
i 1	593.9971836734694	0.2525	77	179	3	4	11	17	0	1	17	0	0	5.302195649147483	
i 1	594.2453061224489	3.0300000000000002	77	179	2	4	11	17	0	1	17	0	0	5.302195649147483	
i 1	594.2609523809524	0.2525	77	1148	2	4	2	16	0	1	16	0	0	5.302195649147483	
i 1	594.4915510204081	1.01	77	179	3	4	2	17	0	1	17	0	0	5.302195649147483	
i 1	594.4996870748299	1.01	77	1148	2	4	10	16	0	1	16	0	0	5.302195649147483	
i 1	595.5065714285714	0.2525	77	1148	2	4	8	16	0	1	16	0	0	5.302195649147483	
i 1	595.5090748299319	10.1	77	179	2	4	8	17	0	1	17	0	0	5.302195649147483	
i 1	595.7428027210884	2.2725	77	1148	2	4	8	16	0	1	16	0	0	5.302195649147483	
i 1	595.7528163265306	0.505	77	1148	2	24	11	17	1502	1	17	0	0	5.302195649147483	
i 1	596.2402993197279	2.525	77	1148	2	24	11	17	1502	1	17	0	0	5.302195649147483	
i 1	596.2540680272109	0.505	74	1148	2	24	9	17	1502	1	17	0	0	5.302195649147483	
i 1	596.7352925170068	0.2525	77	179	3	24	1	17	1501	1	17	0	0	5.302195649147483	
i 1	596.7540680272109	0.7575000000000001	74	1148	2	24	5	17	1502	1	17	0	0	5.302195649147483	
i 1	596.9928027210884	0.7575000000000001	77	179	2	24	8	17	1501	1	17	0	0	5.302195649147483	
i 1	597.0034421768707	0.2525	77	1148	2	4	14	17	0	2	17	0	0	5.302195649147483	
i 1	597.2453061224489	0.2525	77	179	3	4	8	17	0	1	17	0	0	5.302195649147483	
i 1	597.2565714285714	1.7675	77	1148	2	4	3	17	0	2	17	0	0	5.302195649147483	
i 1	597.4928027210884	0.2525	74	1148	2	24	5	17	1502	1	17	0	0	5.302195649147483	
i 1	597.5071972789116	1.01	77	179	2	4	12	17	0	1	17	0	0	5.302195649147483	
i 1	597.7615782312926	0.2525	77	179	3	24	1	17	1501	1	17	0	0	5.302195649147483	
i 1	597.7615782312926	2.525	74	1148	2	24	8	17	1502	1	17	0	0	5.302195649147483	
i 1	597.9884217687074	2.525	77	179	2	24	5	17	1501	1	17	0	0	5.302195649147483	
i 1	597.9978095238096	0.2525	77	1148	2	4	8	16	0	1	16	0	0	5.302195649147483	
i 1	598.2352925170068	1.01	77	1148	2	4	2	16	0	1	16	0	0	5.302195649147483	
i 1	598.2459319727891	0.2525	74	179	3	24	9	16	1501	1	16	0	0	5.302195649147483	
i 1	598.4909251700681	0.2525	77	179	3	4	11	17	0	1	17	0	0	5.302195649147483	
i 1	598.5040680272109	2.525	74	179	2	24	3	16	1501	1	16	0	0	5.302195649147483	
i 1	598.7440544217687	0.2525	77	1148	2	24	14	17	1502	1	17	0	0	5.302195649147483	
i 1	598.7440544217687	1.01	77	179	2	4	1	17	0	1	17	0	0	5.302195649147483	
i 1	598.9915510204081	0.2525	77	1148	2	4	1	17	0	2	17	0	0	5.302195649147483	
i 1	599.0059455782313	1.01	77	1148	2	24	5	17	1502	1	17	0	0	5.302195649147483	
i 1	599.2359183673469	5.555	77	1148	2	4	3	17	0	2	17	0	0	5.302195649147483	
i 1	599.2421768707483	0.505	77	1148	2	4	2	16	0	1	16	0	0	5.302195649147483	
i 1	599.7503129251701	0.2525	77	179	3	4	9	17	0	1	17	0	0	5.302195649147483	
i 1	599.7546938775511	2.02	77	1148	2	4	16	16	0	1	16	0	0	5.302195649147483	
i 1	599.9865442176871	0.2525	77	1148	2	24	11	17	1502	1	17	0	0	5.302195649147483	
i 1	599.9996870748299	0.7575000000000001	77	179	2	4	16	17	0	1	17	0	0	5.302195649147483	
i 1	600.2377959183674	0.2525	74	1148	2	24	3	17	1502	1	17	0	0	5.302195649147483	
i 1	600.2521904761904	1.2625	77	1148	2	24	2	17	1502	1	17	0	0	5.302195649147483	
i 1	600.4846666666666	2.02	74	1148	2	24	7	17	1502	1	17	0	0	5.302195649147483	
i 1	600.5046938775511	0.2525	77	179	3	24	2	17	1501	1	17	0	0	5.302195649147483	
i 1	600.7434285714286	3.2825	77	179	2	24	12	17	1501	1	17	0	0	5.302195649147483	
i 1	600.7446802721089	0.2525	77	179	3	4	14	17	0	1	17	0	0	5.302195649147483	
i 1	600.9902993197279	0.2525	74	179	3	24	13	16	1501	1	16	0	0	5.302195649147483	
i 1	600.9996870748299	0.2525	77	179	2	4	1	17	0	1	17	0	0	5.302195649147483	
i 1	601.2471836734694	0.2525	77	179	3	4	9	17	0	1	17	0	0	5.302195649147483	
i 1	601.2528163265306	2.02	74	179	2	24	15	16	1501	1	16	0	0	5.302195649147483	
i 1	601.4852925170068	1.5150000000000001	77	179	2	4	2	17	0	1	17	0	0	5.302195649147483	
i 1	601.5084489795919	0.2525	77	1148	2	24	16	17	1502	1	17	0	0	5.302195649147483	
i 1	601.7428027210884	0.505	77	1148	2	24	16	17	1502	1	17	0	0	5.302195649147483	
i 1	601.7609523809524	0.505	77	1148	2	4	2	16	0	1	16	0	0	5.302195649147483	
i 1	602.2346666666666	0.2525	77	1148	2	24	2	17	1502	1	17	0	0	5.302195649147483	
i 1	602.2415510204081	0.505	77	1148	2	4	9	16	0	1	16	0	0	5.302195649147483	
i 1	602.4978095238096	2.7775	77	1148	2	24	14	17	1502	1	17	0	0	5.302195649147483	
i 1	602.5071972789116	0.2525	74	1148	2	24	16	17	1502	1	17	0	0	5.302195649147483	
i 1	602.7415510204081	0.2525	77	1148	2	4	16	16	0	1	16	0	0	5.302195649147483	
i 1	602.7515646258504	5.3025	74	1148	2	24	10	17	1502	1	17	0	0	5.302195649147483	
i 1	602.9859183673469	2.7775	77	1148	2	4	9	16	0	1	16	0	0	5.302195649147483	
i 1	602.9896734693878	0.2525	77	179	3	4	4	17	0	1	17	0	0	5.302195649147483	
i 1	603.2559455782313	0.2525	77	179	2	4	15	17	0	1	17	0	0	5.302195649147483	
i 1	603.2609523809524	0.2525	74	179	2	24	1	16	1501	1	16	0	0	5.302195649147483	
i 1	603.5053197278911	0.505	77	179	3	4	9	17	0	1	17	0	0	5.302195649147483	
i 1	603.5097006802721	3.7875	74	179	2	24	4	16	1501	1	16	0	0	5.302195649147483	
i 1	604.0078231292517	0.2525	77	179	3	24	6	17	1501	1	17	0	0	5.302195649147483	
i 1	604.0103265306122	0.2525	77	179	2	4	9	17	0	1	17	0	0	5.302195649147483	
i 1	604.2346666666666	0.2525	77	179	2	24	16	17	1501	1	17	0	0	5.302195649147483	
i 1	604.2390476190476	0.2525	77	179	3	4	3	17	0	1	17	0	0	5.302195649147483	
i 1	604.5078231292517	0.2525	77	179	3	24	16	17	1501	1	17	0	0	5.302195649147483	
i 1	604.5140816326531	3.535	77	179	2	4	12	17	0	1	17	0	0	5.302195649147483	
i 1	604.7534421768707	0.2525	77	179	2	24	14	17	1501	1	17	0	0	5.302195649147483	
i 1	604.7597006802721	0.2525	77	1148	2	4	9	17	0	2	17	0	0	5.302195649147483	
i 1	604.9852925170068	0.2525	77	179	3	24	7	17	1501	1	17	0	0	5.302195649147483	
i 1	605.0065714285714	3.0300000000000002	77	1148	2	4	7	17	0	2	17	0	0	5.302195649147483	
i 1	605.2359183673469	0.7575000000000001	77	179	2	24	2	17	1501	1	17	0	0	5.302195649147483	
i 1	605.2359183673469	0.2525	77	1148	2	24	3	17	1502	1	17	0	0	5.302195649147483	
i 1	605.4846666666666	0.2525	77	179	3	4	15	17	0	1	17	0	0	5.302195649147483	
i 1	605.5053197278911	2.525	77	1148	2	24	13	17	1502	1	17	0	0	5.302195649147483	
i 1	605.7359183673469	0.2525	77	1148	2	4	3	16	0	1	16	0	0	5.302195649147483	
i 1	605.7640816326531	0.505	77	179	2	4	9	17	0	1	17	0	0	5.302195649147483	
i 1	605.9946802721089	0.2525	77	179	3	24	3	17	1501	1	17	0	0	5.302195649147483	
i 1	605.9984353741496	2.02	77	1148	2	4	5	16	0	1	16	0	0	5.302195649147483	
i 1	606.2578231292517	0.2525	77	179	2	24	5	17	1501	1	17	0	0	5.302195649147483	
i 1	606.2615782312926	0.2525	77	179	3	4	13	17	0	1	17	0	0	5.302195649147483	
i 1	606.5021904761904	0.505	77	179	3	24	12	17	1501	1	17	0	0	5.302195649147483	
i 1	606.5103265306122	0.505	77	179	2	4	3	17	0	1	17	0	0	5.302195649147483	
i 1	606.9909251700681	0.2525	77	179	3	4	15	17	0	1	17	0	0	5.302195649147483	
i 1	606.9940544217687	1.01	77	179	2	24	8	17	1501	1	17	0	0	5.302195649147483	
i 1	607.2371700680272	0.2525	74	179	2	24	15	16	1501	1	16	0	0	5.302195649147483	
i 1	607.2603265306122	0.2525	77	179	2	4	14	17	0	1	17	0	0	5.302195649147483	
i 1	607.5103265306122	0.2525	74	179	2	24	14	16	1501	1	16	0	0	5.302195649147483	
i 1	607.5103265306122	0.2525	77	179	3	4	11	17	0	1	17	0	0	5.302195649147483	
i 1	607.7390476190476	0.2525	77	179	2	4	9	17	0	1	17	0	0	5.302195649147483	
i 1	607.7647074829932	0.2525	74	179	2	24	9	16	1501	1	16	0	0	5.302195649147483	
i 1	607.9884217687074	3.0300000000000002	74	881	2	24	4	17	0	2	17	0	0	5.302195649147483	
i 1	607.9990612244898	0.2525	77	67	3	4	9	16	0	1	16	0	0	5.302195649147483	
i 1	608.0009387755102	3.0300000000000002	74	67	2	24	9	16	1501	1	16	0	0	5.302195649147483	
i 1	608.0084489795919	3.0300000000000002	77	67	2	4	11	16	0	1	16	0	0	5.302195649147483	
i 1	608.0097006802721	1.5150000000000001	74	881	2	4	4	16	0	1	16	0	0	5.302195649147483	
i 1	608.0103265306122	1.2625	74	881	2	4	12	17	0	1	17	0	0	5.302195649147483	
i 1	608.0153333333334	0.2525	74	67	2	24	15	16	1501	1	16	0	0	5.302195649147483	
i 1	608.0153333333334	0.505	77	881	2	24	11	17	0	2	17	0	0	5.302195649147483	
i 1	608.2415510204081	0.2525	74	67	2	24	14	16	1501	1	16	0	0	5.302195649147483	
i 1	608.2534421768707	2.7775	77	67	2	4	7	16	0	1	16	0	0	5.302195649147483	
i 1	608.4915510204081	0.2525	74	67	2	24	10	16	1501	1	16	0	0	5.302195649147483	
i 1	608.5103265306122	0.2525	77	881	2	24	4	17	0	2	17	0	0	5.302195649147483	
i 1	608.7390476190476	0.2525	77	881	2	24	5	17	0	2	17	0	0	5.302195649147483	
i 1	608.7515646258504	0.2525	74	67	2	24	11	16	1501	1	16	0	0	5.302195649147483	
i 1	608.9884217687074	0.2525	77	881	2	24	13	17	0	2	17	0	0	5.302195649147483	
i 1	609.0115782312926	2.02	74	67	2	24	4	16	1501	1	16	0	0	5.302195649147483	
i 1	609.2396734693878	1.7675	77	881	2	24	14	17	0	2	17	0	0	5.302195649147483	
i 1	609.2534421768707	0.2525	74	881	2	4	12	17	0	1	17	0	0	5.302195649147483	
i 1	609.5053197278911	0.2525	74	881	2	4	13	16	0	1	16	0	0	5.302195649147483	
i 1	609.5090748299319	1.5150000000000001	74	881	2	4	2	17	0	1	17	0	0	5.302195649147483	
i 1	609.7509387755102	1.2625	74	881	2	4	1	16	0	1	16	0	0	5.302195649147483	
i 1	610.9902993197279	1.5150000000000001	74	780	2	24	1	16	0	1	16	0	0	5.302195649147483	
i 1	610.9965578231293	1.5150000000000001	74	780	2	4	2	16	0	2	16	0	0	5.302195649147483	
i 1	611.0065714285714	1.5150000000000001	74	780	2	4	12	17	0	1	17	0	0	5.302195649147483	
i 1	611.0097006802721	1.5150000000000001	74	1096	2	4	12	16	0	1	16	0	0	5.302195649147483	
i 1	611.0115782312926	1.5150000000000001	74	1096	2	24	5	17	0	1	17	0	0	5.302195649147483	
i 1	611.0140816326531	1.5150000000000001	77	1096	2	24	9	16	0	1	16	0	0	5.302195649147483	
i 1	611.0140816326531	1.5150000000000001	77	780	2	24	6	17	0	1	17	0	0	5.302195649147483	
i 1	611.0153333333334	1.5150000000000001	74	1096	2	4	11	17	0	2	17	0	0	5.302195649147483	
i 1	612.4965578231293	0.2525	74	602	2	24	2	17	0	2	17	0	0	5.302195649147483	
i 1	612.4971836734694	29.0375	77	602	2	24	2	16	0	2	16	0	0	5.302195649147483	
i 1	612.4978095238096	29.0375	74	918	2	24	5	17	0	1	17	0	0	5.302195649147483	
i 1	612.5040680272109	29.0375	74	918	2	4	5	17	0	1	17	0	0	5.302195649147483	
i 1	612.5053197278911	29.0375	77	918	2	24	11	17	0	1	17	0	0	5.302195649147483	
i 1	612.5053197278911	29.0375	74	602	2	4	3	17	0	1	17	0	0	5.302195649147483	
i 1	612.5109523809524	1.01	77	602	2	4	15	17	0	2	17	0	0	5.302195649147483	
i 1	612.5140816326531	1.5150000000000001	77	918	2	4	4	17	0	2	17	0	0	5.302195649147483	
i 1	612.7384217687074	0.2525	74	602	2	24	1	17	0	2	17	0	0	5.302195649147483	
i 1	613.0090748299319	0.7575000000000001	74	602	2	24	9	17	0	2	17	0	0	5.302195649147483	
i 1	613.5059455782313	0.2525	77	602	2	4	16	17	0	2	17	0	0	5.302195649147483	
i 1	613.7409251700681	27.775	77	602	2	4	15	17	0	2	17	0	0	5.302195649147483	
i 1	613.7521904761904	0.2525	74	602	2	24	1	17	0	2	17	0	0	5.302195649147483	
i 1	613.9934285714286	0.505	77	918	2	4	9	17	0	2	17	0	0	5.302195649147483	
i 1	614.0021904761904	27.5225	74	602	2	24	13	17	0	2	17	0	0	5.302195649147483	
i 1	614.4909251700681	27.017500000000002	77	918	2	4	8	17	0	2	17	0	0	5.302195649147483	
i 1	641.2377959183674	43.1775	74	918	2	24	7	17	0	1	17	0	0	5.934238528271724	
i 1	641.2409251700681	4.7975	74	602	2	24	16	17	0	2	17	0	0	5.934238528271724	
i 1	641.2453061224489	4.7975	77	602	2	24	2	16	0	2	16	0	0	5.934238528271724	
i 1	641.2459319727891	31.0575	74	918	2	4	12	17	0	1	17	0	0	5.934238528271724	
i 1	641.2484353741496	43.1775	77	918	2	24	9	17	0	1	17	0	0	5.934238528271724	
i 1	641.2540680272109	4.7975	74	602	2	4	10	17	0	1	17	0	0	5.934238528271724	
i 1	641.2603265306122	4.7975	77	602	2	4	16	17	0	2	17	0	0	5.934238528271724	
i 1	641.2653333333334	30.552500000000002	77	918	2	4	6	17	0	2	17	0	0	5.934238528271724	
i 1	645.9978095238096	3.0300000000000002	77	104	2	24	10	16	0	2	16	0	0	5.934238528271724	
i 1	646.0015646258504	3.0300000000000002	74	104	2	4	1	17	0	2	17	0	0	5.934238528271724	
i 1	646.0034421768707	3.0300000000000002	74	104	2	24	16	16	0	2	16	0	0	5.934238528271724	
i 1	646.0084489795919	3.0300000000000002	77	104	2	4	14	17	0	2	17	0	0	5.934238528271724	
i 1	648.9915510204081	1.5150000000000001	74	216	2	24	2	16	0	2	16	0	0	5.934238528271724	
i 1	648.9921768707483	1.5150000000000001	74	216	2	4	9	16	0	1	16	0	0	5.934238528271724	
i 1	648.9965578231293	1.5150000000000001	74	216	2	4	11	17	0	2	17	0	0	5.934238528271724	
i 1	649.0097006802721	1.5150000000000001	74	216	2	24	4	17	0	1	17	0	0	5.934238528271724	
i 1	650.4928027210884	21.9675	74	420	2	24	2	16	0	1	16	0	0	5.934238528271724	
i 1	650.5003129251701	23.735	77	420	2	4	16	17	0	2	17	0	0	5.934238528271724	
i 1	650.5015646258504	20.705000000000002	74	420	2	4	1	16	0	2	16	0	0	5.934238528271724	
i 1	650.5034421768707	38.38	77	420	2	24	8	17	0	2	17	0	0	5.934238528271724	
i 1	670.9928027210884	0.505	74	420	2	4	15	16	0	2	16	0	0	5.934238528271724	
i 1	671.5065714285714	0.2525	74	420	2	4	12	16	0	2	16	0	0	5.934238528271724	
i 1	671.5122040816326	0.2525	77	918	2	4	6	17	0	2	17	0	0	5.934238528271724	
i 1	671.7421768707483	4.7975	77	918	2	4	3	17	0	2	17	0	0	5.934238528271724	
i 1	671.7553197278911	0.2525	74	420	2	4	3	16	0	2	16	0	0	5.934238528271724	
i 1	671.9965578231293	0.2525	74	918	2	4	5	17	0	1	17	0	0	5.934238528271724	
i 1	672.0128299319728	1.7675	74	420	2	4	3	16	0	2	16	0	0	5.934238528271724	
i 1	672.2484353741496	0.2525	74	420	2	24	14	16	0	1	16	0	0	5.934238528271724	
i 1	672.2622040816326	0.7575000000000001	74	918	2	4	1	17	0	1	17	0	0	5.934238528271724	
i 1	672.4940544217687	16.16	74	420	2	24	1	16	0	1	16	0	0	5.934238528271724	
i 1	673.0059455782313	0.505	74	918	2	4	15	17	0	1	17	0	0	5.934238528271724	
i 1	673.4934285714286	2.02	74	918	2	4	12	17	0	1	17	0	0	5.934238528271724	
i 1	673.7421768707483	0.2525	74	420	2	4	2	16	0	2	16	0	0	5.934238528271724	
i 1	673.9884217687074	1.2625	74	420	2	4	5	16	0	2	16	0	0	5.934238528271724	
i 1	673.9896734693878	0.2525	77	420	2	4	2	17	0	2	17	0	0	5.934238528271724	
i 1	674.2428027210884	0.2525	77	420	2	4	5	17	0	2	17	0	0	5.934238528271724	
i 1	674.4902993197279	0.505	77	420	2	4	3	17	0	2	17	0	0	5.934238528271724	
i 1	675.0128299319728	1.01	77	420	2	4	11	17	0	2	17	0	0	5.934238528271724	
i 1	675.2509387755102	0.2525	74	420	2	4	13	16	0	2	16	0	0	5.934238528271724	
i 1	675.4978095238096	0.2525	74	918	2	4	11	17	0	1	17	0	0	5.934238528271724	
i 1	675.4990612244898	3.2825	74	420	2	4	11	16	0	2	16	0	0	5.934238528271724	
i 1	675.7540680272109	5.3025	74	918	2	4	5	17	0	1	17	0	0	5.934238528271724	
i 1	676.0053197278911	0.2525	77	420	2	4	9	17	0	2	17	0	0	5.934238528271724	
i 1	676.2409251700681	0.7575000000000001	77	420	2	4	6	17	0	2	17	0	0	5.934238528271724	
i 1	676.4928027210884	0.2525	77	918	2	4	14	17	0	2	17	0	0	5.934238528271724	
i 1	676.7653333333334	1.5150000000000001	77	918	2	4	8	17	0	2	17	0	0	5.934238528271724	
i 1	677.0115782312926	0.2525	77	420	2	4	14	17	0	2	17	0	0	5.934238528271724	
i 1	677.2440544217687	5.555	77	420	2	4	8	17	0	2	17	0	0	5.934238528271724	
i 1	678.2446802721089	0.2525	77	918	2	4	10	17	0	2	17	0	0	5.934238528271724	
i 1	678.4921768707483	5.555	77	918	2	4	9	17	0	2	17	0	0	5.934238528271724	
i 1	678.7346666666666	0.2525	74	420	2	4	1	16	0	2	16	0	0	5.934238528271724	
i 1	678.9978095238096	0.505	74	420	2	4	6	16	0	2	16	0	0	5.934238528271724	
i 1	679.4890476190476	0.2525	74	420	2	4	14	16	0	2	16	0	0	5.934238528271724	
i 1	679.7434285714286	4.7975	74	420	2	4	7	16	0	2	16	0	0	5.934238528271724	
i 1	680.9959319727891	0.2525	74	918	2	4	4	17	0	1	17	0	0	5.934238528271724	
i 1	681.2490612244898	1.2625	74	918	2	4	13	17	0	1	17	0	0	5.934238528271724	
i 1	682.5040680272109	0.2525	74	918	2	4	1	17	0	1	17	0	0	5.934238528271724	
i 1	682.7484353741496	0.2525	77	420	2	4	7	17	0	2	17	0	0	5.934238528271724	
i 1	682.7490612244898	1.2625	74	918	2	4	13	17	0	1	17	0	0	5.934238528271724	
i 1	683.0097006802721	5.555	77	420	2	4	7	17	0	2	17	0	0	5.934238528271724	
i 1	683.9915510204081	4.545	74	806	2	24	4	17	0	1	17	0	0	5.934238528271724	
i 1	684.0003129251701	4.545	77	806	2	24	16	16	0	1	16	0	0	5.934238528271724	
i 1	684.0103265306122	4.545	77	806	2	4	3	16	0	1	16	0	0	5.934238528271724	
i 1	684.0122040816326	4.545	74	806	2	4	8	17	0	2	17	0	0	5.934238528271724	
i 1	684.4959319727891	0.2525	74	420	2	4	14	16	0	2	16	0	0	5.934238528271724	
i 1	684.7459319727891	0.7575000000000001	74	420	2	4	7	16	0	2	16	0	0	5.934238528271724	
i 1	685.5009387755102	0.2525	74	420	2	4	3	16	0	2	16	0	0	5.934238528271724	
i 1	685.7446802721089	0.7575000000000001	74	420	2	4	6	16	0	2	16	0	0	5.934238528271724	
i 1	686.5140816326531	0.2525	74	420	2	4	8	16	0	2	16	0	0	5.934238528271724	
i 1	686.7571972789116	0.505	74	420	2	4	8	16	0	2	16	0	0	5.934238528271724	
i 1	687.2471836734694	0.2525	74	420	2	4	11	16	0	2	16	0	0	5.934238528271724	
i 1	687.5084489795919	1.01	74	420	2	4	11	16	0	2	16	0	0	5.934238528271724	
i 1	688.4852925170068	24.240000000000002	77	399	2	4	7	16	0	1	16	0	0	5.934238528271724	
i 1	688.4859183673469	24.240000000000002	77	399	2	4	14	17	0	1	17	0	0	5.934238528271724	
i 1	688.5053197278911	8.585	74	399	2	24	16	16	0	2	16	0	0	5.934238528271724	
i 1	688.5071972789116	24.240000000000002	77	897	2	24	8	17	0	1	17	0	0	5.934238528271724	
i 1	688.5084489795919	0.2525	74	897	2	4	9	17	0	2	17	0	0	5.934238528271724	
i 1	688.5115782312926	24.240000000000002	77	897	2	24	14	16	0	1	16	0	0	5.934238528271724	
i 1	688.5153333333334	11.11	74	399	2	24	7	16	0	2	16	0	0	5.934238528271724	
i 1	688.5153333333334	24.240000000000002	77	897	2	4	5	17	0	2	17	0	0	5.934238528271724	
i 1	688.7377959183674	1.2625	74	897	2	4	4	17	0	2	17	0	0	5.934238528271724	
i 1	689.9902993197279	0.2525	74	897	2	4	14	17	0	2	17	0	0	5.934238528271724	
i 1	690.2553197278911	22.4725	74	897	2	4	15	17	0	2	17	0	0	5.934238528271724	
i 1	696.9896734693878	0.2525	74	399	2	24	15	16	0	2	16	0	0	5.934238528271724	
i 1	697.2478095238096	0.2525	74	399	2	24	13	16	0	2	16	0	0	5.934238528271724	
i 1	697.5153333333334	0.2525	74	399	2	24	4	16	0	2	16	0	0	5.934238528271724	
i 1	697.7540680272109	2.7775	74	399	2	24	8	16	0	2	16	0	0	5.934238528271724	
i 1	699.5084489795919	0.505	74	399	2	24	16	16	0	2	16	0	0	5.934238528271724	
i 1	700.0034421768707	0.7575000000000001	74	399	2	24	2	16	0	2	16	0	0	5.934238528271724	
i 1	700.5034421768707	0.2525	74	399	2	24	15	16	0	2	16	0	0	5.934238528271724	
i 1	700.7528163265306	0.7575000000000001	74	399	2	24	14	16	0	2	16	0	0	5.934238528271724	
i 1	700.7609523809524	0.7575000000000001	74	399	2	24	6	16	0	2	16	0	0	5.934238528271724	
i 1	701.4896734693878	6.3125	74	399	2	24	7	16	0	2	16	0	0	5.934238528271724	
i 1	701.5128299319728	0.2525	74	399	2	24	12	16	0	2	16	0	0	5.934238528271724	
i 1	701.7421768707483	3.0300000000000002	74	399	2	24	9	16	0	2	16	0	0	5.934238528271724	
i 1	704.7434285714286	0.2525	74	399	2	24	2	16	0	2	16	0	0	5.934238528271724	
i 1	704.9865442176871	0.2525	74	399	2	24	14	16	0	2	16	0	0	5.934238528271724	
i 1	705.2459319727891	0.2525	74	399	2	24	12	16	0	2	16	0	0	5.934238528271724	
i 1	705.5147074829932	1.5150000000000001	74	399	2	24	6	16	0	2	16	0	0	5.934238528271724	
i 1	707.0078231292517	0.2525	74	399	2	24	7	16	0	2	16	0	0	5.934238528271724	
i 1	707.2584489795919	5.3025	74	399	2	24	8	16	0	2	16	0	0	5.934238528271724	
i 1	707.7584489795919	0.2525	74	399	2	24	11	16	0	2	16	0	0	5.934238528271724	
i 1	708.0046938775511	4.545	74	399	2	24	1	16	0	2	16	0	0	5.934238528271724	
i 1	712.4902993197279	41.915	77	897	2	4	13	17	0	2	17	0	0	6.1432795808655545	
i 1	712.4996870748299	41.915	74	897	2	4	8	17	0	2	17	0	0	6.1432795808655545	
i 1	712.5021904761904	41.915	74	399	2	24	15	16	0	2	16	0	0	6.1432795808655545	
i 1	712.5046938775511	41.915	77	399	2	4	14	16	0	1	16	0	0	6.1432795808655545	
i 1	712.5090748299319	41.915	74	399	2	24	11	16	0	2	16	0	0	6.1432795808655545	
i 1	712.5090748299319	41.915	77	897	2	24	16	16	0	1	16	0	0	6.1432795808655545	
i 1	712.5103265306122	41.915	77	897	2	24	6	17	0	1	17	0	0	6.1432795808655545	
i 1	712.5140816326531	41.915	77	399	2	4	7	17	0	1	17	0	0	6.1432795808655545	
t0 92
</CsScore>
</CsoundSynthesizer>

