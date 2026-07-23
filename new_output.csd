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
i 1	0.0003129251700680277	0.505	72	203	7	2	7	1	0	-1	1	0	0	4.0	0	
i 1	0.0021904761904761906	2.02	63	203	6	14	12	16	0	1	16	0	0	5.293436574645402	0	
i 1	0.0034421768707482998	7.575	61	203	6	14	4	1	0	1	1	0	0	5.293436574645402	0	
i 1	0.006571428571428572	0.2525	72	701	3	9	1	0	0	-1	0	0	0	3.0	0	
i 1	0.009074829931972788	1.01	63	1087	3	13	1	1	0	2	1	0	0	3.5289577164302686	0	
i 1	0.014707482993197277	3.0300000000000002	63	1087	4	7	11	16	0	2	16	0	0	4.7052769552403575	0	
i 1	0.25657142857142856	0.2525	74	203	7	5	13	8	0	-2	8	0	0	3.0	0	
i 1	0.4940544217687075	1.5150000000000001	72	203	7	2	5	0	0	-1	0	0	0	4.0	0	
i 1	0.749061224489796	0.2525	73	203	1	20	10	8	0	-1	8	0	0	4.0	0	
i 1	0.9865442176870748	3.0300000000000002	63	1087	5	13	3	1	0	2	1	0	0	3.5289577164302686	0	
i 1	1.013455782312925	0.2525	71	1087	6	5	1	8	0	-1	8	0	0	3.0	0	
i 1	1.2565714285714287	0.2525	74	701	4	24	9	8	0	-2	8	0	0	3.0	0	
i 1	1.2653333333333334	0.505	71	701	6	5	10	2	0	-1	2	0	0	3.0	0	
i 1	1.512204081632653	1.5150000000000001	74	203	7	5	11	8	0	-2	8	0	0	3.0	0	
i 1	1.9978095238095237	5.555	63	203	6	14	5	16	0	1	16	0	0	5.293436574645402	1	
i 1	2.0053197278911563	0.2525	71	701	6	5	11	2	0	-2	2	0	0	3.0	1	
i 1	2.487795918367347	0.2525	74	701	6	5	10	2	0	-1	2	0	0	3.0	1	
i 1	2.736544217687075	0.505	74	701	6	5	5	8	0	-1	8	0	0	3.0	1	
i 1	2.9928027210884354	3.0300000000000002	63	1087	6	7	14	16	0	2	16	0	0	4.7052769552403575	2	
i 1	2.9965578231292516	1.01	71	1087	6	5	13	8	0	-1	8	0	0	3.0	2	
i 1	3.239047619047619	0.505	72	701	5	9	10	0	0	-1	0	0	0	3.0	2	
i 1	3.5046938775510204	0.2525	71	701	6	5	5	2	0	-1	2	0	0	3.0	3	
i 1	3.9852925170068025	1.5150000000000001	72	203	7	2	15	1	0	-1	1	0	0	4.0	3	
i 1	3.990925170068027	1.5150000000000001	71	1087	6	5	6	8	0	-1	8	0	0	3.0	3	
i 1	3.9965578231292516	3.535	63	1087	5	13	2	1	0	2	1	0	0	3.5289577164302686	3	
i 1	4.243428571428572	0.505	74	203	7	5	5	8	0	-2	8	0	0	3.0	3	
i 1	4.2597006802721085	0.2525	72	1087	4	4	15	0	0	-1	0	0	0	4.0	3	
i 1	4.511578231292517	0.2525	69	701	5	9	11	1	0	-1	1	0	0	3.0	3	
i 1	4.745931972789116	0.2525	74	701	6	5	11	8	0	-1	8	0	0	3.0	3	
i 1	5.243428571428572	1.5150000000000001	72	203	7	2	15	0	0	-1	0	0	0	4.0	3	
i 1	5.494680272108844	0.2525	69	701	5	3	14	0	0	-1	0	0	0	4.0	3	
i 1	5.745931972789116	0.2525	74	701	4	24	3	8	0	-2	8	0	0	3.0	3	
i 1	5.745931972789116	0.505	71	701	6	5	16	2	0	-2	2	0	0	3.0	3	
i 1	5.9915510204081635	1.5150000000000001	63	1087	5	7	7	16	0	2	16	0	0	4.7052769552403575	3	
i 1	6.4971836734693875	0.2525	69	701	5	3	5	0	0	-1	0	0	0	4.0	3	
i 1	6.497809523809524	0.2525	71	1087	6	5	1	8	0	-1	8	0	0	3.0	3	
i 1	7.238421768707483	0.2525	71	1087	4	24	14	2	0	-1	2	0	0	3.0	3	
i 1	7.486544217687075	4.04	63	379	5	13	7	1	0	2	1	0	0	3.5289577164302686	4	
i 1	7.498435374149659	1.5150000000000001	72	695	6	2	16	1	0	0	1	0	0	4.0	4	
i 1	7.5028163265306125	0.505	71	1081	6	5	8	2	0	-1	2	0	0	3.0	4	
i 1	7.5028163265306125	5.555	73	379	1	24	5	2	0	252	2	307	0	4.0	4	
i 1	7.506571428571428	2.525	61	695	5	14	11	16	0	1	16	0	0	5.293436574645402	4	
i 1	7.510952380952381	0.505	61	695	5	14	2	1	0	1	1	0	0	5.293436574645402	4	
i 1	7.512204081632653	4.04	61	379	6	7	12	1	0	1	1	0	0	4.7052769552403575	4	
i 1	8.005319727891157	5.05	61	695	5	14	11	1	0	1	1	0	0	5.293436574645402	4	
i 1	8.007197278911564	5.05	73	1081	1	24	12	8	0	252	8	307	0	4.0	4	
i 1	8.015333333333333	0.2525	74	379	6	5	5	8	0	-2	8	0	0	3.0	4	
i 1	8.252816326530612	0.2525	73	379	1	24	16	2	0	-2	2	0	0	4.0	4	
i 1	8.25970068027211	0.2525	74	379	6	5	8	2	0	-2	2	0	0	3.0	4	
i 1	8.485918367346938	0.505	74	1081	6	5	7	2	0	-1	2	0	0	3.0	4	
i 1	8.984666666666667	0.2525	74	379	6	5	15	2	0	-2	2	0	0	3.0	4	
i 1	8.993428571428572	0.505	69	379	4	4	15	0	0	0	0	0	0	4.0	4	
i 1	9.492802721088436	0.2525	72	379	4	4	1	0	0	-1	0	0	0	4.0	5	
i 1	9.98904761904762	0.2525	69	379	4	4	6	0	0	0	0	0	0	4.0	5	
i 1	10.000312925170068	3.0300000000000002	61	695	5	14	8	16	0	1	16	0	0	5.293436574645402	5	
i 1	10.006571428571428	0.2525	71	695	6	5	8	8	0	-2	8	0	0	3.0	5	
i 1	10.007823129251701	0.2525	73	379	1	24	7	2	0	-2	2	0	0	4.0	5	
i 1	10.74029931972789	0.2525	74	379	6	5	9	8	0	-2	8	0	0	3.0	5	
i 1	10.759074829931972	0.505	72	695	5	2	15	1	0	0	1	0	0	4.0	5	
i 1	11.252816326530612	0.2525	69	1081	5	9	5	0	0	0	0	0	0	3.0	5	
i 1	11.254068027210884	0.2525	71	379	4	24	13	8	0	-2	8	0	0	3.0	5	
i 1	11.49029931972789	1.5150000000000001	71	695	6	5	5	8	0	-2	8	0	0	3.0	6	
i 1	11.502190476190476	2.525	61	695	6	7	11	16	0	1	16	0	0	4.7052769552403575	6	
i 1	11.50469387755102	0.2525	72	695	5	2	14	1	0	0	1	0	0	4.0	6	
i 1	11.513455782312926	0.505	63	695	5	13	5	16	0	1	16	0	0	3.5289577164302686	6	
i 1	11.997809523809524	1.01	72	695	5	3	11	0	0	0	0	0	0	4.0	6	
i 1	11.999061224489797	7.07	63	695	5	13	3	16	0	1	16	0	0	3.5289577164302686	6	
i 1	12.24530612244898	0.505	69	379	5	3	1	1	0	-1	1	0	0	4.0	6	
i 1	12.76095238095238	0.2525	69	1081	5	9	10	0	0	0	0	0	0	3.0	7	
i 1	12.990925170068028	1.5150000000000001	72	899	5	2	2	0	0	0	0	0	0	4.0	8	
i 1	13.00156462585034	9.09	61	899	5	14	15	16	0	1	16	0	0	5.293436574645402	8	
i 1	13.003442176870749	0.2525	74	197	3	24	3	8	0	-2	8	0	0	3.0	8	
i 1	13.01095238095238	9.09	63	899	5	14	6	1	0	1	1	0	0	5.293436574645402	8	
i 1	13.485292517006803	0.505	69	197	6	3	15	1	0	0	1	0	0	4.0	8	
i 1	13.98904761904762	5.05	61	695	6	7	1	16	0	1	16	0	0	4.7052769552403575	8	
i 1	13.99843537414966	0.2525	69	197	6	9	13	1	0	-1	1	0	0	3.0	8	
i 1	14.502816326530612	0.2525	74	197	6	5	12	8	0	-1	8	0	0	3.0	8	
i 1	14.735292517006803	0.2525	72	899	5	2	9	0	0	0	0	0	0	4.0	8	
i 1	15.244054421768707	0.2525	69	197	6	9	1	1	0	-1	1	0	0	3.0	8	
i 1	15.487170068027211	0.2525	74	695	4	24	16	8	0	-2	8	0	0	3.0	8	
i 1	15.507823129251701	0.2525	69	899	5	2	11	1	0	0	1	0	0	4.0	8	
i 1	15.999687074829932	6.0600000000000005	73	197	1	24	1	2	0	248	2	308	0	9.0	8	
i 1	16.00156462585034	1.2625	71	899	4	5	8	8	0	-1	8	0	0	3.0	8	
i 1	16.241551020408163	0.2525	70	899	1	20	3	2	0	-1	2	0	0	5.0	8	
i 1	16.762204081632653	0.2525	72	197	5	4	10	0	0	-1	0	0	0	4.0	8	
i 1	17.2352925170068	0.505	73	899	1	20	15	8	0	-1	8	0	0	5.0	9	
i 1	17.262204081632653	0.2525	74	197	5	24	8	8	0	-2	8	0	0	3.0	9	
i 1	17.262204081632653	0.505	74	197	6	5	11	8	0	-1	8	0	0	3.0	9	
i 1	17.754068027210884	0.2525	70	197	1	20	3	2	0	-2	2	0	0	5.0	9	
i 1	18.24405442176871	0.2525	72	197	5	4	3	0	0	-1	0	0	0	4.0	9	
i 1	18.247183673469387	0.7575000000000001	74	695	4	24	12	8	0	-2	8	0	0	3.0	9	
i 1	18.490925170068028	0.2525	69	197	5	9	5	1	0	-1	1	0	0	3.0	9	
i 1	18.505319727891155	0.505	71	899	4	5	3	8	0	-1	8	0	0	3.0	9	
i 1	18.745931972789116	0.2525	70	197	1	20	14	8	0	-2	8	0	0	5.0	9	
i 1	18.99530612244898	1.5150000000000001	71	583	4	5	3	2	0	-1	2	0	0	3.0	10	
i 1	19.000938775510203	3.0300000000000002	61	583	5	13	4	16	0	2	16	0	0	3.5289577164302686	10	
i 1	19.00156462585034	3.0300000000000002	63	583	6	7	4	1	0	1	1	0	0	4.7052769552403575	10	
i 1	19.240925170068028	0.505	71	197	7	5	14	2	0	-1	2	0	0	3.0	10	
i 1	19.75156462585034	0.505	69	583	4	4	13	1	0	0	1	0	0	4.0	10	
i 1	19.987795918367347	0.505	71	583	4	24	16	8	0	-2	8	0	0	3.0	10	
i 1	20.002816326530613	0.2525	71	197	7	5	16	2	0	-1	2	0	0	3.0	10	
i 1	20.4921768707483	0.7575000000000001	72	899	5	2	3	0	0	0	0	0	0	4.0	10	
i 1	20.9852925170068	0.7575000000000001	73	197	1	24	14	8	0	252	8	307	0	9.0	11	
i 1	20.987795918367347	0.7575000000000001	70	197	1	20	3	8	0	-2	8	0	0	5.0	11	
i 1	20.997183673469387	0.505	74	197	5	24	9	8	0	-2	8	0	0	3.0	11	
i 1	21.250938775510203	0.2525	69	197	4	3	3	1	0	0	1	0	0	4.0	11	
i 1	21.739047619047618	0.2525	74	197	5	24	12	8	0	-2	8	0	0	3.0	11	
i 1	21.758448979591837	0.2525	70	899	1	20	10	2	0	-2	2	0	0	5.0	11	
i 1	21.984666666666666	4.545	63	695	5	13	3	1	0	2	1	0	0	3.5289577164302686	12	
i 1	21.98717006802721	0.505	73	197	1	20	2	2	0	-2	2	0	0	5.0	12	
i 1	21.995931972789116	8.08	63	1081	5	14	6	1	0	2	1	0	0	5.293436574645402	12	
i 1	22.002190476190478	0.505	74	1081	6	5	7	8	0	-2	8	0	0	3.0	12	
i 1	22.00469387755102	8.08	61	1081	5	14	2	16	0	1	16	0	0	5.293436574645402	12	
i 1	22.00657142857143	1.2625	71	695	4	5	12	2	0	-2	2	0	0	3.0	12	
i 1	22.012204081632653	1.5150000000000001	69	1081	4	2	10	0	0	0	0	0	0	4.0	12	
i 1	22.5078231292517	0.505	69	695	4	4	14	1	0	-1	1	0	0	4.0	13	
i 1	22.738421768707482	0.2525	71	197	4	5	2	2	0	-1	2	0	0	3.0	13	
i 1	22.759074829931972	0.7575000000000001	71	695	4	5	9	8	0	-1	8	0	0	3.0	13	
i 1	22.984666666666666	0.2525	69	197	5	9	8	1	0	-1	1	0	0	3.0	13	
i 1	22.98717006802721	0.505	74	695	4	24	4	8	0	-1	8	0	0	3.0	13	
i 1	23.000312925170068	1.2625	74	695	4	24	1	2	0	-1	2	0	0	3.0	13	
i 1	23.254068027210884	0.2525	73	197	1	20	13	2	0	-2	2	0	0	5.0	13	
i 1	23.260952380952382	0.2525	69	695	4	4	15	1	0	-1	1	0	0	4.0	13	
i 1	23.505319727891155	0.505	69	1081	6	2	10	0	0	-1	0	0	0	4.0	13	
i 1	23.512204081632653	0.2525	74	695	6	5	16	2	0	-1	2	0	0	3.0	13	
i 1	23.741551020408163	0.505	74	695	6	5	2	2	0	-2	2	0	0	3.0	13	
i 1	23.98717006802721	0.2525	73	1081	1	20	3	2	0	-2	2	0	0	5.0	13	
i 1	24.013455782312924	0.2525	73	1081	1	20	13	2	0	-2	2	0	0	5.0	13	
i 1	24.509700680272108	0.2525	69	695	4	4	6	1	0	-1	1	0	0	4.0	13	
i 1	24.739047619047618	0.2525	72	197	5	9	9	1	0	0	1	0	0	3.0	13	
i 1	24.758448979591837	0.505	71	695	4	5	4	2	0	-2	2	0	0	3.0	13	
i 1	24.759074829931972	0.2525	73	197	1	24	4	8	0	-2	8	0	0	9.0	13	
i 1	24.765333333333334	0.2525	74	695	6	5	5	2	0	-2	2	0	0	3.0	13	
i 1	25.239673469387753	0.2525	73	1081	1	20	1	8	0	-1	8	0	0	5.0	13	
i 1	25.49342857142857	0.2525	71	197	4	5	3	2	0	-1	2	0	0	3.0	13	
i 1	26.015333333333334	0.505	72	695	4	3	8	1	0	0	1	0	0	4.0	13	
i 1	26.250312925170068	1.7675	74	1081	6	5	6	8	0	-1	8	0	0	3.0	13	
i 1	26.486544217687076	2.02	63	583	5	13	16	1	0	1	1	0	0	3.5289577164302686	14	
i 1	26.491551020408163	2.02	63	583	6	7	6	1	0	1	1	0	0	4.7052769552403575	14	
i 1	26.502816326530613	0.2525	73	197	1	24	9	8	0	-2	8	0	0	9.0	14	
i 1	26.5078231292517	0.2525	74	583	4	24	11	2	0	-2	2	0	0	3.0	14	
i 1	26.5147074829932	0.7575000000000001	69	695	4	3	14	0	0	0	0	0	0	4.0	14	
i 1	26.737795918367347	1.2625	69	583	4	4	5	0	0	-1	0	0	0	4.0	14	
i 1	26.988421768707482	1.2625	73	197	1	24	1	8	0	-2	8	0	0	9.0	14	
i 1	27.005319727891155	1.2625	73	197	1	20	16	2	0	-2	2	0	0	5.0	14	
i 1	27.240299319727892	0.505	69	1081	4	2	5	0	0	0	0	0	0	4.0	14	
i 1	27.240925170068028	0.2525	70	197	1	20	11	8	0	-2	8	0	0	5.0	14	
i 1	27.740925170068028	0.2525	69	1081	4	2	6	0	0	-1	0	0	0	4.0	14	
i 1	27.74342857142857	0.2525	69	695	4	3	7	0	0	0	0	0	0	4.0	14	
i 1	27.98717006802721	0.505	69	583	4	4	11	0	0	-1	0	0	0	4.0	14	
i 1	27.99342857142857	0.2525	74	583	4	24	13	2	0	-2	2	0	0	3.0	14	
i 1	28.00469387755102	0.2525	74	695	4	24	15	8	0	-1	8	0	0	3.0	14	
i 1	28.245931972789116	1.5150000000000001	69	1081	4	2	6	0	0	-1	0	0	0	4.0	14	
i 1	28.258448979591837	0.2525	74	1081	6	5	7	8	0	-1	8	0	0	3.0	14	
i 1	28.487795918367347	0.2525	70	197	1	20	12	8	0	-2	8	0	0	5.0	15	
i 1	28.49655782312925	1.5150000000000001	63	379	5	13	6	16	0	1	16	0	0	3.5289577164302686	15	
i 1	28.51408163265306	1.5150000000000001	71	379	6	5	2	8	0	-1	8	0	0	3.0	15	
i 1	28.744680272108845	0.2525	74	379	6	5	10	8	0	-1	8	0	0	3.0	15	
i 1	28.745931972789116	0.2525	73	379	1	24	5	2	0	-2	2	0	0	9.0	15	
i 1	28.74655782312925	0.2525	71	379	4	24	7	8	0	-2	8	0	0	3.0	15	
i 1	28.989047619047618	0.2525	74	197	4	5	11	8	0	-1	8	0	0	3.0	15	
i 1	28.99655782312925	1.01	73	197	1	20	13	2	0	-1	2	0	0	5.0	15	
i 1	28.99843537414966	0.2525	74	695	4	24	8	8	0	-1	8	0	0	3.0	15	
i 1	29.499061224489797	0.505	69	1081	4	2	7	0	0	0	0	0	0	4.0	15	
i 1	29.50469387755102	0.2525	70	197	1	20	15	2	0	-1	2	0	0	5.0	15	
i 1	29.5078231292517	0.505	71	379	4	24	11	8	0	-2	8	0	0	3.0	15	
i 1	29.744680272108845	0.2525	74	1081	6	5	3	8	0	-1	8	0	0	3.0	15	
i 1	29.9852925170068	0.505	69	1081	6	2	10	0	0	0	0	0	0	4.0	15	
i 1	29.98717006802721	0.505	63	695	4	19	1	1	0	2	1	0	0	5.290431105685503	15	
i 1	29.987795918367347	0.505	70	1081	1	20	12	2	0	-1	2	0	0	5.0	15	
i 1	29.989047619047618	2.02	63	197	5	18	3	16	0	1	16	0	0	5.290431105685503	15	
i 1	29.989047619047618	0.505	61	695	1	27	16	1	0	252	1	307	0	1.154898545639104	15	
i 1	29.990925170068028	0.505	63	695	1	27	5	1	0	252	1	307	0	1.154898545639104	15	
i 1	29.991551020408163	0.2525	74	197	6	1	9	2	0	-2	2	0	0	0.488354119971917	15	
i 1	29.992802721088434	0.505	61	1081	5	14	15	16	0	1	16	0	0	6.933713913664838	15	
i 1	29.994680272108845	0.505	61	695	4	19	5	16	0	1	16	0	0	5.290431105685503	15	
i 1	29.99530612244898	2.02	61	197	5	18	13	1	0	2	1	0	0	5.290431105685503	15	
i 1	29.995931972789116	0.2525	69	379	4	3	12	0	0	-1	0	0	0	4.0	15	
i 1	29.999061224489797	0.505	63	1081	6	17	12	16	0	1	16	0	0	5.290431105685503	15	
i 1	30.00156462585034	0.505	63	1081	5	14	12	1	0	2	1	0	0	6.933713913664838	15	
i 1	30.002190476190478	0.505	63	379	5	13	15	16	0	1	16	0	0	5.169235055449704	15	
i 1	30.002816326530613	0.2525	74	379	6	5	5	8	0	-1	8	0	0	3.0065128918243444	15	
i 1	30.00344217687075	0.505	74	1081	6	5	4	8	0	-1	8	0	0	3.0065128918243444	15	
i 1	30.00657142857143	0.505	63	379	6	17	3	1	0	2	1	0	0	5.290431105685503	15	
i 1	30.00657142857143	0.505	63	379	6	7	7	16	0	2	16	0	0	6.345554294259793	15	
i 1	30.011578231292518	0.505	63	379	6	17	10	16	0	2	16	0	0	5.290431105685503	15	
i 1	30.011578231292518	0.505	70	197	1	20	15	8	0	-2	8	0	0	5.0	15	
i 1	30.0147074829932	0.505	63	1081	6	17	1	16	0	2	16	0	0	5.290431105685503	15	
i 1	30.2352925170068	0.2525	71	379	6	5	6	8	0	-1	8	0	0	3.0065128918243444	15	
i 1	30.484666666666666	5.555	61	899	6	17	6	16	0	1	16	0	0	5.290431105685503	16	
i 1	30.486544217687076	5.555	61	583	5	13	12	1	0	2	1	0	0	5.169235055449704	16	
i 1	30.487795918367347	1.5150000000000001	61	197	1	27	6	1	0	252	1	307	0	1.154898545639104	16	
i 1	30.488421768707482	0.7575000000000001	71	899	4	1	5	2	0	-1	2	0	0	0.488354119971917	16	
i 1	30.489673469387753	7.575	63	583	6	17	8	1	0	1	1	0	0	5.290431105685503	16	
i 1	30.490299319727892	7.575	61	583	6	17	14	1	0	1	1	0	0	5.290431105685503	16	
i 1	30.49405442176871	3.535	63	899	5	14	5	16	0	2	16	0	0	6.933713913664838	16	
i 1	30.500938775510203	3.535	61	899	6	17	11	16	0	2	16	0	0	5.290431105685503	16	
i 1	30.500938775510203	1.5150000000000001	63	197	5	19	12	16	0	2	16	0	0	5.290431105685503	16	
i 1	30.509074829931972	1.5150000000000001	63	197	5	19	1	1	0	1	1	0	0	5.290431105685503	16	
i 1	30.509074829931972	1.5150000000000001	70	197	1	24	5	8	0	252	8	307	0	9.0	16	
i 1	30.509700680272108	0.2525	69	899	4	2	8	1	0	0	1	0	0	4.0	16	
i 1	30.510326530612247	1.7675	71	899	6	5	13	2	0	-2	2	0	0	3.0065128918243444	16	
i 1	30.512204081632653	0.2525	73	197	1	20	7	2	0	-2	2	0	0	5.0	16	
i 1	30.51408163265306	1.5150000000000001	63	899	5	14	1	1	0	1	1	0	0	6.933713913664838	16	
i 1	30.747809523809522	0.7575000000000001	69	197	6	9	10	1	0	-1	1	0	0	3.0	16	
i 1	30.98717006802721	0.2525	74	583	6	5	14	2	0	-1	2	0	0	3.0065128918243444	16	
i 1	31.00344217687075	0.2525	73	197	1	20	1	8	0	-1	8	0	0	5.0	16	
i 1	31.250312925170068	0.2525	71	197	6	1	2	2	0	-1	2	0	0	0.488354119971917	16	
i 1	31.252816326530613	0.2525	74	583	4	1	14	2	0	-1	2	0	0	0.488354119971917	16	
i 1	31.2647074829932	0.2525	69	583	4	3	7	0	0	0	0	0	0	4.0	16	
i 1	31.49655782312925	0.2525	71	197	3	5	13	2	0	-1	2	0	0	3.0065128918243444	17	
i 1	31.509700680272108	0.2525	71	197	3	5	9	2	0	-2	2	0	0	3.0065128918243444	17	
i 1	31.749061224489797	1.7675	74	583	4	1	5	2	0	-1	2	0	0	0.488354119971917	17	
i 1	31.752190476190478	1.2625	74	583	6	5	11	8	0	-2	8	0	0	3.0065128918243444	17	
i 1	31.99405442176871	6.0600000000000005	61	1165	4	18	14	1	0	1	1	0	0	5.290431105685503	18	
i 1	31.99530612244898	6.0600000000000005	61	196	5	19	2	16	0	1	16	0	0	5.290431105685503	18	
i 1	31.99530612244898	1.01	70	1165	1	20	12	2	0	-2	2	0	0	5.0	18	
i 1	31.997809523809522	6.0600000000000005	61	196	5	19	9	1	0	1	1	0	0	5.290431105685503	18	
i 1	32.00219047619048	6.0600000000000005	63	899	4	14	13	1	0	1	1	0	0	6.933713913664838	18	
i 1	32.00469387755102	6.0600000000000005	63	196	4	27	9	16	0	1	16	0	0	1.154898545639104	18	
i 1	32.00719727891156	6.0600000000000005	61	1165	4	18	13	16	0	1	16	0	0	5.290431105685503	18	
i 1	32.0078231292517	0.2525	72	1165	4	9	5	1	0	-1	1	0	0	3.0	18	
i 1	32.255319727891155	1.7675	72	583	4	4	16	0	0	0	0	0	0	4.0	18	
i 1	32.50344217687075	1.5150000000000001	71	899	4	1	14	2	0	-1	2	0	0	0.488354119971917	18	
i 1	32.5078231292517	0.2525	74	196	3	5	12	8	0	-2	8	0	0	3.0065128918243444	18	
i 1	32.74280272108844	1.2625	70	1165	1	24	2	8	0	-1	8	0	0	9.0	18	
i 1	32.74780952380952	0.2525	72	1165	4	9	8	1	0	-1	1	0	0	3.0	18	
i 1	32.75970068027211	0.2525	70	899	1	20	10	2	0	-2	2	0	0	5.0	18	
i 1	32.76408163265306	0.2525	70	583	1	24	8	8	0	-1	8	0	0	9.0	18	
i 1	32.98591836734694	0.2525	71	196	5	24	9	8	0	-2	8	0	0	3.488354119971917	18	
i 1	32.98591836734694	0.2525	72	196	6	3	7	0	0	0	0	0	0	4.0	18	
i 1	33.25031292517007	0.2525	69	1165	4	9	11	0	0	0	0	0	0	3.0	18	
i 1	33.49342857142857	0.2525	71	196	5	24	11	8	0	-2	8	0	0	3.488354119971917	18	
i 1	33.49405442176871	0.505	72	196	4	4	3	0	0	0	0	0	0	4.0	18	
i 1	33.75093877551021	0.2525	74	1165	6	5	6	8	0	-2	8	0	0	3.0065128918243444	18	
i 1	33.98842176870748	4.04	61	899	5	17	16	16	0	2	16	0	0	5.290431105685503	18	
i 1	33.98904761904762	1.2625	71	899	6	1	14	2	0	-1	2	0	0	0.488354119971917	18	
i 1	33.98904761904762	0.2525	73	899	1	20	5	8	0	-2	8	0	0	5.0	18	
i 1	33.99029931972789	1.5150000000000001	69	583	5	3	11	0	0	0	0	0	0	4.0	18	
i 1	33.99029931972789	4.04	63	899	4	14	6	16	0	2	16	0	0	6.933713913664838	18	
i 1	33.99780952380952	0.2525	72	196	3	3	7	0	0	0	0	0	0	4.0	18	
i 1	34.00281632653061	0.2525	70	583	1	24	1	8	0	-1	8	0	0	9.0	18	
i 1	34.00594557823129	4.04	63	196	4	27	10	16	0	1	16	0	0	1.154898545639104	18	
i 1	34.00657142857143	0.2525	72	899	6	2	2	0	0	-1	0	0	0	4.0	18	
i 1	34.26533333333333	2.02	74	899	5	5	15	8	0	-1	8	0	0	3.0065128918243444	18	
i 1	34.49029931972789	1.5150000000000001	73	1165	1	20	1	2	0	-1	2	0	0	5.0	18	
i 1	34.49906122448979	2.2725	72	899	6	2	14	0	0	-1	0	0	0	4.0	18	
i 1	34.514707482993195	1.5150000000000001	71	899	4	1	16	8	0	-1	8	0	0	0.488354119971917	18	
i 1	34.745931972789116	0.2525	74	1165	6	1	15	2	0	-2	2	0	0	0.488354119971917	18	
i 1	35.004068027210884	0.2525	72	196	5	4	1	0	0	0	0	0	0	4.0	18	
i 1	35.00844897959184	0.2525	73	1165	4	20	8	8	0	-2	8	0	0	5.0	18	
i 1	35.01282993197279	0.505	70	1165	1	24	8	8	0	252	8	307	0	9.0	18	
i 1	35.2421768707483	0.2525	71	1165	6	5	2	2	0	-2	2	0	0	3.0065128918243444	18	
i 1	35.259074829931976	0.2525	74	196	5	5	9	8	0	-2	8	0	0	3.0065128918243444	18	
i 1	35.50469387755102	1.7675	70	1165	1	24	6	8	0	-1	8	0	0	9.0	18	
i 1	35.744680272108845	0.2525	74	1165	6	1	14	2	0	-2	2	0	0	0.488354119971917	18	
i 1	35.98466666666667	2.02	61	583	4	13	15	1	0	2	1	0	0	5.169235055449704	19	
i 1	35.986544217687076	1.5150000000000001	74	583	4	1	10	2	0	-1	2	0	0	0.488354119971917	19	
i 1	35.98779591836735	2.02	61	899	5	17	6	16	0	1	16	0	0	5.290431105685503	19	
i 1	35.99718367346939	1.2625	71	899	5	5	1	2	0	-2	2	0	0	3.0065128918243444	19	
i 1	35.99718367346939	0.2525	70	583	1	24	4	2	0	-1	2	0	0	9.0	19	
i 1	36.24968707482993	0.2525	72	1165	4	9	14	1	0	-1	1	0	0	3.0	19	
i 1	36.259074829931976	0.505	71	899	6	1	5	2	0	-1	2	0	0	0.488354119971917	19	
i 1	36.51157823129252	0.2525	69	1165	4	9	9	0	0	0	0	0	0	3.0	19	
i 1	36.740925170068024	0.2525	72	196	3	3	12	0	0	0	0	0	0	4.0	19	
i 1	36.74718367346939	0.2525	71	1165	6	5	10	2	0	-2	2	0	0	3.0065128918243444	19	
i 1	36.75093877551021	0.505	72	196	3	4	14	0	0	0	0	0	0	4.0	19	
i 1	36.99906122448979	0.505	73	583	1	24	13	2	0	-2	2	0	0	9.0	19	
i 1	37.236544217687076	0.2525	74	1165	6	5	11	8	0	-2	8	0	0	3.0065128918243444	19	
i 1	37.23779591836735	0.7575000000000001	71	899	6	1	14	8	0	-1	8	0	0	0.488354119971917	19	
i 1	37.24906122448979	0.2525	74	196	5	5	7	8	0	-2	8	0	0	3.0065128918243444	19	
i 1	37.26157823129252	0.2525	70	899	4	20	13	8	0	-1	8	0	0	5.0	19	
i 1	37.50281632653061	0.505	70	1165	4	20	16	8	0	-1	8	0	0	5.0	19	
i 1	37.98466666666667	2.02	61	197	6	17	8	1	0	1	1	0	0	5.290431105685503	20	
i 1	37.98591836734694	1.7675	74	695	6	1	16	8	0	-1	8	0	0	0.488354119971917	20	
i 1	37.98779591836735	10.1	63	695	4	14	7	16	0	1	16	0	0	6.933713913664838	20	
i 1	37.98842176870748	6.0600000000000005	63	695	3	27	7	1	0	2	1	0	0	1.154898545639104	20	
i 1	37.98904761904762	1.7675	74	695	5	5	12	2	0	-1	2	0	0	3.0065128918243444	20	
i 1	37.99029931972789	8.08	61	695	4	14	12	16	0	1	16	0	0	6.933713913664838	20	
i 1	37.9921768707483	12.120000000000001	61	197	4	13	16	1	0	1	1	0	0	5.169235055449704	20	
i 1	37.99906122448979	2.02	63	695	3	27	15	16	0	2	16	0	0	1.154898545639104	20	
i 1	38.00031292517007	6.0600000000000005	61	1081	4	18	6	16	0	2	16	0	0	5.290431105685503	20	
i 1	38.00156462585034	4.04	63	1081	4	18	8	1	0	1	1	0	0	5.290431105685503	20	
i 1	38.00469387755102	10.1	61	695	4	19	7	1	0	1	1	0	0	5.290431105685503	20	
i 1	38.00469387755102	13.13	61	197	4	7	14	16	0	2	16	0	0	6.345554294259793	20	
i 1	38.01095238095238	12.120000000000001	63	197	5	17	7	16	0	1	16	0	0	5.290431105685503	20	
i 1	38.01282993197279	10.1	63	695	5	17	9	16	0	2	16	0	0	5.290431105685503	20	
i 1	38.013455782312924	8.08	61	695	4	19	9	16	0	1	16	0	0	5.290431105685503	20	
i 1	38.013455782312924	0.2525	71	695	4	5	9	8	0	-2	8	0	0	3.0065128918243444	20	
i 1	38.014707482993195	0.2525	74	197	6	5	5	8	0	-1	8	0	0	3.0065128918243444	20	
i 1	38.01533333333333	8.08	61	695	5	17	1	1	0	2	1	0	0	5.290431105685503	20	
i 1	38.24780952380952	0.505	72	695	6	2	15	0	0	-1	0	0	0	4.0	20	
i 1	38.24780952380952	0.505	71	1081	5	5	7	2	0	-1	2	0	0	3.0065128918243444	20	
i 1	38.49530612244898	0.2525	70	695	4	20	8	8	0	-2	8	0	0	5.0	20	
i 1	38.51157823129252	0.2525	73	197	1	24	5	8	0	-2	8	0	0	9.0	20	
i 1	38.7421768707483	0.505	69	695	2	4	4	1	0	-1	1	0	0	4.0	20	
i 1	38.75156462585034	0.505	71	695	5	5	8	2	0	-1	2	0	0	3.0065128918243444	20	
i 1	38.754068027210884	1.01	73	1081	3	20	5	8	0	-1	8	0	0	5.0	20	
i 1	38.99029931972789	0.505	71	1081	5	5	7	2	0	-1	2	0	0	3.0065128918243444	20	
i 1	39.23717006802721	1.5150000000000001	71	197	5	5	15	2	0	-2	2	0	0	3.0065128918243444	20	
i 1	39.24530612244898	0.2525	69	1081	3	9	7	1	0	-1	1	0	0	3.0	20	
i 1	39.50031292517007	0.2525	71	695	4	5	7	8	0	-2	8	0	0	3.0065128918243444	20	
i 1	39.736544217687076	0.2525	71	197	7	1	8	2	0	-1	2	0	0	0.488354119971917	20	
i 1	39.73842176870748	0.2525	71	695	5	5	4	2	0	-1	2	0	0	3.0065128918243444	20	
i 1	39.74155102040816	0.2525	73	197	1	24	14	8	0	-2	8	0	0	9.0	20	
i 1	39.74530612244898	2.02	69	197	5	4	11	1	0	-1	1	0	0	4.0	20	
i 1	39.75719727891156	0.2525	71	695	4	1	5	8	0	-1	8	0	0	0.488354119971917	20	
i 1	39.98904761904762	1.01	71	197	5	24	1	2	0	-2	2	0	0	3.488354119971917	21	
i 1	39.99280272108844	11.11	61	197	5	17	4	1	0	1	1	0	0	5.290431105685503	21	
i 1	39.99968707482993	6.0600000000000005	63	695	3	27	15	16	0	2	16	0	0	1.154898545639104	21	
i 1	40.00469387755102	0.2525	71	1081	3	1	4	8	0	-1	8	0	0	0.488354119971917	21	
i 1	40.01095238095238	0.505	71	1081	3	1	5	2	0	-2	2	0	0	0.488354119971917	21	
i 1	40.23466666666667	0.2525	72	197	6	3	16	0	0	-1	0	0	0	4.0	21	
i 1	40.48779591836735	1.5150000000000001	71	197	7	1	6	2	0	-1	2	0	0	0.488354119971917	21	
i 1	40.48779591836735	0.2525	73	197	4	24	14	2	0	-2	2	0	0	4.0	21	
i 1	40.50281632653061	0.2525	69	1081	5	9	3	1	0	-1	1	0	0	3.0	21	
i 1	40.51095238095238	0.505	71	1081	3	1	10	8	0	-1	8	0	0	0.488354119971917	21	
i 1	40.74530612244898	0.505	69	695	2	4	3	1	0	-1	1	0	0	4.0	21	
i 1	40.74968707482993	1.2625	73	695	2	24	13	2	0	-2	2	0	0	4.0	21	
i 1	41.23779591836735	0.2525	71	197	5	5	8	2	0	-2	2	0	0	3.0065128918243444	22	
i 1	41.24843537414966	1.2625	72	197	6	3	7	0	0	-1	0	0	0	4.0	22	
i 1	41.50031292517007	4.2925	71	695	5	5	10	2	0	-1	2	0	0	3.0065128918243444	23	
i 1	41.73466666666667	0.2525	71	695	2	24	11	2	0	-1	2	0	0	3.488354119971917	23	
i 1	41.76032653061225	2.2725	69	695	6	2	4	0	0	-1	0	0	0	4.0	23	
i 1	41.99280272108844	0.2525	74	1081	5	5	5	8	0	-1	8	0	0	3.0065128918243444	23	
i 1	41.99655782312925	9.09	63	1081	4	18	1	1	0	1	1	0	0	5.290431105685503	23	
i 1	42.25719727891156	0.2525	71	1081	4	5	11	2	0	-1	2	0	0	3.0065128918243444	23	
i 1	42.49780952380952	0.505	69	1081	5	9	6	0	0	0	0	0	0	3.0	23	
i 1	42.504068027210884	0.505	71	695	4	5	12	2	0	-2	2	0	0	3.0065128918243444	23	
i 1	42.75156462585034	0.2525	71	1081	4	5	4	2	0	-1	2	0	0	3.0065128918243444	23	
i 1	42.75844897959184	0.505	71	1081	6	1	6	8	0	-1	8	0	0	0.488354119971917	23	
i 1	42.985292517006805	0.505	69	197	5	4	15	1	0	-1	1	0	0	4.0	23	
i 1	42.99843537414966	0.2525	69	695	4	3	15	1	0	-1	1	0	0	4.0	23	
i 1	43.25344217687075	0.2525	71	197	4	1	9	2	0	-1	2	0	0	0.488354119971917	23	
i 1	43.255319727891155	0.2525	73	695	2	24	14	2	0	-2	2	0	0	4.0	23	
i 1	43.26095238095238	1.01	73	1081	3	24	10	8	0	-2	8	0	0	4.0	23	
i 1	43.49155102040816	2.02	72	695	6	2	2	0	0	-1	0	0	0	4.0	23	
i 1	43.49968707482993	1.5150000000000001	74	695	4	1	14	8	0	-1	8	0	0	0.488354119971917	23	
i 1	43.74655782312925	0.505	69	197	5	4	8	1	0	-1	1	0	0	4.0	23	
i 1	43.990925170068024	2.02	63	695	3	27	8	1	0	2	1	0	0	1.154898545639104	23	
i 1	43.995931972789116	0.505	71	197	4	24	14	2	0	-2	2	0	0	3.488354119971917	23	
i 1	43.99718367346939	0.2525	73	695	2	24	4	2	0	-2	2	0	0	4.0	23	
i 1	44.00281632653061	7.07	61	1081	4	18	11	16	0	2	16	0	0	5.290431105685503	23	
i 1	44.23466666666667	0.2525	69	1081	5	9	12	0	0	0	0	0	0	3.0	23	
i 1	44.49029931972789	1.01	71	1081	4	5	1	2	0	-1	2	0	0	3.0065128918243444	23	
i 1	44.49342857142857	0.2525	71	1081	6	1	7	2	0	-2	2	0	0	0.488354119971917	23	
i 1	44.49718367346939	1.5150000000000001	71	197	4	1	13	2	0	-1	2	0	0	0.488354119971917	23	
i 1	44.49780952380952	0.2525	69	695	6	2	4	0	0	-1	0	0	0	4.0	23	
i 1	44.75344217687075	1.2625	69	197	5	4	12	1	0	-1	1	0	0	4.0	23	
i 1	44.75719727891156	0.505	71	695	2	1	13	8	0	-2	8	0	0	0.488354119971917	23	
i 1	45.00594557823129	0.2525	71	695	4	5	9	8	0	-2	8	0	0	3.0065128918243444	23	
i 1	45.24029931972789	0.2525	71	1081	6	1	15	8	0	-1	8	0	0	0.488354119971917	23	
i 1	45.2421768707483	0.2525	71	197	4	24	10	2	0	-2	2	0	0	3.488354119971917	23	
i 1	45.49155102040816	0.505	74	695	5	5	16	2	0	-1	2	0	0	3.0065128918243444	24	
i 1	45.51157823129252	2.02	74	695	4	1	15	8	0	-1	8	0	0	0.488354119971917	24	
i 1	45.513455782312924	0.505	71	695	2	24	2	2	0	-1	2	0	0	3.488354119971917	24	
i 1	45.98591836734694	5.05	61	695	3	19	7	16	0	1	16	0	0	5.290431105685503	24	
i 1	45.986544217687076	5.05	61	695	6	17	11	1	0	2	1	0	0	5.290431105685503	24	
i 1	45.994680272108845	2.2725	70	695	2	24	13	8	0	-1	8	0	0	4.0	24	
i 1	46.00093877551021	5.05	61	695	5	14	3	16	0	1	16	0	0	6.933713913664838	24	
i 1	46.00469387755102	2.02	63	695	3	27	6	16	0	2	16	0	0	1.154898545639104	24	
i 1	46.245931972789116	0.2525	71	695	4	1	6	8	0	-1	8	0	0	0.488354119971917	24	
i 1	46.25031292517007	0.2525	69	1081	5	9	1	0	0	0	0	0	0	3.0	24	
i 1	46.25156462585034	0.2525	71	197	4	1	1	2	0	-1	2	0	0	0.488354119971917	24	
i 1	46.48842176870748	0.2525	71	1081	4	5	4	2	0	-1	2	0	0	3.0065128918243444	24	
i 1	46.504068027210884	0.2525	71	695	3	5	4	8	0	-2	8	0	0	3.0065128918243444	24	
i 1	46.76220408163265	3.0300000000000002	69	695	6	2	4	0	0	-1	0	0	0	4.0	24	
i 1	46.76408163265306	0.2525	71	695	4	1	16	8	0	-1	8	0	0	0.488354119971917	24	
i 1	46.99342857142857	0.2525	72	695	6	2	14	0	0	-1	0	0	0	4.0	24	
i 1	47.236544217687076	0.2525	74	1081	4	5	8	8	0	-1	8	0	0	3.0065128918243444	24	
i 1	47.24906122448979	0.505	71	1081	4	5	3	2	0	-1	2	0	0	3.0065128918243444	24	
i 1	47.50031292517007	0.505	74	695	5	5	11	2	0	-1	2	0	0	3.0065128918243444	25	
i 1	47.51282993197279	0.2525	69	197	5	4	16	1	0	-1	1	0	0	4.0	25	
i 1	47.74780952380952	0.2525	71	695	5	1	10	8	0	-2	8	0	0	0.488354119971917	25	
i 1	47.75657142857143	0.505	69	1081	5	9	3	1	0	-1	1	0	0	3.0	25	
i 1	47.98466666666667	3.0300000000000002	63	695	5	14	9	16	0	1	16	0	0	6.933713913664838	25	
i 1	47.985292517006805	3.0300000000000002	61	695	3	19	9	1	0	1	1	0	0	5.290431105685503	25	
i 1	47.98591836734694	2.02	74	695	6	5	13	2	0	-1	2	0	0	3.0065128918243444	25	
i 1	47.990925170068024	0.2525	74	1081	4	5	1	8	0	-1	8	0	0	3.0065128918243444	25	
i 1	48.00281632653061	2.2725	73	695	2	24	15	8	0	-2	8	0	0	4.0	25	
i 1	48.009074829931976	3.0300000000000002	63	695	6	17	14	16	0	2	16	0	0	5.290431105685503	25	
i 1	48.01032653061225	0.2525	71	1081	3	1	15	8	0	-1	8	0	0	0.488354119971917	25	
i 1	48.23717006802721	0.505	71	197	4	1	14	2	0	-1	2	0	0	0.488354119971917	25	
i 1	48.24906122448979	0.505	71	1081	4	5	1	2	0	-1	2	0	0	3.0065128918243444	25	
i 1	48.25219047619048	0.7575000000000001	73	1081	3	24	3	8	0	-2	8	0	0	4.0	25	
i 1	48.254068027210884	0.2525	69	1081	5	9	3	0	0	0	0	0	0	3.0	25	
i 1	48.26220408163265	0.2525	74	197	5	5	16	8	0	-1	8	0	0	3.0065128918243444	25	
i 1	48.49906122448979	0.7575000000000001	70	695	2	24	5	2	0	-2	2	0	0	4.0	25	
i 1	48.50594557823129	0.505	71	695	3	5	6	8	0	-2	8	0	0	3.0065128918243444	25	
i 1	48.50719727891156	0.2525	69	695	4	4	5	1	0	-1	1	0	0	4.0	25	
i 1	48.759074829931976	2.2725	69	197	5	4	14	1	0	-1	1	0	0	4.0	25	
i 1	48.98591836734694	2.02	71	197	5	5	12	2	0	-2	2	0	0	3.0065128918243444	25	
i 1	49.24718367346939	0.2525	69	1081	5	9	7	1	0	-1	1	0	0	3.0	25	
i 1	49.49029931972789	1.5150000000000001	71	197	4	24	10	2	0	-2	2	0	0	3.488354119971917	26	
i 1	49.50093877551021	0.2525	71	695	5	5	2	2	0	-1	2	0	0	3.0065128918243444	26	
i 1	49.76533333333333	0.505	71	197	4	1	6	2	0	-1	2	0	0	0.488354119971917	26	
i 1	50.005319727891155	1.01	63	197	7	17	14	16	0	1	16	0	0	5.290431105685503	26	
i 1	50.00970068027211	1.01	61	197	6	13	11	1	0	1	1	0	0	5.169235055449704	26	
i 1	50.23904761904762	0.7575000000000001	73	695	1	24	9	8	0	252	8	307	0	4.0	26	
i 1	50.24342857142857	0.2525	71	695	6	5	16	2	0	-1	2	0	0	3.0065128918243444	26	
i 1	50.26282993197279	0.2525	69	1081	5	9	5	1	0	-1	1	0	0	3.0	26	
i 1	50.985292517006805	8.08	61	199	4	19	16	16	0	1	16	0	0	5.290431105685503	28	
i 1	50.98591836734694	3.0300000000000002	63	199	5	18	6	16	5000	1	16	0	0	5.290431105685503	28	
i 1	50.986544217687076	3.0300000000000002	63	199	1	27	8	16	0	252	16	307	0	1.154898545639104	28	
i 1	50.99155102040816	0.7575000000000001	74	901	6	5	15	8	0	-1	8	0	0	3.0065128918243444	28	
i 1	50.99342857142857	7.07	63	901	6	17	9	16	0	2	16	0	0	5.290431105685503	28	
i 1	50.99342857142857	7.07	61	199	4	19	14	1	0	1	1	0	0	5.290431105685503	28	
i 1	50.995931972789116	5.05	63	901	5	14	12	16	0	2	16	0	0	6.933713913664838	28	
i 1	50.99780952380952	1.01	61	585	5	17	14	16	0	1	16	0	0	5.290431105685503	28	
i 1	50.99843537414966	8.08	61	901	6	17	4	16	0	1	16	0	0	5.290431105685503	28	
i 1	50.99968707482993	7.07	63	901	5	14	4	16	0	1	16	0	0	6.933713913664838	28	
i 1	51.00093877551021	1.01	63	585	4	7	8	16	0	1	16	0	0	6.345554294259793	28	
i 1	51.00281632653061	8.08	63	585	6	17	14	16	0	1	16	0	0	5.290431105685503	28	
i 1	51.00281632653061	1.01	61	199	1	27	15	1	0	248	1	308	0	1.154898545639104	28	
i 1	51.00469387755102	5.05	63	199	5	18	9	1	5000	2	1	0	0	5.290431105685503	28	
i 1	51.00657142857143	8.08	61	585	5	13	1	1	0	1	1	0	0	5.169235055449704	28	
i 1	51.01220408163265	1.01	74	901	4	1	9	2	0	-1	2	0	0	0.488354119971917	28	
i 1	51.24718367346939	0.2525	71	199	5	5	2	2	5000	-2	2	0	0	3.0065128918243444	28	
i 1	51.50156462585034	0.2525	70	199	4	24	7	2	5000	-1	2	0	0	4.0	28	
i 1	51.51533333333333	1.7675	74	901	4	1	11	2	0	-2	2	0	0	0.488354119971917	28	
i 1	51.74780952380952	0.2525	74	585	5	5	13	2	0	-1	2	0	0	3.0065128918243444	28	
i 1	51.75281632653061	0.505	73	199	3	24	14	8	0	-2	8	0	0	4.0	28	
i 1	51.75844897959184	0.7575000000000001	72	585	4	4	16	0	0	0	0	0	0	4.0	28	
i 1	51.75970068027211	0.7575000000000001	70	199	1	24	14	2	5000	248	2	308	0	4.0	28	
i 1	51.985292517006805	7.07	63	585	6	7	1	16	0	1	16	0	0	6.345554294259793	28	
i 1	51.986544217687076	7.07	61	199	4	27	2	1	0	2	1	0	0	1.154898545639104	28	
i 1	51.98967346938775	7.07	61	585	6	17	2	16	0	1	16	0	0	5.290431105685503	28	
i 1	52.24655782312925	1.01	69	901	6	2	5	1	0	0	1	0	0	4.0	28	
i 1	52.48967346938775	0.2525	69	199	5	4	1	0	0	0	0	0	0	4.0	28	
i 1	52.50719727891156	0.2525	70	585	4	24	4	2	0	-2	2	0	0	4.0	28	
i 1	52.7421768707483	0.2525	73	199	3	24	13	8	0	-1	8	0	0	4.0	28	
i 1	52.744680272108845	0.2525	71	199	3	1	15	2	0	-2	2	0	0	0.488354119971917	28	
i 1	52.76032653061225	2.2725	74	901	6	5	4	8	0	-1	8	0	0	3.0065128918243444	28	
i 1	52.764707482993195	0.7575000000000001	73	199	3	24	1	8	0	-2	8	0	0	4.0	28	
i 1	53.25469387755102	0.505	72	901	6	2	12	1	0	0	1	0	0	4.0	28	
i 1	53.48779591836735	1.7675	70	199	4	24	13	2	5000	-1	2	0	0	4.0	28	
i 1	53.5078231292517	0.505	72	199	6	9	2	1	5000	0	1	0	0	3.0	28	
i 1	53.5078231292517	0.2525	71	585	6	5	4	8	0	-2	8	0	0	3.0065128918243444	28	
i 1	53.73842176870748	1.5150000000000001	73	199	3	24	4	8	0	-2	8	0	0	4.0	28	
i 1	53.990925170068024	0.2525	73	199	3	24	3	2	0	-2	2	0	0	4.0	28	
i 1	53.99155102040816	5.05	63	199	5	18	9	16	5000	1	16	0	0	5.290431105685503	28	
i 1	53.99405442176871	1.01	69	199	5	4	8	0	0	0	0	0	0	4.0	28	
i 1	54.00219047619048	0.2525	74	199	5	5	10	8	5000	-1	8	0	0	3.0065128918243444	28	
i 1	54.00281632653061	5.05	63	199	4	27	4	16	0	1	16	0	0	1.154898545639104	28	
i 1	54.25281632653061	0.505	74	199	4	5	15	8	0	-1	8	0	0	3.0065128918243444	28	
i 1	54.73967346938775	0.505	74	199	5	5	1	8	5000	-1	8	0	0	3.0065128918243444	28	
i 1	54.98466666666667	0.505	71	901	6	5	9	8	0	-2	8	0	0	3.0065128918243444	29	
i 1	54.99655782312925	0.505	74	199	4	1	11	8	5000	-2	8	0	0	0.488354119971917	29	
i 1	55.00844897959184	0.2525	71	585	4	1	15	2	0	-2	2	0	0	0.488354119971917	29	
i 1	55.23904761904762	0.2525	69	199	5	4	12	0	0	0	0	0	0	4.0	29	
i 1	55.24280272108844	2.02	74	901	6	5	16	8	0	-1	8	0	0	3.0065128918243444	29	
i 1	55.255319727891155	0.2525	72	199	5	3	13	1	0	0	1	0	0	4.0	29	
i 1	55.264707482993195	2.02	73	199	1	24	14	8	0	252	8	307	0	4.0	29	
i 1	55.490925170068024	0.2525	70	199	4	24	15	2	5000	-1	2	0	0	4.0	29	
i 1	55.50719727891156	0.2525	74	901	6	1	11	2	0	-1	2	0	0	0.488354119971917	29	
i 1	55.51533333333333	0.505	74	199	5	5	14	8	5000	-1	8	0	0	3.0065128918243444	29	
i 1	55.744680272108845	0.2525	71	199	3	1	10	2	0	-2	2	0	0	0.488354119971917	29	
i 1	55.74655782312925	0.505	72	199	5	3	5	1	0	0	1	0	0	4.0	29	
i 1	55.76032653061225	1.7675	73	199	3	24	12	2	0	-2	2	0	0	4.0	29	
i 1	55.98779591836735	0.2525	71	585	6	5	12	8	0	-2	8	0	0	3.0065128918243444	29	
i 1	55.99280272108844	3.0300000000000002	63	199	5	18	13	1	5000	2	1	0	0	5.290431105685503	29	
i 1	56.00031292517007	2.525	72	901	5	2	8	1	0	0	1	0	0	4.0	29	
i 1	56.00844897959184	3.0300000000000002	63	901	3	14	12	16	0	2	16	0	0	6.933713913664838	29	
i 1	56.00970068027211	0.2525	69	199	5	4	9	0	0	0	0	0	0	4.0	29	
i 1	56.24530612244898	0.2525	69	901	6	2	11	1	0	0	1	0	0	4.0	29	
i 1	56.25719727891156	0.2525	74	199	4	5	11	2	0	-2	2	0	0	3.0065128918243444	29	
i 1	56.495931972789116	0.2525	72	585	4	4	3	0	0	0	0	0	0	4.0	29	
i 1	56.50719727891156	0.505	69	199	5	4	15	0	0	0	0	0	0	4.0	29	
i 1	56.76220408163265	0.505	74	199	4	1	1	8	5000	-2	8	0	0	0.488354119971917	29	
i 1	56.98717006802721	0.2525	69	901	6	2	4	1	0	0	1	0	0	4.0	30	
i 1	56.99655782312925	2.02	74	901	6	1	11	2	0	-2	2	0	0	0.488354119971917	30	
i 1	57.009074829931976	0.2525	72	199	5	3	7	1	0	0	1	0	0	4.0	30	
i 1	57.244680272108845	0.505	72	585	4	4	11	0	0	0	0	0	0	4.0	30	
i 1	57.25156462585034	0.2525	74	585	6	5	9	2	0	-1	2	0	0	3.0065128918243444	30	
i 1	57.25344217687075	0.2525	71	585	6	1	15	2	0	-2	2	0	0	0.488354119971917	30	
i 1	57.49655782312925	0.505	74	901	6	1	6	2	0	-1	2	0	0	0.488354119971917	30	
i 1	57.50219047619048	0.2525	72	199	5	3	10	1	0	0	1	0	0	4.0	30	
i 1	57.73466666666667	0.2525	72	585	5	3	10	1	0	-1	1	0	0	4.0	30	
i 1	57.75281632653061	0.2525	72	199	6	9	3	1	5000	0	1	0	0	3.0	30	
i 1	57.764707482993195	0.2525	74	199	5	5	5	8	5000	-1	8	0	0	3.0065128918243444	30	
i 1	57.98779591836735	1.01	63	901	5	17	3	16	0	2	16	0	0	5.290431105685503	30	
i 1	57.99342857142857	0.505	71	199	4	1	14	2	5000	-2	2	0	0	0.488354119971917	30	
i 1	58.00344217687075	1.01	63	901	3	14	4	16	0	1	16	0	0	6.933713913664838	30	
i 1	58.005319727891155	1.01	72	585	4	4	1	0	0	0	0	0	0	4.0	30	
i 1	58.01282993197279	1.01	61	199	5	19	14	1	0	1	1	0	0	5.290431105685503	30	
i 1	58.01408163265306	1.01	71	585	6	5	11	8	0	-2	8	0	0	3.0065128918243444	30	
i 1	58.2578231292517	0.7575000000000001	71	585	4	24	13	8	0	-2	8	0	0	3.488354119971917	30	
i 1	58.50719727891156	0.505	69	199	6	9	1	0	5000	0	0	0	0	3.0	30	
i 1	58.51157823129252	0.2525	70	199	1	24	3	2	5000	-1	2	0	0	4.0	30	
i 1	58.51282993197279	0.505	74	199	3	24	16	2	0	-1	2	0	0	3.488354119971917	30	
i 1	58.745931972789116	0.2525	69	199	5	4	14	0	0	0	0	0	0	4.0	30	
i 1	58.76282993197279	0.2525	74	199	4	5	11	2	0	-2	2	0	0	3.0065128918243444	30	
i 1	58.98779591836735	1.01	61	585	5	13	1	1	0	1	1	0	0	5.169235055449704	31	
i 1	58.98904761904762	1.01	61	199	4	19	16	16	0	1	16	0	0	5.290431105685503	31	
i 1	58.98904761904762	1.01	61	199	4	27	2	1	0	2	1	0	0	1.154898545639104	31	
i 1	58.98967346938775	1.01	61	585	6	17	2	16	0	1	16	0	0	5.290431105685503	31	
i 1	58.99280272108844	0.505	72	199	6	9	13	1	5000	0	1	0	0	3.0	31	
i 1	58.994680272108845	1.01	72	585	4	4	1	0	0	0	0	0	0	4.0	31	
i 1	58.994680272108845	1.01	63	199	4	27	4	16	0	1	16	0	0	1.154898545639104	31	
i 1	58.99530612244898	0.2525	74	199	4	5	16	8	0	-1	8	0	0	3.0065128918243444	31	
i 1	58.99655782312925	0.2525	74	199	3	24	16	2	0	-1	2	0	0	3.488354119971917	31	
i 1	58.99780952380952	1.01	63	585	6	7	1	16	0	1	16	0	0	6.345554294259793	31	
i 1	58.99906122448979	1.01	63	901	3	14	12	16	0	2	16	0	0	6.933713913664838	31	
i 1	59.00031292517007	0.2525	70	585	1	24	13	2	0	-1	2	0	0	4.0	31	
i 1	59.004068027210884	1.01	63	901	5	17	3	16	0	2	16	0	0	5.290431105685503	31	
i 1	59.00594557823129	1.01	63	901	3	14	4	16	0	1	16	0	0	6.933713913664838	31	
i 1	59.00657142857143	1.01	63	199	5	18	9	16	5000	1	16	0	0	5.290431105685503	31	
i 1	59.0078231292517	1.01	61	901	6	17	4	16	0	1	16	0	0	5.290431105685503	31	
i 1	59.01032653061225	0.505	71	199	3	1	5	2	0	-2	2	0	0	0.488354119971917	31	
i 1	59.01032653061225	1.01	61	199	5	19	14	1	0	1	1	0	0	5.290431105685503	31	
i 1	59.01157823129252	1.01	63	585	6	17	14	16	0	1	16	0	0	5.290431105685503	31	
i 1	59.01533333333333	0.2525	69	199	6	9	1	0	5000	0	0	0	0	3.0	31	
i 1	59.01533333333333	1.01	63	199	5	18	13	1	5000	2	1	0	0	5.290431105685503	31	
i 1	59.236544217687076	0.2525	69	901	5	2	6	1	0	0	1	0	0	4.0	31	
i 1	59.2421768707483	0.2525	71	585	6	5	9	8	0	-2	8	0	0	3.0065128918243444	31	
i 1	59.2578231292517	0.2525	71	199	4	1	14	2	5000	-2	2	0	0	0.488354119971917	31	
i 1	59.49405442176871	0.2525	72	901	5	2	2	1	0	0	1	0	0	4.0	31	
i 1	59.51220408163265	0.2525	71	585	6	1	16	2	0	-2	2	0	0	0.488354119971917	31	
i 1	59.740925170068024	0.2525	73	199	3	24	10	8	0	-2	8	0	0	4.0	31	
i 1	59.98779591836735	2.02	63	1098	5	17	11	16	0	1	16	0	0	2.6452155528427514	32	
i 1	59.98842176870748	8.585	63	712	4	19	7	1	0	2	1	0	0	2.6452155528427514	32	
i 1	59.98842176870748	2.02	63	1098	5	25	14	16	0	1	16	0	0	3.464695636917311	32	
i 1	59.98967346938775	2.02	69	1098	5	2	2	1	0	-1	1	0	0	4.0	32	
i 1	59.990925170068024	4.04	61	1098	5	25	11	1	0	2	1	0	0	3.464695636917311	32	
i 1	59.99155102040816	2.02	73	712	3	24	5	8	0	-2	8	0	0	4.0	32	
i 1	59.99155102040816	4.04	63	712	3	13	7	16	5001	2	16	0	0	5.252323524405568	32	
i 1	59.99405442176871	8.585	61	712	4	19	6	1	0	2	1	0	0	2.6452155528427514	32	
i 1	59.99530612244898	8.08	63	199	5	18	11	1	5000	2	1	0	0	2.6452155528427514	32	
i 1	59.99718367346939	8.585	61	712	3	27	7	1	0	2	1	0	0	4.619594182556415	32	
i 1	60.00156462585034	2.02	61	712	6	17	11	16	5001	1	16	0	0	2.6452155528427514	32	
i 1	60.00156462585034	6.0600000000000005	61	712	5	25	1	1	5001	2	1	0	0	3.464695636917311	32	
i 1	60.00281632653061	8.585	63	199	5	26	6	1	5000	2	1	0	0	3.464695636917311	32	
i 1	60.00281632653061	2.02	61	712	3	27	13	1	0	1	1	0	0	4.619594182556415	32	
i 1	60.00344217687075	2.02	63	1098	3	14	12	16	0	2	16	0	0	7.0168023826207016	32	
i 1	60.005319727891155	8.08	61	712	5	25	13	1	5001	2	1	0	0	3.464695636917311	32	
i 1	60.00594557823129	1.7675	71	1098	6	5	14	2	0	-1	2	0	0	3.005510908466753	32	
i 1	60.0078231292517	8.585	61	1098	5	14	12	1	0	2	1	0	0	7.0168023826207016	32	
i 1	60.01095238095238	4.04	61	712	6	17	7	16	5001	1	16	0	0	2.6452155528427514	32	
i 1	60.01095238095238	6.0600000000000005	63	199	5	18	14	16	5000	1	16	0	0	2.6452155528427514	32	
i 1	60.01157823129252	8.585	63	199	5	26	12	1	5000	1	1	0	0	3.464695636917311	32	
i 1	60.50657142857143	0.505	72	199	6	9	16	1	5000	0	1	0	0	3.0	33	
i 1	60.76095238095238	0.2525	74	712	6	5	1	8	0	-1	8	0	0	3.005510908466753	33	
i 1	61.0078231292517	0.505	69	712	5	3	2	0	5001	-1	0	0	0	4.0	33	
i 1	61.25844897959184	0.2525	74	199	7	5	4	8	5000	-1	8	0	0	3.005510908466753	33	
i 1	61.73967346938775	0.7575000000000001	72	712	4	4	4	0	0	-1	0	0	0	4.0	33	
i 1	61.7578231292517	2.525	71	712	6	5	5	8	5001	-2	8	0	0	3.005510908466753	33	
i 1	61.98904761904762	2.02	61	712	5	17	1	16	5001	1	16	0	0	2.6452155528427514	33	
i 1	61.99029931972789	6.565	63	1098	5	25	5	16	0	1	16	0	0	3.464695636917311	33	
i 1	61.99342857142857	6.565	61	712	3	27	15	1	0	1	1	0	0	4.619594182556415	33	
i 1	61.99718367346939	1.01	71	712	6	1	8	8	5001	-1	8	0	0	0.031506717417543406	33	
i 1	62.00469387755102	0.505	74	712	4	24	16	8	5001	-1	8	0	0	3.0315067174175434	33	
i 1	62.00469387755102	6.565	63	1098	5	14	9	16	0	2	16	0	0	7.0168023826207016	33	
i 1	62.235292517006805	0.7575000000000001	72	199	6	9	3	1	5000	0	1	0	0	3.0	33	
i 1	62.50093877551021	0.2525	73	712	3	24	12	8	0	-1	8	0	0	4.0	33	
i 1	62.50844897959184	0.2525	71	199	7	1	5	2	5000	-2	2	0	0	0.031506717417543406	33	
i 1	62.99530612244898	0.2525	69	712	5	3	13	0	0	-1	0	0	0	4.0	33	
i 1	63.0078231292517	0.505	72	712	4	4	5	0	0	-1	0	0	0	4.0	33	
i 1	63.00970068027211	0.7575000000000001	74	712	6	5	4	8	0	-1	8	0	0	3.005510908466753	33	
i 1	63.23904761904762	0.2525	69	199	6	9	3	0	5000	0	0	0	0	3.0	33	
i 1	63.49968707482993	0.2525	70	199	1	24	3	2	5000	-1	2	0	0	4.0	33	
i 1	63.51157823129252	0.2525	72	712	4	4	1	1	5001	-1	1	0	0	4.0	33	
i 1	63.98967346938775	2.02	74	712	4	24	10	8	5001	-1	8	0	0	3.0315067174175434	33	
i 1	63.99530612244898	4.545	61	1098	5	25	15	1	0	2	1	0	0	3.464695636917311	33	
i 1	63.995931972789116	2.02	61	712	5	17	10	16	5001	1	16	0	0	2.6452155528427514	33	
i 1	63.99718367346939	6.0600000000000005	63	712	5	13	8	16	5001	2	16	0	0	5.252323524405568	33	
i 1	64.0028163265306	0.2525	73	712	1	24	11	8	5001	-1	8	0	0	4.0	33	
i 1	64.0097006802721	1.01	70	199	1	24	4	2	5000	-1	2	0	0	4.0	33	
i 1	64.24593197278912	0.2525	69	1098	5	2	12	1	0	-1	1	0	0	4.0	33	
i 1	64.50531972789116	0.2525	71	712	6	5	13	8	5001	-2	8	0	0	3.005510908466753	34	
i 1	64.51157823129252	1.7675	71	1098	6	5	8	2	0	-1	2	0	0	3.005510908466753	34	
i 1	64.75406802721088	0.2525	71	199	7	1	4	2	5000	-2	2	0	0	0.031506717417543406	34	
i 1	64.76220408163265	0.2525	73	712	1	24	10	8	5001	-1	8	0	0	4.0	34	
i 1	64.98591836734694	0.505	74	199	7	1	4	8	5000	-2	8	0	0	0.031506717417543406	34	
i 1	65.00719727891156	3.535	73	712	1	24	2	8	5001	252	8	307	0	4.0	34	
i 1	65.01220408163265	0.505	72	712	4	4	14	1	5001	-1	1	0	0	4.0	34	
i 1	65.48779591836735	0.505	72	199	5	9	7	1	5000	0	1	0	0	3.0	34	
i 1	65.51282993197279	1.5150000000000001	71	1098	6	1	10	8	0	-2	8	0	0	0.031506717417543406	34	
i 1	65.99342857142857	0.2525	71	712	6	5	16	8	5001	-2	8	0	0	3.005510908466753	34	
i 1	65.99468027210884	1.01	72	1098	6	2	3	1	0	0	1	0	0	4.0	34	
i 1	65.99780952380952	2.02	63	199	5	18	8	16	5000	1	16	0	0	2.6452155528427514	34	
i 1	65.9990612244898	4.04	61	712	5	25	1	1	5001	2	1	0	0	3.464695636917311	34	
i 1	66.00594557823129	0.2525	71	712	6	1	2	2	0	-1	2	0	0	0.031506717417543406	34	
i 1	66.0078231292517	0.2525	71	1098	6	1	14	2	0	-2	2	0	0	0.031506717417543406	34	
i 1	66.0097006802721	1.5150000000000001	71	712	6	5	11	8	5001	-1	8	0	0	3.005510908466753	34	
i 1	66.01220408163265	0.2525	69	712	5	3	12	0	0	-1	0	0	0	4.0	34	
i 1	66.23904761904762	0.2525	74	199	7	5	3	8	5000	-1	8	0	0	3.005510908466753	34	
i 1	66.23967346938775	0.2525	71	712	6	1	16	8	5001	-1	8	0	0	0.031506717417543406	34	
i 1	66.24155102040817	0.2525	69	199	5	9	16	0	5000	0	0	0	0	3.0	34	
i 1	66.49342857142857	1.5150000000000001	74	712	4	24	8	8	5001	-1	8	0	0	3.0315067174175434	35	
i 1	66.98654421768707	0.2525	71	712	6	1	11	2	0	-1	2	0	0	0.031506717417543406	35	
i 1	66.98717006802721	2.02	69	712	5	3	1	0	5001	-1	0	0	0	4.0	35	
i 1	66.99405442176871	0.2525	72	712	4	4	7	0	0	-1	0	0	0	4.0	35	
i 1	67.01533333333333	0.2525	74	199	7	1	15	8	5000	-2	8	0	0	0.031506717417543406	35	
i 1	67.2402993197279	0.2525	71	1098	6	5	10	2	0	-1	2	0	0	3.005510908466753	35	
i 1	67.25657142857143	0.505	69	712	5	3	11	0	0	-1	0	0	0	4.0	35	
i 1	67.48591836734694	0.505	74	199	7	5	16	8	5000	-1	8	0	0	3.005510908466753	35	
i 1	67.49593197278912	0.2525	74	712	6	5	14	8	0	-1	8	0	0	3.005510908466753	35	
i 1	67.7647074829932	0.505	71	712	6	5	15	8	5001	-1	8	0	0	3.005510908466753	35	
i 1	67.98591836734694	0.7575000000000001	71	712	6	1	13	8	5001	-1	8	0	0	0.031506717417543406	35	
i 1	67.98967346938775	2.02	61	712	5	25	5	1	5001	2	1	0	0	3.464695636917311	35	
i 1	67.9921768707483	0.2525	71	712	6	5	3	8	0	-2	8	0	0	3.005510908466753	35	
i 1	67.99968707482994	0.505	63	199	5	18	6	1	5000	2	1	0	0	2.6452155528427514	35	
i 1	68.00344217687075	0.7575000000000001	71	712	6	5	12	8	5001	-2	8	0	0	3.005510908466753	35	
i 1	68.01408163265306	0.505	70	199	1	24	1	2	5000	-1	2	0	0	4.0	35	
i 1	68.24468027210884	0.2525	71	1098	6	1	13	2	0	-2	2	0	0	0.031506717417543406	35	
i 1	68.25594557823129	0.2525	71	1098	6	5	7	2	0	-1	2	0	0	3.005510908466753	35	
i 1	68.26345578231293	0.2525	71	1098	6	5	3	2	0	-2	2	0	0	3.005510908466753	35	
i 1	68.48466666666667	1.5150000000000001	63	4	5	19	14	1	0	1	1	0	0	2.6452155528427514	36	
i 1	68.48717006802721	1.5150000000000001	74	4	7	1	6	8	0	-2	8	0	0	0.031506717417543406	36	
i 1	68.49155102040817	3.535	72	4	7	2	10	0	0	-1	0	0	0	4.0	36	
i 1	68.49155102040817	3.535	63	4	5	19	10	1	0	2	1	0	0	2.6452155528427514	36	
i 1	68.49155102040817	5.555	61	4	4	27	15	16	0	1	16	0	0	4.619594182556415	36	
i 1	68.49155102040817	7.575	63	4	4	27	13	1	0	2	1	0	0	4.619594182556415	36	
i 1	68.49280272108844	3.535	63	390	4	26	10	16	0	1	16	0	0	3.464695636917311	36	
i 1	68.49280272108844	1.2625	74	4	7	5	13	8	0	-2	8	0	0	3.005510908466753	36	
i 1	68.49530612244898	7.575	63	4	6	25	9	16	0	2	16	0	0	3.464695636917311	36	
i 1	68.4971836734694	1.5150000000000001	63	390	4	26	5	16	0	2	16	0	0	3.464695636917311	36	
i 1	68.50156462585034	1.5150000000000001	61	390	4	18	12	16	0	1	16	0	0	2.6452155528427514	36	
i 1	68.50594557823129	1.5150000000000001	63	4	6	14	1	1	0	2	1	0	0	7.0168023826207016	36	
i 1	68.50907482993198	7.575	61	4	6	25	10	1	0	2	1	0	0	3.464695636917311	36	
i 1	68.5097006802721	3.535	61	4	6	14	3	1	0	2	1	0	0	7.0168023826207016	36	
i 1	68.7528163265306	0.505	71	4	6	5	4	2	0	-2	2	0	0	3.005510908466753	36	
i 1	69.25907482993198	0.2525	69	4	4	3	9	1	0	0	1	0	0	4.0	36	
i 1	69.26220408163265	0.7575000000000001	71	712	6	1	8	8	5001	-1	8	0	0	0.031506717417543406	36	
i 1	69.5009387755102	0.505	69	4	5	4	14	1	0	-1	1	0	0	4.0	37	
i 1	69.73779591836735	0.2525	74	712	4	24	14	8	5001	-1	8	0	0	3.0315067174175434	37	
i 1	69.98717006802721	6.0600000000000005	63	390	4	26	13	16	0	2	16	0	0	3.464695636917311	38	
i 1	69.99280272108844	4.04	66	888	5	13	6	6	0	1	6	0	0	5.252323524405568	38	
i 1	69.99468027210884	0.2525	74	390	6	1	9	8	0	-1	8	0	0	0.031506717417543406	38	
i 1	69.99655782312925	2.02	63	4	4	19	10	1	0	1	1	0	0	2.6452155528427514	38	
i 1	69.9971836734694	9.09	66	888	5	25	13	9	0	2	9	0	0	3.464695636917311	38	
i 1	70.00531972789116	6.0600000000000005	63	4	6	14	9	1	0	2	1	0	0	7.0168023826207016	38	
i 1	70.00907482993198	9.09	66	888	5	25	4	9	0	1	9	0	0	3.464695636917311	38	
i 1	70.01095238095238	0.2525	74	4	7	5	11	8	0	-2	8	0	0	3.005510908466753	38	
i 1	70.01282993197279	3.2825	72	888	4	24	14	2	0	-2	2	0	0	3.0315067174175434	38	
i 1	70.01408163265306	0.2525	72	888	6	1	6	2	0	-2	2	0	0	0.031506717417543406	38	
i 1	70.24092517006802	0.2525	71	390	6	5	8	8	0	-2	8	0	0	3.005510908466753	38	
i 1	70.24968707482994	0.2525	69	4	4	4	3	1	0	-1	1	0	0	4.0	38	
i 1	70.25907482993198	0.505	71	4	5	24	6	8	0	-1	8	0	0	3.0315067174175434	38	
i 1	70.7597006802721	1.01	69	4	4	4	12	1	0	-1	1	0	0	4.0	38	
i 1	70.98466666666667	1.2625	74	4	7	1	11	8	0	-2	8	0	0	0.031506717417543406	38	
i 1	71.00594557823129	0.2525	71	390	6	1	10	8	0	-1	8	0	0	0.031506717417543406	38	
i 1	71.01408163265306	1.01	74	4	7	5	3	8	0	-2	8	0	0	3.005510908466753	38	
i 1	71.4971836734694	2.02	74	888	6	5	6	17	0	1	17	0	0	3.005510908466753	38	
i 1	71.74468027210884	0.505	75	888	5	3	4	2	0	1	2	0	0	4.0	38	
i 1	71.98466666666667	2.02	63	4	4	19	11	1	0	2	1	0	0	2.6452155528427514	38	
i 1	71.98654421768707	4.04	61	4	6	14	10	1	0	2	1	0	0	7.0168023826207016	38	
i 1	71.98779591836735	4.04	63	390	4	26	10	16	0	1	16	0	0	3.464695636917311	38	
i 1	72.00406802721088	0.7575000000000001	72	4	6	2	12	0	0	-1	0	0	0	4.0	38	
i 1	72.26408163265306	2.02	69	4	6	2	4	0	0	-1	0	0	0	4.0	38	
i 1	72.51345578231293	0.7575000000000001	69	4	4	4	3	1	0	-1	1	0	0	4.0	38	
i 1	72.73466666666667	0.2525	71	4	6	5	9	2	0	-2	2	0	0	3.005510908466753	38	
i 1	72.74405442176871	0.2525	75	888	5	3	16	2	0	1	2	0	0	4.0	38	
i 1	72.99405442176871	0.7575000000000001	72	390	5	9	3	0	0	0	0	0	0	3.0	38	
i 1	73.00156462585034	0.2525	73	390	1	24	11	2	0	-1	2	0	0	4.0	38	
i 1	73.25156462585034	0.505	74	4	5	1	9	8	0	-1	8	0	0	0.031506717417543406	38	
i 1	73.2578231292517	0.2525	75	888	5	3	13	2	0	1	2	0	0	4.0	38	
i 1	73.51032653061225	0.2525	74	4	6	5	1	8	0	-1	8	0	0	3.005510908466753	38	
i 1	73.74092517006802	0.505	71	4	6	5	15	2	0	-2	2	0	0	3.005510908466753	38	
i 1	73.74843537414966	0.505	71	888	1	24	11	1	0	-1	1	0	0	4.0	38	
i 1	73.76220408163265	1.01	75	888	4	4	12	2	0	-2	2	0	0	4.0	38	
i 1	74.00907482993198	2.02	61	4	4	27	12	16	0	1	16	0	0	4.619594182556415	39	
i 1	74.01220408163265	5.05	66	888	5	13	12	6	0	1	6	0	0	5.252323524405568	39	
i 1	74.01345578231293	0.2525	74	390	6	5	16	2	0	-1	2	0	0	3.005510908466753	39	
i 1	74.23904761904762	0.2525	69	4	4	3	9	1	0	0	1	0	0	4.0	39	
i 1	74.24280272108844	1.7675	75	888	5	3	1	2	0	1	2	0	0	4.0	39	
i 1	74.2597006802721	0.505	74	4	5	1	5	8	0	-1	8	0	0	0.031506717417543406	39	
i 1	74.48904761904762	0.2525	72	4	6	2	1	0	0	-1	0	0	0	4.0	39	
i 1	74.75594557823129	0.2525	74	390	6	5	11	2	0	-1	2	0	0	3.005510908466753	39	
i 1	74.75719727891156	1.01	72	390	5	9	10	0	0	-1	0	0	0	3.0	39	
i 1	74.99405442176871	0.2525	74	888	6	5	5	17	0	1	17	0	0	3.005510908466753	39	
i 1	75.2352925170068	0.7575000000000001	71	4	5	24	15	8	0	-1	8	0	0	3.0315067174175434	39	
i 1	75.2528163265306	0.2525	75	888	4	4	3	2	0	-2	2	0	0	4.0	39	
i 1	75.25344217687075	0.7575000000000001	74	4	7	5	6	8	0	-2	8	0	0	3.005510908466753	39	
i 1	75.48654421768707	0.505	69	4	6	2	11	0	0	-1	0	0	0	4.0	39	
i 1	75.7647074829932	0.2525	75	888	4	4	6	2	0	-2	2	0	0	4.0	39	
i 1	75.98717006802721	0.2525	72	186	5	1	13	2	0	1	2	0	0	0.031506717417543406	40	
i 1	75.98717006802721	7.575	61	186	4	27	7	9	0	1	9	0	0	4.619594182556415	40	
i 1	75.98717006802721	0.505	77	186	7	5	16	16	0	2	16	0	0	3.005510908466753	40	
i 1	75.98842176870748	0.2525	77	186	7	5	4	17	0	2	17	0	0	3.005510908466753	40	
i 1	75.98904761904762	7.575	61	1070	5	14	1	9	0	1	9	0	0	7.0168023826207016	40	
i 1	75.9902993197279	0.2525	68	186	1	24	1	1	0	0	1	0	0	4.0	40	
i 1	75.9921768707483	7.575	66	1070	5	14	8	6	0	1	6	0	0	7.0168023826207016	40	
i 1	76.00531972789116	7.575	66	1070	5	25	3	6	0	2	6	0	0	3.464695636917311	40	
i 1	76.00657142857143	7.575	61	186	4	27	8	9	0	1	9	0	0	4.619594182556415	40	
i 1	76.00719727891156	1.2625	75	888	4	4	1	2	0	-2	2	0	0	4.0	40	
i 1	76.00719727891156	7.575	61	1070	5	25	3	9	0	1	9	0	0	3.464695636917311	40	
i 1	76.00719727891156	12.625	61	186	5	26	16	6	0	1	6	0	0	3.464695636917311	40	
i 1	76.00907482993198	7.575	72	1070	6	1	3	2	0	-2	2	0	0	0.031506717417543406	40	
i 1	76.01032653061225	12.625	61	186	5	26	3	6	0	1	6	0	0	3.464695636917311	40	
i 1	76.01157823129252	3.2825	74	1070	6	5	12	16	0	1	16	0	0	3.005510908466753	40	
i 1	76.2402993197279	0.7575000000000001	74	888	6	5	6	17	0	1	17	0	0	3.005510908466753	40	
i 1	76.51157823129252	0.2525	72	888	4	24	11	2	0	-2	2	0	0	3.0315067174175434	40	
i 1	76.51220408163265	0.505	75	186	5	24	1	2	0	1	2	0	0	3.0315067174175434	40	
i 1	76.7421768707483	0.505	74	888	6	5	12	16	0	2	16	0	0	3.005510908466753	40	
i 1	76.98466666666667	1.01	74	1070	6	5	16	17	0	1	17	0	0	3.005510908466753	40	
i 1	77.01282993197279	0.2525	72	186	6	1	1	2	0	1	2	0	0	0.031506717417543406	40	
i 1	77.0147074829932	0.505	75	186	4	4	5	8	0	-2	8	0	0	4.0	40	
i 1	77.23967346938775	0.2525	77	186	7	5	14	17	0	2	17	0	0	3.005510908466753	40	
i 1	77.48717006802721	0.505	75	888	4	4	15	2	0	-2	2	0	0	4.0	40	
i 1	77.51032653061225	0.2525	75	186	4	3	2	2	0	1	2	0	0	4.0	40	
i 1	77.75156462585034	0.2525	68	186	1	24	6	1	0	0	1	0	0	4.0	40	
i 1	77.75406802721088	0.7575000000000001	74	888	6	5	6	16	0	2	16	0	0	3.005510908466753	40	
i 1	77.98779591836735	0.2525	75	1070	5	2	6	2	0	1	2	0	0	4.0	41	
i 1	77.99092517006802	0.505	77	186	7	5	7	17	0	2	17	0	0	3.005510908466753	41	
i 1	77.99780952380952	0.2525	71	888	2	20	6	0	0	0	0	0	0	8.0	41	
i 1	77.9990612244898	0.505	72	186	5	9	3	2	0	-2	2	0	0	3.0	41	
i 1	78.01533333333333	0.2525	71	186	1	20	3	1	0	-1	1	0	0	8.0	41	
i 1	78.24342857142857	1.2625	71	186	1	20	9	1	0	0	1	0	0	8.0	41	
i 1	78.49468027210884	0.505	75	186	4	4	4	8	0	-2	8	0	0	4.0	41	
i 1	78.4990612244898	0.2525	77	186	7	5	6	17	0	2	17	0	0	3.005510908466753	41	
i 1	78.74342857142857	0.2525	75	888	4	4	4	2	0	-2	2	0	0	4.0	41	
i 1	78.75594557823129	0.2525	74	888	6	5	16	16	0	2	16	0	0	3.005510908466753	41	
i 1	78.98717006802721	8.585	66	684	6	7	4	6	0	2	6	0	0	6.428642763215657	42	
i 1	78.98842176870748	0.2525	75	186	5	24	5	2	0	1	2	0	0	3.0315067174175434	42	
i 1	78.99780952380952	8.585	66	684	5	13	10	9	0	1	9	0	0	5.252323524405568	42	
i 1	79.00469387755102	0.7575000000000001	75	684	4	4	4	2	0	-2	2	0	0	4.0	42	
i 1	79.00594557823129	8.585	66	684	5	25	12	6	0	2	6	0	0	3.464695636917311	42	
i 1	79.0147074829932	8.585	66	684	5	25	16	9	0	2	9	0	0	3.464695636917311	42	
i 1	79.25031292517006	2.02	75	684	5	3	10	8	0	-2	8	0	0	4.0	42	
i 1	79.50469387755102	0.7575000000000001	74	1070	6	5	11	16	0	1	16	0	0	3.005510908466753	43	
i 1	79.99530612244898	0.505	77	186	7	5	9	17	0	2	17	0	0	3.005510908466753	43	
i 1	79.99968707482994	0.2525	72	1070	6	1	3	2	0	1	2	0	0	0.031506717417543406	43	
i 1	80.23904761904762	1.5150000000000001	74	1070	6	5	15	17	0	1	17	0	0	3.005510908466753	43	
i 1	80.25531972789116	0.505	75	684	6	1	7	8	0	-2	8	0	0	0.031506717417543406	43	
i 1	80.26408163265306	1.7675	68	186	1	24	15	1	0	252	1	307	0	4.0	43	
i 1	80.49968707482994	0.2525	72	186	5	1	11	2	0	1	2	0	0	0.031506717417543406	43	
i 1	80.5097006802721	0.2525	77	186	7	5	4	17	0	2	17	0	0	3.005510908466753	43	
i 1	80.51408163265306	1.5150000000000001	75	1070	5	2	9	2	0	1	2	0	0	4.0	43	
i 1	80.99968707482994	0.2525	74	684	6	5	8	16	0	1	16	0	0	3.005510908466753	43	
i 1	81.25531972789116	0.7575000000000001	77	186	7	5	10	16	0	2	16	0	0	3.005510908466753	43	
i 1	81.26408163265306	0.2525	75	684	4	4	8	2	0	-2	2	0	0	4.0	43	
i 1	81.2647074829932	0.2525	75	186	5	4	7	8	0	-2	8	0	0	4.0	43	
i 1	81.49968707482994	0.2525	75	1070	5	2	6	2	0	1	2	0	0	4.0	43	
i 1	81.50031292517006	0.505	72	186	6	1	6	2	0	1	2	0	0	0.031506717417543406	43	
i 1	81.51533333333333	0.2525	75	684	5	3	7	8	0	-2	8	0	0	4.0	43	
i 1	81.73967346938775	0.7575000000000001	77	186	7	5	4	17	0	2	17	0	0	3.005510908466753	43	
i 1	81.74843537414966	0.505	75	186	6	1	9	2	0	1	2	0	0	0.031506717417543406	43	
i 1	81.99968707482994	0.2525	77	186	6	5	7	17	0	2	17	0	0	3.005510908466753	43	
i 1	82.00156462585034	1.5150000000000001	75	1070	5	2	12	2	0	1	2	0	0	4.0	43	
i 1	82.01408163265306	1.01	75	1070	4	2	7	2	0	1	2	0	0	4.0	43	
i 1	82.01533333333333	0.7575000000000001	68	186	2	24	5	1	0	0	1	0	0	4.0	43	
i 1	82.23717006802721	0.505	74	684	6	5	4	16	0	1	16	0	0	3.005510908466753	43	
i 1	82.24593197278912	0.505	72	186	5	9	4	2	0	-2	2	0	0	3.0	43	
i 1	82.24655782312925	0.2525	72	684	4	24	6	2	0	-2	2	0	0	3.0315067174175434	43	
i 1	82.48967346938775	0.2525	72	1070	6	1	16	2	0	1	2	0	0	0.031506717417543406	43	
i 1	82.50031292517006	0.2525	75	186	6	1	13	2	0	1	2	0	0	0.031506717417543406	43	
i 1	82.50907482993198	0.2525	77	186	7	5	2	16	0	2	16	0	0	3.005510908466753	43	
i 1	82.73591836734694	0.7575000000000001	74	1070	6	5	14	17	0	1	17	0	0	3.005510908466753	43	
i 1	82.76408163265306	0.2525	75	186	5	24	11	2	0	1	2	0	0	3.0315067174175434	43	
i 1	82.98904761904762	0.2525	75	186	5	4	13	8	0	-2	8	0	0	4.0	43	
i 1	82.99780952380952	0.2525	71	186	1	24	6	1	0	0	1	0	0	4.0	43	
i 1	83.24342857142857	1.01	72	684	4	24	1	2	0	-2	2	0	0	3.0315067174175434	43	
i 1	83.2647074829932	0.2525	74	684	6	5	9	16	0	1	16	0	0	3.005510908466753	43	
i 1	83.48466666666667	0.505	77	186	7	5	16	17	0	2	17	0	0	3.005510908466753	44	
i 1	83.48904761904762	0.2525	75	186	6	1	14	2	0	1	2	0	0	0.031506717417543406	44	
i 1	83.49155102040817	5.05	61	186	4	27	7	9	0	1	9	0	0	4.619594182556415	44	
i 1	83.4921768707483	5.555	66	888	5	14	15	6	0	1	6	0	0	7.0168023826207016	44	
i 1	83.49655782312925	5.555	66	888	5	25	5	6	0	1	6	0	0	3.464695636917311	44	
i 1	83.49780952380952	0.505	77	186	6	5	8	16	0	2	16	0	0	3.005510908466753	44	
i 1	83.50031292517006	0.505	75	888	5	2	4	2	0	1	2	0	0	4.0	44	
i 1	83.5028163265306	5.555	61	888	5	25	11	6	0	1	6	0	0	3.464695636917311	44	
i 1	83.50406802721088	5.555	61	888	5	14	12	9	0	2	9	0	0	7.0168023826207016	44	
i 1	83.51220408163265	5.05	61	186	4	27	5	9	0	1	9	0	0	4.619594182556415	44	
i 1	83.73842176870748	0.505	72	888	4	2	15	8	0	1	8	0	0	4.0	44	
i 1	83.75344217687075	0.2525	72	186	6	1	4	2	0	1	2	0	0	0.031506717417543406	44	
i 1	83.76157823129252	0.2525	72	888	6	1	3	2	0	1	2	0	0	0.031506717417543406	44	
i 1	83.99655782312925	0.2525	68	186	1	24	10	1	0	0	1	0	0	4.0	44	
i 1	83.9990612244898	1.5150000000000001	75	888	4	2	8	2	0	1	2	0	0	4.0	44	
i 1	83.99968707482994	1.5150000000000001	72	888	6	1	2	2	0	1	2	0	0	0.031506717417543406	44	
i 1	84.23904761904762	0.2525	72	186	4	1	9	2	0	1	2	0	0	0.031506717417543406	44	
i 1	84.2578231292517	0.2525	77	186	6	5	12	17	0	2	17	0	0	3.005510908466753	44	
i 1	84.26032653061225	0.2525	75	684	5	3	15	8	0	-2	8	0	0	4.0	44	
i 1	84.49280272108844	2.2725	72	684	4	24	9	2	0	-2	2	0	0	3.0315067174175434	44	
i 1	84.50469387755102	1.5150000000000001	72	888	4	2	3	8	0	1	8	0	0	4.0	44	
i 1	84.50594557823129	0.2525	75	186	6	1	9	2	0	1	2	0	0	0.031506717417543406	44	
i 1	85.23967346938775	2.02	75	684	4	4	2	2	0	-2	2	0	0	4.0	44	
i 1	85.24405442176871	0.505	75	186	4	24	15	2	0	1	2	0	0	3.0315067174175434	44	
i 1	85.49843537414966	0.2525	72	888	6	1	7	2	0	-2	2	0	0	0.031506717417543406	45	
i 1	85.76408163265306	0.2525	75	888	4	2	8	2	0	1	2	0	0	4.0	45	
i 1	86.2421768707483	0.2525	75	186	5	9	3	2	0	-2	2	0	0	3.0	45	
i 1	86.24593197278912	0.505	72	186	5	9	1	2	0	-2	2	0	0	3.0	45	
i 1	86.48466666666667	0.2525	77	186	6	5	10	17	0	2	17	0	0	3.005510908466753	45	
i 1	86.48591836734694	1.01	74	684	6	5	12	16	0	1	16	0	0	3.005510908466753	45	
i 1	86.49655782312925	1.5150000000000001	75	888	4	2	12	2	0	1	2	0	0	4.0	45	
i 1	86.75031292517006	0.2525	75	186	3	3	11	2	0	1	2	0	0	4.0	45	
i 1	86.76282993197279	0.2525	75	186	4	24	1	2	0	1	2	0	0	3.0315067174175434	45	
i 1	86.98717006802721	0.2525	72	186	6	1	4	2	0	1	2	0	0	0.031506717417543406	45	
i 1	86.9921768707483	0.2525	72	888	6	1	5	2	0	-2	2	0	0	0.031506717417543406	45	
i 1	87.26032653061225	1.7675	77	888	6	5	16	17	0	1	17	0	0	3.005510908466753	45	
i 1	87.49468027210884	0.505	77	186	6	5	8	17	0	2	17	0	0	3.005510908466753	46	
i 1	87.4971836734694	0.505	72	572	4	4	16	2	0	1	2	0	0	4.0	46	
i 1	87.50156462585034	0.2525	74	572	6	5	6	17	0	2	17	0	0	3.005510908466753	46	
i 1	87.50469387755102	1.5150000000000001	61	572	5	13	12	6	0	2	6	0	0	5.252323524405568	46	
i 1	87.50907482993198	0.2525	72	888	5	2	5	8	0	1	8	0	0	4.0	46	
i 1	87.51345578231293	1.5150000000000001	66	572	5	25	1	9	0	2	9	0	0	3.464695636917311	46	
i 1	87.51345578231293	1.5150000000000001	66	572	5	25	11	9	0	1	9	0	0	3.464695636917311	46	
i 1	87.99405442176871	1.01	72	572	4	4	13	2	0	1	2	0	0	4.0	46	
i 1	87.99593197278912	1.01	75	888	5	2	1	2	0	1	2	0	0	4.0	46	
i 1	88.00156462585034	0.505	72	888	4	2	6	8	0	1	8	0	0	4.0	46	
i 1	88.23904761904762	0.2525	68	186	1	24	16	1	0	0	1	0	0	4.0	46	
i 1	88.26533333333333	0.7575000000000001	72	572	4	24	7	2	0	1	2	0	0	3.0315067174175434	46	
i 1	88.48904761904762	0.505	71	185	1	24	9	0	0	248	0	308	0	4.0	47	
i 1	88.49280272108844	0.505	66	1154	4	26	4	6	0	1	6	0	0	3.464695636917311	47	
i 1	88.49530612244898	0.505	71	1154	1	24	7	1	0	0	1	0	0	4.0	47	
i 1	88.4990612244898	0.505	66	1154	4	26	5	6	0	2	6	0	0	3.464695636917311	47	
i 1	88.4990612244898	0.505	61	185	4	27	9	9	0	1	9	0	0	4.619594182556415	47	
i 1	88.4990612244898	0.505	77	1154	6	5	14	17	0	1	17	0	0	3.005510908466753	47	
i 1	88.50406802721088	0.505	66	185	4	27	10	6	0	2	6	0	0	4.619594182556415	47	
i 1	88.50469387755102	0.505	71	185	1	24	13	0	0	252	0	307	0	4.0	47	
i 1	88.74593197278912	0.2525	72	572	4	3	14	2	0	-2	2	0	0	4.0	47	
i 1	88.76533333333333	0.2525	71	572	1	24	15	0	0	0	0	0	0	4.0	47	
i 1	88.98591836734694	1.01	66	193	6	25	2	6	0	2	6	0	0	3.464695636917311	48	
i 1	88.98654421768707	1.01	66	193	6	13	12	6	0	1	6	0	0	5.252323524405568	48	
i 1	88.98904761904762	0.2525	77	691	4	5	7	16	5002	1	16	0	0	3.005510908466753	48	
i 1	88.99780952380952	1.01	61	691	5	25	2	6	0	1	6	0	0	3.464695636917311	48	
i 1	89.0009387755102	1.01	66	1077	4	26	14	9	0	1	9	0	0	3.464695636917311	48	
i 1	89.0028163265306	1.01	61	691	5	14	11	6	0	2	6	0	0	7.0168023826207016	48	
i 1	89.00406802721088	1.01	66	1077	4	26	4	9	0	1	9	0	0	3.464695636917311	48	
i 1	89.00469387755102	1.01	61	691	3	27	16	9	5002	2	9	0	0	4.619594182556415	48	
i 1	89.00469387755102	1.01	61	691	3	27	5	6	5002	2	6	0	0	4.619594182556415	48	
i 1	89.01220408163265	0.505	72	193	4	4	9	2	0	1	2	0	0	4.0	48	
i 1	89.01345578231293	1.01	66	691	5	14	6	6	0	1	6	0	0	7.0168023826207016	48	
i 1	89.0147074829932	1.01	66	691	5	25	12	6	0	2	6	0	0	3.464695636917311	48	
i 1	89.0147074829932	1.01	77	691	6	5	7	17	0	2	17	0	0	3.005510908466753	48	
i 1	89.01533333333333	1.01	61	193	6	25	11	6	0	2	6	0	0	3.464695636917311	48	
i 1	89.2490612244898	0.505	75	691	4	24	10	2	5002	1	2	0	0	3.0315067174175434	48	
i 1	89.50844897959183	0.2525	72	193	4	3	3	2	0	1	2	0	0	4.0	48	
i 1	89.73779591836735	0.2525	75	1077	4	9	8	2	0	1	2	0	0	3.0	48	
i 1	89.98967346938775	4.04	61	691	5	14	12	6	0	2	6	0	0	6.0219224595203	48	
i 1	89.99092517006802	0.7575000000000001	72	691	4	2	13	2	0	1	2	0	0	7.0	48	
i 1	89.99155102040817	10.1	61	193	7	7	4	6	0	2	6	0	0	5.433762840115255	48	
i 1	89.99968707482994	8.08	66	193	6	13	1	6	0	1	6	0	0	4.257443601305166	48	
i 1	90.00594557823129	6.0600000000000005	66	691	5	14	16	6	0	1	6	0	0	6.0219224595203	48	
i 1	90.01345578231293	0.2525	72	193	4	4	13	2	0	1	2	0	0	7.0	48	
i 1	90.25469387755102	1.2625	72	691	4	2	8	8	0	1	8	0	0	7.0	48	
i 1	90.2647074829932	0.505	74	1077	5	5	13	17	0	1	17	0	0	3.0005725619186236	48	
i 1	90.51032653061225	0.2525	72	691	3	3	14	2	5002	1	2	0	0	7.0	48	
i 1	90.75469387755102	0.2525	77	691	4	5	10	16	5002	1	16	0	0	3.0005725619186236	48	
i 1	90.7578231292517	1.01	72	1077	3	9	12	8	0	-2	8	0	0	6.0	48	
i 1	90.76095238095238	1.2625	72	193	4	4	4	2	0	1	2	0	0	7.0	48	
i 1	90.76095238095238	0.2525	77	691	4	5	12	17	5002	2	17	0	0	3.0005725619186236	48	
i 1	91.0009387755102	0.2525	77	193	6	5	1	16	0	2	16	0	0	3.0005725619186236	48	
i 1	91.00156462585034	0.2525	77	691	6	5	12	17	0	2	17	0	0	3.0005725619186236	48	
i 1	91.48466666666667	0.2525	77	1077	5	5	2	16	0	2	16	0	0	3.0005725619186236	48	
i 1	91.5009387755102	0.2525	72	691	3	4	11	2	5002	-2	2	0	0	7.0	48	
i 1	91.50469387755102	0.505	77	691	6	5	7	17	0	2	17	0	0	3.0005725619186236	48	
i 1	91.74780952380952	0.2525	75	1077	4	9	2	2	0	1	2	0	0	6.0	48	
i 1	91.75469387755102	2.2725	72	691	4	2	4	2	0	1	2	0	0	7.0	48	
i 1	91.9921768707483	0.2525	74	1077	5	5	9	17	0	1	17	0	0	3.0005725619186236	48	
i 1	91.99280272108844	0.505	72	193	5	4	16	2	0	1	2	0	0	7.0	48	
i 1	92.0097006802721	2.02	77	193	6	5	4	16	0	2	16	0	0	3.0005725619186236	48	
i 1	92.26157823129252	0.2525	77	691	4	5	3	17	5002	2	17	0	0	3.0005725619186236	48	
i 1	92.73967346938775	0.2525	74	691	6	5	5	16	0	2	16	0	0	3.0005725619186236	48	
i 1	92.99780952380952	0.2525	74	193	6	5	10	17	0	2	17	0	0	3.0005725619186236	49	
i 1	93.01095238095238	0.2525	74	1077	5	5	5	17	0	1	17	0	0	3.0005725619186236	49	
i 1	93.2490612244898	0.2525	74	691	6	5	3	16	0	2	16	0	0	3.0005725619186236	49	
i 1	93.48779591836735	1.5150000000000001	74	193	6	5	8	17	0	2	17	0	0	3.0005725619186236	49	
i 1	93.49655782312925	1.5150000000000001	72	691	4	2	10	8	0	1	8	0	0	7.0	49	
i 1	93.75907482993198	0.7575000000000001	77	1077	5	5	11	16	0	2	16	0	0	3.0005725619186236	49	
i 1	93.9990612244898	12.625	61	691	3	14	3	6	0	2	6	0	0	6.0219224595203	49	
i 1	94.23591836734694	2.7775	74	691	6	5	10	16	0	2	16	0	0	3.0005725619186236	49	
i 1	94.50156462585034	2.02	72	691	4	2	2	2	0	1	2	0	0	7.0	49	
i 1	94.50344217687075	0.2525	75	691	4	24	12	2	5002	1	2	0	0	3.0	49	
i 1	94.50844897959183	0.2525	77	691	4	5	7	16	5002	1	16	0	0	3.0005725619186236	49	
i 1	94.74530612244898	1.01	77	691	4	5	12	17	5002	2	17	0	0	3.0005725619186236	49	
i 1	94.98779591836735	0.2525	71	193	2	24	2	0	0	0	0	0	0	4.0	50	
i 1	94.9971836734694	1.2625	71	1077	1	24	12	0	0	-1	0	0	0	4.0	50	
i 1	95.25344217687075	0.2525	75	691	4	24	15	2	5002	1	2	0	0	3.0	50	
i 1	95.2597006802721	0.2525	77	1077	5	5	15	16	0	2	16	0	0	3.0005725619186236	50	
i 1	95.49655782312925	0.2525	75	1077	3	9	11	2	0	1	2	0	0	6.0	50	
i 1	95.49968707482994	0.505	72	193	4	3	16	2	0	1	2	0	0	7.0	50	
i 1	95.76282993197279	2.2725	72	193	4	4	15	2	0	1	2	0	0	7.0	50	
i 1	96.00031292517006	10.605	66	691	3	14	12	6	0	1	6	0	0	6.0219224595203	50	
i 1	96.01032653061225	4.04	77	691	6	5	5	17	0	2	17	0	0	3.0005725619186236	50	
i 1	96.23967346938775	0.2525	72	691	2	3	14	2	5002	1	2	0	0	7.0	50	
i 1	96.5028163265306	0.2525	77	691	4	5	4	17	5002	2	17	0	0	3.0005725619186236	50	
i 1	96.74155102040817	0.505	77	193	6	5	6	16	0	2	16	0	0	3.0005725619186236	50	
i 1	96.7597006802721	0.505	72	691	4	2	14	2	0	1	2	0	0	7.0	50	
i 1	97.0028163265306	2.02	71	1077	1	24	9	0	0	-1	0	0	0	4.0	51	
i 1	97.01220408163265	0.2525	74	1077	5	5	1	17	0	1	17	0	0	3.0005725619186236	51	
i 1	97.24780952380952	0.505	72	691	4	2	3	8	0	1	8	0	0	7.0	51	
i 1	97.25594557823129	0.2525	77	691	4	5	1	16	5002	1	16	0	0	3.0005725619186236	51	
i 1	97.25719727891156	1.2625	74	691	6	5	16	16	0	2	16	0	0	3.0005725619186236	51	
i 1	97.48967346938775	2.2725	72	691	4	2	11	2	0	1	2	0	0	7.0	51	
i 1	97.74342857142857	0.2525	72	691	2	4	11	2	5002	-2	2	0	0	7.0	51	
i 1	97.99280272108844	0.2525	74	1077	5	5	14	17	0	1	17	0	0	3.0005725619186236	52	
i 1	97.9990612244898	1.01	72	193	4	3	6	2	0	1	2	0	0	7.0	52	
i 1	98.01345578231293	8.585	66	193	3	13	16	6	0	1	6	0	0	4.257443601305166	52	
i 1	98.0147074829932	0.2525	72	691	3	3	6	2	5002	1	2	0	0	7.0	52	
i 1	98.25031292517006	0.2525	75	691	4	24	12	2	5002	1	2	0	0	3.0	52	
i 1	98.26345578231293	0.505	74	193	6	5	15	17	0	2	17	0	0	3.0005725619186236	52	
i 1	98.74780952380952	0.2525	74	1077	5	5	5	17	0	1	17	0	0	3.0005725619186236	53	
i 1	98.75844897959183	0.505	75	1077	3	9	6	2	0	1	2	0	0	6.0	53	
i 1	98.9902993197279	2.2725	72	691	4	2	5	8	0	1	8	0	0	7.0	53	
i 1	98.9921768707483	0.2525	77	691	4	5	16	17	5002	2	17	0	0	3.0005725619186236	53	
i 1	99.00657142857143	0.2525	74	193	6	5	1	17	0	2	17	0	0	3.0005725619186236	53	
i 1	99.25531972789116	3.2825	74	691	6	5	10	16	0	2	16	0	0	3.0005725619186236	53	
i 1	99.26095238095238	0.2525	72	1077	3	9	10	8	0	-2	8	0	0	6.0	53	
i 1	99.49092517006802	0.2525	77	1077	5	5	8	16	0	2	16	0	0	3.0005725619186236	53	
i 1	99.4990612244898	0.2525	72	193	4	3	9	2	0	1	2	0	0	7.0	53	
i 1	99.76220408163265	0.7575000000000001	72	1077	3	9	10	8	0	-2	8	0	0	6.0	53	
i 1	100.23654421768707	0.2525	75	691	4	24	7	2	5002	1	2	0	0	3.0	53	
i 1	100.26282993197279	0.2525	71	1077	1	24	8	0	0	-1	0	0	0	4.0	53	
i 1	100.4902993197279	0.505	72	691	3	4	5	2	5002	-2	2	0	0	7.0	53	
i 1	100.75469387755102	1.01	77	691	4	5	7	16	5002	1	16	0	0	3.0005725619186236	53	
i 1	101.00156462585034	0.2525	71	1077	1	24	13	0	0	-1	0	0	0	4.0	53	
i 1	101.25907482993198	0.2525	72	193	4	3	6	2	0	1	2	0	0	7.0	53	
i 1	101.4921768707483	0.2525	72	691	2	3	11	2	5002	1	2	0	0	7.0	53	
i 1	101.49342857142857	0.7575000000000001	71	1077	1	24	10	0	0	-1	0	0	0	4.0	53	
i 1	101.50594557823129	2.2725	72	193	5	24	8	2	0	-2	2	0	0	3.0	53	
i 1	101.7421768707483	0.2525	71	193	2	24	11	0	0	0	0	0	0	4.0	53	
i 1	101.74405442176871	2.02	77	193	6	5	1	16	0	2	16	0	0	3.0005725619186236	53	
i 1	101.74655782312925	0.2525	74	1077	5	5	12	17	0	1	17	0	0	3.0005725619186236	53	
i 1	102.26408163265306	0.2525	72	691	2	3	4	2	5002	1	2	0	0	7.0	53	
i 1	102.49530612244898	0.505	74	1077	5	5	6	17	0	1	17	0	0	3.0005725619186236	54	
i 1	102.51282993197279	0.2525	77	691	4	5	12	17	5002	2	17	0	0	3.0005725619186236	54	
i 1	102.75907482993198	0.505	72	1077	3	9	15	8	0	-2	8	0	0	6.0	54	
i 1	103.2528163265306	0.2525	72	193	4	3	15	2	0	1	2	0	0	7.0	54	
i 1	103.25344217687075	2.02	72	691	6	2	12	8	0	1	8	0	0	7.0	54	
i 1	103.25469387755102	0.2525	77	691	4	5	14	17	5002	2	17	0	0	3.0005725619186236	54	
i 1	103.73842176870748	0.505	77	691	4	5	2	16	5002	1	16	0	0	3.0005725619186236	54	
i 1	103.98591836734694	0.505	72	193	4	4	12	2	0	1	2	0	0	7.0	54	
i 1	103.99468027210884	0.7575000000000001	72	193	5	24	16	2	0	-2	2	0	0	3.0	54	
i 1	104.00219047619048	0.2525	77	691	6	5	5	17	0	2	17	0	0	3.0005725619186236	54	
i 1	104.25531972789116	0.2525	74	1077	5	5	3	17	0	1	17	0	0	3.0005725619186236	54	
i 1	104.26095238095238	0.505	77	691	4	5	1	17	5002	2	17	0	0	3.0005725619186236	54	
i 1	104.49342857142857	1.01	74	691	6	5	8	16	0	2	16	0	0	3.0005725619186236	55	
i 1	104.50156462585034	2.02	68	691	1	24	9	1	0	252	1	307	0	4.0	55	
i 1	104.73779591836735	0.2525	72	691	2	3	6	2	5002	1	2	0	0	7.0	55	
i 1	104.75844897959183	1.01	72	691	6	2	13	2	0	1	2	0	0	7.0	55	
i 1	104.99843537414966	0.2525	77	691	4	5	4	17	5002	2	17	0	0	3.0005725619186236	55	
i 1	105.24655782312925	1.2625	72	193	4	4	4	2	0	1	2	0	0	7.0	55	
i 1	105.7352925170068	0.7575000000000001	71	1077	1	24	1	0	0	-1	0	0	0	4.0	55	
i 1	105.74405442176871	0.2525	75	1077	3	9	4	2	0	1	2	0	0	6.0	55	
i 1	105.99843537414966	0.505	72	691	6	2	8	2	0	1	2	0	0	7.0	55	
i 1	106.00344217687075	0.505	77	193	6	5	7	16	0	2	16	0	0	3.0005725619186236	55	
i 1	106.24280272108844	0.2525	75	691	3	24	4	2	5002	1	2	0	0	3.0	55	
i 1	106.4902993197279	5.555	61	1098	3	14	14	9	0	2	9	0	0	6.0219224595203	56	
i 1	106.50469387755102	0.2525	71	214	2	24	6	1	5003	-1	1	0	0	4.0	56	
i 1	106.50531972789116	1.7675	75	1098	6	2	6	8	0	1	8	0	0	7.0	56	
i 1	106.51095238095238	0.2525	72	712	4	24	9	2	5001	1	2	0	0	3.0	56	
i 1	106.51095238095238	3.535	61	1098	3	14	5	9	0	2	9	0	0	6.0219224595203	56	
i 1	106.51345578231293	7.575	66	712	3	13	13	9	5001	2	9	0	0	4.257443601305166	56	
i 1	106.7402993197279	0.2525	72	691	2	3	8	2	5002	1	2	0	0	7.0	56	
i 1	106.74530612244898	0.505	71	712	2	24	13	1	5001	0	1	0	0	4.0	56	
i 1	107.00844897959183	0.2525	77	691	4	5	7	16	5002	1	16	0	0	3.0005725619186236	56	
i 1	107.01095238095238	1.2625	71	214	2	24	12	1	5003	-1	1	0	0	4.0	56	
i 1	107.2352925170068	0.2525	72	1098	6	2	1	8	0	-2	8	0	0	7.0	56	
i 1	107.25594557823129	0.505	68	691	1	24	3	1	5001	252	1	307	0	4.0	56	
i 1	107.50219047619048	0.2525	77	214	6	5	2	17	5003	2	17	0	0	3.0005725619186236	57	
i 1	107.50594557823129	0.2525	72	214	4	9	8	2	5003	-2	2	0	0	6.0	57	
i 1	107.74280272108844	0.2525	68	712	2	24	10	1	5001	0	1	0	0	4.0	57	
i 1	107.76032653061225	1.5150000000000001	72	1098	6	2	14	8	0	-2	8	0	0	7.0	57	
i 1	107.76282993197279	1.7675	72	712	4	24	14	2	5001	1	2	0	0	3.0	57	
i 1	107.98717006802721	0.2525	77	691	4	5	10	16	5002	1	16	0	0	3.0005725619186236	58	
i 1	108.24155102040817	0.2525	74	712	6	5	12	16	5001	2	16	0	0	3.0005725619186236	58	
i 1	108.26032653061225	0.505	77	1098	6	5	2	17	0	2	17	0	0	3.0005725619186236	58	
i 1	108.48654421768707	0.505	75	691	3	24	10	2	5002	1	2	0	0	3.0	58	
i 1	108.48779591836735	1.7675	71	214	2	24	2	1	5003	-1	1	0	0	4.0	58	
i 1	108.50031292517006	0.2525	72	214	4	9	12	2	5003	-2	2	0	0	6.0	58	
i 1	108.50844897959183	0.505	72	712	5	3	3	2	5001	1	2	0	0	7.0	58	
i 1	108.76157823129252	2.2725	75	712	4	4	1	8	5001	1	8	0	0	7.0	58	
i 1	108.99843537414966	0.505	74	214	6	5	3	16	5003	1	16	0	0	3.0005725619186236	58	
i 1	109.24280272108844	0.2525	75	1098	6	2	8	8	0	1	8	0	0	7.0	58	
i 1	109.50031292517006	0.2525	72	214	4	9	1	2	5003	-2	2	0	0	6.0	58	
i 1	109.51345578231293	0.2525	77	712	6	5	7	16	5001	1	16	0	0	3.0005725619186236	58	
i 1	109.76533333333333	2.02	74	712	6	5	14	16	5001	2	16	0	0	3.0005725619186236	58	
i 1	109.98779591836735	0.505	77	1098	6	5	14	17	0	1	17	0	0	3.0005725619186236	58	
i 1	109.99593197278912	0.505	71	691	1	24	9	0	5001	252	0	307	0	4.0	58	
i 1	110.00594557823129	4.04	61	1098	5	14	4	9	0	2	9	0	0	6.0219224595203	58	
i 1	110.23717006802721	2.02	75	1098	6	2	1	8	0	1	8	0	0	7.0	58	
i 1	110.49280272108844	0.2525	72	691	2	4	4	2	5002	-2	2	0	0	7.0	58	
i 1	110.50406802721088	2.02	72	712	4	24	14	2	5001	1	2	0	0	3.0	58	
i 1	110.51533333333333	0.2525	71	691	2	24	13	0	5001	0	0	0	0	4.0	58	
i 1	111.25594557823129	0.2525	75	712	4	4	10	8	5001	1	8	0	0	7.0	58	
i 1	111.49280272108844	0.2525	72	214	4	9	6	2	5003	-2	2	0	0	6.0	58	
i 1	111.4990612244898	0.2525	77	1098	6	5	13	17	0	2	17	0	0	3.0005725619186236	58	
i 1	111.7421768707483	0.2525	72	691	2	4	13	2	5002	-2	2	0	0	7.0	58	
i 1	111.7471836734694	0.2525	77	1098	6	5	9	17	0	1	17	0	0	3.0005725619186236	58	
i 1	111.75719727891156	0.2525	77	691	4	5	3	16	5002	1	16	0	0	3.0005725619186236	58	
i 1	111.99593197278912	2.02	61	1098	5	14	4	9	0	2	9	0	0	6.0219224595203	59	
i 1	112.00657142857143	0.2525	71	214	4	24	3	1	5003	-1	1	0	0	4.0	59	
i 1	112.0097006802721	0.505	72	214	6	9	13	2	5003	1	2	0	0	6.0	59	
i 1	112.25344217687075	2.02	72	712	5	3	6	2	5001	1	2	0	0	7.0	59	
i 1	112.50156462585034	1.01	72	691	2	3	6	2	5002	1	2	0	0	7.0	59	
i 1	112.50531972789116	0.7575000000000001	77	691	4	5	15	17	5002	2	17	0	0	3.0005725619186236	59	
i 1	112.7402993197279	0.505	74	712	6	5	14	16	5001	2	16	0	0	3.0005725619186236	59	
i 1	112.75907482993198	0.2525	72	214	6	9	2	2	5003	-2	2	0	0	6.0	59	
i 1	112.98466666666667	1.5150000000000001	75	712	4	4	5	8	5001	1	8	0	0	7.0	59	
i 1	113.23466666666667	0.7575000000000001	77	1098	6	5	2	17	0	2	17	0	0	3.0005725619186236	59	
i 1	113.2471836734694	0.505	77	214	6	5	12	17	5003	2	17	0	0	3.0005725619186236	59	
i 1	113.48654421768707	0.2525	71	214	4	24	15	1	5003	-1	1	0	0	4.0	59	
i 1	113.76157823129252	0.2525	74	214	6	5	16	16	5003	1	16	0	0	3.0005725619186236	59	
i 1	113.99530612244898	6.0600000000000005	61	185	6	14	12	9	5004	2	9	0	0	6.0219224595203	60	
i 1	114.00219047619048	0.2525	75	1069	3	24	13	2	0	1	2	0	0	3.0	60	
i 1	114.0028163265306	1.2625	74	185	7	5	13	17	5004	1	17	0	0	3.0005725619186236	60	
i 1	114.0028163265306	6.0600000000000005	66	712	5	13	14	9	5001	2	9	0	0	4.257443601305166	60	
i 1	114.0097006802721	0.2525	74	712	6	5	1	16	5001	2	16	0	0	3.0005725619186236	60	
i 1	114.01282993197279	6.0600000000000005	61	185	6	14	12	9	5004	1	9	0	0	6.0219224595203	60	
i 1	114.50219047619048	0.2525	74	1069	4	5	14	16	0	2	16	0	0	3.0005725619186236	60	
i 1	114.50531972789116	0.505	77	214	6	5	8	17	5003	2	17	0	0	3.0005725619186236	60	
i 1	114.74342857142857	1.2625	75	185	7	2	12	2	5004	1	2	0	0	7.0	60	
i 1	114.9971836734694	0.2525	74	1069	4	5	8	16	0	2	16	0	0	3.0005725619186236	60	
i 1	115.23779591836735	0.2525	74	214	6	5	10	16	5003	1	16	0	0	3.0005725619186236	60	
i 1	115.23779591836735	0.7575000000000001	71	214	4	24	8	1	5003	-1	1	0	0	4.0	60	
i 1	115.24530612244898	0.2525	77	214	6	5	10	17	5003	2	17	0	0	3.0005725619186236	60	
i 1	115.4852925170068	0.505	77	712	6	5	12	16	5001	1	16	0	0	3.0005725619186236	60	
i 1	115.48904761904762	0.2525	72	185	7	2	11	2	5004	-2	2	0	0	7.0	60	
i 1	115.5078231292517	0.2525	72	214	6	9	10	2	5003	-2	2	0	0	6.0	60	
i 1	115.50907482993198	0.2525	75	1069	3	24	2	2	0	1	2	0	0	3.0	60	
i 1	115.98717006802721	0.7575000000000001	71	214	1	24	10	1	5003	-1	1	0	0	4.0	61	
i 1	115.99843537414966	0.2525	72	214	6	9	13	2	5003	1	2	0	0	6.0	61	
i 1	116.00344217687075	1.01	75	185	6	2	13	2	5004	1	2	0	0	7.0	61	
i 1	116.00406802721088	2.02	77	185	7	5	13	17	5004	1	17	0	0	3.0005725619186236	61	
i 1	116.24468027210884	2.2725	75	712	4	4	16	8	5001	1	8	0	0	7.0	61	
i 1	116.25219047619048	0.2525	77	214	6	5	15	17	5003	2	17	0	0	3.0005725619186236	61	
i 1	116.25469387755102	0.505	72	712	5	3	16	2	5001	1	2	0	0	7.0	61	
i 1	116.50657142857143	0.505	74	1069	4	5	5	16	0	2	16	0	0	3.0005725619186236	61	
i 1	116.51345578231293	1.01	71	1069	2	24	15	1	0	0	1	0	0	4.0	61	
i 1	116.7471836734694	0.2525	72	214	6	9	2	2	5003	1	2	0	0	6.0	61	
i 1	116.98591836734694	0.505	72	1069	4	3	7	2	0	-2	2	0	0	7.0	62	
i 1	116.99843537414966	0.7575000000000001	72	214	6	9	2	2	5003	-2	2	0	0	6.0	62	
i 1	117.01408163265306	0.2525	77	214	6	5	4	17	5003	2	17	0	0	3.0005725619186236	62	
i 1	117.25719727891156	0.505	77	712	6	5	13	16	5001	1	16	0	0	3.0005725619186236	62	
i 1	117.26533333333333	0.2525	74	214	7	5	10	16	5003	1	16	0	0	3.0005725619186236	62	
i 1	117.50844897959183	0.2525	71	712	1	24	16	1	5001	-1	1	0	0	4.0	63	
i 1	117.76220408163265	0.2525	72	1069	4	3	9	2	0	-2	2	0	0	7.0	63	
i 1	117.76345578231293	0.2525	77	214	6	5	5	17	5003	2	17	0	0	3.0005725619186236	63	
i 1	117.98842176870748	2.02	77	712	6	5	3	16	5001	1	16	0	0	3.0005725619186236	63	
i 1	118.00219047619048	0.7575000000000001	72	185	6	2	15	2	5004	-2	2	0	0	7.0	63	
i 1	118.00344217687075	0.505	74	712	6	5	6	16	5001	2	16	0	0	3.0005725619186236	63	
i 1	118.00657142857143	1.2625	72	712	4	24	9	2	5001	1	2	0	0	3.0	63	
i 1	118.00657142857143	0.2525	72	214	6	9	9	2	5003	1	2	0	0	6.0	63	
i 1	118.0147074829932	2.2725	68	1069	2	24	2	1	0	0	1	0	0	4.0	63	
i 1	118.5028163265306	0.2525	72	1069	4	4	2	2	0	-2	2	0	0	7.0	63	
i 1	118.50719727891156	0.2525	74	185	7	5	1	17	5004	1	17	0	0	3.0005725619186236	63	
i 1	118.73904761904762	0.2525	77	1069	4	5	10	16	0	2	16	0	0	3.0005725619186236	63	
i 1	118.76533333333333	0.505	75	712	4	4	2	8	5001	1	8	0	0	7.0	63	
i 1	119.25406802721088	0.2525	72	185	6	2	15	2	5004	-2	2	0	0	7.0	63	
i 1	119.51220408163265	0.505	77	185	7	5	3	17	5004	1	17	0	0	3.0005725619186236	63	
i 1	119.73842176870748	0.2525	72	214	6	9	11	2	5003	1	2	0	0	6.0	63	
i 1	119.98591836734694	1.5150000000000001	66	712	5	15	5	9	5001	2	9	0	0	6.0427119593512675	63	
i 1	120.00156462585034	0.505	77	712	6	5	4	16	5001	1	16	0	0	3.0	63	
i 1	120.0028163265306	1.5150000000000001	66	185	6	14	10	6	5004	1	6	0	0	10.071186598918779	63	
i 1	120.00344217687075	0.505	74	712	6	5	15	16	5001	2	16	0	0	3.0	63	
i 1	120.00406802721088	1.5150000000000001	66	712	5	15	10	6	5001	1	6	0	0	6.0427119593512675	63	
i 1	120.00469387755102	1.5150000000000001	61	185	6	13	13	9	5004	2	9	0	0	4.028474639567512	63	
i 1	120.01157823129252	1.5150000000000001	61	185	6	14	9	9	5004	2	9	0	0	4.428294622370949	63	
i 1	120.01157823129252	1.5150000000000001	61	185	6	14	10	9	5004	1	9	0	0	4.428294622370949	63	
i 1	120.01157823129252	1.5150000000000001	66	712	5	13	7	9	5001	2	9	0	0	2.663815764155815	63	
i 1	120.01220408163265	1.5150000000000001	61	214	5	16	3	9	5003	2	9	0	0	8.056949279135024	63	
i 1	120.01533333333333	1.5150000000000001	61	214	5	16	2	9	5003	2	9	0	0	8.056949279135024	63	
i 1	120.01533333333333	0.2525	72	1069	4	4	9	2	0	-2	2	0	0	4.0	63	
i 1	120.01533333333333	0.2525	71	712	1	24	1	1	5001	-1	1	0	0	4.0	63	
i 1	120.48779591836735	0.2525	72	214	6	9	15	2	5003	1	2	0	0	3.0	63	
i 1	120.50156462585034	1.01	71	1069	1	24	5	0	5001	252	0	307	0	4.0	63	
i 1	120.50657142857143	0.2525	72	712	4	24	1	2	5001	1	2	0	0	3.0	63	
i 1	120.73466666666667	0.7575000000000001	74	185	7	5	12	17	5004	1	17	0	0	3.0	63	
i 1	120.99655782312925	0.505	74	214	6	5	11	16	5003	1	16	0	0	3.0	63	
i 1	121.2421768707483	0.2525	72	185	6	2	1	2	5004	-2	2	0	0	4.0	63	
i 1	121.4902993197279	0.505	72	203	7	2	7	1	0	-1	1	0	0	4.0	0	
i 1	121.49280272108844	2.02	63	203	6	14	12	16	0	1	16	0	0	5.293436574645402	0	
i 1	121.50219047619048	3.0300000000000002	63	1087	4	7	11	16	0	2	16	0	0	4.7052769552403575	0	
i 1	121.51032653061225	7.575	61	203	6	14	4	1	0	1	1	0	0	5.293436574645402	0	
i 1	121.51282993197279	1.01	63	1087	3	13	1	1	0	2	1	0	0	3.5289577164302686	0	
i 1	121.5147074829932	0.2525	74	701	6	5	7	2	0	-1	2	0	0	3.0	0	
i 1	121.74655782312925	0.2525	74	701	4	24	4	8	0	-2	8	0	0	3.0	0	
i 1	121.7597006802721	0.2525	74	203	7	5	13	8	0	-2	8	0	0	3.0	0	
i 1	122.24155102040817	0.2525	73	203	1	20	10	8	0	-1	8	0	0	4.0	0	
i 1	122.4971836734694	3.0300000000000002	63	1087	5	13	3	1	0	2	1	0	0	3.5289577164302686	0	
i 1	122.50469387755102	0.2525	71	1087	6	5	1	8	0	-1	8	0	0	3.0	0	
i 1	122.74280272108844	0.2525	74	701	4	24	9	8	0	-2	8	0	0	3.0	0	
i 1	123.48967346938775	0.2525	71	701	6	5	11	2	0	-2	2	0	0	3.0	1	
i 1	123.51157823129252	5.555	63	203	6	14	5	16	0	1	16	0	0	5.293436574645402	1	
i 1	123.73904761904762	1.7675	71	1087	4	24	4	2	0	-1	2	0	0	3.0	1	
i 1	124.26345578231293	0.505	74	701	6	5	5	8	0	-1	8	0	0	3.0	1	
i 1	124.4852925170068	3.0300000000000002	63	1087	6	7	14	16	0	2	16	0	0	4.7052769552403575	2	
i 1	124.49593197278912	1.01	71	1087	6	5	13	8	0	-1	8	0	0	3.0	2	
i 1	124.76282993197279	0.505	72	701	5	9	10	0	0	-1	0	0	0	3.0	2	
i 1	125.0097006802721	0.2525	71	701	6	5	5	2	0	-1	2	0	0	3.0	3	
i 1	125.48654421768707	3.535	63	1087	5	13	2	1	0	2	1	0	0	3.5289577164302686	3	
i 1	125.48967346938775	1.5150000000000001	72	203	7	2	15	1	0	-1	1	0	0	4.0	3	
i 1	125.75031292517006	0.505	74	203	7	5	5	8	0	-2	8	0	0	3.0	3	
i 1	125.75594557823129	0.2525	72	1087	4	4	15	0	0	-1	0	0	0	4.0	3	
i 1	126.0028163265306	0.2525	69	701	5	9	11	1	0	-1	1	0	0	3.0	3	
i 1	126.48466666666667	0.2525	74	701	6	5	4	2	0	-1	2	0	0	3.0	3	
i 1	126.99342857142857	1.5150000000000001	71	203	7	5	10	8	0	-1	8	0	0	3.0	3	
i 1	127.00469387755102	0.2525	74	701	6	5	9	2	0	-1	2	0	0	3.0	3	
i 1	127.2471836734694	0.505	71	701	6	5	16	2	0	-2	2	0	0	3.0	3	
i 1	127.26408163265306	0.2525	72	701	3	4	16	0	0	0	0	0	0	4.0	3	
i 1	127.49593197278912	1.5150000000000001	63	1087	5	7	7	16	0	2	16	0	0	4.7052769552403575	3	
i 1	127.99468027210884	0.2525	69	701	5	3	5	0	0	-1	0	0	0	4.0	3	
i 1	127.99530612244898	0.2525	71	1087	6	5	1	8	0	-1	8	0	0	3.0	3	
i 1	127.99655782312925	0.505	71	1087	4	24	10	2	0	-1	2	0	0	3.0	3	
i 1	128.25970068027212	0.505	72	1087	4	4	13	0	0	-1	0	0	0	4.0	3	
i 1	128.50719727891158	0.2525	74	701	4	24	15	8	0	-2	8	0	0	3.0	3	
i 1	128.73904761904762	0.2525	74	701	6	5	10	2	0	-1	2	0	0	3.0	3	
i 1	128.99655782312925	1.5150000000000001	71	379	6	5	6	8	0	-1	8	0	0	3.0	4	
i 1	128.99780952380954	0.505	73	1081	2	24	15	8	0	-2	8	0	0	4.0	4	
i 1	129.00469387755103	1.5150000000000001	72	695	6	2	16	1	0	0	1	0	0	4.0	4	
i 1	129.0059455782313	4.04	63	379	5	13	7	1	0	2	1	0	0	3.5289577164302686	4	
i 1	129.00844897959183	2.525	61	695	5	14	11	16	0	1	16	0	0	5.293436574645402	4	
i 1	129.01220408163266	5.555	73	379	1	24	5	2	0	252	2	307	0	4.0	4	
i 1	129.01533333333333	0.505	61	695	5	14	2	1	0	1	1	0	0	5.293436574645402	4	
i 1	129.51032653061225	5.05	61	695	5	14	11	1	0	1	1	0	0	5.293436574645402	4	
i 1	129.74280272108842	0.2525	73	379	1	24	16	2	0	-2	2	0	0	4.0	4	
i 1	130.01408163265307	0.505	74	1081	6	5	7	2	0	-1	2	0	0	3.0	4	
i 1	130.49029931972788	0.505	69	379	4	4	15	0	0	0	0	0	0	4.0	4	
i 1	130.49718367346938	0.2525	74	379	6	5	15	2	0	-2	2	0	0	3.0	4	
i 1	130.74342857142858	0.2525	71	695	6	5	2	8	0	-2	8	0	0	3.0	4	
i 1	130.99468027210884	0.2525	72	379	4	4	1	0	0	-1	0	0	0	4.0	5	
i 1	131.48779591836734	0.2525	71	695	6	5	8	8	0	-2	8	0	0	3.0	5	
i 1	131.49655782312925	3.0300000000000002	61	695	5	14	8	16	0	1	16	0	0	5.293436574645402	5	
i 1	131.50657142857142	0.2525	73	379	1	24	7	2	0	-2	2	0	0	4.0	5	
i 1	131.51095238095238	0.2525	69	379	4	4	6	0	0	0	0	0	0	4.0	5	
i 1	131.75344217687075	1.2625	72	695	5	2	14	0	0	-1	0	0	0	4.0	5	
i 1	132.00469387755103	1.01	71	695	6	5	4	8	0	-2	8	0	0	3.0	5	
i 1	132.2490612244898	0.505	72	695	5	2	15	1	0	0	1	0	0	4.0	5	
i 1	132.7615782312925	0.2525	71	379	4	24	13	8	0	-2	8	0	0	3.0	5	
i 1	132.99593197278912	0.2525	72	695	5	2	14	1	0	0	1	0	0	4.0	6	
i 1	132.99593197278912	1.5150000000000001	71	695	6	5	5	8	0	-2	8	0	0	3.0	6	
i 1	132.99843537414966	0.505	63	695	5	13	5	16	0	1	16	0	0	3.5289577164302686	6	
i 1	133.00406802721088	2.525	61	695	6	7	11	16	0	1	16	0	0	4.7052769552403575	6	
i 1	133.50219047619046	1.01	72	695	5	3	11	0	0	0	0	0	0	4.0	6	
i 1	133.51345578231292	7.07	63	695	5	13	3	16	0	1	16	0	0	3.5289577164302686	6	
i 1	133.75970068027212	0.505	69	379	5	3	1	1	0	-1	1	0	0	4.0	6	
i 1	134.4990612244898	0.2525	74	197	3	24	3	8	0	-2	8	0	0	3.0	8	
i 1	134.5009387755102	9.09	63	899	5	14	6	1	0	1	1	0	0	5.293436574645402	8	
i 1	134.50219047619046	9.09	61	899	5	14	15	16	0	1	16	0	0	5.293436574645402	8	
i 1	134.50657142857142	1.5150000000000001	71	899	6	5	10	8	0	-1	8	0	0	3.0	8	
i 1	134.50907482993196	3.0300000000000002	70	197	1	24	8	8	0	252	8	307	0	4.0	8	
i 1	135.00156462585034	0.505	69	197	6	3	15	1	0	0	1	0	0	4.0	8	
i 1	135.50406802721088	0.2525	69	197	6	9	13	1	0	-1	1	0	0	3.0	8	
i 1	135.75469387755103	0.2525	69	197	6	3	3	1	0	0	1	0	0	4.0	8	
i 1	135.75970068027212	0.2525	73	197	1	24	13	8	0	-2	8	0	0	4.0	8	
i 1	135.7628299319728	1.7675	74	695	6	5	3	8	0	-2	8	0	0	3.0	8	
i 1	136.0078231292517	0.7575000000000001	69	695	4	4	8	1	0	-1	1	0	0	4.0	8	
i 1	136.24593197278912	0.2525	72	899	5	2	9	0	0	0	0	0	0	4.0	8	
i 1	136.75970068027212	0.2525	69	197	6	9	1	1	0	-1	1	0	0	3.0	8	
i 1	137.01095238095238	0.505	71	899	6	5	8	8	0	-1	8	0	0	3.0	8	
i 1	137.5078231292517	0.2525	74	197	7	5	4	8	0	-1	8	0	0	3.0	8	
i 1	137.75469387755103	1.7675	69	899	5	2	6	1	0	0	1	0	0	4.0	8	
i 1	138.25344217687075	0.2525	73	197	1	24	16	8	0	-2	8	0	0	9.0	8	
i 1	138.50531972789116	0.505	72	197	5	9	10	1	0	0	1	0	0	3.0	9	
i 1	138.51408163265307	0.2525	74	695	6	5	2	8	0	-2	8	0	0	3.0	9	
i 1	138.7440544217687	0.505	73	899	1	20	15	8	0	-1	8	0	0	5.0	9	
i 1	138.74593197278912	0.7575000000000001	70	197	1	20	2	8	0	-2	8	0	0	5.0	9	
i 1	138.75406802721088	0.505	74	197	6	5	11	8	0	-1	8	0	0	3.0	9	
i 1	138.9884217687075	0.2525	74	197	7	5	10	8	0	-1	8	0	0	3.0	9	
i 1	139.24968707482992	0.2525	70	197	1	20	3	2	0	-2	2	0	0	5.0	9	
i 1	139.49155102040817	0.2525	73	197	1	24	3	8	0	-2	8	0	0	9.0	9	
i 1	140.00719727891158	0.505	71	899	4	5	3	8	0	-1	8	0	0	3.0	9	
i 1	140.23654421768708	0.2525	73	899	1	20	13	8	0	-1	8	0	0	5.0	9	
i 1	140.25031292517008	0.2525	70	197	1	20	14	8	0	-2	8	0	0	5.0	9	
i 1	140.4852925170068	3.0300000000000002	63	583	6	7	4	1	0	1	1	0	0	4.7052769552403575	10	
i 1	140.4884217687075	0.2525	69	583	4	4	2	1	0	0	1	0	0	4.0	10	
i 1	140.48967346938775	1.5150000000000001	71	583	4	5	3	2	0	-1	2	0	0	3.0	10	
i 1	140.49468027210884	3.0300000000000002	61	583	5	13	4	16	0	2	16	0	0	3.5289577164302686	10	
i 1	140.76345578231292	0.505	71	197	7	5	14	2	0	-1	2	0	0	3.0	10	
i 1	141.01408163265307	3.0300000000000002	73	197	1	24	15	8	0	-2	8	0	0	9.0	10	
i 1	141.01533333333333	0.505	69	583	5	3	15	1	0	0	1	0	0	4.0	10	
i 1	141.48591836734693	0.7575000000000001	69	899	6	2	3	1	0	0	1	0	0	4.0	10	
i 1	141.48591836734693	0.2525	71	197	7	5	16	2	0	-1	2	0	0	3.0	10	
i 1	141.74718367346938	0.2525	72	197	5	9	5	1	0	0	1	0	0	3.0	10	
i 1	141.74718367346938	1.7675	74	899	6	5	4	8	0	-1	8	0	0	3.0	10	
i 1	141.9852925170068	0.7575000000000001	72	899	5	2	3	0	0	0	0	0	0	4.0	10	
i 1	142.00657142857142	0.2525	74	197	5	24	15	8	0	-2	8	0	0	3.0	10	
i 1	142.01345578231292	0.505	70	583	1	24	9	8	0	-1	8	0	0	9.0	10	
i 1	142.24530612244897	1.2625	69	583	4	4	12	1	0	0	1	0	0	4.0	10	
i 1	142.26345578231292	0.2525	71	197	7	5	3	2	0	-1	2	0	0	3.0	10	
i 1	142.4871700680272	0.7575000000000001	70	197	1	20	3	8	0	-2	8	0	0	5.0	11	
i 1	142.51032653061225	0.505	74	197	5	24	9	8	0	-2	8	0	0	3.0	11	
i 1	142.99029931972788	0.505	69	899	6	2	3	1	0	0	1	0	0	4.0	11	
i 1	143.25719727891158	0.2525	73	583	1	20	13	8	0	-2	8	0	0	5.0	11	
i 1	143.25907482993196	0.2525	70	899	1	20	10	2	0	-2	2	0	0	5.0	11	
i 1	143.26408163265307	0.2525	74	197	5	24	12	8	0	-2	8	0	0	3.0	11	
i 1	143.4852925170068	0.505	73	197	1	20	2	2	0	-2	2	0	0	5.0	12	
i 1	143.48591836734693	1.2625	71	695	4	5	12	2	0	-2	2	0	0	3.0	12	
i 1	143.48779591836734	4.545	63	695	5	13	3	1	0	2	1	0	0	3.5289577164302686	12	
i 1	143.4940544217687	8.08	61	1081	5	14	2	16	0	1	16	0	0	5.293436574645402	12	
i 1	143.50719727891158	8.08	63	1081	5	14	6	1	0	2	1	0	0	5.293436574645402	12	
i 1	143.50970068027212	0.505	74	1081	6	5	7	8	0	-2	8	0	0	3.0	12	
i 1	144.00844897959183	0.505	69	695	4	4	14	1	0	-1	1	0	0	4.0	13	
i 1	144.26345578231292	0.2525	71	197	4	5	2	2	0	-1	2	0	0	3.0	13	
i 1	144.48654421768708	0.505	74	695	4	24	4	8	0	-1	8	0	0	3.0	13	
i 1	144.49843537414966	1.7675	74	1081	6	5	7	8	0	-1	8	0	0	3.0	13	
i 1	144.50970068027212	0.2525	69	695	4	3	5	0	0	0	0	0	0	4.0	13	
i 1	144.5147074829932	0.2525	69	197	5	9	8	1	0	-1	1	0	0	3.0	13	
i 1	144.73654421768708	0.2525	73	197	1	20	13	2	0	-2	2	0	0	5.0	13	
i 1	144.74593197278912	0.2525	69	695	4	4	15	1	0	-1	1	0	0	4.0	13	
i 1	145.01220408163266	0.505	69	1081	6	2	10	0	0	-1	0	0	0	4.0	13	
i 1	145.01408163265307	0.2525	74	695	6	5	16	2	0	-1	2	0	0	3.0	13	
i 1	145.26220408163266	0.505	74	695	6	5	2	2	0	-2	2	0	0	3.0	13	
i 1	145.4940544217687	0.505	70	197	1	20	7	8	0	-2	8	0	0	5.0	13	
i 1	145.49655782312925	0.2525	72	695	5	3	13	1	0	0	1	0	0	4.0	13	
i 1	145.50970068027212	0.2525	73	1081	1	20	13	2	0	-2	2	0	0	5.0	13	
i 1	145.7371700680272	0.2525	70	197	1	20	15	2	0	-1	2	0	0	5.0	13	
i 1	145.76095238095238	1.7675	69	1081	4	2	4	0	0	0	0	0	0	4.0	13	
i 1	145.99593197278912	0.2525	69	695	4	4	6	1	0	-1	1	0	0	4.0	13	
i 1	146.0147074829932	2.2725	74	1081	6	5	4	8	0	-2	8	0	0	3.0	13	
i 1	146.24780952380954	0.2525	70	695	1	24	4	8	0	-1	8	0	0	9.0	13	
i 1	146.2490612244898	0.2525	73	197	1	24	4	8	0	-2	8	0	0	9.0	13	
i 1	146.2509387755102	0.505	71	695	4	5	4	2	0	-2	2	0	0	3.0	13	
i 1	146.25719727891158	0.2525	74	695	6	5	5	2	0	-2	2	0	0	3.0	13	
i 1	146.25907482993196	0.2525	69	1081	4	2	9	0	0	-1	0	0	0	4.0	13	
i 1	146.74468027210884	0.2525	71	695	6	5	5	8	0	-1	8	0	0	3.0	13	
i 1	146.99655782312925	0.2525	71	197	4	5	3	2	0	-1	2	0	0	3.0	13	
i 1	147.4921768707483	0.505	72	695	4	3	8	1	0	0	1	0	0	4.0	13	
i 1	147.74593197278912	0.7575000000000001	69	1081	4	2	7	0	0	0	0	0	0	4.0	13	
i 1	147.75219047619046	1.7675	74	1081	6	5	6	8	0	-1	8	0	0	3.0	13	
i 1	147.98967346938775	0.2525	74	583	4	24	11	2	0	-2	2	0	0	3.0	14	
i 1	147.99155102040817	2.02	63	583	5	13	16	1	0	1	1	0	0	3.5289577164302686	14	
i 1	148.0009387755102	0.7575000000000001	69	695	4	3	14	0	0	0	0	0	0	4.0	14	
i 1	148.00907482993196	0.2525	73	197	1	24	9	8	0	-2	8	0	0	9.0	14	
i 1	148.00970068027212	0.2525	69	197	5	9	11	1	0	-1	1	0	0	3.0	14	
i 1	148.23779591836734	0.2525	74	695	4	24	15	8	0	-1	8	0	0	3.0	14	
i 1	148.25406802721088	1.2625	69	583	4	4	5	0	0	-1	0	0	0	4.0	14	
i 1	148.50281632653062	1.5150000000000001	74	1081	6	5	16	8	0	-2	8	0	0	3.0	14	
i 1	148.99718367346938	0.2525	72	197	5	9	9	1	0	0	1	0	0	3.0	14	
i 1	149.2559455782313	0.2525	69	1081	4	2	6	0	0	-1	0	0	0	4.0	14	
i 1	149.49780952380954	0.2525	74	583	4	24	13	2	0	-2	2	0	0	3.0	14	
i 1	149.50970068027212	0.2525	74	695	4	24	15	8	0	-1	8	0	0	3.0	14	
i 1	149.74718367346938	1.5150000000000001	69	1081	4	2	6	0	0	-1	0	0	0	4.0	14	
i 1	149.98904761904762	0.2525	70	197	1	20	12	8	0	-2	8	0	0	5.0	15	
i 1	149.98967346938775	1.5150000000000001	63	379	5	13	6	16	0	1	16	0	0	3.5289577164302686	15	
i 1	149.99593197278912	0.505	69	379	4	3	12	0	0	-1	0	0	0	4.0	15	
i 1	150.00531972789116	1.5150000000000001	71	379	6	5	2	8	0	-1	8	0	0	3.0	15	
i 1	150.26345578231292	0.2525	71	379	4	24	7	8	0	-2	8	0	0	3.0	15	
i 1	150.50469387755103	0.2525	74	197	4	5	11	8	0	-1	8	0	0	3.0	15	
i 1	150.50531972789116	1.01	73	197	1	20	13	2	0	-1	2	0	0	5.0	15	
i 1	151.00031292517008	0.505	71	379	4	24	11	8	0	-2	8	0	0	3.0	15	
i 1	151.00031292517008	0.505	69	1081	4	2	7	0	0	0	0	0	0	4.0	15	
i 1	151.25156462585034	0.2525	74	1081	6	5	3	8	0	-1	8	0	0	3.0	15	
i 1	151.4852925170068	0.2525	74	379	6	5	5	8	0	-1	8	0	0	3.0065128918243444	15	
i 1	151.48591836734693	0.2525	74	197	6	1	9	2	0	-2	2	0	0	0.488354119971917	15	
i 1	151.4871700680272	0.505	63	379	6	7	7	16	0	2	16	0	0	6.345554294259793	15	
i 1	151.48779591836734	0.505	61	1081	5	14	15	16	0	1	16	0	0	6.933713913664838	15	
i 1	151.49155102040817	0.505	63	1081	6	17	12	16	0	1	16	0	0	5.290431105685503	15	
i 1	151.49280272108842	0.505	70	1081	1	20	12	2	0	-1	2	0	0	5.0	15	
i 1	151.49655782312925	0.2525	69	379	4	3	12	0	0	-1	0	0	0	4.0	15	
i 1	151.49843537414966	0.505	63	379	5	13	15	16	0	1	16	0	0	5.169235055449704	15	
i 1	151.4990612244898	0.505	63	695	1	27	5	1	0	252	1	307	0	1.154898545639104	15	
i 1	151.49968707482992	0.505	63	1081	6	17	1	16	0	2	16	0	0	5.290431105685503	15	
i 1	151.50156462585034	0.505	63	379	6	17	10	16	0	2	16	0	0	5.290431105685503	15	
i 1	151.50156462585034	2.02	61	197	5	18	13	1	0	2	1	0	0	5.290431105685503	15	
i 1	151.50219047619046	2.02	63	197	5	18	3	16	0	1	16	0	0	5.290431105685503	15	
i 1	151.50657142857142	0.505	63	379	6	17	3	1	0	2	1	0	0	5.290431105685503	15	
i 1	151.50907482993196	0.505	61	695	4	19	5	16	0	1	16	0	0	5.290431105685503	15	
i 1	151.50907482993196	0.505	61	695	1	27	16	1	0	252	1	307	0	1.154898545639104	15	
i 1	151.5115782312925	0.505	63	695	4	19	1	1	0	2	1	0	0	5.290431105685503	15	
i 1	151.51220408163266	0.505	63	1081	5	14	12	1	0	2	1	0	0	6.933713913664838	15	
i 1	151.98591836734693	7.575	61	583	6	17	14	1	0	1	1	0	0	5.290431105685503	16	
i 1	151.9871700680272	1.5150000000000001	63	197	5	19	12	16	0	2	16	0	0	5.290431105685503	16	
i 1	151.9884217687075	0.2525	72	583	4	4	1	0	0	0	0	0	0	4.0	16	
i 1	151.99155102040817	0.2525	69	899	4	2	8	1	0	0	1	0	0	4.0	16	
i 1	151.9921768707483	7.575	63	583	6	17	8	1	0	1	1	0	0	5.290431105685503	16	
i 1	151.9921768707483	0.2525	73	197	1	20	7	2	0	-2	2	0	0	5.0	16	
i 1	151.99655782312925	3.535	61	899	6	17	11	16	0	2	16	0	0	5.290431105685503	16	
i 1	152.0009387755102	5.555	61	583	5	13	12	1	0	2	1	0	0	5.169235055449704	16	
i 1	152.00406802721088	1.5150000000000001	74	583	4	24	11	2	0	-2	2	0	0	3.488354119971917	16	
i 1	152.00657142857142	1.5150000000000001	63	197	5	19	1	1	0	1	1	0	0	5.290431105685503	16	
i 1	152.00719727891158	1.5150000000000001	70	197	1	24	5	8	0	252	8	307	0	9.0	16	
i 1	152.01095238095238	5.555	61	899	6	17	6	16	0	1	16	0	0	5.290431105685503	16	
i 1	152.01095238095238	3.535	63	899	5	14	5	16	0	2	16	0	0	6.933713913664838	16	
i 1	152.0115782312925	1.5150000000000001	61	197	1	27	6	1	0	252	1	307	0	1.154898545639104	16	
i 1	152.0128299319728	1.5150000000000001	63	899	5	14	1	1	0	1	1	0	0	6.933713913664838	16	
i 1	152.49280272108842	0.2525	73	197	1	20	1	8	0	-1	8	0	0	5.0	16	
i 1	152.49780952380954	0.2525	74	583	6	5	14	2	0	-1	2	0	0	3.0065128918243444	16	
i 1	152.50031292517008	0.505	74	583	6	5	12	8	0	-2	8	0	0	3.0065128918243444	16	
i 1	152.73779591836734	0.2525	71	197	6	1	2	2	0	-1	2	0	0	0.488354119971917	16	
i 1	152.74780952380954	0.2525	74	583	4	1	14	2	0	-1	2	0	0	0.488354119971917	16	
i 1	152.75970068027212	0.505	70	197	1	20	9	8	0	-2	8	0	0	5.0	16	
i 1	152.76408163265307	0.2525	69	583	4	3	7	0	0	0	0	0	0	4.0	16	
i 1	152.98466666666667	0.2525	74	197	6	1	16	2	0	-2	2	0	0	0.488354119971917	17	
i 1	152.99655782312925	0.2525	72	197	4	4	6	0	0	-1	0	0	0	4.0	17	
i 1	152.99843537414966	0.2525	74	197	5	24	3	2	0	-1	2	0	0	3.488354119971917	17	
i 1	153.00031292517008	0.2525	71	197	3	5	9	2	0	-2	2	0	0	3.0065128918243444	17	
i 1	153.00281632653062	0.2525	72	197	4	9	12	1	0	0	1	0	0	3.0	17	
i 1	153.49029931972788	6.0600000000000005	61	1165	4	18	13	16	0	1	16	0	0	5.290431105685503	18	
i 1	153.4921768707483	6.0600000000000005	61	1165	4	18	14	1	0	1	1	0	0	5.290431105685503	18	
i 1	153.49530612244897	1.01	70	1165	1	20	12	2	0	-2	2	0	0	5.0	18	
i 1	153.49718367346938	0.2525	72	1165	4	9	5	1	0	-1	1	0	0	3.0	18	
i 1	153.49780952380954	6.0600000000000005	63	899	4	14	13	1	0	1	1	0	0	6.933713913664838	18	
i 1	153.49843537414966	6.0600000000000005	61	196	5	19	2	16	0	1	16	0	0	5.290431105685503	18	
i 1	153.50031292517008	6.0600000000000005	63	196	4	27	9	16	0	1	16	0	0	1.154898545639104	18	
i 1	153.50657142857142	0.7575000000000001	70	1165	1	20	15	8	0	-1	8	0	0	5.0	18	
i 1	153.50907482993196	6.0600000000000005	61	196	5	19	9	1	0	1	1	0	0	5.290431105685503	18	
i 1	153.7421768707483	0.7575000000000001	69	1165	4	9	11	0	0	0	0	0	0	3.0	18	
i 1	153.75344217687075	0.505	74	1165	6	5	3	8	0	-2	8	0	0	3.0065128918243444	18	
i 1	153.9871700680272	1.5150000000000001	71	899	4	1	14	2	0	-1	2	0	0	0.488354119971917	18	
i 1	154.23779591836734	1.7675	71	899	6	5	15	2	0	-2	2	0	0	3.0065128918243444	18	
i 1	154.24593197278912	1.2625	70	1165	1	24	2	8	0	-1	8	0	0	9.0	18	
i 1	154.25844897959183	0.2525	72	1165	4	9	8	1	0	-1	1	0	0	3.0	18	
i 1	154.26345578231292	0.2525	70	583	1	24	8	8	0	-1	8	0	0	9.0	18	
i 1	154.48654421768708	0.2525	74	1165	6	5	8	8	0	-2	8	0	0	3.0065128918243444	18	
i 1	154.51095238095238	0.2525	69	899	6	2	3	1	0	0	1	0	0	4.0	18	
i 1	154.7509387755102	0.2525	71	196	5	5	6	2	0	-2	2	0	0	3.0065128918243444	18	
i 1	154.76408163265307	0.2525	72	1165	4	9	16	1	0	-1	1	0	0	3.0	18	
i 1	154.98591836734693	0.2525	71	899	4	1	10	8	0	-1	8	0	0	0.488354119971917	18	
i 1	154.98904761904762	0.505	69	583	4	3	10	0	0	0	0	0	0	4.0	18	
i 1	155.00344217687075	0.2525	71	196	5	24	11	8	0	-2	8	0	0	3.488354119971917	18	
i 1	155.01220408163266	0.505	74	583	6	5	8	8	0	-2	8	0	0	3.0065128918243444	18	
i 1	155.2615782312925	0.2525	74	1165	6	1	11	2	0	-2	2	0	0	0.488354119971917	18	
i 1	155.48591836734693	1.5150000000000001	69	583	5	3	11	0	0	0	0	0	0	4.0	18	
i 1	155.48591836734693	0.2525	73	899	1	20	5	8	0	-2	8	0	0	5.0	18	
i 1	155.49155102040817	4.04	61	899	5	17	16	16	0	2	16	0	0	5.290431105685503	18	
i 1	155.49780952380954	4.04	63	196	4	27	10	16	0	1	16	0	0	1.154898545639104	18	
i 1	155.50281632653062	4.04	63	899	4	14	6	16	0	2	16	0	0	6.933713913664838	18	
i 1	155.50844897959183	0.2525	72	899	6	2	2	0	0	-1	0	0	0	4.0	18	
i 1	155.51220408163266	0.2525	72	196	3	3	7	0	0	0	0	0	0	4.0	18	
i 1	155.73591836734693	0.7575000000000001	70	1165	1	24	1	8	0	-1	8	0	0	9.0	18	
i 1	155.99718367346938	0.2525	74	583	6	5	15	2	0	-1	2	0	0	3.0065128918243444	18	
i 1	156.01032653061225	2.2725	72	899	6	2	14	0	0	-1	0	0	0	4.0	18	
i 1	156.0128299319728	1.5150000000000001	71	899	4	1	16	8	0	-1	8	0	0	0.488354119971917	18	
i 1	156.24468027210884	0.2525	72	1165	4	9	7	1	0	-1	1	0	0	3.0	18	
i 1	156.50156462585034	0.2525	74	1165	6	5	8	8	0	-2	8	0	0	3.0065128918243444	18	
i 1	156.5147074829932	0.2525	74	583	6	5	3	2	0	-1	2	0	0	3.0065128918243444	18	
i 1	156.76095238095238	0.505	74	196	5	1	6	2	0	-1	2	0	0	0.488354119971917	18	
i 1	157.00219047619046	1.7675	70	1165	1	24	6	8	0	-1	8	0	0	9.0	18	
i 1	157.23466666666667	0.2525	72	1165	4	9	14	1	0	-1	1	0	0	3.0	18	
i 1	157.23654421768708	0.2525	74	1165	6	1	14	2	0	-2	2	0	0	0.488354119971917	18	
i 1	157.2615782312925	0.505	71	196	5	24	8	8	0	-2	8	0	0	3.488354119971917	18	
i 1	157.48466666666667	2.02	69	899	6	2	2	1	0	0	1	0	0	4.0	19	
i 1	157.4921768707483	0.505	71	899	6	1	15	8	0	-1	8	0	0	0.488354119971917	19	
i 1	157.49468027210884	1.2625	71	899	5	5	1	2	0	-2	2	0	0	3.0065128918243444	19	
i 1	157.50281632653062	2.02	61	583	4	13	15	1	0	2	1	0	0	5.169235055449704	19	
i 1	157.50970068027212	2.02	61	899	5	17	6	16	0	1	16	0	0	5.290431105685503	19	
i 1	157.5147074829932	0.2525	70	583	1	24	4	2	0	-1	2	0	0	9.0	19	
i 1	157.7384217687075	0.2525	72	1165	4	9	14	1	0	-1	1	0	0	3.0	19	
i 1	158.00281632653062	0.2525	69	1165	4	9	9	0	0	0	0	0	0	3.0	19	
i 1	158.0059455782313	0.2525	74	1165	4	1	3	2	0	-2	2	0	0	0.488354119971917	19	
i 1	158.2384217687075	0.2525	71	1165	6	5	10	2	0	-2	2	0	0	3.0065128918243444	19	
i 1	158.24530612244897	1.2625	74	583	6	5	10	8	0	-2	8	0	0	3.0065128918243444	19	
i 1	158.50406802721088	0.505	73	583	1	24	13	2	0	-2	2	0	0	9.0	19	
i 1	158.50469387755103	0.505	72	583	4	4	6	0	0	0	0	0	0	4.0	19	
i 1	158.73466666666667	0.2525	74	196	5	5	7	8	0	-2	8	0	0	3.0065128918243444	19	
i 1	158.75281632653062	0.7575000000000001	71	899	6	1	14	8	0	-1	8	0	0	0.488354119971917	19	
i 1	158.75469387755103	0.2525	69	1165	4	9	8	0	0	0	0	0	0	3.0	19	
i 1	158.76533333333333	0.2525	70	899	4	20	13	8	0	-1	8	0	0	5.0	19	
i 1	158.9940544217687	0.505	74	899	5	5	5	8	0	-1	8	0	0	3.0065128918243444	19	
i 1	158.9990612244898	0.505	72	899	6	2	5	0	0	-1	0	0	0	4.0	19	
i 1	159.00281632653062	0.505	70	1165	4	20	16	8	0	-1	8	0	0	5.0	19	
i 1	159.48779591836734	2.02	61	197	6	17	8	1	0	1	1	0	0	5.290431105685503	20	
i 1	159.49029931972788	4.04	63	1081	4	18	8	1	0	1	1	0	0	5.290431105685503	20	
i 1	159.4940544217687	12.120000000000001	63	197	5	17	7	16	0	1	16	0	0	5.290431105685503	20	
i 1	159.49530612244897	8.08	61	695	4	14	12	16	0	1	16	0	0	6.933713913664838	20	
i 1	159.49718367346938	8.08	61	695	5	17	1	1	0	2	1	0	0	5.290431105685503	20	
i 1	159.49780952380954	2.02	63	695	3	27	15	16	0	2	16	0	0	1.154898545639104	20	
i 1	159.50031292517008	10.1	61	695	4	19	7	1	0	1	1	0	0	5.290431105685503	20	
i 1	159.50469387755103	6.0600000000000005	63	695	3	27	7	1	0	2	1	0	0	1.154898545639104	20	
i 1	159.5059455782313	0.2525	70	1081	3	20	8	2	0	-1	2	0	0	5.0	20	
i 1	159.50970068027212	0.2525	74	197	6	5	5	8	0	-1	8	0	0	3.0065128918243444	20	
i 1	159.51220408163266	10.1	63	695	5	17	9	16	0	2	16	0	0	5.290431105685503	20	
i 1	159.51408163265307	8.08	61	695	4	19	9	16	0	1	16	0	0	5.290431105685503	20	
i 1	159.51408163265307	12.120000000000001	61	197	4	13	16	1	0	1	1	0	0	5.169235055449704	20	
i 1	159.5147074829932	1.7675	74	695	5	5	12	2	0	-1	2	0	0	3.0065128918243444	20	
i 1	159.5147074829932	10.1	63	695	4	14	7	16	0	1	16	0	0	6.933713913664838	20	
i 1	159.51533333333333	6.0600000000000005	61	1081	4	18	6	16	0	2	16	0	0	5.290431105685503	20	
i 1	159.74092517006804	0.505	71	1081	5	5	7	2	0	-1	2	0	0	3.0065128918243444	20	
i 1	159.76095238095238	0.505	72	695	6	2	15	0	0	-1	0	0	0	4.0	20	
i 1	160.00907482993196	0.2525	70	695	4	20	8	8	0	-2	8	0	0	5.0	20	
i 1	160.2647074829932	0.505	71	695	5	5	8	2	0	-1	2	0	0	3.0065128918243444	20	
i 1	160.51220408163266	0.2525	71	1081	3	1	1	2	0	-2	2	0	0	0.488354119971917	20	
i 1	160.74530612244897	1.5150000000000001	71	197	5	5	15	2	0	-2	2	0	0	3.0065128918243444	20	
i 1	160.75406802721088	0.505	71	695	4	24	8	2	0	-1	2	0	0	3.488354119971917	20	
i 1	160.75844897959183	0.2525	69	1081	3	9	7	1	0	-1	1	0	0	3.0	20	
i 1	160.98654421768708	0.2525	73	1081	3	20	7	8	0	-1	8	0	0	5.0	20	
i 1	160.99655782312925	0.2525	71	695	4	5	7	8	0	-2	8	0	0	3.0065128918243444	20	
i 1	161.24342857142858	0.2525	70	695	4	20	10	2	0	-1	2	0	0	5.0	20	
i 1	161.24655782312925	0.2525	71	695	4	1	5	8	0	-1	8	0	0	0.488354119971917	20	
i 1	161.24968707482992	0.2525	73	197	1	24	14	8	0	-2	8	0	0	9.0	20	
i 1	161.25344217687075	0.2525	71	197	7	1	8	2	0	-1	2	0	0	0.488354119971917	20	
i 1	161.48967346938775	6.0600000000000005	63	695	3	27	15	16	0	2	16	0	0	1.154898545639104	21	
i 1	161.49092517006804	11.11	61	197	5	17	4	1	0	1	1	0	0	5.290431105685503	21	
i 1	161.49155102040817	1.01	71	197	5	24	1	2	0	-2	2	0	0	3.488354119971917	21	
i 1	161.50031292517008	0.505	69	695	2	3	7	1	0	-1	1	0	0	4.0	21	
i 1	161.50031292517008	2.2725	74	197	5	5	3	8	0	-1	8	0	0	3.0065128918243444	21	
i 1	161.73654421768708	0.2525	71	695	2	1	2	8	0	-2	8	0	0	0.488354119971917	21	
i 1	161.9852925170068	0.2525	72	695	6	2	7	0	0	-1	0	0	0	4.0	21	
i 1	161.98779591836734	0.2525	73	197	4	24	14	2	0	-2	2	0	0	4.0	21	
i 1	162.48967346938775	3.0300000000000002	71	695	4	1	7	8	0	-1	8	0	0	0.488354119971917	22	
i 1	162.76408163265307	0.2525	71	197	5	5	8	2	0	-2	2	0	0	3.0065128918243444	22	
i 1	162.99843537414966	4.2925	71	695	5	5	10	2	0	-1	2	0	0	3.0065128918243444	23	
i 1	163.24968707482992	0.2525	71	695	2	24	11	2	0	-1	2	0	0	3.488354119971917	23	
i 1	163.4921768707483	0.505	71	197	4	1	13	2	0	-1	2	0	0	0.488354119971917	23	
i 1	163.49843537414966	0.2525	74	1081	5	5	5	8	0	-1	8	0	0	3.0065128918243444	23	
i 1	163.5078231292517	9.09	63	1081	4	18	1	1	0	1	1	0	0	5.290431105685503	23	
i 1	163.74530612244897	0.2525	71	1081	4	5	11	2	0	-1	2	0	0	3.0065128918243444	23	
i 1	163.74718367346938	0.505	71	695	2	24	10	2	0	-1	2	0	0	3.488354119971917	23	
i 1	163.98466666666667	0.505	71	1081	3	1	14	2	0	-2	2	0	0	0.488354119971917	23	
i 1	164.00970068027212	0.505	71	695	4	5	12	2	0	-2	2	0	0	3.0065128918243444	23	
i 1	164.4871700680272	0.505	71	695	2	24	5	2	0	-1	2	0	0	3.488354119971917	23	
i 1	164.49280272108842	1.2625	74	695	5	5	16	2	0	-1	2	0	0	3.0065128918243444	23	
i 1	164.50531972789116	0.2525	71	197	5	5	3	2	0	-2	2	0	0	3.0065128918243444	23	
i 1	164.7647074829932	1.01	73	1081	3	24	10	8	0	-2	8	0	0	4.0	23	
i 1	164.99780952380954	0.505	70	197	4	24	5	2	0	-2	2	0	0	4.0	23	
i 1	165.0128299319728	0.2525	71	197	5	24	5	2	0	-2	2	0	0	3.488354119971917	23	
i 1	165.49593197278912	2.02	63	695	3	27	8	1	0	2	1	0	0	1.154898545639104	23	
i 1	165.50531972789116	0.2525	73	695	2	24	4	2	0	-2	2	0	0	4.0	23	
i 1	165.50844897959183	7.07	61	1081	4	18	11	16	0	2	16	0	0	5.290431105685503	23	
i 1	165.73654421768708	0.2525	69	1081	5	9	12	0	0	0	0	0	0	3.0	23	
i 1	166.00970068027212	1.5150000000000001	71	197	4	1	13	2	0	-1	2	0	0	0.488354119971917	23	
i 1	166.24593197278912	0.505	71	695	2	1	13	8	0	-2	8	0	0	0.488354119971917	23	
i 1	166.2559455782313	1.2625	69	197	5	4	12	1	0	-1	1	0	0	4.0	23	
i 1	166.48904761904762	0.2525	71	695	4	5	9	8	0	-2	8	0	0	3.0065128918243444	23	
i 1	166.73967346938775	0.2525	71	1081	6	1	15	8	0	-1	8	0	0	0.488354119971917	23	
i 1	166.99593197278912	0.505	71	695	2	24	2	2	0	-1	2	0	0	3.488354119971917	24	
i 1	166.99780952380954	2.02	74	695	4	1	15	8	0	-1	8	0	0	0.488354119971917	24	
i 1	167.48779591836734	5.05	61	695	6	17	11	1	0	2	1	0	0	5.290431105685503	24	
i 1	167.48904761904762	5.05	61	695	3	19	7	16	0	1	16	0	0	5.290431105685503	24	
i 1	167.49029931972788	5.05	61	695	5	14	3	16	0	1	16	0	0	6.933713913664838	24	
i 1	167.49155102040817	2.02	63	695	3	27	6	16	0	2	16	0	0	1.154898545639104	24	
i 1	167.49530612244897	0.2525	71	1081	3	1	15	8	0	-1	8	0	0	0.488354119971917	24	
i 1	167.49780952380954	0.7575000000000001	69	695	4	4	14	1	0	-1	1	0	0	4.0	24	
i 1	167.5115782312925	0.2525	71	197	4	24	14	2	0	-2	2	0	0	3.488354119971917	24	
i 1	167.5147074829932	0.2525	71	197	5	5	5	2	0	-2	2	0	0	3.0065128918243444	24	
i 1	167.7615782312925	0.2525	71	197	4	1	1	2	0	-1	2	0	0	0.488354119971917	24	
i 1	167.99280272108842	0.2525	71	695	3	5	4	8	0	-2	8	0	0	3.0065128918243444	24	
i 1	168.00219047619046	0.505	69	695	4	3	2	1	0	-1	1	0	0	4.0	24	
i 1	168.01032653061225	0.2525	71	1081	4	5	4	2	0	-1	2	0	0	3.0065128918243444	24	
i 1	168.23654421768708	0.505	71	197	5	5	4	2	0	-2	2	0	0	3.0065128918243444	24	
i 1	168.26095238095238	0.2525	71	197	4	1	1	2	0	-1	2	0	0	0.488354119971917	24	
i 1	168.2647074829932	3.0300000000000002	69	695	6	2	4	0	0	-1	0	0	0	4.0	24	
i 1	168.50344217687075	1.01	71	1081	6	1	13	2	0	-2	2	0	0	0.488354119971917	24	
i 1	168.50531972789116	2.2725	71	197	4	24	3	2	0	-2	2	0	0	3.488354119971917	24	
i 1	168.5147074829932	0.2525	72	695	6	2	14	0	0	-1	0	0	0	4.0	24	
i 1	168.75531972789116	0.2525	74	1081	4	5	8	8	0	-1	8	0	0	3.0065128918243444	24	
i 1	168.75844897959183	0.2525	69	1081	5	9	5	0	0	0	0	0	0	3.0	24	
i 1	169.00219047619046	0.505	74	695	5	5	11	2	0	-1	2	0	0	3.0065128918243444	25	
i 1	169.01095238095238	0.2525	69	197	5	4	16	1	0	-1	1	0	0	4.0	25	
i 1	169.23466666666667	0.2525	74	197	5	5	4	8	0	-1	8	0	0	3.0065128918243444	25	
i 1	169.48904761904762	3.0300000000000002	63	695	6	17	14	16	0	2	16	0	0	5.290431105685503	25	
i 1	169.49342857142858	2.2725	73	695	2	24	15	8	0	-2	8	0	0	4.0	25	
i 1	169.4940544217687	2.02	74	695	6	5	13	2	0	-1	2	0	0	3.0065128918243444	25	
i 1	169.49968707482992	3.0300000000000002	63	695	5	14	9	16	0	1	16	0	0	6.933713913664838	25	
i 1	169.50281632653062	3.0300000000000002	61	695	3	19	9	1	0	1	1	0	0	5.290431105685503	25	
i 1	169.50657142857142	0.2525	71	1081	3	1	15	8	0	-1	8	0	0	0.488354119971917	25	
i 1	169.73654421768708	0.505	71	1081	4	5	1	2	0	-1	2	0	0	3.0065128918243444	25	
i 1	169.7421768707483	0.2525	70	197	4	24	5	2	0	-2	2	0	0	4.0	25	
i 1	169.75844897959183	0.7575000000000001	69	695	4	3	14	1	0	-1	1	0	0	4.0	25	
i 1	170.00406802721088	0.7575000000000001	70	695	2	24	5	2	0	-2	2	0	0	4.0	25	
i 1	170.2352925170068	0.2525	70	197	4	24	15	2	0	-1	2	0	0	4.0	25	
i 1	170.25281632653062	0.2525	71	695	4	24	16	2	0	-1	2	0	0	3.488354119971917	25	
i 1	170.26345578231292	0.2525	71	695	3	5	15	2	0	-2	2	0	0	3.0065128918243444	25	
i 1	170.4940544217687	0.2525	71	1081	3	1	16	2	0	-2	2	0	0	0.488354119971917	25	
i 1	170.50469387755103	0.2525	71	1081	4	5	7	2	0	-1	2	0	0	3.0065128918243444	25	
i 1	170.73654421768708	0.505	71	695	4	24	13	2	0	-1	2	0	0	3.488354119971917	25	
i 1	170.76345578231292	0.2525	69	1081	5	9	7	1	0	-1	1	0	0	3.0	25	
i 1	170.99593197278912	1.5150000000000001	71	197	4	24	10	2	0	-2	2	0	0	3.488354119971917	26	
i 1	170.99593197278912	0.2525	71	695	5	5	2	2	0	-1	2	0	0	3.0065128918243444	26	
i 1	171.2628299319728	1.2625	73	1081	3	24	7	8	0	-2	8	0	0	4.0	26	
i 1	171.4852925170068	1.01	63	197	7	17	14	16	0	1	16	0	0	5.290431105685503	26	
i 1	171.48779591836734	0.2525	74	1081	4	5	3	8	0	-1	8	0	0	3.0065128918243444	26	
i 1	171.5128299319728	1.01	61	197	6	13	11	1	0	1	1	0	0	5.169235055449704	26	
i 1	171.74530612244897	0.2525	69	695	6	2	6	0	0	-1	0	0	0	4.0	26	
i 1	171.74718367346938	0.2525	74	695	6	5	14	2	0	-1	2	0	0	3.0065128918243444	26	
i 1	171.74780952380954	0.2525	71	695	4	1	11	8	0	-1	8	0	0	0.488354119971917	26	
i 1	171.74843537414966	0.2525	70	695	2	24	13	2	0	-2	2	0	0	4.0	26	
i 1	171.76095238095238	0.2525	71	695	6	5	16	2	0	-1	2	0	0	3.0065128918243444	26	
i 1	172.00970068027212	0.2525	73	695	2	24	7	8	0	-2	8	0	0	4.0	27	
i 1	172.25281632653062	0.2525	69	695	6	2	9	0	0	-1	0	0	0	4.0	27	
i 1	172.48466666666667	7.07	61	199	4	19	14	1	0	1	1	0	0	5.290431105685503	28	
i 1	172.4852925170068	8.08	63	585	6	17	14	16	0	1	16	0	0	5.290431105685503	28	
i 1	172.4884217687075	5.05	63	199	5	18	9	1	5000	2	1	0	0	5.290431105685503	28	
i 1	172.4940544217687	3.0300000000000002	63	199	1	27	8	16	0	252	16	307	0	1.154898545639104	28	
i 1	172.4940544217687	7.07	63	901	5	14	4	16	0	1	16	0	0	6.933713913664838	28	
i 1	172.49593197278912	3.0300000000000002	63	199	5	18	6	16	5000	1	16	0	0	5.290431105685503	28	
i 1	172.49780952380954	1.01	63	585	4	7	8	16	0	1	16	0	0	6.345554294259793	28	
i 1	172.50406802721088	5.05	63	901	5	14	12	16	0	2	16	0	0	6.933713913664838	28	
i 1	172.50531972789116	1.01	61	199	1	27	15	1	0	248	1	308	0	1.154898545639104	28	
i 1	172.50657142857142	7.07	63	901	6	17	9	16	0	2	16	0	0	5.290431105685503	28	
i 1	172.50657142857142	8.08	61	901	6	17	4	16	0	1	16	0	0	5.290431105685503	28	
i 1	172.5115782312925	1.01	61	585	5	17	14	16	0	1	16	0	0	5.290431105685503	28	
i 1	172.51345578231292	8.08	61	585	5	13	1	1	0	1	1	0	0	5.169235055449704	28	
i 1	172.51533333333333	8.08	61	199	4	19	16	16	0	1	16	0	0	5.290431105685503	28	
i 1	173.00469387755103	1.7675	74	901	4	1	11	2	0	-2	2	0	0	0.488354119971917	28	
i 1	173.23779591836734	0.2525	74	585	5	5	13	2	0	-1	2	0	0	3.0065128918243444	28	
i 1	173.24655782312925	0.7575000000000001	72	585	4	4	16	0	0	0	0	0	0	4.0	28	
i 1	173.24718367346938	0.505	73	199	3	24	14	8	0	-2	8	0	0	4.0	28	
i 1	173.24843537414966	0.7575000000000001	70	199	1	24	14	2	5000	248	2	308	0	4.0	28	
i 1	173.2490612244898	0.2525	74	199	4	5	5	2	0	-2	2	0	0	3.0065128918243444	28	
i 1	173.48779591836734	7.07	61	585	6	17	2	16	0	1	16	0	0	5.290431105685503	28	
i 1	173.48967346938775	0.2525	72	199	5	3	5	1	0	0	1	0	0	4.0	28	
i 1	173.50344217687075	0.2525	71	199	5	5	15	2	5000	-2	2	0	0	3.0065128918243444	28	
i 1	173.50970068027212	7.07	61	199	4	27	2	1	0	2	1	0	0	1.154898545639104	28	
i 1	173.7628299319728	0.2525	74	199	4	1	1	8	5000	-2	8	0	0	0.488354119971917	28	
i 1	173.99280272108842	0.2525	69	199	5	4	1	0	0	0	0	0	0	4.0	28	
i 1	173.99342857142858	0.2525	70	585	4	24	4	2	0	-2	2	0	0	4.0	28	
i 1	174.0128299319728	2.2725	71	585	4	1	6	2	0	-2	2	0	0	0.488354119971917	28	
i 1	174.24092517006804	0.2525	71	199	3	1	15	2	0	-2	2	0	0	0.488354119971917	28	
i 1	174.24780952380954	2.2725	72	585	4	4	10	0	0	0	0	0	0	4.0	28	
i 1	174.2559455782313	0.2525	73	199	3	24	13	8	0	-1	8	0	0	4.0	28	
i 1	174.26345578231292	2.2725	74	901	6	5	4	8	0	-1	8	0	0	3.0065128918243444	28	
i 1	174.4884217687075	0.2525	74	901	6	1	8	2	0	-1	2	0	0	0.488354119971917	28	
i 1	175.00281632653062	0.2525	71	585	6	5	4	8	0	-2	8	0	0	3.0065128918243444	28	
i 1	175.0128299319728	1.7675	70	199	4	24	13	2	5000	-1	2	0	0	4.0	28	
i 1	175.23591836734693	0.2525	74	901	6	1	15	2	0	-1	2	0	0	0.488354119971917	28	
i 1	175.24342857142858	0.505	71	199	4	1	4	2	5000	-2	2	0	0	0.488354119971917	28	
i 1	175.4871700680272	5.05	63	199	4	27	4	16	0	1	16	0	0	1.154898545639104	28	
i 1	175.48967346938775	0.2525	73	199	3	24	3	2	0	-2	2	0	0	4.0	28	
i 1	175.49593197278912	0.2525	71	199	5	5	12	2	5000	-2	2	0	0	3.0065128918243444	28	
i 1	175.49655782312925	5.05	63	199	5	18	9	16	5000	1	16	0	0	5.290431105685503	28	
i 1	175.51533333333333	1.01	69	199	5	4	8	0	0	0	0	0	0	4.0	28	
i 1	175.76095238095238	0.2525	71	585	4	24	4	8	0	-2	8	0	0	3.488354119971917	28	
i 1	176.4940544217687	0.2525	72	199	6	9	12	1	5000	0	1	0	0	3.0	29	
i 1	176.49655782312925	0.2525	71	585	4	1	15	2	0	-2	2	0	0	0.488354119971917	29	
i 1	176.50031292517008	0.505	74	199	4	1	11	8	5000	-2	8	0	0	0.488354119971917	29	
i 1	176.74593197278912	0.2525	69	199	5	4	12	0	0	0	0	0	0	4.0	29	
i 1	176.75156462585034	0.2525	73	199	3	24	13	8	0	-2	8	0	0	4.0	29	
i 1	176.9871700680272	0.505	72	901	6	2	10	1	0	0	1	0	0	4.0	29	
i 1	177.01095238095238	0.2525	74	901	6	1	11	2	0	-1	2	0	0	0.488354119971917	29	
i 1	177.0128299319728	0.2525	72	585	4	4	16	0	0	0	0	0	0	4.0	29	
i 1	177.0128299319728	0.2525	70	199	4	24	15	2	5000	-1	2	0	0	4.0	29	
i 1	177.23904761904762	0.2525	71	199	3	1	10	2	0	-2	2	0	0	0.488354119971917	29	
i 1	177.25719727891158	0.505	72	199	5	3	5	1	0	0	1	0	0	4.0	29	
i 1	177.48779591836734	0.2525	71	585	6	5	12	8	0	-2	8	0	0	3.0065128918243444	29	
i 1	177.50156462585034	2.525	72	901	5	2	8	1	0	0	1	0	0	4.0	29	
i 1	177.50156462585034	0.2525	69	199	5	4	9	0	0	0	0	0	0	4.0	29	
i 1	177.50219047619046	0.2525	71	199	7	5	13	2	5000	-2	2	0	0	3.0065128918243444	29	
i 1	177.51220408163266	3.0300000000000002	63	901	3	14	12	16	0	2	16	0	0	6.933713913664838	29	
i 1	177.5147074829932	3.0300000000000002	63	199	5	18	13	1	5000	2	1	0	0	5.290431105685503	29	
i 1	177.73654421768708	0.2525	69	901	6	2	11	1	0	0	1	0	0	4.0	29	
i 1	177.7615782312925	0.2525	72	199	6	9	7	1	5000	0	1	0	0	3.0	29	
i 1	177.99655782312925	0.505	69	199	5	4	15	0	0	0	0	0	0	4.0	29	
i 1	178.0059455782313	0.2525	71	199	4	1	6	2	5000	-2	2	0	0	0.488354119971917	29	
i 1	178.49968707482992	0.2525	72	199	5	3	7	1	0	0	1	0	0	4.0	30	
i 1	178.50406802721088	0.2525	69	901	6	2	4	1	0	0	1	0	0	4.0	30	
i 1	178.73967346938775	0.505	72	585	4	4	11	0	0	0	0	0	0	4.0	30	
i 1	178.74029931972788	0.505	71	199	7	5	14	2	5000	-2	2	0	0	3.0065128918243444	30	
i 1	178.75657142857142	0.2525	71	585	6	1	15	2	0	-2	2	0	0	0.488354119971917	30	
i 1	178.9921768707483	0.2525	71	199	3	1	11	2	0	-2	2	0	0	0.488354119971917	30	
i 1	179.00719727891158	0.505	74	901	6	1	6	2	0	-1	2	0	0	0.488354119971917	30	
i 1	179.2371700680272	0.2525	74	199	5	5	5	8	5000	-1	8	0	0	3.0065128918243444	30	
i 1	179.26032653061225	1.2625	74	585	6	5	3	2	0	-1	2	0	0	3.0065128918243444	30	
i 1	179.48591836734693	1.01	63	901	5	17	3	16	0	2	16	0	0	5.290431105685503	30	
i 1	179.49342857142858	0.2525	74	199	4	1	8	8	5000	-2	8	0	0	0.488354119971917	30	
i 1	179.49530612244897	1.01	61	199	5	19	14	1	0	1	1	0	0	5.290431105685503	30	
i 1	179.49530612244897	1.01	63	901	3	14	4	16	0	1	16	0	0	6.933713913664838	30	
i 1	179.50156462585034	1.01	72	585	4	4	1	0	0	0	0	0	0	4.0	30	
i 1	179.50531972789116	1.01	71	585	6	5	11	8	0	-2	8	0	0	3.0065128918243444	30	
i 1	179.7384217687075	0.7575000000000001	71	585	4	24	13	8	0	-2	8	0	0	3.488354119971917	30	
i 1	180.0078231292517	0.505	69	199	6	9	1	0	5000	0	0	0	0	3.0	30	
i 1	180.23466666666667	0.2525	74	199	4	5	11	2	0	-2	2	0	0	3.0065128918243444	30	
i 1	180.48466666666667	4.545	66	185	6	14	10	6	5004	1	6	0	0	10.071186598918779	64	
i 1	180.4852925170068	5.555	61	185	6	13	13	9	5004	2	9	0	0	4.028474639567512	64	
i 1	180.4884217687075	0.505	74	185	7	5	12	17	5004	1	17	0	0	3.0	64	
i 1	180.48967346938775	0.2525	77	712	6	5	11	16	5001	1	16	0	0	3.0	64	
i 1	180.48967346938775	5.555	61	185	6	14	10	9	5004	1	9	0	0	4.428294622370949	64	
i 1	180.49155102040817	0.2525	72	701	3	24	12	2	0	-2	2	0	0	3.0	64	
i 1	180.49718367346938	0.2525	75	185	6	2	7	2	5004	1	2	0	0	4.0	64	
i 1	180.49968707482992	11.615	66	712	5	13	7	9	5001	2	9	0	0	2.663815764155815	64	
i 1	180.50156462585034	8.585	66	712	5	15	5	9	5001	2	9	0	0	6.0427119593512675	64	
i 1	180.5059455782313	10.605	66	712	5	15	10	6	5001	1	6	0	0	6.0427119593512675	64	
i 1	180.5078231292517	5.555	61	185	6	14	9	9	5004	2	9	0	0	4.428294622370949	64	
i 1	180.5115782312925	5.555	66	1087	4	16	6	9	0	1	9	0	0	8.056949279135024	64	
i 1	180.5147074829932	5.555	61	1087	4	16	13	6	0	2	6	0	0	8.056949279135024	64	
i 1	180.5147074829932	2.2725	74	712	6	5	1	16	5001	2	16	0	0	3.0	64	
i 1	180.7578231292517	0.2525	72	701	4	3	1	2	0	1	2	0	0	4.0	64	
i 1	180.99155102040817	5.05	61	701	3	12	13	6	0	1	6	0	0	8.056949279135024	64	
i 1	181.0009387755102	0.505	72	712	4	24	3	2	5001	1	2	0	0	3.0	64	
i 1	181.00406802721088	3.535	72	185	6	2	16	2	5004	-2	2	0	0	4.0	64	
i 1	181.2352925170068	0.505	77	185	7	5	12	17	5004	1	17	0	0	3.0	64	
i 1	181.7440544217687	0.505	72	701	3	24	2	2	0	-2	2	0	0	3.0	64	
i 1	181.75844897959183	0.505	77	701	5	5	9	17	0	2	17	0	0	3.0	64	
i 1	181.76408163265307	0.2525	77	712	6	5	8	16	5001	1	16	0	0	3.0	64	
i 1	182.25406802721088	0.2525	75	712	4	4	5	8	5001	1	8	0	0	4.0	64	
i 1	182.50469387755103	0.2525	72	701	3	24	7	2	0	-2	2	0	0	3.0	65	
i 1	182.74968707482992	0.2525	77	701	5	5	8	17	0	2	17	0	0	3.0	65	
i 1	182.99655782312925	0.505	72	1087	4	9	8	2	0	1	2	0	0	3.0	65	
i 1	183.0009387755102	0.2525	77	712	6	5	5	16	5001	1	16	0	0	3.0	65	
i 1	183.00344217687075	0.2525	75	185	7	2	5	2	5004	1	2	0	0	4.0	65	
i 1	183.00406802721088	0.2525	72	712	4	24	2	2	5001	1	2	0	0	3.0	65	
i 1	183.01533333333333	3.0300000000000002	61	701	3	12	1	6	0	2	6	0	0	8.056949279135024	65	
i 1	183.25156462585034	0.505	75	712	4	4	7	8	5001	1	8	0	0	4.0	65	
i 1	183.4921768707483	0.2525	72	701	4	3	8	2	0	1	2	0	0	4.0	65	
i 1	183.49280272108842	2.525	77	185	7	5	6	17	5004	1	17	0	0	3.0	65	
i 1	183.73967346938775	0.505	75	1087	5	9	8	8	0	1	8	0	0	3.0	65	
i 1	183.75719727891158	1.2625	75	185	7	2	5	2	5004	1	2	0	0	4.0	65	
i 1	184.24342857142858	0.505	77	701	4	5	12	16	0	1	16	0	0	3.0	65	
i 1	184.25344217687075	0.2525	72	1087	4	9	7	2	0	1	2	0	0	3.0	65	
i 1	184.25907482993196	0.7575000000000001	72	712	4	24	7	2	5001	1	2	0	0	3.0	65	
i 1	184.51220408163266	2.02	75	712	4	4	3	8	5001	1	8	0	0	4.0	66	
i 1	185.0009387755102	1.01	66	185	6	14	13	6	5004	1	6	0	0	10.071186598918779	66	
i 1	185.00406802721088	0.505	72	701	4	3	12	2	0	1	2	0	0	4.0	66	
i 1	185.00657142857142	0.2525	74	185	7	5	2	17	5004	1	17	0	0	3.0	66	
i 1	185.23967346938775	0.2525	72	712	5	3	11	2	5001	1	2	0	0	4.0	66	
i 1	185.24718367346938	0.2525	77	701	5	5	9	16	0	1	16	0	0	3.0	66	
i 1	185.49029931972788	0.2525	75	701	4	4	5	2	0	1	2	0	0	4.0	67	
i 1	185.49342857142858	1.01	72	712	4	24	10	2	5001	1	2	0	0	3.0	67	
i 1	185.75406802721088	0.2525	77	712	6	5	16	16	5001	1	16	0	0	3.0	67	
i 1	185.7647074829932	0.2525	75	185	7	2	5	2	5004	1	2	0	0	4.0	67	
i 1	185.98654421768708	7.07	66	4	5	16	12	6	0	2	6	0	0	8.056949279135024	68	
i 1	185.9884217687075	9.09	61	4	6	14	14	6	0	2	6	0	0	4.428294622370949	68	
i 1	185.99280272108842	9.09	66	4	5	16	2	9	0	1	9	0	0	8.056949279135024	68	
i 1	186.00031292517008	3.2825	71	888	1	24	13	1	5001	252	1	307	0	4.0	68	
i 1	186.00156462585034	9.09	61	4	6	14	6	9	0	1	9	0	0	10.071186598918779	68	
i 1	186.00219047619046	9.09	61	4	6	14	7	9	0	2	9	0	0	4.428294622370949	68	
i 1	186.00657142857142	1.01	66	4	6	13	14	9	0	2	9	0	0	4.028474639567512	68	
i 1	186.00719727891158	1.7675	72	4	7	2	16	8	0	1	8	0	0	4.0	68	
i 1	186.00844897959183	9.09	66	888	3	12	2	6	0	2	6	0	0	8.056949279135024	68	
i 1	186.01533333333333	9.09	66	888	3	12	8	6	0	1	6	0	0	8.056949279135024	68	
i 1	186.50970068027212	0.2525	72	888	3	24	16	2	0	-2	2	0	0	3.0	68	
i 1	186.51032653061225	2.2725	74	4	7	5	13	16	0	1	16	0	0	3.0	68	
i 1	186.5128299319728	0.2525	72	712	5	3	6	2	5001	1	2	0	0	4.0	68	
i 1	186.7371700680272	0.2525	75	712	4	4	5	8	5001	1	8	0	0	4.0	68	
i 1	187.00344217687075	8.08	66	4	6	13	16	9	0	2	9	0	0	4.028474639567512	68	
i 1	187.2490612244898	0.7575000000000001	74	888	5	5	8	16	0	1	16	0	0	3.0	68	
i 1	187.25031292517008	0.2525	75	4	7	2	8	2	0	1	2	0	0	4.0	68	
i 1	187.2578231292517	0.2525	77	4	7	5	10	17	0	2	17	0	0	3.0	68	
i 1	187.26345578231292	1.5150000000000001	72	712	5	3	10	2	5001	1	2	0	0	4.0	68	
i 1	187.50469387755103	0.505	72	712	4	24	16	2	5001	1	2	0	0	3.0	68	
i 1	187.5128299319728	0.505	74	712	6	5	10	16	5001	2	16	0	0	3.0	68	
i 1	187.74280272108842	0.2525	75	888	4	4	13	2	0	1	2	0	0	4.0	68	
i 1	187.98654421768708	0.505	72	888	4	24	11	2	0	-2	2	0	0	3.0	68	
i 1	187.99655782312925	0.505	74	4	7	5	5	17	0	2	17	0	0	3.0	68	
i 1	188.00031292517008	0.2525	74	888	5	5	14	17	0	2	17	0	0	3.0	68	
i 1	188.00657142857142	0.2525	75	4	7	2	14	2	0	1	2	0	0	4.0	68	
i 1	188.24968707482992	0.7575000000000001	75	712	4	4	6	8	5001	1	8	0	0	4.0	68	
i 1	188.2509387755102	0.2525	72	4	5	9	11	2	0	-2	2	0	0	3.0	68	
i 1	188.25281632653062	1.7675	74	712	6	5	4	16	5001	2	16	0	0	3.0	68	
i 1	188.50344217687075	0.7575000000000001	75	4	5	9	6	2	0	1	2	0	0	3.0	68	
i 1	188.75344217687075	0.2525	72	888	3	3	4	2	0	1	2	0	0	4.0	68	
i 1	188.75531972789116	0.2525	74	4	7	5	4	17	0	2	17	0	0	3.0	68	
i 1	188.75970068027212	0.2525	74	888	5	5	3	16	0	1	16	0	0	3.0	68	
i 1	188.98904761904762	0.2525	75	4	7	2	13	2	0	1	2	0	0	4.0	68	
i 1	188.9921768707483	3.0300000000000002	66	712	5	15	9	9	5001	2	9	0	0	6.0427119593512675	68	
i 1	188.99718367346938	0.2525	72	888	3	24	12	2	0	-2	2	0	0	3.0	68	
i 1	189.2371700680272	0.505	68	712	1	24	16	0	5001	0	0	0	0	4.0	68	
i 1	189.4990612244898	3.2825	75	4	7	2	12	2	0	1	2	0	0	4.0	68	
i 1	189.50719727891158	1.01	74	4	7	5	5	16	0	1	16	0	0	3.0	68	
i 1	189.73904761904762	0.2525	72	712	4	24	1	2	5001	1	2	0	0	3.0	68	
i 1	189.75281632653062	2.525	77	4	7	5	11	16	0	2	16	0	0	3.0	68	
i 1	189.99718367346938	0.2525	72	888	3	24	8	2	0	-2	2	0	0	3.0	69	
i 1	190.0115782312925	0.2525	74	4	7	5	5	17	0	2	17	0	0	3.0	69	
i 1	190.49780952380954	0.2525	77	4	7	5	13	17	0	2	17	0	0	3.0	69	
i 1	190.75156462585034	0.2525	77	712	6	5	10	16	5001	1	16	0	0	3.0	69	
i 1	190.99342857142858	1.01	66	712	5	15	16	6	5001	1	6	0	0	6.0427119593512675	69	
i 1	191.00907482993196	0.505	72	712	5	3	13	2	5001	1	2	0	0	4.0	69	
i 1	191.00970068027212	0.505	74	4	7	5	12	17	0	2	17	0	0	3.0	69	
i 1	191.4921768707483	0.2525	72	888	3	3	6	2	0	1	2	0	0	4.0	69	
i 1	191.51220408163266	0.505	77	712	6	5	5	16	5001	1	16	0	0	3.0	69	
i 1	191.74843537414966	0.2525	75	4	6	9	7	2	0	1	2	0	0	3.0	69	
i 1	191.7509387755102	0.2525	75	712	4	4	13	8	5001	1	8	0	0	4.0	69	
i 1	191.9871700680272	3.0300000000000002	61	622	5	15	7	6	0	2	6	0	0	6.0427119593512675	70	
i 1	191.99655782312925	3.0300000000000002	61	622	5	15	16	6	0	2	6	0	0	6.0427119593512675	70	
i 1	192.00156462585034	0.505	72	4	7	2	4	8	0	1	8	0	0	4.0	70	
i 1	192.00531972789116	1.5150000000000001	72	622	4	4	9	8	0	-2	8	0	0	4.0	70	
i 1	192.0059455782313	1.5150000000000001	74	622	6	5	13	16	0	2	16	0	0	3.0	70	
i 1	192.0147074829932	3.0300000000000002	66	622	5	13	3	6	0	1	6	0	0	2.663815764155815	70	
i 1	192.01533333333333	1.7675	71	4	1	24	16	1	0	-1	1	0	0	4.0	70	
i 1	192.24530612244897	0.505	74	4	7	5	15	17	0	2	17	0	0	3.0	70	
i 1	192.24780952380954	0.2525	68	622	1	24	2	1	0	-1	1	0	0	4.0	70	
i 1	192.49280272108842	0.2525	72	888	3	3	4	2	0	1	2	0	0	4.0	70	
i 1	192.51533333333333	0.7575000000000001	74	888	5	5	6	16	0	1	16	0	0	3.0	70	
i 1	192.7647074829932	0.2525	72	4	5	9	15	2	0	-2	2	0	0	3.0	70	
i 1	192.7647074829932	2.02	77	4	7	5	9	16	0	2	16	0	0	3.0	70	
i 1	192.9871700680272	0.505	72	888	3	3	2	2	0	1	2	0	0	4.0	70	
i 1	192.99092517006804	1.7675	72	622	4	24	6	2	0	-2	2	0	0	3.0	70	
i 1	192.99843537414966	2.02	75	4	7	2	1	2	0	1	2	0	0	4.0	70	
i 1	193.00344217687075	2.02	66	4	5	16	1	6	0	2	6	0	0	8.056949279135024	70	
i 1	193.25031292517008	0.2525	74	4	7	5	11	16	0	1	16	0	0	3.0	70	
i 1	193.48904761904762	0.2525	74	888	5	5	1	16	0	1	16	0	0	3.0	70	
i 1	193.49968707482992	0.2525	68	622	1	24	15	1	0	0	1	0	0	4.0	70	
i 1	193.51345578231292	0.2525	72	4	6	9	3	2	0	-2	2	0	0	3.0	70	
i 1	193.7352925170068	0.505	74	888	6	5	9	17	0	2	17	0	0	3.0	70	
i 1	193.75281632653062	0.2525	77	4	7	5	7	17	0	2	17	0	0	3.0	70	
i 1	194.24655782312925	0.2525	71	622	1	24	6	0	0	-1	0	0	0	4.0	71	
i 1	194.49968707482992	0.505	74	622	6	5	10	16	0	2	16	0	0	3.0	71	
i 1	194.51220408163266	0.505	72	4	7	2	14	8	0	1	8	0	0	4.0	71	
i 1	194.75719727891158	0.2525	72	888	4	24	12	2	0	-2	2	0	0	3.0	71	
i 1	194.98967346938775	14.14	66	706	5	15	13	6	0	2	6	0	0	6.0427119593512675	72	
i 1	194.99092517006804	4.04	66	1092	5	14	13	6	0	1	6	0	0	4.428294622370949	72	
i 1	194.99280272108842	8.08	66	1092	5	14	7	6	0	1	6	0	0	10.071186598918779	72	
i 1	194.9940544217687	6.0600000000000005	61	1092	5	14	1	6	0	1	6	0	0	4.428294622370949	72	
i 1	194.9990612244898	2.02	61	1092	3	12	10	9	0	1	9	0	0	8.056949279135024	72	
i 1	195.00031292517008	4.04	61	1092	3	12	12	9	0	2	9	0	0	8.056949279135024	72	
i 1	195.00219047619046	8.08	66	706	5	13	13	9	0	1	9	0	0	2.663815764155815	72	
i 1	195.00344217687075	1.7675	75	706	4	4	14	2	0	1	2	0	0	4.0	72	
i 1	195.00406802721088	14.14	61	208	5	16	12	6	5006	1	6	0	0	8.056949279135024	72	
i 1	195.00469387755103	14.14	61	208	5	16	4	6	5006	2	6	0	0	8.056949279135024	72	
i 1	195.00531972789116	8.585	66	1092	5	13	13	6	0	2	6	0	0	4.028474639567512	72	
i 1	195.0059455782313	12.120000000000001	66	706	5	15	5	6	0	2	6	0	0	6.0427119593512675	72	
i 1	195.01032653061225	1.01	77	1092	5	5	15	17	0	2	17	0	0	3.0	72	
i 1	195.24155102040817	2.02	77	706	6	5	4	16	0	2	16	0	0	3.0	72	
i 1	195.24342857142858	0.2525	74	1092	6	5	9	16	0	2	16	0	0	3.0	72	
i 1	195.2509387755102	0.505	75	706	4	24	1	2	0	-2	2	0	0	3.0	72	
i 1	195.7647074829932	0.505	74	208	7	5	8	16	5006	1	16	0	0	3.0	73	
i 1	195.9871700680272	0.2525	75	1092	3	4	1	2	0	-2	2	0	0	4.0	73	
i 1	196.0147074829932	0.505	74	208	7	5	10	17	5006	2	17	0	0	3.0	73	
i 1	196.24968707482992	0.2525	68	208	1	24	5	1	5006	-1	1	0	0	4.0	73	
i 1	196.25907482993196	0.505	77	1092	6	5	15	16	0	2	16	0	0	3.0	73	
i 1	196.49029931972788	0.2525	75	1092	3	4	1	2	0	-2	2	0	0	4.0	73	
i 1	196.49155102040817	0.505	74	1092	6	5	2	16	0	2	16	0	0	3.0	73	
i 1	196.74029931972788	0.2525	74	208	7	5	13	17	5006	2	17	0	0	3.0	73	
i 1	196.75156462585034	1.01	75	208	6	9	10	2	5006	-2	2	0	0	3.0	73	
i 1	196.98904761904762	1.2625	74	1092	5	5	4	16	0	2	16	0	0	3.0	73	
i 1	197.00844897959183	0.2525	74	706	6	5	9	17	0	2	17	0	0	3.0	73	
i 1	197.01220408163266	2.525	61	1092	4	12	6	9	0	1	9	0	0	8.056949279135024	73	
i 1	197.25156462585034	0.2525	68	706	1	24	16	0	0	-1	0	0	0	4.0	73	
i 1	197.49593197278912	0.505	72	208	6	9	5	2	5006	-2	2	0	0	3.0	73	
i 1	197.50219047619046	0.2525	75	706	4	24	7	2	0	-2	2	0	0	3.0	73	
i 1	197.7628299319728	0.7575000000000001	75	1092	4	24	4	2	0	-2	2	0	0	3.0	73	
i 1	197.7647074829932	0.2525	77	1092	5	5	3	17	0	2	17	0	0	3.0	73	
i 1	197.9990612244898	0.2525	75	1092	4	4	4	2	0	-2	2	0	0	4.0	73	
i 1	198.00344217687075	1.01	77	706	6	5	14	16	0	2	16	0	0	3.0	73	
i 1	198.0078231292517	0.2525	68	706	1	24	16	0	0	0	0	0	0	4.0	73	
i 1	198.23591836734693	0.2525	77	1092	6	5	8	16	0	2	16	0	0	3.0	73	
i 1	198.2615782312925	0.505	74	208	7	5	5	16	5006	1	16	0	0	3.0	73	
i 1	198.26345578231292	1.5150000000000001	75	706	4	24	10	2	0	-2	2	0	0	3.0	73	
i 1	199.00156462585034	0.2525	77	1092	5	5	3	17	0	2	17	0	0	3.0	73	
i 1	199.00281632653062	0.505	61	1092	4	12	10	9	0	2	9	0	0	8.056949279135024	73	
i 1	199.0078231292517	4.545	66	1092	4	14	10	6	0	1	6	0	0	4.428294622370949	73	
i 1	199.50406802721088	4.04	67	4	5	12	8	5	0	1	5	0	0	8.056949279135024	74	
i 1	199.50406802721088	4.04	67	4	5	12	12	0	0	0	0	0	0	8.056949279135024	74	
i 1	199.74342857142858	0.2525	74	208	7	5	7	17	5006	2	17	0	0	3.0	74	
i 1	199.74655782312925	1.5150000000000001	75	706	4	4	13	2	0	1	2	0	0	4.0	74	
i 1	199.76408163265307	0.7575000000000001	77	706	5	5	2	16	0	2	16	0	0	3.0	74	
i 1	200.48591836734693	0.2525	77	1092	5	5	8	17	0	2	17	0	0	3.0	74	
i 1	200.5078231292517	1.7675	74	1092	5	5	5	16	0	2	16	0	0	3.0	74	
i 1	200.98466666666667	1.5150000000000001	75	706	4	24	3	2	0	-2	2	0	0	3.0	74	
i 1	200.99342857142858	2.525	61	1092	4	14	12	6	0	1	6	0	0	4.428294622370949	74	
i 1	200.99530612244897	1.5150000000000001	75	1092	6	2	7	2	0	-2	2	0	0	4.0	74	
i 1	201.00970068027212	1.01	74	706	5	5	2	17	0	2	17	0	0	3.0	74	
i 1	201.50970068027212	0.2525	75	4	7	5	13	2	0	1	2	0	0	3.0	75	
i 1	201.98591836734693	1.5150000000000001	75	1092	6	2	6	2	0	1	2	0	0	4.0	75	
i 1	202.0147074829932	0.2525	68	208	1	24	8	1	5006	-1	1	0	0	4.0	75	
i 1	202.2371700680272	0.2525	75	4	7	5	12	2	0	-2	2	0	0	3.0	75	
i 1	202.2628299319728	2.7775	77	706	5	5	14	16	0	2	16	0	0	3.0	75	
i 1	202.74342857142858	0.2525	75	1092	6	2	4	2	0	-2	2	0	0	4.0	75	
i 1	202.99029931972788	6.0600000000000005	66	706	4	13	13	9	0	1	9	0	0	2.663815764155815	75	
i 1	202.99593197278912	0.505	74	1092	5	5	10	16	0	2	16	0	0	3.0	75	
i 1	203.00531972789116	0.505	74	4	1	24	1	2	0	252	2	307	0	4.0	75	
i 1	203.0128299319728	0.505	77	1092	5	5	6	17	0	2	17	0	0	3.0	75	
i 1	203.0147074829932	0.505	66	1092	5	14	8	6	0	1	6	0	0	10.071186598918779	75	
i 1	203.24092517006804	1.7675	75	706	4	4	11	2	0	1	2	0	0	4.0	75	
i 1	203.48654421768708	5.555	60	208	5	12	2	5	5006	0	5	0	0	8.056949279135024	76	
i 1	203.4940544217687	5.555	60	208	5	12	9	0	5006	1	0	0	0	8.056949279135024	76	
i 1	203.49718367346938	1.5150000000000001	67	910	5	13	2	0	5006	0	0	0	0	4.028474639567512	76	
i 1	203.5009387755102	5.555	60	910	5	14	9	0	5006	1	0	0	0	10.071186598918779	76	
i 1	203.50406802721088	3.535	60	910	4	14	9	5	5006	0	5	0	0	4.428294622370949	76	
i 1	203.51408163265307	5.555	60	910	4	14	4	0	5006	1	0	0	0	4.428294622370949	76	
i 1	203.73904761904762	0.2525	71	910	6	2	12	2	5006	-1	2	0	0	4.0	76	
i 1	203.74718367346938	0.2525	72	910	5	5	9	2	5006	1	2	0	0	3.0	76	
i 1	203.99468027210884	0.505	74	208	7	5	7	16	5006	1	16	0	0	3.0	76	
i 1	204.00219047619046	0.2525	74	208	5	5	14	17	5006	2	17	0	0	3.0	76	
i 1	204.01220408163266	0.2525	71	208	3	24	10	2	0	-2	2	0	0	4.0	76	
i 1	204.0147074829932	0.505	71	910	6	2	5	8	5006	-1	8	0	0	4.0	76	
i 1	204.2440544217687	0.2525	72	208	6	9	4	2	5006	-2	2	0	0	3.0	76	
i 1	204.26220408163266	0.2525	71	706	4	24	12	8	0	1	8	0	0	4.0	76	
i 1	204.26408163265307	0.2525	75	706	4	24	6	2	0	-2	2	0	0	3.0	76	
i 1	204.48967346938775	0.2525	75	208	6	9	12	2	5006	-2	2	0	0	3.0	77	
i 1	204.5059455782313	0.2525	74	706	5	5	5	17	0	2	17	0	0	3.0	77	
i 1	204.5147074829932	0.2525	74	208	6	3	1	2	5006	-1	2	0	0	4.0	77	
i 1	204.76533333333333	3.7875	71	910	6	2	15	2	5006	-1	2	0	0	4.0	77	
i 1	204.99468027210884	4.04	67	910	5	13	2	0	5006	0	0	0	0	4.028474639567512	78	
i 1	205.00719727891158	4.04	66	706	4	7	5	9	0	1	9	0	0	3.840135002965904	78	
i 1	205.0078231292517	0.505	75	208	7	5	7	2	5006	-2	2	0	0	3.0	78	
i 1	205.0147074829932	0.7575000000000001	71	910	6	2	11	8	5006	-1	8	0	0	4.0	78	
i 1	205.26533333333333	0.2525	75	208	6	9	10	2	5006	-2	2	0	0	3.0	78	
i 1	205.50344217687075	0.2525	68	208	4	24	2	1	5006	-1	1	0	0	4.0	78	
i 1	205.9940544217687	0.2525	72	208	3	24	8	1	5006	-1	1	0	0	3.0	78	
i 1	205.99468027210884	0.2525	71	910	6	2	9	8	5006	-1	8	0	0	4.0	78	
i 1	206.00031292517008	0.2525	74	208	5	5	3	16	5006	1	16	0	0	3.0	78	
i 1	206.01220408163266	0.2525	74	208	5	5	8	17	5006	2	17	0	0	3.0	78	
i 1	206.74530612244897	0.505	74	208	5	5	8	16	5006	1	16	0	0	3.0	78	
i 1	206.9852925170068	2.02	60	910	6	17	7	0	5006	0	0	0	0	7.9356466585282535	78	
i 1	206.99530612244897	2.02	66	706	5	15	14	6	0	2	6	0	0	6.0427119593512675	78	
i 1	207.00719727891158	2.02	60	910	5	14	8	5	5006	0	5	0	0	4.428294622370949	78	
i 1	207.49780952380954	0.505	74	208	5	3	13	2	5006	-1	2	0	0	4.0	78	
i 1	207.99280272108842	0.2525	72	208	3	24	13	1	5006	-1	1	0	0	3.0	78	
i 1	208.01345578231292	0.2525	71	910	6	2	9	8	5006	-1	8	0	0	4.0	78	
i 1	208.2371700680272	1.01	75	706	4	4	14	2	0	1	2	0	0	4.0	78	
i 1	208.2647074829932	0.2525	74	208	5	5	13	17	5006	2	17	0	0	3.0	78	
i 1	208.48967346938775	0.505	68	208	4	24	6	1	5006	-1	1	0	0	4.0	78	
i 1	208.50219047619046	0.2525	72	706	5	3	3	2	0	-2	2	0	0	4.0	78	
i 1	208.76533333333333	0.2525	71	910	6	2	7	2	5006	-1	2	0	0	4.0	78	
i 1	208.98654421768708	9.595	60	910	5	14	10	5	5006	0	5	0	0	2.715139349179956	79	
i 1	208.9884217687075	9.595	67	208	4	27	14	5	5006	0	5	0	0	1.154898545639105	79	
i 1	208.99155102040817	2.02	61	208	5	16	3	6	5006	1	6	0	0	14.0	79	
i 1	208.99280272108842	8.08	67	208	4	27	7	0	5006	0	0	0	0	1.154898545639105	79	
i 1	208.9940544217687	9.595	60	910	5	14	13	0	5006	1	0	0	0	14.0	79	
i 1	208.99468027210884	0.505	71	910	6	2	12	8	5006	-1	8	0	0	4.0	79	
i 1	208.99593197278912	8.08	60	208	5	12	8	5	5006	0	5	0	0	14.0	79	
i 1	209.00031292517008	2.02	66	706	5	15	5	6	0	2	6	0	0	14.0	79	
i 1	209.00156462585034	2.02	66	706	4	7	7	9	0	1	9	0	0	2.126979729774911	79	
i 1	209.00406802721088	2.02	75	706	4	24	12	2	0	-2	2	0	0	4.589290586500903	79	
i 1	209.00406802721088	6.0600000000000005	60	208	5	12	13	0	5006	1	0	0	0	14.0	79	
i 1	209.0059455782313	8.08	60	910	6	17	5	5	5006	0	5	0	0	8.817385176142503	79	
i 1	209.00719727891158	1.7675	71	910	6	2	15	2	5006	-1	2	0	0	4.0	79	
i 1	209.0078231292517	0.7575000000000001	68	208	3	24	15	1	5006	-1	1	0	0	4.0	79	
i 1	209.00844897959183	2.02	66	706	4	13	13	9	0	1	9	0	0	0.950660490964822	79	
i 1	209.00907482993196	1.01	71	208	3	24	2	2	5006	1	2	0	0	4.0	79	
i 1	209.00970068027212	6.0600000000000005	60	910	6	17	8	0	5006	0	0	0	0	8.817385176142503	79	
i 1	209.01032653061225	2.02	66	706	5	15	8	6	0	2	6	0	0	14.0	79	
i 1	209.01032653061225	2.02	60	910	5	14	5	0	5006	1	0	0	0	2.715139349179956	79	
i 1	209.0115782312925	9.595	67	910	5	13	15	0	5006	0	0	0	0	14.0	79	
i 1	209.0147074829932	4.04	61	208	5	16	2	6	5006	2	6	0	0	14.0	79	
i 1	209.23591836734693	0.2525	74	208	5	3	3	2	5006	-1	2	0	0	4.0	79	
i 1	209.24655782312925	0.505	74	706	5	5	7	17	0	2	17	0	0	3.0	79	
i 1	209.25344217687075	0.2525	72	910	6	1	8	1	5006	-1	1	0	0	1.589290586500903	79	
i 1	209.25531972789116	0.2525	74	208	5	5	6	16	5006	1	16	0	0	3.0	79	
i 1	209.49155102040817	0.505	72	208	6	9	4	2	5006	-2	2	0	0	3.0	79	
i 1	209.49155102040817	0.505	72	910	6	5	14	2	5006	-2	2	0	0	3.0	79	
i 1	209.50281632653062	0.7575000000000001	72	208	3	1	5	0	5006	-1	0	0	0	1.589290586500903	79	
i 1	209.75907482993196	0.2525	72	910	6	1	14	1	5006	-1	1	0	0	1.589290586500903	79	
i 1	209.99593197278912	0.2525	74	208	5	5	16	16	5006	1	16	0	0	3.0	79	
i 1	209.99843537414966	0.2525	74	208	5	5	3	17	5006	2	17	0	0	3.0	79	
i 1	210.23466666666667	0.7575000000000001	77	706	6	5	13	16	0	2	16	0	0	3.0	79	
i 1	210.23654421768708	0.2525	75	706	4	4	12	2	0	1	2	0	0	4.0	79	
i 1	210.2371700680272	0.2525	72	208	4	5	5	8	5006	-2	8	0	0	3.0	79	
i 1	210.2615782312925	0.2525	75	706	6	1	8	8	0	-2	8	0	0	1.589290586500903	79	
i 1	210.48904761904762	0.2525	68	208	3	24	14	1	5006	-1	1	0	0	4.0	79	
i 1	210.73654421768708	0.2525	74	208	5	5	15	17	5006	2	17	0	0	3.0	79	
i 1	210.7421768707483	0.2525	75	208	6	9	8	2	5006	-2	2	0	0	3.0	79	
i 1	210.75281632653062	3.535	72	910	6	1	11	0	5006	-1	0	0	0	1.589290586500903	79	
i 1	210.7559455782313	0.505	72	910	6	1	13	1	5006	-1	1	0	0	1.589290586500903	79	
i 1	210.75719727891158	1.01	68	208	1	24	13	1	5006	252	1	307	0	4.0	79	
i 1	210.98591836734693	16.16	67	579	5	15	4	5	5000	0	5	0	0	14.0	80	
i 1	210.98654421768708	8.08	60	579	6	17	7	5	5000	1	5	0	0	8.817385176142503	80	
i 1	210.98904761904762	0.505	75	579	6	5	9	2	5000	1	2	0	0	3.0	80	
i 1	210.99342857142858	7.575	61	208	5	16	8	6	5006	1	6	0	0	14.0	80	
i 1	210.99530612244897	0.2525	72	910	4	5	4	2	5006	1	2	0	0	3.0	80	
i 1	211.00219047619046	0.7575000000000001	71	579	4	4	12	2	5000	-2	2	0	0	4.0	80	
i 1	211.00281632653062	7.575	60	910	5	14	13	0	5006	1	0	0	0	2.715139349179956	80	
i 1	211.01032653061225	2.02	60	579	4	7	12	5	5000	1	5	0	0	2.126979729774911	80	
i 1	211.01408163265307	14.14	60	579	5	15	3	5	5000	1	5	0	0	14.0	80	
i 1	211.01408163265307	2.02	60	579	5	13	8	5	5000	1	5	0	0	0.950660490964822	80	
i 1	211.23466666666667	0.2525	74	208	5	3	4	2	5006	-1	2	0	0	4.0	80	
i 1	211.25219047619046	1.7675	72	910	6	5	12	2	5006	-2	2	0	0	3.0	80	
i 1	211.25970068027212	0.2525	75	208	7	1	15	2	5006	-2	2	0	0	1.589290586500903	80	
i 1	211.4852925170068	0.2525	72	208	6	9	2	2	5006	-2	2	0	0	3.0	80	
i 1	211.49029931972788	0.2525	72	910	4	5	2	2	5006	1	2	0	0	3.0	80	
i 1	211.49718367346938	0.2525	72	208	7	1	15	0	5006	-1	0	0	0	1.589290586500903	80	
i 1	211.50531972789116	0.2525	74	208	5	5	3	16	5006	1	16	0	0	3.0	80	
i 1	211.74342857142858	0.2525	74	208	5	5	16	17	5006	2	17	0	0	3.0	80	
i 1	211.74530612244897	0.505	68	208	3	24	5	1	5006	-1	1	0	0	4.0	80	
i 1	211.76032653061225	0.505	69	579	4	24	12	1	5000	-1	1	0	0	4.589290586500903	80	
i 1	212.26345578231292	0.2525	72	208	7	1	3	0	5006	-1	0	0	0	1.589290586500903	80	
i 1	212.49780952380954	0.2525	72	579	6	5	7	2	5000	-2	2	0	0	3.0	80	
i 1	212.5078231292517	0.2525	69	579	4	24	9	1	5000	-1	1	0	0	4.589290586500903	80	
i 1	212.5078231292517	0.2525	72	208	6	9	12	2	5006	-2	2	0	0	3.0	80	
i 1	212.51220408163266	0.2525	74	208	5	3	4	2	5006	-1	2	0	0	4.0	80	
i 1	212.7421768707483	1.7675	75	579	6	5	14	2	5000	1	2	0	0	3.0	80	
i 1	212.75344217687075	2.525	71	910	6	2	12	2	5006	-1	2	0	0	4.0	80	
i 1	212.98904761904762	5.555	61	208	5	16	6	6	5006	2	6	0	0	14.0	81	
i 1	212.99468027210884	0.2525	74	208	5	5	1	16	5006	1	16	0	0	3.0	81	
i 1	212.99593197278912	2.02	60	579	5	7	16	5	5000	1	5	0	0	2.126979729774911	81	
i 1	213.00219047619046	1.01	71	208	2	24	13	2	5006	1	2	0	0	4.0	81	
i 1	213.00844897959183	10.1	60	579	5	13	1	5	5000	1	5	0	0	0.950660490964822	81	
i 1	213.01408163265307	8.08	67	579	6	17	14	5	5000	0	5	0	0	8.817385176142503	81	
i 1	213.24530612244897	0.2525	72	910	4	5	14	2	5006	1	2	0	0	3.0	81	
i 1	214.00719727891158	0.2525	68	208	3	24	5	1	5006	-1	1	0	0	4.0	82	
i 1	214.0078231292517	0.2525	72	208	4	5	11	8	5006	-2	8	0	0	3.0	82	
i 1	214.01220408163266	1.2625	72	910	5	1	8	1	5006	-1	1	0	0	1.589290586500903	82	
i 1	214.2352925170068	0.7575000000000001	71	208	2	24	6	2	5006	1	2	0	0	4.0	82	
i 1	214.2647074829932	0.7575000000000001	74	208	1	24	7	2	5000	252	2	307	0	4.0	82	
i 1	214.73654421768708	1.5150000000000001	72	910	4	5	8	2	5006	-2	2	0	0	3.0	83	
i 1	214.99092517006804	0.2525	74	208	7	5	5	16	5006	1	16	0	0	3.0	83	
i 1	214.99155102040817	0.7575000000000001	71	208	3	20	2	2	5006	-2	2	0	0	7.000000000000002	83	
i 1	215.00031292517008	2.02	60	910	6	17	15	0	5006	0	0	0	0	8.817385176142503	83	
i 1	215.00281632653062	3.535	60	208	6	12	1	0	5006	1	0	0	0	14.0	83	
i 1	215.0128299319728	10.1	60	579	6	7	7	5	5000	1	5	0	0	2.126979729774911	83	
i 1	215.01408163265307	3.535	66	208	5	18	8	6	5006	2	6	0	0	8.817385176142503	83	
i 1	215.23904761904762	1.5150000000000001	69	579	6	1	2	1	5000	-1	1	0	0	1.589290586500903	83	
i 1	215.25469387755103	1.5150000000000001	71	579	4	4	8	2	5000	-2	2	0	0	4.0	83	
i 1	215.4940544217687	0.2525	74	208	3	20	5	2	5006	1	2	0	0	7.000000000000002	83	
i 1	215.49468027210884	0.505	71	910	6	2	13	2	5006	-1	2	0	0	4.0	83	
i 1	215.7371700680272	0.2525	71	579	3	24	13	2	5000	1	2	0	0	11.000000000000002	83	
i 1	215.75281632653062	0.2525	74	208	7	5	10	17	5006	2	17	0	0	3.0	83	
i 1	215.99092517006804	0.2525	71	208	2	24	15	2	5006	1	2	0	0	11.000000000000002	83	
i 1	216.00344217687075	0.2525	71	208	3	20	16	8	5006	-2	8	0	0	7.000000000000002	83	
i 1	216.24780952380954	0.505	71	910	3	20	2	8	5006	1	8	0	0	7.000000000000002	83	
i 1	216.25531972789116	0.2525	72	208	4	5	13	8	5006	-2	8	0	0	3.0	83	
i 1	216.2559455782313	0.7575000000000001	71	208	1	24	4	8	5006	248	8	308	0	11.000000000000002	83	
i 1	216.7440544217687	1.5150000000000001	69	579	4	24	13	1	5000	-1	1	0	0	4.589290586500903	83	
i 1	216.75970068027212	0.2525	74	208	3	20	2	2	5006	-2	2	0	0	7.000000000000002	83	
i 1	216.98779591836734	0.2525	71	208	2	24	15	2	5006	1	2	0	0	4.0	83	
i 1	216.98967346938775	0.2525	72	208	5	24	4	1	5006	-1	1	0	0	4.589290586500903	83	
i 1	216.99718367346938	0.2525	74	208	6	3	6	2	5006	-1	2	0	0	4.0	83	
i 1	217.00844897959183	1.5150000000000001	60	910	6	17	10	5	5006	0	5	0	0	8.817385176142503	83	
i 1	217.00970068027212	1.5150000000000001	66	208	5	18	3	9	5006	1	9	0	0	8.817385176142503	83	
i 1	217.0115782312925	1.5150000000000001	60	208	6	12	2	5	5006	0	5	0	0	14.0	83	
i 1	217.01220408163266	0.7575000000000001	71	579	4	4	4	2	5000	-2	2	0	0	4.0	83	
i 1	217.01533333333333	1.5150000000000001	60	910	6	17	7	0	5006	0	0	0	0	8.817385176142503	83	
i 1	217.24593197278912	0.2525	74	208	7	5	16	17	5006	2	17	0	0	3.0	83	
i 1	217.26032653061225	0.2525	75	208	6	5	15	2	5006	-2	2	0	0	3.0	83	
i 1	217.49530612244897	0.7575000000000001	75	579	4	5	11	2	5000	1	2	0	0	3.0	83	
i 1	217.5115782312925	1.01	71	208	2	24	6	2	5006	1	2	0	0	4.0	83	
i 1	217.74155102040817	0.2525	75	208	7	1	3	2	5006	-2	2	0	0	1.589290586500903	83	
i 1	217.74968707482992	0.7575000000000001	71	910	4	2	14	8	5006	-1	8	0	0	4.0	83	
i 1	218.25907482993196	0.2525	74	208	7	5	14	16	5006	1	16	0	0	3.0	83	
i 1	218.4852925170068	5.555	60	284	6	12	16	0	0	1	0	0	0	14.0	84	
i 1	218.48967346938775	1.5150000000000001	72	1098	6	5	7	2	0	1	2	0	0	3.0	84	
i 1	218.49029931972788	10.605	67	1098	4	16	16	5	5001	0	5	0	0	14.0	84	
i 1	218.49342857142858	4.545	67	1098	4	18	2	5	5001	1	5	0	0	8.817385176142503	84	
i 1	218.4940544217687	12.625	67	1098	4	16	15	0	5001	1	0	0	0	14.0	84	
i 1	218.49530612244897	1.2625	71	579	4	4	14	2	5000	-2	2	0	0	4.0	84	
i 1	218.49655782312925	4.545	67	1098	5	13	12	5	0	1	5	0	0	14.0	84	
i 1	218.49655782312925	2.525	74	284	1	24	9	2	0	252	2	307	0	4.0	84	
i 1	218.4990612244898	0.505	60	1098	6	17	12	0	0	0	0	0	0	8.817385176142503	84	
i 1	218.50344217687075	5.555	60	284	6	12	13	0	0	1	0	0	0	14.0	84	
i 1	218.5059455782313	2.525	60	1098	5	14	3	0	0	1	0	0	0	14.0	84	
i 1	218.5059455782313	6.565	60	1098	4	18	1	5	5001	0	5	0	0	8.817385176142503	84	
i 1	218.5078231292517	0.505	67	1098	5	14	6	0	0	0	0	0	0	2.715139349179956	84	
i 1	218.50907482993196	0.505	60	284	4	27	9	0	0	1	0	0	0	1.154898545639105	84	
i 1	218.51095238095238	2.525	67	1098	5	14	4	0	0	1	0	0	0	2.715139349179956	84	
i 1	218.51533333333333	5.555	60	1098	6	17	10	5	0	1	5	0	0	8.817385176142503	84	
i 1	218.51533333333333	0.2525	75	284	4	5	9	2	0	-2	2	0	0	3.0	84	
i 1	218.98654421768708	0.505	74	284	2	24	13	2	0	-2	2	0	0	4.0	84	
i 1	218.99092517006804	5.05	60	1098	6	17	15	0	0	0	0	0	0	8.817385176142503	84	
i 1	218.99092517006804	5.05	60	284	1	27	16	0	0	252	0	307	0	1.154898545639105	84	
i 1	219.00344217687075	5.05	60	284	5	19	2	5	0	0	5	0	0	8.817385176142503	84	
i 1	219.0078231292517	2.02	60	579	6	17	2	5	5000	1	5	0	0	8.817385176142503	84	
i 1	219.01408163265307	5.05	67	1098	3	14	16	0	0	0	0	0	0	2.715139349179956	84	
i 1	219.49780952380954	0.7575000000000001	75	579	6	5	14	2	5000	1	2	0	0	3.0	84	
i 1	219.51408163265307	2.7775	74	284	1	24	12	2	0	252	2	307	0	4.0	84	
i 1	220.00844897959183	0.2525	72	1098	6	5	1	8	0	1	8	0	0	3.0	84	
i 1	220.26095238095238	0.2525	75	284	6	5	2	2	0	-2	2	0	0	3.0	84	
i 1	220.4940544217687	0.2525	71	1098	4	2	13	8	0	-1	8	0	0	4.0	85	
i 1	220.5059455782313	0.505	74	1098	2	24	13	2	5001	1	2	0	0	4.0	85	
i 1	220.99092517006804	3.0300000000000002	60	1098	5	14	10	0	0	1	0	0	0	14.0	85	
i 1	221.00031292517008	2.02	71	1098	4	2	7	8	0	-1	8	0	0	4.0	85	
i 1	221.00281632653062	3.0300000000000002	67	1098	3	14	3	0	0	1	0	0	0	2.715139349179956	85	
i 1	221.0059455782313	9.09	60	579	6	17	14	5	5000	1	5	0	0	8.817385176142503	85	
i 1	221.0115782312925	2.02	67	579	6	17	2	5	5000	0	5	0	0	8.817385176142503	85	
i 1	221.0147074829932	3.0300000000000002	60	284	5	19	6	5	0	1	5	0	0	8.817385176142503	85	
i 1	221.2578231292517	0.2525	69	579	4	24	2	1	5000	-1	1	0	0	4.589290586500903	85	
i 1	221.50657142857142	0.505	69	579	5	1	12	1	5000	-1	1	0	0	1.589290586500903	85	
i 1	221.73904761904762	0.505	71	284	2	24	3	2	5000	1	2	0	0	4.0	85	
i 1	221.7509387755102	1.2625	72	1098	6	5	3	2	0	1	2	0	0	3.0	85	
i 1	222.00469387755103	1.7675	69	1098	5	1	11	1	0	0	1	0	0	1.589290586500903	85	
i 1	222.26032653061225	0.2525	69	1098	6	1	7	0	5001	-1	0	0	0	1.589290586500903	85	
i 1	222.26345578231292	0.505	74	284	2	24	11	2	0	-2	2	0	0	4.0	85	
i 1	222.50844897959183	0.2525	75	579	6	5	8	2	5000	1	2	0	0	3.0	86	
i 1	222.9871700680272	7.07	60	579	3	13	14	5	5000	1	5	0	0	0.950660490964822	86	
i 1	222.98967346938775	2.02	67	1098	4	18	4	5	5001	1	5	0	0	8.817385176142503	86	
i 1	222.99280272108842	1.01	67	1098	5	13	12	5	0	1	5	0	0	14.0	86	
i 1	223.00344217687075	0.7575000000000001	71	1098	6	2	13	8	0	-1	8	0	0	4.0	86	
i 1	223.00970068027212	7.07	67	579	6	17	6	5	5000	0	5	0	0	8.817385176142503	86	
i 1	223.24968707482992	0.7575000000000001	72	1098	3	5	11	2	5001	-2	2	0	0	3.0	86	
i 1	223.25281632653062	0.2525	74	1098	3	9	1	2	5001	-2	2	0	0	3.0	86	
i 1	223.4884217687075	1.01	69	579	4	24	9	1	5000	-1	1	0	0	4.589290586500903	87	
i 1	223.50344217687075	0.505	74	284	6	3	2	2	0	-1	2	0	0	4.0	87	
i 1	223.50719727891158	0.7575000000000001	72	579	6	5	5	2	5000	-2	2	0	0	3.0	87	
i 1	223.9852925170068	0.505	69	706	5	1	3	1	0	-1	1	0	0	1.589290586500903	88	
i 1	223.9871700680272	3.0300000000000002	67	390	4	19	8	0	0	0	0	0	0	8.817385176142503	88	
i 1	223.98779591836734	1.01	67	706	5	14	4	0	0	0	0	0	0	14.0	88	
i 1	223.99280272108842	5.05	60	390	4	19	14	0	0	1	0	0	0	8.817385176142503	88	
i 1	223.99468027210884	5.05	67	706	6	17	8	5	0	0	5	0	0	8.817385176142503	88	
i 1	223.99718367346938	11.11	60	390	5	12	6	0	0	0	0	0	0	14.0	88	
i 1	223.99780952380954	0.505	71	390	2	24	15	2	0	1	2	0	0	4.0	88	
i 1	223.99843537414966	3.0300000000000002	67	706	5	13	7	5	0	1	5	0	0	14.0	88	
i 1	224.0009387755102	1.5150000000000001	75	579	6	5	9	2	5000	1	2	0	0	3.0	88	
i 1	224.00219047619046	13.635	67	390	1	27	7	5	0	252	5	307	0	1.154898545639105	88	
i 1	224.00344217687075	9.09	67	390	5	12	5	5	0	0	5	0	0	14.0	88	
i 1	224.0059455782313	7.07	67	706	6	17	15	0	0	1	0	0	0	8.817385176142503	88	
i 1	224.0078231292517	9.09	67	706	3	14	12	5	0	0	5	0	0	2.715139349179956	88	
i 1	224.0147074829932	9.09	67	706	3	14	11	0	0	1	0	0	0	2.715139349179956	88	
i 1	224.49593197278912	4.545	69	706	5	1	12	0	0	-1	0	0	0	1.589290586500903	88	
i 1	224.50531972789116	0.2525	69	579	5	1	5	1	5000	-1	1	0	0	1.589290586500903	88	
i 1	224.50657142857142	0.2525	75	390	6	5	3	2	0	-2	2	0	0	3.0	88	
i 1	224.50907482993196	0.2525	71	1098	5	9	7	2	5001	-2	2	0	0	3.0	88	
i 1	224.5147074829932	0.505	74	579	4	3	4	2	5000	-1	2	0	0	4.0	88	
i 1	224.7421768707483	1.2625	74	390	2	24	11	2	0	1	2	0	0	4.0	88	
i 1	224.75344217687075	0.2525	71	579	4	4	7	2	5000	-2	2	0	0	4.0	88	
i 1	224.99968707482992	4.04	60	579	5	15	3	5	5000	1	5	0	0	14.0	88	
i 1	225.00281632653062	8.08	67	706	5	14	3	0	0	0	0	0	0	14.0	88	
i 1	225.00344217687075	0.2525	74	1098	3	9	8	2	5001	-2	2	0	0	3.0	88	
i 1	225.00469387755103	8.08	67	1098	4	18	6	5	5001	1	5	0	0	8.817385176142503	88	
i 1	225.00907482993196	2.02	60	1098	4	18	11	5	5001	0	5	0	0	8.817385176142503	88	
i 1	225.00907482993196	5.05	60	579	4	7	4	5	5000	1	5	0	0	2.126979729774911	88	
i 1	225.23466666666667	0.2525	72	390	4	24	3	1	0	-1	1	0	0	4.589290586500903	88	
i 1	225.24468027210884	0.505	71	390	4	4	2	2	0	-1	2	0	0	4.0	88	
i 1	225.24593197278912	0.7575000000000001	71	390	1	24	8	2	5000	252	2	307	0	4.0	88	
i 1	225.2509387755102	0.7575000000000001	75	706	6	5	13	2	0	-2	2	0	0	3.0	88	
i 1	225.50970068027212	0.2525	69	579	5	1	3	1	5000	-1	1	0	0	1.589290586500903	88	
i 1	225.51220408163266	0.2525	75	706	4	5	13	2	0	1	2	0	0	3.0	88	
i 1	225.76032653061225	0.2525	69	579	4	24	3	1	5000	-1	1	0	0	4.589290586500903	88	
i 1	226.00970068027212	0.2525	71	390	4	4	3	2	0	-1	2	0	0	4.0	88	
i 1	226.24530612244897	0.2525	75	390	3	5	3	2	0	-2	2	0	0	3.0	88	
i 1	226.49593197278912	0.2525	69	579	5	1	1	1	5000	-1	1	0	0	1.589290586500903	88	
i 1	226.7509387755102	0.2525	74	390	2	24	12	2	5000	-2	2	0	0	4.0	88	
i 1	226.98779591836734	6.0600000000000005	67	706	5	13	9	5	0	1	5	0	0	14.0	88	
i 1	226.99092517006804	2.02	67	390	4	19	15	0	0	0	0	0	0	8.817385176142503	88	
i 1	226.9921768707483	0.7575000000000001	69	579	5	1	1	1	5000	-1	1	0	0	1.589290586500903	88	
i 1	227.00469387755103	3.0300000000000002	67	579	5	15	13	5	5000	0	5	0	0	14.0	88	
i 1	227.00531972789116	0.2525	71	390	4	4	13	2	0	-1	2	0	0	4.0	88	
i 1	227.0078231292517	6.0600000000000005	60	1098	4	18	4	5	5001	0	5	0	0	8.817385176142503	88	
i 1	227.24029931972788	1.01	74	706	6	2	11	2	0	-2	2	0	0	4.0	88	
i 1	227.4852925170068	0.2525	71	390	4	4	3	2	0	-1	2	0	0	4.0	88	
i 1	227.73466666666667	0.2525	69	1098	4	1	6	0	5001	-1	0	0	0	1.589290586500903	88	
i 1	227.7371700680272	0.2525	75	706	4	5	1	2	0	1	2	0	0	3.0	88	
i 1	227.9940544217687	2.525	71	706	6	2	3	8	0	-2	8	0	0	4.0	89	
i 1	228.7628299319728	0.2525	74	390	3	3	7	8	0	-1	8	0	0	4.0	89	
i 1	228.9852925170068	2.02	60	390	4	19	5	0	0	1	0	0	0	8.817385176142503	89	
i 1	228.99593197278912	4.04	67	1098	4	16	5	5	5001	0	5	0	0	14.0	89	
i 1	228.99655782312925	8.585	67	390	4	19	10	0	0	0	0	0	0	8.817385176142503	89	
i 1	229.00031292517008	1.01	60	579	5	15	8	5	5000	1	5	0	0	14.0	89	
i 1	229.00281632653062	1.5150000000000001	74	1098	2	24	14	2	5001	1	2	0	0	4.0	89	
i 1	229.0059455782313	2.2725	75	706	4	5	3	2	0	1	2	0	0	3.0	89	
i 1	229.48466666666667	0.2525	74	1098	5	9	5	2	5001	-2	2	0	0	3.0	89	
i 1	229.73466666666667	0.2525	71	390	3	4	12	2	0	-1	2	0	0	4.0	89	
i 1	229.99155102040817	3.0300000000000002	60	390	6	17	13	5	0	0	5	0	0	8.817385176142503	90	
i 1	230.00719727891158	0.2525	75	1098	6	5	14	2	5001	-2	2	0	0	3.0	90	
i 1	230.0078231292517	3.0300000000000002	60	390	3	13	10	5	0	0	5	0	0	0.950660490964822	90	
i 1	230.01032653061225	1.01	67	390	5	15	3	5	0	0	5	0	0	14.0	90	
i 1	230.0115782312925	3.0300000000000002	60	390	6	17	12	0	0	0	0	0	0	8.817385176142503	90	
i 1	230.01533333333333	3.0300000000000002	60	390	5	15	4	0	0	1	0	0	0	14.0	90	
i 1	230.01533333333333	3.0300000000000002	67	390	4	7	1	0	0	0	0	0	0	2.126979729774911	90	
i 1	230.23591836734693	0.505	75	706	4	5	4	2	0	-2	2	0	0	3.0	90	
i 1	230.49718367346938	0.505	74	706	6	2	5	2	0	-2	2	0	0	4.0	90	
i 1	230.50844897959183	1.01	69	706	6	1	15	1	0	-1	1	0	0	1.589290586500903	90	
i 1	230.98591836734693	6.565	60	390	4	19	11	0	0	1	0	0	0	8.817385176142503	90	
i 1	230.98904761904762	0.505	71	706	6	2	8	8	0	-2	8	0	0	4.0	90	
i 1	231.01032653061225	0.7575000000000001	74	706	4	2	6	2	0	-2	2	0	0	4.0	90	
i 1	231.0128299319728	2.02	67	390	5	15	8	5	0	0	5	0	0	14.0	90	
i 1	231.0147074829932	2.02	67	1098	4	16	10	0	5001	1	0	0	0	14.0	90	
i 1	231.0147074829932	0.2525	74	390	2	24	15	2	0	1	2	0	0	4.0	90	
i 1	231.23591836734693	0.505	75	390	4	5	14	2	0	1	2	0	0	3.0	90	
i 1	231.24342857142858	0.7575000000000001	74	1098	1	24	13	2	5001	1	2	0	0	4.0	90	
i 1	231.51095238095238	0.2525	71	390	3	4	6	2	0	-1	2	0	0	4.0	90	
i 1	231.74843537414966	0.2525	71	390	4	4	9	8	0	-2	8	0	0	4.0	90	
i 1	231.9871700680272	1.01	74	1098	1	24	11	2	5001	252	2	307	0	4.0	91	
i 1	232.00844897959183	0.505	71	390	2	24	8	2	0	1	2	0	0	4.0	91	
i 1	232.25907482993196	0.2525	74	1098	5	9	12	2	5001	-2	2	0	0	3.0	91	
i 1	232.7352925170068	0.2525	71	706	6	2	3	8	0	-2	8	0	0	4.0	91	
i 1	232.7371700680272	0.2525	74	390	2	24	6	2	0	1	2	0	0	4.0	91	
i 1	232.98466666666667	4.04	67	390	5	12	14	5	0	0	5	0	0	14.0	92	
i 1	232.98779591836734	2.02	67	4	6	14	9	0	0	0	0	0	0	14.0	92	
i 1	232.99092517006804	2.02	67	390	4	16	16	0	0	1	0	0	0	14.0	92	
i 1	232.99155102040817	4.545	60	390	4	18	13	5	0	0	5	0	0	8.817385176142503	92	
i 1	232.99342857142858	6.0600000000000005	67	4	4	14	14	5	0	1	5	0	0	2.715139349179956	92	
i 1	232.9940544217687	4.545	67	706	5	15	12	5	0	1	5	0	0	14.0	92	
i 1	232.99593197278912	4.545	60	390	4	16	10	0	0	1	0	0	0	14.0	92	
i 1	232.99593197278912	1.01	74	706	4	4	12	2	0	-2	2	0	0	4.0	92	
i 1	232.99655782312925	4.04	60	390	4	18	1	0	0	0	0	0	0	8.817385176142503	92	
i 1	232.99655782312925	4.545	60	706	4	7	5	0	0	1	0	0	0	2.126979729774911	92	
i 1	232.99780952380954	4.545	67	706	5	15	3	0	0	1	0	0	0	14.0	92	
i 1	232.9990612244898	6.0600000000000005	67	4	4	14	9	0	0	1	0	0	0	2.715139349179956	92	
i 1	233.00406802721088	0.505	72	706	6	1	2	0	0	0	0	0	0	1.589290586500903	92	
i 1	233.00657142857142	0.2525	71	390	3	4	4	2	0	-1	2	0	0	4.0	92	
i 1	233.00657142857142	4.545	67	706	3	13	7	5	0	1	5	0	0	0.950660490964822	92	
i 1	233.01032653061225	4.04	67	4	6	13	2	0	0	1	0	0	0	14.0	92	
i 1	233.0115782312925	1.2625	69	4	7	1	1	0	0	0	0	0	0	1.589290586500903	92	
i 1	233.0147074829932	2.02	67	706	6	17	15	0	0	1	0	0	0	8.817385176142503	92	
i 1	233.5078231292517	0.2525	72	390	5	1	6	1	0	-1	1	0	0	1.589290586500903	93	
i 1	233.5147074829932	0.2525	71	390	5	9	8	2	0	-2	2	0	0	3.0	93	
i 1	233.7509387755102	0.2525	72	706	6	1	2	0	0	0	0	0	0	1.589290586500903	93	
i 1	234.01408163265307	0.2525	71	390	5	9	6	2	0	-2	2	0	0	3.0	93	
i 1	234.23967346938775	0.505	69	390	4	1	4	1	0	-1	1	0	0	1.589290586500903	93	
i 1	234.26032653061225	0.2525	74	390	5	3	4	8	0	-1	8	0	0	4.0	93	
i 1	234.26533333333333	1.5150000000000001	72	706	6	1	6	0	0	0	0	0	0	1.589290586500903	93	
i 1	234.49843537414966	0.505	75	4	5	5	2	2	0	-2	2	0	0	3.0	93	
i 1	234.7647074829932	0.2525	72	390	4	24	9	1	0	-1	1	0	0	4.589290586500903	93	
i 1	234.98967346938775	4.04	67	4	6	14	2	0	0	0	0	0	0	14.0	93	
i 1	234.9990612244898	0.505	71	390	4	4	14	2	0	-1	2	0	0	4.0	93	
i 1	235.00406802721088	2.525	60	390	5	12	11	0	0	0	0	0	0	14.0	93	
i 1	235.01408163265307	1.01	74	390	1	24	9	2	0	1	2	0	0	4.0	93	
i 1	235.01533333333333	2.525	67	390	4	16	7	0	0	1	0	0	0	14.0	93	
i 1	235.5128299319728	0.2525	75	390	6	5	7	2	0	-2	2	0	0	3.0	93	
i 1	235.5147074829932	0.2525	74	706	4	4	13	2	0	-2	2	0	0	4.0	93	
i 1	235.7421768707483	0.2525	71	706	4	3	16	8	0	-2	8	0	0	4.0	93	
i 1	235.74655782312925	0.2525	69	706	4	24	2	0	0	-1	0	0	0	4.589290586500903	93	
i 1	235.75156462585034	0.2525	72	706	4	5	14	2	0	-2	2	0	0	3.0	93	
i 1	235.76408163265307	1.5150000000000001	72	4	7	1	5	1	0	0	1	0	0	1.589290586500903	93	
i 1	236.01408163265307	0.7575000000000001	71	390	5	9	16	8	0	-1	8	0	0	3.0	93	
i 1	236.01533333333333	0.505	72	706	6	1	12	0	0	0	0	0	0	1.589290586500903	93	
i 1	236.48904761904762	0.2525	75	706	4	5	6	2	0	-2	2	0	0	3.0	93	
i 1	236.76533333333333	0.2525	74	390	5	3	14	8	0	-1	8	0	0	4.0	93	
i 1	236.99468027210884	0.505	67	390	4	12	10	5	0	0	5	0	0	14.0	93	
i 1	236.99530612244897	0.2525	71	390	5	9	9	2	0	-2	2	0	0	3.0	93	
i 1	236.99655782312925	2.02	67	4	6	13	11	0	0	1	0	0	0	14.0	93	
i 1	237.00219047619046	0.505	74	706	4	4	14	2	0	-2	2	0	0	4.0	93	
i 1	237.01345578231292	0.2525	72	390	4	24	9	1	0	-1	1	0	0	4.589290586500903	93	
i 1	237.24780952380954	0.2525	69	390	6	1	2	0	0	0	0	0	0	1.589290586500903	93	
i 1	237.2490612244898	0.2525	74	390	1	24	6	2	0	1	2	0	0	4.0	93	
i 1	237.2578231292517	0.2525	72	706	6	1	2	0	0	0	0	0	0	1.589290586500903	93	
i 1	237.48466666666667	1.5150000000000001	67	621	5	12	14	5	0	0	5	0	0	14.0	94	
i 1	237.4871700680272	0.505	74	235	2	24	11	2	5012	-2	2	0	0	4.0	94	
i 1	237.4921768707483	1.5150000000000001	60	621	4	19	16	0	0	1	0	0	0	8.817385176142503	94	
i 1	237.49718367346938	1.5150000000000001	67	937	5	15	3	5	5008	0	5	0	0	14.0	94	
i 1	237.49968707482992	1.5150000000000001	67	937	3	13	9	5	5008	1	5	0	0	0.950660490964822	94	
i 1	237.49968707482992	1.5150000000000001	67	937	4	7	1	0	5008	1	0	0	0	2.126979729774911	94	
i 1	237.50031292517008	1.5150000000000001	67	235	5	16	8	5	5012	1	5	0	0	14.0	94	
i 1	237.5009387755102	1.5150000000000001	74	4	5	2	11	2	0	-1	2	0	0	4.0	94	
i 1	237.50344217687075	1.5150000000000001	67	621	4	12	10	5	0	0	5	0	0	14.0	94	
i 1	237.50406802721088	1.5150000000000001	60	235	5	18	7	0	5012	0	0	0	0	8.817385176142503	94	
i 1	237.50469387755103	1.5150000000000001	67	621	4	19	12	5	0	1	5	0	0	8.817385176142503	94	
i 1	237.5059455782313	1.5150000000000001	60	621	1	27	13	0	0	252	0	307	0	1.154898545639105	94	
i 1	237.50657142857142	0.2525	74	937	4	3	1	8	5008	-1	8	0	0	4.0	94	
i 1	237.50719727891158	1.5150000000000001	60	235	5	16	10	5	5012	0	5	0	0	14.0	94	
i 1	237.51533333333333	1.5150000000000001	60	937	5	15	6	5	5008	0	5	0	0	14.0	94	
i 1	237.9871700680272	0.2525	74	4	5	2	8	2	0	-2	2	0	0	4.0	94	
i 1	237.99655782312925	0.2525	72	235	7	1	14	1	5012	-1	1	0	0	1.589290586500903	94	
i 1	238.00219047619046	0.7575000000000001	71	621	1	24	6	2	0	-2	2	0	0	4.0	94	
i 1	238.00344217687075	1.7675	75	4	7	5	6	2	0	-2	2	0	0	3.0	94	
i 1	238.2421768707483	0.2525	69	937	6	1	2	1	5008	-1	1	0	0	1.589290586500903	94	
i 1	238.48591836734693	0.505	69	4	7	1	2	0	0	0	0	0	0	1.589290586500903	94	
i 1	238.75031292517008	0.505	72	937	4	5	2	2	5008	1	2	0	0	3.0	94	
i 1	238.76408163265307	0.2525	69	235	7	1	14	0	5012	-1	0	0	0	1.589290586500903	94	
i 1	238.98779591836734	2.02	67	235	5	26	10	5	5012	1	5	0	0	11.548985456391039	94	
i 1	238.98967346938775	2.525	67	4	5	14	3	5	0	1	5	0	0	1.3616771179546303	94	
i 1	238.99155102040817	2.02	67	4	4	14	12	0	0	1	0	0	0	1.3616771179546303	94	
i 1	238.99530612244897	4.04	60	235	5	26	15	0	5012	1	0	0	0	11.548985456391039	94	
i 1	238.99780952380954	4.04	60	937	5	25	7	0	5008	0	0	0	0	11.548985456391039	94	
i 1	239.0059455782313	2.02	60	621	1	27	12	0	0	252	0	307	0	12.703884002030144	94	
i 1	239.0078231292517	2.02	60	4	6	25	1	0	0	0	0	0	0	11.548985456391039	94	
i 1	239.01032653061225	2.525	60	4	6	25	10	0	0	1	0	0	0	11.548985456391039	94	
i 1	239.01220408163266	4.04	60	937	5	25	9	5	5008	1	5	0	0	11.548985456391039	94	
i 1	239.0128299319728	2.525	69	4	7	1	4	0	0	0	0	0	0	2.9699977441471823	94	
i 1	239.25844897959183	0.2525	75	235	4	5	12	2	5012	-2	2	0	0	3.0	94	
i 1	239.4921768707483	1.7675	72	937	6	5	6	2	5008	-2	2	0	0	3.0	95	
i 1	239.49280272108842	0.2525	69	621	6	1	11	0	0	0	0	0	0	2.9699977441471823	95	
i 1	239.7384217687075	0.2525	71	621	1	24	16	2	0	-2	2	0	0	4.0	95	
i 1	239.74968707482992	0.2525	72	937	4	5	1	2	5008	1	2	0	0	3.0	95	
i 1	239.75531972789116	0.505	72	937	4	24	14	1	5008	0	1	0	0	5.969997744147182	95	
i 1	240.00531972789116	0.2525	71	621	5	3	11	8	0	-1	8	0	0	8.0	95	
i 1	240.23466666666667	0.2525	69	937	6	1	11	1	5008	-1	1	0	0	2.9699977441471823	95	
i 1	240.24843537414966	1.5150000000000001	74	937	4	4	3	2	5008	-1	2	0	0	8.0	95	
i 1	240.99092517006804	0.505	67	4	5	14	9	0	0	1	0	0	0	1.3616771179546303	95	
i 1	240.99155102040817	0.505	60	621	3	27	10	0	0	1	0	0	0	12.703884002030144	95	
i 1	240.99718367346938	0.505	60	4	6	25	8	0	0	0	0	0	0	11.548985456391039	95	
i 1	241.0059455782313	0.505	74	4	5	2	9	2	0	-2	2	0	0	8.0	95	
i 1	241.0147074829932	8.08	67	235	5	26	15	5	5012	1	5	0	0	11.548985456391039	95	
i 1	241.2371700680272	0.505	74	937	4	3	9	8	5008	-1	8	0	0	8.0	95	
i 1	241.48591836734693	7.575	60	1109	4	14	11	0	5009	0	0	0	0	1.3616771179546303	96	
i 1	241.49029931972788	1.5150000000000001	67	1109	5	25	11	5	5009	1	5	0	0	11.548985456391039	96	
i 1	241.49029931972788	1.5150000000000001	67	723	1	27	2	0	5009	252	0	307	0	12.703884002030144	96	
i 1	241.49092517006804	7.575	60	1109	4	14	6	5	5009	0	5	0	0	1.3616771179546303	96	
i 1	241.4921768707483	0.2525	75	723	3	5	16	2	5009	-2	2	0	0	3.0	96	
i 1	241.49593197278912	3.535	60	1109	5	25	10	5	5009	0	5	0	0	11.548985456391039	96	
i 1	241.5128299319728	3.535	60	723	3	27	9	0	5009	0	0	0	0	12.703884002030144	96	
i 1	241.74029931972788	0.505	71	235	4	9	16	8	5012	-1	8	0	0	7.0	96	
i 1	241.74092517006804	1.2625	74	723	1	24	8	2	5009	1	2	0	0	4.0	96	
i 1	242.23654421768708	0.2525	75	235	4	5	16	2	5012	-2	2	0	0	3.0	96	
i 1	242.2509387755102	0.505	69	937	6	1	9	1	5008	-1	1	0	0	2.9699977441471823	96	
i 1	242.74843537414966	0.2525	72	937	4	24	10	1	5008	0	1	0	0	5.969997744147182	97	
i 1	242.7490612244898	0.2525	72	937	6	5	1	2	5008	1	2	0	0	3.0	97	
i 1	242.9852925170068	8.08	60	235	5	26	5	0	5012	1	0	0	0	11.548985456391039	98	
i 1	242.98779591836734	0.7575000000000001	71	721	4	3	10	2	5011	-1	2	0	0	8.0	98	
i 1	242.99029931972788	4.04	67	723	3	27	7	0	5009	0	0	0	0	12.703884002030144	98	
i 1	242.99780952380954	0.2525	72	235	7	5	15	8	5012	-2	8	0	0	3.0	98	
i 1	243.00031292517008	4.04	67	1109	5	25	5	5	5009	1	5	0	0	11.548985456391039	98	
i 1	243.00219047619046	4.04	60	721	5	25	14	0	5011	0	0	0	0	11.548985456391039	98	
i 1	243.00844897959183	1.01	69	721	4	24	13	0	5011	0	0	0	0	5.969997744147182	98	
i 1	243.00907482993196	1.2625	74	235	3	24	1	2	5012	-2	2	0	0	4.0	98	
i 1	243.01032653061225	2.02	60	721	5	25	3	0	5011	0	0	0	0	11.548985456391039	98	
i 1	243.51408163265307	1.2625	71	1109	6	2	10	8	5009	-2	8	0	0	8.0	98	
i 1	243.75219047619046	0.2525	74	1109	6	2	9	2	5009	-2	2	0	0	8.0	98	
i 1	243.99655782312925	0.2525	72	721	6	5	10	2	5011	1	2	0	0	3.0	98	
i 1	243.99718367346938	0.2525	71	235	4	9	9	8	5012	-1	8	0	0	7.0	98	
i 1	244.01032653061225	0.505	71	235	4	9	3	2	5012	-2	2	0	0	7.0	98	
i 1	244.25469387755103	4.7975	72	1109	6	1	8	0	5009	-1	0	0	0	2.9699977441471823	98	
i 1	244.74155102040817	1.7675	72	1109	6	5	13	2	5009	-2	2	0	0	3.0	98	
i 1	244.7490612244898	0.505	74	721	4	4	13	2	5011	-1	2	0	0	8.0	98	
i 1	244.9852925170068	1.2625	71	721	5	3	10	2	5011	-1	2	0	0	8.0	98	
i 1	244.99155102040817	4.04	60	723	3	27	12	0	5009	0	0	0	0	12.703884002030144	98	
i 1	245.00344217687075	7.07	60	721	4	7	13	5	5011	1	5	0	0	0.7735174985495858	98	
i 1	245.00531972789116	4.04	60	721	5	25	13	0	5011	0	0	0	0	11.548985456391039	98	
i 1	245.0147074829932	0.2525	72	723	4	24	3	1	5009	0	1	0	0	5.969997744147182	98	
i 1	245.25844897959183	0.2525	71	235	4	9	6	2	5012	-2	2	0	0	7.0	98	
i 1	245.2628299319728	0.2525	71	721	3	24	15	8	5011	1	8	0	0	4.0	98	
i 1	245.4921768707483	0.2525	71	723	3	3	2	8	5009	-2	8	0	0	8.0	98	
i 1	245.50531972789116	0.505	74	723	1	24	7	2	5009	-2	2	0	0	4.0	98	
i 1	245.5128299319728	0.2525	74	1109	6	2	3	2	5009	-2	2	0	0	8.0	98	
i 1	245.98967346938775	0.7575000000000001	69	235	7	1	9	0	5012	-1	0	0	0	2.9699977441471823	98	
i 1	245.9940544217687	0.2525	75	1109	6	5	2	8	5009	1	8	0	0	3.0	98	
i 1	246.01220408163266	0.2525	75	723	3	5	4	2	5009	-2	2	0	0	3.0	98	
i 1	246.0147074829932	0.2525	74	235	3	24	13	2	5012	-2	2	0	0	4.0	98	
i 1	246.24029931972788	0.7575000000000001	74	721	4	4	5	2	5011	-1	2	0	0	8.0	98	
i 1	246.25406802721088	0.7575000000000001	74	723	1	24	11	2	5009	-2	2	0	0	4.0	98	
i 1	246.26345578231292	1.5150000000000001	72	721	6	5	6	2	5011	1	2	0	0	3.0	98	
i 1	246.50344217687075	0.2525	72	721	6	5	9	2	5011	1	2	0	0	3.0	98	
i 1	246.73591836734693	0.2525	75	723	3	5	16	2	5009	-2	2	0	0	3.0	98	
i 1	246.98779591836734	0.2525	69	235	7	1	4	0	5012	-1	0	0	0	2.9699977441471823	99	
i 1	246.99530612244897	4.04	60	721	5	25	2	0	5011	0	0	0	0	11.548985456391039	99	
i 1	246.99780952380954	2.02	67	723	3	27	16	0	5009	0	0	0	0	12.703884002030144	99	
i 1	247.00406802721088	2.525	74	721	4	4	15	2	5011	-1	2	0	0	8.0	99	
i 1	247.24655782312925	1.01	75	1109	4	5	7	8	5009	1	8	0	0	3.0	99	
i 1	247.25469387755103	0.2525	75	723	6	5	6	2	5009	-2	2	0	0	3.0	99	
i 1	247.49530612244897	0.2525	74	1109	4	2	14	2	5009	-2	2	0	0	8.0	99	
i 1	247.75657142857142	0.505	69	1109	5	1	8	0	5009	0	0	0	0	2.9699977441471823	99	
i 1	247.99968707482992	1.01	72	1109	6	5	6	2	5009	-2	2	0	0	3.0	99	
i 1	248.25844897959183	0.7575000000000001	69	235	7	1	15	0	5012	-1	0	0	0	2.9699977441471823	99	
i 1	248.2615782312925	0.505	72	235	7	5	8	8	5012	-2	8	0	0	3.0	99	
i 1	248.4921768707483	0.505	74	1109	4	2	9	2	5009	-2	2	0	0	8.0	99	
i 1	248.74593197278912	0.2525	74	723	2	24	10	2	5009	-2	2	0	0	4.0	99	
i 1	248.7509387755102	0.2525	75	235	7	5	10	2	5012	-2	2	0	0	3.0	99	
i 1	248.75657142857142	1.2625	69	721	6	1	5	0	5011	-1	0	0	0	2.9699977441471823	99	
i 1	248.98904761904762	0.2525	74	930	4	2	5	8	5013	-2	8	0	0	8.0	100	
i 1	248.98967346938775	0.2525	72	930	5	1	16	1	5013	0	1	0	0	2.9699977441471823	100	
i 1	248.99342857142858	0.2525	75	228	7	5	7	2	0	-2	2	0	0	3.0	100	
i 1	248.9940544217687	6.0600000000000005	67	930	4	14	1	0	5013	0	0	0	0	1.3616771179546303	100	
i 1	248.9990612244898	3.535	60	228	4	27	1	0	0	1	0	0	0	12.703884002030144	100	
i 1	248.99968707482992	4.04	60	930	4	14	13	0	5013	1	0	0	0	1.3616771179546303	100	
i 1	249.00907482993196	3.535	67	228	4	27	7	5	0	0	5	0	0	12.703884002030144	100	
i 1	249.0115782312925	3.535	67	235	5	26	7	5	5012	1	5	0	0	11.548985456391039	100	
i 1	249.25219047619046	0.2525	69	930	5	1	11	0	5013	0	0	0	0	2.9699977441471823	100	
i 1	249.26345578231292	1.5150000000000001	71	721	4	3	11	2	5011	-1	2	0	0	8.0	100	
i 1	249.73967346938775	0.505	71	930	4	2	8	2	5013	-2	2	0	0	8.0	100	
i 1	249.75844897959183	0.2525	71	228	3	4	11	2	0	-1	2	0	0	8.0	100	
i 1	250.24968707482992	0.2525	75	228	7	5	2	2	0	-2	2	0	0	3.0	100	
i 1	250.49280272108842	2.02	71	930	4	2	15	2	5013	-2	2	0	0	8.0	100	
i 1	250.76408163265307	0.2525	72	721	6	5	12	2	5011	1	2	0	0	3.0	100	
i 1	250.9884217687075	0.2525	74	721	4	4	2	2	5011	-1	2	0	0	8.0	101	
i 1	250.9940544217687	0.2525	75	235	7	5	4	2	5012	-2	2	0	0	3.0	101	
i 1	250.99968707482992	1.5150000000000001	60	235	5	26	2	0	5012	1	0	0	0	11.548985456391039	101	
i 1	251.00406802721088	0.2525	72	228	7	1	5	0	0	0	0	0	0	2.9699977441471823	101	
i 1	251.24092517006804	0.505	69	721	4	24	14	0	5011	0	0	0	0	5.969997744147182	101	
i 1	251.49468027210884	0.505	74	228	1	24	7	2	5011	-2	2	0	0	4.0	101	
i 1	251.51345578231292	0.7575000000000001	71	228	2	24	16	2	0	-2	2	0	0	4.0	101	
i 1	251.73904761904762	0.2525	69	721	5	1	1	0	5011	-1	0	0	0	2.9699977441471823	101	
i 1	251.74530612244897	0.505	71	235	6	9	15	2	5012	-2	2	0	0	7.0	101	
i 1	252.0009387755102	3.0300000000000002	72	930	5	1	1	1	5013	0	1	0	0	2.9699977441471823	102	
i 1	252.01095238095238	1.7675	75	614	4	5	15	2	5013	-2	2	0	0	3.0	102	
i 1	252.01345578231292	0.2525	74	614	2	24	2	2	5013	1	2	0	0	4.0	102	
i 1	252.25281632653062	0.2525	71	614	4	3	7	8	5013	-1	8	0	0	8.0	102	
i 1	252.49029931972788	2.525	67	1197	4	26	10	5	0	1	5	0	0	11.548985456391039	103	
i 1	252.49280272108842	1.5150000000000001	74	228	1	24	7	2	0	248	2	308	0	4.0	103	
i 1	252.49780952380954	0.505	60	228	4	27	12	0	0	0	0	0	0	12.703884002030144	103	
i 1	252.50844897959183	0.505	67	1197	4	26	13	0	0	1	0	0	0	11.548985456391039	103	
i 1	252.50907482993196	0.7575000000000001	74	228	2	24	2	2	0	-2	2	0	0	4.0	103	
i 1	252.51095238095238	2.525	60	228	4	27	2	5	0	1	5	0	0	12.703884002030144	103	
i 1	252.5115782312925	0.2525	71	228	3	3	3	2	0	-1	2	0	0	8.0	103	
i 1	252.9871700680272	0.2525	71	228	1	24	8	2	5013	1	2	0	0	4.0	103	
i 1	252.9884217687075	3.535	60	228	4	27	15	0	0	0	0	0	0	12.703884002030144	103	
i 1	252.9884217687075	3.535	60	930	3	14	7	0	5013	1	0	0	0	1.3616771179546303	103	
i 1	253.2384217687075	0.2525	72	614	5	1	4	0	5013	0	0	0	0	2.9699977441471823	103	
i 1	253.24155102040817	0.2525	69	614	4	24	7	0	5013	-1	0	0	0	5.969997744147182	103	
i 1	253.2509387755102	0.7575000000000001	75	930	4	5	13	8	5013	1	8	0	0	3.0	103	
i 1	253.2578231292517	0.2525	75	1197	6	5	1	8	0	-2	8	0	0	3.0	103	
i 1	253.48654421768708	3.0300000000000002	75	930	4	5	8	2	5013	-2	2	0	0	3.0	103	
i 1	253.49530612244897	0.505	72	1197	6	1	10	0	0	0	0	0	0	2.9699977441471823	103	
i 1	253.74718367346938	0.7575000000000001	75	1197	6	5	3	8	0	-2	8	0	0	3.0	103	
i 1	254.00281632653062	2.02	74	228	1	24	1	2	0	-2	2	0	0	4.0	103	
i 1	254.00907482993196	0.2525	75	1197	6	5	8	2	0	-2	2	0	0	3.0	103	
i 1	254.26032653061225	0.2525	72	228	7	5	1	8	0	-2	8	0	0	3.0	103	
i 1	254.4940544217687	2.02	72	614	5	1	16	0	5013	0	0	0	0	2.9699977441471823	103	
i 1	254.74092517006804	0.505	75	1197	6	5	14	2	0	-2	2	0	0	3.0	103	
i 1	254.9852925170068	1.5150000000000001	67	930	3	14	6	0	5013	0	0	0	0	1.3616771179546303	103	
i 1	254.99468027210884	1.5150000000000001	60	228	4	27	5	5	0	1	5	0	0	12.703884002030144	103	
i 1	254.99655782312925	1.5150000000000001	74	930	6	2	6	8	5013	-2	8	0	0	8.0	103	
i 1	255.01032653061225	0.2525	71	228	5	4	5	8	0	-1	8	0	0	8.0	103	
i 1	255.23654421768708	0.505	72	930	5	1	6	1	5013	0	1	0	0	2.9699977441471823	103	
i 1	255.25844897959183	0.2525	69	1197	5	1	3	1	0	-1	1	0	0	2.9699977441471823	103	
i 1	255.26032653061225	0.505	75	614	4	5	10	2	5013	-2	2	0	0	3.0	103	
i 1	255.26533333333333	0.2525	74	1197	4	9	15	8	0	-2	8	0	0	7.0	103	
i 1	255.48967346938775	0.2525	71	228	5	3	10	2	0	-1	2	0	0	8.0	103	
i 1	255.4990612244898	1.01	74	228	1	24	1	2	0	-2	2	0	0	4.0	103	
i 1	255.74530612244897	0.505	74	1197	4	9	11	8	0	-2	8	0	0	7.0	103	
i 1	255.76032653061225	0.2525	69	228	5	24	14	0	0	0	0	0	0	5.969997744147182	103	
i 1	256.0040680272109	0.505	71	614	4	3	2	8	5013	-1	8	0	0	8.0	103	
i 1	256.2528163265306	0.2525	74	1197	2	24	1	2	0	1	2	0	0	4.0	103	
i 1	256.48466666666667	2.525	67	400	3	27	1	0	5016	1	0	0	0	12.703884002030144	104	
i 1	256.4871700680272	0.7575000000000001	72	716	4	5	4	2	5016	1	2	0	0	3.0	104	
i 1	256.4884217687075	1.2625	72	716	4	24	14	0	0	-1	0	0	0	5.969997744147182	104	
i 1	256.4884217687075	0.2525	71	400	1	24	14	2	5016	-2	2	0	0	4.0	104	
i 1	256.4921768707483	0.7575000000000001	71	1102	1	24	5	2	0	1	2	0	0	4.0	104	
i 1	256.49468027210884	2.525	67	716	3	14	5	5	5016	1	5	0	0	1.3616771179546303	104	
i 1	256.4959319727891	0.505	74	716	4	3	8	8	0	-2	8	0	0	8.0	104	
i 1	256.50344217687075	4.545	60	716	3	14	4	0	5016	0	0	0	0	1.3616771179546303	104	
i 1	256.50844897959183	0.505	60	400	3	27	9	0	5016	1	0	0	0	12.703884002030144	104	
i 1	256.51032653061225	0.2525	71	716	6	2	16	8	5016	-2	8	0	0	8.0	104	
i 1	256.7496870748299	0.2525	74	400	4	4	1	8	5016	-1	8	0	0	8.0	104	
i 1	256.7647074829932	2.2725	74	400	1	24	3	2	5016	1	2	0	0	4.0	104	
i 1	256.99843537414966	1.01	74	716	5	3	12	8	0	-2	8	0	0	8.0	104	
i 1	257.00156462585034	0.2525	72	716	6	1	12	0	5016	0	0	0	0	2.9699977441471823	104	
i 1	257.00156462585034	0.7575000000000001	72	1102	4	1	15	1	0	0	1	0	0	2.9699977441471823	104	
i 1	257.0109523809524	12.120000000000001	60	400	1	27	15	0	5016	248	0	308	0	12.703884002030144	104	
i 1	257.2390476190476	2.02	72	716	6	1	6	0	5016	-1	0	0	0	2.9699977441471823	104	
i 1	257.4990612244898	0.2525	75	1102	3	5	11	2	0	-2	2	0	0	3.0	104	
i 1	257.509074829932	0.2525	75	716	4	5	9	8	0	1	8	0	0	3.0	104	
i 1	257.76032653061225	0.2525	69	1102	4	1	10	0	0	0	0	0	0	2.9699977441471823	104	
i 1	257.7634557823129	0.2525	69	400	6	1	15	1	5016	-1	1	0	0	2.9699977441471823	104	
i 1	257.99843537414966	0.2525	72	400	6	5	10	8	5016	-2	8	0	0	3.0	104	
i 1	258.00531972789116	0.2525	69	400	4	24	13	0	5016	-1	0	0	0	5.969997744147182	104	
i 1	258.00844897959183	0.505	71	1102	3	9	15	8	0	-2	8	0	0	7.0	104	
i 1	258.00844897959183	0.2525	75	716	4	5	11	8	0	1	8	0	0	3.0	104	
i 1	258.009074829932	0.2525	72	1102	4	1	8	1	0	0	1	0	0	2.9699977441471823	104	
i 1	258.2559455782313	0.2525	74	400	1	24	9	8	0	1	8	0	0	4.0	104	
i 1	258.259074829932	0.7575000000000001	69	1102	4	1	2	0	0	0	0	0	0	2.9699977441471823	104	
i 1	258.5009387755102	2.02	71	1102	1	24	5	2	0	1	2	0	0	4.0	105	
i 1	258.74468027210884	0.505	75	716	4	5	4	8	0	1	8	0	0	3.0	105	
i 1	258.7540680272109	4.2925	72	716	6	1	16	0	5016	0	0	0	0	2.9699977441471823	105	
i 1	258.7559455782313	0.2525	72	716	4	5	1	2	5016	1	2	0	0	3.0	105	
i 1	258.9865442176871	0.7575000000000001	71	400	1	24	2	2	5016	-2	2	0	0	4.0	105	
i 1	258.9884217687075	0.505	74	400	1	24	11	2	5016	252	2	307	0	4.0	105	
i 1	258.99155102040817	0.2525	69	716	6	1	1	0	0	0	0	0	0	2.9699977441471823	105	
i 1	258.99468027210884	10.1	67	400	1	27	6	0	5016	252	0	307	0	12.703884002030144	105	
i 1	259.0071972789116	8.08	67	716	4	14	7	5	5016	1	5	0	0	1.3616771179546303	105	
i 1	259.49843537414966	1.2625	75	716	4	5	15	8	0	-2	8	0	0	3.0	105	
i 1	259.7352925170068	0.2525	74	400	3	4	14	8	5016	-1	8	0	0	8.0	105	
i 1	260.0140816326531	3.535	74	716	4	4	7	2	0	-2	2	0	0	8.0	105	
i 1	260.2571972789116	1.7675	71	400	1	24	10	2	5016	-2	2	0	0	4.0	105	
i 1	260.2628299319728	1.7675	74	400	1	24	8	2	5016	252	2	307	0	4.0	105	
i 1	260.48779591836734	0.2525	71	400	3	3	14	8	5016	-1	8	0	0	8.0	106	
i 1	260.4978095238095	1.2625	69	898	4	1	3	0	0	0	0	0	0	2.9699977441471823	106	
i 1	260.5009387755102	0.505	74	898	1	24	15	2	0	-2	2	0	0	4.0	106	
i 1	261.00844897959183	8.08	60	716	4	14	15	0	5016	0	0	0	0	1.3616771179546303	106	
i 1	261.23466666666667	0.505	75	898	3	5	5	2	0	-2	2	0	0	3.0	106	
i 1	261.2371700680272	0.2525	75	898	3	5	9	2	0	-2	2	0	0	3.0	106	
i 1	261.74155102040817	0.505	72	400	3	5	6	2	5016	-2	2	0	0	3.0	107	
i 1	261.7540680272109	0.505	71	400	3	3	7	8	5016	-1	8	0	0	8.0	107	
i 1	261.7540680272109	0.505	74	716	1	24	12	2	0	252	2	307	0	4.0	107	
i 1	262.2428027210884	0.2525	75	716	4	5	13	8	0	-2	8	0	0	3.0	108	
i 1	262.48779591836734	0.2525	72	1102	4	1	6	1	0	0	1	0	0	2.9699977441471823	108	
i 1	262.4990612244898	0.505	69	1102	4	1	1	1	0	-1	1	0	0	2.9699977441471823	108	
i 1	262.51032653061225	0.505	72	716	6	5	5	2	5016	1	2	0	0	3.0	108	
i 1	262.51032653061225	0.2525	72	400	3	5	10	2	5016	-2	2	0	0	3.0	108	
i 1	262.990925170068	0.505	72	716	6	1	10	0	5016	0	0	0	0	2.9699977441471823	108	
i 1	263.00344217687075	1.01	71	400	1	24	14	2	5016	-2	2	0	0	4.0	108	
i 1	263.2471836734694	0.505	72	1102	4	1	2	1	0	0	1	0	0	2.9699977441471823	108	
i 1	263.2634557823129	0.7575000000000001	72	1102	3	5	1	2	0	1	2	0	0	3.0	108	
i 1	263.7628299319728	2.02	75	716	4	5	8	8	0	1	8	0	0	3.0	108	
i 1	263.98967346938775	1.7675	72	716	6	1	1	0	5016	0	0	0	0	2.9699977441471823	108	
i 1	264.00344217687075	0.2525	72	716	4	24	7	0	0	-1	0	0	0	5.969997744147182	108	
i 1	264.0128299319728	0.505	74	716	5	3	9	8	0	-2	8	0	0	8.0	108	
i 1	264.23466666666667	0.2525	74	400	3	4	12	8	5016	-1	8	0	0	8.0	108	
i 1	264.2384217687075	0.2525	72	716	6	1	1	0	5016	-1	0	0	0	2.9699977441471823	108	
i 1	264.2597006802721	0.2525	71	400	1	24	15	2	0	-2	2	0	0	4.0	108	
i 1	264.4940544217687	0.505	69	1102	6	1	3	1	0	-1	1	0	0	2.9699977441471823	108	
i 1	264.5009387755102	0.2525	74	1102	1	24	10	2	0	-2	2	0	0	4.0	108	
i 1	264.5140816326531	0.505	75	716	4	5	14	8	0	-2	8	0	0	3.0	108	
i 1	264.7421768707483	0.2525	75	1102	3	5	7	2	0	1	2	0	0	3.0	108	
i 1	264.75844897959183	0.2525	69	400	4	1	8	1	5016	-1	1	0	0	2.9699977441471823	108	
i 1	264.7609523809524	2.02	74	716	4	4	9	2	0	-2	2	0	0	8.0	108	
i 1	264.98779591836734	0.2525	72	716	6	1	9	0	5016	-1	0	0	0	2.9699977441471823	108	
i 1	264.9978095238095	3.0300000000000002	60	716	4	7	6	0	0	0	0	0	0	0.7735174985495858	108	
i 1	265.01220408163266	2.02	69	716	6	1	1	0	0	0	0	0	0	2.9699977441471823	108	
i 1	265.2402993197279	0.505	74	716	5	3	14	8	0	-2	8	0	0	8.0	108	
i 1	265.2528163265306	0.2525	74	400	3	4	15	8	5016	-1	8	0	0	8.0	108	
i 1	265.73466666666667	0.7575000000000001	69	400	4	24	5	0	5016	-1	0	0	0	5.969997744147182	108	
i 1	265.73466666666667	0.2525	71	400	1	24	7	2	0	-2	2	0	0	4.0	108	
i 1	265.7390476190476	0.2525	72	1102	3	5	5	2	0	1	2	0	0	3.0	108	
i 1	265.745306122449	0.2525	69	1102	6	1	10	1	0	-1	1	0	0	2.9699977441471823	108	
i 1	265.9852925170068	0.2525	75	1102	3	5	1	2	0	1	2	0	0	3.0	109	
i 1	265.99655782312925	0.505	75	716	4	5	10	8	0	1	8	0	0	3.0	109	
i 1	265.9971836734694	0.2525	71	400	5	3	5	8	5016	-1	8	0	0	8.0	109	
i 1	265.99843537414966	0.2525	71	716	6	2	1	8	5016	-2	8	0	0	8.0	109	
i 1	266.0071972789116	0.2525	74	400	1	24	16	2	5016	1	2	0	0	4.0	109	
i 1	266.2402993197279	0.2525	69	400	4	1	13	1	5016	-1	1	0	0	2.9699977441471823	109	
i 1	266.4865442176871	0.7575000000000001	69	1102	6	1	10	1	0	-1	1	0	0	2.9699977441471823	109	
i 1	266.4959319727891	0.2525	72	1102	3	5	15	2	0	1	2	0	0	3.0	109	
i 1	266.4978095238095	0.505	72	716	4	24	16	0	0	-1	0	0	0	5.969997744147182	109	
i 1	266.49843537414966	0.7575000000000001	71	716	6	2	9	8	5016	-2	8	0	0	8.0	109	
i 1	266.7365442176871	0.2525	74	1102	5	9	2	2	0	-2	2	0	0	7.0	109	
i 1	266.7490612244898	1.01	75	716	6	5	1	8	0	-2	8	0	0	3.0	109	
i 1	266.7597006802721	1.01	72	716	6	5	7	2	5016	1	2	0	0	3.0	109	
i 1	266.9902993197279	0.505	72	716	6	1	6	0	5016	-1	0	0	0	2.9699977441471823	109	
i 1	266.9940544217687	2.02	67	716	5	14	15	5	5016	1	5	0	0	1.3616771179546303	109	
i 1	266.99655782312925	1.01	72	716	4	24	7	0	0	-1	0	0	0	5.969997744147182	109	
i 1	266.9996870748299	0.2525	74	400	4	4	15	8	5016	-1	8	0	0	8.0	109	
i 1	267.2521904761905	0.2525	74	1102	1	24	10	2	0	-2	2	0	0	4.0	109	
i 1	267.2559455782313	1.01	74	716	6	2	1	2	5016	-1	2	0	0	8.0	109	
i 1	267.5115782312925	0.2525	69	400	4	24	3	0	5016	-1	0	0	0	5.969997744147182	109	
i 1	267.73779591836734	0.2525	75	1102	3	5	11	2	0	1	2	0	0	3.0	109	
i 1	267.7384217687075	1.01	71	400	1	24	2	2	5016	-2	2	0	0	4.0	109	
i 1	267.7634557823129	0.2525	72	400	3	5	1	8	5016	-2	8	0	0	3.0	109	
i 1	267.99155102040817	0.2525	72	610	6	5	14	2	0	-2	2	0	0	3.0	110	
i 1	267.99843537414966	1.01	74	610	4	4	7	8	0	-2	8	0	0	8.0	110	
i 1	268.00344217687075	0.2525	75	112	4	5	13	2	5017	-2	2	0	0	3.0	110	
i 1	268.2559455782313	0.7575000000000001	71	610	5	3	6	8	0	-2	8	0	0	8.0	110	
i 1	268.9890476190476	2.02	67	400	1	27	15	0	5016	252	0	307	0	9.239188365112831	110	
i 1	268.9902993197279	1.01	74	610	4	4	9	8	0	-2	8	0	0	4.0	110	
i 1	268.9959319727891	0.2525	74	400	1	24	16	2	5016	1	2	0	0	4.0	110	
i 1	268.99843537414966	2.02	60	716	5	25	15	5	5016	0	5	0	0	8.084289819473728	110	
i 1	269.0003129251701	0.2525	72	112	7	1	5	0	5017	0	0	0	0	2.114530660224938	110	
i 1	269.0003129251701	2.02	60	400	1	27	1	0	5016	252	0	307	0	9.239188365112831	110	
i 1	269.0078231292517	1.5150000000000001	72	716	6	5	10	2	5016	1	2	0	0	3.011193585509093	110	
i 1	269.0078231292517	0.505	72	400	3	5	11	2	5016	-2	2	0	0	3.011193585509093	110	
i 1	269.254693877551	0.505	72	716	6	1	7	0	5016	-1	0	0	0	2.114530660224938	110	
i 1	269.5021904761905	0.2525	74	400	1	24	1	2	5016	1	2	0	0	4.0	110	
i 1	269.5097006802721	1.5150000000000001	71	716	6	2	1	8	5016	-2	8	0	0	4.0	110	
i 1	269.5147074829932	0.2525	69	610	4	24	8	0	0	-1	0	0	0	5.114530660224938	110	
i 1	269.74655782312925	1.2625	71	400	1	24	5	2	5016	-2	2	0	0	4.0	110	
i 1	269.7640816326531	0.2525	69	400	6	1	3	1	5016	-1	1	0	0	2.114530660224938	110	
i 1	269.98466666666667	1.01	74	381	6	1	14	16	0	1	16	0	0	2.114530660224938	111	
i 1	270.01032653061225	0.505	74	716	6	2	11	2	5016	-1	2	0	0	4.0	111	
i 1	270.4928027210884	0.2525	72	400	3	5	16	2	5016	-2	2	0	0	3.011193585509093	111	
i 1	270.7390476190476	0.2525	72	381	6	5	6	0	0	-1	0	0	0	3.011193585509093	111	
i 1	270.7421768707483	0.2525	72	112	6	5	11	2	5017	-2	2	0	0	3.011193585509093	111	
i 1	270.9859183673469	2.02	69	614	6	5	11	0	0	-1	0	0	0	3.011193585509093	112	
i 1	270.9890476190476	12.120000000000001	61	228	1	27	15	9	0	252	9	307	0	9.239188365112831	112	
i 1	271.0040680272109	4.04	61	930	5	25	4	9	0	1	9	0	0	8.084289819473728	112	
i 1	271.0140816326531	2.02	61	930	5	25	7	9	0	0	9	0	0	8.084289819473728	112	
i 1	271.4859183673469	0.2525	69	228	3	5	16	0	0	0	0	0	0	3.011193585509093	113	
i 1	271.495306122449	0.2525	73	228	1	24	10	16	0	2	16	0	0	4.0	113	
i 1	271.5109523809524	4.04	74	614	4	24	1	17	0	1	17	0	0	5.114530660224938	113	
i 1	271.7352925170068	0.2525	77	228	6	9	11	17	5018	2	17	0	0	3.0	113	
i 1	271.7402993197279	0.505	73	228	1	24	14	16	0	248	16	308	0	4.0	113	
i 1	271.9884217687075	0.2525	74	228	7	1	10	16	5018	1	16	0	0	2.114530660224938	113	
i 1	271.98967346938775	0.2525	73	228	1	24	1	16	5018	1	16	0	0	4.0	113	
i 1	272.0097006802721	2.2725	74	930	6	2	5	16	0	1	16	0	0	4.0	113	
i 1	272.24843537414966	0.2525	77	930	6	1	16	16	0	2	16	0	0	2.114530660224938	113	
i 1	272.2628299319728	0.2525	77	228	5	4	9	16	0	1	16	0	0	4.0	113	
i 1	272.5003129251701	0.2525	74	228	6	9	16	17	5018	1	17	0	0	3.0	113	
i 1	272.74843537414966	0.505	77	228	5	4	3	16	0	1	16	0	0	4.0	113	
i 1	272.7578231292517	0.2525	73	228	1	24	11	16	5018	1	16	0	0	4.0	113	
i 1	272.7628299319728	0.2525	77	614	4	4	14	17	0	2	17	0	0	4.0	113	
i 1	272.98967346938775	1.7675	69	614	6	5	6	0	0	-1	0	0	0	3.011193585509093	113	
i 1	272.9971836734694	8.08	61	930	5	25	16	9	0	0	9	0	0	8.084289819473728	113	
i 1	272.99843537414966	4.04	61	614	5	25	7	9	0	1	9	0	0	8.084289819473728	113	
i 1	273.2371700680272	0.505	69	228	3	5	1	0	0	0	0	0	0	3.011193585509093	113	
i 1	273.73466666666667	0.2525	77	614	4	4	2	17	0	2	17	0	0	4.0	113	
i 1	273.75531972789116	1.2625	76	228	1	24	12	16	0	1	16	0	0	4.0	113	
i 1	273.9934285714286	0.7575000000000001	69	228	3	5	15	0	0	0	0	0	0	3.011193585509093	113	
i 1	274.2371700680272	0.505	74	228	6	9	7	17	5018	1	17	0	0	3.0	113	
i 1	274.2384217687075	0.2525	77	228	5	4	11	16	0	1	16	0	0	4.0	113	
i 1	274.25844897959183	3.0300000000000002	69	930	5	5	13	0	0	-1	0	0	0	3.011193585509093	113	
i 1	274.2640816326531	0.2525	73	228	1	24	7	16	0	2	16	0	0	4.0	113	
i 1	274.5003129251701	0.505	77	228	6	9	13	17	5018	2	17	0	0	3.0	113	
i 1	274.73779591836734	0.2525	69	930	6	5	13	0	0	0	0	0	0	3.011193585509093	113	
i 1	274.7540680272109	0.2525	77	228	5	24	16	16	0	2	16	0	0	5.114530660224938	113	
i 1	274.754693877551	0.7575000000000001	73	228	1	24	2	16	0	2	16	0	0	4.0	113	
i 1	274.7609523809524	0.2525	69	228	6	5	12	1	5018	0	1	0	0	3.011193585509093	113	
i 1	274.7615782312925	2.525	77	614	4	4	1	17	0	2	17	0	0	4.0	113	
i 1	274.9902993197279	8.08	61	930	5	25	4	9	0	1	9	0	0	8.084289819473728	113	
i 1	274.9928027210884	0.2525	69	614	6	5	11	0	0	-1	0	0	0	3.011193585509093	113	
i 1	274.9934285714286	0.2525	69	228	6	5	14	0	5018	0	0	0	0	3.011193585509093	113	
i 1	275.004693877551	4.04	66	614	5	25	6	6	0	1	6	0	0	8.084289819473728	113	
i 1	275.0071972789116	0.7575000000000001	74	228	7	1	8	16	5018	1	16	0	0	2.114530660224938	113	
i 1	275.2471836734694	0.2525	69	614	6	5	11	1	0	0	1	0	0	3.011193585509093	113	
i 1	275.26220408163266	0.2525	77	228	6	9	7	17	5018	2	17	0	0	3.0	113	
i 1	275.2634557823129	0.505	72	228	5	5	11	0	0	-1	0	0	0	3.011193585509093	113	
i 1	275.51533333333333	0.7575000000000001	74	614	5	3	12	17	0	2	17	0	0	4.0	114	
i 1	275.759074829932	0.2525	69	228	6	5	8	1	5018	0	1	0	0	3.011193585509093	114	
i 1	275.990925170068	0.2525	69	228	6	5	4	0	5018	0	0	0	0	3.011193585509093	114	
i 1	275.99155102040817	0.505	73	228	1	24	11	16	5018	1	16	0	0	4.0	114	
i 1	276.2402993197279	0.505	77	228	6	9	8	17	5018	2	17	0	0	3.0	114	
i 1	276.2428027210884	0.2525	74	228	7	1	11	16	5018	1	16	0	0	2.114530660224938	114	
i 1	276.254693877551	0.2525	74	930	6	1	11	17	0	2	17	0	0	2.114530660224938	114	
i 1	276.5109523809524	0.2525	74	228	6	1	12	16	0	2	16	0	0	2.114530660224938	114	
i 1	276.5115782312925	0.2525	69	614	6	5	8	0	0	-1	0	0	0	3.011193585509093	114	
i 1	276.7402993197279	0.505	74	228	7	1	2	16	5018	1	16	0	0	2.114530660224938	114	
i 1	276.990925170068	4.04	61	228	5	26	6	9	5018	0	9	0	0	8.084289819473728	114	
i 1	276.99843537414966	2.2725	77	930	6	1	14	16	0	2	16	0	0	2.114530660224938	114	
i 1	277.01220408163266	8.08	61	614	5	25	1	9	0	1	9	0	0	8.084289819473728	114	
i 1	277.2597006802721	0.505	69	228	5	5	12	0	0	0	0	0	0	3.011193585509093	114	
i 1	277.2609523809524	0.505	74	228	5	3	14	17	0	2	17	0	0	4.0	114	
i 1	277.4859183673469	0.7575000000000001	74	228	7	1	8	16	5018	2	16	0	0	2.114530660224938	115	
i 1	277.4902993197279	0.2525	72	228	5	5	1	0	0	-1	0	0	0	3.011193585509093	115	
i 1	277.49655782312925	0.2525	77	228	5	24	6	16	0	2	16	0	0	5.114530660224938	115	
i 1	277.9859183673469	0.2525	69	614	5	5	5	0	0	-1	0	0	0	3.011193585509093	115	
i 1	278.2371700680272	0.505	69	228	7	5	15	0	5018	0	0	0	0	3.011193585509093	115	
i 1	278.2540680272109	0.505	73	228	1	24	4	16	5018	1	16	0	0	4.0	115	
i 1	278.5021904761905	1.01	74	228	5	3	12	17	0	2	17	0	0	4.0	115	
i 1	278.5078231292517	0.505	74	614	6	1	1	17	0	2	17	0	0	2.114530660224938	115	
i 1	278.9940544217687	0.2525	69	930	5	5	16	0	0	0	0	0	0	3.011193585509093	115	
i 1	279.004693877551	1.2625	74	614	6	1	6	17	0	2	17	0	0	2.114530660224938	115	
i 1	279.0071972789116	4.04	61	228	5	26	6	9	5018	1	9	0	0	8.084289819473728	115	
i 1	279.01220408163266	8.08	66	614	5	25	11	6	0	1	6	0	0	8.084289819473728	115	
i 1	279.25344217687075	0.2525	74	228	7	1	13	16	5018	2	16	0	0	2.114530660224938	115	
i 1	279.2628299319728	0.505	74	614	4	24	5	17	0	1	17	0	0	5.114530660224938	115	
i 1	279.504693877551	0.505	74	228	6	9	9	17	5018	1	17	0	0	3.0	116	
i 1	279.5065714285714	0.2525	69	228	7	5	2	0	5018	0	0	0	0	3.011193585509093	116	
i 1	279.5134557823129	1.5150000000000001	77	614	4	4	3	17	0	2	17	0	0	4.0	116	
i 1	279.73779591836734	0.2525	69	228	7	5	5	1	5018	0	1	0	0	3.011193585509093	116	
i 1	280.240925170068	0.2525	74	228	6	9	1	17	5018	1	17	0	0	3.0	116	
i 1	280.2615782312925	0.2525	74	228	5	3	11	17	0	2	17	0	0	4.0	116	
i 1	280.5140816326531	0.505	72	228	5	5	5	0	0	-1	0	0	0	3.011193585509093	117	
i 1	280.98466666666667	4.04	66	228	4	27	3	6	0	1	6	0	0	9.239188365112831	118	
i 1	280.99468027210884	0.2525	74	228	5	3	7	17	0	2	17	0	0	4.0	118	
i 1	280.9978095238095	8.08	61	228	5	26	3	9	5018	0	9	0	0	8.084289819473728	118	
i 1	281.0078231292517	0.2525	74	930	6	2	6	17	0	2	17	0	0	4.0	118	
i 1	281.0097006802721	0.505	69	228	5	5	12	0	5018	0	0	0	0	3.011193585509093	118	
i 1	281.0140816326531	6.0600000000000005	61	930	5	25	6	9	0	0	9	0	0	8.084289819473728	118	
i 1	281.0147074829932	1.7675	74	614	6	1	14	17	0	2	17	0	0	2.114530660224938	118	
i 1	281.2384217687075	5.8075	69	930	5	5	13	0	0	-1	0	0	0	3.011193585509093	118	
i 1	281.2402993197279	0.2525	77	614	4	4	14	17	0	2	17	0	0	4.0	118	
i 1	281.50344217687075	0.2525	77	228	5	24	1	16	0	2	16	0	0	5.114530660224938	118	
i 1	281.5097006802721	0.2525	72	228	7	5	14	0	0	-1	0	0	0	3.011193585509093	118	
i 1	281.73967346938775	1.01	69	930	5	5	1	0	0	0	0	0	0	3.011193585509093	118	
i 1	281.7578231292517	0.2525	69	228	7	5	6	1	5018	0	1	0	0	3.011193585509093	118	
i 1	282.0097006802721	2.02	74	930	6	2	8	16	0	1	16	0	0	4.0	118	
i 1	282.4871700680272	0.2525	74	228	7	1	12	16	5018	2	16	0	0	2.114530660224938	118	
i 1	282.5115782312925	0.2525	73	614	1	24	2	16	0	1	16	0	0	4.0	118	
i 1	282.5134557823129	0.7575000000000001	77	614	4	4	3	17	0	2	17	0	0	4.0	118	
i 1	282.98466666666667	4.04	61	930	5	25	3	9	0	1	9	0	0	8.084289819473728	118	
i 1	282.9871700680272	1.01	73	228	1	24	12	16	5018	1	16	0	0	4.0	118	
i 1	282.99655782312925	4.04	61	228	4	27	3	9	0	0	9	0	0	9.239188365112831	118	
i 1	283.01533333333333	8.08	61	228	5	26	2	9	5018	1	9	0	0	8.084289819473728	118	
i 1	283.2365442176871	0.2525	74	930	6	1	15	17	0	2	17	0	0	2.114530660224938	118	
i 1	283.23967346938775	0.2525	69	930	5	5	11	0	0	0	0	0	0	3.011193585509093	118	
i 1	283.25531972789116	0.2525	74	614	5	3	8	17	0	2	17	0	0	4.0	118	
i 1	283.2571972789116	0.2525	74	228	6	1	8	16	5018	2	16	0	0	2.114530660224938	118	
i 1	283.48466666666667	1.5150000000000001	74	930	6	2	13	17	0	2	17	0	0	4.0	118	
i 1	283.4852925170068	0.2525	74	228	6	9	12	17	5018	1	17	0	0	3.0	118	
i 1	283.4971836734694	0.505	69	228	7	5	6	0	0	0	0	0	0	3.011193585509093	118	
i 1	283.504693877551	0.505	77	228	5	24	14	16	0	2	16	0	0	5.114530660224938	118	
i 1	283.509074829932	0.2525	74	228	7	1	2	16	5018	1	16	0	0	2.114530660224938	118	
i 1	283.74468027210884	0.2525	73	614	1	24	7	17	0	2	17	0	0	4.0	118	
i 1	283.9971836734694	1.01	77	614	4	4	4	17	0	2	17	0	0	4.0	118	
i 1	284.00344217687075	0.505	77	228	5	4	9	16	0	1	16	0	0	4.0	118	
i 1	284.2521904761905	0.2525	69	614	5	5	12	0	0	-1	0	0	0	3.011193585509093	118	
i 1	284.2609523809524	0.505	69	228	5	5	7	1	5018	0	1	0	0	3.011193585509093	118	
i 1	284.5028163265306	0.2525	74	228	6	9	2	17	5018	1	17	0	0	3.0	118	
i 1	284.76032653061225	0.2525	69	614	5	5	1	1	0	0	1	0	0	3.011193585509093	118	
i 1	284.7615782312925	0.2525	69	930	5	5	15	0	0	0	0	0	0	3.011193585509093	118	
i 1	284.76533333333333	0.2525	73	228	1	24	16	16	5018	1	16	0	0	4.0	118	
i 1	284.9884217687075	2.02	77	614	4	4	3	17	0	2	17	0	0	4.0	119	
i 1	284.9902993197279	2.02	61	614	5	25	8	9	0	1	9	0	0	8.084289819473728	119	
i 1	284.9902993197279	2.02	66	228	4	27	1	6	0	1	6	0	0	9.239188365112831	119	
i 1	285.0065714285714	1.01	69	228	5	5	1	0	5018	0	0	0	0	3.011193585509093	119	
i 1	285.01032653061225	0.505	72	228	4	5	15	0	0	-1	0	0	0	3.011193585509093	119	
i 1	285.0115782312925	0.2525	74	228	6	1	8	16	5018	2	16	0	0	2.114530660224938	119	
i 1	285.01533333333333	0.2525	74	930	6	1	11	17	0	2	17	0	0	2.114530660224938	119	
i 1	285.24155102040817	0.505	74	228	6	1	8	16	0	2	16	0	0	2.114530660224938	119	
i 1	285.2478095238095	1.7675	77	930	6	1	1	16	0	2	16	0	0	2.114530660224938	119	
i 1	285.745306122449	0.2525	77	228	5	24	10	16	0	2	16	0	0	5.114530660224938	119	
i 1	285.75531972789116	0.7575000000000001	74	228	6	9	1	17	5018	1	17	0	0	3.0	119	
i 1	285.7559455782313	0.2525	74	614	5	3	14	17	0	2	17	0	0	4.0	119	
i 1	285.9865442176871	0.2525	69	614	5	5	15	0	0	-1	0	0	0	3.011193585509093	119	
i 1	285.995306122449	0.505	72	228	4	5	3	0	0	-1	0	0	0	3.011193585509093	119	
i 1	285.9990612244898	0.7575000000000001	74	930	6	2	9	16	0	1	16	0	0	4.0	119	
i 1	286.01032653061225	0.2525	74	228	6	1	13	16	5018	1	16	0	0	2.114530660224938	119	
i 1	286.01220408163266	0.2525	74	614	4	24	15	17	0	1	17	0	0	5.114530660224938	119	
i 1	286.4871700680272	0.2525	74	228	5	3	8	17	0	2	17	0	0	4.0	119	
i 1	286.4902993197279	0.505	74	228	6	1	10	16	5018	1	16	0	0	2.114530660224938	119	
i 1	286.5071972789116	0.2525	69	228	5	5	14	1	5018	0	1	0	0	3.011193585509093	119	
i 1	286.7528163265306	0.2525	69	614	5	5	10	0	0	-1	0	0	0	3.011193585509093	119	
i 1	286.76533333333333	0.2525	74	930	6	2	12	17	0	2	17	0	0	4.0	119	
i 1	286.9884217687075	6.0600000000000005	61	723	3	27	5	9	0	1	9	0	0	9.239188365112831	120	
i 1	286.9890476190476	2.02	61	1109	5	25	7	9	0	1	9	0	0	8.084289819473728	120	
i 1	286.99155102040817	4.04	61	1109	5	25	10	9	0	1	9	0	0	8.084289819473728	120	
i 1	286.9934285714286	6.0600000000000005	73	723	1	24	14	17	0	248	17	308	0	4.0	120	
i 1	286.9978095238095	7.575	66	723	3	27	5	9	0	0	9	0	0	9.239188365112831	120	
i 1	287.0009387755102	1.7675	69	1109	5	5	9	1	0	-1	1	0	0	3.011193585509093	120	
i 1	287.00156462585034	1.2625	73	228	1	24	6	16	5018	1	16	0	0	4.0	120	
i 1	287.0021904761905	6.0600000000000005	76	723	1	24	14	17	0	248	17	308	0	4.0	120	
i 1	287.0028163265306	6.0600000000000005	61	723	5	25	4	6	5019	1	6	0	0	8.084289819473728	120	
i 1	287.00344217687075	4.04	66	723	5	25	9	9	5019	0	9	0	0	8.084289819473728	120	
i 1	287.00531972789116	0.2525	74	228	6	1	7	16	5018	2	16	0	0	2.114530660224938	120	
i 1	287.0059455782313	2.7775	74	723	4	4	1	16	5019	2	16	0	0	4.0	120	
i 1	287.0071972789116	0.2525	77	228	6	9	12	17	5018	2	17	0	0	3.0	120	
i 1	287.74468027210884	0.2525	74	228	6	9	15	17	5018	1	17	0	0	3.0	120	
i 1	287.9928027210884	0.505	74	723	4	4	5	16	0	2	16	0	0	4.0	120	
i 1	287.99655782312925	0.2525	73	723	1	24	11	16	5019	2	16	0	0	4.0	120	
i 1	288.0115782312925	0.2525	72	723	5	5	1	0	5019	0	0	0	0	3.011193585509093	120	
i 1	288.2359183673469	0.2525	74	228	6	1	4	16	5018	2	16	0	0	2.114530660224938	120	
i 1	288.2540680272109	4.04	69	723	5	5	1	0	5019	0	0	0	0	3.011193585509093	120	
i 1	288.5109523809524	0.2525	74	1109	6	2	7	17	0	1	17	0	0	4.0	120	
i 1	288.7352925170068	0.2525	72	723	5	5	13	0	5019	0	0	0	0	3.011193585509093	120	
i 1	288.75156462585034	0.2525	77	723	5	3	1	17	5019	2	17	0	0	4.0	120	
i 1	288.76032653061225	0.2525	74	228	6	1	8	16	5018	1	16	0	0	2.114530660224938	120	
i 1	288.9865442176871	0.2525	73	228	1	24	9	16	5018	1	16	0	0	4.0	121	
i 1	289.00344217687075	0.2525	74	723	6	1	15	17	5019	2	17	0	0	2.114530660224938	121	
i 1	289.00344217687075	0.505	69	228	5	5	4	0	5018	0	0	0	0	3.011193585509093	121	
i 1	289.0065714285714	5.555	61	228	5	26	1	9	5018	0	9	0	0	8.084289819473728	121	
i 1	289.0097006802721	0.2525	77	1109	6	2	14	16	0	1	16	0	0	4.0	121	
i 1	289.01533333333333	4.04	61	1109	5	25	10	9	0	1	9	0	0	8.084289819473728	121	
i 1	289.245306122449	2.02	77	723	5	3	2	17	5019	2	17	0	0	4.0	121	
i 1	289.4996870748299	0.2525	69	228	5	5	9	1	5018	0	1	0	0	3.011193585509093	121	
i 1	289.5147074829932	3.535	74	723	6	1	13	17	5019	2	17	0	0	2.114530660224938	121	
i 1	289.7428027210884	0.2525	69	228	5	5	13	0	5018	0	0	0	0	3.011193585509093	121	
i 1	289.74468027210884	1.01	69	1109	5	5	4	1	0	-1	1	0	0	3.011193585509093	121	
i 1	289.7647074829932	0.7575000000000001	77	1109	6	2	6	16	0	1	16	0	0	4.0	121	
i 1	289.995306122449	0.7575000000000001	73	228	1	24	15	16	5018	1	16	0	0	4.0	122	
i 1	290.004693877551	0.2525	73	723	1	24	4	16	5019	2	16	0	0	4.0	122	
i 1	290.50156462585034	0.505	74	723	5	3	11	17	0	2	17	0	0	4.0	123	
i 1	290.7365442176871	0.505	69	228	5	5	15	0	5018	0	0	0	0	3.011193585509093	123	
i 1	290.745306122449	1.01	74	1109	6	2	11	17	0	1	17	0	0	4.0	123	
i 1	290.7628299319728	0.505	77	723	5	1	12	16	0	2	16	0	0	2.114530660224938	123	
i 1	290.995306122449	2.02	61	1109	5	25	11	9	0	1	9	0	0	8.084289819473728	123	
i 1	291.004693877551	4.04	66	723	5	25	11	9	5019	0	9	0	0	8.084289819473728	123	
i 1	291.0115782312925	3.535	61	228	5	26	8	9	5018	1	9	0	0	8.084289819473728	123	
i 1	291.23967346938775	1.7675	77	1109	6	2	1	16	0	1	16	0	0	4.0	123	
i 1	291.7352925170068	2.2725	77	723	4	24	8	16	5019	2	16	0	0	5.114530660224938	123	
i 1	291.7521904761905	2.525	69	1109	5	5	8	1	0	-1	1	0	0	3.011193585509093	123	
i 1	291.75531972789116	0.2525	77	228	6	9	4	17	5018	2	17	0	0	3.0	123	
i 1	291.9990612244898	0.2525	77	1109	6	1	2	16	0	2	16	0	0	2.114530660224938	123	
i 1	292.0140816326531	0.2525	74	1109	6	2	2	17	0	1	17	0	0	4.0	123	
i 1	292.2540680272109	0.2525	69	228	5	5	8	1	5018	0	1	0	0	3.011193585509093	123	
i 1	292.4959319727891	0.505	69	228	5	5	7	0	5018	0	0	0	0	3.011193585509093	123	
i 1	292.4971836734694	2.2725	74	723	4	4	2	16	5019	2	16	0	0	4.0	123	
i 1	292.7634557823129	0.505	69	228	5	5	3	1	5018	0	1	0	0	3.011193585509093	123	
i 1	293.0003129251701	0.505	74	228	6	1	9	16	5018	2	16	0	0	2.114530660224938	123	
i 1	293.0097006802721	1.5150000000000001	61	723	3	27	15	9	0	1	9	0	0	9.239188365112831	123	
i 1	293.01032653061225	0.2525	77	723	5	1	9	16	0	2	16	0	0	2.114530660224938	123	
i 1	293.0109523809524	1.5150000000000001	61	1109	5	25	4	9	0	1	9	0	0	8.084289819473728	123	
i 1	293.0109523809524	4.04	61	723	5	25	11	6	5019	1	6	0	0	8.084289819473728	123	
i 1	293.2352925170068	0.2525	73	228	1	20	1	16	5018	1	16	0	0	10.0	123	
i 1	293.2528163265306	0.2525	69	723	5	5	8	0	5019	0	0	0	0	3.011193585509093	123	
i 1	293.259074829932	1.2625	74	1109	6	1	13	17	0	1	17	0	0	2.114530660224938	123	
i 1	293.5140816326531	0.2525	69	228	5	5	11	1	5018	0	1	0	0	3.011193585509093	123	
i 1	293.7359183673469	0.2525	73	723	1	24	7	16	5019	2	16	0	0	14.0	123	
i 1	293.7496870748299	0.7575000000000001	69	1109	5	5	14	1	0	0	1	0	0	3.011193585509093	123	
i 1	293.7647074829932	0.2525	74	228	6	1	4	16	5018	1	16	0	0	2.114530660224938	123	
i 1	294.0040680272109	0.7575000000000001	74	723	6	1	6	17	5019	2	17	0	0	2.114530660224938	123	
i 1	294.0065714285714	0.2525	76	228	2	20	6	17	0	2	17	0	0	10.0	123	
i 1	294.0078231292517	0.2525	72	723	5	5	16	0	5019	0	0	0	0	3.011193585509093	123	
i 1	294.01220408163266	0.505	77	1109	6	2	15	16	0	1	16	0	0	4.0	123	
i 1	294.2371700680272	0.2525	69	723	5	5	10	0	5019	0	0	0	0	3.011193585509093	123	
i 1	294.4902993197279	4.04	66	390	3	27	13	9	0	1	9	0	0	9.239188365112831	124	
i 1	294.49468027210884	0.505	61	4	6	25	12	6	0	1	6	0	0	8.084289819473728	124	
i 1	294.4990612244898	1.7675	77	4	7	1	5	16	0	2	16	0	0	2.114530660224938	124	
i 1	294.5009387755102	2.525	61	4	5	26	4	9	0	1	9	0	0	8.084289819473728	124	
i 1	294.50844897959183	0.505	61	390	3	27	8	6	0	0	6	0	0	9.239188365112831	124	
i 1	294.5109523809524	0.505	61	4	5	26	7	9	0	1	9	0	0	8.084289819473728	124	
i 1	294.5140816326531	2.02	74	4	7	2	2	16	0	2	16	0	0	4.0	124	
i 1	294.745306122449	0.2525	76	4	3	20	5	16	0	1	16	0	0	10.0	124	
i 1	294.7578231292517	0.505	77	723	5	3	3	17	5019	2	17	0	0	4.0	124	
i 1	294.7597006802721	0.2525	76	4	3	20	7	16	0	2	16	0	0	10.0	124	
i 1	294.76220408163266	0.2525	73	4	1	20	6	17	0	2	17	0	0	10.0	124	
i 1	294.7647074829932	0.2525	74	4	7	2	11	16	0	1	16	0	0	4.0	124	
i 1	294.9871700680272	3.535	61	4	5	26	5	9	0	1	9	0	0	8.084289819473728	124	
i 1	294.9884217687075	0.2525	77	4	7	1	7	16	0	2	16	0	0	2.114530660224938	124	
i 1	294.9921768707483	3.535	61	390	3	27	2	6	0	0	6	0	0	9.239188365112831	124	
i 1	295.0078231292517	2.02	66	723	5	25	7	9	5019	0	9	0	0	8.084289819473728	124	
i 1	295.24155102040817	0.2525	77	4	6	9	5	17	0	2	17	0	0	3.0	124	
i 1	295.2640816326531	0.505	74	390	4	24	5	16	0	1	16	0	0	5.114530660224938	124	
i 1	295.50844897959183	0.2525	73	4	1	24	10	17	0	2	17	0	0	4.0	124	
i 1	295.5140816326531	0.2525	69	4	5	5	1	0	0	0	0	0	0	3.011193585509093	124	
i 1	295.7384217687075	0.505	77	390	4	4	2	16	0	1	16	0	0	4.0	124	
i 1	295.73967346938775	1.01	69	723	5	5	5	0	5019	0	0	0	0	3.011193585509093	124	
i 1	295.76533333333333	0.2525	74	390	5	1	14	16	0	1	16	0	0	2.114530660224938	124	
i 1	295.9928027210884	0.2525	69	390	4	5	13	0	0	0	0	0	0	3.011193585509093	124	
i 1	296.0028163265306	0.2525	77	723	4	24	6	16	5019	2	16	0	0	5.114530660224938	124	
i 1	296.2471836734694	2.2725	72	4	7	5	7	1	0	-1	1	0	0	3.011193585509093	124	
i 1	296.49655782312925	0.505	74	4	6	9	3	16	0	1	16	0	0	3.0	125	
i 1	296.5021904761905	0.2525	74	390	5	1	1	16	0	1	16	0	0	2.114530660224938	125	
i 1	296.76032653061225	0.2525	72	4	5	5	16	1	0	-1	1	0	0	3.011193585509093	125	
i 1	296.9902993197279	2.02	61	723	5	25	14	6	5019	1	6	0	0	8.084289819473728	125	
i 1	296.995306122449	0.2525	77	390	5	3	14	17	0	2	17	0	0	4.0	125	
i 1	297.00531972789116	1.5150000000000001	61	4	5	26	10	9	0	1	9	0	0	8.084289819473728	125	
i 1	297.2402993197279	0.2525	73	723	2	24	14	16	5019	1	16	0	0	4.0	125	
i 1	297.240925170068	1.2625	77	723	5	3	15	17	5019	2	17	0	0	4.0	125	
i 1	297.2421768707483	0.505	69	4	7	5	14	0	0	-1	0	0	0	3.011193585509093	125	
i 1	297.25156462585034	0.2525	77	4	7	1	13	16	0	2	16	0	0	2.114530660224938	125	
i 1	297.7578231292517	1.2625	69	723	5	5	2	0	5019	0	0	0	0	3.011193585509093	125	
i 1	297.7628299319728	0.2525	77	4	7	1	10	16	0	1	16	0	0	2.114530660224938	125	
i 1	297.9940544217687	0.2525	74	723	4	4	8	16	5019	2	16	0	0	4.0	125	
i 1	297.9978095238095	0.2525	77	723	4	24	11	16	5019	2	16	0	0	5.114530660224938	125	
i 1	298.0028163265306	0.2525	69	4	7	5	5	0	0	-1	0	0	0	3.011193585509093	125	
i 1	298.2509387755102	0.7575000000000001	74	723	6	1	15	17	5019	2	17	0	0	2.114530660224938	125	
i 1	298.25531972789116	0.505	74	4	7	2	16	16	0	2	16	0	0	4.0	125	
i 1	298.2634557823129	0.7575000000000001	72	723	5	5	8	0	5019	0	0	0	0	3.011193585509093	125	
i 1	298.490925170068	0.2525	74	4	5	4	9	16	0	2	16	0	0	4.0	126	
i 1	298.4928027210884	0.505	66	390	4	26	5	6	0	0	6	0	0	8.084289819473728	126	
i 1	298.4978095238095	0.2525	77	390	6	1	4	16	0	2	16	0	0	2.114530660224938	126	
i 1	298.5003129251701	0.505	61	4	4	27	13	9	0	1	9	0	0	9.239188365112831	126	
i 1	298.5078231292517	0.505	61	4	4	27	4	6	0	1	6	0	0	9.239188365112831	126	
i 1	298.5140816326531	0.2525	72	390	5	5	4	0	0	-1	0	0	0	3.011193585509093	126	
i 1	298.51533333333333	0.505	61	390	4	26	7	9	0	1	9	0	0	8.084289819473728	126	
i 1	298.98466666666667	0.7575000000000001	72	390	5	5	11	0	0	-1	0	0	0	3.021213419085008	126	
i 1	298.99655782312925	1.01	74	4	7	2	14	16	0	2	16	0	0	4.0	126	
i 1	299.0021904761905	1.01	76	4	1	24	12	16	5019	1	16	0	0	4.0	126	
i 1	299.00344217687075	1.01	69	723	6	5	1	0	5019	0	0	0	0	3.021213419085008	126	
i 1	299.0109523809524	0.2525	72	723	5	5	16	0	5019	0	0	0	0	3.021213419085008	126	
i 1	299.245306122449	0.7575000000000001	72	4	7	5	3	1	0	-1	1	0	0	3.021213419085008	126	
i 1	299.2540680272109	0.2525	77	4	6	3	1	17	0	2	17	0	0	4.0	126	
i 1	299.5128299319728	0.2525	77	390	5	9	16	16	0	2	16	0	0	3.0	127	
i 1	299.7365442176871	0.2525	74	723	4	4	15	16	5019	2	16	0	0	4.0	127	
i 1	299.74655782312925	0.2525	77	390	6	1	2	16	0	2	16	0	0	0.2698800808635933	127	
i 1	299.7565714285714	0.2525	69	4	7	5	2	0	0	-1	0	0	0	3.021213419085008	127	
i 1	299.9890476190476	0.505	72	203	7	2	7	1	0	-1	1	0	0	4.0	0	
i 1	299.9921768707483	0.2525	72	701	3	9	1	0	0	-1	0	0	0	3.0	0	
i 1	299.9934285714286	1.01	63	1087	3	13	1	1	0	2	1	0	0	3.5289577164302686	0	
i 1	300.0134557823129	7.575	61	203	6	14	4	1	0	1	1	0	0	5.293436574645402	0	
i 1	300.0147074829932	2.02	63	203	6	14	12	16	0	1	16	0	0	5.293436574645402	0	
i 1	300.2402993197279	0.2525	72	1087	4	4	10	0	0	-1	0	0	0	4.0	0	
i 1	300.2540680272109	0.2525	74	701	4	24	4	8	0	-2	8	0	0	3.0	0	
i 1	300.2615782312925	0.2525	74	203	7	5	13	8	0	-2	8	0	0	3.0	0	
i 1	300.50531972789116	1.5150000000000001	72	203	7	2	5	0	0	-1	0	0	0	4.0	0	
i 1	300.7540680272109	0.2525	73	203	1	20	10	8	0	-1	8	0	0	4.0	0	
i 1	300.9859183673469	0.2525	71	1087	6	5	1	8	0	-1	8	0	0	3.0	0	
i 1	301.0021904761905	3.0300000000000002	63	1087	5	13	3	1	0	2	1	0	0	3.5289577164302686	0	
i 1	301.2597006802721	0.505	71	701	6	5	10	2	0	-1	2	0	0	3.0	0	
i 1	302.0071972789116	5.555	63	203	6	14	5	16	0	1	16	0	0	5.293436574645402	1	
i 1	302.2352925170068	1.7675	71	1087	4	24	4	2	0	-1	2	0	0	3.0	1	
i 1	302.5065714285714	0.2525	74	701	6	5	10	2	0	-1	2	0	0	3.0	1	
i 1	302.5147074829932	0.2525	69	701	5	9	8	1	0	-1	1	0	0	3.0	1	
i 1	302.7597006802721	0.505	74	701	6	5	5	8	0	-1	8	0	0	3.0	1	
i 1	302.98466666666667	3.0300000000000002	63	1087	6	7	14	16	0	2	16	0	0	4.7052769552403575	2	
i 1	303.2559455782313	0.2525	71	701	6	5	8	2	0	-2	2	0	0	3.0	2	
i 1	303.5009387755102	0.7575000000000001	69	1087	5	3	15	1	0	-1	1	0	0	4.0	3	
i 1	303.7390476190476	0.2525	69	701	3	3	13	0	0	-1	0	0	0	4.0	3	
i 1	303.9852925170068	3.535	63	1087	5	13	2	1	0	2	1	0	0	3.5289577164302686	3	
i 1	304.2528163265306	0.505	74	203	7	5	5	8	0	-2	8	0	0	3.0	3	
i 1	304.2559455782313	0.2525	72	1087	4	4	15	0	0	-1	0	0	0	4.0	3	
i 1	304.5040680272109	0.2525	69	701	5	9	11	1	0	-1	1	0	0	3.0	3	
i 1	304.74655782312925	0.2525	74	701	6	5	11	8	0	-1	8	0	0	3.0	3	
i 1	305.01533333333333	0.2525	74	701	6	5	4	2	0	-1	2	0	0	3.0	3	
i 1	305.2371700680272	1.5150000000000001	72	203	7	2	15	0	0	-1	0	0	0	4.0	3	
i 1	305.49468027210884	0.2525	74	701	6	5	9	2	0	-1	2	0	0	3.0	3	
i 1	305.4971836734694	1.5150000000000001	71	203	7	5	10	8	0	-1	8	0	0	3.0	3	
i 1	305.5040680272109	0.2525	69	701	5	3	14	0	0	-1	0	0	0	4.0	3	
i 1	305.740925170068	0.2525	72	701	3	4	16	0	0	0	0	0	0	4.0	3	
i 1	305.7578231292517	0.505	71	701	6	5	16	2	0	-2	2	0	0	3.0	3	
i 1	306.2428027210884	0.2525	74	203	7	5	15	8	0	-2	8	0	0	3.0	3	
i 1	306.2578231292517	0.2525	72	203	7	2	15	1	0	-1	1	0	0	4.0	3	
i 1	306.9890476190476	0.2525	74	701	4	24	15	8	0	-2	8	0	0	3.0	3	
i 1	306.9996870748299	0.505	74	203	7	5	4	8	0	-2	8	0	0	3.0	3	
i 1	307.4884217687075	0.505	73	1081	2	24	15	8	0	-2	8	0	0	4.0	4	
i 1	307.49155102040817	2.525	61	695	5	14	11	16	0	1	16	0	0	5.293436574645402	4	
i 1	307.49655782312925	1.5150000000000001	72	695	6	2	16	1	0	0	1	0	0	4.0	4	
i 1	307.49655782312925	1.5150000000000001	71	379	6	5	6	8	0	-1	8	0	0	3.0	4	
i 1	307.49843537414966	0.505	71	1081	6	5	8	2	0	-1	2	0	0	3.0	4	
i 1	307.49843537414966	4.04	63	379	5	13	7	1	0	2	1	0	0	3.5289577164302686	4	
i 1	307.50531972789116	0.505	61	695	5	14	2	1	0	1	1	0	0	5.293436574645402	4	
i 1	308.00844897959183	5.05	73	1081	1	24	12	8	0	252	8	307	0	4.0	4	
i 1	308.0147074829932	5.05	61	695	5	14	11	1	0	1	1	0	0	5.293436574645402	4	
i 1	308.2352925170068	0.2525	73	379	1	24	16	2	0	-2	2	0	0	4.0	4	
i 1	308.2390476190476	0.2525	74	379	6	5	8	2	0	-2	2	0	0	3.0	4	
i 1	308.49468027210884	0.505	74	1081	6	5	7	2	0	-1	2	0	0	3.0	4	
i 1	308.9884217687075	0.505	69	379	4	4	15	0	0	0	0	0	0	4.0	4	
i 1	309.0021904761905	1.7675	74	695	6	5	16	2	0	-1	2	0	0	3.0	4	
i 1	309.26220408163266	0.2525	71	695	6	5	2	8	0	-2	8	0	0	3.0	4	
i 1	309.5028163265306	0.2525	72	379	4	4	1	0	0	-1	0	0	0	4.0	5	
i 1	309.5147074829932	1.2625	72	379	5	3	6	1	0	-1	1	0	0	4.0	5	
i 1	309.9865442176871	0.2525	71	695	6	5	8	8	0	-2	8	0	0	3.0	5	
i 1	309.9940544217687	3.0300000000000002	61	695	5	14	8	16	0	1	16	0	0	5.293436574645402	5	
i 1	310.00156462585034	0.2525	69	379	4	4	6	0	0	0	0	0	0	4.0	5	
i 1	310.2365442176871	1.2625	72	695	5	2	14	0	0	-1	0	0	0	4.0	5	
i 1	310.4978095238095	1.01	71	695	6	5	4	8	0	-2	8	0	0	3.0	5	
i 1	310.7428027210884	0.505	72	695	5	2	15	1	0	0	1	0	0	4.0	5	
i 1	310.75844897959183	0.2525	74	379	6	5	9	8	0	-2	8	0	0	3.0	5	
i 1	311.48967346938775	1.5150000000000001	71	695	6	5	5	8	0	-2	8	0	0	3.0	6	
i 1	311.4902993197279	0.505	63	695	5	13	5	16	0	1	16	0	0	3.5289577164302686	6	
i 1	311.5040680272109	2.525	61	695	6	7	11	16	0	1	16	0	0	4.7052769552403575	6	
i 1	311.98967346938775	0.2525	69	1081	5	9	4	0	0	0	0	0	0	3.0	6	
i 1	311.9978095238095	1.01	72	695	5	3	11	0	0	0	0	0	0	4.0	6	
i 1	312.0109523809524	7.07	63	695	5	13	3	16	0	1	16	0	0	3.5289577164302686	6	
i 1	312.2647074829932	0.505	69	379	5	3	1	1	0	-1	1	0	0	4.0	6	
i 1	312.7571972789116	0.2525	69	1081	5	9	10	0	0	0	0	0	0	3.0	7	
i 1	312.9865442176871	3.0300000000000002	70	197	1	24	8	8	0	252	8	307	0	4.0	8	
i 1	312.9884217687075	1.5150000000000001	72	899	5	2	2	0	0	0	0	0	0	4.0	8	
i 1	312.9934285714286	0.2525	74	197	3	24	3	8	0	-2	8	0	0	3.0	8	
i 1	313.0003129251701	9.09	63	899	5	14	6	1	0	1	1	0	0	5.293436574645402	8	
i 1	313.0021904761905	1.2625	73	197	1	24	12	8	0	252	8	307	0	4.0	8	
i 1	313.0059455782313	9.09	61	899	5	14	15	16	0	1	16	0	0	5.293436574645402	8	
i 1	313.0134557823129	1.5150000000000001	71	899	6	5	10	8	0	-1	8	0	0	3.0	8	
i 1	313.51032653061225	0.505	69	197	6	3	15	1	0	0	1	0	0	4.0	8	
i 1	313.9978095238095	0.2525	69	197	6	9	13	1	0	-1	1	0	0	3.0	8	
i 1	314.0059455782313	5.05	61	695	6	7	1	16	0	1	16	0	0	4.7052769552403575	8	
i 1	314.00844897959183	0.2525	74	899	4	5	14	8	0	-1	8	0	0	3.0	8	
i 1	314.2459319727891	0.2525	69	197	6	3	3	1	0	0	1	0	0	4.0	8	
i 1	314.2609523809524	1.7675	74	695	6	5	3	8	0	-2	8	0	0	3.0	8	
i 1	314.4859183673469	0.2525	74	197	6	5	12	8	0	-1	8	0	0	3.0	8	
i 1	314.5140816326531	0.7575000000000001	69	695	4	4	8	1	0	-1	1	0	0	4.0	8	
i 1	314.7597006802721	0.2525	74	197	6	5	4	8	0	-1	8	0	0	3.0	8	
i 1	315.0009387755102	1.2625	72	695	5	3	3	0	0	0	0	0	0	4.0	8	
i 1	315.24843537414966	0.2525	74	197	7	5	12	8	0	-1	8	0	0	3.0	8	
i 1	315.49155102040817	0.2525	69	899	5	2	11	1	0	0	1	0	0	4.0	8	
i 1	315.5071972789116	0.2525	74	695	4	24	16	8	0	-2	8	0	0	3.0	8	
i 1	315.7384217687075	0.2525	74	197	6	5	9	8	0	-1	8	0	0	3.0	8	
i 1	316.00156462585034	0.2525	74	197	7	5	4	8	0	-1	8	0	0	3.0	8	
i 1	316.00156462585034	6.0600000000000005	73	197	1	24	1	2	0	248	2	308	0	9.0	8	
i 1	316.004693877551	0.505	74	695	4	24	15	8	0	-2	8	0	0	3.0	8	
i 1	316.2528163265306	1.7675	69	899	5	2	6	1	0	0	1	0	0	4.0	8	
i 1	316.74655782312925	0.2525	73	197	1	24	16	8	0	-2	8	0	0	9.0	8	
i 1	316.76220408163266	0.2525	72	197	5	4	10	0	0	-1	0	0	0	4.0	8	
i 1	317.01032653061225	0.505	72	197	5	9	10	1	0	0	1	0	0	3.0	9	
i 1	317.2365442176871	0.505	73	899	1	20	15	8	0	-1	8	0	0	5.0	9	
i 1	317.25156462585034	0.2525	74	197	5	24	8	8	0	-2	8	0	0	3.0	9	
i 1	317.26032653061225	0.505	74	197	6	5	11	8	0	-1	8	0	0	3.0	9	
i 1	317.48779591836734	0.7575000000000001	72	899	5	2	9	0	0	0	0	0	0	4.0	9	
i 1	318.26533333333333	0.7575000000000001	74	695	4	24	12	8	0	-2	8	0	0	3.0	9	
i 1	318.4859183673469	0.505	71	899	4	5	3	8	0	-1	8	0	0	3.0	9	
i 1	318.51533333333333	0.2525	69	197	5	9	5	1	0	-1	1	0	0	3.0	9	
i 1	318.7503129251701	0.2525	73	899	1	20	13	8	0	-1	8	0	0	5.0	9	
i 1	318.7521904761905	1.2625	69	899	5	2	1	1	0	0	1	0	0	4.0	9	
i 1	318.9928027210884	3.0300000000000002	61	583	5	13	4	16	0	2	16	0	0	3.5289577164302686	10	
i 1	319.0059455782313	3.0300000000000002	63	583	6	7	4	1	0	1	1	0	0	4.7052769552403575	10	
i 1	319.254693877551	0.505	71	197	7	5	14	2	0	-1	2	0	0	3.0	10	
i 1	319.5059455782313	0.505	69	583	5	3	15	1	0	0	1	0	0	4.0	10	
i 1	319.5078231292517	3.0300000000000002	73	197	1	24	15	8	0	-2	8	0	0	9.0	10	
i 1	319.754693877551	0.505	69	583	4	4	13	1	0	0	1	0	0	4.0	10	
i 1	319.9990612244898	0.7575000000000001	69	899	6	2	3	1	0	0	1	0	0	4.0	10	
i 1	320.01533333333333	0.2525	71	197	7	5	16	2	0	-1	2	0	0	3.0	10	
i 1	320.2634557823129	1.7675	74	899	6	5	4	8	0	-1	8	0	0	3.0	10	
i 1	320.4959319727891	0.2525	74	197	6	5	16	8	0	-1	8	0	0	3.0	10	
i 1	320.5059455782313	0.2525	74	197	5	24	15	8	0	-2	8	0	0	3.0	10	
i 1	320.5065714285714	0.505	70	583	1	24	9	8	0	-1	8	0	0	9.0	10	
i 1	320.7540680272109	0.2525	71	197	7	5	3	2	0	-1	2	0	0	3.0	10	
i 1	321.0021904761905	0.505	74	197	5	24	9	8	0	-2	8	0	0	3.0	11	
i 1	321.00344217687075	0.7575000000000001	73	197	1	24	14	8	0	252	8	307	0	9.0	11	
i 1	321.004693877551	0.7575000000000001	70	197	1	20	3	8	0	-2	8	0	0	5.0	11	
i 1	321.26533333333333	0.505	74	197	6	5	8	8	0	-1	8	0	0	3.0	11	
i 1	321.4934285714286	0.2525	72	197	5	4	7	0	0	-1	0	0	0	4.0	11	
i 1	321.74155102040817	0.2525	74	197	5	24	12	8	0	-2	8	0	0	3.0	11	
i 1	321.745306122449	0.2525	70	899	1	20	10	2	0	-2	2	0	0	5.0	11	
i 1	321.9871700680272	0.505	73	197	1	20	2	2	0	-2	2	0	0	5.0	12	
i 1	321.9971836734694	1.5150000000000001	69	1081	4	2	10	0	0	0	0	0	0	4.0	12	
i 1	321.9971836734694	8.08	61	1081	5	14	2	16	0	1	16	0	0	5.293436574645402	12	
i 1	322.00344217687075	1.2625	71	695	4	5	12	2	0	-2	2	0	0	3.0	12	
i 1	322.0128299319728	4.545	63	695	5	13	3	1	0	2	1	0	0	3.5289577164302686	12	
i 1	322.0147074829932	8.08	63	1081	5	14	6	1	0	2	1	0	0	5.293436574645402	12	
i 1	322.995306122449	0.505	74	695	4	24	4	8	0	-1	8	0	0	3.0	13	
i 1	323.00156462585034	0.2525	69	695	4	3	5	0	0	0	0	0	0	4.0	13	
i 1	323.2359183673469	0.2525	73	197	1	20	13	2	0	-2	2	0	0	5.0	13	
i 1	323.73967346938775	0.505	74	695	6	5	2	2	0	-2	2	0	0	3.0	13	
i 1	323.9865442176871	0.2525	72	695	5	3	13	1	0	0	1	0	0	4.0	13	
i 1	324.2421768707483	0.2525	74	197	4	5	2	8	0	-1	8	0	0	3.0	13	
i 1	324.2471836734694	0.2525	70	197	1	20	15	2	0	-1	2	0	0	5.0	13	
i 1	324.5134557823129	0.505	74	695	4	24	15	8	0	-1	8	0	0	3.0	13	
i 1	324.7365442176871	0.505	71	695	4	5	4	2	0	-2	2	0	0	3.0	13	
i 1	324.745306122449	0.2525	73	197	1	24	4	8	0	-2	8	0	0	9.0	13	
i 1	324.754693877551	0.2525	74	695	6	5	5	2	0	-2	2	0	0	3.0	13	
i 1	325.2365442176871	0.2525	71	695	6	5	5	8	0	-1	8	0	0	3.0	13	
i 1	325.4852925170068	0.2525	71	197	4	5	3	2	0	-1	2	0	0	3.0	13	
i 1	325.490925170068	0.2525	71	695	4	5	2	2	0	-2	2	0	0	3.0	13	
i 1	326.0003129251701	0.505	72	695	4	3	8	1	0	0	1	0	0	4.0	13	
i 1	326.4934285714286	0.2525	74	583	4	24	11	2	0	-2	2	0	0	3.0	14	
i 1	326.4990612244898	2.02	63	583	5	13	16	1	0	1	1	0	0	3.5289577164302686	14	
i 1	326.50844897959183	2.02	63	583	6	7	6	1	0	1	1	0	0	4.7052769552403575	14	
i 1	326.51220408163266	0.2525	69	197	5	9	11	1	0	-1	1	0	0	3.0	14	
i 1	326.51220408163266	0.2525	73	197	1	24	9	8	0	-2	8	0	0	9.0	14	
i 1	326.7521904761905	1.2625	69	583	4	4	5	0	0	-1	0	0	0	4.0	14	
i 1	326.9859183673469	1.5150000000000001	74	1081	6	5	16	8	0	-2	8	0	0	3.0	14	
i 1	327.2578231292517	0.505	69	1081	4	2	5	0	0	0	0	0	0	4.0	14	
i 1	327.490925170068	0.2525	72	197	5	9	9	1	0	0	1	0	0	3.0	14	
i 1	327.745306122449	0.2525	69	1081	4	2	6	0	0	-1	0	0	0	4.0	14	
i 1	327.74655782312925	0.2525	69	695	4	3	7	0	0	0	0	0	0	4.0	14	
i 1	328.4884217687075	1.5150000000000001	63	379	5	13	6	16	0	1	16	0	0	3.5289577164302686	15	
i 1	328.4934285714286	0.2525	70	197	1	20	12	8	0	-2	8	0	0	5.0	15	
i 1	328.5040680272109	1.5150000000000001	63	379	6	7	16	16	0	2	16	0	0	4.7052769552403575	15	
i 1	328.7634557823129	0.2525	71	379	4	24	7	8	0	-2	8	0	0	3.0	15	
i 1	328.76533333333333	0.2525	73	379	1	24	5	2	0	-2	2	0	0	9.0	15	
i 1	328.995306122449	0.2525	74	695	4	24	8	8	0	-1	8	0	0	3.0	15	
i 1	329.0097006802721	0.2525	74	695	3	5	5	2	0	-2	2	0	0	3.0	15	
i 1	329.01220408163266	0.2525	74	197	4	5	11	8	0	-1	8	0	0	3.0	15	
i 1	329.0140816326531	1.01	73	197	1	20	13	2	0	-1	2	0	0	5.0	15	
i 1	329.26032653061225	0.505	74	695	3	5	13	2	0	-1	2	0	0	3.0	15	
i 1	329.5078231292517	0.505	69	1081	4	2	7	0	0	0	0	0	0	4.0	15	
i 1	329.5115782312925	0.505	71	379	4	24	11	8	0	-2	8	0	0	3.0	15	
i 1	329.740925170068	0.2525	74	1081	6	5	3	8	0	-1	8	0	0	3.0	15	
i 1	329.98466666666667	0.505	63	695	4	19	1	1	0	2	1	0	0	5.290431105685503	15	
i 1	329.98466666666667	0.505	70	1081	1	20	12	2	0	-1	2	0	0	5.0	15	
i 1	329.9859183673469	0.2525	74	197	6	1	9	2	0	-2	2	0	0	0.488354119971917	15	
i 1	329.9859183673469	0.2525	69	197	6	9	7	1	0	-1	1	0	0	3.0	15	
i 1	329.9871700680272	0.505	61	1081	5	14	15	16	0	1	16	0	0	6.933713913664838	15	
i 1	329.9884217687075	0.505	63	379	5	13	15	16	0	1	16	0	0	5.169235055449704	15	
i 1	329.9928027210884	0.505	63	379	6	17	10	16	0	2	16	0	0	5.290431105685503	15	
i 1	329.99468027210884	0.505	63	1081	6	17	12	16	0	1	16	0	0	5.290431105685503	15	
i 1	329.99468027210884	0.505	63	379	6	7	7	16	0	2	16	0	0	6.345554294259793	15	
i 1	329.9978095238095	0.505	63	695	1	27	5	1	0	252	1	307	0	1.154898545639104	15	
i 1	329.9996870748299	0.505	69	1081	6	2	10	0	0	0	0	0	0	4.0	15	
i 1	330.0009387755102	0.2525	69	379	4	3	12	0	0	-1	0	0	0	4.0	15	
i 1	330.00156462585034	2.02	61	197	5	18	13	1	0	2	1	0	0	5.290431105685503	15	
i 1	330.0021904761905	0.2525	74	379	6	5	5	8	0	-1	8	0	0	3.0065128918243444	15	
i 1	330.004693877551	2.02	63	197	5	18	3	16	0	1	16	0	0	5.290431105685503	15	
i 1	330.0071972789116	0.505	63	379	6	17	3	1	0	2	1	0	0	5.290431105685503	15	
i 1	330.00844897959183	0.505	61	695	4	19	5	16	0	1	16	0	0	5.290431105685503	15	
i 1	330.00844897959183	0.505	63	1081	5	14	12	1	0	2	1	0	0	6.933713913664838	15	
i 1	330.0109523809524	0.505	63	1081	6	17	1	16	0	2	16	0	0	5.290431105685503	15	
i 1	330.0128299319728	0.505	61	695	1	27	16	1	0	252	1	307	0	1.154898545639104	15	
i 1	330.245306122449	0.2525	71	379	6	5	6	8	0	-1	8	0	0	3.0065128918243444	15	
i 1	330.2496870748299	0.2525	74	197	6	5	9	8	0	-1	8	0	0	3.0065128918243444	15	
i 1	330.4902993197279	1.5150000000000001	74	583	4	24	11	2	0	-2	2	0	0	3.488354119971917	16	
i 1	330.4902993197279	5.555	61	899	6	17	6	16	0	1	16	0	0	5.290431105685503	16	
i 1	330.4934285714286	3.535	61	899	6	17	11	16	0	2	16	0	0	5.290431105685503	16	
i 1	330.495306122449	7.575	63	583	6	7	8	16	0	1	16	0	0	6.345554294259793	16	
i 1	330.4959319727891	7.575	61	583	6	17	14	1	0	1	1	0	0	5.290431105685503	16	
i 1	330.4959319727891	7.575	63	583	6	17	8	1	0	1	1	0	0	5.290431105685503	16	
i 1	330.4971836734694	1.7675	71	899	6	5	13	2	0	-2	2	0	0	3.0065128918243444	16	
i 1	330.4978095238095	3.535	63	899	5	14	5	16	0	2	16	0	0	6.933713913664838	16	
i 1	330.5040680272109	0.7575000000000001	71	899	4	1	5	2	0	-1	2	0	0	0.488354119971917	16	
i 1	330.5059455782313	1.5150000000000001	61	197	1	27	6	1	0	252	1	307	0	1.154898545639104	16	
i 1	330.5059455782313	0.2525	73	197	1	20	7	2	0	-2	2	0	0	5.0	16	
i 1	330.50844897959183	5.555	61	583	5	13	12	1	0	2	1	0	0	5.169235055449704	16	
i 1	330.51032653061225	1.5150000000000001	63	197	5	19	12	16	0	2	16	0	0	5.290431105685503	16	
i 1	330.5109523809524	1.5150000000000001	63	197	5	19	1	1	0	1	1	0	0	5.290431105685503	16	
i 1	330.5109523809524	1.5150000000000001	63	899	5	14	1	1	0	1	1	0	0	6.933713913664838	16	
i 1	330.5115782312925	0.505	74	899	6	5	9	8	0	-1	8	0	0	3.0065128918243444	16	
i 1	330.7540680272109	0.2525	74	197	6	1	7	2	0	-2	2	0	0	0.488354119971917	16	
i 1	330.9852925170068	0.2525	73	197	1	20	1	8	0	-1	8	0	0	5.0	16	
i 1	331.0109523809524	0.505	74	583	6	5	12	8	0	-2	8	0	0	3.0065128918243444	16	
i 1	331.2490612244898	0.2525	69	583	4	3	7	0	0	0	0	0	0	4.0	16	
i 1	331.2647074829932	0.2525	71	197	6	1	2	2	0	-1	2	0	0	0.488354119971917	16	
i 1	331.26533333333333	0.505	70	197	1	20	9	8	0	-2	8	0	0	5.0	16	
i 1	331.48779591836734	0.2525	72	197	4	9	12	1	0	0	1	0	0	3.0	17	
i 1	331.5009387755102	0.2525	71	197	3	5	13	2	0	-1	2	0	0	3.0065128918243444	17	
i 1	331.7402993197279	0.2525	73	197	1	24	6	8	0	-2	8	0	0	9.0	17	
i 1	331.7478095238095	1.2625	74	583	6	5	11	8	0	-2	8	0	0	3.0065128918243444	17	
i 1	331.7578231292517	1.7675	74	583	4	1	5	2	0	-1	2	0	0	0.488354119971917	17	
i 1	331.99155102040817	6.0600000000000005	70	196	1	24	1	8	0	252	8	307	0	9.0	18	
i 1	331.99155102040817	6.0600000000000005	63	899	4	14	13	1	0	1	1	0	0	6.933713913664838	18	
i 1	331.9928027210884	0.2525	72	1165	4	9	5	1	0	-1	1	0	0	3.0	18	
i 1	331.9928027210884	6.0600000000000005	61	196	5	19	9	1	0	1	1	0	0	5.290431105685503	18	
i 1	331.9940544217687	6.0600000000000005	63	196	4	27	9	16	0	1	16	0	0	1.154898545639104	18	
i 1	331.9959319727891	6.0600000000000005	61	1165	4	18	14	1	0	1	1	0	0	5.290431105685503	18	
i 1	332.0097006802721	6.0600000000000005	61	1165	4	18	13	16	0	1	16	0	0	5.290431105685503	18	
i 1	332.0097006802721	6.0600000000000005	61	196	5	19	2	16	0	1	16	0	0	5.290431105685503	18	
i 1	332.01220408163266	1.01	70	1165	1	20	12	2	0	-2	2	0	0	5.0	18	
i 1	332.2352925170068	1.7675	72	583	4	4	16	0	0	0	0	0	0	4.0	18	
i 1	332.26220408163266	0.2525	71	899	4	1	6	8	0	-1	8	0	0	0.488354119971917	18	
i 1	332.4934285714286	0.2525	74	196	3	5	12	8	0	-2	8	0	0	3.0065128918243444	18	
i 1	332.74468027210884	0.2525	70	583	1	24	8	8	0	-1	8	0	0	9.0	18	
i 1	332.7528163265306	0.2525	72	1165	4	9	8	1	0	-1	1	0	0	3.0	18	
i 1	332.75844897959183	0.2525	70	899	1	20	10	2	0	-2	2	0	0	5.0	18	
i 1	332.76032653061225	0.505	74	899	6	5	5	8	0	-1	8	0	0	3.0065128918243444	18	
i 1	332.9890476190476	0.2525	72	196	6	3	7	0	0	0	0	0	0	4.0	18	
i 1	333.0028163265306	0.2525	71	196	5	24	9	8	0	-2	8	0	0	3.488354119971917	18	
i 1	333.0140816326531	0.2525	74	1165	6	5	8	8	0	-2	8	0	0	3.0065128918243444	18	
i 1	333.2371700680272	0.2525	71	1165	6	5	3	2	0	-2	2	0	0	3.0065128918243444	18	
i 1	333.2471836734694	0.2525	72	1165	4	9	16	1	0	-1	1	0	0	3.0	18	
i 1	333.2640816326531	0.2525	71	196	5	5	6	2	0	-2	2	0	0	3.0065128918243444	18	
i 1	333.4884217687075	0.505	69	583	4	3	10	0	0	0	0	0	0	4.0	18	
i 1	333.4934285714286	0.2525	71	196	5	24	11	8	0	-2	8	0	0	3.488354119971917	18	
i 1	333.4990612244898	0.505	72	196	4	4	3	0	0	0	0	0	0	4.0	18	
i 1	333.504693877551	0.2525	71	899	4	1	10	8	0	-1	8	0	0	0.488354119971917	18	
i 1	333.7421768707483	0.2525	74	1165	6	1	11	2	0	-2	2	0	0	0.488354119971917	18	
i 1	333.7628299319728	0.7575000000000001	74	583	4	1	16	2	0	-1	2	0	0	0.488354119971917	18	
i 1	333.98779591836734	4.04	63	899	4	14	6	16	0	2	16	0	0	6.933713913664838	18	
i 1	333.99468027210884	1.5150000000000001	69	583	5	3	11	0	0	0	0	0	0	4.0	18	
i 1	333.9978095238095	4.04	63	196	4	27	10	16	0	1	16	0	0	1.154898545639104	18	
i 1	334.0009387755102	0.2525	72	196	3	3	7	0	0	0	0	0	0	4.0	18	
i 1	334.00156462585034	0.2525	72	899	6	2	2	0	0	-1	0	0	0	4.0	18	
i 1	334.00344217687075	0.2525	73	899	1	20	5	8	0	-2	8	0	0	5.0	18	
i 1	334.004693877551	4.04	61	899	5	17	16	16	0	2	16	0	0	5.290431105685503	18	
i 1	334.0134557823129	1.2625	71	899	6	1	14	2	0	-1	2	0	0	0.488354119971917	18	
i 1	334.2384217687075	2.02	74	899	5	5	15	8	0	-1	8	0	0	3.0065128918243444	18	
i 1	334.2647074829932	0.7575000000000001	70	1165	1	24	1	8	0	-1	8	0	0	9.0	18	
i 1	334.4902993197279	0.2525	74	583	6	5	15	2	0	-1	2	0	0	3.0065128918243444	18	
i 1	334.4971836734694	0.505	74	196	5	5	9	8	0	-2	8	0	0	3.0065128918243444	18	
i 1	334.50344217687075	2.2725	72	899	6	2	14	0	0	-1	0	0	0	4.0	18	
i 1	334.7521904761905	0.2525	74	1165	6	1	15	2	0	-2	2	0	0	0.488354119971917	18	
i 1	334.9978095238095	0.505	70	1165	1	24	8	8	0	252	8	307	0	9.0	18	
i 1	334.99843537414966	0.2525	72	196	5	4	1	0	0	0	0	0	0	4.0	18	
i 1	335.01220408163266	0.2525	74	583	6	5	3	2	0	-1	2	0	0	3.0065128918243444	18	
i 1	335.2471836734694	0.505	74	196	5	1	6	2	0	-1	2	0	0	0.488354119971917	18	
i 1	335.259074829932	0.2525	74	196	5	5	9	8	0	-2	8	0	0	3.0065128918243444	18	
i 1	335.50531972789116	1.7675	70	1165	1	24	6	8	0	-1	8	0	0	9.0	18	
i 1	335.74843537414966	0.2525	74	1165	6	1	14	2	0	-2	2	0	0	0.488354119971917	18	
i 1	335.75531972789116	0.2525	72	1165	4	9	14	1	0	-1	1	0	0	3.0	18	
i 1	335.7634557823129	0.505	71	196	5	24	8	8	0	-2	8	0	0	3.488354119971917	18	
i 1	335.990925170068	0.505	71	899	6	1	15	8	0	-1	8	0	0	0.488354119971917	19	
i 1	335.995306122449	1.5150000000000001	74	583	4	1	10	2	0	-1	2	0	0	0.488354119971917	19	
i 1	335.9971836734694	2.02	61	583	4	13	15	1	0	2	1	0	0	5.169235055449704	19	
i 1	336.0021904761905	0.2525	70	583	1	24	4	2	0	-1	2	0	0	9.0	19	
i 1	336.0078231292517	1.2625	71	899	5	5	1	2	0	-2	2	0	0	3.0065128918243444	19	
i 1	336.01032653061225	2.02	61	899	5	17	6	16	0	1	16	0	0	5.290431105685503	19	
i 1	336.240925170068	0.2525	72	1165	4	9	14	1	0	-1	1	0	0	3.0	19	
i 1	336.4871700680272	0.2525	74	1165	4	1	3	2	0	-2	2	0	0	0.488354119971917	19	
i 1	336.7352925170068	0.2525	71	899	6	1	10	8	0	-1	8	0	0	0.488354119971917	19	
i 1	336.7440544217687	0.505	72	196	3	4	14	0	0	0	0	0	0	4.0	19	
i 1	336.754693877551	0.2525	71	1165	6	5	10	2	0	-2	2	0	0	3.0065128918243444	19	
i 1	336.7615782312925	1.2625	74	583	6	5	10	8	0	-2	8	0	0	3.0065128918243444	19	
i 1	336.7634557823129	0.2525	72	196	3	3	12	0	0	0	0	0	0	4.0	19	
i 1	337.004693877551	0.505	73	583	1	24	13	2	0	-2	2	0	0	9.0	19	
i 1	337.23466666666667	0.2525	74	196	5	5	7	8	0	-2	8	0	0	3.0065128918243444	19	
i 1	337.2434285714286	0.2525	74	1165	6	5	11	8	0	-2	8	0	0	3.0065128918243444	19	
i 1	337.25344217687075	0.7575000000000001	70	1165	1	20	7	2	0	-2	2	0	0	5.0	19	
i 1	337.5003129251701	0.505	70	1165	4	20	16	8	0	-1	8	0	0	5.0	19	
i 1	337.5097006802721	0.505	72	899	6	2	5	0	0	-1	0	0	0	4.0	19	
i 1	337.9859183673469	2.02	61	197	6	17	8	1	0	1	1	0	0	5.290431105685503	20	
i 1	337.9859183673469	4.04	63	1081	4	18	8	1	0	1	1	0	0	5.290431105685503	20	
i 1	337.9865442176871	0.2525	71	695	4	5	9	8	0	-2	8	0	0	3.0065128918243444	20	
i 1	337.9902993197279	8.08	61	695	4	19	9	16	0	1	16	0	0	5.290431105685503	20	
i 1	337.9902993197279	6.0600000000000005	63	695	3	27	7	1	0	2	1	0	0	1.154898545639104	20	
i 1	337.9921768707483	10.1	63	695	5	17	9	16	0	2	16	0	0	5.290431105685503	20	
i 1	337.9928027210884	6.0600000000000005	61	1081	4	18	6	16	0	2	16	0	0	5.290431105685503	20	
i 1	337.9978095238095	2.02	63	695	3	27	15	16	0	2	16	0	0	1.154898545639104	20	
i 1	337.9990612244898	12.120000000000001	61	197	4	13	16	1	0	1	1	0	0	5.169235055449704	20	
i 1	338.0009387755102	10.1	63	695	4	14	7	16	0	1	16	0	0	6.933713913664838	20	
i 1	338.0021904761905	8.08	61	695	4	14	12	16	0	1	16	0	0	6.933713913664838	20	
i 1	338.0028163265306	1.7675	74	695	6	1	16	8	0	-1	8	0	0	0.488354119971917	20	
i 1	338.00531972789116	10.1	61	695	4	19	7	1	0	1	1	0	0	5.290431105685503	20	
i 1	338.0109523809524	0.2525	70	1081	3	20	8	2	0	-1	2	0	0	5.0	20	
i 1	338.0115782312925	8.08	61	695	5	17	1	1	0	2	1	0	0	5.290431105685503	20	
i 1	338.0128299319728	12.120000000000001	63	197	5	17	7	16	0	1	16	0	0	5.290431105685503	20	
i 1	338.2365442176871	0.505	71	1081	3	1	10	8	0	-1	8	0	0	0.488354119971917	20	
i 1	338.25844897959183	0.505	71	1081	5	5	7	2	0	-1	2	0	0	3.0065128918243444	20	
i 1	338.4852925170068	0.2525	70	695	4	20	8	8	0	-2	8	0	0	5.0	20	
i 1	338.7509387755102	0.2525	71	197	5	5	9	2	0	-2	2	0	0	3.0065128918243444	20	
i 1	338.7521904761905	1.01	73	1081	3	20	5	8	0	-1	8	0	0	5.0	20	
i 1	338.75531972789116	0.505	71	695	5	5	8	2	0	-1	2	0	0	3.0065128918243444	20	
i 1	339.00531972789116	0.2525	71	1081	3	1	1	2	0	-2	2	0	0	0.488354119971917	20	
i 1	339.2365442176871	0.7575000000000001	71	197	4	24	9	2	0	-2	2	0	0	3.488354119971917	20	
i 1	339.2471836734694	0.505	71	695	4	24	8	2	0	-1	2	0	0	3.488354119971917	20	
i 1	339.4934285714286	0.2525	73	1081	3	20	7	8	0	-1	8	0	0	5.0	20	
i 1	339.7352925170068	0.2525	71	695	4	1	5	8	0	-1	8	0	0	0.488354119971917	20	
i 1	339.73967346938775	0.2525	71	197	7	1	8	2	0	-1	2	0	0	0.488354119971917	20	
i 1	339.73967346938775	0.2525	70	695	4	20	10	2	0	-1	2	0	0	5.0	20	
i 1	339.9865442176871	0.2525	71	1081	3	1	4	8	0	-1	8	0	0	0.488354119971917	21	
i 1	339.9996870748299	6.0600000000000005	63	695	3	27	15	16	0	2	16	0	0	1.154898545639104	21	
i 1	340.00156462585034	0.505	69	695	2	3	7	1	0	-1	1	0	0	4.0	21	
i 1	340.01032653061225	11.11	61	197	5	17	4	1	0	1	1	0	0	5.290431105685503	21	
i 1	340.0109523809524	1.01	71	197	5	24	1	2	0	-2	2	0	0	3.488354119971917	21	
i 1	340.01533333333333	0.505	71	1081	3	1	5	2	0	-2	2	0	0	0.488354119971917	21	
i 1	340.50531972789116	1.5150000000000001	71	197	7	1	6	2	0	-1	2	0	0	0.488354119971917	21	
i 1	340.509074829932	0.505	71	1081	3	1	10	8	0	-1	8	0	0	0.488354119971917	21	
i 1	340.51533333333333	0.2525	69	1081	5	9	3	1	0	-1	1	0	0	3.0	21	
i 1	340.75844897959183	0.7575000000000001	74	695	5	5	10	2	0	-1	2	0	0	3.0065128918243444	21	
i 1	340.7609523809524	0.505	69	695	2	4	3	1	0	-1	1	0	0	4.0	21	
i 1	340.7628299319728	1.2625	73	695	2	24	13	2	0	-2	2	0	0	4.0	21	
i 1	341.23779591836734	0.2525	71	197	5	5	8	2	0	-2	2	0	0	3.0065128918243444	22	
i 1	341.9871700680272	9.09	63	1081	4	18	1	1	0	1	1	0	0	5.290431105685503	23	
i 1	342.0071972789116	0.505	71	197	4	1	13	2	0	-1	2	0	0	0.488354119971917	23	
i 1	342.259074829932	0.505	71	695	2	24	10	2	0	-1	2	0	0	3.488354119971917	23	
i 1	342.26533333333333	0.505	71	197	5	5	8	2	0	-2	2	0	0	3.0065128918243444	23	
i 1	342.4921768707483	0.505	71	1081	3	1	14	2	0	-2	2	0	0	0.488354119971917	23	
i 1	342.76533333333333	0.505	71	1081	6	1	6	8	0	-1	8	0	0	0.488354119971917	23	
i 1	343.0040680272109	0.2525	69	695	4	3	15	1	0	-1	1	0	0	4.0	23	
i 1	343.004693877551	0.505	71	695	2	24	5	2	0	-1	2	0	0	3.488354119971917	23	
i 1	343.0059455782313	0.505	69	197	5	4	15	1	0	-1	1	0	0	4.0	23	
i 1	343.2565714285714	0.2525	71	197	4	1	9	2	0	-1	2	0	0	0.488354119971917	23	
i 1	343.2571972789116	0.505	69	1081	5	9	12	1	0	-1	1	0	0	3.0	23	
i 1	343.26032653061225	1.01	73	1081	3	24	10	8	0	-2	8	0	0	4.0	23	
i 1	343.5109523809524	1.5150000000000001	74	695	4	1	14	8	0	-1	8	0	0	0.488354119971917	23	
i 1	343.7628299319728	0.505	69	197	5	4	8	1	0	-1	1	0	0	4.0	23	
i 1	344.0134557823129	7.07	61	1081	4	18	11	16	0	2	16	0	0	5.290431105685503	23	
i 1	344.0147074829932	2.02	63	695	3	27	8	1	0	2	1	0	0	1.154898545639104	23	
i 1	344.4940544217687	1.01	71	1081	4	5	1	2	0	-1	2	0	0	3.0065128918243444	23	
i 1	344.5028163265306	0.2525	71	1081	6	1	7	2	0	-2	2	0	0	0.488354119971917	23	
i 1	344.5028163265306	0.2525	69	695	6	2	4	0	0	-1	0	0	0	4.0	23	
i 1	344.9978095238095	0.2525	71	695	4	5	9	8	0	-2	8	0	0	3.0065128918243444	23	
i 1	345.4871700680272	0.505	74	695	5	5	16	2	0	-1	2	0	0	3.0065128918243444	24	
i 1	345.4902993197279	2.2725	72	197	6	3	1	0	0	-1	0	0	0	4.0	24	
i 1	345.4934285714286	0.505	71	695	2	24	2	2	0	-1	2	0	0	3.488354119971917	24	
i 1	345.7490612244898	0.2525	71	695	4	5	6	8	0	-2	8	0	0	3.0065128918243444	24	
i 1	345.98466666666667	0.2525	71	197	4	24	14	2	0	-2	2	0	0	3.488354119971917	24	
i 1	345.98466666666667	5.05	61	695	3	19	7	16	0	1	16	0	0	5.290431105685503	24	
i 1	345.9940544217687	5.05	61	695	6	17	11	1	0	2	1	0	0	5.290431105685503	24	
i 1	345.995306122449	0.2525	71	1081	3	1	15	8	0	-1	8	0	0	0.488354119971917	24	
i 1	345.99655782312925	0.2525	71	197	5	5	5	2	0	-2	2	0	0	3.0065128918243444	24	
i 1	345.99843537414966	5.05	61	695	5	14	3	16	0	1	16	0	0	6.933713913664838	24	
i 1	346.0003129251701	2.02	63	695	3	27	6	16	0	2	16	0	0	1.154898545639104	24	
i 1	346.0109523809524	2.2725	70	695	2	24	13	8	0	-1	8	0	0	4.0	24	
i 1	346.25844897959183	0.2525	71	695	4	1	6	8	0	-1	8	0	0	0.488354119971917	24	
i 1	346.2609523809524	0.2525	71	197	4	1	1	2	0	-1	2	0	0	0.488354119971917	24	
i 1	346.48466666666667	0.2525	71	1081	4	5	4	2	0	-1	2	0	0	3.0065128918243444	24	
i 1	346.5097006802721	0.2525	71	695	3	5	4	8	0	-2	8	0	0	3.0065128918243444	24	
i 1	346.7434285714286	1.5150000000000001	71	695	5	5	1	2	0	-1	2	0	0	3.0065128918243444	24	
i 1	346.7459319727891	0.2525	71	695	4	1	16	8	0	-1	8	0	0	0.488354119971917	24	
i 1	346.75344217687075	0.2525	71	197	4	1	1	2	0	-1	2	0	0	0.488354119971917	24	
i 1	347.0021904761905	2.2725	71	197	4	24	3	2	0	-2	2	0	0	3.488354119971917	24	
i 1	347.0028163265306	0.2525	72	695	6	2	14	0	0	-1	0	0	0	4.0	24	
i 1	347.2578231292517	0.505	71	1081	4	5	3	2	0	-1	2	0	0	3.0065128918243444	24	
i 1	347.26220408163266	0.2525	74	1081	4	5	8	8	0	-1	8	0	0	3.0065128918243444	24	
i 1	347.2647074829932	0.2525	69	1081	5	9	5	0	0	0	0	0	0	3.0	24	
i 1	347.4871700680272	0.2525	69	197	5	4	16	1	0	-1	1	0	0	4.0	25	
i 1	347.4971836734694	0.2525	71	1081	3	1	10	8	0	-1	8	0	0	0.488354119971917	25	
i 1	347.4971836734694	0.505	74	695	5	5	11	2	0	-1	2	0	0	3.0065128918243444	25	
i 1	347.7521904761905	0.2525	74	197	5	5	4	8	0	-1	8	0	0	3.0065128918243444	25	
i 1	347.7647074829932	0.2525	71	695	5	1	10	8	0	-2	8	0	0	0.488354119971917	25	
i 1	347.9971836734694	3.0300000000000002	63	695	5	14	9	16	0	1	16	0	0	6.933713913664838	25	
i 1	347.99843537414966	3.0300000000000002	63	695	6	17	14	16	0	2	16	0	0	5.290431105685503	25	
i 1	348.00156462585034	2.2725	73	695	2	24	15	8	0	-2	8	0	0	4.0	25	
i 1	348.00531972789116	3.0300000000000002	61	695	3	19	9	1	0	1	1	0	0	5.290431105685503	25	
i 1	348.00844897959183	2.02	74	695	6	5	13	2	0	-1	2	0	0	3.0065128918243444	25	
i 1	348.009074829932	0.2525	72	197	6	3	9	0	0	-1	0	0	0	4.0	25	
i 1	348.2434285714286	0.7575000000000001	69	695	4	3	14	1	0	-1	1	0	0	4.0	25	
i 1	348.2503129251701	2.525	74	695	4	1	8	8	0	-1	8	0	0	0.488354119971917	25	
i 1	348.2503129251701	0.2525	74	197	5	5	16	8	0	-1	8	0	0	3.0065128918243444	25	
i 1	348.26032653061225	0.2525	69	1081	5	9	3	0	0	0	0	0	0	3.0	25	
i 1	348.26220408163266	0.505	71	197	4	1	14	2	0	-1	2	0	0	0.488354119971917	25	
i 1	348.48967346938775	0.505	71	695	3	5	6	8	0	-2	8	0	0	3.0065128918243444	25	
i 1	348.4934285714286	0.7575000000000001	70	695	2	24	5	2	0	-2	2	0	0	4.0	25	
i 1	348.5109523809524	0.2525	69	695	4	4	5	1	0	-1	1	0	0	4.0	25	
i 1	348.740925170068	0.2525	71	695	3	5	15	2	0	-2	2	0	0	3.0065128918243444	25	
i 1	348.74843537414966	0.2525	71	695	4	24	16	2	0	-1	2	0	0	3.488354119971917	25	
i 1	348.7609523809524	2.2725	69	197	5	4	14	1	0	-1	1	0	0	4.0	25	
i 1	348.9921768707483	0.2525	71	1081	4	5	7	2	0	-1	2	0	0	3.0065128918243444	25	
i 1	349.0003129251701	1.2625	73	695	2	24	15	8	0	-2	8	0	0	4.0	25	
i 1	349.0028163265306	0.2525	71	1081	3	1	16	2	0	-2	2	0	0	0.488354119971917	25	
i 1	349.0059455782313	0.2525	72	695	6	2	9	0	0	-1	0	0	0	4.0	25	
i 1	349.23967346938775	0.2525	69	1081	5	9	7	1	0	-1	1	0	0	3.0	25	
i 1	349.75844897959183	0.505	71	695	3	5	13	2	0	-2	2	0	0	3.0065128918243444	26	
i 1	349.7647074829932	1.2625	73	1081	3	24	7	8	0	-2	8	0	0	4.0	26	
i 1	349.995306122449	1.01	61	197	6	13	11	1	0	1	1	0	0	5.169235055449704	26	
i 1	350.0065714285714	1.01	63	197	7	17	14	16	0	1	16	0	0	5.290431105685503	26	
i 1	350.2359183673469	0.7575000000000001	73	695	1	24	9	8	0	252	8	307	0	4.0	26	
i 1	350.2503129251701	0.2525	70	695	2	24	13	2	0	-2	2	0	0	4.0	26	
i 1	350.2578231292517	0.2525	69	1081	5	9	5	1	0	-1	1	0	0	3.0	26	
i 1	350.25844897959183	0.2525	69	695	6	2	6	0	0	-1	0	0	0	4.0	26	
i 1	350.754693877551	0.2525	69	695	6	2	9	0	0	-1	0	0	0	4.0	27	
i 1	350.98466666666667	1.01	61	585	5	17	14	16	0	1	16	0	0	5.290431105685503	28	
i 1	350.9890476190476	1.01	61	199	1	27	15	1	0	248	1	308	0	1.154898545639104	28	
i 1	350.9890476190476	1.01	63	585	4	7	8	16	0	1	16	0	0	6.345554294259793	28	
i 1	350.98967346938775	7.07	61	199	4	19	14	1	0	1	1	0	0	5.290431105685503	28	
i 1	350.990925170068	7.07	63	901	6	17	9	16	0	2	16	0	0	5.290431105685503	28	
i 1	350.9971836734694	8.08	61	901	6	17	4	16	0	1	16	0	0	5.290431105685503	28	
i 1	351.0003129251701	0.7575000000000001	74	901	6	5	15	8	0	-1	8	0	0	3.0065128918243444	28	
i 1	351.0009387755102	7.07	63	901	5	14	4	16	0	1	16	0	0	6.933713913664838	28	
i 1	351.0021904761905	0.2525	72	585	4	4	11	0	0	0	0	0	0	4.0	28	
i 1	351.0028163265306	8.08	61	199	4	19	16	16	0	1	16	0	0	5.290431105685503	28	
i 1	351.0040680272109	5.05	63	199	5	18	9	1	5000	2	1	0	0	5.290431105685503	28	
i 1	351.01032653061225	3.0300000000000002	63	199	1	27	8	16	0	252	16	307	0	1.154898545639104	28	
i 1	351.0109523809524	8.08	63	585	6	17	14	16	0	1	16	0	0	5.290431105685503	28	
i 1	351.0109523809524	8.08	61	585	5	13	1	1	0	1	1	0	0	5.169235055449704	28	
i 1	351.0128299319728	5.05	63	901	5	14	12	16	0	2	16	0	0	6.933713913664838	28	
i 1	351.0134557823129	3.0300000000000002	63	199	5	18	6	16	5000	1	16	0	0	5.290431105685503	28	
i 1	351.5040680272109	1.7675	74	901	4	1	11	2	0	-2	2	0	0	0.488354119971917	28	
i 1	351.7352925170068	0.2525	74	585	5	5	13	2	0	-1	2	0	0	3.0065128918243444	28	
i 1	351.7365442176871	0.2525	74	199	4	5	5	2	0	-2	2	0	0	3.0065128918243444	28	
i 1	351.7471836734694	0.7575000000000001	70	199	1	24	14	2	5000	248	2	308	0	4.0	28	
i 1	351.7540680272109	0.7575000000000001	72	585	4	4	16	0	0	0	0	0	0	4.0	28	
i 1	351.9859183673469	0.2525	71	199	5	5	15	2	5000	-2	2	0	0	3.0065128918243444	28	
i 1	351.9971836734694	7.07	61	585	6	17	2	16	0	1	16	0	0	5.290431105685503	28	
i 1	352.009074829932	7.07	61	199	4	27	2	1	0	2	1	0	0	1.154898545639104	28	
i 1	352.2371700680272	1.01	69	901	6	2	5	1	0	0	1	0	0	4.0	28	
i 1	352.23779591836734	0.2525	74	199	4	1	1	8	5000	-2	8	0	0	0.488354119971917	28	
i 1	352.48967346938775	0.2525	70	585	4	24	4	2	0	-2	2	0	0	4.0	28	
i 1	352.490925170068	2.2725	71	585	4	1	6	2	0	-2	2	0	0	0.488354119971917	28	
i 1	352.5028163265306	0.7575000000000001	70	199	4	24	16	2	5000	-1	2	0	0	4.0	28	
i 1	352.50844897959183	0.2525	74	585	5	5	11	2	0	-1	2	0	0	3.0065128918243444	28	
i 1	352.5097006802721	0.2525	69	199	5	4	1	0	0	0	0	0	0	4.0	28	
i 1	352.7371700680272	0.2525	71	199	3	1	15	2	0	-2	2	0	0	0.488354119971917	28	
i 1	352.74843537414966	2.2725	72	585	4	4	10	0	0	0	0	0	0	4.0	28	
i 1	352.7609523809524	2.2725	74	901	6	5	4	8	0	-1	8	0	0	3.0065128918243444	28	
i 1	353.004693877551	0.2525	74	901	6	1	8	2	0	-1	2	0	0	0.488354119971917	28	
i 1	353.01533333333333	0.2525	72	199	6	9	13	1	5000	0	1	0	0	3.0	28	
i 1	353.2615782312925	0.505	72	901	6	2	12	1	0	0	1	0	0	4.0	28	
i 1	353.26220408163266	0.2525	74	585	5	5	14	2	0	-1	2	0	0	3.0065128918243444	28	
i 1	353.26533333333333	0.2525	74	199	5	5	10	8	5000	-1	8	0	0	3.0065128918243444	28	
i 1	353.4884217687075	0.2525	74	199	4	5	1	2	0	-2	2	0	0	3.0065128918243444	28	
i 1	353.49155102040817	0.2525	71	585	6	5	4	8	0	-2	8	0	0	3.0065128918243444	28	
i 1	353.4940544217687	0.2525	73	585	4	24	2	8	0	-2	8	0	0	4.0	28	
i 1	353.73466666666667	0.2525	74	901	6	1	15	2	0	-1	2	0	0	0.488354119971917	28	
i 1	353.7503129251701	0.505	71	199	4	1	4	2	5000	-2	2	0	0	0.488354119971917	28	
i 1	353.98466666666667	5.05	63	199	4	27	4	16	0	1	16	0	0	1.154898545639104	28	
i 1	354.0071972789116	0.2525	71	199	5	5	12	2	5000	-2	2	0	0	3.0065128918243444	28	
i 1	354.009074829932	0.2525	73	199	3	24	3	2	0	-2	2	0	0	4.0	28	
i 1	354.01032653061225	5.05	63	199	5	18	9	16	5000	1	16	0	0	5.290431105685503	28	
i 1	354.2384217687075	0.2525	71	585	4	24	4	8	0	-2	8	0	0	3.488354119971917	28	
i 1	354.259074829932	1.7675	74	585	6	5	7	2	0	-1	2	0	0	3.0065128918243444	28	
i 1	354.7509387755102	0.505	74	199	5	5	1	8	5000	-1	8	0	0	3.0065128918243444	28	
i 1	355.0009387755102	0.505	71	901	6	5	9	8	0	-2	8	0	0	3.0065128918243444	29	
i 1	355.0040680272109	0.505	74	199	4	1	11	8	5000	-2	8	0	0	0.488354119971917	29	
i 1	355.26220408163266	2.02	74	901	6	5	16	8	0	-1	8	0	0	3.0065128918243444	29	
i 1	355.2634557823129	2.02	73	199	1	24	14	8	0	252	8	307	0	4.0	29	
i 1	355.49655782312925	0.2525	74	901	6	1	11	2	0	-1	2	0	0	0.488354119971917	29	
i 1	355.5128299319728	0.505	72	901	6	2	10	1	0	0	1	0	0	4.0	29	
i 1	355.7459319727891	0.2525	71	199	3	1	10	2	0	-2	2	0	0	0.488354119971917	29	
i 1	355.7471836734694	0.505	72	199	5	3	5	1	0	0	1	0	0	4.0	29	
i 1	355.98466666666667	0.505	74	199	3	24	5	2	0	-1	2	0	0	3.488354119971917	29	
i 1	355.9871700680272	3.0300000000000002	63	901	3	14	12	16	0	2	16	0	0	6.933713913664838	29	
i 1	356.0147074829932	3.0300000000000002	63	199	5	18	13	1	5000	2	1	0	0	5.290431105685503	29	
i 1	356.2390476190476	0.2525	74	199	4	5	11	2	0	-2	2	0	0	3.0065128918243444	29	
i 1	356.2428027210884	0.2525	72	199	6	9	7	1	5000	0	1	0	0	3.0	29	
i 1	356.24468027210884	0.505	74	199	4	5	10	8	0	-1	8	0	0	3.0065128918243444	29	
i 1	356.5003129251701	0.505	69	199	5	4	15	0	0	0	0	0	0	4.0	29	
i 1	356.51220408163266	0.505	71	585	6	1	6	2	0	-2	2	0	0	0.488354119971917	29	
i 1	357.00344217687075	1.01	70	199	4	24	4	2	5000	-1	2	0	0	4.0	30	
i 1	357.2371700680272	0.2525	71	585	6	1	15	2	0	-2	2	0	0	0.488354119971917	30	
i 1	357.245306122449	0.2525	74	585	6	5	9	2	0	-1	2	0	0	3.0065128918243444	30	
i 1	357.2503129251701	1.7675	73	199	3	24	8	8	0	-2	8	0	0	4.0	30	
i 1	357.49155102040817	0.2525	71	199	3	1	11	2	0	-2	2	0	0	0.488354119971917	30	
i 1	357.7359183673469	0.2525	74	199	5	5	5	8	5000	-1	8	0	0	3.0065128918243444	30	
i 1	357.74843537414966	0.2525	72	199	6	9	3	1	5000	0	1	0	0	3.0	30	
i 1	357.76220408163266	0.2525	72	585	5	3	10	1	0	-1	1	0	0	4.0	30	
i 1	357.9852925170068	1.01	72	585	4	4	1	0	0	0	0	0	0	4.0	30	
i 1	357.9902993197279	0.505	71	199	4	1	14	2	5000	-2	2	0	0	0.488354119971917	30	
i 1	357.990925170068	1.01	63	901	5	17	3	16	0	2	16	0	0	5.290431105685503	30	
i 1	357.9959319727891	1.01	63	901	3	14	4	16	0	1	16	0	0	6.933713913664838	30	
i 1	358.0021904761905	1.01	61	199	5	19	14	1	0	1	1	0	0	5.290431105685503	30	
i 1	358.245306122449	0.7575000000000001	71	585	4	24	13	8	0	-2	8	0	0	3.488354119971917	30	
i 1	358.4871700680272	0.505	69	199	6	9	1	0	5000	0	0	0	0	3.0	30	
i 1	358.5040680272109	0.505	74	199	3	24	16	2	0	-1	2	0	0	3.488354119971917	30	
i 1	358.5059455782313	0.2525	70	199	1	24	3	2	5000	-1	2	0	0	4.0	30	
i 1	358.7565714285714	0.2525	74	199	4	5	11	2	0	-2	2	0	0	3.0065128918243444	30	
i 1	358.75844897959183	0.2525	69	199	5	4	14	0	0	0	0	0	0	4.0	30	
i 1	358.75844897959183	0.2525	73	199	3	24	7	2	0	-2	2	0	0	4.0	30	
i 1	358.990925170068	0.2525	69	723	6	5	1	0	5019	0	0	0	0	3.021213419085008	128	
i 1	358.99843537414966	1.2625	77	723	4	24	10	16	5019	2	16	0	0	3.2698800808635933	128	
i 1	359.00844897959183	0.7575000000000001	74	723	6	1	2	17	5019	2	17	0	0	0.2698800808635933	128	
i 1	359.01032653061225	2.02	72	1092	6	5	11	0	0	0	0	0	0	3.021213419085008	128	
i 1	359.2471836734694	0.505	77	208	6	9	12	16	5020	2	16	0	0	3.0	128	
i 1	359.73779591836734	3.535	74	1092	6	2	3	16	0	1	16	0	0	4.0	128	
i 1	359.75344217687075	0.2525	74	208	5	1	5	17	5022	2	17	0	0	0.2698800808635933	128	
i 1	359.7578231292517	4.2925	77	1092	6	1	3	17	0	1	17	0	0	0.2698800808635933	128	
i 1	359.9934285714286	0.2525	74	208	6	9	11	16	5020	2	16	0	0	3.0	128	
i 1	360.0065714285714	0.2525	73	208	1	24	4	16	5019	2	16	0	0	4.0	128	
i 1	360.23466666666667	0.2525	77	208	5	24	7	17	5022	1	17	0	0	3.2698800808635933	128	
i 1	360.2478095238095	0.505	73	208	1	24	9	16	5019	252	16	307	0	4.0	128	
i 1	360.2496870748299	0.2525	77	208	6	3	7	17	5022	2	17	0	0	4.0	128	
i 1	360.2503129251701	2.2725	72	723	6	5	3	0	5019	0	0	0	0	3.021213419085008	128	
i 1	360.4859183673469	0.2525	77	208	7	1	16	17	5020	2	17	0	0	0.2698800808635933	128	
i 1	360.5134557823129	0.505	74	1092	6	1	6	16	0	2	16	0	0	0.2698800808635933	128	
i 1	360.7352925170068	0.2525	69	208	4	5	9	1	5022	-1	1	0	0	3.021213419085008	128	
i 1	360.9871700680272	0.2525	69	208	5	5	4	1	5020	0	1	0	0	3.021213419085008	128	
i 1	361.2528163265306	0.2525	74	723	6	1	1	17	5019	2	17	0	0	0.2698800808635933	128	
i 1	361.2634557823129	0.2525	77	208	7	1	7	17	5020	2	17	0	0	0.2698800808635933	128	
i 1	361.5078231292517	0.505	77	723	4	24	13	16	5019	2	16	0	0	3.2698800808635933	128	
i 1	361.7490612244898	0.2525	74	723	6	1	13	17	5019	2	17	0	0	0.2698800808635933	128	
i 1	361.990925170068	0.2525	72	208	5	5	7	0	5020	-1	0	0	0	3.021213419085008	128	
i 1	362.01220408163266	0.7575000000000001	77	208	5	24	16	17	5022	1	17	0	0	3.2698800808635933	128	
i 1	362.01533333333333	0.505	77	208	6	3	13	17	5022	2	17	0	0	4.0	128	
i 1	362.240925170068	2.02	69	723	6	5	2	0	5019	0	0	0	0	3.021213419085008	128	
i 1	362.48779591836734	0.2525	69	208	7	5	2	1	5020	0	1	0	0	3.021213419085008	128	
i 1	362.9940544217687	0.505	74	208	7	1	7	17	5020	2	17	0	0	0.2698800808635933	129	
i 1	362.9971836734694	0.2525	69	208	4	5	13	0	5022	-1	0	0	0	3.021213419085008	129	
i 1	363.23967346938775	0.505	69	208	7	5	7	1	5020	0	1	0	0	3.021213419085008	129	
i 1	363.2503129251701	0.2525	76	723	2	24	11	16	5019	2	16	0	0	4.0	129	
i 1	363.25844897959183	2.525	74	723	6	1	14	17	5019	2	17	0	0	0.2698800808635933	129	
i 1	363.4971836734694	0.7575000000000001	76	208	1	24	12	16	5019	1	16	0	0	4.0	129	
i 1	363.5065714285714	0.505	77	723	4	24	3	16	5019	2	16	0	0	3.2698800808635933	129	
i 1	363.74655782312925	0.505	77	208	6	3	6	17	5022	2	17	0	0	4.0	129	
i 1	363.7496870748299	0.2525	72	208	5	5	1	0	5020	-1	0	0	0	3.021213419085008	129	
i 1	363.9865442176871	0.7575000000000001	74	208	7	1	7	17	5020	2	17	0	0	0.2698800808635933	129	
i 1	364.0071972789116	0.7575000000000001	69	208	4	5	12	0	5022	-1	0	0	0	3.021213419085008	129	
i 1	364.245306122449	0.2525	77	208	5	4	4	17	5022	1	17	0	0	4.0	129	
i 1	364.26220408163266	0.2525	74	208	6	1	15	17	5022	2	17	0	0	0.2698800808635933	129	
i 1	364.48466666666667	0.2525	76	208	1	24	5	17	5019	1	17	0	0	4.0	129	
i 1	364.5078231292517	2.02	77	1092	6	2	15	17	0	2	17	0	0	4.0	129	
i 1	364.509074829932	0.505	74	723	4	4	11	16	5019	2	16	0	0	4.0	129	
i 1	364.9959319727891	0.505	69	208	4	5	5	1	5022	-1	1	0	0	3.021213419085008	130	
i 1	365.0065714285714	2.02	77	1092	6	1	7	17	0	1	17	0	0	0.2698800808635933	130	
i 1	365.0147074829932	0.2525	72	1092	6	5	9	0	0	0	0	0	0	3.021213419085008	130	
i 1	365.2634557823129	0.2525	74	1092	6	2	14	16	0	1	16	0	0	4.0	130	
i 1	365.48967346938775	0.505	74	723	4	4	11	16	5019	2	16	0	0	4.0	130	
i 1	365.5078231292517	0.2525	77	723	5	3	16	17	5019	2	17	0	0	4.0	130	
i 1	365.7421768707483	0.2525	76	208	1	24	2	16	5022	1	16	0	0	4.0	130	
i 1	365.9859183673469	0.2525	73	208	1	24	7	16	5022	2	16	0	0	4.0	130	
i 1	365.98967346938775	0.2525	77	723	5	3	11	17	5019	2	17	0	0	4.0	130	
i 1	366.240925170068	0.505	72	1092	6	5	16	0	0	0	0	0	0	3.021213419085008	130	
i 1	366.2634557823129	0.2525	72	208	7	5	11	0	5020	-1	0	0	0	3.021213419085008	130	
i 1	366.4859183673469	1.5150000000000001	74	723	6	1	9	17	5019	2	17	0	0	0.2698800808635933	130	
i 1	366.4890476190476	0.2525	69	723	6	5	11	0	5019	0	0	0	0	3.021213419085008	130	
i 1	366.5065714285714	0.2525	77	723	4	24	4	16	5019	2	16	0	0	3.2698800808635933	130	
i 1	366.7521904761905	0.2525	77	208	5	4	10	17	5022	1	17	0	0	4.0	130	
i 1	366.7528163265306	0.7575000000000001	76	208	1	24	7	16	5022	1	16	0	0	4.0	130	
i 1	367.2597006802721	0.2525	74	208	6	1	1	17	5022	2	17	0	0	0.2698800808635933	131	
i 1	367.5009387755102	0.2525	74	208	6	1	13	17	5020	2	17	0	0	0.2698800808635933	131	
i 1	367.5140816326531	0.505	77	1092	6	1	5	17	0	1	17	0	0	0.2698800808635933	131	
i 1	367.9871700680272	2.525	69	882	6	5	10	0	5021	-1	0	0	0	3.021213419085008	132	
i 1	367.99155102040817	2.2725	77	882	6	2	14	17	5021	2	17	0	0	4.0	132	
i 1	367.9928027210884	0.2525	74	678	6	1	4	16	0	2	16	0	0	0.2698800808635933	132	
i 1	367.99843537414966	4.545	74	882	6	1	1	17	5021	2	17	0	0	0.2698800808635933	132	
i 1	368.2352925170068	0.505	74	882	6	1	6	17	5021	2	17	0	0	0.2698800808635933	132	
i 1	368.26220408163266	0.2525	74	208	6	1	10	17	5020	2	17	0	0	0.2698800808635933	132	
i 1	368.4902993197279	0.505	77	678	4	24	1	17	0	1	17	0	0	3.2698800808635933	133	
i 1	368.7365442176871	0.2525	77	208	5	24	8	17	5022	1	17	0	0	3.2698800808635933	133	
i 1	368.73967346938775	0.2525	77	208	5	3	8	17	5022	2	17	0	0	4.0	133	
i 1	368.7478095238095	0.2525	77	678	4	4	9	17	0	2	17	0	0	4.0	133	
i 1	368.98466666666667	0.7575000000000001	74	882	6	2	12	17	5021	2	17	0	0	4.0	133	
i 1	369.0009387755102	1.2625	73	208	2	24	9	16	0	1	16	0	0	4.0	133	
i 1	369.00531972789116	1.01	76	208	4	24	4	16	5020	2	16	0	0	4.0	133	
i 1	369.01220408163266	0.2525	74	208	6	1	7	17	5020	2	17	0	0	0.2698800808635933	133	
i 1	369.2565714285714	0.505	69	208	6	5	3	1	5022	-1	1	0	0	3.021213419085008	133	
i 1	369.5003129251701	0.505	74	208	6	1	12	17	5020	2	17	0	0	0.2698800808635933	133	
i 1	369.7384217687075	2.7775	72	678	6	5	6	0	0	0	0	0	0	3.021213419085008	133	
i 1	369.7478095238095	2.2725	77	678	4	4	5	17	0	2	17	0	0	4.0	133	
i 1	369.7615782312925	0.2525	69	208	6	5	2	0	5022	-1	0	0	0	3.021213419085008	133	
i 1	370.0009387755102	0.505	72	208	7	5	2	0	5020	-1	0	0	0	3.021213419085008	133	
i 1	370.24155102040817	0.505	77	678	4	24	3	17	0	1	17	0	0	3.2698800808635933	133	
i 1	370.2559455782313	0.505	74	678	5	3	1	17	0	1	17	0	0	4.0	133	
i 1	370.4902993197279	0.7575000000000001	74	882	6	1	16	17	5021	2	17	0	0	0.2698800808635933	133	
i 1	370.4940544217687	0.2525	69	208	7	5	9	1	5020	0	1	0	0	3.021213419085008	133	
i 1	370.5021904761905	0.505	77	208	5	4	8	17	5022	1	17	0	0	4.0	133	
i 1	370.50344217687075	0.2525	72	882	6	5	2	1	5021	-1	1	0	0	3.021213419085008	133	
i 1	370.7565714285714	0.2525	74	208	6	1	10	17	5020	2	17	0	0	0.2698800808635933	133	
i 1	370.9859183673469	3.0300000000000002	72	882	6	5	7	1	5021	-1	1	0	0	3.021213419085008	133	
i 1	371.0003129251701	0.2525	73	208	2	24	5	17	0	2	17	0	0	4.0	133	
i 1	371.0040680272109	1.5150000000000001	74	678	5	3	16	17	0	1	17	0	0	4.0	133	
i 1	371.0109523809524	0.505	69	208	6	5	1	0	5022	-1	0	0	0	3.021213419085008	133	
i 1	371.4934285714286	0.505	72	678	6	5	5	1	0	0	1	0	0	3.021213419085008	133	
i 1	371.5003129251701	0.2525	77	208	5	3	7	17	5022	2	17	0	0	4.0	133	
i 1	371.7503129251701	0.505	77	208	6	1	5	17	5020	2	17	0	0	0.2698800808635933	133	
i 1	371.9978095238095	0.2525	74	208	6	9	16	16	5020	2	16	0	0	3.0	133	
i 1	372.2615782312925	1.7675	77	882	5	2	9	17	5021	2	17	0	0	4.0	133	
i 1	372.4871700680272	0.2525	74	566	6	1	7	16	5021	1	16	0	0	0.2698800808635933	134	
i 1	372.4971836734694	1.5150000000000001	77	566	4	24	8	16	5021	1	16	0	0	3.2698800808635933	134	
i 1	372.509074829932	0.2525	74	882	6	1	11	17	5021	2	17	0	0	0.2698800808635933	134	
i 1	372.7384217687075	0.7575000000000001	72	208	7	5	10	0	5020	-1	0	0	0	3.021213419085008	134	
i 1	372.7428027210884	0.2525	77	208	5	4	3	17	5022	1	17	0	0	4.0	134	
i 1	372.9871700680272	3.0300000000000002	74	882	5	2	15	17	5021	2	17	0	0	4.0	134	
i 1	372.9959319727891	0.2525	69	882	6	5	15	0	5021	-1	0	0	0	3.021213419085008	134	
i 1	373.2503129251701	0.505	69	208	6	5	10	1	5022	-1	1	0	0	3.021213419085008	134	
i 1	373.4852925170068	0.2525	74	208	6	9	16	16	5020	2	16	0	0	3.0	134	
i 1	373.7615782312925	0.2525	69	208	7	5	9	1	5020	0	1	0	0	3.021213419085008	134	
i 1	373.7634557823129	1.01	69	882	6	5	11	0	5021	-1	0	0	0	3.021213419085008	134	
i 1	373.9890476190476	0.2525	77	208	4	24	6	17	5022	1	17	0	0	3.2698800808635933	134	
i 1	374.01220408163266	0.505	74	208	6	1	1	17	5020	2	17	0	0	0.2698800808635933	134	
i 1	374.0128299319728	0.2525	77	208	6	9	4	16	5020	2	16	0	0	3.0	134	
i 1	374.2428027210884	0.2525	77	566	5	3	5	17	5021	1	17	0	0	4.0	134	
i 1	374.2559455782313	2.02	72	566	6	5	15	0	5021	-1	0	0	0	3.021213419085008	134	
i 1	374.2647074829932	2.02	77	566	4	24	2	16	5021	1	16	0	0	3.2698800808635933	134	
i 1	374.4928027210884	0.505	76	1151	1	24	2	16	0	248	16	308	0	4.0	135	
i 1	374.990925170068	1.01	69	882	6	5	7	0	5021	-1	0	0	0	3.021213419085008	135	
i 1	375.0003129251701	0.2525	76	1151	4	24	12	16	0	1	16	0	0	4.0	135	
i 1	375.0009387755102	0.2525	77	208	6	3	3	17	5022	2	17	0	0	4.0	135	
i 1	375.240925170068	0.505	77	208	5	4	15	17	5022	1	17	0	0	4.0	135	
i 1	375.504693877551	0.7575000000000001	69	208	6	5	5	0	5022	-1	0	0	0	3.021213419085008	135	
i 1	375.74155102040817	0.2525	77	1151	5	9	2	17	0	1	17	0	0	3.0	135	
i 1	375.7459319727891	0.7575000000000001	76	1151	4	24	6	16	0	1	16	0	0	4.0	135	
i 1	375.754693877551	0.7575000000000001	74	882	6	1	16	17	5021	2	17	0	0	0.2698800808635933	135	
i 1	375.9890476190476	0.505	69	882	4	5	12	0	5021	-1	0	0	0	3.021213419085008	135	
i 1	376.2478095238095	0.2525	72	882	6	5	15	1	5021	-1	1	0	0	3.021213419085008	135	
i 1	376.2597006802721	0.2525	69	1151	6	5	12	0	0	-1	0	0	0	3.021213419085008	135	
i 1	376.4978095238095	1.01	77	180	5	4	5	17	0	1	17	0	0	4.0	136	
i 1	376.5134557823129	1.5150000000000001	74	678	6	1	11	16	0	1	16	0	0	0.2698800808635933	136	
i 1	376.5147074829932	1.5150000000000001	72	678	6	5	8	1	0	0	1	0	0	3.021213419085008	136	
i 1	376.7371700680272	3.535	77	180	5	3	10	17	0	1	17	0	0	4.0	136	
i 1	376.9884217687075	0.505	74	678	4	4	1	17	0	1	17	0	0	4.0	136	
i 1	377.0003129251701	0.2525	69	1064	6	5	15	1	0	0	1	0	0	3.021213419085008	136	
i 1	377.0003129251701	0.2525	69	678	6	5	16	1	0	-1	1	0	0	3.021213419085008	136	
i 1	377.0065714285714	0.2525	74	1064	6	1	1	16	0	2	16	0	0	0.2698800808635933	136	
i 1	377.2440544217687	0.505	72	678	4	5	15	0	0	-1	0	0	0	3.021213419085008	136	
i 1	377.2490612244898	0.7575000000000001	69	180	7	5	6	0	0	-1	0	0	0	3.021213419085008	136	
i 1	377.26032653061225	0.505	74	678	6	1	9	16	0	2	16	0	0	0.2698800808635933	136	
i 1	377.4890476190476	0.7575000000000001	77	678	5	2	4	16	0	2	16	0	0	4.0	137	
i 1	377.49155102040817	0.2525	74	678	5	3	14	16	0	2	16	0	0	4.0	137	
i 1	377.5003129251701	0.2525	77	678	4	24	2	16	0	1	16	0	0	3.2698800808635933	137	
i 1	377.7371700680272	0.2525	74	1064	6	1	10	16	0	2	16	0	0	0.2698800808635933	137	
i 1	377.7428027210884	0.2525	69	678	6	5	2	1	0	-1	1	0	0	3.021213419085008	137	
i 1	377.7459319727891	0.2525	74	678	5	2	3	16	0	1	16	0	0	4.0	137	
i 1	377.7597006802721	2.2725	74	180	7	1	13	17	0	2	17	0	0	0.2698800808635933	137	
i 1	377.7640816326531	0.505	72	1064	6	5	15	0	0	-1	0	0	0	3.021213419085008	137	
i 1	377.9959319727891	1.2625	69	180	4	5	13	0	0	-1	0	0	0	3.021213419085008	138	
i 1	378.0109523809524	10.1	66	678	5	14	13	6	0	0	6	0	0	4.028474639567512	138	
i 1	378.2634557823129	3.7875	72	678	6	5	13	1	0	0	1	0	0	3.021213419085008	138	
i 1	378.4865442176871	0.505	72	678	6	5	10	0	0	-1	0	0	0	3.021213419085008	138	
i 1	378.4959319727891	0.505	77	180	5	4	8	17	0	1	17	0	0	4.0	138	
i 1	378.5071972789116	0.2525	73	678	2	24	15	17	0	2	17	0	0	4.0	138	
i 1	378.9852925170068	0.2525	74	1064	6	1	5	17	0	1	17	0	0	0.2698800808635933	138	
i 1	379.00344217687075	0.7575000000000001	69	678	6	5	2	1	0	-1	1	0	0	3.021213419085008	138	
i 1	379.2428027210884	0.7575000000000001	72	1064	6	5	5	0	0	-1	0	0	0	3.021213419085008	138	
i 1	379.24843537414966	0.2525	72	180	7	5	15	0	0	0	0	0	0	3.021213419085008	138	
i 1	379.26533333333333	2.02	74	678	6	1	5	16	0	1	16	0	0	0.2698800808635933	138	
i 1	379.7490612244898	0.2525	77	1064	4	9	7	16	0	2	16	0	0	3.0	138	
i 1	379.7528163265306	0.505	77	678	6	1	9	17	0	2	17	0	0	0.2698800808635933	138	
i 1	379.76032653061225	0.7575000000000001	69	678	6	5	16	1	0	0	1	0	0	3.021213419085008	138	
i 1	380.0115782312925	2.02	74	180	5	24	9	16	0	1	16	0	0	3.2698800808635933	138	
i 1	380.2390476190476	0.2525	77	678	4	24	7	16	0	1	16	0	0	3.2698800808635933	138	
i 1	380.2647074829932	9.09	73	678	2	24	12	17	0	2	17	0	0	4.0	138	
i 1	380.74155102040817	0.2525	74	678	5	3	3	16	0	2	16	0	0	4.0	138	
i 1	380.74843537414966	0.7575000000000001	72	180	4	5	4	0	0	0	0	0	0	3.021213419085008	138	
i 1	380.7609523809524	0.2525	69	678	6	5	3	1	0	-1	1	0	0	3.021213419085008	138	
i 1	380.9934285714286	0.2525	76	678	2	24	10	16	0	1	16	0	0	4.0	138	
i 1	381.23779591836734	0.505	77	678	6	1	12	17	0	2	17	0	0	0.2698800808635933	138	
i 1	381.2402993197279	0.2525	77	1064	4	9	3	16	0	2	16	0	0	3.0	138	
i 1	381.25156462585034	0.505	74	678	4	4	6	17	0	1	17	0	0	4.0	138	
i 1	381.2647074829932	0.2525	72	678	6	5	8	0	0	-1	0	0	0	3.021213419085008	138	
i 1	381.51533333333333	0.2525	74	678	6	1	4	16	0	2	16	0	0	0.2698800808635933	138	
i 1	381.7428027210884	0.2525	74	678	6	1	14	16	0	1	16	0	0	0.2698800808635933	138	
i 1	381.7459319727891	0.505	69	678	6	5	3	1	0	0	1	0	0	3.021213419085008	138	
i 1	381.7521904761905	2.2725	77	678	6	2	10	16	0	2	16	0	0	4.0	138	
i 1	381.76032653061225	0.2525	77	180	5	3	14	17	0	1	17	0	0	4.0	138	
i 1	381.7634557823129	0.2525	72	1064	6	5	10	0	0	-1	0	0	0	3.021213419085008	138	
i 1	381.98967346938775	0.7575000000000001	77	180	5	4	5	17	0	1	17	0	0	4.0	139	
i 1	381.99655782312925	0.2525	74	1064	6	1	5	16	0	2	16	0	0	0.2698800808635933	139	
i 1	382.0028163265306	1.01	73	678	1	24	6	17	0	248	17	308	0	4.0	139	
i 1	382.0040680272109	0.2525	69	1064	6	5	3	1	0	0	1	0	0	3.021213419085008	139	
i 1	382.0115782312925	0.505	69	180	7	5	16	0	0	-1	0	0	0	3.021213419085008	139	
i 1	382.4971836734694	2.2725	74	180	5	24	3	16	0	1	16	0	0	3.2698800808635933	139	
i 1	382.51032653061225	1.2625	73	1064	3	24	11	17	0	1	17	0	0	4.0	139	
i 1	382.7352925170068	0.2525	69	180	7	5	12	0	0	-1	0	0	0	3.021213419085008	139	
i 1	382.7440544217687	0.7575000000000001	74	1064	6	1	8	16	0	2	16	0	0	0.2698800808635933	139	
i 1	382.9852925170068	0.2525	72	678	6	5	2	0	0	-1	0	0	0	3.021213419085008	139	
i 1	383.0009387755102	0.2525	69	678	6	5	2	1	0	-1	1	0	0	3.021213419085008	139	
i 1	383.00531972789116	0.2525	74	678	4	4	4	17	0	1	17	0	0	4.0	139	
i 1	383.24655782312925	1.5150000000000001	77	180	5	4	15	17	0	1	17	0	0	4.0	139	
i 1	383.2503129251701	0.2525	74	678	6	1	2	16	0	2	16	0	0	0.2698800808635933	139	
i 1	383.4859183673469	2.525	74	678	6	2	5	16	0	1	16	0	0	4.0	139	
i 1	383.4902993197279	0.2525	69	678	6	5	13	1	0	-1	1	0	0	3.021213419085008	139	
i 1	383.4921768707483	0.505	72	678	6	5	11	0	0	-1	0	0	0	3.021213419085008	139	
i 1	383.5128299319728	0.505	74	1064	6	1	4	17	0	1	17	0	0	0.2698800808635933	139	
i 1	383.75344217687075	0.2525	74	678	6	1	10	16	0	2	16	0	0	0.2698800808635933	139	
i 1	383.754693877551	0.2525	76	678	2	24	2	16	0	1	16	0	0	4.0	139	
i 1	383.76032653061225	0.505	69	678	6	5	13	1	0	0	1	0	0	3.021213419085008	139	
i 1	383.7609523809524	0.2525	74	678	4	4	6	17	0	1	17	0	0	4.0	139	
i 1	383.9996870748299	1.5150000000000001	72	678	6	5	4	0	0	-1	0	0	0	3.021213419085008	140	
i 1	384.2384217687075	1.7675	69	180	7	5	1	0	0	-1	0	0	0	3.021213419085008	140	
i 1	384.25844897959183	0.2525	72	1064	6	5	4	0	0	-1	0	0	0	3.021213419085008	140	
i 1	384.2634557823129	0.2525	74	1064	6	1	3	16	0	2	16	0	0	0.2698800808635933	140	
i 1	384.5040680272109	0.2525	69	678	6	5	16	1	0	-1	1	0	0	3.021213419085008	140	
i 1	384.7402993197279	0.505	74	678	6	1	14	16	0	2	16	0	0	0.2698800808635933	140	
i 1	384.7421768707483	0.7575000000000001	77	1064	4	9	11	16	0	2	16	0	0	3.0	140	
i 1	384.7597006802721	0.505	72	180	7	5	15	0	0	0	0	0	0	3.021213419085008	140	
i 1	384.9902993197279	1.01	69	1064	3	5	6	1	0	0	1	0	0	3.021213419085008	140	
i 1	385.0040680272109	0.505	74	1064	6	1	2	17	0	1	17	0	0	0.2698800808635933	140	
i 1	385.01533333333333	0.2525	77	678	4	2	7	16	0	2	16	0	0	4.0	140	
i 1	385.4852925170068	0.2525	74	678	3	3	8	16	0	2	16	0	0	4.0	140	
i 1	385.48967346938775	0.2525	69	678	6	5	10	1	0	-1	1	0	0	3.021213419085008	140	
i 1	385.51533333333333	0.505	77	678	6	1	12	17	0	2	17	0	0	0.2698800808635933	140	
i 1	385.9921768707483	0.2525	69	1064	6	5	13	1	0	0	1	0	0	3.021213419085008	141	
i 1	385.9928027210884	2.02	66	1064	4	16	2	6	0	0	6	0	0	2.014237319783756	141	
i 1	386.0147074829932	1.7675	74	678	4	2	3	16	0	1	16	0	0	4.0	141	
i 1	386.01533333333333	0.505	77	180	5	4	16	17	0	1	17	0	0	4.0	141	
i 1	386.01533333333333	1.01	69	180	7	5	16	0	0	-1	0	0	0	3.021213419085008	141	
i 1	386.23779591836734	0.7575000000000001	74	678	3	4	9	17	0	1	17	0	0	4.0	141	
i 1	386.2634557823129	1.2625	76	678	2	24	9	16	0	1	16	0	0	4.0	141	
i 1	386.49468027210884	0.2525	77	678	4	2	2	16	0	2	16	0	0	4.0	141	
i 1	386.5003129251701	0.505	77	678	4	24	11	16	0	1	16	0	0	3.2698800808635933	141	
i 1	386.5059455782313	1.5150000000000001	77	180	6	3	2	17	0	1	17	0	0	4.0	141	
i 1	386.7459319727891	0.7575000000000001	77	180	5	4	13	17	0	1	17	0	0	4.0	141	
i 1	386.7565714285714	0.505	77	678	6	1	6	17	0	2	17	0	0	0.2698800808635933	141	
i 1	386.75844897959183	0.2525	72	678	6	5	16	0	0	-1	0	0	0	3.021213419085008	141	
i 1	387.00531972789116	0.505	77	1064	4	9	4	16	0	2	16	0	0	3.0	142	
i 1	387.00844897959183	0.2525	69	678	6	5	9	1	0	0	1	0	0	3.021213419085008	142	
i 1	387.01533333333333	0.505	74	1064	6	1	14	16	0	2	16	0	0	0.2698800808635933	142	
i 1	387.25344217687075	0.2525	77	678	4	24	3	16	0	1	16	0	0	3.2698800808635933	142	
i 1	387.254693877551	0.2525	72	180	7	5	5	0	0	0	0	0	0	3.021213419085008	142	
i 1	387.2571972789116	0.505	74	180	5	24	6	16	0	1	16	0	0	3.2698800808635933	142	
i 1	387.48779591836734	0.505	72	678	6	5	12	0	0	-1	0	0	0	3.021213419085008	143	
i 1	387.4890476190476	0.505	74	1064	6	1	7	17	0	1	17	0	0	0.2698800808635933	143	
i 1	387.5009387755102	0.2525	74	678	3	3	8	16	0	2	16	0	0	4.0	143	
i 1	387.7640816326531	0.505	73	1064	3	24	4	17	0	1	17	0	0	4.0	143	
i 1	387.98466666666667	9.09	66	180	6	25	11	9	0	0	9	0	0	8.084289819473726	143	
i 1	387.98466666666667	4.04	66	1064	4	26	15	6	0	0	6	0	0	8.084289819473726	143	
i 1	387.99468027210884	2.02	66	180	6	25	1	6	0	0	6	0	0	8.084289819473726	143	
i 1	387.99655782312925	0.505	77	1064	4	9	15	16	0	2	16	0	0	6.0	143	
i 1	387.9971836734694	0.505	69	678	3	5	12	1	0	0	1	0	0	3.010120031911674	143	
i 1	388.00344217687075	8.08	66	678	5	25	3	9	0	0	9	0	0	8.084289819473726	143	
i 1	388.00531972789116	9.09	61	678	5	25	15	9	0	1	9	0	0	8.084289819473726	143	
i 1	388.0065714285714	0.505	77	1064	5	9	8	16	0	2	16	0	0	6.0	143	
i 1	388.0078231292517	2.02	66	678	3	27	8	6	0	0	6	0	0	9.23918836511283	143	
i 1	388.00844897959183	3.0300000000000002	72	678	6	5	15	1	0	0	1	0	0	3.010120031911674	143	
i 1	388.009074829932	0.2525	73	678	2	24	14	16	0	1	16	0	0	4.0	143	
i 1	388.0147074829932	6.0600000000000005	61	1064	4	26	6	9	0	1	9	0	0	8.084289819473726	143	
i 1	388.2647074829932	0.505	72	1064	6	5	10	0	0	-1	0	0	0	3.010120031911674	143	
i 1	388.4902993197279	0.505	74	678	4	2	7	16	0	1	16	0	0	7.0	143	
i 1	388.5140816326531	0.2525	69	678	6	5	12	1	0	-1	1	0	0	3.010120031911674	143	
i 1	388.73779591836734	0.2525	69	678	3	5	5	1	0	0	1	0	0	3.010120031911674	143	
i 1	389.00344217687075	1.01	77	678	4	2	11	16	0	2	16	0	0	7.0	143	
i 1	389.2371700680272	0.2525	74	180	5	24	8	16	0	1	16	0	0	3.0	143	
i 1	389.245306122449	0.2525	72	678	6	5	5	0	0	-1	0	0	0	3.010120031911674	143	
i 1	389.4978095238095	0.505	69	180	7	5	8	0	0	-1	0	0	0	3.010120031911674	143	
i 1	389.5065714285714	0.505	69	678	3	5	2	1	0	0	1	0	0	3.010120031911674	143	
i 1	389.5109523809524	0.2525	72	1064	6	5	13	0	0	-1	0	0	0	3.010120031911674	143	
i 1	389.7647074829932	0.7575000000000001	72	180	7	5	12	0	0	0	0	0	0	3.010120031911674	143	
i 1	389.9940544217687	6.0600000000000005	66	678	3	27	2	6	0	0	6	0	0	9.23918836511283	143	
i 1	389.9940544217687	0.7575000000000001	69	1064	6	5	8	1	0	0	1	0	0	3.010120031911674	143	
i 1	389.995306122449	0.2525	77	1064	5	9	1	16	0	2	16	0	0	6.0	143	
i 1	389.9959319727891	2.02	66	678	3	27	15	6	0	1	6	0	0	9.23918836511283	143	
i 1	390.0071972789116	1.01	77	678	6	2	6	16	0	2	16	0	0	7.0	143	
i 1	390.00844897959183	0.2525	69	678	6	5	6	1	0	-1	1	0	0	3.010120031911674	143	
i 1	390.01220408163266	7.07	66	180	6	25	16	6	0	0	6	0	0	8.084289819473726	143	
i 1	390.4940544217687	0.505	72	1064	6	5	11	0	0	-1	0	0	0	3.010120031911674	143	
i 1	390.7352925170068	0.2525	72	180	7	5	4	0	0	0	0	0	0	3.010120031911674	143	
i 1	390.74155102040817	0.2525	74	678	3	4	16	17	0	1	17	0	0	7.0	143	
i 1	390.7428027210884	0.2525	77	180	4	3	11	17	0	1	17	0	0	7.0	143	
i 1	390.74843537414966	0.2525	77	678	4	24	6	16	0	1	16	0	0	3.0	143	
i 1	391.99655782312925	5.05	66	1064	4	26	2	6	0	0	6	0	0	8.084289819473726	144	
i 1	392.00156462585034	5.05	66	678	3	27	13	6	0	1	6	0	0	9.23918836511283	144	
i 1	394.00156462585034	3.0300000000000002	61	1064	4	26	2	9	0	1	9	0	0	8.084289819473726	145	
i 1	395.98967346938775	1.01	66	678	3	27	14	6	0	0	6	0	0	9.23918836511283	146	
i 1	395.99155102040817	1.01	66	678	5	25	16	9	0	0	9	0	0	8.084289819473726	146	
t0 92
</CsScore>
</CsoundSynthesizer>

