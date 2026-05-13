; started: 8/13/18 
; last edit: 4/30/23 
; again: 4/17/26 and many before that.
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
 iVoicet = (iSampleType == 5 ? (p7 + max(iVel - 60, 0)/2) : p7) ; 2:1 volume change to sample change
 iVoicet = (iSampleType == 5 ? (min(iVoicet, 38)) : p7) 
 iVoice = int(iVoicet + 0.5) 
 print(p4, iVel, p7, iSampleType, iVoicet, iVoice) 
; table f1 has the start location of the sample tables control functions 
 iSampWaveTable table iVoice,1 ; find the location of the sample wave tables base on input p7 
 print(iSampWaveTable) 
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
 iHighValue table iLength-1, iSampWaveTable ; use last valid index, not guard point (guard may be 0)
 ; If MIDI note is outside sample range (iFtableTemp==0 from GEN17 initial value), clamp to highest valid sample
 if iFtableTemp == 0 then
     iFtableTemp = iHighValue
     iFtable = iHighValue
 endif
 ; GEN17 initial 0 means no sample assigned; use iFtableTemp as floor to avoid ftable 0 (mono)
 iLowValue = (iLowValue == 0 ? iFtableTemp : iLowValue)
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
 ; ivoice, iFtableTemp iFtable giMoved always print 
 ; + + + + + 
 if iFtable != iFtableTemp then 
 printf_i "voice: %i. switched sample from %i to %i. Total moved so far: %i\n", 1, iVoice, iFtableTemp, iFtable, giMoved 
 else 
 printf_i "voice: %i. no switch %i == %i\n", 1, iVoice, iFtableTemp, iFtable 
 endif 
 iFound: ; nothing found the target sample in the sample collection. Move ok. 
 
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
 if iSampWaveTable == 1474 then
     printf_i "BOSEN: MIDI=%i iFtableTemp=%i iFtable=%i iHigh=%i iLow=%i iloop=%i\n", 1, iMIDInumber, iFtableTemp, iFtable, iHighValue, iLowValue, iloop
 endif
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
 outs a1 * kpan_l ,a2 * kpan_r ; outs has been deprecated?
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
; finger_piano_part: voice # McGill instrument # 
; 6 finger piano 1 1 112 
; 2 bass finger piano 1 24 
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
; 8 trumpet 2 25 40 
; trombone 
; tuba 
; ------------------------------------------ 
; total samples 329 
; both parts: Wait a bit before adding the piano. It's terribly complicated and prone to untraceable errors. 
; 8 Bosendorfer 11 494 184 
; ------- 
; 823 samples in total 
; 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 
f630 0 128 -17 0 634 44 635 48 636 50 637 52 638 54 639 56 640 58 641 60 642 62 643 64 644 66 645 68 646 70 647 72 648 74 649 76 650 78 651 80 
f631 0 64 -2 0  43  47  49  51  53  55  57  59  61  63  65  67  69  71  73  75  77  79 
f632 0 64 -2 0 -6  -8  +2  -13 +17 -4  0   0   0   0   0   0   0   0   0   0   0   0   
f633 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f652 0 128 -17 0 656 49 657 52 658 55 659 58 660 64 661 67 662 70 663 73 664 76 665 79 666 82 
f653 0 64 -2 0  48  51  54  57  63  66  69  72  75  78  81 
f654 0 64 -2 0 -13 -31 0   0   0   0   +6  0   +13 0   0   
f655 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 
f667 0 128 -17 0 671 37 672 41 673 46 674 50 675 53 676 60 677 61 678 65 679 67 680 69 681 72 682 75 
f668 0 64 -2 0  36  40  45  49  52  59  60  64  66  68  71  74 
f669 0 64 -2 0 +13 +49 -6  +11 +1  +8  +1  +8  +7  0   0   0   
f670 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 
f683 0 128 -17 0 687 30 688 33 689 36 690 39 691 45 692 48 693 51 694 54 695 57 696 60 697 63 698 66 699 69 700 73 701 75 702 78 703 81 704 84 
f684 0 64 -2 0  29  32  35  38  44  47  50  53  56  59  62  65  68  72  74  77  80  83 
f685 0 64 -2 0 +8  +5  +8  +11 +7  +7  +5  +6  -2  -8  +5  +5  +3  +2  +9  +5  +4  +7  
f686 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f705 0 128 -17 0 709 54 710 56 711 58 712 60 713 62 714 64 715 66 716 68 717 70 718 72 719 74 720 76 721 78 722 80 723 82 724 84 725 86 
f706 0 64 -2 0  53  55  57  59  61  63  65  67  69  71  73  75  77  79  81  83  85 
f707 0 64 -2 0 +14 +13 +13 +12 +12 +13 +12 +13 +13 0   0   0   0   0   0   +18 +19 
f708 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f726 0 128 -17 0 730 42 731 46 732 50 733 52 734 55 735 58 736 61 737 64 738 67 739 71 740 74 741 78 
f727 0 64 -2 0  41  45  49  51  54  57  60  63  66  70  73  77 
f728 0 64 -2 0 +6  +6  +6  +6  +5  +4  +4  +4  +5  +5  +7  +6  
f729 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 
f742 0 128 -17 0 746 14 747 16 748 18 749 21 750 24 751 28 752 30 753 35 754 41 755 44 756 47 757 50 758 53 759 57 760 61 761 65 762 68 763 76 764 80 765 84 
f743 0 64 -2 0  13  15  17  20  23  27  29  34  40  43  46  49  52  56  60  64  67  75  79  83 
f744 0 64 -2 0 -25 -33 -16 +1  +1  -1  -3  +12 -11 +1  -4  +13 +3  -6  +4  -7  +2  -8  0   -21 
f745 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f766 0 128 -17 0 770 44 771 46 772 48 773 50 774 52 775 54 776 56 777 58 778 60 779 62 780 64 781 66 782 68 783 70 784 72 785 74 786 76 
f767 0 64 -2 0  43  45  47  49  51  53  55  57  59  61  63  65  67  69  71  73  75 
f768 0 64 -2 0 -9  -12 +4  +8  +3  +7  -8  +9  +4  +24 +14 0   +3  0   0   0   0   
f769 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f787 0 128 -17 0 791 37 792 39 793 41 794 43 795 46 796 49 797 51 798 53 799 55 800 58 801 60 802 62 803 64 804 69 805 71 806 73 
f788 0 64 -2 0  36  38  40  42  45  48  50  52  54  57  59  61  63  68  70  72 
f789 0 64 -2 0 -11 -21 -13 -25 0   -2  -2  -33 -28 +9  0   0   -31 0   0   0   
f790 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f807 0 128 -17 0 811 25 812 27 813 29 814 31 815 33 816 35 817 37 818 39 819 41 820 43 821 47 822 49 823 51 824 53 825 55 826 57 827 59 828 61 829 63 
f808 0 64 -2 0  24  26  28  30  32  34  36  38  40  42  46  48  50  52  54  56  58  60  62 
f809 0 64 -2 0 +38 +6  0   -3  -9  -8  +8  -10 -9  -2  +1  0   -25 -5  -9  +24 -16 +15 +12 
f810 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f830 0 128 -17 0 834 23 835 25 836 27 837 29 838 31 839 33 840 35 841 37 842 39 843 41 844 43 845 45 846 47 847 49 848 51 849 53 
f831 0 64 -2 0  22  24  26  28  30  32  34  36  38  40  42  44  46  48  50  52 
f832 0 64 -2 0 +5  +7  +12 +2  -2  +5  +2  +1  +3  -3  -1  -6  +2  +2  +1  0   
f833 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f850 0 128 -17 0 854 39 855 41 856 43 857 45 858 47 859 49 860 53 861 55 862 57 863 59 864 61 865 63 866 65 867 67 868 69 869 71 870 73 871 75 
f851 0 64 -2 0  38  40  42  44  46  48  52  54  56  58  60  62  64  66  68  70  72  74 
f852 0 64 -2 0 +1  +5  +1  0   +7  +2  +5  +1  +2  +1  +4  +1  +4  +5  +3  +2  +2  +1  
f853 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f872 0 128 -17 0 876 49 877 51 878 55 879 59 880 65 881 70 882 72 883 74 884 76 885 78 886 80 887 82 888 84 889 85 
f873 0 64 -2 0  48  50  54  58  64  69  71  73  75  77  79  81  83  84 
f874 0 64 -2 0 -2  -8  +10 +12 +3  -2  +7  +8  +6  +7  +6  +4  +7  +22 
f875 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f890 0 128 -17 0 894 47 895 49 896 51 897 53 898 55 899 57 900 59 901 61 902 63 903 65 904 69 905 71 906 73 907 75 908 77 
f891 0 64 -2 0  46  48  50  52  54  56  58  60  62  64  68  70  72  74  76 
f892 0 64 -2 0 -12 +4  +6  +7  +9  +10 -8  -7  +15 +8  +5  +2  +14 +12 +22 
f893 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f909 0 128 -17 0 913 27 914 29 915 31 916 33 917 35 918 39 919 41 920 43 921 45 922 47 923 49 924 51 925 53 926 55 927 59 928 61 929 63 
f910 0 64 -2 0  26  28  30  32  34  38  40  42  44  46  48  50  52  54  58  60  62 
f911 0 64 -2 0 +1  -2  +3  -15 +5  -4  +13 -1  -6  -9  -5  +1  +2  -7  -6  +1  +3  
f912 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f930 0 128 -17 0 934 45 935 47 936 49 937 51 938 53 939 55 940 57 941 59 942 62 943 64 944 66 945 68 946 70 947 72 948 74 949 76 950 78 951 80 952 82 
f931 0 64 -2 0  44  46  48  50  52  54  56  58  61  63  65  67  69  71  73  75  77  79  81 
f932 0 64 -2 0 +3  -3  -1  +1  +3  -7  -2  -7  +14 +21 0   +6  -8  +6  -30 +9  -18 +8  -19 
f933 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f953 0 128 -17 0 957 38 958 39 959 41 960 43 961 45 962 47 963 49 964 51 965 53 966 55 967 57 968 59 969 61 970 65 971 67 972 70 973 72 974 74 
f954 0 64 -2 0  37  38  40  42  44  46  48  50  52  54  56  58  60  64  66  69  71  73 
f955 0 64 -2 0 -14 -26 -33 -13 -26 -13 -10 -3  -18 -40 -5  -1  -2  +0  +13 -1  -6  -5  
f956 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f975 0 128 -17 0 979 26 980 28 981 30 982 32 983 34 984 36 985 38 986 40 987 42 988 44 989 46 990 48 991 50 992 52 993 54 994 56 995 58 996 60 997 62 998 64 
f976 0 64 -2 0  25  27  29  31  33  35  37  39  41  43  45  47  49  51  53  55  57  59  61  63 
f977 0 64 -2 0 +1  +2  0   0   -1  -4  -1  +3  -3  -3  -11 -5  -8  -8  -5  -4  -2  -2  +14 -35 
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
f1158 0 64 -2 0 +2  -4  +5  +8  -10 -5  +2  +3  -1  0   +1  +1  -4  +6  0   -2  -6  
f1159 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f1177 0 128 -17 0 1181 29 1182 32 1183 35 1184 38 1185 41 1186 44 1187 47 1188 50 1189 53 1190 56 1191 59 
f1178 0 64 -2 0  28  31  34  37  40  43  46  49  52  55  58 
f1179 0 64 -2 0 0   -7  -1  -4  -7  0   -9  +6  +5  +3  -6  
f1180 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 
f1192 0 128 -17 0 1196 25 1197 27 1198 30 1199 32 1200 34 1201 36 1202 38 1203 40 1204 42 1205 44 1206 46 1207 48 1208 50 1209 52 1210 54 1211 56 
f1193 0 64 -2 0  24  26  29  31  33  35  37  39  41  43  45  47  49  51  53  55 
f1194 0 64 -2 0 +6  +2  +4  0   +2  +4  +1  -6  +1  +1  +2  +3  +1  +3  +4  +6  
f1195 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f1212 0 128 -17 0 1216 58 
f1213 0 64 -2 0  57 
f1214 0 64 -2 0  0  
f1215 0 64 -2 0 1 
f1217 0 128 -17 0 1221 10 1222 12 1223 13 1224 15 1225 17 1226 18 1227 20 1228 22 1229 24 1230 25 1231 27 1232 29 1233 30 1234 32 1235 34 1236 36 1237 37 1238 48 1239 51 1240 53 1241 60 1242 61 1243 63 1244 65 1245 66 1246 68 1247 73 1248 75 
  1249 77 1250 78 1251 80 1252 82 1253 84 1254 85 1255 87 1256 89 1257 90 1258 92 1259 94 1260 96 1261 97 
f1218 0 64 -2 0   9  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  36  47  50  52  59  60  62  64  65  67  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1219 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1220 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1262 0 128 -17 0 1266 10 1267 12 1268 13 1269 15 1270 17 1271 18 1272 20 1273 22 1274 24 1275 25 1276 27 1277 29 1278 30 1279 32 1280 34 1281 36 1282 37 1283 39 1284 41 1285 42 1286 44 1287 46 1288 48 1289 49 1290 51 1291 53 1292 54 1293 56 
  1294 58 1295 60 1296 61 1297 63 1298 65 1299 66 1300 68 1301 70 1302 72 1303 73 1304 75 1305 77 1306 78 1307 80 1308 82 1309 85 1310 87 1311 89 1312 90 1313 92 1314 94 1315 96 1316 97 
f1263 0 64 -2 0   9  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  84  86  88  89  91  93  95  96 
f1264 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1265 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1317 0 128 -17 0 1321 10 1322 12 1323 13 1324 15 1325 17 1326 18 1327 20 1328 22 1329 25 1330 27 1331 29 1332 30 1333 32 1334 34 1335 36 1336 37 1337 41 1338 44 1339 48 1340 49 1341 51 1342 61 1343 63 1344 65 1345 66 1346 68 1347 72 1348 73 
  1349 75 1350 77 1351 78 1352 80 1353 82 1354 84 1355 85 1356 87 1357 89 1358 90 1359 92 1360 94 1361 96 1362 97 
f1318 0 64 -2 0   9  11  12  14  16  17  19  21  24  26  28  29  31  33  35  36  40  43  47  48  50  60  62  64  65  67  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1319 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1320 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1363 0 128 -17 0 1367 10 1368 12 1369 13 1370 15 1371 17 1372 18 1373 20 1374 22 1375 24 1376 27 1377 29 1378 30 1379 32 1380 34 1381 36 1382 37 1383 39 1384 41 1385 42 1386 44 1387 46 1388 48 1389 49 1390 51 1391 53 1392 54 1393 56 1394 58 
  1395 60 1396 61 1397 63 1398 65 1399 66 1400 68 1401 70 1402 72 1403 73 1404 75 1405 77 1406 78 1407 80 1408 82 1409 84 1410 85 1411 87 1412 89 1413 90 1414 92 1415 94 1416 96 1417 97 
f1364 0 64 -2 0   9  11  12  14  16  17  19  21  23  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1365 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1366 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1418 0 128 -17 0 1422 10 1423 12 1424 13 1425 15 1426 17 1427 18 1428 20 1429 22 1430 24 1431 25 1432 27 1433 29 1434 30 1435 32 1436 34 1437 36 1438 37 1439 39 1440 41 1441 42 1442 44 1443 46 1444 48 1445 49 1446 51 1447 53 1448 54 1449 56 
  1450 58 1451 60 1452 61 1453 63 1454 65 1455 66 1456 68 1457 70 1458 72 1459 73 1460 75 1461 77 1462 78 1463 80 1464 82 1465 84 1466 85 1467 87 1468 89 1469 90 1470 92 1471 94 1472 96 1473 97 
f1419 0 64 -2 0   9  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1420 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1421 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1474 0 128 -17 0 1478 12 1479 13 1480 15 1481 17 1482 18 1483 20 1484 22 1485 24 1486 25 1487 27 1488 29 1489 30 1490 32 1491 34 1492 36 1493 37 1494 39 1495 41 1496 42 1497 44 1498 46 1499 48 1500 49 1501 51 1502 53 1503 54 1504 56 1505 58 
  1506 60 1507 61 1508 63 1509 65 1510 66 1511 68 1512 70 1513 72 1514 73 1515 75 1516 77 1517 78 1518 80 1519 82 1520 84 1521 85 1522 87 1523 89 1524 90 1525 92 1526 94 1527 96 1528 97 
f1475 0 64 -2 0  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1476 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1477 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1529 0 128 -17 0 1533 10 1534 12 1535 13 1536 15 1537 17 1538 18 1539 20 1540 22 1541 24 1542 25 1543 27 1544 29 1545 30 1546 32 1547 34 1548 36 1549 37 1550 39 1551 41 1552 42 1553 44 1554 46 1555 48 1556 49 1557 51 1558 53 1559 54 1560 56 
  1561 58 1562 60 1563 61 1564 63 1565 65 1566 66 1567 68 1568 70 1569 72 1570 73 1571 75 1572 77 1573 78 1574 80 1575 82 1576 84 1577 85 1578 87 1579 89 1580 90 1581 92 1582 94 1583 96 1584 97 
f1530 0 64 -2 0   9  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1531 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1532 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1585 0 128 -17 0 1589 10 1590 12 1591 13 1592 15 1593 17 1594 18 1595 20 1596 22 1597 24 1598 25 1599 27 1600 29 1601 30 1602 32 1603 34 1604 36 1605 37 1606 39 1607 41 1608 42 1609 44 1610 46 1611 48 1612 49 1613 51 1614 53 1615 54 1616 56 
  1617 58 1618 60 1619 61 1620 63 1621 65 1622 66 1623 68 1624 70 1625 72 1626 73 1627 75 1628 77 1629 78 1630 80 1631 82 1632 84 1633 85 1634 87 1635 89 1636 90 1637 92 1638 94 1639 96 1640 97 
f1586 0 64 -2 0   9  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1587 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1588 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1641 0 128 -17 0 1645 10 1646 12 1647 13 1648 15 1649 17 1650 18 1651 20 1652 22 1653 24 1654 25 1655 27 1656 29 1657 30 1658 34 1659 36 1660 37 1661 39 1662 41 1663 42 1664 44 1665 46 1666 48 1667 49 1668 51 1669 53 1670 54 1671 56 1672 58 
  1673 60 1674 61 1675 63 1676 65 1677 66 1678 68 1679 70 1680 72 1681 73 1682 75 1683 77 1684 78 1685 80 1686 82 1687 84 1688 85 1689 87 1690 89 1691 90 1692 92 1693 94 1694 96 1695 97 
f1642 0 64 -2 0   9  11  12  14  16  17  19  21  23  24  26  28  29  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1643 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1644 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1696 0 128 -17 0 1700 10 1701 12 1702 13 1703 15 1704 17 1705 18 1706 20 1707 22 1708 24 1709 25 1710 27 1711 29 1712 30 1713 32 1714 34 1715 36 1716 39 1717 41 1718 42 1719 44 1720 46 1721 48 1722 49 1723 51 1724 53 1725 54 1726 56 1727 58 
  1728 60 1729 61 1730 63 1731 65 1732 66 1733 68 1734 70 1735 72 1736 73 1737 75 1738 77 1739 78 1740 80 1741 82 1742 84 1743 85 1744 87 1745 89 1746 90 1747 92 1748 94 1749 96 1750 97 
f1697 0 64 -2 0   9  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1698 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1699 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
; 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 
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
f1216 0 0 1 "samples/sine/triangle.wav" 0 0 0
f1221 0 0 1 "./samples/Bosendor/25 emp A0.wav" 0 0 0
f1222 0 0 1 "./samples/Bosendor/25 emp B0-.wav" 0 0 0
f1223 0 0 1 "./samples/Bosendor/25 emp C1-.wav" 0 0 0
f1224 0 0 1 "./samples/Bosendor/25 emp D1-.wav" 0 0 0
f1225 0 0 1 "./samples/Bosendor/25 emp E1-.wav" 0 0 0
f1226 0 0 1 "./samples/Bosendor/25 emp F1-.wav" 0 0 0
f1227 0 0 1 "./samples/Bosendor/25 emp G1-.wav" 0 0 0
f1228 0 0 1 "./samples/Bosendor/25 emp A1.wav" 0 0 0
f1229 0 0 1 "./samples/Bosendor/25 emp B1-.wav" 0 0 0
f1230 0 0 1 "./samples/Bosendor/25 emp C2-.wav" 0 0 0
f1231 0 0 1 "./samples/Bosendor/25 emp D2-.wav" 0 0 0
f1232 0 0 1 "./samples/Bosendor/25 emp E2-.wav" 0 0 0
f1233 0 0 1 "./samples/Bosendor/25 emp F2-.wav" 0 0 0
f1234 0 0 1 "./samples/Bosendor/25 emp G2-.wav" 0 0 0
f1235 0 0 1 "./samples/Bosendor/25 emp A2-.wav" 0 0 0
f1236 0 0 1 "./samples/Bosendor/25 emp B2-.wav" 0 0 0
f1237 0 0 1 "./samples/Bosendor/25 emp C3-.wav" 0 0 0
f1238 0 0 1 "./samples/Bosendor/25 emp B3-.wav" 0 0 0
f1239 0 0 1 "./samples/Bosendor/25 emp D4-.wav" 0 0 0
f1240 0 0 1 "./samples/Bosendor/25 emp E4-.wav" 0 0 0
f1241 0 0 1 "./samples/Bosendor/25 emp B4-.wav" 0 0 0
f1242 0 0 1 "./samples/Bosendor/25 emp C5-.wav" 0 0 0
f1243 0 0 1 "./samples/Bosendor/25 emp D5-.wav" 0 0 0
f1244 0 0 1 "./samples/Bosendor/25 emp E5-.wav" 0 0 0
f1245 0 0 1 "./samples/Bosendor/25 emp F5-.wav" 0 0 0
f1246 0 0 1 "./samples/Bosendor/25 emp G5-.wav" 0 0 0
f1247 0 0 1 "./samples/Bosendor/25 emp C6-.wav" 0 0 0
f1248 0 0 1 "./samples/Bosendor/25 emp D6-.wav" 0 0 0
f1249 0 0 1 "./samples/Bosendor/25 emp E6-.wav" 0 0 0
f1250 0 0 1 "./samples/Bosendor/25 emp F6-.wav" 0 0 0
f1251 0 0 1 "./samples/Bosendor/25 emp G6-.wav" 0 0 0
f1252 0 0 1 "./samples/Bosendor/25 emp A6-.wav" 0 0 0
f1253 0 0 1 "./samples/Bosendor/25 emp B6-.wav" 0 0 0
f1254 0 0 1 "./samples/Bosendor/25 emp C7-.wav" 0 0 0
f1255 0 0 1 "./samples/Bosendor/25 emp D7-.wav" 0 0 0
f1256 0 0 1 "./samples/Bosendor/25 emp E7-.wav" 0 0 0
f1257 0 0 1 "./samples/Bosendor/25 emp F7-.wav" 0 0 0
f1258 0 0 1 "./samples/Bosendor/25 emp G7-.wav" 0 0 0
f1259 0 0 1 "./samples/Bosendor/25 emp A7-.wav" 0 0 0
f1260 0 0 1 "./samples/Bosendor/25 emp B7-.wav" 0 0 0
f1261 0 0 1 "./samples/Bosendor/25 emp C8-.wav" 0 0 0
f1266 0 0 1 "./samples/Bosendor/31 emp A0.wav" 0 0 0
f1267 0 0 1 "./samples/Bosendor/31 emp B0-.wav" 0 0 0
f1268 0 0 1 "./samples/Bosendor/31 emp C1-.wav" 0 0 0
f1269 0 0 1 "./samples/Bosendor/31 emp D1-.wav" 0 0 0
f1270 0 0 1 "./samples/Bosendor/31 emp E1-.wav" 0 0 0
f1271 0 0 1 "./samples/Bosendor/31 emp F1-.wav" 0 0 0
f1272 0 0 1 "./samples/Bosendor/31 emp G1-.wav" 0 0 0
f1273 0 0 1 "./samples/Bosendor/31 emp A1.wav" 0 0 0
f1274 0 0 1 "./samples/Bosendor/31 emp B1-.wav" 0 0 0
f1275 0 0 1 "./samples/Bosendor/31 emp C2-.wav" 0 0 0
f1276 0 0 1 "./samples/Bosendor/31 emp D2-.wav" 0 0 0
f1277 0 0 1 "./samples/Bosendor/31 emp E2-.wav" 0 0 0
f1278 0 0 1 "./samples/Bosendor/31 emp F2-.wav" 0 0 0
f1279 0 0 1 "./samples/Bosendor/31 emp G2-.wav" 0 0 0
f1280 0 0 1 "./samples/Bosendor/31 emp A2-.wav" 0 0 0
f1281 0 0 1 "./samples/Bosendor/31 emp B2-.wav" 0 0 0
f1282 0 0 1 "./samples/Bosendor/31 emp C3-.wav" 0 0 0
f1283 0 0 1 "./samples/Bosendor/31 emp D3-.wav" 0 0 0
f1284 0 0 1 "./samples/Bosendor/31 emp E3-.wav" 0 0 0
f1285 0 0 1 "./samples/Bosendor/31 emp F3-.wav" 0 0 0
f1286 0 0 1 "./samples/Bosendor/31 emp G3-.wav" 0 0 0
f1287 0 0 1 "./samples/Bosendor/31 emp A3-.wav" 0 0 0
f1288 0 0 1 "./samples/Bosendor/31 emp B3-.wav" 0 0 0
f1289 0 0 1 "./samples/Bosendor/31 emp C4-.wav" 0 0 0
f1290 0 0 1 "./samples/Bosendor/31 emp D4-.wav" 0 0 0
f1291 0 0 1 "./samples/Bosendor/31 emp E4-.wav" 0 0 0
f1292 0 0 1 "./samples/Bosendor/31 emp F4-.wav" 0 0 0
f1293 0 0 1 "./samples/Bosendor/31 emp G4-.wav" 0 0 0
f1294 0 0 1 "./samples/Bosendor/31 emp A4-.wav" 0 0 0
f1295 0 0 1 "./samples/Bosendor/31 emp B4-.wav" 0 0 0
f1296 0 0 1 "./samples/Bosendor/31 emp C5-.wav" 0 0 0
f1297 0 0 1 "./samples/Bosendor/31 emp D5-.wav" 0 0 0
f1298 0 0 1 "./samples/Bosendor/31 emp E5-.wav" 0 0 0
f1299 0 0 1 "./samples/Bosendor/31 emp F5-.wav" 0 0 0
f1300 0 0 1 "./samples/Bosendor/31 emp G5-.wav" 0 0 0
f1301 0 0 1 "./samples/Bosendor/31 emp A5-.wav" 0 0 0
f1302 0 0 1 "./samples/Bosendor/31 emp B5-.wav" 0 0 0
f1303 0 0 1 "./samples/Bosendor/31 emp C6-.wav" 0 0 0
f1304 0 0 1 "./samples/Bosendor/31 emp D6-.wav" 0 0 0
f1305 0 0 1 "./samples/Bosendor/31 emp E6-.wav" 0 0 0
f1306 0 0 1 "./samples/Bosendor/31 emp F6-.wav" 0 0 0
f1307 0 0 1 "./samples/Bosendor/31 emp G6-.wav" 0 0 0
f1308 0 0 1 "./samples/Bosendor/31 emp A6-.wav" 0 0 0
f1309 0 0 1 "./samples/Bosendor/31 emp C7-.wav" 0 0 0
f1310 0 0 1 "./samples/Bosendor/31 emp D7-.wav" 0 0 0
f1311 0 0 1 "./samples/Bosendor/31 emp E7-.wav" 0 0 0
f1312 0 0 1 "./samples/Bosendor/31 emp F7-.wav" 0 0 0
f1313 0 0 1 "./samples/Bosendor/31 emp G7-.wav" 0 0 0
f1314 0 0 1 "./samples/Bosendor/31 emp A7-.wav" 0 0 0
f1315 0 0 1 "./samples/Bosendor/31 emp B7-.wav" 0 0 0
f1316 0 0 1 "./samples/Bosendor/31 emp C8-.wav" 0 0 0
f1321 0 0 1 "./samples/Bosendor/39 emp A0.wav" 0 0 0
f1322 0 0 1 "./samples/Bosendor/39 emp B0-.wav" 0 0 0
f1323 0 0 1 "./samples/Bosendor/39 emp C1-.wav" 0 0 0
f1324 0 0 1 "./samples/Bosendor/39 emp D1-.wav" 0 0 0
f1325 0 0 1 "./samples/Bosendor/39 emp E1-.wav" 0 0 0
f1326 0 0 1 "./samples/Bosendor/39 emp F1-.wav" 0 0 0
f1327 0 0 1 "./samples/Bosendor/39 emp G1-.wav" 0 0 0
f1328 0 0 1 "./samples/Bosendor/39 emp A1.wav" 0 0 0
f1329 0 0 1 "./samples/Bosendor/39 emp C2-.wav" 0 0 0
f1330 0 0 1 "./samples/Bosendor/39 emp D2-.wav" 0 0 0
f1331 0 0 1 "./samples/Bosendor/39 emp E2-.wav" 0 0 0
f1332 0 0 1 "./samples/Bosendor/39 emp F2-.wav" 0 0 0
f1333 0 0 1 "./samples/Bosendor/39 emp G2-.wav" 0 0 0
f1334 0 0 1 "./samples/Bosendor/39 emp A2-.wav" 0 0 0
f1335 0 0 1 "./samples/Bosendor/39 emp B2-.wav" 0 0 0
f1336 0 0 1 "./samples/Bosendor/39 emp C3-.wav" 0 0 0
f1337 0 0 1 "./samples/Bosendor/39 emp E3-.wav" 0 0 0
f1338 0 0 1 "./samples/Bosendor/39 emp G3-.wav" 0 0 0
f1339 0 0 1 "./samples/Bosendor/39 emp B3-.wav" 0 0 0
f1340 0 0 1 "./samples/Bosendor/39 emp C4-.wav" 0 0 0
f1341 0 0 1 "./samples/Bosendor/39 emp D4-.wav" 0 0 0
f1342 0 0 1 "./samples/Bosendor/39 emp C5-.wav" 0 0 0
f1343 0 0 1 "./samples/Bosendor/39 emp D5-.wav" 0 0 0
f1344 0 0 1 "./samples/Bosendor/39 emp E5-.wav" 0 0 0
f1345 0 0 1 "./samples/Bosendor/39 emp F5-.wav" 0 0 0
f1346 0 0 1 "./samples/Bosendor/39 emp G5-.wav" 0 0 0
f1347 0 0 1 "./samples/Bosendor/39 emp B5-.wav" 0 0 0
f1348 0 0 1 "./samples/Bosendor/39 emp C6-.wav" 0 0 0
f1349 0 0 1 "./samples/Bosendor/39 emp D6-.wav" 0 0 0
f1350 0 0 1 "./samples/Bosendor/39 emp E6-.wav" 0 0 0
f1351 0 0 1 "./samples/Bosendor/39 emp F6-.wav" 0 0 0
f1352 0 0 1 "./samples/Bosendor/39 emp G6-.wav" 0 0 0
f1353 0 0 1 "./samples/Bosendor/39 emp A6-.wav" 0 0 0
f1354 0 0 1 "./samples/Bosendor/39 emp B6-.wav" 0 0 0
f1355 0 0 1 "./samples/Bosendor/39 emp C7-.wav" 0 0 0
f1356 0 0 1 "./samples/Bosendor/39 emp D7-.wav" 0 0 0
f1357 0 0 1 "./samples/Bosendor/39 emp E7-.wav" 0 0 0
f1358 0 0 1 "./samples/Bosendor/39 emp F7-.wav" 0 0 0
f1359 0 0 1 "./samples/Bosendor/39 emp G7-.wav" 0 0 0
f1360 0 0 1 "./samples/Bosendor/39 emp A7-.wav" 0 0 0
f1361 0 0 1 "./samples/Bosendor/39 emp B7-.wav" 0 0 0
f1362 0 0 1 "./samples/Bosendor/39 emp C8-.wav" 0 0 0
f1367 0 0 1 "./samples/Bosendor/47 emp A0.wav" 0 0 0
f1368 0 0 1 "./samples/Bosendor/47 emp B0-.wav" 0 0 0
f1369 0 0 1 "./samples/Bosendor/47 emp C1-.wav" 0 0 0
f1370 0 0 1 "./samples/Bosendor/47 emp D1-.wav" 0 0 0
f1371 0 0 1 "./samples/Bosendor/47 emp E1-.wav" 0 0 0
f1372 0 0 1 "./samples/Bosendor/47 emp F1-.wav" 0 0 0
f1373 0 0 1 "./samples/Bosendor/47 emp G1-.wav" 0 0 0
f1374 0 0 1 "./samples/Bosendor/47 emp A1.wav" 0 0 0
f1375 0 0 1 "./samples/Bosendor/47 emp B1-.wav" 0 0 0
f1376 0 0 1 "./samples/Bosendor/47 emp D2-.wav" 0 0 0
f1377 0 0 1 "./samples/Bosendor/47 emp E2-.wav" 0 0 0
f1378 0 0 1 "./samples/Bosendor/47 emp F2-.wav" 0 0 0
f1379 0 0 1 "./samples/Bosendor/47 emp G2-.wav" 0 0 0
f1380 0 0 1 "./samples/Bosendor/47 emp A2-.wav" 0 0 0
f1381 0 0 1 "./samples/Bosendor/47 emp B2-.wav" 0 0 0
f1382 0 0 1 "./samples/Bosendor/47 emp C3-.wav" 0 0 0
f1383 0 0 1 "./samples/Bosendor/47 emp D3-.wav" 0 0 0
f1384 0 0 1 "./samples/Bosendor/47 emp E3-.wav" 0 0 0
f1385 0 0 1 "./samples/Bosendor/47 emp F3-.wav" 0 0 0
f1386 0 0 1 "./samples/Bosendor/47 emp G3-.wav" 0 0 0
f1387 0 0 1 "./samples/Bosendor/47 emp A3-.wav" 0 0 0
f1388 0 0 1 "./samples/Bosendor/47 emp B3-.wav" 0 0 0
f1389 0 0 1 "./samples/Bosendor/47 emp C4-.wav" 0 0 0
f1390 0 0 1 "./samples/Bosendor/47 emp D4-.wav" 0 0 0
f1391 0 0 1 "./samples/Bosendor/47 emp E4-.wav" 0 0 0
f1392 0 0 1 "./samples/Bosendor/47 emp F4-.wav" 0 0 0
f1393 0 0 1 "./samples/Bosendor/47 emp G4-.wav" 0 0 0
f1394 0 0 1 "./samples/Bosendor/47 emp A4-.wav" 0 0 0
f1395 0 0 1 "./samples/Bosendor/47 emp B4-.wav" 0 0 0
f1396 0 0 1 "./samples/Bosendor/47 emp C5-.wav" 0 0 0
f1397 0 0 1 "./samples/Bosendor/47 emp D5-.wav" 0 0 0
f1398 0 0 1 "./samples/Bosendor/47 emp E5-.wav" 0 0 0
f1399 0 0 1 "./samples/Bosendor/47 emp F5-.wav" 0 0 0
f1400 0 0 1 "./samples/Bosendor/47 emp G5-.wav" 0 0 0
f1401 0 0 1 "./samples/Bosendor/47 emp A5-.wav" 0 0 0
f1402 0 0 1 "./samples/Bosendor/47 emp B5-.wav" 0 0 0
f1403 0 0 1 "./samples/Bosendor/47 emp C6-.wav" 0 0 0
f1404 0 0 1 "./samples/Bosendor/47 emp D6-.wav" 0 0 0
f1405 0 0 1 "./samples/Bosendor/47 emp E6-.wav" 0 0 0
f1406 0 0 1 "./samples/Bosendor/47 emp F6-.wav" 0 0 0
f1407 0 0 1 "./samples/Bosendor/47 emp G6-.wav" 0 0 0
f1408 0 0 1 "./samples/Bosendor/47 emp A6-.wav" 0 0 0
f1409 0 0 1 "./samples/Bosendor/47 emp B6-.wav" 0 0 0
f1410 0 0 1 "./samples/Bosendor/47 emp C7-.wav" 0 0 0
f1411 0 0 1 "./samples/Bosendor/47 emp D7-.wav" 0 0 0
f1412 0 0 1 "./samples/Bosendor/47 emp E7-.wav" 0 0 0
f1413 0 0 1 "./samples/Bosendor/47 emp F7-.wav" 0 0 0
f1414 0 0 1 "./samples/Bosendor/47 emp G7-.wav" 0 0 0
f1415 0 0 1 "./samples/Bosendor/47 emp A7-.wav" 0 0 0
f1416 0 0 1 "./samples/Bosendor/47 emp B7-.wav" 0 0 0
f1417 0 0 1 "./samples/Bosendor/47 emp C8-.wav" 0 0 0
f1422 0 0 1 "./samples/Bosendor/63 emp A0.wav" 0 0 0
f1423 0 0 1 "./samples/Bosendor/63 emp B0-.wav" 0 0 0
f1424 0 0 1 "./samples/Bosendor/63 emp C1-.wav" 0 0 0
f1425 0 0 1 "./samples/Bosendor/63 emp D1-.wav" 0 0 0
f1426 0 0 1 "./samples/Bosendor/63 emp E1-.wav" 0 0 0
f1427 0 0 1 "./samples/Bosendor/63 emp F1-.wav" 0 0 0
f1428 0 0 1 "./samples/Bosendor/63 emp G1-.wav" 0 0 0
f1429 0 0 1 "./samples/Bosendor/63 emp A1.wav" 0 0 0
f1430 0 0 1 "./samples/Bosendor/63 emp B1-.wav" 0 0 0
f1431 0 0 1 "./samples/Bosendor/63 emp C2-.wav" 0 0 0
f1432 0 0 1 "./samples/Bosendor/63 emp D2-.wav" 0 0 0
f1433 0 0 1 "./samples/Bosendor/63 emp E2-.wav" 0 0 0
f1434 0 0 1 "./samples/Bosendor/63 emp F2-.wav" 0 0 0
f1435 0 0 1 "./samples/Bosendor/63 emp G2-.wav" 0 0 0
f1436 0 0 1 "./samples/Bosendor/63 emp A2-.wav" 0 0 0
f1437 0 0 1 "./samples/Bosendor/63 emp B2-.wav" 0 0 0
f1438 0 0 1 "./samples/Bosendor/63 emp C3-.wav" 0 0 0
f1439 0 0 1 "./samples/Bosendor/63 emp D3-.wav" 0 0 0
f1440 0 0 1 "./samples/Bosendor/63 emp E3-.wav" 0 0 0
f1441 0 0 1 "./samples/Bosendor/63 emp F3-.wav" 0 0 0
f1442 0 0 1 "./samples/Bosendor/63 emp G3-.wav" 0 0 0
f1443 0 0 1 "./samples/Bosendor/63 emp A3-.wav" 0 0 0
f1444 0 0 1 "./samples/Bosendor/63 emp B3-.wav" 0 0 0
f1445 0 0 1 "./samples/Bosendor/63 emp C4-.wav" 0 0 0
f1446 0 0 1 "./samples/Bosendor/63 emp D4-.wav" 0 0 0
f1447 0 0 1 "./samples/Bosendor/63 emp E4-.wav" 0 0 0
f1448 0 0 1 "./samples/Bosendor/63 emp F4-.wav" 0 0 0
f1449 0 0 1 "./samples/Bosendor/63 emp G4-.wav" 0 0 0
f1450 0 0 1 "./samples/Bosendor/63 emp A4-.wav" 0 0 0
f1451 0 0 1 "./samples/Bosendor/63 emp B4-.wav" 0 0 0
f1452 0 0 1 "./samples/Bosendor/63 emp C5-.wav" 0 0 0
f1453 0 0 1 "./samples/Bosendor/63 emp D5-.wav" 0 0 0
f1454 0 0 1 "./samples/Bosendor/63 emp E5-.wav" 0 0 0
f1455 0 0 1 "./samples/Bosendor/63 emp F5-.wav" 0 0 0
f1456 0 0 1 "./samples/Bosendor/63 emp G5-.wav" 0 0 0
f1457 0 0 1 "./samples/Bosendor/63 emp A5-.wav" 0 0 0
f1458 0 0 1 "./samples/Bosendor/63 emp B5-.wav" 0 0 0
f1459 0 0 1 "./samples/Bosendor/63 emp C6-.wav" 0 0 0
f1460 0 0 1 "./samples/Bosendor/63 emp D6-.wav" 0 0 0
f1461 0 0 1 "./samples/Bosendor/63 emp E6-.wav" 0 0 0
f1462 0 0 1 "./samples/Bosendor/63 emp F6-.wav" 0 0 0
f1463 0 0 1 "./samples/Bosendor/63 emp G6-.wav" 0 0 0
f1464 0 0 1 "./samples/Bosendor/63 emp A6-.wav" 0 0 0
f1465 0 0 1 "./samples/Bosendor/63 emp B6-.wav" 0 0 0
f1466 0 0 1 "./samples/Bosendor/63 emp C7-.wav" 0 0 0
f1467 0 0 1 "./samples/Bosendor/63 emp D7-.wav" 0 0 0
f1468 0 0 1 "./samples/Bosendor/63 emp E7-.wav" 0 0 0
f1469 0 0 1 "./samples/Bosendor/63 emp F7-.wav" 0 0 0
f1470 0 0 1 "./samples/Bosendor/63 emp G7-.wav" 0 0 0
f1471 0 0 1 "./samples/Bosendor/63 emp A7-.wav" 0 0 0
f1472 0 0 1 "./samples/Bosendor/63 emp B7-.wav" 0 0 0
f1473 0 0 1 "./samples/Bosendor/63 emp C8-.wav" 0 0 0
f1478 0 0 1 "./samples/Bosendor/78 emp B0-.wav" 0 0 0
f1479 0 0 1 "./samples/Bosendor/78 emp C1-.wav" 0 0 0
f1480 0 0 1 "./samples/Bosendor/78 emp D1-.wav" 0 0 0
f1481 0 0 1 "./samples/Bosendor/78 emp E1-.wav" 0 0 0
f1482 0 0 1 "./samples/Bosendor/78 emp F1-.wav" 0 0 0
f1483 0 0 1 "./samples/Bosendor/78 emp G1-.wav" 0 0 0
f1484 0 0 1 "./samples/Bosendor/78 emp A1.wav" 0 0 0
f1485 0 0 1 "./samples/Bosendor/78 emp B1-.wav" 0 0 0
f1486 0 0 1 "./samples/Bosendor/78 emp C2-.wav" 0 0 0
f1487 0 0 1 "./samples/Bosendor/78 emp D2-.wav" 0 0 0
f1488 0 0 1 "./samples/Bosendor/78 emp E2-.wav" 0 0 0
f1489 0 0 1 "./samples/Bosendor/78 emp F2-.wav" 0 0 0
f1490 0 0 1 "./samples/Bosendor/78 emp G2-.wav" 0 0 0
f1491 0 0 1 "./samples/Bosendor/78 emp A2-.wav" 0 0 0
f1492 0 0 1 "./samples/Bosendor/78 emp B2-.wav" 0 0 0
f1493 0 0 1 "./samples/Bosendor/78 emp C3-.wav" 0 0 0
f1494 0 0 1 "./samples/Bosendor/78 emp D3-.wav" 0 0 0
f1495 0 0 1 "./samples/Bosendor/78 emp E3-.wav" 0 0 0
f1496 0 0 1 "./samples/Bosendor/78 emp F3-.wav" 0 0 0
f1497 0 0 1 "./samples/Bosendor/78 emp G3-.wav" 0 0 0
f1498 0 0 1 "./samples/Bosendor/78 emp A3-.wav" 0 0 0
f1499 0 0 1 "./samples/Bosendor/78 emp B3-.wav" 0 0 0
f1500 0 0 1 "./samples/Bosendor/78 emp C4-.wav" 0 0 0
f1501 0 0 1 "./samples/Bosendor/78 emp D4-.wav" 0 0 0
f1502 0 0 1 "./samples/Bosendor/78 emp E4-.wav" 0 0 0
f1503 0 0 1 "./samples/Bosendor/78 emp F4-.wav" 0 0 0
f1504 0 0 1 "./samples/Bosendor/78 emp G4-.wav" 0 0 0
f1505 0 0 1 "./samples/Bosendor/78 emp A4-.wav" 0 0 0
f1506 0 0 1 "./samples/Bosendor/78 emp B4-.wav" 0 0 0
f1507 0 0 1 "./samples/Bosendor/78 emp C5-.wav" 0 0 0
f1508 0 0 1 "./samples/Bosendor/78 emp D5-.wav" 0 0 0
f1509 0 0 1 "./samples/Bosendor/78 emp E5-.wav" 0 0 0
f1510 0 0 1 "./samples/Bosendor/78 emp F5-.wav" 0 0 0
f1511 0 0 1 "./samples/Bosendor/78 emp G5-.wav" 0 0 0
f1512 0 0 1 "./samples/Bosendor/78 emp A5-.wav" 0 0 0
f1513 0 0 1 "./samples/Bosendor/78 emp B5-.wav" 0 0 0
f1514 0 0 1 "./samples/Bosendor/78 emp C6-.wav" 0 0 0
f1515 0 0 1 "./samples/Bosendor/78 emp D6-.wav" 0 0 0
f1516 0 0 1 "./samples/Bosendor/78 emp E6-.wav" 0 0 0
f1517 0 0 1 "./samples/Bosendor/78 emp F6-.wav" 0 0 0
f1518 0 0 1 "./samples/Bosendor/78 emp G6-.wav" 0 0 0
f1519 0 0 1 "./samples/Bosendor/78 emp A6-.wav" 0 0 0
f1520 0 0 1 "./samples/Bosendor/78 emp B6-.wav" 0 0 0
f1521 0 0 1 "./samples/Bosendor/78 emp C7-.wav" 0 0 0
f1522 0 0 1 "./samples/Bosendor/78 emp D7-.wav" 0 0 0
f1523 0 0 1 "./samples/Bosendor/78 emp E7-.wav" 0 0 0
f1524 0 0 1 "./samples/Bosendor/78 emp F7-.wav" 0 0 0
f1525 0 0 1 "./samples/Bosendor/78 emp G7-.wav" 0 0 0
f1526 0 0 1 "./samples/Bosendor/78 emp A7-.wav" 0 0 0
f1527 0 0 1 "./samples/Bosendor/78 emp B7-.wav" 0 0 0
f1528 0 0 1 "./samples/Bosendor/78 emp C8-.wav" 0 0 0
f1533 0 0 1 "./samples/Bosendor/85 emp A0.wav" 0 0 0
f1534 0 0 1 "./samples/Bosendor/85 emp B0-.wav" 0 0 0
f1535 0 0 1 "./samples/Bosendor/85 emp C1-.wav" 0 0 0
f1536 0 0 1 "./samples/Bosendor/85 emp D1-.wav" 0 0 0
f1537 0 0 1 "./samples/Bosendor/85 emp E1-.wav" 0 0 0
f1538 0 0 1 "./samples/Bosendor/85 emp F1-.wav" 0 0 0
f1539 0 0 1 "./samples/Bosendor/85 emp G1-.wav" 0 0 0
f1540 0 0 1 "./samples/Bosendor/85 emp A1.wav" 0 0 0
f1541 0 0 1 "./samples/Bosendor/85 emp B1-.wav" 0 0 0
f1542 0 0 1 "./samples/Bosendor/85 emp C2-.wav" 0 0 0
f1543 0 0 1 "./samples/Bosendor/85 emp D2-.wav" 0 0 0
f1544 0 0 1 "./samples/Bosendor/85 emp E2-.wav" 0 0 0
f1545 0 0 1 "./samples/Bosendor/85 emp F2-.wav" 0 0 0
f1546 0 0 1 "./samples/Bosendor/85 emp G2-.wav" 0 0 0
f1547 0 0 1 "./samples/Bosendor/85 emp A2-.wav" 0 0 0
f1548 0 0 1 "./samples/Bosendor/85 emp B2-.wav" 0 0 0
f1549 0 0 1 "./samples/Bosendor/85 emp C3-.wav" 0 0 0
f1550 0 0 1 "./samples/Bosendor/85 emp D3-.wav" 0 0 0
f1551 0 0 1 "./samples/Bosendor/85 emp E3-.wav" 0 0 0
f1552 0 0 1 "./samples/Bosendor/85 emp F3-.wav" 0 0 0
f1553 0 0 1 "./samples/Bosendor/85 emp G3-.wav" 0 0 0
f1554 0 0 1 "./samples/Bosendor/85 emp A3-.wav" 0 0 0
f1555 0 0 1 "./samples/Bosendor/85 emp B3-.wav" 0 0 0
f1556 0 0 1 "./samples/Bosendor/85 emp C4-.wav" 0 0 0
f1557 0 0 1 "./samples/Bosendor/85 emp D4-.wav" 0 0 0
f1558 0 0 1 "./samples/Bosendor/85 emp E4-.wav" 0 0 0
f1559 0 0 1 "./samples/Bosendor/85 emp F4-.wav" 0 0 0
f1560 0 0 1 "./samples/Bosendor/85 emp G4-.wav" 0 0 0
f1561 0 0 1 "./samples/Bosendor/85 emp A4-.wav" 0 0 0
f1562 0 0 1 "./samples/Bosendor/85 emp B4-.wav" 0 0 0
f1563 0 0 1 "./samples/Bosendor/85 emp C5-.wav" 0 0 0
f1564 0 0 1 "./samples/Bosendor/85 emp D5-.wav" 0 0 0
f1565 0 0 1 "./samples/Bosendor/85 emp E5-.wav" 0 0 0
f1566 0 0 1 "./samples/Bosendor/85 emp F5-.wav" 0 0 0
f1567 0 0 1 "./samples/Bosendor/85 emp G5-.wav" 0 0 0
f1568 0 0 1 "./samples/Bosendor/85 emp A5-.wav" 0 0 0
f1569 0 0 1 "./samples/Bosendor/85 emp B5-.wav" 0 0 0
f1570 0 0 1 "./samples/Bosendor/85 emp C6-.wav" 0 0 0
f1571 0 0 1 "./samples/Bosendor/85 emp D6-.wav" 0 0 0
f1572 0 0 1 "./samples/Bosendor/85 emp E6-.wav" 0 0 0
f1573 0 0 1 "./samples/Bosendor/85 emp F6-.wav" 0 0 0
f1574 0 0 1 "./samples/Bosendor/85 emp G6-.wav" 0 0 0
f1575 0 0 1 "./samples/Bosendor/85 emp A6-.wav" 0 0 0
f1576 0 0 1 "./samples/Bosendor/85 emp B6-.wav" 0 0 0
f1577 0 0 1 "./samples/Bosendor/85 emp C7-.wav" 0 0 0
f1578 0 0 1 "./samples/Bosendor/85 emp D7-.wav" 0 0 0
f1579 0 0 1 "./samples/Bosendor/85 emp E7-.wav" 0 0 0
f1580 0 0 1 "./samples/Bosendor/85 emp F7-.wav" 0 0 0
f1581 0 0 1 "./samples/Bosendor/85 emp G7-.wav" 0 0 0
f1582 0 0 1 "./samples/Bosendor/85 emp A7-.wav" 0 0 0
f1583 0 0 1 "./samples/Bosendor/85 emp B7-.wav" 0 0 0
f1584 0 0 1 "./samples/Bosendor/85 emp C8-.wav" 0 0 0
f1589 0 0 1 "./samples/Bosendor/99 emp A0.wav" 0 0 0
f1590 0 0 1 "./samples/Bosendor/99 emp B0-.wav" 0 0 0
f1591 0 0 1 "./samples/Bosendor/99 emp C1-.wav" 0 0 0
f1592 0 0 1 "./samples/Bosendor/99 emp D1-.wav" 0 0 0
f1593 0 0 1 "./samples/Bosendor/99 emp E1-.wav" 0 0 0
f1594 0 0 1 "./samples/Bosendor/99 emp F1-.wav" 0 0 0
f1595 0 0 1 "./samples/Bosendor/99 emp G1-.wav" 0 0 0
f1596 0 0 1 "./samples/Bosendor/99 emp A1.wav" 0 0 0
f1597 0 0 1 "./samples/Bosendor/99 emp B1-.wav" 0 0 0
f1598 0 0 1 "./samples/Bosendor/99 emp C2-.wav" 0 0 0
f1599 0 0 1 "./samples/Bosendor/99 emp D2-.wav" 0 0 0
f1600 0 0 1 "./samples/Bosendor/99 emp E2-.wav" 0 0 0
f1601 0 0 1 "./samples/Bosendor/99 emp F2-.wav" 0 0 0
f1602 0 0 1 "./samples/Bosendor/99 emp G2-.wav" 0 0 0
f1603 0 0 1 "./samples/Bosendor/99 emp A2-.wav" 0 0 0
f1604 0 0 1 "./samples/Bosendor/99 emp B2-.wav" 0 0 0
f1605 0 0 1 "./samples/Bosendor/99 emp C3-.wav" 0 0 0
f1606 0 0 1 "./samples/Bosendor/99 emp D3-.wav" 0 0 0
f1607 0 0 1 "./samples/Bosendor/99 emp E3-.wav" 0 0 0
f1608 0 0 1 "./samples/Bosendor/99 emp F3-.wav" 0 0 0
f1609 0 0 1 "./samples/Bosendor/99 emp G3-.wav" 0 0 0
f1610 0 0 1 "./samples/Bosendor/99 emp A3-.wav" 0 0 0
f1611 0 0 1 "./samples/Bosendor/99 emp B3-.wav" 0 0 0
f1612 0 0 1 "./samples/Bosendor/99 emp C4-.wav" 0 0 0
f1613 0 0 1 "./samples/Bosendor/99 emp D4-.wav" 0 0 0
f1614 0 0 1 "./samples/Bosendor/99 emp E4-.wav" 0 0 0
f1615 0 0 1 "./samples/Bosendor/99 emp F4-.wav" 0 0 0
f1616 0 0 1 "./samples/Bosendor/99 emp G4-.wav" 0 0 0
f1617 0 0 1 "./samples/Bosendor/99 emp A4-.wav" 0 0 0
f1618 0 0 1 "./samples/Bosendor/99 emp B4-.wav" 0 0 0
f1619 0 0 1 "./samples/Bosendor/99 emp C5-.wav" 0 0 0
f1620 0 0 1 "./samples/Bosendor/99 emp D5-.wav" 0 0 0
f1621 0 0 1 "./samples/Bosendor/99 emp E5-.wav" 0 0 0
f1622 0 0 1 "./samples/Bosendor/99 emp F5-.wav" 0 0 0
f1623 0 0 1 "./samples/Bosendor/99 emp G5-.wav" 0 0 0
f1624 0 0 1 "./samples/Bosendor/99 emp A5-.wav" 0 0 0
f1625 0 0 1 "./samples/Bosendor/99 emp B5-.wav" 0 0 0
f1626 0 0 1 "./samples/Bosendor/99 emp C6-.wav" 0 0 0
f1627 0 0 1 "./samples/Bosendor/99 emp D6-.wav" 0 0 0
f1628 0 0 1 "./samples/Bosendor/99 emp E6-.wav" 0 0 0
f1629 0 0 1 "./samples/Bosendor/99 emp F6-.wav" 0 0 0
f1630 0 0 1 "./samples/Bosendor/99 emp G6-.wav" 0 0 0
f1631 0 0 1 "./samples/Bosendor/99 emp A6-.wav" 0 0 0
f1632 0 0 1 "./samples/Bosendor/99 emp B6-.wav" 0 0 0
f1633 0 0 1 "./samples/Bosendor/99 emp C7-.wav" 0 0 0
f1634 0 0 1 "./samples/Bosendor/99 emp D7-.wav" 0 0 0
f1635 0 0 1 "./samples/Bosendor/99 emp E7-.wav" 0 0 0
f1636 0 0 1 "./samples/Bosendor/99 emp F7-.wav" 0 0 0
f1637 0 0 1 "./samples/Bosendor/99 emp G7-.wav" 0 0 0
f1638 0 0 1 "./samples/Bosendor/99 emp A7-.wav" 0 0 0
f1639 0 0 1 "./samples/Bosendor/99 emp B7-.wav" 0 0 0
f1640 0 0 1 "./samples/Bosendor/99 emp C8-.wav" 0 0 0
f1645 0 0 1 "./samples/Bosendor/113 emp A0.wav" 0 0 0
f1646 0 0 1 "./samples/Bosendor/113 emp B0-.wav" 0 0 0
f1647 0 0 1 "./samples/Bosendor/113 emp C1-.wav" 0 0 0
f1648 0 0 1 "./samples/Bosendor/113 emp D1-.wav" 0 0 0
f1649 0 0 1 "./samples/Bosendor/113 emp E1-.wav" 0 0 0
f1650 0 0 1 "./samples/Bosendor/113 emp F1-.wav" 0 0 0
f1651 0 0 1 "./samples/Bosendor/113 emp G1-.wav" 0 0 0
f1652 0 0 1 "./samples/Bosendor/113 emp A1.wav" 0 0 0
f1653 0 0 1 "./samples/Bosendor/113 emp B1-.wav" 0 0 0
f1654 0 0 1 "./samples/Bosendor/113 emp C2-.wav" 0 0 0
f1655 0 0 1 "./samples/Bosendor/113 emp D2-.wav" 0 0 0
f1656 0 0 1 "./samples/Bosendor/113 emp E2-.wav" 0 0 0
f1657 0 0 1 "./samples/Bosendor/113 emp F2-.wav" 0 0 0
f1658 0 0 1 "./samples/Bosendor/113 emp A2-.wav" 0 0 0
f1659 0 0 1 "./samples/Bosendor/113 emp B2-.wav" 0 0 0
f1660 0 0 1 "./samples/Bosendor/113 emp C3-.wav" 0 0 0
f1661 0 0 1 "./samples/Bosendor/113 emp D3-.wav" 0 0 0
f1662 0 0 1 "./samples/Bosendor/113 emp E3-.wav" 0 0 0
f1663 0 0 1 "./samples/Bosendor/113 emp F3-.wav" 0 0 0
f1664 0 0 1 "./samples/Bosendor/113 emp G3-.wav" 0 0 0
f1665 0 0 1 "./samples/Bosendor/113 emp A3-.wav" 0 0 0
f1666 0 0 1 "./samples/Bosendor/113 emp B3-.wav" 0 0 0
f1667 0 0 1 "./samples/Bosendor/113 emp C4-.wav" 0 0 0
f1668 0 0 1 "./samples/Bosendor/113 emp D4-.wav" 0 0 0
f1669 0 0 1 "./samples/Bosendor/113 emp E4-.wav" 0 0 0
f1670 0 0 1 "./samples/Bosendor/113 emp F4-.wav" 0 0 0
f1671 0 0 1 "./samples/Bosendor/113 emp G4-.wav" 0 0 0
f1672 0 0 1 "./samples/Bosendor/113 emp A4-.wav" 0 0 0
f1673 0 0 1 "./samples/Bosendor/113 emp B4-.wav" 0 0 0
f1674 0 0 1 "./samples/Bosendor/113 emp C5-.wav" 0 0 0
f1675 0 0 1 "./samples/Bosendor/113 emp D5-.wav" 0 0 0
f1676 0 0 1 "./samples/Bosendor/113 emp E5-.wav" 0 0 0
f1677 0 0 1 "./samples/Bosendor/113 emp F5-.wav" 0 0 0
f1678 0 0 1 "./samples/Bosendor/113 emp G5-.wav" 0 0 0
f1679 0 0 1 "./samples/Bosendor/113 emp A5-.wav" 0 0 0
f1680 0 0 1 "./samples/Bosendor/113 emp B5-.wav" 0 0 0
f1681 0 0 1 "./samples/Bosendor/113 emp C6-.wav" 0 0 0
f1682 0 0 1 "./samples/Bosendor/113 emp D6-.wav" 0 0 0
f1683 0 0 1 "./samples/Bosendor/113 emp E6-.wav" 0 0 0
f1684 0 0 1 "./samples/Bosendor/113 emp F6-.wav" 0 0 0
f1685 0 0 1 "./samples/Bosendor/113 emp G6-.wav" 0 0 0
f1686 0 0 1 "./samples/Bosendor/113 emp A6-.wav" 0 0 0
f1687 0 0 1 "./samples/Bosendor/113 emp B6-.wav" 0 0 0
f1688 0 0 1 "./samples/Bosendor/113 emp C7-.wav" 0 0 0
f1689 0 0 1 "./samples/Bosendor/113 emp D7-.wav" 0 0 0
f1690 0 0 1 "./samples/Bosendor/113 emp E7-.wav" 0 0 0
f1691 0 0 1 "./samples/Bosendor/113 emp F7-.wav" 0 0 0
f1692 0 0 1 "./samples/Bosendor/113 emp G7-.wav" 0 0 0
f1693 0 0 1 "./samples/Bosendor/113 emp A7-.wav" 0 0 0
f1694 0 0 1 "./samples/Bosendor/113 emp B7-.wav" 0 0 0
f1695 0 0 1 "./samples/Bosendor/113 emp C8-.wav" 0 0 0
f1700 0 0 1 "./samples/Bosendor/127 emp A0.wav" 0 0 0
f1701 0 0 1 "./samples/Bosendor/127 emp B0-.wav" 0 0 0
f1702 0 0 1 "./samples/Bosendor/127 emp C1-.wav" 0 0 0
f1703 0 0 1 "./samples/Bosendor/127 emp D1-.wav" 0 0 0
f1704 0 0 1 "./samples/Bosendor/127 emp E1-.wav" 0 0 0
f1705 0 0 1 "./samples/Bosendor/127 emp F1-.wav" 0 0 0
f1706 0 0 1 "./samples/Bosendor/127 emp G1-.wav" 0 0 0
f1707 0 0 1 "./samples/Bosendor/127 emp A1.wav" 0 0 0
f1708 0 0 1 "./samples/Bosendor/127 emp B1-.wav" 0 0 0
f1709 0 0 1 "./samples/Bosendor/127 emp C2-.wav" 0 0 0
f1710 0 0 1 "./samples/Bosendor/127 emp D2-.wav" 0 0 0
f1711 0 0 1 "./samples/Bosendor/127 emp E2-.wav" 0 0 0
f1712 0 0 1 "./samples/Bosendor/127 emp F2-.wav" 0 0 0
f1713 0 0 1 "./samples/Bosendor/127 emp G2-.wav" 0 0 0
f1714 0 0 1 "./samples/Bosendor/127 emp A2-.wav" 0 0 0
f1715 0 0 1 "./samples/Bosendor/127 emp B2-.wav" 0 0 0
f1716 0 0 1 "./samples/Bosendor/127 emp D3-.wav" 0 0 0
f1717 0 0 1 "./samples/Bosendor/127 emp E3-.wav" 0 0 0
f1718 0 0 1 "./samples/Bosendor/127 emp F3-.wav" 0 0 0
f1719 0 0 1 "./samples/Bosendor/127 emp G3-.wav" 0 0 0
f1720 0 0 1 "./samples/Bosendor/127 emp A3-.wav" 0 0 0
f1721 0 0 1 "./samples/Bosendor/127 emp B3-.wav" 0 0 0
f1722 0 0 1 "./samples/Bosendor/127 emp C4-.wav" 0 0 0
f1723 0 0 1 "./samples/Bosendor/127 emp D4-.wav" 0 0 0
f1724 0 0 1 "./samples/Bosendor/127 emp E4-.wav" 0 0 0
f1725 0 0 1 "./samples/Bosendor/127 emp F4-.wav" 0 0 0
f1726 0 0 1 "./samples/Bosendor/127 emp G4-.wav" 0 0 0
f1727 0 0 1 "./samples/Bosendor/127 emp A4-.wav" 0 0 0
f1728 0 0 1 "./samples/Bosendor/127 emp B4-.wav" 0 0 0
f1729 0 0 1 "./samples/Bosendor/127 emp C5-.wav" 0 0 0
f1730 0 0 1 "./samples/Bosendor/127 emp D5-.wav" 0 0 0
f1731 0 0 1 "./samples/Bosendor/127 emp E5-.wav" 0 0 0
f1732 0 0 1 "./samples/Bosendor/127 emp F5-.wav" 0 0 0
f1733 0 0 1 "./samples/Bosendor/127 emp G5-.wav" 0 0 0
f1734 0 0 1 "./samples/Bosendor/127 emp A5-.wav" 0 0 0
f1735 0 0 1 "./samples/Bosendor/127 emp B5-.wav" 0 0 0
f1736 0 0 1 "./samples/Bosendor/127 emp C6-.wav" 0 0 0
f1737 0 0 1 "./samples/Bosendor/127 emp D6-.wav" 0 0 0
f1738 0 0 1 "./samples/Bosendor/127 emp E6-.wav" 0 0 0
f1739 0 0 1 "./samples/Bosendor/127 emp F6-.wav" 0 0 0
f1740 0 0 1 "./samples/Bosendor/127 emp G6-.wav" 0 0 0
f1741 0 0 1 "./samples/Bosendor/127 emp A6-.wav" 0 0 0
f1742 0 0 1 "./samples/Bosendor/127 emp B6-.wav" 0 0 0
f1743 0 0 1 "./samples/Bosendor/127 emp C7-.wav" 0 0 0
f1744 0 0 1 "./samples/Bosendor/127 emp D7-.wav" 0 0 0
f1745 0 0 1 "./samples/Bosendor/127 emp E7-.wav" 0 0 0
f1746 0 0 1 "./samples/Bosendor/127 emp F7-.wav" 0 0 0
f1747 0 0 1 "./samples/Bosendor/127 emp G7-.wav" 0 0 0
f1748 0 0 1 "./samples/Bosendor/127 emp A7-.wav" 0 0 0
f1749 0 0 1 "./samples/Bosendor/127 emp B7-.wav" 0 0 0
f1750 0 0 1 "./samples/Bosendor/127 emp C8-.wav" 0 0 0
;              1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20   21   22   23   24   25   26   27   28   29   30   31   32   33   34   35   36   37   38 
f1 0 64 -2 0 601 630 652 667 683 705 726 742 766 787 807 830 850 872 890 909 930 953 975 999 1030 1070 1104 1130 1156 1177 1192 1212 1217 1262 1317 1363 1418 1474 1529 1585 1641 1696 
f2 0 64 -2 0 1 2 2 2 2 2 2 1 2 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 2 2 2 1 5 5 5 5 5 5 5 5 5 5
;Inst Start        Dur  Vel    Ton   Oct   Voice Stere Envlp Gliss Upsamp R-Env 2nd-gl 3rd Mult Line # ; Channel
;p1   p2           p3   p4     p5    p6    p7    p8    p9    p10   p11    p12   p13   p14  p15; Channel

f5000.0 0.0 256.0 -6.0 1.0 128.0 0.9925470000000001 128.0 0.985094 
f5001.0 0.0 256.0 -6.0 1.0 128.0 1.0066869999999999 128.0 1.013374 
f5002.0 0.0 256.0 -6.0 1.0 128.0 1.0063944999999999 128.0 1.012789 
f5003.0 0.0 256.0 -6.0 1.0 128.0 0.997695 128.0 0.99539 
;Inst	Sta	Hold	Vel	Ton	Oct	Voi	Ste	En1	Gls	Ups	Ren	2gl	3gl	Vol
i 1	0.0004013605442176882	0.7575000000000001	74	200	7	1	3	8	0	-2	8	0	0	2.0	
i 1	0.002006802721088434	0.7575000000000001	71	698	5	9	13	8	0	-1	8	0	0	2.0	
i 1	0.002006802721088434	20.4525	63	1084	6	7	10	1	0	1	1	0	0	1.5001661053861919	
i 1	0.004414965986394556	0.7575000000000001	71	698	6	1	8	2	0	-1	2	0	0	2.0	
i 1	0.007625850340136055	14.645	63	698	4	18	9	16	0	1	16	0	0	6.937531292532962	
i 1	0.007625850340136055	0.2525	72	698	3	5	7	2	0	-2	2	0	0	2.0	
i 1	0.008428571428571428	1.01	63	1084	5	17	11	16	0	1	16	0	0	6.937531292532962	
i 1	0.010034013605442177	0.2525	72	200	4	5	7	8	0	-2	8	0	0	2.0	
i 1	0.011639455782312923	6.8175	63	200	7	17	2	1	0	1	1	0	0	6.937531292532962	
i 1	0.012442176870748299	0.2525	74	698	2	24	16	2	0	1	2	0	0	4.0	
i 1	0.013244897959183675	0.7575000000000001	74	200	5	2	5	8	0	-2	8	0	0	3.0	
i 1	0.014047619047619045	6.8175	63	200	6	14	10	1	0	1	1	0	0	2.250249158079288	
i 1	0.014850340136054421	6.8175	61	200	4	14	16	16	0	2	16	0	0	2.250249158079288	
i 1	0.015653061224489798	7.8275	61	1084	5	17	10	1	0	2	1	0	0	6.937531292532962	
i 1	0.018061224489795916	21.4625	63	698	4	18	6	1	0	2	1	0	0	6.937531292532962	
i 1	0.23916326530612245	1.5150000000000001	75	1084	3	5	14	8	0	-2	8	0	0	2.0	
i 1	0.26725850340136054	1.5150000000000001	75	698	3	5	3	2	0	-2	2	0	0	2.0	
i 1	0.26725850340136054	0.505	74	698	2	24	2	2	0	-2	2	0	0	4.0	
i 1	0.7303333333333333	0.2525	74	1084	4	4	16	8	0	-2	8	0	0	3.0	
i 1	0.7375578231292517	1.01	74	1084	4	24	13	2	0	-1	2	0	0	3.0	
i 1	0.74478231292517	1.2625	74	698	2	24	12	2	0	1	2	0	0	4.0	
i 1	0.7592312925170068	1.01	74	698	4	24	3	2	0	-2	2	0	0	3.0	
i 1	0.7640476190476191	0.2525	71	698	4	4	5	8	0	-2	8	0	0	3.0	
i 1	0.9931768707482993	12.625	63	1084	6	17	5	16	0	1	16	0	0	6.937531292532962	
i 1	0.99478231292517	0.505	74	698	5	9	1	8	0	-2	8	0	0	2.0	
i 1	1.0020068027210884	27.27	63	698	4	19	3	1	0	1	1	0	0	6.937531292532962	
i 1	1.0196666666666667	0.505	71	200	5	2	16	8	0	-1	8	0	0	3.0	
i 1	1.4803333333333333	1.01	71	1084	4	3	11	2	0	-1	2	0	0	3.0	
i 1	1.492374149659864	1.01	71	698	5	3	3	8	0	-1	8	0	0	3.0	
i 1	1.731938775510204	1.2625	71	200	6	1	5	8	0	-1	8	0	0	2.0	
i 1	1.7391632653061224	1.2625	74	698	6	1	4	2	0	-2	2	0	0	2.0	
i 1	1.7431768707482993	1.2625	75	200	7	5	9	8	0	-2	8	0	0	2.0	
i 1	1.748795918367347	1.2625	72	698	3	5	16	2	0	1	2	0	0	2.0	
i 1	1.9915714285714285	0.505	71	698	2	24	10	2	0	-2	2	0	0	4.0	
i 1	2.0148503401360545	0.505	74	698	2	24	3	2	0	-2	2	0	0	4.0	
i 1	2.509231292517007	1.01	74	200	5	2	13	8	0	-2	8	0	0	3.0	
i 1	2.509231292517007	1.01	71	698	5	9	2	8	0	-1	8	0	0	2.0	
i 1	2.511639455782313	0.505	74	698	2	24	8	2	0	1	2	0	0	4.0	
i 1	2.9875578231292517	0.2525	72	698	3	5	15	8	0	1	8	0	0	2.0	
i 1	2.9891632653061224	0.2525	72	1084	3	5	4	8	0	-2	8	0	0	2.0	
i 1	2.989965986394558	0.2525	74	698	2	24	7	2	0	-2	2	0	0	4.0	
i 1	2.9931768707482993	1.5150000000000001	71	698	6	1	16	2	0	-2	2	0	0	2.0	
i 1	3.011639455782313	1.5150000000000001	74	1084	6	1	7	2	0	-2	2	0	0	2.0	
i 1	3.260034013605442	0.2525	71	1084	2	24	6	8	0	-2	8	0	0	4.0	
i 1	3.2648503401360545	1.5150000000000001	72	698	3	5	12	2	0	-2	2	0	0	2.0	
i 1	3.268061224489796	0.2525	74	698	2	24	13	2	0	1	2	0	0	4.0	
i 1	3.2688639455782313	1.5150000000000001	72	200	4	5	7	8	0	-2	8	0	0	2.0	
i 1	3.4995986394557823	0.7575000000000001	74	1084	4	4	3	8	0	-2	8	0	0	3.0	
i 1	3.4995986394557823	0.7575000000000001	71	698	4	4	2	8	0	-2	8	0	0	3.0	
i 1	3.7479931972789116	0.2525	74	1084	2	24	11	2	0	-2	2	0	0	4.0	
i 1	3.76565306122449	0.2525	74	698	2	24	5	2	0	1	2	0	0	4.0	
i 1	3.9931768707482993	0.505	71	698	2	24	8	2	0	1	2	0	0	4.0	
i 1	4.006823129251701	0.505	74	698	2	24	10	2	0	-2	2	0	0	4.0	
i 1	4.251204081632653	0.7575000000000001	71	200	5	2	4	8	0	-1	8	0	0	3.0	
i 1	4.256823129251701	0.7575000000000001	74	698	5	9	15	8	0	-2	8	0	0	2.0	
i 1	4.485952380952381	1.2625	71	698	6	1	8	2	0	-1	2	0	0	2.0	
i 1	4.493176870748299	1.2625	74	200	7	1	14	8	0	-2	8	0	0	2.0	
i 1	4.510836734693878	0.505	74	1084	2	24	9	2	0	1	2	0	0	4.0	
i 1	4.512442176870748	0.505	74	698	2	24	15	2	0	1	2	0	0	4.0	
i 1	4.748795918367347	1.01	75	698	3	5	12	2	0	-2	2	0	0	2.0	
i 1	4.754414965986395	1.01	75	1084	3	5	10	8	0	-2	8	0	0	2.0	
i 1	4.989163265306122	0.2525	71	698	5	3	6	8	0	-1	8	0	0	3.0	
i 1	4.9915714285714285	0.2525	74	698	2	24	8	2	0	1	2	0	0	4.0	
i 1	5.001204081632653	0.2525	71	1084	4	3	15	2	0	-1	2	0	0	3.0	
i 1	5.250401360544218	0.505	74	200	5	2	2	8	0	-2	8	0	0	3.0	
i 1	5.25521768707483	0.505	74	698	2	24	6	2	0	1	2	0	0	4.0	
i 1	5.262442176870748	0.505	71	698	5	9	5	8	0	-1	8	0	0	2.0	
i 1	5.26565306122449	0.505	71	1084	2	24	4	2	0	1	2	0	0	4.0	
i 1	5.743176870748299	1.01	71	698	4	4	1	8	0	-2	8	0	0	3.0	
i 1	5.74478231292517	0.505	74	1084	4	24	12	2	0	-1	2	0	0	3.0	
i 1	5.746387755102041	0.2525	72	698	3	5	12	2	0	1	2	0	0	2.0	
i 1	5.750401360544218	1.01	74	1084	4	4	16	8	0	-2	8	0	0	3.0	
i 1	5.750401360544218	0.2525	75	200	7	5	1	8	0	-2	8	0	0	2.0	
i 1	5.752006802721088	0.505	74	698	4	24	10	2	0	-2	2	0	0	3.0	
i 1	5.753612244897959	1.01	74	698	2	24	12	2	0	1	2	0	0	4.0	
i 1	5.762442176870748	1.01	74	698	2	24	2	2	0	-2	2	0	0	4.0	
i 1	5.995585034013605	1.5150000000000001	72	1084	3	5	5	8	0	-2	8	0	0	2.0	
i 1	6.010034013605442	1.5150000000000001	72	698	3	5	13	8	0	1	8	0	0	2.0	
i 1	6.242374149659864	0.7575000000000001	74	698	6	1	11	2	0	-2	2	0	0	2.0	
i 1	6.243979591836735	0.505	71	200	6	1	2	8	0	-1	8	0	0	2.0	
i 1	6.731136054421769	1.01	74	698	5	9	13	8	0	-2	8	0	0	2.0	
i 1	6.739163265306122	1.01	71	200	5	2	10	8	0	-1	8	0	0	3.0	
i 1	6.748795918367347	0.2525	74	698	2	24	8	2	0	1	2	0	0	5.0	
i 1	6.756020408163265	1.01	74	698	2	20	1	2	0	-2	2	0	0	1.0	
i 1	6.759231292517007	1.2625	74	698	2	24	10	2	0	-2	2	0	0	5.0	
i 1	6.762442176870748	37.6225	61	200	5	14	9	16	0	2	16	0	0	2.250249158079288	
i 1	6.7648503401360545	6.8175	63	200	4	14	14	1	0	1	1	0	0	2.250249158079288	
i 1	6.767258503401361	0.2525	74	698	2	20	14	2	0	-2	2	0	0	1.0	
i 1	6.768061224489796	0.2525	71	200	7	1	8	8	0	-1	8	0	0	2.0	
i 1	6.982741496598639	0.7575000000000001	74	698	1	20	11	2	0	-2	2	0	0	1.0	
i 1	7.003612244897959	0.7575000000000001	71	698	2	20	11	8	0	-2	8	0	0	1.0	
i 1	7.00521768707483	1.01	74	1084	6	1	7	2	0	-2	2	0	0	2.0	
i 1	7.01565306122449	1.01	71	698	6	1	14	2	0	-2	2	0	0	2.0	
i 1	7.487557823129252	1.2625	72	200	7	5	1	8	0	-2	8	0	0	2.0	
i 1	7.510034013605442	1.2625	72	698	3	5	11	2	0	-2	2	0	0	2.0	
i 1	7.7351496598639455	0.2525	74	200	2	20	13	2	0	-2	2	0	0	1.0	
i 1	7.740768707482993	0.2525	71	1084	2	20	15	2	0	1	2	0	0	1.0	
i 1	7.746387755102041	0.7575000000000001	71	698	5	3	4	8	0	-1	8	0	0	3.0	
i 1	7.748795918367347	0.7575000000000001	71	1084	4	3	9	2	0	-1	2	0	0	3.0	
i 1	7.760034013605442	27.27	63	698	4	19	2	1	0	1	1	0	0	6.937531292532962	
i 1	7.762442176870748	12.625	61	1084	6	17	9	1	0	2	1	0	0	6.937531292532962	
i 1	7.76565306122449	0.2525	74	698	2	20	4	2	0	-2	2	0	0	1.0	
i 1	7.992374149659864	0.505	71	698	2	20	10	8	0	-2	8	0	0	1.0	
i 1	7.99478231292517	1.2625	71	698	6	1	5	2	0	-1	2	0	0	2.0	
i 1	7.997190476190476	0.505	74	698	1	20	13	2	0	-2	2	0	0	1.0	
i 1	7.997993197278912	1.2625	74	200	6	1	2	8	0	-2	8	0	0	2.0	
i 1	8.484346938775511	1.2625	74	698	2	24	2	2	0	-2	2	0	0	5.0	
i 1	8.485149659863946	0.7575000000000001	74	200	5	2	6	8	0	-2	8	0	0	3.0	
i 1	8.490768707482994	0.505	74	200	2	20	3	2	0	-2	2	0	0	1.0	
i 1	8.511639455782312	0.7575000000000001	71	698	5	9	12	8	0	-1	8	0	0	2.0	
i 1	8.748795918367348	0.2525	75	1084	3	5	14	8	0	-2	8	0	0	2.0	
i 1	8.761639455782312	0.2525	75	698	3	5	5	2	0	-2	2	0	0	2.0	
i 1	8.981938775510205	1.5150000000000001	72	698	3	5	14	2	0	1	2	0	0	2.0	
i 1	8.98274149659864	1.5150000000000001	75	200	6	5	2	8	0	-2	8	0	0	2.0	
i 1	8.985149659863946	0.2525	74	698	2	20	1	2	0	-2	2	0	0	1.0	
i 1	8.999598639455783	0.2525	71	698	2	20	8	8	0	-2	8	0	0	1.0	
i 1	9.014850340136054	0.2525	74	698	1	20	16	2	0	1	2	0	0	1.0	
i 1	9.234346938775511	1.5150000000000001	74	1084	4	24	7	2	0	-1	2	0	0	3.0	
i 1	9.234346938775511	0.505	74	698	2	20	11	2	0	-2	2	0	0	1.0	
i 1	9.239163265306123	0.505	74	1084	2	20	11	2	0	1	2	0	0	1.0	
i 1	9.260836734693877	1.5150000000000001	74	698	4	24	1	2	0	-2	2	0	0	3.0	
i 1	9.266455782312924	0.2525	71	698	4	4	15	8	0	-2	8	0	0	3.0	
i 1	9.26725850340136	0.505	71	200	2	20	4	2	0	1	2	0	0	1.0	
i 1	9.269666666666666	0.2525	74	1084	4	4	5	8	0	-2	8	0	0	3.0	
i 1	9.514047619047618	0.505	74	698	4	9	10	8	0	-2	8	0	0	2.0	
i 1	9.519666666666666	0.505	71	200	5	2	2	8	0	-1	8	0	0	3.0	
i 1	9.73274149659864	1.2625	71	698	2	20	2	8	0	-2	8	0	0	1.0	
i 1	9.740768707482994	1.2625	71	698	1	20	1	2	0	-2	2	0	0	1.0	
i 1	9.997190476190477	1.01	71	1084	4	3	8	2	0	-1	2	0	0	3.0	
i 1	9.998795918367348	1.01	71	698	5	3	5	8	0	-1	8	0	0	3.0	
i 1	10.485149659863946	1.01	72	1084	3	5	2	8	0	-2	8	0	0	2.0	
i 1	10.500401360544217	1.01	72	698	3	5	16	8	0	1	8	0	0	2.0	
i 1	10.731938775510205	1.2625	74	698	6	1	8	2	0	-2	2	0	0	2.0	
i 1	10.76886394557823	1.2625	71	200	7	1	8	8	0	-1	8	0	0	2.0	
i 1	10.987557823129253	1.01	71	698	5	9	6	8	0	-1	8	0	0	2.0	
i 1	11.00842857142857	1.01	74	200	5	2	14	8	0	-2	8	0	0	3.0	
i 1	11.00842857142857	0.7575000000000001	74	698	2	24	13	2	0	-2	2	0	0	5.0	
i 1	11.01725850340136	0.2525	74	200	2	20	5	2	0	-2	2	0	0	1.0	
i 1	11.240768707482994	0.2525	71	698	2	20	8	8	0	-2	8	0	0	1.0	
i 1	11.252006802721088	0.2525	71	698	2	20	15	2	0	1	2	0	0	1.0	
i 1	11.2568231292517	0.2525	71	698	1	20	6	2	0	1	2	0	0	1.0	
i 1	11.485952380952382	0.2525	74	698	2	20	10	2	0	-2	2	0	0	1.0	
i 1	11.495585034013606	0.2525	72	200	7	5	6	8	0	-2	8	0	0	2.0	
i 1	11.510034013605441	0.2525	74	200	2	20	14	2	0	-2	2	0	0	1.0	
i 1	11.51725850340136	0.2525	72	698	3	5	12	2	0	-2	2	0	0	2.0	
i 1	11.73274149659864	1.5150000000000001	75	1084	3	5	16	8	0	-2	8	0	0	2.0	
i 1	11.736755102040817	1.5150000000000001	75	698	3	5	3	2	0	-2	2	0	0	2.0	
i 1	11.985952380952382	0.505	71	698	6	1	4	2	0	-2	2	0	0	2.0	
i 1	11.992374149659865	0.7575000000000001	74	1084	4	4	5	8	0	-2	8	0	0	3.0	
i 1	11.994782312925171	0.7575000000000001	71	698	4	4	13	8	0	-2	8	0	0	3.0	
i 1	12.014850340136054	0.505	74	1084	6	1	5	2	0	-2	2	0	0	2.0	
i 1	12.015653061224489	0.2525	74	698	2	24	10	2	0	-2	2	0	0	5.0	
i 1	12.016455782312924	0.2525	71	200	2	20	15	2	0	-2	2	0	0	1.0	
i 1	12.235952380952382	1.2625	74	698	1	20	7	2	0	-2	2	0	0	1.0	
i 1	12.239163265306123	1.2625	71	698	2	20	5	8	0	-2	8	0	0	1.0	
i 1	12.510034013605441	0.7575000000000001	71	698	6	1	5	2	0	-1	2	0	0	2.0	
i 1	12.516455782312924	0.7575000000000001	74	200	6	1	4	8	0	-2	8	0	0	2.0	
i 1	12.761639455782312	0.7575000000000001	71	200	5	2	2	8	0	-1	8	0	0	3.0	
i 1	12.76886394557823	0.7575000000000001	74	698	4	9	5	8	0	-2	8	0	0	2.0	
i 1	13.244782312925171	1.2625	72	698	3	5	3	2	0	1	2	0	0	2.0	
i 1	13.253612244897958	1.01	74	698	4	24	3	2	0	-2	2	0	0	3.0	
i 1	13.260836734693877	1.01	74	1084	4	24	9	2	0	-1	2	0	0	3.0	
i 1	13.264047619047618	1.2625	75	200	6	5	4	8	0	-2	8	0	0	2.0	
i 1	13.501204081632652	0.2525	71	200	2	20	9	8	0	-2	8	0	0	1.0	
i 1	13.502006802721088	0.2525	71	1084	4	3	6	2	0	-1	2	0	0	3.0	
i 1	13.509231292517006	30.805	63	200	5	14	7	1	0	1	1	0	0	2.250249158079288	
i 1	13.511639455782312	3.535	74	698	2	24	2	2	0	-2	2	0	0	5.0	
i 1	13.516455782312924	0.2525	71	698	5	3	8	8	0	-1	8	0	0	3.0	
i 1	13.739965986394559	0.505	74	200	5	2	7	8	0	-2	8	0	0	3.0	
i 1	13.740768707482994	0.505	74	698	1	20	12	8	0	-2	8	0	0	1.0	
i 1	13.746387755102042	0.505	71	698	5	9	11	8	0	-1	8	0	0	2.0	
i 1	13.751204081632652	3.2825	71	698	1	20	14	2	0	-2	2	0	0	1.0	
i 1	13.75842857142857	0.505	71	698	2	20	7	8	0	-2	8	0	0	1.0	
i 1	14.237557823129253	1.01	74	1084	4	4	15	8	0	-2	8	0	0	3.0	
i 1	14.253612244897958	1.01	71	698	4	4	7	8	0	-2	8	0	0	3.0	
i 1	14.256020408163264	1.2625	71	200	7	1	13	8	0	-1	8	0	0	2.0	
i 1	14.257625850340135	0.505	74	698	2	24	2	2	0	1	2	0	0	5.0	
i 1	14.259231292517006	0.505	71	698	1	20	11	2	0	1	2	0	0	1.0	
i 1	14.265653061224489	1.2625	74	698	6	1	8	2	0	-2	2	0	0	2.0	
i 1	14.49157142857143	0.2525	72	1084	6	5	7	8	0	-2	8	0	0	2.0	
i 1	14.509231292517006	12.625	63	698	4	18	11	16	0	1	16	0	0	6.937531292532962	
i 1	14.51886394557823	0.2525	72	698	3	5	12	8	0	1	8	0	0	2.0	
i 1	14.740768707482994	1.5150000000000001	74	698	1	20	6	8	0	-2	8	0	0	1.0	
i 1	14.7431768707483	1.5150000000000001	71	698	2	20	15	8	0	-2	8	0	0	1.0	
i 1	14.747190476190477	1.5150000000000001	72	698	3	5	9	2	0	-2	2	0	0	2.0	
i 1	14.749598639455783	1.5150000000000001	72	200	6	5	13	8	0	-2	8	0	0	2.0	
i 1	15.246387755102042	1.01	71	200	5	2	6	8	0	-1	8	0	0	3.0	
i 1	15.253612244897958	1.01	74	698	4	9	13	8	0	-2	8	0	0	2.0	
i 1	15.504414965986394	1.5150000000000001	74	1084	5	1	4	2	0	-2	2	0	0	2.0	
i 1	15.510034013605441	1.5150000000000001	71	698	6	1	1	2	0	-2	2	0	0	2.0	
i 1	16.247993197278912	1.01	75	698	3	5	3	2	0	-2	2	0	0	2.0	
i 1	16.2568231292517	0.7575000000000001	71	1084	4	3	16	2	0	-1	2	0	0	3.0	
i 1	16.26244217687075	0.7575000000000001	71	698	2	24	13	2	0	1	2	0	0	5.0	
i 1	16.26244217687075	1.01	74	698	2	20	13	2	0	-2	2	0	0	1.0	
i 1	16.269666666666666	0.7575000000000001	71	698	5	3	8	8	0	-1	8	0	0	3.0	
i 1	16.269666666666666	1.01	75	1084	3	5	4	8	0	-2	8	0	0	2.0	
i 1	16.986755102040817	0.7575000000000001	74	200	5	2	11	8	0	-2	8	0	0	3.0	
i 1	16.98755782312925	1.2625	71	698	6	1	7	2	0	-1	2	0	0	2.0	
i 1	16.98996598639456	0.2525	71	1084	2	24	6	2	0	-2	2	0	0	5.0	
i 1	16.992374149659863	1.2625	74	200	7	1	16	8	0	-2	8	0	0	2.0	
i 1	16.99478231292517	0.7575000000000001	71	698	4	9	6	8	0	-1	8	0	0	2.0	
i 1	16.995585034013605	0.2525	71	1084	1	20	16	2	0	1	2	0	0	1.0	
i 1	17.001204081632654	0.7575000000000001	74	698	2	24	11	2	0	1	2	0	0	5.0	
i 1	17.23274149659864	0.505	74	698	1	20	2	8	0	-2	8	0	0	1.0	
i 1	17.23274149659864	0.505	71	698	1	20	6	2	0	1	2	0	0	1.0	
i 1	17.23595238095238	0.2525	75	200	6	5	10	8	0	-2	8	0	0	2.0	
i 1	17.24638775510204	0.505	74	698	2	24	3	2	0	-2	2	0	0	5.0	
i 1	17.26565306122449	0.2525	72	698	3	5	6	2	0	1	2	0	0	2.0	
i 1	17.48755782312925	1.5150000000000001	72	698	3	5	12	8	0	1	8	0	0	2.0	
i 1	17.51083673469388	1.5150000000000001	72	1084	6	5	8	8	0	-2	8	0	0	2.0	
i 1	17.735149659863946	0.2525	74	1084	4	4	13	8	0	-2	8	0	0	3.0	
i 1	17.735149659863946	0.2525	71	200	2	20	4	2	0	-2	2	0	0	1.0	
i 1	17.73755782312925	0.7575000000000001	74	698	2	20	16	2	0	-2	2	0	0	1.0	
i 1	17.7568231292517	0.2525	71	1084	1	20	2	2	0	-2	2	0	0	1.0	
i 1	17.759231292517008	0.2525	71	698	2	20	8	8	0	-2	8	0	0	1.0	
i 1	17.768061224489795	0.2525	71	698	4	4	5	8	0	-2	8	0	0	3.0	
i 1	17.985149659863946	0.505	74	698	4	9	1	8	0	-2	8	0	0	2.0	
i 1	17.98595238095238	0.505	74	698	2	24	11	2	0	-2	2	0	0	5.0	
i 1	17.99638775510204	0.505	74	698	2	24	7	2	0	-2	2	0	0	5.0	
i 1	18.014850340136054	0.505	74	698	1	20	10	2	0	1	2	0	0	1.0	
i 1	18.019666666666666	0.505	71	200	5	2	14	8	0	-1	8	0	0	3.0	
i 1	18.240768707482992	0.505	74	1084	4	24	12	2	0	-1	2	0	0	3.0	
i 1	18.24478231292517	0.505	74	698	4	24	3	2	0	-2	2	0	0	3.0	
i 1	18.49478231292517	1.01	71	1084	4	3	1	2	0	-1	2	0	0	3.0	
i 1	18.5068231292517	0.2525	71	698	1	20	2	2	0	1	2	0	0	1.0	
i 1	18.516455782312924	1.01	71	698	5	3	8	8	0	-1	8	0	0	3.0	
i 1	18.518863945578232	0.2525	71	698	2	20	2	8	0	-2	8	0	0	1.0	
i 1	18.735149659863946	0.7575000000000001	74	698	6	1	1	2	0	-2	2	0	0	2.0	
i 1	18.74638775510204	0.7575000000000001	71	200	7	1	1	8	0	-1	8	0	0	2.0	
i 1	18.754414965986395	0.2525	74	698	2	24	14	2	0	-2	2	0	0	5.0	
i 1	18.7568231292517	0.2525	71	200	2	20	7	8	0	-2	8	0	0	1.0	
i 1	19.011639455782312	1.2625	72	200	6	5	5	8	0	-2	8	0	0	2.0	
i 1	19.011639455782312	1.2625	72	698	3	5	1	2	0	-2	2	0	0	2.0	
i 1	19.235149659863946	0.2525	74	200	2	20	11	8	0	1	8	0	0	1.0	
i 1	19.24157142857143	0.2525	74	698	2	24	12	2	0	-2	2	0	0	5.0	
i 1	19.250401360544217	0.2525	71	1084	2	24	4	2	0	-2	2	0	0	5.0	
i 1	19.268863945578232	0.2525	74	698	2	24	9	2	0	1	2	0	0	5.0	
i 1	19.4931768707483	1.01	71	698	6	1	15	2	0	-2	2	0	0	2.0	
i 1	19.49478231292517	0.505	71	698	1	20	4	2	0	1	2	0	0	1.0	
i 1	19.49638775510204	1.01	74	200	5	2	7	8	0	-2	8	0	0	3.0	
i 1	19.50521768707483	0.7575000000000001	74	1084	5	1	1	2	0	-2	2	0	0	2.0	
i 1	19.507625850340137	0.505	71	698	2	20	11	8	0	-2	8	0	0	1.0	
i 1	19.513244897959183	1.01	71	698	4	9	15	8	0	-1	8	0	0	2.0	
i 1	19.997993197278912	0.2525	74	200	2	20	4	2	0	1	2	0	0	1.0	
i 1	20.018061224489795	0.2525	74	698	2	24	7	2	0	-2	2	0	0	5.0	
i 1	20.23595238095238	1.01	74	698	1	20	6	2	0	-2	2	0	0	1.0	
i 1	20.238360544217688	1.01	74	698	1	24	3	2	0	-2	2	0	0	5.0	
i 1	20.242374149659863	0.2525	74	1084	6	1	8	2	0	-2	2	0	0	2.0	
i 1	20.24478231292517	1.01	71	698	2	20	7	8	0	-2	8	0	0	1.0	
i 1	20.247993197278912	1.01	74	698	2	20	9	2	0	-2	2	0	0	1.0	
i 1	20.248795918367346	0.2525	75	1084	6	5	9	8	0	-2	8	0	0	2.0	
i 1	20.256020408163266	6.8175	63	1084	4	7	10	1	0	1	1	0	0	1.5001661053861919	
i 1	20.264850340136054	0.2525	75	698	3	5	9	2	0	-2	2	0	0	2.0	
i 1	20.48274149659864	1.2625	74	200	7	1	14	8	0	-2	8	0	0	2.0	
i 1	20.48755782312925	1.5150000000000001	72	698	3	5	1	2	0	1	2	0	0	2.0	
i 1	20.50361224489796	0.7575000000000001	74	1084	4	4	10	8	0	-2	8	0	0	3.0	
i 1	20.51083673469388	0.7575000000000001	71	698	4	4	14	8	0	-2	8	0	0	3.0	
i 1	20.51565306122449	1.5150000000000001	75	200	4	5	7	8	0	-2	8	0	0	2.0	
i 1	20.518863945578232	1.2625	71	698	6	1	8	2	0	-1	2	0	0	2.0	
i 1	21.231136054421768	0.2525	71	200	2	20	15	8	0	1	8	0	0	1.0	
i 1	21.238360544217688	0.7575000000000001	71	200	5	2	7	8	0	-1	8	0	0	3.0	
i 1	21.2431768707483	12.625	63	698	4	18	9	1	0	2	1	0	0	6.937531292532962	
i 1	21.252006802721088	0.2525	74	698	2	24	13	2	0	-2	2	0	0	5.0	
i 1	21.25842857142857	0.7575000000000001	74	698	4	9	4	8	0	-2	8	0	0	2.0	
i 1	21.26244217687075	0.2525	71	1084	1	24	7	8	0	1	8	0	0	5.0	
i 1	21.26404761904762	0.2525	74	698	2	24	1	2	0	1	2	0	0	5.0	
i 1	21.48434693877551	1.01	71	698	2	20	14	8	0	-2	8	0	0	1.0	
i 1	21.488360544217688	1.01	74	698	1	20	12	2	0	1	2	0	0	1.0	
i 1	21.743979591836734	1.5150000000000001	74	698	4	24	12	2	0	-2	2	0	0	3.0	
i 1	21.761639455782312	1.5150000000000001	74	1084	4	24	15	2	0	-1	2	0	0	3.0	
i 1	21.992374149659863	0.2525	71	698	4	3	9	8	0	-1	8	0	0	3.0	
i 1	21.995585034013605	1.01	72	1084	5	5	10	8	0	-2	8	0	0	2.0	
i 1	21.999598639455783	1.01	72	698	3	5	6	8	0	1	8	0	0	2.0	
i 1	22.009231292517008	0.2525	71	1084	4	3	11	2	0	-1	2	0	0	3.0	
i 1	22.23434693877551	0.505	74	200	5	2	16	8	0	-2	8	0	0	3.0	
i 1	22.245585034013605	0.505	71	698	4	9	4	8	0	-1	8	0	0	2.0	
i 1	22.49157142857143	0.2525	74	698	2	24	14	2	0	-2	2	0	0	5.0	
i 1	22.51083673469388	0.2525	71	200	2	20	5	2	0	1	2	0	0	1.0	
i 1	22.738360544217688	0.7575000000000001	71	698	1	20	4	2	0	-2	2	0	0	1.0	
i 1	22.747993197278912	0.7575000000000001	71	698	2	20	5	8	0	-2	8	0	0	1.0	
i 1	22.759231292517008	1.01	71	698	4	4	16	8	0	-2	8	0	0	3.0	
i 1	22.759231292517008	0.505	71	698	1	24	8	8	0	1	8	0	0	5.0	
i 1	22.763244897959183	0.505	74	698	2	20	5	2	0	-2	2	0	0	1.0	
i 1	22.766455782312924	1.01	74	1084	4	4	2	8	0	-2	8	0	0	3.0	
i 1	23.006020408163266	0.2525	72	698	3	5	12	2	0	-2	2	0	0	2.0	
i 1	23.00842857142857	0.2525	72	200	6	5	11	8	0	-2	8	0	0	2.0	
i 1	23.23916326530612	0.2525	74	698	1	20	13	2	0	1	2	0	0	1.0	
i 1	23.2568231292517	1.5150000000000001	75	1084	6	5	6	8	0	-2	8	0	0	2.0	
i 1	23.26083673469388	1.2625	71	200	7	1	4	8	0	-1	8	0	0	2.0	
i 1	23.266455782312924	1.5150000000000001	75	698	3	5	10	2	0	-2	2	0	0	2.0	
i 1	23.268863945578232	1.2625	74	698	6	1	3	2	0	-2	2	0	0	2.0	
i 1	23.268863945578232	0.2525	74	698	2	24	8	2	0	-2	2	0	0	5.0	
i 1	23.492374149659863	0.2525	74	1084	1	20	8	2	0	1	2	0	0	1.0	
i 1	23.4931768707483	1.2625	74	698	2	20	7	2	0	-2	2	0	0	1.0	
i 1	23.499598639455783	0.2525	74	1084	1	24	14	2	0	1	2	0	0	5.0	
i 1	23.50361224489796	0.2525	74	698	2	24	15	2	0	1	2	0	0	5.0	
i 1	23.735149659863946	1.01	74	698	4	9	6	8	0	-2	8	0	0	2.0	
i 1	23.738360544217688	1.01	71	698	1	24	5	2	0	-2	2	0	0	5.0	
i 1	23.74478231292517	1.01	71	200	5	2	2	8	0	-1	8	0	0	3.0	
i 1	24.48755782312925	0.505	71	698	6	1	16	2	0	-2	2	0	0	2.0	
i 1	24.50521768707483	0.505	74	1084	6	1	11	2	0	-2	2	0	0	2.0	
i 1	24.752809523809525	1.2625	72	698	3	5	13	2	0	1	2	0	0	2.0	
i 1	24.759231292517008	0.2525	71	698	2	20	2	8	0	-2	8	0	0	1.0	
i 1	24.764850340136054	0.7575000000000001	71	698	4	3	10	8	0	-1	8	0	0	3.0	
i 1	24.76725850340136	0.7575000000000001	71	1084	4	3	4	2	0	-1	2	0	0	3.0	
i 1	24.76725850340136	1.2625	75	200	4	5	15	8	0	-2	8	0	0	2.0	
i 1	24.768863945578232	0.2525	74	698	1	20	14	2	0	1	2	0	0	1.0	
i 1	24.980333333333334	0.2525	74	698	2	24	13	2	0	1	2	0	0	5.0	
i 1	24.981938775510205	0.2525	71	1084	1	24	1	2	0	1	2	0	0	5.0	
i 1	24.988360544217688	0.7575000000000001	71	698	6	1	2	2	0	-1	2	0	0	2.0	
i 1	25.000401360544217	0.2525	74	200	2	20	1	2	0	-2	2	0	0	1.0	
i 1	25.00361224489796	0.7575000000000001	74	200	7	1	11	8	0	-2	8	0	0	2.0	
i 1	25.014850340136054	0.2525	74	698	2	24	4	2	0	-2	2	0	0	5.0	
i 1	25.242374149659863	0.505	74	698	2	20	3	2	0	-2	2	0	0	1.0	
i 1	25.245585034013605	1.7675	71	698	2	20	15	8	0	-2	8	0	0	1.0	
i 1	25.261639455782312	1.7675	71	698	1	20	13	2	0	1	2	0	0	1.0	
i 1	25.268061224489795	0.505	71	698	1	24	1	2	0	-2	2	0	0	5.0	
i 1	25.481136054421768	0.7575000000000001	71	698	4	9	2	8	0	-1	8	0	0	2.0	
i 1	25.48595238095238	0.7575000000000001	74	200	5	2	7	8	0	-2	8	0	0	3.0	
i 1	25.73916326530612	1.01	74	698	4	24	15	2	0	-2	2	0	0	3.0	
i 1	25.76244217687075	1.01	74	1084	4	24	3	2	0	-1	2	0	0	3.0	
i 1	25.99157142857143	0.2525	72	1084	5	5	8	8	0	-2	8	0	0	2.0	
i 1	26.00521768707483	0.2525	72	698	3	5	15	8	0	1	8	0	0	2.0	
i 1	26.230333333333334	0.2525	74	1084	4	4	1	8	0	-2	8	0	0	3.0	
i 1	26.235149659863946	0.7575000000000001	72	200	6	5	12	8	0	-2	8	0	0	2.0	
i 1	26.252006802721088	0.2525	71	698	4	4	13	8	0	-2	8	0	0	3.0	
i 1	26.257625850340137	1.5150000000000001	72	698	3	5	11	2	0	-2	2	0	0	2.0	
i 1	26.498795918367346	0.505	71	200	5	2	4	8	0	-1	8	0	0	3.0	
i 1	26.50521768707483	0.505	74	698	4	9	9	8	0	-2	8	0	0	2.0	
i 1	26.759231292517008	0.2525	74	698	6	1	16	2	0	-2	2	0	0	2.0	
i 1	26.76244217687075	1.2625	71	200	7	1	10	8	0	-1	8	0	0	2.0	
i 1	26.985149659863946	17.17	63	1084	4	7	9	1	0	1	1	0	0	1.5001661053861919	
i 1	26.98595238095238	0.7575000000000001	72	200	4	5	9	8	0	-2	8	0	0	2.0	
i 1	26.98755782312925	1.01	71	1084	4	3	5	2	0	-1	2	0	0	3.0	
i 1	26.997190476190475	1.01	74	698	5	1	12	2	0	-2	2	0	0	2.0	
i 1	27.002809523809525	1.01	71	698	4	3	11	8	0	-1	8	0	0	3.0	
i 1	27.01404761904762	1.01	74	698	2	20	2	2	0	-2	2	0	0	12.0	
i 1	27.018863945578232	1.01	71	698	1	24	2	2	0	-2	2	0	0	16.0	
i 1	27.742374149659863	1.01	75	1084	5	5	14	8	0	-2	8	0	0	2.0	
i 1	27.757625850340137	1.01	75	698	3	5	2	2	0	-2	2	0	0	2.0	
i 1	27.980333333333334	0.505	71	698	2	20	4	8	0	-2	8	0	0	12.0	
i 1	27.981136054421768	12.625	63	698	4	19	5	1	0	1	1	0	0	6.937531292532962	
i 1	27.993979591836734	1.01	74	200	5	2	16	8	0	-2	8	0	0	3.0	
i 1	27.995585034013605	1.5150000000000001	71	698	6	1	15	2	0	-2	2	0	0	2.0	
i 1	28.013244897959183	1.01	71	698	4	9	14	8	0	-1	8	0	0	2.0	
i 1	28.018061224489795	0.505	71	698	1	20	1	2	0	1	2	0	0	12.0	
i 1	28.019666666666666	1.5150000000000001	74	1084	6	1	11	2	0	-2	2	0	0	2.0	
i 1	28.483544217687076	0.2525	74	698	2	24	3	2	0	-2	2	0	0	16.0	
i 1	28.49478231292517	0.2525	74	698	1	24	11	2	0	1	2	0	0	16.0	
i 1	28.499598639455783	0.2525	74	200	2	20	6	2	0	-2	2	0	0	12.0	
i 1	28.501204081632654	0.2525	71	1084	1	24	5	2	0	1	2	0	0	16.0	
i 1	28.730333333333334	0.505	71	698	1	24	7	2	0	-2	2	0	0	16.0	
i 1	28.731136054421768	0.505	74	698	2	20	15	2	0	-2	2	0	0	12.0	
i 1	28.735149659863946	0.2525	72	698	6	5	16	2	0	1	2	0	0	2.0	
i 1	28.752809523809525	0.2525	75	200	4	5	6	8	0	-2	8	0	0	2.0	
i 1	28.76404761904762	1.5150000000000001	71	698	1	20	10	2	0	-2	2	0	0	12.0	
i 1	28.766455782312924	1.5150000000000001	71	698	2	20	15	8	0	-2	8	0	0	12.0	
i 1	28.9931768707483	0.7575000000000001	74	1084	4	4	15	8	0	-2	8	0	0	3.0	
i 1	28.9931768707483	1.5150000000000001	72	698	3	5	3	8	0	1	8	0	0	2.0	
i 1	28.99478231292517	1.5150000000000001	72	1084	5	5	9	8	0	-2	8	0	0	2.0	
i 1	28.998795918367346	0.7575000000000001	71	698	4	4	7	8	0	-2	8	0	0	3.0	
i 1	29.501204081632654	1.2625	71	698	6	1	6	2	0	-1	2	0	0	2.0	
i 1	29.519666666666666	1.2625	74	200	7	1	15	8	0	-2	8	0	0	2.0	
i 1	29.735149659863946	0.7575000000000001	71	200	5	2	3	8	0	-1	8	0	0	3.0	
i 1	29.735149659863946	0.7575000000000001	74	698	4	9	14	8	0	-2	8	0	0	2.0	
i 1	30.238360544217688	1.01	74	698	2	20	12	2	0	-2	2	0	0	12.0	
i 1	30.254414965986395	1.01	71	698	1	24	11	2	0	-2	2	0	0	16.0	
i 1	30.481938775510205	1.2625	72	200	4	5	5	8	0	-2	8	0	0	2.0	
i 1	30.49638775510204	0.2525	71	698	4	3	6	8	0	-1	8	0	0	3.0	
i 1	30.51565306122449	1.2625	72	698	3	5	10	2	0	-2	2	0	0	2.0	
i 1	30.518061224489795	0.2525	71	1084	4	3	3	2	0	-1	2	0	0	3.0	
i 1	30.73595238095238	0.505	71	698	4	9	10	8	0	-1	8	0	0	2.0	
i 1	30.7568231292517	0.505	74	1084	4	24	2	2	0	-1	2	0	0	3.0	
i 1	30.76565306122449	0.505	74	698	4	24	16	2	0	-2	2	0	0	3.0	
i 1	30.768863945578232	0.505	74	200	5	2	15	8	0	-2	8	0	0	3.0	
i 1	31.23916326530612	0.7575000000000001	71	698	2	20	8	8	0	-2	8	0	0	12.0	
i 1	31.240768707482992	0.7575000000000001	74	698	5	1	1	2	0	-2	2	0	0	2.0	
i 1	31.247993197278912	0.7575000000000001	71	200	7	1	8	8	0	-1	8	0	0	2.0	
i 1	31.259231292517008	0.7575000000000001	71	698	1	20	1	2	0	-2	2	0	0	12.0	
i 1	31.26083673469388	1.01	71	698	4	4	16	8	0	-2	8	0	0	3.0	
i 1	31.264850340136054	1.01	74	1084	4	4	12	8	0	-2	8	0	0	3.0	
i 1	31.748795918367346	0.2525	75	1084	5	5	16	8	0	-2	8	0	0	2.0	
i 1	31.768061224489795	0.2525	75	698	3	5	5	2	0	-2	2	0	0	2.0	
i 1	31.98434693877551	1.5150000000000001	72	698	6	5	5	2	0	1	2	0	0	2.0	
i 1	32.00441496598639	0.505	74	698	2	24	2	2	0	-2	2	0	0	16.0	
i 1	32.011639455782316	1.01	74	1084	6	1	7	2	0	-2	2	0	0	2.0	
i 1	32.01244217687075	0.2525	71	1084	1	20	4	2	0	1	2	0	0	12.0	
i 1	32.01244217687075	0.2525	74	698	2	20	8	2	0	-2	2	0	0	12.0	
i 1	32.01725850340136	1.5150000000000001	75	200	4	5	10	8	0	-2	8	0	0	2.0	
i 1	32.0180612244898	1.01	71	698	6	1	9	2	0	-2	2	0	0	2.0	
i 1	32.0180612244898	0.2525	74	200	2	20	9	2	0	1	2	0	0	12.0	
i 1	32.241571428571426	1.01	74	698	4	9	6	8	0	-2	8	0	0	2.0	
i 1	32.24879591836735	1.01	71	698	2	20	12	8	0	-2	8	0	0	12.0	
i 1	32.26003401360544	1.01	71	698	1	20	5	2	0	1	2	0	0	12.0	
i 1	32.26003401360544	0.2525	74	698	1	20	5	2	0	1	2	0	0	12.0	
i 1	32.261639455782316	1.01	71	200	5	2	8	8	0	-1	8	0	0	3.0	
i 1	32.493979591836734	0.2525	71	698	1	24	11	2	0	1	2	0	0	16.0	
i 1	32.51003401360544	0.2525	74	698	2	20	13	2	0	-2	2	0	0	12.0	
i 1	33.00120408163265	1.2625	74	200	7	1	4	8	0	-2	8	0	0	2.0	
i 1	33.01886394557823	0.7575000000000001	71	698	6	1	16	2	0	-1	2	0	0	2.0	
i 1	33.235952380952384	0.7575000000000001	71	698	4	3	8	8	0	-1	8	0	0	3.0	
i 1	33.24478231292517	1.01	74	698	2	24	3	2	0	-2	2	0	0	16.0	
i 1	33.24959863945578	0.7575000000000001	71	1084	4	3	3	2	0	-1	2	0	0	3.0	
i 1	33.25521768707483	0.2525	71	200	2	20	1	2	0	1	2	0	0	12.0	
i 1	33.48514965986394	0.2525	72	1084	5	5	15	8	0	-2	8	0	0	2.0	
i 1	33.49237414965987	0.2525	71	698	2	20	5	8	0	-2	8	0	0	12.0	
i 1	33.4931768707483	1.01	72	698	3	5	2	8	0	1	8	0	0	2.0	
i 1	33.50441496598639	0.505	74	698	1	20	11	2	0	1	2	0	0	12.0	
i 1	33.50923129251701	0.505	71	698	1	20	7	8	0	-2	8	0	0	12.0	
i 1	33.73434693877551	0.505	71	698	5	1	11	2	0	-1	2	0	0	2.0	
i 1	33.76485034013606	0.7575000000000001	72	1084	3	5	6	8	0	-2	8	0	0	2.0	
i 1	33.99478231292517	0.7575000000000001	71	698	4	9	9	8	0	-1	8	0	0	2.0	
i 1	34.006020408163266	0.2525	71	200	2	20	10	8	0	-2	8	0	0	12.0	
i 1	34.0068231292517	0.7575000000000001	74	200	5	2	15	8	0	-2	8	0	0	3.0	
i 1	34.01003401360544	0.2525	74	698	2	20	10	2	0	-2	2	0	0	12.0	
i 1	34.014047619047616	0.2525	71	1084	1	20	8	8	0	-2	8	0	0	12.0	
i 1	34.2319387755102	0.505	74	698	1	20	15	8	0	1	8	0	0	12.0	
i 1	34.25521768707483	1.5150000000000001	74	698	4	24	10	2	0	-2	2	0	0	3.0	
i 1	34.26003401360544	0.505	71	698	1	20	1	8	0	-2	8	0	0	12.0	
i 1	34.261639455782316	1.5150000000000001	74	1084	4	24	3	2	0	-1	2	0	0	3.0	
i 1	34.48514965986394	0.2525	72	200	4	5	3	8	0	-2	8	0	0	2.0	
i 1	34.510836734693875	0.2525	72	698	6	5	12	2	0	-2	2	0	0	2.0	
i 1	34.73274149659864	1.5150000000000001	75	1084	5	5	9	8	0	-2	8	0	0	2.0	
i 1	34.735952380952384	0.2525	71	200	2	20	7	2	0	-2	2	0	0	12.0	
i 1	34.73755782312925	0.2525	74	1084	4	4	8	8	0	-2	8	0	0	3.0	
i 1	34.74237414965987	9.3425	63	698	4	19	5	1	0	1	1	0	0	6.937531292532962	
i 1	34.74638775510204	0.2525	71	698	4	4	2	8	0	-2	8	0	0	3.0	
i 1	34.761639455782316	1.2625	74	698	2	24	16	2	0	-2	2	0	0	16.0	
i 1	34.766455782312924	1.5150000000000001	75	698	3	5	10	2	0	-2	2	0	0	2.0	
i 1	34.98675510204082	1.01	71	698	1	20	8	2	0	-2	2	0	0	12.0	
i 1	34.989163265306125	2.2725	71	698	1	20	10	8	0	-2	8	0	0	12.0	
i 1	34.99638775510204	0.505	71	200	5	2	9	8	0	-1	8	0	0	3.0	
i 1	34.997190476190475	0.505	74	698	4	9	5	8	0	-2	8	0	0	2.0	
i 1	34.997190476190475	1.7675	74	698	1	20	15	2	0	1	2	0	0	12.0	
i 1	35.50521768707483	1.01	71	1084	4	3	4	2	0	-1	2	0	0	3.0	
i 1	35.516455782312924	1.01	71	698	4	3	2	8	0	-1	8	0	0	3.0	
i 1	35.74799319727891	1.2625	71	200	7	1	14	8	0	-1	8	0	0	2.0	
i 1	35.764047619047616	1.2625	74	698	6	1	8	2	0	-2	2	0	0	2.0	
i 1	35.988360544217684	1.2625	74	698	1	24	15	2	0	1	2	0	0	16.0	
i 1	35.9931768707483	0.7575000000000001	74	698	1	20	9	2	0	-2	2	0	0	12.0	
i 1	36.24558503401361	1.2625	72	698	5	5	7	2	0	1	2	0	0	2.0	
i 1	36.256020408163266	1.2625	75	200	4	5	8	8	0	-2	8	0	0	2.0	
i 1	36.48675510204082	1.01	71	698	4	9	15	8	0	-1	8	0	0	2.0	
i 1	36.50521768707483	1.01	74	200	5	2	15	8	0	-2	8	0	0	3.0	
i 1	36.756020408163266	0.505	74	200	2	20	2	2	0	-2	2	0	0	12.0	
i 1	36.769666666666666	0.505	71	1084	1	24	13	2	0	-2	2	0	0	16.0	
i 1	37.00040136054422	0.505	71	698	6	1	16	2	0	-2	2	0	0	2.0	
i 1	37.00361224489796	0.505	74	1084	6	1	15	2	0	-2	2	0	0	2.0	
i 1	37.23755782312925	0.505	74	698	2	20	2	2	0	-2	2	0	0	12.0	
i 1	37.25361224489796	0.505	74	698	1	24	13	2	0	1	2	0	0	16.0	
i 1	37.4819387755102	0.7575000000000001	74	1084	4	4	14	8	0	-2	8	0	0	3.0	
i 1	37.48514965986394	0.2525	72	698	3	5	5	8	0	1	8	0	0	2.0	
i 1	37.49076870748299	0.7575000000000001	71	698	5	1	8	2	0	-1	2	0	0	2.0	
i 1	37.491571428571426	0.2525	72	1084	3	5	16	8	0	-2	8	0	0	2.0	
i 1	37.49959863945578	0.7575000000000001	74	200	7	1	9	8	0	-2	8	0	0	2.0	
i 1	37.502809523809525	0.7575000000000001	71	698	4	4	9	8	0	-2	8	0	0	3.0	
i 1	37.74076870748299	1.5150000000000001	72	698	6	5	2	2	0	-2	2	0	0	2.0	
i 1	37.75120408163265	0.2525	71	698	1	20	10	8	0	-2	8	0	0	12.0	
i 1	37.75441496598639	1.5150000000000001	72	200	4	5	16	8	0	-2	8	0	0	2.0	
i 1	37.76725850340136	0.2525	74	698	1	20	12	8	0	1	8	0	0	12.0	
i 1	38.0068231292517	0.505	74	698	2	24	5	2	0	-2	2	0	0	16.0	
i 1	38.01003401360544	0.505	74	200	2	20	15	8	0	-2	8	0	0	12.0	
i 1	38.010836734693875	0.2525	74	1084	1	20	14	2	0	-2	2	0	0	12.0	
i 1	38.01244217687075	0.2525	74	698	2	20	15	2	0	-2	2	0	0	12.0	
i 1	38.2319387755102	1.01	74	1084	4	24	1	2	0	-1	2	0	0	3.0	
i 1	38.23434693877551	1.01	74	698	4	24	2	2	0	-2	2	0	0	3.0	
i 1	38.239163265306125	0.7575000000000001	74	698	4	9	11	8	0	-2	8	0	0	2.0	
i 1	38.258428571428574	0.7575000000000001	71	200	5	2	14	8	0	-1	8	0	0	3.0	
i 1	38.4819387755102	0.2525	71	698	1	20	14	8	0	-2	8	0	0	12.0	
i 1	38.50521768707483	0.2525	71	698	1	20	15	2	0	-2	2	0	0	12.0	
i 1	38.51565306122449	0.2525	74	698	1	24	11	2	0	1	2	0	0	16.0	
i 1	38.739163265306125	0.2525	74	698	1	24	5	2	0	1	2	0	0	16.0	
i 1	38.76003401360544	0.2525	74	1084	1	24	6	2	0	-2	2	0	0	16.0	
i 1	38.98434693877551	0.2525	71	698	4	3	13	8	0	-1	8	0	0	3.0	
i 1	38.988360544217684	0.2525	71	698	1	24	5	2	0	1	2	0	0	16.0	
i 1	38.997190476190475	0.2525	71	1084	4	3	1	2	0	-1	2	0	0	3.0	
i 1	39.0068231292517	0.7575000000000001	71	698	1	20	12	8	0	-2	8	0	0	12.0	
i 1	39.01886394557823	0.7575000000000001	71	698	1	20	8	8	0	-2	8	0	0	12.0	
i 1	39.230333333333334	0.2525	71	698	1	20	15	2	0	1	2	0	0	12.0	
i 1	39.23274149659864	0.2525	74	698	2	24	3	2	0	-2	2	0	0	16.0	
i 1	39.238360544217684	1.2625	71	200	7	1	5	8	0	-1	8	0	0	2.0	
i 1	39.23996598639456	1.01	75	1084	5	5	10	8	0	-2	8	0	0	2.0	
i 1	39.243979591836734	1.01	75	698	3	5	15	2	0	-2	2	0	0	2.0	
i 1	39.2568231292517	1.2625	74	698	6	1	3	2	0	-2	2	0	0	2.0	
i 1	39.26003401360544	0.505	71	698	4	9	14	8	0	-1	8	0	0	2.0	
i 1	39.26565306122449	0.505	74	200	5	2	1	8	0	-2	8	0	0	3.0	
i 1	39.73755782312925	1.01	71	698	4	4	15	8	0	-2	8	0	0	3.0	
i 1	39.7431768707483	0.2525	74	698	1	24	4	2	0	1	2	0	0	16.0	
i 1	39.756020408163266	0.2525	74	1084	1	24	12	2	0	1	2	0	0	16.0	
i 1	39.76886394557823	0.505	74	698	2	20	7	2	0	-2	2	0	0	12.0	
i 1	39.769666666666666	1.01	74	1084	4	4	15	8	0	-2	8	0	0	3.0	
i 1	39.99799319727891	0.2525	74	698	1	24	16	2	0	-2	2	0	0	16.0	
i 1	40.23755782312925	0.2525	71	1084	1	24	1	2	0	1	2	0	0	16.0	
i 1	40.24799319727891	0.2525	74	698	1	24	16	2	0	1	2	0	0	16.0	
i 1	40.25361224489796	0.2525	75	200	4	5	4	8	0	-2	8	0	0	2.0	
i 1	40.25923129251701	0.2525	72	698	5	5	3	2	0	1	2	0	0	2.0	
i 1	40.26485034013606	0.2525	71	200	2	20	2	2	0	1	2	0	0	12.0	
i 1	40.2680612244898	0.2525	74	698	2	24	4	2	0	-2	2	0	0	16.0	
i 1	40.48113605442177	1.5150000000000001	74	698	1	20	12	2	0	-2	2	0	0	12.0	
i 1	40.488360544217684	0.505	71	698	1	20	12	8	0	-2	8	0	0	12.0	
i 1	40.49076870748299	0.505	74	698	1	20	13	2	0	1	2	0	0	12.0	
i 1	40.493979591836734	1.5150000000000001	72	1084	3	5	3	8	0	-2	8	0	0	2.0	
i 1	40.49558503401361	1.5150000000000001	72	698	6	5	14	8	0	1	8	0	0	2.0	
i 1	40.497190476190475	1.5150000000000001	71	698	5	1	15	2	0	-2	2	0	0	2.0	
i 1	40.497190476190475	1.5150000000000001	74	698	1	24	3	2	0	-2	2	0	0	16.0	
i 1	40.50923129251701	1.5150000000000001	74	1084	6	1	13	2	0	-2	2	0	0	2.0	
i 1	40.733544217687076	1.01	74	698	4	9	12	8	0	-2	8	0	0	2.0	
i 1	40.75441496598639	1.01	71	200	7	2	7	8	0	-1	8	0	0	3.0	
i 1	40.98113605442177	0.2525	74	698	2	20	3	2	0	-2	2	0	0	12.0	
i 1	41.01244217687075	0.2525	74	698	1	24	14	2	0	-2	2	0	0	16.0	
i 1	41.25441496598639	0.7575000000000001	74	698	1	20	14	2	0	1	2	0	0	12.0	
i 1	41.260836734693875	0.7575000000000001	71	698	1	20	12	8	0	-2	8	0	0	12.0	
i 1	41.747190476190475	0.7575000000000001	71	1084	4	3	15	2	0	-1	2	0	0	3.0	
i 1	41.76324489795918	0.7575000000000001	71	698	4	3	4	8	0	-1	8	0	0	3.0	
i 1	41.98113605442177	0.7575000000000001	74	698	2	20	11	2	0	-2	2	0	0	12.0	
i 1	41.98434693877551	0.7575000000000001	74	698	1	24	4	2	0	-2	2	0	0	16.0	
i 1	41.993979591836734	1.2625	72	200	4	5	6	8	0	-2	8	0	0	2.0	
i 1	42.00762585034013	1.2625	71	698	6	1	8	2	0	-1	2	0	0	2.0	
i 1	42.0180612244898	1.2625	72	698	5	5	5	2	0	-2	2	0	0	2.0	
i 1	42.01886394557823	1.2625	74	200	7	1	15	8	0	-2	8	0	0	2.0	
i 1	42.5068231292517	0.7575000000000001	74	200	5	2	1	8	0	-2	8	0	0	3.0	
i 1	42.511639455782316	0.7575000000000001	71	698	4	9	10	8	0	-1	8	0	0	2.0	
i 1	42.73434693877551	1.2625	74	698	1	24	14	2	0	-2	2	0	0	16.0	
i 1	42.739163265306125	0.2525	74	698	1	24	9	2	0	1	2	0	0	16.0	
i 1	42.73996598639456	0.2525	74	200	2	20	3	2	0	1	2	0	0	12.0	
i 1	42.747190476190475	0.2525	71	1084	1	24	12	2	0	-2	2	0	0	16.0	
i 1	42.99638775510204	1.01	71	698	1	20	15	2	0	-2	2	0	0	12.0	
i 1	43.01003401360544	0.505	71	698	1	20	2	8	0	-2	8	0	0	12.0	
i 1	43.0180612244898	0.505	74	698	1	20	15	8	0	1	8	0	0	12.0	
i 1	43.23113605442177	0.2525	75	1084	3	5	5	8	0	-2	8	0	0	2.0	
i 1	43.23514965986394	0.505	74	1084	4	24	5	2	0	-1	2	0	0	3.0	
i 1	43.23755782312925	0.2525	74	1084	4	4	10	8	0	-2	8	0	0	3.0	
i 1	43.2431768707483	0.2525	71	698	4	4	12	8	0	-2	8	0	0	3.0	
i 1	43.243979591836734	0.2525	75	698	3	5	2	2	0	-2	2	0	0	2.0	
i 1	43.25762585034013	0.505	74	698	4	24	7	2	0	-2	2	0	0	3.0	
i 1	43.48755782312925	0.505	74	698	4	9	14	8	0	-2	8	0	0	2.0	
i 1	43.48996598639456	0.505	74	698	2	20	15	2	0	-2	2	0	0	12.0	
i 1	43.49478231292517	0.505	71	200	7	2	6	8	0	-1	8	0	0	3.0	
i 1	43.50521768707483	0.505	72	698	5	5	9	2	0	1	2	0	0	2.0	
i 1	43.50521768707483	0.505	74	698	1	24	6	2	0	1	2	0	0	16.0	
i 1	43.51324489795918	0.505	75	200	4	5	14	8	0	-2	8	0	0	2.0	
i 1	43.738360544217684	0.2525	74	698	6	1	3	2	0	-2	2	0	0	2.0	
i 1	43.76485034013606	0.2525	71	200	5	1	6	8	0	-1	8	0	0	2.0	
i 1	43.98113605442177	1.5150000000000001	61	384	5	7	5	16	0	2	16	0	0	1.5001661053861919	
i 1	43.9819387755102	0.2525	74	384	2	24	2	2	0	-2	2	0	0	16.0	
i 1	43.98274149659864	1.01	71	700	6	1	6	2	0	-2	2	0	0	2.0	
i 1	43.985952380952384	1.01	75	700	4	5	14	2	0	-2	2	0	0	2.0	
i 1	43.989163265306125	3.2825	61	700	5	14	10	16	0	2	16	0	0	2.250249158079288	
i 1	43.98996598639456	1.01	72	384	6	5	4	2	0	1	2	0	0	2.0	
i 1	43.991571428571426	9.8475	61	700	5	14	9	1	0	2	1	0	0	2.250249158079288	
i 1	44.00040136054422	1.01	74	700	5	2	8	8	0	-1	8	0	0	3.0	
i 1	44.00441496598639	3.2825	61	384	4	19	14	16	0	1	16	0	0	6.937531292532962	
i 1	44.01003401360544	1.01	71	384	4	3	16	2	0	-2	2	0	0	3.0	
i 1	44.01725850340136	0.2525	71	1086	1	24	16	2	0	-2	2	0	0	16.0	
i 1	44.019666666666666	1.01	74	384	5	1	16	2	0	-1	2	0	0	2.0	
i 1	44.24638775510204	0.7575000000000001	74	1086	1	20	1	2	0	1	2	0	0	12.0	
i 1	44.256020408163266	3.0300000000000002	71	384	2	20	13	8	0	1	8	0	0	12.0	
i 1	44.25762585034013	0.7575000000000001	74	384	1	24	7	2	0	-2	2	0	0	16.0	
i 1	44.26244217687075	0.7575000000000001	71	1086	1	20	6	8	0	1	8	0	0	12.0	
i 1	44.98434693877551	0.505	71	384	4	4	7	8	0	-2	8	0	0	3.0	
i 1	44.98996598639456	0.2525	71	384	2	20	10	2	0	-2	2	0	0	12.0	
i 1	44.99076870748299	0.2525	74	700	2	20	4	2	0	1	2	0	0	12.0	
i 1	44.9931768707483	0.505	74	1086	6	1	3	8	0	-1	8	0	0	2.0	
i 1	45.00040136054422	0.2525	75	384	4	5	16	2	0	1	2	0	0	2.0	
i 1	45.006020408163266	0.505	71	1086	4	9	12	2	0	-2	2	0	0	2.0	
i 1	45.00762585034013	0.2525	72	1086	5	5	6	2	0	-2	2	0	0	2.0	
i 1	45.014047619047616	0.505	71	384	4	24	15	2	0	-2	2	0	0	3.0	
i 1	45.0180612244898	0.505	71	384	1	24	15	2	0	1	2	0	0	16.0	
i 1	45.23113605442177	1.7675	74	384	5	1	7	2	0	-1	2	0	0	2.0	
i 1	45.23514965986394	1.7675	72	1086	5	5	6	2	0	-2	2	0	0	2.0	
i 1	45.23675510204082	0.2525	75	700	4	5	5	2	0	1	2	0	0	2.0	
i 1	45.25200680272109	0.2525	74	384	6	1	14	8	0	-2	8	0	0	2.0	
i 1	45.26565306122449	0.2525	71	384	1	20	2	2	0	-2	2	0	0	12.0	
i 1	45.269666666666666	2.525	74	384	1	24	16	2	0	-2	2	0	0	16.0	
i 1	45.48274149659864	0.7575000000000001	71	384	4	3	3	2	0	-2	2	0	0	3.0	
i 1	45.485952380952384	0.2525	71	700	6	1	4	2	0	-2	2	0	0	2.0	
i 1	45.4931768707483	1.5150000000000001	71	700	6	1	16	2	0	-2	2	0	0	2.0	
i 1	45.49478231292517	0.2525	74	1086	4	9	3	8	0	-2	8	0	0	2.0	
i 1	45.50120408163265	0.7575000000000001	74	700	5	3	10	2	0	-2	2	0	0	3.0	
i 1	45.50361224489796	0.2525	71	1086	1	20	13	8	0	1	8	0	0	12.0	
i 1	45.50361224489796	22.22	61	700	5	7	1	16	0	2	16	0	0	1.5001661053861919	
i 1	45.50521768707483	1.5150000000000001	75	700	4	5	13	2	0	-2	2	0	0	2.0	
i 1	45.50521768707483	0.2525	74	1086	1	20	6	2	0	-2	2	0	0	12.0	
i 1	45.73434693877551	0.2525	75	700	4	5	3	2	0	1	2	0	0	2.0	
i 1	45.988360544217684	1.01	74	1086	4	9	9	8	0	-2	8	0	0	2.0	
i 1	46.00762585034013	0.2525	71	384	1	24	8	2	0	1	2	0	0	16.0	
i 1	46.01244217687075	1.01	74	700	5	2	2	8	0	-1	8	0	0	3.0	
i 1	46.25200680272109	1.5150000000000001	74	1086	1	20	8	2	0	-2	2	0	0	12.0	
i 1	46.26565306122449	1.7675	71	1086	1	20	9	8	0	1	8	0	0	12.0	
i 1	46.4819387755102	0.7575000000000001	72	1086	5	5	15	2	0	-2	2	0	0	2.0	
i 1	46.50762585034013	0.2525	74	1086	6	1	1	8	0	-1	8	0	0	2.0	
i 1	46.74076870748299	0.505	75	700	4	5	3	2	0	1	2	0	0	2.0	
i 1	46.75040136054422	0.505	72	384	3	5	8	2	0	1	2	0	0	2.0	
i 1	46.764047619047616	2.02	75	700	4	5	1	2	0	1	2	0	0	2.0	
i 1	46.98514965986394	0.2525	71	700	6	1	16	2	0	-2	2	0	0	2.0	
i 1	46.988360544217684	0.2525	74	384	4	4	3	8	0	-2	8	0	0	3.0	
i 1	46.99558503401361	0.2525	71	384	4	3	14	2	0	-2	2	0	0	3.0	
i 1	47.00762585034013	1.5150000000000001	74	1086	6	1	3	8	0	-2	8	0	0	2.0	
i 1	47.01725850340136	0.2525	71	700	4	4	4	8	0	-2	8	0	0	3.0	
i 1	47.23113605442177	1.5150000000000001	71	384	1	20	15	8	0	1	8	0	0	12.0	
i 1	47.23274149659864	0.2525	72	384	6	5	1	2	0	1	2	0	0	2.0	
i 1	47.238360544217684	1.2625	71	700	5	1	12	2	0	-2	2	0	0	2.0	
i 1	47.247190476190475	0.7575000000000001	71	700	6	2	1	2	0	-2	2	0	0	3.0	
i 1	47.24959863945578	0.7575000000000001	71	1086	4	9	4	2	0	-2	2	0	0	2.0	
i 1	47.25762585034013	1.5150000000000001	72	1086	3	5	9	2	0	-2	2	0	0	2.0	
i 1	47.25923129251701	6.565	61	700	4	14	11	16	0	2	16	0	0	2.250249158079288	
i 1	47.514047619047616	0.2525	72	1086	5	5	15	2	0	-2	2	0	0	2.0	
i 1	47.7319387755102	0.2525	71	700	2	20	4	2	0	-2	2	0	0	12.0	
i 1	47.74076870748299	1.01	74	700	5	3	4	2	0	-2	2	0	0	3.0	
i 1	47.75120408163265	0.2525	74	700	2	24	6	2	0	1	2	0	0	16.0	
i 1	47.752809523809525	1.01	71	384	4	3	10	2	0	-2	2	0	0	3.0	
i 1	47.76244217687075	3.2825	71	384	1	24	15	2	0	1	2	0	0	16.0	
i 1	47.76886394557823	0.2525	71	700	2	20	4	2	0	-2	2	0	0	12.0	
i 1	47.98514965986394	0.2525	74	700	6	2	16	8	0	-1	8	0	0	3.0	
i 1	47.985952380952384	0.7575000000000001	74	384	4	24	2	2	0	-2	2	0	0	3.0	
i 1	47.993979591836734	0.505	71	384	1	24	7	2	0	-2	2	0	0	16.0	
i 1	47.99558503401361	0.7575000000000001	74	700	4	24	1	2	0	-2	2	0	0	3.0	
i 1	48.00361224489796	0.505	71	384	1	20	7	2	0	1	2	0	0	12.0	
i 1	48.23434693877551	0.2525	74	384	4	4	15	8	0	-2	8	0	0	3.0	
i 1	48.25040136054422	1.5150000000000001	72	384	5	5	15	2	0	1	2	0	0	2.0	
i 1	48.25200680272109	1.5150000000000001	75	700	4	5	6	2	0	1	2	0	0	2.0	
i 1	48.26886394557823	0.2525	71	1086	1	20	13	8	0	1	8	0	0	12.0	
i 1	48.48274149659864	0.2525	71	700	2	20	8	8	0	1	8	0	0	12.0	
i 1	48.514047619047616	0.2525	71	700	2	20	1	2	0	-2	2	0	0	12.0	
i 1	48.738360544217684	0.505	71	1086	1	20	5	8	0	1	8	0	0	12.0	
i 1	48.74558503401361	0.2525	72	384	6	5	2	2	0	1	2	0	0	2.0	
i 1	48.74558503401361	0.505	74	384	1	20	13	8	0	1	8	0	0	12.0	
i 1	48.75040136054422	1.2625	74	1086	4	9	16	8	0	-2	8	0	0	2.0	
i 1	48.75521768707483	0.7575000000000001	71	700	5	1	3	8	0	-2	8	0	0	2.0	
i 1	48.7568231292517	0.7575000000000001	74	1086	6	1	14	8	0	-1	8	0	0	2.0	
i 1	48.75762585034013	0.2525	71	700	4	4	14	8	0	-2	8	0	0	3.0	
i 1	48.75923129251701	1.2625	74	700	6	2	15	8	0	-1	8	0	0	3.0	
i 1	48.760836734693875	0.505	74	1086	1	20	10	8	0	-2	8	0	0	12.0	
i 1	49.01003401360544	0.2525	72	1086	3	5	15	2	0	-2	2	0	0	2.0	
i 1	49.23514965986394	0.2525	71	384	1	20	14	8	0	1	8	0	0	12.0	
i 1	49.256020408163266	0.2525	74	700	5	3	3	2	0	-2	2	0	0	3.0	
i 1	49.25762585034013	0.2525	71	700	2	20	2	2	0	-2	2	0	0	12.0	
i 1	49.258428571428574	0.2525	71	700	2	20	4	8	0	-2	8	0	0	12.0	
i 1	49.488360544217684	1.01	74	384	4	4	12	8	0	-2	8	0	0	3.0	
i 1	49.49076870748299	0.2525	75	700	4	5	16	2	0	-2	2	0	0	2.0	
i 1	49.49237414965987	1.01	71	700	4	4	6	8	0	-2	8	0	0	3.0	
i 1	49.49237414965987	0.2525	72	1086	5	5	15	2	0	-2	2	0	0	2.0	
i 1	49.49638775510204	1.5150000000000001	71	384	1	20	16	2	0	1	2	0	0	12.0	
i 1	49.49799319727891	1.2625	74	384	6	1	4	2	0	-1	2	0	0	2.0	
i 1	49.49799319727891	1.5150000000000001	74	1086	1	20	10	8	0	1	8	0	0	12.0	
i 1	49.50040136054422	1.7675	75	700	4	5	13	2	0	1	2	0	0	2.0	
i 1	49.50762585034013	1.01	71	700	6	1	9	2	0	-2	2	0	0	2.0	
i 1	49.511639455782316	1.5150000000000001	71	1086	1	20	15	8	0	1	8	0	0	12.0	
i 1	49.516455782312924	2.02	72	384	6	5	11	2	0	1	2	0	0	2.0	
i 1	49.74076870748299	0.2525	74	384	4	24	2	2	0	-2	2	0	0	3.0	
i 1	49.993979591836734	0.2525	71	384	4	3	6	2	0	-2	2	0	0	3.0	
i 1	49.99478231292517	0.2525	74	1086	6	1	15	8	0	-1	8	0	0	2.0	
i 1	50.24558503401361	0.2525	74	700	5	3	3	2	0	-2	2	0	0	3.0	
i 1	50.489163265306125	1.5150000000000001	74	1086	6	1	7	8	0	-2	8	0	0	2.0	
i 1	50.50441496598639	1.5150000000000001	71	700	5	1	4	2	0	-2	2	0	0	2.0	
i 1	50.51003401360544	1.01	71	1086	4	9	7	2	0	-2	2	0	0	2.0	
i 1	50.510836734693875	1.01	71	700	6	2	13	2	0	-2	2	0	0	3.0	
i 1	50.74076870748299	0.2525	75	700	4	5	4	2	0	1	2	0	0	2.0	
i 1	50.75200680272109	0.505	71	384	1	20	15	8	0	1	8	0	0	12.0	
i 1	50.760836734693875	0.505	71	384	1	24	4	2	0	1	2	0	0	16.0	
i 1	50.98996598639456	1.7675	75	700	4	5	13	2	0	1	2	0	0	2.0	
i 1	51.002809523809525	0.2525	71	700	4	4	7	8	0	-2	8	0	0	3.0	
i 1	51.0180612244898	1.7675	72	1086	3	5	11	2	0	-2	2	0	0	2.0	
i 1	51.2319387755102	1.5150000000000001	71	384	1	20	8	2	0	1	2	0	0	12.0	
i 1	51.239163265306125	1.5150000000000001	74	1086	1	20	1	8	0	1	8	0	0	12.0	
i 1	51.247190476190475	1.01	74	700	6	2	1	8	0	-1	8	0	0	3.0	
i 1	51.247190476190475	2.525	71	1086	1	20	8	8	0	1	8	0	0	12.0	
i 1	51.252809523809525	0.2525	74	700	5	3	14	2	0	-2	2	0	0	3.0	
i 1	51.25361224489796	2.2725	74	700	4	24	12	2	0	-2	2	0	0	3.0	
i 1	51.25521768707483	1.01	74	1086	4	9	2	8	0	-2	8	0	0	2.0	
i 1	51.2680612244898	2.525	71	384	1	24	6	2	0	1	2	0	0	16.0	
i 1	51.269666666666666	0.505	71	384	4	3	9	2	0	-2	2	0	0	3.0	
i 1	51.480333333333334	0.7575000000000001	71	384	1	24	2	2	0	1	2	0	0	16.0	
i 1	51.5068231292517	2.02	74	384	4	24	11	2	0	-2	2	0	0	3.0	
i 1	51.519666666666666	0.7575000000000001	71	384	1	20	11	8	0	1	8	0	0	12.0	
i 1	51.752809523809525	0.2525	75	700	4	5	12	2	0	1	2	0	0	2.0	
i 1	51.76485034013606	1.5150000000000001	74	384	4	4	16	8	0	-2	8	0	0	3.0	
i 1	51.7680612244898	1.5150000000000001	71	700	4	4	3	8	0	-2	8	0	0	3.0	
i 1	51.985952380952384	0.2525	72	384	5	5	15	2	0	1	2	0	0	2.0	
i 1	52.00923129251701	0.2525	71	700	6	1	9	2	0	-2	2	0	0	2.0	
i 1	52.247190476190475	0.2525	71	384	4	3	3	2	0	-2	2	0	0	3.0	
i 1	52.261639455782316	0.2525	74	1086	6	1	15	8	0	-1	8	0	0	2.0	
i 1	52.485952380952384	1.2625	75	700	4	5	8	2	0	-2	2	0	0	2.0	
i 1	52.489163265306125	0.2525	75	700	4	5	13	2	0	1	2	0	0	2.0	
i 1	52.489163265306125	1.2625	72	1086	5	5	16	2	0	-2	2	0	0	2.0	
i 1	52.49478231292517	0.2525	71	700	6	2	8	2	0	-2	2	0	0	3.0	
i 1	52.50040136054422	0.2525	71	700	5	1	9	8	0	-2	8	0	0	2.0	
i 1	52.516455782312924	0.2525	72	384	5	5	8	2	0	1	2	0	0	2.0	
i 1	52.519666666666666	0.505	71	384	1	20	7	8	0	1	8	0	0	12.0	
i 1	52.73274149659864	0.2525	74	700	2	20	11	2	0	-2	2	0	0	12.0	
i 1	52.7431768707483	0.2525	71	700	2	20	11	2	0	-2	2	0	0	12.0	
i 1	52.980333333333334	0.7575000000000001	71	700	6	2	16	2	0	-2	2	0	0	3.0	
i 1	52.99558503401361	0.7575000000000001	71	1086	1	20	15	2	0	1	2	0	0	12.0	
i 1	53.01485034013606	0.7575000000000001	74	384	1	20	7	2	0	1	2	0	0	12.0	
i 1	53.01725850340136	0.2525	75	700	4	5	8	2	0	1	2	0	0	2.0	
i 1	53.019666666666666	0.7575000000000001	71	1086	4	9	11	2	0	-2	2	0	0	2.0	
i 1	53.247190476190475	0.2525	74	1086	4	9	4	8	0	-2	8	0	0	2.0	
i 1	53.25120408163265	0.505	71	700	5	1	14	8	0	-2	8	0	0	2.0	
i 1	53.25762585034013	0.505	74	1086	6	1	9	8	0	-1	8	0	0	2.0	
i 1	53.26725850340136	0.2525	75	700	4	5	6	2	0	1	2	0	0	2.0	
i 1	53.48434693877551	0.2525	74	384	4	4	9	8	0	-2	8	0	0	3.0	
i 1	53.48675510204082	0.505	74	700	5	3	16	2	0	-2	2	0	0	3.0	
i 1	53.516455782312924	0.2525	74	1086	6	1	1	8	0	-2	8	0	0	2.0	
i 1	53.516455782312924	0.2525	71	384	1	20	4	8	0	1	8	0	0	12.0	
i 1	53.7319387755102	1.01	71	202	4	4	8	8	0	-1	8	0	0	3.0	
i 1	53.73274149659864	0.2525	74	202	2	20	10	2	0	-2	2	0	0	12.0	
i 1	53.73434693877551	0.2525	61	904	5	14	5	16	0	2	16	0	0	2.250249158079288	
i 1	53.743979591836734	0.7575000000000001	74	202	7	1	12	2	0	-1	2	0	0	2.0	
i 1	53.74558503401361	0.2525	72	904	4	5	12	2	0	1	2	0	0	2.0	
i 1	53.74799319727891	0.505	72	904	4	5	5	8	0	-2	8	0	0	2.0	
i 1	53.74959863945578	4.04	71	202	1	20	11	2	0	-2	2	0	0	12.0	
i 1	53.75040136054422	20.705000000000002	61	904	4	14	8	1	0	2	1	0	0	2.250249158079288	
i 1	53.75361224489796	1.5150000000000001	74	202	1	20	16	8	0	1	8	0	0	12.0	
i 1	53.75521768707483	0.2525	75	202	6	5	2	2	0	1	2	0	0	2.0	
i 1	53.75923129251701	0.2525	71	202	1	24	1	2	0	1	2	0	0	16.0	
i 1	53.761639455782316	1.5150000000000001	71	202	7	1	16	2	0	-1	2	0	0	2.0	
i 1	53.76886394557823	0.2525	71	202	2	20	3	2	0	-2	2	0	0	12.0	
i 1	53.769666666666666	0.7575000000000001	74	904	5	1	1	2	0	-1	2	0	0	2.0	
i 1	53.769666666666666	0.2525	71	202	5	9	4	2	0	-1	2	0	0	2.0	
i 1	53.983544217687076	0.7575000000000001	74	700	5	3	15	2	0	-2	2	0	0	3.0	
i 1	53.98675510204082	0.2525	74	904	4	2	2	8	0	-2	8	0	0	3.0	
i 1	53.989163265306125	0.2525	74	202	2	24	7	2	0	1	2	0	0	16.0	
i 1	53.99237414965987	1.2625	74	700	4	24	6	2	0	-2	2	0	0	3.0	
i 1	54.00441496598639	27.27	61	904	4	14	15	16	0	2	16	0	0	2.250249158079288	
i 1	54.01324489795918	0.7575000000000001	72	904	5	5	10	2	0	1	2	0	0	2.0	
i 1	54.01886394557823	1.01	75	202	4	5	6	2	0	1	2	0	0	2.0	
i 1	54.23434693877551	1.01	71	202	2	20	7	2	0	-2	2	0	0	12.0	
i 1	54.256020408163266	1.2625	71	202	5	9	4	2	0	-1	2	0	0	2.0	
i 1	54.258428571428574	1.2625	71	202	1	24	2	2	0	1	2	0	0	16.0	
i 1	54.50521768707483	1.01	71	700	4	4	8	8	0	-2	8	0	0	3.0	
i 1	54.51003401360544	0.505	75	700	4	5	10	2	0	1	2	0	0	2.0	
i 1	54.51725850340136	0.505	72	202	5	5	10	2	0	1	2	0	0	2.0	
i 1	54.74478231292517	0.2525	71	904	6	2	11	8	0	-2	8	0	0	3.0	
i 1	54.75040136054422	1.5150000000000001	74	202	7	1	4	2	0	-1	2	0	0	2.0	
i 1	54.75441496598639	2.02	74	202	2	24	16	2	0	1	2	0	0	16.0	
i 1	54.76003401360544	0.505	74	202	1	24	4	2	0	1	2	0	0	16.0	
i 1	54.760836734693875	1.5150000000000001	74	904	5	1	12	2	0	-1	2	0	0	2.0	
i 1	54.985952380952384	0.7575000000000001	74	202	5	9	3	2	0	-1	2	0	0	2.0	
i 1	54.993979591836734	1.7675	72	904	4	5	1	8	0	-2	8	0	0	2.0	
i 1	54.997190476190475	1.01	74	904	4	2	2	8	0	-2	8	0	0	3.0	
i 1	55.00762585034013	1.7675	72	202	5	5	5	2	0	-2	2	0	0	2.0	
i 1	55.01003401360544	0.2525	75	700	4	5	15	2	0	1	2	0	0	2.0	
i 1	55.233544217687076	1.2625	71	202	4	4	3	8	0	-1	8	0	0	3.0	
i 1	55.23514965986394	0.2525	71	700	2	20	4	2	0	1	2	0	0	12.0	
i 1	55.25120408163265	0.2525	72	904	5	5	7	2	0	1	2	0	0	2.0	
i 1	55.2568231292517	0.2525	71	904	2	20	10	2	0	-2	2	0	0	12.0	
i 1	55.266455782312924	0.2525	71	700	5	1	11	2	0	-2	2	0	0	2.0	
i 1	55.266455782312924	1.5150000000000001	74	700	5	3	12	2	0	-2	2	0	0	3.0	
i 1	55.2680612244898	0.2525	71	700	2	24	8	2	0	-2	2	0	0	16.0	
i 1	55.4819387755102	1.01	74	202	1	24	15	2	0	-2	2	0	0	16.0	
i 1	55.48434693877551	1.01	74	202	1	20	10	2	0	1	2	0	0	12.0	
i 1	55.493979591836734	0.2525	71	904	5	1	12	8	0	-2	8	0	0	2.0	
i 1	55.73675510204082	0.2525	75	202	4	5	14	2	0	1	2	0	0	2.0	
i 1	55.74558503401361	2.02	71	700	5	1	15	2	0	-2	2	0	0	2.0	
i 1	55.76565306122449	1.7675	71	202	5	24	4	2	0	-2	2	0	0	3.0	
i 1	55.98274149659864	0.2525	71	700	4	4	12	8	0	-2	8	0	0	3.0	
i 1	55.99478231292517	0.2525	75	700	4	5	1	2	0	1	2	0	0	2.0	
i 1	56.238360544217684	0.2525	75	700	4	5	6	2	0	1	2	0	0	2.0	
i 1	56.25040136054422	1.2625	71	904	6	2	11	8	0	-2	8	0	0	3.0	
i 1	56.25361224489796	0.2525	71	202	7	1	16	2	0	-1	2	0	0	2.0	
i 1	56.2568231292517	1.2625	71	202	4	3	6	2	0	-2	2	0	0	3.0	
i 1	56.483544217687076	1.5150000000000001	75	202	4	5	12	2	0	1	2	0	0	2.0	
i 1	56.48996598639456	3.2825	74	202	2	20	2	2	0	-2	2	0	0	12.0	
i 1	56.491571428571426	1.5150000000000001	75	700	4	5	5	2	0	1	2	0	0	2.0	
i 1	56.49237414965987	0.2525	74	904	2	20	16	8	0	-2	8	0	0	12.0	
i 1	56.49959863945578	0.2525	71	202	6	1	10	8	0	-2	8	0	0	2.0	
i 1	56.49959863945578	0.2525	74	700	2	20	6	2	0	1	2	0	0	12.0	
i 1	56.50120408163265	0.2525	74	904	2	20	3	2	0	-2	2	0	0	12.0	
i 1	56.51244217687075	1.2625	71	202	1	24	6	2	0	1	2	0	0	16.0	
i 1	56.514047619047616	0.2525	74	700	2	24	16	2	0	1	2	0	0	16.0	
i 1	56.743979591836734	0.2525	75	202	4	5	13	2	0	1	2	0	0	2.0	
i 1	56.75361224489796	1.01	71	202	1	20	14	8	0	-2	8	0	0	12.0	
i 1	56.7568231292517	1.01	74	202	2	20	10	2	0	-2	2	0	0	12.0	
i 1	56.75762585034013	0.2525	71	202	4	4	14	8	0	-1	8	0	0	3.0	
i 1	56.76485034013606	0.2525	71	202	7	1	5	2	0	-1	2	0	0	2.0	
i 1	56.76485034013606	2.02	71	202	2	20	4	2	0	-2	2	0	0	12.0	
i 1	56.98113605442177	1.5150000000000001	71	700	4	4	3	8	0	-2	8	0	0	3.0	
i 1	56.985952380952384	1.5150000000000001	71	202	5	9	15	2	0	-1	2	0	0	2.0	
i 1	56.99558503401361	2.02	71	202	6	1	15	8	0	-2	8	0	0	2.0	
i 1	57.00040136054422	0.2525	75	700	4	5	12	2	0	1	2	0	0	2.0	
i 1	57.010836734693875	2.2725	71	904	5	1	5	8	0	-2	8	0	0	2.0	
i 1	57.23996598639456	1.7675	74	202	2	24	6	2	0	1	2	0	0	16.0	
i 1	57.26244217687075	1.5150000000000001	74	202	1	24	14	8	0	-2	8	0	0	16.0	
i 1	57.2680612244898	1.01	75	202	4	5	3	2	0	1	2	0	0	2.0	
i 1	57.4931768707483	0.7575000000000001	72	904	5	5	4	2	0	1	2	0	0	2.0	
i 1	57.502809523809525	0.2525	74	202	5	9	14	2	0	-1	2	0	0	2.0	
i 1	57.7431768707483	1.5150000000000001	74	904	4	2	4	8	0	-2	8	0	0	3.0	
i 1	57.743979591836734	0.2525	71	202	5	24	15	2	0	-2	2	0	0	3.0	
i 1	57.75441496598639	2.02	72	202	5	5	14	2	0	1	2	0	0	2.0	
i 1	57.761639455782316	2.02	75	700	4	5	11	2	0	1	2	0	0	2.0	
i 1	57.99959863945578	1.2625	74	202	5	9	1	2	0	-1	2	0	0	2.0	
i 1	58.01886394557823	0.2525	71	202	7	1	12	2	0	-1	2	0	0	2.0	
i 1	58.239163265306125	0.2525	75	202	4	5	9	2	0	1	2	0	0	2.0	
i 1	58.260836734693875	0.2525	74	202	7	1	5	2	0	-1	2	0	0	2.0	
i 1	58.49799319727891	1.7675	74	700	5	3	7	2	0	-2	2	0	0	3.0	
i 1	58.50120408163265	1.7675	74	700	4	24	1	2	0	-2	2	0	0	3.0	
i 1	58.50200680272109	0.2525	75	700	4	5	9	2	0	1	2	0	0	2.0	
i 1	58.50762585034013	2.02	71	202	1	24	1	2	0	1	2	0	0	16.0	
i 1	58.508428571428574	1.7675	71	202	7	1	11	2	0	-1	2	0	0	2.0	
i 1	58.514047619047616	2.2725	71	202	1	20	15	2	0	-2	2	0	0	12.0	
i 1	58.51886394557823	0.2525	71	202	1	20	10	8	0	-2	8	0	0	12.0	
i 1	58.73113605442177	0.2525	74	904	2	20	12	8	0	1	8	0	0	12.0	
i 1	58.741571428571426	0.2525	71	904	2	20	2	2	0	1	2	0	0	12.0	
i 1	58.74799319727891	1.5150000000000001	71	202	4	4	12	8	0	-1	8	0	0	3.0	
i 1	58.752809523809525	0.2525	71	700	2	20	15	2	0	-2	2	0	0	12.0	
i 1	58.76485034013606	0.2525	74	700	2	24	3	2	0	-2	2	0	0	16.0	
i 1	58.983544217687076	0.2525	75	700	4	5	4	2	0	1	2	0	0	2.0	
i 1	59.016455782312924	0.2525	74	202	2	20	6	8	0	-2	8	0	0	12.0	
i 1	59.23113605442177	0.2525	71	202	5	24	9	2	0	-2	2	0	0	3.0	
i 1	59.23996598639456	0.2525	71	202	4	3	7	2	0	-2	2	0	0	3.0	
i 1	59.241571428571426	0.2525	74	700	2	24	13	8	0	-2	8	0	0	16.0	
i 1	59.247190476190475	0.2525	71	904	2	20	5	2	0	-2	2	0	0	12.0	
i 1	59.25441496598639	1.5150000000000001	72	202	5	5	3	2	0	-2	2	0	0	2.0	
i 1	59.261639455782316	1.5150000000000001	74	202	2	24	14	2	0	1	2	0	0	16.0	
i 1	59.26725850340136	1.5150000000000001	72	904	4	5	11	8	0	-2	8	0	0	2.0	
i 1	59.269666666666666	0.2525	71	700	2	20	8	2	0	1	2	0	0	12.0	
i 1	59.49478231292517	1.2625	74	202	1	20	13	2	0	1	2	0	0	12.0	
i 1	59.502809523809525	1.2625	74	202	1	24	9	2	0	-2	2	0	0	16.0	
i 1	59.51565306122449	1.5150000000000001	71	202	5	9	2	2	0	-1	2	0	0	2.0	
i 1	59.51725850340136	0.2525	71	700	5	1	15	2	0	-2	2	0	0	2.0	
i 1	59.51725850340136	1.01	74	202	2	20	7	2	0	-2	2	0	0	12.0	
i 1	59.73434693877551	1.01	74	202	7	1	3	2	0	-1	2	0	0	2.0	
i 1	59.73514965986394	1.01	74	904	5	1	10	2	0	-1	2	0	0	2.0	
i 1	59.75361224489796	1.01	71	700	4	4	2	8	0	-2	8	0	0	3.0	
i 1	59.76886394557823	1.2625	75	700	4	5	15	2	0	1	2	0	0	2.0	
i 1	60.23675510204082	1.2625	71	700	5	1	3	2	0	-2	2	0	0	2.0	
i 1	60.23675510204082	2.02	74	202	5	9	7	2	0	-1	2	0	0	2.0	
i 1	60.24879591836735	0.7575000000000001	75	202	4	5	2	2	0	1	2	0	0	2.0	
i 1	60.25762585034013	1.2625	71	202	5	24	2	2	0	-2	2	0	0	3.0	
i 1	60.49959863945578	2.02	75	202	4	5	1	2	0	1	2	0	0	2.0	
i 1	60.50040136054422	2.2725	72	904	5	5	4	2	0	1	2	0	0	2.0	
i 1	60.50441496598639	1.5150000000000001	74	904	4	2	2	8	0	-2	8	0	0	3.0	
i 1	60.73274149659864	1.01	74	202	1	24	9	2	0	-2	2	0	0	8.0	
i 1	60.73755782312925	5.3025	71	202	1	20	16	2	0	-2	2	0	0	4.0	
i 1	60.74237414965987	1.01	74	202	2	24	4	2	0	1	2	0	0	8.0	
i 1	60.756020408163266	1.01	74	202	1	20	4	2	0	1	2	0	0	4.0	
i 1	60.758428571428574	0.2525	71	202	6	1	3	8	0	-2	8	0	0	2.0	
i 1	60.769666666666666	0.2525	71	700	4	4	4	8	0	-2	8	0	0	3.0	
i 1	60.98274149659864	0.2525	72	202	3	5	7	2	0	-2	2	0	0	2.0	
i 1	60.99558503401361	1.5150000000000001	74	904	5	1	3	2	0	-1	2	0	0	2.0	
i 1	60.997190476190475	2.02	71	202	4	4	2	8	0	-1	8	0	0	3.0	
i 1	61.01565306122449	1.5150000000000001	74	202	7	1	11	2	0	-1	2	0	0	2.0	
i 1	61.24076870748299	0.2525	72	202	5	5	15	2	0	1	2	0	0	2.0	
i 1	61.48675510204082	1.5150000000000001	74	700	5	3	8	2	0	-2	2	0	0	3.0	
i 1	61.51324489795918	1.7675	71	202	1	24	1	2	0	1	2	0	0	8.0	
i 1	61.516455782312924	0.2525	71	904	5	1	2	8	0	-2	8	0	0	2.0	
i 1	61.73675510204082	0.2525	75	202	4	5	13	2	0	1	2	0	0	2.0	
i 1	61.74076870748299	2.02	71	202	7	1	11	2	0	-1	2	0	0	2.0	
i 1	61.75521768707483	0.2525	74	904	2	20	2	2	0	1	2	0	0	4.0	
i 1	61.75521768707483	0.2525	71	700	2	20	12	8	0	-2	8	0	0	4.0	
i 1	61.98113605442177	0.7575000000000001	74	202	1	24	4	2	0	-2	2	0	0	8.0	
i 1	61.983544217687076	0.7575000000000001	74	202	2	24	13	2	0	1	2	0	0	8.0	
i 1	61.98434693877551	1.7675	75	700	4	5	14	2	0	1	2	0	0	2.0	
i 1	61.98675510204082	1.7675	74	700	4	24	2	2	0	-2	2	0	0	3.0	
i 1	62.00120408163265	1.7675	72	202	5	5	12	2	0	1	2	0	0	2.0	
i 1	62.00441496598639	0.7575000000000001	71	202	1	20	13	2	0	-2	2	0	0	4.0	
i 1	62.011639455782316	0.7575000000000001	71	202	2	20	4	2	0	1	2	0	0	4.0	
i 1	62.26485034013606	1.7675	71	202	4	3	1	2	0	-2	2	0	0	3.0	
i 1	62.49879591836735	0.2525	71	202	6	1	9	8	0	-2	8	0	0	2.0	
i 1	62.50521768707483	1.2625	71	904	4	2	7	8	0	-2	8	0	0	3.0	
i 1	62.741571428571426	1.2625	72	202	3	5	9	2	0	-2	2	0	0	2.0	
i 1	62.74237414965987	0.2525	71	904	2	20	13	2	0	1	2	0	0	4.0	
i 1	62.747190476190475	0.2525	74	700	2	20	7	2	0	1	2	0	0	4.0	
i 1	62.74879591836735	0.2525	71	202	5	24	1	2	0	-2	2	0	0	3.0	
i 1	62.9931768707483	1.2625	74	202	1	20	7	2	0	-2	2	0	0	4.0	
i 1	63.008428571428574	1.5150000000000001	71	202	5	9	16	2	0	-1	2	0	0	2.0	
i 1	63.01485034013606	0.2525	71	700	5	1	16	2	0	-2	2	0	0	2.0	
i 1	63.23274149659864	2.02	74	904	5	1	15	2	0	-1	2	0	0	2.0	
i 1	63.23274149659864	2.2725	74	202	7	1	9	2	0	-1	2	0	0	2.0	
i 1	63.23996598639456	0.2525	74	202	2	20	7	2	0	-2	2	0	0	4.0	
i 1	63.24799319727891	1.2625	71	700	4	4	5	8	0	-2	8	0	0	3.0	
i 1	63.26324489795918	0.7575000000000001	72	904	5	5	6	8	0	-2	8	0	0	2.0	
i 1	63.50120408163265	2.02	75	202	4	5	3	2	0	1	2	0	0	2.0	
i 1	63.50361224489796	1.2625	74	202	2	24	5	2	0	1	2	0	0	8.0	
i 1	63.510836734693875	0.7575000000000001	71	202	1	24	14	2	0	-2	2	0	0	8.0	
i 1	63.5180612244898	2.02	75	700	4	5	11	2	0	1	2	0	0	2.0	
i 1	63.76485034013606	0.2525	71	202	6	1	3	8	0	-2	8	0	0	2.0	
i 1	63.989163265306125	0.2525	71	202	5	24	13	2	0	-2	2	0	0	3.0	
i 1	63.989163265306125	0.2525	72	904	5	5	1	2	0	1	2	0	0	2.0	
i 1	63.98996598639456	1.01	74	904	4	2	13	8	0	-2	8	0	0	3.0	
i 1	64.00361224489797	0.7575000000000001	74	202	5	9	11	2	0	-1	2	0	0	2.0	
i 1	64.0180612244898	0.2525	74	202	2	20	6	2	0	-2	2	0	0	4.0	
i 1	64.23113605442177	0.7575000000000001	74	202	2	20	5	2	0	-2	2	0	0	4.0	
i 1	64.2319387755102	0.2525	71	700	2	24	3	8	0	1	8	0	0	8.0	
i 1	64.24157142857143	0.2525	75	202	4	5	3	2	0	1	2	0	0	2.0	
i 1	64.24157142857143	0.2525	74	904	2	20	8	2	0	1	2	0	0	4.0	
i 1	64.24397959183673	2.2725	71	202	4	4	13	8	0	-1	8	0	0	3.0	
i 1	64.25521768707483	2.2725	74	700	5	3	14	2	0	-2	2	0	0	3.0	
i 1	64.26003401360545	0.2525	74	700	2	20	9	2	0	-2	2	0	0	4.0	
i 1	64.48755782312925	0.2525	71	202	6	1	11	8	0	-2	8	0	0	2.0	
i 1	64.48996598639455	0.505	74	202	2	20	3	2	0	-2	2	0	0	4.0	
i 1	64.51645578231293	0.2525	74	202	1	24	1	2	0	1	2	0	0	8.0	
i 1	64.51966666666667	1.01	74	202	1	20	5	2	0	-2	2	0	0	4.0	
i 1	64.73514965986395	0.2525	72	904	5	5	11	8	0	-2	8	0	0	2.0	
i 1	64.7568231292517	1.7675	71	202	5	24	9	2	0	-2	2	0	0	3.0	
i 1	64.76725850340137	1.7675	71	700	5	1	9	2	0	-2	2	0	0	2.0	
i 1	64.98354421768707	1.5150000000000001	72	904	5	5	12	2	0	1	2	0	0	2.0	
i 1	64.98916326530612	0.505	74	202	1	24	1	2	0	1	2	0	0	8.0	
i 1	65.00120408163265	1.5150000000000001	75	202	4	5	2	2	0	1	2	0	0	2.0	
i 1	65.0044149659864	0.2525	74	202	5	9	8	2	0	-1	2	0	0	2.0	
i 1	65.24638775510203	0.2525	71	202	5	9	14	2	0	-1	2	0	0	2.0	
i 1	65.26083673469388	3.2825	71	202	1	24	5	2	0	1	2	0	0	8.0	
i 1	65.48113605442177	0.505	74	700	4	24	1	2	0	-2	2	0	0	3.0	
i 1	65.4955850340136	1.2625	72	202	5	5	13	2	0	1	2	0	0	2.0	
i 1	65.49638775510203	1.01	74	202	2	24	1	2	0	1	2	0	0	8.0	
i 1	65.50120408163265	1.2625	74	202	2	20	9	2	0	-2	2	0	0	4.0	
i 1	65.509231292517	0.2525	74	700	2	20	9	2	0	1	2	0	0	4.0	
i 1	65.51163945578232	0.2525	74	202	5	9	11	2	0	-1	2	0	0	2.0	
i 1	65.51645578231293	0.2525	71	700	2	24	3	2	0	1	2	0	0	8.0	
i 1	65.51966666666667	0.2525	74	904	2	20	8	8	0	-2	8	0	0	4.0	
i 1	65.7431768707483	0.2525	71	202	1	20	3	2	0	1	2	0	0	4.0	
i 1	65.74638775510203	0.2525	74	202	1	24	4	2	0	1	2	0	0	8.0	
i 1	65.76003401360545	1.7675	71	202	5	9	4	2	0	-1	2	0	0	2.0	
i 1	65.7680612244898	0.2525	71	202	2	20	2	2	0	1	2	0	0	4.0	
i 1	65.98675510204082	0.505	71	700	2	20	10	2	0	1	2	0	0	4.0	
i 1	65.98755782312925	1.01	71	904	5	1	2	8	0	-2	8	0	0	2.0	
i 1	65.98916326530612	0.505	74	904	2	20	2	8	0	-2	8	0	0	4.0	
i 1	65.99397959183673	1.5150000000000001	71	700	4	4	2	8	0	-2	8	0	0	3.0	
i 1	65.99397959183673	1.01	75	700	4	5	13	2	0	1	2	0	0	2.0	
i 1	65.99719047619048	1.01	71	202	6	1	12	8	0	-2	8	0	0	2.0	
i 1	65.99879591836735	0.505	74	904	2	20	14	2	0	1	2	0	0	4.0	
i 1	66.23274149659863	3.0300000000000002	71	202	1	20	13	2	0	-2	2	0	0	4.0	
i 1	66.24959863945578	2.02	72	904	5	5	13	8	0	-2	8	0	0	2.0	
i 1	66.26003401360545	2.02	72	202	3	5	10	2	0	-2	2	0	0	2.0	
i 1	66.48113605442177	0.505	74	202	1	20	10	2	0	-2	2	0	0	4.0	
i 1	66.48434693877552	0.2525	71	904	4	2	11	8	0	-2	8	0	0	3.0	
i 1	66.48514965986395	1.2625	74	700	4	24	11	2	0	-2	2	0	0	3.0	
i 1	66.48595238095238	0.2525	74	202	2	20	2	2	0	-2	2	0	0	4.0	
i 1	66.51725850340137	1.01	71	202	7	1	15	2	0	-1	2	0	0	2.0	
i 1	66.73836054421768	0.2525	74	700	5	3	7	2	0	-2	2	0	0	3.0	
i 1	66.9819387755102	0.505	74	904	4	2	12	8	0	-2	8	0	0	3.0	
i 1	66.98274149659863	0.2525	71	904	2	20	2	2	0	1	2	0	0	4.0	
i 1	67.00120408163265	1.7675	74	202	7	1	13	2	0	-1	2	0	0	2.0	
i 1	67.00842857142857	0.2525	75	700	4	5	16	2	0	1	2	0	0	2.0	
i 1	67.01003401360545	1.2625	74	202	5	9	13	2	0	-1	2	0	0	2.0	
i 1	67.01725850340137	0.2525	74	700	2	20	7	2	0	1	2	0	0	4.0	
i 1	67.23274149659863	0.7575000000000001	71	202	2	20	12	8	0	1	8	0	0	4.0	
i 1	67.23755782312925	0.7575000000000001	74	202	1	20	9	2	0	-2	2	0	0	4.0	
i 1	67.240768707483	1.5150000000000001	74	904	5	1	12	2	0	-1	2	0	0	2.0	
i 1	67.24157142857143	0.2525	75	202	4	5	12	2	0	1	2	0	0	2.0	
i 1	67.48354421768707	16.4125	61	700	4	7	15	16	0	2	16	0	0	1.5001661053861919	
i 1	67.48836054421768	0.7575000000000001	74	904	6	2	11	8	0	-2	8	0	0	3.0	
i 1	67.49959863945578	0.2525	71	202	6	9	7	2	0	-1	2	0	0	2.0	
i 1	67.50521768707483	2.02	75	700	4	5	9	2	0	1	2	0	0	2.0	
i 1	67.51163945578232	0.2525	71	202	5	1	10	2	0	-1	2	0	0	2.0	
i 1	67.73113605442177	1.7675	75	202	4	5	7	2	0	1	2	0	0	2.0	
i 1	67.7455850340136	2.2725	74	202	2	24	5	2	0	1	2	0	0	8.0	
i 1	67.75361224489797	1.2625	71	202	4	4	2	8	0	-1	8	0	0	3.0	
i 1	67.76003401360545	0.2525	71	202	2	20	1	2	0	1	2	0	0	4.0	
i 1	67.76324489795918	1.2625	74	700	4	3	1	2	0	-2	2	0	0	3.0	
i 1	67.76565306122448	0.2525	71	202	6	1	4	8	0	-2	8	0	0	2.0	
i 1	67.98113605442177	0.2525	74	904	2	20	3	2	0	-2	2	0	0	4.0	
i 1	67.98113605442177	0.2525	74	904	2	20	7	2	0	1	2	0	0	4.0	
i 1	67.98916326530612	0.2525	71	700	2	20	1	2	0	-2	2	0	0	4.0	
i 1	68.01404761904762	0.2525	71	202	5	1	6	2	0	-1	2	0	0	2.0	
i 1	68.23274149659863	0.2525	75	700	5	5	7	2	0	1	2	0	0	2.0	
i 1	68.24638775510203	2.02	71	700	5	1	3	2	0	-2	2	0	0	2.0	
i 1	68.24959863945578	1.7675	74	202	1	24	9	2	0	1	2	0	0	8.0	
i 1	68.259231292517	1.01	71	202	1	20	6	2	0	-2	2	0	0	4.0	
i 1	68.26003401360545	2.02	71	202	5	24	16	2	0	-2	2	0	0	3.0	
i 1	68.26083673469388	1.01	71	904	4	2	7	8	0	-2	8	0	0	3.0	
i 1	68.490768707483	0.7575000000000001	71	202	4	3	2	2	0	-2	2	0	0	3.0	
i 1	68.49157142857143	1.5150000000000001	71	700	4	4	14	8	0	-2	8	0	0	3.0	
i 1	68.49638775510203	1.5150000000000001	75	202	4	5	14	2	0	1	2	0	0	2.0	
i 1	68.50040136054422	1.7675	71	202	6	9	1	2	0	-1	2	0	0	2.0	
i 1	68.73595238095238	0.2525	71	202	5	1	16	2	0	-1	2	0	0	2.0	
i 1	68.73755782312925	3.2825	74	202	2	20	14	2	0	-2	2	0	0	4.0	
i 1	68.74397959183673	2.7775	74	202	2	20	16	8	0	1	8	0	0	4.0	
i 1	68.76003401360545	1.2625	72	904	5	5	8	2	0	1	2	0	0	2.0	
i 1	69.01404761904762	0.2525	74	202	7	1	2	2	0	-1	2	0	0	2.0	
i 1	69.23274149659863	2.02	75	700	5	5	10	2	0	1	2	0	0	2.0	
i 1	69.23836054421768	0.2525	71	202	4	4	12	8	0	-1	8	0	0	3.0	
i 1	69.24638775510203	4.2925	74	904	5	1	13	2	0	-1	2	0	0	2.0	
i 1	69.26244217687075	2.02	72	202	3	5	7	2	0	1	2	0	0	2.0	
i 1	69.26565306122448	0.2525	74	700	4	3	7	2	0	-2	2	0	0	3.0	
i 1	69.48514965986395	2.02	71	202	1	20	9	2	0	-2	2	0	0	4.0	
i 1	69.4931768707483	2.2725	74	202	7	1	15	2	0	-1	2	0	0	2.0	
i 1	69.49719047619048	3.2825	71	202	1	20	1	2	0	-2	2	0	0	4.0	
i 1	69.49799319727892	1.5150000000000001	74	202	5	9	7	2	0	-1	2	0	0	2.0	
i 1	69.50521768707483	1.5150000000000001	74	904	6	2	9	8	0	-2	8	0	0	3.0	
i 1	70.00120408163265	2.525	72	904	5	5	11	8	0	-2	8	0	0	2.0	
i 1	70.00521768707483	0.505	71	202	4	3	14	2	0	-2	2	0	0	3.0	
i 1	70.01163945578232	0.2525	72	202	3	5	9	2	0	-2	2	0	0	2.0	
i 1	70.2455850340136	0.2525	71	904	4	2	11	8	0	-2	8	0	0	3.0	
i 1	70.24879591836735	0.2525	71	904	5	1	3	8	0	-2	8	0	0	2.0	
i 1	70.26083673469388	0.2525	75	202	4	5	1	2	0	1	2	0	0	2.0	
i 1	70.48033333333333	2.525	71	202	5	1	16	2	0	-1	2	0	0	2.0	
i 1	70.50120408163265	4.2925	71	202	4	4	13	8	0	-1	8	0	0	3.0	
i 1	70.51324489795918	2.02	72	202	3	5	11	2	0	-2	2	0	0	2.0	
i 1	70.51404761904762	4.2925	74	700	4	3	10	2	0	-2	2	0	0	3.0	
i 1	70.73836054421768	2.2725	74	700	4	24	9	2	0	-2	2	0	0	3.0	
i 1	71.0068231292517	0.505	71	202	4	3	8	2	0	-2	2	0	0	3.0	
i 1	71.01966666666667	4.7975	71	202	1	24	7	2	0	1	2	0	0	8.0	
i 1	71.259231292517	0.2525	75	700	4	5	16	2	0	1	2	0	0	2.0	
i 1	71.49638775510203	0.2525	72	202	3	5	15	2	0	1	2	0	0	2.0	
i 1	71.49799319727892	0.2525	74	700	2	24	15	8	0	1	8	0	0	8.0	
i 1	71.50200680272108	0.2525	74	904	6	2	3	8	0	-2	8	0	0	3.0	
i 1	71.50280952380952	0.2525	74	700	2	20	2	2	0	-2	2	0	0	4.0	
i 1	71.50762585034013	0.2525	72	904	5	5	7	2	0	1	2	0	0	2.0	
i 1	71.50842857142857	0.2525	71	904	2	20	3	8	0	-2	8	0	0	4.0	
i 1	71.51324489795918	2.2725	74	202	2	24	9	2	0	1	2	0	0	8.0	
i 1	71.73916326530612	1.5150000000000001	71	202	1	24	3	2	0	1	2	0	0	8.0	
i 1	71.740768707483	0.2525	74	202	5	9	11	2	0	-1	2	0	0	2.0	
i 1	71.74157142857143	0.2525	71	202	2	20	2	8	0	-2	8	0	0	4.0	
i 1	71.74478231292517	1.5150000000000001	74	202	2	20	1	2	0	1	2	0	0	4.0	
i 1	71.74719047619048	0.2525	71	202	4	3	5	2	0	-2	2	0	0	3.0	
i 1	71.75602040816327	1.5150000000000001	71	202	1	20	6	2	0	-2	2	0	0	4.0	
i 1	71.76083673469388	1.01	75	700	4	5	16	2	0	1	2	0	0	2.0	
i 1	71.76244217687075	1.2625	75	202	4	5	1	2	0	1	2	0	0	2.0	
i 1	71.99397959183673	1.5150000000000001	71	202	6	9	16	2	0	-1	2	0	0	2.0	
i 1	72.00200680272108	2.2725	72	904	5	5	2	2	0	1	2	0	0	2.0	
i 1	72.00280952380952	2.525	75	202	4	5	5	2	0	1	2	0	0	2.0	
i 1	72.01725850340137	1.5150000000000001	71	700	4	4	6	8	0	-2	8	0	0	3.0	
i 1	72.0180612244898	1.5150000000000001	74	202	7	1	12	2	0	-1	2	0	0	2.0	
i 1	72.50361224489797	1.7675	71	700	5	1	7	2	0	-2	2	0	0	2.0	
i 1	72.509231292517	1.7675	71	202	5	24	5	2	0	-2	2	0	0	3.0	
i 1	72.74237414965987	1.01	74	202	5	9	9	2	0	-1	2	0	0	2.0	
i 1	72.74397959183673	1.2625	74	202	2	20	16	2	0	-2	2	0	0	4.0	
i 1	72.75280952380952	0.7575000000000001	72	904	5	5	3	8	0	-2	8	0	0	2.0	
i 1	72.76645578231293	1.01	74	904	6	2	15	8	0	-2	8	0	0	3.0	
i 1	72.98514965986395	21.715	71	202	1	20	16	2	0	-2	2	0	0	4.0	
i 1	73.01244217687075	0.2525	75	700	4	5	4	2	0	1	2	0	0	2.0	
i 1	73.23916326530612	2.02	71	202	6	1	16	8	0	-2	8	0	0	2.0	
i 1	73.2431768707483	0.2525	71	700	2	20	4	2	0	-2	2	0	0	4.0	
i 1	73.24478231292517	0.2525	74	700	2	24	8	2	0	-2	2	0	0	8.0	
i 1	73.25521768707483	2.2725	75	700	5	5	7	2	0	1	2	0	0	2.0	
i 1	73.26083673469388	0.2525	74	904	2	20	1	2	0	-2	2	0	0	4.0	
i 1	73.26485034013605	2.02	71	904	5	1	16	8	0	-2	8	0	0	2.0	
i 1	73.48434693877552	0.2525	74	202	1	24	11	2	0	1	2	0	0	8.0	
i 1	73.49157142857143	0.505	74	202	2	20	8	8	0	1	8	0	0	4.0	
i 1	73.51485034013605	1.01	74	202	1	20	9	2	0	-2	2	0	0	4.0	
i 1	73.51886394557823	2.02	72	202	3	5	8	2	0	1	2	0	0	2.0	
i 1	73.73434693877552	0.2525	71	700	4	4	5	8	0	-2	8	0	0	3.0	
i 1	73.75040136054422	2.02	71	202	4	3	6	2	0	-2	2	0	0	3.0	
i 1	73.98354421768707	0.505	74	202	1	24	1	2	0	1	2	0	0	8.0	
i 1	74.01163945578232	0.2525	71	904	4	2	5	8	0	-2	8	0	0	3.0	
i 1	74.23354421768707	2.2725	74	700	4	24	3	2	0	-2	2	0	0	3.0	
i 1	74.23434693877552	1.5150000000000001	71	904	6	2	3	8	0	-2	8	0	0	3.0	
i 1	74.24478231292517	3.0300000000000002	74	202	2	24	9	2	0	1	2	0	0	8.0	
i 1	74.24879591836735	0.2525	74	202	2	20	14	8	0	1	8	0	0	4.0	
i 1	74.25280952380952	23.735	61	904	3	14	5	1	0	2	1	0	0	2.250249158079288	
i 1	74.26485034013605	2.2725	71	202	5	1	16	2	0	-1	2	0	0	2.0	
i 1	74.48274149659863	1.5150000000000001	72	202	3	5	11	2	0	-2	2	0	0	2.0	
i 1	74.48434693877552	0.2525	71	700	2	24	8	2	0	-2	2	0	0	8.0	
i 1	74.4931768707483	0.2525	71	700	2	20	8	2	0	1	2	0	0	4.0	
i 1	74.50120408163265	0.2525	74	904	2	20	15	2	0	-2	2	0	0	4.0	
i 1	74.5044149659864	1.2625	74	202	2	20	1	2	0	-2	2	0	0	4.0	
i 1	74.50521768707483	1.2625	72	904	5	5	7	8	0	-2	8	0	0	2.0	
i 1	74.73916326530612	2.02	71	202	6	9	4	2	0	-1	2	0	0	2.0	
i 1	74.7431768707483	2.525	75	700	5	5	4	2	0	1	2	0	0	2.0	
i 1	74.7431768707483	0.2525	71	202	1	20	6	2	0	1	2	0	0	4.0	
i 1	74.75521768707483	2.525	75	202	4	5	6	2	0	1	2	0	0	2.0	
i 1	74.75842857142857	2.02	71	700	4	4	11	8	0	-2	8	0	0	3.0	
i 1	74.99638775510203	0.2525	74	700	2	24	10	2	0	1	2	0	0	8.0	
i 1	74.99799319727892	0.2525	71	904	2	20	12	2	0	1	2	0	0	4.0	
i 1	75.00200680272108	0.2525	71	700	2	20	15	2	0	1	2	0	0	4.0	
i 1	75.23434693877552	0.505	71	202	2	20	7	2	0	1	2	0	0	4.0	
i 1	75.23675510204082	0.2525	71	700	5	1	9	2	0	-2	2	0	0	2.0	
i 1	75.25280952380952	1.5150000000000001	71	202	1	24	8	2	0	-2	2	0	0	8.0	
i 1	75.25842857142857	1.5150000000000001	74	202	1	20	8	8	0	1	8	0	0	4.0	
i 1	75.26645578231293	2.7775	74	904	5	1	15	2	0	-1	2	0	0	2.0	
i 1	75.49157142857143	2.525	74	202	5	1	8	2	0	-1	2	0	0	2.0	
i 1	75.75120408163265	1.7675	74	202	6	9	15	2	0	-1	2	0	0	2.0	
i 1	75.75120408163265	0.505	75	700	5	5	8	2	0	1	2	0	0	2.0	
i 1	75.76244217687075	1.7675	74	904	6	2	9	8	0	-2	8	0	0	3.0	
i 1	76.00200680272108	0.2525	72	904	5	5	15	8	0	-2	8	0	0	2.0	
i 1	76.23675510204082	2.02	75	202	4	5	11	2	0	1	2	0	0	2.0	
i 1	76.23996598639455	2.02	72	904	5	5	8	2	0	1	2	0	0	2.0	
i 1	76.26003401360545	1.5150000000000001	71	202	1	24	10	2	0	1	2	0	0	8.0	
i 1	76.48113605442177	2.02	71	202	4	4	12	8	0	-1	8	0	0	3.0	
i 1	76.48354421768707	0.505	71	904	5	1	8	8	0	-2	8	0	0	2.0	
i 1	76.48514965986395	2.02	74	700	4	3	11	2	0	-2	2	0	0	3.0	
i 1	76.51163945578232	0.2525	71	202	6	1	5	8	0	-2	8	0	0	2.0	
i 1	76.73434693877552	0.505	71	700	2	20	3	2	0	-2	2	0	0	4.0	
i 1	76.74157142857143	0.505	74	700	2	24	16	8	0	-2	8	0	0	8.0	
i 1	76.74397959183673	1.7675	74	202	2	20	10	2	0	-2	2	0	0	4.0	
i 1	76.75120408163265	2.525	71	700	5	1	2	2	0	-2	2	0	0	2.0	
i 1	76.76404761904762	0.505	74	904	2	20	9	2	0	1	2	0	0	4.0	
i 1	76.99638775510203	2.2725	71	202	5	24	3	2	0	-2	2	0	0	3.0	
i 1	77.23916326530612	1.2625	75	700	5	5	1	2	0	1	2	0	0	2.0	
i 1	77.23996598639455	0.505	74	202	1	24	1	2	0	-2	2	0	0	8.0	
i 1	77.2455850340136	1.2625	72	202	3	5	3	2	0	1	2	0	0	2.0	
i 1	77.24638775510203	2.02	71	202	1	20	16	8	0	1	8	0	0	4.0	
i 1	77.24959863945578	1.2625	71	202	2	20	9	2	0	-2	2	0	0	4.0	
i 1	77.48434693877552	1.7675	71	202	6	9	15	2	0	-1	2	0	0	2.0	
i 1	77.4955850340136	1.7675	71	700	4	4	8	8	0	-2	8	0	0	3.0	
i 1	77.49799319727892	2.7775	72	202	3	5	2	2	0	-2	2	0	0	2.0	
i 1	77.51565306122448	2.525	72	904	5	5	3	8	0	-2	8	0	0	2.0	
i 1	78.00842857142857	0.2525	71	904	5	1	1	8	0	-2	8	0	0	2.0	
i 1	78.009231292517	0.2525	71	202	5	1	15	2	0	-1	2	0	0	2.0	
i 1	78.23113605442177	1.5150000000000001	74	202	2	24	2	2	0	1	2	0	0	8.0	
i 1	78.23755782312925	1.01	74	202	1	24	1	2	0	-2	2	0	0	8.0	
i 1	78.24237414965987	2.02	74	904	6	2	11	8	0	-2	8	0	0	3.0	
i 1	78.26324489795918	2.02	74	202	6	9	3	2	0	-1	2	0	0	2.0	
i 1	78.2680612244898	3.2825	74	202	5	1	4	2	0	-1	2	0	0	2.0	
i 1	78.26966666666667	2.7775	74	904	5	1	12	2	0	-1	2	0	0	2.0	
i 1	78.49478231292517	0.2525	75	700	5	5	15	2	0	1	2	0	0	2.0	
i 1	78.51485034013605	0.2525	72	904	5	5	7	2	0	1	2	0	0	2.0	
i 1	78.73033333333333	1.7675	71	202	5	1	9	2	0	-1	2	0	0	2.0	
i 1	78.73274149659863	7.575	71	202	1	24	12	2	0	1	2	0	0	8.0	
i 1	78.74959863945578	2.2725	75	202	4	5	15	2	0	1	2	0	0	2.0	
i 1	78.76485034013605	0.2525	72	202	3	5	12	2	0	1	2	0	0	2.0	
i 1	78.76725850340137	2.02	74	700	4	24	16	2	0	-2	2	0	0	3.0	
i 1	78.99237414965987	2.02	74	202	2	20	3	2	0	-2	2	0	0	4.0	
i 1	78.99397959183673	2.02	75	700	5	5	5	2	0	1	2	0	0	2.0	
i 1	79.01003401360545	0.2525	71	202	2	20	15	2	0	-2	2	0	0	4.0	
i 1	79.23434693877552	1.7675	74	700	4	3	2	2	0	-2	2	0	0	3.0	
i 1	79.23916326530612	0.2525	74	904	2	20	9	2	0	1	2	0	0	4.0	
i 1	79.2455850340136	0.2525	74	700	2	20	5	2	0	-2	2	0	0	4.0	
i 1	79.25842857142857	2.02	71	202	4	4	12	8	0	-1	8	0	0	3.0	
i 1	79.26966666666667	0.2525	71	700	2	24	8	8	0	-2	8	0	0	8.0	
i 1	79.48514965986395	1.5150000000000001	71	202	2	20	14	2	0	1	2	0	0	4.0	
i 1	79.48916326530612	0.505	74	202	1	24	1	2	0	1	2	0	0	8.0	
i 1	79.49478231292517	2.2725	74	202	1	20	2	8	0	1	8	0	0	4.0	
i 1	79.7544149659864	2.02	71	202	2	20	8	2	0	-2	2	0	0	4.0	
i 1	79.9931768707483	0.2525	72	202	3	5	13	2	0	1	2	0	0	2.0	
i 1	80.23113605442177	1.2625	75	202	4	5	16	2	0	1	2	0	0	2.0	
i 1	80.2319387755102	1.7675	71	904	6	2	5	8	0	-2	8	0	0	3.0	
i 1	80.25762585034013	0.7575000000000001	71	202	4	3	6	2	0	-2	2	0	0	3.0	
i 1	80.26485034013605	0.7575000000000001	72	904	5	5	10	2	0	1	2	0	0	2.0	
i 1	80.48354421768707	2.525	72	202	3	5	2	2	0	1	2	0	0	2.0	
i 1	80.5068231292517	3.2825	75	700	5	5	4	2	0	1	2	0	0	2.0	
i 1	80.51966666666667	2.02	71	700	5	1	13	2	0	-2	2	0	0	2.0	
i 1	80.73033333333333	1.7675	71	202	5	24	6	2	0	-2	2	0	0	3.0	
i 1	80.74719047619048	1.01	74	202	1	24	15	2	0	1	2	0	0	8.0	
i 1	80.76083673469388	1.2625	74	202	2	24	12	2	0	1	2	0	0	8.0	
i 1	80.98354421768707	0.505	74	904	4	1	10	2	0	-1	2	0	0	2.0	
i 1	80.98675510204082	0.2525	74	904	6	2	7	8	0	-2	8	0	0	3.0	
i 1	81.00120408163265	16.9175	61	904	3	14	8	16	0	2	16	0	0	2.250249158079288	
i 1	81.00602040816327	1.01	72	904	6	5	3	2	0	1	2	0	0	2.0	
i 1	81.00762585034013	1.01	71	202	6	3	11	2	0	-2	2	0	0	3.0	
i 1	81.23996598639455	1.5150000000000001	71	202	4	9	6	2	0	-1	2	0	0	2.0	
i 1	81.24397959183673	1.5150000000000001	71	700	4	4	3	8	0	-2	8	0	0	3.0	
i 1	81.48033333333333	0.2525	75	700	5	5	14	2	0	1	2	0	0	2.0	
i 1	81.509231292517	0.2525	71	202	4	1	1	8	0	-2	8	0	0	2.0	
i 1	81.73916326530612	0.505	74	700	2	24	16	2	0	1	2	0	0	8.0	
i 1	81.74237414965987	1.2625	74	904	6	2	3	8	0	-2	8	0	0	3.0	
i 1	81.74478231292517	0.505	71	700	2	20	14	2	0	-2	2	0	0	4.0	
i 1	81.76244217687075	0.2525	71	202	5	1	5	2	0	-1	2	0	0	2.0	
i 1	81.76645578231293	2.2725	72	904	5	5	1	8	0	-2	8	0	0	2.0	
i 1	81.76645578231293	0.2525	71	904	2	20	9	2	0	1	2	0	0	4.0	
i 1	81.76966666666667	1.2625	74	202	6	9	10	2	0	-1	2	0	0	2.0	
i 1	81.98113605442177	1.7675	74	700	5	3	11	2	0	-2	2	0	0	3.0	
i 1	81.98434693877552	2.02	71	202	4	4	12	8	0	-1	8	0	0	3.0	
i 1	81.98514965986395	0.2525	74	904	2	20	7	2	0	1	2	0	0	4.0	
i 1	81.98595238095238	3.7875	72	202	3	5	10	2	0	-2	2	0	0	2.0	
i 1	81.98916326530612	2.2725	71	904	5	1	14	8	0	-2	8	0	0	2.0	
i 1	81.99959863945578	2.2725	71	202	4	1	9	8	0	-2	8	0	0	2.0	
i 1	82.00200680272108	1.5150000000000001	74	202	2	20	1	2	0	-2	2	0	0	4.0	
i 1	82.2544149659864	1.2625	71	202	2	20	13	2	0	1	2	0	0	4.0	
i 1	82.25521768707483	2.525	71	202	1	20	2	2	0	1	2	0	0	4.0	
i 1	82.26244217687075	0.505	71	202	1	24	2	2	0	-2	2	0	0	8.0	
i 1	82.48354421768707	1.01	71	202	2	20	4	2	0	-2	2	0	0	4.0	
i 1	82.51404761904762	0.505	74	700	4	24	1	2	0	-2	2	0	0	3.0	
i 1	82.99719047619048	0.2525	71	700	5	1	16	2	0	-2	2	0	0	2.0	
i 1	83.00521768707483	0.505	71	202	5	24	8	2	0	-2	2	0	0	3.0	
i 1	83.01003401360545	0.2525	72	904	6	5	13	2	0	1	2	0	0	2.0	
i 1	83.01244217687075	0.2525	71	700	4	4	9	8	0	-2	8	0	0	3.0	
i 1	83.0180612244898	0.2525	71	202	6	3	14	2	0	-2	2	0	0	3.0	
i 1	83.23514965986395	1.7675	74	904	6	2	14	8	0	-2	8	0	0	3.0	
i 1	83.23916326530612	0.505	75	700	5	5	2	2	0	1	2	0	0	2.0	
i 1	83.2544149659864	0.2525	74	700	4	24	4	2	0	-2	2	0	0	3.0	
i 1	83.26244217687075	1.2625	75	202	5	5	15	2	0	1	2	0	0	2.0	
i 1	83.2680612244898	1.7675	71	202	4	9	7	2	0	-1	2	0	0	2.0	
i 1	83.48113605442177	3.0300000000000002	74	904	4	1	8	2	0	-1	2	0	0	2.0	
i 1	83.5044149659864	3.0300000000000002	71	202	5	1	1	2	0	-1	2	0	0	2.0	
i 1	83.7455850340136	0.2525	74	588	5	3	12	2	0	-1	2	0	0	3.0	
i 1	83.74879591836735	1.01	71	202	1	24	13	2	0	-2	2	0	0	8.0	
i 1	83.7544149659864	1.01	71	202	2	20	13	2	0	-2	2	0	0	4.0	
i 1	83.76163945578232	0.2525	75	588	5	5	5	2	0	-2	2	0	0	2.0	
i 1	83.76485034013605	10.8575	61	588	4	7	4	1	0	1	1	0	0	1.5001661053861919	
i 1	83.76565306122448	1.7675	74	202	2	24	1	2	0	1	2	0	0	8.0	
i 1	83.76966666666667	2.02	72	588	5	5	6	2	0	-2	2	0	0	2.0	
i 1	83.98033333333333	0.2525	71	904	6	2	12	8	0	-2	8	0	0	3.0	
i 1	84.01163945578232	0.2525	75	202	4	5	2	2	0	1	2	0	0	2.0	
i 1	84.01324489795918	0.2525	74	202	6	9	1	2	0	-1	2	0	0	2.0	
i 1	84.23836054421768	0.2525	71	588	4	4	6	8	0	-2	8	0	0	3.0	
i 1	84.259231292517	0.2525	71	588	4	24	9	2	0	-1	2	0	0	3.0	
i 1	84.26645578231293	0.505	71	202	2	20	15	2	0	1	2	0	0	4.0	
i 1	84.4931768707483	0.2525	71	202	5	24	8	2	0	-2	2	0	0	3.0	
i 1	84.4931768707483	3.0300000000000002	75	202	4	5	4	2	0	1	2	0	0	2.0	
i 1	84.49719047619048	0.2525	72	904	6	5	16	2	0	1	2	0	0	2.0	
i 1	84.49959863945578	1.5150000000000001	74	588	5	3	7	2	0	-1	2	0	0	3.0	
i 1	84.50120408163265	1.5150000000000001	71	202	6	3	14	2	0	-2	2	0	0	3.0	
i 1	84.509231292517	2.02	74	202	2	20	2	2	0	-2	2	0	0	4.0	
i 1	84.51966666666667	1.5150000000000001	71	588	5	1	10	8	0	-2	8	0	0	2.0	
i 1	84.73595238095238	1.01	71	202	4	1	8	8	0	-2	8	0	0	2.0	
i 1	84.74237414965987	0.2525	71	588	2	20	7	8	0	-2	8	0	0	4.0	
i 1	84.75040136054422	2.2725	72	904	5	5	9	8	0	-2	8	0	0	2.0	
i 1	84.75521768707483	0.2525	71	904	2	20	15	2	0	1	2	0	0	4.0	
i 1	84.76404761904762	0.2525	71	904	2	20	15	2	0	-2	2	0	0	4.0	
i 1	84.76725850340137	0.2525	74	588	2	24	13	2	0	1	2	0	0	8.0	
i 1	84.99397959183673	1.2625	71	202	2	20	2	2	0	-2	2	0	0	4.0	
i 1	84.9955850340136	1.7675	71	904	6	2	5	8	0	-2	8	0	0	3.0	
i 1	84.99719047619048	2.2725	71	202	1	20	7	8	0	1	8	0	0	4.0	
i 1	85.01645578231293	0.2525	74	202	1	24	1	2	0	-2	2	0	0	8.0	
i 1	85.01966666666667	1.2625	74	202	2	20	11	2	0	-2	2	0	0	4.0	
i 1	85.240768707483	1.5150000000000001	74	202	6	9	4	2	0	-1	2	0	0	2.0	
i 1	85.74638775510203	1.01	71	588	4	4	3	8	0	-2	8	0	0	3.0	
i 1	85.76244217687075	1.01	71	202	4	4	2	8	0	-1	8	0	0	3.0	
i 1	85.7680612244898	0.2525	75	588	5	5	10	2	0	-2	2	0	0	2.0	
i 1	86.00040136054422	1.5150000000000001	71	588	4	24	4	2	0	-1	2	0	0	3.0	
i 1	86.00280952380952	1.01	72	202	3	5	6	2	0	1	2	0	0	2.0	
i 1	86.00521768707483	1.7675	71	202	5	24	14	2	0	-2	2	0	0	3.0	
i 1	86.23755782312925	1.2625	71	202	4	9	2	2	0	-1	2	0	0	2.0	
i 1	86.24638775510203	1.2625	74	904	6	2	1	8	0	-2	8	0	0	3.0	
i 1	86.2544149659864	2.2725	72	904	6	5	11	2	0	1	2	0	0	2.0	
i 1	86.26244217687075	2.2725	75	202	5	5	11	2	0	1	2	0	0	2.0	
i 1	86.26324489795918	0.7575000000000001	75	588	5	5	4	2	0	-2	2	0	0	2.0	
i 1	86.5180612244898	0.2525	71	588	5	1	5	8	0	-2	8	0	0	2.0	
i 1	86.5180612244898	0.2525	74	202	1	24	14	2	0	-2	2	0	0	8.0	
i 1	86.73354421768707	0.2525	71	202	4	1	14	8	0	-2	8	0	0	2.0	
i 1	86.73996598639455	2.02	74	202	2	20	2	2	0	-2	2	0	0	4.0	
i 1	86.740768707483	2.7775	71	202	6	3	14	2	0	-2	2	0	0	3.0	
i 1	86.75280952380952	1.01	71	202	1	24	3	2	0	1	2	0	0	8.0	
i 1	86.75762585034013	0.2525	71	904	5	1	7	8	0	-2	8	0	0	2.0	
i 1	86.76083673469388	0.505	74	202	2	20	13	2	0	-2	2	0	0	4.0	
i 1	86.76163945578232	0.505	71	202	2	20	7	2	0	-2	2	0	0	4.0	
i 1	86.98755782312925	1.7675	71	202	5	1	3	2	0	-1	2	0	0	2.0	
i 1	86.99478231292517	2.525	74	588	5	3	15	2	0	-1	2	0	0	3.0	
i 1	87.00602040816327	3.0300000000000002	74	202	2	24	3	2	0	1	2	0	0	8.0	
i 1	87.01404761904762	2.02	74	904	4	1	14	2	0	-1	2	0	0	2.0	
i 1	87.23514965986395	0.2525	74	904	2	20	12	2	0	-2	2	0	0	4.0	
i 1	87.23996598639455	0.2525	74	588	2	20	1	2	0	1	2	0	0	4.0	
i 1	87.24478231292517	0.2525	74	904	2	20	9	2	0	-2	2	0	0	4.0	
i 1	87.48996598639455	0.2525	72	202	3	5	2	2	0	1	2	0	0	2.0	
i 1	87.49719047619048	0.2525	71	202	2	20	13	2	0	1	2	0	0	4.0	
i 1	87.49799319727892	0.2525	71	202	4	4	6	8	0	-1	8	0	0	3.0	
i 1	87.50842857142857	0.505	71	202	1	20	10	8	0	1	8	0	0	4.0	
i 1	87.509231292517	0.2525	71	904	5	1	9	8	0	-2	8	0	0	2.0	
i 1	87.73434693877552	0.2525	71	588	4	24	7	2	0	-1	2	0	0	3.0	
i 1	87.73916326530612	0.2525	75	202	5	5	7	2	0	1	2	0	0	2.0	
i 1	87.74237414965987	0.2525	71	588	4	4	4	8	0	-2	8	0	0	3.0	
i 1	87.76163945578232	0.2525	71	588	5	1	16	8	0	-2	8	0	0	2.0	
i 1	87.9819387755102	1.5150000000000001	72	588	5	5	12	2	0	-2	2	0	0	2.0	
i 1	87.98755782312925	0.2525	71	904	4	1	6	8	0	-2	8	0	0	2.0	
i 1	87.9955850340136	0.2525	74	588	2	20	11	2	0	-2	2	0	0	4.0	
i 1	88.0068231292517	0.2525	74	588	2	24	3	8	0	-2	8	0	0	8.0	
i 1	88.01083673469388	1.5150000000000001	72	202	3	5	12	2	0	-2	2	0	0	2.0	
i 1	88.01404761904762	0.2525	74	904	3	20	8	2	0	-2	2	0	0	4.0	
i 1	88.0180612244898	0.2525	71	904	2	20	5	2	0	1	2	0	0	4.0	
i 1	88.0180612244898	0.7575000000000001	71	202	1	24	4	2	0	1	2	0	0	8.0	
i 1	88.23434693877552	2.02	71	588	5	1	2	8	0	-2	8	0	0	2.0	
i 1	88.23996598639455	0.505	74	202	2	20	8	2	0	-2	2	0	0	4.0	
i 1	88.240768707483	2.2725	71	202	4	1	5	8	0	-2	8	0	0	2.0	
i 1	88.24719047619048	0.7575000000000001	71	202	3	20	3	8	0	1	8	0	0	4.0	
i 1	88.26324489795918	0.7575000000000001	71	202	1	20	1	8	0	1	8	0	0	4.0	
i 1	88.26886394557823	0.7575000000000001	74	202	1	24	4	2	0	1	2	0	0	8.0	
i 1	88.51485034013605	0.2525	75	588	5	5	13	2	0	-2	2	0	0	2.0	
i 1	88.73916326530612	0.2525	71	904	4	1	16	8	0	-2	8	0	0	2.0	
i 1	88.75200680272108	0.2525	72	904	6	5	5	2	0	1	2	0	0	2.0	
i 1	88.75602040816327	0.2525	74	202	4	9	1	2	0	-1	2	0	0	2.0	
i 1	88.9819387755102	0.7575000000000001	75	202	5	5	1	2	0	1	2	0	0	2.0	
i 1	88.98675510204082	1.2625	71	588	4	4	3	8	0	-2	8	0	0	3.0	
i 1	88.990768707483	0.7575000000000001	74	904	3	20	16	2	0	-2	2	0	0	4.0	
i 1	88.99638775510203	1.5150000000000001	71	202	5	4	14	8	0	-1	8	0	0	3.0	
i 1	89.00602040816327	0.7575000000000001	71	588	2	24	13	2	0	1	2	0	0	8.0	
i 1	89.0068231292517	0.7575000000000001	72	904	6	5	1	8	0	-2	8	0	0	2.0	
i 1	89.009231292517	0.2525	71	202	4	24	13	2	0	-2	2	0	0	3.0	
i 1	89.01645578231293	0.2525	71	588	2	20	15	8	0	-2	8	0	0	4.0	
i 1	89.23274149659863	2.2725	71	904	4	1	4	8	0	-2	8	0	0	2.0	
i 1	89.23434693877552	3.2825	75	202	5	5	7	2	0	1	2	0	0	2.0	
i 1	89.25762585034013	3.2825	72	904	6	5	2	2	0	1	2	0	0	2.0	
i 1	89.4819387755102	3.0300000000000002	74	202	2	20	2	2	0	-2	2	0	0	4.0	
i 1	89.50521768707483	0.2525	71	588	2	20	16	8	0	-2	8	0	0	4.0	
i 1	89.51966666666667	1.5150000000000001	71	202	4	9	7	2	0	-1	2	0	0	2.0	
i 1	89.73274149659863	3.0300000000000002	71	202	1	20	7	8	0	1	8	0	0	4.0	
i 1	89.740768707483	1.7675	74	202	5	1	6	2	0	-1	2	0	0	2.0	
i 1	89.74397959183673	2.7775	71	202	3	20	8	2	0	1	2	0	0	4.0	
i 1	89.75200680272108	0.2525	72	588	5	5	2	2	0	-2	2	0	0	2.0	
i 1	89.76083673469388	1.2625	74	904	6	2	15	8	0	-2	8	0	0	3.0	
i 1	89.76324489795918	0.2525	71	202	1	24	16	2	0	1	2	0	0	8.0	
i 1	89.98755782312925	0.2525	75	202	5	5	11	2	0	1	2	0	0	2.0	
i 1	90.01485034013605	0.2525	72	202	3	5	9	2	0	1	2	0	0	2.0	
i 1	90.23595238095238	0.505	75	588	5	5	6	2	0	-2	2	0	0	2.0	
i 1	90.24959863945578	0.2525	72	904	6	5	13	8	0	-2	8	0	0	2.0	
i 1	90.26645578231293	0.2525	74	904	4	1	13	2	0	-1	2	0	0	2.0	
i 1	90.48996598639455	0.505	71	202	6	3	3	2	0	-2	2	0	0	3.0	
i 1	90.50200680272108	0.505	74	588	5	3	9	2	0	-1	2	0	0	3.0	
i 1	90.50602040816327	0.505	71	588	5	1	13	8	0	-2	8	0	0	2.0	
i 1	90.73595238095238	1.5150000000000001	74	202	4	9	14	2	0	-1	2	0	0	2.0	
i 1	90.74237414965987	1.2625	71	904	6	2	9	8	0	-2	8	0	0	3.0	
i 1	90.76645578231293	0.2525	72	588	5	5	6	2	0	-2	2	0	0	2.0	
i 1	90.98434693877552	1.01	71	202	4	24	8	2	0	-2	2	0	0	3.0	
i 1	90.99799319727892	0.2525	72	904	6	5	14	8	0	-2	8	0	0	2.0	
i 1	91.00120408163265	1.5150000000000001	74	202	2	20	1	2	0	1	2	0	0	4.0	
i 1	91.0068231292517	0.2525	71	202	5	4	14	8	0	-1	8	0	0	3.0	
i 1	91.00842857142857	1.01	71	588	4	24	11	2	0	-1	2	0	0	3.0	
i 1	91.01244217687075	1.5150000000000001	71	202	1	24	8	2	0	1	2	0	0	8.0	
i 1	91.25602040816327	0.2525	74	588	5	3	16	2	0	-1	2	0	0	3.0	
i 1	91.48354421768707	0.2525	71	202	4	9	6	2	0	-1	2	0	0	2.0	
i 1	91.48434693877552	1.2625	71	202	5	1	2	2	0	-1	2	0	0	2.0	
i 1	91.50040136054422	1.2625	74	904	4	1	13	2	0	-1	2	0	0	2.0	
i 1	91.50842857142857	0.2525	72	588	5	5	13	2	0	-2	2	0	0	2.0	
i 1	91.73595238095238	1.2625	71	202	5	4	2	8	0	-1	8	0	0	3.0	
i 1	91.740768707483	1.2625	72	202	3	5	4	2	0	-2	2	0	0	2.0	
i 1	91.75361224489797	1.2625	71	588	4	4	16	8	0	-2	8	0	0	3.0	
i 1	91.99478231292517	1.7675	71	588	5	1	13	8	0	-2	8	0	0	2.0	
i 1	92.00361224489797	0.7575000000000001	71	202	1	24	8	2	0	1	2	0	0	8.0	
i 1	92.0044149659864	0.7575000000000001	74	202	2	24	3	2	0	1	2	0	0	8.0	
i 1	92.00842857142857	0.7575000000000001	72	588	5	5	7	2	0	-2	2	0	0	2.0	
i 1	92.23996598639455	1.5150000000000001	71	202	4	1	9	8	0	-2	8	0	0	2.0	
i 1	92.24799319727892	0.2525	71	904	6	2	7	8	0	-2	8	0	0	3.0	
i 1	92.25361224489797	2.02	72	904	6	5	5	8	0	-2	8	0	0	2.0	
i 1	92.26083673469388	2.02	75	202	5	5	11	2	0	1	2	0	0	2.0	
i 1	92.48434693877552	1.5150000000000001	71	202	4	9	15	2	0	-1	2	0	0	2.0	
i 1	92.49157142857143	1.5150000000000001	74	904	6	2	5	8	0	-2	8	0	0	3.0	
i 1	92.74237414965987	0.2525	74	202	5	1	14	2	0	-1	2	0	0	2.0	
i 1	92.76725850340137	0.2525	74	588	2	24	15	2	0	1	2	0	0	8.0	
i 1	92.98113605442177	0.7575000000000001	74	202	1	24	15	2	0	-2	2	0	0	8.0	
i 1	92.98595238095238	2.02	74	904	4	1	14	2	0	-1	2	0	0	2.0	
i 1	92.98996598639455	2.02	74	202	2	24	5	2	0	1	2	0	0	8.0	
i 1	92.99959863945578	0.505	75	202	5	5	8	2	0	1	2	0	0	2.0	
i 1	93.00521768707483	0.2525	71	904	6	2	7	8	0	-2	8	0	0	3.0	
i 1	93.00521768707483	0.7575000000000001	74	202	1	20	16	8	0	-2	8	0	0	4.0	
i 1	93.25200680272108	1.7675	71	202	5	1	4	2	0	-1	2	0	0	2.0	
i 1	93.259231292517	0.2525	71	588	4	4	3	8	0	-2	8	0	0	3.0	
i 1	93.48675510204082	1.01	71	202	6	3	10	2	0	-2	2	0	0	3.0	
i 1	93.490768707483	0.2525	72	588	5	5	9	2	0	-2	2	0	0	2.0	
i 1	93.50280952380952	2.7775	71	202	1	24	1	2	0	1	2	0	0	8.0	
i 1	93.51083673469388	2.525	74	588	5	3	6	2	0	-1	2	0	0	3.0	
i 1	93.73274149659863	0.2525	74	588	2	24	6	8	0	-2	8	0	0	8.0	
i 1	93.73514965986395	0.7575000000000001	74	202	2	20	7	2	0	-2	2	0	0	4.0	
i 1	93.73675510204082	1.5150000000000001	72	202	3	5	5	2	0	1	2	0	0	2.0	
i 1	93.73675510204082	0.2525	74	904	3	20	12	2	0	1	2	0	0	4.0	
i 1	93.74719047619048	1.5150000000000001	75	588	5	5	5	2	0	-2	2	0	0	2.0	
i 1	93.74719047619048	0.2525	74	588	2	20	13	2	0	1	2	0	0	4.0	
i 1	93.75842857142857	0.2525	71	588	4	24	7	2	0	-1	2	0	0	3.0	
i 1	93.9819387755102	0.2525	74	202	1	20	7	8	0	1	8	0	0	4.0	
i 1	93.98595238095238	0.2525	71	588	4	4	5	8	0	-2	8	0	0	3.0	
i 1	93.98836054421768	0.2525	71	202	4	1	14	8	0	-2	8	0	0	2.0	
i 1	93.99799319727892	0.2525	71	202	3	20	7	2	0	1	2	0	0	4.0	
i 1	93.99959863945578	0.2525	74	202	1	24	2	8	0	-2	8	0	0	8.0	
i 1	94.2319387755102	0.2525	74	904	6	2	1	8	0	-2	8	0	0	3.0	
i 1	94.23354421768707	0.2525	71	904	4	1	9	8	0	-2	8	0	0	2.0	
i 1	94.25521768707483	0.505	71	904	3	20	10	2	0	-2	2	0	0	4.0	
i 1	94.25602040816327	0.505	74	588	2	20	12	2	0	1	2	0	0	4.0	
i 1	94.48113605442177	2.02	71	202	4	24	8	2	0	-2	2	0	0	3.0	
i 1	94.4819387755102	1.01	71	202	3	3	14	2	0	-2	2	0	0	3.0	
i 1	94.48354421768707	3.2825	61	588	4	7	15	1	0	1	1	0	0	1.5001661053861919	
i 1	94.49478231292517	0.2525	72	202	4	5	11	2	0	-2	2	0	0	2.0	
i 1	94.50361224489797	2.02	71	588	4	24	10	2	0	-1	2	0	0	3.0	
i 1	94.73274149659863	1.5150000000000001	74	202	3	20	2	2	0	1	2	0	0	4.0	
i 1	94.73675510204082	0.2525	74	202	1	20	9	8	0	-2	8	0	0	4.0	
i 1	94.73836054421768	1.5150000000000001	71	202	3	20	13	2	0	1	2	0	0	4.0	
i 1	94.74397959183673	0.505	75	202	5	5	7	2	0	1	2	0	0	2.0	
i 1	94.74799319727892	1.5150000000000001	74	202	2	20	8	2	0	-2	2	0	0	4.0	
i 1	94.75040136054422	0.2525	71	904	6	2	13	8	0	-2	8	0	0	3.0	
i 1	94.75200680272108	0.7575000000000001	72	904	6	5	3	2	0	1	2	0	0	2.0	
i 1	94.99237414965987	0.2525	74	202	5	1	10	2	0	-1	2	0	0	2.0	
i 1	94.99879591836735	1.7675	72	588	6	5	10	2	0	-2	2	0	0	2.0	
i 1	95.0068231292517	0.505	71	588	4	4	3	8	0	-2	8	0	0	3.0	
i 1	95.01244217687075	1.7675	72	202	4	5	15	2	0	-2	2	0	0	2.0	
i 1	95.01725850340137	0.505	71	202	5	4	11	8	0	-1	8	0	0	3.0	
i 1	95.23514965986395	1.01	71	202	6	9	14	2	0	-1	2	0	0	2.0	
i 1	95.24879591836735	1.2625	74	904	6	2	3	8	0	-2	8	0	0	3.0	
i 1	95.50521768707483	0.2525	74	904	4	1	10	2	0	-1	2	0	0	2.0	
i 1	95.73675510204082	0.7575000000000001	74	202	1	20	1	8	0	-2	8	0	0	4.0	
i 1	95.7455850340136	2.02	71	202	1	20	5	2	0	-2	2	0	0	4.0	
i 1	95.74799319727892	0.2525	75	588	5	5	12	2	0	-2	2	0	0	2.0	
i 1	95.74959863945578	0.2525	74	202	5	1	9	2	0	-1	2	0	0	2.0	
i 1	96.0044149659864	1.5150000000000001	74	904	4	1	4	2	0	-1	2	0	0	2.0	
i 1	96.01645578231293	1.5150000000000001	71	202	5	1	3	2	0	-1	2	0	0	2.0	
i 1	96.24799319727892	1.01	74	588	5	3	15	2	0	-1	2	0	0	3.0	
i 1	96.26485034013605	1.01	71	202	3	3	13	2	0	-2	2	0	0	3.0	
i 1	96.48274149659863	0.505	71	904	3	20	10	2	0	1	2	0	0	4.0	
i 1	96.50602040816327	0.505	74	588	2	20	3	2	0	-2	2	0	0	4.0	
i 1	96.509231292517	1.5150000000000001	74	202	2	24	12	2	0	1	2	0	0	8.0	
i 1	96.51966666666667	1.2625	71	202	1	24	10	2	0	1	2	0	0	8.0	
i 1	96.73033333333333	0.2525	72	904	6	5	11	2	0	1	2	0	0	2.0	
i 1	96.74719047619048	1.2625	75	202	5	5	16	2	0	1	2	0	0	2.0	
i 1	96.7544149659864	0.2525	71	202	6	9	13	2	0	-1	2	0	0	2.0	
i 1	96.75842857142857	1.01	72	904	6	5	13	8	0	-2	8	0	0	2.0	
i 1	96.76324489795918	4.7975	74	202	2	20	9	2	0	-2	2	0	0	4.0	
i 1	96.98916326530612	0.2525	71	202	1	20	8	2	0	-2	2	0	0	4.0	
i 1	96.99237414965987	0.2525	71	202	3	20	10	2	0	1	2	0	0	4.0	
i 1	97.01645578231293	0.2525	71	202	5	4	7	8	0	-1	8	0	0	3.0	
i 1	97.23274149659863	0.505	71	588	4	1	16	8	0	-2	8	0	0	2.0	
i 1	97.23595238095238	0.505	71	202	4	1	15	8	0	-2	8	0	0	2.0	
i 1	97.240768707483	0.505	74	904	6	2	3	8	0	-2	8	0	0	3.0	
i 1	97.24478231292517	1.5150000000000001	74	202	4	9	15	2	0	-1	2	0	0	2.0	
i 1	97.24959863945578	0.505	71	904	6	2	15	8	0	-2	8	0	0	3.0	
i 1	97.2544149659864	0.505	74	904	3	20	5	2	0	-2	2	0	0	4.0	
i 1	97.26725850340137	0.2525	75	588	5	5	14	2	0	-2	2	0	0	2.0	
i 1	97.26886394557823	0.505	71	588	2	20	14	2	0	1	2	0	0	4.0	
i 1	97.49237414965987	0.2525	74	202	5	1	16	2	0	-1	2	0	0	2.0	
i 1	97.5044149659864	0.2525	72	202	4	5	5	2	0	-2	2	0	0	2.0	
i 1	97.73113605442177	0.505	75	1086	6	5	4	2	0	-2	2	0	0	2.0	
i 1	97.73274149659863	0.7575000000000001	71	202	5	1	5	2	0	-1	2	0	0	2.0	
i 1	97.73274149659863	2.7775	75	700	3	5	9	2	0	1	2	0	0	2.0	
i 1	97.73354421768707	3.535	61	1086	3	14	12	1	0	2	1	0	0	2.250249158079288	
i 1	97.73514965986395	0.2525	75	1086	6	5	10	8	0	-2	8	0	0	2.0	
i 1	97.73595238095238	1.01	74	1086	6	2	1	2	0	-2	2	0	0	3.0	
i 1	97.73755782312925	0.7575000000000001	74	700	4	24	9	2	0	-2	2	0	0	3.0	
i 1	97.74397959183673	3.2825	74	700	1	20	16	2	0	1	2	0	0	4.0	
i 1	97.74799319727892	3.2825	71	700	1	20	7	2	0	1	2	0	0	4.0	
i 1	97.74799319727892	1.5150000000000001	63	700	4	7	3	16	0	2	16	0	0	1.5001661053861919	
i 1	97.74879591836735	1.5150000000000001	75	700	6	5	12	2	0	1	2	0	0	2.0	
i 1	97.7544149659864	0.2525	74	700	1	24	8	2	0	1	2	0	0	8.0	
i 1	97.76324489795918	3.535	74	202	3	20	10	2	0	1	2	0	0	4.0	
i 1	97.76645578231293	3.535	61	1086	3	14	8	16	0	2	16	0	0	2.250249158079288	
i 1	97.98595238095238	0.2525	71	700	4	4	7	8	0	-1	8	0	0	3.0	
i 1	98.23595238095238	0.2525	72	700	5	5	4	8	0	-2	8	0	0	2.0	
i 1	98.48514965986395	0.7575000000000001	74	202	5	1	3	2	0	-1	2	0	0	2.0	
i 1	98.49719047619048	1.7675	71	1086	4	1	9	8	0	-2	8	0	0	2.0	
i 1	98.51163945578232	1.01	71	700	4	4	5	8	0	-1	8	0	0	3.0	
i 1	98.51565306122448	0.7575000000000001	74	700	5	3	11	2	0	-2	2	0	0	3.0	
i 1	98.51886394557823	0.505	75	202	5	5	8	2	0	1	2	0	0	2.0	
i 1	98.73836054421768	0.2525	74	1086	4	1	14	2	0	-2	2	0	0	2.0	
i 1	99.23113605442177	2.02	63	588	4	7	16	1	0	1	1	0	0	1.5001661053861919	
i 1	99.23354421768707	1.01	71	202	5	1	14	2	0	-1	2	0	0	2.0	
i 1	99.23916326530612	1.01	75	588	5	5	10	8	0	-2	8	0	0	2.0	
i 1	99.2455850340136	0.2525	75	588	6	5	8	2	0	-2	2	0	0	2.0	
i 1	99.25200680272108	0.505	74	588	4	4	6	2	0	-1	2	0	0	3.0	
i 1	99.25762585034013	0.2525	74	1086	6	2	10	2	0	-1	2	0	0	3.0	
i 1	99.26966666666667	0.2525	71	700	4	24	8	2	0	-1	2	0	0	3.0	
i 1	99.48033333333333	0.7575000000000001	74	1086	6	2	1	2	0	-2	2	0	0	3.0	
i 1	99.51003401360545	0.2525	75	1086	6	5	14	8	0	-2	8	0	0	2.0	
i 1	99.51404761904762	0.7575000000000001	71	202	6	9	3	2	0	-1	2	0	0	2.0	
i 1	99.98595238095238	0.505	75	202	5	5	16	2	0	1	2	0	0	2.0	
i 1	99.98916326530612	0.7575000000000001	75	1086	6	5	3	2	0	-2	2	0	0	2.0	
i 1	100.23675510204082	1.01	71	700	4	24	11	2	0	-1	2	0	0	3.0	
i 1	100.25602040816327	1.01	74	588	4	24	16	8	0	-1	8	0	0	3.0	
i 1	100.26083673469388	1.2625	74	700	3	3	14	8	0	-2	8	0	0	3.0	
i 1	100.26163945578232	1.2625	74	588	5	3	1	2	0	-2	2	0	0	3.0	
i 1	100.48434693877552	0.7575000000000001	75	588	6	5	12	2	0	-2	2	0	0	2.0	
i 1	100.48595238095238	0.7575000000000001	72	700	4	5	3	2	0	-2	2	0	0	2.0	
i 1	100.7319387755102	0.7575000000000001	74	202	2	24	10	2	0	1	2	0	0	8.0	
i 1	100.73836054421768	0.2525	71	202	5	1	2	2	0	-1	2	0	0	2.0	
i 1	100.74157142857143	0.2525	75	202	5	5	12	2	0	1	2	0	0	2.0	
i 1	100.76565306122448	0.505	74	700	1	24	10	2	0	-2	2	0	0	8.0	
i 1	100.99719047619048	0.2525	75	1086	6	5	16	2	0	-2	2	0	0	2.0	
i 1	101.00842857142857	0.2525	74	202	5	1	4	2	0	-1	2	0	0	2.0	
i 1	101.23113605442177	6.8175	63	202	5	16	11	1	0	2	1	0	0	3.094852019400723	
i 1	101.23354421768707	0.7575000000000001	72	700	4	5	5	2	0	-2	2	0	0	2.1662443531096365	
i 1	101.23595238095238	0.2525	74	588	3	20	14	2	0	1	2	0	0	4.0	
i 1	101.23595238095238	6.0600000000000005	63	588	4	7	13	1	0	1	1	0	0	2.180033569360793	
i 1	101.23675510204082	0.2525	71	588	2	24	10	8	0	1	8	0	0	8.0	
i 1	101.23755782312925	0.505	71	700	4	24	12	2	0	-1	2	0	0	3.0438274789689523	
i 1	101.23916326530612	6.3125	61	1086	5	14	10	1	0	2	1	0	0	4.270502321028533	
i 1	101.23916326530612	6.0600000000000005	63	588	5	15	9	1	0	2	1	0	0	1.9192017177729124	
i 1	101.240768707483	0.2525	74	700	1	24	5	2	0	1	2	0	0	8.0	
i 1	101.24157142857143	0.505	74	588	4	24	5	8	0	-1	8	0	0	3.0438274789689523	
i 1	101.24237414965987	6.3125	63	700	3	27	12	1	0	2	1	0	0	12.051504796183696	
i 1	101.24879591836735	6.8175	63	202	5	26	3	16	0	2	16	0	0	10.329861253871739	
i 1	101.24959863945578	0.7575000000000001	75	588	6	5	2	2	0	-2	2	0	0	2.1662443531096365	
i 1	101.25040136054422	1.01	74	1086	6	2	14	2	0	-1	2	0	0	3.0	
i 1	101.25200680272108	6.3125	61	700	3	27	1	1	0	1	1	0	0	12.051504796183696	
i 1	101.25280952380952	1.01	74	202	6	9	11	2	0	-1	2	0	0	2.0	
i 1	101.25361224489797	6.0600000000000005	61	588	3	13	1	16	0	1	16	0	0	0.6798674639746006	
i 1	101.25602040816327	6.3125	61	1086	5	13	6	1	0	2	1	0	0	0.743551416145102	
i 1	101.25602040816327	6.8175	63	202	5	16	13	1	0	1	1	0	0	3.094852019400723	
i 1	101.2568231292517	0.2525	71	1086	3	20	6	2	0	1	2	0	0	4.0	
i 1	101.25762585034013	6.3125	61	1086	3	14	12	16	0	2	16	0	0	2.930116622053889	
i 1	101.25842857142857	1.2625	74	700	1	20	1	2	0	1	2	0	0	4.0	
i 1	101.26645578231293	6.3125	61	1086	3	14	10	1	0	2	1	0	0	2.930116622053889	
i 1	101.26725850340137	6.0600000000000005	61	588	5	15	13	16	0	1	16	0	0	1.9192017177729124	
i 1	101.48836054421768	1.01	74	700	2	20	5	2	0	1	2	0	0	4.0	
i 1	101.73916326530612	1.2625	71	202	5	1	11	2	0	-1	2	0	0	2.0438274789689523	
i 1	101.75280952380952	1.2625	71	1086	4	1	9	8	0	-2	8	0	0	2.0438274789689523	
i 1	101.99397959183673	1.2625	75	202	5	5	12	2	0	1	2	0	0	2.1662443531096365	
i 1	102.00762585034013	1.2625	75	1086	6	5	11	8	0	-2	8	0	0	2.1662443531096365	
i 1	102.259231292517	1.5150000000000001	74	1086	6	2	12	2	0	-2	2	0	0	3.0	
i 1	102.26966666666667	1.5150000000000001	71	202	6	9	5	2	0	-1	2	0	0	2.0	
i 1	102.48755782312925	0.505	71	1086	3	20	6	2	0	1	2	0	0	4.0	
i 1	102.49879591836735	1.01	74	202	2	24	4	2	0	1	2	0	0	8.0	
i 1	102.5068231292517	0.505	74	700	1	24	16	2	0	1	2	0	0	8.0	
i 1	102.51404761904762	0.505	74	588	3	20	5	2	0	1	2	0	0	4.0	
i 1	102.98755782312925	0.505	74	700	1	24	6	8	0	-2	8	0	0	8.0	
i 1	102.98836054421768	1.2625	74	700	4	1	4	8	0	-1	8	0	0	2.0438274789689523	
i 1	102.99879591836735	0.505	74	202	2	20	14	2	0	-2	2	0	0	4.0	
i 1	103.00361224489797	1.2625	74	588	4	1	14	8	0	-2	8	0	0	2.0438274789689523	
i 1	103.00361224489797	0.505	71	202	3	20	13	2	0	-2	2	0	0	4.0	
i 1	103.24959863945578	1.7675	75	202	5	5	13	2	0	1	2	0	0	2.1662443531096365	
i 1	103.25762585034013	1.7675	75	1086	6	5	1	2	0	-2	2	0	0	2.1662443531096365	
i 1	103.48354421768707	0.2525	71	588	2	24	1	2	0	-2	2	0	0	8.0	
i 1	103.49959863945578	0.2525	74	700	1	24	12	2	0	1	2	0	0	8.0	
i 1	103.51725850340137	0.2525	71	588	3	20	6	2	0	1	2	0	0	4.0	
i 1	103.51725850340137	2.525	74	700	1	20	8	2	0	1	2	0	0	4.0	
i 1	103.73033333333333	1.01	74	588	5	3	2	2	0	-2	2	0	0	3.0	
i 1	103.73113605442177	2.2725	71	700	2	20	7	2	0	1	2	0	0	4.0	
i 1	103.76404761904762	1.01	74	700	3	3	9	8	0	-2	8	0	0	3.0	
i 1	103.99799319727892	2.02	74	202	3	20	4	2	0	-2	2	0	0	4.0	
i 1	104.00762585034013	2.02	74	202	2	20	1	2	0	-2	2	0	0	4.0	
i 1	104.26645578231293	1.01	71	700	4	24	3	2	0	-1	2	0	0	3.0438274789689523	
i 1	104.26725850340137	1.01	74	588	4	24	6	8	0	-1	8	0	0	3.0438274789689523	
i 1	104.740768707483	1.01	71	700	3	4	10	8	0	-1	8	0	0	3.0	
i 1	104.76886394557823	1.01	74	588	4	4	12	2	0	-1	2	0	0	3.0	
i 1	104.9819387755102	1.01	72	700	4	5	4	2	0	-2	2	0	0	2.1662443531096365	
i 1	105.00762585034013	1.01	75	588	6	5	12	2	0	-2	2	0	0	2.1662443531096365	
i 1	105.25842857142857	1.01	71	202	5	1	8	2	0	-1	2	0	0	2.0438274789689523	
i 1	105.26886394557823	1.01	71	1086	4	1	15	8	0	-2	8	0	0	2.0438274789689523	
i 1	105.73514965986395	1.01	74	1086	6	2	1	2	0	-2	2	0	0	3.0	
i 1	105.73595238095238	1.01	71	202	6	9	14	2	0	-1	2	0	0	2.0	
i 1	105.98996598639455	0.2525	74	588	3	20	11	8	0	-2	8	0	0	4.0	
i 1	105.99157142857143	0.2525	74	700	1	24	7	2	0	1	2	0	0	8.0	
i 1	106.00602040816327	0.2525	75	1086	6	5	13	8	0	-2	8	0	0	2.1662443531096365	
i 1	106.01083673469388	0.2525	75	202	5	5	13	2	0	1	2	0	0	2.1662443531096365	
i 1	106.23274149659863	0.2525	74	700	2	20	11	2	0	1	2	0	0	4.0	
i 1	106.23434693877552	1.01	75	588	6	5	6	8	0	-2	8	0	0	2.1662443531096365	
i 1	106.23595238095238	1.01	74	700	4	1	8	8	0	-1	8	0	0	2.0438274789689523	
i 1	106.23836054421768	1.01	74	588	4	1	15	8	0	-2	8	0	0	2.0438274789689523	
i 1	106.2455850340136	0.2525	74	700	1	20	16	2	0	1	2	0	0	4.0	
i 1	106.25040136054422	1.2625	75	700	4	5	16	2	0	1	2	0	0	2.1662443531096365	
i 1	106.48274149659863	0.2525	74	1086	3	20	14	2	0	1	2	0	0	4.0	
i 1	106.48595238095238	0.2525	74	588	3	20	6	2	0	1	2	0	0	4.0	
i 1	106.7431768707483	0.505	74	202	2	20	10	2	0	-2	2	0	0	4.0	
i 1	106.74397959183673	0.505	74	700	3	3	11	8	0	-2	8	0	0	3.0	
i 1	106.74397959183673	0.2525	74	700	1	20	9	2	0	1	2	0	0	4.0	
i 1	106.75361224489797	0.505	74	588	5	3	10	2	0	-2	2	0	0	3.0	
i 1	106.7680612244898	0.505	74	202	3	20	5	2	0	1	2	0	0	4.0	
i 1	107.23514965986395	0.2525	74	384	3	20	6	2	0	1	2	0	0	4.0	
i 1	107.23514965986395	0.2525	74	202	2	24	10	2	0	1	2	0	0	8.0	
i 1	107.23514965986395	0.2525	74	700	1	24	8	2	0	1	2	0	0	8.0	
i 1	107.23916326530612	0.2525	74	202	6	9	6	2	0	-1	2	0	0	2.0	
i 1	107.24478231292517	0.2525	71	384	4	24	11	2	0	-2	2	0	0	3.0438274789689523	
i 1	107.2455850340136	0.2525	63	384	3	13	12	1	0	1	1	0	0	0.6798674639746006	
i 1	107.24638775510203	0.2525	63	384	5	15	13	1	0	2	1	0	0	1.9192017177729124	
i 1	107.24719047619048	0.2525	63	384	4	7	15	16	0	2	16	0	0	2.180033569360793	
i 1	107.24879591836735	0.2525	71	202	5	1	7	2	0	-1	2	0	0	2.0438274789689523	
i 1	107.25120408163265	0.2525	72	384	6	5	10	2	0	1	2	0	0	2.1662443531096365	
i 1	107.25521768707483	0.2525	71	1086	3	20	6	2	0	-2	2	0	0	4.0	
i 1	107.2568231292517	0.2525	63	384	5	15	9	1	0	2	1	0	0	1.9192017177729124	
i 1	107.26083673469388	0.2525	74	1086	6	2	14	2	0	-2	2	0	0	3.0	
i 1	107.4955850340136	0.505	74	202	3	3	2	2	0	-2	2	0	0	3.0	
i 1	107.49638775510203	0.505	61	588	5	15	7	16	0	1	16	0	0	1.9192017177729124	
i 1	107.49799319727892	0.505	74	202	2	20	2	8	0	-2	8	0	0	4.0	
i 1	107.49959863945578	1.2625	74	202	4	1	1	2	0	-1	2	0	0	2.0438274789689523	
i 1	107.50040136054422	7.3225	61	588	5	15	5	16	0	2	16	0	0	1.9192017177729124	
i 1	107.50120408163265	1.7675	72	904	6	5	1	2	0	-2	2	0	0	2.1662443531096365	
i 1	107.50200680272108	14.14	63	904	3	14	4	1	0	1	1	0	0	2.930116622053889	
i 1	107.50280952380952	0.505	74	202	1	20	1	2	0	1	2	0	0	4.0	
i 1	107.50361224489797	0.505	75	202	5	5	10	2	0	1	2	0	0	2.1662443531096365	
i 1	107.50762585034013	1.2625	71	588	4	1	3	2	0	-2	2	0	0	2.0438274789689523	
i 1	107.51163945578232	27.775	63	588	3	13	11	16	0	1	16	0	0	0.6798674639746006	
i 1	107.51163945578232	34.5925	63	588	4	7	13	1	0	2	1	0	0	2.180033569360793	
i 1	107.51244217687075	7.3225	61	202	4	27	1	16	0	1	16	0	0	12.051504796183696	
i 1	107.51725850340137	44.44	61	904	5	14	5	16	0	2	16	0	0	4.270502321028533	
i 1	107.51886394557823	20.9575	61	904	3	14	6	16	0	1	16	0	0	2.930116622053889	
i 1	107.51966666666667	44.44	63	904	5	13	2	1	0	1	1	0	0	0.743551416145102	
i 1	107.51966666666667	1.01	71	588	5	3	16	8	0	-2	8	0	0	3.0	
i 1	107.51966666666667	14.14	63	202	4	27	7	1	0	2	1	0	0	12.051504796183696	
i 1	107.9819387755102	0.505	74	202	2	20	12	8	0	-2	8	0	0	2.0	
i 1	108.00040136054422	0.505	74	202	1	20	10	2	0	1	2	0	0	2.0	
i 1	108.00200680272108	6.8175	63	202	5	16	7	1	0	2	1	0	0	3.094852019400723	
i 1	108.0044149659864	13.635	63	202	5	16	16	1	0	1	1	0	0	3.094852019400723	
i 1	108.0044149659864	1.2625	75	202	7	5	5	2	0	1	2	0	0	2.1662443531096365	
i 1	108.0068231292517	43.935	61	588	5	15	12	16	0	1	16	0	0	1.9192017177729124	
i 1	108.0068231292517	6.8175	63	202	6	12	10	1	0	2	1	0	0	3.094852019400723	
i 1	108.01083673469388	0.505	74	202	6	3	4	2	0	-2	2	0	0	3.0	
i 1	108.48113605442177	1.01	71	588	4	4	13	2	0	-2	2	0	0	3.0	
i 1	108.48113605442177	1.01	71	202	3	4	14	8	0	-2	8	0	0	3.0	
i 1	108.490768707483	0.505	71	202	1	24	9	2	0	1	2	0	0	6.0	
i 1	108.50280952380952	0.505	71	588	3	20	9	2	0	1	2	0	0	2.0	
i 1	108.51244217687075	0.7575000000000001	74	202	2	24	5	2	0	1	2	0	0	6.0	
i 1	108.51565306122448	0.505	71	904	3	20	5	8	0	-2	8	0	0	2.0	
i 1	108.7319387755102	1.01	71	202	4	24	7	8	0	-1	8	0	0	3.0438274789689523	
i 1	108.7431768707483	1.01	71	588	4	24	13	8	0	-2	8	0	0	3.0438274789689523	
i 1	108.98836054421768	0.2525	74	202	2	24	6	2	0	-2	2	0	0	6.0	
i 1	108.99157142857143	0.2525	71	202	2	20	2	2	0	1	2	0	0	2.0	
i 1	109.00842857142857	0.505	74	202	1	20	15	2	0	1	2	0	0	2.0	
i 1	109.23836054421768	1.01	72	588	6	5	11	2	0	1	2	0	0	2.1662443531096365	
i 1	109.24157142857143	0.2525	71	904	3	20	15	8	0	-2	8	0	0	2.0	
i 1	109.24719047619048	0.2525	74	588	3	24	5	2	0	-2	2	0	0	6.0	
i 1	109.26003401360545	3.2825	74	202	2	20	1	2	0	-2	2	0	0	2.0	
i 1	109.26966666666667	1.01	72	202	4	5	1	2	0	-2	2	0	0	2.1662443531096365	
i 1	109.49397959183673	1.01	71	202	6	9	1	2	0	-1	2	0	0	2.0	
i 1	109.50200680272108	1.2625	74	202	3	20	10	2	0	-2	2	0	0	2.0	
i 1	109.51163945578232	1.2625	71	202	1	24	6	2	0	1	2	0	0	6.0	
i 1	109.51485034013605	3.0300000000000002	71	202	3	20	11	2	0	1	2	0	0	2.0	
i 1	109.5180612244898	1.01	74	904	6	2	6	2	0	-1	2	0	0	3.0	
i 1	109.73595238095238	1.01	71	904	4	1	1	8	0	-2	8	0	0	2.0438274789689523	
i 1	109.76324489795918	1.01	71	202	4	1	8	2	0	-1	2	0	0	2.0438274789689523	
i 1	110.259231292517	0.2525	75	202	5	5	11	2	0	1	2	0	0	2.1662443531096365	
i 1	110.26645578231293	0.2525	72	904	6	5	11	2	0	1	2	0	0	2.1662443531096365	
i 1	110.48675510204082	1.5150000000000001	72	588	6	5	4	2	0	1	2	0	0	2.1662443531096365	
i 1	110.51404761904762	1.5150000000000001	72	202	4	5	7	2	0	-2	2	0	0	2.1662443531096365	
i 1	110.51485034013605	0.7575000000000001	74	202	6	3	11	2	0	-2	2	0	0	3.0	
i 1	110.5180612244898	0.7575000000000001	71	588	5	3	5	8	0	-2	8	0	0	3.0	
i 1	110.74799319727892	2.02	74	202	1	20	2	2	0	1	2	0	0	2.0	
i 1	110.75120408163265	1.5150000000000001	71	588	4	1	6	2	0	-2	2	0	0	2.0438274789689523	
i 1	110.7544149659864	1.5150000000000001	74	202	4	1	4	2	0	-1	2	0	0	2.0438274789689523	
i 1	110.76163945578232	1.7675	71	202	2	20	7	2	0	-2	2	0	0	2.0	
i 1	111.26244217687075	0.7575000000000001	71	904	6	2	16	2	0	-2	2	0	0	3.0	
i 1	111.26886394557823	0.7575000000000001	74	202	6	9	2	2	0	-1	2	0	0	2.0	
i 1	111.98755782312925	0.2525	71	202	6	9	11	2	0	-1	2	0	0	2.0	
i 1	112.00120408163265	0.2525	74	904	6	2	12	2	0	-1	2	0	0	3.0	
i 1	112.01003401360545	1.2625	75	202	7	5	3	2	0	1	2	0	0	2.1662443531096365	
i 1	112.01324489795918	1.2625	72	904	6	5	4	2	0	-2	2	0	0	2.1662443531096365	
i 1	112.2455850340136	1.2625	71	904	4	1	1	8	0	-2	8	0	0	2.0438274789689523	
i 1	112.2568231292517	0.7575000000000001	71	904	6	2	4	2	0	-2	2	0	0	3.0	
i 1	112.25842857142857	1.2625	71	202	4	1	7	2	0	-1	2	0	0	2.0438274789689523	
i 1	112.259231292517	0.7575000000000001	74	202	6	9	6	2	0	-1	2	0	0	2.0	
i 1	112.49959863945578	0.2525	71	588	3	24	2	8	0	1	8	0	0	6.0	
i 1	112.51083673469388	0.2525	71	588	3	20	16	2	0	-2	2	0	0	2.0	
i 1	112.51565306122448	0.505	71	202	1	24	9	2	0	1	2	0	0	6.0	
i 1	112.74959863945578	0.2525	71	202	3	20	10	2	0	1	2	0	0	2.0	
i 1	112.7544149659864	0.505	71	202	2	24	1	2	0	1	2	0	0	6.0	
i 1	112.7568231292517	0.505	74	202	2	24	11	2	0	1	2	0	0	6.0	
i 1	112.98836054421768	2.02	74	202	6	3	1	2	0	-2	2	0	0	3.0	
i 1	113.01244217687075	2.02	71	588	5	3	6	8	0	-2	8	0	0	3.0	
i 1	113.23595238095238	0.2525	74	588	3	24	2	2	0	-2	2	0	0	6.0	
i 1	113.24397959183673	0.2525	72	202	4	5	16	8	0	-2	8	0	0	2.1662443531096365	
i 1	113.24799319727892	0.2525	72	588	6	5	2	2	0	-2	2	0	0	2.1662443531096365	
i 1	113.26645578231293	0.2525	74	202	1	20	15	2	0	1	2	0	0	2.0	
i 1	113.4931768707483	1.2625	71	202	4	24	10	8	0	-1	8	0	0	3.0438274789689523	
i 1	113.49719047619048	1.2625	71	588	4	24	10	8	0	-2	8	0	0	3.0438274789689523	
i 1	113.49719047619048	1.01	74	202	2	24	2	2	0	1	2	0	0	6.0	
i 1	113.50200680272108	0.2525	71	202	3	20	4	2	0	-2	2	0	0	2.0	
i 1	113.50200680272108	0.2525	74	202	2	20	11	2	0	-2	2	0	0	2.0	
i 1	113.51083673469388	1.5150000000000001	72	904	6	5	13	2	0	1	2	0	0	2.1662443531096365	
i 1	113.51163945578232	0.2525	74	202	2	24	16	2	0	-2	2	0	0	6.0	
i 1	113.51485034013605	1.2625	75	202	5	5	15	2	0	1	2	0	0	2.1662443531096365	
i 1	113.74959863945578	0.2525	74	202	1	20	2	2	0	1	2	0	0	2.0	
i 1	113.7568231292517	0.2525	71	588	3	24	11	2	0	1	2	0	0	6.0	
i 1	113.76645578231293	0.2525	74	904	3	20	5	2	0	1	2	0	0	2.0	
i 1	113.99879591836735	0.505	71	202	2	24	9	2	0	-2	2	0	0	6.0	
i 1	114.48836054421768	0.2525	74	202	2	20	15	2	0	-2	2	0	0	2.0	
i 1	114.49157142857143	0.2525	74	202	3	20	10	2	0	-2	2	0	0	2.0	
i 1	114.50200680272108	0.505	71	202	1	24	8	2	0	1	2	0	0	6.0	
i 1	114.51485034013605	0.2525	74	202	3	20	16	2	0	-2	2	0	0	2.0	
i 1	114.73113605442177	2.02	71	588	4	1	3	2	0	-2	2	0	0	2.0438274789689523	
i 1	114.73113605442177	1.01	74	202	1	20	9	2	0	1	2	0	0	2.0	
i 1	114.73274149659863	0.2525	71	588	3	24	1	2	0	-2	2	0	0	6.0	
i 1	114.73514965986395	0.2525	71	588	3	20	11	2	0	1	2	0	0	2.0	
i 1	114.73996598639455	6.8175	61	202	6	12	14	16	0	2	16	0	0	3.094852019400723	
i 1	114.76244217687075	37.1175	61	588	5	15	6	16	0	2	16	0	0	1.9192017177729124	
i 1	114.76244217687075	13.635	63	202	5	16	16	1	0	2	1	0	0	3.094852019400723	
i 1	114.76404761904762	2.02	74	202	4	1	16	2	0	-1	2	0	0	2.0438274789689523	
i 1	114.76404761904762	0.2525	75	202	7	5	4	2	0	1	2	0	0	2.1662443531096365	
i 1	114.76645578231293	6.8175	63	202	5	12	6	1	0	2	1	0	0	3.094852019400723	
i 1	114.98113605442177	1.2625	72	904	6	5	12	2	0	-2	2	0	0	2.1662443531096365	
i 1	114.98274149659863	0.505	74	202	2	24	10	2	0	1	2	0	0	6.0	
i 1	114.98434693877552	0.505	71	202	2	20	14	2	0	-2	2	0	0	2.0	
i 1	114.98595238095238	0.505	74	202	3	24	9	2	0	1	2	0	0	6.0	
i 1	115.00040136054422	1.2625	75	202	7	5	4	2	0	1	2	0	0	2.1662443531096365	
i 1	115.00361224489797	0.7575000000000001	71	588	4	4	13	2	0	-2	2	0	0	3.0	
i 1	115.0068231292517	0.7575000000000001	71	202	5	4	11	8	0	-2	8	0	0	3.0	
i 1	115.49638775510203	0.2525	74	202	2	20	1	2	0	-2	2	0	0	2.0	
i 1	115.51083673469388	0.2525	74	904	3	20	13	8	0	-2	8	0	0	2.0	
i 1	115.51966666666667	0.2525	71	588	3	24	16	2	0	1	2	0	0	6.0	
i 1	115.73274149659863	1.5150000000000001	74	202	3	24	14	2	0	1	2	0	0	6.0	
i 1	115.73514965986395	0.7575000000000001	71	202	1	24	5	2	0	1	2	0	0	6.0	
i 1	115.74478231292517	0.7575000000000001	71	202	6	9	4	2	0	-1	2	0	0	2.0	
i 1	115.74879591836735	0.7575000000000001	74	904	6	2	5	2	0	-1	2	0	0	3.0	
i 1	115.76725850340137	0.2525	71	202	3	20	16	2	0	-2	2	0	0	2.0	
i 1	115.76725850340137	0.2525	71	202	2	24	10	8	0	1	8	0	0	6.0	
i 1	115.98996598639455	0.505	71	588	3	20	1	2	0	1	2	0	0	2.0	
i 1	115.99799319727892	0.505	74	904	3	20	5	8	0	1	8	0	0	2.0	
i 1	116.24959863945578	1.5150000000000001	72	202	4	5	16	2	0	-2	2	0	0	2.1662443531096365	
i 1	116.2680612244898	1.5150000000000001	72	588	6	5	10	2	0	1	2	0	0	2.1662443531096365	
i 1	116.48274149659863	0.505	74	202	1	20	7	2	0	1	2	0	0	2.0	
i 1	116.48514965986395	0.505	71	202	2	20	11	2	0	-2	2	0	0	2.0	
i 1	116.4931768707483	0.2525	71	588	5	3	7	8	0	-2	8	0	0	3.0	
i 1	116.49719047619048	0.7575000000000001	71	202	2	24	16	2	0	1	2	0	0	6.0	
i 1	116.51966666666667	0.2525	74	202	6	3	14	2	0	-2	2	0	0	3.0	
i 1	116.73274149659863	1.5150000000000001	71	588	4	24	2	8	0	-2	8	0	0	3.0438274789689523	
i 1	116.7455850340136	0.7575000000000001	74	202	6	9	1	2	0	-1	2	0	0	2.0	
i 1	116.7544149659864	1.5150000000000001	71	202	4	24	16	8	0	-1	8	0	0	3.0438274789689523	
i 1	116.75842857142857	0.7575000000000001	71	904	6	2	13	2	0	-2	2	0	0	3.0	
i 1	116.98595238095238	0.2525	74	202	3	20	7	2	0	1	2	0	0	2.0	
i 1	116.98675510204082	0.2525	74	202	2	20	8	2	0	-2	2	0	0	2.0	
i 1	117.23836054421768	0.505	74	202	1	20	1	2	0	1	2	0	0	2.0	
i 1	117.24157142857143	0.505	71	588	3	24	5	2	0	-2	2	0	0	6.0	
i 1	117.49799319727892	1.01	74	904	6	2	1	2	0	-1	2	0	0	3.0	
i 1	117.50120408163265	1.01	71	202	6	9	6	2	0	-1	2	0	0	2.0	
i 1	117.740768707483	1.2625	74	202	2	24	13	8	0	-2	8	0	0	6.0	
i 1	117.74638775510203	1.2625	75	202	7	5	9	2	0	1	2	0	0	2.1662443531096365	
i 1	117.7544149659864	1.2625	74	202	3	24	12	2	0	1	2	0	0	6.0	
i 1	117.7568231292517	1.2625	72	904	6	5	3	2	0	1	2	0	0	2.1662443531096365	
i 1	118.24799319727892	1.2625	71	904	4	1	4	8	0	-2	8	0	0	2.0438274789689523	
i 1	118.25361224489797	1.2625	71	202	4	1	1	2	0	-1	2	0	0	2.0438274789689523	
i 1	118.4819387755102	1.01	71	904	6	2	1	2	0	-2	2	0	0	3.0	
i 1	118.51163945578232	1.01	74	202	6	9	13	2	0	-1	2	0	0	2.0	
i 1	118.990768707483	0.2525	72	588	6	5	9	2	0	1	2	0	0	2.1662443531096365	
i 1	118.99157142857143	0.2525	74	202	1	20	10	2	0	1	2	0	0	2.0	
i 1	118.99397959183673	0.2525	72	202	4	5	14	2	0	-2	2	0	0	2.1662443531096365	
i 1	119.00040136054422	0.505	74	202	2	20	2	2	0	-2	2	0	0	2.0	
i 1	119.00521768707483	0.505	71	202	3	20	6	2	0	-2	2	0	0	2.0	
i 1	119.01886394557823	0.2525	71	202	2	20	10	2	0	1	2	0	0	2.0	
i 1	119.240768707483	1.5150000000000001	72	904	6	5	4	2	0	-2	2	0	0	2.1662443531096365	
i 1	119.25842857142857	1.2625	74	202	3	24	13	2	0	1	2	0	0	6.0	
i 1	119.26565306122448	1.5150000000000001	75	202	7	5	16	2	0	1	2	0	0	2.1662443531096365	
i 1	119.26645578231293	0.2525	74	202	2	24	14	8	0	-2	8	0	0	6.0	
i 1	119.48033333333333	1.5150000000000001	71	588	5	3	11	8	0	-2	8	0	0	3.0	
i 1	119.48514965986395	1.5150000000000001	74	202	6	3	8	2	0	-2	2	0	0	3.0	
i 1	119.48916326530612	0.505	74	202	4	1	11	2	0	-1	2	0	0	2.0438274789689523	
i 1	119.49799319727892	0.2525	74	202	1	20	10	2	0	1	2	0	0	2.0	
i 1	119.49959863945578	0.505	71	588	4	1	10	2	0	-2	2	0	0	2.0438274789689523	
i 1	119.51003401360545	0.2525	74	904	3	20	6	2	0	-2	2	0	0	2.0	
i 1	119.51244217687075	0.2525	71	588	3	24	6	2	0	-2	2	0	0	6.0	
i 1	119.75200680272108	0.7575000000000001	74	202	2	24	12	2	0	1	2	0	0	6.0	
i 1	119.98996598639455	0.7575000000000001	71	202	4	1	8	2	0	-1	2	0	0	2.0438274789689523	
i 1	119.990768707483	0.7575000000000001	71	904	4	1	8	8	0	-2	8	0	0	2.0438274789689523	
i 1	120.48675510204082	0.505	74	202	2	20	12	2	0	1	2	0	0	2.0	
i 1	120.49397959183673	0.505	74	202	2	20	12	2	0	-2	2	0	0	2.0	
i 1	120.51163945578232	0.505	74	202	1	20	3	2	0	1	2	0	0	2.0	
i 1	120.51966666666667	0.505	71	202	3	20	10	8	0	1	8	0	0	2.0	
i 1	120.73595238095238	2.02	71	202	4	24	13	8	0	-1	8	0	0	3.0438274789689523	
i 1	120.74879591836735	0.7575000000000001	72	202	4	5	4	8	0	-2	8	0	0	2.1662443531096365	
i 1	120.7544149659864	1.01	72	588	6	5	13	2	0	-2	2	0	0	2.1662443531096365	
i 1	120.759231292517	2.02	71	588	4	24	2	8	0	-2	8	0	0	3.0438274789689523	
i 1	120.98274149659863	0.2525	71	202	5	4	2	8	0	-2	8	0	0	3.0	
i 1	120.98514965986395	0.2525	71	202	1	24	15	2	0	1	2	0	0	6.0	
i 1	120.99237414965987	0.2525	71	588	4	4	1	2	0	-2	2	0	0	3.0	
i 1	120.99638775510203	0.2525	71	904	3	20	10	8	0	-2	8	0	0	2.0	
i 1	120.99959863945578	0.2525	71	588	3	20	4	2	0	-2	2	0	0	2.0	
i 1	121.0068231292517	0.505	74	202	3	24	13	2	0	1	2	0	0	6.0	
i 1	121.23113605442177	0.505	74	202	1	20	2	2	0	1	2	0	0	2.0	
i 1	121.2455850340136	0.2525	71	202	2	24	3	2	0	1	2	0	0	6.0	
i 1	121.2544149659864	0.7575000000000001	71	202	6	9	9	2	0	-1	2	0	0	2.0	
i 1	121.2568231292517	0.2525	74	202	2	20	8	2	0	1	2	0	0	2.0	
i 1	121.26083673469388	0.2525	74	904	6	2	6	2	0	-1	2	0	0	3.0	
i 1	121.48033333333333	0.2525	71	588	3	24	2	2	0	1	2	0	0	6.0	
i 1	121.48514965986395	16.16	63	202	5	16	13	1	0	1	1	0	0	3.094852019400723	
i 1	121.48755782312925	0.2525	72	202	7	5	9	8	0	-2	8	0	0	2.1662443531096365	
i 1	121.4955850340136	13.635	63	202	4	12	5	1	0	2	1	0	0	3.094852019400723	
i 1	121.49879591836735	30.3	63	904	5	14	16	1	0	1	1	0	0	2.930116622053889	
i 1	121.51244217687075	0.505	74	904	4	2	14	2	0	-1	2	0	0	3.0	
i 1	121.5180612244898	6.8175	61	202	5	12	10	16	0	2	16	0	0	3.094852019400723	
i 1	121.73274149659863	5.8075	74	202	3	24	10	2	0	1	2	0	0	6.0	
i 1	121.73595238095238	0.2525	75	202	7	5	14	2	0	1	2	0	0	2.1662443531096365	
i 1	121.740768707483	0.2525	72	904	6	5	10	2	0	1	2	0	0	2.1662443531096365	
i 1	121.74719047619048	0.505	74	202	2	24	2	2	0	1	2	0	0	6.0	
i 1	121.75280952380952	0.505	74	202	3	20	7	2	0	-2	2	0	0	2.0	
i 1	121.7568231292517	0.505	71	202	3	20	16	2	0	-2	2	0	0	2.0	
i 1	121.99799319727892	1.01	71	588	5	3	12	8	0	-2	8	0	0	3.0	
i 1	121.99879591836735	2.7775	75	202	7	5	9	2	0	1	2	0	0	2.1662443531096365	
i 1	122.00521768707483	2.7775	72	904	6	5	12	2	0	-2	2	0	0	2.1662443531096365	
i 1	122.01966666666667	1.01	74	202	6	3	9	2	0	-2	2	0	0	3.0	
i 1	122.24799319727892	0.505	74	202	1	20	13	2	0	1	2	0	0	2.0	
i 1	122.25120408163265	0.505	71	588	3	24	9	8	0	1	8	0	0	6.0	
i 1	122.2680612244898	0.505	74	904	3	20	6	2	0	1	2	0	0	2.0	
i 1	122.7319387755102	0.505	74	202	3	20	14	2	0	-2	2	0	0	2.0	
i 1	122.74799319727892	0.505	71	202	3	20	8	2	0	-2	2	0	0	2.0	
i 1	122.7544149659864	2.7775	74	202	3	1	11	2	0	-1	2	0	0	2.0438274789689523	
i 1	122.75842857142857	2.7775	71	588	4	1	3	2	0	-2	2	0	0	2.0438274789689523	
i 1	122.76324489795918	0.505	71	202	2	24	9	2	0	-2	2	0	0	6.0	
i 1	123.00602040816327	1.01	74	202	6	9	15	2	0	-1	2	0	0	2.0	
i 1	123.00762585034013	1.01	71	904	6	2	6	2	0	-2	2	0	0	3.0	
i 1	123.23354421768707	0.2525	71	588	3	24	3	2	0	1	2	0	0	6.0	
i 1	123.26003401360545	0.2525	74	904	3	20	10	2	0	-2	2	0	0	2.0	
i 1	123.26565306122448	0.2525	74	202	1	20	9	2	0	1	2	0	0	2.0	
i 1	123.48595238095238	0.2525	74	202	3	20	7	2	0	-2	2	0	0	2.0	
i 1	123.48755782312925	0.2525	74	202	3	20	8	2	0	-2	2	0	0	2.0	
i 1	123.4955850340136	0.2525	71	202	2	24	13	2	0	-2	2	0	0	6.0	
i 1	123.73595238095238	0.505	74	904	3	20	3	2	0	-2	2	0	0	2.0	
i 1	123.7431768707483	0.505	71	588	3	24	15	2	0	1	2	0	0	6.0	
i 1	123.75842857142857	0.505	74	202	1	20	9	2	0	1	2	0	0	2.0	
i 1	123.98113605442177	0.7575000000000001	74	202	3	20	11	2	0	-2	2	0	0	2.0	
i 1	123.99879591836735	1.01	74	904	4	2	14	2	0	-1	2	0	0	3.0	
i 1	124.01404761904762	1.01	71	202	6	9	9	2	0	-1	2	0	0	2.0	
i 1	124.24237414965987	0.7575000000000001	74	202	2	24	10	2	0	-2	2	0	0	6.0	
i 1	124.2455850340136	0.505	74	202	3	20	1	2	0	-2	2	0	0	2.0	
i 1	124.24638775510203	0.2525	71	202	4	24	9	8	0	-1	8	0	0	3.0438274789689523	
i 1	124.49638775510203	0.505	72	202	4	5	3	2	0	-2	2	0	0	2.1662443531096365	
i 1	124.73434693877552	0.7575000000000001	71	904	6	2	15	2	0	-2	2	0	0	3.0	
i 1	124.75521768707483	0.7575000000000001	74	202	6	9	6	2	0	-1	2	0	0	2.0	
i 1	124.76244217687075	0.2525	72	588	6	5	8	2	0	1	2	0	0	2.1662443531096365	
i 1	124.9819387755102	0.505	74	202	1	20	15	2	0	1	2	0	0	2.0	
i 1	124.9955850340136	0.2525	74	904	3	20	11	8	0	-2	8	0	0	2.0	
i 1	125.00762585034013	1.5150000000000001	72	904	6	5	16	2	0	1	2	0	0	2.1662443531096365	
i 1	125.01404761904762	1.7675	75	202	7	5	1	2	0	1	2	0	0	2.1662443531096365	
i 1	125.01485034013605	0.2525	71	588	3	24	10	8	0	-2	8	0	0	6.0	
i 1	125.24799319727892	1.5150000000000001	74	202	3	20	5	2	0	-2	2	0	0	2.0	
i 1	125.25280952380952	1.5150000000000001	74	202	3	20	4	8	0	-2	8	0	0	2.0	
i 1	125.26003401360545	2.02	74	202	2	24	9	8	0	1	8	0	0	6.0	
i 1	125.48755782312925	1.2625	71	588	5	3	12	8	0	-2	8	0	0	3.0	
i 1	125.50280952380952	0.2525	71	202	4	1	5	2	0	-1	2	0	0	2.0438274789689523	
i 1	125.50602040816327	1.2625	74	202	6	3	15	2	0	-2	2	0	0	3.0	
i 1	125.51083673469388	0.505	71	202	4	24	5	8	0	-1	8	0	0	3.0438274789689523	
i 1	125.51324489795918	0.505	71	588	4	24	10	8	0	-2	8	0	0	3.0438274789689523	
i 1	125.99719047619048	1.01	71	202	4	1	14	2	0	-1	2	0	0	2.0438274789689523	
i 1	126.01324489795918	1.01	71	904	5	1	7	8	0	-2	8	0	0	2.0438274789689523	
i 1	126.24799319727892	0.2525	71	588	4	24	16	8	0	-2	8	0	0	3.0438274789689523	
i 1	126.48996598639455	1.01	72	588	6	5	6	2	0	1	2	0	0	2.1662443531096365	
i 1	126.50280952380952	1.2625	71	588	4	4	9	2	0	-2	2	0	0	3.0	
i 1	126.51003401360545	1.01	72	202	4	5	5	2	0	-2	2	0	0	2.1662443531096365	
i 1	126.51725850340137	1.2625	71	202	5	4	8	8	0	-2	8	0	0	3.0	
i 1	126.73113605442177	1.2625	71	588	4	1	13	2	0	-2	2	0	0	2.0438274789689523	
i 1	126.74478231292517	0.2525	74	904	4	2	9	2	0	-1	2	0	0	3.0	
i 1	126.76324489795918	1.2625	74	202	3	1	9	2	0	-1	2	0	0	2.0438274789689523	
i 1	127.23595238095238	0.2525	74	202	1	20	14	2	0	1	2	0	0	2.0	
i 1	127.23836054421768	0.2525	71	904	3	20	4	2	0	1	2	0	0	2.0	
i 1	127.2431768707483	1.01	74	904	4	2	16	2	0	-1	2	0	0	3.0	
i 1	127.24397959183673	0.7575000000000001	75	202	7	5	1	2	0	1	2	0	0	2.1662443531096365	
i 1	127.26083673469388	0.7575000000000001	72	904	6	5	10	2	0	-2	2	0	0	2.1662443531096365	
i 1	127.26163945578232	1.2625	71	202	6	9	5	2	0	-1	2	0	0	2.0	
i 1	127.26725850340137	0.2525	71	588	3	24	11	2	0	-2	2	0	0	6.0	
i 1	127.4931768707483	2.02	74	202	2	24	5	2	0	-2	2	0	0	6.0	
i 1	127.50521768707483	2.02	71	202	3	20	15	2	0	1	2	0	0	2.0	
i 1	127.51003401360545	1.7675	74	202	3	20	14	2	0	-2	2	0	0	2.0	
i 1	127.73274149659863	1.5150000000000001	72	588	6	5	2	2	0	-2	2	0	0	2.1662443531096365	
i 1	127.73434693877552	1.01	71	904	5	1	4	8	0	-2	8	0	0	2.0438274789689523	
i 1	127.74157142857143	1.01	71	202	4	1	7	2	0	-1	2	0	0	2.0438274789689523	
i 1	127.7455850340136	2.02	74	202	3	24	7	2	0	1	2	0	0	6.0	
i 1	127.759231292517	1.7675	72	202	7	5	8	8	0	-2	8	0	0	2.1662443531096365	
i 1	128.2319387755102	9.3425	63	202	5	16	1	1	0	2	1	0	0	3.094852019400723	
i 1	128.24719047619047	9.3425	61	202	4	12	2	16	0	2	16	0	0	3.094852019400723	
i 1	128.25040136054423	0.2525	74	904	6	2	11	2	0	-1	2	0	0	3.0	
i 1	128.25521768707483	23.4825	61	904	5	14	13	16	0	1	16	0	0	2.930116622053889	
i 1	128.2568231292517	0.505	72	904	6	5	15	2	0	-2	2	0	0	2.1662443531096365	
i 1	128.48113605442177	3.2825	71	202	3	24	7	8	0	-1	8	0	0	3.0438274789689523	
i 1	128.49157142857143	0.7575000000000001	74	202	6	3	1	2	0	-2	2	0	0	3.0	
i 1	128.50120408163266	0.7575000000000001	71	588	5	3	16	8	0	-2	8	0	0	3.0	
i 1	128.5020068027211	3.2825	71	588	4	24	7	8	0	-2	8	0	0	3.0438274789689523	
i 1	128.76404761904763	0.2525	71	588	4	4	7	2	0	-2	2	0	0	3.0	
i 1	129.23354421768707	1.5150000000000001	72	904	6	5	4	2	0	1	2	0	0	2.1662443531096365	
i 1	129.24157142857143	0.7575000000000001	71	904	4	2	9	2	0	-2	2	0	0	3.0	
i 1	129.25521768707483	0.2525	74	202	4	1	4	2	0	-1	2	0	0	2.0438274789689523	
i 1	129.25842857142857	0.505	74	202	1	20	9	2	0	1	2	0	0	2.0	
i 1	129.2632448979592	1.7675	74	202	6	9	12	2	0	-1	2	0	0	2.0	
i 1	129.2680612244898	1.5150000000000001	75	202	7	5	15	2	0	1	2	0	0	2.1662443531096365	
i 1	129.49157142857143	0.2525	74	588	3	24	9	2	0	1	2	0	0	6.0	
i 1	129.5044149659864	0.2525	71	904	3	20	11	2	0	1	2	0	0	2.0	
i 1	129.73033333333333	0.505	74	202	3	20	3	2	0	-2	2	0	0	2.0	
i 1	129.7343469387755	0.505	71	202	6	9	2	2	0	-1	2	0	0	2.0	
i 1	129.74959863945577	0.2525	71	202	3	20	14	8	0	-2	8	0	0	2.0	
i 1	129.75521768707483	0.505	74	904	6	2	15	2	0	-1	2	0	0	3.0	
i 1	129.7568231292517	0.2525	74	202	2	24	8	2	0	1	2	0	0	6.0	
i 1	129.9843469387755	0.2525	74	202	1	20	4	2	0	1	2	0	0	2.0	
i 1	129.99959863945577	0.2525	74	202	4	1	15	2	0	-1	2	0	0	2.0438274789689523	
i 1	130.00521768707483	0.2525	74	588	3	24	14	8	0	1	8	0	0	6.0	
i 1	130.01404761904763	0.2525	72	588	6	5	14	2	0	1	2	0	0	2.1662443531096365	
i 1	130.23595238095237	0.505	74	202	2	24	9	2	0	-2	2	0	0	6.0	
i 1	130.2431768707483	1.7675	74	202	3	24	4	2	0	1	2	0	0	6.0	
i 1	130.25120408163266	2.2725	72	904	6	5	4	2	0	-2	2	0	0	2.1662443531096365	
i 1	130.26083673469387	0.7575000000000001	71	904	4	2	14	2	0	-2	2	0	0	3.0	
i 1	130.26485034013606	2.2725	75	202	7	5	9	2	0	1	2	0	0	2.1662443531096365	
i 1	130.5116394557823	0.505	71	202	2	24	3	2	0	1	2	0	0	6.0	
i 1	130.73354421768707	1.01	74	202	1	20	15	2	0	1	2	0	0	2.0	
i 1	130.7343469387755	0.2525	74	904	3	20	16	2	0	-2	2	0	0	2.0	
i 1	130.75361224489797	0.505	74	202	3	20	11	2	0	-2	2	0	0	2.0	
i 1	130.7544149659864	2.2725	74	202	6	3	10	2	0	-2	2	0	0	3.0	
i 1	130.75521768707483	2.2725	71	588	5	3	9	8	0	-2	8	0	0	3.0	
i 1	130.76966666666667	0.2525	71	588	3	24	11	2	0	1	2	0	0	6.0	
i 1	131.00361224489797	0.2525	71	202	3	20	15	2	0	1	2	0	0	2.0	
i 1	131.00842857142857	0.2525	71	202	2	24	5	2	0	-2	2	0	0	6.0	
i 1	131.25602040816327	0.2525	74	202	4	1	9	2	0	-1	2	0	0	2.0438274789689523	
i 1	131.2568231292517	0.505	71	588	3	24	1	2	0	1	2	0	0	6.0	
i 1	131.2680612244898	0.2525	74	202	6	9	3	2	0	-1	2	0	0	2.0	
i 1	131.4819387755102	1.2625	74	202	3	1	7	2	0	-1	2	0	0	2.0438274789689523	
i 1	131.48916326530613	1.2625	71	202	2	24	5	2	0	1	2	0	0	6.0	
i 1	131.49879591836734	1.2625	71	588	4	1	1	2	0	-2	2	0	0	2.0438274789689523	
i 1	131.5156530612245	0.2525	72	202	7	5	2	8	0	-2	8	0	0	2.1662443531096365	
i 1	131.51645578231293	0.2525	74	904	3	20	2	2	0	1	2	0	0	2.0	
i 1	131.74719047619047	0.2525	71	202	2	24	8	2	0	1	2	0	0	6.0	
i 1	131.7568231292517	1.01	71	202	3	20	14	2	0	1	2	0	0	2.0	
i 1	131.98595238095237	0.505	74	202	4	1	4	2	0	-1	2	0	0	2.0438274789689523	
i 1	132.00280952380953	0.2525	72	904	6	5	8	2	0	1	2	0	0	2.1662443531096365	
i 1	132.00842857142857	0.2525	74	202	3	20	14	2	0	-2	2	0	0	2.0	
i 1	132.23755782312926	2.7775	72	202	7	5	14	2	0	-2	2	0	0	2.1662443531096365	
i 1	132.2455850340136	2.7775	72	588	6	5	9	2	0	1	2	0	0	2.1662443531096365	
i 1	132.26404761904763	0.2525	71	202	5	4	8	8	0	-2	8	0	0	3.0	
i 1	132.49879591836734	0.2525	74	904	5	1	1	2	0	-2	2	0	0	2.0438274789689523	
i 1	132.50762585034013	0.7575000000000001	74	202	1	20	3	2	0	1	2	0	0	2.0	
i 1	132.5180612244898	0.2525	72	588	6	5	5	2	0	-2	2	0	0	2.1662443531096365	
i 1	132.51966666666667	2.2725	74	202	3	20	3	2	0	-2	2	0	0	2.0	
i 1	132.73033333333333	0.2525	71	588	3	24	10	2	0	1	2	0	0	6.0	
i 1	132.73274149659863	0.2525	71	904	3	20	3	2	0	-2	2	0	0	2.0	
i 1	132.7367551020408	0.2525	74	904	6	2	15	2	0	-1	2	0	0	3.0	
i 1	132.74157142857143	1.01	71	588	4	24	6	8	0	-2	8	0	0	3.0438274789689523	
i 1	132.74157142857143	1.01	71	202	3	24	7	8	0	-1	8	0	0	3.0438274789689523	
i 1	132.98113605442177	0.505	71	202	2	24	6	8	0	1	8	0	0	6.0	
i 1	132.98755782312926	0.7575000000000001	71	588	4	4	9	2	0	-2	2	0	0	3.0	
i 1	132.98916326530613	0.2525	71	588	4	1	16	2	0	-2	2	0	0	2.0438274789689523	
i 1	132.99157142857143	0.7575000000000001	71	202	5	4	15	8	0	-2	8	0	0	3.0	
i 1	132.9955850340136	2.7775	71	202	2	24	16	2	0	1	2	0	0	6.0	
i 1	133.00280952380953	0.505	71	202	3	20	3	2	0	1	2	0	0	2.0	
i 1	133.00602040816327	0.505	72	904	6	5	12	2	0	1	2	0	0	2.1662443531096365	
i 1	133.01083673469387	1.01	74	202	3	24	13	2	0	1	2	0	0	6.0	
i 1	133.0180612244898	0.7575000000000001	75	202	7	5	4	2	0	1	2	0	0	2.1662443531096365	
i 1	133.23916326530613	0.2525	74	202	4	1	10	2	0	-1	2	0	0	2.0438274789689523	
i 1	133.49478231292517	1.01	71	202	6	9	14	2	0	-1	2	0	0	2.0	
i 1	133.4955850340136	1.01	74	904	6	2	16	2	0	-1	2	0	0	3.0	
i 1	133.49879591836734	0.2525	74	202	3	1	6	2	0	-1	2	0	0	2.0438274789689523	
i 1	133.49879591836734	0.2525	71	904	3	20	4	2	0	1	2	0	0	2.0	
i 1	133.50842857142857	0.2525	71	904	3	20	1	2	0	-2	2	0	0	2.0	
i 1	133.51485034013606	0.2525	74	588	3	24	6	2	0	1	2	0	0	6.0	
i 1	133.73033333333333	1.01	71	202	4	1	8	2	0	-1	2	0	0	2.0438274789689523	
i 1	133.74959863945577	0.2525	74	202	2	24	15	2	0	1	2	0	0	6.0	
i 1	133.7544149659864	1.01	71	904	5	1	3	8	0	-2	8	0	0	2.0438274789689523	
i 1	133.75842857142857	0.7575000000000001	74	202	3	20	8	2	0	1	2	0	0	2.0	
i 1	133.7632448979592	0.2525	71	904	4	2	14	2	0	-2	2	0	0	3.0	
i 1	133.76886394557823	0.505	72	904	6	5	8	2	0	-2	2	0	0	2.1662443531096365	
i 1	133.76966666666667	0.7575000000000001	71	202	3	20	12	2	0	1	2	0	0	2.0	
i 1	133.990768707483	1.01	71	588	4	4	15	2	0	-2	2	0	0	3.0	
i 1	134.25602040816327	2.02	74	202	3	24	11	2	0	1	2	0	0	6.0	
i 1	134.26725850340137	0.505	74	202	1	20	6	2	0	1	2	0	0	2.0	
i 1	134.48354421768707	2.2725	74	202	3	1	12	2	0	-1	2	0	0	2.0438274789689523	
i 1	134.48755782312926	0.505	71	588	4	1	13	2	0	-2	2	0	0	2.0438274789689523	
i 1	134.5044149659864	0.2525	71	588	5	3	3	8	0	-2	8	0	0	3.0	
i 1	134.5044149659864	0.2525	71	904	3	20	8	8	0	-2	8	0	0	2.0	
i 1	134.5068231292517	0.2525	74	202	6	3	11	2	0	-2	2	0	0	3.0	
i 1	134.51485034013606	0.2525	74	904	3	20	4	2	0	1	2	0	0	2.0	
i 1	134.73916326530613	0.7575000000000001	74	202	6	9	1	2	0	-1	2	0	0	2.0	
i 1	134.7479931972789	0.2525	71	202	3	20	16	2	0	1	2	0	0	2.0	
i 1	134.75120408163266	0.2525	71	904	4	2	7	2	0	-2	2	0	0	3.0	
i 1	134.7520068027211	0.2525	74	202	2	24	9	2	0	-2	2	0	0	6.0	
i 1	134.76725850340137	1.5150000000000001	75	202	7	5	4	2	0	1	2	0	0	2.1662443531096365	
i 1	134.9819387755102	2.525	63	202	6	12	14	1	0	2	1	0	0	3.094852019400723	
i 1	134.9883605442177	1.2625	72	904	6	5	8	2	0	-2	2	0	0	2.1662443531096365	
i 1	134.99157142857143	16.665	63	588	5	13	6	16	0	1	16	0	0	0.6798674639746006	
i 1	134.99397959183673	0.2525	71	202	4	1	5	2	0	-1	2	0	0	2.0438274789689523	
i 1	134.99397959183673	0.2525	72	202	7	5	3	8	0	-2	8	0	0	2.1662443531096365	
i 1	134.99719047619047	1.5150000000000001	71	588	5	1	16	2	0	-2	2	0	0	2.0438274789689523	
i 1	134.99719047619047	0.505	74	202	3	20	15	2	0	-2	2	0	0	2.0	
i 1	134.99959863945577	0.505	71	904	6	2	15	2	0	-2	2	0	0	3.0	
i 1	135.2367551020408	1.01	71	202	2	24	2	2	0	1	2	0	0	6.0	
i 1	135.23755782312926	0.2525	74	202	3	20	14	2	0	1	2	0	0	2.0	
i 1	135.2455850340136	1.2625	74	904	6	2	8	2	0	-1	2	0	0	3.0	
i 1	135.259231292517	0.2525	71	202	3	20	7	2	0	1	2	0	0	2.0	
i 1	135.26003401360543	0.2525	71	588	4	24	12	8	0	-2	8	0	0	3.0438274789689523	
i 1	135.2632448979592	1.2625	71	202	6	9	4	2	0	-1	2	0	0	2.0	
i 1	135.7367551020408	1.5150000000000001	74	202	3	20	13	2	0	-2	2	0	0	2.0	
i 1	135.75040136054423	0.505	71	202	3	20	14	2	0	1	2	0	0	2.0	
i 1	135.76244217687074	0.2525	75	202	7	5	7	2	0	1	2	0	0	2.1662443531096365	
i 1	135.9843469387755	0.2525	74	202	6	3	1	2	0	-2	2	0	0	3.0	
i 1	136.00040136054423	0.505	72	588	6	5	12	2	0	-2	2	0	0	2.1662443531096365	
i 1	136.00521768707483	0.7575000000000001	72	202	7	5	11	8	0	-2	8	0	0	2.1662443531096365	
i 1	136.0180612244898	0.2525	74	904	5	1	12	2	0	-2	2	0	0	2.0438274789689523	
i 1	136.2479931972789	1.2625	75	202	7	5	14	2	0	1	2	0	0	2.1662443531096365	
i 1	136.2479931972789	1.2625	71	202	2	24	14	2	0	1	2	0	0	6.0	
i 1	136.24879591836734	1.2625	71	202	4	1	3	2	0	-1	2	0	0	2.0438274789689523	
i 1	136.24879591836734	0.2525	74	588	3	20	13	2	0	1	2	0	0	2.0	
i 1	136.24959863945577	1.2625	74	202	6	9	2	2	0	-1	2	0	0	2.0	
i 1	136.2520068027211	1.2625	71	904	5	1	8	8	0	-2	8	0	0	2.0438274789689523	
i 1	136.25602040816327	0.2525	74	904	3	20	3	2	0	1	2	0	0	2.0	
i 1	136.2616394557823	1.5150000000000001	71	904	6	2	9	2	0	-2	2	0	0	3.0	
i 1	136.48113605442177	0.2525	71	588	4	4	1	2	0	-2	2	0	0	3.0	
i 1	136.48916326530613	0.2525	71	202	2	20	10	2	0	-2	2	0	0	2.0	
i 1	136.49959863945577	0.2525	74	202	3	20	4	2	0	-2	2	0	0	2.0	
i 1	136.51083673469387	1.01	74	202	3	24	11	2	0	1	2	0	0	6.0	
i 1	136.51244217687074	0.2525	71	202	3	20	8	2	0	-2	2	0	0	2.0	
i 1	136.51485034013606	2.02	72	904	6	5	16	2	0	1	2	0	0	2.1662443531096365	
i 1	136.7319387755102	0.2525	74	904	5	1	10	2	0	-2	2	0	0	2.0438274789689523	
i 1	136.7544149659864	0.2525	72	904	6	5	15	2	0	-2	2	0	0	2.1662443531096365	
i 1	136.7568231292517	0.2525	74	904	3	20	11	2	0	1	2	0	0	2.0	
i 1	136.76886394557823	0.505	74	202	2	20	5	2	0	1	2	0	0	2.0	
i 1	136.98113605442177	0.2525	74	202	3	20	3	8	0	-2	8	0	0	2.0	
i 1	136.98996598639457	0.505	71	202	2	24	16	2	0	-2	2	0	0	6.0	
i 1	136.9955850340136	0.2525	75	202	7	5	16	2	0	1	2	0	0	2.1662443531096365	
i 1	137.0068231292517	0.505	74	202	3	20	15	2	0	-2	2	0	0	2.0	
i 1	137.2343469387755	0.2525	74	904	6	2	8	2	0	-1	2	0	0	3.0	
i 1	137.2367551020408	1.7675	71	588	4	24	8	8	0	-2	8	0	0	3.0438274789689523	
i 1	137.23996598639457	0.2525	71	202	3	24	6	8	0	-1	8	0	0	3.0438274789689523	
i 1	137.26886394557823	0.2525	72	588	6	5	16	2	0	1	2	0	0	2.1662443531096365	
i 1	137.4819387755102	4.2925	61	201	4	12	14	1	0	2	1	0	0	3.094852019400723	
i 1	137.48595238095237	0.2525	71	1170	4	1	7	8	0	-2	8	0	0	2.0438274789689523	
i 1	137.48595238095237	14.14	61	1170	4	16	9	16	0	2	16	0	0	3.094852019400723	
i 1	137.48595238095237	14.14	63	201	6	12	6	16	0	1	16	0	0	3.094852019400723	
i 1	137.4883605442177	0.2525	74	201	2	24	6	2	0	-2	2	0	0	6.0	
i 1	137.49157142857143	1.7675	71	201	6	3	13	2	0	-2	2	0	0	3.0	
i 1	137.49397959183673	1.7675	71	201	2	20	4	2	0	-2	2	0	0	2.0	
i 1	137.4955850340136	0.505	74	1170	5	9	5	8	0	-2	8	0	0	2.0	
i 1	137.49719047619047	0.7575000000000001	75	1170	6	5	1	2	0	1	2	0	0	2.1662443531096365	
i 1	137.4979931972789	0.2525	74	1170	3	24	11	2	0	-2	2	0	0	6.0	
i 1	137.5020068027211	1.5150000000000001	71	201	3	24	4	2	0	-2	2	0	0	3.0438274789689523	
i 1	137.50602040816327	1.7675	71	588	4	3	12	8	0	-2	8	0	0	3.0	
i 1	137.50602040816327	3.0300000000000002	74	1170	3	20	13	2	0	-2	2	0	0	2.0	
i 1	137.5068231292517	1.7675	74	201	2	24	11	2	0	1	2	0	0	6.0	
i 1	137.50842857142857	3.0300000000000002	71	1170	3	20	14	2	0	-2	2	0	0	2.0	
i 1	137.51886394557823	14.14	63	1170	4	16	14	16	0	2	16	0	0	3.094852019400723	
i 1	137.73595238095237	1.7675	72	904	6	5	7	2	0	-2	2	0	0	2.1662443531096365	
i 1	137.75521768707483	1.7675	72	1170	6	5	5	2	0	-2	2	0	0	2.1662443531096365	
i 1	138.00602040816327	0.2525	71	588	5	1	15	2	0	-2	2	0	0	2.0438274789689523	
i 1	138.25120408163266	2.7775	71	201	3	1	7	2	0	-1	2	0	0	2.0438274789689523	
i 1	138.49638775510203	2.525	71	588	5	1	5	2	0	-2	2	0	0	2.0438274789689523	
i 1	138.5068231292517	1.01	71	588	4	4	12	2	0	-2	2	0	0	3.0	
i 1	138.50762585034013	0.2525	75	1170	6	5	8	2	0	1	2	0	0	2.1662443531096365	
i 1	138.73514965986394	0.2525	72	201	7	5	4	8	0	1	8	0	0	2.1662443531096365	
i 1	138.7632448979592	0.7575000000000001	71	201	5	4	9	2	0	-1	2	0	0	3.0	
i 1	138.9883605442177	0.505	71	1170	4	1	1	8	0	-2	8	0	0	2.0438274789689523	
i 1	138.9931768707483	2.02	75	201	7	5	5	2	0	1	2	0	0	2.1662443531096365	
i 1	138.99719047619047	1.2625	71	1170	5	9	2	2	0	-1	2	0	0	2.0	
i 1	139.0180612244898	1.2625	74	904	6	2	14	2	0	-1	2	0	0	3.0	
i 1	139.01966666666667	2.2725	72	588	6	5	2	2	0	1	2	0	0	2.1662443531096365	
i 1	139.25521768707483	0.2525	74	1170	3	20	12	2	0	-2	2	0	0	2.0	
i 1	139.48274149659863	1.5150000000000001	74	201	2	24	13	2	0	-2	2	0	0	6.0	
i 1	139.4843469387755	0.2525	71	904	6	2	4	2	0	-2	2	0	0	3.0	
i 1	139.48755782312926	0.2525	74	1170	4	1	6	8	0	-2	8	0	0	2.0438274789689523	
i 1	139.48755782312926	1.01	74	201	2	24	12	2	0	1	2	0	0	6.0	
i 1	139.49638775510203	1.5150000000000001	74	201	2	20	15	2	0	-2	2	0	0	2.0	
i 1	139.50280952380953	0.2525	72	588	6	5	12	2	0	-2	2	0	0	2.1662443531096365	
i 1	139.51966666666667	1.01	71	201	2	20	11	2	0	-2	2	0	0	2.0	
i 1	139.73033333333333	0.2525	71	904	5	1	7	8	0	-2	8	0	0	2.0438274789689523	
i 1	139.74237414965987	1.5150000000000001	71	588	4	3	10	8	0	-2	8	0	0	3.0	
i 1	139.74397959183673	1.5150000000000001	71	201	6	3	3	2	0	-2	2	0	0	3.0	
i 1	139.75762585034013	1.2625	74	1170	3	20	16	2	0	-2	2	0	0	2.0	
i 1	139.7616394557823	0.2525	72	201	7	5	15	8	0	1	8	0	0	2.1662443531096365	
i 1	139.76725850340137	1.2625	74	1170	3	24	16	2	0	-2	2	0	0	6.0	
i 1	140.24237414965987	0.2525	71	904	5	1	12	8	0	-2	8	0	0	2.0438274789689523	
i 1	140.2656530612245	0.2525	72	904	6	5	3	2	0	-2	2	0	0	2.1662443531096365	
i 1	140.26886394557823	0.2525	71	904	6	2	6	2	0	-2	2	0	0	3.0	
i 1	140.48033333333333	1.7675	72	904	6	5	8	2	0	1	2	0	0	2.1662443531096365	
i 1	140.48755782312926	2.02	71	201	3	24	4	2	0	-2	2	0	0	3.0438274789689523	
i 1	140.48916326530613	1.7675	75	1170	6	5	2	2	0	1	2	0	0	2.1662443531096365	
i 1	140.50280952380953	1.2625	71	588	4	24	9	8	0	-2	8	0	0	3.0438274789689523	
i 1	140.5180612244898	0.2525	71	201	5	4	15	2	0	-1	2	0	0	3.0	
i 1	140.7319387755102	3.0300000000000002	74	1170	3	20	9	2	0	-2	2	0	0	2.0	
i 1	140.7343469387755	0.2525	74	904	6	2	13	2	0	-1	2	0	0	3.0	
i 1	140.7568231292517	1.5150000000000001	71	201	2	20	1	2	0	-2	2	0	0	2.0	
i 1	140.7616394557823	3.7875	71	1170	3	20	7	2	0	-2	2	0	0	2.0	
i 1	140.76966666666667	1.5150000000000001	74	201	2	24	4	2	0	1	2	0	0	6.0	
i 1	140.99879591836734	1.2625	71	904	6	2	5	2	0	-2	2	0	0	3.0	
i 1	141.01083673469387	0.2525	71	904	5	1	9	8	0	-2	8	0	0	2.0438274789689523	
i 1	141.0132448979592	1.2625	74	1170	5	9	4	8	0	-2	8	0	0	2.0	
i 1	141.24237414965987	0.505	72	588	6	5	2	2	0	-2	2	0	0	2.1662443531096365	
i 1	141.25762585034013	0.2525	74	1170	4	1	14	8	0	-2	8	0	0	2.0438274789689523	
i 1	141.48916326530613	0.2525	74	904	6	2	10	2	0	-1	2	0	0	3.0	
i 1	141.73916326530613	0.7575000000000001	72	588	6	5	1	2	0	1	2	0	0	2.1662443531096365	
i 1	141.74237414965987	9.8475	61	201	6	12	7	1	0	2	1	0	0	3.094852019400723	
i 1	141.7455850340136	0.2525	71	201	3	1	5	2	0	-1	2	0	0	2.0438274789689523	
i 1	141.75521768707483	0.7575000000000001	71	588	4	24	14	8	0	-2	8	0	0	3.0438274789689523	
i 1	141.75602040816327	9.8475	63	588	5	7	2	1	0	2	1	0	0	2.180033569360793	
i 1	141.76886394557823	0.7575000000000001	75	201	7	5	9	2	0	1	2	0	0	2.1662443531096365	
i 1	141.98274149659863	1.01	74	904	6	2	2	2	0	-1	2	0	0	3.0	
i 1	141.99638775510203	3.0300000000000002	71	1170	4	1	8	8	0	-2	8	0	0	2.0438274789689523	
i 1	142.0020068027211	2.02	72	1170	6	5	15	2	0	-2	2	0	0	2.1662443531096365	
i 1	142.01725850340137	2.02	72	904	6	5	6	2	0	-2	2	0	0	2.1662443531096365	
i 1	142.01886394557823	3.2825	71	904	5	1	9	8	0	-2	8	0	0	2.0438274789689523	
i 1	142.01966666666667	1.01	71	1170	5	9	6	2	0	-1	2	0	0	2.0	
i 1	142.24879591836734	1.5150000000000001	74	201	2	20	7	2	0	-2	2	0	0	2.0	
i 1	142.25120408163266	2.7775	74	201	2	24	13	2	0	-2	2	0	0	6.0	
i 1	142.26725850340137	0.2525	71	588	5	3	14	8	0	-2	8	0	0	3.0	
i 1	142.4843469387755	1.2625	71	904	6	2	8	2	0	-2	2	0	0	3.0	
i 1	142.4955850340136	1.5150000000000001	74	1170	5	9	15	8	0	-2	8	0	0	2.0	
i 1	142.49638775510203	0.2525	72	201	7	5	11	8	0	1	8	0	0	2.1662443531096365	
i 1	142.51645578231293	0.2525	74	1170	4	1	12	8	0	-2	8	0	0	2.0438274789689523	
i 1	142.73996598639457	0.2525	74	904	5	1	11	2	0	-2	2	0	0	2.0438274789689523	
i 1	142.75120408163266	1.5150000000000001	71	201	2	20	8	2	0	-2	2	0	0	2.0	
i 1	142.759231292517	0.2525	75	1170	6	5	12	2	0	1	2	0	0	2.1662443531096365	
i 1	142.7656530612245	1.01	74	201	2	24	3	2	0	1	2	0	0	6.0	
i 1	142.98514965986394	0.2525	71	201	3	24	5	2	0	-2	2	0	0	3.0438274789689523	
i 1	142.990768707483	1.7675	71	588	5	3	10	8	0	-2	8	0	0	3.0	
i 1	143.23354421768707	1.5150000000000001	71	201	6	3	16	2	0	-2	2	0	0	3.0	
i 1	143.25040136054423	1.01	71	201	3	1	3	2	0	-1	2	0	0	2.0438274789689523	
i 1	143.259231292517	1.01	71	588	5	1	5	2	0	-2	2	0	0	2.0438274789689523	
i 1	143.26485034013606	0.2525	72	588	6	5	4	2	0	1	2	0	0	2.1662443531096365	
i 1	143.48755782312926	1.5150000000000001	72	588	6	5	8	2	0	-2	2	0	0	2.1662443531096365	
i 1	143.50762585034013	1.5150000000000001	72	201	7	5	6	8	0	1	8	0	0	2.1662443531096365	
i 1	143.75040136054423	0.2525	74	588	3	24	3	2	0	-2	2	0	0	6.0	
i 1	143.76244217687074	0.2525	74	588	3	20	3	8	0	1	8	0	0	2.0	
i 1	143.76645578231293	0.2525	74	904	3	20	4	8	0	1	8	0	0	2.0	
i 1	143.98595238095237	0.2525	72	904	6	5	4	2	0	1	2	0	0	2.1662443531096365	
i 1	143.99719047619047	0.2525	71	201	2	20	9	8	0	1	8	0	0	2.0	
i 1	143.99959863945577	0.2525	71	201	2	24	2	2	0	-2	2	0	0	6.0	
i 1	144.00120408163266	0.2525	74	1170	3	20	4	2	0	1	2	0	0	2.0	
i 1	144.00280952380953	0.2525	74	904	6	2	11	2	0	-1	2	0	0	3.0	
i 1	144.00361224489797	1.01	74	1170	3	24	10	2	0	-2	2	0	0	6.0	
i 1	144.23916326530613	1.5150000000000001	71	588	4	4	1	2	0	-2	2	0	0	3.0	
i 1	144.2479931972789	1.5150000000000001	71	201	5	4	16	2	0	-1	2	0	0	3.0	
i 1	144.2544149659864	0.2525	72	904	6	5	15	2	0	-2	2	0	0	2.1662443531096365	
i 1	144.25842857142857	0.2525	74	904	5	1	10	2	0	-2	2	0	0	2.0438274789689523	
i 1	144.48595238095237	0.2525	71	1170	3	20	12	2	0	1	2	0	0	2.0	
i 1	144.49478231292517	0.2525	71	201	2	20	3	2	0	-2	2	0	0	2.0	
i 1	144.5020068027211	0.7575000000000001	72	904	6	5	12	2	0	1	2	0	0	2.1662443531096365	
i 1	144.50280952380953	0.2525	71	1170	3	20	14	2	0	-2	2	0	0	2.0	
i 1	144.50280952380953	1.01	71	201	2	20	2	2	0	-2	2	0	0	2.0	
i 1	144.51485034013606	2.525	71	588	4	24	14	8	0	-2	8	0	0	3.0438274789689523	
i 1	144.51485034013606	0.7575000000000001	75	1170	6	5	9	2	0	1	2	0	0	2.1662443531096365	
i 1	144.5156530612245	2.7775	71	201	3	24	12	2	0	-2	2	0	0	3.0438274789689523	
i 1	144.5180612244898	0.2525	74	201	2	24	11	8	0	1	8	0	0	6.0	
i 1	144.7343469387755	3.2825	72	1170	6	5	11	2	0	-2	2	0	0	2.1662443531096365	
i 1	144.73514965986394	0.505	74	588	3	20	3	8	0	-2	8	0	0	2.0	
i 1	144.74478231292517	0.505	71	904	3	20	1	2	0	-2	2	0	0	2.0	
i 1	144.759231292517	3.2825	72	904	6	5	2	2	0	-2	2	0	0	2.1662443531096365	
i 1	144.7656530612245	0.2525	71	904	6	2	13	2	0	-2	2	0	0	3.0	
i 1	144.7680612244898	3.0300000000000002	71	1170	3	20	15	2	0	-2	2	0	0	2.0	
i 1	144.9843469387755	1.7675	71	1170	5	9	2	2	0	-1	2	0	0	2.0	
i 1	145.25602040816327	0.2525	74	1170	3	20	6	2	0	-2	2	0	0	2.0	
i 1	145.2568231292517	1.5150000000000001	74	904	6	2	11	2	0	-1	2	0	0	3.0	
i 1	145.2568231292517	0.7575000000000001	74	201	2	24	8	2	0	-2	2	0	0	6.0	
i 1	145.259231292517	0.2525	72	588	6	5	3	2	0	1	2	0	0	2.1662443531096365	
i 1	145.26404761904763	0.2525	71	201	2	20	8	2	0	-2	2	0	0	2.0	
i 1	145.2680612244898	0.2525	74	1170	3	20	6	2	0	-2	2	0	0	2.0	
i 1	145.26966666666667	0.2525	74	904	5	1	3	2	0	-2	2	0	0	2.0438274789689523	
i 1	145.4867551020408	0.2525	71	904	3	20	4	2	0	-2	2	0	0	2.0	
i 1	145.49237414965987	0.505	75	201	7	5	2	2	0	1	2	0	0	2.1662443531096365	
i 1	145.4955850340136	0.505	71	588	5	1	12	2	0	-2	2	0	0	2.0438274789689523	
i 1	145.50521768707483	0.2525	71	904	3	20	12	2	0	1	2	0	0	2.0	
i 1	145.51003401360543	2.02	74	1170	3	24	14	2	0	-2	2	0	0	6.0	
i 1	145.73113605442177	0.2525	71	201	6	3	4	2	0	-2	2	0	0	3.0	
i 1	145.74478231292517	0.7575000000000001	71	1170	3	20	14	2	0	-2	2	0	0	2.0	
i 1	145.759231292517	0.7575000000000001	74	1170	3	20	10	2	0	1	2	0	0	2.0	
i 1	145.98514965986394	0.2525	74	1170	4	1	4	8	0	-2	8	0	0	2.0438274789689523	
i 1	146.0068231292517	0.2525	74	1170	5	9	8	8	0	-2	8	0	0	2.0	
i 1	146.009231292517	0.2525	72	201	7	5	12	8	0	1	8	0	0	2.1662443531096365	
i 1	146.240768707483	0.2525	75	201	7	5	5	2	0	1	2	0	0	2.1662443531096365	
i 1	146.24638775510203	0.2525	74	904	5	1	6	2	0	-2	2	0	0	2.0438274789689523	
i 1	146.25521768707483	2.2725	74	201	2	24	2	2	0	-2	2	0	0	6.0	
i 1	146.25842857142857	1.2625	71	201	6	3	3	2	0	-2	2	0	0	3.0	
i 1	146.2680612244898	1.2625	71	588	5	3	10	8	0	-2	8	0	0	3.0	
i 1	146.49638775510203	2.02	71	201	2	20	13	2	0	-2	2	0	0	2.0	
i 1	146.4979931972789	0.505	74	904	3	20	14	2	0	1	2	0	0	2.0	
i 1	146.5044149659864	0.505	74	904	3	20	3	2	0	-2	2	0	0	2.0	
i 1	146.50521768707483	0.505	71	588	3	20	4	2	0	-2	2	0	0	2.0	
i 1	146.509231292517	3.2825	71	588	5	1	10	2	0	-2	2	0	0	2.0438274789689523	
i 1	146.51645578231293	3.2825	71	201	3	1	1	2	0	-1	2	0	0	2.0438274789689523	
i 1	146.7520068027211	2.525	71	904	6	2	1	2	0	-2	2	0	0	3.0	
i 1	146.98354421768707	0.2525	72	904	6	5	11	2	0	1	2	0	0	2.1662443531096365	
i 1	146.99237414965987	0.2525	74	201	2	20	15	2	0	-2	2	0	0	2.0	
i 1	146.9931768707483	0.2525	71	1170	3	20	7	8	0	-2	8	0	0	2.0	
i 1	147.01485034013606	0.2525	71	1170	3	20	9	2	0	1	2	0	0	2.0	
i 1	147.01886394557823	2.2725	74	1170	5	9	1	8	0	-2	8	0	0	2.0	
i 1	147.23274149659863	0.2525	71	588	3	20	6	2	0	1	2	0	0	2.0	
i 1	147.24638775510203	0.2525	74	904	3	20	2	2	0	1	2	0	0	2.0	
i 1	147.25602040816327	0.2525	71	904	3	20	12	2	0	1	2	0	0	2.0	
i 1	147.26404761904763	0.2525	71	588	4	24	16	8	0	-2	8	0	0	3.0438274789689523	
i 1	147.49157142857143	0.2525	71	1170	3	20	4	2	0	-2	2	0	0	2.0	
i 1	147.49638775510203	0.2525	71	588	4	4	15	2	0	-2	2	0	0	3.0	
i 1	147.50361224489797	0.505	71	904	5	1	13	8	0	-2	8	0	0	2.0438274789689523	
i 1	147.5044149659864	0.7575000000000001	75	201	7	5	9	2	0	1	2	0	0	2.1662443531096365	
i 1	147.5116394557823	0.2525	71	201	2	20	4	2	0	1	2	0	0	2.0	
i 1	147.51485034013606	0.7575000000000001	72	588	6	5	8	2	0	1	2	0	0	2.1662443531096365	
i 1	147.73274149659863	0.505	74	904	3	20	3	2	0	1	2	0	0	2.0	
i 1	147.740768707483	0.7575000000000001	72	904	6	5	9	2	0	1	2	0	0	2.1662443531096365	
i 1	147.74959863945577	2.02	75	1170	6	5	10	2	0	1	2	0	0	2.1662443531096365	
i 1	147.75040136054423	0.7575000000000001	71	1170	5	9	7	2	0	-1	2	0	0	2.0	
i 1	147.75120408163266	0.7575000000000001	74	904	6	2	6	2	0	-1	2	0	0	3.0	
i 1	147.75602040816327	0.505	71	588	3	20	1	8	0	1	8	0	0	2.0	
i 1	147.9843469387755	0.2525	74	904	5	1	3	2	0	-2	2	0	0	2.0438274789689523	
i 1	147.99237414965987	2.525	71	1170	3	20	13	2	0	-2	2	0	0	2.0	
i 1	148.00040136054423	0.2525	74	904	3	20	13	2	0	-2	2	0	0	2.0	
i 1	148.00361224489797	1.01	74	1170	3	24	5	2	0	-2	2	0	0	6.0	
i 1	148.24157142857143	0.7575000000000001	74	1170	3	20	15	2	0	-2	2	0	0	2.0	
i 1	148.25521768707483	0.2525	71	904	5	1	14	8	0	-2	8	0	0	2.0438274789689523	
i 1	148.26003401360543	0.7575000000000001	71	1170	3	20	14	2	0	-2	2	0	0	2.0	
i 1	148.26083673469387	0.505	72	1170	6	5	1	2	0	-2	2	0	0	2.1662443531096365	
i 1	148.2656530612245	0.2525	74	201	2	20	6	2	0	-2	2	0	0	2.0	
i 1	148.49157142857143	2.7775	71	201	6	3	7	2	0	-2	2	0	0	3.0	
i 1	148.49478231292517	1.5150000000000001	72	904	6	5	1	2	0	1	2	0	0	2.1662443531096365	
i 1	148.74397959183673	1.01	71	201	2	20	15	2	0	-2	2	0	0	2.0	
i 1	148.74638775510203	2.7775	71	588	5	3	8	8	0	-2	8	0	0	3.0	
i 1	148.74959863945577	0.2525	74	201	2	20	2	2	0	-2	2	0	0	2.0	
i 1	148.75762585034013	2.7775	74	201	2	24	14	2	0	-2	2	0	0	6.0	
i 1	148.7632448979592	0.2525	72	588	6	5	12	2	0	-2	2	0	0	2.1662443531096365	
i 1	148.98274149659863	0.2525	74	1170	4	1	12	8	0	-2	8	0	0	2.0438274789689523	
i 1	148.98354421768707	0.505	74	588	3	20	7	2	0	-2	2	0	0	2.0	
i 1	149.00120408163266	0.505	71	904	3	20	13	2	0	1	2	0	0	2.0	
i 1	149.01725850340137	1.7675	72	588	6	5	5	2	0	1	2	0	0	2.1662443531096365	
i 1	149.23514965986394	1.01	71	201	3	24	12	2	0	-2	2	0	0	3.0438274789689523	
i 1	149.24959863945577	1.5150000000000001	75	201	7	5	4	2	0	1	2	0	0	2.1662443531096365	
i 1	149.2568231292517	1.01	71	588	4	24	4	8	0	-2	8	0	0	3.0438274789689523	
i 1	149.2616394557823	0.505	71	201	5	4	13	2	0	-1	2	0	0	3.0	
i 1	149.48514965986394	0.505	71	1170	3	20	16	2	0	-2	2	0	0	2.0	
i 1	149.4931768707483	0.505	71	201	2	20	5	2	0	-2	2	0	0	2.0	
i 1	149.73996598639457	1.2625	71	904	6	1	14	8	0	-2	8	0	0	2.0438274789689523	
i 1	149.7431768707483	0.2525	74	1170	5	9	9	8	0	-2	8	0	0	2.0	
i 1	149.75280952380953	1.2625	71	1170	5	1	3	8	0	-2	8	0	0	2.0438274789689523	
i 1	149.76244217687074	0.2525	71	1170	3	20	1	2	0	-2	2	0	0	2.0	
i 1	149.9819387755102	0.2525	74	904	3	20	1	2	0	-2	2	0	0	2.0	
i 1	149.990768707483	0.2525	71	588	3	20	16	2	0	-2	2	0	0	2.0	
i 1	149.9931768707483	0.2525	71	904	3	20	1	8	0	-2	8	0	0	2.0	
i 1	150.01003401360543	1.5150000000000001	72	904	6	5	11	2	0	-2	2	0	0	2.1662443531096365	
i 1	150.01244217687074	0.2525	71	588	4	4	11	2	0	-2	2	0	0	3.0	
i 1	150.0180612244898	1.01	74	1170	3	24	4	2	0	-2	2	0	0	6.0	
i 1	150.23033333333333	0.2525	74	904	5	1	16	2	0	-2	2	0	0	2.0438274789689523	
i 1	150.2319387755102	0.7575000000000001	72	1170	6	5	8	2	0	-2	2	0	0	2.1662443531096365	
i 1	150.240768707483	0.2525	74	904	5	2	14	2	0	-1	2	0	0	3.0	
i 1	150.24959863945577	1.2625	71	201	2	20	14	2	0	-2	2	0	0	2.0	
i 1	150.25521768707483	0.2525	71	1170	3	20	12	8	0	1	8	0	0	2.0	
i 1	150.26485034013606	0.7575000000000001	71	1170	3	20	15	2	0	1	2	0	0	2.0	
i 1	150.4819387755102	1.01	71	201	3	1	13	2	0	-1	2	0	0	2.0438274789689523	
i 1	150.4931768707483	1.01	72	201	7	5	3	8	0	1	8	0	0	2.1662443531096365	
i 1	150.49397959183673	1.01	71	588	4	4	11	2	0	-2	2	0	0	3.0	
i 1	150.50120408163266	1.01	72	588	6	5	12	2	0	-2	2	0	0	2.1662443531096365	
i 1	150.51645578231293	1.01	71	588	5	1	10	2	0	-2	2	0	0	2.0438274789689523	
i 1	150.7383605442177	0.7575000000000001	71	201	5	4	4	2	0	-1	2	0	0	3.0	
i 1	150.98113605442177	0.505	71	1170	3	20	7	8	0	1	8	0	0	2.0	
i 1	150.99237414965987	0.505	71	1170	3	20	14	2	0	-2	2	0	0	2.0	
i 1	150.99719047619047	0.2525	71	201	3	24	15	2	0	-2	2	0	0	3.0438274789689523	
i 1	151.24879591836734	0.2525	71	588	4	24	11	8	0	-2	8	0	0	3.0438274789689523	
i 1	151.25280952380953	0.2525	75	1170	6	5	7	2	0	1	2	0	0	2.1662443531096365	
i 1	151.2544149659864	0.2525	71	1170	5	1	4	8	0	-2	8	0	0	2.0438274789689523	
i 1	151.48033333333333	1.01	74	1102	2	20	1	2	0	1	2	0	0	2.0	
i 1	151.48033333333333	2.2725	74	716	1	24	11	2	0	1	2	0	0	6.0	
i 1	151.48113605442177	2.02	72	716	6	5	3	2	0	-2	2	0	0	2.1662443531096365	
i 1	151.48274149659863	17.4225	63	716	5	14	5	1	0	1	1	0	0	2.930116622053889	
i 1	151.48514965986394	1.7675	72	1102	6	5	11	2	0	-2	2	0	0	2.1662443531096365	
i 1	151.4867551020408	3.0300000000000002	74	1102	4	1	5	2	0	-1	2	0	0	2.0438274789689523	
i 1	151.4867551020408	0.505	71	1102	2	20	5	2	0	-2	2	0	0	2.0	
i 1	151.48755782312926	31.0575	63	218	5	13	16	16	0	2	16	0	0	0.6798674639746006	
i 1	151.48916326530613	0.2525	71	218	5	1	10	8	0	-1	8	0	0	2.0438274789689523	
i 1	151.490768707483	44.6925	63	716	5	12	6	1	0	2	1	0	0	3.094852019400723	
i 1	151.49157142857143	1.01	74	218	6	3	12	8	0	-2	8	0	0	3.0	
i 1	151.4931768707483	24.240000000000002	63	218	6	15	6	16	0	1	16	0	0	1.9192017177729124	
i 1	151.49638775510203	0.505	74	716	1	20	16	2	0	-2	2	0	0	2.0	
i 1	151.4979931972789	17.4225	63	218	6	15	11	1	0	2	1	0	0	1.9192017177729124	
i 1	151.49959863945577	3.0300000000000002	71	218	5	24	5	2	0	-2	2	0	0	3.0438274789689523	
i 1	151.50040136054423	37.875	61	1102	4	16	9	16	0	1	16	0	0	3.094852019400723	
i 1	151.5020068027211	24.240000000000002	61	716	5	14	15	16	0	2	16	0	0	2.930116622053889	
i 1	151.50280952380953	10.605	61	716	5	13	13	16	0	2	16	0	0	0.743551416145102	
i 1	151.50602040816327	0.505	75	716	6	5	5	2	0	1	2	0	0	2.1662443531096365	
i 1	151.50762585034013	3.7875	63	716	5	14	13	1	0	2	1	0	0	4.270502321028533	
i 1	151.50762585034013	37.875	61	218	5	7	15	1	0	1	1	0	0	2.180033569360793	
i 1	151.509231292517	0.2525	72	218	7	5	1	2	0	-2	2	0	0	2.1662443531096365	
i 1	151.51003401360543	31.0575	61	1102	4	16	15	1	0	2	1	0	0	3.094852019400723	
i 1	151.51244217687074	1.01	74	716	4	4	5	2	0	-1	2	0	0	3.0	
i 1	151.51886394557823	0.505	74	218	5	4	7	2	0	-1	2	0	0	3.0	
i 1	151.51966666666667	51.51	61	716	5	12	14	16	0	2	16	0	0	3.094852019400723	
i 1	151.98514965986394	0.7575000000000001	74	716	6	2	4	8	0	-2	8	0	0	3.0	
i 1	151.98755782312926	0.2525	74	218	3	20	12	8	0	1	8	0	0	2.0	
i 1	152.0044149659864	0.2525	75	716	6	5	5	2	0	1	2	0	0	2.1662443531096365	
i 1	152.00602040816327	0.2525	74	716	3	20	4	2	0	-2	2	0	0	2.0	
i 1	152.01404761904763	3.0300000000000002	71	716	1	20	3	2	0	1	2	0	0	2.0	
i 1	152.0156530612245	0.7575000000000001	74	716	5	3	9	2	0	-1	2	0	0	3.0	
i 1	152.23514965986394	2.7775	75	1102	6	5	12	2	0	-2	2	0	0	2.1662443531096365	
i 1	152.25361224489797	1.2625	74	716	5	2	11	2	0	-1	2	0	0	3.0	
i 1	152.2544149659864	0.2525	71	1102	2	20	5	2	0	-2	2	0	0	2.0	
i 1	152.25602040816327	1.2625	71	1102	5	9	6	2	0	-1	2	0	0	2.0	
i 1	152.2680612244898	1.5150000000000001	71	716	1	20	15	2	0	1	2	0	0	2.0	
i 1	152.75120408163266	0.2525	74	218	6	3	9	8	0	-2	8	0	0	3.0	
i 1	152.76725850340137	2.02	72	218	7	5	9	2	0	1	2	0	0	2.1662443531096365	
i 1	152.76886394557823	1.01	71	1102	2	20	5	2	0	-2	2	0	0	2.0	
i 1	153.01244217687074	1.5150000000000001	74	716	6	2	2	8	0	-2	8	0	0	3.0	
i 1	153.01645578231293	1.7675	74	716	5	3	6	2	0	-1	2	0	0	3.0	
i 1	153.24397959183673	0.2525	71	716	6	1	11	8	0	-2	8	0	0	2.0438274789689523	
i 1	153.25602040816327	6.3125	74	1102	2	20	10	2	0	1	2	0	0	2.0	
i 1	153.2680612244898	0.505	71	1102	2	20	5	2	0	1	2	0	0	2.0	
i 1	153.48996598639457	2.7775	71	218	5	1	13	8	0	-1	8	0	0	2.0438274789689523	
i 1	153.49237414965987	0.7575000000000001	71	1102	2	24	10	2	0	-2	2	0	0	6.0	
i 1	153.49478231292517	0.2525	75	716	6	5	16	2	0	1	2	0	0	2.1662443531096365	
i 1	153.5068231292517	0.2525	71	1102	3	9	6	8	0	-2	8	0	0	2.0	
i 1	153.73514965986394	0.2525	74	716	3	20	11	2	0	1	2	0	0	2.0	
i 1	153.7383605442177	2.525	74	218	6	3	16	8	0	-2	8	0	0	3.0	
i 1	153.75842857142857	0.2525	72	1102	6	5	1	2	0	-2	2	0	0	2.1662443531096365	
i 1	153.75842857142857	0.2525	71	218	3	20	5	2	0	1	2	0	0	2.0	
i 1	153.98354421768707	1.7675	75	716	6	5	1	2	0	1	2	0	0	2.1662443531096365	
i 1	153.98996598639457	2.2725	74	716	4	4	3	2	0	-1	2	0	0	3.0	
i 1	153.99237414965987	0.2525	74	716	1	20	12	2	0	-2	2	0	0	2.0	
i 1	153.99397959183673	2.525	74	716	2	24	3	2	0	-2	2	0	0	3.0438274789689523	
i 1	153.9979931972789	0.2525	71	716	1	24	11	8	0	1	8	0	0	6.0	
i 1	154.01003401360543	0.2525	74	1102	2	20	4	2	0	1	2	0	0	2.0	
i 1	154.01886394557823	0.7575000000000001	74	716	1	24	11	2	0	1	2	0	0	6.0	
i 1	154.26404761904763	1.5150000000000001	75	716	6	5	2	2	0	1	2	0	0	2.1662443531096365	
i 1	154.4819387755102	1.2625	71	1102	2	24	12	2	0	-2	2	0	0	6.0	
i 1	154.50120408163266	0.2525	71	716	1	24	4	8	0	1	8	0	0	6.0	
i 1	154.50602040816327	0.2525	71	716	6	1	15	8	0	-2	8	0	0	2.0438274789689523	
i 1	154.74157142857143	0.2525	71	218	3	24	2	2	0	1	2	0	0	6.0	
i 1	154.7431768707483	0.2525	74	716	3	20	14	8	0	1	8	0	0	2.0	
i 1	154.74397959183673	0.2525	74	716	5	2	7	2	0	-1	2	0	0	3.0	
i 1	154.7616394557823	0.2525	71	716	2	1	7	2	0	-1	2	0	0	2.0438274789689523	
i 1	154.99157142857143	0.7575000000000001	71	1102	2	20	8	2	0	1	2	0	0	2.0	
i 1	155.00120408163266	1.01	72	218	7	5	9	2	0	1	2	0	0	2.1662443531096365	
i 1	155.01003401360543	0.2525	71	1102	3	9	11	8	0	-2	8	0	0	2.0	
i 1	155.0132448979592	0.7575000000000001	71	716	1	24	3	8	0	-2	8	0	0	6.0	
i 1	155.01725850340137	0.2525	74	716	5	1	15	8	0	-2	8	0	0	2.0438274789689523	
i 1	155.23354421768707	1.7675	71	218	5	24	14	2	0	-2	2	0	0	3.0438274789689523	
i 1	155.2343469387755	0.505	71	716	1	20	16	8	0	-2	8	0	0	2.0	
i 1	155.23755782312926	47.722500000000004	63	716	5	14	12	1	0	2	1	0	0	4.270502321028533	
i 1	155.24237414965987	0.7575000000000001	75	1102	6	5	2	2	0	-2	2	0	0	2.1662443531096365	
i 1	155.24879591836734	0.505	74	1102	2	20	13	2	0	-2	2	0	0	2.0	
i 1	155.25120408163266	5.555	74	716	1	24	4	2	0	1	2	0	0	6.0	
i 1	155.25361224489797	0.2525	74	716	4	2	11	2	0	-1	2	0	0	3.0	
i 1	155.25762585034013	0.7575000000000001	71	716	1	20	12	2	0	1	2	0	0	2.0	
i 1	155.2656530612245	47.722500000000004	63	716	5	25	3	1	0	2	1	0	0	10.329861253871739	
i 1	155.4819387755102	2.02	72	716	6	5	7	2	0	-2	2	0	0	2.1662443531096365	
i 1	155.5132448979592	2.02	72	1102	6	5	14	2	0	-2	2	0	0	2.1662443531096365	
i 1	155.51966666666667	1.5150000000000001	74	218	5	4	10	2	0	-1	2	0	0	3.0	
i 1	155.74719047619047	1.2625	71	1102	5	9	7	8	0	-2	8	0	0	2.0	
i 1	155.74959863945577	0.2525	71	218	3	20	4	2	0	1	2	0	0	2.0	
i 1	155.75762585034013	1.2625	74	1102	4	1	1	2	0	-1	2	0	0	2.0438274789689523	
i 1	155.76003401360543	0.2525	71	716	3	20	16	2	0	1	2	0	0	2.0	
i 1	155.98514965986394	0.2525	72	716	6	5	5	8	0	1	8	0	0	2.1662443531096365	
i 1	155.98996598639457	1.7675	71	1102	2	20	16	2	0	1	2	0	0	2.0	
i 1	156.0116394557823	0.2525	74	716	1	20	4	2	0	-2	2	0	0	2.0	
i 1	156.24397959183673	0.2525	75	1102	6	5	14	2	0	-2	2	0	0	2.1662443531096365	
i 1	156.2632448979592	0.2525	74	716	5	2	9	8	0	-2	8	0	0	3.0	
i 1	156.26404761904763	1.5150000000000001	74	1102	2	20	16	2	0	-2	2	0	0	2.0	
i 1	156.49157142857143	0.7575000000000001	71	1102	3	9	8	2	0	-1	2	0	0	2.0	
i 1	156.49237414965987	1.5150000000000001	71	716	6	1	6	8	0	-2	8	0	0	2.0438274789689523	
i 1	156.50120408163266	2.02	74	1102	4	1	6	2	0	-2	2	0	0	2.0438274789689523	
i 1	156.50602040816327	0.7575000000000001	74	716	4	2	15	2	0	-1	2	0	0	3.0	
i 1	156.73354421768707	1.01	71	1102	2	24	12	2	0	-2	2	0	0	6.0	
i 1	156.73514965986394	0.2525	75	1102	6	5	6	2	0	-2	2	0	0	2.1662443531096365	
i 1	156.73996598639457	1.2625	74	716	4	4	4	2	0	-1	2	0	0	3.0	
i 1	156.74959863945577	1.01	74	716	1	24	8	2	0	-2	2	0	0	6.0	
i 1	156.7680612244898	1.2625	74	218	6	3	6	8	0	-2	8	0	0	3.0	
i 1	156.98996598639457	1.7675	72	218	7	5	15	2	0	-2	2	0	0	2.1662443531096365	
i 1	156.99719047619047	1.7675	72	716	6	5	1	8	0	1	8	0	0	2.1662443531096365	
i 1	157.01083673469387	0.2525	71	716	2	1	9	2	0	-1	2	0	0	2.0438274789689523	
i 1	157.23033333333333	0.7575000000000001	71	716	1	20	14	2	0	1	2	0	0	2.0	
i 1	157.23113605442177	1.7675	74	716	5	2	1	8	0	-2	8	0	0	3.0	
i 1	157.2319387755102	0.505	74	716	1	20	6	2	0	-2	2	0	0	2.0	
i 1	157.26645578231293	0.2525	71	218	5	24	13	2	0	-2	2	0	0	3.0438274789689523	
i 1	157.4819387755102	1.7675	71	218	5	1	10	8	0	-1	8	0	0	2.0438274789689523	
i 1	157.490768707483	1.7675	74	716	5	3	13	2	0	-1	2	0	0	3.0	
i 1	157.49719047619047	0.2525	75	716	6	5	13	2	0	1	2	0	0	2.1662443531096365	
i 1	157.51886394557823	1.7675	74	716	2	24	6	2	0	-2	2	0	0	3.0438274789689523	
i 1	157.7319387755102	0.2525	71	716	3	20	13	2	0	1	2	0	0	2.0	
i 1	157.75120408163266	0.2525	71	218	3	20	3	2	0	-2	2	0	0	2.0	
i 1	157.76725850340137	0.2525	72	218	7	5	16	2	0	1	2	0	0	2.1662443531096365	
i 1	157.98113605442177	0.7575000000000001	74	1102	2	20	4	2	0	-2	2	0	0	2.0	
i 1	157.98274149659863	0.2525	74	716	1	20	6	2	0	1	2	0	0	2.0	
i 1	158.0116394557823	2.02	74	716	4	2	11	2	0	-1	2	0	0	3.0	
i 1	158.01645578231293	0.2525	75	1102	6	5	3	2	0	-2	2	0	0	2.1662443531096365	
i 1	158.01966666666667	0.7575000000000001	74	1102	2	20	2	2	0	-2	2	0	0	2.0	
i 1	158.25361224489797	0.7575000000000001	75	716	6	5	10	2	0	1	2	0	0	2.1662443531096365	
i 1	158.2568231292517	1.01	75	716	6	5	8	2	0	1	2	0	0	2.1662443531096365	
i 1	158.48595238095237	3.0300000000000002	72	1102	6	5	4	2	0	-2	2	0	0	2.1662443531096365	
i 1	158.49719047619047	0.2525	71	716	2	1	11	2	0	-1	2	0	0	2.0438274789689523	
i 1	158.49719047619047	3.0300000000000002	72	716	6	5	1	2	0	-2	2	0	0	2.1662443531096365	
i 1	158.51003401360543	0.2525	74	716	1	20	15	2	0	1	2	0	0	2.0	
i 1	158.51645578231293	1.5150000000000001	71	1102	3	9	2	2	0	-1	2	0	0	2.0	
i 1	158.7319387755102	0.505	71	218	3	20	1	2	0	1	2	0	0	2.0	
i 1	158.74478231292517	2.02	71	716	6	1	10	8	0	-2	8	0	0	2.0438274789689523	
i 1	158.74478231292517	0.505	74	716	3	20	4	2	0	1	2	0	0	2.0	
i 1	158.74879591836734	2.02	74	1102	4	1	14	2	0	-2	2	0	0	2.0438274789689523	
i 1	159.0116394557823	3.2825	71	716	1	20	16	2	0	1	2	0	0	2.0	
i 1	159.24397959183673	2.02	74	716	1	20	10	2	0	-2	2	0	0	2.0	
i 1	159.2479931972789	0.7575000000000001	75	1102	6	5	6	2	0	-2	2	0	0	2.1662443531096365	
i 1	159.259231292517	0.2525	71	716	2	1	15	2	0	-1	2	0	0	2.0438274789689523	
i 1	159.259231292517	1.5150000000000001	71	1102	2	20	3	2	0	-2	2	0	0	2.0	
i 1	159.2656530612245	0.2525	74	716	4	4	10	2	0	-1	2	0	0	3.0	
i 1	159.4819387755102	0.2525	74	716	6	1	7	8	0	-2	8	0	0	2.0438274789689523	
i 1	159.4819387755102	1.2625	74	716	5	3	10	2	0	-1	2	0	0	3.0	
i 1	159.5068231292517	1.2625	74	716	5	2	1	8	0	-2	8	0	0	3.0	
i 1	159.98755782312926	0.2525	71	1102	5	9	10	8	0	-2	8	0	0	2.0	
i 1	159.99478231292517	0.2525	72	218	7	5	2	2	0	-2	2	0	0	2.1662443531096365	
i 1	160.01725850340137	0.2525	74	716	2	24	12	2	0	-2	2	0	0	3.0438274789689523	
i 1	160.2544149659864	2.2725	74	1102	2	20	7	2	0	1	2	0	0	2.0	
i 1	160.25842857142857	2.2725	71	218	5	24	15	2	0	-2	2	0	0	3.0438274789689523	
i 1	160.259231292517	1.01	71	1102	2	20	3	2	0	-2	2	0	0	2.0	
i 1	160.26083673469387	2.2725	74	1102	4	1	1	2	0	-1	2	0	0	2.0438274789689523	
i 1	160.26404761904763	1.5150000000000001	74	218	6	3	4	8	0	-2	8	0	0	3.0	
i 1	160.26485034013606	1.5150000000000001	74	716	4	4	1	2	0	-1	2	0	0	3.0	
i 1	160.26886394557823	0.2525	72	218	7	5	1	2	0	1	2	0	0	2.1662443531096365	
i 1	160.73033333333333	0.2525	72	218	7	5	8	2	0	-2	2	0	0	2.1662443531096365	
i 1	160.7319387755102	0.2525	74	716	4	2	7	2	0	-1	2	0	0	3.0	
i 1	160.74638775510203	0.505	71	218	5	1	11	8	0	-1	8	0	0	2.0438274789689523	
i 1	160.99879591836734	0.2525	71	1102	2	20	10	2	0	-2	2	0	0	2.0	
i 1	161.00280952380953	0.2525	74	716	5	2	15	8	0	-2	8	0	0	3.0	
i 1	161.00602040816327	0.7575000000000001	71	1102	2	24	5	2	0	-2	2	0	0	6.0	
i 1	161.0068231292517	0.7575000000000001	75	1102	6	5	6	2	0	-2	2	0	0	2.1662443531096365	
i 1	161.01886394557823	0.7575000000000001	72	218	7	5	9	2	0	1	2	0	0	2.1662443531096365	
i 1	161.2455850340136	0.2525	74	716	3	20	4	2	0	1	2	0	0	2.0	
i 1	161.24719047619047	1.2625	71	1102	5	9	14	8	0	-2	8	0	0	2.0	
i 1	161.2479931972789	2.02	75	716	6	5	1	2	0	1	2	0	0	2.1662443531096365	
i 1	161.2479931972789	2.02	75	716	6	5	10	2	0	1	2	0	0	2.1662443531096365	
i 1	161.2479931972789	0.2525	74	218	3	20	7	2	0	1	2	0	0	2.0	
i 1	161.25602040816327	0.2525	71	716	3	20	2	2	0	-2	2	0	0	2.0	
i 1	161.26244217687074	1.2625	74	218	5	4	4	2	0	-1	2	0	0	3.0	
i 1	161.26645578231293	2.525	74	716	1	24	1	2	0	1	2	0	0	6.0	
i 1	161.26966666666667	0.2525	71	716	2	1	11	2	0	-1	2	0	0	2.0438274789689523	
i 1	161.49478231292517	0.2525	74	1102	4	1	14	2	0	-2	2	0	0	2.0438274789689523	
i 1	161.49478231292517	0.505	71	716	1	20	15	8	0	-2	8	0	0	2.0	
i 1	161.51003401360543	0.2525	71	1102	2	20	2	8	0	1	8	0	0	2.0	
i 1	161.51966666666667	0.505	71	1102	2	20	9	8	0	1	8	0	0	2.0	
i 1	161.73354421768707	0.2525	74	716	5	3	16	2	0	-1	2	0	0	3.0	
i 1	161.73514965986394	0.2525	72	716	6	5	4	2	0	-2	2	0	0	2.1662443531096365	
i 1	161.75361224489797	0.2525	71	218	5	1	16	8	0	-1	8	0	0	2.0438274789689523	
i 1	161.9819387755102	40.905	63	716	5	25	14	16	0	2	16	0	0	10.329861253871739	
i 1	161.9843469387755	40.905	61	716	5	13	15	16	0	2	16	0	0	0.743551416145102	
i 1	161.98514965986394	0.2525	71	218	3	20	15	8	0	1	8	0	0	2.0	
i 1	161.9867551020408	1.5150000000000001	71	1102	5	9	13	2	0	-1	2	0	0	2.0	
i 1	161.990768707483	2.02	74	716	2	24	14	2	0	-2	2	0	0	3.0438274789689523	
i 1	161.9955850340136	0.2525	74	716	3	20	14	2	0	-2	2	0	0	2.0	
i 1	162.0044149659864	40.905	61	716	6	17	10	16	0	2	16	0	0	4.574761808462703	
i 1	162.00842857142857	0.2525	72	218	7	5	12	2	0	1	2	0	0	2.1662443531096365	
i 1	162.009231292517	2.02	71	218	7	1	6	8	0	-1	8	0	0	2.0438274789689523	
i 1	162.01404761904763	1.5150000000000001	74	716	4	2	7	2	0	-1	2	0	0	3.0	
i 1	162.2367551020408	1.01	74	1102	2	20	1	2	0	1	2	0	0	2.0	
i 1	162.24879591836734	0.505	72	716	6	5	13	8	0	1	8	0	0	2.1662443531096365	
i 1	162.24879591836734	0.2525	71	716	1	20	7	2	0	1	2	0	0	2.0	
i 1	162.48514965986394	0.2525	74	716	4	2	14	8	0	-2	8	0	0	3.0	
i 1	162.5020068027211	0.2525	74	1102	1	20	12	2	0	1	2	0	0	2.0	
i 1	162.51083673469387	0.2525	74	1102	4	1	13	2	0	-2	2	0	0	2.0438274789689523	
i 1	162.73113605442177	0.2525	72	1102	6	5	4	2	0	-2	2	0	0	2.1662443531096365	
i 1	162.76244217687074	0.2525	74	218	5	4	2	2	0	-1	2	0	0	3.0	
i 1	162.98514965986394	1.5150000000000001	75	1102	6	5	1	2	0	-2	2	0	0	2.1662443531096365	
i 1	163.00120408163266	0.2525	74	1102	4	1	1	2	0	-2	2	0	0	2.0438274789689523	
i 1	163.0020068027211	1.5150000000000001	74	218	5	3	14	8	0	-2	8	0	0	3.0	
i 1	163.00280952380953	2.02	74	1102	2	20	7	2	0	1	2	0	0	2.0	
i 1	163.00762585034013	1.5150000000000001	72	218	7	5	12	2	0	1	2	0	0	2.1662443531096365	
i 1	163.00842857142857	0.2525	71	716	1	20	2	2	0	1	2	0	0	2.0	
i 1	163.0156530612245	1.5150000000000001	74	716	4	4	8	2	0	-1	2	0	0	3.0	
i 1	163.2479931972789	0.2525	74	716	6	1	3	8	0	-2	8	0	0	2.0438274789689523	
i 1	163.24879591836734	0.505	72	716	6	5	3	8	0	1	8	0	0	2.1662443531096365	
i 1	163.24879591836734	0.2525	74	218	3	20	13	2	0	1	2	0	0	2.0	
i 1	163.26725850340137	0.2525	71	716	3	20	8	2	0	1	2	0	0	2.0	
i 1	163.26966666666667	1.7675	71	716	1	20	12	2	0	1	2	0	0	2.0	
i 1	163.4843469387755	1.5150000000000001	71	716	1	20	8	8	0	-2	8	0	0	2.0	
i 1	163.50040136054423	0.2525	71	1102	2	20	8	2	0	-2	2	0	0	2.0	
i 1	163.51003401360543	0.2525	71	1102	5	9	1	8	0	-2	8	0	0	2.0	
i 1	163.7367551020408	2.525	72	218	7	5	7	2	0	-2	2	0	0	2.1662443531096365	
i 1	163.75762585034013	1.7675	71	218	5	24	16	2	0	-2	2	0	0	3.0438274789689523	
i 1	163.76725850340137	1.7675	74	1102	4	1	1	2	0	-1	2	0	0	2.0438274789689523	
i 1	163.98113605442177	0.505	74	716	1	24	6	2	0	1	2	0	0	6.0	
i 1	163.98274149659863	1.2625	74	716	4	2	9	8	0	-2	8	0	0	3.0	
i 1	163.98514965986394	0.505	71	716	3	1	5	2	0	-1	2	0	0	2.0438274789689523	
i 1	163.98595238095237	1.2625	74	716	2	3	4	2	0	-1	2	0	0	3.0	
i 1	164.009231292517	0.505	71	1102	2	20	14	2	0	-2	2	0	0	2.0	
i 1	164.01003401360543	1.01	74	1102	1	20	6	8	0	-2	8	0	0	2.0	
i 1	164.2431768707483	2.02	72	716	6	5	12	8	0	1	8	0	0	2.1662443531096365	
i 1	164.2616394557823	0.7575000000000001	72	716	6	5	1	2	0	-2	2	0	0	2.1662443531096365	
i 1	164.2632448979592	0.505	72	1102	6	5	3	2	0	-2	2	0	0	2.1662443531096365	
i 1	164.50280952380953	0.2525	74	716	2	24	15	2	0	-2	2	0	0	3.0438274789689523	
i 1	164.51244217687074	1.2625	71	1102	5	9	7	2	0	-1	2	0	0	2.0	
i 1	164.73595238095237	1.01	74	716	4	2	11	2	0	-1	2	0	0	3.0	
i 1	164.7479931972789	3.535	74	716	1	24	3	2	0	1	2	0	0	6.0	
i 1	164.75040136054423	0.7575000000000001	71	1102	2	24	3	2	0	-2	2	0	0	6.0	
i 1	164.7616394557823	0.2525	71	218	7	1	11	8	0	-1	8	0	0	2.0438274789689523	
i 1	164.9843469387755	0.2525	74	716	2	20	13	8	0	-2	8	0	0	2.0	
i 1	164.9955850340136	0.2525	75	716	6	5	16	2	0	1	2	0	0	2.1662443531096365	
i 1	165.0020068027211	2.02	71	716	6	1	12	8	0	-2	8	0	0	2.0438274789689523	
i 1	165.01003401360543	2.02	74	1102	4	1	7	2	0	-2	2	0	0	2.0438274789689523	
i 1	165.01966666666667	0.2525	74	218	3	20	12	2	0	-2	2	0	0	2.0	
i 1	165.23113605442177	0.2525	74	716	4	4	12	2	0	-1	2	0	0	3.0	
i 1	165.23595238095237	0.2525	72	716	6	5	11	2	0	-2	2	0	0	2.1662443531096365	
i 1	165.25040136054423	0.2525	74	1102	1	20	2	8	0	-2	8	0	0	2.0	
i 1	165.2568231292517	0.7575000000000001	71	716	1	20	10	2	0	1	2	0	0	2.0	
i 1	165.25762585034013	0.2525	74	716	1	20	4	2	0	-2	2	0	0	2.0	
i 1	165.48113605442177	0.505	74	1102	2	20	16	2	0	1	2	0	0	2.0	
i 1	165.50602040816327	0.2525	74	218	5	4	9	2	0	-1	2	0	0	3.0	
i 1	165.509231292517	0.2525	72	218	7	5	3	2	0	1	2	0	0	2.1662443531096365	
i 1	165.51725850340137	0.2525	71	218	7	1	5	8	0	-1	8	0	0	2.0438274789689523	
i 1	165.73996598639457	0.505	74	716	4	2	16	8	0	-2	8	0	0	3.0	
i 1	165.74157142857143	0.505	74	716	2	3	13	2	0	-1	2	0	0	3.0	
i 1	165.74397959183673	1.7675	75	716	6	5	5	2	0	1	2	0	0	2.1662443531096365	
i 1	165.74719047619047	2.2725	74	218	5	3	8	8	0	-2	8	0	0	3.0	
i 1	165.75040136054423	0.505	74	1102	2	20	1	8	0	1	8	0	0	2.0	
i 1	165.7544149659864	0.505	71	218	5	24	5	2	0	-2	2	0	0	3.0438274789689523	
i 1	165.75762585034013	0.2525	74	1102	1	20	13	2	0	-2	2	0	0	2.0	
i 1	165.76404761904763	1.5150000000000001	75	716	6	5	14	2	0	1	2	0	0	2.1662443531096365	
i 1	166.0116394557823	2.02	74	716	4	4	16	2	0	-1	2	0	0	3.0	
i 1	166.23755782312926	1.7675	74	716	2	24	11	2	0	-2	2	0	0	3.0438274789689523	
i 1	166.2455850340136	0.505	71	218	3	20	1	8	0	-2	8	0	0	2.0	
i 1	166.2479931972789	0.505	71	716	3	20	16	2	0	-2	2	0	0	2.0	
i 1	166.26003401360543	1.7675	74	1102	2	20	10	2	0	1	2	0	0	2.0	
i 1	166.49719047619047	0.7575000000000001	71	716	1	20	16	2	0	1	2	0	0	2.0	
i 1	166.51003401360543	0.2525	74	716	2	3	3	2	0	-1	2	0	0	3.0	
i 1	166.51886394557823	1.5150000000000001	71	218	7	1	1	8	0	-1	8	0	0	2.0438274789689523	
i 1	166.7431768707483	2.2725	72	716	6	5	15	2	0	-2	2	0	0	2.1662443531096365	
i 1	166.75280952380953	2.2725	72	1102	6	5	10	2	0	-2	2	0	0	2.1662443531096365	
i 1	166.76485034013606	0.505	74	716	1	20	16	2	0	-2	2	0	0	2.0	
i 1	166.76886394557823	0.505	74	1102	2	20	6	2	0	-2	2	0	0	2.0	
i 1	166.98033333333333	0.2525	74	716	6	1	8	8	0	-2	8	0	0	2.0438274789689523	
i 1	167.24879591836734	0.2525	74	716	2	3	1	2	0	-1	2	0	0	3.0	
i 1	167.24959863945577	0.505	71	218	3	20	9	2	0	1	2	0	0	2.0	
i 1	167.25521768707483	0.505	71	716	3	20	11	2	0	-2	2	0	0	2.0	
i 1	167.26244217687074	0.2525	71	218	5	24	15	2	0	-2	2	0	0	3.0438274789689523	
i 1	167.4931768707483	1.2625	74	218	5	4	10	2	0	-1	2	0	0	3.0	
i 1	167.49478231292517	0.2525	75	716	6	5	14	2	0	1	2	0	0	2.1662443531096365	
i 1	167.51485034013606	1.5150000000000001	71	1102	5	9	3	8	0	-2	8	0	0	2.0	
i 1	167.73514965986394	1.01	71	716	6	1	13	8	0	-2	8	0	0	2.0438274789689523	
i 1	167.73595238095237	1.01	74	1102	4	1	6	2	0	-2	2	0	0	2.0438274789689523	
i 1	167.75120408163266	1.01	71	716	1	20	1	2	0	1	2	0	0	2.0	
i 1	167.75361224489797	0.2525	71	716	1	24	14	2	0	1	2	0	0	6.0	
i 1	167.75521768707483	0.2525	71	1102	2	20	4	8	0	1	8	0	0	2.0	
i 1	167.7680612244898	0.2525	71	716	1	20	10	8	0	-2	8	0	0	2.0	
i 1	167.98113605442177	0.2525	74	716	3	20	3	2	0	-2	2	0	0	2.0	
i 1	167.98595238095237	0.2525	71	218	3	20	16	2	0	-2	2	0	0	2.0	
i 1	167.98755782312926	0.2525	72	218	7	5	10	2	0	-2	2	0	0	2.1662443531096365	
i 1	167.98996598639457	0.2525	74	716	2	3	5	2	0	-1	2	0	0	3.0	
i 1	168.0068231292517	0.2525	74	218	3	24	4	2	0	-2	2	0	0	6.0	
i 1	168.0132448979592	0.7575000000000001	71	1102	2	24	10	2	0	-2	2	0	0	6.0	
i 1	168.24638775510203	0.505	71	716	1	20	13	2	0	-2	2	0	0	2.0	
i 1	168.24719047619047	0.505	71	716	1	24	13	8	0	-2	8	0	0	6.0	
i 1	168.2479931972789	0.2525	75	716	6	5	2	2	0	1	2	0	0	2.1662443531096365	
i 1	168.2544149659864	0.505	71	218	5	24	10	2	0	-2	2	0	0	3.0438274789689523	
i 1	168.2632448979592	1.2625	74	716	4	2	1	2	0	-1	2	0	0	3.0	
i 1	168.2680612244898	2.2725	74	1102	4	1	5	2	0	-1	2	0	0	2.0438274789689523	
i 1	168.4883605442177	0.2525	75	716	6	5	4	2	0	1	2	0	0	2.1662443531096365	
i 1	168.5180612244898	1.01	71	1102	5	9	14	2	0	-1	2	0	0	2.0	
i 1	168.73274149659863	0.2525	71	716	1	24	4	8	0	-2	8	0	0	5.0	
i 1	168.73595238095237	0.2525	71	1102	2	24	11	2	0	-2	2	0	0	5.0	
i 1	168.7367551020408	1.7675	71	218	5	24	16	2	0	-2	2	0	0	3.0438274789689523	
i 1	168.7383605442177	20.4525	63	716	5	14	1	1	0	1	1	0	0	2.930116622053889	
i 1	168.74959863945577	2.2725	74	716	1	24	16	2	0	1	2	0	0	5.0	
i 1	168.75040136054423	34.0875	63	218	5	25	8	16	0	2	16	0	0	10.329861253871739	
i 1	168.75361224489797	34.0875	63	716	6	17	5	16	0	2	16	0	0	4.574761808462703	
i 1	168.7568231292517	34.0875	63	218	6	15	10	1	0	2	1	0	0	1.9192017177729124	
i 1	168.75842857142857	0.7575000000000001	74	1102	2	20	10	2	0	1	2	0	0	1.0	
i 1	168.759231292517	3.2825	72	218	7	5	7	2	0	1	2	0	0	2.1662443531096365	
i 1	168.76083673469387	0.2525	74	716	3	24	12	2	0	-2	2	0	0	3.0438274789689523	
i 1	168.76083673469387	0.2525	74	1102	1	20	4	2	0	-2	2	0	0	1.0	
i 1	168.7616394557823	0.2525	71	716	1	20	3	2	0	1	2	0	0	1.0	
i 1	168.76244217687074	1.2625	75	1102	6	5	4	2	0	-2	2	0	0	2.1662443531096365	
i 1	168.76645578231293	0.2525	74	218	5	4	14	2	0	-1	2	0	0	3.0	
i 1	168.76886394557823	0.2525	71	716	1	20	16	2	0	-2	2	0	0	1.0	
i 1	168.98916326530613	0.2525	74	716	6	1	7	8	0	-2	8	0	0	2.0438274789689523	
i 1	168.99638775510203	1.2625	74	218	4	3	13	8	0	-2	8	0	0	3.0	
i 1	168.99638775510203	0.2525	74	716	2	20	7	2	0	-2	2	0	0	1.0	
i 1	169.0132448979592	0.2525	74	218	3	20	8	2	0	-2	2	0	0	1.0	
i 1	169.24959863945577	1.7675	71	1102	1	20	10	2	0	1	2	0	0	1.0	
i 1	169.25361224489797	0.505	72	1102	6	5	15	2	0	-2	2	0	0	2.1662443531096365	
i 1	169.2680612244898	1.01	74	716	2	4	3	2	0	-1	2	0	0	3.0	
i 1	169.50521768707483	0.2525	74	716	5	3	12	2	0	-1	2	0	0	3.0	
i 1	169.76485034013606	0.2525	74	716	1	24	14	8	0	-2	8	0	0	5.0	
i 1	169.7680612244898	0.2525	74	218	5	4	12	2	0	-1	2	0	0	3.0	
i 1	169.9819387755102	0.2525	75	716	6	5	3	2	0	1	2	0	0	2.1662443531096365	
i 1	169.99237414965987	3.0300000000000002	74	716	3	24	4	2	0	-2	2	0	0	3.0438274789689523	
i 1	169.99959863945577	0.2525	75	716	5	5	13	2	0	1	2	0	0	2.1662443531096365	
i 1	170.00602040816327	3.0300000000000002	71	218	7	1	6	8	0	-1	8	0	0	2.0438274789689523	
i 1	170.23113605442177	0.2525	71	1102	5	9	7	8	0	-2	8	0	0	2.0	
i 1	170.24879591836734	0.2525	74	716	5	3	12	2	0	-1	2	0	0	3.0	
i 1	170.25280952380953	0.2525	74	716	4	2	15	8	0	-2	8	0	0	3.0	
i 1	170.2632448979592	1.7675	75	1102	6	5	1	2	0	-2	2	0	0	2.1662443531096365	
i 1	170.26966666666667	1.01	71	1102	1	20	14	2	0	-2	2	0	0	1.0	
i 1	170.4819387755102	0.7575000000000001	71	1102	5	9	9	2	0	-1	2	0	0	2.0	
i 1	170.48354421768707	0.2525	72	716	6	5	12	8	0	1	8	0	0	2.1662443531096365	
i 1	170.5044149659864	0.505	74	218	4	3	16	8	0	-2	8	0	0	3.0	
i 1	170.50521768707483	0.2525	71	716	3	1	13	2	0	-1	2	0	0	2.0438274789689523	
i 1	170.51886394557823	0.7575000000000001	74	716	4	2	3	2	0	-1	2	0	0	3.0	
i 1	170.7431768707483	1.7675	71	716	1	20	2	2	0	1	2	0	0	1.0	
i 1	170.75040136054423	0.2525	71	716	6	1	13	8	0	-2	8	0	0	2.0438274789689523	
i 1	170.75040136054423	0.505	74	716	1	20	8	8	0	-2	8	0	0	1.0	
i 1	170.75521768707483	1.2625	74	1102	2	20	4	2	0	1	2	0	0	1.0	
i 1	170.98113605442177	0.2525	74	218	5	4	7	2	0	-1	2	0	0	3.0	
i 1	171.0116394557823	0.2525	72	1102	6	5	15	2	0	-2	2	0	0	2.1662443531096365	
i 1	171.23595238095237	0.505	71	218	3	20	1	8	0	1	8	0	0	1.0	
i 1	171.240768707483	1.2625	74	716	1	24	5	2	0	1	2	0	0	5.0	
i 1	171.2544149659864	1.2625	74	716	4	2	12	8	0	-2	8	0	0	3.0	
i 1	171.25762585034013	1.2625	74	716	5	3	13	2	0	-1	2	0	0	3.0	
i 1	171.26244217687074	0.2525	74	716	2	20	6	2	0	-2	2	0	0	1.0	
i 1	171.26244217687074	0.505	71	716	2	20	7	2	0	-2	2	0	0	1.0	
i 1	171.48595238095237	0.2525	75	716	6	5	14	2	0	1	2	0	0	2.1662443531096365	
i 1	171.5132448979592	0.2525	71	1102	5	9	4	2	0	-1	2	0	0	2.0	
i 1	171.73514965986394	1.01	72	1102	6	5	14	2	0	-2	2	0	0	2.1662443531096365	
i 1	171.73595238095237	0.505	71	716	6	1	12	8	0	-2	8	0	0	2.0438274789689523	
i 1	171.74719047619047	0.7575000000000001	74	716	1	20	15	2	0	-2	2	0	0	1.0	
i 1	171.75602040816327	1.01	72	716	6	5	16	2	0	-2	2	0	0	2.1662443531096365	
i 1	171.7568231292517	0.2525	74	218	5	4	1	2	0	-1	2	0	0	3.0	
i 1	171.75762585034013	0.7575000000000001	74	1102	1	20	6	2	0	1	2	0	0	1.0	
i 1	172.00280952380953	2.02	74	716	2	4	13	2	0	-1	2	0	0	3.0	
i 1	172.0116394557823	2.02	74	218	4	3	8	8	0	-2	8	0	0	3.0	
i 1	172.240768707483	0.7575000000000001	72	716	6	5	13	8	0	1	8	0	0	2.1662443531096365	
i 1	172.4867551020408	0.505	72	218	7	5	9	2	0	-2	2	0	0	2.1662443531096365	
i 1	172.4931768707483	0.2525	71	1102	5	9	1	8	0	-2	8	0	0	2.0	
i 1	172.50280952380953	0.2525	74	716	2	20	6	8	0	1	8	0	0	1.0	
i 1	172.5132448979592	0.2525	74	1102	4	1	2	2	0	-1	2	0	0	2.0438274789689523	
i 1	172.5180612244898	0.2525	74	1102	2	20	2	2	0	1	2	0	0	1.0	
i 1	172.7319387755102	1.5150000000000001	71	716	1	24	11	2	0	-2	2	0	0	5.0	
i 1	172.7479931972789	2.02	74	716	1	24	10	2	0	1	2	0	0	5.0	
i 1	172.759231292517	0.2525	74	716	4	2	11	8	0	-2	8	0	0	3.0	
i 1	172.76645578231293	1.5150000000000001	71	1102	2	24	13	2	0	-2	2	0	0	5.0	
i 1	172.7680612244898	1.7675	74	1102	1	20	1	2	0	1	2	0	0	1.0	
i 1	172.9819387755102	0.2525	71	716	3	1	13	2	0	-1	2	0	0	2.0438274789689523	
i 1	172.98916326530613	1.5150000000000001	75	716	5	5	7	2	0	1	2	0	0	2.1662443531096365	
i 1	172.9955850340136	1.5150000000000001	75	716	6	5	12	2	0	1	2	0	0	2.1662443531096365	
i 1	172.99879591836734	1.2625	74	1102	4	1	15	2	0	-1	2	0	0	2.0438274789689523	
i 1	173.00521768707483	1.2625	71	218	5	24	8	2	0	-2	2	0	0	3.0438274789689523	
i 1	173.25361224489797	0.2525	75	1102	6	5	8	2	0	-2	2	0	0	2.1662443531096365	
i 1	173.51886394557823	0.2525	74	218	5	4	8	2	0	-1	2	0	0	3.0	
i 1	173.7455850340136	0.2525	74	716	6	1	5	8	0	-2	8	0	0	2.0438274789689523	
i 1	173.75280952380953	0.2525	74	716	4	2	4	8	0	-2	8	0	0	3.0	
i 1	173.76083673469387	0.2525	72	716	6	5	11	2	0	-2	2	0	0	2.1662443531096365	
i 1	173.98514965986394	0.2525	71	716	3	1	8	2	0	-1	2	0	0	2.0438274789689523	
i 1	173.9883605442177	1.01	74	218	5	4	11	2	0	-1	2	0	0	3.0	
i 1	174.00040136054423	1.01	71	1102	5	9	8	8	0	-2	8	0	0	2.0	
i 1	174.23113605442177	0.505	74	1102	4	1	14	2	0	-2	2	0	0	2.0438274789689523	
i 1	174.240768707483	1.2625	72	1102	6	5	6	2	0	-2	2	0	0	2.1662443531096365	
i 1	174.26244217687074	1.7675	72	716	6	5	6	2	0	-2	2	0	0	2.1662443531096365	
i 1	174.26485034013606	0.505	71	716	6	1	5	8	0	-2	8	0	0	2.0438274789689523	
i 1	174.509231292517	0.2525	74	218	3	20	3	2	0	-2	2	0	0	1.0	
i 1	174.51244217687074	0.2525	74	716	2	20	9	2	0	-2	2	0	0	1.0	
i 1	174.51725850340137	0.2525	72	218	7	5	10	2	0	1	2	0	0	2.1662443531096365	
i 1	174.51725850340137	0.7575000000000001	74	1102	2	20	8	2	0	1	2	0	0	1.0	
i 1	174.5180612244898	0.7575000000000001	71	1102	5	9	5	2	0	-1	2	0	0	2.0	
i 1	174.73916326530613	0.7575000000000001	71	218	7	1	9	8	0	-1	8	0	0	2.0438274789689523	
i 1	174.74879591836734	0.7575000000000001	74	716	2	4	6	2	0	-1	2	0	0	3.0	
i 1	174.75280952380953	0.505	74	1102	1	20	1	2	0	-2	2	0	0	1.0	
i 1	174.75521768707483	0.7575000000000001	74	716	3	24	7	2	0	-2	2	0	0	3.0438274789689523	
i 1	174.75762585034013	1.2625	71	716	1	20	8	2	0	1	2	0	0	1.0	
i 1	174.76404761904763	1.2625	74	218	4	3	6	8	0	-2	8	0	0	3.0	
i 1	174.7656530612245	0.505	74	716	4	2	1	2	0	-1	2	0	0	3.0	
i 1	174.7656530612245	0.7575000000000001	71	716	1	20	16	2	0	1	2	0	0	1.0	
i 1	174.9843469387755	3.0300000000000002	74	1102	1	20	12	2	0	-2	2	0	0	1.0	
i 1	174.9979931972789	3.2825	74	716	1	24	1	2	0	1	2	0	0	5.0	
i 1	175.0180612244898	0.2525	71	218	5	24	8	2	0	-2	2	0	0	3.0438274789689523	
i 1	175.2656530612245	0.2525	72	218	7	5	9	2	0	1	2	0	0	2.1662443531096365	
i 1	175.26725850340137	1.5150000000000001	71	716	6	1	3	8	0	-2	8	0	0	2.0438274789689523	
i 1	175.4819387755102	0.505	74	716	4	4	7	2	0	-1	2	0	0	3.0	
i 1	175.49157142857143	27.27	63	218	6	17	11	1	0	1	1	0	0	4.574761808462703	
i 1	175.49237414965987	1.2625	74	1102	4	1	8	2	0	-2	2	0	0	2.0438274789689523	
i 1	175.49397959183673	0.505	72	1102	6	5	15	2	0	-2	2	0	0	2.1662443531096365	
i 1	175.49638775510203	27.27	63	218	6	15	14	16	0	1	16	0	0	1.9192017177729124	
i 1	175.49638775510203	27.27	61	218	5	25	1	1	0	2	1	0	0	10.329861253871739	
i 1	175.50521768707483	20.4525	61	716	5	14	10	16	0	2	16	0	0	2.930116622053889	
i 1	175.75842857142857	1.01	74	716	4	2	12	8	0	-2	8	0	0	3.0	
i 1	175.75842857142857	1.01	74	716	5	3	3	2	0	-1	2	0	0	3.0	
i 1	175.98916326530613	1.7675	72	218	7	5	5	2	0	1	2	0	0	2.1662443531096365	
i 1	175.99237414965987	1.7675	75	1102	6	5	6	2	0	-2	2	0	0	2.1662443531096365	
i 1	176.01244217687074	1.2625	74	1102	2	20	1	2	0	1	2	0	0	1.0	
i 1	176.0180612244898	1.2625	74	1102	1	20	3	2	0	-2	2	0	0	1.0	
i 1	176.240768707483	3.0300000000000002	74	1102	6	1	7	2	0	-1	2	0	0	2.0438274789689523	
i 1	176.26485034013606	3.0300000000000002	71	218	5	24	15	2	0	-2	2	0	0	3.0438274789689523	
i 1	176.51244217687074	0.2525	72	716	6	5	4	2	0	-2	2	0	0	2.1662443531096365	
i 1	176.73755782312926	1.01	74	716	6	2	11	2	0	-1	2	0	0	3.0	
i 1	176.74959863945577	1.01	71	1102	5	9	13	2	0	-1	2	0	0	2.0	
i 1	176.9867551020408	1.2625	71	1102	2	24	1	2	0	-2	2	0	0	5.0	
i 1	176.98996598639457	1.01	71	716	1	24	3	2	0	1	2	0	0	5.0	
i 1	177.51003401360543	1.01	75	716	6	5	5	2	0	1	2	0	0	2.1662443531096365	
i 1	177.51485034013606	1.01	75	716	5	5	12	2	0	1	2	0	0	2.1662443531096365	
i 1	177.73113605442177	0.2525	74	1102	1	20	7	2	0	-2	2	0	0	1.0	
i 1	177.73354421768707	0.2525	74	716	6	1	10	8	0	-2	8	0	0	2.0438274789689523	
i 1	177.76003401360543	0.7575000000000001	74	716	5	3	13	2	0	-1	2	0	0	3.0	
i 1	177.76404761904763	0.7575000000000001	74	716	4	2	9	8	0	-2	8	0	0	3.0	
i 1	177.7656530612245	0.2525	72	218	7	5	15	2	0	-2	2	0	0	2.1662443531096365	
i 1	177.98595238095237	0.2525	71	218	2	20	1	2	0	1	2	0	0	1.0	
i 1	178.01003401360543	0.2525	71	716	2	20	11	2	0	1	2	0	0	1.0	
i 1	178.0132448979592	0.2525	71	218	7	1	12	8	0	-1	8	0	0	2.0438274789689523	
i 1	178.23354421768707	1.2625	74	218	4	3	10	8	0	-2	8	0	0	3.0	
i 1	178.2455850340136	1.2625	74	716	4	4	13	2	0	-1	2	0	0	3.0	
i 1	178.24719047619047	0.505	71	716	1	20	14	2	0	1	2	0	0	1.0	
i 1	178.48916326530613	0.2525	72	218	7	5	13	2	0	1	2	0	0	2.1662443531096365	
i 1	178.51485034013606	0.2525	75	1102	6	5	9	2	0	-2	2	0	0	2.1662443531096365	
i 1	178.73274149659863	2.2725	74	716	1	24	13	2	0	1	2	0	0	5.0	
i 1	178.7383605442177	1.01	74	1102	2	20	4	2	0	1	2	0	0	1.0	
i 1	178.74397959183673	1.5150000000000001	72	716	6	5	9	2	0	-2	2	0	0	2.1662443531096365	
i 1	178.7479931972789	0.2525	71	716	2	20	6	2	0	1	2	0	0	1.0	
i 1	178.7520068027211	1.5150000000000001	72	1102	6	5	12	2	0	-2	2	0	0	2.1662443531096365	
i 1	178.75361224489797	0.2525	74	218	2	20	5	2	0	1	2	0	0	1.0	
i 1	179.00040136054423	0.7575000000000001	74	1102	1	20	6	2	0	-2	2	0	0	1.0	
i 1	179.01244217687074	2.02	71	1102	1	20	1	8	0	1	8	0	0	1.0	
i 1	179.24638775510203	1.7675	74	716	3	24	3	2	0	-2	2	0	0	3.0438274789689523	
i 1	179.26966666666667	1.7675	71	218	7	1	8	8	0	-1	8	0	0	2.0438274789689523	
i 1	179.48595238095237	0.7575000000000001	74	218	4	4	8	2	0	-1	2	0	0	3.0	
i 1	179.50602040816327	0.7575000000000001	71	1102	4	9	1	8	0	-2	8	0	0	2.0	
i 1	180.24157142857143	1.2625	72	218	7	5	1	2	0	-2	2	0	0	2.1662443531096365	
i 1	180.2544149659864	1.01	71	1102	5	9	6	2	0	-1	2	0	0	2.0	
i 1	180.25521768707483	1.2625	72	716	5	5	1	8	0	1	8	0	0	2.1662443531096365	
i 1	180.2656530612245	1.01	74	716	6	2	11	2	0	-1	2	0	0	3.0	
i 1	180.9955850340136	1.2625	71	716	1	20	7	2	0	1	2	0	0	1.0	
i 1	180.99879591836734	1.2625	74	1102	2	20	15	2	0	1	2	0	0	1.0	
i 1	181.00521768707483	1.2625	74	1102	1	20	14	2	0	-2	2	0	0	1.0	
i 1	181.0116394557823	0.7575000000000001	71	218	5	24	10	2	0	-2	2	0	0	3.0438274789689523	
i 1	181.0156530612245	0.7575000000000001	74	1102	6	1	11	2	0	-1	2	0	0	2.0438274789689523	
i 1	181.240768707483	1.01	74	218	4	3	3	8	0	-2	8	0	0	3.0	
i 1	181.26083673469387	1.01	74	716	4	4	6	2	0	-1	2	0	0	3.0	
i 1	181.49959863945577	0.2525	75	716	5	5	11	2	0	1	2	0	0	2.1662443531096365	
i 1	181.51645578231293	0.2525	75	716	6	5	2	2	0	1	2	0	0	2.1662443531096365	
i 1	181.7479931972789	2.525	72	716	6	5	12	2	0	-2	2	0	0	2.1662443531096365	
i 1	181.75120408163266	2.525	72	1102	6	5	7	2	0	-2	2	0	0	2.1662443531096365	
i 1	181.7632448979592	1.01	71	716	6	1	14	8	0	-2	8	0	0	2.0438274789689523	
i 1	181.7656530612245	0.505	74	1102	4	1	7	2	0	-2	2	0	0	2.0438274789689523	
i 1	182.23033333333333	0.505	74	1102	6	1	13	2	0	-2	2	0	0	2.0438274789689523	
i 1	182.2319387755102	20.4525	63	218	6	17	4	1	0	1	1	0	0	4.574761808462703	
i 1	182.23274149659863	20.4525	63	1102	4	26	9	16	0	1	16	0	0	10.329861253871739	
i 1	182.2479931972789	0.505	74	218	2	20	3	8	0	1	8	0	0	1.0	
i 1	182.25361224489797	20.4525	63	218	6	13	1	16	0	2	16	0	0	0.6798674639746006	
i 1	182.25762585034013	0.7575000000000001	74	716	6	2	3	8	0	-2	8	0	0	3.0	
i 1	182.26645578231293	1.01	74	716	1	24	5	2	0	1	2	0	0	5.0	
i 1	182.26725850340137	20.4525	61	1102	4	16	11	1	0	2	1	0	0	3.094852019400723	
i 1	182.26966666666667	0.7575000000000001	74	716	5	3	3	2	0	-1	2	0	0	3.0	
i 1	182.73113605442177	0.505	74	1102	1	20	3	2	0	1	2	0	0	1.0	
i 1	182.74237414965987	1.2625	74	716	3	24	9	2	0	-2	2	0	0	3.0438274789689523	
i 1	182.75361224489797	0.505	71	716	1	20	15	2	0	1	2	0	0	1.0	
i 1	182.7616394557823	1.2625	71	218	7	1	2	8	0	-1	8	0	0	2.0438274789689523	
i 1	182.98033333333333	0.7575000000000001	71	1102	4	9	9	2	0	-1	2	0	0	2.0	
i 1	183.0020068027211	0.7575000000000001	74	716	6	2	15	2	0	-1	2	0	0	3.0	
i 1	183.23113605442177	0.2525	74	716	2	20	3	2	0	1	2	0	0	1.0	
i 1	183.23916326530613	1.01	74	1102	2	20	14	2	0	1	2	0	0	1.0	
i 1	183.25361224489797	0.2525	71	716	2	20	6	2	0	-2	2	0	0	1.0	
i 1	183.25842857142857	0.2525	71	1102	2	24	12	2	0	-2	2	0	0	5.0	
i 1	183.48113605442177	0.7575000000000001	74	1102	1	20	6	8	0	-2	8	0	0	1.0	
i 1	183.5116394557823	2.02	71	716	1	20	8	2	0	1	2	0	0	1.0	
i 1	183.75040136054423	0.2525	74	716	6	2	12	8	0	-2	8	0	0	3.0	
i 1	183.75120408163266	0.2525	74	716	5	3	6	2	0	-1	2	0	0	3.0	
i 1	183.98916326530613	1.5150000000000001	74	1102	6	1	3	2	0	-2	2	0	0	2.0438274789689523	
i 1	183.99638775510203	1.7675	74	716	4	4	12	2	0	-1	2	0	0	3.0	
i 1	184.0020068027211	1.7675	74	218	4	3	7	8	0	-2	8	0	0	3.0	
i 1	184.0132448979592	1.5150000000000001	71	716	6	1	16	8	0	-2	8	0	0	2.0438274789689523	
i 1	184.24478231292517	1.01	74	1102	1	20	6	2	0	1	2	0	0	1.0	
i 1	184.25361224489797	0.2525	75	1102	6	5	13	2	0	-2	2	0	0	2.1662443531096365	
i 1	184.26404761904763	1.5150000000000001	74	716	1	24	13	2	0	1	2	0	0	5.0	
i 1	184.2656530612245	0.2525	72	218	7	5	1	2	0	1	2	0	0	2.1662443531096365	
i 1	184.49157142857143	1.5150000000000001	75	716	6	5	7	2	0	1	2	0	0	2.1662443531096365	
i 1	184.5116394557823	1.5150000000000001	75	716	6	5	1	2	0	1	2	0	0	2.1662443531096365	
i 1	185.2520068027211	0.2525	71	218	2	20	15	2	0	1	2	0	0	1.0	
i 1	185.2544149659864	0.2525	71	218	2	24	12	2	0	-2	2	0	0	5.0	
i 1	185.48755782312926	0.2525	71	1102	2	24	1	2	0	-2	2	0	0	5.0	
i 1	185.49959863945577	1.7675	71	218	5	24	5	2	0	-2	2	0	0	3.0438274789689523	
i 1	185.5044149659864	1.7675	74	1102	6	1	4	2	0	-1	2	0	0	2.0438274789689523	
i 1	185.5068231292517	0.2525	74	1102	1	20	2	2	0	-2	2	0	0	1.0	
i 1	185.73113605442177	0.2525	71	716	2	20	16	2	0	-2	2	0	0	1.0	
i 1	185.7383605442177	1.01	74	218	4	4	8	2	0	-1	2	0	0	3.0	
i 1	185.74157142857143	1.01	71	1102	3	9	9	8	0	-2	8	0	0	2.0	
i 1	185.7544149659864	0.2525	74	1102	2	20	15	2	0	1	2	0	0	1.0	
i 1	185.98354421768707	1.2625	72	218	7	5	14	2	0	1	2	0	0	2.1662443531096365	
i 1	185.990768707483	1.2625	75	1102	6	5	13	2	0	-2	2	0	0	2.1662443531096365	
i 1	185.9931768707483	0.7575000000000001	71	716	1	20	3	2	0	1	2	0	0	1.0	
i 1	186.00280952380953	2.2725	74	716	1	24	11	2	0	1	2	0	0	5.0	
i 1	186.01244217687074	0.505	71	1102	1	20	15	2	0	-2	2	0	0	1.0	
i 1	186.48514965986394	0.2525	71	218	2	20	8	2	0	-2	2	0	0	1.0	
i 1	186.48755782312926	0.2525	71	218	2	24	14	2	0	1	2	0	0	5.0	
i 1	186.740768707483	1.2625	71	1102	2	24	6	2	0	-2	2	0	0	5.0	
i 1	186.74879591836734	0.7575000000000001	74	716	6	2	3	2	0	-1	2	0	0	3.0	
i 1	186.74959863945577	0.7575000000000001	71	1102	4	9	2	2	0	-1	2	0	0	2.0	
i 1	186.7616394557823	1.5150000000000001	74	1102	1	20	3	2	0	-2	2	0	0	1.0	
i 1	187.23595238095237	1.7675	74	716	3	24	12	2	0	-2	2	0	0	3.0438274789689523	
i 1	187.25602040816327	0.2525	72	1102	6	5	3	2	0	-2	2	0	0	2.1662443531096365	
i 1	187.26244217687074	0.2525	72	716	6	5	3	2	0	-2	2	0	0	2.1662443531096365	
i 1	187.2680612244898	1.7675	71	218	7	1	12	8	0	-1	8	0	0	2.0438274789689523	
i 1	187.48514965986394	1.5150000000000001	72	218	7	5	13	2	0	-2	2	0	0	2.1662443531096365	
i 1	187.48595238095237	1.5150000000000001	72	716	5	5	12	8	0	1	8	0	0	2.1662443531096365	
i 1	187.48996598639457	0.7575000000000001	74	716	4	4	16	2	0	-1	2	0	0	3.0	
i 1	187.49237414965987	0.7575000000000001	74	218	4	3	3	8	0	-2	8	0	0	3.0	
i 1	188.24719047619047	0.2525	71	716	2	20	2	2	0	1	2	0	0	1.0	
i 1	188.24959863945577	0.2525	74	1102	2	20	9	2	0	1	2	0	0	1.0	
i 1	188.25040136054423	0.2525	74	716	6	2	12	8	0	-2	8	0	0	3.0	
i 1	188.259231292517	0.2525	74	716	5	3	15	2	0	-1	2	0	0	3.0	
i 1	188.48113605442177	0.2525	74	1102	1	20	3	2	0	1	2	0	0	1.0	
i 1	188.4883605442177	0.2525	71	716	1	20	10	2	0	1	2	0	0	1.0	
i 1	188.50120408163266	4.2925	74	716	1	24	4	2	0	1	2	0	0	5.0	
i 1	188.5068231292517	0.7575000000000001	74	716	6	2	4	2	0	-1	2	0	0	3.0	
i 1	188.51886394557823	0.505	71	1102	4	9	5	2	0	-1	2	0	0	2.0	
i 1	188.74397959183673	0.2525	74	716	2	20	11	2	0	-2	2	0	0	1.0	
i 1	188.75120408163266	0.2525	74	1102	2	20	9	2	0	1	2	0	0	1.0	
i 1	188.76485034013606	0.2525	71	218	2	20	10	2	0	1	2	0	0	1.0	
i 1	188.98274149659863	13.635	63	716	5	14	15	1	0	1	1	0	0	2.930116622053889	
i 1	188.9843469387755	13.635	61	218	6	7	13	1	0	1	1	0	0	2.180033569360793	
i 1	188.98755782312926	0.505	71	716	1	20	2	2	0	1	2	0	0	1.0	
i 1	188.9883605442177	1.2625	71	218	5	24	4	2	0	-2	2	0	0	3.0438274789689523	
i 1	188.990768707483	0.2525	71	1102	3	9	8	2	0	-1	2	0	0	2.0	
i 1	189.0020068027211	13.635	61	1102	4	16	10	16	0	1	16	0	0	3.094852019400723	
i 1	189.00361224489797	0.505	74	1102	1	20	1	2	0	-2	2	0	0	1.0	
i 1	189.00521768707483	1.01	75	716	6	5	9	2	0	1	2	0	0	2.1662443531096365	
i 1	189.01003401360543	13.635	61	1102	4	26	8	16	0	1	16	0	0	10.329861253871739	
i 1	189.01244217687074	1.2625	74	1102	6	1	8	2	0	-1	2	0	0	2.0438274789689523	
i 1	189.01645578231293	1.01	75	716	6	5	9	2	0	1	2	0	0	2.1662443531096365	
i 1	189.01725850340137	13.635	61	1102	4	18	7	16	0	1	16	0	0	4.574761808462703	
i 1	189.24237414965987	1.01	74	716	3	3	12	2	0	-1	2	0	0	3.0	
i 1	189.24879591836734	1.01	74	716	6	2	5	8	0	-2	8	0	0	3.0	
i 1	189.51003401360543	0.505	74	218	2	20	7	8	0	-2	8	0	0	1.0	
i 1	189.5180612244898	0.505	74	1102	2	20	2	2	0	1	2	0	0	1.0	
i 1	189.51966666666667	0.505	71	716	2	20	2	2	0	-2	2	0	0	1.0	
i 1	189.98274149659863	1.7675	72	716	6	5	2	2	0	-2	2	0	0	2.1662443531096365	
i 1	189.9843469387755	0.505	71	1102	1	20	8	2	0	-2	2	0	0	1.0	
i 1	189.99719047619047	1.7675	72	1102	6	5	14	2	0	-2	2	0	0	2.1662443531096365	
i 1	190.00521768707483	0.505	71	716	1	20	3	2	0	1	2	0	0	1.0	
i 1	190.2319387755102	1.5150000000000001	71	716	5	1	16	8	0	-2	8	0	0	2.0438274789689523	
i 1	190.23514965986394	1.7675	74	218	6	3	12	8	0	-2	8	0	0	3.0	
i 1	190.24959863945577	1.5150000000000001	74	1102	6	1	7	2	0	-2	2	0	0	2.0438274789689523	
i 1	190.26244217687074	1.7675	74	716	4	4	9	2	0	-1	2	0	0	3.0	
i 1	190.48354421768707	0.2525	71	716	2	20	5	2	0	-2	2	0	0	1.0	
i 1	190.49638775510203	0.2525	74	218	2	20	10	2	0	-2	2	0	0	1.0	
i 1	190.51725850340137	0.2525	74	1102	2	20	4	2	0	1	2	0	0	1.0	
i 1	190.73113605442177	0.7575000000000001	71	716	1	20	6	2	0	1	2	0	0	1.0	
i 1	190.76083673469387	2.02	71	1102	1	20	2	2	0	-2	2	0	0	1.0	
i 1	191.49397959183673	0.7575000000000001	74	1102	1	20	8	2	0	-2	2	0	0	1.0	
i 1	191.51485034013606	0.7575000000000001	74	1102	2	20	7	2	0	1	2	0	0	1.0	
i 1	191.73274149659863	1.2625	75	1102	6	5	11	2	0	-2	2	0	0	2.1662443531096365	
i 1	191.73354421768707	1.2625	74	716	3	24	14	2	0	-2	2	0	0	3.0438274789689523	
i 1	191.7544149659864	1.2625	72	218	7	5	8	2	0	1	2	0	0	2.1662443531096365	
i 1	191.759231292517	1.2625	71	218	7	1	5	8	0	-1	8	0	0	2.0438274789689523	
i 1	192.009231292517	0.7575000000000001	74	218	4	4	13	2	0	-1	2	0	0	3.0	
i 1	192.01725850340137	0.7575000000000001	71	1102	3	9	2	8	0	-2	8	0	0	2.0	
i 1	192.2383605442177	0.505	71	716	1	20	6	2	0	1	2	0	0	1.0	
i 1	192.73354421768707	0.2525	71	1102	1	24	5	2	0	-2	2	0	0	5.0	
i 1	192.7367551020408	0.2525	74	716	6	2	4	2	0	-1	2	0	0	3.0	
i 1	192.7479931972789	0.2525	74	1102	1	20	16	2	0	-2	2	0	0	1.0	
i 1	192.75521768707483	0.2525	71	1102	3	9	1	2	0	-1	2	0	0	2.0	
i 1	192.7680612244898	0.2525	74	1102	2	20	9	2	0	1	2	0	0	1.0	
i 1	192.98514965986394	0.7575000000000001	74	218	6	3	13	8	0	-2	8	0	0	3.0	
i 1	192.98755782312926	0.2525	75	716	6	5	3	2	0	1	2	0	0	2.1662443531096365	
i 1	192.98916326530613	0.7575000000000001	74	716	4	4	15	2	0	-1	2	0	0	3.0	
i 1	192.98996598639457	0.2525	75	716	6	5	15	2	0	1	2	0	0	2.1662443531096365	
i 1	192.99719047619047	0.2525	71	218	2	24	9	2	0	-2	2	0	0	5.0	
i 1	193.00280952380953	0.505	74	1102	6	1	11	2	0	-2	2	0	0	2.0438274789689523	
i 1	193.01083673469387	0.2525	71	716	1	20	11	2	0	1	2	0	0	1.0	
i 1	193.0116394557823	0.505	71	716	5	1	5	8	0	-2	8	0	0	2.0438274789689523	
i 1	193.2479931972789	1.5150000000000001	75	1102	6	5	7	2	0	-2	2	0	0	2.1662443531096365	
i 1	193.25040136054423	1.7675	71	1102	1	24	13	2	0	-2	2	0	0	5.0	
i 1	193.2520068027211	1.01	71	1102	1	20	11	2	0	1	2	0	0	1.0	
i 1	193.2520068027211	1.01	74	716	1	24	15	2	0	1	2	0	0	5.0	
i 1	193.26485034013606	1.5150000000000001	72	218	7	5	14	2	0	1	2	0	0	2.1662443531096365	
i 1	193.48755782312926	1.7675	71	218	5	24	7	2	0	-2	2	0	0	3.0438274789689523	
i 1	193.50040136054423	1.7675	74	1102	6	1	16	2	0	-1	2	0	0	2.0438274789689523	
i 1	193.7568231292517	1.2625	74	716	6	2	6	8	0	-2	8	0	0	3.0	
i 1	193.75762585034013	1.2625	74	716	3	3	7	2	0	-1	2	0	0	3.0	
i 1	194.23755782312926	0.2525	74	716	2	20	4	2	0	1	2	0	0	1.0	
i 1	194.2479931972789	0.7575000000000001	74	1102	2	20	4	2	0	1	2	0	0	1.0	
i 1	194.25842857142857	0.2525	74	716	2	20	12	2	0	-2	2	0	0	1.0	
i 1	194.50040136054423	0.505	71	1102	1	20	1	2	0	1	2	0	0	1.0	
i 1	194.73274149659863	1.01	71	1102	3	9	8	2	0	-1	2	0	0	2.0	
i 1	194.73996598639457	1.01	74	716	6	2	5	2	0	-1	2	0	0	3.0	
i 1	194.74237414965987	1.2625	72	1102	6	5	10	2	0	-2	2	0	0	2.1662443531096365	
i 1	194.76244217687074	1.2625	72	716	6	5	14	2	0	-2	2	0	0	2.1662443531096365	
i 1	194.98755782312926	0.2525	74	1102	1	20	6	2	0	1	2	0	0	1.0	
i 1	194.9979931972789	1.2625	74	716	1	24	5	2	0	1	2	0	0	5.0	
i 1	195.0116394557823	0.2525	71	716	1	20	9	2	0	1	2	0	0	1.0	
i 1	195.23916326530613	2.7775	71	218	7	1	4	8	0	-1	8	0	0	2.0438274789689523	
i 1	195.23996598639457	1.01	71	1102	1	24	10	2	0	-2	2	0	0	5.0	
i 1	195.2455850340136	0.2525	71	218	2	20	9	2	0	1	2	0	0	1.0	
i 1	195.259231292517	0.2525	74	716	2	20	2	2	0	-2	2	0	0	1.0	
i 1	195.26645578231293	0.505	74	716	3	24	1	2	0	-2	2	0	0	3.0438274789689523	
i 1	195.48113605442177	0.505	74	1102	1	20	16	2	0	-2	2	0	0	1.0	
i 1	195.51485034013606	0.505	71	716	1	20	15	2	0	1	2	0	0	1.0	
i 1	195.7383605442177	6.8175	63	716	4	12	16	1	0	2	1	0	0	3.094852019400723	
i 1	195.73996598639457	0.2525	72	218	7	5	15	2	0	-2	2	0	0	2.1662443531096365	
i 1	195.740768707483	2.02	75	716	6	5	1	2	0	1	2	0	0	2.1662443531096365	
i 1	195.7431768707483	6.8175	63	1102	4	18	9	1	0	2	1	0	0	4.574761808462703	
i 1	195.74719047619047	0.7575000000000001	74	716	2	3	2	2	0	-1	2	0	0	3.0	
i 1	195.74879591836734	6.8175	61	716	3	27	14	16	0	2	16	0	0	12.051504796183696	
i 1	195.74959863945577	0.2525	72	716	6	5	1	8	0	1	8	0	0	2.1662443531096365	
i 1	195.75120408163266	2.2725	74	716	4	24	14	2	0	-2	2	0	0	3.0438274789689523	
i 1	195.7520068027211	6.8175	61	716	5	14	16	16	0	2	16	0	0	2.930116622053889	
i 1	195.75602040816327	0.7575000000000001	74	716	6	2	13	8	0	-2	8	0	0	3.0	
i 1	195.7616394557823	2.02	75	716	6	5	6	2	0	1	2	0	0	2.1662443531096365	
i 1	195.9843469387755	0.2525	74	218	2	20	3	2	0	-2	2	0	0	1.0	
i 1	196.00120408163266	0.2525	74	716	5	2	6	2	0	-1	2	0	0	3.0	
i 1	196.01725850340137	0.2525	74	716	2	20	1	8	0	1	8	0	0	1.0	
i 1	196.23996598639457	0.505	71	1102	1	20	7	2	0	-2	2	0	0	1.0	
i 1	196.2479931972789	0.2525	72	218	7	5	15	2	0	1	2	0	0	2.1662443531096365	
i 1	196.24959863945577	0.2525	71	1102	3	9	4	8	0	-2	8	0	0	2.0	
i 1	196.25762585034013	0.505	74	1102	1	20	1	2	0	1	2	0	0	1.0	
i 1	196.26886394557823	0.505	71	716	1	20	5	2	0	1	2	0	0	1.0	
i 1	196.48755782312926	0.2525	75	1102	6	5	11	2	0	-2	2	0	0	2.1662443531096365	
i 1	196.50602040816327	1.01	74	218	6	3	3	8	0	-2	8	0	0	3.0	
i 1	196.51083673469387	1.01	74	716	3	4	9	2	0	-1	2	0	0	3.0	
i 1	196.74879591836734	0.2525	71	1102	1	24	7	2	0	-2	2	0	0	5.0	
i 1	196.75040136054423	0.2525	71	218	2	20	15	8	0	1	8	0	0	1.0	
i 1	196.75521768707483	0.2525	74	716	1	24	5	2	0	1	2	0	0	5.0	
i 1	196.76244217687074	0.2525	74	1102	6	1	14	2	0	-1	2	0	0	2.0438274789689523	
i 1	196.7632448979592	0.2525	74	716	2	20	15	2	0	1	2	0	0	1.0	
i 1	196.98916326530613	0.2525	71	716	6	1	15	8	0	-2	8	0	0	2.0438274789689523	
i 1	196.99237414965987	3.535	74	1102	1	20	9	8	0	1	8	0	0	1.0	
i 1	197.00361224489797	0.2525	71	716	1	20	4	2	0	1	2	0	0	1.0	
i 1	197.0044149659864	3.535	74	1102	1	20	8	2	0	1	2	0	0	1.0	
i 1	197.24237414965987	1.5150000000000001	71	1102	1	20	9	2	0	1	2	0	0	1.0	
i 1	197.26244217687074	0.2525	74	716	2	3	2	2	0	-1	2	0	0	3.0	
i 1	197.26645578231293	1.5150000000000001	74	716	1	24	6	2	0	1	2	0	0	5.0	
i 1	197.48514965986394	1.5150000000000001	72	716	6	5	6	2	0	-2	2	0	0	2.1662443531096365	
i 1	197.49478231292517	0.7575000000000001	71	1102	3	9	14	8	0	-2	8	0	0	2.0	
i 1	197.5068231292517	1.5150000000000001	72	1102	6	5	10	2	0	-2	2	0	0	2.1662443531096365	
i 1	197.51404761904763	0.7575000000000001	74	218	5	4	7	2	0	-1	2	0	0	3.0	
i 1	197.73996598639457	1.7675	74	1102	6	1	11	2	0	-1	2	0	0	2.0438274789689523	
i 1	197.74397959183673	1.7675	71	218	5	24	15	2	0	-2	2	0	0	3.0438274789689523	
i 1	197.74397959183673	0.2525	74	716	3	4	14	2	0	-1	2	0	0	3.0	
i 1	198.2319387755102	1.2625	74	716	5	2	11	2	0	-1	2	0	0	3.0	
i 1	198.25040136054423	1.2625	71	1102	3	9	15	2	0	-1	2	0	0	2.0	
i 1	198.25521768707483	0.2525	74	716	6	2	14	8	0	-2	8	0	0	3.0	
i 1	198.5156530612245	2.525	71	716	1	20	7	2	0	1	2	0	0	1.0	
i 1	198.7520068027211	1.7675	72	218	7	5	12	2	0	1	2	0	0	2.1662443531096365	
i 1	198.76966666666667	0.2525	71	218	7	1	10	8	0	-1	8	0	0	2.0438274789689523	
i 1	198.9883605442177	1.5150000000000001	74	716	3	4	7	2	0	-1	2	0	0	3.0	
i 1	198.98916326530613	1.01	71	716	6	1	8	8	0	-2	8	0	0	2.0438274789689523	
i 1	198.990768707483	1.5150000000000001	74	218	6	3	3	8	0	-2	8	0	0	3.0	
i 1	199.01083673469387	1.01	74	1102	6	1	12	2	0	-2	2	0	0	2.0438274789689523	
i 1	199.01244217687074	1.5150000000000001	75	1102	6	5	2	2	0	-2	2	0	0	2.1662443531096365	
i 1	199.24478231292517	0.2525	72	716	6	5	3	2	0	-2	2	0	0	2.1662443531096365	
i 1	199.4955850340136	1.01	71	218	7	1	7	8	0	-1	8	0	0	2.0438274789689523	
i 1	199.51404761904763	1.01	74	716	4	24	6	2	0	-2	2	0	0	3.0438274789689523	
i 1	199.76725850340137	0.2525	75	716	6	5	12	2	0	1	2	0	0	2.1662443531096365	
i 1	199.98996598639457	1.2625	74	716	6	2	5	8	0	-2	8	0	0	3.0	
i 1	199.9979931972789	1.2625	74	716	2	3	2	2	0	-1	2	0	0	3.0	
i 1	200.23514965986394	1.5150000000000001	74	1102	6	1	2	2	0	-2	2	0	0	2.0438274789689523	
i 1	200.259231292517	1.5150000000000001	71	716	6	1	10	8	0	-2	8	0	0	2.0438274789689523	
i 1	200.26003401360543	0.7575000000000001	72	1102	6	5	6	2	0	-2	2	0	0	2.1662443531096365	
i 1	200.4843469387755	0.505	74	716	1	24	8	2	0	1	2	0	0	5.0	
i 1	200.48514965986394	0.2525	74	218	2	20	2	2	0	-2	2	0	0	1.0	
i 1	200.48595238095237	0.2525	74	1102	6	1	8	2	0	-1	2	0	0	2.0438274789689523	
i 1	200.49638775510203	1.5150000000000001	71	1102	3	9	4	2	0	-1	2	0	0	2.0	
i 1	200.49959863945577	0.2525	74	218	2	24	10	2	0	1	2	0	0	5.0	
i 1	200.5116394557823	1.2625	75	716	6	5	2	2	0	1	2	0	0	2.1662443531096365	
i 1	200.51725850340137	1.2625	75	716	6	5	3	2	0	1	2	0	0	2.1662443531096365	
i 1	200.73274149659863	0.2525	74	716	5	1	8	8	0	-2	8	0	0	2.0438274789689523	
i 1	200.73595238095237	0.2525	71	1102	1	20	12	2	0	1	2	0	0	1.0	
i 1	200.74719047619047	0.505	74	1102	1	20	6	2	0	1	2	0	0	1.0	
i 1	200.75762585034013	0.2525	71	1102	1	20	8	2	0	1	2	0	0	1.0	
i 1	200.76003401360543	0.7575000000000001	71	1102	1	24	4	2	0	-2	2	0	0	5.0	
i 1	200.76083673469387	1.2625	74	716	5	2	3	2	0	-1	2	0	0	3.0	
i 1	200.9931768707483	0.2525	72	218	7	5	2	2	0	1	2	0	0	2.1662443531096365	
i 1	201.01645578231293	0.505	74	716	2	20	10	2	0	1	2	0	0	1.0	
i 1	201.23755782312926	0.2525	74	716	4	24	12	2	0	-2	2	0	0	3.0438274789689523	
i 1	201.23755782312926	0.2525	74	218	2	20	8	2	0	-2	2	0	0	1.0	
i 1	201.24719047619047	0.2525	72	716	6	5	7	8	0	1	8	0	0	2.1662443531096365	
i 1	201.2632448979592	1.01	74	716	1	24	4	2	0	1	2	0	0	5.0	
i 1	201.4819387755102	1.01	72	1102	6	5	3	2	0	-2	2	0	0	2.1662443531096365	
i 1	201.48274149659863	3.7875	74	1102	1	20	15	2	0	1	2	0	0	1.0	
i 1	201.48354421768707	0.505	72	218	7	5	15	2	0	1	2	0	0	2.1662443531096365	
i 1	201.49397959183673	0.505	71	1102	1	20	13	8	0	1	8	0	0	1.0	
i 1	201.49638775510203	1.01	74	716	6	2	6	8	0	-2	8	0	0	3.0	
i 1	201.49959863945577	0.7575000000000001	74	716	2	3	4	2	0	-1	2	0	0	3.0	
i 1	201.50361224489797	1.01	72	716	6	5	9	2	0	-2	2	0	0	2.1662443531096365	
i 1	201.509231292517	0.505	75	1102	6	5	10	2	0	-2	2	0	0	2.1662443531096365	
i 1	201.51003401360543	1.01	71	218	5	24	7	2	0	-2	2	0	0	3.0438274789689523	
i 1	201.51244217687074	1.01	74	1102	6	1	14	2	0	-1	2	0	0	2.0438274789689523	
i 1	201.51645578231293	0.505	74	1102	1	20	7	2	0	1	2	0	0	1.0	
i 1	201.7319387755102	0.7575000000000001	74	716	3	4	7	2	0	-1	2	0	0	3.0	
i 1	201.76966666666667	2.02	74	218	6	3	3	8	0	-2	8	0	0	3.0	
i 1	201.98916326530613	0.2525	71	1102	1	24	1	2	0	-2	2	0	0	5.0	
i 1	201.99237414965987	0.2525	71	716	2	20	13	2	0	-2	2	0	0	1.0	
i 1	201.99237414965987	0.2525	71	716	2	20	4	2	0	-2	2	0	0	1.0	
i 1	202.0044149659864	0.2525	74	218	2	20	5	2	0	-2	2	0	0	1.0	
i 1	202.00602040816327	1.2625	71	716	1	20	16	2	0	1	2	0	0	1.0	
i 1	202.2479931972789	0.2525	71	716	6	1	6	2	0	-1	2	0	0	2.0438274789689523	
i 1	202.24959863945577	0.505	71	1102	1	20	9	2	0	1	2	0	0	1.0	
i 1	202.2520068027211	0.2525	75	716	6	5	13	2	0	1	2	0	0	2.1662443531096365	
i 1	202.48033333333333	2.2725	71	218	5	24	11	2	0	-2	2	0	0	3.0358440348444966	
i 1	202.4819387755102	2.7775	63	218	6	13	16	16	0	2	16	0	0	0.9817685575960969	
i 1	202.48354421768707	0.2525	71	218	5	1	7	8	0	-1	8	0	0	2.0358440348444966	
i 1	202.4843469387755	2.7775	61	716	5	13	2	16	0	2	16	0	0	1.4131775125293653	
i 1	202.48514965986394	2.7775	61	218	6	7	5	1	0	1	1	0	0	2.481934662982289	
i 1	202.48595238095237	2.7775	61	1102	4	16	11	16	0	1	16	0	0	3.764478115784986	
i 1	202.4867551020408	2.7775	63	218	6	17	13	1	0	1	1	0	0	2.640561506326075	
i 1	202.48755782312926	0.2525	72	716	6	5	11	8	0	1	8	0	0	2.004130294487196	
i 1	202.4883605442177	2.7775	63	716	6	17	14	16	0	2	16	0	0	2.640561506326075	
i 1	202.49157142857143	2.7775	63	218	6	15	3	1	0	2	1	0	0	2.5888278141571757	
i 1	202.4931768707483	2.7775	61	716	4	12	3	16	0	2	16	0	0	3.764478115784986	
i 1	202.49397959183673	1.2625	74	716	2	4	16	2	0	-1	2	0	0	3.0	
i 1	202.4955850340136	2.7775	63	218	6	17	6	1	0	1	1	0	0	2.640561506326075	
i 1	202.4955850340136	2.7775	61	1102	4	18	9	16	0	1	16	0	0	2.640561506326075	
i 1	202.4955850340136	2.7775	63	716	5	14	8	1	0	1	1	0	0	3.2320177156753847	
i 1	202.4955850340136	2.7775	61	716	5	14	7	16	0	2	16	0	0	3.2320177156753847	
i 1	202.49959863945577	1.01	72	716	6	5	13	2	0	-2	2	0	0	2.004130294487196	
i 1	202.50602040816327	2.7775	63	716	5	14	7	1	0	2	1	0	0	4.940128417412796	
i 1	202.50602040816327	0.2525	74	218	5	4	9	2	0	-1	2	0	0	3.0	
i 1	202.5068231292517	2.7775	61	716	4	19	11	16	0	1	16	0	0	2.640561506326075	
i 1	202.50762585034013	2.02	74	1102	6	1	14	2	0	-1	2	0	0	2.0358440348444966	
i 1	202.509231292517	2.7775	61	1102	4	16	6	1	0	2	1	0	0	3.764478115784986	
i 1	202.51083673469387	2.7775	63	218	6	15	1	16	0	1	16	0	0	2.5888278141571757	
i 1	202.5132448979592	2.7775	63	1102	4	18	3	1	0	2	1	0	0	2.640561506326075	
i 1	202.51645578231293	2.7775	63	716	4	12	3	1	0	2	1	0	0	3.764478115784986	
i 1	202.51725850340137	1.01	72	1102	6	5	12	2	0	-2	2	0	0	2.004130294487196	
i 1	202.7367551020408	0.7575000000000001	71	1102	1	24	7	2	0	-2	2	0	0	5.0	
i 1	202.7383605442177	0.2525	71	716	2	20	8	2	0	-2	2	0	0	1.0	
i 1	202.73996598639457	0.2525	75	716	6	5	4	2	0	1	2	0	0	2.004130294487196	
i 1	202.74397959183673	0.2525	74	716	2	20	14	2	0	-2	2	0	0	1.0	
i 1	202.74638775510203	0.2525	74	218	2	24	7	2	0	-2	2	0	0	5.0	
i 1	202.7656530612245	0.2525	71	218	2	20	7	8	0	-2	8	0	0	1.0	
i 1	202.9819387755102	1.7675	72	716	6	5	15	8	0	1	8	0	0	2.004130294487196	
i 1	202.98354421768707	0.2525	74	1102	1	20	12	2	0	1	2	0	0	1.0	
i 1	202.98595238095237	1.7675	72	218	6	5	9	2	0	-2	2	0	0	2.004130294487196	
i 1	202.98916326530613	0.505	74	716	5	2	14	8	0	-2	8	0	0	3.0	
i 1	203.00762585034013	0.2525	71	1102	1	20	6	2	0	1	2	0	0	1.0	
i 1	203.26886394557823	0.505	74	716	6	1	6	8	0	-2	8	0	0	2.0358440348444966	
i 1	203.5116394557823	1.5150000000000001	74	218	5	4	8	2	0	-1	2	0	0	3.0	
i 1	203.5156530612245	1.5150000000000001	71	1102	5	9	9	8	0	-2	8	0	0	2.0	
i 1	203.740768707483	1.01	71	1102	1	24	6	2	0	-2	2	0	0	5.0	
i 1	203.75602040816327	0.2525	71	716	6	1	16	8	0	-2	8	0	0	2.0358440348444966	
i 1	203.75842857142857	0.2525	71	218	2	24	11	2	0	-2	2	0	0	5.0	
i 1	203.759231292517	1.5150000000000001	71	716	1	20	14	2	0	1	2	0	0	1.0	
i 1	203.76003401360543	0.2525	71	1102	3	9	7	2	0	-1	2	0	0	2.0	
i 1	203.98033333333333	0.2525	74	1102	1	20	16	2	0	-2	2	0	0	1.0	
i 1	203.98514965986394	0.2525	74	716	2	4	13	2	0	-1	2	0	0	3.0	
i 1	203.98755782312926	1.2625	71	218	5	1	6	8	0	-1	8	0	0	2.0358440348444966	
i 1	203.990768707483	0.7575000000000001	71	1102	1	20	3	2	0	-2	2	0	0	1.0	
i 1	204.23274149659863	0.505	75	716	6	5	10	2	0	1	2	0	0	2.004130294487196	
i 1	204.23514965986394	1.01	74	716	4	24	11	2	0	-2	2	0	0	3.0358440348444966	
i 1	204.24638775510203	0.7575000000000001	75	716	6	5	7	2	0	1	2	0	0	2.004130294487196	
i 1	204.48113605442177	0.7575000000000001	72	716	6	5	11	2	0	-2	2	0	0	2.004130294487196	
i 1	204.50602040816327	0.7575000000000001	72	1102	6	5	6	2	0	-2	2	0	0	2.004130294487196	
i 1	204.73033333333333	0.505	74	716	5	2	10	2	0	-1	2	0	0	3.0	
i 1	204.73514965986394	0.505	71	1102	3	9	15	2	0	-1	2	0	0	2.0	
i 1	204.73996598639457	0.2525	74	1102	1	20	7	2	0	-2	2	0	0	1.0	
i 1	204.75361224489797	0.505	71	716	6	1	8	8	0	-2	8	0	0	2.0358440348444966	
i 1	204.98033333333333	0.2525	75	1102	6	5	6	2	0	-2	2	0	0	2.004130294487196	
i 1	204.98354421768707	0.2525	74	716	2	20	3	2	0	1	2	0	0	1.0	
i 1	204.9843469387755	0.2525	74	716	2	20	6	2	0	1	2	0	0	1.0	
i 1	204.99638775510203	0.2525	71	218	2	20	14	2	0	1	2	0	0	1.0	
i 1	205.0020068027211	0.2525	74	716	5	2	14	8	0	-2	8	0	0	3.0	
i 1	205.23033333333333	1.2625	75	200	7	5	14	2	0	1	2	0	0	2.004130294487196	
i 1	205.2319387755102	3.0300000000000002	71	200	2	20	5	2	0	-2	2	0	0	1.0	
i 1	205.23354421768707	9.8475	61	586	5	15	8	1	0	2	1	0	0	2.5888278141571757	
i 1	205.2343469387755	9.8475	61	902	5	14	5	16	0	2	16	0	0	4.940128417412796	
i 1	205.2343469387755	0.2525	75	200	7	5	12	2	0	-2	2	0	0	2.004130294487196	
i 1	205.23514965986394	0.2525	71	586	5	1	16	2	0	-2	2	0	0	2.0358440348444966	
i 1	205.23514965986394	0.2525	74	902	5	2	3	8	0	-1	8	0	0	3.0	
i 1	205.23514965986394	9.8475	63	586	5	13	15	1	0	1	1	0	0	0.9817685575960969	
i 1	205.2367551020408	31.31	61	200	5	18	8	16	0	2	16	0	0	2.640561506326075	
i 1	205.2383605442177	4.04	61	586	6	7	13	1	0	1	1	0	0	2.481934662982289	
i 1	205.23916326530613	2.02	74	902	5	2	10	2	0	-2	2	0	0	3.0	
i 1	205.23916326530613	9.8475	61	200	5	19	4	16	0	2	16	0	0	2.640561506326075	
i 1	205.23916326530613	1.2625	72	902	6	5	3	8	0	1	8	0	0	2.004130294487196	
i 1	205.23996598639457	1.2625	74	586	4	24	3	2	0	-1	2	0	0	3.0358440348444966	
i 1	205.24157142857143	2.02	71	200	4	9	12	8	0	-1	8	0	0	2.0	
i 1	205.24237414965987	9.8475	61	586	6	17	1	16	0	2	16	0	0	2.640561506326075	
i 1	205.2431768707483	9.8475	63	200	5	12	13	16	0	1	16	0	0	3.764478115784986	
i 1	205.24397959183673	1.01	71	200	5	24	6	2	0	-2	2	0	0	3.0358440348444966	
i 1	205.24478231292517	9.8475	63	200	5	12	14	16	0	2	16	0	0	3.764478115784986	
i 1	205.24719047619047	9.8475	63	902	5	14	14	1	0	2	1	0	0	3.2320177156753847	
i 1	205.2479931972789	54.2875	63	200	5	16	1	1	0	2	1	0	0	3.764478115784986	
i 1	205.24959863945577	9.8475	63	586	6	17	11	1	0	2	1	0	0	2.640561506326075	
i 1	205.25280952380953	24.4925	63	200	5	18	3	1	0	1	1	0	0	2.640561506326075	
i 1	205.25602040816327	4.04	63	902	6	17	11	1	0	2	1	0	0	2.640561506326075	
i 1	205.25762585034013	51.7625	61	200	5	16	12	16	0	2	16	0	0	3.764478115784986	
i 1	205.25842857142857	9.8475	63	586	5	15	1	16	0	2	16	0	0	2.5888278141571757	
i 1	205.2632448979592	9.8475	63	902	5	14	10	1	0	2	1	0	0	3.2320177156753847	
i 1	205.2656530612245	4.7975	71	200	1	24	3	2	0	1	2	0	0	5.0	
i 1	205.26645578231293	9.8475	63	902	5	13	12	16	0	1	16	0	0	1.4131775125293653	
i 1	205.48595238095237	0.2525	74	902	2	20	7	2	0	1	2	0	0	1.0	
i 1	205.49638775510203	0.2525	71	586	4	4	9	8	0	-1	8	0	0	3.0	
i 1	205.49879591836734	0.2525	71	200	7	1	15	2	0	-1	2	0	0	2.0358440348444966	
i 1	205.50120408163266	0.2525	74	902	2	20	3	8	0	-2	8	0	0	1.0	
i 1	205.50120408163266	0.2525	71	586	2	20	16	8	0	1	8	0	0	1.0	
i 1	205.51404761904763	1.01	74	200	2	20	4	2	0	-2	2	0	0	1.0	
i 1	205.73755782312926	1.2625	71	200	7	1	12	2	0	-2	2	0	0	2.0358440348444966	
i 1	205.74157142857143	0.505	71	200	1	20	1	2	0	1	2	0	0	1.0	
i 1	205.7431768707483	0.7575000000000001	74	902	5	2	10	8	0	-1	8	0	0	3.0	
i 1	205.74397959183673	0.505	71	200	2	20	5	2	0	1	2	0	0	1.0	
i 1	205.74638775510203	0.2525	75	200	7	5	16	2	0	-2	2	0	0	2.004130294487196	
i 1	205.75602040816327	1.2625	74	902	6	1	10	2	0	-2	2	0	0	2.0358440348444966	
i 1	205.759231292517	1.01	74	200	6	9	1	8	0	-1	8	0	0	2.0	
i 1	205.98514965986394	0.7575000000000001	75	902	6	5	16	2	0	1	2	0	0	2.004130294487196	
i 1	205.99157142857143	0.7575000000000001	75	200	7	5	16	2	0	-2	2	0	0	2.004130294487196	
i 1	206.23354421768707	0.505	71	586	2	20	13	8	0	1	8	0	0	1.0	
i 1	206.24638775510203	2.02	75	200	7	5	15	2	0	-2	2	0	0	2.004130294487196	
i 1	206.25120408163266	0.505	71	902	2	20	8	2	0	1	2	0	0	1.0	
i 1	206.25361224489797	2.2725	75	586	6	5	4	2	0	-2	2	0	0	2.004130294487196	
i 1	206.48996598639457	1.7675	74	200	7	1	2	2	0	-1	2	0	0	2.0358440348444966	
i 1	206.50842857142857	1.5150000000000001	71	586	5	1	5	2	0	-2	2	0	0	2.0358440348444966	
i 1	206.7383605442177	2.525	71	200	3	3	10	2	0	-1	2	0	0	3.0	
i 1	206.74719047619047	2.525	74	586	5	3	7	2	0	-2	2	0	0	3.0	
i 1	206.74879591836734	0.2525	71	200	2	20	3	2	0	-2	2	0	0	1.0	
i 1	206.74959863945577	0.2525	71	200	1	20	8	8	0	-2	8	0	0	1.0	
i 1	206.76244217687074	0.2525	75	200	7	5	12	2	0	1	2	0	0	2.004130294487196	
i 1	206.99478231292517	0.2525	74	902	6	1	14	2	0	-2	2	0	0	2.0358440348444966	
i 1	207.00602040816327	0.505	75	200	7	5	15	2	0	-2	2	0	0	2.004130294487196	
i 1	207.01083673469387	0.2525	74	586	2	20	11	2	0	-2	2	0	0	1.0	
i 1	207.01404761904763	0.2525	74	902	2	20	16	2	0	1	2	0	0	1.0	
i 1	207.0180612244898	1.01	74	200	2	20	7	2	0	-2	2	0	0	1.0	
i 1	207.23996598639457	0.505	74	200	1	20	12	2	0	-2	2	0	0	1.0	
i 1	207.25842857142857	0.2525	71	200	5	24	15	2	0	-2	2	0	0	3.0358440348444966	
i 1	207.25842857142857	0.2525	71	586	4	4	13	8	0	-1	8	0	0	3.0	
i 1	207.26404761904763	0.505	74	200	2	20	8	2	0	1	2	0	0	1.0	
i 1	207.4867551020408	0.2525	75	200	7	5	1	2	0	-2	2	0	0	2.004130294487196	
i 1	207.48916326530613	3.2825	71	200	7	1	16	2	0	-2	2	0	0	2.0358440348444966	
i 1	207.51244217687074	1.7675	74	902	6	1	11	2	0	-2	2	0	0	2.0358440348444966	
i 1	207.51966666666667	0.2525	74	200	6	9	16	8	0	-1	8	0	0	2.0	
i 1	207.73033333333333	0.2525	71	586	2	20	1	2	0	-2	2	0	0	1.0	
i 1	207.73514965986394	1.7675	72	902	6	5	8	8	0	1	8	0	0	2.004130294487196	
i 1	207.74638775510203	1.7675	75	200	7	5	4	2	0	1	2	0	0	2.004130294487196	
i 1	207.7616394557823	0.2525	74	902	2	20	16	2	0	-2	2	0	0	1.0	
i 1	207.99638775510203	1.5150000000000001	74	200	1	20	8	2	0	1	2	0	0	1.0	
i 1	207.99879591836734	2.02	71	200	2	20	2	2	0	-2	2	0	0	1.0	
i 1	208.25521768707483	0.2525	74	902	5	2	1	8	0	-1	8	0	0	3.0	
i 1	208.2680612244898	0.2525	74	586	4	24	5	2	0	-1	2	0	0	3.0358440348444966	
i 1	208.4819387755102	1.5150000000000001	71	586	4	4	13	8	0	-1	8	0	0	3.0	
i 1	208.48274149659863	0.2525	71	200	7	1	7	2	0	-1	2	0	0	2.0358440348444966	
i 1	208.48595238095237	2.2725	71	200	1	24	2	8	0	1	8	0	0	5.0	
i 1	208.49638775510203	0.7575000000000001	74	200	2	20	6	2	0	-2	2	0	0	1.0	
i 1	208.5044149659864	2.2725	74	200	2	24	14	2	0	-2	2	0	0	5.0	
i 1	208.51083673469387	0.2525	75	200	7	5	12	2	0	-2	2	0	0	2.004130294487196	
i 1	208.73354421768707	1.01	75	200	7	5	13	2	0	-2	2	0	0	2.004130294487196	
i 1	208.73755782312926	1.2625	74	200	3	4	8	8	0	-2	8	0	0	3.0	
i 1	208.99397959183673	1.01	75	586	6	5	11	2	0	-2	2	0	0	2.004130294487196	
i 1	209.23354421768707	5.8075	61	200	5	19	6	16	0	2	16	0	0	2.640561506326075	
i 1	209.2343469387755	1.5150000000000001	74	200	6	9	11	8	0	-1	8	0	0	2.0	
i 1	209.23595238095237	0.2525	74	200	7	1	10	2	0	-1	2	0	0	2.0358440348444966	
i 1	209.2367551020408	2.02	75	200	7	5	5	2	0	-2	2	0	0	2.004130294487196	
i 1	209.23916326530613	0.2525	74	200	1	20	10	2	0	-2	2	0	0	1.0	
i 1	209.24719047619047	1.5150000000000001	74	902	5	1	16	2	0	-2	2	0	0	2.0358440348444966	
i 1	209.25120408163266	2.02	75	902	6	5	11	2	0	1	2	0	0	2.004130294487196	
i 1	209.2568231292517	5.8075	61	586	6	7	9	1	0	1	1	0	0	2.481934662982289	
i 1	209.49237414965987	0.505	71	586	6	1	14	2	0	-2	2	0	0	2.0358440348444966	
i 1	209.49959863945577	1.2625	71	200	2	20	16	2	0	-2	2	0	0	1.0	
i 1	209.50280952380953	1.2625	74	200	2	20	11	2	0	-2	2	0	0	1.0	
i 1	209.51485034013606	1.2625	74	902	5	2	14	8	0	-1	8	0	0	3.0	
i 1	209.9867551020408	1.01	71	200	3	3	3	2	0	-1	2	0	0	3.0	
i 1	210.00361224489797	0.2525	72	902	6	5	11	8	0	1	8	0	0	2.004130294487196	
i 1	210.0116394557823	2.02	71	200	5	24	13	2	0	-2	2	0	0	3.0358440348444966	
i 1	210.23113605442177	0.2525	75	200	7	5	3	2	0	-2	2	0	0	2.004130294487196	
i 1	210.2455850340136	2.2725	74	200	1	20	11	2	0	-2	2	0	0	1.0	
i 1	210.24719047619047	2.2725	74	586	4	24	12	2	0	-1	2	0	0	3.0358440348444966	
i 1	210.25120408163266	0.7575000000000001	74	586	5	3	7	2	0	-2	2	0	0	3.0	
i 1	210.25280952380953	0.505	74	200	1	20	2	2	0	1	2	0	0	1.0	
i 1	210.25361224489797	3.2825	71	200	1	24	3	2	0	1	2	0	0	5.0	
i 1	210.26645578231293	0.505	71	200	2	20	16	2	0	-2	2	0	0	1.0	
i 1	210.4843469387755	1.2625	74	902	5	2	2	2	0	-2	2	0	0	3.0	
i 1	210.48755782312926	3.535	75	200	7	5	13	2	0	1	2	0	0	2.004130294487196	
i 1	210.50762585034013	1.2625	71	200	6	9	2	8	0	-1	8	0	0	2.0	
i 1	210.74397959183673	0.2525	74	200	7	1	8	2	0	-1	2	0	0	2.0358440348444966	
i 1	210.74959863945577	0.2525	71	902	2	20	12	2	0	-2	2	0	0	1.0	
i 1	210.7520068027211	0.2525	74	586	2	20	3	2	0	1	2	0	0	1.0	
i 1	210.76725850340137	3.2825	72	902	6	5	11	8	0	1	8	0	0	2.004130294487196	
i 1	210.98274149659863	0.2525	74	200	3	4	2	8	0	-2	8	0	0	3.0	
i 1	210.99959863945577	1.7675	74	200	1	20	4	2	0	1	2	0	0	1.0	
i 1	211.0180612244898	0.2525	74	902	6	1	14	2	0	-2	2	0	0	2.0358440348444966	
i 1	211.01966666666667	1.7675	74	200	2	20	2	2	0	1	2	0	0	1.0	
i 1	211.23595238095237	1.5150000000000001	74	902	5	2	8	8	0	-1	8	0	0	3.0	
i 1	211.23595238095237	1.5150000000000001	74	200	6	9	6	8	0	-1	8	0	0	2.0	
i 1	211.2479931972789	0.2525	75	200	7	5	1	2	0	-2	2	0	0	2.004130294487196	
i 1	211.26003401360543	2.2725	71	586	6	1	1	2	0	-2	2	0	0	2.0358440348444966	
i 1	211.48755782312926	0.2525	75	586	6	5	4	2	0	-2	2	0	0	2.004130294487196	
i 1	211.4883605442177	1.01	74	200	1	24	5	2	0	-2	2	0	0	5.0	
i 1	211.509231292517	1.01	74	200	2	24	11	2	0	-2	2	0	0	5.0	
i 1	211.51485034013606	2.2725	74	200	7	1	11	2	0	-1	2	0	0	2.0358440348444966	
i 1	211.7319387755102	0.2525	74	586	5	3	5	2	0	-2	2	0	0	3.0	
i 1	211.759231292517	0.2525	75	586	6	5	2	2	0	-2	2	0	0	2.004130294487196	
i 1	212.00602040816327	0.2525	71	200	3	3	12	2	0	-1	2	0	0	3.0	
i 1	212.00762585034013	0.505	75	586	6	5	4	2	0	-2	2	0	0	2.004130294487196	
i 1	212.24719047619047	1.5150000000000001	71	200	6	9	10	8	0	-1	8	0	0	2.0	
i 1	212.26083673469387	1.5150000000000001	74	902	5	2	12	2	0	-2	2	0	0	3.0	
i 1	212.5020068027211	1.01	71	200	2	20	14	2	0	-2	2	0	0	1.0	
i 1	212.51083673469387	0.2525	71	200	7	1	3	2	0	-1	2	0	0	2.0358440348444966	
i 1	212.51645578231293	0.2525	75	586	6	5	3	2	0	-2	2	0	0	2.004130294487196	
i 1	212.73755782312926	1.7675	74	586	4	24	15	2	0	-1	2	0	0	3.0358440348444966	
i 1	212.74638775510203	0.2525	75	586	6	5	16	2	0	-2	2	0	0	2.004130294487196	
i 1	212.7479931972789	0.2525	74	586	5	3	4	2	0	-2	2	0	0	3.0	
i 1	212.7632448979592	0.505	74	902	2	20	7	2	0	-2	2	0	0	1.0	
i 1	212.7656530612245	0.505	71	586	2	20	14	2	0	1	2	0	0	1.0	
i 1	212.9931768707483	0.505	75	200	7	5	15	2	0	-2	2	0	0	2.004130294487196	
i 1	213.00120408163266	0.2525	74	902	5	2	15	8	0	-1	8	0	0	3.0	
i 1	213.00602040816327	1.5150000000000001	74	200	1	20	11	2	0	-2	2	0	0	1.0	
i 1	213.01886394557823	1.7675	71	200	5	24	4	2	0	-2	2	0	0	3.0358440348444966	
i 1	213.2319387755102	1.7675	71	200	3	3	5	2	0	-1	2	0	0	3.0	
i 1	213.2455850340136	1.7675	74	586	5	3	10	2	0	-2	2	0	0	3.0	
i 1	213.26083673469387	1.01	74	200	1	20	15	2	0	-2	2	0	0	1.0	
i 1	213.2680612244898	0.2525	74	200	2	20	15	2	0	-2	2	0	0	1.0	
i 1	213.4843469387755	1.5150000000000001	75	902	6	5	8	2	0	1	2	0	0	2.004130294487196	
i 1	213.48755782312926	2.02	75	200	7	5	12	2	0	-2	2	0	0	2.004130294487196	
i 1	213.4979931972789	0.2525	71	200	2	20	6	2	0	-2	2	0	0	1.0	
i 1	213.73113605442177	0.2525	71	200	2	20	9	2	0	-2	2	0	0	1.0	
i 1	213.76003401360543	0.505	74	200	6	9	6	8	0	-1	8	0	0	2.0	
i 1	213.76485034013606	1.5150000000000001	71	200	7	1	5	2	0	-2	2	0	0	2.0358440348444966	
i 1	213.98274149659863	1.01	74	902	5	1	14	2	0	-2	2	0	0	2.0358440348444966	
i 1	213.99478231292517	0.7575000000000001	74	200	2	24	9	2	0	-2	2	0	0	5.0	
i 1	214.00842857142857	1.01	71	200	1	24	16	2	0	1	2	0	0	5.0	
i 1	214.0116394557823	0.2525	75	200	7	5	14	2	0	-2	2	0	0	2.004130294487196	
i 1	214.24157142857143	0.505	74	902	5	2	8	8	0	-1	8	0	0	3.0	
i 1	214.24157142857143	0.2525	71	902	2	20	11	2	0	1	2	0	0	1.0	
i 1	214.25040136054423	0.2525	74	902	2	20	4	2	0	1	2	0	0	1.0	
i 1	214.25120408163266	0.2525	75	200	7	5	4	2	0	-2	2	0	0	2.004130294487196	
i 1	214.2520068027211	1.5150000000000001	71	200	2	20	13	2	0	-2	2	0	0	1.0	
i 1	214.2616394557823	0.2525	74	586	2	20	2	2	0	-2	2	0	0	1.0	
i 1	214.4843469387755	1.2625	74	200	2	20	2	2	0	-2	2	0	0	1.0	
i 1	214.48996598639457	0.505	74	200	1	20	15	2	0	1	2	0	0	1.0	
i 1	214.49959863945577	1.7675	74	200	2	20	9	2	0	1	2	0	0	1.0	
i 1	214.73916326530613	0.2525	74	902	5	2	9	2	0	-2	2	0	0	3.0	
i 1	214.7632448979592	3.535	71	200	7	1	10	2	0	-1	2	0	0	2.0358440348444966	
i 1	214.98033333333333	35.097500000000004	61	698	4	19	2	1	0	1	1	0	0	2.640561506326075	
i 1	214.98113605442177	0.505	74	1084	5	2	1	2	0	-2	2	0	0	3.0	
i 1	214.9819387755102	21.4625	63	1084	5	13	16	16	0	2	16	0	0	1.4131775125293653	
i 1	214.9843469387755	44.44	61	698	5	12	7	16	0	2	16	0	0	3.764478115784986	
i 1	214.98514965986394	1.01	63	1084	5	14	3	1	0	1	1	0	0	3.2320177156753847	
i 1	214.9867551020408	14.645	61	1084	5	14	13	16	0	2	16	0	0	4.940128417412796	
i 1	214.98755782312926	1.5150000000000001	71	698	3	4	8	2	0	-1	2	0	0	3.0	
i 1	214.99157142857143	1.01	71	1084	5	1	8	8	0	-1	8	0	0	2.0358440348444966	
i 1	214.99157142857143	14.645	63	698	5	13	9	16	0	1	16	0	0	0.9817685575960969	
i 1	214.99397959183673	44.44	61	698	5	12	7	16	0	2	16	0	0	3.764478115784986	
i 1	214.99478231292517	7.8275	61	698	6	17	2	1	0	1	1	0	0	2.640561506326075	
i 1	214.9979931972789	2.2725	71	698	1	24	15	2	0	1	2	0	0	5.0	
i 1	214.99879591836734	0.505	72	1084	6	5	3	2	0	1	2	0	0	2.004130294487196	
i 1	214.99879591836734	21.4625	61	698	6	7	14	16	0	2	16	0	0	2.481934662982289	
i 1	215.00120408163266	1.7675	71	698	5	3	13	8	0	-2	8	0	0	3.0	
i 1	215.00120408163266	2.02	75	698	6	5	4	2	0	-2	2	0	0	2.004130294487196	
i 1	215.00842857142857	28.28	63	698	5	15	14	16	0	1	16	0	0	2.5888278141571757	
i 1	215.009231292517	35.097500000000004	63	698	5	15	1	1	0	2	1	0	0	2.5888278141571757	
i 1	215.009231292517	0.2525	72	1084	6	5	14	2	0	-2	2	0	0	2.004130294487196	
i 1	215.01645578231293	0.505	71	698	3	3	16	8	0	-1	8	0	0	3.0	
i 1	215.01725850340137	28.28	63	698	4	19	4	1	0	1	1	0	0	2.640561506326075	
i 1	215.01725850340137	2.2725	74	698	1	20	6	2	0	1	2	0	0	1.0	
i 1	215.01886394557823	1.01	63	698	6	17	8	1	0	1	1	0	0	2.640561506326075	
i 1	215.01966666666667	2.02	72	698	6	5	7	8	0	-2	8	0	0	2.004130294487196	
i 1	215.01966666666667	7.8275	63	1084	5	14	14	1	0	1	1	0	0	3.2320177156753847	
i 1	215.26083673469387	1.01	74	200	2	24	7	2	0	-2	2	0	0	5.0	
i 1	215.2656530612245	0.505	74	698	4	24	4	2	0	-1	2	0	0	3.0358440348444966	
i 1	215.4843469387755	0.2525	75	200	7	5	4	2	0	1	2	0	0	2.004130294487196	
i 1	215.50842857142857	0.2525	71	698	4	4	2	2	0	-2	2	0	0	3.0	
i 1	215.7383605442177	0.2525	74	200	6	9	14	8	0	-1	8	0	0	2.0	
i 1	215.7568231292517	0.2525	74	698	4	24	1	8	0	-2	8	0	0	3.0358440348444966	
i 1	215.76485034013606	0.2525	72	1084	6	5	15	2	0	1	2	0	0	2.004130294487196	
i 1	215.99638775510203	2.525	75	698	6	5	1	2	0	1	2	0	0	2.004130294487196	
i 1	215.99719047619047	0.2525	74	698	6	1	11	8	0	-2	8	0	0	2.0358440348444966	
i 1	216.01083673469387	1.5150000000000001	74	1084	5	2	14	2	0	-2	2	0	0	3.0	
i 1	216.01725850340137	13.635	63	1084	3	14	3	1	0	1	1	0	0	3.2320177156753847	
i 1	216.01886394557823	2.02	71	1084	4	1	5	8	0	-1	8	0	0	2.0358440348444966	
i 1	216.01886394557823	1.5150000000000001	71	698	5	3	12	8	0	-1	8	0	0	3.0	
i 1	216.2343469387755	0.2525	71	200	5	1	3	2	0	-2	2	0	0	2.0358440348444966	
i 1	216.26003401360543	0.2525	71	698	1	20	3	2	0	-2	2	0	0	1.0	
i 1	216.49237414965987	2.7775	74	200	2	24	11	2	0	-2	2	0	0	5.0	
i 1	216.51083673469387	1.5150000000000001	72	1084	6	5	1	2	0	-2	2	0	0	2.004130294487196	
i 1	216.5156530612245	0.505	74	698	4	24	10	8	0	-2	8	0	0	3.0358440348444966	
i 1	216.74237414965987	2.2725	74	200	2	20	12	2	0	1	2	0	0	1.0	
i 1	216.7479931972789	2.02	71	698	1	24	4	2	0	-2	2	0	0	5.0	
i 1	216.75040136054423	1.7675	74	1084	5	2	15	2	0	-1	2	0	0	3.0	
i 1	216.76244217687074	2.02	71	698	1	20	9	2	0	-2	2	0	0	1.0	
i 1	216.98595238095237	1.7675	71	200	6	9	10	8	0	-1	8	0	0	2.0	
i 1	217.0044149659864	0.2525	71	200	5	1	12	2	0	-2	2	0	0	2.0358440348444966	
i 1	217.0116394557823	0.2525	75	200	6	5	7	2	0	1	2	0	0	2.004130294487196	
i 1	217.23755782312926	0.2525	74	698	6	1	3	8	0	-2	8	0	0	2.0358440348444966	
i 1	217.23996598639457	0.2525	72	698	6	5	13	8	0	-2	8	0	0	2.004130294487196	
i 1	217.48595238095237	1.5150000000000001	74	698	4	24	5	2	0	-1	2	0	0	3.0358440348444966	
i 1	217.48916326530613	0.2525	71	698	5	3	16	8	0	-2	8	0	0	3.0	
i 1	217.49157142857143	1.5150000000000001	71	200	5	1	5	2	0	-2	2	0	0	2.0358440348444966	
i 1	217.5044149659864	3.7875	75	200	7	5	4	2	0	-2	2	0	0	2.004130294487196	
i 1	217.509231292517	0.2525	74	200	6	9	14	8	0	-1	8	0	0	2.0	
i 1	217.51725850340137	3.7875	72	1084	6	5	10	2	0	1	2	0	0	2.004130294487196	
i 1	217.7656530612245	0.2525	71	698	3	4	15	2	0	-1	2	0	0	3.0	
i 1	217.9843469387755	1.2625	74	1084	5	2	3	2	0	-2	2	0	0	3.0	
i 1	217.98514965986394	1.2625	71	698	5	3	4	8	0	-1	8	0	0	3.0	
i 1	217.990768707483	0.2525	72	698	6	5	8	2	0	1	2	0	0	2.004130294487196	
i 1	218.23033333333333	2.525	74	698	6	1	6	8	0	-2	8	0	0	2.0358440348444966	
i 1	218.23514965986394	2.525	74	698	4	24	10	8	0	-2	8	0	0	3.0358440348444966	
i 1	218.2367551020408	3.2825	71	698	1	24	7	2	0	1	2	0	0	5.0	
i 1	218.26244217687074	0.7575000000000001	74	698	1	20	2	2	0	1	2	0	0	1.0	
i 1	218.48113605442177	0.2525	71	698	4	4	4	2	0	-2	2	0	0	3.0	
i 1	218.49157142857143	0.505	74	200	2	20	13	2	0	-2	2	0	0	1.0	
i 1	218.5044149659864	0.2525	75	200	6	5	11	2	0	1	2	0	0	2.004130294487196	
i 1	218.5132448979592	1.5150000000000001	71	200	2	20	12	2	0	-2	2	0	0	1.0	
i 1	218.73916326530613	0.2525	75	698	6	5	6	2	0	1	2	0	0	2.004130294487196	
i 1	218.74478231292517	1.7675	71	698	3	4	10	2	0	-1	2	0	0	3.0	
i 1	218.76645578231293	2.02	71	698	5	3	13	8	0	-2	8	0	0	3.0	
i 1	218.9883605442177	0.2525	74	1084	2	20	6	2	0	1	2	0	0	1.0	
i 1	219.009231292517	0.2525	71	1084	4	1	1	8	0	-1	8	0	0	2.0358440348444966	
i 1	219.01886394557823	0.2525	74	698	2	20	12	2	0	1	2	0	0	1.0	
i 1	219.01966666666667	0.2525	74	1084	2	20	13	2	0	-2	2	0	0	1.0	
i 1	219.23033333333333	0.2525	74	1084	5	1	3	2	0	-2	2	0	0	2.0358440348444966	
i 1	219.23033333333333	0.7575000000000001	71	200	2	20	4	2	0	1	2	0	0	1.0	
i 1	219.24397959183673	2.2725	74	698	1	20	3	2	0	1	2	0	0	1.0	
i 1	219.25280952380953	1.2625	74	200	2	20	16	2	0	1	2	0	0	1.0	
i 1	219.25842857142857	0.2525	71	200	6	9	5	8	0	-1	8	0	0	2.0	
i 1	219.48916326530613	0.2525	71	200	7	1	6	2	0	-1	2	0	0	2.0358440348444966	
i 1	219.48916326530613	1.01	74	200	2	24	11	2	0	-2	2	0	0	5.0	
i 1	219.49638775510203	0.2525	74	1084	5	2	8	2	0	-1	2	0	0	3.0	
i 1	219.49638775510203	0.2525	74	1084	5	2	9	2	0	-2	2	0	0	3.0	
i 1	219.7431768707483	2.2725	71	200	5	1	7	2	0	-2	2	0	0	2.0358440348444966	
i 1	219.7455850340136	1.5150000000000001	71	698	4	4	13	2	0	-2	2	0	0	3.0	
i 1	219.7479931972789	1.5150000000000001	74	200	6	9	6	8	0	-1	8	0	0	2.0	
i 1	219.75762585034013	2.2725	74	698	4	24	3	2	0	-1	2	0	0	3.0358440348444966	
i 1	219.7656530612245	0.2525	75	200	6	5	15	2	0	1	2	0	0	2.004130294487196	
i 1	220.00040136054423	1.7675	75	698	6	5	14	2	0	1	2	0	0	2.004130294487196	
i 1	220.25040136054423	1.2625	72	1084	6	5	1	2	0	-2	2	0	0	2.004130294487196	
i 1	220.48514965986394	0.2525	71	200	6	9	3	8	0	-1	8	0	0	2.0	
i 1	220.49719047619047	0.2525	71	200	2	20	12	2	0	1	2	0	0	1.0	
i 1	220.50361224489797	2.525	72	698	6	5	9	2	0	1	2	0	0	2.004130294487196	
i 1	220.5156530612245	2.525	75	200	6	5	6	2	0	1	2	0	0	2.004130294487196	
i 1	220.73274149659863	4.545	71	698	5	3	3	8	0	-1	8	0	0	3.0	
i 1	220.74879591836734	2.2725	74	200	2	20	7	2	0	1	2	0	0	1.0	
i 1	220.7520068027211	2.02	71	698	1	20	1	2	0	-2	2	0	0	1.0	
i 1	220.7544149659864	2.525	74	200	2	24	16	2	0	-2	2	0	0	5.0	
i 1	220.7632448979592	2.02	71	698	1	24	2	2	0	-2	2	0	0	5.0	
i 1	220.7680612244898	0.2525	74	1084	5	1	12	2	0	-2	2	0	0	2.0358440348444966	
i 1	220.7680612244898	3.2825	74	1084	5	2	7	2	0	-2	2	0	0	3.0	
i 1	220.99397959183673	0.2525	74	698	4	24	4	8	0	-2	8	0	0	3.0358440348444966	
i 1	221.2367551020408	0.2525	71	200	6	9	3	8	0	-1	8	0	0	2.0	
i 1	221.24719047619047	0.2525	74	1084	5	1	10	2	0	-2	2	0	0	2.0358440348444966	
i 1	221.24719047619047	0.2525	71	698	5	3	2	8	0	-2	8	0	0	3.0	
i 1	221.4883605442177	1.2625	71	1084	4	1	12	8	0	-1	8	0	0	2.0358440348444966	
i 1	221.4883605442177	0.2525	72	1084	6	5	13	2	0	1	2	0	0	2.004130294487196	
i 1	221.4955850340136	0.2525	74	200	6	9	2	8	0	-1	8	0	0	2.0	
i 1	221.50040136054423	1.2625	71	200	7	1	9	2	0	-1	2	0	0	2.0358440348444966	
i 1	221.74237414965987	1.01	71	698	3	4	14	2	0	-1	2	0	0	3.0	
i 1	221.7479931972789	1.01	75	200	7	5	10	2	0	-2	2	0	0	2.004130294487196	
i 1	221.76083673469387	1.7675	71	698	5	3	2	8	0	-2	8	0	0	3.0	
i 1	221.7656530612245	0.2525	72	1084	6	5	2	2	0	-2	2	0	0	2.004130294487196	
i 1	221.98274149659863	0.2525	74	698	4	24	12	8	0	-2	8	0	0	3.0358440348444966	
i 1	222.01003401360543	2.02	72	1084	6	5	12	2	0	1	2	0	0	2.004130294487196	
i 1	222.24879591836734	0.2525	74	698	4	24	8	2	0	-1	2	0	0	3.0358440348444966	
i 1	222.24959863945577	0.7575000000000001	74	698	1	20	10	2	0	1	2	0	0	1.0	
i 1	222.2520068027211	0.2525	74	1084	5	1	5	2	0	-2	2	0	0	2.0358440348444966	
i 1	222.26083673469387	3.0300000000000002	71	698	1	24	11	2	0	1	2	0	0	5.0	
i 1	222.4819387755102	5.05	71	200	2	20	2	2	0	-2	2	0	0	1.0	
i 1	222.49397959183673	0.2525	71	698	6	1	11	8	0	-1	8	0	0	2.0358440348444966	
i 1	222.49397959183673	0.505	71	200	2	20	11	2	0	1	2	0	0	1.0	
i 1	222.7319387755102	2.2725	74	698	4	24	13	8	0	-2	8	0	0	3.0358440348444966	
i 1	222.73354421768707	1.2625	71	200	5	1	10	2	0	-1	2	0	0	2.0358440348444966	
i 1	222.73354421768707	0.505	71	698	4	4	7	2	0	-1	2	0	0	3.0	
i 1	222.7383605442177	13.635	63	1084	3	14	16	1	0	1	1	0	0	3.2320177156753847	
i 1	222.75602040816327	1.2625	75	200	6	5	16	2	0	-2	2	0	0	2.004130294487196	
i 1	222.76404761904763	2.2725	74	698	5	1	5	8	0	-2	8	0	0	2.0358440348444966	
i 1	222.7656530612245	1.01	71	1084	5	1	1	8	0	-1	8	0	0	2.0358440348444966	
i 1	223.00280952380953	0.2525	74	698	2	20	13	2	0	1	2	0	0	1.0	
i 1	223.00521768707483	1.01	72	698	6	5	9	8	0	-2	8	0	0	2.004130294487196	
i 1	223.00602040816327	0.2525	71	1084	2	20	13	2	0	1	2	0	0	1.0	
i 1	223.0068231292517	1.2625	75	698	6	5	2	2	0	-2	2	0	0	2.004130294487196	
i 1	223.01485034013606	0.2525	74	1084	2	20	11	2	0	-2	2	0	0	1.0	
i 1	223.23755782312926	2.525	72	1084	6	5	14	2	0	-2	2	0	0	2.004130294487196	
i 1	223.2431768707483	1.5150000000000001	74	698	1	20	16	2	0	1	2	0	0	1.0	
i 1	223.24959863945577	1.5150000000000001	74	200	2	20	12	2	0	1	2	0	0	1.0	
i 1	223.2632448979592	2.2725	75	698	6	5	3	2	0	1	2	0	0	2.004130294487196	
i 1	223.26886394557823	1.01	74	200	2	20	13	2	0	1	2	0	0	1.0	
i 1	223.4843469387755	1.2625	74	200	2	24	13	2	0	-2	2	0	0	5.0	
i 1	223.49237414965987	1.5150000000000001	74	1084	4	2	13	2	0	-1	2	0	0	3.0	
i 1	223.50040136054423	1.5150000000000001	71	200	6	9	5	8	0	-1	8	0	0	2.0	
i 1	223.76083673469387	0.2525	74	1084	4	1	9	2	0	-2	2	0	0	2.0358440348444966	
i 1	223.98916326530613	0.2525	71	200	7	1	9	2	0	-2	2	0	0	2.0358440348444966	
i 1	223.99879591836734	0.2525	74	200	5	9	3	8	0	-1	8	0	0	2.0	
i 1	224.01485034013606	2.525	71	1084	5	1	9	8	0	-1	8	0	0	2.0358440348444966	
i 1	224.24959863945577	3.0300000000000002	71	698	5	3	14	8	0	-2	8	0	0	3.0	
i 1	224.25040136054423	0.2525	72	698	6	5	10	2	0	1	2	0	0	2.004130294487196	
i 1	224.25361224489797	1.01	74	1084	5	2	11	2	0	-2	2	0	0	3.0	
i 1	224.259231292517	3.0300000000000002	71	698	4	4	6	2	0	-1	2	0	0	3.0	
i 1	224.2656530612245	2.02	71	200	5	1	6	2	0	-1	2	0	0	2.0358440348444966	
i 1	224.26645578231293	6.0600000000000005	71	698	1	20	14	2	0	-2	2	0	0	1.0	
i 1	224.26725850340137	0.505	75	200	6	5	1	2	0	1	2	0	0	2.004130294487196	
i 1	224.48755782312926	0.2525	74	200	2	20	11	2	0	1	2	0	0	1.0	
i 1	224.50361224489797	0.2525	71	698	1	24	3	2	0	-2	2	0	0	5.0	
i 1	224.51244217687074	4.2925	72	1084	6	5	11	2	0	1	2	0	0	2.004130294487196	
i 1	224.73033333333333	4.04	75	200	6	5	10	2	0	-2	2	0	0	2.004130294487196	
i 1	224.7431768707483	0.2525	74	1084	2	20	3	2	0	-2	2	0	0	1.0	
i 1	224.7431768707483	0.2525	71	698	2	24	6	2	0	-2	2	0	0	5.0	
i 1	224.76083673469387	0.2525	71	1084	2	20	4	2	0	1	2	0	0	1.0	
i 1	224.76886394557823	0.2525	74	698	2	20	4	2	0	1	2	0	0	1.0	
i 1	224.98916326530613	1.01	74	698	1	20	11	2	0	1	2	0	0	1.0	
i 1	224.99157142857143	0.2525	74	1084	4	1	1	2	0	-2	2	0	0	2.0358440348444966	
i 1	224.9955850340136	1.01	71	698	1	24	3	2	0	-2	2	0	0	5.0	
i 1	225.0020068027211	0.505	71	200	2	20	3	2	0	-2	2	0	0	1.0	
i 1	225.01003401360543	1.01	71	200	2	20	7	2	0	1	2	0	0	1.0	
i 1	225.01485034013606	0.505	71	698	6	1	4	8	0	-1	8	0	0	2.0358440348444966	
i 1	225.25120408163266	2.2725	71	200	7	1	14	2	0	-2	2	0	0	2.0358440348444966	
i 1	225.26003401360543	0.2525	71	698	4	4	3	2	0	-2	2	0	0	3.0	
i 1	225.26485034013606	0.2525	71	200	6	9	9	8	0	-1	8	0	0	2.0	
i 1	225.48354421768707	0.2525	72	698	6	5	16	8	0	-2	8	0	0	2.004130294487196	
i 1	225.48755782312926	8.08	71	698	1	24	8	2	0	1	2	0	0	5.0	
i 1	225.49879591836734	2.02	74	698	4	24	14	2	0	-1	2	0	0	3.0358440348444966	
i 1	225.50762585034013	0.2525	74	1084	4	2	13	2	0	-1	2	0	0	3.0	
i 1	225.51083673469387	0.2525	74	1084	5	2	5	2	0	-2	2	0	0	3.0	
i 1	225.7520068027211	0.2525	75	200	6	5	8	2	0	1	2	0	0	2.004130294487196	
i 1	225.75602040816327	0.505	71	698	5	3	10	8	0	-1	8	0	0	3.0	
i 1	225.7632448979592	0.2525	75	698	6	5	12	2	0	-2	2	0	0	2.004130294487196	
i 1	225.99237414965987	0.2525	71	1084	2	20	16	2	0	1	2	0	0	1.0	
i 1	225.99237414965987	0.2525	71	698	2	24	5	2	0	-2	2	0	0	5.0	
i 1	225.9931768707483	0.2525	74	698	2	20	10	2	0	1	2	0	0	1.0	
i 1	225.9955850340136	0.505	72	698	6	5	16	8	0	-2	8	0	0	2.004130294487196	
i 1	225.9979931972789	0.2525	72	698	6	5	11	2	0	1	2	0	0	2.004130294487196	
i 1	225.99959863945577	2.2725	71	698	4	4	2	2	0	-2	2	0	0	3.0	
i 1	226.23033333333333	0.505	75	698	6	5	8	2	0	-2	2	0	0	2.004130294487196	
i 1	226.23595238095237	3.535	71	698	1	24	6	2	0	-2	2	0	0	5.0	
i 1	226.24638775510203	1.2625	71	200	2	20	11	2	0	1	2	0	0	1.0	
i 1	226.24879591836734	2.02	74	200	5	9	7	8	0	-1	8	0	0	2.0	
i 1	226.26485034013606	3.2825	74	698	5	1	7	8	0	-2	8	0	0	2.0358440348444966	
i 1	226.26886394557823	3.535	74	698	1	20	2	2	0	1	2	0	0	1.0	
i 1	226.49879591836734	1.5150000000000001	74	200	2	24	14	2	0	-2	2	0	0	5.0	
i 1	226.5116394557823	1.5150000000000001	74	200	2	20	11	2	0	1	2	0	0	1.0	
i 1	226.51404761904763	0.2525	72	1084	6	5	8	2	0	-2	2	0	0	2.004130294487196	
i 1	226.5156530612245	4.04	74	698	4	24	10	8	0	-2	8	0	0	3.0358440348444966	
i 1	226.740768707483	0.2525	72	698	6	5	12	8	0	-2	8	0	0	2.004130294487196	
i 1	226.75280952380953	0.505	72	698	6	5	7	2	0	1	2	0	0	2.004130294487196	
i 1	226.99157142857143	0.505	75	698	6	5	9	2	0	1	2	0	0	2.004130294487196	
i 1	227.23274149659863	4.7975	71	698	5	3	6	8	0	-1	8	0	0	3.0	
i 1	227.24157142857143	0.2525	75	698	6	5	8	2	0	-2	2	0	0	2.004130294487196	
i 1	227.26725850340137	2.2725	74	1084	5	2	9	2	0	-2	2	0	0	3.0	
i 1	227.4819387755102	2.2725	72	1084	6	5	6	2	0	-2	2	0	0	2.004130294487196	
i 1	227.50602040816327	0.505	71	698	6	1	10	8	0	-1	8	0	0	2.0358440348444966	
i 1	227.5180612244898	0.2525	71	200	5	1	14	2	0	-1	2	0	0	2.0358440348444966	
i 1	227.5180612244898	0.2525	72	698	6	5	9	2	0	1	2	0	0	2.004130294487196	
i 1	227.7479931972789	1.7675	75	698	6	5	2	2	0	1	2	0	0	2.004130294487196	
i 1	227.75280952380953	0.2525	71	1084	5	1	12	8	0	-1	8	0	0	2.0358440348444966	
i 1	227.98755782312926	0.505	74	1084	4	1	16	2	0	-2	2	0	0	2.0358440348444966	
i 1	227.98755782312926	1.7675	71	698	5	3	12	8	0	-2	8	0	0	3.0	
i 1	227.99397959183673	1.7675	71	698	4	4	5	2	0	-1	2	0	0	3.0	
i 1	228.4819387755102	0.2525	71	698	6	1	10	8	0	-1	8	0	0	2.0358440348444966	
i 1	228.73755782312926	0.505	71	1084	5	1	6	8	0	-1	8	0	0	2.0358440348444966	
i 1	228.76083673469387	1.2625	75	200	6	5	7	2	0	1	2	0	0	2.004130294487196	
i 1	228.76966666666667	1.7675	72	698	6	5	6	2	0	1	2	0	0	2.004130294487196	
i 1	228.98916326530613	0.7575000000000001	71	200	2	20	11	2	0	1	2	0	0	1.0	
i 1	228.98996598639457	2.525	75	200	6	5	7	2	0	-2	2	0	0	2.004130294487196	
i 1	229.00602040816327	2.525	72	1084	6	5	8	2	0	1	2	0	0	2.004130294487196	
i 1	229.00762585034013	0.505	71	200	6	9	14	8	0	-1	8	0	0	2.0	
i 1	229.00842857142857	2.525	71	200	2	20	7	2	0	-2	2	0	0	1.0	
i 1	229.01003401360543	2.02	74	1084	4	2	9	2	0	-1	2	0	0	3.0	
i 1	229.23354421768707	0.2525	74	698	4	24	2	2	0	-1	2	0	0	3.0358440348444966	
i 1	229.26003401360543	2.525	71	200	7	1	10	2	0	-2	2	0	0	2.0358440348444966	
i 1	229.48755782312926	1.5150000000000001	71	200	5	9	8	8	0	-1	8	0	0	2.0	
i 1	229.49237414965987	2.525	74	1084	4	2	16	2	0	-2	2	0	0	3.0	
i 1	229.4955850340136	0.2525	75	698	5	5	2	2	0	1	2	0	0	2.004130294487196	
i 1	229.49719047619047	1.01	74	698	4	1	7	8	0	-2	8	0	0	2.0358440348444966	
i 1	229.5020068027211	2.2725	74	698	4	24	2	2	0	-1	2	0	0	3.0358440348444966	
i 1	229.509231292517	20.4525	63	1084	5	14	5	1	0	1	1	0	0	3.2320177156753847	
i 1	229.51966666666667	13.635	63	698	3	13	9	16	0	1	16	0	0	0.9817685575960969	
i 1	229.73755782312926	0.505	71	698	2	24	8	2	0	-2	2	0	0	5.0	
i 1	229.759231292517	0.505	71	1084	2	20	16	2	0	1	2	0	0	1.0	
i 1	229.76886394557823	0.505	74	698	2	20	8	2	0	1	2	0	0	1.0	
i 1	230.01485034013606	0.2525	75	698	6	5	5	2	0	-2	2	0	0	2.004130294487196	
i 1	230.23755782312926	0.2525	72	1084	6	5	3	2	0	-2	2	0	0	2.004130294487196	
i 1	230.24719047619047	1.2625	71	200	2	20	3	2	0	1	2	0	0	1.0	
i 1	230.26886394557823	2.7775	74	698	1	20	9	2	0	1	2	0	0	1.0	
i 1	230.48033333333333	2.2725	72	698	6	5	7	8	0	-2	8	0	0	2.004130294487196	
i 1	230.48274149659863	2.525	71	698	1	24	16	2	0	-2	2	0	0	5.0	
i 1	230.48354421768707	0.2525	74	1084	5	1	13	2	0	-2	2	0	0	2.0358440348444966	
i 1	230.48996598639457	1.7675	71	200	2	20	5	8	0	-2	8	0	0	1.0	
i 1	230.50040136054423	3.2825	71	698	1	20	3	2	0	-2	2	0	0	1.0	
i 1	230.50280952380953	0.2525	71	698	4	1	8	8	0	-1	8	0	0	2.0358440348444966	
i 1	230.50602040816327	1.7675	74	200	2	24	4	2	0	-2	2	0	0	5.0	
i 1	230.51966666666667	2.2725	75	698	6	5	16	2	0	-2	2	0	0	2.004130294487196	
i 1	230.73916326530613	5.05	71	200	7	1	1	2	0	-1	2	0	0	2.0358440348444966	
i 1	230.74638775510203	5.05	71	1084	5	1	10	8	0	-1	8	0	0	2.0358440348444966	
i 1	231.0116394557823	4.7975	71	698	4	4	6	2	0	-1	2	0	0	3.0	
i 1	231.01645578231293	4.7975	71	698	5	3	13	8	0	-2	8	0	0	3.0	
i 1	231.49237414965987	2.525	74	698	4	1	16	8	0	-2	8	0	0	2.0358440348444966	
i 1	231.49237414965987	1.5150000000000001	72	1084	6	5	9	2	0	-2	2	0	0	2.004130294487196	
i 1	231.49959863945577	0.2525	75	200	6	5	1	2	0	1	2	0	0	2.004130294487196	
i 1	231.50361224489797	1.7675	74	698	4	24	1	8	0	-2	8	0	0	3.0358440348444966	
i 1	231.7343469387755	1.2625	75	698	5	5	10	2	0	1	2	0	0	2.004130294487196	
i 1	231.9819387755102	0.505	71	200	5	9	9	8	0	-1	8	0	0	2.0	
i 1	231.9931768707483	4.04	72	1084	6	5	15	2	0	1	2	0	0	2.004130294487196	
i 1	231.99638775510203	0.2525	74	200	5	9	9	8	0	-1	8	0	0	2.0	
i 1	232.0156530612245	3.7875	75	200	6	5	13	2	0	-2	2	0	0	2.004130294487196	
i 1	232.24638775510203	0.2525	74	1084	4	2	11	2	0	-1	2	0	0	3.0	
i 1	232.4883605442177	0.505	71	200	2	20	2	8	0	-2	8	0	0	1.0	
i 1	232.49879591836734	2.02	71	698	4	4	8	2	0	-2	2	0	0	3.0	
i 1	232.50602040816327	0.2525	74	1084	4	2	3	2	0	-2	2	0	0	3.0	
i 1	232.5116394557823	6.0600000000000005	71	200	2	20	1	2	0	-2	2	0	0	1.0	
i 1	232.759231292517	1.7675	74	200	5	9	9	8	0	-1	8	0	0	2.0	
i 1	232.76003401360543	2.02	74	200	2	24	5	2	0	-2	2	0	0	5.0	
i 1	232.99237414965987	0.2525	74	1084	2	20	6	2	0	-2	2	0	0	1.0	
i 1	232.9979931972789	0.2525	72	698	6	5	3	8	0	-2	8	0	0	2.004130294487196	
i 1	233.00842857142857	0.505	72	698	6	5	3	2	0	1	2	0	0	2.004130294487196	
i 1	233.01003401360543	0.2525	71	698	2	24	2	2	0	-2	2	0	0	5.0	
i 1	233.01966666666667	0.2525	74	698	2	20	3	2	0	1	2	0	0	1.0	
i 1	233.23033333333333	1.5150000000000001	71	200	2	20	16	8	0	-2	8	0	0	1.0	
i 1	233.24719047619047	1.7675	74	698	1	20	1	2	0	1	2	0	0	1.0	
i 1	233.2632448979592	0.2525	71	698	1	24	9	2	0	-2	2	0	0	5.0	
i 1	233.26404761904763	0.2525	75	200	6	5	10	2	0	1	2	0	0	2.004130294487196	
i 1	233.26886394557823	0.2525	71	200	7	1	8	2	0	-2	2	0	0	2.0358440348444966	
i 1	233.48755782312926	0.2525	74	698	4	24	2	2	0	-1	2	0	0	3.0358440348444966	
i 1	233.490768707483	5.05	74	1084	4	2	11	2	0	-2	2	0	0	3.0	
i 1	233.49237414965987	0.2525	75	698	6	5	15	2	0	-2	2	0	0	2.004130294487196	
i 1	233.51725850340137	2.7775	71	698	5	3	1	8	0	-1	8	0	0	3.0	
i 1	233.74397959183673	7.07	71	698	1	24	8	2	0	1	2	0	0	5.0	
i 1	233.74478231292517	0.2525	72	698	6	5	3	8	0	-2	8	0	0	2.004130294487196	
i 1	233.7544149659864	1.2625	74	200	2	20	12	2	0	1	2	0	0	1.0	
i 1	233.99638775510203	0.505	72	698	6	5	11	2	0	1	2	0	0	2.004130294487196	
i 1	234.00842857142857	0.2525	74	698	4	24	5	2	0	-1	2	0	0	3.0358440348444966	
i 1	234.23996598639457	0.505	74	698	4	1	13	8	0	-2	8	0	0	2.0358440348444966	
i 1	234.48354421768707	0.2525	71	698	4	1	5	8	0	-1	8	0	0	2.0358440348444966	
i 1	234.50361224489797	1.7675	71	698	1	20	4	2	0	-2	2	0	0	1.0	
i 1	234.50762585034013	2.7775	75	698	5	5	13	2	0	1	2	0	0	2.004130294487196	
i 1	234.51404761904763	0.2525	75	200	6	5	4	2	0	1	2	0	0	2.004130294487196	
i 1	234.7383605442177	2.525	72	1084	6	5	2	2	0	-2	2	0	0	2.004130294487196	
i 1	234.7455850340136	1.5150000000000001	71	200	7	1	15	2	0	-2	2	0	0	2.0358440348444966	
i 1	234.76485034013606	1.5150000000000001	74	698	4	24	13	2	0	-1	2	0	0	3.0358440348444966	
i 1	234.9955850340136	0.7575000000000001	71	1084	2	20	1	2	0	-2	2	0	0	1.0	
i 1	234.99638775510203	0.7575000000000001	74	698	2	20	11	2	0	1	2	0	0	1.0	
i 1	235.73033333333333	0.2525	74	1084	5	1	1	2	0	-2	2	0	0	2.0358440348444966	
i 1	235.73033333333333	0.7575000000000001	71	200	2	20	7	2	0	1	2	0	0	1.0	
i 1	235.73595238095237	2.02	71	200	5	9	16	8	0	-1	8	0	0	2.0	
i 1	235.759231292517	0.2525	74	698	4	1	7	8	0	-2	8	0	0	2.0358440348444966	
i 1	235.7616394557823	0.7575000000000001	74	698	1	20	15	2	0	1	2	0	0	1.0	
i 1	235.76645578231293	0.2525	72	698	6	5	3	8	0	-2	8	0	0	2.004130294487196	
i 1	235.76886394557823	2.02	74	1084	4	2	2	2	0	-1	2	0	0	3.0	
i 1	235.9867551020408	0.2525	74	698	4	24	5	8	0	-2	8	0	0	3.0358440348444966	
i 1	235.9979931972789	2.525	75	200	6	5	5	2	0	1	2	0	0	2.004130294487196	
i 1	235.99879591836734	0.2525	71	1084	5	1	13	8	0	-1	8	0	0	2.0358440348444966	
i 1	236.01003401360543	2.525	72	698	6	5	16	2	0	1	2	0	0	2.004130294487196	
i 1	236.2319387755102	1.01	71	200	5	1	16	2	0	-2	2	0	0	2.0358440348444966	
i 1	236.23274149659863	3.0300000000000002	74	698	4	24	8	8	0	-2	8	0	0	3.0358440348444966	
i 1	236.23354421768707	1.01	74	698	4	24	15	2	0	-1	2	0	0	3.0358440348444966	
i 1	236.24638775510203	3.0300000000000002	74	698	5	1	8	8	0	-2	8	0	0	2.0358440348444966	
i 1	236.2479931972789	20.4525	63	1084	5	14	13	1	0	1	1	0	0	3.2320177156753847	
i 1	236.25280952380953	13.635	61	698	4	7	9	16	0	2	16	0	0	2.481934662982289	
i 1	236.2656530612245	2.2725	71	698	4	3	9	8	0	-1	8	0	0	3.0	
i 1	236.50280952380953	0.2525	71	1084	2	20	10	2	0	1	2	0	0	1.0	
i 1	236.5044149659864	0.2525	74	698	2	20	16	2	0	1	2	0	0	1.0	
i 1	236.759231292517	0.7575000000000001	74	698	1	20	2	2	0	1	2	0	0	1.0	
i 1	236.76725850340137	0.7575000000000001	71	200	2	20	5	2	0	1	2	0	0	1.0	
i 1	237.01725850340137	3.2825	71	698	1	20	5	2	0	-2	2	0	0	1.0	
i 1	237.2319387755102	1.5150000000000001	75	200	6	5	8	2	0	-2	2	0	0	2.004130294487196	
i 1	237.23996598639457	0.2525	74	1084	5	1	14	2	0	-2	2	0	0	2.0358440348444966	
i 1	237.24879591836734	0.2525	75	698	5	5	8	2	0	-2	2	0	0	2.004130294487196	
i 1	237.26645578231293	0.2525	71	1084	5	1	8	8	0	-1	8	0	0	2.0358440348444966	
i 1	237.48113605442177	1.7675	72	1084	6	5	16	2	0	1	2	0	0	2.004130294487196	
i 1	237.49237414965987	0.505	74	698	4	24	7	2	0	-1	2	0	0	3.0358440348444966	
i 1	237.49237414965987	2.02	71	698	4	3	6	8	0	-2	8	0	0	3.0	
i 1	237.4979931972789	0.2525	74	1084	2	20	14	2	0	1	2	0	0	1.0	
i 1	237.49879591836734	2.02	71	698	4	4	8	2	0	-1	2	0	0	3.0	
i 1	237.5020068027211	0.2525	74	698	2	20	11	2	0	1	2	0	0	1.0	
i 1	237.5156530612245	0.2525	71	200	7	1	13	2	0	-1	2	0	0	2.0358440348444966	
i 1	237.74397959183673	0.2525	74	698	1	20	8	2	0	1	2	0	0	1.0	
i 1	237.74719047619047	0.505	74	1084	5	1	7	2	0	-2	2	0	0	2.0358440348444966	
i 1	237.75280952380953	0.2525	71	200	2	20	13	2	0	1	2	0	0	1.0	
i 1	237.75361224489797	2.525	72	698	6	5	13	8	0	-2	8	0	0	2.004130294487196	
i 1	237.75602040816327	2.525	75	698	5	5	6	2	0	-2	2	0	0	2.004130294487196	
i 1	237.9931768707483	0.2525	71	1084	2	20	4	2	0	1	2	0	0	1.0	
i 1	237.9955850340136	0.2525	71	1084	5	1	7	8	0	-1	8	0	0	2.0358440348444966	
i 1	238.00120408163266	0.2525	74	698	2	20	13	2	0	1	2	0	0	1.0	
i 1	238.23755782312926	1.5150000000000001	71	200	2	20	11	2	0	1	2	0	0	1.0	
i 1	238.24157142857143	1.01	74	698	1	20	10	2	0	1	2	0	0	1.0	
i 1	238.24638775510203	1.7675	71	200	5	1	1	2	0	-2	2	0	0	2.0358440348444966	
i 1	238.24719047619047	1.7675	74	698	4	24	4	2	0	-1	2	0	0	3.0358440348444966	
i 1	238.25280952380953	3.0300000000000002	74	200	2	24	1	2	0	-2	2	0	0	5.0	
i 1	238.25361224489797	1.5150000000000001	71	698	1	24	4	2	0	-2	2	0	0	5.0	
i 1	238.25521768707483	0.505	74	200	2	20	3	2	0	1	2	0	0	1.0	
i 1	238.48033333333333	2.02	71	698	4	4	7	2	0	-2	2	0	0	3.0	
i 1	238.48033333333333	2.02	74	200	5	9	6	8	0	-1	8	0	0	2.0	
i 1	238.76003401360543	0.2525	72	1084	6	5	16	2	0	-2	2	0	0	2.004130294487196	
i 1	238.9843469387755	2.02	71	200	7	1	16	2	0	-1	2	0	0	2.0358440348444966	
i 1	238.99638775510203	0.2525	75	200	6	5	9	2	0	-2	2	0	0	2.004130294487196	
i 1	239.0044149659864	2.02	71	1084	5	1	8	8	0	-1	8	0	0	2.0358440348444966	
i 1	239.2319387755102	0.505	74	200	2	20	11	2	0	1	2	0	0	1.0	
i 1	239.2383605442177	1.7675	72	1084	6	5	6	2	0	-2	2	0	0	2.004130294487196	
i 1	239.24157142857143	1.7675	75	698	5	5	13	2	0	1	2	0	0	2.004130294487196	
i 1	239.4883605442177	1.7675	74	1084	4	2	7	2	0	-2	2	0	0	3.0	
i 1	239.49237414965987	3.535	71	698	4	3	16	8	0	-1	8	0	0	3.0	
i 1	239.73113605442177	0.505	74	1084	2	20	6	2	0	-2	2	0	0	1.0	
i 1	239.7367551020408	0.505	74	1084	2	20	5	2	0	-2	2	0	0	1.0	
i 1	239.73755782312926	0.505	71	698	2	24	16	2	0	-2	2	0	0	5.0	
i 1	239.74719047619047	3.7875	71	200	2	20	2	2	0	-2	2	0	0	1.0	
i 1	240.00280952380953	2.2725	74	698	5	1	4	8	0	-2	8	0	0	2.0358440348444966	
i 1	240.00361224489797	2.2725	74	698	4	24	15	8	0	-2	8	0	0	3.0358440348444966	
i 1	240.24157142857143	3.7875	72	1084	6	5	5	2	0	1	2	0	0	2.004130294487196	
i 1	240.25361224489797	3.2825	71	200	2	20	9	2	0	1	2	0	0	1.0	
i 1	240.25361224489797	0.505	71	698	1	24	7	2	0	-2	2	0	0	5.0	
i 1	240.26003401360543	3.7875	75	200	6	5	1	2	0	-2	2	0	0	2.004130294487196	
i 1	240.26083673469387	1.01	71	200	2	20	13	2	0	-2	2	0	0	1.0	
i 1	240.4867551020408	2.02	71	698	4	3	12	8	0	-2	8	0	0	3.0	
i 1	240.50762585034013	2.02	71	698	4	4	9	2	0	-1	2	0	0	3.0	
i 1	240.9883605442177	0.2525	75	698	5	5	10	2	0	-2	2	0	0	2.004130294487196	
i 1	240.98916326530613	0.505	71	698	6	1	6	8	0	-1	8	0	0	2.0358440348444966	
i 1	241.2383605442177	0.2525	74	1084	4	2	3	2	0	-1	2	0	0	3.0	
i 1	241.25120408163266	1.7675	71	200	7	1	8	2	0	-1	2	0	0	2.0358440348444966	
i 1	241.2568231292517	0.2525	72	1084	6	5	9	2	0	-2	2	0	0	2.004130294487196	
i 1	241.259231292517	0.2525	71	698	1	24	16	2	0	-2	2	0	0	5.0	
i 1	241.26485034013606	0.2525	75	698	5	5	15	2	0	1	2	0	0	2.004130294487196	
i 1	241.48274149659863	0.2525	75	698	5	5	3	2	0	-2	2	0	0	2.004130294487196	
i 1	241.49478231292517	1.5150000000000001	71	1084	5	1	12	8	0	-1	8	0	0	2.0358440348444966	
i 1	241.49959863945577	4.2925	74	200	2	24	6	2	0	-2	2	0	0	5.0	
i 1	241.5068231292517	0.7575000000000001	75	200	6	5	2	2	0	1	2	0	0	2.004130294487196	
i 1	241.50842857142857	2.7775	71	200	2	20	4	2	0	-2	2	0	0	1.0	
i 1	241.5116394557823	1.5150000000000001	74	1084	4	2	5	2	0	-2	2	0	0	3.0	
i 1	241.73113605442177	0.7575000000000001	72	698	6	5	5	8	0	-2	8	0	0	2.004130294487196	
i 1	241.98274149659863	1.5150000000000001	71	698	1	24	3	2	0	1	2	0	0	5.0	
i 1	241.9867551020408	1.5150000000000001	74	698	1	20	8	2	0	1	2	0	0	1.0	
i 1	242.23354421768707	1.7675	71	200	5	9	6	8	0	-1	8	0	0	2.0	
i 1	242.24237414965987	1.7675	74	1084	4	2	10	2	0	-1	2	0	0	3.0	
i 1	242.2431768707483	0.2525	72	698	6	5	9	2	0	1	2	0	0	2.004130294487196	
i 1	242.24397959183673	0.2525	74	1084	5	1	16	2	0	-2	2	0	0	2.0358440348444966	
i 1	242.25361224489797	0.2525	71	200	5	1	13	2	0	-2	2	0	0	2.0358440348444966	
i 1	242.48514965986394	0.505	74	698	4	24	5	8	0	-2	8	0	0	3.0358440348444966	
i 1	242.48996598639457	0.2525	74	698	5	1	11	8	0	-2	8	0	0	2.0358440348444966	
i 1	242.50120408163266	0.2525	75	698	5	5	15	2	0	-2	2	0	0	2.004130294487196	
i 1	242.73113605442177	1.5150000000000001	71	698	1	24	16	2	0	-2	2	0	0	5.0	
i 1	242.7383605442177	0.2525	72	1084	6	5	11	2	0	-2	2	0	0	2.004130294487196	
i 1	242.76244217687074	2.02	71	698	1	20	16	2	0	-2	2	0	0	1.0	
i 1	242.9843469387755	0.2525	75	200	6	5	6	2	0	1	2	0	0	2.004130294487196	
i 1	242.9931768707483	0.2525	71	698	4	3	11	8	0	-2	8	0	0	3.0	
i 1	242.99478231292517	17.675	63	698	5	13	16	16	0	1	16	0	0	0.9817685575960969	
i 1	242.9955850340136	0.2525	74	698	4	24	5	2	0	-1	2	0	0	3.0358440348444966	
i 1	243.009231292517	2.2725	71	1084	6	1	14	8	0	-1	8	0	0	2.0358440348444966	
i 1	243.01003401360543	1.2625	75	698	5	5	1	2	0	1	2	0	0	2.004130294487196	
i 1	243.0116394557823	0.2525	74	200	5	9	1	8	0	-1	8	0	0	2.0	
i 1	243.01645578231293	2.2725	71	200	5	1	8	2	0	-1	2	0	0	2.0358440348444966	
i 1	243.23033333333333	1.01	72	1084	6	5	5	2	0	-2	2	0	0	2.004130294487196	
i 1	243.24397959183673	0.7575000000000001	74	1084	4	2	9	2	0	-2	2	0	0	3.0	
i 1	243.24959863945577	0.505	71	698	6	1	8	8	0	-1	8	0	0	2.0358440348444966	
i 1	243.24959863945577	0.2525	74	698	4	24	12	8	0	-2	8	0	0	3.0358440348444966	
i 1	243.2632448979592	0.7575000000000001	71	698	4	3	8	8	0	-1	8	0	0	3.0	
i 1	243.48996598639457	0.505	71	200	4	1	6	2	0	-2	2	0	0	2.0358440348444966	
i 1	243.50120408163266	2.525	71	698	4	3	9	8	0	-2	8	0	0	3.0	
i 1	243.50842857142857	3.0300000000000002	71	698	4	4	1	2	0	-1	2	0	0	3.0	
i 1	243.75280952380953	0.2525	74	1084	5	1	1	2	0	-2	2	0	0	2.0358440348444966	
i 1	243.75602040816327	2.02	75	200	6	5	2	2	0	1	2	0	0	2.004130294487196	
i 1	243.76485034013606	2.02	72	698	6	5	2	2	0	1	2	0	0	2.004130294487196	
i 1	243.98354421768707	0.2525	71	200	2	20	14	2	0	1	2	0	0	1.0	
i 1	243.99959863945577	3.0300000000000002	71	698	1	24	15	2	0	1	2	0	0	5.0	
i 1	244.0156530612245	0.2525	74	200	5	9	12	8	0	-1	8	0	0	2.0	
i 1	244.01645578231293	0.2525	74	698	4	24	1	8	0	-2	8	0	0	3.0358440348444966	
i 1	244.23033333333333	0.2525	74	698	2	20	7	2	0	1	2	0	0	1.0	
i 1	244.2319387755102	0.2525	74	1084	4	2	8	2	0	-1	2	0	0	3.0	
i 1	244.23595238095237	1.5150000000000001	71	200	4	1	1	2	0	-2	2	0	0	2.0358440348444966	
i 1	244.23916326530613	0.2525	71	698	2	24	1	2	0	-2	2	0	0	5.0	
i 1	244.240768707483	0.2525	75	200	6	5	11	2	0	-2	2	0	0	2.004130294487196	
i 1	244.24237414965987	0.2525	74	1084	2	20	9	2	0	1	2	0	0	1.0	
i 1	244.24719047619047	0.2525	71	698	4	4	9	2	0	-2	2	0	0	3.0	
i 1	244.26003401360543	0.2525	71	698	6	1	16	8	0	-1	8	0	0	2.0358440348444966	
i 1	244.26404761904763	0.2525	74	1084	2	20	8	2	0	-2	2	0	0	1.0	
i 1	244.4867551020408	0.2525	71	698	1	24	14	2	0	-2	2	0	0	5.0	
i 1	244.48755782312926	1.2625	74	200	2	20	14	8	0	1	8	0	0	1.0	
i 1	244.4955850340136	0.505	71	698	4	3	16	8	0	-1	8	0	0	3.0	
i 1	244.50762585034013	1.2625	74	698	1	20	7	2	0	1	2	0	0	1.0	
i 1	244.5116394557823	1.2625	74	698	4	24	12	2	0	-1	2	0	0	3.0358440348444966	
i 1	244.51645578231293	0.2525	72	698	6	5	9	8	0	-2	8	0	0	2.004130294487196	
i 1	244.7479931972789	2.2725	75	200	6	5	5	2	0	-2	2	0	0	2.004130294487196	
i 1	244.75280952380953	0.2525	72	1084	6	5	10	2	0	-2	2	0	0	2.004130294487196	
i 1	244.76083673469387	0.7575000000000001	71	200	5	9	16	8	0	-1	8	0	0	2.0	
i 1	244.9867551020408	2.525	74	698	5	1	6	8	0	-2	8	0	0	2.0358440348444966	
i 1	244.99157142857143	2.525	74	698	4	24	2	8	0	-2	8	0	0	3.0358440348444966	
i 1	245.00361224489797	2.525	71	200	2	20	2	2	0	-2	2	0	0	1.0	
i 1	245.00602040816327	0.7575000000000001	74	200	2	20	5	2	0	1	2	0	0	1.0	
i 1	245.01003401360543	2.2725	72	1084	6	5	6	2	0	1	2	0	0	2.004130294487196	
i 1	245.01886394557823	0.2525	74	1084	4	2	14	2	0	-2	2	0	0	3.0	
i 1	245.24959863945577	1.2625	71	698	1	20	9	2	0	-2	2	0	0	1.0	
i 1	245.49397959183673	1.7675	74	200	5	9	4	8	0	-1	8	0	0	2.0	
i 1	245.5132448979592	1.7675	71	698	4	4	3	2	0	-2	2	0	0	3.0	
i 1	245.75521768707483	0.2525	71	1084	6	1	7	8	0	-1	8	0	0	2.0358440348444966	
i 1	245.75602040816327	0.2525	74	698	2	20	10	2	0	1	2	0	0	1.0	
i 1	245.76003401360543	0.2525	75	698	5	5	6	2	0	1	2	0	0	2.004130294487196	
i 1	245.76886394557823	0.2525	74	1084	2	20	6	8	0	-2	8	0	0	1.0	
i 1	245.98274149659863	0.2525	74	698	1	20	5	2	0	1	2	0	0	1.0	
i 1	245.99638775510203	0.2525	71	698	6	1	14	8	0	-1	8	0	0	2.0358440348444966	
i 1	246.0020068027211	1.01	75	698	5	5	12	2	0	-2	2	0	0	2.004130294487196	
i 1	246.00521768707483	0.2525	71	200	4	1	8	2	0	-2	2	0	0	2.0358440348444966	
i 1	246.0180612244898	0.2525	74	200	2	20	5	2	0	-2	2	0	0	1.0	
i 1	246.01886394557823	1.01	72	698	6	5	2	8	0	-2	8	0	0	2.004130294487196	
i 1	246.23033333333333	0.2525	74	698	2	20	1	2	0	1	2	0	0	1.0	
i 1	246.2319387755102	0.2525	74	1084	5	1	8	2	0	-2	2	0	0	2.0358440348444966	
i 1	246.23916326530613	0.2525	71	1084	2	20	14	8	0	-2	8	0	0	1.0	
i 1	246.26083673469387	2.525	74	1084	4	2	16	2	0	-2	2	0	0	3.0	
i 1	246.48755782312926	2.02	72	1084	6	5	10	2	0	-2	2	0	0	2.004130294487196	
i 1	246.49237414965987	1.01	74	200	2	20	10	2	0	-2	2	0	0	1.0	
i 1	246.49879591836734	2.2725	71	698	4	3	7	8	0	-1	8	0	0	3.0	
i 1	246.50602040816327	2.02	75	698	5	5	7	2	0	1	2	0	0	2.004130294487196	
i 1	246.5068231292517	0.2525	71	1084	6	1	12	8	0	-1	8	0	0	2.0358440348444966	
i 1	246.7544149659864	2.2725	71	200	4	1	16	2	0	-2	2	0	0	2.0358440348444966	
i 1	246.7632448979592	2.525	74	698	4	24	7	2	0	-1	2	0	0	3.0358440348444966	
i 1	246.98755782312926	2.7775	74	200	2	24	12	2	0	-2	2	0	0	5.0	
i 1	246.98916326530613	2.525	74	200	2	20	13	2	0	1	2	0	0	1.0	
i 1	247.0020068027211	1.5150000000000001	71	698	4	3	4	8	0	-2	8	0	0	3.0	
i 1	247.00280952380953	1.5150000000000001	71	698	4	4	8	2	0	-1	2	0	0	3.0	
i 1	247.24879591836734	0.2525	75	698	5	5	1	2	0	-2	2	0	0	2.004130294487196	
i 1	247.49157142857143	0.2525	71	1084	6	1	7	8	0	-1	8	0	0	2.0358440348444966	
i 1	247.50040136054423	0.2525	71	698	1	20	10	2	0	-2	2	0	0	1.0	
i 1	247.50120408163266	0.505	71	698	6	1	15	8	0	-1	8	0	0	2.0358440348444966	
i 1	247.51404761904763	4.04	75	200	6	5	3	2	0	-2	2	0	0	2.004130294487196	
i 1	247.51886394557823	0.2525	75	200	6	5	4	2	0	1	2	0	0	2.004130294487196	
i 1	247.7431768707483	0.2525	71	200	5	1	7	2	0	-1	2	0	0	2.0358440348444966	
i 1	247.7455850340136	1.7675	74	698	1	20	6	2	0	1	2	0	0	1.0	
i 1	247.74879591836734	3.7875	72	1084	6	5	16	2	0	1	2	0	0	2.004130294487196	
i 1	247.76485034013606	2.02	71	200	2	20	15	2	0	-2	2	0	0	1.0	
i 1	247.76725850340137	2.02	71	698	1	24	14	2	0	1	2	0	0	5.0	
i 1	247.76886394557823	1.7675	74	200	2	20	4	2	0	-2	2	0	0	1.0	
i 1	248.0068231292517	5.3025	71	1084	6	1	14	8	0	-1	8	0	0	2.0358440348444966	
i 1	248.00762585034013	2.2725	71	200	5	9	11	8	0	-1	8	0	0	2.0	
i 1	248.01404761904763	1.7675	74	1084	4	2	12	2	0	-1	2	0	0	3.0	
i 1	248.49638775510203	1.2625	71	200	5	1	7	2	0	-1	2	0	0	2.0358440348444966	
i 1	248.51725850340137	0.2525	72	698	6	5	16	8	0	-2	8	0	0	2.004130294487196	
i 1	248.75762585034013	0.2525	71	698	4	4	14	2	0	-1	2	0	0	3.0	
i 1	248.76966666666667	0.2525	75	698	5	5	3	2	0	-2	2	0	0	2.004130294487196	
i 1	248.99397959183673	1.7675	74	1084	4	2	1	2	0	-2	2	0	0	3.0	
i 1	248.99879591836734	1.7675	71	698	4	3	4	8	0	-1	8	0	0	3.0	
i 1	249.24879591836734	0.505	71	698	1	20	12	2	0	-2	2	0	0	1.0	
i 1	249.25280952380953	0.2525	74	698	4	24	4	8	0	-2	8	0	0	3.0358440348444966	
i 1	249.48113605442177	0.2525	74	698	2	20	14	2	0	1	2	0	0	1.0	
i 1	249.4979931972789	0.2525	75	200	6	5	14	2	0	1	2	0	0	2.004130294487196	
i 1	249.51083673469387	0.2525	71	1084	2	20	9	8	0	-2	8	0	0	1.0	
i 1	249.5116394557823	0.2525	74	1084	5	1	15	2	0	-2	2	0	0	2.0358440348444966	
i 1	249.51244217687074	0.2525	74	1084	2	20	7	2	0	1	2	0	0	1.0	
i 1	249.73274149659863	2.2725	74	698	5	1	8	8	0	-2	8	0	0	2.0358440348444966	
i 1	249.759231292517	1.01	71	200	4	1	3	2	0	-1	2	0	0	2.0358440348444966	
i 1	249.76244217687074	9.3425	63	1084	4	14	10	1	0	1	1	0	0	3.2320177156753847	
i 1	249.76485034013606	2.2725	74	698	4	24	12	8	0	-2	8	0	0	3.0358440348444966	
i 1	249.76725850340137	0.505	71	698	1	24	7	2	0	1	2	0	0	4.0	
i 1	249.76886394557823	0.2525	72	1084	6	5	9	2	0	-2	2	0	0	2.004130294487196	
i 1	249.76966666666667	10.8575	61	698	5	7	6	16	0	2	16	0	0	2.481934662982289	
i 1	249.98755782312926	2.525	71	698	4	4	7	2	0	-1	2	0	0	3.0	
i 1	250.25040136054423	2.2725	71	698	4	3	1	8	0	-2	8	0	0	3.0	
i 1	250.51244217687074	1.2625	74	200	2	24	2	2	0	-2	2	0	0	4.0	
i 1	250.759231292517	0.505	71	698	4	4	9	2	0	-2	2	0	0	3.0	
i 1	250.7680612244898	0.2525	75	698	5	5	6	2	0	-2	2	0	0	2.004130294487196	
i 1	250.76886394557823	0.2525	74	1084	6	1	8	2	0	-2	2	0	0	2.0358440348444966	
i 1	250.9883605442177	0.2525	74	200	4	9	10	8	0	-1	8	0	0	2.0	
i 1	251.0044149659864	1.5150000000000001	72	1084	6	5	6	2	0	-2	2	0	0	2.004130294487196	
i 1	251.0044149659864	1.5150000000000001	75	698	5	5	12	2	0	1	2	0	0	2.004130294487196	
i 1	251.0156530612245	2.2725	71	200	4	1	14	2	0	-1	2	0	0	2.0358440348444966	
i 1	251.24397959183673	0.2525	74	1084	4	2	7	2	0	-2	2	0	0	3.0	
i 1	251.48274149659863	0.2525	72	698	6	5	3	2	0	1	2	0	0	2.004130294487196	
i 1	251.50280952380953	4.7975	71	698	1	24	3	2	0	1	2	0	0	4.0	
i 1	251.51083673469387	0.505	74	1084	4	2	6	2	0	-1	2	0	0	3.0	
i 1	251.7431768707483	0.2525	72	698	6	5	6	8	0	-2	8	0	0	2.004130294487196	
i 1	251.9843469387755	0.2525	74	698	4	24	6	2	0	-1	2	0	0	3.0358440348444966	
i 1	251.98514965986394	0.7575000000000001	75	200	6	5	14	2	0	1	2	0	0	2.004130294487196	
i 1	252.01404761904763	0.7575000000000001	72	698	6	5	14	2	0	1	2	0	0	2.004130294487196	
i 1	252.0156530612245	1.7675	71	698	4	4	16	2	0	-2	2	0	0	3.0	
i 1	252.01966666666667	1.7675	74	200	4	9	9	8	0	-1	8	0	0	2.0	
i 1	252.24879591836734	2.02	72	1084	6	5	5	2	0	1	2	0	0	2.004130294487196	
i 1	252.26244217687074	2.02	75	200	6	5	15	2	0	-2	2	0	0	2.004130294487196	
i 1	252.2680612244898	0.2525	71	200	5	1	10	2	0	-2	2	0	0	2.0358440348444966	
i 1	252.48595238095237	0.2525	74	698	5	1	4	8	0	-2	8	0	0	2.0358440348444966	
i 1	252.48996598639457	2.2725	74	200	2	24	10	2	0	-2	2	0	0	4.0	
i 1	252.5156530612245	0.2525	74	1084	4	2	6	2	0	-1	2	0	0	3.0	
i 1	252.73755782312926	1.5150000000000001	74	698	4	24	15	2	0	-1	2	0	0	3.0358440348444966	
i 1	252.74237414965987	0.2525	72	1084	6	5	10	2	0	-2	2	0	0	2.004130294487196	
i 1	252.74397959183673	1.5150000000000001	71	200	5	1	10	2	0	-2	2	0	0	2.0358440348444966	
i 1	252.76083673469387	0.7575000000000001	71	698	4	3	13	8	0	-1	8	0	0	3.0	
i 1	252.7656530612245	0.7575000000000001	74	1084	4	2	13	2	0	-2	2	0	0	3.0	
i 1	253.00602040816327	1.5150000000000001	71	698	4	3	5	8	0	-2	8	0	0	3.0	
i 1	253.0116394557823	0.2525	75	698	5	5	11	2	0	-2	2	0	0	2.004130294487196	
i 1	253.01404761904763	1.5150000000000001	71	698	4	4	13	2	0	-1	2	0	0	3.0	
i 1	253.23595238095237	0.505	74	1084	6	1	4	2	0	-2	2	0	0	2.0358440348444966	
i 1	253.2367551020408	0.2525	75	200	6	5	3	2	0	1	2	0	0	2.004130294487196	
i 1	253.2616394557823	0.2525	75	698	5	5	15	2	0	1	2	0	0	2.004130294487196	
i 1	253.48755782312926	2.02	72	698	6	5	11	8	0	-2	8	0	0	2.004130294487196	
i 1	253.73274149659863	2.7775	74	698	4	24	11	8	0	-2	8	0	0	3.0358440348444966	
i 1	253.7343469387755	2.7775	74	698	5	1	8	8	0	-2	8	0	0	2.0358440348444966	
i 1	253.74478231292517	1.7675	75	698	5	5	8	2	0	-2	2	0	0	2.004130294487196	
i 1	253.7544149659864	1.7675	74	1084	4	2	1	2	0	-2	2	0	0	3.0	
i 1	253.75521768707483	2.02	71	698	4	3	3	8	0	-1	8	0	0	3.0	
i 1	254.24638775510203	0.2525	71	200	4	1	15	2	0	-1	2	0	0	2.0358440348444966	
i 1	254.25521768707483	0.2525	75	200	6	5	5	2	0	1	2	0	0	2.004130294487196	
i 1	254.4819387755102	0.2525	75	200	6	5	13	2	0	-2	2	0	0	2.004130294487196	
i 1	254.49478231292517	0.2525	71	200	5	9	3	8	0	-1	8	0	0	2.0	
i 1	254.51404761904763	0.7575000000000001	74	1084	6	1	10	2	0	-2	2	0	0	2.0358440348444966	
i 1	254.73595238095237	1.2625	72	1084	6	5	2	2	0	-2	2	0	0	2.004130294487196	
i 1	254.76886394557823	1.7675	74	1084	4	2	14	2	0	-1	2	0	0	3.0	
i 1	254.98514965986394	0.7575000000000001	75	698	5	5	6	2	0	1	2	0	0	2.004130294487196	
i 1	254.99719047619047	1.5150000000000001	71	200	5	9	6	8	0	-1	8	0	0	2.0	
i 1	255.2455850340136	3.2825	75	200	6	5	12	2	0	-2	2	0	0	2.004130294487196	
i 1	255.26404761904763	0.2525	71	200	4	1	13	2	0	-1	2	0	0	2.0358440348444966	
i 1	255.26886394557823	3.2825	72	1084	6	5	7	2	0	1	2	0	0	2.004130294487196	
i 1	255.5180612244898	0.2525	74	698	4	24	4	2	0	-1	2	0	0	3.0358440348444966	
i 1	255.73274149659863	0.2525	74	200	4	9	3	8	0	-1	8	0	0	2.0	
i 1	255.7520068027211	0.2525	71	200	4	1	13	2	0	-1	2	0	0	2.0358440348444966	
i 1	255.9867551020408	1.5150000000000001	74	1084	4	2	6	2	0	-2	2	0	0	3.0	
i 1	255.990768707483	0.505	75	200	6	5	10	2	0	1	2	0	0	2.004130294487196	
i 1	255.99638775510203	1.2625	71	698	4	3	10	8	0	-1	8	0	0	3.0	
i 1	256.0020068027211	0.505	74	698	4	24	9	2	0	-1	2	0	0	3.0358440348444966	
i 1	256.0156530612245	1.5150000000000001	74	200	2	24	12	2	0	-2	2	0	0	4.0	
i 1	256.48514965986396	0.2525	71	698	1	24	12	2	0	1	2	0	0	4.0	
i 1	256.49397959183676	0.2525	71	1084	6	1	11	8	0	-1	8	0	0	2.0358440348444966	
i 1	256.5020068027211	0.7575000000000001	74	698	6	1	11	8	0	-2	8	0	0	2.0358440348444966	
i 1	256.50441496598637	0.7575000000000001	74	698	4	24	12	8	0	-2	8	0	0	3.0358440348444966	
i 1	256.5068231292517	0.2525	74	200	4	9	16	8	0	-1	8	0	0	2.0	
i 1	256.51324489795917	2.525	63	1084	4	14	10	1	0	1	1	0	0	3.2320177156753847	
i 1	256.51404761904763	0.2525	75	698	5	5	12	2	0	-2	2	0	0	2.004130294487196	
i 1	256.7383605442177	1.5150000000000001	71	698	4	3	4	8	0	-2	8	0	0	3.0	
i 1	256.74237414965984	1.5150000000000001	71	698	4	4	12	2	0	-1	2	0	0	3.0	
i 1	256.7568231292517	1.7675	71	200	5	1	6	2	0	-2	2	0	0	2.0358440348444966	
i 1	256.75762585034016	1.7675	74	698	4	24	16	2	0	-1	2	0	0	3.0358440348444966	
i 1	256.7696666666667	0.2525	72	698	6	5	10	8	0	-2	8	0	0	2.004130294487196	
i 1	256.9931768707483	0.2525	75	698	5	5	7	2	0	1	2	0	0	2.004130294487196	
i 1	257.23996598639457	0.505	72	698	6	5	5	8	0	-2	8	0	0	2.004130294487196	
i 1	257.25120408163264	0.2525	74	1084	6	1	16	2	0	-2	2	0	0	2.0358440348444966	
i 1	257.25521768707483	1.7675	71	698	1	24	16	2	0	1	2	0	0	4.0	
i 1	257.4971904761905	0.2525	71	698	4	3	14	8	0	-1	8	0	0	3.0	
i 1	257.51244217687076	0.505	71	698	3	1	13	8	0	-1	8	0	0	2.0358440348444966	
i 1	257.73274149659863	1.2625	72	1084	6	5	2	2	0	-2	2	0	0	2.004130294487196	
i 1	257.74076870748297	1.5150000000000001	71	698	4	4	15	2	0	-2	2	0	0	3.0	
i 1	257.75602040816324	1.2625	74	200	4	9	7	8	0	-1	8	0	0	2.0	
i 1	257.9803333333333	1.01	71	200	5	1	12	2	0	-1	2	0	0	2.0358440348444966	
i 1	257.9931768707483	1.01	71	1084	6	1	6	8	0	-1	8	0	0	2.0358440348444966	
i 1	258.00120408163264	1.01	75	698	5	5	4	2	0	1	2	0	0	2.004130294487196	
i 1	258.2431768707483	0.2525	74	1084	4	2	1	2	0	-2	2	0	0	3.0	
i 1	258.24638775510203	0.7575000000000001	74	200	2	24	4	2	0	-2	2	0	0	4.0	
i 1	258.4803333333333	0.2525	74	1084	6	1	12	2	0	-2	2	0	0	2.0358440348444966	
i 1	258.50602040816324	1.7675	71	698	4	3	2	8	0	-2	8	0	0	3.0	
i 1	258.5068231292517	0.2525	72	698	6	5	4	2	0	1	2	0	0	2.004130294487196	
i 1	258.7303333333333	0.2525	71	200	5	1	13	2	0	-2	2	0	0	2.0358440348444966	
i 1	258.73274149659863	0.2525	71	698	4	3	13	8	0	-1	8	0	0	3.0	
i 1	258.73274149659863	0.2525	75	200	6	5	1	2	0	1	2	0	0	2.004130294487196	
i 1	258.75040136054423	0.2525	72	1084	6	5	3	2	0	1	2	0	0	2.004130294487196	
i 1	258.9835442176871	1.2625	69	382	6	5	2	1	0	-1	1	0	0	2.004130294487196	
i 1	258.98755782312924	9.8475	66	1196	5	12	14	6	0	1	6	0	0	3.764478115784986	
i 1	258.99157142857143	0.2525	74	382	4	9	9	17	0	1	17	0	0	2.0	
i 1	258.99638775510203	1.01	76	1196	1	24	10	17	0	2	17	0	0	4.0	
i 1	258.9971904761905	9.8475	66	1196	5	14	11	6	0	1	6	0	0	3.2320177156753847	
i 1	258.9979931972789	0.2525	72	1196	6	5	13	0	0	-1	0	0	0	2.004130294487196	
i 1	259.00040136054423	4.2925	66	382	4	16	15	6	0	1	6	0	0	3.764478115784986	
i 1	259.00040136054423	2.7775	76	382	2	24	4	17	0	1	17	0	0	4.0	
i 1	259.00120408163264	9.8475	66	1196	5	14	10	9	0	2	9	0	0	3.2320177156753847	
i 1	259.00361224489797	1.7675	77	382	5	1	3	17	0	1	17	0	0	2.0358440348444966	
i 1	259.00762585034016	2.02	77	1196	6	1	1	17	0	1	17	0	0	2.0358440348444966	
i 1	259.01324489795917	9.8475	61	1196	5	12	3	6	0	2	6	0	0	3.764478115784986	
i 1	259.01404761904763	2.525	74	1196	4	3	9	16	0	2	16	0	0	3.0	
i 1	259.0196666666667	3.0300000000000002	69	1196	6	5	2	0	0	0	0	0	0	2.004130294487196	
i 1	259.2383605442177	0.2525	76	1196	1	24	7	17	0	1	17	0	0	4.0	
i 1	259.26485034013604	0.2525	69	1196	5	5	13	1	0	0	1	0	0	2.004130294487196	
i 1	259.2656530612245	0.2525	77	382	4	9	9	16	0	1	16	0	0	2.0	
i 1	259.49558503401363	0.2525	74	698	6	1	16	8	0	-2	8	0	0	2.0358440348444966	
i 1	259.49879591836736	0.2525	76	698	2	24	14	16	0	1	16	0	0	4.0	
i 1	259.5108367346939	1.01	72	698	6	5	11	8	0	-2	8	0	0	2.004130294487196	
i 1	259.51806122448977	2.2725	74	1196	5	2	16	16	0	2	16	0	0	3.0	
i 1	259.73274149659863	1.01	73	1196	1	24	7	16	0	1	16	0	0	4.0	
i 1	259.7335442176871	1.01	77	382	4	9	4	16	0	1	16	0	0	2.0	
i 1	259.7479931972789	0.7575000000000001	69	1196	5	5	5	1	0	-1	1	0	0	2.004130294487196	
i 1	259.99879591836736	2.02	72	382	6	5	16	1	0	-1	1	0	0	2.004130294487196	
i 1	260.00441496598637	0.2525	74	382	5	1	12	16	0	2	16	0	0	2.0358440348444966	
i 1	260.0164557823129	0.7575000000000001	72	1196	6	5	15	0	0	-1	0	0	0	2.004130294487196	
i 1	260.23996598639457	1.7675	76	1196	1	24	10	17	0	2	17	0	0	4.0	
i 1	260.2528095238095	0.2525	74	698	6	1	2	8	0	-2	8	0	0	2.0358440348444966	
i 1	260.26003401360543	3.0300000000000002	77	1196	4	24	9	16	0	2	16	0	0	3.0358440348444966	
i 1	260.49397959183676	4.545	77	880	6	1	5	16	0	2	16	0	0	2.0358440348444966	
i 1	260.5028095238095	2.7775	61	880	5	13	4	6	0	1	6	0	0	0.9817685575960969	
i 1	260.51003401360543	9.595	61	880	5	7	13	6	0	1	6	0	0	2.481934662982289	
i 1	260.7479931972789	0.2525	69	1196	5	5	16	1	0	0	1	0	0	2.004130294487196	
i 1	260.75602040816324	0.2525	74	382	4	9	2	17	0	1	17	0	0	2.0	
i 1	260.99076870748297	0.2525	74	382	5	1	3	16	0	2	16	0	0	2.0358440348444966	
i 1	260.9979931972789	1.5150000000000001	77	880	4	3	1	16	0	1	16	0	0	3.0	
i 1	261.00120408163264	1.5150000000000001	74	1196	4	4	8	17	0	1	17	0	0	3.0	
i 1	261.0020068027211	0.2525	72	880	6	5	5	0	0	-1	0	0	0	2.004130294487196	
i 1	261.23755782312924	0.2525	72	880	6	5	7	0	0	-1	0	0	0	2.004130294487196	
i 1	261.24076870748297	0.2525	74	880	4	24	5	17	0	2	17	0	0	3.0358440348444966	
i 1	261.48755782312924	2.02	69	1196	5	5	3	1	0	-1	1	0	0	2.004130294487196	
i 1	261.4931768707483	2.02	72	1196	6	5	8	0	0	-1	0	0	0	2.004130294487196	
i 1	261.74879591836736	0.2525	77	382	4	9	7	16	0	1	16	0	0	2.0	
i 1	261.9891632653061	4.545	76	382	2	24	9	17	0	1	17	0	0	4.0	
i 1	261.98996598639457	0.505	72	880	6	5	8	0	0	-1	0	0	0	2.004130294487196	
i 1	261.99237414965984	1.5150000000000001	74	382	4	9	6	17	0	1	17	0	0	2.0	
i 1	262.00602040816324	1.5150000000000001	74	880	4	4	5	17	0	1	17	0	0	3.0	
i 1	262.24879591836736	2.02	76	1196	1	24	1	17	0	2	17	0	0	4.0	
i 1	262.25361224489797	0.2525	73	1196	1	24	13	16	0	1	16	0	0	4.0	
i 1	262.48274149659863	0.2525	77	382	4	9	6	16	0	1	16	0	0	2.0	
i 1	262.50120408163264	0.2525	69	382	6	5	10	1	0	-1	1	0	0	2.004130294487196	
i 1	262.50842857142857	0.505	73	880	2	24	8	17	0	2	17	0	0	4.0	
i 1	262.73514965986396	3.535	69	1196	5	5	5	1	0	0	1	0	0	2.004130294487196	
i 1	262.76485034013604	0.2525	77	1196	5	2	4	16	0	1	16	0	0	3.0	
i 1	262.9931768707483	0.2525	77	382	5	1	5	17	0	1	17	0	0	2.0358440348444966	
i 1	263.00120408163264	1.5150000000000001	74	1196	5	2	6	16	0	2	16	0	0	3.0	
i 1	263.00441496598637	3.2825	72	880	6	5	10	0	0	-1	0	0	0	2.004130294487196	
i 1	263.0156530612245	0.2525	76	1196	1	24	6	17	0	2	17	0	0	4.0	
i 1	263.0164557823129	0.2525	74	1196	4	3	15	16	0	2	16	0	0	3.0	
i 1	263.23113605442177	3.2825	77	1196	3	24	4	16	0	2	16	0	0	3.0358440348444966	
i 1	263.24157142857143	1.5150000000000001	74	1196	3	3	2	16	0	2	16	0	0	3.0	
i 1	263.24237414965984	35.855	61	880	4	13	5	6	0	1	6	0	0	0.9817685575960969	
i 1	263.24478231292517	0.505	74	382	5	1	11	16	0	2	16	0	0	2.0358440348444966	
i 1	263.2479931972789	5.555	61	1196	6	17	10	6	0	1	6	0	0	2.640561506326075	
i 1	263.25602040816324	0.2525	73	880	2	24	13	16	0	1	16	0	0	4.0	
i 1	263.4883605442177	0.2525	77	880	4	3	3	16	0	1	16	0	0	3.0	
i 1	263.51725850340137	0.2525	69	1196	6	5	4	0	0	0	0	0	0	2.004130294487196	
i 1	263.73274149659863	0.2525	69	382	6	5	10	1	0	-1	1	0	0	2.004130294487196	
i 1	263.74638775510203	0.2525	77	382	4	9	11	16	0	1	16	0	0	2.0	
i 1	263.76725850340137	0.2525	74	880	4	24	6	17	0	2	17	0	0	3.0358440348444966	
i 1	263.7696666666667	0.2525	73	880	2	24	13	17	0	1	17	0	0	4.0	
i 1	263.98113605442177	0.2525	77	382	5	1	5	17	0	1	17	0	0	2.0358440348444966	
i 1	263.9843469387755	0.7575000000000001	69	1196	6	5	7	0	0	0	0	0	0	2.004130294487196	
i 1	263.98675510204083	1.01	76	1196	1	24	11	17	0	1	17	0	0	4.0	
i 1	263.9979931972789	0.7575000000000001	72	382	6	5	6	1	0	-1	1	0	0	2.004130294487196	
i 1	264.00521768707483	1.5150000000000001	74	1196	4	4	13	17	0	1	17	0	0	3.0	
i 1	264.0108367346939	1.5150000000000001	77	880	4	3	14	16	0	1	16	0	0	3.0	
i 1	264.2664557823129	1.5150000000000001	74	382	5	1	12	16	0	2	16	0	0	2.0358440348444966	
i 1	264.48996598639457	1.2625	77	1196	6	1	9	17	0	1	17	0	0	2.0358440348444966	
i 1	264.75842857142857	0.7575000000000001	72	880	6	5	9	0	0	-1	0	0	0	2.004130294487196	
i 1	264.7616394557823	0.2525	77	1196	6	2	15	16	0	1	16	0	0	3.0	
i 1	265.00040136054423	1.2625	74	1196	5	2	9	16	0	2	16	0	0	3.0	
i 1	265.00842857142857	2.525	76	1196	1	24	7	17	0	2	17	0	0	4.0	
i 1	265.01324489795917	1.2625	74	1196	3	3	11	16	0	2	16	0	0	3.0	
i 1	265.0196666666667	0.2525	73	880	2	24	4	17	0	2	17	0	0	4.0	
i 1	265.25361224489797	0.2525	76	1196	1	24	16	16	0	2	16	0	0	4.0	
i 1	265.25762585034016	1.2625	77	880	6	1	15	16	0	2	16	0	0	2.0358440348444966	
i 1	265.4883605442177	0.2525	76	880	2	24	6	16	0	2	16	0	0	4.0	
i 1	265.49558503401363	1.5150000000000001	77	382	4	9	2	16	0	1	16	0	0	2.0	
i 1	265.51324489795917	0.2525	69	1196	6	5	6	0	0	0	0	0	0	2.004130294487196	
i 1	265.7471904761905	0.2525	74	880	4	24	16	17	0	2	17	0	0	3.0358440348444966	
i 1	265.74879591836736	1.5150000000000001	72	1196	6	5	8	0	0	-1	0	0	0	2.004130294487196	
i 1	265.76003401360543	0.7575000000000001	73	1196	1	24	15	16	0	2	16	0	0	4.0	
i 1	265.7616394557823	1.2625	77	1196	6	2	9	16	0	1	16	0	0	3.0	
i 1	265.76725850340137	1.5150000000000001	69	1196	5	5	5	1	0	-1	1	0	0	2.004130294487196	
i 1	265.98755782312924	2.7775	74	382	5	1	5	16	0	2	16	0	0	2.0358440348444966	
i 1	265.98996598639457	2.7775	77	1196	6	1	11	17	0	1	17	0	0	2.0358440348444966	
i 1	266.25361224489797	0.2525	77	880	4	3	7	16	0	1	16	0	0	3.0	
i 1	266.25441496598637	0.2525	69	382	6	5	15	1	0	-1	1	0	0	2.004130294487196	
i 1	266.4891632653061	0.7575000000000001	74	1196	3	3	8	16	0	2	16	0	0	3.0	
i 1	266.49076870748297	0.2525	69	1196	5	5	14	1	0	0	1	0	0	2.004130294487196	
i 1	266.49478231292517	0.7575000000000001	74	1196	5	2	1	16	0	2	16	0	0	3.0	
i 1	266.50762585034016	0.2525	74	880	4	24	7	17	0	2	17	0	0	3.0358440348444966	
i 1	266.73675510204083	4.2925	77	880	4	3	6	16	0	1	16	0	0	3.0	
i 1	266.7431768707483	2.02	74	1196	4	4	1	17	0	1	17	0	0	3.0	
i 1	266.74959863945577	2.02	72	382	6	5	16	1	0	-1	1	0	0	2.004130294487196	
i 1	266.76485034013604	0.2525	77	382	5	1	15	17	0	1	17	0	0	2.0358440348444966	
i 1	266.7664557823129	2.02	69	1196	6	5	13	0	0	0	0	0	0	2.004130294487196	
i 1	266.99076870748297	1.01	76	1196	1	24	9	16	0	1	16	0	0	4.0	
i 1	267.24879591836736	0.2525	72	880	6	5	10	0	0	-1	0	0	0	2.004130294487196	
i 1	267.25923129251703	1.01	74	382	4	9	13	17	0	1	17	0	0	2.0	
i 1	267.49959863945577	0.2525	69	1196	5	5	1	1	0	-1	1	0	0	2.004130294487196	
i 1	267.75521768707483	1.01	76	382	2	24	2	17	0	1	17	0	0	4.0	
i 1	267.7664557823129	1.01	76	1196	1	24	5	17	0	2	17	0	0	4.0	
i 1	267.99076870748297	0.2525	74	880	4	24	5	17	0	2	17	0	0	3.0358440348444966	
i 1	268.00040136054423	0.2525	73	880	2	24	5	17	0	2	17	0	0	4.0	
i 1	268.23996598639457	0.505	74	1196	3	3	2	16	0	2	16	0	0	3.0	
i 1	268.24638775510203	0.505	73	1196	1	24	6	17	0	2	17	0	0	4.0	
i 1	268.25762585034016	0.2525	74	1196	5	2	10	16	0	2	16	0	0	3.0	
i 1	268.26324489795917	0.505	77	1196	4	1	9	17	0	1	17	0	0	2.0358440348444966	
i 1	268.26485034013604	4.2925	77	880	6	1	3	16	0	2	16	0	0	2.0358440348444966	
i 1	268.4803333333333	0.2525	77	1196	6	2	9	16	0	1	16	0	0	3.0	
i 1	268.48755782312924	0.2525	69	382	6	5	8	1	0	-1	1	0	0	2.004130294487196	
i 1	268.73675510204083	0.505	74	178	4	4	11	16	5002	2	16	0	0	3.0	
i 1	268.73675510204083	35.35	61	1111	4	14	8	6	5000	1	6	0	0	3.2320177156753847	
i 1	268.74157142857143	3.2825	76	178	1	24	11	17	5002	2	17	0	0	4.0	
i 1	268.7431768707483	0.2525	77	178	5	1	16	16	5001	1	16	0	0	2.0358440348444966	
i 1	268.74397959183676	2.2725	74	178	3	3	7	17	5002	2	17	0	0	3.0	
i 1	268.74478231292517	35.35	61	1111	5	17	13	9	5000	2	9	0	0	2.640561506326075	
i 1	268.74478231292517	1.5150000000000001	73	178	2	24	8	16	5001	1	16	0	0	4.0	
i 1	268.74638775510203	8.08	66	178	5	12	3	6	5002	2	6	0	0	3.764478115784986	
i 1	268.74879591836736	3.7875	74	178	4	1	2	16	5002	1	16	0	0	2.0358440348444966	
i 1	268.7520068027211	0.2525	77	1111	6	1	1	16	5000	2	16	0	0	2.0358440348444966	
i 1	268.75923129251703	1.2625	72	178	6	5	16	1	5001	0	1	0	0	2.004130294487196	
i 1	268.7616394557823	35.35	66	1111	4	14	7	9	5000	2	9	0	0	3.2320177156753847	
i 1	268.7664557823129	0.2525	73	178	1	24	8	16	0	1	16	0	0	4.0	
i 1	268.76806122448977	1.2625	69	1111	6	5	3	1	5000	-1	1	0	0	2.004130294487196	
i 1	268.7696666666667	1.2625	66	178	5	12	14	6	5002	2	6	0	0	3.764478115784986	
i 1	268.98274149659863	0.2525	72	880	6	5	11	0	0	-1	0	0	0	2.004130294487196	
i 1	268.99157142857143	0.2525	76	880	2	24	15	17	0	2	17	0	0	4.0	
i 1	269.0028095238095	0.2525	74	880	4	24	1	17	0	2	17	0	0	3.0358440348444966	
i 1	269.0108367346939	0.505	77	1111	6	2	5	16	5000	1	16	0	0	3.0	
i 1	269.25040136054423	0.505	73	178	1	24	15	16	0	1	16	0	0	4.0	
i 1	269.2568231292517	0.2525	77	1111	6	1	3	16	5000	2	16	0	0	2.0358440348444966	
i 1	269.26404761904763	1.2625	69	178	5	5	5	1	5002	0	1	0	0	2.004130294487196	
i 1	269.4843469387755	0.2525	74	178	4	9	3	16	5001	2	16	0	0	2.0	
i 1	269.4883605442177	1.01	74	880	4	24	1	17	0	2	17	0	0	3.0358440348444966	
i 1	269.4979931972789	1.01	72	880	6	5	3	0	0	-1	0	0	0	2.004130294487196	
i 1	269.73996598639457	0.2525	77	1111	6	2	16	16	5000	1	16	0	0	3.0	
i 1	269.74478231292517	2.02	72	1111	6	5	16	0	5000	0	0	0	0	2.004130294487196	
i 1	269.74959863945577	0.505	73	880	2	24	2	17	0	1	17	0	0	4.0	
i 1	269.75762585034016	2.02	69	178	6	5	9	0	5001	-1	0	0	0	2.004130294487196	
i 1	269.98193877551023	34.0875	66	1111	5	17	14	9	5000	2	9	0	0	2.640561506326075	
i 1	269.99157142857143	3.0300000000000002	74	178	4	9	8	16	5001	2	16	0	0	2.0	
i 1	269.99879591836736	27.27	61	1111	5	14	10	6	5000	1	6	0	0	4.940128417412796	
i 1	270.00361224489797	29.0375	61	880	4	7	12	6	0	1	6	0	0	2.481934662982289	
i 1	270.23996598639457	0.2525	77	178	4	24	15	17	5002	1	17	0	0	3.0358440348444966	
i 1	270.26244217687076	1.01	76	178	1	24	9	17	0	2	17	0	0	4.0	
i 1	270.26886394557823	3.2825	77	1111	6	2	7	17	5000	1	17	0	0	3.0	
i 1	270.4843469387755	0.2525	74	1111	6	1	2	17	5000	1	17	0	0	2.0358440348444966	
i 1	270.48514965986396	0.2525	69	178	5	5	6	0	5002	-1	0	0	0	2.004130294487196	
i 1	270.48755782312924	0.7575000000000001	73	178	2	24	15	16	5001	1	16	0	0	4.0	
i 1	270.50842857142857	0.2525	72	178	6	5	1	1	5001	0	1	0	0	2.004130294487196	
i 1	270.74558503401363	1.2625	74	178	4	9	1	17	5001	2	17	0	0	2.0	
i 1	270.7528095238095	0.2525	69	178	5	5	12	1	5002	0	1	0	0	2.004130294487196	
i 1	270.75842857142857	0.2525	72	880	6	5	15	0	0	-1	0	0	0	2.004130294487196	
i 1	270.76886394557823	0.2525	77	1111	6	1	3	16	5000	2	16	0	0	2.0358440348444966	
i 1	270.7696666666667	1.2625	77	1111	6	2	12	16	5000	1	16	0	0	3.0	
i 1	270.9971904761905	1.7675	72	880	6	5	5	0	0	-1	0	0	0	2.004130294487196	
i 1	271.2568231292517	1.5150000000000001	69	178	5	5	1	1	5002	0	1	0	0	2.004130294487196	
i 1	271.73113605442177	0.2525	69	178	5	5	7	0	5002	-1	0	0	0	2.004130294487196	
i 1	271.73514965986396	0.2525	74	1111	6	1	13	17	5000	1	17	0	0	2.0358440348444966	
i 1	271.9883605442177	5.555	77	178	6	1	16	17	5001	1	17	0	0	2.0358440348444966	
i 1	271.9931768707483	2.7775	74	178	3	3	3	17	5002	2	17	0	0	3.0	
i 1	272.0020068027211	2.7775	77	880	4	3	12	16	0	1	16	0	0	3.0	
i 1	272.00602040816324	0.2525	72	880	6	5	14	0	0	-1	0	0	0	2.004130294487196	
i 1	272.0156530612245	1.5150000000000001	69	1111	6	5	11	1	5000	-1	1	0	0	2.004130294487196	
i 1	272.0164557823129	5.8075	77	1111	6	1	8	16	5000	2	16	0	0	2.0358440348444966	
i 1	272.23996598639457	3.7875	72	1111	6	5	2	0	5000	0	0	0	0	2.004130294487196	
i 1	272.24237414965984	3.7875	69	178	6	5	4	0	5001	-1	0	0	0	2.004130294487196	
i 1	272.24397959183676	1.01	72	178	6	5	11	1	5001	0	1	0	0	2.004130294487196	
i 1	272.2471904761905	1.2625	76	178	1	24	15	17	5002	2	17	0	0	4.0	
i 1	272.2528095238095	1.2625	73	178	2	24	10	16	5001	1	16	0	0	4.0	
i 1	272.49478231292517	0.2525	74	880	4	24	13	17	0	2	17	0	0	3.0358440348444966	
i 1	272.73996598639457	0.7575000000000001	76	178	1	24	7	16	0	1	16	0	0	4.0	
i 1	272.74237414965984	1.7675	77	880	6	1	2	16	0	2	16	0	0	2.0358440348444966	
i 1	272.75602040816324	1.7675	74	178	4	1	3	16	5002	1	16	0	0	2.0358440348444966	
i 1	273.24478231292517	0.2525	69	178	5	5	10	1	5002	0	1	0	0	2.004130294487196	
i 1	273.51003401360543	0.2525	72	880	6	5	3	0	0	-1	0	0	0	2.004130294487196	
i 1	273.5164557823129	0.2525	77	1111	6	2	8	16	5000	1	16	0	0	3.0	
i 1	273.76886394557823	0.2525	77	1111	6	2	14	17	5000	1	17	0	0	3.0	
i 1	273.98514965986396	1.5150000000000001	74	880	4	4	8	17	0	1	17	0	0	3.0	
i 1	273.99558503401363	1.5150000000000001	74	178	3	4	9	16	5002	2	16	0	0	3.0	
i 1	274.2383605442177	29.795	76	178	1	24	8	17	5002	2	17	0	0	4.0	
i 1	274.2479931972789	0.2525	72	880	6	5	3	0	0	-1	0	0	0	2.004130294487196	
i 1	274.4891632653061	0.505	69	178	5	5	11	0	5002	-1	0	0	0	2.004130294487196	
i 1	274.50762585034016	1.5150000000000001	73	178	2	24	5	16	5001	1	16	0	0	4.0	
i 1	274.5108367346939	0.2525	76	178	1	24	14	16	0	1	16	0	0	4.0	
i 1	274.5196666666667	0.2525	77	178	4	24	12	17	5002	1	17	0	0	3.0358440348444966	
i 1	274.75521768707483	0.2525	74	880	4	24	2	17	0	2	17	0	0	3.0358440348444966	
i 1	274.7608367346939	0.2525	74	178	4	1	15	16	5002	1	16	0	0	2.0358440348444966	
i 1	274.7656530612245	0.2525	74	178	4	9	8	16	5001	2	16	0	0	2.0	
i 1	274.7664557823129	0.2525	76	880	2	24	8	17	0	1	17	0	0	4.0	
i 1	274.98675510204083	1.5150000000000001	77	880	4	3	2	16	0	1	16	0	0	3.0	
i 1	274.98755782312924	1.7675	74	178	3	3	5	17	5002	2	17	0	0	3.0	
i 1	274.99397959183676	0.2525	72	880	6	5	1	0	0	-1	0	0	0	2.004130294487196	
i 1	275.00762585034016	0.2525	73	178	1	24	9	16	0	2	16	0	0	4.0	
i 1	275.2608367346939	2.02	72	178	6	5	13	1	5001	0	1	0	0	2.004130294487196	
i 1	275.2656530612245	2.02	69	1111	6	5	2	1	5000	-1	1	0	0	2.004130294487196	
i 1	275.26725850340137	0.505	76	880	2	24	5	16	0	1	16	0	0	4.0	
i 1	275.4843469387755	0.2525	74	178	4	9	8	16	5001	2	16	0	0	2.0	
i 1	275.51244217687076	0.2525	74	178	4	1	6	16	5002	1	16	0	0	2.0358440348444966	
i 1	275.7303333333333	0.2525	77	1111	6	2	8	16	5000	1	16	0	0	3.0	
i 1	275.74237414965984	0.505	77	178	5	1	4	16	5001	1	16	0	0	2.0358440348444966	
i 1	276.00040136054423	0.2525	72	880	6	5	7	0	0	-1	0	0	0	2.004130294487196	
i 1	276.0108367346939	3.7875	74	178	4	9	2	16	5001	2	16	0	0	2.0	
i 1	276.01404761904763	4.04	77	1111	6	2	8	17	5000	1	17	0	0	3.0	
i 1	276.2568231292517	0.2525	74	1111	6	1	16	17	5000	1	17	0	0	2.0358440348444966	
i 1	276.25923129251703	0.2525	72	1111	6	5	13	0	5000	0	0	0	0	2.004130294487196	
i 1	276.2664557823129	0.2525	74	178	4	1	4	16	5002	1	16	0	0	2.0358440348444966	
i 1	276.48514965986396	2.2725	77	178	4	24	3	17	5002	1	17	0	0	3.0358440348444966	
i 1	276.4931768707483	2.02	74	880	4	24	12	17	0	2	17	0	0	3.0358440348444966	
i 1	276.5196666666667	0.2525	72	880	6	5	1	0	0	-1	0	0	0	2.004130294487196	
i 1	276.74076870748297	27.27	61	1111	5	13	5	9	5000	2	9	0	0	1.4131775125293653	
i 1	276.7471904761905	22.22	66	880	5	17	11	6	0	1	6	0	0	2.640561506326075	
i 1	276.75762585034016	2.02	77	1111	6	2	10	16	5000	1	16	0	0	3.0	
i 1	276.76485034013604	3.535	72	880	6	5	7	0	0	-1	0	0	0	2.004130294487196	
i 1	276.7656530612245	3.7875	69	178	5	5	14	1	5002	0	1	0	0	2.004130294487196	
i 1	276.99478231292517	1.5150000000000001	74	178	4	9	10	17	5001	2	17	0	0	2.0	
i 1	277.0108367346939	1.01	73	178	2	24	7	16	5001	1	16	0	0	4.0	
i 1	277.25602040816324	0.2525	72	880	6	5	12	0	0	-1	0	0	0	2.004130294487196	
i 1	277.2656530612245	1.5150000000000001	69	178	6	5	2	0	5001	-1	0	0	0	2.004130294487196	
i 1	277.49558503401363	3.7875	74	178	4	1	6	16	5002	1	16	0	0	2.0358440348444966	
i 1	277.49879591836736	1.2625	72	1111	6	5	9	0	5000	0	0	0	0	2.004130294487196	
i 1	277.73996598639457	3.535	77	880	6	1	9	16	0	2	16	0	0	2.0358440348444966	
i 1	278.2335442176871	2.02	73	178	2	24	3	16	5001	1	16	0	0	4.0	
i 1	278.50361224489797	0.2525	77	178	6	1	12	16	5001	1	16	0	0	2.0358440348444966	
i 1	278.7391632653061	0.7575000000000001	72	880	6	5	9	0	0	-1	0	0	0	2.004130294487196	
i 1	278.74076870748297	0.2525	77	178	6	1	12	17	5001	1	17	0	0	2.0358440348444966	
i 1	278.74157142857143	0.2525	69	1111	6	5	2	1	5000	-1	1	0	0	2.004130294487196	
i 1	278.7479931972789	4.7975	77	880	5	3	8	16	0	1	16	0	0	3.0	
i 1	278.7520068027211	4.7975	74	178	3	3	2	17	5002	2	17	0	0	3.0	
i 1	278.76485034013604	0.2525	77	1111	6	1	16	16	5000	2	16	0	0	2.0358440348444966	
i 1	279.01244217687076	0.2525	69	178	6	5	16	0	5001	-1	0	0	0	2.004130294487196	
i 1	279.23755782312924	0.2525	74	1111	6	1	15	17	5000	1	17	0	0	2.0358440348444966	
i 1	279.2471904761905	1.7675	72	178	6	5	14	1	5001	0	1	0	0	2.004130294487196	
i 1	279.2479931972789	0.2525	77	1111	6	1	1	16	5000	2	16	0	0	2.0358440348444966	
i 1	279.48595238095237	0.505	74	880	4	24	16	17	0	2	17	0	0	3.0358440348444966	
i 1	279.5020068027211	1.5150000000000001	69	1111	6	5	9	1	5000	-1	1	0	0	2.004130294487196	
i 1	279.50842857142857	0.505	77	178	6	1	1	17	5001	1	17	0	0	2.0358440348444966	
i 1	279.73755782312924	0.2525	74	880	4	4	10	17	0	1	17	0	0	3.0	
i 1	279.98274149659863	0.2525	77	1111	6	2	16	16	5000	1	16	0	0	3.0	
i 1	279.98675510204083	0.2525	74	1111	6	1	9	17	5000	1	17	0	0	2.0358440348444966	
i 1	279.98996598639457	0.2525	74	178	4	9	15	16	5001	2	16	0	0	2.0	
i 1	280.2335442176871	2.525	77	178	6	1	5	17	5001	1	17	0	0	2.0358440348444966	
i 1	280.2343469387755	1.2625	74	880	4	4	14	17	0	1	17	0	0	3.0	
i 1	280.2391632653061	0.2525	72	880	6	5	4	0	0	-1	0	0	0	2.004130294487196	
i 1	280.2479931972789	0.2525	74	178	4	9	13	17	5001	2	17	0	0	2.0	
i 1	280.2616394557823	2.525	77	1111	6	1	14	16	5000	2	16	0	0	2.0358440348444966	
i 1	280.48595238095237	1.01	74	178	3	4	5	16	5002	2	16	0	0	3.0	
i 1	280.48595238095237	3.535	72	1111	6	5	16	0	5000	0	0	0	0	2.004130294487196	
i 1	280.48675510204083	3.535	69	178	6	5	10	0	5001	-1	0	0	0	2.004130294487196	
i 1	280.98675510204083	0.2525	69	178	5	5	14	1	5002	0	1	0	0	2.004130294487196	
i 1	281.00923129251703	0.2525	69	178	5	5	12	0	5002	-1	0	0	0	2.004130294487196	
i 1	281.2343469387755	0.505	74	880	4	24	12	17	0	2	17	0	0	3.0358440348444966	
i 1	281.24237414965984	0.2525	74	1111	6	1	4	17	5000	1	17	0	0	2.0358440348444966	
i 1	281.2568231292517	0.2525	72	880	6	5	10	0	0	-1	0	0	0	2.004130294487196	
i 1	281.26003401360543	0.505	72	178	6	5	11	1	5001	0	1	0	0	2.004130294487196	
i 1	281.4971904761905	0.2525	69	1111	6	5	7	1	5000	-1	1	0	0	2.004130294487196	
i 1	281.4979931972789	0.2525	74	178	4	9	11	17	5001	2	17	0	0	2.0	
i 1	281.50842857142857	0.2525	74	178	4	9	11	16	5001	2	16	0	0	2.0	
i 1	281.74638775510203	0.7575000000000001	74	880	4	4	1	17	0	1	17	0	0	3.0	
i 1	281.7528095238095	0.7575000000000001	72	880	6	5	11	0	0	-1	0	0	0	2.004130294487196	
i 1	281.75602040816324	2.2725	77	880	6	1	8	16	0	2	16	0	0	2.0358440348444966	
i 1	281.7568231292517	1.7675	74	178	4	1	11	16	5002	1	16	0	0	2.0358440348444966	
i 1	281.76244217687076	0.2525	77	1111	6	2	8	16	5000	1	16	0	0	3.0	
i 1	282.23996598639457	0.2525	72	880	6	5	15	0	0	-1	0	0	0	2.004130294487196	
i 1	282.4835442176871	0.2525	72	178	6	5	7	1	5001	0	1	0	0	2.004130294487196	
i 1	282.49478231292517	3.535	74	178	4	9	2	16	5001	2	16	0	0	2.0	
i 1	282.50441496598637	2.2725	69	1111	6	5	11	1	5000	-1	1	0	0	2.004130294487196	
i 1	282.50842857142857	3.535	77	1111	6	2	12	17	5000	1	17	0	0	3.0	
i 1	282.73514965986396	0.2525	69	178	5	5	8	1	5002	0	1	0	0	2.004130294487196	
i 1	282.74076870748297	0.2525	77	178	4	24	5	17	5002	1	17	0	0	3.0358440348444966	
i 1	282.98514965986396	0.2525	77	178	6	1	2	16	5001	1	16	0	0	2.0358440348444966	
i 1	282.9979931972789	0.2525	74	880	4	24	16	17	0	2	17	0	0	3.0358440348444966	
i 1	282.99879591836736	1.5150000000000001	72	178	6	5	6	1	5001	0	1	0	0	2.004130294487196	
i 1	283.23595238095237	0.2525	77	1111	6	1	9	16	5000	2	16	0	0	2.0358440348444966	
i 1	283.2383605442177	4.2925	69	178	5	5	10	1	5002	0	1	0	0	2.004130294487196	
i 1	283.24157142857143	3.0300000000000002	77	178	6	1	13	17	5001	1	17	0	0	2.0358440348444966	
i 1	283.25923129251703	3.7875	72	880	6	5	5	0	0	-1	0	0	0	2.004130294487196	
i 1	283.4803333333333	15.4025	61	880	5	17	7	6	0	1	6	0	0	2.640561506326075	
i 1	283.4883605442177	0.7575000000000001	74	178	5	1	5	16	5002	1	16	0	0	2.0358440348444966	
i 1	283.50361224489797	1.7675	77	1111	6	2	7	16	5000	1	16	0	0	3.0	
i 1	283.5068231292517	15.4025	66	880	5	15	16	6	0	1	6	0	0	2.5888278141571757	
i 1	283.50762585034016	1.7675	74	178	4	9	3	17	5001	2	17	0	0	2.0	
i 1	283.5116394557823	2.7775	77	1111	6	1	7	16	5000	2	16	0	0	2.0358440348444966	
i 1	284.23755782312924	1.01	73	178	2	24	16	16	5001	1	16	0	0	4.0	
i 1	284.24558503401363	0.2525	74	880	4	24	1	17	0	2	17	0	0	3.0358440348444966	
i 1	284.26886394557823	0.2525	77	178	4	24	15	17	5002	1	17	0	0	3.0358440348444966	
i 1	284.4979931972789	0.2525	74	1111	6	1	11	17	5000	1	17	0	0	2.0358440348444966	
i 1	284.50842857142857	0.2525	69	178	5	5	10	0	5002	-1	0	0	0	2.004130294487196	
i 1	284.51324489795917	0.2525	74	178	5	1	9	16	5002	1	16	0	0	2.0358440348444966	
i 1	284.73193877551023	0.505	77	880	6	1	3	16	0	2	16	0	0	2.0358440348444966	
i 1	284.7528095238095	2.02	72	1111	6	5	13	0	5000	0	0	0	0	2.004130294487196	
i 1	284.75361224489797	2.02	69	178	6	5	12	0	5001	-1	0	0	0	2.004130294487196	
i 1	284.98113605442177	0.2525	74	1111	6	1	12	17	5000	1	17	0	0	2.0358440348444966	
i 1	284.9891632653061	5.05	74	178	3	3	3	17	5002	2	17	0	0	3.0	
i 1	285.01725850340137	5.05	77	880	5	3	3	16	0	1	16	0	0	3.0	
i 1	285.2568231292517	1.7675	74	880	4	24	8	17	0	2	17	0	0	3.0358440348444966	
i 1	285.2568231292517	1.7675	77	178	4	24	6	17	5002	1	17	0	0	3.0358440348444966	
i 1	285.98274149659863	2.7775	72	178	6	5	1	1	5001	0	1	0	0	2.004130294487196	
i 1	286.00602040816324	7.07	74	178	5	1	8	16	5002	1	16	0	0	2.0358440348444966	
i 1	286.0116394557823	5.05	77	880	6	1	11	16	0	2	16	0	0	2.0358440348444966	
i 1	286.01324489795917	2.7775	69	1111	6	5	12	1	5000	-1	1	0	0	2.004130294487196	
i 1	286.0164557823129	2.2725	74	178	3	4	9	16	5002	2	16	0	0	3.0	
i 1	286.25521768707483	2.02	74	880	4	4	7	17	0	1	17	0	0	3.0	
i 1	286.98514965986396	0.2525	69	178	6	5	4	0	5001	-1	0	0	0	2.004130294487196	
i 1	286.98595238095237	0.2525	77	1111	6	1	11	16	5000	2	16	0	0	2.0358440348444966	
i 1	286.98755782312924	1.2625	73	178	2	24	14	16	5001	1	16	0	0	4.0	
i 1	287.0196666666667	0.2525	77	178	6	1	12	16	5001	1	16	0	0	2.0358440348444966	
i 1	287.23113605442177	0.2525	72	880	6	5	11	0	0	-1	0	0	0	2.004130294487196	
i 1	287.2479931972789	1.01	77	178	6	1	11	17	5001	1	17	0	0	2.0358440348444966	
i 1	287.26725850340137	0.2525	74	880	4	24	13	17	0	2	17	0	0	3.0358440348444966	
i 1	287.4931768707483	3.7875	72	1111	6	5	6	0	5000	0	0	0	0	2.004130294487196	
i 1	287.51404761904763	2.7775	69	178	6	5	6	0	5001	-1	0	0	0	2.004130294487196	
i 1	287.74397959183676	0.2525	74	880	4	24	14	17	0	2	17	0	0	3.0358440348444966	
i 1	288.01003401360543	0.7575000000000001	77	178	4	24	14	17	5002	1	17	0	0	3.0358440348444966	
i 1	288.2528095238095	0.2525	74	178	4	9	14	16	5001	2	16	0	0	2.0	
i 1	288.25842857142857	0.7575000000000001	77	1111	6	2	10	16	5000	1	16	0	0	3.0	
i 1	288.26485034013604	0.2525	77	178	6	1	13	16	5001	1	16	0	0	2.0358440348444966	
i 1	288.51404761904763	0.505	77	178	6	1	4	17	5001	1	17	0	0	2.0358440348444966	
i 1	288.51886394557823	0.2525	74	178	3	4	14	16	5002	2	16	0	0	3.0	
i 1	288.73514965986396	0.2525	72	880	6	5	12	0	0	-1	0	0	0	2.004130294487196	
i 1	288.74638775510203	0.7575000000000001	74	880	4	24	9	17	0	2	17	0	0	3.0358440348444966	
i 1	288.75762585034016	0.2525	72	880	6	5	10	0	0	-1	0	0	0	2.004130294487196	
i 1	288.76404761904763	0.2525	74	880	4	4	8	17	0	1	17	0	0	3.0	
i 1	288.9803333333333	0.2525	74	1111	6	1	5	17	5000	1	17	0	0	2.0358440348444966	
i 1	288.98996598639457	0.505	69	178	5	5	3	1	5002	0	1	0	0	2.004130294487196	
i 1	288.99157142857143	3.0300000000000002	74	178	4	9	16	16	5001	2	16	0	0	2.0	
i 1	289.00602040816324	0.2525	69	1111	6	5	12	1	5000	-1	1	0	0	2.004130294487196	
i 1	289.00923129251703	3.0300000000000002	77	1111	6	2	16	17	5000	1	17	0	0	3.0	
i 1	289.25120408163264	0.2525	77	178	6	1	11	17	5001	1	17	0	0	2.0358440348444966	
i 1	289.25521768707483	0.7575000000000001	72	880	6	5	4	0	0	-1	0	0	0	2.004130294487196	
i 1	289.48755782312924	0.2525	74	1111	6	1	1	17	5000	1	17	0	0	2.0358440348444966	
i 1	289.51324489795917	0.2525	72	178	6	5	12	1	5001	0	1	0	0	2.004130294487196	
i 1	289.73675510204083	0.2525	77	178	6	1	14	16	5001	1	16	0	0	2.0358440348444966	
i 1	289.74076870748297	0.505	74	178	4	9	2	17	5001	2	17	0	0	2.0	
i 1	289.74959863945577	0.505	72	880	6	5	6	0	0	-1	0	0	0	2.004130294487196	
i 1	289.7656530612245	0.505	77	1111	6	2	8	16	5000	1	16	0	0	3.0	
i 1	289.76725850340137	0.2525	74	880	4	24	6	17	0	2	17	0	0	3.0358440348444966	
i 1	289.98193877551023	0.7575000000000001	73	178	3	24	6	17	0	2	17	0	0	4.0	
i 1	289.9883605442177	5.3025	77	1111	6	1	2	16	5000	2	16	0	0	2.0358440348444966	
i 1	290.00842857142857	4.7975	77	178	6	1	11	17	5001	1	17	0	0	2.0358440348444966	
i 1	290.00842857142857	0.2525	73	178	2	24	1	16	5001	1	16	0	0	4.0	
i 1	290.01725850340137	2.2725	72	178	6	5	1	1	5001	0	1	0	0	2.004130294487196	
i 1	290.2335442176871	0.7575000000000001	77	1111	4	2	4	16	5000	1	16	0	0	3.0	
i 1	290.24959863945577	0.7575000000000001	74	178	6	9	1	17	5001	2	17	0	0	2.0	
i 1	290.25040136054423	8.585	61	880	5	15	4	6	0	2	6	0	0	2.5888278141571757	
i 1	290.25441496598637	1.01	69	178	7	5	12	0	5001	-1	0	0	0	2.004130294487196	
i 1	290.26725850340137	2.02	69	1111	6	5	9	1	5000	-1	1	0	0	2.004130294487196	
i 1	290.26806122448977	1.01	73	178	4	24	5	16	5001	1	16	0	0	4.0	
i 1	290.26886394557823	13.635	61	178	5	18	10	9	5001	1	9	0	0	2.640561506326075	
i 1	290.75923129251703	0.505	76	880	4	24	7	17	0	2	17	0	0	4.0	
i 1	290.9979931972789	4.7975	74	178	3	3	4	17	5002	2	17	0	0	3.0	
i 1	291.0028095238095	4.7975	77	880	5	3	2	16	0	1	16	0	0	3.0	
i 1	291.01003401360543	0.2525	77	178	5	24	16	17	5002	1	17	0	0	3.0358440348444966	
i 1	291.23193877551023	2.02	77	880	6	1	15	16	0	2	16	0	0	2.0358440348444966	
i 1	291.2383605442177	1.2625	69	178	5	5	16	1	5002	0	1	0	0	2.004130294487196	
i 1	291.25441496598637	1.2625	72	880	6	5	9	0	0	-1	0	0	0	2.004130294487196	
i 1	291.2616394557823	0.505	76	178	3	24	6	16	0	1	16	0	0	4.0	
i 1	291.4931768707483	2.525	72	1111	6	5	11	0	5000	0	0	0	0	2.004130294487196	
i 1	291.4931768707483	2.525	69	178	7	5	4	0	5001	-1	0	0	0	2.004130294487196	
i 1	291.5116394557823	1.2625	73	178	4	24	12	16	5001	1	16	0	0	4.0	
i 1	291.7383605442177	0.2525	73	880	4	24	4	17	0	2	17	0	0	4.0	
i 1	291.99879591836736	0.2525	76	178	3	24	2	17	0	2	17	0	0	4.0	
i 1	292.00120408163264	0.505	74	880	4	4	9	17	0	1	17	0	0	3.0	
i 1	292.00361224489797	0.2525	77	1111	4	2	3	16	5000	1	16	0	0	3.0	
i 1	292.24157142857143	0.2525	76	880	4	24	12	17	0	1	17	0	0	4.0	
i 1	292.26886394557823	0.2525	74	178	3	4	4	16	5002	2	16	0	0	3.0	
i 1	292.4803333333333	0.505	72	880	6	5	16	0	0	-1	0	0	0	2.004130294487196	
i 1	292.4883605442177	0.2525	77	1111	6	2	9	17	5000	1	17	0	0	3.0	
i 1	292.49959863945577	0.505	72	178	6	5	1	1	5001	0	1	0	0	2.004130294487196	
i 1	292.51244217687076	0.505	73	178	3	24	10	17	0	1	17	0	0	4.0	
i 1	292.74397959183676	2.02	74	880	4	4	7	17	0	1	17	0	0	3.0	
i 1	292.7696666666667	0.2525	74	178	4	9	12	16	5001	2	16	0	0	2.0	
i 1	292.98514965986396	1.7675	74	178	3	4	9	16	5002	2	16	0	0	3.0	
i 1	292.99478231292517	2.02	72	880	6	5	16	0	0	-1	0	0	0	2.004130294487196	
i 1	293.00602040816324	0.505	74	880	4	24	2	17	0	2	17	0	0	3.0358440348444966	
i 1	293.0116394557823	2.02	69	178	5	5	4	1	5002	0	1	0	0	2.004130294487196	
i 1	293.26886394557823	3.2825	77	178	5	24	16	17	5002	1	17	0	0	3.0358440348444966	
i 1	293.50521768707483	0.2525	74	178	5	1	16	16	5002	1	16	0	0	2.0358440348444966	
i 1	293.50762585034016	2.525	73	178	4	24	1	16	5001	1	16	0	0	4.0	
i 1	293.74879591836736	2.525	74	880	4	24	5	17	0	2	17	0	0	3.0358440348444966	
i 1	293.9979931972789	1.2625	72	178	6	5	11	1	5001	0	1	0	0	2.004130294487196	
i 1	294.00040136054423	1.2625	69	1111	6	5	8	1	5000	-1	1	0	0	2.004130294487196	
i 1	294.24157142857143	6.0600000000000005	72	1111	6	5	11	0	5000	0	0	0	0	2.004130294487196	
i 1	294.24879591836736	4.04	69	178	7	5	6	0	5001	-1	0	0	0	2.004130294487196	
i 1	294.73595238095237	0.2525	77	880	6	1	3	16	0	2	16	0	0	2.0358440348444966	
i 1	294.76485034013604	2.2725	77	1111	6	2	1	17	5000	1	17	0	0	3.0	
i 1	294.7656530612245	2.2725	74	178	4	9	5	16	5001	2	16	0	0	2.0	
i 1	294.99076870748297	0.2525	77	178	6	1	16	17	5001	1	17	0	0	2.0358440348444966	
i 1	295.25120408163264	1.7675	77	880	6	1	4	16	0	2	16	0	0	2.0358440348444966	
i 1	295.26003401360543	0.2525	72	880	6	5	14	0	0	-1	0	0	0	2.004130294487196	
i 1	295.26886394557823	0.2525	69	178	5	5	1	0	5002	-1	0	0	0	2.004130294487196	
i 1	295.2696666666667	4.04	74	178	5	1	9	16	5002	1	16	0	0	2.0358440348444966	
i 1	295.4979931972789	0.2525	72	880	6	5	1	0	0	-1	0	0	0	2.004130294487196	
i 1	295.50120408163264	0.2525	72	178	6	5	13	1	5001	0	1	0	0	2.004130294487196	
i 1	295.74237414965984	0.2525	69	178	5	5	2	0	5002	-1	0	0	0	2.004130294487196	
i 1	295.7471904761905	2.02	77	1111	4	2	3	16	5000	1	16	0	0	3.0	
i 1	295.75923129251703	2.02	74	178	6	9	2	17	5001	2	17	0	0	2.0	
i 1	296.00602040816324	0.2525	69	1111	6	5	16	1	5000	-1	1	0	0	2.004130294487196	
i 1	296.23755782312924	0.7575000000000001	72	880	6	5	11	0	0	-1	0	0	0	2.004130294487196	
i 1	296.26725850340137	0.2525	77	1111	6	1	13	16	5000	2	16	0	0	2.0358440348444966	
i 1	296.48274149659863	0.7575000000000001	74	1111	6	1	16	17	5000	1	17	0	0	2.0358440348444966	
i 1	296.50040136054423	0.505	73	178	3	24	11	17	0	2	17	0	0	4.0	
i 1	296.5196666666667	0.2525	74	880	4	24	3	17	0	2	17	0	0	3.0358440348444966	
i 1	296.7479931972789	1.7675	73	178	4	24	14	16	5001	1	16	0	0	4.0	
i 1	296.75040136054423	0.2525	77	178	5	24	12	17	5002	1	17	0	0	3.0358440348444966	
i 1	296.7664557823129	0.2525	69	178	5	5	10	0	5002	-1	0	0	0	2.004130294487196	
i 1	296.9891632653061	2.2725	69	1111	6	5	8	1	5000	-1	1	0	0	2.004130294487196	
i 1	296.99076870748297	6.8175	66	178	5	16	9	9	5001	2	9	0	0	3.764478115784986	
i 1	296.99558503401363	6.8175	66	178	5	18	14	6	5001	2	6	0	0	2.640561506326075	
i 1	296.99638775510203	1.7675	77	880	6	1	9	16	0	2	16	0	0	2.0358440348444966	
i 1	297.00040136054423	0.2525	76	880	4	24	9	17	0	1	17	0	0	4.0	
i 1	297.0068231292517	1.7675	74	178	6	9	3	16	5001	2	16	0	0	2.0	
i 1	297.00923129251703	6.8175	61	1111	5	14	1	6	5000	1	6	0	0	4.940128417412796	
i 1	297.0116394557823	0.505	77	178	6	1	2	17	5001	1	17	0	0	2.0358440348444966	
i 1	297.01324489795917	1.7675	77	1111	4	2	9	17	5000	1	17	0	0	3.0	
i 1	297.01324489795917	3.2825	72	178	7	5	12	1	5001	0	1	0	0	2.004130294487196	
i 1	297.24879591836736	0.505	77	178	5	24	15	17	5002	1	17	0	0	3.0358440348444966	
i 1	297.24959863945577	0.7575000000000001	73	178	3	24	6	17	0	2	17	0	0	4.0	
i 1	297.51725850340137	0.2525	74	1111	6	1	8	17	5000	1	17	0	0	2.0358440348444966	
i 1	297.73274149659863	1.5150000000000001	74	178	3	3	13	17	5002	2	17	0	0	3.0	
i 1	297.7335442176871	0.505	77	178	6	1	16	16	5001	1	16	0	0	2.0358440348444966	
i 1	297.74959863945577	0.2525	77	178	6	1	14	17	5001	1	17	0	0	2.0358440348444966	
i 1	297.7616394557823	1.01	77	880	5	3	14	16	0	1	16	0	0	3.0	
i 1	297.98675510204083	2.02	77	178	5	24	8	17	5002	1	17	0	0	3.0358440348444966	
i 1	297.9931768707483	0.2525	73	880	4	24	9	16	0	2	16	0	0	4.0	
i 1	298.23595238095237	0.2525	76	178	3	24	16	17	0	1	17	0	0	4.0	
i 1	298.23755782312924	0.505	74	880	4	4	1	17	0	1	17	0	0	3.0	
i 1	298.23996598639457	0.505	69	178	5	5	13	1	5002	0	1	0	0	2.004130294487196	
i 1	298.24397959183676	1.7675	74	178	6	9	13	17	5001	2	17	0	0	2.0	
i 1	298.24558503401363	0.2525	77	178	6	1	12	17	5001	1	17	0	0	2.0358440348444966	
i 1	298.4891632653061	0.2525	74	1111	6	1	6	17	5000	1	17	0	0	2.0358440348444966	
i 1	298.74076870748297	5.05	66	699	5	15	1	6	0	2	6	0	0	2.5888278141571757	
i 1	298.74879591836736	0.2525	77	699	4	24	6	17	0	2	17	0	0	3.0358440348444966	
i 1	298.74959863945577	5.05	66	699	5	17	8	9	0	1	9	0	0	2.640561506326075	
i 1	298.74959863945577	5.05	66	699	4	7	14	9	0	2	9	0	0	2.481934662982289	
i 1	298.75040136054423	0.2525	72	699	6	5	1	0	0	0	0	0	0	2.004130294487196	
i 1	298.75361224489797	5.05	66	699	5	17	4	6	0	1	6	0	0	2.640561506326075	
i 1	298.75923129251703	2.525	77	699	5	3	4	17	0	2	17	0	0	3.0	
i 1	298.7616394557823	5.05	61	699	4	13	4	6	0	1	6	0	0	0.9817685575960969	
i 1	298.76485034013604	1.2625	77	699	6	1	16	17	0	1	17	0	0	2.0358440348444966	
i 1	298.76485034013604	5.05	61	699	5	15	2	6	0	2	6	0	0	2.5888278141571757	
i 1	298.76806122448977	1.2625	74	699	4	4	4	16	0	2	16	0	0	3.0	
i 1	298.9843469387755	3.535	77	1111	6	1	5	16	5000	2	16	0	0	2.0358440348444966	
i 1	298.99237414965984	2.2725	74	178	3	4	12	16	5002	2	16	0	0	3.0	
i 1	299.00762585034016	1.5150000000000001	69	178	5	5	10	0	5002	-1	0	0	0	2.004130294487196	
i 1	299.0108367346939	3.535	77	178	6	1	11	16	5001	1	16	0	0	2.0358440348444966	
i 1	299.26725850340137	1.5150000000000001	72	699	6	5	11	0	0	0	0	0	0	2.004130294487196	
i 1	299.48595238095237	3.2825	69	1111	6	5	10	1	5000	-1	1	0	0	2.004130294487196	
i 1	299.5196666666667	2.525	69	178	5	5	7	1	5002	0	1	0	0	2.004130294487196	
i 1	299.74558503401363	1.5150000000000001	73	178	4	24	6	16	5001	1	16	0	0	4.0	
i 1	299.98595238095237	4.04	77	1111	4	2	5	17	5000	1	17	0	0	3.0	
i 1	299.99157142857143	0.505	77	699	4	24	14	17	0	2	17	0	0	3.0358440348444966	
i 1	300.00120408163264	0.2525	77	1111	4	2	3	16	5000	1	16	0	0	3.0	
i 1	300.0108367346939	0.2525	74	178	5	1	15	16	5002	1	16	0	0	2.0358440348444966	
i 1	300.2383605442177	1.01	74	1111	6	1	12	17	5000	1	17	0	0	2.0358440348444966	
i 1	300.26725850340137	3.535	74	178	3	3	11	17	5002	2	17	0	0	3.0	
i 1	300.49397959183676	0.505	77	699	6	1	14	17	0	1	17	0	0	2.0358440348444966	
i 1	300.51404761904763	0.2525	69	178	7	5	16	0	5001	-1	0	0	0	2.004130294487196	
i 1	300.7431768707483	3.0300000000000002	72	178	7	5	5	1	5001	0	1	0	0	2.004130294487196	
i 1	300.7479931972789	3.0300000000000002	72	1111	6	5	8	0	5000	0	0	0	0	2.004130294487196	
i 1	300.9835442176871	0.2525	74	178	5	1	16	16	5002	1	16	0	0	2.0358440348444966	
i 1	301.23595238095237	2.525	77	699	4	24	10	17	0	2	17	0	0	3.0358440348444966	
i 1	301.2479931972789	2.525	77	178	6	1	16	17	5001	1	17	0	0	2.0358440348444966	
i 1	301.2608367346939	2.02	74	178	6	9	14	16	5001	2	16	0	0	2.0	
i 1	301.26485034013604	2.02	77	1111	4	2	11	16	5000	1	16	0	0	3.0	
i 1	301.4931768707483	1.2625	73	178	4	24	12	16	5001	1	16	0	0	4.0	
i 1	302.00040136054423	0.2525	69	178	5	5	10	0	5002	-1	0	0	0	2.004130294487196	
i 1	302.24959863945577	0.2525	69	178	5	5	2	1	5002	0	1	0	0	2.004130294487196	
i 1	302.50762585034016	0.2525	74	1111	6	1	8	17	5000	1	17	0	0	2.0358440348444966	
i 1	302.51404761904763	1.2625	77	178	5	24	7	17	5002	1	17	0	0	3.0358440348444966	
i 1	302.7335442176871	0.2525	74	178	5	1	1	16	5002	1	16	0	0	2.0358440348444966	
i 1	302.75361224489797	0.7575000000000001	69	178	5	5	12	0	5002	-1	0	0	0	2.004130294487196	
i 1	302.76485034013604	0.2525	69	699	6	5	1	0	0	0	0	0	0	2.004130294487196	
i 1	302.98193877551023	0.505	72	699	6	5	16	0	0	0	0	0	0	2.004130294487196	
i 1	302.9835442176871	0.7575000000000001	77	699	6	1	2	17	0	1	17	0	0	2.0358440348444966	
i 1	302.9835442176871	0.7575000000000001	77	699	5	3	2	17	0	2	17	0	0	3.0	
i 1	302.9843469387755	4.7975	74	178	3	4	16	16	5002	2	16	0	0	3.0	
i 1	303.50602040816324	0.2525	69	178	5	5	1	1	5002	0	1	0	0	2.004130294487196	
i 1	303.50762585034016	0.2525	69	178	7	5	12	0	5001	-1	0	0	0	2.004130294487196	
i 1	303.73193877551023	10.605	66	699	4	7	4	9	0	2	9	0	0	2.484788109882402	
i 1	303.73274149659863	10.605	66	699	5	15	11	6	0	2	6	0	0	2.3720094531185953	
i 1	303.73274149659863	2.02	69	178	6	5	1	1	5002	0	1	0	0	2.0	
i 1	303.73514965986396	9.09	61	178	4	19	3	9	5002	1	9	0	0	1.132643730431941	
i 1	303.73755782312924	2.2725	77	699	6	1	11	17	0	1	17	0	0	2.0014753984039526	
i 1	303.7391632653061	2.02	69	1111	6	5	3	1	5000	-1	1	0	0	2.0	
i 1	303.74157142857143	6.8175	61	699	5	15	14	6	0	2	6	0	0	2.3720094531185953	
i 1	303.74397959183676	9.09	66	1111	4	14	12	9	5000	2	9	0	0	3.2348711625754984	
i 1	303.74638775510203	10.605	61	699	4	13	1	6	0	1	6	0	0	0.9846220044962098	
i 1	303.74879591836736	6.8175	66	1111	5	17	3	9	5000	2	9	0	0	1.132643730431941	
i 1	303.75441496598637	0.2525	74	178	5	3	14	17	5002	2	17	0	0	3.0	
i 1	303.75602040816324	0.2525	77	178	6	1	7	17	5001	1	17	0	0	2.0014753984039526	
i 1	303.7568231292517	18.685	66	178	5	16	16	6	5001	1	6	0	0	3.5476597547464057	
i 1	303.75842857142857	0.2525	77	699	4	24	16	17	0	2	17	0	0	3.0014753984039526	
i 1	303.7608367346939	1.01	72	178	7	5	3	1	5001	0	1	0	0	2.0	
i 1	303.7616394557823	18.685	66	178	5	16	12	9	5001	2	9	0	0	3.5476597547464057	
i 1	303.76324489795917	4.2925	77	699	4	3	9	17	0	2	17	0	0	3.0	
i 1	303.76324489795917	18.685	61	178	5	18	15	9	5001	1	9	0	0	1.132643730431941	
i 1	303.76324489795917	3.535	76	178	3	24	10	17	5002	2	17	0	0	4.0	
i 1	303.76404761904763	10.605	66	699	5	17	1	6	0	1	6	0	0	1.132643730431941	
i 1	303.76404761904763	18.685	66	178	5	18	1	6	5001	2	6	0	0	1.132643730431941	
i 1	303.76485034013604	2.2725	77	178	5	24	16	17	5002	1	17	0	0	3.0014753984039526	
i 1	303.76485034013604	9.09	61	1111	5	14	8	6	5000	1	6	0	0	4.723310056374216	
i 1	303.76485034013604	9.09	61	1111	5	13	7	9	5000	2	9	0	0	1.1963591514907852	
i 1	303.76485034013604	9.09	61	1111	4	14	4	6	5000	1	6	0	0	3.2348711625754984	
i 1	303.7656530612245	1.01	72	1111	6	5	9	0	5000	0	0	0	0	2.0	
i 1	303.7696666666667	10.605	66	699	5	17	8	9	0	1	9	0	0	1.132643730431941	
i 1	303.98514965986396	0.2525	74	1111	6	1	7	17	5000	1	17	0	0	2.0014753984039526	
i 1	304.0028095238095	0.7575000000000001	77	178	6	1	4	16	5001	1	16	0	0	2.0014753984039526	
i 1	304.00521768707483	2.02	74	699	4	4	3	16	0	2	16	0	0	3.0	
i 1	304.01725850340137	2.525	74	178	6	9	1	17	5001	2	17	0	0	2.0	
i 1	304.26806122448977	0.2525	77	178	6	1	13	17	5001	1	17	0	0	2.0014753984039526	
i 1	304.50120408163264	0.505	77	699	4	24	11	17	0	2	17	0	0	3.0014753984039526	
i 1	304.73193877551023	0.2525	77	1111	6	1	7	16	5000	2	16	0	0	2.0014753984039526	
i 1	304.75842857142857	1.5150000000000001	69	178	5	5	9	0	5002	-1	0	0	0	2.0	
i 1	304.7696666666667	1.2625	72	699	6	5	12	0	0	0	0	0	0	2.0	
i 1	304.99076870748297	1.7675	74	178	5	1	8	16	5002	1	16	0	0	2.0014753984039526	
i 1	304.99478231292517	2.525	72	178	7	5	5	1	5001	0	1	0	0	2.0	
i 1	305.0028095238095	2.525	72	1111	6	5	15	0	5000	0	0	0	0	2.0	
i 1	305.00361224489797	2.525	73	178	4	24	9	16	5001	1	16	0	0	4.0	
i 1	305.00923129251703	0.505	73	699	4	24	11	17	0	2	17	0	0	4.0	
i 1	305.01404761904763	1.7675	74	1111	6	1	15	17	5000	1	17	0	0	2.0014753984039526	
i 1	305.4891632653061	0.2525	73	178	3	24	9	16	0	2	16	0	0	4.0	
i 1	305.74478231292517	2.2725	77	1111	6	1	1	16	5000	2	16	0	0	2.0014753984039526	
i 1	305.74638775510203	2.02	77	178	6	1	3	16	5001	1	16	0	0	2.0014753984039526	
i 1	305.76244217687076	0.505	73	699	4	24	14	17	0	2	17	0	0	4.0	
i 1	305.9803333333333	0.2525	77	1111	4	2	10	17	5000	1	17	0	0	3.0	
i 1	305.99959863945577	0.2525	69	178	6	5	10	1	5002	0	1	0	0	2.0	
i 1	306.23274149659863	0.2525	69	699	6	5	6	0	0	0	0	0	0	2.0	
i 1	306.25923129251703	0.2525	74	178	5	3	5	17	5002	2	17	0	0	3.0	
i 1	306.26324489795917	0.2525	76	178	3	24	6	17	0	1	17	0	0	4.0	
i 1	306.2664557823129	0.2525	69	178	7	5	5	0	5001	-1	0	0	0	2.0	
i 1	306.49478231292517	2.02	69	178	5	5	4	0	5002	-1	0	0	0	2.0	
i 1	306.5020068027211	2.02	72	699	6	5	12	0	0	0	0	0	0	2.0	
i 1	306.50361224489797	3.535	77	1111	4	2	12	17	5000	1	17	0	0	3.0	
i 1	306.50441496598637	0.2525	76	699	4	24	6	17	0	1	17	0	0	4.0	
i 1	306.7383605442177	0.2525	74	178	6	9	3	17	5001	2	17	0	0	2.0	
i 1	306.7431768707483	0.505	73	178	3	24	1	16	0	2	16	0	0	4.0	
i 1	306.7479931972789	2.525	77	178	5	24	13	17	5002	1	17	0	0	3.0014753984039526	
i 1	306.76725850340137	2.525	77	699	6	1	13	17	0	1	17	0	0	2.0014753984039526	
i 1	306.9883605442177	2.7775	74	178	5	3	9	17	5002	2	17	0	0	3.0	
i 1	307.26886394557823	0.505	73	699	4	24	8	17	0	2	17	0	0	4.0	
i 1	307.49397959183676	1.2625	69	178	6	5	14	1	5002	0	1	0	0	2.0	
i 1	307.49959863945577	1.01	69	1111	6	5	4	1	5000	-1	1	0	0	2.0	
i 1	307.50842857142857	5.3025	76	178	3	24	8	17	5002	2	17	0	0	4.0	
i 1	307.73193877551023	0.505	76	178	3	24	11	17	0	1	17	0	0	4.0	
i 1	307.73274149659863	3.7875	72	1111	6	5	1	0	5000	0	0	0	0	2.0	
i 1	307.73274149659863	4.04	72	178	7	5	3	1	5001	0	1	0	0	2.0	
i 1	307.7431768707483	0.2525	74	178	6	9	1	17	5001	2	17	0	0	2.0	
i 1	307.99478231292517	1.5150000000000001	74	178	6	9	5	16	5001	2	16	0	0	2.0	
i 1	308.00842857142857	1.5150000000000001	77	1111	4	2	1	16	5000	1	16	0	0	3.0	
i 1	308.01324489795917	0.2525	74	1111	6	1	3	17	5000	1	17	0	0	2.0014753984039526	
i 1	308.2335442176871	3.7875	77	1111	6	1	6	16	5000	2	16	0	0	2.0014753984039526	
i 1	308.24157142857143	3.7875	77	178	6	1	8	16	5001	1	16	0	0	2.0014753984039526	
i 1	308.49638775510203	0.505	76	178	3	24	6	17	0	1	17	0	0	4.0	
i 1	308.73274149659863	0.505	72	699	6	5	3	0	0	0	0	0	0	2.0	
i 1	308.73595238095237	1.7675	74	178	3	4	12	16	5002	2	16	0	0	3.0	
i 1	308.74558503401363	0.2525	69	1111	6	5	4	1	5000	-1	1	0	0	2.0	
i 1	308.75602040816324	3.0300000000000002	77	699	4	3	2	17	0	2	17	0	0	3.0	
i 1	308.75842857142857	0.2525	73	178	4	24	14	16	5001	1	16	0	0	4.0	
i 1	309.01886394557823	0.2525	69	699	6	5	8	0	0	0	0	0	0	2.0	
i 1	309.2479931972789	0.7575000000000001	69	178	6	5	8	1	5002	0	1	0	0	2.0	
i 1	309.25040136054423	0.505	74	1111	6	1	7	17	5000	1	17	0	0	2.0014753984039526	
i 1	309.25762585034016	0.505	76	178	3	24	1	17	0	1	17	0	0	4.0	
i 1	309.49558503401363	1.5150000000000001	73	178	4	24	14	16	5001	1	16	0	0	4.0	
i 1	309.73996598639457	0.2525	76	699	4	24	13	17	0	1	17	0	0	4.0	
i 1	309.74478231292517	0.2525	77	178	6	1	16	17	5001	1	17	0	0	2.0014753984039526	
i 1	309.74558503401363	0.2525	69	178	7	5	11	0	5001	-1	0	0	0	2.0	
i 1	309.74959863945577	0.505	77	1111	4	2	4	16	5000	1	16	0	0	3.0	
i 1	309.75842857142857	0.2525	77	699	4	24	16	17	0	2	17	0	0	3.0014753984039526	
i 1	310.00602040816324	0.505	74	699	4	4	1	16	0	2	16	0	0	3.0	
i 1	310.00923129251703	0.2525	74	178	5	1	2	16	5002	1	16	0	0	2.0014753984039526	
i 1	310.0108367346939	0.505	74	1111	6	1	6	17	5000	1	17	0	0	2.0014753984039526	
i 1	310.01404761904763	0.505	69	178	5	5	6	0	5002	-1	0	0	0	2.0	
i 1	310.01485034013604	0.2525	73	178	3	24	1	16	0	2	16	0	0	4.0	
i 1	310.2303333333333	0.2525	72	699	6	5	1	0	0	0	0	0	0	2.0	
i 1	310.24397959183676	0.2525	74	178	5	3	8	17	5002	2	17	0	0	3.0	
i 1	310.26244217687076	0.2525	73	699	4	24	8	17	0	2	17	0	0	4.0	
i 1	310.48996598639457	0.2525	74	178	6	9	13	17	5001	2	17	0	0	2.0	
i 1	310.49397959183676	0.505	73	178	3	24	1	16	0	1	16	0	0	4.0	
i 1	310.49478231292517	1.2625	74	178	5	4	3	16	5002	2	16	0	0	3.0	
i 1	310.4979931972789	2.2725	66	178	4	19	1	9	5002	2	9	0	0	1.132643730431941	
i 1	310.49959863945577	2.2725	66	178	5	12	5	6	5002	2	6	0	0	3.5476597547464057	
i 1	310.5028095238095	0.2525	77	178	5	24	1	17	5002	1	17	0	0	3.0014753984039526	
i 1	310.50361224489797	3.7875	61	699	5	15	11	6	0	2	6	0	0	2.3720094531185953	
i 1	310.50361224489797	2.2725	69	1111	6	5	15	1	5000	-1	1	0	0	2.0	
i 1	310.50441496598637	2.2725	69	178	6	5	15	1	5002	0	1	0	0	2.0	
i 1	310.5108367346939	0.2525	77	178	7	1	14	17	5001	1	17	0	0	2.0014753984039526	
i 1	310.73113605442177	0.2525	77	1111	4	2	14	17	5000	1	17	0	0	3.0	
i 1	310.74237414965984	0.2525	74	178	5	1	7	16	5002	1	16	0	0	2.0014753984039526	
i 1	310.75521768707483	0.2525	74	1111	6	1	14	17	5000	1	17	0	0	2.0014753984039526	
i 1	310.7656530612245	0.2525	77	1111	4	2	15	16	5000	1	16	0	0	3.0	
i 1	310.9803333333333	1.5150000000000001	74	699	4	4	9	16	0	2	16	0	0	3.0	
i 1	310.98274149659863	1.7675	77	178	7	1	14	17	5001	1	17	0	0	2.0014753984039526	
i 1	311.00923129251703	1.7675	77	699	4	24	2	17	0	2	17	0	0	3.0014753984039526	
i 1	311.01324489795917	1.5150000000000001	74	178	6	9	11	17	5001	2	17	0	0	2.0	
i 1	311.2616394557823	0.505	73	178	3	24	7	16	0	1	16	0	0	4.0	
i 1	311.51003401360543	4.2925	73	178	4	24	2	16	5001	1	16	0	0	4.0	
i 1	311.5196666666667	0.2525	69	178	7	5	8	0	5001	-1	0	0	0	2.0	
i 1	311.73755782312924	0.2525	73	699	4	24	3	16	0	2	16	0	0	4.0	
i 1	311.74478231292517	1.2625	77	699	6	1	15	17	0	1	17	0	0	2.0014753984039526	
i 1	311.75120408163264	0.2525	74	178	5	3	6	17	5002	2	17	0	0	3.0	
i 1	311.75521768707483	1.01	77	178	5	24	7	17	5002	1	17	0	0	3.0014753984039526	
i 1	311.76485034013604	0.2525	72	1111	6	5	1	0	5000	0	0	0	0	2.0	
i 1	311.9891632653061	1.01	77	699	4	3	8	17	0	2	17	0	0	3.0	
i 1	311.99157142857143	0.7575000000000001	69	178	6	5	16	0	5002	-1	0	0	0	2.0	
i 1	311.99558503401363	0.7575000000000001	74	178	5	4	11	16	5002	2	16	0	0	3.0	
i 1	311.99879591836736	0.2525	76	178	3	24	16	17	0	1	17	0	0	4.0	
i 1	312.00361224489797	1.01	72	699	6	5	3	0	0	0	0	0	0	2.0	
i 1	312.2335442176871	5.05	77	178	6	1	10	16	5001	1	16	0	0	2.0014753984039526	
i 1	312.23514965986396	1.2625	69	699	6	5	14	0	0	0	0	0	0	2.0	
i 1	312.23996598639457	0.505	77	1111	4	2	12	17	5000	1	17	0	0	3.0	
i 1	312.26806122448977	0.505	74	1111	6	1	5	17	5000	1	17	0	0	2.0014753984039526	
i 1	312.26886394557823	2.2725	74	178	6	9	10	16	5001	2	16	0	0	2.0	
i 1	312.49076870748297	3.2825	72	178	7	5	16	1	5001	0	1	0	0	2.0	
i 1	312.7335442176871	1.7675	69	903	6	5	14	1	0	-1	1	0	0	2.0	
i 1	312.7431768707483	9.8475	61	903	5	14	3	9	0	1	9	0	0	4.723310056374216	
i 1	312.74638775510203	9.8475	61	903	4	14	5	6	0	1	6	0	0	3.2348711625754984	
i 1	312.74879591836736	9.8475	66	903	5	13	4	9	0	1	9	0	0	1.1963591514907852	
i 1	312.7568231292517	9.8475	66	178	4	12	9	6	5002	2	6	0	0	3.5476597547464057	
i 1	312.76003401360543	9.8475	61	903	4	14	12	6	0	1	6	0	0	3.2348711625754984	
i 1	312.7608367346939	0.2525	77	178	4	24	6	17	5002	1	17	0	0	3.0014753984039526	
i 1	312.76485034013604	9.8475	61	178	3	19	7	9	5002	1	9	0	0	1.132643730431941	
i 1	312.7656530612245	0.7575000000000001	69	178	5	5	14	0	5002	-1	0	0	0	2.0	
i 1	312.7664557823129	1.2625	77	903	6	1	12	17	0	1	17	0	0	2.0014753984039526	
i 1	312.76806122448977	9.8475	66	178	3	19	16	9	5002	2	9	0	0	1.132643730431941	
i 1	312.76886394557823	2.02	74	903	4	2	8	16	0	1	16	0	0	3.0	
i 1	312.7696666666667	0.2525	74	178	4	4	4	16	5002	2	16	0	0	3.0	
i 1	312.7696666666667	3.7875	76	178	2	24	10	17	5002	2	17	0	0	4.0	
i 1	312.99076870748297	0.2525	73	699	4	24	8	17	0	2	17	0	0	4.0	
i 1	313.0020068027211	1.01	74	903	4	2	13	17	0	2	17	0	0	3.0	
i 1	313.00521768707483	4.2925	74	903	6	1	13	16	0	2	16	0	0	2.0014753984039526	
i 1	313.25521768707483	0.7575000000000001	74	178	6	9	3	17	5001	2	17	0	0	2.0	
i 1	313.26244217687076	2.7775	73	178	2	24	16	17	0	1	17	0	0	4.0	
i 1	313.50923129251703	1.2625	77	178	7	1	5	17	5001	1	17	0	0	2.0014753984039526	
i 1	313.51244217687076	0.505	72	699	6	5	2	0	0	0	0	0	0	2.0	
i 1	313.51886394557823	0.2525	72	903	6	5	16	0	0	0	0	0	0	2.0	
i 1	313.76324489795917	0.2525	69	178	5	5	3	1	5002	0	1	0	0	2.0	
i 1	313.98675510204083	0.2525	77	699	4	3	11	17	0	2	17	0	0	3.0	
i 1	313.9883605442177	2.02	72	903	6	5	7	0	0	0	0	0	0	2.0	
i 1	313.99157142857143	1.2625	74	178	4	4	14	16	5002	2	16	0	0	3.0	
i 1	314.23274149659863	3.0300000000000002	61	587	5	15	13	6	0	2	6	0	0	2.3720094531185953	
i 1	314.24397959183676	3.0300000000000002	61	587	5	17	12	6	0	1	6	0	0	1.132643730431941	
i 1	314.24879591836736	1.01	77	587	4	3	9	17	0	2	17	0	0	3.0	
i 1	314.2608367346939	8.3325	61	587	5	15	7	9	0	1	9	0	0	2.3720094531185953	
i 1	314.26324489795917	0.505	69	587	6	5	16	1	0	0	1	0	0	2.0	
i 1	314.26324489795917	8.3325	66	587	4	7	15	6	0	2	6	0	0	2.484788109882402	
i 1	314.26806122448977	8.3325	66	587	5	17	13	6	0	2	6	0	0	1.132643730431941	
i 1	314.26806122448977	8.3325	61	587	4	13	11	6	0	1	6	0	0	0.9846220044962098	
i 1	314.48274149659863	0.2525	74	178	4	1	7	16	5002	1	16	0	0	2.0014753984039526	
i 1	314.7335442176871	1.5150000000000001	77	587	4	4	10	16	0	2	16	0	0	3.0	
i 1	314.73595238095237	0.505	69	178	7	5	12	0	5001	-1	0	0	0	2.0	
i 1	314.7383605442177	0.505	69	178	5	5	13	0	5002	-1	0	0	0	2.0	
i 1	314.7471904761905	0.2525	74	587	4	24	4	16	0	1	16	0	0	3.0014753984039526	
i 1	314.76324489795917	1.5150000000000001	74	178	6	9	14	17	5001	2	17	0	0	2.0	
i 1	314.9803333333333	0.2525	77	903	6	1	4	17	0	1	17	0	0	2.0014753984039526	
i 1	315.0196666666667	0.505	77	178	7	1	3	17	5001	1	17	0	0	2.0014753984039526	
i 1	315.23274149659863	0.505	74	903	4	2	2	17	0	2	17	0	0	3.0	
i 1	315.23514965986396	2.2725	69	903	6	5	11	1	0	-1	1	0	0	2.0	
i 1	315.2608367346939	2.02	69	178	5	5	1	1	5002	0	1	0	0	2.0	
i 1	315.5116394557823	0.2525	74	178	4	1	3	16	5002	1	16	0	0	2.0014753984039526	
i 1	315.51485034013604	0.2525	77	903	6	1	13	17	0	1	17	0	0	2.0014753984039526	
i 1	315.74237414965984	0.505	77	587	6	1	1	17	0	2	17	0	0	2.0014753984039526	
i 1	315.74558503401363	0.2525	69	178	5	5	14	0	5002	-1	0	0	0	2.0	
i 1	315.75602040816324	2.02	74	178	4	4	8	16	5002	2	16	0	0	3.0	
i 1	315.76725850340137	2.2725	77	587	4	3	4	17	0	2	17	0	0	3.0	
i 1	315.9979931972789	0.2525	73	587	4	24	6	17	0	2	17	0	0	4.0	
i 1	316.00521768707483	0.2525	69	178	7	5	15	0	5001	-1	0	0	0	2.0	
i 1	316.0108367346939	3.7875	73	178	4	24	10	16	5001	1	16	0	0	4.0	
i 1	316.2303333333333	1.5150000000000001	76	178	2	24	15	16	0	2	16	0	0	4.0	
i 1	316.2343469387755	0.2525	74	178	4	1	2	16	5002	1	16	0	0	2.0014753984039526	
i 1	316.23514965986396	0.2525	74	178	4	3	11	17	5002	2	17	0	0	3.0	
i 1	316.24157142857143	0.2525	72	903	6	5	2	0	0	0	0	0	0	2.0	
i 1	316.25441496598637	0.2525	77	178	7	1	4	17	5001	1	17	0	0	2.0014753984039526	
i 1	316.48595238095237	1.7675	69	587	6	5	15	0	0	0	0	0	0	2.0	
i 1	316.5068231292517	0.2525	74	178	6	9	5	16	5001	2	16	0	0	2.0	
i 1	316.51725850340137	0.2525	77	587	6	1	1	17	0	2	17	0	0	2.0014753984039526	
i 1	316.73113605442177	3.0300000000000002	74	587	4	24	4	16	0	1	16	0	0	3.0014753984039526	
i 1	316.74558503401363	0.2525	76	178	2	24	1	17	5002	2	17	0	0	4.0	
i 1	316.75441496598637	3.0300000000000002	77	178	7	1	9	17	5001	1	17	0	0	2.0014753984039526	
i 1	316.76003401360543	1.5150000000000001	69	178	5	5	4	0	5002	-1	0	0	0	2.0	
i 1	316.76725850340137	0.2525	77	587	4	4	6	16	0	2	16	0	0	3.0	
i 1	317.01244217687076	2.2725	74	903	4	2	8	17	0	2	17	0	0	3.0	
i 1	317.23113605442177	0.2525	74	903	5	1	15	16	0	2	16	0	0	2.0014753984039526	
i 1	317.2391632653061	1.5150000000000001	77	178	4	24	9	17	5002	1	17	0	0	3.0014753984039526	
i 1	317.2431768707483	5.3025	66	178	4	12	2	6	5002	2	6	0	0	3.5476597547464057	
i 1	317.24558503401363	1.5150000000000001	77	587	6	1	7	17	0	2	17	0	0	2.0014753984039526	
i 1	317.2528095238095	0.2525	77	178	7	1	14	16	5001	1	16	0	0	2.0014753984039526	
i 1	317.26244217687076	1.7675	74	178	6	9	11	16	5001	2	16	0	0	2.0	
i 1	317.26324489795917	5.3025	61	587	5	15	7	6	0	2	6	0	0	2.3720094531185953	
i 1	317.48113605442177	0.2525	69	587	6	5	1	1	0	0	1	0	0	2.0	
i 1	317.74157142857143	0.2525	74	178	4	9	10	17	5001	2	17	0	0	2.0	
i 1	317.7479931972789	0.2525	76	587	4	24	9	16	0	2	16	0	0	4.0	
i 1	317.75842857142857	0.7575000000000001	72	903	6	5	9	0	0	0	0	0	0	2.0	
i 1	317.76003401360543	0.7575000000000001	72	178	7	5	1	1	5001	0	1	0	0	2.0	
i 1	317.99157142857143	0.7575000000000001	76	178	2	24	13	17	5002	2	17	0	0	4.0	
i 1	317.9971904761905	2.02	69	178	7	5	12	0	5001	-1	0	0	0	2.0	
i 1	317.99959863945577	2.02	69	587	6	5	2	1	0	0	1	0	0	2.0	
i 1	317.99959863945577	0.2525	76	178	2	24	2	16	0	1	16	0	0	4.0	
i 1	318.0116394557823	0.2525	74	178	4	4	16	16	5002	2	16	0	0	3.0	
i 1	318.26003401360543	1.5150000000000001	74	903	4	2	8	16	0	1	16	0	0	3.0	
i 1	318.49879591836736	1.5150000000000001	74	178	4	3	13	17	5002	2	17	0	0	3.0	
i 1	318.51886394557823	0.505	69	178	5	5	5	1	5002	0	1	0	0	2.0	
i 1	318.76725850340137	0.2525	77	903	6	1	16	17	0	1	17	0	0	2.0014753984039526	
i 1	318.98113605442177	0.2525	77	178	4	24	12	17	5002	1	17	0	0	3.0014753984039526	
i 1	319.01244217687076	0.2525	69	903	6	5	4	1	0	-1	1	0	0	2.0	
i 1	319.01806122448977	1.01	76	178	2	24	10	17	5002	2	17	0	0	4.0	
i 1	319.2431768707483	2.2725	74	178	4	4	8	16	5002	2	16	0	0	3.0	
i 1	319.24638775510203	2.2725	77	587	4	3	1	17	0	2	17	0	0	3.0	
i 1	319.25441496598637	2.02	77	903	6	1	1	17	0	1	17	0	0	2.0014753984039526	
i 1	319.26003401360543	2.02	74	178	4	1	8	16	5002	1	16	0	0	2.0014753984039526	
i 1	319.2664557823129	0.2525	69	178	5	5	4	0	5002	-1	0	0	0	2.0	
i 1	319.2696666666667	0.2525	73	587	4	24	8	16	0	2	16	0	0	4.0	
i 1	319.4803333333333	1.7675	69	903	6	5	14	1	0	-1	1	0	0	2.0	
i 1	319.50040136054423	1.5150000000000001	69	178	5	5	14	1	5002	0	1	0	0	2.0	
i 1	319.75762585034016	0.2525	77	587	6	1	11	17	0	2	17	0	0	2.0014753984039526	
i 1	319.99879591836736	0.2525	69	587	6	5	3	0	0	0	0	0	0	2.0	
i 1	320.0156530612245	0.2525	74	903	5	1	2	16	0	2	16	0	0	2.0014753984039526	
i 1	320.0164557823129	0.2525	74	178	6	9	15	16	5001	2	16	0	0	2.0	
i 1	320.23514965986396	2.02	73	178	4	24	1	16	5001	1	16	0	0	4.0	
i 1	320.2383605442177	2.2725	76	178	2	24	2	17	5002	2	17	0	0	4.0	
i 1	320.25040136054423	0.7575000000000001	73	178	2	24	15	17	0	1	17	0	0	4.0	
i 1	320.2608367346939	0.2525	77	178	7	1	3	17	5001	1	17	0	0	2.0014753984039526	
i 1	320.2608367346939	2.02	72	178	7	5	15	1	5001	0	1	0	0	2.0	
i 1	320.26886394557823	0.2525	74	903	4	2	12	16	0	1	16	0	0	3.0	
i 1	320.4979931972789	2.02	72	903	6	5	3	0	0	0	0	0	0	2.0	
i 1	320.5068231292517	2.02	74	903	5	1	10	16	0	2	16	0	0	2.0014753984039526	
i 1	320.50762585034016	0.2525	74	178	4	3	6	17	5002	2	17	0	0	3.0	
i 1	320.75361224489797	1.5150000000000001	77	587	4	4	5	16	0	2	16	0	0	3.0	
i 1	320.7608367346939	1.5150000000000001	77	178	7	1	1	16	5001	1	16	0	0	2.0014753984039526	
i 1	320.99237414965984	1.2625	74	178	4	9	7	17	5001	2	17	0	0	2.0	
i 1	321.01003401360543	0.2525	76	587	4	24	7	17	0	2	17	0	0	4.0	
i 1	321.23193877551023	0.2525	74	587	4	24	16	16	0	1	16	0	0	3.0014753984039526	
i 1	321.2391632653061	0.2525	69	178	5	5	1	1	5002	0	1	0	0	2.0	
i 1	321.49076870748297	0.2525	74	903	4	2	3	16	0	1	16	0	0	3.0	
i 1	321.50120408163264	0.2525	74	178	4	1	14	16	5002	1	16	0	0	2.0014753984039526	
i 1	321.50602040816324	0.2525	69	178	7	5	15	0	5001	-1	0	0	0	2.0	
i 1	321.51806122448977	0.2525	76	587	4	24	1	17	0	1	17	0	0	4.0	
i 1	321.7335442176871	0.7575000000000001	76	178	2	24	2	17	0	1	17	0	0	4.0	
i 1	321.73514965986396	0.505	77	903	6	1	6	17	0	1	17	0	0	2.0014753984039526	
i 1	321.7383605442177	0.7575000000000001	77	587	4	3	3	17	0	2	17	0	0	3.0	
i 1	321.7528095238095	0.2525	69	587	6	5	15	0	0	0	0	0	0	2.0	
i 1	321.7696666666667	0.7575000000000001	74	178	4	4	13	16	5002	2	16	0	0	3.0	
i 1	321.99157142857143	0.505	69	903	6	5	9	1	0	-1	1	0	0	2.0	
i 1	322.23274149659863	0.2525	66	1169	4	18	7	9	0	2	9	0	0	1.132643730431941	
i 1	322.2343469387755	0.2525	61	1169	4	18	5	6	0	1	6	0	0	1.132643730431941	
i 1	322.2383605442177	0.2525	77	1169	6	1	12	17	0	2	17	0	0	2.0014753984039526	
i 1	322.24157142857143	0.2525	61	1169	4	16	15	9	0	1	9	0	0	3.5476597547464057	
i 1	322.24558503401363	0.2525	74	903	4	2	4	17	0	2	17	0	0	3.0	
i 1	322.25040136054423	0.2525	66	1169	4	16	16	9	0	1	9	0	0	3.5476597547464057	
i 1	322.25762585034016	0.2525	77	1169	6	1	10	16	0	2	16	0	0	2.0014753984039526	
i 1	322.26404761904763	0.2525	77	1169	4	9	15	16	0	2	16	0	0	2.0	
i 1	322.26725850340137	0.2525	76	1169	4	24	12	16	0	2	16	0	0	4.0	
i 1	322.26806122448977	0.2525	69	1169	6	5	3	0	0	-1	0	0	0	2.0	
i 1	322.48113605442177	0.2525	74	204	4	3	4	17	0	1	17	0	0	3.0	
i 1	322.48113605442177	1.2625	69	1088	6	5	5	0	0	0	0	0	0	2.0	
i 1	322.48274149659863	1.5150000000000001	74	702	5	1	9	17	0	1	17	0	0	2.0014753984039526	
i 1	322.4835442176871	54.2875	61	204	5	15	14	6	0	2	6	0	0	2.3720094531185953	
i 1	322.4843469387755	54.2875	61	702	5	14	7	9	0	1	9	0	0	4.723310056374216	
i 1	322.4843469387755	54.2875	66	204	5	15	3	9	0	2	9	0	0	2.3720094531185953	
i 1	322.48755782312924	8.3325	66	1088	4	18	7	6	0	2	6	0	0	1.132643730431941	
i 1	322.48755782312924	0.2525	69	702	6	5	10	0	0	0	0	0	0	2.0	
i 1	322.48996598639457	42.42	61	204	4	13	16	9	0	1	9	0	0	0.9846220044962098	
i 1	322.49076870748297	0.2525	73	702	2	24	15	16	0	2	16	0	0	4.0	
i 1	322.4931768707483	0.2525	74	1088	6	1	16	16	0	2	16	0	0	2.0014753984039526	
i 1	322.49397959183676	1.2625	69	702	6	5	16	0	0	-1	0	0	0	2.0	
i 1	322.4971904761905	3.0300000000000002	76	702	2	24	16	17	0	1	17	0	0	4.0	
i 1	322.4979931972789	1.5150000000000001	61	204	5	17	8	9	0	1	9	0	0	1.132643730431941	
i 1	322.5028095238095	1.01	77	1088	3	9	1	16	0	2	16	0	0	2.0	
i 1	322.5068231292517	54.2875	66	702	5	13	1	6	0	1	6	0	0	1.1963591514907852	
i 1	322.50762585034016	1.5150000000000001	61	1088	4	16	16	6	0	2	6	0	0	3.5476597547464057	
i 1	322.50842857142857	21.9675	61	702	3	19	3	9	0	2	9	0	0	1.132643730431941	
i 1	322.50842857142857	0.505	73	1088	3	24	12	16	0	2	16	0	0	4.0	
i 1	322.51003401360543	0.2525	74	702	4	4	2	17	0	1	17	0	0	3.0	
i 1	322.5108367346939	8.3325	66	1088	4	16	9	9	0	2	9	0	0	3.5476597547464057	
i 1	322.5108367346939	1.2625	77	702	4	2	3	16	0	2	16	0	0	3.0	
i 1	322.5108367346939	28.785	61	702	4	14	15	9	0	1	9	0	0	3.2348711625754984	
i 1	322.5116394557823	49.2375	66	204	4	7	8	9	0	2	9	0	0	2.484788109882402	
i 1	322.51485034013604	15.15	66	1088	4	18	9	6	0	2	6	0	0	1.132643730431941	
i 1	322.51485034013604	28.785	66	702	3	19	3	6	0	2	6	0	0	1.132643730431941	
i 1	322.5156530612245	21.9675	61	702	4	12	1	6	0	2	6	0	0	3.5476597547464057	
i 1	322.5156530612245	35.6025	66	702	4	14	10	6	0	2	6	0	0	3.2348711625754984	
i 1	322.5164557823129	15.15	66	702	4	12	15	9	0	2	9	0	0	3.5476597547464057	
i 1	322.51886394557823	2.2725	77	1088	6	1	6	17	0	2	17	0	0	2.0014753984039526	
i 1	322.7391632653061	0.2525	72	204	7	5	3	1	0	-1	1	0	0	2.0	
i 1	322.7391632653061	0.2525	73	204	4	24	3	16	0	2	16	0	0	4.0	
i 1	322.7479931972789	0.2525	74	702	4	3	15	17	0	1	17	0	0	3.0	
i 1	322.98595238095237	1.01	77	1088	5	9	8	16	0	2	16	0	0	2.0	
i 1	322.99478231292517	0.2525	74	702	4	1	14	17	0	1	17	0	0	2.0014753984039526	
i 1	323.0108367346939	1.7675	74	702	4	2	5	17	0	2	17	0	0	3.0	
i 1	323.0116394557823	1.2625	72	702	5	5	6	0	0	-1	0	0	0	2.0	
i 1	323.24237414965984	1.2625	69	204	7	5	4	1	0	-1	1	0	0	2.0	
i 1	323.25762585034016	1.2625	73	1088	3	24	1	16	0	2	16	0	0	4.0	
i 1	323.2696666666667	0.505	74	702	6	1	10	16	0	1	16	0	0	2.0014753984039526	
i 1	323.5156530612245	0.2525	76	204	4	24	5	17	0	2	17	0	0	4.0	
i 1	323.7431768707483	4.2925	74	702	4	3	6	17	0	1	17	0	0	3.0	
i 1	323.74478231292517	0.2525	69	702	6	5	14	0	0	0	0	0	0	2.0	
i 1	323.74638775510203	2.525	72	1088	6	5	12	1	0	-1	1	0	0	2.0	
i 1	323.75040136054423	0.2525	77	204	5	24	1	17	0	1	17	0	0	3.0014753984039526	
i 1	323.7656530612245	0.505	76	702	2	24	14	16	0	1	16	0	0	4.0	
i 1	323.98514965986396	4.2925	74	204	4	3	16	17	0	1	17	0	0	3.0	
i 1	323.98996598639457	0.505	77	1088	3	9	15	16	0	2	16	0	0	2.0	
i 1	324.0108367346939	1.7675	69	702	4	5	13	0	0	0	0	0	0	2.0	
i 1	324.0116394557823	0.2525	74	702	5	1	12	17	0	1	17	0	0	2.0014753984039526	
i 1	324.01404761904763	0.7575000000000001	74	702	6	1	12	17	0	1	17	0	0	2.0014753984039526	
i 1	324.0156530612245	52.7725	61	1088	4	16	7	6	0	2	6	0	0	3.5476597547464057	
i 1	324.2383605442177	1.2625	77	702	4	24	15	16	0	1	16	0	0	3.0014753984039526	
i 1	324.2471904761905	3.7875	77	204	5	24	2	17	0	1	17	0	0	3.0014753984039526	
i 1	324.25762585034016	1.2625	76	204	4	24	16	17	0	1	17	0	0	4.0	
i 1	324.48113605442177	0.505	72	204	7	5	16	1	0	-1	1	0	0	2.0	
i 1	324.74157142857143	0.2525	74	204	4	4	11	16	0	1	16	0	0	3.0	
i 1	324.76003401360543	0.2525	74	1088	6	1	13	16	0	2	16	0	0	2.0014753984039526	
i 1	324.99157142857143	0.2525	69	1088	6	5	6	0	0	0	0	0	0	2.0	
i 1	324.9931768707483	0.2525	74	702	4	2	8	17	0	2	17	0	0	3.0	
i 1	324.99638775510203	0.7575000000000001	73	1088	3	24	3	16	0	2	16	0	0	4.0	
i 1	325.0068231292517	1.5150000000000001	74	204	7	1	1	16	0	2	16	0	0	2.0014753984039526	
i 1	325.00842857142857	1.5150000000000001	74	702	5	1	16	17	0	1	17	0	0	2.0014753984039526	
i 1	325.23675510204083	1.5150000000000001	69	702	5	5	9	0	0	-1	0	0	0	2.0	
i 1	325.23755782312924	1.5150000000000001	72	204	7	5	3	1	0	-1	1	0	0	2.0	
i 1	325.26404761904763	0.2525	77	1088	3	9	1	16	0	2	16	0	0	2.0	
i 1	325.4803333333333	0.7575000000000001	74	702	4	4	1	17	0	1	17	0	0	3.0	
i 1	325.4843469387755	0.7575000000000001	74	204	4	4	8	16	0	1	16	0	0	3.0	
i 1	326.0156530612245	2.02	77	702	4	24	9	16	0	1	16	0	0	3.0014753984039526	
i 1	326.2479931972789	0.505	77	702	4	2	16	16	0	2	16	0	0	3.0	
i 1	326.2656530612245	0.7575000000000001	69	1088	6	5	6	0	0	0	0	0	0	2.0	
i 1	326.2696666666667	0.7575000000000001	69	702	6	5	11	0	0	-1	0	0	0	2.0	
i 1	326.48193877551023	3.535	72	1088	6	5	16	1	0	-1	1	0	0	2.0	
i 1	326.49558503401363	0.2525	76	702	2	24	2	16	0	2	16	0	0	4.0	
i 1	326.49558503401363	1.01	76	702	2	24	14	17	0	1	17	0	0	4.0	
i 1	326.5028095238095	3.7875	69	702	4	5	13	0	0	0	0	0	0	2.0	
i 1	326.51324489795917	0.2525	74	702	5	1	14	16	0	1	16	0	0	2.0014753984039526	
i 1	326.74397959183676	0.2525	74	702	4	2	13	17	0	2	17	0	0	3.0	
i 1	326.7520068027211	0.505	76	204	4	24	14	16	0	2	16	0	0	4.0	
i 1	326.76404761904763	0.2525	74	702	5	1	5	17	0	1	17	0	0	2.0014753984039526	
i 1	327.00441496598637	0.2525	72	702	5	5	4	0	0	-1	0	0	0	2.0	
i 1	327.00842857142857	0.505	77	1088	6	1	6	17	0	2	17	0	0	2.0014753984039526	
i 1	327.01244217687076	0.2525	77	702	4	2	9	16	0	2	16	0	0	3.0	
i 1	327.24959863945577	0.2525	76	702	2	24	16	16	0	2	16	0	0	4.0	
i 1	327.25361224489797	0.2525	69	702	5	5	11	0	0	-1	0	0	0	2.0	
i 1	327.25521768707483	0.2525	77	1088	3	9	15	16	0	2	16	0	0	2.0	
i 1	327.48193877551023	0.505	72	702	5	5	8	0	0	-1	0	0	0	2.0	
i 1	327.49558503401363	2.02	74	1088	6	1	7	16	0	2	16	0	0	2.0014753984039526	
i 1	327.5020068027211	0.2525	73	1088	3	24	12	16	0	2	16	0	0	4.0	
i 1	327.50923129251703	2.2725	77	702	4	2	11	16	0	2	16	0	0	3.0	
i 1	327.51324489795917	2.2725	74	702	5	1	11	16	0	1	16	0	0	2.0014753984039526	
i 1	327.51485034013604	2.525	77	1088	3	9	14	16	0	2	16	0	0	2.0	
i 1	327.75842857142857	0.505	76	702	2	24	3	16	0	2	16	0	0	4.0	
i 1	327.9803333333333	0.2525	77	1088	6	1	10	17	0	2	17	0	0	2.0014753984039526	
i 1	328.0196666666667	0.2525	72	204	7	5	11	1	0	-1	1	0	0	2.0	
i 1	328.24157142857143	0.2525	69	1088	6	5	14	0	0	0	0	0	0	2.0	
i 1	328.2608367346939	0.505	74	702	5	1	10	17	0	1	17	0	0	2.0014753984039526	
i 1	328.26725850340137	0.2525	77	1088	3	9	14	16	0	2	16	0	0	2.0	
i 1	328.4971904761905	2.02	74	702	4	2	13	17	0	2	17	0	0	3.0	
i 1	328.51324489795917	0.2525	69	702	6	5	5	0	0	-1	0	0	0	2.0	
i 1	328.74558503401363	0.2525	76	702	2	24	12	17	0	1	17	0	0	4.0	
i 1	328.7616394557823	0.2525	77	702	4	24	14	16	0	1	16	0	0	3.0014753984039526	
i 1	328.9803333333333	0.2525	69	702	5	5	5	0	0	-1	0	0	0	2.0	
i 1	328.9931768707483	1.7675	74	702	6	1	1	17	0	1	17	0	0	2.0014753984039526	
i 1	328.9971904761905	1.7675	77	1088	6	1	14	17	0	2	17	0	0	2.0014753984039526	
i 1	329.25602040816324	1.7675	77	1088	3	9	3	16	0	2	16	0	0	2.0	
i 1	329.26725850340137	2.525	69	1088	6	5	6	0	0	0	0	0	0	2.0	
i 1	329.4835442176871	0.7575000000000001	73	1088	3	24	13	16	0	2	16	0	0	4.0	
i 1	329.4843469387755	1.2625	69	702	6	5	9	0	0	-1	0	0	0	2.0	
i 1	329.5116394557823	2.02	76	702	2	24	6	17	0	1	17	0	0	4.0	
i 1	329.7479931972789	0.2525	74	702	5	1	12	17	0	1	17	0	0	2.0014753984039526	
i 1	329.98193877551023	0.7575000000000001	74	702	4	3	12	17	0	1	17	0	0	3.0	
i 1	329.9835442176871	1.7675	74	204	4	3	8	17	0	1	17	0	0	3.0	
i 1	330.0068231292517	0.2525	74	1088	6	1	1	16	0	2	16	0	0	2.0014753984039526	
i 1	330.2343469387755	0.2525	69	204	7	5	7	1	0	-1	1	0	0	2.0	
i 1	330.25521768707483	0.505	74	204	7	1	14	16	0	2	16	0	0	2.0014753984039526	
i 1	330.2696666666667	1.5150000000000001	74	702	5	1	6	17	0	1	17	0	0	2.0014753984039526	
i 1	330.48193877551023	0.2525	72	1088	6	5	7	1	0	-1	1	0	0	2.0	
i 1	330.74076870748297	0.2525	69	702	4	5	1	0	0	0	0	0	0	2.0	
i 1	330.74157142857143	1.01	74	204	5	1	16	16	0	2	16	0	0	2.0014753984039526	
i 1	330.7471904761905	0.2525	74	702	6	1	15	16	0	1	16	0	0	2.0014753984039526	
i 1	330.75441496598637	1.01	74	702	2	3	10	17	0	1	17	0	0	3.0	
i 1	330.75762585034016	1.01	69	702	4	5	9	0	0	-1	0	0	0	2.0	
i 1	330.76324489795917	45.955	66	1088	4	16	15	9	0	2	9	0	0	3.5476597547464057	
i 1	330.76725850340137	0.7575000000000001	73	1088	3	24	9	16	0	2	16	0	0	4.0	
i 1	330.99237414965984	1.7675	74	702	4	4	10	17	0	1	17	0	0	3.0	
i 1	331.00762585034016	1.5150000000000001	69	204	7	5	1	1	0	-1	1	0	0	2.0	
i 1	331.00923129251703	2.2725	77	1088	6	1	5	17	0	2	17	0	0	2.0014753984039526	
i 1	331.01003401360543	1.5150000000000001	72	702	5	5	4	0	0	-1	0	0	0	2.0	
i 1	331.01806122448977	2.2725	74	702	6	1	10	17	0	1	17	0	0	2.0014753984039526	
i 1	331.23274149659863	1.5150000000000001	74	204	4	4	13	16	0	1	16	0	0	3.0	
i 1	331.74959863945577	0.2525	74	702	6	1	6	16	0	1	16	0	0	2.0014753984039526	
i 1	331.75602040816324	0.2525	77	702	6	2	6	16	0	2	16	0	0	3.0	
i 1	331.7568231292517	0.2525	77	1088	3	9	4	16	0	2	16	0	0	2.0	
i 1	331.76003401360543	0.2525	74	1088	6	1	5	16	0	2	16	0	0	2.0014753984039526	
i 1	331.7664557823129	0.2525	72	204	7	5	10	1	0	-1	1	0	0	2.0	
i 1	331.98113605442177	0.505	77	204	5	24	5	17	0	1	17	0	0	3.0014753984039526	
i 1	331.98514965986396	2.525	74	702	2	3	4	17	0	1	17	0	0	3.0	
i 1	331.9931768707483	0.7575000000000001	69	702	4	5	3	0	0	0	0	0	0	2.0	
i 1	332.00120408163264	0.7575000000000001	72	1088	6	5	4	1	0	-1	1	0	0	2.0	
i 1	332.01324489795917	2.525	74	204	4	3	15	17	0	1	17	0	0	3.0	
i 1	332.24397959183676	0.2525	74	702	5	1	1	17	0	1	17	0	0	2.0014753984039526	
i 1	332.24558503401363	2.02	69	702	5	5	1	0	0	-1	0	0	0	2.0	
i 1	332.2479931972789	2.02	72	204	7	5	9	1	0	-1	1	0	0	2.0	
i 1	332.25120408163264	1.01	73	1088	3	24	9	16	0	2	16	0	0	4.0	
i 1	332.4931768707483	0.7575000000000001	73	702	2	24	13	17	0	1	17	0	0	4.0	
i 1	332.51725850340137	0.2525	74	1088	6	1	14	16	0	2	16	0	0	2.0014753984039526	
i 1	332.7391632653061	0.2525	74	702	4	2	11	17	0	2	17	0	0	3.0	
i 1	332.7431768707483	2.02	77	204	5	24	7	17	0	1	17	0	0	3.0014753984039526	
i 1	332.7431768707483	0.2525	77	702	6	2	4	16	0	2	16	0	0	3.0	
i 1	332.7520068027211	2.02	77	702	4	24	6	16	0	1	16	0	0	3.0014753984039526	
i 1	332.76003401360543	0.505	72	702	5	5	13	0	0	-1	0	0	0	2.0	
i 1	333.0068231292517	2.2725	77	1088	3	9	4	16	0	2	16	0	0	2.0	
i 1	333.24879591836736	0.2525	72	1088	6	5	5	1	0	-1	1	0	0	2.0	
i 1	333.26003401360543	0.2525	74	1088	6	1	5	16	0	2	16	0	0	2.0014753984039526	
i 1	333.2616394557823	0.2525	74	702	5	1	12	17	0	1	17	0	0	2.0014753984039526	
i 1	333.49237414965984	0.2525	69	702	4	5	7	0	0	0	0	0	0	2.0	
i 1	333.5020068027211	1.5150000000000001	73	1088	3	24	10	16	0	2	16	0	0	4.0	
i 1	333.5116394557823	0.2525	74	702	6	1	16	16	0	1	16	0	0	2.0014753984039526	
i 1	333.5116394557823	0.2525	74	702	4	4	4	17	0	1	17	0	0	3.0	
i 1	333.7343469387755	0.2525	74	204	5	1	2	16	0	2	16	0	0	2.0014753984039526	
i 1	333.74478231292517	1.2625	76	702	2	24	2	17	0	1	17	0	0	4.0	
i 1	333.7568231292517	1.5150000000000001	77	702	6	2	12	16	0	2	16	0	0	3.0	
i 1	333.7608367346939	1.5150000000000001	69	1088	6	5	1	0	0	0	0	0	0	2.0	
i 1	333.7616394557823	1.5150000000000001	69	702	4	5	15	0	0	-1	0	0	0	2.0	
i 1	333.99478231292517	2.2725	74	702	5	1	16	17	0	1	17	0	0	2.0014753984039526	
i 1	334.23755782312924	2.02	74	204	5	1	6	16	0	2	16	0	0	2.0014753984039526	
i 1	334.2391632653061	0.2525	69	702	4	5	12	0	0	0	0	0	0	2.0	
i 1	334.4891632653061	0.2525	74	702	4	4	15	17	0	1	17	0	0	3.0	
i 1	334.51806122448977	0.2525	69	204	7	5	13	1	0	-1	1	0	0	2.0	
i 1	334.73996598639457	1.5150000000000001	77	1088	3	9	9	16	0	2	16	0	0	2.0	
i 1	334.74397959183676	0.2525	74	702	6	1	4	17	0	1	17	0	0	2.0014753984039526	
i 1	334.74879591836736	3.535	69	702	4	5	11	0	0	0	0	0	0	2.0	
i 1	334.75120408163264	1.5150000000000001	74	702	4	2	14	17	0	2	17	0	0	3.0	
i 1	334.76324489795917	3.535	72	1088	6	5	5	1	0	-1	1	0	0	2.0	
i 1	335.00923129251703	0.505	77	702	4	24	14	16	0	1	16	0	0	3.0014753984039526	
i 1	335.01725850340137	0.2525	77	204	5	24	12	17	0	1	17	0	0	3.0014753984039526	
i 1	335.2343469387755	2.7775	74	702	2	3	16	17	0	1	17	0	0	3.0	
i 1	335.23595238095237	0.2525	72	702	5	5	4	0	0	-1	0	0	0	2.0	
i 1	335.26404761904763	0.2525	69	204	7	5	9	1	0	-1	1	0	0	2.0	
i 1	335.4835442176871	0.2525	74	204	4	4	14	16	0	1	16	0	0	3.0	
i 1	335.48675510204083	0.2525	69	702	5	5	5	0	0	-1	0	0	0	2.0	
i 1	335.49879591836736	0.2525	77	1088	6	1	8	17	0	2	17	0	0	2.0014753984039526	
i 1	335.50441496598637	1.01	76	702	2	24	16	17	0	1	17	0	0	4.0	
i 1	335.50842857142857	2.02	77	204	5	24	4	17	0	1	17	0	0	3.0014753984039526	
i 1	335.7391632653061	2.02	77	702	4	24	10	16	0	1	16	0	0	3.0014753984039526	
i 1	335.75361224489797	2.2725	74	204	4	3	5	17	0	1	17	0	0	3.0	
i 1	336.23193877551023	0.2525	77	1088	6	1	9	17	0	2	17	0	0	2.0014753984039526	
i 1	336.23274149659863	0.2525	74	1088	6	1	10	16	0	2	16	0	0	2.0014753984039526	
i 1	336.23675510204083	0.7575000000000001	77	1088	3	9	6	16	0	2	16	0	0	2.0	
i 1	336.24237414965984	0.505	69	204	7	5	5	1	0	-1	1	0	0	2.0	
i 1	336.49558503401363	0.505	77	1088	3	9	5	16	0	2	16	0	0	2.0	
i 1	336.5068231292517	0.2525	74	702	6	1	1	17	0	1	17	0	0	2.0014753984039526	
i 1	336.74076870748297	0.2525	77	1088	6	1	7	17	0	2	17	0	0	2.0014753984039526	
i 1	336.74879591836736	0.7575000000000001	74	702	6	1	10	16	0	1	16	0	0	2.0014753984039526	
i 1	336.74879591836736	0.2525	76	702	2	24	2	17	0	1	17	0	0	4.0	
i 1	336.99076870748297	1.01	73	1088	3	24	1	16	0	2	16	0	0	4.0	
i 1	336.99959863945577	0.2525	74	702	4	2	6	17	0	2	17	0	0	3.0	
i 1	337.00521768707483	0.2525	69	702	5	5	14	0	0	-1	0	0	0	2.0	
i 1	337.0108367346939	1.2625	74	1088	6	1	10	16	0	2	16	0	0	2.0014753984039526	
i 1	337.23113605442177	1.7675	74	204	4	4	16	16	0	1	16	0	0	3.0	
i 1	337.2343469387755	0.2525	72	702	5	5	1	0	0	-1	0	0	0	2.0	
i 1	337.2471904761905	0.2525	77	702	6	2	8	16	0	2	16	0	0	3.0	
i 1	337.2568231292517	0.7575000000000001	76	702	2	24	16	17	0	1	17	0	0	4.0	
i 1	337.48113605442177	0.7575000000000001	74	702	6	1	9	16	0	1	16	0	0	2.0014753984039526	
i 1	337.4931768707483	1.5150000000000001	77	1088	6	1	13	17	0	2	17	0	0	2.0014753984039526	
i 1	337.49478231292517	0.2525	77	204	5	24	8	17	0	1	17	0	0	3.0014753984039526	
i 1	337.50040136054423	68.175	66	702	3	12	3	9	0	2	9	0	0	3.5476597547464057	
i 1	337.5020068027211	1.7675	69	702	4	5	1	0	0	-1	0	0	0	2.0	
i 1	337.5116394557823	1.5150000000000001	74	702	2	4	1	17	0	1	17	0	0	3.0	
i 1	337.5196666666667	1.5150000000000001	74	702	5	1	3	17	0	1	17	0	0	2.0014753984039526	
i 1	337.5196666666667	1.2625	69	1088	6	5	4	0	0	0	0	0	0	2.0	
i 1	338.00441496598637	0.2525	77	702	6	2	16	16	0	2	16	0	0	3.0	
i 1	338.00842857142857	2.525	69	204	4	5	9	1	0	-1	1	0	0	2.0	
i 1	338.01404761904763	2.525	72	702	5	5	3	0	0	-1	0	0	0	2.0	
i 1	338.23996598639457	0.7575000000000001	76	702	2	24	15	17	0	1	17	0	0	4.0	
i 1	338.24558503401363	1.7675	74	702	5	1	16	17	0	1	17	0	0	2.0014753984039526	
i 1	338.26404761904763	1.7675	74	204	7	1	8	16	0	2	16	0	0	2.0014753984039526	
i 1	338.2664557823129	1.5150000000000001	74	204	4	3	15	17	0	1	17	0	0	3.0	
i 1	338.2664557823129	1.5150000000000001	74	702	2	3	8	17	0	1	17	0	0	3.0	
i 1	338.76725850340137	0.2525	69	702	4	5	9	0	0	0	0	0	0	2.0	
i 1	338.9891632653061	3.0300000000000002	77	1088	3	9	15	16	0	2	16	0	0	2.0	
i 1	338.99076870748297	3.0300000000000002	77	702	6	2	12	16	0	2	16	0	0	3.0	
i 1	339.01244217687076	0.2525	74	702	6	1	2	16	0	1	16	0	0	2.0014753984039526	
i 1	339.01404761904763	0.2525	77	702	4	24	6	16	0	1	16	0	0	3.0014753984039526	
i 1	339.24237414965984	4.04	74	702	5	1	3	17	0	1	17	0	0	2.0014753984039526	
i 1	339.25361224489797	1.5150000000000001	73	1088	3	24	16	16	0	2	16	0	0	4.0	
i 1	339.2568231292517	1.7675	72	1088	6	5	2	1	0	-1	1	0	0	2.0	
i 1	339.26404761904763	4.2925	77	1088	6	1	3	17	0	2	17	0	0	2.0014753984039526	
i 1	339.50762585034016	1.5150000000000001	69	702	4	5	15	0	0	0	0	0	0	2.0	
i 1	339.5164557823129	1.7675	76	702	2	24	8	17	0	1	17	0	0	4.0	
i 1	339.7335442176871	0.2525	74	204	4	4	1	16	0	1	16	0	0	3.0	
i 1	340.00120408163264	0.505	74	702	6	2	1	17	0	2	17	0	0	3.0	
i 1	340.0116394557823	0.7575000000000001	74	702	2	4	6	17	0	1	17	0	0	3.0	
i 1	340.0164557823129	0.2525	74	1088	6	1	6	16	0	2	16	0	0	2.0014753984039526	
i 1	340.25923129251703	0.2525	77	204	5	24	2	17	0	1	17	0	0	3.0014753984039526	
i 1	340.2664557823129	0.2525	77	702	4	24	13	16	0	1	16	0	0	3.0014753984039526	
i 1	340.49558503401363	1.2625	69	702	5	5	6	0	0	-1	0	0	0	2.0	
i 1	340.49638775510203	1.2625	72	204	7	5	10	1	0	-1	1	0	0	2.0	
i 1	340.51324489795917	0.2525	74	204	7	1	4	16	0	2	16	0	0	2.0014753984039526	
i 1	340.51324489795917	2.2725	77	1088	3	9	16	16	0	2	16	0	0	2.0	
i 1	340.73675510204083	2.525	69	1088	6	5	10	0	0	0	0	0	0	2.0	
i 1	340.73755782312924	2.02	74	702	6	2	12	17	0	2	17	0	0	3.0	
i 1	340.7471904761905	2.7775	69	702	4	5	10	0	0	-1	0	0	0	2.0	
i 1	340.75521768707483	0.7575000000000001	77	204	5	24	3	17	0	1	17	0	0	3.0014753984039526	
i 1	340.76404761904763	0.2525	74	1088	6	1	16	16	0	2	16	0	0	2.0014753984039526	
i 1	340.99959863945577	0.505	74	204	7	1	4	16	0	2	16	0	0	2.0014753984039526	
i 1	341.01404761904763	0.505	73	1088	3	24	9	16	0	2	16	0	0	4.0	
i 1	341.48675510204083	0.2525	74	702	6	1	6	16	0	1	16	0	0	2.0014753984039526	
i 1	341.4931768707483	0.2525	73	702	2	24	15	16	0	1	16	0	0	4.0	
i 1	341.50842857142857	0.2525	74	1088	6	1	6	16	0	2	16	0	0	2.0014753984039526	
i 1	341.73595238095237	0.2525	69	702	4	5	6	0	0	0	0	0	0	2.0	
i 1	341.73996598639457	1.2625	73	1088	3	24	5	16	0	2	16	0	0	4.0	
i 1	341.74638775510203	0.2525	74	204	7	1	1	16	0	2	16	0	0	2.0014753984039526	
i 1	341.76404761904763	4.2925	77	702	4	24	14	16	0	1	16	0	0	3.0014753984039526	
i 1	341.76485034013604	1.2625	76	702	2	24	2	17	0	1	17	0	0	4.0	
i 1	341.7696666666667	0.2525	72	1088	6	5	10	1	0	-1	1	0	0	2.0	
i 1	341.9979931972789	2.2725	74	204	4	3	13	17	0	1	17	0	0	3.0	
i 1	342.00120408163264	0.505	72	702	5	5	4	0	0	-1	0	0	0	2.0	
i 1	342.00762585034016	0.2525	69	204	4	5	6	1	0	-1	1	0	0	2.0	
i 1	342.00842857142857	0.2525	74	1088	6	1	5	16	0	2	16	0	0	2.0014753984039526	
i 1	342.0116394557823	4.545	74	702	2	3	2	17	0	1	17	0	0	3.0	
i 1	342.25441496598637	4.04	69	702	4	5	16	0	0	0	0	0	0	2.0	
i 1	342.26485034013604	2.02	77	204	5	24	8	17	0	1	17	0	0	3.0014753984039526	
i 1	342.51404761904763	3.535	72	1088	6	5	5	1	0	-1	1	0	0	2.0	
i 1	342.7471904761905	0.2525	77	702	6	2	15	16	0	2	16	0	0	3.0	
i 1	342.98996598639457	1.5150000000000001	74	204	4	4	10	16	0	1	16	0	0	3.0	
i 1	343.2303333333333	1.2625	74	702	2	4	16	17	0	1	17	0	0	3.0	
i 1	343.2343469387755	0.2525	72	204	7	5	1	1	0	-1	1	0	0	2.0	
i 1	343.24157142857143	0.505	74	1088	6	1	3	16	0	2	16	0	0	2.0014753984039526	
i 1	343.24478231292517	1.01	76	702	2	24	8	17	0	1	17	0	0	4.0	
i 1	343.51244217687076	0.505	69	1088	6	5	16	0	0	0	0	0	0	2.0	
i 1	343.51725850340137	0.7575000000000001	74	204	7	1	10	16	0	2	16	0	0	2.0014753984039526	
i 1	343.7656530612245	1.5150000000000001	74	702	5	1	3	17	0	1	17	0	0	2.0014753984039526	
i 1	344.0116394557823	0.2525	72	702	5	5	9	0	0	-1	0	0	0	2.0	
i 1	344.23193877551023	61.3575	61	702	3	12	8	6	0	2	6	0	0	3.5476597547464057	
i 1	344.23274149659863	0.2525	76	702	2	24	3	17	0	1	17	0	0	8.0	
i 1	344.2391632653061	2.525	74	204	6	3	5	17	0	1	17	0	0	3.0	
i 1	344.24478231292517	0.2525	73	702	2	24	2	16	0	1	16	0	0	8.0	
i 1	344.2471904761905	1.01	74	204	6	1	11	16	0	2	16	0	0	2.0014753984039526	
i 1	344.2520068027211	1.2625	73	702	2	20	10	17	0	2	17	0	0	4.0	
i 1	344.25923129251703	8.585	76	702	2	20	6	16	0	2	16	0	0	4.0	
i 1	344.26886394557823	0.2525	69	702	4	5	13	0	0	-1	0	0	0	2.0	
i 1	344.4891632653061	0.2525	73	1088	3	20	7	17	0	1	17	0	0	4.0	
i 1	344.49638775510203	0.2525	77	1088	3	9	13	16	0	2	16	0	0	2.0	
i 1	344.5020068027211	1.5150000000000001	77	204	5	24	13	17	0	1	17	0	0	3.0014753984039526	
i 1	344.7520068027211	0.2525	72	204	4	5	8	1	0	-1	1	0	0	2.0	
i 1	344.75762585034016	3.0300000000000002	77	702	6	2	15	16	0	2	16	0	0	3.0	
i 1	344.7656530612245	2.525	73	1088	3	24	4	16	0	2	16	0	0	8.0	
i 1	344.9883605442177	1.7675	69	702	4	5	12	0	0	-1	0	0	0	2.0	
i 1	344.9883605442177	2.2725	76	702	2	24	11	17	0	1	17	0	0	8.0	
i 1	344.99879591836736	0.505	73	1088	3	20	2	17	0	1	17	0	0	4.0	
i 1	345.00441496598637	2.02	74	702	5	1	14	16	0	1	16	0	0	2.0014753984039526	
i 1	345.0108367346939	1.7675	69	1088	6	5	15	0	0	0	0	0	0	2.0	
i 1	345.0116394557823	2.2725	74	1088	6	1	10	16	0	2	16	0	0	2.0014753984039526	
i 1	345.01404761904763	0.2525	74	204	4	4	7	16	0	1	16	0	0	3.0	
i 1	345.2431768707483	2.525	77	1088	3	9	8	16	0	2	16	0	0	2.0	
i 1	345.26485034013604	7.8275	76	1088	3	20	6	17	0	2	17	0	0	4.0	
i 1	345.5108367346939	0.2525	76	702	4	20	15	17	0	1	17	0	0	4.0	
i 1	345.51244217687076	0.2525	76	204	4	20	11	17	0	2	17	0	0	4.0	
i 1	345.7343469387755	0.505	73	702	2	20	13	17	0	2	17	0	0	4.0	
i 1	345.74076870748297	0.505	73	1088	3	20	9	16	0	2	16	0	0	4.0	
i 1	345.98675510204083	0.2525	69	702	5	5	15	0	0	-1	0	0	0	2.0	
i 1	345.99959863945577	5.05	77	1088	4	1	2	17	0	2	17	0	0	2.0014753984039526	
i 1	346.01324489795917	2.525	74	702	5	1	14	17	0	1	17	0	0	2.0014753984039526	
i 1	346.23514965986396	0.2525	73	702	4	20	2	17	0	1	17	0	0	4.0	
i 1	346.23675510204083	0.2525	73	204	4	20	1	16	0	1	16	0	0	4.0	
i 1	346.24959863945577	1.01	69	204	4	5	13	1	0	-1	1	0	0	2.0	
i 1	346.26404761904763	1.2625	72	702	5	5	7	0	0	-1	0	0	0	2.0	
i 1	346.48193877551023	2.525	74	702	6	2	15	17	0	2	17	0	0	3.0	
i 1	346.49397959183676	2.2725	72	1088	6	5	1	1	0	-1	1	0	0	2.0	
i 1	346.4979931972789	0.2525	73	1088	3	20	16	16	0	2	16	0	0	4.0	
i 1	346.50602040816324	0.2525	73	702	2	20	2	16	0	1	16	0	0	4.0	
i 1	346.5116394557823	2.2725	69	702	4	5	3	0	0	0	0	0	0	2.0	
i 1	346.73113605442177	0.2525	73	204	4	20	9	16	0	1	16	0	0	4.0	
i 1	346.7335442176871	0.2525	73	702	4	20	3	16	0	2	16	0	0	4.0	
i 1	346.7391632653061	2.02	77	1088	3	9	15	16	0	2	16	0	0	2.0	
i 1	346.98514965986396	0.505	74	204	6	1	6	16	0	2	16	0	0	2.0014753984039526	
i 1	347.01404761904763	0.7575000000000001	73	1088	3	20	6	17	0	2	17	0	0	4.0	
i 1	347.0156530612245	0.7575000000000001	76	702	2	20	10	17	0	2	17	0	0	4.0	
i 1	347.24157142857143	0.2525	77	204	5	24	5	17	0	1	17	0	0	3.0014753984039526	
i 1	347.48514965986396	0.505	69	1088	6	5	14	0	0	0	0	0	0	2.0	
i 1	347.48595238095237	0.2525	74	702	5	1	1	16	0	1	16	0	0	2.0014753984039526	
i 1	347.49397959183676	4.04	76	702	2	24	1	17	0	1	17	0	0	8.0	
i 1	347.49558503401363	0.2525	76	1088	3	20	9	16	0	1	16	0	0	4.0	
i 1	347.51806122448977	0.2525	72	204	4	5	6	1	0	-1	1	0	0	2.0	
i 1	347.7303333333333	0.2525	76	204	4	20	11	16	0	1	16	0	0	4.0	
i 1	347.7335442176871	0.2525	74	702	2	4	7	17	0	1	17	0	0	3.0	
i 1	347.73514965986396	2.7775	74	204	6	1	9	16	0	2	16	0	0	2.0014753984039526	
i 1	347.74478231292517	2.2725	74	702	5	1	5	17	0	1	17	0	0	2.0014753984039526	
i 1	347.74478231292517	4.7975	74	702	2	3	11	17	0	1	17	0	0	3.0	
i 1	347.7479931972789	0.2525	69	702	4	5	15	0	0	-1	0	0	0	2.0	
i 1	347.75040136054423	0.2525	76	702	4	20	4	16	0	1	16	0	0	4.0	
i 1	347.75521768707483	0.2525	73	702	4	20	1	16	0	2	16	0	0	4.0	
i 1	347.99157142857143	1.01	73	1088	3	24	10	16	0	2	16	0	0	8.0	
i 1	347.9979931972789	2.02	72	204	4	5	12	1	0	-1	1	0	0	2.0	
i 1	348.00441496598637	4.545	74	204	6	3	6	17	0	1	17	0	0	3.0	
i 1	348.00842857142857	0.2525	76	1088	3	20	9	17	0	2	17	0	0	4.0	
i 1	348.00923129251703	2.02	69	702	5	5	5	0	0	-1	0	0	0	2.0	
i 1	348.50923129251703	0.505	74	702	5	1	9	16	0	1	16	0	0	2.0014753984039526	
i 1	348.51485034013604	0.2525	76	1088	3	20	12	17	0	1	17	0	0	4.0	
i 1	348.73996598639457	0.2525	76	204	4	20	8	17	0	1	17	0	0	4.0	
i 1	348.7479931972789	0.2525	77	702	6	2	11	16	0	2	16	0	0	3.0	
i 1	348.75923129251703	0.2525	72	702	5	5	14	0	0	-1	0	0	0	2.0	
i 1	348.76886394557823	1.7675	69	702	4	5	1	0	0	-1	0	0	0	2.0	
i 1	348.76886394557823	0.2525	76	702	4	20	10	17	0	2	17	0	0	4.0	
i 1	348.9843469387755	3.0300000000000002	74	702	5	1	2	17	0	1	17	0	0	2.0014753984039526	
i 1	348.9843469387755	1.7675	74	204	4	4	6	16	0	1	16	0	0	3.0	
i 1	348.9931768707483	1.2625	69	1088	6	5	2	0	0	0	0	0	0	2.0	
i 1	349.00361224489797	0.505	73	1088	3	20	6	16	0	2	16	0	0	4.0	
i 1	349.00602040816324	0.505	73	702	2	20	14	17	0	2	17	0	0	4.0	
i 1	349.23996598639457	1.01	73	1088	3	24	15	16	0	2	16	0	0	8.0	
i 1	349.26404761904763	0.2525	76	1088	3	20	16	17	0	2	17	0	0	4.0	
i 1	349.26806122448977	1.7675	74	702	2	4	13	17	0	1	17	0	0	3.0	
i 1	349.48113605442177	0.2525	76	702	4	20	14	17	0	1	17	0	0	4.0	
i 1	349.4891632653061	3.7875	69	702	4	5	3	0	0	0	0	0	0	2.0	
i 1	349.49638775510203	1.5150000000000001	72	1088	6	5	15	1	0	-1	1	0	0	2.0	
i 1	349.50521768707483	0.2525	73	204	4	20	3	16	0	2	16	0	0	4.0	
i 1	349.5156530612245	0.2525	73	702	4	20	11	17	0	2	17	0	0	4.0	
i 1	349.7471904761905	0.505	76	1088	3	20	9	17	0	1	17	0	0	4.0	
i 1	349.7520068027211	0.505	76	702	2	20	11	16	0	2	16	0	0	4.0	
i 1	349.76485034013604	0.505	76	1088	3	20	5	17	0	2	17	0	0	4.0	
i 1	350.00040136054423	0.2525	74	1088	6	1	7	16	0	2	16	0	0	2.0014753984039526	
i 1	350.2431768707483	0.2525	69	702	5	5	10	0	0	-1	0	0	0	2.0	
i 1	350.24478231292517	0.2525	73	204	4	20	16	16	0	2	16	0	0	4.0	
i 1	350.2528095238095	0.2525	74	702	5	1	16	16	0	1	16	0	0	2.0014753984039526	
i 1	350.2656530612245	0.2525	73	702	4	20	10	16	0	1	16	0	0	4.0	
i 1	350.2696666666667	0.2525	73	702	4	20	7	17	0	1	17	0	0	4.0	
i 1	350.48675510204083	4.7975	77	702	4	24	2	16	0	1	16	0	0	3.0014753984039526	
i 1	350.48755782312924	0.2525	69	204	4	5	5	1	0	-1	1	0	0	2.0	
i 1	350.4891632653061	0.505	76	702	2	20	5	16	0	2	16	0	0	4.0	
i 1	350.4891632653061	1.2625	73	1088	3	24	6	16	0	2	16	0	0	8.0	
i 1	350.5068231292517	0.505	76	1088	3	20	3	17	0	1	17	0	0	4.0	
i 1	350.51003401360543	0.505	73	702	2	24	13	17	0	2	17	0	0	8.0	
i 1	350.5116394557823	0.2525	72	702	5	5	3	0	0	-1	0	0	0	2.0	
i 1	350.5156530612245	0.505	76	1088	3	20	5	16	0	2	16	0	0	4.0	
i 1	350.74237414965984	0.2525	74	702	5	1	12	16	0	1	16	0	0	2.0014753984039526	
i 1	350.75120408163264	0.2525	74	702	6	2	11	17	0	2	17	0	0	3.0	
i 1	350.76886394557823	0.505	72	204	4	5	16	1	0	-1	1	0	0	2.0	
i 1	350.98755782312924	2.2725	72	1088	3	5	7	1	0	-1	1	0	0	2.0	
i 1	350.98755782312924	0.2525	76	702	4	20	1	16	0	2	16	0	0	4.0	
i 1	350.98755782312924	0.2525	76	204	4	24	9	17	0	2	17	0	0	8.0	
i 1	350.9931768707483	0.2525	74	204	5	4	16	16	0	1	16	0	0	3.0	
i 1	350.99397959183676	4.545	77	204	5	24	4	17	0	1	17	0	0	3.0014753984039526	
i 1	350.9979931972789	1.01	77	1088	6	1	12	17	0	2	17	0	0	2.0014753984039526	
i 1	350.99959863945577	0.2525	76	702	4	20	4	16	0	1	16	0	0	4.0	
i 1	351.0068231292517	6.8175	61	702	5	14	7	9	0	1	9	0	0	3.2348711625754984	
i 1	351.00762585034016	0.2525	73	204	4	20	8	17	0	2	17	0	0	4.0	
i 1	351.01485034013604	0.2525	77	1088	3	9	12	16	0	2	16	0	0	2.0	
i 1	351.23193877551023	0.2525	69	702	4	5	1	0	0	-1	0	0	0	2.0	
i 1	351.2383605442177	0.505	76	702	2	24	4	16	0	2	16	0	0	8.0	
i 1	351.24076870748297	1.01	76	1088	3	20	8	16	0	2	16	0	0	4.0	
i 1	351.24478231292517	2.2725	77	1088	3	9	7	16	0	2	16	0	0	2.0	
i 1	351.25521768707483	2.2725	77	702	6	2	14	16	0	2	16	0	0	3.0	
i 1	351.26404761904763	0.2525	73	1088	3	20	7	17	0	2	17	0	0	4.0	
i 1	351.2696666666667	1.01	73	702	2	20	8	17	0	1	17	0	0	4.0	
i 1	351.51404761904763	0.505	69	1088	6	5	12	0	0	0	0	0	0	2.0	
i 1	351.7343469387755	2.02	74	702	5	1	2	17	0	1	17	0	0	2.0014753984039526	
i 1	351.73514965986396	0.505	73	1088	3	20	2	17	0	2	17	0	0	4.0	
i 1	351.75361224489797	2.2725	74	204	5	1	7	16	0	2	16	0	0	2.0014753984039526	
i 1	351.76886394557823	2.7775	76	702	2	24	4	17	0	1	17	0	0	8.0	
i 1	352.0020068027211	0.2525	72	204	4	5	7	1	0	-1	1	0	0	2.0	
i 1	352.00602040816324	4.2925	73	1088	3	24	15	16	0	2	16	0	0	8.0	
i 1	352.01003401360543	0.2525	72	702	5	5	8	0	0	-1	0	0	0	2.0	
i 1	352.0196666666667	0.2525	76	702	2	24	2	16	0	2	16	0	0	8.0	
i 1	352.2343469387755	0.2525	73	204	4	20	3	16	0	1	16	0	0	4.0	
i 1	352.24237414965984	0.2525	73	702	4	20	14	16	0	1	16	0	0	4.0	
i 1	352.26485034013604	0.2525	73	204	4	24	15	17	0	2	17	0	0	8.0	
i 1	352.2656530612245	2.525	69	702	4	5	14	0	0	-1	0	0	0	2.0	
i 1	352.26725850340137	2.525	69	1088	6	5	3	0	0	0	0	0	0	2.0	
i 1	352.26886394557823	0.2525	73	702	4	20	3	17	0	2	17	0	0	4.0	
i 1	352.49076870748297	0.2525	73	1088	3	20	4	17	0	1	17	0	0	4.0	
i 1	352.49237414965984	2.02	77	1088	3	9	16	16	0	2	16	0	0	2.0	
i 1	352.49397959183676	0.505	76	702	2	20	14	17	0	2	17	0	0	4.0	
i 1	352.49879591836736	3.7875	76	702	2	24	7	17	0	2	17	0	0	8.0	
i 1	352.50120408163264	2.02	76	1088	3	20	3	17	0	2	17	0	0	4.0	
i 1	352.5116394557823	2.2725	74	702	6	2	11	17	0	2	17	0	0	3.0	
i 1	353.2431768707483	0.2525	69	204	4	5	8	1	0	-1	1	0	0	2.0	
i 1	353.2616394557823	0.2525	72	204	4	5	8	1	0	-1	1	0	0	2.0	
i 1	353.48274149659863	2.2725	72	702	5	5	12	0	0	-1	0	0	0	2.0	
i 1	353.49237414965984	3.2825	73	1088	3	20	1	17	0	1	17	0	0	4.0	
i 1	353.49397959183676	4.7975	74	702	2	3	2	17	0	1	17	0	0	3.0	
i 1	353.4971904761905	4.545	74	204	6	3	14	17	0	1	17	0	0	3.0	
i 1	353.5068231292517	0.2525	72	1088	3	5	8	1	0	-1	1	0	0	2.0	
i 1	353.50762585034016	12.120000000000001	76	1088	3	20	4	17	0	2	17	0	0	4.0	
i 1	353.5164557823129	1.5150000000000001	76	702	2	20	15	16	0	2	16	0	0	4.0	
i 1	353.51725850340137	1.5150000000000001	76	702	2	20	2	17	0	2	17	0	0	4.0	
i 1	353.75040136054423	0.2525	74	702	5	1	12	16	0	1	16	0	0	2.0014753984039526	
i 1	353.7656530612245	2.02	69	204	4	5	16	1	0	-1	1	0	0	2.0	
i 1	353.98996598639457	0.2525	74	702	5	1	14	17	0	1	17	0	0	2.0014753984039526	
i 1	354.00120408163264	2.7775	74	1088	4	1	14	16	0	2	16	0	0	2.0014753984039526	
i 1	354.2616394557823	2.7775	74	702	5	1	3	16	0	1	16	0	0	2.0014753984039526	
i 1	354.5116394557823	0.2525	74	702	2	4	6	17	0	1	17	0	0	3.0	
i 1	354.74157142857143	0.2525	74	204	5	4	7	16	0	1	16	0	0	3.0	
i 1	354.74478231292517	1.5150000000000001	69	702	4	5	3	0	0	0	0	0	0	2.0	
i 1	354.75602040816324	1.5150000000000001	72	1088	3	5	8	1	0	-1	1	0	0	2.0	
i 1	354.76886394557823	0.2525	77	1088	3	9	7	16	0	2	16	0	0	2.0	
i 1	354.9843469387755	0.2525	77	1088	3	9	8	16	0	2	16	0	0	2.0	
i 1	354.99397959183676	2.525	69	702	5	5	8	0	0	-1	0	0	0	2.0	
i 1	354.9971904761905	2.02	74	702	2	4	10	17	0	1	17	0	0	3.0	
i 1	355.00602040816324	2.525	72	204	4	5	3	1	0	-1	1	0	0	2.0	
i 1	355.24157142857143	1.7675	74	204	5	4	1	16	0	1	16	0	0	3.0	
i 1	355.25361224489797	0.2525	74	204	5	1	10	16	0	2	16	0	0	2.0014753984039526	
i 1	355.49959863945577	0.2525	74	702	5	1	16	17	0	1	17	0	0	2.0014753984039526	
i 1	355.5156530612245	5.3025	74	702	5	1	8	17	0	1	17	0	0	2.0014753984039526	
i 1	355.7383605442177	2.02	77	1088	6	1	13	17	0	2	17	0	0	2.0014753984039526	
i 1	355.76003401360543	7.07	76	702	2	20	2	16	0	2	16	0	0	4.0	
i 1	355.76886394557823	1.01	76	702	2	20	12	17	0	2	17	0	0	4.0	
i 1	356.24157142857143	2.2725	69	702	4	5	6	0	0	-1	0	0	0	2.0	
i 1	356.24237414965984	0.2525	69	204	4	5	2	1	0	-1	1	0	0	2.0	
i 1	356.24638775510203	0.505	76	1088	3	20	15	17	0	2	17	0	0	4.0	
i 1	356.25040136054423	2.02	76	702	2	24	10	17	0	1	17	0	0	8.0	
i 1	356.49638775510203	0.2525	76	702	2	24	14	17	0	2	17	0	0	8.0	
i 1	356.50923129251703	1.2625	69	1088	6	5	14	0	0	0	0	0	0	2.0	
i 1	356.5116394557823	2.02	73	1088	3	24	11	16	0	2	16	0	0	8.0	
i 1	356.75040136054423	0.2525	76	204	4	20	8	17	0	2	17	0	0	4.0	
i 1	356.75361224489797	1.01	74	702	5	1	6	17	0	1	17	0	0	2.0014753984039526	
i 1	356.75441496598637	0.2525	73	204	4	24	5	16	0	2	16	0	0	8.0	
i 1	356.75521768707483	0.2525	76	702	4	20	16	16	0	1	16	0	0	4.0	
i 1	356.76806122448977	0.2525	76	702	4	20	3	16	0	1	16	0	0	4.0	
i 1	356.98595238095237	0.7575000000000001	76	1088	3	20	8	17	0	1	17	0	0	4.0	
i 1	356.99237414965984	0.7575000000000001	73	1088	3	20	8	16	0	2	16	0	0	4.0	
i 1	357.0020068027211	0.7575000000000001	73	702	2	20	4	17	0	2	17	0	0	4.0	
i 1	357.00521768707483	2.7775	77	702	6	2	5	16	0	2	16	0	0	3.0	
i 1	357.0116394557823	2.02	74	204	5	1	9	16	0	2	16	0	0	2.0014753984039526	
i 1	357.01244217687076	0.7575000000000001	77	1088	3	9	2	16	0	2	16	0	0	2.0	
i 1	357.01725850340137	0.7575000000000001	73	702	2	24	13	17	0	1	17	0	0	8.0	
i 1	357.48514965986396	4.04	72	1088	3	5	1	1	0	-1	1	0	0	2.0	
i 1	357.48755782312924	4.04	69	702	4	5	14	0	0	0	0	0	0	2.0	
i 1	357.73274149659863	2.02	77	1088	5	9	4	16	0	2	16	0	0	2.0	
i 1	357.73675510204083	0.2525	73	204	4	24	12	17	0	2	17	0	0	8.0	
i 1	357.73996598639457	0.2525	76	204	4	20	11	17	0	2	17	0	0	4.0	
i 1	357.74076870748297	0.2525	73	702	4	20	2	16	0	2	16	0	0	4.0	
i 1	357.75120408163264	0.2525	76	702	4	20	6	16	0	2	16	0	0	4.0	
i 1	357.76003401360543	6.8175	66	702	5	14	13	6	0	2	6	0	0	3.2348711625754984	
i 1	357.7616394557823	2.7775	77	1088	5	1	4	17	0	2	17	0	0	2.0014753984039526	
i 1	357.76485034013604	1.01	74	702	3	1	7	17	0	1	17	0	0	2.0014753984039526	
i 1	357.7696666666667	0.7575000000000001	69	1088	3	5	6	0	0	0	0	0	0	2.0	
i 1	357.7696666666667	13.635	61	702	5	14	1	9	0	1	9	0	0	3.2348711625754984	
i 1	357.9803333333333	1.7675	73	1088	3	20	6	17	0	2	17	0	0	4.0	
i 1	357.9843469387755	0.2525	73	1088	3	20	15	16	0	1	16	0	0	4.0	
i 1	358.00441496598637	0.505	73	702	2	24	16	16	0	2	16	0	0	8.0	
i 1	358.00602040816324	0.505	74	702	6	2	6	17	0	2	17	0	0	3.0	
i 1	358.00602040816324	2.02	73	702	2	20	2	17	0	1	17	0	0	4.0	
i 1	358.26725850340137	0.505	74	204	6	3	4	17	0	1	17	0	0	3.0	
i 1	358.48755782312924	0.505	72	204	4	5	1	1	0	-1	1	0	0	2.0	
i 1	358.49879591836736	0.505	69	702	5	5	7	0	0	-1	0	0	0	2.0	
i 1	358.50361224489797	0.2525	74	204	5	4	14	16	0	1	16	0	0	3.0	
i 1	358.73274149659863	1.2625	73	702	2	24	4	16	0	2	16	0	0	8.0	
i 1	358.73755782312924	14.8975	73	1088	3	24	2	16	0	2	16	0	0	8.0	
i 1	358.74076870748297	1.2625	73	1088	3	20	15	16	0	1	16	0	0	4.0	
i 1	358.7471904761905	0.2525	74	1088	6	1	15	16	0	2	16	0	0	2.0014753984039526	
i 1	358.75040136054423	3.7875	76	702	2	24	12	17	0	1	17	0	0	8.0	
i 1	358.76003401360543	2.02	77	1088	3	9	3	16	0	2	16	0	0	2.0	
i 1	358.76886394557823	2.525	74	702	6	2	12	17	0	2	17	0	0	3.0	
i 1	358.98595238095237	0.2525	69	204	4	5	2	1	0	-1	1	0	0	2.0	
i 1	358.99959863945577	0.2525	72	702	5	5	8	0	0	-1	0	0	0	2.0	
i 1	359.00040136054423	0.2525	74	702	5	1	13	16	0	1	16	0	0	2.0014753984039526	
i 1	359.0164557823129	0.2525	77	702	4	24	2	16	0	1	16	0	0	3.0014753984039526	
i 1	359.23595238095237	0.2525	69	702	5	5	10	0	0	-1	0	0	0	2.0	
i 1	359.24638775510203	0.2525	74	702	3	1	9	17	0	1	17	0	0	2.0014753984039526	
i 1	359.26244217687076	2.7775	77	204	5	24	10	17	0	1	17	0	0	3.0014753984039526	
i 1	359.26886394557823	0.2525	69	1088	3	5	4	0	0	0	0	0	0	2.0	
i 1	359.4891632653061	2.525	77	702	4	24	11	16	0	1	16	0	0	3.0014753984039526	
i 1	359.51886394557823	0.7575000000000001	69	702	4	5	5	0	0	-1	0	0	0	2.0	
i 1	359.73996598639457	5.05	74	702	2	3	13	17	0	1	17	0	0	3.0	
i 1	359.76003401360543	4.7975	74	204	6	3	16	17	0	1	17	0	0	3.0	
i 1	359.9891632653061	0.505	76	702	4	20	11	16	0	2	16	0	0	4.0	
i 1	359.99959863945577	0.505	73	204	4	24	14	16	0	1	16	0	0	8.0	
i 1	360.01404761904763	0.505	73	204	4	20	8	16	0	1	16	0	0	4.0	
i 1	360.01886394557823	0.505	73	702	4	20	15	16	0	1	16	0	0	4.0	
i 1	360.2528095238095	1.5150000000000001	69	1088	3	5	15	0	0	0	0	0	0	2.0	
i 1	360.26725850340137	0.2525	72	204	4	5	12	1	0	-1	1	0	0	2.0	
i 1	360.4803333333333	0.505	73	702	2	20	1	17	0	2	17	0	0	4.0	
i 1	360.49478231292517	0.505	73	1088	3	20	2	17	0	2	17	0	0	4.0	
i 1	360.50120408163264	0.2525	74	702	5	1	1	16	0	1	16	0	0	2.0014753984039526	
i 1	360.51003401360543	1.5150000000000001	69	702	4	5	2	0	0	-1	0	0	0	2.0	
i 1	360.51003401360543	0.505	73	1088	3	20	5	17	0	1	17	0	0	4.0	
i 1	360.51404761904763	0.505	76	702	2	24	15	17	0	1	17	0	0	8.0	
i 1	360.7528095238095	2.525	69	204	4	5	4	1	0	-1	1	0	0	2.0	
i 1	360.75762585034016	0.2525	77	1088	5	1	13	17	0	2	17	0	0	2.0014753984039526	
i 1	360.76324489795917	0.2525	77	702	6	2	5	16	0	2	16	0	0	3.0	
i 1	360.76324489795917	2.525	72	702	5	5	9	0	0	-1	0	0	0	2.0	
i 1	360.76806122448977	2.7775	74	204	5	1	16	16	0	2	16	0	0	2.0014753984039526	
i 1	360.98193877551023	0.2525	76	702	4	20	6	16	0	1	16	0	0	4.0	
i 1	360.98755782312924	1.5150000000000001	74	702	2	4	10	17	0	1	17	0	0	3.0	
i 1	361.00361224489797	0.2525	73	204	4	24	1	17	0	2	17	0	0	8.0	
i 1	361.00762585034016	0.2525	76	702	4	20	6	16	0	1	16	0	0	4.0	
i 1	361.01244217687076	0.2525	73	204	4	20	7	16	0	1	16	0	0	4.0	
i 1	361.01886394557823	2.525	74	702	3	1	16	17	0	1	17	0	0	2.0014753984039526	
i 1	361.2391632653061	0.7575000000000001	73	702	2	20	12	16	0	1	16	0	0	4.0	
i 1	361.24397959183676	0.7575000000000001	76	1088	3	20	13	17	0	2	17	0	0	4.0	
i 1	361.2528095238095	0.7575000000000001	73	702	2	24	8	17	0	2	17	0	0	8.0	
i 1	361.25762585034016	1.2625	74	204	5	4	5	16	0	1	16	0	0	3.0	
i 1	361.2608367346939	0.7575000000000001	73	1088	3	20	12	16	0	1	16	0	0	4.0	
i 1	361.74397959183676	0.505	72	204	4	5	5	1	0	-1	1	0	0	2.0	
i 1	361.98113605442177	0.505	74	702	5	1	5	16	0	1	16	0	0	2.0014753984039526	
i 1	361.9883605442177	0.2525	74	1088	6	1	11	16	0	2	16	0	0	2.0014753984039526	
i 1	361.9979931972789	0.2525	76	702	4	20	9	17	0	2	17	0	0	4.0	
i 1	362.01244217687076	0.2525	76	702	4	20	5	17	0	1	17	0	0	4.0	
i 1	362.01244217687076	0.2525	73	204	4	20	10	16	0	1	16	0	0	4.0	
i 1	362.01404761904763	2.2725	69	702	4	5	2	0	0	0	0	0	0	2.0	
i 1	362.01806122448977	0.2525	76	204	4	24	16	16	0	1	16	0	0	8.0	
i 1	362.23113605442177	2.525	77	204	5	24	15	17	0	1	17	0	0	3.0014753984039526	
i 1	362.2335442176871	0.2525	76	702	2	20	7	17	0	1	17	0	0	4.0	
i 1	362.2343469387755	2.02	72	1088	3	5	10	1	0	-1	1	0	0	2.0	
i 1	362.24157142857143	2.525	73	702	2	24	16	16	0	1	16	0	0	8.0	
i 1	362.26404761904763	2.525	73	1088	3	20	15	16	0	2	16	0	0	4.0	
i 1	362.2696666666667	0.505	73	1088	3	20	5	16	0	2	16	0	0	4.0	
i 1	362.49638775510203	0.505	77	1088	3	9	2	16	0	2	16	0	0	2.0	
i 1	362.50923129251703	2.02	77	702	4	24	4	16	0	1	16	0	0	3.0014753984039526	
i 1	362.51806122448977	0.2525	77	702	6	2	8	16	0	2	16	0	0	3.0	
i 1	362.75923129251703	0.2525	74	702	2	4	7	17	0	1	17	0	0	3.0	
i 1	362.98675510204083	3.0300000000000002	77	702	6	2	11	16	0	2	16	0	0	3.0	
i 1	363.00120408163264	0.2525	74	702	6	2	8	17	0	2	17	0	0	3.0	
i 1	363.23193877551023	1.7675	69	702	5	5	10	0	0	-1	0	0	0	2.0	
i 1	363.25521768707483	2.7775	77	1088	5	9	13	16	0	2	16	0	0	2.0	
i 1	363.26003401360543	1.5150000000000001	72	204	4	5	12	1	0	-1	1	0	0	2.0	
i 1	363.4931768707483	1.7675	76	702	2	20	11	16	0	2	16	0	0	4.0	
i 1	363.5020068027211	0.2525	74	702	5	1	2	17	0	1	17	0	0	2.0014753984039526	
i 1	363.50923129251703	1.2625	76	702	2	20	2	17	0	1	17	0	0	4.0	
i 1	363.5156530612245	2.02	74	702	5	1	4	16	0	1	16	0	0	2.0014753984039526	
i 1	363.73514965986396	2.7775	69	702	4	5	16	0	0	-1	0	0	0	2.0	
i 1	363.73996598639457	2.525	69	1088	3	5	5	0	0	0	0	0	0	2.0	
i 1	363.74478231292517	0.7575000000000001	74	1088	6	1	5	16	0	2	16	0	0	2.0014753984039526	
i 1	364.2568231292517	0.505	73	1088	3	20	15	16	0	2	16	0	0	4.0	
i 1	364.2608367346939	3.2825	76	702	2	24	16	17	0	1	17	0	0	8.0	
i 1	364.48595238095237	1.01	74	1088	5	1	2	16	0	2	16	0	0	2.0014753984039526	
i 1	364.49157142857143	11.8675	66	702	5	14	7	6	0	2	6	0	0	3.2348711625754984	
i 1	364.4931768707483	5.8075	77	1088	4	1	3	17	0	2	17	0	0	2.0014753984039526	
i 1	364.49478231292517	6.0600000000000005	74	702	5	1	16	17	0	1	17	0	0	2.0014753984039526	
i 1	364.49879591836736	11.8675	66	702	6	17	1	6	0	2	6	0	0	1.132643730431941	
i 1	364.50521768707483	6.8175	61	204	6	13	6	9	0	1	9	0	0	0.9846220044962098	
i 1	364.50923129251703	0.2525	77	702	3	24	1	16	0	1	16	0	0	3.0014753984039526	
i 1	364.5116394557823	2.2725	77	1088	5	9	9	16	0	2	16	0	0	2.0	
i 1	364.7303333333333	0.2525	76	204	4	20	9	16	0	1	16	0	0	4.0	
i 1	364.73675510204083	0.505	72	702	2	5	8	0	0	-1	0	0	0	2.0	
i 1	364.7431768707483	0.2525	74	204	5	4	13	16	0	1	16	0	0	3.0	
i 1	364.7479931972789	0.2525	73	702	4	20	1	16	0	1	16	0	0	4.0	
i 1	364.76806122448977	0.2525	76	702	4	20	1	16	0	2	16	0	0	4.0	
i 1	364.7696666666667	0.2525	73	204	4	24	9	17	0	2	17	0	0	8.0	
i 1	364.9803333333333	1.7675	74	702	6	2	15	17	0	2	17	0	0	3.0	
i 1	364.9883605442177	0.2525	72	204	4	5	10	1	0	-1	1	0	0	2.0	
i 1	364.9891632653061	3.7875	76	702	2	24	9	16	0	2	16	0	0	8.0	
i 1	364.9931768707483	0.2525	73	1088	3	20	15	16	0	2	16	0	0	4.0	
i 1	364.99879591836736	0.505	73	702	2	20	9	17	0	1	17	0	0	4.0	
i 1	365.0108367346939	2.525	76	1088	3	20	4	16	0	1	16	0	0	4.0	
i 1	365.23193877551023	2.2725	74	702	5	1	4	17	0	1	17	0	0	2.0014753984039526	
i 1	365.24076870748297	3.7875	69	702	4	5	13	0	0	0	0	0	0	2.0	
i 1	365.24478231292517	2.02	74	204	5	1	4	16	0	2	16	0	0	2.0014753984039526	
i 1	365.2696666666667	3.7875	72	1088	3	5	3	1	0	-1	1	0	0	2.0	
i 1	365.74076870748297	4.7975	74	702	2	3	8	17	0	1	17	0	0	3.0	
i 1	365.74478231292517	4.7975	74	204	6	3	10	17	0	1	17	0	0	3.0	
i 1	366.25521768707483	0.2525	72	204	4	5	8	1	0	-1	1	0	0	2.0	
i 1	366.4883605442177	2.2725	76	1088	3	20	8	17	0	2	17	0	0	4.0	
i 1	366.49237414965984	2.2725	73	1088	3	20	4	16	0	2	16	0	0	4.0	
i 1	366.4979931972789	0.505	69	1088	3	5	3	0	0	0	0	0	0	2.0	
i 1	366.51244217687076	0.2525	72	702	2	5	5	0	0	-1	0	0	0	2.0	
i 1	366.7303333333333	0.2525	77	1088	5	9	2	16	0	2	16	0	0	2.0	
i 1	366.7656530612245	2.02	74	204	5	4	10	16	0	1	16	0	0	3.0	
i 1	366.9883605442177	2.02	74	702	2	4	13	17	0	1	17	0	0	3.0	
i 1	366.99157142857143	0.2525	69	204	4	5	5	1	0	-1	1	0	0	2.0	
i 1	367.00602040816324	0.505	72	702	2	5	6	0	0	-1	0	0	0	2.0	
i 1	367.2335442176871	0.2525	74	702	5	1	2	16	0	1	16	0	0	2.0014753984039526	
i 1	367.2335442176871	2.7775	69	702	4	5	9	0	0	-1	0	0	0	2.0	
i 1	367.48595238095237	0.2525	69	204	4	5	5	1	0	-1	1	0	0	2.0	
i 1	367.4971904761905	0.2525	77	204	5	24	12	17	0	1	17	0	0	3.0014753984039526	
i 1	367.51725850340137	0.505	74	204	5	1	12	16	0	2	16	0	0	2.0014753984039526	
i 1	367.7383605442177	2.2725	69	1088	3	5	1	0	0	0	0	0	0	2.0	
i 1	367.9835442176871	0.2525	74	1088	5	1	14	16	0	2	16	0	0	2.0014753984039526	
i 1	368.0028095238095	0.505	77	702	3	24	15	16	0	1	16	0	0	3.0014753984039526	
i 1	368.24157142857143	0.505	73	702	2	20	6	17	0	1	17	0	0	4.0	
i 1	368.24959863945577	6.3125	76	702	2	24	11	17	0	1	17	0	0	8.0	
i 1	368.2608367346939	0.505	74	204	5	1	3	16	0	2	16	0	0	2.0014753984039526	
i 1	368.2656530612245	1.7675	76	702	2	20	9	16	0	2	16	0	0	4.0	
i 1	368.4971904761905	0.2525	74	702	5	1	14	16	0	1	16	0	0	2.0014753984039526	
i 1	368.73113605442177	0.505	76	204	4	20	7	17	0	2	17	0	0	4.0	
i 1	368.7383605442177	0.2525	74	702	5	1	16	17	0	1	17	0	0	2.0014753984039526	
i 1	368.7383605442177	0.505	73	702	4	20	3	17	0	2	17	0	0	4.0	
i 1	368.7431768707483	0.505	73	204	4	24	9	16	0	1	16	0	0	8.0	
i 1	368.74638775510203	0.2525	77	702	6	2	3	16	0	2	16	0	0	3.0	
i 1	368.75602040816324	0.505	74	1088	5	1	14	16	0	2	16	0	0	2.0014753984039526	
i 1	368.9835442176871	2.02	72	702	2	5	15	0	0	-1	0	0	0	2.0	
i 1	368.99558503401363	0.2525	74	204	5	4	4	16	0	1	16	0	0	3.0	
i 1	369.00361224489797	1.5150000000000001	69	204	4	5	11	1	0	-1	1	0	0	2.0	
i 1	369.01404761904763	0.505	74	702	6	2	11	17	0	2	17	0	0	3.0	
i 1	369.0164557823129	2.2725	77	702	3	24	8	16	0	1	16	0	0	3.0014753984039526	
i 1	369.23996598639457	2.2725	77	702	6	2	10	16	0	2	16	0	0	3.0	
i 1	369.24478231292517	0.7575000000000001	73	702	2	20	1	17	0	1	17	0	0	4.0	
i 1	369.25602040816324	2.7775	76	1088	3	20	15	16	0	2	16	0	0	4.0	
i 1	369.26003401360543	3.2825	73	702	2	24	15	16	0	2	16	0	0	8.0	
i 1	369.26886394557823	2.02	77	204	5	24	4	17	0	1	17	0	0	3.0014753984039526	
i 1	369.49076870748297	2.02	77	1088	5	9	7	16	0	2	16	0	0	2.0	
i 1	369.49237414965984	1.7675	69	702	4	5	4	0	0	0	0	0	0	2.0	
i 1	369.50040136054423	2.525	72	1088	3	5	15	1	0	-1	1	0	0	2.0	
i 1	370.2696666666667	2.02	74	204	5	1	8	16	0	2	16	0	0	2.0014753984039526	
i 1	370.49076870748297	0.7575000000000001	74	702	5	1	10	17	0	1	17	0	0	2.0014753984039526	
i 1	370.49478231292517	0.505	72	204	4	5	5	1	0	-1	1	0	0	2.0	
i 1	370.50441496598637	2.02	74	702	6	2	3	17	0	2	17	0	0	3.0	
i 1	370.5164557823129	2.02	77	1088	5	9	6	16	0	2	16	0	0	2.0	
i 1	370.98514965986396	0.2525	69	204	4	5	3	1	0	-1	1	0	0	2.0	
i 1	371.00040136054423	1.5150000000000001	73	1088	3	20	15	17	0	1	17	0	0	4.0	
i 1	371.00842857142857	0.2525	69	702	4	5	13	0	0	-1	0	0	0	2.0	
i 1	371.01404761904763	1.7675	76	1088	3	20	1	17	0	2	17	0	0	4.0	
i 1	371.23193877551023	1.01	74	702	4	1	13	17	0	1	17	0	0	2.0014753984039526	
i 1	371.24076870748297	1.7675	72	204	4	5	3	1	0	-1	1	0	0	2.0	
i 1	371.24237414965984	5.05	61	702	6	17	6	6	0	2	6	0	0	1.132643730431941	
i 1	371.24237414965984	2.02	69	702	3	5	4	0	0	-1	0	0	0	2.0	
i 1	371.24558503401363	0.2525	74	1088	4	1	1	16	0	2	16	0	0	2.0014753984039526	
i 1	371.24959863945577	5.05	61	204	6	13	2	9	0	1	9	0	0	0.9846220044962098	
i 1	371.25040136054423	5.05	66	204	7	7	14	9	0	2	9	0	0	2.484788109882402	
i 1	371.2568231292517	0.7575000000000001	69	702	6	5	5	0	0	0	0	0	0	2.0	
i 1	371.26324489795917	5.05	61	702	3	14	2	9	0	1	9	0	0	3.2348711625754984	
i 1	371.26725850340137	0.2525	74	702	5	1	2	16	0	1	16	0	0	2.0014753984039526	
i 1	371.48595238095237	4.545	74	204	6	3	10	17	0	1	17	0	0	3.0	
i 1	371.4931768707483	6.0600000000000005	74	702	5	3	1	17	0	1	17	0	0	3.0	
i 1	371.49879591836736	1.5150000000000001	77	204	5	24	1	17	0	1	17	0	0	3.0014753984039526	
i 1	371.51806122448977	1.5150000000000001	77	702	4	24	8	16	0	1	16	0	0	3.0014753984039526	
i 1	371.99397959183676	2.02	74	1088	4	1	11	16	0	2	16	0	0	2.0014753984039526	
i 1	371.9979931972789	0.505	73	702	2	20	8	17	0	1	17	0	0	4.0	
i 1	372.0028095238095	1.01	69	702	4	5	13	0	0	-1	0	0	0	2.0	
i 1	372.00602040816324	2.2725	74	702	5	1	6	16	0	1	16	0	0	2.0014753984039526	
i 1	372.01725850340137	1.01	69	1088	3	5	12	0	0	0	0	0	0	2.0	
i 1	372.2343469387755	3.7875	72	1088	3	5	1	1	0	-1	1	0	0	2.0	
i 1	372.24157142857143	4.04	69	702	6	5	6	0	0	0	0	0	0	2.0	
i 1	372.4891632653061	0.505	76	702	4	20	2	17	0	2	17	0	0	4.0	
i 1	372.4979931972789	0.2525	77	702	6	2	6	16	0	2	16	0	0	3.0	
i 1	372.4979931972789	2.02	76	702	2	20	3	16	0	2	16	0	0	4.0	
i 1	372.50521768707483	2.525	74	702	2	4	6	17	0	1	17	0	0	3.0	
i 1	372.5068231292517	0.505	76	204	4	20	14	16	0	1	16	0	0	4.0	
i 1	372.51003401360543	0.505	73	702	4	20	16	16	0	1	16	0	0	4.0	
i 1	372.51806122448977	0.2525	73	204	4	24	8	16	0	2	16	0	0	8.0	
i 1	372.75842857142857	0.2525	74	702	6	2	13	17	0	2	17	0	0	3.0	
i 1	372.98514965986396	1.01	73	1088	3	20	6	17	0	1	17	0	0	4.0	
i 1	372.98996598639457	0.505	76	1088	3	20	1	16	0	1	16	0	0	4.0	
i 1	373.0068231292517	2.02	74	204	5	4	6	16	0	1	16	0	0	3.0	
i 1	373.00923129251703	2.525	74	702	5	1	7	17	0	1	17	0	0	2.0014753984039526	
i 1	373.01244217687076	0.505	72	702	2	5	3	0	0	-1	0	0	0	2.0	
i 1	373.01324489795917	2.2725	77	1088	4	1	11	17	0	2	17	0	0	2.0014753984039526	
i 1	373.01725850340137	1.01	73	702	2	20	1	17	0	2	17	0	0	4.0	
i 1	373.2343469387755	0.505	72	204	4	5	2	1	0	-1	1	0	0	2.0	
i 1	373.49397959183676	0.2525	69	1088	3	5	7	0	0	0	0	0	0	2.0	
i 1	373.73274149659863	0.2525	73	702	2	24	10	17	0	2	17	0	0	8.0	
i 1	373.73755782312924	0.2525	76	1088	3	20	10	16	0	1	16	0	0	4.0	
i 1	373.75521768707483	2.02	76	1088	3	20	13	17	0	2	17	0	0	4.0	
i 1	373.76003401360543	2.2725	73	1088	3	24	3	16	0	2	16	0	0	8.0	
i 1	373.76404761904763	0.505	69	702	3	5	8	0	0	-1	0	0	0	2.0	
i 1	373.98193877551023	0.2525	76	204	4	24	13	16	0	1	16	0	0	8.0	
i 1	373.99157142857143	0.7575000000000001	77	702	4	24	3	16	0	1	16	0	0	3.0014753984039526	
i 1	373.99959863945577	0.2525	76	702	4	20	2	16	0	1	16	0	0	4.0	
i 1	374.00120408163264	0.2525	69	702	4	5	6	0	0	-1	0	0	0	2.0	
i 1	374.0028095238095	0.2525	73	204	4	20	7	17	0	2	17	0	0	4.0	
i 1	374.01725850340137	0.2525	73	702	4	20	3	16	0	1	16	0	0	4.0	
i 1	374.2303333333333	2.02	74	204	5	1	8	16	0	2	16	0	0	2.0014753984039526	
i 1	374.2431768707483	1.2625	73	702	2	24	6	16	0	2	16	0	0	8.0	
i 1	374.2479931972789	0.2525	73	702	2	20	10	16	0	2	16	0	0	4.0	
i 1	374.2520068027211	0.2525	72	702	2	5	1	0	0	-1	0	0	0	2.0	
i 1	374.26244217687076	0.2525	73	1088	3	20	15	16	0	2	16	0	0	4.0	
i 1	374.26485034013604	1.2625	73	1088	3	20	5	17	0	2	17	0	0	4.0	
i 1	374.48193877551023	0.2525	72	204	4	5	3	1	0	-1	1	0	0	2.0	
i 1	374.75923129251703	1.5150000000000001	69	1088	3	5	8	0	0	0	0	0	0	2.0	
i 1	374.76244217687076	2.2725	74	702	4	1	6	17	0	1	17	0	0	2.0014753984039526	
i 1	374.9891632653061	2.02	76	702	2	24	7	17	0	1	17	0	0	8.0	
i 1	374.98996598639457	0.505	73	702	2	20	11	16	0	2	16	0	0	4.0	
i 1	375.00040136054423	1.2625	77	1088	5	9	5	16	0	2	16	0	0	2.0	
i 1	375.00120408163264	1.2625	77	702	6	2	14	16	0	2	16	0	0	3.0	
i 1	375.01324489795917	0.2525	72	204	4	5	14	1	0	-1	1	0	0	2.0	
i 1	375.24237414965984	1.01	69	702	4	5	6	0	0	-1	0	0	0	2.0	
i 1	375.25040136054423	0.2525	77	204	5	24	13	17	0	1	17	0	0	3.0014753984039526	
i 1	375.26244217687076	3.535	76	702	2	20	6	16	0	2	16	0	0	4.0	
i 1	375.48113605442177	0.505	74	702	5	1	9	16	0	1	16	0	0	2.0014753984039526	
i 1	375.48996598639457	0.2525	77	1088	4	1	2	17	0	2	17	0	0	2.0014753984039526	
i 1	375.49157142857143	0.505	73	702	4	20	8	17	0	1	17	0	0	4.0	
i 1	375.50842857142857	0.7575000000000001	73	204	4	24	14	17	0	1	17	0	0	8.0	
i 1	375.50923129251703	0.7575000000000001	76	204	4	20	15	17	0	2	17	0	0	4.0	
i 1	375.73193877551023	0.505	74	702	6	2	7	17	0	2	17	0	0	3.0	
i 1	375.9803333333333	0.2525	74	702	5	1	7	17	0	1	17	0	0	2.0014753984039526	
i 1	376.0020068027211	0.2525	73	702	4	20	13	17	0	1	17	0	0	4.0	
i 1	376.0028095238095	0.2525	74	1088	4	1	12	16	0	2	16	0	0	2.0014753984039526	
i 1	376.2335442176871	0.505	74	1088	6	2	14	17	0	2	17	0	0	3.0	
i 1	376.2343469387755	1.7675	77	1088	5	1	2	16	0	1	16	0	0	2.0014753984039526	
i 1	376.2343469387755	1.7675	66	702	6	7	1	6	5003	2	6	0	0	2.484788109882402	
i 1	376.23514965986396	22.22	61	1088	5	13	1	9	0	2	9	0	0	1.1963591514907852	
i 1	376.23595238095237	1.7675	77	204	5	1	5	17	0	1	17	0	0	2.0014753984039526	
i 1	376.2391632653061	29.0375	66	204	5	16	10	9	0	2	9	0	0	3.5476597547464057	
i 1	376.23996598639457	8.585	66	702	5	13	13	9	5003	2	9	0	0	0.9846220044962098	
i 1	376.24157142857143	1.2625	74	1088	6	2	10	16	0	2	16	0	0	3.0	
i 1	376.24157142857143	0.2525	76	702	4	24	1	17	5003	2	17	0	0	8.0	
i 1	376.24237414965984	0.2525	73	1088	4	20	2	16	0	1	16	0	0	4.0	
i 1	376.2431768707483	15.4025	66	1088	5	14	15	6	0	1	6	0	0	4.723310056374216	
i 1	376.24397959183676	1.7675	66	1088	5	14	4	6	0	1	6	0	0	3.2348711625754984	
i 1	376.24959863945577	29.0375	66	1088	6	17	13	9	0	1	9	0	0	1.132643730431941	
i 1	376.25040136054423	6.0600000000000005	69	204	4	5	2	0	0	-1	0	0	0	2.0	
i 1	376.25120408163264	0.505	74	204	6	9	4	16	0	1	16	0	0	2.0	
i 1	376.25361224489797	6.0600000000000005	72	1088	6	5	15	1	0	0	1	0	0	2.0	
i 1	376.2568231292517	29.0375	66	204	5	16	13	6	0	1	6	0	0	3.5476597547464057	
i 1	376.25842857142857	0.7575000000000001	69	1088	4	5	10	0	0	0	0	0	0	2.0	
i 1	376.25923129251703	3.0300000000000002	76	204	4	20	10	16	0	1	16	0	0	4.0	
i 1	376.2608367346939	0.2525	73	702	4	20	1	17	5003	2	17	0	0	4.0	
i 1	376.26324489795917	29.0375	66	702	5	15	4	9	5003	2	9	0	0	2.3720094531185953	
i 1	376.26725850340137	0.505	74	702	5	1	6	17	5003	1	17	0	0	2.0014753984039526	
i 1	376.26725850340137	29.0375	66	702	5	15	9	9	5003	2	9	0	0	2.3720094531185953	
i 1	376.26806122448977	22.22	66	1088	3	14	4	9	0	1	9	0	0	3.2348711625754984	
i 1	376.26886394557823	29.0375	61	1088	6	17	4	9	0	1	9	0	0	1.132643730431941	
i 1	376.48113605442177	1.5150000000000001	74	702	2	4	2	17	0	1	17	0	0	3.0	
i 1	376.48113605442177	1.2625	73	204	4	20	3	17	0	1	17	0	0	4.0	
i 1	376.49076870748297	0.505	72	702	4	5	2	1	5003	0	1	0	0	2.0	
i 1	376.49638775510203	4.7975	74	702	5	3	2	16	5003	2	16	0	0	3.0	
i 1	376.5028095238095	1.2625	76	702	2	24	16	17	5003	2	17	0	0	8.0	
i 1	376.50762585034016	0.505	73	702	2	20	8	17	5003	2	17	0	0	4.0	
i 1	376.98996598639457	1.5150000000000001	74	702	4	24	3	17	5003	2	17	0	0	3.0014753984039526	
i 1	377.01886394557823	1.01	72	204	4	5	3	1	0	0	1	0	0	2.0	
i 1	377.0196666666667	1.01	72	702	4	5	2	1	5003	0	1	0	0	2.0	
i 1	377.2528095238095	1.2625	74	204	5	1	9	17	0	1	17	0	0	2.0014753984039526	
i 1	377.5020068027211	0.7575000000000001	73	204	4	24	13	16	0	2	16	0	0	8.0	
i 1	377.5028095238095	0.2525	74	1088	6	2	5	17	0	2	17	0	0	3.0	
i 1	377.51003401360543	0.505	74	702	4	4	1	17	5003	2	17	0	0	3.0	
i 1	377.7335442176871	0.505	73	1088	4	20	15	16	0	1	16	0	0	4.0	
i 1	377.73755782312924	0.2525	77	702	4	24	2	16	0	1	16	0	0	3.0014753984039526	
i 1	377.74959863945577	0.505	73	702	4	20	13	17	5003	2	17	0	0	4.0	
i 1	377.7528095238095	1.7675	74	702	5	1	16	17	5003	1	17	0	0	2.0014753984039526	
i 1	377.7608367346939	0.2525	74	702	5	3	9	17	0	1	17	0	0	3.0	
i 1	377.7608367346939	0.505	76	702	4	24	9	17	5003	2	17	0	0	8.0	
i 1	377.7696666666667	0.505	73	1088	4	20	6	17	0	1	17	0	0	4.0	
i 1	377.9843469387755	1.5150000000000001	77	702	4	24	3	16	0	1	16	0	0	3.0014753984039526	
i 1	378.00441496598637	27.27	66	1088	3	14	4	6	0	1	6	0	0	3.2348711625754984	
i 1	378.00521768707483	13.635	66	702	6	7	6	6	5003	2	6	0	0	2.484788109882402	
i 1	378.00762585034016	5.05	76	702	2	24	10	17	0	1	17	0	0	8.0	
i 1	378.01003401360543	1.01	74	702	4	4	5	17	0	1	17	0	0	3.0	
i 1	378.01324489795917	27.27	61	702	6	17	14	6	5003	2	6	0	0	1.132643730431941	
i 1	378.01324489795917	0.2525	69	702	3	5	8	0	0	-1	0	0	0	2.0	
i 1	378.23675510204083	0.2525	77	204	6	9	14	17	0	2	17	0	0	2.0	
i 1	378.24638775510203	0.7575000000000001	76	204	4	20	2	16	0	1	16	0	0	4.0	
i 1	378.24638775510203	2.02	73	702	2	20	3	17	5003	2	17	0	0	4.0	
i 1	378.2479931972789	0.2525	74	1088	6	2	6	16	0	2	16	0	0	3.0	
i 1	378.2608367346939	0.505	72	702	4	5	11	1	5003	0	1	0	0	2.0	
i 1	378.26886394557823	0.505	73	204	4	20	14	17	0	1	17	0	0	4.0	
i 1	378.4835442176871	1.5150000000000001	74	204	6	9	16	16	0	1	16	0	0	2.0	
i 1	378.49397959183676	1.5150000000000001	74	702	4	4	2	17	5003	2	17	0	0	3.0	
i 1	378.50361224489797	0.2525	77	204	5	1	12	17	0	1	17	0	0	2.0014753984039526	
i 1	378.73595238095237	1.5150000000000001	74	702	4	24	2	17	5003	2	17	0	0	3.0014753984039526	
i 1	378.76244217687076	1.5150000000000001	74	204	5	1	8	17	0	1	17	0	0	2.0014753984039526	
i 1	378.76244217687076	0.505	72	204	4	5	15	1	0	0	1	0	0	2.0	
i 1	379.2303333333333	1.7675	74	702	4	4	11	17	0	1	17	0	0	3.0	
i 1	379.2343469387755	0.2525	73	204	4	24	16	16	0	2	16	0	0	8.0	
i 1	379.23755782312924	0.505	72	702	4	5	13	1	5003	0	1	0	0	2.0	
i 1	379.25923129251703	0.2525	76	702	2	24	14	17	5003	2	17	0	0	8.0	
i 1	379.48595238095237	2.2725	74	1088	5	1	6	17	0	2	17	0	0	2.0014753984039526	
i 1	379.50762585034016	0.7575000000000001	76	204	4	20	6	16	0	1	16	0	0	4.0	
i 1	379.51003401360543	2.2725	74	702	3	1	11	17	0	1	17	0	0	2.0014753984039526	
i 1	379.7335442176871	0.505	76	702	2	24	12	17	5003	2	17	0	0	8.0	
i 1	379.74076870748297	4.7975	76	702	2	20	5	16	0	2	16	0	0	4.0	
i 1	379.74397959183676	0.2525	69	702	3	5	4	0	0	-1	0	0	0	2.0	
i 1	379.75923129251703	1.01	76	204	4	20	7	16	0	1	16	0	0	4.0	
i 1	379.9843469387755	0.2525	72	204	4	5	6	1	0	0	1	0	0	2.0	
i 1	379.9931768707483	0.2525	74	1088	6	2	7	17	0	2	17	0	0	3.0	
i 1	379.9979931972789	2.7775	77	204	6	9	16	17	0	2	17	0	0	2.0	
i 1	379.99959863945577	1.01	73	204	4	24	8	16	0	2	16	0	0	8.0	
i 1	380.00842857142857	0.2525	73	204	4	20	15	17	0	1	17	0	0	4.0	
i 1	380.23193877551023	0.2525	77	702	4	24	8	16	0	1	16	0	0	3.0014753984039526	
i 1	380.24879591836736	0.2525	76	1088	4	20	15	17	0	2	17	0	0	4.0	
i 1	380.26003401360543	0.2525	69	702	3	5	11	0	0	-1	0	0	0	2.0	
i 1	380.26485034013604	0.2525	73	1088	4	20	11	16	0	2	16	0	0	4.0	
i 1	380.2656530612245	0.2525	76	702	4	24	7	17	5003	2	17	0	0	8.0	
i 1	380.2696666666667	0.2525	73	702	4	20	2	17	5003	2	17	0	0	4.0	
i 1	380.48113605442177	1.5150000000000001	73	702	2	20	2	17	5003	2	17	0	0	4.0	
i 1	380.4883605442177	0.7575000000000001	72	702	4	5	2	1	5003	0	1	0	0	2.0	
i 1	380.49076870748297	0.505	73	204	4	20	6	17	0	1	17	0	0	4.0	
i 1	380.49076870748297	1.5150000000000001	76	702	2	24	5	17	5003	2	17	0	0	8.0	
i 1	380.51324489795917	0.505	69	1088	6	5	9	0	0	0	0	0	0	2.0	
i 1	380.5156530612245	2.2725	74	1088	6	2	9	17	0	2	17	0	0	3.0	
i 1	380.51725850340137	0.2525	77	1088	6	1	1	16	0	1	16	0	0	2.0014753984039526	
i 1	380.76725850340137	0.2525	77	204	5	1	15	17	0	1	17	0	0	2.0014753984039526	
i 1	380.99959863945577	0.2525	77	702	4	24	15	16	0	1	16	0	0	3.0014753984039526	
i 1	381.2343469387755	0.2525	69	702	3	5	10	0	0	-1	0	0	0	2.0	
i 1	381.2528095238095	2.2725	77	204	5	1	1	17	0	1	17	0	0	2.0014753984039526	
i 1	381.25762585034016	2.2725	77	1088	6	1	11	16	0	1	16	0	0	2.0014753984039526	
i 1	381.26324489795917	0.2525	74	204	6	9	14	16	0	1	16	0	0	2.0	
i 1	381.2664557823129	0.2525	72	204	4	5	1	1	0	0	1	0	0	2.0	
i 1	381.26806122448977	0.7575000000000001	74	702	5	3	11	17	0	1	17	0	0	3.0	
i 1	381.4835442176871	1.7675	72	702	2	5	4	0	0	-1	0	0	0	2.0	
i 1	381.5164557823129	1.7675	69	1088	6	5	14	0	0	0	0	0	0	2.0	
i 1	381.74879591836736	0.2525	74	702	5	1	8	17	5003	1	17	0	0	2.0014753984039526	
i 1	381.98274149659863	0.2525	76	702	4	24	16	17	5003	2	17	0	0	8.0	
i 1	381.98996598639457	0.2525	73	702	4	20	12	17	5003	2	17	0	0	4.0	
i 1	381.99558503401363	0.2525	74	204	6	9	13	16	0	1	16	0	0	2.0	
i 1	382.0196666666667	0.2525	74	702	3	1	15	17	0	1	17	0	0	2.0014753984039526	
i 1	382.23996598639457	1.5150000000000001	74	702	5	3	5	17	0	1	17	0	0	3.0	
i 1	382.25120408163264	1.2625	69	702	3	5	15	0	0	-1	0	0	0	2.0	
i 1	382.2520068027211	2.7775	74	702	5	1	12	17	5003	1	17	0	0	2.0014753984039526	
i 1	382.25441496598637	0.505	73	702	2	20	11	17	5003	2	17	0	0	4.0	
i 1	382.2616394557823	1.7675	74	1088	6	2	15	16	0	2	16	0	0	3.0	
i 1	382.26485034013604	1.01	73	204	4	24	12	16	0	2	16	0	0	8.0	
i 1	382.51806122448977	1.01	72	702	4	5	7	1	5003	0	1	0	0	2.0	
i 1	382.7343469387755	1.7675	77	702	4	24	8	16	0	1	16	0	0	3.0014753984039526	
i 1	382.7391632653061	1.7675	74	702	4	4	2	17	0	1	17	0	0	3.0	
i 1	382.73996598639457	0.2525	73	1088	4	20	8	16	0	2	16	0	0	4.0	
i 1	382.73996598639457	0.2525	76	702	4	24	1	17	5003	2	17	0	0	8.0	
i 1	382.7471904761905	0.2525	74	204	6	9	13	16	0	1	16	0	0	2.0	
i 1	382.76485034013604	2.7775	76	204	4	20	11	16	0	1	16	0	0	4.0	
i 1	382.76886394557823	0.2525	73	702	4	20	16	17	5003	2	17	0	0	4.0	
i 1	382.98514965986396	2.02	72	1088	6	5	12	1	0	0	1	0	0	2.0	
i 1	382.98675510204083	6.3125	69	204	4	5	14	0	0	-1	0	0	0	2.0	
i 1	382.99157142857143	0.2525	73	702	2	20	7	17	5003	2	17	0	0	4.0	
i 1	383.0020068027211	1.5150000000000001	74	702	5	3	2	16	5003	2	16	0	0	3.0	
i 1	383.00441496598637	1.5150000000000001	76	702	2	24	14	17	5003	2	17	0	0	8.0	
i 1	383.00521768707483	2.2725	73	204	4	20	7	17	0	2	17	0	0	4.0	
i 1	383.49237414965984	0.2525	72	702	2	5	8	0	0	-1	0	0	0	2.0	
i 1	383.5164557823129	0.2525	74	1088	5	1	4	17	0	2	17	0	0	2.0014753984039526	
i 1	383.74157142857143	0.2525	74	204	5	1	1	17	0	1	17	0	0	2.0014753984039526	
i 1	383.7520068027211	0.2525	72	702	4	5	9	1	5003	0	1	0	0	2.0	
i 1	383.99157142857143	13.8875	76	702	2	24	1	17	0	1	17	0	0	8.0	
i 1	383.99959863945577	1.5150000000000001	74	702	4	4	8	17	5003	2	17	0	0	3.0	
i 1	384.00361224489797	1.5150000000000001	74	204	6	9	12	16	0	1	16	0	0	2.0	
i 1	384.00762585034016	2.2725	77	204	5	1	11	17	0	1	17	0	0	2.0014753984039526	
i 1	384.01324489795917	2.02	77	1088	6	1	2	16	0	1	16	0	0	2.0014753984039526	
i 1	384.01404761904763	1.2625	73	702	2	20	3	17	5003	2	17	0	0	4.0	
i 1	384.23514965986396	0.2525	69	1088	6	5	13	0	0	0	0	0	0	2.0	
i 1	384.48675510204083	2.02	72	204	4	5	13	1	0	0	1	0	0	2.0	
i 1	384.48755782312924	1.5150000000000001	72	702	4	5	5	1	5003	0	1	0	0	2.0	
i 1	384.50923129251703	0.2525	74	1088	6	2	12	17	0	2	17	0	0	3.0	
i 1	384.51003401360543	0.2525	77	204	6	9	3	17	0	2	17	0	0	2.0	
i 1	384.74397959183676	20.4525	66	702	3	13	13	9	5003	2	9	0	0	0.9846220044962098	
i 1	384.75040136054423	0.2525	74	1088	6	2	14	16	0	2	16	0	0	3.0	
i 1	384.76806122448977	20.4525	66	702	6	17	1	9	5003	1	9	0	0	1.132643730431941	
i 1	384.9883605442177	2.2725	74	702	5	3	10	16	5003	2	16	0	0	3.0	
i 1	384.9883605442177	0.2525	69	1088	6	5	10	0	0	0	0	0	0	2.0	
i 1	384.9971904761905	0.2525	74	702	3	1	6	17	0	1	17	0	0	2.0014753984039526	
i 1	385.00361224489797	2.7775	76	702	2	20	12	16	0	2	16	0	0	4.0	
i 1	385.01806122448977	2.2725	74	702	4	4	4	17	0	1	17	0	0	3.0	
i 1	385.2383605442177	0.2525	76	702	4	24	7	17	5003	2	17	0	0	8.0	
i 1	385.24076870748297	0.2525	73	1088	4	20	4	16	0	1	16	0	0	4.0	
i 1	385.24157142857143	4.04	72	1088	6	5	5	1	0	0	1	0	0	2.0	
i 1	385.24237414965984	0.2525	73	702	4	20	14	17	5003	2	17	0	0	4.0	
i 1	385.2479931972789	0.2525	74	1088	6	1	3	17	0	2	17	0	0	2.0014753984039526	
i 1	385.48514965986396	0.2525	74	1088	6	2	5	17	0	2	17	0	0	3.0	
i 1	385.49558503401363	1.7675	76	702	2	24	6	17	5003	2	17	0	0	8.0	
i 1	385.5028095238095	1.7675	73	702	2	20	12	17	5003	2	17	0	0	4.0	
i 1	385.5116394557823	1.5150000000000001	74	204	5	1	8	17	0	1	17	0	0	2.0014753984039526	
i 1	385.51806122448977	1.5150000000000001	74	702	4	24	10	17	5003	2	17	0	0	3.0014753984039526	
i 1	385.75361224489797	0.2525	77	204	6	9	5	17	0	2	17	0	0	2.0	
i 1	385.9971904761905	0.505	74	702	4	4	16	17	5003	2	17	0	0	3.0	
i 1	386.2664557823129	0.2525	74	702	3	1	9	17	0	1	17	0	0	2.0014753984039526	
i 1	386.49397959183676	2.02	77	702	3	24	14	16	0	1	16	0	0	3.0014753984039526	
i 1	386.49558503401363	0.2525	74	702	5	3	14	17	0	1	17	0	0	3.0	
i 1	386.49638775510203	2.02	74	702	5	1	10	17	5003	1	17	0	0	2.0014753984039526	
i 1	386.5068231292517	0.2525	69	1088	6	5	8	0	0	0	0	0	0	2.0	
i 1	386.7343469387755	0.505	73	204	4	20	5	16	0	1	16	0	0	4.0	
i 1	386.75361224489797	0.7575000000000001	73	204	4	24	12	16	0	2	16	0	0	8.0	
i 1	386.75923129251703	0.505	72	702	2	5	6	0	0	-1	0	0	0	2.0	
i 1	386.76244217687076	2.02	74	1088	6	2	13	17	0	2	17	0	0	3.0	
i 1	386.7656530612245	2.02	77	204	6	9	1	17	0	2	17	0	0	2.0	
i 1	387.00361224489797	0.2525	76	204	4	20	9	16	0	2	16	0	0	4.0	
i 1	387.0108367346939	0.2525	77	1088	6	1	4	16	0	1	16	0	0	2.0014753984039526	
i 1	387.2303333333333	0.2525	69	702	3	5	3	0	0	-1	0	0	0	2.0	
i 1	387.2471904761905	0.2525	73	702	4	20	5	17	5003	2	17	0	0	4.0	
i 1	387.2520068027211	0.2525	76	1088	4	20	12	16	0	1	16	0	0	4.0	
i 1	387.25361224489797	0.2525	74	204	5	1	12	17	0	1	17	0	0	2.0014753984039526	
i 1	387.25602040816324	0.2525	74	702	4	4	8	17	5003	2	17	0	0	3.0	
i 1	387.25762585034016	0.2525	73	1088	4	20	10	16	0	2	16	0	0	4.0	
i 1	387.25842857142857	2.02	76	204	4	20	13	16	0	1	16	0	0	4.0	
i 1	387.49959863945577	1.5150000000000001	76	204	4	20	8	16	0	2	16	0	0	4.0	
i 1	387.51485034013604	0.2525	74	702	4	4	4	17	0	1	17	0	0	3.0	
i 1	387.51725850340137	1.5150000000000001	73	702	2	20	13	17	5003	2	17	0	0	4.0	
i 1	387.5196666666667	0.2525	72	702	2	5	13	0	0	-1	0	0	0	2.0	
i 1	387.75441496598637	1.01	72	204	4	5	10	1	0	0	1	0	0	2.0	
i 1	387.7568231292517	0.2525	74	1088	6	1	1	17	0	2	17	0	0	2.0014753984039526	
i 1	387.99076870748297	0.2525	74	204	6	9	15	16	0	1	16	0	0	2.0	
i 1	388.00521768707483	2.02	74	204	5	1	7	17	0	1	17	0	0	2.0014753984039526	
i 1	388.0116394557823	2.02	74	702	4	24	14	17	5003	2	17	0	0	3.0014753984039526	
i 1	388.2431768707483	0.7575000000000001	74	702	5	3	4	17	0	1	17	0	0	3.0	
i 1	388.2479931972789	0.7575000000000001	74	1088	6	2	14	16	0	2	16	0	0	3.0	
i 1	388.4803333333333	2.2725	74	702	5	3	16	16	5003	2	16	0	0	3.0	
i 1	388.48675510204083	0.2525	74	702	3	1	2	17	0	1	17	0	0	2.0014753984039526	
i 1	388.49237414965984	2.2725	74	702	4	4	3	17	0	1	17	0	0	3.0	
i 1	388.73193877551023	0.2525	76	702	2	24	4	17	5003	2	17	0	0	8.0	
i 1	388.73514965986396	2.02	72	702	2	5	11	0	0	-1	0	0	0	2.0	
i 1	388.73595238095237	1.7675	76	702	2	20	3	16	0	2	16	0	0	4.0	
i 1	388.74879591836736	2.02	69	1088	6	5	15	0	0	0	0	0	0	2.0	
i 1	388.75762585034016	0.505	74	702	5	1	9	17	5003	1	17	0	0	2.0014753984039526	
i 1	388.76244217687076	0.7575000000000001	73	204	4	24	2	16	0	2	16	0	0	8.0	
i 1	388.9883605442177	0.2525	74	1088	6	2	3	17	0	2	17	0	0	3.0	
i 1	388.9891632653061	0.2525	73	702	4	20	9	17	5003	2	17	0	0	4.0	
i 1	388.98996598639457	0.2525	76	1088	4	20	13	16	0	2	16	0	0	4.0	
i 1	389.0108367346939	0.2525	76	702	4	24	4	17	5003	2	17	0	0	8.0	
i 1	389.23595238095237	0.7575000000000001	73	702	2	20	2	17	5003	2	17	0	0	4.0	
i 1	389.23675510204083	0.2525	72	702	6	5	9	1	5003	0	1	0	0	2.0	
i 1	389.24879591836736	0.2525	77	702	3	24	13	16	0	1	16	0	0	3.0014753984039526	
i 1	389.24879591836736	0.2525	74	702	5	3	6	17	0	1	17	0	0	3.0	
i 1	389.26244217687076	0.7575000000000001	76	702	2	24	4	17	5003	2	17	0	0	8.0	
i 1	389.49157142857143	0.2525	69	702	3	5	5	0	0	-1	0	0	0	2.0	
i 1	389.5020068027211	1.7675	74	1088	6	1	14	17	0	2	17	0	0	2.0014753984039526	
i 1	389.51324489795917	0.2525	77	204	6	9	11	17	0	2	17	0	0	2.0	
i 1	389.51806122448977	1.7675	74	702	3	1	6	17	0	1	17	0	0	2.0014753984039526	
i 1	389.7383605442177	0.505	74	1088	6	2	2	16	0	2	16	0	0	3.0	
i 1	389.75842857142857	0.2525	76	204	4	20	14	17	0	1	17	0	0	4.0	
i 1	389.9843469387755	0.2525	74	702	5	1	7	17	5003	1	17	0	0	2.0014753984039526	
i 1	389.9883605442177	3.0300000000000002	76	204	4	20	14	16	0	1	16	0	0	4.0	
i 1	390.0020068027211	0.2525	76	702	4	24	13	17	5003	2	17	0	0	8.0	
i 1	390.0028095238095	1.7675	69	702	3	5	7	0	0	-1	0	0	0	2.0	
i 1	390.01485034013604	0.2525	76	1088	4	20	9	16	0	2	16	0	0	4.0	
i 1	390.01886394557823	0.2525	73	702	4	20	6	17	5003	2	17	0	0	4.0	
i 1	390.24397959183676	1.7675	74	204	6	9	15	16	0	1	16	0	0	2.0	
i 1	390.24478231292517	0.2525	74	204	5	1	6	17	0	1	17	0	0	2.0014753984039526	
i 1	390.25602040816324	1.5150000000000001	73	702	2	20	11	17	5003	2	17	0	0	4.0	
i 1	390.25923129251703	1.2625	76	204	4	20	13	17	0	1	17	0	0	4.0	
i 1	390.26324489795917	1.5150000000000001	74	702	4	4	6	17	5003	2	17	0	0	3.0	
i 1	390.26886394557823	1.5150000000000001	72	702	6	5	3	1	5003	0	1	0	0	2.0	
i 1	390.48996598639457	1.5150000000000001	77	204	5	1	5	17	0	1	17	0	0	2.0014753984039526	
i 1	390.73595238095237	0.2525	74	1088	6	2	8	16	0	2	16	0	0	3.0	
i 1	390.75842857142857	0.2525	72	1088	6	5	15	1	0	0	1	0	0	2.0	
i 1	390.7608367346939	1.2625	77	1088	6	1	2	16	0	1	16	0	0	2.0014753984039526	
i 1	390.9883605442177	0.2525	69	1088	6	5	16	0	0	0	0	0	0	2.0	
i 1	390.99558503401363	1.01	73	204	4	24	8	16	0	2	16	0	0	8.0	
i 1	391.01485034013604	2.2725	74	702	4	4	6	17	0	1	17	0	0	3.0	
i 1	391.0156530612245	0.7575000000000001	76	204	4	20	9	17	0	1	17	0	0	4.0	
i 1	391.2343469387755	1.01	72	1088	6	5	13	1	0	0	1	0	0	2.0	
i 1	391.2391632653061	2.2725	74	702	5	3	1	16	5003	2	16	0	0	3.0	
i 1	391.2528095238095	0.2525	74	702	4	24	10	17	5003	2	17	0	0	3.0014753984039526	
i 1	391.25602040816324	1.01	69	204	4	5	5	0	0	-1	0	0	0	2.0	
i 1	391.48193877551023	1.7675	74	702	6	1	4	17	5003	1	17	0	0	2.0014753984039526	
i 1	391.49157142857143	13.635	61	204	5	18	2	9	0	2	9	0	0	1.132643730431941	
i 1	391.49237414965984	1.2625	77	702	3	24	5	16	0	1	16	0	0	3.0014753984039526	
i 1	391.49558503401363	13.635	66	702	4	7	8	6	5003	2	6	0	0	2.484788109882402	
i 1	391.50120408163264	6.8175	66	1088	5	14	9	6	0	1	6	0	0	4.723310056374216	
i 1	391.51244217687076	0.7575000000000001	76	702	2	20	12	16	0	2	16	0	0	4.0	
i 1	391.73996598639457	0.2525	76	1088	4	20	13	16	0	1	16	0	0	4.0	
i 1	391.7431768707483	2.2725	72	702	6	5	1	1	5003	0	1	0	0	2.0	
i 1	391.7431768707483	2.02	72	204	4	5	16	1	0	0	1	0	0	2.0	
i 1	391.76244217687076	0.2525	73	702	4	20	10	17	5003	2	17	0	0	4.0	
i 1	391.76806122448977	0.2525	73	1088	4	20	16	16	0	2	16	0	0	4.0	
i 1	391.9803333333333	0.2525	76	204	4	20	3	17	0	1	17	0	0	4.0	
i 1	392.00120408163264	0.2525	77	204	6	9	8	17	0	2	17	0	0	2.0	
i 1	392.00923129251703	0.2525	74	1088	6	1	9	17	0	2	17	0	0	2.0014753984039526	
i 1	392.01485034013604	0.7575000000000001	73	204	4	20	10	17	0	2	17	0	0	4.0	
i 1	392.0164557823129	0.7575000000000001	73	702	2	20	8	17	5003	2	17	0	0	4.0	
i 1	392.23514965986396	3.0300000000000002	77	204	5	1	6	17	0	1	17	0	0	2.0014753984039526	
i 1	392.2568231292517	0.2525	69	1088	6	5	6	0	0	0	0	0	0	2.0	
i 1	392.26485034013604	3.0300000000000002	77	1088	6	1	3	16	0	1	16	0	0	2.0014753984039526	
i 1	392.2696666666667	2.2725	74	1088	6	2	13	17	0	2	17	0	0	3.0	
i 1	392.4835442176871	1.01	76	702	2	20	9	16	0	2	16	0	0	4.0	
i 1	392.51003401360543	5.05	72	1088	6	5	7	1	0	0	1	0	0	2.0	
i 1	392.74397959183676	0.505	76	1088	4	20	7	17	0	2	17	0	0	4.0	
i 1	392.74397959183676	0.505	73	702	4	20	4	17	5003	2	17	0	0	4.0	
i 1	392.74558503401363	1.7675	77	204	6	9	5	17	0	2	17	0	0	2.0	
i 1	393.2335442176871	0.2525	76	204	4	20	1	16	0	2	16	0	0	4.0	
i 1	393.24076870748297	1.7675	73	702	2	20	4	17	5003	2	17	0	0	4.0	
i 1	393.2431768707483	0.2525	74	702	4	24	2	17	5003	2	17	0	0	3.0014753984039526	
i 1	393.25602040816324	4.2925	69	204	4	5	1	0	0	-1	0	0	0	2.0	
i 1	393.48113605442177	0.2525	76	204	4	20	4	16	0	1	16	0	0	4.0	
i 1	393.50040136054423	0.2525	74	702	4	4	4	17	0	1	17	0	0	3.0	
i 1	393.50842857142857	0.2525	74	1088	6	1	16	17	0	2	17	0	0	2.0014753984039526	
i 1	393.73193877551023	0.2525	76	204	4	20	4	16	0	2	16	0	0	4.0	
i 1	393.75521768707483	0.2525	74	702	5	3	14	16	5003	2	16	0	0	3.0	
i 1	393.98514965986396	1.2625	74	702	5	3	6	17	0	1	17	0	0	3.0	
i 1	393.98595238095237	1.01	76	702	2	24	16	17	5003	2	17	0	0	8.0	
i 1	394.00521768707483	1.5150000000000001	74	1088	6	2	6	16	0	2	16	0	0	3.0	
i 1	394.01404761904763	0.2525	72	702	6	5	16	1	5003	0	1	0	0	2.0	
i 1	394.01806122448977	1.01	76	702	2	20	11	16	0	2	16	0	0	4.0	
i 1	394.0196666666667	0.2525	74	204	5	1	2	17	0	1	17	0	0	2.0014753984039526	
i 1	394.25842857142857	0.2525	69	702	3	5	11	0	0	-1	0	0	0	2.0	
i 1	394.48193877551023	0.2525	72	204	4	5	8	1	0	0	1	0	0	2.0	
i 1	394.4835442176871	0.505	76	204	4	20	16	16	0	2	16	0	0	4.0	
i 1	394.50602040816324	4.7975	76	204	4	20	11	16	0	1	16	0	0	4.0	
i 1	394.51244217687076	0.2525	74	702	3	1	11	17	0	1	17	0	0	2.0014753984039526	
i 1	394.51725850340137	2.525	74	702	5	3	11	16	5003	2	16	0	0	3.0	
i 1	394.7391632653061	2.2725	74	702	4	4	12	17	0	1	17	0	0	3.0	
i 1	394.74558503401363	0.505	69	702	3	5	15	0	0	-1	0	0	0	2.0	
i 1	394.74959863945577	2.02	74	702	4	24	10	17	5003	2	17	0	0	3.0014753984039526	
i 1	394.75040136054423	2.02	74	204	5	1	6	17	0	1	17	0	0	2.0014753984039526	
i 1	394.99076870748297	0.2525	73	702	4	20	14	17	5003	2	17	0	0	4.0	
i 1	394.99237414965984	0.2525	73	1088	4	20	11	17	0	2	17	0	0	4.0	
i 1	395.2343469387755	0.505	74	702	3	1	12	17	0	1	17	0	0	2.0014753984039526	
i 1	395.24397959183676	1.01	76	204	4	20	6	17	0	2	17	0	0	4.0	
i 1	395.2479931972789	1.01	73	702	2	20	14	17	5003	2	17	0	0	4.0	
i 1	395.26886394557823	0.2525	72	702	6	5	16	1	5003	0	1	0	0	2.0	
i 1	395.49157142857143	0.2525	72	702	2	5	14	0	0	-1	0	0	0	2.0	
i 1	395.49558503401363	0.2525	74	702	5	3	7	17	0	1	17	0	0	3.0	
i 1	395.74959863945577	0.2525	74	204	6	9	4	16	0	1	16	0	0	2.0	
i 1	395.7656530612245	0.505	77	204	5	1	1	17	0	1	17	0	0	2.0014753984039526	
i 1	395.9835442176871	0.7575000000000001	76	702	2	20	10	16	0	2	16	0	0	4.0	
i 1	396.0156530612245	0.2525	74	1088	6	2	5	16	0	2	16	0	0	3.0	
i 1	396.23675510204083	2.02	77	702	3	24	6	16	0	1	16	0	0	3.0014753984039526	
i 1	396.2479931972789	1.7675	74	702	6	1	4	17	5003	1	17	0	0	2.0014753984039526	
i 1	396.25120408163264	0.2525	73	1088	4	20	1	16	0	2	16	0	0	4.0	
i 1	396.2520068027211	1.5150000000000001	74	204	6	9	2	16	0	1	16	0	0	2.0	
i 1	396.25762585034016	0.2525	73	702	4	20	1	17	5003	2	17	0	0	4.0	
i 1	396.4891632653061	1.2625	74	702	4	4	16	17	5003	2	17	0	0	3.0	
i 1	396.50040136054423	1.2625	73	702	2	20	5	17	5003	2	17	0	0	4.0	
i 1	396.5108367346939	2.525	76	204	4	20	2	17	0	2	17	0	0	4.0	
i 1	396.7303333333333	0.2525	69	702	3	5	15	0	0	-1	0	0	0	2.0	
i 1	396.73996598639457	0.2525	74	702	3	1	5	17	0	1	17	0	0	2.0014753984039526	
i 1	396.9883605442177	0.2525	74	204	5	1	10	17	0	1	17	0	0	2.0014753984039526	
i 1	396.9971904761905	1.01	69	1088	6	5	9	0	0	0	0	0	0	2.0	
i 1	397.00040136054423	0.2525	77	204	6	9	11	17	0	2	17	0	0	2.0	
i 1	397.00441496598637	1.2625	72	702	2	5	8	0	0	-1	0	0	0	2.0	
i 1	397.23113605442177	0.2525	77	204	5	1	14	17	0	1	17	0	0	2.0014753984039526	
i 1	397.2479931972789	1.01	76	702	2	20	16	16	0	2	16	0	0	4.0	
i 1	397.25040136054423	1.2625	76	702	2	24	15	17	5003	2	17	0	0	8.0	
i 1	397.2616394557823	1.7675	74	702	4	4	7	17	0	1	17	0	0	3.0	
i 1	397.26725850340137	1.7675	74	702	5	3	15	16	5003	2	16	0	0	3.0	
i 1	397.48274149659863	2.02	72	702	6	5	16	1	5003	0	1	0	0	2.0	
i 1	397.48595238095237	1.2625	74	204	5	1	14	17	0	1	17	0	0	2.0014753984039526	
i 1	397.50441496598637	2.525	69	702	3	5	10	0	0	-1	0	0	0	2.0	
i 1	397.50842857142857	0.7575000000000001	74	702	4	24	8	17	5003	2	17	0	0	3.0014753984039526	
i 1	397.76806122448977	0.505	74	1088	6	2	13	16	0	2	16	0	0	3.0	
i 1	398.23193877551023	6.8175	66	204	5	18	16	9	0	2	9	0	0	1.132643730431941	
i 1	398.24397959183676	0.2525	72	1088	6	5	5	1	0	0	1	0	0	2.0	
i 1	398.25120408163264	2.525	74	1088	6	2	3	17	0	2	17	0	0	3.0	
i 1	398.25361224489797	6.8175	61	1088	5	13	8	9	0	2	9	0	0	1.1963591514907852	
i 1	398.25762585034016	0.7575000000000001	74	702	4	24	5	17	5003	2	17	0	0	3.0014753984039526	
i 1	398.26806122448977	1.2625	74	1088	6	1	3	17	0	2	17	0	0	2.0014753984039526	
i 1	398.26886394557823	1.2625	74	702	3	1	16	17	0	1	17	0	0	2.0014753984039526	
i 1	398.2696666666667	6.8175	66	1088	4	14	11	9	0	1	9	0	0	3.2348711625754984	
i 1	398.48675510204083	2.02	76	702	2	24	2	17	0	1	17	0	0	8.0	
i 1	398.49558503401363	2.2725	77	204	6	9	5	17	0	2	17	0	0	2.0	
i 1	398.5116394557823	0.505	72	204	7	5	14	1	0	0	1	0	0	2.0	
i 1	398.7383605442177	0.2525	73	702	2	20	12	17	5003	2	17	0	0	4.0	
i 1	398.7520068027211	1.7675	76	702	2	20	2	16	0	2	16	0	0	4.0	
i 1	398.98755782312924	0.2525	74	1088	6	2	12	16	0	2	16	0	0	3.0	
i 1	398.99558503401363	6.0600000000000005	69	204	4	5	6	0	0	-1	0	0	0	2.0	
i 1	398.99959863945577	0.505	73	1088	4	20	3	16	0	1	16	0	0	4.0	
i 1	399.00521768707483	6.8175	72	1088	6	5	16	1	0	0	1	0	0	2.0	
i 1	399.00762585034016	1.7675	77	1088	6	1	13	16	0	1	16	0	0	2.0014753984039526	
i 1	399.0156530612245	0.505	73	702	4	20	10	17	5003	2	17	0	0	4.0	
i 1	399.0196666666667	1.5150000000000001	77	204	5	1	13	17	0	1	17	0	0	2.0014753984039526	
i 1	399.24879591836736	0.2525	74	702	4	4	6	17	5003	2	17	0	0	3.0	
i 1	399.49397959183676	0.505	73	702	2	20	7	17	5003	2	17	0	0	4.0	
i 1	399.51404761904763	0.2525	77	702	3	24	3	16	0	1	16	0	0	3.0014753984039526	
i 1	399.5156530612245	0.505	76	204	4	20	2	16	0	1	16	0	0	4.0	
i 1	399.7568231292517	0.2525	74	204	5	1	16	17	0	1	17	0	0	2.0014753984039526	
i 1	399.75762585034016	0.2525	74	702	4	4	12	17	5003	2	17	0	0	3.0	
i 1	399.98996598639457	0.7575000000000001	72	204	7	5	12	1	0	0	1	0	0	2.0	
i 1	399.9931768707483	0.7575000000000001	72	702	6	5	4	1	5003	0	1	0	0	2.0	
i 1	399.99879591836736	1.5150000000000001	74	702	5	3	7	17	0	1	17	0	0	3.0	
i 1	399.99959863945577	0.2525	73	702	4	20	6	17	5003	2	17	0	0	4.0	
i 1	399.99959863945577	1.5150000000000001	76	204	4	20	8	16	0	1	16	0	0	4.0	
i 1	400.0068231292517	2.02	77	702	3	24	14	16	0	1	16	0	0	3.0014753984039526	
i 1	400.00842857142857	2.2725	74	702	6	1	13	17	5003	1	17	0	0	2.0014753984039526	
i 1	400.00923129251703	0.2525	76	1088	4	20	3	16	0	2	16	0	0	4.0	
i 1	400.2303333333333	0.2525	73	702	2	20	8	17	5003	2	17	0	0	4.0	
i 1	400.2471904761905	1.2625	74	1088	6	2	15	16	0	2	16	0	0	3.0	
i 1	400.2696666666667	1.2625	73	204	4	20	5	17	0	1	17	0	0	4.0	
i 1	400.49638775510203	0.2525	73	204	4	24	4	16	0	2	16	0	0	8.0	
i 1	400.73113605442177	1.7675	74	702	5	3	9	16	5003	2	16	0	0	3.0	
i 1	400.7343469387755	1.01	76	702	2	24	10	17	0	1	17	0	0	8.0	
i 1	400.73595238095237	0.2525	69	1088	6	5	11	0	0	0	0	0	0	2.0	
i 1	400.76324489795917	0.2525	74	702	3	1	14	17	0	1	17	0	0	2.0014753984039526	
i 1	400.98675510204083	1.7675	74	702	4	4	4	17	0	1	17	0	0	3.0	
i 1	400.99397959183676	0.2525	77	1088	6	1	16	16	0	1	16	0	0	2.0014753984039526	
i 1	400.99638775510203	0.505	76	702	2	24	11	17	5003	2	17	0	0	8.0	
i 1	400.9971904761905	0.2525	72	702	2	5	8	0	0	-1	0	0	0	2.0	
i 1	401.00441496598637	0.505	73	702	2	20	1	17	5003	2	17	0	0	4.0	
i 1	401.0068231292517	1.5150000000000001	76	702	2	20	7	16	0	2	16	0	0	4.0	
i 1	401.2383605442177	0.2525	74	702	3	1	10	17	0	1	17	0	0	2.0014753984039526	
i 1	401.26725850340137	0.7575000000000001	73	204	4	24	3	16	0	2	16	0	0	8.0	
i 1	401.4835442176871	3.2825	77	1088	6	1	1	16	0	1	16	0	0	2.0014753984039526	
i 1	401.49638775510203	0.2525	74	702	4	4	11	17	5003	2	17	0	0	3.0	
i 1	401.50602040816324	0.2525	76	702	4	24	11	17	5003	2	17	0	0	8.0	
i 1	401.51324489795917	0.2525	73	702	4	20	3	17	5003	2	17	0	0	4.0	
i 1	401.51886394557823	3.2825	77	204	5	1	8	17	0	1	17	0	0	2.0014753984039526	
i 1	401.73113605442177	0.7575000000000001	76	702	2	24	9	17	5003	2	17	0	0	8.0	
i 1	401.7431768707483	1.7675	74	204	6	9	11	16	0	1	16	0	0	2.0	
i 1	401.7568231292517	1.2625	73	702	2	20	5	17	5003	2	17	0	0	4.0	
i 1	401.9803333333333	1.01	76	204	4	20	5	17	0	2	17	0	0	4.0	
i 1	401.99076870748297	1.5150000000000001	74	702	4	4	5	17	5003	2	17	0	0	3.0	
i 1	401.9979931972789	3.2825	76	702	2	24	8	17	0	1	17	0	0	8.0	
i 1	402.0028095238095	0.2525	72	702	6	5	1	1	5003	0	1	0	0	2.0	
i 1	402.00842857142857	4.7975	76	204	4	20	2	16	0	1	16	0	0	4.0	
i 1	402.48193877551023	0.2525	72	702	2	5	8	0	0	-1	0	0	0	2.0	
i 1	402.5196666666667	0.505	74	702	4	24	16	17	5003	2	17	0	0	3.0014753984039526	
i 1	402.73514965986396	0.2525	74	702	5	3	5	17	0	1	17	0	0	3.0	
i 1	402.7616394557823	0.2525	72	702	6	5	14	1	5003	0	1	0	0	2.0	
i 1	402.9843469387755	0.2525	73	702	4	20	5	17	5003	2	17	0	0	4.0	
i 1	402.99237414965984	2.02	74	702	5	3	12	16	5003	2	16	0	0	3.0	
i 1	402.99638775510203	0.2525	73	1088	4	20	7	17	0	1	17	0	0	4.0	
i 1	403.00762585034016	2.02	74	702	4	4	2	17	0	1	17	0	0	3.0	
i 1	403.0164557823129	0.2525	77	702	3	24	14	16	0	1	16	0	0	3.0014753984039526	
i 1	403.23113605442177	0.7575000000000001	76	204	4	20	11	17	0	2	17	0	0	4.0	
i 1	403.23113605442177	0.7575000000000001	73	702	2	20	12	17	5003	2	17	0	0	4.0	
i 1	403.24638775510203	0.2525	74	702	6	1	6	17	5003	1	17	0	0	2.0014753984039526	
i 1	403.48996598639457	0.2525	74	1088	6	2	7	17	0	2	17	0	0	3.0	
i 1	403.75120408163264	0.2525	74	702	5	3	16	17	0	1	17	0	0	3.0	
i 1	403.75762585034016	0.2525	74	702	3	1	15	17	0	1	17	0	0	2.0014753984039526	
i 1	403.76324489795917	0.7575000000000001	76	702	2	20	11	16	0	2	16	0	0	4.0	
i 1	403.7696666666667	0.2525	72	204	7	5	14	1	0	0	1	0	0	2.0	
i 1	403.9835442176871	0.2525	73	1088	4	20	14	16	0	1	16	0	0	4.0	
i 1	403.9843469387755	0.2525	73	702	4	20	5	17	5003	2	17	0	0	4.0	
i 1	403.99638775510203	0.2525	77	204	6	9	10	17	0	2	17	0	0	2.0	
i 1	404.23113605442177	0.2525	69	702	3	5	5	0	0	-1	0	0	0	2.0	
i 1	404.2335442176871	0.505	73	204	4	20	8	17	0	1	17	0	0	4.0	
i 1	404.24076870748297	0.505	74	702	4	4	16	17	5003	2	17	0	0	3.0	
i 1	404.24237414965984	0.505	73	702	2	20	1	17	5003	2	17	0	0	4.0	
i 1	404.24397959183676	0.7575000000000001	74	204	5	1	4	17	0	1	17	0	0	2.0014753984039526	
i 1	404.26404761904763	0.7575000000000001	74	702	4	24	9	17	5003	2	17	0	0	3.0014753984039526	
i 1	404.5020068027211	1.5150000000000001	72	702	2	5	10	0	0	-1	0	0	0	2.0	
i 1	404.7335442176871	0.2525	76	702	4	24	1	17	5003	2	17	0	0	8.0	
i 1	404.73514965986396	0.2525	76	1088	4	20	6	16	0	2	16	0	0	4.0	
i 1	404.74478231292517	0.2525	77	204	6	9	2	17	0	2	17	0	0	2.0	
i 1	404.75361224489797	3.2825	76	702	2	20	13	16	0	2	16	0	0	4.0	
i 1	404.75441496598637	1.2625	69	1088	6	5	14	0	0	0	0	0	0	2.0	
i 1	404.75762585034016	0.2525	74	1088	6	2	2	17	0	2	17	0	0	3.0	
i 1	404.76806122448977	0.2525	73	702	4	20	16	17	5003	2	17	0	0	4.0	
i 1	404.98193877551023	1.7675	77	204	6	9	8	17	0	2	17	0	0	2.8488226289245264	
i 1	404.9835442176871	1.7675	73	204	4	20	5	17	0	2	17	0	0	4.0	
i 1	404.9843469387755	15.4025	61	702	3	12	15	6	0	2	6	0	0	2.8075281002507912	
i 1	404.98755782312924	0.2525	69	204	7	5	2	0	0	-1	0	0	0	2.0	
i 1	404.98755782312924	6.8175	66	702	3	13	10	9	5003	2	9	0	0	0.7673465283066598	
i 1	404.9883605442177	1.2625	74	702	6	1	6	17	5003	1	17	0	0	2.0	
i 1	404.98996598639457	13.635	66	204	5	16	11	9	0	2	9	0	0	2.8075281002507912	
i 1	404.98996598639457	1.7675	74	1088	4	2	1	17	0	2	17	0	0	3.8488226289245264	
i 1	404.99076870748297	0.2525	74	702	4	4	8	17	0	1	17	0	0	3.8488226289245264	
i 1	404.99157142857143	15.4025	66	1088	6	17	15	9	0	1	9	0	0	0.04872182508915611	
i 1	404.9931768707483	25.25	66	204	5	18	11	9	0	2	9	0	0	0.04872182508915611	
i 1	404.99397959183676	0.505	74	204	7	1	14	17	0	1	17	0	0	2.0	
i 1	404.99558503401363	0.505	74	702	4	24	9	17	5003	2	17	0	0	3.0	
i 1	404.99638775510203	1.2625	77	702	3	24	10	16	0	1	16	0	0	3.0	
i 1	404.9971904761905	13.635	66	702	4	7	11	6	5003	2	6	0	0	2.267512633692852	
i 1	404.99959863945577	15.4025	66	702	3	27	7	9	0	2	9	0	0	1.7216435423119565	
i 1	405.0020068027211	6.8175	66	702	5	15	10	9	5003	2	9	0	0	1.6318777986229804	
i 1	405.0028095238095	15.4025	61	702	4	19	13	9	0	2	9	0	0	0.04872182508915611	
i 1	405.00361224489797	15.4025	66	702	3	12	15	9	0	2	9	0	0	2.8075281002507912	
i 1	405.00441496598637	20.4525	66	204	5	16	13	6	0	1	6	0	0	2.8075281002507912	
i 1	405.00521768707483	1.7675	76	702	2	24	10	17	5003	2	17	0	0	8.0	
i 1	405.0068231292517	40.905	66	702	6	17	6	9	5003	1	9	0	0	0.04872182508915611	
i 1	405.00762585034016	6.8175	66	702	5	15	16	9	5003	2	9	0	0	1.6318777986229804	
i 1	405.00842857142857	25.25	61	204	5	18	12	9	0	2	9	0	0	0.04872182508915611	
i 1	405.01003401360543	15.4025	66	1088	4	14	13	9	0	1	9	0	0	3.017595686385947	
i 1	405.01003401360543	15.4025	66	1088	4	14	7	6	0	1	6	0	0	3.017595686385947	
i 1	405.0116394557823	15.4025	61	1088	6	17	5	9	0	1	9	0	0	0.04872182508915611	
i 1	405.0116394557823	15.4025	66	702	3	27	12	6	0	1	6	0	0	1.7216435423119565	
i 1	405.01806122448977	34.0875	61	702	6	17	1	6	5003	2	6	0	0	0.04872182508915611	
i 1	405.73595238095237	1.2625	74	204	7	1	12	17	0	1	17	0	0	2.0	
i 1	405.73755782312924	0.7575000000000001	69	702	3	5	2	0	0	-1	0	0	0	2.0	
i 1	405.7431768707483	0.7575000000000001	72	702	6	5	2	1	5003	0	1	0	0	2.0	
i 1	405.7568231292517	1.2625	74	702	4	24	13	17	5003	2	17	0	0	3.0	
i 1	406.01725850340137	0.2525	74	204	6	9	1	16	0	1	16	0	0	2.8488226289245264	
i 1	406.01886394557823	2.02	72	1088	6	5	12	1	0	0	1	0	0	2.0	
i 1	406.23193877551023	1.7675	76	702	2	24	14	17	0	1	17	0	0	8.0	
i 1	406.24478231292517	0.7575000000000001	74	702	5	3	2	17	0	1	17	0	0	3.8488226289245264	
i 1	406.24478231292517	1.7675	69	204	7	5	6	0	0	-1	0	0	0	2.0	
i 1	406.25441496598637	0.7575000000000001	74	1088	6	2	6	16	0	2	16	0	0	3.8488226289245264	
i 1	406.26404761904763	2.525	74	1088	6	1	4	17	0	2	17	0	0	2.0	
i 1	406.2656530612245	1.5150000000000001	73	702	2	20	1	17	5003	2	17	0	0	4.0	
i 1	406.50923129251703	2.02	74	702	5	3	8	16	5003	2	16	0	0	3.8488226289245264	
i 1	406.51485034013604	2.02	74	702	4	4	7	17	0	1	17	0	0	3.8488226289245264	
i 1	406.5196666666667	0.2525	72	204	7	5	13	1	0	0	1	0	0	2.0	
i 1	406.73113605442177	2.02	74	702	3	1	7	17	0	1	17	0	0	2.0	
i 1	406.74076870748297	0.2525	72	702	6	5	9	1	5003	0	1	0	0	2.0	
i 1	406.98675510204083	0.2525	77	1088	6	1	15	16	0	1	16	0	0	2.0	
i 1	406.9979931972789	0.7575000000000001	76	702	2	24	1	17	5003	2	17	0	0	8.0	
i 1	407.00521768707483	0.2525	74	204	6	9	4	16	0	1	16	0	0	2.8488226289245264	
i 1	407.23274149659863	0.2525	77	204	5	1	5	17	0	1	17	0	0	2.0	
i 1	407.48113605442177	0.2525	77	204	6	9	10	17	0	2	17	0	0	2.8488226289245264	
i 1	407.49157142857143	0.2525	77	1088	6	1	8	16	0	1	16	0	0	2.0	
i 1	407.49558503401363	0.2525	72	702	2	5	5	0	0	-1	0	0	0	2.0	
i 1	407.5108367346939	0.2525	73	204	4	20	9	17	0	2	17	0	0	4.0	
i 1	407.73595238095237	0.2525	74	1088	6	2	10	16	0	2	16	0	0	3.8488226289245264	
i 1	407.73675510204083	1.2625	72	702	6	5	11	1	5003	0	1	0	0	2.0	
i 1	407.74157142857143	0.2525	76	702	4	24	16	17	5003	2	17	0	0	8.0	
i 1	407.75923129251703	2.02	76	204	4	20	2	16	0	1	16	0	0	4.0	
i 1	407.76003401360543	0.2525	73	702	4	20	11	17	5003	2	17	0	0	4.0	
i 1	407.76244217687076	0.2525	76	1088	4	20	10	16	0	2	16	0	0	4.0	
i 1	407.76324489795917	1.2625	72	204	7	5	11	1	0	0	1	0	0	2.0	
i 1	407.98675510204083	2.525	77	204	5	1	3	17	0	1	17	0	0	2.0	
i 1	408.0116394557823	0.2525	72	702	2	5	10	0	0	-1	0	0	0	2.0	
i 1	408.01485034013604	1.7675	76	204	4	20	13	17	0	1	17	0	0	4.0	
i 1	408.0156530612245	0.2525	74	1088	4	2	16	17	0	2	17	0	0	3.8488226289245264	
i 1	408.23675510204083	1.7675	77	1088	6	1	13	16	0	1	16	0	0	2.0	
i 1	408.2391632653061	1.5150000000000001	74	204	6	9	16	16	0	1	16	0	0	2.8488226289245264	
i 1	408.24237414965984	1.5150000000000001	74	702	4	4	13	17	5003	2	17	0	0	3.8488226289245264	
i 1	408.24638775510203	0.2525	73	204	4	24	11	16	0	2	16	0	0	8.0	
i 1	408.4979931972789	3.7875	72	1088	6	5	10	1	0	0	1	0	0	2.0	
i 1	408.50441496598637	0.2525	74	702	5	3	7	17	0	1	17	0	0	3.8488226289245264	
i 1	408.50441496598637	3.535	69	204	7	5	3	0	0	-1	0	0	0	2.0	
i 1	408.73675510204083	0.2525	74	204	7	1	12	17	0	1	17	0	0	2.0	
i 1	408.98113605442177	2.2725	74	702	5	3	16	16	5003	2	16	0	0	3.8488226289245264	
i 1	409.0068231292517	0.505	77	702	3	24	10	16	0	1	16	0	0	3.0	
i 1	409.2343469387755	1.2625	76	702	2	24	15	17	0	1	17	0	0	8.0	
i 1	409.2391632653061	4.04	76	702	2	20	7	16	0	2	16	0	0	4.0	
i 1	409.2431768707483	2.7775	76	702	2	24	2	17	5003	2	17	0	0	8.0	
i 1	409.25040136054423	1.2625	73	702	2	20	2	17	5003	2	17	0	0	4.0	
i 1	409.2568231292517	0.2525	72	702	6	5	3	1	5003	0	1	0	0	2.0	
i 1	409.25842857142857	2.2725	74	702	4	4	10	17	0	1	17	0	0	3.8488226289245264	
i 1	409.4803333333333	0.2525	74	702	3	1	13	17	0	1	17	0	0	2.0	
i 1	409.49879591836736	0.2525	72	702	6	5	4	1	5003	0	1	0	0	2.0	
i 1	409.73675510204083	1.7675	74	702	6	1	9	17	5003	1	17	0	0	2.0	
i 1	409.7431768707483	1.7675	77	702	3	24	14	16	0	1	16	0	0	3.0	
i 1	409.76886394557823	0.2525	77	204	6	9	15	17	0	2	17	0	0	2.8488226289245264	
i 1	410.2303333333333	2.2725	77	204	6	9	14	17	0	2	17	0	0	2.8488226289245264	
i 1	410.23595238095237	0.2525	69	1088	6	5	12	0	0	0	0	0	0	2.0	
i 1	410.24879591836736	1.7675	76	204	4	20	15	17	0	1	17	0	0	4.0	
i 1	410.25120408163264	1.7675	76	204	4	20	4	16	0	1	16	0	0	4.0	
i 1	410.5028095238095	0.2525	74	702	3	1	15	17	0	1	17	0	0	2.0	
i 1	410.51404761904763	0.2525	72	702	6	5	15	1	5003	0	1	0	0	2.0	
i 1	410.74237414965984	0.2525	74	1088	6	1	5	17	0	2	17	0	0	2.0	
i 1	410.7520068027211	1.7675	74	1088	4	2	11	17	0	2	17	0	0	3.8488226289245264	
i 1	411.0028095238095	0.2525	72	702	2	5	6	0	0	-1	0	0	0	2.0	
i 1	411.00602040816324	0.7575000000000001	77	204	5	1	13	17	0	1	17	0	0	2.0	
i 1	411.01725850340137	0.7575000000000001	77	1088	6	1	12	16	0	1	16	0	0	2.0	
i 1	411.50361224489797	0.2525	74	702	5	3	11	17	0	1	17	0	0	3.8488226289245264	
i 1	411.5196666666667	0.2525	74	1088	6	1	6	17	0	2	17	0	0	2.0	
i 1	411.73675510204083	2.02	69	1088	6	5	8	0	0	0	0	0	0	2.0	
i 1	411.7383605442177	0.2525	73	702	2	20	16	17	5003	2	17	0	0	4.0	
i 1	411.74638775510203	1.2625	77	204	7	1	10	17	0	1	17	0	0	2.0	
i 1	411.75040136054423	0.2525	77	702	3	24	5	16	0	1	16	0	0	3.0	
i 1	411.75762585034016	0.2525	74	702	4	4	8	17	5003	2	17	0	0	3.8488226289245264	
i 1	411.76003401360543	6.8175	66	702	5	15	13	9	5003	2	9	0	0	1.6318777986229804	
i 1	411.76324489795917	1.2625	77	1088	6	1	9	16	0	1	16	0	0	2.0	
i 1	411.76324489795917	1.5150000000000001	76	702	2	24	11	17	0	1	17	0	0	8.0	
i 1	411.76485034013604	8.585	66	702	4	19	12	6	0	2	6	0	0	0.04872182508915611	
i 1	411.7656530612245	27.27	66	702	4	13	3	9	5003	2	9	0	0	0.7673465283066598	
i 1	411.76886394557823	2.02	72	702	5	5	5	0	0	-1	0	0	0	2.0	
i 1	411.98514965986396	1.01	74	702	5	3	6	17	0	1	17	0	0	3.8488226289245264	
i 1	411.99638775510203	0.7575000000000001	73	702	4	20	16	17	5003	2	17	0	0	4.0	
i 1	412.00040136054423	0.7575000000000001	76	1088	4	20	14	17	0	1	17	0	0	4.0	
i 1	412.0020068027211	0.2525	74	702	4	24	10	17	5003	2	17	0	0	3.0	
i 1	412.01725850340137	1.01	74	1088	4	2	15	16	0	2	16	0	0	3.8488226289245264	
i 1	412.49157142857143	0.2525	72	204	7	5	5	1	0	0	1	0	0	2.0	
i 1	412.4931768707483	0.2525	74	702	4	4	14	17	5003	2	17	0	0	3.8488226289245264	
i 1	412.5116394557823	0.2525	74	702	6	1	10	17	5003	1	17	0	0	2.0	
i 1	412.51806122448977	0.2525	76	702	4	24	10	17	5003	2	17	0	0	8.0	
i 1	412.7335442176871	0.505	73	702	2	20	2	17	5003	2	17	0	0	4.0	
i 1	412.73996598639457	1.01	74	204	7	1	3	17	0	1	17	0	0	2.0	
i 1	412.7431768707483	0.7575000000000001	76	702	2	24	4	17	5003	2	17	0	0	8.0	
i 1	412.7479931972789	1.01	74	702	4	24	12	17	5003	2	17	0	0	3.0	
i 1	412.75521768707483	1.7675	76	204	4	20	5	16	0	1	16	0	0	4.0	
i 1	412.98113605442177	1.5150000000000001	76	204	4	20	7	16	0	1	16	0	0	4.0	
i 1	412.9891632653061	1.7675	74	702	5	3	3	16	5003	2	16	0	0	3.8488226289245264	
i 1	412.99638775510203	1.7675	74	702	4	4	2	17	0	1	17	0	0	3.8488226289245264	
i 1	413.0020068027211	0.2525	72	702	6	5	14	1	5003	0	1	0	0	2.0	
i 1	413.48514965986396	0.505	77	204	6	9	5	17	0	2	17	0	0	2.8488226289245264	
i 1	413.4883605442177	2.02	77	702	3	24	10	16	0	1	16	0	0	3.0	
i 1	413.49558503401363	2.525	74	702	6	1	14	17	5003	1	17	0	0	2.0	
i 1	413.49879591836736	1.2625	69	702	3	5	7	0	0	-1	0	0	0	2.0	
i 1	413.51806122448977	1.2625	72	702	6	5	15	1	5003	0	1	0	0	2.0	
i 1	413.73675510204083	0.505	76	702	2	20	10	16	0	2	16	0	0	4.0	
i 1	414.01404761904763	0.2525	69	204	7	5	4	0	0	-1	0	0	0	2.0	
i 1	414.2343469387755	0.2525	74	702	4	24	13	17	5003	2	17	0	0	3.0	
i 1	414.24638775510203	2.525	76	702	2	24	6	17	0	1	17	0	0	8.0	
i 1	414.24959863945577	0.2525	76	702	2	24	14	17	5003	2	17	0	0	8.0	
i 1	414.26003401360543	0.2525	72	702	6	5	14	1	5003	0	1	0	0	2.0	
i 1	414.26244217687076	0.2525	74	702	5	3	16	17	0	1	17	0	0	3.8488226289245264	
i 1	414.26324489795917	0.7575000000000001	73	204	4	24	7	16	0	2	16	0	0	8.0	
i 1	414.4931768707483	0.505	74	702	3	1	5	17	0	1	17	0	0	2.0	
i 1	414.50361224489797	0.2525	76	1088	4	20	11	16	0	1	16	0	0	4.0	
i 1	414.50441496598637	0.2525	76	702	4	24	2	17	5003	2	17	0	0	8.0	
i 1	414.5068231292517	0.505	69	204	7	5	8	0	0	-1	0	0	0	2.0	
i 1	414.51324489795917	0.7575000000000001	72	1088	6	5	15	1	0	0	1	0	0	2.0	
i 1	414.7303333333333	1.5150000000000001	76	702	2	20	4	16	0	2	16	0	0	4.0	
i 1	414.74397959183676	0.505	74	1088	4	2	15	16	0	2	16	0	0	3.8488226289245264	
i 1	414.74397959183676	1.01	74	702	4	4	1	17	5003	2	17	0	0	3.8488226289245264	
i 1	414.74879591836736	1.5150000000000001	76	702	2	24	6	17	5003	2	17	0	0	8.0	
i 1	414.75762585034016	2.02	72	204	7	5	15	1	0	0	1	0	0	2.0	
i 1	414.75842857142857	2.02	72	702	6	5	3	1	5003	0	1	0	0	2.0	
i 1	414.75842857142857	2.02	73	702	2	20	8	17	5003	2	17	0	0	4.0	
i 1	414.7616394557823	1.01	74	204	6	9	5	16	0	1	16	0	0	2.8488226289245264	
i 1	414.76725850340137	0.2525	73	204	4	20	1	17	0	2	17	0	0	4.0	
i 1	414.98755782312924	1.7675	74	702	4	24	15	17	5003	2	17	0	0	3.0	
i 1	415.0116394557823	1.7675	74	204	7	1	10	17	0	1	17	0	0	2.0	
i 1	415.23996598639457	1.7675	74	702	4	4	6	17	0	1	17	0	0	3.8488226289245264	
i 1	415.24638775510203	0.505	69	1088	6	5	11	0	0	0	0	0	0	2.0	
i 1	415.2520068027211	1.7675	74	702	5	3	6	16	5003	2	16	0	0	3.8488226289245264	
i 1	415.74959863945577	0.2525	72	702	5	5	8	0	0	-1	0	0	0	2.0	
i 1	415.98755782312924	0.2525	69	204	7	5	12	0	0	-1	0	0	0	2.0	
i 1	415.99478231292517	0.2525	74	1088	4	2	12	17	0	2	17	0	0	3.8488226289245264	
i 1	416.00361224489797	0.2525	77	702	3	24	3	16	0	1	16	0	0	3.0	
i 1	416.48193877551023	2.02	74	1088	4	2	3	17	0	2	17	0	0	3.8488226289245264	
i 1	416.48514965986396	2.02	72	1088	6	5	2	1	0	0	1	0	0	2.0	
i 1	416.4931768707483	2.02	77	204	6	9	9	17	0	2	17	0	0	2.8488226289245264	
i 1	416.51324489795917	1.5150000000000001	74	1088	6	1	15	17	0	2	17	0	0	2.0	
i 1	416.51725850340137	4.04	69	204	7	5	13	0	0	-1	0	0	0	2.0	
i 1	416.51806122448977	1.5150000000000001	74	702	3	1	5	17	0	1	17	0	0	2.0	
i 1	416.7335442176871	2.02	76	702	2	20	3	16	0	2	16	0	0	4.0	
i 1	416.7471904761905	0.2525	76	702	4	24	15	17	5003	2	17	0	0	8.0	
i 1	416.7568231292517	0.2525	73	702	4	20	11	17	5003	2	17	0	0	4.0	
i 1	416.7568231292517	0.505	73	204	4	24	12	16	0	2	16	0	0	8.0	
i 1	416.99638775510203	0.7575000000000001	73	702	2	20	6	17	5003	2	17	0	0	4.0	
i 1	416.99638775510203	1.7675	76	702	2	24	5	17	5003	2	17	0	0	8.0	
i 1	416.99959863945577	0.7575000000000001	76	702	2	24	1	17	0	1	17	0	0	8.0	
i 1	417.26404761904763	0.2525	69	1088	6	5	14	0	0	0	0	0	0	2.0	
i 1	417.2664557823129	0.2525	77	204	7	1	10	17	0	1	17	0	0	2.0	
i 1	417.48514965986396	1.2625	76	204	4	20	10	16	0	1	16	0	0	4.0	
i 1	417.49879591836736	1.2625	73	204	4	20	12	17	0	2	17	0	0	4.0	
i 1	417.5028095238095	0.2525	74	702	4	4	4	17	5003	2	17	0	0	3.8488226289245264	
i 1	417.5164557823129	0.2525	72	702	6	5	3	1	5003	0	1	0	0	2.0	
i 1	417.74076870748297	0.2525	74	702	5	3	3	16	5003	2	16	0	0	3.8488226289245264	
i 1	418.00441496598637	0.7575000000000001	77	204	7	1	9	17	0	1	17	0	0	2.0	
i 1	418.0108367346939	0.7575000000000001	77	1088	6	1	1	16	0	1	16	0	0	2.0	
i 1	418.2303333333333	0.2525	72	204	7	5	7	1	0	0	1	0	0	2.0	
i 1	418.24638775510203	0.2525	77	702	3	24	4	16	0	1	16	0	0	3.0	
i 1	418.4843469387755	27.27	66	702	4	7	7	6	5003	2	6	0	0	2.267512633692852	
i 1	418.49558503401363	0.7575000000000001	74	1088	4	2	9	16	0	2	16	0	0	3.8488226289245264	
i 1	418.51725850340137	1.7675	72	1088	4	5	9	1	0	0	1	0	0	2.0	
i 1	418.51806122448977	6.8175	66	204	5	16	1	9	0	2	9	0	0	2.8075281002507912	
i 1	418.51886394557823	0.7575000000000001	74	702	5	3	16	17	0	1	17	0	0	3.8488226289245264	
i 1	418.73595238095237	0.7575000000000001	73	702	2	20	6	17	5003	2	17	0	0	4.0	
i 1	418.74397959183676	0.7575000000000001	76	702	2	24	15	17	0	1	17	0	0	8.0	
i 1	418.75521768707483	0.7575000000000001	77	702	3	24	13	16	0	1	16	0	0	3.0	
i 1	418.75923129251703	0.7575000000000001	74	702	6	1	6	17	5003	1	17	0	0	2.0	
i 1	418.98113605442177	1.2625	76	702	2	20	5	16	0	2	16	0	0	4.0	
i 1	419.23193877551023	4.04	73	204	4	20	5	17	0	2	17	0	0	4.0	
i 1	419.23274149659863	1.01	77	1088	6	1	4	16	0	1	16	0	0	2.0	
i 1	419.23514965986396	2.7775	74	702	4	3	10	16	5003	2	16	0	0	3.8488226289245264	
i 1	419.24558503401363	1.2625	77	204	7	1	10	17	0	1	17	0	0	2.0	
i 1	419.2471904761905	1.01	76	702	2	24	14	17	5003	2	17	0	0	8.0	
i 1	419.25040136054423	1.2625	76	204	4	20	16	16	0	1	16	0	0	4.0	
i 1	419.2616394557823	0.2525	69	1088	6	5	14	0	0	0	0	0	0	2.0	
i 1	419.26404761904763	1.01	74	702	4	4	6	17	0	1	17	0	0	3.8488226289245264	
i 1	419.4883605442177	0.2525	72	702	6	5	14	1	5003	0	1	0	0	2.0	
i 1	419.49478231292517	0.2525	74	702	4	24	7	17	5003	2	17	0	0	3.0	
i 1	419.49638775510203	0.505	74	1088	4	2	15	17	0	2	17	0	0	3.8488226289245264	
i 1	419.98595238095237	1.7675	74	702	4	24	11	17	5003	2	17	0	0	3.0	
i 1	419.9979931972789	0.2525	77	702	3	24	3	16	0	1	16	0	0	3.0	
i 1	420.23193877551023	9.8475	66	1088	3	27	9	9	0	2	9	0	0	1.7216435423119565	
i 1	420.2335442176871	0.2525	72	204	5	5	9	0	0	0	0	0	0	2.0	
i 1	420.2335442176871	11.8675	61	204	5	14	3	6	0	2	6	0	0	3.017595686385947	
i 1	420.2343469387755	11.8675	66	204	7	17	14	6	0	2	6	0	0	0.04872182508915611	
i 1	420.24237414965984	1.7675	77	1088	5	3	14	16	0	2	16	0	0	3.8488226289245264	
i 1	420.2431768707483	1.5150000000000001	77	1088	3	24	4	17	0	1	17	0	0	3.0	
i 1	420.24638775510203	9.8475	61	1088	3	12	5	9	0	2	9	0	0	2.8075281002507912	
i 1	420.24638775510203	9.8475	61	1088	4	19	13	6	0	1	6	0	0	0.04872182508915611	
i 1	420.24638775510203	5.05	66	204	5	14	16	6	0	1	6	0	0	3.017595686385947	
i 1	420.2471904761905	0.505	72	702	6	5	7	1	5003	0	1	0	0	2.0	
i 1	420.2471904761905	0.2525	76	702	4	24	8	17	5003	2	17	0	0	8.0	
i 1	420.24879591836736	9.8475	66	1088	3	27	8	6	0	2	6	0	0	1.7216435423119565	
i 1	420.25361224489797	9.8475	61	1088	3	12	13	9	0	2	9	0	0	2.8075281002507912	
i 1	420.25842857142857	0.505	69	1088	5	5	2	1	0	-1	1	0	0	2.0	
i 1	420.2608367346939	5.05	61	204	7	17	13	9	0	1	9	0	0	0.04872182508915611	
i 1	420.26404761904763	0.2525	77	204	7	1	11	16	0	2	16	0	0	2.0	
i 1	420.2664557823129	9.8475	61	1088	4	19	8	9	0	1	9	0	0	0.04872182508915611	
i 1	420.26806122448977	0.2525	76	1088	2	20	14	16	0	1	16	0	0	4.0	
i 1	420.48274149659863	0.2525	74	204	7	1	4	17	0	1	17	0	0	2.0	
i 1	420.4971904761905	1.01	76	1088	2	24	9	16	0	2	16	0	0	8.0	
i 1	420.73675510204083	1.7675	72	204	5	5	8	0	0	0	0	0	0	2.0	
i 1	420.75923129251703	0.2525	76	1088	2	20	6	17	5003	2	17	0	0	4.0	
i 1	420.76404761904763	1.5150000000000001	72	204	7	5	2	1	0	0	1	0	0	2.0	
i 1	421.2608367346939	0.2525	72	1088	5	5	7	1	0	-1	1	0	0	2.0	
i 1	421.49237414965984	0.2525	76	204	4	20	2	16	0	1	16	0	0	4.0	
i 1	421.50040136054423	0.2525	77	204	7	1	12	16	0	2	16	0	0	2.0	
i 1	421.50923129251703	0.2525	74	204	5	2	15	16	0	2	16	0	0	3.8488226289245264	
i 1	421.73113605442177	0.2525	73	1088	2	24	8	17	5003	1	17	0	0	8.0	
i 1	421.7335442176871	1.7675	77	1088	5	1	12	17	0	2	17	0	0	2.0	
i 1	421.73514965986396	0.2525	76	1088	2	24	5	16	0	2	16	0	0	8.0	
i 1	421.75521768707483	0.2525	73	204	4	24	4	16	0	2	16	0	0	8.0	
i 1	421.75602040816324	1.7675	74	702	6	1	1	17	5003	1	17	0	0	2.0	
i 1	421.7696666666667	0.2525	74	702	4	4	4	17	5003	2	17	0	0	3.8488226289245264	
i 1	421.98514965986396	0.2525	74	204	7	1	9	17	0	1	17	0	0	2.0	
i 1	421.98755782312924	1.7675	74	204	5	2	6	16	0	2	16	0	0	3.8488226289245264	
i 1	421.9891632653061	0.505	76	1088	2	20	5	16	0	1	16	0	0	4.0	
i 1	421.9971904761905	0.505	76	204	4	20	8	16	0	1	16	0	0	4.0	
i 1	422.0028095238095	1.7675	74	204	6	9	14	16	0	1	16	0	0	2.8488226289245264	
i 1	422.01324489795917	0.505	73	702	4	24	16	16	5003	2	16	0	0	8.0	
i 1	422.23675510204083	0.2525	77	1088	3	24	14	17	0	1	17	0	0	3.0	
i 1	422.24237414965984	1.01	72	702	6	5	4	1	5003	0	1	0	0	2.0	
i 1	422.2471904761905	1.01	72	1088	5	5	1	1	0	-1	1	0	0	2.0	
i 1	422.4803333333333	0.2525	77	204	7	1	16	16	0	2	16	0	0	2.0	
i 1	422.48113605442177	0.2525	74	702	4	3	9	16	5003	2	16	0	0	3.8488226289245264	
i 1	422.5020068027211	0.7575000000000001	76	1088	2	24	8	16	0	2	16	0	0	8.0	
i 1	422.98514965986396	1.7675	74	204	7	1	2	17	0	1	17	0	0	2.0	
i 1	422.98755782312924	1.7675	77	204	7	1	3	16	0	2	16	0	0	2.0	
i 1	423.00762585034016	0.2525	74	1088	4	4	16	16	0	1	16	0	0	3.8488226289245264	
i 1	423.23595238095237	3.2825	72	204	5	5	14	0	0	0	0	0	0	2.0	
i 1	423.25361224489797	0.7575000000000001	73	1088	2	24	6	16	5003	1	16	0	0	8.0	
i 1	423.2608367346939	3.2825	72	204	7	5	7	1	0	0	1	0	0	2.0	
i 1	423.26485034013604	0.7575000000000001	73	204	4	24	13	16	0	2	16	0	0	8.0	
i 1	423.50120408163264	0.2525	76	1088	2	20	14	16	0	1	16	0	0	4.0	
i 1	423.75040136054423	0.7575000000000001	74	204	5	2	6	16	0	2	16	0	0	3.8488226289245264	
i 1	423.7696666666667	0.7575000000000001	77	204	6	9	4	17	0	2	17	0	0	2.8488226289245264	
i 1	423.98755782312924	1.01	76	1088	2	20	13	16	0	1	16	0	0	4.0	
i 1	423.99397959183676	0.2525	73	702	4	24	5	16	5003	1	16	0	0	8.0	
i 1	423.99959863945577	0.2525	76	1088	2	24	4	16	0	2	16	0	0	8.0	
i 1	424.00120408163264	0.2525	73	702	4	20	14	17	5003	2	17	0	0	4.0	
i 1	424.23675510204083	1.01	77	204	7	1	8	17	0	1	17	0	0	2.0	
i 1	424.23755782312924	0.7575000000000001	73	1088	2	20	8	17	5003	2	17	0	0	4.0	
i 1	424.2696666666667	1.01	74	204	7	1	8	16	0	2	16	0	0	2.0	
i 1	424.49076870748297	0.7575000000000001	73	204	4	20	16	17	0	2	17	0	0	4.0	
i 1	424.49478231292517	1.2625	77	1088	5	3	7	16	0	2	16	0	0	3.8488226289245264	
i 1	424.51324489795917	1.2625	74	702	4	3	11	16	5003	2	16	0	0	3.8488226289245264	
i 1	424.73595238095237	0.505	76	1088	2	24	6	16	0	2	16	0	0	8.0	
i 1	424.7520068027211	0.7575000000000001	73	1088	2	24	9	16	5003	1	16	0	0	8.0	
i 1	424.75842857142857	0.7575000000000001	73	204	4	24	3	16	0	2	16	0	0	8.0	
i 1	425.23274149659863	2.2725	76	1088	2	20	3	16	0	1	16	0	0	4.0	
i 1	425.23514965986396	4.7975	66	204	5	16	1	6	0	1	6	0	0	2.8075281002507912	
i 1	425.23675510204083	47.722500000000004	66	204	6	14	12	6	0	1	6	0	0	3.017595686385947	
i 1	425.24558503401363	49.2375	61	204	7	17	5	9	0	1	9	0	0	0.04872182508915611	
i 1	425.2520068027211	0.2525	73	1088	2	20	15	17	5003	2	17	0	0	4.0	
i 1	425.2616394557823	1.2625	74	204	7	1	2	17	0	1	17	0	0	2.0	
i 1	425.2696666666667	1.01	77	204	7	1	1	16	0	2	16	0	0	2.0	
i 1	425.51886394557823	0.2525	73	702	4	24	14	16	5003	2	16	0	0	8.0	
i 1	425.73113605442177	1.7675	76	1088	2	20	6	16	5003	2	16	0	0	4.0	
i 1	425.7568231292517	2.525	73	1088	2	24	14	16	5003	1	16	0	0	8.0	
i 1	425.75762585034016	2.525	73	204	4	24	2	16	0	2	16	0	0	8.0	
i 1	425.7616394557823	0.7575000000000001	74	702	4	4	7	17	5003	2	17	0	0	3.8488226289245264	
i 1	425.76244217687076	0.7575000000000001	74	1088	4	4	10	16	0	1	16	0	0	3.8488226289245264	
i 1	426.00441496598637	1.2625	77	1088	5	1	9	17	0	2	17	0	0	2.0	
i 1	426.00602040816324	1.2625	74	702	6	1	7	17	5003	1	17	0	0	2.0	
i 1	426.2303333333333	2.02	74	702	4	3	4	16	5003	2	16	0	0	3.8488226289245264	
i 1	426.26806122448977	2.02	77	1088	5	3	12	16	0	2	16	0	0	3.8488226289245264	
i 1	426.48755782312924	1.5150000000000001	69	204	5	5	13	1	0	0	1	0	0	2.0	
i 1	426.50441496598637	1.5150000000000001	69	204	7	5	5	0	0	-1	0	0	0	2.0	
i 1	426.74879591836736	0.2525	74	204	6	9	12	16	0	1	16	0	0	2.8488226289245264	
i 1	426.76244217687076	0.2525	72	204	5	5	3	0	0	0	0	0	0	2.0	
i 1	426.98595238095237	1.2625	73	204	4	20	14	17	0	2	17	0	0	4.0	
i 1	426.98755782312924	3.0300000000000002	77	204	7	1	12	16	0	2	16	0	0	2.0	
i 1	426.9931768707483	1.2625	76	204	4	20	9	16	0	1	16	0	0	4.0	
i 1	426.99959863945577	3.0300000000000002	74	204	7	1	2	17	0	1	17	0	0	2.0	
i 1	427.23595238095237	0.2525	74	204	7	1	5	16	0	2	16	0	0	2.0	
i 1	427.49397959183676	0.2525	74	204	5	2	6	16	0	2	16	0	0	3.8488226289245264	
i 1	427.49959863945577	0.2525	72	1088	5	5	11	1	0	-1	1	0	0	2.0	
i 1	428.00120408163264	1.01	72	702	6	5	9	1	5003	0	1	0	0	2.0	
i 1	428.00842857142857	1.01	69	1088	5	5	11	1	0	-1	1	0	0	2.0	
i 1	428.23595238095237	0.2525	76	1088	2	20	2	16	5003	2	16	0	0	4.0	
i 1	428.2391632653061	1.01	74	204	5	2	1	16	0	2	16	0	0	3.8488226289245264	
i 1	428.2520068027211	1.01	74	204	6	9	16	16	0	1	16	0	0	2.8488226289245264	
i 1	428.25441496598637	0.505	76	1088	2	20	11	16	0	1	16	0	0	4.0	
i 1	428.48193877551023	0.2525	76	702	4	20	11	16	5003	1	16	0	0	4.0	
i 1	428.50842857142857	0.2525	76	1088	2	24	4	16	0	2	16	0	0	8.0	
i 1	428.51806122448977	0.2525	73	702	4	24	12	17	5003	1	17	0	0	8.0	
i 1	428.73193877551023	1.2625	73	1088	2	24	4	17	5003	2	17	0	0	8.0	
i 1	428.74157142857143	1.2625	73	204	4	24	12	16	0	2	16	0	0	8.0	
i 1	428.99157142857143	0.2525	72	204	7	5	11	1	0	0	1	0	0	2.0	
i 1	428.99558503401363	0.2525	72	204	5	5	9	0	0	0	0	0	0	2.0	
i 1	429.2471904761905	0.7575000000000001	72	1088	5	5	5	1	0	-1	1	0	0	2.0	
i 1	429.2479931972789	1.01	74	204	5	2	13	16	0	2	16	0	0	3.8488226289245264	
i 1	429.25120408163264	1.5150000000000001	72	702	6	5	5	1	5003	0	1	0	0	2.0	
i 1	429.2616394557823	0.7575000000000001	77	204	6	9	14	17	0	2	17	0	0	2.8488226289245264	
i 1	429.9835442176871	29.29	66	1088	4	18	10	6	0	1	6	0	0	0.04872182508915611	
i 1	429.9891632653061	0.7575000000000001	69	702	5	5	4	1	0	-1	1	0	0	2.0	
i 1	429.99237414965984	22.4725	61	702	3	27	1	9	0	1	9	0	0	1.7216435423119565	
i 1	429.99478231292517	1.01	76	702	2	20	15	16	5003	2	16	0	0	4.0	
i 1	430.00040136054423	2.02	66	1088	4	16	16	9	0	2	9	0	0	2.8075281002507912	
i 1	430.00120408163264	2.02	61	702	3	12	10	6	0	2	6	0	0	2.8075281002507912	
i 1	430.00361224489797	36.1075	61	702	4	19	4	6	0	2	6	0	0	0.04872182508915611	
i 1	430.00521768707483	1.2625	74	702	4	24	9	17	5003	2	17	0	0	3.0	
i 1	430.0068231292517	42.925	61	702	4	19	15	6	0	1	6	0	0	0.04872182508915611	
i 1	430.0068231292517	2.02	76	702	2	24	9	17	5003	2	17	0	0	8.0	
i 1	430.00762585034016	1.2625	74	702	4	24	2	17	0	1	17	0	0	3.0	
i 1	430.00762585034016	1.01	76	702	2	24	12	16	0	2	16	0	0	8.0	
i 1	430.01003401360543	29.29	61	702	3	27	3	9	0	2	9	0	0	1.7216435423119565	
i 1	430.01324489795917	22.4725	61	1088	4	18	15	6	0	2	6	0	0	0.04872182508915611	
i 1	430.01404761904763	8.8375	61	702	3	12	16	6	0	2	6	0	0	2.8075281002507912	
i 1	430.0156530612245	2.02	76	702	2	20	3	16	0	1	16	0	0	4.0	
i 1	430.01806122448977	0.2525	77	1088	5	9	10	17	0	1	17	0	0	2.8488226289245264	
i 1	430.23113605442177	1.7675	74	702	5	3	7	16	0	2	16	0	0	3.8488226289245264	
i 1	430.26404761904763	1.7675	74	702	4	3	4	16	5003	2	16	0	0	3.8488226289245264	
i 1	430.73274149659863	4.04	72	204	5	5	14	0	0	0	0	0	0	2.0	
i 1	430.7528095238095	4.04	72	1088	6	5	16	0	0	0	0	0	0	2.0	
i 1	430.99478231292517	1.01	73	1088	3	20	1	16	0	2	16	0	0	4.0	
i 1	430.9979931972789	1.2625	76	1088	3	24	9	17	0	1	17	0	0	8.0	
i 1	431.24558503401363	0.7575000000000001	74	702	6	1	5	17	5003	1	17	0	0	2.0	
i 1	431.2616394557823	0.7575000000000001	74	702	5	1	16	17	0	1	17	0	0	2.0	
i 1	431.98675510204083	0.7575000000000001	74	1088	6	1	13	17	0	1	17	0	0	2.0	
i 1	431.98755782312924	0.7575000000000001	77	702	4	4	12	17	0	1	17	0	0	3.8488226289245264	
i 1	431.9931768707483	42.42	66	204	7	17	7	6	0	2	6	0	0	0.04872182508915611	
i 1	431.99558503401363	1.2625	76	702	2	24	2	16	0	2	16	0	0	8.0	
i 1	432.0028095238095	6.8175	61	702	5	12	11	6	0	2	6	0	0	2.8075281002507912	
i 1	432.0028095238095	42.42	61	204	6	14	1	6	0	2	6	0	0	3.017595686385947	
i 1	432.00361224489797	0.7575000000000001	74	702	4	4	1	17	5003	2	17	0	0	3.8488226289245264	
i 1	432.0108367346939	0.2525	76	204	4	20	9	16	0	1	16	0	0	4.0	
i 1	432.0164557823129	0.7575000000000001	77	204	7	1	2	16	0	2	16	0	0	2.0	
i 1	432.0196666666667	0.2525	76	702	4	24	1	17	5003	2	17	0	0	8.0	
i 1	432.23193877551023	1.01	76	1088	3	20	3	16	0	2	16	0	0	4.0	
i 1	432.23514965986396	1.01	76	702	2	20	9	16	5003	2	16	0	0	4.0	
i 1	432.2568231292517	1.01	73	1088	3	20	13	16	0	1	16	0	0	4.0	
i 1	432.7391632653061	1.01	74	702	5	3	13	16	0	2	16	0	0	3.8488226289245264	
i 1	432.74157142857143	1.01	74	702	4	3	12	16	5003	2	16	0	0	3.8488226289245264	
i 1	432.75120408163264	1.01	74	204	7	1	8	16	0	2	16	0	0	2.0	
i 1	432.76725850340137	1.01	74	1088	6	1	16	17	0	1	17	0	0	2.0	
i 1	433.2335442176871	4.2925	76	702	2	20	6	16	0	1	16	0	0	4.0	
i 1	433.2391632653061	0.505	76	1088	3	24	8	17	0	1	17	0	0	8.0	
i 1	433.25923129251703	0.505	76	702	4	20	11	16	5003	2	16	0	0	4.0	
i 1	433.2696666666667	0.505	76	702	4	24	16	17	5003	2	17	0	0	8.0	
i 1	433.7343469387755	1.2625	76	702	2	24	10	16	0	2	16	0	0	8.0	
i 1	433.74558503401363	1.5150000000000001	77	204	7	1	14	16	0	2	16	0	0	2.0	
i 1	433.74638775510203	2.7775	76	702	2	24	4	17	5003	2	17	0	0	8.0	
i 1	433.76003401360543	1.2625	76	702	2	20	10	16	5003	2	16	0	0	4.0	
i 1	433.7608367346939	1.5150000000000001	74	1088	6	1	15	17	0	1	17	0	0	2.0	
i 1	433.76324489795917	1.7675	74	204	5	2	12	16	0	2	16	0	0	3.8488226289245264	
i 1	433.76886394557823	1.7675	74	1088	3	9	10	16	0	2	16	0	0	2.8488226289245264	
i 1	434.73595238095237	0.2525	69	204	5	5	2	1	0	0	1	0	0	2.0	
i 1	434.75923129251703	0.2525	69	1088	6	5	14	0	0	-1	0	0	0	2.0	
i 1	434.99879591836736	1.5150000000000001	76	1088	3	20	3	17	0	1	17	0	0	4.0	
i 1	435.00842857142857	1.5150000000000001	73	1088	3	20	13	16	0	1	16	0	0	4.0	
i 1	435.01244217687076	1.5150000000000001	72	702	5	5	9	1	0	-1	1	0	0	2.0	
i 1	435.0156530612245	1.5150000000000001	72	702	4	5	8	1	5003	0	1	0	0	2.0	
i 1	435.23113605442177	1.5150000000000001	74	702	6	1	8	17	5003	1	17	0	0	2.0	
i 1	435.25602040816324	1.5150000000000001	74	702	5	1	3	17	0	1	17	0	0	2.0	
i 1	435.49397959183676	1.01	77	1088	5	9	10	17	0	1	17	0	0	2.8488226289245264	
i 1	435.5196666666667	1.01	74	204	5	2	2	16	0	2	16	0	0	3.8488226289245264	
i 1	436.48675510204083	0.2525	76	702	4	20	2	16	5003	2	16	0	0	4.0	
i 1	436.48755782312924	1.01	72	1088	6	5	5	0	0	0	0	0	0	2.0	
i 1	436.48996598639457	0.2525	76	204	4	20	13	16	0	2	16	0	0	4.0	
i 1	436.49237414965984	1.5150000000000001	74	702	5	3	7	16	0	2	16	0	0	3.8488226289245264	
i 1	436.49959863945577	1.01	76	702	2	24	5	16	0	2	16	0	0	8.0	
i 1	436.50040136054423	1.01	72	204	5	5	4	0	0	0	0	0	0	2.0	
i 1	436.51404761904763	1.5150000000000001	74	702	4	3	10	16	5003	2	16	0	0	3.8488226289245264	
i 1	436.7335442176871	2.02	77	204	7	1	11	16	0	2	16	0	0	2.0	
i 1	436.7383605442177	0.7575000000000001	76	702	2	24	10	17	5003	2	17	0	0	8.0	
i 1	436.75040136054423	0.7575000000000001	76	702	2	20	14	16	5003	2	16	0	0	4.0	
i 1	436.7616394557823	2.02	74	1088	6	1	6	17	0	1	17	0	0	2.0	
i 1	437.4835442176871	0.2525	76	204	4	20	5	17	0	1	17	0	0	4.0	
i 1	437.4883605442177	1.01	73	1088	3	20	11	16	0	1	16	0	0	4.0	
i 1	437.49076870748297	0.505	69	702	5	5	9	1	0	-1	1	0	0	2.0	
i 1	437.49638775510203	1.01	76	1088	3	24	7	17	0	1	17	0	0	8.0	
i 1	437.5020068027211	0.505	72	702	6	5	3	1	5003	0	1	0	0	2.0	
i 1	437.51324489795917	0.2525	76	702	4	24	15	17	5003	2	17	0	0	8.0	
i 1	437.7520068027211	0.7575000000000001	76	1088	3	20	5	17	0	2	17	0	0	4.0	
i 1	437.7568231292517	0.7575000000000001	76	1088	3	20	3	17	0	2	17	0	0	4.0	
i 1	437.99076870748297	4.2925	72	204	5	5	9	0	0	0	0	0	0	2.0	
i 1	437.99558503401363	4.2925	72	1088	6	5	5	0	0	0	0	0	0	2.0	
i 1	438.00762585034016	0.2525	77	702	4	4	12	17	0	1	17	0	0	3.8488226289245264	
i 1	438.01886394557823	0.2525	74	702	4	4	15	17	5003	2	17	0	0	3.8488226289245264	
i 1	438.23755782312924	1.7675	74	702	4	3	1	16	5003	2	16	0	0	3.8488226289245264	
i 1	438.25762585034016	1.7675	74	702	5	3	13	16	0	2	16	0	0	3.8488226289245264	
i 1	438.48996598639457	0.2525	76	702	2	20	7	16	0	1	16	0	0	4.0	
i 1	438.49478231292517	0.2525	76	702	4	20	3	16	5003	2	16	0	0	4.0	
i 1	438.4979931972789	0.2525	76	702	2	24	5	16	0	2	16	0	0	8.0	
i 1	438.5156530612245	0.2525	73	204	4	20	7	17	0	1	17	0	0	4.0	
i 1	438.73193877551023	6.8175	61	702	5	12	14	6	0	2	6	0	0	2.8075281002507912	
i 1	438.73193877551023	37.1175	66	702	5	13	14	9	5003	2	9	0	0	0.7673465283066598	
i 1	438.73675510204083	0.505	76	702	2	24	16	17	5003	2	17	0	0	8.0	
i 1	438.7383605442177	37.1175	61	702	6	17	9	6	5003	2	6	0	0	0.04872182508915611	
i 1	438.7383605442177	1.01	76	702	2	24	9	16	0	2	16	0	0	8.0	
i 1	438.74076870748297	0.505	76	702	2	20	10	16	0	1	16	0	0	4.000000000000001	
i 1	438.75521768707483	0.7575000000000001	74	702	4	24	15	17	0	1	17	0	0	3.0	
i 1	438.76244217687076	0.505	76	702	2	20	4	16	5003	2	16	0	0	4.000000000000001	
i 1	438.76324489795917	0.7575000000000001	74	702	4	24	4	17	5003	2	17	0	0	3.0	
i 1	439.2335442176871	0.505	76	204	4	20	3	16	0	2	16	0	0	4.000000000000001	
i 1	439.23514965986396	0.505	76	1088	3	24	2	17	0	1	17	0	0	8.0	
i 1	439.26485034013604	0.505	76	702	4	24	16	17	5003	2	17	0	0	8.0	
i 1	439.48193877551023	1.01	74	702	6	1	5	17	5003	1	17	0	0	2.0	
i 1	439.48595238095237	1.01	74	702	5	1	12	17	0	1	17	0	0	2.0	
i 1	439.7528095238095	0.7575000000000001	73	1088	3	20	16	16	0	1	16	0	0	4.000000000000001	
i 1	439.7696666666667	0.7575000000000001	76	1088	3	20	10	17	0	1	17	0	0	4.000000000000001	
i 1	439.99478231292517	1.7675	74	204	5	2	12	16	0	2	16	0	0	3.8488226289245264	
i 1	440.00441496598637	1.7675	74	1088	3	9	11	16	0	2	16	0	0	2.8488226289245264	
i 1	440.4835442176871	1.5150000000000001	74	1088	6	1	13	17	0	1	17	0	0	2.0	
i 1	440.4835442176871	0.2525	76	702	2	20	15	16	0	1	16	0	0	4.000000000000001	
i 1	440.4883605442177	1.5150000000000001	77	204	7	1	10	16	0	2	16	0	0	2.0	
i 1	440.5068231292517	0.2525	76	702	2	24	4	17	5003	2	17	0	0	8.0	
i 1	440.7335442176871	0.505	76	1088	3	20	13	17	0	1	17	0	0	4.000000000000001	
i 1	440.7383605442177	0.505	73	1088	3	20	15	16	0	1	16	0	0	4.000000000000001	
i 1	440.75120408163264	0.505	76	702	2	20	12	16	5003	2	16	0	0	4.000000000000001	
i 1	440.75441496598637	0.505	76	702	2	24	15	16	0	2	16	0	0	8.0	
i 1	441.23113605442177	0.2525	76	1088	3	24	1	17	0	1	17	0	0	8.0	
i 1	441.25762585034016	0.2525	76	702	4	20	15	16	5003	2	16	0	0	4.000000000000001	
i 1	441.2608367346939	1.7675	76	702	2	20	10	16	0	1	16	0	0	4.000000000000001	
i 1	441.26404761904763	0.2525	76	702	4	24	16	17	5003	2	17	0	0	8.0	
i 1	441.48595238095237	1.5150000000000001	76	702	2	24	15	17	5003	2	17	0	0	8.0	
i 1	441.49397959183676	1.5150000000000001	73	1088	3	20	16	17	0	1	17	0	0	4.000000000000001	
i 1	441.49959863945577	1.5150000000000001	73	1088	3	20	5	16	0	1	16	0	0	4.000000000000001	
i 1	441.74157142857143	0.7575000000000001	77	1088	3	9	2	17	0	1	17	0	0	2.8488226289245264	
i 1	441.76725850340137	0.7575000000000001	74	204	5	2	11	16	0	2	16	0	0	3.8488226289245264	
i 1	441.98755782312924	1.5150000000000001	74	204	7	1	1	16	0	2	16	0	0	2.0	
i 1	442.0108367346939	1.5150000000000001	74	1088	6	1	15	17	0	1	17	0	0	2.0	
i 1	442.25602040816324	1.01	69	204	5	5	9	1	0	0	1	0	0	2.0	
i 1	442.26003401360543	1.01	69	1088	6	5	4	0	0	-1	0	0	0	2.0	
i 1	442.49478231292517	1.2625	74	702	5	3	2	16	0	2	16	0	0	3.8488226289245264	
i 1	442.5116394557823	1.2625	74	702	4	3	16	16	5003	2	16	0	0	3.8488226289245264	
i 1	442.98514965986396	1.01	76	702	2	24	14	16	0	2	16	0	0	8.0	
i 1	443.00441496598637	0.505	76	204	4	20	2	16	0	2	16	0	0	4.000000000000001	
i 1	443.2431768707483	0.505	72	702	5	5	14	1	0	-1	1	0	0	2.0	
i 1	443.25521768707483	0.505	72	702	4	5	3	1	5003	0	1	0	0	2.0	
i 1	443.48274149659863	1.2625	77	204	7	1	5	16	0	2	16	0	0	2.0	
i 1	443.50602040816324	1.2625	74	1088	6	1	1	17	0	1	17	0	0	2.0	
i 1	443.51404761904763	0.505	76	1088	3	20	15	16	0	1	16	0	0	4.000000000000001	
i 1	443.51485034013604	0.505	73	1088	3	20	13	16	0	1	16	0	0	4.000000000000001	
i 1	443.5156530612245	0.505	76	702	2	20	13	16	5003	2	16	0	0	4.000000000000001	
i 1	443.74879591836736	1.5150000000000001	72	1088	6	5	14	0	0	0	0	0	0	2.0	
i 1	443.75120408163264	0.7575000000000001	74	702	4	4	8	17	5003	2	17	0	0	3.8488226289245264	
i 1	443.75923129251703	1.5150000000000001	72	204	5	5	6	0	0	0	0	0	0	2.0	
i 1	443.7608367346939	0.7575000000000001	77	702	4	4	8	17	0	1	17	0	0	3.8488226289245264	
i 1	443.9883605442177	0.7575000000000001	76	702	2	20	6	16	0	1	16	0	0	4.000000000000001	
i 1	444.00120408163264	0.2525	76	702	2	24	5	17	5003	2	17	0	0	8.0	
i 1	444.24478231292517	0.2525	76	1088	3	24	5	17	0	1	17	0	0	8.0	
i 1	444.24959863945577	0.2525	76	702	4	20	1	16	5003	2	16	0	0	4.000000000000001	
i 1	444.2696666666667	0.2525	76	702	4	24	5	17	5003	2	17	0	0	8.0	
i 1	444.50842857142857	1.7675	74	702	4	3	16	16	5003	2	16	0	0	3.8488226289245264	
i 1	444.50923129251703	0.2525	76	702	2	20	16	16	5003	2	16	0	0	4.000000000000001	
i 1	444.5196666666667	1.01	74	702	5	3	16	16	0	2	16	0	0	3.8488226289245264	
i 1	444.75923129251703	0.7575000000000001	74	702	6	1	3	17	5003	1	17	0	0	2.0	
i 1	444.76725850340137	0.7575000000000001	74	702	5	1	8	17	0	1	17	0	0	2.0	
i 1	445.00120408163264	0.7575000000000001	76	702	2	20	3	16	0	1	16	0	0	4.000000000000001	
i 1	445.0108367346939	0.2525	76	702	2	24	14	17	5003	2	17	0	0	8.0	
i 1	445.2391632653061	1.01	72	702	4	5	8	1	5003	0	1	0	0	2.0	
i 1	445.24076870748297	0.505	76	702	4	20	7	16	5003	2	16	0	0	4.000000000000001	
i 1	445.24157142857143	1.01	69	702	5	5	9	1	0	-1	1	0	0	2.0	
i 1	445.24237414965984	1.01	76	1088	3	24	12	17	0	1	17	0	0	8.0	
i 1	445.2616394557823	0.505	76	702	4	24	13	17	5003	2	17	0	0	8.0	
i 1	445.48755782312924	1.7675	74	1088	6	1	11	17	0	1	17	0	0	2.0	
i 1	445.49478231292517	0.7575000000000001	74	702	2	3	12	16	0	2	16	0	0	3.8488226289245264	
i 1	445.50361224489797	30.3	66	702	6	17	16	9	5003	1	9	0	0	0.04872182508915611	
i 1	445.50842857142857	28.785	61	204	6	14	8	6	0	1	6	0	0	3.983178401878601	
i 1	445.5156530612245	30.3	66	702	5	7	14	6	5003	2	6	0	0	2.267512633692852	
i 1	445.51725850340137	1.7675	77	204	7	1	6	16	0	2	16	0	0	2.0	
i 1	445.73996598639457	0.505	76	702	2	20	13	16	5003	2	16	0	0	4.000000000000001	
i 1	445.74638775510203	0.505	76	1088	3	20	4	16	0	2	16	0	0	4.000000000000001	
i 1	445.7664557823129	0.505	76	702	2	24	1	16	0	2	16	0	0	8.0	
i 1	446.2335442176871	1.01	74	204	7	2	16	16	0	2	16	0	0	3.8488226289245264	
i 1	446.23595238095237	0.7575000000000001	73	1088	3	20	1	17	0	2	17	0	0	4.000000000000001	
i 1	446.2383605442177	1.01	74	1088	3	9	5	16	0	2	16	0	0	2.8488226289245264	
i 1	446.23996598639457	1.01	73	1088	3	20	5	16	0	1	16	0	0	4.000000000000001	
i 1	446.24397959183676	3.2825	72	204	5	5	4	0	0	0	0	0	0	2.0	
i 1	446.26244217687076	3.2825	72	1088	3	5	13	0	0	0	0	0	0	2.0	
i 1	446.9803333333333	1.7675	76	702	2	20	5	16	0	1	16	0	0	4.000000000000001	
i 1	446.99478231292517	0.2525	76	702	4	20	12	16	5003	2	16	0	0	4.000000000000001	
i 1	446.99558503401363	0.2525	76	204	4	20	15	17	0	1	17	0	0	4.000000000000001	
i 1	447.23193877551023	1.2625	76	702	2	20	10	16	5003	2	16	0	0	4.000000000000001	
i 1	447.24076870748297	1.01	74	204	5	2	4	16	0	2	16	0	0	3.8488226289245264	
i 1	447.25521768707483	1.01	77	1088	3	9	8	17	0	1	17	0	0	2.8488226289245264	
i 1	447.25923129251703	1.2625	76	702	2	24	16	16	0	2	16	0	0	8.0	
i 1	447.2616394557823	1.5150000000000001	74	702	4	24	5	17	5003	2	17	0	0	3.0	
i 1	447.2616394557823	1.5150000000000001	74	702	4	24	8	17	0	1	17	0	0	3.0	
i 1	447.2696666666667	1.2625	76	702	2	24	7	17	5003	2	17	0	0	8.0	
i 1	448.23193877551023	1.7675	74	702	4	3	12	16	5003	2	16	0	0	3.8488226289245264	
i 1	448.24478231292517	1.7675	74	702	2	3	12	16	0	2	16	0	0	3.8488226289245264	
i 1	448.50521768707483	0.2525	76	702	4	20	14	16	5003	2	16	0	0	4.000000000000001	
i 1	448.51404761904763	1.5150000000000001	76	1088	3	24	3	17	0	1	17	0	0	8.0	
i 1	448.51886394557823	0.2525	76	702	4	24	10	17	5003	2	17	0	0	8.0	
i 1	448.73113605442177	1.01	76	1088	3	20	13	16	0	2	16	0	0	4.000000000000001	
i 1	448.7391632653061	0.505	76	702	2	20	10	16	5003	2	16	0	0	4.000000000000001	
i 1	448.73996598639457	1.5150000000000001	74	702	6	1	13	17	5003	1	17	0	0	2.0	
i 1	448.7608367346939	1.5150000000000001	74	702	5	1	13	17	0	1	17	0	0	2.0	
i 1	448.76485034013604	0.505	76	702	2	24	2	16	0	2	16	0	0	8.0	
i 1	449.23193877551023	0.505	76	702	2	20	11	16	0	1	16	0	0	4.000000000000001	
i 1	449.24478231292517	0.505	76	702	2	24	16	17	5003	2	17	0	0	8.0	
i 1	449.5156530612245	1.5150000000000001	69	204	5	5	7	1	0	0	1	0	0	2.0	
i 1	449.51806122448977	1.5150000000000001	69	1088	6	5	5	0	0	-1	0	0	0	2.0	
i 1	449.7383605442177	0.2525	76	702	4	24	4	17	5003	2	17	0	0	8.0	
i 1	449.99638775510203	0.7575000000000001	77	702	4	4	4	17	0	1	17	0	0	3.8488226289245264	
i 1	449.9971904761905	0.2525	76	702	2	24	10	16	0	2	16	0	0	8.0	
i 1	449.99959863945577	0.7575000000000001	74	702	4	4	2	17	5003	2	17	0	0	3.8488226289245264	
i 1	450.00762585034016	0.505	76	702	2	20	16	16	0	1	16	0	0	4.000000000000001	
i 1	450.0156530612245	0.2525	76	702	2	20	1	16	5003	2	16	0	0	4.000000000000001	
i 1	450.0156530612245	0.2525	76	702	2	24	2	17	5003	2	17	0	0	8.0	
i 1	450.24397959183676	1.2625	74	1088	6	1	7	17	0	1	17	0	0	2.0	
i 1	450.2479931972789	0.2525	76	702	4	20	2	16	5003	2	16	0	0	4.000000000000001	
i 1	450.25923129251703	0.2525	73	204	4	20	12	17	0	1	17	0	0	4.000000000000001	
i 1	450.2656530612245	1.2625	77	204	7	1	13	16	0	2	16	0	0	2.0	
i 1	450.26886394557823	0.2525	73	1088	3	20	16	16	0	1	16	0	0	4.000000000000001	
i 1	450.5116394557823	1.7675	76	1088	3	24	1	17	0	1	17	0	0	8.0	
i 1	450.5156530612245	1.5150000000000001	76	1088	3	20	12	16	0	2	16	0	0	4.000000000000001	
i 1	450.73595238095237	1.01	74	702	2	3	12	16	0	2	16	0	0	3.8488226289245264	
i 1	450.76244217687076	1.01	74	702	4	3	10	16	5003	2	16	0	0	3.8488226289245264	
i 1	451.00602040816324	1.01	72	702	4	5	14	1	5003	0	1	0	0	2.0	
i 1	451.01725850340137	1.01	72	702	5	5	7	1	0	-1	1	0	0	2.0	
i 1	451.49237414965984	0.7575000000000001	74	1088	6	1	8	17	0	1	17	0	0	2.0	
i 1	451.4979931972789	0.7575000000000001	74	204	7	1	16	16	0	2	16	0	0	2.0	
i 1	451.74157142857143	1.7675	74	1088	3	9	8	16	0	2	16	0	0	2.8488226289245264	
i 1	451.75762585034016	0.2525	76	702	2	20	4	16	5003	2	16	0	0	4.000000000000001	
i 1	451.76886394557823	1.7675	74	204	7	2	6	16	0	2	16	0	0	3.8488226289245264	
i 1	451.7696666666667	0.2525	76	702	2	24	15	16	0	2	16	0	0	8.0	
i 1	451.98274149659863	0.2525	72	1088	3	5	12	0	0	0	0	0	0	2.0	
i 1	451.9883605442177	0.2525	76	702	4	20	2	16	5003	2	16	0	0	4.000000000000001	
i 1	452.0020068027211	1.01	76	702	2	20	1	16	0	1	16	0	0	4.000000000000001	
i 1	452.00842857142857	0.2525	76	702	4	24	5	17	5003	2	17	0	0	8.0	
i 1	452.0116394557823	0.2525	72	204	5	5	1	0	0	0	0	0	0	2.0	
i 1	452.2343469387755	2.02	76	702	2	24	7	16	0	2	16	0	0	8.0	
i 1	452.24558503401363	0.7575000000000001	77	204	7	1	12	16	0	2	16	0	0	2.0	
i 1	452.2471904761905	21.9675	61	204	6	13	9	6	0	2	6	0	0	0.45622749699517	
i 1	452.2479931972789	0.7575000000000001	74	1088	6	1	8	17	0	1	17	0	0	2.0	
i 1	452.2520068027211	21.9675	61	1088	4	18	4	6	0	2	6	0	0	0.04872182508915611	
i 1	452.2520068027211	1.7675	69	702	5	5	9	1	0	-1	1	0	0	2.0	
i 1	452.2608367346939	0.505	76	702	2	24	6	17	5003	2	17	0	0	8.0	
i 1	452.26404761904763	1.7675	72	702	4	5	6	1	5003	0	1	0	0	2.0	
i 1	452.26806122448977	0.505	76	702	2	20	10	16	5003	2	16	0	0	4.000000000000001	
i 1	452.75441496598637	0.2525	76	204	4	20	11	16	0	2	16	0	0	4.000000000000001	
i 1	452.7568231292517	0.2525	76	702	4	20	5	16	5003	2	16	0	0	4.000000000000001	
i 1	452.9803333333333	1.2625	76	702	2	20	13	16	5003	2	16	0	0	4.000000000000001	
i 1	453.00361224489797	2.02	76	1088	3	20	4	16	0	2	16	0	0	4.000000000000001	
i 1	453.00441496598637	3.0300000000000002	76	1088	3	24	15	17	0	1	17	0	0	8.0	
i 1	453.0116394557823	1.01	74	702	6	1	4	17	0	1	17	0	0	2.0	
i 1	453.01485034013604	1.01	74	702	6	1	9	17	5003	1	17	0	0	2.0	
i 1	453.2391632653061	0.2525	74	702	2	3	3	16	0	2	16	0	0	3.8488226289245264	
i 1	453.49558503401363	1.01	77	1088	3	9	12	17	0	1	17	0	0	2.8488226289245264	
i 1	453.5196666666667	1.01	74	204	7	2	8	16	0	2	16	0	0	3.8488226289245264	
i 1	453.74157142857143	4.04	72	1088	3	5	2	0	0	0	0	0	0	2.0	
i 1	453.74397959183676	3.535	77	204	7	1	16	16	0	2	16	0	0	2.0	
i 1	453.7520068027211	3.535	74	1088	6	1	16	17	0	1	17	0	0	2.0	
i 1	453.75842857142857	4.04	72	204	7	5	10	0	0	0	0	0	0	2.0	
i 1	453.9835442176871	1.01	76	702	2	24	3	17	5003	2	17	0	0	8.0	
i 1	453.98755782312924	1.5150000000000001	76	702	2	20	11	16	0	1	16	0	0	4.000000000000001	
i 1	453.99076870748297	0.2525	72	702	5	5	14	1	0	-1	1	0	0	2.0	
i 1	454.2335442176871	0.2525	74	1088	6	1	12	17	0	1	17	0	0	2.0	
i 1	454.2343469387755	0.2525	72	702	4	5	10	1	5003	0	1	0	0	2.0	
i 1	454.48113605442177	0.2525	74	204	7	2	10	16	0	2	16	0	0	3.8488226289245264	
i 1	454.4931768707483	3.7875	74	702	2	3	14	16	0	2	16	0	0	3.8488226289245264	
i 1	454.50521768707483	3.7875	74	702	4	3	10	16	5003	2	16	0	0	3.8488226289245264	
i 1	454.73193877551023	0.505	74	1088	3	9	8	16	0	2	16	0	0	2.8488226289245264	
i 1	454.7335442176871	0.2525	76	702	2	20	15	16	5003	2	16	0	0	4.000000000000001	
i 1	454.99076870748297	0.505	76	702	4	20	12	16	5003	2	16	0	0	4.000000000000001	
i 1	455.0116394557823	0.505	76	702	4	24	16	17	5003	2	17	0	0	8.0	
i 1	455.49558503401363	0.2525	76	1088	3	20	5	17	0	1	17	0	0	4.000000000000001	
i 1	455.50361224489797	0.2525	69	204	5	5	16	1	0	0	1	0	0	2.0	
i 1	455.50361224489797	0.2525	76	702	2	20	1	16	5003	2	16	0	0	4.000000000000001	
i 1	455.50441496598637	1.7675	76	702	2	24	11	16	0	2	16	0	0	8.0	
i 1	455.50923129251703	0.2525	74	1088	3	9	1	16	0	2	16	0	0	2.8488226289245264	
i 1	455.51886394557823	0.2525	74	1088	6	1	10	17	0	1	17	0	0	2.0	
i 1	455.7343469387755	0.2525	76	204	4	20	9	16	0	1	16	0	0	4.000000000000001	
i 1	455.73675510204083	0.505	74	702	4	4	6	17	5003	2	17	0	0	3.8488226289245264	
i 1	455.7383605442177	0.505	77	702	2	4	9	17	0	1	17	0	0	3.8488226289245264	
i 1	455.74558503401363	0.2525	74	702	4	24	8	17	0	1	17	0	0	3.0	
i 1	455.74638775510203	1.5150000000000001	76	702	2	20	7	16	0	1	16	0	0	4.000000000000001	
i 1	455.75602040816324	0.2525	76	702	4	24	6	17	5003	2	17	0	0	8.0	
i 1	455.76324489795917	0.2525	76	702	4	20	3	16	5003	2	16	0	0	4.000000000000001	
i 1	455.76324489795917	0.505	73	1088	3	20	2	16	0	1	16	0	0	4.000000000000001	
i 1	455.99558503401363	0.7575000000000001	76	702	2	20	1	16	5003	2	16	0	0	4.000000000000001	
i 1	455.9971904761905	0.7575000000000001	76	702	2	24	9	17	5003	2	17	0	0	8.0	
i 1	456.01244217687076	0.2525	73	1088	3	20	12	17	0	2	17	0	0	4.000000000000001	
i 1	456.2383605442177	0.2525	69	204	5	5	15	1	0	0	1	0	0	2.0	
i 1	456.2431768707483	0.2525	74	204	7	2	9	16	0	2	16	0	0	3.8488226289245264	
i 1	456.51886394557823	2.525	76	1088	3	24	9	17	0	1	17	0	0	8.0	
i 1	456.74638775510203	0.2525	76	702	4	20	8	16	5003	2	16	0	0	4.000000000000001	
i 1	456.74638775510203	0.2525	76	702	4	24	9	17	5003	2	17	0	0	8.0	
i 1	456.75441496598637	1.7675	74	702	4	24	14	17	0	1	17	0	0	3.0	
i 1	456.75762585034016	0.2525	74	702	4	4	15	17	5003	2	17	0	0	3.8488226289245264	
i 1	456.75762585034016	0.2525	76	204	4	20	12	16	0	2	16	0	0	4.000000000000001	
i 1	456.75842857142857	1.7675	74	702	4	24	12	17	5003	2	17	0	0	3.0	
i 1	456.9803333333333	1.01	73	1088	3	20	3	16	0	1	16	0	0	4.000000000000001	
i 1	456.98675510204083	0.2525	76	702	2	20	3	16	5003	2	16	0	0	4.000000000000001	
i 1	456.99959863945577	0.505	69	702	5	5	2	1	0	-1	1	0	0	2.0	
i 1	457.00842857142857	0.2525	76	702	2	24	8	17	5003	2	17	0	0	8.0	
i 1	457.0116394557823	1.7675	73	1088	3	20	13	16	0	2	16	0	0	4.000000000000001	
i 1	457.01485034013604	0.2525	74	204	7	2	3	16	0	2	16	0	0	3.8488226289245264	
i 1	457.0164557823129	1.01	73	1088	3	20	6	17	0	1	17	0	0	4.000000000000001	
i 1	457.50842857142857	0.2525	74	702	6	1	14	17	5003	1	17	0	0	2.0	
i 1	457.51725850340137	0.2525	77	702	2	4	12	17	0	1	17	0	0	3.8488226289245264	
i 1	457.7335442176871	0.505	69	1088	3	5	15	0	0	-1	0	0	0	2.0	
i 1	457.73595238095237	2.525	76	702	2	24	15	16	0	2	16	0	0	8.0	
i 1	457.7479931972789	1.01	76	702	2	20	13	16	5003	2	16	0	0	4.000000000000001	
i 1	457.75441496598637	0.2525	69	702	5	5	6	1	0	-1	1	0	0	2.0	
i 1	457.75762585034016	0.2525	74	1088	6	1	4	17	0	1	17	0	0	2.0	
i 1	457.76886394557823	0.505	69	204	5	5	1	1	0	0	1	0	0	2.0	
i 1	457.98274149659863	0.2525	77	204	7	1	11	16	0	2	16	0	0	2.0	
i 1	457.99558503401363	2.02	74	1088	3	9	12	16	0	2	16	0	0	2.8488226289245264	
i 1	457.99638775510203	1.7675	72	702	4	5	2	1	5003	0	1	0	0	2.0	
i 1	458.00120408163264	1.01	72	702	5	5	13	1	0	-1	1	0	0	2.0	
i 1	458.0108367346939	2.02	74	204	7	2	9	16	0	2	16	0	0	3.8488226289245264	
i 1	458.24879591836736	1.01	74	702	6	1	15	17	0	1	17	0	0	2.0	
i 1	458.25040136054423	0.7575000000000001	74	702	6	1	1	17	5003	1	17	0	0	2.0	
i 1	458.25120408163264	0.2525	72	702	4	5	7	1	5003	0	1	0	0	2.0	
i 1	458.49558503401363	1.5150000000000001	77	204	7	1	2	16	0	2	16	0	0	2.0	
i 1	458.49638775510203	0.2525	69	204	5	5	9	1	0	0	1	0	0	2.0	
i 1	458.73274149659863	4.04	76	702	2	20	12	16	0	1	16	0	0	4.000000000000001	
i 1	458.73595238095237	0.2525	76	702	4	20	9	16	5003	2	16	0	0	4.000000000000001	
i 1	458.74157142857143	0.2525	69	1088	3	5	15	0	0	-1	0	0	0	2.0	
i 1	458.75762585034016	1.2625	74	1088	6	1	11	17	0	1	17	0	0	2.0	
i 1	458.75842857142857	0.2525	77	1088	3	9	7	17	0	1	17	0	0	2.8488226289245264	
i 1	458.76003401360543	0.2525	76	702	4	24	12	17	5003	2	17	0	0	8.0	
i 1	458.76886394557823	0.2525	76	204	4	20	4	17	0	1	17	0	0	4.000000000000001	
i 1	458.98274149659863	2.525	76	702	2	24	16	17	5003	2	17	0	0	8.0	
i 1	459.00521768707483	1.01	72	702	2	5	16	1	0	-1	1	0	0	2.0	
i 1	459.0068231292517	0.2525	74	702	6	1	3	17	5003	1	17	0	0	2.0	
i 1	459.00842857142857	0.2525	74	702	4	4	4	17	5003	2	17	0	0	3.8488226289245264	
i 1	459.01485034013604	6.565	72	204	7	5	6	0	0	0	0	0	0	2.0	
i 1	459.0164557823129	16.665	66	702	5	15	1	9	5003	2	9	0	0	1.6318777986229804	
i 1	459.01806122448977	1.2625	76	702	2	20	10	16	5003	2	16	0	0	4.000000000000001	
i 1	459.01886394557823	15.15	66	1088	4	18	4	6	0	1	6	0	0	0.04872182508915611	
i 1	459.23274149659863	0.2525	77	702	2	4	5	17	0	1	17	0	0	3.8488226289245264	
i 1	459.25120408163264	1.7675	74	1088	6	1	16	17	0	1	17	0	0	2.0	
i 1	459.25120408163264	6.565	72	1088	3	5	13	0	0	0	0	0	0	2.0	
i 1	459.48996598639457	1.2625	74	204	7	2	10	16	0	2	16	0	0	3.8488226289245264	
i 1	459.50120408163264	1.5150000000000001	74	204	7	1	7	16	0	2	16	0	0	2.0	
i 1	459.51324489795917	1.5150000000000001	77	1088	3	9	11	17	0	1	17	0	0	2.8488226289245264	
i 1	459.75120408163264	2.02	76	1088	3	24	8	17	0	1	17	0	0	8.0	
i 1	459.7656530612245	1.7675	73	1088	3	20	8	17	0	1	17	0	0	4.000000000000001	
i 1	459.9931768707483	2.02	74	702	2	3	5	16	0	2	16	0	0	3.8488226289245264	
i 1	459.9971904761905	0.2525	69	204	7	5	14	1	0	0	1	0	0	2.0	
i 1	459.9979931972789	0.505	74	702	6	1	3	17	0	1	17	0	0	2.0	
i 1	460.24076870748297	1.7675	74	702	5	3	8	16	5003	2	16	0	0	3.8488226289245264	
i 1	460.25521768707483	1.2625	69	702	5	5	16	1	0	-1	1	0	0	2.0	
i 1	460.26886394557823	1.01	72	702	4	5	12	1	5003	0	1	0	0	2.0	
i 1	460.48193877551023	2.02	77	204	7	1	15	16	0	2	16	0	0	2.0	
i 1	460.49157142857143	2.7775	74	1088	6	1	15	17	0	1	17	0	0	2.0	
i 1	460.98113605442177	0.2525	74	702	6	1	10	17	5003	1	17	0	0	2.0	
i 1	460.98675510204083	0.2525	77	702	2	4	10	17	0	1	17	0	0	3.8488226289245264	
i 1	461.0028095238095	2.7775	76	702	2	24	14	16	0	2	16	0	0	8.0	
i 1	461.0108367346939	0.505	76	702	2	20	10	16	5003	2	16	0	0	4.000000000000001	
i 1	461.23595238095237	0.2525	74	204	7	2	13	16	0	2	16	0	0	3.8488226289245264	
i 1	461.24397959183676	0.7575000000000001	73	1088	3	20	11	16	0	1	16	0	0	4.000000000000001	
i 1	461.24478231292517	0.2525	74	702	6	1	8	17	0	1	17	0	0	2.0	
i 1	461.4843469387755	0.505	74	1088	6	1	14	17	0	1	17	0	0	2.0	
i 1	461.4843469387755	0.2525	76	702	4	24	1	17	5003	2	17	0	0	8.0	
i 1	461.49237414965984	1.2625	74	702	4	4	13	17	5003	2	17	0	0	3.8488226289245264	
i 1	461.49397959183676	0.2525	69	204	7	5	14	1	0	0	1	0	0	2.0	
i 1	461.49558503401363	0.2525	76	204	4	20	5	17	0	1	17	0	0	4.000000000000001	
i 1	461.50040136054423	1.5150000000000001	77	702	2	4	1	17	0	1	17	0	0	3.8488226289245264	
i 1	461.51886394557823	0.2525	76	702	4	20	7	16	5003	2	16	0	0	4.000000000000001	
i 1	461.73274149659863	0.505	76	702	2	20	3	16	5003	2	16	0	0	4.000000000000001	
i 1	461.74237414965984	0.505	76	702	2	24	2	17	5003	2	17	0	0	8.0	
i 1	461.7616394557823	0.2525	76	1088	3	20	14	17	0	2	17	0	0	4.000000000000001	
i 1	461.76404761904763	0.2525	72	702	4	5	8	1	5003	0	1	0	0	2.0	
i 1	461.9931768707483	2.02	74	702	6	1	9	17	0	1	17	0	0	2.0	
i 1	462.0028095238095	1.7675	76	1088	3	24	12	17	0	1	17	0	0	8.0	
i 1	462.00923129251703	2.02	74	702	6	1	7	17	5003	1	17	0	0	2.0	
i 1	462.01003401360543	0.2525	74	204	7	2	14	16	0	2	16	0	0	3.8488226289245264	
i 1	462.23274149659863	0.2525	76	702	4	20	13	16	5003	2	16	0	0	4.000000000000001	
i 1	462.24237414965984	2.2725	74	702	2	3	3	16	0	2	16	0	0	3.8488226289245264	
i 1	462.2471904761905	0.2525	76	702	4	24	12	17	5003	2	17	0	0	8.0	
i 1	462.25842857142857	0.2525	76	204	4	20	9	17	0	2	17	0	0	4.000000000000001	
i 1	462.26324489795917	2.2725	74	702	5	3	11	16	5003	2	16	0	0	3.8488226289245264	
i 1	462.4835442176871	1.2625	76	702	2	20	11	16	5003	2	16	0	0	4.000000000000001	
i 1	462.50602040816324	0.2525	76	702	2	24	1	17	5003	2	17	0	0	8.0	
i 1	462.5068231292517	1.2625	73	1088	3	20	8	16	0	1	16	0	0	4.000000000000001	
i 1	462.99558503401363	0.2525	74	1088	3	9	11	16	0	2	16	0	0	2.8488226289245264	
i 1	463.23274149659863	1.5150000000000001	76	702	2	24	1	17	5003	2	17	0	0	8.0	
i 1	463.2335442176871	2.7775	73	1088	3	20	16	16	0	1	16	0	0	4.000000000000001	
i 1	463.2383605442177	0.2525	74	1088	6	1	14	17	0	1	17	0	0	2.0	
i 1	463.24076870748297	0.2525	74	204	7	2	9	16	0	2	16	0	0	3.8488226289245264	
i 1	463.26003401360543	2.7775	73	1088	3	20	10	16	0	2	16	0	0	4.000000000000001	
i 1	463.26485034013604	1.5150000000000001	76	702	2	20	13	16	0	1	16	0	0	4.000000000000001	
i 1	463.4843469387755	2.525	74	1088	6	1	15	17	0	1	17	0	0	2.0	
i 1	463.49157142857143	2.525	77	204	7	1	6	16	0	2	16	0	0	2.0	
i 1	463.5028095238095	0.505	77	702	2	4	12	17	0	1	17	0	0	3.8488226289245264	
i 1	463.9891632653061	1.7675	74	1088	3	9	14	16	0	2	16	0	0	2.8488226289245264	
i 1	463.99157142857143	0.2525	74	702	4	24	4	17	5003	2	17	0	0	3.0	
i 1	464.0028095238095	1.7675	74	204	7	2	1	16	0	2	16	0	0	3.8488226289245264	
i 1	464.2343469387755	1.7675	76	1088	3	24	15	17	0	1	17	0	0	8.0	
i 1	464.2383605442177	0.7575000000000001	76	702	2	20	4	16	5003	2	16	0	0	4.000000000000001	
i 1	464.24638775510203	0.7575000000000001	76	702	2	24	10	16	0	2	16	0	0	8.0	
i 1	464.2471904761905	0.2525	74	702	6	1	10	17	5003	1	17	0	0	2.0	
i 1	464.24879591836736	1.7675	73	1088	3	20	9	16	0	1	16	0	0	4.000000000000001	
i 1	464.49397959183676	0.2525	77	702	2	4	1	17	0	1	17	0	0	3.8488226289245264	
i 1	464.73193877551023	0.2525	72	702	4	5	7	1	5003	0	1	0	0	2.0	
i 1	464.76244217687076	0.2525	74	702	5	3	9	16	5003	2	16	0	0	3.8488226289245264	
i 1	464.98595238095237	1.5150000000000001	69	1088	3	5	9	0	0	-1	0	0	0	2.0	
i 1	464.9883605442177	1.7675	74	204	7	2	14	16	0	2	16	0	0	3.8488226289245264	
i 1	464.99157142857143	1.7675	77	1088	3	9	8	17	0	1	17	0	0	2.8488226289245264	
i 1	465.01806122448977	1.5150000000000001	69	204	7	5	10	1	0	0	1	0	0	2.0	
i 1	465.24879591836736	1.5150000000000001	76	702	2	24	12	16	0	2	16	0	0	8.0	
i 1	465.25040136054423	1.5150000000000001	76	702	2	20	14	16	5003	2	16	0	0	4.000000000000001	
i 1	465.25040136054423	2.2725	76	702	2	24	10	17	5003	2	17	0	0	8.0	
i 1	465.2656530612245	2.7775	76	702	2	20	4	16	0	1	16	0	0	4.000000000000001	
i 1	465.4979931972789	1.5150000000000001	74	702	4	24	10	17	0	1	17	0	0	3.0	
i 1	465.49959863945577	0.2525	74	702	4	24	14	17	5003	2	17	0	0	3.0	
i 1	465.7303333333333	2.525	74	702	5	3	10	16	5003	2	16	0	0	3.8488226289245264	
i 1	465.74558503401363	2.525	74	702	2	3	11	16	0	2	16	0	0	3.8488226289245264	
i 1	465.75602040816324	9.8475	66	702	5	15	15	9	5003	2	9	0	0	1.6318777986229804	
i 1	465.76003401360543	1.2625	74	702	4	24	14	17	5003	2	17	0	0	3.0	
i 1	465.76485034013604	0.2525	72	702	4	5	6	1	5003	0	1	0	0	2.0	
i 1	465.7696666666667	8.3325	61	702	4	19	6	6	0	2	6	0	0	0.04872182508915611	
i 1	465.98274149659863	0.2525	74	1088	6	1	7	17	0	1	17	0	0	2.0	
i 1	466.00120408163264	1.01	72	702	6	5	6	1	5003	0	1	0	0	2.0	
i 1	466.00602040816324	1.2625	72	702	2	5	9	1	0	-1	1	0	0	2.0	
i 1	466.23675510204083	1.5150000000000001	74	702	6	1	14	17	5003	1	17	0	0	2.0	
i 1	466.24638775510203	1.7675	76	1088	3	24	2	17	0	1	17	0	0	8.0	
i 1	466.26003401360543	1.2625	73	1088	3	20	1	16	0	1	16	0	0	4.000000000000001	
i 1	466.26806122448977	1.5150000000000001	74	702	6	1	8	17	0	1	17	0	0	2.0	
i 1	466.5020068027211	2.02	72	1088	3	5	7	0	0	0	0	0	0	2.0	
i 1	466.51404761904763	2.02	72	204	7	5	5	0	0	0	0	0	0	2.0	
i 1	466.76003401360543	0.505	77	702	2	4	3	17	0	1	17	0	0	3.8488226289245264	
i 1	466.7608367346939	0.2525	74	204	7	2	4	16	0	2	16	0	0	3.8488226289245264	
i 1	466.9843469387755	2.2725	77	204	7	1	7	16	0	2	16	0	0	2.0	
i 1	467.0108367346939	2.2725	74	1088	6	1	14	17	0	1	17	0	0	2.0	
i 1	467.0116394557823	0.505	69	1088	3	5	8	0	0	-1	0	0	0	2.0	
i 1	467.23274149659863	0.2525	74	1088	3	9	2	16	0	2	16	0	0	2.8488226289245264	
i 1	467.24558503401363	0.2525	76	702	2	20	4	16	5003	2	16	0	0	4.000000000000001	
i 1	467.4843469387755	0.2525	69	204	7	5	3	1	0	0	1	0	0	2.0	
i 1	467.48675510204083	0.2525	76	702	4	24	10	17	5003	2	17	0	0	8.0	
i 1	467.4883605442177	0.2525	74	204	7	2	7	16	0	2	16	0	0	3.8488226289245264	
i 1	467.4891632653061	1.5150000000000001	76	702	2	24	3	16	0	2	16	0	0	8.0	
i 1	467.49076870748297	0.2525	76	702	4	20	13	16	5003	2	16	0	0	4.000000000000001	
i 1	467.49237414965984	1.5150000000000001	73	1088	3	20	10	16	0	1	16	0	0	4.000000000000001	
i 1	467.5028095238095	0.2525	76	204	4	20	13	16	0	1	16	0	0	4.000000000000001	
i 1	467.5108367346939	0.2525	73	204	4	20	2	16	0	1	16	0	0	4.000000000000001	
i 1	467.73675510204083	0.2525	76	1088	3	20	16	16	0	2	16	0	0	4.000000000000001	
i 1	467.73755782312924	0.2525	72	702	2	5	4	1	0	-1	1	0	0	2.0	
i 1	467.7479931972789	1.5150000000000001	74	702	4	4	1	17	5003	2	17	0	0	3.8488226289245264	
i 1	467.75120408163264	1.5150000000000001	77	702	2	4	13	17	0	1	17	0	0	3.8488226289245264	
i 1	467.75762585034016	0.7575000000000001	76	702	2	20	7	16	5003	2	16	0	0	4.000000000000001	
i 1	467.75923129251703	0.7575000000000001	73	1088	3	20	13	17	0	1	17	0	0	4.000000000000001	
i 1	467.7664557823129	0.2525	76	702	2	24	7	17	5003	2	17	0	0	8.0	
i 1	467.76806122448977	0.2525	74	702	4	24	15	17	5003	2	17	0	0	3.0	
i 1	467.7696666666667	0.2525	72	702	6	5	8	1	5003	0	1	0	0	2.0	
i 1	467.9843469387755	1.5150000000000001	72	702	4	5	7	1	5003	0	1	0	0	2.0	
i 1	467.99237414965984	0.2525	74	702	6	1	8	17	5003	1	17	0	0	2.0	
i 1	468.0164557823129	1.5150000000000001	69	702	3	5	12	1	0	-1	1	0	0	2.0	
i 1	468.01886394557823	3.0300000000000002	74	1088	6	1	14	17	0	1	17	0	0	2.0	
i 1	468.24478231292517	0.2525	74	1088	3	9	1	16	0	2	16	0	0	2.8488226289245264	
i 1	468.48595238095237	1.7675	74	702	2	3	3	16	0	2	16	0	0	3.8488226289245264	
i 1	468.49157142857143	0.2525	74	702	4	24	1	17	0	1	17	0	0	3.0	
i 1	468.49397959183676	0.2525	76	204	4	20	4	17	0	1	17	0	0	4.000000000000001	
i 1	468.4979931972789	0.2525	76	702	4	24	10	17	5003	2	17	0	0	8.0	
i 1	468.50040136054423	0.2525	76	702	4	20	2	16	5003	2	16	0	0	4.000000000000001	
i 1	468.5028095238095	0.2525	69	1088	3	5	13	0	0	-1	0	0	0	2.0	
i 1	468.50441496598637	0.2525	76	204	4	20	6	16	0	1	16	0	0	4.000000000000001	
i 1	468.50521768707483	1.2625	76	702	2	20	8	16	0	1	16	0	0	4.000000000000001	
i 1	468.50762585034016	1.7675	74	702	5	3	6	16	5003	2	16	0	0	3.8488226289245264	
i 1	468.5196666666667	0.2525	72	702	6	5	4	1	5003	0	1	0	0	2.0	
i 1	468.5196666666667	1.2625	76	1088	3	24	1	17	0	1	17	0	0	8.0	
i 1	468.73274149659863	0.505	73	1088	3	20	6	16	0	2	16	0	0	4.000000000000001	
i 1	468.73595238095237	0.505	76	702	2	24	1	17	5003	2	17	0	0	8.0	
i 1	468.75040136054423	0.2525	76	1088	3	20	6	17	0	2	17	0	0	4.000000000000001	
i 1	468.7520068027211	0.2525	72	702	2	5	7	1	0	-1	1	0	0	2.0	
i 1	468.7608367346939	2.2725	74	204	7	1	8	16	0	2	16	0	0	2.0	
i 1	469.0116394557823	4.04	72	1088	3	5	5	0	0	0	0	0	0	2.0	
i 1	469.0156530612245	5.05	72	204	7	5	3	0	0	0	0	0	0	2.0	
i 1	469.2335442176871	0.2525	76	204	4	20	11	16	0	2	16	0	0	4.000000000000001	
i 1	469.24237414965984	0.2525	76	702	4	20	6	16	5003	2	16	0	0	4.000000000000001	
i 1	469.2471904761905	0.2525	76	204	4	20	11	16	0	1	16	0	0	4.000000000000001	
i 1	469.24879591836736	2.7775	74	1088	3	9	11	16	0	2	16	0	0	2.8488226289245264	
i 1	469.25842857142857	3.535	76	702	2	24	14	16	0	2	16	0	0	8.0	
i 1	469.2608367346939	0.2525	76	702	4	24	14	17	5003	2	17	0	0	8.0	
i 1	469.2616394557823	2.7775	74	204	7	2	7	16	0	2	16	0	0	3.8488226289245264	
i 1	469.26806122448977	0.2525	74	702	6	1	12	17	0	1	17	0	0	2.0	
i 1	469.26886394557823	0.505	74	702	6	1	11	17	5003	1	17	0	0	2.0	
i 1	469.26886394557823	4.7975	73	1088	3	20	9	16	0	1	16	0	0	4.000000000000001	
i 1	469.48514965986396	0.505	73	1088	3	20	3	17	0	1	17	0	0	4.000000000000001	
i 1	469.48514965986396	0.2525	76	702	2	24	9	17	5003	2	17	0	0	8.0	
i 1	469.49397959183676	0.505	73	1088	3	20	11	17	0	1	17	0	0	4.000000000000001	
i 1	469.49879591836736	0.2525	72	702	2	5	11	1	0	-1	1	0	0	2.0	
i 1	469.50842857142857	0.7575000000000001	74	702	4	24	5	17	5003	2	17	0	0	3.0	
i 1	469.5116394557823	0.505	76	702	2	20	12	16	5003	2	16	0	0	4.000000000000001	
i 1	469.51886394557823	0.2525	72	702	6	5	15	1	5003	0	1	0	0	2.0	
i 1	469.7303333333333	0.2525	69	702	3	5	6	1	0	-1	1	0	0	2.0	
i 1	469.73514965986396	0.2525	69	1088	3	5	7	0	0	-1	0	0	0	2.0	
i 1	469.76485034013604	0.2525	77	204	7	1	15	16	0	2	16	0	0	2.0	
i 1	469.98193877551023	0.505	73	204	4	20	4	16	0	2	16	0	0	4.000000000000001	
i 1	469.98595238095237	1.5150000000000001	76	1088	3	24	1	17	0	1	17	0	0	8.0	
i 1	469.98675510204083	1.5150000000000001	76	702	2	20	4	16	0	1	16	0	0	4.000000000000001	
i 1	470.00521768707483	2.525	74	1088	6	1	8	17	0	1	17	0	0	2.0	
i 1	470.00762585034016	0.505	73	204	4	20	11	16	0	2	16	0	0	4.000000000000001	
i 1	470.01725850340137	0.2525	76	702	4	20	7	16	5003	2	16	0	0	4.000000000000001	
i 1	470.01886394557823	0.505	76	702	4	24	10	17	5003	2	17	0	0	8.0	
i 1	470.2343469387755	0.2525	74	204	7	2	1	16	0	2	16	0	0	3.8488226289245264	
i 1	470.2383605442177	3.7875	77	204	7	1	9	16	0	2	16	0	0	2.0	
i 1	470.26886394557823	0.2525	74	702	4	4	13	17	5003	2	17	0	0	3.8488226289245264	
i 1	470.4883605442177	0.2525	76	702	2	24	12	17	5003	2	17	0	0	8.0	
i 1	470.49478231292517	0.2525	77	1088	3	9	7	17	0	1	17	0	0	2.8488226289245264	
i 1	470.49959863945577	0.2525	72	702	4	5	14	1	5003	0	1	0	0	2.0	
i 1	470.51003401360543	0.2525	76	1088	3	20	12	16	0	2	16	0	0	4.000000000000001	
i 1	470.51485034013604	0.2525	76	1088	3	20	3	17	0	1	17	0	0	4.000000000000001	
i 1	470.7343469387755	0.2525	74	702	5	3	16	16	5003	2	16	0	0	3.8488226289245264	
i 1	470.73595238095237	0.2525	76	702	4	24	11	17	5003	2	17	0	0	8.0	
i 1	470.73675510204083	0.505	69	702	3	5	7	1	0	-1	1	0	0	2.0	
i 1	470.74959863945577	0.2525	73	204	4	20	4	17	0	1	17	0	0	4.000000000000001	
i 1	470.75762585034016	0.2525	74	702	4	4	12	17	5003	2	17	0	0	3.8488226289245264	
i 1	470.75762585034016	0.2525	69	1088	3	5	2	0	0	-1	0	0	0	2.0	
i 1	470.76404761904763	0.2525	76	702	4	20	6	16	5003	2	16	0	0	4.000000000000001	
i 1	470.76485034013604	0.2525	76	204	4	20	16	17	0	2	17	0	0	4.000000000000001	
i 1	471.0028095238095	0.2525	74	702	4	24	12	17	5003	2	17	0	0	3.0	
i 1	471.00842857142857	0.505	76	702	2	24	12	17	5003	2	17	0	0	8.0	
i 1	471.01324489795917	2.02	74	204	7	2	16	16	0	2	16	0	0	3.8488226289245264	
i 1	471.0156530612245	0.7575000000000001	76	1088	3	20	5	16	0	2	16	0	0	4.000000000000001	
i 1	471.0164557823129	0.7575000000000001	76	702	2	20	1	16	5003	2	16	0	0	4.000000000000001	
i 1	471.01806122448977	0.2525	74	702	4	24	9	17	0	1	17	0	0	3.0	
i 1	471.0196666666667	2.02	77	1088	3	9	10	17	0	1	17	0	0	2.8488226289245264	
i 1	471.23514965986396	0.505	76	1088	3	20	8	17	0	1	17	0	0	4.000000000000001	
i 1	471.24157142857143	0.7575000000000001	72	702	2	5	2	1	0	-1	1	0	0	2.0	
i 1	471.24397959183676	0.2525	69	204	7	5	15	1	0	0	1	0	0	2.0	
i 1	471.24638775510203	1.7675	74	702	6	1	1	17	0	1	17	0	0	2.0	
i 1	471.26324489795917	2.02	74	702	6	1	16	17	5003	1	17	0	0	2.0	
i 1	471.50040136054423	0.505	72	702	4	5	12	1	5003	0	1	0	0	2.0	
i 1	471.73193877551023	2.2725	76	702	2	20	12	16	0	1	16	0	0	4.000000000000001	
i 1	471.7471904761905	0.505	76	702	4	24	1	17	5003	2	17	0	0	8.0	
i 1	471.76244217687076	1.5150000000000001	76	1088	3	24	8	17	0	1	17	0	0	8.0	
i 1	471.76485034013604	0.505	76	702	4	20	15	16	5003	2	16	0	0	4.000000000000001	
i 1	471.76725850340137	0.505	73	204	4	20	2	17	0	1	17	0	0	4.000000000000001	
i 1	471.76806122448977	0.505	76	204	4	20	16	17	0	1	17	0	0	4.000000000000001	
i 1	471.9835442176871	3.535	74	702	5	3	2	16	5003	2	16	0	0	3.8488226289245264	
i 1	471.98755782312924	2.02	69	204	7	5	15	1	0	0	1	0	0	2.0	
i 1	471.99397959183676	2.02	69	1088	3	5	5	0	0	-1	0	0	0	2.0	
i 1	472.01404761904763	2.02	74	702	2	3	4	16	0	2	16	0	0	3.8488226289245264	
i 1	472.2343469387755	1.01	73	1088	3	20	12	16	0	1	16	0	0	4.000000000000001	
i 1	472.24237414965984	1.7675	73	1088	3	20	4	17	0	2	17	0	0	4.000000000000001	
i 1	472.2479931972789	1.7675	76	702	2	24	7	17	5003	2	17	0	0	8.0	
i 1	472.4883605442177	1.5150000000000001	61	702	4	19	16	6	0	1	6	0	0	0.04872182508915611	
i 1	472.50923129251703	1.5150000000000001	66	204	4	14	9	6	0	1	6	0	0	3.017595686385947	
i 1	472.51003401360543	1.5150000000000001	74	1088	6	1	15	17	0	1	17	0	0	2.0	
i 1	472.51244217687076	1.5150000000000001	61	1088	4	16	16	9	0	1	9	0	0	2.8075281002507912	
i 1	472.99157142857143	1.01	76	702	2	24	1	16	0	2	16	0	0	8.0	
i 1	472.99397959183676	0.2525	74	204	6	2	12	16	0	2	16	0	0	3.8488226289245264	
i 1	472.99959863945577	0.2525	74	1088	6	1	5	17	0	1	17	0	0	2.0	
i 1	473.00441496598637	1.01	76	702	2	20	4	16	5003	2	16	0	0	4.000000000000001	
i 1	473.01725850340137	0.505	74	702	4	4	13	17	5003	2	17	0	0	3.8488226289245264	
i 1	473.0196666666667	0.2525	72	702	2	5	10	1	0	-1	1	0	0	2.0	
i 1	473.24638775510203	0.7575000000000001	77	702	2	4	7	17	0	1	17	0	0	3.8488226289245264	
i 1	473.24959863945577	0.7575000000000001	74	702	4	24	10	17	0	1	17	0	0	3.0	
i 1	473.25762585034016	0.2525	72	702	6	5	7	1	5003	0	1	0	0	2.0	
i 1	473.25842857142857	0.2525	74	702	4	24	6	17	5003	2	17	0	0	3.0	
i 1	473.48274149659863	0.2525	74	204	7	2	12	16	0	2	16	0	0	3.8488226289245264	
i 1	473.50762585034016	2.02	74	702	6	1	8	17	5003	1	17	0	0	2.0	
i 1	473.73514965986396	0.2525	77	1088	3	9	9	17	0	1	17	0	0	2.8488226289245264	
i 1	473.73755782312924	0.2525	73	1088	3	20	2	16	0	1	16	0	0	4.000000000000001	
i 1	473.75441496598637	0.2525	72	1088	3	5	10	0	0	0	0	0	0	2.0	
i 1	473.9843469387755	5.3025	61	1192	4	14	13	6	0	1	6	0	0	3.017595686385947	
i 1	473.98595238095237	1.5150000000000001	74	925	4	24	10	17	0	2	17	0	0	3.0	
i 1	473.98675510204083	5.3025	66	1192	5	14	1	6	0	2	6	0	0	3.017595686385947	
i 1	473.9883605442177	1.5150000000000001	61	925	4	19	13	6	0	1	6	0	0	0.04872182508915611	
i 1	473.98996598639457	9.8475	76	1192	4	20	6	17	0	2	17	0	0	4.000000000000001	
i 1	473.99157142857143	9.8475	66	1192	5	14	10	6	0	1	6	0	0	3.983178401878601	
i 1	473.99397959183676	0.7575000000000001	77	925	2	3	5	16	0	2	16	0	0	3.8488226289245264	
i 1	473.99638775510203	1.5150000000000001	61	925	4	19	10	6	0	2	6	0	0	0.04872182508915611	
i 1	473.99959863945577	1.01	77	1192	6	1	9	16	0	1	16	0	0	2.0	
i 1	474.00120408163264	2.02	69	1192	4	5	12	1	0	0	1	0	0	2.0	
i 1	474.0028095238095	0.505	69	1192	6	5	12	1	0	-1	1	0	0	2.0	
i 1	474.00361224489797	9.8475	61	1192	4	18	15	9	0	2	9	0	0	0.04872182508915611	
i 1	474.00602040816324	9.8475	61	1192	4	16	16	6	0	1	6	0	0	2.8075281002507912	
i 1	474.00602040816324	9.8475	61	1192	6	17	10	6	0	2	6	0	0	0.04872182508915611	
i 1	474.00602040816324	3.7875	73	1192	4	20	4	17	0	2	17	0	0	4.000000000000001	
i 1	474.0068231292517	9.8475	66	1192	5	13	15	9	0	1	9	0	0	0.45622749699517	
i 1	474.00762585034016	0.505	76	925	2	24	4	16	5003	2	16	0	0	8.0	
i 1	474.00923129251703	1.5150000000000001	73	925	2	24	12	16	0	2	16	0	0	8.0	
i 1	474.0116394557823	9.8475	61	1192	4	18	16	9	0	1	9	0	0	0.04872182508915611	
i 1	474.01244217687076	9.8475	66	1192	6	17	15	9	0	1	9	0	0	0.04872182508915611	
i 1	474.01244217687076	1.5150000000000001	73	925	2	20	3	16	0	2	16	0	0	4.000000000000001	
i 1	474.01404761904763	0.505	76	925	2	20	14	17	5003	1	17	0	0	4.000000000000001	
i 1	474.01485034013604	0.2525	72	702	6	5	10	1	5003	0	1	0	0	2.0	
i 1	474.0156530612245	3.7875	69	1192	6	5	15	1	0	0	1	0	0	2.0	
i 1	474.0164557823129	0.505	77	1192	6	1	2	17	0	1	17	0	0	2.0	
i 1	474.01725850340137	1.5150000000000001	77	925	2	4	1	17	0	1	17	0	0	3.8488226289245264	
i 1	474.01725850340137	9.8475	76	1192	4	20	15	16	0	1	16	0	0	4.000000000000001	
i 1	474.24478231292517	0.2525	69	925	3	5	8	0	0	0	0	0	0	2.0	
i 1	474.49638775510203	0.2525	76	702	4	20	13	16	5003	2	16	0	0	4.000000000000001	
i 1	474.50040136054423	3.0300000000000002	69	1192	4	5	11	0	0	0	0	0	0	2.0	
i 1	474.5020068027211	0.505	77	1192	6	1	9	17	0	1	17	0	0	2.0	
i 1	474.50842857142857	0.2525	74	1192	5	9	2	17	0	2	17	0	0	2.8488226289245264	
i 1	474.51404761904763	1.01	72	702	6	5	14	1	5003	0	1	0	0	2.0	
i 1	474.5196666666667	0.2525	76	702	4	24	12	17	5003	1	17	0	0	8.0	
i 1	474.73675510204083	1.7675	76	1192	4	24	15	16	0	1	16	0	0	8.0	
i 1	474.74478231292517	1.2625	74	1192	6	2	8	17	0	1	17	0	0	3.8488226289245264	
i 1	474.74478231292517	0.505	73	925	2	20	12	17	5003	1	17	0	0	4.000000000000001	
i 1	474.75521768707483	0.505	73	925	2	24	5	17	5003	1	17	0	0	8.0	
i 1	474.7656530612245	2.2725	77	1192	4	9	7	16	0	1	16	0	0	2.8488226289245264	
i 1	474.98595238095237	0.2525	74	1192	6	1	12	17	0	1	17	0	0	2.0	
i 1	474.99076870748297	0.505	74	925	6	1	8	16	0	1	16	0	0	2.0	
i 1	475.01244217687076	2.02	77	1192	6	2	3	17	0	1	17	0	0	3.8488226289245264	
i 1	475.25441496598637	0.2525	73	702	4	20	15	17	5003	2	17	0	0	4.000000000000001	
i 1	475.26003401360543	0.2525	77	1192	6	1	1	16	0	1	16	0	0	2.0	
i 1	475.48113605442177	8.3325	61	610	5	13	10	9	0	2	9	0	0	0.7673465283066598	
i 1	475.48514965986396	8.3325	66	610	6	17	14	6	0	1	6	0	0	0.04872182508915611	
i 1	475.48595238095237	0.2525	77	610	5	3	4	16	0	2	16	0	0	3.8488226289245264	
i 1	475.48755782312924	2.02	77	926	6	1	16	16	0	1	16	0	0	2.0	
i 1	475.48755782312924	0.2525	73	926	2	20	4	17	0	1	17	0	0	4.000000000000001	
i 1	475.49076870748297	0.2525	69	610	6	5	11	0	0	-1	0	0	0	2.0	
i 1	475.49237414965984	8.3325	66	610	6	17	11	6	0	1	6	0	0	0.04872182508915611	
i 1	475.4931768707483	4.04	74	610	6	1	10	17	0	1	17	0	0	2.0	
i 1	475.49558503401363	0.505	74	926	4	24	1	17	0	2	17	0	0	3.0	
i 1	475.49558503401363	0.2525	77	926	2	4	12	17	0	2	17	0	0	3.8488226289245264	
i 1	475.50040136054423	8.3325	61	610	5	15	14	6	0	2	6	0	0	1.6318777986229804	
i 1	475.50361224489797	8.3325	61	926	4	19	11	6	0	2	6	0	0	0.04872182508915611	
i 1	475.50361224489797	0.7575000000000001	73	926	2	20	16	16	0	1	16	0	0	4.000000000000001	
i 1	475.50441496598637	8.3325	66	610	5	15	1	9	0	1	9	0	0	1.6318777986229804	
i 1	475.5116394557823	0.7575000000000001	77	610	4	24	10	17	0	1	17	0	0	3.0	
i 1	475.51324489795917	8.3325	61	926	4	19	12	9	0	2	9	0	0	0.04872182508915611	
i 1	475.51886394557823	2.2725	76	926	2	24	16	16	0	1	16	0	0	8.0	
i 1	475.5196666666667	8.3325	66	610	5	7	3	9	0	1	9	0	0	2.267512633692852	
i 1	475.7479931972789	4.7975	74	926	2	3	3	16	0	2	16	0	0	3.8488226289245264	
i 1	475.76324489795917	0.2525	76	610	4	20	1	16	0	1	16	0	0	4.000000000000001	
i 1	475.7664557823129	0.505	69	1192	6	5	12	1	0	-1	1	0	0	2.0	
i 1	475.9803333333333	0.505	76	926	2	20	11	16	0	2	16	0	0	4.000000000000001	
i 1	475.98193877551023	0.505	77	1192	6	1	16	17	0	1	17	0	0	2.0	
i 1	476.00040136054423	0.505	72	926	2	5	5	0	0	-1	0	0	0	2.0	
i 1	476.01886394557823	4.7975	77	610	5	3	5	16	0	2	16	0	0	3.8488226289245264	
i 1	476.2303333333333	2.7775	69	1192	4	5	13	1	0	0	1	0	0	2.0	
i 1	476.25602040816324	5.05	77	1192	6	1	2	17	0	1	17	0	0	2.0	
i 1	476.48996598639457	2.525	69	1192	6	5	8	1	0	-1	1	0	0	2.0	
i 1	476.5020068027211	2.02	77	1192	6	1	16	16	0	1	16	0	0	2.0	
i 1	476.73113605442177	2.02	77	926	2	4	4	17	0	2	17	0	0	3.8488226289245264	
i 1	476.7656530612245	2.02	74	610	4	4	5	16	0	2	16	0	0	3.8488226289245264	
i 1	476.76806122448977	1.01	76	1192	4	24	7	16	0	1	16	0	0	8.0	
i 1	476.99237414965984	3.0300000000000002	73	926	2	20	2	16	0	1	16	0	0	4.000000000000001	
i 1	477.01404761904763	0.2525	76	926	2	20	3	16	0	2	16	0	0	4.000000000000001	
i 1	477.2479931972789	0.2525	73	610	4	20	13	16	0	2	16	0	0	4.000000000000001	
i 1	477.48595238095237	0.2525	69	610	6	5	5	0	0	-1	0	0	0	2.0	
i 1	477.5028095238095	0.2525	77	1192	6	1	11	17	0	1	17	0	0	2.0	
i 1	477.51244217687076	2.02	76	926	2	20	5	17	0	1	17	0	0	4.000000000000001	
i 1	477.7343469387755	2.2725	69	610	6	5	13	1	0	0	1	0	0	2.0	
i 1	477.7471904761905	2.2725	72	926	2	5	11	0	0	-1	0	0	0	2.0	
i 1	477.75521768707483	1.7675	77	926	6	1	16	16	0	1	16	0	0	2.0	
i 1	477.99237414965984	5.8075	76	926	2	24	5	16	0	1	16	0	0	8.0	
i 1	478.01806122448977	5.8075	73	1192	4	20	5	17	0	2	17	0	0	4.000000000000001	
i 1	478.50361224489797	0.2525	77	1192	6	1	8	17	0	1	17	0	0	2.0	
i 1	478.7343469387755	2.7775	77	1192	6	1	12	16	0	1	16	0	0	2.0	
i 1	478.74478231292517	0.2525	74	1192	6	2	5	17	0	1	17	0	0	3.8488226289245264	
i 1	478.98755782312924	0.2525	69	1192	6	5	2	1	0	0	1	0	0	2.0	
i 1	478.99558503401363	0.2525	69	1192	4	5	6	0	0	0	0	0	0	2.0	
i 1	479.0116394557823	0.2525	74	1192	5	9	15	17	0	2	17	0	0	2.8488226289245264	
i 1	479.01806122448977	1.2625	76	1192	4	24	15	16	0	1	16	0	0	8.0	
i 1	479.2303333333333	0.2525	77	926	2	4	7	17	0	2	17	0	0	3.8488226289245264	
i 1	479.23595238095237	1.01	69	1192	6	5	14	0	0	0	0	0	0	2.0	
i 1	479.23595238095237	4.545	61	1192	5	14	2	6	0	1	6	0	0	3.017595686385947	
i 1	479.24157142857143	1.01	69	1192	6	5	1	1	0	0	1	0	0	2.0	
i 1	479.24478231292517	4.545	61	1192	4	16	1	6	0	2	6	0	0	2.8075281002507912	
i 1	479.2479931972789	2.2725	69	610	6	5	5	0	0	-1	0	0	0	2.0	
i 1	479.24879591836736	2.2725	72	926	3	5	14	0	0	0	0	0	0	2.0	
i 1	479.2520068027211	4.545	66	1192	4	14	12	6	0	2	6	0	0	3.017595686385947	
i 1	479.26485034013604	0.2525	77	1192	5	9	5	16	0	1	16	0	0	2.8488226289245264	
i 1	479.48514965986396	0.2525	73	610	4	20	4	17	0	2	17	0	0	4.000000000000001	
i 1	479.4883605442177	2.7775	74	1192	6	2	3	17	0	1	17	0	0	3.8488226289245264	
i 1	479.51003401360543	0.2525	74	1192	6	1	13	17	0	1	17	0	0	2.0	
i 1	479.51324489795917	2.7775	74	1192	5	9	13	17	0	2	17	0	0	2.8488226289245264	
i 1	479.7616394557823	0.2525	76	926	2	20	10	17	0	1	17	0	0	4.000000000000001	
i 1	479.7656530612245	0.2525	74	926	4	24	7	17	0	2	17	0	0	3.0	
i 1	480.00602040816324	0.2525	74	1192	6	1	14	17	0	1	17	0	0	2.0	
i 1	480.00602040816324	2.7775	77	610	4	24	16	17	0	1	17	0	0	3.0	
i 1	480.25040136054423	0.2525	69	1192	6	5	14	1	0	-1	1	0	0	2.0	
i 1	480.26725850340137	2.525	74	926	4	24	6	17	0	2	17	0	0	3.0	
i 1	480.26806122448977	0.2525	69	1192	4	5	12	1	0	0	1	0	0	2.0	
i 1	480.51806122448977	0.2525	69	610	6	5	16	1	0	0	1	0	0	2.0	
i 1	480.5196666666667	0.2525	77	1192	5	9	2	16	0	1	16	0	0	2.8488226289245264	
i 1	480.7303333333333	0.2525	76	926	2	20	9	17	0	1	17	0	0	4.000000000000001	
i 1	480.73996598639457	3.0300000000000002	69	1192	6	5	4	1	0	0	1	0	0	2.0	
i 1	480.74638775510203	2.02	76	1192	4	24	12	16	0	1	16	0	0	8.0	
i 1	480.75521768707483	0.2525	77	926	2	4	5	17	0	2	17	0	0	3.8488226289245264	
i 1	480.76244217687076	3.0300000000000002	69	1192	6	5	6	0	0	0	0	0	0	2.0	
i 1	480.9843469387755	0.2525	76	610	4	20	16	17	0	1	17	0	0	4.000000000000001	
i 1	481.01003401360543	0.505	74	926	2	3	15	16	0	2	16	0	0	3.8488226289245264	
i 1	481.0156530612245	1.5150000000000001	73	926	2	20	13	16	0	1	16	0	0	4.000000000000001	
i 1	481.23996598639457	2.525	74	610	6	1	14	17	0	1	17	0	0	2.0	
i 1	481.2528095238095	1.7675	77	1192	5	9	14	16	0	1	16	0	0	2.8488226289245264	
i 1	481.25923129251703	1.2625	73	926	2	20	8	16	0	1	16	0	0	4.000000000000001	
i 1	481.49076870748297	1.5150000000000001	77	1192	6	2	13	17	0	1	17	0	0	3.8488226289245264	
i 1	481.49397959183676	0.505	69	610	6	5	5	1	0	0	1	0	0	2.0	
i 1	481.50842857142857	0.2525	72	926	2	5	2	0	0	-1	0	0	0	2.0	
i 1	481.5164557823129	0.2525	77	1192	6	1	3	17	0	1	17	0	0	2.0	
i 1	481.51806122448977	1.2625	76	926	2	24	13	16	0	2	16	0	0	8.0	
i 1	481.75602040816324	0.2525	69	610	6	5	6	0	0	-1	0	0	0	2.0	
i 1	481.7568231292517	2.02	77	926	6	1	14	16	0	1	16	0	0	2.0	
i 1	482.00602040816324	1.5150000000000001	74	926	2	3	9	16	0	2	16	0	0	3.8488226289245264	
i 1	482.0108367346939	0.505	69	1192	6	5	1	1	0	-1	1	0	0	2.0	
i 1	482.01404761904763	1.2625	77	610	5	3	2	16	0	2	16	0	0	3.8488226289245264	
i 1	482.48595238095237	0.2525	69	610	6	5	6	1	0	0	1	0	0	2.0	
i 1	482.50441496598637	0.505	72	926	3	5	10	0	0	0	0	0	0	2.0	
i 1	482.5156530612245	1.2625	77	926	2	4	5	17	0	2	17	0	0	3.8488226289245264	
i 1	482.5196666666667	1.2625	74	610	4	4	12	16	0	2	16	0	0	3.8488226289245264	
i 1	482.7479931972789	0.2525	74	1192	6	1	9	17	0	1	17	0	0	2.0	
i 1	482.74879591836736	0.2525	77	1192	6	1	13	17	0	1	17	0	0	2.0	
i 1	482.98193877551023	0.7575000000000001	73	926	2	20	15	16	0	1	16	0	0	4.000000000000001	
i 1	482.99397959183676	0.7575000000000001	74	926	4	24	8	17	0	2	17	0	0	3.0	
i 1	482.99638775510203	0.2525	77	1192	6	1	6	17	0	1	17	0	0	2.0	
i 1	482.99879591836736	0.7575000000000001	73	926	2	20	2	16	0	1	16	0	0	4.000000000000001	
i 1	483.0028095238095	0.7575000000000001	76	1192	4	24	10	16	0	1	16	0	0	8.0	
i 1	483.00361224489797	0.7575000000000001	69	1192	6	5	14	1	0	-1	1	0	0	2.0	
i 1	483.01244217687076	0.7575000000000001	76	926	2	24	11	16	0	2	16	0	0	8.0	
i 1	483.25602040816324	0.2525	77	1192	6	1	1	16	0	1	16	0	0	2.0	
i 1	483.26886394557823	0.505	72	926	2	5	8	0	0	-1	0	0	0	2.0	
i 1	483.49959863945577	0.2525	77	610	5	3	16	16	0	2	16	0	0	3.8488226289245264	
i 1	483.73274149659863	22.725	66	205	5	16	10	6	0	2	6	0	0	2.8075281002507912	
i 1	483.73514965986396	22.725	61	205	5	18	8	6	0	1	6	0	0	0.04872182508915611	
i 1	483.73675510204083	22.725	66	703	5	15	1	9	0	1	9	0	0	1.6318777986229804	
i 1	483.7383605442177	22.725	66	1089	4	19	13	9	0	1	9	0	0	0.04872182508915611	
i 1	483.74157142857143	0.505	74	1089	6	1	8	16	0	1	16	0	0	2.0	
i 1	483.74397959183676	0.2525	72	205	6	5	15	0	0	0	0	0	0	2.0	
i 1	483.74478231292517	22.725	61	205	5	16	14	6	0	1	6	0	0	2.8075281002507912	
i 1	483.74478231292517	0.505	77	703	4	4	1	16	0	2	16	0	0	3.8488226289245264	
i 1	483.74638775510203	2.2725	61	1089	3	14	10	6	0	2	6	0	0	3.017595686385947	
i 1	483.74959863945577	15.9075	66	703	6	17	6	9	0	1	9	0	0	0.04872182508915611	
i 1	483.75040136054423	2.2725	61	703	5	13	12	9	0	2	9	0	0	0.7673465283066598	
i 1	483.75120408163264	3.0300000000000002	74	703	6	1	4	16	0	1	16	0	0	2.0	
i 1	483.75120408163264	0.2525	69	1089	5	5	10	1	0	-1	1	0	0	2.0	
i 1	483.7528095238095	22.725	61	1089	5	13	15	9	0	2	9	0	0	0.45622749699517	
i 1	483.75361224489797	1.5150000000000001	69	1089	2	5	13	1	0	-1	1	0	0	2.0	
i 1	483.75441496598637	22.725	61	1089	5	14	13	9	0	1	9	0	0	3.983178401878601	
i 1	483.75602040816324	6.565	73	1089	2	24	8	17	0	2	17	0	0	8.0	
i 1	483.7568231292517	3.0300000000000002	74	1089	4	24	15	17	0	1	17	0	0	3.0	
i 1	483.7568231292517	2.2725	61	1089	6	17	14	6	0	2	6	0	0	0.04872182508915611	
i 1	483.7568231292517	1.5150000000000001	69	1089	6	5	14	1	0	0	1	0	0	2.0	
i 1	483.75762585034016	22.725	61	1089	5	14	8	6	0	2	6	0	0	3.017595686385947	
i 1	483.75842857142857	22.725	61	703	5	15	7	9	0	1	9	0	0	1.6318777986229804	
i 1	483.75842857142857	1.5150000000000001	73	1089	2	20	9	16	0	2	16	0	0	4.000000000000001	
i 1	483.75842857142857	0.2525	73	205	4	24	6	16	0	1	16	0	0	8.0	
i 1	483.7608367346939	0.2525	77	205	7	1	3	17	0	1	17	0	0	2.0	
i 1	483.7608367346939	0.2525	76	1089	2	24	3	16	0	1	16	0	0	8.0	
i 1	483.76404761904763	2.2725	77	703	5	3	2	16	0	1	16	0	0	3.8488226289245264	
i 1	483.76404761904763	9.09	61	703	5	7	2	9	0	1	9	0	0	2.267512633692852	
i 1	483.7656530612245	2.2725	74	1089	2	4	16	16	0	2	16	0	0	3.8488226289245264	
i 1	483.7656530612245	9.09	61	1089	6	17	3	9	0	1	9	0	0	0.04872182508915611	
i 1	483.7656530612245	22.725	61	205	5	18	4	6	0	1	6	0	0	0.04872182508915611	
i 1	483.76725850340137	22.725	61	1089	4	19	13	9	0	2	9	0	0	0.04872182508915611	
i 1	483.76725850340137	0.2525	76	1089	2	20	7	16	0	1	16	0	0	4.000000000000001	
i 1	483.76806122448977	2.2725	73	205	4	20	10	17	0	1	17	0	0	4.000000000000001	
i 1	483.76886394557823	22.725	66	703	6	17	6	6	0	2	6	0	0	0.04872182508915611	
i 1	483.7696666666667	1.5150000000000001	76	205	4	20	6	17	0	2	17	0	0	4.000000000000001	
i 1	484.00602040816324	1.2625	69	703	6	5	8	1	0	-1	1	0	0	2.0	
i 1	484.01244217687076	0.505	74	1089	2	3	5	16	0	2	16	0	0	3.8488226289245264	
i 1	484.2343469387755	1.01	69	1089	3	5	15	1	0	-1	1	0	0	2.0	
i 1	484.26485034013604	0.2525	77	1089	6	1	16	17	0	1	17	0	0	2.0	
i 1	484.4835442176871	0.2525	74	1089	5	2	8	17	0	2	17	0	0	3.8488226289245264	
i 1	484.4835442176871	0.7575000000000001	76	205	4	20	15	17	0	1	17	0	0	4.000000000000001	
i 1	484.48595238095237	4.7975	77	205	7	1	7	16	0	1	16	0	0	2.0	
i 1	484.48755782312924	0.2525	74	205	6	9	2	16	0	1	16	0	0	2.8488226289245264	
i 1	484.49638775510203	1.5150000000000001	73	205	4	24	14	16	0	1	16	0	0	8.0	
i 1	484.5020068027211	1.5150000000000001	69	205	4	5	2	0	0	0	0	0	0	2.0	
i 1	484.50521768707483	2.2725	69	1089	5	5	14	1	0	-1	1	0	0	2.0	
i 1	484.5068231292517	4.545	77	1089	6	1	10	17	0	2	17	0	0	2.0	
i 1	484.74076870748297	0.2525	74	1089	2	3	13	16	0	2	16	0	0	3.8488226289245264	
i 1	484.76244217687076	0.2525	77	205	6	9	14	16	0	2	16	0	0	2.8488226289245264	
i 1	484.99076870748297	1.01	74	1089	5	2	12	17	0	2	17	0	0	3.8488226289245264	
i 1	485.0020068027211	2.2725	74	205	6	9	6	16	0	1	16	0	0	2.8488226289245264	
i 1	485.0068231292517	1.7675	76	1089	2	20	4	16	0	1	16	0	0	4.000000000000001	
i 1	485.23274149659863	0.2525	73	1089	4	20	11	17	0	2	17	0	0	4.000000000000001	
i 1	485.2383605442177	0.2525	72	205	6	5	9	0	0	0	0	0	0	2.0	
i 1	485.24076870748297	0.2525	76	703	4	20	14	16	0	2	16	0	0	4.000000000000001	
i 1	485.2471904761905	0.2525	76	1089	4	20	13	17	0	2	17	0	0	4.000000000000001	
i 1	485.25602040816324	0.2525	69	703	6	5	7	0	0	0	0	0	0	2.0	
i 1	485.4883605442177	0.505	69	1089	6	5	15	1	0	0	1	0	0	2.0	
i 1	485.49237414965984	0.505	76	205	4	20	3	16	0	2	16	0	0	4.000000000000001	
i 1	485.49397959183676	0.505	76	1089	2	20	11	16	0	2	16	0	0	4.000000000000001	
i 1	485.50441496598637	0.505	76	1089	2	24	5	17	0	1	17	0	0	8.0	
i 1	485.50521768707483	0.2525	69	703	6	5	5	1	0	-1	1	0	0	2.0	
i 1	485.50762585034016	0.505	76	205	4	20	16	16	0	1	16	0	0	4.000000000000001	
i 1	485.76485034013604	0.2525	69	1089	3	5	4	1	0	-1	1	0	0	2.0	
i 1	485.98274149659863	6.8175	61	703	3	13	16	9	0	2	9	0	0	0.7673465283066598	
i 1	485.9843469387755	0.2525	74	1089	5	2	7	17	0	1	17	0	0	3.8488226289245264	
i 1	485.99157142857143	0.2525	73	703	4	24	7	17	0	2	17	0	0	8.0	
i 1	485.9979931972789	0.505	73	703	4	20	11	16	0	1	16	0	0	4.000000000000001	
i 1	485.9979931972789	20.4525	61	1089	5	14	15	6	0	2	6	0	0	3.017595686385947	
i 1	486.00120408163264	1.2625	74	1089	6	2	10	17	0	2	17	0	0	3.8488226289245264	
i 1	486.0028095238095	2.02	72	205	6	5	9	0	0	0	0	0	0	2.0	
i 1	486.00842857142857	1.01	69	205	6	5	8	0	0	0	0	0	0	2.0	
i 1	486.0116394557823	2.2725	69	703	6	5	8	0	0	0	0	0	0	2.0	
i 1	486.01725850340137	20.4525	61	1089	6	17	13	6	0	2	6	0	0	0.04872182508915611	
i 1	486.01886394557823	20.4525	61	1089	3	12	12	9	0	1	9	0	0	2.8075281002507912	
i 1	486.24157142857143	0.2525	76	1089	4	20	5	17	0	2	17	0	0	4.000000000000001	
i 1	486.24237414965984	2.02	73	205	4	20	3	17	0	1	17	0	0	4.000000000000001	
i 1	486.2608367346939	0.2525	74	1089	4	3	13	16	0	2	16	0	0	3.8488226289245264	
i 1	486.26485034013604	0.505	77	703	4	4	7	16	0	2	16	0	0	3.8488226289245264	
i 1	486.48996598639457	2.2725	73	1089	2	20	13	16	0	1	16	0	0	4.000000000000001	
i 1	486.5164557823129	1.7675	73	205	4	20	15	17	0	2	17	0	0	4.000000000000001	
i 1	486.7335442176871	0.7575000000000001	74	1089	5	2	3	17	0	1	17	0	0	3.8488226289245264	
i 1	486.73675510204083	1.01	74	1089	4	3	10	16	0	2	16	0	0	3.8488226289245264	
i 1	486.7528095238095	0.2525	77	1089	6	1	10	17	0	1	17	0	0	2.0	
i 1	486.75762585034016	0.2525	77	205	7	1	6	17	0	1	17	0	0	2.0	
i 1	486.99959863945577	0.2525	74	1089	5	1	14	16	0	1	16	0	0	2.0	
i 1	487.00762585034016	0.2525	69	1089	2	5	11	1	0	-1	1	0	0	2.0	
i 1	487.00842857142857	5.05	74	1089	2	4	1	16	0	2	16	0	0	3.8488226289245264	
i 1	487.01485034013604	0.2525	77	703	4	24	4	16	0	2	16	0	0	3.0	
i 1	487.01485034013604	1.7675	77	703	5	3	8	16	0	1	16	0	0	3.8488226289245264	
i 1	487.2391632653061	2.7775	69	1089	5	5	1	1	0	-1	1	0	0	2.0	
i 1	487.2568231292517	2.7775	69	205	6	5	4	0	0	0	0	0	0	2.0	
i 1	487.26324489795917	0.2525	77	1089	6	1	9	17	0	1	17	0	0	2.0	
i 1	487.7528095238095	0.2525	74	1089	5	2	8	17	0	1	17	0	0	3.8488226289245264	
i 1	487.75762585034016	1.01	76	205	4	20	9	17	0	2	17	0	0	4.000000000000001	
i 1	487.76003401360543	1.7675	73	205	4	24	1	16	0	1	16	0	0	8.0	
i 1	487.7656530612245	0.2525	77	205	7	1	3	17	0	1	17	0	0	2.0	
i 1	487.99638775510203	1.5150000000000001	77	205	6	9	9	16	0	2	16	0	0	2.8488226289245264	
i 1	487.99959863945577	0.2525	74	703	6	1	15	16	0	1	16	0	0	2.0	
i 1	488.00441496598637	1.5150000000000001	77	703	4	4	10	16	0	2	16	0	0	3.8488226289245264	
i 1	488.01806122448977	0.2525	69	1089	3	5	8	1	0	-1	1	0	0	2.0	
i 1	488.25521768707483	2.7775	77	205	7	1	5	17	0	1	17	0	0	2.0	
i 1	488.2608367346939	2.525	77	703	4	24	13	16	0	2	16	0	0	3.0	
i 1	488.2616394557823	0.505	69	1089	5	5	2	1	0	0	1	0	0	2.0	
i 1	488.2616394557823	0.2525	69	703	6	5	5	1	0	-1	1	0	0	2.0	
i 1	488.50120408163264	0.7575000000000001	69	703	6	5	9	0	0	0	0	0	0	2.0	
i 1	488.5108367346939	1.01	73	205	4	20	13	17	0	1	17	0	0	4.000000000000001	
i 1	488.51244217687076	0.2525	73	205	4	20	2	17	0	2	17	0	0	4.000000000000001	
i 1	488.7431768707483	0.2525	73	703	4	20	9	17	0	1	17	0	0	4.000000000000001	
i 1	488.76404761904763	0.2525	76	1089	4	20	2	17	0	2	17	0	0	4.000000000000001	
i 1	488.7656530612245	0.2525	76	1089	4	20	6	17	0	1	17	0	0	4.000000000000001	
i 1	488.98595238095237	3.0300000000000002	77	703	5	3	6	16	0	1	16	0	0	3.8488226289245264	
i 1	489.00120408163264	0.7575000000000001	73	1089	2	20	4	16	0	2	16	0	0	4.000000000000001	
i 1	489.00602040816324	0.505	76	205	4	20	1	17	0	2	17	0	0	4.000000000000001	
i 1	489.01404761904763	3.535	69	1089	2	5	2	1	0	-1	1	0	0	2.0	
i 1	489.01404761904763	0.7575000000000001	76	205	4	20	3	17	0	1	17	0	0	4.000000000000001	
i 1	489.2479931972789	3.2825	69	1089	5	5	15	1	0	0	1	0	0	2.0	
i 1	489.26886394557823	0.2525	74	703	6	1	6	16	0	1	16	0	0	2.0	
i 1	489.48514965986396	0.505	77	205	7	1	9	16	0	1	16	0	0	2.0	
i 1	489.48755782312924	3.0300000000000002	76	1089	2	20	6	16	0	1	16	0	0	4.000000000000001	
i 1	489.4971904761905	0.505	74	1089	6	2	1	17	0	2	17	0	0	3.8488226289245264	
i 1	489.74076870748297	0.2525	73	703	4	24	6	17	0	1	17	0	0	8.0	
i 1	489.7431768707483	1.2625	73	205	4	20	11	17	0	1	17	0	0	4.000000000000001	
i 1	489.7608367346939	0.2525	73	703	4	20	12	17	0	2	17	0	0	4.000000000000001	
i 1	489.7664557823129	0.2525	73	1089	4	20	8	16	0	1	16	0	0	4.000000000000001	
i 1	489.9835442176871	0.7575000000000001	73	205	4	20	10	17	0	1	17	0	0	4.000000000000001	
i 1	489.9891632653061	0.2525	74	1089	4	3	6	16	0	2	16	0	0	3.8488226289245264	
i 1	489.99237414965984	0.2525	69	703	6	5	2	0	0	0	0	0	0	2.0	
i 1	489.9971904761905	0.7575000000000001	76	1089	2	24	8	16	0	2	16	0	0	8.0	
i 1	490.0028095238095	3.2825	74	703	6	1	15	16	0	1	16	0	0	2.0	
i 1	490.01003401360543	0.2525	73	1089	2	20	11	16	0	2	16	0	0	4.000000000000001	
i 1	490.01806122448977	2.7775	74	1089	4	24	6	17	0	1	17	0	0	3.0	
i 1	490.23595238095237	0.2525	77	703	4	4	10	16	0	2	16	0	0	3.8488226289245264	
i 1	490.25602040816324	0.7575000000000001	69	205	6	5	4	0	0	0	0	0	0	2.0	
i 1	490.26244217687076	0.7575000000000001	69	1089	5	5	9	1	0	-1	1	0	0	2.0	
i 1	490.50842857142857	0.2525	73	1089	2	20	13	16	0	2	16	0	0	4.000000000000001	
i 1	490.5116394557823	3.0300000000000002	73	205	4	24	6	16	0	1	16	0	0	8.0	
i 1	490.7431768707483	0.505	73	703	4	24	2	17	0	2	17	0	0	8.0	
i 1	490.7479931972789	0.505	73	703	4	20	2	16	0	2	16	0	0	4.000000000000001	
i 1	490.76806122448977	0.2525	76	1089	4	20	4	16	0	1	16	0	0	4.000000000000001	
i 1	490.9891632653061	0.2525	74	205	6	9	16	16	0	1	16	0	0	2.8488226289245264	
i 1	490.99879591836736	1.2625	77	1089	6	1	5	17	0	2	17	0	0	2.0	
i 1	491.00842857142857	3.2825	73	1089	2	24	10	17	0	2	17	0	0	8.0	
i 1	491.01485034013604	0.505	69	703	6	5	3	0	0	0	0	0	0	2.0	
i 1	491.01725850340137	1.2625	77	205	7	1	5	16	0	1	16	0	0	2.0	
i 1	491.24959863945577	0.2525	77	703	4	4	14	16	0	2	16	0	0	3.8488226289245264	
i 1	491.25923129251703	1.2625	76	1089	2	24	14	17	0	1	17	0	0	8.0	
i 1	491.26404761904763	2.2725	76	1089	2	20	2	16	0	2	16	0	0	4.000000000000001	
i 1	491.49157142857143	0.2525	69	703	6	5	12	1	0	-1	1	0	0	2.0	
i 1	491.49638775510203	2.02	73	205	4	20	8	16	0	1	16	0	0	4.000000000000001	
i 1	491.50521768707483	2.2725	74	205	6	9	8	16	0	1	16	0	0	2.8488226289245264	
i 1	491.50762585034016	2.02	74	1089	6	2	11	17	0	2	17	0	0	3.8488226289245264	
i 1	491.75923129251703	0.2525	69	703	6	5	8	0	0	0	0	0	0	2.0	
i 1	491.98675510204083	1.5150000000000001	69	1089	3	5	4	1	0	-1	1	0	0	2.0	
i 1	492.00441496598637	0.7575000000000001	69	703	6	5	4	1	0	-1	1	0	0	2.0	
i 1	492.01806122448977	0.2525	74	1089	4	3	6	16	0	2	16	0	0	3.8488226289245264	
i 1	492.25602040816324	0.505	77	703	4	4	6	16	0	2	16	0	0	3.8488226289245264	
i 1	492.2568231292517	0.2525	77	205	7	1	3	17	0	1	17	0	0	2.0	
i 1	492.49638775510203	1.5150000000000001	77	205	7	1	16	16	0	1	16	0	0	2.0	
i 1	492.5068231292517	0.2525	69	703	6	5	1	0	0	0	0	0	0	2.0	
i 1	492.5196666666667	1.7675	77	1089	6	1	11	17	0	2	17	0	0	2.0	
i 1	492.73113605442177	1.5150000000000001	74	1089	4	3	15	16	0	2	16	0	0	3.8488226289245264	
i 1	492.7335442176871	13.635	61	1089	6	17	4	9	0	1	9	0	0	0.04872182508915611	
i 1	492.7520068027211	6.8175	61	703	4	7	12	9	0	1	9	0	0	2.267512633692852	
i 1	492.7528095238095	0.7575000000000001	69	703	5	5	15	1	0	-1	1	0	0	2.0	
i 1	492.75602040816324	0.2525	74	1089	4	24	4	17	0	1	17	0	0	3.0	
i 1	492.76244217687076	13.635	61	703	5	13	11	9	0	2	9	0	0	0.7673465283066598	
i 1	492.76806122448977	0.2525	72	205	6	5	1	0	0	0	0	0	0	2.0	
i 1	492.76886394557823	13.635	61	1089	3	12	5	9	0	1	9	0	0	2.8075281002507912	
i 1	492.98996598639457	1.2625	74	1089	6	2	12	17	0	1	17	0	0	3.8488226289245264	
i 1	492.9931768707483	1.01	76	1089	2	20	14	16	0	1	16	0	0	4.000000000000001	
i 1	493.00602040816324	1.01	69	205	6	5	9	0	0	0	0	0	0	2.0	
i 1	493.00762585034016	0.7575000000000001	76	1089	2	24	15	17	0	1	17	0	0	8.0	
i 1	493.00842857142857	2.2725	73	205	4	20	1	17	0	1	17	0	0	4.000000000000001	
i 1	493.00923129251703	1.01	69	1089	5	5	12	1	0	-1	1	0	0	2.0	
i 1	493.01806122448977	0.7575000000000001	76	205	4	20	16	16	0	2	16	0	0	4.000000000000001	
i 1	493.23514965986396	0.2525	74	1089	5	1	11	16	0	1	16	0	0	2.0	
i 1	493.4891632653061	2.02	72	205	6	5	3	0	0	0	0	0	0	2.0	
i 1	493.49638775510203	2.02	74	703	6	1	7	16	0	1	16	0	0	2.0	
i 1	493.4971904761905	2.2725	74	1089	4	24	13	17	0	1	17	0	0	3.0	
i 1	493.5156530612245	2.02	69	703	6	5	5	0	0	0	0	0	0	2.0	
i 1	493.73113605442177	5.05	74	1089	4	4	15	16	0	2	16	0	0	3.8488226289245264	
i 1	493.74157142857143	0.2525	73	703	4	24	7	17	0	1	17	0	0	8.0	
i 1	493.74959863945577	1.5150000000000001	77	703	5	3	14	16	0	1	16	0	0	3.8488226289245264	
i 1	493.75521768707483	0.2525	76	1089	4	20	10	16	0	1	16	0	0	4.000000000000001	
i 1	493.7568231292517	2.7775	73	205	4	24	15	16	0	1	16	0	0	8.0	
i 1	493.76003401360543	0.2525	73	1089	4	20	2	17	0	1	17	0	0	4.000000000000001	
i 1	493.98595238095237	0.2525	69	1089	5	5	13	1	0	0	1	0	0	2.0	
i 1	494.00040136054423	2.2725	76	205	4	20	2	16	0	1	16	0	0	4.000000000000001	
i 1	494.0196666666667	1.2625	73	205	4	20	6	17	0	2	17	0	0	4.000000000000001	
i 1	494.2383605442177	0.2525	77	703	4	4	5	16	0	2	16	0	0	3.8488226289245264	
i 1	494.24157142857143	0.505	74	1089	5	1	13	16	0	1	16	0	0	2.0	
i 1	494.25120408163264	0.2525	69	1089	4	5	8	1	0	-1	1	0	0	2.0	
i 1	494.4971904761905	0.2525	74	1089	4	3	9	16	0	2	16	0	0	3.8488226289245264	
i 1	494.73193877551023	3.535	77	1089	6	1	15	17	0	2	17	0	0	2.0	
i 1	494.73274149659863	1.2625	77	205	6	9	14	16	0	2	16	0	0	2.8488226289245264	
i 1	494.75040136054423	1.2625	77	703	4	4	3	16	0	2	16	0	0	3.8488226289245264	
i 1	494.75040136054423	1.5150000000000001	76	1089	2	20	13	17	0	1	17	0	0	4.000000000000001	
i 1	494.75120408163264	3.2825	73	1089	2	24	5	17	0	2	17	0	0	8.0	
i 1	494.76244217687076	0.2525	69	1089	5	5	10	1	0	0	1	0	0	2.0	
i 1	494.99237414965984	2.2725	69	1089	5	5	11	1	0	-1	1	0	0	2.0	
i 1	494.9931768707483	3.2825	77	205	7	1	11	16	0	1	16	0	0	2.0	
i 1	495.00120408163264	1.7675	69	205	6	5	16	0	0	0	0	0	0	2.0	
i 1	495.24959863945577	1.5150000000000001	76	1089	2	20	7	16	0	1	16	0	0	4.000000000000001	
i 1	495.26725850340137	1.01	73	1089	2	24	5	17	0	1	17	0	0	8.0	
i 1	495.48755782312924	2.7775	77	703	5	3	11	16	0	1	16	0	0	3.8488226289245264	
i 1	495.51324489795917	0.505	69	703	5	5	4	1	0	-1	1	0	0	2.0	
i 1	495.7391632653061	0.2525	77	205	7	1	14	17	0	1	17	0	0	2.0	
i 1	495.98193877551023	3.0300000000000002	73	205	4	20	5	17	0	1	17	0	0	4.000000000000001	
i 1	495.99879591836736	0.505	74	1089	6	2	3	17	0	2	17	0	0	3.8488226289245264	
i 1	496.00762585034016	0.2525	74	1089	5	1	8	16	0	1	16	0	0	2.0	
i 1	496.01404761904763	0.2525	69	703	6	5	6	0	0	0	0	0	0	2.0	
i 1	496.2391632653061	0.2525	76	1089	4	20	3	17	0	2	17	0	0	4.000000000000001	
i 1	496.24076870748297	0.2525	76	703	4	20	4	16	0	2	16	0	0	4.000000000000001	
i 1	496.24397959183676	0.2525	73	1089	4	20	4	16	0	1	16	0	0	4.000000000000001	
i 1	496.24959863945577	3.535	69	1089	5	5	13	1	0	0	1	0	0	2.0	
i 1	496.2656530612245	2.02	69	1089	4	5	16	1	0	-1	1	0	0	2.0	
i 1	496.48675510204083	0.2525	77	205	6	9	11	16	0	2	16	0	0	2.8488226289245264	
i 1	496.49237414965984	0.2525	73	205	4	20	14	17	0	1	17	0	0	4.000000000000001	
i 1	496.49959863945577	2.525	73	205	4	20	9	17	0	1	17	0	0	4.000000000000001	
i 1	496.51886394557823	1.5150000000000001	76	1089	2	20	9	16	0	1	16	0	0	4.000000000000001	
i 1	496.7471904761905	0.2525	74	1089	6	2	11	17	0	1	17	0	0	3.8488226289245264	
i 1	496.76003401360543	0.2525	74	703	6	1	3	16	0	1	16	0	0	2.0	
i 1	497.0068231292517	0.505	74	1089	5	1	10	16	0	1	16	0	0	2.0	
i 1	497.2471904761905	0.2525	69	1089	3	5	8	1	0	-1	1	0	0	2.0	
i 1	497.48675510204083	0.2525	74	1089	4	24	15	17	0	1	17	0	0	3.0	
i 1	497.48996598639457	3.0300000000000002	73	205	4	24	6	16	0	1	16	0	0	8.0	
i 1	497.51244217687076	0.2525	69	703	5	5	11	1	0	-1	1	0	0	2.0	
i 1	497.51324489795917	0.2525	74	1089	4	3	11	16	0	2	16	0	0	3.8488226289245264	
i 1	497.51485034013604	2.2725	73	205	4	20	6	17	0	1	17	0	0	4.000000000000001	
i 1	497.7335442176871	1.5150000000000001	69	205	6	5	8	0	0	0	0	0	0	2.0	
i 1	497.73595238095237	1.5150000000000001	69	1089	5	5	1	1	0	-1	1	0	0	2.0	
i 1	497.74157142857143	2.2725	74	1089	6	2	9	17	0	2	17	0	0	3.8488226289245264	
i 1	497.75923129251703	2.2725	74	205	6	9	16	16	0	1	16	0	0	2.8488226289245264	
i 1	497.7608367346939	1.01	77	703	4	24	8	16	0	2	16	0	0	3.0	
i 1	497.7616394557823	1.01	77	205	7	1	6	17	0	1	17	0	0	2.0	
i 1	498.2343469387755	1.2625	74	703	6	1	1	16	0	1	16	0	0	2.0	
i 1	498.24879591836736	1.2625	74	1089	4	24	16	17	0	1	17	0	0	3.0	
i 1	498.50923129251703	2.7775	73	1089	2	24	4	17	0	2	17	0	0	8.0	
i 1	498.5156530612245	1.01	76	1089	2	20	1	16	0	1	16	0	0	4.000000000000001	
i 1	498.7303333333333	0.505	77	703	5	3	14	16	0	1	16	0	0	3.8488226289245264	
i 1	498.74237414965984	1.7675	77	205	7	1	16	16	0	1	16	0	0	2.0	
i 1	498.76725850340137	1.01	69	1089	4	5	13	1	0	-1	1	0	0	2.0	
i 1	498.98274149659863	0.7575000000000001	73	1089	2	24	6	16	0	2	16	0	0	8.0	
i 1	498.98675510204083	1.01	76	1089	2	20	9	16	0	1	16	0	0	4.000000000000001	
i 1	499.00842857142857	0.505	77	1089	6	1	13	17	0	2	17	0	0	2.0	
i 1	499.24478231292517	0.2525	77	703	4	4	15	16	0	2	16	0	0	3.8488226289245264	
i 1	499.24558503401363	2.02	69	703	5	5	10	1	0	-1	1	0	0	2.0	
i 1	499.26725850340137	0.2525	69	1089	3	5	10	1	0	-1	1	0	0	2.0	
i 1	499.4843469387755	0.2525	77	205	7	1	9	17	0	1	17	0	0	2.0	
i 1	499.4891632653061	0.2525	73	205	4	20	13	17	0	1	17	0	0	4.000000000000001	
i 1	499.49076870748297	1.7675	69	1089	4	5	9	1	0	-1	1	0	0	2.0	
i 1	499.49397959183676	6.8175	61	703	5	7	7	9	0	1	9	0	0	2.267512633692852	
i 1	499.49558503401363	1.2625	74	1089	4	3	5	16	0	2	16	0	0	3.8488226289245264	
i 1	499.5068231292517	1.01	77	1089	6	1	15	17	0	2	17	0	0	2.0	
i 1	499.50923129251703	1.2625	74	1089	6	2	6	17	0	1	17	0	0	3.8488226289245264	
i 1	499.5156530612245	6.8175	66	703	6	17	12	9	0	1	9	0	0	0.04872182508915611	
i 1	499.74076870748297	2.2725	74	703	6	1	5	16	0	1	16	0	0	2.0	
i 1	499.74237414965984	0.505	76	703	4	24	16	17	0	2	17	0	0	8.0	
i 1	499.75521768707483	0.2525	73	1089	4	20	6	17	0	2	17	0	0	4.000000000000001	
i 1	499.76324489795917	0.2525	69	205	6	5	12	0	0	0	0	0	0	2.0	
i 1	499.76806122448977	0.505	76	1089	4	20	14	17	0	2	17	0	0	4.000000000000001	
i 1	499.9891632653061	2.2725	74	1089	4	24	5	17	0	1	17	0	0	3.0	
i 1	499.99558503401363	1.2625	73	205	4	20	5	17	0	1	17	0	0	4.000000000000001	
i 1	500.00120408163264	0.2525	72	205	6	5	10	0	0	0	0	0	0	2.0	
i 1	500.01886394557823	0.2525	77	703	4	4	7	16	0	2	16	0	0	3.8488226289245264	
i 1	500.2343469387755	4.7975	77	703	5	3	1	16	0	1	16	0	0	3.8488226289245264	
i 1	500.24157142857143	4.545	74	1089	4	4	5	16	0	2	16	0	0	3.8488226289245264	
i 1	500.24478231292517	0.505	73	205	4	20	4	17	0	1	17	0	0	4.000000000000001	
i 1	500.2528095238095	0.2525	73	1089	2	24	13	17	0	1	17	0	0	8.0	
i 1	500.49397959183676	0.2525	77	205	7	1	6	17	0	1	17	0	0	2.0	
i 1	500.50521768707483	0.2525	69	1089	5	5	7	1	0	0	1	0	0	2.0	
i 1	500.7335442176871	0.2525	77	703	4	24	7	16	0	2	16	0	0	3.0	
i 1	500.7343469387755	5.555	69	1089	5	5	11	1	0	-1	1	0	0	2.0	
i 1	500.7391632653061	0.2525	76	1089	4	20	16	17	0	2	17	0	0	4.000000000000001	
i 1	500.74638775510203	0.2525	76	703	4	24	2	17	0	1	17	0	0	8.0	
i 1	500.75602040816324	1.5150000000000001	76	1089	2	20	16	16	0	1	16	0	0	4.000000000000001	
i 1	500.7608367346939	1.01	77	703	4	4	7	16	0	2	16	0	0	3.8488226289245264	
i 1	500.76485034013604	1.5150000000000001	73	205	4	24	1	16	0	1	16	0	0	8.0	
i 1	500.7664557823129	0.2525	76	1089	4	20	6	17	0	1	17	0	0	4.000000000000001	
i 1	500.76806122448977	5.555	69	205	6	5	15	0	0	0	0	0	0	2.0	
i 1	500.98274149659863	1.2625	76	1089	2	24	8	16	0	2	16	0	0	8.0	
i 1	500.98675510204083	1.01	77	205	5	9	14	16	0	2	16	0	0	2.8488226289245264	
i 1	500.99879591836736	0.2525	73	205	4	20	15	16	0	2	16	0	0	4.000000000000001	
i 1	501.01886394557823	1.2625	76	205	4	20	16	17	0	2	17	0	0	4.000000000000001	
i 1	501.24638775510203	0.505	69	1089	4	5	4	1	0	-1	1	0	0	2.0	
i 1	501.24879591836736	0.2525	77	205	7	1	8	17	0	1	17	0	0	2.0	
i 1	501.48113605442177	2.2725	77	1089	6	1	1	17	0	2	17	0	0	2.0	
i 1	501.50120408163264	2.02	77	205	7	1	10	16	0	1	16	0	0	2.0	
i 1	501.73193877551023	2.2725	73	205	4	20	13	17	0	1	17	0	0	4.000000000000001	
i 1	501.73274149659863	0.7575000000000001	69	703	5	5	14	0	0	0	0	0	0	2.0	
i 1	501.74076870748297	1.2625	73	1089	2	24	5	17	0	2	17	0	0	8.0	
i 1	501.7528095238095	2.02	73	205	4	20	15	16	0	2	16	0	0	4.000000000000001	
i 1	501.7528095238095	1.2625	73	1089	2	20	12	16	0	2	16	0	0	4.000000000000001	
i 1	501.7608367346939	0.7575000000000001	72	205	6	5	1	0	0	0	0	0	0	2.0	
i 1	502.00842857142857	0.2525	74	1089	6	2	14	17	0	1	17	0	0	3.8488226289245264	
i 1	502.2335442176871	0.505	77	703	4	24	1	16	0	2	16	0	0	3.0	
i 1	502.2343469387755	0.2525	74	1089	4	3	1	16	0	2	16	0	0	3.8488226289245264	
i 1	502.4891632653061	1.01	76	1089	2	24	3	16	0	2	16	0	0	8.0	
i 1	502.4931768707483	2.7775	76	1089	2	20	13	16	0	1	16	0	0	4.000000000000001	
i 1	502.51806122448977	0.2525	69	1089	4	5	11	1	0	-1	1	0	0	2.0	
i 1	502.74558503401363	0.2525	69	703	5	5	12	1	0	-1	1	0	0	2.0	
i 1	502.76886394557823	2.02	74	703	6	1	6	16	0	1	16	0	0	2.0	
i 1	503.0164557823129	1.7675	74	1089	4	24	3	17	0	1	17	0	0	3.0	
i 1	503.49237414965984	10.352500000000001	73	1089	2	24	4	17	0	2	17	0	0	8.0	
i 1	503.49397959183676	0.2525	73	1089	2	20	8	16	0	2	16	0	0	4.000000000000001	
i 1	503.7391632653061	0.2525	77	205	5	9	16	16	0	2	16	0	0	2.8488226289245264	
i 1	503.74638775510203	0.2525	69	1089	5	5	6	1	0	0	1	0	0	2.0	
i 1	503.7479931972789	0.2525	73	1089	4	20	8	17	0	2	17	0	0	4.000000000000001	
i 1	503.75923129251703	0.2525	74	1089	5	1	16	16	0	1	16	0	0	2.0	
i 1	503.7664557823129	0.2525	73	703	4	20	8	16	0	2	16	0	0	4.000000000000001	
i 1	503.9835442176871	0.2525	77	1089	6	1	4	17	0	1	17	0	0	2.0	
i 1	503.99959863945577	0.505	73	1089	2	20	7	17	0	1	17	0	0	4.000000000000001	
i 1	504.00923129251703	2.2725	74	205	6	9	1	16	0	1	16	0	0	2.8488226289245264	
i 1	504.0196666666667	0.2525	76	205	4	20	8	17	0	1	17	0	0	4.000000000000001	
i 1	504.2343469387755	2.02	74	1089	6	2	13	17	0	2	17	0	0	3.8488226289245264	
i 1	504.24397959183676	0.2525	69	703	5	5	14	1	0	-1	1	0	0	2.0	
i 1	504.24638775510203	1.7675	77	1089	6	1	14	17	0	2	17	0	0	2.0	
i 1	504.2656530612245	2.02	77	205	7	1	12	16	0	1	16	0	0	2.0	
i 1	504.48514965986396	0.2525	76	703	4	20	10	17	0	1	17	0	0	4.000000000000001	
i 1	504.4883605442177	2.525	73	205	4	20	7	17	0	1	17	0	0	4.000000000000001	
i 1	504.49397959183676	1.01	69	1089	5	5	8	1	0	0	1	0	0	2.0	
i 1	504.49879591836736	0.2525	73	1089	4	20	11	16	0	2	16	0	0	4.000000000000001	
i 1	504.50923129251703	1.2625	69	1089	4	5	5	1	0	-1	1	0	0	2.0	
i 1	504.73274149659863	2.02	73	205	4	20	12	16	0	1	16	0	0	4.000000000000001	
i 1	504.75602040816324	0.2525	77	1089	6	1	3	17	0	1	17	0	0	2.0	
i 1	504.76485034013604	2.02	73	1089	2	20	14	16	0	2	16	0	0	4.000000000000001	
i 1	504.98996598639457	0.2525	77	703	4	24	1	16	0	2	16	0	0	3.0	
i 1	504.99237414965984	0.505	74	1089	4	4	3	16	0	2	16	0	0	3.8488226289245264	
i 1	505.2343469387755	0.2525	77	703	5	3	13	16	0	1	16	0	0	3.8488226289245264	
i 1	505.2391632653061	0.2525	74	1089	5	1	2	16	0	1	16	0	0	2.0	
i 1	505.2616394557823	0.2525	74	703	6	1	3	16	0	1	16	0	0	2.0	
i 1	505.48595238095237	0.7575000000000001	74	1089	6	2	6	17	0	1	17	0	0	3.8488226289245264	
i 1	505.50040136054423	1.7675	77	205	7	1	5	17	0	1	17	0	0	2.0	
i 1	505.50361224489797	1.5150000000000001	77	703	4	24	12	16	0	2	16	0	0	3.0	
i 1	505.73595238095237	0.505	77	703	5	3	16	16	0	1	16	0	0	3.8488226289245264	
i 1	505.73595238095237	0.2525	69	703	5	5	5	1	0	-1	1	0	0	2.0	
i 1	505.73996598639457	0.505	74	1089	4	4	7	16	0	2	16	0	0	3.8488226289245264	
i 1	505.74397959183676	0.505	74	1089	4	3	4	16	0	2	16	0	0	3.8488226289245264	
i 1	506.01324489795917	0.2525	69	1089	5	5	12	1	0	0	1	0	0	2.0	
i 1	506.2343469387755	1.7675	69	1089	4	5	5	1	0	-1	1	0	0	2.5915445024659647	
i 1	506.23595238095237	13.635	66	703	5	15	12	9	0	1	9	0	0	0.7315640146361382	
i 1	506.23595238095237	27.27	66	205	5	16	6	6	0	2	6	0	0	1.9072143162639486	
i 1	506.23595238095237	5.05	77	703	5	3	11	16	0	1	16	0	0	4.889597876681885	
i 1	506.2391632653061	5.05	74	1089	4	4	6	16	0	2	16	0	0	4.889597876681885	
i 1	506.2391632653061	31.5625	61	703	5	7	6	9	0	1	9	0	0	1.9090269580453596	
i 1	506.24076870748297	27.27	61	205	5	26	13	9	0	1	9	0	0	1.721643542311956	
i 1	506.24237414965984	21.715	61	1089	5	25	3	6	0	1	6	0	0	1.721643542311956	
i 1	506.24237414965984	20.4525	66	703	5	25	4	9	0	1	9	0	0	1.721643542311956	
i 1	506.24397959183676	6.8175	61	1089	5	25	12	9	0	1	9	0	0	1.721643542311956	
i 1	506.24638775510203	20.4525	61	1089	5	14	9	6	0	2	6	0	0	2.6591100107384555	
i 1	506.2479931972789	7.575	61	1089	3	12	7	9	0	1	9	0	0	1.9072143162639486	
i 1	506.24879591836736	20.4525	61	703	5	15	13	9	0	1	9	0	0	0.7315640146361382	
i 1	506.25120408163264	34.0875	61	205	5	16	2	6	0	1	6	0	0	1.9072143162639486	
i 1	506.25120408163264	0.2525	74	1089	6	2	15	17	0	1	17	0	0	4.889597876681885	
i 1	506.25361224489797	1.7675	69	1089	5	5	15	1	0	0	1	0	0	2.5915445024659647	
i 1	506.25762585034016	31.5625	61	703	5	13	14	9	0	2	9	0	0	0.40886085265916766	
i 1	506.25842857142857	0.7575000000000001	69	1089	5	5	2	1	0	-1	1	0	0	2.5915445024659647	
i 1	506.2616394557823	0.2525	74	1089	4	3	5	16	0	2	16	0	0	4.889597876681885	
i 1	506.26244217687076	0.2525	74	1089	5	1	6	16	0	1	16	0	0	2.0	
i 1	506.26324489795917	0.2525	77	1089	6	1	7	17	0	1	17	0	0	2.0	
i 1	506.26404761904763	7.575	61	1089	3	12	10	9	0	1	9	0	0	1.9072143162639486	
i 1	506.2656530612245	13.635	66	703	5	25	2	9	0	2	9	0	0	1.721643542311956	
i 1	506.26725850340137	0.7575000000000001	69	205	6	5	11	0	0	0	0	0	0	2.5915445024659647	
i 1	506.26806122448977	21.715	61	1089	5	14	7	6	0	2	6	0	0	2.6591100107384555	
i 1	506.48113605442177	1.7675	76	1089	2	20	15	16	0	1	16	0	0	4.000000000000001	
i 1	506.48514965986396	2.2725	74	1089	4	24	11	17	0	1	17	0	0	3.0	
i 1	506.50521768707483	2.2725	74	703	6	1	7	16	0	1	16	0	0	2.0	
i 1	506.51003401360543	0.2525	77	205	5	9	12	16	0	2	16	0	0	3.889597876681885	
i 1	506.74397959183676	0.2525	70	703	4	20	9	8	0	-1	8	0	0	4.000000000000001	
i 1	506.7528095238095	0.505	74	1089	4	3	8	16	0	2	16	0	0	4.889597876681885	
i 1	506.7608367346939	0.2525	73	1089	4	20	5	2	0	-1	2	0	0	4.000000000000001	
i 1	506.99558503401363	0.2525	70	205	4	20	11	8	0	-2	8	0	0	4.000000000000001	
i 1	506.99879591836736	0.2525	72	205	5	5	2	0	0	0	0	0	0	2.5915445024659647	
i 1	507.0108367346939	0.2525	70	1089	2	20	6	2	0	-2	2	0	0	4.000000000000001	
i 1	507.2335442176871	1.2625	77	205	5	9	2	16	0	2	16	0	0	3.889597876681885	
i 1	507.23675510204083	0.2525	77	703	4	24	1	16	0	2	16	0	0	3.0	
i 1	507.25040136054423	1.2625	77	703	4	4	9	16	0	2	16	0	0	4.889597876681885	
i 1	507.25040136054423	1.01	73	205	4	20	9	17	0	1	17	0	0	4.000000000000001	
i 1	507.25923129251703	1.01	69	703	5	5	9	1	0	-1	1	0	0	2.5915445024659647	
i 1	507.4803333333333	2.525	69	205	6	5	15	0	0	0	0	0	0	2.5915445024659647	
i 1	507.49157142857143	5.3025	69	1089	5	5	10	1	0	-1	1	0	0	2.5915445024659647	
i 1	507.49638775510203	0.7575000000000001	69	1089	4	5	1	1	0	-1	1	0	0	2.5915445024659647	
i 1	507.4971904761905	0.2525	70	1089	2	20	15	2	0	-2	2	0	0	4.000000000000001	
i 1	507.50762585034016	0.2525	77	205	7	1	10	17	0	1	17	0	0	2.0	
i 1	507.74237414965984	0.2525	73	703	4	20	8	2	0	-1	2	0	0	4.000000000000001	
i 1	507.74478231292517	0.2525	74	1089	5	1	1	16	0	1	16	0	0	2.0	
i 1	507.75923129251703	2.525	77	1089	6	1	14	17	0	2	17	0	0	2.0	
i 1	507.7656530612245	0.2525	73	1089	4	20	4	8	0	-1	8	0	0	4.000000000000001	
i 1	508.00521768707483	3.7875	70	1089	2	20	8	2	0	-2	2	0	0	4.000000000000001	
i 1	508.00602040816324	2.2725	77	205	7	1	9	16	0	1	16	0	0	2.0	
i 1	508.00923129251703	0.2525	73	205	4	20	7	8	0	-2	8	0	0	4.000000000000001	
i 1	508.25842857142857	0.2525	69	703	5	5	10	0	0	0	0	0	0	2.5915445024659647	
i 1	508.26886394557823	0.505	73	205	4	24	13	16	0	1	16	0	0	8.0	
i 1	508.48675510204083	0.2525	74	1089	6	2	12	17	0	1	17	0	0	4.889597876681885	
i 1	508.4891632653061	0.505	69	1089	5	5	11	1	0	0	1	0	0	2.5915445024659647	
i 1	508.51003401360543	0.2525	69	703	5	5	4	1	0	-1	1	0	0	2.5915445024659647	
i 1	508.7303333333333	0.2525	74	1089	5	1	5	16	0	1	16	0	0	2.0	
i 1	508.73996598639457	3.535	73	205	4	20	1	17	0	1	17	0	0	4.000000000000001	
i 1	508.74638775510203	1.5150000000000001	76	1089	2	20	5	16	0	1	16	0	0	4.000000000000001	
i 1	508.74959863945577	1.5150000000000001	70	1089	2	24	9	2	0	-1	2	0	0	8.0	
i 1	508.75361224489797	0.2525	69	1089	4	5	5	1	0	-1	1	0	0	2.5915445024659647	
i 1	508.75762585034016	0.2525	74	1089	4	3	10	16	0	2	16	0	0	4.889597876681885	
i 1	508.76244217687076	3.0300000000000002	73	205	4	20	15	8	0	-2	8	0	0	4.000000000000001	
i 1	508.7656530612245	0.505	77	703	4	24	13	16	0	2	16	0	0	3.0	
i 1	508.98675510204083	0.2525	77	205	7	1	1	17	0	1	17	0	0	2.0	
i 1	509.01003401360543	2.02	72	205	5	5	8	0	0	0	0	0	0	2.5915445024659647	
i 1	509.01806122448977	2.02	69	703	5	5	3	0	0	0	0	0	0	2.5915445024659647	
i 1	509.24157142857143	3.535	74	1089	4	24	11	17	0	1	17	0	0	3.0	
i 1	509.4803333333333	0.2525	74	1089	4	3	15	16	0	2	16	0	0	4.889597876681885	
i 1	509.4931768707483	3.535	74	703	6	1	6	16	0	1	16	0	0	2.0	
i 1	509.74157142857143	0.2525	77	205	5	9	9	16	0	2	16	0	0	3.889597876681885	
i 1	509.7479931972789	0.505	74	205	5	9	14	16	0	1	16	0	0	3.889597876681885	
i 1	509.9931768707483	2.7775	74	1089	6	2	11	17	0	2	17	0	0	4.889597876681885	
i 1	510.0196666666667	0.2525	69	1089	4	5	10	1	0	-1	1	0	0	2.5915445024659647	
i 1	510.2431768707483	2.7775	69	205	6	5	11	0	0	0	0	0	0	2.5915445024659647	
i 1	510.24397959183676	0.2525	77	703	4	24	7	16	0	2	16	0	0	3.0	
i 1	510.2664557823129	0.2525	74	1089	4	3	4	16	0	2	16	0	0	4.889597876681885	
i 1	510.4979931972789	1.2625	77	205	7	1	15	16	0	1	16	0	0	2.0	
i 1	510.51485034013604	2.2725	74	205	5	9	12	16	0	1	16	0	0	3.889597876681885	
i 1	510.73113605442177	1.01	77	1089	6	1	2	17	0	2	17	0	0	2.0	
i 1	510.9803333333333	0.7575000000000001	69	1089	4	5	4	1	0	-1	1	0	0	2.5915445024659647	
i 1	510.9883605442177	0.2525	69	703	5	5	15	1	0	-1	1	0	0	2.5915445024659647	
i 1	511.24157142857143	0.2525	74	1089	4	3	5	16	0	2	16	0	0	4.889597876681885	
i 1	511.2471904761905	2.525	76	1089	2	20	2	16	0	1	16	0	0	4.000000000000001	
i 1	511.25842857142857	0.505	74	1089	6	2	15	17	0	1	17	0	0	4.889597876681885	
i 1	511.25842857142857	0.2525	69	1089	4	5	11	1	0	-1	1	0	0	2.5915445024659647	
i 1	511.73113605442177	0.2525	77	205	5	9	14	16	0	2	16	0	0	3.889597876681885	
i 1	511.73755782312924	0.2525	74	1089	5	1	14	16	0	1	16	0	0	2.0	
i 1	511.74959863945577	0.505	69	703	5	5	8	1	0	-1	1	0	0	2.5915445024659647	
i 1	511.75361224489797	0.2525	70	1089	4	20	1	2	0	-2	2	0	0	4.000000000000001	
i 1	511.75602040816324	0.2525	70	703	4	20	6	8	0	-2	8	0	0	4.000000000000001	
i 1	511.76003401360543	0.2525	70	703	4	24	15	2	0	-1	2	0	0	8.0	
i 1	511.76244217687076	0.2525	77	703	5	3	7	16	0	1	16	0	0	4.889597876681885	
i 1	511.76485034013604	0.2525	77	205	7	1	12	17	0	1	17	0	0	2.0	
i 1	511.9931768707483	1.01	70	1089	2	20	9	8	0	-2	8	0	0	4.000000000000001	
i 1	511.99879591836736	3.2825	77	205	7	1	11	16	0	1	16	0	0	2.0	
i 1	512.0028095238096	0.2525	73	205	4	20	1	2	0	-2	2	0	0	4.000000000000001	
i 1	512.009231292517	0.7575000000000001	73	1089	2	24	8	8	0	-1	8	0	0	8.0	
i 1	512.0124421768708	1.01	74	1089	4	3	5	16	0	2	16	0	0	4.889597876681885	
i 1	512.0132448979592	3.2825	77	1089	6	1	7	17	0	2	17	0	0	2.0	
i 1	512.0180612244898	1.7675	74	1089	6	2	13	17	0	1	17	0	0	4.889597876681885	
i 1	512.0188639455782	0.2525	69	703	5	5	13	0	0	0	0	0	0	2.5915445024659647	
i 1	512.2576258503401	1.5150000000000001	69	1089	4	5	12	1	0	-1	1	0	0	2.5915445024659647	
i 1	512.264850340136	3.535	69	1089	5	5	13	1	0	0	1	0	0	2.5915445024659647	
i 1	512.483544217687	5.05	77	703	5	3	7	16	0	1	16	0	0	4.889597876681885	
i 1	512.514850340136	0.505	73	205	4	20	9	2	0	-2	2	0	0	4.000000000000001	
i 1	512.5156530612245	1.2625	74	1089	4	4	1	16	0	2	16	0	0	4.889597876681885	
i 1	512.7656530612245	0.505	77	1089	6	1	3	17	0	1	17	0	0	2.0	
i 1	512.9803333333333	0.505	74	1089	3	3	15	16	0	2	16	0	0	4.889597876681885	
i 1	512.9819387755102	14.8975	61	1089	5	25	13	9	0	1	9	0	0	1.721643542311956	
i 1	512.9827414965987	27.27	61	205	5	26	10	6	0	1	6	0	0	1.721643542311956	
i 1	512.9883605442177	0.505	74	1089	4	24	11	17	0	1	17	0	0	3.0	
i 1	512.9923741496599	1.2625	69	205	5	5	3	0	0	0	0	0	0	2.5915445024659647	
i 1	512.9947823129252	1.5150000000000001	69	1089	5	5	15	1	0	-1	1	0	0	2.5915445024659647	
i 1	513.0060204081633	0.2525	70	1089	4	20	3	2	0	-2	2	0	0	4.000000000000001	
i 1	513.0108367346938	0.2525	70	703	4	20	14	8	0	-1	8	0	0	4.000000000000001	
i 1	513.0108367346938	3.0300000000000002	73	205	4	20	2	17	0	1	17	0	0	4.000000000000001	
i 1	513.2391632653062	0.2525	73	205	4	20	12	8	0	-2	8	0	0	4.000000000000001	
i 1	513.2576258503401	0.2525	73	1089	2	20	12	8	0	-1	8	0	0	4.000000000000001	
i 1	513.4875578231292	0.2525	73	1089	4	20	11	8	0	-2	8	0	0	4.000000000000001	
i 1	513.4995986394558	0.505	77	703	4	24	12	16	0	2	16	0	0	3.0	
i 1	513.5100340136055	0.2525	73	703	4	20	9	2	0	-2	2	0	0	4.000000000000001	
i 1	513.5180612244898	2.02	77	703	4	4	14	16	0	2	16	0	0	4.889597876681885	
i 1	513.7367551020408	1.01	73	1	3	24	5	2	0	-2	2	0	0	8.0	
i 1	513.7399659863945	0.505	70	1	3	20	1	2	0	-2	2	0	0	4.000000000000001	
i 1	513.7415714285714	0.7575000000000001	77	1089	6	1	9	17	0	1	17	0	0	2.0	
i 1	513.7431768707482	1.01	70	1	3	20	14	2	0	-1	2	0	0	4.000000000000001	
i 1	513.7455850340136	0.505	73	205	4	20	1	2	0	-1	2	0	0	4.000000000000001	
i 1	513.7512040816326	2.02	74	1	5	5	7	2	0	-1	2	0	0	2.5915445024659647	
i 1	513.7584285714286	2.525	77	205	6	9	12	16	0	2	16	0	0	3.889597876681885	
i 1	513.7608367346938	14.14	67	1	4	12	3	5	0	0	5	0	0	1.9072143162639486	
i 1	513.7640476190476	14.14	60	1	4	12	3	0	0	0	0	0	0	1.9072143162639486	
i 1	513.7688639455782	4.04	75	1	5	4	6	2	0	-2	2	0	0	4.889597876681885	
i 1	513.9915714285714	0.2525	69	1	5	24	8	1	0	0	1	0	0	3.0	
i 1	513.9963877551021	1.7675	73	205	4	24	12	16	0	1	16	0	0	8.0	
i 1	514.2311360544218	0.505	72	205	5	5	13	0	0	0	0	0	0	2.5915445024659647	
i 1	514.2343469387755	2.7775	77	703	4	24	9	16	0	2	16	0	0	3.0	
i 1	514.2552176870748	0.2525	73	1089	4	20	3	2	0	-2	2	0	0	4.000000000000001	
i 1	514.2568231292518	0.2525	73	703	4	20	10	2	0	-2	2	0	0	4.000000000000001	
i 1	514.2632448979592	0.2525	73	1089	4	20	15	2	0	-1	2	0	0	4.000000000000001	
i 1	514.4931768707482	1.2625	73	205	4	20	8	2	0	-2	2	0	0	4.000000000000001	
i 1	514.4939795918367	2.525	77	205	7	1	1	17	0	1	17	0	0	2.0	
i 1	514.5132448979592	2.525	73	205	4	20	14	2	0	-2	2	0	0	4.000000000000001	
i 1	514.5140476190476	2.2725	69	703	5	5	5	1	0	-1	1	0	0	2.5915445024659647	
i 1	514.5196666666667	0.2525	70	1	3	20	5	8	0	-2	8	0	0	4.000000000000001	
i 1	514.735149659864	2.02	71	1	5	5	12	2	0	-1	2	0	0	2.5915445024659647	
i 1	514.9891632653062	2.02	70	1	3	20	11	8	0	-2	8	0	0	4.000000000000001	
i 1	514.9891632653062	4.7975	73	1	3	24	15	2	0	-2	2	0	0	8.0	
i 1	515.2319387755102	6.8175	74	703	6	1	11	16	0	1	16	0	0	2.0	
i 1	515.2680612244898	0.2525	69	1	5	24	12	1	0	0	1	0	0	3.0	
i 1	515.4883605442177	0.2525	77	1089	6	1	2	17	0	2	17	0	0	2.0	
i 1	515.490768707483	0.2525	74	1089	6	2	5	17	0	1	17	0	0	4.889597876681885	
i 1	515.7311360544218	0.7575000000000001	72	1	4	3	9	2	0	-2	2	0	0	4.889597876681885	
i 1	515.7375578231292	1.5150000000000001	69	205	5	5	5	0	0	0	0	0	0	2.5915445024659647	
i 1	515.7552176870748	1.5150000000000001	69	1089	5	5	7	1	0	-1	1	0	0	2.5915445024659647	
i 1	515.7560204081633	6.3125	69	1	5	24	1	1	0	0	1	0	0	3.0	
i 1	516.0076258503401	1.5150000000000001	73	205	4	24	15	16	0	1	16	0	0	8.0	
i 1	516.2303333333333	2.525	72	205	5	5	2	0	0	0	0	0	0	2.5915445024659647	
i 1	516.2311360544218	2.7775	69	703	5	5	11	0	0	0	0	0	0	2.5915445024659647	
i 1	516.2688639455782	0.2525	74	1089	6	2	3	17	0	1	17	0	0	4.889597876681885	
i 1	516.5028095238096	2.7775	74	205	5	9	2	16	0	1	16	0	0	3.889597876681885	
i 1	516.5060204081633	1.2625	70	1	3	20	3	2	0	-1	2	0	0	4.000000000000001	
i 1	516.5108367346938	2.7775	74	1089	6	2	11	17	0	2	17	0	0	4.889597876681885	
i 1	516.7560204081633	0.2525	73	205	4	20	7	2	0	-2	2	0	0	4.000000000000001	
i 1	516.7696666666667	3.0300000000000002	73	205	4	20	13	17	0	1	17	0	0	4.000000000000001	
i 1	516.9923741496599	3.2825	77	205	7	1	2	16	0	1	16	0	0	2.0	
i 1	517.0020068027211	0.2525	73	703	4	20	2	8	0	-2	8	0	0	4.000000000000001	
i 1	517.0044149659864	0.2525	70	1089	4	20	7	8	0	-2	8	0	0	4.000000000000001	
i 1	517.0124421768708	0.2525	73	1089	4	20	5	8	0	-2	8	0	0	4.000000000000001	
i 1	517.014850340136	3.2825	77	1089	6	1	9	17	0	2	17	0	0	2.0	
i 1	517.2327414965987	0.505	69	1089	5	5	8	1	0	0	1	0	0	2.5915445024659647	
i 1	517.2367551020408	0.2525	73	205	4	20	4	2	0	-2	2	0	0	4.000000000000001	
i 1	517.2375578231292	0.7575000000000001	73	205	4	20	8	2	0	-2	2	0	0	4.000000000000001	
i 1	517.2568231292518	0.7575000000000001	70	1	3	20	4	8	0	-1	8	0	0	4.000000000000001	
i 1	517.2584285714286	0.2525	71	1	5	5	14	2	0	-1	2	0	0	2.5915445024659647	
i 1	517.4987959183674	0.2525	69	703	5	5	2	1	0	-1	1	0	0	2.5915445024659647	
i 1	517.5060204081633	0.505	77	703	4	4	4	16	0	2	16	0	0	4.889597876681885	
i 1	517.7455850340136	2.2725	69	205	5	5	10	0	0	0	0	0	0	2.5915445024659647	
i 1	517.7471904761904	2.02	69	1089	5	5	13	1	0	-1	1	0	0	2.5915445024659647	
i 1	517.7616394557823	2.2725	72	1	4	3	6	2	0	-2	2	0	0	4.889597876681885	
i 1	517.9915714285714	0.2525	70	1089	4	20	16	8	0	-2	8	0	0	4.000000000000001	
i 1	517.9931768707482	0.2525	77	205	6	9	3	16	0	2	16	0	0	3.889597876681885	
i 1	518.0028095238096	1.7675	70	1	3	20	7	2	0	-1	2	0	0	4.000000000000001	
i 1	518.014850340136	0.2525	70	703	4	20	7	2	0	-2	2	0	0	4.000000000000001	
i 1	518.2359523809524	1.7675	74	1089	6	2	15	17	0	1	17	0	0	4.889597876681885	
i 1	518.2439795918367	0.2525	70	1	3	20	3	2	0	-2	2	0	0	4.000000000000001	
i 1	518.2520068027211	0.2525	73	205	4	20	16	8	0	-2	8	0	0	4.000000000000001	
i 1	518.5036122448979	0.505	73	1089	4	20	4	2	0	-2	2	0	0	4.000000000000001	
i 1	518.5076258503401	0.505	73	703	4	20	8	8	0	-1	8	0	0	4.000000000000001	
i 1	518.7383605442177	4.7975	69	1089	5	5	10	1	0	0	1	0	0	2.5915445024659647	
i 1	518.9899659863945	0.7575000000000001	75	1	5	4	1	2	0	-2	2	0	0	4.889597876681885	
i 1	518.9971904761904	0.7575000000000001	74	1	5	5	9	2	0	-1	2	0	0	2.5915445024659647	
i 1	519.0052176870748	0.2525	70	205	4	20	7	2	0	-1	2	0	0	4.000000000000001	
i 1	519.0116394557823	5.555	77	703	5	3	16	16	0	1	16	0	0	4.889597876681885	
i 1	519.0172585034013	0.2525	70	1	3	20	14	2	0	-2	2	0	0	4.000000000000001	
i 1	519.235149659864	0.2525	73	703	4	20	15	2	0	-2	2	0	0	4.000000000000001	
i 1	519.2359523809524	0.2525	73	1089	4	20	2	2	0	-1	2	0	0	4.000000000000001	
i 1	519.7319387755102	17.9275	66	703	5	25	1	9	0	2	9	0	0	1.721643542311956	
i 1	519.7367551020408	1.5150000000000001	77	205	6	9	1	16	0	2	16	0	0	3.889597876681885	
i 1	519.7447823129252	1.2625	77	703	4	4	9	16	0	2	16	0	0	4.889597876681885	
i 1	519.7463877551021	6.3125	73	1	3	24	10	2	0	-2	2	0	0	4.0	
i 1	519.7528095238096	3.2825	74	1	4	5	16	2	0	-1	2	0	0	2.5915445024659647	
i 1	519.7536122448979	0.2525	69	1089	6	5	6	1	0	-1	1	0	0	2.5915445024659647	
i 1	519.766455782313	4.2925	75	1	4	4	11	2	0	-2	2	0	0	4.889597876681885	
i 1	519.7680612244898	8.08	60	1	4	27	9	5	0	0	5	0	0	3.4432870846239125	
i 1	519.9995986394558	0.505	69	703	5	5	8	0	0	0	0	0	0	2.5915445024659647	
i 1	520.0188639455782	0.2525	72	205	5	5	1	0	0	0	0	0	0	2.5915445024659647	
i 1	520.2439795918367	0.2525	69	703	5	5	10	1	0	-1	1	0	0	2.5915445024659647	
i 1	520.2479931972789	0.2525	77	703	4	24	15	16	0	2	16	0	0	3.0	
i 1	520.2616394557823	0.505	69	1	6	1	10	0	0	-1	0	0	0	2.0	
i 1	520.4947823129252	0.505	73	205	4	24	2	16	0	1	16	0	0	4.0	
i 1	520.5004013605442	2.02	69	1089	6	5	6	1	0	-1	1	0	0	2.5915445024659647	
i 1	520.5060204081633	2.02	69	205	5	5	6	0	0	0	0	0	0	2.5915445024659647	
i 1	520.5156530612245	0.2525	77	205	7	1	3	17	0	1	17	0	0	2.0	
i 1	520.7568231292518	3.7875	77	205	7	1	7	16	0	1	16	0	0	2.0	
i 1	520.766455782313	3.7875	77	1089	6	1	15	17	0	2	17	0	0	2.0	
i 1	521.0068231292518	0.2525	74	1089	6	2	7	17	0	1	17	0	0	4.889597876681885	
i 1	521.240768707483	0.505	72	1	4	3	16	2	0	-2	2	0	0	4.889597876681885	
i 1	521.2495986394558	0.505	77	703	4	4	2	16	0	2	16	0	0	4.889597876681885	
i 1	521.7343469387755	0.2525	74	205	6	9	7	16	0	1	16	0	0	3.889597876681885	
i 1	521.7512040816326	0.2525	74	1089	6	2	9	17	0	2	17	0	0	4.889597876681885	
i 1	521.9843469387755	0.505	77	205	6	9	7	16	0	2	16	0	0	3.889597876681885	
i 1	521.9891632653062	1.2625	77	205	7	1	6	17	0	1	17	0	0	2.0	
i 1	521.9899659863945	2.525	71	1	5	5	3	2	0	-1	2	0	0	2.5915445024659647	
i 1	521.990768707483	2.525	69	703	5	5	15	1	0	-1	1	0	0	2.5915445024659647	
i 1	521.9971904761904	0.505	70	1	3	24	9	8	0	-2	8	0	0	4.0	
i 1	522.0060204081633	0.2525	72	1	4	3	11	2	0	-2	2	0	0	4.889597876681885	
i 1	522.009231292517	0.2525	69	1	6	1	12	0	0	-1	0	0	0	2.0	
i 1	522.0116394557823	1.2625	73	205	4	24	7	16	0	1	16	0	0	4.0	
i 1	522.2528095238096	0.2525	77	703	4	24	15	16	0	2	16	0	0	3.0	
i 1	522.2632448979592	0.505	77	703	4	4	3	16	0	2	16	0	0	4.889597876681885	
i 1	522.4915714285714	0.505	74	1089	6	2	10	17	0	1	17	0	0	4.889597876681885	
i 1	522.4987959183674	0.2525	70	703	4	24	14	8	0	-2	8	0	0	4.0	
i 1	522.733544217687	2.02	70	1	3	24	2	2	0	-1	2	0	0	4.0	
i 1	522.7375578231292	0.2525	72	1	4	3	16	2	0	-2	2	0	0	4.889597876681885	
i 1	522.9947823129252	0.2525	69	1089	6	5	7	1	0	-1	1	0	0	2.5915445024659647	
i 1	523.0084285714286	2.525	74	205	6	9	6	16	0	1	16	0	0	3.889597876681885	
i 1	523.0156530612245	2.525	74	1089	6	2	2	17	0	2	17	0	0	4.889597876681885	
i 1	523.2303333333333	0.2525	69	703	5	5	12	0	0	0	0	0	0	2.5915445024659647	
i 1	523.2319387755102	0.2525	69	1	6	1	3	0	0	-1	0	0	0	2.0	
i 1	523.266455782313	0.2525	69	1	5	24	3	1	0	0	1	0	0	3.0	
i 1	523.4827414965987	1.5150000000000001	77	205	7	1	7	17	0	1	17	0	0	2.0	
i 1	523.4859523809524	4.2925	69	1089	6	5	16	1	0	-1	1	0	0	2.5915445024659647	
i 1	523.4883605442177	1.5150000000000001	77	703	4	24	2	16	0	2	16	0	0	3.0	
i 1	523.4979931972789	6.8175	69	205	5	5	14	0	0	0	0	0	0	2.5915445024659647	
i 1	523.9843469387755	3.7875	69	1	5	24	6	1	0	0	1	0	0	3.0	
i 1	523.985149659864	5.8075	74	703	6	1	8	16	0	1	16	0	0	2.0	
i 1	523.9883605442177	0.2525	77	205	6	9	4	16	0	2	16	0	0	3.889597876681885	
i 1	524.2447823129252	1.5150000000000001	72	1	4	3	16	2	0	-2	2	0	0	4.889597876681885	
i 1	524.4803333333333	1.5150000000000001	72	205	5	5	3	0	0	0	0	0	0	2.5915445024659647	
i 1	524.483544217687	1.2625	69	703	5	5	15	0	0	0	0	0	0	2.5915445024659647	
i 1	524.4891632653062	1.5150000000000001	74	1089	6	2	15	17	0	1	17	0	0	4.889597876681885	
i 1	524.7343469387755	2.02	77	1089	6	1	5	17	0	2	17	0	0	2.0	
i 1	524.7447823129252	4.04	77	703	5	3	6	16	0	1	16	0	0	4.889597876681885	
i 1	524.7576258503401	2.02	77	205	7	1	11	16	0	1	16	0	0	2.0	
i 1	524.7584285714286	3.0300000000000002	75	1	4	4	6	2	0	-2	2	0	0	4.889597876681885	
i 1	524.9819387755102	0.505	73	703	4	24	11	8	0	-2	8	0	0	4.0	
i 1	525.4875578231292	1.5150000000000001	70	1	3	24	11	8	0	-2	8	0	0	4.0	
i 1	525.733544217687	0.2525	74	205	6	9	2	16	0	1	16	0	0	3.889597876681885	
i 1	525.7632448979592	0.7575000000000001	69	1089	5	5	14	1	0	0	1	0	0	2.5915445024659647	
i 1	525.9803333333333	1.7675	77	703	4	4	13	16	0	2	16	0	0	4.889597876681885	
i 1	525.983544217687	0.505	74	1	4	5	8	2	0	-1	2	0	0	2.5915445024659647	
i 1	526.0020068027211	4.04	77	205	6	9	5	16	0	2	16	0	0	3.889597876681885	
i 1	526.4859523809524	1.2625	61	1089	4	14	16	6	0	2	6	0	0	2.6591100107384555	
i 1	526.4955850340136	1.2625	60	1	4	27	4	0	0	0	0	0	0	3.4432870846239125	
i 1	526.4995986394558	11.11	66	703	5	25	6	9	0	1	9	0	0	1.721643542311956	
i 1	526.5020068027211	1.7675	73	205	4	24	9	16	0	1	16	0	0	4.0	
i 1	526.5028095238096	0.2525	71	1	4	5	9	2	0	-1	2	0	0	2.5915445024659647	
i 1	526.5108367346938	0.505	69	1089	6	5	12	1	0	0	1	0	0	2.5915445024659647	
i 1	526.733544217687	0.2525	77	703	4	24	14	16	0	2	16	0	0	3.0	
i 1	526.7391632653062	2.02	72	205	5	5	7	0	0	0	0	0	0	2.5915445024659647	
i 1	526.7608367346938	1.01	73	1	3	24	16	2	0	-2	2	0	0	4.0	
i 1	526.7672585034013	0.2525	77	205	6	1	4	17	0	1	17	0	0	2.0	
i 1	526.9819387755102	0.505	77	1089	6	1	6	17	0	2	17	0	0	2.0	
i 1	526.9995986394558	0.2525	77	1089	6	1	15	17	0	1	17	0	0	2.0	
i 1	527.0028095238096	0.2525	69	703	5	5	11	0	0	0	0	0	0	2.5915445024659647	
i 1	527.0108367346938	0.2525	70	703	4	24	16	2	0	-1	2	0	0	4.0	
i 1	527.240768707483	0.2525	74	1	4	5	1	2	0	-1	2	0	0	2.5915445024659647	
i 1	527.2568231292518	0.505	73	1	3	24	3	8	0	-1	8	0	0	4.0	
i 1	527.2616394557823	0.505	72	1	6	3	13	2	0	-2	2	0	0	4.889597876681885	
i 1	527.4891632653062	0.2525	69	1	6	1	2	0	0	-1	0	0	0	2.0	
i 1	527.5052176870748	0.2525	71	1	4	5	3	2	0	-1	2	0	0	2.5915445024659647	
i 1	527.5188639455782	0.2525	77	703	4	24	10	16	0	2	16	0	0	3.0	
i 1	527.7303333333333	12.3725	67	907	5	25	6	5	0	0	5	0	0	1.721643542311956	
i 1	527.7319387755102	5.555	60	907	5	14	5	0	0	1	0	0	0	2.6591100107384555	
i 1	527.7327414965987	1.01	74	907	6	5	3	2	0	-2	2	0	0	2.5915445024659647	
i 1	527.7359523809524	0.2525	73	703	4	24	15	8	0	-1	8	0	0	4.0	
i 1	527.7367551020408	8.3325	70	205	3	24	5	2	0	-2	2	0	0	4.0	
i 1	527.7383605442177	0.2525	77	205	7	1	14	16	0	1	16	0	0	2.0	
i 1	527.7383605442177	0.505	75	205	4	4	6	2	0	-2	2	0	0	4.889597876681885	
i 1	527.7391632653062	19.19	60	205	4	12	16	5	0	0	5	0	0	1.9072143162639486	
i 1	527.7391632653062	26.0075	60	205	4	12	6	0	0	1	0	0	0	1.9072143162639486	
i 1	527.7415714285714	26.0075	67	205	4	27	14	0	0	0	0	0	0	3.4432870846239125	
i 1	527.7479931972789	2.02	72	205	6	1	10	0	0	0	0	0	0	2.0	
i 1	527.7504013605442	19.19	60	205	4	27	14	5	0	1	5	0	0	3.4432870846239125	
i 1	527.7504013605442	2.525	74	907	6	5	11	2	0	-2	2	0	0	2.5915445024659647	
i 1	527.7544149659864	1.01	72	205	6	3	10	2	0	1	2	0	0	4.889597876681885	
i 1	527.7576258503401	5.555	60	907	5	25	12	5	0	1	5	0	0	1.721643542311956	
i 1	527.7600340136055	12.3725	67	907	4	14	12	5	0	0	5	0	0	2.6591100107384555	
i 1	527.7688639455782	0.505	72	205	5	24	11	1	0	0	1	0	0	3.0	
i 1	528.0012040816326	2.7775	70	205	3	24	8	2	0	-2	2	0	0	4.0	
i 1	528.0084285714286	2.02	75	907	6	2	4	2	0	1	2	0	0	4.889597876681885	
i 1	528.2311360544218	3.2825	77	205	6	1	4	17	0	1	17	0	0	2.0	
i 1	528.4803333333333	0.2525	72	907	6	1	12	0	0	-1	0	0	0	2.0	
i 1	528.7375578231292	0.2525	69	703	5	5	15	0	0	0	0	0	0	2.5915445024659647	
i 1	528.7423741496599	0.2525	77	703	4	4	12	16	0	2	16	0	0	4.889597876681885	
i 1	528.7487959183674	2.525	74	205	6	9	5	16	0	1	16	0	0	3.889597876681885	
i 1	528.7512040816326	2.7775	69	907	6	1	15	1	0	0	1	0	0	2.0	
i 1	528.7608367346938	2.2725	69	703	5	5	10	1	0	-1	1	0	0	2.5915445024659647	
i 1	528.9843469387755	2.2725	72	907	6	2	7	8	0	-2	8	0	0	4.889597876681885	
i 1	528.9923741496599	0.2525	71	205	4	5	1	8	0	-1	8	0	0	2.5915445024659647	
i 1	529.2656530612245	1.7675	71	205	4	5	1	2	0	-1	2	0	0	2.5915445024659647	
i 1	529.7544149659864	0.505	77	703	4	24	8	16	0	2	16	0	0	3.0	
i 1	529.7656530612245	0.2525	77	205	7	1	5	16	0	1	16	0	0	2.0	
i 1	529.9843469387755	0.2525	77	703	5	3	8	16	0	1	16	0	0	4.889597876681885	
i 1	529.9859523809524	0.2525	72	205	6	1	9	0	0	0	0	0	0	2.0	
i 1	529.9923741496599	0.2525	75	205	4	4	10	2	0	-2	2	0	0	4.889597876681885	
i 1	530.2327414965987	1.5150000000000001	72	205	5	5	13	0	0	0	0	0	0	2.5915445024659647	
i 1	530.235149659864	4.2925	74	907	6	5	3	2	0	-2	2	0	0	2.5915445024659647	
i 1	530.2471904761904	0.2525	74	703	6	1	12	16	0	1	16	0	0	2.0	
i 1	530.2696666666667	0.2525	75	907	6	2	8	2	0	1	2	0	0	4.889597876681885	
i 1	530.4811360544218	1.5150000000000001	72	205	6	3	1	2	0	1	2	0	0	4.889597876681885	
i 1	530.4843469387755	1.7675	72	205	5	24	16	1	0	0	1	0	0	3.0	
i 1	530.4875578231292	2.525	71	205	4	5	9	8	0	-1	8	0	0	2.5915445024659647	
i 1	530.4915714285714	2.7775	69	703	5	5	13	0	0	0	0	0	0	2.5915445024659647	
i 1	530.4979931972789	1.5150000000000001	77	703	5	3	9	16	0	1	16	0	0	4.889597876681885	
i 1	530.5140476190476	1.7675	77	703	4	24	13	16	0	2	16	0	0	3.0	
i 1	531.0060204081633	2.2725	75	205	4	4	11	2	0	-2	2	0	0	4.889597876681885	
i 1	531.009231292517	2.02	77	703	4	4	15	16	0	2	16	0	0	4.889597876681885	
i 1	531.235149659864	2.2725	72	205	6	1	14	0	0	0	0	0	0	2.0	
i 1	531.2536122448979	2.2725	73	205	4	24	12	16	0	1	16	0	0	4.0	
i 1	531.2608367346938	2.02	74	703	6	1	15	16	0	1	16	0	0	2.0	
i 1	532.0020068027211	0.2525	74	205	6	9	4	16	0	1	16	0	0	3.889597876681885	
i 1	532.0076258503401	0.2525	72	907	6	2	12	8	0	-2	8	0	0	4.889597876681885	
i 1	532.0100340136055	2.7775	72	205	5	5	12	0	0	0	0	0	0	2.5915445024659647	
i 1	532.2423741496599	2.525	72	205	6	3	7	2	0	1	2	0	0	4.889597876681885	
i 1	532.2431768707482	2.525	69	907	6	1	7	1	0	0	1	0	0	2.0	
i 1	532.2616394557823	2.525	77	703	5	3	8	16	0	1	16	0	0	4.889597876681885	
i 1	532.2624421768708	2.525	77	205	6	1	12	17	0	1	17	0	0	2.0	
i 1	532.5172585034013	0.2525	70	205	3	24	5	2	0	-2	2	0	0	4.0	
i 1	532.7455850340136	0.2525	70	703	4	24	16	2	0	-1	2	0	0	4.0	
i 1	532.985149659864	1.7675	70	205	3	24	4	2	0	-1	2	0	0	4.0	
i 1	532.9891632653062	0.2525	69	205	5	5	12	0	0	0	0	0	0	2.5915445024659647	
i 1	533.0172585034013	0.2525	75	907	6	2	1	2	0	1	2	0	0	4.889597876681885	
i 1	533.2319387755102	0.2525	72	205	5	24	15	1	0	0	1	0	0	3.0	
i 1	533.233544217687	0.2525	77	703	4	4	12	16	0	2	16	0	0	4.889597876681885	
i 1	533.2359523809524	27.27	61	205	5	26	1	9	0	1	9	0	0	1.721643542311956	
i 1	533.2544149659864	0.2525	75	907	4	2	15	2	0	1	2	0	0	4.889597876681885	
i 1	533.2608367346938	2.525	74	907	6	5	10	2	0	-2	2	0	0	2.5915445024659647	
i 1	533.2656530612245	6.8175	60	907	5	25	11	5	0	1	5	0	0	1.721643542311956	
i 1	533.2688639455782	13.635	60	907	4	14	15	0	0	1	0	0	0	2.6591100107384555	
i 1	533.4811360544218	0.2525	77	703	4	24	5	16	0	2	16	0	0	3.0	
i 1	533.485149659864	2.2725	69	205	5	5	8	0	0	0	0	0	0	2.5915445024659647	
i 1	533.516455782313	3.0300000000000002	77	205	6	9	13	16	0	2	16	0	0	3.889597876681885	
i 1	533.7359523809524	2.7775	75	907	4	2	9	2	0	1	2	0	0	4.889597876681885	
i 1	533.740768707483	2.525	72	205	6	1	13	0	0	0	0	0	0	2.0	
i 1	533.7544149659864	2.525	74	703	6	1	3	16	0	1	16	0	0	2.0	
i 1	534.0020068027211	3.2825	73	205	4	24	14	16	0	1	16	0	0	4.0	
i 1	534.5188639455782	0.2525	71	205	4	5	3	8	0	-1	8	0	0	2.5915445024659647	
i 1	534.7439795918367	0.505	72	907	6	2	6	8	0	-2	8	0	0	4.889597876681885	
i 1	534.7576258503401	0.2525	77	703	4	24	12	16	0	2	16	0	0	3.0	
i 1	534.7680612244898	0.2525	75	205	5	4	10	2	0	-2	2	0	0	4.889597876681885	
i 1	534.7688639455782	2.2725	74	907	6	5	11	2	0	-2	2	0	0	2.5915445024659647	
i 1	534.9827414965987	0.2525	71	205	4	5	14	2	0	-1	2	0	0	2.5915445024659647	
i 1	534.9931768707482	0.2525	77	703	4	4	7	16	0	2	16	0	0	4.889597876681885	
i 1	535.0020068027211	0.2525	69	907	6	1	2	1	0	0	1	0	0	2.0	
i 1	535.2528095238096	0.2525	77	205	6	1	16	16	0	1	16	0	0	2.0	
i 1	535.2624421768708	0.2525	72	907	6	1	6	0	0	-1	0	0	0	2.0	
i 1	535.2640476190476	3.7875	72	205	5	5	4	0	0	0	0	0	0	2.5915445024659647	
i 1	535.4899659863945	0.2525	72	205	6	3	10	2	0	1	2	0	0	4.889597876681885	
i 1	535.5004013605442	4.2925	69	907	6	1	1	1	0	0	1	0	0	2.0	
i 1	535.5188639455782	1.7675	77	205	6	1	10	17	0	1	17	0	0	2.0	
i 1	535.7423741496599	0.2525	69	703	6	5	16	1	0	-1	1	0	0	2.5915445024659647	
i 1	535.7471904761904	0.2525	75	205	5	4	1	2	0	-2	2	0	0	4.889597876681885	
i 1	535.7495986394558	0.2525	73	703	4	24	2	2	0	-2	2	0	0	4.0	
i 1	535.7672585034013	0.2525	69	703	5	5	2	0	0	0	0	0	0	2.5915445024659647	
i 1	535.9923741496599	1.2625	69	205	5	5	16	0	0	0	0	0	0	2.5915445024659647	
i 1	535.9931768707482	1.5150000000000001	74	205	6	9	13	16	0	1	16	0	0	3.889597876681885	
i 1	536.0036122448979	1.5150000000000001	72	907	6	2	15	8	0	-2	8	0	0	4.889597876681885	
i 1	536.0076258503401	1.2625	74	907	6	5	11	2	0	-2	2	0	0	2.5915445024659647	
i 1	536.0132448979592	0.7575000000000001	73	205	3	24	3	8	0	-1	8	0	0	4.0	
i 1	536.2359523809524	1.7675	71	205	4	5	4	2	0	-1	2	0	0	2.5915445024659647	
i 1	536.2471904761904	0.2525	72	205	5	24	16	1	0	0	1	0	0	3.0	
i 1	536.2672585034013	1.2625	69	703	6	5	4	1	0	-1	1	0	0	2.5915445024659647	
i 1	536.4931768707482	1.5150000000000001	72	205	6	1	11	0	0	0	0	0	0	2.0	
i 1	536.4939795918367	9.8475	70	205	3	24	1	2	0	-2	2	0	0	4.0	
i 1	536.5012040816326	1.01	74	703	6	1	1	16	0	1	16	0	0	2.0	
i 1	536.5076258503401	1.01	77	703	5	3	13	16	0	1	16	0	0	4.889597876681885	
i 1	536.7343469387755	1.2625	72	205	6	3	12	2	0	1	2	0	0	4.889597876681885	
i 1	536.7560204081633	0.2525	73	703	4	24	1	2	0	-1	2	0	0	4.0	
i 1	536.9987959183674	0.2525	73	205	3	24	10	8	0	-2	8	0	0	4.0	
i 1	537.0100340136055	0.505	69	703	5	5	3	0	0	0	0	0	0	2.5915445024659647	
i 1	537.0108367346938	3.2825	75	205	5	4	12	2	0	-2	2	0	0	4.889597876681885	
i 1	537.2504013605442	2.525	77	205	6	1	13	16	0	1	16	0	0	2.0	
i 1	537.4803333333333	9.3425	60	591	5	25	10	5	0	0	5	0	0	1.721643542311956	
i 1	537.4819387755102	0.505	74	591	6	5	6	8	0	-1	8	0	0	2.5915445024659647	
i 1	537.485149659864	1.5150000000000001	71	591	5	5	8	2	0	-1	2	0	0	2.5915445024659647	
i 1	537.4867551020408	2.525	60	591	5	13	6	5	0	1	5	0	0	0.40886085265916766	
i 1	537.4899659863945	0.505	69	591	6	1	15	0	0	-1	0	0	0	2.0	
i 1	537.4955850340136	1.01	73	205	4	24	8	16	0	1	16	0	0	4.0	
i 1	537.4963877551021	2.525	72	591	5	3	15	2	0	-2	2	0	0	4.889597876681885	
i 1	537.4971904761904	9.3425	67	591	5	7	15	0	0	0	0	0	0	1.9090269580453596	
i 1	537.5140476190476	16.16	60	591	5	25	7	5	0	0	5	0	0	1.721643542311956	
i 1	537.7471904761904	0.2525	70	591	4	24	9	2	0	-1	2	0	0	4.0	
i 1	537.7672585034013	0.2525	75	907	4	2	8	2	0	1	2	0	0	4.889597876681885	
i 1	537.983544217687	0.2525	77	205	6	9	5	16	0	2	16	0	0	3.889597876681885	
i 1	537.985149659864	4.545	74	907	6	5	6	2	0	-2	2	0	0	2.5915445024659647	
i 1	537.9859523809524	4.2925	69	205	5	5	6	0	0	0	0	0	0	2.5915445024659647	
i 1	537.9867551020408	0.505	70	205	3	24	14	8	0	-1	8	0	0	4.0	
i 1	537.9931768707482	0.2525	69	591	4	24	13	1	0	0	1	0	0	3.0	
i 1	538.0156530612245	0.2525	75	591	4	4	9	8	0	-2	8	0	0	4.889597876681885	
i 1	538.2584285714286	0.505	75	907	4	2	4	2	0	1	2	0	0	4.889597876681885	
i 1	538.264850340136	0.2525	77	205	6	1	14	17	0	1	17	0	0	2.0	
i 1	538.490768707483	0.2525	72	907	6	2	10	8	0	-2	8	0	0	4.889597876681885	
i 1	538.5132448979592	0.2525	72	205	6	1	13	0	0	0	0	0	0	2.0	
i 1	538.733544217687	2.2725	69	591	6	1	1	0	0	-1	0	0	0	2.0	
i 1	538.7431768707482	0.505	72	205	6	3	4	2	0	1	2	0	0	4.889597876681885	
i 1	538.7439795918367	2.525	72	205	5	24	4	1	0	0	1	0	0	3.0	
i 1	539.0012040816326	0.2525	77	205	6	9	10	16	0	2	16	0	0	3.889597876681885	
i 1	539.0172585034013	0.505	71	205	4	5	3	8	0	-1	8	0	0	2.5915445024659647	
i 1	539.2367551020408	0.2525	71	205	4	5	16	2	0	-1	2	0	0	2.5915445024659647	
i 1	539.2479931972789	1.01	73	205	4	24	14	16	0	1	16	0	0	4.0	
i 1	539.2552176870748	2.7775	75	907	4	2	1	2	0	1	2	0	0	4.889597876681885	
i 1	539.2600340136055	2.7775	74	205	6	9	7	16	0	1	16	0	0	3.889597876681885	
i 1	539.4811360544218	0.2525	72	205	5	5	10	0	0	0	0	0	0	2.5915445024659647	
i 1	539.4923741496599	0.2525	74	907	6	5	12	2	0	-2	2	0	0	2.5915445024659647	
i 1	539.5076258503401	0.2525	70	205	3	24	16	8	0	-1	8	0	0	4.0	
i 1	539.7423741496599	0.2525	74	591	6	5	7	8	0	-1	8	0	0	2.5915445024659647	
i 1	539.7423741496599	4.04	71	205	4	5	15	2	0	-1	2	0	0	2.5915445024659647	
i 1	539.759231292517	0.2525	69	591	4	24	12	1	0	0	1	0	0	3.0	
i 1	539.7632448979592	0.2525	73	591	4	24	1	8	0	-2	8	0	0	4.0	
i 1	539.9811360544218	3.7875	74	907	6	5	12	2	0	-2	2	0	0	2.5915445024659647	
i 1	539.9827414965987	0.2525	72	205	5	1	4	0	0	0	0	0	0	2.0	
i 1	539.9875578231292	20.4525	67	907	5	14	15	5	0	0	5	0	0	2.6591100107384555	
i 1	539.9979931972789	6.8175	67	907	5	25	8	5	0	0	5	0	0	1.721643542311956	
i 1	540.0036122448979	27.27	61	205	5	26	7	6	0	1	6	0	0	1.721643542311956	
i 1	540.0068231292518	13.635	60	591	4	13	15	5	0	1	5	0	0	0.40886085265916766	
i 1	540.0172585034013	1.01	73	205	3	24	7	2	0	-1	2	0	0	4.0	
i 1	540.2391632653062	0.2525	72	205	6	3	12	2	0	1	2	0	0	4.889597876681885	
i 1	540.2423741496599	2.2725	69	907	6	1	8	1	0	0	1	0	0	2.0	
i 1	540.2447823129252	0.2525	75	591	4	4	2	8	0	-2	8	0	0	4.889597876681885	
i 1	540.2640476190476	2.525	77	205	6	1	3	16	0	1	16	0	0	2.0	
i 1	540.4811360544218	0.2525	77	205	6	9	1	16	0	2	16	0	0	3.889597876681885	
i 1	540.5196666666667	0.2525	75	205	5	4	2	2	0	-2	2	0	0	4.889597876681885	
i 1	540.7600340136055	0.2525	75	591	4	4	4	8	0	-2	8	0	0	4.889597876681885	
i 1	540.7656530612245	0.2525	72	591	5	3	5	2	0	-2	2	0	0	4.889597876681885	
i 1	541.0076258503401	1.7675	72	205	6	3	16	2	0	1	2	0	0	4.889597876681885	
i 1	541.0084285714286	1.7675	72	907	4	2	3	8	0	-2	8	0	0	4.889597876681885	
i 1	541.0188639455782	0.2525	73	591	4	24	13	2	0	-2	2	0	0	4.0	
i 1	541.233544217687	0.7575000000000001	72	907	6	1	15	0	0	-1	0	0	0	2.0	
i 1	541.735149659864	1.5150000000000001	73	205	4	24	15	16	0	1	16	0	0	4.0	
i 1	541.7487959183674	4.7975	72	591	5	3	8	2	0	-2	2	0	0	4.889597876681885	
i 1	541.7576258503401	4.7975	75	205	5	4	16	2	0	-2	2	0	0	4.889597876681885	
i 1	541.7600340136055	0.505	73	205	3	24	14	2	0	-2	2	0	0	4.0	
i 1	541.9899659863945	3.2825	69	591	6	1	3	0	0	-1	0	0	0	2.0	
i 1	541.9915714285714	3.2825	72	205	5	24	9	1	0	0	1	0	0	3.0	
i 1	542.2383605442177	0.2525	71	591	6	5	14	2	0	-1	2	0	0	2.5915445024659647	
i 1	542.2512040816326	0.505	73	591	4	24	6	2	0	-2	2	0	0	4.0	
i 1	542.4827414965987	0.505	72	205	5	1	12	0	0	0	0	0	0	2.0	
i 1	542.4827414965987	1.01	75	591	4	4	4	8	0	-2	8	0	0	4.889597876681885	
i 1	542.4955850340136	1.2625	77	205	6	9	6	16	0	2	16	0	0	3.889597876681885	
i 1	542.5188639455782	2.2725	74	591	6	5	6	8	0	-1	8	0	0	2.5915445024659647	
i 1	542.7367551020408	2.02	70	205	3	24	9	2	0	-2	2	0	0	4.0	
i 1	542.7560204081633	0.2525	69	907	6	1	1	1	0	0	1	0	0	2.0	
i 1	543.0004013605442	1.7675	71	205	4	5	14	8	0	-1	8	0	0	2.5915445024659647	
i 1	543.0140476190476	0.2525	77	205	6	1	11	17	0	1	17	0	0	2.0	
i 1	543.2423741496599	5.8075	77	205	6	1	16	16	0	1	16	0	0	2.0	
i 1	543.2656530612245	1.01	69	907	6	1	10	1	0	0	1	0	0	2.0	
i 1	543.7431768707482	0.505	72	205	6	3	15	2	0	1	2	0	0	4.889597876681885	
i 1	543.7608367346938	0.2525	72	205	5	5	12	0	0	0	0	0	0	2.5915445024659647	
i 1	543.9891632653062	1.2625	69	205	5	5	11	0	0	0	0	0	0	2.5915445024659647	
i 1	544.0140476190476	1.2625	74	907	6	5	10	2	0	-2	2	0	0	2.5915445024659647	
i 1	544.2455850340136	0.2525	72	907	4	2	10	8	0	-2	8	0	0	4.889597876681885	
i 1	544.2616394557823	0.505	75	591	4	4	16	8	0	-2	8	0	0	4.889597876681885	
i 1	544.4867551020408	2.02	72	205	5	5	15	0	0	0	0	0	0	2.5915445024659647	
i 1	544.4899659863945	3.2825	73	205	4	24	13	16	0	1	16	0	0	4.0	
i 1	544.4939795918367	2.2725	71	591	6	5	16	2	0	-1	2	0	0	2.5915445024659647	
i 1	544.5124421768708	4.545	69	907	6	1	16	1	0	0	1	0	0	2.0	
i 1	544.7367551020408	0.2525	77	205	6	9	14	16	0	2	16	0	0	3.889597876681885	
i 1	544.7439795918367	0.2525	75	907	4	2	8	2	0	1	2	0	0	4.889597876681885	
i 1	544.9843469387755	0.2525	72	205	6	3	13	2	0	1	2	0	0	4.889597876681885	
i 1	545.2311360544218	0.2525	77	205	6	9	10	16	0	2	16	0	0	3.889597876681885	
i 1	545.2319387755102	0.2525	74	907	6	5	5	2	0	-2	2	0	0	2.5915445024659647	
i 1	545.2343469387755	0.505	77	205	6	1	13	17	0	1	17	0	0	2.0	
i 1	545.2391632653062	2.7775	75	907	4	2	8	2	0	1	2	0	0	4.889597876681885	
i 1	545.4859523809524	0.505	71	205	4	5	3	8	0	-1	8	0	0	2.5915445024659647	
i 1	545.4947823129252	0.2525	69	205	5	5	14	0	0	0	0	0	0	2.5915445024659647	
i 1	545.5196666666667	0.2525	69	591	6	1	12	0	0	-1	0	0	0	2.0	
i 1	545.7399659863945	0.505	69	591	4	24	4	1	0	0	1	0	0	3.0	
i 1	545.7471904761904	2.2725	74	205	6	9	4	16	0	1	16	0	0	3.889597876681885	
i 1	545.9899659863945	1.7675	69	205	5	5	10	0	0	0	0	0	0	2.5915445024659647	
i 1	545.9987959183674	1.7675	74	907	6	5	9	2	0	-2	2	0	0	2.5915445024659647	
i 1	546.2391632653062	0.2525	72	205	5	24	2	1	0	0	1	0	0	3.0	
i 1	546.5036122448979	0.2525	77	205	6	1	5	17	0	1	17	0	0	2.0	
i 1	546.5188639455782	0.505	72	205	6	3	3	2	0	1	2	0	0	4.889597876681885	
i 1	546.7415714285714	0.505	72	591	4	3	13	2	0	-2	2	0	0	4.889597876681885	
i 1	546.7439795918367	20.4525	60	907	5	14	11	0	0	1	0	0	0	2.6591100107384555	
i 1	546.7528095238096	6.8175	60	591	5	25	16	5	0	0	5	0	0	1.721643542311956	
i 1	546.7616394557823	0.2525	71	205	4	5	6	8	0	-1	8	0	0	2.5915445024659647	
i 1	546.764850340136	27.27	60	205	4	27	11	5	0	1	5	0	0	3.4432870846239125	
i 1	546.7688639455782	13.635	67	591	4	7	4	0	0	0	0	0	0	1.9090269580453596	
i 1	546.9811360544218	2.2725	71	205	4	5	3	2	0	-1	2	0	0	2.5915445024659647	
i 1	547.0076258503401	0.2525	70	205	2	24	7	2	0	-2	2	0	0	4.0	
i 1	547.0124421768708	1.5150000000000001	70	205	3	24	2	2	0	-2	2	0	0	4.0	
i 1	547.2327414965987	1.01	72	907	4	2	13	8	0	-2	8	0	0	4.889597876681885	
i 1	547.2463877551021	0.2525	73	591	3	24	15	2	0	-2	2	0	0	4.0	
i 1	547.2512040816326	1.01	72	205	6	3	7	2	0	1	2	0	0	4.889597876681885	
i 1	547.2608367346938	2.02	74	907	6	5	13	2	0	-2	2	0	0	2.5915445024659647	
i 1	547.4939795918367	0.7575000000000001	73	205	2	24	5	2	0	-1	2	0	0	4.0	
i 1	547.5020068027211	2.02	75	205	5	4	5	2	0	-2	2	0	0	4.889597876681885	
i 1	547.516455782313	5.3025	72	591	4	3	9	2	0	-2	2	0	0	4.889597876681885	
i 1	547.7584285714286	0.2525	74	591	6	5	4	8	0	-1	8	0	0	2.5915445024659647	
i 1	547.990768707483	0.2525	69	205	5	5	10	0	0	0	0	0	0	2.5915445024659647	
i 1	547.9955850340136	0.2525	72	205	5	1	3	0	0	0	0	0	0	2.0	
i 1	548.235149659864	0.2525	70	591	3	24	2	8	0	-1	8	0	0	4.0	
i 1	548.2359523809524	0.2525	72	205	7	5	2	0	0	0	0	0	0	2.5915445024659647	
i 1	548.2391632653062	1.5150000000000001	73	205	4	24	11	16	0	1	16	0	0	4.0	
i 1	548.2504013605442	0.2525	74	591	6	5	12	8	0	-1	8	0	0	2.5915445024659647	
i 1	548.2520068027211	0.505	75	907	4	2	4	2	0	1	2	0	0	4.889597876681885	
i 1	548.264850340136	0.2525	77	205	6	1	11	17	0	1	17	0	0	2.0	
i 1	548.4827414965987	3.2825	69	591	6	1	12	0	0	-1	0	0	0	2.0	
i 1	548.4987959183674	5.555	72	205	5	24	14	1	0	0	1	0	0	3.0	
i 1	548.5036122448979	1.7675	69	205	5	5	14	0	0	0	0	0	0	2.5915445024659647	
i 1	548.5196666666667	1.7675	77	205	6	9	6	16	0	2	16	0	0	3.889597876681885	
i 1	548.7479931972789	0.505	70	205	2	24	13	8	0	-1	8	0	0	4.0	
i 1	548.7640476190476	1.5150000000000001	74	907	6	5	14	2	0	-2	2	0	0	2.5915445024659647	
i 1	548.9859523809524	0.2525	72	907	6	1	6	0	0	-1	0	0	0	2.0	
i 1	548.9939795918367	1.2625	75	591	4	4	13	8	0	-2	8	0	0	4.889597876681885	
i 1	549.2367551020408	0.2525	77	205	6	1	7	17	0	1	17	0	0	2.0	
i 1	549.2399659863945	0.2525	71	591	6	5	3	2	0	-1	2	0	0	2.5915445024659647	
i 1	549.240768707483	0.2525	73	591	3	24	1	2	0	-2	2	0	0	4.0	
i 1	549.264850340136	1.7675	70	205	3	24	11	2	0	-2	2	0	0	4.0	
i 1	549.4931768707482	1.2625	69	907	6	1	2	1	0	0	1	0	0	2.0	
i 1	549.4947823129252	0.2525	74	205	6	9	9	16	0	1	16	0	0	3.889597876681885	
i 1	549.5116394557823	0.2525	71	205	4	5	8	8	0	-1	8	0	0	2.5915445024659647	
i 1	549.5180612244898	1.01	73	205	2	24	9	8	0	-1	8	0	0	4.0	
i 1	549.7303333333333	3.0300000000000002	75	205	5	4	13	2	0	-2	2	0	0	4.889597876681885	
i 1	549.7584285714286	1.01	74	907	6	5	8	2	0	-2	2	0	0	2.5915445024659647	
i 1	549.759231292517	1.01	77	205	6	1	8	16	0	1	16	0	0	2.0	
i 1	549.7696666666667	1.01	71	205	4	5	7	2	0	-1	2	0	0	2.5915445024659647	
i 1	549.9899659863945	0.7575000000000001	73	205	4	24	13	16	0	1	16	0	0	4.0	
i 1	550.2303333333333	2.2725	71	205	4	5	10	8	0	-1	8	0	0	2.5915445024659647	
i 1	550.233544217687	2.02	74	591	6	5	11	8	0	-1	8	0	0	2.5915445024659647	
i 1	550.2479931972789	0.2525	75	907	4	2	6	2	0	1	2	0	0	4.889597876681885	
i 1	550.4963877551021	0.2525	75	591	4	4	5	8	0	-2	8	0	0	4.889597876681885	
i 1	550.5124421768708	0.2525	73	591	3	24	8	8	0	-2	8	0	0	4.0	
i 1	550.7479931972789	0.505	72	205	6	3	16	2	0	1	2	0	0	4.889597876681885	
i 1	550.7495986394558	0.2525	72	907	6	1	11	0	0	-1	0	0	0	2.0	
i 1	550.7504013605442	0.505	73	205	2	24	12	2	0	-1	2	0	0	4.0	
i 1	550.7584285714286	0.7575000000000001	69	205	5	5	10	0	0	0	0	0	0	2.5915445024659647	
i 1	550.9939795918367	0.2525	75	907	4	2	13	2	0	1	2	0	0	4.889597876681885	
i 1	550.9971904761904	1.7675	69	907	6	1	12	1	0	0	1	0	0	2.0	
i 1	551.0028095238096	2.525	73	205	4	24	14	16	0	1	16	0	0	4.0	
i 1	551.0132448979592	1.7675	77	205	6	1	14	16	0	1	16	0	0	2.0	
i 1	551.2576258503401	2.2725	70	205	3	24	15	2	0	-2	2	0	0	4.0	
i 1	551.266455782313	0.2525	73	591	3	24	8	2	0	-2	2	0	0	4.0	
i 1	551.2696666666667	0.505	77	205	6	9	2	16	0	2	16	0	0	3.889597876681885	
i 1	551.4955850340136	2.02	74	907	6	5	13	2	0	-2	2	0	0	2.5915445024659647	
i 1	551.4963877551021	0.2525	73	205	2	24	1	2	0	-2	2	0	0	4.0	
i 1	551.5156530612245	0.505	72	907	4	2	2	8	0	-2	8	0	0	4.889597876681885	
i 1	551.7375578231292	0.2525	69	591	4	24	7	1	0	0	1	0	0	3.0	
i 1	551.7688639455782	1.7675	69	205	5	5	11	0	0	0	0	0	0	2.5915445024659647	
i 1	551.9955850340136	1.5150000000000001	69	591	6	1	1	0	0	-1	0	0	0	2.0	
i 1	551.9987959183674	0.2525	77	205	6	9	6	16	0	2	16	0	0	3.889597876681885	
i 1	552.2343469387755	2.02	75	907	4	2	14	2	0	1	2	0	0	4.889597876681885	
i 1	552.2656530612245	2.02	74	205	6	9	2	16	0	1	16	0	0	3.889597876681885	
i 1	552.4995986394558	1.2625	71	591	6	5	13	2	0	-1	2	0	0	2.5915445024659647	
i 1	552.7439795918367	0.2525	70	205	2	24	15	8	0	-2	8	0	0	4.0	
i 1	552.7608367346938	0.7575000000000001	72	205	7	5	16	0	0	0	0	0	0	2.5915445024659647	
i 1	552.7632448979592	0.505	75	591	4	4	4	8	0	-2	8	0	0	4.889597876681885	
i 1	552.764850340136	0.2525	72	205	5	1	8	0	0	0	0	0	0	2.0	
i 1	552.9819387755102	4.2925	77	205	6	1	2	16	0	1	16	0	0	2.0	
i 1	553.264850340136	0.2525	77	205	6	9	4	16	0	2	16	0	0	3.889597876681885	
i 1	553.2672585034013	0.2525	73	591	3	24	4	2	0	-2	2	0	0	4.0	
i 1	553.4803333333333	27.27	67	205	4	27	1	0	0	0	0	0	0	3.4432870846239125	
i 1	553.4987959183674	0.505	69	591	6	1	14	0	0	-1	0	0	0	2.0	
i 1	553.4987959183674	4.545	69	205	7	5	14	0	0	0	0	0	0	2.5915445024659647	
i 1	553.5004013605442	2.2725	73	205	3	24	2	16	0	1	16	0	0	4.0	
i 1	553.5036122448979	4.545	74	907	6	5	9	2	0	-2	2	0	0	2.5915445024659647	
i 1	553.5060204081633	1.5150000000000001	72	907	4	2	3	8	0	-2	8	0	0	4.889597876681885	
i 1	553.5068231292518	3.2825	70	205	2	24	7	8	0	-1	8	0	0	4.0	
i 1	553.5076258503401	20.4525	60	591	5	13	13	5	0	1	5	0	0	0.40886085265916766	
i 1	553.5140476190476	3.7875	69	907	6	1	5	1	0	0	1	0	0	2.0	
i 1	553.5196666666667	6.8175	60	591	5	25	2	5	0	0	5	0	0	1.721643542311956	
i 1	553.7544149659864	0.505	71	205	4	5	2	8	0	-1	8	0	0	2.5915445024659647	
i 1	553.7560204081633	1.2625	72	205	6	3	4	2	0	1	2	0	0	4.889597876681885	
i 1	553.9931768707482	0.2525	69	591	4	24	8	1	0	0	1	0	0	3.0	
i 1	554.235149659864	0.2525	74	907	6	5	5	2	0	-2	2	0	0	2.5915445024659647	
i 1	554.2688639455782	0.2525	75	591	4	4	16	8	0	-2	8	0	0	4.889597876681885	
i 1	554.2696666666667	0.2525	72	907	6	1	3	0	0	-1	0	0	0	2.0	
i 1	554.4803333333333	0.505	72	205	7	5	7	0	0	0	0	0	0	2.5915445024659647	
i 1	554.5076258503401	1.5150000000000001	75	205	5	4	2	2	0	-2	2	0	0	4.889597876681885	
i 1	554.514850340136	1.5150000000000001	72	591	4	3	6	2	0	-2	2	0	0	4.889597876681885	
i 1	555.0052176870748	0.2525	71	205	4	5	16	2	0	-1	2	0	0	2.5915445024659647	
i 1	555.0196666666667	0.2525	75	591	4	4	15	8	0	-2	8	0	0	4.889597876681885	
i 1	555.2528095238096	0.2525	74	205	6	9	11	16	0	1	16	0	0	3.889597876681885	
i 1	555.2528095238096	3.0300000000000002	70	205	3	24	5	2	0	-2	2	0	0	4.0	
i 1	555.266455782313	0.2525	71	205	4	5	13	8	0	-1	8	0	0	2.5915445024659647	
i 1	555.4883605442177	1.01	74	907	6	5	11	2	0	-2	2	0	0	2.5915445024659647	
i 1	555.5116394557823	1.5150000000000001	75	591	4	4	14	8	0	-2	8	0	0	4.889597876681885	
i 1	555.5140476190476	1.01	71	205	4	5	3	2	0	-1	2	0	0	2.5915445024659647	
i 1	555.516455782313	1.2625	77	205	6	9	2	16	0	2	16	0	0	3.889597876681885	
i 1	555.7528095238096	0.2525	69	591	4	24	5	1	0	0	1	0	0	3.0	
i 1	556.0076258503401	0.2525	75	907	4	2	7	2	0	1	2	0	0	4.889597876681885	
i 1	556.2439795918367	0.2525	69	591	4	24	10	1	0	0	1	0	0	3.0	
i 1	556.2447823129252	2.7775	72	591	4	3	12	2	0	-2	2	0	0	4.889597876681885	
i 1	556.2560204081633	2.7775	75	205	5	4	2	2	0	-2	2	0	0	4.889597876681885	
i 1	556.2688639455782	0.7575000000000001	73	205	3	24	5	16	0	1	16	0	0	4.0	
i 1	556.514850340136	1.7675	72	205	5	24	3	1	0	0	1	0	0	3.0	
i 1	556.5188639455782	0.2525	71	205	4	5	4	8	0	-1	8	0	0	2.5915445024659647	
i 1	556.733544217687	1.2625	69	591	6	1	9	0	0	-1	0	0	0	2.0	
i 1	556.7367551020408	0.2525	74	591	6	5	5	8	0	-1	8	0	0	2.5915445024659647	
i 1	556.9987959183674	0.2525	77	205	6	9	15	16	0	2	16	0	0	3.889597876681885	
i 1	557.233544217687	0.2525	72	205	5	1	3	0	0	0	0	0	0	2.0	
i 1	557.2455850340136	0.2525	71	205	4	5	14	8	0	-1	8	0	0	2.5915445024659647	
i 1	557.2576258503401	0.2525	75	591	4	4	3	8	0	-2	8	0	0	4.889597876681885	
i 1	557.4811360544218	1.5150000000000001	74	907	6	5	2	2	0	-2	2	0	0	2.5915445024659647	
i 1	557.490768707483	1.5150000000000001	77	205	6	1	7	16	0	1	16	0	0	2.0	
i 1	557.5076258503401	1.5150000000000001	71	205	4	5	9	2	0	-1	2	0	0	2.5915445024659647	
i 1	557.5188639455782	1.5150000000000001	69	907	6	1	5	1	0	0	1	0	0	2.0	
i 1	557.7311360544218	1.2625	73	205	3	24	6	16	0	1	16	0	0	4.0	
i 1	557.7512040816326	0.2525	77	205	6	9	10	16	0	2	16	0	0	3.889597876681885	
i 1	557.7536122448979	0.2525	73	591	3	24	7	8	0	-1	8	0	0	4.0	
i 1	558.0044149659864	0.505	73	205	2	24	15	2	0	-2	2	0	0	4.0	
i 1	558.0196666666667	0.2525	72	205	7	5	5	0	0	0	0	0	0	2.5915445024659647	
i 1	558.2544149659864	0.2525	72	907	4	2	8	8	0	-2	8	0	0	4.889597876681885	
i 1	558.259231292517	0.2525	69	205	7	5	9	0	0	0	0	0	0	2.5915445024659647	
i 1	558.2616394557823	2.2725	69	591	6	1	12	0	0	-1	0	0	0	2.0	
i 1	558.4931768707482	2.2725	74	205	6	9	4	16	0	1	16	0	0	3.889597876681885	
i 1	558.5028095238096	2.2725	75	907	4	2	16	2	0	1	2	0	0	4.889597876681885	
i 1	558.509231292517	0.2525	70	591	3	24	9	2	0	-2	2	0	0	4.0	
i 1	558.509231292517	1.5150000000000001	70	205	3	24	1	2	0	-2	2	0	0	4.0	
i 1	558.514850340136	2.02	72	205	5	24	2	1	0	0	1	0	0	3.0	
i 1	558.516455782313	1.2625	74	591	6	5	14	8	0	-1	8	0	0	2.5915445024659647	
i 1	558.5188639455782	0.7575000000000001	71	205	4	5	3	8	0	-1	8	0	0	2.5915445024659647	
i 1	558.7471904761904	0.2525	70	205	2	24	11	2	0	-1	2	0	0	4.0	
i 1	558.7536122448979	2.02	74	907	6	5	11	2	0	-2	2	0	0	2.5915445024659647	
i 1	558.7584285714286	2.02	69	205	7	5	2	0	0	0	0	0	0	2.5915445024659647	
i 1	558.9987959183674	0.2525	72	205	6	3	12	2	0	1	2	0	0	4.889597876681885	
i 1	559.0052176870748	0.505	72	907	6	1	14	0	0	-1	0	0	0	2.0	
i 1	559.2319387755102	0.2525	72	591	4	3	5	2	0	-2	2	0	0	4.889597876681885	
i 1	559.4811360544218	2.525	77	205	6	1	2	16	0	1	16	0	0	2.0	
i 1	559.5140476190476	3.535	73	205	3	24	2	16	0	1	16	0	0	4.0	
i 1	559.7303333333333	0.2525	77	205	6	9	8	16	0	2	16	0	0	3.889597876681885	
i 1	559.7415714285714	0.505	71	205	4	5	4	8	0	-1	8	0	0	2.5915445024659647	
i 1	560.0036122448979	1.7675	72	205	6	3	12	2	0	1	2	0	0	4.889597876681885	
i 1	560.0108367346938	2.02	69	907	6	1	10	1	0	0	1	0	0	2.0	
i 1	560.2343469387755	1.2625	72	907	4	2	4	8	0	-2	8	0	0	4.889597876681885	
i 1	560.2463877551021	6.8175	61	205	5	26	3	9	0	1	9	0	0	1.721643542311956	
i 1	560.2479931972789	20.4525	67	591	6	7	10	0	0	0	0	0	0	1.9090269580453596	
i 1	560.2560204081633	1.5150000000000001	72	205	7	5	13	0	0	0	0	0	0	2.5915445024659647	
i 1	560.2624421768708	6.8175	67	907	5	14	11	5	0	0	5	0	0	2.6591100107384555	
i 1	560.266455782313	2.2725	71	591	6	5	2	2	0	-1	2	0	0	2.5915445024659647	
i 1	560.4843469387755	0.505	69	591	4	24	4	1	0	0	1	0	0	3.0	
i 1	560.7431768707482	0.2525	71	205	4	5	12	8	0	-1	8	0	0	2.5915445024659647	
i 1	560.7512040816326	3.2825	70	205	3	24	9	2	0	-2	2	0	0	4.0	
i 1	560.7568231292518	0.2525	77	205	4	9	11	16	0	2	16	0	0	3.889597876681885	
i 1	560.9843469387755	4.545	72	591	4	3	7	2	0	-2	2	0	0	4.889597876681885	
i 1	560.9859523809524	4.545	75	205	5	4	7	2	0	-2	2	0	0	4.889597876681885	
i 1	561.0060204081633	2.2725	72	205	5	24	14	1	0	0	1	0	0	3.0	
i 1	561.0172585034013	2.7775	69	205	7	5	14	0	0	0	0	0	0	2.5915445024659647	
i 1	561.2680612244898	2.525	74	907	6	5	4	2	0	-2	2	0	0	2.5915445024659647	
i 1	561.5044149659864	1.7675	69	591	6	1	11	0	0	-1	0	0	0	2.0	
i 1	561.7383605442177	0.7575000000000001	77	205	4	9	12	16	0	2	16	0	0	3.889597876681885	
i 1	561.7487959183674	0.7575000000000001	75	591	4	4	7	8	0	-2	8	0	0	4.889597876681885	
i 1	561.9939795918367	0.7575000000000001	72	907	6	1	1	0	0	-1	0	0	0	2.0	
i 1	562.5060204081633	0.505	71	205	4	5	4	8	0	-1	8	0	0	2.5915445024659647	
i 1	562.5156530612245	0.2525	72	907	4	2	16	8	0	-2	8	0	0	4.889597876681885	
i 1	562.7303333333333	0.2525	72	205	6	3	12	2	0	1	2	0	0	4.889597876681885	
i 1	562.7439795918367	2.7775	77	205	6	1	8	16	0	1	16	0	0	2.0	
i 1	562.7512040816326	3.0300000000000002	69	907	6	1	6	1	0	0	1	0	0	2.0	
i 1	562.9955850340136	3.535	71	205	6	5	12	2	0	-1	2	0	0	2.5915445024659647	
i 1	563.2520068027211	3.2825	74	907	6	5	5	2	0	-2	2	0	0	2.5915445024659647	
i 1	563.2584285714286	0.2525	69	591	4	24	15	1	0	0	1	0	0	3.0	
i 1	563.2608367346938	0.505	73	205	2	24	9	2	0	-1	2	0	0	4.0	
i 1	563.490768707483	1.01	73	205	3	24	1	16	0	1	16	0	0	4.0	
i 1	563.5028095238096	0.2525	77	205	4	9	3	16	0	2	16	0	0	3.889597876681885	
i 1	563.5132448979592	0.2525	72	205	5	24	6	1	0	0	1	0	0	3.0	
i 1	563.7415714285714	0.2525	71	591	6	5	1	2	0	-1	2	0	0	2.5915445024659647	
i 1	563.7504013605442	0.2525	70	591	3	24	12	8	0	-1	8	0	0	4.0	
i 1	563.7608367346938	0.505	75	591	4	4	6	8	0	-2	8	0	0	4.889597876681885	
i 1	563.9979931972789	0.2525	73	205	2	24	10	8	0	-2	8	0	0	4.0	
i 1	564.0100340136055	0.2525	72	205	7	5	9	0	0	0	0	0	0	2.5915445024659647	
i 1	564.2568231292518	0.7575000000000001	74	907	6	5	2	2	0	-2	2	0	0	2.5915445024659647	
i 1	564.2608367346938	1.2625	70	205	3	24	9	2	0	-2	2	0	0	4.0	
i 1	564.264850340136	1.2625	69	205	7	5	15	0	0	0	0	0	0	2.5915445024659647	
i 1	564.2696666666667	0.2525	77	205	4	9	9	16	0	2	16	0	0	3.889597876681885	
i 1	564.5108367346938	0.505	72	205	6	3	16	2	0	1	2	0	0	4.889597876681885	
i 1	564.7520068027211	0.2525	69	591	4	24	9	1	0	0	1	0	0	3.0	
i 1	564.9811360544218	2.02	75	907	4	2	4	2	0	1	2	0	0	4.889597876681885	
i 1	564.9883605442177	2.02	74	205	6	9	9	16	0	1	16	0	0	3.889597876681885	
i 1	564.9971904761904	2.02	72	205	5	24	8	1	0	0	1	0	0	3.0	
i 1	565.0068231292518	3.7875	73	205	3	24	5	16	0	1	16	0	0	4.0	
i 1	565.014850340136	2.525	69	591	6	1	15	0	0	-1	0	0	0	2.0	
i 1	565.4811360544218	0.2525	74	591	6	5	8	8	0	-1	8	0	0	2.5915445024659647	
i 1	565.483544217687	0.2525	72	907	4	2	6	8	0	-2	8	0	0	4.889597876681885	
i 1	565.735149659864	0.2525	72	205	6	3	9	2	0	1	2	0	0	4.889597876681885	
i 1	565.740768707483	1.2625	71	205	4	5	15	8	0	-1	8	0	0	2.5915445024659647	
i 1	565.7479931972789	0.2525	77	205	6	1	5	17	0	1	17	0	0	2.0	
i 1	565.9803333333333	0.7575000000000001	70	205	3	24	2	2	0	-2	2	0	0	4.0	
i 1	565.9915714285714	0.2525	69	907	6	1	12	1	0	0	1	0	0	2.0	
i 1	565.9915714285714	1.01	74	591	6	5	13	8	0	-1	8	0	0	2.5915445024659647	
i 1	566.2552176870748	2.525	70	205	2	24	16	8	0	-2	8	0	0	4.0	
i 1	566.2568231292518	0.2525	75	591	4	4	6	8	0	-2	8	0	0	4.889597876681885	
i 1	566.2640476190476	0.2525	69	591	4	24	2	1	0	0	1	0	0	3.0	
i 1	566.4899659863945	2.2725	77	205	6	1	1	16	0	1	16	0	0	2.0	
i 1	566.4915714285714	0.7575000000000001	72	205	6	3	9	2	0	1	2	0	0	4.889597876681885	
i 1	566.4947823129252	0.2525	71	591	6	5	13	2	0	-1	2	0	0	2.5915445024659647	
i 1	566.4979931972789	2.02	69	907	6	1	8	1	0	0	1	0	0	2.0	
i 1	566.5156530612245	0.7575000000000001	72	907	4	2	5	8	0	-2	8	0	0	4.889597876681885	
i 1	566.7552176870748	1.7675	75	205	5	4	15	2	0	-2	2	0	0	4.889597876681885	
i 1	566.7632448979592	0.2525	74	907	6	5	16	2	0	-2	2	0	0	2.5915445024659647	
i 1	566.7640476190476	1.7675	72	591	4	3	7	2	0	-2	2	0	0	4.889597876681885	
i 1	566.9827414965987	1.01	69	205	7	5	15	0	0	0	0	0	0	2.5915445024659647	
i 1	566.983544217687	0.505	71	205	6	5	16	8	0	-1	8	0	0	2.5915445024659647	
i 1	566.990768707483	6.8175	61	205	5	26	15	6	0	1	6	0	0	1.721643542311956	
i 1	566.9915714285714	14.645	67	907	3	14	2	5	0	0	5	0	0	2.6591100107384555	
i 1	566.9931768707482	0.505	74	591	6	5	15	8	0	-1	8	0	0	2.5915445024659647	
i 1	566.9979931972789	1.01	74	907	6	5	11	2	0	-2	2	0	0	2.5915445024659647	
i 1	566.9995986394558	6.8175	60	907	5	14	3	0	0	1	0	0	0	2.6591100107384555	
i 1	567.2576258503401	0.2525	75	591	4	4	8	8	0	-2	8	0	0	4.889597876681885	
i 1	567.483544217687	2.2725	72	205	7	5	2	0	0	0	0	0	0	2.5915445024659647	
i 1	567.4955850340136	0.2525	74	205	4	9	12	16	0	1	16	0	0	3.889597876681885	
i 1	567.5084285714286	0.2525	77	205	7	1	7	17	0	1	17	0	0	2.0	
i 1	567.514850340136	2.02	71	591	6	5	16	2	0	-1	2	0	0	2.5915445024659647	
i 1	567.7423741496599	0.2525	69	591	4	24	1	1	0	0	1	0	0	3.0	
i 1	567.7624421768708	1.5150000000000001	77	205	4	9	12	16	0	2	16	0	0	3.889597876681885	
i 1	567.9931768707482	3.0300000000000002	69	591	6	1	2	0	0	-1	0	0	0	2.0	
i 1	568.0036122448979	3.0300000000000002	72	205	5	24	9	1	0	0	1	0	0	3.0	
i 1	568.0044149659864	1.2625	75	591	4	4	13	8	0	-2	8	0	0	4.889597876681885	
i 1	568.009231292517	0.2525	74	591	6	5	14	8	0	-1	8	0	0	2.5915445024659647	
i 1	568.240768707483	0.2525	74	907	6	5	4	2	0	-2	2	0	0	2.5915445024659647	
i 1	568.2487959183674	1.2625	70	205	2	24	4	2	0	-2	2	0	0	4.0	
i 1	568.5140476190476	0.2525	75	907	4	2	3	2	0	1	2	0	0	4.889597876681885	
i 1	568.5140476190476	0.2525	71	205	6	5	1	2	0	-1	2	0	0	2.5915445024659647	
i 1	568.7439795918367	3.0300000000000002	72	591	4	3	11	2	0	-2	2	0	0	4.889597876681885	
i 1	568.7512040816326	0.2525	69	591	4	24	5	1	0	0	1	0	0	3.0	
i 1	568.7576258503401	0.2525	70	591	3	24	6	8	0	-1	8	0	0	4.0	
i 1	568.7584285714286	2.2725	74	907	6	5	16	2	0	-2	2	0	0	2.5915445024659647	
i 1	568.7608367346938	3.535	75	205	5	4	9	2	0	-2	2	0	0	4.889597876681885	
i 1	568.9827414965987	1.5150000000000001	73	205	3	24	9	16	0	1	16	0	0	4.0	
i 1	569.009231292517	0.2525	72	907	6	1	6	0	0	-1	0	0	0	2.0	
i 1	569.0140476190476	1.7675	69	205	7	5	8	0	0	0	0	0	0	2.5915445024659647	
i 1	569.2383605442177	1.01	77	205	6	1	14	16	0	1	16	0	0	2.0	
i 1	569.259231292517	5.8075	69	907	6	1	10	1	0	0	1	0	0	2.0	
i 1	569.266455782313	0.2525	75	907	4	2	12	2	0	1	2	0	0	4.889597876681885	
i 1	569.5116394557823	0.2525	75	591	4	4	13	8	0	-2	8	0	0	4.889597876681885	
i 1	569.7303333333333	0.505	74	205	4	9	3	16	0	1	16	0	0	3.889597876681885	
i 1	569.7383605442177	0.2525	70	205	2	24	10	8	0	-1	8	0	0	4.0	
i 1	569.759231292517	0.2525	71	205	6	5	12	2	0	-1	2	0	0	2.5915445024659647	
i 1	569.9963877551021	0.2525	73	591	3	24	7	8	0	-1	8	0	0	4.0	
i 1	570.0044149659864	0.2525	74	591	6	5	4	8	0	-1	8	0	0	2.5915445024659647	
i 1	570.0180612244898	5.05	70	205	2	24	10	2	0	-2	2	0	0	4.0	
i 1	570.2311360544218	0.2525	75	591	4	4	1	8	0	-2	8	0	0	4.889597876681885	
i 1	570.235149659864	2.02	70	205	2	24	4	2	0	-1	2	0	0	4.0	
i 1	570.2375578231292	2.02	74	907	6	5	15	2	0	-2	2	0	0	2.5915445024659647	
i 1	570.2447823129252	2.02	71	205	6	5	6	2	0	-1	2	0	0	2.5915445024659647	
i 1	570.4995986394558	3.2825	77	205	6	1	11	16	0	1	16	0	0	2.0	
i 1	570.514850340136	0.2525	77	205	4	9	12	16	0	2	16	0	0	3.889597876681885	
i 1	570.9811360544218	0.2525	72	907	4	2	13	8	0	-2	8	0	0	4.889597876681885	
i 1	570.9971904761904	0.505	72	205	5	1	1	0	0	0	0	0	0	2.0	
i 1	571.0100340136055	0.2525	71	591	6	5	3	2	0	-1	2	0	0	2.5915445024659647	
i 1	571.2391632653062	2.02	74	205	4	9	9	16	0	1	16	0	0	3.889597876681885	
i 1	571.2528095238096	2.02	74	907	6	5	6	2	0	-2	2	0	0	2.5915445024659647	
i 1	571.264850340136	2.02	75	907	4	2	6	2	0	1	2	0	0	4.889597876681885	
i 1	571.509231292517	0.2525	72	205	5	24	1	1	0	0	1	0	0	3.0	
i 1	571.7624421768708	0.2525	69	591	4	24	5	1	0	0	1	0	0	3.0	
i 1	571.7656530612245	1.5150000000000001	69	205	7	5	7	0	0	0	0	0	0	2.5915445024659647	
i 1	572.2327414965987	1.01	73	205	3	24	11	16	0	1	16	0	0	4.0	
i 1	572.2528095238096	0.2525	72	907	6	1	9	0	0	-1	0	0	0	2.0	
i 1	572.2536122448979	0.2525	71	205	6	5	10	8	0	-1	8	0	0	2.5915445024659647	
i 1	572.2560204081633	0.2525	72	591	4	3	7	2	0	-2	2	0	0	4.889597876681885	
i 1	572.2680612244898	0.2525	70	591	3	24	16	8	0	-1	8	0	0	4.0	
i 1	572.483544217687	1.2625	72	205	6	3	16	2	0	1	2	0	0	4.889597876681885	
i 1	572.5076258503401	0.2525	73	205	2	24	5	2	0	-2	2	0	0	4.0	
i 1	572.5132448979592	0.505	72	205	5	24	13	1	0	0	1	0	0	3.0	
i 1	572.5196666666667	1.2625	71	205	6	5	8	2	0	-1	2	0	0	2.5915445024659647	
i 1	572.7447823129252	1.2625	72	907	4	2	12	8	0	-2	8	0	0	4.889597876681885	
i 1	572.7640476190476	1.01	74	907	6	5	4	2	0	-2	2	0	0	2.5915445024659647	
i 1	573.0036122448979	0.505	69	591	6	1	16	0	0	-1	0	0	0	2.0	
i 1	573.0188639455782	0.2525	70	205	2	24	5	2	0	-2	2	0	0	4.0	
i 1	573.2463877551021	2.02	74	591	6	5	5	8	0	-1	8	0	0	2.5915445024659647	
i 1	573.2536122448979	2.02	71	205	6	5	2	8	0	-1	8	0	0	2.5915445024659647	
i 1	573.2696666666667	1.7675	72	591	4	3	9	2	0	-2	2	0	0	4.889597876681885	
i 1	573.4955850340136	0.2525	77	205	7	1	8	17	0	1	17	0	0	2.0	
i 1	573.514850340136	1.5150000000000001	75	205	5	4	7	2	0	-2	2	0	0	4.889597876681885	
i 1	573.7311360544218	0.505	69	205	7	5	3	0	0	0	0	0	0	2.5915445024659647	
i 1	573.7463877551021	6.8175	60	205	4	27	5	5	0	1	5	0	0	3.4432870846239125	
i 1	573.7471904761904	1.2625	77	205	7	1	13	16	0	1	16	0	0	2.0	
i 1	573.7520068027211	0.2525	72	205	5	24	12	1	0	0	1	0	0	3.0	
i 1	573.7528095238096	0.2525	72	205	3	3	16	2	0	1	2	0	0	4.889597876681885	
i 1	573.7528095238096	6.8175	60	591	5	13	5	5	0	1	5	0	0	0.40886085265916766	
i 1	573.7672585034013	7.8275	60	907	3	14	10	0	0	1	0	0	0	2.6591100107384555	
i 1	574.0060204081633	2.02	77	205	4	9	8	16	0	2	16	0	0	3.889597876681885	
i 1	574.2536122448979	0.2525	77	205	7	1	8	17	0	1	17	0	0	2.0	
i 1	574.2608367346938	0.2525	74	907	6	5	14	2	0	-2	2	0	0	2.5915445024659647	
i 1	574.4843469387755	0.2525	73	591	3	24	6	8	0	-2	8	0	0	4.0	
i 1	574.4867551020408	3.0300000000000002	72	205	5	24	8	1	0	0	1	0	0	3.0	
i 1	574.4875578231292	1.2625	75	591	4	4	2	8	0	-2	8	0	0	4.889597876681885	
i 1	574.4899659863945	6.565	74	907	6	5	14	2	0	-2	2	0	0	2.5915445024659647	
i 1	574.5012040816326	3.0300000000000002	69	591	6	1	8	0	0	-1	0	0	0	2.0	
i 1	574.7303333333333	6.3125	69	205	7	5	13	0	0	0	0	0	0	2.5915445024659647	
i 1	574.7367551020408	0.7575000000000001	70	205	2	24	16	2	0	-1	2	0	0	4.0	
i 1	575.0060204081633	0.2525	69	591	4	24	6	1	0	0	1	0	0	3.0	
i 1	575.0068231292518	0.2525	75	907	4	2	1	2	0	1	2	0	0	4.889597876681885	
i 1	575.2423741496599	2.7775	72	591	4	3	16	2	0	-2	2	0	0	4.889597876681885	
i 1	575.2439795918367	3.0300000000000002	75	205	5	4	9	2	0	-2	2	0	0	4.889597876681885	
i 1	575.2520068027211	0.505	72	205	5	1	7	0	0	0	0	0	0	2.0	
i 1	575.2560204081633	0.2525	71	591	6	5	15	2	0	-1	2	0	0	2.5915445024659647	
i 1	575.2584285714286	0.7575000000000001	70	205	2	24	13	2	0	-2	2	0	0	4.0	
i 1	575.2616394557823	1.7675	73	205	3	24	8	16	0	1	16	0	0	4.0	
i 1	575.4819387755102	0.2525	74	591	6	5	7	8	0	-1	8	0	0	2.5915445024659647	
i 1	575.4819387755102	0.2525	70	591	3	24	3	2	0	-1	2	0	0	4.0	
i 1	575.7359523809524	2.7775	69	907	6	1	9	1	0	0	1	0	0	2.0	
i 1	575.7383605442177	1.01	77	205	7	1	7	16	0	1	16	0	0	2.0	
i 1	575.7439795918367	0.7575000000000001	71	591	6	5	13	2	0	-1	2	0	0	2.5915445024659647	
i 1	575.7520068027211	0.2525	73	205	2	24	14	8	0	-1	8	0	0	4.0	
i 1	575.7616394557823	0.7575000000000001	72	205	7	5	7	0	0	0	0	0	0	2.5915445024659647	
i 1	575.9803333333333	0.2525	72	205	3	3	14	2	0	1	2	0	0	4.889597876681885	
i 1	576.264850340136	0.2525	77	205	4	9	4	16	0	2	16	0	0	3.889597876681885	
i 1	576.5004013605442	1.01	70	205	2	24	16	2	0	-2	2	0	0	4.0	
i 1	576.5012040816326	0.2525	72	907	4	2	9	8	0	-2	8	0	0	4.889597876681885	
i 1	576.5052176870748	0.2525	71	205	6	5	10	8	0	-1	8	0	0	2.5915445024659647	
i 1	576.7479931972789	0.505	75	907	4	2	1	2	0	1	2	0	0	4.889597876681885	
i 1	576.7504013605442	0.2525	73	205	2	24	16	2	0	-2	2	0	0	4.0	
i 1	576.7528095238096	0.2525	71	205	6	5	10	2	0	-1	2	0	0	2.5915445024659647	
i 1	576.9827414965987	0.2525	73	591	3	24	12	2	0	-1	2	0	0	4.0	
i 1	576.9979931972789	1.5150000000000001	77	205	7	1	13	16	0	1	16	0	0	2.0	
i 1	577.2383605442177	1.01	70	205	2	24	6	8	0	-2	8	0	0	4.0	
i 1	577.2479931972789	0.2525	72	907	4	2	7	8	0	-2	8	0	0	4.889597876681885	
i 1	577.4891632653062	2.2725	75	907	4	2	9	2	0	1	2	0	0	4.889597876681885	
i 1	577.4955850340136	0.505	69	591	4	24	15	1	0	0	1	0	0	3.0	
i 1	577.5028095238096	0.2525	71	205	6	5	8	2	0	-1	2	0	0	2.5915445024659647	
i 1	577.5044149659864	2.525	74	205	4	9	7	16	0	1	16	0	0	3.889597876681885	
i 1	577.7463877551021	0.505	74	907	6	5	5	2	0	-2	2	0	0	2.5915445024659647	
i 1	577.9939795918367	2.02	69	591	6	1	3	0	0	-1	0	0	0	2.0	
i 1	577.9947823129252	0.7575000000000001	73	205	3	24	9	16	0	1	16	0	0	4.0	
i 1	578.0132448979592	2.02	72	205	5	24	3	1	0	0	1	0	0	3.0	
i 1	578.2303333333333	1.2625	71	205	6	5	6	2	0	-1	2	0	0	2.5915445024659647	
i 1	578.2319387755102	0.2525	70	591	3	24	7	2	0	-2	2	0	0	4.0	
i 1	578.2327414965987	0.2525	72	205	3	3	2	2	0	1	2	0	0	4.889597876681885	
i 1	578.2504013605442	1.2625	70	205	2	24	15	2	0	-2	2	0	0	4.0	
i 1	578.4819387755102	1.01	74	907	6	5	12	2	0	-2	2	0	0	2.5915445024659647	
i 1	578.4859523809524	0.505	73	205	2	24	2	2	0	-1	2	0	0	4.0	
i 1	578.4875578231292	0.2525	72	205	5	1	5	0	0	0	0	0	0	2.0	
i 1	578.5004013605442	0.2525	75	591	4	4	14	8	0	-2	8	0	0	4.889597876681885	
i 1	578.764850340136	0.505	69	591	4	24	5	1	0	0	1	0	0	3.0	
i 1	578.9915714285714	0.2525	73	591	3	24	14	2	0	-1	2	0	0	4.0	
i 1	579.0052176870748	0.2525	72	591	4	3	8	2	0	-2	2	0	0	4.889597876681885	
i 1	579.2327414965987	1.2625	69	907	6	1	16	1	0	0	1	0	0	2.0	
i 1	579.2343469387755	0.505	73	205	2	24	15	2	0	-1	2	0	0	4.0	
i 1	579.2520068027211	1.2625	72	907	4	2	1	8	0	-2	8	0	0	4.889597876681885	
i 1	579.2672585034013	1.2625	72	205	3	3	10	2	0	1	2	0	0	4.889597876681885	
i 1	579.4923741496599	0.2525	71	591	6	5	16	2	0	-1	2	0	0	2.5915445024659647	
i 1	579.4963877551021	0.7575000000000001	73	205	3	24	13	16	0	1	16	0	0	4.0	
i 1	579.4979931972789	2.02	77	205	7	1	4	16	0	1	16	0	0	2.0	
i 1	579.7343469387755	0.505	74	907	6	5	12	2	0	-2	2	0	0	2.5915445024659647	
i 1	579.7536122448979	1.7675	70	205	2	24	1	2	0	-2	2	0	0	4.0	
i 1	579.7688639455782	0.2525	73	591	3	24	8	2	0	-2	2	0	0	4.0	
i 1	579.9955850340136	0.2525	72	907	6	1	6	0	0	-1	0	0	0	2.0	
i 1	580.0020068027211	0.505	75	205	5	4	6	2	0	-2	2	0	0	4.889597876681885	
i 1	580.0100340136055	1.5150000000000001	70	205	2	24	10	2	0	-1	2	0	0	4.0	
i 1	580.0116394557823	2.7775	72	591	4	3	9	2	0	-2	2	0	0	4.889597876681885	
i 1	580.2423741496599	0.2525	71	205	6	5	2	8	0	-1	8	0	0	2.5915445024659647	
i 1	580.2688639455782	0.2525	69	591	6	1	6	0	0	-1	0	0	0	2.0	
i 1	580.4811360544218	6.8175	67	591	5	7	8	0	0	0	0	0	0	1.9090269580453596	
i 1	580.4827414965987	1.01	71	205	6	5	4	2	0	-1	2	0	0	2.5915445024659647	
i 1	580.485149659864	1.01	74	907	6	5	15	2	0	-2	2	0	0	2.5915445024659647	
i 1	580.490768707483	1.01	77	205	4	9	9	16	0	2	16	0	0	3.889597876681885	
i 1	580.4931768707482	1.01	75	205	3	4	11	2	0	-2	2	0	0	4.889597876681885	
i 1	580.4947823129252	27.27	60	591	3	13	15	5	0	1	5	0	0	0.40886085265916766	
i 1	580.4979931972789	0.505	77	205	7	1	10	17	0	1	17	0	0	2.0	
i 1	580.5140476190476	1.01	69	907	5	1	13	1	0	0	1	0	0	2.0	
i 1	580.514850340136	1.01	67	205	4	27	15	0	0	0	0	0	0	3.4432870846239125	
i 1	580.7568231292518	0.7575000000000001	75	591	4	4	15	8	0	-2	8	0	0	4.889597876681885	
i 1	580.9875578231292	0.2525	72	907	6	1	4	0	0	-1	0	0	0	2.0	
i 1	580.9971904761904	0.2525	71	591	6	5	14	2	0	-1	2	0	0	2.5915445024659647	
i 1	581.2303333333333	0.2525	72	205	7	5	3	0	0	0	0	0	0	2.5915445024659647	
i 1	581.2487959183674	2.7775	69	591	6	1	12	0	0	-1	0	0	0	2.0	
i 1	581.2520068027211	0.2525	72	205	7	1	16	0	0	0	0	0	0	2.0	
i 1	581.2600340136055	0.2525	74	907	6	5	1	2	0	-2	2	0	0	2.5915445024659647	
i 1	581.266455782313	0.2525	72	205	3	3	14	2	0	1	2	0	0	4.889597876681885	
i 1	581.4803333333333	0.2525	74	1089	6	5	3	2	0	-2	2	0	0	2.5915445024659647	
i 1	581.4819387755102	0.2525	72	1089	6	1	13	0	0	-1	0	0	0	2.0	
i 1	581.4819387755102	0.7575000000000001	74	1089	6	5	12	2	0	-2	2	0	0	2.5915445024659647	
i 1	581.483544217687	9.8475	60	1089	3	14	3	5	0	0	5	0	0	2.6591100107384555	
i 1	581.4867551020408	0.505	74	1089	6	5	12	8	0	-1	8	0	0	2.5915445024659647	
i 1	581.4883605442177	5.8075	60	275	4	27	16	5	0	0	5	0	0	3.4432870846239125	
i 1	581.4939795918367	9.8475	60	1089	3	14	11	0	0	0	0	0	0	2.6591100107384555	
i 1	581.4963877551021	0.7575000000000001	72	275	7	1	8	0	0	-1	0	0	0	2.0	
i 1	581.4979931972789	2.02	71	591	6	5	1	2	0	-1	2	0	0	2.5915445024659647	
i 1	581.5028095238096	5.8075	70	1089	2	24	3	8	0	-1	8	0	0	4.0	
i 1	581.5124421768708	1.5150000000000001	69	1089	5	1	9	0	0	-1	0	0	0	2.0	
i 1	581.5140476190476	0.2525	71	275	6	5	15	2	0	-1	2	0	0	2.5915445024659647	
i 1	581.5156530612245	1.01	72	275	3	3	6	8	0	-2	8	0	0	4.889597876681885	
i 1	581.5156530612245	2.2725	71	275	6	5	15	8	0	-2	8	0	0	2.5915445024659647	
i 1	581.5156530612245	0.505	70	275	2	24	7	2	0	-1	2	0	0	4.0	
i 1	581.5172585034013	0.2525	75	275	3	4	3	2	0	1	2	0	0	4.889597876681885	
i 1	581.5188639455782	0.2525	73	591	3	24	14	8	0	-2	8	0	0	4.0	
i 1	581.7391632653062	2.525	72	1089	6	2	2	2	0	1	2	0	0	4.889597876681885	
i 1	581.7415714285714	1.2625	72	1089	6	1	1	1	0	-1	1	0	0	2.0	
i 1	581.9987959183674	2.2725	75	1089	3	9	14	2	0	1	2	0	0	3.889597876681885	
i 1	582.2327414965987	0.2525	70	275	2	24	16	2	0	-1	2	0	0	4.0	
i 1	582.2680612244898	0.7575000000000001	74	591	6	5	12	8	0	-1	8	0	0	2.5915445024659647	
i 1	582.483544217687	0.2525	73	591	3	24	16	2	0	-1	2	0	0	4.0	
i 1	582.485149659864	1.5150000000000001	72	275	7	1	11	0	0	-1	0	0	0	2.0	
i 1	582.4915714285714	4.7975	70	275	2	24	11	2	0	-1	2	0	0	4.0	
i 1	582.7600340136055	0.505	72	1089	4	2	14	8	0	1	8	0	0	4.889597876681885	
i 1	582.9843469387755	0.2525	72	1089	6	1	8	0	0	-1	0	0	0	2.0	
i 1	582.9931768707482	2.02	74	1089	6	5	7	8	0	-1	8	0	0	2.5915445024659647	
i 1	582.9931768707482	2.02	74	1089	6	5	13	2	0	-2	2	0	0	2.5915445024659647	
i 1	583.0052176870748	0.2525	70	591	3	24	4	2	0	-2	2	0	0	4.0	
i 1	583.2319387755102	0.2525	75	591	4	4	10	8	0	-2	8	0	0	4.889597876681885	
i 1	583.2359523809524	0.2525	69	591	4	24	3	1	0	0	1	0	0	3.0	
i 1	583.4923741496599	2.2725	72	1089	6	1	1	1	0	-1	1	0	0	2.0	
i 1	583.514850340136	2.02	69	1089	5	1	16	0	0	-1	0	0	0	2.0	
i 1	583.5180612244898	1.5150000000000001	72	1089	4	2	13	8	0	1	8	0	0	4.889597876681885	
i 1	583.7447823129252	0.505	74	1089	6	5	3	2	0	-2	2	0	0	2.5915445024659647	
i 1	583.7624421768708	1.2625	75	1089	3	9	1	2	0	1	2	0	0	3.889597876681885	
i 1	584.0180612244898	0.2525	69	591	4	24	1	1	0	0	1	0	0	3.0	
i 1	584.2343469387755	0.2525	75	275	3	4	6	2	0	1	2	0	0	4.889597876681885	
i 1	584.2520068027211	0.2525	74	591	6	5	4	8	0	-1	8	0	0	2.5915445024659647	
i 1	584.259231292517	0.2525	72	1089	6	1	4	0	0	-1	0	0	0	2.0	
i 1	584.5028095238096	0.7575000000000001	72	275	3	3	5	8	0	-2	8	0	0	4.889597876681885	
i 1	584.5060204081633	0.7575000000000001	72	591	4	3	9	2	0	-2	2	0	0	4.889597876681885	
i 1	584.5084285714286	1.7675	74	1089	6	5	7	2	0	-2	2	0	0	2.5915445024659647	
i 1	584.5172585034013	1.7675	71	1089	6	5	14	2	0	-1	2	0	0	2.5915445024659647	
i 1	584.7391632653062	0.2525	69	1089	6	1	7	1	0	-1	1	0	0	2.0	
i 1	584.7504013605442	1.7675	75	275	3	4	2	2	0	1	2	0	0	4.889597876681885	
i 1	584.7616394557823	1.7675	75	591	4	4	16	8	0	-2	8	0	0	4.889597876681885	
i 1	584.9963877551021	0.505	74	591	6	5	2	8	0	-1	8	0	0	2.5915445024659647	
i 1	585.0004013605442	1.7675	72	275	7	1	12	0	0	-1	0	0	0	2.0	
i 1	585.014850340136	1.7675	69	591	6	1	4	0	0	-1	0	0	0	2.0	
i 1	585.0172585034013	0.2525	70	275	2	24	13	2	0	-2	2	0	0	4.0	
i 1	585.240768707483	0.2525	73	591	3	24	2	2	0	-1	2	0	0	4.0	
i 1	585.2512040816326	0.2525	72	1089	4	2	5	8	0	1	8	0	0	4.889597876681885	
i 1	585.4843469387755	0.2525	72	1089	6	2	2	2	0	1	2	0	0	4.889597876681885	
i 1	585.5132448979592	0.2525	71	275	6	5	6	2	0	-1	2	0	0	2.5915445024659647	
i 1	585.7431768707482	1.5150000000000001	74	1089	6	5	4	2	0	-2	2	0	0	2.5915445024659647	
i 1	585.7512040816326	0.2525	69	591	4	24	16	1	0	0	1	0	0	3.0	
i 1	585.7560204081633	1.5150000000000001	74	1089	6	5	6	8	0	-1	8	0	0	2.5915445024659647	
i 1	585.7568231292518	0.2525	72	1089	4	2	3	8	0	1	8	0	0	4.889597876681885	
i 1	585.9931768707482	3.2825	72	591	4	3	1	2	0	-2	2	0	0	4.889597876681885	
i 1	585.9979931972789	3.0300000000000002	72	275	3	3	2	8	0	-2	8	0	0	4.889597876681885	
i 1	586.0188639455782	0.2525	72	275	5	24	2	0	0	0	0	0	0	3.0	
i 1	586.2423741496599	3.0300000000000002	69	1089	5	1	1	0	0	-1	0	0	0	2.0	
i 1	586.2495986394558	0.2525	71	275	6	5	12	8	0	-2	8	0	0	2.5915445024659647	
i 1	586.2560204081633	5.3025	72	1089	6	1	11	1	0	-1	1	0	0	2.0	
i 1	586.4843469387755	0.2525	75	1089	3	9	3	2	0	1	2	0	0	3.889597876681885	
i 1	586.5196666666667	0.2525	71	591	6	5	15	2	0	-1	2	0	0	2.5915445024659647	
i 1	586.7375578231292	0.505	72	1089	6	1	11	0	0	-1	0	0	0	2.0	
i 1	586.7520068027211	0.2525	75	275	3	4	9	2	0	1	2	0	0	4.889597876681885	
i 1	586.7568231292518	2.2725	74	591	6	5	5	8	0	-1	8	0	0	2.5915445024659647	
i 1	586.7584285714286	0.2525	73	275	2	24	11	2	0	-1	2	0	0	4.0	
i 1	586.7640476190476	2.525	71	275	6	5	11	2	0	-1	2	0	0	2.5915445024659647	
i 1	587.0076258503401	0.2525	70	591	3	24	7	8	0	-2	8	0	0	4.0	
i 1	587.2303333333333	0.505	69	591	6	1	13	0	0	-1	0	0	0	2.0	
i 1	587.2391632653062	1.5150000000000001	73	275	2	20	1	8	0	-2	8	0	0	3.0	
i 1	587.2536122448979	0.2525	70	1089	3	20	10	2	0	-2	2	0	0	3.0	
i 1	587.2568231292518	0.2525	71	1089	6	5	15	2	0	-1	2	0	0	2.5915445024659647	
i 1	587.2576258503401	0.2525	72	1089	6	2	5	8	0	1	8	0	0	4.889597876681885	
i 1	587.259231292517	1.01	73	1089	2	20	5	8	0	-2	8	0	0	3.0	
i 1	587.2624421768708	20.4525	67	591	4	7	16	0	0	0	0	0	0	1.9090269580453596	
i 1	587.2696666666667	0.505	70	1089	2	24	2	8	0	-1	8	0	0	7.0	
i 1	587.4819387755102	0.505	70	1089	2	20	3	2	0	-2	2	0	0	3.0	
i 1	587.5020068027211	0.505	74	1089	6	5	1	2	0	-2	2	0	0	2.5915445024659647	
i 1	587.5036122448979	0.505	70	275	2	24	11	8	0	-1	8	0	0	7.0	
i 1	587.5180612244898	0.505	75	1089	3	9	9	2	0	1	2	0	0	3.889597876681885	
i 1	587.7536122448979	0.2525	69	591	4	24	6	1	0	0	1	0	0	3.0	
i 1	587.7616394557823	3.535	70	275	2	24	13	2	0	-1	2	0	0	7.0	
i 1	587.9899659863945	0.505	70	591	3	20	12	2	0	-2	2	0	0	3.0	
i 1	588.0012040816326	0.505	70	1089	3	20	4	2	0	-2	2	0	0	3.0	
i 1	588.0044149659864	2.2725	69	591	6	1	15	0	0	-1	0	0	0	2.0	
i 1	588.0124421768708	0.2525	72	1089	6	2	3	2	0	1	2	0	0	4.889597876681885	
i 1	588.0132448979592	0.2525	71	275	6	5	3	8	0	-2	8	0	0	2.5915445024659647	
i 1	588.2415714285714	2.02	70	1089	2	24	15	8	0	-1	8	0	0	7.0	
i 1	588.2600340136055	3.2825	74	1089	6	5	7	2	0	-2	2	0	0	2.5915445024659647	
i 1	588.2632448979592	1.7675	75	1089	3	9	12	2	0	1	2	0	0	3.889597876681885	
i 1	588.4971904761904	1.2625	73	1089	2	20	13	8	0	-1	8	0	0	3.0	
i 1	588.4987959183674	1.5150000000000001	72	1089	6	2	11	2	0	1	2	0	0	4.889597876681885	
i 1	588.509231292517	2.7775	74	1089	6	5	12	8	0	-1	8	0	0	2.5915445024659647	
i 1	588.514850340136	0.2525	70	1089	2	20	6	2	0	-2	2	0	0	3.0	
i 1	588.5172585034013	1.2625	70	275	2	20	16	2	0	-2	2	0	0	3.0	
i 1	588.7375578231292	1.5150000000000001	72	275	7	1	14	0	0	-1	0	0	0	2.0	
i 1	589.2487959183674	0.505	70	275	2	24	5	8	0	-2	8	0	0	7.0	
i 1	589.2520068027211	2.02	72	1089	6	2	15	8	0	1	8	0	0	4.889597876681885	
i 1	589.2600340136055	0.7575000000000001	73	275	2	20	13	8	0	-2	8	0	0	3.0	
i 1	589.2624421768708	0.2525	74	1089	6	5	12	2	0	-2	2	0	0	2.5915445024659647	
i 1	589.5020068027211	0.2525	70	1089	2	20	1	2	0	-2	2	0	0	3.0	
i 1	589.5036122448979	1.01	71	591	6	5	8	2	0	-1	2	0	0	2.5915445024659647	
i 1	589.5068231292518	1.01	71	275	6	5	2	8	0	-2	8	0	0	2.5915445024659647	
i 1	589.509231292517	1.7675	75	1089	3	9	5	2	0	1	2	0	0	3.889597876681885	
i 1	589.7423741496599	0.2525	70	591	3	24	11	8	0	-1	8	0	0	7.0	
i 1	589.7479931972789	5.555	73	1089	2	20	7	8	0	-2	8	0	0	3.0	
i 1	589.7544149659864	0.2525	70	1089	3	20	8	2	0	-2	2	0	0	3.0	
i 1	589.7560204081633	0.2525	73	591	3	20	1	8	0	-1	8	0	0	3.0	
i 1	589.759231292517	0.2525	73	1089	3	20	2	8	0	-1	8	0	0	3.0	
i 1	589.7696666666667	1.5150000000000001	69	1089	5	1	9	0	0	-1	0	0	0	2.0	
i 1	589.9963877551021	0.2525	73	275	2	24	9	2	0	-2	2	0	0	7.0	
i 1	589.9971904761904	1.2625	70	275	2	20	8	2	0	-1	2	0	0	3.0	
i 1	590.0052176870748	0.2525	75	275	3	4	6	2	0	1	2	0	0	4.889597876681885	
i 1	590.0108367346938	1.2625	70	1089	2	20	6	2	0	-2	2	0	0	3.0	
i 1	590.240768707483	0.2525	72	1089	6	2	5	2	0	1	2	0	0	4.889597876681885	
i 1	590.2696666666667	0.2525	69	591	4	24	12	1	0	0	1	0	0	3.0	
i 1	590.485149659864	0.2525	69	591	6	1	9	0	0	-1	0	0	0	2.0	
i 1	590.4875578231292	0.2525	71	275	6	5	13	2	0	-1	2	0	0	2.5915445024659647	
i 1	590.4995986394558	0.2525	75	591	4	4	5	8	0	-2	8	0	0	4.889597876681885	
i 1	590.7383605442177	0.2525	71	591	6	5	16	2	0	-1	2	0	0	2.5915445024659647	
i 1	590.7415714285714	0.505	72	275	3	3	8	8	0	-2	8	0	0	4.889597876681885	
i 1	590.7431768707482	2.525	72	591	4	3	6	2	0	-2	2	0	0	4.889597876681885	
i 1	590.7640476190476	0.2525	72	275	5	24	13	0	0	0	0	0	0	3.0	
i 1	590.9827414965987	0.2525	75	275	3	4	9	2	0	1	2	0	0	4.889597876681885	
i 1	590.9987959183674	1.7675	72	1089	6	1	4	0	0	-1	0	0	0	2.0	
i 1	591.0004013605442	0.2525	74	1089	6	5	3	2	0	-2	2	0	0	2.5915445024659647	
i 1	591.0036122448979	0.2525	73	1089	2	20	1	8	0	-1	8	0	0	3.0	
i 1	591.014850340136	0.2525	73	275	2	20	4	8	0	-2	8	0	0	3.0	
i 1	591.2303333333333	1.2625	74	387	6	5	11	8	5003	-2	8	0	0	2.5915445024659647	
i 1	591.2359523809524	9.595	60	703	3	14	16	0	0	1	0	0	0	2.6591100107384555	
i 1	591.2383605442177	2.7775	60	703	3	14	4	5	0	1	5	0	0	2.6591100107384555	
i 1	591.2399659863945	0.505	70	591	3	20	10	2	0	-2	2	0	0	3.0	
i 1	591.2415714285714	1.7675	72	703	5	1	3	1	0	-1	1	0	0	2.0	
i 1	591.2415714285714	1.01	73	387	2	20	8	8	5003	-2	8	0	0	3.0	
i 1	591.2423741496599	2.02	75	387	3	4	12	2	5003	1	2	0	0	4.889597876681885	
i 1	591.2439795918367	0.2525	70	703	3	20	9	2	0	-2	2	0	0	3.0	
i 1	591.2512040816326	0.505	70	703	3	20	12	2	0	-1	2	0	0	3.0	
i 1	591.2560204081633	1.2625	74	703	6	5	16	8	0	-1	8	0	0	2.5915445024659647	
i 1	591.2616394557823	0.505	72	387	3	3	15	2	5003	-2	2	0	0	4.889597876681885	
i 1	591.2688639455782	0.2525	70	387	2	24	15	2	5003	-1	2	0	0	7.0	
i 1	591.5012040816326	0.2525	69	591	6	1	4	0	0	-1	0	0	0	2.0	
i 1	591.5052176870748	0.2525	74	591	6	5	13	8	0	-1	8	0	0	2.5915445024659647	
i 1	591.5084285714286	1.01	70	1089	2	24	1	8	0	-1	8	0	0	7.0	
i 1	591.7343469387755	0.2525	73	1089	2	20	14	2	0	-2	2	0	0	3.0	
i 1	591.7383605442177	0.2525	72	1089	6	1	10	1	0	-1	1	0	0	2.0	
i 1	591.7391632653062	1.2625	71	1089	6	5	6	2	0	-1	2	0	0	2.5915445024659647	
i 1	591.7455850340136	0.2525	75	703	6	2	1	2	0	-2	2	0	0	4.889597876681885	
i 1	591.7584285714286	3.0300000000000002	70	387	2	24	13	2	5003	-1	2	0	0	7.0	
i 1	591.9819387755102	0.7575000000000001	71	703	6	5	15	8	0	-1	8	0	0	2.5915445024659647	
i 1	591.983544217687	0.2525	73	703	3	20	7	2	0	-1	2	0	0	3.0	
i 1	591.985149659864	0.2525	69	703	5	1	11	0	0	0	0	0	0	2.0	
i 1	592.0156530612245	0.2525	75	591	4	4	8	8	0	-2	8	0	0	4.889597876681885	
i 1	592.2303333333333	1.7675	69	387	4	24	2	1	5003	-1	1	0	0	3.0	
i 1	592.2311360544218	1.7675	69	591	6	1	12	0	0	-1	0	0	0	2.0	
i 1	592.2399659863945	0.2525	70	387	2	24	14	2	0	-2	2	0	0	7.0	
i 1	592.2431768707482	3.0300000000000002	74	387	6	5	6	8	5003	-1	8	0	0	2.5915445024659647	
i 1	592.2576258503401	0.505	70	1089	2	20	2	2	0	-2	2	0	0	3.0	
i 1	592.2600340136055	0.505	70	387	2	20	7	8	0	-2	8	0	0	3.0	
i 1	592.266455782313	3.0300000000000002	74	591	6	5	2	8	0	-1	8	0	0	2.5915445024659647	
i 1	592.4859523809524	1.01	73	387	2	20	13	8	5003	-2	8	0	0	3.0	
i 1	592.4891632653062	0.2525	72	703	6	2	1	2	0	1	2	0	0	4.889597876681885	
i 1	592.7359523809524	1.2625	75	1089	3	9	16	2	0	1	2	0	0	3.889597876681885	
i 1	592.7367551020408	0.2525	73	591	3	20	14	8	0	-1	8	0	0	3.0	
i 1	592.7487959183674	0.2525	73	703	3	20	6	8	0	-1	8	0	0	3.0	
i 1	592.7544149659864	1.01	70	1089	2	24	8	8	0	-1	8	0	0	7.0	
i 1	592.7608367346938	1.5150000000000001	75	591	4	4	2	8	0	-2	8	0	0	4.889597876681885	
i 1	592.9843469387755	0.2525	69	703	5	1	2	0	0	0	0	0	0	2.0	
i 1	592.9843469387755	0.2525	73	387	2	24	3	2	0	-2	2	0	0	7.0	
i 1	592.990768707483	0.2525	74	387	6	5	1	8	5003	-2	8	0	0	2.5915445024659647	
i 1	592.9995986394558	0.2525	73	1089	2	20	8	8	0	-2	8	0	0	3.0	
i 1	593.0116394557823	0.2525	70	387	2	20	10	2	0	-2	2	0	0	3.0	
i 1	593.0140476190476	0.2525	73	1089	2	20	2	8	0	-2	8	0	0	3.0	
i 1	593.2391632653062	0.2525	74	703	6	5	13	8	0	-1	8	0	0	2.5915445024659647	
i 1	593.2528095238096	0.2525	70	703	3	20	11	8	0	-1	8	0	0	3.0	
i 1	593.264850340136	0.2525	70	591	3	24	3	8	0	-1	8	0	0	7.0	
i 1	593.266455782313	0.2525	72	1089	6	1	2	1	0	-1	1	0	0	2.0	
i 1	593.2696666666667	0.2525	72	703	6	2	1	2	0	1	2	0	0	4.889597876681885	
i 1	593.4803333333333	0.505	75	703	6	2	15	2	0	-2	2	0	0	4.889597876681885	
i 1	593.4819387755102	2.02	75	1089	3	9	9	2	0	1	2	0	0	3.889597876681885	
i 1	593.4867551020408	0.505	72	703	5	1	4	1	0	-1	1	0	0	2.0	
i 1	593.4875578231292	1.2625	70	387	2	20	14	2	0	-1	2	0	0	3.0	
i 1	593.4891632653062	3.0300000000000002	72	1089	6	1	6	0	0	-1	0	0	0	2.0	
i 1	593.4979931972789	0.2525	70	387	2	24	9	8	0	-1	8	0	0	7.0	
i 1	593.5060204081633	0.505	71	591	6	5	4	2	0	-1	2	0	0	2.5915445024659647	
i 1	593.5100340136055	1.2625	70	1089	2	20	11	2	0	-1	2	0	0	3.0	
i 1	593.9923741496599	0.505	69	591	4	24	11	1	0	0	1	0	0	3.0	
i 1	593.9931768707482	1.5150000000000001	75	703	6	2	10	2	0	-2	2	0	0	4.889597876681885	
i 1	593.9947823129252	13.635	60	703	4	14	6	5	0	1	5	0	0	2.6591100107384555	
i 1	594.0020068027211	2.2725	72	703	6	1	16	1	0	-1	1	0	0	2.0	
i 1	594.0196666666667	0.2525	71	1089	6	5	11	2	0	-1	2	0	0	2.5915445024659647	
i 1	594.2471904761904	0.505	73	1089	2	20	15	2	0	-2	2	0	0	3.0	
i 1	594.2495986394558	0.2525	75	1089	3	9	13	2	0	1	2	0	0	3.889597876681885	
i 1	594.264850340136	3.7875	70	1089	2	24	8	8	0	-1	8	0	0	7.0	
i 1	594.2656530612245	0.2525	74	703	6	5	14	8	0	-1	8	0	0	2.5915445024659647	
i 1	594.4947823129252	0.2525	75	387	3	4	15	2	5003	1	2	0	0	4.889597876681885	
i 1	594.5012040816326	0.2525	71	591	6	5	1	2	0	-1	2	0	0	2.5915445024659647	
i 1	594.5100340136055	0.2525	69	387	6	1	7	1	5003	-1	1	0	0	2.0	
i 1	594.7415714285714	1.01	71	1089	6	5	16	2	0	-1	2	0	0	2.5915445024659647	
i 1	594.7479931972789	0.2525	69	591	5	1	13	0	0	-1	0	0	0	2.0	
i 1	594.7520068027211	1.01	71	703	6	5	3	8	0	-1	8	0	0	2.5915445024659647	
i 1	594.7536122448979	2.02	73	387	2	20	11	8	5003	-2	8	0	0	3.0	
i 1	594.759231292517	1.5150000000000001	72	703	6	2	13	2	0	1	2	0	0	4.889597876681885	
i 1	594.7624421768708	0.2525	73	703	3	20	5	2	0	-2	2	0	0	3.0	
i 1	594.7640476190476	0.2525	73	591	3	24	4	8	0	-1	8	0	0	7.0	
i 1	594.7656530612245	0.2525	70	703	3	20	9	2	0	-2	2	0	0	3.0	
i 1	594.9811360544218	1.2625	73	1089	2	20	13	2	0	-2	2	0	0	3.0	
i 1	594.983544217687	0.2525	69	387	4	24	16	1	5003	-1	1	0	0	3.0	
i 1	594.983544217687	1.2625	70	387	2	24	10	8	0	-2	8	0	0	7.0	
i 1	595.0044149659864	1.2625	72	387	3	3	15	2	5003	-2	2	0	0	4.889597876681885	
i 1	595.2303333333333	1.7675	71	591	6	5	15	2	0	-1	2	0	0	2.5915445024659647	
i 1	595.2632448979592	1.7675	74	1089	6	5	14	2	0	-2	2	0	0	2.5915445024659647	
i 1	595.5036122448979	2.2725	69	387	4	24	2	1	5003	-1	1	0	0	3.0	
i 1	595.5188639455782	1.7675	72	591	5	3	11	2	0	-2	2	0	0	4.889597876681885	
i 1	595.7367551020408	1.5150000000000001	75	387	3	4	2	2	5003	1	2	0	0	4.889597876681885	
i 1	595.7568231292518	0.2525	74	387	6	5	8	8	5003	-1	8	0	0	2.5915445024659647	
i 1	595.7576258503401	2.02	69	591	5	1	5	0	0	-1	0	0	0	2.0	
i 1	595.7640476190476	0.505	70	1089	2	20	2	8	0	-2	8	0	0	3.0	
i 1	595.7680612244898	0.7575000000000001	73	1089	2	20	14	8	0	-2	8	0	0	3.0	
i 1	595.990768707483	0.2525	71	1089	6	5	3	2	0	-1	2	0	0	2.5915445024659647	
i 1	595.9947823129252	0.2525	73	387	2	20	2	8	0	-2	8	0	0	3.0	
i 1	596.0076258503401	1.5150000000000001	70	387	2	24	11	2	5003	-1	2	0	0	7.0	
i 1	596.2343469387755	0.2525	73	591	3	24	2	8	0	-1	8	0	0	7.0	
i 1	596.2375578231292	0.2525	73	591	3	20	14	2	0	-1	2	0	0	3.0	
i 1	596.2383605442177	0.2525	70	703	3	20	16	8	0	-2	8	0	0	3.0	
i 1	596.2495986394558	0.2525	74	703	6	5	16	8	0	-1	8	0	0	2.5915445024659647	
i 1	596.2576258503401	0.2525	75	703	6	2	12	2	0	-2	2	0	0	4.889597876681885	
i 1	596.2688639455782	0.2525	70	703	3	20	9	8	0	-1	8	0	0	3.0	
i 1	596.4843469387755	0.2525	73	1089	2	20	4	2	0	-2	2	0	0	3.0	
i 1	596.4915714285714	1.7675	71	1089	6	5	2	2	0	-1	2	0	0	2.5915445024659647	
i 1	596.4963877551021	0.2525	75	1089	3	9	1	2	0	1	2	0	0	3.889597876681885	
i 1	596.5028095238096	0.7575000000000001	73	387	2	20	3	8	0	-1	8	0	0	3.0	
i 1	596.5068231292518	0.2525	72	703	6	1	1	1	0	-1	1	0	0	2.0	
i 1	596.5140476190476	0.7575000000000001	70	1089	2	20	13	2	0	-1	2	0	0	3.0	
i 1	596.5196666666667	2.02	71	703	6	5	9	8	0	-1	8	0	0	2.5915445024659647	
i 1	596.7391632653062	0.2525	69	703	5	1	7	0	0	0	0	0	0	2.0	
i 1	596.7512040816326	1.2625	75	1089	3	9	3	2	0	1	2	0	0	3.889597876681885	
i 1	596.7608367346938	1.2625	75	591	4	4	15	8	0	-2	8	0	0	4.889597876681885	
i 1	596.983544217687	0.2525	69	387	6	1	2	1	5003	-1	1	0	0	2.0	
i 1	596.9899659863945	0.2525	74	703	6	5	7	8	0	-1	8	0	0	2.5915445024659647	
i 1	596.990768707483	2.2725	73	1089	2	20	7	8	0	-2	8	0	0	3.0	
i 1	597.0044149659864	0.2525	70	387	2	24	2	8	0	-2	8	0	0	7.0	
i 1	597.2311360544218	2.02	72	703	6	1	7	1	0	-1	1	0	0	2.0	
i 1	597.2471904761904	1.7675	72	1089	6	1	11	0	0	-1	0	0	0	2.0	
i 1	597.2552176870748	0.505	70	703	3	20	10	8	0	-1	8	0	0	3.0	
i 1	597.2624421768708	0.505	70	591	3	24	8	8	0	-1	8	0	0	7.0	
i 1	597.2632448979592	0.2525	74	1089	6	5	9	2	0	-2	2	0	0	2.5915445024659647	
i 1	597.2656530612245	0.2525	72	387	3	3	3	2	5003	-2	2	0	0	4.889597876681885	
i 1	597.266455782313	0.2525	70	591	3	20	13	8	0	-1	8	0	0	3.0	
i 1	597.4955850340136	2.2725	74	387	6	5	10	8	5003	-2	8	0	0	2.5915445024659647	
i 1	597.5060204081633	1.7675	73	387	2	20	8	8	5003	-2	8	0	0	3.0	
i 1	597.5076258503401	1.7675	75	387	3	4	15	2	5003	1	2	0	0	4.889597876681885	
i 1	597.5188639455782	1.5150000000000001	72	591	5	3	2	2	0	-2	2	0	0	4.889597876681885	
i 1	597.7463877551021	2.02	74	703	6	5	2	8	0	-1	8	0	0	2.5915445024659647	
i 1	597.7479931972789	1.5150000000000001	70	1089	2	20	11	8	0	-2	8	0	0	3.0	
i 1	597.7576258503401	0.2525	72	1089	6	1	11	1	0	-1	1	0	0	2.0	
i 1	597.7576258503401	0.2525	73	1089	2	20	3	2	0	-1	2	0	0	3.0	
i 1	597.7688639455782	1.5150000000000001	73	387	2	24	1	8	0	-2	8	0	0	7.0	
i 1	597.990768707483	0.2525	69	387	6	1	7	1	5003	-1	1	0	0	2.0	
i 1	598.0052176870748	0.2525	75	1089	3	9	5	2	0	1	2	0	0	3.889597876681885	
i 1	598.2327414965987	0.2525	72	703	6	2	10	2	0	1	2	0	0	4.889597876681885	
i 1	598.2656530612245	0.2525	69	591	4	24	4	1	0	0	1	0	0	3.0	
i 1	598.4827414965987	0.2525	71	591	6	5	7	2	0	-1	2	0	0	2.5915445024659647	
i 1	598.490768707483	1.7675	75	1089	3	9	7	2	0	1	2	0	0	3.889597876681885	
i 1	598.5068231292518	3.0300000000000002	69	387	4	24	10	1	5003	-1	1	0	0	3.0	
i 1	598.5180612244898	1.7675	75	591	4	4	7	8	0	-2	8	0	0	4.889597876681885	
i 1	598.5188639455782	3.0300000000000002	69	591	5	1	14	0	0	-1	0	0	0	2.0	
i 1	598.7383605442177	1.5150000000000001	73	1089	2	20	4	2	0	-1	2	0	0	3.0	
i 1	598.7487959183674	2.02	70	387	2	24	11	2	5003	-1	2	0	0	7.0	
i 1	598.7512040816326	1.5150000000000001	70	1089	2	24	7	8	0	-1	8	0	0	7.0	
i 1	598.7536122448979	1.5150000000000001	73	387	2	20	11	2	0	-2	2	0	0	3.0	
i 1	598.7688639455782	0.2525	74	591	6	5	2	8	0	-1	8	0	0	2.5915445024659647	
i 1	599.0020068027211	0.2525	71	591	6	5	9	2	0	-1	2	0	0	2.5915445024659647	
i 1	599.2399659863945	1.5150000000000001	71	1089	6	5	3	2	0	-1	2	0	0	2.5915445024659647	
i 1	599.2536122448979	1.5150000000000001	71	703	6	5	13	8	0	-1	8	0	0	2.5915445024659647	
i 1	599.2560204081633	0.2525	69	591	4	24	2	1	0	0	1	0	0	3.0	
i 1	599.2696666666667	0.2525	75	703	6	2	7	2	0	-2	2	0	0	4.889597876681885	
i 1	599.4827414965987	0.2525	72	1089	6	1	14	1	0	-1	1	0	0	2.0	
i 1	599.5124421768708	0.2525	72	387	3	3	8	2	5003	-2	2	0	0	4.889597876681885	
i 1	599.7359523809524	1.01	72	703	6	1	13	1	0	-1	1	0	0	2.0	
i 1	599.7423741496599	0.2525	71	591	6	5	4	2	0	-1	2	0	0	2.5915445024659647	
i 1	599.7479931972789	2.2725	75	703	6	2	14	2	0	-2	2	0	0	4.889597876681885	
i 1	599.7552176870748	2.525	75	1089	3	9	2	2	0	1	2	0	0	3.889597876681885	
i 1	599.7576258503401	0.505	70	1089	2	20	16	8	0	-2	8	0	0	3.0	
i 1	599.7640476190476	2.02	73	1089	2	20	5	8	0	-2	8	0	0	3.0	
i 1	599.7680612244898	1.01	72	1089	6	1	9	0	0	-1	0	0	0	2.0	
i 1	599.9971904761904	3.2825	73	387	2	20	4	8	5003	-2	8	0	0	3.0	
i 1	600.0108367346938	2.525	74	591	6	5	7	8	0	-1	8	0	0	2.5915445024659647	
i 1	600.233544217687	0.2525	73	591	3	24	11	2	0	-2	2	0	0	7.0	
i 1	600.2367551020408	0.2525	72	703	6	2	1	2	0	1	2	0	0	4.889597876681885	
i 1	600.2399659863945	0.2525	73	591	3	20	5	8	0	-1	8	0	0	3.0	
i 1	600.2528095238096	0.2525	73	703	3	20	2	8	0	-2	8	0	0	3.0	
i 1	600.2696666666667	0.505	74	387	6	5	12	8	5003	-1	8	0	0	2.5915445024659647	
i 1	600.485149659864	0.2525	72	591	5	3	14	2	0	-2	2	0	0	4.889597876681885	
i 1	600.5084285714286	1.2625	70	1089	2	20	11	2	0	-2	2	0	0	3.0	
i 1	600.514850340136	0.2525	73	387	2	20	4	2	0	-2	2	0	0	3.0	
i 1	600.5180612244898	2.2725	73	387	2	24	7	8	0	-1	8	0	0	7.0	
i 1	600.735149659864	0.2525	74	387	6	5	5	8	5003	-2	8	0	0	2.5915445024659647	
i 1	600.7399659863945	1.7675	74	387	6	5	15	8	5003	-1	8	0	0	2.5915445024659647	
i 1	600.7415714285714	0.2525	69	387	6	1	2	1	5003	-1	1	0	0	2.0	
i 1	600.7495986394558	6.8175	60	703	4	14	9	0	0	1	0	0	0	2.6591100107384555	
i 1	600.9883605442177	0.2525	71	703	6	5	5	8	0	-1	8	0	0	2.5915445024659647	
i 1	601.0012040816326	4.2925	72	1089	6	1	10	0	0	-1	0	0	0	2.0	
i 1	601.0140476190476	4.2925	72	703	6	1	16	1	0	-1	1	0	0	2.0	
i 1	601.2327414965987	0.505	71	591	6	5	3	2	0	-1	2	0	0	2.5915445024659647	
i 1	601.2399659863945	1.7675	70	1089	2	24	13	8	0	-1	8	0	0	7.0	
i 1	601.2504013605442	0.2525	72	591	5	3	2	2	0	-2	2	0	0	4.889597876681885	
i 1	601.2504013605442	1.01	70	387	2	24	5	2	5003	-1	2	0	0	7.0	
i 1	601.2512040816326	1.01	73	387	2	20	10	2	0	-2	2	0	0	3.0	
i 1	601.4947823129252	1.2625	72	703	6	2	1	2	0	1	2	0	0	4.889597876681885	
i 1	601.5012040816326	1.2625	72	387	3	3	2	2	5003	-2	2	0	0	4.889597876681885	
i 1	601.5060204081633	0.2525	69	591	4	24	12	1	0	0	1	0	0	3.0	
i 1	601.7399659863945	4.2925	71	1089	6	5	13	2	0	-1	2	0	0	2.5915445024659647	
i 1	601.7504013605442	0.2525	69	591	5	1	13	0	0	-1	0	0	0	2.0	
i 1	602.0028095238096	4.04	71	703	6	5	6	8	0	-1	8	0	0	2.5915445024659647	
i 1	602.2455850340136	0.2525	69	591	4	24	14	1	0	0	1	0	0	3.0	
i 1	602.2560204081633	3.7875	72	591	5	3	7	2	0	-2	2	0	0	4.889597876681885	
i 1	602.264850340136	3.535	75	387	3	4	14	2	5003	1	2	0	0	4.889597876681885	
i 1	602.4955850340136	0.7575000000000001	69	703	6	1	15	0	0	0	0	0	0	2.0	
i 1	602.5036122448979	2.02	73	1089	2	20	10	8	0	-2	8	0	0	3.0	
i 1	602.5076258503401	0.2525	74	387	6	5	5	8	5003	-2	8	0	0	2.5915445024659647	
i 1	602.5140476190476	0.2525	73	387	2	20	6	2	0	-2	2	0	0	3.0	
i 1	602.7319387755102	0.2525	75	1089	3	9	16	2	0	1	2	0	0	3.889597876681885	
i 1	602.7359523809524	0.2525	73	703	1	20	15	2	0	-1	2	0	0	3.0	
i 1	602.7399659863945	3.0300000000000002	70	387	2	24	15	2	5003	-1	2	0	0	7.0	
i 1	602.7495986394558	0.2525	73	703	3	20	12	8	0	-2	8	0	0	3.0	
i 1	602.7544149659864	0.2525	73	591	3	24	7	8	0	-2	8	0	0	7.0	
i 1	602.759231292517	0.2525	74	591	6	5	2	8	0	-1	8	0	0	2.5915445024659647	
i 1	602.759231292517	0.2525	70	591	3	20	13	2	0	-1	2	0	0	3.0	
i 1	602.9979931972789	1.2625	75	1089	3	9	1	2	0	1	2	0	0	3.889597876681885	
i 1	603.0004013605442	0.505	70	1089	2	20	13	8	0	-2	8	0	0	3.0	
i 1	603.0028095238096	0.7575000000000001	75	591	4	4	15	8	0	-2	8	0	0	4.889597876681885	
i 1	603.0036122448979	0.505	73	387	2	20	16	8	0	-2	8	0	0	3.0	
i 1	603.014850340136	1.01	71	591	6	5	16	2	0	-1	2	0	0	2.5915445024659647	
i 1	603.016455782313	0.7575000000000001	74	1089	6	5	10	2	0	-2	2	0	0	2.5915445024659647	
i 1	603.2311360544218	0.2525	69	591	4	24	12	1	0	0	1	0	0	3.0	
i 1	603.2528095238096	2.2725	70	1089	2	24	16	8	0	-1	8	0	0	7.0	
i 1	603.2536122448979	0.2525	70	387	2	24	4	2	0	-1	2	0	0	7.0	
i 1	603.4819387755102	0.505	73	703	3	20	15	2	0	-1	2	0	0	3.0	
i 1	603.4827414965987	0.505	70	591	3	24	1	8	0	-2	8	0	0	7.0	
i 1	603.5036122448979	0.7575000000000001	70	591	3	20	9	8	0	-1	8	0	0	3.0	
i 1	603.5076258503401	0.7575000000000001	73	703	1	20	8	2	0	-2	2	0	0	3.0	
i 1	603.5132448979592	0.2525	69	591	5	1	13	0	0	-1	0	0	0	2.0	
i 1	603.5140476190476	1.01	73	387	2	20	2	8	5003	-2	8	0	0	3.0	
i 1	603.7504013605442	0.2525	69	591	4	24	1	1	0	0	1	0	0	3.0	
i 1	603.983544217687	0.505	69	703	6	1	12	0	0	0	0	0	0	2.0	
i 1	603.9955850340136	0.2525	74	703	6	5	3	8	0	-1	8	0	0	2.5915445024659647	
i 1	604.2447823129252	0.505	72	703	6	2	9	2	0	1	2	0	0	4.889597876681885	
i 1	604.2528095238096	0.2525	74	387	6	5	3	8	5003	-1	8	0	0	2.5915445024659647	
i 1	604.2672585034013	1.01	73	387	2	20	13	2	0	-2	2	0	0	3.0	
i 1	604.516455782313	0.2525	69	387	6	1	9	1	5003	-1	1	0	0	2.0	
i 1	604.740768707483	1.5150000000000001	69	591	5	1	6	0	0	-1	0	0	0	2.0	
i 1	604.7455850340136	1.5150000000000001	69	387	4	24	1	1	5003	-1	1	0	0	3.0	
i 1	604.764850340136	0.2525	75	1089	3	9	12	2	0	1	2	0	0	3.889597876681885	
i 1	604.9963877551021	2.7775	73	387	2	20	4	8	5003	-2	8	0	0	3.0	
i 1	605.0020068027211	0.2525	75	703	6	2	12	2	0	-2	2	0	0	4.889597876681885	
i 1	605.0044149659864	0.2525	73	1089	2	20	3	2	0	-2	2	0	0	3.0	
i 1	605.233544217687	0.2525	74	591	6	5	6	8	0	-1	8	0	0	2.5915445024659647	
i 1	605.2391632653062	4.04	73	1089	2	20	6	8	0	-2	8	0	0	3.0	
i 1	605.2455850340136	0.2525	70	703	3	20	12	2	0	-1	2	0	0	3.0	
i 1	605.2463877551021	0.2525	73	591	3	20	4	8	0	-2	8	0	0	3.0	
i 1	605.2512040816326	1.5150000000000001	75	591	4	4	4	8	0	-2	8	0	0	4.889597876681885	
i 1	605.2576258503401	0.2525	70	591	3	24	3	8	0	-2	8	0	0	7.0	
i 1	605.2600340136055	1.7675	75	1089	3	9	10	2	0	1	2	0	0	3.889597876681885	
i 1	605.264850340136	0.2525	73	703	1	20	6	8	0	-2	8	0	0	3.0	
i 1	605.2672585034013	0.2525	69	387	6	1	4	1	5003	-1	1	0	0	2.0	
i 1	605.5084285714286	1.2625	74	703	6	5	8	8	0	-1	8	0	0	2.5915445024659647	
i 1	605.5100340136055	1.01	73	1089	2	20	5	8	0	-1	8	0	0	3.0	
i 1	605.5116394557823	0.2525	73	387	2	20	9	8	0	-1	8	0	0	3.0	
i 1	605.516455782313	1.01	70	387	2	24	12	8	0	-2	8	0	0	7.0	
i 1	605.5196666666667	0.2525	72	1089	6	1	16	1	0	-1	1	0	0	2.0	
i 1	605.7608367346938	1.5150000000000001	74	387	6	5	4	8	5003	-2	8	0	0	2.5915445024659647	
i 1	605.9803333333333	0.2525	71	591	6	5	5	2	0	-1	2	0	0	2.5915445024659647	
i 1	606.0116394557823	0.2525	72	703	6	2	13	2	0	1	2	0	0	4.889597876681885	
i 1	606.0132448979592	0.2525	69	387	6	1	9	1	5003	-1	1	0	0	2.0	
i 1	606.233544217687	1.2625	75	1089	3	9	7	2	0	1	2	0	0	3.889597876681885	
i 1	606.233544217687	0.7575000000000001	70	1089	2	24	15	8	0	-1	8	0	0	7.0	
i 1	606.2423741496599	1.2625	71	1089	6	5	15	2	0	-1	2	0	0	2.5915445024659647	
i 1	606.2447823129252	0.7575000000000001	70	387	2	24	11	2	5003	-1	2	0	0	7.0	
i 1	606.2463877551021	0.7575000000000001	72	703	6	1	13	1	0	-1	1	0	0	2.0	
i 1	606.259231292517	0.7575000000000001	72	1089	6	1	10	0	0	-1	0	0	0	2.0	
i 1	606.2656530612245	1.2625	71	703	6	5	15	8	0	-1	8	0	0	2.5915445024659647	
i 1	606.4883605442177	0.7575000000000001	73	591	3	20	16	2	0	-1	2	0	0	3.0	
i 1	606.490768707483	0.7575000000000001	73	703	1	20	1	2	0	-1	2	0	0	3.0	
i 1	606.5012040816326	0.505	73	703	3	20	12	2	0	-2	2	0	0	3.0	
i 1	606.5036122448979	1.01	75	703	6	2	16	2	0	-2	2	0	0	4.889597876681885	
i 1	606.5052176870748	0.505	70	591	3	24	16	8	0	-2	8	0	0	7.0	
i 1	606.5116394557823	1.2625	69	387	4	24	5	1	5003	-1	1	0	0	3.0	
i 1	606.5124421768708	1.01	69	591	5	1	4	0	0	-1	0	0	0	2.0	
i 1	606.9915714285714	0.2525	75	387	3	4	16	2	5003	1	2	0	0	4.889597876681885	
i 1	607.235149659864	1.5150000000000001	72	1089	6	1	16	0	0	-1	0	0	0	2.0	
i 1	607.2399659863945	0.2525	72	591	5	3	5	2	0	-2	2	0	0	4.889597876681885	
i 1	607.2455850340136	0.505	70	387	2	24	16	2	0	-1	2	0	0	7.0	
i 1	607.259231292517	0.505	70	1089	2	24	3	8	0	-1	8	0	0	7.0	
i 1	607.2600340136055	1.5150000000000001	70	387	2	20	12	2	0	-2	2	0	0	3.0	
i 1	607.2608367346938	1.5150000000000001	72	703	6	1	8	1	0	-1	1	0	0	2.0	
i 1	607.4867551020408	28.0275	60	703	4	14	10	0	0	1	0	0	0	2.238332859264742	
i 1	607.4875578231292	0.505	75	703	6	2	13	2	0	-2	2	0	0	5.926595144985097	
i 1	607.4891632653062	0.505	71	1089	6	5	14	2	0	-1	2	0	0	3.0008473025314624	
i 1	607.4939795918367	1.5150000000000001	74	591	6	5	3	8	0	-1	8	0	0	3.0008473025314624	
i 1	607.4939795918367	28.0275	60	703	4	14	9	5	0	1	5	0	0	2.238332859264742	
i 1	607.4987959183674	0.505	71	703	6	5	1	8	0	-1	8	0	0	3.0008473025314624	
i 1	607.4987959183674	1.5150000000000001	74	387	6	5	8	8	5003	-1	8	0	0	3.0008473025314624	
i 1	607.5012040816326	6.8175	67	591	4	7	8	0	0	0	0	0	0	1.4882498065716456	
i 1	607.5100340136055	3.0300000000000002	70	387	2	24	3	2	5003	-1	2	0	0	7.0	
i 1	607.5116394557823	0.505	69	591	6	1	7	0	0	-1	0	0	0	2.0	
i 1	607.5132448979592	0.505	75	1089	3	9	13	2	0	1	2	0	0	4.926595144985097	
i 1	607.7447823129252	0.505	72	387	3	3	2	2	5003	-2	2	0	0	5.926595144985097	
i 1	607.9859523809524	0.2525	72	703	6	2	13	2	0	1	2	0	0	5.926595144985097	
i 1	608.0140476190476	0.2525	69	591	4	24	11	1	0	0	1	0	0	3.0	
i 1	608.2343469387755	1.2625	75	387	3	4	7	2	5003	1	2	0	0	5.926595144985097	
i 1	608.2375578231292	1.2625	72	591	5	3	15	2	0	-2	2	0	0	5.926595144985097	
i 1	608.2391632653062	2.02	69	387	4	24	7	1	5003	-1	1	0	0	3.0	
i 1	608.2512040816326	2.02	69	591	6	1	7	0	0	-1	0	0	0	2.0	
i 1	608.2672585034013	0.2525	75	591	4	4	4	8	0	-2	8	0	0	5.926595144985097	
i 1	608.4843469387755	0.7575000000000001	70	1089	2	24	1	8	0	-1	8	0	0	7.0	
i 1	608.4859523809524	0.2525	70	387	2	24	5	2	0	-1	2	0	0	7.0	
i 1	608.4947823129252	0.2525	72	387	3	3	6	2	5003	-2	2	0	0	5.926595144985097	
i 1	608.7375578231292	1.7675	71	703	6	5	15	8	0	-1	8	0	0	3.0008473025314624	
i 1	608.7455850340136	1.7675	71	1089	6	5	8	2	0	-1	2	0	0	3.0008473025314624	
i 1	608.7495986394558	0.2525	73	703	1	20	1	8	0	-2	8	0	0	3.0	
i 1	608.7544149659864	0.2525	70	591	3	24	16	2	0	-2	2	0	0	7.0	
i 1	608.7632448979592	0.2525	73	591	3	20	8	8	0	-1	8	0	0	3.0	
i 1	608.7696666666667	0.7575000000000001	73	387	2	20	5	8	5003	-2	8	0	0	3.0	
i 1	608.983544217687	0.2525	75	1089	5	9	16	2	0	1	2	0	0	4.926595144985097	
i 1	608.983544217687	0.2525	74	1089	6	5	4	2	0	-2	2	0	0	3.0008473025314624	
i 1	608.9939795918367	0.505	72	1089	6	1	2	0	0	-1	0	0	0	2.0	
i 1	609.2431768707482	0.2525	73	703	1	20	2	2	0	-2	2	0	0	3.0	
i 1	609.2447823129252	0.2525	71	591	6	5	6	2	0	-1	2	0	0	3.0008473025314624	
i 1	609.2504013605442	0.2525	73	591	3	20	6	2	0	-1	2	0	0	3.0	
i 1	609.2512040816326	1.2625	75	591	4	4	5	8	0	-2	8	0	0	5.926595144985097	
i 1	609.4811360544218	1.01	73	1089	2	20	11	8	0	-2	8	0	0	3.0	
i 1	609.4923741496599	0.2525	72	703	6	2	8	2	0	1	2	0	0	5.926595144985097	
i 1	609.5036122448979	0.505	74	703	6	5	3	8	0	-1	8	0	0	3.0008473025314624	
i 1	609.5044149659864	1.01	75	1089	5	9	10	2	0	1	2	0	0	4.926595144985097	
i 1	609.5076258503401	3.535	72	703	6	1	14	1	0	-1	1	0	0	2.0	
i 1	609.5084285714286	1.01	70	387	2	20	14	2	0	-2	2	0	0	3.0	
i 1	609.7463877551021	3.2825	72	1089	6	1	4	0	0	-1	0	0	0	2.0	
i 1	609.7487959183674	0.2525	75	1089	3	9	15	2	0	1	2	0	0	4.926595144985097	
i 1	610.0036122448979	0.7575000000000001	73	387	2	20	6	8	5003	-2	8	0	0	3.0	
i 1	610.0108367346938	0.7575000000000001	70	387	2	24	3	8	0	-1	8	0	0	7.0	
i 1	610.2415714285714	2.02	72	591	5	3	3	2	0	-2	2	0	0	5.926595144985097	
i 1	610.2415714285714	0.2525	74	703	6	5	15	8	0	-1	8	0	0	3.0008473025314624	
i 1	610.2552176870748	2.02	75	387	3	4	2	2	5003	1	2	0	0	5.926595144985097	
i 1	610.4819387755102	0.2525	74	387	6	5	6	8	5003	-1	8	0	0	3.0008473025314624	
i 1	610.4971904761904	1.2625	74	1089	6	5	14	2	0	-2	2	0	0	3.0008473025314624	
i 1	610.5052176870748	1.2625	71	591	6	5	2	2	0	-1	2	0	0	3.0008473025314624	
i 1	610.7439795918367	0.505	70	387	2	20	12	2	0	-2	2	0	0	3.0	
i 1	610.7495986394558	0.7575000000000001	70	387	2	24	9	2	5003	-1	2	0	0	7.0	
i 1	610.7520068027211	0.2525	75	1089	3	9	10	2	0	1	2	0	0	4.926595144985097	
i 1	610.7568231292518	0.2525	74	387	6	5	12	8	5003	-2	8	0	0	3.0008473025314624	
i 1	610.7672585034013	1.2625	73	1089	2	20	4	8	0	-2	8	0	0	3.0	
i 1	611.0052176870748	0.2525	72	703	6	2	9	2	0	1	2	0	0	5.926595144985097	
i 1	611.0124421768708	0.2525	72	1089	4	1	9	1	0	-1	1	0	0	2.0	
i 1	611.2303333333333	0.2525	75	1089	3	9	10	2	0	1	2	0	0	4.926595144985097	
i 1	611.2367551020408	0.7575000000000001	73	387	2	20	8	8	5003	-2	8	0	0	3.0	
i 1	611.2415714285714	0.2525	69	387	6	1	12	1	5003	-1	1	0	0	2.0	
i 1	611.2455850340136	0.2525	70	703	1	20	6	2	0	-1	2	0	0	3.0	
i 1	611.2495986394558	0.2525	70	591	3	20	10	8	0	-2	8	0	0	3.0	
i 1	611.2584285714286	0.2525	70	591	3	24	2	2	0	-1	2	0	0	7.0	
i 1	611.4939795918367	1.7675	71	703	6	5	9	8	0	-1	8	0	0	3.0008473025314624	
i 1	611.5044149659864	1.7675	71	1089	6	5	2	2	0	-1	2	0	0	3.0008473025314624	
i 1	611.5044149659864	0.2525	70	387	2	24	12	8	0	-1	8	0	0	7.0	
i 1	611.7399659863945	1.01	75	1089	5	9	4	2	0	1	2	0	0	4.926595144985097	
i 1	611.740768707483	0.505	70	1089	2	24	12	8	0	-1	8	0	0	7.0	
i 1	611.7463877551021	1.01	75	591	4	4	5	8	0	-2	8	0	0	5.926595144985097	
i 1	611.7520068027211	0.505	73	591	3	24	12	8	0	-2	8	0	0	7.0	
i 1	611.7672585034013	0.2525	70	387	2	24	7	2	5003	-1	2	0	0	7.0	
i 1	612.2303333333333	0.2525	73	387	2	24	5	2	0	-2	2	0	0	7.0	
i 1	612.2471904761904	0.2525	70	387	2	24	8	2	5003	-1	2	0	0	7.0	
i 1	612.2487959183674	0.2525	70	387	2	20	9	8	0	-1	8	0	0	3.0	
i 1	612.2672585034013	3.2825	73	387	2	20	7	8	5003	-2	8	0	0	3.0	
i 1	612.4939795918367	0.2525	70	591	3	20	5	2	0	-2	2	0	0	3.0	
i 1	612.4963877551021	0.2525	74	591	6	5	13	8	0	-1	8	0	0	3.0008473025314624	
i 1	612.5076258503401	0.2525	70	703	1	20	14	8	0	-1	8	0	0	3.0	
i 1	612.5076258503401	0.2525	73	1089	2	20	14	8	0	-2	8	0	0	3.0	
i 1	612.7512040816326	1.01	70	1089	2	24	1	8	0	-1	8	0	0	7.0	
i 1	612.7608367346938	1.5150000000000001	75	703	6	2	3	2	0	-2	2	0	0	5.926595144985097	
i 1	612.7616394557823	1.5150000000000001	75	1089	3	9	13	2	0	1	2	0	0	4.926595144985097	
i 1	612.7680612244898	2.7775	70	387	2	24	3	8	0	-2	8	0	0	7.0	
i 1	613.0156530612245	0.7575000000000001	69	591	6	1	15	0	0	-1	0	0	0	2.0	
i 1	613.0180612244898	0.7575000000000001	69	387	4	24	14	1	5003	-1	1	0	0	3.0	
i 1	613.2415714285714	1.01	74	703	6	5	10	8	0	-1	8	0	0	3.0008473025314624	
i 1	613.2431768707482	0.2525	69	387	6	1	11	1	5003	-1	1	0	0	2.0	
i 1	613.2528095238096	1.01	74	387	6	5	16	8	5003	-2	8	0	0	3.0008473025314624	
i 1	613.4843469387755	1.5150000000000001	70	387	2	24	3	2	5003	-1	2	0	0	7.0	
i 1	613.5084285714286	0.7575000000000001	73	387	2	20	12	8	0	-2	8	0	0	3.0	
i 1	613.733544217687	0.505	72	703	6	1	9	1	0	-1	1	0	0	2.0	
i 1	613.7584285714286	0.2525	75	387	3	4	7	2	5003	1	2	0	0	5.926595144985097	
i 1	613.7640476190476	0.505	72	1089	6	1	11	0	0	-1	0	0	0	2.0	
i 1	614.2367551020408	0.7575000000000001	72	703	6	2	3	2	0	1	2	0	0	5.926595144985097	
i 1	614.2439795918367	0.505	72	703	6	1	11	1	0	-1	1	0	0	2.0	
i 1	614.2455850340136	7.07	67	591	4	7	9	0	0	0	0	0	0	1.4882498065716456	
i 1	614.2504013605442	0.7575000000000001	72	387	3	3	5	2	5003	-2	2	0	0	5.926595144985097	
i 1	614.2632448979592	0.505	72	1089	4	1	1	0	0	-1	0	0	0	2.0	
i 1	614.2632448979592	0.2525	71	1089	6	5	6	2	0	-1	2	0	0	3.0008473025314624	
i 1	614.2640476190476	0.2525	71	703	6	5	16	8	0	-1	8	0	0	3.0008473025314624	
i 1	614.5068231292518	2.525	74	591	6	5	8	8	0	-1	8	0	0	3.0008473025314624	
i 1	614.5172585034013	2.525	74	387	6	5	6	8	5003	-1	8	0	0	3.0008473025314624	
i 1	614.7504013605442	1.5150000000000001	69	591	6	1	7	0	0	-1	0	0	0	2.0	
i 1	614.7608367346938	1.5150000000000001	69	387	4	24	16	1	5003	-1	1	0	0	3.0	
i 1	615.0068231292518	1.01	72	591	5	3	15	2	0	-2	2	0	0	5.926595144985097	
i 1	615.0140476190476	1.01	75	387	3	4	16	2	5003	1	2	0	0	5.926595144985097	
i 1	615.4987959183674	0.505	70	387	2	24	6	2	5003	-1	2	0	0	7.0	
i 1	615.9883605442177	0.7575000000000001	75	591	4	4	10	8	0	-2	8	0	0	5.926595144985097	
i 1	616.0004013605442	1.01	73	387	2	20	14	8	5003	-2	8	0	0	3.0	
i 1	616.0108367346938	0.7575000000000001	75	1089	5	9	13	2	0	1	2	0	0	4.926595144985097	
i 1	616.0156530612245	0.505	70	591	1	20	8	2	0	-1	2	0	0	3.0	
i 1	616.2495986394558	1.2625	72	703	6	1	8	1	0	-1	1	0	0	2.0	
i 1	616.2536122448979	0.2525	70	703	1	20	14	2	0	-1	2	0	0	3.0	
i 1	616.2688639455782	1.2625	72	1089	4	1	13	0	0	-1	0	0	0	2.0	
i 1	616.2688639455782	0.2525	73	1089	2	20	1	8	0	-2	8	0	0	3.0	
i 1	616.4891632653062	0.7575000000000001	70	1089	2	24	15	8	0	-1	8	0	0	7.0	
i 1	616.4899659863945	0.505	73	387	2	24	8	8	0	-2	8	0	0	7.0	
i 1	616.7463877551021	1.01	75	387	3	4	9	2	5003	1	2	0	0	5.926595144985097	
i 1	616.7696666666667	1.01	72	591	5	3	7	2	0	-2	2	0	0	5.926595144985097	
i 1	616.9819387755102	0.505	71	703	6	5	8	8	0	-1	8	0	0	3.0008473025314624	
i 1	617.009231292517	0.505	71	1089	6	5	9	2	0	-1	2	0	0	3.0008473025314624	
i 1	617.0180612244898	0.2525	73	591	3	24	13	2	0	-2	2	0	0	7.0	
i 1	617.2303333333333	0.2525	70	387	2	24	2	2	5003	-1	2	0	0	7.0	
i 1	617.2343469387755	0.2525	70	387	2	24	6	8	0	-2	8	0	0	7.0	
i 1	617.2528095238096	4.7975	73	387	2	20	14	8	5003	-2	8	0	0	3.0	
i 1	617.4883605442177	1.2625	71	591	6	5	12	2	0	-1	2	0	0	3.0008473025314624	
i 1	617.490768707483	1.2625	69	387	4	24	10	1	5003	-1	1	0	0	3.0	
i 1	617.4939795918367	1.2625	69	591	6	1	6	0	0	-1	0	0	0	2.0	
i 1	617.5124421768708	0.2525	73	591	1	20	9	8	0	-2	8	0	0	3.0	
i 1	617.5196666666667	1.2625	74	1089	6	5	1	2	0	-2	2	0	0	3.0008473025314624	
i 1	617.735149659864	1.2625	75	591	4	4	1	8	0	-2	8	0	0	5.926595144985097	
i 1	617.7423741496599	0.505	73	387	2	24	8	2	0	-1	2	0	0	7.0	
i 1	617.7447823129252	1.2625	75	1089	5	9	3	2	0	1	2	0	0	4.926595144985097	
i 1	618.2391632653062	0.2525	70	591	3	24	3	2	0	-1	2	0	0	7.0	
i 1	618.2544149659864	0.2525	70	1089	2	24	13	8	0	-1	8	0	0	7.0	
i 1	618.2624421768708	0.2525	73	591	1	20	10	2	0	-2	2	0	0	3.0	
i 1	618.5108367346938	0.505	70	387	2	24	16	8	0	-1	8	0	0	7.0	
i 1	618.5156530612245	0.505	70	387	2	24	3	2	5003	-1	2	0	0	7.0	
i 1	618.7375578231292	1.2625	71	703	6	5	10	8	0	-1	8	0	0	3.0008473025314624	
i 1	618.740768707483	1.2625	71	1089	6	5	9	2	0	-1	2	0	0	3.0008473025314624	
i 1	618.7415714285714	2.2725	72	703	6	1	5	1	0	-1	1	0	0	2.0	
i 1	618.7423741496599	2.2725	72	1089	4	1	7	0	0	-1	0	0	0	2.0	
i 1	618.9803333333333	0.2525	73	591	3	24	3	2	0	-1	2	0	0	7.0	
i 1	618.9811360544218	1.7675	75	1089	5	9	11	2	0	1	2	0	0	4.926595144985097	
i 1	618.9891632653062	0.2525	73	591	1	20	10	2	0	-2	2	0	0	3.0	
i 1	618.9923741496599	0.2525	70	1089	2	24	11	8	0	-1	8	0	0	7.0	
i 1	619.0100340136055	1.7675	75	703	6	2	11	2	0	-2	2	0	0	5.926595144985097	
i 1	619.2495986394558	1.7675	73	387	2	24	1	2	0	-2	2	0	0	7.0	
i 1	620.0068231292518	1.2625	74	703	6	5	6	8	0	-1	8	0	0	3.0008473025314624	
i 1	620.0132448979592	2.7775	74	387	6	5	8	8	5003	-2	8	0	0	3.0008473025314624	
i 1	620.740768707483	0.505	72	703	6	2	14	2	0	1	2	0	0	5.926595144985097	
i 1	620.740768707483	0.2525	72	387	3	3	13	2	5003	-2	2	0	0	5.926595144985097	
i 1	620.9811360544218	0.2525	69	387	4	24	12	1	5003	-1	1	0	0	3.0	
i 1	620.9883605442177	0.2525	72	387	5	3	1	2	5003	-2	2	0	0	5.926595144985097	
i 1	620.9963877551021	0.2525	69	591	6	1	16	0	0	-1	0	0	0	2.0	
i 1	621.2303333333333	1.5150000000000001	74	387	6	5	12	8	0	-2	8	0	0	3.0008473025314624	
i 1	621.2343469387755	14.14	60	387	4	7	13	5	0	1	5	0	0	1.4882498065716456	
i 1	621.2552176870748	0.505	72	387	4	4	11	2	0	1	2	0	0	5.926595144985097	
i 1	621.2584285714286	1.2625	72	387	6	1	9	1	0	0	1	0	0	2.0	
i 1	621.259231292517	0.505	75	387	3	4	15	2	5003	1	2	0	0	5.926595144985097	
i 1	621.2640476190476	1.2625	69	387	4	1	8	1	5003	-1	1	0	0	2.0	
i 1	621.7439795918367	1.7675	72	387	5	3	16	2	0	1	2	0	0	5.926595144985097	
i 1	621.7688639455782	1.7675	72	387	5	3	10	2	5003	-2	2	0	0	5.926595144985097	
i 1	621.9915714285714	0.505	70	1089	2	24	6	8	0	-1	8	0	0	7.0	
i 1	622.0180612244898	0.505	73	387	1	24	10	2	0	-2	2	0	0	7.0	
i 1	622.4811360544218	1.2625	72	1089	6	1	7	1	0	-1	1	0	0	2.0	
i 1	622.4947823129252	1.2625	72	703	6	1	1	1	0	-1	1	0	0	2.0	
i 1	622.4995986394558	1.7675	73	387	2	20	13	8	5003	-2	8	0	0	3.0	
i 1	622.5020068027211	0.2525	75	1089	5	9	1	2	0	1	2	0	0	4.926595144985097	
i 1	622.7343469387755	0.2525	74	387	6	5	3	8	5003	-1	8	0	0	3.0008473025314624	
i 1	622.7391632653062	1.5150000000000001	71	703	6	5	5	8	0	-1	8	0	0	3.0008473025314624	
i 1	622.7536122448979	0.2525	72	387	4	24	1	0	0	-1	0	0	0	3.0	
i 1	622.7576258503401	1.2625	74	1089	6	5	4	2	0	-2	2	0	0	3.0008473025314624	
i 1	622.9843469387755	1.01	75	387	3	4	14	2	5003	1	2	0	0	5.926595144985097	
i 1	622.9987959183674	0.2525	70	1089	2	24	8	8	0	-1	8	0	0	7.0	
i 1	623.0012040816326	1.2625	72	387	4	4	10	2	0	1	2	0	0	5.926595144985097	
i 1	623.7319387755102	1.2625	74	387	6	5	4	8	5003	-1	8	0	0	3.0008473025314624	
i 1	623.7495986394558	0.505	69	387	4	1	13	1	5003	-1	1	0	0	2.0	
i 1	623.7495986394558	1.2625	74	387	6	5	10	8	0	-1	8	0	0	3.0008473025314624	
i 1	623.7552176870748	0.505	72	387	6	1	4	1	0	0	1	0	0	2.0	
i 1	623.764850340136	0.2525	72	387	5	3	13	2	0	1	2	0	0	5.926595144985097	
i 1	623.985149659864	1.01	70	1089	2	24	7	8	0	-1	8	0	0	7.0	
i 1	624.0132448979592	2.02	75	1089	5	9	7	2	0	1	2	0	0	4.926595144985097	
i 1	624.0180612244898	2.02	75	703	4	2	10	2	0	-2	2	0	0	5.926595144985097	
i 1	624.2375578231292	0.2525	73	1089	2	20	8	8	0	-2	8	0	0	3.0	
i 1	624.2520068027211	3.535	72	703	6	1	14	1	0	-1	1	0	0	2.0	
i 1	624.2560204081633	3.535	72	1089	6	1	13	1	0	-1	1	0	0	2.0	
i 1	624.2688639455782	0.7575000000000001	73	387	1	24	6	2	0	-2	2	0	0	7.0	
i 1	624.2696666666667	0.2525	69	703	6	1	12	0	0	0	0	0	0	2.0	
i 1	624.5156530612245	0.2525	74	387	6	5	15	8	5003	-2	8	0	0	3.0008473025314624	
i 1	624.7552176870748	2.02	74	1089	6	5	12	2	0	-2	2	0	0	3.0008473025314624	
i 1	624.7584285714286	1.2625	73	387	2	20	5	8	5003	-2	8	0	0	3.0	
i 1	624.7616394557823	0.2525	73	387	1	20	5	2	0	-1	2	0	0	3.0	
i 1	624.7672585034013	1.01	70	387	2	24	11	2	5003	-1	2	0	0	7.0	
i 1	624.9859523809524	0.2525	71	1089	6	5	7	2	0	-1	2	0	0	3.0008473025314624	
i 1	624.9947823129252	0.2525	72	387	6	1	16	1	0	0	1	0	0	2.0	
i 1	624.9995986394558	1.7675	71	703	6	5	7	8	0	-1	8	0	0	3.0008473025314624	
i 1	625.0036122448979	0.2525	72	703	6	2	16	2	0	1	2	0	0	5.926595144985097	
i 1	625.233544217687	0.2525	74	387	6	5	8	8	5003	-2	8	0	0	3.0008473025314624	
i 1	625.4803333333333	1.01	70	1089	2	24	2	8	0	-1	8	0	0	7.0	
i 1	625.4867551020408	0.2525	74	387	6	5	13	8	5003	-1	8	0	0	3.0008473025314624	
i 1	625.5044149659864	0.2525	72	387	5	3	5	2	5003	-2	2	0	0	5.926595144985097	
i 1	625.7391632653062	0.7575000000000001	75	1089	5	9	15	2	0	1	2	0	0	4.926595144985097	
i 1	625.7672585034013	0.2525	69	387	4	1	9	1	5003	-1	1	0	0	2.0	
i 1	625.7672585034013	0.7575000000000001	72	703	6	2	14	2	0	1	2	0	0	5.926595144985097	
i 1	625.9811360544218	0.2525	73	387	1	24	4	2	0	-2	2	0	0	7.0	
i 1	625.9827414965987	1.7675	75	387	3	4	4	2	5003	1	2	0	0	5.926595144985097	
i 1	626.0036122448979	0.2525	71	1089	6	5	2	2	0	-1	2	0	0	3.0008473025314624	
i 1	626.0068231292518	0.2525	73	703	1	20	3	8	0	-1	8	0	0	3.0	
i 1	626.2367551020408	0.2525	72	1089	4	1	14	0	0	-1	0	0	0	2.0	
i 1	626.2528095238096	0.2525	72	387	5	3	14	2	5003	-2	2	0	0	5.926595144985097	
i 1	626.2560204081633	2.2725	73	387	2	20	9	8	5003	-2	8	0	0	3.0	
i 1	626.2616394557823	0.2525	72	387	5	3	2	2	0	1	2	0	0	5.926595144985097	
i 1	626.266455782313	1.7675	72	387	4	4	12	2	0	1	2	0	0	5.926595144985097	
i 1	626.4867551020408	1.5150000000000001	71	1089	6	5	14	2	0	-1	2	0	0	3.0008473025314624	
i 1	626.5020068027211	1.5150000000000001	74	703	6	5	5	8	0	-1	8	0	0	3.0008473025314624	
i 1	626.5044149659864	0.2525	75	703	4	2	6	2	0	-2	2	0	0	5.926595144985097	
i 1	626.5188639455782	0.2525	72	387	6	1	13	1	0	0	1	0	0	2.0	
i 1	626.9971904761904	0.7575000000000001	72	387	6	1	8	1	0	0	1	0	0	2.0	
i 1	627.0132448979592	0.2525	70	387	2	24	3	2	5003	-1	2	0	0	7.0	
i 1	627.0172585034013	0.2525	72	387	5	3	10	2	0	1	2	0	0	5.926595144985097	
i 1	627.0172585034013	0.2525	74	387	6	5	1	8	0	-2	8	0	0	3.0008473025314624	
i 1	627.2423741496599	1.7675	69	387	4	1	12	1	5003	-1	1	0	0	2.0	
i 1	627.2528095238096	0.2525	74	387	6	5	15	8	0	-1	8	0	0	3.0008473025314624	
i 1	627.2616394557823	2.525	72	387	5	3	7	2	5003	-2	2	0	0	5.926595144985097	
i 1	627.4979931972789	2.2725	72	387	5	3	8	2	0	1	2	0	0	5.926595144985097	
i 1	627.7455850340136	0.505	69	703	6	1	10	0	0	0	0	0	0	2.0	
i 1	627.7536122448979	0.7575000000000001	71	703	6	5	12	8	0	-1	8	0	0	3.0008473025314624	
i 1	627.7544149659864	0.2525	75	387	4	4	15	2	5003	1	2	0	0	5.926595144985097	
i 1	627.7584285714286	0.2525	73	1089	2	20	4	8	0	-2	8	0	0	3.0	
i 1	627.7656530612245	1.5150000000000001	72	387	6	1	12	1	0	0	1	0	0	2.0	
i 1	627.766455782313	1.2625	74	1089	5	5	2	2	0	-2	2	0	0	3.0008473025314624	
i 1	627.9915714285714	0.505	73	387	1	24	8	2	0	-2	2	0	0	7.0	
i 1	628.0036122448979	0.505	73	387	1	20	2	2	0	-1	2	0	0	3.0	
i 1	628.0108367346938	2.525	74	387	6	5	14	8	5003	-2	8	0	0	3.0008473025314624	
i 1	628.0196666666667	2.525	74	387	6	5	4	8	0	-2	8	0	0	3.0008473025314624	
i 1	628.2359523809524	0.2525	73	703	1	20	10	8	0	-1	8	0	0	3.0	
i 1	628.2504013605442	1.2625	70	387	2	24	8	2	5003	-1	2	0	0	7.0	
i 1	628.2672585034013	0.2525	72	703	4	2	6	2	0	1	2	0	0	5.926595144985097	
i 1	628.4979931972789	3.2825	72	1089	6	1	7	1	0	-1	1	0	0	2.0	
i 1	628.5060204081633	3.2825	72	703	6	1	12	1	0	-1	1	0	0	2.0	
i 1	628.7560204081633	0.2525	75	1089	5	9	3	2	0	1	2	0	0	4.926595144985097	
i 1	628.9883605442177	7.8275	73	387	2	20	1	8	5003	-2	8	0	0	3.0	
i 1	628.9915714285714	1.5150000000000001	72	387	4	4	11	2	0	1	2	0	0	5.926595144985097	
i 1	628.9979931972789	0.505	71	703	6	5	16	8	0	-1	8	0	0	3.0008473025314624	
i 1	629.2327414965987	1.2625	75	387	4	4	3	2	5003	1	2	0	0	5.926595144985097	
i 1	629.2616394557823	0.2525	72	1089	6	1	2	0	0	-1	0	0	0	2.0	
i 1	629.490768707483	0.2525	69	387	4	24	5	1	5003	-1	1	0	0	3.0	
i 1	629.509231292517	0.2525	74	703	6	5	13	8	0	-1	8	0	0	3.0008473025314624	
i 1	629.7544149659864	1.01	69	387	4	1	13	1	5003	-1	1	0	0	2.0	
i 1	629.7576258503401	1.01	72	387	6	1	4	1	0	0	1	0	0	2.0	
i 1	629.9819387755102	1.2625	75	703	4	2	12	2	0	-2	2	0	0	5.926595144985097	
i 1	629.9867551020408	1.5150000000000001	75	1089	5	9	4	2	0	1	2	0	0	4.926595144985097	
i 1	629.9963877551021	0.505	73	387	1	24	16	2	0	-2	2	0	0	7.0	
i 1	630.0188639455782	1.01	71	703	6	5	1	8	0	-1	8	0	0	3.0008473025314624	
i 1	630.2552176870748	0.7575000000000001	74	1089	5	5	1	2	0	-2	2	0	0	3.0008473025314624	
i 1	630.4915714285714	2.02	74	387	6	5	3	8	0	-1	8	0	0	3.0008473025314624	
i 1	630.4963877551021	0.2525	72	387	5	3	10	2	0	1	2	0	0	5.926595144985097	
i 1	630.7391632653062	1.7675	75	1089	5	9	15	2	0	1	2	0	0	4.926595144985097	
i 1	630.7512040816326	2.02	72	703	4	2	3	2	0	1	2	0	0	5.926595144985097	
i 1	630.7568231292518	0.2525	69	387	4	24	8	1	5003	-1	1	0	0	3.0	
i 1	630.7608367346938	1.7675	74	387	6	5	5	8	5003	-1	8	0	0	3.0008473025314624	
i 1	630.9955850340136	1.5150000000000001	69	387	4	1	15	1	5003	-1	1	0	0	2.0	
i 1	631.0100340136055	0.2525	74	387	6	5	1	8	0	-2	8	0	0	3.0008473025314624	
i 1	631.0140476190476	1.5150000000000001	72	387	6	1	1	1	0	0	1	0	0	2.0	
i 1	631.5188639455782	0.2525	72	387	5	3	14	2	0	1	2	0	0	5.926595144985097	
i 1	631.5188639455782	0.2525	74	387	6	5	9	8	0	-2	8	0	0	3.0008473025314624	
i 1	631.733544217687	2.2725	71	703	6	5	9	8	0	-1	8	0	0	3.0008473025314624	
i 1	631.7391632653062	0.2525	72	387	4	4	6	2	0	1	2	0	0	5.926595144985097	
i 1	631.7423741496599	0.2525	72	387	4	24	5	0	0	-1	0	0	0	3.0	
i 1	631.7552176870748	2.2725	74	1089	5	5	5	2	0	-2	2	0	0	3.0008473025314624	
i 1	631.9803333333333	1.2625	72	387	5	3	6	2	0	1	2	0	0	5.926595144985097	
i 1	631.9859523809524	1.2625	72	387	5	3	8	2	5003	-2	2	0	0	5.926595144985097	
i 1	631.9955850340136	3.2825	72	703	6	1	7	1	0	-1	1	0	0	2.0	
i 1	632.0076258503401	3.2825	72	1089	6	1	1	1	0	-1	1	0	0	2.0	
i 1	632.0108367346938	0.2525	73	387	1	24	7	2	0	-2	2	0	0	7.0	
i 1	632.4867551020408	0.2525	69	387	4	24	5	1	5003	-1	1	0	0	3.0	
i 1	632.5012040816326	0.2525	71	1089	6	5	7	2	0	-1	2	0	0	3.0008473025314624	
i 1	632.7423741496599	1.5150000000000001	75	387	4	4	2	2	5003	1	2	0	0	5.926595144985097	
i 1	632.7495986394558	1.5150000000000001	72	387	4	4	9	2	0	1	2	0	0	5.926595144985097	
i 1	632.7584285714286	0.2525	74	387	6	5	13	8	0	-1	8	0	0	3.0008473025314624	
i 1	632.7624421768708	0.2525	69	387	4	1	6	1	5003	-1	1	0	0	2.0	
i 1	632.9947823129252	0.2525	72	1089	6	1	1	0	0	-1	0	0	0	2.0	
i 1	633.0044149659864	0.2525	74	387	6	5	15	8	5003	-2	8	0	0	3.0008473025314624	
i 1	633.2303333333333	1.2625	71	1089	6	5	10	2	0	-1	2	0	0	3.0008473025314624	
i 1	633.2391632653062	0.2525	73	1089	2	20	10	8	0	-2	8	0	0	3.0	
i 1	633.2487959183674	0.2525	75	1089	5	9	5	2	0	1	2	0	0	4.926595144985097	
i 1	633.2632448979592	0.505	72	387	4	24	14	0	0	-1	0	0	0	3.0	
i 1	633.485149659864	1.01	72	387	5	3	12	2	5003	-2	2	0	0	5.926595144985097	
i 1	633.4923741496599	0.2525	72	703	4	2	12	2	0	1	2	0	0	5.926595144985097	
i 1	633.4931768707482	1.7675	74	703	6	5	13	8	0	-1	8	0	0	3.0008473025314624	
i 1	633.7656530612245	0.7575000000000001	69	703	6	1	9	0	0	0	0	0	0	2.0	
i 1	633.7656530612245	0.7575000000000001	72	387	5	3	10	2	0	1	2	0	0	5.926595144985097	
i 1	634.0060204081633	0.2525	74	387	6	5	2	8	0	-1	8	0	0	3.0008473025314624	
i 1	634.2367551020408	0.2525	74	1089	5	5	10	2	0	-2	2	0	0	3.0008473025314624	
i 1	634.2415714285714	0.2525	75	1089	5	9	7	2	0	1	2	0	0	4.926595144985097	
i 1	634.4923741496599	0.2525	69	387	4	24	7	1	5003	-1	1	0	0	3.0	
i 1	634.4963877551021	0.2525	72	387	4	24	11	0	0	-1	0	0	0	3.0	
i 1	634.4963877551021	0.2525	72	703	4	2	14	2	0	1	2	0	0	5.926595144985097	
i 1	634.4971904761904	0.7575000000000001	71	1089	5	5	7	2	0	-1	2	0	0	3.0008473025314624	
i 1	634.5028095238096	0.7575000000000001	74	387	6	5	6	8	0	-2	8	0	0	3.0008473025314624	
i 1	634.5044149659864	0.7575000000000001	72	387	4	3	8	2	0	1	2	0	0	5.926595144985097	
i 1	634.5124421768708	1.01	72	387	5	3	4	2	5003	-2	2	0	0	5.926595144985097	
i 1	634.7303333333333	0.505	74	1089	6	5	12	2	0	-2	2	0	0	3.0008473025314624	
i 1	634.7319387755102	1.01	74	387	6	5	15	8	5003	-1	8	0	0	3.0008473025314624	
i 1	634.7327414965987	0.505	72	1089	6	1	15	0	0	-1	0	0	0	2.0	
i 1	634.7399659863945	0.505	75	1089	5	9	2	2	0	1	2	0	0	4.926595144985097	
i 1	634.7471904761904	0.505	71	703	5	5	4	8	0	-1	8	0	0	3.0008473025314624	
i 1	634.7696666666667	0.505	75	703	4	2	4	2	0	-2	2	0	0	5.926595144985097	
i 1	635.2319387755102	0.7575000000000001	72	695	4	3	7	2	0	-2	2	0	0	5.926595144985097	
i 1	635.2319387755102	1.5150000000000001	71	379	6	5	4	8	0	-2	8	0	0	3.0008473025314624	
i 1	635.233544217687	0.2525	70	695	1	24	11	8	0	-1	8	0	0	7.0	
i 1	635.2343469387755	0.2525	74	379	6	5	8	8	0	-2	8	0	0	3.0008473025314624	
i 1	635.235149659864	0.505	74	695	6	5	2	8	0	-2	8	0	0	3.0008473025314624	
i 1	635.2391632653062	0.2525	74	1193	6	5	5	8	0	-2	8	0	0	3.0008473025314624	
i 1	635.2431768707482	9.8475	67	1193	5	14	7	5	0	1	5	0	0	2.238332859264742	
i 1	635.2439795918367	1.5150000000000001	73	379	1	24	5	8	0	-2	8	0	0	7.0	
i 1	635.2455850340136	1.5150000000000001	67	695	4	7	14	0	0	0	0	0	0	1.4882498065716456	
i 1	635.2487959183674	1.5150000000000001	69	379	6	1	15	1	0	0	1	0	0	2.0	
i 1	635.2487959183674	3.535	74	1193	6	5	15	2	0	-1	2	0	0	3.0008473025314624	
i 1	635.2520068027211	6.0600000000000005	69	1193	6	1	8	0	0	-1	0	0	0	2.0	
i 1	635.2568231292518	0.2525	72	1193	6	1	4	0	0	0	0	0	0	2.0	
i 1	635.2568231292518	1.5150000000000001	72	379	5	9	13	2	0	-2	2	0	0	4.926595144985097	
i 1	635.2576258503401	9.8475	67	1193	5	14	3	0	0	1	0	0	0	2.238332859264742	
i 1	635.2600340136055	0.2525	72	379	6	1	5	0	0	-1	0	0	0	2.0	
i 1	635.2632448979592	1.7675	75	1193	5	2	13	2	0	-2	2	0	0	5.926595144985097	
i 1	635.4891632653062	1.2625	69	387	4	24	1	1	5003	-1	1	0	0	3.0	
i 1	635.4939795918367	1.2625	72	695	6	1	16	1	0	0	1	0	0	2.0	
i 1	635.7359523809524	0.505	75	379	5	9	14	2	0	-2	2	0	0	4.926595144985097	
i 1	635.7504013605442	0.2525	74	1193	6	5	6	8	0	-2	8	0	0	3.0008473025314624	
i 1	635.7688639455782	0.2525	73	695	1	24	2	2	0	-2	2	0	0	7.0	
i 1	636.0036122448979	0.2525	74	387	6	5	4	8	5003	-1	8	0	0	3.0008473025314624	
i 1	636.0132448979592	0.2525	75	695	4	4	5	2	0	1	2	0	0	5.926595144985097	
i 1	636.2343469387755	0.505	74	379	6	5	13	8	0	-2	8	0	0	3.0008473025314624	
i 1	636.2359523809524	0.505	72	695	4	3	8	2	0	-2	2	0	0	5.926595144985097	
i 1	636.2423741496599	0.505	72	387	5	3	2	2	5003	-2	2	0	0	5.926595144985097	
i 1	636.2600340136055	0.505	74	695	6	5	11	8	0	-2	8	0	0	3.0008473025314624	
i 1	636.2616394557823	0.505	72	379	6	1	13	0	0	-1	0	0	0	2.0	
i 1	636.733544217687	0.7575000000000001	74	224	6	5	4	8	0	-2	8	0	0	3.0008473025314624	
i 1	636.7343469387755	4.545	72	224	7	1	3	1	0	0	1	0	0	2.0	
i 1	636.7447823129252	2.02	74	224	7	5	10	8	0	-1	8	0	0	3.0008473025314624	
i 1	636.7520068027211	0.2525	69	926	6	1	9	0	0	0	0	0	0	2.0	
i 1	636.7528095238096	0.505	75	224	6	9	8	2	0	-2	2	0	0	4.926595144985097	
i 1	636.7608367346938	0.2525	72	610	4	24	5	1	0	-1	1	0	0	3.0	
i 1	636.7616394557823	38.6325	67	926	4	7	15	0	0	0	0	0	0	1.4882498065716456	
i 1	636.7624421768708	0.505	72	224	7	1	15	1	0	0	1	0	0	2.0	
i 1	636.7624421768708	4.545	70	610	2	20	13	8	0	-1	8	0	0	3.0	
i 1	636.764850340136	3.535	72	610	5	3	14	2	0	1	2	0	0	5.926595144985097	
i 1	636.7656530612245	1.01	72	926	4	3	4	2	0	-2	2	0	0	5.926595144985097	
i 1	636.7656530612245	0.2525	74	610	6	5	14	2	0	-1	2	0	0	3.0008473025314624	
i 1	636.7688639455782	4.545	73	224	1	24	7	8	0	-2	8	0	0	7.0	
i 1	637.014850340136	0.2525	74	926	6	5	1	8	0	-2	8	0	0	3.0008473025314624	
i 1	637.266455782313	0.2525	72	1193	6	1	8	0	0	0	0	0	0	2.0	
i 1	637.266455782313	1.7675	72	224	6	9	13	8	0	-2	8	0	0	4.926595144985097	
i 1	637.2680612244898	0.505	72	926	4	24	9	1	0	0	1	0	0	3.0	
i 1	637.2688639455782	1.7675	75	1193	5	2	12	2	0	-2	2	0	0	5.926595144985097	
i 1	637.4803333333333	0.2525	74	926	6	5	8	2	0	-2	2	0	0	3.0008473025314624	
i 1	637.7319387755102	0.2525	72	224	7	1	15	1	0	0	1	0	0	2.0	
i 1	637.7431768707482	2.2725	74	224	6	5	6	8	0	-2	8	0	0	3.0008473025314624	
i 1	637.7536122448979	0.2525	69	926	6	1	2	0	0	0	0	0	0	2.0	
i 1	637.7560204081633	2.02	74	1193	6	5	4	8	0	-2	8	0	0	3.0008473025314624	
i 1	637.766455782313	0.505	75	224	6	9	3	2	0	-2	2	0	0	4.926595144985097	
i 1	638.0060204081633	0.2525	72	926	4	24	16	1	0	0	1	0	0	3.0	
i 1	638.2423741496599	2.02	72	926	4	3	2	2	0	-2	2	0	0	5.926595144985097	
i 1	638.4827414965987	0.2525	69	926	6	1	6	0	0	0	0	0	0	2.0	
i 1	638.514850340136	0.2525	72	224	7	1	13	1	0	0	1	0	0	2.0	
i 1	638.7375578231292	0.505	72	1193	6	1	10	0	0	0	0	0	0	2.0	
i 1	638.7560204081633	0.2525	74	610	6	5	5	2	0	-2	2	0	0	3.0008473025314624	
i 1	638.764850340136	0.2525	74	926	6	5	5	2	0	-2	2	0	0	3.0008473025314624	
i 1	638.9867551020408	2.02	74	1193	6	5	9	2	0	-1	2	0	0	3.0008473025314624	
i 1	638.9875578231292	1.5150000000000001	72	926	4	4	15	2	0	1	2	0	0	5.926595144985097	
i 1	638.9899659863945	2.02	74	224	7	5	11	8	0	-1	8	0	0	3.0008473025314624	
i 1	639.2383605442177	1.5150000000000001	70	224	1	20	15	8	0	-1	8	0	0	3.0	
i 1	639.240768707483	0.2525	72	926	4	24	12	1	0	0	1	0	0	3.0	
i 1	639.2504013605442	1.5150000000000001	73	610	2	24	4	2	0	-1	2	0	0	7.0	
i 1	639.2520068027211	0.2525	70	224	1	20	15	8	0	-1	8	0	0	3.0	
i 1	639.2632448979592	1.2625	75	610	4	4	6	2	0	-2	2	0	0	5.926595144985097	
i 1	639.2656530612245	0.2525	72	610	4	24	1	1	0	-1	1	0	0	3.0	
i 1	639.4803333333333	0.2525	73	926	1	20	10	2	0	-2	2	0	0	3.0	
i 1	639.4859523809524	0.2525	73	926	1	24	8	8	0	-2	8	0	0	7.0	
i 1	639.4939795918367	0.2525	70	1193	2	20	11	2	0	-1	2	0	0	3.0	
i 1	639.4995986394558	0.2525	69	610	6	1	11	0	0	0	0	0	0	2.0	
i 1	639.5028095238096	3.0300000000000002	72	224	6	9	13	8	0	-2	8	0	0	4.926595144985097	
i 1	639.5060204081633	0.2525	72	1193	6	1	2	0	0	0	0	0	0	2.0	
i 1	639.514850340136	3.0300000000000002	75	1193	5	2	14	2	0	-2	2	0	0	5.926595144985097	
i 1	639.5156530612245	0.2525	73	1193	2	20	11	2	0	-2	2	0	0	3.0	
i 1	639.7544149659864	0.2525	74	926	6	5	4	2	0	-2	2	0	0	3.0008473025314624	
i 1	639.7584285714286	0.505	73	224	1	20	11	8	0	-2	8	0	0	3.0	
i 1	639.7640476190476	0.505	70	224	1	20	7	8	0	-2	8	0	0	3.0	
i 1	639.9923741496599	0.2525	69	926	6	1	13	0	0	0	0	0	0	2.0	
i 1	640.0180612244898	1.2625	74	1193	6	5	7	8	0	-2	8	0	0	3.0008473025314624	
i 1	640.2343469387755	1.01	74	224	6	5	2	8	0	-2	8	0	0	3.0008473025314624	
i 1	640.2415714285714	0.2525	73	926	1	24	10	2	0	-1	2	0	0	7.0	
i 1	640.2423741496599	1.01	74	610	6	5	15	2	0	-1	2	0	0	3.0008473025314624	
i 1	640.2487959183674	0.2525	70	1193	2	20	13	2	0	-2	2	0	0	3.0	
i 1	640.2504013605442	1.5150000000000001	72	1193	6	1	15	0	0	0	0	0	0	2.0	
i 1	640.2512040816326	1.5150000000000001	72	224	7	1	3	1	0	0	1	0	0	2.0	
i 1	640.2560204081633	1.01	74	926	6	5	3	8	0	-2	8	0	0	3.0008473025314624	
i 1	640.259231292517	0.2525	70	1193	2	20	15	8	0	-2	8	0	0	3.0	
i 1	640.2632448979592	0.2525	70	926	1	20	6	2	0	-1	2	0	0	3.0	
i 1	640.4987959183674	0.505	70	224	1	20	6	2	0	-1	2	0	0	3.0	
i 1	640.4995986394558	0.2525	72	926	4	3	1	2	0	-2	2	0	0	5.926595144985097	
i 1	640.5012040816326	0.505	72	1193	5	2	11	2	0	1	2	0	0	5.926595144985097	
i 1	640.5140476190476	0.2525	70	224	1	20	10	8	0	-2	8	0	0	3.0	
i 1	640.7367551020408	0.2525	75	610	4	4	6	2	0	-2	2	0	0	5.926595144985097	
i 1	640.9899659863945	0.2525	72	610	5	3	5	2	0	1	2	0	0	5.926595144985097	
i 1	640.9931768707482	2.525	75	224	6	9	15	2	0	-2	2	0	0	4.926595144985097	
i 1	641.2399659863945	2.2725	72	1193	5	2	4	2	0	1	2	0	0	5.926595144985097	
i 1	641.2399659863945	3.7875	74	1193	6	5	9	2	0	-1	2	0	0	3.0008473025314624	
i 1	641.2423741496599	1.5150000000000001	74	224	7	5	13	8	0	-2	8	0	0	3.0008473025314624	
i 1	641.2520068027211	0.2525	74	224	7	5	9	8	0	-1	8	0	0	3.0008473025314624	
i 1	641.2608367346938	4.545	73	224	1	24	2	8	0	-2	8	0	0	4.0	
i 1	641.2640476190476	1.5150000000000001	74	1193	6	5	11	8	0	-2	8	0	0	3.0008473025314624	
i 1	641.264850340136	3.7875	69	1193	5	1	4	0	0	-1	0	0	0	2.0	
i 1	641.264850340136	3.7875	72	224	7	1	4	1	0	0	1	0	0	2.0	
i 1	641.490768707483	3.535	69	610	6	1	12	0	0	0	0	0	0	2.0	
i 1	641.5108367346938	2.02	69	926	6	1	13	0	0	0	0	0	0	2.0	
i 1	641.5132448979592	0.2525	74	610	6	5	7	2	0	-2	2	0	0	3.0008473025314624	
i 1	641.7600340136055	3.7875	74	224	7	5	7	8	0	-1	8	0	0	3.0008473025314624	
i 1	642.4931768707482	2.525	72	610	5	3	10	2	0	1	2	0	0	5.926595144985097	
i 1	642.5196666666667	3.0300000000000002	72	926	4	3	8	2	0	-2	2	0	0	5.926595144985097	
i 1	642.7375578231292	1.5150000000000001	74	926	6	5	12	2	0	-2	2	0	0	3.0008473025314624	
i 1	642.7560204081633	1.5150000000000001	74	610	6	5	10	2	0	-2	2	0	0	3.0008473025314624	
i 1	643.2520068027211	1.7675	75	1193	5	2	3	2	0	-2	2	0	0	5.926595144985097	
i 1	643.2552176870748	1.5150000000000001	72	224	6	9	13	8	0	-2	8	0	0	4.926595144985097	
i 1	643.5060204081633	0.2525	72	610	4	24	11	1	0	-1	1	0	0	3.0	
i 1	643.7495986394558	1.7675	69	926	6	1	10	0	0	0	0	0	0	2.0	
i 1	644.2600340136055	0.7575000000000001	74	1193	6	5	5	8	0	-2	8	0	0	3.0008473025314624	
i 1	644.2608367346938	0.2525	74	224	7	5	11	8	0	-2	8	0	0	3.0008473025314624	
i 1	644.483544217687	0.505	74	610	5	5	3	2	0	-1	2	0	0	3.0008473025314624	
i 1	644.4883605442177	4.04	75	224	6	9	9	2	0	-2	2	0	0	4.926595144985097	
i 1	644.5084285714286	3.535	72	224	7	1	15	1	0	0	1	0	0	2.0	
i 1	644.9971904761904	1.5150000000000001	71	722	5	5	12	2	0	-2	2	0	0	3.0008473025314624	
i 1	644.9987959183674	9.8475	67	1108	4	14	16	5	0	1	5	0	0	2.238332859264742	
i 1	645.0004013605442	1.01	75	722	5	3	10	2	0	-2	2	0	0	5.926595144985097	
i 1	645.0004013605442	16.665	60	1108	4	14	13	5	0	0	5	0	0	2.238332859264742	
i 1	645.0012040816326	1.7675	74	1108	5	5	3	8	0	-2	8	0	0	3.0008473025314624	
i 1	645.0044149659864	3.0300000000000002	72	1108	4	2	15	2	0	-2	2	0	0	5.926595144985097	
i 1	645.0052176870748	4.04	69	1108	4	1	12	1	0	-1	1	0	0	2.0	
i 1	645.0052176870748	1.5150000000000001	71	1108	5	5	3	8	0	-1	8	0	0	3.0008473025314624	
i 1	645.0060204081633	0.505	69	722	6	1	8	1	0	-1	1	0	0	2.0	
i 1	645.4843469387755	0.2525	75	722	4	4	4	8	0	1	8	0	0	5.926595144985097	
i 1	645.4883605442177	1.7675	74	224	7	5	5	8	0	-2	8	0	0	3.0008473025314624	
i 1	645.4947823129252	0.7575000000000001	72	224	7	1	4	1	0	0	1	0	0	2.0	
i 1	645.4995986394558	0.2525	72	926	4	24	3	1	0	0	1	0	0	3.0	
i 1	645.733544217687	2.2725	74	722	6	5	14	8	0	-2	8	0	0	3.0008473025314624	
i 1	645.7608367346938	2.2725	75	1108	4	2	11	8	0	-2	8	0	0	5.926595144985097	
i 1	645.7616394557823	2.2725	74	926	6	5	16	8	0	-2	8	0	0	3.0008473025314624	
i 1	645.7672585034013	0.2525	69	1108	6	1	5	1	0	0	1	0	0	2.0	
i 1	645.9827414965987	0.2525	72	926	4	3	5	2	0	-2	2	0	0	5.926595144985097	
i 1	646.0140476190476	0.2525	69	722	4	24	8	0	0	0	0	0	0	3.0	
i 1	646.2471904761904	1.7675	69	1108	6	1	12	1	0	0	1	0	0	2.0	
i 1	646.2528095238096	1.7675	75	722	5	3	11	2	0	-2	2	0	0	5.926595144985097	
i 1	646.2576258503401	1.7675	69	722	6	1	4	1	0	-1	1	0	0	2.0	
i 1	646.7455850340136	4.545	73	224	1	24	9	8	0	-2	8	0	0	4.0	
i 1	646.7640476190476	0.2525	74	224	7	5	9	8	0	-1	8	0	0	3.0008473025314624	
i 1	647.0100340136055	0.2525	74	926	6	5	13	2	0	-2	2	0	0	3.0008473025314624	
i 1	647.0124421768708	3.7875	75	722	4	4	2	8	0	1	8	0	0	5.926595144985097	
i 1	647.0180612244898	3.535	72	926	4	3	12	2	0	-2	2	0	0	5.926595144985097	
i 1	647.2479931972789	0.2525	73	926	1	24	2	8	0	-2	8	0	0	4.0	
i 1	647.2528095238096	2.02	71	1108	5	5	3	8	0	-1	8	0	0	3.0008473025314624	
i 1	647.266455782313	0.7575000000000001	71	722	5	5	9	2	0	-2	2	0	0	3.0008473025314624	
i 1	647.7319387755102	0.2525	73	926	1	24	6	8	0	-2	8	0	0	4.0	
i 1	647.9867551020408	1.01	72	224	7	1	13	1	0	0	1	0	0	2.0	
i 1	647.9947823129252	2.525	69	722	4	24	15	0	0	0	0	0	0	3.0	
i 1	647.9947823129252	0.7575000000000001	72	1108	6	2	9	2	0	-2	2	0	0	5.926595144985097	
i 1	647.9955850340136	5.05	69	926	6	1	14	0	0	0	0	0	0	2.0	
i 1	647.9987959183674	0.2525	74	926	5	5	16	8	0	-2	8	0	0	3.0008473025314624	
i 1	648.0036122448979	1.2625	71	722	6	5	3	2	0	-2	2	0	0	3.0008473025314624	
i 1	648.0052176870748	0.2525	74	722	5	5	12	8	0	-2	8	0	0	3.0008473025314624	
i 1	648.2311360544218	1.5150000000000001	74	224	7	5	10	8	0	-2	8	0	0	3.0008473025314624	
i 1	648.2327414965987	1.5150000000000001	74	1108	5	5	8	8	0	-2	8	0	0	3.0008473025314624	
i 1	648.509231292517	0.2525	72	926	4	4	16	2	0	1	2	0	0	5.926595144985097	
i 1	648.7359523809524	0.505	72	224	4	9	5	8	0	-2	8	0	0	4.926595144985097	
i 1	648.7423741496599	2.2725	74	926	6	5	6	2	0	-2	2	0	0	3.0008473025314624	
i 1	648.7672585034013	0.2525	75	224	6	9	12	2	0	-2	2	0	0	4.926595144985097	
i 1	648.7672585034013	2.525	74	224	7	5	10	8	0	-1	8	0	0	3.0008473025314624	
i 1	649.0020068027211	0.2525	70	926	1	24	7	8	0	-1	8	0	0	4.0	
i 1	649.0044149659864	0.505	72	926	4	24	13	1	0	0	1	0	0	3.0	
i 1	649.009231292517	0.505	69	1108	4	1	1	1	0	0	1	0	0	2.0	
i 1	649.2552176870748	0.2525	72	926	4	4	6	2	0	1	2	0	0	5.926595144985097	
i 1	649.2640476190476	3.2825	72	1108	6	2	6	2	0	-2	2	0	0	5.926595144985097	
i 1	649.4859523809524	3.0300000000000002	75	224	6	9	9	2	0	-2	2	0	0	4.926595144985097	
i 1	649.5140476190476	2.2725	69	1108	4	1	15	1	0	-1	1	0	0	2.0	
i 1	649.516455782313	2.2725	72	224	7	1	14	1	0	0	1	0	0	2.0	
i 1	649.7520068027211	0.2525	71	1108	5	5	9	8	0	-1	8	0	0	3.0008473025314624	
i 1	649.7552176870748	0.2525	74	722	5	5	2	8	0	-2	8	0	0	3.0008473025314624	
i 1	649.9923741496599	2.2725	74	224	7	5	4	8	0	-2	8	0	0	3.0008473025314624	
i 1	650.0172585034013	2.2725	74	1108	5	5	1	8	0	-2	8	0	0	3.0008473025314624	
i 1	650.2343469387755	0.505	70	926	1	24	6	2	0	-2	2	0	0	4.0	
i 1	650.5020068027211	0.2525	72	224	4	9	1	8	0	-2	8	0	0	4.926595144985097	
i 1	650.5196666666667	0.2525	72	926	4	24	1	1	0	0	1	0	0	3.0	
i 1	650.7367551020408	0.2525	72	926	4	3	3	2	0	-2	2	0	0	5.926595144985097	
i 1	650.7391632653062	2.525	69	722	4	24	3	0	0	0	0	0	0	3.0	
i 1	650.7399659863945	0.2525	72	926	4	4	4	2	0	1	2	0	0	5.926595144985097	
i 1	650.9819387755102	0.2525	75	1108	4	2	9	8	0	-2	8	0	0	5.926595144985097	
i 1	650.9923741496599	2.7775	71	722	6	5	3	2	0	-2	2	0	0	3.0008473025314624	
i 1	651.259231292517	0.2525	72	926	4	4	4	2	0	1	2	0	0	5.926595144985097	
i 1	651.2656530612245	2.525	71	1108	5	5	5	8	0	-1	8	0	0	3.0008473025314624	
i 1	651.485149659864	1.5150000000000001	75	722	5	3	13	2	0	-2	2	0	0	5.926595144985097	
i 1	651.4923741496599	1.5150000000000001	75	1108	4	2	5	8	0	-2	8	0	0	5.926595144985097	
i 1	651.733544217687	0.2525	72	224	7	1	4	1	0	0	1	0	0	2.0	
i 1	651.733544217687	4.7975	72	926	4	3	1	2	0	-2	2	0	0	5.926595144985097	
i 1	651.7504013605442	1.7675	73	224	1	24	11	8	0	-2	8	0	0	4.0	
i 1	651.7512040816326	0.2525	69	722	6	1	3	1	0	-1	1	0	0	2.0	
i 1	651.759231292517	4.7975	75	722	4	4	5	8	0	1	8	0	0	5.926595144985097	
i 1	652.0068231292518	3.535	69	1108	4	1	13	1	0	-1	1	0	0	2.0	
i 1	652.0124421768708	3.2825	72	224	7	1	12	1	0	0	1	0	0	2.0	
i 1	652.2367551020408	0.2525	74	926	5	5	13	8	0	-2	8	0	0	3.0008473025314624	
i 1	652.2423741496599	0.505	70	926	1	24	16	8	0	-1	8	0	0	4.0	
i 1	652.264850340136	0.505	74	722	5	5	3	8	0	-2	8	0	0	3.0008473025314624	
i 1	652.5084285714286	2.2725	74	224	7	5	2	8	0	-2	8	0	0	3.0008473025314624	
i 1	652.7479931972789	2.02	74	1108	5	5	16	8	0	-2	8	0	0	3.0008473025314624	
i 1	652.9875578231292	0.2525	69	1108	4	1	11	1	0	0	1	0	0	2.0	
i 1	652.9915714285714	1.7675	75	224	6	9	9	2	0	-2	2	0	0	4.926595144985097	
i 1	653.0020068027211	1.7675	72	1108	6	2	13	2	0	-2	2	0	0	5.926595144985097	
i 1	653.2367551020408	0.2525	69	722	6	1	7	1	0	-1	1	0	0	2.0	
i 1	653.2536122448979	0.2525	69	926	6	1	14	0	0	0	0	0	0	2.0	
i 1	653.7560204081633	0.2525	69	722	4	24	2	0	0	0	0	0	0	3.0	
i 1	653.7560204081633	1.7675	74	926	5	5	5	8	0	-2	8	0	0	3.0008473025314624	
i 1	653.7576258503401	1.01	74	722	5	5	3	8	0	-2	8	0	0	3.0008473025314624	
i 1	653.9899659863945	0.2525	72	224	7	1	13	1	0	0	1	0	0	2.0	
i 1	654.0172585034013	2.7775	69	1108	4	1	16	1	0	0	1	0	0	2.0	
i 1	654.2343469387755	2.2725	71	1108	5	5	1	8	0	-1	8	0	0	3.0008473025314624	
i 1	654.2560204081633	0.505	69	722	6	1	12	1	0	-1	1	0	0	2.0	
i 1	654.2608367346938	2.2725	71	722	6	5	13	2	0	-2	2	0	0	3.0008473025314624	
i 1	654.5036122448979	1.2625	73	224	1	24	5	8	0	-2	8	0	0	4.0	
i 1	654.7431768707482	27.27	67	1108	5	14	5	5	0	1	5	0	0	2.238332859264742	
i 1	654.7528095238096	0.505	74	722	6	5	7	8	0	-2	8	0	0	3.0008473025314624	
i 1	654.7576258503401	0.2525	75	224	4	9	16	2	0	-2	2	0	0	4.926595144985097	
i 1	654.7616394557823	2.02	69	722	6	1	8	1	0	-1	1	0	0	2.0	
i 1	654.7680612244898	0.505	72	926	4	4	8	2	0	1	2	0	0	5.926595144985097	
i 1	654.9867551020408	0.2525	72	1108	6	2	6	2	0	-2	2	0	0	5.926595144985097	
i 1	655.0036122448979	0.2525	70	926	1	24	11	8	0	-2	8	0	0	4.0	
i 1	655.2303333333333	6.8175	74	224	7	5	7	8	0	-2	8	0	0	3.0008473025314624	
i 1	655.2311360544218	0.2525	75	1108	6	2	12	8	0	-2	8	0	0	5.926595144985097	
i 1	655.2343469387755	0.2525	72	224	4	9	5	8	0	-2	8	0	0	4.926595144985097	
i 1	655.2455850340136	0.2525	69	926	4	1	6	0	0	0	0	0	0	2.0	
i 1	655.4995986394558	2.7775	75	224	4	9	12	2	0	-2	2	0	0	4.926595144985097	
i 1	655.5020068027211	0.2525	72	926	4	24	2	1	0	0	1	0	0	3.0	
i 1	655.5100340136055	6.565	74	1108	5	5	10	8	0	-2	8	0	0	3.0008473025314624	
i 1	655.5108367346938	0.2525	72	224	7	1	11	1	0	0	1	0	0	2.0	
i 1	655.5156530612245	2.7775	72	1108	6	2	10	2	0	-2	2	0	0	5.926595144985097	
i 1	655.7487959183674	2.2725	69	1108	4	1	11	1	0	-1	1	0	0	2.0	
i 1	655.7544149659864	2.2725	72	224	7	1	6	1	0	0	1	0	0	2.0	
i 1	656.4947823129252	1.2625	74	926	5	5	1	2	0	-2	2	0	0	3.0008473025314624	
i 1	656.4995986394558	0.2525	75	722	5	3	6	2	0	-2	2	0	0	5.926595144985097	
i 1	656.5084285714286	0.2525	72	224	4	9	12	8	0	-2	8	0	0	4.926595144985097	
i 1	656.516455782313	1.5150000000000001	74	224	7	5	12	8	0	-1	8	0	0	3.0008473025314624	
i 1	656.735149659864	2.2725	75	1108	6	2	6	8	0	-2	8	0	0	5.926595144985097	
i 1	656.7423741496599	0.2525	72	926	4	24	8	1	0	0	1	0	0	3.0	
i 1	656.7616394557823	0.505	72	926	4	4	14	2	0	1	2	0	0	5.926595144985097	
i 1	656.764850340136	3.535	69	722	4	24	1	0	0	0	0	0	0	3.0	
i 1	657.0052176870748	3.2825	69	926	4	1	8	0	0	0	0	0	0	2.0	
i 1	657.2383605442177	1.7675	75	722	5	3	10	2	0	-2	2	0	0	5.926595144985097	
i 1	657.7415714285714	0.2525	73	926	1	24	16	2	0	-1	2	0	0	4.0	
i 1	657.7584285714286	0.2525	74	722	6	5	5	8	0	-2	8	0	0	3.0008473025314624	
i 1	657.9811360544218	3.0300000000000002	72	926	4	3	8	2	0	-2	2	0	0	5.926595144985097	
i 1	657.9811360544218	0.7575000000000001	71	1108	5	5	14	8	0	-1	8	0	0	3.0008473025314624	
i 1	657.9827414965987	0.2525	69	1108	4	1	11	1	0	0	1	0	0	2.0	
i 1	657.9827414965987	3.2825	75	722	4	4	7	8	0	1	8	0	0	5.926595144985097	
i 1	657.9971904761904	0.2525	72	926	4	24	1	1	0	0	1	0	0	3.0	
i 1	658.0180612244898	0.2525	74	926	5	5	14	8	0	-2	8	0	0	3.0008473025314624	
i 1	658.2439795918367	3.2825	69	1108	4	1	7	1	0	-1	1	0	0	2.0	
i 1	658.2520068027211	5.8075	72	224	7	1	6	1	0	0	1	0	0	2.0	
i 1	658.2544149659864	0.2525	74	224	7	5	16	8	0	-1	8	0	0	3.0008473025314624	
i 1	658.2624421768708	2.525	73	224	1	24	12	8	0	-2	8	0	0	4.0	
i 1	658.4955850340136	0.505	74	926	5	5	11	2	0	-2	2	0	0	3.0008473025314624	
i 1	658.7584285714286	0.505	74	224	7	5	2	8	0	-1	8	0	0	3.0008473025314624	
i 1	658.766455782313	0.2525	70	926	1	24	1	8	0	-2	8	0	0	4.0	
i 1	658.985149659864	1.7675	71	1108	5	5	6	8	0	-1	8	0	0	3.0008473025314624	
i 1	659.0004013605442	5.05	75	224	4	9	13	2	0	-2	2	0	0	4.926595144985097	
i 1	659.0156530612245	5.05	72	1108	6	2	9	2	0	-2	2	0	0	5.926595144985097	
i 1	659.2512040816326	1.2625	71	722	6	5	12	2	0	-2	2	0	0	3.0008473025314624	
i 1	659.9947823129252	0.2525	73	926	1	24	7	2	0	-2	2	0	0	4.0	
i 1	660.2487959183674	0.2525	72	224	7	1	15	1	0	0	1	0	0	2.0	
i 1	660.4883605442177	0.505	74	722	6	5	14	8	0	-2	8	0	0	3.0008473025314624	
i 1	660.5180612244898	0.505	69	926	4	1	3	0	0	0	0	0	0	2.0	
i 1	660.7520068027211	0.2525	74	224	7	5	10	8	0	-1	8	0	0	3.0008473025314624	
i 1	660.9883605442177	0.2525	69	1108	4	1	6	1	0	0	1	0	0	2.0	
i 1	660.9899659863945	1.7675	74	926	5	5	5	8	0	-2	8	0	0	3.0008473025314624	
i 1	660.9947823129252	0.505	72	926	4	24	13	1	0	0	1	0	0	3.0	
i 1	661.235149659864	0.2525	72	224	4	9	10	8	0	-2	8	0	0	4.926595144985097	
i 1	661.2528095238096	1.5150000000000001	74	722	6	5	10	8	0	-2	8	0	0	3.0008473025314624	
i 1	661.2680612244898	0.505	72	224	7	1	1	1	0	0	1	0	0	2.0	
i 1	661.4827414965987	27.27	60	1108	5	14	2	5	0	0	5	0	0	2.238332859264742	
i 1	661.4867551020408	0.2525	72	926	4	4	14	2	0	1	2	0	0	5.926595144985097	
i 1	661.5020068027211	2.7775	69	1108	6	1	7	1	0	-1	1	0	0	2.0	
i 1	661.5076258503401	0.2525	75	1108	6	2	12	8	0	-2	8	0	0	5.926595144985097	
i 1	661.5140476190476	0.2525	69	722	6	1	10	1	0	-1	1	0	0	2.0	
i 1	661.7463877551021	0.2525	69	722	4	24	13	0	0	0	0	0	0	3.0	
i 1	661.7520068027211	0.2525	69	926	4	1	3	0	0	0	0	0	0	2.0	
i 1	661.7568231292518	0.7575000000000001	72	926	5	3	9	2	0	-2	2	0	0	5.926595144985097	
i 1	661.9883605442177	1.2625	71	722	6	5	10	2	0	-2	2	0	0	3.0008473025314624	
i 1	661.990768707483	1.5150000000000001	71	1108	5	5	2	8	0	-1	8	0	0	3.0008473025314624	
i 1	662.2319387755102	2.2725	74	1108	5	5	16	8	0	-2	8	0	0	3.0008473025314624	
i 1	662.2600340136055	2.2725	74	224	7	5	1	8	0	-2	8	0	0	3.0008473025314624	
i 1	662.2616394557823	0.2525	69	722	4	24	11	0	0	0	0	0	0	3.0	
i 1	662.2640476190476	0.505	72	926	4	24	8	1	0	0	1	0	0	3.0	
i 1	662.483544217687	0.2525	75	1108	6	2	6	8	0	-2	8	0	0	5.926595144985097	
i 1	662.514850340136	0.2525	75	722	3	3	15	2	0	-2	2	0	0	5.926595144985097	
i 1	662.7311360544218	0.2525	72	224	4	9	14	8	0	-2	8	0	0	4.926595144985097	
i 1	662.733544217687	1.01	73	224	1	24	4	8	0	-2	8	0	0	4.0	
i 1	662.7520068027211	0.2525	75	722	4	4	13	8	0	1	8	0	0	5.926595144985097	
i 1	662.7696666666667	0.2525	69	1108	4	1	6	1	0	0	1	0	0	2.0	
i 1	662.9915714285714	0.2525	69	926	4	1	2	0	0	0	0	0	0	2.0	
i 1	663.0076258503401	0.505	72	224	7	1	3	1	0	0	1	0	0	2.0	
i 1	663.0180612244898	0.2525	70	926	1	24	12	8	0	-2	8	0	0	4.0	
i 1	663.0196666666667	1.7675	75	722	3	3	5	2	0	-2	2	0	0	5.926595144985097	
i 1	663.2319387755102	1.5150000000000001	75	1108	6	2	11	8	0	-2	8	0	0	5.926595144985097	
i 1	663.2455850340136	0.2525	74	722	6	5	9	8	0	-2	8	0	0	3.0008473025314624	
i 1	663.4811360544218	2.02	69	1108	4	1	11	1	0	0	1	0	0	2.0	
i 1	663.4987959183674	0.2525	71	722	6	5	9	2	0	-2	2	0	0	3.0008473025314624	
i 1	663.5060204081633	2.02	69	722	6	1	13	1	0	-1	1	0	0	2.0	
i 1	663.7504013605442	1.7675	74	926	5	5	16	2	0	-2	2	0	0	3.0008473025314624	
i 1	663.7608367346938	2.02	74	224	5	5	11	8	0	-1	8	0	0	3.0008473025314624	
i 1	663.990768707483	3.2825	72	926	5	3	3	2	0	-2	2	0	0	5.926595144985097	
i 1	664.0172585034013	0.2525	72	224	4	9	7	8	0	-2	8	0	0	4.926595144985097	
i 1	664.2383605442177	0.2525	72	224	7	1	9	1	0	0	1	0	0	2.0	
i 1	664.2383605442177	3.2825	75	722	4	4	2	8	0	1	8	0	0	5.926595144985097	
i 1	664.2680612244898	0.2525	73	224	1	24	3	8	0	-2	8	0	0	4.0	
i 1	664.4803333333333	1.2625	69	1108	6	1	13	1	0	-1	1	0	0	2.0	
i 1	664.4867551020408	1.01	72	1108	6	2	15	2	0	-2	2	0	0	5.926595144985097	
i 1	664.4971904761904	0.2525	71	1108	5	5	6	8	0	-1	8	0	0	3.0008473025314624	
i 1	664.509231292517	1.2625	75	224	4	9	8	2	0	-2	2	0	0	4.926595144985097	
i 1	664.7399659863945	2.7775	72	224	7	1	2	1	0	0	1	0	0	2.0	
i 1	664.7536122448979	2.7775	74	224	7	5	3	8	0	-2	8	0	0	3.0008473025314624	
i 1	664.7672585034013	2.7775	74	1108	5	5	1	8	0	-2	8	0	0	3.0008473025314624	
i 1	665.0012040816326	1.5150000000000001	73	224	1	24	9	8	0	-2	8	0	0	4.0	
i 1	665.2383605442177	1.2625	69	722	4	24	5	0	0	0	0	0	0	3.0	
i 1	665.2447823129252	1.2625	69	926	4	1	4	0	0	0	0	0	0	2.0	
i 1	665.4827414965987	0.7575000000000001	71	722	6	5	4	2	0	-2	2	0	0	3.0008473025314624	
i 1	665.4915714285714	0.505	73	926	1	24	15	8	0	-2	8	0	0	4.0	
i 1	665.7343469387755	0.2525	72	224	4	9	1	8	0	-2	8	0	0	4.926595144985097	
i 1	665.7399659863945	0.2525	74	926	5	5	1	2	0	-2	2	0	0	3.0008473025314624	
i 1	665.9939795918367	0.2525	75	224	4	9	6	2	0	-2	2	0	0	4.926595144985097	
i 1	666.0068231292518	0.2525	74	926	5	5	10	8	0	-2	8	0	0	3.0008473025314624	
i 1	666.0180612244898	1.7675	69	1108	6	1	16	1	0	-1	1	0	0	2.0	
i 1	666.0180612244898	0.2525	75	722	3	3	15	2	0	-2	2	0	0	5.926595144985097	
i 1	666.2319387755102	0.2525	74	926	5	5	1	2	0	-2	2	0	0	3.0008473025314624	
i 1	666.2520068027211	0.2525	74	224	5	5	14	8	0	-1	8	0	0	3.0008473025314624	
i 1	666.4803333333333	1.7675	71	1108	5	5	4	8	0	-1	8	0	0	3.0008473025314624	
i 1	666.4931768707482	1.7675	71	722	6	5	6	2	0	-2	2	0	0	3.0008473025314624	
i 1	666.4979931972789	0.2525	69	722	6	1	11	1	0	-1	1	0	0	2.0	
i 1	666.5020068027211	0.2525	75	1108	6	2	14	8	0	-2	8	0	0	5.926595144985097	
i 1	666.5044149659864	0.2525	72	926	4	4	1	2	0	1	2	0	0	5.926595144985097	
i 1	666.7327414965987	0.2525	72	926	4	24	8	1	0	0	1	0	0	3.0	
i 1	666.7431768707482	2.2725	72	1108	6	2	8	2	0	-2	2	0	0	5.926595144985097	
i 1	666.7656530612245	2.2725	75	224	4	9	16	2	0	-2	2	0	0	4.926595144985097	
i 1	666.9883605442177	2.02	69	722	4	24	15	0	0	0	0	0	0	3.0	
i 1	666.9931768707482	2.02	69	926	4	1	7	0	0	0	0	0	0	2.0	
i 1	667.4899659863945	0.505	72	926	4	4	16	2	0	1	2	0	0	5.926595144985097	
i 1	667.5108367346938	0.2525	74	224	5	5	4	8	0	-1	8	0	0	3.0008473025314624	
i 1	667.7383605442177	0.7575000000000001	73	224	1	24	11	8	0	-2	8	0	0	4.0	
i 1	667.7552176870748	0.2525	69	1108	4	1	10	1	0	0	1	0	0	2.0	
i 1	667.7616394557823	0.7575000000000001	74	1108	5	5	12	8	0	-2	8	0	0	3.0008473025314624	
i 1	667.7624421768708	0.505	74	224	7	5	1	8	0	-2	8	0	0	3.0008473025314624	
i 1	667.9891632653062	0.2525	72	224	7	1	16	1	0	0	1	0	0	2.0	
i 1	667.9899659863945	0.2525	73	926	1	24	15	2	0	-1	2	0	0	4.0	
i 1	667.9923741496599	2.02	74	722	6	5	13	8	0	-2	8	0	0	3.0008473025314624	
i 1	668.0036122448979	0.2525	75	722	3	3	15	2	0	-2	2	0	0	5.926595144985097	
i 1	668.0188639455782	2.2725	74	926	5	5	4	8	0	-2	8	0	0	3.0008473025314624	
i 1	668.2319387755102	0.2525	72	224	4	1	10	1	0	0	1	0	0	2.0	
i 1	668.2431768707482	0.505	75	722	3	4	14	8	0	1	8	0	0	5.926595144985097	
i 1	668.2656530612245	0.505	74	224	5	5	15	8	0	-2	8	0	0	3.0008473025314624	
i 1	668.5052176870748	3.2825	69	1108	6	1	14	1	0	-1	1	0	0	2.0	
i 1	668.5196666666667	3.2825	72	224	7	1	6	1	0	0	1	0	0	2.0	
i 1	668.7327414965987	0.7575000000000001	75	1108	6	2	10	8	0	-2	8	0	0	5.926595144985097	
i 1	668.7536122448979	0.2525	74	1108	5	5	14	8	0	-2	8	0	0	3.0008473025314624	
i 1	668.7608367346938	0.7575000000000001	75	722	3	3	15	2	0	-2	2	0	0	5.926595144985097	
i 1	668.985149659864	0.2525	72	926	4	24	14	1	0	0	1	0	0	3.0	
i 1	669.0196666666667	0.2525	74	224	5	5	8	8	0	-1	8	0	0	3.0008473025314624	
i 1	669.2423741496599	0.2525	72	224	4	1	2	1	0	0	1	0	0	2.0	
i 1	669.2584285714286	1.7675	71	722	6	5	9	2	0	-2	2	0	0	3.0008473025314624	
i 1	669.259231292517	1.5150000000000001	72	926	5	3	16	2	0	-2	2	0	0	5.926595144985097	
i 1	669.266455782313	4.2925	75	722	3	4	7	8	0	1	8	0	0	5.926595144985097	
i 1	669.4931768707482	1.2625	71	1108	5	5	14	8	0	-1	8	0	0	3.0008473025314624	
i 1	669.7311360544218	0.2525	72	926	4	24	2	1	0	0	1	0	0	3.0	
i 1	669.759231292517	0.2525	75	224	4	9	12	2	0	-2	2	0	0	4.926595144985097	
i 1	669.9843469387755	0.7575000000000001	73	224	1	24	16	8	0	-2	8	0	0	4.0	
i 1	670.0052176870748	0.2525	72	926	4	4	9	2	0	1	2	0	0	5.926595144985097	
i 1	670.2343469387755	1.2625	74	1108	5	5	9	8	0	-2	8	0	0	3.0008473025314624	
i 1	670.2455850340136	1.5150000000000001	75	224	4	9	10	2	0	-2	2	0	0	4.926595144985097	
i 1	670.2495986394558	1.2625	72	1108	6	2	11	2	0	-2	2	0	0	5.926595144985097	
i 1	670.2640476190476	0.2525	70	926	1	24	1	2	0	-2	2	0	0	4.0	
i 1	670.2680612244898	0.2525	69	926	4	1	12	0	0	0	0	0	0	2.0	
i 1	670.5020068027211	1.01	74	224	5	5	2	8	0	-2	8	0	0	3.0008473025314624	
i 1	670.5044149659864	0.2525	72	926	4	24	14	1	0	0	1	0	0	3.0	
i 1	670.9883605442177	1.7675	74	224	5	5	7	8	0	-1	8	0	0	3.0008473025314624	
i 1	670.9899659863945	2.2725	72	926	5	3	6	2	0	-2	2	0	0	5.926595144985097	
i 1	671.0044149659864	1.7675	69	1108	6	1	10	1	0	0	1	0	0	2.0	
i 1	671.0044149659864	1.7675	74	926	5	5	4	2	0	-2	2	0	0	3.0008473025314624	
i 1	671.4923741496599	1.2625	69	722	6	1	4	1	0	-1	1	0	0	2.0	
i 1	671.4947823129252	0.2525	74	926	5	5	5	8	0	-2	8	0	0	3.0008473025314624	
i 1	671.5100340136055	0.2525	73	224	1	24	10	8	0	-2	8	0	0	4.0	
i 1	671.733544217687	0.2525	74	224	5	5	13	8	0	-2	8	0	0	3.0008473025314624	
i 1	671.7495986394558	0.2525	72	926	4	4	9	2	0	1	2	0	0	5.926595144985097	
i 1	671.7624421768708	0.2525	72	224	4	1	8	1	0	0	1	0	0	2.0	
i 1	672.0172585034013	0.2525	75	722	3	3	16	2	0	-2	2	0	0	5.926595144985097	
i 1	672.4819387755102	1.2625	74	224	5	5	3	8	0	-2	8	0	0	3.0008473025314624	
i 1	672.4955850340136	1.01	69	1108	6	1	11	1	0	-1	1	0	0	2.0	
i 1	672.5044149659864	1.01	72	224	7	1	2	1	0	0	1	0	0	2.0	
i 1	672.5076258503401	1.2625	74	1108	5	5	10	8	0	-2	8	0	0	3.0008473025314624	
i 1	673.0012040816326	0.2525	74	722	6	5	3	8	0	-2	8	0	0	3.0008473025314624	
i 1	673.0076258503401	1.7675	75	224	4	9	12	2	0	-2	2	0	0	4.926595144985097	
i 1	673.0172585034013	1.7675	72	1108	6	2	6	2	0	-2	2	0	0	5.926595144985097	
i 1	673.4867551020408	1.5150000000000001	71	722	6	5	16	2	0	-2	2	0	0	3.0008473025314624	
i 1	673.4915714285714	1.5150000000000001	69	926	4	1	4	0	0	0	0	0	0	2.0	
i 1	673.4947823129252	1.5150000000000001	71	1108	5	5	10	8	0	-1	8	0	0	3.0008473025314624	
i 1	673.5004013605442	1.7675	69	722	4	24	5	0	0	0	0	0	0	3.0	
i 1	673.7624421768708	0.2525	69	1108	6	1	2	1	0	-1	1	0	0	2.0	
i 1	673.9987959183674	0.2525	72	224	4	9	6	8	0	-2	8	0	0	4.926595144985097	
i 1	674.5124421768708	0.2525	74	224	5	5	11	8	0	-2	8	0	0	3.0008473025314624	
i 1	674.7544149659864	0.7575000000000001	75	1108	6	2	12	8	0	-2	8	0	0	5.926595144985097	
i 1	674.7552176870748	0.505	75	722	3	3	5	2	0	-2	2	0	0	5.926595144985097	
i 1	674.7560204081633	0.2525	75	722	3	4	6	8	0	1	8	0	0	5.926595144985097	
i 1	674.7584285714286	0.2525	74	926	5	5	1	8	0	-2	8	0	0	3.0008473025314624	
i 1	674.9811360544218	1.2625	71	722	4	5	8	2	0	-2	2	0	0	3.0008473025314624	
i 1	674.9819387755102	15.655	67	722	5	7	15	0	0	1	0	0	0	1.4882498065716456	
i 1	674.9931768707482	1.2625	72	1108	6	2	4	2	0	-2	2	0	0	5.926595144985097	
i 1	674.9987959183674	1.2625	69	722	6	1	12	1	0	-1	1	0	0	2.0	
i 1	675.0004013605442	1.5150000000000001	73	224	1	24	15	8	0	-2	8	0	0	4.0	
i 1	675.0028095238096	1.2625	72	224	6	9	13	8	0	-2	8	0	0	4.926595144985097	
i 1	675.0060204081633	1.2625	71	722	5	5	4	8	0	-1	8	0	0	3.0008473025314624	
i 1	675.014850340136	1.2625	72	722	6	1	6	0	0	0	0	0	0	2.0	
i 1	675.2680612244898	0.2525	72	224	4	1	15	1	0	0	1	0	0	2.0	
i 1	675.4971904761904	0.2525	75	722	4	4	14	2	0	-2	2	0	0	5.926595144985097	
i 1	675.509231292517	0.2525	73	722	1	24	11	2	0	-1	2	0	0	4.0	
i 1	675.7375578231292	1.2625	75	722	3	3	15	2	0	-2	2	0	0	5.926595144985097	
i 1	675.7672585034013	1.2625	72	722	5	3	15	8	0	1	8	0	0	5.926595144985097	
i 1	675.9827414965987	1.7675	74	224	5	5	5	8	0	-2	8	0	0	3.0008473025314624	
i 1	675.990768707483	2.7775	72	224	4	1	3	1	0	0	1	0	0	2.0	
i 1	676.0012040816326	1.7675	71	1108	5	5	6	8	0	-1	8	0	0	3.0008473025314624	
i 1	676.0044149659864	0.505	73	722	1	24	16	2	0	-1	2	0	0	4.0	
i 1	676.0060204081633	2.7775	69	1108	6	1	8	1	0	-1	1	0	0	2.0	
i 1	677.0036122448979	2.2725	72	224	6	9	7	8	0	-2	8	0	0	4.926595144985097	
i 1	677.0060204081633	2.2725	72	1108	6	2	13	2	0	-2	2	0	0	5.926595144985097	
i 1	677.2311360544218	0.505	73	224	1	24	9	8	0	-2	8	0	0	4.0	
i 1	677.2495986394558	0.2525	73	722	1	24	15	2	0	-1	2	0	0	4.0	
i 1	677.7383605442177	1.01	74	722	5	5	12	8	0	-1	8	0	0	3.0008473025314624	
i 1	677.740768707483	1.01	74	722	6	5	6	8	0	-2	8	0	0	3.0008473025314624	
i 1	678.2367551020408	0.505	73	224	1	24	5	8	0	-2	8	0	0	4.0	
i 1	678.735149659864	1.01	72	224	4	1	7	1	0	0	1	0	0	2.0	
i 1	678.7512040816326	1.7675	74	224	5	5	1	8	0	-1	8	0	0	3.0008473025314624	
i 1	678.7536122448979	1.7675	74	1108	5	5	9	8	0	-2	8	0	0	3.0008473025314624	
i 1	678.759231292517	1.01	69	1108	6	1	10	1	0	0	1	0	0	2.0	
i 1	679.235149659864	1.01	75	224	4	9	1	2	0	-2	2	0	0	4.926595144985097	
i 1	679.2688639455782	1.01	75	1108	6	2	9	8	0	-2	8	0	0	5.926595144985097	
i 1	679.7343469387755	1.5150000000000001	72	224	4	1	3	1	0	0	1	0	0	2.0	
i 1	679.7479931972789	1.5150000000000001	69	1108	6	1	16	1	0	-1	1	0	0	2.0	
i 1	679.9883605442177	0.2525	73	722	1	24	14	2	0	-1	2	0	0	4.0	
i 1	679.9891632653062	1.01	73	224	1	24	10	8	0	-2	8	0	0	4.0	
i 1	680.2584285714286	0.7575000000000001	72	722	5	3	3	8	0	1	8	0	0	5.926595144985097	
i 1	680.2680612244898	0.7575000000000001	75	722	3	3	2	2	0	-2	2	0	0	5.926595144985097	
i 1	680.4811360544218	1.01	74	224	5	5	6	8	0	-2	8	0	0	3.0008473025314624	
i 1	680.4899659863945	1.01	71	1108	5	5	13	8	0	-1	8	0	0	3.0008473025314624	
i 1	680.9883605442177	0.2525	72	224	6	9	13	8	0	-2	8	0	0	4.926595144985097	
i 1	681.0116394557823	0.2525	72	1108	6	2	13	2	0	-2	2	0	0	5.926595144985097	
i 1	681.240768707483	0.505	72	722	6	1	7	0	0	0	0	0	0	2.0	
i 1	681.2512040816326	1.5150000000000001	72	722	5	3	14	8	0	1	8	0	0	5.926595144985097	
i 1	681.2536122448979	0.505	69	722	6	1	16	1	0	-1	1	0	0	2.0	
i 1	681.2696666666667	1.5150000000000001	75	722	3	3	1	2	0	-2	2	0	0	5.926595144985097	
i 1	681.4843469387755	1.2625	73	224	1	24	13	8	0	-2	8	0	0	4.0	
i 1	681.4923741496599	0.505	74	224	5	5	7	8	0	-1	8	0	0	3.0008473025314624	
i 1	681.4979931972789	0.2525	74	1108	5	5	10	8	0	-2	8	0	0	3.0008473025314624	
i 1	681.7319387755102	0.2525	74	1108	6	5	7	8	0	-2	8	0	0	3.0008473025314624	
i 1	681.7391632653062	0.7575000000000001	72	722	6	1	5	0	0	0	0	0	0	2.0	
i 1	681.7399659863945	7.3225	67	1108	5	14	10	5	0	1	5	0	0	2.238332859264742	
i 1	681.7512040816326	0.7575000000000001	69	722	3	1	6	1	0	-1	1	0	0	2.0	
i 1	681.9891632653062	1.2625	71	722	4	5	7	2	0	-2	2	0	0	3.0008473025314624	
i 1	682.0188639455782	1.2625	71	722	5	5	15	8	0	-1	8	0	0	3.0008473025314624	
i 1	682.4955850340136	1.2625	69	1108	6	1	15	1	0	-1	1	0	0	2.0	
i 1	682.516455782313	1.2625	72	224	4	1	5	1	0	0	1	0	0	2.0	
i 1	682.7544149659864	2.525	72	224	6	9	15	8	0	-2	8	0	0	4.926595144985097	
i 1	682.7624421768708	2.525	72	1108	4	2	2	2	0	-2	2	0	0	5.926595144985097	
i 1	683.240768707483	1.2625	74	224	5	5	11	8	0	-2	8	0	0	3.0008473025314624	
i 1	683.2600340136055	1.2625	71	1108	5	5	5	8	0	-1	8	0	0	3.0008473025314624	
i 1	683.7319387755102	0.505	69	722	3	1	8	1	0	-1	1	0	0	2.0	
i 1	683.7391632653062	0.505	72	722	6	1	6	0	0	0	0	0	0	2.0	
i 1	683.7552176870748	0.2525	73	224	1	24	13	8	0	-2	8	0	0	4.0	
i 1	684.235149659864	3.2825	72	224	4	1	12	1	0	0	1	0	0	2.0	
i 1	684.2656530612245	3.2825	69	1108	6	1	5	1	0	-1	1	0	0	2.0	
i 1	684.4803333333333	1.5150000000000001	74	722	4	5	16	8	0	-2	8	0	0	3.0008473025314624	
i 1	684.5052176870748	0.505	73	224	1	24	9	8	0	-2	8	0	0	4.0	
i 1	684.5084285714286	1.5150000000000001	74	722	5	5	14	8	0	-1	8	0	0	3.0008473025314624	
i 1	685.2327414965987	0.2525	75	224	6	9	16	2	0	-2	2	0	0	4.926595144985097	
i 1	685.2455850340136	0.2525	75	1108	6	2	14	8	0	-2	8	0	0	5.926595144985097	
i 1	685.4939795918367	0.2525	75	722	3	3	12	2	0	-2	2	0	0	5.926595144985097	
i 1	685.5028095238096	0.2525	72	722	5	3	13	8	0	1	8	0	0	5.926595144985097	
i 1	685.7463877551021	1.2625	72	224	6	9	1	8	0	-2	8	0	0	4.926595144985097	
i 1	685.7656530612245	1.2625	72	1108	4	2	9	2	0	-2	2	0	0	5.926595144985097	
i 1	685.9915714285714	1.5150000000000001	74	224	5	5	4	8	0	-1	8	0	0	3.0008473025314624	
i 1	686.009231292517	1.5150000000000001	74	1108	6	5	13	8	0	-2	8	0	0	3.0008473025314624	
i 1	687.0052176870748	1.5150000000000001	75	722	3	3	1	2	0	-2	2	0	0	5.926595144985097	
i 1	687.0084285714286	0.505	73	224	1	24	7	8	0	-2	8	0	0	4.0	
i 1	687.009231292517	1.7675	72	722	5	3	10	8	0	1	8	0	0	5.926595144985097	
i 1	687.483544217687	1.2625	69	1108	6	1	4	1	0	0	1	0	0	2.0	
i 1	687.4915714285714	1.01	71	1108	5	5	4	8	0	-1	8	0	0	3.0008473025314624	
i 1	687.4987959183674	1.2625	72	224	4	1	11	1	0	0	1	0	0	2.0	
i 1	687.514850340136	1.2625	74	224	5	5	16	8	0	-2	8	0	0	3.0008473025314624	
i 1	688.4923741496599	0.2525	71	1108	6	5	13	8	0	-1	8	0	0	3.0008473025314624	
i 1	688.4955850340136	0.2525	75	722	5	3	1	2	0	-2	2	0	0	5.926595144985097	
i 1	688.5028095238096	0.505	60	1108	5	14	6	5	0	0	5	0	0	2.238332859264742	
i 1	688.7327414965987	0.2525	74	224	5	5	7	8	0	-1	8	0	0	3.0008473025314624	
i 1	688.733544217687	0.2525	74	1108	6	5	9	8	0	-2	8	0	0	3.0008473025314624	
i 1	688.735149659864	0.2525	72	224	7	1	11	1	0	0	1	0	0	2.0	
i 1	688.7383605442177	0.2525	69	1108	6	1	8	1	0	-1	1	0	0	2.0	
i 1	688.7576258503401	0.2525	72	1108	4	2	10	2	0	-2	2	0	0	5.926595144985097	
i 1	688.7616394557823	0.2525	72	224	6	9	14	8	0	-2	8	0	0	4.926595144985097	
i 1	688.9803333333333	0.2525	75	224	6	9	1	2	0	-2	2	0	0	4.926595144985097	
i 1	688.9875578231292	9.8475	67	926	5	14	15	0	0	0	0	0	0	2.238332859264742	
i 1	688.9923741496599	0.505	69	926	6	1	1	0	0	0	0	0	0	2.0	
i 1	688.9979931972789	0.505	72	224	4	1	13	1	0	0	1	0	0	2.0	
i 1	689.0020068027211	1.5150000000000001	74	224	4	5	16	2	0	-2	2	0	0	3.0008473025314624	
i 1	689.0100340136055	9.8475	60	926	5	14	3	0	0	1	0	0	0	2.238332859264742	
i 1	689.0156530612245	1.5150000000000001	71	926	6	5	8	2	0	-1	2	0	0	3.0008473025314624	
i 1	689.2367551020408	0.2525	75	224	6	3	8	2	0	-2	2	0	0	5.926595144985097	
i 1	689.2423741496599	0.2525	72	926	4	2	2	2	0	-2	2	0	0	5.926595144985097	
i 1	689.485149659864	0.7575000000000001	72	722	6	1	4	0	0	0	0	0	0	2.0	
i 1	689.4875578231292	1.01	72	722	5	3	13	8	0	1	8	0	0	5.926595144985097	
i 1	689.5012040816326	0.7575000000000001	69	224	3	24	12	0	0	-1	0	0	0	3.0	
i 1	689.5180612244898	1.01	72	224	3	4	13	2	0	-2	2	0	0	5.926595144985097	
i 1	690.0044149659864	0.2525	73	224	1	24	6	8	0	-2	8	0	0	4.0	
i 1	690.2319387755102	0.2525	69	722	4	24	9	0	0	-1	0	0	0	3.0	
i 1	690.2479931972789	1.7675	72	224	7	1	4	1	0	0	1	0	0	2.0	
i 1	690.4883605442177	1.7675	75	224	6	3	12	2	0	-2	2	0	0	5.926595144985097	
i 1	690.4931768707482	1.5150000000000001	69	926	6	1	8	0	0	0	0	0	0	2.0	
i 1	690.4931768707482	1.2625	71	926	6	5	8	8	0	-1	8	0	0	3.0008473025314624	
i 1	690.4947823129252	1.2625	74	224	5	5	14	8	0	-1	8	0	0	3.0008473025314624	
i 1	690.4955850340136	1.7675	75	610	5	3	14	2	0	1	2	0	0	5.926595144985097	
i 1	690.5084285714286	8.3325	67	610	5	7	9	5	0	0	5	0	0	1.4882498065716456	
i 1	691.735149659864	1.2625	71	926	6	5	11	2	0	-1	2	0	0	3.0008473025314624	
i 1	691.735149659864	1.2625	74	224	5	5	11	8	0	-2	8	0	0	3.0008473025314624	
i 1	691.9891632653062	1.2625	72	224	4	1	16	1	0	0	1	0	0	2.0	
i 1	692.0060204081633	1.2625	69	926	6	1	5	1	0	-1	1	0	0	2.0	
i 1	692.2367551020408	0.7575000000000001	72	926	4	2	6	8	0	1	8	0	0	5.926595144985097	
i 1	692.240768707483	0.7575000000000001	72	224	6	9	1	8	0	-2	8	0	0	4.926595144985097	
i 1	692.7624421768708	0.505	73	224	1	24	9	8	0	-2	8	0	0	4.0	
i 1	692.9915714285714	0.2525	75	224	6	9	3	2	0	-2	2	0	0	4.926595144985097	
i 1	692.9915714285714	1.2625	71	926	6	5	11	8	0	-1	8	0	0	3.0008473025314624	
i 1	692.9939795918367	0.2525	72	926	4	2	13	2	0	-2	2	0	0	5.926595144985097	
i 1	693.0028095238096	1.2625	74	224	5	5	16	8	0	-1	8	0	0	3.0008473025314624	
i 1	693.240768707483	1.2625	72	224	7	1	4	1	0	0	1	0	0	2.0	
i 1	693.2528095238096	0.2525	72	926	4	2	1	8	0	1	8	0	0	5.926595144985097	
i 1	693.259231292517	1.2625	69	926	6	1	16	0	0	0	0	0	0	2.0	
i 1	693.2672585034013	0.2525	72	224	6	9	12	8	0	-2	8	0	0	4.926595144985097	
i 1	693.4867551020408	1.2625	72	926	4	2	13	2	0	-2	2	0	0	5.926595144985097	
i 1	693.4987959183674	1.2625	75	224	6	9	8	2	0	-2	2	0	0	4.926595144985097	
i 1	693.766455782313	0.2525	75	224	6	3	7	2	0	-2	2	0	0	5.926595144985097	
i 1	693.9859523809524	2.7775	74	224	5	5	12	8	0	-2	8	0	0	3.0008473025314624	
i 1	693.9875578231292	1.2625	71	926	6	5	10	2	0	-1	2	0	0	3.0008473025314624	
i 1	694.0060204081633	0.505	73	224	1	24	5	8	0	-2	8	0	0	4.0	
i 1	694.0068231292518	0.2525	74	224	4	5	16	2	0	-2	2	0	0	3.0008473025314624	
i 1	694.014850340136	0.2525	71	610	5	5	11	8	0	-2	8	0	0	3.0008473025314624	
i 1	694.4803333333333	0.7575000000000001	72	610	6	1	15	1	0	-1	1	0	0	2.0	
i 1	694.483544217687	1.01	75	224	6	3	3	2	0	-2	2	0	0	5.926595144985097	
i 1	694.4859523809524	0.2525	74	224	5	5	6	8	0	-1	8	0	0	3.0008473025314624	
i 1	694.5052176870748	0.7575000000000001	72	224	3	1	5	0	0	-1	0	0	0	2.0	
i 1	694.5132448979592	0.2525	69	224	3	24	4	0	0	-1	0	0	0	3.0	
i 1	694.7640476190476	0.505	75	610	5	3	15	2	0	1	2	0	0	5.926595144985097	
i 1	694.7656530612245	0.2525	72	224	4	1	9	1	0	0	1	0	0	2.0	
i 1	695.0052176870748	0.7575000000000001	69	926	6	1	2	0	0	0	0	0	0	2.0	
i 1	695.2327414965987	3.0300000000000002	73	224	1	24	12	8	0	-2	8	0	0	4.0	
i 1	695.2463877551021	0.2525	72	224	7	1	7	1	0	0	1	0	0	2.0	
i 1	695.2528095238096	0.2525	74	224	4	5	1	2	0	-2	2	0	0	3.0008473025314624	
i 1	695.2544149659864	1.5150000000000001	71	926	6	5	2	2	0	-1	2	0	0	3.0008473025314624	
i 1	695.2552176870748	0.2525	75	610	4	3	3	2	0	1	2	0	0	5.926595144985097	
i 1	695.2600340136055	3.535	67	926	5	25	15	5	0	0	5	0	0	1.7216435423119565	
i 1	695.2632448979592	0.505	72	224	7	1	7	1	0	0	1	0	0	2.0	
i 1	695.4883605442177	1.2625	72	224	3	1	6	0	0	-1	0	0	0	2.0	
i 1	695.5028095238096	0.2525	72	926	4	2	14	2	0	-2	2	0	0	5.926595144985097	
i 1	695.5084285714286	1.01	72	926	4	2	10	8	0	1	8	0	0	5.926595144985097	
i 1	695.5124421768708	1.01	72	224	6	9	13	8	0	-2	8	0	0	4.926595144985097	
i 1	695.7431768707482	1.01	72	610	6	1	5	1	0	-1	1	0	0	2.0	
i 1	696.2512040816326	0.2525	71	224	4	5	10	8	0	-1	8	0	0	3.0008473025314624	
i 1	696.2688639455782	0.2525	72	224	7	1	6	1	0	0	1	0	0	2.0	
i 1	696.485149659864	0.2525	75	610	4	4	15	2	0	-2	2	0	0	5.926595144985097	
i 1	696.4899659863945	1.01	75	224	6	3	9	2	0	-2	2	0	0	5.926595144985097	
i 1	696.4971904761904	0.2525	72	224	7	1	2	1	0	0	1	0	0	2.0	
i 1	696.5108367346938	0.2525	71	926	6	5	1	8	0	-1	8	0	0	3.0008473025314624	
i 1	696.5180612244898	1.2625	75	610	4	3	13	2	0	1	2	0	0	5.926595144985097	
i 1	696.7327414965987	0.505	71	224	4	5	4	8	0	-1	8	0	0	3.0008473025314624	
i 1	696.7487959183674	0.505	71	610	5	5	10	2	0	-2	2	0	0	3.0008473025314624	
i 1	696.7544149659864	1.7675	69	224	3	24	8	0	0	-1	0	0	0	3.0	
i 1	696.764850340136	1.7675	69	610	4	24	14	1	0	-1	1	0	0	3.0	
i 1	696.9947823129252	1.5150000000000001	74	224	5	5	13	8	0	-1	8	0	0	3.0008473025314624	
i 1	696.9979931972789	1.7675	71	926	6	5	8	8	0	-1	8	0	0	3.0008473025314624	
i 1	697.2656530612245	0.2525	72	224	5	4	6	2	0	-2	2	0	0	5.926595144985097	
i 1	697.4843469387755	0.2525	72	224	6	9	9	8	0	-2	8	0	0	4.926595144985097	
i 1	697.5012040816326	0.2525	69	926	6	1	14	1	0	-1	1	0	0	2.0	
i 1	697.5100340136055	0.2525	72	926	4	2	15	8	0	1	8	0	0	5.926595144985097	
i 1	697.5156530612245	0.2525	74	224	5	5	12	8	0	-2	8	0	0	3.0008473025314624	
i 1	697.7423741496599	1.01	72	926	4	2	1	2	0	-2	2	0	0	5.926595144985097	
i 1	697.7512040816326	0.7575000000000001	72	224	7	1	6	1	0	0	1	0	0	2.0	
i 1	697.7560204081633	0.2525	75	610	4	4	14	2	0	-2	2	0	0	5.926595144985097	
i 1	697.7632448979592	0.7575000000000001	75	224	6	9	5	2	0	-2	2	0	0	4.926595144985097	
i 1	697.9915714285714	0.2525	71	610	5	5	16	2	0	-2	2	0	0	3.0008473025314624	
i 1	698.009231292517	0.7575000000000001	69	926	6	1	3	0	0	0	0	0	0	2.0	
i 1	698.2447823129252	0.2525	71	610	6	5	6	8	0	-2	8	0	0	3.0008473025314624	
i 1	698.2696666666667	0.2525	72	224	6	9	15	8	0	-2	8	0	0	4.926595144985097	
i 1	698.4803333333333	0.2525	69	926	6	1	9	1	0	-1	1	0	0	2.0	
i 1	698.4811360544218	0.2525	72	1192	5	9	9	2	0	-2	2	0	0	4.926595144985097	
i 1	698.5052176870748	0.2525	72	1192	6	1	4	0	0	0	0	0	0	2.0	
i 1	698.5060204081633	0.2525	75	610	4	3	16	2	0	1	2	0	0	5.926595144985097	
i 1	698.5132448979592	0.2525	74	1192	5	5	14	8	0	-2	8	0	0	3.0008473025314624	
i 1	698.7359523809524	0.2525	69	1075	6	1	13	0	0	-1	0	0	0	2.0	
i 1	698.7399659863945	0.2525	71	1075	4	5	16	8	0	-1	8	0	0	3.0008473025314624	
i 1	698.7415714285714	1.01	72	689	4	2	1	2	0	-2	2	0	0	5.926595144985097	
i 1	698.7415714285714	10.1	60	689	5	14	9	0	0	1	0	0	0	2.238332859264742	
i 1	698.7431768707482	2.02	71	373	4	5	14	8	0	-1	8	0	0	3.0008473025314624	
i 1	698.7455850340136	3.2825	67	689	5	7	14	5	0	1	5	0	0	1.4882498065716456	
i 1	698.7479931972789	0.2525	69	689	6	1	16	0	0	0	0	0	0	2.0	
i 1	698.7479931972789	1.5150000000000001	72	689	6	1	2	0	0	0	0	0	0	2.0	
i 1	698.7504013605442	2.02	74	689	6	5	9	2	0	-2	2	0	0	3.0008473025314624	
i 1	698.7528095238096	0.2525	72	1075	5	9	3	2	0	1	2	0	0	4.926595144985097	
i 1	698.7568231292518	0.2525	71	689	6	5	11	2	0	-2	2	0	0	3.0008473025314624	
i 1	698.7600340136055	1.5150000000000001	72	373	3	1	2	1	0	0	1	0	0	2.0	
i 1	698.7608367346938	0.2525	71	1075	4	5	15	8	0	-2	8	0	0	3.0008473025314624	
i 1	698.7640476190476	1.01	72	373	5	3	16	8	0	-2	8	0	0	5.926595144985097	
i 1	698.7672585034013	10.1	60	689	5	25	13	5	0	0	5	0	0	1.7216435423119565	
i 1	698.7696666666667	10.1	60	689	5	14	12	0	0	0	0	0	0	2.238332859264742	
i 1	698.9947823129252	0.2525	72	689	4	24	12	0	0	-1	0	0	0	3.0	
i 1	699.0156530612245	0.505	74	689	6	5	1	2	0	-1	2	0	0	3.0008473025314624	
i 1	699.5060204081633	1.01	75	689	4	3	5	8	0	1	8	0	0	5.926595144985097	
i 1	699.5100340136055	0.505	71	689	6	5	6	2	0	-2	2	0	0	3.0008473025314624	
i 1	699.5108367346938	1.01	75	373	4	4	14	2	0	1	2	0	0	5.926595144985097	
i 1	699.7624421768708	1.01	69	689	6	1	12	0	0	0	0	0	0	2.0	
i 1	699.766455782313	0.7575000000000001	72	1075	6	1	5	1	0	0	1	0	0	2.0	
i 1	700.0060204081633	0.2525	72	373	5	3	3	8	0	-2	8	0	0	5.926595144985097	
i 1	700.235149659864	1.7675	72	689	4	2	13	8	0	1	8	0	0	5.926595144985097	
i 1	700.2439795918367	1.2625	72	373	3	24	10	1	0	-1	1	0	0	3.0	
i 1	700.2504013605442	1.2625	72	689	6	1	12	0	0	0	0	0	0	2.0	
i 1	700.2544149659864	1.7675	74	373	4	5	13	8	0	-1	8	0	0	3.0008473025314624	
i 1	700.2560204081633	1.7675	74	689	6	5	4	2	0	-1	2	0	0	3.0008473025314624	
i 1	700.2640476190476	3.0300000000000002	72	1075	5	9	2	2	0	1	2	0	0	4.926595144985097	
i 1	700.7536122448979	0.2525	74	689	5	5	16	8	0	-1	8	0	0	3.0008473025314624	
i 1	700.9803333333333	0.2525	71	1075	4	5	14	8	0	-2	8	0	0	3.0008473025314624	
i 1	700.983544217687	1.2625	75	689	4	3	10	8	0	1	8	0	0	5.926595144985097	
i 1	700.9859523809524	1.7675	69	689	6	1	4	0	0	0	0	0	0	2.0	
i 1	700.9891632653062	1.01	72	1075	6	1	9	1	0	0	1	0	0	2.0	
i 1	700.9987959183674	1.01	75	373	4	4	10	2	0	1	2	0	0	5.926595144985097	
i 1	701.2512040816326	0.7575000000000001	74	689	5	5	7	8	0	-1	8	0	0	3.0008473025314624	
i 1	701.5060204081633	1.7675	71	1075	4	5	14	8	0	-1	8	0	0	3.0008473025314624	
i 1	701.516455782313	0.2525	72	689	4	24	16	0	0	-1	0	0	0	3.0	
i 1	701.7616394557823	0.2525	72	689	6	1	1	0	0	0	0	0	0	2.0	
i 1	701.9843469387755	1.2625	72	689	6	2	11	8	0	1	8	0	0	5.926595144985097	
i 1	701.9867551020408	0.505	72	1075	6	1	3	1	0	0	1	0	0	2.0	
i 1	701.9875578231292	2.02	72	373	3	24	8	1	0	-1	1	0	0	3.0	
i 1	701.9987959183674	0.2525	71	373	4	5	2	8	0	-1	8	0	0	3.0008473025314624	
i 1	702.0068231292518	1.5150000000000001	74	689	6	5	4	8	0	-1	8	0	0	3.0008473025314624	
i 1	702.0108367346938	6.8175	67	689	6	7	8	5	0	1	5	0	0	1.4882498065716456	
i 1	702.0132448979592	6.8175	60	689	5	25	4	5	0	0	5	0	0	1.7216435423119565	
i 1	702.016455782313	2.02	72	689	6	1	15	0	0	0	0	0	0	2.0	
i 1	702.2423741496599	0.2525	74	373	4	5	14	8	0	-1	8	0	0	3.0008473025314624	
i 1	702.2576258503401	0.2525	72	689	4	2	3	2	0	-2	2	0	0	5.926595144985097	
i 1	702.4811360544218	0.2525	72	1075	5	9	14	2	0	1	2	0	0	4.926595144985097	
i 1	702.509231292517	5.05	71	689	6	5	9	2	0	-2	2	0	0	3.0008473025314624	
i 1	702.7399659863945	4.545	71	1075	4	5	7	8	0	-2	8	0	0	3.0008473025314624	
i 1	702.7504013605442	1.5150000000000001	72	689	4	2	6	2	0	-2	2	0	0	5.926595144985097	
i 1	702.7528095238096	0.2525	69	1075	6	1	12	0	0	-1	0	0	0	2.0	
i 1	702.7688639455782	1.2625	72	373	5	3	1	8	0	-2	8	0	0	5.926595144985097	
i 1	702.990768707483	0.2525	69	689	6	1	4	0	0	0	0	0	0	2.0	
i 1	703.2528095238096	0.2525	72	689	6	1	6	0	0	0	0	0	0	2.0	
i 1	703.2656530612245	0.2525	75	689	4	4	1	2	0	-2	2	0	0	5.926595144985097	
i 1	703.4843469387755	1.5150000000000001	72	689	6	2	3	8	0	1	8	0	0	5.926595144985097	
i 1	703.4931768707482	1.5150000000000001	72	1075	5	9	13	2	0	1	2	0	0	4.926595144985097	
i 1	703.4939795918367	2.2725	72	689	4	24	7	0	0	-1	0	0	0	3.0	
i 1	703.5004013605442	2.02	69	1075	6	1	11	0	0	-1	0	0	0	2.0	
i 1	703.5116394557823	0.2525	71	1075	4	5	9	8	0	-1	8	0	0	3.0008473025314624	
i 1	703.7608367346938	0.2525	74	689	6	5	6	8	0	-1	8	0	0	3.0008473025314624	
i 1	704.0188639455782	0.2525	72	373	6	1	7	1	0	0	1	0	0	2.0	
i 1	704.2311360544218	0.2525	75	373	4	4	9	2	0	1	2	0	0	5.926595144985097	
i 1	704.2327414965987	0.2525	72	689	6	1	7	0	0	0	0	0	0	2.0	
i 1	704.2560204081633	0.2525	74	689	6	5	10	8	0	-1	8	0	0	3.0008473025314624	
i 1	704.4819387755102	4.2925	72	1075	6	1	2	1	0	0	1	0	0	2.0	
i 1	704.4875578231292	1.5150000000000001	72	689	4	2	11	2	0	-2	2	0	0	5.926595144985097	
i 1	704.4923741496599	4.2925	69	689	6	1	3	0	0	0	0	0	0	2.0	
i 1	704.4947823129252	0.7575000000000001	71	373	4	5	13	8	0	-1	8	0	0	3.0008473025314624	
i 1	704.5132448979592	1.5150000000000001	72	373	5	3	4	8	0	-2	8	0	0	5.926595144985097	
i 1	704.5196666666667	0.505	71	1075	4	5	13	8	0	-1	8	0	0	3.0008473025314624	
i 1	705.0140476190476	3.535	75	373	4	4	12	2	0	1	2	0	0	5.926595144985097	
i 1	705.2303333333333	1.5150000000000001	72	689	6	2	4	8	0	1	8	0	0	5.926595144985097	
i 1	705.2327414965987	3.2825	75	689	4	3	15	8	0	1	8	0	0	5.926595144985097	
i 1	705.2343469387755	1.2625	72	1075	5	9	5	2	0	1	2	0	0	4.926595144985097	
i 1	705.2560204081633	0.2525	74	689	6	5	12	2	0	-2	2	0	0	3.0008473025314624	
i 1	705.4939795918367	0.2525	74	689	6	5	15	2	0	-1	2	0	0	3.0008473025314624	
i 1	705.4971904761904	0.2525	72	689	6	1	2	0	0	0	0	0	0	2.0	
i 1	705.7391632653062	0.2525	69	1075	6	1	16	0	0	-1	0	0	0	2.0	
i 1	705.7487959183674	0.2525	72	373	6	1	6	1	0	0	1	0	0	2.0	
i 1	705.7680612244898	0.2525	74	373	4	5	6	8	0	-1	8	0	0	3.0008473025314624	
i 1	705.9859523809524	0.505	71	1075	4	5	10	8	0	-1	8	0	0	3.0008473025314624	
i 1	706.0172585034013	1.7675	72	689	6	1	4	0	0	0	0	0	0	2.0	
i 1	706.2415714285714	1.5150000000000001	72	373	6	1	7	1	0	0	1	0	0	2.0	
i 1	706.4899659863945	0.7575000000000001	71	373	4	5	12	8	0	-1	8	0	0	3.0008473025314624	
i 1	706.5156530612245	0.7575000000000001	74	689	6	5	9	2	0	-2	2	0	0	3.0008473025314624	
i 1	706.7303333333333	0.2525	72	1075	5	9	16	2	0	1	2	0	0	4.926595144985097	
i 1	706.7391632653062	0.2525	75	689	4	4	10	2	0	-2	2	0	0	5.926595144985097	
i 1	706.7423741496599	2.02	74	689	6	5	2	2	0	-1	2	0	0	3.0008473025314624	
i 1	706.764850340136	2.02	74	373	4	5	9	8	0	-1	8	0	0	3.0008473025314624	
i 1	707.016455782313	0.2525	72	689	6	2	5	8	0	1	8	0	0	5.926595144985097	
i 1	707.2495986394558	0.2525	71	1075	4	5	11	8	0	-1	8	0	0	3.0008473025314624	
i 1	707.4939795918367	0.2525	71	373	4	5	8	8	0	-1	8	0	0	3.0008473025314624	
i 1	707.4963877551021	0.2525	72	1075	5	9	8	2	0	1	2	0	0	4.926595144985097	
i 1	707.516455782313	1.2625	72	689	6	2	5	8	0	1	8	0	0	5.926595144985097	
i 1	707.7504013605442	1.01	72	1075	5	9	1	2	0	1	2	0	0	4.926595144985097	
i 1	707.7616394557823	0.7575000000000001	74	689	6	5	7	8	0	-1	8	0	0	3.0008473025314624	
i 1	707.7632448979592	1.01	72	689	6	1	1	0	0	0	0	0	0	2.0	
i 1	707.990768707483	0.7575000000000001	72	373	3	24	10	1	0	-1	1	0	0	3.0	
i 1	708.2311360544218	0.2525	71	689	6	5	4	2	0	-2	2	0	0	3.0008473025314624	
i 1	708.4939795918367	0.2525	72	373	5	3	8	8	0	-2	8	0	0	5.926595144985097	
i 1	708.509231292517	0.2525	71	373	4	5	2	8	0	-1	8	0	0	3.0008473025314624	
i 1	708.5116394557823	0.2525	72	689	4	2	10	2	0	-2	2	0	0	5.926595144985097	
i 1	708.5140476190476	0.2525	71	1075	4	5	6	8	0	-2	8	0	0	3.0008473025314624	
i 1	708.7319387755102	1.01	74	689	6	5	10	2	0	-1	2	0	0	2.595700713469904	
i 1	708.7359523809524	0.2525	69	689	4	1	14	0	0	0	0	0	0	2.088571040475097	
i 1	708.7375578231292	1.7675	72	689	6	2	4	2	0	-2	2	0	0	6.7837035003629405	
i 1	708.7375578231292	1.2625	74	689	6	5	7	8	0	-1	8	0	0	2.595700713469904	
i 1	708.7463877551021	1.2625	71	1075	5	5	5	8	0	-1	8	0	0	2.595700713469904	
i 1	708.7471904761904	0.2525	72	1075	6	1	5	1	0	0	1	0	0	2.088571040475097	
i 1	708.7487959183674	20.4525	67	689	6	7	7	5	0	1	5	0	0	1.084099902903431	
i 1	708.7552176870748	1.7675	72	689	6	1	13	0	0	0	0	0	0	2.088571040475097	
i 1	708.7568231292518	1.7675	72	1075	5	9	15	2	0	1	2	0	0	5.7837035003629405	
i 1	708.7584285714286	6.8175	60	689	5	14	7	0	0	1	0	0	0	1.8341829555965272	
i 1	708.7616394557823	2.02	72	373	5	3	15	8	0	-2	8	0	0	6.7837035003629405	
i 1	708.7656530612245	1.7675	72	689	6	2	16	8	0	1	8	0	0	6.7837035003629405	
i 1	708.7656530612245	1.01	74	373	4	5	16	8	0	-1	8	0	0	2.595700713469904	
i 1	708.766455782313	1.7675	72	373	4	24	1	1	0	-1	1	0	0	3.088571040475097	
i 1	708.7672585034013	43.935	60	689	4	14	8	0	0	0	0	0	0	1.8341829555965272	
i 1	708.9931768707482	0.2525	72	689	6	1	9	0	0	0	0	0	0	2.088571040475097	
i 1	709.0012040816326	5.05	71	1075	4	5	5	8	0	-2	8	0	0	2.595700713469904	
i 1	709.0116394557823	5.05	71	689	6	5	1	2	0	-2	2	0	0	2.595700713469904	
i 1	709.0188639455782	0.505	72	373	6	1	16	1	0	0	1	0	0	2.088571040475097	
i 1	709.2584285714286	2.525	72	1075	6	1	13	1	0	0	1	0	0	2.088571040475097	
i 1	709.490768707483	2.525	69	689	4	1	10	0	0	0	0	0	0	2.088571040475097	
i 1	709.9843469387755	4.545	75	689	4	3	5	8	0	1	8	0	0	6.7837035003629405	
i 1	710.0020068027211	4.545	75	373	4	4	4	2	0	1	2	0	0	6.7837035003629405	
i 1	710.0100340136055	0.2525	74	373	4	5	2	8	0	-1	8	0	0	2.595700713469904	
i 1	710.233544217687	0.2525	71	1075	5	5	15	8	0	-1	8	0	0	2.595700713469904	
i 1	710.2504013605442	0.505	74	689	6	5	13	2	0	-1	2	0	0	2.595700713469904	
i 1	710.4883605442177	0.2525	72	373	6	1	5	1	0	0	1	0	0	2.088571040475097	
i 1	710.4955850340136	0.2525	75	689	4	4	10	2	0	-2	2	0	0	6.7837035003629405	
i 1	710.5044149659864	0.7575000000000001	74	373	4	5	1	8	0	-1	8	0	0	2.595700713469904	
i 1	710.7343469387755	2.2725	72	373	4	24	3	1	0	-1	1	0	0	3.088571040475097	
i 1	710.7391632653062	0.2525	71	1075	5	5	9	8	0	-1	8	0	0	2.595700713469904	
i 1	710.7487959183674	0.2525	72	689	4	24	1	0	0	-1	0	0	0	3.088571040475097	
i 1	710.7640476190476	0.2525	72	1075	3	9	7	2	0	1	2	0	0	5.7837035003629405	
i 1	710.7696666666667	2.525	72	1075	5	9	1	2	0	1	2	0	0	5.7837035003629405	
i 1	710.9883605442177	2.02	72	689	6	1	5	0	0	0	0	0	0	2.088571040475097	
i 1	711.0020068027211	1.7675	72	689	6	2	7	8	0	1	8	0	0	6.7837035003629405	
i 1	711.016455782313	0.7575000000000001	71	373	4	5	8	8	0	-1	8	0	0	2.595700713469904	
i 1	711.240768707483	0.2525	74	689	6	5	5	2	0	-1	2	0	0	2.595700713469904	
i 1	711.5044149659864	0.2525	74	689	6	5	12	8	0	-1	8	0	0	2.595700713469904	
i 1	711.7600340136055	0.2525	72	373	6	1	6	1	0	0	1	0	0	2.088571040475097	
i 1	711.7616394557823	0.2525	71	1075	5	5	9	8	0	-1	8	0	0	2.595700713469904	
i 1	711.9891632653062	1.5150000000000001	69	1075	6	1	11	0	0	-1	0	0	0	2.088571040475097	
i 1	711.9995986394558	0.2525	74	689	6	5	7	8	0	-1	8	0	0	2.595700713469904	
i 1	712.0172585034013	1.7675	72	689	4	24	10	0	0	-1	0	0	0	3.088571040475097	
i 1	712.4987959183674	0.505	74	689	6	5	12	2	0	-1	2	0	0	2.595700713469904	
i 1	712.5084285714286	2.7775	72	1075	6	1	2	1	0	0	1	0	0	2.088571040475097	
i 1	712.5196666666667	3.0300000000000002	69	689	4	1	3	0	0	0	0	0	0	2.088571040475097	
i 1	712.7431768707482	0.2525	71	1075	5	5	10	8	0	-1	8	0	0	2.595700713469904	
i 1	712.7552176870748	0.2525	72	689	6	2	14	2	0	-2	2	0	0	6.7837035003629405	
i 1	712.9867551020408	2.2725	74	689	6	5	5	2	0	-2	2	0	0	2.595700713469904	
i 1	713.0140476190476	2.2725	71	373	4	5	7	8	0	-1	8	0	0	2.595700713469904	
i 1	713.0188639455782	0.505	72	1075	3	9	8	2	0	1	2	0	0	5.7837035003629405	
i 1	713.4971904761904	0.2525	72	689	6	1	5	0	0	0	0	0	0	2.088571040475097	
i 1	713.5012040816326	2.02	72	689	6	2	13	8	0	1	8	0	0	6.7837035003629405	
i 1	713.5116394557823	2.02	72	1075	5	9	3	2	0	1	2	0	0	5.7837035003629405	
i 1	713.7327414965987	0.505	72	373	4	24	15	1	0	-1	1	0	0	3.088571040475097	
i 1	713.733544217687	0.2525	69	1075	6	1	6	0	0	-1	0	0	0	2.088571040475097	
i 1	713.7584285714286	1.2625	72	373	5	3	14	8	0	-2	8	0	0	6.7837035003629405	
i 1	713.764850340136	3.2825	72	689	6	2	10	2	0	-2	2	0	0	6.7837035003629405	
i 1	713.9963877551021	2.7775	74	689	6	5	4	2	0	-1	2	0	0	2.595700713469904	
i 1	714.0044149659864	1.5150000000000001	72	689	6	1	14	0	0	0	0	0	0	2.088571040475097	
i 1	714.0132448979592	2.7775	74	373	4	5	2	8	0	-1	8	0	0	2.595700713469904	
i 1	714.2479931972789	2.7775	72	373	6	1	11	1	0	0	1	0	0	2.088571040475097	
i 1	714.990768707483	0.2525	75	373	4	4	3	2	0	1	2	0	0	6.7837035003629405	
i 1	715.2431768707482	1.7675	72	373	5	3	15	8	0	-2	8	0	0	6.7837035003629405	
i 1	715.2487959183674	0.2525	71	1075	5	5	6	8	0	-1	8	0	0	2.595700713469904	
i 1	715.2504013605442	0.505	69	1075	6	1	14	0	0	-1	0	0	0	2.088571040475097	
i 1	715.2688639455782	0.2525	74	689	6	5	5	8	0	-1	8	0	0	2.595700713469904	
i 1	715.4811360544218	0.7575000000000001	72	689	6	2	4	8	0	1	8	0	0	6.7837035003629405	
i 1	715.4843469387755	2.2725	71	1075	6	5	10	8	0	-1	8	0	0	2.595700713469904	
i 1	715.4931768707482	37.1175	60	689	4	14	15	0	0	1	0	0	0	1.8341829555965272	
i 1	715.5068231292518	0.2525	71	689	5	5	15	2	0	-2	2	0	0	2.595700713469904	
i 1	715.5100340136055	1.5150000000000001	72	689	4	1	14	0	0	0	0	0	0	2.088571040475097	
i 1	715.5100340136055	0.7575000000000001	72	1075	3	9	6	2	0	1	2	0	0	5.7837035003629405	
i 1	715.5172585034013	0.2525	72	373	4	24	2	1	0	-1	1	0	0	3.088571040475097	
i 1	715.7375578231292	4.04	72	1075	6	1	7	1	0	0	1	0	0	2.088571040475097	
i 1	715.7640476190476	2.2725	74	689	6	5	7	8	0	-1	8	0	0	2.595700713469904	
i 1	715.7680612244898	2.2725	69	689	4	1	11	0	0	0	0	0	0	2.088571040475097	
i 1	716.0004013605442	3.2825	75	689	5	3	4	8	0	1	8	0	0	6.7837035003629405	
i 1	716.0076258503401	3.535	75	373	4	4	8	2	0	1	2	0	0	6.7837035003629405	
i 1	716.7375578231292	3.7875	71	689	5	5	16	2	0	-2	2	0	0	2.595700713469904	
i 1	716.7640476190476	3.7875	71	1075	5	5	13	8	0	-2	8	0	0	2.595700713469904	
i 1	716.9867551020408	3.535	72	689	6	1	6	0	0	0	0	0	0	2.088571040475097	
i 1	716.9883605442177	6.565	72	1075	3	9	2	2	0	1	2	0	0	5.7837035003629405	
i 1	716.9955850340136	3.535	72	373	4	24	1	1	0	-1	1	0	0	3.088571040475097	
i 1	717.0116394557823	7.3225	72	689	6	2	1	8	0	1	8	0	0	6.7837035003629405	
i 1	717.7576258503401	1.2625	71	373	4	5	8	8	0	-1	8	0	0	2.595700713469904	
i 1	717.9867551020408	0.505	74	689	6	5	13	2	0	-1	2	0	0	2.595700713469904	
i 1	718.0084285714286	0.2525	72	689	4	24	9	0	0	-1	0	0	0	3.088571040475097	
i 1	718.2383605442177	1.5150000000000001	69	689	4	1	11	0	0	0	0	0	0	2.088571040475097	
i 1	718.5084285714286	0.7575000000000001	74	689	6	5	5	8	0	-1	8	0	0	2.595700713469904	
i 1	718.9947823129252	0.505	74	373	4	5	15	8	0	-1	8	0	0	2.595700713469904	
i 1	719.2391632653062	0.2525	71	1075	6	5	15	8	0	-1	8	0	0	2.595700713469904	
i 1	719.2487959183674	3.0300000000000002	72	373	5	3	15	8	0	-2	8	0	0	6.7837035003629405	
i 1	719.483544217687	2.02	72	689	4	24	7	0	0	-1	0	0	0	3.088571040475097	
i 1	719.5020068027211	2.525	74	689	6	5	16	2	0	-2	2	0	0	2.595700713469904	
i 1	719.5020068027211	2.525	71	373	4	5	4	8	0	-1	8	0	0	2.595700713469904	
i 1	719.5028095238096	2.02	69	1075	6	1	3	0	0	-1	0	0	0	2.088571040475097	
i 1	719.5108367346938	2.7775	72	689	6	2	12	2	0	-2	2	0	0	6.7837035003629405	
i 1	720.5060204081633	3.7875	72	1075	6	1	11	1	0	0	1	0	0	2.088571040475097	
i 1	720.5124421768708	0.2525	74	689	6	5	6	2	0	-1	2	0	0	2.595700713469904	
i 1	720.5188639455782	3.7875	69	689	4	1	11	0	0	0	0	0	0	2.088571040475097	
i 1	720.5188639455782	0.2525	74	373	4	5	8	8	0	-1	8	0	0	2.595700713469904	
i 1	720.7512040816326	0.2525	71	1075	5	5	5	8	0	-2	8	0	0	2.595700713469904	
i 1	720.759231292517	0.2525	74	689	6	5	8	8	0	-1	8	0	0	2.595700713469904	
i 1	720.9947823129252	1.2625	74	689	6	5	11	2	0	-1	2	0	0	2.595700713469904	
i 1	720.9995986394558	1.2625	74	373	4	5	14	8	0	-1	8	0	0	2.595700713469904	
i 1	721.4971904761904	0.2525	72	689	6	1	2	0	0	0	0	0	0	2.088571040475097	
i 1	721.5028095238096	0.2525	72	373	6	1	1	1	0	0	1	0	0	2.088571040475097	
i 1	721.7471904761904	0.2525	72	373	4	24	7	1	0	-1	1	0	0	3.088571040475097	
i 1	721.7680612244898	0.2525	72	689	4	24	9	0	0	-1	0	0	0	3.088571040475097	
i 1	721.9875578231292	3.535	75	689	5	3	14	8	0	1	8	0	0	6.7837035003629405	
i 1	721.9947823129252	0.2525	71	1075	5	5	15	8	0	-2	8	0	0	2.595700713469904	
i 1	721.9963877551021	3.535	75	373	4	4	16	2	0	1	2	0	0	6.7837035003629405	
i 1	722.0052176870748	0.505	72	373	6	1	9	1	0	0	1	0	0	2.088571040475097	
i 1	722.016455782313	0.2525	71	689	5	5	11	2	0	-2	2	0	0	2.595700713469904	
i 1	722.233544217687	0.7575000000000001	72	689	6	2	8	2	0	-2	2	0	0	6.7837035003629405	
i 1	722.2375578231292	1.2625	74	689	5	5	8	2	0	-1	2	0	0	2.595700713469904	
i 1	722.2479931972789	2.2725	74	689	6	5	16	8	0	-1	8	0	0	2.595700713469904	
i 1	722.2504013605442	2.2725	71	1075	6	5	9	8	0	-1	8	0	0	2.595700713469904	
i 1	722.2512040816326	1.01	74	373	5	5	15	8	0	-1	8	0	0	2.595700713469904	
i 1	722.2560204081633	0.7575000000000001	72	373	3	3	9	8	0	-2	8	0	0	6.7837035003629405	
i 1	722.4923741496599	0.505	72	689	4	1	2	0	0	0	0	0	0	2.088571040475097	
i 1	723.0124421768708	2.525	72	689	4	1	11	0	0	0	0	0	0	2.088571040475097	
i 1	723.0188639455782	0.2525	69	1075	6	1	8	0	0	-1	0	0	0	2.088571040475097	
i 1	723.2568231292518	2.2725	72	373	6	1	1	1	0	0	1	0	0	2.088571040475097	
i 1	723.2568231292518	5.05	71	1075	6	5	15	8	0	-2	8	0	0	2.595700713469904	
i 1	723.4883605442177	0.2525	75	689	4	4	11	2	0	-2	2	0	0	6.7837035003629405	
i 1	723.5004013605442	4.7975	71	689	5	5	13	2	0	-2	2	0	0	2.595700713469904	
i 1	723.7375578231292	3.7875	72	1075	3	9	10	2	0	1	2	0	0	5.7837035003629405	
i 1	723.7568231292518	0.2525	70	689	1	24	13	8	0	-1	8	0	0	4.0	
i 1	724.2447823129252	0.2525	72	373	4	24	5	1	0	-1	1	0	0	3.088571040475097	
i 1	724.2455850340136	0.2525	72	689	6	2	16	2	0	-2	2	0	0	6.7837035003629405	
i 1	724.266455782313	0.2525	72	689	4	24	10	0	0	-1	0	0	0	3.088571040475097	
i 1	724.4811360544218	3.2825	72	1075	6	1	7	1	0	0	1	0	0	2.088571040475097	
i 1	724.4883605442177	3.2825	69	689	4	1	13	0	0	0	0	0	0	2.088571040475097	
i 1	724.4955850340136	0.2525	71	373	4	5	13	8	0	-1	8	0	0	2.595700713469904	
i 1	724.4995986394558	0.2525	74	689	5	5	8	2	0	-1	2	0	0	2.595700713469904	
i 1	724.5060204081633	3.0300000000000002	72	689	6	2	13	8	0	1	8	0	0	6.7837035003629405	
i 1	724.7560204081633	0.505	74	373	5	5	2	8	0	-1	8	0	0	2.595700713469904	
i 1	724.7632448979592	0.2525	71	1075	6	5	7	8	0	-1	8	0	0	2.595700713469904	
i 1	724.9955850340136	4.545	72	689	4	1	4	0	0	0	0	0	0	2.088571040475097	
i 1	725.0036122448979	4.2925	72	373	4	24	7	1	0	-1	1	0	0	3.088571040475097	
i 1	725.2303333333333	0.2525	71	373	4	5	2	8	0	-1	8	0	0	2.595700713469904	
i 1	725.4867551020408	2.2725	72	689	6	2	11	2	0	-2	2	0	0	6.7837035003629405	
i 1	725.4875578231292	2.2725	72	373	3	3	16	8	0	-2	8	0	0	6.7837035003629405	
i 1	725.5012040816326	0.2525	74	373	5	5	16	8	0	-1	8	0	0	2.595700713469904	
i 1	725.7471904761904	0.505	74	689	6	5	8	2	0	-2	2	0	0	2.595700713469904	
i 1	726.2672585034013	0.505	74	373	5	5	4	8	0	-1	8	0	0	2.595700713469904	
i 1	726.7319387755102	0.505	71	1075	6	5	12	8	0	-1	8	0	0	2.595700713469904	
i 1	726.7487959183674	2.2725	75	689	5	3	2	8	0	1	8	0	0	6.7837035003629405	
i 1	726.759231292517	2.2725	75	373	4	4	16	2	0	1	2	0	0	6.7837035003629405	
i 1	727.0172585034013	0.2525	74	689	6	5	7	8	0	-1	8	0	0	2.595700713469904	
i 1	727.2319387755102	1.5150000000000001	74	689	6	5	16	2	0	-2	2	0	0	2.595700713469904	
i 1	727.264850340136	1.2625	71	373	4	5	10	8	0	-1	8	0	0	2.595700713469904	
i 1	727.4899659863945	1.5150000000000001	74	373	5	5	10	8	0	-1	8	0	0	2.595700713469904	
i 1	727.4955850340136	3.2825	74	689	5	5	12	2	0	-1	2	0	0	2.595700713469904	
i 1	727.7303333333333	0.505	72	689	4	1	9	0	0	0	0	0	0	2.088571040475097	
i 1	727.7431768707482	0.2525	75	689	4	4	2	2	0	-2	2	0	0	6.7837035003629405	
i 1	727.7471904761904	1.2625	72	689	4	24	6	0	0	-1	0	0	0	3.088571040475097	
i 1	727.7495986394558	2.02	72	689	6	2	10	8	0	1	8	0	0	6.7837035003629405	
i 1	727.9923741496599	0.7575000000000001	72	1075	3	9	15	2	0	1	2	0	0	5.7837035003629405	
i 1	728.2303333333333	0.505	69	1075	6	1	11	0	0	-1	0	0	0	2.088571040475097	
i 1	728.4995986394558	0.505	74	689	6	5	8	8	0	-1	8	0	0	2.595700713469904	
i 1	728.7455850340136	0.2525	71	689	5	5	9	2	0	-2	2	0	0	2.595700713469904	
i 1	728.7568231292518	1.2625	72	871	3	9	2	8	0	1	8	0	0	5.7837035003629405	
i 1	728.7600340136055	1.7675	69	871	6	1	16	1	0	-1	1	0	0	2.088571040475097	
i 1	728.9811360544218	15.4025	67	689	4	7	15	5	0	1	5	0	0	1.084099902903431	
i 1	728.9883605442177	0.505	71	373	5	5	6	8	0	-1	8	0	0	2.595700713469904	
i 1	728.9939795918367	1.5150000000000001	72	689	4	24	12	0	0	-1	0	0	0	3.088571040475097	
i 1	729.0020068027211	0.505	71	871	6	5	4	2	0	-2	2	0	0	2.595700713469904	
i 1	729.0020068027211	1.7675	74	373	6	5	10	8	0	-1	8	0	0	2.595700713469904	
i 1	729.0084285714286	2.525	75	373	3	4	16	2	0	1	2	0	0	6.7837035003629405	
i 1	729.0100340136055	2.525	75	689	5	3	4	8	0	1	8	0	0	6.7837035003629405	
i 1	729.2616394557823	0.2525	72	689	4	1	7	0	0	0	0	0	0	2.088571040475097	
i 1	729.4827414965987	7.575	69	871	6	1	11	0	0	0	0	0	0	2.088571040475097	
i 1	729.4915714285714	0.2525	71	689	5	5	3	2	0	-2	2	0	0	2.595700713469904	
i 1	729.5020068027211	4.545	69	689	4	1	14	0	0	0	0	0	0	2.088571040475097	
i 1	729.5116394557823	1.7675	74	871	6	5	3	8	0	-1	8	0	0	2.595700713469904	
i 1	729.7616394557823	1.2625	74	689	6	5	2	8	0	-1	8	0	0	2.595700713469904	
i 1	729.7656530612245	0.2525	72	373	3	3	6	8	0	-2	8	0	0	6.7837035003629405	
i 1	729.9923741496599	0.2525	72	689	6	2	10	8	0	1	8	0	0	6.7837035003629405	
i 1	730.0036122448979	5.05	71	689	5	5	10	2	0	-2	2	0	0	2.595700713469904	
i 1	730.016455782313	0.2525	72	871	5	9	6	2	0	1	2	0	0	5.7837035003629405	
i 1	730.0180612244898	5.05	71	871	6	5	7	2	0	-2	2	0	0	2.595700713469904	
i 1	730.2415714285714	0.2525	75	689	4	4	11	2	0	-2	2	0	0	6.7837035003629405	
i 1	730.4987959183674	2.7775	72	871	3	9	6	8	0	1	8	0	0	5.7837035003629405	
i 1	730.5052176870748	0.2525	72	373	6	1	4	1	0	0	1	0	0	2.088571040475097	
i 1	730.5084285714286	2.7775	72	689	6	2	4	8	0	1	8	0	0	6.7837035003629405	
i 1	730.5100340136055	0.2525	72	689	4	1	8	0	0	0	0	0	0	2.088571040475097	
i 1	730.7375578231292	0.2525	72	689	4	1	8	0	0	0	0	0	0	2.088571040475097	
i 1	730.740768707483	1.2625	72	373	3	3	15	8	0	-2	8	0	0	6.7837035003629405	
i 1	730.7415714285714	1.2625	72	689	6	2	16	2	0	-2	2	0	0	6.7837035003629405	
i 1	730.7560204081633	0.2525	72	373	4	24	2	1	0	-1	1	0	0	3.088571040475097	
i 1	730.9979931972789	0.2525	72	689	4	24	7	0	0	-1	0	0	0	3.088571040475097	
i 1	730.9995986394558	2.02	72	689	4	1	10	0	0	0	0	0	0	2.088571040475097	
i 1	731.0108367346938	0.505	74	689	5	5	10	2	0	-2	2	0	0	2.595700713469904	
i 1	731.2439795918367	0.505	74	689	5	5	6	2	0	-1	2	0	0	2.595700713469904	
i 1	731.2600340136055	1.7675	72	373	6	1	3	1	0	0	1	0	0	2.088571040475097	
i 1	731.485149659864	1.01	74	871	6	5	7	8	0	-1	8	0	0	2.595700713469904	
i 1	731.7359523809524	0.2525	74	689	6	5	4	8	0	-1	8	0	0	2.595700713469904	
i 1	731.983544217687	0.2525	75	689	5	3	7	8	0	1	8	0	0	6.7837035003629405	
i 1	732.0116394557823	0.2525	75	689	4	4	5	2	0	-2	2	0	0	6.7837035003629405	
i 1	732.0156530612245	0.2525	71	373	5	5	5	8	0	-1	8	0	0	2.595700713469904	
i 1	732.2423741496599	0.2525	74	689	5	5	11	2	0	-1	2	0	0	2.595700713469904	
i 1	732.2463877551021	1.7675	72	373	3	3	9	8	0	-2	8	0	0	6.7837035003629405	
i 1	732.2552176870748	1.7675	72	689	6	2	3	2	0	-2	2	0	0	6.7837035003629405	
i 1	732.4859523809524	0.7575000000000001	71	373	5	5	8	8	0	-1	8	0	0	2.595700713469904	
i 1	732.5004013605442	0.505	74	689	5	5	12	2	0	-2	2	0	0	2.595700713469904	
i 1	732.9803333333333	0.2525	74	871	6	5	3	8	0	-1	8	0	0	2.595700713469904	
i 1	732.985149659864	3.535	75	689	5	3	16	8	0	1	8	0	0	6.7837035003629405	
i 1	732.9891632653062	2.525	72	689	4	1	11	0	0	0	0	0	0	2.088571040475097	
i 1	733.0028095238096	3.2825	75	373	3	4	4	2	0	1	2	0	0	6.7837035003629405	
i 1	733.0116394557823	2.525	72	373	4	24	4	1	0	-1	1	0	0	3.088571040475097	
i 1	733.2520068027211	0.2525	74	689	6	5	13	8	0	-1	8	0	0	2.595700713469904	
i 1	733.2528095238096	0.505	74	689	5	5	12	2	0	-2	2	0	0	2.595700713469904	
i 1	733.7399659863945	0.2525	74	871	6	5	1	8	0	-1	8	0	0	2.595700713469904	
i 1	733.7487959183674	2.02	71	373	5	5	16	8	0	-1	8	0	0	2.595700713469904	
i 1	733.990768707483	6.8175	72	689	6	2	15	8	0	1	8	0	0	6.7837035003629405	
i 1	733.9979931972789	0.505	69	871	6	1	6	1	0	-1	1	0	0	2.088571040475097	
i 1	734.0012040816326	1.7675	72	871	3	9	7	8	0	1	8	0	0	5.7837035003629405	
i 1	734.0108367346938	2.02	74	689	5	5	8	2	0	-2	2	0	0	2.595700713469904	
i 1	734.514850340136	2.2725	69	689	4	1	10	0	0	0	0	0	0	2.088571040475097	
i 1	735.0012040816326	2.7775	74	689	5	5	16	2	0	-1	2	0	0	2.595700713469904	
i 1	735.0124421768708	2.7775	74	373	6	5	14	8	0	-1	8	0	0	2.595700713469904	
i 1	735.4939795918367	0.2525	72	689	4	1	13	0	0	0	0	0	0	2.088571040475097	
i 1	735.5116394557823	0.2525	72	689	4	24	11	0	0	-1	0	0	0	3.088571040475097	
i 1	735.7359523809524	0.505	71	373	6	5	8	8	0	-1	8	0	0	2.595700713469904	
i 1	735.7447823129252	2.2725	72	373	4	24	8	1	0	-1	1	0	0	3.088571040475097	
i 1	735.7608367346938	2.2725	72	689	4	1	3	0	0	0	0	0	0	2.088571040475097	
i 1	735.7696666666667	4.7975	72	871	5	9	12	8	0	1	8	0	0	5.7837035003629405	
i 1	736.0140476190476	0.2525	74	871	6	5	3	8	0	-1	8	0	0	2.595700713469904	
i 1	736.2343469387755	0.2525	71	871	6	5	9	2	0	-2	2	0	0	2.595700713469904	
i 1	736.235149659864	0.2525	74	689	5	5	16	8	0	-1	8	0	0	2.595700713469904	
i 1	736.2367551020408	0.2525	75	689	4	4	13	2	0	-2	2	0	0	6.7837035003629405	
i 1	736.4971904761904	3.535	72	689	6	2	16	2	0	-2	2	0	0	6.7837035003629405	
i 1	736.4987959183674	0.2525	71	689	6	5	12	2	0	-2	2	0	0	2.595700713469904	
i 1	736.5044149659864	0.2525	71	373	6	5	6	8	0	-1	8	0	0	2.595700713469904	
i 1	736.5084285714286	3.535	72	373	3	3	1	8	0	-2	8	0	0	6.7837035003629405	
i 1	736.735149659864	2.02	74	689	5	5	16	8	0	-1	8	0	0	2.595700713469904	
i 1	736.7439795918367	1.7675	72	689	4	24	12	0	0	-1	0	0	0	3.088571040475097	
i 1	736.7447823129252	2.7775	74	871	6	5	8	8	0	-1	8	0	0	2.595700713469904	
i 1	736.9979931972789	1.5150000000000001	69	871	3	1	12	1	0	-1	1	0	0	2.088571040475097	
i 1	737.4939795918367	3.0300000000000002	69	689	4	1	14	0	0	0	0	0	0	2.088571040475097	
i 1	737.5116394557823	2.7775	69	871	6	1	15	0	0	0	0	0	0	2.088571040475097	
i 1	737.7495986394558	3.7875	71	689	6	5	6	2	0	-2	2	0	0	2.595700713469904	
i 1	737.7680612244898	3.7875	71	871	6	5	4	2	0	-2	2	0	0	2.595700713469904	
i 1	738.5028095238096	0.2525	72	373	6	1	4	1	0	0	1	0	0	2.088571040475097	
i 1	738.5116394557823	0.505	72	373	4	24	9	1	0	-1	1	0	0	3.088571040475097	
i 1	738.7383605442177	0.505	72	689	4	1	7	0	0	0	0	0	0	2.088571040475097	
i 1	738.7439795918367	0.2525	74	373	6	5	5	8	0	-1	8	0	0	2.595700713469904	
i 1	738.983544217687	0.2525	69	871	3	1	7	1	0	-1	1	0	0	2.088571040475097	
i 1	738.9891632653062	3.535	75	689	5	3	4	8	0	1	8	0	0	6.7837035003629405	
i 1	738.9891632653062	3.535	75	373	3	4	9	2	0	1	2	0	0	6.7837035003629405	
i 1	738.9971904761904	0.2525	74	689	5	5	15	2	0	-1	2	0	0	2.595700713469904	
i 1	739.233544217687	2.525	72	689	4	1	2	0	0	0	0	0	0	2.088571040475097	
i 1	739.2391632653062	0.505	71	373	6	5	6	8	0	-1	8	0	0	2.595700713469904	
i 1	739.2624421768708	2.525	72	373	6	1	9	1	0	0	1	0	0	2.088571040475097	
i 1	739.4923741496599	0.505	74	373	6	5	16	8	0	-1	8	0	0	2.595700713469904	
i 1	739.7455850340136	0.2525	74	871	6	5	5	8	0	-1	8	0	0	2.595700713469904	
i 1	739.9955850340136	0.505	74	689	5	5	13	2	0	-1	2	0	0	2.595700713469904	
i 1	740.016455782313	0.2525	74	689	5	5	3	2	0	-2	2	0	0	2.595700713469904	
i 1	740.264850340136	0.2525	69	871	3	1	15	1	0	-1	1	0	0	2.088571040475097	
i 1	740.264850340136	0.2525	74	871	6	5	7	8	0	-1	8	0	0	2.595700713469904	
i 1	740.4947823129252	2.02	69	871	6	1	1	0	0	0	0	0	0	2.088571040475097	
i 1	740.5060204081633	0.2525	72	689	4	1	7	0	0	0	0	0	0	2.088571040475097	
i 1	740.5084285714286	2.7775	74	689	5	5	3	2	0	-2	2	0	0	2.595700713469904	
i 1	740.5116394557823	2.7775	71	373	6	5	5	8	0	-1	8	0	0	2.595700713469904	
i 1	740.5188639455782	0.2525	72	871	5	9	2	2	0	1	2	0	0	5.7837035003629405	
i 1	740.7311360544218	2.2725	69	689	4	1	8	0	0	0	0	0	0	2.088571040475097	
i 1	740.7383605442177	0.2525	75	689	4	4	14	2	0	-2	2	0	0	6.7837035003629405	
i 1	740.7415714285714	0.2525	72	373	3	3	7	8	0	-2	8	0	0	6.7837035003629405	
i 1	741.0188639455782	0.2525	72	871	5	9	15	8	0	1	8	0	0	5.7837035003629405	
i 1	741.2343469387755	0.2525	72	373	3	3	6	8	0	-2	8	0	0	6.7837035003629405	
i 1	741.2680612244898	4.7975	72	689	6	2	13	8	0	1	8	0	0	6.7837035003629405	
i 1	741.4923741496599	1.2625	72	871	5	9	5	8	0	1	8	0	0	5.7837035003629405	
i 1	741.4955850340136	0.505	74	689	5	5	7	8	0	-1	8	0	0	2.595700713469904	
i 1	741.5004013605442	0.2525	74	689	5	5	8	2	0	-1	2	0	0	2.595700713469904	
i 1	741.7391632653062	0.2525	74	871	6	5	15	8	0	-1	8	0	0	2.595700713469904	
i 1	741.7415714285714	0.2525	69	871	3	1	2	1	0	-1	1	0	0	2.088571040475097	
i 1	741.7471904761904	0.2525	72	689	4	24	16	0	0	-1	0	0	0	3.088571040475097	
i 1	741.9963877551021	2.2725	74	373	6	5	4	8	0	-1	8	0	0	2.595700713469904	
i 1	742.0012040816326	2.2725	72	373	4	24	2	1	0	-1	1	0	0	3.088571040475097	
i 1	742.0140476190476	0.505	74	689	5	5	10	2	0	-1	2	0	0	2.595700713469904	
i 1	742.014850340136	2.2725	72	689	4	1	13	0	0	0	0	0	0	2.088571040475097	
i 1	742.4819387755102	1.7675	72	373	5	3	14	8	0	-2	8	0	0	6.7837035003629405	
i 1	742.4819387755102	1.7675	74	689	6	5	14	2	0	-1	2	0	0	2.595700713469904	
i 1	742.5004013605442	0.2525	69	871	3	1	12	0	0	0	0	0	0	2.088571040475097	
i 1	742.5068231292518	2.2725	72	689	6	2	4	2	0	-2	2	0	0	6.7837035003629405	
i 1	742.7439795918367	1.5150000000000001	72	1075	5	9	16	2	0	-2	2	0	0	5.7837035003629405	
i 1	742.7672585034013	0.2525	69	1075	3	1	10	0	0	-1	0	0	0	2.088571040475097	
i 1	742.9827414965987	0.2525	69	1075	3	1	3	1	0	0	1	0	0	2.088571040475097	
i 1	743.0172585034013	0.2525	72	689	4	24	15	0	0	-1	0	0	0	3.088571040475097	
i 1	743.2343469387755	1.01	69	1075	3	1	7	0	0	-1	0	0	0	2.088571040475097	
i 1	743.2375578231292	1.01	74	689	5	5	3	8	0	-1	8	0	0	2.595700713469904	
i 1	743.2544149659864	6.0600000000000005	69	689	4	1	13	0	0	0	0	0	0	2.088571040475097	
i 1	743.2552176870748	1.01	74	1075	4	5	14	2	0	-2	2	0	0	2.595700713469904	
i 1	743.733544217687	0.505	72	689	4	24	9	0	0	-1	0	0	0	3.088571040475097	
i 1	743.735149659864	0.505	72	1075	5	9	5	2	0	-2	2	0	0	5.7837035003629405	
i 1	743.7536122448979	3.7875	71	689	5	5	4	2	0	-2	2	0	0	2.595700713469904	
i 1	744.2367551020408	0.7575000000000001	71	561	5	5	9	2	0	-2	2	0	0	2.595700713469904	
i 1	744.2367551020408	1.5150000000000001	70	107	1	24	10	8	0	-1	8	0	0	4.0	
i 1	744.2423741496599	1.2625	72	423	4	24	14	0	0	-1	0	0	0	3.088571040475097	
i 1	744.2439795918367	2.02	72	107	6	9	4	2	0	1	2	0	0	5.7837035003629405	
i 1	744.2455850340136	0.505	69	107	4	1	10	1	0	0	1	0	0	2.088571040475097	
i 1	744.2471904761904	1.7675	69	561	4	24	7	0	0	-1	0	0	0	3.088571040475097	
i 1	744.2495986394558	0.2525	74	423	6	5	13	8	0	-2	8	0	0	2.595700713469904	
i 1	744.2552176870748	8.08	67	561	4	7	6	5	0	1	5	0	0	1.084099902903431	
i 1	744.2560204081633	3.2825	71	107	5	5	16	2	0	-1	2	0	0	2.595700713469904	
i 1	744.2568231292518	0.505	75	423	5	3	1	8	0	-2	8	0	0	6.7837035003629405	
i 1	744.2688639455782	0.2525	72	107	6	9	9	2	0	1	2	0	0	5.7837035003629405	
i 1	744.4987959183674	0.2525	71	561	5	5	6	2	0	-1	2	0	0	2.595700713469904	
i 1	744.5004013605442	0.505	73	561	1	24	5	2	0	-2	2	0	0	4.0	
i 1	744.509231292517	7.07	72	107	4	1	13	1	0	0	1	0	0	2.088571040475097	
i 1	744.7359523809524	3.0300000000000002	72	561	5	3	9	2	0	1	2	0	0	6.7837035003629405	
i 1	744.766455782313	0.2525	72	423	3	4	6	2	0	-2	2	0	0	6.7837035003629405	
i 1	745.0156530612245	2.7775	75	423	5	3	13	8	0	-2	8	0	0	6.7837035003629405	
i 1	745.0188639455782	0.505	71	561	5	5	16	2	0	-1	2	0	0	2.595700713469904	
i 1	745.2423741496599	0.2525	73	561	1	24	4	8	0	-1	8	0	0	4.0	
i 1	745.2544149659864	0.2525	71	561	5	5	4	2	0	-2	2	0	0	2.595700713469904	
i 1	745.4955850340136	0.2525	72	689	4	1	4	0	0	0	0	0	0	2.088571040475097	
i 1	745.5020068027211	0.505	74	423	6	5	15	2	0	-1	2	0	0	2.595700713469904	
i 1	745.733544217687	0.7575000000000001	72	423	4	24	1	0	0	-1	0	0	0	3.088571040475097	
i 1	745.7367551020408	0.2525	71	107	7	5	11	2	0	-2	2	0	0	2.595700713469904	
i 1	745.9827414965987	0.2525	74	423	6	5	14	8	0	-2	8	0	0	2.595700713469904	
i 1	746.0012040816326	0.505	72	689	6	2	4	2	0	-2	2	0	0	6.7837035003629405	
i 1	746.0036122448979	0.2525	69	107	4	1	6	1	0	0	1	0	0	2.088571040475097	
i 1	746.009231292517	0.2525	74	689	6	5	15	2	0	-1	2	0	0	2.595700713469904	
i 1	746.2367551020408	0.2525	72	561	4	1	12	1	0	-1	1	0	0	2.088571040475097	
i 1	746.2512040816326	0.2525	72	107	6	9	13	2	0	1	2	0	0	5.7837035003629405	
i 1	746.2656530612245	0.2525	71	107	7	5	12	2	0	-2	2	0	0	2.595700713469904	
i 1	746.266455782313	2.2725	74	423	6	5	14	2	0	-1	2	0	0	2.595700713469904	
i 1	746.4867551020408	2.02	71	561	5	5	16	2	0	-1	2	0	0	2.595700713469904	
i 1	746.5012040816326	2.525	72	689	4	1	7	0	0	0	0	0	0	2.088571040475097	
i 1	746.5108367346938	0.2525	72	561	4	4	13	2	0	-2	2	0	0	6.7837035003629405	
i 1	746.5140476190476	2.525	72	107	6	9	13	2	0	1	2	0	0	5.7837035003629405	
i 1	746.7560204081633	2.525	72	689	6	2	5	8	0	1	8	0	0	6.7837035003629405	
i 1	746.7576258503401	1.2625	70	107	1	24	4	8	0	-1	8	0	0	4.0	
i 1	746.7624421768708	0.2525	69	423	6	1	5	1	0	0	1	0	0	2.088571040475097	
i 1	746.9843469387755	2.2725	69	107	4	1	16	1	0	0	1	0	0	2.088571040475097	
i 1	747.4803333333333	1.7675	72	107	6	9	4	2	0	1	2	0	0	5.7837035003629405	
i 1	747.4867551020408	2.7775	72	689	6	2	9	2	0	-2	2	0	0	6.7837035003629405	
i 1	747.509231292517	1.7675	71	107	7	5	3	2	0	-2	2	0	0	2.595700713469904	
i 1	747.516455782313	1.7675	74	689	6	5	6	2	0	-1	2	0	0	2.595700713469904	
i 1	747.5180612244898	0.505	70	561	1	24	15	8	0	-1	8	0	0	4.0	
i 1	748.4883605442177	0.2525	71	107	5	5	3	2	0	-1	2	0	0	2.595700713469904	
i 1	748.5132448979592	2.525	71	561	5	5	7	2	0	-2	2	0	0	2.595700713469904	
i 1	748.7471904761904	0.2525	71	561	5	5	10	2	0	-1	2	0	0	2.595700713469904	
i 1	748.9971904761904	2.02	74	423	6	5	15	8	0	-2	8	0	0	2.595700713469904	
i 1	749.0100340136055	0.2525	72	423	3	4	5	2	0	-2	2	0	0	6.7837035003629405	
i 1	749.0124421768708	0.2525	69	561	4	24	8	0	0	-1	0	0	0	3.088571040475097	
i 1	749.2319387755102	1.7675	72	561	4	4	6	2	0	-2	2	0	0	6.7837035003629405	
i 1	749.2327414965987	1.7675	72	423	4	4	14	2	0	-2	2	0	0	6.7837035003629405	
i 1	749.2399659863945	2.2725	69	689	6	1	10	0	0	0	0	0	0	2.088571040475097	
i 1	749.240768707483	1.01	72	107	6	9	3	2	0	1	2	0	0	5.7837035003629405	
i 1	749.2479931972789	0.7575000000000001	71	107	5	5	13	2	0	-2	2	0	0	2.595700713469904	
i 1	749.2544149659864	0.7575000000000001	74	689	5	5	1	2	0	-1	2	0	0	2.595700713469904	
i 1	749.2680612244898	3.2825	69	423	3	1	3	1	0	0	1	0	0	2.088571040475097	
i 1	749.2688639455782	3.0300000000000002	72	561	4	1	4	1	0	-1	1	0	0	2.088571040475097	
i 1	749.9803333333333	2.2725	72	689	6	2	12	8	0	1	8	0	0	6.7837035003629405	
i 1	749.9875578231292	2.525	71	107	5	5	3	2	0	-1	2	0	0	2.595700713469904	
i 1	750.0108367346938	2.2725	71	689	5	5	15	2	0	-2	2	0	0	2.595700713469904	
i 1	750.0188639455782	2.525	72	107	6	9	1	2	0	1	2	0	0	5.7837035003629405	
i 1	750.2399659863945	2.2725	70	107	1	24	7	8	0	-1	8	0	0	4.0	
i 1	750.9843469387755	0.2525	74	689	5	5	10	2	0	-1	2	0	0	2.595700713469904	
i 1	750.990768707483	1.5150000000000001	75	423	5	3	4	8	0	-2	8	0	0	6.7837035003629405	
i 1	750.9979931972789	0.7575000000000001	74	423	6	5	11	2	0	-1	2	0	0	2.595700713469904	
i 1	751.0124421768708	1.2625	72	561	5	3	12	2	0	1	2	0	0	6.7837035003629405	
i 1	751.2383605442177	0.7575000000000001	74	423	6	5	13	8	0	-2	8	0	0	2.595700713469904	
i 1	751.4947823129252	1.01	72	423	4	24	10	0	0	-1	0	0	0	3.088571040475097	
i 1	751.5116394557823	0.7575000000000001	69	561	4	24	1	0	0	-1	0	0	0	3.088571040475097	
i 1	751.7423741496599	0.7575000000000001	72	107	6	9	5	2	0	1	2	0	0	5.7837035003629405	
i 1	751.7479931972789	0.7575000000000001	69	107	4	1	5	1	0	0	1	0	0	2.088571040475097	
i 1	751.7528095238096	0.505	69	689	6	1	12	0	0	0	0	0	0	2.088571040475097	
i 1	751.7552176870748	0.7575000000000001	71	107	5	5	15	2	0	-2	2	0	0	2.595700713469904	
i 1	751.9915714285714	0.2525	74	689	5	5	16	2	0	-1	2	0	0	2.595700713469904	
i 1	752.0116394557823	0.505	72	107	4	1	16	1	0	0	1	0	0	2.088571040475097	
i 1	752.2311360544218	0.2525	75	690	6	2	10	2	0	1	2	0	0	6.7837035003629405	
i 1	752.2383605442177	0.2525	75	423	5	3	11	2	0	1	2	0	0	6.7837035003629405	
i 1	752.2431768707482	0.2525	71	690	5	5	1	2	0	-1	2	0	0	2.595700713469904	
i 1	752.2455850340136	0.2525	69	423	4	24	13	0	0	-1	0	0	0	3.088571040475097	
i 1	752.2463877551021	0.2525	72	690	6	1	3	0	0	0	0	0	0	2.088571040475097	
i 1	752.2479931972789	0.2525	67	423	4	7	10	0	0	1	0	0	0	1.084099902903431	
i 1	752.2495986394558	0.2525	71	690	5	5	9	2	0	-1	2	0	0	2.595700713469904	
i 1	752.2520068027211	0.2525	60	690	4	14	4	0	0	0	0	0	0	1.8341829555965272	
i 1	752.2552176870748	0.2525	72	423	4	1	16	0	0	-1	0	0	0	2.088571040475097	
i 1	752.2584285714286	0.2525	67	690	4	14	6	5	0	1	5	0	0	1.8341829555965272	
i 1	752.4827414965987	14.8975	72	199	4	1	11	1	0	-1	1	0	0	2.088571040475097	
i 1	752.4827414965987	0.505	69	199	4	1	2	0	0	-1	0	0	0	2.088571040475097	
i 1	752.483544217687	23.9875	60	585	4	7	11	5	0	0	5	0	0	1.084099902903431	
i 1	752.4843469387755	0.2525	69	199	5	24	14	1	0	-1	1	0	0	3.088571040475097	
i 1	752.4843469387755	10.352500000000001	60	901	4	14	10	5	0	0	5	0	0	1.8341829555965272	
i 1	752.4891632653062	0.2525	75	199	5	3	5	8	0	1	8	0	0	6.7837035003629405	
i 1	752.4947823129252	2.02	74	199	5	5	16	8	0	-1	8	0	0	2.595700713469904	
i 1	752.4971904761904	0.505	74	199	5	5	5	8	0	-2	8	0	0	2.595700713469904	
i 1	752.5068231292518	0.2525	72	585	4	24	4	1	0	-1	1	0	0	3.088571040475097	
i 1	752.5068231292518	1.5150000000000001	75	199	6	9	12	8	0	-2	8	0	0	5.7837035003629405	
i 1	752.5108367346938	14.8975	72	901	6	1	4	1	0	-1	1	0	0	2.088571040475097	
i 1	752.516455782313	2.02	71	901	5	5	4	2	0	-2	2	0	0	2.595700713469904	
i 1	752.5172585034013	1.2625	75	901	6	2	10	2	0	-2	2	0	0	6.7837035003629405	
i 1	752.5172585034013	3.535	67	901	4	14	13	5	0	1	5	0	0	1.8341829555965272	
i 1	752.5180612244898	0.2525	72	585	5	3	6	2	0	-2	2	0	0	6.7837035003629405	
i 1	752.5180612244898	3.535	70	199	1	24	10	2	0	-2	2	0	0	4.0	
i 1	752.5188639455782	2.525	72	199	6	9	11	2	0	-2	2	0	0	5.7837035003629405	
i 1	752.5188639455782	0.505	71	901	5	5	9	2	0	-1	2	0	0	2.595700713469904	
i 1	752.7439795918367	2.2725	72	901	6	2	1	8	0	-2	8	0	0	6.7837035003629405	
i 1	752.985149659864	0.2525	72	585	4	24	8	1	0	-1	1	0	0	3.088571040475097	
i 1	753.0124421768708	3.535	69	585	4	1	12	0	0	0	0	0	0	2.088571040475097	
i 1	753.0156530612245	0.2525	74	585	6	5	6	8	0	-2	8	0	0	2.595700713469904	
i 1	753.0188639455782	0.2525	74	199	7	5	7	8	0	-1	8	0	0	2.595700713469904	
i 1	753.259231292517	0.2525	74	199	5	5	5	8	0	-2	8	0	0	2.595700713469904	
i 1	753.2656530612245	0.2525	71	901	5	5	10	2	0	-1	2	0	0	2.595700713469904	
i 1	753.2680612244898	3.2825	72	199	3	1	11	0	0	-1	0	0	0	2.088571040475097	
i 1	753.4939795918367	2.2725	71	199	7	5	13	8	0	-1	8	0	0	2.595700713469904	
i 1	753.5084285714286	2.02	74	585	5	5	5	2	0	-2	2	0	0	2.595700713469904	
i 1	753.764850340136	2.02	75	199	5	4	11	2	0	-2	2	0	0	6.7837035003629405	
i 1	754.0004013605442	1.7675	75	585	4	4	11	2	0	-2	2	0	0	6.7837035003629405	
i 1	754.0188639455782	0.2525	70	585	1	24	5	2	0	-2	2	0	0	4.0	
i 1	754.4947823129252	4.04	74	199	5	5	9	8	0	-2	8	0	0	2.595700713469904	
i 1	754.5036122448979	4.2925	71	901	5	5	15	2	0	-1	2	0	0	2.595700713469904	
i 1	754.733544217687	0.2525	70	585	1	24	7	8	0	-2	8	0	0	4.0	
i 1	754.7479931972789	5.8075	75	199	6	9	15	8	0	-2	8	0	0	5.7837035003629405	
i 1	754.764850340136	1.2625	75	901	6	2	9	2	0	-2	2	0	0	6.7837035003629405	
i 1	755.259231292517	0.2525	70	585	1	24	3	8	0	-2	8	0	0	4.0	
i 1	755.4955850340136	0.505	71	901	5	5	6	2	0	-2	2	0	0	2.595700713469904	
i 1	755.7327414965987	2.02	72	585	5	3	1	2	0	-2	2	0	0	6.7837035003629405	
i 1	755.7367551020408	0.505	74	199	5	5	13	8	0	-1	8	0	0	2.595700713469904	
i 1	755.7495986394558	0.2525	75	199	5	3	1	8	0	1	8	0	0	6.7837035003629405	
i 1	756.0076258503401	6.8175	67	901	5	14	3	5	0	1	5	0	0	1.8341829555965272	
i 1	756.009231292517	0.2525	74	199	4	5	12	8	0	-1	8	0	0	2.595700713469904	
i 1	756.0180612244898	2.525	75	901	4	2	8	2	0	-2	2	0	0	6.7837035003629405	
i 1	756.0188639455782	1.7675	75	199	6	3	5	8	0	1	8	0	0	6.7837035003629405	
i 1	756.2311360544218	0.2525	74	585	6	5	11	2	0	-2	2	0	0	2.595700713469904	
i 1	756.2415714285714	0.2525	74	585	5	5	2	8	0	-2	8	0	0	2.595700713469904	
i 1	756.4803333333333	0.2525	72	585	4	24	11	1	0	-1	1	0	0	3.088571040475097	
i 1	756.4803333333333	1.01	71	901	5	5	1	2	0	-2	2	0	0	2.595700713469904	
i 1	756.4955850340136	0.2525	69	199	3	24	14	1	0	-1	1	0	0	3.088571040475097	
i 1	756.7439795918367	0.505	69	585	4	1	11	0	0	0	0	0	0	2.088571040475097	
i 1	756.7495986394558	0.2525	69	901	6	1	4	1	0	0	1	0	0	2.088571040475097	
i 1	756.990768707483	0.505	69	199	3	24	6	1	0	-1	1	0	0	3.088571040475097	
i 1	757.2319387755102	0.2525	74	199	5	5	9	8	0	-1	8	0	0	2.595700713469904	
i 1	757.2512040816326	0.505	69	199	4	1	14	0	0	-1	0	0	0	2.088571040475097	
i 1	757.4859523809524	0.2525	69	585	4	1	2	0	0	0	0	0	0	2.088571040475097	
i 1	757.4955850340136	1.2625	70	199	1	24	6	2	0	-2	2	0	0	4.0	
i 1	757.5004013605442	2.2725	74	585	5	5	6	8	0	-2	8	0	0	2.595700713469904	
i 1	757.5004013605442	2.525	74	199	4	5	5	8	0	-1	8	0	0	2.595700713469904	
i 1	757.5132448979592	4.04	72	901	6	2	3	8	0	-2	8	0	0	6.7837035003629405	
i 1	757.5140476190476	4.04	72	199	6	9	10	2	0	-2	2	0	0	5.7837035003629405	
i 1	757.7391632653062	0.505	69	901	6	1	11	1	0	0	1	0	0	2.088571040475097	
i 1	757.7696666666667	0.2525	69	199	3	24	1	1	0	-1	1	0	0	3.088571040475097	
i 1	758.2319387755102	0.2525	69	199	3	24	16	1	0	-1	1	0	0	3.088571040475097	
i 1	758.4899659863945	0.2525	75	585	4	4	4	2	0	-2	2	0	0	6.7837035003629405	
i 1	758.4979931972789	0.2525	72	585	4	24	11	1	0	-1	1	0	0	3.088571040475097	
i 1	758.5012040816326	0.505	69	901	6	1	11	1	0	0	1	0	0	2.088571040475097	
i 1	758.5156530612245	0.2525	71	199	7	5	5	8	0	-1	8	0	0	2.595700713469904	
i 1	758.7359523809524	2.2725	71	901	5	5	13	2	0	-2	2	0	0	2.595700713469904	
i 1	758.7568231292518	1.7675	75	901	4	2	14	2	0	-2	2	0	0	6.7837035003629405	
i 1	758.7688639455782	2.525	74	199	5	5	16	8	0	-1	8	0	0	2.595700713469904	
i 1	758.9859523809524	0.2525	69	199	3	24	13	1	0	-1	1	0	0	3.088571040475097	
i 1	759.014850340136	0.2525	72	199	3	1	2	0	0	-1	0	0	0	2.088571040475097	
i 1	759.2327414965987	1.5150000000000001	69	199	4	1	15	0	0	-1	0	0	0	2.088571040475097	
i 1	759.2528095238096	1.5150000000000001	69	901	6	1	11	1	0	0	1	0	0	2.088571040475097	
i 1	759.4971904761904	1.5150000000000001	70	199	1	24	11	2	0	-2	2	0	0	4.0	
i 1	759.7431768707482	0.2525	68	585	1	24	13	1	0	0	1	0	0	4.0	
i 1	759.7688639455782	0.2525	74	199	5	5	8	8	0	-2	8	0	0	2.595700713469904	
i 1	760.0036122448979	2.525	74	585	6	5	7	2	0	-2	2	0	0	2.595700713469904	
i 1	760.0140476190476	2.525	71	199	7	5	9	8	0	-1	8	0	0	2.595700713469904	
i 1	760.4899659863945	2.2725	72	199	3	1	6	0	0	-1	0	0	0	2.088571040475097	
i 1	760.509231292517	1.7675	75	585	4	4	1	2	0	-2	2	0	0	6.7837035003629405	
i 1	760.5172585034013	2.02	69	585	4	1	7	0	0	0	0	0	0	2.088571040475097	
i 1	760.5188639455782	1.7675	75	199	5	4	3	2	0	-2	2	0	0	6.7837035003629405	
i 1	761.0116394557823	0.2525	74	199	4	5	3	8	0	-1	8	0	0	2.595700713469904	
i 1	761.240768707483	1.2625	75	901	4	2	15	2	0	-2	2	0	0	6.7837035003629405	
i 1	761.2415714285714	1.2625	75	199	6	9	15	8	0	-2	8	0	0	5.7837035003629405	
i 1	761.2568231292518	0.2525	71	901	5	5	14	2	0	-2	2	0	0	2.595700713469904	
i 1	761.2696666666667	0.2525	74	585	5	5	9	8	0	-2	8	0	0	2.595700713469904	
i 1	761.4811360544218	1.2625	74	199	5	5	7	8	0	-2	8	0	0	2.595700713469904	
i 1	761.4843469387755	4.2925	71	901	5	5	15	2	0	-1	2	0	0	2.595700713469904	
i 1	761.4867551020408	3.0300000000000002	75	199	6	3	6	8	0	1	8	0	0	6.7837035003629405	
i 1	761.5180612244898	3.0300000000000002	72	585	5	3	12	2	0	-2	2	0	0	6.7837035003629405	
i 1	762.4915714285714	0.2525	72	585	4	24	10	1	0	-1	1	0	0	3.088571040475097	
i 1	762.4931768707482	0.505	74	199	4	5	1	8	0	-1	8	0	0	2.595700713469904	
i 1	762.4979931972789	0.2525	75	199	5	4	14	2	0	-2	2	0	0	6.7837035003629405	
i 1	762.5004013605442	0.2525	72	901	6	2	3	8	0	-2	8	0	0	6.7837035003629405	
i 1	762.5068231292518	0.7575000000000001	74	585	5	5	2	8	0	-2	8	0	0	2.595700713469904	
i 1	762.7311360544218	6.8175	60	901	5	14	3	5	0	0	5	0	0	1.8341829555965272	
i 1	762.7375578231292	0.2525	69	199	3	24	9	1	0	-1	1	0	0	3.088571040475097	
i 1	762.7383605442177	7.8275	70	199	1	24	9	2	0	-2	2	0	0	4.0	
i 1	762.7399659863945	27.27	67	901	4	14	14	5	0	1	5	0	0	1.8341829555965272	
i 1	762.7415714285714	0.2525	72	901	4	2	13	8	0	-2	8	0	0	6.7837035003629405	
i 1	762.7423741496599	3.0300000000000002	74	199	6	5	15	8	0	-2	8	0	0	2.595700713469904	
i 1	762.7688639455782	0.7575000000000001	75	199	5	4	2	2	0	-2	2	0	0	6.7837035003629405	
i 1	762.7696666666667	0.2525	69	901	6	1	11	1	0	0	1	0	0	2.088571040475097	
i 1	762.9859523809524	2.2725	72	199	3	1	12	0	0	-1	0	0	0	2.088571040475097	
i 1	763.0020068027211	0.2525	68	585	1	24	6	0	0	0	0	0	0	4.0	
i 1	763.0100340136055	2.02	69	585	6	1	1	0	0	0	0	0	0	2.088571040475097	
i 1	763.014850340136	0.2525	71	199	4	5	8	8	0	-1	8	0	0	2.595700713469904	
i 1	763.2343469387755	0.2525	74	585	5	5	2	2	0	-2	2	0	0	2.595700713469904	
i 1	763.2359523809524	0.2525	71	901	5	5	4	2	0	-2	2	0	0	2.595700713469904	
i 1	763.2383605442177	0.2525	72	199	6	9	13	2	0	-2	2	0	0	5.7837035003629405	
i 1	763.4859523809524	3.2825	75	199	6	9	13	8	0	-2	8	0	0	5.7837035003629405	
i 1	763.4883605442177	0.2525	74	585	5	5	6	8	0	-2	8	0	0	2.595700713469904	
i 1	763.5052176870748	0.505	74	199	4	5	1	8	0	-1	8	0	0	2.595700713469904	
i 1	763.5180612244898	3.2825	75	901	4	2	7	2	0	-2	2	0	0	6.7837035003629405	
i 1	763.7616394557823	0.7575000000000001	74	585	5	5	2	2	0	-2	2	0	0	2.595700713469904	
i 1	763.983544217687	0.2525	71	901	5	5	12	2	0	-2	2	0	0	2.595700713469904	
i 1	764.2319387755102	3.0300000000000002	72	901	4	2	10	8	0	-2	8	0	0	6.7837035003629405	
i 1	764.2439795918367	0.505	74	199	4	5	7	8	0	-1	8	0	0	2.595700713469904	
i 1	764.2528095238096	3.0300000000000002	72	199	6	9	5	2	0	-2	2	0	0	5.7837035003629405	
i 1	764.4915714285714	0.505	74	199	5	5	13	8	0	-1	8	0	0	2.595700713469904	
i 1	764.4979931972789	0.2525	68	585	1	24	10	1	0	0	1	0	0	4.0	
i 1	764.7544149659864	0.2525	71	199	4	5	5	8	0	-1	8	0	0	2.595700713469904	
i 1	764.9827414965987	1.01	74	199	4	5	15	8	0	-1	8	0	0	2.595700713469904	
i 1	764.9867551020408	0.505	71	585	1	24	8	0	0	0	0	0	0	4.0	
i 1	764.9963877551021	1.01	74	585	5	5	11	8	0	-2	8	0	0	2.595700713469904	
i 1	765.0052176870748	0.2525	69	901	6	1	4	1	0	0	1	0	0	2.088571040475097	
i 1	765.2455850340136	0.2525	69	585	6	1	5	0	0	0	0	0	0	2.088571040475097	
i 1	765.2487959183674	3.7875	74	199	5	5	4	8	0	-1	8	0	0	2.595700713469904	
i 1	765.2552176870748	3.535	71	901	5	5	2	2	0	-2	2	0	0	2.595700713469904	
i 1	765.2600340136055	0.505	69	199	4	1	4	0	0	-1	0	0	0	2.088571040475097	
i 1	765.5188639455782	0.505	72	199	3	1	4	0	0	-1	0	0	0	2.088571040475097	
i 1	765.7391632653062	0.2525	69	199	3	24	5	1	0	-1	1	0	0	3.088571040475097	
i 1	765.9939795918367	0.2525	71	199	4	5	5	8	0	-1	8	0	0	2.595700713469904	
i 1	766.0076258503401	3.0300000000000002	69	199	4	1	2	0	0	-1	0	0	0	2.088571040475097	
i 1	766.0172585034013	0.505	72	585	4	24	16	1	0	-1	1	0	0	3.088571040475097	
i 1	766.2415714285714	0.2525	74	199	4	5	13	8	0	-1	8	0	0	2.595700713469904	
i 1	766.2536122448979	0.2525	74	585	5	5	9	2	0	-2	2	0	0	2.595700713469904	
i 1	766.2544149659864	2.02	75	199	5	4	10	2	0	-2	2	0	0	6.7837035003629405	
i 1	766.2560204081633	1.7675	75	585	4	4	2	2	0	-2	2	0	0	6.7837035003629405	
i 1	766.509231292517	2.2725	69	901	6	1	8	1	0	0	1	0	0	2.088571040475097	
i 1	766.7311360544218	0.2525	74	585	5	5	15	8	0	-2	8	0	0	2.595700713469904	
i 1	766.7552176870748	0.2525	71	199	4	5	3	8	0	-1	8	0	0	2.595700713469904	
i 1	766.9819387755102	0.7575000000000001	74	199	6	5	3	8	0	-2	8	0	0	2.595700713469904	
i 1	766.9891632653062	2.2725	75	199	6	9	2	8	0	-2	8	0	0	5.7837035003629405	
i 1	767.0028095238096	2.2725	75	901	4	2	16	2	0	-2	2	0	0	6.7837035003629405	
i 1	767.235149659864	0.505	72	199	3	1	5	0	0	-1	0	0	0	2.088571040475097	
i 1	767.2367551020408	0.2525	69	199	3	24	9	1	0	-1	1	0	0	3.088571040475097	
i 1	767.2487959183674	0.2525	74	199	4	5	14	8	0	-1	8	0	0	2.595700713469904	
i 1	767.4811360544218	2.2725	72	901	6	1	4	1	0	-1	1	0	0	2.088571040475097	
i 1	767.7487959183674	1.01	74	585	5	5	3	2	0	-2	2	0	0	2.595700713469904	
i 1	767.7536122448979	1.01	71	199	4	5	11	8	0	-1	8	0	0	2.595700713469904	
i 1	767.764850340136	2.02	72	199	4	1	9	1	0	-1	1	0	0	2.088571040475097	
i 1	768.016455782313	3.0300000000000002	75	199	6	3	13	8	0	1	8	0	0	6.7837035003629405	
i 1	768.2311360544218	1.2625	72	585	5	3	5	2	0	-2	2	0	0	6.7837035003629405	
i 1	768.2391632653062	0.505	71	585	1	24	11	1	0	-1	1	0	0	4.0	
i 1	768.2512040816326	4.7975	71	901	5	5	5	2	0	-1	2	0	0	2.595700713469904	
i 1	768.2512040816326	1.2625	74	199	6	5	10	8	0	-2	8	0	0	2.595700713469904	
i 1	768.7303333333333	2.2725	69	585	6	1	6	0	0	0	0	0	0	2.088571040475097	
i 1	768.7520068027211	0.2525	74	199	4	5	7	8	0	-1	8	0	0	2.595700713469904	
i 1	768.9875578231292	0.2525	74	585	5	5	1	8	0	-2	8	0	0	2.595700713469904	
i 1	768.9923741496599	0.2525	74	585	5	5	3	2	0	-2	2	0	0	2.595700713469904	
i 1	769.0196666666667	2.02	72	199	3	1	16	0	0	-1	0	0	0	2.088571040475097	
i 1	769.2568231292518	0.2525	75	199	5	4	16	2	0	-2	2	0	0	6.7837035003629405	
i 1	769.259231292517	0.2525	71	901	5	5	9	2	0	-2	2	0	0	2.595700713469904	
i 1	769.4875578231292	0.2525	75	585	4	4	2	2	0	-2	2	0	0	6.7837035003629405	
i 1	769.4915714285714	1.2625	72	585	4	3	13	2	0	-2	2	0	0	6.7837035003629405	
i 1	769.4939795918367	0.7575000000000001	74	585	5	5	13	8	0	-2	8	0	0	2.595700713469904	
i 1	769.4979931972789	3.2825	74	199	5	5	8	8	0	-2	8	0	0	2.595700713469904	
i 1	769.4987959183674	0.505	75	199	6	9	3	8	0	-2	8	0	0	5.7837035003629405	
i 1	769.5140476190476	27.27	60	901	4	14	2	5	0	0	5	0	0	1.8341829555965272	
i 1	769.7327414965987	0.2525	72	585	4	24	9	1	0	-1	1	0	0	3.088571040475097	
i 1	770.0108367346938	0.2525	71	199	4	5	3	8	0	-1	8	0	0	2.595700713469904	
i 1	770.0124421768708	5.8075	72	901	6	1	12	1	0	-1	1	0	0	2.088571040475097	
i 1	770.014850340136	2.525	75	901	4	2	12	2	0	-2	2	0	0	6.7837035003629405	
i 1	770.2319387755102	0.2525	74	585	5	5	8	2	0	-2	2	0	0	2.595700713469904	
i 1	770.2359523809524	5.555	72	199	4	1	13	1	0	-1	1	0	0	2.088571040475097	
i 1	770.2536122448979	2.2725	75	199	6	9	13	8	0	-2	8	0	0	5.7837035003629405	
i 1	770.4875578231292	0.2525	74	585	5	5	4	8	0	-2	8	0	0	2.595700713469904	
i 1	770.7632448979592	0.505	74	199	4	5	7	8	0	-1	8	0	0	2.595700713469904	
i 1	770.9971904761904	0.7575000000000001	72	199	6	9	13	2	0	-2	2	0	0	5.7837035003629405	
i 1	771.0100340136055	0.2525	72	585	4	24	8	1	0	-1	1	0	0	3.088571040475097	
i 1	771.0116394557823	3.0300000000000002	72	901	4	2	2	8	0	-2	8	0	0	6.7837035003629405	
i 1	771.2439795918367	0.2525	69	199	3	24	16	1	0	-1	1	0	0	3.088571040475097	
i 1	771.2455850340136	0.2525	71	901	5	5	12	2	0	-2	2	0	0	2.595700713469904	
i 1	771.2463877551021	0.2525	74	199	6	5	5	8	0	-1	8	0	0	2.595700713469904	
i 1	771.4899659863945	1.01	72	199	3	1	4	0	0	-1	0	0	0	2.088571040475097	
i 1	771.4923741496599	3.2825	70	199	1	24	2	2	0	-2	2	0	0	4.0	
i 1	771.4939795918367	0.2525	74	585	5	5	16	2	0	-2	2	0	0	2.595700713469904	
i 1	771.4963877551021	0.505	74	199	4	5	3	8	0	-1	8	0	0	2.595700713469904	
i 1	771.5084285714286	1.01	69	585	6	1	2	0	0	0	0	0	0	2.088571040475097	
i 1	771.7423741496599	0.2525	71	585	1	24	7	0	0	0	0	0	0	4.0	
i 1	771.7568231292518	0.2525	75	585	4	4	4	2	0	-2	2	0	0	6.7837035003629405	
i 1	771.9931768707482	0.2525	71	199	4	5	14	8	0	-1	8	0	0	2.595700713469904	
i 1	771.9963877551021	1.7675	72	199	6	9	9	2	0	-2	2	0	0	5.7837035003629405	
i 1	772.2319387755102	1.7675	74	199	4	5	4	8	0	-1	8	0	0	2.595700713469904	
i 1	772.2415714285714	1.7675	74	585	5	5	6	8	0	-2	8	0	0	2.595700713469904	
i 1	772.4939795918367	0.2525	69	901	6	1	11	1	0	0	1	0	0	2.088571040475097	
i 1	772.5036122448979	0.2525	75	199	6	3	1	8	0	1	8	0	0	6.7837035003629405	
i 1	772.7495986394558	0.2525	72	585	4	3	2	2	0	-2	2	0	0	6.7837035003629405	
i 1	772.7632448979592	0.505	69	199	4	1	4	0	0	-1	0	0	0	2.088571040475097	
i 1	773.0100340136055	0.2525	74	585	5	5	10	2	0	-2	2	0	0	2.595700713469904	
i 1	773.0116394557823	0.2525	75	901	4	2	14	2	0	-2	2	0	0	6.7837035003629405	
i 1	773.0188639455782	0.7575000000000001	72	585	4	24	3	1	0	-1	1	0	0	3.088571040475097	
i 1	773.2375578231292	1.5150000000000001	75	199	5	4	9	2	0	-2	2	0	0	6.7837035003629405	
i 1	773.2584285714286	2.02	74	199	6	5	10	8	0	-1	8	0	0	2.595700713469904	
i 1	773.2656530612245	1.2625	75	585	4	4	5	2	0	-2	2	0	0	6.7837035003629405	
i 1	773.2680612244898	2.02	71	901	5	5	10	2	0	-2	2	0	0	2.595700713469904	
i 1	773.5100340136055	0.2525	69	199	4	1	8	0	0	-1	0	0	0	2.088571040475097	
i 1	773.5100340136055	0.2525	68	585	1	24	10	0	0	-1	0	0	0	4.0	
i 1	773.7319387755102	0.505	69	901	6	1	16	1	0	0	1	0	0	2.088571040475097	
i 1	773.7608367346938	1.7675	75	901	4	2	12	2	0	-2	2	0	0	6.7837035003629405	
i 1	773.9803333333333	0.2525	74	585	5	5	4	2	0	-2	2	0	0	2.595700713469904	
i 1	773.9891632653062	1.7675	75	199	6	9	10	8	0	-2	8	0	0	5.7837035003629405	
i 1	773.9915714285714	0.2525	71	199	4	5	9	8	0	-1	8	0	0	2.595700713469904	
i 1	774.2528095238096	0.2525	69	585	6	1	10	0	0	0	0	0	0	2.088571040475097	
i 1	774.259231292517	0.2525	71	901	5	5	1	2	0	-1	2	0	0	2.595700713469904	
i 1	774.4955850340136	0.2525	69	901	6	1	10	1	0	0	1	0	0	2.088571040475097	
i 1	774.4995986394558	2.02	74	585	5	5	16	2	0	-2	2	0	0	2.595700713469904	
i 1	774.7367551020408	1.5150000000000001	71	199	4	5	13	8	0	-1	8	0	0	2.595700713469904	
i 1	774.7672585034013	0.2525	72	199	6	9	9	2	0	-2	2	0	0	5.7837035003629405	
i 1	774.9923741496599	0.2525	69	585	6	1	4	0	0	0	0	0	0	2.088571040475097	
i 1	774.9955850340136	1.5150000000000001	75	199	6	3	8	8	0	1	8	0	0	6.7837035003629405	
i 1	775.0060204081633	1.5150000000000001	72	585	4	3	2	2	0	-2	2	0	0	6.7837035003629405	
i 1	775.2447823129252	0.2525	71	901	5	5	15	2	0	-1	2	0	0	2.595700713469904	
i 1	775.2688639455782	1.5150000000000001	69	199	4	1	6	0	0	-1	0	0	0	2.088571040475097	
i 1	775.4883605442177	0.2525	71	901	5	5	13	2	0	-2	2	0	0	2.595700713469904	
i 1	775.4891632653062	1.5150000000000001	69	901	6	1	10	1	0	0	1	0	0	2.088571040475097	
i 1	775.7303333333333	0.2525	72	585	4	24	5	1	0	-1	1	0	0	3.088571040475097	
i 1	775.7608367346938	3.535	71	901	5	5	5	2	0	-1	2	0	0	2.595700713469904	
i 1	775.9867551020408	3.0300000000000002	72	901	6	1	16	1	0	-1	1	0	0	2.088571040475097	
i 1	775.9899659863945	3.535	74	199	5	5	12	8	0	-2	8	0	0	2.595700713469904	
i 1	775.990768707483	1.2625	75	199	6	9	14	8	0	-2	8	0	0	5.7837035003629405	
i 1	776.0028095238096	1.2625	75	901	4	2	5	2	0	-2	2	0	0	6.7837035003629405	
i 1	776.2311360544218	3.0300000000000002	72	199	6	1	14	1	0	-1	1	0	0	2.088571040475097	
i 1	776.2495986394558	6.8175	60	585	6	7	3	5	0	0	5	0	0	1.084099902903431	
i 1	776.4891632653062	0.2525	75	585	4	4	6	2	0	-2	2	0	0	6.7837035003629405	
i 1	776.5068231292518	0.2525	74	199	5	5	8	8	0	-1	8	0	0	2.595700713469904	
i 1	776.514850340136	4.7975	70	199	1	24	11	2	0	-2	2	0	0	4.0	
i 1	776.7327414965987	0.2525	74	585	5	5	13	8	0	-2	8	0	0	2.595700713469904	
i 1	776.9875578231292	1.5150000000000001	72	199	6	9	12	2	0	-2	2	0	0	5.7837035003629405	
i 1	776.9947823129252	1.5150000000000001	72	901	4	2	14	8	0	-2	8	0	0	6.7837035003629405	
i 1	777.2616394557823	0.2525	69	901	6	1	3	1	0	0	1	0	0	2.088571040475097	
i 1	777.490768707483	1.01	69	585	6	1	10	0	0	0	0	0	0	2.088571040475097	
i 1	777.5116394557823	1.01	72	199	3	1	14	0	0	-1	0	0	0	2.088571040475097	
i 1	777.5132448979592	0.2525	74	199	5	5	10	8	0	-1	8	0	0	2.595700713469904	
i 1	777.9995986394558	1.01	75	901	4	2	16	2	0	-2	2	0	0	6.7837035003629405	
i 1	778.0012040816326	1.01	75	199	6	9	1	8	0	-2	8	0	0	5.7837035003629405	
i 1	778.0100340136055	0.2525	71	585	1	24	10	1	0	0	1	0	0	4.0	
i 1	778.0172585034013	0.2525	71	901	5	5	6	2	0	-2	2	0	0	2.595700713469904	
i 1	778.2375578231292	0.2525	74	199	5	5	8	8	0	-1	8	0	0	2.595700713469904	
i 1	778.7471904761904	1.5150000000000001	74	199	5	5	4	8	0	-1	8	0	0	2.595700713469904	
i 1	778.7624421768708	1.7675	72	199	6	9	9	2	0	-2	2	0	0	5.7837035003629405	
i 1	778.7640476190476	1.5150000000000001	72	901	4	2	12	8	0	-2	8	0	0	6.7837035003629405	
i 1	778.9875578231292	1.01	72	199	3	1	8	0	0	-1	0	0	0	2.088571040475097	
i 1	778.9995986394558	0.2525	75	199	5	4	4	2	0	-2	2	0	0	6.7837035003629405	
i 1	779.0012040816326	1.2625	74	585	5	5	16	8	0	-2	8	0	0	2.595700713469904	
i 1	779.0044149659864	1.01	69	585	6	1	11	0	0	0	0	0	0	2.088571040475097	
i 1	779.4867551020408	0.2525	72	585	4	24	11	1	0	-1	1	0	0	3.088571040475097	
i 1	779.740768707483	0.2525	74	199	5	5	7	8	0	-2	8	0	0	2.595700713469904	
i 1	779.7576258503401	1.2625	75	199	5	4	13	2	0	-2	2	0	0	6.7837035003629405	
i 1	779.7656530612245	1.2625	75	585	4	4	3	2	0	-2	2	0	0	6.7837035003629405	
i 1	779.9883605442177	3.7875	72	901	6	1	9	1	0	-1	1	0	0	2.088571040475097	
i 1	779.9939795918367	3.7875	72	199	6	1	8	1	0	-1	1	0	0	2.088571040475097	
i 1	780.0004013605442	1.5150000000000001	74	199	5	5	10	8	0	-1	8	0	0	2.595700713469904	
i 1	780.264850340136	1.2625	71	901	5	5	13	2	0	-2	2	0	0	2.595700713469904	
i 1	780.4827414965987	0.2525	72	901	4	2	12	8	0	-2	8	0	0	6.7837035003629405	
i 1	780.4923741496599	0.2525	71	901	5	5	6	2	0	-1	2	0	0	2.595700713469904	
i 1	780.5188639455782	0.2525	72	199	3	1	6	0	0	-1	0	0	0	2.088571040475097	
i 1	780.7471904761904	0.505	75	199	6	9	13	8	0	-2	8	0	0	5.7837035003629405	
i 1	780.7608367346938	0.505	75	901	4	2	2	2	0	-2	2	0	0	6.7837035003629405	
i 1	780.7688639455782	2.2725	75	199	6	3	9	8	0	1	8	0	0	6.7837035003629405	
i 1	780.7696666666667	2.2725	72	585	4	3	12	2	0	-2	2	0	0	6.7837035003629405	
i 1	780.985149659864	0.2525	71	585	1	24	10	1	0	-1	1	0	0	4.0	
i 1	781.0068231292518	0.2525	71	901	5	5	11	2	0	-1	2	0	0	2.595700713469904	
i 1	781.2576258503401	0.2525	72	901	4	2	11	8	0	-2	8	0	0	6.7837035003629405	
i 1	781.4827414965987	0.2525	75	199	5	4	11	2	0	-2	2	0	0	6.7837035003629405	
i 1	781.483544217687	1.5150000000000001	71	199	4	5	14	8	0	-1	8	0	0	2.595700713469904	
i 1	781.4923741496599	1.01	70	199	1	24	14	2	0	-2	2	0	0	4.0	
i 1	781.5012040816326	0.2525	71	585	1	24	7	0	0	-1	0	0	0	4.0	
i 1	781.514850340136	0.2525	72	199	3	1	5	0	0	-1	0	0	0	2.088571040475097	
i 1	781.516455782313	0.2525	74	199	5	5	3	8	0	-1	8	0	0	2.595700713469904	
i 1	781.5196666666667	1.5150000000000001	74	585	5	5	13	2	0	-2	2	0	0	2.595700713469904	
i 1	781.759231292517	0.2525	69	585	6	1	6	0	0	0	0	0	0	2.088571040475097	
i 1	781.7688639455782	0.505	74	585	5	5	1	8	0	-2	8	0	0	2.595700713469904	
i 1	781.9803333333333	0.2525	69	199	4	1	12	0	0	-1	0	0	0	2.088571040475097	
i 1	782.235149659864	0.2525	71	901	5	5	11	2	0	-1	2	0	0	2.595700713469904	
i 1	782.2399659863945	0.2525	72	199	6	9	7	2	0	-2	2	0	0	5.7837035003629405	
i 1	782.5060204081633	0.2525	69	585	6	1	15	0	0	0	0	0	0	2.088571040475097	
i 1	782.5132448979592	0.2525	74	199	5	5	14	8	0	-2	8	0	0	2.595700713469904	
i 1	782.7383605442177	0.2525	75	199	6	9	10	8	0	-2	8	0	0	5.7837035003629405	
i 1	782.7584285714286	0.2525	75	901	4	2	7	2	0	-2	2	0	0	6.7837035003629405	
i 1	782.9931768707482	3.535	71	901	5	5	3	2	0	-1	2	0	0	2.595700713469904	
i 1	783.0028095238096	0.7575000000000001	75	199	4	9	11	8	0	-2	8	0	0	5.7837035003629405	
i 1	783.0044149659864	0.7575000000000001	75	901	5	2	2	2	0	-2	2	0	0	6.7837035003629405	
i 1	783.0084285714286	23.4825	60	585	4	7	6	5	0	0	5	0	0	1.084099902903431	
i 1	783.0172585034013	3.535	74	199	5	5	11	8	0	-2	8	0	0	2.595700713469904	
i 1	783.7415714285714	1.01	72	199	6	9	3	2	0	-2	2	0	0	5.7837035003629405	
i 1	783.7487959183674	0.505	69	199	6	1	13	0	0	-1	0	0	0	2.088571040475097	
i 1	783.7568231292518	1.01	72	901	4	2	10	8	0	-2	8	0	0	6.7837035003629405	
i 1	783.7616394557823	0.505	69	901	6	1	8	1	0	0	1	0	0	2.088571040475097	
i 1	784.2391632653062	0.7575000000000001	72	901	6	1	12	1	0	-1	1	0	0	2.088571040475097	
i 1	784.2471904761904	0.7575000000000001	72	199	6	1	8	1	0	-1	1	0	0	2.088571040475097	
i 1	784.735149659864	0.7575000000000001	75	199	4	9	12	8	0	-2	8	0	0	5.7837035003629405	
i 1	784.7632448979592	0.7575000000000001	75	901	5	2	12	2	0	-2	2	0	0	6.7837035003629405	
i 1	784.9859523809524	1.01	69	585	6	1	7	0	0	0	0	0	0	2.088571040475097	
i 1	784.9891632653062	1.01	72	199	3	1	2	0	0	-1	0	0	0	2.088571040475097	
i 1	785.240768707483	0.2525	68	585	1	24	5	1	0	-1	1	0	0	4.0	
i 1	785.4931768707482	0.505	70	199	1	24	15	2	0	-2	2	0	0	4.0	
i 1	785.4971904761904	0.2525	72	901	4	2	5	8	0	-2	8	0	0	6.7837035003629405	
i 1	785.5052176870748	0.2525	72	199	6	9	14	2	0	-2	2	0	0	5.7837035003629405	
i 1	785.7552176870748	0.7575000000000001	75	585	4	4	16	2	0	-2	2	0	0	6.7837035003629405	
i 1	785.7600340136055	0.7575000000000001	75	199	5	4	6	2	0	-2	2	0	0	6.7837035003629405	
i 1	786.0004013605442	1.5150000000000001	72	901	6	1	3	1	0	-1	1	0	0	2.088571040475097	
i 1	786.0196666666667	1.5150000000000001	72	199	6	1	16	1	0	-1	1	0	0	2.088571040475097	
i 1	786.483544217687	1.2625	75	199	4	9	1	8	0	-2	8	0	0	5.7837035003629405	
i 1	786.4867551020408	0.2525	74	199	4	5	15	8	0	-1	8	0	0	2.595700713469904	
i 1	786.5076258503401	0.2525	74	585	5	5	11	8	0	-2	8	0	0	2.595700713469904	
i 1	786.509231292517	1.2625	75	901	5	2	6	2	0	-2	2	0	0	6.7837035003629405	
i 1	786.7319387755102	2.525	71	901	5	5	3	2	0	-2	2	0	0	2.595700713469904	
i 1	786.740768707483	2.525	74	199	5	5	6	8	0	-1	8	0	0	2.595700713469904	
i 1	787.485149659864	1.01	72	199	3	1	13	0	0	-1	0	0	0	2.088571040475097	
i 1	787.4923741496599	1.01	69	585	6	1	1	0	0	0	0	0	0	2.088571040475097	
i 1	787.7311360544218	1.7675	72	585	4	3	8	2	0	-2	2	0	0	6.7837035003629405	
i 1	787.7479931972789	1.7675	75	199	6	3	14	8	0	1	8	0	0	6.7837035003629405	
i 1	788.266455782313	0.2525	70	199	1	24	4	2	0	-2	2	0	0	4.0	
i 1	788.4875578231292	0.2525	71	585	1	24	2	0	0	0	0	0	0	4.0	
i 1	788.5028095238096	2.525	72	199	6	1	1	1	0	-1	1	0	0	2.088571040475097	
i 1	788.5188639455782	2.525	72	901	6	1	9	1	0	-1	1	0	0	2.088571040475097	
i 1	789.2343469387755	0.2525	71	199	5	5	2	8	0	-1	8	0	0	2.595700713469904	
i 1	789.2391632653062	0.2525	74	585	5	5	12	2	0	-2	2	0	0	2.595700713469904	
i 1	789.4803333333333	4.04	74	199	5	5	14	8	0	-2	8	0	0	2.595700713469904	
i 1	789.4819387755102	2.2725	70	199	1	24	3	2	0	-2	2	0	0	4.0	
i 1	789.4971904761904	0.7575000000000001	75	901	5	2	14	2	0	-2	2	0	0	6.7837035003629405	
i 1	789.5004013605442	0.7575000000000001	75	199	4	9	7	8	0	-2	8	0	0	5.7837035003629405	
i 1	789.5100340136055	0.2525	71	901	5	5	10	2	0	-1	2	0	0	2.595700713469904	
i 1	789.7383605442177	3.7875	71	901	6	5	4	2	0	-1	2	0	0	2.595700713469904	
i 1	789.7528095238096	13.635	67	901	5	14	1	5	0	1	5	0	0	1.8341829555965272	
i 1	790.2463877551021	0.2525	72	199	4	9	9	2	0	-2	2	0	0	5.7837035003629405	
i 1	790.2584285714286	0.2525	72	901	5	2	6	8	0	-2	8	0	0	6.7837035003629405	
i 1	790.5100340136055	0.7575000000000001	75	199	4	9	15	8	0	-2	8	0	0	5.7837035003629405	
i 1	790.5156530612245	0.7575000000000001	75	901	5	2	10	2	0	-2	2	0	0	6.7837035003629405	
i 1	790.9915714285714	1.01	69	901	6	1	8	1	0	0	1	0	0	2.088571040475097	
i 1	791.0100340136055	1.01	69	199	6	1	8	0	0	-1	0	0	0	2.088571040475097	
i 1	791.2327414965987	1.2625	72	199	4	9	9	2	0	-2	2	0	0	5.7837035003629405	
i 1	791.2447823129252	1.2625	72	901	5	2	11	8	0	-2	8	0	0	6.7837035003629405	
i 1	792.0004013605442	1.5150000000000001	72	901	6	1	3	1	0	-1	1	0	0	2.088571040475097	
i 1	792.0124421768708	1.5150000000000001	72	199	6	1	7	1	0	-1	1	0	0	2.088571040475097	
i 1	792.4963877551021	0.7575000000000001	75	585	4	4	1	2	0	-2	2	0	0	6.7837035003629405	
i 1	792.4971904761904	1.2625	70	199	1	24	4	2	0	-2	2	0	0	4.0	
i 1	792.5076258503401	0.7575000000000001	75	199	5	4	8	2	0	-2	2	0	0	6.7837035003629405	
i 1	793.2391632653062	1.01	75	901	5	2	15	2	0	-2	2	0	0	6.7837035003629405	
i 1	793.2463877551021	1.01	75	199	4	9	9	8	0	-2	8	0	0	5.7837035003629405	
i 1	793.483544217687	1.01	74	585	5	5	4	8	0	-2	8	0	0	2.595700713469904	
i 1	793.485149659864	1.01	69	585	6	1	14	0	0	0	0	0	0	2.088571040475097	
i 1	793.4947823129252	1.01	72	199	5	1	10	0	0	-1	0	0	0	2.088571040475097	
i 1	793.5132448979592	1.01	74	199	4	5	14	8	0	-1	8	0	0	2.595700713469904	
i 1	794.2656530612245	1.01	75	199	6	3	6	8	0	1	8	0	0	6.7837035003629405	
i 1	794.266455782313	1.01	72	585	4	3	13	2	0	-2	2	0	0	6.7837035003629405	
i 1	794.4955850340136	1.5150000000000001	71	901	5	5	13	2	0	-2	2	0	0	2.595700713469904	
i 1	794.4979931972789	1.5150000000000001	74	199	5	5	10	8	0	-1	8	0	0	2.595700713469904	
i 1	794.5012040816326	1.2625	72	199	6	1	9	1	0	-1	1	0	0	2.088571040475097	
i 1	794.5132448979592	1.2625	72	901	6	1	4	1	0	-1	1	0	0	2.088571040475097	
i 1	795.2319387755102	0.7575000000000001	75	901	5	2	11	2	0	-2	2	0	0	6.7837035003629405	
i 1	795.2447823129252	0.505	70	199	1	24	3	2	0	-2	2	0	0	4.0	
i 1	795.2455850340136	0.7575000000000001	75	199	4	9	9	8	0	-2	8	0	0	5.7837035003629405	
i 1	795.7391632653062	0.505	69	585	6	1	3	0	0	0	0	0	0	2.088571040475097	
i 1	795.7479931972789	0.505	72	199	5	1	5	0	0	-1	0	0	0	2.088571040475097	
i 1	795.7528095238096	0.505	68	585	1	24	14	0	0	-1	0	0	0	4.0	
i 1	795.9803333333333	1.01	74	585	5	5	3	2	0	-2	2	0	0	2.595700713469904	
i 1	795.9867551020408	1.2625	72	199	4	9	12	2	0	-2	2	0	0	5.7837035003629405	
i 1	796.009231292517	1.2625	72	901	5	2	9	8	0	-2	8	0	0	6.7837035003629405	
i 1	796.0124421768708	1.01	71	199	4	5	9	8	0	-1	8	0	0	2.595700713469904	
i 1	796.259231292517	3.2825	72	901	6	1	5	1	0	-1	1	0	0	2.088571040475097	
i 1	796.2672585034013	3.2825	72	199	6	1	16	1	0	-1	1	0	0	2.088571040475097	
i 1	796.4915714285714	9.8475	60	901	5	14	14	5	0	0	5	0	0	1.8341829555965272	
i 1	796.983544217687	3.0300000000000002	71	901	6	5	6	2	0	-1	2	0	0	2.595700713469904	
i 1	796.9987959183674	3.0300000000000002	74	199	5	5	10	8	0	-2	8	0	0	2.595700713469904	
i 1	797.2520068027211	0.7575000000000001	75	199	4	9	9	8	0	-2	8	0	0	5.7837035003629405	
i 1	797.2576258503401	0.7575000000000001	75	901	5	2	1	2	0	-2	2	0	0	6.7837035003629405	
i 1	797.7560204081633	0.2525	70	199	1	24	15	2	0	-2	2	0	0	4.0	
i 1	797.990768707483	1.01	72	199	4	9	1	2	0	-2	2	0	0	5.7837035003629405	
i 1	798.0044149659864	1.01	72	901	5	2	8	8	0	-2	8	0	0	6.7837035003629405	
i 1	798.7367551020408	0.7575000000000001	70	199	1	24	11	2	0	-2	2	0	0	4.0	
i 1	798.985149659864	0.7575000000000001	75	199	5	4	14	2	0	-2	2	0	0	6.7837035003629405	
i 1	798.9891632653062	0.7575000000000001	75	585	4	4	12	2	0	-2	2	0	0	6.7837035003629405	
i 1	799.5108367346938	0.2525	68	585	1	24	12	0	0	-1	0	0	0	4.0	
i 1	799.5132448979592	1.01	69	199	6	1	5	0	0	-1	0	0	0	2.088571040475097	
i 1	799.5180612244898	1.01	69	901	6	1	10	1	0	0	1	0	0	2.088571040475097	
i 1	799.7487959183674	0.2525	75	199	4	9	2	8	0	-2	8	0	0	5.7837035003629405	
i 1	799.7536122448979	0.505	70	199	1	24	1	2	0	-2	2	0	0	4.0	
i 1	799.7600340136055	0.2525	75	901	5	2	6	2	0	-2	2	0	0	6.7837035003629405	
i 1	800.0012040816326	1.2625	74	199	4	5	16	8	0	-1	8	0	0	2.595700713469904	
i 1	800.0020068027211	1.2625	74	585	5	5	14	8	0	-2	8	0	0	2.595700713469904	
i 1	800.0084285714286	2.02	72	585	5	3	12	2	0	-2	2	0	0	6.7837035003629405	
i 1	800.016455782313	2.02	75	199	3	3	12	8	0	1	8	0	0	6.7837035003629405	
i 1	800.2600340136055	0.2525	68	585	1	24	11	1	0	0	1	0	0	4.0	
i 1	800.4955850340136	1.2625	72	901	6	1	3	1	0	-1	1	0	0	2.088571040475097	
i 1	800.4971904761904	0.7575000000000001	70	199	1	24	8	2	0	-2	2	0	0	4.0	
i 1	800.5124421768708	1.2625	72	199	6	1	11	1	0	-1	1	0	0	2.088571040475097	
i 1	801.2311360544218	1.2625	71	901	6	5	12	2	0	-2	2	0	0	2.595700713469904	
i 1	801.2439795918367	1.2625	74	199	5	5	6	8	0	-1	8	0	0	2.595700713469904	
i 1	801.2471904761904	0.2525	71	585	1	24	11	1	0	-1	1	0	0	4.0	
i 1	801.4931768707482	0.2525	70	199	1	24	1	2	0	-2	2	0	0	4.0	
i 1	801.7447823129252	0.505	72	199	5	1	11	0	0	-1	0	0	0	2.088571040475097	
i 1	801.7688639455782	0.505	69	585	6	1	3	0	0	0	0	0	0	2.088571040475097	
i 1	801.9923741496599	0.7575000000000001	75	199	4	9	14	8	0	-2	8	0	0	5.7837035003629405	
i 1	802.0060204081633	0.7575000000000001	75	901	5	2	5	2	0	-2	2	0	0	6.7837035003629405	
i 1	802.2520068027211	0.7575000000000001	72	901	6	1	11	1	0	-1	1	0	0	2.088571040475097	
i 1	802.2608367346938	0.7575000000000001	72	199	6	1	8	1	0	-1	1	0	0	2.088571040475097	
i 1	802.5052176870748	1.5150000000000001	71	199	4	5	10	8	0	-1	8	0	0	2.595700713469904	
i 1	802.5108367346938	1.5150000000000001	74	585	5	5	4	2	0	-2	2	0	0	2.595700713469904	
i 1	802.7544149659864	0.2525	70	199	1	24	8	2	0	-2	2	0	0	4.0	
i 1	802.7632448979592	1.01	72	199	4	9	14	2	0	-2	2	0	0	5.7837035003629405	
i 1	802.764850340136	1.01	72	901	5	2	3	8	0	-2	8	0	0	6.7837035003629405	
i 1	802.9803333333333	1.01	72	199	5	1	11	0	0	-1	0	0	0	2.088571040475097	
i 1	802.9843469387755	0.505	68	585	1	24	1	1	0	0	1	0	0	4.0	
i 1	803.0020068027211	1.01	69	585	6	1	14	0	0	0	0	0	0	2.088571040475097	
i 1	803.2536122448979	3.0300000000000002	67	901	4	14	10	5	0	1	5	0	0	1.8341829555965272	
i 1	803.5084285714286	0.7575000000000001	70	199	1	24	2	2	0	-2	2	0	0	4.0	
i 1	803.7367551020408	0.7575000000000001	75	199	4	9	1	8	0	-2	8	0	0	5.7837035003629405	
i 1	803.7463877551021	0.7575000000000001	75	901	5	2	16	2	0	-2	2	0	0	6.7837035003629405	
i 1	803.7584285714286	0.2525	71	585	1	24	16	1	0	0	1	0	0	4.0	
i 1	803.9819387755102	2.2725	74	199	5	5	7	8	0	-2	8	0	0	2.595700713469904	
i 1	803.9843469387755	2.2725	72	901	6	1	12	1	0	-1	1	0	0	2.088571040475097	
i 1	804.0172585034013	2.2725	72	199	6	1	9	1	0	-1	1	0	0	2.088571040475097	
i 1	804.0196666666667	2.2725	71	901	6	5	1	2	0	-1	2	0	0	2.595700713469904	
i 1	804.5044149659864	0.2525	72	901	5	2	4	8	0	-2	8	0	0	6.7837035003629405	
i 1	804.5052176870748	0.2525	72	199	4	9	13	2	0	-2	2	0	0	5.7837035003629405	
i 1	804.7431768707482	0.2525	70	199	1	24	4	2	0	-2	2	0	0	4.0	
i 1	804.7447823129252	0.7575000000000001	75	199	3	4	11	2	0	-2	2	0	0	6.7837035003629405	
i 1	804.7672585034013	0.7575000000000001	75	585	4	4	8	2	0	-2	2	0	0	6.7837035003629405	
i 1	805.4819387755102	0.7575000000000001	75	199	4	9	10	8	0	-2	8	0	0	5.7837035003629405	
i 1	805.4923741496599	0.7575000000000001	75	901	5	2	11	2	0	-2	2	0	0	6.7837035003629405	
i 1	806.2423741496599	0.7575000000000001	69	697	5	3	14	1	0	0	1	0	0	6.7837035003629405	
i 1	806.2504013605442	1.2625	75	1083	6	1	8	8	0	1	8	0	0	2.088571040475097	
i 1	806.2512040816326	1.01	77	697	4	5	11	16	0	2	16	0	0	2.595700713469904	
i 1	806.2608367346938	3.7875	66	1083	4	14	8	9	0	0	9	0	0	1.8341829555965272	
i 1	806.2608367346938	3.7875	61	697	4	7	11	9	0	0	9	0	0	1.084099902903431	
i 1	806.2616394557823	2.2725	70	199	1	24	11	2	0	-2	2	0	0	4.0	
i 1	806.2632448979592	1.01	77	697	6	5	16	17	0	1	17	0	0	2.595700713469904	
i 1	806.2640476190476	3.7875	61	1083	5	14	10	9	0	1	9	0	0	1.8341829555965272	
i 1	806.2672585034013	0.7575000000000001	72	697	3	4	6	1	0	0	1	0	0	6.7837035003629405	
i 1	806.2696666666667	1.2625	72	697	5	1	9	2	0	1	2	0	0	2.088571040475097	
i 1	806.983544217687	1.01	72	199	4	9	7	2	0	-2	2	0	0	5.7837035003629405	
i 1	806.9987959183674	1.01	72	1083	5	2	6	0	0	0	0	0	0	6.7837035003629405	
i 1	807.2471904761904	1.7675	74	697	4	5	9	17	0	2	17	0	0	2.595700713469904	
i 1	807.264850340136	1.7675	74	1083	6	5	12	17	0	1	17	0	0	2.595700713469904	
i 1	807.483544217687	0.505	69	199	6	1	4	0	0	-1	0	0	0	2.088571040475097	
i 1	807.5076258503401	0.505	75	1083	6	1	9	8	0	1	8	0	0	2.088571040475097	
i 1	807.9819387755102	0.7575000000000001	69	1083	5	2	1	0	0	-1	0	0	0	6.7837035003629405	
i 1	807.9971904761904	0.7575000000000001	75	697	4	24	13	2	0	-2	2	0	0	3.088571040475097	
i 1	808.0052176870748	0.7575000000000001	72	697	6	1	5	2	0	1	2	0	0	2.088571040475097	
i 1	808.0100340136055	0.7575000000000001	72	697	3	3	14	0	0	-1	0	0	0	6.7837035003629405	
i 1	808.7319387755102	0.2525	72	199	4	9	9	2	0	-2	2	0	0	5.7837035003629405	
i 1	808.7375578231292	1.01	69	199	6	1	7	0	0	-1	0	0	0	2.088571040475097	
i 1	808.7399659863945	0.2525	72	1083	5	2	11	0	0	0	0	0	0	6.7837035003629405	
i 1	808.7672585034013	1.01	75	1083	6	1	5	8	0	1	8	0	0	2.088571040475097	
i 1	808.9811360544218	0.7575000000000001	69	1083	5	2	15	0	0	-1	0	0	0	6.7837035003629405	
i 1	808.9883605442177	1.01	77	697	6	5	3	17	0	1	17	0	0	2.595700713469904	
i 1	808.9955850340136	1.5150000000000001	70	199	1	24	1	2	0	-2	2	0	0	4.0	
i 1	809.0060204081633	0.2525	68	697	1	24	4	0	0	-1	0	0	0	4.0	
i 1	809.0068231292518	1.01	77	697	4	5	14	16	0	2	16	0	0	2.595700713469904	
i 1	809.0084285714286	0.7575000000000001	72	697	3	3	6	0	0	-1	0	0	0	6.7837035003629405	
i 1	809.7391632653062	0.2525	72	697	6	1	14	2	0	1	2	0	0	2.088571040475097	
i 1	809.7471904761904	0.2525	75	199	4	9	4	8	0	-2	8	0	0	5.7837035003629405	
i 1	809.7495986394558	0.2525	75	697	4	24	15	2	0	-2	2	0	0	3.088571040475097	
i 1	809.7568231292518	0.2525	69	697	4	4	14	1	0	-1	1	0	0	6.7837035003629405	
i 1	809.9803333333333	2.7775	74	199	5	5	13	8	0	-1	8	0	0	2.021576994371229	
i 1	809.9867551020408	1.2625	72	697	6	1	15	2	0	1	2	0	0	2.1425181232208543	
i 1	809.9875578231292	20.4525	61	1083	4	14	6	9	0	1	9	0	0	1.5255790233655324	
i 1	809.9891632653062	1.01	69	697	4	4	15	1	0	-1	1	0	0	7.242100706752225	
i 1	809.9939795918367	1.2625	75	697	4	24	12	2	0	-2	2	0	0	3.1425181232208543	
i 1	809.9979931972789	13.635	61	697	5	7	6	9	0	0	9	0	0	0.7754959706724363	
i 1	810.0020068027211	1.01	75	199	5	9	7	8	0	-2	8	0	0	6.242100706752225	
i 1	810.0108367346938	2.7775	74	1083	6	5	7	17	0	2	17	0	0	2.021576994371229	
i 1	810.0172585034013	13.635	66	1083	4	14	6	9	0	0	9	0	0	1.5255790233655324	
i 1	811.0068231292518	0.7575000000000001	72	1083	6	2	14	0	0	0	0	0	0	7.242100706752225	
i 1	811.0108367346938	0.7575000000000001	72	199	4	9	8	2	0	-2	2	0	0	6.242100706752225	
i 1	811.2415714285714	2.7775	75	1083	6	1	7	8	0	1	8	0	0	2.1425181232208543	
i 1	811.2696666666667	2.7775	69	199	6	1	9	0	0	-1	0	0	0	2.1425181232208543	
i 1	811.7359523809524	1.7675	69	697	5	3	4	1	0	0	1	0	0	7.242100706752225	
i 1	811.7391632653062	0.505	70	199	1	24	10	2	0	-2	2	0	0	4.0	
i 1	811.7487959183674	1.7675	72	697	3	4	5	1	0	0	1	0	0	7.242100706752225	
i 1	811.9971904761904	0.2525	68	697	1	24	9	0	0	-1	0	0	0	4.0	
i 1	812.740768707483	1.01	70	199	1	24	16	2	0	-2	2	0	0	4.0	
i 1	812.7431768707482	1.5150000000000001	77	697	4	5	16	16	0	2	16	0	0	2.021576994371229	
i 1	812.7455850340136	0.2525	68	697	1	24	14	0	0	-1	0	0	0	4.0	
i 1	812.7632448979592	1.5150000000000001	77	697	6	5	14	17	0	1	17	0	0	2.021576994371229	
i 1	813.4947823129252	0.2525	72	199	4	9	14	2	0	-2	2	0	0	6.242100706752225	
i 1	813.5036122448979	0.2525	68	697	1	24	10	0	0	-1	0	0	0	4.0	
i 1	813.5084285714286	0.2525	72	1083	6	2	7	0	0	0	0	0	0	7.242100706752225	
i 1	813.7367551020408	0.7575000000000001	72	697	3	3	10	0	0	-1	0	0	0	7.242100706752225	
i 1	813.7624421768708	0.7575000000000001	69	1083	5	2	12	0	0	-1	0	0	0	7.242100706752225	
i 1	813.9827414965987	0.2525	68	697	1	24	2	0	0	-1	0	0	0	4.0	
i 1	813.990768707483	2.7775	70	199	1	24	7	2	0	-2	2	0	0	4.0	
i 1	813.9939795918367	0.7575000000000001	75	1083	6	1	1	8	0	1	8	0	0	2.1425181232208543	
i 1	813.9963877551021	0.7575000000000001	72	697	5	1	1	2	0	1	2	0	0	2.1425181232208543	
i 1	814.2303333333333	1.2625	74	697	4	5	11	17	0	2	17	0	0	2.021576994371229	
i 1	814.2343469387755	1.2625	74	1083	6	5	10	17	0	1	17	0	0	2.021576994371229	
i 1	814.5140476190476	1.2625	72	1083	6	2	16	0	0	0	0	0	0	7.242100706752225	
i 1	814.5140476190476	1.2625	72	199	4	9	6	2	0	-2	2	0	0	6.242100706752225	
i 1	814.7487959183674	1.01	75	1083	6	1	3	8	0	1	8	0	0	2.1425181232208543	
i 1	814.7640476190476	1.01	69	199	6	1	15	0	0	-1	0	0	0	2.1425181232208543	
i 1	815.4843469387755	1.2625	77	697	6	5	10	17	0	1	17	0	0	2.021576994371229	
i 1	815.4947823129252	1.2625	77	697	4	5	1	16	0	2	16	0	0	2.021576994371229	
i 1	815.7359523809524	0.7575000000000001	72	697	3	3	6	0	0	-1	0	0	0	7.242100706752225	
i 1	815.7552176870748	1.5150000000000001	72	697	6	1	1	2	0	1	2	0	0	2.1425181232208543	
i 1	815.7600340136055	0.7575000000000001	69	1083	5	2	10	0	0	-1	0	0	0	7.242100706752225	
i 1	815.7608367346938	1.5150000000000001	75	697	4	24	5	2	0	-2	2	0	0	3.1425181232208543	
i 1	816.5068231292518	0.2525	68	697	1	24	1	0	0	-1	0	0	0	4.0	
i 1	816.5124421768708	1.01	75	199	5	9	11	8	0	-2	8	0	0	6.242100706752225	
i 1	816.5140476190476	1.01	69	697	4	4	16	1	0	-1	1	0	0	7.242100706752225	
i 1	816.7431768707482	3.7875	74	199	5	5	12	8	0	-1	8	0	0	2.021576994371229	
i 1	816.7656530612245	3.7875	74	1083	6	5	6	17	0	2	17	0	0	2.021576994371229	
i 1	817.2584285714286	1.01	69	199	6	1	16	0	0	-1	0	0	0	2.1425181232208543	
i 1	817.2616394557823	1.01	75	1083	5	1	15	8	0	1	8	0	0	2.1425181232208543	
i 1	817.4899659863945	0.7575000000000001	72	1083	6	2	5	0	0	0	0	0	0	7.242100706752225	
i 1	817.490768707483	0.7575000000000001	72	199	5	9	7	2	0	-2	2	0	0	6.242100706752225	
i 1	817.4995986394558	0.2525	70	199	1	24	15	2	0	-2	2	0	0	4.0	
i 1	818.2423741496599	1.01	72	697	3	4	12	1	0	0	1	0	0	7.242100706752225	
i 1	818.2528095238096	1.2625	75	697	4	24	16	2	0	-2	2	0	0	3.1425181232208543	
i 1	818.2600340136055	1.2625	72	697	6	1	10	2	0	1	2	0	0	2.1425181232208543	
i 1	818.2608367346938	1.01	69	697	5	3	14	1	0	0	1	0	0	7.242100706752225	
i 1	818.7568231292518	0.2525	68	697	1	24	6	0	0	-1	0	0	0	4.0	
i 1	818.7576258503401	1.2625	70	199	1	24	9	2	0	-2	2	0	0	4.0	
i 1	819.2479931972789	1.2625	72	1083	6	2	10	0	0	0	0	0	0	7.242100706752225	
i 1	819.2688639455782	1.2625	72	199	5	9	10	2	0	-2	2	0	0	6.242100706752225	
i 1	819.4819387755102	2.2725	75	1083	5	1	10	8	0	1	8	0	0	2.1425181232208543	
i 1	819.4867551020408	2.2725	69	199	6	1	13	0	0	-1	0	0	0	2.1425181232208543	
i 1	819.7584285714286	0.2525	68	697	1	24	2	0	0	-1	0	0	0	4.0	
i 1	820.2632448979592	1.01	70	199	1	24	3	2	0	-2	2	0	0	4.0	
i 1	820.2672585034013	0.2525	68	697	1	24	10	0	0	-1	0	0	0	4.0	
i 1	820.4859523809524	0.7575000000000001	72	697	3	3	7	0	0	-1	0	0	0	7.242100706752225	
i 1	820.4883605442177	0.2525	77	697	4	5	8	16	0	2	16	0	0	2.021576994371229	
i 1	820.4923741496599	0.7575000000000001	69	1083	6	2	16	0	0	-1	0	0	0	7.242100706752225	
i 1	820.5100340136055	0.2525	77	697	6	5	15	17	0	1	17	0	0	2.021576994371229	
i 1	820.7487959183674	2.2725	74	697	4	5	14	17	0	2	17	0	0	2.021576994371229	
i 1	820.7584285714286	2.2725	74	1083	6	5	15	17	0	1	17	0	0	2.021576994371229	
i 1	821.009231292517	0.2525	68	697	1	24	3	0	0	-1	0	0	0	4.0	
i 1	821.240768707483	1.01	72	1083	6	2	6	0	0	0	0	0	0	7.242100706752225	
i 1	821.2632448979592	1.01	72	199	5	9	8	2	0	-2	2	0	0	6.242100706752225	
i 1	821.7391632653062	1.5150000000000001	72	697	5	1	1	2	0	1	2	0	0	2.1425181232208543	
i 1	821.7688639455782	1.5150000000000001	75	1083	6	1	15	8	0	1	8	0	0	2.1425181232208543	
i 1	822.2520068027211	0.505	68	697	1	24	8	0	0	-1	0	0	0	4.0	
i 1	822.2528095238096	0.7575000000000001	69	1083	6	2	8	0	0	-1	0	0	0	7.242100706752225	
i 1	822.2560204081633	1.2625	70	199	1	24	14	2	0	-2	2	0	0	4.0	
i 1	822.2632448979592	0.7575000000000001	72	697	3	3	16	0	0	-1	0	0	0	7.242100706752225	
i 1	822.9867551020408	0.2525	77	697	6	5	10	17	0	1	17	0	0	2.021576994371229	
i 1	822.9891632653062	0.2525	69	697	4	4	1	1	0	-1	1	0	0	7.242100706752225	
i 1	823.0132448979592	0.2525	77	697	4	5	8	16	0	2	16	0	0	2.021576994371229	
i 1	823.0172585034013	0.2525	75	199	5	9	3	8	0	-2	8	0	0	6.242100706752225	
i 1	823.2359523809524	0.2525	72	1083	6	2	15	0	0	0	0	0	0	7.242100706752225	
i 1	823.2439795918367	0.7575000000000001	72	199	5	9	6	2	0	-2	2	0	0	6.242100706752225	
i 1	823.2471904761904	1.01	69	199	6	1	9	0	0	-1	0	0	0	2.1425181232208543	
i 1	823.2471904761904	0.2525	74	199	5	5	12	8	0	-1	8	0	0	2.021576994371229	
i 1	823.2479931972789	4.04	74	1083	6	5	6	17	0	2	17	0	0	2.021576994371229	
i 1	823.2504013605442	0.2525	75	1083	5	1	13	8	0	1	8	0	0	2.1425181232208543	
i 1	823.4811360544218	0.7575000000000001	75	1083	4	1	9	8	0	1	8	0	0	2.1425181232208543	
i 1	823.4859523809524	0.505	72	1083	6	2	14	0	0	0	0	0	0	7.242100706752225	
i 1	823.509231292517	27.017500000000002	66	1083	5	14	16	9	0	0	9	0	0	1.5255790233655324	
i 1	823.5124421768708	20.4525	61	697	4	7	6	9	0	0	9	0	0	0.7754959706724363	
i 1	823.5140476190476	3.7875	74	199	7	5	6	8	0	-1	8	0	0	2.021576994371229	
i 1	824.0052176870748	1.5150000000000001	70	199	1	24	6	2	0	-2	2	0	0	4.0	
i 1	824.0116394557823	0.2525	68	697	1	24	13	0	0	-1	0	0	0	4.0	
i 1	824.0140476190476	2.02	69	697	5	3	7	1	0	0	1	0	0	7.242100706752225	
i 1	824.0188639455782	2.02	72	697	3	4	10	1	0	0	1	0	0	7.242100706752225	
i 1	824.2479931972789	1.2625	72	697	6	1	2	2	0	1	2	0	0	2.1425181232208543	
i 1	824.264850340136	1.2625	75	697	4	24	16	2	0	-2	2	0	0	3.1425181232208543	
i 1	825.5116394557823	0.505	69	199	6	1	15	0	0	-1	0	0	0	2.1425181232208543	
i 1	825.514850340136	0.505	75	1083	4	1	5	8	0	1	8	0	0	2.1425181232208543	
i 1	825.9803333333333	1.01	72	199	5	9	1	2	0	-2	2	0	0	6.242100706752225	
i 1	825.9947823129252	0.7575000000000001	75	697	4	24	14	2	0	-2	2	0	0	3.1425181232208543	
i 1	826.0060204081633	1.01	72	1083	6	2	16	0	0	0	0	0	0	7.242100706752225	
i 1	826.0124421768708	0.7575000000000001	72	697	6	1	8	2	0	1	2	0	0	2.1425181232208543	
i 1	826.7391632653062	3.535	75	1083	4	1	7	8	0	1	8	0	0	2.1425181232208543	
i 1	826.7552176870748	3.535	69	199	6	1	13	0	0	-1	0	0	0	2.1425181232208543	
i 1	827.0020068027211	0.7575000000000001	69	1083	6	2	16	0	0	-1	0	0	0	7.242100706752225	
i 1	827.0172585034013	0.7575000000000001	72	697	4	3	8	0	0	-1	0	0	0	7.242100706752225	
i 1	827.2327414965987	1.01	77	697	4	5	11	16	0	2	16	0	0	2.021576994371229	
i 1	827.2479931972789	1.01	77	697	6	5	1	17	0	1	17	0	0	2.021576994371229	
i 1	827.7319387755102	0.2525	72	199	5	9	9	2	0	-2	2	0	0	6.242100706752225	
i 1	827.7375578231292	0.2525	68	697	1	24	15	0	0	-1	0	0	0	4.0	
i 1	827.7487959183674	0.2525	72	1083	6	2	4	0	0	0	0	0	0	7.242100706752225	
i 1	827.7672585034013	0.505	70	199	1	24	16	2	0	-2	2	0	0	4.0	
i 1	827.985149659864	0.7575000000000001	69	1083	6	2	5	0	0	-1	0	0	0	7.242100706752225	
i 1	828.0020068027211	0.7575000000000001	72	697	4	3	8	0	0	-1	0	0	0	7.242100706752225	
i 1	828.2423741496599	1.7675	74	697	4	5	3	17	0	2	17	0	0	2.021576994371229	
i 1	828.2680612244898	1.7675	74	1083	6	5	7	17	0	1	17	0	0	2.021576994371229	
i 1	828.7327414965987	1.2625	75	199	5	9	2	8	0	-2	8	0	0	6.242100706752225	
i 1	828.7415714285714	1.2625	69	697	4	4	7	1	0	-1	1	0	0	7.242100706752225	
i 1	829.9811360544218	0.7575000000000001	72	199	5	9	5	2	0	-2	2	0	0	6.242100706752225	
i 1	829.9843469387755	0.7575000000000001	72	1083	6	2	1	0	0	0	0	0	0	7.242100706752225	
i 1	829.9947823129252	0.505	70	199	1	24	13	2	0	-2	2	0	0	4.0	
i 1	829.9971904761904	1.01	77	697	6	5	9	17	0	1	17	0	0	2.021576994371229	
i 1	830.0068231292518	1.01	77	697	4	5	13	16	0	2	16	0	0	2.021576994371229	
i 1	830.233544217687	1.2625	75	1083	4	1	14	8	0	1	8	0	0	2.1425181232208543	
i 1	830.2479931972789	1.2625	72	697	5	1	12	2	0	1	2	0	0	2.1425181232208543	
i 1	830.2479931972789	20.2	61	1083	5	14	13	9	0	1	9	0	0	1.5255790233655324	
i 1	830.7463877551021	1.7675	69	697	5	3	6	1	0	0	1	0	0	7.242100706752225	
i 1	830.7600340136055	1.7675	72	697	4	4	2	1	0	0	1	0	0	7.242100706752225	
i 1	830.9931768707482	2.7775	74	1083	6	5	1	17	0	2	17	0	0	2.021576994371229	
i 1	830.9963877551021	2.7775	74	199	7	5	8	8	0	-1	8	0	0	2.021576994371229	
i 1	831.4843469387755	0.505	69	199	6	1	7	0	0	-1	0	0	0	2.1425181232208543	
i 1	831.509231292517	0.505	75	1083	6	1	1	8	0	1	8	0	0	2.1425181232208543	
i 1	831.9915714285714	0.7575000000000001	75	697	4	24	16	2	0	-2	2	0	0	3.1425181232208543	
i 1	831.9955850340136	0.7575000000000001	72	697	5	1	1	2	0	1	2	0	0	2.1425181232208543	
i 1	832.2696666666667	1.01	70	199	1	24	7	2	0	-2	2	0	0	4.0	
i 1	832.5036122448979	0.2525	72	199	5	9	9	2	0	-2	2	0	0	6.242100706752225	
i 1	832.5172585034013	0.2525	72	1083	6	2	7	0	0	0	0	0	0	7.242100706752225	
i 1	832.7391632653062	1.01	75	1083	6	1	2	8	0	1	8	0	0	2.1425181232208543	
i 1	832.7584285714286	0.7575000000000001	72	697	4	3	2	0	0	-1	0	0	0	7.242100706752225	
i 1	832.7608367346938	1.01	69	199	6	1	14	0	0	-1	0	0	0	2.1425181232208543	
i 1	832.7608367346938	0.7575000000000001	69	1083	6	2	3	0	0	-1	0	0	0	7.242100706752225	
i 1	833.4939795918367	1.2625	72	1083	6	2	10	0	0	0	0	0	0	7.242100706752225	
i 1	833.4987959183674	1.2625	72	199	5	9	10	2	0	-2	2	0	0	6.242100706752225	
i 1	833.7319387755102	1.5150000000000001	77	697	6	5	11	17	0	1	17	0	0	2.021576994371229	
i 1	833.735149659864	1.5150000000000001	72	697	5	1	11	2	0	1	2	0	0	2.1425181232208543	
i 1	833.7479931972789	1.5150000000000001	77	697	4	5	8	16	0	2	16	0	0	2.021576994371229	
i 1	833.7656530612245	1.5150000000000001	75	697	4	24	7	2	0	-2	2	0	0	3.1425181232208543	
i 1	834.2624421768708	1.2625	70	199	1	24	11	2	0	-2	2	0	0	4.0	
i 1	834.7375578231292	0.7575000000000001	72	697	4	3	5	0	0	-1	0	0	0	7.242100706752225	
i 1	834.7640476190476	0.7575000000000001	69	1083	6	2	13	0	0	-1	0	0	0	7.242100706752225	
i 1	835.2311360544218	2.7775	75	1083	6	1	11	8	0	1	8	0	0	2.1425181232208543	
i 1	835.2504013605442	1.2625	74	697	6	5	9	17	0	2	17	0	0	2.021576994371229	
i 1	835.2632448979592	1.2625	74	1083	6	5	16	17	0	1	17	0	0	2.021576994371229	
i 1	835.266455782313	2.7775	69	199	6	1	8	0	0	-1	0	0	0	2.1425181232208543	
i 1	835.4803333333333	1.01	69	697	4	4	15	1	0	-1	1	0	0	7.242100706752225	
i 1	835.5172585034013	1.01	75	199	5	9	12	8	0	-2	8	0	0	6.242100706752225	
i 1	836.4819387755102	1.2625	77	697	6	5	16	17	0	1	17	0	0	2.021576994371229	
i 1	836.4899659863945	0.7575000000000001	72	199	5	9	9	2	0	-2	2	0	0	6.242100706752225	
i 1	836.4923741496599	1.01	70	199	1	24	10	2	0	-2	2	0	0	4.0	
i 1	836.4979931972789	0.505	77	697	4	5	2	16	0	2	16	0	0	2.021576994371229	
i 1	836.5100340136055	0.7575000000000001	72	1083	6	2	4	0	0	0	0	0	0	7.242100706752225	
i 1	837.0140476190476	0.7575000000000001	77	697	6	5	7	16	0	2	16	0	0	2.021576994371229	
i 1	837.2560204081633	1.01	72	697	4	4	8	1	0	0	1	0	0	7.242100706752225	
i 1	837.266455782313	1.01	69	697	5	3	15	1	0	0	1	0	0	7.242100706752225	
i 1	837.7520068027211	3.7875	74	1083	6	5	5	17	0	2	17	0	0	2.021576994371229	
i 1	837.7672585034013	3.7875	74	199	7	5	3	8	0	-1	8	0	0	2.021576994371229	
i 1	838.0052176870748	0.7575000000000001	72	697	5	1	14	2	0	1	2	0	0	2.1425181232208543	
i 1	838.0156530612245	0.7575000000000001	75	1083	6	1	16	8	0	1	8	0	0	2.1425181232208543	
i 1	838.2544149659864	1.2625	72	1083	6	2	15	0	0	0	0	0	0	7.242100706752225	
i 1	838.2576258503401	1.2625	72	199	5	9	16	2	0	-2	2	0	0	6.242100706752225	
i 1	838.5044149659864	1.5150000000000001	70	199	1	24	8	2	0	-2	2	0	0	4.0	
i 1	838.7359523809524	1.01	75	1083	6	1	3	8	0	1	8	0	0	2.1425181232208543	
i 1	838.7367551020408	1.01	69	199	6	1	1	0	0	-1	0	0	0	2.1425181232208543	
i 1	839.4987959183674	0.7575000000000001	69	1083	6	2	11	0	0	-1	0	0	0	7.242100706752225	
i 1	839.5044149659864	0.7575000000000001	72	697	4	3	6	0	0	-1	0	0	0	7.242100706752225	
i 1	839.7423741496599	1.5150000000000001	72	697	4	1	7	2	0	1	2	0	0	2.1425181232208543	
i 1	839.7680612244898	1.5150000000000001	75	697	4	24	11	2	0	-2	2	0	0	3.1425181232208543	
i 1	840.2423741496599	1.01	72	1083	6	2	11	0	0	0	0	0	0	7.242100706752225	
i 1	840.2512040816326	1.01	72	199	5	9	13	2	0	-2	2	0	0	6.242100706752225	
i 1	840.7471904761904	0.505	70	199	1	24	11	2	0	-2	2	0	0	4.0	
i 1	841.2311360544218	1.01	69	199	6	1	2	0	0	-1	0	0	0	2.1425181232208543	
i 1	841.2375578231292	1.01	75	1083	6	1	7	8	0	1	8	0	0	2.1425181232208543	
i 1	841.2544149659864	0.7575000000000001	72	697	4	3	16	0	0	-1	0	0	0	7.242100706752225	
i 1	841.2584285714286	0.7575000000000001	69	1083	6	2	15	0	0	-1	0	0	0	7.242100706752225	
i 1	841.4811360544218	0.2525	77	697	6	5	9	16	0	2	16	0	0	2.021576994371229	
i 1	841.483544217687	0.2525	77	697	6	5	9	17	0	1	17	0	0	2.021576994371229	
i 1	841.5044149659864	0.505	70	199	1	24	8	2	0	-2	2	0	0	4.0	
i 1	841.7576258503401	2.2725	74	697	6	5	13	17	0	2	17	0	0	2.021576994371229	
i 1	841.7616394557823	2.02	74	1083	6	5	5	17	0	1	17	0	0	2.021576994371229	
i 1	841.985149659864	0.2525	69	697	4	4	13	1	0	-1	1	0	0	7.242100706752225	
i 1	842.016455782313	0.2525	75	199	6	9	8	8	0	-2	8	0	0	6.242100706752225	
i 1	842.235149659864	1.2625	72	697	4	1	1	2	0	1	2	0	0	2.1425181232208543	
i 1	842.2391632653062	1.2625	75	697	4	24	12	2	0	-2	2	0	0	3.1425181232208543	
i 1	842.2447823129252	0.2525	70	199	1	24	3	2	0	-2	2	0	0	4.0	
i 1	842.2487959183674	0.2525	68	697	1	24	2	0	0	-1	0	0	0	4.0	
i 1	842.2568231292518	0.7575000000000001	72	1083	6	2	4	0	0	0	0	0	0	7.242100706752225	
i 1	842.2672585034013	0.7575000000000001	72	199	5	9	10	2	0	-2	2	0	0	6.242100706752225	
i 1	843.0124421768708	2.02	69	697	5	3	1	1	0	0	1	0	0	7.242100706752225	
i 1	843.0156530612245	2.02	72	697	4	4	9	1	0	0	1	0	0	7.242100706752225	
i 1	843.490768707483	0.2525	69	199	6	1	4	0	0	-1	0	0	0	2.1425181232208543	
i 1	843.5060204081633	2.2725	75	1083	6	1	3	8	0	1	8	0	0	2.1425181232208543	
i 1	843.5100340136055	1.01	70	199	1	24	4	2	0	-2	2	0	0	4.0	
i 1	843.7343469387755	40.905	61	697	6	7	4	9	0	0	9	0	0	0.7754959706724363	
i 1	843.7391632653062	2.02	69	199	7	1	4	0	0	-1	0	0	0	2.1425181232208543	
i 1	843.7399659863945	0.2525	74	1083	6	5	13	17	0	1	17	0	0	2.021576994371229	
i 1	844.0116394557823	0.2525	77	697	6	5	4	16	0	2	16	0	0	2.021576994371229	
i 1	844.0180612244898	0.2525	77	697	6	5	1	17	0	1	17	0	0	2.021576994371229	
i 1	844.2520068027211	4.2925	74	199	7	5	5	8	0	-1	8	0	0	2.021576994371229	
i 1	844.2696666666667	4.2925	74	1083	6	5	7	17	0	2	17	0	0	2.021576994371229	
i 1	844.7463877551021	0.505	70	199	1	24	10	2	0	-2	2	0	0	4.0	
i 1	845.0028095238096	1.01	72	199	6	9	8	2	0	-2	2	0	0	6.242100706752225	
i 1	845.0084285714286	0.2525	68	697	1	24	5	0	0	-1	0	0	0	4.0	
i 1	845.016455782313	1.01	72	1083	6	2	9	0	0	0	0	0	0	7.242100706752225	
i 1	845.7367551020408	1.5150000000000001	72	697	5	1	12	2	0	1	2	0	0	2.1425181232208543	
i 1	845.7616394557823	1.5150000000000001	75	1083	6	1	3	8	0	1	8	0	0	2.1425181232208543	
i 1	845.9939795918367	0.7575000000000001	69	1083	6	2	1	0	0	-1	0	0	0	7.242100706752225	
i 1	846.0180612244898	0.7575000000000001	72	697	4	3	14	0	0	-1	0	0	0	7.242100706752225	
i 1	846.233544217687	1.2625	70	199	1	24	10	2	0	-2	2	0	0	4.0	
i 1	846.7311360544218	0.2525	72	199	6	9	10	2	0	-2	2	0	0	6.242100706752225	
i 1	846.7479931972789	0.2525	72	1083	6	2	13	0	0	0	0	0	0	7.242100706752225	
i 1	846.9899659863945	0.7575000000000001	69	1083	6	2	14	0	0	-1	0	0	0	7.242100706752225	
i 1	846.9915714285714	0.7575000000000001	72	697	4	3	9	0	0	-1	0	0	0	7.242100706752225	
i 1	847.2383605442177	1.01	75	1083	6	1	3	8	0	1	8	0	0	2.1425181232208543	
i 1	847.2520068027211	1.01	69	199	7	1	7	0	0	-1	0	0	0	2.1425181232208543	
i 1	847.2600340136055	0.2525	68	697	1	24	3	0	0	-1	0	0	0	4.0	
i 1	847.7479931972789	1.2625	75	199	6	9	3	8	0	-2	8	0	0	6.242100706752225	
i 1	847.7608367346938	1.2625	69	697	4	4	9	1	0	-1	1	0	0	7.242100706752225	
i 1	847.990768707483	1.5150000000000001	70	199	1	24	2	2	0	-2	2	0	0	4.0	
i 1	847.9923741496599	0.2525	74	199	7	5	9	8	0	-2	8	0	0	2.021576994371229	
i 1	848.2359523809524	1.2625	75	697	4	24	11	2	0	-2	2	0	0	3.1425181232208543	
i 1	848.2552176870748	1.2625	72	697	6	1	8	2	0	1	2	0	0	2.1425181232208543	
i 1	848.2576258503401	0.2525	72	697	5	1	3	2	0	1	2	0	0	2.1425181232208543	
i 1	848.2640476190476	1.01	77	697	6	5	3	17	0	1	17	0	0	2.021576994371229	
i 1	848.2680612244898	1.01	77	697	6	5	16	16	0	2	16	0	0	2.021576994371229	
i 1	848.4995986394558	0.2525	72	697	4	4	8	1	0	0	1	0	0	7.242100706752225	
i 1	848.7319387755102	0.2525	72	697	4	24	3	2	0	1	2	0	0	3.1425181232208543	
i 1	848.9987959183674	0.7575000000000001	72	1083	6	2	1	0	0	0	0	0	0	7.242100706752225	
i 1	849.0068231292518	0.7575000000000001	72	199	6	9	10	2	0	-2	2	0	0	6.242100706752225	
i 1	849.2487959183674	1.01	74	697	6	5	7	17	0	2	17	0	0	2.021576994371229	
i 1	849.2584285714286	1.01	74	1083	6	5	6	17	0	1	17	0	0	2.021576994371229	
i 1	849.4819387755102	0.7575000000000001	69	199	7	1	15	0	0	-1	0	0	0	2.1425181232208543	
i 1	849.4843469387755	0.2525	77	697	6	5	16	17	0	1	17	0	0	2.021576994371229	
i 1	849.4867551020408	0.2525	69	697	4	4	1	1	0	-1	1	0	0	7.242100706752225	
i 1	849.5172585034013	0.7575000000000001	75	1083	6	1	2	8	0	1	8	0	0	2.1425181232208543	
i 1	849.7544149659864	0.505	69	697	5	3	11	1	0	0	1	0	0	7.242100706752225	
i 1	849.7584285714286	0.505	72	697	4	4	1	1	0	0	1	0	0	7.242100706752225	
i 1	849.9811360544218	0.505	72	697	6	1	1	2	0	1	2	0	0	2.1425181232208543	
i 1	849.9843469387755	0.2525	74	1083	6	5	10	17	0	2	17	0	0	2.021576994371229	
i 1	849.9979931972789	0.2525	74	199	7	5	5	8	0	-2	8	0	0	2.021576994371229	
i 1	850.0044149659864	0.2525	75	697	4	24	6	2	0	-2	2	0	0	3.1425181232208543	
i 1	850.0108367346938	0.2525	72	199	5	1	6	1	0	-1	1	0	0	2.1425181232208543	
i 1	850.2311360544218	9.8475	66	1195	5	14	3	9	0	0	9	0	0	1.5255790233655324	
i 1	850.2343469387755	0.7575000000000001	72	1195	6	2	6	0	0	-1	0	0	0	7.242100706752225	
i 1	850.235149659864	9.8475	66	1195	5	14	3	6	0	0	6	0	0	1.5255790233655324	
i 1	850.2383605442177	0.2525	72	381	4	24	14	2	0	-2	2	0	0	3.1425181232208543	
i 1	850.2512040816326	3.535	74	1195	6	5	12	16	0	2	16	0	0	2.021576994371229	
i 1	850.2520068027211	0.2525	72	1195	5	1	6	2	0	1	2	0	0	2.1425181232208543	
i 1	850.2560204081633	1.5150000000000001	74	1195	6	5	8	16	0	2	16	0	0	2.021576994371229	
i 1	850.2576258503401	0.2525	72	1195	5	9	5	1	0	0	1	0	0	6.242100706752225	
i 1	850.2600340136055	2.525	75	1195	6	1	1	2	0	-2	2	0	0	2.1425181232208543	
i 1	850.5068231292518	0.505	72	1195	5	9	9	1	0	0	1	0	0	6.242100706752225	
i 1	850.5124421768708	1.2625	72	1195	4	1	4	2	0	1	2	0	0	2.1425181232208543	
i 1	850.9995986394558	0.505	69	1195	6	2	12	0	0	-1	0	0	0	7.242100706752225	
i 1	851.0100340136055	0.2525	72	697	4	24	11	2	0	1	2	0	0	3.1425181232208543	
i 1	851.0140476190476	0.505	69	1195	5	9	12	0	0	-1	0	0	0	6.242100706752225	
i 1	851.0156530612245	0.2525	77	697	6	5	5	17	0	1	17	0	0	2.021576994371229	
i 1	851.2319387755102	0.7575000000000001	72	1195	6	2	3	0	0	-1	0	0	0	7.242100706752225	
i 1	851.2495986394558	0.2525	68	1195	1	24	11	0	0	0	0	0	0	4.0	
i 1	851.2640476190476	0.2525	68	381	2	24	12	0	0	-1	0	0	0	4.0	
i 1	851.2672585034013	0.505	72	1195	5	9	7	1	0	0	1	0	0	6.242100706752225	
i 1	851.4923741496599	0.2525	68	697	3	24	1	1	0	0	1	0	0	4.0	
i 1	851.7311360544218	2.02	77	381	6	5	7	17	0	1	17	0	0	2.021576994371229	
i 1	851.735149659864	1.01	75	381	4	1	16	2	0	-2	2	0	0	2.1425181232208543	
i 1	851.7608367346938	0.2525	72	381	5	9	3	0	0	-1	0	0	0	6.242100706752225	
i 1	851.9859523809524	1.5150000000000001	69	1195	6	2	16	0	0	-1	0	0	0	7.242100706752225	
i 1	851.9923741496599	1.5150000000000001	72	381	5	9	8	1	0	0	1	0	0	6.242100706752225	
i 1	851.9947823129252	0.2525	77	697	6	5	13	17	0	1	17	0	0	2.021576994371229	
i 1	851.9955850340136	0.2525	72	1195	6	1	9	2	0	1	2	0	0	2.1425181232208543	
i 1	852.5076258503401	0.2525	77	1195	6	5	6	16	0	1	16	0	0	2.021576994371229	
i 1	852.7455850340136	0.2525	72	697	4	24	16	2	0	1	2	0	0	3.1425181232208543	
i 1	852.7512040816326	1.01	72	1195	6	1	9	2	0	1	2	0	0	2.1425181232208543	
i 1	852.7576258503401	0.2525	77	1195	6	5	7	17	0	2	17	0	0	2.021576994371229	
i 1	852.764850340136	1.01	75	381	5	1	3	2	0	1	2	0	0	2.1425181232208543	
i 1	852.9899659863945	1.01	69	1195	4	4	4	0	0	0	0	0	0	7.242100706752225	
i 1	852.9995986394558	0.2525	68	1195	2	24	12	1	0	-1	1	0	0	4.0	
i 1	853.0068231292518	1.01	69	697	4	4	13	1	0	-1	1	0	0	7.242100706752225	
i 1	853.0116394557823	0.505	71	381	1	24	1	1	0	-1	1	0	0	4.0	
i 1	853.4827414965987	1.5150000000000001	72	697	4	24	13	2	0	1	2	0	0	3.1425181232208543	
i 1	853.4987959183674	1.5150000000000001	72	1195	4	24	6	2	0	-2	2	0	0	3.1425181232208543	
i 1	853.5068231292518	0.505	74	1195	6	5	5	17	0	2	17	0	0	2.021576994371229	
i 1	853.5076258503401	0.505	77	697	6	5	12	17	0	1	17	0	0	2.021576994371229	
i 1	854.0052176870748	2.7775	77	1195	6	5	13	16	0	1	16	0	0	2.021576994371229	
i 1	854.0084285714286	1.01	69	1195	6	2	6	0	0	-1	0	0	0	7.242100706752225	
i 1	854.0124421768708	1.2625	72	381	5	9	16	1	0	0	1	0	0	6.242100706752225	
i 1	854.0156530612245	2.7775	77	381	6	5	11	16	0	2	16	0	0	2.021576994371229	
i 1	854.2367551020408	0.2525	69	697	5	3	12	1	0	0	1	0	0	7.242100706752225	
i 1	854.240768707483	0.2525	68	1195	2	24	3	1	0	-1	1	0	0	4.0	
i 1	854.2552176870748	0.2525	72	1195	6	1	9	2	0	-2	2	0	0	2.1425181232208543	
i 1	854.2616394557823	1.01	71	381	1	24	13	1	0	-1	1	0	0	4.0	
i 1	854.4803333333333	0.2525	75	381	5	1	5	2	0	1	2	0	0	2.1425181232208543	
i 1	854.5060204081633	0.2525	68	697	3	24	14	0	0	0	0	0	0	4.0	
i 1	854.7656530612245	0.505	71	1195	2	24	4	0	0	0	0	0	0	4.0	
i 1	854.9827414965987	1.01	69	1195	5	3	1	0	0	-1	0	0	0	7.242100706752225	
i 1	854.9883605442177	0.7575000000000001	72	697	6	1	16	2	0	1	2	0	0	2.1425181232208543	
i 1	854.9891632653062	1.5150000000000001	75	1195	6	1	8	2	0	-2	2	0	0	2.1425181232208543	
i 1	854.9915714285714	1.01	69	697	5	3	10	1	0	0	1	0	0	7.242100706752225	
i 1	855.0108367346938	0.7575000000000001	72	1195	6	1	13	2	0	-2	2	0	0	2.1425181232208543	
i 1	855.2576258503401	1.2625	75	381	4	1	2	2	0	-2	2	0	0	2.1425181232208543	
i 1	855.2624421768708	0.2525	69	697	4	4	2	1	0	-1	1	0	0	7.242100706752225	
i 1	855.266455782313	0.2525	77	697	6	5	15	17	0	1	17	0	0	2.021576994371229	
i 1	855.5140476190476	0.2525	77	381	6	5	9	17	0	1	17	0	0	2.021576994371229	
i 1	855.7487959183674	0.2525	72	1195	4	24	9	2	0	-2	2	0	0	3.1425181232208543	
i 1	855.7520068027211	0.2525	69	1195	6	2	7	0	0	-1	0	0	0	7.242100706752225	
i 1	855.9827414965987	1.01	72	381	5	9	13	0	0	-1	0	0	0	6.242100706752225	
i 1	855.9947823129252	0.2525	72	1195	6	1	9	2	0	1	2	0	0	2.1425181232208543	
i 1	855.9979931972789	0.2525	74	1195	6	5	3	16	0	2	16	0	0	2.021576994371229	
i 1	856.0196666666667	1.01	72	1195	6	2	14	0	0	-1	0	0	0	7.242100706752225	
i 1	856.2463877551021	1.01	72	697	6	1	11	2	0	1	2	0	0	2.1425181232208543	
i 1	856.2680612244898	1.01	72	1195	6	1	8	2	0	-2	2	0	0	2.1425181232208543	
i 1	856.485149659864	3.535	77	381	6	5	2	17	0	1	17	0	0	2.021576994371229	
i 1	856.5004013605442	0.2525	69	1195	5	3	10	0	0	-1	0	0	0	7.242100706752225	
i 1	856.5036122448979	0.7575000000000001	74	1195	6	5	1	16	0	2	16	0	0	2.021576994371229	
i 1	856.5108367346938	0.2525	77	697	6	5	9	17	0	1	17	0	0	2.021576994371229	
i 1	856.514850340136	0.2525	75	381	5	1	16	2	0	1	2	0	0	2.1425181232208543	
i 1	856.5156530612245	0.505	74	1195	6	5	6	17	0	2	17	0	0	2.021576994371229	
i 1	856.7479931972789	1.2625	69	1195	6	2	12	0	0	-1	0	0	0	7.242100706752225	
i 1	856.7528095238096	0.2525	72	697	4	24	8	2	0	1	2	0	0	3.1425181232208543	
i 1	856.7568231292518	0.505	72	381	5	9	10	1	0	0	1	0	0	6.242100706752225	
i 1	856.7584285714286	0.505	71	381	1	24	5	1	0	-1	1	0	0	4.0	
i 1	856.7608367346938	0.2525	71	1195	2	24	3	0	0	0	0	0	0	4.0	
i 1	857.0020068027211	0.505	77	1195	6	5	3	16	0	1	16	0	0	2.021576994371229	
i 1	857.0068231292518	0.2525	68	697	3	24	7	0	0	-1	0	0	0	4.0	
i 1	857.2311360544218	2.7775	75	1195	6	1	8	2	0	-2	2	0	0	2.1425181232208543	
i 1	857.2343469387755	0.505	68	1195	2	24	1	1	0	0	1	0	0	4.0	
i 1	857.2383605442177	2.7775	75	381	6	1	3	2	0	-2	2	0	0	2.1425181232208543	
i 1	857.2447823129252	0.505	71	381	3	24	6	1	0	-1	1	0	0	4.0	
i 1	857.2487959183674	0.2525	72	1195	4	1	9	2	0	-2	2	0	0	2.1425181232208543	
i 1	857.2544149659864	2.7775	74	1195	6	5	15	16	0	2	16	0	0	2.021576994371229	
i 1	857.2560204081633	1.01	72	381	5	9	15	1	0	0	1	0	0	6.242100706752225	
i 1	857.5140476190476	0.2525	72	1195	4	24	3	2	0	-2	2	0	0	3.1425181232208543	
i 1	857.7311360544218	0.2525	72	1195	6	1	4	2	0	1	2	0	0	2.1425181232208543	
i 1	857.7431768707482	0.2525	77	1195	6	5	14	17	0	2	17	0	0	2.021576994371229	
i 1	857.7471904761904	0.2525	68	697	3	24	2	0	0	-1	0	0	0	4.0	
i 1	858.0076258503401	1.01	72	1195	6	2	13	0	0	-1	0	0	0	7.242100706752225	
i 1	858.0100340136055	1.01	72	381	5	9	2	0	0	-1	0	0	0	6.242100706752225	
i 1	858.240768707483	0.2525	75	381	4	1	16	2	0	1	2	0	0	2.1425181232208543	
i 1	858.2520068027211	0.2525	69	1195	4	4	4	0	0	0	0	0	0	7.242100706752225	
i 1	858.266455782313	0.2525	77	1195	6	5	7	17	0	2	17	0	0	2.021576994371229	
i 1	858.485149659864	1.01	71	381	3	24	1	1	0	-1	1	0	0	4.0	
i 1	858.4867551020408	0.2525	77	381	6	5	6	16	0	2	16	0	0	2.021576994371229	
i 1	858.4867551020408	1.01	71	1195	2	24	10	1	0	-1	1	0	0	4.0	
i 1	858.5060204081633	0.2525	72	1195	6	1	10	2	0	1	2	0	0	2.1425181232208543	
i 1	858.7367551020408	1.2625	72	381	5	9	9	1	0	0	1	0	0	6.242100706752225	
i 1	858.7423741496599	1.2625	69	1195	6	2	16	0	0	-1	0	0	0	7.242100706752225	
i 1	858.9891632653062	0.505	69	1195	4	4	9	0	0	0	0	0	0	7.242100706752225	
i 1	858.9963877551021	0.2525	77	697	6	5	14	17	0	1	17	0	0	2.021576994371229	
i 1	859.5060204081633	0.2525	72	1195	6	1	13	2	0	1	2	0	0	2.1425181232208543	
i 1	859.5132448979592	0.2525	77	697	6	5	8	17	0	1	17	0	0	2.021576994371229	
i 1	859.7512040816326	0.2525	69	1195	4	4	3	0	0	0	0	0	0	7.242100706752225	
i 1	859.7616394557823	0.505	69	697	4	4	13	1	0	-1	1	0	0	7.242100706752225	
i 1	859.7696666666667	1.2625	69	697	5	3	12	1	0	0	1	0	0	7.242100706752225	
i 1	859.9843469387755	0.2525	75	1083	6	1	1	8	0	-2	8	0	0	2.1425181232208543	
i 1	859.9859523809524	0.7575000000000001	72	697	4	24	14	2	0	1	2	0	0	3.1425181232208543	
i 1	859.9899659863945	1.5150000000000001	74	1083	6	5	15	16	0	2	16	0	0	2.021576994371229	
i 1	859.9939795918367	1.5150000000000001	77	199	7	5	15	17	0	1	17	0	0	2.021576994371229	
i 1	860.0060204081633	0.2525	77	1083	6	5	11	17	0	2	17	0	0	2.021576994371229	
i 1	860.0068231292518	0.2525	74	199	7	5	5	17	0	2	17	0	0	2.021576994371229	
i 1	860.0108367346938	1.2625	69	199	5	4	15	1	0	0	1	0	0	7.242100706752225	
i 1	860.0108367346938	4.04	66	1083	5	14	1	6	0	0	6	0	0	1.5255790233655324	
i 1	860.0116394557823	0.7575000000000001	75	199	7	1	13	2	0	-2	2	0	0	2.1425181232208543	
i 1	860.0180612244898	1.2625	71	199	2	24	13	0	0	-1	0	0	0	4.0	
i 1	860.0196666666667	10.8575	61	1083	5	14	12	6	0	1	6	0	0	1.5255790233655324	
i 1	860.2303333333333	1.01	72	697	6	1	16	2	0	1	2	0	0	2.1425181232208543	
i 1	860.2463877551021	0.2525	77	199	7	5	13	16	0	2	16	0	0	2.021576994371229	
i 1	860.2672585034013	1.01	72	199	5	24	16	2	0	-2	2	0	0	3.1425181232208543	
i 1	860.2696666666667	0.2525	69	199	6	9	9	0	0	-1	0	0	0	6.242100706752225	
i 1	860.5132448979592	0.2525	69	1083	6	2	4	1	0	-1	1	0	0	7.242100706752225	
i 1	860.5156530612245	0.2525	77	1083	6	5	4	17	0	2	17	0	0	2.021576994371229	
i 1	860.7359523809524	0.2525	75	1083	6	1	3	8	0	-2	8	0	0	2.1425181232208543	
i 1	860.9827414965987	1.7675	77	697	6	5	1	17	0	1	17	0	0	2.021576994371229	
i 1	860.985149659864	1.7675	77	199	7	5	16	16	0	2	16	0	0	2.021576994371229	
i 1	861.0108367346938	1.2625	72	1083	6	2	11	1	0	0	1	0	0	7.242100706752225	
i 1	861.0196666666667	1.2625	69	199	6	9	9	1	0	0	1	0	0	6.242100706752225	
i 1	861.2479931972789	0.2525	69	697	4	4	3	1	0	-1	1	0	0	7.242100706752225	
i 1	861.2487959183674	1.2625	75	1083	6	1	5	8	0	-2	8	0	0	2.1425181232208543	
i 1	861.2640476190476	1.2625	71	697	3	24	14	1	0	-1	1	0	0	4.0	
i 1	861.2656530612245	1.5150000000000001	75	199	4	1	12	2	0	-2	2	0	0	2.1425181232208543	
i 1	861.2656530612245	2.02	71	199	3	24	3	0	0	0	0	0	0	4.0	
i 1	861.4827414965987	0.2525	72	199	4	1	2	2	0	-2	2	0	0	2.1425181232208543	
i 1	861.5004013605442	0.2525	69	199	6	3	10	1	0	-1	1	0	0	7.242100706752225	
i 1	861.766455782313	0.2525	74	199	7	5	4	17	0	2	17	0	0	2.021576994371229	
i 1	862.0004013605442	1.01	69	1083	6	2	6	1	0	-1	1	0	0	7.242100706752225	
i 1	862.0044149659864	0.2525	74	1083	6	5	12	16	0	2	16	0	0	2.021576994371229	
i 1	862.0060204081633	1.01	69	199	6	3	6	1	0	-1	1	0	0	7.242100706752225	
i 1	862.0180612244898	0.2525	75	199	7	1	15	2	0	-2	2	0	0	2.1425181232208543	
i 1	862.2415714285714	1.7675	72	697	6	1	13	2	0	1	2	0	0	2.1425181232208543	
i 1	862.2479931972789	1.7675	72	199	5	24	14	2	0	-2	2	0	0	3.1425181232208543	
i 1	862.2600340136055	0.505	69	697	5	3	15	1	0	0	1	0	0	7.242100706752225	
i 1	862.4883605442177	0.505	68	199	2	24	3	1	0	0	1	0	0	4.0	
i 1	862.5052176870748	4.04	77	1083	6	5	6	17	0	2	17	0	0	2.021576994371229	
i 1	862.5068231292518	4.04	77	199	7	5	6	16	0	1	16	0	0	2.021576994371229	
i 1	862.740768707483	1.5150000000000001	72	1083	6	2	9	1	0	0	1	0	0	7.242100706752225	
i 1	862.7415714285714	1.5150000000000001	69	199	6	9	8	1	0	0	1	0	0	6.242100706752225	
i 1	863.0068231292518	3.7875	75	1083	6	1	15	8	0	-2	8	0	0	2.1425181232208543	
i 1	863.0068231292518	0.2525	74	199	7	5	4	17	0	2	17	0	0	2.021576994371229	
i 1	863.0100340136055	0.2525	68	697	3	24	1	1	0	0	1	0	0	4.0	
i 1	863.2431768707482	0.2525	77	697	6	5	16	17	0	1	17	0	0	2.021576994371229	
i 1	863.2487959183674	0.2525	69	199	5	4	12	1	0	0	1	0	0	7.242100706752225	
i 1	863.2616394557823	0.7575000000000001	68	199	2	24	15	0	0	-1	0	0	0	4.0	
i 1	863.5156530612245	0.2525	69	697	4	4	10	1	0	-1	1	0	0	7.242100706752225	
i 1	863.5172585034013	0.505	75	199	4	1	12	2	0	-2	2	0	0	2.1425181232208543	
i 1	863.7327414965987	0.2525	77	199	7	5	14	17	0	1	17	0	0	2.021576994371229	
i 1	863.7423741496599	0.2525	69	199	6	3	7	1	0	-1	1	0	0	7.242100706752225	
i 1	863.7512040816326	2.02	69	1083	6	2	2	1	0	-1	1	0	0	7.242100706752225	
i 1	863.9859523809524	1.7675	69	199	5	3	2	1	0	-1	1	0	0	7.242100706752225	
i 1	863.990768707483	0.2525	71	697	3	24	7	0	0	-1	0	0	0	4.0	
i 1	863.9971904761904	2.7775	75	199	7	1	9	2	0	-2	2	0	0	2.1425181232208543	
i 1	864.0028095238096	6.8175	66	1083	4	14	8	6	0	0	6	0	0	1.5255790233655324	
i 1	864.009231292517	0.2525	72	697	4	24	12	2	0	1	2	0	0	3.1425181232208543	
i 1	864.0140476190476	0.505	71	199	3	24	13	0	0	0	0	0	0	4.0	
i 1	864.2327414965987	0.2525	69	199	5	4	4	1	0	0	1	0	0	7.242100706752225	
i 1	864.2447823129252	0.505	77	697	6	5	16	17	0	1	17	0	0	2.021576994371229	
i 1	864.2552176870748	0.2525	72	199	4	24	3	2	0	-2	2	0	0	3.1425181232208543	
i 1	864.266455782313	1.01	71	199	2	24	11	0	0	-1	0	0	0	4.0	
i 1	864.4923741496599	0.2525	69	697	5	3	15	1	0	0	1	0	0	7.242100706752225	
i 1	864.4947823129252	0.2525	75	199	7	1	11	2	0	-2	2	0	0	2.1425181232208543	
i 1	864.7439795918367	0.505	69	199	6	9	14	0	0	-1	0	0	0	6.242100706752225	
i 1	864.7455850340136	0.505	69	697	4	4	5	1	0	-1	1	0	0	7.242100706752225	
i 1	864.7688639455782	0.505	72	199	4	24	8	2	0	-2	2	0	0	3.1425181232208543	
i 1	864.9891632653062	0.2525	77	199	7	5	2	16	0	2	16	0	0	2.021576994371229	
i 1	865.0132448979592	1.5150000000000001	71	199	3	24	16	0	0	0	0	0	0	4.0	
i 1	865.2520068027211	0.2525	69	199	6	9	8	1	0	0	1	0	0	6.242100706752225	
i 1	865.2544149659864	0.2525	68	697	3	24	1	0	0	-1	0	0	0	4.0	
i 1	865.2632448979592	0.505	74	1083	6	5	9	16	0	2	16	0	0	2.021576994371229	
i 1	865.485149659864	2.525	69	199	5	4	10	1	0	0	1	0	0	7.242100706752225	
i 1	865.4987959183674	0.2525	68	199	2	24	5	0	0	0	0	0	0	4.0	
i 1	865.5028095238096	0.2525	72	199	3	1	2	2	0	-2	2	0	0	2.1425181232208543	
i 1	865.509231292517	2.525	69	697	5	3	1	1	0	0	1	0	0	7.242100706752225	
i 1	865.733544217687	1.01	77	697	6	5	10	17	0	1	17	0	0	2.021576994371229	
i 1	865.7552176870748	0.505	68	697	3	24	6	1	0	0	1	0	0	4.0	
i 1	865.7624421768708	0.2525	72	697	6	1	10	2	0	1	2	0	0	2.1425181232208543	
i 1	865.9875578231292	0.2525	75	199	7	1	15	2	0	-2	2	0	0	2.1425181232208543	
i 1	865.9931768707482	0.7575000000000001	77	199	7	5	1	16	0	2	16	0	0	2.021576994371229	
i 1	866.0004013605442	0.2525	69	1083	6	2	16	1	0	-1	1	0	0	7.242100706752225	
i 1	866.2303333333333	1.01	72	1083	6	1	10	8	0	-2	8	0	0	2.1425181232208543	
i 1	866.2303333333333	2.7775	77	199	7	5	2	17	0	1	17	0	0	2.021576994371229	
i 1	866.2431768707482	2.525	74	1083	6	5	5	16	0	2	16	0	0	2.021576994371229	
i 1	866.2560204081633	1.2625	72	199	3	1	14	2	0	-2	2	0	0	2.1425181232208543	
i 1	866.2608367346938	1.2625	71	199	2	24	9	1	0	0	1	0	0	4.0	
i 1	866.4963877551021	0.2525	69	199	5	3	9	1	0	-1	1	0	0	7.242100706752225	
i 1	866.7375578231292	0.2525	69	199	6	9	12	0	0	-1	0	0	0	6.242100706752225	
i 1	866.7536122448979	0.2525	77	1083	6	5	11	17	0	2	17	0	0	2.021576994371229	
i 1	866.764850340136	0.2525	72	199	4	24	9	2	0	-2	2	0	0	3.1425181232208543	
i 1	866.9827414965987	1.5150000000000001	75	199	7	1	1	2	0	-2	2	0	0	2.1425181232208543	
i 1	867.0180612244898	1.5150000000000001	72	697	4	24	2	2	0	1	2	0	0	3.1425181232208543	
i 1	867.0196666666667	0.2525	69	199	5	3	1	1	0	-1	1	0	0	7.242100706752225	
i 1	867.2536122448979	0.2525	77	697	6	5	6	17	0	1	17	0	0	2.021576994371229	
i 1	867.266455782313	1.5150000000000001	71	199	3	24	4	0	0	0	0	0	0	4.0	
i 1	867.4867551020408	1.5150000000000001	69	199	6	9	2	1	0	0	1	0	0	6.242100706752225	
i 1	867.4899659863945	1.5150000000000001	72	1083	6	2	9	1	0	0	1	0	0	7.242100706752225	
i 1	867.4899659863945	0.2525	77	1083	6	5	14	17	0	2	17	0	0	2.021576994371229	
i 1	867.509231292517	0.2525	68	697	3	24	3	0	0	0	0	0	0	4.0	
i 1	867.759231292517	0.2525	72	1083	6	1	4	8	0	-2	8	0	0	2.1425181232208543	
i 1	867.7680612244898	0.505	68	199	2	24	14	1	0	-1	1	0	0	4.0	
i 1	867.983544217687	2.02	72	199	4	24	14	2	0	-2	2	0	0	3.1425181232208543	
i 1	867.9923741496599	2.02	72	697	6	1	1	2	0	1	2	0	0	2.1425181232208543	
i 1	868.0068231292518	0.2525	69	199	6	9	5	0	0	-1	0	0	0	6.242100706752225	
i 1	868.2528095238096	0.2525	69	697	5	3	5	1	0	0	1	0	0	7.242100706752225	
i 1	868.2624421768708	0.2525	71	697	3	24	13	1	0	0	1	0	0	4.0	
i 1	868.4843469387755	2.2725	69	1083	6	2	5	1	0	-1	1	0	0	7.242100706752225	
i 1	868.4883605442177	2.2725	69	199	5	3	15	1	0	-1	1	0	0	7.242100706752225	
i 1	868.5060204081633	0.2525	72	199	3	1	1	2	0	-2	2	0	0	2.1425181232208543	
i 1	868.5180612244898	0.505	71	199	2	24	14	0	0	0	0	0	0	4.0	
i 1	868.7495986394558	0.2525	75	199	7	1	8	2	0	-2	2	0	0	2.1425181232208543	
i 1	868.7544149659864	0.505	77	697	6	5	8	17	0	1	17	0	0	2.021576994371229	
i 1	868.7552176870748	0.2525	77	199	7	5	2	16	0	2	16	0	0	2.021576994371229	
i 1	868.9803333333333	0.2525	68	697	3	24	2	0	0	-1	0	0	0	4.0	
i 1	868.9803333333333	0.505	71	199	3	24	4	0	0	0	0	0	0	4.0	
i 1	869.0020068027211	1.7675	77	199	7	5	15	16	0	1	16	0	0	2.021576994371229	
i 1	869.0036122448979	4.2925	77	1083	6	5	15	17	0	2	17	0	0	2.021576994371229	
i 1	869.2504013605442	1.01	72	1083	6	2	11	1	0	0	1	0	0	7.242100706752225	
i 1	869.2632448979592	0.2525	77	199	7	5	6	17	0	1	17	0	0	2.021576994371229	
i 1	869.2640476190476	0.2525	75	199	7	1	4	2	0	-2	2	0	0	2.1425181232208543	
i 1	869.2672585034013	1.5150000000000001	71	199	2	24	9	0	0	-1	0	0	0	4.0	
i 1	869.2688639455782	0.7575000000000001	69	199	6	9	9	1	0	0	1	0	0	6.242100706752225	
i 1	869.4939795918367	0.2525	74	199	7	5	11	17	0	2	17	0	0	2.021576994371229	
i 1	869.7520068027211	1.2625	75	1083	6	1	11	8	0	-2	8	0	0	2.1425181232208543	
i 1	869.7672585034013	1.2625	75	199	7	1	3	2	0	-2	2	0	0	2.1425181232208543	
i 1	869.9819387755102	0.2525	77	199	7	5	7	16	0	2	16	0	0	2.021576994371229	
i 1	870.0116394557823	0.2525	72	199	3	1	3	2	0	-2	2	0	0	2.1425181232208543	
i 1	870.2319387755102	1.7675	69	199	6	9	3	0	0	-1	0	0	0	6.242100706752225	
i 1	870.233544217687	0.2525	77	199	7	5	14	17	0	1	17	0	0	2.021576994371229	
i 1	870.2383605442177	0.2525	75	199	7	1	5	2	0	-2	2	0	0	2.1425181232208543	
i 1	870.2383605442177	1.7675	69	697	4	4	3	1	0	-1	1	0	0	7.242100706752225	
i 1	870.2624421768708	0.7575000000000001	71	199	3	24	8	0	0	0	0	0	0	4.0	
i 1	870.4803333333333	1.7675	72	697	6	1	16	2	0	1	2	0	0	2.1425181232208543	
i 1	870.5188639455782	0.2525	72	199	4	24	9	2	0	-2	2	0	0	3.1425181232208543	
i 1	870.7375578231292	0.7575000000000001	71	199	2	24	12	0	0	0	0	0	0	4.0	
i 1	870.7504013605442	2.525	77	199	7	5	16	16	0	1	16	0	0	2.021576994371229	
i 1	870.7520068027211	1.5150000000000001	72	199	3	24	8	2	0	-2	2	0	0	3.1425181232208543	
i 1	870.7560204081633	6.8175	61	1083	4	14	5	6	0	1	6	0	0	1.5255790233655324	
i 1	870.7576258503401	0.2525	69	199	5	4	9	1	0	0	1	0	0	7.242100706752225	
i 1	870.7624421768708	20.4525	66	1083	5	14	2	6	0	0	6	0	0	1.5255790233655324	
i 1	870.9883605442177	0.2525	69	1083	6	2	5	1	0	-1	1	0	0	7.242100706752225	
i 1	871.0036122448979	0.2525	71	697	3	24	5	1	0	0	1	0	0	4.0	
i 1	871.0196666666667	0.2525	75	199	7	1	3	2	0	-2	2	0	0	2.1425181232208543	
i 1	871.2303333333333	0.2525	69	199	6	9	12	1	0	0	1	0	0	6.242100706752225	
i 1	871.2319387755102	1.2625	68	199	2	24	1	1	0	0	1	0	0	4.0	
i 1	871.240768707483	0.2525	77	697	6	5	9	17	0	1	17	0	0	2.021576994371229	
i 1	871.2640476190476	0.2525	72	199	7	1	16	2	0	-2	2	0	0	2.1425181232208543	
i 1	871.4915714285714	0.505	77	697	6	5	9	17	0	1	17	0	0	2.021576994371229	
i 1	871.5012040816326	1.2625	69	199	5	3	10	1	0	-1	1	0	0	7.242100706752225	
i 1	871.5052176870748	0.2525	75	199	7	1	9	2	0	-2	2	0	0	2.1425181232208543	
i 1	871.5188639455782	1.2625	69	1083	6	2	2	1	0	-1	1	0	0	7.242100706752225	
i 1	871.7367551020408	2.7775	75	1083	6	1	1	8	0	-2	8	0	0	2.1425181232208543	
i 1	871.7367551020408	2.7775	75	199	7	1	7	2	0	-2	2	0	0	2.1425181232208543	
i 1	871.9923741496599	0.2525	74	199	7	5	11	17	0	2	17	0	0	2.021576994371229	
i 1	872.014850340136	0.2525	72	1083	6	2	3	1	0	0	1	0	0	7.242100706752225	
i 1	872.235149659864	1.01	71	199	3	24	14	0	0	0	0	0	0	4.0	
i 1	872.2359523809524	0.2525	72	1083	6	1	13	8	0	-2	8	0	0	2.1425181232208543	
i 1	872.2367551020408	2.2725	69	697	5	3	6	1	0	0	1	0	0	7.242100706752225	
i 1	872.2439795918367	2.2725	69	199	5	4	4	1	0	0	1	0	0	7.242100706752225	
i 1	872.2528095238096	0.2525	77	199	7	5	15	17	0	1	17	0	0	2.021576994371229	
i 1	872.4955850340136	1.7675	77	697	6	5	5	17	0	1	17	0	0	2.021576994371229	
i 1	872.5036122448979	0.2525	72	199	3	24	1	2	0	-2	2	0	0	3.1425181232208543	
i 1	872.5060204081633	0.505	71	697	3	24	12	0	0	-1	0	0	0	4.0	
i 1	872.7584285714286	1.5150000000000001	77	199	7	5	11	16	0	2	16	0	0	2.021576994371229	
i 1	872.7632448979592	0.2525	69	199	6	9	15	0	0	-1	0	0	0	6.242100706752225	
i 1	872.9947823129252	0.7575000000000001	68	199	2	24	9	1	0	0	1	0	0	4.0	
i 1	873.0044149659864	0.2525	69	199	5	3	12	1	0	-1	1	0	0	7.242100706752225	
i 1	873.0084285714286	0.2525	72	199	7	1	11	2	0	-2	2	0	0	2.1425181232208543	
i 1	873.2303333333333	3.0300000000000002	74	1083	6	5	6	16	0	2	16	0	0	2.021576994371229	
i 1	873.2600340136055	0.505	72	1083	6	1	15	8	0	-2	8	0	0	2.1425181232208543	
i 1	873.490768707483	0.7575000000000001	71	199	3	24	8	0	0	0	0	0	0	4.0	
i 1	873.490768707483	2.7775	71	199	2	24	9	0	0	0	0	0	0	4.0	
i 1	873.5116394557823	0.2525	69	199	6	9	9	0	0	-1	0	0	0	6.242100706752225	
i 1	873.7399659863945	0.2525	75	199	7	1	3	2	0	-2	2	0	0	2.1425181232208543	
i 1	873.7399659863945	3.0300000000000002	69	199	6	9	7	1	0	0	1	0	0	6.242100706752225	
i 1	873.7536122448979	2.2725	77	199	7	5	9	17	0	1	17	0	0	2.021576994371229	
i 1	873.7640476190476	0.2525	68	697	3	24	9	1	0	0	1	0	0	4.0	
i 1	873.9939795918367	0.7575000000000001	72	1083	6	2	16	1	0	0	1	0	0	7.242100706752225	
i 1	874.0180612244898	1.01	71	199	2	24	2	0	0	0	0	0	0	4.0	
i 1	874.0188639455782	2.2725	72	1083	6	1	14	8	0	-2	8	0	0	2.1425181232208543	
i 1	874.0188639455782	2.02	72	199	7	1	2	2	0	-2	2	0	0	2.1425181232208543	
i 1	874.2504013605442	1.2625	69	1083	6	2	10	1	0	-1	1	0	0	7.242100706752225	
i 1	874.2512040816326	1.2625	69	199	5	3	16	1	0	-1	1	0	0	7.242100706752225	
i 1	874.2536122448979	0.2525	77	1083	6	5	4	17	0	2	17	0	0	2.021576994371229	
i 1	874.4875578231292	0.2525	77	697	6	5	12	17	0	1	17	0	0	2.021576994371229	
i 1	874.5188639455782	0.2525	75	199	7	1	12	2	0	-2	2	0	0	2.1425181232208543	
i 1	874.7495986394558	1.5150000000000001	71	199	3	24	9	0	0	0	0	0	0	4.0	
i 1	874.764850340136	0.2525	75	1083	6	1	11	8	0	-2	8	0	0	2.1425181232208543	
i 1	874.9819387755102	0.2525	68	697	3	24	11	1	0	-1	1	0	0	4.0	
i 1	874.9931768707482	2.02	75	199	7	1	11	2	0	-2	2	0	0	2.1425181232208543	
i 1	875.0172585034013	2.02	72	1083	6	2	14	1	0	0	1	0	0	7.242100706752225	
i 1	875.2319387755102	0.505	68	199	2	24	3	0	0	0	0	0	0	4.0	
i 1	875.266455782313	0.2525	77	697	6	5	11	17	0	1	17	0	0	2.021576994371229	
i 1	875.4931768707482	1.5150000000000001	72	697	4	24	6	2	0	1	2	0	0	3.1425181232208543	
i 1	875.4931768707482	0.2525	69	199	6	9	9	0	0	-1	0	0	0	6.242100706752225	
i 1	875.5012040816326	1.5150000000000001	77	199	7	5	1	16	0	2	16	0	0	2.021576994371229	
i 1	875.5188639455782	1.5150000000000001	77	697	6	5	8	17	0	1	17	0	0	2.021576994371229	
i 1	875.740768707483	0.2525	69	199	5	4	16	1	0	0	1	0	0	7.242100706752225	
i 1	875.7447823129252	0.2525	68	697	3	24	7	0	0	-1	0	0	0	4.0	
i 1	875.9995986394558	0.2525	69	697	4	4	8	1	0	-1	1	0	0	7.242100706752225	
i 1	876.0140476190476	1.01	68	199	2	24	3	0	0	0	0	0	0	4.0	
i 1	876.2359523809524	0.2525	75	1083	6	1	16	8	0	-2	8	0	0	2.1425181232208543	
i 1	876.2399659863945	1.2625	69	1083	6	2	13	1	0	-1	1	0	0	7.242100706752225	
i 1	876.2560204081633	0.2525	74	199	7	5	4	17	0	2	17	0	0	2.021576994371229	
i 1	876.264850340136	1.2625	69	199	5	3	15	1	0	-1	1	0	0	7.242100706752225	
i 1	876.4971904761904	3.0300000000000002	72	697	6	1	5	2	0	1	2	0	0	2.1425181232208543	
i 1	876.5100340136055	1.01	72	199	3	24	5	2	0	-2	2	0	0	3.1425181232208543	
i 1	876.5116394557823	3.535	77	1083	6	5	10	17	0	2	17	0	0	2.021576994371229	
i 1	876.5188639455782	3.2825	77	199	7	5	15	16	0	1	16	0	0	2.021576994371229	
i 1	876.7479931972789	1.01	71	199	2	24	14	0	0	0	0	0	0	4.0	
i 1	876.7624421768708	0.7575000000000001	71	199	3	24	12	0	0	0	0	0	0	4.0	
i 1	876.990768707483	1.7675	69	199	6	9	1	0	0	-1	0	0	0	6.242100706752225	
i 1	876.9971904761904	0.2525	75	1083	6	1	4	8	0	-2	8	0	0	2.1425181232208543	
i 1	877.0044149659864	1.5150000000000001	69	697	4	4	7	1	0	-1	1	0	0	7.242100706752225	
i 1	877.016455782313	0.2525	77	697	6	5	15	17	0	1	17	0	0	2.021576994371229	
i 1	877.2415714285714	0.2525	71	199	2	24	15	0	0	-1	0	0	0	4.0	
i 1	877.2576258503401	0.2525	72	199	7	1	3	2	0	-2	2	0	0	2.1425181232208543	
i 1	877.2616394557823	0.2525	77	697	6	5	15	17	0	1	17	0	0	2.021576994371229	
i 1	877.4955850340136	2.2725	72	199	5	24	12	2	0	-2	2	0	0	3.1425181232208543	
i 1	877.5108367346938	20.4525	61	1083	5	14	16	6	0	1	6	0	0	1.5255790233655324	
i 1	877.5132448979592	0.2525	69	199	6	9	14	1	0	0	1	0	0	6.242100706752225	
i 1	877.5172585034013	0.2525	72	697	4	24	15	2	0	1	2	0	0	3.1425181232208543	
i 1	877.7327414965987	0.2525	72	1083	6	2	14	1	0	0	1	0	0	7.242100706752225	
i 1	877.7391632653062	0.2525	71	199	2	24	9	0	0	-1	0	0	0	4.0	
i 1	877.7431768707482	5.3025	75	1083	6	1	5	8	0	-2	8	0	0	2.1425181232208543	
i 1	877.7520068027211	1.01	75	199	7	1	7	2	0	-2	2	0	0	2.1425181232208543	
i 1	877.9843469387755	1.5150000000000001	69	1083	6	2	1	1	0	-1	1	0	0	7.242100706752225	
i 1	878.0044149659864	1.2625	69	199	5	3	2	1	0	-1	1	0	0	7.242100706752225	
i 1	878.4915714285714	1.7675	71	199	3	24	11	0	0	0	0	0	0	4.0	
i 1	878.7311360544218	1.5150000000000001	69	697	5	3	7	1	0	0	1	0	0	7.242100706752225	
i 1	878.7487959183674	1.5150000000000001	69	199	5	4	16	1	0	0	1	0	0	7.242100706752225	
i 1	878.9883605442177	0.2525	74	199	7	5	1	17	0	2	17	0	0	2.021576994371229	
i 1	879.0188639455782	4.04	75	199	7	1	5	2	0	-2	2	0	0	2.1425181232208543	
i 1	879.2479931972789	2.02	77	199	7	5	6	16	0	2	16	0	0	2.021576994371229	
i 1	879.2600340136055	2.02	77	697	6	5	8	17	0	1	17	0	0	2.021576994371229	
i 1	879.5028095238096	0.2525	69	199	5	3	2	1	0	-1	1	0	0	7.242100706752225	
i 1	879.7495986394558	0.2525	72	697	6	1	4	2	0	1	2	0	0	2.1425181232208543	
i 1	879.7576258503401	1.7675	72	1083	6	2	8	1	0	0	1	0	0	7.242100706752225	
i 1	879.766455782313	1.7675	69	199	6	9	11	1	0	0	1	0	0	6.242100706752225	
i 1	879.9923741496599	0.2525	77	697	6	5	6	17	0	1	17	0	0	2.021576994371229	
i 1	880.0012040816326	1.7675	71	199	2	24	5	0	0	0	0	0	0	4.0	
i 1	880.0124421768708	0.505	72	199	7	1	2	2	0	-2	2	0	0	2.1425181232208543	
i 1	880.2479931972789	0.2525	69	697	4	4	9	1	0	-1	1	0	0	7.242100706752225	
i 1	880.2672585034013	0.2525	74	1083	6	5	5	16	0	2	16	0	0	2.021576994371229	
i 1	880.4955850340136	0.2525	77	1083	6	5	7	17	0	2	17	0	0	2.021576994371229	
i 1	880.4971904761904	0.2525	71	199	2	24	3	0	0	-1	0	0	0	4.0	
i 1	880.4995986394558	0.2525	75	199	7	1	16	2	0	-2	2	0	0	2.1425181232208543	
i 1	880.4995986394558	0.2525	69	199	6	9	5	0	0	-1	0	0	0	6.242100706752225	
i 1	880.7415714285714	0.2525	72	697	4	24	8	2	0	1	2	0	0	3.1425181232208543	
i 1	880.7455850340136	1.7675	77	199	6	5	13	17	0	1	17	0	0	2.021576994371229	
i 1	880.7552176870748	0.2525	69	697	5	3	10	1	0	0	1	0	0	7.242100706752225	
i 1	880.7560204081633	1.7675	74	1083	6	5	5	16	0	2	16	0	0	2.021576994371229	
i 1	880.9963877551021	1.2625	69	1083	6	2	2	1	0	-1	1	0	0	7.242100706752225	
i 1	881.0012040816326	1.2625	69	199	5	3	2	1	0	-1	1	0	0	7.242100706752225	
i 1	881.0100340136055	0.505	72	199	7	1	4	2	0	-2	2	0	0	2.1425181232208543	
i 1	881.235149659864	0.2525	77	697	6	5	9	17	0	1	17	0	0	2.021576994371229	
i 1	881.2656530612245	1.01	71	199	3	24	14	0	0	0	0	0	0	4.0	
i 1	881.4827414965987	0.2525	69	199	5	4	13	1	0	0	1	0	0	7.242100706752225	
i 1	881.483544217687	0.7575000000000001	72	1083	6	1	7	8	0	-2	8	0	0	2.1425181232208543	
i 1	881.5044149659864	0.2525	74	199	7	5	12	17	0	2	17	0	0	2.021576994371229	
i 1	881.7520068027211	0.2525	77	697	6	5	10	17	0	1	17	0	0	2.021576994371229	
i 1	881.7656530612245	1.5150000000000001	72	1083	6	2	9	1	0	0	1	0	0	7.242100706752225	
i 1	881.7680612244898	1.5150000000000001	69	199	6	9	5	1	0	0	1	0	0	6.242100706752225	
i 1	881.9891632653062	1.7675	77	199	7	5	2	16	0	2	16	0	0	2.021576994371229	
i 1	881.9971904761904	5.3025	71	199	2	24	2	0	0	0	0	0	0	4.0	
i 1	882.0156530612245	1.7675	77	697	6	5	7	17	0	1	17	0	0	2.021576994371229	
i 1	882.2327414965987	2.02	72	199	7	1	15	2	0	-2	2	0	0	2.1425181232208543	
i 1	882.240768707483	0.2525	69	199	6	9	14	0	0	-1	0	0	0	6.242100706752225	
i 1	882.4811360544218	1.7675	72	1083	6	1	13	8	0	-2	8	0	0	2.1425181232208543	
i 1	882.4971904761904	0.2525	77	199	7	5	14	16	0	1	16	0	0	2.021576994371229	
i 1	882.5012040816326	0.2525	69	697	4	4	14	1	0	-1	1	0	0	7.242100706752225	
i 1	882.5044149659864	0.7575000000000001	71	199	3	24	10	0	0	0	0	0	0	4.0	
i 1	882.7439795918367	2.2725	69	1083	6	2	10	1	0	-1	1	0	0	7.242100706752225	
i 1	882.7624421768708	2.2725	69	199	5	3	3	1	0	-1	1	0	0	7.242100706752225	
i 1	882.7632448979592	0.2525	74	199	7	5	7	17	0	2	17	0	0	2.021576994371229	
i 1	882.990768707483	4.545	77	1083	6	5	9	17	0	2	17	0	0	2.021576994371229	
i 1	882.9987959183674	0.2525	72	697	6	1	12	2	0	1	2	0	0	2.1425181232208543	
i 1	883.2520068027211	4.2925	77	199	7	5	12	16	0	1	16	0	0	2.021576994371229	
i 1	883.2544149659864	0.505	72	199	5	24	13	2	0	-2	2	0	0	3.1425181232208543	
i 1	883.2696666666667	1.01	69	199	6	9	10	0	0	-1	0	0	0	6.242100706752225	
i 1	883.5044149659864	0.7575000000000001	69	697	4	4	13	1	0	-1	1	0	0	7.242100706752225	
i 1	883.5044149659864	1.5150000000000001	71	199	3	24	14	0	0	0	0	0	0	4.0	
i 1	883.7423741496599	1.01	72	697	4	24	10	2	0	1	2	0	0	3.1425181232208543	
i 1	883.7479931972789	1.01	75	199	7	1	14	2	0	-2	2	0	0	2.1425181232208543	
i 1	883.7528095238096	0.2525	74	199	7	5	15	17	0	2	17	0	0	2.021576994371229	
i 1	883.9803333333333	0.2525	77	199	7	5	5	16	0	2	16	0	0	2.021576994371229	
i 1	884.2399659863945	6.8175	61	697	4	7	7	9	0	0	9	0	0	0.7754959706724363	
i 1	884.2528095238096	2.7775	69	199	5	4	5	1	0	0	1	0	0	7.242100706752225	
i 1	884.2616394557823	1.2625	72	199	5	24	8	2	0	-2	2	0	0	3.1425181232208543	
i 1	884.264850340136	0.505	77	697	6	5	3	17	0	1	17	0	0	2.021576994371229	
i 1	884.2672585034013	1.2625	72	697	6	1	4	2	0	1	2	0	0	2.1425181232208543	
i 1	884.4859523809524	2.525	69	697	5	3	3	1	0	0	1	0	0	7.242100706752225	
i 1	884.7327414965987	0.2525	72	1083	6	1	7	8	0	-2	8	0	0	2.1425181232208543	
i 1	884.7656530612245	0.505	74	1083	6	5	14	16	0	2	16	0	0	2.021576994371229	
i 1	884.9811360544218	0.2525	69	199	6	9	15	0	0	-1	0	0	0	6.242100706752225	
i 1	884.9947823129252	1.5150000000000001	75	199	7	1	11	2	0	-2	2	0	0	2.1425181232208543	
i 1	884.9995986394558	1.5150000000000001	75	1083	6	1	11	8	0	-2	8	0	0	2.1425181232208543	
i 1	885.2311360544218	0.2525	69	697	4	4	6	1	0	-1	1	0	0	7.242100706752225	
i 1	885.2536122448979	0.505	77	697	6	5	10	17	0	1	17	0	0	2.021576994371229	
i 1	885.4995986394558	0.2525	72	1083	6	1	15	8	0	-2	8	0	0	2.1425181232208543	
i 1	885.7423741496599	1.5150000000000001	71	199	3	24	1	0	0	0	0	0	0	4.0	
i 1	885.7431768707482	0.2525	77	199	6	5	15	17	0	1	17	0	0	2.021576994371229	
i 1	885.7640476190476	0.2525	72	199	7	1	14	2	0	-2	2	0	0	2.1425181232208543	
i 1	885.985149659864	2.2725	72	697	6	1	9	2	0	1	2	0	0	2.1425181232208543	
i 1	886.0084285714286	2.02	72	199	5	24	3	2	0	-2	2	0	0	3.1425181232208543	
i 1	886.0188639455782	0.2525	77	697	6	5	8	17	0	1	17	0	0	2.021576994371229	
i 1	886.2431768707482	0.2525	69	697	4	4	7	1	0	-1	1	0	0	7.242100706752225	
i 1	886.2680612244898	0.2525	77	199	6	5	16	16	0	2	16	0	0	2.021576994371229	
i 1	886.4811360544218	1.5150000000000001	69	199	6	9	7	1	0	0	1	0	0	6.242100706752225	
i 1	886.4947823129252	0.505	77	199	6	5	13	17	0	1	17	0	0	2.021576994371229	
i 1	886.4979931972789	1.5150000000000001	72	1083	6	2	7	1	0	0	1	0	0	7.242100706752225	
i 1	886.5124421768708	0.2525	75	199	7	1	7	2	0	-2	2	0	0	2.1425181232208543	
i 1	886.7608367346938	0.2525	72	1083	6	1	10	8	0	-2	8	0	0	2.1425181232208543	
i 1	886.985149659864	1.01	77	697	6	5	3	17	0	1	17	0	0	2.021576994371229	
i 1	887.0004013605442	0.2525	69	1083	6	2	11	1	0	-1	1	0	0	7.242100706752225	
i 1	887.0076258503401	0.7575000000000001	77	199	6	5	16	16	0	2	16	0	0	2.021576994371229	
i 1	887.235149659864	0.2525	72	1083	6	1	14	8	0	-2	8	0	0	2.1425181232208543	
i 1	887.2560204081633	2.7775	74	1083	6	5	15	16	0	2	16	0	0	2.021576994371229	
i 1	887.2608367346938	0.2525	69	199	6	9	15	0	0	-1	0	0	0	6.242100706752225	
i 1	887.266455782313	2.7775	77	199	6	5	15	17	0	1	17	0	0	2.021576994371229	
i 1	887.483544217687	2.2725	69	1083	6	2	2	1	0	-1	1	0	0	7.242100706752225	
i 1	887.4891632653062	2.2725	69	199	5	3	1	1	0	-1	1	0	0	7.242100706752225	
i 1	887.4891632653062	0.2525	68	199	2	24	12	1	0	-1	1	0	0	4.0	
i 1	887.5060204081633	3.2825	75	1083	6	1	10	8	0	-2	8	0	0	2.1425181232208543	
i 1	887.5076258503401	3.2825	75	199	7	1	3	2	0	-2	2	0	0	2.1425181232208543	
i 1	887.5076258503401	10.352500000000001	71	199	2	24	2	0	0	0	0	0	0	4.0	
i 1	887.516455782313	1.7675	71	199	3	24	3	0	0	0	0	0	0	4.0	
i 1	887.7367551020408	0.2525	68	697	3	24	4	0	0	0	0	0	0	4.0	
i 1	887.983544217687	0.505	77	199	7	5	11	16	0	1	16	0	0	2.021576994371229	
i 1	887.9875578231292	0.2525	69	697	5	3	9	1	0	0	1	0	0	7.242100706752225	
i 1	888.0044149659864	0.7575000000000001	68	199	2	24	14	0	0	-1	0	0	0	4.0	
i 1	888.2311360544218	0.7575000000000001	72	1083	6	2	4	1	0	0	1	0	0	7.242100706752225	
i 1	888.2319387755102	1.01	69	199	6	9	9	1	0	0	1	0	0	6.242100706752225	
i 1	888.2471904761904	0.2525	72	199	5	24	3	2	0	-2	2	0	0	3.1425181232208543	
i 1	888.5036122448979	0.2525	74	199	7	5	5	17	0	2	17	0	0	2.021576994371229	
i 1	888.509231292517	0.2525	72	199	7	1	11	2	0	-2	2	0	0	2.1425181232208543	
i 1	888.7327414965987	0.2525	71	697	3	24	11	1	0	-1	1	0	0	4.0	
i 1	888.7423741496599	0.2525	77	697	6	5	1	17	0	1	17	0	0	2.021576994371229	
i 1	888.9963877551021	0.2525	71	199	2	24	13	1	0	-1	1	0	0	4.0	
i 1	889.2383605442177	1.7675	69	697	4	4	6	1	0	-1	1	0	0	7.242100706752225	
i 1	889.2399659863945	1.7675	69	199	6	9	11	0	0	-1	0	0	0	6.242100706752225	
i 1	889.2568231292518	0.2525	77	697	6	5	3	17	0	1	17	0	0	2.021576994371229	
i 1	889.4891632653062	0.7575000000000001	77	199	6	5	2	16	0	2	16	0	0	2.021576994371229	
i 1	889.4995986394558	0.7575000000000001	77	697	6	5	12	17	0	1	17	0	0	2.021576994371229	
i 1	889.7367551020408	0.2525	69	697	5	3	13	1	0	0	1	0	0	7.242100706752225	
i 1	889.7495986394558	0.7575000000000001	71	199	3	24	1	0	0	0	0	0	0	4.0	
i 1	889.7520068027211	0.2525	71	199	2	24	3	1	0	0	1	0	0	4.0	
i 1	889.7568231292518	1.2625	77	1083	6	5	7	17	0	2	17	0	0	2.021576994371229	
i 1	889.7672585034013	1.2625	77	199	7	5	14	16	0	1	16	0	0	2.021576994371229	
i 1	890.0172585034013	0.2525	72	1083	6	2	9	1	0	0	1	0	0	7.242100706752225	
i 1	890.0196666666667	0.2525	72	697	6	1	5	2	0	1	2	0	0	2.1425181232208543	
i 1	890.2423741496599	0.2525	74	199	7	5	13	17	0	2	17	0	0	2.021576994371229	
i 1	890.2431768707482	1.2625	72	1083	6	1	10	8	0	-2	8	0	0	2.1425181232208543	
i 1	890.2447823129252	0.2525	69	199	5	4	7	1	0	0	1	0	0	7.242100706752225	
i 1	890.2495986394558	1.2625	72	199	7	1	6	2	0	-2	2	0	0	2.1425181232208543	
i 1	890.4803333333333	1.2625	69	199	5	3	6	1	0	-1	1	0	0	7.242100706752225	
i 1	890.4811360544218	1.2625	69	1083	6	2	2	1	0	-1	1	0	0	7.242100706752225	
i 1	890.4931768707482	0.2525	77	697	6	5	10	17	0	1	17	0	0	2.021576994371229	
i 1	890.5068231292518	0.2525	68	697	3	24	6	1	0	0	1	0	0	4.0	
i 1	890.7600340136055	1.7675	75	199	7	1	3	2	0	-2	2	0	0	2.1425181232208543	
i 1	890.9859523809524	3.2825	77	1083	6	5	4	17	0	2	17	0	0	2.021576994371229	
i 1	890.9931768707482	14.645	61	697	5	7	14	9	0	0	9	0	0	0.7754959706724363	
i 1	891.0004013605442	13.13	66	1083	4	14	7	6	0	0	6	0	0	1.5255790233655324	
i 1	891.0020068027211	1.5150000000000001	72	697	4	24	14	2	0	1	2	0	0	3.1425181232208543	
i 1	891.0076258503401	3.2825	77	199	7	5	9	16	0	1	16	0	0	2.021576994371229	
i 1	891.0084285714286	0.2525	72	1083	6	2	8	1	0	0	1	0	0	7.242100706752225	
i 1	891.2319387755102	0.2525	77	199	6	5	15	17	0	1	17	0	0	2.021576994371229	
i 1	891.2463877551021	2.2725	69	199	5	4	11	1	0	0	1	0	0	7.242100706752225	
i 1	891.2680612244898	2.2725	69	697	5	3	8	1	0	0	1	0	0	7.242100706752225	
i 1	891.4827414965987	0.2525	71	199	2	24	3	1	0	0	1	0	0	4.0	
i 1	891.5044149659864	0.505	77	697	6	5	6	17	0	1	17	0	0	2.021576994371229	
i 1	891.516455782313	1.01	71	199	3	24	6	0	0	0	0	0	0	4.0	
i 1	891.5188639455782	0.2525	75	1083	6	1	6	8	0	-2	8	0	0	2.1425181232208543	
i 1	891.7311360544218	0.2525	69	697	4	4	4	1	0	-1	1	0	0	7.242100706752225	
i 1	891.7632448979592	0.2525	72	1083	6	1	14	8	0	-2	8	0	0	2.1425181232208543	
i 1	891.7632448979592	0.505	71	697	3	24	10	1	0	-1	1	0	0	4.0	
i 1	891.766455782313	0.2525	77	199	6	5	8	16	0	2	16	0	0	2.021576994371229	
i 1	891.9803333333333	0.2525	77	199	6	5	4	17	0	1	17	0	0	2.021576994371229	
i 1	891.990768707483	2.2725	72	697	6	1	10	2	0	1	2	0	0	2.1425181232208543	
i 1	891.9979931972789	0.2525	74	199	7	5	15	17	0	2	17	0	0	2.021576994371229	
i 1	892.016455782313	0.2525	72	1083	6	2	13	1	0	0	1	0	0	7.242100706752225	
i 1	892.0188639455782	2.2725	72	199	5	24	16	2	0	-2	2	0	0	3.1425181232208543	
i 1	892.0196666666667	0.2525	69	199	5	3	10	1	0	-1	1	0	0	7.242100706752225	
i 1	892.2327414965987	0.505	69	1083	6	2	12	1	0	-1	1	0	0	7.242100706752225	
i 1	892.2520068027211	1.2625	71	199	2	24	2	1	0	-1	1	0	0	4.0	
i 1	892.5140476190476	0.2525	72	1083	6	1	13	8	0	-2	8	0	0	2.1425181232208543	
i 1	892.7520068027211	0.2525	75	199	7	1	5	2	0	-2	2	0	0	2.1425181232208543	
i 1	892.7584285714286	0.2525	77	199	6	5	9	16	0	2	16	0	0	2.021576994371229	
i 1	892.7624421768708	0.2525	69	199	6	9	14	0	0	-1	0	0	0	6.242100706752225	
i 1	892.7624421768708	1.01	69	199	6	9	4	1	0	0	1	0	0	6.242100706752225	
i 1	892.985149659864	0.2525	77	697	6	5	7	17	0	1	17	0	0	2.021576994371229	
i 1	892.9867551020408	0.7575000000000001	72	1083	6	2	6	1	0	0	1	0	0	7.242100706752225	
i 1	892.9987959183674	0.2525	72	199	7	1	1	2	0	-2	2	0	0	2.1425181232208543	
i 1	893.2311360544218	1.2625	71	199	3	24	3	0	0	0	0	0	0	4.0	
i 1	893.2399659863945	1.2625	69	1083	6	2	3	1	0	-1	1	0	0	7.242100706752225	
i 1	893.240768707483	2.02	75	199	7	1	6	2	0	-2	2	0	0	2.1425181232208543	
i 1	893.2512040816326	1.2625	69	199	5	3	2	1	0	-1	1	0	0	7.242100706752225	
i 1	893.2576258503401	2.02	75	1083	6	1	2	8	0	-2	8	0	0	2.1425181232208543	
i 1	893.4931768707482	0.2525	77	697	6	5	14	17	0	1	17	0	0	2.021576994371229	
i 1	893.733544217687	1.5150000000000001	77	199	6	5	2	16	0	2	16	0	0	2.021576994371229	
i 1	893.7471904761904	0.2525	69	199	6	9	5	0	0	-1	0	0	0	6.242100706752225	
i 1	893.7624421768708	1.2625	71	199	2	24	3	0	0	-1	0	0	0	4.0	
i 1	893.7640476190476	1.5150000000000001	77	697	6	5	15	17	0	1	17	0	0	2.021576994371229	
i 1	893.985149659864	2.02	69	199	6	9	10	1	0	0	1	0	0	6.242100706752225	
i 1	894.0100340136055	2.02	72	1083	6	2	4	1	0	0	1	0	0	7.242100706752225	
i 1	894.2367551020408	0.2525	72	1083	6	1	5	8	0	-2	8	0	0	2.1425181232208543	
i 1	894.2528095238096	0.2525	74	199	7	5	7	17	0	2	17	0	0	2.021576994371229	
i 1	894.2544149659864	0.2525	74	1083	6	5	15	16	0	2	16	0	0	2.021576994371229	
i 1	894.4867551020408	1.7675	72	697	6	1	12	2	0	1	2	0	0	2.1425181232208543	
i 1	894.5108367346938	0.2525	77	1083	6	5	12	17	0	2	17	0	0	2.021576994371229	
i 1	894.5156530612245	2.02	72	199	5	24	3	2	0	-2	2	0	0	3.1425181232208543	
i 1	894.516455782313	0.505	69	697	5	3	8	1	0	0	1	0	0	7.242100706752225	
i 1	894.7319387755102	2.7775	74	1083	6	5	8	16	0	2	16	0	0	2.021576994371229	
i 1	894.7319387755102	2.525	77	199	6	5	10	17	0	1	17	0	0	2.021576994371229	
i 1	894.7471904761904	3.7875	71	199	3	24	13	0	0	0	0	0	0	4.0	
i 1	895.0012040816326	0.2525	69	199	6	9	8	0	0	-1	0	0	0	6.242100706752225	
i 1	895.0028095238096	0.7575000000000001	71	697	3	24	11	1	0	-1	1	0	0	4.0	
i 1	895.0076258503401	0.2525	69	199	5	4	4	1	0	0	1	0	0	7.242100706752225	
i 1	895.2343469387755	0.2525	74	199	7	5	16	17	0	2	17	0	0	2.021576994371229	
i 1	895.2423741496599	0.2525	75	199	7	1	12	2	0	-2	2	0	0	2.1425181232208543	
i 1	895.2487959183674	1.2625	69	199	5	3	5	1	0	-1	1	0	0	7.242100706752225	
i 1	895.2672585034013	1.2625	69	1083	6	2	10	1	0	-1	1	0	0	7.242100706752225	
i 1	895.4819387755102	0.2525	77	697	6	5	14	17	0	1	17	0	0	2.021576994371229	
i 1	895.4971904761904	0.2525	72	697	4	24	13	2	0	1	2	0	0	3.1425181232208543	
i 1	895.5020068027211	0.2525	77	199	7	5	8	16	0	1	16	0	0	2.021576994371229	
i 1	895.7311360544218	1.7675	69	697	4	4	3	1	0	-1	1	0	0	7.242100706752225	
i 1	895.7375578231292	0.2525	77	199	6	5	12	16	0	2	16	0	0	2.021576994371229	
i 1	895.7391632653062	1.7675	69	199	6	9	5	0	0	-1	0	0	0	6.242100706752225	
i 1	895.7495986394558	0.2525	68	199	2	24	2	1	0	-1	1	0	0	4.0	
i 1	895.7512040816326	2.7775	75	1083	6	1	8	8	0	-2	8	0	0	2.1425181232208543	
i 1	895.7624421768708	2.7775	75	199	7	1	8	2	0	-2	2	0	0	2.1425181232208543	
i 1	895.9979931972789	0.2525	77	199	7	5	11	16	0	1	16	0	0	2.021576994371229	
i 1	896.2431768707482	1.7675	77	697	6	5	9	17	0	1	17	0	0	2.021576994371229	
i 1	896.259231292517	0.2525	72	199	7	1	16	2	0	-2	2	0	0	2.1425181232208543	
i 1	896.2688639455782	0.2525	77	1083	6	5	2	17	0	2	17	0	0	2.021576994371229	
i 1	896.4875578231292	0.2525	72	697	6	1	14	2	0	1	2	0	0	2.1425181232208543	
i 1	896.5004013605442	0.2525	69	697	5	3	11	1	0	0	1	0	0	7.242100706752225	
i 1	896.5108367346938	1.5150000000000001	77	199	6	5	13	16	0	2	16	0	0	2.021576994371229	
i 1	896.7463877551021	0.2525	69	199	5	4	6	1	0	0	1	0	0	7.242100706752225	
i 1	896.9867551020408	1.2625	69	1083	6	2	4	1	0	-1	1	0	0	7.242100706752225	
i 1	896.9899659863945	1.2625	69	199	5	3	2	1	0	-1	1	0	0	7.242100706752225	
i 1	897.009231292517	0.2525	72	1083	6	1	7	8	0	-2	8	0	0	2.1425181232208543	
i 1	897.2327414965987	0.2525	75	199	7	1	2	2	0	-2	2	0	0	2.1425181232208543	
i 1	897.2576258503401	0.2525	72	199	7	1	10	2	0	-2	2	0	0	2.1425181232208543	
i 1	897.4859523809524	0.2525	69	199	6	9	6	1	0	0	1	0	0	6.242100706752225	
i 1	897.4883605442177	2.02	69	697	5	3	14	1	0	0	1	0	0	7.242100706752225	
i 1	897.4939795918367	3.535	77	199	7	5	16	16	0	1	16	0	0	2.021576994371229	
i 1	897.5004013605442	0.505	72	199	5	24	6	2	0	-2	2	0	0	3.1425181232208543	
i 1	897.5116394557823	3.535	77	1083	6	5	1	17	0	2	17	0	0	2.021576994371229	
i 1	897.7471904761904	6.3125	61	1083	4	14	11	6	0	1	6	0	0	1.5255790233655324	
i 1	897.7512040816326	1.5150000000000001	69	199	5	4	6	1	0	0	1	0	0	7.242100706752225	
i 1	897.9923741496599	2.02	72	199	7	1	15	2	0	-2	2	0	0	2.1425181232208543	
i 1	897.9947823129252	5.05	71	199	2	24	1	0	0	0	0	0	0	4.0	
i 1	898.0044149659864	2.02	72	1083	6	1	6	8	0	-2	8	0	0	2.1425181232208543	
i 1	898.0076258503401	1.5150000000000001	71	199	2	24	6	0	0	0	0	0	0	4.0	
i 1	898.009231292517	0.505	74	199	7	5	11	17	0	2	17	0	0	2.021576994371229	
i 1	898.2576258503401	4.04	72	1083	6	2	12	1	0	0	1	0	0	7.242100706752225	
i 1	898.266455782313	0.505	77	697	6	5	1	17	0	1	17	0	0	2.021576994371229	
i 1	898.5036122448979	0.505	74	1083	6	5	14	16	0	2	16	0	0	2.021576994371229	
i 1	898.5196666666667	0.2525	75	199	7	1	2	2	0	-2	2	0	0	2.1425181232208543	
i 1	898.5196666666667	3.7875	69	199	6	9	4	1	0	0	1	0	0	6.242100706752225	
i 1	898.7640476190476	0.505	75	1083	6	1	3	8	0	-2	8	0	0	2.1425181232208543	
i 1	898.9803333333333	0.2525	74	199	7	5	1	17	0	2	17	0	0	2.021576994371229	
i 1	898.9891632653062	0.2525	72	697	6	1	10	2	0	1	2	0	0	2.1425181232208543	
i 1	898.9923741496599	14.645	71	199	3	24	2	0	0	0	0	0	0	4.0	
i 1	899.2303333333333	2.525	72	697	4	24	7	2	0	1	2	0	0	3.1425181232208543	
i 1	899.2439795918367	0.2525	74	1083	6	5	1	16	0	2	16	0	0	2.021576994371229	
i 1	899.2447823129252	0.505	69	199	6	9	16	0	0	-1	0	0	0	6.242100706752225	
i 1	899.2656530612245	2.02	75	199	7	1	5	2	0	-2	2	0	0	2.1425181232208543	
i 1	899.7479931972789	0.2525	69	199	5	4	6	1	0	0	1	0	0	7.242100706752225	
i 1	899.7528095238096	1.2625	71	199	2	24	7	1	0	0	1	0	0	4.0	
i 1	899.7536122448979	1.7675	69	1083	6	2	5	1	0	-1	1	0	0	7.242100706752225	
i 1	899.9987959183674	0.2525	74	199	7	5	12	17	0	2	17	0	0	2.021576994371229	
i 1	900.0028095238096	1.5150000000000001	69	199	5	3	1	1	0	-1	1	0	0	7.242100706752225	
i 1	900.0052176870748	4.2925	77	697	6	5	13	17	0	1	17	0	0	2.021576994371229	
i 1	900.016455782313	0.2525	75	199	7	1	2	2	0	-2	2	0	0	2.1425181232208543	
i 1	900.2359523809524	2.2725	77	199	6	5	9	16	0	2	16	0	0	2.021576994371229	
i 1	900.2528095238096	3.535	72	697	6	1	11	2	0	1	2	0	0	2.1425181232208543	
i 1	900.2608367346938	0.2525	72	199	7	1	11	2	0	-2	2	0	0	2.1425181232208543	
i 1	900.4899659863945	3.535	72	199	5	24	9	2	0	-2	2	0	0	3.1425181232208543	
i 1	901.0036122448979	0.2525	77	199	7	5	6	17	0	1	17	0	0	2.021576994371229	
i 1	901.0060204081633	0.505	68	697	3	24	15	1	0	-1	1	0	0	4.0	
i 1	901.0132448979592	0.2525	77	697	6	5	12	17	0	1	17	0	0	2.021576994371229	
i 1	901.2319387755102	0.2525	77	199	7	5	2	16	0	1	16	0	0	2.021576994371229	
i 1	901.266455782313	0.2525	74	199	7	5	9	17	0	2	17	0	0	2.021576994371229	
i 1	901.4803333333333	0.2525	69	697	4	4	5	1	0	-1	1	0	0	7.242100706752225	
i 1	901.5020068027211	0.505	68	199	2	24	16	1	0	0	1	0	0	4.0	
i 1	901.5036122448979	2.2725	77	199	7	5	15	17	0	1	17	0	0	2.021576994371229	
i 1	901.5108367346938	0.2525	69	199	5	4	15	1	0	0	1	0	0	7.242100706752225	
i 1	901.5132448979592	2.2725	74	1083	6	5	7	16	0	2	16	0	0	2.021576994371229	
i 1	901.7455850340136	2.2725	69	1083	6	2	14	1	0	-1	1	0	0	7.242100706752225	
i 1	901.7479931972789	2.2725	69	199	5	3	7	1	0	-1	1	0	0	7.242100706752225	
i 1	901.7608367346938	2.2725	75	1083	6	1	15	8	0	-2	8	0	0	2.1425181232208543	
i 1	901.7688639455782	2.7775	75	199	7	1	14	2	0	-2	2	0	0	2.1425181232208543	
i 1	902.2383605442177	0.2525	69	697	5	3	16	1	0	0	1	0	0	7.242100706752225	
i 1	902.4931768707482	1.01	69	697	4	4	15	1	0	-1	1	0	0	7.242100706752225	
i 1	902.5180612244898	0.2525	77	1083	6	5	7	17	0	2	17	0	0	2.021576994371229	
i 1	902.5188639455782	1.01	69	199	6	9	6	0	0	-1	0	0	0	6.242100706752225	
i 1	902.7512040816326	0.2525	74	199	7	5	6	17	0	2	17	0	0	2.021576994371229	
i 1	902.9899659863945	1.01	77	199	6	5	13	16	0	2	16	0	0	2.021576994371229	
i 1	902.9971904761904	0.2525	68	199	2	24	8	0	0	0	0	0	0	4.0	
i 1	903.2327414965987	0.2525	71	697	3	24	8	1	0	-1	1	0	0	4.0	
i 1	903.240768707483	0.7575000000000001	69	199	5	4	6	1	0	0	1	0	0	7.242100706752225	
i 1	903.2536122448979	1.01	69	697	5	3	15	1	0	0	1	0	0	7.242100706752225	
i 1	903.4971904761904	2.02	72	697	4	24	12	2	0	1	2	0	0	3.1425181232208543	
i 1	903.5132448979592	0.505	68	199	2	24	7	1	0	0	1	0	0	4.0	
i 1	903.5140476190476	0.505	77	1083	6	5	3	17	0	2	17	0	0	2.021576994371229	
i 1	903.514850340136	2.525	74	199	7	5	11	17	0	2	17	0	0	2.021576994371229	
i 1	903.7303333333333	0.2525	72	1083	6	2	15	1	0	0	1	0	0	7.242100706752225	
i 1	903.7327414965987	1.5150000000000001	69	199	6	9	11	0	0	-1	0	0	0	6.242100706752225	
i 1	903.7391632653062	0.2525	71	199	2	24	5	0	0	0	0	0	0	4.0	
i 1	903.9819387755102	7.3225	61	901	4	14	5	9	0	0	9	0	0	1.5255790233655324	
i 1	903.9843469387755	0.505	69	901	6	2	14	1	0	0	1	0	0	7.242100706752225	
i 1	903.9867551020408	5.8075	72	199	5	24	5	2	0	-2	2	0	0	3.1425181232208543	
i 1	903.9883605442177	7.3225	66	901	4	14	2	9	0	0	9	0	0	1.5255790233655324	
i 1	903.9899659863945	0.2525	69	199	4	3	2	1	0	-1	1	0	0	7.242100706752225	
i 1	903.9955850340136	0.505	77	199	5	5	9	16	0	2	16	0	0	2.021576994371229	
i 1	903.9963877551021	1.2625	72	901	6	2	2	1	0	0	1	0	0	7.242100706752225	
i 1	903.9971904761904	0.2525	69	199	4	4	6	1	0	0	1	0	0	7.242100706752225	
i 1	904.0004013605442	0.7575000000000001	72	901	6	1	13	8	0	1	8	0	0	2.1425181232208543	
i 1	904.0028095238096	0.505	74	901	6	5	16	17	0	2	17	0	0	2.021576994371229	
i 1	904.0076258503401	0.7575000000000001	68	199	1	24	7	1	0	0	1	0	0	4.0	
i 1	904.014850340136	3.2825	71	199	1	24	10	0	0	0	0	0	0	4.0	
i 1	904.2576258503401	1.7675	69	199	6	9	1	1	0	0	1	0	0	6.242100706752225	
i 1	904.266455782313	0.2525	77	697	6	5	13	17	0	1	17	0	0	2.021576994371229	
i 1	904.4867551020408	0.2525	77	697	6	5	6	17	0	1	17	0	0	2.021576994371229	
i 1	904.5052176870748	3.2825	69	901	6	2	15	1	0	0	1	0	0	7.242100706752225	
i 1	904.5108367346938	1.5150000000000001	74	901	6	5	3	17	0	2	17	0	0	2.021576994371229	
i 1	904.5188639455782	0.505	72	697	6	1	6	2	0	1	2	0	0	2.1425181232208543	
i 1	904.7343469387755	0.2525	77	199	6	5	12	17	0	1	17	0	0	2.021576994371229	
i 1	904.7447823129252	0.2525	77	199	6	5	9	16	0	2	16	0	0	2.021576994371229	
i 1	904.7600340136055	2.2725	75	199	6	1	11	2	0	-2	2	0	0	2.1425181232208543	
i 1	904.985149659864	2.525	69	199	4	3	15	1	0	-1	1	0	0	7.242100706752225	
i 1	905.0012040816326	2.525	74	901	6	5	15	17	0	2	17	0	0	2.021576994371229	
i 1	905.2383605442177	0.2525	72	901	6	1	15	2	0	1	2	0	0	2.1425181232208543	
i 1	905.2560204081633	2.02	77	199	6	5	14	17	0	1	17	0	0	2.021576994371229	
i 1	905.4819387755102	0.2525	69	585	5	3	5	0	0	0	0	0	0	7.242100706752225	
i 1	905.490768707483	1.5150000000000001	72	585	4	24	8	2	0	-2	2	0	0	3.1425181232208543	
i 1	905.5004013605442	5.8075	61	585	5	7	7	9	0	0	9	0	0	0.7754959706724363	
i 1	905.5132448979592	0.2525	75	199	7	1	5	2	0	-2	2	0	0	2.1425181232208543	
i 1	905.7536122448979	1.01	69	199	6	9	12	0	0	-1	0	0	0	6.242100706752225	
i 1	905.7608367346938	1.01	69	585	4	4	14	1	0	0	1	0	0	7.242100706752225	
i 1	905.9843469387755	2.7775	77	199	6	5	10	16	0	2	16	0	0	2.021576994371229	
i 1	905.9859523809524	2.525	77	585	6	5	7	17	0	1	17	0	0	2.021576994371229	
i 1	905.9891632653062	3.7875	72	585	6	1	10	2	0	1	2	0	0	2.1425181232208543	
i 1	906.0132448979592	0.7575000000000001	71	585	3	24	5	1	0	0	1	0	0	4.0	
i 1	906.7431768707482	0.2525	71	199	1	24	7	0	0	0	0	0	0	4.0	
i 1	906.7439795918367	3.0300000000000002	69	199	4	4	4	1	0	0	1	0	0	7.242100706752225	
i 1	906.7600340136055	0.2525	69	199	6	9	8	1	0	0	1	0	0	6.242100706752225	
i 1	906.9955850340136	2.7775	69	585	5	3	16	0	0	0	0	0	0	7.242100706752225	
i 1	907.0116394557823	0.2525	75	199	7	1	1	2	0	-2	2	0	0	2.1425181232208543	
i 1	907.235149659864	4.04	72	901	6	1	5	8	0	1	8	0	0	2.1425181232208543	
i 1	907.2608367346938	0.2525	74	585	6	5	12	16	0	2	16	0	0	2.021576994371229	
i 1	907.2632448979592	0.2525	72	901	6	1	10	2	0	1	2	0	0	2.1425181232208543	
i 1	907.264850340136	2.2725	71	199	1	24	4	0	0	0	0	0	0	4.0	
i 1	907.5020068027211	0.2525	69	585	4	4	6	1	0	0	1	0	0	7.242100706752225	
i 1	907.5036122448979	3.7875	75	199	7	1	6	2	0	-2	2	0	0	2.1425181232208543	
i 1	907.5116394557823	2.2725	74	901	6	5	1	17	0	2	17	0	0	2.021576994371229	
i 1	907.5156530612245	2.2725	77	199	7	5	8	16	0	1	16	0	0	2.021576994371229	
i 1	907.7303333333333	0.2525	72	901	6	2	5	1	0	0	1	0	0	7.242100706752225	
i 1	907.9859523809524	0.7575000000000001	69	901	6	2	12	1	0	0	1	0	0	7.242100706752225	
i 1	908.0100340136055	0.505	69	199	6	9	13	1	0	0	1	0	0	6.242100706752225	
i 1	908.4875578231292	2.525	74	901	6	5	12	17	0	2	17	0	0	2.021576994371229	
i 1	908.514850340136	0.2525	69	199	6	9	9	0	0	-1	0	0	0	6.242100706752225	
i 1	908.733544217687	2.2725	77	199	6	5	12	17	0	1	17	0	0	2.021576994371229	
i 1	908.7544149659864	2.525	69	199	6	9	16	1	0	0	1	0	0	6.242100706752225	
i 1	908.7600340136055	2.525	72	901	6	2	8	1	0	0	1	0	0	7.242100706752225	
i 1	909.7303333333333	0.2525	74	199	7	5	8	17	0	2	17	0	0	2.021576994371229	
i 1	909.7311360544218	1.5150000000000001	69	901	6	2	13	1	0	0	1	0	0	7.242100706752225	
i 1	909.7399659863945	0.505	72	585	4	24	13	2	0	-2	2	0	0	3.1425181232208543	
i 1	909.7447823129252	0.7575000000000001	72	901	6	1	15	2	0	1	2	0	0	2.1425181232208543	
i 1	909.7552176870748	1.5150000000000001	69	199	4	3	9	1	0	-1	1	0	0	7.242100706752225	
i 1	909.764850340136	0.2525	77	585	6	5	5	17	0	1	17	0	0	2.021576994371229	
i 1	909.9827414965987	1.2625	74	901	6	5	9	17	0	2	17	0	0	2.021576994371229	
i 1	910.0116394557823	1.2625	77	199	7	5	15	16	0	1	16	0	0	2.021576994371229	
i 1	910.2439795918367	0.505	72	199	5	24	4	2	0	-2	2	0	0	3.1425181232208543	
i 1	910.5156530612245	3.0300000000000002	71	199	1	24	4	0	0	0	0	0	0	4.0	
i 1	910.5180612244898	0.2525	72	199	6	1	8	2	0	-2	2	0	0	2.1425181232208543	
i 1	910.7471904761904	0.505	72	901	6	1	12	2	0	1	2	0	0	2.1425181232208543	
i 1	910.7552176870748	0.2525	75	199	6	1	3	2	0	-2	2	0	0	2.1425181232208543	
i 1	910.9843469387755	0.2525	77	199	6	5	8	16	0	2	16	0	0	2.021576994371229	
i 1	910.9859523809524	0.2525	77	585	6	5	12	17	0	1	17	0	0	2.021576994371229	
i 1	910.9915714285714	0.2525	72	585	4	24	8	2	0	-2	2	0	0	3.1425181232208543	
i 1	911.2311360544218	2.525	61	585	6	17	1	9	0	1	9	0	0	0.8924935241881213	
i 1	911.2327414965987	2.2725	66	199	5	19	15	6	0	0	6	0	0	0.8924935241881213	
i 1	911.2327414965987	2.2725	77	199	6	5	1	17	0	1	17	0	0	2.0307099131190656	
i 1	911.233544217687	2.525	66	901	6	17	4	6	0	0	6	0	0	0.8924935241881213	
i 1	911.233544217687	2.2725	61	199	5	18	12	6	0	1	6	0	0	0.8924935241881213	
i 1	911.2367551020408	2.525	61	585	6	17	13	6	0	0	6	0	0	0.8924935241881213	
i 1	911.2399659863945	0.505	69	199	6	9	1	1	0	0	1	0	0	6.069590434492861	
i 1	911.2431768707482	2.02	75	199	6	1	9	2	0	-2	2	0	0	2.029039167451801	
i 1	911.2447823129252	0.7575000000000001	77	199	7	5	9	16	0	1	16	0	0	2.0307099131190656	
i 1	911.2471904761904	0.7575000000000001	74	901	6	5	8	17	0	2	17	0	0	2.0307099131190656	
i 1	911.2487959183674	2.02	72	585	4	24	14	2	0	-2	2	0	0	3.029039167451801	
i 1	911.2512040816326	2.2725	61	199	5	18	6	6	0	0	6	0	0	0.8924935241881213	
i 1	911.2520068027211	1.01	77	199	6	5	7	16	0	2	16	0	0	2.0307099131190656	
i 1	911.2536122448979	2.525	74	901	6	5	12	17	0	2	17	0	0	2.0307099131190656	
i 1	911.2544149659864	2.2725	61	199	4	27	2	9	0	1	9	0	0	1.7216435423119565	
i 1	911.2560204081633	1.01	72	901	5	1	12	8	0	1	8	0	0	2.029039167451801	
i 1	911.2560204081633	0.505	72	901	6	2	13	1	0	0	1	0	0	7.069590434492861	
i 1	911.2600340136055	2.525	61	901	6	17	5	6	0	1	6	0	0	0.8924935241881213	
i 1	911.2640476190476	1.01	75	199	6	1	12	2	0	-2	2	0	0	2.029039167451801	
i 1	911.2640476190476	1.2625	69	901	6	2	2	1	0	0	1	0	0	7.069590434492861	
i 1	911.264850340136	1.01	77	585	6	5	6	17	0	1	17	0	0	2.0307099131190656	
i 1	911.2680612244898	1.2625	69	199	4	3	3	1	0	-1	1	0	0	7.069590434492861	
i 1	911.2680612244898	2.2725	61	199	4	27	10	9	0	0	9	0	0	1.7216435423119565	
i 1	911.2696666666667	2.2725	66	199	5	19	10	6	0	0	6	0	0	0.8924935241881213	
i 1	911.4963877551021	2.2725	69	585	4	4	11	1	0	0	1	0	0	7.069590434492861	
i 1	911.5068231292518	2.02	69	199	6	9	13	0	0	-1	0	0	0	6.069590434492861	
i 1	912.2327414965987	1.2625	72	199	6	1	6	2	0	-2	2	0	0	2.029039167451801	
i 1	912.235149659864	0.2525	74	199	7	5	11	17	0	2	17	0	0	2.0307099131190656	
i 1	912.2504013605442	0.505	74	585	6	5	6	16	0	2	16	0	0	2.0307099131190656	
i 1	912.2656530612245	1.5150000000000001	72	901	6	1	2	2	0	1	2	0	0	2.029039167451801	
i 1	912.4899659863945	0.2525	77	585	6	5	2	17	0	1	17	0	0	2.0307099131190656	
i 1	912.5012040816326	0.2525	69	199	4	4	1	1	0	0	1	0	0	7.069590434492861	
i 1	912.5020068027211	0.2525	72	901	6	2	10	1	0	0	1	0	0	7.069590434492861	
i 1	912.7576258503401	0.7575000000000001	69	199	4	3	2	1	0	-1	1	0	0	7.069590434492861	
i 1	912.7600340136055	1.01	69	901	6	2	14	1	0	0	1	0	0	7.069590434492861	
i 1	912.985149659864	0.7575000000000001	74	901	6	5	16	17	0	2	17	0	0	2.0307099131190656	
i 1	913.233544217687	0.2525	72	199	5	24	8	2	0	-2	2	0	0	3.029039167451801	
i 1	913.2415714285714	0.505	72	585	6	1	11	2	0	1	2	0	0	2.029039167451801	
i 1	913.2688639455782	0.2525	69	199	6	9	10	1	0	0	1	0	0	6.069590434492861	
i 1	913.4803333333333	0.2525	75	198	6	1	13	8	0	-2	8	0	0	2.029039167451801	
i 1	913.4827414965987	0.2525	61	198	4	27	2	9	0	0	9	0	0	1.7216435423119565	
i 1	913.483544217687	0.2525	74	198	6	5	7	16	0	2	16	0	0	2.0307099131190656	
i 1	913.4843469387755	0.2525	74	1167	6	5	4	16	0	1	16	0	0	2.0307099131190656	
i 1	913.490768707483	0.2525	68	198	1	24	14	0	0	0	0	0	0	4.0	
i 1	913.4915714285714	0.2525	68	1167	3	24	12	0	0	-1	0	0	0	4.0	
i 1	913.4939795918367	0.2525	72	1167	6	1	11	2	0	-2	2	0	0	2.029039167451801	
i 1	913.4963877551021	0.2525	72	1167	5	9	1	0	0	0	0	0	0	6.069590434492861	
i 1	913.5044149659864	0.2525	69	198	4	3	10	1	0	-1	1	0	0	7.069590434492861	
i 1	913.5044149659864	0.2525	61	1167	4	18	5	6	0	1	6	0	0	0.8924935241881213	
i 1	913.5100340136055	0.2525	72	1167	5	9	1	1	0	0	1	0	0	6.069590434492861	
i 1	913.5100340136055	0.2525	61	1167	4	18	12	6	0	1	6	0	0	0.8924935241881213	
i 1	913.5140476190476	0.2525	71	198	1	24	3	0	0	0	0	0	0	4.0	
i 1	913.514850340136	0.2525	66	198	5	19	11	6	0	1	6	0	0	0.8924935241881213	
i 1	913.5188639455782	0.2525	66	198	4	27	2	6	0	1	6	0	0	1.7216435423119565	
i 1	913.5196666666667	0.2525	61	198	5	19	14	6	0	0	6	0	0	0.8924935241881213	
i 1	913.7303333333333	11.8675	69	698	6	2	14	1	0	0	1	0	0	7.069590434492861	
i 1	913.7311360544218	1.7675	75	1084	5	1	13	2	0	-2	2	0	0	2.029039167451801	
i 1	913.7319387755102	65.65	66	698	4	19	8	6	0	1	6	0	0	0.8924935241881213	
i 1	913.733544217687	3.2825	75	698	6	1	16	2	0	1	2	0	0	2.029039167451801	
i 1	913.733544217687	79.285	61	698	3	27	9	9	0	0	9	0	0	1.7216435423119565	
i 1	913.735149659864	2.7775	75	200	6	1	4	2	0	-2	2	0	0	2.029039167451801	
i 1	913.7375578231292	3.535	74	1084	6	5	12	16	0	1	16	0	0	2.0307099131190656	
i 1	913.7383605442177	0.2525	72	698	4	4	14	1	0	-1	1	0	0	7.069590434492861	
i 1	913.740768707483	2.525	71	698	1	24	9	1	0	0	1	0	0	4.0	
i 1	913.7415714285714	17.9275	61	698	6	17	3	6	0	1	6	0	0	0.8924935241881213	
i 1	913.7415714285714	45.1975	61	1084	4	18	4	9	0	0	9	0	0	0.8924935241881213	
i 1	913.7415714285714	58.8325	66	698	4	19	10	6	0	1	6	0	0	0.8924935241881213	
i 1	913.7439795918367	24.745	61	698	6	17	16	9	0	0	9	0	0	0.8924935241881213	
i 1	913.7463877551021	52.015	66	1084	4	18	1	6	0	1	6	0	0	0.8924935241881213	
i 1	913.7463877551021	0.505	74	698	6	5	4	16	0	2	16	0	0	2.0307099131190656	
i 1	913.7479931972789	38.38	61	200	7	17	8	6	0	1	6	0	0	0.8924935241881213	
i 1	913.7504013605442	1.7675	75	698	5	1	15	8	0	1	8	0	0	2.029039167451801	
i 1	913.7504013605442	31.5625	61	200	7	17	13	6	0	1	6	0	0	0.8924935241881213	
i 1	913.7536122448979	0.2525	71	698	1	24	15	0	0	-1	0	0	0	4.0	
i 1	913.7600340136055	86.1025	66	698	3	27	9	6	0	0	6	0	0	1.7216435423119565	
i 1	913.7608367346938	3.7875	74	698	6	5	6	17	0	2	17	0	0	2.0307099131190656	
i 1	913.7632448979592	0.505	72	698	4	3	7	0	0	0	0	0	0	7.069590434492861	
i 1	913.764850340136	0.7575000000000001	77	698	6	5	16	16	0	1	16	0	0	2.0307099131190656	
i 1	913.7680612244898	0.505	72	698	6	1	14	2	0	1	2	0	0	2.029039167451801	
i 1	913.7688639455782	15.655	69	1084	5	9	13	0	0	0	0	0	0	6.069590434492861	
i 1	913.7688639455782	3.7875	68	1084	2	24	3	0	0	-1	0	0	0	4.0	
i 1	913.9891632653062	3.0300000000000002	72	1084	5	9	4	1	0	0	1	0	0	6.069590434492861	
i 1	913.9987959183674	0.2525	71	200	3	24	13	0	0	0	0	0	0	4.0	
i 1	914.2439795918367	0.2525	77	1084	6	5	6	17	0	2	17	0	0	2.0307099131190656	
i 1	914.2455850340136	2.7775	72	698	6	2	5	1	0	0	1	0	0	7.069590434492861	
i 1	914.264850340136	0.505	68	698	1	24	5	1	0	0	1	0	0	4.0	
i 1	914.4963877551021	0.505	74	698	6	5	15	16	0	2	16	0	0	2.0307099131190656	
i 1	914.5028095238096	0.2525	77	200	7	5	5	16	0	1	16	0	0	2.0307099131190656	
i 1	914.7504013605442	0.2525	68	200	3	24	10	1	0	0	1	0	0	4.0	
i 1	914.759231292517	2.2725	77	698	6	5	11	16	0	1	16	0	0	2.0307099131190656	
i 1	914.9947823129252	0.505	71	698	1	24	16	1	0	0	1	0	0	4.0	
i 1	914.9979931972789	2.02	77	1084	6	5	3	17	0	2	17	0	0	2.0307099131190656	
i 1	915.4867551020408	0.2525	71	200	3	24	12	0	0	-1	0	0	0	4.0	
i 1	915.4963877551021	2.525	72	698	6	1	2	2	0	1	2	0	0	2.029039167451801	
i 1	915.5132448979592	2.525	72	1084	5	1	7	2	0	-2	2	0	0	2.029039167451801	
i 1	915.7375578231292	1.2625	71	698	1	24	10	1	0	0	1	0	0	4.0	
i 1	916.2359523809524	2.525	74	698	6	5	4	16	0	2	16	0	0	2.0307099131190656	
i 1	916.2479931972789	1.7675	74	200	7	5	6	17	0	1	17	0	0	2.0307099131190656	
i 1	916.4947823129252	0.505	72	698	4	24	8	2	0	-2	2	0	0	3.029039167451801	
i 1	916.5020068027211	2.02	71	698	1	24	13	1	0	0	1	0	0	4.0	
i 1	916.9995986394558	0.2525	71	200	3	24	6	0	0	0	0	0	0	4.0	
i 1	917.0020068027211	0.2525	69	200	6	3	7	0	0	-1	0	0	0	7.069590434492861	
i 1	917.0052176870748	2.02	75	1084	5	1	6	2	0	-2	2	0	0	2.029039167451801	
i 1	917.009231292517	0.2525	72	698	4	3	7	0	0	0	0	0	0	7.069590434492861	
i 1	917.0180612244898	2.02	75	698	5	1	9	8	0	1	8	0	0	2.029039167451801	
i 1	917.2495986394558	0.2525	74	698	6	5	13	16	0	2	16	0	0	2.0307099131190656	
i 1	917.2504013605442	1.7675	72	698	4	4	6	1	0	-1	1	0	0	7.069590434492861	
i 1	917.2536122448979	0.7575000000000001	72	200	5	4	12	1	0	-1	1	0	0	7.069590434492861	
i 1	917.4939795918367	2.7775	77	698	6	5	7	16	0	1	16	0	0	2.0307099131190656	
i 1	917.5036122448979	2.525	77	1084	6	5	3	17	0	2	17	0	0	2.0307099131190656	
i 1	917.7303333333333	2.525	68	1084	2	24	8	0	0	-1	0	0	0	4.0	
i 1	917.9883605442177	0.2525	71	200	3	24	11	0	0	-1	0	0	0	4.0	
i 1	917.9995986394558	0.505	74	200	6	5	6	17	0	1	17	0	0	2.0307099131190656	
i 1	918.0004013605442	3.7875	72	698	4	24	8	2	0	-2	2	0	0	3.029039167451801	
i 1	918.0188639455782	3.7875	75	200	5	24	1	2	0	-2	2	0	0	3.029039167451801	
i 1	918.0188639455782	1.01	72	200	5	4	5	1	0	-1	1	0	0	7.069590434492861	
i 1	918.2343469387755	2.525	68	698	1	24	8	1	0	-1	1	0	0	4.0	
i 1	918.4915714285714	0.2525	77	200	7	5	12	16	0	1	16	0	0	2.0307099131190656	
i 1	918.7303333333333	2.525	74	200	6	5	6	17	0	1	17	0	0	2.0307099131190656	
i 1	918.7624421768708	0.2525	74	1084	6	5	14	16	0	1	16	0	0	2.0307099131190656	
i 1	918.9891632653062	1.7675	69	200	6	3	2	0	0	-1	0	0	0	7.069590434492861	
i 1	918.9899659863945	2.2725	74	698	6	5	15	16	0	2	16	0	0	2.0307099131190656	
i 1	918.990768707483	0.2525	72	1084	5	1	15	2	0	-2	2	0	0	2.029039167451801	
i 1	919.0028095238096	0.2525	72	698	5	1	2	2	0	1	2	0	0	2.029039167451801	
i 1	919.0076258503401	1.7675	72	698	4	3	9	0	0	0	0	0	0	7.069590434492861	
i 1	919.233544217687	0.2525	75	698	4	1	2	2	0	1	2	0	0	2.029039167451801	
i 1	919.2544149659864	0.2525	75	200	6	1	12	2	0	-2	2	0	0	2.029039167451801	
i 1	919.4875578231292	1.5150000000000001	72	1084	5	1	11	2	0	-2	2	0	0	2.029039167451801	
i 1	919.4995986394558	1.5150000000000001	72	698	5	1	3	2	0	1	2	0	0	2.029039167451801	
i 1	919.9939795918367	3.7875	72	698	6	2	12	1	0	0	1	0	0	7.069590434492861	
i 1	919.9995986394558	3.7875	72	1084	5	9	2	1	0	0	1	0	0	6.069590434492861	
i 1	920.0100340136055	0.2525	77	200	7	5	4	16	0	1	16	0	0	2.0307099131190656	
i 1	920.2383605442177	2.7775	71	698	1	24	9	1	0	0	1	0	0	4.0	
i 1	920.2528095238096	2.2725	74	698	6	5	5	17	0	2	17	0	0	2.0307099131190656	
i 1	920.2568231292518	2.2725	74	1084	6	5	12	16	0	1	16	0	0	2.0307099131190656	
i 1	920.5052176870748	3.535	68	1084	2	24	14	0	0	-1	0	0	0	4.0	
i 1	920.7311360544218	2.2725	75	698	4	1	16	2	0	1	2	0	0	2.029039167451801	
i 1	920.7479931972789	2.02	75	200	6	1	12	2	0	-2	2	0	0	2.029039167451801	
i 1	920.7520068027211	0.2525	71	200	3	24	14	0	0	-1	0	0	0	4.0	
i 1	921.0060204081633	0.2525	68	698	1	24	15	0	0	0	0	0	0	4.0	
i 1	921.2463877551021	2.525	77	1084	6	5	10	17	0	2	17	0	0	2.0307099131190656	
i 1	921.2512040816326	2.525	77	698	6	5	5	16	0	1	16	0	0	2.0307099131190656	
i 1	921.7327414965987	2.525	75	1084	5	1	11	2	0	-2	2	0	0	2.029039167451801	
i 1	921.7455850340136	2.525	75	698	5	1	9	8	0	1	8	0	0	2.029039167451801	
i 1	922.4811360544218	0.2525	74	698	6	5	8	16	0	2	16	0	0	2.0307099131190656	
i 1	922.5172585034013	0.2525	74	200	6	5	2	17	0	1	17	0	0	2.0307099131190656	
i 1	922.7471904761904	2.02	74	698	6	5	5	17	0	2	17	0	0	2.0307099131190656	
i 1	922.7528095238096	2.02	74	1084	6	5	4	16	0	1	16	0	0	2.0307099131190656	
i 1	922.7600340136055	0.505	72	698	5	1	5	2	0	1	2	0	0	2.029039167451801	
i 1	922.9971904761904	0.2525	72	698	4	24	8	2	0	-2	2	0	0	3.029039167451801	
i 1	923.2311360544218	2.7775	71	698	1	24	5	1	0	0	1	0	0	4.0	
i 1	923.2463877551021	1.5150000000000001	75	200	6	1	12	2	0	-2	2	0	0	2.029039167451801	
i 1	923.2504013605442	2.02	75	698	4	1	14	2	0	1	2	0	0	2.029039167451801	
i 1	923.740768707483	1.5150000000000001	74	698	6	5	11	16	0	2	16	0	0	2.0307099131190656	
i 1	923.7431768707482	1.7675	72	698	4	4	15	1	0	-1	1	0	0	7.069590434492861	
i 1	923.7479931972789	1.01	68	698	1	24	13	0	0	0	0	0	0	4.0	
i 1	923.7495986394558	1.5150000000000001	74	200	6	5	15	17	0	1	17	0	0	2.0307099131190656	
i 1	923.7560204081633	2.02	72	200	5	4	15	1	0	-1	1	0	0	7.069590434492861	
i 1	924.2303333333333	0.505	77	1084	6	5	13	17	0	2	17	0	0	2.0307099131190656	
i 1	924.2552176870748	2.2725	72	698	5	1	12	2	0	1	2	0	0	2.029039167451801	
i 1	924.2552176870748	3.2825	77	698	6	5	3	16	0	1	16	0	0	2.0307099131190656	
i 1	924.2616394557823	2.2725	72	1084	5	1	15	2	0	-2	2	0	0	2.029039167451801	
i 1	924.4867551020408	1.5150000000000001	68	1084	2	24	1	0	0	-1	0	0	0	4.0	
i 1	924.7383605442177	0.2525	71	200	2	24	7	0	0	-1	0	0	0	4.0	
i 1	924.7415714285714	0.7575000000000001	75	200	5	1	16	2	0	-2	2	0	0	2.029039167451801	
i 1	924.7552176870748	2.7775	77	1084	6	5	10	17	0	2	17	0	0	2.0307099131190656	
i 1	924.7640476190476	2.02	69	200	6	3	2	0	0	-1	0	0	0	7.069590434492861	
i 1	924.7640476190476	1.7675	72	698	4	3	4	0	0	0	0	0	0	7.069590434492861	
i 1	925.2391632653062	2.02	75	1084	5	1	14	2	0	-2	2	0	0	2.029039167451801	
i 1	925.2471904761904	0.505	74	698	6	5	1	16	0	2	16	0	0	2.0307099131190656	
i 1	925.2576258503401	0.2525	74	698	6	5	13	17	0	2	17	0	0	2.0307099131190656	
i 1	925.4979931972789	0.2525	68	200	2	24	11	1	0	-1	1	0	0	4.0	
i 1	925.4987959183674	0.2525	72	698	4	24	1	2	0	-2	2	0	0	3.029039167451801	
i 1	925.7303333333333	0.7575000000000001	77	200	6	5	11	16	0	1	16	0	0	2.0307099131190656	
i 1	925.7439795918367	3.535	69	698	6	2	6	1	0	0	1	0	0	7.069590434492861	
i 1	925.7536122448979	0.2525	74	1084	6	5	9	16	0	1	16	0	0	2.0307099131190656	
i 1	925.7568231292518	1.5150000000000001	75	698	5	1	6	8	0	1	8	0	0	2.029039167451801	
i 1	925.983544217687	0.2525	74	698	6	5	2	16	0	2	16	0	0	2.0307099131190656	
i 1	926.4827414965987	1.2625	72	698	4	24	6	2	0	-2	2	0	0	3.029039167451801	
i 1	926.483544217687	0.2525	72	200	5	4	12	1	0	-1	1	0	0	7.069590434492861	
i 1	926.4843469387755	1.2625	75	200	5	24	14	2	0	-2	2	0	0	3.029039167451801	
i 1	926.4899659863945	1.01	74	698	6	5	13	16	0	2	16	0	0	2.0307099131190656	
i 1	926.5044149659864	1.01	74	200	6	5	14	17	0	1	17	0	0	2.0307099131190656	
i 1	926.7375578231292	1.7675	72	698	6	2	9	1	0	0	1	0	0	7.069590434492861	
i 1	926.7455850340136	1.7675	72	1084	5	9	10	1	0	0	1	0	0	6.069590434492861	
i 1	926.7608367346938	1.2625	71	698	1	24	9	1	0	0	1	0	0	4.0	
i 1	926.9827414965987	2.02	72	698	5	1	2	2	0	1	2	0	0	2.029039167451801	
i 1	926.9931768707482	4.2925	74	1084	6	5	10	16	0	1	16	0	0	2.0307099131190656	
i 1	927.0028095238096	2.02	72	1084	5	1	15	2	0	-2	2	0	0	2.029039167451801	
i 1	927.0052176870748	4.2925	74	698	6	5	15	17	0	2	17	0	0	2.0307099131190656	
i 1	927.4811360544218	0.2525	77	200	6	5	10	16	0	1	16	0	0	2.0307099131190656	
i 1	927.516455782313	2.02	68	1084	2	24	10	0	0	-1	0	0	0	4.0	
i 1	927.7383605442177	1.01	74	698	6	5	7	16	0	2	16	0	0	2.0307099131190656	
i 1	927.7672585034013	0.2525	75	200	5	1	4	2	0	-2	2	0	0	2.029039167451801	
i 1	928.0012040816326	0.2525	75	698	4	1	3	2	0	1	2	0	0	2.029039167451801	
i 1	928.2391632653062	1.7675	75	200	5	24	8	2	0	-2	2	0	0	3.029039167451801	
i 1	928.2568231292518	0.7575000000000001	71	698	1	24	10	1	0	0	1	0	0	4.0	
i 1	928.2656530612245	1.7675	72	698	4	24	7	2	0	-2	2	0	0	3.029039167451801	
i 1	928.4843469387755	0.2525	72	698	4	3	13	0	0	0	0	0	0	7.069590434492861	
i 1	928.5196666666667	0.2525	74	200	6	5	15	17	0	1	17	0	0	2.0307099131190656	
i 1	928.7327414965987	0.505	77	200	6	5	8	16	0	1	16	0	0	2.0307099131190656	
i 1	928.7495986394558	1.2625	72	698	6	2	10	1	0	0	1	0	0	7.069590434492861	
i 1	928.7680612244898	1.2625	72	1084	5	9	10	1	0	0	1	0	0	6.069590434492861	
i 1	928.9987959183674	0.505	71	200	2	24	16	1	0	0	1	0	0	4.0	
i 1	929.0036122448979	0.7575000000000001	75	1084	5	1	7	2	0	-2	2	0	0	2.029039167451801	
i 1	929.2584285714286	1.01	77	1084	6	5	11	17	0	2	17	0	0	2.0307099131190656	
i 1	929.4931768707482	0.7575000000000001	77	698	6	5	10	16	0	1	16	0	0	2.0307099131190656	
i 1	929.509231292517	0.7575000000000001	69	1084	5	9	10	0	0	0	0	0	0	6.069590434492861	
i 1	929.5124421768708	0.7575000000000001	69	698	6	2	11	1	0	0	1	0	0	7.069590434492861	
i 1	929.7487959183674	1.2625	72	200	5	4	6	1	0	-1	1	0	0	7.069590434492861	
i 1	929.7520068027211	1.2625	72	698	4	4	4	1	0	-1	1	0	0	7.069590434492861	
i 1	929.7544149659864	1.2625	75	698	4	1	7	2	0	1	2	0	0	2.029039167451801	
i 1	929.7560204081633	1.2625	75	200	5	1	12	2	0	-2	2	0	0	2.029039167451801	
i 1	930.2367551020408	0.7575000000000001	74	698	6	5	15	16	0	2	16	0	0	2.0307099131190656	
i 1	930.240768707483	0.505	71	698	1	24	9	1	0	0	1	0	0	4.0	
i 1	930.4915714285714	0.2525	71	200	2	24	4	1	0	0	1	0	0	4.0	
i 1	930.7359523809524	1.2625	69	698	6	2	10	1	0	0	1	0	0	7.069590434492861	
i 1	930.7600340136055	0.7575000000000001	69	1084	5	9	3	0	0	0	0	0	0	6.069590434492861	
i 1	930.985149659864	1.5150000000000001	75	1084	5	1	12	2	0	-2	2	0	0	2.029039167451801	
i 1	931.016455782313	1.5150000000000001	75	698	5	1	11	8	0	1	8	0	0	2.029039167451801	
i 1	931.2303333333333	0.7575000000000001	71	698	1	24	14	1	0	0	1	0	0	4.0	
i 1	931.235149659864	1.01	74	200	6	5	12	17	0	1	17	0	0	2.0307099131190656	
i 1	931.2367551020408	0.505	72	698	5	1	6	2	0	1	2	0	0	2.029039167451801	
i 1	931.264850340136	0.2525	68	1084	2	24	1	0	0	-1	0	0	0	4.0	
i 1	931.2656530612245	0.2525	74	698	6	5	11	16	0	2	16	0	0	2.0307099131190656	
i 1	931.4803333333333	0.505	69	1084	5	9	8	0	0	0	0	0	0	6.069590434492861	
i 1	931.4979931972789	0.2525	72	698	6	2	12	1	0	0	1	0	0	7.069590434492861	
i 1	931.4979931972789	0.505	68	1084	1	24	8	0	0	-1	0	0	0	4.0	
i 1	931.5012040816326	13.635	61	698	5	17	4	6	0	1	6	0	0	0.8924935241881213	
i 1	931.5124421768708	0.2525	77	698	6	5	9	16	0	1	16	0	0	2.0307099131190656	
i 1	931.5180612244898	0.505	68	200	2	24	10	1	0	-1	1	0	0	4.0	
i 1	931.5188639455782	0.7575000000000001	74	698	5	5	14	16	0	2	16	0	0	2.0307099131190656	
i 1	931.7327414965987	1.01	72	698	4	3	7	0	0	0	0	0	0	7.069590434492861	
i 1	931.7487959183674	0.2525	77	200	6	5	4	16	0	1	16	0	0	2.0307099131190656	
i 1	931.7512040816326	1.01	69	200	6	3	3	0	0	-1	0	0	0	7.069590434492861	
i 1	932.2303333333333	1.5150000000000001	77	1084	6	5	1	17	0	2	17	0	0	2.0307099131190656	
i 1	932.2415714285714	1.5150000000000001	77	698	6	5	11	16	0	1	16	0	0	2.0307099131190656	
i 1	932.4843469387755	0.505	75	698	4	1	12	2	0	1	2	0	0	2.029039167451801	
i 1	932.5004013605442	0.505	75	200	5	1	6	2	0	-2	2	0	0	2.029039167451801	
i 1	932.7399659863945	1.01	69	698	6	2	12	1	0	0	1	0	0	7.069590434492861	
i 1	932.7512040816326	1.01	69	1084	5	9	4	0	0	0	0	0	0	6.069590434492861	
i 1	932.7640476190476	0.505	71	698	1	24	11	1	0	0	1	0	0	4.0	
i 1	933.0020068027211	0.7575000000000001	72	1084	5	1	13	2	0	-2	2	0	0	2.029039167451801	
i 1	933.0068231292518	0.7575000000000001	72	698	5	1	3	2	0	1	2	0	0	2.029039167451801	
i 1	933.4811360544218	0.505	71	698	1	24	2	1	0	0	1	0	0	4.0	
i 1	933.485149659864	1.2625	68	1084	1	24	7	0	0	-1	0	0	0	4.0	
i 1	933.7391632653062	1.01	75	1084	5	1	1	2	0	-2	2	0	0	2.029039167451801	
i 1	933.7415714285714	1.01	74	698	5	5	9	16	0	2	16	0	0	2.0307099131190656	
i 1	933.7431768707482	0.7575000000000001	72	698	6	2	15	1	0	0	1	0	0	7.069590434492861	
i 1	933.7495986394558	1.01	75	698	5	1	11	8	0	1	8	0	0	2.029039167451801	
i 1	933.764850340136	1.01	74	200	6	5	13	17	0	1	17	0	0	2.0307099131190656	
i 1	933.7696666666667	0.7575000000000001	72	1084	5	9	3	1	0	0	1	0	0	6.069590434492861	
i 1	933.9859523809524	0.2525	71	200	2	24	8	0	0	-1	0	0	0	4.0	
i 1	934.4867551020408	0.2525	69	698	6	2	8	1	0	0	1	0	0	7.069590434492861	
i 1	934.5076258503401	0.2525	69	1084	5	9	10	0	0	0	0	0	0	6.069590434492861	
i 1	934.735149659864	1.7675	74	698	6	5	8	17	0	2	17	0	0	2.0307099131190656	
i 1	934.7423741496599	1.7675	74	1084	5	5	16	16	0	1	16	0	0	2.0307099131190656	
i 1	934.7431768707482	1.5150000000000001	72	698	4	24	4	2	0	-2	2	0	0	3.029039167451801	
i 1	934.7447823129252	0.7575000000000001	72	698	6	2	13	1	0	0	1	0	0	7.069590434492861	
i 1	934.7624421768708	0.7575000000000001	72	1084	5	9	4	1	0	0	1	0	0	6.069590434492861	
i 1	934.7640476190476	1.5150000000000001	75	200	5	24	9	2	0	-2	2	0	0	3.029039167451801	
i 1	934.9883605442177	0.505	71	698	1	24	12	1	0	0	1	0	0	4.0	
i 1	935.0124421768708	1.2625	68	1084	1	24	14	0	0	-1	0	0	0	4.0	
i 1	935.4891632653062	1.2625	69	698	6	2	14	1	0	0	1	0	0	7.069590434492861	
i 1	935.5028095238096	0.2525	68	200	2	24	5	0	0	0	0	0	0	4.0	
i 1	935.5044149659864	1.2625	69	1084	5	9	1	0	0	0	0	0	0	6.069590434492861	
i 1	936.2632448979592	1.01	72	698	5	1	14	2	0	1	2	0	0	2.029039167451801	
i 1	936.2656530612245	1.01	72	1084	5	1	1	2	0	-2	2	0	0	2.029039167451801	
i 1	936.490768707483	1.2625	68	1084	1	24	15	0	0	-1	0	0	0	4.0	
i 1	936.509231292517	1.01	77	698	6	5	5	16	0	1	16	0	0	2.0307099131190656	
i 1	936.5108367346938	1.2625	71	698	1	24	5	1	0	0	1	0	0	4.0	
i 1	936.5188639455782	1.01	77	1084	6	5	6	17	0	2	17	0	0	2.0307099131190656	
i 1	936.7439795918367	0.7575000000000001	72	698	4	4	9	1	0	-1	1	0	0	7.069590434492861	
i 1	936.7520068027211	0.7575000000000001	72	200	5	4	11	1	0	-1	1	0	0	7.069590434492861	
i 1	937.2391632653062	1.5150000000000001	72	698	4	24	9	2	0	-2	2	0	0	3.029039167451801	
i 1	937.2672585034013	1.5150000000000001	75	200	5	24	15	2	0	-2	2	0	0	3.029039167451801	
i 1	937.4915714285714	1.01	69	698	6	2	4	1	0	0	1	0	0	7.069590434492861	
i 1	937.4971904761904	0.2525	74	1084	5	5	8	16	0	1	16	0	0	2.0307099131190656	
i 1	937.509231292517	0.2525	74	698	6	5	11	17	0	2	17	0	0	2.0307099131190656	
i 1	937.5180612244898	1.01	69	1084	5	9	14	0	0	0	0	0	0	6.069590434492861	
i 1	937.7520068027211	1.2625	74	698	5	5	14	16	0	2	16	0	0	2.0307099131190656	
i 1	937.7640476190476	1.2625	74	200	6	5	15	17	0	1	17	0	0	2.0307099131190656	
i 1	938.2471904761904	13.635	61	698	5	17	8	9	0	0	9	0	0	0.8924935241881213	
i 1	938.259231292517	27.27	66	698	5	14	8	9	0	0	9	0	0	2.3536679069160917	
i 1	938.4947823129252	0.7575000000000001	69	200	6	3	2	0	0	-1	0	0	0	7.069590434492861	
i 1	938.4995986394558	0.7575000000000001	72	698	5	3	8	0	0	0	0	0	0	7.069590434492861	
i 1	938.5020068027211	0.505	71	698	1	24	8	1	0	0	1	0	0	4.0	
i 1	938.7463877551021	0.505	75	200	5	1	10	2	0	-2	2	0	0	2.029039167451801	
i 1	938.7568231292518	0.505	75	698	4	1	6	2	0	1	2	0	0	2.029039167451801	
i 1	938.9891632653062	1.5150000000000001	77	698	6	5	15	16	0	1	16	0	0	2.0307099131190656	
i 1	939.0140476190476	1.5150000000000001	77	1084	5	5	2	17	0	2	17	0	0	2.0307099131190656	
i 1	939.2616394557823	0.7575000000000001	75	1084	4	1	14	2	0	-2	2	0	0	2.029039167451801	
i 1	939.2624421768708	0.2525	69	698	6	2	16	1	0	0	1	0	0	7.069590434492861	
i 1	939.264850340136	0.7575000000000001	75	698	6	1	13	8	0	1	8	0	0	2.029039167451801	
i 1	939.266455782313	0.2525	69	1084	5	9	6	0	0	0	0	0	0	6.069590434492861	
i 1	939.4819387755102	1.01	72	1084	5	9	1	1	0	0	1	0	0	6.069590434492861	
i 1	939.4915714285714	0.505	68	1084	1	24	5	0	0	-1	0	0	0	4.0	
i 1	939.514850340136	0.7575000000000001	72	698	6	2	12	1	0	0	1	0	0	7.069590434492861	
i 1	939.7536122448979	1.2625	75	698	4	1	4	2	0	1	2	0	0	2.029039167451801	
i 1	939.7584285714286	1.2625	75	200	5	1	7	2	0	-2	2	0	0	2.029039167451801	
i 1	940.0020068027211	0.2525	72	1084	5	1	13	2	0	-2	2	0	0	2.029039167451801	
i 1	940.2383605442177	1.2625	69	1084	5	9	12	0	0	0	0	0	0	6.069590434492861	
i 1	940.2520068027211	0.505	71	698	1	24	16	1	0	0	1	0	0	4.0	
i 1	940.2568231292518	1.2625	69	698	6	2	1	1	0	0	1	0	0	7.069590434492861	
i 1	940.2632448979592	0.505	68	1084	1	24	11	0	0	-1	0	0	0	4.0	
i 1	940.4971904761904	0.2525	74	698	6	5	10	17	0	2	17	0	0	2.0307099131190656	
i 1	940.5052176870748	1.2625	74	698	5	5	5	16	0	2	16	0	0	2.0307099131190656	
i 1	940.5060204081633	1.2625	74	200	6	5	2	17	0	1	17	0	0	2.0307099131190656	
i 1	940.985149659864	1.5150000000000001	72	698	5	1	5	2	0	1	2	0	0	2.029039167451801	
i 1	941.0004013605442	1.5150000000000001	72	1084	5	1	6	2	0	-2	2	0	0	2.029039167451801	
i 1	941.0060204081633	0.505	68	1084	1	24	14	0	0	-1	0	0	0	4.0	
i 1	941.2303333333333	0.2525	77	200	6	5	13	16	0	1	16	0	0	2.0307099131190656	
i 1	941.490768707483	0.2525	72	698	5	3	4	0	0	0	0	0	0	7.069590434492861	
i 1	941.4979931972789	0.2525	75	1084	4	1	5	2	0	-2	2	0	0	2.029039167451801	
i 1	941.4987959183674	0.7575000000000001	72	698	6	2	3	1	0	0	1	0	0	7.069590434492861	
i 1	941.5076258503401	0.7575000000000001	72	1084	5	9	3	1	0	0	1	0	0	6.069590434492861	
i 1	941.7375578231292	1.2625	74	698	6	5	13	17	0	2	17	0	0	2.0307099131190656	
i 1	941.7512040816326	0.2525	72	698	4	4	7	1	0	-1	1	0	0	7.069590434492861	
i 1	941.7680612244898	1.2625	74	1084	5	5	6	16	0	1	16	0	0	2.0307099131190656	
i 1	941.9923741496599	2.02	71	698	1	24	4	1	0	0	1	0	0	4.0	
i 1	942.0052176870748	0.2525	68	200	2	24	16	0	0	-1	0	0	0	4.0	
i 1	942.0076258503401	2.02	68	1084	1	24	10	0	0	-1	0	0	0	4.0	
i 1	942.0188639455782	1.2625	69	1084	5	9	9	0	0	0	0	0	0	6.069590434492861	
i 1	942.2552176870748	1.01	69	698	6	2	7	1	0	0	1	0	0	7.069590434492861	
i 1	942.4803333333333	1.01	75	1084	4	1	14	2	0	-2	2	0	0	2.029039167451801	
i 1	942.5076258503401	1.01	75	698	6	1	6	8	0	1	8	0	0	2.029039167451801	
i 1	942.7600340136055	0.2525	72	698	5	3	16	0	0	0	0	0	0	7.069590434492861	
i 1	943.0132448979592	1.5150000000000001	77	1084	5	5	4	17	0	2	17	0	0	2.0307099131190656	
i 1	943.0188639455782	1.5150000000000001	77	698	6	5	2	16	0	1	16	0	0	2.0307099131190656	
i 1	943.2415714285714	0.2525	75	698	4	1	11	2	0	1	2	0	0	2.029039167451801	
i 1	943.2632448979592	0.7575000000000001	72	698	4	4	11	1	0	-1	1	0	0	7.069590434492861	
i 1	943.2640476190476	0.7575000000000001	72	200	5	4	3	1	0	-1	1	0	0	7.069590434492861	
i 1	943.4827414965987	1.5150000000000001	72	698	4	24	9	2	0	-2	2	0	0	3.029039167451801	
i 1	943.4931768707482	0.2525	72	1084	5	9	4	1	0	0	1	0	0	6.069590434492861	
i 1	943.5116394557823	1.5150000000000001	75	200	5	24	2	2	0	-2	2	0	0	3.029039167451801	
i 1	943.7528095238096	0.505	69	1084	5	9	2	0	0	0	0	0	0	6.069590434492861	
i 1	943.766455782313	0.505	69	698	6	2	9	1	0	0	1	0	0	7.069590434492861	
i 1	943.9979931972789	1.01	74	698	6	5	6	17	0	2	17	0	0	2.0307099131190656	
i 1	944.0100340136055	1.2625	74	1084	5	5	14	16	0	1	16	0	0	2.0307099131190656	
i 1	944.0156530612245	0.2525	75	1084	4	1	7	2	0	-2	2	0	0	2.029039167451801	
i 1	944.2391632653062	1.01	72	698	5	3	15	0	0	0	0	0	0	7.069590434492861	
i 1	944.240768707483	1.01	69	200	6	3	6	0	0	-1	0	0	0	7.069590434492861	
i 1	944.2552176870748	0.505	68	1084	1	24	16	0	0	-1	0	0	0	4.0	
i 1	944.5108367346938	0.2525	74	200	6	5	14	17	0	1	17	0	0	2.0307099131190656	
i 1	944.5116394557823	0.2525	71	698	1	24	3	1	0	0	1	0	0	4.0	
i 1	944.759231292517	0.2525	75	1084	4	1	8	2	0	-2	2	0	0	2.029039167451801	
i 1	944.9819387755102	1.5150000000000001	69	1084	5	9	10	0	0	0	0	0	0	6.069590434492861	
i 1	944.9859523809524	0.2525	68	698	2	24	5	0	0	-1	0	0	0	4.0	
i 1	944.9891632653062	0.2525	74	698	4	5	6	17	0	2	17	0	0	2.0307099131190656	
i 1	944.9971904761904	0.505	72	698	6	1	1	2	0	1	2	0	0	2.029039167451801	
i 1	945.009231292517	1.5150000000000001	69	698	6	2	15	1	0	0	1	0	0	7.069590434492861	
i 1	945.0172585034013	0.505	72	1084	4	1	1	2	0	-2	2	0	0	2.029039167451801	
i 1	945.0196666666667	13.635	61	200	5	17	4	6	0	1	6	0	0	0.8924935241881213	
i 1	945.2327414965987	0.2525	68	1084	1	24	14	0	0	-1	0	0	0	4.0	
i 1	945.2455850340136	0.505	74	200	6	5	1	17	0	1	17	0	0	2.0307099131190656	
i 1	945.2576258503401	0.2525	71	200	4	24	5	0	0	0	0	0	0	4.0	
i 1	945.2608367346938	0.505	74	698	4	5	13	16	0	2	16	0	0	2.0307099131190656	
i 1	945.483544217687	0.2525	72	698	5	3	4	0	0	0	0	0	0	7.069590434492861	
i 1	945.4883605442177	0.7575000000000001	72	698	4	24	3	2	0	-2	2	0	0	3.029039167451801	
i 1	945.5124421768708	1.01	75	200	5	24	12	2	0	-2	2	0	0	3.029039167451801	
i 1	945.7303333333333	2.2725	77	1084	5	5	11	17	0	2	17	0	0	2.0307099131190656	
i 1	945.759231292517	2.2725	77	698	6	5	7	16	0	1	16	0	0	2.0307099131190656	
i 1	945.9955850340136	0.2525	68	1084	1	24	11	0	0	-1	0	0	0	4.0	
i 1	946.0156530612245	0.505	74	698	4	5	15	16	0	2	16	0	0	2.0307099131190656	
i 1	946.2343469387755	1.01	75	698	4	1	6	2	0	1	2	0	0	2.029039167451801	
i 1	946.2560204081633	1.01	75	200	5	1	10	2	0	-2	2	0	0	2.029039167451801	
i 1	946.259231292517	0.7575000000000001	72	1084	5	9	9	1	0	0	1	0	0	6.069590434492861	
i 1	946.2672585034013	0.7575000000000001	72	698	6	2	12	1	0	0	1	0	0	7.069590434492861	
i 1	946.7423741496599	0.2525	72	698	6	1	14	2	0	1	2	0	0	2.029039167451801	
i 1	946.7431768707482	2.02	68	1084	1	24	9	0	0	-1	0	0	0	4.0	
i 1	946.7560204081633	1.2625	69	1084	5	9	2	0	0	0	0	0	0	6.069590434492861	
i 1	946.7640476190476	1.2625	69	698	6	2	11	1	0	0	1	0	0	7.069590434492861	
i 1	946.766455782313	0.2525	74	200	6	5	16	17	0	1	17	0	0	2.0307099131190656	
i 1	947.2391632653062	1.5150000000000001	75	698	6	1	11	8	0	1	8	0	0	2.029039167451801	
i 1	947.2544149659864	1.5150000000000001	75	1084	4	1	1	2	0	-2	2	0	0	2.029039167451801	
i 1	947.2656530612245	0.2525	77	200	6	5	10	16	0	1	16	0	0	2.0307099131190656	
i 1	947.5012040816326	0.505	72	1084	4	1	4	2	0	-2	2	0	0	2.029039167451801	
i 1	947.7544149659864	1.2625	72	1084	5	9	1	1	0	0	1	0	0	6.069590434492861	
i 1	947.7584285714286	1.2625	72	698	6	2	3	1	0	0	1	0	0	7.069590434492861	
i 1	948.0116394557823	0.2525	74	698	4	5	16	16	0	2	16	0	0	2.0307099131190656	
i 1	948.014850340136	0.2525	74	200	6	5	11	17	0	1	17	0	0	2.0307099131190656	
i 1	948.2479931972789	2.2725	74	1084	5	5	3	16	0	1	16	0	0	2.0307099131190656	
i 1	948.2512040816326	0.2525	75	698	4	1	8	2	0	1	2	0	0	2.029039167451801	
i 1	948.2656530612245	2.2725	74	698	4	5	4	17	0	2	17	0	0	2.0307099131190656	
i 1	948.4979931972789	0.2525	75	200	5	24	15	2	0	-2	2	0	0	3.029039167451801	
i 1	948.5012040816326	0.7575000000000001	69	698	6	2	10	1	0	0	1	0	0	7.069590434492861	
i 1	948.5028095238096	0.2525	74	698	4	5	4	16	0	2	16	0	0	2.0307099131190656	
i 1	948.509231292517	0.7575000000000001	69	1084	5	9	2	0	0	0	0	0	0	6.069590434492861	
i 1	948.7576258503401	1.01	72	698	4	4	15	1	0	-1	1	0	0	7.069590434492861	
i 1	948.7632448979592	1.01	75	698	4	1	8	2	0	1	2	0	0	2.029039167451801	
i 1	948.7688639455782	1.01	75	200	5	1	15	2	0	-2	2	0	0	2.029039167451801	
i 1	948.7696666666667	1.01	72	200	5	4	15	1	0	-1	1	0	0	7.069590434492861	
i 1	949.0036122448979	0.505	77	200	6	5	9	16	0	1	16	0	0	2.0307099131190656	
i 1	949.0140476190476	2.525	68	1084	1	24	10	0	0	-1	0	0	0	4.0	
i 1	949.2487959183674	0.2525	75	698	6	1	7	8	0	1	8	0	0	2.029039167451801	
i 1	949.4827414965987	1.5150000000000001	69	1084	5	9	13	0	0	0	0	0	0	6.069590434492861	
i 1	949.5004013605442	0.2525	72	698	4	24	3	2	0	-2	2	0	0	3.029039167451801	
i 1	949.5180612244898	1.5150000000000001	69	698	6	2	12	1	0	0	1	0	0	7.069590434492861	
i 1	949.7415714285714	1.5150000000000001	72	1084	4	1	11	2	0	-2	2	0	0	2.029039167451801	
i 1	949.7431768707482	0.2525	74	698	5	5	7	16	0	2	16	0	0	2.0307099131190656	
i 1	949.7479931972789	1.5150000000000001	72	698	6	1	3	2	0	1	2	0	0	2.029039167451801	
i 1	949.9947823129252	0.2525	75	698	4	1	15	2	0	1	2	0	0	2.029039167451801	
i 1	950.2439795918367	0.2525	72	1084	5	9	13	1	0	0	1	0	0	6.069590434492861	
i 1	950.2568231292518	0.7575000000000001	77	698	6	5	12	16	0	1	16	0	0	2.0307099131190656	
i 1	950.266455782313	0.7575000000000001	77	1084	5	5	4	17	0	2	17	0	0	2.0307099131190656	
i 1	950.5036122448979	0.2525	74	698	5	5	11	16	0	2	16	0	0	2.0307099131190656	
i 1	950.5052176870748	0.2525	75	698	6	1	6	8	0	1	8	0	0	2.029039167451801	
i 1	950.5172585034013	0.2525	69	200	6	3	11	0	0	-1	0	0	0	7.069590434492861	
i 1	950.7367551020408	0.505	72	1084	5	9	9	1	0	0	1	0	0	6.069590434492861	
i 1	950.9875578231292	1.01	69	200	6	3	5	0	0	-1	0	0	0	7.069590434492861	
i 1	950.9899659863945	0.2525	74	698	5	5	6	16	0	2	16	0	0	2.0307099131190656	
i 1	951.0060204081633	1.7675	74	698	4	5	3	17	0	2	17	0	0	2.0307099131190656	
i 1	951.0116394557823	1.01	72	698	5	3	16	0	0	0	0	0	0	7.069590434492861	
i 1	951.0196666666667	1.5150000000000001	74	1084	5	5	2	16	0	1	16	0	0	2.0307099131190656	
i 1	951.2319387755102	0.505	75	1084	4	1	11	2	0	-2	2	0	0	2.029039167451801	
i 1	951.2359523809524	0.2525	77	698	6	5	13	16	0	1	16	0	0	2.0307099131190656	
i 1	951.2391632653062	0.505	75	698	6	1	14	8	0	1	8	0	0	2.029039167451801	
i 1	951.2471904761904	0.2525	72	698	6	2	14	1	0	0	1	0	0	7.069590434492861	
i 1	951.2560204081633	1.5150000000000001	72	698	4	24	6	2	0	-2	2	0	0	3.029039167451801	
i 1	951.509231292517	1.2625	75	200	5	24	14	2	0	-2	2	0	0	3.029039167451801	
i 1	951.5140476190476	1.5150000000000001	69	1084	5	9	4	0	0	0	0	0	0	6.069590434492861	
i 1	951.5156530612245	0.2525	69	698	6	2	7	1	0	0	1	0	0	7.069590434492861	
i 1	951.7375578231292	13.635	61	200	5	17	8	6	0	1	6	0	0	0.8924935241881213	
i 1	951.7479931972789	1.01	69	698	6	2	13	1	0	0	1	0	0	7.069590434492861	
i 1	951.7487959183674	1.2625	68	1084	3	24	8	0	0	-1	0	0	0	4.0	
i 1	951.7568231292518	0.2525	72	698	6	1	6	2	0	1	2	0	0	2.029039167451801	
i 1	951.9867551020408	0.2525	71	200	4	24	16	0	0	-1	0	0	0	4.0	
i 1	952.0100340136055	1.5150000000000001	74	698	4	5	13	16	0	2	16	0	0	2.0307099131190656	
i 1	952.2471904761904	0.7575000000000001	71	698	2	24	5	1	0	-1	1	0	0	4.0	
i 1	952.264850340136	1.2625	74	200	6	5	2	17	0	1	17	0	0	2.0307099131190656	
i 1	952.4859523809524	2.2725	72	698	6	2	2	1	0	0	1	0	0	7.069590434492861	
i 1	952.4915714285714	1.2625	72	1084	4	1	7	2	0	-2	2	0	0	2.029039167451801	
i 1	952.4955850340136	2.2725	72	1084	5	9	9	1	0	0	1	0	0	6.069590434492861	
i 1	952.5020068027211	1.2625	72	698	6	1	3	2	0	1	2	0	0	2.029039167451801	
i 1	952.735149659864	0.2525	75	200	7	1	16	2	0	-2	2	0	0	2.029039167451801	
i 1	952.7616394557823	0.2525	77	698	4	5	12	16	0	1	16	0	0	2.0307099131190656	
i 1	952.9891632653062	0.2525	74	1084	5	5	16	16	0	1	16	0	0	2.0307099131190656	
i 1	952.9899659863945	0.2525	75	698	3	1	9	2	0	1	2	0	0	2.029039167451801	
i 1	953.233544217687	1.7675	75	200	5	24	12	2	0	-2	2	0	0	3.029039167451801	
i 1	953.240768707483	1.7675	77	1084	5	5	16	17	0	2	17	0	0	2.0307099131190656	
i 1	953.2415714285714	0.7575000000000001	69	1084	5	9	14	0	0	0	0	0	0	6.069590434492861	
i 1	953.2455850340136	1.7675	77	698	4	5	12	16	0	1	16	0	0	2.0307099131190656	
i 1	953.2536122448979	1.7675	72	698	4	24	2	2	0	-2	2	0	0	3.029039167451801	
i 1	953.2544149659864	2.2725	68	1084	3	24	6	0	0	-1	0	0	0	4.0	
i 1	953.2688639455782	0.7575000000000001	69	698	6	2	8	1	0	0	1	0	0	7.069590434492861	
i 1	953.7616394557823	0.2525	75	200	7	1	4	2	0	-2	2	0	0	2.029039167451801	
i 1	953.7624421768708	0.2525	74	698	4	5	10	16	0	2	16	0	0	2.0307099131190656	
i 1	953.7680612244898	0.7575000000000001	71	698	2	24	8	1	0	-1	1	0	0	4.0	
i 1	953.9859523809524	0.2525	72	698	6	1	5	2	0	1	2	0	0	2.029039167451801	
i 1	954.0076258503401	0.2525	74	698	4	5	7	17	0	2	17	0	0	2.0307099131190656	
i 1	954.2423741496599	0.2525	75	698	6	1	2	8	0	1	8	0	0	2.029039167451801	
i 1	954.2431768707482	0.2525	74	1084	5	5	10	16	0	1	16	0	0	2.0307099131190656	
i 1	954.2608367346938	1.7675	69	698	6	2	3	1	0	0	1	0	0	7.069590434492861	
i 1	954.4915714285714	1.5150000000000001	74	698	4	5	5	16	0	2	16	0	0	2.0307099131190656	
i 1	954.5140476190476	1.5150000000000001	69	1084	5	9	13	0	0	0	0	0	0	6.069590434492861	
i 1	954.5156530612245	1.5150000000000001	74	200	6	5	3	17	0	1	17	0	0	2.0307099131190656	
i 1	954.7471904761904	1.5150000000000001	75	698	3	1	16	2	0	1	2	0	0	2.029039167451801	
i 1	954.7632448979592	1.5150000000000001	75	200	7	1	15	2	0	-2	2	0	0	2.029039167451801	
i 1	954.7688639455782	0.2525	72	698	5	3	5	0	0	0	0	0	0	7.069590434492861	
i 1	955.0116394557823	0.2525	74	698	4	5	11	16	0	2	16	0	0	2.0307099131190656	
i 1	955.0156530612245	0.2525	72	698	4	4	7	1	0	-1	1	0	0	7.069590434492861	
i 1	955.2367551020408	0.2525	77	1084	5	5	14	17	0	2	17	0	0	2.0307099131190656	
i 1	955.2479931972789	0.2525	75	1084	4	1	14	2	0	-2	2	0	0	2.029039167451801	
i 1	955.4859523809524	1.2625	72	698	4	4	14	1	0	-1	1	0	0	7.069590434492861	
i 1	955.4947823129252	2.525	74	1084	5	5	1	16	0	1	16	0	0	2.0307099131190656	
i 1	955.4995986394558	2.2725	74	698	4	5	9	17	0	2	17	0	0	2.0307099131190656	
i 1	955.5036122448979	0.2525	75	698	6	1	5	8	0	1	8	0	0	2.029039167451801	
i 1	955.5060204081633	1.2625	72	200	5	4	5	1	0	-1	1	0	0	7.069590434492861	
i 1	955.7439795918367	2.2725	68	698	2	24	14	0	0	-1	0	0	0	4.0	
i 1	955.759231292517	0.2525	72	698	4	24	8	2	0	-2	2	0	0	3.029039167451801	
i 1	955.985149659864	0.2525	74	698	4	5	5	16	0	2	16	0	0	2.0307099131190656	
i 1	955.9963877551021	1.7675	75	1084	4	1	8	2	0	-2	2	0	0	2.029039167451801	
i 1	956.014850340136	0.2525	69	200	6	3	8	0	0	-1	0	0	0	7.069590434492861	
i 1	956.0156530612245	1.7675	75	698	6	1	10	8	0	1	8	0	0	2.029039167451801	
i 1	956.2359523809524	0.2525	74	698	4	5	5	16	0	2	16	0	0	2.0307099131190656	
i 1	956.2375578231292	2.02	68	1084	3	24	7	0	0	-1	0	0	0	4.0	
i 1	956.4843469387755	0.2525	75	200	5	24	5	2	0	-2	2	0	0	3.029039167451801	
i 1	956.5052176870748	1.2625	69	1084	5	9	3	0	0	0	0	0	0	6.069590434492861	
i 1	956.5068231292518	1.2625	69	698	6	2	13	1	0	0	1	0	0	7.069590434492861	
i 1	956.7487959183674	0.2525	74	698	4	5	3	16	0	2	16	0	0	2.0307099131190656	
i 1	956.7528095238096	0.2525	72	698	6	2	14	1	0	0	1	0	0	7.069590434492861	
i 1	956.9827414965987	1.5150000000000001	77	1084	5	5	12	17	0	2	17	0	0	2.0307099131190656	
i 1	957.2431768707482	1.01	75	200	7	1	6	2	0	-2	2	0	0	2.029039167451801	
i 1	957.2447823129252	1.2625	77	698	4	5	9	16	0	1	16	0	0	2.0307099131190656	
i 1	957.2463877551021	1.2625	69	200	6	3	8	0	0	-1	0	0	0	7.069590434492861	
i 1	957.2512040816326	1.01	75	698	3	1	1	2	0	1	2	0	0	2.029039167451801	
i 1	957.2552176870748	1.2625	72	698	5	3	7	0	0	0	0	0	0	7.069590434492861	
i 1	957.7415714285714	0.2525	72	1084	5	9	1	1	0	0	1	0	0	6.069590434492861	
i 1	957.7431768707482	1.2625	72	698	6	1	15	2	0	1	2	0	0	2.029039167451801	
i 1	957.7520068027211	1.2625	72	1084	4	1	2	2	0	-2	2	0	0	2.029039167451801	
i 1	958.0052176870748	0.2525	74	698	4	5	11	16	0	2	16	0	0	2.0307099131190656	
i 1	958.0124421768708	0.7575000000000001	69	1084	5	9	5	0	0	0	0	0	0	6.069590434492861	
i 1	958.235149659864	0.7575000000000001	74	1084	5	5	9	16	0	1	16	0	0	2.0307099131190656	
i 1	958.2471904761904	0.2525	72	698	4	24	12	2	0	-2	2	0	0	3.029039167451801	
i 1	958.2520068027211	0.7575000000000001	74	698	4	5	10	17	0	2	17	0	0	2.0307099131190656	
i 1	958.2576258503401	1.2625	72	1084	5	9	10	1	0	0	1	0	0	6.069590434492861	
i 1	958.2624421768708	1.2625	72	698	6	2	1	1	0	0	1	0	0	7.069590434492861	
i 1	958.2640476190476	0.505	69	698	6	2	4	1	0	0	1	0	0	7.069590434492861	
i 1	958.4811360544218	1.2625	75	1084	4	1	4	2	0	-2	2	0	0	2.029039167451801	
i 1	958.4891632653062	0.2525	68	200	4	20	4	1	0	0	1	0	0	4.000000000000001	
i 1	958.4931768707482	1.2625	75	698	6	1	2	8	0	1	8	0	0	2.029039167451801	
i 1	958.5060204081633	13.635	61	1084	4	18	4	9	0	0	9	0	0	0.8924935241881213	
i 1	958.5060204081633	0.2525	71	698	3	20	2	0	0	0	0	0	0	4.000000000000001	
i 1	958.5100340136055	1.7675	68	1084	3	20	2	0	0	-1	0	0	0	4.000000000000001	
i 1	958.7311360544218	1.5150000000000001	74	200	4	5	6	17	0	1	17	0	0	2.0307099131190656	
i 1	958.733544217687	1.5150000000000001	74	698	4	5	13	16	0	2	16	0	0	2.0307099131190656	
i 1	958.733544217687	0.505	71	1084	2	20	16	0	0	0	0	0	0	4.000000000000001	
i 1	958.7367551020408	0.2525	69	200	6	3	9	0	0	-1	0	0	0	7.069590434492861	
i 1	958.7399659863945	0.505	68	1084	3	20	3	1	0	0	1	0	0	4.000000000000001	
i 1	958.7504013605442	0.505	71	698	2	20	8	1	0	-1	1	0	0	4.000000000000001	
i 1	958.7528095238096	0.7575000000000001	68	1084	3	24	12	0	0	-1	0	0	0	8.0	
i 1	958.7544149659864	0.505	71	698	2	24	8	1	0	0	1	0	0	8.0	
i 1	958.9827414965987	1.7675	69	698	6	2	2	1	0	0	1	0	0	7.069590434492861	
i 1	959.0004013605442	0.2525	75	200	7	1	2	2	0	-2	2	0	0	2.029039167451801	
i 1	959.0004013605442	0.2525	77	1084	5	5	16	17	0	2	17	0	0	2.0307099131190656	
i 1	959.016455782313	1.7675	69	1084	5	9	9	0	0	0	0	0	0	6.069590434492861	
i 1	959.2455850340136	0.2525	74	698	4	5	9	17	0	2	17	0	0	2.0307099131190656	
i 1	959.2471904761904	0.505	68	698	4	20	15	0	0	0	0	0	0	4.000000000000001	
i 1	959.2552176870748	0.505	68	698	3	20	9	0	0	-1	0	0	0	4.000000000000001	
i 1	959.2696666666667	0.2525	72	698	6	1	4	2	0	1	2	0	0	2.029039167451801	
i 1	959.5140476190476	0.2525	68	200	4	20	9	0	0	-1	0	0	0	4.000000000000001	
i 1	959.733544217687	2.02	77	698	4	5	4	16	0	1	16	0	0	2.0307099131190656	
i 1	959.7343469387755	0.2525	69	200	6	3	5	0	0	-1	0	0	0	7.069590434492861	
i 1	959.7375578231292	1.2625	71	698	2	20	7	0	0	-1	0	0	0	4.000000000000001	
i 1	959.7495986394558	1.2625	68	1084	2	20	13	1	0	0	1	0	0	4.000000000000001	
i 1	959.759231292517	1.7675	72	698	3	24	8	2	0	-2	2	0	0	3.029039167451801	
i 1	959.7608367346938	0.505	68	1084	3	20	15	0	0	0	0	0	0	4.000000000000001	
i 1	959.7616394557823	2.02	77	1084	5	5	11	17	0	2	17	0	0	2.0307099131190656	
i 1	959.766455782313	1.01	68	1084	3	24	13	0	0	-1	0	0	0	8.0	
i 1	959.7680612244898	1.7675	75	200	5	24	11	2	0	-2	2	0	0	3.029039167451801	
i 1	960.0068231292518	1.5150000000000001	72	1084	5	9	12	1	0	0	1	0	0	6.069590434492861	
i 1	960.2447823129252	0.2525	74	698	4	5	15	17	0	2	17	0	0	2.0307099131190656	
i 1	960.2536122448979	1.5150000000000001	72	698	6	2	14	1	0	0	1	0	0	7.069590434492861	
i 1	960.4811360544218	0.505	68	1084	3	20	10	0	0	0	0	0	0	4.000000000000001	
i 1	960.4995986394558	7.07	68	1084	3	20	9	0	0	-1	0	0	0	4.000000000000001	
i 1	960.5084285714286	0.2525	74	200	4	5	4	17	0	1	17	0	0	2.0307099131190656	
i 1	960.7616394557823	0.2525	75	698	6	1	15	8	0	1	8	0	0	2.029039167451801	
i 1	960.7624421768708	0.2525	74	698	4	5	16	16	0	2	16	0	0	2.0307099131190656	
i 1	960.764850340136	0.2525	69	200	6	3	10	0	0	-1	0	0	0	7.069590434492861	
i 1	960.9803333333333	1.5150000000000001	72	698	6	1	14	2	0	1	2	0	0	2.029039167451801	
i 1	960.9883605442177	1.5150000000000001	72	1084	4	1	6	2	0	-2	2	0	0	2.029039167451801	
i 1	960.990768707483	3.2825	68	1084	3	24	16	0	0	-1	0	0	0	8.0	
i 1	960.9995986394558	0.2525	68	698	3	20	15	0	0	0	0	0	0	4.000000000000001	
i 1	961.0076258503401	2.02	74	200	4	5	6	17	0	1	17	0	0	2.0307099131190656	
i 1	961.0100340136055	4.545	69	698	6	2	5	1	0	0	1	0	0	7.069590434492861	
i 1	961.0116394557823	0.2525	68	698	4	20	3	0	0	0	0	0	0	4.000000000000001	
i 1	961.0172585034013	0.2525	71	200	4	20	8	0	0	0	0	0	0	4.000000000000001	
i 1	961.0196666666667	1.5150000000000001	69	1084	5	9	9	0	0	0	0	0	0	6.069590434492861	
i 1	961.240768707483	0.7575000000000001	71	1084	2	20	15	0	0	-1	0	0	0	4.000000000000001	
i 1	961.2439795918367	0.7575000000000001	71	1084	3	20	12	0	0	0	0	0	0	4.000000000000001	
i 1	961.2632448979592	1.7675	74	698	4	5	12	16	0	2	16	0	0	2.0307099131190656	
i 1	961.5132448979592	0.2525	75	200	7	1	16	2	0	-2	2	0	0	2.029039167451801	
i 1	961.733544217687	0.2525	69	200	6	3	10	0	0	-1	0	0	0	7.069590434492861	
i 1	961.7367551020408	0.2525	75	698	3	1	9	2	0	1	2	0	0	2.029039167451801	
i 1	961.7616394557823	0.2525	74	698	4	5	15	17	0	2	17	0	0	2.0307099131190656	
i 1	961.7624421768708	0.2525	68	698	2	20	3	0	0	0	0	0	0	4.000000000000001	
i 1	961.9867551020408	0.505	68	698	4	20	13	0	0	-1	0	0	0	4.000000000000001	
i 1	961.9883605442177	2.02	72	698	3	24	16	2	0	-2	2	0	0	3.029039167451801	
i 1	961.9883605442177	1.2625	72	698	4	4	10	1	0	-1	1	0	0	7.069590434492861	
i 1	961.9939795918367	0.505	71	200	4	20	1	0	0	0	0	0	0	4.000000000000001	
i 1	961.9971904761904	1.2625	72	200	5	4	14	1	0	-1	1	0	0	7.069590434492861	
i 1	961.9995986394558	2.02	75	200	5	24	8	2	0	-2	2	0	0	3.029039167451801	
i 1	961.9995986394558	0.505	68	698	3	20	16	1	0	0	1	0	0	4.000000000000001	
i 1	962.0180612244898	0.2525	77	698	4	5	11	16	0	1	16	0	0	2.0307099131190656	
i 1	962.2584285714286	0.2525	77	1084	5	5	4	17	0	2	17	0	0	2.0307099131190656	
i 1	962.4811360544218	1.5150000000000001	68	1084	3	20	6	0	0	0	0	0	0	4.000000000000001	
i 1	962.485149659864	0.2525	75	1084	4	1	2	2	0	-2	2	0	0	2.029039167451801	
i 1	962.4939795918367	1.7675	74	698	4	5	6	17	0	2	17	0	0	2.0307099131190656	
i 1	962.5004013605442	1.7675	74	1084	5	5	10	16	0	1	16	0	0	2.0307099131190656	
i 1	962.5020068027211	1.5150000000000001	68	1084	2	20	3	0	0	-1	0	0	0	4.000000000000001	
i 1	962.733544217687	0.2525	75	200	7	1	13	2	0	-2	2	0	0	2.029039167451801	
i 1	962.7600340136055	0.7575000000000001	69	1084	5	9	14	0	0	0	0	0	0	6.069590434492861	
i 1	962.9827414965987	0.7575000000000001	68	698	2	24	6	0	0	-1	0	0	0	8.0	
i 1	962.9843469387755	0.2525	75	698	6	1	6	8	0	1	8	0	0	2.029039167451801	
i 1	962.9979931972789	1.5150000000000001	72	698	5	3	2	0	0	0	0	0	0	7.069590434492861	
i 1	963.0028095238096	0.2525	74	698	4	5	5	16	0	2	16	0	0	2.0307099131190656	
i 1	963.0060204081633	1.2625	69	200	6	3	7	0	0	-1	0	0	0	7.069590434492861	
i 1	963.240768707483	1.2625	75	698	3	1	15	2	0	1	2	0	0	2.029039167451801	
i 1	963.2471904761904	0.2525	74	200	4	5	8	17	0	1	17	0	0	2.0307099131190656	
i 1	963.4931768707482	0.2525	74	698	4	5	11	16	0	2	16	0	0	2.0307099131190656	
i 1	963.5084285714286	1.01	75	200	7	1	16	2	0	-2	2	0	0	2.029039167451801	
i 1	963.740768707483	1.7675	69	1084	5	9	13	0	0	0	0	0	0	6.069590434492861	
i 1	963.7560204081633	1.7675	77	1084	5	5	8	17	0	2	17	0	0	2.0307099131190656	
i 1	963.764850340136	1.7675	77	698	4	5	12	16	0	1	16	0	0	2.0307099131190656	
i 1	963.985149659864	0.2525	71	698	3	20	7	1	0	0	1	0	0	4.000000000000001	
i 1	963.9891632653062	0.2525	71	698	4	20	10	1	0	-1	1	0	0	4.000000000000001	
i 1	964.014850340136	1.2625	75	698	6	1	15	8	0	1	8	0	0	2.029039167451801	
i 1	964.016455782313	1.2625	75	1084	4	1	12	2	0	-2	2	0	0	2.029039167451801	
i 1	964.2303333333333	1.01	71	1084	3	20	10	1	0	0	1	0	0	4.000000000000001	
i 1	964.2616394557823	0.2525	74	698	4	5	14	16	0	2	16	0	0	2.0307099131190656	
i 1	964.4875578231292	1.01	68	698	2	24	8	0	0	0	0	0	0	8.0	
i 1	964.4963877551021	0.2525	72	698	4	4	8	1	0	-1	1	0	0	7.069590434492861	
i 1	964.5012040816326	0.2525	77	200	6	5	9	16	0	1	16	0	0	2.0307099131190656	
i 1	964.5076258503401	1.01	71	698	2	20	7	0	0	-1	0	0	0	4.000000000000001	
i 1	964.5188639455782	0.2525	72	1084	4	1	13	2	0	-2	2	0	0	2.029039167451801	
i 1	964.7311360544218	0.2525	74	698	4	5	8	16	0	2	16	0	0	2.0307099131190656	
i 1	964.7327414965987	1.5150000000000001	72	1084	5	9	3	1	0	0	1	0	0	6.069590434492861	
i 1	964.7455850340136	1.5150000000000001	75	698	3	1	15	2	0	1	2	0	0	2.029039167451801	
i 1	964.759231292517	1.5150000000000001	75	200	7	1	11	2	0	-2	2	0	0	2.029039167451801	
i 1	964.9819387755102	1.7675	68	1084	3	24	4	0	0	-1	0	0	0	8.0	
i 1	964.9923741496599	0.505	68	1084	2	20	3	1	0	-1	1	0	0	4.000000000000001	
i 1	964.9947823129252	1.5150000000000001	74	1084	5	5	4	16	0	1	16	0	0	2.0307099131190656	
i 1	965.0076258503401	1.5150000000000001	74	698	4	5	12	17	0	2	17	0	0	2.0307099131190656	
i 1	965.0172585034013	1.5150000000000001	72	698	6	2	11	1	0	0	1	0	0	7.069590434492861	
i 1	965.240768707483	46.7125	66	698	5	14	16	9	0	0	9	0	0	2.3536679069160917	
i 1	965.2415714285714	0.2525	71	1084	2	20	8	1	0	0	1	0	0	4.000000000000001	
i 1	965.2431768707482	27.27	66	1084	4	16	13	6	0	1	6	0	0	1.178017605288281	
i 1	965.2439795918367	1.2625	71	698	2	24	13	1	0	0	1	0	0	8.0	
i 1	965.2495986394558	0.2525	72	698	3	24	6	2	0	-2	2	0	0	3.029039167451801	
i 1	965.2536122448979	13.635	66	1084	4	18	16	6	0	1	6	0	0	0.8924935241881213	
i 1	965.4883605442177	0.505	68	698	3	20	4	0	0	-1	0	0	0	4.000000000000001	
i 1	965.4955850340136	0.2525	75	200	5	24	6	2	0	-2	2	0	0	3.029039167451801	
i 1	965.4995986394558	0.2525	74	200	4	5	8	17	0	1	17	0	0	2.0307099131190656	
i 1	965.5036122448979	0.2525	72	200	5	4	1	1	0	-1	1	0	0	7.069590434492861	
i 1	965.509231292517	0.505	68	698	3	20	10	1	0	0	1	0	0	4.000000000000001	
i 1	965.7303333333333	2.02	72	698	6	1	13	2	0	1	2	0	0	2.029039167451801	
i 1	965.7495986394558	0.2525	71	200	4	20	3	0	0	-1	0	0	0	4.000000000000001	
i 1	965.7504013605442	1.2625	74	698	4	5	9	16	0	2	16	0	0	2.0307099131190656	
i 1	965.7512040816326	2.525	72	1084	4	1	15	2	0	-2	2	0	0	2.029039167451801	
i 1	965.7616394557823	2.525	69	1084	5	9	15	0	0	0	0	0	0	6.069590434492861	
i 1	965.7640476190476	1.5150000000000001	69	698	6	2	6	1	0	0	1	0	0	7.069590434492861	
i 1	965.9859523809524	0.2525	68	1084	2	20	13	1	0	-1	1	0	0	4.000000000000001	
i 1	965.990768707483	0.2525	68	698	2	24	5	0	0	0	0	0	0	8.0	
i 1	965.9923741496599	0.2525	71	1084	2	20	3	0	0	-1	0	0	0	4.000000000000001	
i 1	966.0180612244898	1.2625	74	200	4	5	11	17	0	1	17	0	0	2.0307099131190656	
i 1	966.2552176870748	0.2525	72	698	3	24	7	2	0	-2	2	0	0	3.029039167451801	
i 1	966.2616394557823	0.2525	71	200	4	24	8	1	0	-1	1	0	0	8.0	
i 1	966.4843469387755	0.2525	68	698	2	20	14	1	0	-1	1	0	0	4.000000000000001	
i 1	966.485149659864	0.2525	72	698	4	4	10	1	0	-1	1	0	0	7.069590434492861	
i 1	966.485149659864	0.505	71	698	2	24	14	0	0	0	0	0	0	8.0	
i 1	966.4875578231292	2.7775	77	1084	5	5	4	17	0	2	17	0	0	2.0307099131190656	
i 1	966.5076258503401	2.7775	77	698	4	5	15	16	0	1	16	0	0	2.0307099131190656	
i 1	966.5116394557823	0.2525	75	200	5	24	9	2	0	-2	2	0	0	3.029039167451801	
i 1	966.5188639455782	0.505	71	1084	2	20	10	1	0	-1	1	0	0	4.000000000000001	
i 1	966.7415714285714	1.01	71	698	2	24	1	1	0	0	1	0	0	8.0	
i 1	966.7463877551021	1.2625	72	698	6	2	6	1	0	0	1	0	0	7.069590434492861	
i 1	966.7632448979592	1.2625	72	1084	5	9	4	1	0	0	1	0	0	6.069590434492861	
i 1	966.9859523809524	0.2525	68	698	3	20	14	0	0	0	0	0	0	4.000000000000001	
i 1	966.9971904761904	11.615	68	1084	3	24	7	0	0	-1	0	0	0	8.0	
i 1	967.0084285714286	0.2525	72	698	3	24	16	2	0	-2	2	0	0	3.029039167451801	
i 1	967.0140476190476	0.2525	71	200	4	24	15	0	0	-1	0	0	0	8.0	
i 1	967.235149659864	1.5150000000000001	75	1084	6	1	8	2	0	-2	2	0	0	2.029039167451801	
i 1	967.2431768707482	0.2525	71	698	2	20	11	0	0	-1	0	0	0	4.000000000000001	
i 1	967.2455850340136	0.2525	68	698	2	24	9	1	0	-1	1	0	0	8.0	
i 1	967.2479931972789	0.2525	74	698	4	5	5	16	0	2	16	0	0	2.0307099131190656	
i 1	967.2512040816326	1.5150000000000001	75	698	6	1	9	8	0	1	8	0	0	2.029039167451801	
i 1	967.2608367346938	0.2525	71	1084	2	20	7	1	0	0	1	0	0	4.000000000000001	
i 1	967.2640476190476	0.2525	68	1084	2	20	5	1	0	-1	1	0	0	4.000000000000001	
i 1	967.4819387755102	0.2525	71	698	3	20	9	0	0	-1	0	0	0	4.000000000000001	
i 1	967.516455782313	0.7575000000000001	69	698	6	2	4	1	0	0	1	0	0	7.069590434492861	
i 1	967.5188639455782	0.2525	77	200	4	5	1	16	0	1	16	0	0	2.0307099131190656	
i 1	967.7327414965987	2.02	68	1084	2	20	8	0	0	-1	0	0	0	4.000000000000001	
i 1	967.7447823129252	1.7675	71	698	2	24	4	0	0	-1	0	0	0	8.0	
i 1	967.7552176870748	0.2525	71	698	2	20	16	0	0	-1	0	0	0	4.000000000000001	
i 1	967.7584285714286	1.2625	72	698	4	4	15	1	0	-1	1	0	0	7.069590434492861	
i 1	967.7672585034013	1.2625	72	200	5	4	14	1	0	-1	1	0	0	7.069590434492861	
i 1	968.2391632653062	0.2525	77	200	4	5	8	16	0	1	16	0	0	2.0307099131190656	
i 1	968.2415714285714	3.2825	75	200	5	24	4	2	0	-2	2	0	0	3.029039167451801	
i 1	968.2447823129252	3.2825	72	698	3	24	10	2	0	-2	2	0	0	3.029039167451801	
i 1	968.2536122448979	0.2525	69	200	6	3	14	0	0	-1	0	0	0	7.069590434492861	
i 1	968.5068231292518	3.535	69	1084	5	9	2	0	0	0	0	0	0	6.069590434492861	
i 1	968.516455782313	1.7675	69	698	6	2	10	1	0	0	1	0	0	7.069590434492861	
i 1	968.759231292517	0.7575000000000001	75	200	7	1	11	2	0	-2	2	0	0	2.029039167451801	
i 1	968.7656530612245	0.7575000000000001	74	698	4	5	14	16	0	2	16	0	0	2.0307099131190656	
i 1	968.7672585034013	0.7575000000000001	74	200	4	5	4	17	0	1	17	0	0	2.0307099131190656	
i 1	968.9803333333333	3.0300000000000002	74	1084	5	5	12	16	0	1	16	0	0	2.0307099131190656	
i 1	968.9899659863945	1.01	68	1084	3	20	8	0	0	-1	0	0	0	4.000000000000001	
i 1	968.9947823129252	4.545	74	698	4	5	2	17	0	2	17	0	0	2.0307099131190656	
i 1	969.0132448979592	0.505	72	698	5	3	10	0	0	0	0	0	0	7.069590434492861	
i 1	969.016455782313	0.7575000000000001	68	1084	2	20	8	1	0	0	1	0	0	4.000000000000001	
i 1	969.4939795918367	1.7675	71	698	2	24	14	1	0	0	1	0	0	8.0	
i 1	969.4987959183674	0.2525	74	698	4	5	2	16	0	2	16	0	0	2.0307099131190656	
i 1	969.5076258503401	0.2525	75	1084	6	1	2	2	0	-2	2	0	0	2.029039167451801	
i 1	969.5188639455782	0.2525	72	698	4	4	15	1	0	-1	1	0	0	7.069590434492861	
i 1	969.7311360544218	1.2625	69	200	6	3	1	0	0	-1	0	0	0	7.069590434492861	
i 1	969.7471904761904	1.01	72	698	6	1	5	2	0	1	2	0	0	2.029039167451801	
i 1	969.7495986394558	0.2525	71	698	3	20	8	1	0	-1	1	0	0	4.000000000000001	
i 1	969.7504013605442	0.2525	71	698	3	20	7	0	0	-1	0	0	0	4.000000000000001	
i 1	969.7584285714286	0.2525	77	200	4	5	4	16	0	1	16	0	0	2.0307099131190656	
i 1	969.7624421768708	1.2625	72	698	5	3	2	0	0	0	0	0	0	7.069590434492861	
i 1	969.7632448979592	1.2625	72	1084	4	1	16	2	0	-2	2	0	0	2.029039167451801	
i 1	970.0108367346938	0.2525	68	1084	2	20	15	0	0	-1	0	0	0	4.000000000000001	
i 1	970.0180612244898	1.7675	71	1084	2	20	11	1	0	0	1	0	0	4.000000000000001	
i 1	970.483544217687	0.7575000000000001	68	698	2	20	16	1	0	-1	1	0	0	4.000000000000001	
i 1	970.4915714285714	1.2625	71	698	2	24	9	1	0	-1	1	0	0	8.0	
i 1	970.5068231292518	2.525	69	698	6	2	4	1	0	0	1	0	0	7.069590434492861	
i 1	970.9811360544218	0.2525	74	698	4	5	6	16	0	2	16	0	0	2.0307099131190656	
i 1	970.9939795918367	1.5150000000000001	75	200	7	1	15	2	0	-2	2	0	0	2.029039167451801	
i 1	971.0020068027211	1.5150000000000001	75	698	3	1	5	2	0	1	2	0	0	2.029039167451801	
i 1	971.009231292517	0.2525	72	698	4	4	10	1	0	-1	1	0	0	7.069590434492861	
i 1	971.2471904761904	0.7575000000000001	72	1084	5	9	3	1	0	0	1	0	0	6.069590434492861	
i 1	971.2495986394558	1.01	77	698	4	5	14	16	0	1	16	0	0	2.0307099131190656	
i 1	971.2688639455782	1.01	77	1084	5	5	10	17	0	2	17	0	0	2.0307099131190656	
i 1	971.4811360544218	1.01	68	1084	3	20	4	0	0	-1	0	0	0	4.000000000000001	
i 1	971.4891632653062	0.2525	75	1084	6	1	2	2	0	-2	2	0	0	2.029039167451801	
i 1	971.509231292517	2.2725	72	698	6	2	15	1	0	0	1	0	0	7.069590434492861	
i 1	971.7383605442177	0.2525	71	200	4	24	12	0	0	-1	0	0	0	8.0	
i 1	971.7520068027211	0.2525	72	698	6	1	16	2	0	1	2	0	0	2.029039167451801	
i 1	971.7552176870748	0.505	68	698	3	20	12	1	0	0	1	0	0	4.000000000000001	
i 1	971.983544217687	2.02	75	698	6	1	14	8	0	1	8	0	0	2.029039167451801	
i 1	971.9843469387755	0.2525	68	200	3	20	8	0	0	-1	0	0	0	4.000000000000001	
i 1	971.9971904761904	1.7675	71	698	2	24	13	1	0	0	1	0	0	8.0	
i 1	971.9995986394558	27.27	61	698	6	17	15	6	0	1	6	0	0	0.8924935241881213	
i 1	972.0116394557823	2.02	75	1084	6	1	14	2	0	-2	2	0	0	2.029039167451801	
i 1	972.0132448979592	1.5150000000000001	74	1084	3	5	16	16	0	1	16	0	0	2.0307099131190656	
i 1	972.014850340136	27.27	61	1084	4	16	10	9	0	0	9	0	0	1.178017605288281	
i 1	972.0156530612245	1.7675	72	1084	5	9	1	1	0	0	1	0	0	6.069590434492861	
i 1	972.016455782313	13.635	66	698	3	19	10	6	0	1	6	0	0	0.8924935241881213	
i 1	972.2303333333333	1.2625	68	1084	2	20	1	1	0	-1	1	0	0	4.000000000000001	
i 1	972.2391632653062	0.505	68	698	1	20	5	0	0	-1	0	0	0	4.000000000000001	
i 1	972.2487959183674	0.2525	74	200	4	5	16	17	0	1	17	0	0	2.0307099131190656	
i 1	972.2616394557823	2.7775	69	1084	5	9	14	0	0	0	0	0	0	6.069590434492861	
i 1	972.4883605442177	0.2525	75	200	5	24	9	2	0	-2	2	0	0	3.029039167451801	
i 1	972.4979931972789	0.2525	77	1084	5	5	10	17	0	2	17	0	0	2.0307099131190656	
i 1	972.7616394557823	0.2525	74	698	4	5	4	16	0	2	16	0	0	2.0307099131190656	
i 1	972.7680612244898	0.2525	75	698	3	1	10	2	0	1	2	0	0	2.029039167451801	
i 1	972.9859523809524	1.5150000000000001	74	200	4	5	11	17	0	1	17	0	0	2.0307099131190656	
i 1	972.9867551020408	1.2625	68	698	2	20	6	0	0	0	0	0	0	4.000000000000001	
i 1	972.9971904761904	0.505	68	698	2	24	12	0	0	-1	0	0	0	8.0	
i 1	973.0060204081633	1.5150000000000001	74	698	4	5	16	16	0	2	16	0	0	2.0307099131190656	
i 1	973.0068231292518	0.505	68	698	1	20	4	0	0	-1	0	0	0	4.000000000000001	
i 1	973.0108367346938	0.2525	72	1084	6	1	4	2	0	-2	2	0	0	2.029039167451801	
i 1	973.2367551020408	1.7675	75	200	7	1	16	2	0	-2	2	0	0	2.029039167451801	
i 1	973.2383605442177	3.535	69	698	6	2	14	1	0	0	1	0	0	7.069590434492861	
i 1	973.2560204081633	2.7775	68	1084	3	20	12	0	0	-1	0	0	0	4.000000000000001	
i 1	973.4859523809524	0.2525	74	698	4	5	9	16	0	2	16	0	0	2.0307099131190656	
i 1	973.4915714285714	1.5150000000000001	75	698	3	1	7	2	0	1	2	0	0	2.029039167451801	
i 1	973.4995986394558	0.505	68	698	3	20	14	0	0	-1	0	0	0	4.000000000000001	
i 1	973.5004013605442	0.505	71	200	4	24	7	0	0	-1	0	0	0	8.0	
i 1	973.5052176870748	0.505	68	200	3	20	12	0	0	0	0	0	0	4.000000000000001	
i 1	973.7487959183674	0.2525	74	1084	3	5	5	16	0	1	16	0	0	2.0307099131190656	
i 1	973.7504013605442	0.2525	71	698	3	20	5	0	0	-1	0	0	0	4.000000000000001	
i 1	973.7584285714286	0.505	72	200	5	4	4	1	0	-1	1	0	0	7.069590434492861	
i 1	973.9859523809524	2.02	77	698	4	5	7	16	0	1	16	0	0	2.0307099131190656	
i 1	973.9939795918367	2.02	77	1084	5	5	4	17	0	2	17	0	0	2.0307099131190656	
i 1	973.9939795918367	0.7575000000000001	71	698	1	20	13	0	0	-1	0	0	0	4.000000000000001	
i 1	973.9955850340136	0.2525	72	1084	6	1	12	2	0	-2	2	0	0	2.029039167451801	
i 1	973.9963877551021	0.505	68	1084	2	20	4	0	0	-1	0	0	0	4.000000000000001	
i 1	974.0020068027211	0.7575000000000001	68	1084	2	20	7	1	0	0	1	0	0	4.000000000000001	
i 1	974.0116394557823	0.7575000000000001	71	698	2	24	7	1	0	0	1	0	0	8.0	
i 1	974.2544149659864	0.2525	75	1084	6	1	2	2	0	-2	2	0	0	2.029039167451801	
i 1	974.2552176870748	0.2525	69	200	6	3	15	0	0	-1	0	0	0	7.069590434492861	
i 1	974.4867551020408	0.505	74	698	4	5	14	16	0	2	16	0	0	2.0307099131190656	
i 1	974.5044149659864	2.02	72	1084	6	1	6	2	0	-2	2	0	0	2.029039167451801	
i 1	974.5108367346938	1.2625	72	698	4	4	3	1	0	-1	1	0	0	7.069590434492861	
i 1	974.5124421768708	2.02	72	698	6	1	14	2	0	1	2	0	0	2.029039167451801	
i 1	974.5180612244898	1.2625	72	200	5	4	15	1	0	-1	1	0	0	7.069590434492861	
i 1	974.7359523809524	0.2525	71	698	3	20	6	1	0	-1	1	0	0	4.000000000000001	
i 1	974.7512040816326	0.2525	71	698	3	20	7	1	0	-1	1	0	0	4.000000000000001	
i 1	974.9971904761904	0.2525	74	698	4	5	11	16	0	2	16	0	0	2.0307099131190656	
i 1	975.0004013605442	0.2525	71	1084	2	20	9	1	0	-1	1	0	0	4.000000000000001	
i 1	975.0076258503401	1.01	71	698	2	24	12	1	0	0	1	0	0	8.0	
i 1	975.0108367346938	0.2525	72	698	3	24	12	2	0	-2	2	0	0	3.029039167451801	
i 1	975.0124421768708	0.2525	68	1084	2	20	16	1	0	0	1	0	0	4.000000000000001	
i 1	975.2311360544218	0.505	75	200	5	24	4	2	0	-2	2	0	0	3.029039167451801	
i 1	975.2495986394558	1.5150000000000001	69	1084	5	9	16	0	0	0	0	0	0	6.069590434492861	
i 1	975.2544149659864	0.505	71	698	3	20	13	0	0	-1	0	0	0	4.000000000000001	
i 1	975.2584285714286	0.2525	74	698	4	5	10	16	0	2	16	0	0	2.0307099131190656	
i 1	975.2600340136055	0.505	68	698	3	20	1	0	0	0	0	0	0	4.000000000000001	
i 1	975.4803333333333	1.5150000000000001	74	698	4	5	10	16	0	2	16	0	0	2.0307099131190656	
i 1	975.4963877551021	1.5150000000000001	74	200	4	5	16	17	0	1	17	0	0	2.0307099131190656	
i 1	975.7479931972789	0.2525	72	698	3	24	7	2	0	-2	2	0	0	3.029039167451801	
i 1	975.7512040816326	0.2525	69	200	6	3	11	0	0	-1	0	0	0	7.069590434492861	
i 1	975.7600340136055	0.7575000000000001	68	698	2	20	15	0	0	0	0	0	0	4.000000000000001	
i 1	975.7608367346938	1.2625	68	1084	2	20	9	0	0	0	0	0	0	4.000000000000001	
i 1	975.764850340136	0.2525	68	1084	2	20	6	1	0	-1	1	0	0	4.000000000000001	
i 1	975.7680612244898	1.01	68	698	2	24	1	0	0	-1	0	0	0	8.0	
i 1	975.9955850340136	0.2525	72	698	4	4	3	1	0	-1	1	0	0	7.069590434492861	
i 1	976.0124421768708	1.01	75	698	6	1	4	8	0	1	8	0	0	2.029039167451801	
i 1	976.014850340136	0.2525	74	1084	3	5	6	16	0	1	16	0	0	2.0307099131190656	
i 1	976.0196666666667	1.01	75	1084	6	1	5	2	0	-2	2	0	0	2.029039167451801	
i 1	976.2528095238096	2.525	74	698	4	5	6	17	0	2	17	0	0	2.0307099131190656	
i 1	976.2560204081633	1.2625	69	200	6	3	5	0	0	-1	0	0	0	7.069590434492861	
i 1	976.2656530612245	1.2625	72	698	5	3	6	0	0	0	0	0	0	7.069590434492861	
i 1	976.5044149659864	1.2625	75	200	5	24	4	2	0	-2	2	0	0	3.029039167451801	
i 1	976.5052176870748	1.2625	72	698	3	24	9	2	0	-2	2	0	0	3.029039167451801	
i 1	976.5068231292518	2.525	74	1084	3	5	1	16	0	1	16	0	0	2.0307099131190656	
i 1	976.7327414965987	5.555	68	1084	3	20	11	0	0	-1	0	0	0	4.000000000000001	
i 1	976.7439795918367	0.7575000000000001	71	698	2	24	2	1	0	0	1	0	0	8.0	
i 1	976.7487959183674	0.2525	72	200	5	4	14	1	0	-1	1	0	0	7.069590434492861	
i 1	976.7656530612245	0.2525	68	1084	2	20	3	1	0	-1	1	0	0	4.000000000000001	
i 1	976.983544217687	0.2525	77	200	4	5	6	16	0	1	16	0	0	2.0307099131190656	
i 1	977.0020068027211	0.7575000000000001	69	698	6	2	10	1	0	0	1	0	0	7.069590434492861	
i 1	977.0044149659864	0.2525	75	698	3	1	10	2	0	1	2	0	0	2.029039167451801	
i 1	977.0124421768708	1.7675	69	1084	5	9	1	0	0	0	0	0	0	6.069590434492861	
i 1	977.014850340136	0.2525	68	698	3	20	1	1	0	-1	1	0	0	4.000000000000001	
i 1	977.016455782313	0.2525	71	698	3	20	6	1	0	-1	1	0	0	4.000000000000001	
i 1	977.2359523809524	1.2625	72	698	6	2	14	1	0	0	1	0	0	7.069590434492861	
i 1	977.2375578231292	2.525	72	698	6	1	16	2	0	1	2	0	0	2.029039167451801	
i 1	977.2544149659864	1.5150000000000001	72	1084	6	1	4	2	0	-2	2	0	0	2.029039167451801	
i 1	977.2584285714286	1.5150000000000001	72	1084	5	9	12	1	0	0	1	0	0	6.069590434492861	
i 1	977.2672585034013	0.2525	74	698	4	5	15	16	0	2	16	0	0	2.0307099131190656	
i 1	977.4979931972789	0.2525	68	698	3	20	5	1	0	-1	1	0	0	4.000000000000001	
i 1	977.5188639455782	0.505	74	698	4	5	6	16	0	2	16	0	0	2.0307099131190656	
i 1	977.5196666666667	0.2525	68	698	3	20	14	1	0	-1	1	0	0	4.000000000000001	
i 1	977.733544217687	1.01	71	1084	2	20	2	0	0	-1	0	0	0	4.000000000000001	
i 1	977.733544217687	0.7575000000000001	71	698	2	24	2	1	0	0	1	0	0	8.0	
i 1	977.7391632653062	0.2525	75	698	6	1	12	8	0	1	8	0	0	2.029039167451801	
i 1	977.7624421768708	0.7575000000000001	68	698	2	20	15	0	0	0	0	0	0	4.000000000000001	
i 1	977.7680612244898	1.01	71	1084	2	20	1	1	0	-1	1	0	0	4.000000000000001	
i 1	977.9891632653062	1.7675	69	698	6	2	10	1	0	0	1	0	0	7.069590434492861	
i 1	977.9939795918367	0.2525	74	200	4	5	2	17	0	1	17	0	0	2.0307099131190656	
i 1	978.0140476190476	2.2725	72	698	3	24	11	2	0	-2	2	0	0	3.029039167451801	
i 1	978.2399659863945	2.02	75	200	5	24	9	2	0	-2	2	0	0	3.029039167451801	
i 1	978.2504013605442	0.505	77	1084	5	5	15	17	0	2	17	0	0	2.0307099131190656	
i 1	978.2632448979592	1.5150000000000001	77	698	4	5	1	16	0	1	16	0	0	2.0307099131190656	
i 1	978.4811360544218	0.7575000000000001	71	698	2	24	3	1	0	0	1	0	0	8.0	
i 1	978.7383605442177	1.01	77	1084	3	5	16	17	0	2	17	0	0	2.0307099131190656	
i 1	978.7471904761904	27.27	61	698	5	12	6	9	0	0	9	0	0	1.178017605288281	
i 1	978.7520068027211	0.2525	72	200	5	4	6	1	0	-1	1	0	0	7.069590434492861	
i 1	978.7520068027211	0.2525	71	698	3	20	5	1	0	-1	1	0	0	4.000000000000001	
i 1	978.7576258503401	0.2525	71	698	3	20	6	0	0	-1	0	0	0	4.000000000000001	
i 1	978.7584285714286	13.635	66	698	3	19	1	6	0	1	6	0	0	0.8924935241881213	
i 1	978.7608367346938	5.8075	68	1084	3	24	5	0	0	-1	0	0	0	8.0	
i 1	978.7640476190476	27.27	61	698	6	17	10	9	0	0	9	0	0	0.8924935241881213	
i 1	978.7656530612245	2.7775	69	1084	5	9	12	0	0	0	0	0	0	6.069590434492861	
i 1	978.9843469387755	0.7575000000000001	68	698	2	20	7	0	0	0	0	0	0	4.000000000000001	
i 1	979.0044149659864	0.505	68	698	1	24	7	0	0	0	0	0	0	8.0	
i 1	979.0068231292518	0.2525	74	698	4	5	10	16	0	2	16	0	0	2.0307099131190656	
i 1	979.0084285714286	1.5150000000000001	72	698	6	2	6	1	0	0	1	0	0	7.069590434492861	
i 1	979.0140476190476	0.505	68	1084	2	20	6	0	0	-1	0	0	0	4.000000000000001	
i 1	979.0172585034013	0.2525	68	1084	2	20	11	1	0	-1	1	0	0	4.000000000000001	
i 1	979.2471904761904	1.2625	72	1084	5	9	13	1	0	0	1	0	0	6.069590434492861	
i 1	979.2487959183674	0.7575000000000001	74	1084	3	5	4	16	0	1	16	0	0	2.0307099131190656	
i 1	979.2568231292518	0.7575000000000001	74	698	4	5	9	17	0	2	17	0	0	2.0307099131190656	
i 1	979.4995986394558	1.7675	74	698	4	5	16	16	0	2	16	0	0	2.0307099131190656	
i 1	979.4995986394558	0.2525	71	200	3	24	9	1	0	-1	1	0	0	8.0	
i 1	979.5044149659864	0.2525	68	698	3	20	13	0	0	-1	0	0	0	4.000000000000001	
i 1	979.5132448979592	1.7675	74	200	4	5	11	17	0	1	17	0	0	2.0307099131190656	
i 1	979.733544217687	1.7675	75	698	5	1	10	2	0	1	2	0	0	2.029039167451801	
i 1	979.740768707483	1.5150000000000001	75	200	7	1	2	2	0	-2	2	0	0	2.029039167451801	
i 1	979.7536122448979	1.01	71	1084	2	20	14	1	0	0	1	0	0	4.000000000000001	
i 1	979.7672585034013	1.01	68	698	1	24	12	1	0	-1	1	0	0	8.0	
i 1	979.9963877551021	0.505	74	698	4	5	2	16	0	2	16	0	0	2.0307099131190656	
i 1	980.0100340136055	3.535	68	698	2	20	7	0	0	0	0	0	0	4.000000000000001	
i 1	980.014850340136	0.7575000000000001	68	1084	2	20	15	0	0	0	0	0	0	4.000000000000001	
i 1	980.016455782313	1.5150000000000001	69	698	6	2	9	1	0	0	1	0	0	7.069590434492861	
i 1	980.2640476190476	0.2525	72	698	6	1	1	2	0	1	2	0	0	2.029039167451801	
i 1	980.4899659863945	0.2525	72	698	5	3	10	0	0	0	0	0	0	7.069590434492861	
i 1	980.4971904761904	2.2725	77	1084	3	5	13	17	0	2	17	0	0	2.0307099131190656	
i 1	980.5036122448979	2.2725	75	698	6	1	8	8	0	1	8	0	0	2.029039167451801	
i 1	980.7399659863945	2.02	77	698	4	5	3	16	0	1	16	0	0	2.0307099131190656	
i 1	980.7423741496599	0.2525	71	698	3	20	7	1	0	0	1	0	0	4.000000000000001	
i 1	980.7463877551021	0.2525	72	1084	5	9	10	1	0	0	1	0	0	6.069590434492861	
i 1	980.7520068027211	2.02	75	1084	6	1	6	2	0	-2	2	0	0	2.029039167451801	
i 1	980.7616394557823	0.2525	68	200	3	24	3	1	0	-1	1	0	0	8.0	
i 1	980.7632448979592	0.2525	71	698	3	20	10	1	0	-1	1	0	0	4.000000000000001	
i 1	980.9867551020408	0.505	68	1084	2	20	15	1	0	0	1	0	0	4.000000000000001	
i 1	980.9923741496599	1.2625	72	698	4	4	12	1	0	-1	1	0	0	7.069590434492861	
i 1	980.9971904761904	1.2625	72	200	5	4	14	1	0	-1	1	0	0	7.069590434492861	
i 1	980.9995986394558	0.7575000000000001	68	698	1	24	7	0	0	0	0	0	0	8.0	
i 1	981.016455782313	0.7575000000000001	71	1084	2	20	6	0	0	0	0	0	0	4.000000000000001	
i 1	981.2311360544218	0.2525	74	698	4	5	7	17	0	2	17	0	0	2.0307099131190656	
i 1	981.4899659863945	0.2525	74	200	4	5	4	17	0	1	17	0	0	2.0307099131190656	
i 1	981.4931768707482	0.2525	72	698	6	1	10	2	0	1	2	0	0	2.029039167451801	
i 1	981.5180612244898	0.2525	72	698	5	3	12	0	0	0	0	0	0	7.069590434492861	
i 1	981.7391632653062	0.7575000000000001	69	1084	5	9	12	0	0	0	0	0	0	6.069590434492861	
i 1	981.7479931972789	0.2525	71	698	3	20	9	1	0	0	1	0	0	4.000000000000001	
i 1	981.7544149659864	0.2525	68	200	3	24	3	1	0	-1	1	0	0	8.0	
i 1	981.7616394557823	0.2525	75	200	5	24	11	2	0	-2	2	0	0	3.029039167451801	
i 1	981.7696666666667	0.7575000000000001	69	698	6	2	2	1	0	0	1	0	0	7.069590434492861	
i 1	981.983544217687	1.2625	75	698	5	1	13	2	0	1	2	0	0	2.029039167451801	
i 1	981.9867551020408	1.2625	69	200	6	3	2	0	0	-1	0	0	0	7.069590434492861	
i 1	981.9995986394558	1.2625	72	698	5	3	8	0	0	0	0	0	0	7.069590434492861	
i 1	982.0052176870748	0.2525	68	698	1	24	11	1	0	-1	1	0	0	8.0	
i 1	982.0084285714286	0.2525	74	698	4	5	11	16	0	2	16	0	0	2.0307099131190656	
i 1	982.0188639455782	0.2525	71	1084	2	20	1	1	0	-1	1	0	0	4.000000000000001	
i 1	982.235149659864	1.01	75	200	7	1	12	2	0	-2	2	0	0	2.029039167451801	
i 1	982.240768707483	0.2525	68	200	3	24	3	1	0	0	1	0	0	8.0	
i 1	982.2504013605442	0.2525	71	698	3	20	9	1	0	0	1	0	0	4.000000000000001	
i 1	982.2632448979592	1.7675	74	200	4	5	4	17	0	1	17	0	0	2.0307099131190656	
i 1	982.2656530612245	1.7675	74	698	4	5	8	16	0	2	16	0	0	2.0307099131190656	
i 1	982.4931768707482	1.5150000000000001	71	1084	2	20	13	0	0	-1	0	0	0	4.000000000000001	
i 1	982.5076258503401	1.01	71	698	1	24	1	0	0	-1	0	0	0	8.0	
i 1	982.514850340136	0.2525	72	1084	5	9	13	1	0	0	1	0	0	6.069590434492861	
i 1	982.7327414965987	1.2625	72	698	6	1	16	2	0	1	2	0	0	2.029039167451801	
i 1	982.7391632653062	1.7675	69	698	6	2	7	1	0	0	1	0	0	7.069590434492861	
i 1	982.740768707483	1.7675	69	1084	5	9	14	0	0	0	0	0	0	6.069590434492861	
i 1	982.7447823129252	0.2525	74	698	4	5	5	16	0	2	16	0	0	2.0307099131190656	
i 1	982.7688639455782	1.2625	72	1084	6	1	9	2	0	-2	2	0	0	2.029039167451801	
i 1	982.990768707483	1.7675	68	1084	3	20	10	0	0	-1	0	0	0	4.000000000000001	
i 1	982.9995986394558	0.2525	77	1084	3	5	2	17	0	2	17	0	0	2.0307099131190656	
i 1	983.0036122448979	0.7575000000000001	68	1084	2	20	4	0	0	-1	0	0	0	4.000000000000001	
i 1	983.2423741496599	0.2525	77	200	4	5	15	16	0	1	16	0	0	2.0307099131190656	
i 1	983.2463877551021	0.2525	72	698	4	4	12	1	0	-1	1	0	0	7.069590434492861	
i 1	983.2528095238096	1.7675	75	1084	6	1	7	2	0	-2	2	0	0	2.029039167451801	
i 1	983.4899659863945	1.7675	74	1084	3	5	9	16	0	1	16	0	0	2.0307099131190656	
i 1	983.4939795918367	1.5150000000000001	75	698	6	1	11	8	0	1	8	0	0	2.029039167451801	
i 1	983.4963877551021	1.7675	74	698	4	5	1	17	0	2	17	0	0	2.0307099131190656	
i 1	983.516455782313	0.2525	72	698	6	2	1	1	0	0	1	0	0	7.069590434492861	
i 1	983.7471904761904	0.2525	71	698	1	24	7	0	0	-1	0	0	0	8.0	
i 1	983.7560204081633	1.5150000000000001	72	1084	5	9	5	1	0	0	1	0	0	6.069590434492861	
i 1	983.9891632653062	1.5150000000000001	72	698	6	2	16	1	0	0	1	0	0	7.069590434492861	
i 1	983.9971904761904	0.2525	74	698	4	5	7	16	0	2	16	0	0	2.0307099131190656	
i 1	984.0044149659864	0.2525	71	698	3	20	5	0	0	-1	0	0	0	4.000000000000001	
i 1	984.0084285714286	0.2525	68	200	3	24	3	0	0	-1	0	0	0	8.0	
i 1	984.0100340136055	1.5150000000000001	68	698	2	20	4	0	0	0	0	0	0	4.000000000000001	
i 1	984.0132448979592	0.2525	75	200	7	1	6	2	0	-2	2	0	0	2.029039167451801	
i 1	984.2375578231292	0.2525	77	698	4	5	14	16	0	1	16	0	0	2.0307099131190656	
i 1	984.2455850340136	0.2525	71	1084	2	20	15	1	0	0	1	0	0	4.000000000000001	
i 1	984.2520068027211	0.2525	72	698	6	1	13	2	0	1	2	0	0	2.029039167451801	
i 1	984.2584285714286	1.01	71	698	1	24	15	0	0	0	0	0	0	8.0	
i 1	984.483544217687	1.01	72	698	3	24	16	2	0	-2	2	0	0	3.029039167451801	
i 1	984.4979931972789	2.02	75	200	5	24	11	2	0	-2	2	0	0	3.029039167451801	
i 1	984.509231292517	0.2525	72	698	4	4	16	1	0	-1	1	0	0	7.069590434492861	
i 1	984.5108367346938	0.2525	77	200	4	5	5	16	0	1	16	0	0	2.0307099131190656	
i 1	984.733544217687	1.7675	77	1084	3	5	3	17	0	2	17	0	0	2.0307099131190656	
i 1	984.7431768707482	2.525	71	1084	2	20	9	1	0	0	1	0	0	4.000000000000001	
i 1	984.7495986394558	1.7675	77	698	4	5	16	16	0	1	16	0	0	2.0307099131190656	
i 1	984.7520068027211	0.7575000000000001	68	1084	3	24	8	0	0	-1	0	0	0	8.0	
i 1	984.7632448979592	1.5150000000000001	69	698	6	2	16	1	0	0	1	0	0	7.069590434492861	
i 1	984.7640476190476	1.5150000000000001	69	1084	5	9	9	0	0	0	0	0	0	6.069590434492861	
i 1	985.0044149659864	0.2525	72	1084	6	1	5	2	0	-2	2	0	0	2.029039167451801	
i 1	985.2431768707482	0.2525	75	1084	6	1	14	2	0	-2	2	0	0	2.029039167451801	
i 1	985.264850340136	0.2525	74	698	4	5	9	16	0	2	16	0	0	2.0307099131190656	
i 1	985.4859523809524	26.26	61	200	6	17	4	6	0	1	6	0	0	0.8924935241881213	
i 1	985.4867551020408	0.2525	71	1084	2	20	1	1	0	-1	1	0	0	4.000000000000001	
i 1	985.5052176870748	26.26	66	698	5	12	10	9	0	0	9	0	0	1.178017605288281	
i 1	985.5116394557823	8.8375	68	1084	2	24	14	0	0	-1	0	0	0	8.0	
i 1	985.5124421768708	0.2525	72	698	5	3	12	0	0	0	0	0	0	7.069590434492861	
i 1	985.5180612244898	0.505	74	200	4	5	16	17	0	1	17	0	0	2.0307099131190656	
i 1	985.5188639455782	3.535	72	698	4	24	5	2	0	-2	2	0	0	3.029039167451801	
i 1	985.733544217687	0.2525	75	1084	6	1	3	2	0	-2	2	0	0	2.029039167451801	
i 1	985.7584285714286	1.2625	72	698	6	2	8	1	0	0	1	0	0	7.069590434492861	
i 1	985.7584285714286	0.2525	68	698	1	20	12	1	0	-1	1	0	0	4.000000000000001	
i 1	985.7688639455782	1.2625	72	1084	5	9	5	1	0	0	1	0	0	6.069590434492861	
i 1	985.9923741496599	1.5150000000000001	74	1084	3	5	10	16	0	1	16	0	0	2.0307099131190656	
i 1	985.9931768707482	1.2625	71	698	1	24	6	0	0	0	0	0	0	8.0	
i 1	985.9955850340136	1.5150000000000001	72	698	6	1	6	2	0	1	2	0	0	2.029039167451801	
i 1	986.0068231292518	1.5150000000000001	74	698	4	5	3	17	0	2	17	0	0	2.0307099131190656	
i 1	986.0108367346938	1.7675	72	1084	6	1	16	2	0	-2	2	0	0	2.029039167451801	
i 1	986.0156530612245	1.2625	68	698	2	20	13	0	0	0	0	0	0	4.000000000000001	
i 1	986.2672585034013	0.2525	72	200	5	4	2	1	0	-1	1	0	0	7.069590434492861	
i 1	986.4827414965987	0.2525	77	200	4	5	12	16	0	1	16	0	0	2.0307099131190656	
i 1	986.4867551020408	2.7775	69	1084	5	9	11	0	0	0	0	0	0	6.069590434492861	
i 1	986.5044149659864	0.7575000000000001	69	698	6	2	7	1	0	0	1	0	0	7.069590434492861	
i 1	986.7520068027211	0.505	71	1084	2	20	5	1	0	-1	1	0	0	4.000000000000001	
i 1	986.7528095238096	1.01	68	1084	3	20	14	0	0	-1	0	0	0	4.000000000000001	
i 1	986.759231292517	1.2625	74	200	4	5	14	17	0	1	17	0	0	2.0307099131190656	
i 1	986.7616394557823	1.2625	72	200	5	4	3	1	0	-1	1	0	0	7.069590434492861	
i 1	986.7616394557823	1.2625	72	698	4	4	2	1	0	-1	1	0	0	7.069590434492861	
i 1	986.9803333333333	2.02	75	200	5	24	10	2	0	-2	2	0	0	3.029039167451801	
i 1	986.9939795918367	1.2625	74	698	2	5	2	16	0	2	16	0	0	2.0307099131190656	
i 1	986.9955850340136	0.7575000000000001	71	698	2	24	6	1	0	0	1	0	0	8.0	
i 1	987.2359523809524	0.2525	68	698	3	20	15	1	0	-1	1	0	0	4.000000000000001	
i 1	987.264850340136	0.2525	71	698	3	20	10	0	0	-1	0	0	0	4.000000000000001	
i 1	987.4827414965987	2.7775	77	1084	3	5	14	17	0	2	17	0	0	2.0307099131190656	
i 1	987.4875578231292	0.2525	68	1084	2	20	7	1	0	-1	1	0	0	4.000000000000001	
i 1	987.4979931972789	2.7775	77	698	4	5	4	16	0	1	16	0	0	2.0307099131190656	
i 1	987.5012040816326	0.7575000000000001	68	1084	2	20	4	0	0	0	0	0	0	4.000000000000001	
i 1	987.5196666666667	1.7675	69	698	6	2	4	1	0	0	1	0	0	7.069590434492861	
i 1	987.7311360544218	0.505	68	698	1	24	8	0	0	-1	0	0	0	8.0	
i 1	987.7423741496599	0.2525	75	698	6	1	8	8	0	1	8	0	0	2.029039167451801	
i 1	987.7696666666667	0.7575000000000001	68	698	2	20	1	0	0	0	0	0	0	4.000000000000001	
i 1	987.9915714285714	0.7575000000000001	68	1084	3	20	10	0	0	-1	0	0	0	4.000000000000001	
i 1	988.0156530612245	0.2525	72	698	6	1	12	2	0	1	2	0	0	2.029039167451801	
i 1	988.0156530612245	0.2525	69	200	6	3	16	0	0	-1	0	0	0	7.069590434492861	
i 1	988.2399659863945	3.0300000000000002	75	200	7	1	12	2	0	-2	2	0	0	2.029039167451801	
i 1	988.2431768707482	0.2525	72	698	5	3	9	0	0	0	0	0	0	7.069590434492861	
i 1	988.2536122448979	0.2525	71	200	3	24	10	0	0	0	0	0	0	8.0	
i 1	988.2552176870748	0.2525	68	698	3	20	9	1	0	-1	1	0	0	4.000000000000001	
i 1	988.2632448979592	0.2525	74	698	4	5	1	16	0	2	16	0	0	2.0307099131190656	
i 1	988.4819387755102	0.505	71	698	1	24	12	0	0	-1	0	0	0	8.0	
i 1	988.4859523809524	1.01	75	698	5	1	11	2	0	1	2	0	0	2.029039167451801	
i 1	988.5044149659864	2.525	71	1084	2	20	5	0	0	0	0	0	0	4.000000000000001	
i 1	988.5100340136055	0.2525	72	200	5	4	8	1	0	-1	1	0	0	7.069590434492861	
i 1	988.5180612244898	0.505	74	1084	3	5	3	16	0	1	16	0	0	2.0307099131190656	
i 1	988.7431768707482	1.2625	72	698	5	3	13	0	0	0	0	0	0	7.069590434492861	
i 1	988.7640476190476	1.2625	69	200	6	3	13	0	0	-1	0	0	0	7.069590434492861	
i 1	988.9867551020408	0.7575000000000001	68	1084	3	20	2	0	0	-1	0	0	0	4.000000000000001	
i 1	989.009231292517	0.2525	74	698	4	5	1	16	0	2	16	0	0	2.0307099131190656	
i 1	989.0108367346938	0.7575000000000001	71	1084	2	20	8	0	0	0	0	0	0	4.000000000000001	
i 1	989.0140476190476	1.2625	75	1084	6	1	15	2	0	-2	2	0	0	2.029039167451801	
i 1	989.0172585034013	1.2625	75	698	6	1	12	8	0	1	8	0	0	2.029039167451801	
i 1	989.2327414965987	0.2525	72	200	5	4	10	1	0	-1	1	0	0	7.069590434492861	
i 1	989.2367551020408	0.2525	74	1084	3	5	5	16	0	1	16	0	0	2.0307099131190656	
i 1	989.2471904761904	2.02	68	698	2	20	6	0	0	0	0	0	0	4.000000000000001	
i 1	989.266455782313	1.7675	71	698	1	24	1	0	0	-1	0	0	0	8.0	
i 1	989.4979931972789	6.3125	69	698	6	2	15	1	0	0	1	0	0	7.069590434492861	
i 1	989.5012040816326	0.2525	74	698	4	5	3	17	0	2	17	0	0	2.0307099131190656	
i 1	989.514850340136	1.5150000000000001	69	1084	5	9	6	0	0	0	0	0	0	6.069590434492861	
i 1	989.7552176870748	0.7575000000000001	74	698	2	5	12	16	0	2	16	0	0	2.0307099131190656	
i 1	989.7624421768708	1.5150000000000001	75	698	5	1	11	2	0	1	2	0	0	2.029039167451801	
i 1	989.7688639455782	1.01	74	200	4	5	9	17	0	1	17	0	0	2.0307099131190656	
i 1	990.0012040816326	4.545	74	1084	3	5	6	16	0	1	16	0	0	2.0307099131190656	
i 1	990.0076258503401	4.545	74	698	4	5	6	17	0	2	17	0	0	2.0307099131190656	
i 1	990.0196666666667	0.2525	72	698	4	4	13	1	0	-1	1	0	0	7.069590434492861	
i 1	990.240768707483	2.525	72	1084	5	9	8	1	0	0	1	0	0	6.069590434492861	
i 1	990.2495986394558	0.2525	72	1084	6	1	3	2	0	-2	2	0	0	2.029039167451801	
i 1	990.4899659863945	1.7675	72	698	6	2	3	1	0	0	1	0	0	7.069590434492861	
i 1	990.5052176870748	0.2525	75	200	5	24	5	2	0	-2	2	0	0	3.029039167451801	
i 1	990.7423741496599	2.02	72	1084	6	1	10	2	0	-2	2	0	0	2.029039167451801	
i 1	990.7431768707482	1.5150000000000001	68	1084	3	20	14	0	0	-1	0	0	0	4.000000000000001	
i 1	990.764850340136	0.2525	74	698	2	5	11	16	0	2	16	0	0	2.0307099131190656	
i 1	990.766455782313	2.02	72	698	6	1	11	2	0	1	2	0	0	2.029039167451801	
i 1	990.983544217687	0.2525	68	698	3	20	13	1	0	-1	1	0	0	4.000000000000001	
i 1	990.9859523809524	0.2525	68	698	3	20	6	0	0	-1	0	0	0	4.000000000000001	
i 1	991.0140476190476	0.2525	71	200	3	24	4	1	0	-1	1	0	0	8.0	
i 1	991.016455782313	0.2525	77	1084	3	5	15	17	0	2	17	0	0	2.0307099131190656	
i 1	991.2343469387755	0.2525	75	1084	6	1	3	2	0	-2	2	0	0	2.029039167451801	
i 1	991.2439795918367	0.2525	71	698	1	24	3	1	0	-1	1	0	0	8.0	
i 1	991.259231292517	0.2525	71	1084	2	20	6	1	0	-1	1	0	0	4.000000000000001	
i 1	991.2608367346938	0.2525	68	1084	2	20	4	1	0	0	1	0	0	4.000000000000001	
i 1	991.2616394557823	1.5150000000000001	71	698	2	24	7	1	0	0	1	0	0	8.0	
i 1	991.266455782313	0.7575000000000001	69	1084	5	9	12	0	0	0	0	0	0	6.069590434492861	
i 1	991.5060204081633	0.2525	75	200	5	24	2	2	0	-2	2	0	0	3.029039167451801	
i 1	991.5084285714286	0.505	71	698	3	20	7	1	0	-1	1	0	0	4.000000000000001	
i 1	991.5188639455782	0.505	68	698	3	20	5	0	0	0	0	0	0	4.000000000000001	
i 1	991.990768707483	0.2525	77	200	4	5	13	16	0	1	16	0	0	2.0307099131190656	
i 1	991.9947823129252	0.2525	68	1084	2	20	3	0	0	-1	0	0	0	4.000000000000001	
i 1	992.0028095238096	0.2525	68	1084	2	20	16	0	0	-1	0	0	0	4.000000000000001	
i 1	992.0116394557823	0.2525	75	200	5	24	7	2	0	-2	2	0	0	3.029039167451801	
i 1	992.2303333333333	0.2525	71	698	3	20	12	0	0	-1	0	0	0	4.000000000000001	
i 1	992.2327414965987	0.2525	71	698	3	20	12	1	0	0	1	0	0	4.000000000000001	
i 1	992.2359523809524	0.505	72	698	5	2	16	1	0	0	1	0	0	7.069590434492861	
i 1	992.240768707483	0.7575000000000001	68	1084	2	20	15	0	0	-1	0	0	0	4.000000000000001	
i 1	992.2423741496599	19.4425	61	200	6	17	11	6	0	1	6	0	0	0.8924935241881213	
i 1	992.2439795918367	1.7675	75	698	6	1	8	8	0	1	8	0	0	2.029039167451801	
i 1	992.2528095238096	1.5150000000000001	75	1084	6	1	2	2	0	-2	2	0	0	2.029039167451801	
i 1	992.2536122448979	19.4425	61	698	3	27	12	9	0	0	9	0	0	1.7216435423119565	
i 1	992.259231292517	19.4425	66	1084	4	16	4	6	0	1	6	0	0	1.178017605288281	
i 1	992.2624421768708	1.01	77	698	4	5	11	16	0	1	16	0	0	2.0307099131190656	
i 1	992.2632448979592	1.5150000000000001	77	1084	3	5	4	17	0	2	17	0	0	2.0307099131190656	
i 1	992.2696666666667	1.7675	69	1084	5	9	16	0	0	0	0	0	0	6.069590434492861	
i 1	992.5068231292518	0.505	71	1084	2	20	2	0	0	0	0	0	0	4.000000000000001	
i 1	992.5084285714286	1.5150000000000001	71	1084	2	20	3	1	0	0	1	0	0	4.000000000000001	
i 1	992.7584285714286	0.2525	75	698	5	1	2	2	0	1	2	0	0	2.029039167451801	
i 1	992.7632448979592	0.505	69	200	6	3	12	0	0	-1	0	0	0	7.069590434492861	
i 1	993.0012040816326	0.2525	68	698	2	20	9	0	0	0	0	0	0	4.000000000000001	
i 1	993.009231292517	3.535	75	200	5	24	16	2	0	-2	2	0	0	3.029039167451801	
i 1	993.2319387755102	10.352500000000001	68	1084	2	20	15	0	0	-1	0	0	0	4.000000000000001	
i 1	993.2447823129252	3.2825	72	698	4	24	7	2	0	-2	2	0	0	3.029039167451801	
i 1	993.2584285714286	0.2525	72	698	5	2	3	1	0	0	1	0	0	7.069590434492861	
i 1	993.2640476190476	0.7575000000000001	71	1084	2	20	2	0	0	0	0	0	0	4.000000000000001	
i 1	993.509231292517	1.2625	72	200	5	4	16	1	0	-1	1	0	0	7.069590434492861	
i 1	993.5180612244898	1.2625	72	698	4	4	15	1	0	-1	1	0	0	7.069590434492861	
i 1	993.7303333333333	0.2525	74	698	3	5	3	16	0	2	16	0	0	2.0307099131190656	
i 1	993.7383605442177	0.7575000000000001	71	698	2	24	14	1	0	0	1	0	0	8.0	
i 1	994.0028095238096	0.2525	72	698	6	1	13	2	0	1	2	0	0	2.029039167451801	
i 1	994.0044149659864	0.2525	68	698	3	20	16	0	0	0	0	0	0	4.000000000000001	
i 1	994.0100340136055	1.5150000000000001	74	698	2	5	2	16	0	2	16	0	0	2.0307099131190656	
i 1	994.0100340136055	0.2525	68	698	3	20	12	1	0	0	1	0	0	4.000000000000001	
i 1	994.014850340136	1.5150000000000001	74	200	4	5	10	17	0	1	17	0	0	2.0307099131190656	
i 1	994.2319387755102	0.2525	72	1084	6	1	16	2	0	-2	2	0	0	2.029039167451801	
i 1	994.2391632653062	0.7575000000000001	71	1084	2	20	14	1	0	-1	1	0	0	4.000000000000001	
i 1	994.2576258503401	0.7575000000000001	68	1084	2	20	15	1	0	-1	1	0	0	4.000000000000001	
i 1	994.2688639455782	1.5150000000000001	69	1084	5	9	6	0	0	0	0	0	0	6.069590434492861	
i 1	994.4811360544218	0.7575000000000001	68	698	2	20	4	0	0	0	0	0	0	4.000000000000001	
i 1	994.4843469387755	0.2525	77	698	4	5	14	16	0	1	16	0	0	2.0307099131190656	
i 1	994.485149659864	0.2525	75	698	5	1	12	2	0	1	2	0	0	2.029039167451801	
i 1	994.4963877551021	1.5150000000000001	68	1084	2	24	1	0	0	-1	0	0	0	8.0	
i 1	994.5156530612245	0.505	68	698	1	24	15	0	0	-1	0	0	0	8.0	
i 1	994.7367551020408	0.2525	77	200	4	5	14	16	0	1	16	0	0	2.0307099131190656	
i 1	994.7584285714286	1.2625	72	1084	6	1	5	2	0	-2	2	0	0	2.029039167451801	
i 1	994.766455782313	1.01	72	698	6	1	8	2	0	1	2	0	0	2.029039167451801	
i 1	994.7680612244898	0.2525	69	200	6	3	2	0	0	-1	0	0	0	7.069590434492861	
i 1	994.9867551020408	0.2525	71	200	3	24	3	0	0	-1	0	0	0	8.0	
i 1	994.9931768707482	1.2625	71	698	2	24	4	1	0	0	1	0	0	8.0	
i 1	995.0020068027211	2.02	77	698	4	5	7	16	0	1	16	0	0	2.0307099131190656	
i 1	995.0020068027211	0.505	71	698	3	20	2	0	0	0	0	0	0	4.000000000000001	
i 1	995.0060204081633	2.02	77	1084	3	5	3	17	0	2	17	0	0	2.0307099131190656	
i 1	995.0068231292518	0.2525	72	698	4	4	8	1	0	-1	1	0	0	7.069590434492861	
i 1	995.0076258503401	0.505	71	698	3	20	16	1	0	0	1	0	0	4.000000000000001	
i 1	995.235149659864	1.2625	72	698	5	3	5	0	0	0	0	0	0	7.069590434492861	
i 1	995.2656530612245	1.2625	69	200	6	3	12	0	0	-1	0	0	0	7.069590434492861	
i 1	995.485149659864	0.2525	77	200	4	5	12	16	0	1	16	0	0	2.0307099131190656	
i 1	995.4883605442177	0.2525	71	1084	2	20	3	0	0	0	0	0	0	4.000000000000001	
i 1	995.5012040816326	0.2525	71	1084	2	20	7	0	0	-1	0	0	0	4.000000000000001	
i 1	995.7327414965987	0.2525	71	698	3	20	10	0	0	0	0	0	0	4.000000000000001	
i 1	995.7544149659864	0.2525	72	200	5	4	1	1	0	-1	1	0	0	7.069590434492861	
i 1	995.7544149659864	0.505	74	698	2	5	14	16	0	2	16	0	0	2.0307099131190656	
i 1	995.7640476190476	0.2525	71	698	3	20	14	1	0	0	1	0	0	4.000000000000001	
i 1	995.9827414965987	0.7575000000000001	69	698	6	2	13	1	0	0	1	0	0	7.069590434492861	
i 1	995.9931768707482	1.5150000000000001	75	200	7	1	4	2	0	-2	2	0	0	2.029039167451801	
i 1	996.0068231292518	2.02	75	698	5	1	1	2	0	1	2	0	0	2.029039167451801	
i 1	996.0124421768708	0.7575000000000001	68	1084	2	20	4	1	0	0	1	0	0	4.000000000000001	
i 1	996.0188639455782	0.7575000000000001	69	1084	5	9	13	0	0	0	0	0	0	6.069590434492861	
i 1	996.233544217687	0.2525	74	1084	3	5	13	16	0	1	16	0	0	2.0307099131190656	
i 1	996.2375578231292	1.2625	72	1084	5	9	11	1	0	0	1	0	0	6.069590434492861	
i 1	996.2471904761904	0.2525	68	698	2	20	8	0	0	0	0	0	0	4.000000000000001	
i 1	996.2600340136055	1.2625	72	698	5	2	16	1	0	0	1	0	0	7.069590434492861	
i 1	996.4811360544218	1.01	71	698	2	24	10	1	0	0	1	0	0	8.0	
i 1	996.4867551020408	1.5150000000000001	74	200	4	5	12	17	0	1	17	0	0	2.0307099131190656	
i 1	996.4891632653062	1.5150000000000001	74	698	2	5	1	16	0	2	16	0	0	2.0307099131190656	
i 1	996.5124421768708	0.2525	72	698	6	1	9	2	0	1	2	0	0	2.029039167451801	
i 1	996.7383605442177	0.2525	72	1084	6	1	7	2	0	-2	2	0	0	2.029039167451801	
i 1	996.7487959183674	0.505	68	698	3	20	14	0	0	0	0	0	0	4.000000000000001	
i 1	996.764850340136	0.2525	72	698	4	4	6	1	0	-1	1	0	0	7.069590434492861	
i 1	996.9955850340136	2.02	75	1084	6	1	8	2	0	-2	2	0	0	2.029039167451801	
i 1	997.0108367346938	1.7675	69	1084	5	9	7	0	0	0	0	0	0	6.069590434492861	
i 1	997.0140476190476	2.02	75	698	6	1	4	8	0	1	8	0	0	2.029039167451801	
i 1	997.014850340136	1.7675	69	698	6	2	7	1	0	0	1	0	0	7.069590434492861	
i 1	997.0156530612245	0.2525	74	698	4	5	7	17	0	2	17	0	0	2.0307099131190656	
i 1	997.2512040816326	2.525	74	1084	3	5	8	16	0	1	16	0	0	2.0307099131190656	
i 1	997.2520068027211	0.7575000000000001	71	698	1	24	6	0	0	0	0	0	0	8.0	
i 1	997.2544149659864	1.01	68	698	2	20	2	0	0	0	0	0	0	4.000000000000001	
i 1	997.2560204081633	1.5150000000000001	71	1084	2	20	3	1	0	-1	1	0	0	4.000000000000001	
i 1	997.5020068027211	0.2525	69	200	6	3	3	0	0	-1	0	0	0	7.069590434492861	
i 1	997.509231292517	2.2725	74	698	4	5	16	17	0	2	17	0	0	2.0307099131190656	
i 1	997.7616394557823	0.2525	72	698	5	3	2	0	0	0	0	0	0	7.069590434492861	
i 1	997.9867551020408	0.2525	72	1084	6	1	9	2	0	-2	2	0	0	2.029039167451801	
i 1	998.0004013605442	0.2525	72	200	5	4	14	1	0	-1	1	0	0	7.069590434492861	
i 1	998.0116394557823	0.2525	77	698	4	5	2	16	0	1	16	0	0	2.0307099131190656	
i 1	998.233544217687	0.2525	72	698	4	24	11	2	0	-2	2	0	0	3.029039167451801	
i 1	998.2423741496599	0.2525	71	698	1	24	12	0	0	0	0	0	0	8.0	
i 1	998.2431768707482	1.2625	72	698	5	2	11	1	0	0	1	0	0	7.069590434492861	
i 1	998.2536122448979	0.2525	77	200	4	5	2	16	0	1	16	0	0	2.0307099131190656	
i 1	998.2544149659864	1.2625	72	1084	5	9	13	1	0	0	1	0	0	6.069590434492861	
i 1	998.483544217687	1.5150000000000001	75	698	5	1	5	2	0	1	2	0	0	2.029039167451801	
i 1	998.4931768707482	1.5150000000000001	75	200	7	1	12	2	0	-2	2	0	0	2.029039167451801	
i 1	998.4947823129252	0.505	71	698	2	24	13	1	0	0	1	0	0	8.0	
i 1	998.7552176870748	0.2525	72	200	5	4	2	1	0	-1	1	0	0	7.069590434492861	
i 1	998.766455782313	0.2525	68	698	3	20	4	1	0	0	1	0	0	4.000000000000001	
i 1	998.9819387755102	1.5150000000000001	69	698	5	2	14	1	0	0	1	0	0	7.069590434492861	
i 1	998.9891632653062	0.2525	74	698	2	5	16	16	0	2	16	0	0	2.0307099131190656	
i 1	998.9915714285714	1.5150000000000001	69	1084	5	9	10	0	0	0	0	0	0	6.069590434492861	
i 1	998.9931768707482	0.7575000000000001	68	1084	2	20	10	1	0	0	1	0	0	4.000000000000001	
i 1	998.9963877551021	12.625	66	698	3	27	11	6	0	0	6	0	0	1.7216435423119565	
i 1	998.9987959183674	12.625	61	698	6	17	3	6	0	1	6	0	0	0.8924935241881213	
i 1	999.0036122448979	0.2525	75	200	5	24	15	2	0	-2	2	0	0	3.029039167451801	
i 1	999.0108367346938	0.2525	71	698	1	24	10	1	0	0	1	0	0	8.0	
i 1	999.0132448979592	12.625	61	1084	4	16	12	9	0	0	9	0	0	1.178017605288281	
i 1	999.014850340136	12.625	61	1084	4	18	11	9	0	0	9	0	0	0.8924935241881213	
i 1	999.2359523809524	1.5150000000000001	77	1084	3	5	15	17	0	2	17	0	0	2.0307099131190656	
i 1	999.2520068027211	1.5150000000000001	77	698	4	5	12	16	0	1	16	0	0	2.0307099131190656	
i 1	999.2536122448979	0.505	68	698	1	24	14	0	0	-1	0	0	0	8.0	
i 1	999.2568231292518	2.2725	72	698	6	1	6	2	0	1	2	0	0	2.029039167451801	
i 1	999.2608367346938	0.7575000000000001	68	698	2	20	4	0	0	0	0	0	0	4.000000000000001	
i 1	999.483544217687	0.2525	71	1084	2	20	12	0	0	-1	0	0	0	4.000000000000001	
i 1	999.4867551020408	2.02	72	1084	6	1	7	2	0	-2	2	0	0	2.029039167451801	
i 1	999.4995986394558	0.505	72	698	5	3	1	0	0	0	0	0	0	7.069590434492861	
i 1	999.5188639455782	0.7575000000000001	68	1084	2	24	12	0	0	-1	0	0	0	8.0	
i 1	999.7311360544218	0.505	68	200	3	24	11	1	0	-1	1	0	0	8.0	
i 1	999.7487959183674	3.7875	71	698	1	24	12	1	0	0	1	0	0	8.0	
i 1	999.7528095238096	0.505	71	698	3	20	6	1	0	0	1	0	0	4.000000000000001	
i 1	999.7608367346938	0.505	68	698	3	20	5	1	0	-1	1	0	0	4.000000000000001	
i 1	999.7672585034013	0.2525	77	200	4	5	15	16	0	1	16	0	0	2.0307099131190656	
i 1	999.9811360544218	0.2525	74	698	3	5	5	16	0	2	16	0	0	2.0307099131190656	
i 1	999.9915714285714	1.2625	72	200	5	4	9	1	0	-1	1	0	0	7.069590434492861	
i 1	999.9971904761904	0.2525	75	1084	6	1	10	2	0	-2	2	0	0	2.029039167451801	
i 1	1000.014850340136	1.2625	72	698	4	4	7	1	0	-1	1	0	0	7.069590434492861	
i 1	1000.2423741496599	0.505	75	200	7	1	2	2	0	-2	2	0	0	2.029039167451801	
i 1	1000.2495986394558	1.01	74	698	4	5	8	17	0	2	17	0	0	2.0307099131190656	
i 1	1000.2640476190476	0.7575000000000001	74	1084	3	5	9	16	0	1	16	0	0	2.0307099131190656	
i 1	1000.266455782313	0.2525	68	1084	2	20	16	0	0	0	0	0	0	4.000000000000001	
i 1	1000.4923741496599	1.7675	74	698	2	5	16	16	0	2	16	0	0	2.0307099131190656	
i 1	1000.4939795918367	0.2525	71	698	3	20	7	1	0	0	1	0	0	4.000000000000001	
i 1	1000.4987959183674	0.2525	71	698	3	20	10	1	0	0	1	0	0	4.000000000000001	
i 1	1000.5004013605442	0.2525	72	698	5	2	11	1	0	0	1	0	0	7.069590434492861	
i 1	1000.5180612244898	1.7675	74	200	4	5	15	17	0	1	17	0	0	2.0307099131190656	
i 1	1000.5180612244898	1.7675	68	1084	2	24	2	0	0	-1	0	0	0	8.0	
i 1	1000.7327414965987	0.505	68	1084	2	20	15	0	0	-1	0	0	0	4.000000000000001	
i 1	1000.7439795918367	0.7575000000000001	69	698	5	2	13	1	0	0	1	0	0	7.069590434492861	
i 1	1000.7520068027211	0.505	68	1084	2	20	15	0	0	0	0	0	0	4.000000000000001	
i 1	1000.7528095238096	0.7575000000000001	69	1084	5	9	2	0	0	0	0	0	0	6.069590434492861	
i 1	1000.7640476190476	1.2625	75	698	6	1	2	8	0	1	8	0	0	2.029039167451801	
i 1	1000.9915714285714	1.2625	75	1084	6	1	10	2	0	-2	2	0	0	2.029039167451801	
i 1	1001.0036122448979	1.2625	69	200	6	3	16	0	0	-1	0	0	0	7.069590434492861	
i 1	1001.0076258503401	1.5150000000000001	72	698	5	3	15	0	0	0	0	0	0	7.069590434492861	
i 1	1001.2423741496599	0.2525	71	698	3	20	3	0	0	-1	0	0	0	4.000000000000001	
i 1	1001.2520068027211	0.2525	77	1084	3	5	14	17	0	2	17	0	0	2.0307099131190656	
i 1	1001.2552176870748	0.2525	68	698	3	20	12	0	0	0	0	0	0	4.000000000000001	
i 1	1001.2600340136055	0.2525	71	200	3	20	15	0	0	0	0	0	0	4.000000000000001	
i 1	1001.4803333333333	0.7575000000000001	68	1084	2	20	1	0	0	0	0	0	0	4.000000000000001	
i 1	1001.4859523809524	1.2625	72	698	4	24	2	2	0	-2	2	0	0	3.029039167451801	
i 1	1001.4859523809524	0.7575000000000001	68	698	2	20	1	0	0	0	0	0	0	4.000000000000001	
i 1	1001.4891632653062	3.535	71	1084	2	20	8	1	0	0	1	0	0	4.000000000000001	
i 1	1001.4987959183674	0.7575000000000001	71	698	1	24	11	1	0	-1	1	0	0	8.0	
i 1	1001.5012040816326	0.2525	72	200	5	4	16	1	0	-1	1	0	0	7.069590434492861	
i 1	1001.5028095238096	2.02	71	698	1	20	14	0	0	-1	0	0	0	4.000000000000001	
i 1	1001.5076258503401	0.2525	74	1084	3	5	14	16	0	1	16	0	0	2.0307099131190656	
i 1	1001.5132448979592	1.2625	75	200	5	24	6	2	0	-2	2	0	0	3.029039167451801	
i 1	1001.7423741496599	2.02	77	1084	3	5	6	17	0	2	17	0	0	2.0307099131190656	
i 1	1001.7487959183674	1.7675	69	1084	5	9	8	0	0	0	0	0	0	6.069590434492861	
i 1	1001.7576258503401	1.7675	69	698	5	2	3	1	0	0	1	0	0	7.069590434492861	
i 1	1001.759231292517	2.525	77	698	4	5	2	16	0	1	16	0	0	2.0307099131190656	
i 1	1002.2319387755102	0.2525	74	698	3	5	16	16	0	2	16	0	0	2.0307099131190656	
i 1	1002.2479931972789	1.5150000000000001	72	698	6	1	5	2	0	1	2	0	0	2.029039167451801	
i 1	1002.2560204081633	1.5150000000000001	72	1084	6	1	14	2	0	-2	2	0	0	2.029039167451801	
i 1	1002.4827414965987	0.2525	69	200	6	3	7	0	0	-1	0	0	0	7.069590434492861	
i 1	1002.4955850340136	0.2525	77	200	4	5	10	16	0	1	16	0	0	2.0307099131190656	
i 1	1002.7327414965987	0.2525	75	698	6	1	13	8	0	1	8	0	0	2.029039167451801	
i 1	1002.7520068027211	0.2525	72	200	5	4	5	1	0	-1	1	0	0	7.069590434492861	
i 1	1002.9843469387755	0.2525	74	1084	3	5	15	16	0	1	16	0	0	2.0307099131190656	
i 1	1002.985149659864	2.02	71	698	1	24	15	1	0	-1	1	0	0	8.0	
i 1	1002.9939795918367	0.2525	75	698	5	1	7	2	0	1	2	0	0	2.029039167451801	
i 1	1002.9963877551021	1.2625	72	1084	5	9	1	1	0	0	1	0	0	6.069590434492861	
i 1	1003.0060204081633	1.2625	72	698	5	2	13	1	0	0	1	0	0	7.069590434492861	
i 1	1003.0068231292518	2.525	68	698	2	20	12	0	0	0	0	0	0	4.000000000000001	
i 1	1003.2327414965987	2.02	75	200	5	24	15	2	0	-2	2	0	0	3.029039167451801	
i 1	1003.2375578231292	1.7675	74	698	2	5	4	16	0	2	16	0	0	2.0307099131190656	
i 1	1003.2423741496599	1.7675	74	200	4	5	2	17	0	1	17	0	0	2.0307099131190656	
i 1	1003.2455850340136	2.02	72	698	4	24	8	2	0	-2	2	0	0	3.029039167451801	
i 1	1003.5068231292518	0.2525	72	698	4	4	11	1	0	-1	1	0	0	7.069590434492861	
i 1	1003.7383605442177	1.5150000000000001	69	698	5	2	11	1	0	0	1	0	0	7.069590434492861	
i 1	1003.7463877551021	0.2525	75	698	5	1	2	2	0	1	2	0	0	2.029039167451801	
i 1	1003.7512040816326	1.5150000000000001	69	1084	5	9	12	0	0	0	0	0	0	6.069590434492861	
i 1	1003.9803333333333	1.2625	68	1084	2	24	6	0	0	-1	0	0	0	8.0	
i 1	1003.9931768707482	1.01	68	1084	2	20	16	0	0	0	0	0	0	4.000000000000001	
i 1	1004.0028095238096	1.5150000000000001	68	1084	2	20	9	0	0	-1	0	0	0	4.000000000000001	
i 1	1004.0068231292518	0.505	72	698	6	1	2	2	0	1	2	0	0	2.029039167451801	
i 1	1004.2568231292518	0.2525	77	1084	3	5	14	17	0	2	17	0	0	2.0307099131190656	
i 1	1004.2656530612245	0.2525	72	698	5	3	12	0	0	0	0	0	0	7.069590434492861	
i 1	1004.4875578231292	1.01	75	200	7	1	12	2	0	-2	2	0	0	2.029039167451801	
i 1	1004.5100340136055	1.01	74	1084	3	5	13	16	0	1	16	0	0	2.0307099131190656	
i 1	1004.5196666666667	0.2525	69	200	6	3	11	0	0	-1	0	0	0	7.069590434492861	
i 1	1004.5196666666667	1.01	74	698	4	5	15	17	0	2	17	0	0	2.0307099131190656	
i 1	1004.7391632653062	0.7575000000000001	72	1084	5	9	15	1	0	0	1	0	0	6.069590434492861	
i 1	1004.7487959183674	0.7575000000000001	75	698	5	1	3	2	0	1	2	0	0	2.029039167451801	
i 1	1004.7600340136055	0.7575000000000001	72	698	5	2	15	1	0	0	1	0	0	7.069590434492861	
i 1	1004.9883605442177	0.505	68	200	3	20	12	1	0	-1	1	0	0	4.000000000000001	
i 1	1005.0060204081633	0.505	77	200	4	5	15	16	0	1	16	0	0	2.0307099131190656	
i 1	1005.0084285714286	0.505	71	698	3	20	2	0	0	-1	0	0	0	4.000000000000001	
i 1	1005.0124421768708	0.2525	68	200	3	24	1	0	0	-1	0	0	0	8.0	
i 1	1005.2359523809524	0.2525	68	698	3	20	9	1	0	-1	1	0	0	4.000000000000001	
i 1	1005.240768707483	0.2525	71	698	1	24	9	1	0	0	1	0	0	8.0	
i 1	1005.2415714285714	0.2525	75	1084	6	1	12	2	0	-2	2	0	0	2.029039167451801	
i 1	1005.2672585034013	0.2525	72	698	5	3	11	0	0	0	0	0	0	7.069590434492861	
i 1	1005.733544217687	5.8075	61	698	6	17	13	9	0	0	9	0	0	0.8924935241881213	
i 1	1005.7439795918367	5.8075	61	698	3	12	12	9	0	0	9	0	0	1.178017605288281	
i 1	1005.7696666666667	5.8075	66	1084	4	18	7	6	0	1	6	0	0	0.8924935241881213	
t0 118
</CsScore>
</CsoundSynthesizer>

