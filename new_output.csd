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
i 1	0.0013265306122448983	0.505	74	200	7	1	5	16	0	2	16	0	0	5.0	
i 1	0.002142857142857143	1.01	74	200	5	5	8	16	0	2	16	0	0	9.0	
i 1	0.0025510204081632655	0.2525	69	698	5	9	13	1	0	-1	1	0	0	8.0	
i 1	0.0029591836734693877	0.2525	77	698	6	5	3	17	0	2	17	0	0	9.0	
i 1	0.003979591836734694	0.7575000000000001	74	698	1	24	10	2	0	1	2	0	0	4.0	
i 1	0.004591836734693878	0.2525	74	698	4	24	6	17	0	2	17	0	0	6.0	
i 1	0.004591836734693878	1.01	72	200	4	2	10	0	0	-1	0	0	0	9.0	
i 1	0.24581632653061225	0.2525	74	1084	4	5	4	16	0	1	16	0	0	9.0	
i 1	0.25112244897959185	0.2525	72	698	3	9	6	1	0	-1	1	0	0	8.0	
i 1	0.25316326530612243	0.505	74	698	5	1	14	17	0	1	17	0	0	5.0	
i 1	0.4976530612244898	0.2525	77	200	5	5	16	16	0	1	16	0	0	9.0	
i 1	0.5029591836734694	0.2525	69	1084	5	3	15	1	0	0	1	0	0	9.0	
i 1	0.5035714285714286	1.5150000000000001	77	200	7	1	12	17	0	1	17	0	0	5.0	
i 1	0.7454081632653061	0.2525	77	698	6	5	2	17	0	2	17	0	0	9.0	
i 1	0.7476530612244898	0.2525	71	698	1	24	15	8	0	1	8	0	0	4.0	
i 1	0.7492857142857143	0.2525	74	200	7	1	1	16	0	2	16	0	0	5.0	
i 1	0.7533673469387755	0.2525	72	1084	4	4	16	1	0	-1	1	0	0	9.0	
i 1	0.9962244897959184	0.505	74	698	1	24	6	2	0	1	2	0	0	4.0	
i 1	0.9964285714285714	0.2525	74	1084	4	5	2	16	0	1	16	0	0	9.0	
i 1	1.001326530612245	1.5150000000000001	69	200	4	2	11	0	0	-1	0	0	0	9.0	
i 1	1.0031632653061224	0.505	74	1084	4	24	7	16	0	2	16	0	0	6.0	
i 1	1.0041836734693879	0.2525	74	200	7	5	11	16	0	2	16	0	0	9.0	
i 1	1.004591836734694	0.505	69	698	3	4	11	0	0	-1	0	0	0	9.0	
i 1	1.2456122448979592	0.2525	77	200	5	5	8	16	0	1	16	0	0	9.0	
i 1	1.2456122448979592	0.505	77	698	4	5	12	17	0	2	17	0	0	9.0	
i 1	1.495	0.2525	77	200	7	5	13	16	0	1	16	0	0	9.0	
i 1	1.4964285714285714	0.2525	69	698	5	9	2	1	0	-1	1	0	0	8.0	
i 1	1.501734693877551	0.2525	74	1084	4	24	16	16	0	2	16	0	0	6.0	
i 1	1.504591836734694	0.2525	71	698	1	24	16	8	0	1	8	0	0	4.0	
i 1	1.748061224489796	0.2525	74	698	4	1	12	17	0	1	17	0	0	5.0	
i 1	1.7492857142857143	0.2525	77	698	4	5	5	17	0	2	17	0	0	9.0	
i 1	1.7527551020408163	0.7575000000000001	74	1084	4	5	6	16	0	1	16	0	0	9.0	
i 1	1.755	0.2525	72	698	5	9	16	1	0	-1	1	0	0	8.0	
i 1	1.9992857142857143	0.2525	77	200	7	5	9	16	0	1	16	0	0	9.0	
i 1	1.9994897959183673	0.2525	74	698	6	1	16	17	0	1	17	0	0	5.0	
i 1	2.0005102040816327	0.2525	69	698	4	4	10	0	0	-1	0	0	0	9.0	
i 1	2.0047959183673467	0.505	74	1084	4	24	9	16	0	2	16	0	0	6.0	
i 1	2.248061224489796	0.2525	74	200	7	1	16	16	0	2	16	0	0	5.0	
i 1	2.2527551020408163	0.2525	69	1084	3	3	15	1	0	0	1	0	0	9.0	
i 1	2.2541836734693876	0.2525	74	698	4	5	7	16	0	2	16	0	0	9.0	
i 1	2.495	0.2525	74	384	4	24	13	16	0	2	16	0	0	6.0	
i 1	2.4968367346938773	0.505	74	700	6	5	12	16	0	2	16	0	0	9.0	
i 1	2.497448979591837	1.01	69	384	4	3	12	1	0	-1	1	0	0	9.0	
i 1	2.498061224489796	0.2525	69	1086	3	9	8	0	0	-1	0	0	0	8.0	
i 1	2.500714285714286	0.505	74	700	6	1	10	17	0	1	17	0	0	5.0	
i 1	2.501938775510204	1.5150000000000001	77	700	6	5	2	16	0	1	16	0	0	9.0	
i 1	2.7501020408163264	0.2525	77	700	6	1	15	17	0	1	17	0	0	5.0	
i 1	2.752551020408163	0.2525	69	384	4	4	16	0	0	-1	0	0	0	9.0	
i 1	2.9952040816326533	0.2525	74	384	6	5	6	17	0	2	17	0	0	9.0	
i 1	2.9968367346938773	0.2525	72	700	5	2	4	0	0	0	0	0	0	9.0	
i 1	2.9976530612244896	1.01	74	700	6	1	14	17	0	1	17	0	0	5.0	
i 1	2.999285714285714	0.2525	74	384	4	24	4	16	0	2	16	0	0	6.0	
i 1	3.248061224489796	0.2525	74	384	6	1	16	16	0	1	16	0	0	5.0	
i 1	3.2503061224489795	0.505	72	384	4	4	4	0	0	-1	0	0	0	9.0	
i 1	3.2547959183673467	0.2525	77	384	4	5	16	17	0	2	17	0	0	9.0	
i 1	3.4994897959183673	0.2525	74	1086	6	5	2	17	0	2	17	0	0	9.0	
i 1	3.501530612244898	0.505	74	384	6	1	4	16	0	2	16	0	0	5.0	
i 1	3.5031632653061227	0.505	69	384	5	3	2	1	0	-1	1	0	0	9.0	
i 1	3.751326530612245	0.2525	69	384	3	4	16	0	0	-1	0	0	0	9.0	
i 1	3.751326530612245	0.2525	74	384	6	5	16	16	0	2	16	0	0	9.0	
i 1	3.997448979591837	0.2525	72	700	5	2	12	0	0	0	0	0	0	9.0	
i 1	3.998061224489796	1.01	72	700	5	2	5	1	0	-1	1	0	0	9.0	
i 1	3.9994897959183673	0.2525	74	384	6	1	8	16	0	1	16	0	0	5.0	
i 1	4.000918367346939	0.505	74	700	4	24	4	16	0	1	16	0	0	6.0	
i 1	4.001530612244898	0.505	74	384	6	5	16	16	0	1	16	0	0	9.0	
i 1	4.003571428571429	1.01	77	700	6	5	5	17	0	1	17	0	0	9.0	
i 1	4.24765306122449	0.2525	69	384	3	3	13	1	0	-1	1	0	0	9.0	
i 1	4.254795918367347	0.2525	77	700	6	1	6	17	0	1	17	0	0	5.0	
i 1	4.4992857142857146	0.2525	74	700	6	5	11	16	0	2	16	0	0	9.0	
i 1	4.5019387755102045	0.7575000000000001	74	700	4	24	5	16	0	1	16	0	0	6.0	
i 1	4.5019387755102045	0.2525	72	1086	4	9	16	1	0	0	1	0	0	8.0	
i 1	4.502755102040816	0.2525	74	1086	6	1	12	16	0	2	16	0	0	5.0	
i 1	4.7480612244897955	0.2525	77	384	6	5	13	17	0	2	17	0	0	9.0	
i 1	4.752142857142857	0.2525	72	700	5	2	14	0	0	0	0	0	0	9.0	
i 1	4.7539795918367345	0.2525	74	384	6	1	16	16	0	1	16	0	0	5.0	
i 1	4.9960204081632655	0.505	74	904	6	1	7	17	0	2	17	0	0	5.0	
i 1	4.996836734693877	0.2525	74	202	7	5	3	17	0	2	17	0	0	9.0	
i 1	4.997040816326531	0.2525	69	202	5	9	8	1	0	0	1	0	0	8.0	
i 1	5.000918367346939	1.2625	69	700	5	3	15	1	0	0	1	0	0	9.0	
i 1	5.003571428571429	1.01	74	904	6	5	11	17	0	2	17	0	0	9.0	
i 1	5.246836734693877	0.2525	71	700	1	24	9	2	0	1	2	0	0	4.0	
i 1	5.247857142857143	0.2525	69	700	4	4	2	1	0	-1	1	0	0	9.0	
i 1	5.2480612244897955	0.2525	74	202	1	24	16	2	0	-2	2	0	0	4.0	
i 1	5.249897959183674	0.2525	77	700	6	5	1	17	0	1	17	0	0	9.0	
i 1	5.255	0.2525	77	202	7	1	7	16	0	2	16	0	0	5.0	
i 1	5.496632653061225	0.505	77	904	6	1	7	16	0	1	16	0	0	5.0	
i 1	5.501122448979592	0.2525	69	202	5	9	15	1	0	0	1	0	0	8.0	
i 1	5.502959183673469	0.2525	77	202	6	1	10	16	0	1	16	0	0	5.0	
i 1	5.504795918367347	0.2525	77	202	7	5	10	17	0	1	17	0	0	9.0	
i 1	5.745612244897959	0.2525	74	202	5	24	10	17	0	2	17	0	0	6.0	
i 1	5.752142857142857	0.2525	74	700	5	5	14	16	0	2	16	0	0	9.0	
i 1	5.753571428571429	0.2525	69	202	4	3	10	0	0	-1	0	0	0	9.0	
i 1	5.995	0.2525	77	202	7	5	15	17	0	1	17	0	0	9.0	
i 1	5.997448979591836	0.505	74	700	4	24	4	16	0	1	16	0	0	6.0	
i 1	5.9992857142857146	0.505	74	904	6	5	13	17	0	2	17	0	0	9.0	
i 1	5.99969387755102	0.505	72	202	5	9	6	1	0	0	1	0	0	8.0	
i 1	6.0007142857142854	0.2525	74	904	6	1	15	17	0	2	17	0	0	5.0	
i 1	6.24765306122449	0.2525	74	202	7	5	5	17	0	2	17	0	0	9.0	
i 1	6.25030612244898	0.2525	74	202	5	24	8	17	0	2	17	0	0	6.0	
i 1	6.255	0.2525	69	904	6	2	3	0	0	-1	0	0	0	9.0	
i 1	6.4954081632653065	0.7575000000000001	77	202	5	1	8	16	0	2	16	0	0	5.0	
i 1	6.497244897959184	1.01	74	904	6	1	5	17	0	2	17	0	0	5.0	
i 1	6.499897959183674	0.2525	77	202	7	5	2	17	0	1	17	0	0	9.0	
i 1	6.5013265306122445	0.2525	69	202	4	4	10	0	0	-1	0	0	0	9.0	
i 1	6.503367346938775	0.505	74	588	6	5	5	17	0	2	17	0	0	9.0	
i 1	6.504795918367347	0.505	72	588	4	4	14	1	0	0	1	0	0	9.0	
i 1	6.74969387755102	0.2525	74	202	5	5	8	17	0	2	17	0	0	9.0	
i 1	6.752755102040816	0.2525	72	202	5	9	9	1	0	0	1	0	0	8.0	
i 1	6.995	0.505	69	202	4	4	4	0	0	-1	0	0	0	9.0	
i 1	6.999489795918367	0.505	74	904	6	5	1	17	0	2	17	0	0	9.0	
i 1	6.99969387755102	0.505	72	588	4	4	9	1	0	0	1	0	0	9.0	
i 1	7.002959183673469	0.505	77	202	7	5	13	17	0	2	17	0	0	9.0	
i 1	7.245204081632653	0.2525	77	202	6	1	12	16	0	1	16	0	0	5.0	
i 1	7.495816326530612	1.5150000000000001	77	700	6	1	6	16	0	2	16	0	0	6.0	
i 1	7.4960204081632655	0.2525	77	700	6	5	3	16	0	1	16	0	0	12.0	
i 1	7.496428571428571	1.01	63	700	4	19	14	1	0	1	1	0	0	0.7996619447460603	
i 1	7.497244897959184	1.01	63	1086	5	25	10	1	0	1	1	0	0	1.2894454805229927	
i 1	7.49765306122449	1.5150000000000001	61	700	6	17	10	16	0	1	16	0	0	0.7996619447460603	
i 1	7.497857142857143	3.535	63	202	5	18	2	16	0	2	16	0	0	0.7996619447460603	
i 1	7.498469387755102	1.5150000000000001	77	700	6	5	7	16	0	1	16	0	0	12.0	
i 1	7.499081632653061	0.2525	69	202	6	9	12	1	0	0	1	0	0	5.752718136142363	
i 1	7.500102040816326	0.505	63	700	4	19	4	16	0	2	16	0	0	0.7996619447460603	
i 1	7.500102040816326	0.505	63	700	5	25	2	1	0	1	1	0	0	1.2894454805229927	
i 1	7.50030612244898	2.02	63	1086	6	17	16	1	0	1	1	0	0	0.7996619447460603	
i 1	7.501122448979592	1.5150000000000001	69	1086	5	2	13	0	0	0	0	0	0	6.752718136142363	
i 1	7.502142857142857	1.5150000000000001	63	1086	6	17	3	16	0	2	16	0	0	0.7996619447460603	
i 1	7.503571428571429	1.5150000000000001	63	1086	5	25	8	1	0	1	1	0	0	1.2894454805229927	
i 1	7.503775510204082	1.5150000000000001	61	700	6	17	15	16	0	2	16	0	0	0.7996619447460603	
i 1	7.504183673469388	0.2525	77	202	6	1	7	17	0	1	17	0	0	6.0	
i 1	7.504183673469388	0.505	61	700	5	25	1	16	0	2	16	0	0	1.2894454805229927	
i 1	7.504387755102041	0.505	61	202	5	18	2	1	0	2	1	0	0	0.7996619447460603	
i 1	7.749489795918367	0.2525	74	700	4	5	9	16	0	1	16	0	0	12.0	
i 1	7.753571428571429	0.2525	74	1086	6	1	7	16	0	2	16	0	0	6.0	
i 1	7.755	0.505	69	700	4	4	10	0	0	-1	0	0	0	6.752718136142363	
i 1	7.99765306122449	3.535	61	202	5	18	13	1	0	2	1	0	0	0.7996619447460603	
i 1	7.999489795918367	0.505	63	700	5	25	3	1	0	1	1	0	0	1.2894454805229927	
i 1	8.000510204081632	0.505	61	202	5	26	10	16	0	2	16	0	0	1.2894454805229927	
i 1	8.001326530612245	1.01	63	700	4	19	10	16	0	2	16	0	0	0.7996619447460603	
i 1	8.00438775510204	0.2525	74	1086	6	1	16	17	0	1	17	0	0	6.0	
i 1	8.00438775510204	1.01	61	700	5	25	11	16	0	2	16	0	0	1.2894454805229927	
i 1	8.005	0.505	74	700	6	5	3	16	0	1	16	0	0	12.0	
i 1	8.251326530612245	0.2525	74	700	4	24	13	17	0	2	17	0	0	7.0	
i 1	8.254183673469388	0.2525	69	700	4	4	8	1	0	0	1	0	0	6.752718136142363	
i 1	8.495204081632654	0.505	63	700	5	25	6	1	0	1	1	0	0	1.2894454805229927	
i 1	8.495408163265306	1.5150000000000001	63	700	4	19	9	1	0	1	1	0	0	0.7996619447460603	
i 1	8.496632653061225	0.7575000000000001	77	1086	6	5	11	16	0	1	16	0	0	12.0	
i 1	8.497244897959183	0.2525	74	1086	6	1	5	16	0	2	16	0	0	6.0	
i 1	8.498469387755103	0.505	69	700	5	3	16	1	0	0	1	0	0	6.752718136142363	
i 1	8.498877551020408	0.505	61	202	5	26	2	16	0	2	16	0	0	1.2894454805229927	
i 1	8.498877551020408	0.505	61	202	5	26	6	16	0	2	16	0	0	1.2894454805229927	
i 1	8.750102040816326	0.2525	77	202	6	1	10	16	0	1	16	0	0	6.0	
i 1	8.99561224489796	0.7575000000000001	63	588	6	17	10	1	0	1	1	0	0	0.7996619447460603	
i 1	8.996020408163265	0.7575000000000001	69	588	4	4	16	0	0	-1	0	0	0	6.752718136142363	
i 1	8.99704081632653	0.7575000000000001	74	1086	5	1	12	17	0	1	17	0	0	6.0	
i 1	8.998061224489796	1.5150000000000001	61	202	5	26	7	16	0	2	16	0	0	1.2894454805229927	
i 1	8.999489795918368	0.7575000000000001	63	588	6	17	3	1	0	2	1	0	0	0.7996619447460603	
i 1	8.999897959183674	0.7575000000000001	63	588	5	25	5	1	0	1	1	0	0	1.2894454805229927	
i 1	9.000102040816326	0.505	63	588	5	25	2	1	0	1	1	0	0	1.2894454805229927	
i 1	9.000510204081632	0.2525	74	588	4	24	8	2	0	1	2	0	0	4.0	
i 1	9.000714285714286	1.01	74	1086	6	5	15	17	0	1	17	0	0	12.0	
i 1	9.002551020408163	0.2525	77	202	6	1	11	17	0	1	17	0	0	6.0	
i 1	9.002551020408163	0.505	61	202	5	26	1	16	0	2	16	0	0	1.2894454805229927	
i 1	9.002551020408163	0.505	63	700	3	27	7	1	0	2	1	0	0	2.2779028606542466	
i 1	9.00295918367347	0.2525	69	202	5	9	14	1	0	0	1	0	0	5.752718136142363	
i 1	9.003979591836735	1.01	63	700	4	19	7	16	0	2	16	0	0	0.7996619447460603	
i 1	9.004183673469388	1.01	63	1086	6	17	1	16	0	2	16	0	0	0.7996619447460603	
i 1	9.24704081632653	0.2525	72	202	5	9	13	1	0	0	1	0	0	5.752718136142363	
i 1	9.251122448979592	0.2525	77	202	6	1	14	16	0	1	16	0	0	6.0	
i 1	9.253163265306123	0.2525	77	588	6	5	1	17	0	1	17	0	0	12.0	
i 1	9.49704081632653	1.5150000000000001	61	202	5	26	1	16	0	2	16	0	0	1.2894454805229927	
i 1	9.498265306122448	0.2525	74	202	7	5	11	17	0	2	17	0	0	12.0	
i 1	9.498877551020408	0.2525	74	1086	5	1	15	16	0	2	16	0	0	6.0	
i 1	9.500306122448979	0.505	63	700	3	27	15	1	0	1	1	0	0	2.2779028606542466	
i 1	9.502142857142857	0.505	72	1086	5	2	1	1	0	-1	1	0	0	6.752718136142363	
i 1	9.50234693877551	0.505	63	700	3	27	16	1	0	2	1	0	0	2.2779028606542466	
i 1	9.503367346938775	0.505	63	1086	6	17	8	1	0	1	1	0	0	0.7996619447460603	
i 1	9.749285714285714	0.2525	69	1086	5	2	9	0	0	0	0	0	0	6.752718136142363	
i 1	9.749489795918368	0.2525	61	384	5	25	3	1	0	1	1	0	0	1.2894454805229927	
i 1	9.749897959183674	0.2525	63	384	6	17	16	1	0	1	1	0	0	0.7996619447460603	
i 1	9.751122448979592	0.2525	61	384	6	17	6	16	0	1	16	0	0	0.7996619447460603	
i 1	9.752142857142857	0.2525	74	700	5	1	3	16	0	1	16	0	0	6.0	
i 1	9.752755102040817	0.2525	77	384	4	24	5	16	0	2	16	0	0	7.0	
i 1	9.75377551020408	0.2525	77	384	6	5	2	16	0	1	16	0	0	12.0	
i 1	9.995204081632654	0.2525	71	202	3	24	1	2	0	-2	2	0	0	4.0	
i 1	9.995816326530612	0.2525	69	202	4	4	1	0	0	-1	0	0	0	6.752718136142363	
i 1	9.996020408163265	0.505	61	202	4	27	16	1	0	1	1	0	0	2.2779028606542466	
i 1	9.99622448979592	1.5150000000000001	61	202	5	19	7	16	0	1	16	0	0	0.7996619447460603	
i 1	9.996428571428572	0.505	63	588	6	17	7	1	0	2	1	0	0	0.7996619447460603	
i 1	9.997244897959183	2.525	61	588	6	17	7	16	0	1	16	0	0	0.7996619447460603	
i 1	9.997448979591837	1.5150000000000001	63	202	5	19	6	16	0	1	16	0	0	0.7996619447460603	
i 1	9.998673469387755	2.02	72	588	4	4	12	0	0	-1	0	0	0	6.752718136142363	
i 1	9.998673469387755	1.5150000000000001	77	904	6	5	9	16	0	2	16	0	0	12.0	
i 1	9.999489795918368	0.505	77	904	5	1	14	16	0	2	16	0	0	6.0	
i 1	10.001326530612245	2.525	61	904	6	17	1	1	0	2	1	0	0	0.7996619447460603	
i 1	10.002551020408163	1.5150000000000001	61	202	4	27	7	16	0	1	16	0	0	2.2779028606542466	
i 1	10.003367346938775	0.2525	77	202	6	5	13	17	0	2	17	0	0	12.0	
i 1	10.004183673469388	0.505	77	202	5	24	16	17	0	1	17	0	0	7.0	
i 1	10.004795918367346	2.525	63	904	6	17	6	1	0	2	1	0	0	0.7996619447460603	
i 1	10.245204081632654	0.2525	72	588	5	3	7	0	0	-1	0	0	0	6.752718136142363	
i 1	10.250918367346939	0.2525	74	588	6	5	6	17	0	2	17	0	0	12.0	
i 1	10.495408163265306	0.2525	74	202	6	5	6	17	0	2	17	0	0	12.0	
i 1	10.498061224489796	1.01	61	202	4	27	5	1	0	1	1	0	0	2.2779028606542466	
i 1	10.499081632653061	0.505	69	904	5	2	4	1	0	-1	1	0	0	6.752718136142363	
i 1	10.499693877551021	1.01	74	202	3	24	13	2	0	-2	2	0	0	4.0	
i 1	10.501530612244897	0.2525	77	202	6	1	13	17	0	1	17	0	0	6.0	
i 1	10.504183673469388	1.01	77	904	5	1	7	16	0	1	16	0	0	6.0	
i 1	10.504795918367346	2.02	63	588	6	17	8	1	0	2	1	0	0	0.7996619447460603	
i 1	10.751122448979592	0.2525	77	202	6	5	6	16	0	2	16	0	0	12.0	
i 1	10.752755102040817	0.2525	77	202	5	1	14	16	0	2	16	0	0	6.0	
i 1	10.998469387755103	0.2525	72	202	4	3	9	1	0	-1	1	0	0	6.752718136142363	
i 1	10.999285714285714	0.2525	74	588	6	5	1	16	0	1	16	0	0	12.0	
i 1	11.00295918367347	0.505	63	202	5	18	11	16	0	2	16	0	0	0.7996619447460603	
i 1	11.003163265306123	0.7575000000000001	77	904	4	1	4	16	0	2	16	0	0	6.0	
i 1	11.250510204081632	0.2525	69	202	4	4	12	0	0	-1	0	0	0	6.752718136142363	
i 1	11.255	0.505	74	588	6	5	14	17	0	2	17	0	0	12.0	
i 1	11.495816326530612	0.505	72	201	4	4	11	0	0	0	0	0	0	6.752718136142363	
i 1	11.499285714285714	0.505	63	201	5	19	4	1	0	2	1	0	0	0.7996619447460603	
i 1	11.499285714285714	1.01	74	588	6	5	12	16	0	1	16	0	0	12.0	
i 1	11.501938775510204	1.01	61	201	5	19	10	1	0	2	1	0	0	0.7996619447460603	
i 1	11.50234693877551	1.01	63	1170	4	18	4	1	0	1	1	0	0	0.7996619447460603	
i 1	11.50234693877551	0.505	63	201	4	27	11	1	0	1	1	0	0	2.2779028606542466	
i 1	11.503979591836735	1.01	61	1170	4	18	13	16	0	1	16	0	0	0.7996619447460603	
i 1	11.504795918367346	0.505	77	904	4	1	8	16	0	1	16	0	0	6.0	
i 1	11.74622448979592	0.2525	77	904	6	5	12	16	0	2	16	0	0	12.0	
i 1	11.752755102040817	0.7575000000000001	74	1170	4	24	11	2	0	1	2	0	0	4.0	
i 1	11.753979591836735	0.2525	74	588	5	1	15	16	0	2	16	0	0	6.0	
i 1	12.000918367346939	0.2525	74	1170	6	5	13	16	0	1	16	0	0	12.0	
i 1	12.001122448979592	0.505	63	201	5	19	4	1	0	2	1	0	0	0.7996619447460603	
i 1	12.001326530612245	0.2525	72	588	4	4	13	0	0	-1	0	0	0	6.752718136142363	
i 1	12.004183673469388	0.505	74	588	4	1	15	16	0	2	16	0	0	6.0	
i 1	12.004183673469388	0.2525	69	1170	5	9	14	1	0	0	1	0	0	5.752718136142363	
i 1	12.004591836734694	0.2525	74	201	5	24	12	16	0	1	16	0	0	7.0	
i 1	12.245408163265306	0.2525	74	1170	6	5	12	16	0	2	16	0	0	12.0	
i 1	12.247244897959183	0.2525	77	1170	5	1	4	17	0	2	17	0	0	6.0	
i 1	12.248673469387755	0.2525	69	1170	5	9	8	0	0	-1	0	0	0	5.752718136142363	
i 1	12.253979591836735	0.2525	69	904	6	2	16	0	0	-1	0	0	0	6.752718136142363	
i 1	12.495	0.2525	72	716	6	2	4	1	0	-1	1	0	0	6.752718136142363	
i 1	12.497448979591837	2.525	63	716	6	17	3	16	0	1	16	0	0	0.7996619447460603	
i 1	12.497857142857143	2.525	61	1102	4	18	4	16	0	1	16	0	0	0.7996619447460603	
i 1	12.498061224489796	1.5150000000000001	77	218	4	24	6	16	0	1	16	0	0	7.0	
i 1	12.498061224489796	1.5150000000000001	74	716	6	5	6	16	0	1	16	0	0	12.0	
i 1	12.498265306122448	2.525	63	716	4	19	5	16	0	2	16	0	0	0.7996619447460603	
i 1	12.499081632653061	1.5150000000000001	69	218	5	4	14	1	0	0	1	0	0	6.752718136142363	
i 1	12.501326530612245	0.2525	74	716	4	5	5	16	0	2	16	0	0	12.0	
i 1	12.502755102040817	2.525	61	218	7	17	7	1	0	2	1	0	0	0.7996619447460603	
i 1	12.503979591836735	0.2525	77	716	3	24	2	16	0	1	16	0	0	7.0	
i 1	12.50438775510204	2.525	63	1102	4	18	13	1	0	1	1	0	0	0.7996619447460603	
i 1	12.504591836734694	2.525	61	716	6	17	2	16	0	2	16	0	0	0.7996619447460603	
i 1	12.504591836734694	2.525	63	218	7	17	3	1	0	2	1	0	0	0.7996619447460603	
i 1	12.505	2.525	61	716	4	19	14	16	0	1	16	0	0	0.7996619447460603	
i 1	12.745408163265306	0.2525	74	1102	5	5	1	17	0	1	17	0	0	12.0	
i 1	12.751530612244897	0.505	69	716	6	2	6	1	0	-1	1	0	0	6.752718136142363	
i 1	12.75377551020408	0.2525	77	1102	4	1	4	16	0	2	16	0	0	6.0	
i 1	12.996836734693877	1.01	71	716	2	24	1	2	0	-2	2	0	0	6.291419062908151	
i 1	12.998265306122448	0.2525	74	716	4	5	13	16	0	2	16	0	0	12.0	
i 1	13.001734693877552	0.505	61	716	5	25	11	1	0	2	1	0	0	1.2894454805229927	
i 1	13.00377551020408	0.2525	74	716	3	1	8	17	0	1	17	0	0	6.0	
i 1	13.004183673469388	1.01	71	1102	3	24	9	2	0	1	2	0	0	6.291419062908151	
i 1	13.245204081632654	0.2525	72	716	6	2	2	1	0	-1	1	0	0	6.752718136142363	
i 1	13.251938775510204	0.2525	74	1102	5	5	8	17	0	1	17	0	0	12.0	
i 1	13.255	0.2525	77	716	5	1	10	16	0	2	16	0	0	6.0	
i 1	13.495408163265306	0.505	61	716	5	25	8	1	0	2	1	0	0	1.2894454805229927	
i 1	13.499081632653061	0.2525	77	1102	3	1	10	16	0	2	16	0	0	6.0	
i 1	13.501734693877552	0.2525	69	218	6	3	8	0	0	0	0	0	0	6.752718136142363	
i 1	13.503571428571428	0.2525	74	218	7	5	2	16	0	1	16	0	0	12.0	
i 1	13.504795918367346	0.505	61	716	5	25	5	1	0	2	1	0	0	1.2894454805229927	
i 1	13.74561224489796	0.2525	77	716	5	1	5	16	0	2	16	0	0	6.0	
i 1	13.745816326530612	0.2525	69	716	6	2	10	1	0	-1	1	0	0	6.752718136142363	
i 1	13.747448979591837	0.2525	74	218	7	5	7	16	0	1	16	0	0	12.0	
i 1	13.99561224489796	1.01	69	218	6	3	8	0	0	0	0	0	0	6.752718136142363	
i 1	13.99704081632653	0.2525	77	1102	3	1	2	16	0	2	16	0	0	6.0	
i 1	13.997448979591837	0.2525	74	218	4	20	9	2	0	1	2	0	0	2.291419062908151	
i 1	13.99765306122449	0.2525	69	716	4	4	6	1	0	-1	1	0	0	6.752718136142363	
i 1	13.99765306122449	1.01	74	716	6	5	4	16	0	1	16	0	0	12.0	
i 1	13.999897959183674	1.01	61	716	5	25	7	1	0	2	1	0	0	1.2894454805229927	
i 1	14.000102040816326	0.2525	74	716	4	5	5	16	0	2	16	0	0	12.0	
i 1	14.000306122448979	0.505	63	218	6	25	12	16	0	2	16	0	0	1.2894454805229927	
i 1	14.000510204081632	0.505	61	716	5	25	15	1	0	2	1	0	0	1.2894454805229927	
i 1	14.002755102040817	1.01	77	716	4	1	9	16	0	2	16	0	0	6.0	
i 1	14.00377551020408	0.505	74	716	2	24	11	2	0	-2	2	0	0	6.291419062908151	
i 1	14.246428571428572	0.2525	74	1102	6	5	8	17	0	1	17	0	0	12.0	
i 1	14.248673469387755	0.2525	71	1102	3	20	6	2	0	1	2	0	0	2.291419062908151	
i 1	14.249693877551021	0.505	77	218	5	24	8	16	0	1	16	0	0	7.0	
i 1	14.250510204081632	0.2525	69	218	5	4	3	1	0	0	1	0	0	6.752718136142363	
i 1	14.498265306122448	0.505	61	716	5	25	4	1	0	2	1	0	0	1.2894454805229927	
i 1	14.498469387755103	0.2525	71	716	2	20	10	2	0	-2	2	0	0	2.291419062908151	
i 1	14.499897959183674	0.505	63	218	6	25	7	1	0	1	1	0	0	1.2894454805229927	
i 1	14.499897959183674	0.2525	71	218	4	24	12	2	0	1	2	0	0	6.291419062908151	
i 1	14.500102040816326	0.2525	69	716	4	4	8	1	0	-1	1	0	0	6.752718136142363	
i 1	14.501734693877552	0.505	74	716	5	5	12	16	0	2	16	0	0	12.0	
i 1	14.50438775510204	0.505	63	218	6	25	2	16	0	2	16	0	0	1.2894454805229927	
i 1	14.748673469387755	0.2525	69	218	5	4	6	1	0	0	1	0	0	6.752718136142363	
i 1	14.752551020408163	1.01	71	1102	3	24	9	2	0	1	2	0	0	6.291419062908151	
i 1	14.753367346938775	0.7575000000000001	74	716	2	24	14	2	0	-2	2	0	0	6.291419062908151	
i 1	14.753571428571428	0.2525	77	1102	4	1	11	16	0	2	16	0	0	6.0	
i 1	14.995204081632654	0.505	77	218	5	24	13	16	0	1	16	0	0	3.0	
i 1	14.996836734693877	0.2525	69	1102	5	9	1	0	0	0	0	0	0	4.08331932601638	
i 1	14.996836734693877	2.525	61	716	4	19	7	16	0	1	16	0	0	0.11029819927531855	
i 1	14.997448979591837	0.505	63	1102	4	26	5	16	0	1	16	0	0	1.5697597154192948	
i 1	14.998469387755103	2.525	61	716	5	25	2	1	0	2	1	0	0	1.5697597154192948	
i 1	14.998673469387755	0.2525	77	716	2	24	15	16	0	1	16	0	0	3.0	
i 1	14.998877551020408	1.5150000000000001	63	218	7	17	14	1	0	2	1	0	0	0.11029819927531855	
i 1	14.999897959183674	2.525	63	1102	4	18	5	1	0	1	1	0	0	0.11029819927531855	
i 1	14.999897959183674	0.505	63	218	6	25	1	1	0	1	1	0	0	1.5697597154192948	
i 1	15.000918367346939	0.505	69	218	6	3	5	0	0	0	0	0	0	5.08331932601638	
i 1	15.001530612244897	2.02	61	1102	4	18	13	16	0	1	16	0	0	0.11029819927531855	
i 1	15.001734693877552	2.525	63	716	4	19	15	16	0	2	16	0	0	0.11029819927531855	
i 1	15.001938775510204	1.01	61	218	7	17	9	1	0	2	1	0	0	0.11029819927531855	
i 1	15.002755102040817	0.7575000000000001	74	716	6	5	16	16	0	1	16	0	0	12.0	
i 1	15.004183673469388	0.505	63	716	6	17	7	16	0	1	16	0	0	0.11029819927531855	
i 1	15.004183673469388	2.02	61	716	5	25	15	1	0	2	1	0	0	1.5697597154192948	
i 1	15.004795918367346	2.525	63	218	6	25	2	16	0	2	16	0	0	1.5697597154192948	
i 1	15.004795918367346	0.2525	74	1102	6	5	4	17	0	1	17	0	0	12.0	
i 1	15.245408163265306	0.7575000000000001	69	716	6	2	6	1	0	-1	1	0	0	5.08331932601638	
i 1	15.247448979591837	0.7575000000000001	74	218	7	5	2	16	0	1	16	0	0	12.0	
i 1	15.249489795918368	0.2525	77	1102	4	1	10	16	0	2	16	0	0	2.0	
i 1	15.250918367346939	0.2525	69	218	5	4	2	1	0	0	1	0	0	5.08331932601638	
i 1	15.25234693877551	0.2525	71	716	2	20	6	2	0	-2	2	0	0	2.291419062908151	
i 1	15.25234693877551	2.02	74	716	2	24	12	2	0	-2	2	0	0	6.291419062908151	
i 1	15.495816326530612	0.2525	74	716	3	20	9	2	0	-2	2	0	0	2.291419062908151	
i 1	15.497448979591837	2.02	63	218	6	25	5	1	0	1	1	0	0	1.5697597154192948	
i 1	15.497448979591837	0.505	61	1102	4	26	5	16	0	1	16	0	0	1.5697597154192948	
i 1	15.498673469387755	0.2525	74	716	6	5	3	16	0	1	16	0	0	12.0	
i 1	15.499081632653061	0.2525	71	218	4	24	15	2	0	1	2	0	0	6.291419062908151	
i 1	15.499693877551021	0.7575000000000001	74	218	4	1	13	16	0	2	16	0	0	2.0	
i 1	15.499897959183674	0.505	63	1102	4	26	1	16	0	1	16	0	0	1.5697597154192948	
i 1	15.500102040816326	0.2525	69	716	4	4	2	1	0	-1	1	0	0	5.08331932601638	
i 1	15.505	0.2525	77	716	4	1	1	16	0	2	16	0	0	2.0	
i 1	15.505	0.2525	74	218	4	20	6	2	0	1	2	0	0	2.291419062908151	
i 1	15.74622448979592	0.2525	74	716	2	20	7	2	0	-2	2	0	0	2.291419062908151	
i 1	15.748061224489796	0.505	74	716	4	1	6	17	0	2	17	0	0	2.0	
i 1	15.750102040816326	0.2525	69	716	5	3	14	1	0	-1	1	0	0	5.08331932601638	
i 1	15.75234693877551	0.7575000000000001	71	1102	2	20	1	2	0	1	2	0	0	2.291419062908151	
i 1	15.75377551020408	0.505	74	218	7	5	15	16	0	1	16	0	0	12.0	
i 1	15.995408163265306	0.2525	69	1102	5	9	3	0	0	0	0	0	0	4.08331932601638	
i 1	15.995816326530612	0.505	61	1102	4	26	2	16	0	1	16	0	0	1.5697597154192948	
i 1	15.996632653061225	1.5150000000000001	63	1102	4	26	7	16	0	1	16	0	0	1.5697597154192948	
i 1	15.998877551020408	0.505	71	1102	3	20	12	2	0	1	2	0	0	2.291419062908151	
i 1	16.002755102040815	1.01	69	716	4	2	16	1	0	-1	1	0	0	5.08331932601638	
i 1	16.003775510204083	0.505	77	716	4	1	9	16	0	2	16	0	0	2.0	
i 1	16.003775510204083	0.505	63	716	3	27	3	1	0	2	1	0	0	2.5582170955505488	
i 1	16.003979591836735	0.505	74	218	7	5	5	16	0	1	16	0	0	12.0	
i 1	16.247448979591837	0.7575000000000001	74	716	6	5	2	16	0	1	16	0	0	12.0	
i 1	16.251938775510204	0.2525	77	1102	4	1	11	16	0	2	16	0	0	2.0	
i 1	16.251938775510204	0.2525	77	716	3	24	2	16	0	1	16	0	0	3.0	
i 1	16.251938775510204	0.2525	69	716	5	3	16	1	0	-1	1	0	0	5.08331932601638	
i 1	16.252755102040815	0.2525	74	716	5	5	2	16	0	2	16	0	0	12.0	
i 1	16.496224489795917	0.2525	77	218	4	24	6	16	0	1	16	0	0	3.0	
i 1	16.497244897959185	0.2525	69	1102	5	9	15	1	0	0	1	0	0	4.08331932601638	
i 1	16.497448979591837	0.2525	69	716	4	4	3	1	0	-1	1	0	0	5.08331932601638	
i 1	16.49765306122449	0.505	71	1102	3	20	15	2	0	1	2	0	0	2.291419062908151	
i 1	16.499285714285715	0.505	63	716	3	27	4	1	0	2	1	0	0	2.5582170955505488	
i 1	16.499489795918368	0.505	74	218	7	5	10	16	0	1	16	0	0	12.0	
i 1	16.500918367346937	1.01	77	716	5	1	9	16	0	2	16	0	0	2.0	
i 1	16.50234693877551	1.01	61	1102	4	26	7	16	0	1	16	0	0	1.5697597154192948	
i 1	16.503367346938777	0.505	63	716	3	27	2	1	0	2	1	0	0	2.5582170955505488	
i 1	16.504183673469388	0.2525	74	1102	6	5	14	17	0	1	17	0	0	12.0	
i 1	16.504591836734694	0.505	74	716	3	1	13	17	0	1	17	0	0	2.0	
i 1	16.74683673469388	0.2525	69	218	5	4	15	1	0	0	1	0	0	5.08331932601638	
i 1	16.74683673469388	0.2525	69	716	5	3	16	1	0	-1	1	0	0	5.08331932601638	
i 1	16.751326530612246	0.2525	74	716	6	5	12	16	0	1	16	0	0	12.0	
i 1	16.996020408163265	0.2525	69	716	4	4	14	1	0	-1	1	0	0	5.08331932601638	
i 1	16.997448979591837	0.505	63	716	3	27	2	1	0	2	1	0	0	2.5582170955505488	
i 1	16.999489795918368	0.505	74	716	6	5	14	16	0	1	16	0	0	12.0	
i 1	16.999489795918368	0.505	74	1102	3	20	11	8	0	1	8	0	0	2.291419062908151	
i 1	17.00030612244898	0.505	69	218	4	3	16	0	0	0	0	0	0	5.08331932601638	
i 1	17.002959183673468	0.505	74	218	4	1	5	16	0	2	16	0	0	2.0	
i 1	17.002959183673468	0.2525	77	1102	6	5	16	16	0	2	16	0	0	12.0	
i 1	17.004183673469388	0.2525	72	716	4	2	9	1	0	-1	1	0	0	5.08331932601638	
i 1	17.004183673469388	0.505	71	1102	3	20	4	2	0	1	2	0	0	2.291419062908151	
i 1	17.004795918367346	0.505	63	716	3	27	4	1	0	2	1	0	0	2.5582170955505488	
i 1	17.250102040816326	0.2525	74	218	7	5	11	16	0	1	16	0	0	12.0	
i 1	17.25173469387755	0.2525	77	716	3	24	8	16	0	1	16	0	0	3.0	
i 1	17.252551020408163	0.2525	69	716	4	2	12	1	0	-1	1	0	0	5.08331932601638	
i 1	17.254591836734694	0.2525	74	716	1	24	2	2	0	-2	2	0	0	6.291419062908151	
i 1	17.495	0.7575000000000001	69	586	4	4	5	1	0	0	1	0	0	5.08331932601638	
i 1	17.495816326530612	0.505	63	200	5	19	1	16	0	2	16	0	0	0.11029819927531855	
i 1	17.49642857142857	1.01	61	200	5	19	1	1	0	1	1	0	0	0.11029819927531855	
i 1	17.496632653061223	0.2525	74	200	7	5	2	16	0	2	16	0	0	12.0	
i 1	17.497040816326532	2.525	61	200	4	27	3	1	0	1	1	0	0	2.5582170955505488	
i 1	17.4984693877551	0.2525	74	200	3	20	16	2	0	-2	2	0	0	2.291419062908151	
i 1	17.499285714285715	0.505	71	200	3	24	1	2	0	-2	2	0	0	6.291419062908151	
i 1	17.49969387755102	0.505	63	586	5	25	1	1	0	1	1	0	0	1.5697597154192948	
i 1	17.49969387755102	0.7575000000000001	77	586	6	5	14	16	0	2	16	0	0	12.0	
i 1	17.50030612244898	1.5150000000000001	61	200	5	26	1	16	0	1	16	0	0	1.5697597154192948	
i 1	17.500918367346937	2.525	61	200	4	27	13	1	0	2	1	0	0	2.5582170955505488	
i 1	17.501122448979594	1.01	61	586	5	25	8	1	0	1	1	0	0	1.5697597154192948	
i 1	17.5015306122449	2.02	61	200	5	26	4	16	0	1	16	0	0	1.5697597154192948	
i 1	17.501938775510204	0.2525	74	902	5	1	12	17	0	2	17	0	0	2.0	
i 1	17.50316326530612	1.01	74	200	3	20	16	2	0	-2	2	0	0	2.291419062908151	
i 1	17.504183673469388	0.2525	72	586	4	3	11	0	0	0	0	0	0	5.08331932601638	
i 1	17.50438775510204	0.2525	77	902	5	1	9	17	0	2	17	0	0	2.0	
i 1	17.504795918367346	1.5150000000000001	74	586	5	1	3	16	0	2	16	0	0	2.0	
i 1	17.745204081632654	1.7675	69	902	4	2	3	0	0	0	0	0	0	5.08331932601638	
i 1	17.746224489795917	0.2525	74	200	6	5	10	16	0	2	16	0	0	12.0	
i 1	17.74642857142857	0.2525	74	200	3	24	4	17	0	2	17	0	0	3.0	
i 1	17.750102040816326	0.2525	74	586	4	24	5	16	0	2	16	0	0	3.0	
i 1	17.751326530612246	0.2525	69	200	6	9	13	0	0	0	0	0	0	4.08331932601638	
i 1	17.752551020408163	0.2525	77	586	6	5	9	16	0	2	16	0	0	12.0	
i 1	17.9984693877551	1.7675	77	586	6	5	11	16	0	2	16	0	0	12.0	
i 1	17.999489795918368	1.01	71	200	4	24	11	2	0	-2	2	0	0	6.291419062908151	
i 1	17.999897959183674	0.505	74	902	4	1	2	17	0	2	17	0	0	2.0	
i 1	18.000102040816326	0.2525	74	200	7	5	11	16	0	2	16	0	0	12.0	
i 1	18.000510204081632	0.2525	74	200	2	24	14	2	0	1	2	0	0	6.291419062908151	
i 1	18.001938775510204	0.2525	74	200	4	1	16	17	0	2	17	0	0	2.0	
i 1	18.001938775510204	0.7575000000000001	69	200	4	9	9	1	0	0	1	0	0	4.08331932601638	
i 1	18.003775510204083	1.01	63	902	6	17	3	1	0	2	1	0	0	0.11029819927531855	
i 1	18.24561224489796	0.2525	74	200	7	5	7	16	0	1	16	0	0	12.0	
i 1	18.247448979591837	0.2525	71	200	3	24	13	2	0	1	2	0	0	6.291419062908151	
i 1	18.250102040816326	0.2525	74	902	6	5	7	16	0	2	16	0	0	12.0	
i 1	18.250510204081632	0.2525	69	902	4	2	9	1	0	-1	1	0	0	5.08331932601638	
i 1	18.252755102040815	0.2525	77	902	5	1	16	17	0	2	17	0	0	2.0	
i 1	18.495204081632654	1.01	63	902	6	17	5	1	0	1	1	0	0	0.11029819927531855	
i 1	18.49642857142857	0.2525	74	200	3	1	9	16	0	1	16	0	0	2.0	
i 1	18.497857142857143	0.2525	72	200	6	3	2	0	0	0	0	0	0	5.08331932601638	
i 1	18.499081632653063	0.2525	74	586	4	24	1	8	0	1	8	0	0	6.291419062908151	
i 1	18.499285714285715	0.2525	77	586	6	5	14	16	0	2	16	0	0	12.0	
i 1	18.50030612244898	0.2525	74	586	4	24	14	16	0	2	16	0	0	3.0	
i 1	18.500510204081632	0.2525	74	902	6	5	10	16	0	2	16	0	0	12.0	
i 1	18.501122448979594	0.2525	71	902	3	20	7	2	0	-2	2	0	0	2.291419062908151	
i 1	18.74765306122449	0.505	72	200	5	4	2	1	0	0	1	0	0	5.08331932601638	
i 1	18.747857142857143	0.2525	74	200	3	20	11	2	0	1	2	0	0	2.291419062908151	
i 1	18.748673469387754	0.2525	71	200	3	24	12	2	0	1	2	0	0	6.291419062908151	
i 1	18.750510204081632	0.505	74	902	4	1	9	17	0	2	17	0	0	2.0	
i 1	18.750510204081632	0.2525	77	200	7	5	1	17	0	2	17	0	0	12.0	
i 1	18.751326530612246	0.2525	74	200	4	1	15	17	0	2	17	0	0	2.0	
i 1	18.995408163265306	0.2525	74	200	3	20	14	2	0	1	2	0	0	5.798276341665121	
i 1	18.995816326530612	1.01	69	902	4	2	8	1	0	-1	1	0	0	5.08331932601638	
i 1	18.995816326530612	0.505	71	200	4	24	2	2	0	-2	2	0	0	9.79827634166512	
i 1	18.99642857142857	0.505	77	586	6	5	9	16	0	2	16	0	0	12.0	
i 1	18.99683673469388	1.01	63	902	6	17	4	1	0	2	1	0	0	0.11029819927531855	
i 1	18.997857142857143	0.2525	71	200	2	24	14	2	0	1	2	0	0	9.79827634166512	
i 1	19.000102040816326	0.2525	77	200	6	5	1	17	0	2	17	0	0	12.0	
i 1	19.000714285714285	1.01	61	902	5	25	10	16	0	1	16	0	0	1.5697597154192948	
i 1	19.003367346938777	1.01	74	586	4	1	8	16	0	2	16	0	0	2.0	
i 1	19.003367346938777	0.2525	74	200	5	1	7	17	0	2	17	0	0	2.0	
i 1	19.003775510204083	1.01	63	586	6	17	6	1	0	2	1	0	0	0.11029819927531855	
i 1	19.247040816326532	0.2525	74	200	3	24	6	17	0	2	17	0	0	3.0	
i 1	19.247448979591837	0.2525	71	902	3	20	14	2	0	1	2	0	0	5.798276341665121	
i 1	19.24765306122449	0.2525	71	586	3	24	1	2	0	1	2	0	0	9.79827634166512	
i 1	19.253775510204083	0.2525	77	200	5	1	7	16	0	2	16	0	0	2.0	
i 1	19.496020408163265	0.2525	74	902	6	5	3	16	0	2	16	0	0	12.0	
i 1	19.496020408163265	2.7775	71	200	3	24	11	2	0	-2	2	0	0	9.79827634166512	
i 1	19.496224489795917	0.2525	74	200	4	1	6	16	0	1	16	0	0	2.0	
i 1	19.49765306122449	1.01	71	200	3	20	14	2	0	1	2	0	0	5.798276341665121	
i 1	19.49765306122449	0.2525	74	200	4	20	7	2	0	-2	2	0	0	5.798276341665121	
i 1	19.497857142857143	0.505	63	586	6	17	8	1	0	2	1	0	0	0.11029819927531855	
i 1	19.4984693877551	0.505	72	586	4	3	15	0	0	0	0	0	0	5.08331932601638	
i 1	19.498877551020406	0.505	77	586	6	5	4	16	0	2	16	0	0	12.0	
i 1	19.499897959183674	0.505	63	902	6	17	16	1	0	1	1	0	0	0.11029819927531855	
i 1	19.499897959183674	0.505	63	902	5	25	11	16	0	1	16	0	0	1.5697597154192948	
i 1	19.502142857142857	0.2525	69	902	6	2	9	0	0	0	0	0	0	5.08331932601638	
i 1	19.504795918367346	0.2525	74	200	5	1	3	17	0	2	17	0	0	2.0	
i 1	19.74683673469388	0.2525	74	902	6	5	5	16	0	1	16	0	0	12.0	
i 1	19.748061224489796	0.2525	74	902	4	1	8	17	0	2	17	0	0	2.0	
i 1	19.7484693877551	0.505	69	200	4	9	11	1	0	0	1	0	0	4.08331932601638	
i 1	19.749285714285715	0.2525	71	200	2	24	8	2	0	1	2	0	0	9.79827634166512	
i 1	19.753979591836735	0.2525	77	902	4	1	3	17	0	2	17	0	0	2.0	
i 1	19.996020408163265	1.01	61	698	5	25	4	16	0	1	16	0	0	1.5697597154192948	
i 1	19.996020408163265	1.5150000000000001	74	698	2	24	2	2	0	-2	2	0	0	9.79827634166512	
i 1	19.997040816326532	0.505	77	698	4	1	5	17	0	2	17	0	0	2.0	
i 1	19.997040816326532	0.505	61	698	3	27	10	16	0	1	16	0	0	2.5582170955505488	
i 1	19.99826530612245	0.505	61	1084	5	25	10	1	0	1	1	0	0	1.5697597154192948	
i 1	19.999285714285715	2.525	61	1084	6	17	11	16	0	2	16	0	0	0.11029819927531855	
i 1	19.999897959183674	1.01	77	1084	4	1	12	17	0	1	17	0	0	2.0	
i 1	20.000510204081632	1.01	61	200	5	18	8	16	0	1	16	0	0	0.11029819927531855	
i 1	20.000714285714285	2.2725	74	1084	6	5	13	16	0	1	16	0	0	12.0	
i 1	20.000714285714285	0.2525	77	698	6	5	8	17	0	1	17	0	0	12.0	
i 1	20.000918367346937	0.505	72	698	4	3	15	0	0	0	0	0	0	5.08331932601638	
i 1	20.002142857142857	2.525	63	698	6	17	10	1	0	1	1	0	0	0.11029819927531855	
i 1	20.002755102040815	0.2525	77	200	4	1	7	16	0	2	16	0	0	2.0	
i 1	20.002755102040815	0.505	69	698	3	4	11	1	0	-1	1	0	0	5.08331932601638	
i 1	20.004591836734694	0.505	61	698	6	17	2	16	0	1	16	0	0	0.11029819927531855	
i 1	20.005	2.525	61	1084	6	17	2	1	0	1	1	0	0	0.11029819927531855	
i 1	20.005	1.01	61	1084	5	25	10	16	0	1	16	0	0	1.5697597154192948	
i 1	20.245408163265306	0.2525	74	200	6	5	2	16	0	2	16	0	0	12.0	
i 1	20.24683673469388	0.2525	77	1084	4	1	5	17	0	2	17	0	0	2.0	
i 1	20.251122448979594	0.2525	69	1084	6	2	7	1	0	-1	1	0	0	5.08331932601638	
i 1	20.253367346938777	0.2525	77	698	5	5	10	16	0	1	16	0	0	12.0	
i 1	20.495	1.01	72	698	5	3	8	0	0	0	0	0	0	5.08331932601638	
i 1	20.495204081632654	1.01	61	200	5	18	8	16	0	2	16	0	0	0.11029819927531855	
i 1	20.495204081632654	0.2525	74	200	3	20	8	2	0	-2	2	0	0	5.798276341665121	
i 1	20.495408163265306	0.2525	77	698	6	5	1	17	0	1	17	0	0	12.0	
i 1	20.496020408163265	2.02	61	698	6	17	16	16	0	1	16	0	0	0.11029819927531855	
i 1	20.498673469387754	0.2525	77	200	4	1	10	16	0	2	16	0	0	2.0	
i 1	20.500918367346937	0.2525	74	200	7	5	14	16	0	2	16	0	0	12.0	
i 1	20.5015306122449	1.01	63	698	5	25	10	1	0	2	1	0	0	1.5697597154192948	
i 1	20.502959183673468	0.2525	72	698	3	3	13	0	0	-1	0	0	0	5.08331932601638	
i 1	20.50316326530612	2.02	77	698	4	24	15	16	0	1	16	0	0	3.0	
i 1	20.504183673469388	1.01	61	1084	5	25	16	1	0	1	1	0	0	1.5697597154192948	
i 1	20.504795918367346	0.505	69	200	4	9	13	0	0	0	0	0	0	4.08331932601638	
i 1	20.745204081632654	0.2525	77	1084	4	1	10	17	0	2	17	0	0	2.0	
i 1	20.745408163265306	0.2525	77	698	4	1	6	17	0	2	17	0	0	2.0	
i 1	20.74561224489796	0.2525	77	698	5	5	8	16	0	1	16	0	0	12.0	
i 1	20.746020408163265	0.2525	77	698	6	5	12	16	0	1	16	0	0	12.0	
i 1	20.74683673469388	0.2525	69	200	4	9	2	1	0	0	1	0	0	4.08331932601638	
i 1	20.753367346938777	0.2525	71	200	3	20	2	2	0	1	2	0	0	5.798276341665121	
i 1	20.995816326530612	0.2525	77	698	4	24	1	16	0	1	16	0	0	3.0	
i 1	20.995816326530612	0.2525	71	698	2	20	13	8	0	-2	8	0	0	5.798276341665121	
i 1	20.996020408163265	0.2525	77	698	6	5	15	16	0	1	16	0	0	12.0	
i 1	20.99642857142857	0.2525	69	1084	4	2	16	1	0	0	1	0	0	5.08331932601638	
i 1	20.996632653061223	1.01	63	698	4	19	3	1	0	1	1	0	0	0.11029819927531855	
i 1	20.997244897959185	0.2525	77	200	7	5	10	17	0	2	17	0	0	12.0	
i 1	20.9984693877551	1.01	74	200	4	1	5	17	0	2	17	0	0	2.0	
i 1	20.9984693877551	1.01	61	698	5	25	10	16	0	1	16	0	0	1.5697597154192948	
i 1	20.999489795918368	1.01	61	200	5	26	3	16	0	1	16	0	0	1.5697597154192948	
i 1	20.999897959183674	1.5150000000000001	61	200	5	18	2	16	0	1	16	0	0	0.11029819927531855	
i 1	21.001122448979594	1.5150000000000001	69	1084	4	2	6	1	0	-1	1	0	0	5.08331932601638	
i 1	21.00357142857143	0.505	77	1084	6	1	2	17	0	1	17	0	0	2.0	
i 1	21.005	1.5150000000000001	61	1084	5	25	5	16	0	1	16	0	0	1.5697597154192948	
i 1	21.247448979591837	0.2525	77	698	5	5	13	16	0	2	16	0	0	12.0	
i 1	21.2484693877551	1.01	72	698	3	3	14	0	0	-1	0	0	0	5.08331932601638	
i 1	21.24969387755102	0.2525	72	698	4	4	5	0	0	-1	0	0	0	5.08331932601638	
i 1	21.25173469387755	0.2525	71	200	3	20	16	2	0	1	2	0	0	5.798276341665121	
i 1	21.252551020408163	1.2625	77	1084	6	5	15	17	0	2	17	0	0	12.0	
i 1	21.495408163265306	1.01	61	1084	5	25	9	1	0	1	1	0	0	1.5697597154192948	
i 1	21.49765306122449	0.505	72	698	4	3	8	0	0	0	0	0	0	5.08331932601638	
i 1	21.497857142857143	1.01	63	698	5	25	14	1	0	2	1	0	0	1.5697597154192948	
i 1	21.499285714285715	0.2525	74	698	3	24	11	2	0	-2	2	0	0	9.79827634166512	
i 1	21.49969387755102	1.01	61	200	5	18	9	16	0	2	16	0	0	0.11029819927531855	
i 1	21.500510204081632	0.505	77	698	5	5	1	16	0	1	16	0	0	12.0	
i 1	21.501122448979594	1.01	61	200	5	26	14	16	0	1	16	0	0	1.5697597154192948	
i 1	21.501122448979594	0.7575000000000001	71	698	3	20	5	2	0	-2	2	0	0	5.798276341665121	
i 1	21.501326530612246	0.7575000000000001	74	1084	3	20	3	2	0	1	2	0	0	5.798276341665121	
i 1	21.5015306122449	1.01	71	698	2	24	11	2	0	1	2	0	0	9.79827634166512	
i 1	21.502142857142857	1.01	63	698	4	19	13	16	0	2	16	0	0	0.11029819927531855	
i 1	21.502959183673468	0.505	77	698	4	1	14	17	0	2	17	0	0	2.0	
i 1	21.747857142857143	0.2525	69	698	3	4	16	1	0	-1	1	0	0	5.08331932601638	
i 1	21.748673469387754	0.7575000000000001	77	1084	6	1	14	17	0	1	17	0	0	2.0	
i 1	21.998061224489796	0.505	63	698	4	19	5	1	0	1	1	0	0	0.11029819927531855	
i 1	21.998061224489796	0.505	61	698	5	25	6	16	0	1	16	0	0	1.5697597154192948	
i 1	21.998061224489796	0.505	61	200	5	26	16	16	0	1	16	0	0	1.5697597154192948	
i 1	21.999489795918368	0.505	77	698	6	5	2	16	0	1	16	0	0	12.0	
i 1	22.0015306122449	0.7575000000000001	77	698	6	1	3	17	0	2	17	0	0	2.0	
i 1	22.00316326530612	0.505	61	698	3	27	3	16	0	2	16	0	0	2.5582170955505488	
i 1	22.003979591836735	0.2525	69	200	6	9	7	0	0	0	0	0	0	4.08331932601638	
i 1	22.004795918367346	0.505	74	200	3	20	7	2	0	-2	2	0	0	5.798276341665121	
i 1	22.245408163265306	0.2525	77	1084	6	1	16	17	0	2	17	0	0	2.0	
i 1	22.246020408163265	0.2525	72	698	4	4	3	0	0	-1	0	0	0	5.08331932601638	
i 1	22.246632653061223	0.2525	77	698	6	5	11	16	0	1	16	0	0	12.0	
i 1	22.2484693877551	0.2525	71	698	2	20	16	8	0	-2	8	0	0	5.798276341665121	
i 1	22.250918367346937	0.2525	72	698	4	3	9	0	0	0	0	0	0	5.08331932601638	
i 1	22.251122448979594	0.2525	71	200	3	20	8	2	0	-2	2	0	0	5.798276341665121	
i 1	22.2515306122449	0.2525	74	698	2	24	7	2	0	-2	2	0	0	9.79827634166512	
i 1	22.255	0.2525	71	698	2	20	14	2	0	-2	2	0	0	5.798276341665121	
i 1	22.495	1.5150000000000001	63	698	5	25	5	1	0	2	1	0	0	1.1436820783769146	
i 1	22.495204081632654	0.505	61	1196	3	27	2	16	0	2	16	0	0	2.1321394585081688	
i 1	22.49561224489796	1.01	63	382	4	26	12	1	0	2	1	0	0	1.1436820783769146	
i 1	22.496224489795917	1.5150000000000001	72	698	4	4	12	0	0	-1	0	0	0	3.914296641668232	
i 1	22.49642857142857	2.525	63	1196	5	25	9	1	0	2	1	0	0	1.1436820783769146	
i 1	22.497244897959185	1.01	63	1196	3	27	11	1	0	1	1	0	0	2.1321394585081688	
i 1	22.4984693877551	2.525	61	1196	5	14	10	1	0	1	1	0	0	7.98949226299543	
i 1	22.499081632653063	2.525	63	1196	5	14	3	1	0	2	1	0	0	7.98949226299543	
i 1	22.499285714285715	0.2525	72	382	5	9	8	1	0	0	1	0	0	2.914296641668232	
i 1	22.500102040816326	1.7675	74	1196	6	1	11	17	0	1	17	0	0	2.0	
i 1	22.500102040816326	1.5150000000000001	61	698	5	25	2	16	0	1	16	0	0	1.1436820783769146	
i 1	22.500510204081632	0.505	77	1196	3	24	14	16	0	1	16	0	0	3.0	
i 1	22.500510204081632	0.2525	72	1196	5	2	12	0	0	0	0	0	0	3.914296641668232	
i 1	22.500714285714285	0.505	74	1196	6	5	8	16	0	2	16	0	0	10.408474343763665	
i 1	22.500714285714285	0.7575000000000001	74	382	6	5	13	17	0	1	17	0	0	10.408474343763665	
i 1	22.500714285714285	1.01	74	1196	2	20	16	8	0	1	8	0	0	5.798276341665121	
i 1	22.501122448979594	0.505	63	382	4	26	4	16	0	1	16	0	0	1.1436820783769146	
i 1	22.501938775510204	0.7575000000000001	72	1196	5	2	6	1	0	-1	1	0	0	3.914296641668232	
i 1	22.50234693877551	1.5150000000000001	77	698	6	5	10	16	0	1	16	0	0	10.408474343763665	
i 1	22.502755102040815	0.2525	71	382	3	20	7	2	0	1	2	0	0	5.798276341665121	
i 1	22.502959183673468	0.505	71	1196	2	24	11	2	0	1	2	0	0	9.79827634166512	
i 1	22.50357142857143	0.2525	74	382	3	20	13	2	0	1	2	0	0	5.798276341665121	
i 1	22.503775510204083	2.02	61	1196	5	25	13	16	0	2	16	0	0	1.1436820783769146	
i 1	22.503979591836735	1.01	63	698	4	7	1	1	0	2	1	0	0	3.9979523098797722	
i 1	22.749081632653063	0.2525	72	1196	5	3	4	1	0	-1	1	0	0	3.914296641668232	
i 1	22.750102040816326	0.505	74	382	4	1	10	17	0	1	17	0	0	2.0	
i 1	22.750918367346937	0.2525	71	1196	2	20	10	2	0	1	2	0	0	5.798276341665121	
i 1	22.752959183673468	1.01	72	698	4	3	13	0	0	0	0	0	0	3.914296641668232	
i 1	22.75316326530612	0.2525	74	1196	2	24	6	2	0	1	2	0	0	9.79827634166512	
i 1	22.754183673469388	0.2525	74	1196	3	1	16	17	0	2	17	0	0	2.0	
i 1	22.995	0.2525	77	1196	6	5	13	16	0	1	16	0	0	10.408474343763665	
i 1	22.996224489795917	0.2525	69	382	4	9	8	1	0	0	1	0	0	2.914296641668232	
i 1	22.997040816326532	0.2525	74	1196	4	20	9	8	0	-2	8	0	0	5.798276341665121	
i 1	22.999489795918368	2.02	63	382	4	26	3	16	0	1	16	0	0	1.1436820783769146	
i 1	23.00030612244898	0.2525	77	1196	6	1	2	16	0	2	16	0	0	2.0	
i 1	23.0015306122449	0.2525	77	698	6	5	13	17	0	1	17	0	0	10.408474343763665	
i 1	23.002142857142857	0.2525	71	698	3	24	3	8	0	1	8	0	0	9.79827634166512	
i 1	23.002959183673468	0.505	77	698	4	24	1	16	0	1	16	0	0	3.0	
i 1	23.003367346938777	2.02	74	382	3	20	12	2	0	1	2	0	0	5.798276341665121	
i 1	23.003775510204083	1.01	61	1196	3	27	10	16	0	2	16	0	0	2.1321394585081688	
i 1	23.00438775510204	0.2525	71	698	3	20	6	8	0	-2	8	0	0	5.798276341665121	
i 1	23.247244897959185	0.2525	73	1196	2	20	9	16	0	2	16	0	0	5.798276341665121	
i 1	23.248673469387754	0.2525	69	1196	4	4	14	1	0	0	1	0	0	3.914296641668232	
i 1	23.25030612244898	0.505	76	382	3	20	9	17	0	2	17	0	0	5.798276341665121	
i 1	23.250714285714285	0.505	73	382	3	20	7	16	0	1	16	0	0	5.798276341665121	
i 1	23.251938775510204	0.2525	72	1196	5	2	15	0	0	0	0	0	0	3.914296641668232	
i 1	23.251938775510204	0.2525	73	1196	2	24	15	16	0	2	16	0	0	9.79827634166512	
i 1	23.252142857142857	0.2525	77	1196	3	24	12	16	0	1	16	0	0	3.0	
i 1	23.253979591836735	0.505	77	1196	6	5	12	17	0	1	17	0	0	10.408474343763665	
i 1	23.254591836734694	0.2525	77	382	6	5	3	17	0	2	17	0	0	10.408474343763665	
i 1	23.495204081632654	0.2525	77	1196	6	5	8	16	0	1	16	0	0	10.408474343763665	
i 1	23.495816326530612	1.5150000000000001	63	382	4	26	6	1	0	2	1	0	0	1.1436820783769146	
i 1	23.495816326530612	1.01	63	1196	3	27	11	1	0	1	1	0	0	2.1321394585081688	
i 1	23.496224489795917	0.505	77	698	6	1	10	17	0	2	17	0	0	2.0	
i 1	23.496632653061223	1.5150000000000001	72	1196	5	2	10	1	0	-1	1	0	0	3.914296641668232	
i 1	23.500714285714285	0.2525	74	1196	2	24	8	2	0	1	2	0	0	9.79827634166512	
i 1	23.501938775510204	0.2525	74	1196	3	1	7	17	0	2	17	0	0	2.0	
i 1	23.50316326530612	0.2525	74	382	6	1	15	16	0	2	16	0	0	2.0	
i 1	23.503367346938777	0.505	63	698	4	7	3	1	0	2	1	0	0	3.9979523098797722	
i 1	23.50357142857143	0.505	77	698	6	5	1	17	0	1	17	0	0	10.408474343763665	
i 1	23.74561224489796	0.505	73	1196	4	20	7	17	0	1	17	0	0	5.798276341665121	
i 1	23.74765306122449	1.2625	74	1196	2	20	11	8	0	1	8	0	0	5.798276341665121	
i 1	23.749081632653063	0.2525	69	1196	4	4	12	1	0	0	1	0	0	3.914296641668232	
i 1	23.750102040816326	0.2525	72	382	4	9	11	1	0	0	1	0	0	2.914296641668232	
i 1	23.750510204081632	0.505	76	1196	4	20	10	17	0	1	17	0	0	5.798276341665121	
i 1	23.752755102040815	0.2525	77	698	4	24	7	16	0	1	16	0	0	3.0	
i 1	23.752959183673468	0.2525	74	1196	6	5	1	17	0	1	17	0	0	10.408474343763665	
i 1	23.75316326530612	0.7575000000000001	77	1196	3	24	12	16	0	1	16	0	0	3.0	
i 1	23.754795918367346	0.2525	73	698	3	24	5	16	0	1	16	0	0	9.79827634166512	
i 1	23.99561224489796	0.2525	72	1196	3	3	4	1	0	-1	1	0	0	3.914296641668232	
i 1	23.996632653061223	1.01	69	880	6	5	8	1	0	-1	1	0	0	10.408474343763665	
i 1	23.99683673469388	1.5150000000000001	61	880	5	25	1	6	0	1	6	0	0	1.1436820783769146	
i 1	23.99683673469388	1.01	61	1196	3	27	14	16	0	2	16	0	0	2.1321394585081688	
i 1	23.99826530612245	0.2525	77	1196	6	5	12	16	0	1	16	0	0	10.408474343763665	
i 1	23.998877551020406	0.2525	69	1196	3	4	4	1	0	0	1	0	0	3.914296641668232	
i 1	24.00030612244898	0.2525	77	880	4	4	12	17	0	1	17	0	0	3.914296641668232	
i 1	24.000714285714285	0.505	74	1196	6	5	5	16	0	2	16	0	0	10.408474343763665	
i 1	24.000918367346937	0.2525	76	880	3	24	4	17	0	2	17	0	0	9.79827634166512	
i 1	24.001326530612246	2.525	61	880	4	7	6	9	0	2	9	0	0	3.9979523098797722	
i 1	24.001938775510204	1.5150000000000001	75	880	6	1	6	8	0	-2	8	0	0	2.0	
i 1	24.002959183673468	0.505	75	880	4	24	1	2	0	-2	2	0	0	3.0	
i 1	24.004591836734694	2.02	66	880	5	25	14	9	0	1	9	0	0	1.1436820783769146	
i 1	24.005	0.2525	73	880	3	20	14	16	0	2	16	0	0	5.798276341665121	
i 1	24.245408163265306	0.2525	73	1196	2	24	14	17	0	1	17	0	0	9.79827634166512	
i 1	24.247244897959185	0.7575000000000001	74	382	6	1	5	17	0	1	17	0	0	2.0	
i 1	24.24765306122449	0.505	74	382	6	5	2	17	0	1	17	0	0	10.408474343763665	
i 1	24.24826530612245	0.505	74	880	4	3	13	17	0	2	17	0	0	3.914296641668232	
i 1	24.251122448979594	0.2525	73	382	3	20	14	17	0	2	17	0	0	5.798276341665121	
i 1	24.2515306122449	0.2525	73	1196	2	20	13	16	0	1	16	0	0	5.798276341665121	
i 1	24.25173469387755	0.2525	72	382	4	9	11	1	0	0	1	0	0	2.914296641668232	
i 1	24.252142857142857	0.2525	77	1196	6	5	6	17	0	1	17	0	0	10.408474343763665	
i 1	24.25316326530612	0.2525	76	382	4	20	4	16	0	1	16	0	0	5.798276341665121	
i 1	24.49561224489796	0.505	69	382	4	9	7	1	0	0	1	0	0	2.914296641668232	
i 1	24.497244897959185	0.2525	74	382	6	1	13	16	0	2	16	0	0	2.0	
i 1	24.497448979591837	0.505	63	1196	3	27	4	1	0	1	1	0	0	2.1321394585081688	
i 1	24.498061224489796	0.2525	73	880	3	20	13	17	0	1	17	0	0	5.798276341665121	
i 1	24.499285714285715	0.505	77	1196	6	1	1	16	0	2	16	0	0	2.0	
i 1	24.499285714285715	0.2525	74	1196	6	5	4	17	0	1	17	0	0	10.408474343763665	
i 1	24.501122448979594	0.2525	73	1196	4	20	7	16	0	1	16	0	0	5.798276341665121	
i 1	24.501326530612246	0.2525	76	880	3	24	11	17	0	1	17	0	0	9.79827634166512	
i 1	24.501938775510204	0.2525	73	1196	4	20	16	17	0	2	17	0	0	5.798276341665121	
i 1	24.748061224489796	0.2525	73	382	4	20	10	17	0	1	17	0	0	5.798276341665121	
i 1	24.74826530612245	0.2525	73	1196	2	24	4	16	0	1	16	0	0	9.79827634166512	
i 1	24.748877551020406	0.2525	69	1196	3	4	10	1	0	0	1	0	0	3.914296641668232	
i 1	24.749285714285715	0.2525	73	1196	2	20	4	17	0	2	17	0	0	5.798276341665121	
i 1	24.74969387755102	0.2525	77	1196	6	5	11	17	0	1	17	0	0	10.408474343763665	
i 1	24.750918367346937	0.2525	74	1196	6	1	15	17	0	1	17	0	0	2.0	
i 1	24.7515306122449	0.2525	72	880	6	5	6	1	0	-1	1	0	0	10.408474343763665	
i 1	24.752959183673468	0.2525	71	382	3	24	14	2	0	-2	2	0	0	9.79827634166512	
i 1	24.75316326530612	0.2525	76	382	4	20	8	17	0	2	17	0	0	5.798276341665121	
i 1	24.754591836734694	0.2525	72	382	4	9	13	1	0	0	1	0	0	2.914296641668232	
i 1	24.995	1.01	77	1111	6	2	12	16	5000	1	16	0	0	3.914296641668232	
i 1	24.995408163265306	2.525	66	178	4	27	2	6	5002	2	6	0	0	2.1321394585081688	
i 1	24.99561224489796	0.505	61	1111	4	14	1	9	5000	2	9	0	0	7.98949226299543	
i 1	24.996224489795917	1.5150000000000001	66	178	5	26	3	9	5001	2	9	0	0	1.1436820783769146	
i 1	24.996224489795917	2.525	66	178	4	27	6	6	5002	1	6	0	0	2.1321394585081688	
i 1	24.996632653061223	0.505	74	880	4	3	5	17	0	2	17	0	0	3.914296641668232	
i 1	24.99683673469388	0.2525	72	178	5	24	6	2	5002	1	2	0	0	3.0	
i 1	24.99683673469388	0.505	69	880	6	5	5	1	0	-1	1	0	0	10.408474343763665	
i 1	24.997040816326532	2.02	66	178	5	26	11	6	5001	2	6	0	0	1.1436820783769146	
i 1	24.998061224489796	1.01	66	1111	4	14	12	9	5000	2	9	0	0	7.98949226299543	
i 1	24.998673469387754	0.7575000000000001	76	178	2	20	5	17	5002	1	17	0	0	5.798276341665121	
i 1	24.999489795918368	0.505	77	880	4	4	1	17	0	1	17	0	0	3.914296641668232	
i 1	24.999489795918368	2.525	72	1111	6	5	14	1	5000	0	1	0	0	10.408474343763665	
i 1	24.999489795918368	0.2525	76	178	4	20	5	17	5000	2	17	0	0	5.798276341665121	
i 1	24.999489795918368	1.01	73	178	3	24	1	16	5001	2	16	0	0	9.79827634166512	
i 1	25.000102040816326	0.2525	73	178	2	24	4	16	0	2	16	0	0	9.79827634166512	
i 1	25.00030612244898	0.505	72	178	7	1	1	2	5001	1	2	0	0	2.0	
i 1	25.0015306122449	1.01	73	178	3	20	10	16	5001	1	16	0	0	5.798276341665121	
i 1	25.001938775510204	0.2525	74	178	3	4	2	17	5002	1	17	0	0	3.914296641668232	
i 1	25.00316326530612	2.02	72	1111	6	1	4	8	5000	1	8	0	0	2.0	
i 1	25.00357142857143	0.2525	69	178	6	5	14	1	5002	-1	1	0	0	10.408474343763665	
i 1	25.245204081632654	0.2525	76	1111	4	20	8	17	5000	1	17	0	0	5.798276341665121	
i 1	25.245408163265306	0.2525	72	880	6	5	6	1	0	-1	1	0	0	10.408474343763665	
i 1	25.246224489795917	0.505	72	178	7	5	11	0	5001	-1	0	0	0	10.408474343763665	
i 1	25.246224489795917	0.2525	73	1111	4	20	13	16	5000	1	16	0	0	5.798276341665121	
i 1	25.247244897959185	0.505	77	178	4	9	15	17	5001	1	17	0	0	2.914296641668232	
i 1	25.249285714285715	0.2525	75	880	4	24	12	2	0	-2	2	0	0	3.0	
i 1	25.25173469387755	0.2525	73	880	3	24	12	17	0	2	17	0	0	9.79827634166512	
i 1	25.496020408163265	0.2525	69	178	6	5	4	1	5002	-1	1	0	0	10.408474343763665	
i 1	25.496224489795917	0.7575000000000001	77	1111	4	2	11	16	5000	1	16	0	0	3.914296641668232	
i 1	25.496224489795917	0.505	73	178	4	20	15	16	5000	1	16	0	0	5.798276341665121	
i 1	25.497448979591837	0.7575000000000001	72	178	7	5	11	0	5001	0	0	0	0	10.408474343763665	
i 1	25.49826530612245	0.2525	74	178	4	9	2	17	5001	2	17	0	0	2.914296641668232	
i 1	25.499489795918368	0.2525	72	178	5	24	12	2	5002	1	2	0	0	3.0	
i 1	25.499489795918368	0.505	61	1111	3	14	9	9	5000	2	9	0	0	7.98949226299543	
i 1	25.50030612244898	0.2525	75	178	7	1	10	2	5002	1	2	0	0	2.0	
i 1	25.50030612244898	0.505	76	178	3	24	15	17	0	1	17	0	0	9.79827634166512	
i 1	25.500510204081632	0.7575000000000001	75	1111	6	1	12	2	5000	1	2	0	0	2.0	
i 1	25.745408163265306	0.2525	74	178	3	4	14	17	5002	1	17	0	0	3.914296641668232	
i 1	25.746632653061223	0.7575000000000001	69	880	6	5	2	1	0	-1	1	0	0	10.408474343763665	
i 1	25.747448979591837	0.2525	77	178	3	3	11	16	5002	2	16	0	0	3.914296641668232	
i 1	25.75030612244898	0.2525	72	178	7	1	6	2	5001	1	2	0	0	2.0	
i 1	25.750510204081632	0.2525	69	178	6	5	8	0	5002	-1	0	0	0	10.408474343763665	
i 1	25.753979591836735	0.2525	72	178	7	1	6	2	5001	-2	2	0	0	2.0	
i 1	25.995	3.7875	73	178	4	24	8	16	5001	2	16	0	0	12.814951589930805	
i 1	25.99642857142857	0.2525	74	178	4	9	15	17	5001	2	17	0	0	2.914296641668232	
i 1	25.99642857142857	1.5150000000000001	61	1111	4	14	1	9	5000	2	9	0	0	7.98949226299543	
i 1	25.997857142857143	0.505	66	1111	3	14	3	9	5000	2	9	0	0	7.98949226299543	
i 1	26.000510204081632	0.505	74	880	5	3	1	17	0	2	17	0	0	3.914296641668232	
i 1	26.001938775510204	0.7575000000000001	73	178	4	20	9	16	5000	1	16	0	0	8.814951589930805	
i 1	26.002142857142857	0.7575000000000001	73	178	4	20	2	16	5000	2	16	0	0	8.814951589930805	
i 1	26.002551020408163	1.01	77	1111	4	2	14	16	5000	1	16	0	0	3.914296641668232	
i 1	26.002959183673468	0.505	75	880	6	1	11	8	0	-2	8	0	0	2.0	
i 1	26.003367346938777	0.2525	72	178	5	24	16	2	5002	1	2	0	0	3.0	
i 1	26.003367346938777	0.505	73	178	3	20	15	16	5001	1	16	0	0	8.814951589930805	
i 1	26.00357142857143	0.505	72	880	6	5	1	1	0	-1	1	0	0	10.408474343763665	
i 1	26.245408163265306	0.2525	72	178	7	1	3	2	5001	-2	2	0	0	2.0	
i 1	26.248061224489796	0.2525	74	178	3	4	13	17	5002	1	17	0	0	3.914296641668232	
i 1	26.249285714285715	0.505	77	178	3	3	8	16	5002	2	16	0	0	3.914296641668232	
i 1	26.251326530612246	0.2525	75	880	4	24	7	2	0	-2	2	0	0	3.0	
i 1	26.252959183673468	0.2525	69	178	6	5	6	1	5002	-1	1	0	0	10.408474343763665	
i 1	26.495408163265306	0.2525	72	178	7	5	1	0	5001	-1	0	0	0	10.408474343763665	
i 1	26.49561224489796	2.02	73	178	4	20	14	16	5001	1	16	0	0	8.814951589930805	
i 1	26.49765306122449	0.2525	76	178	3	24	15	17	0	1	17	0	0	12.814951589930805	
i 1	26.497857142857143	1.5150000000000001	69	699	6	5	5	0	0	-1	0	0	0	10.408474343763665	
i 1	26.497857142857143	1.01	66	1111	4	14	16	9	5000	2	9	0	0	7.98949226299543	
i 1	26.498061224489796	2.02	75	699	6	1	7	2	0	-2	2	0	0	2.0	
i 1	26.498877551020406	1.01	66	1111	5	14	9	6	5000	1	6	0	0	8.948458363762148	
i 1	26.498877551020406	1.5150000000000001	77	699	4	3	2	17	0	1	17	0	0	3.914296641668232	
i 1	26.499897959183674	0.505	77	1111	4	2	14	16	5000	1	16	0	0	3.914296641668232	
i 1	26.50234693877551	0.505	66	699	4	7	14	9	0	2	9	0	0	3.9979523098797722	
i 1	26.502551020408163	2.7775	76	178	2	20	5	17	5002	1	17	0	0	8.814951589930805	
i 1	26.502755102040815	0.2525	72	178	5	24	6	2	5002	1	2	0	0	3.0	
i 1	26.504591836734694	0.2525	69	178	6	5	8	0	5002	-1	0	0	0	10.408474343763665	
i 1	26.504795918367346	0.7575000000000001	75	699	4	24	7	8	0	1	8	0	0	3.0	
i 1	26.747244897959185	0.2525	72	699	6	5	5	1	0	-1	1	0	0	10.408474343763665	
i 1	26.748877551020406	0.2525	69	178	6	5	8	1	5002	-1	1	0	0	10.408474343763665	
i 1	26.748877551020406	0.2525	76	1111	4	20	8	17	5000	1	17	0	0	8.814951589930805	
i 1	26.749489795918368	0.2525	72	178	7	1	15	2	5001	1	2	0	0	2.0	
i 1	26.75030612244898	0.2525	73	699	4	24	6	17	0	2	17	0	0	12.814951589930805	
i 1	26.752142857142857	0.2525	73	1111	4	20	13	16	5000	2	16	0	0	8.814951589930805	
i 1	26.75234693877551	0.2525	74	178	3	4	12	17	5002	1	17	0	0	3.914296641668232	
i 1	26.996020408163265	0.2525	76	178	4	20	5	17	5000	1	17	0	0	8.814951589930805	
i 1	26.997244897959185	0.505	66	699	4	7	9	9	0	2	9	0	0	3.9979523098797722	
i 1	26.997448979591837	0.2525	69	178	7	5	16	0	5002	-1	0	0	0	10.408474343763665	
i 1	26.9984693877551	0.2525	76	178	3	24	7	17	0	1	17	0	0	12.814951589930805	
i 1	26.998673469387754	0.505	72	178	7	5	1	0	5001	-1	0	0	0	10.408474343763665	
i 1	26.999489795918368	0.2525	77	1111	6	2	2	16	5000	1	16	0	0	3.914296641668232	
i 1	27.000918367346937	0.2525	72	178	5	24	16	2	5002	1	2	0	0	3.0	
i 1	27.001122448979594	0.505	61	1111	5	13	14	9	5000	2	9	0	0	5.965638909174765	
i 1	27.001326530612246	1.5150000000000001	74	699	4	4	7	17	0	2	17	0	0	3.914296641668232	
i 1	27.00438775510204	0.505	75	1111	6	1	12	2	5000	1	2	0	0	2.0	
i 1	27.004591836734694	0.2525	77	178	6	9	10	17	5001	1	17	0	0	2.914296641668232	
i 1	27.245408163265306	0.2525	72	1111	6	1	5	8	5000	1	8	0	0	2.0	
i 1	27.245408163265306	0.2525	72	178	7	1	5	2	5001	1	2	0	0	2.0	
i 1	27.245408163265306	0.2525	77	1111	4	2	11	16	5000	1	16	0	0	3.914296641668232	
i 1	27.24642857142857	0.2525	73	699	4	24	6	16	0	2	16	0	0	12.814951589930805	
i 1	27.247244897959185	0.2525	76	1111	4	20	10	17	5000	1	17	0	0	8.814951589930805	
i 1	27.250102040816326	0.2525	72	1111	5	5	12	1	5000	0	1	0	0	10.408474343763665	
i 1	27.254795918367346	0.2525	74	178	6	9	4	17	5001	2	17	0	0	2.914296641668232	
i 1	27.495204081632654	0.2525	73	178	4	20	8	16	0	1	16	0	0	8.814951589930805	
i 1	27.49561224489796	0.7575000000000001	72	178	7	1	7	2	5001	-2	2	0	0	2.0	
i 1	27.497040816326532	1.5150000000000001	66	699	4	7	12	9	0	2	9	0	0	3.9979523098797722	
i 1	27.4984693877551	0.2525	69	178	6	5	12	0	5002	-1	0	0	0	10.408474343763665	
i 1	27.498673469387754	1.01	61	903	5	13	7	9	0	2	9	0	0	5.965638909174765	
i 1	27.498673469387754	1.01	66	903	4	14	3	6	0	1	6	0	0	7.98949226299543	
i 1	27.499081632653063	1.5150000000000001	66	699	5	15	15	6	0	1	6	0	0	6.959912060703892	
i 1	27.499489795918368	0.505	66	178	4	27	8	6	5002	1	6	0	0	2.1321394585081688	
i 1	27.500102040816326	0.2525	77	178	6	9	16	17	5001	1	17	0	0	2.914296641668232	
i 1	27.50030612244898	0.505	69	903	5	5	15	0	0	0	0	0	0	10.408474343763665	
i 1	27.500510204081632	0.2525	76	178	2	24	2	16	0	1	16	0	0	12.814951589930805	
i 1	27.500918367346937	0.505	72	903	6	1	15	8	0	-2	8	0	0	2.0	
i 1	27.501122448979594	0.2525	72	178	7	5	14	0	5001	0	0	0	0	10.408474343763665	
i 1	27.50173469387755	0.505	66	903	5	14	1	9	0	2	9	0	0	8.948458363762148	
i 1	27.50234693877551	0.505	74	903	6	2	6	17	0	2	17	0	0	3.914296641668232	
i 1	27.504183673469388	0.2525	75	178	6	1	15	2	5002	1	2	0	0	2.0	
i 1	27.504795918367346	1.5150000000000001	66	903	4	14	10	6	0	1	6	0	0	7.98949226299543	
i 1	27.745816326530612	0.2525	69	903	6	5	1	0	0	0	0	0	0	10.408474343763665	
i 1	27.74765306122449	0.2525	72	178	7	1	4	2	5001	1	2	0	0	2.0	
i 1	27.750714285714285	0.2525	73	699	4	24	7	17	0	1	17	0	0	12.814951589930805	
i 1	27.753367346938777	0.2525	77	178	4	3	2	16	5002	2	16	0	0	3.914296641668232	
i 1	27.753367346938777	0.7575000000000001	72	699	6	5	10	1	0	-1	1	0	0	10.408474343763665	
i 1	27.754795918367346	0.2525	76	903	4	20	16	16	0	1	16	0	0	8.814951589930805	
i 1	27.995	0.2525	77	903	6	2	2	17	0	2	17	0	0	3.914296641668232	
i 1	27.99561224489796	0.2525	75	699	4	24	13	8	0	1	8	0	0	3.0	
i 1	27.99561224489796	0.2525	74	178	4	4	1	17	5002	1	17	0	0	3.914296641668232	
i 1	27.996224489795917	0.505	69	699	5	5	4	0	0	-1	0	0	0	10.408474343763665	
i 1	27.99642857142857	0.505	72	903	6	1	3	8	0	-2	8	0	0	2.0	
i 1	27.99642857142857	0.505	77	178	4	9	6	17	5001	1	17	0	0	2.914296641668232	
i 1	27.997040816326532	0.2525	69	178	6	5	4	1	5002	-1	1	0	0	10.408474343763665	
i 1	27.99765306122449	2.02	66	903	5	14	8	9	0	2	9	0	0	8.948458363762148	
i 1	28.001122448979594	0.2525	69	903	6	5	10	0	0	0	0	0	0	10.408474343763665	
i 1	28.00438775510204	1.01	61	699	5	15	16	6	0	1	6	0	0	6.959912060703892	
i 1	28.00438775510204	0.2525	76	178	2	24	8	17	0	2	17	0	0	12.814951589930805	
i 1	28.004795918367346	0.2525	73	178	4	20	9	17	0	2	17	0	0	8.814951589930805	
i 1	28.248877551020406	1.2625	69	903	6	5	11	0	0	0	0	0	0	10.408474343763665	
i 1	28.249489795918368	0.2525	73	699	4	24	13	17	0	2	17	0	0	12.814951589930805	
i 1	28.24969387755102	0.2525	77	178	4	3	12	16	5002	2	16	0	0	3.914296641668232	
i 1	28.250714285714285	0.505	72	178	7	1	8	2	5001	1	2	0	0	2.0	
i 1	28.252142857142857	0.2525	72	178	7	5	15	0	5001	-1	0	0	0	10.408474343763665	
i 1	28.252755102040815	0.505	74	903	6	2	14	17	0	2	17	0	0	3.914296641668232	
i 1	28.25438775510204	0.2525	75	178	6	1	9	2	5002	1	2	0	0	2.0	
i 1	28.25438775510204	0.2525	76	903	4	20	5	16	0	2	16	0	0	8.814951589930805	
i 1	28.495204081632654	0.505	72	699	5	5	1	1	0	-1	1	0	0	10.408474343763665	
i 1	28.495204081632654	1.5150000000000001	66	903	5	14	7	6	0	1	6	0	0	7.98949226299543	
i 1	28.49683673469388	1.2625	73	178	4	20	3	16	0	1	16	0	0	8.814951589930805	
i 1	28.497448979591837	0.505	72	903	4	1	2	8	0	-2	8	0	0	2.0	
i 1	28.497448979591837	0.2525	77	178	2	3	13	16	5002	2	16	0	0	3.914296641668232	
i 1	28.49826530612245	1.5150000000000001	77	903	6	2	1	17	0	2	17	0	0	3.914296641668232	
i 1	28.49969387755102	1.01	72	903	4	1	16	8	0	-2	8	0	0	2.0	
i 1	28.49969387755102	0.505	75	699	6	1	8	2	0	-2	2	0	0	2.0	
i 1	28.501122448979594	0.505	73	178	2	24	4	16	0	2	16	0	0	12.814951589930805	
i 1	28.502551020408163	0.2525	72	178	7	5	5	0	5001	0	0	0	0	10.408474343763665	
i 1	28.502959183673468	1.5150000000000001	61	903	5	13	8	9	0	2	9	0	0	5.965638909174765	
i 1	28.504591836734694	1.2625	66	178	5	16	5	9	5001	2	9	0	0	7.954185212233019	
i 1	28.504591836734694	0.505	74	699	4	4	10	17	0	2	17	0	0	3.914296641668232	
i 1	28.505	0.505	69	699	6	5	1	0	0	-1	0	0	0	10.408474343763665	
i 1	28.745816326530612	1.01	72	178	7	1	1	2	5001	-2	2	0	0	2.0	
i 1	28.747244897959185	0.2525	77	178	4	9	15	17	5001	1	17	0	0	2.914296641668232	
i 1	28.748061224489796	0.505	69	178	6	5	6	0	5002	-1	0	0	0	10.408474343763665	
i 1	28.750714285714285	0.2525	74	178	4	9	10	17	5001	2	17	0	0	2.914296641668232	
i 1	28.995816326530612	0.7575000000000001	74	587	4	4	6	17	0	2	17	0	0	3.914296641668232	
i 1	28.996224489795917	0.505	72	587	6	5	13	1	0	-1	1	0	0	10.408474343763665	
i 1	28.997244897959185	1.01	69	903	6	5	1	0	0	0	0	0	0	10.408474343763665	
i 1	28.997448979591837	0.505	72	587	4	1	10	2	0	-2	2	0	0	2.0	
i 1	28.998061224489796	1.01	61	587	4	7	5	9	0	1	9	0	0	3.9979523098797722	
i 1	28.9984693877551	0.2525	75	587	4	24	2	8	0	1	8	0	0	3.0	
i 1	28.999489795918368	0.7575000000000001	66	178	5	16	9	9	5001	1	9	0	0	7.954185212233019	
i 1	28.999489795918368	0.7575000000000001	74	178	6	9	9	17	5001	2	17	0	0	2.914296641668232	
i 1	28.99969387755102	1.01	66	903	5	14	10	6	0	1	6	0	0	7.98949226299543	
i 1	29.000510204081632	0.2525	73	178	2	24	8	17	5002	1	17	0	0	12.814951589930805	
i 1	29.000714285714285	1.01	66	587	5	15	5	6	0	2	6	0	0	6.959912060703892	
i 1	29.000714285714285	0.505	61	587	5	15	9	6	0	2	6	0	0	6.959912060703892	
i 1	29.00234693877551	0.2525	77	178	2	3	1	16	5002	2	16	0	0	3.914296641668232	
i 1	29.246632653061223	0.7575000000000001	73	178	2	24	16	16	0	2	16	0	0	12.814951589930805	
i 1	29.24765306122449	0.2525	72	178	5	24	14	2	5002	1	2	0	0	3.0	
i 1	29.24765306122449	0.505	77	587	5	3	5	16	0	1	16	0	0	3.914296641668232	
i 1	29.250102040816326	0.2525	76	178	2	20	8	16	0	1	16	0	0	8.814951589930805	
i 1	29.253979591836735	0.2525	72	178	5	5	4	0	5001	-1	0	0	0	10.408474343763665	
i 1	29.495408163265306	0.505	61	178	6	12	9	9	5002	2	9	0	0	7.954185212233019	
i 1	29.49683673469388	0.505	72	903	6	1	2	8	0	-2	8	0	0	2.0	
i 1	29.498061224489796	0.505	61	587	5	15	6	6	0	2	6	0	0	6.959912060703892	
i 1	29.498061224489796	0.505	76	178	2	20	4	17	5002	1	17	0	0	8.814951589930805	
i 1	29.498673469387754	0.505	75	587	4	24	7	8	0	1	8	0	0	3.0	
i 1	29.499081632653063	0.505	69	903	5	5	16	0	0	0	0	0	0	10.408474343763665	
i 1	29.499489795918368	0.2525	69	178	6	5	3	0	5002	-1	0	0	0	10.408474343763665	
i 1	29.500102040816326	0.505	72	903	4	1	1	8	0	-2	8	0	0	2.0	
i 1	29.501326530612246	0.2525	72	178	7	5	4	0	5001	-1	0	0	0	10.408474343763665	
i 1	29.746020408163265	0.2525	66	1169	4	16	1	9	0	2	9	0	0	7.954185212233019	
i 1	29.747448979591837	0.2525	66	1169	4	16	8	9	0	2	9	0	0	7.954185212233019	
i 1	29.747448979591837	0.2525	73	1169	4	20	15	17	0	2	17	0	0	8.814951589930805	
i 1	29.74826530612245	0.2525	74	178	2	4	8	17	5002	1	17	0	0	3.914296641668232	
i 1	29.74826530612245	0.2525	69	1169	5	5	16	0	0	0	0	0	0	10.408474343763665	
i 1	29.749285714285715	0.2525	72	1169	6	1	14	2	0	1	2	0	0	2.0	
i 1	29.750918367346937	0.2525	73	1169	4	24	15	16	0	1	16	0	0	12.814951589930805	
i 1	29.7515306122449	0.2525	74	1169	5	9	1	17	0	2	17	0	0	2.914296641668232	
i 1	29.753367346938777	0.2525	77	178	2	3	8	16	5002	2	16	0	0	3.914296641668232	
i 1	29.75357142857143	0.2525	69	178	6	5	10	1	5002	-1	1	0	0	10.408474343763665	
i 1	29.995204081632654	1.01	73	204	4	24	12	17	0	2	17	0	0	12.814951589930805	
i 1	29.996020408163265	0.505	72	1088	6	5	12	1	0	-1	1	0	0	3.075867291838965	
i 1	29.99642857142857	0.505	73	1088	3	24	5	17	0	1	17	0	0	12.814951589930805	
i 1	29.99683673469388	1.5150000000000001	66	702	5	12	16	9	0	1	9	0	0	0.9942731515291277	
i 1	29.997040816326532	3.535	61	1088	4	16	15	9	0	2	9	0	0	0.9942731515291277	
i 1	29.997040816326532	0.2525	77	204	5	4	13	17	0	1	17	0	0	3.1681431551441044	
i 1	29.997448979591837	1.5150000000000001	73	702	2	20	7	16	0	2	16	0	0	8.814951589930805	
i 1	29.998061224489796	2.525	66	204	6	15	13	6	0	2	6	0	0	1.1038649455942547e-16	
i 1	29.9984693877551	1.01	61	702	5	14	12	9	0	1	9	0	0	7.986383241534043	
i 1	29.998673469387754	0.505	77	1088	5	9	9	17	0	1	17	0	0	2.1681431551441044	
i 1	29.998673469387754	0.2525	72	702	6	5	10	1	0	0	1	0	0	3.075867291838965	
i 1	29.999285714285715	0.505	66	1088	4	16	7	9	0	2	9	0	0	0.9942731515291277	
i 1	29.999897959183674	1.5150000000000001	61	702	5	14	15	9	0	2	9	0	0	1.9885463030582553	
i 1	29.999897959183674	0.2525	76	702	4	20	4	17	0	1	17	0	0	8.814951589930805	
i 1	30.000102040816326	3.0300000000000002	66	204	6	15	1	9	0	2	9	0	0	1.1038649455942547e-16	
i 1	30.00030612244898	0.7575000000000001	75	702	6	1	12	2	0	-2	2	0	0	2.0	
i 1	30.000714285714285	0.505	72	702	6	1	9	8	0	-2	8	0	0	2.0	
i 1	30.000714285714285	2.525	69	702	5	5	15	1	0	0	1	0	0	3.075867291838965	
i 1	30.0015306122449	0.2525	75	1088	5	1	13	2	0	1	2	0	0	2.0	
i 1	30.001938775510204	1.01	72	204	4	24	9	8	0	1	8	0	0	3.0	
i 1	30.001938775510204	2.525	74	702	6	2	15	16	0	2	16	0	0	3.1681431551441044	
i 1	30.001938775510204	2.02	61	204	6	7	11	6	0	2	6	0	0	3.9948432884183838	
i 1	30.00316326530612	1.01	66	702	5	12	11	6	0	1	6	0	0	0.9942731515291277	
i 1	30.003367346938777	0.505	77	204	6	3	3	17	0	2	17	0	0	3.1681431551441044	
i 1	30.003979591836735	0.505	61	702	5	14	12	6	0	2	6	0	0	7.986383241534043	
i 1	30.00438775510204	0.2525	69	204	7	5	4	1	0	-1	1	0	0	3.075867291838965	
i 1	30.245408163265306	0.2525	76	204	4	20	14	16	0	2	16	0	0	8.814951589930805	
i 1	30.250918367346937	0.2525	72	702	3	5	6	1	0	0	1	0	0	3.075867291838965	
i 1	30.252755102040815	0.2525	75	204	4	1	5	2	0	-2	2	0	0	2.0	
i 1	30.252755102040815	0.2525	74	702	2	4	10	16	0	2	16	0	0	3.1681431551441044	
i 1	30.254591836734694	0.7575000000000001	72	204	7	5	9	1	0	-1	1	0	0	3.075867291838965	
i 1	30.495	0.2525	74	702	4	4	11	16	0	2	16	0	0	3.1681431551441044	
i 1	30.496020408163265	0.2525	72	702	5	5	12	0	0	0	0	0	0	3.075867291838965	
i 1	30.498061224489796	0.2525	77	702	6	2	11	17	0	2	17	0	0	3.1681431551441044	
i 1	30.498877551020406	3.535	66	1088	4	16	11	9	0	2	9	0	0	0.9942731515291277	
i 1	30.500918367346937	0.505	75	1088	3	1	11	2	0	1	2	0	0	2.0	
i 1	30.50173469387755	2.525	75	204	7	1	15	2	0	-2	2	0	0	2.0	
i 1	30.502142857142857	1.7675	76	1088	3	20	13	17	0	2	17	0	0	8.814951589930805	
i 1	30.502551020408163	2.02	61	702	5	14	11	6	0	2	6	0	0	7.986383241534043	
i 1	30.502959183673468	0.2525	74	702	5	3	13	17	0	1	17	0	0	3.1681431551441044	
i 1	30.502959183673468	0.505	76	702	4	20	13	17	0	1	17	0	0	8.814951589930805	
i 1	30.504591836734694	0.2525	69	1088	6	5	16	1	0	-1	1	0	0	3.075867291838965	
i 1	30.745816326530612	0.2525	77	204	5	4	9	17	0	1	17	0	0	3.1681431551441044	
i 1	30.746632653061223	0.2525	72	1088	6	5	16	1	0	-1	1	0	0	3.075867291838965	
i 1	30.74683673469388	0.2525	72	702	4	24	7	2	0	1	2	0	0	3.0	
i 1	30.74826530612245	0.2525	77	1088	5	9	1	17	0	1	17	0	0	2.1681431551441044	
i 1	30.74969387755102	0.2525	72	702	3	5	2	1	0	0	1	0	0	3.075867291838965	
i 1	30.753775510204083	2.2725	77	204	6	3	7	17	0	2	17	0	0	3.1681431551441044	
i 1	30.995204081632654	0.2525	74	1088	5	9	9	16	0	1	16	0	0	2.1681431551441044	
i 1	30.996224489795917	0.505	72	204	5	24	3	8	0	1	8	0	0	3.0	
i 1	30.996224489795917	0.7575000000000001	76	1088	3	20	5	16	0	1	16	0	0	8.814951589930805	
i 1	30.997244897959185	3.535	66	702	4	12	15	6	0	1	6	0	0	0.9942731515291277	
i 1	30.997857142857143	0.505	72	702	5	5	16	1	0	0	1	0	0	3.075867291838965	
i 1	30.999285714285715	0.505	72	702	5	5	1	1	0	0	1	0	0	3.075867291838965	
i 1	30.999489795918368	2.02	61	702	5	14	16	9	0	1	9	0	0	7.986383241534043	
i 1	31.001122448979594	0.505	76	702	2	24	12	17	0	2	17	0	0	12.814951589930805	
i 1	31.001326530612246	0.505	74	702	4	4	5	16	0	2	16	0	0	3.1681431551441044	
i 1	31.00173469387755	0.2525	75	702	6	1	4	2	0	-2	2	0	0	2.0	
i 1	31.00234693877551	2.525	72	204	5	5	13	1	0	-1	1	0	0	3.075867291838965	
i 1	31.002755102040815	0.2525	75	702	2	1	4	8	0	1	8	0	0	2.0	
i 1	31.246020408163265	0.7575000000000001	72	702	6	1	16	8	0	-2	8	0	0	2.0	
i 1	31.246020408163265	1.7675	76	702	2	24	4	17	0	2	17	0	0	12.814951589930805	
i 1	31.247448979591837	0.505	73	702	2	20	4	16	0	2	16	0	0	8.814951589930805	
i 1	31.249897959183674	0.505	75	1088	3	1	13	2	0	1	2	0	0	2.0	
i 1	31.25316326530612	0.505	77	702	6	2	15	17	0	2	17	0	0	3.1681431551441044	
i 1	31.495816326530612	0.2525	77	204	5	4	10	17	0	1	17	0	0	3.1681431551441044	
i 1	31.498673469387754	1.01	61	702	5	14	3	9	0	2	9	0	0	1.9885463030582553	
i 1	31.500510204081632	0.2525	69	204	5	5	11	1	0	-1	1	0	0	3.075867291838965	
i 1	31.500918367346937	0.2525	72	1088	4	5	13	1	0	-1	1	0	0	3.075867291838965	
i 1	31.50316326530612	1.01	75	702	2	1	11	8	0	1	8	0	0	2.0	
i 1	31.505	3.535	66	702	4	12	14	9	0	1	9	0	0	0.9942731515291277	
i 1	31.745816326530612	0.2525	72	702	5	5	10	1	0	0	1	0	0	3.075867291838965	
i 1	31.749285714285715	0.505	73	204	4	24	3	16	0	2	16	0	0	12.814951589930805	
i 1	31.74969387755102	0.7575000000000001	75	702	6	1	13	2	0	-2	2	0	0	2.0	
i 1	31.750714285714285	0.7575000000000001	72	702	5	5	11	1	0	0	1	0	0	3.075867291838965	
i 1	31.750918367346937	1.2625	73	1088	3	24	4	17	0	1	17	0	0	12.814951589930805	
i 1	31.752142857142857	0.505	76	204	4	20	5	17	0	2	17	0	0	8.814951589930805	
i 1	31.75234693877551	0.2525	76	702	4	20	14	17	0	2	17	0	0	8.814951589930805	
i 1	31.752959183673468	0.7575000000000001	74	702	4	4	6	16	0	2	16	0	0	3.1681431551441044	
i 1	31.75316326530612	0.505	77	1088	5	9	3	17	0	1	17	0	0	2.1681431551441044	
i 1	31.995408163265306	2.02	61	204	7	7	11	6	0	2	6	0	0	3.9948432884183838	
i 1	32.000510204081635	0.2525	72	1088	6	1	14	8	0	-2	8	0	0	2.0	
i 1	32.00071428571429	0.2525	76	702	3	20	5	17	0	2	17	0	0	8.814951589930805	
i 1	32.001938775510204	0.2525	69	1088	4	5	7	1	0	-1	1	0	0	3.075867291838965	
i 1	32.24622448979592	0.505	73	702	2	24	11	17	0	2	17	0	0	12.814951589930805	
i 1	32.24989795918367	0.505	76	702	2	20	6	16	0	1	16	0	0	8.814951589930805	
i 1	32.25091836734694	0.2525	75	1088	6	1	13	2	0	1	2	0	0	2.0	
i 1	32.25214285714286	1.2625	77	204	5	4	9	17	0	1	17	0	0	3.1681431551441044	
i 1	32.25316326530612	0.2525	72	702	5	5	13	1	0	0	1	0	0	3.075867291838965	
i 1	32.4954081632653	0.2525	75	702	6	1	5	8	0	1	8	0	0	2.0	
i 1	32.4954081632653	1.5150000000000001	61	702	5	14	10	6	0	2	6	0	0	7.986383241534043	
i 1	32.49908163265306	1.5150000000000001	75	702	4	1	6	2	0	-2	2	0	0	2.0	
i 1	32.49989795918367	0.2525	72	702	4	1	8	8	0	-2	8	0	0	2.0	
i 1	32.50173469387755	1.01	66	204	5	15	10	6	0	2	6	0	0	1.1038649455942547e-16	
i 1	32.50173469387755	0.2525	74	1088	5	9	16	16	0	1	16	0	0	2.1681431551441044	
i 1	32.50214285714286	0.505	69	204	5	5	2	1	0	-1	1	0	0	3.075867291838965	
i 1	32.50234693877551	0.2525	77	702	6	2	6	17	0	2	17	0	0	3.1681431551441044	
i 1	32.50234693877551	0.2525	73	1088	1	20	15	16	0	2	16	0	0	8.814951589930805	
i 1	32.50316326530612	0.2525	72	702	6	5	10	0	0	0	0	0	0	3.075867291838965	
i 1	32.503571428571426	0.2525	69	702	6	5	11	1	0	0	1	0	0	3.075867291838965	
i 1	32.504387755102044	0.505	76	1088	3	20	7	17	0	2	17	0	0	8.814951589930805	
i 1	32.746632653061226	0.2525	72	702	2	24	1	2	0	1	2	0	0	3.0	
i 1	32.74683673469388	0.2525	76	702	2	20	8	16	0	1	16	0	0	8.814951589930805	
i 1	32.74785714285714	0.2525	76	204	4	24	2	17	0	2	17	0	0	12.814951589930805	
i 1	32.7484693877551	0.505	74	702	4	4	12	16	0	2	16	0	0	3.1681431551441044	
i 1	32.748673469387754	0.2525	75	1088	6	1	6	2	0	1	2	0	0	2.0	
i 1	32.751326530612246	0.2525	76	204	4	20	13	17	0	1	17	0	0	8.814951589930805	
i 1	32.75377551020408	0.505	74	702	6	2	4	16	0	2	16	0	0	3.1681431551441044	
i 1	32.75377551020408	1.01	72	1088	4	5	12	1	0	-1	1	0	0	3.075867291838965	
i 1	32.75397959183673	0.2525	69	1088	4	5	4	1	0	-1	1	0	0	3.075867291838965	
i 1	32.995612244897956	1.5150000000000001	76	1088	3	20	14	17	0	2	17	0	0	10.69585629946961	
i 1	32.995816326530615	1.5150000000000001	61	702	5	14	11	9	0	1	9	0	0	7.986383241534043	
i 1	32.9984693877551	0.2525	72	702	4	1	13	8	0	-2	8	0	0	2.0	
i 1	32.999489795918365	2.02	69	204	6	5	2	1	0	-1	1	0	0	3.075867291838965	
i 1	32.99969387755102	1.01	76	702	2	24	3	17	0	2	17	0	0	14.69585629946961	
i 1	33.00010204081633	0.2525	76	702	2	24	2	17	0	1	17	0	0	14.69585629946961	
i 1	33.00030612244898	0.2525	73	1088	3	24	7	17	0	1	17	0	0	14.69585629946961	
i 1	33.000510204081635	1.2625	77	204	6	3	11	17	0	2	17	0	0	3.1681431551441044	
i 1	33.001122448979594	0.2525	73	1088	1	20	4	16	0	1	16	0	0	10.69585629946961	
i 1	33.001326530612246	0.2525	73	702	1	20	5	16	0	2	16	0	0	10.69585629946961	
i 1	33.00173469387755	0.2525	72	702	6	5	15	0	0	0	0	0	0	3.075867291838965	
i 1	33.00255102040816	0.2525	72	204	5	24	4	8	0	1	8	0	0	3.0	
i 1	33.00295918367347	1.01	66	204	5	15	2	9	0	2	9	0	0	1.1038649455942547e-16	
i 1	33.00316326530612	1.01	75	702	6	1	10	8	0	1	8	0	0	2.0	
i 1	33.245	0.2525	72	1088	6	1	15	8	0	-2	8	0	0	2.0	
i 1	33.24602040816327	0.2525	77	1088	5	9	3	17	0	1	17	0	0	2.1681431551441044	
i 1	33.2484693877551	0.505	77	702	6	2	7	17	0	2	17	0	0	3.1681431551441044	
i 1	33.248877551020406	0.2525	73	204	3	20	3	17	0	2	17	0	0	10.69585629946961	
i 1	33.24908163265306	0.2525	73	702	2	20	3	17	0	1	17	0	0	10.69585629946961	
i 1	33.25010204081633	0.2525	72	702	4	24	11	2	0	1	2	0	0	3.0	
i 1	33.25091836734694	0.2525	69	1088	4	5	1	1	0	-1	1	0	0	3.075867291838965	
i 1	33.497244897959185	1.01	75	1088	6	1	5	2	0	1	2	0	0	2.0	
i 1	33.498061224489796	0.2525	72	702	3	5	10	1	0	0	1	0	0	3.075867291838965	
i 1	33.49969387755102	0.505	73	1088	3	24	2	17	0	1	17	0	0	14.69585629946961	
i 1	33.49989795918367	1.5150000000000001	77	204	5	4	5	17	0	1	17	0	0	3.1681431551441044	
i 1	33.49989795918367	0.505	72	702	6	5	1	0	0	0	0	0	0	3.075867291838965	
i 1	33.500510204081635	0.7575000000000001	74	702	5	3	12	17	0	1	17	0	0	3.1681431551441044	
i 1	33.501938775510204	1.01	73	1088	1	20	4	16	0	2	16	0	0	10.69585629946961	
i 1	33.50316326530612	1.01	61	1088	4	16	9	9	0	2	9	0	0	0.9942731515291277	
i 1	33.503367346938774	0.505	76	702	1	24	4	17	0	1	17	0	0	14.69585629946961	
i 1	33.50479591836735	0.2525	72	702	6	1	4	8	0	-2	8	0	0	2.0	
i 1	33.74602040816327	0.2525	74	1088	5	9	1	16	0	1	16	0	0	2.1681431551441044	
i 1	33.747244897959185	0.2525	72	1088	6	1	3	8	0	-2	8	0	0	2.0	
i 1	33.74785714285714	0.2525	69	702	6	5	5	1	0	0	1	0	0	3.075867291838965	
i 1	33.75255102040816	0.2525	69	1088	4	5	5	1	0	-1	1	0	0	3.075867291838965	
i 1	33.99520408163265	0.2525	72	702	3	5	2	1	0	0	1	0	0	3.075867291838965	
i 1	33.99602040816327	0.505	73	1088	2	24	2	17	0	1	17	0	0	14.69585629946961	
i 1	33.996632653061226	1.01	66	1088	4	16	16	9	0	2	9	0	0	0.9942731515291277	
i 1	33.998061224489796	1.01	75	702	6	1	5	2	0	-2	2	0	0	2.0	
i 1	33.998877551020406	1.01	61	204	6	7	10	6	0	2	6	0	0	3.9948432884183838	
i 1	34.00010204081633	0.2525	72	1088	5	5	5	1	0	-1	1	0	0	3.075867291838965	
i 1	34.00071428571429	0.2525	72	702	3	5	10	1	0	0	1	0	0	3.075867291838965	
i 1	34.00091836734694	0.7575000000000001	74	702	4	4	6	16	0	2	16	0	0	3.1681431551441044	
i 1	34.0015306122449	1.01	61	702	4	14	8	6	0	2	6	0	0	7.986383241534043	
i 1	34.003367346938774	0.2525	72	204	4	24	6	8	0	1	8	0	0	3.0	
i 1	34.00397959183673	0.505	75	204	4	1	15	2	0	-2	2	0	0	2.0	
i 1	34.24520408163265	0.7575000000000001	74	702	6	2	9	16	0	2	16	0	0	3.1681431551441044	
i 1	34.246428571428574	0.2525	72	702	6	1	16	8	0	-2	8	0	0	2.0	
i 1	34.251122448979594	0.7575000000000001	72	702	5	5	7	0	0	0	0	0	0	3.075867291838965	
i 1	34.251122448979594	0.2525	69	702	6	5	16	1	0	0	1	0	0	3.075867291838965	
i 1	34.251326530612246	0.2525	74	1088	5	9	3	16	0	1	16	0	0	2.1681431551441044	
i 1	34.253571428571426	0.2525	72	204	6	5	4	1	0	-1	1	0	0	3.075867291838965	
i 1	34.495	0.2525	77	204	6	3	1	17	0	2	17	0	0	3.1681431551441044	
i 1	34.49520408163265	1.01	66	702	3	12	9	6	0	1	6	0	0	0.9942731515291277	
i 1	34.496632653061226	0.2525	75	702	6	1	4	8	0	1	8	0	0	2.0	
i 1	34.498877551020406	0.2525	72	1088	5	5	12	1	0	-1	1	0	0	3.075867291838965	
i 1	34.49989795918367	0.505	76	1088	1	20	4	16	0	1	16	0	0	10.69585629946961	
i 1	34.49989795918367	1.01	73	702	2	20	13	16	0	2	16	0	0	10.69585629946961	
i 1	34.501326530612246	0.505	75	204	7	1	6	2	0	-2	2	0	0	2.0	
i 1	34.50173469387755	0.505	69	702	5	5	6	1	0	0	1	0	0	3.075867291838965	
i 1	34.50316326530612	0.505	73	1088	1	24	2	17	0	1	17	0	0	14.69585629946961	
i 1	34.50397959183673	0.505	61	702	4	14	13	9	0	1	9	0	0	7.986383241534043	
i 1	34.505	0.505	72	204	4	24	1	8	0	1	8	0	0	3.0	
i 1	34.748673469387754	0.2525	69	1088	5	5	7	1	0	-1	1	0	0	3.075867291838965	
i 1	34.749489795918365	0.2525	77	1088	5	9	3	17	0	1	17	0	0	2.1681431551441044	
i 1	34.75214285714286	0.2525	72	702	6	1	11	8	0	-2	8	0	0	2.0	
i 1	34.7545918367347	0.2525	74	1088	5	9	15	16	0	1	16	0	0	2.1681431551441044	
i 1	34.995	0.2525	77	204	6	9	15	17	0	1	17	0	0	2.1681431551441044	
i 1	34.99602040816327	1.01	69	1088	4	5	8	1	0	-1	1	0	0	3.075867291838965	
i 1	34.99622448979592	0.505	72	702	6	1	6	2	5003	-2	2	0	0	2.0	
i 1	34.996428571428574	0.2525	72	1088	6	1	8	2	0	1	2	0	0	2.0	
i 1	34.996632653061226	0.505	76	204	2	24	13	16	0	1	16	0	0	14.69585629946961	
i 1	34.997244897959185	0.505	73	204	2	20	5	16	0	1	16	0	0	10.69585629946961	
i 1	34.99765306122449	1.5150000000000001	73	204	2	20	9	17	0	1	17	0	0	10.69585629946961	
i 1	34.9984693877551	0.2525	75	204	4	1	13	2	0	-2	2	0	0	2.0	
i 1	34.99908163265306	0.505	72	702	5	5	16	1	5003	0	1	0	0	3.075867291838965	
i 1	34.99908163265306	0.505	72	204	6	5	16	0	0	0	0	0	0	3.075867291838965	
i 1	34.99989795918367	1.01	75	702	4	24	10	2	5003	1	2	0	0	3.0	
i 1	35.00091836734694	2.525	74	1088	6	2	6	16	0	2	16	0	0	3.1681431551441044	
i 1	35.00091836734694	0.505	72	1088	5	5	1	1	0	0	1	0	0	3.075867291838965	
i 1	35.001122448979594	0.2525	74	204	6	9	1	17	0	1	17	0	0	2.1681431551441044	
i 1	35.00173469387755	0.505	66	1088	4	14	11	9	0	2	9	0	0	7.986383241534043	
i 1	35.00214285714286	0.505	77	702	4	4	9	16	5003	2	16	0	0	3.1681431551441044	
i 1	35.00316326530612	0.505	61	702	6	7	5	6	5003	2	6	0	0	3.9948432884183838	
i 1	35.003367346938774	1.01	66	1088	4	14	8	9	0	1	9	0	0	7.986383241534043	
i 1	35.004183673469385	1.01	66	702	3	12	10	9	0	1	9	0	0	0.9942731515291277	
i 1	35.24622448979592	1.01	77	1088	6	2	16	17	0	2	17	0	0	3.1681431551441044	
i 1	35.250510204081635	0.2525	74	702	4	4	11	16	0	2	16	0	0	3.1681431551441044	
i 1	35.25397959183673	0.2525	72	702	4	24	16	2	0	1	2	0	0	3.0	
i 1	35.255	0.505	75	702	2	1	12	8	0	1	8	0	0	2.0	
i 1	35.49520408163265	0.2525	74	702	4	4	5	16	0	2	16	0	0	3.1681431551441044	
i 1	35.4954081632653	0.2525	75	204	7	1	6	2	0	-2	2	0	0	2.0	
i 1	35.49785714285714	0.2525	72	702	4	5	14	1	0	0	1	0	0	3.075867291838965	
i 1	35.499489795918365	1.5150000000000001	61	702	4	7	10	6	5003	2	6	0	0	3.9948432884183838	
i 1	35.50030612244898	0.2525	72	702	2	24	16	2	0	1	2	0	0	3.0	
i 1	35.500510204081635	0.2525	74	702	4	3	16	17	0	1	17	0	0	3.1681431551441044	
i 1	35.50071428571429	1.5150000000000001	72	1088	4	5	2	1	0	0	1	0	0	3.075867291838965	
i 1	35.501938775510204	0.2525	69	702	5	5	12	1	5003	0	1	0	0	3.075867291838965	
i 1	35.501938775510204	0.2525	73	1088	2	20	1	17	0	1	17	0	0	10.69585629946961	
i 1	35.50234693877551	0.2525	76	702	2	24	8	17	5003	1	17	0	0	14.69585629946961	
i 1	35.503571428571426	1.5150000000000001	66	1088	5	14	11	9	0	2	9	0	0	7.986383241534043	
i 1	35.50479591836735	0.505	73	702	1	20	9	16	0	2	16	0	0	10.69585629946961	
i 1	35.747244897959185	1.5150000000000001	77	702	4	4	7	16	5003	2	16	0	0	3.1681431551441044	
i 1	35.74928571428571	0.2525	77	204	6	9	7	17	0	1	17	0	0	2.1681431551441044	
i 1	35.749489795918365	0.7575000000000001	72	1088	6	1	3	2	0	1	2	0	0	2.0	
i 1	35.75010204081633	0.2525	72	702	6	1	16	2	5003	-2	2	0	0	2.0	
i 1	35.750510204081635	0.505	76	204	2	20	4	17	0	2	17	0	0	10.69585629946961	
i 1	35.75071428571429	0.505	72	702	4	5	16	1	0	0	1	0	0	3.075867291838965	
i 1	35.75234693877551	0.505	72	1088	6	1	4	2	0	1	2	0	0	2.0	
i 1	35.75295918367347	0.2525	72	702	5	5	2	1	5003	0	1	0	0	3.075867291838965	
i 1	35.995	0.505	74	204	6	9	6	17	0	1	17	0	0	2.1681431551441044	
i 1	36.00030612244898	0.505	69	204	5	5	11	0	0	0	0	0	0	3.075867291838965	
i 1	36.000510204081635	0.505	75	204	7	1	10	2	0	-2	2	0	0	2.0	
i 1	36.00255102040816	0.505	75	702	4	24	12	2	5003	1	2	0	0	3.0	
i 1	36.00377551020408	0.2525	72	702	4	5	7	1	0	0	1	0	0	3.075867291838965	
i 1	36.004183673469385	1.5150000000000001	66	1088	5	14	10	9	0	1	9	0	0	7.986383241534043	
i 1	36.2454081632653	0.7575000000000001	72	702	4	5	11	1	5003	0	1	0	0	3.075867291838965	
i 1	36.24765306122449	0.2525	75	702	2	1	11	8	0	1	8	0	0	2.0	
i 1	36.24908163265306	0.2525	72	204	6	5	11	0	0	0	0	0	0	3.075867291838965	
i 1	36.24969387755102	0.2525	76	204	2	24	11	16	0	1	16	0	0	14.69585629946961	
i 1	36.254183673469385	0.505	74	702	4	4	15	16	0	2	16	0	0	3.1681431551441044	
i 1	36.49683673469388	0.2525	72	702	4	5	16	1	0	0	1	0	0	3.075867291838965	
i 1	36.49826530612245	0.2525	74	702	4	3	6	17	0	1	17	0	0	3.1681431551441044	
i 1	36.498673469387754	1.01	72	1088	6	1	1	2	0	1	2	0	0	2.0	
i 1	36.49989795918367	0.505	72	702	4	5	9	1	0	0	1	0	0	3.075867291838965	
i 1	36.50030612244898	0.505	72	702	2	24	4	2	0	1	2	0	0	3.0	
i 1	36.50234693877551	1.5150000000000001	76	204	2	20	13	17	0	2	17	0	0	10.69585629946961	
i 1	36.50316326530612	0.2525	75	204	7	1	8	2	0	-2	2	0	0	2.0	
i 1	36.503571428571426	1.01	75	702	4	24	13	2	5003	1	2	0	0	3.0	
i 1	36.74704081632653	0.7575000000000001	72	204	5	5	4	0	0	0	0	0	0	3.075867291838965	
i 1	36.748673469387754	0.2525	74	204	6	9	9	17	0	1	17	0	0	2.1681431551441044	
i 1	36.75234693877551	0.2525	77	204	6	9	10	17	0	1	17	0	0	2.1681431551441044	
i 1	36.7545918367347	0.2525	75	702	6	1	1	8	0	1	8	0	0	2.0	
i 1	36.75479591836735	2.2725	76	204	2	24	4	16	0	1	16	0	0	14.69585629946961	
i 1	36.9954081632653	0.505	74	702	5	3	11	17	5003	1	17	0	0	3.1681431551441044	
i 1	36.996428571428574	0.505	61	702	6	7	15	6	5003	2	6	0	0	3.9948432884183838	
i 1	36.99704081632653	0.2525	74	702	4	4	15	16	0	2	16	0	0	3.1681431551441044	
i 1	36.99744897959184	0.505	69	204	4	5	7	0	0	0	0	0	0	3.075867291838965	
i 1	36.9984693877551	0.505	72	702	6	1	10	2	5003	-2	2	0	0	2.0	
i 1	36.99928571428571	0.505	72	1088	6	5	5	1	0	0	1	0	0	3.075867291838965	
i 1	37.00010204081633	0.2525	75	204	7	1	5	2	0	-2	2	0	0	2.0	
i 1	37.001122448979594	0.505	69	1088	6	5	10	1	0	-1	1	0	0	3.075867291838965	
i 1	37.00295918367347	0.505	66	1088	5	14	8	9	0	2	9	0	0	7.986383241534043	
i 1	37.24928571428571	0.2525	74	702	4	3	12	17	0	1	17	0	0	3.1681431551441044	
i 1	37.25071428571429	0.2525	74	204	6	9	2	17	0	1	17	0	0	2.1681431551441044	
i 1	37.25255102040816	0.2525	72	1088	6	1	5	2	0	1	2	0	0	2.0	
i 1	37.495	0.2525	77	702	4	4	5	16	5003	2	16	0	0	3.0	
i 1	37.4954081632653	2.525	74	702	5	3	6	17	5003	1	17	0	0	3.0	
i 1	37.495816326530615	0.7575000000000001	74	204	7	2	16	17	0	1	17	0	0	3.0	
i 1	37.49704081632653	0.505	72	204	7	1	7	2	0	-2	2	0	0	5.0	
i 1	37.49928571428571	2.2725	69	204	7	5	16	0	0	0	0	0	0	2.0	
i 1	37.50010204081633	2.02	72	702	6	1	8	2	5003	-2	2	0	0	5.0	
i 1	37.50030612244898	0.505	72	1088	4	1	12	2	0	-2	2	0	0	5.0	
i 1	37.50091836734694	0.505	69	702	4	5	8	1	5003	0	1	0	0	2.0	
i 1	37.501122448979594	0.2525	75	204	7	1	13	2	0	-2	2	0	0	5.0	
i 1	37.50295918367347	0.505	72	702	6	5	8	1	5003	0	1	0	0	2.0	
i 1	37.50316326530612	0.505	69	204	7	5	2	0	0	0	0	0	0	2.0	
i 1	37.503367346938774	0.2525	77	204	6	9	2	17	0	1	17	0	0	2.0	
i 1	37.74744897959184	0.2525	74	1088	4	4	4	16	0	2	16	0	0	3.0	
i 1	37.75071428571429	0.2525	77	1088	4	3	3	17	0	2	17	0	0	3.0	
i 1	37.7545918367347	0.2525	75	204	7	1	5	2	0	-2	2	0	0	5.0	
i 1	37.995612244897956	0.2525	72	1088	2	5	10	0	0	-1	0	0	0	2.0	
i 1	37.99683673469388	0.2525	72	1088	5	1	14	2	0	-2	2	0	0	5.0	
i 1	37.998673469387754	0.505	69	204	4	5	3	0	0	0	0	0	0	2.0	
i 1	38.00030612244898	0.2525	75	702	4	24	16	2	5003	1	2	0	0	6.0	
i 1	38.000510204081635	0.2525	75	204	7	1	6	2	0	-2	2	0	0	5.0	
i 1	38.00091836734694	0.2525	77	204	7	2	8	16	0	2	16	0	0	3.0	
i 1	38.00377551020408	0.2525	74	204	6	9	2	17	0	1	17	0	0	2.0	
i 1	38.00377551020408	0.2525	72	204	4	5	4	0	0	0	0	0	0	2.0	
i 1	38.2454081632653	0.2525	72	204	7	1	11	2	0	-2	2	0	0	5.0	
i 1	38.24683673469388	1.7675	72	204	7	1	14	2	0	-2	2	0	0	5.0	
i 1	38.2484693877551	0.2525	75	1088	4	24	10	8	0	-2	8	0	0	6.0	
i 1	38.2484693877551	0.505	74	1088	4	4	15	16	0	2	16	0	0	3.0	
i 1	38.248877551020406	0.2525	77	204	6	9	8	17	0	1	17	0	0	2.0	
i 1	38.24908163265306	0.2525	69	204	7	5	6	0	0	0	0	0	0	2.0	
i 1	38.25091836734694	0.2525	69	702	6	5	13	1	5003	0	1	0	0	2.0	
i 1	38.254387755102044	0.2525	77	1088	4	3	14	17	0	2	17	0	0	3.0	
i 1	38.49520408163265	1.01	74	204	7	2	4	17	0	1	17	0	0	3.0	
i 1	38.49520408163265	0.505	73	204	2	20	13	17	0	1	17	0	0	10.69585629946961	
i 1	38.49704081632653	0.505	69	204	7	5	10	0	0	0	0	0	0	2.0	
i 1	38.498061224489796	0.2525	72	1088	3	5	4	1	0	0	1	0	0	2.0	
i 1	38.49826530612245	2.525	72	702	6	5	16	1	5003	0	1	0	0	2.0	
i 1	38.498877551020406	0.2525	75	1088	4	24	10	8	0	-2	8	0	0	6.0	
i 1	38.501122448979594	0.2525	72	1088	5	1	15	2	0	-2	2	0	0	5.0	
i 1	38.50397959183673	2.02	77	702	4	4	4	16	5003	2	16	0	0	3.0	
i 1	38.7454081632653	0.505	72	1088	2	5	6	0	0	-1	0	0	0	2.0	
i 1	38.748673469387754	0.2525	75	204	7	1	3	2	0	-2	2	0	0	5.0	
i 1	38.74969387755102	0.2525	77	204	6	9	2	17	0	1	17	0	0	2.0	
i 1	38.750510204081635	0.2525	76	204	2	20	13	17	0	1	17	0	0	10.69585629946961	
i 1	38.7515306122449	0.2525	75	702	4	24	1	2	5003	1	2	0	0	6.0	
i 1	38.996632653061226	0.2525	69	204	7	5	1	0	0	0	0	0	0	2.0	
i 1	38.99704081632653	1.01	76	204	2	20	12	17	0	2	17	0	0	10.804292165060033	
i 1	38.99826530612245	1.01	76	204	2	24	9	16	0	1	16	0	0	14.804292165060033	
i 1	38.99989795918367	0.2525	72	204	7	1	15	2	0	-2	2	0	0	5.0	
i 1	39.002755102040815	0.2525	75	204	6	1	5	2	0	-2	2	0	0	5.0	
i 1	39.003571428571426	1.01	73	204	2	20	12	17	0	1	17	0	0	10.804292165060033	
i 1	39.005	0.2525	77	1088	4	3	9	17	0	2	17	0	0	3.0	
i 1	39.246428571428574	0.2525	72	1088	5	1	9	2	0	-2	2	0	0	5.0	
i 1	39.247244897959185	0.7575000000000001	75	1088	4	24	4	8	0	-2	8	0	0	6.0	
i 1	39.24928571428571	0.2525	69	204	7	5	13	0	0	0	0	0	0	2.0	
i 1	39.250510204081635	0.2525	77	204	7	2	11	16	0	2	16	0	0	3.0	
i 1	39.25377551020408	0.2525	72	204	7	5	10	0	0	0	0	0	0	2.0	
i 1	39.49602040816327	0.2525	72	1088	6	5	16	0	0	-1	0	0	0	2.0	
i 1	39.497244897959185	0.2525	75	702	4	24	13	2	5003	1	2	0	0	6.0	
i 1	39.49908163265306	0.505	69	702	6	5	11	1	5003	0	1	0	0	2.0	
i 1	39.49928571428571	0.2525	74	1088	4	4	7	16	0	2	16	0	0	3.0	
i 1	39.499489795918365	0.2525	75	204	6	1	8	2	0	-2	2	0	0	5.0	
i 1	39.50316326530612	0.2525	77	204	6	9	14	17	0	1	17	0	0	2.0	
i 1	39.7454081632653	0.2525	72	1088	4	1	1	2	0	-2	2	0	0	5.0	
i 1	39.74908163265306	0.2525	77	1088	4	3	5	17	0	2	17	0	0	3.0	
i 1	39.749489795918365	0.2525	72	1088	3	5	15	1	0	0	1	0	0	2.0	
i 1	39.74969387755102	0.2525	72	204	7	5	4	0	0	0	0	0	0	2.0	
i 1	39.75071428571429	0.2525	75	204	6	1	14	2	0	-2	2	0	0	5.0	
i 1	39.754387755102044	0.2525	77	204	7	2	11	16	0	2	16	0	0	3.0	
i 1	39.9954081632653	0.505	72	702	6	1	15	2	5003	-2	2	0	0	5.0	
i 1	39.995612244897956	0.505	73	1088	1	20	15	16	0	1	16	0	0	10.804292165060033	
i 1	39.995816326530615	0.2525	72	702	4	1	15	2	0	-2	2	0	0	5.0	
i 1	39.995816326530615	0.2525	75	702	4	24	13	2	0	1	2	0	0	6.0	
i 1	39.997244897959185	1.7675	72	204	7	1	3	2	0	-2	2	0	0	5.0	
i 1	39.999489795918365	0.2525	69	204	6	5	7	0	0	0	0	0	0	2.0	
i 1	39.99969387755102	0.505	73	1088	1	20	4	17	0	2	17	0	0	10.804292165060033	
i 1	39.99989795918367	0.505	72	1088	6	5	6	1	0	-1	1	0	0	2.0	
i 1	40.002755102040815	0.505	74	702	5	3	8	17	5003	1	17	0	0	3.0	
i 1	40.00295918367347	0.505	74	204	7	2	7	17	0	1	17	0	0	3.0	
i 1	40.004387755102044	0.2525	77	702	4	3	2	17	0	2	17	0	0	3.0	
i 1	40.005	0.2525	72	702	6	5	7	1	0	0	1	0	0	2.0	
i 1	40.245	0.505	72	1088	6	5	5	1	0	0	1	0	0	2.0	
i 1	40.24765306122449	0.505	77	1088	5	9	11	17	0	2	17	0	0	2.0	
i 1	40.25071428571429	0.2525	69	702	6	5	2	1	5003	0	1	0	0	2.0	
i 1	40.25214285714286	0.2525	72	1088	5	1	2	2	0	1	2	0	0	5.0	
i 1	40.25255102040816	2.2725	76	1088	1	24	16	17	0	2	17	0	0	14.804292165060033	
i 1	40.25479591836735	0.2525	72	204	7	1	8	2	0	-2	2	0	0	5.0	
i 1	40.49744897959184	0.2525	69	204	6	5	14	0	0	0	0	0	0	2.0	
i 1	40.49826530612245	0.2525	77	204	7	2	6	16	0	2	16	0	0	3.0	
i 1	40.4984693877551	0.2525	69	204	6	5	1	0	0	0	0	0	0	2.0	
i 1	40.501122448979594	1.2625	72	702	4	1	15	2	0	-2	2	0	0	5.0	
i 1	40.501326530612246	0.7575000000000001	77	702	4	3	8	17	0	2	17	0	0	3.0	
i 1	40.50214285714286	0.505	75	702	4	24	8	2	5003	1	2	0	0	6.0	
i 1	40.502755102040815	3.0300000000000002	77	702	4	4	7	16	5003	2	16	0	0	3.0	
i 1	40.50377551020408	2.525	72	702	6	1	6	2	5003	-2	2	0	0	5.0	
i 1	40.504183673469385	0.505	61	204	7	17	4	6	0	2	6	0	0	2.158988688416838	
i 1	40.745	0.2525	76	702	2	20	5	16	5003	2	16	0	0	10.804292165060033	
i 1	40.74520408163265	0.2525	72	702	6	5	3	1	0	0	1	0	0	2.0	
i 1	40.74744897959184	0.505	73	702	2	24	9	16	5003	2	16	0	0	14.804292165060033	
i 1	40.75030612244898	0.505	69	702	6	5	3	0	0	-1	0	0	0	2.0	
i 1	40.751326530612246	0.2525	74	702	5	3	5	17	5003	1	17	0	0	3.0	
i 1	40.751326530612246	0.505	77	702	4	4	8	17	0	1	17	0	0	3.0	
i 1	40.75377551020408	0.2525	69	702	6	5	7	1	5003	0	1	0	0	2.0	
i 1	40.99520408163265	0.505	69	204	6	5	14	0	0	0	0	0	0	2.0	
i 1	40.995816326530615	0.2525	74	1088	5	9	6	17	0	2	17	0	0	2.0	
i 1	40.99622448979592	0.505	61	204	7	17	14	9	0	1	9	0	0	2.158988688416838	
i 1	40.998061224489796	1.2625	72	702	5	5	10	1	5003	0	1	0	0	2.0	
i 1	40.998673469387754	0.2525	76	204	4	20	12	17	0	1	17	0	0	10.804292165060033	
i 1	40.99969387755102	1.5150000000000001	61	204	6	17	16	6	0	2	6	0	0	2.158988688416838	
i 1	41.00091836734694	0.2525	69	204	6	5	13	0	0	0	0	0	0	2.0	
i 1	41.0015306122449	0.505	75	702	4	24	13	2	0	1	2	0	0	6.0	
i 1	41.24520408163265	0.2525	72	1088	6	5	1	1	0	-1	1	0	0	2.0	
i 1	41.248877551020406	0.2525	74	204	7	2	9	17	0	1	17	0	0	3.0	
i 1	41.25030612244898	0.2525	77	1088	5	9	6	17	0	2	17	0	0	2.0	
i 1	41.25091836734694	0.505	77	204	7	2	3	16	0	2	16	0	0	3.0	
i 1	41.25214285714286	0.2525	69	702	6	5	7	1	5003	0	1	0	0	2.0	
i 1	41.25255102040816	1.2625	73	1088	3	20	12	17	0	2	17	0	0	10.804292165060033	
i 1	41.49520408163265	1.01	61	204	6	17	2	9	0	1	9	0	0	2.158988688416838	
i 1	41.49704081632653	0.505	69	204	5	5	14	0	0	0	0	0	0	2.0	
i 1	41.49785714285714	0.505	74	1088	5	9	14	17	0	2	17	0	0	2.0	
i 1	41.499489795918365	0.505	61	702	6	17	5	9	5003	2	9	0	0	2.158988688416838	
i 1	41.50010204081633	0.2525	74	702	5	3	15	17	5003	1	17	0	0	3.0	
i 1	41.501326530612246	0.7575000000000001	75	702	4	24	12	2	5003	1	2	0	0	6.0	
i 1	41.503367346938774	0.2525	69	702	6	5	10	0	0	-1	0	0	0	2.0	
i 1	41.504183673469385	0.2525	72	1088	6	5	13	1	0	0	1	0	0	2.0	
i 1	41.745	0.2525	72	702	6	5	2	1	0	0	1	0	0	2.0	
i 1	41.7484693877551	0.2525	75	1088	5	1	14	2	0	1	2	0	0	5.0	
i 1	41.748877551020406	0.2525	77	702	4	3	1	17	0	2	17	0	0	3.0	
i 1	41.753571428571426	0.2525	77	702	4	4	16	17	0	1	17	0	0	3.0	
i 1	41.7545918367347	0.7575000000000001	72	204	7	1	8	2	0	-2	2	0	0	5.0	
i 1	41.7545918367347	0.2525	69	204	6	5	5	0	0	0	0	0	0	2.0	
i 1	41.995612244897956	0.505	69	204	5	5	4	0	0	0	0	0	0	2.0	
i 1	41.99602040816327	0.2525	75	1088	6	1	2	2	0	1	2	0	0	5.0	
i 1	41.99602040816327	0.505	69	204	7	5	8	0	0	0	0	0	0	2.0	
i 1	41.997244897959185	2.02	61	702	5	17	10	9	5003	2	9	0	0	2.158988688416838	
i 1	41.99826530612245	0.505	61	702	6	17	10	9	5003	1	9	0	0	2.158988688416838	
i 1	42.00071428571429	0.505	69	702	6	5	4	0	0	-1	0	0	0	2.0	
i 1	42.001122448979594	0.505	77	702	5	3	7	17	0	2	17	0	0	3.0	
i 1	42.00255102040816	0.2525	73	702	2	24	9	16	5003	2	16	0	0	14.804292165060033	
i 1	42.00397959183673	0.505	76	702	2	20	16	16	5003	2	16	0	0	10.804292165060033	
i 1	42.004387755102044	0.505	77	204	6	2	15	16	0	2	16	0	0	3.0	
i 1	42.005	0.2525	74	702	5	3	13	17	5003	1	17	0	0	3.0	
i 1	42.246632653061226	0.2525	75	702	4	24	1	2	0	1	2	0	0	6.0	
i 1	42.247244897959185	0.2525	72	1088	6	5	3	1	0	0	1	0	0	2.0	
i 1	42.24928571428571	0.2525	72	702	4	1	12	2	0	-2	2	0	0	5.0	
i 1	42.25214285714286	0.2525	74	1088	5	9	13	17	0	2	17	0	0	2.0	
i 1	42.4954081632653	0.505	75	1192	6	1	10	2	0	1	2	0	0	5.0	
i 1	42.4954081632653	0.2525	72	1192	6	1	7	2	0	1	2	0	0	5.0	
i 1	42.495612244897956	2.02	66	1192	6	17	11	9	0	1	9	0	0	2.158988688416838	
i 1	42.496632653061226	0.2525	69	702	5	5	12	1	5003	0	1	0	0	2.0	
i 1	42.49908163265306	1.5150000000000001	77	1192	6	2	16	16	0	1	16	0	0	3.0	
i 1	42.50010204081633	0.505	69	1192	6	5	14	1	0	-1	1	0	0	2.0	
i 1	42.501122448979594	0.505	66	1192	4	18	3	9	0	2	9	0	0	2.158988688416838	
i 1	42.501326530612246	0.2525	76	702	4	20	9	16	5003	2	16	0	0	10.804292165060033	
i 1	42.5015306122449	0.2525	74	925	4	4	10	16	0	1	16	0	0	3.0	
i 1	42.50173469387755	0.2525	72	1192	6	1	4	8	0	1	8	0	0	5.0	
i 1	42.50173469387755	2.02	69	1192	6	5	16	1	0	-1	1	0	0	2.0	
i 1	42.501938775510204	2.525	66	1192	6	17	5	6	0	1	6	0	0	2.158988688416838	
i 1	42.50214285714286	0.2525	74	702	5	3	6	17	5003	1	17	0	0	3.0	
i 1	42.50214285714286	1.5150000000000001	61	702	5	17	10	9	5003	1	9	0	0	2.158988688416838	
i 1	42.50214285714286	0.7575000000000001	72	925	6	5	2	0	0	-1	0	0	0	2.0	
i 1	42.50214285714286	1.2625	76	1192	4	20	13	17	0	2	17	0	0	10.804292165060033	
i 1	42.5045918367347	1.5150000000000001	76	1192	4	24	1	16	0	1	16	0	0	14.804292165060033	
i 1	42.74744897959184	0.7575000000000001	76	925	2	24	12	16	5003	2	16	0	0	14.804292165060033	
i 1	42.74765306122449	0.2525	75	925	4	24	4	8	0	-2	8	0	0	6.0	
i 1	42.748877551020406	0.2525	72	1192	6	1	7	2	0	1	2	0	0	5.0	
i 1	42.748877551020406	0.7575000000000001	74	1192	5	9	3	16	0	2	16	0	0	2.0	
i 1	42.75030612244898	0.2525	72	702	4	5	16	1	5003	0	1	0	0	2.0	
i 1	42.75173469387755	0.505	73	925	2	20	7	17	5003	2	17	0	0	10.804292165060033	
i 1	42.753571428571426	0.505	74	925	5	3	5	16	0	1	16	0	0	3.0	
i 1	42.995	0.2525	69	1192	5	5	2	0	0	0	0	0	0	2.0	
i 1	42.995816326530615	0.505	72	925	6	1	13	2	0	1	2	0	0	5.0	
i 1	42.99826530612245	0.2525	75	925	4	24	8	8	0	-2	8	0	0	6.0	
i 1	42.99989795918367	1.01	75	702	4	24	7	2	5003	1	2	0	0	6.0	
i 1	42.99989795918367	2.02	66	1192	4	18	8	9	0	2	9	0	0	2.158988688416838	
i 1	43.001938775510204	0.7575000000000001	72	925	3	5	4	1	0	0	1	0	0	2.0	
i 1	43.00255102040816	1.01	75	1192	5	1	13	2	0	1	2	0	0	5.0	
i 1	43.004183673469385	0.505	61	1192	4	18	2	9	0	1	9	0	0	2.158988688416838	
i 1	43.24826530612245	0.2525	74	1192	6	2	12	17	0	2	17	0	0	3.0	
i 1	43.249489795918365	1.7675	69	1192	6	5	5	1	0	-1	1	0	0	2.0	
i 1	43.251122448979594	0.2525	72	1192	6	1	15	2	0	1	2	0	0	5.0	
i 1	43.251938775510204	0.2525	72	702	6	5	9	1	5003	0	1	0	0	2.0	
i 1	43.2545918367347	0.7575000000000001	73	1192	4	20	4	17	0	2	17	0	0	10.804292165060033	
i 1	43.255	0.7575000000000001	73	1192	4	20	2	17	0	2	17	0	0	10.804292165060033	
i 1	43.495816326530615	0.505	74	1192	6	2	1	17	0	2	17	0	0	3.0	
i 1	43.49602040816327	1.5150000000000001	72	1192	5	1	5	8	0	1	8	0	0	5.0	
i 1	43.496632653061226	0.2525	72	925	3	5	14	0	0	-1	0	0	0	2.0	
i 1	43.49785714285714	1.5150000000000001	61	1192	4	18	10	9	0	1	9	0	0	2.158988688416838	
i 1	43.49908163265306	0.505	61	925	4	19	3	6	0	2	6	0	0	2.158988688416838	
i 1	43.49989795918367	0.505	74	702	5	3	8	17	5003	1	17	0	0	3.0	
i 1	43.5015306122449	0.2525	73	702	4	24	1	17	5003	2	17	0	0	14.804292165060033	
i 1	43.503367346938774	0.2525	77	1192	5	9	11	16	0	2	16	0	0	2.0	
i 1	43.50397959183673	0.2525	76	702	4	20	1	17	5003	1	17	0	0	10.804292165060033	
i 1	43.504183673469385	0.2525	72	1192	6	1	1	2	0	1	2	0	0	5.0	
i 1	43.74826530612245	0.2525	76	925	2	20	2	17	5003	2	17	0	0	10.804292165060033	
i 1	43.7484693877551	0.2525	69	1192	4	5	15	0	0	0	0	0	0	2.0	
i 1	43.74969387755102	0.2525	69	702	6	5	1	1	5003	0	1	0	0	2.0	
i 1	43.75010204081633	0.2525	76	925	2	24	4	16	5003	1	16	0	0	14.804292165060033	
i 1	43.75234693877551	0.2525	72	1192	6	1	11	2	0	1	2	0	0	5.0	
i 1	43.75255102040816	0.2525	74	925	5	3	8	16	0	1	16	0	0	3.0	
i 1	43.99520408163265	1.01	77	610	4	4	14	17	0	2	17	0	0	3.0	
i 1	43.9954081632653	0.2525	76	610	4	20	1	16	0	2	16	0	0	9.036973062326796	
i 1	43.99602040816327	0.2525	72	610	6	5	10	1	0	0	1	0	0	2.0	
i 1	43.99622448979592	1.01	66	610	5	17	13	9	0	1	9	0	0	2.158988688416838	
i 1	43.99744897959184	0.505	73	1192	4	20	7	17	0	2	17	0	0	9.036973062326796	
i 1	43.99785714285714	1.01	73	1192	4	20	12	17	0	2	17	0	0	9.036973062326796	
i 1	43.998877551020406	0.2525	73	610	4	24	16	16	0	1	16	0	0	13.036973062326796	
i 1	43.99969387755102	0.2525	77	1192	5	9	14	16	0	2	16	0	0	2.0	
i 1	43.99969387755102	0.2525	76	1192	4	24	12	16	0	1	16	0	0	13.036973062326796	
i 1	44.00030612244898	0.505	75	610	4	24	4	8	0	1	8	0	0	6.0	
i 1	44.00071428571429	0.505	66	926	4	19	10	6	0	1	6	0	0	2.158988688416838	
i 1	44.001326530612246	1.01	66	610	5	17	6	9	0	2	9	0	0	2.158988688416838	
i 1	44.0015306122449	0.505	74	610	5	3	7	16	0	1	16	0	0	3.0	
i 1	44.00316326530612	1.01	61	926	3	19	12	9	0	1	9	0	0	2.158988688416838	
i 1	44.00316326530612	0.2525	72	926	3	5	1	0	0	-1	0	0	0	2.0	
i 1	44.003571428571426	0.505	77	1192	6	2	13	16	0	1	16	0	0	3.0	
i 1	44.00397959183673	1.01	72	610	4	1	1	2	0	-2	2	0	0	5.0	
i 1	44.004183673469385	0.2525	72	1192	6	1	10	2	0	1	2	0	0	5.0	
i 1	44.0045918367347	1.01	73	926	2	20	13	17	0	2	17	0	0	9.036973062326796	
i 1	44.245	0.2525	74	1192	6	2	11	17	0	2	17	0	0	3.0	
i 1	44.24520408163265	0.7575000000000001	76	926	2	24	16	16	0	1	16	0	0	13.036973062326796	
i 1	44.2454081632653	0.505	73	926	2	20	4	17	0	1	17	0	0	9.036973062326796	
i 1	44.248061224489796	0.505	72	610	6	5	10	0	0	0	0	0	0	2.0	
i 1	44.25010204081633	0.2525	72	1192	6	1	9	2	0	1	2	0	0	5.0	
i 1	44.25091836734694	0.2525	69	1192	4	5	15	0	0	-1	0	0	0	2.0	
i 1	44.495	0.505	75	926	4	24	10	2	0	-2	2	0	0	6.0	
i 1	44.49520408163265	0.505	74	610	5	3	12	16	0	1	16	0	0	3.0	
i 1	44.495612244897956	0.505	73	1192	1	20	9	17	0	2	17	0	0	9.036973062326796	
i 1	44.49704081632653	0.2525	74	926	5	3	13	16	0	1	16	0	0	3.0	
i 1	44.49704081632653	0.505	72	610	6	5	10	1	0	0	1	0	0	2.0	
i 1	44.497244897959185	0.505	66	926	3	19	16	6	0	1	6	0	0	2.158988688416838	
i 1	44.4984693877551	0.505	76	1192	4	24	14	16	0	1	16	0	0	13.036973062326796	
i 1	44.499489795918365	0.2525	74	1192	5	9	14	16	0	2	16	0	0	2.0	
i 1	44.49969387755102	0.2525	69	1192	6	5	12	0	0	0	0	0	0	2.0	
i 1	44.50214285714286	0.505	66	1192	6	17	11	9	0	1	9	0	0	2.158988688416838	
i 1	44.50295918367347	0.505	75	1192	5	1	6	2	0	1	2	0	0	5.0	
i 1	44.745612244897956	0.2525	77	1192	6	2	2	16	0	1	16	0	0	3.0	
i 1	44.74928571428571	0.2525	69	1192	6	5	2	0	0	-1	0	0	0	2.0	
i 1	44.751122448979594	0.2525	74	926	4	4	9	17	0	1	17	0	0	3.0	
i 1	44.751326530612246	0.2525	72	926	2	5	2	0	0	0	0	0	0	2.0	
i 1	44.995	0.505	75	1089	4	1	6	8	0	1	8	0	0	2.0	
i 1	44.995612244897956	1.01	61	205	5	16	1	6	0	1	6	0	0	0.9942731515291277	
i 1	44.995612244897956	0.7575000000000001	77	1089	3	3	4	16	0	1	16	0	0	3.0	
i 1	44.996632653061226	1.5150000000000001	77	703	4	4	4	17	0	1	17	0	0	3.0	
i 1	44.996632653061226	0.505	66	703	5	17	6	6	0	2	6	0	0	5.081929982520583	
i 1	44.99704081632653	2.02	75	703	4	1	15	2	0	1	2	0	0	2.0	
i 1	44.99704081632653	1.5150000000000001	66	205	5	18	5	9	0	1	9	0	0	5.081929982520583	
i 1	44.997244897959185	0.505	73	1089	2	24	13	17	0	2	17	0	0	13.036973062326796	
i 1	44.997244897959185	0.2525	76	1089	2	20	3	16	0	2	16	0	0	9.036973062326796	
i 1	44.99765306122449	0.505	66	1089	5	12	16	9	0	2	9	0	0	0.9942731515291277	
i 1	44.99785714285714	0.2525	69	205	7	5	9	0	0	0	0	0	0	2.0	
i 1	44.9984693877551	0.505	73	205	4	20	2	17	0	2	17	0	0	9.036973062326796	
i 1	44.998673469387754	1.01	72	1089	4	1	6	2	0	-2	2	0	0	2.0	
i 1	44.998673469387754	1.5150000000000001	66	1089	3	19	8	9	0	1	9	0	0	5.081929982520583	
i 1	44.99928571428571	0.505	66	1089	6	17	5	9	0	1	9	0	0	5.081929982520583	
i 1	44.99989795918367	0.505	66	703	5	15	11	9	0	1	9	0	0	2.7596623639856367e-17	
i 1	45.0015306122449	0.2525	74	1089	4	4	14	16	0	1	16	0	0	3.0	
i 1	45.001938775510204	2.02	61	205	5	18	6	6	0	1	6	0	0	5.081929982520583	
i 1	45.00214285714286	1.5150000000000001	66	205	5	16	16	9	0	1	9	0	0	0.9942731515291277	
i 1	45.00255102040816	1.5150000000000001	66	1089	3	19	8	9	0	2	9	0	0	5.081929982520583	
i 1	45.00255102040816	0.2525	72	205	7	5	8	1	0	0	1	0	0	2.0	
i 1	45.002755102040815	1.01	76	205	4	24	14	16	0	2	16	0	0	13.036973062326796	
i 1	45.00295918367347	0.505	73	205	1	20	10	17	0	1	17	0	0	9.036973062326796	
i 1	45.003367346938774	0.505	72	1089	6	5	9	1	0	0	1	0	0	2.0	
i 1	45.00377551020408	0.7575000000000001	74	703	5	3	10	17	0	1	17	0	0	3.0	
i 1	45.004387755102044	0.2525	75	1089	4	24	16	2	0	1	2	0	0	3.0	
i 1	45.004387755102044	1.5150000000000001	72	703	6	5	10	1	0	0	1	0	0	2.0	
i 1	45.0045918367347	1.01	61	1089	5	12	6	6	0	1	6	0	0	0.9942731515291277	
i 1	45.0045918367347	1.01	66	703	5	17	1	6	0	1	6	0	0	5.081929982520583	
i 1	45.2484693877551	0.2525	72	703	6	5	9	0	0	-1	0	0	0	2.0	
i 1	45.24908163265306	0.505	69	1089	6	5	5	1	0	0	1	0	0	2.0	
i 1	45.25214285714286	0.2525	72	205	7	1	4	2	0	1	2	0	0	2.0	
i 1	45.25234693877551	0.2525	77	1089	6	2	7	17	0	1	17	0	0	3.0	
i 1	45.495816326530615	1.01	66	1089	5	12	3	9	0	2	9	0	0	0.9942731515291277	
i 1	45.496632653061226	1.01	72	1089	5	5	11	1	0	0	1	0	0	2.0	
i 1	45.49744897959184	0.505	72	1089	6	5	12	1	0	0	1	0	0	2.0	
i 1	45.498673469387754	0.505	74	205	5	9	7	16	0	1	16	0	0	2.0	
i 1	45.498673469387754	1.01	76	1089	2	24	9	17	0	1	17	0	0	13.036973062326796	
i 1	45.49908163265306	0.505	66	703	6	17	3	6	0	2	6	0	0	5.081929982520583	
i 1	45.50091836734694	2.02	72	703	4	24	12	2	0	-2	2	0	0	3.0	
i 1	45.501938775510204	0.505	73	205	4	20	10	17	0	1	17	0	0	9.036973062326796	
i 1	45.50397959183673	0.2525	75	1089	6	1	8	2	0	-2	2	0	0	2.0	
i 1	45.74704081632653	0.505	77	1089	5	2	6	16	0	2	16	0	0	3.0	
i 1	45.75071428571429	0.505	69	205	7	5	15	0	0	0	0	0	0	2.0	
i 1	45.751326530612246	0.2525	77	1089	6	2	2	17	0	1	17	0	0	3.0	
i 1	45.753367346938774	0.505	72	205	4	1	16	2	0	1	2	0	0	2.0	
i 1	45.996428571428574	0.505	69	1089	5	5	15	1	0	-1	1	0	0	2.0	
i 1	45.99744897959184	0.505	61	1089	5	12	11	6	0	1	6	0	0	0.9942731515291277	
i 1	45.99744897959184	0.505	76	1089	2	20	6	17	0	2	17	0	0	9.036973062326796	
i 1	45.99785714285714	0.505	66	703	6	17	6	6	0	1	6	0	0	5.081929982520583	
i 1	45.998673469387754	0.505	77	205	6	9	15	17	0	1	17	0	0	2.0	
i 1	46.00010204081633	0.505	75	1089	6	1	8	8	0	1	8	0	0	2.0	
i 1	46.004387755102044	0.505	74	703	5	3	16	17	0	1	17	0	0	3.0	
i 1	46.0045918367347	1.01	76	205	1	24	6	16	0	2	16	0	0	13.036973062326796	
i 1	46.245816326530615	0.7575000000000001	77	1089	5	2	3	17	0	1	17	0	0	3.0	
i 1	46.24602040816327	0.2525	75	1089	2	1	4	2	0	-2	2	0	0	2.0	
i 1	46.24765306122449	0.2525	72	205	7	5	16	1	0	0	1	0	0	2.0	
i 1	46.25234693877551	0.2525	73	205	4	20	7	17	0	1	17	0	0	9.036973062326796	
i 1	46.4954081632653	0.2525	74	703	5	3	11	17	0	1	17	0	0	3.0	
i 1	46.495612244897956	0.505	77	703	4	4	3	17	0	1	17	0	0	3.0	
i 1	46.495816326530615	0.2525	69	1089	6	5	4	1	0	0	1	0	0	2.0	
i 1	46.496428571428574	1.01	67	1	6	12	15	5	0	0	5	0	0	0.9942731515291277	
i 1	46.4984693877551	0.2525	71	703	4	20	15	1	0	0	1	0	0	9.036973062326796	
i 1	46.498673469387754	1.01	60	1	4	19	4	0	0	1	0	0	0	5.081929982520583	
i 1	46.49928571428571	0.2525	74	1	3	24	8	2	0	-1	2	0	0	3.0	
i 1	46.499489795918365	0.505	60	1	6	12	2	5	0	0	5	0	0	0.9942731515291277	
i 1	46.49989795918367	1.01	60	1	4	19	11	0	0	0	0	0	0	5.081929982520583	
i 1	46.501326530612246	0.505	66	205	5	18	3	9	0	1	9	0	0	5.081929982520583	
i 1	46.5015306122449	0.2525	72	205	4	1	12	2	0	-2	2	0	0	2.0	
i 1	46.50173469387755	0.2525	75	1	6	5	3	2	0	1	2	0	0	2.0	
i 1	46.50214285714286	0.2525	77	1089	5	2	10	16	0	2	16	0	0	3.0	
i 1	46.50234693877551	0.2525	71	703	4	24	3	0	0	-1	0	0	0	13.036973062326796	
i 1	46.502755102040815	0.2525	71	1089	4	20	3	1	0	0	1	0	0	9.036973062326796	
i 1	46.50316326530612	0.505	71	1	3	24	13	0	0	0	0	0	0	13.036973062326796	
i 1	46.503367346938774	0.2525	72	1089	6	5	11	1	0	0	1	0	0	2.0	
i 1	46.503367346938774	2.02	72	703	6	5	11	1	0	0	1	0	0	2.0	
i 1	46.745	0.505	72	1089	6	1	14	2	0	-2	2	0	0	2.0	
i 1	46.745612244897956	0.505	72	205	7	5	10	1	0	0	1	0	0	2.0	
i 1	46.747244897959185	0.7575000000000001	72	1	5	3	11	2	0	1	2	0	0	3.0	
i 1	46.74928571428571	0.505	71	1	3	20	8	1	0	-1	1	0	0	9.036973062326796	
i 1	46.75030612244898	0.2525	75	1	4	4	15	2	0	-2	2	0	0	3.0	
i 1	46.75030612244898	0.7575000000000001	69	205	7	5	13	0	0	0	0	0	0	2.0	
i 1	46.75030612244898	0.505	68	205	4	20	16	1	0	0	1	0	0	9.036973062326796	
i 1	46.75234693877551	0.2525	74	1	3	1	8	8	0	-2	8	0	0	2.0	
i 1	46.753367346938774	0.7575000000000001	73	205	1	20	5	17	0	2	17	0	0	9.036973062326796	
i 1	46.7545918367347	0.505	71	1	3	24	15	1	0	0	1	0	0	13.036973062326796	
i 1	46.755	0.2525	72	703	6	5	10	0	0	-1	0	0	0	2.0	
i 1	46.9954081632653	0.2525	74	205	6	9	8	16	0	1	16	0	0	2.0	
i 1	46.99744897959184	0.505	75	703	6	1	6	2	0	1	2	0	0	2.0	
i 1	46.99785714285714	0.505	76	205	4	24	16	16	0	2	16	0	0	13.036973062326796	
i 1	46.99969387755102	0.505	75	1	5	4	6	2	0	-2	2	0	0	3.0	
i 1	47.00071428571429	0.505	75	1089	6	1	5	8	0	1	8	0	0	2.0	
i 1	47.001326530612246	0.2525	72	1	6	5	16	2	0	-2	2	0	0	2.0	
i 1	47.00316326530612	0.505	61	205	5	18	11	6	0	1	6	0	0	5.081929982520583	
i 1	47.00479591836735	1.5150000000000001	77	703	4	4	6	17	0	1	17	0	0	3.0	
i 1	47.24520408163265	0.2525	75	1	6	5	16	2	0	1	2	0	0	2.0	
i 1	47.24785714285714	0.2525	71	1089	4	20	3	1	0	-1	1	0	0	9.036973062326796	
i 1	47.24928571428571	0.2525	71	703	4	24	15	1	0	-1	1	0	0	13.036973062326796	
i 1	47.25479591836735	0.505	74	703	5	3	8	17	0	1	17	0	0	3.0	
i 1	47.25479591836735	0.2525	72	1089	6	5	5	1	0	0	1	0	0	2.0	
i 1	47.255	0.505	72	205	4	1	1	2	0	-2	2	0	0	2.0	
i 1	47.495	0.505	60	205	5	19	3	0	0	1	0	0	0	5.081929982520583	
i 1	47.49520408163265	0.2525	74	907	6	1	3	8	0	-1	8	0	0	2.0	
i 1	47.495612244897956	0.505	67	205	4	19	13	0	0	0	0	0	0	5.081929982520583	
i 1	47.49622448979592	0.505	73	205	4	20	4	17	0	2	17	0	0	6.117401747206259	
i 1	47.496428571428574	2.02	68	205	4	20	16	1	0	0	1	0	0	6.117401747206259	
i 1	47.49683673469388	1.01	71	205	3	24	2	1	0	0	1	0	0	10.117401747206259	
i 1	47.49826530612245	0.2525	72	703	6	5	4	0	0	-1	0	0	0	2.0	
i 1	47.49908163265306	1.01	76	205	4	24	2	16	0	2	16	0	0	10.117401747206259	
i 1	47.49969387755102	2.525	72	703	4	24	8	2	0	-2	2	0	0	3.0	
i 1	47.50030612244898	2.02	75	907	6	5	4	2	0	-2	2	0	0	2.0	
i 1	47.50071428571429	0.505	71	205	3	1	8	2	0	-2	2	0	0	2.0	
i 1	47.50071428571429	0.505	72	907	4	2	4	2	0	-2	2	0	0	3.0	
i 1	47.5015306122449	0.2525	72	907	6	5	8	2	0	1	2	0	0	2.0	
i 1	47.50214285714286	0.2525	74	205	6	9	6	16	0	1	16	0	0	2.0	
i 1	47.747244897959185	0.2525	71	205	3	24	15	8	0	-1	8	0	0	3.0	
i 1	47.74765306122449	0.505	75	907	4	2	2	2	0	-2	2	0	0	3.0	
i 1	47.74928571428571	0.505	72	205	6	5	15	2	0	-2	2	0	0	2.0	
i 1	47.749489795918365	0.505	75	205	5	4	14	2	0	-2	2	0	0	3.0	
i 1	47.74969387755102	0.505	74	907	6	1	1	8	0	-1	8	0	0	2.0	
i 1	47.751938775510204	0.505	69	205	7	5	5	0	0	0	0	0	0	2.0	
i 1	47.9954081632653	1.5150000000000001	68	205	3	20	4	0	0	0	0	0	0	6.117401747206259	
i 1	47.99989795918367	0.2525	74	205	5	9	5	16	0	1	16	0	0	2.0	
i 1	48.000510204081635	0.505	75	703	6	1	4	2	0	1	2	0	0	2.0	
i 1	48.000510204081635	0.505	67	205	5	19	15	0	0	0	0	0	0	5.081929982520583	
i 1	48.002755102040815	1.01	71	205	3	24	6	1	0	0	1	0	0	10.117401747206259	
i 1	48.003367346938774	0.505	72	205	7	1	12	2	0	-2	2	0	0	2.0	
i 1	48.24622448979592	0.2525	72	907	6	5	7	2	0	1	2	0	0	2.0	
i 1	48.247244897959185	1.01	74	703	4	3	8	17	0	1	17	0	0	3.0	
i 1	48.24765306122449	1.01	72	703	6	5	9	0	0	-1	0	0	0	2.0	
i 1	48.248061224489796	0.2525	72	205	6	3	8	2	0	-2	2	0	0	3.0	
i 1	48.25091836734694	0.7575000000000001	71	205	3	1	9	2	0	-2	2	0	0	2.0	
i 1	48.255	0.7575000000000001	72	907	4	2	6	2	0	-2	2	0	0	3.0	
i 1	48.4954081632653	1.5150000000000001	71	205	3	20	1	1	0	0	1	0	0	6.117401747206259	
i 1	48.49785714285714	0.505	75	205	6	5	4	8	0	1	8	0	0	2.0	
i 1	48.49908163265306	0.7575000000000001	77	703	4	4	1	17	0	1	17	0	0	3.0	
i 1	48.49928571428571	0.2525	69	205	7	5	6	0	0	0	0	0	0	2.0	
i 1	48.50071428571429	0.2525	74	907	6	1	1	8	0	-1	8	0	0	2.0	
i 1	48.504183673469385	0.2525	77	205	5	9	8	17	0	1	17	0	0	2.0	
i 1	48.50479591836735	0.2525	72	205	7	1	5	2	0	1	2	0	0	2.0	
i 1	48.7454081632653	0.2525	75	703	6	1	14	2	0	1	2	0	0	2.0	
i 1	48.74785714285714	0.505	72	205	7	5	12	1	0	0	1	0	0	2.0	
i 1	48.74908163265306	0.2525	75	205	5	4	2	2	0	-2	2	0	0	3.0	
i 1	48.75397959183673	0.2525	72	205	7	1	2	2	0	-2	2	0	0	2.0	
i 1	48.998061224489796	0.505	74	907	6	1	4	8	0	-1	8	0	0	2.0	
i 1	48.99826530612245	0.505	77	205	4	9	13	17	0	1	17	0	0	2.0	
i 1	48.998877551020406	0.2525	72	703	6	5	10	1	0	0	1	0	0	2.0	
i 1	48.99908163265306	2.525	74	907	5	1	8	8	0	-1	8	0	0	2.0	
i 1	48.99908163265306	0.2525	72	205	7	1	12	2	0	1	2	0	0	2.0	
i 1	49.002755102040815	0.505	72	907	5	2	5	2	0	-2	2	0	0	3.0	
i 1	49.00397959183673	1.01	73	205	4	20	9	17	0	2	17	0	0	6.117401747206259	
i 1	49.247244897959185	0.7575000000000001	69	205	7	5	14	0	0	0	0	0	0	2.0	
i 1	49.24744897959184	0.7575000000000001	71	205	3	24	15	1	0	0	1	0	0	10.117401747206259	
i 1	49.24826530612245	0.2525	75	907	6	2	6	2	0	-2	2	0	0	3.0	
i 1	49.24928571428571	0.2525	72	205	7	1	2	2	0	-2	2	0	0	2.0	
i 1	49.25091836734694	0.2525	72	205	4	3	4	2	0	-2	2	0	0	3.0	
i 1	49.251326530612246	0.2525	72	907	6	5	11	2	0	1	2	0	0	2.0	
i 1	49.255	0.2525	72	205	7	5	13	2	0	-2	2	0	0	2.0	
i 1	49.49622448979592	0.505	74	703	5	3	9	17	0	1	17	0	0	3.0	
i 1	49.498061224489796	2.02	75	907	6	5	7	2	0	-2	2	0	0	2.0	
i 1	49.49908163265306	0.2525	72	205	7	1	10	2	0	1	2	0	0	2.0	
i 1	49.50010204081633	0.2525	71	205	7	1	12	2	0	-2	2	0	0	2.0	
i 1	49.50010204081633	1.2625	72	907	6	2	9	2	0	-2	2	0	0	3.0	
i 1	49.50030612244898	2.02	67	907	5	14	7	5	0	1	5	0	0	1.9885463030582553	
i 1	49.501122448979594	0.505	72	703	6	5	16	0	0	-1	0	0	0	2.0	
i 1	49.50234693877551	0.2525	68	907	4	20	6	1	0	-1	1	0	0	6.117401747206259	
i 1	49.50255102040816	0.2525	71	703	4	20	10	1	0	0	1	0	0	6.117401747206259	
i 1	49.503571428571426	0.505	72	703	6	5	10	1	0	0	1	0	0	2.0	
i 1	49.50377551020408	0.505	75	205	4	4	11	2	0	-2	2	0	0	3.0	
i 1	49.505	0.2525	77	703	4	4	8	17	0	1	17	0	0	3.0	
i 1	49.745	0.2525	68	205	4	20	7	1	0	0	1	0	0	6.117401747206259	
i 1	49.74622448979592	0.2525	71	205	3	20	6	1	0	0	1	0	0	6.117401747206259	
i 1	49.748061224489796	0.7575000000000001	77	205	4	9	11	17	0	1	17	0	0	2.0	
i 1	49.75030612244898	0.2525	71	205	3	24	1	1	0	0	1	0	0	10.117401747206259	
i 1	49.75255102040816	0.7575000000000001	71	205	5	24	9	8	0	-1	8	0	0	3.0	
i 1	49.755	0.2525	75	703	6	1	16	2	0	1	2	0	0	2.0	
i 1	49.99520408163265	0.2525	72	205	7	1	16	2	0	-2	2	0	0	2.0	
i 1	49.995612244897956	0.505	75	907	6	2	8	2	0	-2	2	0	0	3.0	
i 1	49.995612244897956	0.2525	72	205	7	5	2	2	0	-2	2	0	0	2.0	
i 1	49.99622448979592	1.5150000000000001	71	205	3	24	1	1	0	0	1	0	0	6.840202599747604	
i 1	49.997244897959185	0.2525	73	205	4	20	4	17	0	2	17	0	0	2.840202599747604	
i 1	49.998673469387754	0.2525	71	205	3	24	8	1	0	0	1	0	0	6.840202599747604	
i 1	50.00030612244898	0.505	71	591	4	24	15	8	0	-2	8	0	0	3.0	
i 1	50.002755102040815	2.525	75	591	6	5	3	2	0	1	2	0	0	2.0	
i 1	50.00295918367347	0.2525	68	205	4	20	13	1	0	0	1	0	0	2.840202599747604	
i 1	50.003367346938774	2.02	75	591	5	3	9	8	0	1	8	0	0	3.0	
i 1	50.00377551020408	1.2625	71	205	3	20	5	1	0	0	1	0	0	2.840202599747604	
i 1	50.004183673469385	0.2525	75	205	7	5	4	8	0	1	8	0	0	2.0	
i 1	50.2454081632653	0.2525	71	591	4	24	2	1	0	-1	1	0	0	6.840202599747604	
i 1	50.245816326530615	0.2525	72	205	7	1	11	2	0	1	2	0	0	2.0	
i 1	50.250510204081635	0.2525	68	907	4	20	11	0	0	0	0	0	0	2.840202599747604	
i 1	50.25214285714286	0.505	72	205	7	5	4	1	0	0	1	0	0	2.0	
i 1	50.25397959183673	0.2525	69	205	7	5	1	0	0	0	0	0	0	2.0	
i 1	50.495816326530615	0.7575000000000001	72	205	3	3	14	2	0	-2	2	0	0	3.0	
i 1	50.49602040816327	0.2525	72	205	7	5	14	2	0	-2	2	0	0	2.0	
i 1	50.498061224489796	0.505	72	205	7	1	6	2	0	-2	2	0	0	2.0	
i 1	50.49826530612245	0.2525	77	205	5	9	12	17	0	1	17	0	0	2.0	
i 1	50.498877551020406	0.505	71	205	4	20	15	1	0	0	1	0	0	2.840202599747604	
i 1	50.498877551020406	0.505	68	205	3	24	5	0	0	-1	0	0	0	6.840202599747604	
i 1	50.49928571428571	2.02	71	591	5	1	6	2	0	-1	2	0	0	2.0	
i 1	50.500510204081635	0.2525	71	591	4	24	6	8	0	-2	8	0	0	3.0	
i 1	50.503367346938774	2.02	60	591	5	15	16	0	0	1	0	0	0	2.7596623639856367e-17	
i 1	50.746428571428574	2.2725	75	591	4	4	15	2	0	-2	2	0	0	3.0	
i 1	50.74683673469388	0.2525	75	205	7	5	6	8	0	1	8	0	0	2.0	
i 1	50.75030612244898	0.505	75	907	6	2	8	2	0	-2	2	0	0	3.0	
i 1	50.75234693877551	0.2525	72	907	6	5	13	2	0	1	2	0	0	2.0	
i 1	50.753367346938774	0.2525	74	907	5	1	14	8	0	-1	8	0	0	2.0	
i 1	50.99704081632653	0.2525	71	205	5	24	14	8	0	-1	8	0	0	3.0	
i 1	50.998061224489796	0.2525	69	205	6	5	16	0	0	0	0	0	0	2.0	
i 1	50.99969387755102	1.5150000000000001	60	591	5	15	11	5	0	1	5	0	0	2.7596623639856367e-17	
i 1	51.00030612244898	0.505	72	205	5	1	15	2	0	-2	2	0	0	2.0	
i 1	51.00091836734694	0.505	71	205	3	20	8	0	0	0	0	0	0	2.840202599747604	
i 1	51.001326530612246	0.505	71	205	3	20	5	1	0	0	1	0	0	2.840202599747604	
i 1	51.00479591836735	0.2525	72	205	7	5	11	2	0	-2	2	0	0	2.0	
i 1	51.245	0.2525	72	205	7	5	9	1	0	0	1	0	0	2.0	
i 1	51.248673469387754	0.2525	74	205	5	9	8	16	0	1	16	0	0	2.0	
i 1	51.24989795918367	0.7575000000000001	75	205	3	4	4	2	0	-2	2	0	0	3.0	
i 1	51.25010204081633	0.2525	68	205	3	24	11	0	0	-1	0	0	0	6.840202599747604	
i 1	51.251326530612246	0.2525	76	205	4	24	4	16	0	2	16	0	0	6.840202599747604	
i 1	51.254387755102044	0.2525	74	907	5	1	2	8	0	-1	8	0	0	2.0	
i 1	51.2545918367347	0.2525	72	907	6	5	16	2	0	1	2	0	0	2.0	
i 1	51.495612244897956	0.2525	72	205	7	5	9	2	0	-2	2	0	0	2.0	
i 1	51.496428571428574	0.2525	75	205	7	5	16	8	0	1	8	0	0	2.0	
i 1	51.499489795918365	0.505	76	205	4	24	4	16	0	2	16	0	0	4.000000000000001	
i 1	51.49989795918367	1.01	61	205	5	16	6	6	0	1	6	0	0	0.9942731515291277	
i 1	51.49989795918367	0.2525	71	591	3	20	9	1	0	-1	1	0	0	8.881784197001252e-16	
i 1	51.50010204081633	1.01	67	907	5	14	4	5	0	1	5	0	0	1.9885463030582553	
i 1	51.5015306122449	0.2525	68	591	4	24	6	1	0	-1	1	0	0	4.000000000000001	
i 1	51.501938775510204	0.505	69	205	6	5	4	0	0	0	0	0	0	2.0	
i 1	51.50234693877551	0.2525	74	205	6	9	6	16	0	1	16	0	0	2.0	
i 1	51.503367346938774	0.505	71	205	3	24	9	1	0	0	1	0	0	4.000000000000001	
i 1	51.50397959183673	0.2525	71	591	4	24	9	8	0	-2	8	0	0	3.0	
i 1	51.50479591836735	0.505	71	205	5	24	11	8	0	-1	8	0	0	3.0	
i 1	51.50479591836735	0.2525	68	907	3	20	8	0	0	-1	0	0	0	8.881784197001252e-16	
i 1	51.505	0.2525	72	205	5	1	7	2	0	1	2	0	0	2.0	
i 1	51.745612244897956	0.7575000000000001	72	907	6	5	10	2	0	1	2	0	0	2.0	
i 1	51.746632653061226	0.2525	68	205	3	24	9	1	0	-1	1	0	0	4.000000000000001	
i 1	51.74704081632653	0.7575000000000001	72	907	6	2	2	2	0	-2	2	0	0	3.0	
i 1	51.747244897959185	0.505	72	205	5	1	2	2	0	-2	2	0	0	2.0	
i 1	51.74744897959184	0.505	75	591	6	5	10	2	0	-2	2	0	0	2.0	
i 1	51.74928571428571	0.2525	71	205	6	1	1	2	0	-2	2	0	0	2.0	
i 1	51.75214285714286	0.2525	68	205	3	20	8	0	0	-1	0	0	0	8.881784197001252e-16	
i 1	51.755	0.2525	71	205	2	20	15	0	0	0	0	0	0	8.881784197001252e-16	
i 1	51.996428571428574	0.505	68	205	2	24	16	1	0	-1	1	0	0	4.0	
i 1	51.996632653061226	0.505	76	205	4	24	9	16	0	2	16	0	0	4.0	
i 1	51.99683673469388	0.2525	71	205	5	24	1	8	0	-1	8	0	0	3.0	
i 1	51.997244897959185	0.2525	75	205	4	4	10	2	0	-2	2	0	0	3.0	
i 1	51.99765306122449	0.505	71	205	3	24	6	1	0	0	1	0	0	4.0	
i 1	51.998673469387754	0.505	74	907	4	1	10	8	0	-1	8	0	0	2.0	
i 1	52.00010204081633	0.505	66	205	5	16	9	9	0	1	9	0	0	0.9942731515291277	
i 1	52.00010204081633	0.2525	75	907	6	5	7	2	0	-2	2	0	0	2.0	
i 1	52.00091836734694	0.505	72	205	6	3	9	2	0	-2	2	0	0	3.0	
i 1	52.245	0.2525	72	205	5	1	11	2	0	1	2	0	0	2.0	
i 1	52.246632653061226	0.2525	75	205	7	5	14	8	0	1	8	0	0	2.0	
i 1	52.25010204081633	0.2525	69	205	6	5	15	0	0	0	0	0	0	2.0	
i 1	52.25173469387755	0.2525	75	907	6	2	13	2	0	-2	2	0	0	3.0	
i 1	52.253571428571426	0.2525	74	907	4	1	5	8	0	-1	8	0	0	2.0	
i 1	52.4954081632653	0.505	75	591	6	5	10	2	0	1	2	0	0	2.364127371234759	
i 1	52.495816326530615	1.01	72	1089	6	5	11	2	0	-2	2	0	0	2.364127371234759	
i 1	52.49744897959184	0.2525	72	1089	5	5	8	2	0	1	2	0	0	2.364127371234759	
i 1	52.49765306122449	0.2525	71	591	3	24	6	0	0	-1	0	0	0	4.0	
i 1	52.49765306122449	0.505	67	591	6	7	13	5	0	0	5	0	0	4.043535098493351	
i 1	52.49785714285714	2.525	67	1089	5	14	7	5	0	0	5	0	0	8.03507505160901	
i 1	52.49989795918367	0.505	71	1089	2	24	11	0	0	-1	0	0	0	4.0	
i 1	52.50091836734694	0.2525	71	275	4	1	16	2	0	-1	2	0	0	2.0	
i 1	52.50091836734694	2.02	60	1089	5	14	3	5	0	1	5	0	0	8.03507505160901	
i 1	52.50214285714286	0.505	71	591	4	1	1	2	0	-1	2	0	0	2.0	
i 1	52.50214285714286	0.7575000000000001	75	591	6	5	3	2	0	-2	2	0	0	2.364127371234759	
i 1	52.50234693877551	0.505	75	1089	6	2	12	2	0	-2	2	0	0	3.0	
i 1	52.50234693877551	0.2525	75	1089	5	9	10	8	0	1	8	0	0	2.0	
i 1	52.504183673469385	1.01	71	1089	4	1	4	8	0	-1	8	0	0	2.0	
i 1	52.50479591836735	0.505	72	275	6	3	2	2	0	1	2	0	0	3.0	
i 1	52.505	0.7575000000000001	74	275	4	24	1	8	0	-2	8	0	0	3.0	
i 1	52.505	1.01	68	275	3	24	5	0	0	-1	0	0	0	4.0	
i 1	52.748877551020406	0.2525	74	1089	4	1	1	2	0	-2	2	0	0	2.0	
i 1	52.75010204081633	0.505	75	1089	5	9	14	2	0	-2	2	0	0	2.0	
i 1	52.75030612244898	0.2525	75	1089	6	5	12	2	0	1	2	0	0	2.364127371234759	
i 1	52.751122448979594	0.2525	71	275	2	24	4	1	0	0	1	0	0	4.0	
i 1	52.99826530612245	0.2525	72	275	5	4	2	2	0	-2	2	0	0	3.0	
i 1	52.998673469387754	1.5150000000000001	71	591	4	24	12	8	0	-2	8	0	0	3.0	
i 1	52.99969387755102	0.7575000000000001	74	1089	4	1	8	2	0	-1	2	0	0	2.0	
i 1	53.001326530612246	1.5150000000000001	75	1089	6	2	14	2	0	-2	2	0	0	3.0	
i 1	53.001938775510204	0.2525	75	591	5	3	14	8	0	1	8	0	0	3.0	
i 1	53.00234693877551	0.505	67	591	6	7	8	5	0	0	5	0	0	4.043535098493351	
i 1	53.002755102040815	1.01	75	1089	6	5	13	2	0	1	2	0	0	2.364127371234759	
i 1	53.003367346938774	0.2525	75	275	5	5	14	2	0	-2	2	0	0	2.364127371234759	
i 1	53.245	0.505	75	1089	5	9	16	8	0	1	8	0	0	2.0	
i 1	53.245	0.2525	71	275	2	24	3	1	0	0	1	0	0	4.0	
i 1	53.248061224489796	0.2525	75	591	6	5	3	2	0	1	2	0	0	2.364127371234759	
i 1	53.248673469387754	0.2525	72	275	5	5	11	2	0	-2	2	0	0	2.364127371234759	
i 1	53.24989795918367	1.2625	71	1089	2	24	7	0	0	-1	0	0	0	4.0	
i 1	53.251938775510204	0.505	72	1089	6	2	16	2	0	-2	2	0	0	3.0	
i 1	53.252755102040815	0.2525	75	591	4	4	5	2	0	-2	2	0	0	3.0	
i 1	53.25479591836735	0.2525	74	1089	6	1	3	8	0	-1	8	0	0	2.0	
i 1	53.4954081632653	0.505	75	275	5	5	9	2	0	-2	2	0	0	2.364127371234759	
i 1	53.495612244897956	0.7575000000000001	72	1089	6	5	14	2	0	-2	2	0	0	2.364127371234759	
i 1	53.495816326530615	2.525	67	591	6	7	8	5	0	0	5	0	0	4.043535098493351	
i 1	53.49826530612245	0.505	71	275	4	1	4	2	0	-1	2	0	0	2.0	
i 1	53.498673469387754	0.2525	68	591	3	24	13	1	0	0	1	0	0	4.0	
i 1	53.49969387755102	0.505	75	591	4	4	7	2	0	-2	2	0	0	3.0	
i 1	53.5015306122449	0.2525	75	591	6	5	3	2	0	-2	2	0	0	2.364127371234759	
i 1	53.50397959183673	1.5150000000000001	71	1089	6	1	15	8	0	-1	8	0	0	2.0	
i 1	53.504183673469385	0.7575000000000001	68	275	2	24	10	0	0	-1	0	0	0	4.0	
i 1	53.7454081632653	0.2525	75	1089	5	9	5	2	0	-2	2	0	0	2.0	
i 1	53.74928571428571	0.505	72	275	5	5	14	2	0	-2	2	0	0	2.364127371234759	
i 1	53.74989795918367	0.2525	72	275	6	3	16	2	0	1	2	0	0	3.0	
i 1	53.75010204081633	0.2525	74	1089	6	1	1	8	0	-1	8	0	0	2.0	
i 1	53.7545918367347	0.2525	68	275	2	24	6	0	0	-1	0	0	0	4.0	
i 1	53.995	0.2525	75	1089	5	9	9	2	0	-2	2	0	0	2.0	
i 1	53.99622448979592	1.01	74	275	4	24	5	8	0	-2	8	0	0	3.0	
i 1	53.99704081632653	0.505	72	1089	6	2	10	2	0	-2	2	0	0	3.0	
i 1	53.99928571428571	0.505	75	591	6	5	15	2	0	1	2	0	0	2.364127371234759	
i 1	54.00071428571429	0.2525	74	1089	3	1	5	2	0	-1	2	0	0	2.0	
i 1	54.0015306122449	1.5150000000000001	75	591	4	4	11	2	0	-2	2	0	0	3.0	
i 1	54.005	1.01	75	1089	6	5	16	2	0	1	2	0	0	2.364127371234759	
i 1	54.24602040816327	1.2625	75	591	5	3	4	8	0	1	8	0	0	3.0	
i 1	54.2515306122449	0.505	72	1089	5	5	3	2	0	1	2	0	0	2.364127371234759	
i 1	54.25377551020408	0.2525	71	275	4	1	7	2	0	-1	2	0	0	2.0	
i 1	54.25479591836735	0.2525	75	591	6	5	7	2	0	-2	2	0	0	2.364127371234759	
i 1	54.49602040816327	1.01	71	591	4	24	11	8	0	-2	8	0	0	3.0	
i 1	54.49622448979592	0.2525	74	1089	3	1	4	2	0	-2	2	0	0	2.0	
i 1	54.50010204081633	0.505	72	1089	6	2	8	2	0	-2	2	0	0	3.0	
i 1	54.50071428571429	0.505	60	1089	5	14	9	5	0	1	5	0	0	8.03507505160901	
i 1	54.501938775510204	0.2525	75	1089	5	9	11	2	0	-2	2	0	0	2.0	
i 1	54.502755102040815	0.2525	75	591	6	5	10	2	0	1	2	0	0	2.364127371234759	
i 1	54.50397959183673	0.505	72	1089	6	5	13	2	0	-2	2	0	0	2.364127371234759	
i 1	54.74602040816327	0.2525	75	275	5	5	5	2	0	-2	2	0	0	2.364127371234759	
i 1	54.74683673469388	0.2525	75	591	6	5	15	2	0	-2	2	0	0	2.364127371234759	
i 1	54.75316326530612	0.2525	71	275	3	1	15	2	0	-1	2	0	0	2.0	
i 1	54.75316326530612	0.2525	72	275	5	4	1	2	0	-2	2	0	0	3.0	
i 1	54.99520408163265	0.2525	75	1089	5	9	15	2	0	-2	2	0	0	2.0	
i 1	54.99744897959184	0.2525	71	591	6	1	14	2	0	-1	2	0	0	2.0	
i 1	54.99744897959184	2.525	67	703	5	14	16	5	0	0	5	0	0	8.03507505160901	
i 1	54.99826530612245	2.2725	71	703	6	1	9	8	0	-1	8	0	0	2.0	
i 1	54.99826530612245	0.7575000000000001	71	387	3	1	15	2	5003	-2	2	0	0	2.0	
i 1	54.999489795918365	2.525	72	703	6	5	11	2	0	-2	2	0	0	2.364127371234759	
i 1	55.00234693877551	2.525	60	703	5	14	12	5	0	1	5	0	0	8.03507505160901	
i 1	55.00255102040816	0.505	72	703	6	5	5	2	0	1	2	0	0	2.364127371234759	
i 1	55.00295918367347	1.01	72	703	6	2	10	2	0	-2	2	0	0	3.0	
i 1	55.004387755102044	0.2525	72	1089	6	5	16	2	0	1	2	0	0	2.364127371234759	
i 1	55.005	0.2525	75	591	6	5	4	2	0	1	2	0	0	2.364127371234759	
i 1	55.24969387755102	0.2525	75	387	5	5	5	2	5003	1	2	0	0	2.364127371234759	
i 1	55.25030612244898	0.7575000000000001	75	591	6	5	15	2	0	-2	2	0	0	2.364127371234759	
i 1	55.2515306122449	0.7575000000000001	74	703	6	1	6	2	0	-1	2	0	0	2.0	
i 1	55.251938775510204	0.2525	72	703	6	2	12	2	0	1	2	0	0	3.0	
i 1	55.4954081632653	0.2525	75	1089	5	9	1	2	0	-2	2	0	0	2.0	
i 1	55.496632653061226	0.2525	72	387	4	4	8	2	5003	1	2	0	0	3.0	
i 1	55.49785714285714	0.2525	72	1089	6	5	3	2	0	1	2	0	0	2.364127371234759	
i 1	55.498673469387754	1.01	75	591	5	3	7	8	0	1	8	0	0	3.0	
i 1	55.504387755102044	0.2525	72	1089	5	5	4	2	0	1	2	0	0	2.364127371234759	
i 1	55.50479591836735	0.2525	71	387	3	24	15	8	5003	-1	8	0	0	3.0	
i 1	55.7454081632653	0.7575000000000001	71	591	6	1	16	2	0	-1	2	0	0	2.0	
i 1	55.7484693877551	0.2525	75	387	6	5	6	2	5003	-2	2	0	0	2.364127371234759	
i 1	55.75071428571429	0.2525	75	387	5	3	13	2	5003	1	2	0	0	3.0	
i 1	55.75214285714286	0.2525	72	703	6	2	2	2	0	1	2	0	0	3.0	
i 1	55.75316326530612	0.7575000000000001	75	591	6	5	14	2	0	1	2	0	0	2.364127371234759	
i 1	55.755	0.505	74	1089	5	1	15	2	0	-2	2	0	0	2.0	
i 1	55.99520408163265	0.2525	72	1089	5	5	11	2	0	1	2	0	0	2.364127371234759	
i 1	55.99622448979592	0.2525	72	1089	5	5	13	2	0	1	2	0	0	2.364127371234759	
i 1	55.996632653061226	1.5150000000000001	60	703	6	17	1	0	0	0	0	0	0	5.5397705158726	
i 1	55.999489795918365	0.505	75	591	4	4	4	2	0	-2	2	0	0	3.0	
i 1	56.000510204081635	0.2525	72	387	4	4	15	2	5003	1	2	0	0	3.0	
i 1	56.003571428571426	0.505	67	591	6	7	1	5	0	0	5	0	0	4.043535098493351	
i 1	56.00377551020408	0.2525	72	703	6	2	6	2	0	-2	2	0	0	3.0	
i 1	56.004183673469385	0.2525	71	387	5	1	16	2	5003	-2	2	0	0	2.0	
i 1	56.24908163265306	0.2525	75	387	5	3	11	2	5003	1	2	0	0	3.0	
i 1	56.24989795918367	0.2525	75	1089	5	9	11	2	0	-2	2	0	0	2.0	
i 1	56.24989795918367	0.2525	75	387	6	5	7	2	5003	-2	2	0	0	2.364127371234759	
i 1	56.25091836734694	0.2525	72	703	6	5	12	2	0	1	2	0	0	2.364127371234759	
i 1	56.251326530612246	0.2525	71	591	4	24	15	8	0	-2	8	0	0	3.0	
i 1	56.251326530612246	0.2525	71	387	3	24	5	8	5003	-1	8	0	0	3.0	
i 1	56.49520408163265	1.01	71	387	6	1	15	2	0	-1	2	0	0	2.0	
i 1	56.496632653061226	0.2525	74	1089	5	1	14	2	0	-1	2	0	0	2.0	
i 1	56.49826530612245	1.01	67	387	6	7	9	0	0	1	0	0	0	4.043535098493351	
i 1	56.4984693877551	0.505	72	387	5	3	13	2	0	1	2	0	0	3.0	
i 1	56.499489795918365	0.2525	75	387	6	5	3	2	5003	1	2	0	0	2.364127371234759	
i 1	56.501938775510204	1.01	72	387	4	4	13	2	0	1	2	0	0	3.0	
i 1	56.503367346938774	0.2525	71	387	5	1	7	2	5003	-2	2	0	0	2.0	
i 1	56.503571428571426	1.01	67	703	6	17	4	0	0	0	0	0	0	5.5397705158726	
i 1	56.503571428571426	0.2525	75	387	5	5	9	2	5003	-2	2	0	0	2.364127371234759	
i 1	56.5045918367347	1.01	75	387	6	5	16	2	0	1	2	0	0	2.364127371234759	
i 1	56.50479591836735	0.2525	72	703	6	2	10	2	0	-2	2	0	0	3.0	
i 1	56.505	0.505	72	387	4	4	15	2	5003	1	2	0	0	3.0	
i 1	56.748061224489796	0.2525	75	387	5	3	8	2	5003	1	2	0	0	3.0	
i 1	56.7484693877551	0.2525	71	387	4	24	11	8	5003	-1	8	0	0	3.0	
i 1	56.750510204081635	0.505	72	1089	5	5	13	2	0	1	2	0	0	2.364127371234759	
i 1	56.751122448979594	0.2525	72	703	6	5	11	2	0	1	2	0	0	2.364127371234759	
i 1	56.751326530612246	0.2525	71	387	1	24	1	0	0	0	0	0	0	4.0	
i 1	56.7545918367347	0.2525	74	1089	5	1	6	2	0	-2	2	0	0	2.0	
i 1	56.995	0.2525	72	387	6	5	10	2	0	-2	2	0	0	2.364127371234759	
i 1	56.995612244897956	0.505	72	703	6	2	10	2	0	-2	2	0	0	3.0	
i 1	56.998673469387754	0.505	74	387	4	24	3	2	0	-1	2	0	0	3.0	
i 1	57.00010204081633	0.2525	75	1089	5	9	1	8	0	1	8	0	0	2.0	
i 1	57.001326530612246	0.2525	72	387	5	3	3	2	0	1	2	0	0	3.0	
i 1	57.003571428571426	0.2525	71	387	5	1	12	2	5003	-2	2	0	0	2.0	
i 1	57.00479591836735	0.505	67	387	6	17	14	5	0	0	5	0	0	5.5397705158726	
i 1	57.24744897959184	0.2525	74	703	6	1	9	2	0	-1	2	0	0	2.0	
i 1	57.24765306122449	0.2525	72	703	6	5	9	2	0	1	2	0	0	2.364127371234759	
i 1	57.248061224489796	0.2525	75	387	5	3	6	2	5003	1	2	0	0	3.0	
i 1	57.25030612244898	0.2525	74	1089	5	1	1	2	0	-2	2	0	0	2.0	
i 1	57.25214285714286	0.2525	72	703	6	2	12	2	0	1	2	0	0	3.0	
i 1	57.25234693877551	0.2525	72	1089	5	5	11	2	0	1	2	0	0	2.364127371234759	
i 1	57.495	0.2525	71	387	5	1	15	2	5003	-2	2	0	0	2.0	
i 1	57.495612244897956	2.525	60	1193	6	17	13	0	0	1	0	0	0	5.5397705158726	
i 1	57.495816326530615	1.5150000000000001	67	695	6	17	1	0	0	1	0	0	0	5.5397705158726	
i 1	57.496428571428574	0.2525	72	379	5	9	15	2	0	1	2	0	0	2.0	
i 1	57.496632653061226	0.7575000000000001	72	695	6	5	3	8	0	1	8	0	0	2.364127371234759	
i 1	57.49683673469388	2.525	60	1193	4	14	16	0	0	1	0	0	0	8.03507505160901	
i 1	57.49826530612245	0.7575000000000001	71	387	4	24	8	8	5003	-1	8	0	0	3.0	
i 1	57.49908163265306	2.525	67	1193	6	17	2	5	0	1	5	0	0	5.5397705158726	
i 1	57.49908163265306	1.01	72	1193	6	5	9	2	0	1	2	0	0	2.364127371234759	
i 1	57.50071428571429	0.505	72	695	4	4	12	2	0	1	2	0	0	3.0	
i 1	57.50091836734694	0.505	75	379	6	5	2	2	0	-2	2	0	0	2.364127371234759	
i 1	57.501122448979594	1.5150000000000001	60	695	6	17	8	5	0	1	5	0	0	5.5397705158726	
i 1	57.50173469387755	1.5150000000000001	75	1193	6	2	6	2	0	-2	2	0	0	3.0	
i 1	57.501938775510204	0.2525	72	695	6	5	1	2	0	1	2	0	0	2.364127371234759	
i 1	57.50255102040816	0.2525	72	379	5	9	15	2	0	1	2	0	0	2.0	
i 1	57.50295918367347	0.505	67	1193	5	14	7	5	0	0	5	0	0	8.03507505160901	
i 1	57.50377551020408	1.5150000000000001	71	695	4	24	10	8	0	-1	8	0	0	3.0	
i 1	57.50397959183673	0.505	71	695	6	1	3	8	0	-1	8	0	0	2.0	
i 1	57.50479591836735	1.5150000000000001	67	695	6	7	2	5	0	1	5	0	0	4.043535098493351	
i 1	57.745816326530615	0.505	72	695	5	3	8	8	0	-2	8	0	0	3.0	
i 1	57.748877551020406	0.505	71	379	6	1	13	2	0	-2	2	0	0	2.0	
i 1	57.751326530612246	0.505	75	387	5	3	6	2	5003	1	2	0	0	3.0	
i 1	57.75214285714286	0.505	75	387	5	5	10	2	5003	1	2	0	0	2.364127371234759	
i 1	57.996428571428574	0.2525	72	695	6	5	12	2	0	1	2	0	0	2.364127371234759	
i 1	57.99785714285714	2.02	67	1193	4	14	6	5	0	0	5	0	0	8.03507505160901	
i 1	57.999489795918365	0.7575000000000001	72	379	5	9	4	2	0	1	2	0	0	2.0	
i 1	58.002755102040815	1.01	74	1193	6	1	10	8	0	-2	8	0	0	2.0	
i 1	58.00316326530612	1.01	67	379	4	18	6	5	0	0	5	0	0	5.5397705158726	
i 1	58.24520408163265	0.7575000000000001	75	1193	6	5	6	2	0	1	2	0	0	2.364127371234759	
i 1	58.245816326530615	0.505	75	379	6	5	6	2	0	-2	2	0	0	2.364127371234759	
i 1	58.24683673469388	0.505	71	695	6	1	8	8	0	-1	8	0	0	2.0	
i 1	58.24683673469388	1.2625	75	1193	6	2	3	8	0	1	8	0	0	3.0	
i 1	58.25071428571429	0.2525	75	387	5	5	1	2	5003	-2	2	0	0	2.364127371234759	
i 1	58.253367346938774	0.2525	71	387	2	24	3	0	0	0	0	0	0	4.0	
i 1	58.253367346938774	0.2525	68	379	1	24	6	0	0	0	0	0	0	4.0	
i 1	58.496632653061226	0.505	60	379	4	18	12	0	0	1	0	0	0	5.5397705158726	
i 1	58.49826530612245	1.01	72	1193	6	5	1	2	0	1	2	0	0	2.364127371234759	
i 1	58.499489795918365	0.2525	68	379	3	24	9	0	0	0	0	0	0	4.0	
i 1	58.50316326530612	0.2525	72	379	5	9	6	2	0	1	2	0	0	2.0	
i 1	58.504387755102044	0.505	74	379	6	1	10	8	0	-1	8	0	0	2.0	
i 1	58.749489795918365	0.2525	71	387	2	24	3	0	0	0	0	0	0	4.0	
i 1	58.74969387755102	0.2525	71	387	4	24	9	8	5003	-1	8	0	0	3.0	
i 1	58.750510204081635	0.2525	72	695	4	4	13	2	0	1	2	0	0	3.0	
i 1	58.754387755102044	0.2525	72	695	6	5	15	2	0	1	2	0	0	2.364127371234759	
i 1	58.754387755102044	0.2525	75	387	5	5	4	2	5003	-2	2	0	0	2.364127371234759	
i 1	58.995816326530615	0.2525	71	224	6	1	8	8	0	-2	8	0	0	2.0	
i 1	58.99602040816327	1.01	60	926	6	17	15	0	0	1	0	0	0	5.5397705158726	
i 1	58.99744897959184	1.01	67	224	5	18	14	5	0	1	5	0	0	5.5397705158726	
i 1	58.998061224489796	0.2525	75	224	6	5	16	2	0	1	2	0	0	2.364127371234759	
i 1	58.99826530612245	1.01	74	926	4	24	5	2	0	-2	2	0	0	3.0	
i 1	58.9984693877551	0.505	72	224	6	9	3	2	0	1	2	0	0	2.0	
i 1	58.998877551020406	1.01	60	224	5	18	12	5	0	0	5	0	0	5.5397705158726	
i 1	58.999489795918365	1.01	60	926	4	7	11	5	0	1	5	0	0	4.043535098493351	
i 1	58.99969387755102	1.01	67	926	6	17	5	0	0	0	0	0	0	5.5397705158726	
i 1	58.99989795918367	1.01	60	610	4	19	14	5	0	0	5	0	0	5.5397705158726	
i 1	59.000510204081635	0.505	74	1193	6	1	7	8	0	-2	8	0	0	2.0	
i 1	59.001122448979594	1.01	72	926	6	5	11	2	0	-2	2	0	0	2.364127371234759	
i 1	59.00255102040816	0.2525	75	1193	6	2	1	2	0	-2	2	0	0	3.0	
i 1	59.00295918367347	0.2525	72	610	5	3	2	2	0	-2	2	0	0	3.0	
i 1	59.004387755102044	0.505	74	610	5	1	10	8	0	-1	8	0	0	2.0	
i 1	59.0045918367347	1.01	75	1193	6	5	3	2	0	1	2	0	0	2.364127371234759	
i 1	59.24622448979592	0.2525	72	926	6	5	3	8	0	1	8	0	0	2.364127371234759	
i 1	59.246428571428574	0.505	75	224	6	9	11	2	0	1	2	0	0	2.0	
i 1	59.248673469387754	0.2525	71	1193	5	1	6	8	0	-1	8	0	0	2.0	
i 1	59.251326530612246	0.7575000000000001	72	926	5	3	11	2	0	1	2	0	0	3.0	
i 1	59.4954081632653	0.2525	74	926	6	1	2	2	0	-2	2	0	0	2.0	
i 1	59.49826530612245	0.505	71	1193	6	1	13	8	0	-1	8	0	0	2.0	
i 1	59.49969387755102	0.2525	75	610	5	5	7	2	0	1	2	0	0	2.364127371234759	
i 1	59.49969387755102	0.505	68	610	2	24	9	0	0	-1	0	0	0	4.0	
i 1	59.501938775510204	0.505	75	1193	6	2	3	8	0	1	8	0	0	3.0	
i 1	59.50214285714286	0.505	67	610	4	19	4	0	0	1	0	0	0	5.5397705158726	
i 1	59.50479591836735	0.2525	75	1193	6	2	9	2	0	-2	2	0	0	3.0	
i 1	59.7454081632653	0.2525	75	926	4	4	13	8	0	1	8	0	0	3.0	
i 1	59.7454081632653	2.525	71	224	3	24	6	1	0	0	1	0	0	4.0	
i 1	59.74704081632653	0.2525	71	224	6	1	12	8	0	-2	8	0	0	2.0	
i 1	59.75214285714286	0.2525	72	610	5	3	11	2	0	-2	2	0	0	3.0	
i 1	59.75295918367347	0.2525	72	926	6	5	6	8	0	1	8	0	0	2.364127371234759	
i 1	59.754183673469385	0.2525	71	610	4	24	16	8	0	-2	8	0	0	3.0	
i 1	59.99520408163265	0.505	67	1108	6	17	1	5	0	1	5	0	0	3.7474246373130313	
i 1	59.995816326530615	2.02	67	224	5	18	15	5	0	1	5	0	0	3.7474246373130313	
i 1	59.99622448979592	1.01	60	926	6	17	6	0	0	1	0	0	0	3.7474246373130313	
i 1	59.996428571428574	1.5150000000000001	60	722	5	12	15	0	0	1	0	0	0	0.9942731515291277	
i 1	59.996632653061226	1.5150000000000001	74	1108	6	1	2	2	0	-2	2	0	0	2.0	
i 1	59.997244897959185	2.525	60	224	5	18	4	5	0	0	5	0	0	3.7474246373130313	
i 1	59.99826530612245	0.505	74	926	4	24	12	2	0	-2	2	0	0	3.0	
i 1	59.99826530612245	2.525	67	722	4	19	12	5	0	0	5	0	0	3.7474246373130313	
i 1	59.9984693877551	1.5150000000000001	72	926	5	3	5	2	0	1	2	0	0	3.0	
i 1	59.9984693877551	0.2525	72	926	6	5	14	2	0	-2	2	0	0	2.1318450173838257	
i 1	59.998673469387754	1.5150000000000001	72	926	6	5	14	8	0	1	8	0	0	2.1318450173838257	
i 1	59.99908163265306	1.5150000000000001	60	926	4	7	6	5	0	1	5	0	0	4.059225941181293	
i 1	59.99928571428571	0.7575000000000001	75	1108	6	2	13	2	0	-2	2	0	0	3.0	
i 1	59.99969387755102	0.505	60	1108	6	17	7	5	0	1	5	0	0	3.7474246373130313	
i 1	59.99989795918367	0.505	75	722	5	5	4	2	0	-2	2	0	0	2.1318450173838257	
i 1	60.00071428571429	1.01	67	1108	3	14	6	5	0	0	5	0	0	8.050765894296951	
i 1	60.00091836734694	0.505	67	224	5	16	4	0	0	0	0	0	0	0.9942731515291277	
i 1	60.00091836734694	1.01	60	224	5	16	13	5	0	1	5	0	0	0.9942731515291277	
i 1	60.00091836734694	0.2525	75	722	5	3	4	8	0	1	8	0	0	3.0	
i 1	60.001326530612246	2.02	60	722	5	12	3	0	0	0	0	0	0	0.9942731515291277	
i 1	60.00234693877551	1.5150000000000001	60	1108	3	14	12	5	0	1	5	0	0	8.050765894296951	
i 1	60.002755102040815	2.525	67	722	4	19	8	5	0	0	5	0	0	3.7474246373130313	
i 1	60.00316326530612	0.2525	74	722	5	1	9	2	0	-1	2	0	0	2.0	
i 1	60.004183673469385	0.2525	74	224	6	1	12	8	0	-2	8	0	0	2.0	
i 1	60.004387755102044	1.5150000000000001	67	926	6	17	1	0	0	0	0	0	0	3.7474246373130313	
i 1	60.004387755102044	0.2525	75	224	7	5	2	2	0	1	2	0	0	2.1318450173838257	
i 1	60.004387755102044	0.2525	68	722	2	24	7	0	0	0	0	0	0	4.0	
i 1	60.24622448979592	0.2525	68	926	3	24	13	1	0	-1	1	0	0	4.0	
i 1	60.24683673469388	0.2525	75	722	5	5	12	2	0	-2	2	0	0	2.1318450173838257	
i 1	60.24744897959184	0.2525	75	1108	6	2	10	2	0	1	2	0	0	3.0	
i 1	60.24785714285714	0.2525	71	1108	6	1	12	2	0	-1	2	0	0	2.0	
i 1	60.25173469387755	1.2625	71	722	2	24	2	0	0	0	0	0	0	4.0	
i 1	60.25214285714286	0.2525	75	1108	6	5	4	2	0	1	2	0	0	2.1318450173838257	
i 1	60.495816326530615	0.505	75	722	4	4	1	2	0	1	2	0	0	3.0	
i 1	60.49622448979592	0.2525	71	224	6	1	4	8	0	-2	8	0	0	2.0	
i 1	60.498877551020406	0.2525	72	224	6	9	2	2	0	1	2	0	0	2.0	
i 1	60.49928571428571	1.01	74	926	6	1	11	2	0	-2	2	0	0	2.0	
i 1	60.49928571428571	0.2525	75	722	6	5	4	2	0	-2	2	0	0	2.1318450173838257	
i 1	60.50091836734694	1.01	72	926	6	5	1	2	0	-2	2	0	0	2.1318450173838257	
i 1	60.501326530612246	1.01	72	1108	6	5	4	2	0	1	2	0	0	2.1318450173838257	
i 1	60.50295918367347	0.505	74	224	7	1	8	8	0	-2	8	0	0	2.0	
i 1	60.503571428571426	0.505	67	1108	6	17	13	5	0	1	5	0	0	3.7474246373130313	
i 1	60.505	0.505	68	722	2	24	5	1	0	-1	1	0	0	4.0	
i 1	60.749489795918365	0.505	75	224	6	9	15	2	0	1	2	0	0	2.0	
i 1	60.75030612244898	0.2525	74	722	5	1	14	2	0	-1	2	0	0	2.0	
i 1	60.753367346938774	0.2525	75	1108	6	5	4	2	0	1	2	0	0	2.1318450173838257	
i 1	60.995	0.2525	75	1108	6	2	16	2	0	-2	2	0	0	3.0	
i 1	60.99683673469388	0.2525	72	224	6	5	4	2	0	-2	2	0	0	2.1318450173838257	
i 1	61.00010204081633	0.2525	71	926	3	24	1	0	0	-1	0	0	0	4.0	
i 1	61.001326530612246	1.5150000000000001	67	1108	5	14	16	5	0	0	5	0	0	8.050765894296951	
i 1	61.00295918367347	0.505	74	926	4	24	14	2	0	-2	2	0	0	3.0	
i 1	61.003571428571426	0.505	75	926	4	4	4	8	0	1	8	0	0	3.0	
i 1	61.005	0.505	60	926	6	17	5	0	0	1	0	0	0	3.7474246373130313	
i 1	61.24704081632653	0.505	71	722	2	24	5	1	0	0	1	0	0	4.0	
i 1	61.24908163265306	0.2525	74	224	4	1	10	8	0	-2	8	0	0	2.0	
i 1	61.25091836734694	0.2525	75	1108	6	2	15	2	0	1	2	0	0	3.0	
i 1	61.25214285714286	0.2525	72	224	6	9	11	2	0	1	2	0	0	2.0	
i 1	61.495	1.01	60	722	4	7	6	5	0	1	5	0	0	4.059225941181293	
i 1	61.49602040816327	0.505	74	722	6	1	6	2	0	-1	2	0	0	2.0	
i 1	61.49683673469388	0.505	72	722	5	3	4	2	0	-2	2	0	0	3.0	
i 1	61.49826530612245	0.2525	75	224	6	9	3	2	0	1	2	0	0	2.0	
i 1	61.498673469387754	0.2525	75	224	6	5	5	2	0	1	2	0	0	2.1318450173838257	
i 1	61.49969387755102	0.505	72	722	6	5	2	2	0	-2	2	0	0	2.1318450173838257	
i 1	61.50071428571429	0.505	67	722	6	17	11	5	0	0	5	0	0	3.7474246373130313	
i 1	61.50071428571429	0.2525	75	1108	6	5	15	2	0	1	2	0	0	2.1318450173838257	
i 1	61.50091836734694	0.2525	71	1108	6	1	13	2	0	-1	2	0	0	2.0	
i 1	61.50091836734694	1.01	60	1108	5	14	9	5	0	1	5	0	0	8.050765894296951	
i 1	61.501938775510204	1.5150000000000001	71	722	4	24	7	8	0	-2	8	0	0	3.0	
i 1	61.501938775510204	0.2525	74	224	7	1	3	8	0	-2	8	0	0	2.0	
i 1	61.501938775510204	1.01	72	1108	6	5	9	2	0	1	2	0	0	2.1318450173838257	
i 1	61.504183673469385	2.525	72	722	4	4	2	2	0	-2	2	0	0	3.0	
i 1	61.74683673469388	0.2525	75	722	4	4	8	2	0	1	2	0	0	3.0	
i 1	61.74683673469388	0.7575000000000001	71	722	2	24	13	0	0	0	0	0	0	4.0	
i 1	61.74969387755102	0.2525	71	722	3	24	15	1	0	0	1	0	0	4.0	
i 1	61.75091836734694	0.2525	72	224	6	5	8	2	0	-2	2	0	0	2.1318450173838257	
i 1	61.75214285714286	0.2525	74	722	4	24	6	8	0	-1	8	0	0	3.0	
i 1	61.75479591836735	0.505	75	1108	6	2	7	2	0	1	2	0	0	3.0	
i 1	61.755	0.2525	74	1108	4	1	8	2	0	-2	2	0	0	2.0	
i 1	61.99602040816327	0.2525	75	224	6	5	6	2	0	1	2	0	0	2.1318450173838257	
i 1	61.99744897959184	0.2525	75	722	5	3	4	8	0	1	8	0	0	3.0	
i 1	61.99928571428571	0.2525	71	224	7	1	5	8	0	-2	8	0	0	2.0	
i 1	61.99928571428571	0.2525	74	722	3	1	4	2	0	-1	2	0	0	2.0	
i 1	61.999489795918365	0.505	75	1108	6	5	1	2	0	1	2	0	0	2.1318450173838257	
i 1	62.00071428571429	0.505	72	224	6	9	8	2	0	1	2	0	0	2.0	
i 1	62.001122448979594	0.505	74	722	4	24	9	8	0	-1	8	0	0	3.0	
i 1	62.001326530612246	0.2525	71	722	2	24	5	1	0	0	1	0	0	4.0	
i 1	62.003367346938774	0.505	67	224	5	18	5	5	0	1	5	0	0	3.7474246373130313	
i 1	62.248061224489796	0.7575000000000001	72	224	6	5	10	2	0	-2	2	0	0	2.1318450173838257	
i 1	62.254387755102044	0.2525	72	722	5	3	3	2	0	-2	2	0	0	3.0	
i 1	62.255	0.505	74	224	7	1	16	8	0	-2	8	0	0	2.0	
i 1	62.495612244897956	0.505	71	224	3	24	12	8	0	-1	8	0	0	3.0	
i 1	62.49622448979592	1.7675	72	926	6	5	15	2	0	1	2	0	0	2.1318450173838257	
i 1	62.496428571428574	0.505	67	224	5	19	4	0	0	0	0	0	0	3.7474246373130313	
i 1	62.49928571428571	0.505	67	926	3	14	3	5	0	0	5	0	0	8.050765894296951	
i 1	62.49969387755102	1.5150000000000001	60	722	5	7	16	5	0	1	5	0	0	4.059225941181293	
i 1	62.49989795918367	0.505	67	926	5	14	11	5	0	0	5	0	0	8.050765894296951	
i 1	62.50010204081633	1.01	71	224	7	1	10	2	0	-1	2	0	0	2.0	
i 1	62.500510204081635	0.2525	72	926	5	2	14	2	0	1	2	0	0	3.0	
i 1	62.50071428571429	1.01	60	224	5	19	13	5	0	1	5	0	0	3.7474246373130313	
i 1	62.501122448979594	0.7575000000000001	72	926	6	5	12	2	0	-2	2	0	0	2.1318450173838257	
i 1	62.50214285714286	0.2525	72	224	6	3	15	2	0	-2	2	0	0	3.0	
i 1	62.50214285714286	0.505	60	224	5	18	9	5	0	0	5	0	0	3.7474246373130313	
i 1	62.50214285714286	1.01	68	224	2	24	13	0	0	-1	0	0	0	4.0	
i 1	62.7454081632653	0.2525	75	224	6	9	12	2	0	1	2	0	0	2.0	
i 1	62.745612244897956	0.2525	72	224	6	9	15	2	0	1	2	0	0	2.0	
i 1	62.995612244897956	0.505	67	926	3	14	16	5	0	0	5	0	0	8.050765894296951	
i 1	62.99683673469388	0.505	75	224	5	5	14	2	0	-2	2	0	0	2.1318450173838257	
i 1	62.9984693877551	0.505	67	224	5	19	12	0	0	0	0	0	0	3.7474246373130313	
i 1	62.99989795918367	1.01	67	926	5	14	7	0	0	1	0	0	0	1.9885463030582553	
i 1	63.00091836734694	0.2525	74	926	4	1	13	2	0	-2	2	0	0	2.0	
i 1	63.0015306122449	1.01	71	722	4	24	16	8	0	-2	8	0	0	3.0	
i 1	63.00173469387755	1.01	67	926	5	14	3	5	0	0	5	0	0	8.050765894296951	
i 1	63.002755102040815	0.2525	71	224	2	24	10	0	0	0	0	0	0	4.0	
i 1	63.00295918367347	0.505	72	926	5	2	4	2	0	-2	2	0	0	3.0	
i 1	63.00377551020408	2.02	74	926	4	1	15	8	0	-2	8	0	0	2.0	
i 1	63.004387755102044	1.5150000000000001	71	224	3	24	6	1	0	0	1	0	0	4.0	
i 1	63.0045918367347	0.2525	72	926	6	2	13	2	0	1	2	0	0	3.0	
i 1	63.24826530612245	0.2525	72	224	6	5	5	2	0	-2	2	0	0	2.1318450173838257	
i 1	63.24989795918367	0.2525	72	722	5	3	4	2	0	-2	2	0	0	3.0	
i 1	63.25030612244898	0.2525	71	722	3	24	13	0	0	0	0	0	0	4.0	
i 1	63.495816326530615	0.2525	71	224	2	24	14	1	0	0	1	0	0	4.0	
i 1	63.49785714285714	1.5150000000000001	72	926	6	2	14	2	0	1	2	0	0	3.0	
i 1	63.498673469387754	0.2525	72	224	6	3	1	2	0	-2	2	0	0	3.0	
i 1	63.50030612244898	0.2525	74	722	4	1	7	2	0	-1	2	0	0	2.0	
i 1	63.5015306122449	0.2525	72	722	6	5	10	8	0	-2	8	0	0	2.1318450173838257	
i 1	63.50214285714286	0.505	72	722	6	5	14	2	0	-2	2	0	0	2.1318450173838257	
i 1	63.504183673469385	0.505	60	224	5	19	10	5	0	1	5	0	0	3.7474246373130313	
i 1	63.504183673469385	1.01	67	926	5	14	2	5	0	0	5	0	0	8.050765894296951	
i 1	63.7484693877551	0.2525	75	224	5	5	10	2	0	-2	2	0	0	2.1318450173838257	
i 1	63.74908163265306	0.2525	74	926	4	1	5	2	0	-2	2	0	0	2.0	
i 1	63.74908163265306	0.2525	72	722	5	3	13	2	0	-2	2	0	0	3.0	
i 1	63.751122448979594	0.505	72	926	6	5	1	2	0	-2	2	0	0	2.1318450173838257	
i 1	63.995	1.01	72	610	5	3	8	2	0	1	2	0	0	3.0	
i 1	63.995612244897956	0.505	75	610	4	4	7	8	0	1	8	0	0	3.0	
i 1	63.99602040816327	1.01	67	926	5	14	5	0	0	1	0	0	0	1.9885463030582553	
i 1	63.99928571428571	1.01	71	610	4	24	5	8	0	-1	8	0	0	3.0	
i 1	63.999489795918365	0.505	71	224	7	1	11	2	0	-1	2	0	0	2.0	
i 1	64.00030612244898	0.2525	71	224	4	1	12	8	0	-2	8	0	0	2.0	
i 1	64.00234693877552	1.01	75	610	6	5	14	2	0	1	2	0	0	2.1318450173838257	
i 1	64.00255102040816	0.2525	72	224	7	5	4	2	0	-2	2	0	0	2.1318450173838257	
i 1	64.00255102040816	1.01	67	926	5	14	10	5	0	0	5	0	0	8.050765894296951	
i 1	64.00295918367347	0.505	67	610	4	7	8	0	0	0	0	0	0	4.059225941181293	
i 1	64.00397959183674	0.2525	72	224	6	3	14	2	0	-2	2	0	0	3.0	
i 1	64.005	1.01	60	610	5	15	2	0	0	1	0	0	0	1.1038649455942547e-16	
i 1	64.24602040816326	0.2525	71	224	2	24	3	1	0	0	1	0	0	4.0	
i 1	64.24724489795918	0.2525	75	224	7	5	4	2	0	1	2	0	0	2.1318450173838257	
i 1	64.25030612244898	0.505	75	610	6	5	6	2	0	1	2	0	0	2.1318450173838257	
i 1	64.25377551020408	0.2525	75	224	5	4	16	2	0	1	2	0	0	3.0	
i 1	64.49520408163265	0.505	67	610	5	7	5	0	0	0	0	0	0	4.059225941181293	
i 1	64.4980612244898	0.2525	71	224	3	24	8	1	0	0	1	0	0	5.514371507194083	
i 1	64.49846938775511	0.2525	71	224	3	20	15	1	0	-1	1	0	0	1.5143715071940829	
i 1	64.49867346938775	0.2525	74	926	4	1	3	2	0	-2	2	0	0	2.0	
i 1	64.49908163265306	0.2525	71	224	2	24	6	1	0	0	1	0	0	5.514371507194083	
i 1	64.49928571428572	0.2525	72	224	7	5	16	2	0	-2	2	0	0	2.1318450173838257	
i 1	64.50112244897959	0.505	60	610	5	15	13	0	0	1	0	0	0	1.1038649455942547e-16	
i 1	64.50234693877552	0.2525	75	224	6	9	9	2	0	1	2	0	0	2.0	
i 1	64.50234693877552	0.505	67	926	5	14	4	5	0	0	5	0	0	8.050765894296951	
i 1	64.50438775510204	0.2525	68	224	3	20	10	1	0	0	1	0	0	1.5143715071940829	
i 1	64.745	0.2525	75	223	6	5	15	2	0	1	2	0	0	2.1318450173838257	
i 1	64.74642857142857	0.2525	71	1192	4	1	3	8	0	-1	8	0	0	2.0	
i 1	64.74683673469387	0.2525	71	223	2	24	4	0	0	-1	0	0	0	5.514371507194083	
i 1	64.74846938775511	0.2525	71	223	2	20	12	0	0	-1	0	0	0	1.5143715071940829	
i 1	64.74969387755102	0.2525	71	1192	3	20	10	1	0	0	1	0	0	1.5143715071940829	
i 1	64.75091836734694	0.2525	72	926	6	5	16	2	0	-2	2	0	0	2.1318450173838257	
i 1	64.7519387755102	0.2525	72	1192	5	9	9	2	0	1	2	0	0	2.0	
i 1	64.75255102040816	0.2525	71	1192	3	20	3	1	0	-1	1	0	0	1.5143715071940829	
i 1	64.75336734693877	0.2525	68	223	2	20	8	0	0	-1	0	0	0	1.5143715071940829	
i 1	64.75336734693877	0.2525	68	1192	3	24	16	1	0	-1	1	0	0	5.514371507194083	
i 1	64.99602040816326	0.2525	68	373	2	20	9	1	0	-1	1	0	0	1.5143715071940829	
i 1	64.99622448979592	2.525	60	689	5	14	16	5	0	1	5	0	0	1.9885463030582553	
i 1	64.99704081632653	0.505	60	689	5	15	3	0	0	0	0	0	0	1.1038649455942547e-16	
i 1	64.99724489795918	0.505	72	689	6	5	14	2	0	1	2	0	0	2.1318450173838257	
i 1	64.99744897959184	0.2525	68	1075	2	24	12	0	0	-1	0	0	0	5.514371507194083	
i 1	64.99744897959184	2.525	67	689	5	14	16	0	0	0	0	0	0	8.050765894296951	
i 1	64.99785714285714	0.2525	72	689	6	2	4	2	0	-2	2	0	0	3.0	
i 1	64.99867346938775	2.525	67	689	5	14	4	0	0	1	0	0	0	8.050765894296951	
i 1	64.99887755102041	0.2525	75	373	5	3	5	2	0	1	2	0	0	3.0	
i 1	64.99928571428572	0.2525	71	689	4	1	8	2	0	-1	2	0	0	2.0	
i 1	64.99989795918367	2.2725	72	689	6	5	16	8	0	-2	8	0	0	2.1318450173838257	
i 1	65.00051020408164	0.2525	75	689	6	5	5	8	0	-2	8	0	0	2.1318450173838257	
i 1	65.00071428571428	2.525	71	689	4	24	6	2	0	-1	2	0	0	3.0	
i 1	65.00071428571428	1.01	67	1075	4	16	8	0	0	0	0	0	0	0.9942731515291277	
i 1	65.00112244897959	1.01	71	373	2	20	14	1	0	0	1	0	0	1.5143715071940829	
i 1	65.0019387755102	0.7575000000000001	74	689	4	1	4	2	0	-2	2	0	0	2.0	
i 1	65.00214285714286	0.505	67	689	5	7	4	0	0	1	0	0	0	4.059225941181293	
i 1	65.00234693877552	1.01	60	689	5	15	1	5	0	0	5	0	0	1.1038649455942547e-16	
i 1	65.00275510204082	0.2525	68	373	2	24	9	0	0	-1	0	0	0	5.514371507194083	
i 1	65.00357142857143	1.5150000000000001	75	689	5	3	13	2	0	1	2	0	0	3.0	
i 1	65.245	0.2525	71	689	3	24	3	0	0	0	0	0	0	5.514371507194083	
i 1	65.24867346938775	0.2525	72	689	4	4	8	2	0	1	2	0	0	3.0	
i 1	65.25030612244898	0.2525	72	1075	6	5	15	8	0	-2	8	0	0	2.1318450173838257	
i 1	65.25071428571428	0.2525	71	373	3	24	9	8	0	-2	8	0	0	3.0	
i 1	65.25071428571428	0.2525	72	373	4	4	2	2	0	-2	2	0	0	3.0	
i 1	65.25295918367347	0.505	71	689	3	20	14	0	0	-1	0	0	0	1.5143715071940829	
i 1	65.49602040816326	0.2525	72	373	6	5	4	2	0	1	2	0	0	2.1318450173838257	
i 1	65.49642857142857	1.01	60	689	5	15	10	0	0	0	0	0	0	1.1038649455942547e-16	
i 1	65.49683673469387	0.2525	74	1075	3	1	5	8	0	-2	8	0	0	2.0	
i 1	65.49724489795918	1.01	68	1075	2	24	6	0	0	-1	0	0	0	5.514371507194083	
i 1	65.49785714285714	0.2525	75	1075	5	9	7	2	0	1	2	0	0	2.0	
i 1	65.4980612244898	1.01	60	1075	4	16	4	5	0	1	5	0	0	0.9942731515291277	
i 1	65.49826530612245	0.2525	72	689	6	5	8	2	0	1	2	0	0	2.1318450173838257	
i 1	65.49948979591836	2.02	67	689	6	7	5	0	0	1	0	0	0	4.059225941181293	
i 1	65.50132653061225	0.505	72	689	4	2	4	2	0	-2	2	0	0	3.0	
i 1	65.50234693877552	0.2525	71	689	3	20	6	1	0	-1	1	0	0	1.5143715071940829	
i 1	65.50255102040816	0.2525	72	1075	6	5	13	2	0	1	2	0	0	2.1318450173838257	
i 1	65.745	0.505	68	1075	2	20	1	0	0	-1	0	0	0	1.5143715071940829	
i 1	65.75153061224489	0.2525	72	1075	6	5	3	8	0	-2	8	0	0	2.1318450173838257	
i 1	65.7519387755102	0.2525	75	373	4	3	12	2	0	1	2	0	0	3.0	
i 1	65.75275510204082	0.2525	71	1075	3	1	13	8	0	-2	8	0	0	2.0	
i 1	65.75295918367347	0.2525	74	373	3	1	3	2	0	-2	2	0	0	2.0	
i 1	65.75316326530613	0.2525	75	689	6	5	5	8	0	1	8	0	0	2.1318450173838257	
i 1	65.75459183673469	0.505	68	373	2	20	8	0	0	-1	0	0	0	1.5143715071940829	
i 1	65.99561224489796	1.5150000000000001	60	689	5	15	8	5	0	0	5	0	0	1.1038649455942547e-16	
i 1	65.99724489795918	0.2525	72	373	4	4	16	2	0	-2	2	0	0	3.0	
i 1	65.99908163265306	0.2525	71	689	4	1	15	2	0	-2	2	0	0	2.0	
i 1	66.00030612244898	1.01	60	373	4	12	8	5	0	0	5	0	0	0.9942731515291277	
i 1	66.00091836734694	0.2525	71	373	2	24	12	1	0	0	1	0	0	5.514371507194083	
i 1	66.00112244897959	0.505	67	1075	4	16	5	0	0	0	0	0	0	0.9942731515291277	
i 1	66.00132653061225	0.2525	72	1075	6	5	5	2	0	1	2	0	0	2.1318450173838257	
i 1	66.00234693877552	0.505	75	689	6	5	10	8	0	-2	8	0	0	2.1318450173838257	
i 1	66.00275510204082	0.2525	74	1075	3	1	9	8	0	-2	8	0	0	2.0	
i 1	66.00479591836735	1.01	72	689	4	4	8	2	0	1	2	0	0	3.0	
i 1	66.24948979591836	1.01	71	689	4	1	11	2	0	-1	2	0	0	2.0	
i 1	66.24989795918367	0.2525	68	689	3	24	14	0	0	0	0	0	0	5.514371507194083	
i 1	66.25010204081633	1.5150000000000001	71	373	2	24	7	0	0	0	0	0	0	5.514371507194083	
i 1	66.2519387755102	0.2525	71	373	3	24	7	8	0	-2	8	0	0	3.0	
i 1	66.2519387755102	0.2525	75	1075	5	9	12	2	0	1	2	0	0	2.0	
i 1	66.2519387755102	0.2525	71	689	3	20	4	1	0	0	1	0	0	1.5143715071940829	
i 1	66.25214285714286	0.2525	68	689	3	20	6	1	0	-1	1	0	0	1.5143715071940829	
i 1	66.25438775510204	1.2625	72	689	6	5	11	2	0	1	2	0	0	2.1318450173838257	
i 1	66.49540816326531	0.2525	68	871	2	24	15	0	0	0	0	0	0	5.514371507194083	
i 1	66.49602040816326	0.505	75	689	6	2	2	8	0	1	8	0	0	3.0	
i 1	66.49642857142857	1.01	60	871	4	16	7	0	0	1	0	0	0	0.9942731515291277	
i 1	66.49887755102041	1.01	68	373	2	20	8	1	0	0	1	0	0	1.5143715071940829	
i 1	66.49928571428572	0.505	60	871	4	16	14	0	0	0	0	0	0	0.9942731515291277	
i 1	66.49928571428572	0.2525	68	373	2	24	10	1	0	-1	1	0	0	5.514371507194083	
i 1	66.50071428571428	0.2525	74	373	3	1	4	2	0	-2	2	0	0	2.0	
i 1	66.50132653061225	1.01	67	373	4	12	9	0	0	1	0	0	0	0.9942731515291277	
i 1	66.5019387755102	0.2525	71	871	2	20	16	1	0	-1	1	0	0	1.5143715071940829	
i 1	66.50377551020408	1.01	60	689	5	15	13	0	0	0	0	0	0	1.1038649455942547e-16	
i 1	66.50377551020408	0.2525	75	689	6	5	13	8	0	1	8	0	0	2.1318450173838257	
i 1	66.50459183673469	0.2525	75	689	4	3	2	2	0	1	2	0	0	3.0	
i 1	66.74520408163265	0.2525	71	689	4	1	8	2	0	-2	2	0	0	2.0	
i 1	66.74520408163265	0.2525	72	871	6	5	7	2	0	1	2	0	0	2.1318450173838257	
i 1	66.74622448979592	0.505	75	871	5	9	11	2	0	1	2	0	0	2.0	
i 1	66.7480612244898	0.2525	71	871	2	20	1	1	0	0	1	0	0	1.5143715071940829	
i 1	66.99561224489796	0.505	75	373	5	3	9	2	0	1	2	0	0	3.0	
i 1	66.99622448979592	0.505	72	689	4	4	6	2	0	1	2	0	0	3.0	
i 1	66.99663265306123	0.505	60	871	4	16	1	0	0	0	0	0	0	0.9942731515291277	
i 1	66.9980612244898	0.505	60	373	5	12	16	5	0	0	5	0	0	0.9942731515291277	
i 1	67.0019387755102	0.505	72	373	6	5	12	2	0	1	2	0	0	2.1318450173838257	
i 1	67.00377551020408	0.2525	71	871	2	20	2	1	0	-1	1	0	0	1.5143715071940829	
i 1	67.24744897959184	0.2525	74	689	4	1	8	2	0	-2	2	0	0	2.0	
i 1	67.24928571428572	1.7675	71	373	2	20	7	1	0	0	1	0	0	1.5143715071940829	
i 1	67.25153061224489	0.2525	74	373	3	1	6	2	0	-2	2	0	0	2.0	
i 1	67.25316326530613	0.2525	75	689	6	5	2	8	0	-2	8	0	0	2.1318450173838257	
i 1	67.49602040816326	1.5150000000000001	67	1075	4	16	5	5	0	0	5	0	0	7.954185212233021	
i 1	67.49724489795918	0.2525	72	373	6	5	11	2	0	1	2	0	0	2.0	
i 1	67.49765306122448	1.01	60	689	5	14	11	5	0	1	5	0	0	8.948458363762148	
i 1	67.49765306122448	0.2525	71	689	3	24	5	0	0	-1	0	0	0	5.514371507194083	
i 1	67.49826530612245	0.2525	71	689	3	20	4	1	0	0	1	0	0	1.5143715071940829	
i 1	67.49989795918367	0.2525	71	689	4	1	6	2	0	-1	2	0	0	9.0	
i 1	67.49989795918367	1.5150000000000001	74	689	4	1	6	2	0	-2	2	0	0	9.0	
i 1	67.50010204081633	0.505	60	373	5	12	1	5	0	0	5	0	0	7.954185212233021	
i 1	67.50030612244898	1.5150000000000001	67	1075	4	16	12	5	0	0	5	0	0	7.954185212233021	
i 1	67.50071428571428	1.7675	72	689	6	5	13	2	0	1	2	0	0	2.0	
i 1	67.50091836734694	0.2525	72	1075	5	9	10	2	0	-2	2	0	0	2.067810841647686	
i 1	67.50112244897959	1.5150000000000001	60	689	5	13	12	5	0	0	5	0	0	5.965638909174766	
i 1	67.5019387755102	0.2525	72	689	6	2	12	2	0	-2	2	0	0	3.067810841647686	
i 1	67.50214285714286	1.01	67	373	5	12	10	0	0	1	0	0	0	7.954185212233021	
i 1	67.50275510204082	1.5150000000000001	60	689	5	15	1	0	0	0	0	0	0	6.959912060703894	
i 1	67.50295918367347	1.01	72	689	4	4	5	2	0	1	2	0	0	3.067810841647686	
i 1	67.50316326530613	0.2525	74	1075	3	1	3	8	0	-2	8	0	0	9.0	
i 1	67.50479591836735	1.5150000000000001	60	689	5	15	5	5	0	0	5	0	0	6.959912060703894	
i 1	67.74540816326531	0.2525	75	689	6	5	11	8	0	-2	8	0	0	2.0	
i 1	67.74540816326531	1.01	71	1075	2	20	14	0	0	0	0	0	0	1.5143715071940829	
i 1	67.74602040816326	0.505	71	689	4	24	13	2	0	-1	2	0	0	10.0	
i 1	67.74744897959184	0.2525	71	689	4	1	12	2	0	-2	2	0	0	9.0	
i 1	67.74785714285714	0.2525	72	1075	6	5	1	2	0	-2	2	0	0	2.0	
i 1	67.75091836734694	0.505	75	689	5	3	8	2	0	1	2	0	0	3.067810841647686	
i 1	67.75132653061225	0.2525	75	689	6	2	2	8	0	1	8	0	0	3.067810841647686	
i 1	67.75214285714286	0.7575000000000001	68	373	2	24	9	1	0	0	1	0	0	5.514371507194083	
i 1	67.99561224489796	1.01	60	373	5	12	11	5	0	0	5	0	0	7.954185212233021	
i 1	67.99846938775511	1.2625	72	689	6	2	14	2	0	-2	2	0	0	3.067810841647686	
i 1	67.99989795918367	1.01	71	1075	2	20	14	0	0	-1	0	0	0	1.5143715071940829	
i 1	68.005	0.2525	75	1075	6	5	6	2	0	1	2	0	0	2.0	
i 1	68.24581632653062	0.505	74	373	3	1	4	2	0	-2	2	0	0	9.0	
i 1	68.24622448979592	1.5150000000000001	75	689	6	2	12	8	0	1	8	0	0	3.067810841647686	
i 1	68.24724489795918	0.505	72	1075	6	5	8	2	0	-2	2	0	0	2.0	
i 1	68.24867346938775	0.2525	72	373	6	5	3	2	0	1	2	0	0	2.0	
i 1	68.25091836734694	0.2525	71	689	4	1	6	2	0	-2	2	0	0	9.0	
i 1	68.49520408163265	0.505	67	373	5	12	10	0	0	1	0	0	0	7.954185212233021	
i 1	68.49602040816326	0.505	71	689	4	24	9	2	0	-1	2	0	0	10.0	
i 1	68.49765306122448	0.2525	71	373	2	20	12	0	0	-1	0	0	0	1.5143715071940829	
i 1	68.49928571428572	0.2525	75	373	3	3	6	2	0	1	2	0	0	3.067810841647686	
i 1	68.50030612244898	1.2625	60	689	5	25	14	5	0	1	5	0	0	0.7010281627802958	
i 1	68.50377551020408	0.505	75	689	6	5	16	8	0	-2	8	0	0	2.0	
i 1	68.50479591836735	1.2625	60	689	5	14	12	5	0	1	5	0	0	8.948458363762148	
i 1	68.74561224489796	0.2525	75	1075	5	9	11	2	0	1	2	0	0	2.067810841647686	
i 1	68.74785714285714	0.2525	75	689	6	5	3	8	0	1	8	0	0	2.0	
i 1	68.74928571428572	0.2525	71	689	4	1	3	2	0	-2	2	0	0	9.0	
i 1	68.75112244897959	0.2525	71	689	3	20	6	1	0	0	1	0	0	1.5143715071940829	
i 1	68.75255102040816	0.2525	68	689	3	24	9	0	0	-1	0	0	0	5.514371507194083	
i 1	68.75459183673469	0.2525	68	689	3	20	4	1	0	0	1	0	0	1.5143715071940829	
i 1	68.99540816326531	1.01	67	423	5	12	8	5	0	0	5	0	0	7.954185212233021	
i 1	68.99704081632653	0.2525	68	423	2	24	9	1	0	-1	1	0	0	5.514371507194083	
i 1	68.99744897959184	1.01	60	107	5	16	1	0	0	0	0	0	0	7.954185212233021	
i 1	68.99744897959184	1.01	67	423	5	12	9	5	0	0	5	0	0	7.954185212233021	
i 1	68.99744897959184	0.2525	68	107	3	20	6	1	0	-1	1	0	0	1.5143715071940829	
i 1	68.99846938775511	0.7575000000000001	60	561	5	15	5	5	0	0	5	0	0	6.959912060703894	
i 1	69.00091836734694	0.7575000000000001	60	689	5	13	9	5	0	0	5	0	0	5.965638909174766	
i 1	69.00091836734694	0.2525	68	423	2	20	8	0	0	0	0	0	0	1.5143715071940829	
i 1	69.00153061224489	0.505	71	423	2	20	9	0	0	0	0	0	0	1.5143715071940829	
i 1	69.0019387755102	0.7575000000000001	67	689	5	25	10	5	0	1	5	0	0	0.7010281627802958	
i 1	69.0019387755102	0.2525	75	561	6	5	3	2	0	-2	2	0	0	2.0	
i 1	69.00275510204082	0.7575000000000001	72	561	6	5	3	8	0	-2	8	0	0	2.0	
i 1	69.00459183673469	1.01	68	107	3	20	11	0	0	0	0	0	0	1.5143715071940829	
i 1	69.00479591836735	0.505	67	561	5	15	12	5	0	0	5	0	0	6.959912060703894	
i 1	69.005	1.01	60	107	5	16	6	0	0	1	0	0	0	7.954185212233021	
i 1	69.24602040816326	0.2525	75	423	6	5	1	2	0	1	2	0	0	2.0	
i 1	69.24969387755102	0.2525	70	689	3	20	9	2	0	-2	2	0	0	1.5143715071940829	
i 1	69.25255102040816	0.2525	72	689	6	5	1	8	0	-2	8	0	0	2.0	
i 1	69.25336734693877	0.2525	75	107	6	9	3	2	0	1	2	0	0	2.067810841647686	
i 1	69.25418367346938	0.2525	70	561	3	24	6	2	0	-2	2	0	0	5.514371507194083	
i 1	69.255	0.2525	70	689	3	20	3	2	0	-2	2	0	0	1.5143715071940829	
i 1	69.49520408163265	0.505	68	107	3	24	9	1	0	-1	1	0	0	5.514371507194083	
i 1	69.49540816326531	0.2525	72	107	7	5	14	2	0	-2	2	0	0	2.0	
i 1	69.49622448979592	0.2525	60	561	5	25	13	0	0	0	0	0	0	0.7010281627802958	
i 1	69.49724489795918	0.2525	67	561	5	15	15	5	0	0	5	0	0	6.959912060703894	
i 1	69.49846938775511	0.2525	75	561	5	3	12	2	0	1	2	0	0	3.067810841647686	
i 1	69.49928571428572	0.2525	73	423	2	24	5	8	0	-2	8	0	0	5.514371507194083	
i 1	69.50071428571428	0.2525	75	423	6	5	8	2	0	-2	2	0	0	2.0	
i 1	69.50132653061225	0.2525	72	689	6	2	4	2	0	-2	2	0	0	3.067810841647686	
i 1	69.50357142857143	0.2525	73	107	3	20	14	2	0	-2	2	0	0	1.5143715071940829	
i 1	69.505	0.2525	70	107	3	20	11	8	0	-2	8	0	0	1.5143715071940829	
i 1	69.74581632653062	0.2525	61	690	5	25	15	6	0	1	6	0	0	0.7010281627802958	
i 1	69.74602040816326	0.2525	74	690	6	5	4	2	0	-1	2	0	0	2.0	
i 1	69.74724489795918	0.2525	66	423	5	15	13	6	0	1	6	0	0	6.959912060703894	
i 1	69.74744897959184	0.2525	66	423	5	15	5	9	0	1	9	0	0	6.959912060703894	
i 1	69.74765306122448	0.2525	73	423	3	24	12	8	0	-2	8	0	0	5.514371507194083	
i 1	69.74826530612245	0.2525	61	690	5	25	4	9	0	0	9	0	0	0.7010281627802958	
i 1	69.74846938775511	0.2525	74	423	6	5	16	8	0	-1	8	0	0	2.0	
i 1	69.74846938775511	0.2525	71	423	2	20	12	0	0	0	0	0	0	1.5143715071940829	
i 1	69.74928571428572	0.2525	74	423	4	4	10	8	0	-2	8	0	0	3.067810841647686	
i 1	69.75112244897959	0.2525	61	423	5	25	7	9	0	1	9	0	0	0.7010281627802958	
i 1	69.75214285714286	0.2525	70	690	3	20	6	2	0	-2	2	0	0	1.5143715071940829	
i 1	69.75234693877552	0.2525	61	690	5	13	12	6	0	1	6	0	0	5.965638909174766	
i 1	69.75275510204082	0.2525	74	423	5	3	4	2	0	-2	2	0	0	3.067810841647686	
i 1	69.75316326530613	0.2525	71	690	6	2	4	2	0	-1	2	0	0	3.067810841647686	
i 1	69.75357142857143	0.2525	61	690	5	14	9	9	0	0	9	0	0	8.948458363762148	
i 1	69.99602040816326	0.505	73	199	2	24	7	8	0	-2	8	0	0	5.514371507194083	
i 1	69.99622448979592	0.505	73	199	2	20	10	8	0	-1	8	0	0	1.5143715071940829	
i 1	69.99765306122448	2.02	66	901	5	13	2	9	0	0	9	0	0	5.965638909174766	
i 1	69.99765306122448	0.505	71	585	6	5	8	2	0	-2	2	0	0	2.0	
i 1	69.9980612244898	3.535	61	901	5	25	3	6	0	0	6	0	0	0.7010281627802958	
i 1	69.99846938775511	0.505	61	901	5	25	15	6	0	0	6	0	0	0.7010281627802958	
i 1	69.99908163265306	0.505	71	901	6	5	8	2	0	-2	2	0	0	2.0	
i 1	69.99969387755102	2.02	61	199	5	12	13	9	0	0	9	0	0	7.954185212233021	
i 1	70.00010204081633	0.2525	74	901	6	2	11	8	0	-2	8	0	0	3.067810841647686	
i 1	70.00010204081633	1.01	61	585	5	25	10	9	0	0	9	0	0	0.7010281627802958	
i 1	70.00051020408164	1.5150000000000001	66	199	5	12	2	6	0	0	6	0	0	7.954185212233021	
i 1	70.00051020408164	1.01	71	585	4	4	11	2	0	-1	2	0	0	3.067810841647686	
i 1	70.00051020408164	0.7575000000000001	74	199	7	5	15	8	0	-1	8	0	0	2.0	
i 1	70.00071428571428	3.0300000000000002	66	585	5	15	8	9	0	0	9	0	0	6.959912060703894	
i 1	70.00071428571428	0.2525	70	199	2	24	1	8	0	-2	8	0	0	5.514371507194083	
i 1	70.00112244897959	1.01	61	901	6	17	8	6	0	0	6	0	0	1.8284948891774926	
i 1	70.00214285714286	0.2525	71	585	5	3	10	2	0	-1	2	0	0	3.067810841647686	
i 1	70.00234693877552	2.525	61	585	5	15	4	9	0	1	9	0	0	6.959912060703894	
i 1	70.00336734693877	1.5150000000000001	61	901	5	14	5	6	0	1	6	0	0	8.948458363762148	
i 1	70.00397959183674	0.505	66	199	5	16	5	6	0	1	6	0	0	7.954185212233021	
i 1	70.00459183673469	1.5150000000000001	66	585	5	25	16	9	0	0	9	0	0	0.7010281627802958	
i 1	70.005	1.01	61	199	5	16	12	6	0	0	6	0	0	7.954185212233021	
i 1	70.24887755102041	0.2525	73	199	3	24	14	8	0	-1	8	0	0	5.514371507194083	
i 1	70.25275510204082	0.2525	74	199	6	9	3	2	0	-2	2	0	0	2.067810841647686	
i 1	70.49520408163265	0.2525	74	199	7	5	11	8	0	-2	8	0	0	2.0	
i 1	70.49704081632653	0.2525	73	585	3	24	13	8	0	-2	8	0	0	8.100225206384465	
i 1	70.49724489795918	0.7575000000000001	74	901	6	2	12	8	0	-2	8	0	0	3.067810841647686	
i 1	70.49744897959184	3.535	61	901	5	25	12	6	0	0	6	0	0	0.7010281627802958	
i 1	70.49744897959184	2.02	71	901	4	5	4	2	0	-2	2	0	0	2.0	
i 1	70.49785714285714	0.2525	71	199	5	4	10	8	0	-1	8	0	0	3.067810841647686	
i 1	70.4980612244898	0.2525	73	199	2	20	8	8	0	-1	8	0	0	4.100225206384465	
i 1	70.49928571428572	3.0300000000000002	66	199	5	16	15	6	0	1	6	0	0	7.954185212233021	
i 1	70.50091836734694	0.2525	73	199	3	24	3	8	0	-1	8	0	0	8.100225206384465	
i 1	70.50091836734694	1.2625	73	199	3	20	12	2	0	-1	2	0	0	4.100225206384465	
i 1	70.50173469387755	1.01	61	901	6	17	16	9	0	0	9	0	0	1.8284948891774926	
i 1	70.5019387755102	0.2525	70	901	3	20	3	8	0	-1	8	0	0	4.100225206384465	
i 1	70.50234693877552	1.5150000000000001	61	199	5	26	4	9	0	1	9	0	0	0.7010281627802958	
i 1	70.75051020408164	0.7575000000000001	73	199	3	20	10	2	0	-1	2	0	0	4.100225206384465	
i 1	70.75295918367347	0.2525	74	901	6	5	10	8	0	-2	8	0	0	2.0	
i 1	70.99602040816326	3.535	61	585	5	25	7	9	0	0	9	0	0	0.7010281627802958	
i 1	70.99642857142857	1.5150000000000001	61	199	5	26	1	9	0	1	9	0	0	0.7010281627802958	
i 1	70.99826530612245	1.01	66	585	6	17	16	6	0	1	6	0	0	1.8284948891774926	
i 1	71.00091836734694	0.505	71	199	7	5	10	8	0	-2	8	0	0	2.0	
i 1	71.00153061224489	3.0300000000000002	61	199	5	16	1	6	0	0	6	0	0	7.954185212233021	
i 1	71.00275510204082	3.0300000000000002	61	901	5	17	1	6	0	0	6	0	0	1.8284948891774926	
i 1	71.00438775510204	1.7675	71	585	4	4	9	2	0	-1	2	0	0	3.067810841647686	
i 1	71.00479591836735	0.2525	71	585	6	5	13	2	0	-2	2	0	0	2.0	
i 1	71.24969387755102	0.505	71	199	6	3	4	2	0	-2	2	0	0	3.067810841647686	
i 1	71.25030612244898	0.2525	71	199	6	9	14	8	0	-2	8	0	0	2.067810841647686	
i 1	71.25051020408164	0.2525	71	585	6	5	1	2	0	-2	2	0	0	2.0	
i 1	71.49622448979592	0.2525	74	901	6	2	5	8	0	-2	8	0	0	3.067810841647686	
i 1	71.49663265306123	3.0300000000000002	61	901	5	14	2	6	0	1	6	0	0	8.948458363762148	
i 1	71.49683673469387	3.535	66	585	5	25	13	9	0	0	9	0	0	0.7010281627802958	
i 1	71.49785714285714	1.7675	71	585	4	5	8	2	0	-2	2	0	0	2.0	
i 1	71.50051020408164	1.01	61	585	6	17	14	6	0	0	6	0	0	1.8284948891774926	
i 1	71.50234693877552	1.5150000000000001	66	199	4	27	6	9	0	0	9	0	0	1.68948554291155	
i 1	71.50234693877552	0.2525	73	199	1	20	13	2	0	-1	2	0	0	4.100225206384465	
i 1	71.50479591836735	3.0300000000000002	66	199	4	12	9	6	0	0	6	0	0	7.954185212233021	
i 1	71.505	3.0300000000000002	61	901	5	17	16	9	0	0	9	0	0	1.8284948891774926	
i 1	71.74602040816326	0.7575000000000001	71	199	6	9	14	8	0	-2	8	0	0	2.067810841647686	
i 1	71.75234693877552	2.7775	73	199	2	20	13	8	0	-1	8	0	0	4.100225206384465	
i 1	71.75316326530613	0.2525	71	199	5	4	16	8	0	-1	8	0	0	3.067810841647686	
i 1	71.75438775510204	0.7575000000000001	73	199	2	24	12	8	0	-1	8	0	0	8.100225206384465	
i 1	71.99581632653062	3.0300000000000002	61	199	5	26	1	9	0	1	9	0	0	0.7010281627802958	
i 1	71.99602040816326	1.01	61	199	5	18	7	6	0	1	6	0	0	1.8284948891774926	
i 1	71.99704081632653	0.2525	73	199	3	24	9	8	0	-1	8	0	0	8.100225206384465	
i 1	71.99969387755102	3.0300000000000002	61	199	4	12	5	9	0	0	9	0	0	7.954185212233021	
i 1	72.00010204081633	3.0300000000000002	66	585	5	17	11	6	0	1	6	0	0	1.8284948891774926	
i 1	72.00112244897959	0.2525	71	199	6	3	9	2	0	-2	2	0	0	3.067810841647686	
i 1	72.00234693877552	3.0300000000000002	66	901	5	13	13	9	0	0	9	0	0	5.965638909174766	
i 1	72.00336734693877	1.5150000000000001	61	199	4	27	14	6	0	0	6	0	0	1.68948554291155	
i 1	72.25153061224489	0.2525	71	199	5	4	9	8	0	-1	8	0	0	3.067810841647686	
i 1	72.49581632653062	2.525	61	585	5	15	10	9	0	1	9	0	0	6.959912060703894	
i 1	72.49622448979592	2.525	61	585	5	17	13	6	0	0	6	0	0	1.8284948891774926	
i 1	72.49765306122448	2.525	74	901	4	5	3	8	0	-2	8	0	0	2.0	
i 1	72.50153061224489	2.525	61	199	5	26	9	9	0	1	9	0	0	0.7010281627802958	
i 1	72.50214285714286	0.2525	71	585	5	3	8	2	0	-1	2	0	0	3.067810841647686	
i 1	72.50377551020408	1.01	61	199	5	18	10	9	0	1	9	0	0	1.8284948891774926	
i 1	72.74561224489796	0.2525	74	199	7	5	5	8	0	-1	8	0	0	2.0	
i 1	72.74765306122448	0.2525	74	199	6	9	6	2	0	-2	2	0	0	2.067810841647686	
i 1	72.74928571428572	0.2525	74	901	6	2	10	8	0	-2	8	0	0	3.067810841647686	
i 1	72.74948979591836	0.7575000000000001	74	901	6	2	2	8	0	-2	8	0	0	3.067810841647686	
i 1	72.99622448979592	0.2525	71	901	4	5	8	2	0	-2	2	0	0	2.0	
i 1	72.99704081632653	2.02	61	199	5	18	8	6	0	1	6	0	0	1.8284948891774926	
i 1	72.99765306122448	1.01	61	199	5	19	2	6	0	0	6	0	0	1.8284948891774926	
i 1	72.99785714285714	0.2525	71	199	5	3	7	2	0	-2	2	0	0	3.067810841647686	
i 1	72.99989795918367	2.02	66	199	4	27	8	9	0	0	9	0	0	1.68948554291155	
i 1	73.00071428571428	0.2525	73	199	1	24	1	8	0	-1	8	0	0	8.100225206384465	
i 1	73.00316326530613	0.2525	71	199	6	9	13	8	0	-2	8	0	0	2.067810841647686	
i 1	73.00397959183674	2.02	66	585	5	15	2	9	0	0	9	0	0	6.959912060703894	
i 1	73.24622448979592	0.2525	71	585	4	5	15	2	0	-2	2	0	0	2.0	
i 1	73.25030612244898	0.2525	71	199	4	5	9	8	0	-2	8	0	0	2.0	
i 1	73.25479591836735	0.2525	71	585	4	4	3	2	0	-1	2	0	0	3.067810841647686	
i 1	73.495	1.01	71	585	4	4	2	2	0	-1	2	0	0	3.067810841647686	
i 1	73.49540816326531	1.5150000000000001	61	199	5	18	3	9	0	1	9	0	0	1.8284948891774926	
i 1	73.49561224489796	1.5150000000000001	66	199	5	16	8	6	0	1	6	0	0	7.954185212233021	
i 1	73.49744897959184	1.5150000000000001	61	199	4	27	10	6	0	0	6	0	0	1.68948554291155	
i 1	73.49785714285714	1.01	61	901	5	25	15	6	0	0	6	0	0	0.7010281627802958	
i 1	73.50010204081633	0.2525	74	199	7	5	16	8	0	-1	8	0	0	2.0	
i 1	73.50275510204082	0.2525	71	199	5	3	8	2	0	-2	2	0	0	3.067810841647686	
i 1	73.50377551020408	1.01	61	199	5	19	4	9	0	0	9	0	0	1.8284948891774926	
i 1	73.74765306122448	1.2625	74	901	6	2	3	8	0	-2	8	0	0	3.067810841647686	
i 1	73.75153061224489	0.2525	71	199	4	5	9	8	0	-2	8	0	0	2.0	
i 1	73.75438775510204	0.2525	73	199	1	20	15	2	0	-1	2	0	0	4.100225206384465	
i 1	73.75459183673469	0.2525	71	901	4	5	1	2	0	-2	2	0	0	2.0	
i 1	73.99663265306123	1.01	61	901	5	25	7	6	0	0	6	0	0	0.7010281627802958	
i 1	73.99704081632653	1.01	61	199	4	19	2	6	0	0	6	0	0	1.8284948891774926	
i 1	73.99765306122448	0.2525	71	585	4	5	9	2	0	-2	2	0	0	2.0	
i 1	73.99785714285714	1.01	61	199	5	16	11	6	0	0	6	0	0	7.954185212233021	
i 1	73.99948979591836	0.2525	71	199	3	5	10	8	0	-2	8	0	0	2.0	
i 1	74.245	0.2525	74	199	3	5	3	8	0	-1	8	0	0	2.0	
i 1	74.49989795918367	0.505	61	901	5	14	2	6	0	1	6	0	0	8.948458363762148	
i 1	74.50153061224489	0.505	66	199	6	12	14	6	0	0	6	0	0	7.954185212233021	
i 1	74.50173469387755	0.505	61	199	4	19	12	9	0	0	9	0	0	1.8284948891774926	
i 1	74.5019387755102	0.2525	71	585	4	5	6	2	0	-2	2	0	0	2.0	
i 1	74.50234693877552	0.2525	71	585	5	3	3	2	0	-1	2	0	0	3.067810841647686	
i 1	74.50459183673469	0.505	61	585	5	25	12	9	0	0	9	0	0	0.7010281627802958	
i 1	74.74704081632653	0.2525	74	901	5	2	3	8	0	-2	8	0	0	3.067810841647686	
i 1	74.75091836734694	0.2525	71	199	3	5	10	8	0	-2	8	0	0	2.0	
i 1	74.99826530612245	0.2525	74	697	4	4	16	8	0	-2	8	0	0	3.240023754324743	
i 1	74.99826530612245	0.505	61	697	5	25	3	9	0	0	9	0	0	3.468996208452821	
i 1	74.99826530612245	1.5150000000000001	61	697	3	27	9	9	0	1	9	0	0	4.457453588584074	
i 1	74.99867346938775	2.02	61	697	3	27	16	6	0	1	6	0	0	4.457453588584074	
i 1	74.99887755102041	2.525	71	697	4	5	6	8	0	-1	8	0	0	2.078708393723923	
i 1	74.99989795918367	0.505	61	199	5	26	3	9	0	1	9	0	0	3.468996208452821	
i 1	74.99989795918367	1.2625	70	697	1	20	8	8	0	-1	8	0	0	4.100225206384465	
i 1	75.00010204081633	1.01	66	697	5	25	8	9	0	1	9	0	0	3.468996208452821	
i 1	75.00091836734694	1.01	61	199	5	18	6	6	0	1	6	0	0	0.5653900720121986	
i 1	75.00091836734694	0.2525	74	199	4	5	2	8	0	-2	8	0	0	2.078708393723923	
i 1	75.00173469387755	2.525	61	697	4	19	6	6	0	0	6	0	0	0.5653900720121986	
i 1	75.00275510204082	1.5150000000000001	61	199	5	18	12	9	0	1	9	0	0	0.5653900720121986	
i 1	75.00316326530613	0.505	71	697	5	3	13	8	0	-1	8	0	0	3.240023754324743	
i 1	75.00459183673469	2.02	66	697	4	19	14	6	0	1	6	0	0	0.5653900720121986	
i 1	75.00479591836735	1.01	61	199	5	26	2	9	0	1	9	0	0	3.468996208452821	
i 1	75.005	0.505	66	697	5	17	9	9	0	0	9	0	0	0.5653900720121986	
i 1	75.2480612244898	0.505	71	697	4	5	15	8	0	-1	8	0	0	2.078708393723923	
i 1	75.24948979591836	0.505	74	199	6	9	10	2	0	-2	2	0	0	2.240023754324743	
i 1	75.50112244897959	1.01	61	199	5	26	11	9	0	1	9	0	0	3.468996208452821	
i 1	75.50295918367347	2.525	71	697	5	3	14	8	0	-1	8	0	0	3.240023754324743	
i 1	75.74887755102041	0.2525	74	697	4	4	3	8	0	-2	8	0	0	3.240023754324743	
i 1	75.74969387755102	0.2525	74	1083	4	5	3	8	0	-2	8	0	0	2.078708393723923	
i 1	75.99826530612245	0.2525	74	1083	5	2	12	8	0	-2	8	0	0	3.240023754324743	
i 1	75.99969387755102	1.01	61	199	5	26	10	9	0	1	9	0	0	3.468996208452821	
i 1	75.99969387755102	0.2525	71	697	3	5	16	8	0	-2	8	0	0	2.078708393723923	
i 1	76.24602040816326	0.2525	74	1083	4	5	9	8	0	-1	8	0	0	2.078708393723923	
i 1	76.24846938775511	0.2525	73	697	2	24	10	2	0	-1	2	0	0	8.100225206384465	
i 1	76.25030612244898	0.2525	71	199	6	9	6	8	0	-2	8	0	0	2.240023754324743	
i 1	76.49602040816326	1.01	61	697	3	27	16	9	0	1	9	0	0	4.457453588584074	
i 1	76.49846938775511	0.505	73	199	2	20	3	8	0	-2	8	0	0	4.100225206384465	
i 1	76.49867346938775	0.2525	71	697	3	5	6	8	0	-2	8	0	0	2.078708393723923	
i 1	76.50010204081633	0.2525	74	1083	5	2	12	8	0	-2	8	0	0	3.240023754324743	
i 1	76.50173469387755	0.505	73	199	2	20	4	2	0	-1	2	0	0	4.100225206384465	
i 1	76.74908163265306	0.505	74	1083	4	5	10	8	0	-1	8	0	0	2.078708393723923	
i 1	76.75214285714286	0.2525	74	697	4	4	3	8	0	-2	8	0	0	3.240023754324743	
i 1	76.99969387755102	0.505	61	1083	5	25	11	6	0	1	6	0	0	3.468996208452821	
i 1	77.00010204081633	0.505	61	697	3	27	9	6	0	1	6	0	0	4.457453588584074	
i 1	77.00153061224489	0.2525	74	1083	5	2	5	8	0	-2	8	0	0	3.240023754324743	
i 1	77.0019387755102	0.505	73	697	1	24	9	2	0	-1	2	0	0	8.100225206384465	
i 1	77.00418367346938	0.505	73	199	2	24	6	8	0	-1	8	0	0	8.100225206384465	
i 1	77.245	0.2525	71	199	5	9	11	8	0	-2	8	0	0	2.240023754324743	
i 1	77.25275510204082	0.2525	74	1083	4	5	6	8	0	-2	8	0	0	2.078708393723923	
i 1	77.49622448979592	2.525	66	1195	5	25	13	9	0	1	9	0	0	3.468996208452821	
i 1	77.49724489795918	1.01	73	1195	2	24	11	2	0	-2	2	0	0	10.579914805283185	
i 1	77.49785714285714	1.5150000000000001	71	697	4	5	1	8	0	-1	8	0	0	2.078708393723923	
i 1	77.4980612244898	0.2525	74	381	4	3	15	8	0	-2	8	0	0	3.240023754324743	
i 1	77.4980612244898	0.505	61	381	3	27	2	6	0	0	6	0	0	4.457453588584074	
i 1	77.50112244897959	2.525	61	1195	5	25	3	6	0	0	6	0	0	3.468996208452821	
i 1	77.50418367346938	0.2525	74	1195	6	5	10	2	0	-2	2	0	0	2.078708393723923	
i 1	77.50438775510204	1.01	73	1195	2	20	16	8	0	-2	8	0	0	6.579914805283185	
i 1	77.74989795918367	0.2525	71	697	4	5	9	8	0	-1	8	0	0	2.078708393723923	
i 1	77.75153061224489	0.2525	71	381	4	4	6	2	0	-1	2	0	0	3.240023754324743	
i 1	77.99663265306123	4.545	61	697	5	25	4	9	0	0	9	0	0	3.468996208452821	
i 1	77.99744897959184	0.2525	71	1195	5	9	4	2	0	-1	2	0	0	2.240023754324743	
i 1	77.99928571428572	0.2525	74	1195	6	5	4	2	0	-2	2	0	0	2.078708393723923	
i 1	78.00030612244898	0.7575000000000001	71	697	4	3	16	8	0	-1	8	0	0	3.240023754324743	
i 1	78.25071428571428	0.505	74	1195	4	5	15	2	0	-2	2	0	0	2.078708393723923	
i 1	78.25479591836735	0.2525	74	1195	5	2	6	2	0	-2	2	0	0	3.240023754324743	
i 1	78.495	0.505	70	381	1	24	16	8	0	-2	8	0	0	10.579914805283185	
i 1	78.49744897959184	0.505	70	381	1	20	6	2	0	-2	2	0	0	6.579914805283185	
i 1	78.49867346938775	4.04	66	697	5	25	8	9	0	1	9	0	0	3.468996208452821	
i 1	78.50214285714286	0.2525	71	381	4	4	7	2	0	-1	2	0	0	3.240023754324743	
i 1	78.74540816326531	0.505	74	1195	6	2	6	2	0	-2	2	0	0	3.240023754324743	
i 1	78.74561224489796	0.2525	74	1195	5	2	11	2	0	-2	2	0	0	3.240023754324743	
i 1	78.74908163265306	0.2525	71	1195	4	5	14	8	0	-1	8	0	0	2.078708393723923	
i 1	78.99642857142857	0.2525	73	381	2	24	7	2	0	-2	2	0	0	10.579914805283185	
i 1	78.99887755102041	0.2525	70	1195	1	24	2	2	0	-1	2	0	0	10.579914805283185	
i 1	78.99989795918367	1.01	61	381	4	26	13	6	0	1	6	0	0	3.468996208452821	
i 1	79.00255102040816	0.505	71	697	4	3	7	8	0	-1	8	0	0	3.240023754324743	
i 1	79.00255102040816	0.2525	71	697	6	5	1	8	0	-1	8	0	0	2.078708393723923	
i 1	79.00336734693877	1.01	74	1195	6	5	1	8	0	-1	8	0	0	2.078708393723923	
i 1	79.24581632653062	0.2525	73	381	2	20	9	2	0	-2	2	0	0	6.579914805283185	
i 1	79.24602040816326	0.7575000000000001	74	697	4	4	14	8	0	-2	8	0	0	3.240023754324743	
i 1	79.25295918367347	0.2525	71	1195	3	5	2	2	0	-2	2	0	0	2.078708393723923	
i 1	79.25438775510204	0.2525	73	1195	3	20	5	8	0	-2	8	0	0	6.579914805283185	
i 1	79.49622448979592	0.505	61	381	4	26	14	9	0	0	9	0	0	3.468996208452821	
i 1	79.49642857142857	0.2525	71	697	6	5	11	8	0	-1	8	0	0	2.078708393723923	
i 1	79.4980612244898	0.2525	71	697	5	3	4	8	0	-1	8	0	0	3.240023754324743	
i 1	79.49908163265306	0.505	70	1195	1	24	2	2	0	-1	2	0	0	10.579914805283185	
i 1	79.50316326530613	0.505	73	381	2	24	2	2	0	-2	2	0	0	10.579914805283185	
i 1	79.74540816326531	0.2525	71	381	4	5	8	2	0	-1	2	0	0	2.078708393723923	
i 1	79.75438775510204	0.2525	74	1195	4	3	4	8	0	-2	8	0	0	3.240023754324743	
i 1	79.99561224489796	1.5150000000000001	71	1083	5	2	15	2	0	-2	2	0	0	3.240023754324743	
i 1	79.99704081632653	0.2525	74	199	7	5	5	2	0	-2	2	0	0	2.078708393723923	
i 1	79.99724489795918	2.525	66	199	4	27	4	6	0	1	6	0	0	4.457453588584074	
i 1	79.9980612244898	2.525	66	1083	5	25	2	6	0	0	6	0	0	3.468996208452821	
i 1	79.99969387755102	2.525	61	199	5	26	10	9	0	0	9	0	0	3.468996208452821	
i 1	80.00030612244898	0.2525	74	1083	5	2	7	8	0	-1	8	0	0	3.240023754324743	
i 1	80.00030612244898	0.505	73	199	1	24	5	8	0	-1	8	0	0	10.579914805283185	
i 1	80.00112244897959	0.505	73	199	1	20	7	8	0	-1	8	0	0	6.579914805283185	
i 1	80.00336734693877	2.525	71	697	6	5	3	8	0	-1	8	0	0	2.078708393723923	
i 1	80.00357142857143	2.525	61	199	5	26	12	6	0	1	6	0	0	3.468996208452821	
i 1	80.00418367346938	2.525	61	1083	5	25	15	9	0	1	9	0	0	3.468996208452821	
i 1	80.25377551020408	0.2525	74	199	4	9	11	2	0	-1	2	0	0	2.240023754324743	
i 1	80.25377551020408	0.2525	74	1083	6	5	16	2	0	-2	2	0	0	2.078708393723923	
i 1	80.49704081632653	0.2525	71	199	3	4	2	2	0	-2	2	0	0	3.240023754324743	
i 1	80.49826530612245	2.02	61	199	4	27	12	9	0	1	9	0	0	4.457453588584074	
i 1	80.50255102040816	0.2525	70	199	2	24	10	8	0	-1	8	0	0	10.579914805283185	
i 1	80.50479591836735	0.2525	71	1083	6	5	2	8	0	-2	8	0	0	2.078708393723923	
i 1	80.50479591836735	0.2525	73	697	2	24	4	2	0	-2	2	0	0	10.579914805283185	
i 1	80.74744897959184	0.2525	70	199	2	20	10	2	0	-2	2	0	0	6.579914805283185	
i 1	80.74908163265306	0.2525	71	697	6	5	12	8	0	-1	8	0	0	2.078708393723923	
i 1	80.75173469387755	0.2525	70	199	4	20	10	8	0	-1	8	0	0	6.579914805283185	
i 1	80.75418367346938	0.2525	74	199	4	9	10	2	0	-1	2	0	0	2.240023754324743	
i 1	80.99602040816326	0.2525	70	199	2	24	10	8	0	-1	8	0	0	10.579914805283185	
i 1	80.99683673469387	0.505	74	1083	6	5	15	2	0	-2	2	0	0	2.078708393723923	
i 1	81.00091836734694	0.2525	73	697	2	24	3	2	0	-2	2	0	0	10.579914805283185	
i 1	81.00459183673469	0.505	71	199	3	4	10	2	0	-2	2	0	0	3.240023754324743	
i 1	81.24663265306123	0.2525	73	199	3	20	10	2	0	-1	2	0	0	6.579914805283185	
i 1	81.24785714285714	0.2525	73	199	1	24	14	8	0	-1	8	0	0	10.579914805283185	
i 1	81.4980612244898	0.2525	70	199	2	24	6	8	0	-1	8	0	0	10.579914805283185	
i 1	81.50030612244898	1.01	71	697	5	3	15	8	0	-1	8	0	0	3.240023754324743	
i 1	81.50051020408164	0.2525	74	1083	5	2	14	8	0	-1	8	0	0	3.240023754324743	
i 1	81.50418367346938	0.2525	70	697	4	24	2	8	0	-1	8	0	0	10.579914805283185	
i 1	81.50438775510204	0.2525	74	199	7	5	4	2	0	-2	2	0	0	2.078708393723923	
i 1	81.74622448979592	0.2525	74	1083	6	5	16	2	0	-2	2	0	0	2.078708393723923	
i 1	81.75030612244898	0.2525	71	199	3	4	6	2	0	-2	2	0	0	3.240023754324743	
i 1	81.75173469387755	0.2525	70	199	2	20	10	2	0	-2	2	0	0	6.579914805283185	
i 1	81.75316326530613	0.2525	70	199	4	20	1	2	0	-2	2	0	0	6.579914805283185	
i 1	81.995	0.2525	74	199	4	3	9	2	0	-1	2	0	0	3.240023754324743	
i 1	81.99642857142857	0.2525	70	697	4	24	8	2	0	-1	2	0	0	10.579914805283185	
i 1	81.99928571428572	0.2525	71	199	6	5	16	2	0	-2	2	0	0	2.078708393723923	
i 1	82.00234693877552	0.2525	70	199	4	24	10	8	0	-1	8	0	0	10.579914805283185	
i 1	82.24581632653062	0.2525	73	199	1	24	3	8	0	-1	8	0	0	10.579914805283185	
i 1	82.2519387755102	0.2525	74	1083	5	2	16	8	0	-1	8	0	0	3.240023754324743	
i 1	82.25255102040816	0.2525	73	199	3	20	2	8	0	-1	8	0	0	6.579914805283185	
i 1	82.25459183673469	0.2525	74	199	7	5	1	2	0	-2	2	0	0	2.078708393723923	
i 1	82.49561224489796	2.2725	61	199	5	26	11	9	0	0	9	0	0	6.793926193478677	
i 1	82.49602040816326	2.525	61	901	3	14	15	6	0	0	6	0	0	8.453157474065137	
i 1	82.4980612244898	1.5150000000000001	66	697	5	25	9	9	0	1	9	0	0	6.793926193478677	
i 1	82.49928571428572	2.2725	66	199	4	27	7	6	0	1	6	0	0	7.782383573609931	
i 1	82.49969387755102	2.2725	61	199	4	27	6	9	0	1	9	0	0	7.782383573609931	
i 1	82.49969387755102	1.01	66	697	4	7	10	6	0	0	6	0	0	4.461617520949478	
i 1	82.49989795918367	1.5150000000000001	61	697	5	25	6	9	0	0	9	0	0	6.793926193478677	
i 1	82.50030612244898	1.5150000000000001	66	901	5	25	14	9	0	1	9	0	0	6.793926193478677	
i 1	82.50030612244898	0.2525	71	199	5	5	5	2	0	-2	2	0	0	2.0	
i 1	82.50051020408164	1.01	61	901	5	25	11	6	0	0	6	0	0	6.793926193478677	
i 1	82.50071428571428	1.01	74	697	4	4	7	8	0	-2	8	0	0	3.322717480990833	
i 1	82.50357142857143	0.7575000000000001	71	697	6	5	9	8	0	-1	8	0	0	2.0	
i 1	82.50418367346938	0.7575000000000001	73	199	2	20	8	8	0	-1	8	0	0	6.579914805283185	
i 1	82.50438775510204	2.2725	61	199	5	26	9	6	0	1	6	0	0	6.793926193478677	
i 1	82.50438775510204	2.525	61	901	3	14	2	9	0	0	9	0	0	8.453157474065137	
i 1	82.505	0.505	71	199	3	4	3	2	0	-2	2	0	0	3.322717480990833	
i 1	82.74602040816326	0.2525	71	697	6	5	9	8	0	-1	8	0	0	2.0	
i 1	83.00255102040816	0.2525	71	199	5	9	6	2	0	-1	2	0	0	2.322717480990833	
i 1	83.00459183673469	0.2525	73	199	2	24	7	8	0	-1	8	0	0	10.579914805283185	
i 1	83.005	0.505	71	901	6	5	15	2	0	-1	2	0	0	2.0	
i 1	83.25010204081633	0.2525	74	199	5	9	12	2	0	-1	2	0	0	2.322717480990833	
i 1	83.25010204081633	0.2525	71	199	7	5	11	8	0	-2	8	0	0	2.0	
i 1	83.25479591836735	1.01	70	199	2	24	6	8	0	-1	8	0	0	10.579914805283185	
i 1	83.49520408163265	0.7575000000000001	73	199	2	20	5	2	0	-1	2	0	0	6.579914805283185	
i 1	83.49826530612245	0.505	74	697	4	4	16	8	0	-2	8	0	0	3.322717480990833	
i 1	83.50071428571428	0.505	66	697	4	7	14	6	0	0	6	0	0	4.461617520949478	
i 1	83.5019387755102	0.2525	71	901	6	2	15	2	0	-1	2	0	0	3.322717480990833	
i 1	83.50418367346938	0.2525	71	697	6	5	1	8	0	-1	8	0	0	2.0	
i 1	83.50438775510204	0.505	71	901	5	5	7	2	0	-1	2	0	0	2.0	
i 1	83.505	1.5150000000000001	61	901	5	25	6	6	0	0	6	0	0	6.793926193478677	
i 1	83.74581632653062	0.2525	74	901	6	2	11	8	0	-1	8	0	0	3.322717480990833	
i 1	83.75418367346938	0.2525	71	901	6	5	4	8	0	-2	8	0	0	2.0	
i 1	83.99602040816326	1.01	71	901	6	2	15	2	0	-1	2	0	0	3.322717480990833	
i 1	83.99683673469387	0.505	66	585	5	25	12	9	0	0	9	0	0	6.793926193478677	
i 1	83.99948979591836	0.2525	74	585	4	4	9	8	0	-1	8	0	0	3.322717480990833	
i 1	84.00173469387755	1.01	66	585	5	25	9	9	0	1	9	0	0	6.793926193478677	
i 1	84.00255102040816	1.01	71	901	5	5	8	8	0	-2	8	0	0	2.0	
i 1	84.00336734693877	1.01	61	585	4	7	16	6	0	0	6	0	0	4.461617520949478	
i 1	84.00357142857143	1.01	66	901	5	25	14	9	0	1	9	0	0	6.793926193478677	
i 1	84.00357142857143	0.2525	74	199	7	5	2	2	0	-2	2	0	0	2.0	
i 1	84.24602040816326	0.2525	71	199	5	5	16	2	0	-2	2	0	0	2.0	
i 1	84.24948979591836	0.2525	70	199	4	24	7	8	0	-1	8	0	0	10.579914805283185	
i 1	84.25132653061225	0.505	74	199	3	3	6	2	0	-1	2	0	0	3.322717480990833	
i 1	84.25132653061225	0.2525	70	585	4	24	8	8	0	-1	8	0	0	10.579914805283185	
i 1	84.49561224489796	0.2525	70	199	2	24	4	8	0	-2	8	0	0	12.409705499223124	
i 1	84.4980612244898	0.2525	73	199	2	20	11	2	0	-1	2	0	0	8.409705499223124	
i 1	84.49887755102041	0.2525	74	585	5	5	12	2	0	-2	2	0	0	2.0	
i 1	84.50091836734694	0.505	66	585	5	25	6	9	0	0	9	0	0	6.793926193478677	
i 1	84.74561224489796	0.2525	73	1167	4	20	14	8	0	-2	8	0	0	8.409705499223124	
i 1	84.74622448979592	0.2525	61	1167	4	26	7	6	0	0	6	0	0	6.793926193478677	
i 1	84.74846938775511	0.2525	61	1167	4	26	6	9	0	1	9	0	0	6.793926193478677	
i 1	84.74989795918367	0.2525	74	585	4	4	6	8	0	-1	8	0	0	3.322717480990833	
i 1	84.75214285714286	0.2525	74	1167	6	5	15	8	0	-1	8	0	0	2.0	
i 1	84.75255102040816	0.2525	70	1167	4	20	10	8	0	-1	8	0	0	8.409705499223124	
i 1	84.75316326530613	0.2525	61	198	4	27	2	6	0	0	6	0	0	7.782383573609931	
i 1	84.75459183673469	0.2525	66	198	4	27	8	6	0	0	6	0	0	7.782383573609931	
i 1	84.99540816326531	2.02	61	698	3	27	4	6	0	0	6	0	0	7.782383573609931	
i 1	84.99581632653062	3.0300000000000002	61	200	5	25	13	9	0	1	9	0	0	6.793926193478677	
i 1	84.99663265306123	1.5150000000000001	66	698	3	14	14	6	0	1	6	0	0	8.453157474065137	
i 1	84.99846938775511	2.02	61	698	5	25	15	6	0	1	6	0	0	6.793926193478677	
i 1	84.99846938775511	1.01	66	1084	4	26	6	9	0	1	9	0	0	6.793926193478677	
i 1	84.99887755102041	1.01	71	200	5	5	1	2	0	-2	2	0	0	2.0	
i 1	84.99989795918367	2.525	66	200	5	25	2	9	0	1	9	0	0	6.793926193478677	
i 1	84.99989795918367	0.2525	71	200	5	5	9	8	0	-2	8	0	0	2.0	
i 1	85.00030612244898	2.525	61	200	4	7	5	6	0	1	6	0	0	4.461617520949478	
i 1	85.00112244897959	0.2525	74	200	5	4	11	8	0	-1	8	0	0	3.322717480990833	
i 1	85.00153061224489	1.5150000000000001	61	698	3	27	11	9	0	1	9	0	0	7.782383573609931	
i 1	85.0019387755102	0.505	70	698	2	24	9	2	0	-1	2	0	0	12.409705499223124	
i 1	85.00234693877552	1.01	74	698	6	2	4	8	0	-1	8	0	0	3.322717480990833	
i 1	85.00255102040816	0.505	70	698	2	20	2	2	0	-1	2	0	0	8.409705499223124	
i 1	85.00295918367347	1.5150000000000001	66	698	5	25	6	6	0	1	6	0	0	6.793926193478677	
i 1	85.00479591836735	0.505	66	1084	4	26	9	6	0	1	6	0	0	6.793926193478677	
i 1	85.005	1.01	61	698	3	14	12	6	0	0	6	0	0	8.453157474065137	
i 1	85.24663265306123	0.2525	74	698	5	5	6	8	0	-1	8	0	0	2.0	
i 1	85.24785714285714	0.2525	74	698	6	2	16	2	0	-1	2	0	0	3.322717480990833	
i 1	85.49540816326531	0.2525	71	698	5	5	14	2	0	-2	2	0	0	2.0	
i 1	85.49948979591836	0.2525	70	1084	3	24	10	2	0	-1	2	0	0	12.409705499223124	
i 1	85.5019387755102	0.2525	74	1084	5	9	1	8	0	-2	8	0	0	2.322717480990833	
i 1	85.50357142857143	3.0300000000000002	66	1084	4	26	11	6	0	1	6	0	0	6.793926193478677	
i 1	85.50397959183674	0.2525	70	200	4	24	5	2	0	-1	2	0	0	12.409705499223124	
i 1	85.74622448979592	0.7575000000000001	70	698	2	24	16	2	0	-1	2	0	0	12.409705499223124	
i 1	85.74622448979592	0.7575000000000001	70	698	2	20	1	2	0	-1	2	0	0	8.409705499223124	
i 1	85.74867346938775	0.2525	71	1084	4	5	12	2	0	-1	2	0	0	2.0	
i 1	85.75173469387755	0.2525	71	698	4	4	11	2	0	-2	2	0	0	3.322717480990833	
i 1	85.99561224489796	0.505	74	1084	5	9	16	8	0	-2	8	0	0	2.322717480990833	
i 1	85.99561224489796	2.02	61	698	5	14	12	6	0	0	6	0	0	8.453157474065137	
i 1	85.99887755102041	3.0300000000000002	66	1084	4	26	13	9	0	1	9	0	0	6.793926193478677	
i 1	86.00214285714286	0.505	71	200	7	5	2	2	0	-2	2	0	0	2.0	
i 1	86.00357142857143	0.505	74	698	6	5	15	2	0	-1	2	0	0	2.0	
i 1	86.00479591836735	0.505	74	698	6	2	12	8	0	-1	8	0	0	3.322717480990833	
i 1	86.4980612244898	3.0300000000000002	61	698	3	27	3	9	0	1	9	0	0	7.782383573609931	
i 1	86.4980612244898	2.02	66	698	5	14	3	6	0	1	6	0	0	8.453157474065137	
i 1	86.50377551020408	3.535	66	698	5	25	7	6	0	1	6	0	0	6.793926193478677	
i 1	86.99928571428572	3.0300000000000002	61	698	3	27	2	6	0	0	6	0	0	7.782383573609931	
i 1	87.00255102040816	3.0300000000000002	61	698	5	25	6	6	0	1	6	0	0	6.793926193478677	
i 1	87.49908163265306	2.525	66	200	6	25	3	9	0	1	9	0	0	6.793926193478677	
i 1	87.50030612244898	2.02	61	200	7	7	8	6	0	1	6	0	0	4.461617520949478	
i 1	87.99561224489796	2.02	61	200	6	25	10	9	0	1	9	0	0	6.793926193478677	
i 1	88.00010204081633	2.02	61	698	5	14	16	6	0	0	6	0	0	8.453157474065137	
i 1	88.50234693877552	1.5150000000000001	66	1084	4	26	10	6	0	1	6	0	0	6.793926193478677	
i 1	88.50438775510204	1.5150000000000001	66	698	5	14	2	6	0	1	6	0	0	8.453157474065137	
i 1	88.99683673469387	1.01	66	1084	4	26	9	9	0	1	9	0	0	6.793926193478677	
i 1	89.49540816326531	0.505	61	200	5	7	12	6	0	1	6	0	0	4.461617520949478	
i 1	89.50336734693877	0.505	61	698	3	27	2	9	0	1	9	0	0	7.782383573609931	
i 1	89.99520408163265	1.01	66	698	5	25	12	6	0	1	6	0	0	9.88457380131254	
i 1	89.99663265306123	2.525	66	1084	4	26	5	6	0	1	6	0	0	9.88457380131254	
i 1	89.99724489795918	2.525	61	698	5	14	15	6	0	0	6	0	0	9.096239131969106	
i 1	89.99765306122448	2.525	66	1084	4	26	13	9	0	1	9	0	0	9.88457380131254	
i 1	89.99785714285714	2.525	61	200	5	7	16	6	0	1	6	0	0	5.104699178853448	
i 1	89.99846938775511	2.525	61	200	6	25	11	9	0	1	9	0	0	9.88457380131254	
i 1	89.99846938775511	2.525	61	698	3	27	2	9	0	1	9	0	0	10.873031181443796	
i 1	89.99928571428572	2.525	66	698	5	14	11	6	0	1	6	0	0	9.096239131969106	
i 1	90.00051020408164	2.525	61	698	3	27	6	6	0	0	6	0	0	10.873031181443796	
i 1	90.00255102040816	1.5150000000000001	61	698	5	25	3	6	0	1	6	0	0	9.88457380131254	
i 1	90.005	2.02	66	200	6	25	1	9	0	1	9	0	0	9.88457380131254	
i 1	91.00091836734694	1.5150000000000001	66	698	5	25	14	6	0	1	6	0	0	9.88457380131254	
i 1	91.49622448979592	1.01	61	698	5	25	3	6	0	1	6	0	0	9.88457380131254	
i 1	92.00255102040816	0.505	66	200	6	25	10	9	0	1	9	0	0	9.88457380131254	
t0 30
</CsScore>
</CsoundSynthesizer>

