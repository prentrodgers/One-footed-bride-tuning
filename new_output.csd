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
; print(p4, iVel, p7, iSampleType, iVoicet, iVoice) 
; table f1 has the start location of the sample tables control functions 
 iSampWaveTable table iVoice,1 ; find the location of the sample wave tables base on input p7 
; print(iSampWaveTable) 
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
 ; Still have yet to implement the 3rd glissando. 
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
f307 0 256 -7 .5 256 .5 ; constant 0.5 multiplier — drops playback frequency one octave (used by bass_part octave-0 rescue)
f308 0 256 -7 .25 256 .25 ; constant 0.25 multiplier — drops playback frequency two octaves (used by bass_part octave-0 rescue)
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

f5000.0 0.0 256.0 -6.0 1.0 128.0 0.9994225 128.0 0.998845 
;Inst	Sta	Hold	Vel	Ton	Oct	Voi	Ste	En1	Gls	Ups	Ren	2gl	3gl	Vol
i 1	0.00038775510204081595	1.01	63	918	3	16	10	16	0	1	16	0	0	14.0	0	
i 1	0.0003877551020408168	0.505	63	602	4	25	1	16	0	2	16	0	0	13.971335930312387	0	
i 1	0.0003877551020408168	1.01	61	918	3	26	1	1	0	2	1	0	0	13.971335930312387	0	
i 1	0.0003877551020408168	1.01	63	918	3	26	14	16	0	2	16	0	0	13.971335930312387	0	
i 1	0.0011632653061224487	1.01	63	216	5	13	3	16	0	1	16	0	0	13.882378305840126	0	
i 1	0.0016802721088435384	1.01	63	216	5	25	15	16	0	1	16	0	0	13.971335930312387	0	
i 1	0.003748299319727892	1.01	61	918	3	16	13	16	0	1	16	0	0	14.0	0	
i 1	0.004006802721088436	1.01	63	216	5	25	11	1	0	2	1	0	0	13.971335930312387	0	
i 1	0.00426530612244898	0.505	63	602	4	15	6	16	0	1	16	0	0	14.0	0	
i 1	0.00426530612244898	0.505	63	216	3	12	1	1	0	2	1	0	0	14.0	0	
i 1	0.004523809523809524	1.01	63	216	5	14	4	1	0	2	1	0	0	14.0	0	
i 1	0.0052993197278911565	0.505	63	602	4	25	14	1	0	1	1	0	0	13.971335930312387	0	
i 1	0.005299319727891157	0.505	63	602	4	15	14	16	0	2	16	0	0	14.0	0	
i 1	0.005299319727891157	0.505	63	216	3	27	1	16	0	2	16	0	0	13.971335930312387	0	
i 1	0.005816326530612244	0.505	63	216	3	12	3	1	0	1	1	0	0	14.0	0	
i 1	0.006333333333333333	0.505	61	216	3	27	13	16	0	2	16	0	0	13.971335930312387	0	
i 1	0.4939251700680272	0.505	63	714	4	15	15	1	0	1	1	0	0	14.0	2	
i 1	0.49625170068027213	0.505	61	367	3	27	15	1	0	1	1	0	0	13.971335930312387	2	
i 1	0.49651020408163266	0.505	63	714	4	25	12	16	0	1	16	0	0	13.971335930312387	2	
i 1	0.4967687074829932	0.505	61	714	4	25	15	1	0	1	1	0	0	13.971335930312387	2	
i 1	0.4990952380952381	0.505	61	367	3	12	9	16	0	2	16	0	0	14.0	2	
i 1	0.4996122448979592	0.505	61	367	3	12	13	16	0	2	16	0	0	14.0	2	
i 1	0.5006462585034014	0.505	61	714	4	15	11	1	0	2	1	0	0	14.0	2	
i 1	0.5024557823129252	0.505	61	367	3	27	13	1	0	1	1	0	0	13.971335930312387	2	
i 1	0.9944421768707483	1.01	61	602	3	12	5	16	0	2	16	0	0	14.0	4	
i 1	0.9947006802721089	1.01	61	918	4	25	5	16	0	1	16	0	0	13.971335930312387	4	
i 1	0.9949591836734694	4.04	61	216	4	26	6	1	0	2	1	0	0	13.971335930312387	4	
i 1	0.9970272108843538	4.04	61	216	4	16	7	1	0	1	1	0	0	14.0	4	
i 1	0.9983197278911564	1.01	61	602	3	27	1	16	0	1	16	0	0	13.971335930312387	4	
i 1	0.9998707482993198	1.01	61	918	4	25	1	1	0	1	1	0	0	13.971335930312387	4	
i 1	1.0003877551020408	1.01	63	918	4	13	3	1	0	1	1	0	0	13.882378305840126	4	
i 1	1.0016802721088436	1.01	63	918	4	15	6	1	0	1	1	0	0	14.0	4	
i 1	1.0029727891156464	1.01	63	602	3	12	9	1	0	1	1	0	0	14.0	4	
i 1	1.0045238095238096	1.01	61	602	3	27	9	1	0	1	1	0	0	13.971335930312387	4	
i 1	1.00478231292517	1.01	61	918	4	25	13	1	0	2	1	0	0	13.971335930312387	4	
i 1	1.0052993197278912	1.01	61	918	4	14	2	16	0	1	16	0	0	14.0	4	
i 1	1.0052993197278912	1.01	61	918	4	25	7	16	0	2	16	0	0	13.971335930312387	4	
i 1	1.0055578231292517	4.04	63	216	4	16	4	16	0	2	16	0	0	14.0	4	
i 1	1.0055578231292517	4.04	61	216	4	26	6	16	0	2	16	0	0	13.971335930312387	4	
i 1	1.0060748299319728	1.01	61	918	4	15	12	16	0	1	16	0	0	14.0	4	
i 1	1.9936666666666667	1.01	61	714	4	15	4	1	0	2	1	0	0	14.0	8	
i 1	1.995734693877551	1.01	61	714	4	25	10	16	0	1	16	0	0	13.971335930312387	8	
i 1	1.9978027210884355	1.01	61	714	3	12	10	16	0	2	16	0	0	14.0	8	
i 1	1.998061224489796	1.01	61	714	3	12	7	1	0	2	1	0	0	14.0	8	
i 1	1.9993537414965987	0.505	61	1100	4	25	10	1	0	2	1	0	0	13.971335930312387	8	
i 1	1.9996122448979592	1.01	63	714	3	27	5	1	0	1	1	0	0	13.971335930312387	8	
i 1	1.9998707482993197	0.505	61	1100	4	25	15	1	0	1	1	0	0	13.971335930312387	8	
i 1	2.0016802721088434	1.01	63	714	3	27	13	16	0	1	16	0	0	13.971335930312387	8	
i 1	2.005299319727891	1.01	63	714	4	15	8	1	0	1	1	0	0	14.0	8	
i 1	2.005299319727891	1.01	63	714	4	25	10	1	0	2	1	0	0	13.971335930312387	8	
i 1	2.0063333333333335	0.505	61	1100	4	14	9	16	0	2	16	0	0	14.0	8	
i 1	2.0063333333333335	0.505	61	1100	4	13	7	1	0	2	1	0	0	13.882378305840126	8	
i 1	2.4936666666666665	0.505	61	96	5	13	9	1	0	1	1	0	0	13.882378305840126	10	
i 1	2.493925170068027	0.505	61	96	5	14	10	1	0	2	1	0	0	14.0	10	
i 1	2.494442176870748	0.505	61	96	5	25	10	1	0	2	1	0	0	13.971335930312387	10	
i 1	2.494442176870748	0.505	61	96	5	25	12	16	0	2	16	0	0	13.971335930312387	10	
i 1	2.9952176870748297	0.505	61	216	5	25	9	1	0	1	1	0	0	13.971335930312387	12	
i 1	2.9972857142857143	1.01	63	918	4	25	8	1	0	2	1	0	0	13.971335930312387	12	
i 1	2.998578231292517	1.5150000000000001	61	602	3	27	6	16	0	2	16	0	0	13.971335930312387	12	
i 1	2.9990952380952383	1.5150000000000001	61	602	3	12	12	1	0	1	1	0	0	14.0	12	
i 1	2.999612244897959	0.505	61	216	5	14	3	16	0	2	16	0	0	14.0	12	
i 1	2.999612244897959	1.01	61	918	4	15	11	1	0	2	1	0	0	14.0	12	
i 1	2.999612244897959	1.5150000000000001	63	602	3	27	16	16	0	1	16	0	0	13.971335930312387	12	
i 1	3.0011632653061224	0.505	63	216	5	25	1	16	0	1	16	0	0	13.971335930312387	12	
i 1	3.0034897959183673	1.5150000000000001	63	602	3	12	14	1	0	1	1	0	0	14.0	12	
i 1	3.003748299319728	1.01	63	918	4	25	2	1	0	1	1	0	0	13.971335930312387	12	
i 1	3.004265306122449	0.505	61	216	5	13	7	16	0	1	16	0	0	13.882378305840126	12	
i 1	3.0050408163265305	1.01	61	918	4	15	6	16	0	2	16	0	0	14.0	12	
i 1	3.494700680272109	0.505	61	420	5	25	5	1	0	2	1	0	0	13.971335930312387	14	
i 1	3.4949591836734695	0.505	61	420	5	14	11	16	0	2	16	0	0	14.0	14	
i 1	3.5045238095238096	0.505	63	420	5	25	12	16	0	1	16	0	0	13.971335930312387	14	
i 1	3.505299319727891	0.505	61	420	5	13	5	1	0	2	1	0	0	13.882378305840126	14	
i 1	3.9949591836734695	0.505	63	962	4	15	15	1	0	2	1	0	0	14.0	16	
i 1	3.9965102040816327	1.01	61	602	5	25	8	16	0	1	16	0	0	13.971335930312387	16	
i 1	3.997544217687075	1.01	61	602	5	14	15	1	0	1	1	0	0	14.0	16	
i 1	3.9978027210884353	0.505	61	962	4	15	4	16	0	2	16	0	0	14.0	16	
i 1	3.9983197278911566	0.505	63	962	4	25	3	16	0	2	16	0	0	13.971335930312387	16	
i 1	4.00012925170068	0.505	63	962	4	25	10	16	0	1	16	0	0	13.971335930312387	16	
i 1	4.000387755102041	1.01	61	602	5	25	7	16	0	1	16	0	0	13.971335930312387	16	
i 1	4.005299319727891	1.01	63	602	5	13	4	1	0	2	1	0	0	13.882378305840126	16	
i 1	4.493666666666667	0.505	63	834	3	12	13	1	0	2	1	0	0	14.0	18	
i 1	4.494959183673469	0.505	61	834	3	12	7	16	0	1	16	0	0	14.0	18	
i 1	4.494959183673469	0.505	61	1100	4	25	15	1	0	1	1	0	0	13.971335930312387	18	
i 1	4.495734693877551	0.505	61	1100	4	15	14	16	0	1	16	0	0	14.0	18	
i 1	4.499095238095238	0.505	63	834	3	27	9	16	0	1	16	0	0	13.971335930312387	18	
i 1	4.501680272108843	0.505	63	834	3	27	9	1	0	2	1	0	0	13.971335930312387	18	
i 1	4.5019387755102045	0.505	61	1100	4	25	13	1	0	2	1	0	0	13.971335930312387	18	
i 1	4.502714285714286	0.505	61	1100	4	15	9	1	0	1	1	0	0	14.0	18	
i 1	4.9944421768707485	1.01	63	1016	3	27	15	16	0	1	16	0	0	13.971335930312387	20	
i 1	4.99547619047619	1.01	61	83	4	26	15	16	0	2	16	0	0	13.971335930312387	20	
i 1	4.995993197278912	1.01	63	83	4	16	8	1	0	2	1	0	0	14.0	20	
i 1	4.996510204081632	1.01	61	399	5	25	3	1	0	2	1	0	0	13.971335930312387	20	
i 1	4.997027210884354	1.01	63	83	5	15	16	16	0	1	16	0	0	14.0	20	
i 1	4.997027210884354	1.01	61	1016	3	12	14	16	0	1	16	0	0	14.0	20	
i 1	4.997027210884354	1.01	63	83	5	25	15	1	0	2	1	0	0	13.971335930312387	20	
i 1	4.997802721088435	1.01	61	1016	3	12	12	16	0	2	16	0	0	14.0	20	
i 1	4.999612244897959	1.01	63	83	4	26	15	16	0	1	16	0	0	13.971335930312387	20	
i 1	4.999612244897959	1.01	61	1016	3	27	12	1	0	2	1	0	0	13.971335930312387	20	
i 1	4.99987074829932	1.01	61	399	5	14	15	1	0	2	1	0	0	14.0	20	
i 1	5.00012925170068	1.01	63	83	4	16	7	1	0	1	1	0	0	14.0	20	
i 1	5.005299319727891	1.01	61	83	5	25	6	16	0	1	16	0	0	13.971335930312387	20	
i 1	5.0055578231292515	1.01	61	399	5	13	2	16	0	1	16	0	0	13.882378305840126	20	
i 1	5.0055578231292515	1.01	61	399	5	25	1	1	0	1	1	0	0	13.971335930312387	20	
i 1	5.005816326530613	1.01	61	83	5	15	5	16	0	1	16	0	0	14.0	20	
i 1	5.993925170068027	0.505	63	203	4	26	16	1	0	2	1	0	0	13.971335930312387	24	
i 1	5.994700680272109	1.01	61	589	4	15	10	1	0	2	1	0	0	14.0	24	
i 1	5.99547619047619	2.02	61	203	5	14	13	1	0	1	1	0	0	14.0	24	
i 1	5.995734693877551	1.01	61	589	4	15	13	1	0	1	1	0	0	14.0	24	
i 1	5.995734693877551	0.505	61	1087	3	27	8	1	0	2	1	0	0	13.971335930312387	24	
i 1	5.996510204081632	0.505	61	203	4	26	5	1	0	2	1	0	0	13.971335930312387	24	
i 1	5.998578231292517	1.01	63	589	4	25	4	16	0	2	16	0	0	13.971335930312387	24	
i 1	5.998836734693877	2.02	63	203	5	13	12	1	0	1	1	0	0	13.882378305840126	24	
i 1	5.998836734693877	1.01	63	589	4	25	2	16	0	2	16	0	0	13.971335930312387	24	
i 1	5.99987074829932	0.505	61	1087	3	12	14	1	0	2	1	0	0	14.0	24	
i 1	6.001421768707483	0.505	63	203	4	16	9	1	0	2	1	0	0	14.0	24	
i 1	6.002714285714286	2.02	61	203	5	25	15	1	0	2	1	0	0	13.971335930312387	24	
i 1	6.003748299319728	0.505	63	1087	3	12	12	16	0	2	16	0	0	14.0	24	
i 1	6.00478231292517	0.505	61	203	4	16	12	16	0	1	16	0	0	14.0	24	
i 1	6.005299319727891	2.02	61	203	5	25	14	16	0	1	16	0	0	13.971335930312387	24	
i 1	6.006074829931973	0.505	63	1087	3	27	1	1	0	1	1	0	0	13.971335930312387	24	
i 1	6.493666666666667	0.505	63	91	4	16	10	16	0	2	16	0	0	14.0	26	
i 1	6.4944421768707485	0.505	61	905	3	27	4	16	0	2	16	0	0	13.971335930312387	26	
i 1	6.496251700680272	0.505	61	91	4	26	10	16	0	1	16	0	0	13.971335930312387	26	
i 1	6.49987074829932	0.505	63	91	4	26	5	16	0	2	16	0	0	13.971335930312387	26	
i 1	6.503231292517007	0.505	61	905	3	27	12	1	0	1	1	0	0	13.971335930312387	26	
i 1	6.504006802721088	0.505	61	91	4	16	7	1	0	2	1	0	0	14.0	26	
i 1	6.506074829931973	0.505	61	905	3	12	8	16	0	2	16	0	0	14.0	26	
i 1	6.506074829931973	0.505	61	905	3	12	8	16	0	2	16	0	0	14.0	26	
i 1	6.993925170068027	1.01	63	1136	3	16	9	16	0	1	16	0	0	14.0	28	
i 1	6.993925170068027	1.01	61	820	3	27	14	1	0	1	1	0	0	13.971335930312387	28	
i 1	6.9944421768707485	1.01	63	1136	3	16	12	1	0	2	1	0	0	14.0	28	
i 1	6.9944421768707485	1.01	63	1136	3	26	5	1	0	1	1	0	0	13.971335930312387	28	
i 1	6.99521768707483	1.01	63	820	3	12	16	16	0	2	16	0	0	14.0	28	
i 1	6.995734693877551	1.01	63	820	3	27	13	16	0	2	16	0	0	13.971335930312387	28	
i 1	6.996510204081632	1.01	61	820	3	12	13	1	0	2	1	0	0	14.0	28	
i 1	6.998578231292517	2.02	63	434	4	15	16	16	0	2	16	0	0	14.0	28	
i 1	7.001163265306123	2.02	61	434	4	25	7	1	0	1	1	0	0	13.971335930312387	28	
i 1	7.001421768707483	1.01	63	1136	3	26	16	16	0	2	16	0	0	13.971335930312387	28	
i 1	7.002714285714286	2.02	63	434	4	15	6	1	0	2	1	0	0	14.0	28	
i 1	7.002714285714286	2.02	61	434	4	25	11	1	0	1	1	0	0	13.971335930312387	28	
i 1	7.993925170068027	3.0300000000000002	63	932	3	16	15	1	0	2	1	0	0	14.0	32	
i 1	7.994183673469387	3.0300000000000002	61	932	3	26	2	16	0	2	16	0	0	13.971335930312387	32	
i 1	7.9944421768707485	1.01	63	932	3	12	10	16	0	1	16	0	0	14.0	32	
i 1	7.9944421768707485	1.01	61	118	5	25	15	16	0	2	16	0	0	13.971335930312387	32	
i 1	7.994700680272109	3.0300000000000002	61	932	3	16	16	1	0	2	1	0	0	14.0	32	
i 1	7.994700680272109	1.01	63	118	5	25	11	1	0	2	1	0	0	13.971335930312387	32	
i 1	7.99547619047619	3.0300000000000002	63	932	3	26	16	1	0	2	1	0	0	13.971335930312387	32	
i 1	7.995993197278912	1.01	63	932	3	27	7	16	0	2	16	0	0	13.971335930312387	32	
i 1	8.001938775510204	1.01	63	932	3	12	3	1	0	2	1	0	0	14.0	32	
i 1	8.002197278911565	1.01	63	118	5	14	7	1	0	1	1	0	0	14.0	32	
i 1	8.003489795918368	1.01	63	932	3	27	9	1	0	2	1	0	0	13.971335930312387	32	
i 1	8.006333333333334	1.01	63	118	5	13	9	1	0	2	1	0	0	13.882378305840126	32	
i 1	8.993666666666666	2.02	61	616	4	25	16	16	0	1	16	0	0	13.971335930312387	36	
i 1	8.996768707482993	2.02	61	230	5	14	11	16	0	2	16	0	0	14.0	36	
i 1	8.997027210884355	2.02	61	230	3	12	15	16	0	2	16	0	0	14.0	36	
i 1	8.997285714285715	2.02	61	616	4	15	10	16	0	2	16	0	0	14.0	36	
i 1	8.999612244897959	2.02	61	616	4	15	6	16	0	2	16	0	0	14.0	36	
i 1	9.000129251700681	2.02	61	230	3	27	11	16	0	2	16	0	0	13.971335930312387	36	
i 1	9.000646258503401	2.02	63	230	3	27	12	1	0	2	1	0	0	13.971335930312387	36	
i 1	9.001163265306122	2.02	63	616	4	25	3	16	0	2	16	0	0	13.971335930312387	36	
i 1	9.002972789115645	2.02	63	230	5	13	13	16	0	1	16	0	0	13.882378305840126	36	
i 1	9.003489795918368	2.02	63	230	3	12	11	16	0	2	16	0	0	14.0	36	
i 1	9.005557823129251	2.02	61	230	5	25	6	1	0	1	1	0	0	13.971335930312387	36	
i 1	9.005557823129251	2.02	63	230	5	25	1	1	0	1	1	0	0	13.971335930312387	36	
i 1	10.993666666666666	1.01	61	230	4	12	11	16	0	2	16	0	0	14.0	44	
i 1	10.993666666666666	1.01	61	230	4	27	7	16	0	2	16	0	0	13.971335930312387	44	
i 1	10.994442176870749	1.01	61	616	5	25	5	1	0	2	1	0	0	13.971335930312387	44	
i 1	10.994700680272109	1.5150000000000001	63	932	4	15	6	1	0	1	1	0	0	14.0	44	
i 1	10.996510204081632	1.01	63	616	5	25	7	16	0	1	16	0	0	13.971335930312387	44	
i 1	10.996768707482993	1.01	61	230	4	16	2	1	0	2	1	0	0	14.0	44	
i 1	10.997027210884355	1.5150000000000001	63	932	4	25	11	1	0	2	1	0	0	13.971335930312387	44	
i 1	10.998061224489796	1.01	63	230	4	27	9	1	0	2	1	0	0	13.971335930312387	44	
i 1	10.999612244897959	1.01	63	616	5	14	1	1	0	2	1	0	0	14.0	44	
i 1	11.002714285714285	1.01	63	230	4	26	11	16	0	1	16	0	0	13.971335930312387	44	
i 1	11.002972789115645	1.01	61	230	4	16	10	1	0	1	1	0	0	14.0	44	
i 1	11.003489795918368	1.01	63	616	5	13	5	1	0	1	1	0	0	13.882378305840126	44	
i 1	11.003748299319728	1.5150000000000001	61	932	4	25	13	1	0	1	1	0	0	13.971335930312387	44	
i 1	11.005040816326531	1.5150000000000001	63	932	4	15	9	1	0	1	1	0	0	14.0	44	
i 1	11.005816326530612	1.01	63	230	4	12	3	16	0	2	16	0	0	14.0	44	
i 1	11.005816326530612	1.01	63	230	4	26	13	16	0	2	16	0	0	13.971335930312387	44	
i 1	11.994959183673469	1.01	61	932	3	27	13	16	0	1	16	0	0	13.971335930312387	48	
i 1	11.99521768707483	1.01	61	118	4	16	11	16	0	2	16	0	0	14.0	48	
i 1	11.99521768707483	1.01	61	118	4	26	7	16	0	1	16	0	0	13.971335930312387	48	
i 1	11.996251700680272	0.505	61	434	5	13	2	1	0	2	1	0	0	13.882378305840126	48	
i 1	11.999612244897959	1.01	63	932	3	27	6	1	0	2	1	0	0	13.971335930312387	48	
i 1	11.999870748299319	1.01	63	118	4	16	3	16	0	2	16	0	0	14.0	48	
i 1	12.001163265306122	1.01	61	118	4	26	8	16	0	1	16	0	0	13.971335930312387	48	
i 1	12.002972789115645	0.505	61	434	5	25	8	1	0	1	1	0	0	13.971335930312387	48	
i 1	12.004523809523809	1.01	63	932	3	12	2	16	0	1	16	0	0	14.0	48	
i 1	12.005299319727891	1.01	61	932	3	12	4	16	0	1	16	0	0	14.0	48	
i 1	12.005299319727891	0.505	63	434	5	25	5	16	0	1	16	0	0	13.971335930312387	48	
i 1	12.005557823129251	0.505	63	434	5	14	16	16	0	1	16	0	0	14.0	48	
i 1	12.494183673469388	0.505	61	700	4	15	15	1	0	1	1	0	0	14.0	50	
i 1	12.494700680272109	0.505	63	433	5	14	13	1	0	1	1	0	0	14.0	50	
i 1	12.494700680272109	0.505	63	700	4	25	15	1	0	2	1	0	0	13.971335930312387	50	
i 1	12.501938775510204	0.505	63	433	5	13	4	1	0	1	1	0	0	13.882378305840126	50	
i 1	12.503231292517007	0.505	63	700	4	25	5	1	0	2	1	0	0	13.971335930312387	50	
i 1	12.503489795918368	0.505	61	700	4	15	14	16	0	2	16	0	0	14.0	50	
i 1	12.505557823129251	0.505	63	433	5	25	15	16	0	2	16	0	0	13.971335930312387	50	
i 1	12.505816326530612	0.505	63	433	5	25	12	1	0	2	1	0	0	13.971335930312387	50	
i 1	12.993925170068028	1.01	61	195	4	16	8	1	0	2	1	0	0	14.0	52	
i 1	12.994442176870749	1.01	63	1079	3	27	3	16	0	2	16	0	0	13.971335930312387	52	
i 1	12.995476190476191	1.01	63	581	4	25	4	1	0	1	1	0	0	13.971335930312387	52	
i 1	12.995993197278912	1.01	63	581	4	15	11	16	0	1	16	0	0	14.0	52	
i 1	12.996251700680272	1.01	63	581	4	25	1	1	0	2	1	0	0	13.971335930312387	52	
i 1	12.997027210884355	1.01	63	195	4	16	6	16	0	1	16	0	0	14.0	52	
i 1	12.997802721088435	1.01	63	1079	3	27	10	16	0	2	16	0	0	13.971335930312387	52	
i 1	12.998319727891156	1.01	61	195	5	25	15	1	0	2	1	0	0	13.971335930312387	52	
i 1	12.998836734693878	1.01	61	195	4	26	2	1	0	1	1	0	0	13.971335930312387	52	
i 1	12.999870748299319	1.01	63	1079	3	12	2	1	0	1	1	0	0	14.0	52	
i 1	13.000129251700681	1.01	63	1079	3	12	5	16	0	2	16	0	0	14.0	52	
i 1	13.001163265306122	1.01	63	195	5	14	10	1	0	2	1	0	0	14.0	52	
i 1	13.001938775510204	1.01	63	195	5	13	6	16	0	2	16	0	0	13.882378305840126	52	
i 1	13.003231292517007	1.01	61	195	4	26	12	16	0	1	16	0	0	13.971335930312387	52	
i 1	13.003489795918368	1.01	61	581	4	15	8	1	0	2	1	0	0	14.0	52	
i 1	13.006333333333334	1.01	63	195	5	25	6	16	0	1	16	0	0	13.971335930312387	52	
i 1	13.994183673469388	1.01	61	670	4	15	1	1	0	1	1	0	0	14.0	56	
i 1	13.994959183673469	0.505	61	354	4	16	5	16	0	2	16	0	0	14.0	56	
i 1	13.99521768707483	0.505	61	354	4	26	2	16	0	1	16	0	0	13.971335930312387	56	
i 1	13.995993197278912	1.01	63	354	3	12	4	1	0	2	1	0	0	14.0	56	
i 1	13.995993197278912	1.01	63	670	4	25	11	16	0	2	16	0	0	13.971335930312387	56	
i 1	13.998061224489796	1.01	63	354	3	27	14	1	0	1	1	0	0	13.971335930312387	56	
i 1	13.998319727891156	0.505	61	88	5	14	14	1	0	1	1	0	0	14.0	56	
i 1	13.998578231292518	1.01	63	670	4	15	4	16	0	1	16	0	0	14.0	56	
i 1	13.999353741496599	0.505	63	88	5	13	11	1	0	2	1	0	0	13.882378305840126	56	
i 1	14.000129251700681	0.505	63	88	5	25	2	16	0	2	16	0	0	13.971335930312387	56	
i 1	14.001163265306122	1.01	63	670	4	25	15	16	0	1	16	0	0	13.971335930312387	56	
i 1	14.001680272108844	0.505	61	354	4	16	4	1	0	1	1	0	0	14.0	56	
i 1	14.003489795918368	1.01	61	354	3	12	1	16	0	1	16	0	0	14.0	56	
i 1	14.005040816326531	0.505	61	354	4	26	1	1	0	2	1	0	0	13.971335930312387	56	
i 1	14.005816326530612	1.01	61	354	3	27	11	1	0	2	1	0	0	13.971335930312387	56	
i 1	14.006074829931972	0.505	61	88	5	25	8	16	0	2	16	0	0	13.971335930312387	56	
i 1	14.498319727891156	0.505	61	172	4	26	9	1	0	1	1	0	0	13.971335930312387	58	
i 1	14.501421768707482	0.505	61	172	4	16	16	1	0	2	1	0	0	14.0	58	
i 1	14.502455782312925	0.505	63	1056	4	25	10	1	0	2	1	0	0	13.971335930312387	58	
i 1	14.502714285714285	0.505	63	1056	4	13	1	16	0	2	16	0	0	13.882378305840126	58	
i 1	14.503231292517007	0.505	63	1056	4	14	8	16	0	2	16	0	0	14.0	58	
i 1	14.504523809523809	0.505	61	172	4	16	2	1	0	2	1	0	0	14.0	58	
i 1	14.506074829931972	0.505	63	172	4	26	16	1	0	2	1	0	0	13.971335930312387	58	
i 1	14.506333333333334	0.505	61	1056	4	25	15	16	0	1	16	0	0	13.971335930312387	58	
i 1	14.993666666666666	1.01	61	908	4	25	16	16	0	1	16	0	0	13.971335930312387	60	
i 1	14.99521768707483	1.01	61	592	4	25	12	16	0	1	16	0	0	13.971335930312387	60	
i 1	14.998061224489796	1.01	63	94	4	16	11	16	0	1	16	0	0	14.0	60	
i 1	14.998061224489796	2.02	63	592	3	27	2	1	0	1	1	0	0	13.971335930312387	60	
i 1	14.999095238095238	1.01	63	94	4	26	6	16	0	2	16	0	0	13.971335930312387	60	
i 1	14.999612244897959	1.01	63	592	4	25	16	16	0	2	16	0	0	13.971335930312387	60	
i 1	14.999612244897959	1.01	63	94	4	26	1	1	0	1	1	0	0	13.971335930312387	60	
i 1	15.000646258503401	1.01	63	908	4	14	2	16	0	1	16	0	0	14.0	60	
i 1	15.001163265306122	1.01	63	94	4	16	14	16	0	1	16	0	0	14.0	60	
i 1	15.003231292517007	1.01	63	908	4	25	3	1	0	2	1	0	0	13.971335930312387	60	
i 1	15.003231292517007	2.02	61	592	3	27	1	1	0	2	1	0	0	13.971335930312387	60	
i 1	15.003489795918368	2.02	63	592	3	12	7	16	0	1	16	0	0	14.0	60	
i 1	15.004265306122448	2.02	61	592	3	12	8	1	0	2	1	0	0	14.0	60	
i 1	15.005299319727891	1.01	63	908	4	13	1	16	0	1	16	0	0	13.882378305840126	60	
i 1	15.006333333333334	1.01	61	592	4	15	3	16	0	2	16	0	0	14.0	60	
i 1	15.006333333333334	1.01	63	592	4	15	14	16	0	1	16	0	0	14.0	60	
i 1	15.994700680272109	3.0300000000000002	61	704	4	25	14	1	0	2	1	0	0	13.971335930312387	64	
i 1	15.995734693877552	1.01	63	1090	4	14	7	1	0	2	1	0	0	14.0	64	
i 1	15.995734693877552	3.0300000000000002	63	704	4	25	14	1	0	2	1	0	0	13.971335930312387	64	
i 1	15.998061224489796	1.01	63	1090	4	13	11	1	0	2	1	0	0	13.882378305840126	64	
i 1	15.998836734693878	1.01	61	206	4	26	11	16	0	2	16	0	0	13.971335930312387	64	
i 1	15.999095238095238	1.01	61	206	4	16	1	16	0	2	16	0	0	14.0	64	
i 1	15.999095238095238	1.01	63	1090	4	25	14	16	0	1	16	0	0	13.971335930312387	64	
i 1	16.0006462585034	3.0300000000000002	61	704	4	15	5	1	0	2	1	0	0	14.0	64	
i 1	16.001163265306122	1.01	63	206	4	26	10	1	0	1	1	0	0	13.971335930312387	64	
i 1	16.001938775510204	1.01	61	206	4	16	8	1	0	1	1	0	0	14.0	64	
i 1	16.00400680272109	3.0300000000000002	63	704	4	15	3	16	0	2	16	0	0	14.0	64	
i 1	16.006074829931972	1.01	61	1090	4	25	5	1	0	1	1	0	0	13.971335930312387	64	
i 1	16.99444217687075	0.505	63	122	5	14	16	16	0	2	16	0	0	14.0	68	
i 1	16.99495918367347	0.505	63	388	3	12	10	16	0	2	16	0	0	14.0	68	
i 1	16.99599319727891	0.505	63	122	5	25	15	1	0	2	1	0	0	13.971335930312387	68	
i 1	16.996251700680272	0.505	61	122	5	13	4	16	0	1	16	0	0	13.882378305840126	68	
i 1	16.996768707482993	1.01	63	388	4	16	5	16	0	2	16	0	0	14.0	68	
i 1	17.00012925170068	0.505	61	388	3	27	16	16	0	2	16	0	0	13.971335930312387	68	
i 1	17.00012925170068	0.505	61	388	3	27	4	1	0	1	1	0	0	13.971335930312387	68	
i 1	17.003231292517007	0.505	61	388	3	12	3	16	0	1	16	0	0	14.0	68	
i 1	17.003231292517007	1.01	63	388	4	26	12	16	0	1	16	0	0	13.971335930312387	68	
i 1	17.003489795918366	0.505	63	122	5	25	1	1	0	1	1	0	0	13.971335930312387	68	
i 1	17.00426530612245	1.01	63	388	4	26	7	1	0	2	1	0	0	13.971335930312387	68	
i 1	17.006333333333334	1.01	63	388	4	16	2	1	0	2	1	0	0	14.0	68	
i 1	17.49521768707483	0.505	63	206	5	25	4	16	0	2	16	0	0	13.971335930312387	70	
i 1	17.496768707482993	0.505	63	206	3	27	1	1	0	1	1	0	0	13.971335930312387	70	
i 1	17.498061224489796	0.505	63	206	5	25	13	16	0	2	16	0	0	13.971335930312387	70	
i 1	17.498836734693878	0.505	63	206	5	14	3	16	0	2	16	0	0	14.0	70	
i 1	17.4993537414966	0.505	61	206	3	27	10	1	0	1	1	0	0	13.971335930312387	70	
i 1	17.502197278911563	0.505	63	206	5	13	6	1	0	1	1	0	0	13.882378305840126	70	
i 1	17.503748299319728	0.505	63	206	3	12	10	16	0	2	16	0	0	14.0	70	
i 1	17.506074829931972	0.505	63	206	3	12	14	16	0	2	16	0	0	14.0	70	
i 1	17.99573469387755	0.505	63	107	3	12	1	1	0	2	1	0	0	14.0	72	
i 1	17.99599319727891	0.505	63	971	3	26	11	1	0	1	1	0	0	13.971335930312387	72	
i 1	17.996251700680272	0.505	63	107	3	27	10	16	0	1	16	0	0	13.971335930312387	72	
i 1	17.996510204081634	2.02	61	388	5	25	12	1	0	1	1	0	0	13.971335930312387	72	
i 1	17.996768707482993	0.505	61	971	3	16	11	16	0	2	16	0	0	14.0	72	
i 1	17.997285714285713	2.02	63	388	5	25	16	16	0	2	16	0	0	13.971335930312387	72	
i 1	17.998319727891158	2.02	63	388	5	14	9	16	0	1	16	0	0	14.0	72	
i 1	17.99987074829932	2.02	63	388	5	13	9	16	0	2	16	0	0	13.882378305840126	72	
i 1	17.99987074829932	0.505	61	971	3	16	11	1	0	1	1	0	0	14.0	72	
i 1	18.00400680272109	0.505	63	107	3	12	16	1	0	1	1	0	0	14.0	72	
i 1	18.006074829931972	0.505	63	971	3	26	16	16	0	1	16	0	0	13.971335930312387	72	
i 1	18.006333333333334	0.505	63	107	3	27	1	16	0	1	16	0	0	13.971335930312387	72	
i 1	18.493925170068028	0.505	63	1090	2	27	11	1	0	1	1	0	0	13.971335930312387	74	
i 1	18.49547619047619	0.505	61	1090	3	26	8	1	0	2	1	0	0	13.971335930312387	74	
i 1	18.49547619047619	0.505	61	1090	3	26	16	16	0	2	16	0	0	13.971335930312387	74	
i 1	18.496768707482993	0.505	63	1090	2	12	12	16	0	1	16	0	0	14.0	74	
i 1	18.498578231292516	0.505	63	1090	3	16	14	1	0	1	1	0	0	14.0	74	
i 1	18.49961224489796	0.505	61	1090	2	12	14	1	0	1	1	0	0	14.0	74	
i 1	18.50400680272109	0.505	61	1090	2	27	13	16	0	2	16	0	0	13.971335930312387	74	
i 1	18.50529931972789	0.505	63	1090	3	16	11	1	0	2	1	0	0	14.0	74	
i 1	18.993666666666666	0.505	63	570	4	15	14	1	0	2	1	0	0	14.0	76	
i 1	18.994183673469387	2.02	63	72	4	16	10	1	0	1	1	0	0	14.0	76	
i 1	18.99521768707483	0.505	61	1005	2	12	9	16	0	2	16	0	0	14.0	76	
i 1	18.996510204081634	0.505	63	1005	2	27	12	16	0	1	16	0	0	13.971335930312387	76	
i 1	18.997285714285713	2.02	61	72	4	26	4	1	0	2	1	0	0	13.971335930312387	76	
i 1	18.9993537414966	2.02	61	72	4	26	10	1	0	1	1	0	0	13.971335930312387	76	
i 1	19.000904761904764	0.505	63	1005	2	12	10	16	0	1	16	0	0	14.0	76	
i 1	19.001163265306122	2.02	63	72	4	16	5	1	0	2	1	0	0	14.0	76	
i 1	19.002197278911563	0.505	61	570	4	25	14	1	0	1	1	0	0	13.971335930312387	76	
i 1	19.003231292517007	0.505	63	1005	2	27	16	16	0	2	16	0	0	13.971335930312387	76	
i 1	19.006074829931972	0.505	61	570	4	25	5	16	0	1	16	0	0	13.971335930312387	76	
i 1	19.006333333333334	0.505	61	570	4	15	1	1	0	2	1	0	0	14.0	76	
i 1	19.493666666666666	0.505	61	774	4	15	6	1	0	1	1	0	0	14.0	78	
i 1	19.493925170068028	0.505	61	72	3	27	10	16	0	2	16	0	0	13.971335930312387	78	
i 1	19.49521768707483	0.505	63	72	3	12	10	1	0	2	1	0	0	14.0	78	
i 1	19.497285714285713	0.505	61	774	4	15	12	16	0	1	16	0	0	14.0	78	
i 1	19.498061224489796	0.505	63	72	3	12	3	1	0	2	1	0	0	14.0	78	
i 1	19.498319727891158	0.505	63	774	4	25	4	16	0	1	16	0	0	13.971335930312387	78	
i 1	19.5006462585034	0.505	61	72	3	27	8	16	0	2	16	0	0	13.971335930312387	78	
i 1	19.501680272108842	0.505	63	774	4	25	8	1	0	2	1	0	0	13.971335930312387	78	
i 1	19.993925170068028	1.01	61	1005	4	25	10	1	0	2	1	0	0	13.971335930312387	80	
i 1	19.99573469387755	1.01	63	1005	4	15	4	1	0	1	1	0	0	14.0	80	
i 1	19.996251700680272	1.01	61	387	5	14	7	16	0	1	16	0	0	14.0	80	
i 1	19.996251700680272	1.01	63	570	3	12	14	16	0	2	16	0	0	14.0	80	
i 1	19.996510204081634	1.01	63	1005	4	15	13	16	0	2	16	0	0	14.0	80	
i 1	19.997285714285713	1.01	63	570	3	12	8	16	0	1	16	0	0	14.0	80	
i 1	19.99987074829932	1.01	63	387	5	13	2	16	0	1	16	0	0	13.882378305840126	80	
i 1	20.002455782312925	1.01	63	387	5	25	1	1	0	1	1	0	0	13.971335930312387	80	
i 1	20.003489795918366	1.01	61	570	3	27	8	16	0	2	16	0	0	13.971335930312387	80	
i 1	20.00529931972789	1.01	61	387	5	25	8	16	0	1	16	0	0	13.971335930312387	80	
i 1	20.00529931972789	1.01	61	570	3	27	15	16	0	2	16	0	0	13.971335930312387	80	
i 1	20.00555782312925	1.01	63	1005	4	25	5	16	0	2	16	0	0	13.971335930312387	80	
i 1	20.99495918367347	0.505	63	698	3	12	4	16	0	2	16	0	0	14.0	84	
i 1	20.99573469387755	2.02	63	1084	3	16	9	1	0	1	1	0	0	14.0	84	
i 1	20.997544217687075	0.505	63	1084	4	15	15	1	0	2	1	0	0	14.0	84	
i 1	20.997544217687075	0.505	63	1084	4	25	11	16	0	2	16	0	0	13.971335930312387	84	
i 1	20.998319727891158	2.02	63	1084	3	16	8	16	0	2	16	0	0	14.0	84	
i 1	20.999095238095236	1.01	61	200	5	25	14	16	0	1	16	0	0	13.971335930312387	84	
i 1	21.00012925170068	0.505	63	1084	4	25	5	16	0	1	16	0	0	13.971335930312387	84	
i 1	21.001421768707484	0.505	61	1084	4	15	5	1	0	2	1	0	0	14.0	84	
i 1	21.002197278911563	0.505	61	698	3	27	15	16	0	1	16	0	0	13.971335930312387	84	
i 1	21.00400680272109	0.505	63	698	3	27	1	16	0	2	16	0	0	13.971335930312387	84	
i 1	21.00426530612245	0.505	63	698	3	12	8	16	0	2	16	0	0	14.0	84	
i 1	21.00426530612245	1.01	63	200	5	25	16	16	0	1	16	0	0	13.971335930312387	84	
i 1	21.00478231292517	2.02	63	1084	3	26	2	16	0	1	16	0	0	13.971335930312387	84	
i 1	21.00478231292517	2.02	63	1084	3	26	9	1	0	2	1	0	0	13.971335930312387	84	
i 1	21.005816326530613	1.01	63	200	5	13	15	1	0	1	1	0	0	13.882378305840126	84	
i 1	21.006333333333334	1.01	61	200	5	14	12	16	0	2	16	0	0	14.0	84	
i 1	21.493666666666666	0.505	63	902	4	25	14	1	0	2	1	0	0	13.971335930312387	86	
i 1	21.493925170068028	0.505	63	902	4	25	13	16	0	1	16	0	0	13.971335930312387	86	
i 1	21.497027210884355	0.505	61	586	3	12	11	16	0	2	16	0	0	14.0	86	
i 1	21.497027210884355	0.505	61	586	3	27	16	1	0	2	1	0	0	13.971335930312387	86	
i 1	21.50012925170068	0.505	63	902	4	15	9	16	0	2	16	0	0	14.0	86	
i 1	21.502714285714287	0.505	61	586	3	12	9	16	0	2	16	0	0	14.0	86	
i 1	21.502972789115645	0.505	61	586	3	27	9	16	0	1	16	0	0	13.971335930312387	86	
i 1	21.50400680272109	0.505	61	902	4	15	3	1	0	1	1	0	0	14.0	86	
i 1	21.99470068027211	1.01	63	382	3	27	3	16	0	1	16	0	0	13.971335930312387	88	
i 1	21.996251700680272	1.5150000000000001	63	116	5	14	6	16	0	2	16	0	0	14.0	88	
i 1	21.996768707482993	1.01	61	382	3	27	16	16	0	1	16	0	0	13.971335930312387	88	
i 1	22.00038775510204	1.5150000000000001	63	116	5	25	1	16	0	2	16	0	0	13.971335930312387	88	
i 1	22.00038775510204	1.5150000000000001	63	116	5	25	8	16	0	1	16	0	0	13.971335930312387	88	
i 1	22.00038775510204	1.01	61	698	4	25	9	1	0	2	1	0	0	13.971335930312387	88	
i 1	22.000904761904764	1.5150000000000001	63	116	5	13	2	16	0	2	16	0	0	13.882378305840126	88	
i 1	22.000904761904764	1.01	63	698	4	15	6	16	0	1	16	0	0	14.0	88	
i 1	22.001421768707484	1.01	63	698	4	25	11	16	0	1	16	0	0	13.971335930312387	88	
i 1	22.001680272108842	1.01	61	382	3	12	5	1	0	1	1	0	0	14.0	88	
i 1	22.00478231292517	1.01	61	698	4	15	16	1	0	1	1	0	0	14.0	88	
i 1	22.00555782312925	1.01	61	382	3	12	13	1	0	1	1	0	0	14.0	88	
i 1	22.99470068027211	1.01	63	614	3	12	14	16	0	1	16	0	0	14.0	92	
i 1	22.99495918367347	0.505	63	614	4	15	2	1	0	1	1	0	0	14.0	92	
i 1	22.99495918367347	0.505	61	614	4	25	12	16	0	2	16	0	0	13.971335930312387	92	
i 1	22.997027210884355	1.01	63	1000	3	16	5	1	0	2	1	0	0	14.0	92	
i 1	22.99961224489796	0.505	63	614	4	15	6	16	0	1	16	0	0	14.0	92	
i 1	23.0006462585034	1.01	61	614	3	27	16	16	0	2	16	0	0	13.971335930312387	92	
i 1	23.001421768707484	0.505	61	614	4	25	6	1	0	2	1	0	0	13.971335930312387	92	
i 1	23.001421768707484	1.01	63	1000	3	26	16	1	0	2	1	0	0	13.971335930312387	92	
i 1	23.002455782312925	1.01	61	1000	3	16	15	1	0	1	1	0	0	14.0	92	
i 1	23.00426530612245	1.01	63	614	3	27	2	16	0	1	16	0	0	13.971335930312387	92	
i 1	23.00478231292517	1.01	63	614	3	12	8	1	0	2	1	0	0	14.0	92	
i 1	23.00504081632653	1.01	63	1000	3	26	1	1	0	1	1	0	0	13.971335930312387	92	
i 1	23.49470068027211	0.505	61	382	4	25	12	1	0	2	1	0	0	13.971335930312387	94	
i 1	23.49521768707483	0.505	63	382	4	25	14	1	0	2	1	0	0	13.971335930312387	94	
i 1	23.49599319727891	0.505	61	382	4	15	6	16	0	2	16	0	0	14.0	94	
i 1	23.496251700680272	0.505	61	115	5	14	13	1	0	1	1	0	0	14.0	94	
i 1	23.497027210884355	0.505	63	382	4	15	11	1	0	2	1	0	0	14.0	94	
i 1	23.4993537414966	0.505	61	115	5	13	10	16	0	2	16	0	0	13.882378305840126	94	
i 1	23.501421768707484	0.505	63	115	5	25	1	1	0	2	1	0	0	13.971335930312387	94	
i 1	23.501680272108842	0.505	63	115	5	25	14	1	0	2	1	0	0	13.971335930312387	94	
i 1	23.99470068027211	2.02	61	1103	2	12	4	16	0	1	16	0	0	14.0	96	
i 1	23.99547619047619	2.02	63	1103	2	12	10	16	0	1	16	0	0	14.0	96	
i 1	23.996251700680272	2.02	63	219	4	15	10	1	0	1	1	0	0	14.0	96	
i 1	23.997027210884355	2.02	63	219	4	25	6	1	0	2	1	0	0	13.971335930312387	96	
i 1	23.998578231292516	2.02	63	219	4	25	12	16	0	1	16	0	0	13.971335930312387	96	
i 1	23.998836734693878	2.02	61	1103	3	26	2	16	0	1	16	0	0	13.971335930312387	96	
i 1	23.99961224489796	2.02	63	1103	2	27	3	1	0	1	1	0	0	13.971335930312387	96	
i 1	24.00012925170068	2.02	61	1103	4	13	5	1	0	2	1	0	0	13.882378305840126	96	
i 1	24.002972789115645	2.02	63	219	4	15	11	16	0	1	16	0	0	14.0	96	
i 1	24.003748299319728	2.02	63	1103	4	25	6	16	0	2	16	0	0	13.971335930312387	96	
i 1	24.00400680272109	2.02	61	1103	3	26	14	1	0	1	1	0	0	13.971335930312387	96	
i 1	24.00478231292517	2.02	63	1103	4	14	3	1	0	1	1	0	0	14.0	96	
i 1	24.00529931972789	2.02	63	1103	3	16	5	1	0	2	1	0	0	14.0	96	
i 1	24.00555782312925	2.02	63	1103	4	25	10	16	0	2	16	0	0	13.971335930312387	96	
i 1	24.006333333333334	2.02	61	1103	3	16	4	1	0	1	1	0	0	14.0	96	
i 1	24.006333333333334	2.02	61	1103	2	27	6	1	0	2	1	0	0	13.971335930312387	96	
i 1	25.993666666666666	1.01	63	605	5	14	13	16	0	2	16	0	0	14.0	104	
i 1	25.99444217687075	1.5150000000000001	61	219	4	16	8	1	0	2	1	0	0	14.0	104	
i 1	25.99495918367347	2.02	63	1103	4	25	13	16	0	1	16	0	0	13.971335930312387	104	
i 1	25.99521768707483	1.01	63	1103	3	12	10	16	0	1	16	0	0	14.0	104	
i 1	25.99599319727891	1.01	63	605	5	13	4	16	0	1	16	0	0	13.882378305840126	104	
i 1	25.998061224489796	2.02	61	1103	4	25	3	1	0	2	1	0	0	13.971335930312387	104	
i 1	25.998319727891158	1.01	63	1103	3	27	12	1	0	1	1	0	0	13.971335930312387	104	
i 1	25.998578231292516	1.01	61	1103	3	12	5	16	0	1	16	0	0	14.0	104	
i 1	25.998836734693878	1.01	63	605	5	25	7	1	0	2	1	0	0	13.971335930312387	104	
i 1	25.999095238095236	1.01	63	605	5	25	4	1	0	1	1	0	0	13.971335930312387	104	
i 1	25.99987074829932	1.5150000000000001	63	219	4	26	4	16	0	1	16	0	0	13.971335930312387	104	
i 1	26.001421768707484	2.02	63	1103	4	15	5	16	0	2	16	0	0	14.0	104	
i 1	26.001680272108842	1.5150000000000001	63	219	4	16	8	1	0	1	1	0	0	14.0	104	
i 1	26.00400680272109	1.5150000000000001	63	219	4	26	11	1	0	2	1	0	0	13.971335930312387	104	
i 1	26.005816326530613	1.01	61	1103	3	27	10	1	0	2	1	0	0	13.971335930312387	104	
i 1	26.006074829931972	2.02	63	1103	4	15	12	1	0	1	1	0	0	14.0	104	
i 1	26.99470068027211	1.01	61	717	5	25	13	1	0	2	1	0	0	13.971335930312387	108	
i 1	26.996510204081634	1.01	61	401	3	27	5	1	0	1	1	0	0	13.971335930312387	108	
i 1	26.997802721088437	1.01	63	401	3	12	5	16	0	2	16	0	0	14.0	108	
i 1	26.997802721088437	1.01	61	401	3	27	14	16	0	1	16	0	0	13.971335930312387	108	
i 1	27.001680272108842	1.01	61	717	5	14	6	1	0	2	1	0	0	14.0	108	
i 1	27.002455782312925	1.01	63	401	3	12	5	16	0	1	16	0	0	14.0	108	
i 1	27.00555782312925	1.01	61	717	5	13	13	16	0	1	16	0	0	13.882378305840126	108	
i 1	27.00555782312925	1.01	61	717	5	25	3	1	0	2	1	0	0	13.971335930312387	108	
i 1	27.49470068027211	0.505	63	1103	3	26	8	16	0	1	16	0	0	13.971335930312387	110	
i 1	27.49573469387755	0.505	61	1103	3	26	13	1	0	2	1	0	0	13.971335930312387	110	
i 1	27.503489795918366	0.505	63	1103	3	16	7	16	0	2	16	0	0	14.0	110	
i 1	27.503748299319728	0.505	61	1103	3	16	7	1	0	1	1	0	0	14.0	110	
i 1	27.99444217687075	1.01	63	401	5	14	9	16	0	1	16	0	0	14.0	112	
i 1	27.99470068027211	1.01	63	899	3	27	12	1	0	1	1	0	0	13.971335930312387	112	
i 1	27.99573469387755	1.01	61	899	3	12	13	16	0	2	16	0	0	14.0	112	
i 1	27.996251700680272	1.01	61	401	5	25	1	1	0	2	1	0	0	13.971335930312387	112	
i 1	27.996768707482993	1.01	63	899	3	27	4	1	0	1	1	0	0	13.971335930312387	112	
i 1	27.997544217687075	2.02	63	899	4	15	2	16	0	2	16	0	0	14.0	112	
i 1	27.997544217687075	1.5150000000000001	63	85	4	26	11	1	0	2	1	0	0	13.971335930312387	112	
i 1	27.998319727891158	2.02	63	899	4	25	10	1	0	1	1	0	0	13.971335930312387	112	
i 1	27.999095238095236	2.02	63	899	4	25	10	16	0	2	16	0	0	13.971335930312387	112	
i 1	27.9993537414966	1.01	63	401	5	13	14	16	0	2	16	0	0	13.882378305840126	112	
i 1	27.99961224489796	1.01	63	899	3	12	12	16	0	1	16	0	0	14.0	112	
i 1	28.000904761904764	1.01	63	401	5	25	10	16	0	2	16	0	0	13.971335930312387	112	
i 1	28.003489795918366	1.5150000000000001	61	85	4	26	6	16	0	2	16	0	0	13.971335930312387	112	
i 1	28.00555782312925	2.02	61	899	4	15	8	1	0	1	1	0	0	14.0	112	
i 1	28.00555782312925	1.5150000000000001	63	85	4	16	1	16	0	1	16	0	0	14.0	112	
i 1	28.006074829931972	1.5150000000000001	61	85	4	16	12	16	0	1	16	0	0	14.0	112	
i 1	28.997027210884355	1.01	63	197	3	12	8	1	0	1	1	0	0	14.0	116	
i 1	28.99961224489796	1.01	63	197	3	27	16	16	0	2	16	0	0	13.971335930312387	116	
i 1	29.001680272108842	1.01	63	583	5	14	11	1	0	1	1	0	0	14.0	116	
i 1	29.003489795918366	1.01	61	583	5	25	10	1	0	1	1	0	0	13.971335930312387	116	
i 1	29.003748299319728	1.01	61	197	3	12	5	1	0	2	1	0	0	14.0	116	
i 1	29.00400680272109	1.01	63	583	5	25	10	1	0	2	1	0	0	13.971335930312387	116	
i 1	29.00478231292517	1.01	63	197	3	27	5	16	0	1	16	0	0	13.971335930312387	116	
i 1	29.006074829931972	1.01	61	583	5	13	14	1	0	2	1	0	0	13.882378305840126	116	
i 1	29.49961224489796	0.505	63	899	3	16	2	1	0	2	1	0	0	14.0	118	
i 1	29.49987074829932	0.505	63	899	3	26	4	16	0	2	16	0	0	13.971335930312387	118	
i 1	29.502714285714287	0.505	63	899	3	16	4	16	0	1	16	0	0	14.0	118	
i 1	29.502714285714287	0.505	63	899	3	26	12	16	0	1	16	0	0	13.971335930312387	118	
i 1	29.99547619047619	2.02	63	1081	3	26	7	1	0	2	1	0	0	13.971335930312387	120	
i 1	29.996251700680272	0.505	61	695	3	12	4	16	0	1	16	0	0	14.0	120	
i 1	29.996510204081634	2.02	61	695	4	25	15	1	0	2	1	0	0	13.971335930312387	120	
i 1	29.996768707482993	1.01	61	197	5	14	3	16	0	1	16	0	0	14.0	120	
i 1	29.997285714285713	1.01	63	197	5	25	1	1	0	1	1	0	0	13.971335930312387	120	
i 1	29.997544217687075	0.505	61	695	3	27	3	16	0	2	16	0	0	13.971335930312387	120	
i 1	29.998061224489796	2.02	63	1081	3	16	8	1	0	1	1	0	0	14.0	120	
i 1	30.00012925170068	0.505	63	695	3	12	13	1	0	2	1	0	0	14.0	120	
i 1	30.000904761904764	2.02	63	695	4	25	1	16	0	2	16	0	0	13.971335930312387	120	
i 1	30.001421768707484	1.01	63	197	5	25	11	16	0	2	16	0	0	13.971335930312387	120	
i 1	30.002714285714287	2.02	63	1081	3	16	1	1	0	1	1	0	0	14.0	120	
i 1	30.003231292517007	2.02	61	695	4	15	10	1	0	1	1	0	0	14.0	120	
i 1	30.003748299319728	0.505	63	695	3	27	11	16	0	1	16	0	0	13.971335930312387	120	
i 1	30.00400680272109	1.01	63	197	5	13	5	1	0	2	1	0	0	13.882378305840126	120	
i 1	30.00400680272109	2.02	61	1081	3	26	15	1	0	2	1	0	0	13.971335930312387	120	
i 1	30.00555782312925	2.02	61	695	4	15	11	16	0	1	16	0	0	14.0	120	
i 1	30.49444217687075	0.505	61	583	3	12	15	16	0	2	16	0	0	14.0	122	
i 1	30.496768707482993	0.505	61	583	3	12	10	1	0	1	1	0	0	14.0	122	
i 1	30.50452380952381	0.505	61	583	3	27	15	1	0	1	1	0	0	13.971335930312387	122	
i 1	30.50452380952381	0.505	61	583	3	27	16	16	0	2	16	0	0	13.971335930312387	122	
i 1	30.997544217687075	1.01	61	379	5	25	3	1	0	1	1	0	0	13.971335930312387	124	
i 1	30.99987074829932	1.01	61	379	3	12	13	16	0	1	16	0	0	14.0	124	
i 1	31.000904761904764	1.01	61	379	5	13	5	1	0	1	1	0	0	13.882378305840126	124	
i 1	31.001938775510204	1.01	61	379	3	27	3	16	0	2	16	0	0	13.971335930312387	124	
i 1	31.002714285714287	1.01	61	379	3	12	16	16	0	1	16	0	0	14.0	124	
i 1	31.00504081632653	1.01	63	379	3	27	15	16	0	1	16	0	0	13.971335930312387	124	
i 1	31.00529931972789	1.01	63	379	5	25	16	16	0	2	16	0	0	13.971335930312387	124	
i 1	31.006333333333334	1.01	63	379	5	14	4	16	0	2	16	0	0	14.0	124	
i 1	31.99521768707483	2.02	63	584	4	25	14	16	0	1	16	0	0	13.971335930312387	128	
i 1	31.99547619047619	1.01	63	86	4	26	3	16	0	1	16	0	0	13.971335930312387	128	
i 1	31.996768707482993	2.02	61	584	4	15	2	16	0	1	16	0	0	14.0	128	
i 1	31.997027210884355	1.01	61	970	2	12	6	1	0	1	1	0	0	14.0	128	
i 1	31.998061224489796	1.01	63	86	4	16	10	16	0	1	16	0	0	14.0	128	
i 1	31.998319727891158	1.01	63	970	2	27	14	16	0	2	16	0	0	13.971335930312387	128	
i 1	31.9993537414966	1.01	63	970	2	27	15	1	0	2	1	0	0	13.971335930312387	128	
i 1	32.001163265306126	1.01	63	584	5	13	5	1	0	2	1	0	0	13.882378305840126	128	
i 1	32.001163265306126	2.02	63	584	4	25	11	1	0	1	1	0	0	13.971335930312387	128	
i 1	32.00219727891157	1.01	61	86	4	16	14	16	0	1	16	0	0	14.0	128	
i 1	32.00245578231293	1.01	63	584	5	25	16	16	0	1	16	0	0	13.971335930312387	128	
i 1	32.00323129251701	2.02	61	584	4	15	2	16	0	2	16	0	0	14.0	128	
i 1	32.00478231292517	1.01	63	970	2	12	11	1	0	1	1	0	0	14.0	128	
i 1	32.00555782312925	1.01	61	584	5	14	11	16	0	2	16	0	0	14.0	128	
i 1	32.00581632653061	1.01	63	584	5	25	4	16	0	2	16	0	0	13.971335930312387	128	
i 1	32.00581632653061	1.01	63	86	4	26	10	1	0	1	1	0	0	13.971335930312387	128	
i 1	32.99444217687075	1.01	61	1082	2	27	9	1	0	2	1	0	0	13.971335930312387	132	
i 1	32.99495918367347	1.01	61	1082	4	25	13	1	0	2	1	0	0	13.971335930312387	132	
i 1	32.99651020408163	1.01	63	1082	2	12	4	16	0	1	16	0	0	14.0	132	
i 1	32.99754421768707	1.01	63	1082	2	12	5	1	0	1	1	0	0	14.0	132	
i 1	32.99961224489796	1.01	63	1082	4	13	12	1	0	2	1	0	0	13.882378305840126	132	
i 1	33.00038775510204	1.01	61	1082	4	14	10	16	0	2	16	0	0	14.0	132	
i 1	33.00219727891157	1.01	63	198	4	26	6	1	0	1	1	0	0	13.971335930312387	132	
i 1	33.00245578231293	1.01	61	198	4	16	2	1	0	2	1	0	0	14.0	132	
i 1	33.00426530612245	1.01	61	198	4	26	12	1	0	2	1	0	0	13.971335930312387	132	
i 1	33.00452380952381	1.01	61	198	4	16	13	1	0	2	1	0	0	14.0	132	
i 1	33.00478231292517	1.01	61	1082	4	25	16	1	0	1	1	0	0	13.971335930312387	132	
i 1	33.00504081632653	1.01	61	1082	2	27	2	1	0	1	1	0	0	13.971335930312387	132	
i 1	33.99521768707483	1.01	63	584	5	13	12	16	0	1	16	0	0	13.882378305840126	136	
i 1	33.99547619047619	1.01	61	584	4	16	13	16	0	2	16	0	0	14.0	136	
i 1	33.99573469387755	2.02	61	1082	4	25	7	16	0	1	16	0	0	13.971335930312387	136	
i 1	33.997027210884355	2.02	63	1082	4	25	8	1	0	1	1	0	0	13.971335930312387	136	
i 1	33.99728571428572	1.01	61	584	5	25	15	1	0	2	1	0	0	13.971335930312387	136	
i 1	33.99754421768707	1.01	61	584	4	26	6	1	0	2	1	0	0	13.971335930312387	136	
i 1	33.99909523809524	1.01	61	584	4	16	5	1	0	2	1	0	0	14.0	136	
i 1	34.00012925170068	2.02	61	198	4	27	5	16	0	1	16	0	0	13.971335930312387	136	
i 1	34.00271428571428	1.01	61	584	5	14	6	1	0	2	1	0	0	14.0	136	
i 1	34.002972789115645	1.01	61	584	4	26	13	16	0	2	16	0	0	13.971335930312387	136	
i 1	34.00348979591837	2.02	61	1082	4	15	1	1	0	2	1	0	0	14.0	136	
i 1	34.003748299319724	2.02	63	1082	4	15	11	1	0	2	1	0	0	14.0	136	
i 1	34.003748299319724	1.01	61	584	5	25	15	1	0	2	1	0	0	13.971335930312387	136	
i 1	34.004006802721086	2.02	61	198	4	12	12	1	0	1	1	0	0	14.0	136	
i 1	34.00478231292517	2.02	61	198	4	27	6	1	0	2	1	0	0	13.971335930312387	136	
i 1	34.00633333333333	2.02	61	198	4	12	1	16	0	2	16	0	0	14.0	136	
i 1	34.99444217687075	2.02	61	380	4	16	11	1	0	1	1	0	0	14.0	140	
i 1	34.997027210884355	2.02	61	380	4	16	10	1	0	1	1	0	0	14.0	140	
i 1	34.99780272108843	2.02	61	380	4	26	3	16	0	1	16	0	0	13.971335930312387	140	
i 1	34.99857823129252	1.01	61	696	5	13	7	16	0	1	16	0	0	13.882378305840126	140	
i 1	34.99909523809524	1.01	61	696	5	25	5	16	0	2	16	0	0	13.971335930312387	140	
i 1	34.99961224489796	1.01	63	696	5	25	10	1	0	2	1	0	0	13.971335930312387	140	
i 1	35.001163265306126	1.01	63	696	5	14	12	16	0	2	16	0	0	14.0	140	
i 1	35.00633333333333	2.02	63	380	4	26	12	1	0	2	1	0	0	13.971335930312387	140	
i 1	35.99366666666667	2.02	63	878	4	15	3	1	0	2	1	0	0	14.0	144	
i 1	35.99366666666667	2.02	63	64	4	27	2	1	0	1	1	0	0	13.971335930312387	144	
i 1	35.99470068027211	2.02	61	878	4	15	2	16	0	1	16	0	0	14.0	144	
i 1	35.99470068027211	2.02	61	64	4	12	11	1	0	1	1	0	0	14.0	144	
i 1	35.99470068027211	2.02	61	878	4	25	5	1	0	1	1	0	0	13.971335930312387	144	
i 1	35.99547619047619	2.02	63	64	4	27	12	16	0	2	16	0	0	13.971335930312387	144	
i 1	35.99676870748299	2.02	63	878	4	25	7	16	0	2	16	0	0	13.971335930312387	144	
i 1	35.997027210884355	1.01	63	380	5	13	10	1	0	2	1	0	0	13.882378305840126	144	
i 1	35.99831972789116	1.01	61	380	5	14	15	16	0	1	16	0	0	14.0	144	
i 1	35.99831972789116	1.01	61	380	5	25	2	16	0	2	16	0	0	13.971335930312387	144	
i 1	35.99961224489796	2.02	63	64	4	12	5	1	0	1	1	0	0	14.0	144	
i 1	36.00348979591837	1.01	63	380	5	25	14	1	0	2	1	0	0	13.971335930312387	144	
i 1	36.99495918367347	1.5150000000000001	63	176	4	26	15	16	0	1	16	0	0	13.971335930312387	148	
i 1	36.995993197278914	1.5150000000000001	61	176	4	26	8	1	0	1	1	0	0	13.971335930312387	148	
i 1	36.99831972789116	1.01	63	562	5	25	15	16	0	1	16	0	0	13.971335930312387	148	
i 1	36.99961224489796	1.5150000000000001	61	176	4	16	2	16	0	2	16	0	0	14.0	148	
i 1	36.99987074829932	1.01	61	562	5	14	1	1	0	1	1	0	0	14.0	148	
i 1	37.002972789115645	1.01	61	562	5	13	1	16	0	2	16	0	0	13.882378305840126	148	
i 1	37.002972789115645	1.01	63	562	5	25	8	16	0	2	16	0	0	13.971335930312387	148	
i 1	37.00348979591837	1.5150000000000001	63	176	4	16	3	1	0	2	1	0	0	14.0	148	
i 1	37.99418367346939	0.505	61	1060	3	12	16	1	0	1	1	0	0	14.0	152	
i 1	37.995993197278914	0.505	61	674	4	15	3	16	0	1	16	0	0	14.0	152	
i 1	37.996251700680276	1.01	61	176	5	14	4	16	0	2	16	0	0	14.0	152	
i 1	37.99651020408163	0.505	63	1060	3	27	8	1	0	2	1	0	0	13.971335930312387	152	
i 1	37.99857823129252	0.505	63	674	4	25	15	1	0	2	1	0	0	13.971335930312387	152	
i 1	37.9993537414966	1.01	61	176	5	25	10	1	0	1	1	0	0	13.971335930312387	152	
i 1	38.00012925170068	0.505	61	1060	3	27	15	1	0	1	1	0	0	13.971335930312387	152	
i 1	38.00038775510204	1.01	63	176	5	13	14	16	0	1	16	0	0	13.882378305840126	152	
i 1	38.00271428571428	0.505	63	674	4	15	2	16	0	1	16	0	0	14.0	152	
i 1	38.003748299319724	0.505	61	1060	3	12	14	16	0	2	16	0	0	14.0	152	
i 1	38.003748299319724	0.505	61	674	4	25	6	16	0	1	16	0	0	13.971335930312387	152	
i 1	38.006074829931976	1.01	63	176	5	25	4	16	0	2	16	0	0	13.971335930312387	152	
i 1	38.49366666666667	0.505	63	878	3	27	6	1	0	1	1	0	0	13.971335930312387	154	
i 1	38.496251700680276	0.505	61	562	4	15	12	16	0	2	16	0	0	14.0	154	
i 1	38.49987074829932	0.505	63	64	4	16	9	1	0	1	1	0	0	14.0	154	
i 1	38.50012925170068	0.505	61	562	4	15	14	16	0	1	16	0	0	14.0	154	
i 1	38.50038775510204	0.505	61	562	4	25	6	1	0	2	1	0	0	13.971335930312387	154	
i 1	38.50168027210884	0.505	63	64	4	16	16	1	0	2	1	0	0	14.0	154	
i 1	38.50168027210884	0.505	63	64	4	26	7	1	0	2	1	0	0	13.971335930312387	154	
i 1	38.501938775510204	0.505	63	878	3	27	12	16	0	1	16	0	0	13.971335930312387	154	
i 1	38.50271428571428	0.505	61	878	3	12	11	1	0	1	1	0	0	14.0	154	
i 1	38.504006802721086	0.505	63	562	4	25	3	16	0	1	16	0	0	13.971335930312387	154	
i 1	38.50581632653061	0.505	61	878	3	12	6	1	0	2	1	0	0	14.0	154	
i 1	38.506074829931976	0.505	63	64	4	26	6	16	0	2	16	0	0	13.971335930312387	154	
i 1	38.99521768707483	0.505	63	714	3	27	2	1	0	2	1	0	0	13.971335930312387	156	
i 1	38.99780272108843	1.01	61	398	5	14	13	16	0	2	16	0	0	14.0	156	
i 1	38.99857823129252	1.01	61	398	4	25	6	1	0	2	1	0	0	13.971335930312387	156	
i 1	38.998836734693874	0.505	63	714	3	27	5	1	0	2	1	0	0	13.971335930312387	156	
i 1	38.99909523809524	0.505	61	714	3	12	10	1	0	1	1	0	0	14.0	156	
i 1	38.99909523809524	5.555	61	1100	3	26	5	1	0	2	1	0	0	13.971335930312387	156	
i 1	38.9993537414966	5.555	61	1100	3	26	13	1	0	1	1	0	0	13.971335930312387	156	
i 1	39.00012925170068	1.01	61	398	4	15	15	16	0	2	16	0	0	14.0	156	
i 1	39.0006462585034	1.01	63	398	5	13	8	16	0	1	16	0	0	13.882378305840126	156	
i 1	39.00090476190476	5.555	61	1100	3	16	7	1	0	1	1	0	0	14.0	156	
i 1	39.001938775510204	0.505	61	714	3	12	14	16	0	2	16	0	0	14.0	156	
i 1	39.002972789115645	1.01	63	398	5	25	7	1	0	1	1	0	0	13.971335930312387	156	
i 1	39.003748299319724	1.01	61	398	4	15	2	16	0	2	16	0	0	14.0	156	
i 1	39.00504081632653	1.01	61	398	4	25	15	1	0	1	1	0	0	13.971335930312387	156	
i 1	39.00529931972789	5.555	61	1100	3	16	9	16	0	1	16	0	0	14.0	156	
i 1	39.006074829931976	1.01	63	398	5	25	8	16	0	1	16	0	0	13.971335930312387	156	
i 1	39.49961224489796	0.505	63	602	3	12	6	16	0	2	16	0	0	14.0	158	
i 1	39.5006462585034	0.505	61	602	3	12	15	16	0	2	16	0	0	14.0	158	
i 1	39.50271428571428	0.505	63	602	3	27	15	16	0	1	16	0	0	13.971335930312387	158	
i 1	39.50348979591837	0.505	61	602	3	27	13	16	0	1	16	0	0	13.971335930312387	158	
i 1	39.99366666666667	0.505	63	398	3	27	10	16	0	1	16	0	0	13.971335930312387	160	
i 1	39.993925170068024	1.01	63	602	5	25	10	1	0	2	1	0	0	13.971335930312387	160	
i 1	39.99444217687075	0.505	61	398	3	12	6	16	0	2	16	0	0	14.0	160	
i 1	39.99521768707483	1.01	61	949	4	25	16	1	0	1	1	0	0	13.971335930312387	160	
i 1	39.995993197278914	1.01	63	602	5	14	15	1	0	2	1	0	0	14.0	160	
i 1	39.995993197278914	1.01	63	602	5	13	16	16	0	1	16	0	0	13.882378305840126	160	
i 1	39.995993197278914	0.505	63	398	3	27	14	1	0	1	1	0	0	13.971335930312387	160	
i 1	39.996251700680276	1.01	61	602	5	25	12	1	0	2	1	0	0	13.971335930312387	160	
i 1	39.99728571428572	0.505	61	398	3	12	10	16	0	1	16	0	0	14.0	160	
i 1	40.00038775510204	1.01	63	949	4	15	1	16	0	2	16	0	0	14.0	160	
i 1	40.00219727891157	1.01	61	949	4	15	7	1	0	1	1	0	0	14.0	160	
i 1	40.00581632653061	1.01	61	949	4	25	14	1	0	1	1	0	0	13.971335930312387	160	
i 1	40.49470068027211	0.505	61	286	3	12	4	16	0	1	16	0	0	14.0	162	
i 1	40.50219727891157	0.505	63	286	3	12	14	1	0	1	1	0	0	14.0	162	
i 1	40.50271428571428	0.505	61	286	3	27	4	1	0	1	1	0	0	13.971335930312387	162	
i 1	40.50633333333333	0.505	61	286	3	27	3	16	0	1	16	0	0	13.971335930312387	162	
i 1	40.993925170068024	2.02	63	1100	4	25	1	1	0	2	1	0	0	13.971335930312387	164	
i 1	40.995993197278914	2.02	63	398	3	27	4	16	0	1	16	0	0	13.971335930312387	164	
i 1	40.99857823129252	2.02	63	1100	4	14	3	16	0	2	16	0	0	14.0	164	
i 1	40.99857823129252	2.02	63	1100	4	13	2	16	0	2	16	0	0	13.882378305840126	164	
i 1	40.99909523809524	2.02	63	398	3	27	10	16	0	1	16	0	0	13.971335930312387	164	
i 1	40.9993537414966	2.02	61	714	4	25	10	1	0	1	1	0	0	13.971335930312387	164	
i 1	40.99987074829932	2.02	61	714	4	15	11	1	0	1	1	0	0	14.0	164	
i 1	41.001938775510204	2.02	61	398	3	12	2	1	0	1	1	0	0	14.0	164	
i 1	41.00323129251701	2.02	61	398	3	12	1	1	0	2	1	0	0	14.0	164	
i 1	41.00348979591837	2.02	61	714	4	25	7	1	0	1	1	0	0	13.971335930312387	164	
i 1	41.00478231292517	2.02	63	714	4	15	3	1	0	2	1	0	0	14.0	164	
i 1	41.00633333333333	2.02	63	1100	4	25	8	16	0	1	16	0	0	13.971335930312387	164	
i 1	42.99444217687075	1.01	61	216	5	14	14	16	0	1	16	0	0	14.0	172	
i 1	42.99470068027211	1.01	61	1100	2	27	1	1	0	1	1	0	0	13.971335930312387	172	
i 1	42.995993197278914	1.01	63	602	4	15	11	16	0	1	16	0	0	14.0	172	
i 1	42.99728571428572	1.01	63	602	4	25	7	16	0	2	16	0	0	13.971335930312387	172	
i 1	42.99754421768707	1.01	61	1100	2	12	14	1	0	1	1	0	0	14.0	172	
i 1	42.99961224489796	1.01	63	1100	2	27	5	1	0	1	1	0	0	13.971335930312387	172	
i 1	42.99987074829932	1.01	63	216	5	13	1	1	0	2	1	0	0	13.882378305840126	172	
i 1	42.99987074829932	1.01	61	602	4	15	11	1	0	2	1	0	0	14.0	172	
i 1	43.00142176870748	1.01	61	1100	2	12	14	16	0	2	16	0	0	14.0	172	
i 1	43.001938775510204	1.01	61	602	4	25	8	1	0	2	1	0	0	13.971335930312387	172	
i 1	43.00452380952381	1.01	63	216	5	25	7	16	0	1	16	0	0	13.971335930312387	172	
i 1	43.00633333333333	1.01	61	216	5	25	15	16	0	2	16	0	0	13.971335930312387	172	
i 1	43.99366666666667	1.01	61	451	4	15	4	1	0	1	1	0	0	14.0	176	
i 1	43.99495918367347	1.01	61	451	4	15	16	16	0	1	16	0	0	14.0	176	
i 1	43.997027210884355	1.01	63	451	4	25	6	1	0	2	1	0	0	13.971335930312387	176	
i 1	44.00012925170068	1.01	61	451	4	25	14	16	0	1	16	0	0	13.971335930312387	176	
i 1	44.0006462585034	1.01	61	65	5	25	5	1	0	2	1	0	0	13.971335930312387	176	
i 1	44.001938775510204	1.01	61	65	5	13	3	16	0	2	16	0	0	13.882378305840126	176	
i 1	44.00219727891157	1.01	63	65	3	12	15	16	0	2	16	0	0	14.0	176	
i 1	44.00219727891157	1.01	63	65	5	25	13	16	0	1	16	0	0	13.971335930312387	176	
i 1	44.00219727891157	1.01	63	65	3	27	13	1	0	1	1	0	0	13.971335930312387	176	
i 1	44.00555782312925	1.01	61	65	5	14	7	1	0	2	1	0	0	14.0	176	
i 1	44.00555782312925	1.01	61	65	3	27	14	1	0	2	1	0	0	13.971335930312387	176	
i 1	44.006074829931976	1.01	63	65	3	12	4	16	0	2	16	0	0	14.0	176	
i 1	44.49573469387755	1.01	61	905	3	16	2	16	0	1	16	0	0	14.0	178	
i 1	44.495993197278914	1.01	61	905	3	16	4	1	0	1	1	0	0	14.0	178	
i 1	44.497027210884355	1.01	61	905	3	26	16	16	0	1	16	0	0	13.971335930312387	178	
i 1	44.50426530612245	1.01	63	905	3	26	2	1	0	2	1	0	0	13.971335930312387	178	
i 1	44.99418367346939	1.01	63	1087	4	25	3	16	0	1	16	0	0	13.971335930312387	180	
i 1	44.997027210884355	0.505	61	589	4	25	4	16	0	1	16	0	0	13.971335930312387	180	
i 1	44.9993537414966	0.505	63	589	4	15	9	1	0	2	1	0	0	14.0	180	
i 1	45.00038775510204	0.505	61	589	4	25	10	1	0	2	1	0	0	13.971335930312387	180	
i 1	45.001163265306126	0.505	61	589	4	15	2	1	0	1	1	0	0	14.0	180	
i 1	45.00168027210884	1.01	61	1087	4	13	7	16	0	2	16	0	0	13.882378305840126	180	
i 1	45.00323129251701	1.01	61	1087	4	25	15	1	0	1	1	0	0	13.971335930312387	180	
i 1	45.00426530612245	0.505	63	323	3	12	16	16	0	2	16	0	0	14.0	180	
i 1	45.00478231292517	0.505	63	323	3	27	6	16	0	2	16	0	0	13.971335930312387	180	
i 1	45.006074829931976	0.505	63	323	3	12	1	16	0	2	16	0	0	14.0	180	
i 1	45.006074829931976	0.505	61	323	3	27	13	1	0	1	1	0	0	13.971335930312387	180	
i 1	45.00633333333333	1.01	61	1087	4	14	8	1	0	2	1	0	0	14.0	180	
i 1	45.49366666666667	0.505	63	771	4	15	1	1	0	1	1	0	0	14.0	182	
i 1	45.49366666666667	0.505	61	771	4	15	15	16	0	2	16	0	0	14.0	182	
i 1	45.493925170068024	0.505	61	504	3	27	16	1	0	2	1	0	0	13.971335930312387	182	
i 1	45.49444217687075	0.505	61	771	3	26	12	1	0	1	1	0	0	13.971335930312387	182	
i 1	45.49521768707483	0.505	61	504	3	12	16	16	0	2	16	0	0	14.0	182	
i 1	45.49547619047619	0.505	63	504	3	27	9	1	0	1	1	0	0	13.971335930312387	182	
i 1	45.496251700680276	0.505	63	771	4	25	7	16	0	1	16	0	0	13.971335930312387	182	
i 1	45.497027210884355	0.505	61	771	3	16	14	16	0	1	16	0	0	14.0	182	
i 1	45.49831972789116	0.505	61	771	4	25	8	1	0	2	1	0	0	13.971335930312387	182	
i 1	45.498836734693874	0.505	61	771	3	16	9	16	0	2	16	0	0	14.0	182	
i 1	45.50245578231293	0.505	61	504	3	12	9	16	0	2	16	0	0	14.0	182	
i 1	45.50323129251701	0.505	63	771	3	26	8	1	0	2	1	0	0	13.971335930312387	182	
i 1	45.993925170068024	1.01	61	92	4	25	14	16	0	1	16	0	0	13.971335930312387	184	
i 1	45.99444217687075	1.01	63	590	3	12	2	16	0	2	16	0	0	14.0	184	
i 1	45.99470068027211	1.01	63	906	4	14	16	1	0	2	1	0	0	14.0	184	
i 1	45.99470068027211	2.02	63	590	3	26	3	1	0	1	1	0	0	13.971335930312387	184	
i 1	45.99573469387755	1.01	63	906	4	25	1	1	0	2	1	0	0	13.971335930312387	184	
i 1	45.99651020408163	2.02	63	590	3	26	8	16	0	1	16	0	0	13.971335930312387	184	
i 1	45.99780272108843	2.02	61	590	3	16	1	1	0	2	1	0	0	14.0	184	
i 1	45.99831972789116	1.01	61	906	4	25	2	16	0	1	16	0	0	13.971335930312387	184	
i 1	45.99831972789116	1.01	61	590	3	27	5	1	0	1	1	0	0	13.971335930312387	184	
i 1	45.99909523809524	1.01	63	92	4	15	9	1	0	1	1	0	0	14.0	184	
i 1	46.00142176870748	1.01	63	92	4	15	3	1	0	1	1	0	0	14.0	184	
i 1	46.00271428571428	1.01	63	590	3	27	3	1	0	1	1	0	0	13.971335930312387	184	
i 1	46.00504081632653	1.01	63	590	3	12	12	16	0	1	16	0	0	14.0	184	
i 1	46.00555782312925	1.01	63	906	4	13	8	1	0	2	1	0	0	13.882378305840126	184	
i 1	46.00555782312925	2.02	63	590	3	16	12	1	0	2	1	0	0	14.0	184	
i 1	46.00633333333333	1.01	61	92	4	25	9	1	0	2	1	0	0	13.971335930312387	184	
i 1	46.99573469387755	1.01	63	1088	4	25	14	16	0	2	16	0	0	13.971335930312387	188	
i 1	46.99780272108843	2.02	63	590	4	25	7	16	0	1	16	0	0	13.971335930312387	188	
i 1	46.998836734693874	2.02	63	590	4	15	10	1	0	1	1	0	0	14.0	188	
i 1	46.99987074829932	1.01	61	1088	4	13	4	1	0	1	1	0	0	13.882378305840126	188	
i 1	47.001163265306126	1.01	63	274	3	27	6	16	0	1	16	0	0	13.971335930312387	188	
i 1	47.001938775510204	1.01	61	274	3	27	6	16	0	2	16	0	0	13.971335930312387	188	
i 1	47.00219727891157	1.01	63	274	3	12	10	1	0	1	1	0	0	14.0	188	
i 1	47.00219727891157	1.01	63	274	3	12	15	16	0	2	16	0	0	14.0	188	
i 1	47.00323129251701	1.01	61	1088	4	25	9	16	0	1	16	0	0	13.971335930312387	188	
i 1	47.00348979591837	1.01	63	1088	4	14	16	1	0	2	1	0	0	14.0	188	
i 1	47.003748299319724	2.02	61	590	4	15	2	1	0	1	1	0	0	14.0	188	
i 1	47.00529931972789	2.02	61	590	4	25	10	1	0	1	1	0	0	13.971335930312387	188	
i 1	47.99444217687075	0.505	63	386	3	27	9	16	0	2	16	0	0	13.971335930312387	192	
i 1	47.99470068027211	2.02	61	702	4	13	10	16	0	1	16	0	0	13.882378305840126	192	
i 1	47.99521768707483	2.02	61	702	4	25	1	16	0	1	16	0	0	13.971335930312387	192	
i 1	47.995993197278914	0.505	61	702	3	16	3	16	0	1	16	0	0	14.0	192	
i 1	47.99961224489796	0.505	61	386	3	12	13	16	0	1	16	0	0	14.0	192	
i 1	48.001163265306126	0.505	63	386	3	12	6	16	0	1	16	0	0	14.0	192	
i 1	48.00323129251701	0.505	63	702	3	26	14	1	0	1	1	0	0	13.971335930312387	192	
i 1	48.00323129251701	0.505	63	702	3	26	9	16	0	2	16	0	0	13.971335930312387	192	
i 1	48.003748299319724	2.02	63	702	4	25	9	16	0	1	16	0	0	13.971335930312387	192	
i 1	48.00452380952381	0.505	63	702	3	16	2	1	0	2	1	0	0	14.0	192	
i 1	48.00581632653061	2.02	61	702	4	14	2	1	0	2	1	0	0	14.0	192	
i 1	48.00581632653061	0.505	63	386	3	27	6	16	0	2	16	0	0	13.971335930312387	192	
i 1	48.498061224489796	0.505	61	906	3	16	2	1	0	1	1	0	0	14.0	194	
i 1	48.49831972789116	0.505	63	590	3	12	8	16	0	1	16	0	0	14.0	194	
i 1	48.501938775510204	0.505	63	590	3	12	7	1	0	1	1	0	0	14.0	194	
i 1	48.502972789115645	0.505	63	590	3	27	9	16	0	1	16	0	0	13.971335930312387	194	
i 1	48.50478231292517	0.505	63	906	3	16	6	16	0	2	16	0	0	14.0	194	
i 1	48.50504081632653	0.505	61	906	3	26	15	1	0	2	1	0	0	13.971335930312387	194	
i 1	48.50504081632653	0.505	63	590	3	27	10	1	0	1	1	0	0	13.971335930312387	194	
i 1	48.50633333333333	0.505	63	906	3	26	4	1	0	2	1	0	0	13.971335930312387	194	
i 1	48.99470068027211	1.01	63	435	4	25	5	1	0	2	1	0	0	13.971335930312387	196	
i 1	48.99651020408163	0.505	63	702	3	27	13	1	0	2	1	0	0	13.971335930312387	196	
i 1	48.99831972789116	0.505	61	1137	3	26	2	16	0	2	16	0	0	13.971335930312387	196	
i 1	48.99961224489796	0.505	61	1137	3	16	1	16	0	1	16	0	0	14.0	196	
i 1	49.00038775510204	0.505	61	702	3	27	7	1	0	2	1	0	0	13.971335930312387	196	
i 1	49.00168027210884	1.01	63	435	4	15	13	16	0	1	16	0	0	14.0	196	
i 1	49.001938775510204	1.01	63	435	4	15	6	16	0	1	16	0	0	14.0	196	
i 1	49.00219727891157	0.505	61	1137	3	16	2	1	0	1	1	0	0	14.0	196	
i 1	49.00271428571428	0.505	63	702	3	12	7	1	0	2	1	0	0	14.0	196	
i 1	49.00348979591837	0.505	61	1137	3	26	11	16	0	2	16	0	0	13.971335930312387	196	
i 1	49.00452380952381	0.505	61	702	3	12	15	16	0	1	16	0	0	14.0	196	
i 1	49.00504081632653	1.01	63	435	4	25	12	1	0	1	1	0	0	13.971335930312387	196	
i 1	49.49521768707483	0.505	61	119	4	26	4	1	0	2	1	0	0	13.971335930312387	198	
i 1	49.49547619047619	0.505	63	119	4	16	13	16	0	1	16	0	0	14.0	198	
i 1	49.49728571428572	0.505	63	119	4	26	4	1	0	2	1	0	0	13.971335930312387	198	
i 1	49.49961224489796	0.505	61	933	3	12	16	16	0	2	16	0	0	14.0	198	
i 1	49.50090476190476	0.505	61	933	3	27	7	16	0	2	16	0	0	13.971335930312387	198	
i 1	49.50142176870748	0.505	63	119	4	16	1	1	0	1	1	0	0	14.0	198	
i 1	49.50323129251701	0.505	61	933	3	27	2	1	0	2	1	0	0	13.971335930312387	198	
i 1	49.503748299319724	0.505	63	933	3	12	9	16	0	2	16	0	0	14.0	198	
i 1	49.99366666666667	1.01	63	276	4	15	3	16	0	1	16	0	0	14.0	200	
i 1	49.99366666666667	1.01	61	276	4	25	13	1	0	1	1	0	0	13.971335930312387	200	
i 1	49.99521768707483	1.01	61	276	4	16	4	1	0	2	1	0	0	14.0	200	
i 1	49.996251700680276	1.01	63	276	4	16	16	1	0	2	1	0	0	14.0	200	
i 1	49.99651020408163	1.01	63	1090	3	27	14	16	0	2	16	0	0	13.971335930312387	200	
i 1	49.99728571428572	1.01	61	592	4	13	6	1	0	2	1	0	0	13.882378305840126	200	
i 1	49.99780272108843	1.01	63	592	4	25	12	16	0	1	16	0	0	13.971335930312387	200	
i 1	49.99909523809524	1.01	63	592	4	25	2	1	0	1	1	0	0	13.971335930312387	200	
i 1	49.99987074829932	1.01	63	276	4	26	13	16	0	2	16	0	0	13.971335930312387	200	
i 1	49.99987074829932	1.01	61	1090	3	27	11	16	0	1	16	0	0	13.971335930312387	200	
i 1	50.00090476190476	1.01	61	592	4	14	12	16	0	2	16	0	0	14.0	200	
i 1	50.00090476190476	1.01	61	276	4	15	5	16	0	2	16	0	0	14.0	200	
i 1	50.00142176870748	1.01	61	1090	3	12	15	16	0	2	16	0	0	14.0	200	
i 1	50.00271428571428	1.01	61	276	4	26	12	16	0	2	16	0	0	13.971335930312387	200	
i 1	50.00452380952381	1.01	63	276	4	25	3	1	0	2	1	0	0	13.971335930312387	200	
i 1	50.00478231292517	1.01	63	1090	3	12	10	1	0	2	1	0	0	14.0	200	
i 1	50.99444217687075	2.02	63	206	4	15	11	16	0	1	16	0	0	14.0	204	
i 1	50.99573469387755	2.02	63	704	3	27	6	1	0	2	1	0	0	13.971335930312387	204	
i 1	50.995993197278914	0.505	61	1090	3	26	16	16	0	2	16	0	0	13.971335930312387	204	
i 1	50.99676870748299	0.505	63	1090	3	16	6	1	0	1	1	0	0	14.0	204	
i 1	50.99831972789116	0.505	61	1090	3	26	8	16	0	2	16	0	0	13.971335930312387	204	
i 1	50.998836734693874	2.02	63	704	3	27	15	16	0	2	16	0	0	13.971335930312387	204	
i 1	50.99961224489796	1.01	61	1090	4	25	15	16	0	1	16	0	0	13.971335930312387	204	
i 1	51.00142176870748	0.505	63	1090	3	16	4	1	0	1	1	0	0	14.0	204	
i 1	51.00168027210884	1.01	63	1090	4	14	3	16	0	2	16	0	0	14.0	204	
i 1	51.00219727891157	2.02	63	704	3	12	11	16	0	1	16	0	0	14.0	204	
i 1	51.00219727891157	1.01	63	1090	4	25	9	1	0	2	1	0	0	13.971335930312387	204	
i 1	51.00271428571428	2.02	61	206	4	15	13	1	0	2	1	0	0	14.0	204	
i 1	51.004006802721086	2.02	61	704	3	12	16	16	0	1	16	0	0	14.0	204	
i 1	51.004006802721086	2.02	63	206	4	25	5	1	0	1	1	0	0	13.971335930312387	204	
i 1	51.00452380952381	2.02	63	206	4	25	12	1	0	1	1	0	0	13.971335930312387	204	
i 1	51.006074829931976	1.01	63	1090	4	13	6	16	0	1	16	0	0	13.882378305840126	204	
i 1	51.501163265306126	0.2525	63	55	4	16	8	1	0	1	1	0	0	14.0	206	
i 1	51.50142176870748	0.2525	61	55	4	26	5	16	0	2	16	0	0	13.971335930312387	206	
i 1	51.501938775510204	0.2525	63	55	4	16	13	16	0	1	16	0	0	14.0	206	
i 1	51.50426530612245	0.2525	63	55	4	26	5	16	0	2	16	0	0	13.971335930312387	206	
i 1	51.747027210884355	0.2525	61	206	4	16	14	16	0	2	16	0	0	14.0	207	
i 1	51.74831972789116	0.2525	63	206	4	26	14	1	0	2	1	0	0	13.971335930312387	207	
i 1	51.7493537414966	0.2525	61	206	4	16	8	1	0	2	1	0	0	14.0	207	
i 1	51.74987074829932	0.2525	63	206	4	26	5	1	0	2	1	0	0	13.971335930312387	207	
i 1	51.99366666666667	1.01	61	908	4	13	14	16	0	2	16	0	0	13.882378305840126	208	
i 1	51.99651020408163	1.01	63	55	4	16	3	16	0	2	16	0	0	14.0	208	
i 1	51.99651020408163	1.01	63	55	4	26	5	16	0	1	16	0	0	13.971335930312387	208	
i 1	51.9993537414966	1.01	63	55	4	16	3	1	0	1	1	0	0	14.0	208	
i 1	51.99961224489796	1.01	63	908	4	25	7	1	0	1	1	0	0	13.971335930312387	208	
i 1	52.00090476190476	1.01	63	908	4	14	3	16	0	2	16	0	0	14.0	208	
i 1	52.00323129251701	1.01	63	55	4	26	5	1	0	1	1	0	0	13.971335930312387	208	
i 1	52.00504081632653	1.01	63	908	4	25	10	1	0	1	1	0	0	13.971335930312387	208	
i 1	52.99444217687075	0.505	63	206	4	26	14	1	0	1	1	0	0	13.971335930312387	212	
i 1	52.99470068027211	2.02	61	908	4	25	14	1	0	2	1	0	0	13.971335930312387	212	
i 1	52.99495918367347	2.02	61	206	5	14	4	16	0	2	16	0	0	14.0	212	
i 1	52.99521768707483	2.02	61	908	4	25	8	1	0	1	1	0	0	13.971335930312387	212	
i 1	52.99521768707483	0.505	61	592	3	27	5	1	0	1	1	0	0	13.971335930312387	212	
i 1	52.99573469387755	0.505	61	206	4	16	12	1	0	2	1	0	0	14.0	212	
i 1	52.995993197278914	0.505	61	206	4	16	14	1	0	2	1	0	0	14.0	212	
i 1	52.99676870748299	0.505	63	592	3	12	9	16	0	2	16	0	0	14.0	212	
i 1	52.99728571428572	0.505	61	206	4	26	8	16	0	2	16	0	0	13.971335930312387	212	
i 1	52.99754421768707	0.505	63	592	3	27	7	16	0	1	16	0	0	13.971335930312387	212	
i 1	52.998061224489796	2.02	61	206	5	25	1	16	0	2	16	0	0	13.971335930312387	212	
i 1	52.99857823129252	2.02	61	206	5	13	8	16	0	2	16	0	0	13.882378305840126	212	
i 1	52.99987074829932	0.505	61	592	3	12	7	1	0	1	1	0	0	14.0	212	
i 1	53.001163265306126	2.02	61	908	4	15	3	16	0	1	16	0	0	14.0	212	
i 1	53.00219727891157	2.02	61	908	4	15	10	1	0	1	1	0	0	14.0	212	
i 1	53.00245578231293	2.02	61	206	5	25	12	1	0	2	1	0	0	13.971335930312387	212	
i 1	53.49676870748299	0.505	61	704	3	12	13	16	0	2	16	0	0	14.0	214	
i 1	53.49676870748299	0.505	63	357	4	26	10	16	0	1	16	0	0	13.971335930312387	214	
i 1	53.50038775510204	0.505	61	357	4	16	14	16	0	1	16	0	0	14.0	214	
i 1	53.50038775510204	0.505	63	704	3	27	11	1	0	2	1	0	0	13.971335930312387	214	
i 1	53.501938775510204	0.505	63	357	4	16	6	16	0	2	16	0	0	14.0	214	
i 1	53.504006802721086	0.505	63	357	4	26	4	16	0	1	16	0	0	13.971335930312387	214	
i 1	53.50529931972789	0.505	63	704	3	27	4	1	0	1	1	0	0	13.971335930312387	214	
i 1	53.50633333333333	0.505	61	704	3	12	12	1	0	1	1	0	0	14.0	214	
i 1	53.99366666666667	1.01	61	592	4	16	6	1	0	1	1	0	0	14.0	216	
i 1	53.99780272108843	1.01	63	908	3	12	1	16	0	2	16	0	0	14.0	216	
i 1	53.99987074829932	1.01	63	592	4	26	15	1	0	2	1	0	0	13.971335930312387	216	
i 1	54.00142176870748	1.01	61	908	3	27	7	1	0	2	1	0	0	13.971335930312387	216	
i 1	54.00168027210884	1.01	63	908	3	12	4	1	0	1	1	0	0	14.0	216	
i 1	54.003748299319724	1.01	63	592	4	16	1	1	0	1	1	0	0	14.0	216	
i 1	54.00426530612245	1.01	61	908	3	27	4	1	0	2	1	0	0	13.971335930312387	216	
i 1	54.00478231292517	1.01	63	592	4	26	14	1	0	2	1	0	0	13.971335930312387	216	
i 1	54.99470068027211	1.01	63	95	5	25	16	16	0	1	16	0	0	13.971335930312387	220	
i 1	54.99754421768707	1.01	61	410	4	16	7	1	0	1	1	0	0	14.0	220	
i 1	54.99857823129252	1.01	61	95	5	25	7	16	0	1	16	0	0	13.971335930312387	220	
i 1	54.99961224489796	1.01	63	908	2	12	11	16	0	2	16	0	0	14.0	220	
i 1	55.0006462585034	1.01	63	908	2	12	8	1	0	1	1	0	0	14.0	220	
i 1	55.001163265306126	1.01	61	95	5	14	1	1	0	2	1	0	0	14.0	220	
i 1	55.001163265306126	1.01	61	908	2	27	4	1	0	2	1	0	0	13.971335930312387	220	
i 1	55.00219727891157	1.01	63	677	4	25	16	1	0	2	1	0	0	13.971335930312387	220	
i 1	55.00323129251701	1.01	63	410	4	26	11	1	0	2	1	0	0	13.971335930312387	220	
i 1	55.004006802721086	1.01	61	677	4	15	1	16	0	1	16	0	0	14.0	220	
i 1	55.004006802721086	1.01	61	410	4	26	14	1	0	2	1	0	0	13.971335930312387	220	
i 1	55.00426530612245	1.01	63	677	4	15	6	1	0	1	1	0	0	14.0	220	
i 1	55.00529931972789	1.01	61	908	2	27	16	1	0	2	1	0	0	13.971335930312387	220	
i 1	55.00581632653061	1.01	63	677	4	25	4	16	0	1	16	0	0	13.971335930312387	220	
i 1	55.006074829931976	1.01	63	95	5	13	15	1	0	1	1	0	0	13.882378305840126	220	
i 1	55.006074829931976	1.01	61	410	4	16	13	1	0	2	1	0	0	14.0	220	
i 1	55.993925170068024	1.01	61	201	5	25	8	1	0	2	1	0	0	13.971335930312387	224	
i 1	55.99470068027211	1.01	61	201	5	14	10	16	0	2	16	0	0	14.0	224	
i 1	55.99573469387755	2.02	61	201	3	12	3	16	0	2	16	0	0	14.0	224	
i 1	55.99573469387755	2.02	63	201	3	12	16	16	0	1	16	0	0	14.0	224	
i 1	55.99573469387755	2.02	63	587	4	25	6	16	0	2	16	0	0	13.971335930312387	224	
i 1	55.996251700680276	2.02	61	587	4	15	8	16	0	2	16	0	0	14.0	224	
i 1	55.99728571428572	2.02	61	201	4	16	6	1	0	2	1	0	0	14.0	224	
i 1	55.99728571428572	1.01	61	201	5	25	2	16	0	1	16	0	0	13.971335930312387	224	
i 1	55.998061224489796	2.02	63	587	4	15	9	16	0	2	16	0	0	14.0	224	
i 1	55.9993537414966	2.02	61	201	4	26	6	16	0	2	16	0	0	13.971335930312387	224	
i 1	56.00012925170068	2.02	61	201	3	27	9	16	0	1	16	0	0	13.971335930312387	224	
i 1	56.00012925170068	2.02	63	201	3	27	6	1	0	1	1	0	0	13.971335930312387	224	
i 1	56.001163265306126	2.02	61	201	4	16	16	1	0	1	1	0	0	14.0	224	
i 1	56.00504081632653	2.02	61	587	4	25	12	16	0	2	16	0	0	13.971335930312387	224	
i 1	56.00504081632653	2.02	61	201	4	26	13	16	0	2	16	0	0	13.971335930312387	224	
i 1	56.006074829931976	1.01	61	201	5	13	2	1	0	2	1	0	0	13.882378305840126	224	
i 1	56.99521768707483	1.01	63	903	4	13	8	1	0	1	1	0	0	13.882378305840126	228	
i 1	56.997027210884355	1.01	61	903	4	25	2	1	0	2	1	0	0	13.971335930312387	228	
i 1	57.00142176870748	1.01	63	903	4	25	14	1	0	2	1	0	0	13.971335930312387	228	
i 1	57.00245578231293	1.01	63	903	4	14	11	16	0	2	16	0	0	14.0	228	
i 1	57.99418367346939	1.01	63	201	4	12	6	16	0	1	16	0	0	14.0	232	
i 1	57.99444217687075	2.02	61	433	4	15	7	16	5000	1	16	0	0	14.0	232	
i 1	57.996251700680276	1.01	61	1135	4	13	14	1	0	1	1	0	0	13.882378305840126	232	
i 1	57.99831972789116	1.01	61	819	3	16	8	16	0	1	16	0	0	14.0	232	
i 1	57.998836734693874	1.01	61	819	3	26	12	1	0	2	1	0	0	13.971335930312387	232	
i 1	57.99961224489796	1.01	61	201	4	27	12	16	0	1	16	0	0	13.971335930312387	232	
i 1	57.99987074829932	2.02	63	433	4	15	7	16	5000	2	16	0	0	14.0	232	
i 1	57.99987074829932	1.01	63	201	4	27	16	1	0	1	1	0	0	13.971335930312387	232	
i 1	58.0006462585034	2.02	61	433	4	25	13	16	5000	1	16	0	0	13.971335930312387	232	
i 1	58.00090476190476	1.01	61	201	4	12	5	16	0	2	16	0	0	14.0	232	
i 1	58.001163265306126	1.01	63	1135	4	25	14	16	0	1	16	0	0	13.971335930312387	232	
i 1	58.00219727891157	1.01	63	1135	4	14	16	16	0	1	16	0	0	14.0	232	
i 1	58.00271428571428	1.01	63	819	3	16	13	16	0	1	16	0	0	14.0	232	
i 1	58.002972789115645	1.01	63	819	3	26	3	16	0	2	16	0	0	13.971335930312387	232	
i 1	58.00478231292517	1.01	61	1135	4	25	2	16	0	1	16	0	0	13.971335930312387	232	
i 1	58.00529931972789	2.02	61	433	4	25	7	16	5000	1	16	0	0	13.971335930312387	232	
i 1	58.993925170068024	1.01	61	116	5	25	4	1	0	1	1	0	0	13.971335930312387	236	
i 1	58.99573469387755	1.01	61	1049	3	16	2	1	0	1	1	0	0	14.0	236	
i 1	58.99573469387755	1.01	63	116	4	12	8	1	0	2	1	0	0	14.0	236	
i 1	58.99676870748299	1.01	61	116	4	12	7	1	0	2	1	0	0	14.0	236	
i 1	58.99780272108843	1.01	61	116	5	14	16	1	0	2	1	0	0	14.0	236	
i 1	58.99909523809524	1.01	63	1049	3	26	11	16	0	2	16	0	0	13.971335930312387	236	
i 1	59.00245578231293	1.01	61	116	4	27	12	16	0	2	16	0	0	13.971335930312387	236	
i 1	59.004006802721086	1.01	61	116	5	13	5	16	0	1	16	0	0	13.882378305840126	236	
i 1	59.00504081632653	1.01	63	116	5	25	10	1	0	1	1	0	0	13.971335930312387	236	
i 1	59.00555782312925	1.01	63	1049	3	16	8	16	0	1	16	0	0	14.0	236	
i 1	59.00581632653061	1.01	63	1049	3	26	2	1	0	2	1	0	0	13.971335930312387	236	
i 1	59.00581632653061	1.01	63	116	4	27	10	16	0	1	16	0	0	13.971335930312387	236	
i 1	59.993925170068024	0.505	61	207	5	25	16	1	0	2	1	0	0	13.971335930312387	240	
i 1	59.99418367346939	1.5150000000000001	63	1091	3	12	8	16	0	1	16	0	0	14.0	240	
i 1	59.99444217687075	1.01	63	207	4	15	1	16	0	1	16	0	0	14.0	240	
i 1	59.99444217687075	0.505	61	1091	3	16	5	16	0	1	16	0	0	14.0	240	
i 1	59.99651020408163	0.505	61	1091	3	16	13	1	0	2	1	0	0	14.0	240	
i 1	59.99676870748299	0.505	61	1091	3	26	8	16	0	1	16	0	0	13.971335930312387	240	
i 1	59.998061224489796	0.505	61	207	5	25	16	16	0	1	16	0	0	13.971335930312387	240	
i 1	59.9993537414966	1.5150000000000001	61	1091	3	12	3	16	0	2	16	0	0	14.0	240	
i 1	60.001938775510204	1.01	61	207	4	15	12	1	0	1	1	0	0	14.0	240	
i 1	60.001938775510204	1.01	61	207	4	25	12	16	0	1	16	0	0	13.971335930312387	240	
i 1	60.00348979591837	0.505	61	207	5	14	6	16	0	2	16	0	0	14.0	240	
i 1	60.003748299319724	1.5150000000000001	63	1091	3	27	15	1	0	2	1	0	0	13.971335930312387	240	
i 1	60.00452380952381	0.505	63	1091	3	26	9	1	0	2	1	0	0	13.971335930312387	240	
i 1	60.00478231292517	0.505	63	207	5	13	6	1	0	1	1	0	0	13.882378305840126	240	
i 1	60.00581632653061	1.01	61	207	4	25	9	1	0	1	1	0	0	13.971335930312387	240	
i 1	60.00581632653061	1.5150000000000001	61	1091	3	27	3	1	0	1	1	0	0	13.971335930312387	240	
i 1	60.49366666666667	0.505	63	108	4	16	5	1	0	1	1	0	0	14.0	242	
i 1	60.49495918367347	0.505	61	108	4	26	11	1	0	2	1	0	0	13.971335930312387	242	
i 1	60.49728571428572	0.505	61	389	5	14	1	16	0	1	16	0	0	14.0	242	
i 1	60.49754421768707	0.505	61	108	4	26	2	16	0	2	16	0	0	13.971335930312387	242	
i 1	60.50012925170068	0.505	61	108	4	16	8	1	0	2	1	0	0	14.0	242	
i 1	60.5006462585034	0.505	63	389	5	13	12	1	0	1	1	0	0	13.882378305840126	242	
i 1	60.50478231292517	0.505	61	389	5	25	12	1	0	1	1	0	0	13.971335930312387	242	
i 1	60.50504081632653	0.505	61	389	5	25	9	1	0	2	1	0	0	13.971335930312387	242	
i 1	60.99521768707483	2.02	63	207	4	26	5	1	0	1	1	0	0	13.971335930312387	244	
i 1	60.99573469387755	2.02	63	593	5	13	5	1	0	1	1	0	0	13.882378305840126	244	
i 1	60.995993197278914	0.505	61	207	5	25	2	16	0	1	16	0	0	13.971335930312387	244	
i 1	60.99651020408163	2.02	63	593	5	14	10	16	0	2	16	0	0	14.0	244	
i 1	60.998836734693874	0.505	61	207	5	15	14	1	0	1	1	0	0	14.0	244	
i 1	60.998836734693874	0.505	61	207	5	25	4	1	0	1	1	0	0	13.971335930312387	244	
i 1	61.00038775510204	2.02	61	207	4	26	4	1	0	2	1	0	0	13.971335930312387	244	
i 1	61.00168027210884	2.02	63	207	4	16	14	16	0	2	16	0	0	14.0	244	
i 1	61.00271428571428	2.02	63	593	5	25	11	1	0	2	1	0	0	13.971335930312387	244	
i 1	61.00529931972789	0.505	63	207	5	15	10	16	0	1	16	0	0	14.0	244	
i 1	61.00529931972789	2.02	63	593	5	25	3	16	0	2	16	0	0	13.971335930312387	244	
i 1	61.00581632653061	2.02	63	207	4	16	8	1	0	1	1	0	0	14.0	244	
i 1	61.49418367346939	0.505	61	95	5	25	6	16	0	2	16	0	0	13.971335930312387	246	
i 1	61.498836734693874	0.505	61	95	5	15	4	16	0	2	16	0	0	14.0	246	
i 1	61.49961224489796	0.505	61	909	3	12	11	16	0	1	16	0	0	14.0	246	
i 1	61.501938775510204	0.505	61	909	3	12	6	16	0	2	16	0	0	14.0	246	
i 1	61.50219727891157	0.505	63	95	5	25	14	16	0	2	16	0	0	13.971335930312387	246	
i 1	61.50271428571428	0.505	61	95	5	15	11	1	0	2	1	0	0	14.0	246	
i 1	61.50323129251701	0.505	61	909	3	27	16	1	0	2	1	0	0	13.971335930312387	246	
i 1	61.50452380952381	0.505	63	909	3	27	5	1	0	1	1	0	0	13.971335930312387	246	
i 1	61.99418367346939	0.505	61	705	3	12	8	16	0	1	16	0	0	14.0	248	
i 1	61.995993197278914	0.505	61	1091	4	25	1	1	0	1	1	0	0	13.971335930312387	248	
i 1	61.995993197278914	0.505	63	1091	4	25	5	16	0	1	16	0	0	13.971335930312387	248	
i 1	61.99728571428572	0.505	63	705	3	12	14	1	0	2	1	0	0	14.0	248	
i 1	61.998836734693874	0.505	61	705	3	27	9	16	0	1	16	0	0	13.971335930312387	248	
i 1	62.001938775510204	0.505	63	705	3	27	8	1	0	2	1	0	0	13.971335930312387	248	
i 1	62.004006802721086	0.505	61	1091	4	15	8	1	0	2	1	0	0	14.0	248	
i 1	62.00581632653061	0.505	61	1091	4	15	5	1	0	2	1	0	0	14.0	248	
i 1	62.49366666666667	0.505	63	1047	4	25	16	1	0	1	1	0	0	13.971335930312387	250	
i 1	62.49495918367347	0.505	61	593	3	27	11	1	0	1	1	0	0	13.971335930312387	250	
i 1	62.49728571428572	0.505	63	593	3	12	15	16	0	1	16	0	0	14.0	250	
i 1	62.49728571428572	0.505	61	593	3	27	1	16	0	2	16	0	0	13.971335930312387	250	
i 1	62.49909523809524	0.505	61	593	3	12	4	1	0	1	1	0	0	14.0	250	
i 1	62.50168027210884	0.505	63	1047	4	15	7	1	0	1	1	0	0	14.0	250	
i 1	62.503748299319724	0.505	61	1047	4	15	10	16	0	2	16	0	0	14.0	250	
i 1	62.504006802721086	0.505	63	1047	4	25	2	16	0	2	16	0	0	13.971335930312387	250	
i 1	62.99418367346939	2.02	63	133	4	26	15	16	0	1	16	0	0	13.971335930312387	252	
i 1	62.99418367346939	2.02	63	133	4	26	3	16	0	2	16	0	0	13.971335930312387	252	
i 1	62.99495918367347	1.01	61	400	5	25	9	1	0	2	1	0	0	13.971335930312387	252	
i 1	62.99547619047619	2.02	63	133	4	16	8	1	0	2	1	0	0	14.0	252	
i 1	62.99547619047619	0.505	61	715	3	12	4	1	0	2	1	0	0	14.0	252	
i 1	62.99573469387755	1.01	63	400	5	13	6	1	0	1	1	0	0	13.882378305840126	252	
i 1	62.99831972789116	0.505	63	1102	4	15	10	1	0	1	1	0	0	14.0	252	
i 1	62.99831972789116	0.505	63	715	3	27	3	16	0	1	16	0	0	13.971335930312387	252	
i 1	62.99857823129252	0.505	61	1102	4	25	9	1	0	1	1	0	0	13.971335930312387	252	
i 1	62.99961224489796	1.01	63	400	5	14	15	16	0	2	16	0	0	14.0	252	
i 1	62.99961224489796	0.505	61	715	3	12	1	16	0	1	16	0	0	14.0	252	
i 1	63.00038775510204	1.01	63	400	5	25	7	16	0	2	16	0	0	13.971335930312387	252	
i 1	63.00271428571428	2.02	63	133	4	16	12	1	0	1	1	0	0	14.0	252	
i 1	63.002972789115645	0.505	61	1102	4	25	3	16	0	1	16	0	0	13.971335930312387	252	
i 1	63.002972789115645	0.505	61	715	3	27	6	16	0	2	16	0	0	13.971335930312387	252	
i 1	63.00452380952381	0.505	63	1102	4	15	5	1	0	2	1	0	0	14.0	252	
i 1	63.49366666666667	0.505	63	400	3	27	15	1	0	2	1	0	0	13.971335930312387	254	
i 1	63.495993197278914	0.505	61	400	3	12	10	1	0	2	1	0	0	14.0	254	
i 1	63.496251700680276	0.505	61	400	3	27	14	1	0	2	1	0	0	13.971335930312387	254	
i 1	63.49651020408163	0.505	61	133	5	25	16	1	0	1	1	0	0	13.971335930312387	254	
i 1	63.49754421768707	0.505	63	133	5	15	1	1	0	1	1	0	0	14.0	254	
i 1	63.50142176870748	0.505	63	133	5	15	15	1	0	2	1	0	0	14.0	254	
i 1	63.50245578231293	0.505	63	400	3	12	1	16	0	1	16	0	0	14.0	254	
i 1	63.50504081632653	0.505	63	133	5	25	11	1	0	2	1	0	0	13.971335930312387	254	
i 1	63.99366666666667	1.01	63	631	3	12	3	16	0	1	16	0	0	14.0	256	
i 1	63.99521768707483	1.01	61	1017	4	15	3	16	0	1	16	0	0	14.0	256	
i 1	63.99676870748299	1.01	63	399	5	25	3	1	0	2	1	0	0	13.971335930312387	256	
i 1	63.997027210884355	1.01	61	399	5	25	3	1	0	2	1	0	0	13.971335930312387	256	
i 1	63.997027210884355	1.01	61	631	3	27	13	1	0	2	1	0	0	13.971335930312387	256	
i 1	63.99987074829932	1.01	61	1017	4	25	16	16	0	1	16	0	0	13.971335930312387	256	
i 1	64.0006462585034	1.01	63	399	5	14	4	1	0	1	1	0	0	14.0	256	
i 1	64.00116326530612	1.01	63	1017	4	15	9	1	0	1	1	0	0	14.0	256	
i 1	64.00219727891157	1.01	63	399	5	13	3	16	0	1	16	0	0	13.882378305840126	256	
i 1	64.00245578231292	1.01	61	631	3	12	8	16	0	2	16	0	0	14.0	256	
i 1	64.0045238095238	1.01	63	1017	4	25	5	16	0	2	16	0	0	13.971335930312387	256	
i 1	64.0058163265306	1.01	63	631	3	27	4	1	0	1	1	0	0	13.971335930312387	256	
i 1	64.99366666666667	2.02	63	1077	3	26	9	1	0	2	1	0	0	13.971335930312387	260	
i 1	64.9947006802721	0.505	61	1077	4	15	2	1	0	1	1	0	0	14.0	260	
i 1	64.99521768707483	0.505	61	691	3	27	3	16	0	2	16	0	0	13.971335930312387	260	
i 1	64.99573469387755	2.02	63	1077	3	16	1	1	0	1	1	0	0	14.0	260	
i 1	65.00012925170068	1.01	61	193	5	14	4	1	0	2	1	0	0	14.0	260	
i 1	65.00012925170068	1.01	61	193	5	25	4	16	0	1	16	0	0	13.971335930312387	260	
i 1	65.00090476190476	0.505	61	691	3	27	15	1	0	1	1	0	0	13.971335930312387	260	
i 1	65.00116326530612	0.505	63	691	3	12	1	16	0	2	16	0	0	14.0	260	
i 1	65.00219727891157	0.505	63	1077	4	25	6	16	0	1	16	0	0	13.971335930312387	260	
i 1	65.00271428571429	1.01	63	193	5	25	11	16	0	1	16	0	0	13.971335930312387	260	
i 1	65.00374829931972	2.02	61	1077	3	16	10	16	0	2	16	0	0	14.0	260	
i 1	65.00374829931972	2.02	63	1077	3	26	16	1	0	1	1	0	0	13.971335930312387	260	
i 1	65.00426530612245	0.505	61	1077	4	15	15	1	0	2	1	0	0	14.0	260	
i 1	65.0045238095238	0.505	61	1077	4	25	15	16	0	1	16	0	0	13.971335930312387	260	
i 1	65.00504081632653	1.01	61	193	5	13	1	1	0	2	1	0	0	13.882378305840126	260	
i 1	65.0052993197279	0.505	63	691	3	12	11	16	0	2	16	0	0	14.0	260	
i 1	65.49625170068028	0.505	61	579	3	12	6	1	0	1	1	0	0	14.0	262	
i 1	65.496768707483	0.505	61	579	3	27	13	16	0	1	16	0	0	13.971335930312387	262	
i 1	65.49754421768708	0.505	61	895	4	25	9	1	0	2	1	0	0	13.971335930312387	262	
i 1	65.50168027210884	0.505	63	895	4	15	4	1	0	2	1	0	0	14.0	262	
i 1	65.50168027210884	0.505	61	579	3	12	12	1	0	2	1	0	0	14.0	262	
i 1	65.5045238095238	0.505	63	895	4	25	16	1	0	1	1	0	0	13.971335930312387	262	
i 1	65.50607482993198	0.505	63	895	4	15	16	16	0	1	16	0	0	14.0	262	
i 1	65.50607482993198	0.505	63	579	3	27	16	1	0	1	1	0	0	13.971335930312387	262	
i 1	65.99366666666667	1.5150000000000001	61	109	5	25	5	16	0	2	16	0	0	13.971335930312387	264	
i 1	65.9941836734694	1.01	61	691	4	25	15	16	0	1	16	0	0	13.971335930312387	264	
i 1	65.99444217687075	1.01	63	691	4	15	12	1	0	2	1	0	0	14.0	264	
i 1	65.99702721088435	1.5150000000000001	61	109	5	13	15	1	0	2	1	0	0	13.882378305840126	264	
i 1	65.99780272108843	1.01	63	691	4	25	16	16	0	2	16	0	0	13.971335930312387	264	
i 1	65.99857823129251	1.01	61	375	3	12	5	1	0	1	1	0	0	14.0	264	
i 1	65.99857823129251	1.01	61	375	3	27	11	16	0	1	16	0	0	13.971335930312387	264	
i 1	65.99909523809524	1.01	61	375	3	12	1	16	0	1	16	0	0	14.0	264	
i 1	65.99987074829932	1.01	61	691	4	15	16	16	0	2	16	0	0	14.0	264	
i 1	66.003231292517	1.5150000000000001	61	109	5	25	11	1	0	2	1	0	0	13.971335930312387	264	
i 1	66.0040068027211	1.01	61	375	3	27	5	1	0	1	1	0	0	13.971335930312387	264	
i 1	66.00478231292517	1.5150000000000001	63	109	5	14	6	1	0	2	1	0	0	14.0	264	
i 1	66.9941836734694	1.01	61	607	3	12	12	1	0	2	1	0	0	14.0	268	
i 1	66.9941836734694	1.01	61	993	3	26	11	16	0	1	16	0	0	13.971335930312387	268	
i 1	66.99625170068028	1.01	63	993	3	16	1	1	0	2	1	0	0	14.0	268	
i 1	66.99754421768708	1.01	63	993	3	26	1	16	0	2	16	0	0	13.971335930312387	268	
i 1	66.9980612244898	1.01	63	607	3	12	10	1	0	2	1	0	0	14.0	268	
i 1	67.00012925170068	0.505	61	607	4	15	10	16	0	2	16	0	0	14.0	268	
i 1	67.0019387755102	1.01	63	607	3	27	1	16	0	2	16	0	0	13.971335930312387	268	
i 1	67.00348979591837	1.01	63	607	3	27	2	16	0	1	16	0	0	13.971335930312387	268	
i 1	67.0040068027211	1.01	61	993	3	16	3	16	0	2	16	0	0	14.0	268	
i 1	67.00478231292517	0.505	63	607	4	25	9	16	0	2	16	0	0	13.971335930312387	268	
i 1	67.00607482993198	0.505	63	607	4	15	6	16	0	1	16	0	0	14.0	268	
i 1	67.00633333333333	0.505	63	607	4	25	11	16	0	1	16	0	0	13.971335930312387	268	
i 1	67.4941836734694	0.505	61	108	5	25	16	16	0	2	16	0	0	13.971335930312387	270	
i 1	67.4947006802721	0.505	63	375	4	15	10	1	0	1	1	0	0	14.0	270	
i 1	67.49521768707483	0.505	61	108	5	14	5	16	0	2	16	0	0	14.0	270	
i 1	67.49754421768708	0.505	63	108	5	25	4	16	0	2	16	0	0	13.971335930312387	270	
i 1	67.50090476190476	0.505	61	375	4	25	15	16	0	1	16	0	0	13.971335930312387	270	
i 1	67.5040068027211	0.505	63	375	4	25	5	16	0	2	16	0	0	13.971335930312387	270	
i 1	67.50478231292517	0.505	63	108	5	13	5	1	0	1	1	0	0	13.882378305840126	270	
i 1	67.50607482993198	0.505	61	375	4	15	10	16	0	1	16	0	0	14.0	270	
i 1	67.99573469387755	2.02	61	1112	2	27	3	1	0	1	1	0	0	13.971335930312387	272	
i 1	67.996768707483	2.02	61	1112	2	27	8	1	0	1	1	0	0	13.971335930312387	272	
i 1	67.99987074829932	2.02	61	1112	3	26	3	1	0	2	1	0	0	13.971335930312387	272	
i 1	68.00038775510204	2.02	61	1112	2	12	7	16	0	1	16	0	0	14.0	272	
i 1	68.0006462585034	2.02	63	298	4	25	7	1	0	1	1	0	0	13.971335930312387	272	
i 1	68.00142176870749	2.02	61	298	4	15	9	16	0	2	16	0	0	14.0	272	
i 1	68.00219727891157	2.02	61	1112	4	25	10	16	0	2	16	0	0	13.971335930312387	272	
i 1	68.00297278911565	2.02	61	1112	3	16	6	16	0	1	16	0	0	14.0	272	
i 1	68.00297278911565	2.02	61	1112	3	16	5	1	0	2	1	0	0	14.0	272	
i 1	68.00348979591837	2.02	63	1112	2	12	6	1	0	2	1	0	0	14.0	272	
i 1	68.00478231292517	2.02	63	298	4	25	7	16	0	1	16	0	0	13.971335930312387	272	
i 1	68.00504081632653	2.02	63	298	4	15	10	1	0	1	1	0	0	14.0	272	
i 1	68.0052993197279	2.02	63	1112	3	26	16	16	0	2	16	0	0	13.971335930312387	272	
i 1	68.00607482993198	2.02	63	1112	4	13	15	16	0	1	16	0	0	13.882378305840126	272	
i 1	68.00633333333333	2.02	61	1112	4	14	15	16	0	2	16	0	0	14.0	272	
i 1	68.00633333333333	2.02	61	1112	4	25	8	16	0	2	16	0	0	13.971335930312387	272	
t0 38
</CsScore>
</CsoundSynthesizer>

