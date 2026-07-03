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

f5000.0 0.0 256.0 -6.0 1.0 128.0 1.004351 128.0 1.008702 
f5001.0 0.0 256.0 -6.0 1.0 128.0 0.99827 128.0 0.99654 
f5002.0 0.0 256.0 -6.0 1.0 128.0 1.0060055 128.0 1.012011 
f5003.0 0.0 256.0 -6.0 1.0 128.0 0.9916940000000001 128.0 0.983388 
f5004.0 0.0 256.0 -6.0 1.0 128.0 1.0052254999999999 128.0 1.010451 
f5005.0 0.0 256.0 -6.0 1.0 128.0 0.9968330000000001 128.0 0.993666 
f5006.0 0.0 256.0 -6.0 1.0 128.0 0.9956864999999999 128.0 0.991373 
f5007.0 0.0 256.0 -6.0 1.0 128.0 1.006102 128.0 1.012204 
f5008.0 0.0 256.0 -6.0 1.0 128.0 0.99712 128.0 0.99424 
f5009.0 0.0 256.0 -6.0 1.0 128.0 0.9994225 128.0 0.998845 
f5010.0 0.0 256.0 -6.0 1.0 128.0 0.9965459999999999 128.0 0.993092 
f5011.0 0.0 256.0 -6.0 1.0 128.0 1.0013495 128.0 1.002699 
f5012.0 0.0 256.0 -6.0 1.0 128.0 0.9978865 128.0 0.995773 
f5013.0 0.0 256.0 -6.0 1.0 128.0 1.0003440000000001 128.0 1.000688 
f5014.0 0.0 256.0 -6.0 1.0 128.0 1.0038155 128.0 1.007631 
f5015.0 0.0 256.0 -6.0 1.0 128.0 0.9940175 128.0 0.988035 
f5016.0 0.0 256.0 -6.0 1.0 128.0 0.994658 128.0 0.989316 
f5017.0 0.0 256.0 -6.0 1.0 128.0 1.000648 128.0 1.001296 
f5018.0 0.0 256.0 -6.0 1.0 128.0 0.9992265 128.0 0.998453 
f5019.0 0.0 256.0 -6.0 1.0 128.0 0.995114 128.0 0.990228 
f5020.0 0.0 256.0 -6.0 1.0 128.0 0.9919785 128.0 0.983957 
f5021.0 0.0 256.0 -6.0 1.0 128.0 1.000867 128.0 1.001734 
f5022.0 0.0 256.0 -6.0 1.0 128.0 0.9925470000000001 128.0 0.985094 
;Inst	Sta	Hold	Vel	Ton	Oct	Voi	Ste	En1	Gls	Ups	Ren	2gl	3gl	Vol
i 1	0.0025238095238095254	0.505	74	203	6	2	10	8	0	-1	8	0	0	4.0	
i 1	0.0032448979591836735	3.0300000000000002	61	203	6	25	9	1	0	1	1	0	0	1.1853860203341497	
i 1	0.0032448979591836735	10.352500000000001	61	701	1	27	4	16	0	252	16	307	0	1.7780790305012246	
i 1	0.005408163265306123	1.01	74	701	6	1	7	16	0	1	16	0	0	2.0	
i 1	0.0061292517006802695	0.7575000000000001	73	701	2	20	3	2	0	-2	2	0	0	4.0	
i 1	0.006129251700680273	13.3825	61	701	1	27	4	16	0	252	16	307	0	1.7780790305012246	
i 1	0.006850340136054421	0.505	71	701	5	9	8	8	0	-1	8	0	0	3.0	
i 1	0.006850340136054423	1.01	69	203	4	5	9	1	0	0	1	0	0	3.0	
i 1	0.00973469387755102	6.0600000000000005	63	1087	5	25	10	1	0	2	1	0	0	1.1853860203341497	
i 1	0.01261904761904762	0.505	70	701	3	24	1	2	0	-1	2	0	0	8.0	
i 1	0.014782312925170068	0.505	73	701	3	20	12	8	0	-2	8	0	0	4.0	
i 1	0.24819727891156462	0.2525	77	1087	4	24	16	16	0	2	16	0	0	5.0	
i 1	0.49531292517006803	0.2525	70	203	4	20	13	2	0	-2	2	0	0	4.0	
i 1	0.5025238095238095	0.7575000000000001	71	701	4	4	7	8	0	-2	8	0	0	4.0	
i 1	0.7381020408163266	0.2525	70	1087	3	20	4	8	0	-2	8	0	0	4.0	
i 1	0.7554081632653061	0.2525	70	1087	3	24	11	8	0	-2	8	0	0	8.0	
i 1	0.9866598639455783	0.2525	72	701	6	5	16	1	0	0	1	0	0	3.0	
i 1	0.9931496598639455	0.7575000000000001	77	701	4	24	2	16	0	2	16	0	0	5.0	
i 1	1.0169455782312926	1.2625	72	1087	3	5	13	1	0	0	1	0	0	3.0	
i 1	1.2532448979591837	0.2525	70	1087	3	20	1	8	0	-1	8	0	0	4.0	
i 1	1.2604557823129252	0.7575000000000001	71	701	4	4	10	8	0	-2	8	0	0	4.0	
i 1	1.2611768707482993	7.8275	63	1087	5	25	4	1	0	2	1	0	0	1.1853860203341497	
i 1	1.2655034013605442	1.01	72	701	3	5	13	1	0	0	1	0	0	3.0	
i 1	1.495312925170068	0.2525	73	701	2	24	14	8	0	-1	8	0	0	8.0	
i 1	1.4960340136054422	0.2525	74	701	6	1	3	16	0	1	16	0	0	2.0	
i 1	1.7395442176870748	1.2625	74	701	6	1	6	17	0	1	17	0	0	2.0	
i 1	1.9844965986394558	0.505	70	701	3	24	4	2	0	-1	2	0	0	8.0	
i 1	1.985938775510204	1.7675	71	701	5	9	2	8	0	-1	8	0	0	3.0	
i 1	1.9888231292517007	0.505	70	701	3	20	4	2	0	-1	2	0	0	4.0	
i 1	1.9895442176870748	0.2525	72	701	3	5	2	0	0	-1	0	0	0	3.0	
i 1	1.9924285714285714	0.2525	77	1087	6	1	13	16	0	1	16	0	0	2.0	
i 1	2.2323333333333335	0.2525	71	1087	5	3	8	8	0	-1	8	0	0	4.0	
i 1	2.2330544217687076	1.5150000000000001	69	701	3	5	4	0	0	0	0	0	0	3.0	
i 1	2.2409863945578232	1.5150000000000001	69	203	6	5	8	0	0	0	0	0	0	3.0	
i 1	2.495312925170068	0.2525	74	701	6	1	11	16	0	1	16	0	0	2.0	
i 1	2.509734693877551	0.2525	70	203	4	20	7	2	0	-1	2	0	0	4.0	
i 1	2.7438707482993197	0.2525	72	701	3	5	3	0	0	-1	0	0	0	3.0	
i 1	2.759734693877551	0.2525	73	701	3	20	6	2	0	-1	2	0	0	4.0	
i 1	2.7676666666666665	0.2525	70	701	3	24	8	2	0	-1	2	0	0	8.0	
i 1	2.9823333333333335	1.5150000000000001	70	701	3	24	4	2	0	-1	2	0	0	4.0	
i 1	3.0176666666666665	0.2525	77	1087	6	1	14	16	0	1	16	0	0	2.0	
i 1	3.239544217687075	1.01	74	701	6	1	16	16	0	1	16	0	0	2.0	
i 1	3.2409863945578232	1.7675	77	203	5	1	12	17	0	1	17	0	0	2.0	
i 1	3.490265306122449	1.5150000000000001	71	701	5	3	12	8	0	-2	8	0	0	4.0	
i 1	3.499639455782313	1.01	72	701	3	5	5	0	0	-1	0	0	0	3.0	
i 1	3.500360544217687	1.5150000000000001	71	1087	5	3	11	8	0	-1	8	0	0	4.0	
i 1	3.5032448979591835	0.7575000000000001	72	1087	3	5	8	0	0	0	0	0	0	3.0	
i 1	3.986659863945578	1.2625	70	701	3	24	7	2	0	-1	2	0	0	4.0	
i 1	4.003244897959184	2.02	72	701	3	5	10	0	0	-1	0	0	0	3.0	
i 1	4.246755102040816	1.01	74	701	6	1	6	16	0	1	16	0	0	2.0	
i 1	4.259734693877551	7.8275	63	701	4	26	1	16	0	1	16	0	0	1.1853860203341497	
i 1	4.508292517006803	0.2525	72	1087	6	5	11	0	0	0	0	0	0	3.0	
i 1	4.739544217687075	1.2625	77	1087	4	24	16	16	0	2	16	0	0	5.0	
i 1	4.742428571428571	1.2625	77	701	4	24	5	16	0	2	16	0	0	5.0	
i 1	5.004687074829932	0.7575000000000001	74	203	5	2	15	8	0	-1	8	0	0	4.0	
i 1	5.24387074829932	1.7675	71	1087	4	4	4	2	0	-2	2	0	0	4.0	
i 1	5.244591836734694	0.2525	72	1087	6	5	14	0	0	0	0	0	0	3.0	
i 1	5.244591836734694	0.505	70	701	3	24	4	2	0	-1	2	0	0	4.0	
i 1	5.266945578231293	1.7675	71	701	4	4	16	8	0	-2	8	0	0	4.0	
i 1	5.504687074829932	0.2525	72	701	3	5	7	1	0	0	1	0	0	3.0	
i 1	5.507571428571429	0.2525	72	1087	3	5	10	1	0	0	1	0	0	3.0	
i 1	5.7496394557823125	1.5150000000000001	69	701	3	5	6	0	0	0	0	0	0	3.0	
i 1	5.986659863945579	1.2625	73	701	3	24	4	8	0	-1	8	0	0	4.0	
i 1	5.996755102040816	1.2625	74	701	6	1	1	17	0	1	17	0	0	2.0	
i 1	6.007571428571429	1.2625	74	203	5	1	9	17	0	2	17	0	0	2.0	
i 1	6.011897959183673	0.2525	77	1087	4	1	14	16	0	1	16	0	0	2.0	
i 1	6.241707482993197	0.505	77	1087	4	24	12	16	0	2	16	0	0	5.0	
i 1	6.2503605442176875	0.2525	69	203	6	5	1	1	0	0	1	0	0	3.0	
i 1	6.253965986394558	1.01	71	701	5	9	16	8	0	-1	8	0	0	3.0	
i 1	6.482333333333333	1.01	74	203	5	2	8	8	0	-1	8	0	0	4.0	
i 1	6.492428571428571	1.7675	72	1087	5	5	6	0	0	0	0	0	0	3.0	
i 1	6.746034013605442	1.2625	77	1087	4	1	8	16	0	1	16	0	0	2.0	
i 1	6.751081632653062	0.505	74	701	6	1	14	16	0	1	16	0	0	2.0	
i 1	7.241707482993197	0.7575000000000001	74	701	6	1	7	16	0	1	16	0	0	2.0	
i 1	7.254687074829932	7.8275	63	701	4	26	6	1	0	2	1	0	0	1.1853860203341497	
i 1	7.258292517006803	1.5150000000000001	71	701	5	3	14	8	0	-2	8	0	0	4.0	
i 1	7.263340136054421	0.2525	71	701	5	9	5	8	0	-1	8	0	0	3.0	
i 1	7.490265306122449	1.01	73	701	3	24	5	8	0	-1	8	0	0	4.0	
i 1	7.492428571428571	2.02	69	203	6	5	1	1	0	0	1	0	0	3.0	
i 1	7.501081632653062	1.01	70	701	3	24	4	8	0	-1	8	0	0	4.0	
i 1	7.755408163265306	1.5150000000000001	77	203	5	1	1	17	0	1	17	0	0	2.0	
i 1	7.758292517006803	1.5150000000000001	74	701	6	1	13	16	0	1	16	0	0	2.0	
i 1	8.266945578231292	0.2525	77	1087	4	1	1	16	0	1	16	0	0	2.0	
i 1	8.496755102040817	0.2525	74	701	6	1	5	17	0	1	17	0	0	2.0	
i 1	8.49747619047619	1.7675	71	701	5	9	1	8	0	-1	8	0	0	3.0	
i 1	8.505408163265306	0.7575000000000001	70	701	3	24	7	2	0	-1	2	0	0	4.0	
i 1	8.517666666666667	1.7675	74	203	5	2	5	8	0	-1	8	0	0	4.0	
i 1	8.986659863945578	0.505	77	1087	4	24	12	16	0	2	16	0	0	5.0	
i 1	8.991707482993197	0.505	77	701	4	24	8	16	0	2	16	0	0	5.0	
i 1	9.001081632653062	2.02	74	203	5	1	8	17	0	2	17	0	0	2.0	
i 1	9.012619047619047	2.02	74	701	6	1	3	17	0	1	17	0	0	2.0	
i 1	9.236659863945578	0.2525	71	1087	4	3	1	8	0	-1	8	0	0	4.0	
i 1	9.259013605442178	0.7575000000000001	72	1087	5	5	15	1	0	0	1	0	0	3.0	
i 1	9.493149659863946	0.7575000000000001	69	701	3	5	2	0	0	0	0	0	0	3.0	
i 1	9.50612925170068	0.2525	74	701	6	1	10	16	0	1	16	0	0	2.0	
i 1	9.514061224489796	1.7675	69	203	6	5	8	0	0	0	0	0	0	3.0	
i 1	9.741707482993197	0.505	70	701	3	24	2	2	0	-1	2	0	0	4.0	
i 1	9.755408163265306	0.2525	70	701	3	24	12	8	0	-1	8	0	0	4.0	
i 1	9.996034013605442	0.2525	73	1087	3	24	10	2	0	-2	2	0	0	4.0	
i 1	9.998197278911565	2.02	71	701	4	4	2	8	0	-2	8	0	0	4.0	
i 1	10.240986394557822	0.2525	74	203	5	2	8	8	0	-1	8	0	0	4.0	
i 1	10.248918367346938	1.01	69	701	6	5	8	0	0	0	0	0	0	3.0	
i 1	10.261897959183674	6.565	61	701	3	27	13	16	0	1	16	0	0	1.7780790305012246	
i 1	10.265503401360544	5.05	73	701	3	24	1	8	0	-1	8	0	0	4.0	
i 1	10.494591836734694	1.7675	74	701	6	1	4	16	0	1	16	0	0	2.0	
i 1	10.505408163265306	0.2525	71	701	5	9	13	8	0	-1	8	0	0	3.0	
i 1	10.982333333333333	0.7575000000000001	72	1087	5	5	2	0	0	0	0	0	0	3.0	
i 1	11.001081632653062	2.02	70	701	3	24	12	2	0	-1	2	0	0	4.0	
i 1	11.490986394557822	0.505	71	701	5	9	2	8	0	-1	8	0	0	3.0	
i 1	11.493149659863946	1.2625	69	203	6	5	16	1	0	0	1	0	0	3.0	
i 1	11.498918367346938	0.7575000000000001	74	203	5	2	1	8	0	-1	8	0	0	4.0	
i 1	11.740986394557822	1.5150000000000001	77	203	5	1	15	17	0	1	17	0	0	2.0	
i 1	11.74242857142857	0.7575000000000001	73	1087	3	24	16	8	0	-1	8	0	0	4.0	
i 1	11.765503401360544	1.5150000000000001	74	701	6	1	13	16	0	1	16	0	0	2.0	
i 1	11.995312925170069	1.2625	71	701	5	3	12	8	0	-2	8	0	0	4.0	
i 1	12.243149659863946	1.5150000000000001	72	1087	5	5	11	1	0	0	1	0	0	3.0	
i 1	12.74026530612245	1.2625	77	701	4	24	12	16	0	2	16	0	0	5.0	
i 1	12.746034013605442	0.505	72	701	3	5	6	0	0	-1	0	0	0	3.0	
i 1	12.751802721088435	0.2525	71	701	4	4	13	8	0	-2	8	0	0	4.0	
i 1	12.753244897959183	1.7675	77	1087	4	24	4	16	0	2	16	0	0	5.0	
i 1	13.23521768707483	3.535	61	701	3	27	13	16	0	1	16	0	0	1.7780790305012246	
i 1	13.245312925170069	1.01	74	203	5	2	16	8	0	-1	8	0	0	4.0	
i 1	13.261176870748299	0.7575000000000001	70	701	3	24	6	2	0	-1	2	0	0	4.0	
i 1	13.264061224489796	0.2525	77	1087	4	1	5	16	0	1	16	0	0	2.0	
i 1	13.264061224489796	0.505	71	701	5	3	5	8	0	-2	8	0	0	4.0	
i 1	13.50757142857143	1.7675	74	701	4	1	11	17	0	1	17	0	0	2.0	
i 1	13.516224489795919	1.7675	74	203	5	1	14	17	0	2	17	0	0	2.0	
i 1	13.738102040816326	2.02	71	701	4	4	14	8	0	-2	8	0	0	4.0	
i 1	13.740986394557822	2.02	71	1087	4	4	14	2	0	-2	2	0	0	4.0	
i 1	13.740986394557822	0.2525	72	1087	5	5	1	0	0	0	0	0	0	3.0	
i 1	13.763340136054422	1.5150000000000001	73	701	3	24	9	2	0	-2	2	0	0	4.0	
i 1	14.014061224489796	0.2525	72	701	6	5	7	0	0	-1	0	0	0	3.0	
i 1	14.239544217687074	0.2525	72	1087	5	5	11	1	0	0	1	0	0	3.0	
i 1	14.24242857142857	0.2525	74	203	5	2	3	8	0	-1	8	0	0	4.0	
i 1	14.734496598639456	0.7575000000000001	77	1087	4	1	1	16	0	1	16	0	0	2.0	
i 1	14.73521768707483	0.2525	71	1087	4	3	14	8	0	-1	8	0	0	4.0	
i 1	14.746755102040817	1.01	72	701	3	5	6	0	0	-1	0	0	0	3.0	
i 1	14.754687074829931	1.01	72	1087	5	5	6	0	0	0	0	0	0	3.0	
i 1	14.762619047619047	2.02	70	701	3	24	16	2	0	-1	2	0	0	4.0	
i 1	14.983054421768708	1.7675	74	701	4	1	9	16	0	1	16	0	0	2.0	
i 1	15.239544217687074	1.5150000000000001	72	701	5	5	16	0	0	-1	0	0	0	3.0	
i 1	15.25612925170068	1.5150000000000001	71	701	4	9	6	8	0	-1	8	0	0	3.0	
i 1	15.25757142857143	1.5150000000000001	69	203	6	5	9	1	0	0	1	0	0	3.0	
i 1	15.511176870748299	0.2525	77	1087	4	24	8	16	0	2	16	0	0	5.0	
i 1	15.739544217687074	0.2525	74	203	5	1	8	17	0	2	17	0	0	2.0	
i 1	15.987380952380953	0.2525	72	1087	5	5	7	1	0	0	1	0	0	3.0	
i 1	16.011897959183674	0.2525	71	1087	4	3	4	8	0	-1	8	0	0	4.0	
i 1	16.48521768707483	0.2525	71	701	5	3	16	8	0	-2	8	0	0	4.0	
i 1	16.489544217687076	0.2525	74	203	5	2	3	8	0	-1	8	0	0	4.0	
i 1	16.493149659863946	0.2525	74	203	5	1	12	17	0	2	17	0	0	2.0	
i 1	16.732333333333333	1.2625	63	379	3	27	8	1	0	2	1	0	0	1.7780790305012246	
i 1	16.7388231292517	0.7575000000000001	77	695	5	1	12	17	0	2	17	0	0	2.0	
i 1	16.74891836734694	1.01	74	1081	4	9	13	2	0	-1	2	0	0	3.0	
i 1	16.751802721088435	1.7675	74	1081	4	1	6	16	0	2	16	0	0	2.0	
i 1	16.75973469387755	4.2925	61	379	3	27	7	16	0	1	16	0	0	1.7780790305012246	
i 1	16.761897959183674	0.7575000000000001	74	695	5	2	3	8	0	-1	8	0	0	4.0	
i 1	16.76478231292517	2.2725	70	1081	3	24	12	2	0	-2	2	0	0	4.0	
i 1	16.766224489795917	0.505	72	379	6	5	4	1	0	0	1	0	0	3.0	
i 1	16.766945578231294	2.2725	70	379	3	24	1	8	0	-2	8	0	0	4.0	
i 1	16.767666666666667	1.7675	74	695	5	1	7	17	0	1	17	0	0	2.0	
i 1	16.983775510204083	0.2525	72	379	6	5	9	0	0	0	0	0	0	3.0	
i 1	17.238102040816326	1.7675	71	695	5	3	6	2	0	-1	2	0	0	4.0	
i 1	17.2388231292517	0.505	69	695	6	5	15	1	0	-1	1	0	0	3.0	
i 1	17.241707482993196	1.5150000000000001	69	695	6	5	15	0	0	-1	0	0	0	3.0	
i 1	17.48665986394558	0.2525	74	695	4	24	16	17	0	1	17	0	0	5.0	
i 1	17.738102040816326	0.2525	72	379	6	5	5	0	0	0	0	0	0	3.0	
i 1	17.742428571428572	1.7675	74	379	4	24	14	17	0	2	17	0	0	5.0	
i 1	17.992428571428572	1.2625	74	695	4	24	11	17	0	1	17	0	0	5.0	
i 1	17.99531292517007	0.2525	74	695	5	2	3	8	0	-1	8	0	0	4.0	
i 1	18.00973469387755	15.4025	63	379	1	27	5	1	0	252	1	307	0	1.7780790305012246	
i 1	18.015503401360544	1.01	74	379	4	3	15	8	0	-1	8	0	0	4.0	
i 1	18.234496598639456	1.7675	69	695	4	5	2	0	0	-1	0	0	0	3.0	
i 1	18.24387074829932	1.5150000000000001	71	1081	4	9	8	8	0	-1	8	0	0	3.0	
i 1	18.490986394557822	2.02	77	695	6	1	9	17	0	2	17	0	0	2.0	
i 1	18.51334013605442	1.01	74	695	5	2	16	8	0	-1	8	0	0	4.0	
i 1	18.732333333333333	1.7675	77	1081	4	1	16	17	0	1	17	0	0	2.0	
i 1	18.99891836734694	0.2525	72	695	6	5	16	0	0	0	0	0	0	3.0	
i 1	19.512619047619047	1.01	72	379	5	5	11	0	0	0	0	0	0	3.0	
i 1	19.756850340136054	4.2925	70	1081	3	24	13	2	0	-2	2	0	0	4.0	
i 1	19.983054421768706	1.2625	74	379	4	1	5	17	0	1	17	0	0	2.0	
i 1	19.99026530612245	1.01	72	695	6	5	14	0	0	0	0	0	0	3.0	
i 1	19.990986394557822	2.02	72	1081	5	5	10	1	0	-1	1	0	0	3.0	
i 1	20.01478231292517	1.2625	70	379	3	24	2	2	0	-1	2	0	0	4.0	
i 1	20.016945578231294	0.7575000000000001	74	695	5	1	11	16	0	1	16	0	0	2.0	
i 1	20.233054421768706	2.02	74	1081	4	1	10	16	0	2	16	0	0	2.0	
i 1	20.24891836734694	0.7575000000000001	74	695	5	1	6	17	0	1	17	0	0	2.0	
i 1	20.2611768707483	0.2525	74	695	5	2	6	8	0	-1	8	0	0	4.0	
i 1	20.483054421768706	0.2525	69	695	4	5	15	0	0	-1	0	0	0	3.0	
i 1	20.492428571428572	2.2725	70	379	3	24	6	2	0	-2	2	0	0	4.0	
i 1	20.501802721088435	2.525	74	1081	4	9	13	2	0	-1	2	0	0	3.0	
i 1	20.516224489795917	0.505	74	695	5	2	3	2	0	-1	2	0	0	4.0	
i 1	20.748197278911565	0.2525	72	1081	5	5	6	0	0	-1	0	0	0	3.0	
i 1	21.001802721088435	12.3725	61	379	1	27	7	16	0	252	16	307	0	1.7780790305012246	
i 1	21.246755102040815	0.2525	74	379	4	3	15	8	0	-1	8	0	0	4.0	
i 1	21.25973469387755	0.2525	74	695	5	1	7	16	0	1	16	0	0	2.0	
i 1	21.512619047619047	0.2525	74	379	4	4	10	2	0	-2	2	0	0	4.0	
i 1	21.75973469387755	2.7775	74	379	4	24	11	17	0	2	17	0	0	5.0	
i 1	21.760455782312924	1.5150000000000001	69	695	4	5	12	0	0	-1	0	0	0	3.0	
i 1	21.9888231292517	2.02	74	379	4	3	10	8	0	-1	8	0	0	4.0	
i 1	22.01334013605442	2.02	71	695	5	3	13	2	0	-1	2	0	0	4.0	
i 1	22.255408163265304	0.2525	74	695	5	1	16	16	0	1	16	0	0	2.0	
i 1	22.494591836734696	0.2525	73	695	4	24	4	2	0	-1	2	0	0	4.0	
i 1	22.515503401360544	0.505	74	379	4	1	6	17	0	1	17	0	0	2.0	
i 1	22.74891836734694	1.2625	70	379	3	24	14	2	0	-2	2	0	0	4.0	
i 1	22.760455782312924	1.2625	69	695	6	5	10	1	0	-1	1	0	0	3.0	
i 1	22.76334013605442	1.7675	72	379	5	5	3	0	0	0	0	0	0	3.0	
i 1	22.99963945578231	0.2525	74	695	5	1	8	16	0	1	16	0	0	2.0	
i 1	23.00973469387755	0.505	71	695	4	4	2	8	0	-2	8	0	0	4.0	
i 1	23.267666666666667	1.7675	70	379	3	24	3	2	0	-2	2	0	0	4.0	
i 1	23.485938775510203	0.2525	72	695	4	5	11	0	0	0	0	0	0	3.0	
i 1	23.515503401360544	0.505	74	695	5	2	8	8	0	-1	8	0	0	4.0	
i 1	23.733054421768706	1.7675	71	695	4	4	12	8	0	-2	8	0	0	4.0	
i 1	23.7388231292517	0.2525	69	695	6	5	15	0	0	-1	0	0	0	3.0	
i 1	23.75973469387755	1.7675	74	379	4	4	15	2	0	-2	2	0	0	4.0	
i 1	24.003244897959185	0.505	69	695	4	5	10	1	0	-1	1	0	0	3.0	
i 1	24.00612925170068	1.7675	72	1081	5	5	3	1	0	-1	1	0	0	3.0	
i 1	24.010455782312924	1.2625	74	695	6	1	14	16	0	1	16	0	0	2.0	
i 1	24.01478231292517	1.7675	72	695	4	5	8	0	0	0	0	0	0	3.0	
i 1	24.238102040816326	0.2525	71	695	5	3	12	2	0	-1	2	0	0	4.0	
i 1	24.482333333333333	0.2525	70	695	4	24	11	2	0	-1	2	0	0	4.0	
i 1	24.496034013605442	0.2525	69	695	6	5	11	0	0	-1	0	0	0	3.0	
i 1	24.50973469387755	2.02	70	1081	3	24	13	2	0	-2	2	0	0	4.0	
i 1	24.73521768707483	1.7675	74	1081	4	1	6	16	0	2	16	0	0	2.0	
i 1	24.7611768707483	0.2525	74	695	6	2	1	8	0	-1	8	0	0	4.0	
i 1	24.761897959183674	0.505	70	379	3	24	12	8	0	-2	8	0	0	4.0	
i 1	24.766945578231294	0.2525	72	1081	5	5	6	0	0	-1	0	0	0	3.0	
i 1	24.983775510204083	1.01	74	695	6	2	13	2	0	-1	2	0	0	4.0	
i 1	25.011897959183674	1.01	74	1081	4	9	15	2	0	-1	2	0	0	3.0	
i 1	25.247476190476192	1.2625	70	379	3	24	12	2	0	-2	2	0	0	4.0	
i 1	25.25612925170068	1.01	72	379	5	5	2	1	0	-1	1	0	0	3.0	
i 1	25.257571428571428	0.2525	73	695	4	24	7	8	0	-1	8	0	0	4.0	
i 1	25.503965986394558	1.2625	70	379	3	24	11	8	0	-2	8	0	0	4.0	
i 1	25.510455782312924	0.2525	74	379	4	24	13	17	0	2	17	0	0	5.0	
i 1	25.517666666666667	2.02	74	379	4	3	4	8	0	-1	8	0	0	4.0	
i 1	25.74387074829932	2.02	69	695	4	5	14	0	0	-1	0	0	0	3.0	
i 1	25.744591836734696	2.02	72	1081	5	5	1	0	0	-1	0	0	0	3.0	
i 1	25.766945578231294	0.2525	74	695	6	1	2	16	0	1	16	0	0	2.0	
i 1	25.993149659863946	0.2525	74	695	6	2	3	8	0	-1	8	0	0	4.0	
i 1	26.002523809523808	0.7575000000000001	74	695	4	24	10	17	0	1	17	0	0	5.0	
i 1	26.232333333333333	2.02	77	1081	4	1	13	17	0	1	17	0	0	2.0	
i 1	26.26478231292517	0.2525	72	1081	5	5	11	1	0	-1	1	0	0	3.0	
i 1	26.266224489795917	2.02	77	695	6	1	7	17	0	2	17	0	0	2.0	
i 1	26.50108163265306	0.505	72	695	4	5	3	0	0	0	0	0	0	3.0	
i 1	26.74387074829932	0.2525	74	695	6	2	8	2	0	-1	2	0	0	4.0	
i 1	26.744591836734696	1.7675	70	1081	3	24	2	2	0	-2	2	0	0	4.0	
i 1	26.74891836734694	0.505	74	1081	4	1	15	16	0	2	16	0	0	2.0	
i 1	26.75108163265306	1.01	70	379	3	24	11	2	0	-2	2	0	0	4.0	
i 1	26.98521768707483	0.2525	69	695	4	5	10	0	0	-1	0	0	0	3.0	
i 1	26.994591836734696	2.02	74	695	6	2	15	8	0	-1	8	0	0	4.0	
i 1	27.00036054421769	0.505	71	695	5	3	1	2	0	-1	2	0	0	4.0	
i 1	27.001802721088435	0.2525	70	379	3	24	13	8	0	-2	8	0	0	4.0	
i 1	27.003244897959185	2.2725	71	1081	4	9	12	8	0	-1	8	0	0	3.0	
i 1	27.24531292517007	0.2525	74	695	6	1	10	16	0	1	16	0	0	2.0	
i 1	27.24963945578231	0.2525	73	695	4	24	9	2	0	-2	2	0	0	4.0	
i 1	27.50036054421769	0.2525	74	695	6	1	3	17	0	1	17	0	0	2.0	
i 1	27.505408163265304	1.5150000000000001	72	1081	5	5	10	1	0	-1	1	0	0	3.0	
i 1	27.50612925170068	0.7575000000000001	73	379	3	24	1	8	0	-2	8	0	0	4.0	
i 1	27.511897959183674	0.2525	71	695	4	4	13	8	0	-2	8	0	0	4.0	
i 1	27.743149659863946	1.7675	74	695	6	1	16	16	0	1	16	0	0	2.0	
i 1	27.75612925170068	0.2525	74	695	6	2	3	2	0	-1	2	0	0	4.0	
i 1	28.247476190476192	0.505	73	695	4	24	5	8	0	-2	8	0	0	4.0	
i 1	28.25973469387755	2.02	69	695	4	5	16	0	0	-1	0	0	0	3.0	
i 1	28.49026530612245	0.2525	77	695	6	1	8	17	0	2	17	0	0	2.0	
i 1	28.490986394557822	1.5150000000000001	70	379	3	24	1	2	0	-2	2	0	0	4.0	
i 1	28.49387074829932	2.02	72	379	5	5	11	1	0	-1	1	0	0	3.0	
i 1	28.50108163265306	1.5150000000000001	71	695	4	4	9	8	0	-2	8	0	0	4.0	
i 1	28.507571428571428	2.02	74	379	4	4	6	2	0	-2	2	0	0	4.0	
i 1	28.756850340136054	0.2525	73	379	3	24	1	2	0	-2	2	0	0	4.0	
i 1	28.989544217687076	0.2525	72	1081	5	5	12	0	0	-1	0	0	0	3.0	
i 1	28.996034013605442	1.5150000000000001	74	1081	4	1	14	16	0	2	16	0	0	2.0	
i 1	29.001802721088435	1.01	70	1081	3	24	15	2	0	-2	2	0	0	4.0	
i 1	29.234496598639456	0.2525	74	695	6	2	8	2	0	-1	2	0	0	4.0	
i 1	29.761897959183674	3.0300000000000002	74	379	4	24	10	17	0	2	17	0	0	5.0	
i 1	29.997476190476192	2.7775	74	695	4	24	4	17	0	1	17	0	0	5.0	
i 1	29.99891836734694	1.5150000000000001	72	1081	3	5	13	0	0	-1	0	0	0	3.0	
i 1	29.99891836734694	0.7575000000000001	73	1081	2	20	4	8	0	-1	8	0	0	2.0155750592515815	
i 1	30.007571428571428	0.7575000000000001	74	1081	4	9	13	2	0	-1	2	0	0	3.0	
i 1	30.009013605442178	3.2825	70	379	3	24	15	2	0	-2	2	0	0	6.0155750592515815	
i 1	30.017666666666667	0.7575000000000001	70	379	2	24	10	8	0	-2	8	0	0	6.0155750592515815	
i 1	30.240986394557822	1.7675	71	695	5	3	13	2	0	-1	2	0	0	4.0	
i 1	30.25468707482993	1.7675	74	379	4	3	14	8	0	-1	8	0	0	4.0	
i 1	30.497476190476192	0.505	69	695	4	5	9	0	0	-1	0	0	0	3.0	
i 1	30.50612925170068	0.7575000000000001	70	1081	3	20	7	2	0	-1	2	0	0	2.0155750592515815	
i 1	30.508292517006804	0.2525	77	1081	5	1	16	17	0	1	17	0	0	2.0	
i 1	30.755408163265304	0.2525	74	695	6	2	2	8	0	-1	8	0	0	4.0	
i 1	30.75612925170068	0.2525	73	695	3	24	2	2	0	-2	2	0	0	6.0155750592515815	
i 1	30.76478231292517	0.2525	73	695	3	20	3	8	0	-1	8	0	0	2.0155750592515815	
i 1	30.983054421768706	1.01	73	1081	2	20	4	2	0	-2	2	0	0	2.0155750592515815	
i 1	30.984496598639456	0.2525	77	1081	5	1	14	17	0	1	17	0	0	2.0	
i 1	30.990986394557822	1.01	72	379	5	5	15	0	0	0	0	0	0	3.0	
i 1	30.99891836734694	0.2525	74	379	4	4	3	2	0	-2	2	0	0	4.0	
i 1	31.009013605442178	1.01	70	379	2	20	14	2	0	-2	2	0	0	2.0155750592515815	
i 1	31.244591836734696	0.505	74	379	4	1	2	17	0	1	17	0	0	2.0	
i 1	31.256850340136054	1.5150000000000001	74	695	6	2	5	8	0	-1	8	0	0	4.0	
i 1	31.483054421768706	1.5150000000000001	72	1081	5	5	10	1	0	-1	1	0	0	3.0	
i 1	31.506850340136054	1.2625	71	1081	4	9	2	8	0	-1	8	0	0	3.0	
i 1	31.746755102040815	1.2625	74	1081	4	1	16	16	0	2	16	0	0	2.0	
i 1	31.75468707482993	0.2525	70	379	2	24	4	2	0	-2	2	0	0	6.0155750592515815	
i 1	31.755408163265304	1.01	74	695	6	1	4	16	0	1	16	0	0	2.0	
i 1	31.984496598639456	0.505	69	695	4	5	4	0	0	-1	0	0	0	3.0	
i 1	31.987380952380953	0.2525	70	695	3	24	14	8	0	-1	8	0	0	6.0155750592515815	
i 1	31.994591836734696	1.5150000000000001	71	695	4	4	16	8	0	-2	8	0	0	4.0	
i 1	31.997476190476192	0.2525	70	695	3	20	14	8	0	-2	8	0	0	2.0155750592515815	
i 1	31.99891836734694	0.7575000000000001	70	1081	3	24	1	2	0	-2	2	0	0	6.0155750592515815	
i 1	32.00757142857143	1.2625	74	695	6	1	7	17	0	1	17	0	0	2.0	
i 1	32.013340136054424	0.2525	73	695	3	20	15	2	0	-1	2	0	0	2.0155750592515815	
i 1	32.23810204081633	1.01	70	379	2	20	4	8	0	-2	8	0	0	2.0155750592515815	
i 1	32.2582925170068	1.01	73	1081	2	20	15	8	0	-2	8	0	0	2.0155750592515815	
i 1	32.26766666666666	0.505	73	379	2	24	12	2	0	-2	2	0	0	6.0155750592515815	
i 1	32.51478231292517	0.2525	72	379	5	5	5	1	0	-1	1	0	0	3.0	
i 1	32.746755102040815	1.2625	71	695	5	3	14	2	0	-1	2	0	0	4.0	
i 1	32.99891836734694	0.2525	72	1081	3	5	8	1	0	-1	1	0	0	3.0	
i 1	33.00757142857143	0.2525	77	695	6	1	6	17	0	2	17	0	0	2.0	
i 1	33.23449659863945	1.5150000000000001	74	197	6	1	1	17	0	2	17	0	0	2.0	
i 1	33.24242857142857	1.2625	74	197	4	4	7	8	0	-1	8	0	0	4.0	
i 1	33.24459183673469	0.505	72	197	4	5	4	0	0	-1	0	0	0	3.0	
i 1	33.24459183673469	0.2525	70	695	3	20	1	8	0	-2	8	0	0	2.0155750592515815	
i 1	33.24819727891156	0.2525	70	899	3	20	5	8	0	-1	8	0	0	2.0155750592515815	
i 1	33.249639455782315	0.7575000000000001	69	695	4	5	2	1	0	-1	1	0	0	3.0	
i 1	33.253965986394554	0.505	72	899	4	5	1	1	0	0	1	0	0	3.0	
i 1	33.256850340136054	1.5150000000000001	70	197	3	24	8	8	0	-1	8	0	0	6.0155750592515815	
i 1	33.266945578231294	1.01	70	197	4	20	16	8	0	-2	8	0	0	2.0155750592515815	
i 1	33.48449659863945	0.2525	74	899	6	2	2	2	0	-1	2	0	0	4.0	
i 1	33.503965986394554	0.2525	73	197	3	20	16	8	0	-1	8	0	0	2.0155750592515815	
i 1	33.503965986394554	0.2525	73	197	2	20	2	8	0	-2	8	0	0	2.0155750592515815	
i 1	33.50901360544218	0.2525	70	197	2	24	12	8	0	-2	8	0	0	6.0155750592515815	
i 1	33.514061224489794	0.2525	74	197	6	9	7	8	0	-1	8	0	0	3.0	
i 1	33.74747619047619	0.2525	73	899	3	20	13	8	0	-2	8	0	0	2.0155750592515815	
i 1	33.753965986394554	0.2525	71	695	4	4	15	8	0	-2	8	0	0	4.0	
i 1	33.75757142857143	0.2525	73	695	3	20	10	2	0	-2	2	0	0	2.0155750592515815	
i 1	33.76478231292517	0.2525	69	695	4	5	16	0	0	-1	0	0	0	3.0	
i 1	33.98233333333334	0.505	70	197	3	20	7	2	0	-2	2	0	0	2.0155750592515815	
i 1	33.986659863945576	0.505	69	583	4	5	12	0	0	-1	0	0	0	3.0	
i 1	33.989544217687076	0.505	72	583	4	5	12	0	0	-1	0	0	0	3.0	
i 1	33.99891836734694	0.2525	72	899	4	5	4	1	0	0	1	0	0	3.0	
i 1	34.010455782312924	0.505	70	197	2	24	2	8	0	-1	8	0	0	6.0155750592515815	
i 1	34.246034013605446	0.2525	74	583	4	24	11	17	0	1	17	0	0	5.0	
i 1	34.266945578231294	1.5150000000000001	74	197	6	1	2	16	0	1	16	0	0	2.0	
i 1	34.483054421768706	2.02	74	695	4	3	11	2	0	-2	2	0	0	4.0	
i 1	34.48377551020408	0.7575000000000001	70	695	2	20	5	8	0	-2	8	0	0	2.0155750592515815	
i 1	34.48377551020408	1.2625	70	695	3	24	15	2	0	-2	2	0	0	6.0155750592515815	
i 1	34.485938775510206	1.5150000000000001	69	695	4	5	2	0	0	-1	0	0	0	3.0	
i 1	34.4888231292517	10.605	61	695	1	27	6	1	0	252	1	307	0	1.7780790305012246	
i 1	34.49531292517007	2.02	74	1081	6	2	7	2	0	-2	2	0	0	4.0	
i 1	34.49891836734694	0.7575000000000001	70	695	2	24	11	8	0	-2	8	0	0	6.0155750592515815	
i 1	34.50612925170068	0.505	77	1081	6	1	10	17	0	1	17	0	0	2.0	
i 1	34.51189795918367	1.2625	74	695	4	24	10	16	0	2	16	0	0	5.0	
i 1	34.76550340136055	1.2625	69	695	5	5	9	1	0	-1	1	0	0	3.0	
i 1	35.003965986394554	1.7675	77	695	4	24	10	16	0	1	16	0	0	5.0	
i 1	35.00612925170068	1.01	70	197	4	20	11	8	0	-2	8	0	0	2.0155750592515815	
i 1	35.01261904761905	1.7675	77	695	6	1	9	16	0	1	16	0	0	2.0	
i 1	35.01478231292517	0.505	71	695	4	4	4	2	0	-1	2	0	0	4.0	
i 1	35.23521768707483	0.2525	70	695	3	24	6	8	0	-2	8	0	0	6.0155750592515815	
i 1	35.246755102040815	0.2525	70	695	3	20	4	8	0	-2	8	0	0	2.0155750592515815	
i 1	35.253244897959185	1.5150000000000001	72	1081	4	5	12	1	0	-1	1	0	0	3.0	
i 1	35.256850340136054	0.2525	70	1081	3	20	15	8	0	-2	8	0	0	2.0155750592515815	
i 1	35.26261904761905	0.2525	71	197	5	9	7	8	0	-1	8	0	0	3.0	
i 1	35.51478231292517	0.2525	70	695	2	20	3	8	0	-2	8	0	0	2.0155750592515815	
i 1	35.73233333333334	1.5150000000000001	77	1081	6	1	13	17	0	1	17	0	0	2.0	
i 1	35.75540816326531	1.01	71	695	4	4	12	2	0	-1	2	0	0	4.0	
i 1	35.98377551020408	0.505	69	695	3	5	3	1	0	-1	1	0	0	3.0	
i 1	35.986659863945576	2.02	69	197	4	5	4	0	0	-1	0	0	0	3.0	
i 1	35.99747619047619	1.7675	70	197	3	20	4	8	0	-2	8	0	0	2.0155750592515815	
i 1	36.24242857142857	2.2725	71	197	6	9	14	8	0	-1	8	0	0	3.0	
i 1	36.24531292517007	2.7775	70	695	3	24	11	2	0	-2	2	0	0	6.0155750592515815	
i 1	36.263340136054424	1.5150000000000001	70	695	2	20	13	8	0	-2	8	0	0	2.0155750592515815	
i 1	36.49242857142857	0.2525	69	695	4	5	8	0	0	-1	0	0	0	3.0	
i 1	36.50252380952381	2.2725	74	695	4	24	4	16	0	2	16	0	0	5.0	
i 1	36.51622448979592	2.02	74	197	6	1	9	16	0	1	16	0	0	2.0	
i 1	36.73738095238095	0.2525	69	695	3	5	14	1	0	-1	1	0	0	3.0	
i 1	36.764061224489794	0.2525	71	695	5	3	15	2	0	-1	2	0	0	4.0	
i 1	36.985938775510206	0.505	74	695	4	3	15	2	0	-2	2	0	0	4.0	
i 1	37.24242857142857	0.505	77	695	6	1	13	16	0	1	16	0	0	2.0	
i 1	37.26261904761905	1.7675	69	695	5	5	6	1	0	0	1	0	0	3.0	
i 1	37.73233333333334	0.7575000000000001	70	695	3	20	16	8	0	-2	8	0	0	2.0155750592515815	
i 1	37.746755102040815	1.2625	77	1081	6	1	15	17	0	1	17	0	0	2.0	
i 1	37.759734693877554	2.02	74	695	4	4	10	8	0	-2	8	0	0	4.0	
i 1	37.99819727891156	0.7575000000000001	70	197	3	24	16	8	0	-1	8	0	0	6.0155750592515815	
i 1	38.00612925170068	4.04	70	197	3	20	13	8	0	-2	8	0	0	2.0155750592515815	
i 1	38.48377551020408	0.7575000000000001	70	695	2	24	6	8	0	-2	8	0	0	6.0155750592515815	
i 1	38.509734693877554	0.7575000000000001	70	695	2	20	14	8	0	-2	8	0	0	2.0155750592515815	
i 1	38.73377551020408	3.2825	70	695	3	20	2	2	0	-1	2	0	0	2.0155750592515815	
i 1	38.735938775510206	1.5150000000000001	69	695	3	5	14	1	0	-1	1	0	0	3.0	
i 1	38.764061224489794	1.5150000000000001	72	1081	4	5	11	1	0	-1	1	0	0	3.0	
i 1	39.00180272108844	0.7575000000000001	77	1081	4	1	16	17	0	1	17	0	0	2.0	
i 1	39.01478231292517	0.2525	71	1081	6	2	11	2	0	-2	2	0	0	4.0	
i 1	39.01622448979592	1.7675	70	695	2	24	7	2	0	-2	2	0	0	6.0155750592515815	
i 1	39.25180272108844	0.2525	73	1081	3	20	15	2	0	-1	2	0	0	2.0155750592515815	
i 1	39.25252380952381	2.2725	74	1081	6	2	15	2	0	-2	2	0	0	4.0	
i 1	39.48738095238095	2.02	69	197	4	5	7	0	0	-1	0	0	0	3.0	
i 1	39.503965986394554	0.2525	70	695	2	24	4	8	0	-2	8	0	0	6.0155750592515815	
i 1	39.509734693877554	0.2525	70	695	2	20	8	8	0	-2	8	0	0	2.0155750592515815	
i 1	39.73233333333334	1.7675	69	695	4	5	4	0	0	-1	0	0	0	3.0	
i 1	39.735938775510206	0.2525	74	1081	4	1	4	17	0	1	17	0	0	2.0	
i 1	40.00180272108844	0.2525	71	197	6	9	12	8	0	-1	8	0	0	3.0	
i 1	40.016945578231294	0.2525	70	695	2	20	16	8	0	-2	8	0	0	2.0155750592515815	
i 1	40.23233333333334	0.505	71	1081	6	2	15	2	0	-2	2	0	0	4.0	
i 1	40.23810204081633	0.2525	70	695	3	24	10	8	0	-2	8	0	0	6.0155750592515815	
i 1	40.25180272108844	0.2525	73	1081	3	20	1	2	0	-1	2	0	0	2.0155750592515815	
i 1	40.49098639455782	0.2525	70	695	2	20	6	8	0	-2	8	0	0	2.0155750592515815	
i 1	40.51550340136055	1.2625	71	695	4	4	9	2	0	-1	2	0	0	4.0	
i 1	40.74819727891156	2.525	74	197	6	1	4	16	0	1	16	0	0	2.0	
i 1	40.75108163265306	1.5150000000000001	74	197	6	9	16	8	0	-1	8	0	0	3.0	
i 1	40.990265306122446	2.02	71	197	6	9	9	8	0	-1	8	0	0	3.0	
i 1	41.00252380952381	2.02	71	1081	6	2	4	2	0	-2	2	0	0	4.0	
i 1	41.23377551020408	2.525	69	695	4	5	1	0	0	-1	0	0	0	3.0	
i 1	41.256850340136054	2.525	69	695	3	5	10	1	0	0	1	0	0	3.0	
i 1	41.743149659863946	0.2525	70	695	2	24	2	2	0	-2	2	0	0	6.0155750592515815	
i 1	41.76189795918367	0.2525	77	1081	4	1	15	17	0	1	17	0	0	2.0	
i 1	41.76478231292517	0.2525	70	695	2	20	6	8	0	-2	8	0	0	2.0155750592515815	
i 1	41.990265306122446	1.01	70	695	2	24	8	2	0	-2	2	0	0	8.087976833828202	
i 1	41.99459183673469	0.2525	69	197	4	5	1	0	0	-1	0	0	0	3.0	
i 1	42.003244897959185	0.2525	74	695	5	1	13	16	0	2	16	0	0	2.0	
i 1	42.00468707482993	0.2525	70	695	2	20	7	8	0	-2	8	0	0	4.087976833828202	
i 1	42.00540816326531	9.3425	70	695	2	20	11	2	0	-1	2	0	0	4.087976833828202	
i 1	42.24387074829932	0.505	70	695	3	24	13	8	0	-2	8	0	0	8.087976833828202	
i 1	42.246755102040815	0.2525	69	695	4	5	2	0	0	-1	0	0	0	3.0	
i 1	42.25612925170068	2.7775	74	1081	6	2	8	2	0	-2	2	0	0	4.0	
i 1	42.25612925170068	0.505	73	1081	2	20	8	8	0	-1	8	0	0	4.087976833828202	
i 1	42.25757142857143	2.525	77	695	4	1	8	16	0	1	16	0	0	2.0	
i 1	42.26261904761905	0.505	70	1081	3	20	1	8	0	-2	8	0	0	4.087976833828202	
i 1	42.26766666666666	1.7675	69	695	3	5	8	1	0	-1	1	0	0	3.0	
i 1	42.51766666666666	0.2525	72	1081	4	5	9	1	0	-1	1	0	0	3.0	
i 1	42.73377551020408	0.2525	70	695	2	20	15	8	0	-2	8	0	0	4.087976833828202	
i 1	42.7417074829932	2.2725	69	197	4	5	16	0	0	-1	0	0	0	3.0	
i 1	42.75757142857143	1.5150000000000001	73	197	3	20	7	8	0	-2	8	0	0	4.087976833828202	
i 1	42.76766666666666	1.5150000000000001	70	695	2	24	15	8	0	-2	8	0	0	8.087976833828202	
i 1	42.9917074829932	1.01	72	1081	4	5	13	1	0	-1	1	0	0	3.0	
i 1	43.00180272108844	0.505	74	695	4	4	6	8	0	-2	8	0	0	4.0	
i 1	43.00612925170068	3.2825	70	695	1	24	5	2	0	248	2	308	0	8.087976833828202	
i 1	43.01478231292517	2.02	69	695	4	5	10	0	0	-1	0	0	0	3.0	
i 1	43.24819727891156	0.2525	77	1081	4	1	14	17	0	1	17	0	0	2.0	
i 1	43.5082925170068	0.2525	74	197	6	1	6	17	0	2	17	0	0	2.0	
i 1	43.516945578231294	0.2525	71	695	4	4	4	2	0	-1	2	0	0	4.0	
i 1	44.0082925170068	0.2525	70	695	2	20	5	8	0	-2	8	0	0	4.087976833828202	
i 1	44.2388231292517	0.2525	70	695	3	24	16	8	0	-2	8	0	0	8.087976833828202	
i 1	44.24242857142857	0.2525	70	695	3	20	8	8	0	-2	8	0	0	4.087976833828202	
i 1	44.26478231292517	0.2525	73	1081	3	20	11	8	0	-1	8	0	0	4.087976833828202	
i 1	44.48521768707483	0.505	70	197	3	20	12	8	0	-2	8	0	0	4.087976833828202	
i 1	44.48521768707483	2.02	70	695	2	24	3	8	0	-2	8	0	0	8.087976833828202	
i 1	44.50901360544218	0.505	70	695	2	20	7	8	0	-2	8	0	0	4.087976833828202	
i 1	44.986659863945576	0.2525	74	1081	6	2	2	2	0	-2	2	0	0	9.003796959404667	
i 1	44.989544217687076	0.2525	71	1081	6	2	5	2	0	-2	2	0	0	9.003796959404667	
i 1	44.999639455782315	2.2725	69	695	3	5	10	1	0	0	1	0	0	3.0	
i 1	45.000360544217685	4.2925	77	1081	4	1	12	17	0	1	17	0	0	9.0	
i 1	45.00108163265306	1.7675	70	197	2	20	11	8	0	-2	8	0	0	4.087976833828202	
i 1	45.01766666666666	2.02	74	197	6	1	11	16	0	1	16	0	0	9.0	
i 1	45.23377551020408	2.02	70	197	3	24	3	8	0	-1	8	0	0	8.087976833828202	
i 1	45.24819727891156	0.2525	74	695	5	3	10	2	0	-2	2	0	0	9.003796959404667	
i 1	45.253965986394554	1.5150000000000001	70	197	2	20	11	8	0	-2	8	0	0	4.087976833828202	
i 1	45.263340136054424	0.505	74	695	4	4	14	8	0	-2	8	0	0	9.003796959404667	
i 1	45.4888231292517	2.525	71	1081	6	2	9	2	0	-2	2	0	0	9.003796959404667	
i 1	45.739544217687076	2.2725	71	197	6	9	12	8	0	-1	8	0	0	8.003796959404667	
i 1	46.0111768707483	0.2525	69	695	4	5	4	0	0	-1	0	0	0	3.0	
i 1	46.25757142857143	0.2525	74	695	4	4	12	8	0	-2	8	0	0	9.003796959404667	
i 1	46.2582925170068	0.505	70	695	2	20	10	8	0	-2	8	0	0	4.087976833828202	
i 1	46.259734693877554	0.2525	74	1081	6	2	16	2	0	-2	2	0	0	9.003796959404667	
i 1	46.5082925170068	0.505	74	695	5	3	2	2	0	-2	2	0	0	9.003796959404667	
i 1	46.73449659863945	2.525	69	197	4	5	12	0	0	-1	0	0	0	3.0	
i 1	46.73738095238095	2.2725	77	695	4	1	2	16	0	1	16	0	0	9.0	
i 1	46.746755102040815	0.2525	73	1081	2	20	13	8	0	-2	8	0	0	4.087976833828202	
i 1	46.74819727891156	2.525	69	695	4	5	6	0	0	-1	0	0	0	3.0	
i 1	46.75901360544218	0.2525	73	1081	2	20	10	8	0	-1	8	0	0	4.087976833828202	
i 1	46.760455782312924	1.5150000000000001	71	695	5	3	4	2	0	-1	2	0	0	9.003796959404667	
i 1	46.76766666666666	0.2525	70	695	3	20	7	8	0	-2	8	0	0	4.087976833828202	
i 1	47.00468707482993	1.01	70	695	2	20	5	8	0	-2	8	0	0	4.087976833828202	
i 1	47.01766666666666	1.2625	74	695	4	4	13	8	0	-2	8	0	0	9.003796959404667	
i 1	47.23738095238095	1.01	70	197	1	24	7	8	0	252	8	307	0	8.087976833828202	
i 1	47.24747619047619	2.2725	74	1081	6	2	13	2	0	-2	2	0	0	9.003796959404667	
i 1	47.76550340136055	0.2525	69	695	3	5	15	1	0	0	1	0	0	3.0	
i 1	47.99747619047619	0.2525	70	695	1	20	12	8	0	-2	8	0	0	4.087976833828202	
i 1	48.0111768707483	0.2525	72	197	4	5	11	0	0	-1	0	0	0	3.0	
i 1	48.246755102040815	2.02	70	197	2	20	7	2	0	-1	2	0	0	4.087976833828202	
i 1	48.249639455782315	2.7775	72	1081	4	5	12	1	0	-1	1	0	0	3.0	
i 1	48.256850340136054	1.7675	74	197	6	9	3	8	0	-1	8	0	0	8.003796959404667	
i 1	48.2582925170068	3.535	70	197	3	24	5	8	0	-1	8	0	0	8.087976833828202	
i 1	48.2582925170068	1.5150000000000001	70	695	1	24	12	2	0	252	2	307	0	8.087976833828202	
i 1	48.5082925170068	2.525	74	197	4	1	9	16	0	1	16	0	0	9.0	
i 1	48.510455782312924	2.02	74	695	4	24	8	16	0	2	16	0	0	12.0	
i 1	48.51622448979592	2.02	69	695	3	5	10	1	0	0	1	0	0	3.0	
i 1	48.759734693877554	1.2625	71	695	4	4	15	2	0	-1	2	0	0	9.003796959404667	
i 1	49.00108163265306	2.7775	71	197	6	9	10	8	0	-1	8	0	0	8.003796959404667	
i 1	49.00180272108844	2.2725	71	1081	6	2	8	2	0	-2	2	0	0	9.003796959404667	
i 1	49.246755102040815	1.7675	74	197	6	1	5	17	0	2	17	0	0	9.0	
i 1	49.4917074829932	0.2525	77	695	4	1	1	16	0	1	16	0	0	9.0	
i 1	49.746034013605446	1.5150000000000001	77	1081	4	1	12	17	0	1	17	0	0	9.0	
i 1	49.750360544217685	1.5150000000000001	70	695	2	24	6	2	0	-2	2	0	0	8.087976833828202	
i 1	50.00180272108844	1.5150000000000001	69	197	4	5	4	0	0	-1	0	0	0	3.0	
i 1	50.00468707482993	1.2625	74	1081	6	2	3	2	0	-2	2	0	0	9.003796959404667	
i 1	50.236659863945576	0.2525	70	695	3	24	15	8	0	-2	8	0	0	8.087976833828202	
i 1	50.489544217687076	0.505	74	583	4	24	6	16	0	2	16	0	0	12.0	
i 1	50.49242857142857	0.2525	70	197	2	20	16	2	0	-2	2	0	0	4.087976833828202	
i 1	50.496755102040815	1.2625	72	197	4	5	3	0	0	-1	0	0	0	3.0	
i 1	50.49891836734694	0.2525	70	695	2	24	6	8	0	-2	8	0	0	8.087976833828202	
i 1	50.503965986394554	0.7575000000000001	74	695	5	1	7	16	0	2	16	0	0	9.0	
i 1	50.73377551020408	1.01	74	197	6	9	6	8	0	-1	8	0	0	8.003796959404667	
i 1	50.985938775510206	0.7575000000000001	74	197	4	1	12	17	0	2	17	0	0	9.0	
i 1	50.9888231292517	0.2525	73	197	2	20	12	2	0	-1	2	0	0	4.087976833828202	
i 1	50.99819727891156	0.2525	72	1081	6	5	2	1	0	-1	1	0	0	3.0	
i 1	51.003244897959185	0.2525	70	197	2	20	15	2	0	-2	2	0	0	4.087976833828202	
i 1	51.236659863945576	0.7575000000000001	71	899	6	2	3	2	0	-1	2	0	0	9.003796959404667	
i 1	51.236659863945576	0.505	61	197	1	27	10	1	0	248	1	308	0	5.92693010167075	
i 1	51.24242857142857	0.2525	71	899	6	2	8	8	0	-2	8	0	0	9.003796959404667	
i 1	51.246755102040815	0.505	74	197	5	4	3	2	0	-2	2	0	0	9.003796959404667	
i 1	51.246755102040815	0.505	61	197	1	27	6	16	0	248	16	308	0	5.92693010167075	
i 1	51.24819727891156	0.2525	74	197	4	1	3	16	0	1	16	0	0	9.0	
i 1	51.24891836734694	2.02	74	583	4	4	2	2	0	-2	2	0	0	9.003796959404667	
i 1	51.2582925170068	0.505	77	197	5	1	1	17	0	2	17	0	0	9.0	
i 1	51.25901360544218	0.505	70	197	2	20	3	8	0	-1	8	0	0	4.087976833828202	
i 1	51.26189795918367	3.2825	72	899	6	5	5	0	0	0	0	0	0	3.0	
i 1	51.26261904761905	1.7675	77	899	4	1	2	16	0	2	16	0	0	9.0	
i 1	51.500360544217685	0.2525	69	583	4	5	5	1	0	-1	1	0	0	3.0	
i 1	51.73521768707483	1.7675	74	196	5	1	2	17	0	1	17	0	0	9.0	
i 1	51.736659863945576	3.7875	70	196	2	20	10	2	0	-2	2	0	0	4.087976833828202	
i 1	51.73738095238095	0.2525	69	583	4	5	7	0	0	0	0	0	0	3.0	
i 1	51.73810204081633	1.5150000000000001	74	196	5	4	11	2	0	-1	2	0	0	9.003796959404667	
i 1	51.740265306122446	2.7775	69	1165	4	5	16	1	0	0	1	0	0	3.0	
i 1	51.74242857142857	0.2525	77	899	4	1	15	17	0	2	17	0	0	9.0	
i 1	51.743149659863946	2.02	74	1165	5	9	12	8	0	-2	8	0	0	8.003796959404667	
i 1	51.743149659863946	16.16	61	196	1	27	16	16	0	252	16	307	0	5.92693010167075	
i 1	51.743149659863946	0.2525	73	1165	2	20	3	8	0	-1	8	0	0	4.087976833828202	
i 1	51.749639455782315	0.505	69	1165	4	5	12	1	0	-1	1	0	0	3.0	
i 1	51.75901360544218	2.2725	73	1165	3	24	15	2	0	-1	2	0	0	8.087976833828202	
i 1	51.759734693877554	1.2625	77	1165	4	1	10	16	0	1	16	0	0	9.0	
i 1	51.759734693877554	2.7775	70	1165	3	20	9	8	0	-2	8	0	0	4.087976833828202	
i 1	52.000360544217685	0.2525	70	583	2	24	10	2	0	-2	2	0	0	8.087976833828202	
i 1	52.0082925170068	0.2525	72	196	3	5	12	0	0	-1	0	0	0	3.0	
i 1	52.233054421768706	1.2625	69	196	3	5	9	1	0	0	1	0	0	3.0	
i 1	52.24747619047619	2.525	74	583	4	24	5	16	0	1	16	0	0	12.0	
i 1	52.249639455782315	2.525	74	196	5	24	9	17	0	2	17	0	0	12.0	
i 1	52.26189795918367	1.5150000000000001	71	899	6	2	7	2	0	-1	2	0	0	9.003796959404667	
i 1	52.49747619047619	0.2525	70	899	2	20	7	8	0	-2	8	0	0	4.087976833828202	
i 1	52.73521768707483	3.7875	71	899	6	2	1	8	0	-2	8	0	0	9.003796959404667	
i 1	52.750360544217685	1.2625	70	1165	2	20	2	2	0	-1	2	0	0	4.087976833828202	
i 1	52.75468707482993	3.7875	71	1165	5	9	16	8	0	-1	8	0	0	8.003796959404667	
i 1	53.00612925170068	1.01	73	196	1	20	1	8	0	-2	8	0	0	4.087976833828202	
i 1	53.499639455782315	0.2525	77	899	4	1	9	17	0	2	17	0	0	9.0	
i 1	53.51189795918367	0.2525	77	899	4	1	8	16	0	2	16	0	0	9.0	
i 1	53.514061224489794	2.2725	72	196	3	5	3	0	0	-1	0	0	0	3.0	
i 1	53.735938775510206	0.2525	74	583	5	3	12	8	0	-1	8	0	0	9.003796959404667	
i 1	53.73810204081633	0.505	74	583	4	4	14	2	0	-2	2	0	0	9.003796959404667	
i 1	53.743149659863946	0.2525	74	196	5	1	5	17	0	1	17	0	0	9.0	
i 1	53.759734693877554	2.2725	77	583	4	1	16	17	0	1	17	0	0	9.0	
i 1	53.98449659863945	2.02	74	196	3	1	16	17	0	1	17	0	0	9.0	
i 1	53.99531292517007	0.2525	73	899	2	20	10	2	0	-2	2	0	0	4.087976833828202	
i 1	54.00540816326531	0.2525	70	583	2	20	8	8	0	-2	8	0	0	4.087976833828202	
i 1	54.235938775510206	0.2525	73	1165	2	20	7	2	0	-1	2	0	0	4.087976833828202	
i 1	54.24098639455782	1.7675	73	196	1	20	11	2	0	-2	2	0	0	4.087976833828202	
i 1	54.250360544217685	0.2525	74	196	5	4	5	2	0	-1	2	0	0	9.003796959404667	
i 1	54.25757142857143	1.7675	70	1165	2	20	6	8	0	-1	8	0	0	4.087976833828202	
i 1	54.48233333333334	0.2525	71	899	6	2	11	2	0	-1	2	0	0	9.003796959404667	
i 1	54.483054421768706	0.2525	74	1165	5	9	4	8	0	-2	8	0	0	8.003796959404667	
i 1	54.4917074829932	2.525	73	1165	2	24	4	2	0	-1	2	0	0	8.087976833828202	
i 1	54.49387074829932	1.5150000000000001	73	196	1	24	13	2	0	-2	2	0	0	8.087976833828202	
i 1	54.50757142857143	4.2925	69	1165	4	5	14	1	0	-1	1	0	0	3.0	
i 1	54.73449659863945	0.505	74	583	5	3	2	8	0	-1	8	0	0	9.003796959404667	
i 1	54.7388231292517	0.2525	77	899	6	1	8	17	0	2	17	0	0	9.0	
i 1	54.750360544217685	2.2725	70	1165	3	20	4	8	0	-2	8	0	0	4.087976833828202	
i 1	54.763340136054424	6.0600000000000005	77	1165	4	1	14	16	0	1	16	0	0	9.0	
i 1	55.00540816326531	0.505	74	1165	5	9	11	8	0	-2	8	0	0	8.003796959404667	
i 1	55.013340136054424	2.02	77	899	4	1	13	16	0	2	16	0	0	9.0	
i 1	55.50180272108844	4.04	74	583	5	3	9	8	0	-1	8	0	0	9.003796959404667	
i 1	55.5082925170068	4.04	74	196	5	3	12	2	0	-1	2	0	0	9.003796959404667	
i 1	55.5082925170068	0.2525	69	1165	4	5	13	1	0	0	1	0	0	3.0	
i 1	55.75180272108844	1.5150000000000001	69	583	6	5	3	1	0	-1	1	0	0	3.0	
i 1	55.75612925170068	1.7675	69	196	3	5	2	1	0	0	1	0	0	3.0	
i 1	56.01766666666666	0.2525	73	583	2	24	3	8	0	-1	8	0	0	8.087976833828202	
i 1	56.24242857142857	0.2525	70	196	1	24	9	8	0	-1	8	0	0	8.087976833828202	
i 1	56.246034013605446	0.2525	73	196	1	20	5	2	0	-2	2	0	0	4.087976833828202	
i 1	56.73449659863945	0.2525	70	196	1	24	4	8	0	-2	8	0	0	8.087976833828202	
i 1	56.740265306122446	0.2525	70	196	1	20	12	8	0	-2	8	0	0	4.087976833828202	
i 1	56.75252380952381	0.2525	71	1165	5	9	2	8	0	-1	8	0	0	8.003796959404667	
i 1	56.75612925170068	0.2525	73	1165	2	20	1	2	0	-2	2	0	0	4.087976833828202	
i 1	56.76261904761905	0.2525	70	1165	2	20	4	8	0	-2	8	0	0	4.087976833828202	
i 1	56.986659863945576	1.2625	70	1165	2	20	7	8	0	-2	8	0	0	5.018084618446634	
i 1	56.98738095238095	0.505	70	1165	2	20	7	8	0	-2	8	0	0	5.018084618446634	
i 1	56.9888231292517	3.0300000000000002	74	1165	5	9	10	8	0	-2	8	0	0	8.003796959404667	
i 1	56.9888231292517	0.505	70	196	1	20	11	8	0	-2	8	0	0	5.018084618446634	
i 1	56.99387074829932	4.04	77	899	6	1	8	16	0	2	16	0	0	9.0	
i 1	56.99747619047619	1.2625	70	196	2	20	12	2	0	-2	2	0	0	5.018084618446634	
i 1	56.99891836734694	3.0300000000000002	70	196	2	24	15	2	0	-2	2	0	0	9.018084618446634	
i 1	57.000360544217685	10.8575	73	1165	2	24	12	2	0	-1	2	0	0	9.018084618446634	
i 1	57.00757142857143	9.09	61	899	5	25	4	16	0	2	16	0	0	5.334237091503674	
i 1	57.49747619047619	0.2525	70	899	2	20	6	8	0	-2	8	0	0	5.018084618446634	
i 1	57.503244897959185	0.2525	70	583	2	24	6	8	0	-1	8	0	0	9.018084618446634	
i 1	57.5082925170068	1.5150000000000001	72	196	3	5	12	0	0	-1	0	0	0	3.0	
i 1	57.51189795918367	0.2525	72	899	6	5	5	0	0	0	0	0	0	3.0	
i 1	57.51478231292517	0.2525	73	899	2	20	5	2	0	-1	2	0	0	5.018084618446634	
i 1	57.7388231292517	1.2625	70	196	1	24	3	2	0	-2	2	0	0	9.018084618446634	
i 1	57.98521768707483	1.2625	74	196	3	1	14	17	0	1	17	0	0	9.0	
i 1	57.99387074829932	4.2925	69	1165	4	5	13	1	0	0	1	0	0	3.0	
i 1	58.003244897959185	4.2925	72	899	6	5	12	0	0	0	0	0	0	3.0	
i 1	58.24819727891156	0.2525	74	196	5	4	15	2	0	-1	2	0	0	9.003796959404667	
i 1	58.485938775510206	0.505	70	196	1	20	11	2	0	-2	2	0	0	5.018084618446634	
i 1	58.49747619047619	1.5150000000000001	71	899	6	2	5	2	0	-1	2	0	0	9.003796959404667	
i 1	58.50901360544218	2.02	70	1165	2	20	13	8	0	-2	8	0	0	5.018084618446634	
i 1	58.7388231292517	4.04	70	196	2	20	10	2	0	-2	2	0	0	5.018084618446634	
i 1	58.985938775510206	0.505	70	583	2	24	3	8	0	-1	8	0	0	9.018084618446634	
i 1	58.99531292517007	0.505	73	899	2	20	16	2	0	-2	2	0	0	5.018084618446634	
i 1	59.00468707482993	2.02	69	583	6	5	5	1	0	-1	1	0	0	3.0	
i 1	59.01622448979592	0.505	70	583	2	20	10	2	0	-2	2	0	0	5.018084618446634	
i 1	59.01766666666666	2.02	69	196	3	5	3	1	0	0	1	0	0	3.0	
i 1	59.250360544217685	0.2525	74	196	3	24	13	17	0	2	17	0	0	12.0	
i 1	59.260455782312924	0.505	74	1165	4	1	13	17	0	2	17	0	0	9.0	
i 1	59.49098639455782	0.2525	77	899	6	1	8	17	0	2	17	0	0	9.0	
i 1	59.740265306122446	0.2525	70	899	2	20	14	2	0	-2	2	0	0	5.018084618446634	
i 1	59.753244897959185	0.2525	70	583	2	24	15	8	0	-1	8	0	0	9.018084618446634	
i 1	59.98738095238095	7.8275	61	899	5	25	13	1	0	1	1	0	0	5.334237091503674	
i 1	59.989544217687076	0.2525	71	1165	5	9	13	8	0	-1	8	0	0	8.003796959404667	
i 1	59.993149659863946	0.2525	74	583	5	3	3	8	0	-1	8	0	0	9.003796959404667	
i 1	59.99459183673469	6.565	70	196	1	24	8	2	0	-2	2	0	0	9.018084618446634	
i 1	60.00540816326531	4.545	70	196	1	24	7	2	0	-1	2	0	0	9.018084618446634	
i 1	60.263340136054424	2.525	71	899	6	2	10	2	0	-1	2	0	0	9.003796959404667	
i 1	60.263340136054424	2.525	74	1165	5	9	7	8	0	-2	8	0	0	8.003796959404667	
i 1	60.4888231292517	2.2725	70	196	1	20	10	2	0	-2	2	0	0	5.018084618446634	
i 1	61.000360544217685	1.7675	72	196	3	5	16	0	0	-1	0	0	0	3.0	
i 1	61.014061224489794	0.2525	69	899	6	5	2	1	0	-1	1	0	0	3.0	
i 1	61.240265306122446	1.5150000000000001	69	583	6	5	14	0	0	0	0	0	0	3.0	
i 1	61.246755102040815	0.2525	71	899	6	2	9	8	0	-2	8	0	0	9.003796959404667	
i 1	61.49747619047619	0.2525	74	196	5	4	13	2	0	-1	2	0	0	9.003796959404667	
i 1	61.516945578231294	0.2525	74	196	5	3	5	2	0	-1	2	0	0	9.003796959404667	
i 1	61.76478231292517	2.7775	71	899	6	2	1	8	0	-2	8	0	0	9.003796959404667	
i 1	62.74387074829932	0.2525	74	196	5	3	12	2	0	-1	2	0	0	9.003796959404667	
i 1	62.74459183673469	0.505	74	196	5	4	9	2	0	-1	2	0	0	9.003796959404667	
i 1	62.75540816326531	0.2525	69	1165	4	5	8	1	0	0	1	0	0	3.0	
i 1	62.75540816326531	1.7675	69	196	3	5	4	1	0	0	1	0	0	3.0	
i 1	62.76189795918367	4.04	77	1165	4	1	3	16	0	1	16	0	0	9.0	
i 1	62.98449659863945	0.2525	71	899	6	2	3	2	0	-1	2	0	0	9.003796959404667	
i 1	63.01261904761905	4.7975	61	583	5	25	10	1	0	1	1	0	0	5.334237091503674	
i 1	63.01478231292517	0.2525	72	196	3	5	1	0	0	-1	0	0	0	3.0	
i 1	63.25252380952381	0.2525	74	1165	5	9	15	8	0	-2	8	0	0	8.003796959404667	
i 1	63.25252380952381	1.2625	69	583	6	5	9	1	0	-1	1	0	0	3.0	
i 1	63.26622448979592	4.545	74	583	5	3	1	8	0	-1	8	0	0	9.003796959404667	
i 1	63.49098639455782	4.04	74	196	5	3	10	2	0	-1	2	0	0	9.003796959404667	
i 1	63.9917074829932	3.7875	70	1165	2	20	14	8	0	-2	8	0	0	5.018084618446634	
i 1	63.99459183673469	0.505	70	196	1	20	4	2	0	-2	2	0	0	5.018084618446634	
i 1	63.996755102040815	1.2625	74	196	3	24	2	17	0	2	17	0	0	12.0	
i 1	64.24026530612245	1.2625	70	196	1	20	10	2	0	-2	2	0	0	5.018084618446634	
i 1	64.48738095238095	2.02	69	583	6	5	4	0	0	0	0	0	0	3.0	
i 1	64.49098639455782	0.2525	70	583	2	24	7	8	0	-2	8	0	0	9.018084618446634	
i 1	64.49747619047619	2.02	72	196	3	5	16	0	0	-1	0	0	0	3.0	
i 1	64.50685034013605	1.5150000000000001	74	1165	5	9	11	8	0	-2	8	0	0	8.003796959404667	
i 1	64.51622448979592	0.2525	70	899	2	20	4	8	0	-2	8	0	0	5.018084618446634	
i 1	64.73521768707484	1.7675	70	1165	2	20	5	8	0	-1	8	0	0	5.018084618446634	
i 1	64.76334013605442	0.7575000000000001	73	196	1	20	2	8	0	-2	8	0	0	5.018084618446634	
i 1	65.24891836734695	0.2525	74	1165	4	1	3	17	0	2	17	0	0	9.0	
i 1	65.49026530612245	2.2725	72	899	6	5	3	0	0	0	0	0	0	3.0	
i 1	65.49242857142858	2.2725	69	1165	6	5	11	1	0	0	1	0	0	3.0	
i 1	65.49891836734695	2.2725	74	196	3	1	8	17	0	1	17	0	0	9.0	
i 1	65.5140612244898	0.2525	74	196	3	24	4	17	0	2	17	0	0	12.0	
i 1	65.73377551020408	2.02	77	583	6	1	10	17	0	1	17	0	0	9.0	
i 1	65.98665986394558	1.7675	61	899	5	25	7	16	0	2	16	0	0	5.334237091503674	
i 1	66.00108163265305	0.2525	74	1165	5	9	14	8	0	-2	8	0	0	8.003796959404667	
i 1	66.01478231292516	1.7675	63	583	5	25	13	16	0	2	16	0	0	5.334237091503674	
i 1	66.50829251700681	1.2625	74	1165	5	9	6	8	0	-2	8	0	0	8.003796959404667	
i 1	66.5111768707483	0.2525	69	899	6	5	16	1	0	-1	1	0	0	3.0	
i 1	66.73233333333333	0.2525	74	1165	6	1	12	17	0	2	17	0	0	9.0	
i 1	66.75685034013605	1.01	69	196	7	5	5	1	0	0	1	0	0	3.0	
i 1	66.75757142857142	1.01	70	196	1	24	3	2	0	-2	2	0	0	9.018084618446634	
i 1	66.99531292517007	0.7575000000000001	77	899	6	1	15	16	0	2	16	0	0	9.0	
i 1	67.23449659863945	0.505	69	1165	6	5	15	1	0	-1	1	0	0	3.0	
i 1	67.24675510204082	0.505	74	583	4	24	7	16	0	1	16	0	0	12.0	
i 1	67.24891836734695	0.505	71	1165	5	9	4	8	0	-1	8	0	0	8.003796959404667	
i 1	67.25108163265305	0.505	73	196	1	20	2	8	0	-2	8	0	0	5.018084618446634	
i 1	67.25973469387755	0.505	74	1165	6	1	1	17	0	2	17	0	0	9.0	
i 1	67.26550340136055	0.505	69	583	6	5	12	0	0	0	0	0	0	3.0	
i 1	67.50757142857142	0.2525	70	196	1	20	4	2	0	-2	2	0	0	5.018084618446634	
i 1	67.73449659863945	4.2925	61	197	6	25	2	1	0	1	1	0	0	5.334237091503674	
i 1	67.73521768707484	10.352500000000001	63	695	1	27	16	1	0	252	1	307	0	5.92693010167075	
i 1	67.73665986394558	1.01	69	197	7	5	11	1	0	0	1	0	0	3.0	
i 1	67.73738095238095	0.505	72	695	6	5	10	0	0	0	0	0	0	3.0	
i 1	67.74026530612245	0.505	74	1081	5	9	15	8	0	-2	8	0	0	8.003796959404667	
i 1	67.74170748299319	1.2625	74	197	5	24	16	16	0	1	16	0	0	12.0	
i 1	67.74387074829932	4.2925	63	695	5	25	2	16	0	1	16	0	0	5.334237091503674	
i 1	67.7445918367347	1.5150000000000001	77	1081	5	1	10	16	0	1	16	0	0	9.0	
i 1	67.74531292517007	2.02	71	695	6	2	1	8	0	-1	8	0	0	9.003796959404667	
i 1	67.75180272108844	0.7575000000000001	70	695	1	24	10	8	0	248	8	308	0	9.018084618446634	
i 1	67.75324489795918	0.2525	71	695	4	4	8	8	0	-1	8	0	0	9.003796959404667	
i 1	67.75468707482993	2.02	69	1081	6	5	9	1	0	0	1	0	0	3.0	
i 1	67.75973469387755	0.2525	74	695	2	1	8	17	0	1	17	0	0	9.0	
i 1	67.76045578231293	1.2625	63	695	5	25	10	16	0	2	16	0	0	5.334237091503674	
i 1	67.76334013605442	0.505	77	1081	3	1	16	17	0	1	17	0	0	9.0	
i 1	67.76478231292516	2.525	77	197	6	1	6	16	0	2	16	0	0	9.0	
i 1	67.76478231292516	7.3225	63	197	6	25	5	1	0	2	1	0	0	5.334237091503674	
i 1	67.76622448979592	2.02	69	197	7	5	13	0	0	0	0	0	0	3.0	
i 1	67.76694557823129	6.8175	70	1081	1	20	7	2	0	-2	2	0	0	5.018084618446634	
i 1	68.0140612244898	2.2725	77	695	2	24	12	17	0	2	17	0	0	12.0	
i 1	68.49819727891156	0.2525	73	695	2	20	8	8	0	-2	8	0	0	5.018084618446634	
i 1	68.49891836734695	0.2525	69	695	6	5	7	0	0	-1	0	0	0	3.0	
i 1	68.50468707482993	2.7775	74	695	4	3	5	2	0	-2	2	0	0	9.003796959404667	
i 1	68.73449659863945	0.2525	72	695	6	5	16	1	0	-1	1	0	0	3.0	
i 1	68.73665986394558	3.7875	72	1081	6	5	11	0	0	-1	0	0	0	3.0	
i 1	68.74026530612245	1.01	73	1081	1	20	11	2	0	-1	2	0	0	5.018084618446634	
i 1	68.98521768707484	9.09	61	1081	4	26	6	1	0	1	1	0	0	5.334237091503674	
i 1	68.99098639455782	0.2525	77	1081	5	1	8	17	0	1	17	0	0	9.0	
i 1	68.99098639455782	2.02	69	197	7	5	9	1	0	0	1	0	0	3.0	
i 1	69.0054081632653	1.01	71	1081	5	9	4	8	0	-2	8	0	0	8.003796959404667	
i 1	69.01261904761905	6.0600000000000005	63	695	5	25	1	16	0	2	16	0	0	5.334237091503674	
i 1	69.23449659863945	6.0600000000000005	74	695	6	1	13	17	0	2	17	0	0	9.0	
i 1	69.48665986394558	2.2725	74	197	5	24	7	16	0	1	16	0	0	12.0	
i 1	69.51766666666667	2.525	77	1081	5	1	12	16	0	1	16	0	0	9.0	
i 1	69.73305442176871	0.2525	70	695	2	20	9	2	0	-1	2	0	0	5.018084618446634	
i 1	69.73954421768707	2.525	73	1081	1	24	13	2	0	-2	2	0	0	9.018084618446634	
i 1	69.74242857142858	0.2525	73	197	2	20	9	2	0	-1	2	0	0	5.018084618446634	
i 1	69.75612925170068	0.2525	70	197	2	24	15	8	0	-2	8	0	0	9.018084618446634	
i 1	69.99675510204082	2.02	73	1081	1	20	9	2	0	-1	2	0	0	5.018084618446634	
i 1	70.51622448979592	0.2525	77	695	6	1	5	16	0	2	16	0	0	9.0	
i 1	70.98449659863945	1.01	74	695	2	1	10	17	0	1	17	0	0	9.0	
i 1	70.99963945578232	2.02	71	1081	5	9	12	8	0	-2	8	0	0	8.003796959404667	
i 1	71.00829251700681	2.02	69	197	7	5	6	0	0	0	0	0	0	3.0	
i 1	71.98377551020408	3.0300000000000002	74	695	4	1	5	17	0	1	17	0	0	9.0	
i 1	71.98738095238095	0.2525	77	1081	5	1	4	17	0	1	17	0	0	9.0	
i 1	71.98810204081633	0.2525	69	695	6	5	3	1	0	0	1	0	0	3.0	
i 1	72.00036054421768	6.0600000000000005	61	197	6	25	16	1	0	1	1	0	0	5.334237091503674	
i 1	72.00108163265305	9.09	63	1081	4	26	3	16	0	2	16	0	0	5.334237091503674	
i 1	72.00901360544218	13.8875	63	695	5	25	11	16	0	1	16	0	0	5.334237091503674	
i 1	72.25901360544218	2.7775	77	695	2	24	13	17	0	2	17	0	0	12.0	
i 1	72.25901360544218	0.2525	69	197	7	5	13	1	0	0	1	0	0	3.0	
i 1	72.48305442176871	1.01	69	695	5	5	2	0	0	-1	0	0	0	3.0	
i 1	72.76189795918367	2.2725	69	695	6	5	15	1	0	0	1	0	0	3.0	
i 1	73.23233333333333	0.2525	74	1081	5	9	11	8	0	-2	8	0	0	8.003796959404667	
i 1	73.26694557823129	4.04	71	1081	5	9	7	8	0	-2	8	0	0	8.003796959404667	
i 1	73.4945918367347	0.2525	69	197	7	5	7	0	0	0	0	0	0	3.0	
i 1	73.50108163265305	0.2525	72	1081	6	5	16	0	0	-1	0	0	0	3.0	
i 1	73.9859387755102	0.2525	69	197	7	5	7	0	0	0	0	0	0	3.0	
i 1	74.23810204081633	0.7575000000000001	73	1081	1	24	11	2	0	-2	2	0	0	9.018084618446634	
i 1	74.25829251700681	1.2625	69	695	5	5	15	0	0	-1	0	0	0	3.0	
i 1	74.50468707482993	0.2525	74	695	6	2	4	8	0	-2	8	0	0	9.003796959404667	
i 1	74.74242857142858	1.7675	69	197	7	5	6	0	0	0	0	0	0	3.0	
i 1	74.74531292517007	0.2525	70	1081	1	20	6	2	0	-2	2	0	0	5.018084618446634	
i 1	74.76189795918367	0.2525	71	197	5	4	16	2	0	-2	2	0	0	9.003796959404667	
i 1	74.76766666666667	1.7675	69	1081	6	5	4	1	0	0	1	0	0	3.0	
i 1	74.9888231292517	6.0600000000000005	63	197	6	25	8	1	0	2	1	0	0	5.334237091503674	
i 1	74.98954421768707	9.09	61	695	3	27	4	1	0	1	1	0	0	5.92693010167075	
i 1	74.99314965986395	0.7575000000000001	73	1081	1	24	13	2	0	-2	2	0	0	8.00466493427608	
i 1	75.01334013605442	10.8575	63	695	5	25	1	16	0	2	16	0	0	5.334237091503674	
i 1	75.01478231292516	0.7575000000000001	73	1081	3	20	7	2	0	-1	2	0	0	4.0046649342760805	
i 1	75.24531292517007	0.2525	69	695	6	5	10	1	0	0	1	0	0	3.0	
i 1	75.25108163265305	1.01	71	197	5	4	15	2	0	-2	2	0	0	9.003796959404667	
i 1	75.25829251700681	0.2525	77	695	6	1	11	16	0	2	16	0	0	9.0	
i 1	75.26045578231293	1.01	74	1081	5	9	15	8	0	-2	8	0	0	8.003796959404667	
i 1	75.50829251700681	1.7675	72	695	5	5	4	1	0	-1	1	0	0	3.0	
i 1	76.25468707482993	1.7675	74	695	6	2	13	8	0	-2	8	0	0	9.003796959404667	
i 1	76.49170748299319	1.2625	73	1081	1	24	1	2	0	-2	2	0	0	8.00466493427608	
i 1	76.49747619047619	2.02	69	197	5	5	3	1	0	0	1	0	0	3.0	
i 1	76.50036054421768	0.2525	74	695	6	1	4	17	0	2	17	0	0	9.0	
i 1	76.50396598639456	1.2625	73	1081	3	20	4	2	0	-1	2	0	0	4.0046649342760805	
i 1	76.75757142857142	0.2525	74	197	5	24	10	16	0	1	16	0	0	12.0	
i 1	77.23521768707484	0.7575000000000001	70	1081	1	20	2	8	0	-2	8	0	0	4.0046649342760805	
i 1	77.24387074829932	0.2525	72	695	6	5	13	0	0	0	0	0	0	3.0	
i 1	77.2445918367347	2.2725	70	1081	1	20	1	2	0	-2	2	0	0	4.0046649342760805	
i 1	77.48810204081633	0.2525	69	1081	6	5	7	1	0	0	1	0	0	3.0	
i 1	77.49242857142858	0.2525	74	1081	5	9	9	8	0	-2	8	0	0	8.003796959404667	
i 1	77.74819727891156	0.2525	74	197	5	24	10	16	0	1	16	0	0	12.0	
i 1	77.75685034013605	0.2525	69	695	5	5	14	0	0	-1	0	0	0	3.0	
i 1	77.98665986394558	7.8275	63	695	3	27	2	1	0	1	1	0	0	5.92693010167075	
i 1	77.98738095238095	1.01	74	695	6	1	3	17	0	2	17	0	0	9.0	
i 1	77.99242857142858	7.8275	61	197	5	25	3	1	0	1	1	0	0	5.334237091503674	
i 1	77.99603401360544	6.0600000000000005	61	1081	4	26	13	1	0	1	1	0	0	5.334237091503674	
i 1	77.99747619047619	0.2525	77	1081	5	1	6	17	0	1	17	0	0	9.0	
i 1	77.99891836734695	1.2625	74	695	4	2	2	8	0	-2	8	0	0	9.003796959404667	
i 1	78.00468707482993	1.01	72	695	6	5	11	1	0	-1	1	0	0	3.0	
i 1	78.01189795918367	0.505	70	1081	3	20	7	8	0	-2	8	0	0	4.0046649342760805	
i 1	78.23305442176871	2.2725	69	197	5	5	7	0	0	0	0	0	0	3.0	
i 1	78.24242857142858	0.2525	71	1081	5	9	9	8	0	-2	8	0	0	8.003796959404667	
i 1	78.25036054421768	0.2525	77	695	4	24	13	17	0	2	17	0	0	12.0	
i 1	78.25757142857142	2.2725	69	1081	6	5	16	1	0	0	1	0	0	3.0	
i 1	78.48738095238095	1.5150000000000001	74	197	5	24	11	16	0	1	16	0	0	12.0	
i 1	78.50829251700681	1.5150000000000001	77	1081	5	1	6	16	0	1	16	0	0	9.0	
i 1	78.5111768707483	0.7575000000000001	73	197	2	20	15	2	0	-2	2	0	0	4.0046649342760805	
i 1	78.51766666666667	0.505	70	695	4	20	5	2	0	-1	2	0	0	4.0046649342760805	
i 1	78.73521768707484	0.505	73	197	2	24	15	8	0	-1	8	0	0	8.00466493427608	
i 1	78.74603401360544	0.505	70	695	4	20	9	8	0	-1	8	0	0	4.0046649342760805	
i 1	78.75468707482993	1.5150000000000001	73	1081	1	24	16	2	0	-2	2	0	0	8.00466493427608	
i 1	78.99603401360544	0.2525	77	695	4	24	6	17	0	2	17	0	0	12.0	
i 1	79.01478231292516	0.2525	69	695	5	5	3	0	0	-1	0	0	0	3.0	
i 1	79.23810204081633	0.2525	77	695	6	1	10	16	0	2	16	0	0	9.0	
i 1	79.25396598639456	1.01	70	1081	3	20	12	2	0	-2	2	0	0	4.0046649342760805	
i 1	79.25829251700681	0.505	72	695	6	5	2	0	0	0	0	0	0	3.0	
i 1	79.48954421768707	1.2625	74	695	4	1	7	17	0	1	17	0	0	9.0	
i 1	79.51334013605442	1.5150000000000001	74	695	6	1	11	17	0	2	17	0	0	9.0	
i 1	79.73377551020408	0.2525	72	695	6	5	2	1	0	-1	1	0	0	3.0	
i 1	79.74963945578232	0.505	70	1081	3	20	10	2	0	-1	2	0	0	4.0046649342760805	
i 1	79.76045578231293	0.7575000000000001	70	1081	1	20	12	2	0	-2	2	0	0	4.0046649342760805	
i 1	79.98233333333333	1.01	72	695	6	5	16	0	0	0	0	0	0	3.0	
i 1	79.98377551020408	0.2525	77	695	6	1	16	16	0	2	16	0	0	9.0	
i 1	79.98521768707484	5.3025	71	1081	5	9	4	8	0	-2	8	0	0	8.003796959404667	
i 1	79.99387074829932	0.7575000000000001	69	695	5	5	4	0	0	-1	0	0	0	3.0	
i 1	80.23233333333333	1.7675	69	197	5	5	3	1	0	0	1	0	0	3.0	
i 1	80.23305442176871	3.7875	77	695	4	24	13	17	0	2	17	0	0	12.0	
i 1	80.2359387755102	0.7575000000000001	77	197	6	1	2	16	0	2	16	0	0	9.0	
i 1	80.24026530612245	0.2525	70	197	2	20	4	8	0	-1	8	0	0	4.0046649342760805	
i 1	80.48377551020408	0.2525	74	695	4	2	5	8	0	-2	8	0	0	9.003796959404667	
i 1	80.5054081632653	0.2525	70	1081	3	20	7	8	0	-2	8	0	0	4.0046649342760805	
i 1	80.74603401360544	0.2525	71	197	6	3	6	8	0	-2	8	0	0	9.003796959404667	
i 1	80.99531292517007	4.7975	63	197	5	25	13	1	0	2	1	0	0	5.334237091503674	
i 1	81.00252380952381	2.525	70	695	2	20	1	2	0	-2	2	0	0	4.0046649342760805	
i 1	81.01478231292516	0.2525	72	695	4	5	2	1	0	-1	1	0	0	3.0	
i 1	81.01694557823129	4.7975	63	1081	4	26	4	16	0	2	16	0	0	5.334237091503674	
i 1	81.26622448979592	1.5150000000000001	72	695	6	5	1	0	0	0	0	0	0	3.0	
i 1	81.48665986394558	2.02	70	1081	3	20	15	8	0	-2	8	0	0	4.0046649342760805	
i 1	81.49098639455782	0.7575000000000001	74	695	4	1	11	17	0	1	17	0	0	9.0	
i 1	81.4945918367347	1.01	71	197	4	3	15	8	0	-2	8	0	0	9.003796959404667	
i 1	81.4945918367347	2.02	70	1081	1	20	9	2	0	-2	2	0	0	4.0046649342760805	
i 1	81.50396598639456	0.7575000000000001	71	695	4	4	10	8	0	-1	8	0	0	9.003796959404667	
i 1	81.50468707482993	1.01	74	695	6	1	6	17	0	2	17	0	0	9.0	
i 1	82.24963945578232	1.7675	69	1081	4	5	8	1	0	0	1	0	0	3.0	
i 1	82.25973469387755	1.7675	69	197	5	5	4	0	0	0	0	0	0	3.0	
i 1	82.48738095238095	0.2525	74	197	5	24	11	16	0	1	16	0	0	12.0	
i 1	82.76694557823129	0.2525	69	197	5	5	12	1	0	0	1	0	0	3.0	
i 1	82.98665986394558	0.2525	77	1081	5	1	13	17	0	1	17	0	0	9.0	
i 1	82.99098639455782	0.2525	69	695	6	5	16	0	0	-1	0	0	0	3.0	
i 1	83.01189795918367	1.5150000000000001	70	1081	3	20	11	2	0	-1	2	0	0	4.0046649342760805	
i 1	83.24026530612245	1.7675	77	1081	5	1	11	16	0	1	16	0	0	9.0	
i 1	83.24963945578232	0.2525	69	695	6	5	2	1	0	0	1	0	0	3.0	
i 1	83.50036054421768	0.505	72	695	4	5	10	1	0	-1	1	0	0	3.0	
i 1	83.50612925170068	0.505	72	1081	6	5	16	0	0	-1	0	0	0	3.0	
i 1	83.98233333333333	1.7675	61	695	3	27	16	1	0	1	1	0	0	5.92693010167075	
i 1	83.98449659863945	1.7675	69	197	7	5	1	1	0	0	1	0	0	3.0	
i 1	83.98521768707484	0.505	72	695	5	5	4	1	0	-1	1	0	0	3.0	
i 1	83.98665986394558	1.01	74	197	5	24	8	16	0	1	16	0	0	12.0	
i 1	83.99819727891156	0.505	72	1081	4	5	14	0	0	-1	0	0	0	3.0	
i 1	84.00685034013605	1.7675	61	1081	4	26	13	1	0	1	1	0	0	5.334237091503674	
i 1	84.00973469387755	1.2625	71	695	6	2	8	8	0	-1	8	0	0	9.003796959404667	
i 1	84.01045578231293	1.01	70	695	2	24	2	8	0	-2	8	0	0	8.00466493427608	
i 1	84.01622448979592	0.2525	77	197	7	1	2	16	0	2	16	0	0	9.0	
i 1	84.24747619047619	0.2525	77	695	6	1	4	16	0	2	16	0	0	9.0	
i 1	84.25180272108844	0.2525	71	197	4	3	14	8	0	-2	8	0	0	9.003796959404667	
i 1	84.48233333333333	1.2625	77	197	7	1	5	16	0	2	16	0	0	9.0	
i 1	84.48521768707484	1.2625	77	695	4	24	12	17	0	2	17	0	0	12.0	
i 1	84.75252380952381	1.01	74	695	4	2	13	8	0	-2	8	0	0	9.003796959404667	
i 1	84.98665986394558	0.2525	77	695	6	1	3	16	0	2	16	0	0	9.0	
i 1	85.24098639455782	0.2525	71	695	4	4	2	8	0	-1	8	0	0	9.003796959404667	
i 1	85.25612925170068	0.2525	74	695	4	1	5	17	0	1	17	0	0	9.0	
i 1	85.48810204081633	0.2525	71	197	4	3	14	8	0	-2	8	0	0	9.003796959404667	
i 1	85.73233333333333	1.5150000000000001	69	199	5	5	8	1	5000	-1	1	0	0	3.0	
i 1	85.73377551020408	8.585	61	199	5	26	1	1	5000	2	1	0	0	5.334237091503674	
i 1	85.73665986394558	0.505	69	199	7	5	5	0	0	0	0	0	0	3.0	
i 1	85.73954421768707	8.585	61	901	5	25	8	16	0	2	16	0	0	5.334237091503674	
i 1	85.74098639455782	1.2625	61	199	4	27	7	16	0	2	16	0	0	5.92693010167075	
i 1	85.74387074829932	3.2825	74	199	6	3	2	2	0	-1	2	0	0	9.003796959404667	
i 1	85.74675510204082	1.2625	61	199	5	26	5	1	5000	1	1	0	0	5.334237091503674	
i 1	85.74963945578232	4.2925	63	199	4	27	7	16	0	2	16	0	0	5.92693010167075	
i 1	85.75108163265305	4.2925	70	199	2	20	11	8	5000	-1	8	0	0	4.0046649342760805	
i 1	85.75468707482993	0.2525	73	199	1	20	7	8	0	-2	8	0	0	4.0046649342760805	
i 1	85.75757142857142	0.7575000000000001	69	585	5	5	13	0	0	0	0	0	0	3.0	
i 1	85.75973469387755	0.2525	74	585	6	1	14	17	0	2	17	0	0	9.0	
i 1	85.75973469387755	8.585	61	901	5	25	11	1	0	1	1	0	0	5.334237091503674	
i 1	85.76045578231293	1.01	77	585	4	24	6	17	0	2	17	0	0	12.0	
i 1	85.76045578231293	0.505	74	901	4	2	7	2	0	-1	2	0	0	9.003796959404667	
i 1	85.7611768707483	8.585	61	585	5	25	10	1	0	1	1	0	0	5.334237091503674	
i 1	85.7611768707483	1.2625	72	901	4	5	12	0	0	0	0	0	0	3.0	
i 1	85.76261904761905	8.585	63	585	5	25	11	1	0	2	1	0	0	5.334237091503674	
i 1	85.76550340136055	1.01	74	199	5	24	15	16	0	2	16	0	0	12.0	
i 1	85.9945918367347	0.2525	73	901	4	20	2	2	0	-1	2	0	0	4.0046649342760805	
i 1	86.01261904761905	0.2525	73	585	4	20	1	8	0	-1	8	0	0	4.0046649342760805	
i 1	86.23665986394558	1.2625	70	199	3	20	2	2	0	-2	2	0	0	4.0046649342760805	
i 1	86.23665986394558	0.7575000000000001	70	199	3	24	7	8	0	-2	8	0	0	8.00466493427608	
i 1	86.24387074829932	1.7675	77	901	6	1	2	16	0	2	16	0	0	9.0	
i 1	86.25468707482993	0.7575000000000001	73	199	1	20	5	8	0	-2	8	0	0	4.0046649342760805	
i 1	86.25901360544218	0.2525	74	199	6	9	6	8	5000	-1	8	0	0	8.003796959404667	
i 1	86.26334013605442	1.2625	70	199	4	20	13	8	0	-1	8	0	0	4.0046649342760805	
i 1	86.50685034013605	0.2525	74	199	5	4	2	2	0	-1	2	0	0	9.003796959404667	
i 1	86.50757142857142	0.2525	69	199	7	5	1	0	0	0	0	0	0	3.0	
i 1	86.75252380952381	0.2525	69	585	6	5	5	1	0	-1	1	0	0	3.0	
i 1	86.75396598639456	0.2525	74	901	6	1	14	17	0	1	17	0	0	9.0	
i 1	86.7611768707483	0.2525	74	901	4	2	4	2	0	-1	2	0	0	9.003796959404667	
i 1	86.76694557823129	0.2525	69	199	7	5	5	0	0	-1	0	0	0	3.0	
i 1	86.98233333333333	1.2625	69	199	4	5	4	0	0	-1	0	0	0	3.0	
i 1	86.98665986394558	0.7575000000000001	74	901	6	2	1	8	0	-2	8	0	0	9.003796959404667	
i 1	86.99170748299319	7.3225	61	199	5	26	16	1	5000	1	1	0	0	5.334237091503674	
i 1	87.00180272108844	6.0600000000000005	61	199	4	27	2	16	0	2	16	0	0	5.92693010167075	
i 1	87.0054081632653	0.2525	74	199	5	24	9	16	0	2	16	0	0	12.0	
i 1	87.0111768707483	1.2625	69	585	4	5	2	1	0	-1	1	0	0	3.0	
i 1	87.26189795918367	0.2525	69	199	7	5	16	0	0	0	0	0	0	3.0	
i 1	87.49819727891156	2.02	72	901	5	5	6	0	0	0	0	0	0	3.0	
i 1	87.50324489795918	0.2525	70	901	4	20	16	8	0	-2	8	0	0	4.0046649342760805	
i 1	87.50324489795918	0.2525	73	585	4	20	16	8	0	-2	8	0	0	4.0046649342760805	
i 1	87.51550340136055	0.7575000000000001	74	199	5	1	1	16	0	1	16	0	0	9.0	
i 1	87.51766666666667	0.7575000000000001	74	585	6	1	12	17	0	2	17	0	0	9.0	
i 1	87.75036054421768	1.7675	74	199	7	1	16	16	5000	1	16	0	0	9.0	
i 1	87.75757142857142	0.505	70	199	4	20	6	2	0	-2	2	0	0	4.0046649342760805	
i 1	87.7611768707483	0.2525	74	199	6	9	4	8	5000	-1	8	0	0	8.003796959404667	
i 1	88.00396598639456	0.2525	74	199	5	4	15	2	0	-1	2	0	0	9.003796959404667	
i 1	88.0140612244898	0.2525	70	199	3	20	1	8	0	-2	8	0	0	4.0046649342760805	
i 1	88.2445918367347	1.2625	71	199	4	9	10	2	5000	-2	2	0	0	8.003796959404667	
i 1	88.24603401360544	0.2525	69	199	7	5	2	0	0	0	0	0	0	3.0	
i 1	88.25685034013605	0.2525	77	901	6	1	1	16	0	2	16	0	0	9.0	
i 1	88.25901360544218	0.2525	70	901	4	20	3	8	0	-2	8	0	0	4.0046649342760805	
i 1	88.49891836734695	1.2625	74	901	6	2	3	8	0	-2	8	0	0	9.003796959404667	
i 1	88.51766666666667	0.2525	69	199	4	5	16	0	0	-1	0	0	0	3.0	
i 1	88.73305442176871	0.2525	70	585	4	20	4	2	0	-1	2	0	0	4.0046649342760805	
i 1	88.98810204081633	1.01	69	199	7	5	8	0	0	0	0	0	0	3.0	
i 1	89.00612925170068	1.01	74	585	4	4	5	8	0	-2	8	0	0	9.003796959404667	
i 1	89.01261904761905	0.7575000000000001	73	199	4	20	10	2	0	-1	2	0	0	4.0046649342760805	
i 1	89.01622448979592	1.01	74	199	5	4	4	2	0	-1	2	0	0	9.003796959404667	
i 1	89.48377551020408	3.2825	72	901	5	5	16	0	0	0	0	0	0	3.0	
i 1	89.4859387755102	0.505	72	199	5	5	8	0	5000	-1	0	0	0	3.0	
i 1	89.74747619047619	0.2525	71	585	4	3	5	2	0	-2	2	0	0	9.003796959404667	
i 1	89.76478231292516	0.2525	70	585	4	20	7	8	0	-2	8	0	0	4.0046649342760805	
i 1	89.98305442176871	2.2725	74	199	5	4	8	2	0	-1	2	0	0	11.483894163016764	
i 1	89.98665986394558	2.525	74	585	4	4	8	8	0	-2	8	0	0	11.483894163016764	
i 1	89.98954421768707	0.2525	72	901	5	5	1	0	0	0	0	0	0	3.0	
i 1	89.99891836734695	2.7775	72	199	7	5	9	0	5000	-1	0	0	0	3.0	
i 1	90.00973469387755	4.2925	63	199	4	27	4	16	0	2	16	0	0	5.92693010167075	
i 1	90.24026530612245	1.5150000000000001	77	585	4	24	15	17	0	2	17	0	0	3.0000000000000004	
i 1	90.24819727891156	1.7675	74	199	5	24	5	16	0	2	16	0	0	3.0000000000000004	
i 1	90.25973469387755	0.2525	69	585	5	5	9	1	0	-1	1	0	0	3.0	
i 1	90.50036054421768	0.2525	72	901	5	5	3	0	0	0	0	0	0	3.0	
i 1	90.50324489795918	0.7575000000000001	74	901	6	2	16	8	0	-2	8	0	0	11.483894163016764	
i 1	90.73665986394558	3.535	70	199	4	20	4	8	5000	-1	8	0	0	4.0046649342760805	
i 1	90.74026530612245	2.02	70	199	4	20	2	8	0	-2	8	0	0	4.0046649342760805	
i 1	90.75973469387755	2.02	73	199	4	24	8	8	5000	-2	8	0	0	8.00466493427608	
i 1	91.00973469387755	1.01	69	585	5	5	6	1	0	-1	1	0	0	3.0	
i 1	91.49531292517007	0.2525	71	199	4	9	16	2	5000	-2	2	0	0	10.483894163016764	
i 1	91.74963945578232	2.2725	74	199	4	9	15	8	5000	-1	8	0	0	10.483894163016764	
i 1	92.24819727891156	1.5150000000000001	69	199	4	5	3	0	0	0	0	0	0	3.0	
i 1	92.4859387755102	0.2525	71	585	5	3	9	2	0	-2	2	0	0	11.483894163016764	
i 1	92.73521768707484	1.5150000000000001	73	199	1	24	7	8	5000	252	8	307	0	8.00466493427608	
i 1	92.73665986394558	0.2525	74	199	5	4	12	2	0	-1	2	0	0	11.483894163016764	
i 1	92.7388231292517	1.5150000000000001	74	199	5	24	7	16	0	2	16	0	0	3.0000000000000004	
i 1	92.74098639455782	1.5150000000000001	73	199	1	20	5	8	0	-2	8	0	0	4.0046649342760805	
i 1	92.75829251700681	0.2525	70	901	4	20	11	2	0	-1	2	0	0	4.0046649342760805	
i 1	92.75901360544218	0.2525	72	901	5	5	8	0	0	0	0	0	0	3.0	
i 1	92.76189795918367	0.2525	70	585	4	20	8	8	0	-1	8	0	0	4.0046649342760805	
i 1	92.76478231292516	0.2525	70	585	4	24	10	2	0	-1	2	0	0	8.00466493427608	
i 1	92.98305442176871	1.2625	73	199	4	20	13	8	0	-1	8	0	0	4.0046649342760805	
i 1	92.9888231292517	1.2625	61	199	4	27	9	16	0	2	16	0	0	5.92693010167075	
i 1	92.99531292517007	0.2525	70	199	3	24	11	2	0	-2	2	0	0	8.00466493427608	
i 1	93.00685034013605	0.2525	72	199	4	5	14	0	5000	-1	0	0	0	3.0	
i 1	93.00757142857142	0.2525	74	901	6	2	16	8	0	-2	8	0	0	11.483894163016764	
i 1	93.0111768707483	0.7575000000000001	69	585	5	5	2	0	0	0	0	0	0	3.0	
i 1	93.23810204081633	1.01	69	199	7	5	13	1	5000	-1	1	0	0	3.0	
i 1	93.25901360544218	1.01	74	199	3	3	11	2	0	-1	2	0	0	11.483894163016764	
i 1	93.50468707482993	0.7575000000000001	71	585	5	3	5	2	0	-2	2	0	0	11.483894163016764	
i 1	93.99891836734695	0.2525	69	585	5	5	9	1	0	-1	1	0	0	3.0	
i 1	94.23233333333333	9.3425	61	199	5	26	1	1	5000	2	1	0	0	5.334237091503674	
i 1	94.23233333333333	1.5150000000000001	73	199	3	20	11	8	0	-1	8	0	0	4.0046649342760805	
i 1	94.23233333333333	1.7675	70	199	3	24	7	2	0	-2	2	0	0	8.00466493427608	
i 1	94.23810204081633	0.2525	74	199	5	24	7	16	0	2	16	0	0	3.0000000000000004	
i 1	94.2388231292517	3.2825	74	199	3	3	11	2	0	-1	2	0	0	11.483894163016764	
i 1	94.2388231292517	8.08	63	199	4	27	4	16	0	2	16	0	0	5.92693010167075	
i 1	94.23954421768707	9.3425	61	199	5	26	16	1	5000	1	1	0	0	5.334237091503674	
i 1	94.24026530612245	0.505	70	199	4	20	4	8	5000	-1	8	0	0	4.0046649342760805	
i 1	94.24387074829932	8.08	63	585	5	25	11	1	0	2	1	0	0	5.334237091503674	
i 1	94.2445918367347	8.08	61	901	5	25	11	1	0	1	1	0	0	5.334237091503674	
i 1	94.24531292517007	2.7775	72	901	5	5	13	0	0	0	0	0	0	3.0	
i 1	94.24963945578232	8.08	61	901	5	25	8	16	0	2	16	0	0	5.334237091503674	
i 1	94.25252380952381	1.5150000000000001	70	199	3	24	4	2	0	-2	2	0	0	8.00466493427608	
i 1	94.25252380952381	1.5150000000000001	73	199	1	20	5	8	0	-2	8	0	0	4.0046649342760805	
i 1	94.25612925170068	0.2525	71	199	4	9	5	2	5000	-2	2	0	0	10.483894163016764	
i 1	94.25757142857142	1.2625	69	585	5	5	9	1	0	-1	1	0	0	3.0	
i 1	94.2611768707483	1.7675	69	199	7	5	13	1	5000	-1	1	0	0	3.0	
i 1	94.26189795918367	8.08	61	585	5	25	10	1	0	1	1	0	0	5.334237091503674	
i 1	94.26694557823129	8.08	61	199	4	27	9	16	0	2	16	0	0	5.92693010167075	
i 1	95.24891836734695	0.7575000000000001	73	199	4	24	8	8	5000	-2	8	0	0	8.00466493427608	
i 1	95.25757142857142	0.7575000000000001	70	199	4	20	1	8	5000	-1	8	0	0	4.0046649342760805	
i 1	95.26694557823129	0.505	73	199	4	20	16	8	0	-1	8	0	0	4.0046649342760805	
i 1	95.48449659863945	0.2525	77	585	4	24	1	17	0	2	17	0	0	3.0000000000000004	
i 1	95.74098639455782	0.2525	69	199	4	5	12	0	0	-1	0	0	0	3.0	
i 1	95.74387074829932	0.2525	74	199	5	4	12	2	0	-1	2	0	0	11.483894163016764	
i 1	95.74963945578232	0.2525	70	585	4	24	9	2	0	-2	2	0	0	8.00466493427608	
i 1	95.75901360544218	0.2525	73	901	4	20	16	8	0	-2	8	0	0	4.0046649342760805	
i 1	95.98377551020408	1.01	69	199	4	5	14	1	5000	-1	1	0	0	3.0	
i 1	95.98665986394558	0.2525	70	585	4	24	3	2	0	-2	2	0	0	5.902697368247871	
i 1	95.98810204081633	2.2725	70	199	4	20	5	8	5000	-1	8	0	0	1.9026973682478712	
i 1	95.99170748299319	0.2525	74	585	4	4	5	8	0	-2	8	0	0	11.483894163016764	
i 1	95.99963945578232	0.2525	70	901	4	20	9	8	0	-1	8	0	0	1.9026973682478712	
i 1	96.01334013605442	1.5150000000000001	73	199	3	20	11	8	0	-2	8	0	0	1.9026973682478712	
i 1	96.24387074829932	0.2525	69	199	7	5	1	0	0	-1	0	0	0	3.0	
i 1	96.24603401360544	0.2525	74	901	6	2	8	2	0	-1	2	0	0	11.483894163016764	
i 1	96.24675510204082	1.2625	73	199	3	24	9	2	0	-1	2	0	0	5.902697368247871	
i 1	96.24747619047619	1.5150000000000001	73	199	1	24	3	8	5000	252	8	307	0	5.902697368247871	
i 1	96.48305442176871	1.01	69	585	5	5	1	0	0	0	0	0	0	3.0	
i 1	96.49242857142858	0.7575000000000001	69	199	4	5	11	0	0	0	0	0	0	3.0	
i 1	96.76189795918367	0.2525	77	585	4	24	3	17	0	2	17	0	0	3.0000000000000004	
i 1	97.24891836734695	0.2525	70	199	4	20	6	2	0	-1	2	0	0	1.9026973682478712	
i 1	97.25685034013605	1.01	70	199	3	24	6	2	0	-2	2	0	0	5.902697368247871	
i 1	97.48738095238095	2.02	69	585	5	5	2	1	0	-1	1	0	0	3.0	
i 1	97.49170748299319	0.2525	71	585	5	3	8	2	0	-2	2	0	0	11.483894163016764	
i 1	97.49242857142858	0.505	73	901	4	20	16	2	0	-2	2	0	0	1.9026973682478712	
i 1	97.73521768707484	0.2525	70	585	4	24	13	8	0	-1	8	0	0	5.902697368247871	
i 1	97.75757142857142	1.2625	69	199	7	5	12	0	0	-1	0	0	0	3.0	
i 1	97.76334013605442	2.02	73	199	4	24	12	8	5000	-2	8	0	0	5.902697368247871	
i 1	97.99026530612245	1.7675	70	199	4	20	1	2	0	-2	2	0	0	1.9026973682478712	
i 1	98.00829251700681	3.2825	73	199	3	24	10	2	0	-1	2	0	0	5.902697368247871	
i 1	98.48665986394558	0.2525	69	199	4	5	10	0	0	0	0	0	0	3.0	
i 1	98.75324489795918	1.7675	72	199	5	5	11	0	5000	-1	0	0	0	3.0	
i 1	98.98738095238095	1.5150000000000001	72	901	6	5	7	0	0	0	0	0	0	3.0	
i 1	98.99098639455782	0.505	74	199	5	24	11	16	0	2	16	0	0	3.0000000000000004	
i 1	99.00108163265305	0.2525	69	199	3	5	13	0	0	-1	0	0	0	3.0	
i 1	99.00901360544218	0.505	74	199	6	9	13	8	5000	-1	8	0	0	10.483894163016764	
i 1	99.24314965986395	3.2825	70	199	4	20	13	8	5000	-1	8	0	0	1.9026973682478712	
i 1	99.25396598639456	2.02	73	199	4	20	5	8	0	-2	8	0	0	1.9026973682478712	
i 1	99.49242857142858	0.2525	71	199	6	9	3	2	5000	-2	2	0	0	10.483894163016764	
i 1	99.74675510204082	1.7675	69	199	7	5	1	0	0	0	0	0	0	3.0	
i 1	99.75036054421768	0.2525	74	199	5	24	15	16	0	2	16	0	0	3.0000000000000004	
i 1	99.75252380952381	2.2725	74	199	6	9	11	8	5000	-1	8	0	0	10.483894163016764	
i 1	99.7611768707483	2.2725	74	901	6	2	1	2	0	-1	2	0	0	11.483894163016764	
i 1	99.98449659863945	1.01	69	585	5	5	7	0	0	0	0	0	0	3.0	
i 1	100.23233333333333	0.2525	74	199	3	3	13	2	0	-1	2	0	0	11.483894163016764	
i 1	100.49098639455782	1.7675	77	585	4	24	13	17	0	2	17	0	0	3.0000000000000004	
i 1	100.49098639455782	2.02	69	199	5	5	15	1	5000	-1	1	0	0	3.0	
i 1	100.51766666666667	1.5150000000000001	72	901	5	5	16	0	0	0	0	0	0	3.0	
i 1	101.24314965986395	0.2525	70	585	4	20	14	2	0	-2	2	0	0	1.9026973682478712	
i 1	101.2554081632653	1.01	70	199	3	24	6	2	0	-2	2	0	0	5.902697368247871	
i 1	101.2640612244898	0.2525	74	199	3	4	8	2	0	-1	2	0	0	11.483894163016764	
i 1	101.49531292517007	0.505	74	199	3	3	11	2	0	-1	2	0	0	11.483894163016764	
i 1	101.50252380952381	0.7575000000000001	71	585	5	3	2	2	0	-2	2	0	0	11.483894163016764	
i 1	101.50901360544218	0.2525	69	585	5	5	3	1	0	-1	1	0	0	3.0	
i 1	101.50973469387755	0.2525	73	199	3	24	14	8	0	-1	8	0	0	5.902697368247871	
i 1	101.99891836734695	0.2525	72	901	6	5	3	0	0	0	0	0	0	3.0	
i 1	102.00108163265305	0.2525	73	199	3	20	15	8	0	-2	8	0	0	1.9026973682478712	
i 1	102.00612925170068	0.2525	69	199	4	5	8	0	0	-1	0	0	0	3.0	
i 1	102.23305442176871	0.2525	73	712	3	24	6	2	5001	-2	2	0	0	5.902697368247871	
i 1	102.23305442176871	0.7575000000000001	73	712	3	24	16	2	0	-1	2	0	0	5.902697368247871	
i 1	102.24170748299319	1.2625	61	1098	5	25	12	1	0	1	1	0	0	5.334237091503674	
i 1	102.24531292517007	1.2625	70	712	3	20	16	8	0	-1	8	0	0	1.9026973682478712	
i 1	102.24747619047619	1.2625	61	1098	5	25	16	16	0	1	16	0	0	5.334237091503674	
i 1	102.25829251700681	0.505	72	1098	6	5	8	1	0	0	1	0	0	3.0	
i 1	102.26189795918367	11.8675	63	712	5	25	13	1	5001	1	1	0	0	5.334237091503674	
i 1	102.26261904761905	1.5150000000000001	74	712	5	3	7	8	5001	-2	8	0	0	11.483894163016764	
i 1	102.26261904761905	1.2625	61	712	3	27	7	16	0	1	16	0	0	5.92693010167075	
i 1	102.26261904761905	1.5150000000000001	69	712	5	5	6	1	5001	-1	1	0	0	3.0	
i 1	102.26334013605442	0.2525	74	712	5	3	15	2	0	-2	2	0	0	11.483894163016764	
i 1	102.26550340136055	14.8975	61	712	5	25	3	1	5001	1	1	0	0	5.334237091503674	
i 1	102.26694557823129	1.2625	61	712	3	27	14	16	0	1	16	0	0	5.92693010167075	
i 1	102.48305442176871	1.01	73	199	4	24	1	8	5000	-2	8	0	0	5.902697368247871	
i 1	102.50108163265305	0.2525	71	1098	5	2	3	8	0	-1	8	0	0	11.483894163016764	
i 1	102.51622448979592	0.2525	73	712	4	20	11	2	5001	-2	2	0	0	1.9026973682478712	
i 1	102.75252380952381	0.7575000000000001	73	712	3	20	15	2	5001	-2	2	0	0	1.9026973682478712	
i 1	102.75468707482993	0.7575000000000001	73	712	3	24	6	2	5001	-2	2	0	0	5.902697368247871	
i 1	102.76478231292516	0.2525	69	712	3	5	13	1	0	-1	1	0	0	3.0	
i 1	102.98665986394558	0.505	70	199	2	20	4	8	0	-2	8	0	0	1.9026973682478712	
i 1	102.98738095238095	1.7675	69	712	5	5	7	1	5001	-1	1	0	0	3.0	
i 1	102.99387074829932	0.505	70	199	4	20	1	8	5000	-1	8	0	0	1.9026973682478712	
i 1	103.24675510204082	0.2525	69	712	4	5	1	0	0	0	0	0	0	3.0	
i 1	103.25468707482993	2.2725	71	712	4	4	3	8	5001	-2	8	0	0	11.483894163016764	
i 1	103.48810204081633	16.665	61	390	4	26	4	16	0	1	16	0	0	5.334237091503674	
i 1	103.48810204081633	0.505	73	4	3	24	13	8	5001	-2	8	0	0	5.902697368247871	
i 1	103.4945918367347	16.9175	63	4	4	27	13	1	0	1	1	0	0	5.92693010167075	
i 1	103.49603401360544	0.7575000000000001	70	4	3	20	7	2	5001	-2	2	0	0	1.9026973682478712	
i 1	103.49747619047619	0.7575000000000001	73	390	2	20	7	2	0	-2	2	0	0	1.9026973682478712	
i 1	103.50180272108844	16.9175	61	4	4	27	3	1	0	2	1	0	0	5.92693010167075	
i 1	103.50468707482993	1.5150000000000001	74	4	3	4	2	2	0	-2	2	0	0	11.483894163016764	
i 1	103.50612925170068	4.545	61	4	6	25	16	16	0	2	16	0	0	5.334237091503674	
i 1	103.50757142857142	7.575	61	4	6	25	15	16	0	1	16	0	0	5.334237091503674	
i 1	103.50901360544218	16.9175	63	390	4	26	14	1	0	1	1	0	0	5.334237091503674	
i 1	103.75973469387755	0.2525	74	4	6	2	7	2	0	-1	2	0	0	11.483894163016764	
i 1	103.75973469387755	0.2525	69	390	5	5	1	1	0	-1	1	0	0	3.0	
i 1	104.00108163265305	0.2525	74	4	5	24	3	17	0	1	17	0	0	3.0000000000000004	
i 1	104.01334013605442	2.02	69	4	7	5	4	1	0	-1	1	0	0	3.0	
i 1	104.24098639455782	0.2525	73	4	3	20	1	8	0	-1	8	0	0	1.9026973682478712	
i 1	104.24242857142858	1.7675	69	390	5	5	13	0	0	-1	0	0	0	3.0	
i 1	104.25036054421768	0.2525	70	4	4	20	12	2	0	-1	2	0	0	1.9026973682478712	
i 1	104.25108163265305	1.2625	73	390	4	24	15	2	0	-2	2	0	0	5.902697368247871	
i 1	104.25396598639456	0.505	74	390	5	9	15	8	0	-2	8	0	0	10.483894163016764	
i 1	104.48738095238095	2.7775	73	4	3	20	15	2	5001	-1	2	0	0	1.9026973682478712	
i 1	104.74819727891156	2.02	74	4	5	24	4	17	0	1	17	0	0	3.0000000000000004	
i 1	104.75396598639456	0.2525	74	712	5	3	14	8	5001	-2	8	0	0	11.483894163016764	
i 1	104.98377551020408	2.2725	70	390	2	20	1	8	0	-1	8	0	0	1.9026973682478712	
i 1	105.00901360544218	6.8175	70	390	4	20	13	2	0	-2	2	0	0	1.9026973682478712	
i 1	105.0111768707483	0.2525	69	712	6	5	14	1	5001	-1	1	0	0	3.0	
i 1	105.01478231292516	2.2725	71	4	6	2	16	2	0	-2	2	0	0	11.483894163016764	
i 1	105.26550340136055	0.2525	72	4	7	5	6	0	0	-1	0	0	0	3.0	
i 1	105.51189795918367	1.2625	69	712	5	5	8	1	5001	-1	1	0	0	3.0	
i 1	105.51478231292516	0.505	74	4	6	2	2	2	0	-1	2	0	0	11.483894163016764	
i 1	105.51478231292516	1.2625	72	4	4	5	4	1	0	0	1	0	0	3.0	
i 1	105.98810204081633	0.7575000000000001	70	4	3	24	14	8	5001	-2	8	0	0	5.902697368247871	
i 1	106.00324489795918	0.2525	74	712	5	3	2	8	5001	-2	8	0	0	11.483894163016764	
i 1	106.00612925170068	3.535	69	390	5	5	2	1	0	-1	1	0	0	3.0	
i 1	106.01334013605442	0.7575000000000001	73	390	4	24	2	2	0	-2	2	0	0	5.902697368247871	
i 1	106.26766666666667	3.2825	72	4	7	5	5	0	0	-1	0	0	0	3.0	
i 1	106.50757142857142	0.2525	74	390	5	9	4	8	0	-2	8	0	0	10.483894163016764	
i 1	106.7359387755102	0.2525	69	4	7	5	9	1	0	-1	1	0	0	3.0	
i 1	106.76045578231293	1.7675	74	4	6	3	15	2	0	-2	2	0	0	11.483894163016764	
i 1	107.00468707482993	0.2525	72	4	4	5	3	1	0	0	1	0	0	3.0	
i 1	107.00757142857142	1.5150000000000001	73	4	3	20	6	8	0	-1	8	0	0	1.9026973682478712	
i 1	107.0140612244898	0.2525	73	390	2	20	5	8	0	-1	8	0	0	1.9026973682478712	
i 1	107.24170748299319	0.2525	73	4	3	20	1	2	0	-1	2	0	0	1.9026973682478712	
i 1	107.24891836734695	0.7575000000000001	70	712	4	20	10	8	5001	-2	8	0	0	1.9026973682478712	
i 1	107.24963945578232	1.01	70	4	3	20	8	2	0	-1	2	0	0	1.9026973682478712	
i 1	107.25757142857142	1.2625	72	4	4	5	4	1	0	0	1	0	0	3.0	
i 1	107.26261904761905	0.2525	74	390	5	9	12	8	0	-2	8	0	0	10.483894163016764	
i 1	107.76478231292516	0.2525	69	712	5	5	2	1	5001	-1	1	0	0	3.0	
i 1	107.98377551020408	2.02	74	390	5	9	15	8	0	-2	8	0	0	10.483894163016764	
i 1	107.98449659863945	12.3725	61	4	6	25	6	16	0	2	16	0	0	5.334237091503674	
i 1	107.98810204081633	2.2725	74	4	6	2	1	2	0	-1	2	0	0	11.483894163016764	
i 1	107.99819727891156	1.2625	73	390	4	24	4	2	0	-2	2	0	0	5.902697368247871	
i 1	107.99891836734695	0.7575000000000001	69	712	6	5	10	1	5001	-1	1	0	0	3.0	
i 1	108.00252380952381	5.555	70	4	3	24	9	8	0	-2	8	0	0	5.902697368247871	
i 1	108.01550340136055	0.2525	70	712	2	20	16	8	5001	-2	8	0	0	1.9026973682478712	
i 1	108.23738095238095	1.7675	71	4	1	24	5	1	5001	248	1	308	0	5.902697368247871	
i 1	108.25757142857142	2.2725	71	4	1	20	11	1	5001	0	1	0	0	1.9026973682478712	
i 1	108.75757142857142	0.2525	74	4	5	24	5	17	0	1	17	0	0	3.0000000000000004	
i 1	109.01622448979592	1.5150000000000001	69	712	6	5	13	1	5001	-1	1	0	0	3.0	
i 1	109.25468707482993	1.7675	77	712	4	24	4	17	5001	1	17	0	0	3.0000000000000004	
i 1	109.25468707482993	1.7675	74	4	5	24	7	17	0	1	17	0	0	3.0000000000000004	
i 1	109.50252380952381	1.5150000000000001	69	390	5	5	1	0	0	-1	0	0	0	3.0	
i 1	109.5054081632653	2.02	74	4	6	3	11	2	0	-2	2	0	0	11.483894163016764	
i 1	110.00324489795918	1.01	73	390	4	24	3	2	0	-2	2	0	0	5.902697368247871	
i 1	110.01045578231293	4.04	69	4	7	5	14	1	0	-1	1	0	0	3.0	
i 1	110.01261904761905	0.505	68	390	2	20	11	0	0	-1	0	0	0	1.9026973682478712	
i 1	110.48665986394558	0.2525	71	712	4	24	12	1	5001	0	1	0	0	5.902697368247871	
i 1	110.4888231292517	0.2525	68	4	3	20	10	1	0	0	1	0	0	1.9026973682478712	
i 1	110.49963945578232	0.2525	72	4	7	5	11	0	0	-1	0	0	0	3.0	
i 1	110.73377551020408	0.2525	69	390	5	5	15	1	0	-1	1	0	0	3.0	
i 1	110.74026530612245	0.505	68	390	2	20	2	1	0	-1	1	0	0	1.9026973682478712	
i 1	110.74819727891156	0.2525	74	390	5	9	14	8	0	-2	8	0	0	10.483894163016764	
i 1	110.98810204081633	0.7575000000000001	69	390	6	5	5	0	0	-1	0	0	0	3.0	
i 1	111.0054081632653	0.7575000000000001	74	390	5	9	5	8	0	-2	8	0	0	10.483894163016764	
i 1	111.00973469387755	9.3425	61	4	6	25	8	16	0	1	16	0	0	5.334237091503674	
i 1	111.23738095238095	0.2525	71	4	3	20	16	1	0	-1	1	0	0	1.9026973682478712	
i 1	111.23810204081633	0.2525	68	4	3	20	12	0	0	-1	0	0	0	1.9026973682478712	
i 1	111.23954421768707	1.01	73	4	3	20	5	8	0	-1	8	0	0	1.9026973682478712	
i 1	111.24314965986395	1.2625	72	4	4	5	1	1	0	0	1	0	0	3.0	
i 1	111.24603401360544	2.2725	74	4	5	4	3	2	0	-2	2	0	0	11.483894163016764	
i 1	111.25036054421768	2.02	69	712	6	5	8	1	5001	-1	1	0	0	3.0	
i 1	111.25901360544218	2.7775	71	712	4	4	2	8	5001	-2	8	0	0	11.483894163016764	
i 1	111.26189795918367	1.5150000000000001	73	390	4	24	1	2	0	-2	2	0	0	5.902697368247871	
i 1	111.49242857142858	0.505	68	4	1	24	10	0	5001	-1	0	0	0	5.902697368247871	
i 1	111.49675510204082	0.505	71	390	2	20	1	0	0	-1	0	0	0	1.9026973682478712	
i 1	111.98305442176871	0.2525	68	4	3	20	7	0	0	-1	0	0	0	1.9026973682478712	
i 1	112.0054081632653	0.505	68	4	3	20	13	0	0	0	0	0	0	1.9026973682478712	
i 1	112.5054081632653	0.2525	68	4	1	24	13	1	5001	-1	1	0	0	5.902697368247871	
i 1	112.50757142857142	0.2525	68	390	2	20	13	0	0	-1	0	0	0	1.9026973682478712	
i 1	112.5140612244898	0.505	74	390	5	9	7	8	0	-2	8	0	0	10.483894163016764	
i 1	112.74387074829932	1.2625	74	4	5	24	13	17	0	1	17	0	0	3.0000000000000004	
i 1	112.76694557823129	0.505	68	4	3	20	14	1	0	-1	1	0	0	1.9026973682478712	
i 1	113.00396598639456	1.01	73	390	4	24	15	2	0	-2	2	0	0	5.902697368247871	
i 1	113.2359387755102	1.5150000000000001	71	390	2	20	9	1	0	-1	1	0	0	1.9026973682478712	
i 1	113.50612925170068	0.7575000000000001	72	4	4	5	3	1	0	0	1	0	0	3.0	
i 1	113.50829251700681	3.0300000000000002	69	712	6	5	5	1	5001	-1	1	0	0	3.0	
i 1	113.74314965986395	0.2525	69	390	5	5	6	1	0	-1	1	0	0	3.0	
i 1	113.76622448979592	0.2525	70	4	3	24	16	8	0	-2	8	0	0	5.902697368247871	
i 1	113.9859387755102	2.2725	74	390	5	9	5	8	0	-2	8	0	0	10.483894163016764	
i 1	113.99314965986395	0.2525	74	390	5	9	12	8	0	-2	8	0	0	10.483894163016764	
i 1	114.0054081632653	5.555	63	712	5	25	13	1	5001	1	1	0	0	5.334237091503674	
i 1	114.01045578231293	0.2525	68	390	2	20	15	1	0	-1	1	0	0	1.9026973682478712	
i 1	114.01622448979592	1.01	73	390	2	24	9	2	0	-2	2	0	0	5.902697368247871	
i 1	114.26622448979592	0.2525	74	4	6	3	2	2	0	-2	2	0	0	11.483894163016764	
i 1	114.73377551020408	1.5150000000000001	72	4	4	5	10	1	0	0	1	0	0	3.0	
i 1	114.74963945578232	0.2525	68	4	3	20	11	0	0	0	0	0	0	1.9026973682478712	
i 1	114.75180272108844	0.2525	71	4	3	20	12	1	0	0	1	0	0	1.9026973682478712	
i 1	114.98810204081633	2.02	68	390	2	20	14	1	0	0	1	0	0	1.9026973682478712	
i 1	115.00324489795918	1.5150000000000001	68	390	2	20	11	1	0	0	1	0	0	1.9026973682478712	
i 1	115.23665986394558	0.2525	74	390	5	9	10	8	0	-2	8	0	0	10.483894163016764	
i 1	115.24314965986395	1.2625	73	390	2	24	9	2	0	-2	2	0	0	5.902697368247871	
i 1	115.49314965986395	0.2525	77	712	4	24	14	17	5001	1	17	0	0	3.0000000000000004	
i 1	115.75180272108844	3.535	74	712	5	3	12	8	5001	-2	8	0	0	11.483894163016764	
i 1	116.50901360544218	0.2525	74	4	5	4	16	2	0	-2	2	0	0	11.483894163016764	
i 1	116.51261904761905	0.2525	69	390	6	5	4	0	0	-1	0	0	0	3.0	
i 1	116.73449659863945	0.7575000000000001	70	4	3	24	8	8	0	-2	8	0	0	5.902697368247871	
i 1	116.74170748299319	1.5150000000000001	72	4	4	5	5	1	0	0	1	0	0	3.0	
i 1	116.74531292517007	0.505	74	4	5	24	16	17	0	1	17	0	0	3.0000000000000004	
i 1	116.74747619047619	0.2525	68	4	1	20	6	0	5001	0	0	0	0	1.9026973682478712	
i 1	116.98305442176871	0.2525	68	712	2	20	11	1	5001	0	1	0	0	1.9026973682478712	
i 1	116.98738095238095	0.2525	68	4	3	20	3	0	0	0	0	0	0	1.9026973682478712	
i 1	116.9888231292517	0.2525	68	712	2	24	2	0	5001	-1	0	0	0	5.902697368247871	
i 1	116.99531292517007	2.2725	74	4	4	3	9	2	0	-2	2	0	0	11.483894163016764	
i 1	117.00685034013605	0.2525	70	390	2	20	11	2	0	-2	2	0	0	1.9026973682478712	
i 1	117.00757142857142	2.525	61	712	5	25	3	1	5001	1	1	0	0	5.334237091503674	
i 1	117.01550340136055	1.01	74	390	5	9	6	8	0	-2	8	0	0	10.483894163016764	
i 1	117.23233333333333	1.7675	77	712	4	24	2	17	5001	1	17	0	0	3.0000000000000004	
i 1	117.23305442176871	0.7575000000000001	74	4	6	2	7	2	0	-1	2	0	0	11.483894163016764	
i 1	117.24603401360544	0.7575000000000001	68	390	2	20	14	0	0	0	0	0	0	1.9026973682478712	
i 1	117.24675510204082	0.2525	68	4	1	20	4	0	5001	0	0	0	0	1.9026973682478712	
i 1	117.25252380952381	0.7575000000000001	71	390	2	20	11	0	0	0	0	0	0	1.9026973682478712	
i 1	117.49026530612245	1.7675	74	4	5	24	1	17	0	1	17	0	0	3.0000000000000004	
i 1	117.49891836734695	0.7575000000000001	70	390	2	20	8	2	0	-2	2	0	0	1.9026973682478712	
i 1	117.75468707482993	2.02	69	4	7	5	16	1	0	-1	1	0	0	3.0	
i 1	118.00468707482993	0.2525	71	4	6	2	14	2	0	-2	2	0	0	11.483894163016764	
i 1	118.00829251700681	0.2525	68	4	3	20	4	0	0	-1	0	0	0	1.9026973682478712	
i 1	118.00829251700681	0.2525	68	712	2	24	8	0	5001	0	0	0	0	5.902697368247871	
i 1	118.25757142857142	0.2525	71	712	4	4	5	8	5001	-2	8	0	0	11.483894163016764	
i 1	118.26045578231293	0.2525	68	390	2	20	15	1	0	0	1	0	0	1.9026973682478712	
i 1	118.5140612244898	1.5150000000000001	70	390	2	20	16	2	0	-2	2	0	0	1.9026973682478712	
i 1	118.51766666666667	0.2525	69	712	6	5	7	1	5001	-1	1	0	0	3.0	
i 1	118.73665986394558	0.2525	71	4	3	20	9	1	0	0	1	0	0	1.9026973682478712	
i 1	118.75252380952381	1.2625	74	4	6	2	7	2	0	-1	2	0	0	11.483894163016764	
i 1	118.75685034013605	0.2525	68	4	3	20	15	0	0	0	0	0	0	1.9026973682478712	
i 1	118.75685034013605	0.2525	68	712	2	24	15	1	5001	-1	1	0	0	5.902697368247871	
i 1	118.76622448979592	0.2525	69	712	6	5	15	1	5001	-1	1	0	0	3.0	
i 1	118.98449659863945	0.2525	68	4	1	24	7	0	5001	0	0	0	0	5.902697368247871	
i 1	118.98665986394558	0.505	71	390	2	20	14	1	0	-1	1	0	0	1.9026973682478712	
i 1	119.24026530612245	0.2525	71	712	4	4	1	8	5001	-2	8	0	0	11.483894163016764	
i 1	119.24675510204082	0.7575000000000001	70	4	3	24	12	8	0	-2	8	0	0	5.902697368247871	
i 1	119.25396598639456	0.7575000000000001	72	4	5	5	1	1	0	0	1	0	0	3.0	
i 1	119.4859387755102	1.2625	66	888	5	25	4	9	0	2	9	0	0	5.334237091503674	
i 1	119.49675510204082	0.505	73	4	3	20	1	8	0	-1	8	0	0	1.9026973682478712	
i 1	119.50108163265305	1.2625	71	888	6	5	10	2	0	-1	2	0	0	3.0	
i 1	119.50396598639456	0.2525	71	4	3	20	11	1	0	-1	1	0	0	1.9026973682478712	
i 1	119.50757142857142	1.2625	61	888	5	25	7	6	0	1	6	0	0	5.334237091503674	
i 1	119.73305442176871	0.2525	68	390	2	20	16	1	0	-1	1	0	0	1.9026973682478712	
i 1	119.74314965986395	0.2525	68	390	2	20	13	1	0	0	1	0	0	1.9026973682478712	
i 1	120.00108163265305	0.2525	74	390	5	9	4	8	0	-2	8	0	0	10.483894163016764	
i 1	120.00396598639456	0.2525	72	4	5	5	8	1	0	0	1	0	0	3.0	
i 1	120.00973469387755	0.2525	68	390	2	20	14	1	0	-1	1	0	0	0.16663952660314107	
i 1	120.01045578231293	0.2525	61	390	4	26	7	16	0	1	16	0	0	5.334237091503674	
i 1	120.01189795918367	0.2525	71	4	6	2	6	2	0	-2	2	0	0	11.483894163016764	
i 1	120.23305442176871	10.352500000000001	68	186	2	20	3	0	0	0	0	0	0	0.16663952660314107	
i 1	120.23377551020408	0.505	71	186	1	20	15	1	0	0	1	0	0	0.16663952660314107	
i 1	120.23521768707484	0.505	71	186	2	24	3	1	0	0	1	0	0	4.1666395266031415	
i 1	120.23738095238095	0.505	68	186	1	24	6	0	0	-1	0	0	0	4.1666395266031415	
i 1	120.2388231292517	0.7575000000000001	69	1070	5	2	3	0	0	-1	0	0	0	11.483894163016764	
i 1	120.24603401360544	4.2925	69	186	5	9	1	0	0	0	0	0	0	10.483894163016764	
i 1	120.24603401360544	5.8075	61	186	4	27	16	6	0	2	6	0	0	5.92693010167075	
i 1	120.24819727891156	0.2525	72	186	5	9	1	0	0	-1	0	0	0	10.483894163016764	
i 1	120.24819727891156	14.8975	66	186	5	26	15	9	0	2	9	0	0	5.334237091503674	
i 1	120.24963945578232	0.505	71	186	2	20	9	0	0	-1	0	0	0	0.16663952660314107	
i 1	120.25180272108844	2.02	74	186	6	5	1	2	0	-2	2	0	0	3.0	
i 1	120.25252380952381	0.7575000000000001	71	186	1	24	7	0	0	-1	0	0	0	4.1666395266031415	
i 1	120.25396598639456	8.8375	66	186	4	27	10	9	0	1	9	0	0	5.92693010167075	
i 1	120.25901360544218	14.8975	61	1070	5	25	2	6	0	2	6	0	0	5.334237091503674	
i 1	120.26261904761905	14.8975	61	1070	5	25	9	6	0	1	6	0	0	5.334237091503674	
i 1	120.26478231292516	2.7775	61	186	5	26	1	6	0	1	6	0	0	5.334237091503674	
i 1	120.50252380952381	4.04	72	1070	6	2	11	0	0	-1	0	0	0	11.483894163016764	
i 1	120.73449659863945	1.5150000000000001	71	684	4	24	11	8	0	-2	8	0	0	3.0000000000000004	
i 1	120.73954421768707	0.2525	71	1070	2	20	14	0	0	-1	0	0	0	0.16663952660314107	
i 1	120.74098639455782	0.2525	68	684	2	20	16	0	0	0	0	0	0	0.16663952660314107	
i 1	120.74891836734695	1.7675	74	684	6	5	16	8	0	-1	8	0	0	3.0	
i 1	120.75973469387755	14.3925	61	684	5	25	12	6	0	2	6	0	0	5.334237091503674	
i 1	120.76045578231293	0.2525	71	1070	2	20	5	1	0	-1	1	0	0	0.16663952660314107	
i 1	120.76478231292516	14.3925	61	684	5	25	3	9	0	2	9	0	0	5.334237091503674	
i 1	121.01550340136055	0.2525	71	186	2	20	10	0	0	0	0	0	0	0.16663952660314107	
i 1	121.24387074829932	1.01	71	186	2	24	2	1	0	0	1	0	0	4.1666395266031415	
i 1	121.73449659863945	1.2625	71	1070	6	5	5	2	0	-1	2	0	0	3.0	
i 1	121.74026530612245	0.7575000000000001	71	186	1	20	10	1	0	-1	1	0	0	0.16663952660314107	
i 1	121.7554081632653	1.01	71	186	3	20	4	0	0	0	0	0	0	0.16663952660314107	
i 1	121.76045578231293	1.2625	74	186	5	24	2	2	0	-1	2	0	0	3.0000000000000004	
i 1	121.99675510204082	0.7575000000000001	72	684	5	3	3	0	0	-1	0	0	0	11.483894163016764	
i 1	122.01766666666667	0.7575000000000001	72	186	4	4	16	1	0	0	1	0	0	11.483894163016764	
i 1	122.26694557823129	2.525	71	186	1	24	7	0	0	-1	0	0	0	4.1666395266031415	
i 1	122.4888231292517	2.02	71	186	5	5	8	8	0	-2	8	0	0	3.0	
i 1	122.48954421768707	0.505	74	684	6	5	13	2	0	-2	2	0	0	3.0	
i 1	122.5054081632653	0.2525	68	1070	2	20	9	1	0	0	1	0	0	0.16663952660314107	
i 1	122.73521768707484	1.7675	71	186	2	20	3	0	0	-1	0	0	0	0.16663952660314107	
i 1	122.98233333333333	0.2525	71	684	4	24	1	8	0	-2	8	0	0	3.0000000000000004	
i 1	123.00829251700681	0.2525	74	684	6	5	9	8	0	-1	8	0	0	3.0	
i 1	123.01045578231293	12.120000000000001	61	186	5	26	9	6	0	1	6	0	0	5.334237091503674	
i 1	123.01334013605442	1.5150000000000001	74	684	6	5	14	2	0	-2	2	0	0	3.0	
i 1	123.24170748299319	0.2525	72	186	4	4	9	1	0	0	1	0	0	11.483894163016764	
i 1	123.49387074829932	1.7675	71	684	4	24	9	8	0	-2	8	0	0	3.0000000000000004	
i 1	123.74747619047619	0.2525	71	1070	6	5	13	2	0	-1	2	0	0	3.0	
i 1	123.98233333333333	0.7575000000000001	71	186	5	5	9	8	0	-2	8	0	0	3.0	
i 1	123.99531292517007	1.7675	69	684	4	4	2	0	0	0	0	0	0	11.483894163016764	
i 1	124.01045578231293	1.7675	72	186	5	9	14	0	0	-1	0	0	0	10.483894163016764	
i 1	124.24098639455782	1.7675	71	186	1	20	10	0	0	0	0	0	0	0.16663952660314107	
i 1	124.25036054421768	1.5150000000000001	74	684	6	5	8	8	0	-1	8	0	0	3.0	
i 1	124.25612925170068	0.2525	71	186	1	24	3	1	0	0	1	0	0	4.1666395266031415	
i 1	124.25829251700681	1.2625	71	186	2	24	14	1	0	0	1	0	0	4.1666395266031415	
i 1	124.2611768707483	1.5150000000000001	74	186	6	5	9	2	0	-2	2	0	0	3.0	
i 1	124.4945918367347	0.2525	68	1070	2	20	2	1	0	-1	1	0	0	0.16663952660314107	
i 1	124.50036054421768	0.2525	68	684	2	24	2	1	0	0	1	0	0	4.1666395266031415	
i 1	124.50685034013605	0.2525	69	1070	6	2	2	0	0	-1	0	0	0	11.483894163016764	
i 1	124.75829251700681	0.505	72	186	4	4	5	1	0	0	1	0	0	11.483894163016764	
i 1	125.00324489795918	3.0300000000000002	71	186	1	24	8	0	0	-1	0	0	0	4.1666395266031415	
i 1	125.00757142857142	1.5150000000000001	74	186	5	24	5	2	0	-1	2	0	0	3.0000000000000004	
i 1	125.24026530612245	1.5150000000000001	71	186	5	5	9	8	0	-2	8	0	0	3.0	
i 1	125.4859387755102	0.7575000000000001	68	186	1	24	14	0	0	252	0	307	0	4.1666395266031415	
i 1	125.73449659863945	0.2525	69	186	5	9	5	0	0	0	0	0	0	10.483894163016764	
i 1	125.75180272108844	0.2525	71	186	5	5	3	8	0	-2	8	0	0	3.0	
i 1	125.98665986394558	9.09	61	186	4	27	15	6	0	2	6	0	0	5.92693010167075	
i 1	125.99170748299319	0.7575000000000001	71	186	2	24	10	1	0	0	1	0	0	4.1666395266031415	
i 1	125.99963945578232	0.2525	72	186	5	9	7	0	0	-1	0	0	0	10.483894163016764	
i 1	126.00829251700681	0.2525	74	684	6	5	3	2	0	-2	2	0	0	3.0	
i 1	126.24170748299319	1.7675	74	186	6	5	7	2	0	-2	2	0	0	3.0	
i 1	126.24242857142858	1.7675	74	684	6	5	10	8	0	-1	8	0	0	3.0	
i 1	126.24314965986395	0.2525	71	1070	2	20	15	0	0	0	0	0	0	0.16663952660314107	
i 1	126.24819727891156	0.2525	68	1070	2	20	10	0	0	0	0	0	0	0.16663952660314107	
i 1	126.50108163265305	0.505	68	186	2	20	8	1	0	0	1	0	0	0.16663952660314107	
i 1	126.7388231292517	0.2525	72	684	5	3	8	0	0	-1	0	0	0	11.483894163016764	
i 1	126.98233333333333	0.2525	68	1070	2	20	6	1	0	0	1	0	0	0.16663952660314107	
i 1	126.98810204081633	0.2525	68	1070	2	20	14	1	0	-1	1	0	0	0.16663952660314107	
i 1	126.9945918367347	0.2525	71	1070	6	5	4	2	0	-1	2	0	0	3.0	
i 1	127.2388231292517	0.2525	71	186	5	5	3	8	0	-2	8	0	0	3.0	
i 1	127.24098639455782	0.505	68	186	2	20	3	0	0	0	0	0	0	0.16663952660314107	
i 1	127.24242857142858	0.2525	72	684	5	3	6	0	0	-1	0	0	0	11.483894163016764	
i 1	127.24675510204082	1.5150000000000001	74	186	5	24	11	2	0	-1	2	0	0	3.0000000000000004	
i 1	127.48738095238095	2.2725	71	186	5	5	16	8	0	-2	8	0	0	3.0	
i 1	127.51189795918367	1.2625	74	1070	6	5	6	2	0	-1	2	0	0	3.0	
i 1	127.73665986394558	0.2525	68	1070	2	20	15	0	0	-1	0	0	0	0.16663952660314107	
i 1	127.99891836734695	0.2525	68	186	2	20	14	1	0	0	1	0	0	0.16663952660314107	
i 1	128.00540816326532	0.2525	68	186	2	20	14	1	0	-1	1	0	0	0.16663952660314107	
i 1	128.00973469387756	0.2525	68	186	1	24	4	0	0	0	0	0	0	4.1666395266031415	
i 1	128.0133401360544	1.01	72	186	4	4	14	1	0	0	1	0	0	11.483894163016764	
i 1	128.01766666666666	0.2525	71	1070	6	5	7	2	0	-1	2	0	0	3.0	
i 1	128.2640612244898	2.02	74	684	6	5	5	8	0	-1	8	0	0	3.0	
i 1	128.26766666666666	0.2525	71	1070	2	20	10	1	0	-1	1	0	0	0.16663952660314107	
i 1	128.50396598639455	0.505	68	186	2	20	8	0	0	-1	0	0	0	0.16663952660314107	
i 1	128.51261904761904	5.05	69	186	5	9	2	0	0	0	0	0	0	10.483894163016764	
i 1	128.73449659863945	0.7575000000000001	71	186	1	20	5	0	0	0	0	0	0	0.16663952660314107	
i 1	128.98377551020408	6.0600000000000005	66	186	4	27	4	9	0	1	9	0	0	5.92693010167075	
i 1	129.00180272108844	0.2525	71	1070	2	20	6	0	0	0	0	0	0	0.16663952660314107	
i 1	129.0025238095238	2.2725	74	186	5	24	11	2	0	-1	2	0	0	3.0000000000000004	
i 1	129.2366598639456	0.2525	71	186	2	20	11	0	0	-1	0	0	0	0.16663952660314107	
i 1	129.23738095238096	0.2525	71	186	2	20	13	1	0	0	1	0	0	0.16663952660314107	
i 1	129.25901360544216	0.2525	72	684	5	3	16	0	0	-1	0	0	0	11.483894163016764	
i 1	129.50757142857142	0.2525	69	1070	6	2	3	0	0	-1	0	0	0	11.483894163016764	
i 1	129.73738095238096	2.2725	68	186	2	20	12	0	0	-1	0	0	0	0.16663952660314107	
i 1	129.73810204081633	1.01	72	186	4	4	1	1	0	0	1	0	0	11.483894163016764	
i 1	129.73954421768707	0.7575000000000001	71	1070	6	5	13	2	0	-1	2	0	0	3.0	
i 1	129.74675510204082	0.2525	71	186	2	20	9	1	0	0	1	0	0	0.16663952660314107	
i 1	129.7503605442177	1.01	72	684	5	3	13	0	0	-1	0	0	0	11.483894163016764	
i 1	129.75685034013605	0.7575000000000001	71	186	6	5	14	8	0	-2	8	0	0	3.0	
i 1	129.98521768707482	1.5150000000000001	71	186	5	5	1	8	0	-2	8	0	0	3.0	
i 1	129.9996394557823	1.5150000000000001	74	684	6	5	15	2	0	-2	2	0	0	3.0	
i 1	130.48738095238096	1.5150000000000001	71	684	4	24	15	8	0	-2	8	0	0	3.0000000000000004	
i 1	130.5133401360544	0.2525	71	186	5	5	8	8	0	-2	8	0	0	3.0	
i 1	130.7359387755102	0.2525	69	1070	6	2	2	0	0	-1	0	0	0	11.483894163016764	
i 1	130.7417074829932	2.2725	68	186	2	20	2	0	0	0	0	0	0	0.16663952660314107	
i 1	130.98954421768707	1.7675	74	1070	6	5	2	2	0	-1	2	0	0	3.0	
i 1	130.99603401360545	0.2525	72	186	4	4	13	1	0	0	1	0	0	11.483894163016764	
i 1	131.01189795918367	1.01	71	186	2	20	1	1	0	0	1	0	0	0.16663952660314107	
i 1	131.5082925170068	4.545	71	186	2	24	5	1	0	0	1	0	0	4.1666395266031415	
i 1	131.74603401360545	0.2525	72	186	4	4	8	1	0	0	1	0	0	11.483894163016764	
i 1	131.7669455782313	0.2525	71	186	6	5	3	8	0	-2	8	0	0	3.0	
i 1	132.0025238095238	0.2525	68	684	2	24	13	1	0	-1	1	0	0	4.1666395266031415	
i 1	132.00901360544216	0.505	69	684	4	4	11	0	0	0	0	0	0	11.483894163016764	
i 1	132.01766666666666	0.2525	68	1070	2	20	11	1	0	0	1	0	0	0.16663952660314107	
i 1	132.23449659863945	0.2525	68	186	2	20	6	0	0	-1	0	0	0	0.16663952660314107	
i 1	132.24459183673468	0.2525	71	186	1	24	5	1	0	-1	1	0	0	4.1666395266031415	
i 1	132.25612925170068	0.2525	68	186	2	20	8	1	0	0	1	0	0	0.16663952660314107	
i 1	132.48521768707482	0.2525	72	186	4	3	9	1	0	0	1	0	0	11.483894163016764	
i 1	132.51766666666666	0.2525	71	684	2	24	15	0	0	-1	0	0	0	4.1666395266031415	
i 1	132.7366598639456	2.2725	72	186	6	9	8	0	0	-1	0	0	0	10.483894163016764	
i 1	132.73954421768707	2.7775	68	186	1	24	4	0	0	0	0	0	0	4.1666395266031415	
i 1	132.74387074829932	0.2525	74	684	6	5	8	2	0	-2	2	0	0	3.0	
i 1	132.74459183673468	1.7675	68	186	1	20	14	1	0	-1	1	0	0	0.16663952660314107	
i 1	132.74603401360545	2.2725	74	186	5	24	11	2	0	-1	2	0	0	3.0000000000000004	
i 1	132.98377551020408	0.2525	71	186	5	5	5	8	0	-2	8	0	0	3.0	
i 1	133.00396598639455	2.02	69	684	4	4	11	0	0	0	0	0	0	11.483894163016764	
i 1	133.99026530612244	1.5150000000000001	71	186	2	20	5	0	0	-1	0	0	0	0.16663952660314107	
i 1	133.99387074829932	2.02	71	186	1	24	8	0	0	-1	0	0	0	4.1666395266031415	
i 1	133.99675510204082	0.2525	72	186	4	4	13	1	0	0	1	0	0	11.483894163016764	
i 1	134.0025238095238	1.5150000000000001	68	186	2	20	2	0	0	0	0	0	0	0.16663952660314107	
i 1	134.01622448979592	3.0300000000000002	74	684	6	5	3	8	0	-1	8	0	0	3.0	
i 1	134.25396598639455	0.7575000000000001	72	186	4	3	1	1	0	0	1	0	0	11.483894163016764	
i 1	134.98738095238096	2.7775	66	186	5	18	3	6	0	1	6	0	0	4.311502327952767	
i 1	134.98954421768707	2.7775	66	186	5	18	8	6	0	2	6	0	0	4.311502327952767	
i 1	134.99098639455784	2.525	61	684	6	17	10	9	0	2	9	0	0	4.311502327952767	
i 1	134.9974761904762	0.505	68	186	1	20	1	1	0	-1	1	0	0	0.16663952660314107	
i 1	134.99891836734693	2.525	71	684	4	24	6	8	0	-2	8	0	0	6.0	
i 1	135.0003605442177	2.525	66	684	6	17	16	9	0	1	9	0	0	4.311502327952767	
i 1	135.0003605442177	1.7675	61	186	4	27	3	6	0	2	6	0	0	0.5926930101670749	
i 1	135.0025238095238	1.7675	61	1070	6	17	12	9	0	2	9	0	0	4.311502327952767	
i 1	135.00324489795918	1.5150000000000001	72	186	4	3	11	1	0	0	1	0	0	12.005297634179682	
i 1	135.00468707482995	0.7575000000000001	71	186	1	20	5	0	0	0	0	0	0	0.16663952660314107	
i 1	135.00757142857142	2.02	71	684	6	1	2	2	0	-1	2	0	0	3.0	
i 1	135.01622448979592	1.7675	66	186	4	27	6	9	0	1	9	0	0	0.5926930101670749	
i 1	135.01766666666666	1.7675	66	1070	6	17	2	9	0	2	9	0	0	4.311502327952767	
i 1	135.24314965986395	0.2525	71	186	7	5	4	8	0	-2	8	0	0	3.0	
i 1	135.26550340136055	0.2525	72	186	6	9	4	0	0	-1	0	0	0	11.005297634179682	
i 1	135.48449659863945	0.2525	71	1070	2	20	15	0	0	0	0	0	0	0.16663952660314107	
i 1	135.48954421768707	1.01	74	1070	4	5	5	2	0	-1	2	0	0	3.0	
i 1	135.50757142857142	0.505	72	1070	6	2	12	0	0	-1	0	0	0	12.005297634179682	
i 1	135.7359387755102	0.7575000000000001	68	186	1	20	16	0	0	0	0	0	0	0.16663952660314107	
i 1	135.99026530612244	0.7575000000000001	72	186	4	4	11	1	0	0	1	0	0	12.005297634179682	
i 1	136.00685034013605	1.7675	71	186	1	24	4	0	0	252	0	307	0	4.1666395266031415	
i 1	136.4888231292517	0.2525	71	186	2	20	8	1	0	-1	1	0	0	0.16663952660314107	
i 1	136.50324489795918	0.7575000000000001	71	186	2	24	2	1	0	0	1	0	0	4.1666395266031415	
i 1	136.50901360544216	1.2625	69	186	6	9	9	0	0	0	0	0	0	11.005297634179682	
i 1	136.7330544217687	1.2625	61	888	6	17	15	6	0	1	6	0	0	4.311502327952767	
i 1	136.73954421768707	0.2525	68	888	2	20	5	1	0	0	1	0	0	0.16663952660314107	
i 1	136.74098639455784	0.2525	72	186	3	4	16	1	0	0	1	0	0	12.005297634179682	
i 1	136.7417074829932	1.2625	61	888	6	17	3	6	0	2	6	0	0	4.311502327952767	
i 1	136.7503605442177	1.2625	72	888	6	2	10	1	0	0	1	0	0	12.005297634179682	
i 1	136.75108163265307	1.01	61	186	4	27	1	6	0	2	6	0	0	0.5926930101670749	
i 1	136.75540816326532	1.01	66	186	4	27	14	9	0	1	9	0	0	0.5926930101670749	
i 1	136.75757142857142	1.01	71	186	6	5	9	8	0	-2	8	0	0	3.0	
i 1	136.98954421768707	0.2525	74	888	6	5	11	8	0	-1	8	0	0	3.0	
i 1	136.99675510204082	0.7575000000000001	71	186	2	20	7	0	0	-1	0	0	0	0.16663952660314107	
i 1	137.0111768707483	0.2525	71	186	2	20	16	1	0	0	1	0	0	0.16663952660314107	
i 1	137.2359387755102	0.2525	71	684	6	1	7	2	0	-1	2	0	0	3.0	
i 1	137.23810204081633	0.2525	74	684	6	5	16	8	0	-1	8	0	0	3.0	
i 1	137.23810204081633	0.505	74	186	7	5	1	2	0	-2	2	0	0	3.0	
i 1	137.26478231292518	0.7575000000000001	72	888	6	2	1	1	0	-1	1	0	0	12.005297634179682	
i 1	137.49242857142858	0.505	74	572	6	5	10	8	0	-1	8	0	0	3.0	
i 1	137.49314965986395	0.2525	71	186	2	24	1	1	0	0	1	0	0	4.1666395266031415	
i 1	137.50180272108844	0.505	66	572	6	17	13	6	0	1	6	0	0	4.311502327952767	
i 1	137.50468707482995	0.505	61	572	6	17	4	6	0	2	6	0	0	4.311502327952767	
i 1	137.51550340136055	0.505	74	572	6	1	15	2	0	-2	2	0	0	3.0	
i 1	137.73233333333334	0.2525	71	1154	2	24	3	1	0	0	1	0	0	4.1666395266031415	
i 1	137.73377551020408	0.2525	66	185	4	27	16	9	0	2	9	0	0	0.5926930101670749	
i 1	137.74098639455784	0.2525	69	1154	5	9	1	0	0	-1	0	0	0	11.005297634179682	
i 1	137.74098639455784	0.2525	61	1154	4	18	15	6	0	1	6	0	0	4.311502327952767	
i 1	137.7474761904762	0.2525	66	185	4	27	2	9	0	2	9	0	0	0.5926930101670749	
i 1	137.74891836734693	0.2525	66	1154	4	18	5	9	0	2	9	0	0	4.311502327952767	
i 1	137.7503605442177	0.2525	71	888	2	20	13	1	0	-1	1	0	0	0.16663952660314107	
i 1	137.7669455782313	0.2525	68	1154	2	20	16	0	0	-1	0	0	0	0.16663952660314107	
i 1	137.98377551020408	9.09	61	193	6	17	13	6	0	2	6	0	0	4.311502327952767	
i 1	137.98377551020408	1.01	71	1077	1	24	4	1	0	0	1	0	0	4.1666395266031415	
i 1	137.98954421768707	3.0300000000000002	61	691	6	17	3	6	0	1	6	0	0	4.311502327952767	
i 1	137.99314965986395	1.7675	69	1077	5	9	8	0	0	-1	0	0	0	11.005297634179682	
i 1	137.99459183673468	6.0600000000000005	61	1077	4	18	13	6	0	1	6	0	0	4.311502327952767	
i 1	137.99459183673468	9.09	61	691	4	19	14	9	5002	2	9	0	0	4.311502327952767	
i 1	137.99531292517005	18.18	66	691	3	27	7	6	5002	1	6	0	0	0.5926930101670749	
i 1	138.0003605442177	1.7675	69	691	6	2	11	1	0	-1	1	0	0	12.005297634179682	
i 1	138.0003605442177	15.15	61	691	3	27	13	6	5002	1	6	0	0	0.5926930101670749	
i 1	138.00108163265307	0.505	72	691	6	2	6	0	0	-1	0	0	0	12.005297634179682	
i 1	138.00324489795918	1.01	74	691	4	1	16	8	5002	-2	8	0	0	3.0	
i 1	138.00540816326532	1.01	74	691	6	5	15	8	0	-2	8	0	0	3.0	
i 1	138.00757142857142	6.0600000000000005	66	193	6	17	11	9	0	2	9	0	0	4.311502327952767	
i 1	138.0082925170068	5.8075	68	1077	1	20	11	1	0	-1	1	0	0	0.16663952660314107	
i 1	138.00901360544216	0.2525	74	691	4	24	7	8	5002	-2	8	0	0	6.0	
i 1	138.01261904761904	3.0300000000000002	66	1077	4	18	11	9	0	2	9	0	0	4.311502327952767	
i 1	138.2503605442177	2.525	74	193	5	24	12	2	0	-2	2	0	0	6.0	
i 1	138.25540816326532	0.505	68	691	2	20	12	0	0	-1	0	0	0	0.16663952660314107	
i 1	138.49891836734693	2.02	74	1077	6	5	16	2	0	-2	2	0	0	3.0	
i 1	138.51478231292518	0.2525	68	691	2	20	8	0	0	-1	0	0	0	0.16663952660314107	
i 1	138.76045578231293	1.01	68	1077	1	20	11	0	0	0	0	0	0	0.16663952660314107	
i 1	138.7640612244898	0.2525	72	1077	5	9	7	0	0	-1	0	0	0	11.005297634179682	
i 1	139.25108163265307	0.2525	69	193	5	4	2	0	0	0	0	0	0	12.005297634179682	
i 1	139.49026530612244	0.2525	71	691	6	5	9	2	5002	-2	2	0	0	3.0	
i 1	139.50685034013605	1.7675	72	691	5	3	14	1	5002	-1	1	0	0	12.005297634179682	
i 1	139.51766666666666	0.2525	71	1077	5	1	10	2	0	-1	2	0	0	3.0	
i 1	139.73233333333334	0.2525	68	691	2	20	2	1	0	-1	1	0	0	0.16663952660314107	
i 1	139.7359387755102	1.01	71	1077	1	24	4	1	0	0	1	0	0	4.1666395266031415	
i 1	139.75540816326532	1.5150000000000001	74	691	4	1	4	8	5002	-2	8	0	0	3.0	
i 1	139.7611768707483	0.2525	71	193	2	24	11	1	0	0	1	0	0	4.1666395266031415	
i 1	139.99098639455784	0.2525	69	193	5	4	15	0	0	0	0	0	0	12.005297634179682	
i 1	140.0025238095238	0.7575000000000001	74	193	4	5	8	2	0	-2	2	0	0	3.0	
i 1	140.00973469387756	0.2525	68	1077	1	20	11	1	0	0	1	0	0	0.16663952660314107	
i 1	140.23738095238096	1.5150000000000001	74	691	6	5	16	8	0	-2	8	0	0	3.0	
i 1	140.2417074829932	0.2525	68	691	2	20	3	1	0	-1	1	0	0	0.16663952660314107	
i 1	140.24459183673468	0.2525	68	193	2	24	11	0	0	-1	0	0	0	4.1666395266031415	
i 1	140.25685034013605	1.5150000000000001	71	1077	6	5	5	2	0	-2	2	0	0	3.0	
i 1	140.49603401360545	1.2625	72	1077	5	9	15	0	0	-1	0	0	0	11.005297634179682	
i 1	140.50468707482995	0.505	71	1077	1	20	3	1	0	0	1	0	0	0.16663952660314107	
i 1	140.51622448979592	0.505	68	1077	1	20	4	1	0	-1	1	0	0	0.16663952660314107	
i 1	140.73521768707482	1.5150000000000001	72	691	6	2	12	0	0	-1	0	0	0	12.005297634179682	
i 1	140.75324489795918	1.7675	74	691	4	24	12	8	5002	-2	8	0	0	6.0	
i 1	140.7582925170068	0.2525	74	1077	6	5	12	2	0	-2	2	0	0	3.0	
i 1	140.9830544217687	9.09	66	691	4	19	15	9	5002	2	9	0	0	4.311502327952767	
i 1	140.9866598639456	0.2525	68	691	2	20	1	1	0	0	1	0	0	0.16663952660314107	
i 1	140.99098639455784	0.2525	74	193	7	5	1	2	0	-2	2	0	0	3.0	
i 1	141.00324489795918	1.2625	71	1077	1	24	12	1	0	0	1	0	0	4.1666395266031415	
i 1	141.01045578231293	1.5150000000000001	74	193	5	24	9	2	0	-2	2	0	0	6.0	
i 1	141.01045578231293	0.2525	71	691	2	20	4	1	0	-1	1	0	0	0.16663952660314107	
i 1	141.01189795918367	9.09	66	1077	4	18	5	9	0	2	9	0	0	4.311502327952767	
i 1	141.2633401360544	0.2525	68	1077	1	20	8	1	0	-1	1	0	0	0.16663952660314107	
i 1	141.2640612244898	1.5150000000000001	74	691	6	5	15	8	5002	-2	8	0	0	3.0	
i 1	141.26622448979592	0.2525	71	1077	1	20	5	0	0	-1	0	0	0	0.16663952660314107	
i 1	141.49819727891156	0.505	71	691	2	20	8	1	0	-1	1	0	0	0.16663952660314107	
i 1	141.5003605442177	1.2625	74	193	7	5	1	2	0	-2	2	0	0	3.0	
i 1	141.5003605442177	0.505	71	691	2	20	11	0	0	-1	0	0	0	0.16663952660314107	
i 1	141.99675510204082	1.7675	71	1077	1	20	13	1	0	0	1	0	0	0.16663952660314107	
i 1	142.00901360544216	0.7575000000000001	71	1077	1	20	11	0	0	0	0	0	0	0.16663952660314107	
i 1	142.0169455782313	1.5150000000000001	71	1077	5	1	4	2	0	-1	2	0	0	3.0	
i 1	142.2640612244898	1.2625	71	691	6	1	9	2	0	-1	2	0	0	3.0	
i 1	142.2669455782313	1.7675	74	1077	6	5	2	2	0	-2	2	0	0	3.0	
i 1	142.5111768707483	3.2825	72	1077	5	9	5	0	0	-1	0	0	0	11.005297634179682	
i 1	142.51189795918367	1.5150000000000001	72	691	6	2	4	0	0	-1	0	0	0	12.005297634179682	
i 1	142.7633401360544	0.2525	71	691	6	5	13	2	5002	-2	2	0	0	3.0	
i 1	142.98738095238096	0.2525	71	1077	1	24	16	1	0	0	1	0	0	4.1666395266031415	
i 1	142.99314965986395	0.2525	74	691	4	1	12	8	5002	-2	8	0	0	3.0	
i 1	143.25685034013605	0.505	71	1077	1	20	2	0	0	0	0	0	0	0.16663952660314107	
i 1	143.2582925170068	0.2525	74	691	4	24	14	8	5002	-2	8	0	0	6.0	
i 1	143.4888231292517	1.5150000000000001	74	193	7	1	1	2	0	-2	2	0	0	3.0	
i 1	143.4917074829932	0.505	71	193	4	5	3	8	0	-2	8	0	0	3.0	
i 1	143.49242857142858	1.2625	71	691	6	5	12	2	5002	-2	2	0	0	3.0	
i 1	143.75540816326532	0.2525	69	691	6	2	1	1	0	-1	1	0	0	12.005297634179682	
i 1	143.76189795918367	1.01	71	1077	1	24	10	1	0	0	1	0	0	4.1666395266031415	
i 1	144.00685034013605	9.09	61	1077	4	18	7	6	0	1	6	0	0	4.311502327952767	
i 1	144.01261904761904	0.2525	69	691	4	4	3	0	5002	-1	0	0	0	12.005297634179682	
i 1	144.01766666666666	1.7675	72	691	4	2	8	0	0	-1	0	0	0	12.005297634179682	
i 1	144.2359387755102	1.5150000000000001	74	691	6	1	13	2	0	-2	2	0	0	3.0	
i 1	144.24675510204082	0.2525	71	1077	1	20	8	1	0	0	1	0	0	0.16663952660314107	
i 1	144.25685034013605	1.5150000000000001	71	1077	6	1	10	2	0	-1	2	0	0	3.0	
i 1	144.2582925170068	2.7775	74	1077	6	5	1	2	0	-2	2	0	0	3.0	
i 1	144.4974761904762	0.2525	72	691	5	3	3	1	5002	-1	1	0	0	12.005297634179682	
i 1	144.51766666666666	0.2525	71	193	2	24	11	1	0	-1	1	0	0	4.1666395266031415	
i 1	144.7388231292517	1.01	71	1077	1	20	7	0	0	0	0	0	0	0.16663952660314107	
i 1	144.7525238095238	1.01	71	1077	1	20	14	0	0	0	0	0	0	0.16663952660314107	
i 1	144.98738095238096	2.02	71	1077	1	24	7	1	0	0	1	0	0	4.1666395266031415	
i 1	145.0003605442177	0.2525	71	691	6	1	14	2	0	-1	2	0	0	3.0	
i 1	145.24314965986395	0.505	74	193	7	1	9	2	0	-2	2	0	0	3.0	
i 1	145.25108163265307	0.505	74	691	4	1	13	8	5002	-2	8	0	0	3.0	
i 1	145.49891836734693	2.525	74	193	5	24	13	2	0	-2	2	0	0	6.0	
i 1	145.50396598639455	0.2525	71	691	6	5	6	2	5002	-2	2	0	0	3.0	
i 1	145.51045578231293	2.525	74	691	4	24	12	8	5002	-2	8	0	0	6.0	
i 1	145.73377551020408	0.2525	69	193	5	4	5	0	0	0	0	0	0	12.005297634179682	
i 1	145.7359387755102	0.2525	69	691	4	4	2	0	5002	-1	0	0	0	12.005297634179682	
i 1	145.75180272108844	0.2525	71	193	2	24	14	0	0	0	0	0	0	4.1666395266031415	
i 1	145.76189795918367	0.2525	68	691	2	20	5	0	0	-1	0	0	0	0.16663952660314107	
i 1	146.0025238095238	0.2525	71	1077	3	5	1	2	0	-2	2	0	0	3.0	
i 1	146.00396598639455	1.01	69	691	6	2	10	1	0	-1	1	0	0	12.005297634179682	
i 1	146.25324489795918	0.2525	71	691	6	1	8	2	0	-1	2	0	0	3.0	
i 1	146.25901360544216	0.2525	69	193	6	3	6	0	0	0	0	0	0	12.005297634179682	
i 1	146.75973469387756	0.2525	68	1077	1	20	6	1	0	-1	1	0	0	0.16663952660314107	
i 1	146.76478231292518	1.5150000000000001	74	193	7	5	3	2	0	-2	2	0	0	3.0	
i 1	146.76478231292518	0.2525	71	1077	1	20	8	0	0	-1	0	0	0	0.16663952660314107	
i 1	146.76766666666666	0.2525	69	193	6	3	1	0	0	0	0	0	0	12.005297634179682	
i 1	146.98449659863945	1.5150000000000001	68	1077	1	20	6	1	0	-1	1	0	0	0.03440842368886621	
i 1	146.99891836734693	0.505	74	1077	3	5	10	2	0	-2	2	0	0	3.0	
i 1	147.0003605442177	1.5150000000000001	71	1077	1	24	15	1	0	0	1	0	0	4.034408423688866	
i 1	147.00108163265307	0.2525	71	691	6	1	8	2	0	-1	2	0	0	3.0	
i 1	147.00108163265307	0.7575000000000001	69	691	4	2	11	1	0	-1	1	0	0	12.005297634179682	
i 1	147.00973469387756	9.09	61	691	4	19	5	9	5002	2	9	0	0	4.311502327952767	
i 1	147.01766666666666	1.2625	74	691	6	5	3	8	5002	-2	8	0	0	3.0	
i 1	147.49314965986395	0.2525	71	193	7	5	12	8	0	-2	8	0	0	3.0	
i 1	147.73521768707482	1.5150000000000001	72	691	5	3	8	1	5002	-1	1	0	0	12.005297634179682	
i 1	147.75540816326532	1.5150000000000001	69	193	6	3	2	0	0	0	0	0	0	12.005297634179682	
i 1	147.99603401360545	1.01	74	691	4	1	8	8	5002	-2	8	0	0	3.0	
i 1	147.99891836734693	0.2525	68	691	4	20	1	0	0	0	0	0	0	0.03440842368886621	
i 1	148.01766666666666	0.2525	71	691	2	20	3	0	0	0	0	0	0	0.03440842368886621	
i 1	148.23738095238096	3.0300000000000002	71	691	1	24	6	0	0	248	0	308	0	4.034408423688866	
i 1	148.26550340136055	0.2525	71	1077	6	1	9	2	0	-1	2	0	0	3.0	
i 1	148.2669455782313	1.2625	71	1077	1	20	2	1	0	0	1	0	0	0.03440842368886621	
i 1	148.74603401360545	1.2625	72	691	4	2	7	0	0	-1	0	0	0	12.005297634179682	
i 1	148.75180272108844	1.2625	72	1077	5	9	8	0	0	-1	0	0	0	11.005297634179682	
i 1	149.00540816326532	0.7575000000000001	74	691	4	24	9	8	5002	-2	8	0	0	6.0	
i 1	149.25108163265307	0.7575000000000001	74	691	6	5	6	8	5002	-2	8	0	0	3.0	
i 1	149.26189795918367	1.01	74	193	7	5	5	2	0	-2	2	0	0	3.0	
i 1	149.49603401360545	2.02	71	1077	1	24	7	1	0	0	1	0	0	4.034408423688866	
i 1	149.75396598639455	0.2525	69	193	5	4	7	0	0	0	0	0	0	12.005297634179682	
i 1	149.99026530612244	9.09	66	691	4	19	9	9	5002	2	9	0	0	4.311502327952767	
i 1	150.0003605442177	1.2625	71	1077	3	20	15	0	0	0	0	0	0	0.03440842368886621	
i 1	150.01045578231293	0.7575000000000001	72	1077	5	9	3	0	0	-1	0	0	0	11.005297634179682	
i 1	150.0140612244898	0.505	74	691	2	5	15	8	5002	-2	8	0	0	3.0	
i 1	150.01550340136055	1.5150000000000001	68	1077	1	20	15	1	0	-1	1	0	0	0.03440842368886621	
i 1	150.24891836734693	2.7775	74	1077	6	5	9	2	0	-2	2	0	0	3.0	
i 1	150.2611768707483	1.7675	69	691	4	2	7	1	0	-1	1	0	0	12.005297634179682	
i 1	150.76766666666666	0.7575000000000001	74	193	7	1	4	2	0	-2	2	0	0	3.0	
i 1	151.00757142857142	0.2525	71	1077	3	20	7	1	0	0	1	0	0	0.03440842368886621	
i 1	151.2503605442177	1.01	74	691	5	1	8	2	0	-2	2	0	0	3.0	
i 1	151.25324489795918	0.2525	71	691	4	20	10	1	0	-1	1	0	0	0.03440842368886621	
i 1	151.2582925170068	1.01	71	1077	6	1	16	2	0	-1	2	0	0	3.0	
i 1	151.25973469387756	0.2525	68	691	4	20	6	0	0	0	0	0	0	0.03440842368886621	
i 1	151.51189795918367	1.01	71	1077	3	20	9	0	0	0	0	0	0	0.03440842368886621	
i 1	151.73449659863945	0.2525	71	691	6	5	14	2	5002	-2	2	0	0	3.0	
i 1	151.74314965986395	0.2525	71	193	7	5	5	8	0	-2	8	0	0	3.0	
i 1	151.99242857142858	1.01	71	691	6	5	16	8	0	-2	8	0	0	3.0	
i 1	151.99819727891156	1.7675	72	1077	5	9	12	0	0	-1	0	0	0	11.005297634179682	
i 1	152.00396598639455	1.7675	72	691	6	2	9	0	0	-1	0	0	0	12.005297634179682	
i 1	152.2330544217687	1.5150000000000001	74	691	5	1	13	8	5002	-2	8	0	0	3.0	
i 1	152.76622448979592	1.01	71	1077	1	24	3	1	0	0	1	0	0	4.034408423688866	
i 1	152.98810204081633	1.01	71	1077	6	5	7	2	0	-2	2	0	0	3.0	
i 1	152.99026530612244	15.15	61	691	1	27	1	6	5002	252	6	307	0	0.5926930101670749	
i 1	153.00757142857142	0.2525	69	691	6	2	1	1	0	-1	1	0	0	12.005297634179682	
i 1	153.01045578231293	0.2525	71	691	2	20	2	0	0	0	0	0	0	0.03440842368886621	
i 1	153.24603401360545	0.2525	71	193	2	24	14	0	0	-1	0	0	0	4.034408423688866	
i 1	153.4859387755102	0.7575000000000001	68	1077	1	20	12	1	0	-1	1	0	0	0.03440842368886621	
i 1	153.48810204081633	0.505	69	691	4	4	16	0	5002	-1	0	0	0	12.005297634179682	
i 1	153.49675510204082	0.7575000000000001	71	691	2	20	13	0	0	0	0	0	0	0.03440842368886621	
i 1	153.49891836734693	0.7575000000000001	68	1077	3	20	9	0	0	-1	0	0	0	0.03440842368886621	
i 1	153.51261904761904	0.2525	71	691	6	5	14	8	0	-2	8	0	0	3.0	
i 1	153.74387074829932	3.0300000000000002	69	691	6	2	10	1	0	-1	1	0	0	12.005297634179682	
i 1	153.7640612244898	3.0300000000000002	69	1077	5	9	3	0	0	-1	0	0	0	11.005297634179682	
i 1	154.01478231292518	1.2625	71	691	6	5	14	8	0	-2	8	0	0	3.0	
i 1	154.2474761904762	0.7575000000000001	71	193	4	20	5	1	0	-1	1	0	0	0.03440842368886621	
i 1	154.25612925170068	0.7575000000000001	71	193	1	24	8	1	0	252	1	307	0	4.034408423688866	
i 1	155.23810204081633	1.2625	74	691	5	1	15	8	5002	-2	8	0	0	3.0	
i 1	155.23954421768707	0.7575000000000001	74	193	7	5	12	2	0	-2	2	0	0	3.0	
i 1	155.25324489795918	0.7575000000000001	74	193	7	1	2	2	0	-2	2	0	0	3.0	
i 1	155.25685034013605	0.2525	71	1077	1	24	14	1	0	0	1	0	0	4.034408423688866	
i 1	155.2611768707483	0.7575000000000001	74	691	6	5	12	8	5002	-2	8	0	0	3.0	
i 1	155.4866598639456	0.2525	71	691	2	20	15	0	0	0	0	0	0	0.03440842368886621	
i 1	155.50901360544216	0.2525	68	1077	3	20	14	0	0	-1	0	0	0	0.03440842368886621	
i 1	155.75180272108844	1.5150000000000001	71	1077	3	20	12	0	0	-1	0	0	0	0.03440842368886621	
i 1	155.7633401360544	1.5150000000000001	71	1077	1	24	12	1	0	0	1	0	0	4.034408423688866	
i 1	156.00396598639455	1.5150000000000001	71	1077	6	5	8	2	0	-2	2	0	0	3.0	
i 1	156.00468707482995	0.505	74	193	5	1	5	2	0	-2	2	0	0	3.0	
i 1	156.00757142857142	1.5150000000000001	74	691	6	5	6	8	0	-2	8	0	0	3.0	
i 1	156.01478231292518	1.2625	71	691	2	24	7	0	0	0	0	0	0	4.034408423688866	
i 1	156.4996394557823	0.2525	74	691	4	24	2	8	5002	-2	8	0	0	6.0	
i 1	156.51478231292518	0.2525	74	193	5	24	9	2	0	-2	2	0	0	6.0	
i 1	156.7417074829932	1.01	71	1077	6	1	9	2	0	-1	2	0	0	3.0	
i 1	156.74387074829932	1.5150000000000001	72	691	4	3	15	1	5002	-1	1	0	0	12.005297634179682	
i 1	156.7640612244898	1.5150000000000001	69	193	6	3	13	0	0	0	0	0	0	12.005297634179682	
i 1	157.23377551020408	0.7575000000000001	71	691	2	20	6	0	0	0	0	0	0	0.03440842368886621	
i 1	157.25468707482995	0.7575000000000001	68	1077	1	20	4	1	0	-1	1	0	0	0.03440842368886621	
i 1	157.26622448979592	0.7575000000000001	68	1077	3	20	14	0	0	-1	0	0	0	0.03440842368886621	
i 1	157.4974761904762	0.2525	74	193	6	5	6	2	0	-2	2	0	0	3.0	
i 1	157.51189795918367	0.2525	74	691	6	5	12	8	5002	-2	8	0	0	3.0	
i 1	157.75180272108844	1.2625	74	193	5	1	7	2	0	-2	2	0	0	3.0	
i 1	157.75757142857142	1.01	74	1077	6	5	6	2	0	-2	2	0	0	3.0	
i 1	157.9830544217687	0.505	68	193	4	20	12	1	0	0	1	0	0	0.03440842368886621	
i 1	158.26189795918367	0.2525	72	1077	3	9	3	0	0	-1	0	0	0	11.005297634179682	
i 1	158.49242857142858	0.2525	68	691	2	20	10	0	0	0	0	0	0	0.03440842368886621	
i 1	158.5003605442177	0.505	69	1077	5	9	1	0	0	-1	0	0	0	11.005297634179682	
i 1	158.73521768707482	0.2525	71	1077	1	24	16	1	0	0	1	0	0	4.034408423688866	
i 1	158.74314965986395	0.2525	71	193	7	5	4	8	0	-2	8	0	0	3.0	
i 1	158.75612925170068	0.2525	68	691	2	24	8	0	0	0	0	0	0	4.034408423688866	
i 1	158.76622448979592	1.01	71	691	6	5	6	2	5002	-2	2	0	0	3.0	
i 1	158.98449659863945	0.2525	68	691	2	20	2	0	0	0	0	0	0	0.03440842368886621	
i 1	158.9866598639456	0.7575000000000001	71	193	6	5	15	8	0	-2	8	0	0	3.0	
i 1	159.24026530612244	0.505	68	691	2	24	9	0	0	0	0	0	0	4.034408423688866	
i 1	159.25757142857142	0.505	71	1077	3	20	6	0	0	0	0	0	0	0.03440842368886621	
i 1	159.7330544217687	1.2625	74	1077	6	5	11	2	0	-2	2	0	0	3.0	
i 1	159.73738095238096	1.7675	72	691	6	2	11	0	0	-1	0	0	0	12.005297634179682	
i 1	159.7503605442177	0.2525	71	691	4	20	1	0	0	-1	0	0	0	0.03440842368886621	
i 1	159.75685034013605	1.7675	72	1077	3	9	10	0	0	-1	0	0	0	11.005297634179682	
i 1	159.76766666666666	1.2625	68	1077	1	20	1	1	0	-1	1	0	0	0.03440842368886621	
i 1	160.00180272108844	0.7575000000000001	74	691	5	1	1	8	5002	-2	8	0	0	3.0	
i 1	160.01045578231293	1.01	71	691	2	20	2	0	0	-1	0	0	0	0.03440842368886621	
i 1	160.73954421768707	1.5150000000000001	74	193	5	24	14	2	0	-2	2	0	0	6.0	
i 1	160.98233333333334	0.2525	68	691	4	20	12	0	0	0	0	0	0	0.03440842368886621	
i 1	160.98377551020408	0.505	71	1077	3	24	5	1	0	0	1	0	0	4.034408423688866	
i 1	161.00396598639455	0.7575000000000001	74	691	6	5	10	8	0	-2	8	0	0	3.0	
i 1	161.00540816326532	0.2525	68	193	4	24	15	1	0	0	1	0	0	4.034408423688866	
i 1	161.2633401360544	0.2525	68	691	2	24	6	0	0	0	0	0	0	4.034408423688866	
i 1	161.4866598639456	1.5150000000000001	69	691	4	4	2	0	5002	-1	0	0	0	12.005297634179682	
i 1	161.50468707482995	0.2525	68	1077	3	20	4	0	0	0	0	0	0	0.03440842368886621	
i 1	161.50540816326532	0.2525	68	691	2	20	9	0	0	-1	0	0	0	0.03440842368886621	
i 1	161.50901360544216	1.5150000000000001	69	193	5	4	2	0	0	0	0	0	0	12.005297634179682	
i 1	161.7359387755102	0.505	68	193	1	24	16	0	0	248	0	308	0	4.034408423688866	
i 1	161.73738095238096	1.5150000000000001	74	1077	6	5	8	2	0	-2	2	0	0	3.0	
i 1	162.2474761904762	1.01	74	691	5	1	6	8	5002	-2	8	0	0	3.0	
i 1	162.25468707482995	1.01	74	193	5	1	14	2	0	-2	2	0	0	3.0	
i 1	162.48738095238096	0.2525	68	193	4	20	15	0	0	-1	0	0	0	0.03440842368886621	
i 1	162.49098639455784	0.2525	71	1077	3	24	11	1	0	0	1	0	0	4.034408423688866	
i 1	162.74459183673468	1.01	68	691	2	20	13	0	0	0	0	0	0	0.03440842368886621	
i 1	162.75685034013605	0.7575000000000001	68	1077	3	20	14	1	0	-1	1	0	0	0.03440842368886621	
i 1	163.00468707482995	1.7675	69	691	6	2	15	1	0	-1	1	0	0	12.005297634179682	
i 1	163.23521768707482	1.2625	74	691	4	24	12	8	5002	-2	8	0	0	6.0	
i 1	163.24098639455784	0.2525	74	691	6	5	16	8	5002	-2	8	0	0	3.0	
i 1	163.26189795918367	0.2525	74	193	6	5	7	2	0	-2	2	0	0	3.0	
i 1	163.4866598639456	1.01	74	691	6	5	7	8	0	-2	8	0	0	3.0	
i 1	163.99531292517005	1.01	71	1077	3	24	15	1	0	0	1	0	0	4.034408423688866	
i 1	164.0111768707483	1.01	71	691	2	24	3	1	0	0	1	0	0	4.034408423688866	
i 1	164.01478231292518	0.7575000000000001	68	1077	3	20	4	1	0	-1	1	0	0	0.03440842368886621	
i 1	164.49819727891156	1.01	74	691	6	5	11	8	5002	-2	8	0	0	3.0	
i 1	164.50612925170068	0.505	71	1077	6	1	15	2	0	-1	2	0	0	3.0	
i 1	164.74531292517005	1.2625	72	691	2	3	8	1	5002	-1	1	0	0	12.005297634179682	
i 1	164.75396598639455	1.2625	69	193	6	3	5	0	0	0	0	0	0	12.005297634179682	
i 1	164.9830544217687	0.2525	71	691	4	20	15	0	0	-1	0	0	0	0.03440842368886621	
i 1	164.9974761904762	0.505	68	193	4	20	15	1	0	-1	1	0	0	0.03440842368886621	
i 1	164.99819727891156	0.2525	68	1077	3	20	8	1	0	-1	1	0	0	0.03440842368886621	
i 1	165.0140612244898	6.3125	66	691	5	17	11	9	0	1	9	0	0	4.311502327952767	
i 1	165.01622448979592	0.505	68	691	2	24	11	0	5002	0	0	0	0	4.034408423688866	
i 1	165.4974761904762	1.2625	71	691	6	5	10	8	0	-2	8	0	0	3.0	
i 1	165.50396598639455	0.2525	71	691	2	20	6	0	0	0	0	0	0	0.03440842368886621	
i 1	165.50540816326532	0.505	68	691	2	24	12	0	0	-1	0	0	0	4.034408423688866	
i 1	165.51045578231293	0.505	71	1077	3	24	10	1	0	0	1	0	0	4.034408423688866	
i 1	165.5169455782313	0.7575000000000001	74	691	5	1	1	8	5002	-2	8	0	0	3.0	
i 1	165.73377551020408	0.2525	68	1077	3	20	1	0	0	0	0	0	0	0.03440842368886621	
i 1	165.98521768707482	0.505	72	1077	5	9	14	0	0	-1	0	0	0	11.005297634179682	
i 1	166.01261904761904	0.2525	68	193	4	24	6	0	0	-1	0	0	0	4.034408423688866	
i 1	166.01478231292518	0.2525	68	691	4	20	6	0	0	-1	0	0	0	0.03440842368886621	
i 1	166.2359387755102	1.2625	74	691	5	1	10	2	0	-2	2	0	0	3.0	
i 1	166.2474761904762	0.7575000000000001	71	691	2	24	13	0	0	0	0	0	0	4.034408423688866	
i 1	166.24891836734693	0.7575000000000001	68	691	2	24	10	0	5002	0	0	0	0	4.034408423688866	
i 1	166.25685034013605	0.7575000000000001	71	1077	3	24	9	1	0	0	1	0	0	4.034408423688866	
i 1	166.26189795918367	1.2625	71	1077	4	1	3	2	0	-1	2	0	0	3.0	
i 1	166.48233333333334	1.2625	69	691	6	2	2	1	0	-1	1	0	0	12.005297634179682	
i 1	166.48954421768707	1.2625	69	1077	5	9	6	0	0	-1	0	0	0	11.005297634179682	
i 1	166.75108163265307	0.7575000000000001	71	193	6	5	14	8	0	-2	8	0	0	3.0	
i 1	166.7582925170068	0.7575000000000001	71	691	6	5	4	2	5002	-2	2	0	0	3.0	
i 1	167.00324489795918	0.2525	68	691	2	20	11	1	0	-1	1	0	0	0.03440842368886621	
i 1	167.24242857142858	0.505	68	1077	3	20	1	1	0	0	1	0	0	0.03440842368886621	
i 1	167.25685034013605	0.505	68	1077	3	20	2	1	0	-1	1	0	0	0.03440842368886621	
i 1	167.26189795918367	2.7775	71	1077	3	24	3	1	0	0	1	0	0	4.034408423688866	
i 1	167.49026530612244	1.5150000000000001	74	1077	5	5	14	2	0	-2	2	0	0	3.0	
i 1	167.4917074829932	1.5150000000000001	71	691	6	5	10	8	0	-2	8	0	0	3.0	
i 1	167.50324489795918	0.2525	74	691	5	1	3	8	5002	-2	8	0	0	3.0	
i 1	167.74242857142858	3.0300000000000002	72	691	4	2	11	0	0	-1	0	0	0	12.005297634179682	
i 1	167.7503605442177	3.0300000000000002	72	1077	5	9	4	0	0	-1	0	0	0	11.005297634179682	
i 1	167.7525238095238	2.2725	74	691	4	24	13	8	5002	-2	8	0	0	6.0	
i 1	167.75612925170068	0.2525	68	691	2	20	13	1	0	-1	1	0	0	0.03440842368886621	
i 1	167.98954421768707	3.2825	61	691	5	17	10	6	0	1	6	0	0	4.311502327952767	
i 1	167.99026530612244	4.545	61	691	3	27	7	6	5002	1	6	0	0	0.5926930101670749	
i 1	168.00540816326532	2.02	68	1077	3	20	6	1	0	-1	1	0	0	0.03440842368886621	
i 1	168.00685034013605	1.7675	68	1077	3	20	3	1	0	0	1	0	0	0.03440842368886621	
i 1	169.0003605442177	0.2525	74	691	6	5	14	8	0	-2	8	0	0	3.0	
i 1	169.01261904761904	0.2525	71	1077	5	5	12	2	0	-2	2	0	0	3.0	
i 1	169.25540816326532	1.01	71	691	6	5	10	8	0	-2	8	0	0	3.0	
i 1	169.73954421768707	0.2525	71	193	4	24	12	0	0	0	0	0	0	4.034408423688866	
i 1	169.74026530612244	0.2525	68	691	4	20	7	0	0	0	0	0	0	0.03440842368886621	
i 1	169.74819727891156	0.2525	68	691	2	24	6	0	5002	0	0	0	0	4.034408423688866	
i 1	169.99098639455784	1.2625	74	691	3	1	3	8	5002	-2	8	0	0	3.0	
i 1	170.2388231292517	0.2525	71	691	2	24	3	0	0	-1	0	0	0	4.034408423688866	
i 1	170.24531292517005	1.01	71	1077	3	24	4	1	0	0	1	0	0	4.034408423688866	
i 1	170.26045578231293	1.01	74	193	6	5	4	2	0	-2	2	0	0	3.0	
i 1	170.49603401360545	0.505	68	691	2	20	1	0	5002	0	0	0	0	0.03440842368886621	
i 1	170.50180272108844	0.505	71	691	4	20	15	1	0	-1	1	0	0	0.03440842368886621	
i 1	170.5169455782313	0.2525	74	193	5	24	13	2	0	-2	2	0	0	6.0	
i 1	170.75180272108844	0.2525	69	691	2	4	8	0	5002	-1	0	0	0	12.005297634179682	
i 1	170.76622448979592	0.505	69	193	5	4	5	0	0	0	0	0	0	12.005297634179682	
i 1	170.98377551020408	0.2525	71	691	2	24	2	1	0	-1	1	0	0	4.034408423688866	
i 1	170.9888231292517	1.5150000000000001	66	691	3	27	14	6	5002	1	6	0	0	0.5926930101670749	
i 1	170.99098639455784	0.2525	66	193	5	17	6	9	0	2	9	0	0	4.311502327952767	
i 1	170.9974761904762	0.2525	69	691	4	2	6	1	0	-1	1	0	0	12.005297634179682	
i 1	171.00901360544216	0.2525	69	193	4	3	10	0	0	0	0	0	0	12.005297634179682	
i 1	171.01045578231293	0.2525	74	193	5	24	15	2	0	-2	2	0	0	6.0	
i 1	171.0140612244898	0.2525	69	1077	5	9	16	0	0	-1	0	0	0	11.005297634179682	
i 1	171.23449659863945	1.2625	61	1098	5	17	4	9	0	2	9	0	0	4.311502327952767	
i 1	171.23521768707482	0.2525	68	214	4	24	11	1	5003	0	1	0	0	4.034408423688866	
i 1	171.23810204081633	8.8375	66	712	5	17	7	6	5001	2	6	0	0	4.311502327952767	
i 1	171.2496394557823	1.2625	61	1098	5	17	1	9	0	1	9	0	0	4.311502327952767	
i 1	171.26045578231293	1.2625	68	691	2	20	6	1	5001	-1	1	0	0	0.03440842368886621	
i 1	171.2633401360544	0.505	72	712	4	3	9	1	5001	-1	1	0	0	12.005297634179682	
i 1	171.2669455782313	0.2525	71	691	2	24	16	1	5001	-1	1	0	0	4.034408423688866	
i 1	171.26766666666666	1.2625	71	691	4	5	13	2	5002	-2	2	0	0	3.0	
i 1	171.4888231292517	0.2525	71	712	6	5	5	2	5001	-2	2	0	0	3.0	
i 1	171.75180272108844	0.7575000000000001	69	1098	4	2	1	1	0	-1	1	0	0	12.005297634179682	
i 1	172.23233333333334	0.2525	71	691	2	24	2	1	5001	-1	1	0	0	4.034408423688866	
i 1	172.48377551020408	0.7575000000000001	71	712	6	5	10	2	5001	-2	2	0	0	3.0	
i 1	172.48449659863945	0.7575000000000001	74	1069	4	5	12	8	0	-2	8	0	0	3.0	
i 1	172.4917074829932	4.545	66	1069	3	27	9	9	0	1	9	0	0	0.5926930101670749	
i 1	172.4974761904762	3.535	72	214	6	9	9	1	5003	0	1	0	0	11.005297634179682	
i 1	172.5025238095238	1.5150000000000001	69	185	5	2	13	1	5004	0	1	0	0	12.005297634179682	
i 1	172.5025238095238	7.575	61	185	6	17	15	6	5004	2	6	0	0	4.311502327952767	
i 1	172.50757142857142	0.505	71	1069	2	24	7	1	5001	-1	1	0	0	4.034408423688866	
i 1	172.50901360544216	1.5150000000000001	61	1069	3	27	15	9	0	1	9	0	0	0.5926930101670749	
i 1	172.51045578231293	0.2525	71	1069	2	20	3	0	0	-1	0	0	0	0.03440842368886621	
i 1	172.51189795918367	0.2525	74	1069	3	1	4	2	0	-1	2	0	0	3.0	
i 1	172.5140612244898	7.575	61	185	6	17	9	9	5004	2	9	0	0	4.311502327952767	
i 1	172.73810204081633	2.7775	68	214	4	20	1	1	5003	0	1	0	0	0.03440842368886621	
i 1	172.75324489795918	2.525	71	1069	3	24	8	2	0	-1	2	0	0	6.0	
i 1	172.9866598639456	1.01	71	185	7	5	5	8	5004	-2	8	0	0	3.0	
i 1	173.0169455782313	1.7675	74	214	6	5	8	2	5003	-2	2	0	0	3.0	
i 1	173.24531292517005	1.7675	68	214	4	24	14	1	5003	0	1	0	0	4.034408423688866	
i 1	173.2474761904762	0.2525	71	712	5	1	3	2	5001	-2	2	0	0	3.0	
i 1	173.25468707482995	0.505	71	1069	2	24	11	0	0	-1	0	0	0	4.034408423688866	
i 1	173.48377551020408	0.2525	68	185	4	20	2	1	5004	-1	1	0	0	0.03440842368886621	
i 1	173.4859387755102	0.2525	74	712	6	5	12	2	5001	-2	2	0	0	3.0	
i 1	173.50108163265307	0.2525	71	185	4	20	6	0	5004	-1	0	0	0	0.03440842368886621	
i 1	173.5140612244898	0.2525	71	712	4	24	4	1	5001	0	1	0	0	4.034408423688866	
i 1	173.73954421768707	1.5150000000000001	68	214	4	20	8	1	5004	-1	1	0	0	0.03440842368886621	
i 1	173.75612925170068	1.2625	71	1069	2	24	7	0	5001	0	0	0	0	4.034408423688866	
i 1	173.75612925170068	0.505	71	1069	1	24	3	0	0	252	0	307	0	4.034408423688866	
i 1	173.7611768707483	0.2525	72	214	6	9	7	1	5003	0	1	0	0	11.005297634179682	
i 1	173.98954421768707	6.0600000000000005	61	1069	3	27	5	9	0	1	9	0	0	0.5926930101670749	
i 1	173.99098639455784	1.7675	69	185	7	2	15	1	5004	0	1	0	0	12.005297634179682	
i 1	174.00540816326532	6.0600000000000005	66	712	5	17	14	6	5001	2	6	0	0	4.311502327952767	
i 1	174.0169455782313	0.2525	71	712	5	1	14	2	5001	-2	2	0	0	3.0	
i 1	174.24675510204082	0.2525	74	712	6	5	1	2	5001	-2	2	0	0	3.0	
i 1	174.2496394557823	0.7575000000000001	71	1069	2	24	6	0	0	-1	0	0	0	4.034408423688866	
i 1	174.25180272108844	0.7575000000000001	68	214	4	20	9	0	5004	-1	0	0	0	0.03440842368886621	
i 1	174.48738095238096	2.525	71	1069	2	20	12	0	0	-1	0	0	0	0.03440842368886621	
i 1	174.73738095238096	1.2625	74	1069	3	1	13	2	0	-1	2	0	0	3.0	
i 1	174.74026530612244	0.2525	71	214	6	5	2	2	5003	-1	2	0	0	3.0	
i 1	174.76622448979592	1.2625	71	712	5	1	3	2	5001	-2	2	0	0	3.0	
i 1	174.7669455782313	0.2525	74	185	7	5	6	8	5004	-1	8	0	0	3.0	
i 1	174.9866598639456	1.01	74	214	6	5	9	2	5003	-2	2	0	0	3.0	
i 1	174.99531292517005	0.505	74	1069	4	5	13	2	0	-2	2	0	0	3.0	
i 1	175.2474761904762	0.2525	71	1069	2	24	5	0	0	-1	0	0	0	4.034408423688866	
i 1	175.25901360544216	0.2525	68	185	4	20	1	0	5004	0	0	0	0	0.03440842368886621	
i 1	175.26766666666666	0.2525	71	712	4	20	13	0	5001	0	0	0	0	0.03440842368886621	
i 1	175.49531292517005	1.5150000000000001	72	185	5	2	1	0	5004	0	0	0	0	12.005297634179682	
i 1	175.5003605442177	0.2525	69	712	4	4	13	1	5001	-1	1	0	0	12.005297634179682	
i 1	175.5025238095238	0.505	68	1069	2	24	3	0	5001	-1	0	0	0	4.034408423688866	
i 1	175.5133401360544	2.02	72	214	6	9	4	1	5003	0	1	0	0	11.005297634179682	
i 1	175.7474761904762	0.2525	74	185	7	5	13	8	5004	-1	8	0	0	3.0	
i 1	175.75396598639455	1.01	71	712	4	24	16	2	5001	-1	2	0	0	6.0	
i 1	175.98810204081633	1.01	74	712	6	5	7	2	5001	-2	2	0	0	3.0	
i 1	176.0111768707483	1.2625	74	1069	4	5	6	2	0	-2	2	0	0	3.0	
i 1	176.23449659863945	0.505	68	1069	2	24	14	0	5001	-1	0	0	0	4.034408423688866	
i 1	176.25324489795918	0.505	68	214	4	24	2	1	5003	0	1	0	0	4.034408423688866	
i 1	176.25396598639455	0.2525	74	214	5	1	13	2	5003	-1	2	0	0	3.0	
i 1	176.26189795918367	0.2525	69	1069	5	3	11	0	0	-1	0	0	0	12.005297634179682	
i 1	176.4996394557823	0.2525	68	214	4	20	3	0	5004	0	0	0	0	0.03440842368886621	
i 1	176.73954421768707	0.2525	68	712	4	24	14	1	5001	-1	1	0	0	4.034408423688866	
i 1	176.7496394557823	0.2525	71	712	6	5	2	2	5001	-2	2	0	0	3.0	
i 1	176.75108163265307	0.2525	71	185	4	20	16	1	5004	0	1	0	0	0.03440842368886621	
i 1	176.76189795918367	1.7675	71	185	6	1	4	8	5004	-1	8	0	0	3.0	
i 1	176.98738095238096	0.505	71	1069	2	24	14	0	0	-1	0	0	0	5.2003845630418315	
i 1	176.98954421768707	0.2525	68	185	4	20	2	0	5004	-1	0	0	0	1.2003845630418315	
i 1	176.99459183673468	0.2525	71	185	4	20	9	1	5004	0	1	0	0	1.2003845630418315	
i 1	177.00396598639455	0.2525	71	712	4	20	12	0	5001	-1	0	0	0	1.2003845630418315	
i 1	177.0133401360544	3.0300000000000002	66	214	5	18	4	9	5003	2	9	0	0	4.311502327952767	
i 1	177.0133401360544	3.0300000000000002	66	1069	3	27	12	9	0	1	9	0	0	0.5926930101670749	
i 1	177.01478231292518	1.01	71	1069	2	20	11	0	0	-1	0	0	0	1.2003845630418315	
i 1	177.0169455782313	0.2525	68	712	4	24	8	1	5001	-1	1	0	0	5.2003845630418315	
i 1	177.0169455782313	12.3725	68	214	4	24	8	1	5003	0	1	0	0	5.2003845630418315	
i 1	177.2417074829932	0.7575000000000001	68	1069	2	20	7	1	5001	0	1	0	0	1.2003845630418315	
i 1	177.24387074829932	0.2525	71	214	5	1	10	2	5003	-1	2	0	0	3.0	
i 1	177.48954421768707	0.2525	71	185	6	1	14	8	5004	-1	8	0	0	3.0	
i 1	177.50180272108844	1.5150000000000001	69	1069	5	3	8	0	0	-1	0	0	0	12.005297634179682	
i 1	177.75324489795918	1.7675	68	214	4	20	2	1	5003	0	1	0	0	1.2003845630418315	
i 1	178.01622448979592	1.2625	74	712	6	5	6	2	5001	-2	2	0	0	3.0	
i 1	178.23810204081633	0.2525	74	1069	3	1	9	2	0	-1	2	0	0	3.0	
i 1	178.2388231292517	1.7675	71	185	6	1	13	8	5004	-1	8	0	0	3.0	
i 1	178.24459183673468	1.01	74	1069	4	5	15	2	0	-2	2	0	0	3.0	
i 1	178.26045578231293	1.5150000000000001	71	214	5	1	12	2	5003	-1	2	0	0	3.0	
i 1	178.76045578231293	1.2625	71	185	7	5	6	8	5004	-2	8	0	0	3.0	
i 1	179.01766666666666	0.2525	71	185	6	1	7	8	5004	-1	8	0	0	3.0	
i 1	179.23810204081633	0.2525	68	712	4	24	16	0	5001	0	0	0	0	5.2003845630418315	
i 1	179.24098639455784	0.2525	71	1069	2	20	1	0	0	-1	0	0	0	1.2003845630418315	
i 1	179.2525238095238	1.2625	71	1069	2	24	14	0	0	-1	0	0	0	5.2003845630418315	
i 1	179.25612925170068	0.7575000000000001	74	1069	3	1	4	2	0	-1	2	0	0	3.0	
i 1	179.25612925170068	0.2525	69	1069	5	3	6	0	0	-1	0	0	0	12.005297634179682	
i 1	179.25685034013605	0.2525	68	185	4	20	7	1	5004	0	1	0	0	1.2003845630418315	
i 1	179.2582925170068	0.2525	71	214	6	5	3	2	5003	-1	2	0	0	3.0	
i 1	179.50324489795918	0.2525	72	712	4	3	12	1	5001	-1	1	0	0	12.005297634179682	
i 1	179.50757142857142	1.01	71	1069	2	24	3	1	5001	-1	1	0	0	5.2003845630418315	
i 1	179.51550340136055	0.2525	74	1069	4	5	14	2	0	-2	2	0	0	3.0	
i 1	179.51550340136055	1.01	68	214	4	20	12	0	5004	-1	0	0	0	1.2003845630418315	
i 1	179.73810204081633	0.2525	74	1069	4	5	10	8	0	-2	8	0	0	3.0	
i 1	179.74314965986395	0.2525	69	1069	5	3	14	0	0	-1	0	0	0	12.005297634179682	
i 1	179.9830544217687	9.09	66	712	5	17	6	6	5001	2	6	0	0	6.036103259133875	
i 1	179.98377551020408	9.3425	61	185	7	17	4	6	5004	2	6	0	0	6.036103259133875	
i 1	179.98521768707482	6.0600000000000005	66	712	5	17	9	6	5001	2	6	0	0	6.036103259133875	
i 1	179.9866598639456	0.505	74	214	6	5	1	2	5003	-2	2	0	0	6.0038288353252	
i 1	179.98738095238096	3.0300000000000002	61	712	5	13	14	6	5001	1	6	0	0	5.957502830278858	
i 1	179.98810204081633	3.0300000000000002	66	185	6	14	2	9	5004	1	9	0	0	11.376145318337118	
i 1	179.98810204081633	3.0300000000000002	61	185	6	17	1	9	5004	2	9	0	0	6.036103259133875	
i 1	179.98810204081633	6.0600000000000005	61	712	6	7	4	9	5001	2	9	0	0	8.340503962390402	
i 1	179.99314965986395	6.0600000000000005	66	185	6	13	8	6	5004	1	6	0	0	6.50065446762121	
i 1	179.99531292517005	2.2725	69	1069	5	3	1	0	0	-1	0	0	0	11.13301339623682	
i 1	179.99819727891156	9.09	61	214	5	16	14	9	5003	1	9	0	0	9.750981701431815	
i 1	180.00108163265307	9.3425	61	1069	3	12	3	6	0	2	6	0	0	9.750981701431815	
i 1	180.0025238095238	9.3425	66	185	5	14	10	6	5004	2	6	0	0	9.532004528446173	
i 1	180.00540816326532	9.3425	66	214	5	18	16	9	5003	2	9	0	0	6.036103259133875	
i 1	180.0082925170068	3.0300000000000002	61	712	5	15	11	9	5001	1	9	0	0	8.125818084526513	
i 1	180.00973469387756	9.3425	66	185	5	14	14	9	5004	1	9	0	0	9.532004528446173	
i 1	180.01045578231293	9.3425	61	1069	3	12	10	6	0	2	6	0	0	9.750981701431815	
i 1	180.01189795918367	9.09	66	712	5	15	14	6	5001	2	6	0	0	8.125818084526513	
i 1	180.01550340136055	9.3425	66	214	5	18	7	6	5003	1	6	0	0	6.036103259133875	
i 1	180.0169455782313	6.0600000000000005	66	214	5	16	16	6	5003	1	6	0	0	9.750981701431815	
i 1	180.01766666666666	2.02	72	712	5	3	9	1	5001	-1	1	0	0	11.13301339623682	
i 1	180.01766666666666	0.505	71	185	7	5	9	8	5004	-2	8	0	0	6.0038288353252	
i 1	180.25757142857142	0.505	71	1069	2	20	5	0	0	-1	0	0	0	1.2003845630418315	
i 1	180.2669455782313	0.7575000000000001	71	712	6	5	9	2	5001	-2	2	0	0	6.0038288353252	
i 1	180.4996394557823	0.2525	71	712	4	24	16	1	5001	0	1	0	0	5.2003845630418315	
i 1	180.7417074829932	0.2525	72	1069	4	4	13	0	0	-1	0	0	0	11.13301339623682	
i 1	181.26189795918367	0.2525	69	712	4	4	7	1	5001	-1	1	0	0	11.13301339623682	
i 1	181.51189795918367	1.2625	71	214	6	5	8	2	5003	-1	2	0	0	6.0038288353252	
i 1	181.75540816326532	1.5150000000000001	72	214	4	9	13	1	5003	0	1	0	0	10.13301339623682	
i 1	182.23377551020408	0.2525	72	1069	4	4	15	0	0	-1	0	0	0	11.13301339623682	
i 1	182.25468707482995	0.505	71	1069	2	20	7	0	0	-1	0	0	0	1.2003845630418315	
i 1	182.25685034013605	0.505	68	214	4	20	1	1	5003	0	1	0	0	1.2003845630418315	
i 1	182.25973469387756	0.2525	68	712	4	24	2	1	5001	0	1	0	0	5.2003845630418315	
i 1	182.48233333333334	1.5150000000000001	68	214	4	20	11	1	5004	-1	1	0	0	1.2003845630418315	
i 1	182.48738095238096	0.505	72	712	5	3	4	1	5001	-1	1	0	0	11.13301339623682	
i 1	182.5082925170068	2.2725	71	1069	2	24	12	1	5001	-1	1	0	0	5.2003845630418315	
i 1	182.74531292517005	1.5150000000000001	74	214	6	5	2	2	5003	-2	2	0	0	6.0038288353252	
i 1	182.75612925170068	1.5150000000000001	71	185	7	5	5	8	5004	-2	8	0	0	6.0038288353252	
i 1	182.9866598639456	6.3125	61	712	5	15	4	9	5001	1	9	0	0	8.125818084526513	
i 1	182.9866598639456	6.3125	66	1069	3	19	7	9	0	2	9	0	0	6.036103259133875	
i 1	182.9888231292517	6.3125	66	185	6	14	9	9	5004	1	9	0	0	11.376145318337118	
i 1	182.98954421768707	4.2925	71	1069	2	20	7	0	0	-1	0	0	0	1.2003845630418315	
i 1	182.99098639455784	1.01	69	712	4	4	5	1	5001	-1	1	0	0	11.13301339623682	
i 1	182.9917074829932	6.3125	61	185	7	17	13	9	5004	2	9	0	0	6.036103259133875	
i 1	183.00612925170068	6.3125	61	712	4	13	16	6	5001	1	6	0	0	5.957502830278858	
i 1	183.23449659863945	0.2525	69	1069	2	3	15	0	0	-1	0	0	0	11.13301339623682	
i 1	183.4996394557823	3.2825	72	185	7	2	10	0	5004	0	0	0	0	11.13301339623682	
i 1	183.50468707482995	3.2825	72	214	4	9	5	1	5003	0	1	0	0	10.13301339623682	
i 1	183.51766666666666	0.2525	74	185	7	5	7	8	5004	-1	8	0	0	6.0038288353252	
i 1	183.75612925170068	1.5150000000000001	74	712	6	5	15	2	5001	-2	2	0	0	6.0038288353252	
i 1	183.75685034013605	1.2625	74	1069	4	5	13	2	0	-2	2	0	0	6.0038288353252	
i 1	183.98449659863945	0.2525	72	214	4	9	11	1	5003	0	1	0	0	10.13301339623682	
i 1	183.98954421768707	0.505	71	1069	3	24	10	2	0	-1	2	0	0	3.0	
i 1	184.25540816326532	0.2525	71	214	7	5	14	2	5003	-1	2	0	0	6.0038288353252	
i 1	184.5003605442177	0.2525	72	712	5	3	12	1	5001	-1	1	0	0	11.13301339623682	
i 1	184.50973469387756	1.5150000000000001	74	214	6	5	11	2	5003	-2	2	0	0	6.0038288353252	
i 1	184.51045578231293	3.2825	71	185	7	5	11	8	5004	-2	8	0	0	6.0038288353252	
i 1	184.73521768707482	0.2525	72	1069	4	4	11	0	0	-1	0	0	0	11.13301339623682	
i 1	184.7359387755102	0.505	68	185	4	20	10	0	5004	0	0	0	0	1.2003845630418315	
i 1	184.73738095238096	0.505	71	712	4	24	12	1	5001	0	1	0	0	5.2003845630418315	
i 1	184.99603401360545	0.2525	72	214	4	9	2	1	5003	0	1	0	0	10.13301339623682	
i 1	185.23449659863945	0.505	68	214	4	20	11	0	5004	-1	0	0	0	1.2003845630418315	
i 1	185.25396598639455	0.2525	74	1069	4	5	12	8	0	-2	8	0	0	6.0038288353252	
i 1	185.25685034013605	0.505	68	1069	2	24	7	0	5001	-1	0	0	0	5.2003845630418315	
i 1	185.25973469387756	0.7575000000000001	72	1069	4	4	10	0	0	-1	0	0	0	11.13301339623682	
i 1	185.50901360544216	0.2525	71	712	4	24	10	2	5001	-1	2	0	0	3.0	
i 1	185.5169455782313	0.2525	74	712	6	5	12	2	5001	-2	2	0	0	6.0038288353252	
i 1	185.74242857142858	0.2525	74	185	7	5	15	8	5004	-1	8	0	0	6.0038288353252	
i 1	185.7640612244898	0.2525	68	712	4	24	4	0	5001	-1	0	0	0	5.2003845630418315	
i 1	185.98233333333334	3.2825	66	712	6	17	3	6	5001	2	6	0	0	6.036103259133875	
i 1	185.98810204081633	0.7575000000000001	74	712	6	5	12	2	5001	-2	2	0	0	6.0038288353252	
i 1	185.99675510204082	3.2825	66	185	6	13	16	6	5004	1	6	0	0	6.50065446762121	
i 1	185.99675510204082	3.2825	61	1069	3	19	15	9	0	2	9	0	0	6.036103259133875	
i 1	185.9974761904762	3.2825	61	712	4	7	12	9	5001	2	9	0	0	8.340503962390402	
i 1	186.00468707482995	0.2525	72	214	6	9	9	1	5003	0	1	0	0	10.13301339623682	
i 1	186.01261904761904	3.2825	66	214	5	16	12	6	5003	1	6	0	0	9.750981701431815	
i 1	186.0140612244898	0.2525	71	214	4	20	7	1	5004	-1	1	0	0	1.2003845630418315	
i 1	186.01478231292518	1.7675	74	214	7	5	14	2	5003	-2	2	0	0	6.0038288353252	
i 1	186.24459183673468	3.0300000000000002	72	712	5	3	13	1	5001	-1	1	0	0	11.13301339623682	
i 1	186.24891836734693	3.0300000000000002	69	1069	2	3	14	0	0	-1	0	0	0	11.13301339623682	
i 1	186.26261904761904	0.7575000000000001	71	712	4	24	9	1	5001	0	1	0	0	5.2003845630418315	
i 1	186.2640612244898	0.2525	71	185	4	20	11	0	5004	-1	0	0	0	1.2003845630418315	
i 1	186.73954421768707	0.2525	69	185	7	2	8	1	5004	0	1	0	0	11.13301339623682	
i 1	186.7496394557823	0.505	74	185	7	5	2	8	5004	-1	8	0	0	6.0038288353252	
i 1	187.00612925170068	0.2525	69	712	4	4	2	1	5001	-1	1	0	0	11.13301339623682	
i 1	187.01045578231293	1.5150000000000001	71	1069	2	24	3	0	5001	0	0	0	0	5.2003845630418315	
i 1	187.24242857142858	1.5150000000000001	71	712	6	5	9	2	5001	-2	2	0	0	6.0038288353252	
i 1	187.50324489795918	0.2525	72	185	7	2	7	0	5004	0	0	0	0	11.13301339623682	
i 1	187.74026530612244	0.505	71	214	7	5	3	2	5003	-1	2	0	0	6.0038288353252	
i 1	187.76622448979592	0.7575000000000001	69	185	7	2	5	1	5004	0	1	0	0	11.13301339623682	
i 1	187.9830544217687	1.2625	71	712	4	24	13	2	5001	-1	2	0	0	3.0	
i 1	187.99459183673468	0.7575000000000001	71	1069	2	20	3	0	0	-1	0	0	0	1.2003845630418315	
i 1	188.00468707482995	0.505	68	1069	2	20	2	1	5001	-1	1	0	0	1.2003845630418315	
i 1	188.00540816326532	0.505	68	214	4	20	1	0	5004	-1	0	0	0	1.2003845630418315	
i 1	188.00540816326532	1.01	71	1069	2	24	1	0	0	-1	0	0	0	5.2003845630418315	
i 1	188.25901360544216	1.01	71	185	7	5	8	8	5004	-2	8	0	0	6.0038288353252	
i 1	188.4888231292517	0.2525	68	185	4	20	15	0	5004	0	0	0	0	1.2003845630418315	
i 1	188.49026530612244	0.2525	72	1069	2	4	7	0	0	-1	0	0	0	11.13301339623682	
i 1	188.49531292517005	0.2525	68	185	4	20	13	1	5004	0	1	0	0	1.2003845630418315	
i 1	188.51045578231293	0.2525	71	712	4	20	11	0	5001	-1	0	0	0	1.2003845630418315	
i 1	188.74026530612244	0.2525	71	1069	2	20	5	1	5001	0	1	0	0	1.2003845630418315	
i 1	188.74531292517005	0.2525	74	185	7	5	15	8	5004	-1	8	0	0	6.0038288353252	
i 1	188.98738095238096	0.2525	68	214	4	20	9	0	5004	-1	0	0	0	1.2003845630418315	
i 1	189.0025238095238	0.2525	61	214	5	16	2	9	5003	1	9	0	0	9.750981701431815	
i 1	189.00973469387756	0.2525	66	712	6	17	16	6	5001	2	6	0	0	6.036103259133875	
i 1	189.01045578231293	0.2525	66	712	5	15	9	6	5001	2	6	0	0	8.125818084526513	
i 1	189.01189795918367	0.2525	74	1069	5	5	16	2	0	-2	2	0	0	6.0038288353252	
i 1	189.2330544217687	6.0600000000000005	63	1087	5	25	10	1	0	2	1	0	0	1.1853860203341497	
i 1	189.23521768707482	1.01	74	701	6	1	7	16	0	1	16	0	0	2.0	
i 1	189.23810204081633	0.505	71	701	5	9	8	8	0	-1	8	0	0	3.0	
i 1	189.24459183673468	3.0300000000000002	61	203	6	25	9	1	0	1	1	0	0	1.1853860203341497	
i 1	189.24891836734693	1.01	72	701	3	5	16	0	0	-1	0	0	0	3.0	
i 1	189.2496394557823	0.505	74	203	6	2	10	8	0	-1	8	0	0	4.0	
i 1	189.25180272108844	0.505	70	701	3	24	1	2	0	-1	2	0	0	8.0	
i 1	189.25396598639455	1.2625	77	203	7	1	13	17	0	1	17	0	0	2.0	
i 1	189.25396598639455	10.352500000000001	61	701	1	27	4	16	0	252	16	307	0	1.7780790305012246	
i 1	189.25468707482995	0.7575000000000001	73	701	2	20	3	2	0	-2	2	0	0	4.0	
i 1	189.26189795918367	13.3825	61	701	1	27	4	16	0	252	16	307	0	1.7780790305012246	
i 1	189.48521768707482	0.2525	77	1087	4	24	16	16	0	2	16	0	0	5.0	
i 1	189.75180272108844	0.2525	73	203	4	20	10	2	0	-1	2	0	0	4.0	
i 1	189.9866598639456	0.2525	70	701	3	24	6	2	0	-1	2	0	0	8.0	
i 1	190.00685034013605	0.2525	70	1087	3	24	11	8	0	-2	8	0	0	8.0	
i 1	190.2633401360544	0.7575000000000001	77	1087	4	24	9	16	0	2	16	0	0	5.0	
i 1	190.2640612244898	1.2625	72	1087	3	5	13	1	0	0	1	0	0	3.0	
i 1	190.2640612244898	0.2525	72	701	6	5	16	1	0	0	1	0	0	3.0	
i 1	190.48377551020408	1.01	72	701	3	5	13	1	0	0	1	0	0	3.0	
i 1	190.48738095238096	0.2525	70	1087	3	20	1	8	0	-1	8	0	0	4.0	
i 1	190.48810204081633	7.8275	63	1087	5	25	4	1	0	2	1	0	0	1.1853860203341497	
i 1	190.73233333333334	0.2525	73	701	2	24	14	8	0	-1	8	0	0	8.0	
i 1	190.74819727891156	0.2525	74	701	6	1	3	16	0	1	16	0	0	2.0	
i 1	190.98449659863945	1.2625	74	203	5	1	14	17	0	2	17	0	0	2.0	
i 1	191.23449659863945	1.7675	71	701	5	9	2	8	0	-1	8	0	0	3.0	
i 1	191.24531292517005	0.2525	72	701	3	5	2	0	0	-1	0	0	0	3.0	
i 1	191.2633401360544	0.505	70	701	3	24	4	2	0	-1	2	0	0	8.0	
i 1	191.26550340136055	0.2525	74	203	6	2	8	8	0	-1	8	0	0	4.0	
i 1	191.26550340136055	0.505	70	701	3	20	4	2	0	-1	2	0	0	4.0	
i 1	191.2669455782313	0.2525	77	1087	6	1	13	16	0	1	16	0	0	2.0	
i 1	191.2669455782313	0.2525	70	701	3	20	1	8	0	-1	8	0	0	4.0	
i 1	191.4888231292517	1.5150000000000001	69	203	6	5	8	0	0	0	0	0	0	3.0	
i 1	191.50180272108844	0.2525	71	1087	5	3	8	8	0	-1	8	0	0	4.0	
i 1	191.50468707482995	1.5150000000000001	69	701	3	5	4	0	0	0	0	0	0	3.0	
i 1	191.5082925170068	0.7575000000000001	73	701	3	20	1	2	0	-2	2	0	0	4.0	
i 1	191.73521768707482	0.2525	70	203	4	20	7	2	0	-1	2	0	0	4.0	
i 1	191.74603401360545	0.2525	74	701	6	1	11	16	0	1	16	0	0	2.0	
i 1	191.98233333333334	0.2525	70	701	3	20	6	2	0	-2	2	0	0	4.0	
i 1	191.98521768707482	0.2525	72	701	3	5	3	0	0	-1	0	0	0	3.0	
i 1	192.24387074829932	1.5150000000000001	70	701	3	24	4	2	0	-1	2	0	0	4.0	
i 1	192.25540816326532	0.2525	74	701	6	1	15	16	0	1	16	0	0	2.0	
i 1	192.51189795918367	0.2525	74	701	6	1	16	17	0	1	17	0	0	2.0	
i 1	192.51622448979592	1.7675	77	203	5	1	12	17	0	1	17	0	0	2.0	
i 1	192.7582925170068	1.5150000000000001	71	701	5	3	12	8	0	-2	8	0	0	4.0	
i 1	193.23449659863945	1.2625	70	701	3	24	7	2	0	-1	2	0	0	4.0	
i 1	193.24242857142858	1.5150000000000001	69	203	6	5	14	1	0	0	1	0	0	3.0	
i 1	193.2525238095238	2.02	72	701	3	5	10	0	0	-1	0	0	0	3.0	
i 1	193.25540816326532	0.2525	73	701	2	24	1	8	0	-1	8	0	0	4.0	
i 1	193.48377551020408	7.8275	63	701	4	26	1	16	0	1	16	0	0	1.1853860203341497	
i 1	193.48521768707482	1.01	74	701	6	1	6	16	0	1	16	0	0	2.0	
i 1	193.49387074829932	1.5150000000000001	73	701	3	24	5	8	0	-1	8	0	0	4.0	
i 1	193.73233333333334	0.2525	72	1087	6	5	11	0	0	0	0	0	0	3.0	
i 1	193.7669455782313	0.2525	71	701	5	9	3	8	0	-1	8	0	0	3.0	
i 1	194.00612925170068	0.2525	71	701	5	9	9	8	0	-1	8	0	0	3.0	
i 1	194.01045578231293	1.2625	77	1087	4	24	16	16	0	2	16	0	0	5.0	
i 1	194.23233333333334	0.7575000000000001	74	203	5	2	15	8	0	-1	8	0	0	4.0	
i 1	194.2633401360544	0.7575000000000001	71	701	5	9	11	8	0	-1	8	0	0	3.0	
i 1	194.49098639455784	0.505	70	701	3	24	4	2	0	-1	2	0	0	4.0	
i 1	194.50180272108844	0.2525	74	203	5	1	8	17	0	2	17	0	0	2.0	
i 1	194.50180272108844	1.7675	71	701	4	4	16	8	0	-2	8	0	0	4.0	
i 1	194.5082925170068	0.2525	70	1087	3	24	13	2	0	-1	2	0	0	4.0	
i 1	194.74387074829932	0.2525	72	701	3	5	7	1	0	0	1	0	0	3.0	
i 1	195.00468707482995	1.5150000000000001	69	701	3	5	6	0	0	0	0	0	0	3.0	
i 1	195.00540816326532	1.2625	69	203	6	5	5	0	0	0	0	0	0	3.0	
i 1	195.2611768707483	1.2625	74	701	6	1	1	17	0	1	17	0	0	2.0	
i 1	195.4974761904762	0.2525	69	203	6	5	1	1	0	0	1	0	0	3.0	
i 1	195.73449659863945	1.01	74	203	5	2	8	8	0	-1	8	0	0	4.0	
i 1	195.73738095238096	2.02	72	701	3	5	7	0	0	-1	0	0	0	3.0	
i 1	195.99314965986395	0.505	74	701	6	1	14	16	0	1	16	0	0	2.0	
i 1	196.0003605442177	1.2625	77	1087	4	1	8	16	0	1	16	0	0	2.0	
i 1	196.25396598639455	0.505	70	701	3	24	10	2	0	-1	2	0	0	4.0	
i 1	196.49675510204082	0.7575000000000001	74	701	6	1	7	16	0	1	16	0	0	2.0	
i 1	196.50396598639455	1.5150000000000001	71	701	5	3	14	8	0	-2	8	0	0	4.0	
i 1	196.51045578231293	0.2525	71	701	5	9	5	8	0	-1	8	0	0	3.0	
i 1	196.51622448979592	7.8275	63	701	4	26	6	1	0	2	1	0	0	1.1853860203341497	
i 1	196.76261904761904	1.01	73	701	3	24	5	8	0	-1	8	0	0	4.0	
i 1	197.00685034013605	1.5150000000000001	74	701	6	1	13	16	0	1	16	0	0	2.0	
i 1	197.00973469387756	1.7675	72	701	3	5	7	0	0	-1	0	0	0	3.0	
i 1	197.50973469387756	0.2525	71	701	4	4	4	8	0	-2	8	0	0	4.0	
i 1	197.7366598639456	1.7675	74	203	5	2	5	8	0	-1	8	0	0	4.0	
i 1	197.74026530612244	0.2525	74	701	6	1	5	17	0	1	17	0	0	2.0	
i 1	197.7496394557823	1.7675	71	701	5	9	1	8	0	-1	8	0	0	3.0	
i 1	198.00685034013605	1.2625	73	701	3	24	14	8	0	-1	8	0	0	4.0	
i 1	198.2474761904762	0.505	77	701	4	24	8	16	0	2	16	0	0	5.0	
i 1	198.25324489795918	0.505	77	1087	4	24	12	16	0	2	16	0	0	5.0	
i 1	198.5111768707483	0.7575000000000001	72	701	3	5	7	1	0	0	1	0	0	3.0	
i 1	198.73521768707482	1.7675	69	203	6	5	8	0	0	0	0	0	0	3.0	
i 1	198.7417074829932	0.7575000000000001	69	701	3	5	2	0	0	0	0	0	0	3.0	
i 1	198.74675510204082	0.2525	74	701	6	1	10	16	0	1	16	0	0	2.0	
i 1	198.99531292517005	0.2525	70	701	3	24	12	8	0	-1	8	0	0	4.0	
i 1	199.00180272108844	0.505	70	701	3	24	2	2	0	-1	2	0	0	4.0	
i 1	199.48954421768707	1.01	69	701	6	5	8	0	0	0	0	0	0	3.0	
i 1	199.49098639455784	6.565	61	701	3	27	13	16	0	1	16	0	0	1.7780790305012246	
i 1	199.49891836734693	5.05	73	701	3	24	1	8	0	-1	8	0	0	4.0	
i 1	199.4996394557823	1.2625	73	701	3	24	9	8	0	-2	8	0	0	4.0	
i 1	199.98954421768707	1.2625	72	701	3	5	9	0	0	-1	0	0	0	3.0	
i 1	200.2330544217687	2.02	70	701	3	24	12	2	0	-1	2	0	0	4.0	
i 1	200.23738095238096	0.2525	71	701	5	9	15	8	0	-1	8	0	0	3.0	
i 1	200.73233333333334	1.2625	69	203	6	5	16	1	0	0	1	0	0	3.0	
i 1	200.73233333333334	1.2625	72	701	3	5	9	0	0	-1	0	0	0	3.0	
i 1	201.00901360544216	0.7575000000000001	73	1087	3	24	16	8	0	-1	8	0	0	4.0	
i 1	201.24531292517005	0.2525	71	701	4	9	12	8	0	-1	8	0	0	3.0	
i 1	201.2525238095238	1.2625	71	701	5	3	12	8	0	-2	8	0	0	4.0	
i 1	201.50901360544216	1.5150000000000001	72	1087	5	5	11	1	0	0	1	0	0	3.0	
i 1	201.7496394557823	0.2525	77	1087	4	1	1	16	0	1	16	0	0	2.0	
i 1	201.98233333333334	0.505	72	701	3	5	6	0	0	-1	0	0	0	3.0	
i 1	201.9888231292517	1.2625	77	701	4	24	12	16	0	2	16	0	0	5.0	
i 1	201.99603401360545	1.7675	77	1087	4	24	4	16	0	2	16	0	0	5.0	
i 1	202.49675510204082	1.01	71	701	5	9	6	8	0	-1	8	0	0	3.0	
i 1	202.5003605442177	0.505	71	701	5	3	5	8	0	-2	8	0	0	4.0	
i 1	202.50612925170068	0.2525	77	1087	4	1	5	16	0	1	16	0	0	2.0	
i 1	202.50973469387756	3.535	61	701	3	27	13	16	0	1	16	0	0	1.7780790305012246	
i 1	202.74242857142858	1.7675	74	701	4	1	11	17	0	1	17	0	0	2.0	
i 1	202.75540816326532	1.7675	69	701	5	5	6	0	0	0	0	0	0	3.0	
i 1	202.7582925170068	1.7675	69	203	6	5	10	0	0	0	0	0	0	3.0	
i 1	202.99531292517005	2.02	71	701	4	4	14	8	0	-2	8	0	0	4.0	
i 1	203.49242857142858	0.2525	72	1087	5	5	11	1	0	0	1	0	0	3.0	
i 1	203.9830544217687	2.02	70	701	3	24	16	2	0	-1	2	0	0	4.0	
i 1	203.99459183673468	0.7575000000000001	74	701	6	1	4	16	0	1	16	0	0	2.0	
i 1	203.99675510204082	1.01	72	1087	5	5	6	0	0	0	0	0	0	3.0	
i 1	204.00468707482995	0.7575000000000001	77	1087	4	1	1	16	0	1	16	0	0	2.0	
i 1	204.0133401360544	0.2525	71	1087	4	3	14	8	0	-1	8	0	0	4.0	
i 1	204.01766666666666	1.01	72	701	3	5	6	0	0	-1	0	0	0	3.0	
i 1	204.2366598639456	1.7675	77	203	5	1	1	17	0	1	17	0	0	2.0	
i 1	204.25685034013605	1.7675	74	701	4	1	9	16	0	1	16	0	0	2.0	
i 1	204.50540816326532	1.5150000000000001	71	701	4	9	6	8	0	-1	8	0	0	3.0	
i 1	204.5133401360544	1.5150000000000001	69	203	6	5	9	1	0	0	1	0	0	3.0	
i 1	204.7366598639456	0.2525	77	1087	4	24	8	16	0	2	16	0	0	5.0	
i 1	204.99603401360545	0.2525	69	203	6	5	3	0	0	0	0	0	0	3.0	
i 1	205.00180272108844	0.2525	71	701	4	9	4	8	0	-1	8	0	0	3.0	
i 1	205.25324489795918	0.505	77	701	4	24	12	16	0	2	16	0	0	5.0	
i 1	205.2640612244898	0.2525	71	1087	4	3	4	8	0	-1	8	0	0	4.0	
i 1	205.2640612244898	0.2525	72	1087	5	5	7	1	0	0	1	0	0	3.0	
i 1	205.73233333333334	0.2525	74	203	5	2	3	8	0	-1	8	0	0	4.0	
i 1	205.7640612244898	0.2525	74	203	5	1	12	17	0	2	17	0	0	2.0	
i 1	205.98521768707482	3.535	70	379	3	24	14	2	0	-2	2	0	0	4.0	
i 1	205.99026530612244	1.7675	74	695	5	1	7	17	0	1	17	0	0	2.0	
i 1	205.99026530612244	0.505	72	379	6	5	4	1	0	0	1	0	0	3.0	
i 1	205.99314965986395	0.7575000000000001	77	695	5	1	12	17	0	2	17	0	0	2.0	
i 1	205.99891836734693	2.02	72	379	3	5	14	1	0	-1	1	0	0	3.0	
i 1	206.00108163265307	0.505	69	695	6	5	6	0	0	-1	0	0	0	3.0	
i 1	206.00180272108844	4.2925	61	379	3	27	7	16	0	1	16	0	0	1.7780790305012246	
i 1	206.00324489795918	1.2625	74	379	5	3	16	8	0	-1	8	0	0	4.0	
i 1	206.00324489795918	1.2625	63	379	3	27	8	1	0	2	1	0	0	1.7780790305012246	
i 1	206.00685034013605	0.7575000000000001	74	695	5	2	3	8	0	-1	8	0	0	4.0	
i 1	206.00901360544216	1.2625	74	695	5	2	16	2	0	-1	2	0	0	4.0	
i 1	206.00973469387756	1.01	74	1081	4	9	13	2	0	-1	2	0	0	3.0	
i 1	206.00973469387756	0.505	72	1081	5	5	10	1	0	-1	1	0	0	3.0	
i 1	206.01766666666666	2.2725	70	1081	3	24	12	2	0	-2	2	0	0	4.0	
i 1	206.2503605442177	0.2525	72	379	6	5	9	0	0	0	0	0	0	3.0	
i 1	206.50396598639455	1.7675	71	695	5	3	6	2	0	-1	2	0	0	4.0	
i 1	206.51189795918367	1.5150000000000001	69	695	6	5	15	0	0	-1	0	0	0	3.0	
i 1	206.75757142857142	0.2525	74	695	4	24	16	17	0	1	17	0	0	5.0	
i 1	206.98449659863945	0.2525	72	379	6	5	5	0	0	0	0	0	0	3.0	
i 1	206.98810204081633	1.7675	74	379	4	24	14	17	0	2	17	0	0	5.0	
i 1	207.23449659863945	0.2525	74	695	5	2	3	8	0	-1	8	0	0	4.0	
i 1	207.23521768707482	15.4025	63	379	1	27	5	1	0	252	1	307	0	1.7780790305012246	
i 1	207.24675510204082	2.02	72	1081	5	5	11	0	0	-1	0	0	0	3.0	
i 1	207.25468707482995	1.01	74	379	4	3	15	8	0	-1	8	0	0	4.0	
i 1	207.50396598639455	1.5150000000000001	71	1081	4	9	8	8	0	-1	8	0	0	3.0	
i 1	207.76261904761904	2.02	77	695	6	1	9	17	0	2	17	0	0	2.0	
i 1	207.7633401360544	1.01	74	695	5	2	16	8	0	-1	8	0	0	4.0	
i 1	208.23738095238096	2.2725	71	695	4	4	5	8	0	-2	8	0	0	4.0	
i 1	208.25685034013605	2.02	74	379	4	4	14	2	0	-2	2	0	0	4.0	
i 1	208.49242857142858	1.2625	69	695	6	5	14	1	0	-1	1	0	0	3.0	
i 1	208.73738095238096	0.2525	74	695	5	1	12	16	0	1	16	0	0	2.0	
i 1	208.7611768707483	1.01	72	379	5	5	11	0	0	0	0	0	0	3.0	
i 1	208.98954421768707	0.2525	70	695	4	24	3	8	0	-2	8	0	0	4.0	
i 1	209.0169455782313	0.2525	74	379	4	24	10	17	0	2	17	0	0	5.0	
i 1	209.23449659863945	2.02	72	1081	5	5	10	1	0	-1	1	0	0	3.0	
i 1	209.25180272108844	1.01	72	695	6	5	14	0	0	0	0	0	0	3.0	
i 1	209.26766666666666	1.2625	70	379	3	24	2	2	0	-1	2	0	0	4.0	
i 1	209.49891836734693	2.02	74	1081	4	1	10	16	0	2	16	0	0	2.0	
i 1	209.51478231292518	0.7575000000000001	74	695	5	1	6	17	0	1	17	0	0	2.0	
i 1	209.7359387755102	2.525	74	1081	4	9	13	2	0	-1	2	0	0	3.0	
i 1	209.7359387755102	0.2525	69	695	4	5	15	0	0	-1	0	0	0	3.0	
i 1	209.76478231292518	0.505	74	695	5	2	3	2	0	-1	2	0	0	4.0	
i 1	209.76550340136055	2.2725	70	379	3	24	6	2	0	-2	2	0	0	4.0	
i 1	209.98954421768707	0.2525	72	1081	5	5	6	0	0	-1	0	0	0	3.0	
i 1	210.23449659863945	1.5150000000000001	74	695	6	2	12	2	0	-1	2	0	0	4.0	
i 1	210.23738095238096	1.01	72	695	4	5	10	0	0	0	0	0	0	3.0	
i 1	210.24675510204082	1.2625	74	695	6	1	14	17	0	1	17	0	0	2.0	
i 1	210.24891836734693	12.3725	61	379	1	27	7	16	0	252	16	307	0	1.7780790305012246	
i 1	210.4830544217687	0.2525	74	379	4	3	15	8	0	-1	8	0	0	4.0	
i 1	210.4859387755102	0.2525	74	695	5	1	7	16	0	1	16	0	0	2.0	
i 1	210.49098639455784	0.505	70	695	4	24	12	8	0	-2	8	0	0	4.0	
i 1	210.50108163265307	0.2525	69	695	6	5	16	1	0	-1	1	0	0	3.0	
i 1	210.7633401360544	0.2525	77	1081	4	1	4	17	0	1	17	0	0	2.0	
i 1	210.76766666666666	0.2525	74	379	4	4	10	2	0	-2	2	0	0	4.0	
i 1	210.99459183673468	3.0300000000000002	74	695	4	24	2	17	0	1	17	0	0	5.0	
i 1	210.99459183673468	0.2525	71	695	4	4	7	8	0	-2	8	0	0	4.0	
i 1	210.99891836734693	2.7775	74	379	4	24	11	17	0	2	17	0	0	5.0	
i 1	211.00468707482995	1.5150000000000001	69	695	4	5	12	0	0	-1	0	0	0	3.0	
i 1	211.0140612244898	1.7675	72	1081	5	5	6	0	0	-1	0	0	0	3.0	
i 1	211.2474761904762	2.02	71	695	5	3	13	2	0	-1	2	0	0	4.0	
i 1	211.50901360544216	0.2525	74	695	5	1	16	16	0	1	16	0	0	2.0	
i 1	211.75757142857142	0.2525	73	695	4	24	4	2	0	-1	2	0	0	4.0	
i 1	211.7633401360544	0.505	74	379	4	1	6	17	0	1	17	0	0	2.0	
i 1	211.98810204081633	1.2625	70	379	3	24	14	2	0	-2	2	0	0	4.0	
i 1	211.99531292517005	1.2625	69	695	6	5	10	1	0	-1	1	0	0	3.0	
i 1	212.26478231292518	0.505	71	695	4	4	2	8	0	-2	8	0	0	4.0	
i 1	212.48810204081633	0.505	74	1081	4	1	3	16	0	2	16	0	0	2.0	
i 1	212.74026530612244	0.2525	72	695	4	5	11	0	0	0	0	0	0	3.0	
i 1	212.76478231292518	0.505	74	695	5	2	8	8	0	-1	8	0	0	4.0	
i 1	212.99459183673468	1.7675	74	379	4	1	9	17	0	1	17	0	0	2.0	
i 1	213.0082925170068	1.7675	71	695	4	4	12	8	0	-2	8	0	0	4.0	
i 1	213.2366598639456	0.2525	74	695	6	2	5	8	0	-1	8	0	0	4.0	
i 1	213.2417074829932	1.7675	72	695	4	5	8	0	0	0	0	0	0	3.0	
i 1	213.24603401360545	1.2625	74	695	6	1	14	16	0	1	16	0	0	2.0	
i 1	213.24675510204082	1.7675	72	1081	5	5	3	1	0	-1	1	0	0	3.0	
i 1	213.26766666666666	0.505	69	695	4	5	10	1	0	-1	1	0	0	3.0	
i 1	213.5025238095238	0.2525	71	695	5	3	12	2	0	-1	2	0	0	4.0	
i 1	213.73954421768707	2.02	70	1081	3	24	13	2	0	-2	2	0	0	4.0	
i 1	213.74242857142858	0.2525	70	695	4	24	11	2	0	-1	2	0	0	4.0	
i 1	213.9859387755102	0.2525	74	695	6	2	1	8	0	-1	8	0	0	4.0	
i 1	214.00468707482995	1.7675	74	695	6	1	15	17	0	1	17	0	0	2.0	
i 1	214.00612925170068	0.2525	72	1081	5	5	6	0	0	-1	0	0	0	3.0	
i 1	214.2496394557823	1.01	74	1081	4	9	15	2	0	-1	2	0	0	3.0	
i 1	214.25685034013605	1.01	74	695	6	2	13	2	0	-1	2	0	0	4.0	
i 1	214.25757142857142	0.2525	69	695	4	5	12	1	0	-1	1	0	0	3.0	
i 1	214.48738095238096	0.2525	73	695	4	24	7	8	0	-1	8	0	0	4.0	
i 1	214.50973469387756	1.01	72	379	5	5	2	1	0	-1	1	0	0	3.0	
i 1	214.51045578231293	1.01	69	695	6	5	7	0	0	-1	0	0	0	3.0	
i 1	214.74026530612244	1.2625	70	379	3	24	11	8	0	-2	8	0	0	4.0	
i 1	214.74387074829932	0.2525	74	379	4	24	13	17	0	2	17	0	0	5.0	
i 1	214.76045578231293	1.5150000000000001	71	695	5	3	9	2	0	-1	2	0	0	4.0	
i 1	214.9830544217687	2.02	72	1081	5	5	1	0	0	-1	0	0	0	3.0	
i 1	215.24242857142858	0.7575000000000001	74	379	4	24	14	17	0	2	17	0	0	5.0	
i 1	215.2669455782313	0.2525	74	695	6	2	3	8	0	-1	8	0	0	4.0	
i 1	215.50468707482995	2.02	77	695	6	1	7	17	0	2	17	0	0	2.0	
i 1	215.51550340136055	0.2525	72	1081	5	5	11	1	0	-1	1	0	0	3.0	
i 1	215.76766666666666	0.505	72	695	4	5	3	0	0	0	0	0	0	3.0	
i 1	215.98521768707482	0.505	74	1081	4	1	15	16	0	2	16	0	0	2.0	
i 1	215.9866598639456	0.2525	70	695	4	24	11	8	0	-2	8	0	0	4.0	
i 1	216.0003605442177	0.2525	74	695	6	2	8	2	0	-1	2	0	0	4.0	
i 1	216.00468707482995	1.7675	70	1081	3	24	2	2	0	-2	2	0	0	4.0	
i 1	216.00685034013605	1.01	70	379	3	24	11	2	0	-2	2	0	0	4.0	
i 1	216.24603401360545	0.2525	69	695	4	5	10	0	0	-1	0	0	0	3.0	
i 1	216.4866598639456	0.2525	74	695	6	1	10	16	0	1	16	0	0	2.0	
i 1	216.50324489795918	0.7575000000000001	72	379	5	5	5	0	0	0	0	0	0	3.0	
i 1	216.5133401360544	1.01	69	695	4	5	6	1	0	-1	1	0	0	3.0	
i 1	216.73449659863945	0.2525	74	695	6	1	3	17	0	1	17	0	0	2.0	
i 1	216.7633401360544	0.7575000000000001	73	379	3	24	1	8	0	-2	8	0	0	4.0	
i 1	216.9888231292517	1.7675	74	695	6	1	16	16	0	1	16	0	0	2.0	
i 1	217.00180272108844	0.2525	74	695	6	2	3	2	0	-1	2	0	0	4.0	
i 1	217.00612925170068	2.02	74	379	4	1	9	17	0	1	17	0	0	2.0	
i 1	217.4830544217687	0.2525	74	379	4	3	13	8	0	-1	8	0	0	4.0	
i 1	217.73377551020408	2.02	74	379	4	4	6	2	0	-2	2	0	0	4.0	
i 1	217.76622448979592	1.5150000000000001	71	695	4	4	9	8	0	-2	8	0	0	4.0	
i 1	217.98521768707482	0.2525	73	379	3	24	1	2	0	-2	2	0	0	4.0	
i 1	218.00757142857142	0.2525	74	695	4	24	11	17	0	1	17	0	0	5.0	
i 1	218.23233333333334	0.2525	70	695	4	24	5	8	0	-2	8	0	0	4.0	
i 1	218.24819727891156	1.5150000000000001	74	695	6	1	5	17	0	1	17	0	0	2.0	
i 1	218.24891836734693	1.5150000000000001	74	1081	4	1	14	16	0	2	16	0	0	2.0	
i 1	218.25973469387756	1.01	70	1081	3	24	15	2	0	-2	2	0	0	4.0	
i 1	218.49387074829932	0.2525	74	695	6	2	8	2	0	-1	2	0	0	4.0	
i 1	218.5111768707483	0.7575000000000001	70	379	3	24	10	8	0	-2	8	0	0	4.0	
i 1	218.75973469387756	0.2525	74	1081	4	9	7	2	0	-1	2	0	0	3.0	
i 1	218.99675510204082	3.0300000000000002	74	379	4	24	10	17	0	2	17	0	0	5.0	
i 1	219.00901360544216	1.01	74	695	6	2	16	2	0	-1	2	0	0	4.0	
i 1	219.01261904761904	0.2525	72	1081	5	5	14	0	0	-1	0	0	0	3.0	
i 1	219.23233333333334	3.2825	70	379	3	24	15	2	0	-2	2	0	0	6.0155750592515815	
i 1	219.2388231292517	2.7775	74	695	4	24	4	17	0	1	17	0	0	5.0	
i 1	219.24098639455784	1.01	70	1081	3	24	5	2	0	-2	2	0	0	6.0155750592515815	
i 1	219.25108163265307	0.7575000000000001	74	1081	4	9	13	2	0	-1	2	0	0	3.0	
i 1	219.2525238095238	0.7575000000000001	70	379	2	24	10	8	0	-2	8	0	0	6.0155750592515815	
i 1	219.25612925170068	0.7575000000000001	73	1081	2	20	4	8	0	-1	8	0	0	2.0155750592515815	
i 1	219.51045578231293	1.7675	74	379	4	3	14	8	0	-1	8	0	0	4.0	
i 1	219.7496394557823	0.2525	70	379	2	20	15	8	0	-2	8	0	0	2.0155750592515815	
i 1	219.75468707482995	0.7575000000000001	70	1081	3	20	7	2	0	-1	2	0	0	2.0155750592515815	
i 1	219.75973469387756	0.2525	77	1081	5	1	16	17	0	1	17	0	0	2.0	
i 1	219.76189795918367	0.505	69	695	4	5	9	0	0	-1	0	0	0	3.0	
i 1	220.0003605442177	0.2525	74	1081	4	1	5	16	0	2	16	0	0	2.0	
i 1	220.0082925170068	2.525	70	379	3	20	11	8	0	-2	8	0	0	2.0155750592515815	
i 1	220.01189795918367	0.2525	73	695	3	20	3	8	0	-1	8	0	0	2.0155750592515815	
i 1	220.01550340136055	0.2525	74	695	6	2	2	8	0	-1	8	0	0	4.0	
i 1	220.01622448979592	0.2525	73	695	3	24	2	2	0	-2	2	0	0	6.0155750592515815	
i 1	220.24098639455784	0.2525	74	379	4	4	3	2	0	-2	2	0	0	4.0	
i 1	220.24675510204082	0.2525	77	1081	5	1	14	17	0	1	17	0	0	2.0	
i 1	220.2503605442177	1.01	72	379	5	5	15	0	0	0	0	0	0	3.0	
i 1	220.25324489795918	1.01	73	1081	2	20	4	2	0	-2	2	0	0	2.0155750592515815	
i 1	220.25757142857142	1.01	70	379	2	20	14	2	0	-2	2	0	0	2.0155750592515815	
i 1	220.2582925170068	1.01	69	695	4	5	8	1	0	-1	1	0	0	3.0	
i 1	220.48810204081633	1.5150000000000001	74	695	6	2	5	8	0	-1	8	0	0	4.0	
i 1	220.49675510204082	0.505	74	379	4	1	2	17	0	1	17	0	0	2.0	
i 1	220.73233333333334	1.7675	72	695	4	5	6	0	0	0	0	0	0	3.0	
i 1	221.00180272108844	1.01	74	695	6	1	4	16	0	1	16	0	0	2.0	
i 1	221.00540816326532	0.2525	70	379	2	24	4	2	0	-2	2	0	0	6.0155750592515815	
i 1	221.01045578231293	1.5150000000000001	70	1081	3	20	16	2	0	-1	2	0	0	2.0155750592515815	
i 1	221.23521768707482	1.01	74	379	4	1	16	17	0	1	17	0	0	2.0	
i 1	221.23810204081633	0.2525	70	695	3	20	14	8	0	-2	8	0	0	2.0155750592515815	
i 1	221.24675510204082	1.5150000000000001	71	695	4	4	16	8	0	-2	8	0	0	4.0	
i 1	221.24675510204082	0.505	69	695	4	5	4	0	0	-1	0	0	0	3.0	
i 1	221.25540816326532	0.2525	73	695	3	20	15	2	0	-1	2	0	0	2.0155750592515815	
i 1	221.25685034013605	0.2525	70	695	3	24	14	8	0	-1	8	0	0	6.0155750592515815	
i 1	221.25973469387756	1.2625	74	379	4	4	9	2	0	-2	2	0	0	4.0	
i 1	221.26189795918367	1.2625	74	695	6	1	7	17	0	1	17	0	0	2.0	
i 1	221.48954421768707	0.7575000000000001	73	1081	2	20	11	2	0	-2	2	0	0	2.0155750592515815	
i 1	221.4917074829932	1.01	70	379	2	20	4	8	0	-2	8	0	0	2.0155750592515815	
i 1	221.75108163265307	0.2525	72	379	5	5	5	1	0	-1	1	0	0	3.0	
i 1	221.9917074829932	1.2625	71	695	5	3	14	2	0	-1	2	0	0	4.0	
i 1	222.23521768707482	0.2525	74	1081	5	1	14	16	0	2	16	0	0	2.0	
i 1	222.24603401360545	0.2525	77	695	6	1	6	17	0	2	17	0	0	2.0	
i 1	222.4830544217687	0.2525	70	695	3	20	1	8	0	-2	8	0	0	2.0155750592515815	
i 1	222.49314965986395	0.7575000000000001	69	695	4	5	2	1	0	-1	1	0	0	3.0	
i 1	222.49531292517005	0.2525	72	899	4	5	1	1	0	0	1	0	0	3.0	
i 1	222.49531292517005	1.2625	73	197	3	20	5	8	0	-1	8	0	0	2.0155750592515815	
i 1	222.5025238095238	1.01	70	197	4	20	16	8	0	-2	8	0	0	2.0155750592515815	
i 1	222.50396598639455	0.2525	70	695	3	24	12	8	0	-1	8	0	0	6.0155750592515815	
i 1	222.5082925170068	0.505	72	899	4	5	1	1	0	0	1	0	0	3.0	
i 1	222.50901360544216	0.2525	70	899	3	20	5	8	0	-1	8	0	0	2.0155750592515815	
i 1	222.51189795918367	1.01	74	899	6	1	10	16	0	1	16	0	0	2.0	
i 1	222.51261904761904	1.5150000000000001	70	197	3	24	8	8	0	-1	8	0	0	6.0155750592515815	
i 1	222.73449659863945	0.2525	74	197	4	1	5	17	0	2	17	0	0	2.0	
i 1	222.73449659863945	0.2525	74	899	6	2	2	2	0	-1	2	0	0	4.0	
i 1	222.74531292517005	0.2525	70	197	2	24	12	8	0	-2	8	0	0	6.0155750592515815	
i 1	222.76766666666666	0.2525	73	197	2	20	2	8	0	-2	8	0	0	2.0155750592515815	
i 1	222.9859387755102	0.2525	73	899	3	20	13	8	0	-2	8	0	0	2.0155750592515815	
i 1	223.00540816326532	0.2525	70	695	3	24	8	2	0	-2	2	0	0	6.0155750592515815	
i 1	223.0133401360544	0.2525	73	695	3	20	10	2	0	-2	2	0	0	2.0155750592515815	
i 1	223.01550340136055	0.2525	69	695	4	5	16	0	0	-1	0	0	0	3.0	
i 1	223.23449659863945	0.505	70	197	2	24	2	8	0	-1	8	0	0	6.0155750592515815	
i 1	223.2417074829932	0.505	74	583	4	4	13	8	0	-2	8	0	0	4.0	
i 1	223.51261904761904	1.5150000000000001	74	197	6	1	2	16	0	1	16	0	0	2.0	
i 1	223.73810204081633	2.02	74	1081	6	2	7	2	0	-2	2	0	0	4.0	
i 1	223.73954421768707	0.7575000000000001	70	695	2	20	5	8	0	-2	8	0	0	2.0155750592515815	
i 1	223.74242857142858	1.2625	74	695	4	24	10	16	0	2	16	0	0	5.0	
i 1	223.74314965986395	10.605	61	695	1	27	6	1	0	252	1	307	0	1.7780790305012246	
i 1	223.75757142857142	1.5150000000000001	69	695	4	5	2	0	0	-1	0	0	0	3.0	
i 1	223.75973469387756	0.2525	69	695	4	5	12	0	0	-1	0	0	0	3.0	
i 1	223.7669455782313	4.04	70	695	3	20	6	2	0	-1	2	0	0	2.0155750592515815	
i 1	223.76766666666666	0.7575000000000001	70	695	2	24	11	8	0	-2	8	0	0	6.0155750592515815	
i 1	224.00468707482995	1.2625	69	695	5	5	9	1	0	-1	1	0	0	3.0	
i 1	224.23449659863945	1.01	70	197	4	20	11	8	0	-2	8	0	0	2.0155750592515815	
i 1	224.24675510204082	0.505	71	695	4	4	4	2	0	-1	2	0	0	4.0	
i 1	224.25108163265307	0.2525	70	197	3	20	2	2	0	-2	2	0	0	2.0155750592515815	
i 1	224.48449659863945	0.2525	70	695	3	24	6	8	0	-2	8	0	0	6.0155750592515815	
i 1	224.48738095238096	0.2525	70	695	3	20	4	8	0	-2	8	0	0	2.0155750592515815	
i 1	224.5025238095238	1.5150000000000001	72	1081	4	5	12	1	0	-1	1	0	0	3.0	
i 1	224.51045578231293	0.2525	70	1081	3	20	15	8	0	-2	8	0	0	2.0155750592515815	
i 1	224.7496394557823	1.2625	74	197	6	9	16	8	0	-1	8	0	0	3.0	
i 1	224.75108163265307	2.2725	70	695	2	24	3	8	0	-2	8	0	0	6.0155750592515815	
i 1	224.76261904761904	0.2525	70	695	2	20	3	8	0	-2	8	0	0	2.0155750592515815	
i 1	225.00901360544216	1.01	71	695	4	4	12	2	0	-1	2	0	0	4.0	
i 1	225.24314965986395	1.7675	70	197	3	20	4	8	0	-2	8	0	0	2.0155750592515815	
i 1	225.25468707482995	0.505	69	695	3	5	3	1	0	-1	1	0	0	3.0	
i 1	225.26045578231293	2.02	69	695	4	5	1	0	0	-1	0	0	0	3.0	
i 1	225.49675510204082	2.7775	70	695	3	24	11	2	0	-2	2	0	0	6.0155750592515815	
i 1	225.4974761904762	2.2725	71	1081	6	2	3	2	0	-2	2	0	0	4.0	
i 1	225.49891836734693	2.2725	71	197	6	9	14	8	0	-1	8	0	0	3.0	
i 1	225.51261904761904	1.5150000000000001	70	695	2	20	13	8	0	-2	8	0	0	2.0155750592515815	
i 1	225.7366598639456	2.02	74	197	6	1	9	16	0	1	16	0	0	2.0	
i 1	225.74675510204082	0.2525	69	695	4	5	8	0	0	-1	0	0	0	3.0	
i 1	226.00901360544216	0.2525	71	695	5	3	15	2	0	-1	2	0	0	4.0	
i 1	226.48738095238096	0.505	77	695	6	1	13	16	0	1	16	0	0	2.0	
i 1	226.50324489795918	1.7675	69	695	5	5	6	1	0	0	1	0	0	3.0	
i 1	226.73738095238096	1.01	69	1081	4	5	15	0	0	0	0	0	0	3.0	
i 1	226.74314965986395	1.2625	72	197	4	5	2	0	0	-1	0	0	0	3.0	
i 1	226.99242857142858	0.7575000000000001	73	1081	3	20	7	8	0	-1	8	0	0	2.0155750592515815	
i 1	226.99891836734693	2.02	74	695	5	1	5	16	0	2	16	0	0	2.0	
i 1	227.0111768707483	0.7575000000000001	70	695	3	24	10	8	0	-2	8	0	0	6.0155750592515815	
i 1	227.01766666666666	1.2625	77	1081	6	1	15	17	0	1	17	0	0	2.0	
i 1	227.24603401360545	4.04	70	197	3	20	13	8	0	-2	8	0	0	2.0155750592515815	
i 1	227.2503605442177	0.7575000000000001	70	197	3	24	16	8	0	-1	8	0	0	6.0155750592515815	
i 1	227.73233333333334	0.7575000000000001	70	695	2	20	14	8	0	-2	8	0	0	2.0155750592515815	
i 1	227.74098639455784	0.7575000000000001	70	695	2	24	6	8	0	-2	8	0	0	6.0155750592515815	
i 1	227.7496394557823	0.505	74	1081	4	1	7	17	0	1	17	0	0	2.0	
i 1	227.7503605442177	0.7575000000000001	70	197	3	20	12	8	0	-2	8	0	0	2.0155750592515815	
i 1	228.0082925170068	3.2825	70	695	3	20	2	2	0	-1	2	0	0	2.0155750592515815	
i 1	228.2525238095238	1.7675	70	695	2	24	7	2	0	-2	2	0	0	6.0155750592515815	
i 1	228.26189795918367	1.7675	70	197	3	24	3	8	0	-1	8	0	0	6.0155750592515815	
i 1	228.2640612244898	2.02	77	695	6	1	6	16	0	1	16	0	0	2.0	
i 1	228.5025238095238	0.2525	70	695	3	20	13	8	0	-2	8	0	0	2.0155750592515815	
i 1	228.51261904761904	0.2525	70	695	3	24	2	8	0	-2	8	0	0	6.0155750592515815	
i 1	228.5133401360544	2.2725	74	695	5	3	13	2	0	-2	2	0	0	4.0	
i 1	228.99387074829932	0.2525	74	197	6	1	5	17	0	2	17	0	0	2.0	
i 1	228.99459183673468	0.2525	74	1081	4	1	4	17	0	1	17	0	0	2.0	
i 1	229.0133401360544	1.7675	69	695	4	5	4	0	0	-1	0	0	0	3.0	
i 1	229.2525238095238	1.7675	74	695	5	1	12	16	0	2	16	0	0	2.0	
i 1	229.49531292517005	0.2525	69	695	3	5	8	1	0	0	1	0	0	3.0	
i 1	229.5111768707483	0.505	71	1081	6	2	15	2	0	-2	2	0	0	4.0	
i 1	229.75180272108844	0.2525	70	695	2	20	6	8	0	-2	8	0	0	2.0155750592515815	
i 1	229.75540816326532	1.7675	72	1081	4	5	16	1	0	-1	1	0	0	3.0	
i 1	229.76189795918367	1.2625	71	695	4	4	9	2	0	-1	2	0	0	4.0	
i 1	229.76261904761904	1.5150000000000001	70	695	2	24	13	8	0	-2	8	0	0	6.0155750592515815	
i 1	229.76550340136055	1.5150000000000001	73	197	3	20	10	8	0	-1	8	0	0	2.0155750592515815	
i 1	230.01189795918367	1.2625	69	695	3	5	12	1	0	-1	1	0	0	3.0	
i 1	230.0169455782313	1.5150000000000001	74	197	6	9	16	8	0	-1	8	0	0	3.0	
i 1	230.2359387755102	2.02	71	197	6	9	9	8	0	-1	8	0	0	3.0	
i 1	230.49531292517005	2.525	69	695	3	5	10	1	0	0	1	0	0	3.0	
i 1	230.49603401360545	2.525	69	695	4	5	1	0	0	-1	0	0	0	3.0	
i 1	230.98449659863945	0.2525	70	695	2	24	2	2	0	-2	2	0	0	6.0155750592515815	
i 1	231.23954421768707	9.8475	70	197	3	20	12	8	0	-2	8	0	0	4.087976833828202	
i 1	231.24242857142858	0.2525	70	695	2	24	11	8	0	-2	8	0	0	8.087976833828202	
i 1	231.25180272108844	0.2525	73	197	3	20	7	8	0	-1	8	0	0	4.087976833828202	
i 1	231.25685034013605	2.7775	77	695	4	24	2	16	0	1	16	0	0	5.0	
i 1	231.2582925170068	0.2525	71	695	4	4	16	2	0	-1	2	0	0	4.0	
i 1	231.2582925170068	0.2525	69	197	4	5	1	0	0	-1	0	0	0	3.0	
i 1	231.48810204081633	0.505	70	695	3	24	13	8	0	-2	8	0	0	8.087976833828202	
i 1	231.49242857142858	2.7775	74	695	5	3	4	2	0	-2	2	0	0	4.0	
i 1	231.49387074829932	0.2525	69	695	4	5	2	0	0	-1	0	0	0	3.0	
i 1	231.49819727891156	2.525	77	695	4	1	8	16	0	1	16	0	0	2.0	
i 1	231.50180272108844	1.7675	69	695	3	5	8	1	0	-1	1	0	0	3.0	
i 1	231.51189795918367	2.7775	74	1081	6	2	8	2	0	-2	2	0	0	4.0	
i 1	231.5140612244898	0.505	70	695	3	20	4	8	0	-2	8	0	0	4.087976833828202	
i 1	231.9830544217687	2.2725	69	197	4	5	16	0	0	-1	0	0	0	3.0	
i 1	231.9974761904762	1.5150000000000001	70	695	2	24	15	8	0	-2	8	0	0	8.087976833828202	
i 1	232.00685034013605	1.5150000000000001	73	197	3	20	7	8	0	-2	8	0	0	4.087976833828202	
i 1	232.0133401360544	0.2525	70	695	2	20	15	8	0	-2	8	0	0	4.087976833828202	
i 1	232.24026530612244	0.505	74	695	4	4	6	8	0	-2	8	0	0	4.0	
i 1	232.24314965986395	1.01	72	1081	4	5	13	1	0	-1	1	0	0	3.0	
i 1	232.25612925170068	3.2825	70	695	1	24	5	2	0	248	2	308	0	8.087976833828202	
i 1	232.48954421768707	0.2525	77	1081	4	1	14	17	0	1	17	0	0	2.0	
i 1	233.00612925170068	0.2525	74	695	4	4	16	8	0	-2	8	0	0	4.0	
i 1	233.23449659863945	1.7675	72	197	4	5	12	0	0	-1	0	0	0	3.0	
i 1	233.24242857142858	2.02	69	1081	4	5	7	0	0	0	0	0	0	3.0	
i 1	233.24531292517005	0.2525	70	695	2	20	5	8	0	-2	8	0	0	4.087976833828202	
i 1	233.2633401360544	1.01	71	695	4	4	7	2	0	-1	2	0	0	4.0	
i 1	233.50108163265307	0.2525	70	695	3	20	8	8	0	-2	8	0	0	4.087976833828202	
i 1	233.5025238095238	0.2525	70	695	3	24	16	8	0	-2	8	0	0	8.087976833828202	
i 1	233.74026530612244	0.505	70	197	3	20	12	8	0	-2	8	0	0	4.087976833828202	
i 1	233.7669455782313	0.505	70	695	2	20	7	8	0	-2	8	0	0	4.087976833828202	
i 1	234.24026530612244	0.2525	71	1081	6	2	5	2	0	-2	2	0	0	9.003796959404667	
i 1	234.24387074829932	0.2525	74	1081	6	2	2	2	0	-2	2	0	0	9.003796959404667	
i 1	234.24675510204082	1.2625	71	695	4	4	7	2	0	-1	2	0	0	9.003796959404667	
i 1	234.2474761904762	4.545	74	695	5	1	2	16	0	2	16	0	0	9.0	
i 1	234.24819727891156	2.2725	69	695	3	5	10	1	0	0	1	0	0	3.0	
i 1	234.25396598639455	1.7675	70	197	2	20	11	8	0	-2	8	0	0	4.087976833828202	
i 1	234.2582925170068	1.2625	74	197	6	9	14	8	0	-1	8	0	0	8.003796959404667	
i 1	234.50180272108844	2.02	69	695	4	5	8	0	0	-1	0	0	0	3.0	
i 1	234.50396598639455	0.505	74	695	4	4	14	8	0	-2	8	0	0	9.003796959404667	
i 1	234.50685034013605	0.2525	74	695	5	3	10	2	0	-2	2	0	0	9.003796959404667	
i 1	234.51766666666666	1.5150000000000001	70	197	2	20	11	8	0	-2	8	0	0	4.087976833828202	
i 1	234.75108163265307	2.525	71	1081	6	2	9	2	0	-2	2	0	0	9.003796959404667	
i 1	235.25324489795918	0.2525	72	197	4	5	9	0	0	-1	0	0	0	3.0	
i 1	235.48954421768707	0.2525	74	1081	6	2	16	2	0	-2	2	0	0	9.003796959404667	
i 1	235.4917074829932	4.7975	69	695	3	5	13	1	0	-1	1	0	0	3.0	
i 1	235.49242857142858	0.2525	74	695	4	4	12	8	0	-2	8	0	0	9.003796959404667	
i 1	235.50540816326532	2.02	70	695	2	24	7	2	0	-2	2	0	0	8.087976833828202	
i 1	235.74891836734693	0.505	74	695	5	3	2	2	0	-2	2	0	0	9.003796959404667	
i 1	235.98521768707482	2.525	69	197	4	5	12	0	0	-1	0	0	0	3.0	
i 1	235.98954421768707	2.2725	77	695	4	24	9	16	0	1	16	0	0	12.0	
i 1	235.99314965986395	1.5150000000000001	71	695	5	3	4	2	0	-1	2	0	0	9.003796959404667	
i 1	236.24387074829932	3.2825	73	197	2	20	5	8	0	-2	8	0	0	4.087976833828202	
i 1	236.2669455782313	0.2525	70	197	2	20	11	2	0	-1	2	0	0	4.087976833828202	
i 1	236.48449659863945	2.2725	74	1081	6	2	13	2	0	-2	2	0	0	9.003796959404667	
i 1	236.4974761904762	1.01	70	197	1	24	7	8	0	252	8	307	0	8.087976833828202	
i 1	236.49891836734693	2.2725	74	695	5	3	4	2	0	-2	2	0	0	9.003796959404667	
i 1	237.00180272108844	0.2525	69	695	3	5	15	1	0	0	1	0	0	3.0	
i 1	237.23521768707482	0.2525	72	197	4	5	11	0	0	-1	0	0	0	3.0	
i 1	237.48233333333334	1.5150000000000001	70	695	1	24	12	2	0	252	2	307	0	8.087976833828202	
i 1	237.49819727891156	2.7775	72	1081	4	5	12	1	0	-1	1	0	0	3.0	
i 1	237.50612925170068	2.02	70	197	2	20	7	2	0	-1	2	0	0	4.087976833828202	
i 1	237.7330544217687	2.02	69	695	3	5	10	1	0	0	1	0	0	3.0	
i 1	237.74314965986395	2.525	74	197	4	1	9	16	0	1	16	0	0	9.0	
i 1	237.7582925170068	2.02	69	695	4	5	13	0	0	-1	0	0	0	3.0	
i 1	237.9859387755102	1.2625	71	695	4	4	15	2	0	-1	2	0	0	9.003796959404667	
i 1	238.23738095238096	2.2725	71	1081	6	2	8	2	0	-2	2	0	0	9.003796959404667	
i 1	238.4866598639456	1.7675	74	197	6	1	5	17	0	2	17	0	0	9.0	
i 1	238.99675510204082	1.5150000000000001	77	1081	4	1	12	17	0	1	17	0	0	9.0	
i 1	239.0082925170068	1.5150000000000001	70	695	2	24	6	2	0	-2	2	0	0	8.087976833828202	
i 1	239.2474761904762	1.5150000000000001	69	197	4	5	4	0	0	-1	0	0	0	3.0	
i 1	239.2496394557823	0.2525	71	695	5	3	12	2	0	-1	2	0	0	9.003796959404667	
i 1	239.2582925170068	1.2625	74	1081	6	2	3	2	0	-2	2	0	0	9.003796959404667	
i 1	239.49026530612244	0.2525	73	1081	2	20	3	2	0	-1	2	0	0	4.087976833828202	
i 1	239.49242857142858	0.2525	70	695	3	24	15	8	0	-2	8	0	0	8.087976833828202	
i 1	239.74531292517005	1.2625	72	197	4	5	3	0	0	-1	0	0	0	3.0	
i 1	239.76261904761904	0.2525	70	197	2	20	16	2	0	-2	2	0	0	4.087976833828202	
i 1	240.01550340136055	1.01	74	197	6	9	6	8	0	-1	8	0	0	8.003796959404667	
i 1	240.2366598639456	0.2525	72	1081	6	5	2	1	0	-1	1	0	0	3.0	
i 1	240.24098639455784	0.7575000000000001	74	197	4	1	12	17	0	2	17	0	0	9.0	
i 1	240.25108163265307	0.2525	71	379	4	4	14	8	0	-2	8	0	0	9.003796959404667	
i 1	240.26478231292518	0.2525	70	197	2	20	15	2	0	-2	2	0	0	4.087976833828202	
i 1	240.4866598639456	0.505	70	197	2	20	3	8	0	-1	8	0	0	4.087976833828202	
i 1	240.49314965986395	0.2525	70	583	2	24	10	8	0	-1	8	0	0	8.087976833828202	
i 1	240.49459183673468	1.7675	77	899	4	1	2	16	0	2	16	0	0	9.0	
i 1	240.49603401360545	0.505	74	197	5	4	3	2	0	-2	2	0	0	9.003796959404667	
i 1	240.49819727891156	0.2525	74	197	4	1	3	16	0	1	16	0	0	9.0	
i 1	240.4996394557823	0.505	61	197	1	27	10	1	0	248	1	308	0	5.92693010167075	
i 1	240.50108163265307	0.505	73	197	2	24	10	8	0	-2	8	0	0	8.087976833828202	
i 1	240.50324489795918	0.2525	71	899	6	2	8	8	0	-2	8	0	0	9.003796959404667	
i 1	240.50757142857142	0.505	61	197	1	27	6	16	0	248	16	308	0	5.92693010167075	
i 1	240.51766666666666	0.505	77	197	5	1	1	17	0	2	17	0	0	9.0	
i 1	240.7388231292517	0.2525	69	583	4	5	5	1	0	-1	1	0	0	3.0	
i 1	240.98233333333334	0.2525	69	583	4	5	7	0	0	0	0	0	0	3.0	
i 1	240.9859387755102	1.5150000000000001	74	196	5	4	11	2	0	-1	2	0	0	9.003796959404667	
i 1	240.9866598639456	0.505	69	1165	4	5	12	1	0	-1	1	0	0	3.0	
i 1	240.98738095238096	5.3025	70	196	2	24	5	2	0	-2	2	0	0	8.087976833828202	
i 1	240.99387074829932	0.2525	77	899	4	1	15	17	0	2	17	0	0	9.0	
i 1	240.99603401360545	1.7675	74	196	5	1	2	17	0	1	17	0	0	9.0	
i 1	240.99603401360545	2.7775	70	1165	3	20	9	8	0	-2	8	0	0	4.087976833828202	
i 1	241.00108163265307	16.16	61	196	1	27	16	16	0	252	16	307	0	5.92693010167075	
i 1	241.00901360544216	1.2625	77	1165	4	1	10	16	0	1	16	0	0	9.0	
i 1	241.00973469387756	2.2725	73	1165	3	24	15	2	0	-1	2	0	0	8.087976833828202	
i 1	241.23521768707482	1.2625	77	583	4	1	11	17	0	1	17	0	0	9.0	
i 1	241.26622448979592	0.2525	70	583	2	24	10	2	0	-2	2	0	0	8.087976833828202	
i 1	241.49242857142858	1.5150000000000001	71	899	6	2	7	2	0	-1	2	0	0	9.003796959404667	
i 1	241.50468707482995	2.525	74	583	4	24	5	16	0	1	16	0	0	12.0	
i 1	241.73954421768707	0.2525	73	583	2	24	11	2	0	-1	2	0	0	8.087976833828202	
i 1	241.75540816326532	0.2525	70	899	2	20	7	8	0	-2	8	0	0	4.087976833828202	
i 1	241.99314965986395	1.2625	70	1165	2	20	2	2	0	-1	2	0	0	4.087976833828202	
i 1	242.24242857142858	1.01	73	196	1	20	1	8	0	-2	8	0	0	4.087976833828202	
i 1	242.49459183673468	0.2525	77	1165	4	1	16	16	0	1	16	0	0	9.0	
i 1	242.7359387755102	0.2525	77	899	4	1	8	16	0	2	16	0	0	9.0	
i 1	243.00324489795918	0.2525	74	196	5	1	5	17	0	1	17	0	0	9.0	
i 1	243.00324489795918	0.505	74	583	4	4	14	2	0	-2	2	0	0	9.003796959404667	
i 1	243.00973469387756	0.2525	74	583	5	3	12	8	0	-1	8	0	0	9.003796959404667	
i 1	243.2359387755102	0.2525	73	899	2	20	10	2	0	-2	2	0	0	4.087976833828202	
i 1	243.24459183673468	0.505	74	196	5	3	11	2	0	-1	2	0	0	9.003796959404667	
i 1	243.26478231292518	0.505	73	1165	1	24	14	2	0	252	2	307	0	8.087976833828202	
i 1	243.26550340136055	2.02	74	196	3	1	16	17	0	1	17	0	0	9.0	
i 1	243.4996394557823	1.7675	70	1165	2	20	6	8	0	-1	8	0	0	4.087976833828202	
i 1	243.5003605442177	1.7675	73	196	1	20	11	2	0	-2	2	0	0	4.087976833828202	
i 1	243.50685034013605	0.2525	73	1165	2	20	7	2	0	-1	2	0	0	4.087976833828202	
i 1	243.74459183673468	0.2525	71	899	6	2	11	2	0	-1	2	0	0	9.003796959404667	
i 1	243.76622448979592	2.525	73	1165	2	24	4	2	0	-1	2	0	0	8.087976833828202	
i 1	243.98449659863945	2.2725	70	1165	3	20	4	8	0	-2	8	0	0	4.087976833828202	
i 1	243.99242857142858	0.505	74	583	5	3	2	8	0	-1	8	0	0	9.003796959404667	
i 1	244.01766666666666	6.0600000000000005	77	1165	4	1	14	16	0	1	16	0	0	9.0	
i 1	244.2417074829932	2.02	77	899	4	1	13	16	0	2	16	0	0	9.0	
i 1	244.24314965986395	0.505	74	1165	5	9	11	8	0	-2	8	0	0	8.003796959404667	
i 1	244.73449659863945	4.04	74	196	5	3	12	2	0	-1	2	0	0	9.003796959404667	
i 1	244.76766666666666	0.2525	69	1165	4	5	13	1	0	0	1	0	0	3.0	
i 1	244.99675510204082	1.5150000000000001	69	583	6	5	3	1	0	-1	1	0	0	3.0	
i 1	245.00757142857142	1.2625	70	196	2	20	8	2	0	-2	2	0	0	4.087976833828202	
i 1	245.2388231292517	1.01	74	196	5	24	11	17	0	2	17	0	0	12.0	
i 1	245.24531292517005	0.2525	73	899	2	20	9	8	0	-1	8	0	0	4.087976833828202	
i 1	245.25540816326532	0.2525	73	583	2	24	3	8	0	-1	8	0	0	8.087976833828202	
i 1	245.50973469387756	0.2525	73	196	1	20	5	2	0	-2	2	0	0	4.087976833828202	
i 1	245.51045578231293	0.2525	70	196	1	24	9	8	0	-1	8	0	0	8.087976833828202	
i 1	245.74459183673468	0.2525	74	1165	5	9	3	8	0	-2	8	0	0	8.003796959404667	
i 1	245.7640612244898	0.505	74	196	5	4	16	2	0	-1	2	0	0	9.003796959404667	
i 1	245.98377551020408	0.2525	70	1165	2	20	4	8	0	-2	8	0	0	4.087976833828202	
i 1	245.9974761904762	0.2525	73	1165	2	20	1	2	0	-2	2	0	0	4.087976833828202	
i 1	246.01189795918367	0.2525	71	1165	5	9	2	8	0	-1	8	0	0	8.003796959404667	
i 1	246.23377551020408	1.2625	71	899	6	2	6	2	0	-1	2	0	0	9.003796959404667	
i 1	246.24675510204082	0.505	70	1165	2	20	7	8	0	-2	8	0	0	5.018084618446634	
i 1	246.2503605442177	9.09	61	899	5	25	4	16	0	2	16	0	0	5.334237091503674	
i 1	246.2525238095238	0.505	70	196	1	20	11	8	0	-2	8	0	0	5.018084618446634	
i 1	246.25540816326532	0.505	70	196	1	24	15	8	0	-2	8	0	0	9.018084618446634	
i 1	246.2611768707483	0.7575000000000001	74	196	3	24	6	17	0	2	17	0	0	12.0	
i 1	246.2611768707483	0.505	73	1165	2	20	1	2	0	-2	2	0	0	5.018084618446634	
i 1	246.2640612244898	4.04	77	899	6	1	8	16	0	2	16	0	0	9.0	
i 1	246.26766666666666	3.0300000000000002	70	196	2	24	15	2	0	-2	2	0	0	9.018084618446634	
i 1	246.5111768707483	0.2525	69	583	6	5	14	0	0	0	0	0	0	3.0	
i 1	246.75685034013605	0.2525	73	583	2	20	4	8	0	-1	8	0	0	5.018084618446634	
i 1	246.75901360544216	0.2525	72	899	6	5	5	0	0	0	0	0	0	3.0	
i 1	246.7640612244898	0.2525	70	899	2	20	6	8	0	-2	8	0	0	5.018084618446634	
i 1	246.98449659863945	1.2625	70	1165	2	20	15	8	0	-2	8	0	0	5.018084618446634	
i 1	247.00468707482995	1.2625	69	583	6	5	11	0	0	0	0	0	0	3.0	
i 1	247.0140612244898	1.2625	70	196	1	24	3	2	0	-2	2	0	0	9.018084618446634	
i 1	247.01550340136055	0.2525	74	1165	4	1	16	17	0	2	17	0	0	9.0	
i 1	247.25468707482995	4.2925	72	899	6	5	12	0	0	0	0	0	0	3.0	
i 1	247.2582925170068	1.2625	74	196	3	1	14	17	0	1	17	0	0	9.0	
i 1	247.4996394557823	0.2525	74	196	5	4	15	2	0	-1	2	0	0	9.003796959404667	
i 1	247.7503605442177	2.02	70	1165	2	20	13	8	0	-2	8	0	0	5.018084618446634	
i 1	248.23810204081633	2.02	69	196	3	5	3	1	0	0	1	0	0	3.0	
i 1	248.2417074829932	2.2725	74	196	5	4	12	2	0	-1	2	0	0	9.003796959404667	
i 1	248.25901360544216	2.525	74	583	4	4	16	2	0	-2	2	0	0	9.003796959404667	
i 1	248.26045578231293	0.505	73	899	2	20	16	2	0	-2	2	0	0	5.018084618446634	
i 1	248.26189795918367	0.505	70	583	2	20	10	2	0	-2	2	0	0	5.018084618446634	
i 1	248.5133401360544	0.505	74	1165	4	1	13	17	0	2	17	0	0	9.0	
i 1	248.74026530612244	0.2525	70	196	1	24	9	2	0	-1	2	0	0	9.018084618446634	
i 1	248.74242857142858	0.2525	77	899	6	1	8	17	0	2	17	0	0	9.0	
i 1	248.75108163265307	0.2525	70	1165	2	20	12	2	0	-2	2	0	0	5.018084618446634	
i 1	248.9996394557823	0.2525	70	583	2	24	15	8	0	-1	8	0	0	9.018084618446634	
i 1	249.00757142857142	0.2525	70	899	2	20	14	2	0	-2	2	0	0	5.018084618446634	
i 1	249.0111768707483	4.04	74	196	3	1	14	17	0	1	17	0	0	9.0	
i 1	249.01622448979592	0.2525	77	583	4	1	4	17	0	1	17	0	0	9.0	
i 1	249.23810204081633	0.2525	74	583	5	3	3	8	0	-1	8	0	0	9.003796959404667	
i 1	249.24098639455784	4.545	70	196	1	24	7	2	0	-1	2	0	0	9.018084618446634	
i 1	249.24891836734693	4.545	73	1165	2	20	10	8	0	-1	8	0	0	5.018084618446634	
i 1	249.25396598639455	6.565	70	196	1	24	8	2	0	-2	2	0	0	9.018084618446634	
i 1	249.2669455782313	7.8275	61	899	5	25	13	1	0	1	1	0	0	5.334237091503674	
i 1	249.4866598639456	2.525	71	899	6	2	10	2	0	-1	2	0	0	9.003796959404667	
i 1	249.5082925170068	2.525	74	1165	5	9	7	8	0	-2	8	0	0	8.003796959404667	
i 1	249.75180272108844	2.2725	70	196	1	20	10	2	0	-2	2	0	0	5.018084618446634	
i 1	249.98954421768707	0.2525	77	899	6	1	15	17	0	2	17	0	0	9.0	
i 1	250.24387074829932	1.7675	72	196	3	5	16	0	0	-1	0	0	0	3.0	
i 1	250.24603401360545	0.2525	69	899	6	5	2	1	0	-1	1	0	0	3.0	
i 1	250.4974761904762	1.5150000000000001	69	583	6	5	14	0	0	0	0	0	0	3.0	
i 1	250.74098639455784	0.2525	74	196	5	3	5	2	0	-1	2	0	0	9.003796959404667	
i 1	250.76550340136055	0.2525	74	196	5	4	13	2	0	-1	2	0	0	9.003796959404667	
i 1	250.9866598639456	3.0300000000000002	71	1165	5	9	15	8	0	-1	8	0	0	8.003796959404667	
i 1	250.98738095238096	2.7775	71	899	6	2	1	8	0	-2	8	0	0	9.003796959404667	
i 1	251.0025238095238	3.7875	69	1165	6	5	14	1	0	-1	1	0	0	3.0	
i 1	251.0133401360544	3.7875	69	899	6	5	3	1	0	-1	1	0	0	3.0	
i 1	251.98954421768707	0.505	74	196	5	4	9	2	0	-1	2	0	0	9.003796959404667	
i 1	252.00108163265307	0.2525	69	1165	4	5	8	1	0	0	1	0	0	3.0	
i 1	252.00901360544216	0.2525	74	196	5	3	12	2	0	-1	2	0	0	9.003796959404667	
i 1	252.0140612244898	4.04	77	899	6	1	1	16	0	2	16	0	0	9.0	
i 1	252.2330544217687	4.7975	61	583	5	25	10	1	0	1	1	0	0	5.334237091503674	
i 1	252.24531292517005	0.2525	71	899	6	2	3	2	0	-1	2	0	0	9.003796959404667	
i 1	252.49531292517005	4.545	74	583	5	3	1	8	0	-1	8	0	0	9.003796959404667	
i 1	252.50540816326532	0.2525	74	1165	5	9	15	8	0	-2	8	0	0	8.003796959404667	
i 1	252.98233333333334	0.2525	74	1165	4	1	13	17	0	2	17	0	0	9.0	
i 1	253.25108163265307	1.5150000000000001	74	583	4	24	10	16	0	1	16	0	0	12.0	
i 1	253.26550340136055	1.2625	74	196	3	24	2	17	0	2	17	0	0	12.0	
i 1	253.50396598639455	1.2625	70	196	1	20	10	2	0	-2	2	0	0	5.018084618446634	
i 1	253.7366598639456	0.2525	70	583	2	20	6	8	0	-2	8	0	0	5.018084618446634	
i 1	253.74098639455784	1.5150000000000001	74	1165	5	9	11	8	0	-2	8	0	0	8.003796959404667	
i 1	253.74387074829932	2.02	72	196	3	5	16	0	0	-1	0	0	0	3.0	
i 1	253.98233333333334	3.0300000000000002	71	899	6	2	1	2	0	-1	2	0	0	9.003796959404667	
i 1	253.99819727891156	0.7575000000000001	73	196	1	20	2	8	0	-2	8	0	0	5.018084618446634	
i 1	254.00973469387756	1.7675	70	1165	2	20	5	8	0	-1	8	0	0	5.018084618446634	
i 1	254.48738095238096	0.2525	74	1165	4	1	3	17	0	2	17	0	0	9.0	
i 1	254.74531292517005	2.2725	72	899	6	5	3	0	0	0	0	0	0	3.0	
i 1	254.75685034013605	0.2525	74	196	3	24	4	17	0	2	17	0	0	12.0	
i 1	254.76550340136055	2.2725	74	196	3	1	8	17	0	1	17	0	0	9.0	
i 1	255.23233333333334	1.7675	63	583	5	25	13	16	0	2	16	0	0	5.334237091503674	
i 1	255.26622448979592	1.7675	61	899	5	25	7	16	0	2	16	0	0	5.334237091503674	
i 1	255.50396598639455	0.2525	74	583	4	4	15	2	0	-2	2	0	0	9.003796959404667	
i 1	255.73521768707482	1.2625	74	1165	5	9	6	8	0	-2	8	0	0	8.003796959404667	
i 1	255.7417074829932	1.2625	69	583	6	5	4	1	0	-1	1	0	0	3.0	
i 1	255.98449659863945	1.01	70	196	1	24	3	2	0	-2	2	0	0	9.018084618446634	
i 1	255.99531292517005	0.2525	74	1165	6	1	12	17	0	2	17	0	0	9.0	
i 1	255.9974761904762	1.01	69	196	7	5	5	1	0	0	1	0	0	3.0	
i 1	256.0082925170068	1.01	70	1165	2	20	10	8	0	-1	8	0	0	5.018084618446634	
i 1	256.01045578231293	0.2525	74	583	4	24	8	16	0	1	16	0	0	12.0	
i 1	256.2539659863946	0.7575000000000001	77	899	6	1	15	16	0	2	16	0	0	9.0	
i 1	256.50252380952384	0.505	71	1165	5	9	4	8	0	-1	8	0	0	8.003796959404667	
i 1	256.5133401360544	0.505	74	583	4	24	7	16	0	1	16	0	0	12.0	
i 1	256.51478231292515	0.505	69	1165	6	5	15	1	0	-1	1	0	0	3.0	
i 1	256.51550340136055	0.505	73	196	1	20	2	8	0	-2	8	0	0	5.018084618446634	
i 1	256.7359387755102	0.2525	70	196	1	20	4	2	0	-2	2	0	0	5.018084618446634	
i 1	256.9823333333333	0.7575000000000001	70	695	1	24	10	8	0	248	8	308	0	9.018084618446634	
i 1	256.9830544217687	1.2625	74	197	5	24	16	16	0	1	16	0	0	12.0	
i 1	256.98377551020405	1.2625	63	695	5	25	10	16	0	2	16	0	0	5.334237091503674	
i 1	256.98521768707485	0.505	74	695	6	1	6	17	0	2	17	0	0	9.0	
i 1	256.98954421768707	2.525	77	197	6	1	6	16	0	2	16	0	0	9.0	
i 1	256.9967551020408	1.5150000000000001	77	1081	5	1	10	16	0	1	16	0	0	9.0	
i 1	256.99891836734696	10.352500000000001	63	695	1	27	16	1	0	252	1	307	0	5.92693010167075	
i 1	256.9996394557823	0.2525	71	695	4	4	8	8	0	-1	8	0	0	9.003796959404667	
i 1	256.9996394557823	2.02	69	197	7	5	13	0	0	0	0	0	0	3.0	
i 1	257.00180272108844	0.505	77	1081	3	1	16	17	0	1	17	0	0	9.0	
i 1	257.0046870748299	7.3225	63	197	6	25	5	1	0	2	1	0	0	5.334237091503674	
i 1	257.0054081632653	1.2625	71	1081	5	9	7	8	0	-2	8	0	0	8.003796959404667	
i 1	257.0082925170068	0.505	74	1081	5	9	15	8	0	-2	8	0	0	8.003796959404667	
i 1	257.0111768707483	4.2925	63	695	5	25	2	16	0	1	16	0	0	5.334237091503674	
i 1	257.01189795918367	0.2525	74	695	2	1	8	17	0	1	17	0	0	9.0	
i 1	257.01261904761907	2.02	69	1081	6	5	9	1	0	0	1	0	0	3.0	
i 1	257.0169455782313	4.2925	61	197	6	25	2	1	0	1	1	0	0	5.334237091503674	
i 1	257.0176666666667	0.505	72	695	6	5	10	0	0	0	0	0	0	3.0	
i 1	257.51189795918367	0.2525	69	695	3	5	4	1	0	0	1	0	0	3.0	
i 1	257.7323333333333	2.7775	74	695	4	3	5	2	0	-2	2	0	0	9.003796959404667	
i 1	257.98810204081633	3.7875	72	1081	6	5	11	0	0	-1	0	0	0	3.0	
i 1	257.9945918367347	2.525	74	695	6	2	13	8	0	-2	8	0	0	9.003796959404667	
i 1	257.99891836734696	0.2525	72	695	6	5	16	1	0	-1	1	0	0	3.0	
i 1	258.0046870748299	1.01	73	1081	1	20	11	2	0	-1	2	0	0	5.018084618446634	
i 1	258.2366598639456	0.2525	77	1081	5	1	8	17	0	1	17	0	0	9.0	
i 1	258.23738095238093	1.01	71	1081	5	9	4	8	0	-2	8	0	0	8.003796959404667	
i 1	258.24747619047616	6.0600000000000005	63	695	5	25	1	16	0	2	16	0	0	5.334237091503674	
i 1	258.24747619047616	2.02	69	695	6	5	8	1	0	0	1	0	0	3.0	
i 1	258.2546870748299	2.02	69	197	7	5	9	1	0	0	1	0	0	3.0	
i 1	258.2554081632653	9.09	61	1081	4	26	6	1	0	1	1	0	0	5.334237091503674	
i 1	258.5054081632653	6.0600000000000005	74	695	6	1	13	17	0	2	17	0	0	9.0	
i 1	258.5054081632653	1.2625	74	695	2	1	9	17	0	1	17	0	0	9.0	
i 1	258.75685034013605	2.525	77	1081	5	1	12	16	0	1	16	0	0	9.0	
i 1	258.76550340136055	2.2725	74	197	5	24	7	16	0	1	16	0	0	12.0	
i 1	258.98377551020405	0.2525	70	695	2	20	9	2	0	-1	2	0	0	5.018084618446634	
i 1	258.98521768707485	2.525	73	1081	1	24	13	2	0	-2	2	0	0	9.018084618446634	
i 1	258.98954421768707	0.2525	70	695	2	20	13	2	0	-2	2	0	0	5.018084618446634	
i 1	258.9996394557823	0.2525	73	197	2	20	9	2	0	-1	2	0	0	5.018084618446634	
i 1	259.25973469387753	4.545	70	1081	1	20	7	8	0	-2	8	0	0	5.018084618446634	
i 1	259.26045578231293	2.02	73	1081	1	20	9	2	0	-1	2	0	0	5.018084618446634	
i 1	259.26550340136055	5.05	71	695	4	4	15	8	0	-1	8	0	0	9.003796959404667	
i 1	259.4888231292517	4.2925	71	197	6	3	13	8	0	-2	8	0	0	9.003796959404667	
i 1	259.74387074829934	0.2525	77	695	6	1	5	16	0	2	16	0	0	9.0	
i 1	260.2388231292517	1.01	74	695	2	1	10	17	0	1	17	0	0	9.0	
i 1	260.24242857142855	2.02	69	1081	6	5	7	1	0	0	1	0	0	3.0	
i 1	260.2554081632653	2.02	69	197	7	5	6	0	0	0	0	0	0	3.0	
i 1	260.2611768707483	2.2725	71	695	6	2	5	8	0	-1	8	0	0	9.003796959404667	
i 1	261.23377551020405	3.0300000000000002	74	695	4	1	5	17	0	1	17	0	0	9.0	
i 1	261.24242857142855	0.2525	77	1081	5	1	4	17	0	1	17	0	0	9.0	
i 1	261.24314965986395	13.8875	63	695	5	25	11	16	0	1	16	0	0	5.334237091503674	
i 1	261.25685034013605	9.09	63	1081	4	26	3	16	0	2	16	0	0	5.334237091503674	
i 1	261.25757142857145	6.0600000000000005	61	197	6	25	16	1	0	1	1	0	0	5.334237091503674	
i 1	261.25757142857145	0.2525	69	695	6	5	3	1	0	0	1	0	0	3.0	
i 1	261.49242857142855	0.2525	69	197	7	5	13	1	0	0	1	0	0	3.0	
i 1	261.4960340136054	5.555	77	197	6	1	3	16	0	2	16	0	0	9.0	
i 1	261.51189795918367	2.7775	77	695	2	24	13	17	0	2	17	0	0	12.0	
i 1	261.7409863945578	1.01	69	695	5	5	2	0	0	-1	0	0	0	3.0	
i 1	261.75252380952384	1.01	72	695	6	5	11	0	0	0	0	0	0	3.0	
i 1	261.9866598639456	2.2725	69	197	7	5	15	1	0	0	1	0	0	3.0	
i 1	262.74026530612247	0.2525	72	1081	6	5	16	0	0	-1	0	0	0	3.0	
i 1	263.24747619047616	0.2525	69	197	7	5	7	0	0	0	0	0	0	3.0	
i 1	263.4823333333333	1.01	72	695	6	5	14	0	0	0	0	0	0	3.0	
i 1	263.5003605442177	0.7575000000000001	73	1081	1	20	13	2	0	-1	2	0	0	5.018084618446634	
i 1	263.50612925170066	1.2625	69	695	5	5	15	0	0	-1	0	0	0	3.0	
i 1	263.9830544217687	0.2525	70	1081	1	20	6	2	0	-2	2	0	0	5.018084618446634	
i 1	263.9859387755102	0.2525	71	197	5	4	16	2	0	-2	2	0	0	9.003796959404667	
i 1	263.99242857142855	1.7675	69	197	7	5	6	0	0	0	0	0	0	3.0	
i 1	264.0032448979592	0.2525	70	1081	1	20	3	8	0	-2	8	0	0	5.018084618446634	
i 1	264.2359387755102	2.02	70	1081	1	20	13	8	0	-2	8	0	0	4.0046649342760805	
i 1	264.23738095238093	2.7775	77	695	4	24	6	17	0	2	17	0	0	12.0	
i 1	264.2388231292517	0.7575000000000001	73	1081	3	20	7	2	0	-1	2	0	0	4.0046649342760805	
i 1	264.2409863945578	0.2525	71	197	6	3	5	8	0	-2	8	0	0	9.003796959404667	
i 1	264.2417074829932	2.02	70	1081	1	20	9	2	0	-2	2	0	0	4.0046649342760805	
i 1	264.24387074829934	9.09	61	695	3	27	4	1	0	1	1	0	0	5.92693010167075	
i 1	264.2503605442177	10.8575	63	695	5	25	1	16	0	2	16	0	0	5.334237091503674	
i 1	264.2554081632653	6.0600000000000005	63	197	6	25	8	1	0	2	1	0	0	5.334237091503674	
i 1	264.26045578231293	2.2725	71	695	4	2	5	8	0	-1	8	0	0	9.003796959404667	
i 1	264.2633401360544	0.7575000000000001	73	1081	1	24	13	2	0	-2	2	0	0	8.00466493427608	
i 1	264.48449659863945	1.01	71	197	5	4	15	2	0	-2	2	0	0	9.003796959404667	
i 1	264.4967551020408	0.2525	69	695	6	5	10	1	0	0	1	0	0	3.0	
i 1	264.51550340136055	0.2525	77	695	6	1	11	16	0	2	16	0	0	9.0	
i 1	264.73449659863945	1.01	77	1081	5	1	9	16	0	1	16	0	0	9.0	
i 1	264.7388231292517	1.7675	72	695	5	5	4	1	0	-1	1	0	0	3.0	
i 1	264.74747619047616	1.01	74	197	5	24	2	16	0	1	16	0	0	12.0	
i 1	264.7496394557823	1.7675	72	1081	6	5	7	0	0	-1	0	0	0	3.0	
i 1	265.4953129251701	2.7775	74	695	5	3	14	2	0	-2	2	0	0	9.003796959404667	
i 1	265.73810204081633	2.525	74	695	4	1	6	17	0	1	17	0	0	9.0	
i 1	265.7417074829932	0.2525	74	695	6	1	4	17	0	2	17	0	0	9.0	
i 1	265.74819727891156	1.2625	73	1081	1	24	1	2	0	-2	2	0	0	8.00466493427608	
i 1	265.75180272108844	2.02	69	197	5	5	3	1	0	0	1	0	0	3.0	
i 1	265.98521768707485	0.2525	74	197	5	24	10	16	0	1	16	0	0	12.0	
i 1	266.2467551020408	1.01	74	695	6	1	12	17	0	2	17	0	0	9.0	
i 1	266.4953129251701	2.2725	70	1081	1	20	1	2	0	-2	2	0	0	4.0046649342760805	
i 1	266.5133401360544	0.2525	72	695	6	5	13	0	0	0	0	0	0	3.0	
i 1	266.73521768707485	0.2525	74	1081	5	9	9	8	0	-2	8	0	0	8.003796959404667	
i 1	266.7582925170068	0.2525	69	1081	6	5	7	1	0	0	1	0	0	3.0	
i 1	266.98954421768707	1.01	73	1081	1	24	10	2	0	252	2	307	0	8.00466493427608	
i 1	267.0082925170068	0.2525	69	695	5	5	14	0	0	-1	0	0	0	3.0	
i 1	267.0090136054422	0.2525	74	197	5	24	10	16	0	1	16	0	0	12.0	
i 1	267.2388231292517	0.2525	77	1081	5	1	6	17	0	1	17	0	0	9.0	
i 1	267.2460340136054	7.8275	61	197	5	25	3	1	0	1	1	0	0	5.334237091503674	
i 1	267.2496394557823	1.01	72	695	6	5	11	1	0	-1	1	0	0	3.0	
i 1	267.25180272108844	1.2625	74	695	4	2	2	8	0	-2	8	0	0	9.003796959404667	
i 1	267.25180272108844	1.01	72	1081	6	5	3	0	0	-1	0	0	0	3.0	
i 1	267.25757142857145	1.01	74	695	6	1	3	17	0	2	17	0	0	9.0	
i 1	267.26550340136055	6.0600000000000005	61	1081	4	26	13	1	0	1	1	0	0	5.334237091503674	
i 1	267.26550340136055	7.8275	63	695	3	27	2	1	0	1	1	0	0	5.92693010167075	
i 1	267.26622448979595	0.505	70	1081	3	20	7	8	0	-2	8	0	0	4.0046649342760805	
i 1	267.49242857142855	0.2525	77	197	6	1	4	16	0	2	16	0	0	9.0	
i 1	267.7503605442177	2.02	71	197	6	3	16	8	0	-2	8	0	0	9.003796959404667	
i 1	267.75757142857145	0.7575000000000001	73	197	2	20	15	2	0	-2	2	0	0	4.0046649342760805	
i 1	267.75973469387753	1.5150000000000001	74	197	5	24	11	16	0	1	16	0	0	12.0	
i 1	267.7633401360544	0.505	70	695	4	20	5	2	0	-1	2	0	0	4.0046649342760805	
i 1	267.7669455782313	2.02	71	695	4	4	8	8	0	-1	8	0	0	9.003796959404667	
i 1	267.9823333333333	0.505	73	197	2	24	15	8	0	-1	8	0	0	8.00466493427608	
i 1	268.0054081632653	1.5150000000000001	73	1081	1	24	16	2	0	-2	2	0	0	8.00466493427608	
i 1	268.23377551020405	0.2525	77	695	4	24	6	17	0	2	17	0	0	12.0	
i 1	268.2532448979592	0.2525	69	695	5	5	3	0	0	-1	0	0	0	3.0	
i 1	268.4830544217687	0.2525	74	695	5	3	3	2	0	-2	2	0	0	9.003796959404667	
i 1	268.4967551020408	0.505	72	695	6	5	2	0	0	0	0	0	0	3.0	
i 1	268.74026530612247	1.2625	74	695	4	1	7	17	0	1	17	0	0	9.0	
i 1	268.75685034013605	0.2525	71	1081	5	9	8	8	0	-2	8	0	0	8.003796959404667	
i 1	268.75973469387753	1.5150000000000001	74	695	6	1	11	17	0	2	17	0	0	9.0	
i 1	268.9917074829932	0.2525	72	695	6	5	2	1	0	-1	1	0	0	3.0	
i 1	269.2388231292517	0.7575000000000001	69	695	5	5	4	0	0	-1	0	0	0	3.0	
i 1	269.2503605442177	0.2525	77	695	6	1	16	16	0	2	16	0	0	9.0	
i 1	269.25252380952384	4.04	71	695	4	2	6	8	0	-1	8	0	0	9.003796959404667	
i 1	269.5082925170068	3.7875	77	695	4	24	13	17	0	2	17	0	0	12.0	
i 1	269.5082925170068	0.2525	73	695	4	20	14	2	0	-2	2	0	0	4.0046649342760805	
i 1	269.5111768707483	1.7675	69	197	5	5	3	1	0	0	1	0	0	3.0	
i 1	269.5133401360544	1.5150000000000001	69	695	6	5	13	1	0	0	1	0	0	3.0	
i 1	269.74747619047616	0.2525	70	1081	3	20	7	8	0	-2	8	0	0	4.0046649342760805	
i 1	269.7669455782313	0.2525	74	695	4	2	5	8	0	-2	8	0	0	9.003796959404667	
i 1	269.9866598639456	0.2525	71	197	6	3	6	8	0	-2	8	0	0	9.003796959404667	
i 1	270.0032448979592	1.2625	73	1081	1	24	7	2	0	-2	2	0	0	8.00466493427608	
i 1	270.23954421768707	2.7775	77	197	7	1	3	16	0	2	16	0	0	9.0	
i 1	270.24387074829934	2.525	70	695	2	20	1	2	0	-2	2	0	0	4.0046649342760805	
i 1	270.2453129251701	0.2525	77	695	6	1	16	16	0	2	16	0	0	9.0	
i 1	270.2453129251701	4.7975	63	1081	4	26	4	16	0	2	16	0	0	5.334237091503674	
i 1	270.25252380952384	0.2525	72	695	4	5	2	1	0	-1	1	0	0	3.0	
i 1	270.2546870748299	4.7975	63	197	5	25	13	1	0	2	1	0	0	5.334237091503674	
i 1	270.4859387755102	0.2525	77	1081	5	1	7	17	0	1	17	0	0	9.0	
i 1	270.49387074829934	0.2525	74	695	4	2	1	8	0	-2	8	0	0	9.003796959404667	
i 1	270.50252380952384	1.5150000000000001	72	695	6	5	1	0	0	0	0	0	0	3.0	
i 1	270.51261904761907	1.5150000000000001	69	695	6	5	6	0	0	-1	0	0	0	3.0	
i 1	270.73449659863945	2.02	70	1081	3	20	15	8	0	-2	8	0	0	4.0046649342760805	
i 1	270.74026530612247	0.7575000000000001	71	695	4	4	10	8	0	-1	8	0	0	9.003796959404667	
i 1	270.7409863945578	1.01	71	197	4	3	15	8	0	-2	8	0	0	9.003796959404667	
i 1	270.7409863945578	2.02	70	1081	1	20	9	2	0	-2	2	0	0	4.0046649342760805	
i 1	270.7611768707483	1.01	74	695	6	1	6	17	0	2	17	0	0	9.0	
i 1	271.51622448979595	1.7675	69	197	5	5	4	0	0	0	0	0	0	3.0	
i 1	271.74314965986395	0.2525	74	197	5	24	11	16	0	1	16	0	0	12.0	
i 1	271.7532448979592	0.2525	71	695	4	4	4	8	0	-1	8	0	0	9.003796959404667	
i 1	271.98738095238093	0.2525	69	197	5	5	12	1	0	0	1	0	0	3.0	
i 1	271.9945918367347	1.2625	74	1081	5	9	2	8	0	-2	8	0	0	8.003796959404667	
i 1	272.01622448979595	0.2525	74	695	4	1	1	17	0	1	17	0	0	9.0	
i 1	272.2453129251701	0.2525	69	695	6	5	16	0	0	-1	0	0	0	3.0	
i 1	272.24819727891156	1.01	71	197	5	4	6	2	0	-2	2	0	0	9.003796959404667	
i 1	272.26478231292515	0.2525	77	1081	5	1	13	17	0	1	17	0	0	9.0	
i 1	272.4967551020408	1.7675	77	1081	5	1	11	16	0	1	16	0	0	9.0	
i 1	272.49819727891156	0.2525	69	695	6	5	2	1	0	0	1	0	0	3.0	
i 1	272.7503605442177	0.505	72	695	4	5	10	1	0	-1	1	0	0	3.0	
i 1	272.75973469387753	0.505	72	1081	6	5	16	0	0	-1	0	0	0	3.0	
i 1	273.2323333333333	1.7675	61	695	3	27	16	1	0	1	1	0	0	5.92693010167075	
i 1	273.24819727891156	0.2525	77	197	7	1	2	16	0	2	16	0	0	9.0	
i 1	273.2532448979592	0.505	72	695	5	5	4	1	0	-1	1	0	0	3.0	
i 1	273.26189795918367	1.7675	69	695	6	5	15	1	0	0	1	0	0	3.0	
i 1	273.2640612244898	1.7675	70	1081	1	20	12	2	0	-2	2	0	0	4.0046649342760805	
i 1	273.26622448979595	1.7675	61	1081	4	26	13	1	0	1	1	0	0	5.334237091503674	
i 1	273.4945918367347	1.2625	70	695	2	20	8	2	0	-2	2	0	0	4.0046649342760805	
i 1	273.73377551020405	1.2625	77	197	7	1	5	16	0	2	16	0	0	9.0	
i 1	273.7633401360544	1.2625	77	695	4	24	12	17	0	2	17	0	0	12.0	
i 1	273.9917074829932	1.01	74	695	4	2	13	8	0	-2	8	0	0	9.003796959404667	
i 1	274.2539659863946	0.2525	77	695	6	1	3	16	0	2	16	0	0	9.0	
i 1	274.4823333333333	0.505	69	197	5	5	15	0	0	0	0	0	0	3.0	
i 1	274.48377551020405	0.2525	74	695	4	1	5	17	0	1	17	0	0	9.0	
i 1	274.49387074829934	0.2525	71	695	4	4	2	8	0	-1	8	0	0	9.003796959404667	
i 1	274.73377551020405	0.2525	71	197	4	3	14	8	0	-2	8	0	0	9.003796959404667	
i 1	274.98521768707485	0.505	74	901	4	2	7	2	0	-1	2	0	0	9.003796959404667	
i 1	274.98738095238093	8.585	61	901	5	25	11	1	0	1	1	0	0	5.334237091503674	
i 1	274.98954421768707	8.585	63	585	5	25	11	1	0	2	1	0	0	5.334237091503674	
i 1	274.9909863945578	1.01	74	199	5	24	15	16	0	2	16	0	0	12.0	
i 1	274.99314965986395	1.01	77	585	4	24	6	17	0	2	17	0	0	12.0	
i 1	274.99387074829934	1.5150000000000001	69	199	5	5	8	1	5000	-1	1	0	0	3.0	
i 1	274.9953129251701	3.2825	71	585	4	3	3	2	0	-2	2	0	0	9.003796959404667	
i 1	274.9953129251701	5.555	70	199	1	24	2	2	0	-2	2	0	0	8.00466493427608	
i 1	274.9967551020408	0.2525	73	199	1	20	7	8	0	-2	8	0	0	4.0046649342760805	
i 1	274.99819727891156	0.505	69	199	7	5	5	0	0	0	0	0	0	3.0	
i 1	274.99891836734696	8.585	61	199	5	26	1	1	5000	2	1	0	0	5.334237091503674	
i 1	275.0003605442177	4.2925	63	199	4	27	7	16	0	2	16	0	0	5.92693010167075	
i 1	275.0046870748299	0.2525	70	199	3	20	1	2	0	-1	2	0	0	4.0046649342760805	
i 1	275.00612925170066	0.2525	73	199	4	20	10	2	0	-1	2	0	0	4.0046649342760805	
i 1	275.0090136054422	8.585	61	585	5	25	10	1	0	1	1	0	0	5.334237091503674	
i 1	275.01189795918367	1.2625	61	199	5	26	5	1	5000	1	1	0	0	5.334237091503674	
i 1	275.01261904761907	3.2825	74	199	6	3	2	2	0	-1	2	0	0	9.003796959404667	
i 1	275.01261904761907	8.585	61	901	5	25	8	16	0	2	16	0	0	5.334237091503674	
i 1	275.01622448979595	0.2525	74	585	6	1	14	17	0	2	17	0	0	9.0	
i 1	275.0169455782313	1.2625	61	199	4	27	7	16	0	2	16	0	0	5.92693010167075	
i 1	275.2359387755102	0.2525	73	901	4	20	2	2	0	-1	2	0	0	4.0046649342760805	
i 1	275.48377551020405	1.7675	77	901	6	1	2	16	0	2	16	0	0	9.0	
i 1	275.4909863945578	1.2625	70	199	3	20	2	2	0	-2	2	0	0	4.0046649342760805	
i 1	275.49891836734696	0.2525	74	199	6	9	6	8	5000	-1	8	0	0	8.003796959404667	
i 1	275.50612925170066	0.7575000000000001	73	199	1	20	5	8	0	-2	8	0	0	4.0046649342760805	
i 1	275.75108163265304	0.2525	69	199	7	5	1	0	0	0	0	0	0	3.0	
i 1	276.0032448979592	0.2525	74	901	6	1	14	17	0	1	17	0	0	9.0	
i 1	276.00612925170066	0.2525	69	585	6	5	5	1	0	-1	1	0	0	3.0	
i 1	276.0169455782313	0.2525	69	199	7	5	5	0	0	-1	0	0	0	3.0	
i 1	276.2330544217687	7.3225	61	199	5	26	16	1	5000	1	1	0	0	5.334237091503674	
i 1	276.23521768707485	1.2625	69	585	4	5	2	1	0	-1	1	0	0	3.0	
i 1	276.2409863945578	6.0600000000000005	61	199	4	27	2	16	0	2	16	0	0	5.92693010167075	
i 1	276.2417074829932	1.2625	69	199	4	5	4	0	0	-1	0	0	0	3.0	
i 1	276.25685034013605	0.7575000000000001	74	901	6	2	1	8	0	-2	8	0	0	9.003796959404667	
i 1	276.7453129251701	2.02	72	901	5	5	6	0	0	0	0	0	0	3.0	
i 1	276.75180272108844	0.7575000000000001	74	199	5	1	1	16	0	1	16	0	0	9.0	
i 1	276.7582925170068	0.2525	73	585	4	20	16	8	0	-2	8	0	0	4.0046649342760805	
i 1	276.98738095238093	1.7675	74	901	6	1	4	17	0	1	17	0	0	9.0	
i 1	276.9909863945578	1.7675	74	199	7	1	16	16	5000	1	16	0	0	9.0	
i 1	277.00252380952384	0.2525	74	199	6	9	4	8	5000	-1	8	0	0	8.003796959404667	
i 1	277.00973469387753	1.7675	69	199	5	5	5	1	5000	-1	1	0	0	3.0	
i 1	277.0111768707483	0.505	70	199	4	20	6	2	0	-2	2	0	0	4.0046649342760805	
i 1	277.23738095238093	0.7575000000000001	73	199	1	20	4	8	0	-2	8	0	0	4.0046649342760805	
i 1	277.2611768707483	0.2525	74	199	5	4	15	2	0	-1	2	0	0	9.003796959404667	
i 1	277.2633401360544	0.2525	70	199	3	20	1	8	0	-2	8	0	0	4.0046649342760805	
i 1	277.4830544217687	0.2525	70	901	4	20	3	8	0	-2	8	0	0	4.0046649342760805	
i 1	277.48738095238093	0.2525	69	199	7	5	2	0	0	0	0	0	0	3.0	
i 1	277.50180272108844	0.2525	77	901	6	1	1	16	0	2	16	0	0	9.0	
i 1	277.74747619047616	0.505	74	199	5	24	4	16	0	2	16	0	0	12.0	
i 1	277.7496394557823	0.2525	69	199	4	5	16	0	0	-1	0	0	0	3.0	
i 1	278.00252380952384	0.2525	70	901	4	20	4	8	0	-2	8	0	0	4.0046649342760805	
i 1	278.0032448979592	1.2625	69	585	6	5	1	0	0	0	0	0	0	3.0	
i 1	278.2445918367347	1.01	69	199	7	5	8	0	0	0	0	0	0	3.0	
i 1	278.2445918367347	0.7575000000000001	73	199	4	20	10	2	0	-1	2	0	0	4.0046649342760805	
i 1	278.24819727891156	1.01	74	199	5	1	5	16	0	1	16	0	0	9.0	
i 1	278.24819727891156	1.01	74	585	4	4	5	8	0	-2	8	0	0	9.003796959404667	
i 1	278.2496394557823	1.01	74	199	5	4	4	2	0	-1	2	0	0	9.003796959404667	
i 1	278.2640612244898	1.01	74	585	6	1	14	17	0	2	17	0	0	9.0	
i 1	278.7467551020408	0.505	72	199	5	5	8	0	5000	-1	0	0	0	3.0	
i 1	278.75252380952384	3.2825	72	901	5	5	16	0	0	0	0	0	0	3.0	
i 1	278.75685034013605	0.2525	73	199	3	20	12	8	0	-1	8	0	0	4.0046649342760805	
i 1	278.7611768707483	0.505	77	585	4	24	13	17	0	2	17	0	0	12.0	
i 1	279.00973469387753	0.2525	70	901	4	20	6	8	0	-2	8	0	0	4.0046649342760805	
i 1	279.2460340136054	2.2725	74	199	5	4	8	2	0	-1	2	0	0	11.483894163016764	
i 1	279.2503605442177	2.7775	72	199	7	5	9	0	5000	-1	0	0	0	3.0	
i 1	279.25180272108844	4.2925	63	199	4	27	4	16	0	2	16	0	0	5.92693010167075	
i 1	279.26478231292515	0.2525	70	199	4	20	12	8	0	-2	8	0	0	4.0046649342760805	
i 1	279.4888231292517	1.5150000000000001	77	585	4	24	15	17	0	2	17	0	0	3.0000000000000004	
i 1	279.4917074829932	1.7675	74	199	5	24	5	16	0	2	16	0	0	3.0000000000000004	
i 1	279.51478231292515	0.2525	69	585	5	5	9	1	0	-1	1	0	0	3.0	
i 1	279.74026530612247	0.2525	72	901	5	5	3	0	0	0	0	0	0	3.0	
i 1	279.98521768707485	2.02	70	199	4	20	2	8	0	-2	8	0	0	4.0046649342760805	
i 1	279.9888231292517	2.02	73	199	4	24	8	8	5000	-2	8	0	0	8.00466493427608	
i 1	279.99747619047616	3.535	70	199	4	20	4	8	5000	-1	8	0	0	4.0046649342760805	
i 1	280.0090136054422	1.01	69	199	4	5	13	0	0	-1	0	0	0	3.0	
i 1	280.24819727891156	1.01	69	585	5	5	6	1	0	-1	1	0	0	3.0	
i 1	281.0140612244898	2.2725	74	199	4	9	15	8	5000	-1	8	0	0	10.483894163016764	
i 1	281.24026530612247	0.2525	69	199	4	5	9	0	0	-1	0	0	0	3.0	
i 1	281.48738095238093	0.505	70	199	3	20	15	8	0	-1	8	0	0	4.0046649342760805	
i 1	281.49026530612247	0.7575000000000001	70	199	1	24	5	2	0	-2	2	0	0	8.00466493427608	
i 1	281.49819727891156	1.5150000000000001	69	199	4	5	3	0	0	0	0	0	0	3.0	
i 1	281.73521768707485	0.2525	71	585	5	3	9	2	0	-2	2	0	0	11.483894163016764	
i 1	281.9859387755102	1.5150000000000001	74	199	5	24	7	16	0	2	16	0	0	3.0000000000000004	
i 1	281.9945918367347	0.2525	70	901	4	20	11	2	0	-1	2	0	0	4.0046649342760805	
i 1	282.00252380952384	1.5150000000000001	73	199	1	24	7	8	5000	252	8	307	0	8.00466493427608	
i 1	282.01189795918367	0.2525	70	585	4	20	8	8	0	-1	8	0	0	4.0046649342760805	
i 1	282.2323333333333	1.2625	73	199	4	20	13	8	0	-1	8	0	0	4.0046649342760805	
i 1	282.2323333333333	0.2525	70	199	3	24	11	2	0	-2	2	0	0	8.00466493427608	
i 1	282.2503605442177	1.2625	61	199	4	27	9	16	0	2	16	0	0	5.92693010167075	
i 1	282.25685034013605	0.2525	74	901	6	2	16	8	0	-2	8	0	0	11.483894163016764	
i 1	282.26045578231293	0.2525	72	199	4	5	14	0	5000	-1	0	0	0	3.0	
i 1	282.2640612244898	0.7575000000000001	69	585	5	5	2	0	0	0	0	0	0	3.0	
i 1	282.49387074829934	1.01	74	199	3	3	11	2	0	-1	2	0	0	11.483894163016764	
i 1	282.4953129251701	0.7575000000000001	77	585	4	24	15	17	0	2	17	0	0	3.0000000000000004	
i 1	282.74242857142855	0.7575000000000001	71	585	5	3	5	2	0	-2	2	0	0	11.483894163016764	
i 1	282.98954421768707	0.2525	72	901	5	5	7	0	0	0	0	0	0	3.0	
i 1	283.2366598639456	0.2525	70	199	3	24	7	2	0	-2	2	0	0	8.00466493427608	
i 1	283.2460340136054	0.2525	73	199	3	20	11	8	0	-1	8	0	0	4.0046649342760805	
i 1	283.4830544217687	14.8975	61	185	7	17	13	9	5004	2	9	0	0	6.036103259133875	
i 1	283.4859387755102	16.665	66	185	5	14	14	9	5004	1	9	0	0	9.532004528446173	
i 1	283.4866598639456	5.8075	66	185	6	13	16	6	5004	1	6	0	0	6.50065446762121	
i 1	283.4866598639456	2.7775	61	1087	4	18	1	9	0	1	9	0	0	6.036103259133875	
i 1	283.4866598639456	5.8075	61	1087	4	18	11	9	0	1	9	0	0	6.036103259133875	
i 1	283.49026530612247	5.8075	61	701	3	12	15	9	0	1	9	0	0	9.750981701431815	
i 1	283.49026530612247	16.665	66	185	5	14	10	6	5004	2	6	0	0	9.532004528446173	
i 1	283.49026530612247	17.4225	61	712	4	13	16	6	5001	1	6	0	0	5.957502830278858	
i 1	283.4917074829932	8.8375	66	701	3	19	16	9	0	1	9	0	0	6.036103259133875	
i 1	283.49314965986395	4.2925	71	1087	6	5	16	8	0	-1	8	0	0	6.0038288353252	
i 1	283.4945918367347	1.2625	68	1087	3	20	10	0	5004	-1	0	0	0	1.2003845630418315	
i 1	283.4953129251701	5.8075	61	1087	4	16	3	9	0	2	9	0	0	9.750981701431815	
i 1	283.49819727891156	0.7575000000000001	72	712	5	3	13	1	5001	-1	1	0	0	11.13301339623682	
i 1	283.4996394557823	1.2625	71	1087	3	24	7	0	0	0	0	0	0	5.2003845630418315	
i 1	283.50108163265304	11.8675	61	185	7	17	4	6	5004	2	6	0	0	6.036103259133875	
i 1	283.50252380952384	8.8375	66	1087	4	16	13	6	0	1	6	0	0	9.750981701431815	
i 1	283.5032448979592	11.8675	61	701	3	19	11	6	0	1	6	0	0	6.036103259133875	
i 1	283.5046870748299	8.8375	66	712	5	15	9	6	5001	2	6	0	0	8.125818084526513	
i 1	283.5046870748299	2.7775	61	701	3	12	10	9	0	1	9	0	0	9.750981701431815	
i 1	283.5046870748299	0.2525	74	712	6	5	13	2	5001	-2	2	0	0	6.0038288353252	
i 1	283.5054081632653	0.505	71	1087	3	20	4	1	5004	-1	1	0	0	1.2003845630418315	
i 1	283.50612925170066	0.505	72	701	2	3	16	1	0	0	1	0	0	11.13301339623682	
i 1	283.50612925170066	0.7575000000000001	71	185	7	5	8	8	5004	-2	8	0	0	6.0038288353252	
i 1	283.5082925170068	2.7775	61	712	5	15	4	9	5001	1	9	0	0	8.125818084526513	
i 1	283.5082925170068	2.2725	69	185	7	2	6	1	5004	0	1	0	0	11.13301339623682	
i 1	283.5082925170068	17.4225	66	712	6	17	16	6	5001	2	6	0	0	6.036103259133875	
i 1	283.50973469387753	2.7775	66	185	6	14	9	9	5004	1	9	0	0	11.376145318337118	
i 1	283.5133401360544	1.2625	71	701	2	24	13	0	5001	-1	0	0	0	5.2003845630418315	
i 1	283.51550340136055	17.4225	66	712	6	17	3	6	5001	2	6	0	0	6.036103259133875	
i 1	283.73521768707485	1.5150000000000001	74	185	7	5	6	8	5004	-1	8	0	0	6.0038288353252	
i 1	283.7669455782313	1.2625	74	1087	6	5	13	2	0	-1	2	0	0	6.0038288353252	
i 1	284.23449659863945	3.7875	71	701	2	24	16	0	0	0	0	0	0	5.2003845630418315	
i 1	284.2388231292517	0.2525	69	701	2	4	16	0	0	-1	0	0	0	11.13301339623682	
i 1	284.24891836734696	2.7775	68	1087	3	20	14	1	0	-1	1	0	0	1.2003845630418315	
i 1	284.49314965986395	0.2525	72	185	7	2	8	0	5004	0	0	0	0	11.13301339623682	
i 1	284.51261904761907	1.7675	71	185	7	5	7	8	5004	-2	8	0	0	6.0038288353252	
i 1	284.99242857142855	0.2525	72	185	7	2	9	0	5004	0	0	0	0	11.13301339623682	
i 1	285.25612925170066	2.02	69	701	2	4	12	0	0	-1	0	0	0	11.13301339623682	
i 1	285.4866598639456	1.2625	74	701	5	5	12	8	0	-1	8	0	0	6.0038288353252	
i 1	285.7417074829932	0.2525	69	1087	5	9	1	1	0	-1	1	0	0	10.13301339623682	
i 1	285.99747619047616	0.7575000000000001	74	712	6	5	8	2	5001	-2	2	0	0	6.0038288353252	
i 1	286.0140612244898	0.505	68	1087	3	20	12	0	5004	-1	0	0	0	1.2003845630418315	
i 1	286.01478231292515	5.3025	71	1087	3	24	10	0	0	0	0	0	0	5.2003845630418315	
i 1	286.24387074829934	13.8875	66	185	6	14	15	9	5004	1	9	0	0	11.376145318337118	
i 1	286.2453129251701	1.5150000000000001	71	185	7	5	11	8	5004	-2	8	0	0	6.0038288353252	
i 1	286.2467551020408	9.09	61	701	4	12	14	9	0	1	9	0	0	9.750981701431815	
i 1	286.2503605442177	9.09	61	712	5	15	3	9	5001	1	9	0	0	8.125818084526513	
i 1	286.2640612244898	13.8875	61	1087	4	18	11	9	0	1	9	0	0	6.036103259133875	
i 1	286.5003605442177	0.2525	68	712	4	20	5	0	5001	-1	0	0	0	1.2003845630418315	
i 1	286.73449659863945	2.2725	69	1087	5	9	9	1	0	-1	1	0	0	10.13301339623682	
i 1	286.75973469387753	0.505	74	1087	6	5	5	2	0	-1	2	0	0	6.0038288353252	
i 1	286.7611768707483	0.7575000000000001	68	1087	3	20	9	0	5004	-1	0	0	0	1.2003845630418315	
i 1	286.7676666666667	0.7575000000000001	68	701	2	20	9	1	5001	0	1	0	0	1.2003845630418315	
i 1	287.00108163265304	1.5150000000000001	71	701	2	20	5	1	0	0	1	0	0	1.2003845630418315	
i 1	287.23738095238093	1.5150000000000001	74	712	6	5	3	2	5001	-2	2	0	0	6.0038288353252	
i 1	287.23810204081633	1.5150000000000001	74	701	5	5	6	8	0	-1	8	0	0	6.0038288353252	
i 1	287.25612925170066	0.2525	71	1087	3	20	4	0	5004	-1	0	0	0	1.2003845630418315	
i 1	287.48738095238093	0.2525	71	712	4	24	10	1	5001	0	1	0	0	5.2003845630418315	
i 1	287.49242857142855	1.5150000000000001	68	1087	3	20	12	1	0	-1	1	0	0	1.2003845630418315	
i 1	287.5046870748299	0.2525	68	185	4	20	13	1	5004	-1	1	0	0	1.2003845630418315	
i 1	287.75252380952384	0.505	68	701	2	24	9	0	5001	0	0	0	0	5.2003845630418315	
i 1	287.7611768707483	0.505	68	1087	3	20	4	1	5004	0	1	0	0	1.2003845630418315	
i 1	287.7633401360544	0.2525	72	701	5	3	12	1	0	0	1	0	0	11.13301339623682	
i 1	287.98377551020405	0.505	69	1087	5	9	3	1	0	-1	1	0	0	10.13301339623682	
i 1	288.2496394557823	0.2525	68	185	4	20	10	0	5004	0	0	0	0	1.2003845630418315	
i 1	288.2539659863946	1.7675	71	1087	6	5	15	8	0	-1	8	0	0	6.0038288353252	
i 1	288.2539659863946	0.505	68	185	4	20	6	0	5004	-1	0	0	0	1.2003845630418315	
i 1	288.25685034013605	1.7675	71	185	7	5	7	8	5004	-2	8	0	0	6.0038288353252	
i 1	288.25757142857145	0.505	71	712	4	24	6	0	5001	-1	0	0	0	5.2003845630418315	
i 1	288.48810204081633	3.535	72	701	5	3	5	1	0	0	1	0	0	11.13301339623682	
i 1	288.7359387755102	0.2525	74	1087	6	5	7	2	0	-1	2	0	0	6.0038288353252	
i 1	288.76045578231293	0.2525	74	701	3	24	13	2	0	-2	2	0	0	3.0	
i 1	288.7611768707483	0.2525	68	701	2	24	14	0	5001	-1	0	0	0	5.2003845630418315	
i 1	288.9888231292517	0.2525	71	712	4	24	6	2	5001	-1	2	0	0	3.0	
i 1	288.9917074829932	1.5150000000000001	71	701	2	24	3	0	0	0	0	0	0	5.2003845630418315	
i 1	289.0176666666667	1.01	68	701	2	20	13	0	5001	-1	0	0	0	1.2003845630418315	
i 1	289.24314965986395	9.09	61	701	4	12	14	9	0	1	9	0	0	9.750981701431815	
i 1	289.2496394557823	10.8575	61	1087	4	18	2	9	0	1	9	0	0	6.036103259133875	
i 1	289.25108163265304	10.8575	66	185	6	13	9	6	5004	1	6	0	0	6.50065446762121	
i 1	289.2554081632653	0.2525	69	1087	5	9	12	1	0	-1	1	0	0	10.13301339623682	
i 1	289.26550340136055	9.09	61	1087	4	16	1	9	0	2	9	0	0	9.750981701431815	
i 1	289.74891836734696	4.545	71	712	4	24	9	2	5001	-1	2	0	0	3.0	
i 1	289.7633401360544	1.01	69	185	7	2	9	1	5004	0	1	0	0	11.13301339623682	
i 1	289.76478231292515	0.2525	68	701	2	24	7	0	5001	-1	0	0	0	5.2003845630418315	
i 1	290.2582925170068	0.2525	68	1087	3	20	3	1	5004	0	1	0	0	1.2003845630418315	
i 1	290.2669455782313	2.02	68	701	2	24	2	0	5001	-1	0	0	0	5.2003845630418315	
i 1	290.74819727891156	0.2525	74	712	6	5	9	2	5001	-2	2	0	0	6.0038288353252	
i 1	290.7503605442177	3.2825	71	701	2	24	8	0	0	0	0	0	0	5.2003845630418315	
i 1	290.7611768707483	3.0300000000000002	68	701	2	20	1	1	5001	-1	1	0	0	1.2003845630418315	
i 1	291.23377551020405	0.2525	74	701	5	5	7	8	0	-1	8	0	0	6.0038288353252	
i 1	291.24314965986395	0.2525	69	1087	5	9	14	1	0	-1	1	0	0	10.13301339623682	
i 1	291.4967551020408	3.2825	69	185	7	2	1	1	5004	0	1	0	0	11.13301339623682	
i 1	291.50252380952384	0.7575000000000001	74	185	7	5	11	8	5004	-1	8	0	0	6.0038288353252	
i 1	291.74026530612247	2.525	71	1087	3	24	2	0	0	0	0	0	0	5.2003845630418315	
i 1	291.7467551020408	1.01	74	1087	6	5	14	2	0	-1	2	0	0	6.0038288353252	
i 1	291.74819727891156	2.02	68	1087	3	20	13	0	5004	0	0	0	0	1.2003845630418315	
i 1	292.00685034013605	0.2525	72	185	7	2	13	0	5004	0	0	0	0	11.13301339623682	
i 1	292.24242857142855	8.585	66	712	5	15	14	6	5001	2	6	0	0	8.125818084526513	
i 1	292.24387074829934	0.2525	74	185	5	5	10	8	5004	-1	8	0	0	6.0038288353252	
i 1	292.25108163265304	7.8275	66	1087	4	16	10	6	0	1	6	0	0	9.750981701431815	
i 1	292.2554081632653	7.8275	66	701	4	19	2	9	0	1	9	0	0	6.036103259133875	
i 1	292.25757142857145	0.2525	72	701	5	3	10	1	0	0	1	0	0	11.13301339623682	
i 1	292.74026530612247	1.01	68	1087	3	20	6	1	5004	0	1	0	0	1.2003845630418315	
i 1	292.7676666666667	2.525	68	1087	3	20	3	1	0	-1	1	0	0	1.2003845630418315	
i 1	292.9953129251701	1.5150000000000001	74	712	6	5	6	2	5001	-2	2	0	0	6.0038288353252	
i 1	293.00252380952384	1.7675	74	701	5	5	15	8	0	-1	8	0	0	6.0038288353252	
i 1	293.4823333333333	0.2525	68	701	2	24	11	0	5001	-1	0	0	0	5.2003845630418315	
i 1	293.49747619047616	0.2525	71	712	6	5	14	2	5001	-2	2	0	0	6.0038288353252	
i 1	293.51622448979595	0.2525	69	701	4	4	7	0	0	-1	0	0	0	11.13301339623682	
i 1	293.7366598639456	0.2525	74	1087	6	5	15	2	0	-1	2	0	0	6.0038288353252	
i 1	293.7633401360544	0.2525	68	185	4	20	12	1	5004	0	1	0	0	1.2003845630418315	
i 1	293.7640612244898	0.2525	68	185	4	20	2	1	5004	-1	1	0	0	1.2003845630418315	
i 1	293.7676666666667	0.505	72	712	5	3	5	1	5001	-1	1	0	0	11.13301339623682	
i 1	293.7676666666667	0.2525	71	712	4	24	6	0	5001	-1	0	0	0	5.2003845630418315	
i 1	294.00612925170066	1.01	71	1087	3	20	6	1	5004	-1	1	0	0	1.2003845630418315	
i 1	294.01045578231293	1.2625	71	185	7	5	6	8	5004	-2	8	0	0	6.0038288353252	
i 1	294.48449659863945	0.7575000000000001	69	701	4	4	9	0	0	-1	0	0	0	11.13301339623682	
i 1	294.73738095238093	0.2525	74	185	5	5	9	8	5004	-1	8	0	0	6.0038288353252	
i 1	294.7611768707483	0.2525	71	701	2	20	13	0	5001	-1	0	0	0	1.2003845630418315	
i 1	294.99026530612247	0.2525	68	185	4	20	11	1	5004	-1	1	0	0	1.2003845630418315	
i 1	294.9967551020408	0.2525	71	712	4	24	11	0	5001	0	0	0	0	5.2003845630418315	
i 1	294.99819727891156	2.02	72	185	7	2	2	0	5004	0	0	0	0	11.13301339623682	
i 1	295.00612925170066	0.2525	71	185	4	20	13	1	5004	0	1	0	0	1.2003845630418315	
i 1	295.00757142857145	0.2525	68	712	4	20	4	0	5001	-1	0	0	0	1.2003845630418315	
i 1	295.0090136054422	2.02	69	1087	5	9	3	1	0	-1	1	0	0	10.13301339623682	
i 1	295.00973469387753	1.2625	74	712	6	5	14	2	5001	-2	2	0	0	6.0038288353252	
i 1	295.01622448979595	0.7575000000000001	71	1087	3	24	7	0	0	0	0	0	0	5.2003845630418315	
i 1	295.2323333333333	0.505	71	185	5	5	13	8	5004	-2	8	0	0	6.0038288353252	
i 1	295.2330544217687	4.7975	61	701	4	19	13	6	0	1	6	0	0	6.036103259133875	
i 1	295.2359387755102	0.2525	68	1087	3	20	6	0	5004	0	0	0	0	1.2003845630418315	
i 1	295.2366598639456	1.2625	74	701	5	5	5	8	0	-1	8	0	0	6.0038288353252	
i 1	295.2409863945578	5.555	61	712	5	15	8	9	5001	1	9	0	0	8.125818084526513	
i 1	295.2445918367347	4.7975	61	185	7	17	7	6	5004	2	6	0	0	6.036103259133875	
i 1	295.24891836734696	4.7975	61	701	3	12	16	9	0	1	9	0	0	9.750981701431815	
i 1	295.2611768707483	0.2525	72	712	5	3	12	1	5001	-1	1	0	0	11.13301339623682	
i 1	295.26622448979595	0.2525	71	1087	3	20	9	0	5004	0	0	0	0	1.2003845630418315	
i 1	295.50973469387753	0.7575000000000001	68	1087	3	20	5	1	0	-1	1	0	0	1.2003845630418315	
i 1	295.73738095238093	0.2525	69	701	4	4	3	0	0	-1	0	0	0	11.13301339623682	
i 1	295.73738095238093	0.2525	71	712	6	5	5	2	5001	-2	2	0	0	6.0038288353252	
i 1	296.0039659863946	1.7675	71	1087	6	5	15	8	0	-1	8	0	0	6.0038288353252	
i 1	296.0039659863946	1.01	71	701	2	24	14	0	0	0	0	0	0	5.2003845630418315	
i 1	296.0082925170068	0.2525	71	185	4	20	10	1	5004	-1	1	0	0	1.2003845630418315	
i 1	296.0090136054422	0.2525	69	185	7	2	16	1	5004	0	1	0	0	11.13301339623682	
i 1	296.0090136054422	0.2525	71	712	4	24	2	0	5001	0	0	0	0	5.2003845630418315	
i 1	296.2460340136054	0.7575000000000001	68	701	2	24	12	1	5001	0	1	0	0	5.2003845630418315	
i 1	296.2496394557823	0.2525	69	712	4	4	16	1	5001	-1	1	0	0	11.13301339623682	
i 1	296.48521768707485	1.7675	72	712	5	3	12	1	5001	-1	1	0	0	11.13301339623682	
i 1	296.49242857142855	1.7675	72	701	5	3	16	1	0	0	1	0	0	11.13301339623682	
i 1	296.75180272108844	0.2525	74	185	5	5	15	8	5004	-1	8	0	0	6.0038288353252	
i 1	297.00612925170066	0.2525	74	701	3	24	2	2	0	-2	2	0	0	3.0	
i 1	297.25180272108844	0.2525	74	701	5	5	11	8	0	-2	8	0	0	6.0038288353252	
i 1	297.26189795918367	0.7575000000000001	68	1087	3	20	6	1	0	-1	1	0	0	1.2003845630418315	
i 1	297.4917074829932	0.2525	74	1087	5	5	4	2	0	-1	2	0	0	6.0038288353252	
i 1	297.50180272108844	0.2525	69	701	4	4	3	0	0	-1	0	0	0	11.13301339623682	
i 1	297.73738095238093	0.7575000000000001	71	712	6	5	13	2	5001	-2	2	0	0	6.0038288353252	
i 1	297.73738095238093	0.505	68	1087	3	20	16	0	5004	-1	0	0	0	1.2003845630418315	
i 1	297.73954421768707	0.505	74	701	5	5	9	8	0	-2	8	0	0	6.0038288353252	
i 1	297.9888231292517	1.7675	74	701	3	24	4	2	0	-2	2	0	0	3.0	
i 1	298.00252380952384	1.01	71	185	5	5	2	8	5004	-2	8	0	0	6.0038288353252	
i 1	298.00612925170066	0.2525	71	1087	6	5	16	8	0	-1	8	0	0	6.0038288353252	
i 1	298.0169455782313	1.7675	71	712	4	24	14	2	5001	-1	2	0	0	3.0	
i 1	298.23377551020405	0.2525	68	185	4	20	12	1	5004	0	1	0	0	1.2003845630418315	
i 1	298.23521768707485	1.7675	61	701	3	12	8	9	0	1	9	0	0	9.750981701431815	
i 1	298.23738095238093	0.505	68	1087	3	20	5	1	0	-1	1	0	0	1.2003845630418315	
i 1	298.2388231292517	1.7675	61	1087	4	16	13	9	0	2	9	0	0	9.750981701431815	
i 1	298.2467551020408	0.7575000000000001	71	1087	5	5	2	8	0	-1	8	0	0	6.0038288353252	
i 1	298.24747619047616	1.7675	61	185	7	17	6	9	5004	2	9	0	0	6.036103259133875	
i 1	298.25757142857145	0.2525	68	185	4	20	4	1	5004	-1	1	0	0	1.2003845630418315	
i 1	298.26550340136055	0.7575000000000001	71	701	2	24	1	0	0	0	0	0	0	5.2003845630418315	
i 1	298.4953129251701	0.2525	71	701	2	24	1	0	5001	-1	0	0	0	5.2003845630418315	
i 1	298.5082925170068	0.2525	68	1087	3	20	16	1	5004	0	1	0	0	1.2003845630418315	
i 1	298.9917074829932	0.2525	71	701	2	20	14	1	0	0	1	0	0	1.2003845630418315	
i 1	298.99314965986395	1.01	68	1087	3	20	10	1	0	-1	1	0	0	1.2003845630418315	
i 1	298.9953129251701	0.2525	71	701	2	24	3	1	5001	-1	1	0	0	5.2003845630418315	
i 1	298.99819727891156	1.01	74	1087	5	5	1	2	0	-1	2	0	0	6.0038288353252	
i 1	299.0090136054422	1.01	74	185	5	5	9	8	5004	-1	8	0	0	6.0038288353252	
i 1	299.26261904761907	0.7575000000000001	72	701	5	3	8	1	0	0	1	0	0	11.13301339623682	
i 1	299.9823333333333	1.2625	61	4	5	18	11	6	0	2	6	0	0	6.036103259133875	
i 1	299.9859387755102	0.2525	69	4	6	9	7	0	0	-1	0	0	0	10.13301339623682	
i 1	299.9866598639456	1.2625	66	4	5	16	10	6	0	2	6	0	0	9.750981701431815	
i 1	299.98810204081633	1.2625	66	4	5	18	14	9	0	1	9	0	0	6.036103259133875	
i 1	299.99314965986395	1.2625	61	4	5	16	6	6	0	1	6	0	0	9.750981701431815	
i 1	299.9960340136054	1.2625	66	4	6	13	9	9	0	1	9	0	0	6.50065446762121	
i 1	299.9960340136054	0.2525	74	4	5	5	15	8	0	-1	8	0	0	6.0038288353252	
i 1	299.99747619047616	1.2625	61	4	5	14	9	9	0	2	9	0	0	9.532004528446173	
i 1	299.99891836734696	1.2625	61	888	4	19	4	6	0	2	6	0	0	6.036103259133875	
i 1	300.00180272108844	0.2525	68	888	2	24	6	0	5001	0	0	0	0	5.2003845630418315	
i 1	300.0032448979592	0.2525	71	4	4	20	3	1	0	0	1	0	0	1.2003845630418315	
i 1	300.0039659863946	0.7575000000000001	69	712	4	4	15	1	5001	-1	1	0	0	11.13301339623682	
i 1	300.0039659863946	1.2625	66	4	7	17	9	6	0	2	6	0	0	6.036103259133875	
i 1	300.0046870748299	0.7575000000000001	74	888	3	24	4	8	0	-2	8	0	0	3.0	
i 1	300.00757142857145	1.2625	66	4	7	17	7	6	0	1	6	0	0	6.036103259133875	
i 1	300.00757142857145	1.2625	66	4	5	14	9	9	0	2	9	0	0	9.532004528446173	
i 1	300.01189795918367	0.2525	72	4	7	2	4	1	0	-1	1	0	0	11.13301339623682	
i 1	300.01261904761907	1.2625	61	888	4	19	8	9	0	2	9	0	0	6.036103259133875	
i 1	300.01478231292515	1.2625	66	4	6	14	8	9	0	2	9	0	0	11.376145318337118	
i 1	300.01550340136055	1.2625	66	888	3	12	6	6	0	2	6	0	0	9.750981701431815	
i 1	300.01550340136055	0.7575000000000001	69	4	6	9	5	1	0	0	1	0	0	10.13301339623682	
i 1	300.01622448979595	1.2625	66	888	3	12	4	9	0	2	9	0	0	9.750981701431815	
i 1	300.0169455782313	0.2525	74	4	6	5	16	8	0	-2	8	0	0	6.0038288353252	
i 1	300.2460340136054	0.2525	71	712	4	20	3	0	5001	0	0	0	0	1.2003845630418315	
i 1	300.2611768707483	0.2525	68	712	4	24	13	1	5001	0	1	0	0	5.2003845630418315	
i 1	300.73738095238093	0.505	61	622	4	13	3	9	0	2	9	0	0	5.957502830278858	
i 1	300.74242857142855	0.505	61	622	5	15	3	6	0	2	6	0	0	8.125818084526513	
i 1	300.74819727891156	0.505	71	888	5	5	7	8	0	-2	8	0	0	6.0038288353252	
i 1	300.74891836734696	0.505	61	622	6	17	2	6	0	1	6	0	0	6.036103259133875	
i 1	300.75108163265304	0.505	61	622	5	15	16	6	0	2	6	0	0	8.125818084526513	
i 1	300.76045578231293	0.505	61	622	6	17	16	6	0	2	6	0	0	6.036103259133875	
i 1	300.76622448979595	0.505	72	4	7	2	7	0	0	0	0	0	0	11.13301339623682	
i 1	301.2330544217687	15.15	66	1092	4	19	10	9	0	2	9	0	0	6.036103259133875	
i 1	301.23449659863945	9.09	66	208	5	18	13	6	5006	1	6	0	0	6.036103259133875	
i 1	301.2359387755102	15.15	66	1092	6	17	8	6	0	2	6	0	0	6.036103259133875	
i 1	301.23738095238093	18.18	61	208	5	16	6	6	5006	1	6	0	0	9.750981701431815	
i 1	301.24314965986395	12.120000000000001	66	1092	6	17	7	9	0	2	9	0	0	6.036103259133875	
i 1	301.2460340136054	1.2625	72	1092	6	2	9	0	0	-1	0	0	0	11.13301339623682	
i 1	301.2460340136054	12.120000000000001	61	706	4	7	10	9	0	2	9	0	0	8.340503962390402	
i 1	301.24819727891156	6.0600000000000005	61	1092	3	12	8	6	0	1	6	0	0	9.750981701431815	
i 1	301.2503605442177	18.18	66	706	5	15	16	6	0	2	6	0	0	8.125818084526513	
i 1	301.2503605442177	3.0300000000000002	61	1092	3	12	16	6	0	2	6	0	0	9.750981701431815	
i 1	301.2503605442177	3.0300000000000002	61	1092	4	14	12	6	0	2	6	0	0	9.532004528446173	
i 1	301.25180272108844	0.7575000000000001	68	1092	2	20	13	0	0	-1	0	0	0	2.6910159448670097	
i 1	301.2539659863946	16.9175	66	1092	5	13	8	6	0	1	6	0	0	6.50065446762121	
i 1	301.25757142857145	18.18	61	706	5	15	6	6	0	2	6	0	0	8.125818084526513	
i 1	301.25973469387753	1.5150000000000001	74	706	4	5	14	2	0	-2	2	0	0	6.0038288353252	
i 1	301.26045578231293	1.5150000000000001	68	1092	2	20	5	0	0	0	0	0	0	2.6910159448670097	
i 1	301.26189795918367	18.18	61	706	6	17	10	9	0	2	9	0	0	6.036103259133875	
i 1	301.26189795918367	6.0600000000000005	66	1092	4	14	7	6	0	2	6	0	0	9.532004528446173	
i 1	301.26261904761907	3.0300000000000002	66	706	6	17	16	6	0	2	6	0	0	6.036103259133875	
i 1	301.26261904761907	1.5150000000000001	68	1092	2	24	2	1	0	-1	1	0	0	6.69101594486701	
i 1	301.2640612244898	18.18	66	208	5	16	10	9	5006	1	9	0	0	9.750981701431815	
i 1	301.26550340136055	6.0600000000000005	66	208	5	18	15	6	5006	2	6	0	0	6.036103259133875	
i 1	301.26622448979595	12.120000000000001	66	1092	4	19	16	6	0	2	6	0	0	6.036103259133875	
i 1	301.2669455782313	9.09	61	706	4	13	16	9	0	1	9	0	0	5.957502830278858	
i 1	301.2676666666667	16.9175	66	1092	5	14	1	6	0	1	6	0	0	11.376145318337118	
i 1	301.99387074829934	0.7575000000000001	68	208	4	20	13	0	0	0	0	0	0	2.6910159448670097	
i 1	302.2445918367347	2.2725	74	1092	3	24	1	8	0	-2	8	0	0	3.0	
i 1	302.48521768707485	1.5150000000000001	69	706	4	4	5	1	0	0	1	0	0	11.13301339623682	
i 1	302.7323333333333	0.2525	74	1092	4	5	5	2	0	-2	2	0	0	6.0038288353252	
i 1	302.7359387755102	0.2525	74	1092	4	5	2	8	0	-2	8	0	0	6.0038288353252	
i 1	302.76045578231293	1.01	68	1092	2	20	12	0	0	-1	0	0	0	2.6910159448670097	
i 1	303.01622448979595	1.01	71	208	6	5	3	2	5006	-2	2	0	0	6.0038288353252	
i 1	303.74026530612247	0.505	68	1092	2	24	13	1	0	-1	1	0	0	6.69101594486701	
i 1	303.76622448979595	0.2525	71	706	4	24	5	0	0	0	0	0	0	6.69101594486701	
i 1	303.9823333333333	0.2525	71	1092	2	20	7	1	0	-1	1	0	0	2.6910159448670097	
i 1	304.00108163265304	1.7675	72	1092	6	2	7	0	0	-1	0	0	0	11.13301339623682	
i 1	304.00612925170066	0.2525	68	208	4	20	14	1	5006	0	1	0	0	2.6910159448670097	
i 1	304.00685034013605	0.2525	71	208	4	20	16	0	0	-1	0	0	0	2.6910159448670097	
i 1	304.23521768707485	0.2525	68	208	4	24	14	0	5006	0	0	0	0	6.69101594486701	
i 1	304.2554081632653	13.13	61	1092	5	12	7	6	0	2	6	0	0	9.750981701431815	
i 1	304.2582925170068	15.15	66	706	6	17	11	6	0	2	6	0	0	6.036103259133875	
i 1	304.2582925170068	13.8875	61	1092	5	14	12	6	0	2	6	0	0	9.532004528446173	
i 1	304.26478231292515	3.2825	68	1092	2	20	3	0	0	-1	0	0	0	2.6910159448670097	
i 1	304.51261904761907	2.2725	68	1092	2	24	7	0	0	-1	0	0	0	6.69101594486701	
i 1	305.00180272108844	1.2625	74	1092	4	5	9	2	0	-1	2	0	0	6.0038288353252	
i 1	305.26189795918367	0.505	68	1092	2	20	5	0	0	-1	0	0	0	2.6910159448670097	
i 1	305.74242857142855	1.01	71	208	4	20	3	0	0	-1	0	0	0	2.6910159448670097	
i 1	305.7445918367347	1.2625	72	208	6	9	8	1	5006	-1	1	0	0	10.13301339623682	
i 1	305.7460340136054	1.2625	69	706	4	4	5	1	0	0	1	0	0	11.13301339623682	
i 1	306.26261904761907	0.505	74	1092	4	5	15	2	0	-2	2	0	0	6.0038288353252	
i 1	306.7453129251701	0.2525	68	706	4	20	4	1	0	-1	1	0	0	2.6910159448670097	
i 1	306.7633401360544	1.5150000000000001	74	1092	4	5	2	2	0	-1	2	0	0	6.0038288353252	
i 1	306.9866598639456	1.7675	69	1092	5	3	16	1	0	-1	1	0	0	11.13301339623682	
i 1	306.9953129251701	0.505	68	1092	2	20	15	0	0	0	0	0	0	2.6910159448670097	
i 1	307.01622448979595	1.7675	72	1092	6	2	5	0	0	-1	0	0	0	11.13301339623682	
i 1	307.2453129251701	10.8575	66	1092	5	14	10	6	0	2	6	0	0	9.532004528446173	
i 1	307.25973469387753	10.1	61	1092	5	12	16	6	0	1	6	0	0	9.750981701431815	
i 1	307.2640612244898	12.120000000000001	66	208	5	18	13	6	5006	2	6	0	0	6.036103259133875	
i 1	307.4823333333333	1.01	68	208	4	24	3	0	5006	0	0	0	0	6.69101594486701	
i 1	307.4996394557823	0.505	71	706	4	24	4	1	0	0	1	0	0	6.69101594486701	
i 1	307.76550340136055	0.7575000000000001	68	1092	2	20	9	0	0	-1	0	0	0	2.6910159448670097	
i 1	307.9830544217687	2.2725	71	706	4	24	10	2	0	-1	2	0	0	3.0	
i 1	308.00252380952384	0.505	68	1092	2	24	14	0	0	0	0	0	0	6.69101594486701	
i 1	308.00757142857145	0.505	68	208	1	20	16	1	0	0	1	0	0	2.6910159448670097	
i 1	308.25180272108844	0.2525	74	1092	4	5	6	8	0	-2	8	0	0	6.0038288353252	
i 1	308.2539659863946	0.2525	74	1092	4	5	4	2	0	-2	2	0	0	6.0038288353252	
i 1	308.5003605442177	1.5150000000000001	68	208	4	20	3	1	5006	0	1	0	0	2.6910159448670097	
i 1	308.50973469387753	1.5150000000000001	68	1092	2	20	11	0	0	0	0	0	0	2.6910159448670097	
i 1	308.5169455782313	1.5150000000000001	68	1092	2	24	5	1	0	-1	1	0	0	6.69101594486701	
i 1	308.74387074829934	1.5150000000000001	72	706	5	3	10	0	0	-1	0	0	0	11.13301339623682	
i 1	308.75973469387753	1.5150000000000001	69	1092	4	4	13	0	0	-1	0	0	0	11.13301339623682	
i 1	309.50108163265304	0.7575000000000001	74	1092	4	5	10	8	0	-2	8	0	0	6.0038288353252	
i 1	309.99819727891156	0.2525	68	208	4	24	12	0	5006	0	0	0	0	6.69101594486701	
i 1	310.0032448979592	0.2525	74	706	4	24	6	2	0	-2	2	0	0	6.69101594486701	
i 1	310.2323333333333	1.2625	74	1092	3	24	5	8	0	-2	8	0	0	3.0	
i 1	310.24747619047616	0.2525	74	1092	6	5	7	2	0	-2	2	0	0	6.0038288353252	
i 1	310.24819727891156	0.2525	74	1092	2	5	6	8	0	-2	8	0	0	6.0038288353252	
i 1	310.2532448979592	1.5150000000000001	72	208	6	9	13	0	5006	0	0	0	0	10.13301339623682	
i 1	310.25685034013605	9.09	61	706	5	13	15	9	0	1	9	0	0	5.957502830278858	
i 1	310.2590136054422	9.09	66	208	5	18	10	6	5006	1	6	0	0	6.036103259133875	
i 1	310.2611768707483	1.5150000000000001	72	1092	6	2	2	0	0	-1	0	0	0	11.13301339623682	
i 1	310.4823333333333	1.2625	74	706	4	5	3	2	0	-2	2	0	0	6.0038288353252	
i 1	310.5082925170068	1.2625	71	208	4	5	4	2	5006	-2	2	0	0	6.0038288353252	
i 1	310.5140612244898	1.5150000000000001	68	208	4	24	8	0	5006	0	0	0	0	6.69101594486701	
i 1	310.51622448979595	0.505	74	706	4	24	6	2	0	1	2	0	0	6.69101594486701	
i 1	310.73521768707485	0.2525	74	1092	1	20	10	2	0	-2	2	0	0	2.6910159448670097	
i 1	310.7460340136054	0.2525	68	208	4	20	13	1	5006	0	1	0	0	2.6910159448670097	
i 1	310.9996394557823	0.505	68	1092	2	20	1	0	0	-1	0	0	0	2.6910159448670097	
i 1	311.50612925170066	0.505	74	706	4	24	10	8	0	-2	8	0	0	6.69101594486701	
i 1	311.73810204081633	0.2525	72	208	6	9	6	1	5006	-1	1	0	0	10.13301339623682	
i 1	311.7388231292517	0.505	74	1092	2	5	10	8	0	-2	8	0	0	6.0038288353252	
i 1	311.7445918367347	0.2525	69	706	4	4	6	1	0	0	1	0	0	11.13301339623682	
i 1	311.75252380952384	0.505	74	1092	6	5	2	2	0	-2	2	0	0	6.0038288353252	
i 1	311.98449659863945	1.2625	72	1092	6	2	7	0	0	-1	0	0	0	11.13301339623682	
i 1	312.0032448979592	1.7675	72	208	6	9	1	0	5006	0	0	0	0	10.13301339623682	
i 1	312.01550340136055	1.2625	71	1092	2	24	9	2	0	1	2	0	0	6.69101594486701	
i 1	312.2633401360544	1.01	74	1092	4	5	3	2	0	-1	2	0	0	6.0038288353252	
i 1	312.75252380952384	0.505	68	208	4	20	5	1	5006	0	1	0	0	2.6910159448670097	
i 1	313.23449659863945	0.2525	74	1092	1	20	15	2	0	-2	2	0	0	2.6910159448670097	
i 1	313.23738095238093	0.505	71	706	6	5	6	2	0	-1	2	0	0	6.0038288353252	
i 1	313.24747619047616	4.04	66	1092	4	19	5	6	0	2	6	0	0	6.036103259133875	
i 1	313.2503605442177	4.7975	66	1092	5	17	16	9	0	2	9	0	0	6.036103259133875	
i 1	313.25612925170066	0.505	74	1092	4	24	1	8	0	-2	8	0	0	3.0	
i 1	313.25685034013605	0.505	74	1092	3	5	13	2	0	-1	2	0	0	6.0038288353252	
i 1	313.26478231292515	1.5150000000000001	68	1092	2	24	9	1	0	-1	1	0	0	6.69101594486701	
i 1	313.4909863945578	0.7575000000000001	68	208	4	24	7	0	5006	0	0	0	0	6.69101594486701	
i 1	313.73738095238093	1.2625	72	208	6	9	14	1	5006	-1	1	0	0	10.13301339623682	
i 1	313.75108163265304	1.2625	69	706	4	4	12	1	0	0	1	0	0	11.13301339623682	
i 1	313.7532448979592	0.2525	74	1092	6	5	15	2	0	-2	2	0	0	6.0038288353252	
i 1	313.99314965986395	1.01	74	1092	3	5	14	2	0	-1	2	0	0	6.0038288353252	
i 1	314.01045578231293	1.01	71	706	6	5	16	2	0	-1	2	0	0	6.0038288353252	
i 1	314.24026530612247	2.2725	68	1092	2	20	3	0	0	-1	0	0	0	2.6910159448670097	
i 1	314.26478231292515	2.02	74	1092	2	24	6	2	0	1	2	0	0	6.69101594486701	
i 1	314.49242857142855	1.5150000000000001	74	1092	4	24	5	8	0	-2	8	0	0	3.0	
i 1	314.7330544217687	1.2625	68	208	4	24	1	0	5006	0	0	0	0	6.69101594486701	
i 1	314.98377551020405	1.01	74	1092	6	5	1	2	0	-2	2	0	0	6.0038288353252	
i 1	314.9945918367347	1.01	74	1092	2	5	13	8	0	-2	8	0	0	6.0038288353252	
i 1	315.0003605442177	1.2625	72	1092	6	2	13	0	0	-1	0	0	0	11.13301339623682	
i 1	315.00612925170066	2.2725	69	1092	5	3	6	1	0	-1	1	0	0	11.13301339623682	
i 1	315.98377551020405	0.2525	74	706	4	5	16	2	0	-2	2	0	0	6.0038288353252	
i 1	315.9960340136054	1.2625	71	208	4	5	3	2	5006	-2	2	0	0	6.0038288353252	
i 1	316.0046870748299	0.505	68	1092	2	24	7	1	0	-1	1	0	0	6.69101594486701	
i 1	316.2453129251701	1.01	74	706	6	5	11	2	0	-2	2	0	0	6.0038288353252	
i 1	316.2467551020408	1.7675	66	1092	5	17	13	6	0	2	6	0	0	6.036103259133875	
i 1	316.2539659863946	1.01	66	1092	4	19	14	9	0	2	9	0	0	6.036103259133875	
i 1	316.26622448979595	1.7675	72	1092	6	2	8	0	0	-1	0	0	0	11.13301339623682	
i 1	316.48954421768707	0.2525	71	1092	1	20	12	8	0	1	8	0	0	2.6910159448670097	
i 1	316.49026530612247	1.2625	68	208	4	24	6	0	5006	0	0	0	0	6.69101594486701	
i 1	316.50757142857145	0.2525	68	208	4	20	5	1	5006	0	1	0	0	2.6910159448670097	
i 1	316.5111768707483	0.2525	74	706	1	24	14	2	0	-2	2	0	0	6.69101594486701	
i 1	316.73810204081633	1.01	71	208	1	20	7	8	0	-2	8	0	0	2.6910159448670097	
i 1	316.7460340136054	0.2525	68	1092	2	20	11	0	0	-1	0	0	0	2.6910159448670097	
i 1	316.9888231292517	0.2525	68	1092	2	24	12	1	0	-1	1	0	0	6.69101594486701	
i 1	317.24314965986395	0.7575000000000001	67	4	6	12	4	5	0	1	5	0	0	9.750981701431815	
i 1	317.2496394557823	0.7575000000000001	67	4	6	12	6	0	0	0	0	0	0	9.750981701431815	
i 1	317.26261904761907	0.7575000000000001	67	4	5	19	14	5	0	1	5	0	0	6.036103259133875	
i 1	317.26261904761907	0.7575000000000001	67	4	5	19	3	0	0	1	0	0	0	6.036103259133875	
i 1	317.2633401360544	0.7575000000000001	68	208	4	20	10	1	5006	0	1	0	0	2.6910159448670097	
i 1	317.2669455782313	0.505	74	1092	4	5	15	2	0	-2	2	0	0	6.0038288353252	
i 1	317.7503605442177	0.2525	74	706	6	5	9	2	0	-2	2	0	0	6.0038288353252	
i 1	317.76261904761907	0.2525	71	208	4	5	5	2	5006	-2	2	0	0	6.0038288353252	
i 1	317.76261904761907	0.2525	71	1092	1	20	16	2	0	1	2	0	0	2.6910159448670097	
i 1	317.98377551020405	0.2525	72	208	6	9	7	1	5006	-1	1	0	0	10.13301339623682	
i 1	317.98521768707485	0.2525	71	706	6	5	9	2	0	-1	2	0	0	6.0038288353252	
i 1	317.98521768707485	0.7575000000000001	74	208	3	24	8	2	5006	1	2	0	0	6.69101594486701	
i 1	317.98738095238093	1.2625	67	910	5	14	3	5	5006	0	5	0	0	9.532004528446173	
i 1	317.99026530612247	1.2625	67	910	5	14	5	5	5006	1	5	0	0	9.532004528446173	
i 1	317.9909863945578	0.2525	74	910	6	2	14	17	5006	1	17	0	0	11.13301339623682	
i 1	317.9917074829932	1.2625	67	208	5	19	12	0	5006	1	0	0	0	6.036103259133875	
i 1	317.99314965986395	1.2625	60	208	6	12	3	0	5006	0	0	0	0	9.750981701431815	
i 1	317.99387074829934	1.2625	67	910	5	14	12	5	5006	0	5	0	0	11.376145318337118	
i 1	317.9953129251701	1.2625	60	910	5	17	5	0	5006	1	0	0	0	6.036103259133875	
i 1	317.9967551020408	1.2625	60	208	6	12	3	5	5006	1	5	0	0	9.750981701431815	
i 1	318.00180272108844	0.2525	75	208	3	5	5	2	5006	-2	2	0	0	6.0038288353252	
i 1	318.0046870748299	1.2625	67	910	5	17	4	0	5006	1	0	0	0	6.036103259133875	
i 1	318.0046870748299	0.7575000000000001	74	208	1	20	3	2	5006	-2	2	0	0	2.6910159448670097	
i 1	318.0111768707483	1.2625	67	910	5	13	2	5	5006	0	5	0	0	6.50065446762121	
i 1	318.0111768707483	1.2625	67	208	5	19	4	5	5006	0	5	0	0	6.036103259133875	
i 1	318.25973469387753	1.01	69	706	4	4	13	1	0	0	1	0	0	11.13301339623682	
i 1	318.73377551020405	0.2525	68	208	4	20	10	1	5006	0	1	0	0	2.6910159448670097	
i 1	318.7496394557823	0.2525	68	208	4	24	10	0	5006	0	0	0	0	6.69101594486701	
i 1	318.7546870748299	0.2525	71	208	1	20	4	8	5006	1	8	0	0	2.6910159448670097	
i 1	318.98449659863945	0.2525	74	208	3	24	15	2	5006	1	2	0	0	6.69101594486701	
i 1	318.9888231292517	1.01	71	208	3	20	14	2	5006	-2	2	0	0	2.6910159448670097	
i 1	318.9917074829932	0.2525	74	706	1	24	13	2	0	1	2	0	0	6.69101594486701	
i 1	319.0039659863946	0.2525	74	706	1	20	5	8	0	1	8	0	0	2.6910159448670097	
i 1	319.2330544217687	16.665	60	208	4	27	7	0	5006	0	0	0	0	4.741544081336598	
i 1	319.23377551020405	7.575	68	208	1	24	3	0	5006	0	0	0	0	6.69101594486701	
i 1	319.23738095238093	15.4025	61	706	5	15	4	6	0	2	6	0	0	4.875490850715908	
i 1	319.23954421768707	6.0600000000000005	61	706	5	25	16	6	0	2	6	0	0	4.148851071169524	
i 1	319.24026530612247	16.665	60	208	6	12	11	5	5006	1	5	0	0	6.50065446762121	
i 1	319.2409863945578	3.0300000000000002	61	706	5	25	7	6	0	1	6	0	0	4.148851071169524	
i 1	319.2445918367347	0.2525	77	208	5	4	12	17	5006	2	17	0	0	9.432047472531565	
i 1	319.2460340136054	12.120000000000001	66	208	5	26	3	6	5006	2	6	0	0	4.148851071169524	
i 1	319.24819727891156	15.4025	66	706	5	15	2	6	0	2	6	0	0	4.875490850715908	
i 1	319.24819727891156	16.665	60	208	6	12	15	0	5006	0	0	0	0	6.50065446762121	
i 1	319.2496394557823	9.09	61	208	5	26	5	6	5006	2	6	0	0	4.148851071169524	
i 1	319.2539659863946	16.665	67	910	5	14	3	5	5006	0	5	0	0	8.125818084526513	
i 1	319.2539659863946	3.0300000000000002	67	910	5	25	15	5	5006	0	5	0	0	4.148851071169524	
i 1	319.25612925170066	16.665	66	208	5	16	8	9	5006	1	9	0	0	6.50065446762121	
i 1	319.26045578231293	15.15	67	208	4	27	15	5	5006	0	5	0	0	4.741544081336598	
i 1	319.26261904761907	6.0600000000000005	67	910	5	25	10	0	5006	1	0	0	0	4.148851071169524	
i 1	319.26622448979595	1.01	75	208	3	5	11	2	5006	-2	2	0	0	8.80942960118498	
i 1	319.2669455782313	16.665	61	208	5	16	15	6	5006	1	6	0	0	6.50065446762121	
i 1	319.2676666666667	16.665	67	910	5	13	6	5	5006	0	5	0	0	3.250327233810606	
i 1	319.4953129251701	1.5150000000000001	74	910	6	2	15	17	5006	1	17	0	0	9.432047472531565	
i 1	319.5054081632653	1.5150000000000001	72	208	6	9	11	1	5006	-1	1	0	0	8.432047472531565	
i 1	319.98810204081633	1.01	71	208	1	20	12	2	5006	1	2	0	0	2.6910159448670097	
i 1	320.0140612244898	1.01	74	208	3	24	12	2	5006	1	2	0	0	6.69101594486701	
i 1	320.25685034013605	1.2625	75	910	4	5	9	2	5006	1	2	0	0	8.80942960118498	
i 1	320.26550340136055	1.2625	74	208	4	5	8	2	5006	-2	2	0	0	8.80942960118498	
i 1	320.9967551020408	1.2625	69	706	4	4	7	1	0	0	1	0	0	9.432047472531565	
i 1	321.00612925170066	1.7675	74	208	1	24	12	2	5006	252	2	307	0	6.69101594486701	
i 1	321.01622448979595	1.5150000000000001	71	208	1	20	9	2	5006	1	2	0	0	2.6910159448670097	
i 1	321.5111768707483	2.2725	69	208	5	24	11	0	5006	-1	0	0	0	3.0	
i 1	321.5176666666667	2.2725	71	706	4	24	1	2	0	-1	2	0	0	3.0	
i 1	321.99891836734696	0.2525	74	208	4	5	14	2	5006	-2	2	0	0	8.80942960118498	
i 1	322.2532448979592	0.2525	68	208	1	20	8	1	5006	0	1	0	0	2.6910159448670097	
i 1	322.2546870748299	3.0300000000000002	61	706	5	25	5	6	0	1	6	0	0	4.148851071169524	
i 1	322.25685034013605	6.0600000000000005	67	910	5	25	7	5	5006	0	5	0	0	4.148851071169524	
i 1	322.2582925170068	1.2625	74	208	7	5	10	2	5006	-2	2	0	0	8.80942960118498	
i 1	322.25973469387753	0.2525	69	706	4	4	14	1	0	0	1	0	0	9.432047472531565	
i 1	322.49387074829934	1.7675	72	208	6	9	14	0	5006	0	0	0	0	8.432047472531565	
i 1	322.50685034013605	0.2525	74	910	1	20	15	8	5006	-2	8	0	0	2.6910159448670097	
i 1	322.51045578231293	1.7675	77	910	6	2	7	17	5006	1	17	0	0	9.432047472531565	
i 1	322.74314965986395	0.505	74	208	1	20	11	2	5006	1	2	0	0	2.6910159448670097	
i 1	322.7582925170068	0.505	74	208	3	24	10	2	5006	1	2	0	0	6.69101594486701	
i 1	323.23810204081633	0.2525	74	208	1	20	4	8	5006	-2	8	0	0	2.6910159448670097	
i 1	323.25180272108844	0.2525	68	208	1	20	13	1	5006	0	1	0	0	2.6910159448670097	
i 1	323.4830544217687	1.7675	74	208	3	24	7	2	5006	1	2	0	0	6.69101594486701	
i 1	323.5054081632653	1.7675	74	208	1	20	10	2	5006	1	2	0	0	2.6910159448670097	
i 1	323.5111768707483	0.2525	72	208	3	5	3	2	5006	-2	2	0	0	8.80942960118498	
i 1	324.2330544217687	1.2625	77	208	6	3	14	17	5006	2	17	0	0	9.432047472531565	
i 1	324.2554081632653	1.2625	72	706	5	3	10	0	0	-1	0	0	0	9.432047472531565	
i 1	324.7590136054422	1.01	71	706	4	5	4	2	0	-1	2	0	0	8.80942960118498	
i 1	325.23377551020405	3.0300000000000002	68	208	1	20	4	1	5006	0	1	0	0	2.6910159448670097	
i 1	325.24314965986395	6.0600000000000005	61	706	5	25	6	6	0	1	6	0	0	4.148851071169524	
i 1	325.25252380952384	3.0300000000000002	61	706	5	25	2	6	0	2	6	0	0	4.148851071169524	
i 1	325.2546870748299	0.505	75	208	6	5	13	2	5006	-2	2	0	0	8.80942960118498	
i 1	325.25685034013605	3.0300000000000002	74	208	1	20	3	8	5006	-2	8	0	0	2.6910159448670097	
i 1	325.2633401360544	9.09	67	910	5	25	14	0	5006	1	0	0	0	4.148851071169524	
i 1	325.51045578231293	0.505	72	208	6	9	14	1	5006	-1	1	0	0	8.432047472531565	
i 1	325.74242857142855	1.2625	75	910	4	5	11	2	5006	1	2	0	0	8.80942960118498	
i 1	325.74242857142855	1.2625	74	208	7	5	10	2	5006	-2	2	0	0	8.80942960118498	
i 1	326.01622448979595	1.01	77	208	5	4	7	17	5006	2	17	0	0	9.432047472531565	
i 1	326.7445918367347	0.7575000000000001	74	208	1	20	10	2	5006	1	2	0	0	2.6910159448670097	
i 1	326.98449659863945	3.0300000000000002	72	208	6	9	1	1	5006	-1	1	0	0	8.432047472531565	
i 1	326.9967551020408	0.505	71	706	4	5	4	2	0	-1	2	0	0	8.80942960118498	
i 1	327.0090136054422	0.505	75	208	6	5	11	2	5006	-2	2	0	0	8.80942960118498	
i 1	327.4967551020408	0.505	68	208	1	24	5	0	5006	0	0	0	0	6.69101594486701	
i 1	327.49747619047616	1.5150000000000001	75	910	4	5	14	2	5006	1	2	0	0	8.80942960118498	
i 1	328.2330544217687	3.0300000000000002	61	208	5	26	11	6	5006	2	6	0	0	4.148851071169524	
i 1	328.24026530612247	6.0600000000000005	61	706	5	25	15	6	0	2	6	0	0	4.148851071169524	
i 1	328.24314965986395	0.2525	74	208	1	20	16	2	5006	1	2	0	0	2.6910159448670097	
i 1	328.24819727891156	0.7575000000000001	74	208	4	5	15	2	5006	-2	2	0	0	8.80942960118498	
i 1	328.2546870748299	0.2525	68	208	1	24	8	0	5006	0	0	0	0	6.69101594486701	
i 1	328.25685034013605	7.575	67	910	5	25	14	5	5006	0	5	0	0	4.148851071169524	
i 1	328.5054081632653	0.7575000000000001	74	706	1	24	12	2	0	1	2	0	0	6.69101594486701	
i 1	328.5133401360544	0.7575000000000001	68	208	1	24	13	0	5006	252	0	307	0	6.69101594486701	
i 1	328.9960340136054	0.2525	72	208	6	5	14	2	5006	-2	2	0	0	8.80942960118498	
i 1	329.0032448979592	0.2525	74	706	4	5	16	2	0	-2	2	0	0	8.80942960118498	
i 1	329.2409863945578	1.01	75	910	4	5	12	2	5006	1	2	0	0	8.80942960118498	
i 1	329.24314965986395	1.01	74	208	4	5	5	2	5006	-2	2	0	0	8.80942960118498	
i 1	329.24314965986395	1.5150000000000001	74	208	1	20	14	2	5006	1	2	0	0	2.6910159448670097	
i 1	329.2640612244898	2.2725	68	208	1	24	5	0	5006	0	0	0	0	6.69101594486701	
i 1	329.48738095238093	1.7675	69	208	5	24	4	0	5006	-1	0	0	0	3.0	
i 1	329.9909863945578	0.2525	77	208	5	4	15	17	5006	2	17	0	0	9.432047472531565	
i 1	330.23377551020405	1.7675	77	910	6	2	3	17	5006	1	17	0	0	9.432047472531565	
i 1	330.24819727891156	1.01	74	706	4	5	6	2	0	-2	2	0	0	8.80942960118498	
i 1	330.2539659863946	1.7675	72	208	6	9	15	0	5006	0	0	0	0	8.432047472531565	
i 1	331.00612925170066	0.2525	74	208	1	20	4	2	5006	1	2	0	0	2.6910159448670097	
i 1	331.23738095238093	2.2725	68	208	1	20	13	1	5006	0	1	0	0	2.6910159448670097	
i 1	331.23954421768707	3.2825	61	706	5	25	6	6	0	1	6	0	0	4.148851071169524	
i 1	331.2453129251701	0.505	71	910	1	20	11	2	5006	1	2	0	0	2.6910159448670097	
i 1	331.2633401360544	4.545	61	208	5	26	5	6	5006	2	6	0	0	4.148851071169524	
i 1	331.26550340136055	3.0300000000000002	66	208	5	26	4	6	5006	2	6	0	0	4.148851071169524	
i 1	331.49242857142855	0.2525	74	706	1	24	6	2	0	1	2	0	0	6.69101594486701	
i 1	332.0054081632653	1.01	72	706	5	3	16	0	0	-1	0	0	0	9.432047472531565	
i 1	332.51622448979595	0.505	71	706	4	5	14	2	0	-1	2	0	0	8.80942960118498	
i 1	332.7611768707483	0.2525	68	208	1	24	10	0	5006	0	0	0	0	6.69101594486701	
i 1	332.9859387755102	0.505	74	910	1	20	4	8	5006	-2	8	0	0	2.6910159448670097	
i 1	333.00108163265304	1.5150000000000001	72	208	6	9	3	1	5006	-1	1	0	0	8.432047472531565	
i 1	333.00612925170066	0.7575000000000001	68	208	1	24	8	0	5006	252	0	307	0	6.69101594486701	
i 1	333.00973469387753	1.5150000000000001	74	208	4	5	4	2	5006	-2	2	0	0	8.80942960118498	
i 1	333.0133401360544	1.7675	75	910	4	5	15	2	5006	1	2	0	0	8.80942960118498	
i 1	333.0169455782313	0.505	74	706	1	24	3	2	0	1	2	0	0	6.69101594486701	
i 1	333.4823333333333	0.505	74	208	1	20	9	2	5006	1	2	0	0	2.6910159448670097	
i 1	333.99819727891156	0.2525	74	910	1	20	7	2	5006	1	2	0	0	2.6910159448670097	
i 1	334.01550340136055	0.2525	71	910	1	20	9	8	5006	1	8	0	0	2.6910159448670097	
i 1	334.23954421768707	1.5150000000000001	67	208	4	27	13	5	5006	0	5	0	0	4.741544081336598	
i 1	334.24026530612247	1.5150000000000001	66	208	5	26	1	6	5006	2	6	0	0	4.148851071169524	
i 1	334.24314965986395	0.2525	61	706	5	25	6	6	0	2	6	0	0	4.148851071169524	
i 1	334.2503605442177	0.7575000000000001	74	208	1	20	9	8	5006	-2	8	0	0	3.6093927273451545	
i 1	334.2546870748299	0.7575000000000001	68	208	1	20	10	1	5006	0	1	0	0	3.6093927273451545	
i 1	334.25685034013605	1.5150000000000001	67	910	5	25	6	0	5006	1	0	0	0	4.148851071169524	
i 1	334.4823333333333	0.2525	75	208	3	5	11	2	5006	-2	2	0	0	8.80942960118498	
i 1	334.4888231292517	18.685	67	579	5	15	15	5	5000	0	5	0	0	4.875490850715908	
i 1	334.49819727891156	5.8075	67	579	5	25	1	0	5000	0	0	0	0	4.148851071169524	
i 1	334.5054081632653	18.685	60	579	5	15	3	0	5000	1	0	0	0	4.875490850715908	
i 1	334.51550340136055	8.8375	67	579	5	25	1	0	5000	1	0	0	0	4.148851071169524	
i 1	334.75108163265304	1.01	71	208	4	5	3	2	5006	-2	2	0	0	8.80942960118498	
i 1	334.75180272108844	2.02	75	579	4	5	5	2	5000	1	2	0	0	8.80942960118498	
i 1	334.98377551020405	0.7575000000000001	68	208	1	24	9	0	5006	0	0	0	0	7.6093927273451545	
i 1	335.0039659863946	0.505	74	579	1	24	5	2	5000	1	2	0	0	7.6093927273451545	
i 1	335.49387074829934	0.2525	71	208	1	20	6	2	5006	-2	2	0	0	3.6093927273451545	
i 1	335.7323333333333	16.665	60	1098	5	13	14	5	0	0	5	0	0	3.250327233810606	
i 1	335.7323333333333	4.545	60	1098	4	26	1	0	5001	1	0	0	0	4.148851071169524	
i 1	335.7330544217687	28.785	67	1098	4	16	9	0	5001	0	0	0	0	6.50065446762121	
i 1	335.73810204081633	1.5150000000000001	60	284	4	27	15	0	0	0	0	0	0	4.741544081336598	
i 1	335.74314965986395	16.9175	67	1098	5	25	1	0	0	1	0	0	0	4.148851071169524	
i 1	335.74387074829934	1.5150000000000001	60	1098	4	26	2	5	5001	1	5	0	0	4.148851071169524	
i 1	335.7460340136054	1.5150000000000001	60	284	4	27	8	5	0	1	5	0	0	4.741544081336598	
i 1	335.7467551020408	13.635	67	1098	5	14	1	0	0	1	0	0	0	8.125818084526513	
i 1	335.75180272108844	1.01	75	284	3	5	11	2	0	1	2	0	0	8.80942960118498	
i 1	335.7582925170068	25.755	67	1098	4	16	4	0	5001	1	0	0	0	6.50065446762121	
i 1	335.7611768707483	0.2525	77	579	4	4	16	16	5000	1	16	0	0	9.432047472531565	
i 1	335.76478231292515	16.9175	60	284	6	12	13	0	0	1	0	0	0	6.50065446762121	
i 1	335.76622448979595	1.5150000000000001	60	1098	5	25	10	5	0	0	5	0	0	4.148851071169524	
i 1	335.7669455782313	16.9175	60	284	6	12	16	5	0	1	5	0	0	6.50065446762121	
i 1	336.01045578231293	1.2625	74	1098	4	2	4	17	0	2	17	0	0	9.432047472531565	
i 1	337.24819727891156	15.4025	60	1098	5	25	12	5	0	0	5	0	0	4.148851071169524	
i 1	337.24819727891156	9.09	60	1098	4	26	16	5	5001	1	5	0	0	4.148851071169524	
i 1	337.2640612244898	0.505	74	1098	5	2	8	17	0	2	17	0	0	9.432047472531565	
i 1	337.2640612244898	3.0300000000000002	60	284	4	27	12	5	0	1	5	0	0	4.741544081336598	
i 1	337.26478231292515	6.0600000000000005	60	284	4	27	15	0	0	0	0	0	0	4.741544081336598	
i 1	338.00612925170066	0.505	72	579	4	5	1	2	5000	-2	2	0	0	8.80942960118498	
i 1	338.00685034013605	0.505	75	284	3	5	7	2	0	-2	2	0	0	8.80942960118498	
i 1	338.51189795918367	1.5150000000000001	75	1098	4	5	1	2	0	1	2	0	0	8.80942960118498	
i 1	338.5169455782313	1.5150000000000001	75	1098	3	5	14	2	5001	-2	2	0	0	8.80942960118498	
i 1	338.7417074829932	1.5150000000000001	74	1098	5	9	7	17	5001	2	17	0	0	8.432047472531565	
i 1	339.2366598639456	0.2525	74	1098	1	20	12	8	0	-2	8	0	0	3.6093927273451545	
i 1	339.9960340136054	0.2525	72	579	4	5	7	2	5000	-2	2	0	0	8.80942960118498	
i 1	340.0176666666667	0.2525	75	284	3	5	6	2	0	-2	2	0	0	8.80942960118498	
i 1	340.2330544217687	1.01	75	1098	3	5	3	2	5001	-2	2	0	0	8.80942960118498	
i 1	340.24314965986395	12.8775	67	579	5	25	4	0	5000	0	0	0	0	4.148851071169524	
i 1	340.2453129251701	1.01	75	1098	6	5	12	2	0	1	2	0	0	8.80942960118498	
i 1	340.2546870748299	6.0600000000000005	60	284	4	27	8	5	0	1	5	0	0	4.741544081336598	
i 1	340.2590136054422	9.09	60	1098	4	26	13	0	5001	1	0	0	0	4.148851071169524	
i 1	340.26189795918367	1.5150000000000001	77	579	4	4	1	16	5000	1	16	0	0	9.432047472531565	
i 1	341.25612925170066	1.01	72	1098	3	5	4	2	5001	-2	2	0	0	8.80942960118498	
i 1	341.26045578231293	1.01	75	1098	6	5	11	8	0	1	8	0	0	8.80942960118498	
i 1	341.50685034013605	0.2525	74	1098	1	20	15	8	0	-2	8	0	0	3.6093927273451545	
i 1	341.5133401360544	0.2525	74	579	1	20	12	2	5000	1	2	0	0	3.6093927273451545	
i 1	341.7611768707483	0.2525	74	1098	5	9	1	16	5001	1	16	0	0	8.432047472531565	
i 1	341.99026530612247	1.2625	77	1098	5	2	12	16	0	2	16	0	0	9.432047472531565	
i 1	342.25612925170066	1.2625	75	1098	3	5	5	2	5001	-2	2	0	0	8.80942960118498	
i 1	342.98377551020405	0.2525	72	579	4	24	15	0	5000	0	0	0	0	3.0	
i 1	343.23521768707485	0.2525	74	1098	1	20	6	8	0	-2	8	0	0	3.6093927273451545	
i 1	343.24891836734696	0.505	74	284	5	4	3	16	0	1	16	0	0	9.432047472531565	
i 1	343.2539659863946	9.8475	67	579	5	25	8	0	5000	1	0	0	0	4.148851071169524	
i 1	343.26045578231293	9.09	60	284	4	27	1	0	0	0	0	0	0	4.741544081336598	
i 1	343.2633401360544	0.505	77	579	4	4	16	16	5000	1	16	0	0	9.432047472531565	
i 1	343.26550340136055	0.2525	71	579	1	20	5	2	5000	-2	2	0	0	3.6093927273451545	
i 1	343.4823333333333	0.505	75	284	3	5	7	2	0	1	2	0	0	8.80942960118498	
i 1	343.48810204081633	0.505	75	579	4	5	1	2	5000	1	2	0	0	8.80942960118498	
i 1	343.7366598639456	2.525	74	1098	5	2	10	17	0	2	17	0	0	9.432047472531565	
i 1	343.75180272108844	2.525	74	1098	5	9	4	16	5001	1	16	0	0	8.432047472531565	
i 1	344.98738095238093	0.2525	74	579	1	24	16	8	5000	-2	8	0	0	7.6093927273451545	
i 1	345.0082925170068	0.2525	74	579	1	20	12	2	5000	1	2	0	0	3.6093927273451545	
i 1	345.7323333333333	1.01	75	1098	6	5	15	2	0	1	2	0	0	8.80942960118498	
i 1	345.7388231292517	1.01	75	1098	3	5	14	2	5001	-2	2	0	0	8.80942960118498	
i 1	346.2388231292517	18.18	60	1098	4	26	3	5	5001	1	5	0	0	4.148851071169524	
i 1	346.25252380952384	1.5150000000000001	77	579	5	3	15	16	5000	1	16	0	0	9.432047472531565	
i 1	346.25685034013605	6.3125	60	284	4	27	9	5	0	1	5	0	0	4.741544081336598	
i 1	346.25757142857145	1.5150000000000001	74	284	6	3	10	17	0	1	17	0	0	9.432047472531565	
i 1	346.76478231292515	1.01	72	579	6	5	13	2	5000	-2	2	0	0	8.80942960118498	
i 1	347.73521768707485	1.2625	75	1098	3	5	13	2	5001	-2	2	0	0	8.80942960118498	
i 1	347.75180272108844	0.2525	77	1098	6	2	11	16	0	2	16	0	0	9.432047472531565	
i 1	347.7539659863946	0.2525	74	1098	4	9	2	17	5001	2	17	0	0	8.432047472531565	
i 1	347.7676666666667	1.2625	75	1098	6	5	8	2	0	1	2	0	0	8.80942960118498	
i 1	348.00685034013605	1.2625	77	579	4	4	1	16	5000	1	16	0	0	9.432047472531565	
i 1	348.01550340136055	1.2625	74	284	5	4	9	16	0	1	16	0	0	9.432047472531565	
i 1	349.00757142857145	0.2525	72	1098	3	5	10	2	5001	-2	2	0	0	8.80942960118498	
i 1	349.01189795918367	0.505	75	1098	6	5	10	8	0	1	8	0	0	8.80942960118498	
i 1	349.2323333333333	0.2525	71	1098	2	20	14	2	0	-2	2	0	0	3.6093927273451545	
i 1	349.23810204081633	0.2525	72	1098	5	5	14	2	5001	-2	2	0	0	8.80942960118498	
i 1	349.23954421768707	15.15	60	1098	4	26	3	0	5001	1	0	0	0	4.148851071169524	
i 1	349.2417074829932	0.505	74	1098	4	9	11	16	5001	1	16	0	0	8.432047472531565	
i 1	349.24387074829934	3.2825	67	1098	5	14	15	0	0	1	0	0	0	8.125818084526513	
i 1	349.4917074829932	1.5150000000000001	75	1098	3	5	11	2	5001	-2	2	0	0	8.80942960118498	
i 1	349.50757142857145	0.7575000000000001	71	1098	1	20	10	2	0	-2	2	0	0	3.6093927273451545	
i 1	349.73377551020405	1.01	77	1098	6	2	12	16	0	2	16	0	0	9.432047472531565	
i 1	350.2669455782313	0.505	71	1098	2	20	11	2	0	-2	2	0	0	3.6093927273451545	
i 1	350.74314965986395	1.5150000000000001	74	284	5	4	1	16	0	1	16	0	0	9.432047472531565	
i 1	350.9917074829932	0.2525	75	284	3	5	16	2	0	1	2	0	0	8.80942960118498	
i 1	351.2554081632653	1.01	75	1098	3	5	3	2	5001	-2	2	0	0	8.80942960118498	
i 1	352.24026530612247	0.2525	60	1098	5	13	8	5	0	0	5	0	0	3.250327233810606	
i 1	352.2445918367347	0.2525	74	1098	4	9	7	16	5001	1	16	0	0	8.432047472531565	
i 1	352.2590136054422	0.7575000000000001	72	579	6	5	15	2	5000	-2	2	0	0	8.80942960118498	
i 1	352.2676666666667	0.2525	60	284	4	27	14	0	0	0	0	0	0	4.741544081336598	
i 1	352.4830544217687	11.8675	67	390	3	27	8	0	0	0	0	0	0	4.741544081336598	
i 1	352.48449659863945	11.8675	67	706	5	25	2	0	0	0	0	0	0	4.148851071169524	
i 1	352.48521768707485	11.8675	67	706	5	14	11	0	0	0	0	0	0	8.125818084526513	
i 1	352.48738095238093	11.8675	67	390	5	12	10	5	0	1	5	0	0	6.50065446762121	
i 1	352.48810204081633	2.7775	67	390	3	27	8	5	0	1	5	0	0	4.741544081336598	
i 1	352.5003605442177	11.8675	67	390	5	12	12	5	0	1	5	0	0	6.50065446762121	
i 1	352.5111768707483	1.7675	77	390	3	4	6	16	0	1	16	0	0	9.432047472531565	
i 1	352.5111768707483	11.8675	60	706	5	25	13	0	0	1	0	0	0	4.148851071169524	
i 1	352.51261904761907	11.8675	67	706	5	13	15	0	0	0	0	0	0	3.250327233810606	
i 1	352.9830544217687	2.2725	67	390	5	15	9	5	0	1	5	0	0	4.875490850715908	
i 1	352.9830544217687	11.3625	60	390	5	25	2	5	0	0	5	0	0	4.148851071169524	
i 1	352.98738095238093	11.3625	67	390	5	25	12	0	0	1	0	0	0	4.148851071169524	
i 1	353.00108163265304	5.3025	60	390	5	15	12	5	0	1	5	0	0	4.875490850715908	
i 1	353.0032448979592	1.2625	74	390	4	4	1	16	0	1	16	0	0	9.432047472531565	
i 1	353.0133401360544	0.505	75	706	6	5	15	2	0	1	2	0	0	8.80942960118498	
i 1	353.50685034013605	1.5150000000000001	72	706	6	5	7	2	0	1	2	0	0	8.80942960118498	
i 1	354.23377551020405	0.505	74	390	1	20	7	2	0	-2	2	0	0	3.6093927273451545	
i 1	354.24026530612247	1.2625	72	390	4	24	15	0	0	0	0	0	0	3.0	
i 1	354.24819727891156	1.2625	72	390	3	24	6	0	0	0	0	0	0	3.0	
i 1	354.2611768707483	0.505	77	706	6	2	6	16	0	1	16	0	0	9.432047472531565	
i 1	354.7330544217687	1.01	77	706	6	2	7	17	0	2	17	0	0	9.432047472531565	
i 1	354.76189795918367	0.7575000000000001	74	1098	1	20	7	2	0	-2	2	0	0	3.6093927273451545	
i 1	354.7633401360544	1.01	74	1098	4	9	14	17	5001	2	17	0	0	8.432047472531565	
i 1	354.9917074829932	0.2525	72	390	3	5	9	8	0	1	8	0	0	8.80942960118498	
i 1	355.25252380952384	3.2825	72	706	6	5	8	2	0	1	2	0	0	8.80942960118498	
i 1	355.26045578231293	9.09	67	390	5	15	3	5	0	1	5	0	0	4.875490850715908	
i 1	355.2633401360544	9.09	67	390	3	27	7	5	0	1	5	0	0	4.741544081336598	
i 1	355.4830544217687	0.2525	74	706	2	20	6	2	0	-2	2	0	0	3.6093927273451545	
i 1	355.7539659863946	1.5150000000000001	77	390	4	4	12	16	0	1	16	0	0	9.432047472531565	
i 1	355.7676666666667	1.5150000000000001	74	390	4	4	6	16	0	1	16	0	0	9.432047472531565	
i 1	356.4888231292517	0.2525	74	390	2	20	13	2	0	-2	2	0	0	3.6093927273451545	
i 1	356.7633401360544	2.7775	71	1098	1	20	12	2	0	1	2	0	0	3.6093927273451545	
i 1	357.24242857142855	1.5150000000000001	77	706	6	2	12	16	0	1	16	0	0	9.432047472531565	
i 1	358.26478231292515	6.0600000000000005	60	390	5	15	2	5	0	1	5	0	0	4.875490850715908	
i 1	358.48377551020405	0.505	75	390	5	5	3	2	0	-2	2	0	0	8.80942960118498	
i 1	358.49026530612247	0.505	75	390	6	5	7	8	0	1	8	0	0	8.80942960118498	
i 1	358.7503605442177	0.505	74	1098	5	9	4	17	5001	2	17	0	0	8.432047472531565	
i 1	358.76189795918367	0.505	77	706	5	2	3	17	0	2	17	0	0	9.432047472531565	
i 1	359.00252380952384	1.5150000000000001	72	706	6	5	7	2	0	1	2	0	0	8.80942960118498	
i 1	359.24819727891156	1.2625	77	390	5	3	12	17	0	1	17	0	0	9.432047472531565	
i 1	359.2669455782313	1.2625	77	390	4	3	16	17	0	1	17	0	0	9.432047472531565	
i 1	359.75973469387753	0.505	71	1098	1	20	10	2	0	1	2	0	0	3.6093927273451545	
i 1	360.2554081632653	0.2525	74	706	2	20	8	2	0	-2	2	0	0	3.6093927273451545	
i 1	360.49891836734696	0.505	74	1098	5	9	10	17	5001	2	17	0	0	8.432047472531565	
i 1	360.7417074829932	1.01	75	1098	5	5	4	2	5001	-2	2	0	0	8.80942960118498	
i 1	360.98810204081633	1.01	74	390	4	4	12	16	0	1	16	0	0	9.432047472531565	
i 1	361.00973469387753	1.01	77	390	4	4	4	16	0	1	16	0	0	9.432047472531565	
i 1	361.2388231292517	3.0300000000000002	67	1098	4	16	6	0	5001	1	0	0	0	6.50065446762121	
i 1	361.24891836734696	0.2525	74	390	2	20	15	2	0	-2	2	0	0	3.6093927273451545	
i 1	361.2503605442177	0.2525	74	706	2	20	4	2	0	-2	2	0	0	3.6093927273451545	
i 1	361.74747619047616	0.505	74	1098	1	20	15	2	0	1	2	0	0	3.6093927273451545	
i 1	361.76622448979595	1.01	72	390	5	5	9	8	0	1	8	0	0	8.80942960118498	
i 1	362.01261904761907	1.5150000000000001	74	1098	5	9	13	16	5001	1	16	0	0	8.432047472531565	
i 1	362.2388231292517	0.7575000000000001	72	390	4	24	7	0	0	0	0	0	0	3.0	
i 1	362.7453129251701	1.5150000000000001	75	1098	5	5	5	2	5001	-2	2	0	0	8.80942960118498	
i 1	362.98449659863945	0.2525	74	706	2	20	10	2	0	1	2	0	0	3.6093927273451545	
i 1	363.0054081632653	0.2525	74	706	2	20	4	2	0	-2	2	0	0	3.6093927273451545	
i 1	363.2359387755102	2.525	74	390	1	20	8	2	0	-2	2	0	0	3.6093927273451545	
i 1	363.2496394557823	1.2625	71	1098	1	20	10	2	0	1	2	0	0	3.6093927273451545	
i 1	363.49747619047616	0.7575000000000001	74	1098	5	9	12	17	5001	2	17	0	0	8.432047472531565	
i 1	364.2330544217687	4.7975	60	706	5	25	7	0	0	1	0	0	0	1.1853860203341497	
i 1	364.23377551020405	0.7575000000000001	74	1098	5	9	2	17	5001	2	17	0	0	6.467405886407314	
i 1	364.23449659863945	4.7975	67	1098	4	16	16	0	5001	0	0	0	0	1.6251636169053025	
i 1	364.23521768707485	3.0300000000000002	67	390	5	12	13	5	0	1	5	0	0	1.6251636169053025	
i 1	364.23810204081633	4.7975	60	1098	4	26	5	0	5001	1	0	0	0	1.1853860203341497	
i 1	364.23954421768707	5.555	67	390	3	27	14	5	0	1	5	0	0	1.7780790305012246	
i 1	364.24026530612247	4.7975	60	390	5	25	6	5	0	0	5	0	0	1.1853860203341497	
i 1	364.2409863945578	0.7575000000000001	77	706	5	2	8	17	0	2	17	0	0	7.467405886407314	
i 1	364.24387074829934	5.555	67	390	5	12	3	5	0	1	5	0	0	1.6251636169053025	
i 1	364.24387074829934	4.7975	67	390	5	25	6	0	0	1	0	0	0	1.1853860203341497	
i 1	364.24387074829934	4.7975	60	1098	4	26	9	5	5001	1	5	0	0	1.1853860203341497	
i 1	364.24387074829934	5.555	67	390	3	27	9	0	0	0	0	0	0	1.7780790305012246	
i 1	364.2453129251701	4.7975	67	390	5	13	5	5	0	1	5	0	0	7.149003396334632	
i 1	364.2503605442177	1.7675	75	1098	5	5	6	2	5001	-2	2	0	0	10.020832184089821	
i 1	364.25108163265304	4.7975	67	706	5	14	9	0	0	0	0	0	0	3.250327233810605	
i 1	364.2539659863946	3.0300000000000002	60	706	5	14	13	5	0	0	5	0	0	10.723505094501949	
i 1	364.25612925170066	4.7975	67	1098	4	16	11	0	5001	1	0	0	0	1.6251636169053025	
i 1	364.25757142857145	4.7975	60	706	4	14	2	5	0	0	5	0	0	10.723505094501949	
i 1	364.26261904761907	4.7975	67	706	5	25	15	0	0	0	0	0	0	1.1853860203341497	
i 1	364.51550340136055	1.01	71	1098	1	20	16	2	0	1	2	0	0	3.6093927273451545	
i 1	364.5176666666667	1.01	74	1098	1	20	10	2	5001	1	2	0	0	3.6093927273451545	
i 1	365.00973469387753	0.505	74	390	4	4	4	16	0	1	16	0	0	7.467405886407314	
i 1	365.50973469387753	1.2625	74	1098	5	9	1	16	5001	1	16	0	0	6.467405886407314	
i 1	365.51045578231293	1.2625	77	706	5	2	11	16	0	1	16	0	0	7.467405886407314	
i 1	365.7366598639456	0.2525	71	1098	1	24	7	2	5001	-2	2	0	0	7.6093927273451545	
i 1	365.75612925170066	0.2525	74	390	2	20	5	2	0	-2	2	0	0	3.6093927273451545	
i 1	365.76045578231293	0.2525	71	706	2	20	14	2	0	1	2	0	0	3.6093927273451545	
i 1	365.99026530612247	0.2525	75	390	5	5	9	2	0	-2	2	0	0	10.020832184089821	
i 1	366.00612925170066	1.01	74	1098	1	20	3	2	5001	1	2	0	0	3.6093927273451545	
i 1	366.2330544217687	1.01	75	1098	5	5	9	2	5001	-2	2	0	0	10.020832184089821	
i 1	366.2417074829932	1.01	72	706	5	5	10	2	0	1	2	0	0	10.020832184089821	
i 1	366.7409863945578	0.505	74	390	2	20	7	2	0	-2	2	0	0	3.6093927273451545	
i 1	366.75685034013605	0.505	74	1098	5	9	6	17	5001	2	17	0	0	6.467405886407314	
i 1	366.7582925170068	0.2525	71	706	2	20	5	2	0	1	2	0	0	3.6093927273451545	
i 1	367.00252380952384	0.2525	71	390	2	24	16	2	0	-2	2	0	0	7.6093927273451545	
i 1	367.24026530612247	0.7575000000000001	71	390	1	24	12	2	0	-2	2	0	0	7.6093927273451545	
i 1	367.25252380952384	1.01	72	1098	6	5	9	2	5001	-2	2	0	0	10.020832184089821	
i 1	367.25252380952384	0.7575000000000001	71	1098	1	20	5	2	0	-2	2	0	0	3.6093927273451545	
i 1	367.26045578231293	2.525	67	390	5	12	13	5	0	1	5	0	0	1.6251636169053025	
i 1	367.26189795918367	1.01	77	390	5	3	8	17	0	1	17	0	0	7.467405886407314	
i 1	367.26261904761907	1.7675	60	706	4	14	1	5	0	0	5	0	0	10.723505094501949	
i 1	367.26478231292515	1.01	75	706	4	5	13	2	0	1	2	0	0	10.020832184089821	
i 1	367.99026530612247	0.2525	74	1098	1	20	13	2	5001	1	2	0	0	3.6093927273451545	
i 1	368.2453129251701	0.7575000000000001	74	1098	5	9	14	17	5001	2	17	0	0	6.467405886407314	
i 1	368.25685034013605	0.7575000000000001	71	1098	1	20	5	2	0	-2	2	0	0	3.6093927273451545	
i 1	368.26550340136055	0.7575000000000001	75	1098	6	5	12	2	5001	-2	2	0	0	10.020832184089821	
i 1	368.2669455782313	0.7575000000000001	72	706	5	5	8	2	0	1	2	0	0	10.020832184089821	
i 1	368.73377551020405	0.2525	74	1098	1	20	10	2	5001	1	2	0	0	3.6093927273451545	
i 1	368.7532448979592	0.2525	71	1098	1	20	14	8	0	1	8	0	0	3.6093927273451545	
i 1	368.9823333333333	0.7575000000000001	75	390	5	5	1	2	0	-2	2	0	0	10.020832184089821	
i 1	368.98449659863945	0.7575000000000001	60	390	4	16	15	0	0	0	0	0	0	1.6251636169053025	
i 1	368.98449659863945	1.2625	67	4	6	25	2	0	0	0	0	0	0	1.1853860203341497	
i 1	368.98449659863945	0.7575000000000001	67	390	4	26	8	0	0	0	0	0	0	1.1853860203341497	
i 1	368.9888231292517	0.7575000000000001	60	706	6	7	1	0	0	0	0	0	0	9.532004528446176	
i 1	368.98954421768707	0.2525	71	390	2	20	3	2	0	-2	2	0	0	3.6093927273451545	
i 1	368.99026530612247	1.2625	67	4	5	14	14	5	0	0	5	0	0	10.723505094501949	
i 1	368.9909863945578	1.2625	67	4	6	25	8	0	0	1	0	0	0	1.1853860203341497	
i 1	368.99242857142855	0.7575000000000001	60	706	5	25	14	0	0	0	0	0	0	1.1853860203341497	
i 1	368.9945918367347	0.7575000000000001	67	706	5	25	12	5	0	1	5	0	0	1.1853860203341497	
i 1	368.9960340136054	0.7575000000000001	60	390	4	26	5	5	0	1	5	0	0	1.1853860203341497	
i 1	368.99819727891156	1.2625	67	4	5	14	1	0	0	0	0	0	0	10.723505094501949	
i 1	369.00180272108844	0.7575000000000001	72	4	6	5	7	2	0	-2	2	0	0	10.020832184089821	
i 1	369.00612925170066	0.7575000000000001	60	390	4	16	3	0	0	1	0	0	0	1.6251636169053025	
i 1	369.00757142857145	1.2625	60	4	6	14	14	0	0	1	0	0	0	3.250327233810605	
i 1	369.0133401360544	0.7575000000000001	72	390	3	24	2	0	0	0	0	0	0	3.0	
i 1	369.01550340136055	0.7575000000000001	60	706	5	13	11	5	0	1	5	0	0	7.149003396334632	
i 1	369.01622448979595	0.7575000000000001	77	390	5	3	7	17	0	1	17	0	0	7.467405886407314	
i 1	369.0176666666667	0.7575000000000001	74	4	6	2	16	17	0	1	17	0	0	7.467405886407314	
i 1	369.4888231292517	0.2525	74	706	2	20	7	8	0	-2	8	0	0	3.6093927273451545	
i 1	369.50252380952384	0.2525	71	4	3	20	1	2	0	1	2	0	0	3.6093927273451545	
i 1	369.73521768707485	16.665	60	937	5	25	3	5	5008	0	5	0	0	1.1853860203341497	
i 1	369.74242857142855	26.0075	60	235	5	26	3	5	5012	1	5	0	0	1.1853860203341497	
i 1	369.74747619047616	0.505	60	621	3	27	15	0	0	0	0	0	0	1.7780790305012246	
i 1	369.7503605442177	16.665	60	937	5	25	5	0	5008	1	0	0	0	1.1853860203341497	
i 1	369.75108163265304	0.505	67	621	3	27	14	0	0	1	0	0	0	1.7780790305012246	
i 1	369.75180272108844	3.535	67	937	6	7	8	5	5008	1	5	0	0	9.532004528446176	
i 1	369.75252380952384	26.0075	60	235	5	26	10	5	5012	1	5	0	0	1.1853860203341497	
i 1	369.7532448979592	15.655	60	235	5	16	3	5	5012	1	5	0	0	1.6251636169053025	
i 1	369.7582925170068	12.625	67	235	5	16	1	5	5012	1	5	0	0	1.6251636169053025	
i 1	369.7582925170068	0.505	71	621	1	24	7	2	0	248	2	308	0	7.6093927273451545	
i 1	369.76189795918367	0.505	67	621	5	12	9	0	0	0	0	0	0	1.6251636169053025	
i 1	369.7633401360544	0.2525	72	937	5	5	8	2	5008	1	2	0	0	10.020832184089821	
i 1	369.7640612244898	0.505	67	621	5	12	10	5	0	1	5	0	0	1.6251636169053025	
i 1	369.76622448979595	0.505	67	937	5	13	12	5	5008	1	5	0	0	7.149003396334632	
i 1	369.7676666666667	0.505	77	621	4	4	2	17	0	2	17	0	0	7.467405886407314	
i 1	370.2330544217687	16.9175	67	1109	5	25	4	0	5009	0	0	0	0	1.1853860203341497	
i 1	370.23810204081633	16.9175	67	723	3	27	6	0	5009	1	0	0	0	1.7780790305012246	
i 1	370.23810204081633	16.9175	67	723	3	27	16	5	5009	0	5	0	0	1.7780790305012246	
i 1	370.24387074829934	1.01	72	723	3	24	13	1	5009	-1	1	0	0	3.0	
i 1	370.24891836734696	1.2625	77	1109	5	2	10	17	5009	1	17	0	0	7.467405886407314	
i 1	370.25180272108844	0.2525	74	723	1	20	8	2	5008	1	2	0	0	3.7489262047842917	
i 1	370.25685034013605	6.0600000000000005	67	937	4	13	14	5	5008	1	5	0	0	7.149003396334632	
i 1	370.2590136054422	16.9175	60	723	5	12	13	0	5009	0	0	0	0	1.6251636169053025	
i 1	370.2611768707483	16.9175	60	1109	5	25	8	0	5009	0	0	0	0	1.1853860203341497	
i 1	370.26261904761907	16.9175	60	723	5	12	15	0	5009	1	0	0	0	1.6251636169053025	
i 1	370.2633401360544	16.9175	60	1109	5	14	10	0	5009	0	0	0	0	10.723505094501949	
i 1	370.26478231292515	1.2625	72	1109	4	5	9	2	5009	-2	2	0	0	10.020832184089821	
i 1	370.26478231292515	3.0300000000000002	67	1109	4	14	14	0	5009	1	0	0	0	10.723505094501949	
i 1	370.74387074829934	0.2525	71	235	2	20	9	2	5009	-2	2	0	0	3.7489262047842917	
i 1	370.7640612244898	0.2525	74	235	2	20	2	2	5009	1	2	0	0	3.7489262047842917	
i 1	370.9960340136054	0.505	71	235	2	24	14	2	5012	1	2	0	0	7.748926204784292	
i 1	370.9967551020408	0.505	71	1109	2	20	15	2	5009	1	2	0	0	3.7489262047842917	
i 1	371.48954421768707	3.0300000000000002	71	235	1	24	15	2	5012	252	2	307	0	7.748926204784292	
i 1	371.4960340136054	0.7575000000000001	74	723	1	20	2	2	5009	-2	2	0	0	3.7489262047842917	
i 1	371.49891836734696	1.2625	72	235	7	5	9	2	5012	-2	2	0	0	10.020832184089821	
i 1	371.5039659863946	0.7575000000000001	71	723	1	20	10	2	5008	1	2	0	0	3.7489262047842917	
i 1	371.5046870748299	0.505	77	937	5	3	9	17	5008	1	17	0	0	7.467405886407314	
i 1	371.50612925170066	0.2525	74	235	2	20	1	2	5009	-2	2	0	0	3.7489262047842917	
i 1	371.50973469387753	0.2525	71	235	2	20	3	2	5012	1	2	0	0	3.7489262047842917	
i 1	371.5111768707483	0.505	77	723	4	4	6	16	5009	2	16	0	0	7.467405886407314	
i 1	371.9866598639456	1.5150000000000001	69	937	4	24	11	1	5008	0	1	0	0	3.0	
i 1	371.98810204081633	1.01	74	1109	5	2	1	17	5009	2	17	0	0	7.467405886407314	
i 1	372.2388231292517	0.2525	74	937	2	20	14	2	5008	1	2	0	0	3.7489262047842917	
i 1	372.24314965986395	0.2525	71	235	2	20	8	2	5012	1	2	0	0	3.7489262047842917	
i 1	372.2582925170068	0.2525	71	1109	2	20	5	8	5009	1	8	0	0	3.7489262047842917	
i 1	372.26550340136055	2.525	71	723	1	24	14	2	5009	-2	2	0	0	7.748926204784292	
i 1	372.73449659863945	0.505	72	235	7	5	9	2	5012	-2	2	0	0	10.020832184089821	
i 1	372.7453129251701	0.505	75	1109	4	5	7	2	5009	1	2	0	0	10.020832184089821	
i 1	372.7503605442177	0.2525	71	235	2	20	10	2	5012	1	2	0	0	3.7489262047842917	
i 1	372.98738095238093	0.505	74	937	2	20	15	8	5008	-2	8	0	0	3.7489262047842917	
i 1	373.00973469387753	1.5150000000000001	74	937	4	4	3	16	5008	2	16	0	0	7.467405886407314	
i 1	373.25108163265304	1.7675	72	1109	4	5	11	2	5009	-2	2	0	0	10.020832184089821	
i 1	373.2539659863946	13.8875	67	1109	5	14	13	0	5009	1	0	0	0	10.723505094501949	
i 1	373.48954421768707	0.7575000000000001	74	723	1	20	8	2	5009	-2	2	0	0	3.7489262047842917	
i 1	373.4909863945578	0.7575000000000001	71	723	1	20	13	2	5008	-2	2	0	0	3.7489262047842917	
i 1	374.25108163265304	0.2525	71	235	2	20	2	2	5009	1	2	0	0	3.7489262047842917	
i 1	374.4909863945578	1.5150000000000001	74	723	5	3	12	17	5009	2	17	0	0	7.467405886407314	
i 1	374.4945918367347	1.5150000000000001	74	1109	5	2	9	17	5009	2	17	0	0	7.467405886407314	
i 1	374.49747619047616	0.2525	71	1109	2	20	8	8	5009	-2	8	0	0	3.7489262047842917	
i 1	374.51550340136055	0.505	71	235	2	24	7	2	5012	1	2	0	0	7.748926204784292	
i 1	374.73954421768707	0.2525	71	723	1	20	5	2	5008	1	2	0	0	3.7489262047842917	
i 1	374.7676666666667	0.2525	74	723	1	20	11	2	5009	-2	2	0	0	3.7489262047842917	
i 1	374.99242857142855	1.01	72	937	4	5	2	2	5008	1	2	0	0	10.020832184089821	
i 1	374.99314965986395	0.7575000000000001	74	1109	2	20	5	2	5009	1	2	0	0	3.7489262047842917	
i 1	374.99891836734696	1.2625	69	937	4	24	2	1	5008	0	1	0	0	3.0	
i 1	375.0003605442177	1.01	75	723	6	5	7	2	5009	-2	2	0	0	10.020832184089821	
i 1	375.0003605442177	1.5150000000000001	71	723	1	24	1	2	5009	-2	2	0	0	7.748926204784292	
i 1	375.01622448979595	1.01	71	235	2	20	10	2	5012	1	2	0	0	3.7489262047842917	
i 1	375.7417074829932	0.7575000000000001	74	235	2	20	1	2	5009	-2	2	0	0	3.7489262047842917	
i 1	376.00685034013605	0.7575000000000001	77	1109	5	2	10	17	5009	1	17	0	0	7.467405886407314	
i 1	376.01045578231293	0.7575000000000001	74	235	5	9	1	17	5012	2	17	0	0	6.467405886407314	
i 1	376.2409863945578	10.1	67	937	5	13	3	5	5008	1	5	0	0	7.149003396334632	
i 1	376.4967551020408	0.7575000000000001	71	723	1	24	8	2	5008	-2	2	0	0	7.748926204784292	
i 1	376.5111768707483	0.7575000000000001	71	235	2	20	7	2	5009	1	2	0	0	3.7489262047842917	
i 1	376.5176666666667	0.7575000000000001	71	235	2	24	9	2	5012	1	2	0	0	7.748926204784292	
i 1	376.7417074829932	1.2625	74	235	5	9	4	16	5012	1	16	0	0	6.467405886407314	
i 1	377.2582925170068	1.2625	75	1109	4	5	1	2	5009	1	2	0	0	10.020832184089821	
i 1	377.26550340136055	1.2625	72	235	5	5	5	2	5012	-2	2	0	0	10.020832184089821	
i 1	377.99026530612247	0.505	74	723	4	3	3	17	5009	2	17	0	0	7.467405886407314	
i 1	378.00180272108844	1.5150000000000001	72	723	4	24	3	1	5009	-1	1	0	0	3.0	
i 1	378.4823333333333	0.505	75	723	6	5	2	2	5009	1	2	0	0	10.020832184089821	
i 1	378.5090136054422	0.505	72	1109	4	5	2	2	5009	-2	2	0	0	10.020832184089821	
i 1	378.75108163265304	0.2525	71	235	2	20	14	2	5012	1	2	0	0	3.7489262047842917	
i 1	379.01550340136055	0.2525	72	235	5	5	6	2	5012	-2	2	0	0	10.020832184089821	
i 1	379.2582925170068	1.2625	72	235	4	5	15	2	5012	-2	2	0	0	10.020832184089821	
i 1	379.4866598639456	1.5150000000000001	77	937	5	3	16	17	5008	1	17	0	0	7.467405886407314	
i 1	379.4953129251701	1.01	74	723	1	20	16	2	5008	1	2	0	0	3.7489262047842917	
i 1	379.49891836734696	1.01	71	235	2	20	11	2	5012	1	2	0	0	3.7489262047842917	
i 1	379.5082925170068	1.01	74	235	2	20	5	8	5009	1	8	0	0	3.7489262047842917	
i 1	379.51261904761907	1.01	74	723	1	20	16	2	5009	-2	2	0	0	3.7489262047842917	
i 1	379.75685034013605	1.2625	69	937	4	24	3	1	5008	0	1	0	0	3.0	
i 1	380.5046870748299	0.2525	75	1109	6	5	6	2	5009	1	2	0	0	10.020832184089821	
i 1	380.51189795918367	1.2625	71	723	1	24	5	2	5009	-2	2	0	0	7.748926204784292	
i 1	380.5140612244898	0.2525	72	235	5	5	9	2	5012	-2	2	0	0	10.020832184089821	
i 1	380.7330544217687	1.01	71	723	1	20	10	2	5008	-2	2	0	0	3.7489262047842917	
i 1	380.7359387755102	1.5150000000000001	72	1109	4	5	6	2	5009	-2	2	0	0	10.020832184089821	
i 1	380.74242857142855	1.01	74	723	1	24	10	2	5008	252	2	307	0	7.748926204784292	
i 1	380.75612925170066	1.01	71	235	2	20	8	8	5009	-2	8	0	0	3.7489262047842917	
i 1	380.7640612244898	2.2725	75	723	4	5	10	2	5009	1	2	0	0	10.020832184089821	
i 1	380.99747619047616	1.5150000000000001	74	723	4	3	12	17	5009	2	17	0	0	7.467405886407314	
i 1	381.00685034013605	2.2725	72	723	4	24	13	1	5009	-1	1	0	0	3.0	
i 1	381.0140612244898	1.5150000000000001	74	1109	5	2	11	17	5009	2	17	0	0	7.467405886407314	
i 1	381.7330544217687	0.2525	71	1109	2	20	4	2	5009	1	2	0	0	3.7489262047842917	
i 1	381.76189795918367	0.7575000000000001	71	235	2	20	2	2	5012	1	2	0	0	3.7489262047842917	
i 1	381.9917074829932	0.505	74	723	1	24	10	2	5008	252	2	307	0	7.748926204784292	
i 1	382.0054081632653	0.505	71	235	2	20	16	2	5009	-2	2	0	0	3.7489262047842917	
i 1	382.0111768707483	1.2625	71	723	1	20	10	2	5008	-2	2	0	0	3.7489262047842917	
i 1	382.01189795918367	1.5150000000000001	74	723	1	20	3	2	5009	-2	2	0	0	3.7489262047842917	
i 1	382.0133401360544	0.505	71	235	1	24	3	2	5012	252	2	307	0	7.748926204784292	
i 1	382.2582925170068	0.7575000000000001	72	1109	6	5	6	2	5009	-2	2	0	0	10.020832184089821	
i 1	382.4945918367347	0.7575000000000001	74	723	1	24	1	2	5008	-2	2	0	0	7.748926204784292	
i 1	382.49819727891156	0.7575000000000001	74	235	5	9	5	16	5012	1	16	0	0	6.467405886407314	
i 1	382.51550340136055	0.7575000000000001	71	235	2	24	1	2	5012	1	2	0	0	7.748926204784292	
i 1	382.9830544217687	1.2625	72	937	4	5	3	2	5008	1	2	0	0	10.020832184089821	
i 1	382.99242857142855	1.2625	75	723	4	5	10	2	5009	-2	2	0	0	10.020832184089821	
i 1	383.24819727891156	1.2625	74	723	4	3	1	17	5009	2	17	0	0	7.467405886407314	
i 1	383.2590136054422	2.2725	71	235	2	20	8	2	5012	1	2	0	0	3.7489262047842917	
i 1	383.26550340136055	2.525	71	235	1	24	9	2	5012	248	2	308	0	7.748926204784292	
i 1	383.26622448979595	0.2525	74	1109	2	20	16	8	5009	-2	8	0	0	3.7489262047842917	
i 1	383.5054081632653	2.02	71	235	2	20	13	2	5009	1	2	0	0	3.7489262047842917	
i 1	383.98738095238093	1.5150000000000001	72	723	4	24	3	1	5009	-1	1	0	0	3.0	
i 1	384.25108163265304	0.505	75	723	4	5	14	2	5009	1	2	0	0	10.020832184089821	
i 1	384.2554081632653	0.505	72	1109	6	5	4	2	5009	-2	2	0	0	10.020832184089821	
i 1	384.4888231292517	0.505	74	235	5	9	14	17	5012	2	17	0	0	6.467405886407314	
i 1	384.49747619047616	0.505	77	1109	5	2	9	17	5009	1	17	0	0	7.467405886407314	
i 1	384.7409863945578	0.7575000000000001	74	723	1	20	14	2	5009	-2	2	0	0	3.7489262047842917	
i 1	384.76550340136055	0.505	75	1109	6	5	5	2	5009	1	2	0	0	10.020832184089821	
i 1	385.2582925170068	0.2525	77	1109	5	2	9	17	5009	1	17	0	0	7.467405886407314	
i 1	385.48810204081633	0.2525	74	937	2	20	10	2	5008	1	2	0	0	3.7489262047842917	
i 1	385.5111768707483	1.2625	71	723	1	24	15	2	5009	-2	2	0	0	7.748926204784292	
i 1	385.5176666666667	0.2525	71	1109	2	20	12	2	5009	1	2	0	0	3.7489262047842917	
i 1	385.7323333333333	1.2625	72	723	4	24	12	1	5009	-1	1	0	0	3.0	
i 1	385.7633401360544	0.2525	74	723	1	24	10	8	5008	1	8	0	0	7.748926204784292	
i 1	385.7669455782313	0.7575000000000001	74	235	2	20	5	2	5009	1	2	0	0	3.7489262047842917	
i 1	385.7676666666667	0.2525	71	235	2	24	7	2	5012	1	2	0	0	7.748926204784292	
i 1	385.9859387755102	0.505	71	235	2	20	11	8	5009	-2	8	0	0	3.7489262047842917	
i 1	385.9945918367347	0.2525	74	1109	5	2	2	17	5009	2	17	0	0	7.467405886407314	
i 1	386.01045578231293	1.01	74	723	4	3	6	17	5009	2	17	0	0	7.467405886407314	
i 1	386.2330544217687	1.2625	60	721	5	25	7	5	5011	0	5	0	0	1.1853860203341497	
i 1	386.23377551020405	0.7575000000000001	71	235	2	24	16	2	5012	1	2	0	0	7.748926204784292	
i 1	386.2359387755102	0.505	75	721	4	5	12	2	5011	-2	2	0	0	10.020832184089821	
i 1	386.2366598639456	0.7575000000000001	77	721	5	3	11	17	5011	1	17	0	0	7.467405886407314	
i 1	386.2366598639456	1.2625	67	721	5	13	5	5	5011	1	5	0	0	7.149003396334632	
i 1	386.24314965986395	1.2625	67	721	6	7	3	5	5011	1	5	0	0	9.532004528446176	
i 1	386.24747619047616	1.2625	60	721	5	25	6	5	5011	1	5	0	0	1.1853860203341497	
i 1	386.25685034013605	0.7575000000000001	72	721	4	24	14	0	5011	-1	0	0	0	3.0	
i 1	386.2676666666667	0.505	75	723	4	5	2	2	5009	-2	2	0	0	10.020832184089821	
i 1	386.49026530612247	0.505	75	1109	6	5	13	2	5009	1	2	0	0	10.020832184089821	
i 1	386.49819727891156	0.2525	71	721	2	20	14	2	5011	-2	2	0	0	3.7489262047842917	
i 1	386.5111768707483	0.2525	74	1109	2	20	7	2	5009	-2	2	0	0	3.7489262047842917	
i 1	386.51550340136055	0.505	72	235	4	5	14	2	5012	-2	2	0	0	10.020832184089821	
i 1	386.7359387755102	0.2525	74	723	1	20	5	2	5009	-2	2	0	0	3.7489262047842917	
i 1	386.75973469387753	0.2525	72	1109	6	5	15	2	5009	-2	2	0	0	10.020832184089821	
i 1	386.76261904761907	0.2525	74	723	1	24	3	2	5011	1	2	0	0	7.748926204784292	
i 1	386.9823333333333	8.585	67	228	4	27	2	0	0	0	0	0	0	1.7780790305012246	
i 1	386.98449659863945	16.665	60	930	5	14	1	5	5013	0	5	0	0	10.723505094501949	
i 1	386.98810204081633	16.665	67	930	5	14	10	5	5013	1	5	0	0	10.723505094501949	
i 1	386.9888231292517	0.505	74	228	1	20	9	2	0	-2	2	0	0	3.7489262047842917	
i 1	386.98954421768707	7.3225	67	930	5	25	7	0	5013	0	0	0	0	1.1853860203341497	
i 1	386.9953129251701	0.505	75	228	3	5	13	2	0	-2	2	0	0	10.020832184089821	
i 1	387.00180272108844	8.585	67	228	4	27	10	5	0	0	5	0	0	1.7780790305012246	
i 1	387.0032448979592	0.505	77	721	4	4	1	17	5011	2	17	0	0	7.467405886407314	
i 1	387.00612925170066	1.2625	60	228	5	12	1	5	0	1	5	0	0	1.6251636169053025	
i 1	387.0082925170068	0.505	74	228	1	24	1	2	5011	1	2	0	0	7.748926204784292	
i 1	387.01045578231293	1.7675	74	235	5	9	9	16	5012	1	16	0	0	6.467405886407314	
i 1	387.0169455782313	10.352500000000001	67	930	5	25	10	5	5013	0	5	0	0	1.1853860203341497	
i 1	387.0176666666667	4.2925	67	228	5	12	8	0	0	0	0	0	0	1.6251636169053025	
i 1	387.4888231292517	15.9075	67	614	5	25	9	0	5013	0	0	0	0	1.1853860203341497	
i 1	387.49819727891156	0.2525	71	228	1	20	7	2	5013	1	2	0	0	3.7489262047842917	
i 1	387.5054081632653	12.8775	67	614	5	25	7	0	5013	0	0	0	0	1.1853860203341497	
i 1	387.5111768707483	16.16	60	614	5	13	14	5	5013	0	5	0	0	7.149003396334632	
i 1	387.5111768707483	16.16	67	614	6	7	8	5	5013	1	5	0	0	9.532004528446176	
i 1	387.51261904761907	1.2625	74	930	5	2	1	16	5013	2	16	0	0	7.467405886407314	
i 1	387.51550340136055	1.5150000000000001	72	235	4	5	13	2	5012	-2	2	0	0	10.020832184089821	
i 1	387.7366598639456	0.2525	74	235	5	9	5	17	5012	2	17	0	0	6.467405886407314	
i 1	387.74026530612247	0.2525	74	930	2	20	9	2	5013	1	2	0	0	3.7489262047842917	
i 1	387.7611768707483	0.2525	72	614	6	5	13	8	5013	1	8	0	0	10.020832184089821	
i 1	388.0032448979592	0.7575000000000001	74	228	1	20	16	2	0	-2	2	0	0	3.7489262047842917	
i 1	388.01478231292515	3.7875	71	235	2	24	11	2	5012	1	2	0	0	7.748926204784292	
i 1	388.2388231292517	0.7575000000000001	72	930	6	5	3	2	5013	1	2	0	0	10.020832184089821	
i 1	388.4888231292517	1.01	72	930	6	5	5	8	5013	-2	8	0	0	10.020832184089821	
i 1	388.49026530612247	0.2525	69	614	4	24	6	0	5013	-1	0	0	0	3.0	
i 1	388.49026530612247	0.2525	71	228	1	20	16	2	5013	-2	2	0	0	3.7489262047842917	
i 1	388.75252380952384	0.505	77	614	4	4	3	16	5013	2	16	0	0	7.467405886407314	
i 1	388.75757142857145	0.505	74	228	4	4	5	17	0	2	17	0	0	7.467405886407314	
i 1	389.0032448979592	0.2525	72	614	6	5	14	8	5013	1	8	0	0	10.020832184089821	
i 1	389.2388231292517	1.2625	74	235	5	9	5	17	5012	2	17	0	0	6.467405886407314	
i 1	389.2409863945578	1.2625	77	930	5	2	2	17	5013	1	17	0	0	7.467405886407314	
i 1	389.2590136054422	1.7675	72	930	6	5	8	2	5013	1	2	0	0	10.020832184089821	
i 1	389.74387074829934	0.2525	72	614	6	5	3	8	5013	1	8	0	0	10.020832184089821	
i 1	389.7467551020408	0.2525	74	930	5	2	14	16	5013	2	16	0	0	7.467405886407314	
i 1	389.99242857142855	0.2525	75	228	3	5	10	2	0	1	2	0	0	10.020832184089821	
i 1	390.2460340136054	1.01	74	930	5	2	14	16	5013	2	16	0	0	7.467405886407314	
i 1	390.51550340136055	0.2525	74	228	4	4	9	17	0	2	17	0	0	7.467405886407314	
i 1	390.7366598639456	1.5150000000000001	72	930	6	5	8	8	5013	-2	8	0	0	10.020832184089821	
i 1	390.7460340136054	0.505	72	235	4	5	7	2	5012	-2	2	0	0	10.020832184089821	
i 1	390.74819727891156	0.2525	74	228	4	3	1	16	0	2	16	0	0	7.467405886407314	
i 1	391.2388231292517	0.2525	72	235	4	5	8	2	5012	-2	2	0	0	10.020832184089821	
i 1	391.2445918367347	0.505	74	235	2	20	16	2	5013	-2	2	0	0	3.7489262047842917	
i 1	391.26189795918367	1.01	72	235	6	5	16	2	5012	-2	2	0	0	10.020832184089821	
i 1	391.4830544217687	2.7775	74	228	4	3	4	16	0	2	16	0	0	7.467405886407314	
i 1	391.4996394557823	0.505	74	228	1	24	7	2	5013	-2	2	0	0	7.748926204784292	
i 1	391.51045578231293	0.505	74	228	1	20	5	2	0	-2	2	0	0	3.7489262047842917	
i 1	391.5111768707483	1.01	74	228	1	24	9	8	0	1	8	0	0	7.748926204784292	
i 1	391.51622448979595	0.505	71	228	1	20	7	2	5013	-2	2	0	0	3.7489262047842917	
i 1	391.7330544217687	0.2525	72	614	6	5	3	8	5013	1	8	0	0	10.020832184089821	
i 1	391.73954421768707	2.525	77	614	5	3	15	17	5013	2	17	0	0	7.467405886407314	
i 1	391.9866598639456	0.2525	74	228	4	4	4	17	0	2	17	0	0	7.467405886407314	
i 1	391.9866598639456	0.2525	71	930	2	20	15	8	5013	-2	8	0	0	3.7489262047842917	
i 1	392.0039659863946	0.2525	71	614	2	24	14	2	5013	1	2	0	0	7.748926204784292	
i 1	392.01550340136055	2.7775	72	930	6	5	13	2	5013	1	2	0	0	10.020832184089821	
i 1	392.24891836734696	1.2625	71	235	2	20	7	2	5013	-2	2	0	0	3.7489262047842917	
i 1	392.25180272108844	0.2525	72	614	6	5	12	8	5013	1	8	0	0	10.020832184089821	
i 1	392.48954421768707	1.01	74	228	1	24	12	8	5013	248	8	308	0	7.748926204784292	
i 1	392.4909863945578	0.2525	77	614	4	4	2	16	5013	2	16	0	0	7.467405886407314	
i 1	393.2409863945578	0.505	74	228	1	20	6	2	0	-2	2	0	0	3.7489262047842917	
i 1	393.2460340136054	0.2525	72	930	6	5	15	8	5013	-2	8	0	0	10.020832184089821	
i 1	393.49026530612247	0.2525	69	228	5	24	13	0	0	0	0	0	0	3.0	
i 1	393.50180272108844	0.2525	74	930	6	2	12	16	5013	2	16	0	0	7.467405886407314	
i 1	393.50757142857145	0.2525	71	614	2	20	5	8	5013	1	8	0	0	3.7489262047842917	
i 1	393.5090136054422	0.2525	74	930	2	20	6	2	5013	-2	2	0	0	3.7489262047842917	
i 1	393.75108163265304	0.505	74	228	1	20	9	2	5013	-2	2	0	0	3.7489262047842917	
i 1	393.98377551020405	1.5150000000000001	74	228	1	20	7	2	0	-2	2	0	0	3.7489262047842917	
i 1	393.9917074829932	0.2525	72	930	6	5	8	8	5013	-2	8	0	0	10.020832184089821	
i 1	394.00180272108844	1.5150000000000001	77	614	4	4	12	16	5013	2	16	0	0	7.467405886407314	
i 1	394.01550340136055	0.505	74	228	1	24	8	2	5013	-2	2	0	0	7.748926204784292	
i 1	394.23954421768707	1.2625	69	228	5	24	7	0	0	0	0	0	0	3.0	
i 1	394.24026530612247	9.09	67	930	5	25	13	0	5013	0	0	0	0	1.1853860203341497	
i 1	394.2467551020408	0.505	72	235	6	5	10	2	5012	-2	2	0	0	10.020832184089821	
i 1	394.25612925170066	1.01	75	228	3	5	2	2	0	-2	2	0	0	10.020832184089821	
i 1	394.25973469387753	2.02	69	614	4	24	16	0	5013	-1	0	0	0	3.0	
i 1	394.48377551020405	0.7575000000000001	74	228	1	24	4	8	0	1	8	0	0	7.748926204784292	
i 1	394.5046870748299	0.2525	74	930	2	20	12	2	5013	-2	2	0	0	3.7489262047842917	
i 1	394.5169455782313	0.7575000000000001	71	235	2	24	12	2	5012	1	2	0	0	7.748926204784292	
i 1	394.74387074829934	0.2525	72	930	6	5	10	8	5013	-2	8	0	0	10.020832184089821	
i 1	394.7640612244898	0.2525	71	235	2	20	10	2	5013	1	2	0	0	3.7489262047842917	
i 1	394.9859387755102	0.505	72	235	6	5	13	2	5012	-2	2	0	0	10.020832184089821	
i 1	394.99891836734696	1.01	77	930	6	2	2	17	5013	1	17	0	0	7.467405886407314	
i 1	395.01478231292515	3.0300000000000002	72	930	6	5	15	2	5013	1	2	0	0	10.020832184089821	
i 1	395.25612925170066	0.2525	74	235	2	20	6	2	5013	-2	2	0	0	3.7489262047842917	
i 1	395.4830544217687	0.505	72	228	5	24	7	1	0	0	1	0	0	3.0	
i 1	395.48810204081633	1.01	71	1197	2	20	14	2	5013	1	2	0	0	3.7489262047842917	
i 1	395.49387074829934	0.505	74	1197	5	9	6	16	0	1	16	0	0	6.467405886407314	
i 1	395.4953129251701	2.525	72	1197	6	5	14	2	0	1	2	0	0	10.020832184089821	
i 1	395.50108163265304	8.08	67	228	4	27	4	5	0	1	5	0	0	1.7780790305012246	
i 1	395.50180272108844	8.08	67	1197	4	26	1	0	0	0	0	0	0	1.1853860203341497	
i 1	395.5039659863946	8.08	67	228	4	27	5	0	0	1	0	0	0	1.7780790305012246	
i 1	395.50612925170066	1.5150000000000001	71	1197	2	20	2	8	0	1	8	0	0	3.7489262047842917	
i 1	395.50757142857145	8.08	67	1197	4	26	10	5	0	0	5	0	0	1.1853860203341497	
i 1	395.5111768707483	1.01	71	228	1	24	8	8	0	-2	8	0	0	7.748926204784292	
i 1	395.5111768707483	0.2525	74	228	1	20	7	8	0	1	8	0	0	3.7489262047842917	
i 1	395.51189795918367	1.7675	74	1197	1	24	5	8	0	248	8	308	0	7.748926204784292	
i 1	395.5169455782313	0.2525	74	228	1	24	6	2	5013	-2	2	0	0	7.748926204784292	
i 1	395.98521768707485	1.5150000000000001	74	228	1	20	14	8	0	1	8	0	0	3.7489262047842917	
i 1	396.01622448979595	0.2525	74	228	4	4	14	16	0	2	16	0	0	7.467405886407314	
i 1	396.24387074829934	0.7575000000000001	72	930	6	5	15	8	5013	-2	8	0	0	10.020832184089821	
i 1	396.25685034013605	0.7575000000000001	72	1197	6	5	3	8	0	1	8	0	0	10.020832184089821	
i 1	396.5140612244898	2.02	77	614	4	4	6	16	5013	2	16	0	0	7.467405886407314	
i 1	396.73954421768707	4.545	71	228	1	24	9	8	0	-2	8	0	0	7.748926204784292	
i 1	396.7554081632653	0.2525	74	930	2	20	6	2	5013	-2	2	0	0	3.7489262047842917	
i 1	396.75973469387753	0.7575000000000001	74	614	2	20	12	8	5013	1	8	0	0	3.7489262047842917	
i 1	396.76189795918367	0.7575000000000001	74	614	2	24	4	2	5013	-2	2	0	0	7.748926204784292	
i 1	397.24026530612247	0.2525	72	930	6	5	7	8	5013	-2	8	0	0	10.020832184089821	
i 1	397.25108163265304	6.3125	67	930	5	25	8	5	5013	0	5	0	0	1.1853860203341497	
i 1	397.25252380952384	0.2525	74	930	2	20	16	8	5013	-2	8	0	0	3.7489262047842917	
i 1	397.25973469387753	0.7575000000000001	74	1197	2	24	11	8	0	1	8	0	0	7.748926204784292	
i 1	397.5032448979592	1.7675	72	614	6	5	3	8	5013	1	8	0	0	10.020832184089821	
i 1	397.5046870748299	1.01	71	1197	2	20	11	2	5013	1	2	0	0	3.7489262047842917	
i 1	397.5090136054422	0.505	74	228	1	24	15	2	5013	1	2	0	0	7.748926204784292	
i 1	397.7445918367347	0.7575000000000001	71	1197	4	20	7	2	5013	1	2	0	0	3.7489262047842917	
i 1	397.75973469387753	2.525	77	930	6	2	5	17	5013	1	17	0	0	7.467405886407314	
i 1	397.7611768707483	1.01	71	1197	2	20	4	8	0	1	8	0	0	3.7489262047842917	
i 1	397.98377551020405	0.2525	72	1197	6	5	4	8	0	1	8	0	0	10.020832184089821	
i 1	398.2467551020408	0.2525	71	228	1	20	13	2	5013	1	2	0	0	3.7489262047842917	
i 1	398.25252380952384	0.505	72	614	6	5	12	8	5013	1	8	0	0	10.020832184089821	
i 1	398.2539659863946	2.02	72	228	5	24	3	1	0	0	1	0	0	3.0	
i 1	398.26045578231293	2.2725	69	614	4	24	12	0	5013	-1	0	0	0	3.0	
i 1	398.4909863945578	0.7575000000000001	74	614	2	20	15	2	5013	1	2	0	0	3.7489262047842917	
i 1	398.49314965986395	0.7575000000000001	77	614	5	3	3	17	5013	2	17	0	0	7.467405886407314	
i 1	398.51478231292515	0.505	71	930	4	20	7	2	5013	-2	2	0	0	3.7489262047842917	
i 1	398.7359387755102	1.7675	72	1197	6	5	16	8	0	1	8	0	0	10.020832184089821	
i 1	398.7676666666667	1.7675	72	930	6	5	3	8	5013	-2	8	0	0	10.020832184089821	
i 1	399.00180272108844	3.0300000000000002	74	228	1	20	13	8	0	1	8	0	0	3.7489262047842917	
i 1	399.2554081632653	1.01	74	1197	2	20	7	2	5013	-2	2	0	0	3.7489262047842917	
i 1	399.25973469387753	0.2525	72	930	6	5	16	2	5013	1	2	0	0	10.020832184089821	
i 1	399.4909863945578	1.2625	74	930	6	2	9	16	5013	2	16	0	0	7.467405886407314	
i 1	399.50252380952384	0.2525	72	614	6	5	7	8	5013	1	8	0	0	10.020832184089821	
i 1	399.51550340136055	1.2625	74	1197	5	9	4	16	0	1	16	0	0	6.467405886407314	
i 1	399.75757142857145	0.505	72	1197	6	5	8	2	0	1	2	0	0	10.020832184089821	
i 1	400.23449659863945	2.2725	77	228	4	3	13	16	0	1	16	0	0	7.467405886407314	
i 1	400.23810204081633	3.2825	72	1197	6	5	8	2	0	1	2	0	0	10.020832184089821	
i 1	400.2445918367347	0.2525	74	1197	4	20	14	2	5013	-2	2	0	0	3.7489262047842917	
i 1	400.24819727891156	0.2525	72	228	3	24	4	1	0	0	1	0	0	3.0	
i 1	400.24819727891156	3.2825	67	614	5	25	16	0	5013	0	0	0	0	1.1853860203341497	
i 1	400.25612925170066	3.0300000000000002	71	1197	2	20	13	8	0	1	8	0	0	3.7489262047842917	
i 1	400.2669455782313	3.0300000000000002	60	930	5	14	4	5	5013	1	5	0	0	3.250327233810605	
i 1	400.49387074829934	0.505	72	614	6	5	12	8	5013	1	8	0	0	10.020832184089821	
i 1	400.5176666666667	0.2525	74	614	2	20	13	8	5013	-2	8	0	0	3.7489262047842917	
i 1	400.7330544217687	0.505	71	1197	4	20	6	2	5013	1	2	0	0	3.7489262047842917	
i 1	400.74747619047616	0.2525	74	1197	5	9	8	16	0	1	16	0	0	6.467405886407314	
i 1	401.01478231292515	0.2525	72	614	6	5	4	8	5013	1	8	0	0	10.020832184089821	
i 1	401.26622448979595	0.2525	75	228	5	5	9	2	0	1	2	0	0	10.020832184089821	
i 1	401.4830544217687	0.505	72	614	6	5	5	8	5013	1	8	0	0	10.020832184089821	
i 1	401.7417074829932	1.5150000000000001	69	614	4	24	15	0	5013	-1	0	0	0	3.0	
i 1	401.7417074829932	0.2525	74	614	2	20	10	2	5013	1	2	0	0	3.7489262047842917	
i 1	401.7633401360544	1.7675	74	228	4	4	9	16	0	2	16	0	0	7.467405886407314	
i 1	401.76478231292515	0.2525	71	930	4	20	3	2	5013	1	2	0	0	3.7489262047842917	
i 1	402.0054081632653	1.5150000000000001	77	614	4	4	15	16	5013	2	16	0	0	7.467405886407314	
i 1	402.4866598639456	0.505	71	614	2	20	9	2	5013	1	2	0	0	3.7489262047842917	
i 1	402.49819727891156	0.505	71	930	4	20	3	8	5013	-2	8	0	0	3.7489262047842917	
i 1	402.9859387755102	0.2525	74	1197	4	20	15	2	5013	1	2	0	0	3.7489262047842917	
i 1	403.23377551020405	0.2525	74	1197	5	9	8	16	0	1	16	0	0	6.467405886407314	
i 1	403.23738095238093	0.2525	67	614	5	25	13	0	5013	0	0	0	0	1.1853860203341497	
i 1	403.2417074829932	0.2525	67	930	5	25	12	0	5013	0	0	0	0	1.1853860203341497	
i 1	403.24819727891156	0.2525	69	614	4	24	13	0	5013	-1	0	0	0	3.0	
i 1	403.2546870748299	0.2525	60	930	5	14	14	5	5013	1	5	0	0	3.250327233810605	
i 1	403.2676666666667	0.2525	74	228	3	20	5	2	5013	1	2	0	0	3.7489262047842917	
i 1	403.48377551020405	2.02	74	400	1	20	15	2	5016	-2	2	0	0	3.7489262047842917	
i 1	403.4859387755102	5.8075	67	716	5	25	8	5	0	0	5	0	0	1.1853860203341497	
i 1	403.4866598639456	5.8075	67	716	6	7	8	0	0	1	0	0	0	9.532004528446176	
i 1	403.48810204081633	2.7775	67	716	5	25	12	0	5016	1	0	0	0	1.1853860203341497	
i 1	403.48954421768707	1.7675	74	716	4	4	4	17	0	1	17	0	0	7.467405886407314	
i 1	403.48954421768707	5.8075	60	716	5	25	12	5	0	0	5	0	0	1.1853860203341497	
i 1	403.49026530612247	0.2525	74	1102	4	9	5	16	0	1	16	0	0	6.467405886407314	
i 1	403.4917074829932	0.7575000000000001	67	1102	4	26	14	0	0	0	0	0	0	1.1853860203341497	
i 1	403.4917074829932	5.8075	67	716	5	14	1	5	5016	0	5	0	0	10.723505094501949	
i 1	403.49242857142855	0.505	74	400	1	24	6	2	0	-2	2	0	0	7.748926204784292	
i 1	403.4953129251701	0.2525	71	1102	1	24	5	8	0	1	8	0	0	7.748926204784292	
i 1	403.49819727891156	0.7575000000000001	67	1102	4	26	2	0	0	1	0	0	0	1.1853860203341497	
i 1	403.50180272108844	1.5150000000000001	75	400	6	5	16	2	5016	1	2	0	0	10.020832184089821	
i 1	403.50252380952384	5.8075	67	400	3	27	3	0	5016	1	0	0	0	1.7780790305012246	
i 1	403.5032448979592	0.505	74	1102	3	20	6	2	5016	1	2	0	0	3.7489262047842917	
i 1	403.5039659863946	5.8075	60	716	5	14	5	5	5016	1	5	0	0	10.723505094501949	
i 1	403.5046870748299	2.7775	74	400	1	24	15	8	5016	-2	8	0	0	7.748926204784292	
i 1	403.5046870748299	5.8075	67	716	5	13	13	0	0	1	0	0	0	7.149003396334632	
i 1	403.50757142857145	5.8075	60	400	3	27	16	5	5016	0	5	0	0	1.7780790305012246	
i 1	403.5082925170068	1.5150000000000001	72	716	6	5	8	2	5016	-2	2	0	0	10.020832184089821	
i 1	403.5090136054422	5.8075	60	716	5	14	3	0	5016	0	0	0	0	3.250327233810605	
i 1	403.5140612244898	5.8075	67	716	5	25	16	0	5016	1	0	0	0	1.1853860203341497	
i 1	403.51550340136055	0.7575000000000001	74	1102	1	20	8	2	0	-2	2	0	0	3.7489262047842917	
i 1	403.7388231292517	0.505	69	400	3	24	1	0	5016	-1	0	0	0	3.0	
i 1	403.99026530612247	0.2525	71	716	4	20	13	2	5016	1	2	0	0	3.7489262047842917	
i 1	403.99387074829934	0.2525	71	716	2	24	9	2	0	1	2	0	0	7.748926204784292	
i 1	404.00685034013605	0.2525	74	716	4	20	7	8	0	-2	8	0	0	3.7489262047842917	
i 1	404.2359387755102	1.2625	74	400	3	20	14	2	0	-2	2	0	0	3.7489262047842917	
i 1	404.2417074829932	0.505	67	898	4	26	12	5	0	0	5	0	0	1.1853860203341497	
i 1	404.2467551020408	0.2525	75	898	6	5	13	8	0	1	8	0	0	10.020832184089821	
i 1	404.25757142857145	1.2625	74	400	1	24	2	8	0	-2	8	0	0	7.748926204784292	
i 1	404.26189795918367	0.505	71	898	3	20	10	2	5016	1	2	0	0	3.7489262047842917	
i 1	404.26550340136055	0.505	67	898	4	26	11	0	0	0	0	0	0	1.1853860203341497	
i 1	404.48377551020405	0.2525	77	716	6	2	13	16	5016	1	16	0	0	7.467405886407314	
i 1	404.48377551020405	1.7675	75	716	6	5	16	8	0	1	8	0	0	10.020832184089821	
i 1	404.4866598639456	1.7675	75	400	5	5	10	2	5016	-2	2	0	0	10.020832184089821	
i 1	404.7417074829932	0.7575000000000001	74	1102	5	9	5	16	0	2	16	0	0	6.467405886407314	
i 1	404.74314965986395	1.5150000000000001	60	1102	4	26	5	0	0	0	0	0	0	1.1853860203341497	
i 1	404.7445918367347	1.2625	77	400	4	3	2	16	5016	1	16	0	0	7.467405886407314	
i 1	404.7453129251701	4.545	67	1102	4	26	5	0	0	0	0	0	0	1.1853860203341497	
i 1	404.7539659863946	0.7575000000000001	71	1102	3	20	6	2	5016	1	2	0	0	3.7489262047842917	
i 1	405.0046870748299	0.505	72	716	4	5	8	2	5016	1	2	0	0	10.020832184089821	
i 1	405.48738095238093	0.505	74	716	4	20	11	8	5016	-2	8	0	0	3.7489262047842917	
i 1	405.48954421768707	0.7575000000000001	74	1102	4	9	10	17	0	1	17	0	0	6.467405886407314	
i 1	405.5054081632653	0.505	74	716	4	20	3	2	0	1	2	0	0	3.7489262047842917	
i 1	405.51045578231293	1.7675	77	716	6	2	4	16	5016	1	16	0	0	7.467405886407314	
i 1	405.51189795918367	0.2525	75	1102	6	5	2	2	0	1	2	0	0	10.020832184089821	
i 1	405.74242857142855	1.01	72	716	4	5	7	2	5016	1	2	0	0	10.020832184089821	
i 1	405.7453129251701	3.535	74	400	1	20	12	2	5016	-2	2	0	0	3.7489262047842917	
i 1	405.76478231292515	1.01	72	1102	6	5	10	2	0	-2	2	0	0	10.020832184089821	
i 1	405.9866598639456	0.2525	74	1102	3	20	6	2	5016	-2	2	0	0	3.7489262047842917	
i 1	406.00757142857145	2.02	74	400	3	20	9	8	0	1	8	0	0	3.7489262047842917	
i 1	406.2323333333333	3.0300000000000002	60	1102	4	26	15	0	0	0	0	0	0	1.1853860203341497	
i 1	406.23521768707485	3.0300000000000002	67	716	5	25	4	0	5016	1	0	0	0	1.1853860203341497	
i 1	406.2366598639456	2.2725	75	400	6	5	11	2	5016	1	2	0	0	10.020832184089821	
i 1	406.24314965986395	1.01	74	1102	5	9	6	17	0	1	17	0	0	6.467405886407314	
i 1	406.2445918367347	2.2725	72	716	4	5	7	2	5016	-2	2	0	0	10.020832184089821	
i 1	406.2539659863946	0.2525	77	716	5	3	12	17	0	1	17	0	0	7.467405886407314	
i 1	406.2582925170068	0.2525	74	1102	3	20	1	2	5016	1	2	0	0	3.7489262047842917	
i 1	406.4823333333333	2.02	69	400	3	24	4	0	5016	-1	0	0	0	3.0	
i 1	406.5054081632653	0.505	74	1102	1	20	1	2	0	-2	2	0	0	3.7489262047842917	
i 1	406.51550340136055	0.2525	77	400	4	3	15	16	5016	1	16	0	0	7.467405886407314	
i 1	406.73521768707485	0.2525	75	400	6	5	7	2	5016	-2	2	0	0	10.020832184089821	
i 1	406.75612925170066	2.02	77	400	4	4	6	17	5016	1	17	0	0	7.467405886407314	
i 1	407.0003605442177	1.01	71	1102	1	24	6	2	0	-2	2	0	0	7.748926204784292	
i 1	407.00757142857145	0.2525	72	1102	6	5	2	2	0	-2	2	0	0	10.020832184089821	
i 1	407.4830544217687	0.505	74	1102	3	20	4	2	5016	-2	2	0	0	3.7489262047842917	
i 1	407.5090136054422	0.2525	74	1102	5	9	16	17	0	1	17	0	0	6.467405886407314	
i 1	407.5176666666667	1.7675	74	400	1	24	7	8	5016	-2	8	0	0	7.748926204784292	
i 1	407.7633401360544	0.2525	75	1102	6	5	3	2	0	1	2	0	0	10.020832184089821	
i 1	407.7633401360544	0.7575000000000001	74	1102	1	20	6	2	0	-2	2	0	0	3.7489262047842917	
i 1	407.98449659863945	0.2525	74	716	4	20	6	8	0	1	8	0	0	3.7489262047842917	
i 1	407.99026530612247	1.2625	74	1102	5	9	10	16	0	2	16	0	0	6.467405886407314	
i 1	407.99314965986395	1.2625	72	716	4	24	10	1	0	0	1	0	0	3.0	
i 1	408.0046870748299	1.2625	75	400	6	5	14	2	5016	-2	2	0	0	10.020832184089821	
i 1	408.00757142857145	1.2625	75	716	6	5	8	8	0	1	8	0	0	10.020832184089821	
i 1	408.2388231292517	0.7575000000000001	74	400	3	24	10	2	0	1	2	0	0	7.748926204784292	
i 1	408.2554081632653	1.01	71	1102	1	24	9	2	0	-2	2	0	0	7.748926204784292	
i 1	408.25757142857145	0.7575000000000001	71	1102	3	20	7	2	5016	-2	2	0	0	3.7489262047842917	
i 1	408.50612925170066	0.2525	72	716	4	5	4	2	5016	1	2	0	0	10.020832184089821	
i 1	408.73521768707485	0.2525	77	400	4	3	6	16	5016	1	16	0	0	7.467405886407314	
i 1	409.00180272108844	0.2525	77	716	6	2	10	16	5016	1	16	0	0	7.467405886407314	
i 1	409.0039659863946	0.2525	71	716	4	20	9	2	0	-2	2	0	0	3.7489262047842917	
i 1	409.23377551020405	3.0300000000000002	67	716	5	25	2	5	0	0	5	0	0	5.334237091503673	
i 1	409.23810204081633	1.01	74	1102	5	9	7	16	0	2	16	0	0	4.804094661207461	
i 1	409.24314965986395	12.120000000000001	67	716	5	25	14	0	5016	1	0	0	0	5.334237091503673	
i 1	409.24387074829934	9.09	67	1102	4	26	7	0	0	0	0	0	0	5.334237091503673	
i 1	409.24387074829934	6.0600000000000005	60	400	3	27	8	5	5016	0	5	0	0	5.926930101670749	
i 1	409.2453129251701	3.0300000000000002	67	400	3	27	16	0	5016	1	0	0	0	5.926930101670749	
i 1	409.2467551020408	11.615	60	716	5	25	1	5	0	0	5	0	0	5.334237091503673	
i 1	409.24891836734696	3.0300000000000002	67	716	5	14	13	5	5016	0	5	0	0	2.383001132111544	
i 1	409.2496394557823	12.120000000000001	60	716	5	14	8	0	5016	0	0	0	0	3.250327233810605	
i 1	409.2503605442177	1.2625	74	716	4	4	15	17	0	1	17	0	0	5.804094661207461	
i 1	409.2532448979592	11.615	67	716	6	7	6	0	0	1	0	0	0	1.1915005660557723	
i 1	409.25757142857145	9.09	67	716	5	25	7	0	5016	1	0	0	0	5.334237091503673	
i 1	409.2582925170068	6.0600000000000005	60	716	5	14	7	5	5016	1	5	0	0	2.383001132111544	
i 1	409.25973469387753	0.7575000000000001	71	1102	3	24	15	2	0	-2	2	0	0	7.258469618179239	
i 1	409.2676666666667	6.0600000000000005	60	1102	4	26	12	0	0	0	0	0	0	5.334237091503673	
i 1	409.48954421768707	1.5150000000000001	74	400	1	24	5	8	5016	-2	8	0	0	7.258469618179239	
i 1	409.50108163265304	1.7675	74	1102	1	20	1	2	0	-2	2	0	0	3.258469618179239	
i 1	409.5032448979592	0.2525	77	400	4	4	4	17	5016	1	17	0	0	5.804094661207461	
i 1	409.74387074829934	2.02	77	400	5	3	14	16	5016	1	16	0	0	5.804094661207461	
i 1	409.75757142857145	2.2725	77	716	6	2	5	16	5016	1	16	0	0	5.804094661207461	
i 1	409.9859387755102	0.505	74	400	1	24	5	2	0	252	2	307	0	7.258469618179239	
i 1	410.01045578231293	0.2525	72	716	6	1	2	1	5016	-1	1	0	0	4.0	
i 1	410.2359387755102	1.2625	72	716	6	1	8	1	5016	-1	1	0	0	4.0	
i 1	410.24891836734696	1.7675	72	1102	6	5	5	2	0	-2	2	0	0	8.749497113548824	
i 1	410.26261904761907	1.2625	69	1102	5	1	15	0	0	0	0	0	0	4.0	
i 1	410.73449659863945	1.5150000000000001	71	1102	3	24	15	2	0	-2	2	0	0	7.258469618179239	
i 1	410.74242857142855	3.7875	72	1102	5	1	11	1	0	0	1	0	0	4.0	
i 1	410.75252380952384	0.2525	71	716	4	20	6	2	5016	1	2	0	0	3.258469618179239	
i 1	410.7582925170068	0.2525	74	1102	5	9	13	16	0	2	16	0	0	4.804094661207461	
i 1	410.76478231292515	0.2525	71	716	4	24	8	2	0	1	2	0	0	7.258469618179239	
i 1	410.99387074829934	0.2525	71	1102	3	20	5	8	5016	1	8	0	0	3.258469618179239	
i 1	411.00612925170066	0.505	75	716	4	5	13	8	0	1	8	0	0	8.749497113548824	
i 1	411.01622448979595	1.01	71	400	3	24	6	2	0	-2	2	0	0	7.258469618179239	
i 1	411.5039659863946	1.01	75	400	6	5	6	2	5016	1	2	0	0	8.749497113548824	
i 1	411.7532448979592	2.2725	74	400	1	24	15	8	5016	-2	8	0	0	7.258469618179239	
i 1	411.76622448979595	0.2525	69	400	3	1	6	1	5016	-1	1	0	0	4.0	
i 1	411.98449659863945	0.2525	74	716	4	20	2	2	5016	1	2	0	0	3.258469618179239	
i 1	411.98954421768707	2.02	75	400	6	5	2	2	5016	-2	2	0	0	8.749497113548824	
i 1	412.0054081632653	1.7675	74	716	4	4	16	17	0	1	17	0	0	5.804094661207461	
i 1	412.01045578231293	1.7675	74	1102	5	9	9	16	0	2	16	0	0	4.804094661207461	
i 1	412.0111768707483	2.02	75	716	4	5	1	8	0	1	8	0	0	8.749497113548824	
i 1	412.2366598639456	8.585	67	716	5	25	2	5	0	0	5	0	0	5.334237091503673	
i 1	412.24026530612247	3.0300000000000002	67	1102	4	16	2	0	0	1	0	0	0	1.6251636169053025	
i 1	412.24819727891156	9.09	67	400	3	27	15	0	5016	1	0	0	0	5.926930101670749	
i 1	412.2496394557823	0.2525	74	400	3	24	3	2	0	1	2	0	0	7.258469618179239	
i 1	412.2590136054422	2.02	71	400	3	20	11	2	0	-2	2	0	0	3.258469618179239	
i 1	412.26550340136055	9.3425	67	716	5	14	15	5	5016	0	5	0	0	2.383001132111544	
i 1	412.2669455782313	0.2525	72	716	6	1	16	1	5016	-1	1	0	0	4.0	
i 1	412.50180272108844	1.01	74	1102	3	20	8	2	0	-2	2	0	0	3.258469618179239	
i 1	412.50252380952384	0.2525	77	716	6	2	13	16	5016	1	16	0	0	5.804094661207461	
i 1	412.5090136054422	1.01	71	1102	3	20	2	2	5016	1	2	0	0	3.258469618179239	
i 1	412.5169455782313	0.2525	72	1102	6	5	12	2	0	-2	2	0	0	8.749497113548824	
i 1	412.74747619047616	0.2525	75	400	6	5	14	2	5016	1	2	0	0	8.749497113548824	
i 1	412.7676666666667	0.505	77	716	5	3	16	17	0	1	17	0	0	5.804094661207461	
i 1	413.00757142857145	1.7675	74	400	3	24	8	2	0	1	2	0	0	7.258469618179239	
i 1	413.24387074829934	1.2625	77	716	6	2	8	16	5016	1	16	0	0	5.804094661207461	
i 1	413.4945918367347	0.2525	72	716	6	1	6	1	0	0	1	0	0	4.0	
i 1	413.5039659863946	1.01	72	716	5	5	5	2	5016	1	2	0	0	8.749497113548824	
i 1	413.7409863945578	1.5150000000000001	72	716	4	5	3	2	5016	-2	2	0	0	8.749497113548824	
i 1	413.74242857142855	1.5150000000000001	77	716	6	2	13	16	5016	1	16	0	0	5.804094661207461	
i 1	414.0003605442177	1.2625	69	400	3	24	6	0	5016	-1	0	0	0	7.0	
i 1	414.01045578231293	2.7775	72	716	6	1	6	1	0	0	1	0	0	4.0	
i 1	414.2445918367347	0.2525	71	1102	3	20	12	2	5016	1	2	0	0	3.258469618179239	
i 1	414.4888231292517	0.7575000000000001	74	400	1	24	4	8	5016	-2	8	0	0	7.258469618179239	
i 1	414.49242857142855	0.2525	74	716	4	4	13	17	0	1	17	0	0	5.804094661207461	
i 1	414.49819727891156	0.505	72	1102	6	5	8	2	0	-2	2	0	0	8.749497113548824	
i 1	414.5111768707483	0.2525	71	400	3	20	6	2	0	-2	2	0	0	3.258469618179239	
i 1	414.51550340136055	3.7875	74	400	1	20	6	2	5016	-2	2	0	0	3.258469618179239	
i 1	414.73377551020405	0.505	74	716	4	20	12	8	0	1	8	0	0	3.258469618179239	
i 1	414.73738095238093	3.535	77	400	4	4	14	17	5016	1	17	0	0	5.804094661207461	
i 1	414.73738095238093	0.505	74	716	4	24	11	2	0	-2	2	0	0	7.258469618179239	
i 1	414.9823333333333	0.2525	75	1102	6	5	7	2	0	1	2	0	0	8.749497113548824	
i 1	415.00685034013605	0.2525	74	716	4	20	4	2	5016	-2	2	0	0	3.258469618179239	
i 1	415.01261904761907	0.2525	69	1102	5	1	7	0	0	0	0	0	0	4.0	
i 1	415.23521768707485	3.0300000000000002	67	1102	4	16	10	5	0	0	5	0	0	1.6251636169053025	
i 1	415.2453129251701	0.7575000000000001	74	1102	3	20	10	2	5016	-2	2	0	0	3.258469618179239	
i 1	415.24891836734696	6.3125	60	400	3	27	13	5	5016	0	5	0	0	5.926930101670749	
i 1	415.2496394557823	1.7675	74	400	3	24	2	8	5016	-2	8	0	0	7.258469618179239	
i 1	415.25685034013605	6.0600000000000005	67	716	6	17	16	0	5016	0	0	0	0	5.173802793543322	
i 1	415.25685034013605	6.3125	60	716	5	14	10	5	5016	1	5	0	0	2.383001132111544	
i 1	415.26045578231293	5.555	60	1102	4	26	11	0	0	0	0	0	0	5.334237091503673	
i 1	415.26261904761907	1.5150000000000001	69	400	4	24	14	0	5016	-1	0	0	0	7.0	
i 1	415.26261904761907	0.2525	75	716	4	5	6	8	0	-2	8	0	0	8.749497113548824	
i 1	415.2669455782313	0.2525	72	716	6	1	15	1	5016	-1	1	0	0	4.0	
i 1	415.2669455782313	5.555	67	1102	4	16	1	0	0	1	0	0	0	1.6251636169053025	
i 1	415.48810204081633	5.3025	74	1102	3	20	5	2	0	-2	2	0	0	3.258469618179239	
i 1	415.51261904761907	0.7575000000000001	74	1102	3	20	16	8	5016	-2	8	0	0	3.258469618179239	
i 1	415.75252380952384	0.2525	77	400	5	3	15	16	5016	1	16	0	0	5.804094661207461	
i 1	415.98377551020405	1.7675	75	716	4	5	2	8	0	1	8	0	0	8.749497113548824	
i 1	415.98738095238093	0.2525	72	716	6	1	10	1	5016	-1	1	0	0	4.0	
i 1	415.99819727891156	0.2525	74	1102	5	9	10	16	0	2	16	0	0	4.804094661207461	
i 1	416.0169455782313	1.7675	75	400	6	5	1	2	5016	-2	2	0	0	8.749497113548824	
i 1	416.2409863945578	1.2625	72	716	4	24	7	1	0	0	1	0	0	7.0	
i 1	416.24891836734696	0.505	71	716	4	20	2	2	5016	-2	2	0	0	3.258469618179239	
i 1	416.2539659863946	1.2625	72	1102	5	1	11	1	0	0	1	0	0	4.0	
i 1	416.48377551020405	0.2525	77	716	6	2	7	16	5016	1	16	0	0	5.804094661207461	
i 1	416.73738095238093	0.2525	75	400	6	5	2	2	5016	1	2	0	0	8.749497113548824	
i 1	416.73738095238093	0.2525	71	1102	3	20	8	2	5016	1	2	0	0	3.258469618179239	
i 1	416.75108163265304	0.2525	74	400	3	20	14	2	0	1	2	0	0	3.258469618179239	
i 1	416.7676666666667	0.7575000000000001	77	400	5	3	9	16	5016	1	16	0	0	5.804094661207461	
i 1	416.9960340136054	0.505	76	716	4	20	16	17	5016	1	17	0	0	3.258469618179239	
i 1	417.00108163265304	0.505	73	716	4	20	5	17	0	1	17	0	0	3.258469618179239	
i 1	417.00757142857145	2.02	69	400	4	24	5	0	5016	-1	0	0	0	7.0	
i 1	417.01189795918367	1.2625	72	716	5	5	11	2	5016	-2	2	0	0	8.749497113548824	
i 1	417.2467551020408	1.01	75	400	6	5	5	2	5016	1	2	0	0	8.749497113548824	
i 1	417.50612925170066	0.2525	69	400	5	1	12	1	5016	-1	1	0	0	4.0	
i 1	417.7388231292517	1.2625	74	716	4	4	11	17	0	1	17	0	0	5.804094661207461	
i 1	417.7409863945578	0.2525	72	716	4	24	4	1	0	0	1	0	0	7.0	
i 1	417.74242857142855	1.5150000000000001	71	1102	1	24	1	2	0	252	2	307	0	7.258469618179239	
i 1	417.7460340136054	0.505	72	1102	6	5	15	2	0	-2	2	0	0	8.749497113548824	
i 1	417.7539659863946	2.02	72	716	5	5	7	2	5016	1	2	0	0	8.749497113548824	
i 1	417.76550340136055	1.2625	74	1102	5	9	5	16	0	2	16	0	0	4.804094661207461	
i 1	418.2323333333333	3.0300000000000002	60	400	5	12	6	0	5016	1	0	0	0	1.6251636169053025	
i 1	418.2359387755102	0.2525	72	716	6	1	10	1	5016	-1	1	0	0	4.0	
i 1	418.2359387755102	3.2825	74	400	3	20	7	2	5016	-2	2	0	0	3.258469618179239	
i 1	418.24314965986395	2.525	67	1102	4	26	14	0	0	0	0	0	0	5.334237091503673	
i 1	418.2467551020408	2.525	67	1102	4	16	6	5	0	0	5	0	0	1.6251636169053025	
i 1	418.25108163265304	1.5150000000000001	72	1102	3	5	15	2	0	-2	2	0	0	8.749497113548824	
i 1	418.2532448979592	3.2825	67	716	6	17	7	0	5016	1	0	0	0	5.173802793543322	
i 1	418.26045578231293	0.2525	75	716	4	5	13	8	0	-2	8	0	0	8.749497113548824	
i 1	418.4823333333333	0.2525	75	400	6	5	1	2	5016	1	2	0	0	8.749497113548824	
i 1	418.4960340136054	0.7575000000000001	72	716	6	1	7	1	5016	-1	1	0	0	4.0	
i 1	418.50108163265304	1.7675	77	716	6	2	15	16	5016	1	16	0	0	5.804094661207461	
i 1	418.5054081632653	0.7575000000000001	69	1102	5	1	15	0	0	0	0	0	0	4.0	
i 1	418.5090136054422	1.7675	77	400	5	3	2	16	5016	1	16	0	0	5.804094661207461	
i 1	418.76550340136055	2.02	72	1102	6	1	9	1	0	0	1	0	0	4.0	
i 1	419.0032448979592	0.2525	77	400	4	4	3	17	5016	1	17	0	0	5.804094661207461	
i 1	419.0082925170068	0.2525	75	400	6	5	15	2	5016	-2	2	0	0	8.749497113548824	
i 1	419.2323333333333	1.01	73	400	3	24	5	17	0	2	17	0	0	7.258469618179239	
i 1	419.25252380952384	0.7575000000000001	75	400	6	5	10	2	5016	1	2	0	0	8.749497113548824	
i 1	419.2554081632653	0.505	69	400	4	24	16	0	5016	-1	0	0	0	7.0	
i 1	419.2554081632653	1.2625	71	1102	3	24	1	2	0	-2	2	0	0	7.258469618179239	
i 1	419.25757142857145	0.2525	74	1102	5	9	14	16	0	2	16	0	0	4.804094661207461	
i 1	419.2676666666667	0.7575000000000001	72	716	5	5	9	2	5016	-2	2	0	0	8.749497113548824	
i 1	419.5032448979592	0.2525	77	400	4	4	5	17	5016	1	17	0	0	5.804094661207461	
i 1	419.5111768707483	2.02	75	400	6	5	8	2	5016	-2	2	0	0	8.749497113548824	
i 1	419.75108163265304	0.2525	69	1102	5	1	6	0	0	0	0	0	0	4.0	
i 1	419.75108163265304	1.7675	77	716	6	2	9	16	5016	1	16	0	0	5.804094661207461	
i 1	419.99747619047616	0.2525	75	716	4	5	6	8	0	-2	8	0	0	8.749497113548824	
i 1	420.2417074829932	0.505	74	1102	5	9	5	16	0	2	16	0	0	4.804094661207461	
i 1	420.25108163265304	0.2525	73	716	4	20	15	17	5016	1	17	0	0	3.258469618179239	
i 1	420.2532448979592	0.2525	73	716	4	24	15	16	0	2	16	0	0	7.258469618179239	
i 1	420.4953129251701	0.2525	72	716	6	1	3	1	0	0	1	0	0	4.0	
i 1	420.5054081632653	0.2525	73	1102	3	20	3	16	5016	1	16	0	0	3.258469618179239	
i 1	420.51045578231293	1.01	73	400	3	24	1	16	0	2	16	0	0	7.258469618179239	
i 1	420.5111768707483	0.2525	72	1102	3	5	11	2	0	-2	2	0	0	8.749497113548824	
i 1	420.7359387755102	0.7575000000000001	74	112	4	5	3	16	5017	2	16	0	0	8.749497113548824	
i 1	420.73738095238093	0.2525	73	112	4	20	16	16	5017	2	16	0	0	3.258469618179239	
i 1	420.74314965986395	0.7575000000000001	61	112	5	16	13	9	5017	1	9	0	0	1.6251636169053025	
i 1	420.7453129251701	0.505	61	610	5	25	10	9	0	1	9	0	0	5.334237091503673	
i 1	420.74747619047616	0.505	72	610	4	24	1	2	0	-2	2	0	0	7.0	
i 1	420.74891836734696	0.2525	72	610	4	4	10	2	0	-2	2	0	0	5.804094661207461	
i 1	420.7503605442177	0.7575000000000001	73	112	4	20	5	16	5016	1	16	0	0	3.258469618179239	
i 1	420.75757142857145	0.7575000000000001	66	112	5	26	3	6	5017	1	6	0	0	5.334237091503673	
i 1	420.75973469387753	0.7575000000000001	61	112	5	26	9	9	5017	0	9	0	0	5.334237091503673	
i 1	420.7611768707483	0.7575000000000001	61	112	5	16	9	9	5017	0	9	0	0	1.6251636169053025	
i 1	420.76478231292515	0.505	66	610	5	25	14	6	0	1	6	0	0	5.334237091503673	
i 1	420.76622448979595	0.7575000000000001	72	112	6	9	6	2	5017	1	2	0	0	4.804094661207461	
i 1	420.98738095238093	0.505	76	112	4	24	16	17	5017	2	17	0	0	7.258469618179239	
i 1	420.99747619047616	0.505	77	400	4	4	11	17	5016	1	17	0	0	5.804094661207461	
i 1	421.00252380952384	0.2525	72	610	5	3	16	2	0	1	2	0	0	5.804094661207461	
i 1	421.23377551020405	0.2525	66	381	5	25	9	6	0	1	6	0	0	5.334237091503673	
i 1	421.23738095238093	0.2525	60	400	5	12	9	5	5016	1	5	0	0	1.6251636169053025	
i 1	421.23738095238093	0.2525	61	381	5	7	15	9	0	0	9	0	0	1.1915005660557723	
i 1	421.23810204081633	0.2525	60	716	5	14	12	0	5016	0	0	0	0	3.250327233810605	
i 1	421.2460340136054	0.2525	61	381	6	17	8	6	0	1	6	0	0	5.173802793543322	
i 1	421.2467551020408	0.2525	66	381	5	25	3	9	0	0	9	0	0	5.334237091503673	
i 1	421.2496394557823	0.2525	67	400	3	27	7	0	5016	1	0	0	0	5.926930101670749	
i 1	421.2503605442177	0.2525	72	716	5	5	4	2	5016	1	2	0	0	8.749497113548824	
i 1	421.2532448979592	0.2525	73	112	4	20	4	16	5017	2	16	0	0	3.258469618179239	
i 1	421.2539659863946	0.2525	72	716	6	1	14	1	5016	-1	1	0	0	4.0	
i 1	421.2554081632653	0.2525	67	716	5	17	6	0	5016	0	0	0	0	5.173802793543322	
i 1	421.25612925170066	0.2525	72	381	6	1	6	2	0	1	2	0	0	4.0	
i 1	421.26189795918367	0.2525	60	400	5	12	11	0	5016	1	0	0	0	1.6251636169053025	
i 1	421.2669455782313	0.2525	76	112	4	20	5	17	5016	2	17	0	0	3.258469618179239	
i 1	421.48377551020405	0.2525	73	228	4	24	8	16	5018	2	16	0	0	7.258469618179239	
i 1	421.48449659863945	0.7575000000000001	76	228	4	20	7	16	5018	2	16	0	0	3.258469618179239	
i 1	421.4859387755102	2.7775	61	930	5	14	13	9	0	0	9	0	0	3.250327233810605	
i 1	421.4888231292517	11.8675	61	228	5	26	5	6	5018	1	6	0	0	5.334237091503673	
i 1	421.48954421768707	14.8975	61	228	4	27	3	9	0	0	9	0	0	5.926930101670749	
i 1	421.49026530612247	1.01	72	930	6	2	10	2	0	-2	2	0	0	5.804094661207461	
i 1	421.49242857142855	17.9275	61	228	5	12	1	9	0	1	9	0	0	1.6251636169053025	
i 1	421.49314965986395	17.9275	66	930	5	17	10	9	0	0	9	0	0	5.173802793543322	
i 1	421.4960340136054	14.8975	66	228	5	16	15	6	5018	0	6	0	0	1.6251636169053025	
i 1	421.4960340136054	2.7775	66	228	4	27	9	6	0	1	6	0	0	5.926930101670749	
i 1	421.49819727891156	0.7575000000000001	74	228	4	5	11	16	5018	2	16	0	0	8.749497113548824	
i 1	421.49819727891156	11.8675	61	614	5	7	16	9	0	1	9	0	0	1.1915005660557723	
i 1	421.4996394557823	0.2525	75	228	5	4	10	2	0	-2	2	0	0	5.804094661207461	
i 1	421.50108163265304	1.7675	75	930	6	1	9	8	0	-2	8	0	0	4.0	
i 1	421.5032448979592	2.7775	66	930	5	14	11	9	0	1	9	0	0	2.383001132111544	
i 1	421.5039659863946	0.7575000000000001	73	228	3	24	10	17	0	2	17	0	0	7.258469618179239	
i 1	421.5046870748299	0.2525	72	614	4	24	13	2	0	-2	2	0	0	7.0	
i 1	421.5046870748299	11.8675	66	228	5	16	8	6	5018	0	6	0	0	1.6251636169053025	
i 1	421.50612925170066	2.7775	66	930	6	17	16	6	0	1	6	0	0	5.173802793543322	
i 1	421.50757142857145	0.2525	72	614	5	3	5	2	0	1	2	0	0	5.804094661207461	
i 1	421.5082925170068	5.8075	66	614	6	17	4	9	0	0	9	0	0	5.173802793543322	
i 1	421.5082925170068	0.2525	76	228	4	20	2	16	0	1	16	0	0	3.258469618179239	
i 1	421.51045578231293	2.7775	66	614	5	25	6	6	0	0	6	0	0	5.334237091503673	
i 1	421.5140612244898	5.8075	66	614	5	25	9	9	0	0	9	0	0	5.334237091503673	
i 1	421.51550340136055	2.7775	61	228	6	12	2	9	0	0	9	0	0	1.6251636169053025	
i 1	421.51622448979595	0.2525	74	228	6	5	12	16	0	2	16	0	0	8.749497113548824	
i 1	421.5169455782313	8.8375	66	228	5	26	2	6	5018	1	6	0	0	5.334237091503673	
i 1	421.5169455782313	5.8075	61	930	5	14	11	9	0	0	9	0	0	2.383001132111544	
i 1	421.75180272108844	2.2725	74	228	3	5	8	17	0	1	17	0	0	8.749497113548824	
i 1	421.76550340136055	2.02	72	228	6	9	6	2	5018	1	2	0	0	4.804094661207461	
i 1	421.9888231292517	1.7675	72	930	6	2	5	2	0	1	2	0	0	5.804094661207461	
i 1	422.2323333333333	0.2525	77	930	5	5	14	16	0	2	16	0	0	8.749497113548824	
i 1	422.5003605442177	3.535	72	614	4	24	16	2	0	-2	2	0	0	7.0	
i 1	422.5054081632653	0.2525	75	228	5	4	1	2	0	-2	2	0	0	5.804094661207461	
i 1	422.50685034013605	0.7575000000000001	73	228	3	24	14	17	0	1	17	0	0	7.258469618179239	
i 1	422.5133401360544	0.2525	74	614	5	5	16	17	0	2	17	0	0	8.749497113548824	
i 1	422.7366598639456	0.505	73	228	4	20	9	16	0	2	16	0	0	3.258469618179239	
i 1	422.73738095238093	1.01	73	228	4	24	1	16	5018	2	16	0	0	7.258469618179239	
i 1	422.7532448979592	0.7575000000000001	76	228	4	20	6	16	5018	2	16	0	0	3.258469618179239	
i 1	422.76622448979595	1.7675	72	614	4	4	15	2	0	-2	2	0	0	5.804094661207461	
i 1	423.00180272108844	1.5150000000000001	73	228	3	24	10	17	0	2	17	0	0	7.258469618179239	
i 1	423.2409863945578	0.2525	74	614	5	5	3	17	0	2	17	0	0	8.749497113548824	
i 1	423.2582925170068	1.01	75	228	5	4	15	2	0	-2	2	0	0	5.804094661207461	
i 1	423.26478231292515	0.2525	76	930	4	20	7	16	0	1	16	0	0	3.258469618179239	
i 1	423.26622448979595	0.2525	73	614	4	24	11	17	0	1	17	0	0	7.258469618179239	
i 1	423.48954421768707	1.01	73	228	4	20	4	17	0	1	17	0	0	3.258469618179239	
i 1	423.49387074829934	0.7575000000000001	74	228	4	5	2	16	5018	2	16	0	0	8.749497113548824	
i 1	423.50180272108844	0.2525	72	614	6	1	12	2	0	1	2	0	0	4.0	
i 1	423.50973469387753	1.5150000000000001	77	930	5	5	10	16	0	2	16	0	0	8.749497113548824	
i 1	423.51622448979595	0.2525	76	228	4	20	14	17	0	1	17	0	0	3.258469618179239	
i 1	423.7366598639456	0.2525	72	930	6	1	2	8	0	-2	8	0	0	4.0	
i 1	424.01622448979595	2.02	73	228	4	24	3	16	5018	2	16	0	0	7.258469618179239	
i 1	424.2359387755102	15.15	66	930	5	17	8	6	0	1	6	0	0	5.173802793543322	
i 1	424.23810204081633	15.15	66	228	4	27	15	6	0	1	6	0	0	5.926930101670749	
i 1	424.2388231292517	15.15	61	228	5	12	14	9	0	0	9	0	0	1.6251636169053025	
i 1	424.25108163265304	6.0600000000000005	66	614	6	17	4	9	0	0	9	0	0	5.173802793543322	
i 1	424.25612925170066	15.15	66	930	3	14	9	9	0	1	9	0	0	2.383001132111544	
i 1	424.48954421768707	5.3025	77	930	5	5	1	16	0	2	16	0	0	8.749497113548824	
i 1	424.49242857142855	0.2525	72	614	5	3	16	2	0	1	2	0	0	5.804094661207461	
i 1	424.5169455782313	2.7775	74	228	4	5	11	17	5018	2	17	0	0	8.749497113548824	
i 1	424.9859387755102	0.2525	75	930	6	1	3	8	0	-2	8	0	0	4.0	
i 1	424.99387074829934	0.2525	74	614	5	5	1	17	0	2	17	0	0	8.749497113548824	
i 1	425.26045578231293	2.7775	75	228	7	1	9	2	0	1	2	0	0	4.0	
i 1	425.2669455782313	0.2525	75	228	5	4	12	2	0	-2	2	0	0	5.804094661207461	
i 1	425.4859387755102	0.2525	73	614	4	24	13	16	0	1	16	0	0	7.258469618179239	
i 1	425.4945918367347	2.02	72	614	6	1	11	2	0	1	2	0	0	4.0	
i 1	425.50252380952384	0.2525	76	614	4	20	11	17	0	1	17	0	0	3.258469618179239	
i 1	425.50973469387753	1.5150000000000001	76	228	4	20	12	16	5018	2	16	0	0	3.258469618179239	
i 1	425.51189795918367	0.2525	72	228	6	3	2	2	0	1	2	0	0	5.804094661207461	
i 1	425.51189795918367	0.2525	73	930	4	20	6	16	0	1	16	0	0	3.258469618179239	
i 1	425.73521768707485	1.2625	73	228	4	20	1	17	0	1	17	0	0	3.258469618179239	
i 1	425.7467551020408	2.2725	73	228	3	20	7	16	0	1	16	0	0	3.258469618179239	
i 1	425.98954421768707	0.2525	72	228	6	9	12	8	5018	1	8	0	0	4.804094661207461	
i 1	426.0082925170068	0.2525	74	228	5	5	11	16	5018	2	16	0	0	8.749497113548824	
i 1	426.0111768707483	1.7675	73	228	4	20	11	16	0	2	16	0	0	3.258469618179239	
i 1	426.0133401360544	0.2525	75	930	6	1	14	8	0	-2	8	0	0	4.0	
i 1	426.2323333333333	0.2525	77	930	5	5	13	16	0	2	16	0	0	8.749497113548824	
i 1	426.23954421768707	4.04	72	228	6	3	2	2	0	1	2	0	0	5.804094661207461	
i 1	426.2582925170068	0.505	75	228	5	24	1	2	0	-2	2	0	0	7.0	
i 1	426.26261904761907	4.04	72	614	5	3	8	2	0	1	2	0	0	5.804094661207461	
i 1	426.48954421768707	0.505	75	930	6	1	5	8	0	-2	8	0	0	4.0	
i 1	426.74747619047616	0.2525	72	614	4	4	10	2	0	-2	2	0	0	5.804094661207461	
i 1	426.76189795918367	0.2525	75	228	5	4	16	2	0	-2	2	0	0	5.804094661207461	
i 1	426.9866598639456	0.2525	72	228	6	9	13	2	5018	1	2	0	0	4.804094661207461	
i 1	426.9960340136054	0.2525	75	228	5	24	5	2	0	-2	2	0	0	7.0	
i 1	426.99747619047616	2.02	72	614	4	24	2	2	0	-2	2	0	0	7.0	
i 1	426.99891836734696	1.01	74	228	3	5	12	17	0	1	17	0	0	8.749497113548824	
i 1	427.0090136054422	1.01	74	614	5	5	4	17	0	1	17	0	0	8.749497113548824	
i 1	427.24242857142855	12.120000000000001	66	614	5	17	1	9	0	0	9	0	0	5.173802793543322	
i 1	427.24314965986395	0.7575000000000001	73	228	2	20	12	17	0	1	17	0	0	3.258469618179239	
i 1	427.2496394557823	0.2525	72	930	4	2	12	2	0	1	2	0	0	5.804094661207461	
i 1	427.2532448979592	12.120000000000001	61	930	3	14	8	9	0	0	9	0	0	2.383001132111544	
i 1	427.25612925170066	2.525	74	228	5	5	13	17	5018	2	17	0	0	8.749497113548824	
i 1	427.2611768707483	1.7675	75	228	5	24	2	2	0	-2	2	0	0	7.0	
i 1	427.26189795918367	6.0600000000000005	61	228	5	18	16	6	5018	1	6	0	0	5.173802793543322	
i 1	427.26478231292515	3.2825	76	228	4	20	11	16	5018	2	16	0	0	3.258469618179239	
i 1	427.49819727891156	0.2525	72	930	6	1	5	8	0	-2	8	0	0	4.0	
i 1	427.5176666666667	0.505	72	228	6	9	11	2	5018	1	2	0	0	4.804094661207461	
i 1	427.7388231292517	0.7575000000000001	73	228	4	24	7	16	5018	2	16	0	0	7.258469618179239	
i 1	427.98810204081633	0.2525	74	614	5	5	1	17	0	2	17	0	0	8.749497113548824	
i 1	428.0046870748299	0.2525	75	228	7	1	6	2	5018	1	2	0	0	4.0	
i 1	428.0054081632653	0.2525	76	930	2	20	16	17	0	2	17	0	0	3.258469618179239	
i 1	428.01550340136055	0.2525	73	614	4	20	10	17	0	1	17	0	0	3.258469618179239	
i 1	428.2445918367347	0.505	76	228	3	20	5	16	0	1	16	0	0	3.258469618179239	
i 1	428.2503605442177	1.2625	75	228	7	1	7	2	0	1	2	0	0	4.0	
i 1	428.2590136054422	0.505	72	228	6	9	13	8	5018	1	8	0	0	4.804094661207461	
i 1	428.48954421768707	0.2525	74	228	3	5	12	17	0	1	17	0	0	8.749497113548824	
i 1	428.4917074829932	0.7575000000000001	73	228	1	24	10	16	5018	252	16	307	0	7.258469618179239	
i 1	428.4996394557823	1.01	73	228	3	24	8	17	0	2	17	0	0	7.258469618179239	
i 1	428.75180272108844	2.7775	75	930	6	1	14	8	0	-2	8	0	0	4.0	
i 1	428.75685034013605	0.505	76	930	2	20	2	17	0	1	17	0	0	3.258469618179239	
i 1	428.7611768707483	0.505	76	614	4	20	14	16	0	1	16	0	0	3.258469618179239	
i 1	428.9859387755102	0.7575000000000001	77	930	5	5	12	16	0	2	16	0	0	8.749497113548824	
i 1	429.24387074829934	1.01	74	228	3	5	15	17	0	1	17	0	0	8.749497113548824	
i 1	429.2496394557823	5.3025	73	228	4	24	16	16	5018	2	16	0	0	7.258469618179239	
i 1	429.25252380952384	1.01	73	228	3	24	3	17	0	1	17	0	0	7.258469618179239	
i 1	429.26478231292515	2.7775	74	614	5	5	9	17	0	1	17	0	0	8.749497113548824	
i 1	429.2669455782313	1.01	73	228	2	20	15	17	0	2	17	0	0	3.258469618179239	
i 1	429.5054081632653	0.2525	72	930	6	1	6	8	0	-2	8	0	0	4.0	
i 1	429.7388231292517	0.2525	74	614	5	5	3	17	0	2	17	0	0	8.749497113548824	
i 1	429.75973469387753	0.505	72	930	6	2	4	2	0	-2	2	0	0	5.804094661207461	
i 1	429.7676666666667	4.04	73	228	3	24	13	17	0	2	17	0	0	7.258469618179239	
i 1	429.9888231292517	0.2525	74	228	3	5	2	16	0	2	16	0	0	8.749497113548824	
i 1	430.0111768707483	0.2525	74	228	5	5	6	17	5018	2	17	0	0	8.749497113548824	
i 1	430.23377551020405	6.0600000000000005	66	228	5	18	14	9	5018	0	9	0	0	5.173802793543322	
i 1	430.23449659863945	1.7675	72	930	4	2	1	2	0	1	2	0	0	5.804094661207461	
i 1	430.2359387755102	0.505	77	930	5	5	4	16	0	2	16	0	0	8.749497113548824	
i 1	430.25108163265304	9.09	66	614	5	17	5	9	0	0	9	0	0	5.173802793543322	
i 1	430.2539659863946	1.5150000000000001	72	228	6	9	1	2	5018	1	2	0	0	4.804094661207461	
i 1	430.26045578231293	0.505	72	930	4	2	4	2	0	-2	2	0	0	5.804094661207461	
i 1	430.26045578231293	1.7675	74	228	4	5	9	17	0	1	17	0	0	8.749497113548824	
i 1	430.7409863945578	0.505	76	228	3	20	4	17	0	1	17	0	0	3.258469618179239	
i 1	430.76550340136055	2.525	72	614	4	4	13	2	0	-2	2	0	0	5.804094661207461	
i 1	430.7669455782313	0.505	73	228	2	20	7	16	0	1	16	0	0	3.258469618179239	
i 1	431.2467551020408	2.02	75	228	5	4	4	2	0	-2	2	0	0	5.804094661207461	
i 1	431.25180272108844	0.505	76	930	2	20	6	17	0	2	17	0	0	3.258469618179239	
i 1	431.48810204081633	1.7675	74	228	5	5	2	16	5018	2	16	0	0	8.749497113548824	
i 1	431.5082925170068	2.02	77	930	5	5	7	16	0	2	16	0	0	8.749497113548824	
i 1	431.51045578231293	1.01	76	228	4	20	12	16	5018	2	16	0	0	3.258469618179239	
i 1	431.74242857142855	0.2525	76	228	2	20	16	16	0	2	16	0	0	3.258469618179239	
i 1	431.74387074829934	0.2525	73	228	3	20	10	17	0	2	17	0	0	3.258469618179239	
i 1	431.9888231292517	0.2525	73	930	2	20	6	16	0	2	16	0	0	3.258469618179239	
i 1	432.0111768707483	0.505	75	930	6	1	10	8	0	-2	8	0	0	4.0	
i 1	432.01189795918367	0.2525	76	614	4	20	10	17	0	2	17	0	0	3.258469618179239	
i 1	432.01189795918367	6.565	73	228	3	20	15	17	0	2	17	0	0	3.258469618179239	
i 1	432.0169455782313	4.545	74	228	5	5	9	17	5018	2	17	0	0	8.749497113548824	
i 1	432.2445918367347	0.505	76	228	2	20	4	16	0	1	16	0	0	3.258469618179239	
i 1	432.2532448979592	0.2525	72	228	6	9	3	8	5018	1	8	0	0	4.804094661207461	
i 1	432.5039659863946	2.525	72	614	6	1	10	2	0	1	2	0	0	4.0	
i 1	432.74387074829934	0.2525	76	614	4	20	7	17	0	1	17	0	0	3.258469618179239	
i 1	432.7467551020408	2.2725	72	228	6	9	10	8	5018	1	8	0	0	4.804094661207461	
i 1	432.76189795918367	0.2525	76	930	2	20	8	16	0	1	16	0	0	3.258469618179239	
i 1	432.76550340136055	2.2725	72	930	4	2	4	2	0	-2	2	0	0	5.804094661207461	
i 1	433.00973469387753	0.2525	73	228	3	24	15	17	0	2	17	0	0	7.258469618179239	
i 1	433.2330544217687	0.2525	72	614	4	24	6	2	0	-2	2	0	0	7.0	
i 1	433.2330544217687	21.21	61	228	5	18	12	6	5018	1	6	0	0	5.173802793543322	
i 1	433.23521768707485	6.0600000000000005	66	228	5	19	6	9	0	1	9	0	0	5.173802793543322	
i 1	433.2359387755102	3.0300000000000002	66	228	5	16	8	6	5018	0	6	0	0	1.6251636169053025	
i 1	433.24819727891156	0.505	72	228	6	9	7	2	5018	1	2	0	0	4.804094661207461	
i 1	433.25180272108844	0.2525	76	614	2	20	9	16	0	2	16	0	0	3.258469618179239	
i 1	433.25180272108844	0.2525	76	614	4	24	13	16	0	1	16	0	0	7.258469618179239	
i 1	433.26550340136055	6.0600000000000005	61	614	4	7	15	9	0	1	9	0	0	1.1915005660557723	
i 1	433.4888231292517	0.505	74	228	5	5	6	16	5018	2	16	0	0	8.749497113548824	
i 1	433.4909863945578	0.7575000000000001	73	228	3	24	2	16	0	1	16	0	0	7.258469618179239	
i 1	433.5082925170068	0.2525	75	228	7	1	14	2	5018	1	2	0	0	4.0	
i 1	433.50973469387753	0.7575000000000001	73	228	2	20	11	16	0	2	16	0	0	3.258469618179239	
i 1	433.5169455782313	0.7575000000000001	76	228	1	20	14	17	0	1	17	0	0	3.258469618179239	
i 1	433.7633401360544	0.505	72	614	4	3	5	2	0	1	2	0	0	5.804094661207461	
i 1	433.9909863945578	0.505	74	614	5	5	7	17	0	2	17	0	0	8.749497113548824	
i 1	434.0054081632653	1.2625	73	228	3	24	6	17	0	2	17	0	0	7.258469618179239	
i 1	434.25252380952384	0.2525	75	228	7	1	3	2	5018	1	2	0	0	4.0	
i 1	434.25612925170066	0.505	73	614	4	24	4	17	0	1	17	0	0	7.258469618179239	
i 1	434.25757142857145	0.505	76	614	2	20	12	17	0	2	17	0	0	3.258469618179239	
i 1	434.26045578231293	0.505	73	930	2	20	1	17	0	1	17	0	0	3.258469618179239	
i 1	434.48449659863945	1.2625	74	228	4	5	3	17	0	1	17	0	0	8.749497113548824	
i 1	434.48810204081633	2.2725	75	228	5	24	6	2	0	-2	2	0	0	7.0	
i 1	434.4917074829932	2.02	72	614	4	24	1	2	0	-2	2	0	0	7.0	
i 1	434.73738095238093	1.7675	76	228	2	20	4	16	0	2	16	0	0	3.258469618179239	
i 1	434.7453129251701	1.7675	76	228	1	20	16	17	0	1	17	0	0	3.258469618179239	
i 1	434.9967551020408	0.2525	72	228	7	1	4	2	5018	1	2	0	0	4.0	
i 1	435.23810204081633	0.505	75	930	6	1	3	8	0	-2	8	0	0	4.0	
i 1	435.5046870748299	0.7575000000000001	75	228	5	4	2	2	0	-2	2	0	0	5.804094661207461	
i 1	435.73377551020405	2.02	72	614	6	1	11	2	0	1	2	0	0	4.0	
i 1	435.76261904761907	0.2525	74	228	4	5	7	16	0	2	16	0	0	8.749497113548824	
i 1	435.76622448979595	2.02	75	228	7	1	14	2	0	1	2	0	0	4.0	
i 1	435.9888231292517	1.7675	74	228	5	5	1	16	5018	2	16	0	0	8.749497113548824	
i 1	435.9917074829932	2.02	77	930	5	5	16	16	0	2	16	0	0	8.749497113548824	
i 1	435.9967551020408	1.5150000000000001	73	228	3	24	12	17	0	2	17	0	0	7.258469618179239	
i 1	436.00757142857145	0.7575000000000001	72	930	4	2	14	2	0	-2	2	0	0	5.804094661207461	
i 1	436.0133401360544	0.2525	76	228	3	24	3	16	0	1	16	0	0	7.258469618179239	
i 1	436.2409863945578	3.0300000000000002	61	228	5	19	13	9	0	0	9	0	0	5.173802793543322	
i 1	436.2496394557823	0.2525	72	228	6	9	12	2	5018	1	2	0	0	4.804094661207461	
i 1	436.2582925170068	0.2525	76	228	1	24	2	16	0	1	16	0	0	7.258469618179239	
i 1	436.2590136054422	3.0300000000000002	66	228	5	16	12	6	5018	0	6	0	0	1.6251636169053025	
i 1	436.26045578231293	18.18	66	228	5	18	2	9	5018	0	9	0	0	5.173802793543322	
i 1	436.4859387755102	0.505	73	614	2	24	4	16	0	2	16	0	0	7.258469618179239	
i 1	436.48738095238093	0.2525	75	930	6	1	15	8	0	-2	8	0	0	4.0	
i 1	436.5039659863946	0.505	74	614	5	5	4	17	0	2	17	0	0	8.749497113548824	
i 1	436.5169455782313	0.505	76	614	2	20	16	16	0	2	16	0	0	3.258469618179239	
i 1	436.7409863945578	0.2525	72	614	4	24	5	2	0	-2	2	0	0	7.0	
i 1	436.7409863945578	2.525	73	228	4	24	16	16	5018	2	16	0	0	7.258469618179239	
i 1	436.7467551020408	0.2525	72	228	6	9	11	8	5018	1	8	0	0	4.804094661207461	
i 1	436.98377551020405	1.2625	73	228	1	24	13	16	0	2	16	0	0	7.258469618179239	
i 1	436.98521768707485	1.2625	76	228	1	20	3	16	0	1	16	0	0	3.258469618179239	
i 1	436.98810204081633	0.2525	74	228	4	5	2	16	0	2	16	0	0	8.749497113548824	
i 1	436.99026530612247	1.5150000000000001	75	930	6	1	5	8	0	-2	8	0	0	4.0	
i 1	437.0003605442177	0.7575000000000001	73	228	2	20	12	16	0	1	16	0	0	3.258469618179239	
i 1	437.2445918367347	2.02	74	228	4	5	15	17	0	1	17	0	0	8.749497113548824	
i 1	437.26622448979595	2.02	74	614	5	5	16	17	0	1	17	0	0	8.749497113548824	
i 1	437.4996394557823	1.7675	75	228	5	24	14	2	0	-2	2	0	0	7.0	
i 1	437.51622448979595	0.2525	72	228	6	9	7	2	5018	1	2	0	0	4.804094661207461	
i 1	437.74026530612247	2.2725	72	228	6	9	16	8	5018	1	8	0	0	4.804094661207461	
i 1	438.0046870748299	0.505	74	228	5	5	7	16	5018	2	16	0	0	8.749497113548824	
i 1	438.0046870748299	1.01	73	228	3	24	11	17	0	2	17	0	0	7.258469618179239	
i 1	438.0082925170068	0.2525	73	228	2	20	13	16	0	1	16	0	0	3.258469618179239	
i 1	438.2388231292517	1.5150000000000001	76	228	4	20	9	16	5018	2	16	0	0	3.258469618179239	
i 1	438.2409863945578	0.2525	73	614	2	24	4	17	0	1	17	0	0	7.258469618179239	
i 1	438.24891836734696	0.2525	73	930	2	20	9	16	0	1	16	0	0	3.258469618179239	
i 1	438.2554081632653	0.2525	76	614	2	20	11	17	0	2	17	0	0	3.258469618179239	
i 1	438.48449659863945	0.2525	74	228	4	5	10	16	0	2	16	0	0	8.749497113548824	
i 1	438.5003605442177	0.505	75	228	7	1	4	2	0	1	2	0	0	4.0	
i 1	438.50757142857145	0.2525	72	930	4	2	7	2	0	1	2	0	0	5.804094661207461	
i 1	438.7330544217687	0.505	72	228	6	9	11	2	5018	1	2	0	0	4.804094661207461	
i 1	438.74242857142855	0.7575000000000001	73	228	2	20	14	16	0	2	16	0	0	3.258469618179239	
i 1	438.7496394557823	0.505	76	228	1	24	9	17	0	1	17	0	0	7.258469618179239	
i 1	438.75108163265304	0.505	73	228	3	20	4	17	0	2	17	0	0	3.258469618179239	
i 1	438.7539659863946	0.505	77	930	5	5	3	16	0	2	16	0	0	8.749497113548824	
i 1	438.99314965986395	3.2825	75	228	6	1	8	2	5018	1	2	0	0	4.0	
i 1	439.00685034013605	0.2525	72	614	6	1	8	2	0	1	2	0	0	4.0	
i 1	439.23521768707485	0.2525	73	723	1	20	12	16	5019	1	16	0	0	3.258469618179239	
i 1	439.23810204081633	0.505	72	723	6	1	2	8	5019	-2	8	0	0	4.0	
i 1	439.23810204081633	9.09	66	1109	5	17	5	9	0	0	9	0	0	5.173802793543322	
i 1	439.23810204081633	15.15	61	723	5	17	15	9	5019	1	9	0	0	5.173802793543322	
i 1	439.23810204081633	3.0300000000000002	66	723	4	19	1	9	0	0	9	0	0	5.173802793543322	
i 1	439.23954421768707	15.15	61	723	1	27	1	6	0	252	6	307	0	5.926930101670749	
i 1	439.23954421768707	15.15	61	1109	4	14	9	9	0	0	9	0	0	2.383001132111544	
i 1	439.2409863945578	1.7675	75	723	4	4	12	8	5019	1	8	0	0	5.804094661207461	
i 1	439.2453129251701	3.0300000000000002	66	1109	3	14	3	9	0	1	9	0	0	2.383001132111544	
i 1	439.24819727891156	0.2525	73	723	1	24	16	16	5019	2	16	0	0	7.258469618179239	
i 1	439.24891836734696	1.01	77	723	5	5	3	16	5019	2	16	0	0	8.749497113548824	
i 1	439.25108163265304	2.2725	74	1109	5	5	13	16	0	2	16	0	0	8.749497113548824	
i 1	439.25252380952384	6.0600000000000005	61	1109	5	17	8	6	0	1	6	0	0	5.173802793543322	
i 1	439.2554081632653	15.15	61	723	1	27	4	6	0	252	6	307	0	5.926930101670749	
i 1	439.25612925170066	3.0300000000000002	66	723	5	12	2	9	0	1	9	0	0	1.6251636169053025	
i 1	439.25612925170066	3.0300000000000002	66	723	5	12	2	9	0	0	9	0	0	1.6251636169053025	
i 1	439.25612925170066	15.15	66	723	4	19	10	6	0	0	6	0	0	5.173802793543322	
i 1	439.25612925170066	2.2725	74	723	4	5	1	17	0	1	17	0	0	8.749497113548824	
i 1	439.2611768707483	12.120000000000001	61	723	5	17	14	9	5019	0	9	0	0	5.173802793543322	
i 1	439.26478231292515	9.09	66	723	4	7	12	9	5019	1	9	0	0	1.1915005660557723	
i 1	439.2669455782313	3.2825	73	723	3	20	13	17	0	2	17	0	0	3.258469618179239	
i 1	439.5032448979592	0.505	76	1109	2	20	6	16	0	2	16	0	0	3.258469618179239	
i 1	439.5082925170068	0.2525	75	723	4	3	11	2	5019	1	2	0	0	5.804094661207461	
i 1	439.73810204081633	0.2525	74	228	5	5	10	17	5018	2	17	0	0	8.749497113548824	
i 1	439.76261904761907	0.2525	72	228	6	1	2	2	5018	1	2	0	0	4.0	
i 1	439.9823333333333	0.2525	76	228	2	20	16	17	0	2	17	0	0	3.258469618179239	
i 1	439.9866598639456	0.2525	73	723	1	20	9	16	5019	1	16	0	0	3.258469618179239	
i 1	439.9967551020408	1.5150000000000001	76	228	4	20	11	16	5018	2	16	0	0	3.258469618179239	
i 1	439.99819727891156	0.2525	72	1109	6	2	7	2	0	1	2	0	0	5.804094661207461	
i 1	440.23521768707485	0.2525	73	1109	2	20	2	17	0	2	17	0	0	3.258469618179239	
i 1	440.2366598639456	0.2525	73	723	2	24	16	16	5019	2	16	0	0	7.258469618179239	
i 1	440.2539659863946	0.2525	74	228	5	5	13	17	5018	2	17	0	0	8.749497113548824	
i 1	440.25757142857145	0.2525	74	228	5	5	10	16	5018	2	16	0	0	8.749497113548824	
i 1	440.2640612244898	0.2525	73	723	2	20	14	16	5019	1	16	0	0	3.258469618179239	
i 1	440.4967551020408	2.02	77	723	4	5	10	16	0	1	16	0	0	8.749497113548824	
i 1	440.74387074829934	0.505	72	1109	6	1	2	2	0	-2	2	0	0	4.0	
i 1	440.76189795918367	0.2525	75	1109	6	1	10	2	0	-2	2	0	0	4.0	
i 1	441.0082925170068	0.2525	73	723	2	20	6	16	5019	1	16	0	0	3.258469618179239	
i 1	441.0133401360544	0.2525	73	723	2	24	16	16	5019	2	16	0	0	7.258469618179239	
i 1	441.23521768707485	1.01	72	228	6	9	14	8	5018	1	8	0	0	4.804094661207461	
i 1	441.2388231292517	0.505	73	228	2	20	4	16	0	1	16	0	0	3.258469618179239	
i 1	441.25757142857145	1.2625	73	723	1	24	6	16	5019	2	16	0	0	7.258469618179239	
i 1	441.26045578231293	2.02	75	723	4	24	14	2	0	-2	2	0	0	7.0	
i 1	441.49819727891156	1.7675	72	723	6	1	11	8	5019	-2	8	0	0	4.0	
i 1	441.5032448979592	0.2525	74	228	5	5	9	16	5018	2	16	0	0	8.749497113548824	
i 1	441.7539659863946	0.505	74	1109	5	5	16	16	0	2	16	0	0	8.749497113548824	
i 1	441.7590136054422	2.02	74	723	4	5	6	17	0	1	17	0	0	8.749497113548824	
i 1	441.98954421768707	9.3425	73	228	2	24	8	16	5018	2	16	0	0	7.258469618179239	
i 1	441.99314965986395	0.2525	75	723	4	4	5	8	5019	1	8	0	0	5.804094661207461	
i 1	442.0140612244898	1.2625	73	228	2	20	14	16	0	2	16	0	0	3.258469618179239	
i 1	442.2366598639456	12.120000000000001	66	1109	4	14	4	9	0	1	9	0	0	2.383001132111544	
i 1	442.23738095238093	3.0300000000000002	66	723	5	12	15	9	0	0	9	0	0	1.6251636169053025	
i 1	442.2388231292517	12.120000000000001	66	723	4	19	10	9	0	0	9	0	0	5.173802793543322	
i 1	442.23954421768707	1.01	72	228	4	9	1	8	5018	1	8	0	0	4.804094661207461	
i 1	442.24026530612247	1.2625	72	1109	4	2	16	2	0	1	2	0	0	5.804094661207461	
i 1	442.24747619047616	1.5150000000000001	74	1109	6	5	5	16	0	2	16	0	0	8.749497113548824	
i 1	442.2496394557823	3.0300000000000002	75	723	4	3	1	2	5019	1	2	0	0	5.804094661207461	
i 1	442.25180272108844	5.555	76	228	2	20	6	16	5018	2	16	0	0	3.258469618179239	
i 1	442.4823333333333	1.5150000000000001	72	228	6	1	11	2	5018	1	2	0	0	4.0	
i 1	442.5039659863946	0.2525	77	723	5	5	8	16	5019	1	16	0	0	8.749497113548824	
i 1	442.7366598639456	1.2625	76	723	3	24	9	17	0	2	17	0	0	7.258469618179239	
i 1	442.7453129251701	0.505	73	723	1	20	3	16	5019	1	16	0	0	3.258469618179239	
i 1	442.7453129251701	4.545	73	723	3	20	13	17	0	2	17	0	0	3.258469618179239	
i 1	442.7590136054422	2.2725	77	1109	6	5	15	16	0	2	16	0	0	8.749497113548824	
i 1	442.76045578231293	2.2725	74	228	5	5	6	17	5018	2	17	0	0	8.749497113548824	
i 1	442.9945918367347	4.04	75	228	6	1	9	2	5018	1	2	0	0	4.0	
i 1	443.00973469387753	4.2925	72	723	4	24	6	2	5019	-2	2	0	0	7.0	
i 1	443.2590136054422	0.2525	72	1109	6	2	5	2	0	1	2	0	0	5.804094661207461	
i 1	443.2669455782313	0.2525	76	1109	2	20	16	16	0	1	16	0	0	3.258469618179239	
i 1	443.48377551020405	0.505	75	723	5	3	4	2	0	-2	2	0	0	5.804094661207461	
i 1	443.49242857142855	1.2625	73	228	2	20	16	16	0	2	16	0	0	3.258469618179239	
i 1	443.5032448979592	0.2525	72	228	4	9	5	8	5018	1	8	0	0	4.804094661207461	
i 1	443.51045578231293	1.2625	73	723	1	24	10	16	5019	2	16	0	0	7.258469618179239	
i 1	443.73377551020405	1.01	76	228	2	20	8	17	0	1	17	0	0	3.258469618179239	
i 1	443.76189795918367	0.2525	77	723	5	5	10	16	5019	1	16	0	0	8.749497113548824	
i 1	443.98810204081633	3.535	77	723	4	5	8	16	0	1	16	0	0	8.749497113548824	
i 1	443.99242857142855	0.2525	75	723	5	1	14	8	0	1	8	0	0	4.0	
i 1	444.0054081632653	0.2525	72	228	4	9	7	8	5018	1	8	0	0	4.804094661207461	
i 1	444.0176666666667	1.2625	77	723	5	5	6	16	5019	2	16	0	0	8.749497113548824	
i 1	444.2409863945578	1.01	76	723	3	24	15	17	0	2	17	0	0	7.258469618179239	
i 1	444.2467551020408	0.505	75	723	4	4	10	8	5019	1	8	0	0	5.804094661207461	
i 1	444.48377551020405	0.2525	75	723	5	1	3	8	0	1	8	0	0	4.0	
i 1	444.7323333333333	0.505	72	228	4	9	6	8	5018	1	8	0	0	4.804094661207461	
i 1	444.73449659863945	0.505	75	723	4	24	13	2	0	-2	2	0	0	7.0	
i 1	444.7590136054422	0.2525	76	1109	2	20	10	17	0	1	17	0	0	3.258469618179239	
i 1	444.76189795918367	0.2525	73	723	2	24	9	16	5019	2	16	0	0	7.258469618179239	
i 1	444.7669455782313	0.2525	72	1109	6	2	6	2	0	1	2	0	0	5.804094661207461	
i 1	444.98521768707485	1.7675	73	723	1	24	1	16	5019	2	16	0	0	7.258469618179239	
i 1	444.9859387755102	0.2525	77	723	5	5	5	16	5019	1	16	0	0	8.749497113548824	
i 1	444.9917074829932	1.7675	73	228	2	20	11	17	0	2	17	0	0	3.258469618179239	
i 1	445.00252380952384	0.2525	74	1109	6	5	10	16	0	2	16	0	0	8.749497113548824	
i 1	445.23810204081633	1.5150000000000001	77	723	6	5	6	16	5019	2	16	0	0	8.749497113548824	
i 1	445.2388231292517	3.0300000000000002	61	1109	5	25	5	9	0	1	9	0	0	5.334237091503673	
i 1	445.2460340136054	0.2525	77	1109	6	5	3	16	0	2	16	0	0	8.749497113548824	
i 1	445.2532448979592	0.2525	72	228	6	1	3	2	5018	1	2	0	0	4.0	
i 1	445.2554081632653	2.525	72	1109	4	2	7	2	0	1	2	0	0	5.804094661207461	
i 1	445.26478231292515	2.525	75	723	3	3	4	2	0	-2	2	0	0	5.804094661207461	
i 1	445.4888231292517	0.2525	75	723	4	24	15	2	0	-2	2	0	0	7.0	
i 1	445.99891836734696	2.2725	72	723	6	1	10	8	5019	-2	8	0	0	4.0	
i 1	446.0046870748299	0.2525	72	1109	6	1	9	2	0	-2	2	0	0	4.0	
i 1	446.2453129251701	0.2525	72	228	4	9	7	2	5018	1	2	0	0	4.804094661207461	
i 1	446.25973469387753	2.02	75	723	4	24	9	2	0	-2	2	0	0	7.0	
i 1	446.7330544217687	2.02	72	228	4	9	1	8	5018	1	8	0	0	4.804094661207461	
i 1	446.7460340136054	0.505	73	723	2	24	15	16	5019	2	16	0	0	7.258469618179239	
i 1	446.7582925170068	2.525	76	723	1	24	7	17	0	2	17	0	0	7.258469618179239	
i 1	446.7640612244898	0.505	74	228	5	5	10	16	5018	2	16	0	0	8.749497113548824	
i 1	447.0169455782313	0.2525	75	723	5	1	1	8	0	1	8	0	0	4.0	
i 1	447.2323333333333	1.5150000000000001	73	723	1	20	7	16	5019	1	16	0	0	3.258469618179239	
i 1	447.2532448979592	0.2525	72	228	6	1	9	2	5018	1	2	0	0	4.0	
i 1	447.2590136054422	1.5150000000000001	73	723	1	24	14	16	5019	2	16	0	0	7.258469618179239	
i 1	447.48810204081633	0.2525	77	1109	6	5	8	16	0	2	16	0	0	8.749497113548824	
i 1	447.4888231292517	0.7575000000000001	73	723	3	20	11	17	0	2	17	0	0	3.258469618179239	
i 1	447.4917074829932	0.2525	74	228	5	5	11	16	5018	2	16	0	0	8.749497113548824	
i 1	447.4960340136054	2.2725	72	723	4	24	15	2	5019	-2	2	0	0	7.0	
i 1	447.76622448979595	2.02	72	228	4	9	9	2	5018	1	2	0	0	4.804094661207461	
i 1	448.0046870748299	2.525	77	723	6	5	4	16	5019	2	16	0	0	8.749497113548824	
i 1	448.01045578231293	0.2525	74	228	5	5	11	16	5018	2	16	0	0	8.749497113548824	
i 1	448.23521768707485	3.0300000000000002	73	723	1	20	14	17	0	2	17	0	0	3.258469618179239	
i 1	448.23954421768707	1.5150000000000001	75	723	4	4	7	8	5019	1	8	0	0	5.804094661207461	
i 1	448.24026530612247	0.505	72	1109	6	1	13	2	0	-2	2	0	0	4.0	
i 1	448.2460340136054	6.0600000000000005	61	1109	5	25	5	9	0	1	9	0	0	5.334237091503673	
i 1	448.2467551020408	2.2725	77	723	4	5	12	16	0	1	16	0	0	8.749497113548824	
i 1	448.2539659863946	0.2525	75	1109	4	1	11	2	0	-2	2	0	0	4.0	
i 1	448.26261904761907	3.0300000000000002	66	1109	5	25	15	9	0	0	9	0	0	5.334237091503673	
i 1	448.5046870748299	1.7675	75	723	3	3	5	2	0	-2	2	0	0	5.804094661207461	
i 1	448.7417074829932	2.525	72	723	6	1	5	8	5019	-2	8	0	0	4.0	
i 1	448.7582925170068	0.2525	73	723	2	24	16	16	5019	2	16	0	0	7.258469618179239	
i 1	449.0039659863946	1.5150000000000001	73	228	2	20	8	16	0	1	16	0	0	3.258469618179239	
i 1	449.00973469387753	0.2525	73	723	1	20	11	16	5019	1	16	0	0	3.258469618179239	
i 1	449.01550340136055	1.5150000000000001	73	723	1	24	13	16	5019	2	16	0	0	7.258469618179239	
i 1	449.2582925170068	2.02	72	1109	4	2	15	2	0	1	2	0	0	5.804094661207461	
i 1	449.7330544217687	0.7575000000000001	73	723	1	20	16	16	5019	1	16	0	0	3.258469618179239	
i 1	449.7417074829932	2.7775	74	228	5	5	3	17	5018	2	17	0	0	8.749497113548824	
i 1	449.75973469387753	1.2625	76	723	1	24	7	17	0	2	17	0	0	7.258469618179239	
i 1	450.0046870748299	1.5150000000000001	75	1109	4	1	10	2	0	-2	2	0	0	4.0	
i 1	450.24819727891156	4.04	75	723	3	4	3	2	0	-2	2	0	0	5.804094661207461	
i 1	450.49314965986395	3.7875	75	228	6	1	14	2	5018	1	2	0	0	4.0	
i 1	450.49314965986395	0.2525	73	723	2	20	15	16	5019	1	16	0	0	3.258469618179239	
i 1	450.49387074829934	0.2525	73	723	2	24	11	16	5019	2	16	0	0	7.258469618179239	
i 1	450.73810204081633	0.505	76	228	2	20	4	16	0	1	16	0	0	3.258469618179239	
i 1	450.7417074829932	0.505	73	723	1	20	6	16	5019	1	16	0	0	3.258469618179239	
i 1	450.99242857142855	2.525	77	723	4	5	9	16	0	1	16	0	0	8.749497113548824	
i 1	451.24314965986395	3.0300000000000002	66	1109	5	25	12	9	0	0	9	0	0	5.334237091503673	
i 1	451.2554081632653	1.01	77	1109	4	5	5	16	0	2	16	0	0	8.749497113548824	
i 1	451.2582925170068	2.525	77	723	6	5	5	16	5019	2	16	0	0	8.749497113548824	
i 1	451.25973469387753	1.2625	73	723	1	20	7	17	0	2	17	0	0	2.301580738753259	
i 1	451.2611768707483	0.2525	75	723	4	4	14	8	5019	1	8	0	0	5.804094661207461	
i 1	451.2611768707483	3.0300000000000002	61	723	5	25	7	6	5019	1	6	0	0	5.334237091503673	
i 1	451.2611768707483	4.7975	73	228	2	24	3	16	5018	2	16	0	0	6.301580738753259	
i 1	451.2640612244898	0.2525	73	723	2	24	4	16	5019	2	16	0	0	6.301580738753259	
i 1	451.26622448979595	0.7575000000000001	76	228	2	20	16	16	5018	2	16	0	0	2.301580738753259	
i 1	451.4859387755102	0.7575000000000001	75	723	5	1	11	8	0	1	8	0	0	4.0	
i 1	451.49242857142855	0.2525	75	723	3	3	16	2	0	-2	2	0	0	5.804094661207461	
i 1	451.5090136054422	2.02	73	228	2	20	13	17	0	1	17	0	0	2.301580738753259	
i 1	451.5090136054422	1.01	73	723	1	24	2	16	5019	2	16	0	0	6.301580738753259	
i 1	451.9967551020408	0.505	72	228	6	1	6	2	5018	1	2	0	0	4.0	
i 1	452.01622448979595	0.2525	72	228	4	9	3	8	5018	1	8	0	0	4.804094661207461	
i 1	452.23954421768707	0.2525	72	1109	4	1	10	2	0	-2	2	0	0	4.0	
i 1	452.51478231292515	1.7675	74	723	4	5	2	17	0	1	17	0	0	8.749497113548824	
i 1	452.51622448979595	0.505	75	723	4	24	14	2	0	-2	2	0	0	7.0	
i 1	452.9830544217687	0.2525	72	228	4	9	7	8	5018	1	8	0	0	4.804094661207461	
i 1	452.99242857142855	3.0300000000000002	73	723	1	20	1	17	0	2	17	0	0	2.301580738753259	
i 1	453.2554081632653	0.505	72	1109	4	2	2	2	0	1	2	0	0	5.804094661207461	
i 1	453.25685034013605	0.2525	73	723	1	24	8	16	5019	2	16	0	0	6.301580738753259	
i 1	453.2590136054422	1.01	75	723	3	3	4	2	0	-2	2	0	0	5.804094661207461	
i 1	453.4960340136054	0.2525	72	228	6	1	15	2	5018	1	2	0	0	4.0	
i 1	453.49819727891156	0.7575000000000001	74	228	5	5	15	17	5018	2	17	0	0	8.749497113548824	
i 1	453.73449659863945	0.505	73	723	1	20	14	16	5019	1	16	0	0	2.301580738753259	
i 1	453.73738095238093	1.01	76	228	2	20	4	16	0	2	16	0	0	2.301580738753259	
i 1	453.74026530612247	0.505	75	723	4	24	10	2	0	-2	2	0	0	7.0	
i 1	453.74314965986395	1.01	73	723	1	24	7	16	5019	2	16	0	0	6.301580738753259	
i 1	453.7460340136054	0.2525	72	228	4	9	6	8	5018	1	8	0	0	4.804094661207461	
i 1	453.7676666666667	0.505	72	723	6	1	3	8	5019	-2	8	0	0	4.0	
i 1	454.2330544217687	1.7675	74	1109	4	5	6	16	0	2	16	0	0	5.972585005898294	
i 1	454.23738095238093	1.7675	66	723	4	19	8	9	0	0	9	0	0	3.4492018623622136	
i 1	454.2388231292517	1.7675	61	723	1	27	15	6	0	252	6	307	0	0.592693010167075	
i 1	454.23954421768707	2.7775	72	723	4	1	5	8	5019	-2	8	0	0	8.0	
i 1	454.24387074829934	1.7675	72	1109	4	2	6	2	0	1	2	0	0	5.007119820275398	
i 1	454.2453129251701	1.7675	61	228	5	18	13	6	5018	1	6	0	0	3.4492018623622136	
i 1	454.2467551020408	1.7675	66	723	4	19	13	6	0	0	6	0	0	3.4492018623622136	
i 1	454.24891836734696	1.7675	75	723	3	3	5	2	0	-2	2	0	0	5.007119820275398	
i 1	454.2496394557823	1.01	75	723	4	3	15	2	5019	1	2	0	0	5.007119820275398	
i 1	454.2496394557823	0.7575000000000001	77	1109	4	5	10	16	0	2	16	0	0	5.972585005898294	
i 1	454.25180272108844	1.7675	61	723	1	27	16	6	0	252	6	307	0	0.592693010167075	
i 1	454.26189795918367	2.2725	72	723	4	24	15	2	5019	-2	2	0	0	11.0	
i 1	454.2640612244898	1.7675	66	228	5	18	10	9	5018	0	9	0	0	3.4492018623622136	
i 1	454.7445918367347	0.2525	73	1109	2	20	5	17	0	2	17	0	0	2.301580738753259	
i 1	454.75612925170066	0.505	74	228	6	5	12	17	5018	2	17	0	0	5.972585005898294	
i 1	454.9830544217687	1.01	76	228	2	20	14	17	0	2	17	0	0	2.301580738753259	
i 1	455.00685034013605	1.01	76	228	2	20	16	16	0	2	16	0	0	2.301580738753259	
i 1	455.0111768707483	1.01	73	723	1	24	14	16	5019	2	16	0	0	6.301580738753259	
i 1	455.01261904761907	1.01	77	723	4	5	8	16	0	1	16	0	0	5.972585005898294	
i 1	455.0140612244898	1.01	76	228	2	20	4	16	5018	2	16	0	0	2.301580738753259	
i 1	455.26478231292515	2.02	77	723	6	5	4	16	5019	2	16	0	0	5.972585005898294	
i 1	455.4823333333333	0.505	77	1109	4	5	16	16	0	2	16	0	0	5.972585005898294	
i 1	455.4888231292517	0.505	75	723	5	1	15	8	0	1	8	0	0	8.0	
i 1	455.5140612244898	0.505	74	228	6	5	3	16	5018	2	16	0	0	5.972585005898294	
i 1	455.73738095238093	0.2525	75	1109	4	1	6	2	0	-2	2	0	0	8.0	
i 1	455.98521768707485	0.505	76	390	1	24	10	17	5019	1	17	0	0	6.301580738753259	
i 1	455.98810204081633	1.01	77	4	5	5	6	17	0	2	17	0	0	5.972585005898294	
i 1	455.98954421768707	0.505	66	4	5	18	14	6	0	1	6	0	0	3.4492018623622136	
i 1	455.99242857142855	0.505	77	390	4	5	1	17	0	1	17	0	0	5.972585005898294	
i 1	455.99314965986395	3.0300000000000002	72	4	5	2	10	2	0	1	2	0	0	5.007119820275398	
i 1	455.99314965986395	0.505	75	4	6	9	10	8	0	1	8	0	0	4.007119820275398	
i 1	455.99314965986395	0.505	73	4	2	20	16	17	0	2	17	0	0	2.301580738753259	
i 1	455.9967551020408	0.505	74	4	6	5	15	16	0	2	16	0	0	5.972585005898294	
i 1	455.9967551020408	0.505	76	4	2	20	7	16	0	2	16	0	0	2.301580738753259	
i 1	455.99891836734696	0.505	72	390	5	1	13	2	0	1	2	0	0	8.0	
i 1	456.0054081632653	0.505	66	4	5	18	13	6	0	0	6	0	0	3.4492018623622136	
i 1	456.00685034013605	0.2525	74	4	5	5	2	17	0	2	17	0	0	5.972585005898294	
i 1	456.00973469387753	0.505	66	390	4	19	4	9	0	0	9	0	0	3.4492018623622136	
i 1	456.01045578231293	2.2725	72	4	5	1	6	8	0	1	8	0	0	8.0	
i 1	456.0133401360544	0.505	66	390	4	19	4	6	0	0	6	0	0	3.4492018623622136	
i 1	456.0140612244898	0.505	73	4	2	20	8	17	0	2	17	0	0	2.301580738753259	
i 1	456.01478231292515	0.505	61	390	1	27	8	9	0	252	9	307	0	0.592693010167075	
i 1	456.01478231292515	0.505	77	390	4	5	5	16	0	1	16	0	0	5.972585005898294	
i 1	456.4859387755102	3.7875	61	390	4	18	4	6	0	0	6	0	0	3.4492018623622136	
i 1	456.48738095238093	6.8175	61	4	4	19	2	9	0	0	9	0	0	3.4492018623622136	
i 1	456.49747619047616	9.8475	61	4	4	19	8	6	0	0	6	0	0	3.4492018623622136	
i 1	456.4996394557823	2.7775	73	4	1	24	5	16	0	252	16	307	0	6.301580738753259	
i 1	456.50685034013605	0.7575000000000001	61	390	4	18	13	9	0	1	9	0	0	3.4492018623622136	
i 1	456.51189795918367	0.2525	75	4	5	1	9	2	0	-2	2	0	0	8.0	
i 1	456.51189795918367	0.7575000000000001	74	4	4	5	10	16	0	1	16	0	0	5.972585005898294	
i 1	456.5169455782313	16.16	73	390	2	20	14	16	0	1	16	0	0	2.301580738753259	
i 1	456.5176666666667	2.525	76	4	1	24	8	16	5019	2	16	0	0	6.301580738753259	
i 1	456.9823333333333	2.02	76	390	2	20	10	17	0	1	17	0	0	2.301580738753259	
i 1	456.98810204081633	0.2525	72	723	4	24	12	2	5019	-2	2	0	0	11.0	
i 1	456.9953129251701	0.7575000000000001	74	4	5	5	7	17	0	2	17	0	0	5.972585005898294	
i 1	457.0003605442177	6.8175	72	4	5	24	10	2	0	-2	2	0	0	11.0	
i 1	457.2366598639456	3.535	72	723	4	24	6	2	5019	-2	2	0	0	11.0	
i 1	457.23810204081633	0.2525	72	390	4	9	13	2	0	-2	2	0	0	4.007119820275398	
i 1	457.2409863945578	2.2725	74	4	5	5	13	16	0	1	16	0	0	5.972585005898294	
i 1	457.2582925170068	1.7675	77	723	4	5	7	16	5019	2	16	0	0	5.972585005898294	
i 1	457.2676666666667	0.2525	74	390	6	5	11	16	0	1	16	0	0	5.972585005898294	
i 1	457.5046870748299	0.2525	75	723	4	4	15	8	5019	1	8	0	0	5.007119820275398	
i 1	457.51261904761907	0.2525	77	390	6	5	11	16	0	1	16	0	0	5.972585005898294	
i 1	457.74387074829934	4.7975	75	723	4	3	12	2	5019	1	2	0	0	5.007119820275398	
i 1	457.9945918367347	0.2525	72	723	4	1	5	8	5019	-2	8	0	0	8.0	
i 1	458.01189795918367	5.3025	77	390	6	5	1	16	0	1	16	0	0	5.972585005898294	
i 1	458.0176666666667	5.3025	74	4	5	5	2	17	0	2	17	0	0	5.972585005898294	
i 1	458.2532448979592	0.2525	72	4	5	1	11	8	0	1	8	0	0	8.0	
i 1	458.99026530612247	0.7575000000000001	74	390	6	5	3	16	0	1	16	0	0	5.972585005898294	
i 1	459.00252380952384	0.2525	72	390	4	9	16	2	0	-2	2	0	0	4.007119820275398	
i 1	459.01261904761907	0.505	73	723	2	24	11	16	5019	1	16	0	0	6.301580738753259	
i 1	459.23738095238093	1.2625	73	4	1	24	11	16	0	2	16	0	0	6.301580738753259	
i 1	459.2388231292517	0.2525	75	4	3	4	6	8	0	-2	8	0	0	5.007119820275398	
i 1	459.2539659863946	0.2525	75	390	4	9	4	2	0	1	2	0	0	4.007119820275398	
i 1	459.4859387755102	0.2525	76	390	2	20	15	16	0	1	16	0	0	2.301580738753259	
i 1	459.5003605442177	0.2525	72	390	6	1	16	2	0	-2	2	0	0	8.0	
i 1	459.50757142857145	0.2525	77	723	6	5	5	16	5019	1	16	0	0	5.972585005898294	
i 1	459.5169455782313	0.2525	76	4	1	24	9	17	5019	1	17	0	0	6.301580738753259	
i 1	459.73521768707485	0.505	75	4	3	4	14	8	0	-2	8	0	0	5.007119820275398	
i 1	459.7388231292517	2.525	72	723	4	1	8	8	5019	-2	8	0	0	8.0	
i 1	459.7388231292517	2.7775	75	4	5	1	11	2	0	-2	2	0	0	8.0	
i 1	459.75108163265304	0.2525	77	4	4	5	13	17	0	2	17	0	0	5.972585005898294	
i 1	460.2409863945578	2.2725	75	4	3	3	9	2	0	-2	2	0	0	5.007119820275398	
i 1	460.2496394557823	0.505	72	4	7	2	7	2	0	1	2	0	0	5.007119820275398	
i 1	460.2611768707483	0.2525	77	4	5	5	4	17	0	2	17	0	0	5.972585005898294	
i 1	460.4960340136054	0.505	76	4	1	24	15	16	5019	2	16	0	0	6.301580738753259	
i 1	460.49747619047616	0.505	73	390	2	20	16	16	0	1	16	0	0	2.301580738753259	
i 1	460.50108163265304	0.505	77	723	4	5	8	16	5019	1	16	0	0	5.972585005898294	
i 1	460.5046870748299	0.2525	74	390	6	5	4	16	0	1	16	0	0	5.972585005898294	
i 1	460.5111768707483	0.505	76	4	1	20	14	16	5019	1	16	0	0	2.301580738753259	
i 1	460.7417074829932	0.2525	72	390	4	9	8	2	0	-2	2	0	0	4.007119820275398	
i 1	460.75612925170066	1.5150000000000001	77	723	4	5	7	16	5019	2	16	0	0	5.972585005898294	
i 1	460.75973469387753	0.2525	75	723	4	4	6	8	5019	1	8	0	0	5.007119820275398	
i 1	460.98954421768707	3.535	73	4	1	24	15	16	0	2	16	0	0	6.301580738753259	
i 1	461.0032448979592	0.505	73	4	3	20	5	16	0	1	16	0	0	2.301580738753259	
i 1	461.0039659863946	0.505	76	723	2	20	6	17	5019	2	17	0	0	2.301580738753259	
i 1	461.00757142857145	0.505	75	4	5	4	15	8	0	-2	8	0	0	5.007119820275398	
i 1	461.0133401360544	0.505	73	723	2	24	2	17	5019	2	17	0	0	6.301580738753259	
i 1	461.49026530612247	1.5150000000000001	73	390	2	20	3	17	0	1	17	0	0	2.301580738753259	
i 1	461.4917074829932	1.5150000000000001	76	4	1	20	16	16	5019	1	16	0	0	2.301580738753259	
i 1	461.49387074829934	1.5150000000000001	76	390	2	20	16	17	0	1	17	0	0	2.301580738753259	
i 1	461.9953129251701	2.02	75	390	4	9	8	2	0	1	2	0	0	4.007119820275398	
i 1	462.00180272108844	1.01	76	4	1	24	8	17	5019	1	17	0	0	6.301580738753259	
i 1	462.2460340136054	0.2525	72	390	4	1	7	8	0	-2	8	0	0	8.0	
i 1	462.26478231292515	1.01	74	390	6	5	3	16	0	1	16	0	0	5.972585005898294	
i 1	462.48449659863945	2.525	72	723	4	1	12	8	5019	-2	8	0	0	8.0	
i 1	462.74387074829934	0.505	75	4	5	1	2	2	0	-2	2	0	0	8.0	
i 1	462.9909863945578	2.525	75	723	4	4	12	8	5019	1	8	0	0	5.007119820275398	
i 1	463.0003605442177	0.2525	76	4	3	20	11	16	0	2	16	0	0	2.301580738753259	
i 1	463.00108163265304	0.2525	73	723	2	20	1	16	5019	1	16	0	0	2.301580738753259	
i 1	463.01478231292515	0.2525	76	4	3	20	12	17	0	2	17	0	0	2.301580738753259	
i 1	463.01478231292515	0.2525	76	723	2	24	16	17	5019	2	17	0	0	6.301580738753259	
i 1	463.23738095238093	1.7675	75	4	6	1	12	2	0	-2	2	0	0	8.0	
i 1	463.23738095238093	0.505	76	4	1	24	13	16	5019	1	16	0	0	6.301580738753259	
i 1	463.2388231292517	0.505	76	390	2	20	12	17	0	2	17	0	0	2.301580738753259	
i 1	463.24891836734696	0.2525	77	4	5	5	13	17	0	2	17	0	0	5.972585005898294	
i 1	463.2539659863946	3.0300000000000002	61	4	4	27	7	9	0	0	9	0	0	0.592693010167075	
i 1	463.25685034013605	2.2725	75	4	3	4	1	8	0	-2	8	0	0	5.007119820275398	
i 1	463.49747619047616	0.2525	73	4	1	20	5	17	5019	2	17	0	0	2.301580738753259	
i 1	463.5111768707483	3.2825	74	4	5	5	12	16	0	1	16	0	0	5.972585005898294	
i 1	463.73449659863945	0.505	76	723	2	24	2	17	5019	2	17	0	0	6.301580738753259	
i 1	463.7366598639456	0.505	73	4	3	20	11	17	0	1	17	0	0	2.301580738753259	
i 1	464.01189795918367	2.02	72	4	5	1	2	8	0	1	8	0	0	8.0	
i 1	464.2532448979592	1.01	73	390	2	20	7	16	0	1	16	0	0	2.301580738753259	
i 1	464.25757142857145	0.2525	75	723	4	3	9	2	5019	1	2	0	0	5.007119820275398	
i 1	464.26045578231293	1.01	76	4	1	24	3	16	5019	1	16	0	0	6.301580738753259	
i 1	464.26478231292515	1.01	76	390	2	20	7	17	0	2	17	0	0	2.301580738753259	
i 1	464.4830544217687	2.525	72	390	4	9	13	2	0	-2	2	0	0	4.007119820275398	
i 1	464.5032448979592	0.2525	74	4	5	5	10	17	0	2	17	0	0	5.972585005898294	
i 1	464.5032448979592	0.2525	77	4	5	5	16	17	0	2	17	0	0	5.972585005898294	
i 1	464.73449659863945	0.2525	77	723	4	5	13	16	5019	1	16	0	0	5.972585005898294	
i 1	464.74026530612247	3.535	72	723	4	24	10	2	5019	-2	2	0	0	11.0	
i 1	464.74819727891156	1.5150000000000001	77	390	6	5	10	16	0	1	16	0	0	5.972585005898294	
i 1	464.9960340136054	0.2525	76	4	1	20	6	16	5019	1	16	0	0	2.301580738753259	
i 1	465.2388231292517	0.505	73	723	2	20	13	17	5019	1	17	0	0	2.301580738753259	
i 1	465.2445918367347	1.5150000000000001	73	4	1	24	3	16	0	2	16	0	0	6.301580738753259	
i 1	465.5054081632653	3.0300000000000002	75	390	4	9	2	2	0	1	2	0	0	4.007119820275398	
i 1	465.51045578231293	0.2525	72	4	7	2	4	2	0	1	2	0	0	5.007119820275398	
i 1	465.73521768707485	2.02	73	390	2	20	15	17	0	2	17	0	0	2.301580738753259	
i 1	465.7453129251701	0.2525	75	4	6	1	4	2	0	-2	2	0	0	8.0	
i 1	465.98377551020405	0.2525	72	4	7	2	15	2	0	1	2	0	0	5.007119820275398	
i 1	466.0054081632653	0.7575000000000001	74	390	4	5	1	16	0	1	16	0	0	5.972585005898294	
i 1	466.0133401360544	0.2525	72	4	5	1	10	8	0	1	8	0	0	8.0	
i 1	466.0133401360544	0.2525	72	390	4	1	16	8	0	-2	8	0	0	8.0	
i 1	466.24314965986395	6.3125	73	390	2	24	10	17	0	1	17	0	0	6.301580738753259	
i 1	466.2532448979592	1.5150000000000001	72	4	7	2	12	2	0	1	2	0	0	5.007119820275398	
i 1	466.2532448979592	1.5150000000000001	73	390	2	20	6	17	0	2	17	0	0	2.301580738753259	
i 1	466.2546870748299	6.3125	61	4	4	27	9	9	0	0	9	0	0	0.592693010167075	
i 1	466.26261904761907	3.0300000000000002	66	4	4	27	4	9	0	1	9	0	0	0.592693010167075	
i 1	466.7359387755102	4.04	75	4	3	3	11	2	0	-2	2	0	0	5.007119820275398	
i 1	466.7453129251701	0.7575000000000001	77	4	5	5	6	17	0	2	17	0	0	5.972585005898294	
i 1	466.7467551020408	0.2525	77	723	4	5	16	16	5019	1	16	0	0	5.972585005898294	
i 1	466.75973469387753	3.7875	75	723	5	3	13	2	5019	1	2	0	0	5.007119820275398	
i 1	467.0111768707483	0.2525	72	390	4	1	8	2	0	-2	2	0	0	8.0	
i 1	467.24891836734696	2.525	72	723	4	1	14	8	5019	-2	8	0	0	8.0	
i 1	467.49314965986395	2.525	77	723	4	5	9	16	5019	2	16	0	0	5.972585005898294	
i 1	467.51550340136055	0.2525	76	4	1	20	9	17	5019	1	17	0	0	2.301580738753259	
i 1	467.5176666666667	0.2525	77	4	5	5	13	17	0	2	17	0	0	5.972585005898294	
i 1	467.7330544217687	0.505	76	723	2	20	10	17	5019	2	17	0	0	2.301580738753259	
i 1	467.73377551020405	0.505	73	723	2	24	7	16	5019	1	16	0	0	6.301580738753259	
i 1	467.73449659863945	0.2525	72	4	7	2	4	2	0	-2	2	0	0	5.007119820275398	
i 1	467.7453129251701	2.7775	73	4	1	24	8	16	0	2	16	0	0	6.301580738753259	
i 1	467.75252380952384	0.505	73	4	3	20	7	17	0	2	17	0	0	2.301580738753259	
i 1	467.76045578231293	0.505	73	4	3	20	2	16	0	2	16	0	0	2.301580738753259	
i 1	467.98954421768707	0.2525	75	723	4	4	10	8	5019	1	8	0	0	5.007119820275398	
i 1	468.2323333333333	0.505	76	4	1	24	15	17	5019	2	17	0	0	6.301580738753259	
i 1	468.2460340136054	0.2525	72	390	4	1	13	8	0	-2	8	0	0	8.0	
i 1	468.2590136054422	0.505	76	390	2	20	10	17	0	2	17	0	0	2.301580738753259	
i 1	468.48738095238093	3.0300000000000002	72	723	4	24	6	2	5019	-2	2	0	0	11.0	
i 1	468.5133401360544	0.2525	75	723	4	4	3	8	5019	1	8	0	0	5.007119820275398	
i 1	468.7445918367347	0.2525	73	723	2	20	6	17	5019	1	17	0	0	2.301580738753259	
i 1	468.76478231292515	0.2525	76	4	3	20	1	17	0	1	17	0	0	2.301580738753259	
i 1	468.98738095238093	1.5150000000000001	73	4	1	24	14	17	5019	2	17	0	0	6.301580738753259	
i 1	468.98954421768707	2.2725	74	4	5	5	2	17	0	2	17	0	0	5.972585005898294	
i 1	468.98954421768707	1.5150000000000001	73	4	1	20	12	16	5019	2	16	0	0	2.301580738753259	
i 1	469.2323333333333	0.7575000000000001	74	4	3	5	9	16	0	1	16	0	0	5.972585005898294	
i 1	469.2503605442177	2.2725	72	4	3	24	3	2	0	-2	2	0	0	11.0	
i 1	469.2539659863946	3.2825	72	4	7	2	14	2	0	-2	2	0	0	5.007119820275398	
i 1	469.2546870748299	2.02	76	390	1	20	8	17	0	2	17	0	0	2.301580738753259	
i 1	469.26045578231293	0.2525	75	390	4	9	6	2	0	1	2	0	0	4.007119820275398	
i 1	469.2611768707483	3.2825	66	4	4	27	4	9	0	1	9	0	0	0.592693010167075	
i 1	469.4823333333333	1.7675	76	390	2	20	4	17	0	1	17	0	0	2.301580738753259	
i 1	469.5176666666667	2.525	72	390	4	9	5	2	0	-2	2	0	0	4.007119820275398	
i 1	469.7676666666667	0.2525	72	390	4	1	2	2	0	-2	2	0	0	8.0	
i 1	470.2582925170068	0.2525	72	390	4	1	11	2	0	-2	2	0	0	8.0	
i 1	470.4909863945578	2.02	74	4	3	5	16	16	0	1	16	0	0	5.972585005898294	
i 1	470.5176666666667	0.2525	75	390	4	9	2	2	0	1	2	0	0	4.007119820275398	
i 1	470.7539659863946	0.2525	75	723	4	4	16	8	5019	1	8	0	0	5.007119820275398	
i 1	470.75685034013605	1.7675	73	4	1	24	15	16	0	2	16	0	0	6.301580738753259	
i 1	470.98954421768707	1.2625	75	390	4	9	3	2	0	1	2	0	0	4.007119820275398	
i 1	470.9960340136054	1.5150000000000001	72	4	7	2	10	2	0	1	2	0	0	5.007119820275398	
i 1	471.23738095238093	1.2625	72	390	4	1	13	8	0	-2	8	0	0	8.0	
i 1	471.24387074829934	0.2525	73	4	3	20	14	17	0	1	17	0	0	2.301580738753259	
i 1	471.24747619047616	0.2525	76	723	2	24	4	16	5019	1	16	0	0	6.301580738753259	
i 1	471.25252380952384	0.2525	73	723	2	20	10	17	5019	2	17	0	0	2.301580738753259	
i 1	471.25685034013605	1.2625	72	4	7	1	13	8	0	1	8	0	0	8.0	
i 1	471.2590136054422	0.2525	76	4	2	20	12	17	0	2	17	0	0	2.301580738753259	
i 1	471.51045578231293	0.7575000000000001	77	4	5	5	1	17	0	2	17	0	0	5.972585005898294	
i 1	471.98521768707485	0.2525	76	4	3	20	5	17	0	1	17	0	0	2.301580738753259	
i 1	471.98810204081633	0.2525	74	4	5	5	5	17	0	2	17	0	0	5.972585005898294	
i 1	471.99242857142855	0.2525	73	723	2	20	5	17	5019	1	17	0	0	2.301580738753259	
i 1	472.0054081632653	0.505	75	4	3	3	10	2	0	-2	2	0	0	5.007119820275398	
i 1	472.23449659863945	0.2525	73	390	1	20	16	17	0	2	17	0	0	2.301580738753259	
i 1	472.24387074829934	0.2525	73	4	1	20	8	16	5019	1	16	0	0	2.301580738753259	
i 1	472.2590136054422	0.2525	72	723	4	24	4	2	5019	-2	2	0	0	11.0	
i 1	472.2633401360544	0.2525	75	390	5	9	2	2	0	1	2	0	0	4.007119820275398	
i 1	472.4830544217687	6.0600000000000005	63	1087	5	25	10	1	0	2	1	0	0	1.1853860203341497	
i 1	472.4859387755102	1.01	74	701	6	1	7	16	0	1	16	0	0	2.0	
i 1	472.4859387755102	0.505	73	701	3	20	12	8	0	-2	8	0	0	4.0	
i 1	472.4859387755102	0.7575000000000001	73	701	2	20	3	2	0	-2	2	0	0	4.0	
i 1	472.4866598639456	1.01	69	203	4	5	9	1	0	0	1	0	0	3.0	
i 1	472.48738095238093	0.505	71	701	5	9	8	8	0	-1	8	0	0	3.0	
i 1	472.49026530612247	0.505	70	701	3	24	1	2	0	-1	2	0	0	8.0	
i 1	472.49242857142855	13.3825	61	701	1	27	4	16	0	252	16	307	0	1.7780790305012246	
i 1	472.50108163265304	3.0300000000000002	61	203	6	25	9	1	0	1	1	0	0	1.1853860203341497	
i 1	472.50180272108844	0.505	74	203	6	2	10	8	0	-1	8	0	0	4.0	
i 1	472.51261904761907	1.01	72	701	3	5	16	0	0	-1	0	0	0	3.0	
i 1	472.51550340136055	10.352500000000001	61	701	1	27	4	16	0	252	16	307	0	1.7780790305012246	
i 1	472.7590136054422	0.2525	77	1087	4	24	16	16	0	2	16	0	0	5.0	
i 1	472.76622448979595	0.2525	71	1087	5	3	14	8	0	-1	8	0	0	4.0	
i 1	472.99387074829934	0.7575000000000001	71	701	4	4	7	8	0	-2	8	0	0	4.0	
i 1	473.0111768707483	1.5150000000000001	71	1087	4	4	11	2	0	-2	2	0	0	4.0	
i 1	473.23377551020405	0.2525	70	1087	3	20	4	8	0	-2	8	0	0	4.0	
i 1	473.24242857142855	0.2525	70	701	3	24	6	2	0	-1	2	0	0	8.0	
i 1	473.2633401360544	0.2525	70	1087	3	24	11	8	0	-2	8	0	0	8.0	
i 1	473.49387074829934	1.2625	72	1087	3	5	13	1	0	0	1	0	0	3.0	
i 1	473.49891836734696	0.2525	72	701	6	5	16	1	0	0	1	0	0	3.0	
i 1	473.5133401360544	0.7575000000000001	77	1087	4	24	9	16	0	2	16	0	0	5.0	
i 1	473.5176666666667	0.7575000000000001	77	701	4	24	2	16	0	2	16	0	0	5.0	
i 1	473.74026530612247	0.2525	70	1087	3	20	1	8	0	-1	8	0	0	4.0	
i 1	473.7445918367347	7.8275	63	1087	5	25	4	1	0	2	1	0	0	1.1853860203341497	
i 1	474.24242857142855	1.2625	74	701	6	1	6	17	0	1	17	0	0	2.0	
i 1	474.2445918367347	1.2625	74	203	5	1	14	17	0	2	17	0	0	2.0	
i 1	474.4967551020408	0.505	70	701	3	20	4	2	0	-1	2	0	0	4.0	
i 1	474.4967551020408	0.505	70	701	3	24	4	2	0	-1	2	0	0	8.0	
i 1	474.50757142857145	1.7675	71	701	5	9	2	8	0	-1	8	0	0	3.0	
i 1	474.5082925170068	1.7675	74	203	5	2	1	8	0	-1	8	0	0	4.0	
i 1	474.51478231292515	0.2525	70	701	3	20	1	8	0	-1	8	0	0	4.0	
i 1	474.73954421768707	1.5150000000000001	69	203	6	5	8	0	0	0	0	0	0	3.0	
i 1	474.73954421768707	0.7575000000000001	73	701	3	20	1	2	0	-2	2	0	0	4.0	
i 1	474.74242857142855	1.5150000000000001	69	701	3	5	4	0	0	0	0	0	0	3.0	
i 1	474.7669455782313	0.2525	71	1087	5	3	8	8	0	-1	8	0	0	4.0	
i 1	475.0054081632653	0.2525	70	203	4	20	7	2	0	-1	2	0	0	4.0	
i 1	475.2669455782313	0.2525	72	701	3	5	3	0	0	-1	0	0	0	3.0	
i 1	475.5039659863946	1.5150000000000001	70	701	3	24	4	2	0	-1	2	0	0	4.0	
i 1	475.7366598639456	0.2525	74	701	6	1	16	17	0	1	17	0	0	2.0	
i 1	475.74747619047616	1.01	74	701	6	1	16	16	0	1	16	0	0	2.0	
i 1	475.99026530612247	1.01	72	701	3	5	5	0	0	-1	0	0	0	3.0	
i 1	475.9917074829932	1.5150000000000001	71	701	5	3	12	8	0	-2	8	0	0	4.0	
i 1	475.9967551020408	0.7575000000000001	72	1087	3	5	8	0	0	0	0	0	0	3.0	
i 1	476.0039659863946	1.5150000000000001	71	1087	5	3	11	8	0	-1	8	0	0	4.0	
i 1	476.49387074829934	1.5150000000000001	69	203	6	5	14	1	0	0	1	0	0	3.0	
i 1	476.51622448979595	2.02	72	701	3	5	10	0	0	-1	0	0	0	3.0	
i 1	476.75108163265304	1.01	74	701	6	1	6	16	0	1	16	0	0	2.0	
i 1	476.76261904761907	1.5150000000000001	73	701	3	24	5	8	0	-1	8	0	0	4.0	
i 1	476.76550340136055	7.8275	63	701	4	26	1	16	0	1	16	0	0	1.1853860203341497	
i 1	476.9866598639456	0.2525	72	1087	6	5	11	0	0	0	0	0	0	3.0	
i 1	477.24819727891156	0.2525	71	701	5	9	9	8	0	-1	8	0	0	3.0	
i 1	477.25973469387753	1.2625	77	701	4	24	5	16	0	2	16	0	0	5.0	
i 1	477.51261904761907	0.7575000000000001	74	203	5	2	15	8	0	-1	8	0	0	4.0	
i 1	477.7359387755102	0.2525	72	1087	6	5	14	0	0	0	0	0	0	3.0	
i 1	477.75108163265304	1.7675	71	701	4	4	16	8	0	-2	8	0	0	4.0	
i 1	477.75180272108844	0.2525	70	1087	3	24	13	2	0	-1	2	0	0	4.0	
i 1	477.75757142857145	0.2525	74	203	5	1	8	17	0	2	17	0	0	2.0	
i 1	477.7582925170068	1.7675	71	1087	4	4	4	2	0	-2	2	0	0	4.0	
i 1	477.99314965986395	0.2525	72	1087	3	5	10	1	0	0	1	0	0	3.0	
i 1	478.00757142857145	0.2525	73	701	3	24	7	2	0	-2	2	0	0	4.0	
i 1	478.50685034013605	0.2525	77	1087	4	1	14	16	0	1	16	0	0	2.0	
i 1	478.51189795918367	1.2625	74	701	6	1	1	17	0	1	17	0	0	2.0	
i 1	479.0176666666667	1.7675	72	1087	5	5	6	0	0	0	0	0	0	3.0	
i 1	479.23738095238093	1.2625	77	1087	4	1	8	16	0	1	16	0	0	2.0	
i 1	479.26622448979595	0.505	74	701	6	1	14	16	0	1	16	0	0	2.0	
i 1	479.4866598639456	0.505	70	1087	3	24	10	2	0	-1	2	0	0	4.0	
i 1	479.4917074829932	0.505	70	701	3	24	10	2	0	-1	2	0	0	4.0	
i 1	479.73738095238093	0.2525	71	701	5	9	5	8	0	-1	8	0	0	3.0	
i 1	479.73954421768707	0.7575000000000001	74	701	6	1	7	16	0	1	16	0	0	2.0	
i 1	479.7445918367347	7.8275	63	701	4	26	6	1	0	2	1	0	0	1.1853860203341497	
i 1	479.74819727891156	1.5150000000000001	71	701	5	3	14	8	0	-2	8	0	0	4.0	
i 1	479.76550340136055	1.5150000000000001	71	1087	4	3	6	8	0	-1	8	0	0	4.0	
i 1	479.98521768707485	1.01	70	701	3	24	4	8	0	-1	8	0	0	4.0	
i 1	479.9909863945578	1.01	73	701	3	24	5	8	0	-1	8	0	0	4.0	
i 1	479.9960340136054	0.2525	74	203	5	2	12	8	0	-1	8	0	0	4.0	
i 1	480.0003605442177	2.02	69	203	6	5	1	1	0	0	1	0	0	3.0	
i 1	480.2445918367347	1.5150000000000001	74	701	6	1	13	16	0	1	16	0	0	2.0	
i 1	480.2611768707483	1.5150000000000001	77	203	5	1	1	17	0	1	17	0	0	2.0	
i 1	480.73810204081633	0.2525	77	1087	4	1	1	16	0	1	16	0	0	2.0	
i 1	480.7445918367347	0.2525	71	701	4	4	4	8	0	-2	8	0	0	4.0	
i 1	481.0046870748299	1.7675	74	203	5	2	5	8	0	-1	8	0	0	4.0	
i 1	481.01045578231293	0.2525	74	701	6	1	5	17	0	1	17	0	0	2.0	
i 1	481.0176666666667	1.7675	71	701	5	9	1	8	0	-1	8	0	0	3.0	
i 1	481.24891836734696	1.2625	73	701	3	24	14	8	0	-1	8	0	0	4.0	
i 1	481.5003605442177	0.505	77	701	4	24	8	16	0	2	16	0	0	5.0	
i 1	481.50757142857145	2.02	74	701	6	1	3	17	0	1	17	0	0	2.0	
i 1	481.7330544217687	0.7575000000000001	72	1087	5	5	15	1	0	0	1	0	0	3.0	
i 1	481.74387074829934	0.7575000000000001	72	701	3	5	7	1	0	0	1	0	0	3.0	
i 1	481.98449659863945	0.2525	74	701	6	1	10	16	0	1	16	0	0	2.0	
i 1	481.9967551020408	0.7575000000000001	69	701	3	5	2	0	0	0	0	0	0	3.0	
i 1	482.01189795918367	1.7675	69	203	6	5	8	0	0	0	0	0	0	3.0	
i 1	482.2467551020408	0.2525	70	701	3	24	12	8	0	-1	8	0	0	4.0	
i 1	482.4823333333333	0.2525	72	701	3	5	4	0	0	-1	0	0	0	3.0	
i 1	482.49314965986395	2.02	71	701	4	4	2	8	0	-2	8	0	0	4.0	
i 1	482.5046870748299	0.2525	73	1087	3	24	10	2	0	-2	2	0	0	4.0	
i 1	482.73738095238093	5.05	73	701	3	24	1	8	0	-1	8	0	0	4.0	
i 1	482.7539659863946	6.565	61	701	3	27	13	16	0	1	16	0	0	1.7780790305012246	
i 1	482.75612925170066	1.01	69	701	6	5	8	0	0	0	0	0	0	3.0	
i 1	482.7590136054422	1.2625	73	701	3	24	9	8	0	-2	8	0	0	4.0	
i 1	482.76045578231293	0.505	69	203	6	5	12	1	0	0	1	0	0	3.0	
i 1	483.00757142857145	1.7675	74	701	6	1	4	16	0	1	16	0	0	2.0	
i 1	483.4859387755102	0.7575000000000001	72	1087	5	5	2	0	0	0	0	0	0	3.0	
i 1	483.98521768707485	0.505	71	701	5	9	2	8	0	-1	8	0	0	3.0	
i 1	484.00757142857145	1.2625	69	203	6	5	16	1	0	0	1	0	0	3.0	
i 1	484.2445918367347	1.5150000000000001	77	203	5	1	15	17	0	1	17	0	0	2.0	
i 1	484.25757142857145	0.7575000000000001	73	1087	3	24	16	8	0	-1	8	0	0	4.0	
i 1	484.4967551020408	1.7675	71	1087	4	3	6	8	0	-1	8	0	0	4.0	
i 1	484.49891836734696	1.2625	71	701	5	3	12	8	0	-2	8	0	0	4.0	
i 1	484.50180272108844	0.2525	71	701	4	9	12	8	0	-1	8	0	0	3.0	
i 1	484.7409863945578	1.5150000000000001	72	1087	5	5	11	1	0	0	1	0	0	3.0	
i 1	484.75685034013605	1.5150000000000001	72	701	3	5	2	1	0	0	1	0	0	3.0	
i 1	485.0140612244898	0.2525	77	1087	4	1	1	16	0	1	16	0	0	2.0	
i 1	485.24314965986395	0.2525	71	701	4	4	13	8	0	-2	8	0	0	4.0	
i 1	485.24819727891156	1.7675	77	1087	4	24	4	16	0	2	16	0	0	5.0	
i 1	485.26189795918367	1.2625	77	701	4	24	12	16	0	2	16	0	0	5.0	
i 1	485.7409863945578	0.7575000000000001	70	701	3	24	6	2	0	-1	2	0	0	4.0	
i 1	485.7417074829932	1.01	71	701	5	9	6	8	0	-1	8	0	0	3.0	
i 1	485.7546870748299	1.01	74	203	5	2	16	8	0	-1	8	0	0	4.0	
i 1	485.75685034013605	0.505	70	1087	3	24	10	8	0	-1	8	0	0	4.0	
i 1	485.76189795918367	3.535	61	701	3	27	13	16	0	1	16	0	0	1.7780790305012246	
i 1	485.9917074829932	1.7675	74	701	4	1	11	17	0	1	17	0	0	2.0	
i 1	486.01189795918367	1.7675	74	203	5	1	14	17	0	2	17	0	0	2.0	
i 1	486.2359387755102	2.02	71	1087	4	4	14	2	0	-2	2	0	0	4.0	
i 1	486.24819727891156	1.5150000000000001	73	701	3	24	9	2	0	-2	2	0	0	4.0	
i 1	486.25252380952384	2.02	71	701	4	4	14	8	0	-2	8	0	0	4.0	
i 1	486.48810204081633	0.2525	72	701	6	5	7	0	0	-1	0	0	0	3.0	
i 1	486.75757142857145	0.2525	74	203	5	2	3	8	0	-1	8	0	0	4.0	
i 1	487.2453129251701	0.7575000000000001	74	701	6	1	4	16	0	1	16	0	0	2.0	
i 1	487.24819727891156	2.02	70	701	3	24	16	2	0	-1	2	0	0	4.0	
i 1	487.25685034013605	0.7575000000000001	77	1087	4	1	1	16	0	1	16	0	0	2.0	
i 1	487.5090136054422	1.7675	77	203	5	1	1	17	0	1	17	0	0	2.0	
i 1	487.74242857142855	1.5150000000000001	71	701	4	9	6	8	0	-1	8	0	0	3.0	
i 1	487.74314965986395	1.5150000000000001	69	203	6	5	9	1	0	0	1	0	0	3.0	
i 1	487.7496394557823	1.5150000000000001	72	701	5	5	16	0	0	-1	0	0	0	3.0	
i 1	487.7539659863946	1.5150000000000001	74	203	5	2	13	8	0	-1	8	0	0	4.0	
i 1	488.01045578231293	0.2525	77	1087	4	24	8	16	0	2	16	0	0	5.0	
i 1	488.24242857142855	0.2525	71	701	4	9	4	8	0	-1	8	0	0	3.0	
i 1	488.2546870748299	0.2525	69	203	6	5	3	0	0	0	0	0	0	3.0	
i 1	488.26478231292515	0.2525	74	203	5	1	8	17	0	2	17	0	0	2.0	
i 1	488.4967551020408	0.505	77	701	4	24	12	16	0	2	16	0	0	5.0	
i 1	488.49747619047616	0.7575000000000001	73	701	3	24	8	8	0	-1	8	0	0	4.0	
i 1	488.49891836734696	0.2525	72	1087	5	5	7	1	0	0	1	0	0	3.0	
i 1	489.01261904761907	0.2525	74	203	5	2	3	8	0	-1	8	0	0	4.0	
i 1	489.01478231292515	0.2525	74	203	5	1	12	17	0	2	17	0	0	2.0	
i 1	489.2409863945578	2.2725	70	1081	3	24	12	2	0	-2	2	0	0	4.0	
i 1	489.2445918367347	4.2925	61	379	3	27	7	16	0	1	16	0	0	1.7780790305012246	
i 1	489.2467551020408	1.2625	63	379	3	27	8	1	0	2	1	0	0	1.7780790305012246	
i 1	489.25612925170066	2.02	72	379	3	5	14	1	0	-1	1	0	0	3.0	
i 1	489.25685034013605	1.2625	74	695	5	2	16	2	0	-1	2	0	0	4.0	
i 1	489.2633401360544	1.01	74	1081	4	9	13	2	0	-1	2	0	0	3.0	
i 1	489.2633401360544	0.505	72	1081	5	5	10	1	0	-1	1	0	0	3.0	
i 1	489.2640612244898	1.7675	74	1081	4	1	6	16	0	2	16	0	0	2.0	
i 1	489.4859387755102	0.2525	72	379	6	5	9	0	0	0	0	0	0	3.0	
i 1	489.75180272108844	1.7675	71	695	5	3	6	2	0	-1	2	0	0	4.0	
i 1	490.01478231292515	0.2525	74	695	4	24	16	17	0	1	17	0	0	5.0	
i 1	490.2453129251701	1.7675	74	379	4	24	14	17	0	2	17	0	0	5.0	
i 1	490.25973469387753	0.2525	72	379	6	5	5	0	0	0	0	0	0	3.0	
i 1	490.4830544217687	15.4025	63	379	1	27	5	1	0	252	1	307	0	1.7780790305012246	
i 1	490.4888231292517	0.2525	74	695	5	2	3	8	0	-1	8	0	0	4.0	
i 1	490.4960340136054	2.02	72	1081	5	5	11	0	0	-1	0	0	0	3.0	
i 1	490.4996394557823	1.2625	74	695	4	24	11	17	0	1	17	0	0	5.0	
i 1	490.51045578231293	1.01	74	379	4	3	15	8	0	-1	8	0	0	4.0	
i 1	490.7330544217687	1.5150000000000001	71	1081	4	9	8	8	0	-1	8	0	0	3.0	
i 1	490.74026530612247	1.7675	69	695	4	5	2	0	0	-1	0	0	0	3.0	
i 1	490.99242857142855	2.02	77	695	6	1	9	17	0	2	17	0	0	2.0	
i 1	491.0032448979592	1.01	74	695	5	2	16	8	0	-1	8	0	0	4.0	
i 1	491.2546870748299	0.2525	72	1081	5	5	16	1	0	-1	1	0	0	3.0	
i 1	491.48810204081633	0.2525	72	695	6	5	16	0	0	0	0	0	0	3.0	
i 1	491.51045578231293	2.02	74	379	4	4	14	2	0	-2	2	0	0	4.0	
i 1	491.5140612244898	2.2725	71	695	4	4	5	8	0	-2	8	0	0	4.0	
i 1	492.00757142857145	0.2525	74	695	5	1	12	16	0	1	16	0	0	2.0	
i 1	492.24891836734696	0.2525	74	379	4	3	12	8	0	-1	8	0	0	4.0	
i 1	492.25757142857145	0.2525	70	695	4	24	3	8	0	-2	8	0	0	4.0	
i 1	492.2582925170068	0.2525	74	379	4	24	10	17	0	2	17	0	0	5.0	
i 1	492.4830544217687	1.2625	74	379	4	1	5	17	0	1	17	0	0	2.0	
i 1	492.4830544217687	1.01	72	695	6	5	14	0	0	0	0	0	0	3.0	
i 1	492.4967551020408	0.2525	71	695	5	3	11	2	0	-1	2	0	0	4.0	
i 1	492.5169455782313	0.7575000000000001	74	695	5	1	11	16	0	1	16	0	0	2.0	
i 1	492.7539659863946	0.7575000000000001	74	695	5	1	6	17	0	1	17	0	0	2.0	
i 1	493.0046870748299	0.2525	69	695	4	5	15	0	0	-1	0	0	0	3.0	
i 1	493.0046870748299	2.2725	70	379	3	24	6	2	0	-2	2	0	0	4.0	
i 1	493.2359387755102	0.2525	72	1081	5	5	6	0	0	-1	0	0	0	3.0	
i 1	493.4953129251701	1.2625	74	695	6	1	14	17	0	1	17	0	0	2.0	
i 1	493.49747619047616	1.01	72	695	4	5	10	0	0	0	0	0	0	3.0	
i 1	493.49819727891156	1.5150000000000001	74	695	6	2	12	2	0	-1	2	0	0	4.0	
i 1	493.5082925170068	12.3725	61	379	1	27	7	16	0	252	16	307	0	1.7780790305012246	
i 1	493.7546870748299	0.2525	74	695	5	1	7	16	0	1	16	0	0	2.0	
i 1	493.7582925170068	0.2525	74	379	4	3	15	8	0	-1	8	0	0	4.0	
i 1	493.76045578231293	0.2525	69	695	6	5	16	1	0	-1	1	0	0	3.0	
i 1	493.7633401360544	0.505	70	695	4	24	12	8	0	-2	8	0	0	4.0	
i 1	493.98738095238093	0.2525	74	379	4	4	10	2	0	-2	2	0	0	4.0	
i 1	493.9953129251701	1.2625	72	379	5	5	9	1	0	-1	1	0	0	3.0	
i 1	494.0090136054422	0.7575000000000001	69	695	6	5	2	0	0	-1	0	0	0	3.0	
i 1	494.23954421768707	1.7675	72	1081	5	5	6	0	0	-1	0	0	0	3.0	
i 1	494.24026530612247	1.5150000000000001	69	695	4	5	12	0	0	-1	0	0	0	3.0	
i 1	494.2582925170068	2.7775	74	379	4	24	11	17	0	2	17	0	0	5.0	
i 1	494.2590136054422	3.0300000000000002	74	695	4	24	2	17	0	1	17	0	0	5.0	
i 1	494.26045578231293	0.7575000000000001	73	379	3	24	8	8	0	-1	8	0	0	4.0	
i 1	494.5046870748299	2.02	74	379	4	3	10	8	0	-1	8	0	0	4.0	
i 1	494.9888231292517	0.505	74	379	4	1	6	17	0	1	17	0	0	2.0	
i 1	495.23738095238093	1.7675	72	379	5	5	3	0	0	0	0	0	0	3.0	
i 1	495.2417074829932	1.2625	69	695	6	5	10	1	0	-1	1	0	0	3.0	
i 1	495.26622448979595	1.2625	70	379	3	24	14	2	0	-2	2	0	0	4.0	
i 1	495.49387074829934	0.2525	74	695	5	1	8	16	0	1	16	0	0	2.0	
i 1	495.50973469387753	0.505	71	695	4	4	2	8	0	-2	8	0	0	4.0	
i 1	495.73449659863945	0.505	74	1081	4	1	3	16	0	2	16	0	0	2.0	
i 1	495.75685034013605	1.7675	70	379	3	24	3	2	0	-2	2	0	0	4.0	
i 1	496.2453129251701	1.7675	71	695	4	4	12	8	0	-2	8	0	0	4.0	
i 1	496.2467551020408	0.2525	69	695	6	5	15	0	0	-1	0	0	0	3.0	
i 1	496.48377551020405	1.2625	74	695	6	1	14	16	0	1	16	0	0	2.0	
i 1	496.4953129251701	1.7675	72	1081	5	5	3	1	0	-1	1	0	0	3.0	
i 1	496.5046870748299	0.505	69	695	4	5	10	1	0	-1	1	0	0	3.0	
i 1	496.51550340136055	1.7675	72	695	4	5	8	0	0	0	0	0	0	3.0	
i 1	496.73738095238093	0.2525	71	695	5	3	12	2	0	-1	2	0	0	4.0	
i 1	497.0133401360544	2.02	70	1081	3	24	13	2	0	-2	2	0	0	4.0	
i 1	497.0176666666667	0.2525	70	695	4	24	11	2	0	-1	2	0	0	4.0	
i 1	497.23738095238093	0.505	70	379	3	24	12	8	0	-2	8	0	0	4.0	
i 1	497.2417074829932	1.7675	74	695	6	1	15	17	0	1	17	0	0	2.0	
i 1	497.4909863945578	1.01	74	695	6	2	13	2	0	-1	2	0	0	4.0	
i 1	497.5046870748299	1.01	74	1081	4	9	15	2	0	-1	2	0	0	3.0	
i 1	497.50685034013605	0.2525	69	695	4	5	12	1	0	-1	1	0	0	3.0	
i 1	497.73377551020405	0.2525	73	695	4	24	7	8	0	-1	8	0	0	4.0	
i 1	497.7460340136054	1.2625	70	379	3	24	12	2	0	-2	2	0	0	4.0	
i 1	497.76550340136055	1.01	72	379	5	5	2	1	0	-1	1	0	0	3.0	
i 1	497.7669455782313	1.01	69	695	6	5	7	0	0	-1	0	0	0	3.0	
i 1	497.9859387755102	2.02	74	379	4	3	4	8	0	-1	8	0	0	4.0	
i 1	497.9909863945578	1.5150000000000001	71	695	5	3	9	2	0	-1	2	0	0	4.0	
i 1	498.0090136054422	0.2525	74	379	4	24	13	17	0	2	17	0	0	5.0	
i 1	498.23954421768707	2.02	72	1081	5	5	1	0	0	-1	0	0	0	3.0	
i 1	498.25108163265304	2.02	69	695	4	5	14	0	0	-1	0	0	0	3.0	
i 1	498.7546870748299	2.02	77	695	6	1	7	17	0	2	17	0	0	2.0	
i 1	498.75612925170066	0.2525	72	1081	5	5	11	1	0	-1	1	0	0	3.0	
i 1	498.76045578231293	0.2525	74	695	6	2	11	2	0	-1	2	0	0	4.0	
i 1	499.2453129251701	1.7675	70	1081	3	24	2	2	0	-2	2	0	0	4.0	
i 1	499.26045578231293	0.2525	70	695	4	24	11	8	0	-2	8	0	0	4.0	
i 1	499.4917074829932	2.02	74	695	6	2	15	8	0	-1	8	0	0	4.0	
i 1	499.5054081632653	0.2525	70	379	3	24	13	8	0	-2	8	0	0	4.0	
i 1	499.5082925170068	2.2725	71	1081	4	9	12	8	0	-1	8	0	0	3.0	
i 1	499.73521768707485	0.7575000000000001	72	379	5	5	5	0	0	0	0	0	0	3.0	
i 1	499.74314965986395	0.2525	74	695	6	1	10	16	0	1	16	0	0	2.0	
i 1	499.7546870748299	0.2525	73	695	4	24	9	2	0	-2	2	0	0	4.0	
i 1	499.9823333333333	0.7575000000000001	73	379	3	24	1	8	0	-2	8	0	0	4.0	
i 1	499.98810204081633	0.2525	74	695	6	1	3	17	0	1	17	0	0	2.0	
i 1	499.9909863945578	0.2525	71	695	4	4	13	8	0	-2	8	0	0	4.0	
i 1	500.0003605442177	1.5150000000000001	72	695	4	5	8	0	0	0	0	0	0	3.0	
i 1	500.2640612244898	1.7675	74	695	6	1	16	16	0	1	16	0	0	2.0	
i 1	500.26550340136055	0.2525	74	695	6	2	3	2	0	-1	2	0	0	4.0	
i 1	500.7633401360544	0.2525	74	379	4	3	13	8	0	-1	8	0	0	4.0	
i 1	500.7676666666667	0.505	73	695	4	24	5	8	0	-2	8	0	0	4.0	
i 1	500.9859387755102	1.5150000000000001	70	379	3	24	1	2	0	-2	2	0	0	4.0	
i 1	501.00685034013605	0.2525	77	695	6	1	8	17	0	2	17	0	0	2.0	
i 1	501.0090136054422	2.02	72	379	5	5	11	1	0	-1	1	0	0	3.0	
i 1	501.0111768707483	1.5150000000000001	71	695	4	4	9	8	0	-2	8	0	0	4.0	
i 1	501.01189795918367	2.02	74	379	4	4	6	2	0	-2	2	0	0	4.0	
i 1	501.26045578231293	0.2525	74	695	4	24	11	17	0	1	17	0	0	5.0	
i 1	501.26261904761907	0.2525	73	379	3	24	1	2	0	-2	2	0	0	4.0	
i 1	501.4996394557823	1.01	70	1081	3	24	15	2	0	-2	2	0	0	4.0	
i 1	501.5046870748299	1.5150000000000001	74	695	6	1	5	17	0	1	17	0	0	2.0	
i 1	501.51261904761907	0.2525	70	695	4	24	5	8	0	-2	8	0	0	4.0	
i 1	501.76550340136055	0.7575000000000001	70	379	3	24	10	8	0	-2	8	0	0	4.0	
i 1	501.99891836734696	0.2525	74	1081	4	9	7	2	0	-1	2	0	0	3.0	
i 1	502.2460340136054	1.7675	69	695	4	5	1	0	0	-1	0	0	0	3.0	
i 1	502.2539659863946	3.0300000000000002	74	379	4	24	10	17	0	2	17	0	0	5.0	
i 1	502.25973469387753	1.01	74	695	6	2	16	2	0	-1	2	0	0	4.0	
i 1	502.49026530612247	0.505	71	695	4	4	11	8	0	-2	8	0	0	4.0	
i 1	502.50757142857145	2.7775	74	695	4	24	4	17	0	1	17	0	0	5.0	
i 1	502.5090136054422	0.7575000000000001	74	1081	4	9	13	2	0	-1	2	0	0	3.0	
i 1	502.5111768707483	1.01	70	1081	3	24	5	2	0	-2	2	0	0	6.0155750592515815	
i 1	502.5176666666667	0.7575000000000001	70	379	2	24	10	8	0	-2	8	0	0	6.0155750592515815	
i 1	502.76189795918367	1.7675	74	379	4	3	14	8	0	-1	8	0	0	4.0	
i 1	503.0082925170068	0.505	69	695	4	5	9	0	0	-1	0	0	0	3.0	
i 1	503.01045578231293	0.7575000000000001	70	1081	3	20	7	2	0	-1	2	0	0	2.0155750592515815	
i 1	503.01622448979595	0.2525	77	1081	5	1	16	17	0	1	17	0	0	2.0	
i 1	503.23954421768707	0.2525	70	695	3	20	7	8	0	-2	8	0	0	2.0155750592515815	
i 1	503.2546870748299	2.525	70	379	3	20	11	8	0	-2	8	0	0	2.0155750592515815	
i 1	503.25612925170066	0.2525	73	695	3	24	2	2	0	-2	2	0	0	6.0155750592515815	
i 1	503.26189795918367	0.2525	73	695	3	20	3	8	0	-1	8	0	0	2.0155750592515815	
i 1	503.2640612244898	0.2525	74	695	6	2	2	8	0	-1	8	0	0	4.0	
i 1	503.4866598639456	0.2525	77	1081	5	1	14	17	0	1	17	0	0	2.0	
i 1	503.4866598639456	1.01	72	379	5	5	15	0	0	0	0	0	0	3.0	
i 1	503.50685034013605	0.2525	74	379	4	4	3	2	0	-2	2	0	0	4.0	
i 1	503.75108163265304	1.5150000000000001	74	695	6	2	5	8	0	-1	8	0	0	4.0	
i 1	503.75757142857145	0.505	74	379	4	1	2	17	0	1	17	0	0	2.0	
i 1	504.0046870748299	1.5150000000000001	72	1081	5	5	10	1	0	-1	1	0	0	3.0	
i 1	504.2366598639456	1.2625	74	1081	4	1	16	16	0	2	16	0	0	2.0	
i 1	504.23954421768707	0.2525	70	379	2	24	4	2	0	-2	2	0	0	6.0155750592515815	
i 1	504.2409863945578	1.5150000000000001	70	1081	3	20	16	2	0	-1	2	0	0	2.0155750592515815	
i 1	504.26045578231293	1.01	74	695	6	1	4	16	0	1	16	0	0	2.0	
i 1	504.48521768707485	1.2625	74	695	6	1	7	17	0	1	17	0	0	2.0	
i 1	504.49387074829934	1.01	74	379	4	1	16	17	0	1	17	0	0	2.0	
i 1	504.49387074829934	0.2525	70	695	3	20	14	8	0	-2	8	0	0	2.0155750592515815	
i 1	504.49747619047616	1.2625	74	379	4	4	9	2	0	-2	2	0	0	4.0	
i 1	504.51189795918367	0.7575000000000001	70	1081	3	24	1	2	0	-2	2	0	0	6.0155750592515815	
i 1	504.5169455782313	0.505	69	695	4	5	4	0	0	-1	0	0	0	3.0	
i 1	504.74891836734696	0.505	73	379	2	24	12	2	0	-2	2	0	0	6.0155750592515815	
i 1	504.75108163265304	0.7575000000000001	73	1081	2	20	11	2	0	-2	2	0	0	2.0155750592515815	
i 1	504.98449659863945	0.2525	72	379	5	5	5	1	0	-1	1	0	0	3.0	
i 1	505.2330544217687	1.2625	71	695	5	3	14	2	0	-1	2	0	0	4.0	
i 1	505.25685034013605	0.505	69	695	4	5	10	0	0	-1	0	0	0	3.0	
i 1	505.4823333333333	0.2525	74	1081	5	1	14	16	0	2	16	0	0	2.0	
i 1	505.4960340136054	0.2525	77	695	6	1	6	17	0	2	17	0	0	2.0	
i 1	505.50252380952384	0.2525	72	1081	3	5	8	1	0	-1	1	0	0	3.0	
i 1	505.73449659863945	1.2625	74	197	4	4	7	8	0	-1	8	0	0	4.0	
i 1	505.73449659863945	0.2525	70	695	3	20	1	8	0	-2	8	0	0	2.0155750592515815	
i 1	505.7388231292517	1.5150000000000001	74	197	6	1	1	17	0	2	17	0	0	2.0	
i 1	505.7445918367347	1.5150000000000001	70	197	3	24	8	8	0	-1	8	0	0	6.0155750592515815	
i 1	505.7460340136054	1.01	74	899	6	1	10	16	0	1	16	0	0	2.0	
i 1	505.75252380952384	1.2625	70	197	3	24	7	8	0	-2	8	0	0	6.0155750592515815	
i 1	505.7582925170068	0.2525	70	695	3	24	12	8	0	-1	8	0	0	6.0155750592515815	
i 1	505.76189795918367	0.2525	70	899	3	20	5	8	0	-1	8	0	0	2.0155750592515815	
i 1	505.7640612244898	1.2625	73	197	3	20	5	8	0	-1	8	0	0	2.0155750592515815	
i 1	505.76622448979595	0.2525	74	899	6	1	3	16	0	2	16	0	0	2.0	
i 1	505.76622448979595	1.2625	69	197	5	5	11	0	0	-1	0	0	0	3.0	
i 1	505.99819727891156	0.2525	74	197	4	1	5	17	0	2	17	0	0	2.0	
i 1	506.01261904761907	0.2525	70	197	2	24	12	8	0	-2	8	0	0	6.0155750592515815	
i 1	506.0140612244898	0.2525	74	197	6	9	7	8	0	-1	8	0	0	3.0	
i 1	506.01478231292515	0.2525	73	197	2	20	2	8	0	-2	8	0	0	2.0155750592515815	
i 1	506.2417074829932	0.2525	69	695	4	5	16	0	0	-1	0	0	0	3.0	
i 1	506.24819727891156	0.2525	73	695	3	20	10	2	0	-2	2	0	0	2.0155750592515815	
i 1	506.2590136054422	0.2525	73	899	3	20	13	8	0	-2	8	0	0	2.0155750592515815	
i 1	506.4909863945578	0.505	74	583	4	4	13	8	0	-2	8	0	0	4.0	
i 1	506.49747619047616	0.505	72	583	4	5	12	0	0	-1	0	0	0	3.0	
i 1	506.5003605442177	0.2525	72	899	4	5	4	1	0	0	1	0	0	3.0	
i 1	506.50252380952384	0.505	73	197	2	20	13	2	0	-2	2	0	0	2.0155750592515815	
i 1	506.50973469387753	0.505	69	583	4	5	12	0	0	-1	0	0	0	3.0	
i 1	506.73738095238093	1.5150000000000001	74	197	6	1	2	16	0	1	16	0	0	2.0	
i 1	506.7496394557823	0.2525	74	583	4	24	11	17	0	1	17	0	0	5.0	
i 1	506.98738095238093	2.02	74	1081	6	2	7	2	0	-2	2	0	0	4.0	
i 1	506.9909863945578	1.2625	74	695	4	24	10	16	0	2	16	0	0	5.0	
i 1	507.00252380952384	0.7575000000000001	70	695	2	20	5	8	0	-2	8	0	0	2.0155750592515815	
i 1	507.0032448979592	0.505	77	1081	6	1	10	17	0	1	17	0	0	2.0	
i 1	507.0032448979592	0.2525	69	695	4	5	12	0	0	-1	0	0	0	3.0	
i 1	507.0039659863946	10.605	61	695	1	27	6	1	0	252	1	307	0	1.7780790305012246	
i 1	507.0082925170068	0.7575000000000001	70	695	2	24	11	8	0	-2	8	0	0	6.0155750592515815	
i 1	507.01478231292515	2.02	74	695	4	3	11	2	0	-2	2	0	0	4.0	
i 1	507.01622448979595	4.04	70	695	3	20	6	2	0	-1	2	0	0	2.0155750592515815	
i 1	507.49387074829934	0.2525	70	197	3	20	2	2	0	-2	2	0	0	2.0155750592515815	
i 1	507.49747619047616	1.7675	77	695	4	24	10	16	0	1	16	0	0	5.0	
i 1	507.49747619047616	1.01	70	197	4	20	11	8	0	-2	8	0	0	2.0155750592515815	
i 1	507.50757142857145	1.7675	77	695	6	1	9	16	0	1	16	0	0	2.0	
i 1	507.51045578231293	0.505	71	695	4	4	4	2	0	-1	2	0	0	4.0	
i 1	507.7409863945578	0.2525	70	695	3	24	6	8	0	-2	8	0	0	6.0155750592515815	
i 1	507.7669455782313	0.2525	70	695	3	20	4	8	0	-2	8	0	0	2.0155750592515815	
i 1	507.9823333333333	2.2725	70	197	3	20	11	8	0	-1	8	0	0	2.0155750592515815	
i 1	507.99819727891156	2.2725	70	695	2	24	3	8	0	-2	8	0	0	6.0155750592515815	
i 1	508.0039659863946	0.2525	70	695	2	20	3	8	0	-2	8	0	0	2.0155750592515815	
i 1	508.2640612244898	1.5150000000000001	77	1081	6	1	13	17	0	1	17	0	0	2.0	
i 1	508.49242857142855	2.02	69	695	4	5	1	0	0	-1	0	0	0	3.0	
i 1	508.51622448979595	2.02	69	197	4	5	4	0	0	-1	0	0	0	3.0	
i 1	508.74026530612247	1.5150000000000001	70	695	2	20	13	8	0	-2	8	0	0	2.0155750592515815	
i 1	508.7467551020408	2.7775	70	695	3	24	11	2	0	-2	2	0	0	6.0155750592515815	
i 1	509.0090136054422	2.2725	74	695	4	24	4	16	0	2	16	0	0	5.0	
i 1	509.2409863945578	0.2525	69	695	3	5	14	1	0	-1	1	0	0	3.0	
i 1	509.5090136054422	0.505	74	695	4	3	15	2	0	-2	2	0	0	4.0	
i 1	509.75108163265304	0.505	74	1081	6	2	12	2	0	-2	2	0	0	4.0	
i 1	509.9866598639456	1.7675	69	695	4	5	3	0	0	-1	0	0	0	3.0	
i 1	510.2323333333333	2.2725	71	695	5	3	4	2	0	-1	2	0	0	4.0	
i 1	510.23449659863945	0.7575000000000001	73	1081	3	20	7	8	0	-1	8	0	0	2.0155750592515815	
i 1	510.24314965986395	2.02	74	695	4	4	10	8	0	-2	8	0	0	4.0	
i 1	510.2460340136054	1.2625	77	1081	6	1	15	17	0	1	17	0	0	2.0	
i 1	510.25108163265304	2.02	74	695	5	1	5	16	0	2	16	0	0	2.0	
i 1	510.25685034013605	0.7575000000000001	70	695	3	24	10	8	0	-2	8	0	0	6.0155750592515815	
i 1	510.50973469387753	0.7575000000000001	70	197	3	24	16	8	0	-1	8	0	0	6.0155750592515815	
i 1	510.9866598639456	0.7575000000000001	70	695	2	20	14	8	0	-2	8	0	0	2.0155750592515815	
i 1	511.00252380952384	0.7575000000000001	70	197	3	20	12	8	0	-2	8	0	0	2.0155750592515815	
i 1	511.01189795918367	0.2525	71	695	4	4	15	2	0	-1	2	0	0	4.0	
i 1	511.01261904761907	0.7575000000000001	70	695	2	24	6	8	0	-2	8	0	0	6.0155750592515815	
i 1	511.0169455782313	0.505	74	1081	4	1	7	17	0	1	17	0	0	2.0	
i 1	511.2417074829932	3.2825	70	695	3	20	2	2	0	-1	2	0	0	2.0155750592515815	
i 1	511.25108163265304	1.5150000000000001	69	695	3	5	14	1	0	-1	1	0	0	3.0	
i 1	511.26478231292515	0.2525	71	197	6	9	14	8	0	-1	8	0	0	3.0	
i 1	511.4830544217687	0.7575000000000001	77	1081	4	1	16	17	0	1	17	0	0	2.0	
i 1	511.5111768707483	0.505	69	695	3	5	5	1	0	0	1	0	0	3.0	
i 1	511.51189795918367	2.02	77	695	6	1	6	16	0	1	16	0	0	2.0	
i 1	511.51478231292515	2.02	77	695	4	24	1	16	0	1	16	0	0	5.0	
i 1	511.5176666666667	1.7675	70	197	3	24	3	8	0	-1	8	0	0	6.0155750592515815	
i 1	511.75252380952384	2.2725	74	1081	6	2	15	2	0	-2	2	0	0	4.0	
i 1	511.7554081632653	0.2525	70	695	3	20	13	8	0	-2	8	0	0	2.0155750592515815	
i 1	511.7640612244898	0.2525	70	695	3	24	2	8	0	-2	8	0	0	6.0155750592515815	
i 1	511.9866598639456	0.2525	70	197	3	20	13	2	0	-1	2	0	0	2.0155750592515815	
i 1	512.0155034013605	0.2525	70	695	2	20	8	8	0	-2	8	0	0	2.0155750592515815	
i 1	512.2554081632653	1.7675	69	695	4	5	4	0	0	-1	0	0	0	3.0	
i 1	512.2590136054422	0.2525	74	1081	4	1	4	17	0	1	17	0	0	2.0	
i 1	512.4902653061224	1.5150000000000001	77	1081	4	1	10	17	0	1	17	0	0	2.0	
i 1	512.501081632653	0.2525	70	695	2	20	16	8	0	-2	8	0	0	2.0155750592515815	
i 1	512.7496394557824	0.2525	73	1081	3	20	1	2	0	-1	2	0	0	2.0155750592515815	
i 1	512.7532448979592	0.2525	70	695	3	24	10	8	0	-2	8	0	0	6.0155750592515815	
i 1	512.7597346938776	0.2525	69	695	3	5	8	1	0	0	1	0	0	3.0	
i 1	512.9909863945578	1.7675	72	1081	4	5	16	1	0	-1	1	0	0	3.0	
i 1	512.9960340136055	1.2625	71	695	4	4	9	2	0	-1	2	0	0	4.0	
i 1	513.0054081632653	1.5150000000000001	70	695	2	24	13	8	0	-2	8	0	0	6.0155750592515815	
i 1	513.0147823129251	0.2525	70	695	2	20	6	8	0	-2	8	0	0	2.0155750592515815	
i 1	513.2402653061224	1.5150000000000001	74	197	6	9	16	8	0	-1	8	0	0	3.0	
i 1	513.2460340136055	2.525	74	197	6	1	4	16	0	1	16	0	0	2.0	
i 1	513.248918367347	2.7775	74	695	4	24	8	16	0	2	16	0	0	5.0	
i 1	513.5061292517007	2.02	71	1081	6	2	4	2	0	-2	2	0	0	4.0	
i 1	513.7388231292517	2.525	69	695	3	5	10	1	0	0	1	0	0	3.0	
i 1	513.7474761904762	2.525	69	695	4	5	1	0	0	-1	0	0	0	3.0	
i 1	514.233775510204	0.2525	70	695	2	24	2	2	0	-2	2	0	0	6.0155750592515815	
i 1	514.2539659863945	0.2525	70	695	2	20	6	8	0	-2	8	0	0	2.0155750592515815	
i 1	514.2676666666666	0.2525	77	1081	4	1	15	17	0	1	17	0	0	2.0	
i 1	514.4881020408163	0.2525	71	695	4	4	16	2	0	-1	2	0	0	4.0	
i 1	514.4981972789116	0.2525	70	695	2	20	7	8	0	-2	8	0	0	4.087976833828202	
i 1	514.498918367347	2.7775	77	695	4	24	2	16	0	1	16	0	0	5.0	
i 1	514.498918367347	9.3425	70	695	2	20	11	2	0	-1	2	0	0	4.087976833828202	
i 1	514.5097346938776	0.2525	74	695	5	1	13	16	0	2	16	0	0	2.0	
i 1	514.5126190476191	1.01	70	695	2	24	8	2	0	-2	2	0	0	8.087976833828202	
i 1	514.5140612244898	0.2525	69	197	4	5	1	0	0	-1	0	0	0	3.0	
i 1	514.7352176870749	0.505	70	1081	3	20	1	8	0	-2	8	0	0	4.087976833828202	
i 1	514.7417074829932	2.7775	74	695	5	3	4	2	0	-2	2	0	0	4.0	
i 1	514.751081632653	2.7775	74	1081	6	2	8	2	0	-2	2	0	0	4.0	
i 1	514.7561292517007	0.505	70	695	3	24	13	8	0	-2	8	0	0	8.087976833828202	
i 1	514.756850340136	1.7675	69	695	3	5	8	1	0	-1	1	0	0	3.0	
i 1	514.9981972789116	0.2525	72	1081	4	5	9	1	0	-1	1	0	0	3.0	
i 1	515.2611768707483	1.5150000000000001	70	695	2	24	15	8	0	-2	8	0	0	8.087976833828202	
i 1	515.2655034013605	1.5150000000000001	70	197	2	20	2	2	0	-1	2	0	0	4.087976833828202	
i 1	515.493149659864	2.02	69	695	4	5	10	0	0	-1	0	0	0	3.0	
i 1	515.4938707482993	0.505	74	695	4	4	6	8	0	-2	8	0	0	4.0	
i 1	516.0025238095238	0.2525	74	197	6	1	6	17	0	2	17	0	0	2.0	
i 1	516.0118979591837	0.2525	71	695	4	4	4	2	0	-1	2	0	0	4.0	
i 1	516.2539659863945	0.2525	74	695	4	4	16	8	0	-2	8	0	0	4.0	
i 1	516.2611768707483	1.2625	77	1081	4	1	5	17	0	1	17	0	0	2.0	
i 1	516.4981972789116	2.02	69	1081	4	5	7	0	0	0	0	0	0	3.0	
i 1	516.5061292517007	1.01	71	695	4	4	7	2	0	-1	2	0	0	4.0	
i 1	516.5126190476191	1.7675	72	197	4	5	12	0	0	-1	0	0	0	3.0	
i 1	516.733775510204	0.2525	70	695	3	20	8	8	0	-2	8	0	0	4.087976833828202	
i 1	516.7676666666666	0.2525	73	1081	3	20	11	8	0	-1	8	0	0	4.087976833828202	
i 1	516.9844965986395	0.505	70	695	2	20	7	8	0	-2	8	0	0	4.087976833828202	
i 1	516.9852176870749	0.505	70	197	3	20	12	8	0	-2	8	0	0	4.087976833828202	
i 1	517.2445918367347	0.2525	74	197	6	1	6	17	0	2	17	0	0	2.0	
i 1	517.4844965986395	0.2525	74	1081	6	2	2	2	0	-2	2	0	0	9.003796959404667	
i 1	517.4945918367347	4.2925	77	1081	4	1	12	17	0	1	17	0	0	9.0	
i 1	517.4945918367347	2.02	74	695	4	24	6	16	0	2	16	0	0	12.0	
i 1	517.4967551020408	1.7675	70	197	2	20	11	8	0	-2	8	0	0	4.087976833828202	
i 1	517.501081632653	4.545	74	695	5	1	2	16	0	2	16	0	0	9.0	
i 1	517.501081632653	1.2625	71	695	4	4	7	2	0	-1	2	0	0	9.003796959404667	
i 1	517.5025238095238	1.2625	74	197	6	9	14	8	0	-1	8	0	0	8.003796959404667	
i 1	517.516224489796	2.2725	69	695	3	5	10	1	0	0	1	0	0	3.0	
i 1	517.748918367347	0.505	74	695	4	4	14	8	0	-2	8	0	0	9.003796959404667	
i 1	517.7626190476191	2.02	70	197	3	24	3	8	0	-1	8	0	0	8.087976833828202	
i 1	517.7640612244898	0.2525	74	695	5	3	10	2	0	-2	2	0	0	9.003796959404667	
i 1	517.7655034013605	2.02	69	695	4	5	8	0	0	-1	0	0	0	3.0	
i 1	517.7655034013605	1.5150000000000001	70	197	2	20	11	8	0	-2	8	0	0	4.087976833828202	
i 1	518.0147823129251	2.525	71	1081	6	2	9	2	0	-2	2	0	0	9.003796959404667	
i 1	518.2554081632653	2.2725	71	197	6	9	12	8	0	-1	8	0	0	8.003796959404667	
i 1	518.4938707482993	0.2525	69	695	4	5	4	0	0	-1	0	0	0	3.0	
i 1	518.5090136054422	0.2525	72	197	4	5	9	0	0	-1	0	0	0	3.0	
i 1	518.7532448979592	0.505	70	695	2	20	10	8	0	-2	8	0	0	4.087976833828202	
i 1	518.7597346938776	0.2525	74	1081	6	2	16	2	0	-2	2	0	0	9.003796959404667	
i 1	518.7604557823129	4.7975	69	695	3	5	13	1	0	-1	1	0	0	3.0	
i 1	518.7640612244898	1.5150000000000001	72	1081	4	5	5	1	0	-1	1	0	0	3.0	
i 1	518.9960340136055	0.505	74	695	5	3	2	2	0	-2	2	0	0	9.003796959404667	
i 1	519.2352176870749	0.2525	73	1081	2	20	13	8	0	-2	8	0	0	4.087976833828202	
i 1	519.2388231292517	1.5150000000000001	71	695	5	3	4	2	0	-1	2	0	0	9.003796959404667	
i 1	519.248918367347	2.525	69	197	4	5	12	0	0	-1	0	0	0	3.0	
i 1	519.2496394557824	2.2725	77	695	4	24	9	16	0	1	16	0	0	12.0	
i 1	519.2640612244898	2.525	69	695	4	5	6	0	0	-1	0	0	0	3.0	
i 1	519.4981972789116	1.01	70	695	2	20	5	8	0	-2	8	0	0	4.087976833828202	
i 1	519.5126190476191	0.2525	70	197	2	20	11	2	0	-1	2	0	0	4.087976833828202	
i 1	519.5176666666666	1.2625	74	695	4	4	13	8	0	-2	8	0	0	9.003796959404667	
i 1	519.743149659864	2.2725	74	1081	6	2	13	2	0	-2	2	0	0	9.003796959404667	
i 1	520.2438707482993	0.2525	69	695	3	5	15	1	0	0	1	0	0	3.0	
i 1	520.7352176870749	1.5150000000000001	70	695	1	24	12	2	0	252	2	307	0	8.087976833828202	
i 1	520.7402653061224	2.02	70	197	2	20	7	2	0	-1	2	0	0	4.087976833828202	
i 1	520.7460340136055	2.7775	72	1081	4	5	12	1	0	-1	1	0	0	3.0	
i 1	520.7633401360545	1.7675	74	197	6	9	3	8	0	-1	8	0	0	8.003796959404667	
i 1	520.7633401360545	3.535	70	197	3	24	5	8	0	-1	8	0	0	8.087976833828202	
i 1	520.9823333333334	2.02	69	695	4	5	13	0	0	-1	0	0	0	3.0	
i 1	520.9888231292517	2.525	74	197	4	1	9	16	0	1	16	0	0	9.0	
i 1	520.9960340136055	2.02	74	695	4	24	8	16	0	2	16	0	0	12.0	
i 1	521.016224489796	2.02	69	695	3	5	10	1	0	0	1	0	0	3.0	
i 1	521.5104557823129	2.7775	71	197	6	9	10	8	0	-1	8	0	0	8.003796959404667	
i 1	521.5155034013605	2.2725	71	1081	6	2	8	2	0	-2	2	0	0	9.003796959404667	
i 1	522.5054081632653	0.2525	71	695	5	3	12	2	0	-1	2	0	0	9.003796959404667	
i 1	522.7590136054422	0.2525	73	1081	2	20	3	2	0	-1	2	0	0	4.087976833828202	
i 1	522.7626190476191	0.2525	70	695	3	24	15	8	0	-2	8	0	0	8.087976833828202	
i 1	523.0061292517007	0.2525	70	197	2	20	16	2	0	-2	2	0	0	4.087976833828202	
i 1	523.0133401360545	0.2525	73	197	2	20	13	2	0	-1	2	0	0	4.087976833828202	
i 1	523.483775510204	0.2525	71	379	4	4	14	8	0	-2	8	0	0	9.003796959404667	
i 1	523.4873809523809	0.2525	74	695	4	4	1	8	0	-2	8	0	0	9.003796959404667	
i 1	523.4960340136055	0.2525	72	1081	6	5	2	1	0	-1	1	0	0	3.0	
i 1	523.498918367347	0.2525	70	197	2	20	15	2	0	-2	2	0	0	4.087976833828202	
i 1	523.5090136054422	0.2525	73	197	2	20	12	2	0	-1	2	0	0	4.087976833828202	
i 1	523.7330544217687	0.505	70	197	2	20	3	8	0	-1	8	0	0	4.087976833828202	
i 1	523.7352176870749	0.2525	71	899	6	2	8	8	0	-2	8	0	0	9.003796959404667	
i 1	523.7388231292517	0.7575000000000001	71	899	6	2	3	2	0	-1	2	0	0	9.003796959404667	
i 1	523.7445918367347	0.505	69	899	6	5	3	1	0	-1	1	0	0	3.0	
i 1	523.7561292517007	0.2525	70	583	2	24	10	8	0	-1	8	0	0	8.087976833828202	
i 1	523.756850340136	0.505	61	197	1	27	6	16	0	248	16	308	0	5.92693010167075	
i 1	523.7575714285714	0.505	61	197	1	27	10	1	0	248	1	308	0	5.92693010167075	
i 1	523.7626190476191	3.2825	72	899	6	5	5	0	0	0	0	0	0	3.0	
i 1	523.7633401360545	0.2525	74	197	4	1	3	16	0	1	16	0	0	9.0	
i 1	523.7655034013605	2.02	74	583	4	4	2	2	0	-2	2	0	0	9.003796959404667	
i 1	523.7669455782313	0.505	74	197	5	4	3	2	0	-2	2	0	0	9.003796959404667	
i 1	524.2323333333334	2.7775	69	1165	4	5	16	1	0	0	1	0	0	3.0	
i 1	524.233775510204	2.02	74	1165	5	9	12	8	0	-2	8	0	0	8.003796959404667	
i 1	524.2366598639455	0.2525	69	583	4	5	7	0	0	0	0	0	0	3.0	
i 1	524.2467551020408	2.2725	73	1165	3	24	15	2	0	-1	2	0	0	8.087976833828202	
i 1	524.248918367347	16.16	61	196	1	27	16	16	0	252	16	307	0	5.92693010167075	
i 1	524.2496394557824	1.7675	74	196	5	1	2	17	0	1	17	0	0	9.0	
i 1	524.2496394557824	3.7875	70	196	2	20	10	2	0	-2	2	0	0	4.087976833828202	
i 1	524.2518027210884	0.505	69	1165	4	5	12	1	0	-1	1	0	0	3.0	
i 1	524.2618979591837	2.7775	70	1165	3	20	9	8	0	-2	8	0	0	4.087976833828202	
i 1	524.2676666666666	1.2625	77	1165	4	1	10	16	0	1	16	0	0	9.0	
i 1	524.2676666666666	0.2525	73	1165	2	20	3	8	0	-1	8	0	0	4.087976833828202	
i 1	524.4866598639455	0.2525	72	196	3	5	12	0	0	-1	0	0	0	3.0	
i 1	524.4909863945578	0.2525	71	899	6	2	2	8	0	-2	8	0	0	9.003796959404667	
i 1	524.4938707482993	1.2625	77	583	4	1	11	17	0	1	17	0	0	9.0	
i 1	524.4974761904762	0.2525	70	583	2	24	10	2	0	-2	2	0	0	8.087976833828202	
i 1	524.7460340136055	1.2625	69	196	3	5	9	1	0	0	1	0	0	3.0	
i 1	524.7474761904762	2.525	74	196	5	24	9	17	0	2	17	0	0	12.0	
i 1	524.7582925170068	2.525	74	583	4	24	5	16	0	1	16	0	0	12.0	
i 1	524.7655034013605	1.2625	69	583	4	5	9	1	0	-1	1	0	0	3.0	
i 1	524.9823333333334	0.2525	70	899	2	20	7	8	0	-2	8	0	0	4.087976833828202	
i 1	524.9909863945578	0.2525	73	899	2	20	4	2	0	-2	2	0	0	4.087976833828202	
i 1	525.2344965986395	1.2625	73	1165	2	20	13	2	0	-2	2	0	0	4.087976833828202	
i 1	525.2640612244898	3.7875	71	1165	5	9	16	8	0	-1	8	0	0	8.003796959404667	
i 1	525.4996394557824	1.01	73	196	1	20	1	8	0	-2	8	0	0	4.087976833828202	
i 1	525.7474761904762	0.2525	77	1165	4	1	16	16	0	1	16	0	0	9.0	
i 1	525.9953129251701	2.02	69	583	4	5	9	0	0	0	0	0	0	3.0	
i 1	526.0054081632653	0.2525	77	899	4	1	9	17	0	2	17	0	0	9.0	
i 1	526.0082925170068	2.2725	72	196	3	5	3	0	0	-1	0	0	0	3.0	
i 1	526.0104557823129	0.2525	77	899	4	1	8	16	0	2	16	0	0	9.0	
i 1	526.2344965986395	0.2525	74	196	5	1	5	17	0	1	17	0	0	9.0	
i 1	526.2424285714286	0.505	74	583	4	4	14	2	0	-2	2	0	0	9.003796959404667	
i 1	526.2655034013605	0.2525	74	583	5	3	12	8	0	-1	8	0	0	9.003796959404667	
i 1	526.4902653061224	2.02	74	196	3	1	16	17	0	1	17	0	0	9.0	
i 1	526.4909863945578	0.2525	70	583	2	20	8	8	0	-2	8	0	0	4.087976833828202	
i 1	526.5032448979592	0.2525	73	899	2	20	2	8	0	-1	8	0	0	4.087976833828202	
i 1	526.5046870748299	0.505	73	1165	1	24	14	2	0	252	2	307	0	8.087976833828202	
i 1	526.7402653061224	0.2525	74	196	5	4	5	2	0	-1	2	0	0	9.003796959404667	
i 1	526.7539659863945	0.2525	73	1165	2	20	7	2	0	-1	2	0	0	4.087976833828202	
i 1	526.9844965986395	1.5150000000000001	73	196	1	24	13	2	0	-2	2	0	0	8.087976833828202	
i 1	527.006850340136	0.2525	71	899	6	2	11	2	0	-1	2	0	0	9.003796959404667	
i 1	527.016224489796	0.2525	74	1165	5	9	4	8	0	-2	8	0	0	8.003796959404667	
i 1	527.2330544217687	0.2525	77	899	6	1	8	17	0	2	17	0	0	9.0	
i 1	527.2330544217687	0.505	74	583	5	3	2	8	0	-1	8	0	0	9.003796959404667	
i 1	527.2409863945578	2.2725	70	1165	3	20	4	8	0	-2	8	0	0	4.087976833828202	
i 1	527.256850340136	6.0600000000000005	77	1165	4	1	14	16	0	1	16	0	0	9.0	
i 1	527.2626190476191	1.2625	73	1165	2	20	5	2	0	-1	2	0	0	4.087976833828202	
i 1	527.5104557823129	0.505	74	1165	5	9	11	8	0	-2	8	0	0	8.003796959404667	
i 1	527.7676666666666	0.2525	74	196	5	4	15	2	0	-1	2	0	0	9.003796959404667	
i 1	528.4881020408163	0.2525	73	899	2	20	9	8	0	-1	8	0	0	4.087976833828202	
i 1	528.4881020408163	0.2525	70	583	2	20	4	2	0	-1	2	0	0	4.087976833828202	
i 1	528.5061292517007	1.01	74	196	5	24	11	17	0	2	17	0	0	12.0	
i 1	528.5097346938776	0.2525	73	583	2	24	3	8	0	-1	8	0	0	8.087976833828202	
i 1	528.983775510204	0.505	74	196	5	4	16	2	0	-1	2	0	0	9.003796959404667	
i 1	529.006850340136	0.2525	74	1165	5	9	3	8	0	-2	8	0	0	8.003796959404667	
i 1	529.233775510204	0.2525	70	196	1	24	4	8	0	-2	8	0	0	8.087976833828202	
i 1	529.2381020408163	0.2525	71	1165	5	9	2	8	0	-1	8	0	0	8.003796959404667	
i 1	529.2539659863945	0.2525	70	196	1	20	12	8	0	-2	8	0	0	4.087976833828202	
i 1	529.4866598639455	9.09	61	899	5	25	4	16	0	2	16	0	0	5.334237091503674	
i 1	529.4953129251701	1.2625	70	1165	2	20	7	8	0	-2	8	0	0	5.018084618446634	
i 1	529.4953129251701	1.2625	70	196	2	20	12	2	0	-2	2	0	0	5.018084618446634	
i 1	529.5018027210884	0.7575000000000001	74	196	3	24	6	17	0	2	17	0	0	12.0	
i 1	529.5025238095238	0.505	73	1165	2	20	1	2	0	-2	2	0	0	5.018084618446634	
i 1	529.5046870748299	0.505	70	1165	2	20	7	8	0	-2	8	0	0	5.018084618446634	
i 1	529.5082925170068	4.04	77	899	6	1	8	16	0	2	16	0	0	9.0	
i 1	529.5111768707483	3.0300000000000002	74	1165	5	9	10	8	0	-2	8	0	0	8.003796959404667	
i 1	529.5155034013605	0.505	70	196	1	20	11	8	0	-2	8	0	0	5.018084618446634	
i 1	529.5169455782313	3.0300000000000002	70	196	2	24	15	2	0	-2	2	0	0	9.018084618446634	
i 1	529.7611768707483	0.2525	69	583	6	5	14	0	0	0	0	0	0	3.0	
i 1	529.9830544217687	0.2525	72	899	6	5	5	0	0	0	0	0	0	3.0	
i 1	529.9981972789116	0.2525	70	899	2	20	6	8	0	-2	8	0	0	5.018084618446634	
i 1	530.0054081632653	0.2525	70	583	2	24	6	8	0	-1	8	0	0	9.018084618446634	
i 1	530.0118979591837	1.5150000000000001	72	196	3	5	12	0	0	-1	0	0	0	3.0	
i 1	530.0140612244898	0.2525	73	899	2	20	5	2	0	-1	2	0	0	5.018084618446634	
i 1	530.2525238095238	1.5150000000000001	77	583	4	1	16	17	0	1	17	0	0	9.0	
i 1	530.2525238095238	1.2625	69	583	6	5	11	0	0	0	0	0	0	3.0	
i 1	530.2597346938776	1.2625	70	196	1	24	3	2	0	-2	2	0	0	9.018084618446634	
i 1	530.4859387755102	4.2925	72	899	6	5	12	0	0	0	0	0	0	3.0	
i 1	530.4902653061224	4.2925	69	1165	4	5	13	1	0	0	1	0	0	3.0	
i 1	531.0032448979592	0.505	70	196	1	20	11	2	0	-2	2	0	0	5.018084618446634	
i 1	531.006850340136	1.5150000000000001	71	899	6	2	5	2	0	-1	2	0	0	9.003796959404667	
i 1	531.0140612244898	2.02	70	1165	2	20	13	8	0	-2	8	0	0	5.018084618446634	
i 1	531.4902653061224	0.505	70	583	2	24	3	8	0	-1	8	0	0	9.018084618446634	
i 1	531.4967551020408	2.02	69	196	3	5	3	1	0	0	1	0	0	3.0	
i 1	531.5003605442176	2.02	69	583	6	5	5	1	0	-1	1	0	0	3.0	
i 1	531.501081632653	0.505	70	583	2	20	10	2	0	-2	2	0	0	5.018084618446634	
i 1	531.5097346938776	2.2725	74	196	5	4	12	2	0	-1	2	0	0	9.003796959404667	
i 1	531.5118979591837	0.505	73	899	2	20	16	2	0	-2	2	0	0	5.018084618446634	
i 1	531.5169455782313	2.525	74	583	4	4	16	2	0	-2	2	0	0	9.003796959404667	
i 1	531.7359387755102	0.505	74	1165	4	1	13	17	0	2	17	0	0	9.0	
i 1	531.7409863945578	0.2525	74	196	3	24	13	17	0	2	17	0	0	12.0	
i 1	532.0018027210884	0.2525	70	1165	2	20	12	2	0	-2	2	0	0	5.018084618446634	
i 1	532.2467551020408	0.2525	70	899	2	20	14	2	0	-2	2	0	0	5.018084618446634	
i 1	532.2539659863945	0.2525	70	583	2	24	15	8	0	-1	8	0	0	9.018084618446634	
i 1	532.2647823129251	4.04	74	196	3	1	14	17	0	1	17	0	0	9.0	
i 1	532.4823333333334	0.2525	74	583	5	3	3	8	0	-1	8	0	0	9.003796959404667	
i 1	532.4852176870749	0.2525	71	1165	5	9	13	8	0	-1	8	0	0	8.003796959404667	
i 1	532.4924285714286	7.8275	61	899	5	25	13	1	0	1	1	0	0	5.334237091503674	
i 1	532.5003605442176	4.545	73	1165	2	20	10	8	0	-1	8	0	0	5.018084618446634	
i 1	532.5111768707483	4.04	77	583	6	1	1	17	0	1	17	0	0	9.0	
i 1	532.7618979591837	2.525	71	899	6	2	10	2	0	-1	2	0	0	9.003796959404667	
i 1	533.4852176870749	2.02	74	196	3	24	15	17	0	2	17	0	0	12.0	
i 1	533.7525238095238	1.5150000000000001	69	583	6	5	14	0	0	0	0	0	0	3.0	
i 1	533.9945918367347	0.2525	74	196	5	4	13	2	0	-1	2	0	0	9.003796959404667	
i 1	534.0118979591837	0.2525	74	196	5	3	5	2	0	-1	2	0	0	9.003796959404667	
i 1	534.2453129251701	2.7775	71	899	6	2	1	8	0	-2	8	0	0	9.003796959404667	
i 1	535.251081632653	4.04	77	899	6	1	1	16	0	2	16	0	0	9.0	
i 1	535.2539659863945	0.505	74	196	5	4	9	2	0	-1	2	0	0	9.003796959404667	
i 1	535.2575714285714	4.04	77	1165	4	1	3	16	0	1	16	0	0	9.0	
i 1	535.2626190476191	0.2525	74	196	5	3	12	2	0	-1	2	0	0	9.003796959404667	
i 1	535.501081632653	0.2525	72	196	3	5	1	0	0	-1	0	0	0	3.0	
i 1	535.5039659863945	4.7975	61	583	5	25	10	1	0	1	1	0	0	5.334237091503674	
i 1	535.5097346938776	0.2525	71	899	6	2	3	2	0	-1	2	0	0	9.003796959404667	
i 1	535.7438707482993	4.545	74	583	5	3	1	8	0	-1	8	0	0	9.003796959404667	
i 1	535.7460340136055	0.2525	74	1165	5	9	15	8	0	-2	8	0	0	8.003796959404667	
i 1	536.2388231292517	0.2525	74	1165	4	1	13	17	0	2	17	0	0	9.0	
i 1	536.5169455782313	1.2625	74	196	3	24	2	17	0	2	17	0	0	12.0	
i 1	536.7532448979592	1.2625	70	196	1	20	10	2	0	-2	2	0	0	5.018084618446634	
i 1	536.9866598639455	0.2525	70	899	2	20	4	8	0	-2	8	0	0	5.018084618446634	
i 1	536.998918367347	2.02	69	583	6	5	4	0	0	0	0	0	0	3.0	
i 1	537.0104557823129	2.02	72	196	3	5	16	0	0	-1	0	0	0	3.0	
i 1	537.2330544217687	3.0300000000000002	71	899	6	2	1	2	0	-1	2	0	0	9.003796959404667	
i 1	537.2330544217687	3.0300000000000002	70	196	1	24	7	2	0	-2	2	0	0	9.018084618446634	
i 1	537.248918367347	0.7575000000000001	73	196	1	20	2	8	0	-2	8	0	0	5.018084618446634	
i 1	537.256850340136	3.0300000000000002	73	1165	2	20	1	2	0	-2	2	0	0	5.018084618446634	
i 1	537.7633401360545	0.2525	74	1165	4	1	3	17	0	2	17	0	0	9.0	
i 1	538.0133401360545	0.2525	74	196	3	24	4	17	0	2	17	0	0	12.0	
i 1	538.0133401360545	2.2725	69	1165	6	5	11	1	0	0	1	0	0	3.0	
i 1	538.2460340136055	2.02	77	583	6	1	10	17	0	1	17	0	0	9.0	
i 1	538.4881020408163	1.7675	61	899	5	25	7	16	0	2	16	0	0	5.334237091503674	
i 1	538.4967551020408	1.7675	63	583	5	25	13	16	0	2	16	0	0	5.334237091503674	
i 1	538.9823333333334	1.2625	74	1165	5	9	6	8	0	-2	8	0	0	8.003796959404667	
i 1	538.9917074829932	0.2525	69	899	6	5	16	1	0	-1	1	0	0	3.0	
i 1	539.0176666666666	1.2625	69	583	6	5	4	1	0	-1	1	0	0	3.0	
i 1	539.2395442176871	0.2525	74	583	4	24	8	16	0	1	16	0	0	12.0	
i 1	539.2424285714286	1.01	70	196	1	24	3	2	0	-2	2	0	0	9.018084618446634	
i 1	539.2539659863945	1.01	69	196	7	5	5	1	0	0	1	0	0	3.0	
i 1	539.4981972789116	0.7575000000000001	77	1165	4	1	11	16	0	1	16	0	0	9.0	
i 1	539.5097346938776	0.7575000000000001	77	899	6	1	15	16	0	2	16	0	0	9.0	
i 1	539.7496394557824	0.505	69	583	6	5	12	0	0	0	0	0	0	3.0	
i 1	539.7546870748299	0.505	74	583	4	24	7	16	0	1	16	0	0	12.0	
i 1	540.016224489796	0.2525	70	196	1	20	4	2	0	-2	2	0	0	5.018084618446634	
i 1	540.233775510204	2.02	69	1081	6	5	9	1	0	0	1	0	0	3.0	
i 1	540.2373809523809	1.2625	63	695	5	25	10	16	0	2	16	0	0	5.334237091503674	
i 1	540.2381020408163	0.505	74	695	6	1	6	17	0	2	17	0	0	9.0	
i 1	540.2381020408163	0.505	77	1081	3	1	16	17	0	1	17	0	0	9.0	
i 1	540.2381020408163	0.2525	71	695	4	4	8	8	0	-1	8	0	0	9.003796959404667	
i 1	540.243149659864	1.01	69	197	7	5	11	1	0	0	1	0	0	3.0	
i 1	540.2453129251701	1.2625	74	197	5	24	16	16	0	1	16	0	0	12.0	
i 1	540.2460340136055	10.352500000000001	63	695	1	27	16	1	0	252	1	307	0	5.92693010167075	
i 1	540.2467551020408	2.02	69	197	7	5	13	0	0	0	0	0	0	3.0	
i 1	540.2481972789116	1.5150000000000001	77	1081	5	1	10	16	0	1	16	0	0	9.0	
i 1	540.2503605442176	0.7575000000000001	70	1081	1	20	12	8	0	-1	8	0	0	5.018084618446634	
i 1	540.2518027210884	4.2925	63	695	5	25	2	16	0	1	16	0	0	5.334237091503674	
i 1	540.2518027210884	0.505	72	695	6	5	10	0	0	0	0	0	0	3.0	
i 1	540.2525238095238	6.8175	70	1081	1	20	7	2	0	-2	2	0	0	5.018084618446634	
i 1	540.2532448979592	2.525	77	197	6	1	6	16	0	2	16	0	0	9.0	
i 1	540.2597346938776	4.2925	61	197	6	25	2	1	0	1	1	0	0	5.334237091503674	
i 1	540.2647823129251	7.3225	63	197	6	25	5	1	0	2	1	0	0	5.334237091503674	
i 1	540.2655034013605	0.7575000000000001	70	695	1	24	10	8	0	248	8	308	0	9.018084618446634	
i 1	540.5025238095238	2.2725	77	695	2	24	12	17	0	2	17	0	0	12.0	
i 1	540.5075714285714	0.2525	71	197	6	3	2	8	0	-2	8	0	0	9.003796959404667	
i 1	540.7590136054422	0.2525	69	695	3	5	4	1	0	0	1	0	0	3.0	
i 1	540.9866598639455	0.2525	71	197	6	3	16	8	0	-2	8	0	0	9.003796959404667	
i 1	540.9981972789116	0.2525	73	197	2	20	5	2	0	-2	2	0	0	5.018084618446634	
i 1	541.0018027210884	2.7775	74	695	4	3	5	2	0	-2	2	0	0	9.003796959404667	
i 1	541.0090136054422	0.2525	69	695	6	5	7	0	0	-1	0	0	0	3.0	
i 1	541.0090136054422	0.2525	73	695	2	20	8	8	0	-2	8	0	0	5.018084618446634	
i 1	541.2330544217687	3.7875	72	1081	6	5	11	0	0	-1	0	0	0	3.0	
i 1	541.243149659864	2.525	74	695	6	2	13	8	0	-2	8	0	0	9.003796959404667	
i 1	541.2626190476191	0.2525	72	695	6	5	16	1	0	-1	1	0	0	3.0	
i 1	541.483775510204	1.01	71	1081	5	9	4	8	0	-2	8	0	0	8.003796959404667	
i 1	541.5032448979592	2.02	69	197	7	5	9	1	0	0	1	0	0	3.0	
i 1	541.506850340136	9.09	61	1081	4	26	6	1	0	1	1	0	0	5.334237091503674	
i 1	541.5097346938776	0.2525	77	1081	5	1	8	17	0	1	17	0	0	9.0	
i 1	541.5169455782313	6.0600000000000005	63	695	5	25	1	16	0	2	16	0	0	5.334237091503674	
i 1	541.7626190476191	1.2625	74	695	2	1	9	17	0	1	17	0	0	9.0	
i 1	541.9974761904762	2.2725	74	197	5	24	7	16	0	1	16	0	0	12.0	
i 1	542.0075714285714	2.525	77	1081	5	1	12	16	0	1	16	0	0	9.0	
i 1	542.2373809523809	2.525	73	1081	1	24	13	2	0	-2	2	0	0	9.018084618446634	
i 1	542.2481972789116	0.2525	70	695	2	20	13	2	0	-2	2	0	0	5.018084618446634	
i 1	542.248918367347	0.2525	70	695	2	20	9	2	0	-1	2	0	0	5.018084618446634	
i 1	542.2503605442176	0.2525	70	197	2	24	15	8	0	-2	8	0	0	9.018084618446634	
i 1	542.5039659863945	5.05	71	695	4	4	15	8	0	-1	8	0	0	9.003796959404667	
i 1	542.5054081632653	2.02	73	1081	1	20	9	2	0	-1	2	0	0	5.018084618446634	
i 1	542.7388231292517	4.2925	71	197	6	3	13	8	0	-2	8	0	0	9.003796959404667	
i 1	542.998918367347	0.2525	77	695	6	1	5	16	0	2	16	0	0	9.0	
i 1	543.251081632653	0.2525	77	1081	5	1	4	17	0	1	17	0	0	9.0	
i 1	543.5133401360545	2.02	69	197	7	5	6	0	0	0	0	0	0	3.0	
i 1	544.4823333333334	6.0600000000000005	61	197	6	25	16	1	0	1	1	0	0	5.334237091503674	
i 1	544.4852176870749	13.8875	63	695	5	25	11	16	0	1	16	0	0	5.334237091503674	
i 1	544.5003605442176	0.2525	77	1081	5	1	4	17	0	1	17	0	0	9.0	
i 1	544.5025238095238	0.2525	69	695	6	5	3	1	0	0	1	0	0	3.0	
i 1	544.5046870748299	9.09	63	1081	4	26	3	16	0	2	16	0	0	5.334237091503674	
i 1	544.751081632653	0.2525	69	197	7	5	13	1	0	0	1	0	0	3.0	
i 1	544.7647823129251	2.7775	77	695	2	24	13	17	0	2	17	0	0	12.0	
i 1	545.0082925170068	1.01	69	695	5	5	2	0	0	-1	0	0	0	3.0	
i 1	545.7438707482993	4.04	71	1081	5	9	7	8	0	-2	8	0	0	8.003796959404667	
i 1	545.993149659864	0.2525	69	197	7	5	7	0	0	0	0	0	0	3.0	
i 1	546.2381020408163	0.2525	69	695	5	5	8	0	0	-1	0	0	0	3.0	
i 1	546.743149659864	1.2625	69	695	5	5	15	0	0	-1	0	0	0	3.0	
i 1	546.7503605442176	0.7575000000000001	73	1081	1	24	11	2	0	-2	2	0	0	9.018084618446634	
i 1	547.0104557823129	0.2525	74	695	6	2	4	8	0	-2	8	0	0	9.003796959404667	
i 1	547.2409863945578	1.7675	69	197	7	5	6	0	0	0	0	0	0	3.0	
i 1	547.2445918367347	0.2525	71	197	5	4	16	2	0	-2	2	0	0	9.003796959404667	
i 1	547.2590136054422	1.7675	69	1081	6	5	4	1	0	0	1	0	0	3.0	
i 1	547.2655034013605	0.2525	70	1081	1	20	6	2	0	-2	2	0	0	5.018084618446634	
i 1	547.4888231292517	2.2725	71	695	4	2	5	8	0	-1	8	0	0	9.003796959404667	
i 1	547.493149659864	0.2525	71	197	6	3	5	8	0	-2	8	0	0	9.003796959404667	
i 1	547.4938707482993	0.7575000000000001	73	1081	3	20	7	2	0	-1	2	0	0	4.0046649342760805	
i 1	547.4945918367347	6.0600000000000005	63	197	6	25	8	1	0	2	1	0	0	5.334237091503674	
i 1	547.4953129251701	10.8575	63	695	5	25	1	16	0	2	16	0	0	5.334237091503674	
i 1	547.498918367347	9.09	61	695	3	27	4	1	0	1	1	0	0	5.92693010167075	
i 1	547.5061292517007	0.7575000000000001	73	1081	1	24	13	2	0	-2	2	0	0	8.00466493427608	
i 1	547.5155034013605	2.7775	77	695	4	24	6	17	0	2	17	0	0	12.0	
i 1	547.7352176870749	1.01	74	1081	5	9	15	8	0	-2	8	0	0	8.003796959404667	
i 1	547.7676666666666	1.01	71	197	5	4	15	2	0	-2	2	0	0	9.003796959404667	
i 1	547.7676666666666	0.2525	69	695	6	5	10	1	0	0	1	0	0	3.0	
i 1	548.0126190476191	1.7675	72	695	5	5	4	1	0	-1	1	0	0	3.0	
i 1	548.016224489796	1.7675	72	1081	6	5	7	0	0	-1	0	0	0	3.0	
i 1	548.7460340136055	2.7775	74	695	5	3	14	2	0	-2	2	0	0	9.003796959404667	
i 1	548.9945918367347	0.2525	74	695	6	1	4	17	0	2	17	0	0	9.0	
i 1	549.0032448979592	2.525	74	695	4	1	6	17	0	1	17	0	0	9.0	
i 1	549.0118979591837	1.2625	73	1081	1	24	1	2	0	-2	2	0	0	8.00466493427608	
i 1	550.0075714285714	0.2525	69	1081	6	5	7	1	0	0	1	0	0	3.0	
i 1	550.4830544217687	1.01	74	695	6	1	3	17	0	2	17	0	0	9.0	
i 1	550.4866598639455	1.01	72	695	6	5	11	1	0	-1	1	0	0	3.0	
i 1	550.4917074829932	1.01	72	1081	6	5	3	0	0	-1	0	0	0	3.0	
i 1	550.4967551020408	0.2525	77	1081	5	1	6	17	0	1	17	0	0	9.0	
i 1	550.4974761904762	7.8275	61	197	5	25	3	1	0	1	1	0	0	5.334237091503674	
i 1	550.5090136054422	6.0600000000000005	61	1081	4	26	13	1	0	1	1	0	0	5.334237091503674	
i 1	550.5111768707483	1.2625	74	695	4	2	2	8	0	-2	8	0	0	9.003796959404667	
i 1	550.516224489796	7.8275	63	695	3	27	2	1	0	1	1	0	0	5.92693010167075	
i 1	550.756850340136	0.2525	71	1081	5	9	9	8	0	-2	8	0	0	8.003796959404667	
i 1	550.7647823129251	0.2525	77	197	6	1	4	16	0	2	16	0	0	9.0	
i 1	550.9981972789116	1.5150000000000001	74	197	5	24	11	16	0	1	16	0	0	12.0	
i 1	550.9981972789116	2.02	71	197	6	3	16	8	0	-2	8	0	0	9.003796959404667	
i 1	551.0090136054422	0.505	70	695	4	20	5	2	0	-1	2	0	0	4.0046649342760805	
i 1	551.2532448979592	1.5150000000000001	73	1081	1	24	16	2	0	-2	2	0	0	8.00466493427608	
i 1	551.266224489796	0.505	73	197	2	24	15	8	0	-1	8	0	0	8.00466493427608	
i 1	551.516224489796	0.2525	77	695	4	24	6	17	0	2	17	0	0	12.0	
i 1	551.7373809523809	0.505	72	695	6	5	2	0	0	0	0	0	0	3.0	
i 1	551.743149659864	0.2525	77	695	6	1	10	16	0	2	16	0	0	9.0	
i 1	551.751081632653	0.2525	74	695	5	3	3	2	0	-2	2	0	0	9.003796959404667	
i 1	551.7655034013605	1.01	70	1081	3	20	12	2	0	-2	2	0	0	4.0046649342760805	
i 1	552.0097346938776	1.2625	74	695	4	1	7	17	0	1	17	0	0	9.0	
i 1	552.2518027210884	0.2525	71	197	5	4	11	2	0	-2	2	0	0	9.003796959404667	
i 1	552.2597346938776	0.505	70	1081	3	20	10	2	0	-1	2	0	0	4.0046649342760805	
i 1	552.4953129251701	1.01	72	695	6	5	16	0	0	0	0	0	0	3.0	
i 1	552.5082925170068	5.3025	71	1081	5	9	4	8	0	-2	8	0	0	8.003796959404667	
i 1	552.5111768707483	4.04	71	695	4	2	6	8	0	-1	8	0	0	9.003796959404667	
i 1	552.5118979591837	0.7575000000000001	69	695	5	5	4	0	0	-1	0	0	0	3.0	
i 1	552.5133401360545	0.2525	77	695	6	1	16	16	0	2	16	0	0	9.0	
i 1	552.7330544217687	3.7875	77	695	4	24	13	17	0	2	17	0	0	12.0	
i 1	552.7546870748299	1.7675	69	197	5	5	3	1	0	0	1	0	0	3.0	
i 1	552.7618979591837	0.2525	70	197	2	20	4	8	0	-1	8	0	0	4.0046649342760805	
i 1	553.0155034013605	0.2525	74	695	4	2	5	8	0	-2	8	0	0	9.003796959404667	
i 1	553.256850340136	0.2525	71	197	6	3	6	8	0	-2	8	0	0	9.003796959404667	
i 1	553.2611768707483	1.2625	73	1081	1	24	7	2	0	-2	2	0	0	8.00466493427608	
i 1	553.4888231292517	4.7975	63	1081	4	26	4	16	0	2	16	0	0	5.334237091503674	
i 1	553.4938707482993	1.01	70	1081	3	20	16	2	0	-1	2	0	0	4.0046649342760805	
i 1	553.4967551020408	4.7975	63	197	5	25	13	1	0	2	1	0	0	5.334237091503674	
i 1	553.5018027210884	2.7775	77	197	7	1	3	16	0	2	16	0	0	9.0	
i 1	553.5169455782313	0.2525	77	695	6	1	16	16	0	2	16	0	0	9.0	
i 1	553.7503605442176	0.2525	77	1081	5	1	7	17	0	1	17	0	0	9.0	
i 1	553.7582925170068	0.2525	74	695	4	2	1	8	0	-2	8	0	0	9.003796959404667	
i 1	553.7618979591837	1.5150000000000001	69	695	6	5	6	0	0	-1	0	0	0	3.0	
i 1	553.7676666666666	1.5150000000000001	72	695	6	5	1	0	0	0	0	0	0	3.0	
i 1	553.9873809523809	1.01	71	197	4	3	15	8	0	-2	8	0	0	9.003796959404667	
i 1	553.9881020408163	1.01	74	695	6	1	6	17	0	2	17	0	0	9.0	
i 1	553.9881020408163	2.02	70	1081	3	20	15	8	0	-2	8	0	0	4.0046649342760805	
i 1	553.9938707482993	2.02	70	1081	1	20	9	2	0	-2	2	0	0	4.0046649342760805	
i 1	553.9974761904762	0.7575000000000001	74	695	4	1	11	17	0	1	17	0	0	9.0	
i 1	554.5046870748299	0.2525	69	695	6	5	6	1	0	0	1	0	0	3.0	
i 1	554.7330544217687	1.7675	69	197	5	5	4	0	0	0	0	0	0	3.0	
i 1	554.9823333333334	0.2525	74	197	5	24	11	16	0	1	16	0	0	12.0	
i 1	554.9945918367347	0.2525	71	695	4	4	4	8	0	-1	8	0	0	9.003796959404667	
i 1	555.2575714285714	1.2625	74	1081	5	9	2	8	0	-2	8	0	0	8.003796959404667	
i 1	555.4830544217687	0.2525	77	1081	5	1	13	17	0	1	17	0	0	9.0	
i 1	555.5018027210884	0.2525	69	695	6	5	16	0	0	-1	0	0	0	3.0	
i 1	555.5133401360545	1.5150000000000001	70	1081	3	20	11	2	0	-1	2	0	0	4.0046649342760805	
i 1	555.7366598639455	0.7575000000000001	74	197	5	24	13	16	0	1	16	0	0	12.0	
i 1	555.7438707482993	1.7675	77	1081	5	1	11	16	0	1	16	0	0	9.0	
i 1	555.7532448979592	0.2525	69	695	6	5	2	1	0	0	1	0	0	3.0	
i 1	555.9938707482993	0.505	72	695	4	5	10	1	0	-1	1	0	0	3.0	
i 1	556.0169455782313	0.505	72	1081	6	5	16	0	0	-1	0	0	0	3.0	
i 1	556.4823333333334	1.7675	69	197	7	5	1	1	0	0	1	0	0	3.0	
i 1	556.4945918367347	0.2525	77	197	7	1	2	16	0	2	16	0	0	9.0	
i 1	556.5018027210884	1.7675	70	1081	1	20	12	2	0	-2	2	0	0	4.0046649342760805	
i 1	556.5090136054422	0.2525	74	695	5	3	2	2	0	-2	2	0	0	9.003796959404667	
i 1	556.5155034013605	1.7675	61	695	3	27	16	1	0	1	1	0	0	5.92693010167075	
i 1	556.5176666666666	1.01	74	197	5	24	8	16	0	1	16	0	0	12.0	
i 1	556.5176666666666	1.7675	61	1081	4	26	13	1	0	1	1	0	0	5.334237091503674	
i 1	556.7546870748299	0.2525	71	197	4	3	14	8	0	-2	8	0	0	9.003796959404667	
i 1	556.9902653061224	0.505	72	695	6	5	2	0	0	0	0	0	0	3.0	
i 1	556.9945918367347	1.2625	77	197	7	1	5	16	0	2	16	0	0	9.0	
i 1	557.266224489796	1.01	74	695	4	2	13	8	0	-2	8	0	0	9.003796959404667	
i 1	557.4844965986395	0.2525	77	695	6	1	3	16	0	2	16	0	0	9.0	
i 1	557.4945918367347	0.2525	69	695	4	5	15	0	0	-1	0	0	0	3.0	
i 1	557.7424285714286	0.505	69	197	5	5	15	0	0	0	0	0	0	3.0	
i 1	557.7503605442176	0.2525	71	695	4	4	2	8	0	-1	8	0	0	9.003796959404667	
i 1	557.9974761904762	0.2525	70	197	4	20	16	8	0	-2	8	0	0	4.0046649342760805	
i 1	558.0018027210884	0.2525	71	197	4	3	14	8	0	-2	8	0	0	9.003796959404667	
i 1	558.2330544217687	0.2525	70	199	3	20	1	2	0	-1	2	0	0	4.0046649342760805	
i 1	558.2344965986395	3.2825	71	585	4	3	3	2	0	-2	2	0	0	9.003796959404667	
i 1	558.2352176870749	8.585	61	585	5	25	10	1	0	1	1	0	0	5.334237091503674	
i 1	558.2352176870749	1.2625	61	199	4	27	7	16	0	2	16	0	0	5.92693010167075	
i 1	558.2359387755102	0.2525	73	199	4	20	10	2	0	-1	2	0	0	4.0046649342760805	
i 1	558.2402653061224	0.505	74	901	4	2	7	2	0	-1	2	0	0	9.003796959404667	
i 1	558.2445918367347	8.585	63	585	5	25	11	1	0	2	1	0	0	5.334237091503674	
i 1	558.2467551020408	8.585	61	901	5	25	11	1	0	1	1	0	0	5.334237091503674	
i 1	558.2481972789116	1.5150000000000001	69	199	5	5	8	1	5000	-1	1	0	0	3.0	
i 1	558.2518027210884	0.2525	69	585	6	5	7	1	0	-1	1	0	0	3.0	
i 1	558.2546870748299	1.01	77	585	4	24	6	17	0	2	17	0	0	12.0	
i 1	558.2546870748299	1.2625	61	199	5	26	5	1	5000	1	1	0	0	5.334237091503674	
i 1	558.2561292517007	4.2925	63	199	4	27	7	16	0	2	16	0	0	5.92693010167075	
i 1	558.2561292517007	0.2525	73	199	1	20	7	8	0	-2	8	0	0	4.0046649342760805	
i 1	558.2582925170068	0.505	69	199	7	5	5	0	0	0	0	0	0	3.0	
i 1	558.2597346938776	4.2925	70	199	2	20	11	8	5000	-1	8	0	0	4.0046649342760805	
i 1	558.2604557823129	8.585	61	901	5	25	8	16	0	2	16	0	0	5.334237091503674	
i 1	558.2604557823129	1.2625	72	901	4	5	12	0	0	0	0	0	0	3.0	
i 1	558.2611768707483	8.585	61	199	5	26	1	1	5000	2	1	0	0	5.334237091503674	
i 1	558.2618979591837	0.2525	74	585	6	1	14	17	0	2	17	0	0	9.0	
i 1	558.266224489796	3.2825	74	199	6	3	2	2	0	-1	2	0	0	9.003796959404667	
i 1	558.4823333333334	2.02	74	199	6	1	9	17	5000	1	17	0	0	9.0	
i 1	558.4895442176871	0.2525	73	901	4	20	2	2	0	-1	2	0	0	4.0046649342760805	
i 1	558.5075714285714	0.2525	73	585	4	20	1	8	0	-1	8	0	0	4.0046649342760805	
i 1	558.7330544217687	0.7575000000000001	70	199	3	24	7	8	0	-2	8	0	0	8.00466493427608	
i 1	558.7474761904762	1.2625	70	199	3	20	2	2	0	-2	2	0	0	4.0046649342760805	
i 1	558.7503605442176	0.2525	74	199	6	9	6	8	5000	-1	8	0	0	8.003796959404667	
i 1	558.7546870748299	1.2625	70	199	4	20	13	8	0	-1	8	0	0	4.0046649342760805	
i 1	558.7611768707483	1.7675	77	901	6	1	2	16	0	2	16	0	0	9.0	
i 1	559.0169455782313	0.2525	74	199	5	4	2	2	0	-1	2	0	0	9.003796959404667	
i 1	559.2352176870749	0.2525	74	901	6	1	14	17	0	1	17	0	0	9.0	
i 1	559.2438707482993	0.2525	69	585	6	5	5	1	0	-1	1	0	0	3.0	
i 1	559.2582925170068	0.2525	69	199	7	5	5	0	0	-1	0	0	0	3.0	
i 1	559.4974761904762	7.3225	61	199	5	26	16	1	5000	1	1	0	0	5.334237091503674	
i 1	559.5018027210884	0.2525	74	199	5	24	9	16	0	2	16	0	0	12.0	
i 1	559.516224489796	6.0600000000000005	61	199	4	27	2	16	0	2	16	0	0	5.92693010167075	
i 1	559.9823333333334	2.02	72	901	5	5	6	0	0	0	0	0	0	3.0	
i 1	560.0032448979592	0.7575000000000001	74	199	5	1	1	16	0	1	16	0	0	9.0	
i 1	560.0155034013605	0.7575000000000001	74	585	6	1	12	17	0	2	17	0	0	9.0	
i 1	560.2417074829932	0.505	70	199	4	20	6	2	0	-2	2	0	0	4.0046649342760805	
i 1	560.2481972789116	1.7675	74	199	7	1	16	16	5000	1	16	0	0	9.0	
i 1	560.2525238095238	1.7675	69	199	5	5	5	1	5000	-1	1	0	0	3.0	
i 1	560.2575714285714	0.2525	74	199	6	9	4	8	5000	-1	8	0	0	8.003796959404667	
i 1	560.5082925170068	0.2525	70	199	3	20	1	8	0	-2	8	0	0	4.0046649342760805	
i 1	560.7409863945578	0.2525	70	901	4	20	3	8	0	-2	8	0	0	4.0046649342760805	
i 1	560.9873809523809	0.2525	69	199	4	5	16	0	0	-1	0	0	0	3.0	
i 1	561.0061292517007	0.505	74	199	5	24	4	16	0	2	16	0	0	12.0	
i 1	561.0140612244898	1.2625	74	901	6	2	3	8	0	-2	8	0	0	9.003796959404667	
i 1	561.2467551020408	0.2525	70	901	4	20	4	8	0	-2	8	0	0	4.0046649342760805	
i 1	561.2590136054422	0.2525	70	585	4	20	4	2	0	-1	2	0	0	4.0046649342760805	
i 1	561.4924285714286	0.7575000000000001	73	199	4	20	10	2	0	-1	2	0	0	4.0046649342760805	
i 1	561.5032448979592	1.01	74	199	5	4	4	2	0	-1	2	0	0	9.003796959404667	
i 1	561.5032448979592	1.01	69	199	7	5	8	0	0	0	0	0	0	3.0	
i 1	561.5075714285714	1.01	74	199	5	1	5	16	0	1	16	0	0	9.0	
i 1	561.9830544217687	0.505	72	199	5	5	8	0	5000	-1	0	0	0	3.0	
i 1	561.9917074829932	1.01	73	199	1	20	12	8	0	-2	8	0	0	4.0046649342760805	
i 1	562.0155034013605	0.505	77	585	4	24	13	17	0	2	17	0	0	12.0	
i 1	562.2496394557824	0.2525	70	901	4	20	6	8	0	-2	8	0	0	4.0046649342760805	
i 1	562.2539659863945	0.2525	71	585	4	3	5	2	0	-2	2	0	0	9.003796959404667	
i 1	562.2618979591837	0.2525	70	585	4	20	7	8	0	-2	8	0	0	4.0046649342760805	
i 1	562.4823333333334	0.2525	72	901	5	5	1	0	0	0	0	0	0	3.0	
i 1	562.4852176870749	2.7775	72	199	7	5	9	0	5000	-1	0	0	0	3.0	
i 1	562.4859387755102	0.505	74	199	4	9	9	8	5000	-1	8	0	0	10.483894163016764	
i 1	562.4967551020408	4.2925	63	199	4	27	4	16	0	2	16	0	0	5.92693010167075	
i 1	562.516224489796	1.2625	70	199	3	20	2	8	0	-1	8	0	0	4.0046649342760805	
i 1	562.5176666666666	2.2725	74	199	5	4	8	2	0	-1	2	0	0	11.483894163016764	
i 1	562.7561292517007	0.2525	69	585	5	5	9	1	0	-1	1	0	0	3.0	
i 1	562.7655034013605	1.5150000000000001	77	585	4	24	15	17	0	2	17	0	0	3.0000000000000004	
i 1	562.9881020408163	0.7575000000000001	74	901	6	2	16	8	0	-2	8	0	0	11.483894163016764	
i 1	563.0155034013605	0.2525	72	901	5	5	3	0	0	0	0	0	0	3.0	
i 1	563.0176666666666	2.2725	70	199	4	20	8	2	0	-2	2	0	0	4.0046649342760805	
i 1	563.2409863945578	2.02	70	199	4	20	2	8	0	-2	8	0	0	4.0046649342760805	
i 1	563.2438707482993	1.01	69	199	4	5	13	0	0	-1	0	0	0	3.0	
i 1	563.2626190476191	3.535	70	199	4	20	4	8	5000	-1	8	0	0	4.0046649342760805	
i 1	563.9866598639455	0.2525	71	199	4	9	16	2	5000	-2	2	0	0	10.483894163016764	
i 1	564.2474761904762	2.2725	74	199	4	9	15	8	5000	-1	8	0	0	10.483894163016764	
i 1	564.5118979591837	0.2525	69	199	4	5	9	0	0	-1	0	0	0	3.0	
i 1	564.7445918367347	0.505	70	199	3	20	15	8	0	-1	8	0	0	4.0046649342760805	
i 1	564.756850340136	1.5150000000000001	69	199	4	5	3	0	0	0	0	0	0	3.0	
i 1	564.756850340136	0.7575000000000001	70	199	1	24	5	2	0	-2	2	0	0	8.00466493427608	
i 1	565.0039659863945	0.2525	71	585	5	3	9	2	0	-2	2	0	0	11.483894163016764	
i 1	565.233775510204	0.2525	70	901	4	20	11	2	0	-1	2	0	0	4.0046649342760805	
i 1	565.2381020408163	0.2525	74	199	5	4	12	2	0	-1	2	0	0	11.483894163016764	
i 1	565.2395442176871	0.2525	70	585	4	24	10	2	0	-1	2	0	0	8.00466493427608	
i 1	565.2395442176871	1.5150000000000001	73	199	1	20	5	8	0	-2	8	0	0	4.0046649342760805	
i 1	565.2525238095238	0.2525	70	585	4	20	8	8	0	-1	8	0	0	4.0046649342760805	
i 1	565.2582925170068	1.5150000000000001	74	199	5	24	7	16	0	2	16	0	0	3.0000000000000004	
i 1	565.4917074829932	0.2525	74	901	6	2	16	8	0	-2	8	0	0	11.483894163016764	
i 1	565.5018027210884	1.2625	61	199	4	27	9	16	0	2	16	0	0	5.92693010167075	
i 1	565.5018027210884	0.2525	70	199	3	24	11	2	0	-2	2	0	0	8.00466493427608	
i 1	565.5061292517007	1.2625	70	199	3	24	4	2	0	-2	2	0	0	8.00466493427608	
i 1	565.7409863945578	1.01	74	199	3	3	11	2	0	-1	2	0	0	11.483894163016764	
i 1	566.0054081632653	0.7575000000000001	71	585	5	3	5	2	0	-2	2	0	0	11.483894163016764	
i 1	566.2453129251701	0.2525	72	901	5	5	7	0	0	0	0	0	0	3.0	
i 1	566.4830544217687	0.2525	69	585	5	5	9	1	0	-1	1	0	0	3.0	
i 1	566.4852176870749	0.2525	73	199	3	20	11	8	0	-1	8	0	0	4.0046649342760805	
i 1	566.516224489796	0.2525	70	199	3	24	7	2	0	-2	2	0	0	8.00466493427608	
i 1	566.7344965986395	1.5150000000000001	75	208	4	1	8	2	5020	-2	2	0	0	8.0	
i 1	566.7352176870749	1.2625	73	208	1	24	3	17	5019	1	17	0	0	6.301580738753259	
i 1	566.7352176870749	5.8075	76	208	2	24	8	16	5020	1	16	0	0	6.301580738753259	
i 1	566.7359387755102	1.2625	72	1092	6	1	11	2	0	1	2	0	0	8.0	
i 1	566.7381020408163	0.505	72	208	6	9	16	8	5020	-2	8	0	0	4.007119820275398	
i 1	566.7381020408163	0.7575000000000001	73	208	1	24	7	16	5022	1	16	0	0	6.301580738753259	
i 1	566.743149659864	0.2525	77	208	4	5	11	17	5020	2	17	0	0	5.972585005898294	
i 1	566.7438707482993	1.2625	72	723	4	24	4	2	5019	-2	2	0	0	11.0	
i 1	566.7503605442176	1.2625	72	1092	6	2	7	2	0	1	2	0	0	5.007119820275398	
i 1	566.7518027210884	0.7575000000000001	76	208	1	20	11	16	5022	1	16	0	0	2.301580738753259	
i 1	566.7525238095238	1.2625	66	208	4	27	1	6	5022	1	6	0	0	0.592693010167075	
i 1	566.7546870748299	0.7575000000000001	76	208	1	20	7	16	5019	2	16	0	0	2.301580738753259	
i 1	566.7582925170068	1.2625	61	208	4	27	1	6	5022	1	6	0	0	0.592693010167075	
i 1	566.7582925170068	1.2625	77	1092	6	5	15	16	0	1	16	0	0	5.972585005898294	
i 1	566.7597346938776	1.2625	77	723	4	5	9	16	5019	2	16	0	0	5.972585005898294	
i 1	566.7604557823129	1.2625	73	208	1	20	3	16	0	2	16	0	0	2.301580738753259	
i 1	566.7611768707483	0.505	72	208	4	1	5	8	5020	-2	8	0	0	8.0	
i 1	566.7618979591837	1.2625	74	208	3	5	9	17	5022	2	17	0	0	5.972585005898294	
i 1	567.2626190476191	0.2525	72	1092	6	1	5	2	0	-2	2	0	0	8.0	
i 1	567.4830544217687	0.2525	74	208	3	5	1	16	5022	1	16	0	0	5.972585005898294	
i 1	567.5155034013605	0.505	75	208	3	24	1	2	5022	1	2	0	0	11.0	
i 1	567.7618979591837	0.2525	77	208	4	5	7	17	5020	2	17	0	0	5.972585005898294	
i 1	567.9823333333334	0.2525	77	882	4	5	13	16	5021	1	16	0	0	5.972585005898294	
i 1	567.9859387755102	3.0300000000000002	72	678	5	3	14	2	0	-2	2	0	0	5.007119820275398	
i 1	567.9859387755102	0.505	73	208	1	20	8	16	5021	2	16	0	0	2.301580738753259	
i 1	567.9888231292517	0.505	72	882	6	2	3	2	5021	1	2	0	0	5.007119820275398	
i 1	567.9917074829932	16.9175	66	208	3	27	11	6	5022	1	6	0	0	0.592693010167075	
i 1	567.9981972789116	1.5150000000000001	74	208	2	5	1	17	5022	2	17	0	0	5.972585005898294	
i 1	568.0039659863945	16.9175	61	208	3	27	3	6	5022	1	6	0	0	0.592693010167075	
i 1	568.016224489796	2.2725	75	678	4	24	13	2	0	-2	2	0	0	11.0	
i 1	568.2381020408163	0.2525	75	208	2	1	14	2	5022	-2	2	0	0	8.0	
i 1	568.2554081632653	0.505	74	678	4	5	11	16	0	2	16	0	0	5.972585005898294	
i 1	568.2575714285714	0.7575000000000001	72	678	4	1	9	2	0	-2	2	0	0	8.0	
i 1	568.4909863945578	0.2525	75	208	4	1	2	2	5020	-2	2	0	0	8.0	
i 1	568.5097346938776	0.2525	74	208	4	5	1	16	5020	1	16	0	0	5.972585005898294	
i 1	568.7467551020408	0.2525	72	208	4	9	5	8	5020	-2	8	0	0	4.007119820275398	
i 1	568.7518027210884	0.2525	77	882	4	5	13	16	5021	1	16	0	0	5.972585005898294	
i 1	568.7546870748299	0.7575000000000001	73	208	1	20	1	16	5021	2	16	0	0	2.301580738753259	
i 1	568.7590136054422	2.02	73	208	2	20	14	16	5020	2	16	0	0	2.301580738753259	
i 1	568.7633401360545	0.2525	72	208	6	9	14	8	5020	-2	8	0	0	4.007119820275398	
i 1	569.0018027210884	0.505	77	882	6	5	11	17	5021	2	17	0	0	5.972585005898294	
i 1	569.0155034013605	2.02	74	208	4	5	3	16	5020	1	16	0	0	5.972585005898294	
i 1	569.2474761904762	0.2525	75	882	6	2	1	8	5021	1	8	0	0	5.007119820275398	
i 1	569.2554081632653	0.2525	75	882	6	1	7	2	5021	1	2	0	0	8.0	
i 1	569.4823333333334	1.5150000000000001	77	882	4	5	1	17	5021	2	17	0	0	5.972585005898294	
i 1	569.4844965986395	0.2525	77	882	4	5	1	16	5021	1	16	0	0	5.972585005898294	
i 1	569.4881020408163	0.2525	75	882	6	1	11	2	5021	1	2	0	0	8.0	
i 1	569.5018027210884	0.505	72	882	6	2	9	2	5021	1	2	0	0	5.007119820275398	
i 1	569.5111768707483	0.2525	73	678	2	24	15	16	0	1	16	0	0	6.301580738753259	
i 1	569.5133401360545	0.2525	76	882	1	20	14	16	5021	2	16	0	0	2.301580738753259	
i 1	569.5169455782313	0.2525	74	678	4	5	8	16	0	2	16	0	0	5.972585005898294	
i 1	569.7323333333334	1.2625	75	208	2	1	9	2	5022	-2	2	0	0	8.0	
i 1	569.7417074829932	0.2525	74	678	6	5	4	17	0	1	17	0	0	5.972585005898294	
i 1	569.743149659864	0.7575000000000001	73	208	1	20	16	16	5021	2	16	0	0	2.301580738753259	
i 1	570.0147823129251	1.01	77	882	4	5	2	16	5021	1	16	0	0	5.972585005898294	
i 1	570.233775510204	0.2525	72	208	6	9	3	8	5020	-2	8	0	0	4.007119820275398	
i 1	570.2359387755102	0.2525	75	882	6	1	2	2	5021	1	2	0	0	8.0	
i 1	570.2417074829932	2.2725	74	678	6	5	1	17	0	1	17	0	0	5.972585005898294	
i 1	570.2424285714286	2.525	74	208	2	5	3	17	5022	2	17	0	0	5.972585005898294	
i 1	570.2532448979592	3.535	75	208	4	1	15	2	5020	-2	2	0	0	8.0	
i 1	570.4902653061224	0.505	73	678	2	24	14	17	0	1	17	0	0	6.301580738753259	
i 1	570.4981972789116	3.2825	75	882	6	1	9	2	5021	1	2	0	0	8.0	
i 1	570.5025238095238	2.02	72	882	6	2	6	2	5021	1	2	0	0	5.007119820275398	
i 1	570.5176666666666	0.505	76	882	1	20	14	17	5021	1	17	0	0	2.301580738753259	
i 1	570.9960340136055	0.2525	72	208	6	9	5	8	5020	-2	8	0	0	4.007119820275398	
i 1	571.0104557823129	1.01	73	208	1	20	14	17	5021	1	17	0	0	2.301580738753259	
i 1	571.2402653061224	0.2525	75	882	6	2	3	8	5021	1	8	0	0	5.007119820275398	
i 1	571.2445918367347	0.2525	74	208	4	5	7	16	5020	1	16	0	0	5.972585005898294	
i 1	571.501081632653	0.2525	77	208	4	5	16	17	5020	2	17	0	0	5.972585005898294	
i 1	571.7388231292517	0.2525	72	678	5	3	14	2	0	-2	2	0	0	5.007119820275398	
i 1	571.9852176870749	2.02	73	208	2	20	12	16	5020	2	16	0	0	2.301580738753259	
i 1	571.9924285714286	0.2525	76	882	1	20	4	16	5021	2	16	0	0	2.301580738753259	
i 1	571.993149659864	0.2525	76	678	2	24	6	17	0	2	17	0	0	6.301580738753259	
i 1	571.9945918367347	0.2525	76	882	1	20	12	16	5021	1	16	0	0	2.301580738753259	
i 1	572.0003605442176	0.505	75	678	4	24	13	2	0	-2	2	0	0	11.0	
i 1	572.0133401360545	1.2625	72	208	2	4	6	2	5022	-2	2	0	0	5.007119820275398	
i 1	572.2626190476191	1.01	76	208	1	20	1	16	5021	2	16	0	0	2.301580738753259	
i 1	572.4938707482993	0.505	74	678	4	5	3	17	0	1	17	0	0	5.972585005898294	
i 1	572.5018027210884	0.2525	75	678	4	24	11	2	0	-2	2	0	0	11.0	
i 1	572.5140612244898	2.02	75	882	6	2	13	8	5021	1	8	0	0	5.007119820275398	
i 1	572.7525238095238	0.505	76	208	2	24	9	16	5020	1	16	0	0	6.301580738753259	
i 1	572.7590136054422	0.2525	72	678	6	1	13	2	0	-2	2	0	0	8.0	
i 1	572.9953129251701	0.2525	74	208	3	5	7	16	5022	1	16	0	0	5.972585005898294	
i 1	573.0032448979592	0.2525	73	208	1	20	4	17	5021	2	17	0	0	2.301580738753259	
i 1	573.251081632653	0.2525	77	882	4	5	12	16	5021	1	16	0	0	5.972585005898294	
i 1	573.2561292517007	0.505	73	882	1	20	3	16	5021	1	16	0	0	2.301580738753259	
i 1	573.4830544217687	1.7675	75	678	4	24	12	2	0	-2	2	0	0	11.0	
i 1	573.4866598639455	1.7675	75	208	2	24	13	2	5022	1	2	0	0	11.0	
i 1	573.7532448979592	1.01	73	208	1	20	12	17	5021	1	17	0	0	2.301580738753259	
i 1	573.7626190476191	0.2525	74	208	2	5	8	17	5022	2	17	0	0	5.972585005898294	
i 1	573.7655034013605	0.2525	72	208	2	4	9	2	5022	-2	2	0	0	5.007119820275398	
i 1	573.9866598639455	1.01	72	882	5	2	1	2	5021	1	2	0	0	5.007119820275398	
i 1	574.2366598639455	0.2525	74	678	4	5	3	17	0	1	17	0	0	5.972585005898294	
i 1	574.243149659864	0.505	72	208	4	1	8	8	5020	-2	8	0	0	8.0	
i 1	574.5046870748299	4.04	73	208	2	20	5	16	5020	2	16	0	0	2.301580738753259	
i 1	574.5104557823129	1.7675	77	882	4	5	1	16	5021	1	16	0	0	5.972585005898294	
i 1	574.7344965986395	0.7575000000000001	77	208	4	5	16	17	5020	2	17	0	0	5.972585005898294	
i 1	574.7561292517007	1.01	75	208	2	1	3	2	5022	-2	2	0	0	8.0	
i 1	574.7640612244898	0.7575000000000001	76	208	2	24	7	16	5020	1	16	0	0	6.301580738753259	
i 1	574.9981972789116	0.2525	73	882	1	20	7	17	5021	2	17	0	0	2.301580738753259	
i 1	575.2474761904762	1.2625	73	208	1	20	9	17	5021	1	17	0	0	2.301580738753259	
i 1	575.5140612244898	0.2525	72	882	6	2	9	2	5021	1	2	0	0	5.007119820275398	
i 1	575.7474761904762	2.2725	75	208	2	24	1	2	5022	1	2	0	0	11.0	
i 1	575.7496394557824	2.2725	75	678	4	24	10	2	0	-2	2	0	0	11.0	
i 1	575.7561292517007	0.2525	75	208	7	1	9	2	5020	-2	2	0	0	8.0	
i 1	575.9873809523809	1.7675	74	208	4	5	8	16	5020	1	16	0	0	5.972585005898294	
i 1	575.9967551020408	0.2525	72	208	6	9	12	8	5020	-2	8	0	0	4.007119820275398	
i 1	576.0126190476191	1.7675	77	882	4	5	2	17	5021	2	17	0	0	5.972585005898294	
i 1	576.0147823129251	0.505	74	208	2	5	13	17	5022	2	17	0	0	5.972585005898294	
i 1	576.0155034013605	0.505	74	678	4	5	12	17	0	1	17	0	0	5.972585005898294	
i 1	576.2626190476191	0.2525	72	678	4	4	4	2	0	-2	2	0	0	5.007119820275398	
i 1	576.4866598639455	0.2525	76	882	1	20	8	16	5021	2	16	0	0	2.301580738753259	
i 1	576.4938707482993	0.2525	77	882	4	5	12	16	5021	1	16	0	0	5.972585005898294	
i 1	576.5075714285714	0.2525	76	882	1	20	12	17	5021	2	17	0	0	2.301580738753259	
i 1	576.7453129251701	0.2525	72	678	6	1	4	2	0	-2	2	0	0	8.0	
i 1	576.7518027210884	0.505	76	208	1	20	8	16	5021	1	16	0	0	2.301580738753259	
i 1	576.7582925170068	0.2525	72	208	6	9	8	8	5020	-2	8	0	0	4.007119820275398	
i 1	577.4902653061224	0.2525	76	208	1	20	6	16	5021	1	16	0	0	2.301580738753259	
i 1	577.7330544217687	0.2525	77	208	6	5	6	17	5020	2	17	0	0	5.972585005898294	
i 1	577.7611768707483	0.2525	73	882	1	20	15	16	5021	1	16	0	0	2.301580738753259	
i 1	577.9830544217687	0.2525	72	678	6	1	10	2	0	-2	2	0	0	8.0	
i 1	577.9981972789116	0.2525	75	208	2	1	8	2	5022	-2	2	0	0	8.0	
i 1	578.0003605442176	1.2625	73	208	1	20	4	17	5021	1	17	0	0	2.301580738753259	
i 1	578.0097346938776	1.2625	76	208	1	20	3	17	5021	2	17	0	0	2.301580738753259	
i 1	578.2417074829932	1.2625	75	208	7	1	1	2	5020	-2	2	0	0	8.0	
i 1	578.2640612244898	1.2625	75	882	6	1	4	2	5021	1	2	0	0	8.0	
i 1	578.4823333333334	0.7575000000000001	75	208	6	3	2	2	5022	1	2	0	0	5.007119820275398	
i 1	578.4866598639455	0.7575000000000001	72	678	5	3	2	2	0	-2	2	0	0	5.007119820275398	
i 1	578.4888231292517	1.7675	73	208	1	20	11	16	5020	2	16	0	0	2.301580738753259	
i 1	578.516224489796	6.3125	61	882	6	17	3	9	5021	1	9	0	0	3.4492018623622136	
i 1	579.2323333333334	1.2625	72	208	6	9	2	8	5020	-2	8	0	0	4.007119820275398	
i 1	579.2323333333334	0.2525	76	882	1	20	9	16	5021	1	16	0	0	2.301580738753259	
i 1	579.2554081632653	0.2525	76	208	1	24	1	16	5020	1	16	0	0	6.301580738753259	
i 1	579.2626190476191	0.2525	76	882	1	20	3	16	5021	1	16	0	0	2.301580738753259	
i 1	579.2647823129251	1.2625	72	882	6	2	7	2	5021	1	2	0	0	5.007119820275398	
i 1	579.5111768707483	0.7575000000000001	76	208	1	20	7	17	5021	2	17	0	0	2.301580738753259	
i 1	579.5133401360545	1.2625	75	208	2	24	3	2	5022	1	2	0	0	11.0	
i 1	580.2496394557824	1.5150000000000001	77	882	4	5	8	17	5021	2	17	0	0	5.972585005898294	
i 1	580.4981972789116	0.505	72	208	4	4	15	2	5022	-2	2	0	0	5.007119820275398	
i 1	580.733775510204	0.7575000000000001	75	208	7	1	10	2	5020	-2	2	0	0	8.0	
i 1	580.7655034013605	0.7575000000000001	75	882	6	1	13	2	5021	1	2	0	0	8.0	
i 1	580.9924285714286	0.7575000000000001	72	208	6	9	10	8	5020	-2	8	0	0	4.007119820275398	
i 1	581.0061292517007	0.7575000000000001	75	882	6	2	13	8	5021	1	8	0	0	5.007119820275398	
i 1	581.4830544217687	0.2525	74	208	4	5	5	16	5020	1	16	0	0	5.972585005898294	
i 1	581.4895442176871	0.7575000000000001	75	208	2	24	3	2	5022	1	2	0	0	11.0	
i 1	581.5118979591837	0.7575000000000001	75	678	4	24	7	2	0	-2	2	0	0	11.0	
i 1	581.5176666666666	3.2825	61	882	6	17	15	9	5021	1	9	0	0	3.4492018623622136	
i 1	581.7546870748299	1.5150000000000001	77	882	4	5	2	16	5021	1	16	0	0	5.972585005898294	
i 1	582.2344965986395	1.5150000000000001	72	678	6	1	13	2	0	-2	2	0	0	8.0	
i 1	582.2676666666666	1.5150000000000001	75	208	6	1	8	2	5022	-2	2	0	0	8.0	
i 1	583.2409863945578	0.7575000000000001	72	678	5	3	13	2	0	-2	2	0	0	5.007119820275398	
i 1	583.2417074829932	0.2525	76	208	1	20	4	17	5021	2	17	0	0	2.301580738753259	
i 1	583.2474761904762	0.7575000000000001	75	208	6	3	13	2	5022	1	2	0	0	5.007119820275398	
i 1	583.2481972789116	0.2525	74	208	4	5	15	17	5022	2	17	0	0	5.972585005898294	
i 1	583.2582925170068	0.2525	74	678	4	5	1	17	0	1	17	0	0	5.972585005898294	
i 1	583.2626190476191	0.505	73	208	1	20	7	16	5020	2	16	0	0	2.301580738753259	
i 1	583.4823333333334	0.2525	76	882	1	20	7	17	5021	1	17	0	0	2.301580738753259	
i 1	583.4917074829932	0.505	74	208	4	5	12	16	5020	1	16	0	0	5.972585005898294	
i 1	583.5018027210884	0.505	77	882	4	5	6	17	5021	2	17	0	0	5.972585005898294	
i 1	583.751081632653	0.2525	76	208	1	20	14	17	5021	2	17	0	0	2.301580738753259	
i 1	583.7532448979592	0.7575000000000001	75	208	2	24	13	2	5022	1	2	0	0	11.0	
i 1	583.756850340136	0.2525	75	678	4	24	1	2	0	-2	2	0	0	11.0	
i 1	583.9895442176871	0.7575000000000001	72	208	5	4	3	2	5022	-2	2	0	0	5.007119820275398	
i 1	584.0075714285714	0.505	73	208	1	20	13	16	5020	2	16	0	0	2.301580738753259	
i 1	584.0097346938776	0.7575000000000001	74	566	4	5	11	17	5021	2	17	0	0	5.972585005898294	
i 1	584.0126190476191	0.7575000000000001	75	566	5	3	3	2	5021	1	2	0	0	5.007119820275398	
i 1	584.243149659864	0.2525	73	208	1	20	3	17	5021	2	17	0	0	2.301580738753259	
i 1	584.498918367347	0.2525	75	208	5	24	16	2	5022	1	2	0	0	11.0	
i 1	584.5147823129251	0.2525	66	566	6	17	5	6	5021	1	6	0	0	3.4492018623622136	
i 1	584.5169455782313	0.2525	76	1151	1	24	11	17	0	1	17	0	0	6.301580738753259	
i 1	584.7323333333334	1.2625	75	1064	4	9	13	8	0	1	8	0	0	4.007119820275398	
i 1	584.7359387755102	2.7775	61	678	3	27	14	6	0	1	6	0	0	0.592693010167075	
i 1	584.7388231292517	5.8075	66	678	6	17	16	9	0	0	9	0	0	3.4492018623622136	
i 1	584.7402653061224	5.8075	61	678	3	27	2	6	0	1	6	0	0	0.592693010167075	
i 1	584.7424285714286	11.8675	61	180	7	17	16	9	0	1	9	0	0	3.4492018623622136	
i 1	584.756850340136	1.5150000000000001	74	678	4	5	8	16	0	2	16	0	0	5.972585005898294	
i 1	584.7647823129251	8.8375	61	678	6	17	13	9	0	0	9	0	0	3.4492018623622136	
i 1	584.7647823129251	1.5150000000000001	77	1064	3	5	4	17	0	1	17	0	0	5.972585005898294	
i 1	584.9873809523809	0.2525	76	678	1	20	13	16	0	1	16	0	0	2.301580738753259	
i 1	585.9895442176871	0.505	72	180	5	4	2	2	0	-2	2	0	0	5.007119820275398	
i 1	585.993149659864	0.7575000000000001	72	1064	6	1	8	2	0	-2	2	0	0	8.0	
i 1	586.4895442176871	0.7575000000000001	72	678	6	2	12	2	0	-2	2	0	0	5.007119820275398	
i 1	586.5046870748299	0.7575000000000001	75	1064	5	9	8	2	0	1	2	0	0	4.007119820275398	
i 1	586.7366598639455	0.7575000000000001	75	678	4	24	16	2	0	-2	2	0	0	11.0	
i 1	586.7417074829932	0.7575000000000001	73	678	1	20	9	16	0	1	16	0	0	2.301580738753259	
i 1	586.756850340136	0.7575000000000001	72	180	5	24	14	2	0	-2	2	0	0	11.0	
i 1	586.7669455782313	0.7575000000000001	73	180	1	24	15	17	0	252	17	307	0	6.301580738753259	
i 1	587.2330544217687	0.2525	75	1064	4	9	10	8	0	1	8	0	0	4.007119820275398	
i 1	587.2395442176871	1.5150000000000001	72	678	6	2	5	2	0	-2	2	0	0	5.007119820275398	
i 1	587.4924285714286	1.5150000000000001	72	180	7	1	13	2	0	1	2	0	0	8.0	
i 1	587.4981972789116	3.0300000000000002	61	678	3	27	10	6	0	1	6	0	0	0.592693010167075	
i 1	587.501081632653	12.120000000000001	66	180	7	17	6	6	0	0	6	0	0	3.4492018623622136	
i 1	587.5097346938776	1.2625	75	1064	5	9	13	8	0	1	8	0	0	4.007119820275398	
i 1	587.743149659864	0.2525	77	180	4	5	13	16	0	2	16	0	0	5.972585005898294	
i 1	587.9873809523809	1.01	74	678	6	5	14	16	0	2	16	0	0	5.972585005898294	
i 1	588.0032448979592	1.01	77	1064	3	5	10	17	0	1	17	0	0	5.972585005898294	
i 1	588.5097346938776	0.2525	76	678	1	20	7	17	0	2	17	0	0	2.301580738753259	
i 1	588.5097346938776	0.2525	73	180	1	24	5	17	0	2	17	0	0	6.301580738753259	
i 1	588.7554081632653	1.7675	75	678	5	3	10	2	0	1	2	0	0	5.007119820275398	
i 1	588.9895442176871	1.2625	77	678	6	5	8	16	0	2	16	0	0	5.972585005898294	
i 1	588.9953129251701	1.5150000000000001	75	678	4	24	12	2	0	-2	2	0	0	11.0	
i 1	589.0111768707483	1.2625	74	1064	3	5	1	16	0	1	16	0	0	5.972585005898294	
i 1	590.2424285714286	0.2525	77	180	4	5	13	16	0	2	16	0	0	5.972585005898294	
i 1	590.4823333333334	0.2525	73	180	1	24	1	17	0	1	17	0	0	5.168761183983925	
i 1	590.4859387755102	9.09	66	678	6	17	7	9	0	0	9	0	0	3.4492018623622136	
i 1	590.4866598639455	0.505	75	678	3	3	6	2	0	1	2	0	0	5.007119820275398	
i 1	590.493149659864	3.0300000000000002	61	678	3	27	1	6	0	1	6	0	0	0.592693010167075	
i 1	590.5061292517007	3.0300000000000002	61	678	3	27	15	6	0	1	6	0	0	0.592693010167075	
i 1	590.5126190476191	1.2625	77	180	7	5	4	16	0	2	16	0	0	5.972585005898294	
i 1	590.516224489796	12.120000000000001	66	1064	4	18	5	6	0	1	6	0	0	3.4492018623622136	
i 1	591.0003605442176	1.2625	75	678	4	4	10	2	0	1	2	0	0	5.007119820275398	
i 1	591.7561292517007	0.7575000000000001	75	678	6	1	2	2	0	1	2	0	0	8.0	
i 1	592.2561292517007	0.505	75	678	3	3	12	2	0	1	2	0	0	5.007119820275398	
i 1	592.5039659863945	0.7575000000000001	72	180	5	24	1	2	0	-2	2	0	0	11.0	
i 1	592.5140612244898	0.7575000000000001	75	678	4	24	1	2	0	-2	2	0	0	11.0	
i 1	592.7323333333334	0.7575000000000001	75	1064	5	9	11	8	0	1	8	0	0	4.007119820275398	
i 1	592.7453129251701	0.7575000000000001	72	678	6	2	14	2	0	-2	2	0	0	5.007119820275398	
i 1	593.0082925170068	0.2525	76	180	1	20	8	16	0	2	16	0	0	1.168761183983925	
i 1	593.2546870748299	0.2525	75	678	6	1	2	2	0	1	2	0	0	8.0	
i 1	593.4888231292517	9.09	61	678	6	17	15	9	0	0	9	0	0	3.4492018623622136	
i 1	593.4902653061224	12.120000000000001	66	180	6	13	4	9	0	0	9	0	0	2.383001132111543	
i 1	593.498918367347	6.0600000000000005	61	678	5	14	14	6	0	0	6	0	0	5.957502830278859	
i 1	593.5003605442176	1.5150000000000001	72	180	5	4	6	2	0	-2	2	0	0	5.51824952130878	
i 1	593.5061292517007	1.01	74	1064	3	5	15	16	0	1	16	0	0	3.3425598039596673	
i 1	593.506850340136	9.09	61	678	5	14	14	6	0	1	6	0	0	5.957502830278859	
i 1	593.5147823129251	1.01	77	678	6	5	6	16	0	2	16	0	0	3.3425598039596673	
i 1	593.5169455782313	12.120000000000001	61	1064	4	18	12	9	0	0	9	0	0	3.4492018623622136	
i 1	594.2575714285714	0.505	73	678	1	20	5	17	0	2	17	0	0	1.168761183983925	
i 1	594.5018027210884	1.2625	77	180	7	5	5	16	0	2	16	0	0	3.3425598039596673	
i 1	594.7539659863945	0.2525	72	180	5	24	12	2	0	-2	2	0	0	12.0	
i 1	594.7575714285714	0.2525	75	678	4	24	10	2	0	-2	2	0	0	12.0	
i 1	595.0039659863945	1.2625	72	678	6	1	2	2	0	1	2	0	0	9.0	
i 1	595.0155034013605	1.5150000000000001	75	1064	5	9	4	2	0	1	2	0	0	4.51824952130878	
i 1	595.7453129251701	1.2625	74	678	6	5	13	16	0	2	16	0	0	3.3425598039596673	
i 1	595.7496394557824	1.2625	77	1064	3	5	8	17	0	1	17	0	0	3.3425598039596673	
i 1	596.2373809523809	2.02	75	678	4	24	9	2	0	-2	2	0	0	12.0	
i 1	596.2438707482993	2.02	72	180	5	24	5	2	0	-2	2	0	0	12.0	
i 1	596.4967551020408	12.120000000000001	61	678	4	19	4	6	0	0	6	0	0	3.4492018623622136	
i 1	596.506850340136	9.09	61	180	7	17	16	9	0	1	9	0	0	3.4492018623622136	
i 1	596.9902653061224	0.2525	77	678	6	5	6	16	0	2	16	0	0	3.3425598039596673	
i 1	596.9902653061224	0.2525	74	1064	6	5	10	16	0	1	16	0	0	3.3425598039596673	
i 1	597.2323333333334	1.7675	72	180	6	3	10	8	0	-2	8	0	0	5.51824952130878	
i 1	597.2352176870749	1.7675	75	678	5	3	7	2	0	1	2	0	0	5.51824952130878	
i 1	597.2626190476191	1.7675	74	678	2	5	12	17	0	2	17	0	0	3.3425598039596673	
i 1	597.2647823129251	1.7675	77	180	7	5	2	16	0	2	16	0	0	3.3425598039596673	
i 1	598.2366598639455	0.2525	73	678	1	20	1	17	0	2	17	0	0	1.168761183983925	
i 1	598.2633401360545	0.7575000000000001	72	678	6	1	5	2	0	1	2	0	0	9.0	
i 1	598.2647823129251	0.7575000000000001	72	180	7	1	8	2	0	1	2	0	0	9.0	
i 1	598.9888231292517	0.7575000000000001	75	678	4	4	8	2	0	1	2	0	0	5.51824952130878	
i 1	598.9902653061224	0.505	77	1064	3	5	6	17	0	1	17	0	0	3.3425598039596673	
i 1	598.9945918367347	2.2725	74	678	6	5	9	16	0	2	16	0	0	3.3425598039596673	
i 1	599.0046870748299	0.7575000000000001	72	180	5	4	11	2	0	-2	2	0	0	5.51824952130878	
i 1	599.5039659863945	9.09	66	180	7	17	8	6	0	0	6	0	0	3.4492018623622136	
i 1	599.506850340136	1.7675	77	1064	6	5	16	17	0	1	17	0	0	3.3425598039596673	
i 1	599.5133401360545	6.0600000000000005	61	678	5	14	3	6	0	0	6	0	0	5.957502830278859	
i 1	599.5155034013605	12.120000000000001	66	678	4	19	3	6	0	0	6	0	0	3.4492018623622136	
i 1	599.756850340136	1.5150000000000001	75	678	5	3	1	2	0	1	2	0	0	5.51824952130878	
i 1	599.7618979591837	1.5150000000000001	72	180	6	3	4	8	0	-2	8	0	0	5.51824952130878	
i 1	600.2525238095238	0.2525	73	678	1	20	14	16	0	1	16	0	0	1.168761183983925	
i 1	600.2604557823129	0.2525	73	678	1	20	2	16	0	2	16	0	0	1.168761183983925	
i 1	600.4909863945578	0.2525	72	180	5	24	12	2	0	-2	2	0	0	12.0	
i 1	600.5118979591837	0.2525	75	678	4	24	10	2	0	-2	2	0	0	12.0	
i 1	600.7597346938776	1.2625	75	678	6	1	4	2	0	1	2	0	0	9.0	
i 1	601.2381020408163	1.5150000000000001	72	678	6	2	2	2	0	-2	2	0	0	5.51824952130878	
i 1	601.2445918367347	1.2625	74	1064	6	5	2	16	0	1	16	0	0	3.3425598039596673	
i 1	601.2453129251701	0.2525	73	678	1	20	12	16	0	1	16	0	0	1.168761183983925	
i 1	601.2460340136055	0.2525	73	180	1	20	7	16	0	1	16	0	0	1.168761183983925	
i 1	602.0147823129251	1.2625	75	678	4	24	16	2	0	-2	2	0	0	12.0	
i 1	602.016224489796	1.2625	72	180	5	24	11	2	0	-2	2	0	0	12.0	
i 1	602.4888231292517	0.2525	76	180	1	20	9	16	0	1	16	0	0	1.168761183983925	
i 1	602.4981972789116	6.0600000000000005	61	678	5	14	8	6	0	1	6	0	0	5.957502830278859	
i 1	602.5104557823129	9.09	66	1064	4	18	15	6	0	1	6	0	0	3.4492018623622136	
i 1	602.5126190476191	0.2525	76	678	3	20	3	16	0	2	16	0	0	1.168761183983925	
i 1	602.7554081632653	0.7575000000000001	73	1064	2	20	5	17	0	1	17	0	0	1.168761183983925	
i 1	602.7655034013605	1.5150000000000001	74	678	4	5	2	16	0	2	16	0	0	3.3425598039596673	
i 1	603.2352176870749	0.7575000000000001	72	180	7	1	11	2	0	1	2	0	0	9.0	
i 1	603.2474761904762	0.7575000000000001	72	678	6	1	6	2	0	1	2	0	0	9.0	
i 1	603.4996394557824	1.2625	75	1064	5	9	16	2	0	1	2	0	0	4.51824952130878	
i 1	603.501081632653	1.2625	72	678	6	2	6	2	0	-2	2	0	0	5.51824952130878	
i 1	604.0147823129251	2.2725	75	678	4	24	16	2	0	-2	2	0	0	12.0	
i 1	604.2618979591837	0.2525	74	1064	6	5	13	16	0	1	16	0	0	3.3425598039596673	
i 1	604.5118979591837	2.2725	74	678	5	5	4	17	0	2	17	0	0	3.3425598039596673	
i 1	604.7460340136055	0.2525	77	678	4	5	5	16	0	2	16	0	0	3.3425598039596673	
i 1	604.7611768707483	0.2525	73	180	1	20	13	17	0	2	17	0	0	1.168761183983925	
i 1	604.7618979591837	0.2525	73	678	1	20	9	16	0	1	16	0	0	1.168761183983925	
i 1	604.7647823129251	0.505	75	1064	5	9	10	8	0	1	8	0	0	4.51824952130878	
i 1	604.9823333333334	2.525	76	678	1	24	15	17	0	252	17	307	0	5.168761183983925	
i 1	605.0054081632653	0.505	76	1064	2	20	7	16	0	2	16	0	0	1.168761183983925	
i 1	605.0147823129251	0.2525	74	678	4	5	12	16	0	2	16	0	0	3.3425598039596673	
i 1	605.4924285714286	2.2725	72	180	6	3	16	8	0	-2	8	0	0	5.51824952130878	
i 1	605.4945918367347	6.0600000000000005	61	678	4	14	1	6	0	0	6	0	0	5.957502830278859	
i 1	605.4960340136055	6.0600000000000005	66	180	6	13	1	9	0	0	9	0	0	2.383001132111543	
i 1	605.5003605442176	1.5150000000000001	77	180	4	5	11	16	0	2	16	0	0	3.3425598039596673	
i 1	605.5039659863945	2.02	76	1064	2	20	10	16	0	1	16	0	0	1.168761183983925	
i 1	605.5133401360545	9.09	61	1064	4	18	11	9	0	0	9	0	0	3.4492018623622136	
i 1	606.2445918367347	0.505	72	180	7	1	6	2	0	1	2	0	0	9.0	
i 1	606.2539659863945	2.2725	75	678	6	1	13	2	0	1	2	0	0	9.0	
i 1	606.4859387755102	0.2525	75	678	4	4	2	2	0	1	2	0	0	5.51824952130878	
i 1	606.4953129251701	2.2725	74	678	4	5	3	16	0	2	16	0	0	3.3425598039596673	
i 1	606.5147823129251	1.7675	72	1064	6	1	5	2	0	-2	2	0	0	9.0	
i 1	606.5155034013605	2.02	77	1064	6	5	7	17	0	1	17	0	0	3.3425598039596673	
i 1	606.7352176870749	0.2525	75	678	4	24	8	2	0	-2	2	0	0	12.0	
i 1	607.2424285714286	0.2525	77	678	5	5	16	16	0	1	16	0	0	3.3425598039596673	
i 1	607.4844965986395	0.505	74	180	7	5	1	17	0	1	17	0	0	3.3425598039596673	
i 1	607.4888231292517	0.2525	76	180	1	24	6	16	0	1	16	0	0	5.168761183983925	
i 1	607.4895442176871	0.2525	72	678	6	1	2	2	0	1	2	0	0	9.0	
i 1	607.4996394557824	0.2525	73	678	3	20	5	16	0	2	16	0	0	1.168761183983925	
i 1	607.506850340136	1.01	72	180	5	4	7	2	0	-2	2	0	0	5.51824952130878	
i 1	607.7626190476191	3.2825	72	180	5	24	13	2	0	-2	2	0	0	12.0	
i 1	607.7647823129251	0.2525	76	1064	2	20	3	16	0	2	16	0	0	1.168761183983925	
i 1	608.0046870748299	0.2525	75	1064	5	9	13	8	0	1	8	0	0	4.51824952130878	
i 1	608.2388231292517	0.505	72	678	6	2	13	2	0	-2	2	0	0	5.51824952130878	
i 1	608.2409863945578	0.2525	76	1064	2	20	4	17	0	1	17	0	0	1.168761183983925	
i 1	608.248918367347	1.7675	76	678	1	24	3	16	0	252	16	307	0	5.168761183983925	
i 1	608.2640612244898	1.01	73	1064	3	20	11	17	0	2	17	0	0	1.168761183983925	
i 1	608.483775510204	6.0600000000000005	61	678	4	14	2	6	0	1	6	0	0	5.957502830278859	
i 1	608.5039659863945	0.2525	74	180	4	5	10	17	0	1	17	0	0	3.3425598039596673	
i 1	608.5075714285714	9.09	61	678	4	19	13	6	0	0	6	0	0	3.4492018623622136	
i 1	608.5097346938776	1.7675	75	678	6	1	2	2	0	1	2	0	0	9.0	
i 1	608.5126190476191	6.0600000000000005	66	180	7	7	13	6	0	0	6	0	0	4.766002264223086	
i 1	608.5176666666666	1.5150000000000001	76	1064	3	20	11	17	0	1	17	0	0	1.168761183983925	
i 1	608.7330544217687	1.5150000000000001	75	678	5	3	3	2	0	1	2	0	0	5.51824952130878	
i 1	608.751081632653	1.5150000000000001	72	1064	6	1	3	2	0	-2	2	0	0	9.0	
i 1	608.7518027210884	1.5150000000000001	72	180	6	3	14	8	0	-2	8	0	0	5.51824952130878	
i 1	608.7582925170068	0.2525	77	180	4	5	13	16	0	2	16	0	0	3.3425598039596673	
i 1	609.0133401360545	1.5150000000000001	74	678	5	5	13	17	0	2	17	0	0	3.3425598039596673	
i 1	609.2402653061224	2.2725	72	678	6	2	14	2	0	-2	2	0	0	5.51824952130878	
i 1	609.2647823129251	1.2625	77	180	4	5	2	16	0	2	16	0	0	3.3425598039596673	
i 1	609.7381020408163	1.7675	74	678	4	5	7	16	0	2	16	0	0	3.3425598039596673	
i 1	609.7381020408163	2.02	77	1064	6	5	8	17	0	1	17	0	0	3.3425598039596673	
i 1	609.7503605442176	0.2525	73	1064	3	20	15	17	0	2	17	0	0	1.168761183983925	
i 1	609.9830544217687	0.2525	73	180	3	20	6	17	0	2	17	0	0	1.168761183983925	
i 1	609.9909863945578	0.2525	76	678	4	20	16	17	0	2	17	0	0	1.168761183983925	
i 1	609.9917074829932	0.2525	73	678	4	20	14	17	0	2	17	0	0	1.168761183983925	
i 1	610.0003605442176	2.7775	72	180	7	1	3	2	0	1	2	0	0	9.0	
i 1	610.0003605442176	0.2525	76	180	1	24	15	17	0	2	17	0	0	5.168761183983925	
i 1	610.0133401360545	2.525	72	678	6	1	4	2	0	1	2	0	0	9.0	
i 1	610.2539659863945	1.7675	72	180	5	4	6	2	0	-2	2	0	0	5.51824952130878	
i 1	610.4823333333334	2.2725	77	678	4	5	9	16	0	2	16	0	0	3.3425598039596673	
i 1	610.4888231292517	0.2525	76	180	3	20	11	16	0	1	16	0	0	1.168761183983925	
i 1	610.5097346938776	1.5150000000000001	75	678	4	4	9	2	0	1	2	0	0	5.51824952130878	
i 1	610.7546870748299	1.5150000000000001	76	1064	3	20	10	16	0	1	16	0	0	1.168761183983925	
i 1	610.756850340136	0.2525	73	1064	3	20	10	17	0	1	17	0	0	1.168761183983925	
i 1	610.7611768707483	0.7575000000000001	76	678	1	24	2	16	0	252	16	307	0	5.168761183983925	
i 1	610.9888231292517	1.7675	72	678	6	2	4	2	0	-2	2	0	0	5.51824952130878	
i 1	611.0155034013605	0.505	72	678	6	1	16	2	0	1	2	0	0	9.0	
i 1	611.0169455782313	0.505	75	1064	5	9	7	2	0	1	2	0	0	4.51824952130878	
i 1	611.2575714285714	2.02	75	678	4	24	6	2	0	-2	2	0	0	12.0	
i 1	611.4967551020408	0.7575000000000001	76	678	1	24	2	16	0	1	16	0	0	5.168761183983925	
i 1	611.5003605442176	7.8275	66	678	4	19	11	6	0	0	6	0	0	3.4492018623622136	
i 1	611.5003605442176	6.0600000000000005	66	180	4	13	12	9	0	0	9	0	0	2.383001132111543	
i 1	611.501081632653	1.2625	75	1064	5	9	15	2	0	1	2	0	0	4.51824952130878	
i 1	611.5046870748299	7.8275	66	678	6	17	11	9	0	0	9	0	0	3.4492018623622136	
i 1	611.5111768707483	7.8275	61	678	5	14	12	6	0	0	6	0	0	5.957502830278859	
i 1	611.5155034013605	1.7675	72	180	5	24	3	2	0	-2	2	0	0	12.0	
i 1	611.5169455782313	1.7675	77	180	4	5	1	16	0	2	16	0	0	3.3425598039596673	
i 1	611.7395442176871	1.5150000000000001	72	678	6	2	10	2	0	-2	2	0	0	5.51824952130878	
i 1	611.7647823129251	1.5150000000000001	75	1064	5	9	6	8	0	1	8	0	0	4.51824952130878	
i 1	612.2388231292517	0.505	76	180	4	20	15	17	0	2	17	0	0	1.168761183983925	
i 1	612.7453129251701	0.505	75	678	5	3	6	2	0	1	2	0	0	5.51824952130878	
i 1	612.7460340136055	0.2525	72	1064	6	1	14	2	0	1	2	0	0	9.0	
i 1	612.748918367347	0.505	76	678	2	20	12	17	0	2	17	0	0	1.168761183983925	
i 1	612.7518027210884	0.505	73	1064	3	20	11	16	0	2	16	0	0	1.168761183983925	
i 1	612.7554081632653	0.2525	74	678	4	5	16	16	0	2	16	0	0	3.3425598039596673	
i 1	612.756850340136	0.2525	75	678	4	4	14	2	0	1	2	0	0	5.51824952130878	
i 1	612.7647823129251	0.505	73	678	1	24	15	17	0	2	17	0	0	5.168761183983925	
i 1	612.9859387755102	0.2525	77	1064	6	5	7	17	0	1	17	0	0	3.3425598039596673	
i 1	613.0061292517007	0.2525	72	678	6	1	2	2	0	1	2	0	0	9.0	
i 1	614.5032448979592	4.7975	61	678	5	14	1	6	0	1	6	0	0	5.957502830278859	
i 1	614.5090136054422	4.7975	61	678	6	17	1	9	0	0	9	0	0	3.4492018623622136	
i 1	617.4844965986395	1.7675	61	180	7	17	5	9	0	1	9	0	0	3.4492018623622136	
i 1	617.5054081632653	1.7675	66	180	6	13	1	9	0	0	9	0	0	2.383001132111543	
t0 106
</CsScore>
</CsoundSynthesizer>

