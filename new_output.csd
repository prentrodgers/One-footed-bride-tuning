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

f5000.0 0.0 256.0 -6.0 1.0 128.0 0.9997115 128.0 0.999423 
f5001.0 0.0 256.0 -6.0 1.0 128.0 1.001736 128.0 1.003472 
;Inst	Sta	Hold	Vel	Ton	Oct	Voi	Ste	En1	Gls	Ups	Ren	2gl	3gl	Vol
i 1	0.0013605442176870732	0.2525	72	915	3	4	4	2	0	1	2	0	0	5.0	0	
i 1	0.005714285714285712	9.09	63	915	1	27	16	16	0	252	16	307	0	2.6802591470793242	0	
i 1	0.008435374149659862	3.0300000000000002	63	101	6	25	3	1	0	1	1	0	0	2.23354928923277	0	
i 1	0.011700680272108842	1.01	75	101	7	2	15	2	0	-2	2	0	0	5.0	0	
i 1	0.2410204081632653	0.2525	75	915	3	3	16	8	0	1	8	0	0	5.0	1	
i 1	0.2464625850340136	0.2525	75	915	3	5	15	2	0	1	2	0	0	3.0	1	
i 1	0.4866666666666667	0.2525	71	915	4	24	13	8	0	-1	8	0	0	3.0	1	
i 1	0.5095238095238095	0.2525	72	417	5	5	12	2	0	1	2	0	0	3.0	1	
i 1	0.511156462585034	0.505	72	101	5	2	2	2	0	-2	2	0	0	5.0	1	
i 1	0.7529931972789116	0.505	72	417	4	9	11	2	0	1	2	0	0	4.0	1	
i 1	1.2519047619047619	0.505	75	101	7	2	8	2	0	-2	2	0	0	5.0	1	
i 1	1.2595238095238095	0.2525	71	915	4	24	5	8	0	-1	8	0	0	3.0	1	
i 1	1.488843537414966	1.01	72	101	7	2	7	2	0	-2	2	0	0	5.0	1	
i 1	1.5057142857142858	3.0300000000000002	61	101	6	25	4	1	0	2	1	0	0	2.23354928923277	1	
i 1	1.5073469387755103	0.2525	72	101	7	5	12	2	0	-2	2	0	0	3.0	1	
i 1	1.507891156462585	0.2525	74	417	1	24	14	2	0	-2	2	0	0	4.093637130455701	1	
i 1	1.5095238095238095	0.7575000000000001	72	101	7	5	10	2	0	-2	2	0	0	3.0	1	
i 1	1.510612244897959	0.7575000000000001	74	915	1	20	13	2	0	1	2	0	0	0.0936371304557011	1	
i 1	1.99156462585034	1.2625	75	915	4	4	6	2	0	-2	2	0	0	5.0	1	
i 1	2.2404761904761905	0.2525	74	915	3	20	13	2	0	1	2	0	0	0.0936371304557011	2	
i 1	2.244285714285714	0.2525	75	915	5	5	16	2	0	1	2	0	0	3.0	2	
i 1	2.2595238095238095	0.2525	74	915	1	24	16	2	0	-2	2	0	0	4.093637130455701	2	
i 1	2.2606122448979593	0.2525	74	417	1	24	9	2	0	-2	2	0	0	4.093637130455701	2	
i 1	2.494829931972789	0.505	74	915	1	20	15	2	0	1	2	0	0	0.0936371304557011	2	
i 1	2.5008163265306123	0.2525	72	915	3	4	7	2	0	1	2	0	0	5.0	2	
i 1	2.5008163265306123	0.505	75	915	4	5	12	2	0	1	2	0	0	3.0	2	
i 1	2.512244897959184	0.2525	74	417	4	20	13	8	0	1	8	0	0	0.0936371304557011	2	
i 1	2.751904761904762	0.2525	72	915	4	5	15	8	0	-2	8	0	0	3.0	2	
i 1	2.7529931972789115	0.2525	72	417	4	9	14	2	0	1	2	0	0	4.0	2	
i 1	2.992108843537415	2.525	72	915	6	5	14	8	0	-2	8	0	0	3.0	2	
i 1	3.0029931972789115	0.505	74	915	2	20	5	2	0	1	2	0	0	0.0936371304557011	2	
i 1	3.0040816326530613	4.2925	63	101	6	25	4	1	0	1	1	0	0	2.23354928923277	2	
i 1	3.008979591836735	3.0300000000000002	61	915	5	25	6	1	0	1	1	0	0	2.23354928923277	2	
i 1	3.255714285714286	0.2525	75	417	4	9	6	2	0	-2	2	0	0	4.0	2	
i 1	3.4904761904761905	0.7575000000000001	74	915	3	24	11	2	0	-2	2	0	0	4.093637130455701	2	
i 1	3.986666666666667	0.2525	74	915	4	20	13	2	0	1	2	0	0	0.0936371304557011	2	
i 1	3.9872108843537415	2.02	72	101	7	5	2	2	0	-2	2	0	0	3.0	2	
i 1	4.013333333333334	0.2525	74	417	3	24	14	2	0	-2	2	0	0	4.093637130455701	2	
i 1	4.248639455782313	0.2525	72	101	7	2	6	2	0	-2	2	0	0	5.0	2	
i 1	4.254081632653061	0.2525	74	915	2	20	5	2	0	1	2	0	0	0.0936371304557011	2	
i 1	4.4872108843537415	0.2525	74	915	4	24	6	2	0	-2	2	0	0	4.093637130455701	2	
i 1	4.4904761904761905	3.0300000000000002	61	915	5	25	9	1	0	2	1	0	0	2.23354928923277	2	
i 1	4.491020408163266	2.7775	61	101	6	25	10	1	0	2	1	0	0	2.23354928923277	2	
i 1	4.493197278911564	0.2525	75	101	5	2	12	2	0	-2	2	0	0	5.0	2	
i 1	4.504081632653061	0.2525	74	417	3	24	2	2	0	-2	2	0	0	4.093637130455701	2	
i 1	4.747551020408164	0.505	74	915	2	20	8	2	0	1	2	0	0	0.0936371304557011	2	
i 1	4.7595238095238095	0.7575000000000001	72	101	7	2	8	2	0	-2	2	0	0	5.0	2	
i 1	4.994829931972789	0.2525	71	915	2	24	12	8	0	-1	8	0	0	3.0	2	
i 1	4.998095238095238	0.7575000000000001	71	915	4	24	12	8	0	-1	8	0	0	3.0	2	
i 1	5.489387755102041	0.7575000000000001	72	101	7	5	9	2	0	-2	2	0	0	3.0	2	
i 1	5.745918367346939	0.2525	72	915	2	4	6	2	0	1	2	0	0	5.0	2	
i 1	5.9872108843537415	0.505	74	417	4	24	8	2	0	-2	2	0	0	4.093637130455701	2	
i 1	5.993197278911564	7.3225	61	915	5	25	1	1	0	1	1	0	0	2.23354928923277	2	
i 1	5.9970068027210885	3.0300000000000002	61	417	4	26	1	16	0	1	16	0	0	2.23354928923277	2	
i 1	6.001904761904762	0.505	75	915	4	4	5	2	0	-2	2	0	0	5.0	2	
i 1	6.24265306122449	0.2525	72	101	7	5	15	2	0	-2	2	0	0	3.0	3	
i 1	6.260612244897959	0.2525	74	915	2	24	10	2	0	-2	2	0	0	4.093637130455701	3	
i 1	6.492108843537415	0.2525	72	915	6	5	10	8	0	-2	8	0	0	3.0	4	
i 1	6.495374149659864	0.2525	72	417	4	5	12	2	0	1	2	0	0	3.0	4	
i 1	6.499727891156462	1.01	74	915	1	24	15	2	0	252	2	307	0	4.093637130455701	4	
i 1	6.503537414965987	0.2525	75	417	4	9	1	2	0	-2	2	0	0	4.0	4	
i 1	6.748639455782313	0.505	72	101	7	5	6	2	0	-2	2	0	0	3.0	4	
i 1	6.750816326530612	0.2525	75	915	4	4	14	2	0	-2	2	0	0	5.0	4	
i 1	7.238299319727891	1.2625	75	213	7	5	4	8	0	-2	8	0	0	3.0	6	
i 1	7.255714285714285	3.2825	61	213	6	25	8	1	0	2	1	0	0	2.23354928923277	6	
i 1	7.25843537414966	1.2625	72	213	5	2	16	2	0	-2	2	0	0	5.0	6	
i 1	7.263333333333334	4.7975	63	213	6	25	14	16	0	2	16	0	0	2.23354928923277	6	
i 1	7.488843537414966	5.8075	61	915	5	25	15	1	0	2	1	0	0	2.23354928923277	6	
i 1	7.494285714285715	1.01	71	417	4	20	13	2	0	-2	2	0	0	0.007490970436456301	6	
i 1	7.499183673469388	3.0300000000000002	63	417	4	26	12	1	0	1	1	0	0	2.23354928923277	6	
i 1	7.500816326530612	1.01	71	417	4	20	8	2	0	-2	2	0	0	0.007490970436456301	6	
i 1	7.512244897959183	0.2525	74	915	3	24	8	2	0	-2	2	0	0	4.007490970436456	6	
i 1	7.995374149659864	1.01	74	915	2	24	3	2	0	-2	2	0	0	4.007490970436456	6	
i 1	8.24265306122449	0.505	72	213	7	2	9	2	0	1	2	0	0	5.0	6	
i 1	8.247551020408164	0.2525	72	417	6	5	16	2	0	1	2	0	0	3.0	6	
i 1	8.48938775510204	0.2525	74	915	3	24	9	2	0	-2	2	0	0	4.007490970436456	6	
i 1	8.513333333333334	0.505	75	915	4	4	11	2	0	-2	2	0	0	5.0	6	
i 1	8.738843537414965	1.5150000000000001	72	915	4	3	10	2	0	1	2	0	0	5.0	6	
i 1	8.987210884353741	7.575	61	417	4	26	8	16	0	1	16	0	0	2.23354928923277	6	
i 1	8.99047619047619	0.7575000000000001	74	417	4	20	14	2	0	-2	2	0	0	0.007490970436456301	6	
i 1	8.997006802721089	0.2525	72	915	3	5	7	8	0	-2	8	0	0	3.0	6	
i 1	9.001904761904761	1.01	74	417	4	24	10	2	0	-2	2	0	0	4.007490970436456	6	
i 1	9.003537414965987	3.0300000000000002	63	915	3	27	8	16	0	1	16	0	0	2.6802591470793242	6	
i 1	9.247006802721089	0.2525	75	915	5	5	9	2	0	1	2	0	0	3.0	7	
i 1	9.25625850340136	1.5150000000000001	72	213	7	2	10	2	0	1	2	0	0	5.0	7	
i 1	9.50734693877551	0.2525	72	915	6	5	8	8	0	-2	8	0	0	3.0	7	
i 1	9.738843537414965	0.2525	74	915	4	24	4	2	0	-2	2	0	0	4.007490970436456	7	
i 1	9.743197278911564	0.2525	71	213	4	20	16	2	0	-2	2	0	0	0.007490970436456301	7	
i 1	9.75734693877551	0.7575000000000001	74	915	2	24	4	8	0	-2	8	0	0	4.007490970436456	7	
i 1	9.763333333333334	0.2525	72	417	5	9	8	2	0	1	2	0	0	4.0	7	
i 1	9.987755102040817	0.7575000000000001	74	915	3	24	4	2	0	-2	2	0	0	4.007490970436456	7	
i 1	9.988299319727892	0.505	75	417	5	9	6	2	0	-2	2	0	0	4.0	7	
i 1	9.999727891156462	0.2525	72	417	6	5	14	2	0	1	2	0	0	3.0	7	
i 1	10.002448979591836	0.2525	71	417	4	20	15	2	0	1	2	0	0	0.007490970436456301	7	
i 1	10.246462585034013	0.2525	72	915	4	4	7	2	0	1	2	0	0	5.0	7	
i 1	10.486666666666666	1.5150000000000001	75	915	4	4	9	2	0	-2	2	0	0	5.0	7	
i 1	10.48938775510204	0.2525	74	915	3	24	7	8	0	-2	8	0	0	4.007490970436456	7	
i 1	10.492108843537414	7.575	63	417	4	26	14	1	0	1	1	0	0	2.23354928923277	7	
i 1	10.494285714285715	0.2525	71	417	4	20	10	8	0	-2	8	0	0	0.007490970436456301	7	
i 1	10.501904761904761	0.7575000000000001	74	915	3	24	9	2	0	-2	2	0	0	4.007490970436456	7	
i 1	10.505714285714285	0.2525	71	915	4	24	6	8	0	-1	8	0	0	3.0	7	
i 1	10.511156462585035	2.7775	63	915	3	27	9	16	0	1	16	0	0	2.6802591470793242	7	
i 1	10.750272108843538	0.505	75	213	7	5	15	8	0	1	8	0	0	3.0	7	
i 1	11.004081632653062	1.5150000000000001	72	213	7	2	13	2	0	1	2	0	0	5.0	7	
i 1	11.25952380952381	0.2525	72	213	7	2	2	2	0	-2	2	0	0	5.0	7	
i 1	11.487755102040817	0.2525	71	417	4	20	16	2	0	1	2	0	0	0.007490970436456301	7	
i 1	11.494285714285715	0.7575000000000001	74	915	3	24	5	8	0	-2	8	0	0	4.007490970436456	7	
i 1	11.498095238095239	0.2525	72	915	5	3	1	2	0	1	2	0	0	5.0	7	
i 1	11.506802721088436	0.7575000000000001	74	915	3	24	6	2	0	-2	2	0	0	4.007490970436456	7	
i 1	11.508979591836734	0.505	75	213	7	5	8	8	0	-2	8	0	0	3.0	7	
i 1	11.748095238095239	0.505	74	915	3	20	6	2	0	1	2	0	0	0.007490970436456301	7	
i 1	11.994285714285715	0.2525	75	915	5	5	5	2	0	1	2	0	0	3.0	7	
i 1	11.998639455782312	0.505	75	213	6	5	15	8	0	-2	8	0	0	3.0	7	
i 1	12.000816326530613	0.2525	75	417	4	9	16	2	0	-2	2	0	0	4.0	7	
i 1	12.007891156462586	1.2625	63	915	3	27	4	16	0	1	16	0	0	2.6802591470793242	7	
i 1	12.242108843537414	1.01	75	213	7	5	10	8	0	1	8	0	0	3.0	7	
i 1	12.498095238095239	0.2525	75	417	4	9	4	2	0	-2	2	0	0	4.0	7	
i 1	12.504625850340137	0.2525	75	915	5	5	12	2	0	1	2	0	0	3.0	7	
i 1	12.510068027210885	0.7575000000000001	74	915	3	24	4	8	0	-2	8	0	0	4.007490970436456	7	
i 1	12.73938775510204	0.2525	72	417	4	9	3	2	0	1	2	0	0	4.0	7	
i 1	12.756802721088436	0.505	71	417	4	20	8	8	0	-2	8	0	0	0.007490970436456301	7	
i 1	12.758979591836734	0.2525	72	417	6	5	1	2	0	1	2	0	0	3.0	7	
i 1	12.762244897959183	0.2525	72	417	6	5	7	2	0	1	2	0	0	3.0	7	
i 1	13.242108843537414	1.7675	63	1119	5	25	10	1	0	1	1	0	0	2.23354928923277	8	
i 1	13.245918367346938	1.5150000000000001	75	1119	6	5	14	2	0	1	2	0	0	3.0	8	
i 1	13.246462585034013	0.2525	63	1119	5	25	8	1	0	2	1	0	0	2.23354928923277	8	
i 1	13.249183673469387	0.2525	71	803	4	24	9	8	0	-1	8	0	0	3.0	8	
i 1	13.254625850340137	3.0300000000000002	61	803	3	27	10	1	0	1	1	0	0	2.6802591470793242	8	
i 1	13.257891156462586	0.2525	63	803	3	27	15	1	0	2	1	0	0	2.6802591470793242	8	
i 1	13.50625850340136	2.7775	63	803	3	27	11	1	0	2	1	0	0	2.6802591470793242	9	
i 1	13.512244897959183	0.2525	74	803	3	24	6	8	0	1	8	0	0	4.007490970436456	9	
i 1	13.746462585034013	0.2525	72	417	6	5	8	2	0	1	2	0	0	3.0	9	
i 1	13.999727891156462	0.7575000000000001	72	803	5	5	1	2	0	1	2	0	0	3.0	10	
i 1	14.011700680272108	1.5150000000000001	71	417	4	20	9	2	0	-2	2	0	0	0.007490970436456301	10	
i 1	14.262244897959183	0.2525	75	417	6	2	1	2	0	-2	2	0	0	5.0	11	
i 1	14.49374149659864	1.2625	72	1119	5	3	1	8	0	1	8	0	0	5.0	11	
i 1	14.741020408163266	1.5150000000000001	72	417	6	5	7	2	0	-2	2	0	0	3.0	11	
i 1	14.74156462585034	1.2625	75	417	6	2	13	2	0	-2	2	0	0	5.0	11	
i 1	14.746462585034013	0.2525	75	803	5	5	1	2	0	1	2	0	0	3.0	11	
i 1	14.754625850340137	1.5150000000000001	74	417	4	24	1	2	0	-2	2	0	0	4.007490970436456	11	
i 1	15.005714285714285	0.505	72	1119	6	5	13	2	0	1	2	0	0	3.0	11	
i 1	15.262789115646259	0.2525	72	417	6	5	2	2	0	1	2	0	0	3.0	11	
i 1	15.495374149659863	0.7575000000000001	72	417	6	2	16	2	0	-2	2	0	0	5.0	11	
i 1	15.495374149659863	0.2525	75	1119	5	5	3	2	0	1	2	0	0	3.0	11	
i 1	15.502993197278911	0.2525	74	1119	4	24	4	2	0	-2	2	0	0	4.007490970436456	11	
i 1	15.743197278911564	0.2525	72	803	3	3	9	8	0	1	8	0	0	5.0	11	
i 1	15.762244897959183	0.7575000000000001	71	417	4	20	7	2	0	-2	2	0	0	0.007490970436456301	11	
i 1	16.236666666666668	3.2825	63	915	3	27	16	1	0	2	1	0	0	2.6802591470793242	12	
i 1	16.242108843537416	1.2625	72	417	6	5	16	2	0	1	2	0	0	3.0	12	
i 1	16.24265306122449	4.7975	63	915	3	27	8	16	0	2	16	0	0	2.6802591470793242	12	
i 1	16.251360544217686	1.7675	72	915	5	5	14	2	0	1	2	0	0	3.0	12	
i 1	16.491020408163266	0.2525	74	915	4	24	6	2	0	-2	2	0	0	4.0	12	
i 1	16.50190476190476	0.505	71	915	4	24	13	8	0	-2	8	0	0	3.0	12	
i 1	16.743741496598638	1.5150000000000001	74	915	3	24	5	2	0	-2	2	0	0	4.0	12	
i 1	17.00190476190476	0.2525	71	915	4	24	8	8	0	-1	8	0	0	3.0	12	
i 1	17.25190476190476	0.2525	72	101	7	2	4	2	0	-2	2	0	0	5.0	12	
i 1	17.255714285714287	2.02	72	101	7	2	11	2	0	-2	2	0	0	5.0	12	
i 1	17.496462585034013	1.01	72	101	6	5	16	2	0	-2	2	0	0	3.0	12	
i 1	17.99156462585034	0.2525	72	417	5	5	9	2	0	1	2	0	0	3.0	12	
i 1	18.003537414965987	0.505	71	915	4	24	1	8	0	-1	8	0	0	3.0	12	
i 1	18.25190476190476	0.2525	74	915	4	24	13	2	0	-2	2	0	0	4.0	12	
i 1	18.508979591836734	2.2725	72	915	5	5	3	2	0	-2	2	0	0	3.0	12	
i 1	18.75081632653061	0.2525	75	915	4	4	4	2	0	1	2	0	0	5.0	12	
i 1	18.760068027210885	0.2525	72	915	5	5	2	2	0	1	2	0	0	3.0	12	
i 1	18.98938775510204	0.2525	72	417	6	5	2	2	0	1	2	0	0	3.0	12	
i 1	18.99918367346939	0.505	72	417	5	9	3	2	0	1	2	0	0	4.0	12	
i 1	19.23938775510204	0.505	72	417	5	5	14	2	0	1	2	0	0	3.0	12	
i 1	19.25190476190476	1.01	75	915	5	3	14	2	0	1	2	0	0	5.0	12	
i 1	19.487755102040815	2.02	71	915	4	24	5	8	0	-1	8	0	0	3.0	12	
i 1	19.510068027210885	1.7675	63	915	1	27	2	1	0	252	1	307	0	2.6802591470793242	12	
i 1	19.994829931972788	0.505	75	915	5	5	2	2	0	-2	2	0	0	3.0	12	
i 1	19.99918367346939	0.2525	72	417	5	5	6	2	0	1	2	0	0	3.0	12	
i 1	20.236666666666668	3.2825	72	915	5	5	11	2	0	1	2	0	0	3.0	13	
i 1	20.243197278911566	0.2525	75	915	4	4	10	2	0	1	2	0	0	5.0	13	
i 1	20.495374149659863	0.505	72	417	5	5	11	2	0	1	2	0	0	3.0	14	
i 1	20.502448979591836	0.2525	75	915	4	4	12	2	0	1	2	0	0	5.0	14	
i 1	20.513333333333332	0.2525	74	417	4	24	7	2	0	-2	2	0	0	4.0	14	
i 1	20.988843537414965	0.505	74	915	4	24	13	2	0	-2	2	0	0	4.0	15	
i 1	21.00299319727891	0.2525	63	915	1	27	2	16	0	248	16	308	0	2.6802591470793242	15	
i 1	21.003537414965987	0.2525	72	915	5	5	8	2	0	-2	2	0	0	3.0	15	
i 1	21.236666666666668	1.7675	74	599	3	24	5	8	0	1	8	0	0	4.0	16	
i 1	21.237755102040815	1.2625	63	599	1	27	12	1	0	252	1	307	0	2.6802591470793242	16	
i 1	21.24918367346939	0.2525	72	417	5	5	12	2	0	1	2	0	0	3.0	16	
i 1	21.257891156462584	0.2525	75	915	5	5	1	2	0	-2	2	0	0	3.0	16	
i 1	21.263333333333332	1.2625	63	599	1	27	5	16	0	252	16	307	0	2.6802591470793242	16	
i 1	21.497551020408164	0.2525	74	599	3	24	13	2	0	-2	2	0	0	4.0	16	
i 1	21.499727891156464	0.505	75	915	5	3	8	2	0	1	2	0	0	5.0	16	
i 1	21.501360544217686	0.2525	75	417	5	9	15	2	0	-2	2	0	0	4.0	16	
i 1	21.51061224489796	0.505	72	599	4	5	8	2	0	-2	2	0	0	3.0	16	
i 1	21.758979591836734	0.505	75	915	6	2	1	2	0	-2	2	0	0	5.0	16	
i 1	21.76061224489796	0.2525	71	915	4	24	12	8	0	-1	8	0	0	3.0	16	
i 1	22.002448979591836	0.505	71	599	4	24	11	8	0	-1	8	0	0	3.0	16	
i 1	22.006258503401362	0.2525	75	599	5	5	9	2	0	1	2	0	0	3.0	16	
i 1	22.24047619047619	0.2525	72	417	5	5	7	2	0	1	2	0	0	3.0	16	
i 1	22.245374149659863	0.2525	75	599	4	4	2	2	0	-2	2	0	0	5.0	16	
i 1	22.250272108843536	0.2525	75	915	5	3	10	2	0	1	2	0	0	5.0	16	
i 1	22.486666666666668	5.555	63	915	6	7	4	16	0	1	16	0	0	3.3962957923607635	16	
i 1	22.488843537414965	5.555	63	915	5	13	4	1	0	2	1	0	0	0.5737246101975074	16	
i 1	22.503537414965987	5.555	63	915	5	14	8	1	0	1	1	0	0	4.807581383442391	16	
i 1	22.50408163265306	0.2525	75	599	5	3	7	2	0	-2	2	0	0	11.0	16	
i 1	22.506258503401362	4.545	63	915	5	14	12	16	0	1	16	0	0	4.807581383442391	16	
i 1	22.50734693877551	0.2525	75	915	4	4	1	2	0	1	2	0	0	11.0	16	
i 1	22.73938775510204	0.505	72	417	5	5	14	2	0	1	2	0	0	3.0	16	
i 1	22.993197278911566	0.2525	75	599	5	3	7	2	0	-2	2	0	0	11.0	16	
i 1	23.23829931972789	0.2525	75	599	4	5	6	2	0	1	2	0	0	3.0	17	
i 1	23.25734693877551	0.2525	75	417	5	9	16	2	0	-2	2	0	0	10.0	17	
i 1	23.497551020408164	0.2525	72	915	5	5	10	2	0	1	2	0	0	3.0	17	
i 1	23.741020408163266	0.2525	72	915	5	5	14	2	0	-2	2	0	0	3.0	17	
i 1	23.75952380952381	0.505	72	417	5	5	6	2	0	1	2	0	0	3.0	17	
i 1	23.988843537414965	1.2625	75	915	4	4	8	2	0	1	2	0	0	11.0	17	
i 1	23.99700680272109	1.2625	74	599	3	24	9	2	0	-2	2	0	0	4.0	17	
i 1	24.012789115646257	0.505	75	915	6	5	9	2	0	-2	2	0	0	3.0	17	
i 1	24.24700680272109	0.505	71	915	4	24	11	8	0	-1	8	0	0	3.0	17	
i 1	24.250272108843536	0.2525	72	417	5	5	12	2	0	1	2	0	0	3.0	17	
i 1	24.48829931972789	0.505	72	599	4	5	10	2	0	-2	2	0	0	3.0	17	
i 1	24.49591836734694	0.7575000000000001	71	599	2	24	10	2	0	-2	2	0	0	4.0	17	
i 1	24.75190476190476	2.525	74	417	3	24	15	2	0	-2	2	0	0	4.0	17	
i 1	24.758979591836734	0.2525	71	599	3	24	7	8	0	-1	8	0	0	3.0	17	
i 1	24.762244897959185	0.2525	75	417	5	9	3	2	0	-2	2	0	0	10.0	17	
i 1	24.989931972789115	1.5150000000000001	72	915	5	5	1	2	0	-2	2	0	0	3.0	17	
i 1	25.00190476190476	0.2525	72	915	5	5	15	2	0	1	2	0	0	3.0	17	
i 1	25.247551020408164	0.505	72	417	5	5	12	2	0	1	2	0	0	3.0	17	
i 1	25.489931972789115	2.525	63	915	6	17	8	16	0	1	16	0	0	0.6126620377439105	17	
i 1	25.511156462585035	0.7575000000000001	75	599	4	4	4	2	0	-2	2	0	0	11.0	17	
i 1	25.74591836734694	0.2525	71	599	2	24	13	2	0	-2	2	0	0	4.0	17	
i 1	25.751360544217686	0.2525	75	599	4	5	13	2	0	1	2	0	0	3.0	17	
i 1	25.755714285714287	0.2525	71	599	4	24	5	8	0	-1	8	0	0	3.0	17	
i 1	26.000272108843536	0.2525	71	915	3	24	12	8	0	-2	8	0	0	4.0	17	
i 1	26.006258503401362	0.505	72	417	5	5	15	2	0	1	2	0	0	3.0	17	
i 1	26.23829931972789	0.505	74	599	2	24	7	8	0	1	8	0	0	4.0	17	
i 1	26.261156462585035	1.7675	72	915	6	2	11	8	0	-2	8	0	0	11.0	17	
i 1	26.513333333333332	0.2525	72	599	4	5	3	2	0	-2	2	0	0	3.0	17	
i 1	26.737755102040815	0.2525	74	915	3	24	16	2	0	1	2	0	0	4.0	17	
i 1	26.761156462585035	0.2525	74	599	3	24	1	8	0	1	8	0	0	4.0	17	
i 1	26.987755102040815	1.01	75	599	5	3	15	2	0	-2	2	0	0	11.0	17	
i 1	26.991020408163266	0.505	74	599	2	24	15	8	0	1	8	0	0	4.0	17	
i 1	26.993741496598638	0.7575000000000001	74	599	1	24	12	2	0	252	2	307	0	4.0	17	
i 1	26.995374149659863	1.01	61	915	6	17	8	16	0	1	16	0	0	0.6126620377439105	17	
i 1	26.99591836734694	1.01	63	915	4	14	12	16	0	1	16	0	0	4.807581383442391	17	
i 1	27.00734693877551	1.01	74	599	2	24	14	2	0	-2	2	0	0	4.0	17	
i 1	27.007891156462584	0.2525	72	599	4	5	4	2	0	-2	2	0	0	3.0	17	
i 1	27.49156462585034	0.2525	71	915	4	24	15	8	0	-1	8	0	0	3.0	19	
i 1	27.497551020408164	0.505	75	915	5	3	13	2	0	1	2	0	0	11.0	19	
i 1	27.512789115646257	0.2525	72	213	5	5	10	2	0	-2	2	0	0	3.0	19	
i 1	27.988843537414965	0.505	71	711	3	24	5	2	0	1	2	0	0	4.0	20	
i 1	27.99265306122449	1.7675	74	711	2	24	8	8	0	-2	8	0	0	4.0	20	
i 1	27.993741496598638	0.505	61	1097	6	17	14	1	0	1	1	0	0	0.6126620377439105	20	
i 1	27.994285714285713	6.565	61	711	1	27	15	1	0	252	1	307	0	1.7868394313862161	20	
i 1	27.994285714285713	2.02	61	711	5	13	9	1	0	2	1	0	0	0.5737246101975074	20	
i 1	27.994829931972788	2.02	61	1097	6	17	11	16	0	2	16	0	0	0.6126620377439105	20	
i 1	28.004625850340137	5.05	63	1097	4	14	14	16	0	2	16	0	0	4.807581383442391	20	
i 1	28.005170068027212	0.505	63	1097	5	14	5	1	0	1	1	0	0	4.807581383442391	20	
i 1	28.006802721088434	0.2525	75	711	4	4	9	2	0	-2	2	0	0	11.0	20	
i 1	28.007891156462584	6.565	63	711	1	27	16	1	0	248	1	308	0	1.7868394313862161	20	
i 1	28.010068027210885	0.7575000000000001	72	1097	6	5	3	2	0	-2	2	0	0	3.0	20	
i 1	28.013333333333332	0.2525	72	213	6	9	8	2	0	-2	2	0	0	10.0	20	
i 1	28.255714285714287	0.2525	75	1097	6	2	1	2	0	-2	2	0	0	11.0	21	
i 1	28.487210884353743	6.0600000000000005	63	1097	4	14	8	1	0	1	1	0	0	4.807581383442391	21	
i 1	28.492108843537416	4.545	61	1097	6	17	7	1	0	1	1	0	0	0.6126620377439105	21	
i 1	28.501360544217686	1.7675	63	711	6	17	6	1	0	2	1	0	0	0.6126620377439105	21	
i 1	28.50190476190476	1.2625	71	711	2	24	3	2	0	1	2	0	0	4.0	21	
i 1	28.756802721088434	0.505	75	1097	6	5	10	8	0	-2	8	0	0	3.0	21	
i 1	29.002448979591836	0.2525	75	711	5	3	13	2	0	1	2	0	0	11.0	21	
i 1	29.003537414965987	0.2525	75	213	5	5	9	2	0	-2	2	0	0	3.0	21	
i 1	29.23829931972789	1.2625	72	1097	6	5	4	2	0	-2	2	0	0	3.0	21	
i 1	29.255714285714287	0.7575000000000001	71	213	3	24	8	2	0	1	2	0	0	4.0	21	
i 1	29.25734693877551	0.2525	72	213	6	9	6	2	0	-2	2	0	0	10.0	21	
i 1	29.50081632653061	1.2625	74	711	2	24	13	2	0	1	2	0	0	4.0	21	
i 1	29.511156462585035	0.505	72	711	4	5	16	2	0	-2	2	0	0	3.0	21	
i 1	29.750272108843536	0.2525	75	1097	6	2	15	2	0	-2	2	0	0	11.0	21	
i 1	30.00299319727891	4.545	61	1097	6	17	9	16	0	2	16	0	0	0.6126620377439105	21	
i 1	30.00843537414966	0.2525	63	711	6	17	1	1	0	1	1	0	0	0.6126620377439105	21	
i 1	30.011156462585035	0.2525	61	711	4	13	15	1	0	2	1	0	0	0.5737246101975074	21	
i 1	30.237755102040815	1.2625	61	599	6	17	3	16	0	1	16	0	0	0.6126620377439105	22	
i 1	30.237755102040815	4.2925	63	599	4	13	16	16	0	1	16	0	0	0.5737246101975074	22	
i 1	30.238843537414965	1.2625	71	213	3	24	10	2	0	1	2	0	0	4.0	22	
i 1	30.25734693877551	0.7575000000000001	72	599	6	5	8	8	0	-2	8	0	0	3.0	22	
i 1	30.260068027210885	2.7775	61	599	6	17	7	16	0	2	16	0	0	0.6126620377439105	22	
i 1	30.49700680272109	0.2525	75	711	4	5	14	2	0	-2	2	0	0	3.0	22	
i 1	30.510068027210885	0.7575000000000001	74	711	2	24	8	2	0	1	2	0	0	4.0	22	
i 1	30.987755102040815	0.505	72	1097	6	5	13	2	0	-2	2	0	0	3.0	22	
i 1	30.989931972789115	0.505	75	1097	6	2	8	2	0	-2	2	0	0	11.0	22	
i 1	31.48938775510204	3.0300000000000002	61	599	6	17	16	16	0	1	16	0	0	0.6126620377439105	22	
i 1	31.49047619047619	3.0300000000000002	63	213	5	18	1	16	0	2	16	0	0	0.6126620377439105	22	
i 1	31.510068027210885	1.7675	74	599	4	24	13	8	0	-1	8	0	0	3.0	22	
i 1	31.513333333333332	3.0300000000000002	63	599	4	7	15	1	0	1	1	0	0	3.3962957923607635	22	
i 1	31.753537414965987	1.2625	72	599	4	4	16	2	0	1	2	0	0	11.0	22	
i 1	32.00353741496598	0.7575000000000001	71	711	4	24	3	8	0	-2	8	0	0	3.0	22	
i 1	32.00408163265306	2.2725	71	711	2	24	2	2	0	1	2	0	0	4.0	22	
i 1	32.24374149659864	0.2525	71	711	2	24	7	8	0	1	8	0	0	4.0	22	
i 1	32.24755102040816	0.2525	72	213	6	9	3	2	0	-2	2	0	0	10.0	22	
i 1	32.50027210884354	0.2525	72	599	6	5	2	8	0	-2	8	0	0	3.0	22	
i 1	32.50190476190476	0.2525	75	711	5	3	12	2	0	1	2	0	0	11.0	22	
i 1	32.744285714285716	1.01	72	599	5	3	14	2	0	-2	2	0	0	11.0	22	
i 1	32.74755102040816	0.2525	72	599	6	5	4	2	0	-2	2	0	0	3.0	22	
i 1	32.760068027210885	0.2525	75	711	4	5	13	2	0	-2	2	0	0	3.0	22	
i 1	32.98829931972789	1.5150000000000001	63	1097	5	14	6	16	0	2	16	0	0	4.807581383442391	22	
i 1	32.99265306122449	1.5150000000000001	61	1097	6	17	13	1	0	1	1	0	0	0.6126620377439105	22	
i 1	32.99591836734694	1.5150000000000001	61	599	6	17	6	16	0	2	16	0	0	0.6126620377439105	22	
i 1	32.99700680272109	1.01	72	1097	4	5	15	2	0	-2	2	0	0	3.0	22	
i 1	33.00625850340136	1.5150000000000001	71	213	1	24	13	2	0	252	2	307	0	4.0	22	
i 1	33.00734693877551	1.5150000000000001	63	213	5	18	10	1	0	2	1	0	0	0.6126620377439105	22	
i 1	33.239931972789115	1.2625	75	1097	6	2	16	2	0	-2	2	0	0	11.0	22	
i 1	33.488843537414965	0.7575000000000001	75	1097	6	5	6	8	0	-2	8	0	0	3.0	22	
i 1	33.50462585034013	0.2525	72	599	4	4	2	2	0	1	2	0	0	11.0	22	
i 1	33.512244897959185	0.2525	71	711	4	24	3	8	0	-2	8	0	0	3.0	22	
i 1	33.513333333333335	0.2525	72	599	6	5	3	2	0	-2	2	0	0	3.0	22	
i 1	33.74537414965987	0.2525	75	1097	6	2	7	2	0	-2	2	0	0	11.0	22	
i 1	33.75734693877551	0.2525	75	711	5	3	6	2	0	1	2	0	0	11.0	22	
i 1	33.75734693877551	0.505	74	599	3	24	3	2	0	1	2	0	0	4.0	22	
i 1	33.757891156462584	0.2525	74	599	4	24	10	8	0	-1	8	0	0	3.0	22	
i 1	33.989931972789115	0.505	72	599	4	4	4	2	0	1	2	0	0	11.0	22	
i 1	34.00027210884354	0.505	72	599	6	5	16	8	0	-2	8	0	0	3.0	22	
i 1	34.487755102040815	6.8175	61	904	1	27	8	16	0	252	16	307	0	1.7868394313862161	24	
i 1	34.488843537414965	4.545	61	904	4	18	9	16	0	1	16	0	0	0.6126620377439105	24	
i 1	34.49591836734694	3.0300000000000002	63	90	7	17	14	1	0	2	1	0	0	0.6126620377439105	24	
i 1	34.49755102040816	3.0300000000000002	61	90	6	14	15	16	0	1	16	0	0	4.807581383442391	24	
i 1	34.50136054421769	1.5150000000000001	61	90	7	17	16	1	0	1	1	0	0	0.6126620377439105	24	
i 1	34.50353741496598	1.5150000000000001	61	90	6	14	7	1	0	1	1	0	0	4.807581383442391	24	
i 1	34.50408163265306	1.5150000000000001	61	406	6	17	15	1	0	2	1	0	0	0.6126620377439105	24	
i 1	34.50517006802721	3.0300000000000002	61	904	4	19	10	1	0	2	1	0	0	0.6126620377439105	24	
i 1	34.50734693877551	0.505	74	904	2	24	12	2	0	-2	2	0	0	4.0	24	
i 1	34.50734693877551	0.2525	74	904	2	24	3	8	0	-2	8	0	0	4.0	24	
i 1	34.511156462585035	1.5150000000000001	61	406	4	13	15	16	0	2	16	0	0	0.5737246101975074	24	
i 1	34.511156462585035	3.0300000000000002	61	406	4	7	1	1	0	2	1	0	0	3.3962957923607635	24	
i 1	34.51170068027211	3.0300000000000002	63	406	6	17	10	16	0	2	16	0	0	0.6126620377439105	24	
i 1	34.513333333333335	1.5150000000000001	61	904	4	18	6	16	0	1	16	0	0	0.6126620377439105	24	
i 1	34.992108843537416	2.525	71	904	1	24	6	2	0	252	2	307	0	4.0	25	
i 1	34.99482993197279	0.2525	75	90	5	5	16	2	0	1	2	0	0	3.0	25	
i 1	34.99700680272109	0.2525	72	406	6	5	14	2	0	1	2	0	0	3.0	25	
i 1	35.00408163265306	0.2525	71	904	2	24	5	2	0	-2	2	0	0	4.0	25	
i 1	35.260612244897956	0.505	74	904	3	24	11	2	0	-2	2	0	0	3.0	26	
i 1	35.262244897959185	0.505	75	406	6	5	15	2	0	1	2	0	0	3.0	26	
i 1	35.49918367346939	0.2525	72	904	4	4	7	2	0	1	2	0	0	11.0	26	
i 1	35.507891156462584	1.01	75	90	5	5	8	2	0	1	2	0	0	3.0	26	
i 1	35.739387755102044	3.7875	74	904	1	24	2	2	0	252	2	307	0	4.0	26	
i 1	35.74646258503402	0.7575000000000001	72	90	6	2	7	2	0	-2	2	0	0	11.0	26	
i 1	35.75244897959184	0.2525	74	406	4	24	9	2	0	-1	2	0	0	3.0	26	
i 1	35.98721088435374	4.545	61	904	4	18	8	16	0	1	16	0	0	0.6126620377439105	26	
i 1	35.991020408163266	1.5150000000000001	75	406	6	5	16	2	0	1	2	0	0	3.0	26	
i 1	35.99918367346939	5.3025	61	90	5	14	9	1	0	1	1	0	0	4.807581383442391	26	
i 1	36.00244897959184	3.0300000000000002	61	406	5	13	1	16	0	2	16	0	0	0.5737246101975074	26	
i 1	36.00353741496598	3.0300000000000002	61	904	4	19	13	1	0	2	1	0	0	0.6126620377439105	26	
i 1	36.005714285714284	5.3025	61	90	6	17	11	1	0	1	1	0	0	0.6126620377439105	26	
i 1	36.00843537414966	3.0300000000000002	61	406	6	17	8	1	0	2	1	0	0	0.6126620377439105	26	
i 1	36.00952380952381	0.2525	74	904	3	24	4	2	0	-2	2	0	0	3.0	26	
i 1	36.24755102040816	3.0300000000000002	71	904	2	24	10	2	0	-2	2	0	0	4.0	26	
i 1	36.49047619047619	0.2525	75	904	5	3	14	8	0	1	8	0	0	11.0	26	
i 1	36.49047619047619	0.2525	72	904	6	5	5	2	0	-2	2	0	0	3.0	26	
i 1	36.507891156462584	0.2525	75	904	6	5	10	8	0	-2	8	0	0	3.0	26	
i 1	36.739387755102044	0.2525	72	904	5	9	9	2	0	1	2	0	0	10.0	26	
i 1	36.744285714285716	0.7575000000000001	75	904	6	5	8	2	0	1	2	0	0	3.0	26	
i 1	37.006802721088434	0.7575000000000001	75	406	4	4	15	2	0	1	2	0	0	11.0	26	
i 1	37.24646258503402	0.2525	75	90	5	5	10	2	0	-2	2	0	0	3.0	27	
i 1	37.25244897959184	0.2525	72	904	5	9	14	2	0	1	2	0	0	10.0	27	
i 1	37.48721088435374	3.7875	61	90	5	14	2	16	0	1	16	0	0	4.807581383442391	27	
i 1	37.48829931972789	0.2525	71	904	2	24	15	2	0	-2	2	0	0	4.0	27	
i 1	37.494285714285716	0.505	72	90	6	2	2	2	0	-2	2	0	0	11.0	27	
i 1	37.494285714285716	2.2725	72	406	4	5	11	2	0	1	2	0	0	3.0	27	
i 1	37.50190476190476	3.0300000000000002	63	406	6	17	7	16	0	2	16	0	0	0.6126620377439105	27	
i 1	37.50244897959184	3.7875	61	904	4	19	13	1	0	2	1	0	0	0.6126620377439105	27	
i 1	37.50353741496598	3.0300000000000002	61	406	6	7	16	1	0	2	1	0	0	3.3962957923607635	27	
i 1	37.506802721088434	3.7875	63	90	6	17	8	1	0	2	1	0	0	0.6126620377439105	27	
i 1	37.744285714285716	0.7575000000000001	71	904	1	24	2	2	0	248	2	308	0	4.0	27	
i 1	37.75625850340136	1.01	72	406	5	3	1	2	0	-2	2	0	0	11.0	27	
i 1	37.76170068027211	0.2525	74	904	2	24	11	8	0	-2	8	0	0	4.0	27	
i 1	38.23721088435374	2.7775	72	90	6	2	16	2	0	-2	2	0	0	11.0	27	
i 1	38.25408163265306	0.2525	74	406	4	24	16	2	0	-1	2	0	0	3.0	27	
i 1	38.257891156462584	0.505	75	90	5	5	4	2	0	-2	2	0	0	3.0	27	
i 1	38.49700680272109	0.505	72	904	6	5	6	2	0	-2	2	0	0	3.0	27	
i 1	38.75462585034013	0.2525	72	904	5	9	2	2	0	1	2	0	0	10.0	27	
i 1	38.756802721088434	0.2525	75	406	4	5	9	2	0	1	2	0	0	3.0	27	
i 1	38.75843537414966	0.2525	72	90	6	2	2	2	0	-2	2	0	0	11.0	27	
i 1	38.987755102040815	2.2725	61	904	4	19	9	1	0	2	1	0	0	0.6126620377439105	27	
i 1	38.99156462585034	3.0300000000000002	61	904	4	18	2	16	0	1	16	0	0	0.6126620377439105	27	
i 1	38.993197278911566	0.505	72	406	5	3	7	2	0	-2	2	0	0	11.0	27	
i 1	38.99482993197279	1.01	75	90	5	5	6	2	0	-2	2	0	0	3.0	27	
i 1	38.99482993197279	2.2725	61	406	4	13	16	16	0	2	16	0	0	0.5737246101975074	27	
i 1	39.006802721088434	2.2725	61	406	5	17	1	1	0	2	1	0	0	0.6126620377439105	27	
i 1	39.239931972789115	0.2525	75	904	6	5	12	2	0	1	2	0	0	3.0	27	
i 1	39.489931972789115	0.2525	71	904	2	24	14	2	0	-2	2	0	0	4.0	27	
i 1	39.50136054421769	0.2525	72	904	5	9	3	2	0	1	2	0	0	10.0	27	
i 1	39.50299319727891	0.2525	71	406	1	24	14	2	0	1	2	0	0	4.0	27	
i 1	39.74047619047619	0.2525	72	904	5	9	1	8	0	-2	8	0	0	10.0	27	
i 1	39.75027210884354	0.2525	72	90	6	2	3	2	0	-2	2	0	0	11.0	27	
i 1	39.75081632653061	1.2625	75	90	5	5	3	2	0	1	2	0	0	3.0	27	
i 1	39.99156462585034	0.2525	75	904	5	3	13	8	0	1	8	0	0	11.0	27	
i 1	40.238843537414965	0.2525	72	406	4	5	3	2	0	1	2	0	0	3.0	27	
i 1	40.493197278911566	0.7575000000000001	63	406	5	17	13	16	0	2	16	0	0	0.6126620377439105	27	
i 1	40.49918367346939	0.7575000000000001	75	406	4	4	3	2	0	1	2	0	0	11.0	27	
i 1	40.508979591836734	0.7575000000000001	61	406	4	7	14	1	0	2	1	0	0	3.3962957923607635	27	
i 1	40.510612244897956	1.7675	61	904	4	18	7	16	0	1	16	0	0	0.6126620377439105	27	
i 1	40.987755102040815	0.2525	72	406	5	3	8	2	0	-2	2	0	0	11.0	27	
i 1	40.991020408163266	0.2525	75	904	6	5	12	8	0	-2	8	0	0	3.0	27	
i 1	41.00299319727891	0.2525	71	904	2	24	3	2	0	-2	2	0	0	4.0	27	
i 1	41.010068027210885	0.2525	75	90	5	5	4	2	0	-2	2	0	0	3.0	27	
i 1	41.23721088435374	1.01	61	202	5	14	3	16	0	1	16	0	0	4.807581383442391	28	
i 1	41.238843537414965	0.2525	71	202	2	24	15	2	0	-2	2	0	0	4.0	28	
i 1	41.239387755102044	1.01	61	202	5	14	16	1	0	2	1	0	0	4.807581383442391	28	
i 1	41.241020408163266	1.01	63	202	1	27	2	1	0	252	1	307	0	1.7868394313862161	28	
i 1	41.24156462585034	1.01	63	202	5	19	9	1	0	2	1	0	0	0.6126620377439105	28	
i 1	41.24265306122449	0.2525	75	202	7	5	7	2	0	-2	2	0	0	3.0	28	
i 1	41.24374149659864	1.01	71	202	2	24	2	2	0	1	2	0	0	4.0	28	
i 1	41.244285714285716	0.2525	72	588	5	3	8	2	0	1	2	0	0	11.0	28	
i 1	41.24482993197279	0.7575000000000001	61	202	6	17	2	1	0	2	1	0	0	0.6126620377439105	28	
i 1	41.24755102040816	1.01	63	588	5	17	14	16	0	1	16	0	0	0.6126620377439105	28	
i 1	41.24755102040816	0.7575000000000001	61	202	5	19	13	16	0	2	16	0	0	0.6126620377439105	28	
i 1	41.257891156462584	1.01	61	588	4	13	2	16	0	1	16	0	0	0.5737246101975074	28	
i 1	41.25952380952381	1.01	63	588	5	17	8	16	0	2	16	0	0	0.6126620377439105	28	
i 1	41.260612244897956	1.01	63	202	1	27	10	16	0	252	16	307	0	1.7868394313862161	28	
i 1	41.263333333333335	1.01	61	202	6	17	11	16	0	2	16	0	0	0.6126620377439105	28	
i 1	41.263333333333335	1.01	61	588	4	7	6	16	0	2	16	0	0	3.3962957923607635	28	
i 1	41.49482993197279	0.2525	72	202	6	2	14	8	0	-2	8	0	0	11.0	29	
i 1	41.75462585034013	0.505	72	202	5	3	7	2	0	-2	2	0	0	11.0	29	
i 1	42.00244897959184	0.2525	61	202	7	17	8	1	0	2	1	0	0	0.6126620377439105	30	
i 1	42.011156462585035	0.2525	61	904	4	18	9	16	0	1	16	0	0	0.6126620377439105	30	
i 1	42.011156462585035	0.2525	61	202	5	19	4	16	0	2	16	0	0	0.6126620377439105	30	
i 1	42.011156462585035	0.2525	71	202	2	24	14	2	0	-2	2	0	0	4.0	30	
i 1	42.236666666666665	2.02	61	588	4	13	2	16	0	1	16	0	0	0.5737246101975074	31	
i 1	42.239387755102044	2.02	61	588	4	7	6	16	0	2	16	0	0	3.3962957923607635	31	
i 1	42.243197278911566	2.02	63	202	1	27	2	1	0	252	1	307	0	1.7868394313862161	31	
i 1	42.24482993197279	1.2625	61	202	6	17	11	16	0	2	16	0	0	0.6126620377439105	31	
i 1	42.24646258503402	2.02	61	202	7	17	8	1	0	2	1	0	0	0.6126620377439105	31	
i 1	42.24972789115646	0.7575000000000001	72	904	3	5	16	2	0	1	2	0	0	3.0	31	
i 1	42.25027210884354	2.02	61	202	5	14	16	1	0	2	1	0	0	4.807581383442391	31	
i 1	42.25190476190476	2.02	61	202	5	19	4	16	0	2	16	0	0	0.6126620377439105	31	
i 1	42.25244897959184	0.2525	72	904	4	9	10	8	0	-2	8	0	0	10.0	31	
i 1	42.25408163265306	0.2525	74	202	2	24	10	2	0	-2	2	0	0	4.0	31	
i 1	42.25517006802721	2.02	63	588	5	17	8	16	0	2	16	0	0	0.6126620377439105	31	
i 1	42.256802721088434	1.2625	61	904	4	18	7	16	0	1	16	0	0	0.6126620377439105	31	
i 1	42.257891156462584	2.7775	61	904	4	18	9	16	0	1	16	0	0	0.6126620377439105	31	
i 1	42.257891156462584	1.2625	63	202	5	19	9	1	0	2	1	0	0	0.6126620377439105	31	
i 1	42.257891156462584	1.2625	75	202	5	5	11	2	0	-2	2	0	0	3.0	31	
i 1	42.261156462585035	2.02	63	202	1	27	10	16	0	252	16	307	0	1.7868394313862161	31	
i 1	42.262244897959185	2.02	61	202	5	14	3	16	0	1	16	0	0	4.807581383442391	31	
i 1	42.26278911564626	2.02	63	588	5	17	14	16	0	1	16	0	0	0.6126620377439105	31	
i 1	42.76170068027211	0.505	72	588	4	4	14	2	0	-2	2	0	0	11.0	31	
i 1	42.76170068027211	0.505	71	202	2	24	15	2	0	-2	2	0	0	4.0	31	
i 1	42.763333333333335	0.2525	72	588	4	5	7	8	0	1	8	0	0	3.0	31	
i 1	42.99047619047619	0.2525	72	202	5	5	7	2	0	-2	2	0	0	3.0	31	
i 1	43.00625850340136	1.2625	75	588	4	5	6	8	0	1	8	0	0	3.0	31	
i 1	43.236666666666665	0.7575000000000001	71	202	2	24	12	2	0	1	2	0	0	4.0	31	
i 1	43.242108843537416	0.2525	72	904	4	9	13	2	0	1	2	0	0	10.0	31	
i 1	43.25353741496598	0.7575000000000001	71	202	2	24	16	2	0	1	2	0	0	4.0	31	
i 1	43.488843537414965	1.5150000000000001	61	904	4	18	13	16	0	1	16	0	0	0.6126620377439105	31	
i 1	43.49755102040816	0.7575000000000001	63	202	5	19	11	1	0	2	1	0	0	0.6126620377439105	31	
i 1	43.50843537414966	0.7575000000000001	61	202	7	17	13	16	0	2	16	0	0	0.6126620377439105	31	
i 1	43.74700680272109	0.505	71	588	4	24	6	2	0	-2	2	0	0	3.0	31	
i 1	43.74755102040816	0.2525	72	202	7	5	3	2	0	-2	2	0	0	3.0	31	
i 1	43.994285714285716	0.2525	75	202	7	2	13	2	0	-2	2	0	0	11.0	31	
i 1	44.23829931972789	0.7575000000000001	63	406	4	7	6	16	0	1	16	0	0	3.3962957923607635	32	
i 1	44.24047619047619	0.7575000000000001	63	406	5	17	3	16	0	2	16	0	0	0.6126620377439105	32	
i 1	44.241020408163266	0.7575000000000001	61	90	7	17	10	1	0	2	1	0	0	0.6126620377439105	32	
i 1	44.24156462585034	0.7575000000000001	63	406	5	17	7	1	0	2	1	0	0	0.6126620377439105	32	
i 1	44.243197278911566	0.7575000000000001	61	406	4	13	14	1	0	2	1	0	0	0.5737246101975074	32	
i 1	44.24374149659864	0.7575000000000001	63	904	4	19	13	16	0	2	16	0	0	0.6126620377439105	32	
i 1	44.24482993197279	0.7575000000000001	61	90	5	14	1	1	0	2	1	0	0	4.807581383442391	32	
i 1	44.24700680272109	0.7575000000000001	63	90	7	17	5	1	0	2	1	0	0	0.6126620377439105	32	
i 1	44.24863945578231	0.505	75	406	5	3	2	2	0	1	2	0	0	11.0	32	
i 1	44.25299319727891	0.7575000000000001	72	90	7	5	11	2	0	-2	2	0	0	3.0	32	
i 1	44.25843537414966	0.7575000000000001	63	90	5	14	12	1	0	1	1	0	0	4.807581383442391	32	
i 1	44.258979591836734	0.7575000000000001	61	904	4	19	13	1	0	1	1	0	0	0.6126620377439105	32	
i 1	44.262244897959185	0.7575000000000001	61	904	1	27	7	16	0	248	16	308	0	1.7868394313862161	32	
i 1	44.98829931972789	1.5150000000000001	63	406	5	17	11	16	0	2	16	0	0	2.2222299575273565	32	
i 1	44.994285714285716	4.2925	61	90	7	17	1	1	0	2	1	0	0	2.2222299575273565	32	
i 1	44.99646258503402	4.545	61	406	4	13	12	1	0	2	1	0	0	0.9438112578936171	32	
i 1	44.99700680272109	4.2925	63	90	7	17	2	1	0	2	1	0	0	2.2222299575273565	32	
i 1	44.99809523809524	3.0300000000000002	61	904	4	18	3	16	0	1	16	0	0	2.2222299575273565	32	
i 1	44.99809523809524	3.0300000000000002	63	90	5	14	8	1	0	1	1	0	0	5.177668031138501	32	
i 1	44.99918367346939	1.5150000000000001	63	904	4	19	3	16	0	2	16	0	0	2.2222299575273565	32	
i 1	45.00027210884354	4.2925	61	904	4	18	2	16	0	1	16	0	0	2.2222299575273565	32	
i 1	45.00027210884354	4.2925	61	904	3	19	5	1	0	1	1	0	0	2.2222299575273565	32	
i 1	45.00136054421769	1.5150000000000001	61	90	5	14	10	1	0	2	1	0	0	5.177668031138501	32	
i 1	45.00299319727891	7.575	63	406	6	17	14	1	0	2	1	0	0	2.2222299575273565	32	
i 1	45.25136054421769	1.2625	74	904	2	24	14	8	0	-2	8	0	0	4.0	32	
i 1	45.49156462585034	0.2525	72	904	4	9	15	8	0	-2	8	0	0	10.0	32	
i 1	45.49700680272109	1.7675	72	406	4	5	2	8	0	1	8	0	0	3.0	32	
i 1	45.742108843537416	2.7775	71	406	4	24	8	2	0	-2	2	0	0	3.0	32	
i 1	45.99265306122449	1.5150000000000001	75	90	7	2	3	2	0	1	2	0	0	11.0	32	
i 1	46.25625850340136	0.2525	72	904	3	5	4	8	0	-2	8	0	0	3.0	32	
i 1	46.488843537414965	2.7775	61	90	6	14	10	1	0	2	1	0	0	5.177668031138501	32	
i 1	46.50027210884354	2.7775	63	904	3	19	10	16	0	2	16	0	0	2.2222299575273565	32	
i 1	46.50244897959184	7.575	63	406	6	17	5	16	0	2	16	0	0	2.2222299575273565	32	
i 1	46.510068027210885	0.2525	72	904	2	5	14	8	0	-2	8	0	0	3.0	32	
i 1	46.74809523809524	0.2525	74	904	2	20	2	2	0	-2	2	0	0	0.2490747670121647	32	
i 1	46.75952380952381	1.01	72	406	6	5	3	2	0	-2	2	0	0	3.0	32	
i 1	46.75952380952381	0.2525	71	90	4	20	10	8	0	-2	8	0	0	0.2490747670121647	32	
i 1	46.99482993197279	1.5150000000000001	74	904	1	20	3	2	0	1	2	0	0	0.2490747670121647	32	
i 1	47.24755102040816	0.2525	72	904	3	5	6	2	0	1	2	0	0	3.0	32	
i 1	47.50462585034013	0.505	75	406	5	3	15	2	0	1	2	0	0	11.0	32	
i 1	47.75353741496598	1.01	72	904	3	5	6	8	0	-2	8	0	0	3.0	32	
i 1	47.992108843537416	1.5150000000000001	72	406	4	4	15	2	0	-2	2	0	0	11.0	32	
i 1	48.00517006802721	1.2625	61	904	4	18	3	16	0	1	16	0	0	2.2222299575273565	32	
i 1	48.00734693877551	1.2625	63	90	6	14	16	1	0	1	1	0	0	5.177668031138501	32	
i 1	48.992108843537416	0.2525	74	406	3	24	1	2	0	1	2	0	0	4.249074767012164	35	
i 1	48.99755102040816	0.2525	72	90	7	2	4	2	0	-2	2	0	0	11.0	35	
i 1	49.00299319727891	0.2525	72	904	3	5	16	2	0	1	2	0	0	3.0	35	
i 1	49.00408163265306	0.2525	74	904	2	24	13	8	0	-2	8	0	0	4.249074767012164	35	
i 1	49.23829931972789	1.7675	63	1108	6	17	10	1	0	2	1	0	0	2.2222299575273565	36	
i 1	49.23829931972789	0.505	72	406	6	5	13	2	0	-2	2	0	0	3.0	36	
i 1	49.24047619047619	3.2825	61	406	4	19	1	1	0	1	1	0	0	2.2222299575273565	36	
i 1	49.24047619047619	1.7675	63	1108	5	14	14	16	0	1	16	0	0	5.177668031138501	36	
i 1	49.24646258503402	6.3125	61	792	4	18	2	16	0	2	16	0	0	2.2222299575273565	36	
i 1	49.24646258503402	0.2525	61	792	4	18	2	1	0	2	1	0	0	2.2222299575273565	36	
i 1	49.25136054421769	0.2525	61	1108	5	14	16	16	0	2	16	0	0	5.177668031138501	36	
i 1	49.25353741496598	1.7675	63	406	4	19	9	16	0	2	16	0	0	2.2222299575273565	36	
i 1	49.25734693877551	1.7675	72	1108	6	2	7	2	0	-2	2	0	0	11.0	36	
i 1	49.260612244897956	0.2525	71	1108	3	20	8	2	0	1	2	0	0	0.2490747670121647	36	
i 1	49.263333333333335	0.2525	63	1108	6	17	3	16	0	2	16	0	0	2.2222299575273565	36	
i 1	49.489387755102044	0.505	72	406	6	5	3	8	0	1	8	0	0	3.0	36	
i 1	49.50244897959184	6.565	61	792	4	18	4	1	0	2	1	0	0	2.2222299575273565	36	
i 1	49.50244897959184	3.0300000000000002	61	406	5	13	10	1	0	2	1	0	0	0.9438112578936171	36	
i 1	49.50299319727891	0.505	72	406	4	3	11	2	0	1	2	0	0	11.0	36	
i 1	49.50843537414966	5.8075	61	1108	3	14	5	16	0	2	16	0	0	5.177668031138501	36	
i 1	49.51170068027211	0.505	71	406	4	24	14	2	0	-2	2	0	0	3.0	36	
i 1	49.513333333333335	1.5150000000000001	63	1108	6	17	8	16	0	2	16	0	0	2.2222299575273565	36	
i 1	49.99047619047619	0.2525	75	406	5	3	13	2	0	1	2	0	0	11.0	36	
i 1	49.99972789115646	0.7575000000000001	74	406	2	24	11	2	0	-2	2	0	0	4.249074767012164	36	
i 1	50.00517006802721	0.2525	72	792	6	5	15	2	0	-2	2	0	0	3.0	36	
i 1	50.005714285714284	0.7575000000000001	74	406	3	24	7	2	0	1	2	0	0	4.249074767012164	36	
i 1	50.25027210884354	0.2525	72	792	4	9	5	8	0	1	8	0	0	10.0	36	
i 1	50.262244897959185	0.2525	75	1108	6	5	2	2	0	-2	2	0	0	3.0	36	
i 1	50.74646258503402	1.2625	75	1108	6	5	4	2	0	-2	2	0	0	3.0	36	
i 1	50.75136054421769	0.7575000000000001	74	406	2	24	9	2	0	1	2	0	0	4.249074767012164	36	
i 1	50.758979591836734	0.7575000000000001	74	792	2	24	11	2	0	-2	2	0	0	4.249074767012164	36	
i 1	50.98721088435374	1.5150000000000001	63	1108	6	17	4	1	0	2	1	0	0	2.2222299575273565	36	
i 1	50.99755102040816	5.05	63	406	4	19	13	16	0	2	16	0	0	2.2222299575273565	36	
i 1	51.00299319727891	3.0300000000000002	63	406	5	7	1	16	0	1	16	0	0	3.766382440056873	36	
i 1	51.013333333333335	4.2925	63	1108	3	14	4	16	0	1	16	0	0	5.177668031138501	36	
i 1	51.24809523809524	0.505	71	406	4	24	7	8	0	-2	8	0	0	3.0	37	
i 1	51.494285714285716	0.505	71	792	2	20	15	2	0	-2	2	0	0	0.2490747670121647	37	
i 1	51.50462585034013	0.2525	72	792	5	5	16	2	0	-2	2	0	0	3.0	37	
i 1	51.74537414965987	0.7575000000000001	72	406	6	5	9	8	0	1	8	0	0	3.0	37	
i 1	51.993197278911566	0.2525	75	406	5	3	8	2	0	1	2	0	0	11.0	37	
i 1	52.244285714285716	0.2525	71	406	4	24	1	8	0	-2	8	0	0	3.0	37	
i 1	52.24537414965987	0.505	72	1108	6	2	5	2	0	-2	2	0	0	11.0	37	
i 1	52.25952380952381	0.2525	75	1108	6	5	8	2	0	-2	2	0	0	3.0	37	
i 1	52.49156462585034	1.5150000000000001	63	406	6	17	8	1	0	2	1	0	0	2.2222299575273565	37	
i 1	52.49918367346939	3.535	61	406	4	19	15	1	0	1	1	0	0	2.2222299575273565	37	
i 1	52.505714285714284	0.505	72	406	6	5	14	2	0	-2	2	0	0	3.0	37	
i 1	52.512244897959185	2.7775	61	406	3	13	12	1	0	2	1	0	0	0.9438112578936171	37	
i 1	52.74700680272109	0.2525	75	406	4	4	5	2	0	1	2	0	0	11.0	37	
i 1	52.987755102040815	0.2525	75	1108	6	5	5	2	0	-2	2	0	0	3.0	37	
i 1	52.994285714285716	2.02	71	406	4	24	14	2	0	-2	2	0	0	3.0	37	
i 1	52.99972789115646	1.5150000000000001	75	406	5	3	6	2	0	1	2	0	0	11.0	37	
i 1	53.25299319727891	0.2525	75	792	5	5	12	2	0	-2	2	0	0	3.0	37	
i 1	53.74265306122449	0.7575000000000001	74	406	2	24	15	8	0	1	8	0	0	4.249074767012164	37	
i 1	53.74755102040816	0.7575000000000001	74	406	1	20	4	2	0	1	2	0	0	0.2490747670121647	37	
i 1	53.991020408163266	1.2625	63	406	4	7	5	16	0	1	16	0	0	3.766382440056873	37	
i 1	53.994285714285716	1.2625	63	406	6	17	16	16	0	2	16	0	0	2.2222299575273565	37	
i 1	54.00299319727891	1.2625	75	1108	5	5	8	2	0	-2	2	0	0	3.0	37	
i 1	55.24374149659864	0.7575000000000001	61	1107	3	14	9	16	0	1	16	0	0	5.177668031138501	38	
i 1	55.244285714285716	0.2525	63	174	7	17	13	1	0	2	1	0	0	2.2222299575273565	38	
i 1	55.24863945578231	0.7575000000000001	61	174	3	13	1	1	0	2	1	0	0	0.9438112578936171	38	
i 1	55.24972789115646	0.2525	72	174	6	3	16	2	0	1	2	0	0	11.0	38	
i 1	55.260068027210885	0.7575000000000001	61	1107	3	14	10	1	0	1	1	0	0	5.177668031138501	38	
i 1	55.49374149659864	0.505	61	792	4	18	12	16	0	2	16	0	0	2.2222299575273565	39	
i 1	55.50462585034013	0.505	74	1107	1	20	14	2	0	-2	2	0	0	0.2490747670121647	39	
i 1	55.739387755102044	0.2525	72	792	5	5	1	2	0	-2	2	0	0	3.0	39	
i 1	55.988843537414965	1.01	63	882	4	18	13	1	0	2	1	0	0	2.2222299575273565	40	
i 1	55.99591836734694	7.07	61	882	3	14	16	16	0	1	16	0	0	5.177668031138501	40	
i 1	55.99700680272109	1.01	75	882	4	2	3	2	0	1	2	0	0	11.0	40	
i 1	56.00027210884354	1.2625	75	882	5	5	15	2	0	1	2	0	0	3.0	40	
i 1	56.00625850340136	1.01	63	882	4	18	7	1	0	1	1	0	0	2.2222299575273565	40	
i 1	56.00843537414966	5.555	63	882	3	14	6	16	0	1	16	0	0	5.177668031138501	40	
i 1	56.00952380952381	6.565	61	68	3	13	11	1	0	1	1	0	0	0.9438112578936171	40	
i 1	56.01170068027211	2.2725	61	566	4	19	9	16	0	1	16	0	0	2.2222299575273565	40	
i 1	56.012244897959185	0.505	72	882	5	5	5	2	0	1	2	0	0	3.0	40	
i 1	56.013333333333335	2.2725	61	566	4	19	7	16	0	1	16	0	0	2.2222299575273565	40	
i 1	56.24482993197279	0.7575000000000001	72	566	5	3	11	2	0	1	2	0	0	11.0	41	
i 1	56.49537414965987	0.2525	72	566	5	5	8	2	0	1	2	0	0	3.0	41	
i 1	56.74755102040816	0.2525	75	882	5	5	5	8	0	-2	8	0	0	3.0	41	
i 1	56.75081632653061	0.2525	71	68	1	20	13	0	0	-1	0	0	0	0.2490747670121647	41	
i 1	56.75190476190476	0.2525	74	566	2	24	15	2	0	-2	2	0	0	4.249074767012164	41	
i 1	56.992108843537416	1.5150000000000001	75	68	4	3	2	8	0	-2	8	0	0	11.0	41	
i 1	57.010068027210885	1.5150000000000001	63	882	4	18	11	1	0	2	1	0	0	2.2222299575273565	41	
i 1	57.24646258503402	0.2525	75	882	5	9	9	2	0	1	2	0	0	10.0	41	
i 1	57.25462585034013	1.2625	72	68	5	5	16	2	0	-2	2	0	0	3.0	41	
i 1	58.242108843537416	4.2925	71	384	1	24	11	1	0	248	1	308	0	4.249074767012164	42	
i 1	58.25299319727891	1.7675	61	384	4	19	5	6	0	2	6	0	0	2.2222299575273565	42	
i 1	58.255714285714284	0.2525	61	384	4	19	6	6	0	1	6	0	0	2.2222299575273565	42	
i 1	58.489931972789115	1.7675	75	68	4	4	6	8	0	1	8	0	0	11.0	42	
i 1	58.492108843537416	0.2525	72	68	5	5	11	2	0	-2	2	0	0	3.0	42	
i 1	58.50081632653061	2.7775	75	882	6	5	5	2	0	1	2	0	0	3.0	42	
i 1	58.50625850340136	1.5150000000000001	61	384	4	19	9	6	0	1	6	0	0	2.2222299575273565	42	
i 1	58.75843537414966	0.2525	75	882	6	5	7	2	0	1	2	0	0	3.0	42	
i 1	59.98829931972789	1.5150000000000001	61	384	4	19	5	6	0	2	6	0	0	2.2222299575273565	42	
i 1	60.007891156462584	1.5150000000000001	61	882	5	17	13	1	0	1	1	0	0	2.2222299575273565	42	
i 1	60.25408163265306	1.5150000000000001	75	882	4	2	1	8	0	-2	8	0	0	11.0	42	
i 1	61.49156462585034	0.7575000000000001	72	68	6	5	14	2	0	-2	2	0	0	3.0	42	
i 1	61.49646258503402	6.0600000000000005	61	882	6	17	15	1	0	1	1	0	0	2.2222299575273565	42	
i 1	61.50027210884354	1.5150000000000001	61	882	5	17	7	1	0	2	1	0	0	2.2222299575273565	42	
i 1	61.511156462585035	0.2525	71	882	1	20	8	8	0	1	8	0	0	0.2490747670121647	42	
i 1	61.51170068027211	3.0300000000000002	63	882	4	14	10	16	0	1	16	0	0	5.177668031138501	42	
i 1	62.48721088435374	0.2525	75	882	6	5	10	2	0	1	2	0	0	3.0	44	
i 1	62.494285714285716	3.535	61	566	4	7	4	9	0	1	9	0	0	3.766382440056873	44	
i 1	62.49591836734694	2.02	66	566	3	13	16	9	0	1	9	0	0	0.9438112578936171	44	
i 1	62.49646258503402	1.5150000000000001	74	566	4	3	2	2	0	-1	2	0	0	11.0	44	
i 1	62.507891156462584	0.2525	72	180	5	24	13	2	0	-2	2	0	0	3.0	44	
i 1	62.50952380952381	0.2525	68	180	1	20	4	1	0	-1	1	0	0	0.2490747670121647	44	
i 1	62.739931972789115	0.2525	71	566	1	24	12	0	0	-1	0	0	0	4.249074767012164	44	
i 1	62.76170068027211	1.7675	72	566	6	5	2	1	0	-1	1	0	0	3.0	44	
i 1	62.99156462585034	1.5150000000000001	66	566	5	17	4	9	0	1	9	0	0	2.2222299575273565	45	
i 1	63.005714285714284	4.545	61	882	6	17	4	1	0	2	1	0	0	2.2222299575273565	45	
i 1	63.013333333333335	3.0300000000000002	61	882	4	14	7	16	0	1	16	0	0	5.177668031138501	45	
i 1	63.25027210884354	2.2725	74	566	4	4	3	2	0	-1	2	0	0	11.0	46	
i 1	63.256802721088434	0.7575000000000001	71	180	1	20	9	1	0	-1	1	0	0	0.2490747670121647	46	
i 1	63.491020408163266	0.2525	75	882	5	2	2	8	0	-2	8	0	0	11.0	46	
i 1	63.75244897959184	0.7575000000000001	75	882	4	2	12	2	0	1	2	0	0	11.0	46	
i 1	63.987755102040815	0.2525	68	180	1	20	5	1	0	-1	1	0	0	0.2490747670121647	46	
i 1	63.98829931972789	0.2525	72	384	4	24	16	2	0	1	2	0	0	3.0	46	
i 1	63.991020408163266	0.2525	71	384	4	4	5	8	0	-1	8	0	0	11.0	46	
i 1	64.23938775510204	0.2525	68	180	1	24	10	1	0	-1	1	0	0	4.249074767012164	46	
i 1	64.24809523809523	0.2525	71	384	3	3	6	8	0	-1	8	0	0	11.0	46	
i 1	64.49102040816327	3.0300000000000002	66	566	4	13	14	9	0	1	9	0	0	0.9438112578936171	46	
i 1	64.49156462585034	3.0300000000000002	63	882	5	14	4	16	0	1	16	0	0	5.177668031138501	46	
i 1	64.49319727891157	1.5150000000000001	66	566	5	17	13	6	0	2	6	0	0	2.2222299575273565	46	
i 1	64.49809523809523	3.0300000000000002	66	566	6	17	14	9	0	1	9	0	0	2.2222299575273565	46	
i 1	64.76006802721088	0.2525	72	180	6	5	15	1	0	0	1	0	0	3.0	46	
i 1	65.00027210884353	0.2525	71	384	3	3	11	8	0	-1	8	0	0	11.0	46	
i 1	65.23775510204082	0.2525	71	882	1	20	8	1	0	-1	1	0	0	0.2490747670121647	47	
i 1	65.26115646258503	0.2525	68	566	1	20	10	1	0	0	1	0	0	0.2490747670121647	47	
i 1	65.48993197278912	0.2525	71	384	3	4	2	8	0	-1	8	0	0	11.0	47	
i 1	65.76006802721088	1.7675	68	180	1	20	16	1	0	-1	1	0	0	0.2490747670121647	47	
i 1	65.76061224489796	1.2625	71	180	1	20	11	1	0	-1	1	0	0	0.2490747670121647	47	
i 1	65.98829931972789	1.5150000000000001	66	180	5	18	15	9	0	2	9	0	0	2.2222299575273565	47	
i 1	65.99319727891157	1.5150000000000001	75	882	4	5	2	2	0	1	2	0	0	3.0	47	
i 1	65.99537414965987	1.5150000000000001	61	566	4	7	15	9	0	1	9	0	0	3.766382440056873	47	
i 1	65.99755102040817	1.5150000000000001	66	566	6	17	7	6	0	2	6	0	0	2.2222299575273565	47	
i 1	66.00081632653061	1.5150000000000001	61	882	5	14	12	16	0	1	16	0	0	5.177668031138501	47	
i 1	66.24102040816327	1.2625	74	566	4	4	1	2	0	-1	2	0	0	11.0	47	
i 1	66.50136054421769	0.2525	71	384	3	4	8	8	0	-1	8	0	0	11.0	47	
i 1	66.51224489795918	0.2525	71	180	4	9	7	2	0	-1	2	0	0	10.0	47	
i 1	66.74972789115647	0.2525	68	180	1	20	5	1	0	-1	1	0	0	0.2490747670121647	47	
i 1	66.75462585034013	0.7575000000000001	72	566	4	24	3	2	0	1	2	0	0	3.0	47	
i 1	67.01006802721088	0.2525	72	180	6	5	13	0	0	-1	0	0	0	3.0	47	
i 1	67.24591836734695	0.2525	68	180	1	24	11	1	0	-1	1	0	0	4.249074767012164	47	
i 1	67.25462585034013	0.2525	68	180	1	20	9	0	0	0	0	0	0	0.2490747670121647	47	
i 1	67.48721088435374	0.2525	75	180	5	1	5	2	0	1	2	0	0	2.424640090656279	47	
i 1	67.48721088435374	4.7975	66	180	5	18	16	9	0	2	9	0	0	3.7185586686313403	47	
i 1	67.48775510204082	1.7675	61	384	1	27	12	6	0	252	6	307	0	2.23354928923277	47	
i 1	67.48993197278912	4.7975	66	566	6	17	15	6	0	2	6	0	0	3.7185586686313403	47	
i 1	67.48993197278912	1.5150000000000001	66	180	5	18	2	6	0	1	6	0	0	3.7185586686313403	47	
i 1	67.49102040816327	4.7975	66	566	6	17	5	9	0	1	9	0	0	3.7185586686313403	47	
i 1	67.49210884353741	2.525	61	882	6	17	2	1	0	1	1	0	0	3.7185586686313403	47	
i 1	67.49210884353741	2.525	61	882	6	17	4	1	0	2	1	0	0	3.7185586686313403	47	
i 1	67.49265306122449	4.7975	66	566	5	13	9	9	0	1	9	0	0	0.20561703548373014	47	
i 1	67.49319727891157	0.505	74	566	4	4	2	2	0	-1	2	0	0	4.000000000000001	47	
i 1	67.49591836734695	2.525	63	882	5	14	12	16	0	1	16	0	0	4.439473808728613	47	
i 1	67.49863945578231	0.2525	74	882	6	1	15	2	0	-2	2	0	0	2.424640090656279	47	
i 1	67.50244897959183	2.2725	68	180	1	20	14	1	0	-1	1	0	0	0.13384601588667877	47	
i 1	67.50299319727891	1.01	72	384	5	5	6	1	0	0	1	0	0	3.0	47	
i 1	67.50462585034013	0.2525	72	180	6	5	5	1	0	0	1	0	0	3.0	47	
i 1	67.50517006802721	0.2525	71	384	3	4	9	8	0	-1	8	0	0	4.000000000000001	47	
i 1	67.51224489795918	2.525	61	882	5	14	9	16	0	1	16	0	0	4.439473808728613	47	
i 1	67.74646258503401	0.2525	75	882	4	5	11	2	0	1	2	0	0	3.0	47	
i 1	67.74755102040817	2.2725	75	882	6	2	10	2	0	1	2	0	0	4.000000000000001	47	
i 1	67.99809523809523	0.2525	75	882	4	5	8	2	0	1	2	0	0	3.0	47	
i 1	68.01224489795918	0.2525	75	180	5	1	3	8	0	-2	8	0	0	2.424640090656279	47	
i 1	68.01333333333334	0.505	74	180	4	9	10	8	0	-1	8	0	0	3.000000000000001	47	
i 1	68.24863945578231	0.505	72	384	5	5	10	1	0	-1	1	0	0	3.0	47	
i 1	68.48829931972789	1.01	72	566	4	5	6	0	0	0	0	0	0	3.0	47	
i 1	68.48993197278912	0.2525	74	566	5	3	10	2	0	-1	2	0	0	4.000000000000001	47	
i 1	68.51115646258503	0.2525	75	566	6	1	12	2	0	1	2	0	0	2.424640090656279	47	
i 1	68.73721088435374	0.2525	75	882	6	2	6	8	0	-2	8	0	0	4.000000000000001	47	
i 1	68.99918367346939	0.2525	66	384	4	19	5	9	0	1	9	0	0	3.7185586686313403	47	
i 1	69.00081632653061	3.2825	66	180	5	18	11	6	0	1	6	0	0	3.7185586686313403	47	
i 1	69.01115646258503	0.2525	75	882	4	5	1	2	0	1	2	0	0	3.0	47	
i 1	69.23829931972789	0.7575000000000001	61	566	1	27	2	9	0	252	9	307	0	2.23354928923277	48	
i 1	69.24537414965987	0.2525	75	566	6	1	3	2	0	1	2	0	0	2.424640090656279	48	
i 1	69.24809523809523	0.7575000000000001	61	566	4	19	7	6	0	1	6	0	0	3.7185586686313403	48	
i 1	69.25081632653061	0.2525	75	180	6	1	5	2	0	1	2	0	0	2.424640090656279	48	
i 1	69.25789115646259	0.7575000000000001	75	882	6	5	14	2	0	1	2	0	0	3.0	48	
i 1	69.49265306122449	2.02	72	566	4	24	5	2	0	1	2	0	0	5.424640090656279	49	
i 1	69.50897959183673	0.505	74	566	5	3	2	2	0	-1	2	0	0	4.000000000000001	49	
i 1	69.73829931972789	0.7575000000000001	74	566	4	4	7	2	0	-1	2	0	0	4.000000000000001	49	
i 1	69.74591836734695	0.2525	72	180	6	5	10	1	0	0	1	0	0	3.0	49	
i 1	69.75952380952381	0.505	68	180	1	20	14	0	0	0	0	0	0	0.13384601588667877	49	
i 1	69.98938775510204	1.7675	72	566	4	5	1	1	0	-1	1	0	0	3.0	50	
i 1	69.99265306122449	0.2525	75	180	5	1	11	8	0	-2	8	0	0	2.424640090656279	50	
i 1	69.99265306122449	2.2725	61	798	1	27	2	9	0	252	9	307	0	2.23354928923277	50	
i 1	69.99482993197279	0.505	61	798	4	19	14	6	0	2	6	0	0	3.7185586686313403	50	
i 1	69.99700680272109	0.2525	71	180	5	9	15	2	0	-1	2	0	0	3.000000000000001	50	
i 1	69.99863945578231	2.2725	61	1064	5	14	13	6	0	1	6	0	0	4.439473808728613	50	
i 1	70.00027210884353	2.02	61	1064	6	17	4	9	0	2	9	0	0	3.7185586686313403	50	
i 1	70.00462585034013	2.2725	61	1064	6	17	2	9	0	2	9	0	0	3.7185586686313403	50	
i 1	70.00517006802721	2.2725	66	1064	5	14	7	9	0	2	9	0	0	4.439473808728613	50	
i 1	70.24265306122449	2.02	68	180	1	20	4	1	0	-1	1	0	0	0.13384601588667877	51	
i 1	70.24755102040817	0.2525	68	1064	1	20	13	1	0	0	1	0	0	0.13384601588667877	51	
i 1	70.25408163265305	1.7675	74	1064	6	2	7	8	0	-2	8	0	0	4.000000000000001	51	
i 1	70.25843537414966	0.2525	68	566	1	20	12	0	0	0	0	0	0	0.13384601588667877	51	
i 1	70.26278911564626	0.505	72	566	4	5	16	0	0	0	0	0	0	3.0	51	
i 1	70.50244897959183	0.7575000000000001	68	180	1	20	14	0	0	0	0	0	0	0.13384601588667877	51	
i 1	70.50843537414966	1.7675	61	798	4	19	1	6	0	2	6	0	0	3.7185586686313403	51	
i 1	70.50843537414966	1.5150000000000001	61	798	4	19	13	9	0	1	9	0	0	3.7185586686313403	51	
i 1	70.73938775510204	0.505	74	566	4	4	9	2	0	-1	2	0	0	4.000000000000001	51	
i 1	70.75789115646259	0.2525	71	180	6	9	2	2	0	-1	2	0	0	3.000000000000001	51	
i 1	70.98993197278912	0.505	72	180	6	5	14	1	0	0	1	0	0	3.0	51	
i 1	70.99537414965987	0.2525	75	798	4	1	10	2	0	1	2	0	0	2.424640090656279	51	
i 1	70.99700680272109	1.01	68	180	1	24	13	1	0	-1	1	0	0	4.133846015886679	51	
i 1	70.99972789115647	0.2525	75	1064	6	1	14	8	0	1	8	0	0	2.424640090656279	51	
i 1	71.24537414965987	0.505	74	180	5	9	4	8	0	-1	8	0	0	3.000000000000001	51	
i 1	71.24646258503401	1.01	72	1064	6	1	3	2	0	-2	2	0	0	2.424640090656279	51	
i 1	71.25625850340136	0.7575000000000001	68	566	1	24	4	0	0	0	0	0	0	4.133846015886679	51	
i 1	71.26170068027211	0.2525	68	1064	1	20	16	1	0	0	1	0	0	0.13384601588667877	51	
i 1	71.75789115646259	0.2525	72	180	4	5	14	0	0	-1	0	0	0	3.0	51	
i 1	71.98721088435374	0.2525	61	1064	6	17	8	9	0	2	9	0	0	3.7185586686313403	51	
i 1	72.00462585034013	0.2525	61	798	4	19	9	9	0	1	9	0	0	3.7185586686313403	51	
i 1	72.00952380952381	0.2525	74	1064	5	2	5	8	0	-2	8	0	0	4.000000000000001	51	
i 1	72.23666666666666	5.05	61	882	4	19	2	6	0	2	6	0	0	3.7185586686313403	52	
i 1	72.23721088435374	4.2925	66	68	5	18	12	9	0	1	9	0	0	3.7185586686313403	52	
i 1	72.23829931972789	5.05	61	882	4	19	12	6	0	2	6	0	0	3.7185586686313403	52	
i 1	72.23884353741497	0.2525	71	68	1	20	12	1	0	0	1	0	0	0.13384601588667877	52	
i 1	72.24156462585034	8.8375	61	384	5	13	4	9	0	2	9	0	0	0.20561703548373014	52	
i 1	72.24265306122449	0.505	68	68	3	20	10	1	0	-1	1	0	0	0.13384601588667877	52	
i 1	72.24537414965987	4.2925	61	384	6	17	3	9	0	2	9	0	0	3.7185586686313403	52	
i 1	72.24646258503401	4.2925	66	68	5	18	12	9	0	1	9	0	0	3.7185586686313403	52	
i 1	72.24646258503401	7.3225	66	68	6	14	16	9	0	1	9	0	0	4.439473808728613	52	
i 1	72.25136054421769	0.505	71	68	6	2	9	2	0	-1	2	0	0	4.000000000000001	52	
i 1	72.25190476190477	2.7775	66	68	7	17	11	6	0	2	6	0	0	3.7185586686313403	52	
i 1	72.25190476190477	5.8075	66	68	6	14	6	6	0	1	6	0	0	4.439473808728613	52	
i 1	72.25353741496599	1.2625	61	68	7	17	4	6	0	1	6	0	0	3.7185586686313403	52	
i 1	72.25952380952381	1.2625	74	68	7	2	1	8	0	-2	8	0	0	4.000000000000001	52	
i 1	72.26170068027211	1.2625	69	384	4	5	5	0	0	0	0	0	0	3.0	52	
i 1	72.26333333333334	1.2625	75	384	4	24	7	2	0	-2	2	0	0	5.424640090656279	52	
i 1	72.26333333333334	2.7775	61	384	6	17	4	9	0	2	9	0	0	3.7185586686313403	52	
i 1	72.50027210884353	0.2525	72	68	6	1	1	2	0	-2	2	0	0	2.424640090656279	52	
i 1	72.51333333333334	0.2525	74	384	5	3	9	2	0	-2	2	0	0	4.000000000000001	52	
i 1	72.73775510204082	0.2525	71	384	1	24	1	1	0	-1	1	0	0	4.133846015886679	52	
i 1	72.74755102040817	0.2525	74	882	4	3	8	2	0	-1	2	0	0	4.000000000000001	52	
i 1	73.25462585034013	0.505	75	68	7	1	14	8	0	1	8	0	0	2.424640090656279	52	
i 1	73.49755102040817	0.2525	74	68	6	9	14	8	0	-2	8	0	0	3.000000000000001	52	
i 1	73.50353741496599	3.0300000000000002	61	68	7	17	10	6	0	1	6	0	0	3.7185586686313403	52	
i 1	73.74482993197279	1.7675	75	68	7	1	12	8	0	-2	8	0	0	2.424640090656279	52	
i 1	74.24755102040817	1.7675	68	68	1	20	9	0	0	-1	0	0	0	0.13384601588667877	52	
i 1	74.50517006802721	0.505	72	882	5	1	9	2	0	-2	2	0	0	2.424640090656279	52	
i 1	74.50734693877551	0.2525	72	882	4	24	13	8	0	1	8	0	0	5.424640090656279	52	
i 1	74.99265306122449	3.0300000000000002	61	384	6	17	15	9	0	2	9	0	0	3.7185586686313403	52	
i 1	74.99265306122449	0.2525	71	68	1	24	15	1	0	-1	1	0	0	4.133846015886679	52	
i 1	74.99374149659864	0.505	74	384	5	3	2	2	0	-2	2	0	0	4.000000000000001	52	
i 1	74.99646258503401	1.5150000000000001	71	384	4	4	16	2	0	-2	2	0	0	4.000000000000001	52	
i 1	75.00408163265305	0.2525	75	68	6	1	4	2	0	1	2	0	0	2.424640090656279	52	
i 1	75.01115646258503	9.09	66	68	6	17	13	6	0	2	6	0	0	3.7185586686313403	52	
i 1	75.24863945578231	2.7775	69	68	7	5	1	1	0	-1	1	0	0	3.0	52	
i 1	75.25353741496599	0.505	72	68	7	1	12	2	0	-2	2	0	0	2.424640090656279	52	
i 1	75.48884353741497	1.01	71	68	3	20	16	1	0	0	1	0	0	0.13384601588667877	52	
i 1	75.50843537414966	0.2525	72	384	6	1	1	2	0	-2	2	0	0	2.424640090656279	52	
i 1	75.74428571428571	0.505	74	384	5	3	7	2	0	-2	2	0	0	4.000000000000001	52	
i 1	75.99047619047619	3.535	71	68	6	2	1	2	0	-1	2	0	0	4.000000000000001	52	
i 1	76.23721088435374	0.2525	71	68	1	24	6	1	0	-1	1	0	0	4.133846015886679	53	
i 1	76.25625850340136	0.2525	68	68	3	20	1	1	0	-1	1	0	0	0.13384601588667877	53	
i 1	76.48775510204082	3.0300000000000002	61	384	6	17	9	9	0	2	9	0	0	3.7185586686313403	54	
i 1	76.48829931972789	0.2525	72	68	6	5	3	1	0	0	1	0	0	3.0	54	
i 1	76.48938775510204	0.7575000000000001	71	1086	2	20	14	1	0	-1	1	0	0	0.13384601588667877	54	
i 1	76.49156462585034	7.575	61	68	6	17	15	6	0	1	6	0	0	3.7185586686313403	54	
i 1	76.49428571428571	0.505	69	882	3	5	3	1	0	0	1	0	0	3.0	54	
i 1	76.49482993197279	0.7575000000000001	61	1086	4	18	11	6	0	1	6	0	0	3.7185586686313403	54	
i 1	76.49646258503401	0.2525	74	1086	5	9	6	8	0	-2	8	0	0	3.000000000000001	54	
i 1	76.51170068027211	0.7575000000000001	61	1086	4	18	6	9	0	1	9	0	0	3.7185586686313403	54	
i 1	76.76170068027211	1.01	72	384	6	5	2	0	0	0	0	0	0	3.0	54	
i 1	76.99646258503401	0.2525	69	1086	5	5	12	1	0	0	1	0	0	3.0	55	
i 1	76.99918367346939	0.2525	68	882	2	24	9	0	0	-1	0	0	0	4.133846015886679	55	
i 1	77.24210884353741	2.2725	66	882	4	18	11	6	0	1	6	0	0	3.7185586686313403	56	
i 1	77.24374149659864	0.505	69	68	3	5	11	0	0	-1	0	0	0	3.0	56	
i 1	77.24482993197279	5.3025	66	68	5	19	3	6	0	1	6	0	0	3.7185586686313403	56	
i 1	77.24700680272109	0.2525	75	384	4	24	7	2	0	-2	2	0	0	5.424640090656279	56	
i 1	77.24863945578231	0.2525	71	882	5	9	10	2	0	-2	2	0	0	3.000000000000001	56	
i 1	77.25517006802721	0.2525	71	68	2	24	9	0	0	-1	0	0	0	4.133846015886679	56	
i 1	77.25625850340136	0.2525	72	68	5	24	8	2	0	-2	2	0	0	5.424640090656279	56	
i 1	77.25734693877551	0.7575000000000001	66	882	4	18	11	6	0	1	6	0	0	3.7185586686313403	56	
i 1	77.25843537414966	3.7875	61	68	5	19	6	9	0	1	9	0	0	3.7185586686313403	56	
i 1	77.26115646258503	0.2525	68	882	2	20	4	0	0	-1	0	0	0	0.13384601588667877	56	
i 1	77.50789115646259	0.505	74	68	6	3	4	8	0	-2	8	0	0	4.000000000000001	56	
i 1	77.75136054421769	2.02	71	882	2	20	15	1	0	0	1	0	0	0.13384601588667877	56	
i 1	77.98666666666666	3.0300000000000002	66	882	4	18	1	6	0	1	6	0	0	3.7185586686313403	56	
i 1	77.98775510204082	8.3325	61	384	5	17	16	9	0	2	9	0	0	3.7185586686313403	56	
i 1	77.99102040816327	0.2525	72	68	6	1	5	2	0	-2	2	0	0	2.424640090656279	56	
i 1	78.00027210884353	6.0600000000000005	66	68	4	14	14	6	0	1	6	0	0	4.439473808728613	56	
i 1	78.00952380952381	0.505	72	384	6	1	6	2	0	-2	2	0	0	2.424640090656279	56	
i 1	78.01170068027211	4.545	61	68	6	25	13	6	0	1	6	0	0	1.7868394313862161	56	
i 1	78.24265306122449	0.505	72	68	5	5	12	1	0	0	1	0	0	3.0	56	
i 1	78.49428571428571	0.2525	75	882	6	1	1	2	0	-2	2	0	0	2.424640090656279	56	
i 1	78.49918367346939	0.2525	72	68	6	5	1	1	0	0	1	0	0	3.0	56	
i 1	78.50571428571429	1.7675	71	384	4	4	7	2	0	-2	2	0	0	4.000000000000001	56	
i 1	78.73775510204082	0.505	74	384	5	3	15	2	0	-2	2	0	0	4.000000000000001	56	
i 1	78.99319727891157	1.2625	75	68	7	1	4	8	0	-2	8	0	0	2.424640090656279	56	
i 1	79.24102040816327	0.2525	72	68	6	5	15	1	0	0	1	0	0	3.0	57	
i 1	79.24374149659864	0.2525	74	68	5	4	4	2	0	-1	2	0	0	4.000000000000001	57	
i 1	79.49319727891157	4.545	66	68	4	14	6	9	0	1	9	0	0	4.439473808728613	57	
i 1	79.49700680272109	3.0300000000000002	66	882	4	18	13	6	0	1	6	0	0	3.7185586686313403	57	
i 1	79.49755102040817	0.2525	74	384	5	3	3	2	0	-2	2	0	0	4.000000000000001	57	
i 1	79.50517006802721	2.2725	75	68	5	1	6	8	0	1	8	0	0	2.424640090656279	57	
i 1	79.50843537414966	6.8175	61	384	5	17	7	9	0	2	9	0	0	3.7185586686313403	57	
i 1	79.51170068027211	0.2525	69	882	5	5	7	1	0	0	1	0	0	3.0	57	
i 1	79.51278911564626	4.545	66	68	6	25	6	6	0	2	6	0	0	1.7868394313862161	57	
i 1	79.73829931972789	1.5150000000000001	68	882	2	20	12	1	0	0	1	0	0	0.13384601588667877	57	
i 1	79.75952380952381	0.2525	72	68	5	24	7	2	0	-2	2	0	0	5.424640090656279	57	
i 1	79.98884353741497	0.505	71	68	6	2	15	2	0	-1	2	0	0	4.000000000000001	57	
i 1	80.00843537414966	0.2525	72	384	5	5	8	0	0	0	0	0	0	3.0	57	
i 1	80.24482993197279	0.2525	72	384	6	1	4	2	0	-2	2	0	0	2.424640090656279	57	
i 1	80.49156462585034	0.505	75	68	7	1	6	8	0	-2	8	0	0	2.424640090656279	57	
i 1	80.50734693877551	0.2525	72	882	6	1	1	2	0	1	2	0	0	2.424640090656279	57	
i 1	80.51170068027211	0.2525	69	68	5	5	3	0	0	-1	0	0	0	3.0	57	
i 1	80.74156462585034	3.2825	75	384	4	24	10	2	0	-2	2	0	0	5.424640090656279	57	
i 1	80.75299319727891	0.2525	74	68	5	4	2	2	0	-1	2	0	0	4.000000000000001	57	
i 1	80.75517006802721	0.505	72	882	5	5	12	1	0	0	1	0	0	3.0	57	
i 1	80.98938775510204	4.545	61	384	5	25	14	6	0	1	6	0	0	1.7868394313862161	57	
i 1	80.99646258503401	0.2525	72	68	6	5	16	1	0	0	1	0	0	3.0	57	
i 1	81.00027210884353	5.3025	61	384	3	13	13	9	0	2	9	0	0	0.20561703548373014	57	
i 1	81.01061224489796	5.3025	66	882	4	18	2	6	0	1	6	0	0	3.7185586686313403	57	
i 1	81.01224489795918	2.2725	61	68	5	19	7	9	0	1	9	0	0	3.7185586686313403	57	
i 1	81.24210884353741	0.2525	68	384	3	24	12	0	0	-1	0	0	0	4.133846015886679	57	
i 1	81.25571428571429	0.505	69	68	6	5	2	1	0	-1	1	0	0	3.0	57	
i 1	81.25789115646259	0.2525	72	384	6	1	12	2	0	-2	2	0	0	2.424640090656279	57	
i 1	81.26006802721088	0.2525	71	68	4	20	8	1	0	0	1	0	0	0.13384601588667877	57	
i 1	81.26170068027211	2.2725	72	384	5	5	9	0	0	0	0	0	0	3.0	57	
i 1	81.48829931972789	0.2525	69	68	5	5	3	0	0	-1	0	0	0	3.0	57	
i 1	81.49047619047619	0.505	68	68	2	24	4	1	0	-1	1	0	0	4.133846015886679	57	
i 1	81.50027210884353	0.505	75	882	6	1	1	2	0	-2	2	0	0	2.424640090656279	57	
i 1	81.50190476190477	4.7975	71	384	4	4	10	2	0	-2	2	0	0	4.000000000000001	57	
i 1	81.50734693877551	0.2525	68	882	2	20	14	0	0	0	0	0	0	0.13384601588667877	57	
i 1	81.74156462585034	0.2525	72	68	5	5	9	1	0	0	1	0	0	3.0	57	
i 1	81.98775510204082	0.505	72	384	6	1	15	2	0	-2	2	0	0	2.424640090656279	57	
i 1	81.98829931972789	0.2525	74	68	5	4	15	2	0	-1	2	0	0	4.000000000000001	57	
i 1	82.01170068027211	0.505	71	68	4	20	16	1	0	0	1	0	0	0.13384601588667877	57	
i 1	82.24265306122449	0.2525	68	68	4	20	4	0	0	-1	0	0	0	0.13384601588667877	57	
i 1	82.25081632653061	1.2625	71	882	4	9	7	8	0	-1	8	0	0	3.000000000000001	57	
i 1	82.25952380952381	0.2525	75	882	6	1	7	2	0	-2	2	0	0	2.424640090656279	57	
i 1	82.49210884353741	0.2525	75	68	5	1	7	8	0	1	8	0	0	2.424640090656279	57	
i 1	82.50081632653061	0.2525	71	68	7	2	11	2	0	-1	2	0	0	4.000000000000001	57	
i 1	82.50462585034013	0.2525	75	882	6	1	13	2	0	-2	2	0	0	2.424640090656279	57	
i 1	82.50625850340136	3.7875	66	882	4	18	7	6	0	1	6	0	0	3.7185586686313403	57	
i 1	82.50734693877551	0.2525	69	384	5	5	14	0	0	0	0	0	0	3.0	57	
i 1	82.51115646258503	0.7575000000000001	66	68	5	19	11	6	0	1	6	0	0	3.7185586686313403	57	
i 1	82.51170068027211	3.7875	61	384	5	25	15	6	0	2	6	0	0	1.7868394313862161	57	
i 1	82.73884353741497	0.505	68	68	2	24	6	0	0	-1	0	0	0	4.133846015886679	57	
i 1	82.74591836734695	0.505	68	68	2	24	14	0	0	0	0	0	0	4.133846015886679	57	
i 1	82.76061224489796	0.2525	74	68	4	4	10	2	0	-1	2	0	0	4.000000000000001	57	
i 1	83.01061224489796	1.01	72	68	6	5	8	1	0	0	1	0	0	3.0	57	
i 1	83.23829931972789	0.7575000000000001	71	180	2	24	13	0	0	-1	0	0	0	4.133846015886679	58	
i 1	83.24265306122449	0.505	71	180	2	24	2	0	0	0	0	0	0	4.133846015886679	58	
i 1	83.24374149659864	0.7575000000000001	66	180	5	19	14	6	0	2	6	0	0	3.7185586686313403	58	
i 1	83.24428571428571	0.7575000000000001	61	180	1	27	16	9	0	252	9	307	0	2.23354928923277	58	
i 1	83.25136054421769	0.7575000000000001	61	180	5	19	1	6	0	1	6	0	0	3.7185586686313403	58	
i 1	83.25299319727891	0.7575000000000001	71	68	7	2	16	2	0	-1	2	0	0	4.000000000000001	58	
i 1	83.25517006802721	0.505	69	882	5	5	7	1	0	0	1	0	0	3.0	58	
i 1	83.49047619047619	0.2525	69	384	5	5	14	0	0	0	0	0	0	3.0	59	
i 1	83.73829931972789	0.2525	72	384	4	1	14	2	0	-2	2	0	0	2.424640090656279	59	
i 1	83.74210884353741	0.2525	71	68	4	20	1	0	0	-1	0	0	0	0.13384601588667877	59	
i 1	83.76170068027211	0.2525	75	68	5	1	3	8	0	1	8	0	0	2.424640090656279	59	
i 1	83.76170068027211	0.2525	68	68	4	20	11	0	0	-1	0	0	0	0.13384601588667877	59	
i 1	83.76278911564626	0.2525	71	882	4	9	13	2	0	-2	2	0	0	3.000000000000001	59	
i 1	83.98666666666666	2.2725	66	882	4	26	9	6	0	1	6	0	0	1.7868394313862161	60	
i 1	83.98775510204082	2.2725	61	384	4	19	16	6	0	2	6	0	0	3.7185586686313403	60	
i 1	83.98993197278912	0.2525	75	1086	4	1	12	2	0	1	2	0	0	2.424640090656279	60	
i 1	83.99102040816327	0.2525	69	384	5	5	3	0	0	0	0	0	0	3.0	60	
i 1	83.99482993197279	0.2525	71	882	2	20	4	1	0	-1	1	0	0	0.13384601588667877	60	
i 1	83.99700680272109	1.5150000000000001	66	1086	5	17	2	9	0	2	9	0	0	3.7185586686313403	60	
i 1	83.99863945578231	0.2525	71	882	2	20	15	1	0	0	1	0	0	0.13384601588667877	60	
i 1	83.99918367346939	1.01	74	1086	6	2	1	2	0	-1	2	0	0	4.000000000000001	60	
i 1	83.99972789115647	1.5150000000000001	61	384	4	19	15	6	0	1	6	0	0	3.7185586686313403	60	
i 1	84.00571428571429	2.2725	61	384	1	27	9	6	0	252	6	307	0	2.23354928923277	60	
i 1	84.00897959183673	1.5150000000000001	66	1086	5	14	16	9	0	1	9	0	0	4.439473808728613	60	
i 1	84.01006802721088	1.5150000000000001	66	1086	3	14	5	9	0	2	9	0	0	4.439473808728613	60	
i 1	84.01115646258503	1.5150000000000001	71	384	2	24	6	1	0	0	1	0	0	4.133846015886679	60	
i 1	84.01224489795918	1.7675	71	384	4	3	8	2	0	-1	2	0	0	4.000000000000001	60	
i 1	84.01333333333334	2.2725	61	384	1	27	2	6	0	252	6	307	0	2.23354928923277	60	
i 1	84.24482993197279	2.02	72	384	4	1	6	2	0	-2	2	0	0	2.424640090656279	61	
i 1	84.25843537414966	0.505	71	1086	3	20	12	1	0	-1	1	0	0	0.13384601588667877	61	
i 1	84.26278911564626	0.2525	69	384	5	5	2	0	0	0	0	0	0	3.0	61	
i 1	84.50027210884353	1.2625	69	882	4	5	10	1	0	0	1	0	0	3.0	61	
i 1	84.50680272108843	0.505	75	1086	4	1	4	2	0	1	2	0	0	2.424640090656279	61	
i 1	84.76170068027211	0.505	72	384	5	5	12	0	0	0	0	0	0	3.0	61	
i 1	84.99210884353741	0.2525	71	882	4	9	15	8	0	-1	8	0	0	3.000000000000001	61	
i 1	84.99265306122449	0.2525	68	384	3	24	15	1	0	-1	1	0	0	4.133846015886679	61	
i 1	85.23884353741497	0.2525	75	882	6	1	5	2	0	-2	2	0	0	2.424640090656279	61	
i 1	85.24265306122449	0.7575000000000001	72	1086	6	5	9	0	0	0	0	0	0	3.0	61	
i 1	85.24755102040817	1.01	74	1086	6	2	9	8	0	-2	8	0	0	4.000000000000001	61	
i 1	85.48666666666666	0.7575000000000001	66	1086	5	14	14	9	0	2	9	0	0	4.439473808728613	61	
i 1	85.48775510204082	0.2525	71	1086	3	20	12	1	0	0	1	0	0	0.13384601588667877	61	
i 1	85.49102040816327	0.7575000000000001	71	384	1	24	9	1	0	248	1	308	0	4.133846015886679	61	
i 1	85.49374149659864	0.7575000000000001	66	882	4	26	11	9	0	2	9	0	0	1.7868394313862161	61	
i 1	85.50353741496599	0.7575000000000001	61	384	4	19	11	6	0	1	6	0	0	3.7185586686313403	61	
i 1	85.50462585034013	0.7575000000000001	66	1086	3	14	11	9	0	1	9	0	0	4.439473808728613	61	
i 1	85.50571428571429	0.7575000000000001	69	1086	6	5	7	1	0	-1	1	0	0	3.0	61	
i 1	85.73993197278912	0.2525	75	1086	6	1	6	2	0	1	2	0	0	2.424640090656279	61	
i 1	85.75625850340136	0.505	74	384	4	4	1	2	0	-2	2	0	0	4.000000000000001	61	
i 1	85.75897959183673	0.505	68	882	2	20	1	0	0	-1	0	0	0	0.13384601588667877	61	
i 1	86.23775510204082	3.7875	61	882	4	18	4	9	0	1	9	0	0	3.7185586686313403	62	
i 1	86.24047619047619	3.7875	61	384	4	19	2	9	0	1	9	0	0	3.7185586686313403	62	
i 1	86.24265306122449	1.2625	68	384	1	24	14	1	0	252	1	307	0	4.133846015886679	62	
i 1	86.24319727891157	0.7575000000000001	69	384	5	5	10	0	0	-1	0	0	0	3.0	62	
i 1	86.24591836734695	0.2525	74	384	5	3	10	2	0	-1	2	0	0	4.000000000000001	62	
i 1	86.24591836734695	3.7875	66	882	4	26	6	9	0	1	9	0	0	1.7868394313862161	62	
i 1	86.24809523809523	1.2625	68	882	2	20	13	0	0	-1	0	0	0	0.13384601588667877	62	
i 1	86.24918367346939	0.7575000000000001	66	384	5	17	5	9	0	1	9	0	0	3.7185586686313403	62	
i 1	86.24918367346939	3.7875	61	882	4	18	13	9	0	1	9	0	0	3.7185586686313403	62	
i 1	86.24972789115647	3.7875	72	882	6	1	6	8	0	-2	8	0	0	2.424640090656279	62	
i 1	86.25027210884353	3.7875	61	882	3	14	16	6	0	2	6	0	0	4.439473808728613	62	
i 1	86.25136054421769	0.7575000000000001	61	882	5	14	8	9	0	1	9	0	0	4.439473808728613	62	
i 1	86.25299319727891	2.2725	66	384	4	7	14	6	0	1	6	0	0	3.028188217646986	62	
i 1	86.25353741496599	2.2725	61	384	5	17	6	6	0	1	6	0	0	3.7185586686313403	62	
i 1	86.25353741496599	3.7875	66	384	4	19	4	6	0	2	6	0	0	3.7185586686313403	62	
i 1	86.25353741496599	2.2725	66	384	1	27	2	6	0	252	6	307	0	2.23354928923277	62	
i 1	86.25571428571429	1.01	68	882	2	24	15	1	0	-1	1	0	0	4.133846015886679	62	
i 1	86.25789115646259	1.01	71	384	2	24	15	0	0	0	0	0	0	4.133846015886679	62	
i 1	86.25789115646259	0.7575000000000001	61	384	3	13	13	9	0	2	9	0	0	0.20561703548373014	62	
i 1	86.26061224489796	2.2725	66	882	4	26	4	9	0	2	9	0	0	1.7868394313862161	62	
i 1	86.26170068027211	0.7575000000000001	66	384	5	25	3	6	0	1	6	0	0	1.7868394313862161	62	
i 1	86.74156462585034	0.2525	75	882	6	1	4	2	0	1	2	0	0	2.424640090656279	62	
i 1	86.74646258503401	0.7575000000000001	68	882	2	20	9	1	0	0	1	0	0	0.13384601588667877	62	
i 1	86.75408163265305	1.7675	71	384	2	24	10	0	0	0	0	0	0	4.133846015886679	62	
i 1	86.76006802721088	0.2525	74	882	4	9	5	2	0	-1	2	0	0	3.000000000000001	62	
i 1	86.76224489795918	0.7575000000000001	74	384	5	3	4	2	0	-1	2	0	0	4.000000000000001	62	
i 1	86.99210884353741	3.0300000000000002	61	882	3	14	2	9	0	1	9	0	0	4.439473808728613	62	
i 1	87.00299319727891	0.2525	71	882	6	2	4	8	0	-1	8	0	0	4.000000000000001	62	
i 1	87.00299319727891	1.5150000000000001	61	384	5	13	6	9	0	2	9	0	0	0.20561703548373014	62	
i 1	87.00408163265305	0.2525	75	384	6	1	8	2	0	1	2	0	0	2.424640090656279	62	
i 1	87.00680272108843	3.0300000000000002	61	384	3	27	14	9	0	1	9	0	0	2.23354928923277	62	
i 1	87.01333333333334	3.0300000000000002	74	384	4	4	2	8	0	-2	8	0	0	4.000000000000001	62	
i 1	87.26061224489796	1.5150000000000001	72	882	6	5	10	1	0	0	1	0	0	3.0	62	
i 1	87.50571428571429	0.2525	72	882	4	5	13	0	0	0	0	0	0	3.0	62	
i 1	87.50625850340136	0.2525	68	882	3	20	7	1	0	0	1	0	0	0.13384601588667877	62	
i 1	87.50952380952381	1.01	68	384	2	24	15	1	0	0	1	0	0	4.133846015886679	62	
i 1	87.74918367346939	0.2525	68	882	2	20	12	1	0	0	1	0	0	0.13384601588667877	62	
i 1	87.75897959183673	0.2525	68	384	2	20	11	0	0	0	0	0	0	0.13384601588667877	62	
i 1	88.00136054421769	0.505	72	882	4	5	6	1	0	0	1	0	0	3.0	62	
i 1	88.48775510204082	0.7575000000000001	71	384	2	24	12	0	0	0	0	0	0	4.0	62	
i 1	88.48775510204082	1.7675	68	384	2	24	2	1	0	0	1	0	0	4.0	62	
i 1	88.48829931972789	1.5150000000000001	61	384	3	13	1	9	0	2	9	0	0	0.20561703548373014	62	
i 1	88.50952380952381	1.5150000000000001	66	384	3	27	8	6	0	2	6	0	0	2.23354928923277	62	
i 1	88.51006802721088	1.5150000000000001	66	384	6	7	6	6	0	1	6	0	0	3.028188217646986	62	
i 1	88.51170068027211	0.2525	69	384	6	5	7	0	0	0	0	0	0	3.0	62	
i 1	88.74428571428571	1.2625	69	384	6	5	13	0	0	-1	0	0	0	3.0	62	
i 1	88.74537414965987	0.2525	69	384	4	5	1	0	0	-1	0	0	0	3.0	62	
i 1	88.99102040816327	1.01	71	882	4	2	5	8	0	-2	8	0	0	4.000000000000001	62	
i 1	88.99265306122449	0.2525	72	384	4	24	11	2	0	-2	2	0	0	5.424640090656279	62	
i 1	89.24809523809523	0.2525	75	384	6	1	12	2	0	-2	2	0	0	2.424640090656279	62	
i 1	89.25244897959183	0.2525	72	882	3	1	1	2	0	1	2	0	0	2.424640090656279	62	
i 1	89.26115646258503	0.505	72	882	6	5	1	1	0	0	1	0	0	3.0	62	
i 1	89.98829931972789	0.505	66	384	4	7	3	6	0	1	6	0	0	1.6883558086081272	62	
i 1	89.98884353741497	0.505	71	384	4	3	1	2	0	-1	2	0	0	13.0	62	
i 1	89.99428571428571	0.505	71	882	4	2	12	8	0	-1	8	0	0	13.0	62	
i 1	89.99428571428571	0.505	66	384	4	19	5	6	0	2	6	0	0	3.9915030803368663	62	
i 1	89.99700680272109	0.505	68	882	2	24	3	1	0	-1	1	0	0	4.0	62	
i 1	89.99755102040817	0.505	61	882	4	18	5	9	0	1	9	0	0	3.9915030803368663	62	
i 1	90.00190476190477	0.505	61	384	4	19	1	9	0	1	9	0	0	3.9915030803368663	62	
i 1	90.00408163265305	0.505	61	882	3	14	5	9	0	1	9	0	0	3.099641399689755	62	
i 1	90.01224489795918	0.505	61	882	3	14	5	6	0	2	6	0	0	3.099641399689755	62	
i 1	90.49156462585034	9.09	63	915	1	27	16	16	0	252	16	307	0	2.6802591470793242	0	
i 1	90.49428571428571	0.2525	72	915	3	4	4	2	0	1	2	0	0	5.0	0	
i 1	90.49700680272109	3.0300000000000002	63	101	6	25	3	1	0	1	1	0	0	2.23354928923277	0	
i 1	90.49755102040817	0.2525	72	915	5	5	8	8	0	-2	8	0	0	3.0	0	
i 1	90.50190476190477	1.01	72	101	7	5	14	2	0	-2	2	0	0	3.0	0	
i 1	90.50789115646259	1.5150000000000001	74	417	1	24	5	2	0	-2	2	0	0	4.0	0	
i 1	90.73721088435374	0.2525	75	915	3	5	15	2	0	1	2	0	0	3.0	1	
i 1	90.99809523809523	0.2525	71	915	4	24	13	8	0	-1	8	0	0	3.0	1	
i 1	91.01333333333334	0.2525	72	417	5	5	12	2	0	1	2	0	0	3.0	1	
i 1	91.25027210884353	0.505	75	915	3	5	3	2	0	1	2	0	0	3.0	1	
i 1	91.26061224489796	0.505	72	417	4	9	11	2	0	1	2	0	0	4.0	1	
i 1	91.50897959183673	0.505	72	101	5	5	12	2	0	-2	2	0	0	3.0	1	
i 1	91.74972789115647	0.505	75	101	7	2	8	2	0	-2	2	0	0	5.0	1	
i 1	91.75190476190477	0.2525	71	915	4	24	5	8	0	-1	8	0	0	3.0	1	
i 1	91.98993197278912	0.7575000000000001	72	101	7	5	10	2	0	-2	2	0	0	3.0	1	
i 1	91.99428571428571	0.2525	74	417	1	24	14	2	0	-2	2	0	0	4.093637130455701	1	
i 1	91.99537414965987	0.2525	72	101	7	5	12	2	0	-2	2	0	0	3.0	1	
i 1	91.99755102040817	0.505	71	417	4	20	14	2	0	1	2	0	0	0.0936371304557011	1	
i 1	91.99972789115647	3.0300000000000002	61	101	6	25	4	1	0	2	1	0	0	2.23354928923277	1	
i 1	92.00625850340136	0.7575000000000001	74	915	1	20	13	2	0	1	2	0	0	0.0936371304557011	1	
i 1	92.00952380952381	1.01	72	101	7	2	7	2	0	-2	2	0	0	5.0	1	
i 1	92.25244897959183	0.505	72	915	4	5	8	8	0	-2	8	0	0	3.0	1	
i 1	92.48938775510204	1.2625	75	915	4	4	6	2	0	-2	2	0	0	5.0	1	
i 1	92.74428571428571	0.2525	74	915	1	24	16	2	0	-2	2	0	0	4.093637130455701	2	
i 1	92.74972789115647	0.2525	74	417	1	24	9	2	0	-2	2	0	0	4.093637130455701	2	
i 1	92.99210884353741	0.505	75	915	4	5	12	2	0	1	2	0	0	3.0	2	
i 1	93.00408163265305	0.7575000000000001	71	915	4	24	14	8	0	-1	8	0	0	3.0	2	
i 1	93.00789115646259	0.2525	74	417	4	20	13	8	0	1	8	0	0	0.0936371304557011	2	
i 1	93.00843537414966	0.2525	72	915	3	4	7	2	0	1	2	0	0	5.0	2	
i 1	93.23775510204082	0.2525	72	915	4	5	15	8	0	-2	8	0	0	3.0	2	
i 1	93.24918367346939	0.2525	72	101	7	5	4	2	0	-2	2	0	0	3.0	2	
i 1	93.49646258503401	2.525	72	915	6	5	14	8	0	-2	8	0	0	3.0	2	
i 1	93.49700680272109	3.0300000000000002	61	915	5	25	6	1	0	1	1	0	0	2.23354928923277	2	
i 1	93.50408163265305	0.2525	72	417	5	5	16	2	0	1	2	0	0	3.0	2	
i 1	93.50734693877551	4.2925	63	101	6	25	4	1	0	1	1	0	0	2.23354928923277	2	
i 1	93.73938775510204	0.2525	74	915	1	24	13	2	0	-2	2	0	0	4.093637130455701	2	
i 1	93.76278911564626	1.01	72	915	5	3	15	2	0	1	2	0	0	5.0	2	
i 1	94.00353741496599	1.01	75	101	7	2	5	2	0	-2	2	0	0	5.0	2	
i 1	94.25952380952381	0.505	75	417	4	9	10	2	0	-2	2	0	0	4.0	2	
i 1	94.48993197278912	2.02	72	101	7	5	2	2	0	-2	2	0	0	3.0	2	
i 1	94.50027210884353	0.2525	74	915	4	20	13	2	0	1	2	0	0	0.0936371304557011	2	
i 1	94.50625850340136	0.2525	74	417	3	24	14	2	0	-2	2	0	0	4.093637130455701	2	
i 1	94.75244897959183	0.2525	75	915	4	5	10	2	0	1	2	0	0	3.0	2	
i 1	94.76061224489796	0.2525	72	101	7	2	6	2	0	-2	2	0	0	5.0	2	
i 1	94.76333333333334	0.2525	74	915	2	20	5	2	0	1	2	0	0	0.0936371304557011	2	
i 1	94.98884353741497	0.505	75	915	2	3	6	8	0	1	8	0	0	5.0	2	
i 1	94.99537414965987	0.2525	74	417	3	24	2	2	0	-2	2	0	0	4.093637130455701	2	
i 1	95.00027210884353	2.7775	61	101	6	25	10	1	0	2	1	0	0	2.23354928923277	2	
i 1	95.00136054421769	3.0300000000000002	61	915	5	25	9	1	0	2	1	0	0	2.23354928923277	2	
i 1	95.23721088435374	0.505	74	915	2	20	8	2	0	1	2	0	0	0.0936371304557011	2	
i 1	95.26278911564626	0.7575000000000001	72	101	7	2	8	2	0	-2	2	0	0	5.0	2	
i 1	95.50136054421769	0.2525	75	417	4	9	11	2	0	-2	2	0	0	4.0	2	
i 1	95.50571428571429	0.2525	71	915	2	24	12	8	0	-1	8	0	0	3.0	2	
i 1	95.74700680272109	0.2525	74	915	4	20	2	2	0	1	2	0	0	0.0936371304557011	2	
i 1	96.25081632653061	0.2525	72	915	2	4	6	2	0	1	2	0	0	5.0	2	
i 1	96.49210884353741	3.0300000000000002	61	417	4	26	1	16	0	1	16	0	0	2.23354928923277	2	
i 1	96.50190476190477	0.2525	75	101	5	2	1	2	0	-2	2	0	0	5.0	2	
i 1	96.50244897959183	7.3225	61	915	5	25	1	1	0	1	1	0	0	2.23354928923277	2	
i 1	96.74809523809523	0.2525	74	915	2	20	4	2	0	1	2	0	0	0.0936371304557011	3	
i 1	96.74863945578231	0.2525	74	915	2	24	10	2	0	-2	2	0	0	4.093637130455701	3	
i 1	96.99102040816327	1.01	71	417	4	20	7	2	0	-2	2	0	0	0.0936371304557011	4	
i 1	96.99265306122449	0.2525	75	417	4	9	1	2	0	-2	2	0	0	4.0	4	
i 1	97.00734693877551	0.2525	72	915	3	4	2	2	0	1	2	0	0	5.0	4	
i 1	97.00789115646259	0.2525	74	915	3	20	5	2	0	1	2	0	0	0.0936371304557011	4	
i 1	97.00843537414966	0.2525	72	417	4	5	12	2	0	1	2	0	0	3.0	4	
i 1	97.01061224489796	1.01	71	417	3	20	9	2	0	-2	2	0	0	0.0936371304557011	4	
i 1	97.01115646258503	0.2525	72	915	6	5	10	8	0	-2	8	0	0	3.0	4	
i 1	97.49482993197279	0.2525	71	915	4	24	9	8	0	-1	8	0	0	3.0	5	
i 1	97.73721088435374	3.2825	61	213	6	25	8	1	0	2	1	0	0	2.23354928923277	6	
i 1	97.75081632653061	4.7975	63	213	6	25	14	16	0	2	16	0	0	2.23354928923277	6	
i 1	97.98721088435374	5.8075	61	915	5	25	15	1	0	2	1	0	0	2.23354928923277	6	
i 1	97.98993197278912	0.505	74	915	1	24	5	2	0	248	2	308	0	4.007490970436456	6	
i 1	97.99863945578231	3.0300000000000002	63	417	4	26	12	1	0	1	1	0	0	2.23354928923277	6	
i 1	98.00789115646259	1.01	71	417	4	20	13	2	0	-2	2	0	0	0.007490970436456301	6	
i 1	98.01115646258503	0.2525	74	915	3	24	8	2	0	-2	2	0	0	4.007490970436456	6	
i 1	98.49537414965987	1.5150000000000001	74	915	3	20	16	2	0	1	2	0	0	0.007490970436456301	6	
i 1	98.51061224489796	1.01	74	915	2	24	3	2	0	-2	2	0	0	4.007490970436456	6	
i 1	98.73721088435374	0.7575000000000001	75	213	7	5	14	8	0	1	8	0	0	3.0	6	
i 1	98.75897959183673	0.505	72	213	7	2	9	2	0	1	2	0	0	5.0	6	
i 1	98.76006802721088	0.2525	72	417	6	5	16	2	0	1	2	0	0	3.0	6	
i 1	98.99863945578231	0.2525	74	915	3	24	9	2	0	-2	2	0	0	4.007490970436456	6	
i 1	99.01170068027211	0.505	72	417	6	5	3	2	0	1	2	0	0	3.0	6	
i 1	99.49210884353741	3.0300000000000002	63	915	3	27	8	16	0	1	16	0	0	2.6802591470793242	6	
i 1	99.49863945578231	7.575	61	417	4	26	8	16	0	1	16	0	0	2.23354928923277	6	
i 1	99.75517006802721	1.5150000000000001	72	213	7	2	10	2	0	1	2	0	0	5.0	7	
i 1	99.99265306122449	1.01	71	417	4	20	12	2	0	-2	2	0	0	0.007490970436456301	7	
i 1	100.24156462585034	0.2525	72	417	5	9	8	2	0	1	2	0	0	4.0	7	
i 1	100.24210884353741	0.7575000000000001	72	915	3	5	14	8	0	-2	8	0	0	3.0	7	
i 1	100.25081632653061	0.2525	71	213	4	20	16	2	0	-2	2	0	0	0.007490970436456301	7	
i 1	100.49210884353741	0.2525	71	417	4	20	15	2	0	1	2	0	0	0.007490970436456301	7	
i 1	100.49863945578231	0.2525	72	417	6	5	14	2	0	1	2	0	0	3.0	7	
i 1	100.49972789115647	0.505	75	417	5	9	6	2	0	-2	2	0	0	4.0	7	
i 1	100.50136054421769	0.7575000000000001	74	915	3	24	4	2	0	-2	2	0	0	4.007490970436456	7	
i 1	100.76006802721088	0.2525	72	915	4	4	7	2	0	1	2	0	0	5.0	7	
i 1	100.98938775510204	2.7775	63	915	3	27	9	16	0	1	16	0	0	2.6802591470793242	7	
i 1	100.99265306122449	0.7575000000000001	74	915	3	24	9	2	0	-2	2	0	0	4.007490970436456	7	
i 1	100.99809523809523	0.2525	71	915	4	24	6	8	0	-1	8	0	0	3.0	7	
i 1	100.99972789115647	0.2525	74	915	3	24	7	8	0	-2	8	0	0	4.007490970436456	7	
i 1	101.00353741496599	7.575	63	417	4	26	14	1	0	1	1	0	0	2.23354928923277	7	
i 1	101.01006802721088	0.2525	71	417	4	20	10	8	0	-2	8	0	0	0.007490970436456301	7	
i 1	101.23884353741497	0.505	75	213	7	5	15	8	0	1	8	0	0	3.0	7	
i 1	101.74755102040817	0.2525	72	213	7	2	2	2	0	-2	2	0	0	5.0	7	
i 1	101.99047619047619	0.2525	72	915	5	3	1	2	0	1	2	0	0	5.0	7	
i 1	102.00299319727891	0.505	75	213	7	5	8	8	0	-2	8	0	0	3.0	7	
i 1	102.01115646258503	0.7575000000000001	74	915	3	24	6	2	0	-2	2	0	0	4.007490970436456	7	
i 1	102.48993197278912	0.2525	75	417	4	9	16	2	0	-2	2	0	0	4.0	7	
i 1	102.49700680272109	1.01	75	915	4	4	11	2	0	-2	2	0	0	5.0	7	
i 1	102.49863945578231	1.2625	63	915	3	27	4	16	0	1	16	0	0	2.6802591470793242	7	
i 1	102.50353741496599	0.505	75	213	6	5	15	8	0	-2	8	0	0	3.0	7	
i 1	102.74591836734695	1.01	75	213	7	5	10	8	0	1	8	0	0	3.0	7	
i 1	102.76115646258503	1.01	72	915	5	3	10	2	0	1	2	0	0	5.0	7	
i 1	103.00299319727891	0.7575000000000001	74	915	3	24	11	2	0	-2	2	0	0	4.007490970436456	7	
i 1	103.00734693877551	0.2525	75	915	5	5	12	2	0	1	2	0	0	3.0	7	
i 1	103.24319727891157	0.2525	72	417	6	5	7	2	0	1	2	0	0	3.0	7	
i 1	103.25843537414966	0.2525	72	417	4	9	3	2	0	1	2	0	0	4.0	7	
i 1	103.74102040816327	0.2525	63	1119	5	25	8	1	0	2	1	0	0	2.23354928923277	8	
i 1	103.74156462585034	1.7675	63	1119	5	25	10	1	0	1	1	0	0	2.23354928923277	8	
i 1	103.74537414965987	1.5150000000000001	75	1119	6	5	14	2	0	1	2	0	0	3.0	8	
i 1	103.74863945578231	3.0300000000000002	61	803	3	27	10	1	0	1	1	0	0	2.6802591470793242	8	
i 1	103.74918367346939	0.2525	71	803	3	24	11	2	0	-2	2	0	0	4.007490970436456	8	
i 1	103.74972789115647	0.2525	63	803	3	27	15	1	0	2	1	0	0	2.6802591470793242	8	
i 1	103.75299319727891	0.2525	71	803	4	24	9	8	0	-1	8	0	0	3.0	8	
i 1	103.75952380952381	0.7575000000000001	75	417	6	2	5	2	0	-2	2	0	0	5.0	8	
i 1	103.99102040816327	0.2525	74	803	3	24	6	8	0	1	8	0	0	4.007490970436456	9	
i 1	103.99918367346939	2.7775	63	803	3	27	11	1	0	2	1	0	0	2.6802591470793242	9	
i 1	104.24374149659864	0.2525	75	803	5	5	1	2	0	1	2	0	0	3.0	9	
i 1	104.24537414965987	0.2525	72	417	6	5	8	2	0	1	2	0	0	3.0	9	
i 1	104.75244897959183	1.01	72	417	6	5	10	2	0	1	2	0	0	3.0	11	
i 1	104.75734693877551	0.2525	75	417	6	2	1	2	0	-2	2	0	0	5.0	11	
i 1	104.98884353741497	1.2625	72	1119	5	3	1	8	0	1	8	0	0	5.0	11	
i 1	104.99755102040817	0.2525	71	803	3	24	16	2	0	-2	2	0	0	4.007490970436456	11	
i 1	105.24591836734695	0.505	74	1119	4	24	13	2	0	-1	2	0	0	3.0	11	
i 1	105.26006802721088	1.5150000000000001	74	417	4	24	1	2	0	-2	2	0	0	4.007490970436456	11	
i 1	105.73938775510204	0.2525	75	417	5	9	9	2	0	-2	2	0	0	4.0	11	
i 1	105.75136054421769	0.2525	72	417	6	5	2	2	0	1	2	0	0	3.0	11	
i 1	105.98775510204082	0.2525	72	417	6	5	1	2	0	1	2	0	0	3.0	11	
i 1	106.00517006802721	0.7575000000000001	72	417	6	2	16	2	0	-2	2	0	0	5.0	11	
i 1	106.25897959183673	0.2525	72	803	3	3	9	8	0	1	8	0	0	5.0	11	
i 1	106.26278911564626	0.7575000000000001	71	417	4	20	2	2	0	1	2	0	0	0.007490970436456301	11	
i 1	106.26333333333334	0.7575000000000001	71	417	4	20	7	2	0	-2	2	0	0	0.007490970436456301	11	
i 1	106.48884353741497	0.2525	72	1119	5	3	13	8	0	1	8	0	0	5.0	11	
i 1	106.75136054421769	1.2625	72	417	6	5	16	2	0	1	2	0	0	3.0	12	
i 1	106.75190476190477	3.2825	63	915	3	27	16	1	0	2	1	0	0	2.6802591470793242	12	
i 1	106.75244897959183	4.7975	63	915	3	27	8	16	0	2	16	0	0	2.6802591470793242	12	
i 1	107.00680272108843	0.505	71	915	4	24	13	8	0	-2	8	0	0	3.0	12	
i 1	107.00952380952381	2.02	74	417	4	24	8	2	0	-2	2	0	0	4.0	12	
i 1	107.49428571428571	0.2525	71	915	4	24	8	8	0	-1	8	0	0	3.0	12	
i 1	107.73993197278912	2.02	72	101	7	2	11	2	0	-2	2	0	0	5.0	12	
i 1	107.74319727891157	0.2525	72	101	7	2	4	2	0	-2	2	0	0	5.0	12	
i 1	108.50734693877551	0.2525	72	417	5	5	9	2	0	1	2	0	0	3.0	12	
i 1	108.75027210884353	0.2525	74	915	4	24	13	2	0	-2	2	0	0	4.0	12	
i 1	109.25027210884353	0.2525	75	915	4	4	4	2	0	1	2	0	0	5.0	12	
i 1	109.25680272108843	1.7675	71	915	3	24	8	2	0	-2	2	0	0	4.0	12	
i 1	109.49646258503401	0.505	72	417	5	9	3	2	0	1	2	0	0	4.0	12	
i 1	109.73993197278912	1.01	75	915	5	3	14	2	0	1	2	0	0	5.0	12	
i 1	109.76224489795918	0.505	72	417	5	5	14	2	0	1	2	0	0	3.0	12	
i 1	110.00244897959183	0.2525	72	915	5	3	3	2	0	-2	2	0	0	5.0	12	
i 1	110.00299319727891	2.02	71	915	4	24	5	8	0	-1	8	0	0	3.0	12	
i 1	110.01170068027211	1.7675	63	915	1	27	2	1	0	252	1	307	0	2.6802591470793242	12	
i 1	110.25353741496599	1.5150000000000001	72	101	7	2	9	2	0	-2	2	0	0	5.0	12	
i 1	110.25353741496599	0.2525	72	101	6	5	16	2	0	1	2	0	0	3.0	12	
i 1	110.49482993197279	0.2525	72	417	5	5	6	2	0	1	2	0	0	3.0	12	
i 1	110.50136054421769	1.2625	74	915	3	24	4	2	0	1	2	0	0	4.0	12	
i 1	110.50190476190477	0.505	72	915	5	3	8	2	0	-2	2	0	0	5.0	12	
i 1	110.73938775510204	3.2825	72	915	5	5	11	2	0	1	2	0	0	3.0	13	
i 1	110.75136054421769	0.2525	71	915	4	24	3	8	0	-2	8	0	0	3.0	13	
i 1	110.76061224489796	0.2525	75	915	4	4	10	2	0	1	2	0	0	5.0	13	
i 1	110.98721088435374	0.2525	75	915	4	4	12	2	0	1	2	0	0	5.0	14	
i 1	110.99591836734695	0.505	72	417	5	5	11	2	0	1	2	0	0	3.0	14	
i 1	111.00571428571429	0.2525	75	417	5	9	3	2	0	-2	2	0	0	4.0	14	
i 1	111.50081632653061	0.2525	63	915	1	27	2	16	0	248	16	308	0	2.6802591470793242	15	
i 1	111.50408163265305	0.505	74	915	4	24	13	2	0	-2	2	0	0	4.0	15	
i 1	111.73938775510204	0.2525	72	417	5	5	12	2	0	1	2	0	0	3.0	16	
i 1	111.74210884353741	0.2525	75	915	5	5	1	2	0	-2	2	0	0	3.0	16	
i 1	111.75680272108843	1.7675	74	599	3	24	5	8	0	1	8	0	0	4.0	16	
i 1	111.75897959183673	1.2625	63	599	1	27	12	1	0	252	1	307	0	2.6802591470793242	16	
i 1	111.76224489795918	1.2625	63	599	1	27	5	16	0	252	16	307	0	2.6802591470793242	16	
i 1	111.76278911564626	0.2525	71	599	4	24	9	8	0	-1	8	0	0	3.0	16	
i 1	112.00897959183673	0.505	72	599	4	5	8	2	0	-2	2	0	0	3.0	16	
i 1	112.24265306122449	0.505	75	915	6	2	1	2	0	-2	2	0	0	5.0	16	
i 1	112.24755102040817	0.2525	71	915	4	24	12	8	0	-1	8	0	0	3.0	16	
i 1	112.48666666666666	0.2525	75	915	5	5	7	2	0	-2	2	0	0	3.0	16	
i 1	112.51333333333334	0.2525	75	599	5	5	9	2	0	1	2	0	0	3.0	16	
i 1	112.74972789115647	0.2525	75	915	5	3	10	2	0	1	2	0	0	5.0	16	
i 1	112.75353741496599	0.2525	75	599	4	4	2	2	0	-2	2	0	0	5.0	16	
i 1	112.76061224489796	0.2525	72	417	5	5	8	2	0	1	2	0	0	3.0	16	
i 1	112.98829931972789	5.555	63	915	6	7	4	16	0	1	16	0	0	3.3962957923607635	16	
i 1	112.98938775510204	0.2525	75	599	5	3	7	2	0	-2	2	0	0	11.0	16	
i 1	112.98993197278912	5.555	63	915	5	13	4	1	0	2	1	0	0	0.5737246101975074	16	
i 1	112.99047619047619	0.7575000000000001	74	417	4	24	13	2	0	-2	2	0	0	4.0	16	
i 1	113.00353741496599	0.2525	75	915	4	4	1	2	0	1	2	0	0	11.0	16	
i 1	113.00625850340136	4.545	63	915	5	14	12	16	0	1	16	0	0	4.807581383442391	16	
i 1	113.00952380952381	5.555	63	915	5	14	8	1	0	1	1	0	0	4.807581383442391	16	
i 1	113.24428571428571	0.505	72	417	5	5	14	2	0	1	2	0	0	3.0	16	
i 1	113.25462585034013	2.02	72	915	6	2	1	8	0	-2	8	0	0	11.0	16	
i 1	113.49537414965987	0.2525	75	599	5	3	7	2	0	-2	2	0	0	11.0	16	
i 1	113.50843537414966	1.01	75	915	5	5	7	2	0	-2	2	0	0	3.0	16	
i 1	113.76061224489796	0.2525	75	599	4	5	6	2	0	1	2	0	0	3.0	17	
i 1	113.98775510204082	0.2525	72	915	5	5	10	2	0	1	2	0	0	3.0	17	
i 1	113.99210884353741	0.2525	72	599	4	5	14	2	0	-2	2	0	0	3.0	17	
i 1	114.00190476190477	0.2525	71	599	2	24	10	2	0	1	2	0	0	4.0	17	
i 1	114.24319727891157	0.7575000000000001	71	915	3	24	11	8	0	-2	8	0	0	4.0	17	
i 1	114.25625850340136	0.2525	72	915	5	5	14	2	0	-2	2	0	0	3.0	17	
i 1	114.25734693877551	0.505	72	417	5	5	6	2	0	1	2	0	0	3.0	17	
i 1	114.50299319727891	0.505	75	915	6	5	9	2	0	-2	2	0	0	3.0	17	
i 1	114.50897959183673	1.5150000000000001	72	915	5	5	2	2	0	1	2	0	0	3.0	17	
i 1	114.74591836734695	0.2525	72	417	5	5	12	2	0	1	2	0	0	3.0	17	
i 1	114.74700680272109	0.2525	75	915	6	2	14	2	0	-2	2	0	0	11.0	17	
i 1	115.00625850340136	0.2525	72	915	5	5	4	2	0	-2	2	0	0	3.0	17	
i 1	115.00843537414966	2.2725	75	915	5	3	5	2	0	1	2	0	0	11.0	17	
i 1	115.01333333333334	0.7575000000000001	71	599	2	24	10	2	0	-2	2	0	0	4.0	17	
i 1	115.23938775510204	0.2525	75	417	5	9	3	2	0	-2	2	0	0	10.0	17	
i 1	115.25952380952381	2.525	74	417	3	24	15	2	0	-2	2	0	0	4.0	17	
i 1	115.48938775510204	0.2525	72	915	5	5	15	2	0	1	2	0	0	3.0	17	
i 1	115.49646258503401	0.2525	75	599	4	4	11	2	0	-2	2	0	0	11.0	17	
i 1	115.51170068027211	1.5150000000000001	72	915	5	5	1	2	0	-2	2	0	0	3.0	17	
i 1	115.99265306122449	0.2525	72	915	6	5	11	2	0	1	2	0	0	3.0	17	
i 1	116.01170068027211	2.525	63	915	6	17	8	16	0	1	16	0	0	0.6126620377439105	17	
i 1	116.23775510204082	1.2625	72	915	5	5	5	2	0	1	2	0	0	3.0	17	
i 1	116.23993197278912	0.2525	75	599	4	5	13	2	0	1	2	0	0	3.0	17	
i 1	116.49537414965987	0.2525	71	915	3	24	12	8	0	-2	8	0	0	4.0	17	
i 1	116.50952380952381	0.505	72	417	5	5	15	2	0	1	2	0	0	3.0	17	
i 1	116.74700680272109	1.7675	72	915	6	2	11	8	0	-2	8	0	0	11.0	17	
i 1	116.76278911564626	0.505	74	599	2	24	7	8	0	1	8	0	0	4.0	17	
i 1	117.00190476190477	0.2525	72	599	4	5	3	2	0	-2	2	0	0	3.0	17	
i 1	117.00299319727891	0.2525	72	417	5	5	9	2	0	1	2	0	0	3.0	17	
i 1	117.26061224489796	0.2525	72	417	5	5	14	2	0	1	2	0	0	3.0	17	
i 1	117.26278911564626	0.2525	74	915	3	24	16	2	0	1	2	0	0	4.0	17	
i 1	117.48884353741497	1.01	61	915	6	17	8	16	0	1	16	0	0	0.6126620377439105	17	
i 1	117.48884353741497	0.2525	72	599	4	5	4	2	0	-2	2	0	0	3.0	17	
i 1	117.49047619047619	0.505	71	599	4	24	9	8	0	-1	8	0	0	3.0	17	
i 1	117.49047619047619	1.01	63	915	4	14	12	16	0	1	16	0	0	4.807581383442391	17	
i 1	117.50136054421769	0.505	74	599	2	24	15	8	0	1	8	0	0	4.0	17	
i 1	117.50244897959183	1.01	72	915	6	5	7	2	0	1	2	0	0	3.0	17	
i 1	117.51170068027211	1.01	75	599	5	3	15	2	0	-2	2	0	0	11.0	17	
i 1	117.51278911564626	0.7575000000000001	74	599	1	24	12	2	0	252	2	307	0	4.0	17	
i 1	117.74102040816327	1.5150000000000001	71	213	3	24	14	2	0	1	2	0	0	4.0	18	
i 1	117.74374149659864	0.2525	75	915	4	4	10	2	0	1	2	0	0	11.0	18	
i 1	117.99537414965987	0.2525	71	915	4	24	15	8	0	-1	8	0	0	3.0	19	
i 1	118.48666666666666	6.565	63	711	1	27	16	1	0	248	1	308	0	1.7868394313862161	20	
i 1	118.48721088435374	0.7575000000000001	72	1097	6	5	3	2	0	-2	2	0	0	3.0	20	
i 1	118.48993197278912	1.7675	75	711	5	3	7	8	0	1	8	0	0	11.0	20	
i 1	118.49210884353741	2.02	61	711	5	13	9	1	0	2	1	0	0	0.5737246101975074	20	
i 1	118.49265306122449	2.2725	61	711	6	7	12	1	0	1	1	0	0	3.3962957923607635	20	
i 1	118.49537414965987	0.505	61	1097	6	17	14	1	0	1	1	0	0	0.6126620377439105	20	
i 1	118.50081632653061	2.02	61	1097	6	17	11	16	0	2	16	0	0	0.6126620377439105	20	
i 1	118.50244897959183	5.05	63	1097	4	14	14	16	0	2	16	0	0	4.807581383442391	20	
i 1	118.50517006802721	1.7675	72	711	6	5	11	2	0	-2	2	0	0	3.0	20	
i 1	118.51170068027211	1.7675	74	711	2	24	8	8	0	-2	8	0	0	4.0	20	
i 1	118.51224489795918	6.565	61	711	1	27	15	1	0	252	1	307	0	1.7868394313862161	20	
i 1	118.51333333333334	0.505	63	1097	5	14	5	1	0	1	1	0	0	4.807581383442391	20	
i 1	118.73721088435374	0.2525	75	1097	6	2	1	2	0	-2	2	0	0	11.0	21	
i 1	118.75897959183673	0.2525	75	1097	6	2	11	2	0	-2	2	0	0	11.0	21	
i 1	118.98938775510204	4.545	61	1097	6	17	7	1	0	1	1	0	0	0.6126620377439105	21	
i 1	119.00517006802721	0.2525	75	711	4	4	8	2	0	-2	2	0	0	11.0	21	
i 1	119.00734693877551	1.7675	63	711	6	17	6	1	0	2	1	0	0	0.6126620377439105	21	
i 1	119.01224489795918	6.0600000000000005	63	1097	4	14	8	1	0	1	1	0	0	4.807581383442391	21	
i 1	119.23993197278912	0.505	75	1097	6	5	10	8	0	-2	8	0	0	3.0	21	
i 1	119.25190476190477	0.2525	74	711	2	24	9	2	0	1	2	0	0	4.0	21	
i 1	119.49537414965987	0.2525	75	711	5	3	13	2	0	1	2	0	0	11.0	21	
i 1	119.50081632653061	0.2525	75	213	5	5	9	2	0	-2	2	0	0	3.0	21	
i 1	119.75517006802721	0.2525	72	213	6	9	6	2	0	-2	2	0	0	10.0	21	
i 1	119.98829931972789	1.2625	74	711	2	24	13	2	0	1	2	0	0	4.0	21	
i 1	120.01170068027211	0.505	72	711	4	5	16	2	0	-2	2	0	0	3.0	21	
i 1	120.24482993197279	0.505	75	711	4	4	13	2	0	-2	2	0	0	11.0	21	
i 1	120.49918367346939	4.545	61	1097	6	17	9	16	0	2	16	0	0	0.6126620377439105	21	
i 1	120.50081632653061	0.2525	61	711	4	13	15	1	0	2	1	0	0	0.5737246101975074	21	
i 1	120.50952380952381	0.2525	63	711	6	17	1	1	0	1	1	0	0	0.6126620377439105	21	
i 1	120.73666666666666	1.2625	61	599	6	17	3	16	0	1	16	0	0	0.6126620377439105	22	
i 1	120.73829931972789	0.2525	74	599	3	24	9	2	0	-2	2	0	0	4.0	22	
i 1	120.74319727891157	0.2525	75	711	4	4	15	2	0	-2	2	0	0	11.0	22	
i 1	120.75190476190477	1.2625	63	599	6	7	16	1	0	1	1	0	0	3.3962957923607635	22	
i 1	120.75789115646259	2.7775	61	599	6	17	7	16	0	2	16	0	0	0.6126620377439105	22	
i 1	120.75843537414966	1.2625	71	213	3	24	10	2	0	1	2	0	0	4.0	22	
i 1	120.75952380952381	4.2925	63	599	4	13	16	16	0	1	16	0	0	0.5737246101975074	22	
i 1	120.99646258503401	0.2525	75	711	4	5	14	2	0	-2	2	0	0	3.0	22	
i 1	121.00408163265305	0.505	71	711	4	24	8	8	0	-2	8	0	0	3.0	22	
i 1	121.01224489795918	0.2525	75	1097	6	5	3	8	0	-2	8	0	0	3.0	22	
i 1	121.26061224489796	1.7675	72	599	6	5	4	2	0	-2	2	0	0	3.0	22	
i 1	121.74319727891157	1.01	72	599	5	3	1	2	0	-2	2	0	0	11.0	22	
i 1	121.98884353741497	0.2525	72	213	6	9	12	2	0	-2	2	0	0	10.0	22	
i 1	121.99210884353741	3.0300000000000002	61	599	6	17	16	16	0	1	16	0	0	0.6126620377439105	22	
i 1	121.99918367346939	3.0300000000000002	63	213	5	18	1	16	0	2	16	0	0	0.6126620377439105	22	
i 1	121.99972789115647	3.0300000000000002	63	599	4	7	15	1	0	1	1	0	0	3.3962957923607635	22	
i 1	122.00136054421769	0.2525	75	711	4	5	2	2	0	-2	2	0	0	3.0	22	
i 1	122.01115646258503	1.7675	74	599	4	24	13	8	0	-1	8	0	0	3.0	22	
i 1	122.25190476190477	1.2625	72	599	4	4	16	2	0	1	2	0	0	11.0	22	
i 1	122.49755102040817	0.2525	75	213	6	9	1	2	0	-2	2	0	0	10.0	22	
i 1	122.50462585034013	1.01	72	1097	6	5	11	2	0	-2	2	0	0	3.0	22	
i 1	122.50517006802721	0.7575000000000001	71	711	4	24	3	8	0	-2	8	0	0	3.0	22	
i 1	122.73666666666666	0.505	75	1097	6	5	3	8	0	-2	8	0	0	3.0	22	
i 1	123.01115646258503	0.2525	75	711	5	3	12	2	0	1	2	0	0	11.0	22	
i 1	123.23666666666666	1.01	72	599	5	3	14	2	0	-2	2	0	0	11.0	22	
i 1	123.23993197278912	0.2525	72	599	6	5	4	2	0	-2	2	0	0	3.0	22	
i 1	123.25408163265305	0.2525	71	213	3	24	12	2	0	1	2	0	0	4.0	22	
i 1	123.48884353741497	1.5150000000000001	63	213	5	18	10	1	0	2	1	0	0	0.6126620377439105	22	
i 1	123.49809523809523	1.5150000000000001	61	1097	6	17	13	1	0	1	1	0	0	0.6126620377439105	22	
i 1	123.49863945578231	1.5150000000000001	71	213	1	24	13	2	0	252	2	307	0	4.0	22	
i 1	123.50897959183673	1.5150000000000001	61	599	6	17	6	16	0	2	16	0	0	0.6126620377439105	22	
i 1	123.51006802721088	0.2525	71	711	2	24	10	8	0	1	8	0	0	4.0	22	
i 1	123.51115646258503	1.5150000000000001	63	1097	5	14	6	16	0	2	16	0	0	4.807581383442391	22	
i 1	123.98666666666666	0.2525	72	599	6	5	3	2	0	-2	2	0	0	3.0	22	
i 1	124.00136054421769	0.2525	71	711	2	24	2	8	0	1	8	0	0	4.0	22	
i 1	124.00244897959183	0.7575000000000001	75	1097	6	5	6	8	0	-2	8	0	0	3.0	22	
i 1	124.25408163265305	0.2525	75	1097	6	2	7	2	0	-2	2	0	0	11.0	22	
i 1	124.49265306122449	0.505	72	599	4	4	4	2	0	1	2	0	0	11.0	22	
i 1	124.50680272108843	0.505	72	599	6	5	16	8	0	-2	8	0	0	3.0	22	
i 1	124.50843537414966	0.505	74	711	2	24	6	2	0	1	2	0	0	4.0	22	
i 1	124.75625850340136	0.2525	72	599	6	5	7	2	0	-2	2	0	0	3.0	23	
i 1	124.98775510204082	1.5150000000000001	61	904	4	18	6	16	0	1	16	0	0	0.6126620377439105	24	
i 1	124.98829931972789	3.0300000000000002	63	406	6	17	10	16	0	2	16	0	0	0.6126620377439105	24	
i 1	124.98884353741497	1.2625	75	90	5	5	1	2	0	-2	2	0	0	3.0	24	
i 1	124.98938775510204	3.0300000000000002	61	904	4	19	10	1	0	2	1	0	0	0.6126620377439105	24	
i 1	124.99319727891157	3.0300000000000002	63	90	7	17	14	1	0	2	1	0	0	0.6126620377439105	24	
i 1	124.99646258503401	0.2525	74	904	2	24	3	8	0	-2	8	0	0	4.0	24	
i 1	124.99646258503401	1.5150000000000001	61	406	4	13	15	16	0	2	16	0	0	0.5737246101975074	24	
i 1	124.99918367346939	1.5150000000000001	61	90	7	17	16	1	0	1	1	0	0	0.6126620377439105	24	
i 1	124.99918367346939	0.505	71	904	2	24	15	2	0	-2	2	0	0	4.0	24	
i 1	125.00027210884353	6.8175	61	904	1	27	8	16	0	252	16	307	0	1.7868394313862161	24	
i 1	125.00136054421769	1.5150000000000001	61	406	6	17	15	1	0	2	1	0	0	0.6126620377439105	24	
i 1	125.00190476190477	3.0300000000000002	61	90	6	14	15	16	0	1	16	0	0	4.807581383442391	24	
i 1	125.00952380952381	1.5150000000000001	61	90	6	14	7	1	0	1	1	0	0	4.807581383442391	24	
i 1	125.01170068027211	4.545	61	904	4	18	9	16	0	1	16	0	0	0.6126620377439105	24	
i 1	125.51061224489796	2.525	71	904	1	24	6	2	0	252	2	307	0	4.0	25	
i 1	125.74156462585034	0.505	72	904	5	9	13	2	0	1	2	0	0	10.0	26	
i 1	125.75571428571429	0.505	74	904	2	24	11	2	0	-2	2	0	0	4.0	26	
i 1	125.99047619047619	1.01	75	90	5	5	8	2	0	1	2	0	0	3.0	26	
i 1	126.24265306122449	0.2525	74	406	4	24	9	2	0	-1	2	0	0	3.0	26	
i 1	126.24265306122449	0.2525	72	904	6	5	4	2	0	-2	2	0	0	3.0	26	
i 1	126.24972789115647	3.7875	74	904	1	24	2	2	0	252	2	307	0	4.0	26	
i 1	126.50027210884353	5.3025	61	90	5	14	9	1	0	1	1	0	0	4.807581383442391	26	
i 1	126.50190476190477	3.0300000000000002	61	904	4	19	13	1	0	2	1	0	0	0.6126620377439105	26	
i 1	126.50299319727891	5.3025	61	90	6	17	11	1	0	1	1	0	0	0.6126620377439105	26	
i 1	126.50571428571429	3.0300000000000002	61	406	6	17	8	1	0	2	1	0	0	0.6126620377439105	26	
i 1	126.50625850340136	3.0300000000000002	61	406	5	13	1	16	0	2	16	0	0	0.5737246101975074	26	
i 1	126.51061224489796	4.545	61	904	4	18	8	16	0	1	16	0	0	0.6126620377439105	26	
i 1	126.51224489795918	1.5150000000000001	75	406	6	5	16	2	0	1	2	0	0	3.0	26	
i 1	126.73829931972789	3.0300000000000002	71	904	2	24	10	2	0	-2	2	0	0	4.0	26	
i 1	126.74319727891157	0.2525	72	90	6	2	14	2	0	-2	2	0	0	11.0	26	
i 1	126.76170068027211	0.2525	72	904	6	5	15	2	0	1	2	0	0	3.0	26	
i 1	126.99265306122449	0.2525	75	904	6	5	10	8	0	-2	8	0	0	3.0	26	
i 1	127.25897959183673	0.7575000000000001	75	904	6	5	8	2	0	1	2	0	0	3.0	26	
i 1	127.26170068027211	0.2525	74	406	4	24	9	2	0	-1	2	0	0	3.0	26	
i 1	127.75244897959183	0.2525	75	90	5	5	10	2	0	-2	2	0	0	3.0	27	
i 1	127.98829931972789	3.0300000000000002	63	406	6	17	7	16	0	2	16	0	0	0.6126620377439105	27	
i 1	127.98993197278912	3.7875	63	90	6	17	8	1	0	2	1	0	0	0.6126620377439105	27	
i 1	127.99047619047619	2.2725	72	406	4	5	11	2	0	1	2	0	0	3.0	27	
i 1	127.99482993197279	0.505	72	90	6	2	2	2	0	-2	2	0	0	11.0	27	
i 1	127.99646258503401	0.7575000000000001	75	406	4	5	3	2	0	1	2	0	0	3.0	27	
i 1	128.003537414966	3.7875	61	904	4	19	13	1	0	2	1	0	0	0.6126620377439105	27	
i 1	128.0078911564626	3.7875	61	90	5	14	2	16	0	1	16	0	0	4.807581383442391	27	
i 1	128.01006802721088	3.0300000000000002	61	406	6	7	16	1	0	2	1	0	0	3.3962957923607635	27	
i 1	128.23884353741497	0.7575000000000001	71	904	1	24	2	2	0	248	2	308	0	4.0	27	
i 1	128.2491836734694	0.2525	75	90	5	5	11	2	0	1	2	0	0	3.0	27	
i 1	128.2491836734694	0.2525	74	904	2	24	11	8	0	-2	8	0	0	4.0	27	
i 1	128.4877551020408	0.2525	72	904	5	9	15	2	0	1	2	0	0	10.0	27	
i 1	128.5078911564626	0.2525	72	904	4	4	2	2	0	1	2	0	0	11.0	27	
i 1	128.73938775510203	0.2525	74	406	4	24	16	2	0	-1	2	0	0	3.0	27	
i 1	128.753537414966	0.505	75	90	5	5	4	2	0	-2	2	0	0	3.0	27	
i 1	128.7622448979592	2.7775	72	90	6	2	16	2	0	-2	2	0	0	11.0	27	
i 1	128.99537414965985	0.505	72	904	6	5	6	2	0	-2	2	0	0	3.0	27	
i 1	129.246462585034	0.2525	72	90	6	2	2	2	0	-2	2	0	0	11.0	27	
i 1	129.48938775510203	2.2725	61	406	4	13	16	16	0	2	16	0	0	0.5737246101975074	27	
i 1	129.49102040816325	3.0300000000000002	61	904	4	18	2	16	0	1	16	0	0	0.6126620377439105	27	
i 1	129.496462585034	1.01	75	90	5	5	6	2	0	-2	2	0	0	3.0	27	
i 1	129.503537414966	2.2725	61	904	4	19	9	1	0	2	1	0	0	0.6126620377439105	27	
i 1	129.50680272108843	2.2725	61	406	5	17	1	1	0	2	1	0	0	0.6126620377439105	27	
i 1	129.75571428571428	0.2525	75	904	6	5	12	2	0	1	2	0	0	3.0	27	
i 1	129.99428571428572	0.2525	72	904	5	9	3	2	0	1	2	0	0	10.0	27	
i 1	130.0117006802721	0.2525	71	904	2	24	14	2	0	-2	2	0	0	4.0	27	
i 1	130.23721088435374	0.2525	72	90	6	2	3	2	0	-2	2	0	0	11.0	27	
i 1	130.26115646258503	0.505	72	904	3	5	10	2	0	1	2	0	0	3.0	27	
i 1	130.50136054421768	0.2525	75	406	4	4	12	2	0	1	2	0	0	11.0	27	
i 1	130.5117006802721	0.2525	75	904	5	3	13	8	0	1	8	0	0	11.0	27	
i 1	130.74102040816325	0.505	72	904	5	9	4	2	0	1	2	0	0	10.0	27	
i 1	130.75680272108843	1.01	74	406	4	24	8	2	0	-1	2	0	0	3.0	27	
i 1	130.7622448979592	0.2525	72	406	4	5	3	2	0	1	2	0	0	3.0	27	
i 1	130.99102040816325	0.7575000000000001	63	406	5	17	13	16	0	2	16	0	0	0.6126620377439105	27	
i 1	131.00571428571428	1.7675	61	904	4	18	7	16	0	1	16	0	0	0.6126620377439105	27	
i 1	131.4904761904762	0.2525	72	904	5	9	5	2	0	1	2	0	0	10.0	27	
i 1	131.49863945578232	0.2525	75	904	6	5	12	8	0	-2	8	0	0	3.0	27	
i 1	131.503537414966	0.2525	75	90	5	5	4	2	0	-2	2	0	0	3.0	27	
i 1	131.51061224489797	0.2525	72	406	5	3	8	2	0	-2	2	0	0	11.0	27	
i 1	131.7377551020408	1.01	75	202	6	2	7	2	0	-2	2	0	0	11.0	28	
i 1	131.74102040816325	1.01	63	588	5	17	14	16	0	1	16	0	0	0.6126620377439105	28	
i 1	131.74102040816325	1.01	63	202	1	27	10	16	0	252	16	307	0	1.7868394313862161	28	
i 1	131.74156462585034	1.01	61	588	4	7	6	16	0	2	16	0	0	3.3962957923607635	28	
i 1	131.74428571428572	1.01	61	202	5	14	3	16	0	1	16	0	0	4.807581383442391	28	
i 1	131.74700680272107	0.7575000000000001	61	202	6	17	2	1	0	2	1	0	0	0.6126620377439105	28	
i 1	131.74863945578232	1.01	61	202	6	17	11	16	0	2	16	0	0	0.6126620377439105	28	
i 1	131.74972789115645	1.01	63	202	1	27	2	1	0	252	1	307	0	1.7868394313862161	28	
i 1	131.75027210884355	1.01	63	588	5	17	8	16	0	2	16	0	0	0.6126620377439105	28	
i 1	131.75190476190477	0.7575000000000001	61	202	5	19	13	16	0	2	16	0	0	0.6126620377439105	28	
i 1	131.75190476190477	1.01	61	202	5	14	16	1	0	2	1	0	0	4.807581383442391	28	
i 1	131.75244897959183	1.01	71	202	2	24	2	2	0	1	2	0	0	4.0	28	
i 1	131.7578911564626	1.01	63	202	5	19	9	1	0	2	1	0	0	0.6126620377439105	28	
i 1	131.75897959183675	1.01	61	588	4	13	2	16	0	1	16	0	0	0.5737246101975074	28	
i 1	131.76006802721088	0.2525	75	202	7	5	7	2	0	-2	2	0	0	3.0	28	
i 1	131.76061224489797	0.2525	72	588	5	3	8	2	0	1	2	0	0	11.0	28	
i 1	131.98938775510203	0.2525	72	202	6	2	14	8	0	-2	8	0	0	11.0	29	
i 1	132.26333333333332	0.505	75	202	5	5	11	2	0	-2	2	0	0	3.0	29	
i 1	132.48884353741497	0.2525	61	202	7	17	8	1	0	2	1	0	0	0.6126620377439105	30	
i 1	132.48938775510203	0.2525	74	202	2	24	10	2	0	-2	2	0	0	4.0	30	
i 1	132.48993197278912	0.2525	61	202	5	19	4	16	0	2	16	0	0	0.6126620377439105	30	
i 1	132.49102040816325	0.2525	61	904	4	18	9	16	0	1	16	0	0	0.6126620377439105	30	
i 1	132.49809523809523	0.2525	71	202	2	24	14	2	0	-2	2	0	0	4.0	30	
i 1	132.73666666666668	0.7575000000000001	66	384	4	7	3	6	0	1	6	0	0	1.6883558086081272	64	
i 1	132.74156462585034	0.2525	74	384	4	4	10	8	0	-2	8	0	0	13.0	64	
i 1	132.74319727891157	1.01	71	1086	4	2	11	2	5000	-1	2	0	0	13.0	64	
i 1	132.7448299319728	0.2525	75	1086	6	1	12	2	5000	1	2	0	0	3.981212119583855	64	
i 1	132.74700680272107	0.7575000000000001	61	384	4	19	1	9	0	1	9	0	0	3.9915030803368663	64	
i 1	132.74700680272107	0.7575000000000001	69	384	6	5	9	0	0	-1	0	0	0	3.0000002607919654	64	
i 1	132.74700680272107	1.01	61	1086	3	14	14	6	5000	2	6	0	0	3.099641399689755	64	
i 1	132.74972789115645	0.2525	75	1086	6	1	3	2	5000	1	2	0	0	3.981212119583855	64	
i 1	132.753537414966	0.505	71	384	2	24	15	0	0	0	0	0	0	4.0	64	
i 1	132.75462585034015	0.7575000000000001	72	384	3	24	3	2	0	-2	2	0	0	6.981212119583855	64	
i 1	132.75625850340137	0.7575000000000001	61	770	4	18	3	6	0	1	6	0	0	3.9915030803368663	64	
i 1	132.75843537414966	0.7575000000000001	66	384	4	19	5	6	0	2	6	0	0	3.9915030803368663	64	
i 1	132.75897959183675	1.5150000000000001	71	1086	4	2	1	2	5000	-1	2	0	0	13.0	64	
i 1	132.7595238095238	2.525	66	1086	3	14	16	9	5000	1	9	0	0	3.099641399689755	64	
i 1	132.76061224489797	1.2625	69	1086	6	5	14	1	5000	-1	1	0	0	3.0000002607919654	64	
i 1	132.99374149659863	0.505	72	770	6	1	6	2	0	1	2	0	0	3.981212119583855	64	
i 1	132.9948299319728	0.2525	71	770	5	9	9	2	0	-2	2	0	0	12.0	64	
i 1	132.99591836734695	0.505	75	384	6	1	2	2	0	-2	2	0	0	3.981212119583855	64	
i 1	133.2617006802721	0.2525	71	384	3	24	2	0	0	0	0	0	0	4.0	65	
i 1	133.4882993197279	0.2525	75	384	3	1	7	2	0	-2	2	0	0	3.981212119583855	66	
i 1	133.48884353741497	0.2525	61	770	4	18	5	6	0	2	6	0	0	3.9915030803368663	66	
i 1	133.49102040816325	3.2825	61	384	4	19	12	9	0	2	9	0	0	3.9915030803368663	66	
i 1	133.50027210884355	4.7975	66	152	4	7	11	6	0	1	6	0	0	1.6883558086081272	66	
i 1	133.50244897959183	0.2525	71	384	2	24	6	1	0	0	1	0	0	4.0	66	
i 1	133.503537414966	1.7675	61	384	4	19	13	6	0	1	6	0	0	3.9915030803368663	66	
i 1	133.50462585034015	0.505	72	384	3	24	4	8	0	-2	8	0	0	6.981212119583855	66	
i 1	133.5051700680272	1.01	68	384	2	24	12	1	0	-1	1	0	0	4.0	66	
i 1	133.73938775510203	1.7675	71	1086	6	2	2	2	5000	-1	2	0	0	13.0	66	
i 1	133.74319727891157	0.505	72	1086	6	5	12	0	5000	-1	0	0	0	3.0000002607919654	66	
i 1	133.74537414965985	0.2525	72	384	4	5	12	1	0	-1	1	0	0	3.0000002607919654	66	
i 1	133.74537414965985	5.8075	61	1086	4	14	16	6	5000	2	6	0	0	3.099641399689755	66	
i 1	133.74972789115645	0.2525	72	770	6	1	2	2	0	1	2	0	0	3.981212119583855	66	
i 1	133.99156462585034	0.505	72	770	6	5	5	0	0	-1	0	0	0	3.0000002607919654	66	
i 1	134.00843537414966	0.7575000000000001	69	384	4	5	9	1	0	-1	1	0	0	3.0000002607919654	66	
i 1	134.2421088435374	0.2525	69	1086	6	5	7	1	5000	-1	1	0	0	3.0000002607919654	66	
i 1	134.253537414966	0.2525	71	152	3	24	16	1	0	0	1	0	0	4.0	66	
i 1	134.25408163265305	0.505	75	1086	6	1	8	2	5000	1	2	0	0	3.981212119583855	66	
i 1	134.26333333333332	0.2525	72	384	3	24	11	8	0	-2	8	0	0	6.981212119583855	66	
i 1	134.50571428571428	0.2525	69	770	6	5	12	1	0	-1	1	0	0	3.0000002607919654	66	
i 1	134.50625850340137	0.505	72	770	6	1	8	2	0	1	2	0	0	3.981212119583855	66	
i 1	134.7404761904762	4.7975	68	384	2	24	16	1	0	-1	1	0	0	4.0	66	
i 1	134.74428571428572	0.2525	72	384	4	5	16	1	0	-1	1	0	0	3.0000002607919654	66	
i 1	134.75136054421768	0.2525	72	770	6	5	13	0	0	-1	0	0	0	3.0000002607919654	66	
i 1	134.75244897959183	0.505	74	770	5	9	15	8	0	-1	8	0	0	12.0	66	
i 1	134.753537414966	0.505	75	384	3	1	10	2	0	-2	2	0	0	3.981212119583855	66	
i 1	135.00897959183675	0.2525	72	384	3	24	4	8	0	-2	8	0	0	6.981212119583855	66	
i 1	135.24102040816325	0.2525	75	384	6	1	2	2	0	-2	2	0	0	3.981212119583855	66	
i 1	135.24537414965985	0.505	71	770	5	9	11	2	0	-1	2	0	0	12.0	66	
i 1	135.2491836734694	0.2525	72	770	6	1	2	2	0	1	2	0	0	3.981212119583855	66	
i 1	135.25244897959183	2.525	75	1086	6	1	9	2	5000	1	2	0	0	3.981212119583855	66	
i 1	135.2595238095238	4.2925	66	1086	4	14	13	9	5000	1	9	0	0	3.099641399689755	66	
i 1	135.26115646258503	0.505	72	770	6	5	12	0	0	-1	0	0	0	3.0000002607919654	66	
i 1	135.49156462585034	0.505	72	770	6	1	6	2	0	1	2	0	0	3.981212119583855	67	
i 1	135.49374149659863	0.2525	74	152	4	3	15	8	0	-1	8	0	0	13.0	67	
i 1	135.496462585034	0.2525	72	384	3	24	15	8	0	-2	8	0	0	6.981212119583855	67	
i 1	135.49809523809523	0.2525	71	1086	6	2	1	2	5000	-1	2	0	0	13.0	67	
i 1	135.7382993197279	2.525	71	1086	6	2	14	2	5000	-1	2	0	0	13.0	67	
i 1	135.74972789115645	0.505	74	770	3	9	9	8	0	-1	8	0	0	12.0	67	
i 1	135.75897959183675	0.7575000000000001	74	384	5	3	16	8	0	-2	8	0	0	13.0	67	
i 1	135.76006802721088	0.2525	69	384	6	5	3	1	0	-1	1	0	0	3.0000002607919654	67	
i 1	135.99700680272107	0.7575000000000001	72	770	6	1	5	2	0	1	2	0	0	3.981212119583855	67	
i 1	136.01061224489797	0.2525	69	152	7	5	15	1	0	0	1	0	0	3.0000002607919654	67	
i 1	136.253537414966	0.2525	72	770	6	1	4	2	0	1	2	0	0	3.981212119583855	67	
i 1	136.48993197278912	0.505	71	384	4	4	12	8	0	-1	8	0	0	13.0	67	
i 1	136.49319727891157	0.505	72	770	6	5	5	0	0	-1	0	0	0	3.0000002607919654	67	
i 1	136.50680272108843	0.2525	74	152	4	3	7	8	0	-1	8	0	0	13.0	67	
i 1	136.51333333333332	0.505	71	384	2	24	11	0	0	-1	0	0	0	4.0	67	
i 1	136.74863945578232	0.7575000000000001	74	384	5	3	16	8	0	-2	8	0	0	13.0	67	
i 1	136.75027210884355	1.5150000000000001	66	1086	5	17	4	6	5000	1	6	0	0	3.9915030803368663	67	
i 1	136.75136054421768	0.505	71	1086	6	2	7	2	5000	-1	2	0	0	13.0	67	
i 1	136.76061224489797	2.7775	69	1086	5	5	10	1	5000	-1	1	0	0	3.0000002607919654	67	
i 1	136.9926530612245	0.2525	69	384	6	5	15	1	0	-1	1	0	0	3.0000002607919654	67	
i 1	136.99428571428572	0.2525	74	152	6	3	11	8	0	-1	8	0	0	13.0	67	
i 1	136.99972789115645	0.505	72	770	6	1	10	2	0	1	2	0	0	3.981212119583855	67	
i 1	137.00843537414966	0.2525	72	1086	5	5	16	0	5000	-1	0	0	0	3.0000002607919654	67	
i 1	137.24700680272107	0.505	72	770	6	1	12	2	0	1	2	0	0	3.981212119583855	67	
i 1	137.26006802721088	0.505	71	384	2	24	12	0	0	0	0	0	0	4.0	67	
i 1	137.2617006802721	0.505	72	770	6	5	10	0	0	-1	0	0	0	3.0000002607919654	67	
i 1	137.51278911564626	0.7575000000000001	72	152	7	1	14	2	0	1	2	0	0	3.981212119583855	67	
i 1	137.7377551020408	0.2525	72	384	4	24	14	8	0	-2	8	0	0	6.981212119583855	67	
i 1	137.74428571428572	0.2525	75	1086	6	1	16	2	5000	1	2	0	0	3.981212119583855	67	
i 1	137.74428571428572	0.2525	72	384	6	5	13	1	0	-1	1	0	0	3.0000002607919654	67	
i 1	137.75462585034015	0.2525	71	384	4	4	1	8	0	-1	8	0	0	13.0	67	
i 1	137.7578911564626	0.505	74	384	5	3	8	8	0	-2	8	0	0	13.0	67	
i 1	137.9948299319728	0.2525	72	770	6	5	1	0	0	-1	0	0	0	3.0000002607919654	67	
i 1	138.01006802721088	1.5150000000000001	71	770	2	24	12	1	0	-1	1	0	0	4.0	67	
i 1	138.01061224489797	0.2525	75	384	6	1	2	2	0	-2	2	0	0	3.981212119583855	67	
i 1	138.23666666666668	1.01	74	152	5	4	10	8	0	-2	8	0	0	13.0	67	
i 1	138.23884353741497	1.2625	66	1086	6	17	15	6	5000	1	6	0	0	3.9915030803368663	67	
i 1	138.2551700680272	1.2625	66	1086	5	17	5	6	5000	2	6	0	0	3.9915030803368663	67	
i 1	138.25897959183675	0.2525	71	1086	4	2	9	2	5000	-1	2	0	0	13.0	67	
i 1	138.2595238095238	1.01	72	384	4	24	3	8	0	-2	8	0	0	6.981212119583855	67	
i 1	138.4904761904762	0.505	74	152	6	3	4	8	0	-1	8	0	0	13.0	67	
i 1	138.49972789115645	1.01	75	1086	4	1	2	2	5000	1	2	0	0	3.981212119583855	67	
i 1	138.50299319727893	0.2525	68	152	3	24	9	1	0	0	1	0	0	4.0	67	
i 1	138.74374149659863	0.2525	72	770	6	5	12	0	0	-1	0	0	0	3.0000002607919654	67	
i 1	138.75462585034015	0.505	71	384	2	24	9	1	0	-1	1	0	0	4.0	67	
i 1	138.76278911564626	0.505	71	384	4	4	14	8	0	-1	8	0	0	13.0	67	
i 1	138.9991836734694	0.505	71	1086	4	2	14	2	5000	-1	2	0	0	13.0	67	
i 1	139.00462585034015	0.505	69	152	7	5	4	1	0	-1	1	0	0	3.0000002607919654	67	
i 1	139.24537414965985	0.2525	74	152	6	3	12	8	0	-1	8	0	0	13.0	67	
i 1	139.24755102040817	0.2525	74	384	3	3	12	8	0	-2	8	0	0	13.0	67	
i 1	139.25136054421768	0.2525	71	152	3	24	7	0	0	-1	0	0	0	4.0	67	
i 1	139.48666666666668	0.2525	74	882	2	3	2	2	0	-1	2	0	0	13.0	68	
i 1	139.49102040816325	0.2525	72	68	5	24	3	2	0	1	2	0	0	6.981212119583855	68	
i 1	139.4921088435374	12.3725	66	882	6	17	16	9	0	1	9	0	0	3.9915030803368663	68	
i 1	139.49319727891157	0.2525	71	882	6	2	8	8	0	-2	8	0	0	13.0	68	
i 1	139.49428571428572	10.8575	66	882	4	14	5	6	0	2	6	0	0	3.099641399689755	68	
i 1	139.49755102040817	4.04	68	882	1	24	16	0	0	-1	0	0	0	4.0	68	
i 1	139.49809523809523	0.2525	66	882	5	17	7	6	0	2	6	0	0	3.9915030803368663	68	
i 1	139.49809523809523	0.2525	72	68	7	5	14	0	0	0	0	0	0	3.0000002607919654	68	
i 1	139.50680272108843	1.01	71	384	2	24	5	1	0	-1	1	0	0	4.0	68	
i 1	139.5078911564626	1.2625	69	882	5	5	1	0	0	-1	0	0	0	3.0000002607919654	68	
i 1	139.5095238095238	0.2525	75	882	4	24	3	2	0	-2	2	0	0	6.981212119583855	68	
i 1	139.51061224489797	12.3725	61	882	4	14	5	9	0	1	9	0	0	3.099641399689755	68	
i 1	139.5122448979592	0.2525	69	882	6	5	9	1	0	0	1	0	0	3.0000002607919654	68	
i 1	139.7421088435374	1.7675	72	68	5	5	5	0	0	0	0	0	0	3.0000002607919654	69	
i 1	139.74809523809523	1.01	69	384	6	5	9	0	0	-1	0	0	0	3.0000002607919654	69	
i 1	139.75680272108843	1.5150000000000001	66	68	5	17	4	9	0	1	9	0	0	3.9915030803368663	69	
i 1	139.76115646258503	0.2525	71	68	3	24	9	0	0	-1	0	0	0	4.0	69	
i 1	139.76333333333332	13.635	66	882	6	17	1	6	0	2	6	0	0	3.9915030803368663	69	
i 1	139.99809523809523	0.505	74	882	2	3	16	2	0	-1	2	0	0	13.0	69	
i 1	139.99863945578232	0.2525	74	882	2	4	10	2	0	-1	2	0	0	13.0	69	
i 1	140.00408163265305	0.505	75	882	4	1	10	2	0	1	2	0	0	3.981212119583855	69	
i 1	140.0122448979592	0.505	71	882	1	24	1	1	0	0	1	0	0	4.0	69	
i 1	140.24755102040817	0.505	74	68	6	3	6	2	0	-1	2	0	0	13.0	70	
i 1	140.25299319727893	1.5150000000000001	71	68	5	4	10	2	0	-1	2	0	0	13.0	70	
i 1	140.48938775510203	0.2525	72	384	6	1	4	8	0	-2	8	0	0	3.981212119583855	71	
i 1	140.5073469387755	0.2525	75	882	4	1	12	2	0	1	2	0	0	3.981212119583855	71	
i 1	140.51061224489797	0.2525	71	882	1	24	2	1	0	0	1	0	0	4.0	71	
i 1	140.75625850340137	0.505	71	882	4	2	1	8	0	-2	8	0	0	13.0	71	
i 1	140.75625850340137	0.2525	69	882	6	5	12	1	0	0	1	0	0	3.0000002607919654	71	
i 1	140.99102040816325	2.02	69	882	5	5	14	0	0	-1	0	0	0	3.0000002607919654	71	
i 1	140.9921088435374	0.7575000000000001	71	882	1	24	7	1	0	0	1	0	0	4.0	71	
i 1	141.0008163265306	0.505	74	882	2	4	13	2	0	-1	2	0	0	13.0	71	
i 1	141.24755102040817	13.13	66	68	6	17	9	9	0	1	9	0	0	3.9915030803368663	71	
i 1	141.25625850340137	1.5150000000000001	61	68	5	17	2	6	0	1	6	0	0	3.9915030803368663	71	
i 1	141.26061224489797	0.505	74	68	4	3	8	2	0	-1	2	0	0	13.0	71	
i 1	141.2622448979592	0.2525	72	384	6	1	10	8	0	-2	8	0	0	3.981212119583855	71	
i 1	141.26278911564626	1.5150000000000001	75	68	4	1	1	2	0	1	2	0	0	3.981212119583855	71	
i 1	141.49972789115645	0.505	71	384	5	9	13	2	0	-1	2	0	0	12.0	71	
i 1	141.50843537414966	1.2625	72	68	5	24	3	2	0	1	2	0	0	6.981212119583855	71	
i 1	141.74863945578232	0.505	74	882	2	3	1	2	0	-1	2	0	0	13.0	71	
i 1	141.74863945578232	0.505	69	882	6	5	14	1	0	0	1	0	0	3.0000002607919654	71	
i 1	141.75843537414966	0.505	74	882	2	4	6	2	0	-1	2	0	0	13.0	71	
i 1	141.9921088435374	0.2525	71	882	4	2	10	8	0	-2	8	0	0	13.0	71	
i 1	142.00027210884355	5.3025	72	882	5	5	2	1	0	0	1	0	0	3.0000002607919654	71	
i 1	142.003537414966	3.7875	75	882	4	1	2	2	0	1	2	0	0	3.981212119583855	71	
i 1	142.23938775510203	0.2525	69	384	4	5	12	1	0	-1	1	0	0	3.0000002607919654	71	
i 1	142.24102040816325	0.2525	71	68	3	24	5	1	0	-1	1	0	0	4.0	71	
i 1	142.48666666666668	0.505	68	882	1	24	8	1	0	-1	1	0	0	4.0	72	
i 1	142.50244897959183	0.2525	72	68	5	5	8	0	0	0	0	0	0	3.0000002607919654	72	
i 1	142.50299319727893	0.2525	74	68	4	3	13	2	0	-1	2	0	0	13.0	72	
i 1	142.73993197278912	1.5150000000000001	61	384	4	18	10	6	0	1	6	0	0	3.9915030803368663	72	
i 1	142.7421088435374	11.615	61	68	6	17	8	6	0	1	6	0	0	3.9915030803368663	72	
i 1	142.74755102040817	0.7575000000000001	72	68	4	24	9	2	0	1	2	0	0	6.981212119583855	72	
i 1	142.74972789115645	0.505	69	882	6	5	9	1	0	0	1	0	0	3.0000002607919654	72	
i 1	142.75244897959183	1.7675	71	68	4	4	13	2	0	-1	2	0	0	13.0	72	
i 1	142.75897959183675	0.2525	75	882	4	24	12	2	0	-2	2	0	0	6.981212119583855	72	
i 1	142.7617006802721	0.505	72	384	5	1	5	8	0	-2	8	0	0	3.981212119583855	72	
i 1	142.98938775510203	0.505	75	882	4	1	9	2	0	1	2	0	0	3.981212119583855	72	
i 1	143.003537414966	1.2625	71	882	4	2	8	8	0	-2	8	0	0	13.0	72	
i 1	143.49591836734695	0.2525	72	882	6	1	4	2	0	-2	2	0	0	3.981212119583855	72	
i 1	143.50244897959183	0.505	69	882	6	5	13	1	0	0	1	0	0	3.0000002607919654	72	
i 1	143.74374149659863	0.2525	75	882	4	24	10	2	0	-2	2	0	0	6.981212119583855	72	
i 1	143.74972789115645	0.2525	74	68	4	3	2	2	0	-1	2	0	0	13.0	72	
i 1	143.75680272108843	0.2525	69	384	4	5	6	0	0	-1	0	0	0	3.0000002607919654	72	
i 1	144.00136054421768	0.505	72	68	5	5	6	1	0	-1	1	0	0	3.0000002607919654	72	
i 1	144.00408163265305	0.2525	71	882	1	24	11	0	0	0	0	0	0	4.0	72	
i 1	144.24863945578232	0.2525	71	882	1	24	10	1	0	0	1	0	0	4.0	72	
i 1	144.2508163265306	10.1	61	384	4	18	6	6	0	1	6	0	0	3.9915030803368663	72	
i 1	144.25571428571428	1.5150000000000001	61	384	4	18	8	9	0	1	9	0	0	3.9915030803368663	72	
i 1	144.48993197278912	0.2525	74	68	4	3	16	2	0	-1	2	0	0	13.0	72	
i 1	144.4921088435374	0.505	74	882	6	2	1	8	0	-1	8	0	0	13.0	72	
i 1	144.50897959183675	0.2525	74	384	5	9	14	8	0	-2	8	0	0	12.0	72	
i 1	144.75897959183675	0.2525	69	384	4	5	9	0	0	-1	0	0	0	3.0000002607919654	72	
i 1	144.99374149659863	0.2525	75	384	3	1	1	8	0	1	8	0	0	3.981212119583855	72	
i 1	144.99591836734695	0.2525	71	384	3	9	8	2	0	-1	2	0	0	12.0	72	
i 1	144.99972789115645	0.2525	69	882	6	5	5	1	0	0	1	0	0	3.0000002607919654	72	
i 1	145.01115646258503	0.2525	71	384	2	24	9	1	0	-1	1	0	0	4.0	72	
i 1	145.24319727891157	1.01	71	384	1	24	8	1	0	248	1	308	0	4.0	72	
i 1	145.25571428571428	3.535	68	882	1	24	7	0	0	-1	0	0	0	4.0	72	
i 1	145.25897959183675	0.505	72	882	4	1	7	2	0	-2	2	0	0	3.981212119583855	72	
i 1	145.50625850340137	0.2525	69	384	4	5	10	1	0	-1	1	0	0	3.0000002607919654	72	
i 1	145.51006802721088	0.2525	69	882	6	5	5	1	0	0	1	0	0	3.0000002607919654	72	
i 1	145.51061224489797	0.2525	75	882	4	24	3	2	0	-2	2	0	0	6.981212119583855	72	
i 1	145.73666666666668	0.2525	74	68	6	3	7	2	0	-1	2	0	0	13.0	72	
i 1	145.76006802721088	0.7575000000000001	75	882	4	1	1	2	0	1	2	0	0	3.981212119583855	72	
i 1	145.76061224489797	8.585	61	384	4	18	8	9	0	1	9	0	0	3.9915030803368663	72	
i 1	145.76115646258503	1.5150000000000001	61	882	3	19	13	6	0	1	6	0	0	3.9915030803368663	72	
i 1	145.7617006802721	0.2525	74	882	4	4	8	2	0	-1	2	0	0	13.0	72	
i 1	145.99428571428572	1.01	74	384	3	9	10	8	0	-2	8	0	0	12.0	72	
i 1	146.0051700680272	0.2525	69	384	4	5	12	0	0	-1	0	0	0	3.0000002607919654	72	
i 1	146.0117006802721	0.2525	71	384	3	9	14	2	0	-1	2	0	0	12.0	72	
i 1	146.24156462585034	2.525	75	68	4	1	2	2	0	1	2	0	0	3.981212119583855	72	
i 1	146.25408163265305	4.7975	74	882	6	2	7	8	0	-1	8	0	0	13.0	72	
i 1	146.75462585034015	0.2525	75	882	4	24	11	2	0	-2	2	0	0	6.981212119583855	74	
i 1	146.98666666666668	0.2525	71	384	3	9	1	2	0	-1	2	0	0	12.0	74	
i 1	147.00462585034015	1.01	75	384	3	1	8	8	0	1	8	0	0	3.981212119583855	74	
i 1	147.0078911564626	2.7775	72	68	5	5	3	0	0	0	0	0	0	3.0000002607919654	74	
i 1	147.2426530612245	7.07	61	882	4	19	12	6	0	1	6	0	0	3.9915030803368663	75	
i 1	147.24428571428572	0.2525	71	882	1	24	10	1	0	0	1	0	0	4.0	75	
i 1	147.25625850340137	1.5150000000000001	61	882	3	19	12	6	0	1	6	0	0	3.9915030803368663	75	
i 1	147.26333333333332	1.01	72	882	6	5	15	1	0	0	1	0	0	3.0000002607919654	75	
i 1	147.51278911564626	2.525	75	882	4	1	7	2	0	1	2	0	0	3.981212119583855	76	
i 1	147.74156462585034	0.2525	74	68	6	3	12	2	0	-1	2	0	0	13.0	76	
i 1	147.7617006802721	0.2525	69	882	6	5	6	0	0	-1	0	0	0	3.0000002607919654	76	
i 1	148.00843537414966	0.505	75	882	4	24	9	2	0	-2	2	0	0	6.981212119583855	76	
i 1	148.25571428571428	0.505	71	384	3	9	15	2	0	-1	2	0	0	12.0	76	
i 1	148.25843537414966	0.2525	72	68	4	24	3	2	0	1	2	0	0	6.981212119583855	76	
i 1	148.49591836734695	0.2525	69	882	6	5	13	0	0	-1	0	0	0	3.0000002607919654	76	
i 1	148.496462585034	0.2525	75	384	3	1	7	8	0	1	8	0	0	3.981212119583855	76	
i 1	148.496462585034	0.2525	72	882	2	1	13	2	0	-2	2	0	0	3.981212119583855	76	
i 1	148.50244897959183	0.2525	71	882	6	2	6	8	0	-2	8	0	0	13.0	76	
i 1	148.74102040816325	4.7975	72	68	4	24	1	2	0	1	2	0	0	6.981212119583855	76	
i 1	148.74156462585034	5.555	61	882	4	19	8	6	0	1	6	0	0	3.9915030803368663	76	
i 1	148.7508163265306	0.2525	71	882	1	24	2	1	0	0	1	0	0	4.0	76	
i 1	148.753537414966	0.7575000000000001	71	384	5	9	12	2	0	-1	2	0	0	12.0	76	
i 1	149.2404761904762	0.2525	74	384	3	9	14	8	0	-2	8	0	0	12.0	76	
i 1	149.25680272108843	0.2525	72	882	6	5	14	1	0	0	1	0	0	3.0000002607919654	76	
i 1	149.26061224489797	1.01	69	882	6	5	1	0	0	-1	0	0	0	3.0000002607919654	76	
i 1	149.49537414965985	0.2525	71	68	5	4	15	2	0	-1	2	0	0	13.0	77	
i 1	149.50190476190477	0.505	71	882	6	2	11	8	0	-2	8	0	0	13.0	77	
i 1	149.50571428571428	0.2525	74	68	6	3	4	2	0	-1	2	0	0	13.0	77	
i 1	149.7382993197279	0.505	74	882	2	3	5	2	0	-1	2	0	0	13.0	77	
i 1	149.74863945578232	0.2525	69	384	4	5	1	0	0	-1	0	0	0	3.0000002607919654	77	
i 1	149.9877551020408	1.7675	72	882	6	5	8	1	0	0	1	0	0	3.0000002607919654	77	
i 1	150.00408163265305	2.2725	71	68	5	4	13	2	0	-1	2	0	0	13.0	77	
i 1	150.23721088435374	3.0300000000000002	66	882	3	14	2	6	0	2	6	0	0	3.099641399689755	77	
i 1	150.24972789115645	0.7575000000000001	69	882	6	5	8	0	0	-1	0	0	0	3.0000002607919654	77	
i 1	150.26006802721088	0.505	71	882	6	2	14	8	0	-2	8	0	0	13.0	77	
i 1	150.2622448979592	1.01	72	68	7	5	8	0	0	0	0	0	0	3.0000002607919654	77	
i 1	150.48938775510203	0.505	69	384	4	5	8	1	0	-1	1	0	0	3.0000002607919654	77	
i 1	150.49591836734695	0.2525	75	384	3	1	4	8	0	1	8	0	0	3.981212119583855	77	
i 1	150.75136054421768	0.505	71	384	5	9	9	2	0	-1	2	0	0	12.0	77	
i 1	150.76278911564626	0.2525	75	882	2	24	12	2	0	-2	2	0	0	6.981212119583855	77	
i 1	151.0073469387755	0.505	75	882	4	1	14	2	0	1	2	0	0	3.981212119583855	77	
i 1	151.01333333333332	1.01	72	68	7	5	5	1	0	-1	1	0	0	3.0000002607919654	77	
i 1	151.2404761904762	0.2525	69	882	3	5	10	0	0	-1	0	0	0	3.0000002607919654	77	
i 1	151.24863945578232	0.2525	75	882	4	1	2	2	0	1	2	0	0	3.981212119583855	77	
i 1	151.25408163265305	0.2525	74	882	2	4	6	2	0	-1	2	0	0	13.0	77	
i 1	151.2617006802721	0.2525	69	384	4	5	5	1	0	-1	1	0	0	3.0000002607919654	77	
i 1	151.2617006802721	2.7775	71	384	1	24	11	1	0	248	1	308	0	4.0	77	
i 1	151.49374149659863	2.7775	72	68	7	5	1	0	0	0	0	0	0	3.0000002607919654	77	
i 1	151.503537414966	0.2525	68	882	1	24	12	0	0	-1	0	0	0	4.0	77	
i 1	151.5078911564626	0.2525	69	882	3	5	5	1	0	0	1	0	0	3.0000002607919654	77	
i 1	151.73721088435374	2.525	66	882	6	17	12	9	0	1	9	0	0	3.9915030803368663	77	
i 1	151.73993197278912	1.5150000000000001	75	882	4	1	14	2	0	1	2	0	0	3.981212119583855	77	
i 1	151.75299319727893	0.7575000000000001	72	882	6	5	16	1	0	0	1	0	0	3.0000002607919654	77	
i 1	151.7622448979592	2.525	61	882	3	14	7	9	0	1	9	0	0	3.099641399689755	77	
i 1	152.00027210884355	0.2525	71	384	5	9	5	2	0	-1	2	0	0	12.0	77	
i 1	152.01115646258503	0.2525	69	882	3	5	2	1	0	0	1	0	0	3.0000002607919654	77	
i 1	152.24156462585034	1.01	74	384	5	9	14	8	0	-2	8	0	0	12.0	77	
i 1	152.24319727891157	0.505	74	882	6	2	14	8	0	-1	8	0	0	13.0	77	
i 1	152.2617006802721	1.01	74	882	2	4	2	2	0	-1	2	0	0	13.0	77	
i 1	152.74102040816325	0.2525	71	882	1	24	16	1	0	0	1	0	0	4.0	77	
i 1	152.74591836734695	0.505	72	882	2	1	11	2	0	-2	2	0	0	3.981212119583855	77	
i 1	153.0117006802721	0.2525	75	882	4	1	5	2	0	1	2	0	0	3.981212119583855	77	
i 1	153.2382993197279	1.01	66	882	5	14	1	6	0	2	6	0	0	3.099641399689755	77	
i 1	153.24319727891157	1.01	74	882	6	2	14	8	0	-1	8	0	0	13.0	77	
i 1	153.24700680272107	1.01	66	882	6	17	14	6	0	2	6	0	0	3.9915030803368663	77	
i 1	153.25462585034015	0.505	75	384	3	1	5	8	0	1	8	0	0	3.981212119583855	77	
i 1	153.4991836734694	0.505	69	384	6	5	5	1	0	-1	1	0	0	3.0000002607919654	78	
i 1	153.73938775510203	0.2525	75	882	4	1	7	2	0	1	2	0	0	3.981212119583855	79	
i 1	153.7421088435374	0.505	75	68	4	1	7	2	0	1	2	0	0	3.981212119583855	79	
i 1	153.99755102040817	0.2525	69	882	3	5	4	0	0	-1	0	0	0	3.0000002607919654	79	
i 1	153.99972789115645	0.2525	71	384	2	24	15	1	0	-1	1	0	0	4.0	79	
i 1	154.01333333333332	0.2525	71	384	5	9	10	2	0	-1	2	0	0	12.0	79	
i 1	154.23884353741497	0.505	66	882	4	7	5	9	0	1	9	0	0	1.6883558086081272	80	
i 1	154.23938775510203	0.505	61	384	4	18	13	6	0	1	6	0	0	3.9915030803368663	80	
i 1	154.23938775510203	0.2525	72	384	6	5	13	0	0	0	0	0	0	3.0000002607919654	80	
i 1	154.24319727891157	0.505	66	882	6	17	2	9	0	2	9	0	0	3.9915030803368663	80	
i 1	154.24319727891157	0.505	61	68	6	14	7	6	0	2	6	0	0	3.099641399689755	80	
i 1	154.24374149659863	0.505	66	68	7	17	15	6	0	1	6	0	0	3.9915030803368663	80	
i 1	154.2448299319728	0.505	75	68	7	1	13	2	0	-2	2	0	0	3.981212119583855	80	
i 1	154.24700680272107	0.505	61	882	6	17	1	9	0	1	9	0	0	3.9915030803368663	80	
i 1	154.24863945578232	0.505	75	882	2	24	11	2	0	-2	2	0	0	6.981212119583855	80	
i 1	154.24863945578232	0.505	71	68	7	2	13	8	0	-2	8	0	0	13.0	80	
i 1	154.25299319727893	0.505	71	68	7	2	14	2	0	-1	2	0	0	13.0	80	
i 1	154.25462585034015	0.505	61	68	7	17	3	9	0	2	9	0	0	3.9915030803368663	80	
i 1	154.2551700680272	0.2525	68	882	1	24	3	1	0	0	1	0	0	4.0	80	
i 1	154.2578911564626	0.505	66	882	4	19	11	6	0	2	6	0	0	3.9915030803368663	80	
i 1	154.26006802721088	0.505	61	68	4	14	11	9	0	2	9	0	0	3.099641399689755	80	
i 1	154.2617006802721	0.505	61	882	4	19	5	9	0	1	9	0	0	3.9915030803368663	80	
i 1	154.26333333333332	0.505	61	384	4	18	2	6	0	2	6	0	0	3.9915030803368663	80	
i 1	154.73721088435374	0.505	72	882	3	5	14	0	0	-1	0	0	0	3.0000003880832815	81	
i 1	154.73884353741497	1.5150000000000001	66	68	7	17	13	6	0	1	6	0	0	2.31872071921609	81	
i 1	154.73938775510203	0.2525	75	68	7	1	15	2	0	-2	2	0	0	2.9121610345324758	81	
i 1	154.74156462585034	1.5150000000000001	72	882	4	1	8	8	0	-2	8	0	0	2.9121610345324758	81	
i 1	154.74428571428572	6.0600000000000005	61	882	4	19	3	9	0	1	9	0	0	2.31872071921609	81	
i 1	154.74591836734695	6.0600000000000005	66	882	4	19	12	6	0	2	6	0	0	2.31872071921609	81	
i 1	154.75190476190477	2.02	72	68	7	1	12	2	0	1	2	0	0	2.9121610345324758	81	
i 1	154.75408163265305	0.505	74	882	5	3	4	2	0	-1	2	0	0	4.0	81	
i 1	154.75462585034015	1.5150000000000001	66	882	6	17	7	9	0	2	9	0	0	2.31872071921609	81	
i 1	154.75462585034015	2.02	72	882	6	5	12	1	0	-1	1	0	0	3.0000003880832815	81	
i 1	154.75571428571428	3.0300000000000002	61	384	4	18	4	6	0	1	6	0	0	2.31872071921609	81	
i 1	154.75625850340137	4.545	61	384	4	18	7	6	0	2	6	0	0	2.31872071921609	81	
i 1	154.7617006802721	3.0300000000000002	61	882	6	17	2	9	0	1	9	0	0	2.31872071921609	81	
i 1	154.98938775510203	0.7575000000000001	74	384	5	9	13	8	0	-2	8	0	0	3.0000000000000004	81	
i 1	154.98938775510203	0.2525	68	882	1	24	3	0	0	-1	0	0	0	4.0	81	
i 1	154.99537414965985	0.505	72	68	7	5	7	1	0	-1	1	0	0	3.0000003880832815	81	
i 1	155.50299319727893	2.2725	72	882	4	24	7	2	0	1	2	0	0	5.912161034532476	81	
i 1	155.7404761904762	0.2525	75	68	7	1	1	2	0	-2	2	0	0	2.9121610345324758	81	
i 1	155.74102040816325	2.525	72	68	7	5	2	1	0	-1	1	0	0	3.0000003880832815	81	
i 1	155.75027210884355	0.2525	74	882	4	3	16	2	0	-1	2	0	0	4.0	81	
i 1	155.98666666666668	0.7575000000000001	71	882	4	4	11	2	0	-1	2	0	0	4.0	81	
i 1	155.98993197278912	2.02	68	882	1	24	3	0	0	-1	0	0	0	4.0	81	
i 1	155.9991836734694	0.2525	72	384	4	1	1	8	0	-2	8	0	0	2.9121610345324758	81	
i 1	156.00190476190477	0.505	74	882	5	3	16	2	0	-1	2	0	0	4.0	81	
i 1	156.2404761904762	3.0300000000000002	66	882	6	17	16	9	0	2	9	0	0	2.31872071921609	81	
i 1	156.25843537414966	0.505	72	882	2	1	5	2	0	1	2	0	0	2.9121610345324758	81	
i 1	156.2617006802721	0.2525	69	882	5	5	1	0	0	-1	0	0	0	3.0000003880832815	81	
i 1	156.48721088435374	1.5150000000000001	74	882	4	4	1	8	0	-1	8	0	0	4.0	82	
i 1	156.4921088435374	0.2525	68	882	1	24	7	0	0	0	0	0	0	4.0	82	
i 1	156.49755102040817	0.505	72	384	6	5	15	0	0	0	0	0	0	3.0000003880832815	82	
i 1	156.74863945578232	1.2625	68	882	1	24	3	0	0	252	0	307	0	4.0	82	
i 1	156.753537414966	0.505	69	882	5	5	15	0	0	-1	0	0	0	3.0000003880832815	82	
i 1	156.7573469387755	0.2525	72	882	6	5	11	0	0	0	0	0	0	3.0000003880832815	82	
i 1	156.98938775510203	0.2525	72	882	5	5	14	0	0	-1	0	0	0	3.0000003880832815	82	
i 1	156.99319727891157	0.2525	72	882	2	1	8	2	0	1	2	0	0	2.9121610345324758	82	
i 1	156.99428571428572	0.2525	74	882	5	3	1	2	0	-1	2	0	0	4.0	82	
i 1	156.99700680272107	2.2725	71	68	7	2	16	2	0	-1	2	0	0	4.0	82	
i 1	157.00027210884355	3.7875	68	882	1	24	8	1	0	0	1	0	0	4.0	82	
i 1	157.00190476190477	0.505	72	882	6	5	1	1	0	-1	1	0	0	3.0000003880832815	82	
i 1	157.2491836734694	3.535	72	68	7	5	15	0	0	-1	0	0	0	3.0000003880832815	82	
i 1	157.48993197278912	0.505	72	384	6	5	3	0	0	0	0	0	0	3.0000003880832815	82	
i 1	157.49537414965985	0.2525	72	882	6	5	5	0	0	0	0	0	0	3.0000003880832815	82	
i 1	157.73884353741497	3.0300000000000002	72	882	4	24	7	2	0	1	2	0	0	5.912161034532476	82	
i 1	157.73884353741497	0.7575000000000001	71	68	5	2	3	8	0	-2	8	0	0	4.0	82	
i 1	157.73993197278912	0.505	72	882	6	5	10	1	0	-1	1	0	0	3.0000003880832815	82	
i 1	157.75136054421768	0.505	72	882	2	1	13	2	0	1	2	0	0	2.9121610345324758	82	
i 1	157.7622448979592	3.0300000000000002	61	384	4	18	10	6	0	1	6	0	0	2.31872071921609	82	
i 1	157.9926530612245	0.2525	74	882	4	3	9	2	0	-1	2	0	0	4.0	82	
i 1	158.00625850340137	0.505	72	384	4	1	7	8	0	-2	8	0	0	2.9121610345324758	82	
i 1	158.00625850340137	0.7575000000000001	69	882	5	5	1	0	0	-1	0	0	0	3.0000003880832815	82	
i 1	158.2421088435374	0.2525	74	882	5	3	14	2	0	-1	2	0	0	4.0	82	
i 1	158.2426530612245	1.2625	71	384	3	24	13	1	0	-1	1	0	0	4.0	82	
i 1	158.50408163265305	0.2525	74	882	4	3	11	2	0	-1	2	0	0	4.0	82	
i 1	158.5073469387755	0.2525	74	882	4	4	15	8	0	-1	8	0	0	4.0	82	
i 1	158.50897959183675	0.505	75	68	7	1	5	2	0	-2	2	0	0	2.9121610345324758	82	
i 1	158.7426530612245	0.2525	72	68	7	5	11	1	0	-1	1	0	0	3.0000003880832815	82	
i 1	158.99863945578232	0.2525	72	68	7	1	3	2	0	1	2	0	0	2.9121610345324758	82	
i 1	159.0051700680272	0.2525	72	882	6	5	9	1	0	-1	1	0	0	3.0000003880832815	82	
i 1	159.01061224489797	1.7675	71	68	5	2	2	8	0	-2	8	0	0	4.0	82	
i 1	159.2377551020408	2.2725	61	384	4	18	12	6	0	2	6	0	0	2.31872071921609	82	
i 1	159.25843537414966	0.505	72	68	7	1	16	2	0	1	2	0	0	2.9121610345324758	82	
i 1	159.2595238095238	0.7575000000000001	71	68	5	2	13	2	0	-1	2	0	0	4.0	82	
i 1	159.26278911564626	0.2525	72	882	5	5	16	0	0	-1	0	0	0	3.0000003880832815	82	
i 1	159.48993197278912	0.2525	68	882	1	24	12	0	0	0	0	0	0	4.0	82	
i 1	159.7377551020408	1.01	75	68	7	1	15	2	0	-2	2	0	0	2.9121610345324758	82	
i 1	159.7491836734694	0.2525	69	882	4	5	8	0	0	-1	0	0	0	3.0000003880832815	82	
i 1	159.99809523809523	0.2525	75	882	2	24	3	2	0	-2	2	0	0	5.912161034532476	82	
i 1	159.99863945578232	0.2525	71	882	4	4	10	2	0	-1	2	0	0	4.0	82	
i 1	160.00408163265305	0.2525	72	384	6	5	3	0	0	-1	0	0	0	3.0000003880832815	82	
i 1	160.23721088435374	0.2525	72	384	4	1	9	8	0	-2	8	0	0	2.9121610345324758	82	
i 1	160.2382993197279	0.505	71	68	5	2	7	2	0	-1	2	0	0	4.0	82	
i 1	160.26115646258503	0.2525	74	384	5	9	5	8	0	-1	8	0	0	3.0000000000000004	82	
i 1	160.50625850340137	0.2525	72	882	6	5	1	0	0	0	0	0	0	3.0000003880832815	83	
i 1	160.74591836734695	0.7575000000000001	76	384	2	24	6	17	0	1	17	0	0	7.3515931968829795	84	
i 1	160.7491836734694	0.2525	76	1086	3	20	15	16	0	2	16	0	0	3.3515931968829795	84	
i 1	160.753537414966	6.0600000000000005	67	1086	6	17	3	0	0	1	0	0	0	2.31872071921609	84	
i 1	160.75843537414966	0.7575000000000001	67	384	4	19	5	5	0	1	5	0	0	2.31872071921609	84	
i 1	160.76061224489797	1.7675	77	1086	6	5	1	16	0	1	16	0	0	3.0000003880832815	84	
i 1	160.7617006802721	0.7575000000000001	67	384	4	19	4	0	0	1	0	0	0	2.31872071921609	84	
i 1	160.76278911564626	1.5150000000000001	72	1086	4	2	7	0	0	0	0	0	0	4.0	84	
i 1	160.98938775510203	0.505	69	384	4	4	7	0	0	0	0	0	0	4.0	84	
i 1	160.996462585034	0.505	76	384	3	20	9	16	0	2	16	0	0	3.3515931968829795	84	
i 1	161.01333333333332	2.02	72	770	6	1	14	1	0	-1	1	0	0	2.9121610345324758	84	
i 1	161.2491836734694	0.2525	69	384	3	1	10	1	0	0	1	0	0	2.9121610345324758	85	
i 1	161.26278911564626	0.2525	72	384	6	1	7	2	0	-2	2	0	0	2.9121610345324758	85	
i 1	161.48884353741497	0.7575000000000001	60	152	5	18	15	5	0	1	5	0	0	2.31872071921609	86	
i 1	161.49591836734695	0.505	72	383	3	24	14	1	0	0	1	0	0	5.912161034532476	86	
i 1	161.49700680272107	0.505	69	152	7	1	2	1	0	0	1	0	0	2.9121610345324758	86	
i 1	161.50027210884355	0.7575000000000001	77	152	6	5	6	17	0	2	17	0	0	3.0000003880832815	86	
i 1	161.50244897959183	0.505	69	152	6	9	11	0	0	-1	0	0	0	3.0000000000000004	86	
i 1	161.50843537414966	0.7575000000000001	67	383	4	19	5	0	0	1	0	0	0	2.31872071921609	86	
i 1	161.51006802721088	0.2525	77	1086	6	5	8	16	0	1	16	0	0	3.0000003880832815	86	
i 1	161.51278911564626	2.2725	67	383	4	19	12	0	0	0	0	0	0	2.31872071921609	86	
i 1	161.98993197278912	0.2525	72	383	4	4	3	0	0	0	0	0	0	4.0	86	
i 1	161.99374149659863	0.2525	72	383	3	1	3	1	0	0	1	0	0	2.9121610345324758	86	
i 1	162.00680272108843	0.7575000000000001	76	383	2	20	9	17	0	2	17	0	0	3.3515931968829795	86	
i 1	162.23938775510203	3.0300000000000002	67	383	4	19	11	0	0	1	0	0	0	2.31872071921609	86	
i 1	162.24102040816325	0.2525	72	1086	4	1	10	0	0	0	0	0	0	2.9121610345324758	86	
i 1	162.24156462585034	5.3025	60	1086	6	17	11	0	0	0	0	0	0	2.31872071921609	86	
i 1	162.24700680272107	0.7575000000000001	69	770	4	24	6	1	0	-1	1	0	0	5.912161034532476	86	
i 1	162.2491836734694	0.2525	72	383	5	3	15	0	0	-1	0	0	0	4.0	86	
i 1	162.25680272108843	0.2525	72	383	3	24	15	1	0	0	1	0	0	5.912161034532476	86	
i 1	162.26115646258503	0.2525	73	152	3	24	10	16	0	1	16	0	0	7.3515931968829795	86	
i 1	162.49863945578232	1.2625	72	1086	6	1	6	1	0	-1	1	0	0	2.9121610345324758	86	
i 1	162.5008163265306	2.02	72	770	4	4	5	0	0	0	0	0	0	4.0	86	
i 1	162.5073469387755	0.505	74	383	5	5	4	16	0	1	16	0	0	3.0000003880832815	86	
i 1	162.51061224489797	0.2525	74	383	5	5	9	17	0	1	17	0	0	3.0000003880832815	86	
i 1	162.7404761904762	2.7775	73	152	3	20	11	17	0	1	17	0	0	3.3515931968829795	86	
i 1	162.98666666666668	0.2525	72	1086	4	1	2	0	0	0	0	0	0	2.9121610345324758	86	
i 1	162.9877551020408	0.2525	73	152	3	24	16	16	0	1	16	0	0	7.3515931968829795	86	
i 1	162.99537414965985	0.2525	72	383	6	1	11	1	0	0	1	0	0	2.9121610345324758	86	
i 1	163.24156462585034	0.2525	69	152	7	1	9	1	0	0	1	0	0	2.9121610345324758	86	
i 1	163.26006802721088	0.2525	77	1086	6	5	11	16	0	1	16	0	0	3.0000003880832815	86	
i 1	163.49374149659863	0.2525	72	1086	4	1	7	0	0	0	0	0	0	2.9121610345324758	87	
i 1	163.49428571428572	2.02	69	770	4	24	5	1	0	-1	1	0	0	5.912161034532476	87	
i 1	163.5073469387755	0.505	72	770	6	1	15	1	0	-1	1	0	0	2.9121610345324758	87	
i 1	163.74863945578232	6.0600000000000005	60	770	6	17	10	5	0	0	5	0	0	2.31872071921609	87	
i 1	163.75027210884355	0.2525	76	770	3	20	15	17	0	1	17	0	0	3.3515931968829795	87	
i 1	163.75190476190477	0.2525	73	1086	3	20	13	17	0	2	17	0	0	3.3515931968829795	87	
i 1	163.75625850340137	0.7575000000000001	72	1086	4	1	3	1	0	-1	1	0	0	2.9121610345324758	87	
i 1	163.76006802721088	0.2525	69	152	6	9	13	0	0	-1	0	0	0	3.0000000000000004	87	
i 1	163.99374149659863	0.2525	76	383	2	20	9	17	0	1	17	0	0	3.3515931968829795	87	
i 1	164.01333333333332	2.2725	77	1086	6	5	11	16	0	1	16	0	0	3.0000003880832815	87	
i 1	164.01333333333332	0.2525	76	152	3	20	2	16	0	1	16	0	0	3.3515931968829795	87	
i 1	164.2404761904762	0.2525	72	1086	4	1	15	0	0	0	0	0	0	2.9121610345324758	87	
i 1	164.26006802721088	0.2525	77	1086	6	5	11	16	0	1	16	0	0	3.0000003880832815	87	
i 1	164.49537414965985	0.505	69	152	4	9	2	1	0	0	1	0	0	3.0000000000000004	87	
i 1	164.49700680272107	0.2525	77	770	6	5	5	17	0	2	17	0	0	3.0000003880832815	87	
i 1	164.49809523809523	0.2525	72	770	6	1	12	1	0	-1	1	0	0	2.9121610345324758	87	
i 1	164.49809523809523	0.505	74	383	5	5	12	16	0	1	16	0	0	3.0000003880832815	87	
i 1	164.7421088435374	0.2525	73	152	3	24	3	16	0	1	16	0	0	7.3515931968829795	87	
i 1	164.74863945578232	0.505	74	383	5	5	3	17	0	1	17	0	0	3.0000003880832815	87	
i 1	164.99156462585034	1.2625	72	383	5	3	3	0	0	-1	0	0	0	4.0	87	
i 1	165.0073469387755	0.2525	76	383	2	24	5	17	0	1	17	0	0	7.3515931968829795	87	
i 1	165.01061224489797	0.2525	72	770	6	1	8	1	0	-1	1	0	0	2.9121610345324758	87	
i 1	165.0117006802721	0.2525	77	152	6	5	14	16	0	1	16	0	0	3.0000003880832815	87	
i 1	165.2421088435374	5.3025	67	770	6	17	13	5	0	0	5	0	0	2.31872071921609	87	
i 1	165.24755102040817	2.2725	77	1086	6	5	8	16	0	1	16	0	0	3.0000003880832815	87	
i 1	165.253537414966	0.2525	69	152	4	9	5	0	0	-1	0	0	0	3.0000000000000004	87	
i 1	165.4882993197279	0.2525	72	1086	6	1	12	0	0	0	0	0	0	2.9121610345324758	87	
i 1	165.48938775510203	0.2525	77	152	6	5	1	17	0	2	17	0	0	3.0000003880832815	87	
i 1	165.50299319727893	0.2525	72	770	4	4	3	0	0	0	0	0	0	4.0	87	
i 1	165.5051700680272	0.505	74	383	5	5	4	16	0	1	16	0	0	3.0000003880832815	87	
i 1	165.51061224489797	0.2525	72	1086	5	2	16	0	0	0	0	0	0	4.0	87	
i 1	165.7426530612245	0.2525	72	383	6	1	2	1	0	0	1	0	0	2.9121610345324758	87	
i 1	165.99156462585034	1.5150000000000001	77	770	6	5	13	17	0	2	17	0	0	3.0000003880832815	87	
i 1	165.9926530612245	1.5150000000000001	72	1086	5	2	8	0	0	0	0	0	0	4.0	87	
i 1	166.2595238095238	1.2625	73	152	3	20	3	16	0	1	16	0	0	3.3515931968829795	87	
i 1	166.49156462585034	0.7575000000000001	76	152	3	20	1	16	0	2	16	0	0	3.3515931968829795	87	
i 1	166.49863945578232	0.2525	72	383	4	4	2	0	0	0	0	0	0	4.0	87	
i 1	166.5095238095238	0.2525	74	770	6	5	8	17	0	2	17	0	0	3.0000003880832815	87	
i 1	166.7404761904762	0.7575000000000001	60	152	5	18	11	0	0	0	0	0	0	2.31872071921609	87	
i 1	166.7508163265306	0.7575000000000001	67	1086	6	17	4	0	0	1	0	0	0	2.31872071921609	87	
i 1	166.76278911564626	0.7575000000000001	73	383	2	24	15	16	0	1	16	0	0	7.3515931968829795	87	
i 1	166.76333333333332	0.505	77	152	6	5	2	17	0	2	17	0	0	3.0000003880832815	87	
i 1	167.0073469387755	0.2525	69	152	4	9	8	1	0	0	1	0	0	3.0000000000000004	87	
i 1	167.0095238095238	0.505	72	1086	6	1	14	0	0	0	0	0	0	2.9121610345324758	87	
i 1	167.2382993197279	0.2525	74	383	5	5	4	17	0	1	17	0	0	3.0000003880832815	87	
i 1	167.2448299319728	0.2525	73	383	2	24	1	16	0	2	16	0	0	7.3515931968829795	87	
i 1	167.24537414965985	0.2525	72	383	3	3	2	0	0	-1	0	0	0	4.0	87	
i 1	167.48938775510203	2.2725	73	68	1	24	1	16	0	248	16	308	0	7.3515931968829795	88	
i 1	167.4921088435374	3.0300000000000002	60	68	7	17	5	5	0	1	5	0	0	2.31872071921609	88	
i 1	167.49319727891157	2.2725	69	68	6	2	2	1	0	0	1	0	0	4.0	88	
i 1	167.49755102040817	0.7575000000000001	60	68	7	17	8	0	0	1	0	0	0	2.31872071921609	88	
i 1	167.49809523809523	1.5150000000000001	76	454	2	24	16	16	0	2	16	0	0	7.3515931968829795	88	
i 1	167.4991836734694	0.2525	73	68	3	20	2	16	0	2	16	0	0	3.3515931968829795	88	
i 1	167.49972789115645	5.3025	67	68	5	18	7	5	0	1	5	0	0	2.31872071921609	88	
i 1	167.50027210884355	0.2525	74	68	6	5	4	16	0	2	16	0	0	3.0000003880832815	88	
i 1	167.50571428571428	1.01	72	68	6	2	2	0	0	0	0	0	0	4.0	88	
i 1	167.51006802721088	1.2625	76	454	2	24	3	16	0	2	16	0	0	7.3515931968829795	88	
i 1	167.74591836734695	0.505	72	68	7	1	15	0	0	-1	0	0	0	2.9121610345324758	89	
i 1	168.0073469387755	0.2525	77	454	5	5	8	16	0	1	16	0	0	3.0000003880832815	89	
i 1	168.23721088435374	0.505	74	68	6	5	5	17	0	2	17	0	0	3.0000003880832815	90	
i 1	168.24319727891157	6.0600000000000005	60	68	5	18	10	0	0	1	0	0	0	2.31872071921609	90	
i 1	168.25136054421768	0.505	72	68	4	1	6	0	0	-1	0	0	0	2.9121610345324758	90	
i 1	168.25136054421768	1.5150000000000001	76	68	3	20	16	16	0	2	16	0	0	3.3515931968829795	90	
i 1	168.25897959183675	2.2725	60	68	7	17	15	0	0	1	0	0	0	2.31872071921609	90	
i 1	168.4904761904762	0.7575000000000001	77	454	5	5	4	16	0	1	16	0	0	3.0000003880832815	91	
i 1	168.51333333333332	0.2525	72	68	7	1	10	0	0	-1	0	0	0	2.9121610345324758	91	
i 1	168.7491836734694	0.2525	69	454	4	24	6	1	0	0	1	0	0	5.912161034532476	91	
i 1	168.99700680272107	0.505	72	68	5	9	9	0	0	-1	0	0	0	3.0000000000000004	91	
i 1	169.00027210884355	0.505	72	770	6	1	11	1	0	-1	1	0	0	2.9121610345324758	91	
i 1	169.00408163265305	0.2525	69	454	3	3	9	0	0	0	0	0	0	4.0	91	
i 1	169.25408163265305	0.2525	74	68	6	5	14	16	0	2	16	0	0	3.0000003880832815	91	
i 1	169.49374149659863	1.01	72	68	6	2	12	0	0	0	0	0	0	4.0	91	
i 1	169.50897959183675	0.2525	73	68	3	20	8	16	0	2	16	0	0	3.3515931968829795	91	
i 1	169.73666666666668	0.505	69	770	5	3	7	0	0	-1	0	0	0	4.0	91	
i 1	169.73666666666668	1.5150000000000001	73	68	3	20	4	16	0	2	16	0	0	7.6300665958838945	91	
i 1	169.74374149659863	0.7575000000000001	60	770	6	17	16	5	0	0	5	0	0	2.31872071921609	91	
i 1	169.7448299319728	0.2525	69	770	4	24	3	1	0	-1	1	0	0	5.912161034532476	91	
i 1	169.75680272108843	0.505	77	454	5	5	7	16	0	1	16	0	0	3.0000003880832815	91	
i 1	169.76278911564626	0.7575000000000001	60	454	4	19	3	0	0	1	0	0	0	2.31872071921609	91	
i 1	169.99319727891157	0.2525	76	68	4	20	16	16	0	2	16	0	0	7.6300665958838945	91	
i 1	170.00244897959183	0.505	69	68	6	2	15	1	0	0	1	0	0	4.0	91	
i 1	170.2421088435374	0.505	73	68	3	20	13	16	0	2	16	0	0	7.6300665958838945	91	
i 1	170.24428571428572	0.505	76	68	3	20	8	16	0	2	16	0	0	7.6300665958838945	91	
i 1	170.26115646258503	0.2525	77	68	7	5	15	17	0	1	17	0	0	3.0000003880832815	91	
i 1	170.48938775510203	5.05	67	566	4	19	15	5	0	0	5	0	0	2.31872071921609	92	
i 1	170.48993197278912	0.505	74	566	6	5	16	16	0	1	16	0	0	3.0000003880832815	92	
i 1	170.4926530612245	5.05	67	882	6	17	2	5	0	1	5	0	0	2.31872071921609	92	
i 1	170.49319727891157	0.7575000000000001	72	882	5	2	2	0	0	-1	0	0	0	4.0	92	
i 1	170.49319727891157	5.05	67	882	6	17	9	5	0	1	5	0	0	2.31872071921609	92	
i 1	170.496462585034	0.2525	72	68	5	9	13	1	0	-1	1	0	0	3.0000000000000004	92	
i 1	170.49863945578232	0.505	69	882	6	1	14	1	0	-1	1	0	0	2.9121610345324758	92	
i 1	170.5073469387755	0.7575000000000001	74	882	6	5	15	17	0	2	17	0	0	3.0000003880832815	92	
i 1	170.5095238095238	1.2625	69	566	4	24	4	0	0	0	0	0	0	5.912161034532476	92	
i 1	170.51115646258503	0.7575000000000001	67	566	6	17	12	5	0	0	5	0	0	2.31872071921609	92	
i 1	170.5117006802721	4.2925	60	566	6	17	12	5	0	0	5	0	0	2.31872071921609	92	
i 1	170.74428571428572	0.2525	76	882	3	20	8	16	0	2	16	0	0	7.6300665958838945	92	
i 1	170.7491836734694	1.5150000000000001	77	566	6	5	3	16	0	2	16	0	0	3.0000003880832815	92	
i 1	170.75625850340137	0.2525	72	566	3	4	2	1	0	-1	1	0	0	4.0	92	
i 1	170.75897959183675	0.2525	73	882	3	20	9	17	0	2	17	0	0	7.6300665958838945	92	
i 1	170.98938775510203	2.525	69	566	6	1	14	1	0	-1	1	0	0	2.9121610345324758	92	
i 1	171.0008163265306	0.2525	76	68	3	20	7	16	0	1	16	0	0	7.6300665958838945	92	
i 1	171.00462585034015	0.2525	74	882	6	5	5	17	0	2	17	0	0	3.0000003880832815	92	
i 1	171.01278911564626	1.5150000000000001	76	68	3	20	9	16	0	1	16	0	0	7.6300665958838945	92	
i 1	171.2421088435374	0.2525	74	566	6	5	4	16	0	1	16	0	0	3.0000003880832815	92	
i 1	171.2426530612245	0.2525	76	566	2	24	6	17	0	2	17	0	0	11.630066595883894	92	
i 1	171.25299319727893	4.2925	60	566	4	19	14	0	0	0	0	0	0	2.31872071921609	92	
i 1	171.253537414966	3.535	67	566	6	17	13	5	0	0	5	0	0	2.31872071921609	92	
i 1	171.49972789115645	1.2625	69	566	4	4	6	0	0	0	0	0	0	4.0	92	
i 1	171.7448299319728	1.7675	73	68	3	24	6	16	0	1	16	0	0	11.630066595883894	92	
i 1	171.74537414965985	1.2625	76	566	2	24	3	17	0	2	17	0	0	11.630066595883894	92	
i 1	171.7551700680272	0.2525	74	68	6	5	5	17	0	2	17	0	0	3.0000003880832815	92	
i 1	171.76278911564626	0.7575000000000001	72	566	3	4	2	1	0	-1	1	0	0	4.0	92	
i 1	172.24591836734695	0.505	72	882	5	2	7	0	0	-1	0	0	0	4.0	92	
i 1	172.2617006802721	0.505	72	882	6	1	3	1	0	-1	1	0	0	2.9121610345324758	92	
i 1	172.26333333333332	0.2525	72	68	4	1	6	1	0	0	1	0	0	2.9121610345324758	92	
i 1	172.50680272108843	0.2525	72	68	5	9	3	1	0	-1	1	0	0	3.0000000000000004	92	
i 1	172.5078911564626	0.2525	69	882	6	2	1	1	0	0	1	0	0	4.0	92	
i 1	172.51006802721088	2.2725	69	566	4	24	1	0	0	0	0	0	0	5.912161034532476	92	
i 1	172.74156462585034	2.7775	67	68	5	18	9	5	0	1	5	0	0	2.31872071921609	92	
i 1	172.75299319727893	0.2525	72	566	3	1	1	1	0	-1	1	0	0	2.9121610345324758	92	
i 1	172.753537414966	0.2525	72	566	4	4	13	1	0	-1	1	0	0	4.0	92	
i 1	173.00571428571428	0.2525	74	68	6	5	10	16	0	2	16	0	0	3.0000003880832815	92	
i 1	173.00680272108843	0.2525	73	566	3	20	7	16	0	1	16	0	0	7.6300665958838945	92	
i 1	173.0078911564626	0.505	74	566	6	5	1	16	0	1	16	0	0	3.0000003880832815	92	
i 1	173.00897959183675	1.01	76	566	2	24	4	16	0	2	16	0	0	11.630066595883894	92	
i 1	173.0117006802721	0.2525	76	566	3	24	16	17	0	2	17	0	0	11.630066595883894	92	
i 1	173.2377551020408	0.7575000000000001	73	566	2	20	5	16	0	1	16	0	0	7.6300665958838945	92	
i 1	173.25625850340137	0.2525	72	68	5	9	8	1	0	-1	1	0	0	3.0000000000000004	92	
i 1	173.2578911564626	0.2525	76	68	1	20	8	17	0	1	17	0	0	7.6300665958838945	92	
i 1	173.26061224489797	0.2525	72	566	5	3	3	0	0	0	0	0	0	4.0	92	
i 1	173.2617006802721	0.505	74	68	6	5	3	17	0	2	17	0	0	3.0000003880832815	92	
i 1	173.4948299319728	1.2625	73	68	1	20	16	16	0	1	16	0	0	7.6300665958838945	92	
i 1	173.753537414966	0.2525	72	68	6	1	2	0	0	-1	0	0	0	2.9121610345324758	92	
i 1	173.99591836734695	0.2525	77	566	5	5	5	17	0	2	17	0	0	3.0000003880832815	92	
i 1	174.0078911564626	0.2525	72	68	5	9	8	0	0	-1	0	0	0	3.0000000000000004	92	
i 1	174.00843537414966	1.01	72	882	6	1	6	1	0	-1	1	0	0	2.9121610345324758	92	
i 1	174.2382993197279	1.2625	74	882	6	5	16	17	0	2	17	0	0	3.0000003880832815	92	
i 1	174.24972789115645	1.2625	60	68	5	18	1	0	0	1	0	0	0	2.31872071921609	92	
i 1	174.2573469387755	0.2525	69	566	6	1	12	1	0	-1	1	0	0	2.9121610345324758	92	
i 1	174.50136054421768	0.2525	72	566	5	1	3	1	0	-1	1	0	0	2.9121610345324758	93	
i 1	174.5122448979592	1.01	72	882	6	2	10	0	0	-1	0	0	0	4.0	93	
i 1	174.7377551020408	0.7575000000000001	60	384	6	17	3	0	0	1	0	0	0	2.31872071921609	94	
i 1	174.73938775510203	0.2525	72	566	4	3	1	1	0	-1	1	0	0	4.0	94	
i 1	174.7573469387755	0.7575000000000001	67	384	6	17	8	0	0	0	0	0	0	2.31872071921609	94	
i 1	174.7578911564626	0.2525	76	882	1	20	9	16	0	2	16	0	0	7.6300665958838945	94	
i 1	174.7622448979592	0.7575000000000001	72	384	4	24	13	0	0	0	0	0	0	5.912161034532476	94	
i 1	175.00027210884355	0.505	69	882	6	1	10	1	0	-1	1	0	0	2.9121610345324758	94	
i 1	175.00408163265305	0.2525	76	68	1	20	3	17	0	2	17	0	0	7.6300665958838945	94	
i 1	175.01333333333332	0.505	73	68	3	24	12	16	0	1	16	0	0	11.630066595883894	94	
i 1	175.25299319727893	0.2525	69	882	6	2	2	1	0	0	1	0	0	4.0	95	
i 1	175.4877551020408	1.7675	60	1084	4	18	12	0	0	1	0	0	0	2.31872071921609	96	
i 1	175.49374149659863	1.7675	67	270	6	17	10	0	0	0	0	0	0	2.31872071921609	96	
i 1	175.49428571428572	1.5150000000000001	69	270	5	24	6	0	0	0	0	0	0	5.912161034532476	96	
i 1	175.49591836734695	1.7675	60	586	6	17	12	0	0	0	0	0	0	2.31872071921609	96	
i 1	175.50244897959183	1.7675	67	1084	4	18	2	0	0	1	0	0	0	2.31872071921609	96	
i 1	175.50625850340137	1.7675	67	270	6	17	8	0	0	1	0	0	0	2.31872071921609	96	
i 1	175.50680272108843	0.2525	60	586	6	17	16	5	0	1	5	0	0	2.31872071921609	96	
i 1	175.50897959183675	1.7675	67	1084	4	19	2	5	0	0	5	0	0	2.31872071921609	96	
i 1	175.5095238095238	0.2525	60	1084	4	19	8	0	0	1	0	0	0	2.31872071921609	96	
i 1	175.73993197278912	1.2625	76	1084	2	24	4	16	0	2	16	0	0	10.402173846428589	96	
i 1	175.74428571428572	1.5150000000000001	60	1084	4	19	13	0	0	1	0	0	0	2.31872071921609	96	
i 1	175.7448299319728	1.5150000000000001	60	586	6	17	12	5	0	1	5	0	0	2.31872071921609	96	
i 1	175.74700680272107	1.5150000000000001	73	1084	1	24	3	17	0	252	17	307	0	10.402173846428589	96	
i 1	175.76278911564626	0.505	76	1084	2	20	15	16	0	1	16	0	0	6.402173846428589	96	
i 1	176.00680272108843	0.505	72	1084	5	1	8	0	0	0	0	0	0	2.9121610345324758	96	
i 1	176.01333333333332	0.2525	69	586	6	1	3	1	0	0	1	0	0	2.9121610345324758	96	
i 1	176.2573469387755	0.2525	77	1084	5	5	7	16	0	1	16	0	0	3.0000003880832815	96	
i 1	176.25897959183675	0.7575000000000001	74	586	6	5	6	17	0	1	17	0	0	3.0000003880832815	96	
i 1	176.4926530612245	0.7575000000000001	76	1084	2	20	7	16	0	1	16	0	0	6.402173846428589	96	
i 1	176.496462585034	0.7575000000000001	77	586	6	5	13	17	0	1	17	0	0	3.0000003880832815	96	
i 1	176.49755102040817	0.2525	72	586	6	1	10	1	0	-1	1	0	0	2.9121610345324758	96	
i 1	176.74863945578232	0.2525	76	586	1	20	5	17	0	2	17	0	0	6.402173846428589	96	
i 1	176.7578911564626	0.2525	69	1084	4	24	8	0	0	0	0	0	0	5.912161034532476	96	
i 1	176.75897959183675	0.2525	76	586	1	20	11	16	0	1	16	0	0	6.402173846428589	96	
i 1	176.99972789115645	0.2525	72	1084	4	9	5	0	0	0	0	0	0	3.0000000000000004	96	
i 1	177.23666666666668	6.0600000000000005	67	1084	4	18	12	0	0	1	0	0	0	0.24250072243644835	96	
i 1	177.2382993197279	1.2625	69	270	6	1	10	0	0	-1	0	0	0	0.43817134410573777	96	
i 1	177.23993197278912	3.535	77	586	6	5	11	17	0	1	17	0	0	3.0000001428146477	96	
i 1	177.24156462585034	4.2925	60	1084	4	19	8	0	0	1	0	0	0	0.24250072243644835	96	
i 1	177.24319727891157	5.05	60	586	6	17	14	5	0	1	5	0	0	0.24250072243644835	96	
i 1	177.24374149659863	2.2725	69	270	5	24	16	0	0	0	0	0	0	3.4381713441057378	96	
i 1	177.24428571428572	1.5150000000000001	67	270	6	17	7	0	0	1	0	0	0	0.24250072243644835	96	
i 1	177.24809523809523	4.545	60	1084	4	18	9	0	0	1	0	0	0	0.24250072243644835	96	
i 1	177.24863945578232	0.2525	74	1084	5	5	3	17	0	1	17	0	0	3.0000001428146477	96	
i 1	177.25136054421768	0.2525	72	1084	4	9	2	0	0	0	0	0	0	7.0	96	
i 1	177.25136054421768	5.05	60	586	6	17	15	0	0	0	0	0	0	0.24250072243644835	96	
i 1	177.25190476190477	0.505	69	270	5	4	3	0	0	-1	0	0	0	8.0	96	
i 1	177.26061224489797	3.0300000000000002	67	270	6	17	1	0	0	0	0	0	0	0.24250072243644835	96	
i 1	177.26115646258503	1.5150000000000001	76	1084	2	20	3	16	0	1	16	0	0	1.4798927358166027	96	
i 1	177.26278911564626	4.2925	67	1084	4	19	2	5	0	0	5	0	0	0.24250072243644835	96	
i 1	177.73884353741497	0.2525	72	1084	4	4	10	1	0	0	1	0	0	8.0	97	
i 1	177.74591836734695	0.505	69	586	6	1	13	1	0	0	1	0	0	0.43817134410573777	97	
i 1	177.74700680272107	0.2525	69	1084	4	3	4	1	0	-1	1	0	0	8.0	97	
i 1	177.7578911564626	0.2525	74	270	7	5	6	17	0	1	17	0	0	3.0000001428146477	97	
i 1	177.99428571428572	0.2525	69	270	6	3	5	1	0	0	1	0	0	8.0	97	
i 1	177.996462585034	0.505	69	1084	5	9	12	0	0	-1	0	0	0	7.0	97	
i 1	178.00190476190477	0.2525	77	1084	5	5	15	16	0	1	16	0	0	3.0000001428146477	97	
i 1	178.00897959183675	0.2525	74	1084	4	5	10	16	0	2	16	0	0	3.0000001428146477	97	
i 1	178.23721088435374	0.2525	77	1084	6	5	6	17	0	2	17	0	0	3.0000001428146477	97	
i 1	178.24102040816325	1.2625	69	586	6	2	12	1	0	0	1	0	0	8.0	97	
i 1	178.2421088435374	1.5150000000000001	74	270	7	5	11	17	0	1	17	0	0	3.0000001428146477	97	
i 1	178.2491836734694	0.2525	72	1084	5	1	5	0	0	0	0	0	0	0.43817134410573777	97	
i 1	178.49537414965985	0.2525	69	1084	4	3	16	1	0	-1	1	0	0	8.0	97	
i 1	178.49863945578232	0.505	77	270	7	5	3	17	0	1	17	0	0	3.0000001428146477	97	
i 1	178.5073469387755	0.2525	72	1084	5	1	6	1	0	-1	1	0	0	0.43817134410573777	97	
i 1	178.7573469387755	3.535	67	270	7	17	8	0	0	1	0	0	0	0.24250072243644835	97	
i 1	179.00571428571428	0.2525	77	1084	4	5	4	17	0	2	17	0	0	3.0000001428146477	97	
i 1	179.01115646258503	2.525	72	586	5	1	6	1	0	-1	1	0	0	0.43817134410573777	97	
i 1	179.49319727891157	0.505	69	1084	4	24	10	0	0	0	0	0	0	3.4381713441057378	97	
i 1	179.50843537414966	0.7575000000000001	74	1084	5	5	15	17	0	1	17	0	0	3.0000001428146477	97	
i 1	179.5095238095238	0.2525	69	1084	4	3	7	1	0	-1	1	0	0	8.0	97	
i 1	179.5122448979592	0.2525	72	1084	5	1	16	1	0	-1	1	0	0	0.43817134410573777	97	
i 1	179.75897959183675	0.505	69	586	5	1	13	1	0	0	1	0	0	0.43817134410573777	97	
i 1	179.9877551020408	0.2525	76	1084	2	24	10	16	0	2	16	0	0	5.479892735816603	97	
i 1	180.2377551020408	1.2625	76	1084	1	24	10	16	0	252	16	307	0	5.479892735816603	97	
i 1	180.25027210884355	2.02	67	270	7	17	13	0	0	0	0	0	0	0.24250072243644835	97	
i 1	180.496462585034	0.505	69	1084	5	9	9	0	0	-1	0	0	0	7.0	97	
i 1	180.49755102040817	0.2525	74	586	5	5	10	17	0	1	17	0	0	3.0000001428146477	97	
i 1	180.5078911564626	0.2525	69	586	5	1	8	1	0	0	1	0	0	0.43817134410573777	97	
i 1	180.73666666666668	0.2525	77	1084	4	5	2	16	0	1	16	0	0	3.0000001428146477	97	
i 1	180.746462585034	0.2525	74	1084	6	5	8	16	0	2	16	0	0	3.0000001428146477	97	
i 1	180.9882993197279	0.2525	69	270	5	1	3	0	0	-1	0	0	0	0.43817134410573777	97	
i 1	181.00843537414966	0.2525	72	1084	4	4	10	1	0	0	1	0	0	8.0	97	
i 1	181.00843537414966	0.2525	76	586	1	20	3	16	0	1	16	0	0	1.4798927358166027	97	
i 1	181.25244897959183	0.2525	69	586	5	1	11	1	0	0	1	0	0	0.43817134410573777	97	
i 1	181.25843537414966	0.7575000000000001	69	1084	5	9	11	0	0	-1	0	0	0	7.0	97	
i 1	181.26061224489797	0.505	69	270	5	4	14	0	0	-1	0	0	0	8.0	97	
i 1	181.4926530612245	0.7575000000000001	67	853	4	19	5	0	0	1	0	0	0	0.24250072243644835	98	
i 1	181.49537414965985	0.7575000000000001	60	853	4	19	6	5	0	0	5	0	0	0.24250072243644835	98	
i 1	181.49755102040817	0.2525	73	586	1	20	10	16	0	2	16	0	0	1.4798927358166027	98	
i 1	181.49863945578232	0.2525	74	853	4	5	11	16	0	2	16	0	0	3.0000001428146477	98	
i 1	181.50136054421768	0.2525	76	586	1	20	11	17	0	2	17	0	0	1.4798927358166027	98	
i 1	181.50299319727893	0.505	74	1084	6	5	4	16	0	2	16	0	0	3.0000001428146477	98	
i 1	181.503537414966	0.505	69	270	5	1	2	0	0	-1	0	0	0	0.43817134410573777	98	
i 1	181.7426530612245	7.07	60	1084	4	18	5	0	0	1	0	0	0	0.24250072243644835	99	
i 1	181.76061224489797	0.505	69	270	5	24	2	0	0	0	0	0	0	3.4381713441057378	99	
i 1	181.98993197278912	0.2525	69	586	6	2	11	1	0	0	1	0	0	8.0	99	
i 1	181.99319727891157	0.2525	77	586	5	5	4	17	0	1	17	0	0	3.0000001428146477	99	
i 1	182.23884353741497	4.04	60	768	4	19	1	5	0	1	5	0	0	0.24250072243644835	100	
i 1	182.2404761904762	5.555	60	1084	6	17	15	0	0	0	0	0	0	0.24250072243644835	100	
i 1	182.24374149659863	7.07	67	382	6	17	10	5	0	1	5	0	0	0.24250072243644835	100	
i 1	182.24700680272107	7.3225	67	382	6	17	4	0	0	0	0	0	0	0.24250072243644835	100	
i 1	182.2491836734694	1.2625	74	1084	5	5	11	16	0	1	16	0	0	3.0000001428146477	100	
i 1	182.25136054421768	2.525	67	768	4	19	8	0	0	0	0	0	0	0.24250072243644835	100	
i 1	182.25136054421768	0.2525	77	1084	5	5	2	17	0	2	17	0	0	3.0000001428146477	100	
i 1	182.253537414966	0.2525	72	1084	6	2	14	1	0	-1	1	0	0	8.0	100	
i 1	182.25843537414966	4.04	60	1084	6	17	9	5	0	1	5	0	0	0.24250072243644835	100	
i 1	182.4877551020408	0.505	74	768	4	5	3	17	0	2	17	0	0	3.0000001428146477	101	
i 1	182.49809523809523	0.2525	77	1084	6	5	5	17	0	2	17	0	0	3.0000001428146477	101	
i 1	182.74537414965985	0.2525	69	1084	5	1	1	0	0	0	0	0	0	0.43817134410573777	101	
i 1	182.75897959183675	0.505	72	1084	5	1	5	1	0	-1	1	0	0	0.43817134410573777	101	
i 1	182.99156462585034	1.7675	77	382	6	5	8	17	0	2	17	0	0	3.0000001428146477	101	
i 1	183.23884353741497	1.5150000000000001	72	1084	6	2	4	1	0	-1	1	0	0	8.0	101	
i 1	183.253537414966	5.555	67	1084	4	18	14	0	0	1	0	0	0	0.24250072243644835	101	
i 1	183.49972789115645	0.2525	69	1084	5	1	3	0	0	0	0	0	0	0.43817134410573777	101	
i 1	183.50190476190477	0.2525	77	1084	5	5	9	17	0	2	17	0	0	3.0000001428146477	101	
i 1	183.5078911564626	0.2525	74	768	6	5	13	17	0	2	17	0	0	3.0000001428146477	101	
i 1	184.24156462585034	0.505	72	1084	6	2	15	1	0	-1	1	0	0	8.0	101	
i 1	184.26278911564626	0.7575000000000001	76	768	1	24	12	16	0	252	16	307	0	4.0	101	
i 1	184.5078911564626	0.2525	72	382	5	3	9	1	0	0	1	0	0	8.0	102	
i 1	184.73993197278912	1.5150000000000001	69	382	4	4	3	1	0	-1	1	0	0	8.0	102	
i 1	184.74591836734695	0.2525	72	768	4	4	8	0	0	-1	0	0	0	8.0	102	
i 1	184.74863945578232	1.2625	72	1084	5	2	12	1	0	-1	1	0	0	8.0	102	
i 1	184.76115646258503	4.04	67	768	4	19	14	0	0	0	0	0	0	0.24250072243644835	102	
i 1	184.9921088435374	0.505	72	1084	4	1	16	0	0	0	0	0	0	0.43817134410573777	102	
i 1	184.99809523809523	2.02	74	382	5	5	1	16	0	1	16	0	0	3.0000001428146477	102	
i 1	185.0051700680272	0.2525	77	1084	6	5	13	17	0	2	17	0	0	3.0000001428146477	102	
i 1	185.51333333333332	0.2525	74	768	6	5	14	17	0	2	17	0	0	3.0000001428146477	102	
i 1	185.7404761904762	0.2525	69	1084	5	1	6	1	0	0	1	0	0	0.43817134410573777	102	
i 1	185.7421088435374	1.7675	72	382	4	24	6	0	0	-1	0	0	0	3.4381713441057378	102	
i 1	185.7448299319728	0.2525	74	768	6	5	5	16	0	1	16	0	0	3.0000001428146477	102	
i 1	185.99537414965985	1.7675	72	382	5	3	9	1	0	0	1	0	0	8.0	102	
i 1	186.24374149659863	0.2525	69	1084	6	1	8	1	0	0	1	0	0	0.43817134410573777	102	
i 1	186.24428571428572	2.525	60	768	4	19	11	5	0	1	5	0	0	0.24250072243644835	102	
i 1	186.25136054421768	0.2525	77	1084	5	5	12	17	0	2	17	0	0	3.0000001428146477	102	
i 1	186.25462585034015	2.525	60	1084	5	17	6	5	0	1	5	0	0	0.24250072243644835	102	
i 1	186.25625850340137	0.2525	74	768	6	5	13	17	0	2	17	0	0	3.0000001428146477	102	
i 1	186.49755102040817	0.505	72	382	5	1	3	0	0	-1	0	0	0	0.43817134410573777	102	
i 1	186.50680272108843	2.02	74	1084	5	5	7	16	0	1	16	0	0	3.0000001428146477	102	
i 1	186.5078911564626	0.2525	72	1084	4	1	8	0	0	0	0	0	0	0.43817134410573777	102	
i 1	186.73666666666668	0.505	69	768	5	3	5	1	0	0	1	0	0	8.0	102	
i 1	186.99863945578232	0.505	77	1084	6	5	5	17	0	2	17	0	0	3.0000001428146477	102	
i 1	187.74591836734695	1.01	60	1084	5	17	8	0	0	0	0	0	0	0.24250072243644835	102	
i 1	187.99102040816325	0.2525	72	1084	4	1	11	0	0	0	0	0	0	0.43817134410573777	102	
i 1	187.99102040816325	0.2525	77	382	5	5	15	17	0	2	17	0	0	3.0000001428146477	102	
i 1	187.99755102040817	1.2625	74	382	5	5	6	16	0	1	16	0	0	3.0000001428146477	102	
i 1	188.246462585034	0.505	69	1084	6	1	12	1	0	0	1	0	0	0.43817134410573777	102	
i 1	188.49156462585034	0.2525	77	1084	5	5	1	17	0	2	17	0	0	3.0000001428146477	103	
i 1	188.4926530612245	0.7575000000000001	69	382	4	4	8	1	0	-1	1	0	0	8.0	103	
i 1	188.49809523809523	0.2525	74	1084	4	5	9	16	0	2	16	0	0	3.0000001428146477	103	
i 1	188.7377551020408	6.8175	76	564	1	24	13	16	0	248	16	308	0	4.0	104	
i 1	188.73884353741497	2.02	67	880	5	17	16	5	0	0	5	0	0	0.24250072243644835	104	
i 1	188.74102040816325	3.535	67	880	4	18	5	0	0	1	0	0	0	0.24250072243644835	104	
i 1	188.7421088435374	1.01	77	880	5	5	10	17	0	2	17	0	0	3.0000001428146477	104	
i 1	188.74374149659863	0.2525	72	880	4	1	7	1	0	0	1	0	0	0.43817134410573777	104	
i 1	188.74972789115645	0.2525	69	880	5	9	1	1	0	-1	1	0	0	7.0	104	
i 1	188.75136054421768	0.505	67	880	5	17	9	5	0	0	5	0	0	0.24250072243644835	104	
i 1	188.75190476190477	6.8175	60	564	4	19	2	0	0	1	0	0	0	0.24250072243644835	104	
i 1	188.75625850340137	5.05	67	880	4	18	8	0	0	1	0	0	0	0.24250072243644835	104	
i 1	188.75680272108843	6.565	67	564	4	19	9	0	0	0	0	0	0	0.24250072243644835	104	
i 1	189.00571428571428	0.2525	69	564	4	1	4	0	0	-1	0	0	0	0.43817134410573777	104	
i 1	189.23993197278912	0.2525	77	880	4	5	16	17	0	2	17	0	0	3.0000001428146477	105	
i 1	189.24374149659863	0.2525	77	382	5	5	4	17	0	2	17	0	0	3.0000001428146477	105	
i 1	189.25299319727893	0.2525	69	382	4	4	15	1	0	-1	1	0	0	8.0	105	
i 1	189.25571428571428	0.2525	67	382	5	17	14	5	0	1	5	0	0	0.24250072243644835	105	
i 1	189.48666666666668	0.505	69	298	5	3	9	1	0	0	1	0	0	8.0	106	
i 1	189.4904761904762	1.7675	72	298	5	24	12	0	0	0	0	0	0	3.4381713441057378	106	
i 1	189.49591836734695	1.2625	67	298	7	17	13	5	0	1	5	0	0	0.24250072243644835	106	
i 1	189.5008163265306	0.2525	77	564	6	5	3	17	0	1	17	0	0	3.0000001428146477	106	
i 1	189.51061224489797	2.7775	67	298	5	17	3	0	0	0	0	0	0	0.24250072243644835	106	
i 1	189.98993197278912	0.505	76	298	1	24	1	17	0	1	17	0	0	4.0	106	
i 1	189.99700680272107	0.2525	69	880	5	9	13	0	0	0	0	0	0	7.0	106	
i 1	189.99809523809523	0.505	69	564	4	24	5	0	0	0	0	0	0	3.4381713441057378	106	
i 1	190.00244897959183	0.2525	69	564	5	3	11	0	0	0	0	0	0	8.0	106	
i 1	190.24700680272107	0.505	69	880	5	9	13	1	0	-1	1	0	0	7.0	106	
i 1	190.74700680272107	2.525	74	298	5	5	5	16	0	2	16	0	0	3.0000001428146477	106	
i 1	190.74972789115645	3.0300000000000002	67	298	5	17	7	5	0	1	5	0	0	0.24250072243644835	106	
i 1	190.75680272108843	1.5150000000000001	69	298	5	3	15	1	0	0	1	0	0	8.0	106	
i 1	190.9904761904762	0.505	69	880	4	2	7	0	0	0	0	0	0	8.0	106	
i 1	191.01061224489797	0.2525	77	880	4	5	8	17	0	2	17	0	0	3.0000001428146477	106	
i 1	191.23993197278912	0.7575000000000001	77	564	4	5	9	17	0	1	17	0	0	3.0000001428146477	106	
i 1	191.49591836734695	0.505	69	564	5	3	15	0	0	0	0	0	0	8.0	107	
i 1	191.5095238095238	0.505	69	880	4	1	14	0	0	0	0	0	0	0.43817134410573777	107	
i 1	191.7551700680272	0.505	77	880	4	5	2	17	0	2	17	0	0	3.0000001428146477	107	
i 1	191.99428571428572	0.2525	74	564	4	5	9	16	0	2	16	0	0	3.0000001428146477	107	
i 1	192.00843537414966	0.2525	72	298	5	4	4	1	0	-1	1	0	0	8.0	107	
i 1	192.01333333333332	1.7675	72	298	5	24	3	0	0	0	0	0	0	3.4381713441057378	107	
i 1	192.25299319727893	3.0300000000000002	67	880	4	18	12	0	0	1	0	0	0	0.24250072243644835	107	
i 1	192.25571428571428	0.2525	72	880	6	1	6	1	0	0	1	0	0	0.43817134410573777	107	
i 1	192.25680272108843	0.2525	69	880	4	2	11	0	0	-1	0	0	0	8.0	107	
i 1	192.51333333333332	0.505	69	880	5	1	3	0	0	0	0	0	0	0.43817134410573777	107	
i 1	192.74972789115645	0.2525	69	564	4	24	13	0	0	0	0	0	0	3.4381713441057378	107	
i 1	192.99972789115645	0.2525	69	880	6	1	12	0	0	0	0	0	0	0.43817134410573777	107	
i 1	193.00571428571428	0.2525	69	298	7	1	11	0	0	-1	0	0	0	0.43817134410573777	107	
i 1	193.00843537414966	0.505	77	880	4	5	5	17	0	2	17	0	0	3.0000001428146477	107	
i 1	193.25408163265305	0.2525	74	564	4	5	3	16	0	2	16	0	0	3.0000001428146477	107	
i 1	193.26115646258503	2.2725	69	880	5	1	11	1	0	0	1	0	0	0.43817134410573777	107	
i 1	193.26278911564626	0.2525	73	298	4	24	10	16	0	2	16	0	0	4.0	107	
i 1	193.49809523809523	0.2525	77	298	5	5	1	16	0	1	16	0	0	3.0000001428146477	107	
i 1	193.7377551020408	1.7675	67	880	4	18	9	0	0	1	0	0	0	0.24250072243644835	107	
i 1	193.7448299319728	1.2625	76	880	3	24	6	17	0	1	17	0	0	4.0	107	
i 1	193.98721088435374	0.505	77	298	5	5	3	16	0	1	16	0	0	3.0000001428146477	107	
i 1	193.9921088435374	0.505	76	564	3	24	8	16	0	1	16	0	0	4.0	107	
i 1	193.99591836734695	0.2525	77	880	4	5	6	17	0	2	17	0	0	3.0000001428146477	107	
i 1	193.99755102040817	0.2525	72	298	5	24	1	0	0	0	0	0	0	3.4381713441057378	107	
i 1	193.99863945578232	1.01	69	880	6	2	10	0	0	-1	0	0	0	8.0	107	
i 1	194.0051700680272	0.505	69	880	5	1	10	0	0	0	0	0	0	0.43817134410573777	107	
i 1	194.26278911564626	0.505	69	298	5	1	10	0	0	-1	0	0	0	0.43817134410573777	107	
i 1	194.74591836734695	0.2525	74	564	4	5	16	16	0	2	16	0	0	3.0000001428146477	107	
i 1	194.7491836734694	0.2525	69	880	5	1	8	0	0	0	0	0	0	0.43817134410573777	107	
i 1	194.7491836734694	0.2525	77	298	5	5	6	16	0	1	16	0	0	3.0000001428146477	107	
i 1	194.98938775510203	0.2525	69	880	4	9	4	0	0	0	0	0	0	7.0	107	
i 1	195.00680272108843	0.505	69	880	6	1	8	0	0	0	0	0	0	0.43817134410573777	107	
i 1	195.00897959183675	0.505	77	880	4	5	12	17	0	2	17	0	0	3.0000001428146477	107	
i 1	195.23721088435374	0.2525	67	880	5	14	1	5	0	1	5	0	0	6.928519058338312	107	
i 1	195.2551700680272	0.2525	67	564	4	19	10	0	0	0	0	0	0	0.24250072243644835	107	
i 1	195.2551700680272	0.2525	76	880	3	24	2	17	0	1	17	0	0	4.0	107	
i 1	195.26061224489797	0.2525	76	564	3	24	9	16	0	1	16	0	0	4.0	107	
i 1	195.26278911564626	0.2525	69	880	5	1	8	0	0	0	0	0	0	0.43817134410573777	107	
i 1	195.4882993197279	0.2525	72	789	3	9	5	0	0	-1	0	0	0	7.0	108	
i 1	195.48993197278912	2.7775	60	403	4	19	14	0	0	0	0	0	0	0.24250072243644835	108	
i 1	195.49102040816325	1.2625	67	789	4	18	16	5	0	0	5	0	0	0.24250072243644835	108	
i 1	195.49700680272107	1.7675	72	403	4	4	8	0	0	0	0	0	0	8.0	108	
i 1	195.4991836734694	1.2625	60	403	4	19	1	0	0	1	0	0	0	0.24250072243644835	108	
i 1	195.50462585034015	0.2525	69	789	6	1	13	0	0	-1	0	0	0	0.43817134410573777	108	
i 1	195.5073469387755	1.7675	74	1105	6	5	3	16	0	2	16	0	0	3.0000001428146477	108	
i 1	195.50897959183675	2.2725	76	403	3	24	4	17	0	1	17	0	0	4.0	108	
i 1	195.51006802721088	3.0300000000000002	67	1105	5	14	4	0	0	1	0	0	0	6.928519058338312	108	
i 1	195.5122448979592	0.2525	72	1105	5	1	9	0	0	0	0	0	0	0.43817134410573777	108	
i 1	195.7377551020408	0.505	72	403	6	1	15	0	0	0	0	0	0	0.43817134410573777	109	
i 1	195.7578911564626	0.505	69	789	4	9	7	0	0	-1	0	0	0	7.0	109	
i 1	196.23938775510203	0.2525	72	1105	6	2	8	0	0	-1	0	0	0	8.0	110	
i 1	196.2448299319728	0.2525	69	1105	6	2	11	1	0	-1	1	0	0	8.0	110	
i 1	196.4882993197279	0.2525	72	403	4	4	3	1	0	0	1	0	0	8.0	111	
i 1	196.49319727891157	0.2525	69	789	6	1	15	1	0	0	1	0	0	0.43817134410573777	111	
i 1	196.5095238095238	0.2525	69	403	4	3	13	0	0	-1	0	0	0	8.0	111	
i 1	196.76278911564626	1.7675	60	403	4	19	2	0	0	1	0	0	0	0.24250072243644835	111	
i 1	197.0078911564626	0.2525	69	1105	6	2	13	1	0	-1	1	0	0	8.0	111	
i 1	197.2382993197279	1.2625	73	403	3	24	3	17	0	2	17	0	0	4.0	111	
i 1	197.24700680272107	1.2625	72	1105	6	2	12	0	0	-1	0	0	0	8.0	111	
i 1	197.49809523809523	0.7575000000000001	72	403	4	4	15	1	0	0	1	0	0	8.0	111	
i 1	197.50571428571428	0.2525	69	789	6	1	14	1	0	0	1	0	0	0.43817134410573777	111	
i 1	197.7382993197279	0.505	72	403	6	1	13	0	0	0	0	0	0	0.43817134410573777	111	
i 1	197.73993197278912	0.2525	72	403	4	3	5	0	0	-1	0	0	0	8.0	111	
i 1	198.2404761904762	0.2525	69	403	5	3	2	0	0	-1	0	0	0	8.0	111	
i 1	198.24428571428572	0.2525	60	403	5	15	1	5	0	1	5	0	0	1.051371833090486	111	
i 1	198.24755102040817	1.5150000000000001	73	789	3	24	1	17	0	1	17	0	0	4.0	111	
i 1	198.25136054421768	0.2525	72	1105	6	1	9	0	0	0	0	0	0	0.43817134410573777	111	
i 1	198.4877551020408	1.2625	60	473	5	15	5	0	0	0	0	0	0	1.051371833090486	112	
i 1	198.4926530612245	0.505	72	87	6	1	14	0	0	0	0	0	0	0.43817134410573777	112	
i 1	198.49700680272107	1.2625	67	87	6	14	9	5	0	0	5	0	0	6.928519058338312	112	
i 1	198.49863945578232	0.2525	69	87	7	2	11	1	0	-1	1	0	0	8.0	112	
i 1	198.50408163265305	1.2625	67	87	4	19	12	0	0	1	0	0	0	0.24250072243644835	112	
i 1	198.50462585034015	0.2525	73	87	3	24	15	17	0	2	17	0	0	4.0	112	
i 1	198.5122448979592	1.2625	69	473	4	24	14	1	0	0	1	0	0	3.4381713441057378	112	
i 1	198.98721088435374	0.2525	73	87	3	24	8	17	0	2	17	0	0	4.0	112	
i 1	199.0122448979592	0.2525	69	87	5	24	4	0	0	-1	0	0	0	3.4381713441057378	112	
i 1	199.23993197278912	0.505	69	473	5	3	13	0	0	-1	0	0	0	8.0	112	
i 1	199.25571428571428	0.2525	72	87	4	4	4	0	0	-1	0	0	0	8.0	112	
i 1	199.26061224489797	0.2525	72	87	6	1	4	0	0	0	0	0	0	0.43817134410573777	112	
i 1	199.73993197278912	3.7875	67	473	5	15	4	5	0	1	5	0	0	1.1019369031030044	112	
i 1	199.75571428571428	0.2525	69	789	3	9	3	0	0	-1	0	0	0	5.0	112	
i 1	199.75680272108843	3.7875	67	87	1	27	7	5	0	252	5	307	0	4.467098578465541	112	
i 1	199.76333333333332	1.5150000000000001	67	87	6	14	10	5	0	0	5	0	0	6.979084128350831	112	
i 1	199.76333333333332	3.0300000000000002	60	473	5	15	2	0	0	0	0	0	0	1.1019369031030044	112	
i 1	199.98884353741497	0.2525	73	789	3	24	10	17	0	1	17	0	0	4.0	112	
i 1	199.99972789115645	0.505	69	87	7	2	10	1	0	-1	1	0	0	6.0	112	
i 1	200.23666666666668	0.505	72	87	3	3	14	0	0	-1	0	0	0	6.0	112	
i 1	200.48666666666668	0.7575000000000001	73	789	3	24	14	17	0	1	17	0	0	4.0	112	
i 1	200.746462585034	2.02	69	87	7	2	14	1	0	0	1	0	0	6.0	112	
i 1	200.74755102040817	0.2525	69	473	4	24	8	1	0	0	1	0	0	3.0	112	
i 1	200.76061224489797	2.02	73	87	3	24	7	17	0	2	17	0	0	4.0	112	
i 1	200.9921088435374	0.2525	77	87	7	5	13	16	0	1	16	0	0	3.0	112	
i 1	200.9926530612245	0.505	74	789	6	5	12	16	0	1	16	0	0	3.0	112	
i 1	201.01333333333332	0.2525	72	473	4	4	13	1	0	0	1	0	0	6.0	112	
i 1	201.2382993197279	1.5150000000000001	67	87	6	14	5	5	0	0	5	0	0	6.979084128350831	112	
i 1	201.25571428571428	2.2725	67	789	4	16	12	0	0	0	0	0	0	4.040510515726917	112	
i 1	201.25897959183675	0.505	69	789	5	9	2	0	0	-1	0	0	0	5.0	112	
i 1	201.49428571428572	0.505	77	87	7	5	10	16	0	1	16	0	0	3.0	112	
i 1	201.49755102040817	1.2625	69	473	4	24	11	1	0	0	1	0	0	3.0	112	
i 1	201.75299319727893	0.505	77	87	7	5	7	17	0	1	17	0	0	3.0	112	
i 1	201.76115646258503	0.2525	72	473	4	4	4	1	0	0	1	0	0	6.0	112	
i 1	201.9877551020408	0.2525	76	87	3	24	2	16	0	2	16	0	0	4.0	112	
i 1	202.23993197278912	0.2525	74	789	6	5	14	16	0	1	16	0	0	3.0	112	
i 1	202.24319727891157	1.01	72	473	4	4	7	1	0	0	1	0	0	6.0	112	
i 1	202.24809523809523	1.2625	73	789	3	24	16	17	0	1	17	0	0	4.0	112	
i 1	202.73884353741497	0.7575000000000001	77	87	7	5	3	16	0	1	16	0	0	3.0	114	
i 1	202.74156462585034	0.7575000000000001	60	473	5	15	8	0	0	0	0	0	0	1.1019369031030044	114	
i 1	202.74374149659863	0.2525	74	473	6	5	1	16	0	1	16	0	0	3.0	114	
i 1	202.746462585034	0.7575000000000001	67	87	6	14	2	5	0	0	5	0	0	6.979084128350831	114	
i 1	202.74809523809523	0.2525	69	789	5	9	7	0	0	-1	0	0	0	5.0	114	
i 1	202.75136054421768	0.7575000000000001	67	789	4	16	8	0	0	1	0	0	0	4.040510515726917	114	
i 1	203.23721088435374	0.2525	74	473	6	5	12	16	0	1	16	0	0	3.0	115	
i 1	203.4877551020408	0.2525	69	81	5	4	9	0	0	-1	0	0	0	6.0	116	
i 1	203.4882993197279	3.7875	67	895	4	16	15	0	0	0	0	0	0	4.040510515726917	116	
i 1	203.48938775510203	0.505	69	579	3	4	13	0	0	0	0	0	0	6.0	116	
i 1	203.49809523809523	6.8175	67	895	5	14	1	0	5001	0	0	0	0	6.979084128350831	116	
i 1	203.503537414966	0.7575000000000001	60	81	6	15	12	0	0	1	0	0	0	1.1019369031030044	116	
i 1	203.5051700680272	2.2725	67	895	4	16	7	0	0	1	0	0	0	4.040510515726917	116	
i 1	203.50680272108843	1.01	74	579	6	5	11	16	0	2	16	0	0	3.0	116	
i 1	203.50680272108843	1.2625	73	579	3	24	8	17	0	1	17	0	0	4.0	116	
i 1	203.5073469387755	0.7575000000000001	60	81	6	15	5	0	0	0	0	0	0	1.1019369031030044	116	
i 1	203.51006802721088	0.7575000000000001	69	81	6	3	1	1	0	-1	1	0	0	6.0	116	
i 1	203.51333333333332	0.2525	73	895	3	24	9	17	0	1	17	0	0	4.0	116	
i 1	203.9926530612245	0.505	69	579	4	24	2	1	0	0	1	0	0	3.0	116	
i 1	203.9926530612245	0.2525	72	895	5	9	12	0	0	-1	0	0	0	5.0	116	
i 1	204.23721088435374	1.5150000000000001	60	81	6	15	8	0	0	0	0	0	0	1.1019369031030044	116	
i 1	204.23884353741497	1.01	76	579	3	24	3	17	0	2	17	0	0	4.0	116	
i 1	204.24428571428572	4.545	60	579	5	12	4	5	0	1	5	0	0	4.040510515726917	116	
i 1	204.25571428571428	1.5150000000000001	60	81	5	15	16	0	0	1	0	0	0	1.1019369031030044	116	
i 1	204.26115646258503	0.2525	69	579	4	4	12	0	0	0	0	0	0	6.0	116	
i 1	204.48884353741497	0.505	77	895	6	5	2	17	0	1	17	0	0	3.0	116	
i 1	204.51333333333332	0.7575000000000001	77	895	6	5	8	17	5001	1	17	0	0	3.0	116	
i 1	204.75843537414966	0.2525	69	895	5	9	15	1	0	-1	1	0	0	5.0	116	
i 1	204.99755102040817	0.2525	74	895	5	5	5	16	0	1	16	0	0	3.0	116	
i 1	205.00190476190477	0.2525	72	895	5	9	9	0	0	-1	0	0	0	5.0	116	
i 1	205.2382993197279	0.2525	69	579	4	4	9	0	0	0	0	0	0	6.0	116	
i 1	205.2426530612245	0.2525	69	81	5	24	15	0	0	-1	0	0	0	3.0	116	
i 1	205.2508163265306	0.2525	74	895	6	5	4	16	5001	1	16	0	0	3.0	116	
i 1	205.51061224489797	2.02	69	81	6	3	12	1	0	-1	1	0	0	6.0	117	
i 1	205.7426530612245	4.545	60	81	6	15	6	0	0	1	0	0	0	1.1019369031030044	117	
i 1	205.75027210884355	0.505	77	895	5	5	8	17	0	1	17	0	0	3.0	117	
i 1	205.75897959183675	1.5150000000000001	60	81	5	15	3	0	0	0	0	0	0	1.1019369031030044	117	
i 1	205.76115646258503	1.5150000000000001	67	895	4	16	7	0	0	1	0	0	0	4.040510515726917	117	
i 1	205.7622448979592	0.2525	73	895	3	20	10	17	0	1	17	0	0	0.27354398540402336	117	
i 1	205.76333333333332	3.7875	67	579	5	12	3	0	0	1	0	0	0	4.040510515726917	117	
i 1	206.0008163265306	0.7575000000000001	77	895	6	5	7	17	5001	1	17	0	0	3.0	117	
i 1	206.003537414966	2.2725	73	895	2	20	1	17	5001	1	17	0	0	0.27354398540402336	117	
i 1	206.2508163265306	1.01	73	895	3	20	9	17	0	1	17	0	0	0.27354398540402336	117	
i 1	206.2595238095238	2.02	74	895	6	5	16	16	5001	1	16	0	0	3.0	117	
i 1	206.5117006802721	0.2525	72	579	5	3	10	1	0	0	1	0	0	6.0	117	
i 1	206.7382993197279	0.2525	74	579	6	5	15	16	0	2	16	0	0	3.0	117	
i 1	206.74156462585034	0.2525	76	579	3	24	1	17	0	2	17	0	0	4.273543985404023	117	
i 1	206.74809523809523	0.2525	74	579	6	5	11	17	0	2	17	0	0	3.0	117	
i 1	206.75190476190477	0.2525	72	895	5	9	3	0	0	-1	0	0	0	5.0	117	
i 1	206.9904761904762	1.01	69	895	6	2	8	0	5001	-1	0	0	0	6.0	117	
i 1	207.01333333333332	0.2525	77	895	6	5	8	17	5001	1	17	0	0	3.0	117	
i 1	207.23666666666668	0.2525	72	895	5	9	12	0	0	-1	0	0	0	5.0	117	
i 1	207.23721088435374	1.5150000000000001	67	895	4	16	15	0	0	0	0	0	0	4.040510515726917	117	
i 1	207.2578911564626	3.0300000000000002	60	81	6	15	15	0	0	0	0	0	0	1.1019369031030044	117	
i 1	207.26061224489797	1.5150000000000001	67	895	4	16	10	0	0	1	0	0	0	4.040510515726917	117	
i 1	207.26278911564626	0.2525	76	895	2	20	3	16	5001	2	16	0	0	0.27354398540402336	117	
i 1	207.48721088435374	0.2525	74	579	6	5	9	17	0	2	17	0	0	3.0	117	
i 1	207.50244897959183	2.02	76	579	3	24	13	17	0	2	17	0	0	4.273543985404023	117	
i 1	207.5051700680272	0.505	69	895	6	2	15	1	5001	-1	1	0	0	6.0	117	
i 1	207.74102040816325	2.525	77	81	6	5	12	16	0	1	16	0	0	3.0	117	
i 1	207.75244897959183	1.01	77	895	5	5	1	17	0	1	17	0	0	3.0	117	
i 1	207.75462585034015	0.7575000000000001	73	579	2	20	16	17	0	2	17	0	0	0.27354398540402336	117	
i 1	208.0117006802721	0.2525	69	579	4	4	3	0	0	0	0	0	0	6.0	117	
i 1	208.24156462585034	0.2525	76	895	2	20	12	16	5001	2	16	0	0	0.27354398540402336	117	
i 1	208.24428571428572	0.2525	69	895	6	2	4	0	5001	-1	0	0	0	6.0	117	
i 1	208.24537414965985	0.2525	69	895	6	2	16	1	5001	-1	1	0	0	6.0	117	
i 1	208.4882993197279	0.2525	73	81	3	20	10	16	0	2	16	0	0	0.27354398540402336	117	
i 1	208.50625850340137	0.505	77	81	6	5	1	16	0	2	16	0	0	3.0	117	
i 1	208.5078911564626	0.2525	69	895	5	9	3	1	0	-1	1	0	0	5.0	117	
i 1	208.7404761904762	0.7575000000000001	60	579	5	12	16	5	0	1	5	0	0	4.040510515726917	117	
i 1	208.746462585034	1.5150000000000001	69	81	5	24	16	0	0	-1	0	0	0	3.0	117	
i 1	208.75244897959183	1.5150000000000001	67	895	4	16	2	0	0	1	0	0	0	4.040510515726917	117	
i 1	208.7595238095238	1.5150000000000001	67	895	4	16	16	0	0	0	0	0	0	4.040510515726917	117	
i 1	209.01278911564626	0.2525	72	895	5	9	7	0	0	-1	0	0	0	5.0	117	
i 1	209.2382993197279	1.01	69	895	6	2	11	1	5001	-1	1	0	0	6.0	117	
i 1	209.24755102040817	1.01	76	895	2	20	7	16	5001	2	16	0	0	0.27354398540402336	117	
i 1	209.25027210884355	1.01	73	895	2	20	5	17	0	1	17	0	0	0.27354398540402336	117	
i 1	209.2622448979592	1.01	77	895	5	5	14	17	5001	1	17	0	0	3.0	117	
i 1	209.48938775510203	0.7575000000000001	67	397	1	27	10	5	0	248	5	308	0	4.467098578465541	118	
i 1	209.4991836734694	0.7575000000000001	60	397	5	12	3	5	0	0	5	0	0	4.040510515726917	118	
i 1	209.5008163265306	0.7575000000000001	74	895	6	5	14	16	5001	1	16	0	0	3.0	118	
i 1	209.50136054421768	0.7575000000000001	60	397	5	12	16	5	0	0	5	0	0	4.040510515726917	118	
i 1	209.50462585034015	0.505	76	397	1	24	2	17	0	252	17	307	0	4.273543985404023	118	
i 1	209.51115646258503	0.2525	76	397	3	24	15	17	0	2	17	0	0	4.273543985404023	118	
i 1	210.2382993197279	6.0600000000000005	67	193	5	16	4	5	5001	1	5	0	0	4.040510515726917	120	
i 1	210.23993197278912	0.505	76	579	2	24	9	16	0	2	16	0	0	4.273543985404023	120	
i 1	210.2404761904762	6.565	60	193	5	16	7	0	5001	0	0	0	0	4.040510515726917	120	
i 1	210.24700680272107	1.01	76	579	2	24	3	17	0	2	17	0	0	4.273543985404023	120	
i 1	210.24755102040817	1.5150000000000001	67	579	5	12	7	5	0	1	5	0	0	4.040510515726917	120	
i 1	210.2508163265306	3.0300000000000002	67	895	5	14	5	0	5001	0	0	0	0	6.979084128350831	120	
i 1	210.25190476190477	3.0300000000000002	60	579	5	15	13	0	5001	0	0	0	0	1.1019369031030044	120	
i 1	210.25299319727893	4.545	60	579	5	15	8	0	5001	1	0	0	0	1.1019369031030044	120	
i 1	210.25625850340137	1.5150000000000001	60	579	4	12	14	5	0	1	5	0	0	4.040510515726917	120	
i 1	210.2578911564626	1.5150000000000001	69	579	4	4	6	0	5001	-1	0	0	0	6.0	120	
i 1	210.26006802721088	4.545	69	579	4	24	1	1	5001	0	1	0	0	3.0	120	
i 1	210.5008163265306	0.7575000000000001	76	579	2	24	8	16	5001	1	16	0	0	4.273543985404023	121	
i 1	210.51333333333332	1.2625	77	895	5	5	2	17	5001	1	17	0	0	3.0	121	
i 1	210.7404761904762	1.01	70	193	3	20	5	8	5001	-2	8	0	0	0.27354398540402336	121	
i 1	210.74972789115645	1.01	76	193	3	24	6	16	5001	1	16	0	0	4.273543985404023	121	
i 1	211.00408163265305	0.2525	69	895	6	2	4	1	5001	-1	1	0	0	6.0	121	
i 1	211.246462585034	1.2625	76	579	2	24	6	16	0	2	16	0	0	4.273543985404023	121	
i 1	211.246462585034	1.2625	76	579	1	24	15	17	0	248	17	308	0	4.273543985404023	121	
i 1	211.26061224489797	0.505	69	579	5	3	13	0	0	-1	0	0	0	6.0	121	
i 1	211.50625850340137	0.505	74	579	6	5	11	16	5001	2	16	0	0	3.0	121	
i 1	211.5073469387755	0.2525	73	193	3	20	9	8	5001	-1	8	0	0	0.27354398540402336	121	
i 1	211.7448299319728	0.7575000000000001	60	579	5	12	13	5	0	1	5	0	0	4.040510515726917	121	
i 1	211.746462585034	0.505	72	579	5	3	13	0	5001	0	0	0	0	6.0	121	
i 1	211.75408163265305	0.7575000000000001	67	579	4	12	6	5	0	1	5	0	0	4.040510515726917	121	
i 1	211.75571428571428	0.2525	77	193	6	5	14	16	5001	2	16	0	0	3.0	121	
i 1	211.9882993197279	0.7575000000000001	73	193	3	20	5	16	5001	2	16	0	0	0.27354398540402336	121	
i 1	211.99374149659863	0.2525	77	579	5	5	1	16	0	2	16	0	0	3.0	121	
i 1	212.0117006802721	3.0300000000000002	74	895	5	5	9	16	5001	1	16	0	0	3.0	121	
i 1	212.2491836734694	0.505	69	193	6	9	12	0	5001	0	0	0	0	5.0	121	
i 1	212.25190476190477	0.2525	77	193	6	5	3	16	5001	2	16	0	0	3.0	121	
i 1	212.25462585034015	0.2525	69	579	5	3	2	0	0	-1	0	0	0	6.0	121	
i 1	212.50136054421768	0.7575000000000001	61	750	4	12	8	6	0	0	6	0	0	4.040510515726917	122	
i 1	212.50244897959183	4.2925	61	750	5	12	2	6	0	0	6	0	0	4.040510515726917	122	
i 1	212.5078911564626	0.505	70	750	2	24	12	2	5001	-1	2	0	0	4.273543985404023	122	
i 1	212.51278911564626	0.505	74	193	6	5	12	17	5001	2	17	0	0	3.0	122	
i 1	212.75027210884355	1.01	70	750	2	24	16	8	0	-2	8	0	0	4.273543985404023	122	
i 1	212.75680272108843	0.2525	74	579	6	5	6	16	5001	2	16	0	0	3.0	122	
i 1	212.98666666666668	0.2525	69	579	4	4	2	0	5001	-1	0	0	0	6.0	122	
i 1	212.99537414965985	0.2525	77	750	4	24	8	16	0	1	16	0	0	3.0	122	
i 1	213.00190476190477	0.2525	74	750	5	5	12	8	0	-1	8	0	0	3.0	122	
i 1	213.24374149659863	3.0300000000000002	60	579	5	15	6	0	5001	0	0	0	0	1.1019369031030044	122	
i 1	213.24537414965985	3.535	61	750	5	12	16	6	0	0	6	0	0	4.040510515726917	122	
i 1	213.25625850340137	0.7575000000000001	69	579	4	4	6	0	5001	-1	0	0	0	6.0	122	
i 1	213.26006802721088	0.2525	73	193	3	20	2	2	5001	-2	2	0	0	0.27354398540402336	122	
i 1	213.5117006802721	1.2625	72	579	5	3	10	0	5001	0	0	0	0	6.0	122	
i 1	213.73993197278912	0.2525	77	750	4	4	4	16	0	1	16	0	0	6.0	122	
i 1	213.74102040816325	0.7575000000000001	77	193	6	5	4	16	5001	2	16	0	0	3.0	122	
i 1	213.746462585034	1.5150000000000001	73	750	2	24	8	2	0	-1	2	0	0	4.273543985404023	122	
i 1	213.99428571428572	0.2525	77	750	5	3	9	16	0	2	16	0	0	6.0	122	
i 1	214.0008163265306	0.2525	77	895	5	5	3	17	5001	1	17	0	0	3.0	122	
i 1	214.01333333333332	2.02	69	895	6	2	10	1	5001	-1	1	0	0	6.0	122	
i 1	214.5008163265306	0.2525	74	750	5	5	15	8	0	-1	8	0	0	3.0	122	
i 1	214.74537414965985	0.7575000000000001	72	193	6	9	12	0	5001	0	0	0	0	5.0	122	
i 1	214.7551700680272	2.02	60	579	5	15	16	0	5001	1	0	0	0	1.1019369031030044	122	
i 1	214.99700680272107	0.2525	70	579	3	20	3	8	5001	-2	8	0	0	0.27354398540402336	122	
i 1	215.00136054421768	2.02	77	895	6	5	1	17	5001	1	17	0	0	3.0	122	
i 1	215.0117006802721	1.7675	73	193	3	20	3	16	5001	2	16	0	0	0.27354398540402336	122	
i 1	215.24319727891157	1.5150000000000001	72	579	5	3	12	0	5001	0	0	0	0	6.0	122	
i 1	215.24755102040817	0.7575000000000001	74	750	5	5	3	8	0	-2	8	0	0	3.0	122	
i 1	215.25244897959183	0.2525	70	193	3	20	3	2	5001	-1	2	0	0	0.27354398540402336	122	
i 1	215.253537414966	0.2525	70	193	3	20	14	2	5001	-1	2	0	0	0.27354398540402336	122	
i 1	215.25408163265305	0.2525	73	750	2	20	10	8	5001	-2	8	0	0	0.27354398540402336	122	
i 1	215.5051700680272	0.2525	74	579	5	5	9	16	5001	2	16	0	0	3.0	122	
i 1	215.7573469387755	0.7575000000000001	77	193	5	5	16	16	5001	2	16	0	0	3.0	122	
i 1	215.76061224489797	0.505	73	579	3	20	14	2	5001	-1	2	0	0	0.27354398540402336	122	
i 1	216.23721088435374	0.505	67	193	5	16	4	5	5001	1	5	0	0	4.040510515726917	122	
i 1	216.2491836734694	0.2525	73	750	2	20	11	2	5001	-2	2	0	0	0.27354398540402336	122	
i 1	216.24972789115645	0.505	74	579	5	5	6	16	5001	2	16	0	0	3.0	122	
i 1	216.50843537414966	0.2525	74	750	5	5	6	8	0	-2	8	0	0	3.0	123	
i 1	216.73938775510203	0.7575000000000001	61	901	5	12	4	6	0	1	6	0	0	4.040510515726917	124	
i 1	216.73938775510203	0.7575000000000001	77	403	5	3	5	17	0	1	17	0	0	6.0	124	
i 1	216.74156462585034	0.7575000000000001	66	901	1	27	7	6	0	248	6	308	0	4.467098578465541	124	
i 1	216.7448299319728	0.7575000000000001	74	403	4	4	2	16	0	1	16	0	0	6.0	124	
i 1	216.74755102040817	0.7575000000000001	70	87	3	20	3	2	0	-1	2	0	0	0.27354398540402336	124	
i 1	216.74809523809523	0.7575000000000001	66	901	1	27	12	6	0	252	6	307	0	4.467098578465541	124	
i 1	216.75027210884355	0.505	74	901	5	5	5	8	0	-1	8	0	0	3.0	124	
i 1	216.75680272108843	0.7575000000000001	66	87	5	16	14	9	0	1	9	0	0	4.040510515726917	124	
i 1	216.7578911564626	0.7575000000000001	66	87	5	16	2	9	0	0	9	0	0	4.040510515726917	124	
i 1	216.76006802721088	0.7575000000000001	66	403	5	15	3	9	0	1	9	0	0	1.1019369031030044	124	
i 1	216.7617006802721	0.7575000000000001	61	901	5	12	4	6	0	0	6	0	0	4.040510515726917	124	
i 1	217.0078911564626	0.2525	71	87	5	5	9	8	0	-2	8	0	0	3.0	124	
i 1	217.23938775510203	0.2525	71	901	5	5	2	8	0	-2	8	0	0	3.0	125	
i 1	217.2551700680272	0.2525	70	87	3	24	11	8	0	-2	8	0	0	4.273543985404023	125	
i 1	217.26061224489797	0.2525	73	87	3	20	10	2	5001	-1	2	0	0	0.27354398540402336	125	
i 1	217.48721088435374	0.2525	66	199	5	16	7	6	0	1	6	0	0	4.040510515726917	126	
i 1	217.4882993197279	0.2525	74	199	5	5	10	8	0	-1	8	0	0	3.0	126	
i 1	217.4904761904762	0.2525	70	199	3	20	7	8	0	-2	8	0	0	0.27354398540402336	126	
i 1	217.4948299319728	0.2525	61	403	5	15	2	9	0	1	9	0	0	1.1019369031030044	126	
i 1	217.49863945578232	3.2825	61	1052	5	12	5	6	0	1	6	0	0	4.040510515726917	126	
i 1	217.4991836734694	3.535	74	403	4	24	2	16	0	2	16	0	0	3.0	126	
i 1	217.5051700680272	1.7675	66	199	5	16	3	6	0	0	6	0	0	4.040510515726917	126	
i 1	217.50571428571428	0.7575000000000001	77	403	4	4	11	17	0	2	17	0	0	6.0	126	
i 1	217.5073469387755	1.7675	66	1052	5	12	16	6	0	0	6	0	0	4.040510515726917	126	
i 1	217.5117006802721	0.505	73	199	3	24	5	2	0	-1	2	0	0	4.273543985404023	126	
i 1	217.51278911564626	4.7975	61	1052	1	27	10	6	0	252	6	307	0	4.467098578465541	126	
i 1	217.74102040816325	3.0300000000000002	66	199	5	16	5	6	0	1	6	0	0	4.040510515726917	126	
i 1	217.746462585034	0.2525	70	199	3	20	10	2	5001	-1	2	0	0	0.27354398540402336	126	
i 1	217.753537414966	1.5150000000000001	74	895	6	5	5	16	5001	1	16	0	0	3.0	126	
i 1	217.76006802721088	0.505	74	403	6	5	13	8	0	-2	8	0	0	3.0	126	
i 1	218.5078911564626	0.2525	70	199	3	20	4	2	5001	-1	2	0	0	0.27354398540402336	126	
i 1	218.74156462585034	0.2525	70	1052	2	20	12	2	0	-1	2	0	0	0.27354398540402336	126	
i 1	218.7578911564626	2.525	74	403	6	5	16	8	0	-2	8	0	0	3.0	126	
i 1	219.0008163265306	1.5150000000000001	70	199	3	20	15	8	0	-2	8	0	0	0.27354398540402336	126	
i 1	219.23938775510203	0.2525	70	1052	2	20	12	8	0	-2	8	0	0	0.27354398540402336	126	
i 1	219.25244897959183	3.0300000000000002	66	1052	4	12	11	6	0	0	6	0	0	4.040510515726917	126	
i 1	219.2622448979592	1.01	73	199	3	20	4	2	5001	-1	2	0	0	0.27354398540402336	126	
i 1	219.4921088435374	0.2525	77	1052	4	24	7	17	0	2	17	0	0	3.0	127	
i 1	219.73993197278912	0.2525	71	199	5	5	9	2	0	-1	2	0	0	3.0	127	
i 1	219.99863945578232	0.505	77	895	6	5	2	17	5001	1	17	0	0	3.0	127	
i 1	220.00625850340137	0.2525	74	199	5	5	4	8	0	-1	8	0	0	3.0	127	
i 1	220.24374149659863	1.01	70	1052	2	24	4	2	0	-2	2	0	0	4.273543985404023	127	
i 1	220.26061224489797	0.2525	73	895	3	20	6	8	5001	-2	8	0	0	0.27354398540402336	127	
i 1	220.48721088435374	0.2525	71	199	5	5	9	2	0	-1	2	0	0	3.0	127	
i 1	220.49755102040817	0.2525	73	1052	2	20	5	2	0	-2	2	0	0	0.27354398540402336	127	
i 1	220.75299319727893	1.5150000000000001	67	895	5	25	14	0	5001	1	0	0	0	4.020388720618987	127	
i 1	220.7595238095238	2.2725	77	895	6	5	5	17	5001	1	17	0	0	3.0	127	
i 1	220.76333333333332	1.5150000000000001	61	1052	4	12	14	6	0	1	6	0	0	4.040510515726917	127	
i 1	221.0051700680272	1.01	69	895	6	2	12	1	5001	-1	1	0	0	6.0	127	
i 1	221.25625850340137	0.2525	74	1052	4	5	11	8	0	-2	8	0	0	3.0	127	
i 1	221.50244897959183	0.2525	74	199	6	5	16	8	0	-1	8	0	0	3.0	127	
i 1	221.76061224489797	0.505	71	1052	4	5	1	8	0	-1	8	0	0	3.0	127	
i 1	222.00625850340137	0.505	74	403	6	5	12	8	0	-2	8	0	0	3.0	127	
i 1	222.25190476190477	1.2625	70	1052	2	20	14	8	0	-2	8	0	0	0.14096973566733428	127	
i 1	222.253537414966	1.2625	70	1052	2	24	12	8	0	-1	8	0	0	4.140969735667334	127	
i 1	222.25462585034015	1.2625	77	403	4	4	9	17	0	2	17	0	0	14.0	127	
i 1	222.25462585034015	1.2625	74	895	6	5	4	16	5001	1	16	0	0	3.0	127	
i 1	222.2578911564626	1.2625	61	1052	4	12	2	6	0	1	6	0	0	3.404153879908992	127	
i 1	222.25897959183675	0.2525	69	895	6	2	13	0	5001	-1	0	0	0	14.0	127	
i 1	222.48884353741497	0.2525	73	199	3	20	16	2	5001	-1	2	0	0	0.14096973566733428	127	
i 1	222.50136054421768	0.505	74	1052	5	3	15	16	0	1	16	0	0	14.0	127	
i 1	222.75680272108843	0.7575000000000001	74	403	5	3	8	17	0	2	17	0	0	14.0	127	
i 1	222.9904761904762	0.505	74	403	4	24	6	16	0	2	16	0	0	3.0	127	
i 1	223.2404761904762	0.2525	74	403	6	5	10	8	0	-2	8	0	0	3.0	127	
i 1	223.25244897959183	0.2525	71	199	6	5	16	2	0	-1	2	0	0	3.0	127	
i 1	223.25680272108843	0.2525	77	199	6	9	8	17	0	1	17	0	0	13.0	127	
i 1	223.49102040816325	9.09	63	915	1	27	16	16	0	252	16	307	0	2.6802591470793242	0	
i 1	223.49809523809523	0.2525	72	915	5	5	8	8	0	-2	8	0	0	3.0	0	
i 1	223.503537414966	3.0300000000000002	63	101	6	25	3	1	0	1	1	0	0	2.23354928923277	0	
i 1	223.50462585034015	1.5150000000000001	74	417	1	24	5	2	0	-2	2	0	0	4.0	0	
i 1	223.7491836734694	0.2525	75	915	3	5	15	2	0	1	2	0	0	3.0	1	
i 1	223.7578911564626	0.2525	75	915	3	3	16	8	0	1	8	0	0	5.0	1	
i 1	223.9877551020408	0.2525	72	417	5	5	12	2	0	1	2	0	0	3.0	1	
i 1	223.99863945578232	0.2525	71	915	4	24	13	8	0	-1	8	0	0	3.0	1	
i 1	224.23721088435374	0.505	72	417	4	9	11	2	0	1	2	0	0	4.0	1	
i 1	224.24972789115645	0.505	75	915	3	5	3	2	0	1	2	0	0	3.0	1	
i 1	224.49863945578232	0.505	71	915	4	24	8	8	0	-1	8	0	0	3.0	1	
i 1	224.50244897959183	0.505	72	101	5	5	12	2	0	-2	2	0	0	3.0	1	
i 1	224.74700680272107	0.2525	72	417	5	5	15	2	0	1	2	0	0	3.0	1	
i 1	224.7595238095238	0.505	75	101	7	2	8	2	0	-2	2	0	0	5.0	1	
i 1	224.98721088435374	0.505	71	417	4	20	14	2	0	1	2	0	0	0.0936371304557011	1	
i 1	224.9904761904762	0.2525	72	101	7	5	12	2	0	-2	2	0	0	3.0	1	
i 1	225.00190476190477	0.2525	74	417	1	24	14	2	0	-2	2	0	0	4.093637130455701	1	
i 1	225.00462585034015	1.01	72	101	7	2	7	2	0	-2	2	0	0	5.0	1	
i 1	225.0095238095238	3.0300000000000002	61	101	6	25	4	1	0	2	1	0	0	2.23354928923277	1	
i 1	225.2551700680272	0.505	72	915	4	5	8	8	0	-2	8	0	0	3.0	1	
i 1	225.75244897959183	0.2525	74	417	1	24	9	2	0	-2	2	0	0	4.093637130455701	2	
i 1	225.75680272108843	0.505	72	101	7	5	4	2	0	-2	2	0	0	3.0	2	
i 1	225.98666666666668	0.505	75	915	4	5	12	2	0	1	2	0	0	3.0	2	
i 1	226.01115646258503	0.505	74	915	1	20	15	2	0	1	2	0	0	0.0936371304557011	2	
i 1	226.24537414965985	0.2525	72	417	4	9	14	2	0	1	2	0	0	4.0	2	
i 1	226.26061224489797	0.2525	72	101	7	5	4	2	0	-2	2	0	0	3.0	2	
i 1	226.49319727891157	0.505	74	915	2	20	5	2	0	1	2	0	0	0.0936371304557011	2	
i 1	226.50027210884355	3.0300000000000002	61	915	5	25	6	1	0	1	1	0	0	2.23354928923277	2	
i 1	226.50408163265305	4.2925	63	101	6	25	4	1	0	1	1	0	0	2.23354928923277	2	
i 1	226.51333333333332	0.2525	72	417	5	5	16	2	0	1	2	0	0	3.0	2	
i 1	226.74156462585034	0.7575000000000001	74	417	1	24	8	2	0	-2	2	0	0	4.093637130455701	2	
i 1	226.9921088435374	1.01	75	101	7	2	5	2	0	-2	2	0	0	5.0	2	
i 1	227.246462585034	0.505	75	417	4	9	10	2	0	-2	2	0	0	4.0	2	
i 1	227.48993197278912	0.2525	74	417	3	24	14	2	0	-2	2	0	0	4.093637130455701	2	
i 1	227.4904761904762	2.02	72	101	7	5	2	2	0	-2	2	0	0	3.0	2	
i 1	227.74102040816325	0.2525	74	915	2	20	5	2	0	1	2	0	0	0.0936371304557011	2	
i 1	227.99156462585034	0.2525	74	417	3	24	2	2	0	-2	2	0	0	4.093637130455701	2	
i 1	228.00027210884355	0.2525	74	915	4	24	6	2	0	-2	2	0	0	4.093637130455701	2	
i 1	228.0008163265306	0.505	75	915	2	3	6	8	0	1	8	0	0	5.0	2	
i 1	228.00462585034015	0.2525	75	101	5	2	12	2	0	-2	2	0	0	5.0	2	
i 1	228.0117006802721	3.0300000000000002	61	915	5	25	9	1	0	2	1	0	0	2.23354928923277	2	
i 1	228.0122448979592	2.7775	61	101	6	25	10	1	0	2	1	0	0	2.23354928923277	2	
i 1	228.24102040816325	0.7575000000000001	72	101	7	2	8	2	0	-2	2	0	0	5.0	2	
i 1	228.496462585034	0.2525	75	417	4	9	11	2	0	-2	2	0	0	4.0	2	
i 1	228.50027210884355	0.7575000000000001	75	915	4	4	1	2	0	-2	2	0	0	5.0	2	
i 1	228.503537414966	0.7575000000000001	71	915	4	24	12	8	0	-1	8	0	0	3.0	2	
i 1	228.51278911564626	0.2525	71	915	2	24	12	8	0	-1	8	0	0	3.0	2	
i 1	228.74700680272107	0.2525	74	915	4	20	2	2	0	1	2	0	0	0.0936371304557011	2	
i 1	228.9882993197279	0.505	74	915	2	20	6	2	0	1	2	0	0	0.0936371304557011	2	
i 1	229.0008163265306	0.2525	74	915	2	24	1	2	0	-2	2	0	0	4.093637130455701	2	
i 1	229.2551700680272	0.2525	72	915	2	4	6	2	0	1	2	0	0	5.0	2	
i 1	229.48993197278912	3.0300000000000002	61	417	4	26	1	16	0	1	16	0	0	2.23354928923277	2	
i 1	229.4921088435374	0.2525	75	101	5	2	1	2	0	-2	2	0	0	5.0	2	
i 1	229.50299319727893	0.505	74	417	4	24	8	2	0	-2	2	0	0	4.093637130455701	2	
i 1	229.5078911564626	7.3225	61	915	5	25	1	1	0	1	1	0	0	2.23354928923277	2	
i 1	229.51061224489797	1.5150000000000001	75	915	6	5	5	2	0	1	2	0	0	3.0	2	
i 1	229.7377551020408	0.2525	74	915	2	24	10	2	0	-2	2	0	0	4.093637130455701	3	
i 1	229.74428571428572	0.2525	72	101	7	5	15	2	0	-2	2	0	0	3.0	3	
i 1	229.75408163265305	0.2525	71	915	2	24	12	8	0	-1	8	0	0	3.0	3	
i 1	229.9877551020408	0.2525	72	915	3	4	2	2	0	1	2	0	0	5.0	4	
i 1	229.9926530612245	0.2525	75	417	4	9	1	2	0	-2	2	0	0	4.0	4	
i 1	229.99972789115645	1.01	71	417	3	20	9	2	0	-2	2	0	0	0.0936371304557011	4	
i 1	230.00571428571428	1.01	71	417	4	20	7	2	0	-2	2	0	0	0.0936371304557011	4	
i 1	230.00625850340137	0.2525	72	915	6	5	10	8	0	-2	8	0	0	3.0	4	
i 1	230.0095238095238	0.2525	74	915	3	20	5	2	0	1	2	0	0	0.0936371304557011	4	
i 1	230.23666666666668	0.2525	75	915	4	4	14	2	0	-2	2	0	0	5.0	4	
i 1	230.5095238095238	0.2525	71	915	4	24	9	8	0	-1	8	0	0	3.0	5	
i 1	230.74755102040817	1.2625	75	213	7	5	4	8	0	-2	8	0	0	3.0	6	
i 1	230.74809523809523	4.7975	63	213	6	25	14	16	0	2	16	0	0	2.23354928923277	6	
i 1	230.74863945578232	3.2825	61	213	6	25	8	1	0	2	1	0	0	2.23354928923277	6	
i 1	230.99156462585034	3.0300000000000002	63	417	4	26	12	1	0	1	1	0	0	2.23354928923277	6	
i 1	230.99700680272107	0.2525	74	915	3	24	8	2	0	-2	2	0	0	4.007490970436456	6	
i 1	231.003537414966	5.8075	61	915	5	25	15	1	0	2	1	0	0	2.23354928923277	6	
i 1	231.48993197278912	1.01	74	915	2	24	3	2	0	-2	2	0	0	4.007490970436456	6	
i 1	231.49374149659863	1.5150000000000001	74	915	3	20	16	2	0	1	2	0	0	0.007490970436456301	6	
i 1	231.99809523809523	0.505	72	417	6	5	3	2	0	1	2	0	0	3.0	6	
i 1	232.49374149659863	0.2525	72	915	3	5	7	8	0	-2	8	0	0	3.0	6	
i 1	232.49700680272107	7.575	61	417	4	26	8	16	0	1	16	0	0	2.23354928923277	6	
i 1	232.50027210884355	1.5150000000000001	71	915	4	24	5	8	0	-1	8	0	0	3.0	6	
i 1	232.50571428571428	0.2525	74	915	3	24	15	2	0	-2	2	0	0	4.007490970436456	6	
i 1	232.50680272108843	0.7575000000000001	74	417	4	20	14	2	0	-2	2	0	0	0.007490970436456301	6	
i 1	232.5073469387755	3.0300000000000002	63	915	3	27	8	16	0	1	16	0	0	2.6802591470793242	6	
i 1	232.5122448979592	1.01	74	417	4	24	10	2	0	-2	2	0	0	4.007490970436456	6	
i 1	232.98666666666668	0.2525	72	417	6	5	2	2	0	1	2	0	0	3.0	7	
i 1	233.2426530612245	0.2525	72	417	5	9	8	2	0	1	2	0	0	4.0	7	
i 1	233.25190476190477	0.2525	71	213	4	20	16	2	0	-2	2	0	0	0.007490970436456301	7	
i 1	233.49156462585034	0.2525	71	417	4	20	15	2	0	1	2	0	0	0.007490970436456301	7	
i 1	233.74591836734695	0.2525	72	915	4	4	7	2	0	1	2	0	0	5.0	7	
i 1	233.98666666666668	0.2525	71	915	4	24	6	8	0	-1	8	0	0	3.0	7	
i 1	233.99755102040817	7.575	63	417	4	26	14	1	0	1	1	0	0	2.23354928923277	7	
i 1	234.00462585034015	2.7775	63	915	3	27	9	16	0	1	16	0	0	2.6802591470793242	7	
i 1	234.00680272108843	0.2525	75	213	7	5	7	8	0	-2	8	0	0	3.0	7	
i 1	234.25136054421768	0.2525	72	915	4	4	11	2	0	1	2	0	0	5.0	7	
i 1	234.2551700680272	0.2525	71	213	4	20	16	2	0	-2	2	0	0	0.007490970436456301	7	
i 1	234.26115646258503	0.505	75	213	7	5	15	8	0	1	8	0	0	3.0	7	
i 1	234.49319727891157	0.2525	74	417	4	20	2	2	0	-2	2	0	0	0.007490970436456301	7	
i 1	234.7595238095238	0.2525	72	213	7	2	2	2	0	-2	2	0	0	5.0	7	
i 1	234.99809523809523	0.7575000000000001	74	915	3	24	5	8	0	-2	8	0	0	4.007490970436456	7	
i 1	235.00299319727893	0.7575000000000001	74	915	3	24	6	2	0	-2	2	0	0	4.007490970436456	7	
i 1	235.01006802721088	0.2525	71	417	4	20	16	2	0	1	2	0	0	0.007490970436456301	7	
i 1	235.24537414965985	0.505	74	915	3	24	12	2	0	-2	2	0	0	4.007490970436456	7	
i 1	235.48993197278912	0.505	75	213	6	5	15	8	0	-2	8	0	0	3.0	7	
i 1	235.50299319727893	2.2725	74	417	4	24	14	2	0	-2	2	0	0	4.007490970436456	7	
i 1	235.5122448979592	1.2625	63	915	3	27	4	16	0	1	16	0	0	2.6802591470793242	7	
i 1	235.74809523809523	0.505	75	915	6	5	14	2	0	1	2	0	0	3.0	7	
i 1	235.7617006802721	0.2525	74	915	4	24	13	2	0	-2	2	0	0	4.007490970436456	7	
i 1	235.9877551020408	0.7575000000000001	74	915	3	24	11	2	0	-2	2	0	0	4.007490970436456	7	
i 1	236.00462585034015	0.2525	75	417	4	9	4	2	0	-2	2	0	0	4.0	7	
i 1	236.01115646258503	0.7575000000000001	74	915	3	24	4	8	0	-2	8	0	0	4.007490970436456	7	
i 1	236.746462585034	0.2525	71	803	4	24	9	8	0	-1	8	0	0	3.0	8	
i 1	236.75027210884355	0.505	74	1119	4	24	2	2	0	-1	2	0	0	3.0	8	
i 1	236.75244897959183	0.2525	63	803	3	27	15	1	0	2	1	0	0	2.6802591470793242	8	
i 1	236.7551700680272	1.7675	63	1119	5	25	10	1	0	1	1	0	0	2.23354928923277	8	
i 1	236.75571428571428	3.0300000000000002	61	803	3	27	10	1	0	1	1	0	0	2.6802591470793242	8	
i 1	236.75680272108843	0.2525	63	1119	5	25	8	1	0	2	1	0	0	2.23354928923277	8	
i 1	236.7578911564626	0.7575000000000001	75	417	6	2	5	2	0	-2	2	0	0	5.0	8	
i 1	236.996462585034	1.7675	75	1119	4	4	6	2	0	-2	2	0	0	5.0	9	
i 1	237.01278911564626	0.2525	74	803	3	24	6	8	0	1	8	0	0	4.007490970436456	9	
i 1	237.01333333333332	2.7775	63	803	3	27	11	1	0	2	1	0	0	2.6802591470793242	9	
i 1	237.25244897959183	0.2525	75	803	5	5	1	2	0	1	2	0	0	3.0	9	
i 1	237.25571428571428	0.2525	72	417	6	5	8	2	0	1	2	0	0	3.0	9	
i 1	237.4948299319728	1.5150000000000001	71	417	4	20	9	2	0	-2	2	0	0	0.007490970436456301	10	
i 1	237.5078911564626	0.7575000000000001	72	803	5	5	1	2	0	1	2	0	0	3.0	10	
i 1	237.51061224489797	0.505	71	417	4	20	11	2	0	1	2	0	0	0.007490970436456301	10	
i 1	237.7448299319728	0.2525	75	417	6	2	1	2	0	-2	2	0	0	5.0	11	
i 1	237.75190476190477	0.505	72	803	3	3	8	8	0	1	8	0	0	5.0	11	
i 1	237.99319727891157	1.2625	72	1119	5	3	1	8	0	1	8	0	0	5.0	11	
i 1	238.0117006802721	0.2525	71	803	3	24	16	2	0	-2	2	0	0	4.007490970436456	11	
i 1	238.25625850340137	0.505	74	1119	4	24	13	2	0	-1	2	0	0	3.0	11	
i 1	238.26333333333332	1.5150000000000001	72	417	6	5	7	2	0	-2	2	0	0	3.0	11	
i 1	238.50571428571428	0.505	72	1119	6	5	13	2	0	1	2	0	0	3.0	11	
i 1	238.7421088435374	0.2525	72	417	6	5	2	2	0	1	2	0	0	3.0	11	
i 1	238.7551700680272	0.2525	75	417	5	9	9	2	0	-2	2	0	0	4.0	11	
i 1	238.98721088435374	0.2525	72	417	6	5	1	2	0	1	2	0	0	3.0	11	
i 1	238.99700680272107	0.2525	75	1119	5	5	3	2	0	1	2	0	0	3.0	11	
i 1	239.246462585034	0.7575000000000001	71	417	4	20	2	2	0	1	2	0	0	0.007490970436456301	11	
i 1	239.5008163265306	0.2525	72	1119	5	3	13	8	0	1	8	0	0	5.0	11	
i 1	239.5095238095238	0.2525	75	417	5	9	4	2	0	-2	2	0	0	4.0	11	
i 1	239.7377551020408	0.505	72	101	7	2	9	2	0	-2	2	0	0	5.0	12	
i 1	239.74700680272107	1.2625	72	417	6	5	16	2	0	1	2	0	0	3.0	12	
i 1	239.75136054421768	2.525	75	915	5	3	4	2	0	1	2	0	0	5.0	12	
i 1	239.75462585034015	4.7975	63	915	3	27	8	16	0	2	16	0	0	2.6802591470793242	12	
i 1	239.75843537414966	3.2825	63	915	3	27	16	1	0	2	1	0	0	2.6802591470793242	12	
i 1	239.99156462585034	0.2525	74	915	4	24	6	2	0	-2	2	0	0	4.0	12	
i 1	239.9948299319728	0.505	71	915	4	24	13	8	0	-2	8	0	0	3.0	12	
i 1	240.00408163265305	2.02	74	417	4	24	8	2	0	-2	2	0	0	4.0	12	
i 1	240.50571428571428	0.2525	71	915	4	24	8	8	0	-1	8	0	0	3.0	12	
i 1	240.76061224489797	2.02	72	101	7	2	11	2	0	-2	2	0	0	5.0	12	
i 1	241.0051700680272	1.01	72	101	6	5	16	2	0	-2	2	0	0	3.0	12	
i 1	241.4926530612245	0.505	75	915	4	4	13	2	0	1	2	0	0	5.0	12	
i 1	241.50680272108843	1.5150000000000001	72	101	6	5	4	2	0	1	2	0	0	3.0	12	
i 1	241.5078911564626	0.2525	72	417	5	5	9	2	0	1	2	0	0	3.0	12	
i 1	241.74156462585034	0.2525	74	915	4	24	13	2	0	-2	2	0	0	4.0	12	
i 1	241.99755102040817	2.2725	72	915	5	5	3	2	0	-2	2	0	0	3.0	12	
i 1	242.25897959183675	0.2525	72	915	5	5	2	2	0	1	2	0	0	3.0	12	
i 1	242.503537414966	0.2525	72	417	6	5	2	2	0	1	2	0	0	3.0	12	
i 1	242.50680272108843	0.505	72	417	5	9	3	2	0	1	2	0	0	4.0	12	
i 1	242.74591836734695	1.01	75	915	5	3	14	2	0	1	2	0	0	5.0	12	
i 1	242.75136054421768	0.505	72	417	5	5	14	2	0	1	2	0	0	3.0	12	
i 1	242.99319727891157	1.7675	63	915	1	27	2	1	0	252	1	307	0	2.6802591470793242	12	
i 1	242.99700680272107	0.2525	72	915	5	3	3	2	0	-2	2	0	0	5.0	12	
i 1	243.49374149659863	0.505	72	915	5	3	8	2	0	-2	2	0	0	5.0	12	
i 1	243.4948299319728	0.505	75	915	5	5	2	2	0	-2	2	0	0	3.0	12	
i 1	243.98721088435374	0.2525	74	417	4	24	7	2	0	-2	2	0	0	4.0	14	
i 1	243.9877551020408	0.2525	75	417	5	9	3	2	0	-2	2	0	0	4.0	14	
i 1	243.9948299319728	0.505	72	417	5	5	11	2	0	1	2	0	0	3.0	14	
i 1	244.01333333333332	0.2525	75	915	4	4	12	2	0	1	2	0	0	5.0	14	
i 1	244.2617006802721	0.505	72	101	6	5	14	2	0	-2	2	0	0	3.0	14	
i 1	244.49755102040817	0.2525	63	915	1	27	2	16	0	248	16	308	0	2.6802591470793242	15	
i 1	244.49972789115645	0.7575000000000001	74	417	4	24	1	2	0	-2	2	0	0	4.0	15	
i 1	244.50136054421768	1.5150000000000001	75	915	4	4	7	2	0	1	2	0	0	5.0	15	
i 1	244.7382993197279	0.2525	75	915	5	5	1	2	0	-2	2	0	0	3.0	16	
i 1	244.73938775510203	0.2525	71	599	4	24	9	8	0	-1	8	0	0	3.0	16	
i 1	244.74156462585034	0.2525	72	417	5	5	12	2	0	1	2	0	0	3.0	16	
i 1	244.746462585034	1.2625	63	599	1	27	12	1	0	252	1	307	0	2.6802591470793242	16	
i 1	244.7622448979592	1.2625	63	599	1	27	5	16	0	252	16	307	0	2.6802591470793242	16	
i 1	244.99319727891157	0.505	75	915	5	3	8	2	0	1	2	0	0	5.0	16	
i 1	244.99374149659863	0.505	72	599	4	5	8	2	0	-2	2	0	0	3.0	16	
i 1	244.99809523809523	0.2525	74	599	3	24	13	2	0	-2	2	0	0	4.0	16	
i 1	245.26115646258503	0.505	75	915	6	2	1	2	0	-2	2	0	0	5.0	16	
i 1	245.48666666666668	0.505	71	599	4	24	11	8	0	-1	8	0	0	3.0	16	
i 1	245.503537414966	0.2525	75	599	5	5	9	2	0	1	2	0	0	3.0	16	
i 1	245.7491836734694	0.2525	75	599	4	4	2	2	0	-2	2	0	0	5.0	16	
i 1	245.75299319727893	0.2525	72	417	5	5	7	2	0	1	2	0	0	3.0	16	
i 1	245.7622448979592	0.2525	75	915	5	3	10	2	0	1	2	0	0	5.0	16	
i 1	245.9877551020408	4.545	63	915	5	14	12	16	0	1	16	0	0	4.807581383442391	16	
i 1	245.99591836734695	0.2525	75	915	4	4	1	2	0	1	2	0	0	11.0	16	
i 1	246.00027210884355	5.555	63	915	5	14	8	1	0	1	1	0	0	4.807581383442391	16	
i 1	246.01333333333332	5.555	63	915	5	13	4	1	0	2	1	0	0	0.5737246101975074	16	
i 1	246.25625850340137	0.505	72	417	5	5	14	2	0	1	2	0	0	3.0	16	
i 1	246.2595238095238	2.02	72	915	6	2	1	8	0	-2	8	0	0	11.0	16	
i 1	246.49700680272107	0.2525	75	599	5	3	7	2	0	-2	2	0	0	11.0	16	
i 1	246.49755102040817	0.505	71	915	1	24	15	2	0	252	2	307	0	4.0	16	
i 1	246.7448299319728	0.7575000000000001	72	417	5	9	15	2	0	1	2	0	0	10.0	17	
i 1	246.75136054421768	0.2525	75	417	5	9	16	2	0	-2	2	0	0	10.0	17	
i 1	246.75571428571428	0.2525	75	599	4	5	6	2	0	1	2	0	0	3.0	17	
i 1	247.01333333333332	0.505	74	417	4	24	1	2	0	-2	2	0	0	4.0	17	
i 1	247.49319727891157	0.505	74	417	3	24	16	2	0	-2	2	0	0	4.0	17	
i 1	247.49537414965985	1.2625	75	915	4	4	8	2	0	1	2	0	0	11.0	17	
i 1	247.5078911564626	1.5150000000000001	72	915	5	5	2	2	0	1	2	0	0	3.0	17	
i 1	247.74700680272107	0.2525	72	417	5	5	12	2	0	1	2	0	0	3.0	17	
i 1	248.0078911564626	0.505	72	599	4	5	10	2	0	-2	2	0	0	3.0	17	
i 1	248.2448299319728	2.525	74	417	3	24	15	2	0	-2	2	0	0	4.0	17	
i 1	248.24972789115645	0.2525	71	599	3	24	7	8	0	-1	8	0	0	3.0	17	
i 1	248.4904761904762	1.5150000000000001	72	915	5	5	1	2	0	-2	2	0	0	3.0	17	
i 1	248.50897959183675	0.2525	75	599	4	4	11	2	0	-2	2	0	0	11.0	17	
i 1	249.0008163265306	0.2525	71	915	4	24	6	8	0	-1	8	0	0	3.0	17	
i 1	249.00843537414966	2.525	63	915	6	17	8	16	0	1	16	0	0	0.6126620377439105	17	
i 1	249.01061224489797	0.7575000000000001	75	599	4	4	4	2	0	-2	2	0	0	11.0	17	
i 1	249.2617006802721	1.2625	72	915	5	5	5	2	0	1	2	0	0	3.0	17	
i 1	249.2617006802721	0.2525	71	599	2	24	13	2	0	-2	2	0	0	4.0	17	
i 1	249.50244897959183	0.2525	71	915	3	24	12	8	0	-2	8	0	0	4.0	17	
i 1	249.51333333333332	1.01	74	599	3	24	9	2	0	-2	2	0	0	4.0	17	
i 1	249.7617006802721	1.7675	72	915	6	2	11	8	0	-2	8	0	0	11.0	17	
i 1	250.2404761904762	0.2525	75	599	4	5	1	2	0	1	2	0	0	3.0	17	
i 1	250.2404761904762	0.2525	74	599	3	24	1	8	0	1	8	0	0	4.0	17	
i 1	250.49156462585034	0.7575000000000001	74	599	1	24	12	2	0	252	2	307	0	4.0	17	
i 1	250.49537414965985	0.505	71	599	4	24	9	8	0	-1	8	0	0	3.0	17	
i 1	250.49537414965985	0.2525	72	599	4	5	4	2	0	-2	2	0	0	3.0	17	
i 1	250.49700680272107	1.01	61	915	6	17	8	16	0	1	16	0	0	0.6126620377439105	17	
i 1	250.503537414966	1.01	63	915	4	14	12	16	0	1	16	0	0	4.807581383442391	17	
i 1	250.75625850340137	0.2525	75	915	4	4	10	2	0	1	2	0	0	11.0	18	
i 1	250.7617006802721	0.7575000000000001	75	915	6	5	6	2	0	-2	2	0	0	3.0	18	
i 1	250.9921088435374	0.2525	72	213	5	5	10	2	0	-2	2	0	0	3.0	19	
i 1	251.00244897959183	0.2525	71	915	4	24	15	8	0	-1	8	0	0	3.0	19	
i 1	251.25136054421768	0.2525	75	213	5	5	5	2	0	-2	2	0	0	3.0	19	
i 1	251.4882993197279	2.02	61	1097	6	17	11	16	0	2	16	0	0	0.6126620377439105	20	
i 1	251.49102040816325	6.565	63	711	1	27	16	1	0	248	1	308	0	1.7868394313862161	20	
i 1	251.49156462585034	1.7675	74	711	2	24	8	8	0	-2	8	0	0	4.0	20	
i 1	251.49319727891157	1.7675	75	711	5	3	7	8	0	1	8	0	0	11.0	20	
i 1	251.4948299319728	0.505	61	1097	6	17	14	1	0	1	1	0	0	0.6126620377439105	20	
i 1	251.49537414965985	6.565	61	711	1	27	15	1	0	252	1	307	0	1.7868394313862161	20	
i 1	251.49537414965985	2.02	61	711	5	13	9	1	0	2	1	0	0	0.5737246101975074	20	
i 1	251.49809523809523	0.505	63	1097	5	14	5	1	0	1	1	0	0	4.807581383442391	20	
i 1	251.49863945578232	5.05	63	1097	4	14	14	16	0	2	16	0	0	4.807581383442391	20	
i 1	251.50136054421768	1.7675	72	711	6	5	11	2	0	-2	2	0	0	3.0	20	
i 1	251.5078911564626	0.7575000000000001	72	1097	6	5	3	2	0	-2	2	0	0	3.0	20	
i 1	251.51006802721088	0.2525	72	213	6	9	8	2	0	-2	2	0	0	10.0	20	
i 1	251.5117006802721	0.505	71	711	3	24	5	2	0	1	2	0	0	4.0	20	
i 1	251.7491836734694	0.2525	75	1097	6	2	11	2	0	-2	2	0	0	11.0	21	
i 1	251.99374149659863	1.2625	71	711	2	24	3	2	0	1	2	0	0	4.0	21	
i 1	251.99374149659863	6.0600000000000005	63	1097	4	14	8	1	0	1	1	0	0	4.807581383442391	21	
i 1	251.99428571428572	0.2525	75	711	4	4	2	2	0	-2	2	0	0	11.0	21	
i 1	252.01006802721088	4.545	61	1097	6	17	7	1	0	1	1	0	0	0.6126620377439105	21	
i 1	252.01061224489797	1.7675	63	711	6	17	6	1	0	2	1	0	0	0.6126620377439105	21	
i 1	252.23666666666668	3.0300000000000002	75	1097	6	2	16	2	0	-2	2	0	0	11.0	21	
i 1	252.2578911564626	0.2525	74	711	2	24	9	2	0	1	2	0	0	4.0	21	
i 1	252.26061224489797	0.505	75	1097	6	5	10	8	0	-2	8	0	0	3.0	21	
i 1	252.5078911564626	0.2525	75	213	5	5	9	2	0	-2	2	0	0	3.0	21	
i 1	252.73938775510203	1.2625	72	1097	6	5	4	2	0	-2	2	0	0	3.0	21	
i 1	252.75299319727893	0.2525	72	213	6	9	6	2	0	-2	2	0	0	10.0	21	
i 1	252.76333333333332	0.7575000000000001	71	213	3	24	8	2	0	1	2	0	0	4.0	21	
i 1	253.01115646258503	0.505	72	711	4	5	16	2	0	-2	2	0	0	3.0	21	
i 1	253.50136054421768	0.2525	63	711	6	17	1	1	0	1	1	0	0	0.6126620377439105	21	
i 1	253.50299319727893	4.545	61	1097	6	17	9	16	0	2	16	0	0	0.6126620377439105	21	
i 1	253.5051700680272	0.2525	61	711	4	13	15	1	0	2	1	0	0	0.5737246101975074	21	
i 1	253.51115646258503	0.505	72	213	5	5	6	2	0	-2	2	0	0	3.0	21	
i 1	253.7426530612245	2.7775	61	599	6	17	7	16	0	2	16	0	0	0.6126620377439105	22	
i 1	253.75136054421768	0.7575000000000001	72	599	6	5	8	8	0	-2	8	0	0	3.0	22	
i 1	253.753537414966	1.2625	61	599	6	17	3	16	0	1	16	0	0	0.6126620377439105	22	
i 1	253.753537414966	1.2625	63	599	6	7	16	1	0	1	1	0	0	3.3962957923607635	22	
i 1	253.75680272108843	4.2925	63	599	4	13	16	16	0	1	16	0	0	0.5737246101975074	22	
i 1	253.76006802721088	1.2625	71	213	3	24	10	2	0	1	2	0	0	4.0	22	
i 1	253.76333333333332	0.2525	72	599	4	4	12	2	0	1	2	0	0	11.0	22	
i 1	253.9926530612245	0.2525	75	213	6	9	8	2	0	-2	2	0	0	10.0	22	
i 1	253.99972789115645	0.7575000000000001	74	711	2	24	8	2	0	1	2	0	0	4.0	22	
i 1	254.0078911564626	0.505	71	711	4	24	8	8	0	-2	8	0	0	3.0	22	
i 1	254.01278911564626	0.505	75	711	5	3	8	2	0	1	2	0	0	11.0	22	
i 1	254.2573469387755	1.7675	72	599	6	5	4	2	0	-2	2	0	0	3.0	22	
i 1	254.49102040816325	0.505	75	1097	6	2	8	2	0	-2	2	0	0	11.0	22	
i 1	254.51006802721088	0.2525	72	213	6	9	8	2	0	-2	2	0	0	10.0	22	
i 1	254.76333333333332	1.01	72	599	5	3	1	2	0	-2	2	0	0	11.0	22	
i 1	254.9904761904762	3.0300000000000002	61	599	6	17	16	16	0	1	16	0	0	0.6126620377439105	22	
i 1	254.99591836734695	3.0300000000000002	63	213	5	18	1	16	0	2	16	0	0	0.6126620377439105	22	
i 1	254.99755102040817	0.2525	72	213	7	5	7	2	0	-2	2	0	0	3.0	22	
i 1	255.01006802721088	1.7675	74	599	4	24	13	8	0	-1	8	0	0	3.0	22	
i 1	255.01115646258503	0.2525	72	213	6	9	12	2	0	-2	2	0	0	10.0	22	
i 1	255.01115646258503	3.0300000000000002	63	599	4	7	15	1	0	1	1	0	0	3.3962957923607635	22	
i 1	255.26115646258503	1.2625	72	599	4	4	16	2	0	1	2	0	0	11.0	22	
i 1	255.48666666666668	2.2725	71	711	2	24	2	2	0	1	2	0	0	4.0	22	
i 1	255.49755102040817	1.01	72	1097	6	5	11	2	0	-2	2	0	0	3.0	22	
i 1	255.51278911564626	0.2525	75	213	7	5	14	2	0	-2	2	0	0	3.0	22	
i 1	255.7377551020408	0.2525	71	711	2	24	7	8	0	1	8	0	0	4.0	22	
i 1	255.7491836734694	0.505	75	1097	6	5	3	8	0	-2	8	0	0	3.0	22	
i 1	255.99863945578232	0.2525	72	599	6	5	2	8	0	-2	8	0	0	3.0	22	
i 1	256.25897959183675	0.2525	75	711	4	5	13	2	0	-2	2	0	0	3.0	22	
i 1	256.4877551020408	1.5150000000000001	61	599	6	17	6	16	0	2	16	0	0	0.6126620377439105	22	
i 1	256.488843537415	1.5150000000000001	71	213	1	24	13	2	0	252	2	307	0	4.0	22	
i 1	256.49210884353744	1.5150000000000001	61	1097	6	17	13	1	0	1	1	0	0	0.6126620377439105	22	
i 1	256.49319727891157	1.5150000000000001	63	1097	5	14	6	16	0	2	16	0	0	4.807581383442391	22	
i 1	256.50190476190477	0.2525	71	711	2	24	10	8	0	1	8	0	0	4.0	22	
i 1	256.503537414966	0.505	75	711	4	4	7	2	0	-2	2	0	0	11.0	22	
i 1	256.5057142857143	1.5150000000000001	63	213	5	18	10	1	0	2	1	0	0	0.6126620377439105	22	
i 1	256.74319727891157	1.2625	75	1097	6	2	16	2	0	-2	2	0	0	11.0	22	
i 1	256.99102040816325	0.2525	72	599	6	5	3	2	0	-2	2	0	0	3.0	22	
i 1	256.99156462585034	0.2525	71	711	2	24	2	8	0	1	8	0	0	4.0	22	
i 1	256.99374149659866	0.2525	72	599	4	4	2	2	0	1	2	0	0	11.0	22	
i 1	257.00027210884355	0.7575000000000001	75	1097	6	5	6	8	0	-2	8	0	0	3.0	22	
i 1	257.00244897959186	0.2525	71	711	4	24	3	8	0	-2	8	0	0	3.0	22	
i 1	257.2366666666667	0.505	74	599	3	24	3	2	0	1	2	0	0	4.0	22	
i 1	257.4948299319728	0.505	74	711	2	24	6	2	0	1	2	0	0	4.0	22	
i 1	257.7382993197279	0.2525	72	599	6	5	7	2	0	-2	2	0	0	3.0	23	
i 1	257.9899319727891	1.5150000000000001	61	90	6	14	7	1	0	1	1	0	0	4.807581383442391	24	
i 1	257.99156462585034	1.2625	75	90	5	5	1	2	0	-2	2	0	0	3.0	24	
i 1	257.9959183673469	1.5150000000000001	61	406	4	13	15	16	0	2	16	0	0	0.5737246101975074	24	
i 1	257.9970068027211	0.505	74	904	2	24	12	2	0	-2	2	0	0	4.0	24	
i 1	257.99755102040814	0.2525	74	904	2	24	3	8	0	-2	8	0	0	4.0	24	
i 1	257.99809523809523	0.505	71	904	2	24	15	2	0	-2	2	0	0	4.0	24	
i 1	258.0013605442177	3.0300000000000002	63	90	7	17	14	1	0	2	1	0	0	0.6126620377439105	24	
i 1	258.0051700680272	6.8175	61	904	1	27	8	16	0	252	16	307	0	1.7868394313862161	24	
i 1	258.00625850340134	3.0300000000000002	63	406	6	17	10	16	0	2	16	0	0	0.6126620377439105	24	
i 1	258.00680272108843	1.5150000000000001	61	406	6	17	15	1	0	2	1	0	0	0.6126620377439105	24	
i 1	258.00680272108843	3.0300000000000002	61	904	4	19	10	1	0	2	1	0	0	0.6126620377439105	24	
i 1	258.00789115646256	1.5150000000000001	61	90	7	17	16	1	0	1	1	0	0	0.6126620377439105	24	
i 1	258.00897959183675	4.545	61	904	4	18	9	16	0	1	16	0	0	0.6126620377439105	24	
i 1	258.0095238095238	3.0300000000000002	61	90	6	14	15	16	0	1	16	0	0	4.807581383442391	24	
i 1	258.01061224489797	1.5150000000000001	61	904	4	18	6	16	0	1	16	0	0	0.6126620377439105	24	
i 1	258.0122448979592	3.0300000000000002	61	406	4	7	1	1	0	2	1	0	0	3.3962957923607635	24	
i 1	258.0127891156463	1.5150000000000001	72	90	7	2	13	2	0	-2	2	0	0	11.0	24	
i 1	258.4970068027211	0.2525	75	90	5	5	16	2	0	1	2	0	0	3.0	25	
i 1	258.5133333333333	0.2525	71	904	2	24	5	2	0	-2	2	0	0	4.0	25	
i 1	258.7399319727891	0.505	74	904	2	24	11	2	0	-2	2	0	0	4.0	26	
i 1	258.746462585034	0.505	75	406	6	5	15	2	0	1	2	0	0	3.0	26	
i 1	258.75680272108843	0.505	72	904	5	9	13	2	0	1	2	0	0	10.0	26	
i 1	259.0029931972789	0.2525	72	904	4	4	7	2	0	1	2	0	0	11.0	26	
i 1	259.2404761904762	0.505	72	904	5	9	15	8	0	-2	8	0	0	10.0	26	
i 1	259.2448299319728	3.7875	74	904	1	24	2	2	0	252	2	307	0	4.0	26	
i 1	259.2453741496599	0.2525	72	904	6	5	4	2	0	-2	2	0	0	3.0	26	
i 1	259.4877551020408	1.5150000000000001	75	406	6	5	16	2	0	1	2	0	0	3.0	26	
i 1	259.4899319727891	3.0300000000000002	61	904	4	19	13	1	0	2	1	0	0	0.6126620377439105	26	
i 1	259.49319727891157	5.3025	61	90	5	14	9	1	0	1	1	0	0	4.807581383442391	26	
i 1	259.50081632653064	4.545	61	904	4	18	8	16	0	1	16	0	0	0.6126620377439105	26	
i 1	259.5057142857143	3.0300000000000002	61	406	6	17	8	1	0	2	1	0	0	0.6126620377439105	26	
i 1	259.50680272108843	5.3025	61	90	6	17	11	1	0	1	1	0	0	0.6126620377439105	26	
i 1	259.50897959183675	3.0300000000000002	61	406	5	13	1	16	0	2	16	0	0	0.5737246101975074	26	
i 1	259.5095238095238	0.2525	74	904	3	24	4	2	0	-2	2	0	0	3.0	26	
i 1	259.7573469387755	0.2525	72	90	6	2	14	2	0	-2	2	0	0	11.0	26	
i 1	259.7633333333333	0.2525	72	904	6	5	15	2	0	1	2	0	0	3.0	26	
i 1	260.011156462585	0.2525	75	904	6	5	10	8	0	-2	8	0	0	3.0	26	
i 1	260.23938775510203	0.2525	74	406	4	24	9	2	0	-1	2	0	0	3.0	26	
i 1	260.74755102040814	0.2525	75	90	5	5	10	2	0	-2	2	0	0	3.0	27	
i 1	260.9904761904762	3.7875	63	90	6	17	8	1	0	2	1	0	0	0.6126620377439105	27	
i 1	260.9904761904762	3.0300000000000002	63	406	6	17	7	16	0	2	16	0	0	0.6126620377439105	27	
i 1	260.99319727891157	3.7875	61	90	5	14	2	16	0	1	16	0	0	4.807581383442391	27	
i 1	260.9953741496599	0.2525	74	904	3	24	2	2	0	-2	2	0	0	3.0	27	
i 1	261.00244897959186	3.7875	61	904	4	19	13	1	0	2	1	0	0	0.6126620377439105	27	
i 1	261.2448299319728	0.2525	75	90	5	5	11	2	0	1	2	0	0	3.0	27	
i 1	261.25897959183675	1.01	72	406	5	3	1	2	0	-2	2	0	0	11.0	27	
i 1	261.2633333333333	0.2525	74	904	2	24	11	8	0	-2	8	0	0	4.0	27	
i 1	261.5117006802721	0.2525	72	904	5	9	15	2	0	1	2	0	0	10.0	27	
i 1	261.7529931972789	2.7775	72	90	6	2	16	2	0	-2	2	0	0	11.0	27	
i 1	261.9926530612245	0.505	72	904	6	5	6	2	0	-2	2	0	0	3.0	27	
i 1	262.2442857142857	0.2525	75	406	4	5	9	2	0	1	2	0	0	3.0	27	
i 1	262.25680272108843	0.2525	72	90	6	2	2	2	0	-2	2	0	0	11.0	27	
i 1	262.49156462585034	2.2725	61	406	4	13	16	16	0	2	16	0	0	0.5737246101975074	27	
i 1	262.50081632653064	1.01	75	90	5	5	6	2	0	-2	2	0	0	3.0	27	
i 1	262.5046258503401	3.0300000000000002	61	904	4	18	2	16	0	1	16	0	0	0.6126620377439105	27	
i 1	262.5051700680272	2.2725	61	406	5	17	1	1	0	2	1	0	0	0.6126620377439105	27	
i 1	262.5057142857143	2.2725	61	904	4	19	9	1	0	2	1	0	0	0.6126620377439105	27	
i 1	262.74918367346936	0.2525	75	904	6	5	12	2	0	1	2	0	0	3.0	27	
i 1	262.9872108843537	0.2525	71	904	2	24	14	2	0	-2	2	0	0	4.0	27	
i 1	263.24319727891157	0.505	72	904	3	5	10	2	0	1	2	0	0	3.0	27	
i 1	263.2470068027211	1.2625	75	90	5	5	3	2	0	1	2	0	0	3.0	27	
i 1	263.49374149659866	0.2525	75	904	5	3	13	8	0	1	8	0	0	11.0	27	
i 1	263.7513605442177	0.505	72	904	5	9	4	2	0	1	2	0	0	10.0	27	
i 1	263.7546258503401	0.2525	72	406	4	5	3	2	0	1	2	0	0	3.0	27	
i 1	263.99210884353744	0.7575000000000001	75	406	4	5	14	2	0	1	2	0	0	3.0	27	
i 1	263.9942857142857	1.7675	61	904	4	18	7	16	0	1	16	0	0	0.6126620377439105	27	
i 1	263.9959183673469	0.7575000000000001	63	406	5	17	13	16	0	2	16	0	0	0.6126620377439105	27	
i 1	263.99972789115645	0.7575000000000001	75	406	4	4	3	2	0	1	2	0	0	11.0	27	
i 1	264.00081632653064	0.7575000000000001	61	406	4	7	14	1	0	2	1	0	0	3.3962957923607635	27	
i 1	264.49156462585034	0.2525	72	904	5	9	5	2	0	1	2	0	0	10.0	27	
i 1	264.4948299319728	0.2525	75	904	6	5	12	8	0	-2	8	0	0	3.0	27	
i 1	264.496462585034	0.2525	75	90	5	5	4	2	0	-2	2	0	0	3.0	27	
i 1	264.7366666666667	1.01	61	202	6	17	11	16	0	2	16	0	0	0.6126620377439105	28	
i 1	264.7366666666667	1.01	63	588	5	17	14	16	0	1	16	0	0	0.6126620377439105	28	
i 1	264.7372108843537	1.01	63	202	1	27	2	1	0	252	1	307	0	1.7868394313862161	28	
i 1	264.7399319727891	0.7575000000000001	61	202	5	19	13	16	0	2	16	0	0	0.6126620377439105	28	
i 1	264.7442857142857	1.01	63	202	5	19	9	1	0	2	1	0	0	0.6126620377439105	28	
i 1	264.7459183673469	0.2525	75	202	7	5	7	2	0	-2	2	0	0	3.0	28	
i 1	264.7486394557823	1.01	61	588	4	7	6	16	0	2	16	0	0	3.3962957923607635	28	
i 1	264.7529931972789	1.01	71	202	2	24	2	2	0	1	2	0	0	4.0	28	
i 1	264.7546258503401	0.505	72	202	5	5	8	2	0	-2	2	0	0	3.0	28	
i 1	264.75625850340134	0.7575000000000001	61	202	6	17	2	1	0	2	1	0	0	0.6126620377439105	28	
i 1	264.7573469387755	1.01	61	202	5	14	16	1	0	2	1	0	0	4.807581383442391	28	
i 1	264.75843537414966	1.01	63	588	5	17	8	16	0	2	16	0	0	0.6126620377439105	28	
i 1	264.75897959183675	0.7575000000000001	71	588	4	24	11	2	0	-2	2	0	0	3.0	28	
i 1	264.7595238095238	1.01	63	202	1	27	10	16	0	252	16	307	0	1.7868394313862161	28	
i 1	264.761156462585	0.2525	71	202	2	24	15	2	0	-2	2	0	0	4.0	28	
i 1	264.7617006802721	1.01	75	202	6	2	7	2	0	-2	2	0	0	11.0	28	
i 1	264.7617006802721	1.01	61	202	5	14	3	16	0	1	16	0	0	4.807581383442391	28	
i 1	264.7633333333333	1.01	61	588	4	13	2	16	0	1	16	0	0	0.5737246101975074	28	
i 1	265.2617006802721	0.505	72	202	5	3	7	2	0	-2	2	0	0	11.0	29	
i 1	265.4882993197279	0.2525	61	904	4	18	9	16	0	1	16	0	0	0.6126620377439105	30	
i 1	265.4904761904762	0.2525	74	202	2	24	10	2	0	-2	2	0	0	4.0	30	
i 1	265.5051700680272	0.2525	61	202	7	17	8	1	0	2	1	0	0	0.6126620377439105	30	
i 1	265.5127891156463	0.2525	61	202	5	19	4	16	0	2	16	0	0	0.6126620377439105	30	
i 1	265.74156462585034	0.2525	77	901	4	24	3	17	0	2	17	0	0	3.0	128	
i 1	265.74755102040814	0.2525	74	87	6	9	5	16	0	1	16	0	0	13.0	128	
i 1	265.75027210884355	0.2525	71	585	6	5	12	2	0	-2	2	0	0	3.0	128	
i 1	265.7551700680272	0.505	74	895	6	5	4	16	5001	1	16	0	0	3.0	128	
i 1	265.7557142857143	0.2525	66	901	4	12	16	9	0	0	9	0	0	3.404153879908992	128	
i 1	265.7595238095238	0.2525	74	585	6	5	15	8	0	-1	8	0	0	3.0	128	
i 1	266.003537414966	0.505	74	585	6	5	12	8	0	-1	8	0	0	3.0	129	
i 1	266.2426530612245	0.2525	69	895	5	2	5	0	5001	-1	0	0	0	14.0	129	
i 1	266.26061224489797	0.2525	70	895	2	20	9	8	5001	-1	8	0	0	0.14096973566733428	129	
i 1	266.488843537415	0.2525	74	1066	5	5	16	2	0	-1	2	0	0	3.0	130	
i 1	266.5040816326531	2.2725	71	750	6	5	2	8	0	-2	8	0	0	3.0	130	
i 1	266.5040816326531	1.2625	73	1066	2	20	14	2	0	-2	2	0	0	0.14096973566733428	130	
i 1	266.7377551020408	0.2525	74	750	4	5	13	8	0	-1	8	0	0	3.0	131	
i 1	266.7540816326531	0.2525	70	750	2	24	3	8	0	-2	8	0	0	4.140969735667334	131	
i 1	266.7595238095238	0.7575000000000001	77	750	4	4	16	17	0	2	17	0	0	14.0	131	
i 1	266.7633333333333	0.7575000000000001	74	750	6	5	6	2	0	-1	2	0	0	3.0	131	
i 1	267.011156462585	1.2625	73	1066	1	20	3	2	0	-1	2	0	0	0.14096973566733428	131	
i 1	267.2404761904762	1.5150000000000001	70	1066	2	24	1	8	0	-1	8	0	0	4.140969735667334	131	
i 1	267.26061224489797	0.2525	77	1066	5	2	11	16	0	2	16	0	0	14.0	131	
i 1	267.4942857142857	1.01	77	1066	5	2	8	16	0	1	16	0	0	14.0	131	
i 1	267.4953741496599	0.2525	74	750	6	5	11	2	0	-1	2	0	0	3.0	131	
i 1	267.50625850340134	0.2525	74	750	4	4	4	17	0	2	17	0	0	14.0	131	
i 1	267.9953741496599	0.2525	74	1066	6	5	5	8	0	-1	8	0	0	3.0	131	
i 1	268.2426530612245	0.505	70	750	2	24	11	8	0	-1	8	0	0	4.140969735667334	131	
i 1	268.2459183673469	0.505	73	1066	2	20	16	2	0	-1	2	0	0	0.14096973566733428	131	
i 1	268.2486394557823	0.505	70	750	2	20	2	2	0	-1	2	0	0	0.14096973566733428	131	
i 1	268.261156462585	0.505	74	750	6	5	8	2	0	-1	2	0	0	3.0	131	
i 1	268.5073469387755	0.2525	70	1066	2	20	10	8	0	-2	8	0	0	0.14096973566733428	131	
i 1	268.5127891156463	0.2525	74	750	4	24	4	16	0	2	16	0	0	3.0	131	
i 1	268.74156462585034	2.02	70	896	1	20	6	2	0	-1	2	0	0	0.14096973566733428	132	
i 1	268.7470068027211	1.7675	74	896	4	24	16	16	0	2	16	0	0	3.0	132	
i 1	268.75081632653064	1.01	77	82	6	2	6	17	0	1	17	0	0	14.0	132	
i 1	268.75190476190477	0.505	74	82	7	5	3	8	0	-2	8	0	0	3.0	132	
i 1	268.75244897959186	2.525	73	580	2	24	4	8	0	-1	8	0	0	4.140969735667334	132	
i 1	268.9899319727891	1.01	74	896	4	4	6	17	0	2	17	0	0	14.0	132	
i 1	268.99755102040814	4.7975	61	82	6	14	12	9	0	1	9	0	0	6.342727492532905	132	
i 1	269.496462585034	0.2525	77	580	4	24	8	17	0	1	17	0	0	3.0	132	
i 1	269.74918367346936	0.2525	74	896	6	5	1	8	0	-2	8	0	0	3.0	132	
i 1	269.99319727891157	0.505	71	896	6	5	12	2	0	-2	2	0	0	3.0	132	
i 1	270.011156462585	0.2525	77	580	5	3	6	16	0	1	16	0	0	14.0	132	
i 1	270.5040816326531	0.505	74	896	6	5	4	8	0	-2	8	0	0	3.0	132	
i 1	270.5117006802721	3.0300000000000002	71	82	7	5	1	2	0	-1	2	0	0	3.0	132	
i 1	270.7453741496599	1.2625	73	896	2	20	4	8	0	-1	8	0	0	0.14096973566733428	132	
i 1	271.00244897959186	0.505	71	896	6	5	5	2	0	-1	2	0	0	3.0	132	
i 1	271.00680272108843	0.7575000000000001	70	896	1	20	15	8	0	-1	8	0	0	0.14096973566733428	132	
i 1	271.24374149659866	0.7575000000000001	74	580	5	5	7	8	0	-2	8	0	0	3.0	132	
i 1	271.25244897959186	0.2525	70	580	2	24	15	2	0	-2	2	0	0	4.140969735667334	132	
i 1	271.4882993197279	0.7575000000000001	70	896	1	24	14	2	0	-1	2	0	0	4.140969735667334	132	
i 1	271.511156462585	0.2525	71	896	6	5	4	2	0	-1	2	0	0	3.0	132	
i 1	271.75789115646256	0.2525	74	580	5	5	14	8	0	-2	8	0	0	3.0	132	
i 1	271.7633333333333	1.5150000000000001	73	580	2	24	8	8	0	-1	8	0	0	4.140969735667334	132	
i 1	271.99102040816325	0.505	71	896	6	5	14	2	0	-1	2	0	0	3.0	132	
i 1	271.99918367346936	1.7675	66	896	5	15	15	9	0	0	9	0	0	0.46558026728507906	132	
i 1	272.0013605442177	0.2525	77	896	5	9	8	16	0	2	16	0	0	13.0	132	
i 1	272.0029931972789	1.2625	74	82	7	5	6	8	0	-2	8	0	0	3.0	132	
i 1	272.00789115646256	0.505	70	896	1	20	15	8	0	-2	8	0	0	0.14096973566733428	132	
i 1	272.0095238095238	0.2525	77	580	3	24	5	17	0	1	17	0	0	3.0	132	
i 1	272.5040816326531	0.505	73	896	2	20	8	2	0	-2	2	0	0	0.14096973566733428	132	
i 1	272.511156462585	0.2525	74	896	6	5	15	8	0	-2	8	0	0	3.0	132	
i 1	272.746462585034	0.2525	77	896	5	9	2	16	0	2	16	0	0	13.0	133	
i 1	272.74809523809523	1.01	73	896	1	20	8	8	0	-1	8	0	0	0.14096973566733428	133	
i 1	272.7486394557823	0.2525	71	896	6	5	7	2	0	-1	2	0	0	3.0	133	
i 1	273.0117006802721	0.7575000000000001	71	896	6	5	6	2	0	-2	2	0	0	3.0	134	
i 1	273.2448299319728	0.505	70	896	1	24	12	2	0	-1	2	0	0	4.140969735667334	134	
i 1	273.24809523809523	0.2525	74	896	6	5	14	8	0	-2	8	0	0	3.0	134	
i 1	273.25190476190477	0.2525	74	896	4	24	12	16	0	2	16	0	0	3.0	134	
i 1	273.50244897959186	0.2525	66	896	5	15	14	6	0	1	6	0	0	0.46558026728507906	135	
i 1	273.503537414966	0.2525	70	580	2	24	16	2	0	-2	2	0	0	4.140969735667334	135	
i 1	273.50789115646256	0.2525	71	896	6	5	13	2	0	-1	2	0	0	3.0	135	
i 1	273.50843537414966	0.2525	71	82	7	5	13	2	0	-1	2	0	0	3.0	135	
i 1	273.7399319727891	0.505	74	82	5	4	5	16	0	2	16	0	0	14.0	136	
i 1	273.7426530612245	6.8175	61	82	6	14	10	9	0	1	9	0	0	6.342727492532905	136	
i 1	273.74374149659866	0.7575000000000001	77	398	5	3	7	16	0	2	16	0	0	14.0	136	
i 1	273.75081632653064	0.505	73	82	2	24	4	8	0	-1	8	0	0	4.140969735667334	136	
i 1	273.75190476190477	11.8675	61	398	5	15	10	6	0	1	6	0	0	0.46558026728507906	136	
i 1	273.7551700680272	10.352500000000001	61	398	5	15	10	9	0	0	9	0	0	0.46558026728507906	136	
i 1	273.75843537414966	0.2525	77	82	7	2	12	16	0	2	16	0	0	14.0	136	
i 1	273.75897959183675	0.2525	70	896	1	20	1	8	0	-2	8	0	0	0.14096973566733428	136	
i 1	273.7633333333333	0.2525	73	896	1	20	15	2	0	-2	2	0	0	0.14096973566733428	136	
i 1	273.7633333333333	0.2525	70	896	1	24	3	2	0	-2	2	0	0	4.140969735667334	136	
i 1	273.99210884353744	1.01	74	82	7	2	6	16	0	1	16	0	0	14.0	136	
i 1	274.25081632653064	0.7575000000000001	70	896	1	24	12	2	0	-2	2	0	0	4.140969735667334	136	
i 1	274.25680272108843	0.2525	77	896	4	9	16	16	0	1	16	0	0	13.0	136	
i 1	274.5117006802721	3.0300000000000002	70	82	1	24	6	8	0	-2	8	0	0	4.140969735667334	136	
i 1	274.738843537415	0.2525	71	896	6	5	2	2	0	-1	2	0	0	3.0	136	
i 1	274.9866666666667	0.2525	73	82	3	20	1	2	0	-1	2	0	0	0.14096973566733428	136	
i 1	274.9970068027211	12.120000000000001	66	896	4	16	8	9	0	0	9	0	0	3.404153879908992	136	
i 1	274.99972789115645	0.7575000000000001	71	82	6	5	10	8	0	-1	8	0	0	3.0	136	
i 1	275.23938775510203	0.2525	71	82	6	5	4	8	0	-1	8	0	0	3.0	136	
i 1	275.253537414966	0.505	70	896	1	20	3	2	0	-2	2	0	0	0.14096973566733428	136	
i 1	275.25897959183675	0.2525	77	82	7	2	14	16	0	2	16	0	0	14.0	136	
i 1	275.4882993197279	0.2525	74	398	4	24	6	16	0	1	16	0	0	3.0	136	
i 1	275.5095238095238	0.7575000000000001	70	896	1	24	3	2	0	-2	2	0	0	4.140969735667334	136	
i 1	275.7448299319728	0.2525	73	82	3	20	4	8	0	-1	8	0	0	0.14096973566733428	137	
i 1	276.2529931972789	0.2525	71	896	6	5	11	2	0	-2	2	0	0	3.0	137	
i 1	276.2622448979592	0.7575000000000001	74	82	3	24	6	16	0	2	16	0	0	3.0	137	
i 1	276.4872108843537	0.505	71	82	7	5	16	8	0	-1	8	0	0	3.0	137	
i 1	276.511156462585	10.605	66	896	4	16	11	6	0	1	6	0	0	3.404153879908992	137	
i 1	276.9866666666667	0.2525	71	82	7	5	1	2	0	-1	2	0	0	3.0	137	
i 1	276.9866666666667	3.7875	73	896	1	20	6	2	0	-1	2	0	0	0.14096973566733428	137	
i 1	277.00081632653064	0.7575000000000001	70	896	1	20	5	8	0	-2	8	0	0	0.14096973566733428	137	
i 1	277.25244897959186	0.7575000000000001	77	82	7	2	7	16	0	2	16	0	0	14.0	137	
i 1	277.2557142857143	0.2525	74	896	5	9	3	17	0	2	17	0	0	13.0	137	
i 1	277.25789115646256	0.2525	71	82	7	5	9	8	0	-1	8	0	0	3.0	137	
i 1	277.74374149659866	0.2525	70	82	3	20	3	8	0	-2	8	0	0	0.14096973566733428	137	
i 1	277.7448299319728	0.2525	71	82	7	5	5	2	0	-1	2	0	0	3.0	137	
i 1	277.99755102040814	1.7675	61	82	5	12	15	6	0	0	6	0	0	3.404153879908992	137	
i 1	277.99972789115645	0.2525	73	896	1	20	12	2	0	-2	2	0	0	0.14096973566733428	137	
i 1	278.0040816326531	2.525	71	82	7	5	9	2	0	-1	2	0	0	3.0	137	
i 1	278.0040816326531	1.01	73	82	1	20	8	2	0	-1	2	0	0	0.14096973566733428	137	
i 1	278.0046258503401	0.2525	77	82	7	2	13	16	0	2	16	0	0	14.0	137	
i 1	278.0117006802721	0.2525	77	896	5	9	14	16	0	1	16	0	0	13.0	137	
i 1	278.2382993197279	2.02	73	896	1	20	6	8	0	-2	8	0	0	0.14096973566733428	137	
i 1	278.24319727891157	0.2525	74	82	7	2	5	16	0	1	16	0	0	14.0	137	
i 1	278.2486394557823	0.505	74	398	4	4	5	17	0	1	17	0	0	14.0	137	
i 1	278.5073469387755	0.505	74	82	4	4	5	16	0	2	16	0	0	14.0	137	
i 1	278.50897959183675	0.7575000000000001	71	82	7	5	13	8	0	-1	8	0	0	3.0	137	
i 1	278.75680272108843	0.2525	77	896	5	9	4	16	0	1	16	0	0	13.0	137	
i 1	278.9970068027211	0.505	74	398	6	5	2	2	0	-1	2	0	0	3.0	137	
i 1	279.0051700680272	1.01	77	82	7	2	1	16	0	2	16	0	0	14.0	137	
i 1	279.2442857142857	0.7575000000000001	71	896	5	5	14	2	0	-1	2	0	0	3.0	137	
i 1	279.49374149659866	1.2625	77	398	5	3	16	16	0	2	16	0	0	14.0	137	
i 1	279.5046258503401	0.2525	71	398	6	5	10	8	0	-2	8	0	0	3.0	137	
i 1	279.5095238095238	0.2525	61	82	5	12	15	6	0	0	6	0	0	3.404153879908992	137	
i 1	279.7366666666667	0.7575000000000001	66	194	5	12	5	6	0	1	6	0	0	3.404153879908992	138	
i 1	279.738843537415	0.2525	74	398	6	5	2	2	0	-1	2	0	0	3.0	138	
i 1	279.75081632653064	0.7575000000000001	61	194	5	12	11	9	0	1	9	0	0	3.404153879908992	138	
i 1	280.01061224489797	1.7675	74	398	4	24	10	16	0	1	16	0	0	3.0	139	
i 1	280.23938775510203	0.2525	70	194	1	24	5	2	0	-2	2	0	0	4.140969735667334	139	
i 1	280.2540816326531	0.7575000000000001	74	398	4	4	4	17	0	1	17	0	0	14.0	139	
i 1	280.496462585034	0.2525	71	398	6	5	1	8	0	-2	8	0	0	3.0	140	
i 1	280.5013605442177	6.565	66	398	5	12	11	6	0	1	6	0	0	3.404153879908992	140	
i 1	280.50244897959186	6.565	61	398	5	12	6	9	0	1	9	0	0	3.404153879908992	140	
i 1	280.503537414966	0.505	66	1100	5	14	1	6	0	0	6	0	0	6.342727492532905	140	
i 1	280.511156462585	1.7675	73	398	1	24	1	2	0	-1	2	0	0	4.140969735667334	140	
i 1	280.7382993197279	0.2525	77	1100	6	2	5	16	0	2	16	0	0	14.0	141	
i 1	280.7404761904762	0.505	71	896	5	5	6	2	0	-2	2	0	0	3.0	141	
i 1	280.9953741496599	0.2525	74	398	6	5	12	2	0	-1	2	0	0	3.0	141	
i 1	281.00081632653064	0.2525	73	896	1	20	10	8	0	-2	8	0	0	0.14096973566733428	141	
i 1	281.0046258503401	0.2525	74	896	5	9	2	17	0	2	17	0	0	13.0	141	
i 1	281.0117006802721	1.7675	66	1100	5	14	9	6	0	0	6	0	0	6.342727492532905	141	
i 1	281.24918367346936	0.2525	71	896	5	5	9	2	0	-1	2	0	0	3.0	141	
i 1	281.25897959183675	0.2525	71	398	5	5	3	8	0	-1	8	0	0	3.0	141	
i 1	281.50680272108843	1.01	77	398	5	3	4	16	0	2	16	0	0	14.0	141	
i 1	281.75081632653064	0.2525	77	1100	6	2	1	16	0	1	16	0	0	14.0	141	
i 1	281.7600680272109	1.5150000000000001	73	896	1	20	2	2	0	-1	2	0	0	0.14096973566733428	141	
i 1	281.99102040816325	1.01	74	398	6	5	9	2	0	-1	2	0	0	3.0	141	
i 1	281.99102040816325	0.2525	70	398	1	20	7	8	0	-2	8	0	0	0.14096973566733428	141	
i 1	281.9948299319728	0.505	73	896	1	20	3	8	0	-2	8	0	0	0.14096973566733428	141	
i 1	281.9953741496599	0.7575000000000001	77	1100	6	2	10	16	0	2	16	0	0	14.0	141	
i 1	282.4866666666667	0.2525	70	1100	2	20	8	2	0	-1	2	0	0	0.14096973566733428	141	
i 1	282.75081632653064	1.2625	66	896	5	14	9	9	0	0	9	0	0	6.342727492532905	142	
i 1	282.75190476190477	1.7675	73	896	1	20	1	8	0	-2	8	0	0	0.14096973566733428	142	
i 1	282.75843537414966	0.2525	77	896	6	2	7	17	0	1	17	0	0	14.0	142	
i 1	283.2557142857143	0.2525	70	398	1	20	8	8	0	-2	8	0	0	0.14096973566733428	142	
i 1	283.4948299319728	0.2525	70	896	1	20	10	8	0	-1	8	0	0	0.14096973566733428	142	
i 1	284.00789115646256	3.0300000000000002	61	398	5	15	5	9	0	0	9	0	0	0.46558026728507906	142	
i 1	284.00843537414966	1.5150000000000001	70	398	1	24	5	8	0	-1	8	0	0	4.140969735667334	142	
i 1	284.488843537415	0.2525	71	896	5	5	16	8	0	-2	8	0	0	3.0	142	
i 1	284.49156462585034	0.2525	77	896	6	2	16	17	0	1	17	0	0	14.0	142	
i 1	284.49210884353744	0.2525	73	896	2	20	13	8	0	-2	8	0	0	0.14096973566733428	142	
i 1	284.496462585034	2.7775	71	398	5	5	10	8	0	-2	8	0	0	3.0	142	
i 1	284.5073469387755	0.505	77	398	4	4	13	16	0	2	16	0	0	14.0	142	
i 1	284.753537414966	0.505	71	896	5	5	11	2	0	-2	2	0	0	3.0	142	
i 1	284.7540816326531	0.7575000000000001	70	398	1	20	4	8	0	-2	8	0	0	0.14096973566733428	142	
i 1	285.003537414966	0.2525	77	896	5	9	6	16	0	1	16	0	0	13.0	142	
i 1	285.2573469387755	0.7575000000000001	71	896	5	5	10	8	0	-2	8	0	0	3.0	142	
i 1	285.49809523809523	1.5150000000000001	61	398	5	15	9	6	0	1	6	0	0	0.46558026728507906	142	
i 1	285.7372108843537	0.505	77	398	4	4	7	16	0	2	16	0	0	14.0	142	
i 1	285.7459183673469	0.2525	74	398	4	4	1	17	0	1	17	0	0	14.0	142	
i 1	285.99319727891157	0.2525	71	896	5	5	11	2	0	-1	2	0	0	3.0	142	
i 1	286.00680272108843	0.505	71	398	5	5	14	8	0	-1	8	0	0	3.0	142	
i 1	286.23938775510203	0.2525	70	398	2	24	3	2	0	-1	2	0	0	4.0	142	
i 1	286.25081632653064	0.2525	74	398	5	5	7	2	0	-1	2	0	0	3.0	142	
i 1	286.4872108843537	0.505	71	896	5	5	2	8	0	-1	8	0	0	3.0	142	
i 1	286.73938775510203	0.2525	77	896	6	2	13	17	0	1	17	0	0	14.0	143	
i 1	286.74156462585034	0.2525	77	896	5	9	4	16	0	1	16	0	0	13.0	143	
i 1	286.74156462585034	0.2525	71	896	5	5	9	2	0	-1	2	0	0	3.0	143	
i 1	286.9882993197279	0.2525	74	398	4	4	14	17	0	1	17	0	0	4.0	144	
i 1	286.99102040816325	1.5150000000000001	61	398	3	27	2	6	0	1	6	0	0	3.5736788627724323	144	
i 1	286.9942857142857	0.7575000000000001	61	1100	5	14	10	6	0	1	6	0	0	5.036324277358435	144	
i 1	287.00190476190477	0.7575000000000001	66	1100	5	14	7	9	0	1	9	0	0	5.036324277358435	144	
i 1	287.00897959183675	0.7575000000000001	74	398	5	5	3	2	0	-1	2	0	0	3.0	144	
i 1	287.0117006802721	0.7575000000000001	61	398	5	13	16	9	0	0	9	0	0	0.8024675041135513	144	
i 1	287.261156462585	0.505	74	1100	5	5	12	2	0	-2	2	0	0	3.0	144	
i 1	287.7377551020408	1.7675	74	1099	5	5	15	8	0	-2	8	0	0	3.0	146	
i 1	287.7382993197279	0.505	77	166	5	4	11	17	0	2	17	0	0	4.0	146	
i 1	287.738843537415	3.7875	66	166	6	13	3	9	0	0	9	0	0	0.8024675041135513	146	
i 1	287.74156462585034	0.2525	71	398	5	5	9	8	0	-2	8	0	0	3.0	146	
i 1	287.74809523809523	0.7575000000000001	74	1099	6	2	4	16	0	1	16	0	0	4.0	146	
i 1	287.7529931972789	0.505	74	166	5	24	4	16	0	1	16	0	0	6.10723839815053	146	
i 1	287.753537414966	0.2525	77	1099	6	2	3	16	0	2	16	0	0	4.0	146	
i 1	287.7551700680272	2.2725	66	1099	5	14	11	9	0	1	9	0	0	5.036324277358435	146	
i 1	287.75843537414966	0.2525	74	166	5	5	5	2	0	-1	2	0	0	3.0	146	
i 1	287.7627891156463	0.7575000000000001	66	1099	5	14	10	9	0	1	9	0	0	5.036324277358435	146	
i 1	287.9986394557823	2.525	74	166	6	3	3	16	0	2	16	0	0	4.0	146	
i 1	288.0073469387755	0.505	71	398	5	5	16	8	0	-1	8	0	0	3.0	146	
i 1	288.49755102040814	0.505	74	784	4	5	8	8	0	-1	8	0	0	3.0	146	
i 1	288.50625850340134	0.7575000000000001	74	784	6	1	15	17	0	1	17	0	0	3.10723839815053	146	
i 1	288.5127891156463	5.3025	66	1099	5	14	12	9	0	1	9	0	0	5.036324277358435	146	
i 1	288.9948299319728	0.2525	77	1099	6	2	5	16	0	2	16	0	0	4.0	146	
i 1	289.0127891156463	1.01	74	166	5	24	15	16	0	1	16	0	0	6.10723839815053	146	
i 1	289.0127891156463	0.2525	71	398	5	5	13	8	0	-2	8	0	0	3.0	146	
i 1	289.23938775510203	0.2525	74	398	5	3	8	17	0	2	17	0	0	4.0	146	
i 1	289.24972789115645	0.505	77	398	4	24	5	16	0	2	16	0	0	6.10723839815053	146	
i 1	289.49972789115645	0.505	74	166	5	5	6	2	0	-1	2	0	0	3.0	146	
i 1	289.74972789115645	0.2525	71	398	5	5	14	8	0	-1	8	0	0	3.0	147	
i 1	289.7529931972789	0.7575000000000001	70	398	1	24	15	2	0	252	2	307	0	4.0	147	
i 1	289.7551700680272	0.2525	77	1099	6	1	11	16	0	2	16	0	0	3.10723839815053	147	
i 1	289.99319727891157	1.5150000000000001	74	1099	6	2	12	16	0	1	16	0	0	4.0	147	
i 1	290.00081632653064	0.2525	70	398	1	24	14	8	0	-1	8	0	0	4.0	147	
i 1	290.00244897959186	0.7575000000000001	74	166	5	24	2	16	0	1	16	0	0	6.10723839815053	147	
i 1	290.0040816326531	0.505	74	166	6	1	5	17	0	2	17	0	0	3.10723839815053	147	
i 1	290.0046258503401	0.2525	74	398	6	1	14	16	0	1	16	0	0	3.10723839815053	147	
i 1	290.0100680272109	3.7875	66	1099	5	14	12	9	0	1	9	0	0	5.036324277358435	147	
i 1	290.25081632653064	3.535	77	1099	6	1	15	16	0	2	16	0	0	3.10723839815053	147	
i 1	290.2595238095238	0.505	77	166	5	4	13	17	0	2	17	0	0	4.0	147	
i 1	290.2633333333333	3.535	70	398	1	24	12	8	0	252	8	307	0	4.0	147	
i 1	290.49156462585034	0.505	71	784	4	5	10	2	0	-2	2	0	0	3.0	147	
i 1	290.49210884353744	0.2525	77	784	5	9	15	17	0	1	17	0	0	3.0	147	
i 1	290.50081632653064	1.01	73	784	1	24	7	8	0	-1	8	0	0	4.0	147	
i 1	290.7573469387755	0.2525	74	784	5	9	6	17	0	2	17	0	0	3.0	147	
i 1	290.75843537414966	0.2525	77	398	4	24	7	16	0	2	16	0	0	6.10723839815053	147	
i 1	290.7627891156463	0.2525	74	166	6	1	2	17	0	2	17	0	0	3.10723839815053	147	
i 1	290.9904761904762	0.2525	74	784	6	1	1	17	0	1	17	0	0	3.10723839815053	147	
i 1	291.0117006802721	0.2525	71	398	4	5	12	8	0	-1	8	0	0	3.0	147	
i 1	291.25843537414966	1.01	77	1099	6	1	5	16	0	2	16	0	0	3.10723839815053	147	
i 1	291.4959183673469	2.2725	66	166	6	13	1	9	0	0	9	0	0	0.8024675041135513	147	
i 1	291.50081632653064	0.505	74	1099	5	2	14	16	0	1	16	0	0	4.0	147	
i 1	291.50625850340134	0.2525	77	398	4	24	3	16	0	2	16	0	0	6.10723839815053	147	
i 1	291.74918367346936	0.2525	71	398	4	5	16	8	0	-1	8	0	0	3.0	147	
i 1	291.75190476190477	0.2525	74	784	4	5	10	8	0	-1	8	0	0	3.0	147	
i 1	291.7595238095238	1.7675	74	166	6	3	3	16	0	2	16	0	0	4.0	147	
i 1	291.99918367346936	1.7675	71	1099	6	5	11	8	0	-2	8	0	0	3.0	147	
i 1	292.2372108843537	0.505	77	398	4	24	2	16	0	2	16	0	0	6.10723839815053	147	
i 1	292.23938775510203	0.2525	74	398	5	3	13	17	0	2	17	0	0	4.0	147	
i 1	292.51061224489797	0.2525	71	784	4	5	8	2	0	-2	2	0	0	3.0	147	
i 1	292.9866666666667	0.2525	74	166	6	1	3	17	0	2	17	0	0	3.10723839815053	147	
i 1	293.00190476190477	0.7575000000000001	61	166	7	7	7	6	0	0	6	0	0	3.625038686276807	147	
i 1	293.00244897959186	0.505	77	784	5	9	6	17	0	1	17	0	0	3.0	147	
i 1	293.0073469387755	0.7575000000000001	77	1099	5	2	14	16	0	2	16	0	0	4.0	147	
i 1	293.0095238095238	0.2525	74	166	7	5	2	8	0	-2	8	0	0	3.0	147	
i 1	293.01061224489797	0.505	77	398	4	24	8	16	0	2	16	0	0	6.10723839815053	147	
i 1	293.2399319727891	0.2525	74	1099	6	5	8	8	0	-2	8	0	0	3.0	147	
i 1	293.49972789115645	0.2525	74	1099	5	2	2	16	0	1	16	0	0	4.0	147	
i 1	293.50244897959186	0.2525	74	166	6	1	6	17	0	2	17	0	0	3.10723839815053	147	
i 1	293.5127891156463	0.2525	77	1099	6	1	2	16	0	2	16	0	0	3.10723839815053	147	
i 1	293.7426530612245	14.3925	61	108	7	7	1	9	0	1	9	0	0	3.625038686276807	148	
i 1	293.74374149659866	1.7675	71	108	7	5	15	8	0	-1	8	0	0	3.0	148	
i 1	293.7448299319728	14.8975	61	922	1	27	13	9	0	252	9	307	0	3.5736788627724323	148	
i 1	293.74755102040814	11.3625	61	922	5	14	8	9	0	0	9	0	0	5.036324277358435	148	
i 1	293.75244897959186	0.2525	77	424	5	1	2	17	0	2	17	0	0	3.10723839815053	148	
i 1	293.75843537414966	1.2625	77	108	6	1	14	17	0	2	17	0	0	3.10723839815053	148	
i 1	293.7617006802721	12.8775	66	108	6	13	2	6	0	1	6	0	0	0.8024675041135513	148	
i 1	293.7633333333333	9.8475	61	922	5	14	9	6	0	0	6	0	0	5.036324277358435	148	
i 1	294.011156462585	0.2525	77	922	4	24	9	16	0	2	16	0	0	6.10723839815053	149	
i 1	294.2622448979592	0.2525	77	424	5	9	10	17	0	2	17	0	0	3.0	149	
i 1	294.4904761904762	0.505	77	108	5	4	5	17	0	2	17	0	0	4.0	150	
i 1	294.49210884353744	0.2525	74	922	3	5	6	8	0	-2	8	0	0	3.0	150	
i 1	294.50081632653064	2.7775	77	108	5	3	16	16	0	2	16	0	0	4.0	150	
i 1	294.73938775510203	1.2625	74	922	6	5	8	8	0	-2	8	0	0	3.0	151	
i 1	294.996462585034	0.2525	74	424	5	1	13	16	0	2	16	0	0	3.10723839815053	151	
i 1	294.99918367346936	0.2525	74	424	5	9	3	17	0	2	17	0	0	3.0	151	
i 1	295.0046258503401	0.2525	74	922	3	5	9	2	0	-2	2	0	0	3.0	151	
i 1	295.0100680272109	0.7575000000000001	77	922	4	4	14	17	0	2	17	0	0	4.0	151	
i 1	295.5051700680272	1.01	77	922	4	1	1	17	0	2	17	0	0	3.10723839815053	151	
i 1	295.75081632653064	0.2525	74	424	4	5	4	8	0	-2	8	0	0	3.0	151	
i 1	296.00625850340134	0.2525	71	108	7	5	8	8	0	-1	8	0	0	3.0	151	
i 1	296.26061224489797	0.2525	74	922	6	1	4	16	0	2	16	0	0	3.10723839815053	151	
i 1	296.48938775510203	0.505	77	922	4	24	6	16	0	2	16	0	0	6.10723839815053	151	
i 1	296.50190476190477	0.505	77	424	5	9	6	17	0	2	17	0	0	3.0	151	
i 1	296.7633333333333	0.2525	74	108	7	5	12	2	0	-2	2	0	0	3.0	152	
i 1	296.99156462585034	0.2525	74	922	6	1	1	16	0	2	16	0	0	3.10723839815053	152	
i 1	297.0100680272109	0.7575000000000001	74	424	5	9	7	17	0	2	17	0	0	3.0	152	
i 1	297.2442857142857	2.02	77	108	5	4	6	17	0	2	17	0	0	4.0	152	
i 1	297.2551700680272	2.2725	77	108	5	24	4	17	0	2	17	0	0	6.10723839815053	152	
i 1	297.25680272108843	0.505	77	424	5	1	11	17	0	2	17	0	0	3.10723839815053	152	
i 1	297.49374149659866	0.505	71	922	6	5	10	8	0	-2	8	0	0	3.0	152	
i 1	297.7513605442177	0.2525	74	922	6	1	3	16	0	2	16	0	0	3.10723839815053	152	
i 1	297.7617006802721	0.2525	74	922	5	2	8	17	0	2	17	0	0	4.0	152	
i 1	297.9904761904762	0.505	77	922	4	24	14	16	0	2	16	0	0	6.10723839815053	152	
i 1	297.9986394557823	0.2525	77	108	5	3	7	16	0	2	16	0	0	4.0	152	
i 1	297.9986394557823	0.2525	77	922	4	4	9	17	0	2	17	0	0	4.0	152	
i 1	298.0100680272109	0.2525	74	922	5	5	2	8	0	-2	8	0	0	3.0	152	
i 1	298.24972789115645	0.2525	74	108	7	5	4	2	0	-2	2	0	0	3.0	152	
i 1	298.26061224489797	0.7575000000000001	77	922	5	3	12	16	0	1	16	0	0	4.0	152	
i 1	298.49755102040814	3.0300000000000002	77	108	5	3	14	16	0	2	16	0	0	4.0	152	
i 1	298.51061224489797	2.02	74	922	5	5	7	8	0	-2	8	0	0	3.0	152	
i 1	298.76061224489797	3.7875	74	922	6	1	6	16	0	2	16	0	0	3.10723839815053	152	
i 1	298.9926530612245	1.5150000000000001	74	922	5	2	3	17	0	2	17	0	0	4.0	152	
i 1	299.0040816326531	0.505	74	424	6	5	2	8	0	-2	8	0	0	3.0	152	
i 1	299.253537414966	0.2525	77	922	5	3	15	16	0	1	16	0	0	4.0	152	
i 1	299.503537414966	0.2525	77	108	7	1	2	17	0	2	17	0	0	3.10723839815053	152	
i 1	299.5100680272109	0.2525	77	922	4	24	9	16	0	2	16	0	0	6.10723839815053	152	
i 1	299.5122448979592	0.2525	74	424	4	9	6	17	0	2	17	0	0	3.0	152	
i 1	299.5133333333333	0.7575000000000001	74	108	7	5	16	2	0	-2	2	0	0	3.0	152	
i 1	299.7448299319728	0.505	77	922	4	4	7	17	0	2	17	0	0	4.0	152	
i 1	300.25081632653064	0.505	74	424	4	9	15	17	0	2	17	0	0	3.0	152	
i 1	300.50897959183675	0.2525	74	424	6	5	9	8	0	-2	8	0	0	3.0	152	
i 1	300.5133333333333	0.2525	77	424	4	9	2	17	0	2	17	0	0	3.0	152	
i 1	300.7557142857143	1.7675	71	108	5	5	2	8	0	-1	8	0	0	3.0	153	
i 1	300.7595238095238	1.01	74	108	7	5	3	2	0	-2	2	0	0	3.0	153	
i 1	301.5029931972789	0.505	74	424	6	5	5	8	0	-2	8	0	0	3.0	155	
i 1	301.5100680272109	0.505	77	922	4	4	12	17	0	2	17	0	0	4.0	155	
i 1	301.99210884353744	0.505	74	424	4	9	8	17	0	2	17	0	0	3.0	156	
i 1	302.0046258503401	0.2525	74	108	5	5	2	2	0	-2	2	0	0	3.0	156	
i 1	302.0057142857143	0.505	77	922	4	2	5	16	0	1	16	0	0	4.0	156	
i 1	302.238843537415	0.2525	77	108	5	3	3	16	0	2	16	0	0	4.0	156	
i 1	302.25625850340134	0.2525	74	922	4	1	1	16	0	1	16	0	0	3.10723839815053	156	
i 1	303.503537414966	5.05	61	922	5	14	12	6	0	0	6	0	0	5.036324277358435	156	
i 1	304.98938775510203	3.535	61	922	5	14	7	9	0	0	9	0	0	5.036324277358435	157	
i 1	306.50843537414966	2.02	66	108	6	13	8	6	0	1	6	0	0	0.8024675041135513	157	
i 1	307.99319727891157	0.505	61	108	6	7	15	9	0	1	9	0	0	3.625038686276807	159	
t0 80
</CsScore>
</CsoundSynthesizer>

