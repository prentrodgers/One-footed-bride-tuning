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
 ; valid glissando table number are 1500 since 4/28/23 changed 5/10/26 to now start at 5000 to avoid colliding with the sample files
 i12 = 298-p12 ; valid envelope table number are 298, 297, 296, 295 etc. - right channel 
 i10 = p10 ; glissando #1 
 i13 = p13 ; glissando #2
 i14 = p14 ; glissando #3
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

f5000.0 0.0 256.0 -6.0 1.0 128.0 1.004934 128.0 1.009868 
;Inst	Sta	Hold	Vel	Ton	Oct	Voi	Ste	En1	Gls	Ups	Ren	2gl	3gl	Vol
i 1	0.00020408163265306194	0.2525	68	414	1	24	12	0	0	0	0	0	0	8.0	
i 1	0.0006122448979591841	5.05	61	98	6	25	11	16	0	1	16	0	0	2.039524715566356	
i 1	0.0014285714285714284	1.01	74	98	7	1	2	2	0	-2	2	0	0	2.0	
i 1	0.0014285714285714284	1.01	75	98	5	5	1	2	0	-2	2	0	0	10.0	
i 1	0.0014285714285714284	0.7575000000000001	75	414	6	5	6	2	0	-2	2	0	0	10.0	
i 1	0.0022448979591836735	0.2525	71	414	1	20	3	0	0	-1	0	0	0	4.0	
i 1	0.0030612244897959186	0.505	74	98	6	2	5	16	0	1	16	0	0	13.0	
i 1	0.003877551020408163	1.01	75	98	6	5	8	2	0	1	2	0	0	10.0	
i 1	0.005918367346938775	0.2525	71	414	2	20	3	0	0	0	0	0	0	4.0	
i 1	0.006326530612244899	1.01	74	98	7	1	5	8	0	-1	8	0	0	2.0	
i 1	0.009183673469387756	1.01	74	414	6	1	6	2	0	-1	2	0	0	2.0	
i 1	0.009591836734693876	0.7575000000000001	77	98	7	2	16	16	0	1	16	0	0	13.0	
i 1	0.01	0.505	77	414	5	9	14	16	0	2	16	0	0	12.0	
i 1	0.01	0.2525	68	414	3	20	8	1	0	-1	1	0	0	4.0	
i 1	0.2420408163265306	0.7575000000000001	68	912	1	20	1	1	0	0	1	0	0	4.0	
i 1	0.2453061224489796	0.505	77	414	5	9	7	17	0	1	17	0	0	12.0	
i 1	0.7412244897959184	0.2525	74	912	5	3	6	16	0	2	16	0	0	13.0	
i 1	0.7416326530612245	0.505	74	912	4	3	16	16	0	2	16	0	0	13.0	
i 1	0.7551020408163265	1.01	75	414	6	5	7	8	0	1	8	0	0	10.0	
i 1	0.993265306122449	0.505	68	414	1	24	16	0	0	0	0	0	0	14.999999999999998	
i 1	0.9957142857142857	5.05	63	98	6	25	2	16	0	1	16	0	0	2.039524715566356	
i 1	0.9977551020408163	0.505	71	414	1	20	7	0	0	-1	0	0	0	10.999999999999998	
i 1	1.0010204081632652	0.505	68	414	2	20	1	1	0	-1	1	0	0	10.999999999999998	
i 1	1.0014285714285713	0.2525	74	912	5	3	11	16	0	2	16	0	0	13.0	
i 1	1.0014285714285713	0.505	71	414	2	20	10	0	0	0	0	0	0	10.999999999999998	
i 1	1.0026530612244897	0.7575000000000001	75	98	6	5	3	2	0	-2	2	0	0	10.0	
i 1	1.0042857142857142	1.01	74	98	7	1	15	2	0	-2	2	0	0	2.0	
i 1	1.0042857142857142	1.01	74	414	6	1	8	2	0	-1	2	0	0	2.0	
i 1	1.246530612244898	0.505	68	912	1	24	6	1	0	0	1	0	0	14.999999999999998	
i 1	1.2510204081632652	0.2525	74	98	7	1	5	8	0	-1	8	0	0	2.0	
i 1	1.2522448979591836	0.2525	77	912	4	4	9	17	0	1	17	0	0	13.0	
i 1	1.2522448979591836	0.505	68	912	1	20	13	1	0	0	1	0	0	10.999999999999998	
i 1	1.2587755102040816	0.2525	77	912	4	4	6	17	0	1	17	0	0	13.0	
i 1	1.496530612244898	0.505	75	912	4	5	12	2	0	1	2	0	0	10.0	
i 1	1.4977551020408164	0.7575000000000001	75	912	6	5	3	2	0	1	2	0	0	10.0	
i 1	1.5055102040816326	0.7575000000000001	77	414	5	9	1	16	0	2	16	0	0	12.0	
i 1	1.5059183673469387	0.7575000000000001	74	98	6	2	8	16	0	1	16	0	0	13.0	
i 1	1.74	0.2525	68	414	1	24	13	0	0	0	0	0	0	14.999999999999998	
i 1	1.7404081632653061	1.2625	68	414	2	20	6	1	0	-1	1	0	0	10.999999999999998	
i 1	1.743265306122449	0.2525	71	912	6	1	11	8	0	-1	8	0	0	2.0	
i 1	1.7457142857142858	0.7575000000000001	74	912	4	24	5	8	0	-1	8	0	0	3.0	
i 1	1.7469387755102042	1.2625	71	414	2	20	10	0	0	0	0	0	0	10.999999999999998	
i 1	1.749795918367347	1.2625	71	414	1	20	15	0	0	-1	0	0	0	10.999999999999998	
i 1	1.7514285714285713	0.7575000000000001	74	912	4	24	5	8	0	-1	8	0	0	3.0	
i 1	1.7595918367346939	0.2525	74	912	5	1	10	2	0	-1	2	0	0	2.0	
i 1	1.9957142857142858	1.01	68	414	3	24	13	0	0	0	0	0	0	14.999999999999998	
i 1	1.9969387755102042	5.05	63	912	5	25	15	1	0	2	1	0	0	2.039524715566356	
i 1	1.9981632653061225	0.2525	75	912	5	5	11	2	0	1	2	0	0	10.0	
i 1	2.24	1.01	74	98	7	1	2	8	0	-1	8	0	0	2.0	
i 1	2.2448979591836733	1.01	77	98	6	2	10	16	0	1	16	0	0	13.0	
i 1	2.2510204081632654	0.7575000000000001	72	912	4	5	6	2	0	1	2	0	0	10.0	
i 1	2.253469387755102	1.01	77	414	5	9	15	17	0	1	17	0	0	12.0	
i 1	2.255918367346939	1.01	74	414	6	1	15	2	0	-1	2	0	0	2.0	
i 1	2.255918367346939	0.2525	75	414	6	5	15	8	0	1	8	0	0	10.0	
i 1	2.256326530612245	1.5150000000000001	74	912	5	3	16	16	0	2	16	0	0	13.0	
i 1	2.257142857142857	0.7575000000000001	75	912	6	5	6	8	0	-2	8	0	0	10.0	
i 1	2.4977551020408164	0.2525	68	912	1	24	5	1	0	0	1	0	0	14.999999999999998	
i 1	2.9948979591836733	1.01	75	414	4	5	1	2	0	-2	2	0	0	10.0	
i 1	3.0018367346938777	1.01	75	98	5	5	5	2	0	1	2	0	0	10.0	
i 1	3.009591836734694	5.05	63	912	5	25	7	1	0	1	1	0	0	2.039524715566356	
i 1	3.2416326530612243	0.2525	74	414	6	1	9	2	0	-1	2	0	0	2.0	
i 1	3.242857142857143	0.2525	74	98	7	1	8	2	0	-2	2	0	0	2.0	
i 1	3.2444897959183674	1.5150000000000001	71	912	6	1	10	8	0	-1	8	0	0	2.0	
i 1	3.253061224489796	0.505	74	912	4	3	12	16	0	2	16	0	0	13.0	
i 1	3.5083673469387757	0.505	74	912	5	1	5	2	0	-1	2	0	0	2.0	
i 1	3.740408163265306	1.5150000000000001	68	414	2	20	9	1	0	-1	1	0	0	10.999999999999998	
i 1	3.7522448979591836	0.2525	77	912	4	4	14	17	0	1	17	0	0	13.0	
i 1	3.7546938775510204	1.5150000000000001	71	414	2	20	12	0	0	0	0	0	0	10.999999999999998	
i 1	3.7551020408163267	0.2525	77	912	4	4	6	17	0	1	17	0	0	13.0	
i 1	3.756326530612245	1.2625	71	414	3	20	15	0	0	-1	0	0	0	10.999999999999998	
i 1	3.757142857142857	0.2525	68	414	3	24	12	0	0	0	0	0	0	14.999999999999998	
i 1	3.993265306122449	5.05	61	414	4	26	6	1	0	1	1	0	0	2.039524715566356	
i 1	3.996938775510204	0.7575000000000001	77	414	5	9	8	16	0	2	16	0	0	12.0	
i 1	4.000612244897959	0.7575000000000001	74	98	6	2	10	16	0	1	16	0	0	13.0	
i 1	4.001020408163265	1.7675	68	414	2	24	13	0	0	0	0	0	0	14.999999999999998	
i 1	4.001428571428572	0.2525	75	98	5	5	10	2	0	-2	2	0	0	10.0	
i 1	4.003469387755102	0.505	74	912	6	1	11	2	0	-1	2	0	0	2.0	
i 1	4.005102040816326	1.01	75	912	4	5	11	2	0	1	2	0	0	10.0	
i 1	4.008775510204082	0.2525	75	414	4	5	5	8	0	1	8	0	0	10.0	
i 1	4.2424489795918365	0.2525	75	912	6	5	12	2	0	1	2	0	0	10.0	
i 1	4.243265306122449	0.2525	75	912	6	5	2	8	0	-2	8	0	0	10.0	
i 1	4.259591836734693	0.2525	68	912	1	24	4	0	0	-1	0	0	0	14.999999999999998	
i 1	4.493265306122449	1.01	74	912	4	24	7	8	0	-1	8	0	0	3.0	
i 1	4.493265306122449	0.2525	68	912	1	20	9	1	0	0	1	0	0	10.999999999999998	
i 1	4.495306122448979	0.2525	68	912	1	24	13	1	0	0	1	0	0	14.999999999999998	
i 1	4.496530612244898	0.2525	77	414	5	9	9	17	0	1	17	0	0	12.0	
i 1	4.497755102040816	0.2525	68	912	2	24	3	0	0	-1	0	0	0	14.999999999999998	
i 1	4.499387755102041	0.2525	77	98	6	2	6	16	0	1	16	0	0	13.0	
i 1	4.499795918367347	0.505	74	912	4	24	6	8	0	-1	8	0	0	3.0	
i 1	4.499795918367347	2.02	77	912	4	4	8	17	0	1	17	0	0	13.0	
i 1	4.502244897959184	1.01	74	912	5	3	5	16	0	2	16	0	0	13.0	
i 1	4.503469387755102	0.505	75	912	6	5	13	2	0	1	2	0	0	10.0	
i 1	4.505510204081633	0.505	74	912	6	1	3	2	0	-1	2	0	0	2.0	
i 1	4.506734693877551	0.505	74	912	5	3	15	16	0	2	16	0	0	13.0	
i 1	4.99	0.505	74	912	4	24	2	8	0	-1	8	0	0	3.0	
i 1	4.99734693877551	0.505	74	912	5	3	14	16	0	2	16	0	0	13.0	
i 1	4.997755102040816	0.7575000000000001	72	912	4	5	15	2	0	1	2	0	0	10.0	
i 1	4.999387755102041	0.7575000000000001	75	912	6	5	12	8	0	-2	8	0	0	10.0	
i 1	5.000204081632653	5.05	63	414	4	26	12	1	0	1	1	0	0	2.039524715566356	
i 1	5.001836734693877	0.7575000000000001	74	98	7	1	4	8	0	-1	8	0	0	2.0	
i 1	5.002244897959184	1.7675	61	98	6	25	10	16	0	1	16	0	0	2.039524715566356	
i 1	5.003877551020408	0.2525	75	912	3	5	1	2	0	1	2	0	0	10.0	
i 1	5.0042857142857144	1.01	74	414	6	1	2	2	0	-1	2	0	0	2.0	
i 1	5.0075510204081635	0.505	71	414	2	20	8	0	0	-1	0	0	0	10.999999999999998	
i 1	5.24204081632653	0.7575000000000001	74	414	6	1	1	2	0	-1	2	0	0	2.0	
i 1	5.244897959183674	0.505	68	912	2	20	8	1	0	0	1	0	0	10.999999999999998	
i 1	5.2457142857142856	0.2525	75	912	4	5	16	2	0	1	2	0	0	10.0	
i 1	5.248571428571428	0.2525	71	98	3	20	9	0	0	-1	0	0	0	10.999999999999998	
i 1	5.251836734693877	0.2525	68	912	2	24	7	0	0	-1	0	0	0	14.999999999999998	
i 1	5.253877551020408	0.2525	68	98	3	20	4	0	0	-1	0	0	0	10.999999999999998	
i 1	5.2542857142857144	0.505	68	912	2	24	11	1	0	0	1	0	0	14.999999999999998	
i 1	5.259183673469388	0.7575000000000001	74	98	7	1	3	2	0	-2	2	0	0	2.0	
i 1	5.259591836734693	0.505	68	912	2	20	11	0	0	-1	0	0	0	10.999999999999998	
i 1	5.501836734693877	0.505	77	912	4	4	4	17	0	1	17	0	0	13.0	
i 1	5.740408163265307	0.7575000000000001	75	98	5	5	10	2	0	1	2	0	0	10.0	
i 1	5.740816326530612	1.01	71	414	2	20	12	0	0	-1	0	0	0	10.999999999999998	
i 1	5.74204081632653	0.2525	71	98	3	20	1	0	0	-1	0	0	0	10.999999999999998	
i 1	5.744897959183674	0.2525	68	912	2	24	6	0	0	-1	0	0	0	14.999999999999998	
i 1	5.74734693877551	0.7575000000000001	75	414	4	5	16	2	0	-2	2	0	0	10.0	
i 1	5.74734693877551	0.2525	68	98	3	20	15	0	0	-1	0	0	0	10.999999999999998	
i 1	5.99	1.5150000000000001	68	414	2	24	7	0	0	0	0	0	0	14.999999999999998	
i 1	5.996530612244898	0.7575000000000001	71	414	2	20	13	0	0	-1	0	0	0	10.999999999999998	
i 1	5.996530612244898	0.7575000000000001	71	414	2	20	13	1	0	-1	1	0	0	10.999999999999998	
i 1	5.998163265306123	3.7875	63	912	3	27	6	16	0	1	16	0	0	2.379445501494082	
i 1	5.999795918367347	1.01	74	912	4	24	8	8	0	-1	8	0	0	3.0	
i 1	6.000612244897959	0.505	77	912	4	4	14	17	0	1	17	0	0	13.0	
i 1	6.003469387755102	2.2725	74	912	5	1	14	2	0	-1	2	0	0	2.0	
i 1	6.0042857142857144	1.01	71	912	6	1	11	8	0	-1	8	0	0	2.0	
i 1	6.006734693877551	0.7575000000000001	63	98	6	25	7	16	0	1	16	0	0	2.039524715566356	
i 1	6.490816326530612	0.2525	68	912	1	24	8	1	0	0	1	0	0	14.999999999999998	
i 1	6.496530612244898	0.2525	74	98	7	2	16	16	0	1	16	0	0	13.0	
i 1	6.499387755102041	0.2525	68	912	1	20	16	1	0	0	1	0	0	10.999999999999998	
i 1	6.500612244897959	0.2525	77	414	5	9	14	16	0	2	16	0	0	12.0	
i 1	6.501020408163265	0.505	68	912	1	24	16	0	0	-1	0	0	0	14.999999999999998	
i 1	6.5075510204081635	0.2525	68	912	2	20	3	0	0	-1	0	0	0	10.999999999999998	
i 1	6.50795918367347	0.2525	75	98	5	5	7	2	0	-2	2	0	0	10.0	
i 1	6.509591836734693	0.2525	75	414	4	5	10	8	0	1	8	0	0	10.0	
i 1	6.741632653061225	0.2525	68	912	2	24	5	1	0	0	1	0	0	14.999999999999998	
i 1	6.743265306122449	0.2525	74	912	4	3	2	16	0	2	16	0	0	13.0	
i 1	6.7457142857142856	1.2625	63	210	6	25	6	16	0	2	16	0	0	2.039524715566356	
i 1	6.747755102040816	1.01	75	414	4	5	12	2	0	-2	2	0	0	10.0	
i 1	6.748979591836735	0.2525	61	210	6	25	12	1	0	1	1	0	0	2.039524715566356	
i 1	6.750612244897959	0.2525	74	414	6	1	2	2	0	-1	2	0	0	2.0	
i 1	6.751020408163265	0.2525	75	210	5	5	16	2	0	-2	2	0	0	10.0	
i 1	6.751428571428572	0.2525	74	912	5	3	11	16	0	2	16	0	0	13.0	
i 1	6.752244897959184	0.2525	77	912	4	4	9	17	0	1	17	0	0	13.0	
i 1	6.75265306122449	0.2525	72	912	4	5	4	2	0	1	2	0	0	10.0	
i 1	6.7542857142857144	0.2525	74	210	7	1	9	2	0	-2	2	0	0	2.0	
i 1	6.755510204081633	1.2625	71	210	7	1	12	8	0	-2	8	0	0	2.0	
i 1	6.99	0.505	74	210	7	1	3	2	0	-2	2	0	0	2.0	
i 1	6.990408163265307	0.7575000000000001	77	414	5	9	14	16	0	2	16	0	0	12.0	
i 1	6.993265306122449	2.02	68	912	1	20	5	0	0	-1	0	0	0	10.999999999999998	
i 1	6.993673469387755	2.7775	61	912	3	27	16	1	0	2	1	0	0	2.379445501494082	
i 1	6.994897959183674	2.7775	61	210	6	25	10	1	0	1	1	0	0	2.039524715566356	
i 1	6.996530612244898	0.7575000000000001	77	912	4	4	14	17	0	1	17	0	0	13.0	
i 1	6.998163265306123	1.01	74	210	7	2	9	17	0	2	17	0	0	13.0	
i 1	7.001020408163265	1.2625	68	912	1	24	7	1	0	0	1	0	0	14.999999999999998	
i 1	7.003469387755102	0.505	68	414	2	20	10	0	0	-1	0	0	0	10.999999999999998	
i 1	7.0042857142857144	2.02	63	912	5	25	14	1	0	2	1	0	0	2.039524715566356	
i 1	7.005510204081633	0.505	68	414	2	20	3	1	0	0	1	0	0	10.999999999999998	
i 1	7.009183673469388	0.7575000000000001	72	912	6	5	9	2	0	1	2	0	0	10.0	
i 1	7.009183673469388	0.505	71	414	2	20	8	0	0	-1	0	0	0	10.999999999999998	
i 1	7.2424489795918365	1.01	68	912	1	20	14	1	0	0	1	0	0	10.999999999999998	
i 1	7.249387755102041	1.01	68	912	1	24	13	0	0	-1	0	0	0	14.999999999999998	
i 1	7.490816326530612	0.7575000000000001	75	414	4	5	5	8	0	1	8	0	0	10.0	
i 1	7.491224489795918	1.01	74	210	7	2	13	17	0	2	17	0	0	13.0	
i 1	7.498979591836735	0.505	75	210	5	5	9	2	0	-2	2	0	0	10.0	
i 1	7.503469387755102	1.01	74	912	4	3	8	16	0	2	16	0	0	13.0	
i 1	7.504693877551021	0.505	77	414	5	9	6	17	0	1	17	0	0	12.0	
i 1	7.509591836734693	1.5150000000000001	71	912	6	1	2	8	0	-1	8	0	0	2.0	
i 1	7.753469387755102	1.2625	74	912	4	24	2	8	0	-1	8	0	0	3.0	
i 1	7.991224489795918	1.01	75	912	3	5	11	2	0	1	2	0	0	10.0	
i 1	8.001428571428571	0.2525	71	210	7	1	15	8	0	-2	8	0	0	2.0	
i 1	8.00673469387755	1.7675	63	210	6	25	13	16	0	2	16	0	0	2.039524715566356	
i 1	8.008367346938776	1.7675	63	912	5	25	11	1	0	1	1	0	0	2.039524715566356	
i 1	8.008367346938776	1.01	75	210	5	5	16	2	0	-2	2	0	0	10.0	
i 1	8.244081632653062	1.5150000000000001	68	414	2	24	2	0	0	0	0	0	0	14.999999999999998	
i 1	8.255102040816327	1.5150000000000001	77	912	4	4	6	17	0	1	17	0	0	13.0	
i 1	8.257142857142858	0.2525	75	912	4	5	11	2	0	1	2	0	0	10.0	
i 1	8.259183673469387	0.2525	68	912	2	24	16	1	0	0	1	0	0	14.999999999999998	
i 1	8.26	0.2525	68	912	2	20	13	1	0	0	1	0	0	10.999999999999998	
i 1	8.492857142857142	0.7575000000000001	71	414	2	20	5	0	0	-1	0	0	0	10.999999999999998	
i 1	8.493673469387755	1.2625	74	912	5	3	16	16	0	2	16	0	0	13.0	
i 1	8.49530612244898	0.7575000000000001	68	414	2	20	13	1	0	0	1	0	0	10.999999999999998	
i 1	8.496122448979591	1.2625	74	210	7	1	16	2	0	-2	2	0	0	2.0	
i 1	8.496938775510204	1.01	75	912	3	5	13	8	0	-2	8	0	0	10.0	
i 1	8.497755102040816	0.2525	74	210	7	2	4	17	0	2	17	0	0	13.0	
i 1	8.498571428571429	0.505	68	912	1	24	14	1	0	0	1	0	0	14.999999999999998	
i 1	8.499795918367347	0.505	74	912	4	24	2	8	0	-1	8	0	0	3.0	
i 1	8.501020408163265	1.2625	68	414	2	20	14	0	0	-1	0	0	0	10.999999999999998	
i 1	8.503061224489796	0.2525	68	912	1	20	10	1	0	0	1	0	0	10.999999999999998	
i 1	8.507959183673469	0.505	74	414	6	1	10	2	0	-1	2	0	0	2.0	
i 1	8.741224489795918	0.2525	74	210	7	2	14	17	0	2	17	0	0	13.0	
i 1	8.746938775510204	0.7575000000000001	75	912	4	5	7	2	0	1	2	0	0	10.0	
i 1	8.756326530612245	0.2525	74	414	6	1	6	2	0	-1	2	0	0	2.0	
i 1	9.001020408163265	0.2525	75	414	4	5	6	2	0	-2	2	0	0	10.0	
i 1	9.003469387755102	0.505	74	414	6	1	14	2	0	-1	2	0	0	2.0	
i 1	9.005102040816327	2.02	61	414	4	26	15	1	0	1	1	0	0	2.039524715566356	
i 1	9.005918367346938	0.7575000000000001	63	912	5	25	15	1	0	2	1	0	0	2.039524715566356	
i 1	9.24	0.2525	68	912	1	24	9	1	0	0	1	0	0	14.999999999999998	
i 1	9.255510204081633	0.2525	68	912	1	20	8	0	0	-1	0	0	0	10.999999999999998	
i 1	9.491224489795918	0.2525	74	210	7	2	11	17	0	2	17	0	0	13.0	
i 1	9.492857142857142	0.2525	68	414	2	20	4	1	0	0	1	0	0	10.999999999999998	
i 1	9.494897959183673	1.5150000000000001	71	414	2	20	5	0	0	-1	0	0	0	10.999999999999998	
i 1	9.495714285714286	0.2525	77	414	5	9	8	16	0	2	16	0	0	12.0	
i 1	9.496122448979591	0.2525	77	912	4	4	8	17	0	1	17	0	0	13.0	
i 1	9.500204081632653	0.2525	72	912	4	5	13	2	0	1	2	0	0	10.0	
i 1	9.501836734693878	0.2525	75	210	7	5	9	2	0	-2	2	0	0	10.0	
i 1	9.502244897959184	0.505	77	414	5	9	1	17	0	1	17	0	0	12.0	
i 1	9.505102040816327	0.2525	71	210	7	1	15	8	0	-2	8	0	0	2.0	
i 1	9.505510204081633	0.2525	75	414	4	5	10	2	0	-2	2	0	0	10.0	
i 1	9.508367346938776	0.2525	74	912	5	1	14	2	0	-1	2	0	0	2.0	
i 1	9.74	3.7875	63	414	5	25	10	16	0	1	16	0	0	2.039524715566356	
i 1	9.740408163265306	0.2525	74	1116	4	24	13	8	0	-1	8	0	0	3.0	
i 1	9.741632653061224	1.2625	74	414	6	1	10	2	0	-1	2	0	0	2.0	
i 1	9.742448979591837	3.7875	63	414	5	25	10	1	0	1	1	0	0	2.039524715566356	
i 1	9.744489795918367	0.2525	68	414	3	20	5	0	0	-1	0	0	0	10.999999999999998	
i 1	9.744897959183673	3.7875	63	1116	5	25	3	1	0	2	1	0	0	2.039524715566356	
i 1	9.74530612244898	0.505	74	414	6	2	7	17	0	1	17	0	0	13.0	
i 1	9.746938775510204	0.2525	71	800	1	24	3	1	0	-1	1	0	0	14.999999999999998	
i 1	9.748163265306122	0.505	71	800	4	24	9	2	0	-2	2	0	0	3.0	
i 1	9.74938775510204	0.2525	68	414	3	20	16	1	0	0	1	0	0	10.999999999999998	
i 1	9.750204081632653	1.5150000000000001	74	414	6	1	14	2	0	-1	2	0	0	2.0	
i 1	9.751020408163265	0.2525	72	414	5	5	1	2	0	-2	2	0	0	10.0	
i 1	9.751428571428571	0.2525	75	414	6	5	16	8	0	1	8	0	0	10.0	
i 1	9.752244897959184	2.2725	61	800	3	27	7	16	0	2	16	0	0	2.379445501494082	
i 1	9.752653061224489	0.2525	72	1116	4	5	8	8	0	1	8	0	0	10.0	
i 1	9.755918367346938	2.2725	71	414	6	1	1	2	0	-1	2	0	0	2.0	
i 1	9.755918367346938	0.2525	74	800	5	1	16	2	0	-1	2	0	0	2.0	
i 1	9.75673469387755	1.2625	61	800	3	27	10	1	0	1	1	0	0	2.379445501494082	
i 1	9.757959183673469	0.2525	61	1116	5	25	8	1	0	2	1	0	0	2.039524715566356	
i 1	9.758367346938776	0.2525	74	1116	4	4	12	16	0	1	16	0	0	13.0	
i 1	9.991224489795918	0.7575000000000001	68	414	2	24	3	0	0	0	0	0	0	14.999999999999998	
i 1	9.994489795918367	0.7575000000000001	68	414	2	20	11	1	0	0	1	0	0	10.999999999999998	
i 1	9.997755102040816	2.02	63	414	4	26	6	1	0	1	1	0	0	2.039524715566356	
i 1	9.99938775510204	0.7575000000000001	72	414	6	5	10	2	0	-2	2	0	0	10.0	
i 1	10.001020408163265	0.7575000000000001	68	414	1	20	16	0	0	-1	0	0	0	10.999999999999998	
i 1	10.002653061224489	0.7575000000000001	74	1116	5	3	16	16	0	2	16	0	0	13.0	
i 1	10.003469387755102	0.2525	74	1116	4	24	15	8	0	-1	8	0	0	3.0	
i 1	10.00469387755102	1.01	75	414	4	5	16	8	0	1	8	0	0	10.0	
i 1	10.007142857142858	3.535	61	1116	5	25	4	1	0	2	1	0	0	2.039524715566356	
i 1	10.009591836734694	0.7575000000000001	74	800	4	3	8	16	0	1	16	0	0	13.0	
i 1	10.24	1.5150000000000001	74	414	6	2	3	17	0	1	17	0	0	13.0	
i 1	10.242040816326531	0.7575000000000001	72	800	6	5	8	2	0	1	2	0	0	10.0	
i 1	10.246938775510204	0.7575000000000001	75	1116	4	5	10	2	0	1	2	0	0	10.0	
i 1	10.491224489795918	1.2625	77	414	5	9	10	16	0	2	16	0	0	12.0	
i 1	10.492040816326531	0.505	74	1116	4	4	11	16	0	1	16	0	0	13.0	
i 1	10.496530612244898	0.505	77	800	4	4	16	17	0	1	17	0	0	13.0	
i 1	10.75469387755102	0.2525	68	414	2	20	3	0	0	-1	0	0	0	10.999999999999998	
i 1	10.755102040816327	0.2525	71	800	1	24	4	1	0	-1	1	0	0	14.999999999999998	
i 1	10.758775510204082	0.2525	68	414	3	20	2	1	0	0	1	0	0	10.999999999999998	
i 1	10.99	0.2525	71	1116	2	24	14	0	0	0	0	0	0	7.0	
i 1	10.990816326530613	0.505	68	414	2	24	9	0	0	0	0	0	0	7.0	
i 1	10.991224489795918	4.04	61	414	4	26	12	1	0	1	1	0	0	2.039524715566356	
i 1	10.992448979591837	1.01	74	414	6	1	9	2	0	-1	2	0	0	2.0	
i 1	10.99326530612245	1.01	72	800	6	5	3	2	0	1	2	0	0	10.0	
i 1	10.994081632653062	0.2525	68	414	2	20	6	0	0	-1	0	0	0	3.0	
i 1	10.996938775510204	0.2525	71	414	2	20	4	0	0	-1	0	0	0	3.0	
i 1	10.997346938775511	0.7575000000000001	72	800	3	5	3	2	0	1	2	0	0	10.0	
i 1	11.001428571428571	2.02	61	800	3	27	14	1	0	1	1	0	0	2.379445501494082	
i 1	11.002653061224489	0.7575000000000001	75	1116	6	5	8	2	0	1	2	0	0	10.0	
i 1	11.009183673469387	0.2525	74	414	6	1	12	2	0	-1	2	0	0	2.0	
i 1	11.254285714285714	1.01	74	800	6	1	7	2	0	-1	2	0	0	2.0	
i 1	11.257959183673469	0.2525	74	800	4	3	6	16	0	1	16	0	0	13.0	
i 1	11.491632653061224	1.01	75	414	6	5	6	2	0	1	2	0	0	10.0	
i 1	11.491632653061224	0.2525	68	414	1	20	3	1	0	0	1	0	0	3.0	
i 1	11.492040816326531	1.01	77	414	5	9	2	17	0	1	17	0	0	12.0	
i 1	11.495714285714286	1.01	74	414	6	2	11	17	0	1	17	0	0	13.0	
i 1	11.496530612244898	2.02	72	414	6	5	5	2	0	-2	2	0	0	10.0	
i 1	11.497346938775511	0.7575000000000001	71	1116	6	1	16	8	0	-2	8	0	0	2.0	
i 1	11.501428571428571	0.505	72	1116	4	5	3	8	0	1	8	0	0	10.0	
i 1	11.507551020408163	1.01	75	414	4	5	10	2	0	-2	2	0	0	10.0	
i 1	11.509183673469387	1.7675	74	1116	5	3	1	16	0	2	16	0	0	13.0	
i 1	11.74	1.01	68	800	1	24	13	0	0	-1	0	0	0	7.0	
i 1	11.741224489795918	0.2525	71	800	1	20	15	1	0	-1	1	0	0	3.0	
i 1	11.742857142857142	0.7575000000000001	74	1116	4	24	13	8	0	-1	8	0	0	3.0	
i 1	11.747755102040816	1.01	71	800	1	24	11	1	0	-1	1	0	0	7.0	
i 1	11.751836734693878	0.7575000000000001	71	800	4	24	7	2	0	-2	2	0	0	3.0	
i 1	11.755918367346938	1.01	68	800	1	20	16	1	0	-1	1	0	0	3.0	
i 1	11.991224489795918	1.5150000000000001	61	800	3	27	15	16	0	2	16	0	0	2.379445501494082	
i 1	11.998163265306122	3.0300000000000002	63	414	4	26	1	1	0	1	1	0	0	2.039524715566356	
i 1	12.244489795918367	1.7675	68	414	1	20	2	0	0	-1	0	0	0	3.0	
i 1	12.244897959183673	2.2725	74	414	6	1	4	2	0	-1	2	0	0	2.0	
i 1	12.244897959183673	1.7675	68	414	2	24	15	0	0	0	0	0	0	7.0	
i 1	12.245714285714286	1.7675	71	414	2	20	2	0	0	-1	0	0	0	3.0	
i 1	12.246122448979591	1.2625	68	414	1	20	4	1	0	0	1	0	0	3.0	
i 1	12.248571428571429	1.2625	74	414	6	1	6	2	0	-1	2	0	0	2.0	
i 1	12.249795918367347	1.01	74	800	5	3	6	16	0	1	16	0	0	13.0	
i 1	12.490816326530613	0.2525	71	1116	6	1	10	8	0	-2	8	0	0	2.0	
i 1	12.493673469387755	0.2525	75	1116	6	5	8	2	0	1	2	0	0	10.0	
i 1	12.496938775510204	1.5150000000000001	75	414	4	5	10	8	0	1	8	0	0	10.0	
i 1	12.507959183673469	0.2525	74	414	6	2	15	17	0	1	17	0	0	13.0	
i 1	12.746530612244898	0.505	74	1116	4	4	2	16	0	1	16	0	0	13.0	
i 1	12.751836734693878	0.2525	77	800	4	4	2	17	0	1	17	0	0	13.0	
i 1	12.994489795918367	0.505	74	414	6	2	11	17	0	1	17	0	0	13.0	
i 1	12.994489795918367	0.505	75	1116	6	5	8	2	0	1	2	0	0	10.0	
i 1	12.995714285714286	0.505	71	1116	6	1	9	8	0	-2	8	0	0	2.0	
i 1	12.997346938775511	0.505	72	800	3	5	1	2	0	1	2	0	0	10.0	
i 1	12.99938775510204	0.7575000000000001	74	414	6	1	10	2	0	-1	2	0	0	2.0	
i 1	13.001428571428571	0.505	71	414	6	1	1	2	0	-1	2	0	0	2.0	
i 1	13.003877551020409	0.505	61	800	3	27	8	1	0	1	1	0	0	2.379445501494082	
i 1	13.00469387755102	1.7675	77	414	5	9	1	16	0	2	16	0	0	12.0	
i 1	13.246938775510204	0.2525	74	1116	4	24	15	8	0	-1	8	0	0	3.0	
i 1	13.248571428571429	0.2525	68	800	1	20	10	1	0	-1	1	0	0	3.0	
i 1	13.257959183673469	0.2525	75	414	6	5	16	2	0	1	2	0	0	10.0	
i 1	13.490816326530613	1.5150000000000001	63	912	5	25	1	1	0	1	1	0	0	2.039524715566356	
i 1	13.492857142857142	1.2625	74	912	4	4	15	17	0	1	17	0	0	13.0	
i 1	13.493673469387755	0.505	61	912	3	27	8	16	0	2	16	0	0	2.379445501494082	
i 1	13.494489795918367	0.505	77	912	4	4	7	17	0	1	17	0	0	13.0	
i 1	13.494897959183673	1.01	72	98	7	5	11	2	0	-2	2	0	0	10.0	
i 1	13.496122448979591	1.01	74	912	4	24	14	8	0	-2	8	0	0	3.0	
i 1	13.496530612244898	1.5150000000000001	63	98	6	25	10	16	0	2	16	0	0	2.039524715566356	
i 1	13.497346938775511	1.5150000000000001	63	912	5	25	1	16	0	2	16	0	0	2.039524715566356	
i 1	13.498163265306122	1.5150000000000001	63	912	3	27	7	1	0	1	1	0	0	2.379445501494082	
i 1	13.498979591836735	0.2525	74	912	6	1	13	2	0	-2	2	0	0	2.0	
i 1	13.500204081632653	0.2525	74	98	6	2	9	17	0	2	17	0	0	13.0	
i 1	13.501020408163265	0.505	74	912	5	3	7	16	0	1	16	0	0	13.0	
i 1	13.502244897959184	0.2525	75	912	6	5	13	8	0	1	8	0	0	10.0	
i 1	13.505510204081633	0.2525	71	912	1	20	12	1	0	-1	1	0	0	3.0	
i 1	13.50673469387755	1.5150000000000001	61	98	6	25	8	1	0	1	1	0	0	2.039524715566356	
i 1	13.507959183673469	0.2525	71	98	7	1	15	8	0	-1	8	0	0	2.0	
i 1	13.742040816326531	1.5150000000000001	71	912	1	24	13	0	0	0	0	0	0	7.0	
i 1	13.746530612244898	0.7575000000000001	68	414	1	20	5	1	0	0	1	0	0	3.0	
i 1	13.993673469387755	0.2525	71	98	7	1	1	8	0	-1	8	0	0	2.0	
i 1	13.993673469387755	1.01	75	912	3	5	16	2	0	-2	2	0	0	10.0	
i 1	13.994081632653062	1.01	75	912	6	5	14	8	0	-2	8	0	0	10.0	
i 1	13.996938775510204	0.505	75	414	6	5	11	8	0	1	8	0	0	10.0	
i 1	13.997755102040816	1.7675	74	98	6	2	3	17	0	2	17	0	0	13.0	
i 1	13.998163265306122	1.01	72	98	7	5	9	2	0	-2	2	0	0	10.0	
i 1	13.999795918367347	1.01	61	912	3	27	6	16	0	2	16	0	0	2.379445501494082	
i 1	14.240408163265306	1.5150000000000001	71	912	1	20	9	1	0	-1	1	0	0	3.0	
i 1	14.24326530612245	1.5150000000000001	77	414	5	9	5	17	0	1	17	0	0	12.0	
i 1	14.244489795918367	1.2625	74	98	7	1	1	2	0	-2	2	0	0	2.0	
i 1	14.25673469387755	0.2525	68	414	1	20	3	0	0	-1	0	0	0	3.0	
i 1	14.258367346938776	0.2525	71	414	2	20	7	0	0	-1	0	0	0	3.0	
i 1	14.258775510204082	1.2625	74	414	6	1	10	2	0	-1	2	0	0	2.0	
i 1	14.500204081632653	0.505	71	912	1	20	9	1	0	-1	1	0	0	3.0	
i 1	14.50061224489796	0.505	71	912	1	24	3	0	0	0	0	0	0	7.0	
i 1	14.503469387755102	0.2525	74	912	6	1	3	2	0	-2	2	0	0	2.0	
i 1	14.751020408163265	1.5150000000000001	68	414	1	24	9	0	0	0	0	0	0	7.0	
i 1	14.758775510204082	0.2525	74	912	5	3	2	16	0	1	16	0	0	13.0	
i 1	14.991224489795918	0.7575000000000001	72	912	3	5	7	2	0	1	2	0	0	7.532821849970688	
i 1	14.991632653061224	1.01	61	98	6	25	1	1	0	1	1	0	0	3.3992078592772597	
i 1	14.992857142857142	3.0300000000000002	63	912	5	25	16	16	0	2	16	0	0	3.3992078592772597	
i 1	14.993673469387755	0.505	75	912	6	5	6	2	0	-2	2	0	0	7.532821849970688	
i 1	14.994897959183673	0.2525	68	414	1	20	13	1	0	0	1	0	0	3.0	
i 1	14.99530612244898	0.505	72	98	7	5	1	2	0	-2	2	0	0	7.532821849970688	
i 1	14.997755102040816	5.3025	63	414	4	26	15	1	0	1	1	0	0	3.3992078592772597	
i 1	14.998163265306122	2.02	63	98	6	25	12	16	0	2	16	0	0	3.3992078592772597	
i 1	14.998979591836735	0.7575000000000001	75	912	6	5	11	8	0	-2	8	0	0	7.532821849970688	
i 1	14.99938775510204	0.7575000000000001	71	912	5	1	16	8	0	-2	8	0	0	2.0	
i 1	15.002653061224489	4.04	63	912	5	25	10	1	0	1	1	0	0	3.3992078592772597	
i 1	15.003469387755102	3.0300000000000002	61	912	3	27	16	16	0	2	16	0	0	3.739128645204986	
i 1	15.003877551020409	0.7575000000000001	71	98	7	1	13	8	0	-1	8	0	0	2.0	
i 1	15.007142857142858	0.2525	74	912	4	4	11	17	0	1	17	0	0	13.0	
i 1	15.009591836734694	5.05	61	414	4	26	2	1	0	1	1	0	0	3.3992078592772597	
i 1	15.009591836734694	3.0300000000000002	63	912	3	27	8	1	0	1	1	0	0	3.739128645204986	
i 1	15.24	1.01	75	414	6	5	7	2	0	-2	2	0	0	7.532821849970688	
i 1	15.241632653061224	1.01	74	98	6	2	13	16	0	2	16	0	0	13.0	
i 1	15.242040816326531	0.7575000000000001	74	912	6	1	14	2	0	-2	2	0	0	2.0	
i 1	15.242040816326531	1.01	74	912	5	3	7	17	0	2	17	0	0	13.0	
i 1	15.24326530612245	1.7675	74	912	4	24	11	8	0	-2	8	0	0	3.0	
i 1	15.248979591836735	0.505	71	912	1	24	7	0	0	0	0	0	0	7.0	
i 1	15.25061224489796	1.01	71	912	4	24	11	8	0	-1	8	0	0	3.0	
i 1	15.253877551020409	1.01	75	912	6	5	8	8	0	1	8	0	0	7.532821849970688	
i 1	15.254285714285714	5.05	71	414	1	20	5	0	0	-1	0	0	0	3.0	
i 1	15.255918367346938	0.505	68	98	2	20	5	0	0	-1	0	0	0	3.0	
i 1	15.257142857142858	0.505	68	98	2	20	4	1	0	0	1	0	0	3.0	
i 1	15.508775510204082	0.505	71	912	1	24	15	0	0	0	0	0	0	7.0	
i 1	15.74	0.2525	68	414	1	20	11	1	0	0	1	0	0	3.0	
i 1	15.744897959183673	1.2625	74	414	6	1	15	2	0	-1	2	0	0	2.0	
i 1	15.75061224489796	0.7575000000000001	74	912	5	3	4	16	0	1	16	0	0	13.0	
i 1	15.752653061224489	0.2525	71	414	1	20	8	1	0	-1	1	0	0	3.0	
i 1	15.757551020408163	0.7575000000000001	77	912	4	4	15	17	0	1	17	0	0	13.0	
i 1	15.757551020408163	0.2525	72	98	7	5	16	2	0	-2	2	0	0	7.532821849970688	
i 1	15.991224489795918	1.01	74	912	4	4	6	17	0	1	17	0	0	13.0	
i 1	15.996122448979591	1.01	74	98	6	2	9	17	0	2	17	0	0	13.0	
i 1	15.997755102040816	0.2525	71	98	2	20	2	1	0	-1	1	0	0	3.0	
i 1	16.001020408163264	1.2625	77	414	5	9	8	16	0	2	16	0	0	12.0	
i 1	16.001428571428573	1.2625	75	414	6	5	5	8	0	1	8	0	0	7.532821849970688	
i 1	16.00387755102041	1.2625	72	98	7	5	12	2	0	-2	2	0	0	7.532821849970688	
i 1	16.007142857142856	0.2525	74	912	6	1	16	2	0	-2	2	0	0	2.0	
i 1	16.009183673469387	0.2525	71	98	2	20	14	1	0	-1	1	0	0	3.0	
i 1	16.259183673469387	0.2525	75	912	6	5	1	8	0	-2	8	0	0	7.532821849970688	
i 1	16.49204081632653	0.2525	72	912	6	5	13	2	0	1	2	0	0	7.532821849970688	
i 1	16.49408163265306	0.505	77	414	5	9	13	17	0	1	17	0	0	12.0	
i 1	16.494897959183675	0.2525	68	98	2	20	9	0	0	0	0	0	0	3.0	
i 1	16.498163265306122	0.7575000000000001	74	414	6	1	5	2	0	-1	2	0	0	2.0	
i 1	16.50673469387755	0.2525	68	98	2	20	7	0	0	-1	0	0	0	3.0	
i 1	16.50795918367347	0.505	68	414	1	24	10	0	0	0	0	0	0	7.0	
i 1	16.509183673469387	0.505	74	98	7	1	14	2	0	-2	2	0	0	2.0	
i 1	16.74326530612245	1.2625	71	98	7	1	5	8	0	-1	8	0	0	2.0	
i 1	16.744489795918366	1.2625	71	912	5	1	6	8	0	-2	8	0	0	2.0	
i 1	16.748163265306122	1.2625	74	98	6	2	8	16	0	2	16	0	0	13.0	
i 1	16.748571428571427	0.2525	72	98	7	5	16	2	0	-2	2	0	0	7.532821849970688	
i 1	16.751020408163264	0.2525	71	912	1	20	2	1	0	-1	1	0	0	3.0	
i 1	16.75265306122449	0.505	68	414	1	20	14	1	0	-1	1	0	0	3.0	
i 1	16.753469387755104	1.2625	74	912	5	3	5	17	0	2	17	0	0	13.0	
i 1	16.757142857142856	1.2625	75	912	6	5	5	2	0	-2	2	0	0	7.532821849970688	
i 1	16.759591836734693	1.2625	71	414	1	20	1	1	0	-1	1	0	0	3.0	
i 1	16.99	1.01	72	98	7	5	16	2	0	-2	2	0	0	7.532821849970688	
i 1	17.005510204081634	0.2525	74	98	5	1	1	2	0	-2	2	0	0	2.0	
i 1	17.240408163265307	0.7575000000000001	72	912	6	5	8	2	0	1	2	0	0	7.532821849970688	
i 1	17.251836734693878	0.2525	74	912	4	24	13	8	0	-2	8	0	0	3.0	
i 1	17.253469387755104	0.2525	77	414	5	9	6	17	0	1	17	0	0	12.0	
i 1	17.498979591836736	0.505	75	912	6	5	9	8	0	-2	8	0	0	7.532821849970688	
i 1	17.50387755102041	0.7575000000000001	74	912	5	3	7	16	0	1	16	0	0	13.0	
i 1	17.50591836734694	0.505	77	912	4	4	1	17	0	1	17	0	0	13.0	
i 1	17.509591836734693	0.505	72	98	7	5	10	2	0	-2	2	0	0	7.532821849970688	
i 1	17.74	1.2625	74	912	4	24	11	8	0	-2	8	0	0	3.0	
i 1	17.75469387755102	1.01	68	414	1	24	16	0	0	0	0	0	0	7.0	
i 1	17.757142857142856	0.2525	74	98	5	1	11	2	0	-2	2	0	0	2.0	
i 1	17.758367346938776	1.01	74	912	4	4	15	17	0	1	17	0	0	13.0	
i 1	17.759591836734693	1.5150000000000001	75	414	6	5	2	2	0	-2	2	0	0	7.532821849970688	
i 1	17.990408163265307	0.2525	71	912	4	1	16	8	0	-1	8	0	0	2.0	
i 1	17.99244897959184	0.7575000000000001	77	596	4	4	15	16	0	2	16	0	0	13.0	
i 1	17.99612244897959	1.2625	72	912	6	5	16	2	0	1	2	0	0	7.532821849970688	
i 1	17.998571428571427	0.2525	71	596	5	1	10	8	0	-2	8	0	0	2.0	
i 1	18.001020408163264	0.2525	75	596	6	5	9	2	0	1	2	0	0	7.532821849970688	
i 1	18.00469387755102	0.2525	75	912	6	5	3	8	0	-2	8	0	0	7.532821849970688	
i 1	18.00755102040816	1.2625	74	912	5	1	1	8	0	-1	8	0	0	2.0	
i 1	18.00795918367347	1.01	71	596	4	24	11	8	0	-2	8	0	0	3.0	
i 1	18.008367346938776	4.04	63	596	3	27	10	1	0	2	1	0	0	3.739128645204986	
i 1	18.008367346938776	5.05	63	596	3	27	9	16	0	1	16	0	0	3.739128645204986	
i 1	18.00877551020408	0.505	68	912	1	20	6	0	0	-1	0	0	0	3.0	
i 1	18.009591836734693	1.01	77	912	5	2	11	16	0	2	16	0	0	13.0	
i 1	18.25469387755102	0.2525	75	596	6	5	1	2	0	-2	2	0	0	7.532821849970688	
i 1	18.26	0.7575000000000001	77	414	5	9	8	17	0	1	17	0	0	12.0	
i 1	18.49122448979592	1.01	74	912	5	3	12	16	0	1	16	0	0	13.0	
i 1	18.49408163265306	1.01	77	596	4	3	6	16	0	1	16	0	0	13.0	
i 1	18.496530612244896	1.7675	68	414	1	20	9	0	0	-1	0	0	0	3.0	
i 1	18.74612244897959	0.2525	72	912	6	5	13	2	0	-2	2	0	0	7.532821849970688	
i 1	18.748979591836736	0.2525	71	912	4	1	9	8	0	-1	8	0	0	2.0	
i 1	18.754285714285714	0.2525	74	414	6	1	10	2	0	-1	2	0	0	2.0	
i 1	18.755510204081634	0.505	74	414	6	1	14	2	0	-1	2	0	0	2.0	
i 1	18.758367346938776	1.01	75	414	6	5	16	8	0	1	8	0	0	7.532821849970688	
i 1	18.99326530612245	0.505	72	912	6	5	15	2	0	-2	2	0	0	7.532821849970688	
i 1	18.995714285714286	0.7575000000000001	77	596	4	4	4	16	0	2	16	0	0	13.0	
i 1	18.99612244897959	0.7575000000000001	71	912	5	1	8	8	0	-1	8	0	0	2.0	
i 1	19.002244897959184	0.7575000000000001	74	414	6	1	9	2	0	-1	2	0	0	2.0	
i 1	19.003061224489795	0.7575000000000001	71	414	1	20	8	1	0	-1	1	0	0	3.0	
i 1	19.00591836734694	0.7575000000000001	74	912	4	4	11	17	0	1	17	0	0	13.0	
i 1	19.00591836734694	1.01	75	912	6	5	9	8	0	-2	8	0	0	7.532821849970688	
i 1	19.00591836734694	1.2625	75	596	6	5	13	2	0	-2	2	0	0	7.532821849970688	
i 1	19.244489795918366	1.01	77	414	5	9	5	16	0	2	16	0	0	12.0	
i 1	19.244897959183675	1.2625	74	912	5	2	6	16	0	1	16	0	0	13.0	
i 1	19.253061224489795	0.7575000000000001	74	912	4	1	11	2	0	-2	2	0	0	2.0	
i 1	19.258367346938776	0.7575000000000001	71	596	5	1	1	8	0	-2	8	0	0	2.0	
i 1	19.74	1.2625	75	596	6	5	7	2	0	1	2	0	0	7.532821849970688	
i 1	19.74612244897959	1.2625	75	912	6	5	7	8	0	1	8	0	0	7.532821849970688	
i 1	19.752244897959184	0.2525	77	596	4	3	12	16	0	1	16	0	0	13.0	
i 1	19.753469387755104	2.02	72	912	6	5	14	2	0	1	2	0	0	7.532821849970688	
i 1	19.75387755102041	0.2525	74	912	5	1	2	8	0	-1	8	0	0	2.0	
i 1	19.990816326530613	0.7575000000000001	71	596	4	24	3	8	0	-2	8	0	0	3.0	
i 1	19.991632653061224	0.505	74	912	5	1	8	2	0	-2	2	0	0	2.0	
i 1	19.99244897959184	0.2525	77	414	5	9	8	17	0	1	17	0	0	12.0	
i 1	19.99530612244898	0.2525	75	912	6	5	6	8	0	-2	8	0	0	7.532821849970688	
i 1	19.996530612244896	0.7575000000000001	74	912	4	24	14	8	0	-2	8	0	0	3.0	
i 1	19.996938775510205	1.5150000000000001	77	912	5	2	7	16	0	2	16	0	0	13.0	
i 1	20.000612244897958	2.02	74	912	5	3	16	16	0	1	16	0	0	13.0	
i 1	20.002244897959184	0.2525	68	414	1	24	3	0	0	0	0	0	0	7.0	
i 1	20.003061224489795	0.2525	71	414	1	20	4	1	0	-1	1	0	0	3.0	
i 1	20.004285714285714	0.505	71	596	6	1	14	8	0	-2	8	0	0	2.0	
i 1	20.24204081632653	0.7575000000000001	71	210	1	24	9	0	0	-1	0	0	0	7.0	
i 1	20.242857142857144	2.525	71	912	5	1	7	8	0	-1	8	0	0	2.0	
i 1	20.248571428571427	0.2525	74	210	5	9	8	16	0	2	16	0	0	12.0	
i 1	20.248979591836736	0.7575000000000001	71	210	1	20	12	1	0	0	1	0	0	3.0	
i 1	20.250204081632653	1.5150000000000001	74	912	5	1	12	8	0	-1	8	0	0	2.0	
i 1	20.250612244897958	0.2525	71	210	1	20	4	0	0	0	0	0	0	3.0	
i 1	20.251020408163264	1.2625	74	210	5	9	3	16	0	1	16	0	0	12.0	
i 1	20.255102040816325	0.2525	68	210	1	20	15	1	0	0	1	0	0	3.0	
i 1	20.257142857142856	0.7575000000000001	61	210	5	26	14	16	0	1	16	0	0	3.3992078592772597	
i 1	20.25877551020408	0.7575000000000001	71	210	7	1	14	8	0	-1	8	0	0	2.0	
i 1	20.499795918367347	1.5150000000000001	72	210	7	5	15	2	0	1	2	0	0	7.532821849970688	
i 1	20.749795918367347	0.2525	68	210	1	20	13	1	0	0	1	0	0	3.0	
i 1	20.75469387755102	0.2525	68	210	1	20	6	0	0	-1	0	0	0	3.0	
i 1	20.994897959183675	1.01	77	596	4	3	3	16	0	1	16	0	0	13.0	
i 1	20.99612244897959	1.01	71	210	1	24	12	0	0	-1	0	0	0	4.000000000000001	
i 1	21.003061224489795	1.7675	72	912	6	5	11	2	0	-2	2	0	0	7.532821849970688	
i 1	21.00795918367347	0.7575000000000001	71	210	4	1	11	8	0	-1	8	0	0	2.0	
i 1	21.241632653061224	0.7575000000000001	71	210	7	1	14	2	0	-1	2	0	0	2.0	
i 1	21.26	1.2625	75	210	7	5	5	2	0	1	2	0	0	7.532821849970688	
i 1	21.502244897959184	1.7675	74	912	4	4	4	17	0	1	17	0	0	13.0	
i 1	21.50469387755102	1.2625	77	596	4	4	9	16	0	2	16	0	0	13.0	
i 1	21.75387755102041	1.5150000000000001	74	912	4	24	11	8	0	-2	8	0	0	3.0	
i 1	21.993673469387755	2.525	74	210	5	9	5	16	0	1	16	0	0	12.0	
i 1	21.99408163265306	0.7575000000000001	68	210	1	20	13	1	0	0	1	0	0	11.0	
i 1	21.994897959183675	1.2625	75	912	6	5	5	8	0	-2	8	0	0	7.532821849970688	
i 1	21.999795918367347	0.7575000000000001	71	210	4	1	1	2	0	-1	2	0	0	2.0	
i 1	22.002244897959184	5.05	71	210	1	24	10	0	0	-1	0	0	0	15.0	
i 1	22.005510204081634	5.05	71	210	1	20	2	1	0	0	1	0	0	11.0	
i 1	22.00591836734694	0.7575000000000001	68	210	1	20	4	0	0	-1	0	0	0	11.0	
i 1	22.00877551020408	1.2625	75	596	6	5	12	2	0	-2	2	0	0	7.532821849970688	
i 1	22.253469387755104	1.01	71	596	4	24	12	8	0	-2	8	0	0	3.0	
i 1	22.25387755102041	0.7575000000000001	77	912	6	2	1	16	0	2	16	0	0	13.0	
i 1	22.50591836734694	0.505	74	912	5	3	5	16	0	1	16	0	0	13.0	
i 1	22.50673469387755	0.7575000000000001	77	596	4	3	14	16	0	1	16	0	0	13.0	
i 1	22.740408163265307	3.7875	71	210	5	1	16	8	0	-1	8	0	0	2.0	
i 1	22.747755102040816	0.2525	72	210	7	5	4	2	0	1	2	0	0	7.532821849970688	
i 1	22.749795918367347	0.505	71	912	1	20	7	0	0	0	0	0	0	11.0	
i 1	22.751836734693878	0.505	74	912	5	1	4	8	0	-1	8	0	0	2.0	
i 1	22.752244897959184	0.505	71	912	1	20	5	1	0	-1	1	0	0	11.0	
i 1	22.759183673469387	0.505	68	912	1	20	16	0	0	0	0	0	0	11.0	
i 1	22.99408163265306	0.2525	74	912	6	2	4	16	0	1	16	0	0	13.0	
i 1	22.994897959183675	0.2525	72	912	6	5	5	2	0	-2	2	0	0	7.532821849970688	
i 1	22.99530612244898	0.7575000000000001	75	210	7	5	6	2	0	1	2	0	0	7.532821849970688	
i 1	22.996530612244896	0.2525	74	912	5	1	16	2	0	-2	2	0	0	2.0	
i 1	23.001428571428573	0.2525	72	912	6	5	16	2	0	1	2	0	0	7.532821849970688	
i 1	23.003061224489795	0.2525	74	912	5	3	4	16	0	1	16	0	0	13.0	
i 1	23.24204081632653	0.505	77	708	5	3	12	17	0	1	17	0	0	13.0	
i 1	23.24244897959184	1.5150000000000001	71	708	4	24	5	8	0	-1	8	0	0	3.0	
i 1	23.24244897959184	0.2525	77	708	4	3	8	17	0	2	17	0	0	13.0	
i 1	23.24244897959184	1.2625	75	1094	6	5	13	2	0	1	2	0	0	7.532821849970688	
i 1	23.24244897959184	0.7575000000000001	72	708	6	5	11	2	0	-2	2	0	0	7.532821849970688	
i 1	23.24244897959184	0.7575000000000001	68	210	1	20	15	0	0	-1	0	0	0	11.0	
i 1	23.242857142857144	0.7575000000000001	74	1094	6	2	16	17	0	2	17	0	0	13.0	
i 1	23.249387755102042	0.2525	74	1094	5	1	14	8	0	-2	8	0	0	2.0	
i 1	23.250612244897958	0.2525	75	708	6	5	3	2	0	1	2	0	0	7.532821849970688	
i 1	23.251836734693878	0.505	71	708	5	1	4	2	0	-1	2	0	0	2.0	
i 1	23.253061224489795	0.2525	74	708	4	4	10	16	0	1	16	0	0	13.0	
i 1	23.256326530612245	0.7575000000000001	71	210	1	20	7	1	0	0	1	0	0	11.0	
i 1	23.25877551020408	0.505	71	708	4	24	2	2	0	-1	2	0	0	3.0	
i 1	23.259591836734693	0.7575000000000001	75	1094	6	5	16	2	0	1	2	0	0	7.532821849970688	
i 1	23.74612244897959	0.2525	71	210	5	1	5	2	0	-1	2	0	0	2.0	
i 1	23.749795918367347	1.2625	74	1094	6	2	6	17	0	2	17	0	0	13.0	
i 1	23.99204081632653	1.01	72	708	6	5	7	2	0	-2	2	0	0	7.532821849970688	
i 1	23.996938775510205	0.505	74	1094	5	2	4	17	0	2	17	0	0	13.0	
i 1	23.998163265306122	0.505	72	708	6	5	13	2	0	-2	2	0	0	7.532821849970688	
i 1	23.998979591836736	1.01	77	708	4	3	9	17	0	2	17	0	0	13.0	
i 1	24.000612244897958	0.2525	71	708	3	24	5	2	0	-1	2	0	0	3.0	
i 1	24.001836734693878	0.2525	68	1094	1	20	16	0	0	-1	0	0	0	11.0	
i 1	24.002244897959184	0.2525	68	1094	1	20	6	1	0	0	1	0	0	11.0	
i 1	24.007142857142856	0.7575000000000001	75	708	6	5	15	2	0	1	2	0	0	7.532821849970688	
i 1	24.24122448979592	0.7575000000000001	71	210	5	1	2	2	0	-1	2	0	0	2.0	
i 1	24.248163265306122	0.2525	68	210	1	20	4	1	0	0	1	0	0	11.0	
i 1	24.248571428571427	0.2525	68	210	1	20	8	0	0	0	0	0	0	11.0	
i 1	24.25265306122449	2.2725	74	1094	5	1	13	8	0	-2	8	0	0	2.0	
i 1	24.49326530612245	0.2525	74	708	4	4	4	16	0	1	16	0	0	13.0	
i 1	24.49408163265306	1.2625	74	708	4	4	6	16	0	2	16	0	0	13.0	
i 1	24.498571428571427	1.2625	72	210	7	5	3	2	0	1	2	0	0	7.532821849970688	
i 1	24.501020408163264	0.2525	71	1094	1	20	3	1	0	-1	1	0	0	11.0	
i 1	24.501428571428573	0.505	75	1094	6	5	8	2	0	1	2	0	0	7.532821849970688	
i 1	24.50755102040816	0.2525	71	1094	1	20	12	0	0	0	0	0	0	11.0	
i 1	24.742857142857144	0.2525	71	708	3	24	9	2	0	-1	2	0	0	3.0	
i 1	24.744897959183675	0.2525	72	596	6	5	7	8	0	1	8	0	0	7.532821849970688	
i 1	24.744897959183675	1.01	71	210	1	20	5	0	0	0	0	0	0	11.0	
i 1	24.753061224489795	1.01	74	596	4	24	2	8	0	-2	8	0	0	3.0	
i 1	24.754285714285714	1.01	68	210	1	20	15	1	0	-1	1	0	0	11.0	
i 1	24.75469387755102	1.01	74	596	4	4	10	16	0	1	16	0	0	13.0	
i 1	24.99244897959184	0.7575000000000001	75	1094	6	5	11	2	0	1	2	0	0	7.532821849970688	
i 1	25.001836734693878	1.01	71	708	4	24	14	2	0	-1	2	0	0	3.0	
i 1	25.002244897959184	0.2525	74	210	6	9	13	16	0	2	16	0	0	12.0	
i 1	25.009591836734693	1.5150000000000001	75	210	7	5	5	2	0	1	2	0	0	7.532821849970688	
i 1	25.24408163265306	1.7675	72	596	6	5	9	8	0	1	8	0	0	7.532821849970688	
i 1	25.244489795918366	0.7575000000000001	74	1094	5	2	4	17	0	2	17	0	0	13.0	
i 1	25.253061224489795	0.7575000000000001	75	1094	6	5	10	2	0	1	2	0	0	7.532821849970688	
i 1	25.255510204081634	0.7575000000000001	74	210	5	9	7	16	0	1	16	0	0	12.0	
i 1	25.494489795918366	1.5150000000000001	77	708	4	3	12	17	0	2	17	0	0	13.0	
i 1	25.50877551020408	0.505	77	596	5	3	14	17	0	1	17	0	0	13.0	
i 1	25.74326530612245	0.2525	68	1094	1	20	6	0	0	0	0	0	0	11.0	
i 1	25.749387755102042	0.2525	71	1094	1	20	11	0	0	0	0	0	0	11.0	
i 1	25.758367346938776	0.2525	71	596	1	20	2	0	0	-1	0	0	0	11.0	
i 1	25.990816326530613	0.2525	71	210	1	20	14	0	0	0	0	0	0	11.0	
i 1	25.994489795918366	0.505	75	1094	6	5	3	2	0	1	2	0	0	7.532821849970688	
i 1	25.99612244897959	1.01	71	210	5	1	15	2	0	-1	2	0	0	2.0	
i 1	25.998571428571427	1.01	72	708	6	5	8	2	0	-2	2	0	0	7.532821849970688	
i 1	25.998979591836736	0.2525	74	210	6	9	6	16	0	2	16	0	0	12.0	
i 1	26.00591836734694	0.2525	68	210	1	20	10	1	0	-1	1	0	0	11.0	
i 1	26.00673469387755	0.7575000000000001	77	596	5	3	4	17	0	1	17	0	0	13.0	
i 1	26.008367346938776	0.7575000000000001	71	1094	5	1	6	2	0	-1	2	0	0	2.0	
i 1	26.245714285714286	0.7575000000000001	74	596	5	1	15	8	0	-1	8	0	0	2.0	
i 1	26.247755102040816	0.7575000000000001	74	708	4	4	16	16	0	2	16	0	0	13.0	
i 1	26.248163265306122	0.7575000000000001	74	708	4	1	14	2	0	-2	2	0	0	2.0	
i 1	26.248571428571427	0.7575000000000001	74	596	4	4	8	16	0	1	16	0	0	13.0	
i 1	26.506326530612245	0.2525	72	596	6	5	8	2	0	1	2	0	0	7.532821849970688	
i 1	26.745714285714286	0.2525	74	1094	5	1	15	8	0	-2	8	0	0	2.0	
i 1	26.745714285714286	0.2525	75	210	7	5	16	2	0	1	2	0	0	7.532821849970688	
i 1	26.75265306122449	0.2525	74	1094	5	2	14	17	0	2	17	0	0	13.0	
i 1	26.753061224489795	0.2525	68	1094	1	20	6	1	0	0	1	0	0	11.0	
i 1	26.75469387755102	0.2525	68	1094	1	20	9	1	0	0	1	0	0	11.0	
i 1	26.755510204081634	0.2525	68	596	1	20	11	1	0	0	1	0	0	11.0	
i 1	26.75755102040816	0.2525	68	596	1	24	8	0	0	-1	0	0	0	15.0	
i 1	26.759183673469387	0.2525	75	1094	6	5	2	2	0	1	2	0	0	7.532821849970688	
i 1	26.99204081632653	0.2525	74	417	4	4	11	17	0	1	17	0	0	13.0	
i 1	26.99204081632653	1.2625	75	101	7	5	2	2	0	1	2	0	0	7.532821849970688	
i 1	26.994897959183675	1.7675	71	101	6	1	12	2	0	-1	2	0	0	2.0	
i 1	26.99734693877551	0.2525	71	417	5	1	14	2	0	-1	2	0	0	2.0	
i 1	26.998571428571427	1.7675	71	915	4	1	16	8	0	-1	8	0	0	2.0	
i 1	26.999387755102042	0.505	75	915	6	5	8	8	0	-2	8	0	0	7.532821849970688	
i 1	27.00591836734694	0.2525	72	417	6	5	6	2	0	1	2	0	0	7.532821849970688	
i 1	27.00591836734694	1.2625	75	915	6	5	13	2	0	1	2	0	0	7.532821849970688	
i 1	27.006326530612245	0.2525	77	915	4	4	9	16	0	1	16	0	0	13.0	
i 1	27.00673469387755	1.01	77	915	5	3	14	17	0	2	17	0	0	13.0	
i 1	27.00755102040816	1.01	74	101	6	2	11	16	0	2	16	0	0	13.0	
i 1	27.00877551020408	0.2525	74	915	4	1	16	8	0	-2	8	0	0	2.0	
i 1	27.009183673469387	0.505	75	101	7	5	4	8	0	-2	8	0	0	7.532821849970688	
i 1	27.246530612244896	0.2525	77	915	5	9	11	17	0	1	17	0	0	12.0	
i 1	27.256326530612245	0.2525	71	417	4	24	13	8	0	-1	8	0	0	3.0	
i 1	27.49122448979592	0.505	72	417	6	5	5	2	0	-2	2	0	0	7.532821849970688	
i 1	27.492857142857144	0.505	77	915	4	4	4	16	0	1	16	0	0	13.0	
i 1	27.493673469387755	0.7575000000000001	74	101	6	1	7	8	0	-1	8	0	0	2.0	
i 1	27.495714285714286	0.7575000000000001	77	417	5	3	3	17	0	2	17	0	0	13.0	
i 1	27.503061224489795	0.7575000000000001	74	915	4	1	15	8	0	-2	8	0	0	2.0	
i 1	27.74408163265306	0.2525	77	915	5	9	14	17	0	1	17	0	0	12.0	
i 1	27.74612244897959	1.2625	72	915	6	5	12	2	0	1	2	0	0	7.532821849970688	
i 1	27.748163265306122	1.2625	72	417	6	5	11	2	0	1	2	0	0	7.532821849970688	
i 1	27.755510204081634	1.2625	74	417	4	4	6	17	0	1	17	0	0	13.0	
i 1	28.000204081632653	0.2525	77	915	4	4	5	16	0	1	16	0	0	13.0	
i 1	28.006326530612245	1.01	77	915	4	9	7	17	0	1	17	0	0	12.0	
i 1	28.007142857142856	1.7675	72	417	6	5	16	2	0	-2	2	0	0	7.532821849970688	
i 1	28.24408163265306	1.2625	71	417	4	24	12	8	0	-1	8	0	0	3.0	
i 1	28.248979591836736	0.2525	77	915	5	9	16	17	0	1	17	0	0	12.0	
i 1	28.252244897959184	1.2625	71	915	4	1	16	2	0	-2	2	0	0	2.0	
i 1	28.49244897959184	0.505	74	101	6	2	5	16	0	2	16	0	0	13.0	
i 1	28.49612244897959	1.2625	77	915	5	3	7	17	0	2	17	0	0	13.0	
i 1	28.496530612244896	1.5150000000000001	77	417	5	3	15	17	0	2	17	0	0	13.0	
i 1	28.504285714285714	0.505	75	915	6	5	6	2	0	1	2	0	0	7.532821849970688	
i 1	28.76	1.2625	74	101	6	1	6	8	0	-1	8	0	0	2.0	
i 1	28.995714285714286	0.2525	71	101	2	20	13	1	0	0	1	0	0	11.0	
i 1	28.995714285714286	0.2525	71	101	2	20	14	0	0	-1	0	0	0	11.0	
i 1	28.998571428571427	0.7575000000000001	71	915	4	1	3	8	0	-1	8	0	0	2.0	
i 1	28.998571428571427	1.01	75	915	5	5	12	2	0	1	2	0	0	7.532821849970688	
i 1	28.998979591836736	0.7575000000000001	71	101	7	1	10	2	0	-1	2	0	0	2.0	
i 1	29.004285714285714	0.2525	75	915	6	5	3	2	0	1	2	0	0	7.532821849970688	
i 1	29.006326530612245	0.7575000000000001	74	101	5	2	1	16	0	2	16	0	0	13.0	
i 1	29.250612244897958	1.5150000000000001	74	915	4	1	8	8	0	-2	8	0	0	2.0	
i 1	29.251020408163264	0.7575000000000001	77	915	4	4	11	16	0	1	16	0	0	13.0	
i 1	29.25387755102041	0.7575000000000001	75	101	7	5	1	8	0	-2	8	0	0	7.532821849970688	
i 1	29.259591836734693	0.7575000000000001	75	915	6	5	1	8	0	-2	8	0	0	7.532821849970688	
i 1	29.74204081632653	0.2525	77	915	4	9	3	17	0	1	17	0	0	12.0	
i 1	29.748979591836736	0.2525	74	915	4	24	5	8	0	-2	8	0	0	3.0	
i 1	29.99204081632653	1.01	77	915	4	4	11	16	0	1	16	0	0	5.0	
i 1	29.992857142857144	0.2525	68	417	1	20	8	1	0	-1	1	0	0	11.0	
i 1	29.99326530612245	0.2525	68	417	1	24	9	0	0	-1	0	0	0	15.0	
i 1	29.998571428571427	0.2525	71	417	4	24	14	8	0	-1	8	0	0	3.0	
i 1	30.001020408163264	0.2525	71	101	2	20	8	0	0	-1	0	0	0	11.0	
i 1	30.002244897959184	1.01	75	915	5	5	12	8	0	-2	8	0	0	5.966403934487984	
i 1	30.003469387755104	0.7575000000000001	74	101	7	1	3	8	0	-1	8	0	0	2.0	
i 1	30.00387755102041	1.01	75	915	6	5	8	2	0	1	2	0	0	5.966403934487984	
i 1	30.00469387755102	1.5150000000000001	75	101	7	5	2	2	0	1	2	0	0	5.966403934487984	
i 1	30.005102040816325	0.7575000000000001	77	417	4	3	3	17	0	2	17	0	0	5.0	
i 1	30.00591836734694	0.2525	77	101	5	2	16	16	0	1	16	0	0	5.0	
i 1	30.00795918367347	0.505	75	101	7	5	1	8	0	-2	8	0	0	5.966403934487984	
i 1	30.24244897959184	1.2625	74	915	4	24	6	8	0	-2	8	0	0	3.0	
i 1	30.24612244897959	0.7575000000000001	71	417	5	1	3	2	0	-1	2	0	0	2.0	
i 1	30.248571428571427	1.2625	77	915	4	9	16	17	0	1	17	0	0	4.0	
i 1	30.251428571428573	0.7575000000000001	74	417	4	4	1	17	0	1	17	0	0	5.0	
i 1	30.759183673469387	0.7575000000000001	71	417	4	24	8	8	0	-1	8	0	0	3.0	
i 1	30.990408163265307	0.505	72	915	6	5	3	2	0	1	2	0	0	5.966403934487984	
i 1	30.992857142857144	0.505	75	915	5	5	12	2	0	1	2	0	0	5.966403934487984	
i 1	30.99408163265306	0.7575000000000001	77	915	4	9	8	17	0	1	17	0	0	4.0	
i 1	30.998979591836736	2.02	71	915	4	1	11	2	0	-2	2	0	0	2.0	
i 1	31.000204081632653	0.505	74	417	4	4	13	17	0	1	17	0	0	5.0	
i 1	31.002244897959184	0.505	71	417	6	1	8	2	0	-1	2	0	0	2.0	
i 1	31.003061224489795	0.505	72	417	6	5	5	2	0	1	2	0	0	5.966403934487984	
i 1	31.00795918367347	0.505	77	101	5	2	14	16	0	1	16	0	0	5.0	
i 1	31.240816326530613	0.2525	74	101	7	1	1	8	0	-1	8	0	0	2.0	
i 1	31.242857142857144	0.2525	75	101	7	5	11	8	0	-2	8	0	0	5.966403934487984	
i 1	31.24734693877551	0.2525	71	101	7	1	6	2	0	-1	2	0	0	2.0	
i 1	31.253469387755104	2.02	75	915	5	5	10	2	0	1	2	0	0	5.966403934487984	
i 1	31.25795918367347	0.2525	77	417	4	3	1	17	0	2	17	0	0	5.0	
i 1	31.26	1.01	71	915	4	1	1	8	0	-1	8	0	0	2.0	
i 1	31.26	0.2525	77	915	4	3	14	17	0	2	17	0	0	5.0	
i 1	31.490408163265307	0.2525	74	599	4	24	9	2	0	-1	2	0	0	3.0	
i 1	31.490408163265307	0.7575000000000001	74	213	4	3	7	16	0	2	16	0	0	5.0	
i 1	31.49612244897959	0.7575000000000001	74	599	4	3	14	17	0	1	17	0	0	5.0	
i 1	31.49612244897959	0.2525	71	599	1	24	4	1	0	-1	1	0	0	15.0	
i 1	31.497755102040816	0.2525	68	599	1	20	13	0	0	-1	0	0	0	11.0	
i 1	31.498979591836736	0.2525	72	213	6	5	14	2	0	1	2	0	0	5.966403934487984	
i 1	31.504285714285714	0.505	74	213	7	1	7	8	0	-2	8	0	0	2.0	
i 1	31.504285714285714	1.5150000000000001	75	213	7	5	7	8	0	-2	8	0	0	5.966403934487984	
i 1	31.505102040816325	0.2525	77	213	5	2	16	16	0	2	16	0	0	5.0	
i 1	31.505102040816325	1.7675	74	599	4	4	7	17	0	2	17	0	0	5.0	
i 1	31.50591836734694	1.5150000000000001	71	213	7	1	9	8	0	-2	8	0	0	2.0	
i 1	31.50673469387755	0.2525	72	599	6	5	2	2	0	-2	2	0	0	5.966403934487984	
i 1	31.51	0.2525	71	213	2	20	4	1	0	-1	1	0	0	11.0	
i 1	31.75755102040816	1.5150000000000001	77	213	4	4	9	17	0	1	17	0	0	5.0	
i 1	31.99612244897959	2.02	71	915	3	20	11	0	0	0	0	0	0	4.0	
i 1	32.0034693877551	0.2525	74	213	7	1	3	8	0	-2	8	0	0	2.0	
i 1	32.2530612244898	0.2525	77	915	3	9	13	17	0	1	17	0	0	4.0	
i 1	32.25959183673469	0.2525	71	599	6	1	4	2	0	-1	2	0	0	2.0	
i 1	32.498163265306125	0.2525	75	915	5	5	12	8	0	-2	8	0	0	5.966403934487984	
i 1	32.49857142857143	0.7575000000000001	74	213	4	24	10	8	0	-2	8	0	0	3.0	
i 1	32.50020408163265	0.2525	77	213	5	2	8	16	0	2	16	0	0	5.0	
i 1	32.50959183673469	0.7575000000000001	74	599	4	24	5	2	0	-1	2	0	0	3.0	
i 1	32.74775510204081	1.2625	72	599	6	5	9	2	0	-2	2	0	0	5.966403934487984	
i 1	32.7530612244898	1.5150000000000001	77	213	5	2	12	17	0	2	17	0	0	5.0	
i 1	32.754285714285714	1.2625	72	213	5	5	3	2	0	1	2	0	0	5.966403934487984	
i 1	32.758367346938776	0.2525	77	915	4	9	7	17	0	1	17	0	0	4.0	
i 1	32.992448979591835	1.2625	71	213	7	1	12	8	0	-2	8	0	0	2.0	
i 1	32.99979591836735	1.2625	71	915	6	1	3	2	0	-2	2	0	0	2.0	
i 1	33.00387755102041	1.7675	68	915	3	20	2	1	0	0	1	0	0	4.0	
i 1	33.00551020408163	1.2625	77	915	3	9	6	17	0	1	17	0	0	4.0	
i 1	33.005918367346936	0.2525	75	213	6	5	1	8	0	-2	8	0	0	5.966403934487984	
i 1	33.2465306122449	0.2525	72	213	7	5	5	2	0	-2	2	0	0	5.966403934487984	
i 1	33.24857142857143	0.2525	77	213	5	2	7	16	0	2	16	0	0	5.0	
i 1	33.251020408163264	0.7575000000000001	71	915	4	1	5	8	0	-1	8	0	0	2.0	
i 1	33.49775510204081	1.2625	75	599	6	5	8	8	0	-2	8	0	0	5.966403934487984	
i 1	33.498979591836736	0.2525	77	213	4	4	11	17	0	1	17	0	0	5.0	
i 1	33.50142857142857	1.2625	72	213	5	5	2	2	0	1	2	0	0	5.966403934487984	
i 1	33.74938775510204	0.2525	74	213	7	1	13	8	0	-2	8	0	0	2.0	
i 1	33.74979591836735	1.2625	74	599	4	3	9	17	0	1	17	0	0	5.0	
i 1	33.7530612244898	0.2525	74	213	4	3	3	16	0	2	16	0	0	5.0	
i 1	33.99204081632653	2.7775	61	213	6	25	7	1	0	2	1	0	0	3.3992078592772597	
i 1	33.993265306122446	0.2525	75	915	5	5	2	8	0	-2	8	0	0	5.966403934487984	
i 1	34.001020408163264	1.2625	74	213	3	3	2	16	0	2	16	0	0	5.0	
i 1	34.0030612244898	1.01	74	213	7	1	11	8	0	-2	8	0	0	2.0	
i 1	34.005102040816325	1.2625	71	213	3	20	9	0	0	0	0	0	0	4.0	
i 1	34.00551020408163	1.01	71	915	6	1	10	8	0	-1	8	0	0	2.0	
i 1	34.24285714285714	0.7575000000000001	74	213	4	1	15	8	0	-1	8	0	0	2.0	
i 1	34.24448979591837	1.5150000000000001	75	213	6	5	11	8	0	-2	8	0	0	5.966403934487984	
i 1	34.244897959183675	1.7675	72	213	6	5	5	2	0	-2	2	0	0	5.966403934487984	
i 1	34.24612244897959	1.5150000000000001	74	599	4	4	9	17	0	2	17	0	0	5.0	
i 1	34.251020408163264	1.5150000000000001	75	915	5	5	6	2	0	1	2	0	0	5.966403934487984	
i 1	34.255918367346936	1.01	71	915	3	20	6	0	0	0	0	0	0	4.0	
i 1	34.49530612244898	0.505	77	213	4	4	10	17	0	1	17	0	0	5.0	
i 1	34.50142857142857	0.505	71	599	6	1	9	2	0	-1	2	0	0	2.0	
i 1	34.5034693877551	1.2625	74	599	4	24	10	2	0	-1	2	0	0	3.0	
i 1	34.755918367346936	1.2625	74	213	4	24	6	8	0	-2	8	0	0	3.0	
i 1	34.99122448979592	0.7575000000000001	77	213	3	4	12	17	0	1	17	0	0	5.0	
i 1	34.99367346938776	1.7675	61	213	6	25	5	16	0	2	16	0	0	3.3992078592772597	
i 1	35.001020408163264	0.2525	71	599	6	1	7	2	0	-1	2	0	0	2.0	
i 1	35.005918367346936	0.2525	74	213	6	1	5	8	0	-1	8	0	0	2.0	
i 1	35.24530612244898	0.2525	68	599	4	24	12	0	0	-1	0	0	0	8.0	
i 1	35.2469387755102	1.7675	71	915	6	1	11	2	0	-2	2	0	0	2.0	
i 1	35.24775510204081	0.2525	71	213	4	20	14	1	0	0	1	0	0	4.0	
i 1	35.24775510204081	0.2525	71	599	4	20	16	1	0	0	1	0	0	4.0	
i 1	35.248979591836736	0.7575000000000001	71	213	7	1	7	8	0	-2	8	0	0	2.0	
i 1	35.254285714285714	0.7575000000000001	77	915	3	9	12	17	0	1	17	0	0	4.0	
i 1	35.258367346938776	1.01	75	915	5	5	15	8	0	-2	8	0	0	5.966403934487984	
i 1	35.25877551020408	0.7575000000000001	77	213	5	2	15	17	0	2	17	0	0	5.0	
i 1	35.494081632653064	1.2625	74	599	4	3	3	17	0	1	17	0	0	5.0	
i 1	35.49938775510204	0.505	68	915	3	20	14	1	0	0	1	0	0	4.0	
i 1	35.50061224489796	0.505	68	213	3	24	6	1	0	-1	1	0	0	8.0	
i 1	35.501836734693875	1.2625	72	213	5	5	13	2	0	1	2	0	0	5.966403934487984	
i 1	35.5034693877551	0.505	68	213	3	20	16	1	0	0	1	0	0	4.0	
i 1	35.50387755102041	0.505	68	915	3	20	7	1	0	0	1	0	0	4.0	
i 1	35.505102040816325	1.2625	74	213	3	3	3	16	0	2	16	0	0	5.0	
i 1	35.50551020408163	1.2625	72	599	5	5	1	2	0	-2	2	0	0	5.966403934487984	
i 1	35.99	0.7575000000000001	74	213	7	1	4	8	0	-2	8	0	0	2.0	
i 1	35.992448979591835	0.505	71	213	4	20	12	1	0	-1	1	0	0	4.0	
i 1	35.99612244897959	0.505	71	213	4	20	15	1	0	-1	1	0	0	4.0	
i 1	35.9965306122449	0.505	71	599	4	20	5	1	0	0	1	0	0	4.0	
i 1	35.998979591836736	1.7675	71	915	6	1	9	8	0	-1	8	0	0	2.0	
i 1	35.99938775510204	0.7575000000000001	71	213	5	1	9	8	0	-2	8	0	0	2.0	
i 1	35.99938775510204	1.5150000000000001	68	915	3	24	16	1	0	0	1	0	0	8.0	
i 1	36.00061224489796	0.2525	77	915	3	9	10	17	0	1	17	0	0	4.0	
i 1	36.004285714285714	0.7575000000000001	61	599	5	25	11	1	0	1	1	0	0	3.3992078592772597	
i 1	36.251836734693875	0.505	72	213	5	5	15	2	0	1	2	0	0	5.966403934487984	
i 1	36.2534693877551	0.505	77	213	3	4	7	17	0	1	17	0	0	5.0	
i 1	36.254285714285714	0.505	74	599	4	4	13	17	0	2	17	0	0	5.0	
i 1	36.255918367346936	0.505	75	599	5	5	10	8	0	-2	8	0	0	5.966403934487984	
i 1	36.49204081632653	0.505	68	915	3	20	5	0	0	0	0	0	0	4.0	
i 1	36.49612244897959	0.2525	77	213	6	2	5	17	0	2	17	0	0	5.0	
i 1	36.49612244897959	1.2625	75	915	5	5	4	8	0	-2	8	0	0	5.966403934487984	
i 1	36.49734693877551	0.2525	71	213	3	20	5	1	0	-1	1	0	0	4.0	
i 1	36.504285714285714	0.2525	75	213	6	5	12	8	0	-2	8	0	0	5.966403934487984	
i 1	36.74	0.2525	72	915	4	5	4	2	0	-2	2	0	0	5.966403934487984	
i 1	36.74040816326531	0.2525	74	915	2	4	3	17	0	2	17	0	0	5.0	
i 1	36.742448979591835	0.2525	74	417	4	4	7	17	0	2	17	0	0	5.0	
i 1	36.742448979591835	6.8175	61	417	5	25	12	16	0	1	16	0	0	3.3992078592772597	
i 1	36.74367346938776	1.01	75	101	6	5	2	2	0	1	2	0	0	5.966403934487984	
i 1	36.744897959183675	1.01	71	101	5	1	11	2	0	-1	2	0	0	2.0	
i 1	36.74530612244898	0.2525	72	417	5	5	6	2	0	1	2	0	0	5.966403934487984	
i 1	36.748979591836736	1.7675	75	417	5	5	1	2	0	1	2	0	0	5.966403934487984	
i 1	36.74938775510204	1.01	74	101	6	2	12	16	0	1	16	0	0	5.0	
i 1	36.74938775510204	0.2525	68	915	2	20	1	1	0	0	1	0	0	4.0	
i 1	36.75142857142857	3.7875	63	101	6	25	7	16	0	2	16	0	0	3.3992078592772597	
i 1	36.7534693877551	1.01	77	915	2	3	9	17	0	1	17	0	0	5.0	
i 1	36.757551020408165	3.7875	63	101	6	25	5	1	0	1	1	0	0	3.3992078592772597	
i 1	36.99204081632653	0.2525	77	915	3	9	5	17	0	1	17	0	0	4.0	
i 1	36.99612244897959	1.01	71	915	6	1	11	8	0	-2	8	0	0	2.0	
i 1	36.998163265306125	6.565	63	417	5	25	13	1	0	2	1	0	0	3.3992078592772597	
i 1	37.00265306122449	0.2525	71	101	4	20	13	0	0	0	0	0	0	4.0	
i 1	37.00265306122449	3.535	71	915	3	20	10	0	0	0	0	0	0	4.0	
i 1	37.24081632653061	1.01	74	417	5	3	8	16	0	2	16	0	0	5.0	
i 1	37.24612244897959	1.2625	72	915	4	5	10	2	0	-2	2	0	0	5.966403934487984	
i 1	37.2534693877551	0.7575000000000001	74	101	5	1	10	8	0	-1	8	0	0	2.0	
i 1	37.254285714285714	0.7575000000000001	74	915	2	4	11	17	0	2	17	0	0	5.0	
i 1	37.255918367346936	1.01	71	915	3	20	15	0	0	0	0	0	0	4.0	
i 1	37.25632653061224	0.2525	71	915	2	20	5	1	0	0	1	0	0	4.0	
i 1	37.26	3.2825	68	915	3	20	8	0	0	0	0	0	0	4.0	
i 1	37.49734693877551	0.505	71	417	6	1	6	2	0	-2	2	0	0	2.0	
i 1	37.49979591836735	0.505	74	417	4	4	12	17	0	2	17	0	0	5.0	
i 1	37.505918367346936	0.505	74	915	4	24	2	8	0	-1	8	0	0	3.0	
i 1	37.51	1.2625	77	915	3	9	14	17	0	1	17	0	0	4.0	
i 1	37.744897959183675	0.2525	75	915	4	5	12	2	0	1	2	0	0	5.966403934487984	
i 1	37.99	1.01	71	915	2	20	11	1	0	0	1	0	0	4.0	
i 1	37.99122448979592	0.7575000000000001	74	417	4	4	11	17	0	2	17	0	0	5.0	
i 1	37.993265306122446	1.5150000000000001	72	417	5	5	11	2	0	1	2	0	0	5.966403934487984	
i 1	37.99367346938776	1.01	74	417	4	24	13	8	0	-1	8	0	0	3.0	
i 1	37.994897959183675	0.505	71	417	4	1	13	2	0	-2	2	0	0	2.0	
i 1	37.99979591836735	1.01	71	915	5	1	15	2	0	-2	2	0	0	2.0	
i 1	38.00142857142857	1.5150000000000001	75	915	4	5	8	2	0	1	2	0	0	5.966403934487984	
i 1	38.001836734693875	0.2525	71	915	2	24	13	0	0	-1	0	0	0	8.0	
i 1	38.007551020408165	0.505	74	915	4	24	14	8	0	-1	8	0	0	3.0	
i 1	38.01	2.525	61	915	4	26	2	1	0	1	1	0	0	3.3992078592772597	
i 1	38.24081632653061	0.2525	74	915	2	4	14	17	0	2	17	0	0	5.0	
i 1	38.493265306122446	2.02	74	417	5	3	3	16	0	2	16	0	0	5.0	
i 1	38.495714285714286	2.02	71	915	2	24	12	0	0	-1	0	0	0	8.0	
i 1	38.4965306122449	1.01	77	915	2	3	4	17	0	1	17	0	0	5.0	
i 1	38.501020408163264	2.02	74	101	5	1	12	8	0	-1	8	0	0	2.0	
i 1	38.50469387755102	2.02	71	915	3	20	15	0	0	0	0	0	0	4.0	
i 1	38.50551020408163	1.01	74	101	6	2	14	16	0	1	16	0	0	5.0	
i 1	38.505918367346936	0.2525	75	915	4	5	11	2	0	1	2	0	0	5.966403934487984	
i 1	38.74612244897959	0.7575000000000001	71	915	5	1	9	8	0	-1	8	0	0	2.0	
i 1	38.75632653061224	0.7575000000000001	71	101	5	1	4	2	0	-1	2	0	0	2.0	
i 1	38.75959183673469	1.01	75	915	4	5	13	8	0	-2	8	0	0	5.966403934487984	
i 1	38.99081632653061	0.2525	71	915	6	1	2	2	0	-2	2	0	0	2.0	
i 1	38.99122448979592	1.5150000000000001	74	915	2	4	1	17	0	2	17	0	0	5.0	
i 1	38.998979591836736	0.2525	74	417	4	24	8	8	0	-1	8	0	0	3.0	
i 1	39.00265306122449	1.5150000000000001	61	915	4	26	11	16	0	1	16	0	0	3.3992078592772597	
i 1	39.007551020408165	0.7575000000000001	75	101	7	5	14	2	0	1	2	0	0	5.966403934487984	
i 1	39.008367346938776	1.5150000000000001	71	915	4	1	13	8	0	-2	8	0	0	2.0	
i 1	39.25387755102041	0.7575000000000001	68	915	2	20	16	0	0	0	0	0	0	4.0	
i 1	39.256734693877554	0.7575000000000001	75	101	6	5	8	8	0	1	8	0	0	5.966403934487984	
i 1	39.256734693877554	0.7575000000000001	71	915	2	20	16	1	0	0	1	0	0	4.0	
i 1	39.258367346938776	1.2625	75	915	3	5	16	2	0	1	2	0	0	5.966403934487984	
i 1	39.492448979591835	0.2525	71	915	6	1	6	2	0	-2	2	0	0	2.0	
i 1	39.7469387755102	0.2525	74	915	4	24	14	8	0	-1	8	0	0	3.0	
i 1	39.754285714285714	0.2525	74	101	6	2	6	16	0	1	16	0	0	5.0	
i 1	39.755102040816325	0.2525	75	915	4	5	3	2	0	1	2	0	0	5.966403934487984	
i 1	39.99285714285714	1.01	75	417	5	5	10	2	0	1	2	0	0	5.966403934487984	
i 1	39.995714285714286	0.505	75	101	7	5	3	8	0	1	8	0	0	5.966403934487984	
i 1	39.99612244897959	0.505	61	915	3	27	14	1	0	2	1	0	0	3.739128645204986	
i 1	40.0030612244898	0.505	74	417	4	4	8	17	0	2	17	0	0	5.0	
i 1	40.00632653061224	0.505	77	915	4	9	5	17	0	1	17	0	0	4.0	
i 1	40.24285714285714	0.2525	71	101	5	1	14	2	0	-1	2	0	0	2.0	
i 1	40.243265306122446	0.505	72	417	5	5	11	2	0	1	2	0	0	5.966403934487984	
i 1	40.244081632653064	0.2525	72	915	3	5	14	2	0	-2	2	0	0	5.966403934487984	
i 1	40.2469387755102	0.2525	77	915	4	9	11	17	0	1	17	0	0	4.0	
i 1	40.248163265306125	0.2525	71	915	6	1	6	8	0	-1	8	0	0	2.0	
i 1	40.25469387755102	0.2525	74	101	6	2	7	16	0	1	16	0	0	5.0	
i 1	40.255918367346936	0.2525	75	915	4	5	6	2	0	1	2	0	0	5.966403934487984	
i 1	40.25877551020408	0.2525	75	101	6	5	11	2	0	1	2	0	0	5.966403934487984	
i 1	40.25877551020408	0.2525	68	915	3	24	6	1	0	0	1	0	0	8.0	
i 1	40.25959183673469	0.2525	71	915	3	1	8	2	0	-2	2	0	0	2.0	
i 1	40.49040816326531	0.2525	72	417	4	5	10	2	0	1	2	0	0	5.966403934487984	
i 1	40.49122448979592	4.545	61	417	3	27	6	1	0	1	1	0	0	3.739128645204986	
i 1	40.492448979591835	1.5150000000000001	75	1119	5	5	14	2	0	-2	2	0	0	5.966403934487984	
i 1	40.49285714285714	0.2525	74	803	4	9	8	16	0	1	16	0	0	4.0	
i 1	40.49530612244898	0.2525	77	1119	5	2	4	17	0	1	17	0	0	5.0	
i 1	40.49530612244898	4.545	63	803	4	26	15	1	0	1	1	0	0	3.3992078592772597	
i 1	40.49734693877551	1.7675	71	417	4	1	9	2	0	-2	2	0	0	2.0	
i 1	40.49734693877551	0.505	71	803	6	1	10	2	0	-2	2	0	0	2.0	
i 1	40.49857142857143	0.505	74	803	3	1	3	2	0	-1	2	0	0	2.0	
i 1	40.49857142857143	0.505	68	803	3	20	3	0	0	0	0	0	0	4.0	
i 1	40.49979591836735	1.7675	75	803	4	5	15	8	0	-2	8	0	0	5.966403934487984	
i 1	40.50387755102041	2.525	61	1119	5	25	14	16	0	2	16	0	0	3.3992078592772597	
i 1	40.50469387755102	3.0300000000000002	61	1119	5	25	6	1	0	1	1	0	0	3.3992078592772597	
i 1	40.505102040816325	0.505	68	803	3	20	16	0	0	0	0	0	0	4.0	
i 1	40.50551020408163	0.505	74	417	3	3	11	16	0	2	16	0	0	5.0	
i 1	40.505918367346936	4.545	63	803	4	26	11	16	0	1	16	0	0	3.3992078592772597	
i 1	40.50714285714286	0.2525	71	803	3	24	5	0	0	0	0	0	0	8.0	
i 1	40.50795918367347	0.2525	71	803	3	20	12	1	0	0	1	0	0	4.0	
i 1	40.508367346938776	0.7575000000000001	71	1119	4	1	5	2	0	-2	2	0	0	2.0	
i 1	40.50959183673469	0.505	71	1119	4	1	12	2	0	-2	2	0	0	2.0	
i 1	40.741632653061224	1.5150000000000001	74	417	4	4	4	17	0	2	17	0	0	5.0	
i 1	40.748163265306125	0.2525	68	417	3	20	11	0	0	-1	0	0	0	4.0	
i 1	40.751020408163264	0.7575000000000001	74	417	5	3	6	16	0	2	16	0	0	5.0	
i 1	40.99122448979592	0.505	71	803	3	24	5	0	0	0	0	0	0	8.0	
i 1	40.991632653061224	0.2525	71	803	3	1	1	2	0	-2	2	0	0	2.0	
i 1	40.99204081632653	4.04	61	417	3	27	4	16	0	1	16	0	0	3.739128645204986	
i 1	40.99285714285714	0.505	71	417	3	20	16	0	0	-1	0	0	0	4.0	
i 1	40.994081632653064	1.01	71	417	6	1	3	2	0	-2	2	0	0	2.0	
i 1	40.99448979591837	0.505	71	803	1	20	6	1	0	0	1	0	0	4.0	
i 1	41.00265306122449	0.505	68	417	3	24	8	0	0	0	0	0	0	8.0	
i 1	41.00795918367347	0.505	74	417	4	3	4	16	0	2	16	0	0	5.0	
i 1	41.24122448979592	0.2525	72	417	5	5	7	2	0	1	2	0	0	5.966403934487984	
i 1	41.25918367346939	0.7575000000000001	74	417	3	4	12	16	0	2	16	0	0	5.0	
i 1	41.49367346938776	0.2525	71	1119	2	20	10	1	0	0	1	0	0	4.0	
i 1	41.494897959183675	0.2525	71	417	4	20	15	0	0	-1	0	0	0	4.0	
i 1	41.49979591836735	0.505	68	417	3	20	7	0	0	-1	0	0	0	4.0	
i 1	41.50020408163265	0.505	68	803	3	20	4	0	0	0	0	0	0	4.0	
i 1	41.507551020408165	0.2525	72	417	4	5	11	2	0	1	2	0	0	5.966403934487984	
i 1	41.74204081632653	0.2525	71	803	3	24	2	0	0	0	0	0	0	8.0	
i 1	41.742448979591835	0.2525	74	803	4	9	9	16	0	1	16	0	0	4.0	
i 1	41.7469387755102	0.2525	68	803	3	20	4	0	0	0	0	0	0	4.0	
i 1	41.74857142857143	1.7675	71	1119	4	1	16	2	0	-2	2	0	0	2.0	
i 1	41.75224489795919	0.2525	68	417	3	24	11	0	0	0	0	0	0	8.0	
i 1	41.7530612244898	0.2525	71	803	1	20	7	0	0	0	0	0	0	4.0	
i 1	41.7534693877551	0.2525	71	417	3	20	15	0	0	-1	0	0	0	4.0	
i 1	41.75918367346939	1.5150000000000001	75	417	4	5	13	8	0	-2	8	0	0	5.966403934487984	
i 1	41.99081632653061	0.2525	74	417	4	4	11	16	0	2	16	0	0	5.0	
i 1	41.99122448979592	0.2525	74	1119	6	2	9	16	0	2	16	0	0	5.0	
i 1	41.99122448979592	1.2625	75	417	5	5	4	2	0	1	2	0	0	5.966403934487984	
i 1	41.994897959183675	0.505	71	417	4	24	10	8	0	-1	8	0	0	3.0	
i 1	41.99530612244898	0.2525	71	417	3	1	12	2	0	-2	2	0	0	2.0	
i 1	41.99857142857143	1.01	68	803	1	20	3	0	0	0	0	0	0	11.0	
i 1	42.00020408163265	0.505	74	417	4	24	6	8	0	-1	8	0	0	3.0	
i 1	42.004285714285714	1.01	68	803	3	20	4	0	0	0	0	0	0	11.0	
i 1	42.005102040816325	1.5150000000000001	74	803	3	1	2	2	0	-1	2	0	0	2.0	
i 1	42.00918367346939	1.01	71	803	1	20	13	0	0	0	0	0	0	11.0	
i 1	42.24367346938776	1.01	74	803	4	9	15	16	0	1	16	0	0	4.0	
i 1	42.24448979591837	0.2525	74	417	4	3	3	16	0	2	16	0	0	5.0	
i 1	42.24938775510204	1.01	77	1119	6	2	6	17	0	1	17	0	0	5.0	
i 1	42.49204081632653	0.505	71	803	3	24	16	0	0	0	0	0	0	15.0	
i 1	42.49530612244898	0.505	68	417	3	24	6	0	0	0	0	0	0	15.0	
i 1	42.50551020408163	0.505	71	417	3	20	10	0	0	-1	0	0	0	11.0	
i 1	42.74	1.7675	72	417	4	5	2	2	0	1	2	0	0	5.966403934487984	
i 1	42.744897959183675	0.2525	74	417	5	3	5	16	0	2	16	0	0	5.0	
i 1	42.74530612244898	0.2525	68	417	3	20	7	0	0	-1	0	0	0	11.0	
i 1	42.75265306122449	0.7575000000000001	75	1119	6	5	16	2	0	-2	2	0	0	5.966403934487984	
i 1	42.756734693877554	0.7575000000000001	71	1119	4	1	2	2	0	-2	2	0	0	2.0	
i 1	42.99204081632653	0.2525	72	417	5	5	5	2	0	1	2	0	0	5.966403934487984	
i 1	42.993265306122446	0.2525	74	1119	6	2	1	16	0	2	16	0	0	5.0	
i 1	42.99367346938776	0.505	68	803	3	20	2	0	0	0	0	0	0	10.0	
i 1	42.994081632653064	1.2625	71	803	3	1	12	2	0	-2	2	0	0	2.0	
i 1	42.99448979591837	0.505	68	417	3	20	3	0	0	-1	0	0	0	10.0	
i 1	42.994897959183675	0.7575000000000001	75	803	5	5	13	8	0	-2	8	0	0	5.966403934487984	
i 1	42.99734693877551	1.7675	68	417	3	24	10	0	0	0	0	0	0	14.0	
i 1	42.998163265306125	2.02	71	803	3	24	11	0	0	0	0	0	0	14.0	
i 1	42.99979591836735	0.2525	71	1119	2	20	2	1	0	0	1	0	0	10.0	
i 1	43.00918367346939	0.2525	71	417	2	20	3	0	0	-1	0	0	0	10.0	
i 1	43.24530612244898	0.7575000000000001	71	417	3	1	12	2	0	-2	2	0	0	2.0	
i 1	43.25020408163265	0.505	68	803	1	20	1	1	0	0	1	0	0	10.0	
i 1	43.25469387755102	0.505	71	417	1	20	15	0	0	-1	0	0	0	10.0	
i 1	43.25918367346939	1.01	74	417	4	3	8	16	0	2	16	0	0	5.0	
i 1	43.49	0.7575000000000001	74	1118	6	2	7	17	0	2	17	0	0	5.0	
i 1	43.49	0.505	75	185	5	5	4	2	0	-2	2	0	0	5.966403934487984	
i 1	43.492448979591835	0.505	74	803	4	9	11	16	0	1	16	0	0	4.0	
i 1	43.49530612244898	0.505	74	1118	4	1	13	2	0	-1	2	0	0	2.0	
i 1	43.49857142857143	0.505	61	1118	5	25	11	16	0	2	16	0	0	3.3992078592772597	
i 1	43.498979591836736	1.5150000000000001	63	185	6	25	14	16	0	1	16	0	0	3.3992078592772597	
i 1	43.50020408163265	1.5150000000000001	63	185	6	25	14	1	0	2	1	0	0	3.3992078592772597	
i 1	43.50265306122449	0.2525	77	185	6	3	10	17	0	1	17	0	0	5.0	
i 1	43.50265306122449	0.2525	75	1118	6	5	6	2	0	1	2	0	0	5.966403934487984	
i 1	43.50551020408163	0.505	74	1118	6	2	10	16	0	1	16	0	0	5.0	
i 1	43.50877551020408	0.505	74	1118	4	1	4	8	0	-1	8	0	0	2.0	
i 1	43.755918367346936	0.2525	71	1118	2	20	14	0	0	-1	0	0	0	10.0	
i 1	43.75714285714286	0.2525	68	185	2	20	10	1	0	0	1	0	0	10.0	
i 1	43.757551020408165	1.01	68	417	3	20	1	0	0	-1	0	0	0	10.0	
i 1	43.75959183673469	1.2625	68	803	3	20	6	0	0	0	0	0	0	10.0	
i 1	43.99204081632653	0.2525	74	1118	6	1	5	8	0	-1	8	0	0	2.0	
i 1	43.99367346938776	1.01	75	803	4	5	15	8	0	-2	8	0	0	5.966403934487984	
i 1	43.994081632653064	1.01	75	185	5	5	11	8	0	1	8	0	0	5.966403934487984	
i 1	43.9969387755102	0.7575000000000001	75	185	7	5	8	2	0	-2	2	0	0	5.966403934487984	
i 1	43.998979591836736	0.505	71	417	1	20	10	0	0	0	0	0	0	10.0	
i 1	43.99979591836735	0.2525	77	185	5	4	4	16	0	2	16	0	0	5.0	
i 1	44.005918367346936	0.505	68	803	1	20	5	0	0	-1	0	0	0	10.0	
i 1	44.00959183673469	0.505	68	803	1	20	2	1	0	0	1	0	0	10.0	
i 1	44.24081632653061	0.2525	74	417	4	4	4	16	0	2	16	0	0	5.0	
i 1	44.2465306122449	0.7575000000000001	74	1118	4	1	10	2	0	-1	2	0	0	2.0	
i 1	44.25142857142857	0.2525	77	185	6	3	8	17	0	1	17	0	0	5.0	
i 1	44.257551020408165	0.7575000000000001	71	417	3	1	6	2	0	-2	2	0	0	2.0	
i 1	44.49	0.2525	68	1118	2	20	8	1	0	-1	1	0	0	10.0	
i 1	44.50020408163265	0.505	77	185	5	4	15	16	0	2	16	0	0	5.0	
i 1	44.504285714285714	0.2525	68	185	2	20	12	1	0	0	1	0	0	10.0	
i 1	44.50469387755102	0.505	74	803	4	9	7	17	0	2	17	0	0	4.0	
i 1	44.50959183673469	0.2525	71	1118	2	20	8	0	0	-1	0	0	0	10.0	
i 1	44.74285714285714	0.2525	68	803	1	20	1	1	0	0	1	0	0	10.0	
i 1	44.745714285714286	0.2525	74	803	4	9	10	16	0	1	16	0	0	4.0	
i 1	44.7465306122449	0.2525	71	803	1	20	11	0	0	0	0	0	0	10.0	
i 1	44.75265306122449	0.2525	72	417	4	5	12	2	0	1	2	0	0	5.966403934487984	
i 1	44.756734693877554	0.2525	71	417	3	24	2	8	0	-1	8	0	0	3.0	
i 1	44.758367346938776	0.2525	74	1118	6	2	4	17	0	2	17	0	0	5.0	
i 1	44.99204081632653	11.11	63	903	4	14	13	16	0	2	16	0	0	11.246573065828398	
i 1	44.99285714285714	1.01	61	89	4	7	3	1	0	1	1	0	0	5.645614572289043	
i 1	44.99367346938776	0.7575000000000001	72	587	4	5	1	2	0	-2	2	0	0	5.112110450027318	
i 1	44.994897959183675	3.0300000000000002	63	903	4	26	12	1	0	2	1	0	0	3.3992078592772597	
i 1	44.99612244897959	0.7575000000000001	72	89	7	5	3	2	0	1	2	0	0	5.112110450027318	
i 1	44.99734693877551	1.7675	71	587	3	24	6	1	0	0	1	0	0	14.0	
i 1	44.99775510204081	2.02	61	903	4	26	4	16	0	1	16	0	0	3.3992078592772597	
i 1	44.99979591836735	1.01	77	903	6	2	2	16	0	2	16	0	0	3.0	
i 1	45.00020408163265	1.5150000000000001	71	903	1	20	11	1	0	0	1	0	0	10.0	
i 1	45.00061224489796	0.505	74	89	4	24	9	8	0	-2	8	0	0	3.0	
i 1	45.00265306122449	2.2725	61	587	3	27	14	1	0	1	1	0	0	3.739128645204986	
i 1	45.004285714285714	0.505	74	89	5	4	15	17	0	1	17	0	0	3.0	
i 1	45.00469387755102	0.2525	77	903	5	9	2	16	0	2	16	0	0	2.0	
i 1	45.00469387755102	0.2525	75	587	5	5	6	2	0	-2	2	0	0	5.112110450027318	
i 1	45.00469387755102	10.1	61	903	4	14	5	16	0	1	16	0	0	11.246573065828398	
i 1	45.00551020408163	0.505	74	587	3	24	8	8	0	-2	8	0	0	3.0	
i 1	45.006734693877554	1.5150000000000001	71	903	6	1	1	2	0	-2	2	0	0	2.0	
i 1	45.00714285714286	1.01	77	903	4	9	2	16	0	1	16	0	0	2.0	
i 1	45.00877551020408	2.2725	63	587	3	27	11	16	0	2	16	0	0	3.739128645204986	
i 1	45.00959183673469	1.01	63	89	6	25	4	16	0	2	16	0	0	3.3992078592772597	
i 1	45.248163265306125	1.2625	74	903	3	1	1	2	0	-1	2	0	0	2.0	
i 1	45.49367346938776	0.505	75	89	7	5	4	2	0	-2	2	0	0	5.112110450027318	
i 1	45.49530612244898	0.505	75	587	5	5	12	2	0	-2	2	0	0	5.112110450027318	
i 1	45.49612244897959	1.01	71	587	1	20	11	0	0	-1	0	0	0	10.0	
i 1	45.50224489795919	0.2525	77	89	6	3	3	16	0	2	16	0	0	3.0	
i 1	45.748979591836736	0.7575000000000001	68	587	3	20	1	1	0	-1	1	0	0	10.0	
i 1	45.75142857142857	0.2525	72	903	4	5	9	8	0	-2	8	0	0	5.112110450027318	
i 1	45.7534693877551	1.01	74	587	4	3	7	16	0	2	16	0	0	3.0	
i 1	45.99285714285714	1.7675	71	903	3	1	6	8	0	-1	8	0	0	2.0	
i 1	45.99775510204081	4.2925	61	89	4	7	14	1	0	1	1	0	0	5.645614572289043	
i 1	46.00061224489796	0.7575000000000001	75	587	4	5	16	2	0	-2	2	0	0	5.112110450027318	
i 1	46.00142857142857	0.7575000000000001	77	89	6	3	13	16	0	2	16	0	0	3.0	
i 1	46.001836734693875	2.02	74	903	6	1	15	2	0	-1	2	0	0	2.0	
i 1	46.005102040816325	0.7575000000000001	75	89	4	5	2	2	0	-2	2	0	0	5.112110450027318	
i 1	46.243265306122446	0.505	71	903	1	24	3	0	0	0	0	0	0	14.0	
i 1	46.24448979591837	0.2525	71	903	1	20	16	0	0	0	0	0	0	10.0	
i 1	46.493265306122446	0.2525	73	89	2	20	2	8	0	-1	8	0	0	10.0	
i 1	46.49857142857143	0.2525	71	903	2	20	4	0	0	0	0	0	0	10.0	
i 1	46.50387755102041	0.505	72	587	5	5	7	2	0	-2	2	0	0	5.112110450027318	
i 1	46.50714285714286	0.505	72	89	7	5	7	2	0	1	2	0	0	5.112110450027318	
i 1	46.74081632653061	0.505	74	89	5	4	8	17	0	1	17	0	0	3.0	
i 1	46.74204081632653	0.505	74	903	3	1	10	2	0	-1	2	0	0	2.0	
i 1	46.74530612244898	0.2525	71	903	6	1	7	2	0	-2	2	0	0	2.0	
i 1	46.75551020408163	1.01	77	903	5	9	15	16	0	2	16	0	0	2.0	
i 1	46.75551020408163	0.2525	73	587	1	20	3	8	0	-1	8	0	0	10.0	
i 1	46.756734693877554	0.2525	75	903	4	5	8	2	0	1	2	0	0	5.112110450027318	
i 1	46.757551020408165	1.01	68	903	1	20	8	0	0	0	0	0	0	10.0	
i 1	46.75877551020408	0.505	74	587	4	4	7	17	0	2	17	0	0	3.0	
i 1	46.75877551020408	0.505	71	903	1	20	10	0	0	0	0	0	0	10.0	
i 1	46.99040816326531	0.7575000000000001	72	903	6	5	3	8	0	-2	8	0	0	5.112110450027318	
i 1	46.99285714285714	0.2525	75	903	4	5	5	8	0	-2	8	0	0	5.112110450027318	
i 1	46.99448979591837	0.7575000000000001	75	903	4	5	4	2	0	-2	2	0	0	5.112110450027318	
i 1	47.001020408163264	0.7575000000000001	71	903	1	20	15	1	0	0	1	0	0	10.0	
i 1	47.00469387755102	0.2525	71	587	1	24	14	1	0	0	1	0	0	14.0	
i 1	47.007551020408165	0.7575000000000001	74	903	6	2	8	16	0	1	16	0	0	3.0	
i 1	47.25061224489796	2.7775	61	405	3	27	8	9	0	1	9	0	0	3.739128645204986	
i 1	47.251020408163264	1.7675	61	405	3	27	2	9	0	1	9	0	0	3.739128645204986	
i 1	47.25224489795919	2.02	73	405	1	20	11	8	0	-1	8	0	0	10.0	
i 1	47.25795918367347	2.02	73	405	1	24	11	2	0	-1	2	0	0	14.0	
i 1	47.49204081632653	1.01	75	903	6	5	15	2	0	1	2	0	0	5.112110450027318	
i 1	47.49367346938776	0.2525	74	89	5	4	16	17	0	1	17	0	0	3.0	
i 1	47.498163265306125	1.01	71	903	5	1	16	2	0	-2	2	0	0	2.0	
i 1	47.50265306122449	1.01	75	903	4	5	3	8	0	-2	8	0	0	5.112110450027318	
i 1	47.50387755102041	0.505	71	903	1	20	4	0	0	0	0	0	0	10.0	
i 1	47.506734693877554	1.7675	75	89	4	5	2	2	0	-2	2	0	0	5.112110450027318	
i 1	47.50714285714286	2.2725	71	903	1	24	8	0	0	0	0	0	0	14.0	
i 1	47.51	0.505	74	903	3	1	1	2	0	-1	2	0	0	2.0	
i 1	47.751020408163264	0.505	77	903	6	2	12	16	0	2	16	0	0	3.0	
i 1	47.7534693877551	0.505	77	903	5	9	11	16	0	1	16	0	0	2.0	
i 1	47.75632653061224	1.2625	77	89	6	3	10	16	0	2	16	0	0	3.0	
i 1	47.99122448979592	1.01	72	405	5	3	12	0	0	-1	0	0	0	3.0	
i 1	47.998979591836736	0.505	74	903	6	1	9	2	0	-1	2	0	0	2.0	
i 1	48.00061224489796	1.5150000000000001	71	903	3	20	11	0	0	0	0	0	0	10.0	
i 1	48.004285714285714	1.01	74	903	5	1	5	2	0	-1	2	0	0	2.0	
i 1	48.49122448979592	0.7575000000000001	74	405	6	5	10	16	0	2	16	0	0	5.112110450027318	
i 1	48.508367346938776	0.2525	74	405	3	24	1	16	0	1	16	0	0	3.0	
i 1	48.50877551020408	0.505	71	903	3	1	6	8	0	-1	8	0	0	2.0	
i 1	48.74938775510204	1.5150000000000001	74	89	5	4	15	17	0	1	17	0	0	3.0	
i 1	48.751836734693875	0.2525	74	89	7	1	6	8	0	-2	8	0	0	2.0	
i 1	48.751836734693875	1.5150000000000001	69	405	4	4	16	0	0	0	0	0	0	3.0	
i 1	48.754285714285714	1.01	74	405	3	1	4	16	0	1	16	0	0	2.0	
i 1	48.99367346938776	0.7575000000000001	74	89	5	1	16	8	0	-2	8	0	0	2.0	
i 1	49.25224489795919	0.7575000000000001	72	89	4	5	12	2	0	1	2	0	0	5.112110450027318	
i 1	49.25469387755102	0.7575000000000001	74	405	6	5	1	16	0	1	16	0	0	5.112110450027318	
i 1	49.498979591836736	0.2525	73	89	2	24	3	8	0	-1	8	0	0	14.0	
i 1	49.50551020408163	0.7575000000000001	73	405	1	24	11	2	0	-1	2	0	0	14.0	
i 1	49.50877551020408	0.2525	71	903	4	20	7	1	0	0	1	0	0	10.0	
i 1	49.74081632653061	0.2525	75	903	4	5	5	8	0	-2	8	0	0	5.112110450027318	
i 1	49.74367346938776	0.505	68	903	1	20	6	0	0	0	0	0	0	10.0	
i 1	49.74612244897959	0.505	71	903	3	20	13	1	0	0	1	0	0	10.0	
i 1	49.751836734693875	0.2525	72	405	5	3	2	0	0	-1	0	0	0	3.0	
i 1	49.75387755102041	0.2525	74	903	5	1	12	2	0	-1	2	0	0	2.0	
i 1	49.75714285714286	0.505	74	405	3	24	11	16	0	1	16	0	0	3.0	
i 1	49.75959183673469	0.2525	74	89	5	24	1	8	0	-2	8	0	0	3.0	
i 1	49.99122448979592	0.2525	73	405	3	20	5	8	0	-1	8	0	0	10.0	
i 1	49.99448979591837	0.2525	72	903	3	5	15	8	0	-2	8	0	0	5.112110450027318	
i 1	49.994897959183675	1.01	71	903	6	1	1	2	0	-2	2	0	0	2.0	
i 1	49.994897959183675	0.2525	74	89	5	24	3	8	0	-2	8	0	0	3.0	
i 1	49.99734693877551	0.2525	75	903	6	5	1	2	0	-2	2	0	0	5.112110450027318	
i 1	49.99938775510204	0.7575000000000001	74	903	6	1	15	2	0	-1	2	0	0	2.0	
i 1	50.00061224489796	0.2525	74	405	6	1	16	16	0	1	16	0	0	2.0	
i 1	50.2465306122449	7.8275	61	587	4	7	13	9	0	1	9	0	0	5.645614572289043	
i 1	50.2469387755102	0.2525	69	587	5	3	9	0	0	0	0	0	0	3.0	
i 1	50.25265306122449	1.01	72	587	4	4	5	0	0	-1	0	0	0	3.0	
i 1	50.25265306122449	0.7575000000000001	77	201	7	5	15	17	0	2	17	0	0	5.112110450027318	
i 1	50.254285714285714	1.01	70	201	1	20	1	8	0	-1	8	0	0	10.0	
i 1	50.25469387755102	0.7575000000000001	77	587	4	5	9	17	0	1	17	0	0	5.112110450027318	
i 1	50.255918367346936	1.01	73	201	4	20	14	2	0	-1	2	0	0	10.0	
i 1	50.25714285714286	1.01	70	201	2	20	16	8	0	-2	8	0	0	10.0	
i 1	50.25795918367347	0.505	74	201	6	1	11	16	0	1	16	0	0	2.0	
i 1	50.25959183673469	0.2525	72	201	5	4	11	1	0	-1	1	0	0	3.0	
i 1	50.25959183673469	1.01	70	201	3	20	8	2	0	-2	2	0	0	10.0	
i 1	50.49204081632653	0.7575000000000001	69	201	6	9	6	1	0	0	1	0	0	2.0	
i 1	50.49204081632653	0.2525	69	201	6	3	1	1	0	0	1	0	0	3.0	
i 1	50.5030612244898	0.505	74	201	7	1	1	17	0	2	17	0	0	2.0	
i 1	50.75020408163265	1.5150000000000001	75	903	6	5	4	2	0	-2	2	0	0	5.112110450027318	
i 1	50.99040816326531	0.2525	77	587	6	5	7	17	0	1	17	0	0	5.112110450027318	
i 1	50.994897959183675	0.7575000000000001	74	201	6	1	3	16	0	1	16	0	0	2.0	
i 1	50.99530612244898	1.01	74	201	4	5	12	17	0	1	17	0	0	5.112110450027318	
i 1	50.995714285714286	0.2525	77	201	3	5	15	17	0	2	17	0	0	5.112110450027318	
i 1	51.0030612244898	0.2525	74	587	6	1	5	16	0	2	16	0	0	2.0	
i 1	51.00387755102041	0.7575000000000001	74	903	6	1	6	2	0	-1	2	0	0	2.0	
i 1	51.24	0.2525	74	903	4	2	6	16	0	1	16	0	0	3.0	
i 1	51.241632653061224	0.2525	69	201	6	9	8	1	0	0	1	0	0	2.0	
i 1	51.244897959183675	0.2525	73	201	2	24	13	8	0	-1	8	0	0	14.0	
i 1	51.251836734693875	0.505	73	201	1	24	10	2	0	-2	2	0	0	14.0	
i 1	51.25714285714286	0.2525	70	903	4	20	5	8	0	-1	8	0	0	10.0	
i 1	51.25959183673469	0.2525	73	587	4	20	14	2	0	-1	2	0	0	10.0	
i 1	51.495714285714286	0.2525	70	201	4	20	16	8	0	-1	8	0	0	10.0	
i 1	51.49612244897959	0.505	77	903	6	2	1	16	0	2	16	0	0	3.0	
i 1	51.49734693877551	0.2525	70	201	1	20	14	8	0	-1	8	0	0	10.0	
i 1	51.49979591836735	0.2525	69	201	6	3	8	1	0	0	1	0	0	3.0	
i 1	51.50020408163265	0.2525	70	201	3	20	7	8	0	-2	8	0	0	10.0	
i 1	51.74285714285714	1.01	75	903	6	5	14	8	0	-2	8	0	0	5.112110450027318	
i 1	51.74530612244898	0.505	72	405	5	3	13	1	0	-1	1	0	0	3.0	
i 1	51.74612244897959	0.7575000000000001	70	201	2	20	3	8	0	-2	8	0	0	10.0	
i 1	51.74734693877551	0.2525	73	587	4	20	12	8	0	-2	8	0	0	10.0	
i 1	51.75387755102041	0.2525	70	405	1	24	8	8	0	-2	8	0	0	14.0	
i 1	51.754285714285714	0.2525	74	201	7	1	5	17	0	2	17	0	0	2.0	
i 1	51.75714285714286	0.2525	71	903	4	1	3	2	0	-2	2	0	0	2.0	
i 1	51.758367346938776	0.2525	73	903	4	20	8	2	0	-2	2	0	0	10.0	
i 1	51.75877551020408	1.01	74	405	3	5	8	16	0	2	16	0	0	5.112110450027318	
i 1	51.99367346938776	1.01	74	405	6	1	7	16	0	1	16	0	0	2.0	
i 1	51.998163265306125	0.505	70	405	3	20	16	2	0	-1	2	0	0	10.0	
i 1	52.00020408163265	1.01	74	903	4	1	16	2	0	-1	2	0	0	2.0	
i 1	52.0030612244898	0.2525	77	903	4	2	11	16	0	2	16	0	0	3.0	
i 1	52.00387755102041	0.505	73	405	1	20	5	2	0	-1	2	0	0	10.0	
i 1	52.008367346938776	0.505	73	201	4	20	13	2	0	-1	2	0	0	10.0	
i 1	52.24530612244898	1.01	72	405	4	4	16	0	0	-1	0	0	0	3.0	
i 1	52.24938775510204	0.7575000000000001	69	587	5	3	3	0	0	0	0	0	0	3.0	
i 1	52.49448979591837	0.2525	73	587	4	20	12	8	0	-1	8	0	0	10.0	
i 1	52.498163265306125	0.2525	73	903	4	20	15	2	0	-1	2	0	0	10.0	
i 1	52.498163265306125	0.505	70	405	1	24	9	8	0	-2	8	0	0	14.0	
i 1	52.49979591836735	0.2525	73	201	4	24	11	8	0	-1	8	0	0	14.0	
i 1	52.74040816326531	0.7575000000000001	77	405	3	5	7	16	0	1	16	0	0	5.112110450027318	
i 1	52.74040816326531	0.2525	73	405	3	20	9	2	0	-2	2	0	0	10.0	
i 1	52.74285714285714	0.2525	73	405	1	20	8	2	0	-1	2	0	0	10.0	
i 1	52.754285714285714	0.2525	73	201	4	20	4	8	0	-1	8	0	0	10.0	
i 1	52.75551020408163	0.7575000000000001	77	587	6	5	14	17	0	1	17	0	0	5.112110450027318	
i 1	52.99204081632653	0.2525	69	587	4	3	1	0	0	0	0	0	0	3.0	
i 1	52.99285714285714	2.02	73	201	4	20	8	8	0	-1	8	0	0	3.0	
i 1	52.993265306122446	1.01	74	587	4	24	4	17	0	1	17	0	0	3.0	
i 1	52.994081632653064	0.7575000000000001	74	405	4	24	9	16	0	1	16	0	0	3.0	
i 1	53.00061224489796	1.01	73	405	3	20	12	2	0	-2	2	0	0	3.0	
i 1	53.0034693877551	1.01	73	405	1	20	8	2	0	-1	2	0	0	3.0	
i 1	53.00387755102041	0.7575000000000001	74	587	4	1	14	16	0	2	16	0	0	2.0	
i 1	53.00387755102041	1.01	70	405	1	24	11	8	0	-2	8	0	0	7.0	
i 1	53.24	1.01	69	201	6	9	14	1	0	0	1	0	0	2.0	
i 1	53.24734693877551	0.7575000000000001	72	587	4	4	14	0	0	-1	0	0	0	3.0	
i 1	53.49040816326531	1.01	74	587	6	5	5	16	0	1	16	0	0	5.112110450027318	
i 1	53.49204081632653	1.2625	75	903	4	5	2	2	0	-2	2	0	0	5.112110450027318	
i 1	53.49775510204081	1.01	74	201	7	5	3	17	0	1	17	0	0	5.112110450027318	
i 1	53.758367346938776	0.2525	77	201	6	1	2	16	0	1	16	0	0	2.0	
i 1	53.991632653061224	0.505	74	201	6	1	9	17	0	2	17	0	0	2.0	
i 1	53.994081632653064	1.01	70	201	4	20	2	8	0	-2	8	0	0	3.0	
i 1	53.99612244897959	0.2525	72	587	4	4	5	0	0	-1	0	0	0	3.0	
i 1	53.99857142857143	0.2525	70	201	4	20	5	2	0	-1	2	0	0	3.0	
i 1	54.0034693877551	0.505	71	903	4	1	15	2	0	-2	2	0	0	2.0	
i 1	54.00877551020408	0.2525	73	201	4	24	13	8	0	-1	8	0	0	7.0	
i 1	54.24285714285714	0.7575000000000001	72	587	5	3	5	1	0	0	1	0	0	3.0	
i 1	54.24285714285714	0.7575000000000001	73	587	3	20	16	8	0	-1	8	0	0	3.0	
i 1	54.244897959183675	0.7575000000000001	77	903	6	2	8	16	0	2	16	0	0	3.0	
i 1	54.255102040816325	0.7575000000000001	73	587	3	24	4	2	0	-2	2	0	0	7.0	
i 1	54.49530612244898	0.505	77	587	4	1	1	16	0	2	16	0	0	2.0	
i 1	54.50387755102041	0.2525	74	201	7	5	8	17	0	1	17	0	0	5.112110450027318	
i 1	54.50918367346939	0.7575000000000001	74	903	4	1	15	2	0	-1	2	0	0	2.0	
i 1	54.74	0.7575000000000001	74	587	6	5	11	16	0	1	16	0	0	5.112110450027318	
i 1	54.74367346938776	0.7575000000000001	74	201	7	5	13	17	0	1	17	0	0	5.112110450027318	
i 1	54.99040816326531	0.505	70	201	4	20	1	2	0	-1	2	0	0	3.0	
i 1	54.993265306122446	0.505	70	587	3	24	6	8	0	-2	8	0	0	7.0	
i 1	54.995714285714286	2.02	61	903	3	14	13	16	0	1	16	0	0	11.246573065828398	
i 1	54.998979591836736	0.2525	72	587	4	4	10	0	0	-1	0	0	0	3.0	
i 1	55.00142857142857	0.7575000000000001	70	587	3	20	15	2	0	-1	2	0	0	3.0	
i 1	55.00224489795919	0.2525	77	587	5	1	13	16	0	2	16	0	0	2.0	
i 1	55.0034693877551	0.2525	69	587	5	3	5	0	0	0	0	0	0	3.0	
i 1	55.00959183673469	0.7575000000000001	73	201	4	24	8	8	0	-1	8	0	0	7.0	
i 1	55.24612244897959	0.7575000000000001	69	201	4	9	7	1	0	0	1	0	0	2.0	
i 1	55.24734693877551	1.7675	71	903	4	1	11	2	0	-2	2	0	0	2.0	
i 1	55.24775510204081	0.7575000000000001	72	587	4	4	15	0	0	-1	0	0	0	3.0	
i 1	55.25265306122449	0.2525	74	201	6	1	6	17	0	2	17	0	0	2.0	
i 1	55.49367346938776	0.2525	73	587	4	20	14	8	0	-1	8	0	0	3.0	
i 1	55.49530612244898	1.01	77	587	5	1	9	16	0	2	16	0	0	2.0	
i 1	55.49530612244898	1.5150000000000001	77	587	4	5	15	17	0	1	17	0	0	5.112110450027318	
i 1	55.495714285714286	1.01	74	903	4	1	8	2	0	-1	2	0	0	2.0	
i 1	55.506734693877554	0.2525	70	587	4	24	16	8	0	-2	8	0	0	7.0	
i 1	55.50714285714286	0.505	77	587	3	5	3	17	0	1	17	0	0	5.112110450027318	
i 1	55.7469387755102	0.505	70	201	4	20	13	2	0	-1	2	0	0	3.0	
i 1	55.75061224489796	0.505	73	587	3	20	11	8	0	-1	8	0	0	3.0	
i 1	55.75469387755102	0.7575000000000001	70	201	4	20	3	8	0	-2	8	0	0	3.0	
i 1	55.76	0.7575000000000001	73	587	3	24	16	2	0	-2	2	0	0	7.0	
i 1	55.994081632653064	1.01	69	201	4	9	12	1	0	0	1	0	0	2.0	
i 1	55.99448979591837	1.01	63	903	3	14	2	16	0	2	16	0	0	11.246573065828398	
i 1	56.00061224489796	1.01	74	903	6	2	5	16	0	1	16	0	0	3.0	
i 1	56.00061224489796	1.01	77	587	6	5	3	17	0	1	17	0	0	5.112110450027318	
i 1	56.001020408163264	1.01	77	903	6	2	9	16	0	2	16	0	0	3.0	
i 1	56.244081632653064	0.2525	70	903	4	20	7	8	0	-2	8	0	0	3.0	
i 1	56.25795918367347	0.2525	73	903	4	20	6	8	0	-1	8	0	0	3.0	
i 1	56.49122448979592	0.2525	70	587	3	24	6	8	0	-2	8	0	0	7.0	
i 1	56.49367346938776	0.2525	70	587	3	20	4	2	0	-1	2	0	0	3.0	
i 1	56.49448979591837	0.2525	73	201	4	24	8	8	0	-1	8	0	0	7.0	
i 1	56.498979591836736	0.505	74	201	4	1	11	17	0	2	17	0	0	2.0	
i 1	56.50918367346939	0.2525	73	201	4	20	12	2	0	-2	2	0	0	3.0	
i 1	56.75224489795919	0.2525	73	587	3	20	9	8	0	-1	8	0	0	3.0	
i 1	56.754285714285714	0.2525	73	587	3	24	4	2	0	-2	2	0	0	7.0	
i 1	56.99081632653061	0.2525	73	819	3	24	12	2	0	-1	2	0	0	7.0	
i 1	56.991632653061224	0.2525	73	587	4	20	13	8	0	-1	8	0	0	3.0	
i 1	56.994897959183675	0.7575000000000001	69	587	5	3	13	0	0	0	0	0	0	3.0	
i 1	56.99612244897959	0.2525	70	1085	4	20	7	2	0	-1	2	0	0	3.0	
i 1	56.99857142857143	0.7575000000000001	77	1085	4	5	3	17	0	1	17	0	0	5.112110450027318	
i 1	56.99857142857143	0.7575000000000001	74	201	7	5	8	17	0	1	17	0	0	5.112110450027318	
i 1	56.99979591836735	1.5150000000000001	66	1085	3	14	7	9	0	2	9	0	0	11.246573065828398	
i 1	57.00061224489796	0.2525	77	819	3	1	6	17	0	2	17	0	0	2.0	
i 1	57.001836734693875	1.5150000000000001	66	1085	3	14	7	9	0	1	9	0	0	11.246573065828398	
i 1	57.00551020408163	0.2525	74	587	4	1	6	16	0	2	16	0	0	2.0	
i 1	57.00632653061224	0.2525	70	819	3	20	12	8	0	-1	8	0	0	3.0	
i 1	57.006734693877554	0.7575000000000001	69	819	3	3	14	1	0	-1	1	0	0	3.0	
i 1	57.24367346938776	0.505	77	819	4	24	2	17	0	1	17	0	0	3.0	
i 1	57.25061224489796	0.505	73	201	4	20	13	2	0	-2	2	0	0	3.0	
i 1	57.25061224489796	0.7575000000000001	70	201	4	20	9	8	0	-2	8	0	0	3.0	
i 1	57.255918367346936	0.505	74	587	4	24	15	17	0	1	17	0	0	3.0	
i 1	57.50551020408163	0.505	73	201	4	24	3	8	0	-1	8	0	0	7.0	
i 1	57.74040816326531	0.2525	69	819	4	4	4	0	0	0	0	0	0	3.0	
i 1	57.74081632653061	0.7575000000000001	77	587	4	5	1	17	0	1	17	0	0	5.112110450027318	
i 1	57.741632653061224	0.7575000000000001	74	819	6	5	15	17	0	1	17	0	0	5.112110450027318	
i 1	57.74775510204081	0.2525	73	587	4	24	5	2	0	-2	2	0	0	7.0	
i 1	57.748163265306125	0.7575000000000001	74	1085	4	1	10	16	0	1	16	0	0	2.0	
i 1	57.74938775510204	0.7575000000000001	72	587	4	4	12	0	0	-1	0	0	0	3.0	
i 1	57.74979591836735	0.7575000000000001	74	1085	4	1	1	16	0	2	16	0	0	2.0	
i 1	57.751836734693875	0.7575000000000001	77	201	4	1	2	16	0	1	16	0	0	2.0	
i 1	57.75632653061224	0.2525	70	1085	4	20	10	2	0	-1	2	0	0	3.0	
i 1	58.001020408163264	0.505	61	587	4	7	1	9	0	1	9	0	0	5.645614572289043	
i 1	58.001836734693875	0.505	69	819	3	4	11	0	0	0	0	0	0	3.0	
i 1	58.49040816326531	1.5150000000000001	61	410	4	7	12	9	0	2	9	0	0	5.645614572289043	
i 1	58.49081632653061	1.5150000000000001	61	94	4	14	7	9	0	1	9	0	0	11.246573065828398	
i 1	58.49285714285714	1.5150000000000001	66	94	4	14	14	9	0	1	9	0	0	11.246573065828398	
i 1	58.49367346938776	1.2625	77	94	5	1	1	17	0	2	17	0	0	2.0	
i 1	58.49612244897959	0.2525	74	94	5	5	3	16	0	2	16	0	0	5.112110450027318	
i 1	58.50020408163265	0.2525	69	410	5	3	3	1	0	-1	1	0	0	3.0	
i 1	58.50265306122449	0.2525	72	908	3	4	8	1	0	-1	1	0	0	3.0	
i 1	58.506734693877554	0.2525	74	94	4	5	10	17	0	1	17	0	0	5.112110450027318	
i 1	58.507551020408165	1.2625	74	908	3	1	11	17	0	2	17	0	0	2.0	
i 1	58.74	0.7575000000000001	72	410	4	4	4	1	0	0	1	0	0	3.0	
i 1	58.743265306122446	0.7575000000000001	77	410	4	5	15	17	0	1	17	0	0	5.112110450027318	
i 1	58.74367346938776	1.2625	77	410	4	5	15	17	0	2	17	0	0	5.112110450027318	
i 1	58.74612244897959	0.7575000000000001	69	94	6	9	2	1	0	0	1	0	0	2.0	
i 1	58.7469387755102	0.7575000000000001	77	94	4	5	9	17	0	2	17	0	0	5.112110450027318	
i 1	59.49081632653061	1.01	72	94	7	2	1	0	0	0	0	0	0	3.0	
i 1	59.493265306122446	0.505	77	908	6	5	2	17	0	2	17	0	0	5.112110450027318	
i 1	59.507551020408165	1.01	72	94	6	9	12	1	0	-1	1	0	0	2.0	
i 1	59.741632653061224	0.2525	74	94	7	1	7	17	0	2	17	0	0	2.0	
i 1	59.75877551020408	0.2525	77	94	4	1	13	16	0	1	16	0	0	2.0	
i 1	60.00265306122449	1.01	77	908	3	5	3	17	0	2	17	0	0	4.78130559306412	
i 1	60.00551020408163	5.05	61	410	4	7	3	9	0	2	9	0	0	5.623963140167982	
i 1	60.005918367346936	3.0300000000000002	61	94	4	14	5	9	0	1	9	0	0	11.224921633707336	
i 1	60.00714285714286	1.01	77	410	4	5	8	17	0	2	17	0	0	4.78130559306412	
i 1	60.007551020408165	0.505	74	94	7	1	2	17	0	2	17	0	0	4.487098870211395	
i 1	60.00877551020408	0.505	77	94	4	1	5	16	0	1	16	0	0	4.487098870211395	
i 1	60.00877551020408	2.02	66	94	4	14	8	9	0	1	9	0	0	11.224921633707336	
i 1	60.49081632653061	0.505	77	410	4	1	7	16	0	1	16	0	0	4.487098870211395	
i 1	60.49081632653061	0.7575000000000001	69	94	7	2	12	0	0	-1	0	0	0	3.0	
i 1	60.49857142857143	0.7575000000000001	69	908	5	3	8	0	0	-1	0	0	0	3.0	
i 1	60.50959183673469	0.2525	77	94	7	1	14	17	0	2	17	0	0	4.487098870211395	
i 1	60.50959183673469	0.2525	74	908	3	1	6	17	0	2	17	0	0	4.487098870211395	
i 1	60.74204081632653	0.505	74	908	3	24	11	17	0	1	17	0	0	5.487098870211395	
i 1	60.995714285714286	0.7575000000000001	74	1112	3	5	13	16	0	1	16	0	0	4.78130559306412	
i 1	60.99938775510204	0.7575000000000001	74	94	7	5	13	16	0	2	16	0	0	4.78130559306412	
i 1	61.00551020408163	0.2525	77	410	6	1	5	16	0	1	16	0	0	4.487098870211395	
i 1	61.24367346938776	0.7575000000000001	77	1112	3	1	11	17	0	1	17	0	0	4.487098870211395	
i 1	61.24448979591837	0.2525	69	410	5	3	2	1	0	-1	1	0	0	3.0	
i 1	61.24530612244898	0.2525	72	908	4	4	13	1	0	-1	1	0	0	3.0	
i 1	61.257551020408165	1.2625	72	410	4	4	13	1	0	0	1	0	0	3.0	
i 1	61.25795918367347	0.7575000000000001	74	410	4	24	6	16	0	1	16	0	0	5.487098870211395	
i 1	61.49938775510204	1.01	72	1112	5	9	14	0	0	0	0	0	0	2.0	
i 1	61.751020408163264	1.01	74	94	7	5	16	17	0	1	17	0	0	4.78130559306412	
i 1	61.75632653061224	1.01	74	908	3	5	3	16	0	2	16	0	0	4.78130559306412	
i 1	61.99204081632653	0.2525	74	94	7	1	4	17	0	2	17	0	0	4.487098870211395	
i 1	62.001836734693875	5.555	66	94	6	14	10	9	0	1	9	0	0	11.224921633707336	
i 1	62.00959183673469	0.2525	77	1112	3	1	14	16	0	2	16	0	0	4.487098870211395	
i 1	62.24204081632653	2.02	77	94	7	1	9	17	0	2	17	0	0	4.487098870211395	
i 1	62.25061224489796	1.5150000000000001	74	908	3	1	11	17	0	2	17	0	0	4.487098870211395	
i 1	62.50061224489796	0.7575000000000001	72	94	5	2	3	0	0	0	0	0	0	3.0	
i 1	62.50551020408163	0.7575000000000001	69	1112	5	9	15	1	0	0	1	0	0	2.0	
i 1	62.74530612244898	0.2525	77	908	3	5	10	17	0	2	17	0	0	4.78130559306412	
i 1	62.748979591836736	0.2525	77	410	6	5	15	17	0	2	17	0	0	4.78130559306412	
i 1	62.7534693877551	1.01	77	410	6	5	15	17	0	1	17	0	0	4.78130559306412	
i 1	62.994897959183675	0.7575000000000001	77	1112	5	5	9	17	0	1	17	0	0	4.78130559306412	
i 1	62.99857142857143	4.545	61	94	6	14	15	9	0	1	9	0	0	11.224921633707336	
i 1	63.25265306122449	0.505	72	908	4	4	4	1	0	-1	1	0	0	3.0	
i 1	63.25877551020408	0.7575000000000001	69	410	5	3	12	1	0	-1	1	0	0	3.0	
i 1	63.74081632653061	0.2525	74	94	7	5	9	16	0	2	16	0	0	4.78130559306412	
i 1	63.75551020408163	0.505	69	94	5	4	9	0	0	0	0	0	0	3.0	
i 1	63.75714285714286	0.2525	77	908	3	5	4	17	0	2	17	0	0	4.78130559306412	
i 1	63.75918367346939	0.505	74	94	3	1	2	17	0	2	17	0	0	4.487098870211395	
i 1	63.99367346938776	0.2525	69	410	4	3	11	1	0	-1	1	0	0	3.0	
i 1	64.00755102040816	0.505	74	94	6	5	2	16	0	2	16	0	0	4.78130559306412	
i 1	64.00755102040816	0.505	77	908	5	5	8	17	0	2	17	0	0	4.78130559306412	
i 1	64.25020408163266	0.7575000000000001	72	410	4	4	8	1	0	0	1	0	0	3.0	
i 1	64.25224489795919	1.01	72	94	6	2	13	0	0	0	0	0	0	3.0	
i 1	64.25551020408163	0.505	77	908	5	1	4	17	0	1	17	0	0	4.487098870211395	
i 1	64.25632653061224	0.505	74	94	6	1	15	17	0	2	17	0	0	4.487098870211395	
i 1	64.25673469387755	0.7575000000000001	72	908	5	9	13	0	0	0	0	0	0	2.0	
i 1	64.50265306122449	0.7575000000000001	77	908	5	5	9	17	0	2	17	0	0	4.78130559306412	
i 1	64.50469387755102	0.7575000000000001	77	410	6	5	6	17	0	1	17	0	0	4.78130559306412	
i 1	64.75265306122449	0.2525	77	94	7	1	16	17	0	2	17	0	0	4.487098870211395	
i 1	64.75714285714285	0.2525	74	94	3	1	7	17	0	2	17	0	0	4.487098870211395	
i 1	64.99204081632654	0.2525	72	908	5	9	15	1	0	0	1	0	0	2.0	
i 1	64.99367346938776	0.2525	74	94	5	1	12	17	0	2	17	0	0	4.487098870211395	
i 1	65.00755102040816	0.505	77	94	6	1	3	17	0	2	17	0	0	4.487098870211395	
i 1	65.00877551020409	6.0600000000000005	61	410	5	7	10	9	0	2	9	0	0	5.623963140167982	
i 1	65.24285714285715	0.7575000000000001	72	206	6	3	12	0	0	-1	0	0	0	3.0	
i 1	65.2469387755102	0.7575000000000001	69	94	6	2	13	0	0	-1	0	0	0	3.0	
i 1	65.25551020408163	0.7575000000000001	77	410	6	5	3	17	0	2	17	0	0	4.78130559306412	
i 1	65.2591836734694	0.7575000000000001	74	206	3	5	8	16	0	2	16	0	0	4.78130559306412	
i 1	65.49857142857142	0.2525	77	410	6	1	13	16	0	1	16	0	0	4.487098870211395	
i 1	65.50755102040816	0.2525	74	206	3	24	3	17	0	2	17	0	0	5.487098870211395	
i 1	65.74408163265306	1.01	74	410	4	24	7	16	0	1	16	0	0	5.487098870211395	
i 1	65.75061224489797	1.7675	74	94	6	1	6	17	0	2	17	0	0	4.487098870211395	
i 1	65.75428571428571	1.01	74	908	5	1	7	17	0	1	17	0	0	4.487098870211395	
i 1	65.99	1.01	74	206	5	5	11	16	0	2	16	0	0	4.78130559306412	
i 1	65.99530612244898	1.2625	74	94	7	5	11	16	0	2	16	0	0	4.78130559306412	
i 1	65.99897959183673	0.2525	72	206	5	4	3	0	0	-1	0	0	0	3.0	
i 1	66.00714285714285	0.2525	69	410	5	3	16	1	0	-1	1	0	0	3.0	
i 1	66.01	1.01	77	410	5	5	16	17	0	2	17	0	0	4.78130559306412	
i 1	66.24448979591837	1.2625	72	908	3	9	8	0	0	0	0	0	0	2.0	
i 1	66.25020408163266	0.7575000000000001	72	410	4	4	8	1	0	0	1	0	0	3.0	
i 1	66.75877551020409	1.5150000000000001	77	908	5	1	13	17	0	1	17	0	0	4.487098870211395	
i 1	66.99285714285715	0.2525	77	908	5	5	16	17	0	2	17	0	0	4.78130559306412	
i 1	67.00591836734694	0.505	72	94	6	2	8	0	0	0	0	0	0	3.0	
i 1	67.0091836734694	0.505	72	410	4	4	6	1	0	0	1	0	0	3.0	
i 1	67.24163265306123	0.2525	74	94	7	5	4	17	0	1	17	0	0	4.78130559306412	
i 1	67.25387755102041	0.2525	74	206	5	5	12	17	0	1	17	0	0	4.78130559306412	
i 1	67.49163265306123	0.7575000000000001	69	410	5	3	14	1	0	-1	1	0	0	3.0	
i 1	67.49367346938776	0.505	66	1112	5	14	15	9	0	1	9	0	0	11.224921633707336	
i 1	67.49816326530612	0.7575000000000001	77	410	5	5	2	17	0	1	17	0	0	4.78130559306412	
i 1	67.49857142857142	2.02	77	1112	5	1	4	16	0	1	16	0	0	4.487098870211395	
i 1	67.49938775510203	1.5150000000000001	66	1112	5	14	10	9	0	2	9	0	0	11.224921633707336	
i 1	67.50714285714285	0.505	69	410	4	3	11	0	0	0	0	0	0	3.0	
i 1	67.50877551020409	0.505	77	410	5	5	4	17	0	1	17	0	0	4.78130559306412	
i 1	67.99448979591837	0.2525	69	410	3	3	4	0	0	0	0	0	0	3.0	
i 1	67.99571428571429	1.01	66	1112	5	14	14	9	0	1	9	0	0	11.224921633707336	
i 1	68.00469387755102	1.7675	77	410	6	5	6	17	0	1	17	0	0	4.78130559306412	
i 1	68.24285714285715	0.2525	69	410	4	4	12	1	0	-1	1	0	0	3.0	
i 1	68.24816326530612	0.7575000000000001	77	908	4	5	14	17	0	2	17	0	0	4.78130559306412	
i 1	68.25224489795919	0.7575000000000001	74	908	4	1	5	17	0	1	17	0	0	4.487098870211395	
i 1	68.25224489795919	0.7575000000000001	74	1112	6	5	10	16	0	1	16	0	0	4.78130559306412	
i 1	68.25510204081633	0.7575000000000001	77	1112	5	1	12	16	0	1	16	0	0	4.487098870211395	
i 1	68.25836734693877	0.2525	72	410	4	4	5	1	0	0	1	0	0	3.0	
i 1	68.49571428571429	0.7575000000000001	72	908	4	9	14	0	0	0	0	0	0	2.0	
i 1	68.50224489795919	0.7575000000000001	69	1112	5	2	3	0	0	-1	0	0	0	3.0	
i 1	68.9969387755102	1.01	72	1112	5	2	12	0	0	0	0	0	0	3.0	
i 1	68.9969387755102	1.5150000000000001	69	410	5	3	5	1	0	-1	1	0	0	3.0	
i 1	69.00020408163266	0.7575000000000001	77	410	5	5	8	17	0	1	17	0	0	4.78130559306412	
i 1	69.00102040816327	0.505	77	908	4	1	13	17	0	1	17	0	0	4.487098870211395	
i 1	69.0034693877551	0.7575000000000001	72	908	4	9	8	1	0	0	1	0	0	2.0	
i 1	69.00469387755102	1.5150000000000001	66	1112	5	14	6	6	0	2	6	0	0	1.6490761054648397	
i 1	69.00632653061224	1.01	66	1112	5	14	2	9	0	2	9	0	0	11.224921633707336	
i 1	69.00755102040816	1.5150000000000001	66	1112	5	14	9	9	0	1	9	0	0	11.224921633707336	
i 1	69.24612244897959	1.2625	77	410	5	1	2	16	0	1	16	0	0	4.487098870211395	
i 1	69.25183673469388	0.7575000000000001	74	410	5	1	10	17	0	2	17	0	0	4.487098870211395	
i 1	69.49285714285715	1.5150000000000001	77	410	6	5	11	17	0	2	17	0	0	4.78130559306412	
i 1	69.50183673469388	0.505	69	410	3	3	7	0	0	0	0	0	0	3.0	
i 1	69.50551020408163	0.505	74	410	5	5	16	16	0	2	16	0	0	4.78130559306412	
i 1	69.99	0.505	61	1112	5	13	14	6	0	1	6	0	0	0.40554170511859283	
i 1	69.99489795918367	1.01	74	410	4	5	10	16	0	2	16	0	0	4.78130559306412	
i 1	69.99897959183673	0.7575000000000001	69	410	4	3	13	0	0	0	0	0	0	3.0	
i 1	70.0034693877551	0.505	66	1112	5	14	4	9	0	2	9	0	0	11.224921633707336	
i 1	70.00387755102041	0.505	69	410	3	4	8	1	0	-1	1	0	0	3.0	
i 1	70.0091836734694	2.02	74	410	4	1	9	17	0	2	17	0	0	4.487098870211395	
i 1	70.24367346938776	0.2525	77	1112	5	1	15	16	0	1	16	0	0	4.487098870211395	
i 1	70.25061224489797	0.2525	69	1112	4	2	10	0	0	-1	0	0	0	3.0	
i 1	70.2534693877551	0.2525	74	410	4	24	15	17	0	2	17	0	0	5.487098870211395	
i 1	70.25591836734694	1.01	72	908	4	9	11	1	0	0	1	0	0	2.0	
i 1	70.25714285714285	0.2525	72	410	4	4	4	1	0	0	1	0	0	3.0	
i 1	70.2595918367347	0.2525	74	410	4	24	8	16	0	1	16	0	0	5.487098870211395	
i 1	70.49	0.2525	74	908	4	5	4	17	0	1	17	0	0	4.78130559306412	
i 1	70.49163265306123	1.5150000000000001	61	908	5	14	16	6	0	1	6	0	0	1.6490761054648397	
i 1	70.49163265306123	0.7575000000000001	69	908	4	2	12	1	0	-1	1	0	0	3.0	
i 1	70.49326530612245	1.5150000000000001	66	908	5	14	15	9	0	2	9	0	0	11.224921633707336	
i 1	70.49367346938776	1.5150000000000001	66	908	5	13	1	6	0	2	6	0	0	0.40554170511859283	
i 1	70.5030612244898	1.2625	77	908	4	5	2	16	0	1	16	0	0	4.78130559306412	
i 1	70.50632653061224	1.5150000000000001	77	908	5	1	13	16	0	1	16	0	0	4.487098870211395	
i 1	70.50632653061224	0.2525	77	908	6	5	9	17	0	2	17	0	0	4.78130559306412	
i 1	70.50673469387755	1.5150000000000001	66	908	5	14	4	9	0	2	9	0	0	11.224921633707336	
i 1	70.74489795918367	0.2525	72	908	4	9	1	0	0	0	0	0	0	2.0	
i 1	70.99285714285715	1.01	72	410	4	4	9	1	0	0	1	0	0	3.0	
i 1	70.9965306122449	0.505	69	410	5	3	7	1	0	-1	1	0	0	3.0	
i 1	70.99816326530612	3.2825	66	410	5	15	7	9	0	1	9	0	0	0.8200531719006751	
i 1	71.00020408163266	0.505	69	410	4	4	3	1	0	-1	1	0	0	3.0	
i 1	71.0034693877551	0.7575000000000001	74	410	6	5	5	16	0	2	16	0	0	4.78130559306412	
i 1	71.00551020408163	1.01	61	410	6	7	9	9	0	2	9	0	0	5.623963140167982	
i 1	71.0091836734694	1.01	77	410	4	5	8	17	0	2	17	0	0	4.78130559306412	
i 1	71.5095918367347	0.505	77	410	4	5	7	17	0	1	17	0	0	4.78130559306412	
i 1	71.51	0.505	72	908	4	9	7	0	0	0	0	0	0	2.0	
i 1	71.74734693877551	0.505	74	410	4	24	13	17	0	2	17	0	0	5.487098870211395	
i 1	71.74938775510203	0.2525	72	908	4	9	10	1	0	0	1	0	0	2.0	
i 1	71.99	2.2725	61	410	5	15	13	6	0	1	6	0	0	0.8200531719006751	
i 1	71.99163265306123	2.2725	61	1112	5	14	1	6	0	2	6	0	0	1.6490761054648397	
i 1	71.99163265306123	2.2725	61	1112	5	13	1	6	0	1	6	0	0	0.40554170511859283	
i 1	71.99326530612245	0.7575000000000001	77	796	6	5	9	16	0	2	16	0	0	4.78130559306412	
i 1	71.99408163265306	0.2525	74	796	4	1	3	16	0	1	16	0	0	4.487098870211395	
i 1	71.99938775510203	0.7575000000000001	77	1112	4	5	16	17	0	1	17	0	0	4.78130559306412	
i 1	72.00224489795919	0.2525	69	1112	4	2	3	1	0	-1	1	0	0	3.0	
i 1	72.00224489795919	2.2725	61	410	6	7	5	9	0	2	9	0	0	5.623963140167982	
i 1	72.00469387755102	2.2725	66	1112	5	14	11	9	0	2	9	0	0	11.224921633707336	
i 1	72.00877551020409	0.2525	69	796	4	9	5	1	0	0	1	0	0	2.0	
i 1	72.0095918367347	0.2525	77	1112	5	1	1	17	0	1	17	0	0	4.487098870211395	
i 1	72.0095918367347	2.2725	61	1112	5	14	12	9	0	2	9	0	0	11.224921633707336	
i 1	72.24448979591837	0.7575000000000001	69	410	4	3	5	0	0	0	0	0	0	3.0	
i 1	72.24612244897959	1.01	74	410	4	1	10	17	0	2	17	0	0	4.487098870211395	
i 1	72.24897959183673	1.7675	74	410	4	24	7	16	0	1	16	0	0	5.487098870211395	
i 1	72.24897959183673	0.7575000000000001	69	410	4	3	16	1	0	-1	1	0	0	3.0	
i 1	72.26	1.01	77	410	5	1	16	16	0	1	16	0	0	4.487098870211395	
i 1	72.50673469387755	0.2525	69	410	4	4	14	1	0	-1	1	0	0	3.0	
i 1	72.74122448979591	0.7575000000000001	77	410	6	5	10	17	0	1	17	0	0	4.78130559306412	
i 1	72.75836734693877	1.5150000000000001	77	410	4	5	5	17	0	1	17	0	0	4.78130559306412	
i 1	73.00020408163266	2.02	61	796	4	16	10	6	0	2	6	0	0	1.2345646386827576	
i 1	73.0095918367347	1.2625	72	410	4	4	6	1	0	0	1	0	0	3.0	
i 1	73.0095918367347	1.7675	69	410	4	4	5	1	0	-1	1	0	0	3.0	
i 1	73.25632653061224	0.7575000000000001	74	410	4	24	2	17	0	2	17	0	0	5.487098870211395	
i 1	73.5034693877551	0.7575000000000001	77	410	4	5	7	17	0	2	17	0	0	4.78130559306412	
i 1	73.50387755102041	0.7575000000000001	74	410	6	5	12	16	0	2	16	0	0	4.78130559306412	
i 1	73.5095918367347	0.2525	69	796	4	9	16	1	0	0	1	0	0	2.0	
i 1	73.99326530612245	1.01	61	796	4	16	1	6	0	1	6	0	0	1.2345646386827576	
i 1	73.99816326530612	0.2525	77	1112	5	1	11	16	0	2	16	0	0	4.487098870211395	
i 1	74.0030612244898	0.2525	77	796	4	1	15	16	0	2	16	0	0	4.487098870211395	
i 1	74.24	0.7575000000000001	74	410	4	1	8	17	0	2	17	0	0	4.487098870211395	
i 1	74.24122448979591	0.7575000000000001	66	178	6	15	16	9	0	2	9	0	0	0.8200531719006751	
i 1	74.24244897959184	0.505	77	796	3	5	10	17	0	1	17	0	0	4.78130559306412	
i 1	74.24285714285715	0.505	77	1111	4	5	5	16	0	1	16	0	0	4.78130559306412	
i 1	74.24571428571429	0.7575000000000001	66	1111	5	14	2	9	0	2	9	0	0	11.224921633707336	
i 1	74.24816326530612	0.7575000000000001	66	1111	5	14	6	9	0	2	9	0	0	11.224921633707336	
i 1	74.25020408163266	0.7575000000000001	74	1111	5	1	5	17	0	2	17	0	0	4.487098870211395	
i 1	74.25020408163266	0.7575000000000001	61	1111	5	14	3	6	0	2	6	0	0	1.6490761054648397	
i 1	74.25020408163266	0.7575000000000001	61	178	6	7	4	6	0	1	6	0	0	5.623963140167982	
i 1	74.25428571428571	0.2525	74	1111	5	1	12	17	0	1	17	0	0	4.487098870211395	
i 1	74.25510204081633	0.7575000000000001	66	1111	5	13	13	6	0	1	6	0	0	0.40554170511859283	
i 1	74.25551020408163	0.7575000000000001	61	178	6	15	15	9	0	1	9	0	0	0.8200531719006751	
i 1	74.25877551020409	0.505	69	178	6	3	11	0	0	0	0	0	0	3.0	
i 1	74.49775510204081	0.505	74	1111	4	5	8	16	0	1	16	0	0	4.78130559306412	
i 1	74.49938775510203	0.505	69	796	3	9	10	0	0	-1	0	0	0	2.0	
i 1	74.50142857142858	0.505	74	410	6	5	8	16	0	2	16	0	0	4.78130559306412	
i 1	74.5095918367347	0.505	72	178	4	4	15	0	0	0	0	0	0	3.0	
i 1	74.75265306122449	0.2525	77	178	4	5	5	16	0	2	16	0	0	4.78130559306412	
i 1	74.75795918367346	0.2525	72	1111	6	2	12	0	0	-1	0	0	0	3.0	
i 1	74.75877551020409	0.2525	74	1111	5	1	13	17	0	1	17	0	0	4.487098870211395	
i 1	74.9908163265306	2.2725	61	410	5	12	16	6	0	1	6	0	0	2.452305891843159	
i 1	74.99163265306123	2.2725	61	178	6	15	15	9	0	1	9	0	0	2.0377944250610764	
i 1	74.99163265306123	0.7575000000000001	74	410	3	5	1	16	0	2	16	0	0	4.785353560073817	
i 1	74.99326530612245	0.7575000000000001	74	1111	4	5	12	16	0	1	16	0	0	4.785353560073817	
i 1	74.99408163265306	0.2525	69	796	3	9	2	1	0	0	1	0	0	12.0	
i 1	74.99571428571429	2.02	61	1111	5	14	2	6	0	2	6	0	0	2.866817358625241	
i 1	74.99897959183673	0.505	74	1111	5	1	10	17	0	2	17	0	0	8.125276332754941	
i 1	75.00061224489797	0.2525	77	796	3	5	3	17	0	1	17	0	0	4.785353560073817	
i 1	75.00183673469388	0.505	74	410	4	1	7	17	0	2	17	0	0	8.125276332754941	
i 1	75.0034693877551	0.7575000000000001	74	1111	5	1	2	17	0	1	17	0	0	8.125276332754941	
i 1	75.00428571428571	2.2725	66	178	6	15	3	9	0	2	9	0	0	2.0377944250610764	
i 1	75.00551020408163	2.2725	61	796	4	16	10	6	0	2	6	0	0	2.452305891843159	
i 1	75.00755102040816	2.2725	61	796	4	16	2	6	0	1	6	0	0	2.452305891843159	
i 1	75.00755102040816	0.505	69	796	3	9	3	0	0	-1	0	0	0	12.0	
i 1	75.00795918367346	2.2725	66	1111	5	13	10	6	0	1	6	0	0	1.623282958278994	
i 1	75.01	0.505	72	178	5	4	11	0	0	0	0	0	0	13.0	
i 1	75.24	1.01	74	178	4	5	9	16	0	1	16	0	0	4.785353560073817	
i 1	75.24448979591837	0.7575000000000001	72	1111	6	2	6	0	0	-1	0	0	0	13.0	
i 1	75.24571428571429	0.7575000000000001	69	410	4	3	10	0	0	0	0	0	0	13.0	
i 1	75.25224489795919	0.505	74	796	4	1	10	16	0	1	16	0	0	8.125276332754941	
i 1	75.2530612244898	0.7575000000000001	77	410	6	5	8	17	0	1	17	0	0	4.785353560073817	
i 1	75.74816326530612	1.01	74	410	4	1	8	17	0	2	17	0	0	8.125276332754941	
i 1	75.74938775510203	1.01	74	1111	5	1	6	17	0	2	17	0	0	8.125276332754941	
i 1	75.75551020408163	0.2525	77	178	5	1	7	16	0	2	16	0	0	8.125276332754941	
i 1	75.99244897959184	1.2625	66	410	5	12	13	6	0	2	6	0	0	2.452305891843159	
i 1	75.99367346938776	0.2525	69	1111	6	2	12	1	0	0	1	0	0	13.0	
i 1	75.99612244897959	0.2525	77	410	3	5	16	17	0	1	17	0	0	4.785353560073817	
i 1	75.99938775510203	0.2525	72	1111	6	2	9	0	0	-1	0	0	0	13.0	
i 1	76.00387755102041	0.2525	69	410	3	3	13	0	0	0	0	0	0	13.0	
i 1	76.24	0.7575000000000001	77	178	4	5	15	16	0	2	16	0	0	4.785353560073817	
i 1	76.2404081632653	0.7575000000000001	77	796	3	5	2	16	0	2	16	0	0	4.785353560073817	
i 1	76.24204081632654	1.01	77	178	5	1	3	16	0	2	16	0	0	8.125276332754941	
i 1	76.2534693877551	1.01	77	1111	4	5	16	16	0	1	16	0	0	4.785353560073817	
i 1	76.25551020408163	0.7575000000000001	69	410	4	4	5	1	0	-1	1	0	0	13.0	
i 1	76.2595918367347	0.7575000000000001	69	178	6	3	8	0	0	0	0	0	0	13.0	
i 1	76.74734693877551	0.505	74	410	4	24	3	17	0	2	17	0	0	9.125276332754941	
i 1	76.75020408163266	0.505	77	796	3	5	6	17	0	1	17	0	0	4.785353560073817	
i 1	76.75102040816327	0.2525	74	178	5	24	11	17	0	1	17	0	0	9.125276332754941	
i 1	76.75428571428571	0.2525	69	796	3	9	16	1	0	0	1	0	0	12.0	
i 1	76.9908163265306	0.2525	69	178	6	3	12	0	0	0	0	0	0	13.0	
i 1	76.99122448979591	0.2525	77	410	3	5	1	17	0	1	17	0	0	4.785353560073817	
i 1	76.99204081632654	0.2525	72	178	5	4	14	0	0	0	0	0	0	13.0	
i 1	77.00469387755102	0.2525	61	1111	5	14	5	6	0	2	6	0	0	2.866817358625241	
i 1	77.00795918367346	0.2525	69	410	3	4	1	1	0	-1	1	0	0	13.0	
i 1	77.2408163265306	0.2525	77	901	4	5	7	17	0	2	17	0	0	4.785353560073817	
i 1	77.24326530612245	0.505	77	403	3	5	6	17	0	2	17	0	0	4.785353560073817	
i 1	77.24367346938776	1.7675	61	901	5	14	1	9	0	2	9	0	0	2.866817358625241	
i 1	77.2465306122449	0.7575000000000001	61	901	5	13	6	6	0	1	6	0	0	1.623282958278994	
i 1	77.2465306122449	0.7575000000000001	69	87	5	4	15	0	0	0	0	0	0	13.0	
i 1	77.24734693877551	5.8075	61	901	5	12	13	6	0	2	6	0	0	2.452305891843159	
i 1	77.25020408163266	2.7775	61	87	6	15	11	9	0	2	9	0	0	2.0377944250610764	
i 1	77.2534693877551	4.7975	61	403	4	16	1	6	0	2	6	0	0	2.452305891843159	
i 1	77.2534693877551	6.8175	61	901	5	12	16	9	0	1	9	0	0	2.452305891843159	
i 1	77.2534693877551	1.2625	77	87	4	5	12	17	0	1	17	0	0	4.785353560073817	
i 1	77.25428571428571	1.01	77	901	5	1	7	16	0	2	16	0	0	8.125276332754941	
i 1	77.25428571428571	1.7675	66	87	6	15	6	6	0	2	6	0	0	2.0377944250610764	
i 1	77.25551020408163	1.2625	74	901	2	5	5	16	0	2	16	0	0	4.785353560073817	
i 1	77.25591836734694	1.01	74	403	4	1	9	16	0	1	16	0	0	8.125276332754941	
i 1	77.25591836734694	1.01	69	901	2	4	13	0	0	0	0	0	0	13.0	
i 1	77.2595918367347	3.7875	61	403	4	16	1	9	0	1	9	0	0	2.452305891843159	
i 1	77.49489795918367	0.2525	77	87	5	1	1	17	0	2	17	0	0	8.125276332754941	
i 1	77.4965306122449	0.2525	72	901	2	3	11	1	0	0	1	0	0	13.0	
i 1	77.74204081632654	1.01	77	87	4	5	1	16	0	1	16	0	0	4.785353560073817	
i 1	77.75183673469388	1.2625	77	901	5	1	1	17	0	1	17	0	0	8.125276332754941	
i 1	77.75591836734694	0.2525	72	901	6	2	15	0	0	0	0	0	0	13.0	
i 1	77.75714285714285	1.2625	74	403	4	1	8	17	0	1	17	0	0	8.125276332754941	
i 1	77.99163265306123	0.7575000000000001	77	901	3	5	3	16	0	1	16	0	0	4.785353560073817	
i 1	77.99244897959184	2.02	61	901	5	13	10	6	0	1	6	0	0	1.623282958278994	
i 1	77.99408163265306	1.2625	69	87	6	3	10	1	0	-1	1	0	0	13.0	
i 1	77.99612244897959	1.2625	72	901	5	3	5	1	0	0	1	0	0	13.0	
i 1	78.00020408163266	0.505	69	403	5	9	16	1	0	0	1	0	0	12.0	
i 1	78.00061224489797	0.2525	69	87	5	4	8	0	0	0	0	0	0	13.0	
i 1	78.01	0.505	72	901	6	2	10	0	0	-1	0	0	0	13.0	
i 1	78.24204081632654	1.2625	74	403	3	5	11	17	0	1	17	0	0	4.785353560073817	
i 1	78.25061224489797	1.2625	77	901	5	5	4	17	0	2	17	0	0	4.785353560073817	
i 1	78.25102040816327	0.7575000000000001	77	901	4	5	12	17	0	1	17	0	0	4.785353560073817	
i 1	78.49163265306123	0.2525	69	403	5	9	14	0	0	-1	0	0	0	12.0	
i 1	78.50591836734694	0.2525	77	901	3	1	16	17	0	1	17	0	0	8.125276332754941	
i 1	78.75061224489797	1.5150000000000001	74	403	4	1	7	16	0	1	16	0	0	8.125276332754941	
i 1	78.75877551020409	1.2625	77	901	5	1	15	16	0	2	16	0	0	8.125276332754941	
i 1	78.99204081632654	1.01	69	403	5	9	13	0	0	-1	0	0	0	12.0	
i 1	78.99285714285715	1.01	72	901	6	2	4	0	0	0	0	0	0	13.0	
i 1	78.9969387755102	2.02	66	87	6	15	16	6	0	2	6	0	0	2.0377944250610764	
i 1	78.99775510204081	1.2625	77	901	5	5	11	17	0	1	17	0	0	4.785353560073817	
i 1	79.0095918367347	0.2525	74	901	3	24	4	17	0	1	17	0	0	9.125276332754941	
i 1	79.24938775510203	1.01	77	403	3	5	14	17	0	2	17	0	0	4.785353560073817	
i 1	79.50551020408163	0.2525	77	901	3	5	15	16	0	1	16	0	0	4.785353560073817	
i 1	79.50877551020409	1.5150000000000001	74	403	4	1	13	17	0	1	17	0	0	8.125276332754941	
i 1	79.7408163265306	0.2525	69	403	5	9	1	1	0	0	1	0	0	12.0	
i 1	79.74204081632654	1.2625	77	901	5	1	4	17	0	1	17	0	0	8.125276332754941	
i 1	79.74857142857142	1.5150000000000001	77	87	5	1	11	17	0	2	17	0	0	8.125276332754941	
i 1	79.9969387755102	0.7575000000000001	72	901	5	2	4	0	0	0	0	0	0	13.0	
i 1	79.99897959183673	1.5150000000000001	74	901	2	5	15	16	0	2	16	0	0	4.785353560073817	
i 1	79.99938775510203	1.2625	77	87	5	5	13	17	0	1	17	0	0	4.785353560073817	
i 1	80.00020408163266	0.7575000000000001	69	403	5	9	10	0	0	-1	0	0	0	12.0	
i 1	80.00061224489797	2.02	61	87	6	15	14	9	0	2	9	0	0	2.0377944250610764	
i 1	80.00510204081633	0.2525	69	87	5	4	3	0	0	0	0	0	0	13.0	
i 1	80.00632653061224	0.2525	77	901	6	1	1	16	0	2	16	0	0	8.125276332754941	
i 1	80.25428571428571	0.2525	77	901	3	5	12	16	0	1	16	0	0	4.785353560073817	
i 1	80.49897959183673	0.505	72	901	5	3	9	1	0	0	1	0	0	13.0	
i 1	80.49938775510203	0.2525	77	901	5	5	14	17	0	2	17	0	0	4.785353560073817	
i 1	80.5095918367347	0.7575000000000001	77	901	3	1	8	17	0	1	17	0	0	8.125276332754941	
i 1	80.74367346938776	0.2525	77	87	4	5	6	16	0	1	16	0	0	4.785353560073817	
i 1	80.74571428571429	0.7575000000000001	74	901	3	24	13	17	0	1	17	0	0	9.125276332754941	
i 1	80.75102040816327	0.2525	69	87	6	3	16	1	0	-1	1	0	0	13.0	
i 1	80.75387755102041	1.2625	69	87	5	4	9	0	0	0	0	0	0	13.0	
i 1	80.75591836734694	0.7575000000000001	77	87	5	24	11	17	0	2	17	0	0	9.125276332754941	
i 1	80.75877551020409	1.01	77	901	3	5	8	16	0	1	16	0	0	4.785353560073817	
i 1	81.00591836734694	2.02	61	403	4	16	16	9	0	1	9	0	0	2.452305891843159	
i 1	81.00632653061224	0.505	69	87	5	3	12	1	0	-1	1	0	0	13.0	
i 1	81.00673469387755	0.7575000000000001	77	87	5	5	1	16	0	1	16	0	0	4.785353560073817	
i 1	81.0091836734694	0.505	72	901	5	3	6	1	0	0	1	0	0	13.0	
i 1	81.25061224489797	1.5150000000000001	77	901	6	1	10	16	0	2	16	0	0	8.125276332754941	
i 1	81.25795918367346	1.2625	74	403	4	1	6	16	0	1	16	0	0	8.125276332754941	
i 1	81.49489795918367	0.2525	72	901	5	2	16	0	0	0	0	0	0	13.0	
i 1	81.49775510204081	0.505	74	403	3	5	16	17	0	1	17	0	0	4.785353560073817	
i 1	81.49816326530612	1.5150000000000001	77	901	5	5	4	17	0	2	17	0	0	4.785353560073817	
i 1	81.50510204081633	0.505	69	901	4	4	14	0	0	0	0	0	0	13.0	
i 1	81.74326530612245	0.2525	74	901	3	24	4	17	0	1	17	0	0	9.125276332754941	
i 1	81.99326530612245	2.02	61	403	4	16	10	6	0	2	6	0	0	2.452305891843159	
i 1	81.99857142857142	0.505	77	403	3	5	14	17	0	2	17	0	0	4.785353560073817	
i 1	81.99938775510203	0.2525	77	87	5	24	12	17	0	2	17	0	0	9.125276332754941	
i 1	82.00020408163266	0.2525	69	901	4	4	11	0	0	0	0	0	0	13.0	
i 1	82.00142857142858	0.2525	69	87	5	4	13	0	0	0	0	0	0	13.0	
i 1	82.00877551020409	1.01	74	403	4	5	1	17	0	1	17	0	0	4.785353560073817	
i 1	82.2404081632653	2.7775	74	403	4	1	15	17	0	1	17	0	0	8.125276332754941	
i 1	82.25551020408163	0.7575000000000001	69	403	5	9	9	1	0	0	1	0	0	12.0	
i 1	82.25795918367346	3.0300000000000002	77	901	6	1	15	17	0	1	17	0	0	8.125276332754941	
i 1	82.25836734693877	0.505	72	901	4	2	1	0	0	-1	0	0	0	13.0	
i 1	82.49734693877551	1.7675	72	901	5	3	3	1	0	0	1	0	0	13.0	
i 1	82.49734693877551	0.505	77	901	3	5	13	16	0	1	16	0	0	4.785353560073817	
i 1	82.49979591836734	1.5150000000000001	77	87	5	5	2	17	0	1	17	0	0	4.785353560073817	
i 1	82.50632653061224	1.5150000000000001	69	87	5	3	3	1	0	-1	1	0	0	13.0	
i 1	82.50755102040816	0.505	77	87	5	5	3	16	0	1	16	0	0	4.785353560073817	
i 1	82.75551020408163	1.2625	74	901	2	5	5	16	0	2	16	0	0	4.785353560073817	
i 1	82.99816326530612	0.2525	77	403	4	5	14	17	0	2	17	0	0	4.785353560073817	
i 1	83.00591836734694	2.02	61	901	4	12	2	6	0	2	6	0	0	2.452305891843159	
i 1	83.01	2.2725	72	901	4	2	4	0	0	0	0	0	0	13.0	
i 1	83.25102040816327	0.505	74	901	3	24	4	17	0	1	17	0	0	9.125276332754941	
i 1	83.5091836734694	0.2525	74	403	4	5	6	17	0	1	17	0	0	4.785353560073817	
i 1	83.74	1.2625	77	87	5	5	8	16	0	1	16	0	0	4.785353560073817	
i 1	83.75428571428571	1.2625	77	901	3	5	16	16	0	1	16	0	0	4.785353560073817	
i 1	83.99	0.7575000000000001	77	901	6	1	12	16	0	2	16	0	0	8.125276332754941	
i 1	83.99122448979591	2.02	61	901	4	12	9	9	0	1	9	0	0	2.452305891843159	
i 1	83.99367346938776	0.2525	69	87	4	3	9	1	0	-1	1	0	0	13.0	
i 1	84.00265306122449	1.2625	69	403	4	9	12	0	0	-1	0	0	0	12.0	
i 1	84.00591836734694	0.2525	77	403	4	5	5	17	0	2	17	0	0	4.785353560073817	
i 1	84.00795918367346	0.7575000000000001	74	403	6	1	4	16	0	1	16	0	0	8.125276332754941	
i 1	84.24734693877551	0.2525	72	901	4	2	1	0	0	-1	0	0	0	13.0	
i 1	84.49	0.505	77	901	5	5	9	17	0	2	17	0	0	4.785353560073817	
i 1	84.50673469387755	1.2625	74	403	4	5	5	17	0	1	17	0	0	4.785353560073817	
i 1	84.74	1.2625	77	87	7	1	8	17	0	2	17	0	0	8.125276332754941	
i 1	84.74204081632654	1.2625	77	901	3	1	12	17	0	1	17	0	0	8.125276332754941	
i 1	84.7534693877551	0.2525	69	403	4	9	1	1	0	0	1	0	0	12.0	
i 1	84.99857142857142	0.7575000000000001	77	901	6	5	9	17	0	2	17	0	0	4.785353560073817	
i 1	84.99897959183673	0.505	74	403	6	1	9	17	0	1	17	0	0	8.125276332754941	
i 1	85.00102040816327	0.7575000000000001	72	901	3	3	4	1	0	0	1	0	0	13.0	
i 1	85.00877551020409	0.7575000000000001	69	87	4	3	14	1	0	-1	1	0	0	13.0	
i 1	85.0095918367347	1.01	77	901	5	5	12	17	0	1	17	0	0	4.785353560073817	
i 1	85.24489795918367	0.2525	69	87	4	4	9	0	0	0	0	0	0	13.0	
i 1	85.25591836734694	1.01	77	403	4	5	15	17	0	2	17	0	0	4.785353560073817	
i 1	85.49489795918367	1.01	74	901	3	24	7	17	0	1	17	0	0	9.125276332754941	
i 1	85.7408163265306	0.505	77	87	5	24	2	17	0	2	17	0	0	9.125276332754941	
i 1	85.74367346938776	0.2525	69	901	4	4	5	0	0	0	0	0	0	13.0	
i 1	85.74775510204081	2.2725	74	403	6	1	11	16	0	1	16	0	0	8.125276332754941	
i 1	85.74775510204081	1.5150000000000001	69	87	4	4	5	0	0	0	0	0	0	13.0	
i 1	85.75061224489797	1.7675	74	901	3	5	10	16	0	2	16	0	0	4.785353560073817	
i 1	85.75795918367346	2.2725	77	901	6	1	12	16	0	2	16	0	0	8.125276332754941	
i 1	86.00102040816327	1.7675	77	87	5	5	16	16	0	1	16	0	0	4.785353560073817	
i 1	86.0030612244898	1.01	77	87	5	5	15	17	0	1	17	0	0	4.785353560073817	
i 1	86.00428571428571	1.01	69	901	3	4	11	0	0	0	0	0	0	13.0	
i 1	86.00428571428571	0.2525	77	901	6	5	11	17	0	1	17	0	0	4.785353560073817	
i 1	86.00755102040816	2.02	72	901	4	2	5	0	0	-1	0	0	0	13.0	
i 1	86.50877551020409	1.5150000000000001	69	403	3	9	14	1	0	0	1	0	0	12.0	
i 1	86.75387755102041	0.2525	74	901	3	24	13	17	0	1	17	0	0	9.125276332754941	
i 1	86.99367346938776	0.505	77	87	6	5	5	17	0	1	17	0	0	4.785353560073817	
i 1	86.99489795918367	0.2525	77	901	5	1	3	17	0	1	17	0	0	8.125276332754941	
i 1	86.99734693877551	0.7575000000000001	77	901	3	5	3	16	0	1	16	0	0	4.785353560073817	
i 1	87.2534693877551	0.2525	72	901	4	2	6	0	0	0	0	0	0	13.0	
i 1	87.25387755102041	1.5150000000000001	74	403	4	5	9	17	0	1	17	0	0	4.785353560073817	
i 1	87.25632653061224	1.5150000000000001	77	901	6	5	14	17	0	2	17	0	0	4.785353560073817	
i 1	87.49448979591837	1.2625	69	87	4	3	11	1	0	-1	1	0	0	13.0	
i 1	87.49979591836734	1.2625	74	403	6	1	13	17	0	1	17	0	0	8.125276332754941	
i 1	87.50755102040816	2.02	77	901	6	1	13	17	0	1	17	0	0	8.125276332754941	
i 1	87.5091836734694	0.505	72	901	3	3	12	1	0	0	1	0	0	13.0	
i 1	87.75469387755102	0.2525	77	87	6	5	1	17	0	1	17	0	0	4.785353560073817	
i 1	87.99244897959184	0.2525	77	901	6	5	16	17	0	1	17	0	0	4.785353560073817	
i 1	87.99775510204081	0.2525	74	901	4	24	9	17	0	1	17	0	0	9.125276332754941	
i 1	88.00142857142858	0.2525	72	901	4	2	12	0	0	0	0	0	0	13.0	
i 1	88.00142857142858	1.01	72	901	2	3	6	1	0	0	1	0	0	13.0	
i 1	88.24163265306123	1.2625	77	901	3	5	10	16	0	1	16	0	0	4.785353560073817	
i 1	88.24816326530612	1.2625	77	901	6	1	3	16	0	2	16	0	0	8.125276332754941	
i 1	88.25591836734694	0.2525	69	901	3	4	8	0	0	0	0	0	0	13.0	
i 1	88.25836734693877	1.2625	74	403	6	1	13	16	0	1	16	0	0	8.125276332754941	
i 1	88.2591836734694	1.2625	77	87	6	5	9	16	0	1	16	0	0	4.785353560073817	
i 1	88.50265306122449	0.505	72	901	4	2	9	0	0	0	0	0	0	13.0	
i 1	88.50673469387755	1.01	69	403	3	9	13	0	0	-1	0	0	0	12.0	
i 1	88.75224489795919	1.2625	77	87	6	5	12	17	0	1	17	0	0	4.785353560073817	
i 1	88.99857142857142	1.01	69	87	4	3	9	1	0	-1	1	0	0	13.0	
i 1	89.0030612244898	0.505	72	901	6	2	10	0	0	0	0	0	0	13.0	
i 1	89.00755102040816	0.505	74	403	6	1	3	17	0	1	17	0	0	8.125276332754941	
i 1	89.0095918367347	1.01	74	901	3	5	11	16	0	2	16	0	0	4.785353560073817	
i 1	89.24489795918367	0.7575000000000001	77	901	5	1	14	17	0	1	17	0	0	8.125276332754941	
i 1	89.2465306122449	0.7575000000000001	77	87	7	1	1	17	0	2	17	0	0	8.125276332754941	
i 1	89.49122448979591	0.2525	69	901	2	4	2	0	0	0	0	0	0	13.0	
i 1	89.49489795918367	0.505	72	901	2	3	3	1	0	0	1	0	0	13.0	
i 1	89.50632653061224	0.505	77	901	6	5	11	17	0	2	17	0	0	4.785353560073817	
i 1	89.50714285714285	0.2525	74	901	4	24	10	17	0	1	17	0	0	9.125276332754941	
i 1	89.74204081632654	0.2525	74	403	6	1	1	16	0	1	16	0	0	8.125276332754941	
i 1	89.74204081632654	0.2525	77	87	6	5	14	16	0	1	16	0	0	4.785353560073817	
i 1	89.7530612244898	0.2525	77	901	3	5	12	16	0	1	16	0	0	4.785353560073817	
i 1	89.9904081632653	0.7575000000000001	77	87	7	1	3	17	0	2	17	0	0	11.646042300269992	
i 1	89.99163265306123	0.7575000000000001	69	87	4	4	8	0	0	0	0	0	0	3.0000000000000013	
i 1	89.99530612244898	0.2525	74	901	3	5	14	16	0	2	16	0	0	4.935618547531839	
i 1	89.99571428571429	0.7575000000000001	77	87	6	5	4	16	0	1	16	0	0	4.935618547531839	
i 1	89.9965306122449	0.505	69	87	6	3	14	1	0	-1	1	0	0	3.0000000000000013	
i 1	89.99857142857142	1.01	77	901	3	5	5	16	0	1	16	0	0	4.935618547531839	
i 1	90.00142857142858	0.2525	77	87	6	5	13	17	0	1	17	0	0	4.935618547531839	
i 1	90.00183673469388	1.01	74	901	4	24	6	17	0	1	17	0	0	12.646042300269992	
i 1	90.00510204081633	3.7875	77	901	5	1	12	17	0	1	17	0	0	11.646042300269992	
i 1	90.00551020408163	0.7575000000000001	77	901	6	5	3	17	0	2	17	0	0	4.935618547531839	
i 1	90.00632653061224	1.01	69	901	2	4	12	0	0	0	0	0	0	3.0000000000000013	
i 1	90.00714285714285	0.505	72	901	2	3	3	1	0	0	1	0	0	3.0000000000000013	
i 1	90.25061224489797	0.505	77	87	5	24	15	17	0	2	17	0	0	12.646042300269992	
i 1	90.4908163265306	0.505	74	901	3	5	3	16	0	2	16	0	0	4.935618547531839	
i 1	90.49530612244898	0.2525	77	901	6	5	3	17	0	1	17	0	0	4.935618547531839	
i 1	90.49979591836734	0.2525	77	901	6	1	15	17	0	1	17	0	0	11.646042300269992	
i 1	90.50102040816327	0.2525	74	403	6	1	3	16	0	1	16	0	0	11.646042300269992	
i 1	90.5030612244898	0.2525	69	403	3	9	2	0	0	-1	0	0	0	2.0000000000000013	
i 1	90.50755102040816	0.2525	72	901	6	2	7	0	0	-1	0	0	0	3.0000000000000013	
i 1	90.7408163265306	0.505	74	403	6	1	15	16	0	1	16	0	0	11.646042300269992	
i 1	90.7408163265306	0.2525	74	901	6	5	9	2	0	-2	2	0	0	4.935618547531839	
i 1	90.7465306122449	1.2625	71	87	7	5	9	2	0	-2	2	0	0	4.935618547531839	
i 1	90.75142857142858	3.0300000000000002	72	87	7	1	8	2	0	-2	2	0	0	11.646042300269992	
i 1	90.75469387755102	0.2525	75	901	4	4	8	2	0	1	2	0	0	3.0000000000000013	
i 1	90.75551020408163	0.505	75	901	4	24	14	8	0	1	8	0	0	12.646042300269992	
i 1	90.75755102040816	0.7575000000000001	72	87	7	2	7	2	0	-2	2	0	0	3.0000000000000013	
i 1	90.75877551020409	0.7575000000000001	69	403	4	9	5	0	0	-1	0	0	0	2.0000000000000013	
i 1	90.7595918367347	0.2525	71	87	7	5	11	2	0	-2	2	0	0	4.935618547531839	
i 1	90.99408163265306	1.5150000000000001	75	901	5	3	11	2	0	-2	2	0	0	3.0000000000000013	
i 1	91.00836734693877	1.01	74	901	4	5	10	16	0	2	16	0	0	4.935618547531839	
i 1	91.2591836734694	0.2525	74	403	6	5	13	17	0	1	17	0	0	4.935618547531839	
i 1	91.26	1.2625	69	901	2	4	16	0	0	0	0	0	0	3.0000000000000013	
i 1	91.49244897959184	0.2525	74	403	6	1	8	17	0	1	17	0	0	11.646042300269992	
i 1	91.49734693877551	0.505	77	901	3	5	8	16	0	1	16	0	0	4.935618547531839	
i 1	91.5034693877551	0.7575000000000001	74	901	6	5	2	2	0	-1	2	0	0	4.935618547531839	
i 1	91.74204081632654	1.5150000000000001	74	901	6	5	5	2	0	-2	2	0	0	4.935618547531839	
i 1	91.74367346938776	1.5150000000000001	74	403	6	5	12	17	0	1	17	0	0	4.935618547531839	
i 1	91.75714285714285	0.2525	72	87	7	2	13	2	0	-2	2	0	0	3.0000000000000013	
i 1	91.7591836734694	1.01	75	87	7	1	9	2	0	1	2	0	0	11.646042300269992	
i 1	91.9908163265306	1.01	74	403	6	1	6	17	0	1	17	0	0	11.646042300269992	
i 1	91.99448979591837	1.5150000000000001	75	87	7	2	2	8	0	-2	8	0	0	3.0000000000000013	
i 1	91.99857142857142	1.5150000000000001	72	901	2	3	12	1	0	0	1	0	0	3.0000000000000013	
i 1	91.99938775510203	0.2525	77	901	4	5	6	16	0	1	16	0	0	4.935618547531839	
i 1	92.2534693877551	0.2525	71	87	7	5	12	2	0	-2	2	0	0	4.935618547531839	
i 1	92.50387755102041	0.2525	69	403	5	9	15	1	0	0	1	0	0	2.0000000000000013	
i 1	92.51	0.2525	74	901	4	5	8	16	0	2	16	0	0	4.935618547531839	
i 1	92.74163265306123	1.7675	71	87	6	5	10	2	0	-2	2	0	0	4.935618547531839	
i 1	92.75510204081633	2.02	77	403	6	5	1	17	0	2	17	0	0	4.935618547531839	
i 1	92.75755102040816	0.2525	69	403	4	9	2	0	0	-1	0	0	0	2.0000000000000013	
i 1	92.99938775510203	1.5150000000000001	69	901	2	4	5	0	0	0	0	0	0	3.0000000000000013	
i 1	93.00387755102041	1.5150000000000001	75	901	5	3	12	2	0	-2	2	0	0	3.0000000000000013	
i 1	93.00877551020409	0.2525	75	87	7	1	9	2	0	1	2	0	0	11.646042300269992	
i 1	93.2408163265306	1.2625	72	901	6	1	9	2	0	1	2	0	0	11.646042300269992	
i 1	93.2534693877551	0.2525	71	87	6	5	16	2	0	-2	2	0	0	4.935618547531839	
i 1	93.25551020408163	1.2625	74	901	4	24	10	17	0	1	17	0	0	12.646042300269992	
i 1	93.25632653061224	1.2625	75	901	4	24	13	8	0	1	8	0	0	12.646042300269992	
i 1	93.49163265306123	1.01	75	901	4	4	3	2	0	1	2	0	0	3.0000000000000013	
i 1	93.50551020408163	0.2525	74	901	6	5	9	2	0	-1	2	0	0	4.935618547531839	
i 1	93.7534693877551	0.2525	74	403	6	5	12	17	0	1	17	0	0	4.935618547531839	
i 1	93.99408163265306	0.505	77	901	4	5	10	16	0	1	16	0	0	4.935618547531839	
i 1	94.0091836734694	0.7575000000000001	74	403	6	1	3	16	0	1	16	0	0	11.646042300269992	
i 1	94.0095918367347	1.01	69	403	5	9	11	1	0	0	1	0	0	2.0000000000000013	
i 1	94.24204081632654	0.2525	72	87	6	2	15	2	0	-2	2	0	0	3.0000000000000013	
i 1	94.24734693877551	0.2525	74	901	6	5	11	2	0	-2	2	0	0	4.935618547531839	
i 1	94.49122448979591	0.2525	74	1105	5	5	7	2	0	-1	2	0	0	4.935618547531839	
i 1	94.49163265306123	0.505	74	789	6	5	10	8	0	-1	8	0	0	4.935618547531839	
i 1	94.49489795918367	0.505	72	1105	5	2	16	8	0	1	8	0	0	3.0000000000000013	
i 1	94.50020408163266	1.01	74	403	5	5	14	8	0	-1	8	0	0	4.935618547531839	
i 1	94.50224489795919	1.5150000000000001	72	403	5	3	15	2	0	1	2	0	0	3.0000000000000013	
i 1	94.50265306122449	1.01	75	789	4	24	5	8	0	1	8	0	0	12.646042300269992	
i 1	94.50265306122449	0.7575000000000001	72	403	4	24	8	2	0	1	2	0	0	12.646042300269992	
i 1	94.50795918367346	0.505	72	789	5	3	4	8	0	-2	8	0	0	3.0000000000000013	
i 1	94.51	0.2525	72	789	4	4	5	2	0	1	2	0	0	3.0000000000000013	
i 1	94.7408163265306	1.2625	72	1105	6	1	14	2	0	1	2	0	0	11.646042300269992	
i 1	94.74571428571429	1.5150000000000001	74	403	6	1	4	17	0	1	17	0	0	11.646042300269992	
i 1	94.75755102040816	0.2525	74	403	5	5	10	2	0	-2	2	0	0	4.935618547531839	
i 1	94.99204081632654	0.505	74	789	5	5	4	8	0	-1	8	0	0	4.935618547531839	
i 1	94.99448979591837	1.5150000000000001	74	1105	5	5	6	2	0	-1	2	0	0	4.935618547531839	
i 1	94.99448979591837	1.01	74	403	6	5	10	17	0	1	17	0	0	4.935618547531839	
i 1	94.99734693877551	0.7575000000000001	72	789	5	3	13	8	0	-2	8	0	0	3.0000000000000013	
i 1	95.00755102040816	2.525	69	403	5	9	16	0	0	-1	0	0	0	2.0000000000000013	
i 1	95.25795918367346	2.2725	72	1105	5	2	9	8	0	-2	8	0	0	3.0000000000000013	
i 1	95.49326530612245	1.7675	72	1105	5	1	14	2	0	-2	2	0	0	11.646042300269992	
i 1	95.50510204081633	0.2525	74	789	5	5	7	8	0	-1	8	0	0	4.935618547531839	
i 1	95.75428571428571	1.5150000000000001	74	403	6	1	10	16	0	1	16	0	0	11.646042300269992	
i 1	95.76	0.2525	74	789	5	5	4	8	0	-1	8	0	0	4.935618547531839	
i 1	95.9908163265306	1.7675	74	789	5	5	3	8	0	-1	8	0	0	4.935618547531839	
i 1	95.99857142857142	0.505	74	403	5	5	13	17	0	1	17	0	0	4.935618547531839	
i 1	96.00061224489797	1.01	74	1105	5	5	5	8	0	-1	8	0	0	4.935618547531839	
i 1	96.00142857142858	0.7575000000000001	77	403	6	5	8	17	0	2	17	0	0	4.935618547531839	
i 1	96.00428571428571	0.2525	72	1105	5	1	7	2	0	1	2	0	0	11.646042300269992	
i 1	96.00836734693877	0.2525	72	789	4	4	15	2	0	1	2	0	0	3.0000000000000013	
i 1	96.24448979591837	0.505	72	789	5	3	7	8	0	-2	8	0	0	3.0000000000000013	
i 1	96.25510204081633	0.2525	75	403	6	1	6	2	0	1	2	0	0	11.646042300269992	
i 1	96.25551020408163	1.2625	74	403	5	5	6	2	0	-2	2	0	0	4.935618547531839	
i 1	96.50836734693877	0.2525	75	789	6	1	2	2	0	1	2	0	0	11.646042300269992	
i 1	96.7465306122449	1.2625	72	1105	5	1	3	2	0	1	2	0	0	11.646042300269992	
i 1	96.75020408163266	0.7575000000000001	74	403	6	1	10	17	0	1	17	0	0	11.646042300269992	
i 1	96.7591836734694	0.2525	72	1105	5	2	5	8	0	1	8	0	0	3.0000000000000013	
i 1	96.9908163265306	1.5150000000000001	74	789	5	5	7	8	0	-1	8	0	0	4.935618547531839	
i 1	97.00632653061224	0.505	72	403	5	3	2	2	0	1	2	0	0	3.0000000000000013	
i 1	97.01	1.2625	72	789	5	3	2	8	0	-2	8	0	0	3.0000000000000013	
i 1	97.25102040816327	0.2525	75	403	6	1	9	2	0	1	2	0	0	11.646042300269992	
i 1	97.25102040816327	0.2525	74	403	5	5	9	8	0	-1	8	0	0	4.935618547531839	
i 1	97.49489795918367	0.505	75	171	7	1	4	2	0	-2	2	0	0	11.646042300269992	
i 1	97.49612244897959	1.5150000000000001	74	402	5	5	8	2	0	-1	2	0	0	4.935618547531839	
i 1	97.49775510204081	0.2525	71	402	5	5	4	8	0	-2	8	0	0	4.935618547531839	
i 1	97.50142857142858	0.7575000000000001	75	789	5	1	12	2	0	1	2	0	0	11.646042300269992	
i 1	97.5030612244898	0.7575000000000001	72	402	5	3	9	2	0	-2	2	0	0	3.0000000000000013	
i 1	97.5095918367347	0.7575000000000001	75	402	6	1	3	2	0	-2	2	0	0	11.646042300269992	
i 1	97.51	0.2525	72	1105	5	2	9	8	0	1	8	0	0	3.0000000000000013	
i 1	97.74244897959184	1.2625	72	789	4	4	11	2	0	1	2	0	0	3.0000000000000013	
i 1	97.74857142857142	1.01	75	402	4	24	10	2	0	-2	2	0	0	12.646042300269992	
i 1	97.7530612244898	0.2525	75	789	4	24	7	8	0	1	8	0	0	12.646042300269992	
i 1	97.75510204081633	1.2625	72	402	4	4	6	2	0	1	2	0	0	3.0000000000000013	
i 1	97.75795918367346	1.2625	71	171	5	5	6	2	0	-1	2	0	0	4.935618547531839	
i 1	97.99530612244898	1.2625	75	789	4	24	15	8	0	1	8	0	0	12.646042300269992	
i 1	98.00551020408163	1.01	74	1105	6	5	12	2	0	-1	2	0	0	4.935618547531839	
i 1	98.24734693877551	0.7575000000000001	72	1105	5	1	9	2	0	-2	2	0	0	11.646042300269992	
i 1	98.2530612244898	0.2525	72	1105	5	2	11	8	0	-2	8	0	0	3.0000000000000013	
i 1	98.25551020408163	0.7575000000000001	75	171	7	1	1	8	0	1	8	0	0	11.646042300269992	
i 1	98.49448979591837	0.505	72	171	5	9	2	2	0	-2	2	0	0	2.0000000000000013	
i 1	98.49571428571429	0.505	72	1105	5	2	15	8	0	1	8	0	0	3.0000000000000013	
i 1	98.50673469387755	1.7675	72	789	5	3	10	8	0	-2	8	0	0	3.0000000000000013	
i 1	98.74163265306123	0.2525	75	402	6	1	6	2	0	-2	2	0	0	11.646042300269992	
i 1	98.74367346938776	0.2525	72	1105	5	1	1	2	0	1	2	0	0	11.646042300269992	
i 1	98.75102040816327	1.2625	74	789	5	5	1	8	0	-1	8	0	0	4.935618547531839	
i 1	98.75428571428571	0.2525	74	789	5	5	12	8	0	-1	8	0	0	4.935618547531839	
i 1	98.99122448979591	0.2525	75	87	6	2	14	2	0	-2	2	0	0	3.0000000000000013	
i 1	98.99163265306123	0.2525	72	87	6	1	7	2	0	-2	2	0	0	11.646042300269992	
i 1	98.99530612244898	1.01	74	789	6	5	10	8	0	-1	8	0	0	4.935618547531839	
i 1	98.99734693877551	0.505	75	87	5	9	3	8	0	1	8	0	0	2.0000000000000013	
i 1	98.99857142857142	1.01	75	473	4	4	1	2	0	1	2	0	0	3.0000000000000013	
i 1	99.0030612244898	1.01	74	473	4	5	2	2	0	-1	2	0	0	4.935618547531839	
i 1	99.00469387755102	2.02	75	87	6	1	2	2	0	-2	2	0	0	11.646042300269992	
i 1	99.00714285714285	0.2525	74	87	5	5	2	8	0	-2	8	0	0	4.935618547531839	
i 1	99.00755102040816	0.2525	75	87	5	1	3	2	0	1	2	0	0	11.646042300269992	
i 1	99.00755102040816	1.5150000000000001	75	473	6	1	1	2	0	1	2	0	0	11.646042300269992	
i 1	99.00755102040816	0.2525	74	87	7	5	12	8	0	-1	8	0	0	4.935618547531839	
i 1	99.49367346938776	1.5150000000000001	75	87	6	2	2	2	0	1	2	0	0	3.0000000000000013	
i 1	99.50469387755102	1.5150000000000001	74	87	5	5	10	8	0	-2	8	0	0	4.935618547531839	
i 1	99.50551020408163	2.2725	75	473	4	3	2	2	0	1	2	0	0	3.0000000000000013	
i 1	99.75061224489797	0.2525	72	87	6	1	6	2	0	-2	2	0	0	11.646042300269992	
i 1	99.99857142857142	1.2625	72	87	5	1	5	2	0	1	2	0	0	11.646042300269992	
i 1	99.99938775510203	0.2525	74	87	5	5	9	8	0	-1	8	0	0	4.935618547531839	
i 1	100.00142857142858	1.01	74	789	6	5	5	8	0	-1	8	0	0	4.935618547531839	
i 1	100.00836734693877	1.2625	72	87	5	1	15	2	0	-2	2	0	0	11.646042300269992	
i 1	100.00836734693877	2.02	60	87	6	25	5	5	0	0	5	0	0	3.009869454505819	
i 1	100.24408163265306	0.2525	72	789	4	4	7	2	0	1	2	0	0	3.0000000000000013	
i 1	100.25183673469388	1.01	74	87	7	5	3	8	0	-1	8	0	0	4.935618547531839	
i 1	100.49122448979591	1.2625	74	87	5	5	16	8	0	-1	8	0	0	4.935618547531839	
i 1	100.49530612244898	0.2525	75	87	7	2	14	2	0	-2	2	0	0	3.0000000000000013	
i 1	100.74	1.5150000000000001	71	473	4	5	3	8	0	-1	8	0	0	4.935618547531839	
i 1	100.7404081632653	1.2625	75	789	5	1	11	2	0	1	2	0	0	11.646042300269992	
i 1	100.74163265306123	0.2525	72	789	5	3	10	8	0	-2	8	0	0	3.0000000000000013	
i 1	100.7469387755102	0.2525	75	473	6	1	16	2	0	1	2	0	0	11.646042300269992	
i 1	100.74857142857142	1.5150000000000001	71	87	7	5	16	8	0	-1	8	0	0	4.935618547531839	
i 1	100.9908163265306	0.505	75	473	4	1	15	2	0	1	2	0	0	11.646042300269992	
i 1	100.99204081632654	0.505	75	87	5	1	4	2	0	-2	2	0	0	11.646042300269992	
i 1	100.99489795918367	0.7575000000000001	75	87	7	2	10	2	0	1	2	0	0	3.0000000000000013	
i 1	101.00020408163266	1.01	72	473	4	24	1	2	0	-2	2	0	0	12.646042300269992	
i 1	101.00591836734694	1.01	75	473	4	4	15	2	0	1	2	0	0	3.0000000000000013	
i 1	101.01	2.02	67	87	6	25	8	0	0	1	0	0	0	3.009869454505819	
i 1	101.24122448979591	1.2625	72	789	4	4	3	2	0	1	2	0	0	3.0000000000000013	
i 1	101.24897959183673	0.7575000000000001	72	789	5	3	6	8	0	-2	8	0	0	3.0000000000000013	
i 1	101.49530612244898	2.525	75	87	5	1	6	2	0	1	2	0	0	11.646042300269992	
i 1	101.49938775510203	1.5150000000000001	75	789	4	24	8	8	0	1	8	0	0	12.646042300269992	
i 1	101.49938775510203	1.01	75	87	5	9	1	8	0	1	8	0	0	2.0000000000000013	
i 1	101.74244897959184	1.2625	74	789	6	5	2	8	0	-1	8	0	0	4.935618547531839	
i 1	101.75224489795919	1.2625	74	473	4	5	16	2	0	-1	2	0	0	4.935618547531839	
i 1	101.99489795918367	2.02	67	789	5	25	12	0	0	0	0	0	0	3.009869454505819	
i 1	101.99816326530612	1.7675	75	87	7	2	14	2	0	-2	2	0	0	3.0000000000000013	
i 1	102.00102040816327	1.5150000000000001	72	87	5	1	1	2	0	-2	2	0	0	11.646042300269992	
i 1	102.00714285714285	1.5150000000000001	75	87	5	9	12	2	0	1	2	0	0	2.0000000000000013	
i 1	102.00714285714285	2.2725	60	87	6	25	10	5	0	0	5	0	0	3.009869454505819	
i 1	102.24	0.7575000000000001	72	87	5	1	12	2	0	1	2	0	0	11.646042300269992	
i 1	102.25551020408163	1.5150000000000001	74	789	6	5	6	8	0	-1	8	0	0	4.935618547531839	
i 1	102.49326530612245	0.505	74	87	7	5	14	8	0	-1	8	0	0	4.935618547531839	
i 1	102.5030612244898	1.5150000000000001	74	87	7	5	9	8	0	-2	8	0	0	4.935618547531839	
i 1	102.50551020408163	0.2525	72	789	5	3	12	8	0	-2	8	0	0	3.0000000000000013	
i 1	102.76	1.5150000000000001	75	473	4	4	14	2	0	1	2	0	0	3.0000000000000013	
i 1	102.9908163265306	1.2625	67	87	6	25	10	0	0	1	0	0	0	3.009869454505819	
i 1	102.9908163265306	1.2625	74	87	5	5	8	8	0	-1	8	0	0	4.935618547531839	
i 1	102.99489795918367	1.2625	72	789	5	3	3	8	0	-2	8	0	0	3.0000000000000013	
i 1	103.0030612244898	1.01	75	789	4	24	1	8	0	1	8	0	0	12.646042300269992	
i 1	103.00632653061224	1.2625	67	789	5	25	6	5	0	1	5	0	0	3.009869454505819	
i 1	103.25795918367346	1.2625	74	87	7	5	12	8	0	-1	8	0	0	4.935618547531839	
i 1	103.50265306122449	0.7575000000000001	75	87	5	1	3	2	0	-2	2	0	0	11.646042300269992	
i 1	103.50755102040816	0.7575000000000001	75	473	4	1	10	2	0	1	2	0	0	11.646042300269992	
i 1	103.75183673469388	0.505	75	87	7	2	11	2	0	1	2	0	0	3.0000000000000013	
i 1	104.00061224489797	0.2525	67	789	5	25	3	0	0	0	0	0	0	3.009869454505819	
i 1	104.00510204081633	0.2525	72	87	5	1	7	2	0	-2	2	0	0	11.646042300269992	
i 1	104.00836734693877	1.01	75	87	5	9	16	2	0	1	2	0	0	2.0000000000000013	
i 1	104.00836734693877	0.2525	71	473	6	5	10	8	0	-1	8	0	0	4.935618547531839	
i 1	104.00877551020409	1.01	67	87	5	26	1	5	0	0	5	0	0	3.009869454505819	
i 1	104.00877551020409	0.2525	74	789	6	5	1	8	0	-1	8	0	0	4.935618547531839	
i 1	104.0095918367347	1.01	75	87	4	1	6	2	0	1	2	0	0	11.646042300269992	
i 1	104.2404081632653	0.2525	72	585	4	1	9	2	0	-2	2	0	0	11.646042300269992	
i 1	104.24326530612245	0.7575000000000001	71	585	6	5	14	2	0	-2	2	0	0	4.935618547531839	
i 1	104.24408163265306	0.505	72	585	5	3	10	2	0	1	2	0	0	3.0000000000000013	
i 1	104.24408163265306	0.7575000000000001	60	585	5	25	5	0	0	1	0	0	0	3.009869454505819	
i 1	104.24530612244898	0.7575000000000001	60	901	5	25	8	5	0	0	5	0	0	3.009869454505819	
i 1	104.24571428571429	0.7575000000000001	71	585	6	5	16	8	0	-1	8	0	0	4.935618547531839	
i 1	104.24897959183673	0.2525	74	901	4	5	13	2	0	-2	2	0	0	4.935618547531839	
i 1	104.24938775510203	0.7575000000000001	72	901	4	1	1	2	0	1	2	0	0	11.646042300269992	
i 1	104.25428571428571	0.7575000000000001	75	901	4	1	3	8	0	1	8	0	0	11.646042300269992	
i 1	104.25428571428571	0.7575000000000001	60	585	5	25	13	0	0	0	0	0	0	3.009869454505819	
i 1	104.25836734693877	0.7575000000000001	60	901	5	25	3	0	0	1	0	0	0	3.009869454505819	
i 1	104.2591836734694	0.2525	72	585	4	4	15	2	0	-2	2	0	0	3.0000000000000013	
i 1	104.26	0.7575000000000001	75	901	6	2	6	2	0	1	2	0	0	3.0000000000000013	
i 1	104.49367346938776	0.505	72	87	5	1	6	2	0	1	2	0	0	11.646042300269992	
i 1	104.74857142857142	0.2525	74	87	7	5	14	8	0	-1	8	0	0	4.935618547531839	
i 1	104.75142857142858	0.2525	75	901	5	2	14	8	0	1	8	0	0	3.0000000000000013	
i 1	104.99163265306123	0.7575000000000001	60	585	5	25	6	0	0	0	0	0	0	1.8797473294634677	
i 1	104.99163265306123	0.505	71	585	4	5	9	2	0	-2	2	0	0	5.060433927200711	
i 1	104.99163265306123	3.0300000000000002	67	901	5	14	16	5	0	0	5	0	0	11.564014635728329	
i 1	104.99285714285715	0.505	72	901	4	1	4	2	0	1	2	0	0	12.0	
i 1	104.99367346938776	0.7575000000000001	72	585	5	3	6	2	0	1	2	0	0	11.0	
i 1	104.99408163265306	0.7575000000000001	74	585	6	5	14	8	0	-1	8	0	0	5.060433927200711	
i 1	104.99489795918367	1.2625	72	87	4	1	1	2	0	1	2	0	0	12.0	
i 1	104.99489795918367	1.01	75	87	6	9	4	2	0	1	2	0	0	10.0	
i 1	104.99489795918367	3.0300000000000002	60	901	5	25	16	0	0	1	0	0	0	1.8797473294634677	
i 1	104.99734693877551	1.01	75	585	4	3	1	2	0	1	2	0	0	11.0	
i 1	104.99734693877551	3.0300000000000002	60	901	5	14	13	5	0	1	5	0	0	11.564014635728329	
i 1	104.99775510204081	1.01	67	87	5	26	15	5	0	0	5	0	0	1.8797473294634677	
i 1	104.99816326530612	0.505	75	901	5	2	5	2	0	1	2	0	0	11.0	
i 1	105.00224489795919	0.7575000000000001	60	585	6	7	7	5	0	0	5	0	0	5.963056142188976	
i 1	105.0034693877551	3.0300000000000002	60	901	5	25	16	5	0	0	5	0	0	1.8797473294634677	
i 1	105.0034693877551	0.7575000000000001	60	585	5	25	15	0	0	1	0	0	0	1.8797473294634677	
i 1	105.00387755102041	0.7575000000000001	72	585	4	1	2	2	0	1	2	0	0	12.0	
i 1	105.00428571428571	0.505	71	585	6	5	16	8	0	-1	8	0	0	5.060433927200711	
i 1	105.00714285714285	1.01	72	585	4	1	15	2	0	-2	2	0	0	12.0	
i 1	105.00755102040816	2.02	67	87	5	18	14	0	0	1	0	0	0	0.0026187251042760974	
i 1	105.00877551020409	0.7575000000000001	74	585	6	5	13	2	0	-1	2	0	0	5.060433927200711	
i 1	105.01	2.02	60	87	5	26	13	5	0	0	5	0	0	1.8797473294634677	
i 1	105.2408163265306	0.7575000000000001	74	901	4	5	11	2	0	-2	2	0	0	5.060433927200711	
i 1	105.24857142857142	1.7675	74	87	7	5	10	8	0	-2	8	0	0	5.060433927200711	
i 1	105.25632653061224	0.7575000000000001	74	901	4	5	15	2	0	-2	2	0	0	5.060433927200711	
i 1	105.49204081632654	0.7575000000000001	75	901	5	1	15	8	0	1	8	0	0	12.0	
i 1	105.49734693877551	1.5150000000000001	75	901	5	2	5	8	0	1	8	0	0	11.0	
i 1	105.74163265306123	0.2525	72	403	4	1	15	2	0	-2	2	0	0	12.0	
i 1	105.74204081632654	2.2725	67	403	5	25	1	0	0	0	0	0	0	1.8797473294634677	
i 1	105.74489795918367	1.5150000000000001	75	87	4	1	11	2	0	1	2	0	0	12.0	
i 1	105.74734693877551	0.2525	72	403	5	3	9	2	0	-2	2	0	0	11.0	
i 1	105.74816326530612	1.5150000000000001	72	403	4	24	5	2	0	1	2	0	0	13.0	
i 1	105.74897959183673	2.2725	67	403	5	25	1	5	0	1	5	0	0	1.8797473294634677	
i 1	105.75183673469388	2.2725	67	403	6	7	13	0	0	1	0	0	0	5.963056142188976	
i 1	105.7591836734694	0.2525	71	403	6	5	16	8	0	-1	8	0	0	5.060433927200711	
i 1	105.99163265306123	0.505	75	901	5	2	1	2	0	1	2	0	0	11.0	
i 1	105.99204081632654	2.02	67	87	5	26	11	5	0	0	5	0	0	1.8797473294634677	
i 1	105.99326530612245	1.01	75	87	6	9	2	2	0	1	2	0	0	10.0	
i 1	105.99367346938776	1.5150000000000001	71	403	4	5	11	8	0	-1	8	0	0	5.060433927200711	
i 1	106.00102040816327	2.02	67	585	3	27	1	0	0	0	0	0	0	2.2196681153911935	
i 1	106.00795918367346	0.7575000000000001	74	585	6	5	16	2	0	-1	2	0	0	5.060433927200711	
i 1	106.25673469387755	0.2525	72	403	4	1	12	2	0	-2	2	0	0	12.0	
i 1	106.4908163265306	0.505	72	585	4	4	10	2	0	-2	2	0	0	11.0	
i 1	106.49285714285715	1.5150000000000001	72	403	5	3	5	2	0	-2	2	0	0	11.0	
i 1	106.50183673469388	1.5150000000000001	72	585	3	1	15	2	0	-2	2	0	0	12.0	
i 1	106.74285714285715	0.2525	71	585	6	5	11	8	0	-1	8	0	0	5.060433927200711	
i 1	106.75755102040816	1.2625	72	901	5	1	3	2	0	1	2	0	0	12.0	
i 1	106.99489795918367	0.2525	75	901	5	2	7	2	0	1	2	0	0	11.0	
i 1	106.9969387755102	1.01	60	87	5	26	2	5	0	0	5	0	0	1.8797473294634677	
i 1	107.0034693877551	1.01	60	585	3	27	16	5	0	1	5	0	0	2.2196681153911935	
i 1	107.00551020408163	1.01	72	585	4	4	7	2	0	-2	2	0	0	11.0	
i 1	107.00877551020409	1.01	74	87	7	5	3	8	0	-1	8	0	0	5.060433927200711	
i 1	107.0095918367347	1.01	74	901	4	5	16	2	0	-2	2	0	0	5.060433927200711	
i 1	107.01	0.505	74	87	4	5	4	8	0	-2	8	0	0	5.060433927200711	
i 1	107.24734693877551	0.2525	72	403	5	1	6	2	0	-2	2	0	0	12.0	
i 1	107.25061224489797	0.2525	75	87	6	9	2	2	0	1	2	0	0	10.0	
i 1	107.50142857142858	0.2525	72	403	4	24	14	2	0	1	2	0	0	13.0	
i 1	107.50387755102041	0.505	71	585	6	5	15	8	0	-1	8	0	0	5.060433927200711	
i 1	107.74775510204081	0.2525	72	87	4	1	1	2	0	1	2	0	0	12.0	
i 1	107.74816326530612	0.2525	75	87	6	9	7	2	0	1	2	0	0	10.0	
i 1	107.75877551020409	0.2525	74	403	4	5	13	2	0	-2	2	0	0	5.060433927200711	
i 1	107.99122448979591	1.2625	74	282	4	5	9	2	0	-2	2	0	0	5.060433927200711	
i 1	107.99244897959184	0.7575000000000001	75	1096	3	1	7	2	0	1	2	0	0	12.0	
i 1	107.99244897959184	7.07	60	1096	4	26	11	0	0	1	0	0	0	1.8797473294634677	
i 1	107.99285714285715	0.505	72	1096	5	9	14	8	0	1	8	0	0	10.0	
i 1	107.99326530612245	0.505	75	598	5	2	5	8	0	-2	8	0	0	11.0	
i 1	107.99326530612245	1.01	60	598	5	14	15	0	0	1	0	0	0	11.564014635728329	
i 1	107.99367346938776	1.01	67	1096	4	19	2	0	0	1	0	0	0	0.0026187251042760974	
i 1	107.99448979591837	3.0300000000000002	67	598	5	25	4	0	0	1	0	0	0	1.8797473294634677	
i 1	107.99571428571429	3.0300000000000002	67	282	7	7	1	0	0	0	0	0	0	5.963056142188976	
i 1	107.99816326530612	1.01	75	282	5	3	1	2	0	1	2	0	0	11.0	
i 1	107.99897959183673	0.2525	74	598	6	5	8	2	0	-2	2	0	0	5.060433927200711	
i 1	107.99897959183673	3.0300000000000002	67	598	4	14	14	5	0	0	5	0	0	11.564014635728329	
i 1	107.99979591836734	1.5150000000000001	75	1096	3	1	6	2	0	-2	2	0	0	12.0	
i 1	108.00102040816327	0.2525	75	1096	4	4	15	2	0	-2	2	0	0	11.0	
i 1	108.00142857142858	3.0300000000000002	67	1096	3	27	16	5	0	0	5	0	0	2.2196681153911935	
i 1	108.00224489795919	4.545	67	282	5	25	15	5	0	0	5	0	0	1.8797473294634677	
i 1	108.00551020408163	4.04	67	598	5	25	15	5	0	0	5	0	0	1.8797473294634677	
i 1	108.00673469387755	4.545	67	282	5	25	15	5	0	0	5	0	0	1.8797473294634677	
i 1	108.00755102040816	0.2525	71	1096	3	5	4	2	0	-2	2	0	0	5.060433927200711	
i 1	108.00836734693877	1.01	75	1096	5	3	4	8	0	1	8	0	0	11.0	
i 1	108.00877551020409	1.01	60	1096	3	27	13	0	0	1	0	0	0	2.2196681153911935	
i 1	108.00877551020409	1.01	71	1096	6	5	9	8	0	-2	8	0	0	5.060433927200711	
i 1	108.0091836734694	0.7575000000000001	75	598	4	1	13	2	0	1	2	0	0	12.0	
i 1	108.0095918367347	8.08	67	1096	4	26	13	0	0	1	0	0	0	1.8797473294634677	
i 1	108.24326530612245	0.2525	71	1096	3	5	16	2	0	-1	2	0	0	5.060433927200711	
i 1	108.2534693877551	0.7575000000000001	72	282	5	1	5	2	0	-2	2	0	0	12.0	
i 1	108.4965306122449	0.7575000000000001	75	1096	4	4	14	2	0	-2	2	0	0	11.0	
i 1	108.50183673469388	1.01	74	282	4	5	4	2	0	-2	2	0	0	5.060433927200711	
i 1	108.50673469387755	1.01	72	282	5	4	4	2	0	-2	2	0	0	11.0	
i 1	108.75102040816327	2.2725	75	1096	4	9	2	8	0	-2	8	0	0	10.0	
i 1	108.75265306122449	0.2525	75	1096	3	1	16	8	0	1	8	0	0	12.0	
i 1	108.75387755102041	1.2625	75	598	4	2	13	8	0	1	8	0	0	11.0	
i 1	108.75795918367346	0.7575000000000001	71	1096	6	5	11	2	0	-2	2	0	0	5.060433927200711	
i 1	108.99122448979591	0.505	72	282	4	1	1	2	0	-2	2	0	0	12.0	
i 1	108.99367346938776	1.7675	72	598	4	1	4	2	0	1	2	0	0	12.0	
i 1	108.99489795918367	3.0300000000000002	60	598	4	14	15	0	0	1	0	0	0	11.564014635728329	
i 1	108.99734693877551	1.7675	75	1096	4	1	15	8	0	1	8	0	0	12.0	
i 1	108.99979591836734	0.2525	71	1096	3	5	15	8	0	-2	8	0	0	5.060433927200711	
i 1	109.00020408163266	1.5150000000000001	74	598	6	5	12	2	0	-2	2	0	0	5.060433927200711	
i 1	109.0034693877551	1.5150000000000001	71	1096	3	5	5	2	0	-1	2	0	0	5.060433927200711	
i 1	109.00591836734694	2.02	60	1096	3	27	13	0	0	1	0	0	0	2.2196681153911935	
i 1	109.49612244897959	0.2525	72	1096	4	9	15	8	0	1	8	0	0	10.0	
i 1	109.50183673469388	2.02	71	1096	3	5	5	2	0	-2	2	0	0	5.060433927200711	
i 1	109.50469387755102	0.2525	75	1096	3	1	4	2	0	1	2	0	0	12.0	
i 1	109.74857142857142	0.2525	75	1096	5	3	13	8	0	1	8	0	0	11.0	
i 1	109.74938775510203	0.2525	72	282	5	24	3	8	0	1	8	0	0	13.0	
i 1	109.9908163265306	2.525	75	598	4	1	13	2	0	1	2	0	0	12.0	
i 1	109.99857142857142	1.2625	71	598	6	5	5	2	0	-1	2	0	0	5.060433927200711	
i 1	109.99979591836734	2.02	75	282	4	3	14	2	0	1	2	0	0	11.0	
i 1	110.00142857142858	1.01	75	598	6	2	13	8	0	1	8	0	0	11.0	
i 1	110.24285714285715	0.7575000000000001	72	1096	3	24	2	8	0	-2	8	0	0	13.0	
i 1	110.25428571428571	1.2625	72	282	4	24	2	8	0	1	8	0	0	13.0	
i 1	110.49326530612245	0.2525	71	1096	3	5	10	8	0	-2	8	0	0	5.060433927200711	
i 1	110.49938775510203	0.505	75	1096	4	3	3	8	0	1	8	0	0	11.0	
i 1	110.74	0.2525	71	1096	3	5	4	2	0	-2	2	0	0	5.060433927200711	
i 1	110.74489795918367	0.2525	74	282	4	5	12	2	0	-2	2	0	0	5.060433927200711	
i 1	110.99204081632654	1.7675	72	1096	4	9	4	8	0	1	8	0	0	10.0	
i 1	110.99326530612245	0.505	75	865	3	24	12	2	0	-2	2	0	0	13.0	
i 1	110.99326530612245	1.5150000000000001	74	282	6	5	2	2	0	-2	2	0	0	5.060433927200711	
i 1	110.99408163265306	1.5150000000000001	60	865	3	27	5	5	0	0	5	0	0	2.2196681153911935	
i 1	110.99571428571429	1.5150000000000001	67	865	3	27	12	5	0	0	5	0	0	2.2196681153911935	
i 1	110.99816326530612	1.5150000000000001	67	598	5	14	5	5	0	0	5	0	0	11.564014635728329	
i 1	111.00224489795919	1.5150000000000001	67	282	4	7	8	0	0	0	0	0	0	5.963056142188976	
i 1	111.00387755102041	1.5150000000000001	74	865	3	5	13	8	0	-2	8	0	0	5.060433927200711	
i 1	111.00551020408163	1.01	75	1096	4	1	13	2	0	1	2	0	0	12.0	
i 1	111.0095918367347	1.01	75	865	4	3	13	8	0	-2	8	0	0	11.0	
i 1	111.49775510204081	1.01	75	598	6	2	15	8	0	-2	8	0	0	11.0	
i 1	111.49938775510203	0.2525	72	598	4	1	5	2	0	1	2	0	0	12.0	
i 1	111.50877551020409	0.2525	74	282	6	5	7	2	0	-2	2	0	0	5.060433927200711	
i 1	111.75632653061224	0.2525	72	282	4	24	13	8	0	1	8	0	0	13.0	
i 1	111.75836734693877	0.2525	71	1096	3	5	1	2	0	-1	2	0	0	5.060433927200711	
i 1	111.9908163265306	0.505	72	598	6	1	11	2	0	1	2	0	0	12.0	
i 1	111.99448979591837	0.505	60	598	5	14	15	0	0	1	0	0	0	11.564014635728329	
i 1	111.99816326530612	1.5150000000000001	75	1096	3	9	10	8	0	-2	8	0	0	10.0	
i 1	112.00510204081633	2.7775	75	1096	3	1	16	2	0	1	2	0	0	12.0	
i 1	112.00591836734694	0.7575000000000001	75	1096	3	1	7	8	0	1	8	0	0	12.0	
i 1	112.2404081632653	0.2525	72	282	4	1	2	2	0	-2	2	0	0	12.0	
i 1	112.2404081632653	0.2525	75	598	6	2	6	8	0	1	8	0	0	11.0	
i 1	112.2404081632653	0.2525	74	598	6	5	16	2	0	-2	2	0	0	5.060433927200711	
i 1	112.24244897959184	0.2525	75	865	4	24	9	2	0	-2	2	0	0	13.0	
i 1	112.24244897959184	0.7575000000000001	71	1096	3	5	10	2	0	-2	2	0	0	5.060433927200711	
i 1	112.25836734693877	0.2525	72	282	4	4	2	2	0	-2	2	0	0	11.0	
i 1	112.49244897959184	0.505	72	394	4	1	10	2	0	1	2	0	0	12.0	
i 1	112.49244897959184	5.3025	67	1096	5	14	14	5	0	0	5	0	0	11.564014635728329	
i 1	112.49285714285715	4.545	67	780	3	27	4	0	0	0	0	0	0	2.2196681153911935	
i 1	112.49489795918367	0.505	60	394	5	25	11	0	0	0	0	0	0	1.8797473294634677	
i 1	112.49571428571429	5.3025	67	780	3	27	8	5	0	1	5	0	0	2.2196681153911935	
i 1	112.49734693877551	1.5150000000000001	74	1096	6	5	11	8	0	-1	8	0	0	5.060433927200711	
i 1	112.49734693877551	0.2525	71	780	3	5	11	8	0	-2	8	0	0	5.060433927200711	
i 1	112.49979591836734	0.505	75	780	4	24	16	2	0	-2	2	0	0	13.0	
i 1	112.49979591836734	0.2525	75	1096	6	2	9	2	0	-2	2	0	0	11.0	
i 1	112.50020408163266	2.2725	75	1096	6	1	6	8	0	1	8	0	0	12.0	
i 1	112.50142857142858	2.7775	75	1096	6	2	4	8	0	-2	8	0	0	11.0	
i 1	112.5034693877551	1.5150000000000001	67	394	4	7	13	0	0	1	0	0	0	5.963056142188976	
i 1	112.50469387755102	5.3025	67	1096	5	14	14	5	0	0	5	0	0	11.564014635728329	
i 1	112.50551020408163	0.505	72	394	4	4	8	2	0	-2	2	0	0	11.0	
i 1	112.50632653061224	1.5150000000000001	67	394	5	25	16	0	0	1	0	0	0	1.8797473294634677	
i 1	112.51	0.2525	74	394	6	5	16	8	0	-2	8	0	0	5.060433927200711	
i 1	112.74897959183673	0.2525	71	780	3	5	14	2	0	-1	2	0	0	5.060433927200711	
i 1	112.99326530612245	0.7575000000000001	72	394	4	4	10	2	0	-2	2	0	0	11.0	
i 1	112.9969387755102	2.02	72	1096	3	9	14	8	0	1	8	0	0	10.0	
i 1	112.99857142857142	0.7575000000000001	71	1096	5	5	15	2	0	-2	2	0	0	5.060433927200711	
i 1	113.0030612244898	0.2525	72	394	4	24	4	2	0	1	2	0	0	13.0	
i 1	113.00387755102041	1.01	71	394	6	5	1	2	0	-1	2	0	0	5.060433927200711	
i 1	113.24775510204081	0.2525	72	394	4	1	11	2	0	1	2	0	0	12.0	
i 1	113.24979591836734	0.7575000000000001	71	780	3	5	16	8	0	-2	8	0	0	5.060433927200711	
i 1	113.49612244897959	1.5150000000000001	74	394	6	5	6	8	0	-2	8	0	0	5.060433927200711	
i 1	113.49775510204081	1.5150000000000001	71	1096	5	5	5	2	0	-1	2	0	0	5.060433927200711	
i 1	113.75877551020409	0.2525	75	780	4	3	15	2	0	1	2	0	0	11.0	
i 1	113.99612244897959	0.2525	72	394	4	4	4	2	0	-2	2	0	0	11.0	
i 1	113.9969387755102	5.3025	67	394	5	7	4	0	0	1	0	0	0	5.963056142188976	
i 1	114.0034693877551	1.7675	74	1096	6	5	5	8	0	-1	8	0	0	5.060433927200711	
i 1	114.00591836734694	0.2525	75	780	3	24	3	2	0	-2	2	0	0	13.0	
i 1	114.2465306122449	0.7575000000000001	72	394	4	24	10	2	0	1	2	0	0	13.0	
i 1	114.25836734693877	1.01	75	1096	3	1	9	8	0	1	8	0	0	12.0	
i 1	114.49489795918367	1.2625	71	1096	5	5	10	2	0	-2	2	0	0	5.060433927200711	
i 1	114.74408163265306	3.0300000000000002	72	780	3	1	14	2	0	-2	2	0	0	12.0	
i 1	114.74816326530612	3.0300000000000002	75	1096	6	1	1	2	0	1	2	0	0	12.0	
i 1	114.75183673469388	1.2625	72	394	5	3	16	2	0	-2	2	0	0	11.0	
i 1	114.9904081632653	0.2525	71	780	5	5	11	8	0	-2	8	0	0	5.060433927200711	
i 1	114.99204081632654	1.01	75	780	3	4	10	2	0	-2	2	0	0	11.0	
i 1	115.00142857142858	0.2525	72	394	4	24	2	2	0	1	2	0	0	13.0	
i 1	115.2408163265306	1.2625	71	780	5	5	1	2	0	-1	2	0	0	5.060433927200711	
i 1	115.24244897959184	1.5150000000000001	75	1096	6	1	11	8	0	1	8	0	0	12.0	
i 1	115.24408163265306	0.2525	75	1096	5	9	15	8	0	-2	8	0	0	10.0	
i 1	115.24897959183673	1.2625	71	1096	6	5	16	8	0	-2	8	0	0	5.060433927200711	
i 1	115.49734693877551	1.01	75	1096	6	2	10	2	0	-2	2	0	0	11.0	
i 1	115.50265306122449	0.505	75	780	3	3	13	2	0	1	2	0	0	11.0	
i 1	115.50469387755102	0.505	75	1096	6	2	16	8	0	-2	8	0	0	11.0	
i 1	115.74612244897959	0.2525	71	394	6	5	12	2	0	-1	2	0	0	5.060433927200711	
i 1	115.7595918367347	1.2625	72	1096	5	9	16	8	0	1	8	0	0	10.0	
i 1	115.9908163265306	0.7575000000000001	75	1096	3	1	11	2	0	1	2	0	0	12.0	
i 1	115.9908163265306	1.7675	71	1096	6	5	4	2	0	-1	2	0	0	5.060433927200711	
i 1	115.99489795918367	0.2525	75	780	5	3	15	2	0	1	2	0	0	11.0	
i 1	115.99571428571429	1.01	75	1096	5	2	7	8	0	-2	8	0	0	11.0	
i 1	115.99857142857142	1.01	74	394	6	5	8	8	0	-2	8	0	0	5.060433927200711	
i 1	116.49204081632654	1.5150000000000001	72	394	5	3	2	2	0	-2	2	0	0	11.0	
i 1	116.49244897959184	0.2525	71	1096	5	5	1	2	0	-2	2	0	0	5.060433927200711	
i 1	116.5091836734694	0.505	75	780	3	4	13	2	0	-2	2	0	0	11.0	
i 1	116.74204081632654	0.2525	75	1096	6	1	4	8	0	1	8	0	0	12.0	
i 1	116.7465306122449	0.2525	71	394	6	5	1	2	0	-1	2	0	0	5.060433927200711	
i 1	116.99489795918367	0.7575000000000001	75	780	4	4	2	2	0	-2	2	0	0	11.0	
i 1	116.99571428571429	1.01	74	394	6	5	9	8	0	-2	8	0	0	5.060433927200711	
i 1	117.00387755102041	0.2525	75	1096	6	1	7	2	0	1	2	0	0	12.0	
i 1	117.00673469387755	0.2525	75	780	5	3	6	2	0	1	2	0	0	11.0	
i 1	117.24489795918367	0.2525	72	394	4	4	1	2	0	-2	2	0	0	11.0	
i 1	117.2469387755102	0.7575000000000001	72	394	6	1	8	2	0	1	2	0	0	12.0	
i 1	117.24816326530612	0.505	75	780	3	24	9	2	0	-2	2	0	0	13.0	
i 1	117.49857142857142	0.2525	75	1096	5	9	11	8	0	-2	8	0	0	10.0	
i 1	117.49979591836734	0.2525	75	1096	5	2	3	8	0	-2	8	0	0	11.0	
i 1	117.50795918367346	0.2525	75	1096	4	1	10	8	0	1	8	0	0	12.0	
i 1	117.5091836734694	0.2525	75	1096	6	1	9	8	0	1	8	0	0	12.0	
i 1	117.5095918367347	1.5150000000000001	72	394	4	24	2	2	0	1	2	0	0	13.0	
i 1	117.74163265306123	1.2625	75	576	3	24	16	8	0	1	8	0	0	13.0	
i 1	117.74734693877551	0.505	71	892	6	5	13	2	0	-2	2	0	0	5.060433927200711	
i 1	117.74857142857142	0.7575000000000001	72	892	6	1	14	2	0	1	2	0	0	12.0	
i 1	117.74857142857142	0.505	72	576	4	4	9	2	0	-2	2	0	0	11.0	
i 1	117.75020408163266	1.2625	72	892	5	9	14	2	0	-2	2	0	0	10.0	
i 1	117.75020408163266	0.2525	74	576	5	5	12	2	0	-2	2	0	0	5.060433927200711	
i 1	117.75102040816327	0.7575000000000001	75	892	4	1	9	2	0	-2	2	0	0	12.0	
i 1	117.7534693877551	1.2625	75	892	5	2	16	8	0	1	8	0	0	11.0	
i 1	117.7534693877551	0.2525	71	892	6	5	5	8	0	-1	8	0	0	5.060433927200711	
i 1	117.75510204081633	2.2725	67	892	5	14	10	0	0	0	0	0	0	11.564014635728329	
i 1	117.75632653061224	0.2525	67	576	3	27	1	0	0	1	0	0	0	2.2196681153911935	
i 1	117.75795918367346	1.5150000000000001	71	394	6	5	7	2	0	-1	2	0	0	5.060433927200711	
i 1	117.75877551020409	2.2725	67	892	5	14	14	0	0	1	0	0	0	11.564014635728329	
i 1	117.99979591836734	2.02	74	576	6	5	5	2	0	-2	2	0	0	5.060433927200711	
i 1	118.00020408163266	0.505	71	892	5	5	9	8	0	-1	8	0	0	5.060433927200711	
i 1	118.24448979591837	1.01	72	394	5	3	5	2	0	-2	2	0	0	11.0	
i 1	118.49530612244898	0.505	74	576	5	5	5	8	0	-2	8	0	0	5.060433927200711	
i 1	118.49571428571429	2.525	72	892	4	1	13	2	0	-2	2	0	0	12.0	
i 1	118.50428571428571	1.01	72	892	6	1	4	2	0	-2	2	0	0	12.0	
i 1	118.51	1.2625	75	576	5	3	7	2	0	-2	2	0	0	11.0	
i 1	118.74775510204081	0.505	74	394	6	5	14	8	0	-2	8	0	0	5.060433927200711	
i 1	118.9904081632653	1.01	72	892	5	2	8	8	0	-2	8	0	0	11.0	
i 1	119.00142857142858	1.7675	72	576	6	1	7	2	0	-2	2	0	0	12.0	
i 1	119.00673469387755	0.505	74	576	6	5	4	8	0	-2	8	0	0	5.060433927200711	
i 1	119.00836734693877	1.01	74	892	6	5	16	8	0	-1	8	0	0	5.060433927200711	
i 1	119.2408163265306	0.2525	72	310	5	3	11	2	0	1	2	0	0	11.0	
i 1	119.24326530612245	0.7575000000000001	75	892	5	2	7	8	0	1	8	0	0	11.0	
i 1	119.24857142857142	0.7575000000000001	60	310	5	7	9	5	0	1	5	0	0	5.963056142188976	
i 1	119.25020408163266	0.7575000000000001	72	892	5	9	16	2	0	1	2	0	0	10.0	
i 1	119.25224489795919	2.2725	72	310	4	1	15	2	0	1	2	0	0	12.0	
i 1	119.25224489795919	0.7575000000000001	74	310	6	5	14	8	0	-1	8	0	0	5.060433927200711	
i 1	119.74775510204081	0.2525	71	892	5	5	11	8	0	-1	8	0	0	5.060433927200711	
i 1	119.99122448979591	1.5150000000000001	67	892	5	14	1	0	0	1	0	0	0	11.673286707214311	
i 1	119.99244897959184	1.5150000000000001	72	310	5	3	3	2	0	1	2	0	0	11.000000000000002	
i 1	119.99326530612245	1.5150000000000001	72	576	4	4	2	2	0	-2	2	0	0	11.000000000000002	
i 1	119.99408163265306	1.5150000000000001	60	310	5	7	8	5	0	1	5	0	0	6.072328213674957	
i 1	119.99448979591837	1.2625	74	310	6	5	6	8	0	-1	8	0	0	5.292763705596874	
i 1	119.99489795918367	0.505	75	892	5	2	10	8	0	1	8	0	0	11.000000000000002	
i 1	119.99775510204081	1.5150000000000001	72	310	5	4	4	8	0	-2	8	0	0	11.000000000000002	
i 1	119.99775510204081	0.2525	74	576	5	5	12	2	0	-2	2	0	0	5.292763705596874	
i 1	119.99816326530612	1.01	71	892	5	5	15	8	0	-1	8	0	0	5.292763705596874	
i 1	120.00183673469388	0.505	72	892	5	9	16	2	0	1	2	0	0	10.000000000000002	
i 1	120.00224489795919	1.5150000000000001	67	892	5	14	15	0	0	0	0	0	0	11.673286707214311	
i 1	120.00265306122449	0.2525	74	892	6	5	12	8	0	-1	8	0	0	5.292763705596874	
i 1	120.24530612244898	0.2525	71	310	6	5	11	2	0	-2	2	0	0	5.292763705596874	
i 1	120.24571428571429	1.2625	75	576	4	24	15	8	0	1	8	0	0	13.0	
i 1	120.50020408163266	1.01	71	892	6	5	16	2	0	-2	2	0	0	5.292763705596874	
i 1	120.50877551020409	1.01	74	892	5	5	15	2	0	-2	2	0	0	5.292763705596874	
i 1	120.99	0.505	72	892	4	9	13	2	0	-2	2	0	0	10.000000000000002	
i 1	120.99897959183673	0.505	60	892	6	17	11	0	0	1	0	0	0	0.007067402691058374	
i 1	121.00183673469388	0.505	72	892	6	1	15	2	0	-2	2	0	0	12.0	
i 1	121.00836734693877	0.505	75	892	4	1	1	2	0	-2	2	0	0	12.0	
i 1	121.24163265306123	0.2525	75	892	5	2	5	8	0	1	8	0	0	11.000000000000002	
i 1	121.2530612244898	0.2525	75	310	4	24	9	2	0	1	2	0	0	13.0	
i 1	121.2591836734694	0.2525	71	892	5	5	2	8	0	-1	8	0	0	5.292763705596874	
i 1	121.49	1.2625	75	395	5	3	14	2	0	-2	2	0	0	11.000000000000002	
i 1	121.49	2.525	60	1097	5	14	12	0	0	1	0	0	0	11.673286707214311	
i 1	121.4908163265306	1.5150000000000001	74	395	5	5	1	8	0	-1	8	0	0	5.292763705596874	
i 1	121.49244897959184	0.7575000000000001	75	395	4	24	10	2	0	1	2	0	0	13.0	
i 1	121.49367346938776	0.2525	72	395	4	4	15	2	0	1	2	0	0	11.000000000000002	
i 1	121.49408163265306	0.2525	75	1097	4	1	7	2	0	-2	2	0	0	12.0	
i 1	121.49448979591837	0.505	72	781	4	9	1	2	0	1	2	0	0	10.000000000000002	
i 1	121.49612244897959	0.505	71	1097	6	5	7	8	0	-2	8	0	0	5.292763705596874	
i 1	121.4969387755102	1.01	75	395	4	24	3	2	0	-2	2	0	0	13.0	
i 1	121.49734693877551	1.5150000000000001	67	1097	5	14	12	5	0	1	5	0	0	11.673286707214311	
i 1	121.49775510204081	0.505	72	395	5	3	14	2	0	1	2	0	0	11.000000000000002	
i 1	121.49816326530612	1.5150000000000001	74	395	6	5	16	2	0	-1	2	0	0	5.292763705596874	
i 1	121.50102040816327	2.2725	71	395	6	5	4	8	0	-1	8	0	0	5.292763705596874	
i 1	121.50183673469388	2.525	60	1097	6	17	5	5	0	0	5	0	0	0.007067402691058374	
i 1	121.50632653061224	0.505	74	781	5	5	16	2	0	-1	2	0	0	5.292763705596874	
i 1	121.50755102040816	0.2525	74	781	5	5	4	2	0	-2	2	0	0	5.292763705596874	
i 1	121.50877551020409	0.505	75	781	6	1	5	8	0	1	8	0	0	12.0	
i 1	121.50877551020409	0.505	72	1097	5	2	13	2	0	1	2	0	0	11.000000000000002	
i 1	121.5095918367347	4.545	60	395	5	7	7	5	0	0	5	0	0	6.072328213674957	
i 1	121.74408163265306	1.2625	72	1097	4	1	16	2	0	-2	2	0	0	12.0	
i 1	121.99285714285715	1.2625	72	395	4	3	11	2	0	1	2	0	0	11.000000000000002	
i 1	121.99408163265306	3.0300000000000002	75	781	3	1	15	8	0	1	8	0	0	12.0	
i 1	121.99612244897959	3.0300000000000002	60	1097	6	17	16	0	0	1	0	0	0	0.007067402691058374	
i 1	122.00020408163266	1.7675	72	1097	5	2	16	2	0	-2	2	0	0	11.000000000000002	
i 1	122.25551020408163	1.5150000000000001	75	781	4	9	11	2	0	-2	2	0	0	10.000000000000002	
i 1	122.49204081632654	0.505	75	1097	6	1	8	2	0	-2	2	0	0	12.0	
i 1	122.5095918367347	1.2625	71	395	5	5	3	8	0	-1	8	0	0	5.292763705596874	
i 1	122.99122448979591	2.02	72	1097	6	1	15	2	0	-2	2	0	0	12.0	
i 1	122.99204081632654	0.505	75	395	3	1	2	8	0	-2	8	0	0	12.0	
i 1	122.99979591836734	3.0300000000000002	67	395	6	17	11	0	0	0	0	0	0	0.007067402691058374	
i 1	123.00020408163266	3.0300000000000002	67	1097	5	14	4	5	0	1	5	0	0	11.673286707214311	
i 1	123.00714285714285	0.2525	74	1097	6	5	1	8	0	-2	8	0	0	5.292763705596874	
i 1	123.24979591836734	1.5150000000000001	74	781	5	5	7	2	0	-1	2	0	0	5.292763705596874	
i 1	123.25224489795919	1.5150000000000001	72	1097	5	2	4	2	0	1	2	0	0	11.000000000000002	
i 1	123.25836734693877	1.5150000000000001	72	781	4	9	5	2	0	1	2	0	0	10.000000000000002	
i 1	123.2591836734694	1.2625	71	1097	6	5	5	8	0	-2	8	0	0	5.292763705596874	
i 1	123.5034693877551	0.2525	72	395	4	1	3	2	0	1	2	0	0	12.0	
i 1	123.74612244897959	0.2525	72	395	4	3	14	2	0	1	2	0	0	11.000000000000002	
i 1	123.74775510204081	0.2525	74	395	6	5	11	2	0	-1	2	0	0	5.292763705596874	
i 1	123.75510204081633	0.2525	75	1097	6	1	4	2	0	-2	2	0	0	12.0	
i 1	123.99122448979591	2.02	67	395	6	17	4	0	0	1	0	0	0	0.007067402691058374	
i 1	123.99122448979591	2.02	60	1097	5	14	10	0	0	1	0	0	0	11.673286707214311	
i 1	123.9965306122449	1.2625	74	781	5	5	1	2	0	-2	2	0	0	5.292763705596874	
i 1	123.99816326530612	2.02	60	1097	6	17	14	5	0	0	5	0	0	0.007067402691058374	
i 1	124.0030612244898	1.2625	74	1097	6	5	3	8	0	-2	8	0	0	5.292763705596874	
i 1	124.00673469387755	0.505	72	781	3	1	8	2	0	1	2	0	0	12.0	
i 1	124.00673469387755	0.2525	75	781	4	9	8	2	0	-2	2	0	0	10.000000000000002	
i 1	124.24897959183673	1.2625	75	395	5	3	5	2	0	-2	2	0	0	11.000000000000002	
i 1	124.25387755102041	1.2625	72	395	4	3	16	2	0	1	2	0	0	11.000000000000002	
i 1	124.49489795918367	1.01	72	395	6	1	12	2	0	1	2	0	0	12.0	
i 1	124.50510204081633	1.5150000000000001	75	395	3	1	9	8	0	-2	8	0	0	12.0	
i 1	124.74163265306123	1.2625	75	395	4	4	15	2	0	1	2	0	0	11.000000000000002	
i 1	124.74285714285715	1.2625	71	395	5	5	6	8	0	-1	8	0	0	5.292763705596874	
i 1	124.75551020408163	1.2625	71	395	6	5	9	8	0	-1	8	0	0	5.292763705596874	
i 1	125.00265306122449	1.01	75	1097	6	1	10	2	0	-2	2	0	0	12.0	
i 1	125.00387755102041	3.0300000000000002	60	781	4	18	13	0	0	1	0	0	0	0.007067402691058374	
i 1	125.00428571428571	1.01	72	395	4	4	1	2	0	1	2	0	0	11.000000000000002	
i 1	125.00836734693877	1.01	60	1097	6	17	3	0	0	1	0	0	0	0.007067402691058374	
i 1	125.01	1.01	72	781	3	1	1	2	0	1	2	0	0	12.0	
i 1	125.2465306122449	0.7575000000000001	72	1097	5	2	5	2	0	1	2	0	0	11.000000000000002	
i 1	125.25755102040816	0.2525	74	781	5	5	1	2	0	-1	2	0	0	5.292763705596874	
i 1	125.50795918367346	0.2525	74	1097	6	5	6	8	0	-2	8	0	0	5.292763705596874	
i 1	125.74408163265306	2.02	74	781	5	5	2	2	0	-2	2	0	0	5.292763705596874	
i 1	125.74530612244898	0.2525	75	395	5	3	12	2	0	-2	2	0	0	11.000000000000002	
i 1	125.74857142857142	0.2525	72	1097	6	1	15	2	0	-2	2	0	0	12.0	
i 1	125.9904081632653	5.3025	60	79	7	17	4	5	0	0	5	0	0	0.007067402691058374	
i 1	125.99204081632654	1.5150000000000001	72	79	4	4	1	2	0	-2	2	0	0	11.000000000000002	
i 1	125.99285714285715	0.2525	74	79	5	5	13	8	0	-1	8	0	0	5.292763705596874	
i 1	125.99326530612245	0.2525	75	79	7	1	1	2	0	-2	2	0	0	12.0	
i 1	125.99612244897959	1.01	60	465	6	17	12	0	0	0	0	0	0	0.007067402691058374	
i 1	125.9965306122449	5.3025	67	79	7	17	2	0	0	0	0	0	0	0.007067402691058374	
i 1	125.99734693877551	0.2525	72	781	5	1	11	2	0	1	2	0	0	12.0	
i 1	125.99857142857142	5.3025	67	465	6	17	12	0	0	0	0	0	0	0.007067402691058374	
i 1	125.99938775510203	1.5150000000000001	74	79	7	5	13	8	0	-2	8	0	0	5.292763705596874	
i 1	125.99979591836734	4.04	67	79	6	14	10	0	0	1	0	0	0	11.673286707214311	
i 1	126.00224489795919	5.3025	60	465	6	7	4	5	0	0	5	0	0	6.072328213674957	
i 1	126.00265306122449	2.02	75	79	3	1	6	2	0	-2	2	0	0	12.0	
i 1	126.00265306122449	0.2525	75	79	6	2	15	2	0	1	2	0	0	11.000000000000002	
i 1	126.0030612244898	0.2525	72	465	4	4	14	2	0	-2	2	0	0	11.000000000000002	
i 1	126.00387755102041	1.01	67	79	6	14	8	5	0	1	5	0	0	4.974137601384988	
i 1	126.00510204081633	3.0300000000000002	67	781	4	18	5	0	0	0	0	0	0	0.007067402691058374	
i 1	126.00551020408163	3.0300000000000002	67	79	6	14	12	0	0	1	0	0	0	11.673286707214311	
i 1	126.00836734693877	0.2525	71	465	6	5	1	2	0	-2	2	0	0	5.292763705596874	
i 1	126.0091836734694	1.01	75	79	7	1	6	2	0	-2	2	0	0	12.0	
i 1	126.0091836734694	1.5150000000000001	75	465	5	3	13	2	0	-2	2	0	0	11.000000000000002	
i 1	126.24244897959184	2.02	74	465	6	5	14	2	0	-2	2	0	0	5.292763705596874	
i 1	126.25183673469388	0.2525	72	79	4	3	13	2	0	-2	2	0	0	11.000000000000002	
i 1	126.49897959183673	2.02	72	79	6	2	14	2	0	1	2	0	0	11.000000000000002	
i 1	126.75469387755102	0.2525	75	781	3	1	11	8	0	1	8	0	0	12.0	
i 1	126.9904081632653	1.2625	74	79	5	5	5	8	0	-1	8	0	0	5.292763705596874	
i 1	126.99204081632654	1.01	60	79	6	13	5	5	0	0	5	0	0	3.7306032010387407	
i 1	126.9969387755102	1.5150000000000001	72	79	4	3	8	2	0	-2	2	0	0	11.000000000000002	
i 1	127.00061224489797	3.0300000000000002	60	79	5	19	2	0	0	0	0	0	0	0.007067402691058374	
i 1	127.0034693877551	1.2625	75	79	7	1	15	2	0	-2	2	0	0	12.0	
i 1	127.00551020408163	4.2925	60	465	6	17	14	0	0	0	0	0	0	0.007067402691058374	
i 1	127.00755102040816	3.2825	75	79	7	1	7	2	0	-2	2	0	0	12.0	
i 1	127.0095918367347	1.01	67	79	6	14	7	5	0	1	5	0	0	4.974137601384988	
i 1	127.49122448979591	0.2525	72	781	4	9	2	2	0	1	2	0	0	10.000000000000002	
i 1	127.7408163265306	1.2625	71	465	6	5	2	2	0	-2	2	0	0	5.292763705596874	
i 1	127.75387755102041	1.2625	74	781	6	5	2	2	0	-1	2	0	0	5.292763705596874	
i 1	127.75510204081633	0.2525	75	465	5	3	7	2	0	-2	2	0	0	11.000000000000002	
i 1	127.75877551020409	2.525	75	781	5	1	9	8	0	1	8	0	0	12.0	
i 1	127.99408163265306	3.2825	60	781	4	18	2	0	0	1	0	0	0	0.007067402691058374	
i 1	127.99448979591837	0.2525	75	79	5	1	3	2	0	-2	2	0	0	12.0	
i 1	127.99489795918367	1.2625	75	79	6	2	12	2	0	1	2	0	0	11.000000000000002	
i 1	127.99612244897959	1.01	67	465	5	15	8	0	0	1	0	0	0	4.145114667820823	
i 1	127.9965306122449	1.01	60	79	6	13	14	5	0	0	5	0	0	3.7306032010387407	
i 1	127.9965306122449	3.0300000000000002	60	79	5	19	5	5	0	1	5	0	0	0.007067402691058374	
i 1	128.00755102040816	2.2725	72	465	4	4	1	2	0	-2	2	0	0	11.000000000000002	
i 1	128.00795918367348	1.2625	75	781	4	9	2	2	0	-2	2	0	0	10.000000000000002	
i 1	128.24	1.01	75	465	6	1	1	2	0	-2	2	0	0	12.0	
i 1	128.24530612244897	0.7575000000000001	72	79	3	24	4	2	0	-2	2	0	0	13.0	
i 1	128.25836734693877	2.525	71	79	7	5	5	2	0	-2	2	0	0	5.292763705596874	
i 1	128.49816326530612	1.2625	74	79	7	5	8	8	0	-2	8	0	0	5.292763705596874	
i 1	128.50510204081633	1.2625	74	781	6	5	4	2	0	-2	2	0	0	5.292763705596874	
i 1	128.74163265306123	1.5150000000000001	72	781	4	9	3	2	0	1	2	0	0	10.000000000000002	
i 1	128.99081632653062	1.01	67	465	5	15	11	0	0	1	0	0	0	4.145114667820823	
i 1	129.00020408163266	2.2725	67	781	4	18	16	0	0	0	0	0	0	0.007067402691058374	
i 1	129.00183673469388	2.02	67	79	4	14	8	0	0	1	0	0	0	11.673286707214311	
i 1	129.00755102040816	1.01	60	465	5	15	11	5	0	1	5	0	0	4.145114667820823	
i 1	129.00795918367348	0.505	72	79	5	24	2	2	0	-2	2	0	0	13.0	
i 1	129.24367346938774	1.5150000000000001	74	79	7	5	15	2	0	-1	2	0	0	5.292763705596874	
i 1	129.25755102040816	0.2525	72	79	6	2	9	2	0	1	2	0	0	11.000000000000002	
i 1	129.49244897959184	1.7675	75	79	7	1	11	2	0	-2	2	0	0	12.0	
i 1	129.49326530612245	0.2525	72	79	4	3	10	2	0	-2	2	0	0	11.000000000000002	
i 1	129.74285714285713	0.2525	72	781	5	1	15	2	0	1	2	0	0	12.0	
i 1	129.74367346938774	1.5150000000000001	75	465	4	24	2	2	0	1	2	0	0	13.0	
i 1	129.74367346938774	0.2525	74	79	5	5	8	8	0	-1	8	0	0	5.292763705596874	
i 1	129.74979591836734	1.5150000000000001	75	781	4	9	14	2	0	-2	2	0	0	10.000000000000002	
i 1	129.75755102040816	0.2525	75	79	6	2	14	2	0	1	2	0	0	11.000000000000002	
i 1	129.99489795918367	1.2625	74	781	6	5	13	2	0	-1	2	0	0	5.292763705596874	
i 1	129.99693877551022	1.01	60	465	5	15	13	5	0	1	5	0	0	4.145114667820823	
i 1	129.99775510204083	1.2625	60	79	5	19	4	0	0	0	0	0	0	0.007067402691058374	
i 1	130.00183673469388	1.2625	72	781	6	1	5	2	0	1	2	0	0	12.0	
i 1	130.00510204081633	1.01	67	781	4	16	7	5	0	0	5	0	0	4.5596261346029054	
i 1	130.00510204081633	1.2625	75	79	5	2	10	2	0	1	2	0	0	11.000000000000002	
i 1	130.01	1.2625	67	79	4	14	11	0	0	1	0	0	0	11.673286707214311	
i 1	130.24081632653062	0.7575000000000001	71	465	6	5	9	2	0	-2	2	0	0	5.292763705596874	
i 1	130.2461224489796	0.2525	72	79	4	4	15	2	0	-2	2	0	0	11.000000000000002	
i 1	130.49979591836734	0.7575000000000001	74	781	6	5	13	2	0	-2	2	0	0	5.292763705596874	
i 1	130.50428571428571	0.7575000000000001	74	79	7	5	5	8	0	-2	8	0	0	5.292763705596874	
i 1	130.50836734693877	0.2525	72	465	4	4	6	2	0	-2	2	0	0	11.000000000000002	
i 1	130.7412244897959	0.505	75	465	5	3	13	2	0	-2	2	0	0	11.000000000000002	
i 1	130.75918367346938	0.505	75	79	5	1	16	2	0	-2	2	0	0	12.0	
i 1	130.76	0.505	72	79	4	4	2	2	0	-2	2	0	0	11.000000000000002	
i 1	130.9912244897959	0.2525	74	465	6	5	15	2	0	-2	2	0	0	5.292763705596874	
i 1	130.99530612244897	0.2525	67	781	4	16	11	5	0	0	5	0	0	4.5596261346029054	
i 1	130.99857142857144	0.2525	67	79	5	14	5	0	0	1	0	0	0	11.673286707214311	
i 1	131.00183673469388	0.2525	75	781	6	1	16	8	0	1	8	0	0	12.0	
i 1	131.00469387755103	0.2525	72	79	5	2	14	2	0	1	2	0	0	11.000000000000002	
i 1	131.00551020408165	0.2525	67	781	4	16	12	0	0	0	0	0	0	4.5596261346029054	
i 1	131.00918367346938	0.2525	60	79	5	19	14	5	0	1	5	0	0	0.007067402691058374	
i 1	131.2412244897959	3.7875	60	902	4	14	15	0	5000	0	0	0	0	11.673286707214311	
i 1	131.24204081632652	1.7675	67	902	6	17	14	5	5000	1	5	0	0	0.007067402691058374	
i 1	131.24530612244897	0.7575000000000001	71	902	6	5	6	8	5000	-1	8	0	0	5.292763705596874	
i 1	131.2461224489796	0.7575000000000001	60	902	4	16	14	0	0	0	0	0	0	4.5596261346029054	
i 1	131.2473469387755	3.7875	60	88	7	17	16	5	0	1	5	0	0	0.007067402691058374	
i 1	131.2473469387755	3.7875	60	902	4	18	8	5	0	0	5	0	0	0.007067402691058374	
i 1	131.24775510204083	0.7575000000000001	75	902	6	1	12	2	0	1	2	0	0	12.0	
i 1	131.24816326530612	0.7575000000000001	60	902	4	16	9	5	0	1	5	0	0	4.5596261346029054	
i 1	131.24938775510205	0.2525	71	902	6	5	11	2	0	-2	2	0	0	5.292763705596874	
i 1	131.24979591836734	2.7775	60	88	7	17	5	5	0	1	5	0	0	0.007067402691058374	
i 1	131.25061224489795	3.7875	67	902	4	18	12	0	0	1	0	0	0	0.007067402691058374	
i 1	131.25061224489795	1.7675	74	88	7	5	10	8	0	-2	8	0	0	5.292763705596874	
i 1	131.25102040816327	0.2525	75	586	4	4	14	8	0	-2	8	0	0	11.000000000000002	
i 1	131.2538775510204	0.7575000000000001	72	902	6	1	4	2	5000	1	2	0	0	12.0	
i 1	131.25469387755103	0.2525	72	586	5	1	3	2	0	1	2	0	0	12.0	
i 1	131.25469387755103	0.2525	72	88	5	3	7	2	0	-2	2	0	0	11.000000000000002	
i 1	131.25469387755103	1.5150000000000001	60	586	4	19	14	5	0	1	5	0	0	0.007067402691058374	
i 1	131.25469387755103	1.01	71	902	6	5	8	2	0	-1	2	0	0	5.292763705596874	
i 1	131.25551020408165	0.7575000000000001	67	902	3	14	7	5	5000	0	5	0	0	11.673286707214311	
i 1	131.25632653061226	1.01	72	902	4	2	16	2	5000	1	2	0	0	11.000000000000002	
i 1	131.25632653061226	0.7575000000000001	60	902	6	17	11	0	5000	0	0	0	0	0.007067402691058374	
i 1	131.25714285714287	1.01	75	902	4	9	3	8	0	-2	8	0	0	10.000000000000002	
i 1	131.25714285714287	1.5150000000000001	67	586	4	19	13	0	0	1	0	0	0	0.007067402691058374	
i 1	131.25714285714287	0.7575000000000001	67	88	6	7	4	5	0	0	5	0	0	6.072328213674957	
i 1	131.50224489795917	0.505	75	902	6	1	1	8	5000	-2	8	0	0	12.0	
i 1	131.50673469387755	0.2525	75	88	5	4	1	2	0	-2	2	0	0	11.000000000000002	
i 1	131.50714285714287	1.01	72	902	6	1	12	8	0	1	8	0	0	12.0	
i 1	131.74163265306123	1.01	74	586	6	5	10	2	0	-2	2	0	0	5.292763705596874	
i 1	131.75020408163266	0.7575000000000001	72	902	4	2	14	2	5000	-2	2	0	0	11.000000000000002	
i 1	131.75755102040816	0.7575000000000001	75	902	4	9	7	2	0	1	2	0	0	10.000000000000002	
i 1	131.99244897959184	1.01	60	902	4	16	6	0	0	0	0	0	0	4.5596261346029054	
i 1	131.99244897959184	0.505	71	902	5	5	7	8	5000	-1	8	0	0	5.292763705596874	
i 1	131.99326530612245	0.7575000000000001	75	586	4	4	2	8	0	-2	8	0	0	11.000000000000002	
i 1	131.99489795918367	0.7575000000000001	72	586	6	1	11	2	0	1	2	0	0	12.0	
i 1	131.99938775510205	2.02	75	902	6	1	11	8	5000	-2	8	0	0	12.0	
i 1	132.00102040816327	1.01	75	88	5	4	10	2	0	-2	2	0	0	11.000000000000002	
i 1	132.00183673469388	3.0300000000000002	67	902	4	14	6	5	5000	0	5	0	0	11.673286707214311	
i 1	132.0026530612245	1.2625	75	88	7	1	13	2	0	1	2	0	0	12.0	
i 1	132.00306122448978	2.02	67	88	4	7	2	5	0	0	5	0	0	6.072328213674957	
i 1	132.0087755102041	0.7575000000000001	67	586	5	12	7	0	0	1	0	0	0	4.5596261346029054	
i 1	132.4904081632653	2.525	74	88	7	5	1	2	0	-2	2	0	0	5.292763705596874	
i 1	132.50428571428571	0.2525	72	88	4	3	13	2	0	-2	2	0	0	11.000000000000002	
i 1	132.50836734693877	0.2525	74	586	6	5	7	8	0	-2	8	0	0	5.292763705596874	
i 1	132.74204081632652	2.2725	71	404	6	5	4	8	0	-1	8	0	0	5.292763705596874	
i 1	132.7461224489796	0.7575000000000001	71	404	6	5	5	8	0	-2	8	0	0	5.292763705596874	
i 1	132.74775510204083	2.02	72	902	6	1	13	8	0	1	8	0	0	12.0	
i 1	132.74775510204083	0.2525	67	404	5	12	9	5	0	1	5	0	0	4.5596261346029054	
i 1	132.74979591836734	2.2725	60	404	4	19	14	0	0	1	0	0	0	0.007067402691058374	
i 1	132.75795918367348	1.5150000000000001	75	404	4	4	15	2	0	-2	2	0	0	11.000000000000002	
i 1	132.75795918367348	2.2725	60	404	4	19	7	0	0	0	0	0	0	0.007067402691058374	
i 1	132.75918367346938	0.505	75	404	6	1	6	2	0	-2	2	0	0	12.0	
i 1	132.75918367346938	0.2525	75	902	4	9	2	2	0	1	2	0	0	10.000000000000002	
i 1	132.99326530612245	1.01	67	404	5	12	2	5	0	1	5	0	0	4.5596261346029054	
i 1	132.99326530612245	1.2625	75	88	4	4	9	2	0	-2	2	0	0	11.000000000000002	
i 1	132.99489795918367	1.01	60	404	5	12	2	0	0	0	0	0	0	4.5596261346029054	
i 1	133.00795918367348	1.01	67	902	5	25	7	0	5000	0	0	0	0	1.5942350572922197	
i 1	133.24285714285713	0.2525	75	902	6	1	8	2	0	1	2	0	0	12.0	
i 1	133.2465306122449	0.2525	72	404	4	3	10	2	0	-2	2	0	0	11.000000000000002	
i 1	133.49897959183673	0.505	75	902	4	9	2	2	0	1	2	0	0	10.000000000000002	
i 1	133.5038775510204	0.2525	72	902	6	1	15	2	5000	1	2	0	0	12.0	
i 1	133.50795918367348	0.505	71	902	5	5	3	8	5000	-1	8	0	0	5.292763705596874	
i 1	133.74	1.2625	72	88	5	24	6	2	0	1	2	0	0	13.0	
i 1	133.75551020408165	1.2625	72	902	4	2	2	2	5000	-2	2	0	0	11.000000000000002	
i 1	133.9904081632653	1.01	67	902	5	25	6	0	5000	0	0	0	0	1.5942350572922197	
i 1	133.99204081632652	0.505	75	902	6	1	15	8	5000	-2	8	0	0	12.0	
i 1	133.99448979591835	1.01	60	902	5	25	7	0	5000	0	0	0	0	1.5942350572922197	
i 1	133.99571428571429	0.2525	74	88	5	5	15	8	0	-2	8	0	0	5.292763705596874	
i 1	133.9965306122449	1.01	67	88	4	7	2	5	0	0	5	0	0	6.072328213674957	
i 1	133.99693877551022	1.01	75	902	3	9	11	2	0	1	2	0	0	10.000000000000002	
i 1	133.9973469387755	1.01	72	404	4	24	1	2	0	-2	2	0	0	13.0	
i 1	134.0087755102041	1.01	60	404	5	12	13	0	0	0	0	0	0	4.5596261346029054	
i 1	134.24693877551022	0.7575000000000001	74	902	5	5	6	8	5000	-2	8	0	0	5.292763705596874	
i 1	134.24816326530612	0.7575000000000001	71	902	6	5	5	2	0	-2	2	0	0	5.292763705596874	
i 1	134.25755102040816	0.505	72	404	4	3	14	2	0	-2	2	0	0	11.000000000000002	
i 1	134.49204081632652	0.505	71	902	5	5	11	8	5000	-1	8	0	0	5.292763705596874	
i 1	134.74448979591835	0.2525	72	902	6	1	2	2	5000	1	2	0	0	12.0	
i 1	134.74979591836734	0.2525	75	404	6	1	15	2	0	-2	2	0	0	12.0	
i 1	134.75020408163266	0.2525	75	404	4	4	9	2	0	-2	2	0	0	11.000000000000002	
i 1	134.75591836734694	0.2525	72	88	4	3	9	2	0	-2	2	0	0	11.000000000000002	
i 1	134.99	1.5150000000000001	72	902	6	1	2	2	5000	1	2	0	0	12.0	
i 1	134.99204081632652	9.09	67	902	5	25	2	0	5000	0	0	0	0	1.6794744170929128	
i 1	134.99408163265306	0.2525	74	586	6	5	12	2	0	-1	2	0	0	6.029069243094779	
i 1	134.99530612244897	0.505	75	200	4	9	7	2	0	-2	2	0	0	9.0	
i 1	134.9961224489796	2.02	67	200	5	18	6	0	0	0	0	0	0	0.006277052524044922	
i 1	134.9961224489796	10.1	60	902	5	25	16	0	5000	0	0	0	0	1.6794744170929128	
i 1	134.9973469387755	1.01	67	586	5	25	4	0	0	1	0	0	0	1.6794744170929128	
i 1	134.99775510204083	1.2625	75	586	6	1	12	2	0	-2	2	0	0	12.0	
i 1	134.99897959183673	0.2525	71	586	5	5	10	8	0	-1	8	0	0	6.029069243094779	
i 1	134.99979591836734	1.7675	71	902	4	5	3	8	5000	-1	8	0	0	6.029069243094779	
i 1	135.00142857142856	0.505	72	586	4	24	13	2	0	1	2	0	0	13.0	
i 1	135.00183673469388	0.2525	72	902	5	2	16	2	5000	-2	2	0	0	10.0	
i 1	135.00183673469388	3.0300000000000002	60	586	4	19	1	0	0	0	0	0	0	0.006277052524044922	
i 1	135.0026530612245	1.01	75	586	4	3	15	8	0	1	8	0	0	10.0	
i 1	135.00755102040816	1.01	75	586	4	4	16	8	0	-2	8	0	0	10.0	
i 1	135.00755102040816	3.0300000000000002	60	586	4	19	13	0	0	0	0	0	0	0.006277052524044922	
i 1	135.00836734693877	0.2525	72	586	4	24	10	2	0	1	2	0	0	13.0	
i 1	135.0087755102041	1.01	67	200	5	18	1	0	0	1	0	0	0	0.006277052524044922	
i 1	135.00918367346938	1.7675	71	200	7	5	11	8	0	-2	8	0	0	6.029069243094779	
i 1	135.24775510204083	0.505	71	200	7	5	14	8	0	-2	8	0	0	6.029069243094779	
i 1	135.4912244897959	1.5150000000000001	72	200	7	1	13	2	0	-2	2	0	0	12.0	
i 1	135.49897959183673	0.505	75	586	4	3	2	2	0	1	2	0	0	10.0	
i 1	135.50020408163266	0.505	72	902	4	2	1	2	5000	1	2	0	0	10.0	
i 1	135.50469387755103	1.5150000000000001	72	902	5	2	9	2	5000	-2	2	0	0	10.0	
i 1	135.74	2.2725	75	902	6	1	8	8	5000	-2	8	0	0	12.0	
i 1	135.7461224489796	1.01	72	200	4	9	12	2	0	1	2	0	0	9.0	
i 1	135.74816326530612	0.2525	74	586	5	5	16	2	0	-1	2	0	0	6.029069243094779	
i 1	135.99163265306123	3.535	67	586	5	25	4	0	0	1	0	0	0	1.6794744170929128	
i 1	135.99204081632652	0.2525	72	902	5	2	5	2	5000	1	2	0	0	10.0	
i 1	135.99244897959184	0.2525	75	586	3	3	15	2	0	1	2	0	0	10.0	
i 1	135.99693877551022	0.2525	71	586	5	5	13	8	0	-1	8	0	0	6.029069243094779	
i 1	136.00755102040816	1.01	60	586	5	25	11	0	0	0	0	0	0	1.6794744170929128	
i 1	136.24	1.7675	72	586	4	4	2	2	0	1	2	0	0	10.0	
i 1	136.24367346938774	2.7775	75	200	4	9	14	2	0	-2	2	0	0	9.0	
i 1	136.25714285714287	1.5150000000000001	74	586	6	5	2	2	0	-1	2	0	0	6.029069243094779	
i 1	136.26	0.7575000000000001	74	586	5	5	9	2	0	-1	2	0	0	6.029069243094779	
i 1	136.49489795918367	0.7575000000000001	72	586	6	1	7	2	0	-2	2	0	0	12.0	
i 1	136.50551020408165	0.7575000000000001	72	586	4	24	1	2	0	1	2	0	0	13.0	
i 1	136.75551020408165	2.02	71	200	5	5	14	8	0	-2	8	0	0	6.029069243094779	
i 1	136.9904081632653	2.525	60	586	5	25	10	0	0	0	0	0	0	1.6794744170929128	
i 1	136.9912244897959	1.01	67	200	5	26	8	5	0	1	5	0	0	1.6794744170929128	
i 1	136.99816326530612	0.7575000000000001	74	586	4	5	16	2	0	-1	2	0	0	6.029069243094779	
i 1	137.00061224489795	0.2525	72	902	5	2	9	2	5000	1	2	0	0	10.0	
i 1	137.00714285714287	0.2525	75	586	3	3	11	2	0	1	2	0	0	10.0	
i 1	137.00714285714287	1.01	71	586	5	5	7	8	0	-1	8	0	0	6.029069243094779	
i 1	137.01	2.02	72	200	6	1	7	2	0	-2	2	0	0	12.0	
i 1	137.24163265306123	0.2525	72	200	4	9	2	2	0	1	2	0	0	9.0	
i 1	137.25510204081633	0.2525	72	200	6	1	6	2	0	-2	2	0	0	12.0	
i 1	137.49244897959184	0.2525	72	586	6	1	7	2	0	-2	2	0	0	12.0	
i 1	137.50469387755103	0.2525	75	586	6	1	16	2	0	-2	2	0	0	12.0	
i 1	137.7534693877551	0.2525	71	902	4	5	3	8	5000	-1	8	0	0	6.029069243094779	
i 1	137.7538775510204	1.7675	72	586	4	24	10	2	0	1	2	0	0	13.0	
i 1	137.99326530612245	1.01	67	200	5	26	14	5	0	1	5	0	0	1.6794744170929128	
i 1	137.99367346938774	0.2525	74	751	3	3	8	8	0	-2	8	0	0	10.0	
i 1	137.9965306122449	1.01	75	902	5	1	14	8	5000	-2	8	0	0	12.0	
i 1	137.99816326530612	1.01	66	751	4	19	2	6	0	1	6	0	0	0.006277052524044922	
i 1	138.00183673469388	1.5150000000000001	67	200	5	26	8	5	0	1	5	0	0	1.6794744170929128	
i 1	138.00224489795917	0.2525	71	902	6	5	7	8	5000	-1	8	0	0	6.029069243094779	
i 1	138.0026530612245	1.2625	72	586	4	4	1	2	0	1	2	0	0	10.0	
i 1	138.0038775510204	0.7575000000000001	71	586	4	5	12	8	0	-1	8	0	0	6.029069243094779	
i 1	138.24571428571429	1.2625	72	200	4	9	11	2	0	1	2	0	0	9.0	
i 1	138.25102040816327	0.7575000000000001	74	902	4	5	2	8	5000	-2	8	0	0	6.029069243094779	
i 1	138.2534693877551	1.5150000000000001	72	902	4	2	13	2	5000	-2	2	0	0	10.0	
i 1	138.2587755102041	0.7575000000000001	75	586	5	3	3	8	0	1	8	0	0	10.0	
i 1	138.2595918367347	1.2625	72	751	4	5	14	1	0	0	1	0	0	6.029069243094779	
i 1	138.49	1.01	72	200	7	1	15	2	0	-2	2	0	0	12.0	
i 1	138.75224489795917	0.2525	74	586	4	5	4	2	0	-1	2	0	0	6.029069243094779	
i 1	138.99	0.505	75	586	4	3	8	8	0	1	8	0	0	10.0	
i 1	138.99326530612245	2.02	71	902	6	5	11	8	5000	-1	8	0	0	6.029069243094779	
i 1	138.9961224489796	0.505	72	751	4	24	7	0	0	-1	0	0	0	13.0	
i 1	138.9965306122449	0.505	61	751	3	27	13	6	0	1	6	0	0	2.019395203020639	
i 1	138.9973469387755	0.7575000000000001	74	902	6	5	4	8	5000	-2	8	0	0	6.029069243094779	
i 1	138.99897959183673	0.505	67	200	5	26	2	5	0	1	5	0	0	1.6794744170929128	
i 1	139.00061224489795	0.505	74	751	3	3	2	8	0	-2	8	0	0	10.0	
i 1	139.00061224489795	0.505	71	200	4	5	16	8	0	-2	8	0	0	6.029069243094779	
i 1	139.0026530612245	0.505	72	586	6	1	4	2	0	-2	2	0	0	12.0	
i 1	139.00428571428571	0.2525	75	200	5	9	5	2	0	-2	2	0	0	9.0	
i 1	139.2534693877551	0.2525	72	200	7	1	1	2	0	-2	2	0	0	12.0	
i 1	139.25428571428571	1.2625	72	902	5	1	12	2	5000	1	2	0	0	12.0	
i 1	139.4904081632653	0.2525	69	88	7	1	10	1	0	-1	1	0	0	12.0	
i 1	139.49285714285713	2.2725	69	88	4	5	1	1	0	-1	1	0	0	6.029069243094779	
i 1	139.49326530612245	2.2725	61	88	5	26	4	6	0	0	6	0	0	1.6794744170929128	
i 1	139.49367346938774	5.3025	66	404	5	25	2	9	5000	0	9	0	0	1.6794744170929128	
i 1	139.49489795918367	2.2725	66	88	5	26	2	9	0	0	9	0	0	1.6794744170929128	
i 1	139.49775510204083	0.2525	69	404	4	24	14	1	5000	-1	1	0	0	13.0	
i 1	139.49857142857144	0.505	69	902	4	5	6	0	0	-1	0	0	0	6.029069243094779	
i 1	139.50102040816327	0.505	71	88	4	9	9	2	0	-2	2	0	0	9.0	
i 1	139.50183673469388	0.505	69	404	6	1	7	1	5000	0	1	0	0	12.0	
i 1	139.50469387755103	0.505	74	404	4	3	7	2	5000	-1	2	0	0	10.0	
i 1	139.50551020408165	0.505	71	902	3	3	6	8	0	-2	8	0	0	10.0	
i 1	139.50591836734694	0.505	66	902	3	27	10	6	0	0	6	0	0	2.019395203020639	
i 1	139.50632653061226	1.01	69	88	7	1	3	0	0	-1	0	0	0	12.0	
i 1	139.50795918367348	5.3025	66	404	5	25	3	9	5000	1	9	0	0	1.6794744170929128	
i 1	139.50836734693877	0.2525	72	902	4	24	10	1	0	-1	1	0	0	13.0	
i 1	139.5087755102041	1.01	72	902	4	2	1	2	5000	1	2	0	0	10.0	
i 1	139.99081632653062	0.7575000000000001	69	88	7	1	7	1	0	-1	1	0	0	12.0	
i 1	139.9912244897959	5.05	67	902	5	14	1	0	5000	1	0	0	0	4.974137601384988	
i 1	139.99204081632652	0.2525	72	902	4	5	16	1	0	0	1	0	0	6.029069243094779	
i 1	139.99326530612245	1.01	71	88	5	9	11	2	0	-2	2	0	0	9.0	
i 1	139.9961224489796	0.505	71	88	5	9	1	2	0	-2	2	0	0	9.0	
i 1	139.99693877551022	1.7675	66	902	3	27	11	6	0	0	6	0	0	2.019395203020639	
i 1	140.0026530612245	1.7675	69	404	5	1	7	1	5000	0	1	0	0	12.0	
i 1	140.00591836734694	0.7575000000000001	75	902	5	1	4	8	5000	-2	8	0	0	12.0	
i 1	140.00795918367348	1.2625	72	902	4	2	9	2	5000	-2	2	0	0	10.0	
i 1	140.0095918367347	1.01	66	902	3	27	8	6	0	0	6	0	0	2.019395203020639	
i 1	140.24204081632652	1.5150000000000001	71	902	3	4	13	8	0	-1	8	0	0	10.0	
i 1	140.24979591836734	1.5150000000000001	69	902	6	1	6	0	0	-1	0	0	0	12.0	
i 1	140.2538775510204	3.2825	74	404	4	4	8	8	5000	-2	8	0	0	10.0	
i 1	140.2538775510204	0.2525	69	88	4	5	5	1	0	0	1	0	0	6.029069243094779	
i 1	140.50795918367348	0.2525	69	902	4	5	15	0	0	-1	0	0	0	6.029069243094779	
i 1	140.74163265306123	0.2525	72	902	4	24	13	1	0	-1	1	0	0	13.0	
i 1	140.74244897959184	0.2525	74	902	6	5	14	8	5000	-2	8	0	0	6.029069243094779	
i 1	140.99	0.7575000000000001	69	88	7	1	16	1	0	-1	1	0	0	12.0	
i 1	140.99367346938774	0.7575000000000001	71	902	4	5	2	8	5000	-1	8	0	0	6.029069243094779	
i 1	140.99408163265306	2.02	75	902	5	1	7	8	5000	-2	8	0	0	12.0	
i 1	140.99489795918367	2.02	72	404	6	5	3	0	5000	0	0	0	0	6.029069243094779	
i 1	141.0026530612245	0.7575000000000001	69	902	3	5	7	0	0	-1	0	0	0	6.029069243094779	
i 1	141.00591836734694	0.7575000000000001	66	902	3	27	8	6	0	0	6	0	0	2.019395203020639	
i 1	141.00673469387755	5.05	67	902	5	13	9	0	5000	0	0	0	0	3.7306032010387407	
i 1	141.24530612244897	0.505	71	902	4	3	15	8	0	-2	8	0	0	10.0	
i 1	141.7404081632653	3.0300000000000002	61	1123	3	27	15	6	0	0	6	0	0	2.019395203020639	
i 1	141.7404081632653	1.5150000000000001	72	1123	3	5	8	1	0	0	1	0	0	6.029069243094779	
i 1	141.7461224489796	3.0300000000000002	66	154	5	26	1	6	0	0	6	0	0	1.6794744170929128	
i 1	141.74775510204083	0.2525	69	404	4	24	16	1	5000	-1	1	0	0	13.0	
i 1	141.74897959183673	0.2525	74	154	5	9	12	8	0	-2	8	0	0	9.0	
i 1	141.74897959183673	3.0300000000000002	66	1123	3	27	7	9	0	0	9	0	0	2.019395203020639	
i 1	141.74938775510205	3.0300000000000002	66	154	5	26	14	6	0	0	6	0	0	1.6794744170929128	
i 1	141.75020408163266	0.2525	72	154	7	1	6	0	0	0	0	0	0	12.0	
i 1	141.75591836734694	0.2525	71	1123	3	4	14	2	0	-1	2	0	0	10.0	
i 1	141.75836734693877	0.2525	74	902	6	5	2	8	5000	-2	8	0	0	6.029069243094779	
i 1	141.75918367346938	0.2525	69	404	6	5	10	1	5000	0	1	0	0	6.029069243094779	
i 1	141.99	0.2525	72	902	5	1	8	2	5000	1	2	0	0	12.0	
i 1	141.99163265306123	2.7775	61	404	5	15	9	9	5000	0	9	0	0	4.145114667820823	
i 1	141.99857142857144	0.2525	71	902	4	5	2	8	5000	-1	8	0	0	6.029069243094779	
i 1	142.00183673469388	1.2625	72	154	5	1	11	0	0	0	0	0	0	12.0	
i 1	142.0087755102041	0.2525	74	1123	4	3	13	2	0	-2	2	0	0	10.0	
i 1	142.0087755102041	1.5150000000000001	71	1123	4	4	13	2	0	-1	2	0	0	10.0	
i 1	142.24163265306123	1.7675	69	404	6	5	16	1	5000	0	1	0	0	6.029069243094779	
i 1	142.24285714285713	0.2525	69	404	5	1	12	1	5000	0	1	0	0	12.0	
i 1	142.24693877551022	2.525	72	1123	3	5	3	1	0	0	1	0	0	6.029069243094779	
i 1	142.25020408163266	1.2625	69	404	4	24	2	1	5000	-1	1	0	0	13.0	
i 1	142.2595918367347	0.2525	72	902	4	2	12	2	5000	-2	2	0	0	10.0	
i 1	142.49938775510205	1.01	69	1123	4	24	3	1	0	-1	1	0	0	13.0	
i 1	142.50428571428571	0.2525	74	1123	4	3	16	2	0	-2	2	0	0	10.0	
i 1	142.7412244897959	1.01	74	154	4	9	13	2	0	-1	2	0	0	9.0	
i 1	142.75551020408165	1.01	72	902	4	2	9	2	5000	-2	2	0	0	10.0	
i 1	142.99	1.01	72	1123	6	1	14	0	0	0	0	0	0	12.0	
i 1	142.99163265306123	0.2525	75	902	4	1	15	8	5000	-2	8	0	0	12.0	
i 1	142.99489795918367	1.2625	69	404	5	1	11	1	5000	0	1	0	0	12.0	
i 1	142.99979591836734	1.01	72	902	5	1	11	2	5000	1	2	0	0	12.0	
i 1	143.0095918367347	1.7675	61	404	5	15	9	6	5000	1	6	0	0	4.145114667820823	
i 1	143.24408163265306	1.5150000000000001	69	154	6	5	15	1	0	-1	1	0	0	6.029069243094779	
i 1	143.2595918367347	0.7575000000000001	74	404	4	3	7	2	5000	-1	2	0	0	10.0	
i 1	143.26	0.7575000000000001	74	1123	3	3	2	2	0	-2	2	0	0	10.0	
i 1	143.4965306122449	0.2525	72	154	5	1	3	0	0	0	0	0	0	12.0	
i 1	143.50224489795917	1.2625	74	902	4	5	10	8	5000	-2	8	0	0	6.029069243094779	
i 1	143.74244897959184	0.2525	72	902	4	2	13	2	5000	1	2	0	0	10.0	
i 1	143.7526530612245	1.01	69	154	5	1	2	1	0	0	1	0	0	12.0	
i 1	143.99489795918367	2.02	67	902	5	25	1	0	5000	0	0	0	0	1.6794744170929128	
i 1	144.0034693877551	0.7575000000000001	69	404	4	5	10	1	5000	0	1	0	0	6.029069243094779	
i 1	144.00428571428571	1.01	72	902	4	1	2	2	5000	1	2	0	0	12.0	
i 1	144.00673469387755	0.7575000000000001	66	154	5	16	16	9	0	1	9	0	0	4.5596261346029054	
i 1	144.0095918367347	0.2525	72	1123	4	1	15	0	0	0	0	0	0	12.0	
i 1	144.24897959183673	0.2525	75	902	4	1	14	8	5000	-2	8	0	0	12.0	
i 1	144.25102040816327	0.2525	72	154	5	1	1	0	0	0	0	0	0	12.0	
i 1	144.50510204081633	1.7675	71	902	6	5	12	8	5000	-1	8	0	0	6.029069243094779	
i 1	144.50836734693877	0.2525	69	404	5	1	7	1	5000	0	1	0	0	12.0	
i 1	144.7404081632653	1.2625	69	104	6	5	1	1	0	-1	1	0	0	6.029069243094779	
i 1	144.74530612244897	1.5150000000000001	61	602	5	25	7	6	0	1	6	0	0	1.6794744170929128	
i 1	144.74571428571429	1.5150000000000001	61	104	5	26	1	6	0	0	6	0	0	1.6794744170929128	
i 1	144.74775510204083	1.5150000000000001	61	919	3	27	4	6	0	1	6	0	0	2.019395203020639	
i 1	144.74897959183673	1.5150000000000001	66	602	5	15	4	9	0	1	9	0	0	4.145114667820823	
i 1	144.74938775510205	1.5150000000000001	61	104	5	16	4	9	0	0	9	0	0	4.5596261346029054	
i 1	144.74979591836734	1.5150000000000001	61	104	5	26	1	9	0	0	9	0	0	1.6794744170929128	
i 1	144.75061224489795	0.2525	72	919	4	24	12	1	0	-1	1	0	0	13.0	
i 1	144.75224489795917	1.5150000000000001	66	919	3	27	14	9	0	0	9	0	0	2.019395203020639	
i 1	144.7534693877551	1.5150000000000001	66	602	5	15	16	9	0	0	9	0	0	4.145114667820823	
i 1	144.75428571428571	1.2625	66	602	5	25	16	9	0	0	9	0	0	1.6794744170929128	
i 1	144.75510204081633	0.2525	72	919	3	5	7	1	0	-1	1	0	0	6.029069243094779	
i 1	144.75836734693877	0.2525	72	602	5	1	16	1	0	0	1	0	0	12.0	
i 1	144.75918367346938	0.505	69	602	4	5	5	1	0	0	1	0	0	6.029069243094779	
i 1	144.99979591836734	1.01	72	602	4	1	7	1	0	0	1	0	0	12.0	
i 1	145.00306122448978	0.505	72	919	5	5	9	1	0	-1	1	0	0	6.029069243094779	
i 1	145.0034693877551	1.2625	60	902	5	25	16	0	5000	0	0	0	0	1.6794744170929128	
i 1	145.00591836734694	1.2625	66	104	5	16	1	9	0	0	9	0	0	4.5596261346029054	
i 1	145.00714285714287	0.2525	72	104	5	1	5	0	0	0	0	0	0	12.0	
i 1	145.00836734693877	1.2625	67	902	5	14	16	0	5000	1	0	0	0	4.974137601384988	
i 1	145.0095918367347	1.2625	72	919	4	24	6	1	0	-1	1	0	0	13.0	
i 1	145.24285714285713	1.01	69	104	5	1	16	0	0	-1	0	0	0	12.0	
i 1	145.2595918367347	1.01	75	902	4	1	11	8	5000	-2	8	0	0	12.0	
i 1	145.4973469387755	0.505	69	602	4	5	12	0	0	0	0	0	0	6.029069243094779	
i 1	145.50102040816327	0.2525	69	602	4	5	13	1	0	0	1	0	0	6.029069243094779	
i 1	145.74081632653062	0.505	72	919	5	5	3	1	0	-1	1	0	0	6.029069243094779	
i 1	145.74408163265306	0.2525	72	602	4	24	2	1	0	0	1	0	0	13.0	
i 1	145.99204081632652	0.2525	67	902	5	13	2	0	5000	0	0	0	0	3.7306032010387407	
i 1	145.99326530612245	0.2525	72	602	4	24	10	1	0	0	1	0	0	13.0	
i 1	145.99979591836734	0.2525	66	602	5	25	8	9	0	0	9	0	0	1.6794744170929128	
i 1	146.00306122448978	0.2525	69	602	6	5	13	0	0	0	0	0	0	6.029069243094779	
i 1	146.00551020408165	0.2525	69	104	4	5	5	1	0	-1	1	0	0	6.029069243094779	
i 1	146.00632653061226	0.2525	66	919	5	12	15	6	0	1	6	0	0	4.5596261346029054	
i 1	146.2404081632653	1.7675	66	774	5	25	16	9	0	1	9	0	0	1.6794744170929128	
i 1	146.24367346938774	2.2725	66	1090	5	13	4	6	0	0	6	0	0	3.7306032010387407	
i 1	146.24489795918367	0.7575000000000001	66	774	5	25	2	6	0	0	6	0	0	1.6794744170929128	
i 1	146.2461224489796	1.01	69	774	4	24	6	1	0	-1	1	0	0	13.0	
i 1	146.24775510204083	0.7575000000000001	61	774	5	15	16	9	0	0	9	0	0	4.145114667820823	
i 1	146.24775510204083	2.2725	66	1090	4	16	7	9	0	0	9	0	0	4.5596261346029054	
i 1	146.24857142857144	0.7575000000000001	72	774	5	5	13	0	0	0	0	0	0	6.029069243094779	
i 1	146.24897959183673	1.7675	61	1090	5	14	15	9	0	1	9	0	0	4.974137601384988	
i 1	146.24897959183673	0.2525	69	1090	6	5	11	0	0	-1	0	0	0	6.029069243094779	
i 1	146.24979591836734	1.7675	61	774	5	15	1	9	0	1	9	0	0	4.145114667820823	
i 1	146.25061224489795	0.505	72	1090	4	1	2	1	0	-1	1	0	0	12.0	
i 1	146.25061224489795	1.7675	66	1090	4	26	13	9	0	0	9	0	0	1.6794744170929128	
i 1	146.25102040816327	1.7675	72	774	5	5	9	1	0	-1	1	0	0	6.029069243094779	
i 1	146.25428571428571	0.7575000000000001	72	774	6	5	7	0	0	-1	0	0	0	6.029069243094779	
i 1	146.25469387755103	0.7575000000000001	66	1090	5	25	14	6	0	0	6	0	0	1.6794744170929128	
i 1	146.25632653061226	2.2725	66	1090	4	16	6	9	0	1	9	0	0	4.5596261346029054	
i 1	146.25673469387755	2.2725	66	1090	4	26	4	6	0	0	6	0	0	1.6794744170929128	
i 1	146.25714285714287	2.2725	61	774	5	12	2	9	0	1	9	0	0	4.5596261346029054	
i 1	146.25795918367348	1.01	69	774	4	24	7	0	0	-1	0	0	0	13.0	
i 1	146.25918367346938	2.2725	61	774	3	27	6	6	0	0	6	0	0	2.019395203020639	
i 1	146.2595918367347	0.7575000000000001	69	774	4	5	14	1	0	0	1	0	0	6.029069243094779	
i 1	146.2595918367347	0.2525	72	1090	3	5	13	0	0	0	0	0	0	6.029069243094779	
i 1	146.26	2.2725	61	774	3	27	13	6	0	1	6	0	0	2.019395203020639	
i 1	146.50714285714287	0.2525	72	774	4	1	16	0	0	0	0	0	0	12.0	
i 1	146.74163265306123	1.7675	69	1090	4	1	11	1	0	-1	1	0	0	12.0	
i 1	146.74979591836734	1.2625	72	1090	4	1	7	1	0	0	1	0	0	12.0	
i 1	146.99326530612245	1.5150000000000001	69	774	6	5	5	1	0	0	1	0	0	6.029069243094779	
i 1	146.9961224489796	1.5150000000000001	66	774	5	25	12	6	0	0	6	0	0	1.6794744170929128	
i 1	146.99693877551022	1.5150000000000001	66	774	5	12	7	9	0	1	9	0	0	4.5596261346029054	
i 1	146.99979591836734	1.01	69	1090	6	5	11	0	0	0	0	0	0	6.029069243094779	
i 1	147.00142857142856	1.5150000000000001	72	1090	3	5	16	0	0	0	0	0	0	6.029069243094779	
i 1	147.0026530612245	1.5150000000000001	61	774	5	15	10	9	0	0	9	0	0	4.145114667820823	
i 1	147.00428571428571	1.01	72	1090	4	1	15	1	0	-1	1	0	0	12.0	
i 1	147.49775510204083	0.2525	72	774	4	1	15	0	0	0	0	0	0	12.0	
i 1	147.99326530612245	0.505	72	1090	5	1	5	1	0	-1	1	0	0	12.0	
i 1	147.9965306122449	0.505	72	1090	3	1	5	1	0	0	1	0	0	12.0	
i 1	147.9965306122449	0.505	66	1090	4	26	8	9	0	0	9	0	0	1.6794744170929128	
i 1	147.99857142857144	0.505	61	1090	5	14	14	9	0	1	9	0	0	4.974137601384988	
i 1	147.99979591836734	0.505	72	774	3	5	13	1	0	-1	1	0	0	6.029069243094779	
i 1	148.00469387755103	0.505	69	1090	6	5	10	0	0	0	0	0	0	6.029069243094779	
i 1	148.00510204081633	0.505	69	1090	6	5	15	0	0	-1	0	0	0	6.029069243094779	
i 1	148.00836734693877	0.505	61	774	5	15	1	9	0	1	9	0	0	4.145114667820823	
i 1	148.0095918367347	0.505	72	1090	3	1	2	1	0	-1	1	0	0	12.0	
i 1	148.49	2.525	61	600	5	12	5	9	0	0	9	0	0	4.5596261346029054	
i 1	148.4904081632653	1.01	72	102	6	1	6	0	0	-1	0	0	0	12.0	
i 1	148.49285714285713	0.505	61	916	4	16	12	6	0	1	6	0	0	4.5596261346029054	
i 1	148.49326530612245	1.5150000000000001	66	916	5	15	15	6	0	1	6	0	0	4.145114667820823	
i 1	148.49489795918367	0.2525	72	102	5	1	16	0	0	-1	0	0	0	12.0	
i 1	148.49489795918367	0.505	66	916	4	26	12	6	0	1	6	0	0	1.6794744170929128	
i 1	148.49530612244897	0.505	66	916	5	25	1	9	0	1	9	0	0	1.6794744170929128	
i 1	148.4961224489796	1.5150000000000001	66	916	4	26	2	6	0	1	6	0	0	1.6794744170929128	
i 1	148.4973469387755	1.5150000000000001	61	102	6	14	12	6	0	0	6	0	0	4.974137601384988	
i 1	148.49938775510205	1.01	69	916	3	1	5	0	0	-1	0	0	0	12.0	
i 1	148.50142857142856	0.505	72	600	3	5	13	1	0	0	1	0	0	6.029069243094779	
i 1	148.50224489795917	0.505	72	916	3	5	8	1	0	0	1	0	0	6.029069243094779	
i 1	148.5026530612245	0.505	61	102	6	13	14	6	0	1	6	0	0	3.7306032010387407	
i 1	148.5034693877551	0.2525	72	102	7	5	7	0	0	-1	0	0	0	6.029069243094779	
i 1	148.5038775510204	3.535	66	600	5	12	16	6	0	0	6	0	0	4.5596261346029054	
i 1	148.50469387755103	1.5150000000000001	69	102	7	5	2	0	0	0	0	0	0	6.029069243094779	
i 1	148.50632653061226	2.2725	72	916	3	1	7	0	0	-1	0	0	0	12.0	
i 1	148.50632653061226	0.2525	69	916	6	5	6	0	0	-1	0	0	0	6.029069243094779	
i 1	148.50673469387755	2.525	61	916	5	15	11	9	0	1	9	0	0	4.145114667820823	
i 1	148.5087755102041	1.5150000000000001	66	600	3	27	3	9	0	0	9	0	0	2.019395203020639	
i 1	148.5087755102041	1.5150000000000001	61	600	3	27	7	9	0	0	9	0	0	2.019395203020639	
i 1	148.50918367346938	1.5150000000000001	61	916	4	16	1	9	0	0	9	0	0	4.5596261346029054	
i 1	148.7465306122449	0.2525	72	600	3	5	13	1	0	0	1	0	0	6.029069243094779	
i 1	148.74693877551022	2.02	72	916	4	24	13	1	0	-1	1	0	0	13.0	
i 1	148.99408163265306	1.01	66	916	4	26	14	6	0	1	6	0	0	1.6794744170929128	
i 1	149.00020408163266	1.01	72	916	6	5	2	1	0	0	1	0	0	6.029069243094779	
i 1	149.00142857142856	2.02	61	102	6	13	6	6	0	1	6	0	0	3.7306032010387407	
i 1	149.01	3.0300000000000002	61	916	4	16	14	6	0	1	6	0	0	4.5596261346029054	
i 1	149.2526530612245	0.2525	69	916	6	5	5	0	0	-1	0	0	0	6.029069243094779	
i 1	149.25306122448978	0.2525	72	102	7	5	12	0	0	-1	0	0	0	6.029069243094779	
i 1	149.49163265306123	0.2525	69	916	4	1	16	1	0	-1	1	0	0	12.0	
i 1	149.49244897959184	0.505	69	916	6	5	10	0	0	-1	0	0	0	6.029069243094779	
i 1	149.50795918367348	3.0300000000000002	69	600	3	1	8	1	0	0	1	0	0	12.0	
i 1	149.74857142857144	0.2525	72	600	3	5	16	1	0	0	1	0	0	6.029069243094779	
i 1	149.75469387755103	2.7775	72	102	6	1	1	0	0	-1	0	0	0	12.0	
i 1	149.99448979591835	2.02	66	600	3	27	6	9	0	0	9	0	0	1.9880032053172232	
i 1	149.9961224489796	2.02	66	916	5	15	4	6	0	1	6	0	0	4.145114667820823	
i 1	149.9961224489796	1.01	61	600	3	27	10	9	0	0	9	0	0	1.9880032053172232	
i 1	149.99816326530612	1.7675	69	916	6	5	16	0	0	-1	0	0	0	7.664266976207336	
i 1	149.99897959183673	1.01	72	600	3	5	10	1	0	0	1	0	0	7.664266976207336	
i 1	150.00142857142856	3.0300000000000002	61	916	4	16	8	9	0	0	9	0	0	4.5596261346029054	
i 1	150.00428571428571	0.2525	69	102	7	5	6	0	0	0	0	0	0	7.664266976207336	
i 1	150.00551020408165	0.2525	72	916	6	5	1	1	0	0	1	0	0	7.664266976207336	
i 1	150.00673469387755	1.01	66	916	4	26	14	6	0	1	6	0	0	1.6480824193894974	
i 1	150.25632653061226	0.7575000000000001	72	916	6	5	2	0	0	-1	0	0	0	7.664266976207336	
i 1	150.49857142857144	2.525	69	916	6	5	12	0	0	-1	0	0	0	7.664266976207336	
i 1	150.75836734693877	0.2525	72	600	3	24	15	1	0	0	1	0	0	13.0	
i 1	150.99163265306123	2.02	61	916	5	15	10	9	0	1	9	0	0	4.145114667820823	
i 1	150.9961224489796	4.545	72	916	5	5	5	0	0	-1	0	0	0	7.664266976207336	
i 1	151.00020408163266	2.02	61	600	4	12	5	9	0	0	9	0	0	4.5596261346029054	
i 1	151.00224489795917	2.02	61	600	3	27	11	9	0	0	9	0	0	1.9880032053172232	
i 1	151.00673469387755	0.7575000000000001	72	600	6	5	7	1	0	0	1	0	0	7.664266976207336	
i 1	151.00755102040816	2.2725	72	102	7	5	1	0	0	-1	0	0	0	7.664266976207336	
i 1	151.0095918367347	0.505	72	916	3	1	13	0	0	-1	0	0	0	12.0	
i 1	151.25469387755103	0.505	72	600	3	24	4	1	0	0	1	0	0	13.0	
i 1	151.4965306122449	1.5150000000000001	72	600	6	5	16	1	0	0	1	0	0	7.664266976207336	
i 1	151.7587755102041	1.2625	72	102	6	1	10	0	0	-1	0	0	0	12.0	
i 1	151.7595918367347	1.2625	69	916	3	1	14	0	0	-1	0	0	0	12.0	
i 1	151.99244897959184	1.01	69	916	5	1	13	1	0	-1	1	0	0	12.0	
i 1	151.9965306122449	1.01	66	600	4	12	7	6	0	0	6	0	0	4.5596261346029054	
i 1	152.00306122448978	2.02	61	916	4	16	5	6	0	1	6	0	0	4.5596261346029054	
i 1	152.00469387755103	1.01	72	600	3	24	3	1	0	0	1	0	0	13.0	
i 1	152.5038775510204	0.505	72	916	4	24	16	1	0	-1	1	0	0	13.0	
i 1	152.7461224489796	0.2525	69	102	7	5	7	0	0	0	0	0	0	7.664266976207336	
i 1	152.99081632653062	1.7675	72	102	3	24	7	1	0	-1	1	0	0	13.0	
i 1	152.99081632653062	0.2525	69	102	5	5	3	1	0	0	1	0	0	7.664266976207336	
i 1	152.9973469387755	0.505	72	418	6	5	7	0	0	-1	0	0	0	7.664266976207336	
i 1	152.99775510204083	1.7675	69	102	6	5	5	0	0	0	0	0	0	7.664266976207336	
i 1	153.00061224489795	2.7775	69	916	4	1	12	0	0	-1	0	0	0	12.0	
i 1	153.00183673469388	2.02	61	916	4	16	5	9	0	0	9	0	0	4.5596261346029054	
i 1	153.0026530612245	1.01	61	102	4	12	13	9	0	0	9	0	0	4.5596261346029054	
i 1	153.0034693877551	0.2525	69	418	5	1	10	0	0	-1	0	0	0	12.0	
i 1	153.00428571428571	2.02	61	102	4	12	2	9	0	1	9	0	0	4.5596261346029054	
i 1	153.00836734693877	0.505	72	102	7	1	8	0	0	-1	0	0	0	12.0	
i 1	153.0087755102041	1.5150000000000001	72	418	4	24	15	0	0	-1	0	0	0	13.0	
i 1	153.24081632653062	1.7675	72	418	6	5	7	1	0	0	1	0	0	7.664266976207336	
i 1	153.49775510204083	0.505	72	102	6	1	1	0	0	-1	0	0	0	12.0	
i 1	153.7404081632653	1.5150000000000001	69	102	5	5	13	1	0	0	1	0	0	7.664266976207336	
i 1	153.9912244897959	1.2625	61	102	5	12	4	9	0	0	9	0	0	4.5596261346029054	
i 1	153.99448979591835	1.7675	72	102	7	1	9	0	0	-1	0	0	0	12.0	
i 1	154.50224489795917	0.7575000000000001	69	102	4	1	6	1	0	0	1	0	0	12.0	
i 1	154.74367346938774	0.2525	72	916	5	5	8	1	0	0	1	0	0	7.664266976207336	
i 1	154.7473469387755	0.2525	72	418	4	24	16	0	0	-1	0	0	0	13.0	
i 1	154.99	2.02	72	916	4	1	7	0	0	-1	0	0	0	12.0	
i 1	154.99408163265306	2.7775	72	102	7	1	4	0	0	-1	0	0	0	12.0	
i 1	154.99489795918367	0.2525	61	102	5	12	1	9	0	1	9	0	0	4.5596261346029054	
i 1	155.00224489795917	1.5150000000000001	72	418	5	5	6	1	0	0	1	0	0	7.664266976207336	
i 1	155.0038775510204	0.2525	72	418	6	5	6	0	0	-1	0	0	0	7.664266976207336	
i 1	155.00551020408165	1.5150000000000001	69	418	6	1	6	0	0	-1	0	0	0	12.0	
i 1	155.24857142857144	0.2525	72	102	6	5	1	0	0	-1	0	0	0	7.664266976207336	
i 1	155.24938775510205	1.7675	61	214	5	12	8	6	0	1	6	0	0	4.5596261346029054	
i 1	155.25224489795917	0.7575000000000001	66	214	5	12	7	6	0	1	6	0	0	4.5596261346029054	
i 1	155.25469387755103	1.2625	72	214	4	1	9	1	0	0	1	0	0	12.0	
i 1	155.25673469387755	1.2625	69	214	5	5	5	1	0	0	1	0	0	7.664266976207336	
i 1	155.49816326530612	2.7775	69	214	5	5	4	1	0	-1	1	0	0	7.664266976207336	
i 1	155.50142857142856	0.505	72	418	6	5	4	0	0	-1	0	0	0	7.664266976207336	
i 1	155.99693877551022	2.7775	72	418	4	24	9	0	0	-1	0	0	0	13.0	
i 1	156.00551020408165	3.0300000000000002	72	418	5	5	12	0	0	-1	0	0	0	7.664266976207336	
i 1	156.24448979591835	1.5150000000000001	72	102	6	5	10	0	0	-1	0	0	0	7.664266976207336	
i 1	156.25142857142856	1.2625	72	916	5	5	10	1	0	0	1	0	0	7.664266976207336	
i 1	156.50061224489795	1.7675	72	214	4	24	13	1	0	0	1	0	0	13.0	
i 1	156.75795918367348	1.5150000000000001	69	102	6	5	5	0	0	0	0	0	0	7.664266976207336	
i 1	157.0095918367347	0.7575000000000001	72	916	6	1	5	0	0	-1	0	0	0	12.0	
i 1	157.74163265306123	0.505	72	214	4	1	4	1	0	0	1	0	0	12.0	
i 1	157.74408163265306	0.2525	72	916	5	5	14	1	0	0	1	0	0	7.664266976207336	
i 1	157.74979591836734	0.505	72	102	7	1	8	0	0	-1	0	0	0	12.0	
i 1	157.99816326530612	0.2525	72	102	7	1	8	0	0	-1	0	0	0	12.0	
i 1	158.00061224489795	2.02	69	418	6	1	10	0	0	-1	0	0	0	12.0	
i 1	158.0034693877551	4.04	72	916	4	5	5	1	0	0	1	0	0	7.664266976207336	
i 1	158.00428571428571	1.7675	69	916	6	1	10	0	0	-1	0	0	0	12.0	
i 1	158.2404081632653	1.5150000000000001	69	1120	6	1	15	1	0	-1	1	0	0	12.0	
i 1	158.24163265306123	1.5150000000000001	72	1120	5	5	14	0	0	0	0	0	0	7.664266976207336	
i 1	158.2465306122449	0.7575000000000001	72	1120	6	1	13	1	0	0	1	0	0	12.0	
i 1	158.24693877551022	0.505	69	418	5	5	4	0	0	-1	0	0	0	7.664266976207336	
i 1	158.2526530612245	1.7675	72	418	4	24	7	0	0	-1	0	0	0	13.0	
i 1	158.25591836734694	0.7575000000000001	69	418	4	1	1	0	0	-1	0	0	0	12.0	
i 1	158.7412244897959	0.2525	69	418	5	5	5	0	0	-1	0	0	0	7.664266976207336	
i 1	158.99489795918367	1.01	69	418	5	5	7	0	0	-1	0	0	0	7.664266976207336	
i 1	158.99530612244897	1.2625	72	916	6	1	15	0	0	-1	0	0	0	12.0	
i 1	158.99857142857144	1.2625	72	418	5	5	1	1	0	0	1	0	0	7.664266976207336	
i 1	159.00428571428571	2.525	72	418	4	24	11	0	0	-1	0	0	0	13.0	
i 1	159.24693877551022	3.2825	72	418	5	5	4	0	0	-1	0	0	0	7.664266976207336	
i 1	159.74081632653062	0.2525	69	916	5	5	4	0	0	-1	0	0	0	7.664266976207336	
i 1	159.99244897959184	2.2725	69	418	4	5	7	0	0	-1	0	0	0	7.664266976207336	
i 1	159.99571428571429	2.7775	72	418	4	24	3	0	0	-1	0	0	0	13.0	
i 1	159.9965306122449	1.01	69	916	6	1	5	1	0	-1	1	0	0	12.0	
i 1	160.00714285714287	1.5150000000000001	72	916	5	5	2	0	0	0	0	0	0	7.664266976207336	
i 1	160.25183673469388	0.2525	72	916	4	1	6	1	0	-1	1	0	0	12.0	
i 1	160.50632653061226	1.5150000000000001	69	916	6	1	9	0	0	-1	0	0	0	12.0	
i 1	160.9912244897959	1.01	69	916	4	1	13	1	0	-1	1	0	0	12.0	
i 1	161.24489795918367	0.7575000000000001	72	916	4	5	12	0	0	-1	0	0	0	7.664266976207336	
i 1	161.24775510204083	0.7575000000000001	69	916	6	5	7	0	0	-1	0	0	0	7.664266976207336	
i 1	161.49857142857144	0.505	69	418	6	1	16	0	0	-1	0	0	0	12.0	
i 1	161.74244897959184	1.2625	72	418	4	24	16	0	0	-1	0	0	0	13.0	
i 1	161.75102040816327	0.2525	72	916	6	1	4	1	0	-1	1	0	0	12.0	
i 1	161.75102040816327	0.2525	72	916	6	1	15	0	0	-1	0	0	0	12.0	
i 1	161.9904081632653	0.7575000000000001	69	418	4	1	2	0	0	-1	0	0	0	12.0	
i 1	161.99285714285713	0.505	69	1120	6	1	16	1	0	0	1	0	0	12.0	
i 1	161.99408163265306	2.2725	69	1120	6	1	6	0	0	-1	0	0	0	12.0	
i 1	161.99816326530612	1.5150000000000001	69	804	4	5	11	1	0	0	1	0	0	7.664266976207336	
i 1	161.99938775510205	0.505	72	804	4	5	16	0	0	0	0	0	0	7.664266976207336	
i 1	162.00142857142856	2.2725	72	804	6	1	7	1	0	-1	1	0	0	12.0	
i 1	162.00142857142856	1.01	72	1120	6	5	16	0	0	0	0	0	0	7.664266976207336	
i 1	162.0038775510204	2.02	69	804	6	1	6	1	0	-1	1	0	0	12.0	
i 1	162.4904081632653	1.7675	69	418	4	5	11	0	0	-1	0	0	0	7.664266976207336	
i 1	162.49816326530612	0.505	72	418	5	5	13	1	0	0	1	0	0	7.664266976207336	
i 1	162.99	1.2625	72	418	6	5	15	1	0	0	1	0	0	7.664266976207336	
i 1	163.00755102040816	1.01	72	418	4	24	5	0	0	-1	0	0	0	13.0	
i 1	163.00795918367348	0.505	72	1120	6	5	11	0	0	0	0	0	0	7.664266976207336	
i 1	163.25142857142856	0.7575000000000001	69	1120	6	5	16	0	0	0	0	0	0	7.664266976207336	
i 1	163.25183673469388	1.7675	69	418	4	5	10	0	0	-1	0	0	0	7.664266976207336	
i 1	163.9973469387755	1.01	69	1120	6	1	3	1	0	0	1	0	0	12.0	
i 1	163.99775510204083	1.01	72	418	4	24	2	0	0	-1	0	0	0	13.0	
i 1	164.00102040816327	1.01	69	1120	6	5	11	0	0	0	0	0	0	7.664266976207336	
i 1	164.0026530612245	1.01	69	804	3	1	2	1	0	-1	1	0	0	12.0	
i 1	164.00591836734694	1.01	72	804	4	5	16	0	0	0	0	0	0	7.664266976207336	
i 1	164.00632653061226	2.02	69	418	6	1	4	0	0	-1	0	0	0	12.0	
i 1	164.00918367346938	1.01	72	418	6	5	11	0	0	-1	0	0	0	7.664266976207336	
i 1	164.49448979591835	0.505	69	418	4	5	12	0	0	-1	0	0	0	7.664266976207336	
i 1	164.49489795918367	0.505	69	1120	6	1	6	0	0	-1	0	0	0	12.0	
i 1	164.74408163265306	0.2525	69	418	6	1	3	0	0	-1	0	0	0	12.0	
i 1	164.9912244897959	1.5150000000000001	61	186	4	7	15	6	0	1	6	0	0	9.135917215400381	
i 1	164.99163265306123	1.5150000000000001	72	186	7	1	2	1	0	0	1	0	0	12.0	
i 1	164.99489795918367	1.5150000000000001	69	418	4	5	12	0	0	-1	0	0	0	9.97928484493554	
i 1	164.99775510204083	0.505	69	1119	6	1	12	0	0	0	0	0	0	12.0	
i 1	164.99857142857144	1.5150000000000001	72	804	5	5	10	0	0	0	0	0	0	9.97928484493554	
i 1	165.00183673469388	1.5150000000000001	66	1119	4	14	15	6	0	0	6	0	0	14.0	
i 1	165.00224489795917	1.5150000000000001	66	1119	4	14	7	9	0	0	9	0	0	14.0	
i 1	165.00591836734694	0.505	69	804	4	5	8	1	0	0	1	0	0	9.97928484493554	
i 1	165.00795918367348	0.7575000000000001	69	804	6	1	6	1	0	-1	1	0	0	12.0	
i 1	165.00795918367348	1.01	72	186	6	5	10	0	0	0	0	0	0	9.97928484493554	
i 1	165.0087755102041	0.7575000000000001	72	1119	6	1	4	0	0	-1	0	0	0	12.0	
i 1	165.4961224489796	1.01	72	418	4	24	5	0	0	-1	0	0	0	13.0	
i 1	165.49693877551022	1.01	72	186	5	24	16	0	0	-1	0	0	0	13.0	
i 1	165.5087755102041	1.01	69	1119	6	5	8	1	0	0	1	0	0	9.97928484493554	
i 1	165.99163265306123	0.505	69	804	6	1	9	1	0	-1	1	0	0	12.0	
i 1	166.00061224489795	0.505	72	186	7	5	1	0	0	0	0	0	0	9.97928484493554	
i 1	166.00428571428571	0.505	69	418	3	1	11	0	0	-1	0	0	0	12.0	
i 1	166.00428571428571	0.505	72	186	7	5	7	1	0	-1	1	0	0	9.97928484493554	
i 1	166.49326530612245	1.5150000000000001	69	82	7	1	12	1	0	-1	1	0	0	12.0	
i 1	166.49367346938774	4.545	61	896	4	14	11	9	0	0	9	0	0	14.0	
i 1	166.49448979591835	2.02	72	82	7	5	6	0	0	0	0	0	0	9.97928484493554	
i 1	166.4961224489796	1.2625	72	398	6	1	10	1	0	-1	1	0	0	12.0	
i 1	166.49938775510205	1.5150000000000001	69	896	3	5	15	1	0	0	1	0	0	9.97928484493554	
i 1	166.50020408163266	0.505	69	896	4	24	12	0	0	-1	0	0	0	13.0	
i 1	166.50102040816327	6.565	66	82	4	7	16	6	0	1	6	0	0	9.135917215400381	
i 1	166.50428571428571	3.535	61	896	4	14	15	6	0	1	6	0	0	14.0	
i 1	166.50469387755103	0.7575000000000001	69	896	6	5	9	1	0	0	1	0	0	9.97928484493554	
i 1	166.50673469387755	1.2625	69	82	5	24	16	1	0	-1	1	0	0	13.0	
i 1	166.5095918367347	0.505	69	398	5	5	14	0	0	-1	0	0	0	9.97928484493554	
i 1	166.99163265306123	0.505	72	398	5	5	14	0	0	0	0	0	0	9.97928484493554	
i 1	166.99530612244897	1.01	69	896	2	24	8	0	0	-1	0	0	0	13.0	
i 1	167.25795918367348	3.2825	69	82	7	5	11	0	0	-1	0	0	0	9.97928484493554	
i 1	167.4973469387755	2.7775	69	398	6	5	12	0	0	-1	0	0	0	9.97928484493554	
i 1	167.50183673469388	1.2625	69	896	5	1	13	1	0	0	1	0	0	12.0	
i 1	167.50591836734694	1.2625	72	896	5	1	5	1	0	-1	1	0	0	12.0	
i 1	167.7412244897959	1.7675	72	398	6	1	9	0	0	-1	0	0	0	12.0	
i 1	167.75510204081633	1.7675	69	896	5	1	13	0	0	0	0	0	0	12.0	
i 1	168.0026530612245	2.2725	69	82	5	1	8	1	0	-1	1	0	0	12.0	
i 1	168.00469387755103	2.02	69	896	6	5	9	0	0	-1	0	0	0	9.97928484493554	
i 1	168.00632653061226	0.505	69	896	4	5	6	1	0	0	1	0	0	9.97928484493554	
i 1	168.00673469387755	2.2725	69	896	4	24	14	0	0	-1	0	0	0	13.0	
i 1	168.00795918367348	1.01	72	896	4	5	12	1	0	-1	1	0	0	9.97928484493554	
i 1	168.50306122448978	0.505	69	82	5	24	5	1	0	-1	1	0	0	13.0	
i 1	168.99775510204083	1.01	72	896	6	5	10	1	0	-1	1	0	0	9.97928484493554	
i 1	169.00428571428571	3.0300000000000002	69	82	5	24	3	1	0	-1	1	0	0	13.0	
i 1	169.24285714285713	0.7575000000000001	72	398	6	1	5	1	0	-1	1	0	0	12.0	
i 1	169.2465306122449	0.7575000000000001	69	896	6	5	13	1	0	0	1	0	0	9.97928484493554	
i 1	169.24693877551022	4.04	72	398	6	5	3	0	0	0	0	0	0	9.97928484493554	
i 1	169.74244897959184	1.2625	72	398	6	1	3	0	0	-1	0	0	0	12.0	
i 1	169.7595918367347	1.2625	69	896	5	1	12	0	0	0	0	0	0	12.0	
i 1	169.9912244897959	2.02	72	398	4	1	2	1	0	-1	1	0	0	12.0	
i 1	169.99326530612245	3.0300000000000002	69	896	5	5	8	1	0	0	1	0	0	9.97928484493554	
i 1	170.00102040816327	10.1	61	896	3	14	12	6	0	1	6	0	0	14.0	
i 1	170.25306122448978	0.2525	69	896	6	5	8	1	0	0	1	0	0	9.97928484493554	
i 1	170.49448979591835	0.2525	69	398	6	5	11	0	0	-1	0	0	0	9.97928484493554	
i 1	170.50469387755103	1.01	72	896	6	5	4	1	0	-1	1	0	0	9.97928484493554	
i 1	170.99	1.7675	69	896	4	24	12	0	0	-1	0	0	0	13.0	
i 1	170.99693877551022	1.7675	69	82	5	1	11	1	0	-1	1	0	0	12.0	
i 1	170.99897959183673	9.09	61	896	3	14	6	9	0	0	9	0	0	14.0	
i 1	171.00020408163266	2.02	69	896	5	1	3	1	0	0	1	0	0	12.0	
i 1	171.49163265306123	2.525	69	896	6	5	4	1	0	0	1	0	0	9.97928484493554	
i 1	171.75183673469388	0.2525	72	896	5	1	2	1	0	-1	1	0	0	12.0	
i 1	171.75306122448978	0.2525	72	82	7	5	16	0	0	0	0	0	0	9.97928484493554	
i 1	171.99489795918367	1.5150000000000001	72	896	3	1	8	1	0	-1	1	0	0	12.0	
i 1	171.9961224489796	2.02	72	82	5	5	12	0	0	0	0	0	0	9.97928484493554	
i 1	172.50224489795917	1.5150000000000001	69	896	6	1	9	0	0	0	0	0	0	12.0	
i 1	172.50836734693877	1.5150000000000001	72	398	4	1	5	0	0	-1	0	0	0	12.0	
i 1	172.99244897959184	0.505	69	896	6	1	15	1	0	0	1	0	0	12.0	
i 1	172.99244897959184	7.07	66	82	4	7	13	6	0	1	6	0	0	9.135917215400381	
i 1	172.99693877551022	1.01	69	82	5	1	1	1	0	-1	1	0	0	12.0	
i 1	172.99693877551022	1.01	69	82	5	5	12	0	0	-1	0	0	0	9.97928484493554	
i 1	173.00306122448978	1.01	69	896	3	24	10	0	0	-1	0	0	0	13.0	
i 1	173.24367346938774	0.7575000000000001	69	82	5	24	14	1	0	-1	1	0	0	13.0	
i 1	173.2465306122449	0.7575000000000001	69	398	6	5	6	0	0	-1	0	0	0	9.97928484493554	
i 1	173.25020408163266	0.7575000000000001	72	398	4	1	16	1	0	-1	1	0	0	12.0	
i 1	173.25551020408165	0.7575000000000001	69	896	5	5	7	0	0	-1	0	0	0	9.97928484493554	
i 1	173.49	0.505	72	896	6	5	9	1	0	-1	1	0	0	9.97928484493554	
i 1	174.99857142857144	5.05	66	896	5	14	13	6	0	0	6	0	0	4.943513964103633	
i 1	176.00591836734694	4.04	66	896	5	13	16	6	0	1	6	0	0	3.6999795637573856	
i 1	177.00755102040816	3.0300000000000002	66	82	6	15	10	9	0	0	9	0	0	4.114491030539468	
i 1	178.0038775510204	2.02	66	82	6	15	2	9	0	1	9	0	0	4.114491030539468	
i 1	178.9973469387755	1.01	61	398	4	16	16	9	0	0	9	0	0	4.52900249732155	
t0 60
</CsScore>
</CsoundSynthesizer>

