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

f5000.0 0.0 256.0 -6.0 1.0 128.0 1.00406 128.0 1.00812 
f5001.0 0.0 256.0 -6.0 1.0 128.0 0.9974075 128.0 0.994815 
f5002.0 0.0 256.0 -6.0 1.0 128.0 0.997695 128.0 0.99539 
f5003.0 0.0 256.0 -6.0 1.0 128.0 1.0072725 128.0 1.014545 
f5004.0 0.0 256.0 -6.0 1.0 128.0 1.002316 128.0 1.004632 
f5005.0 0.0 256.0 -6.0 1.0 128.0 1.002606 128.0 1.005212 
;Inst	Sta	Hold	Vel	Ton	Oct	Voi	Ste	En1	Gls	Ups	Ren	2gl	3gl	Vol
i 1	0.00036054421768707406	11.615	61	200	6	14	14	1	0	1	1	0	0	4.17512010120168	
i 1	0.0032448979591836735	1.01	74	698	3	5	7	16	0	2	16	0	0	5.0	
i 1	0.005408163265306123	11.615	63	1084	3	13	13	1	0	1	1	0	0	1.4105596104834173	
i 1	0.006129251700680273	1.5150000000000001	61	698	5	12	1	1	0	1	1	0	0	3.711217867734826	
i 1	0.007571428571428569	0.2525	77	698	3	9	7	17	0	2	17	0	0	2.0	
i 1	0.007571428571428573	0.2525	74	200	5	2	3	16	0	2	16	0	0	3.0	
i 1	0.007571428571428573	14.645	61	1084	4	7	10	16	0	2	16	0	0	4.231678831450252	
i 1	0.00829251700680272	0.2525	69	200	6	1	6	1	0	0	1	0	0	2.0	
i 1	0.009013605442176869	0.7575000000000001	74	698	3	24	5	2	0	1	2	0	0	4.0	
i 1	0.00973469387755102	5.8075	63	200	4	14	1	16	0	1	16	0	0	5.642238441933669	
i 1	0.01117687074829932	5.8075	63	200	3	14	15	16	0	2	16	0	0	5.642238441933669	
i 1	0.012619047619047617	1.01	74	200	7	5	8	17	0	2	17	0	0	5.0	
i 1	0.014782312925170068	14.645	61	200	6	25	1	16	0	1	16	0	0	2.2996626092540455	
i 1	0.01550340136054422	0.2525	69	698	3	1	16	1	0	0	1	0	0	2.0	
i 1	0.24387074829931973	1.5150000000000001	72	698	3	24	14	0	0	0	0	0	0	3.0	
i 1	0.24891836734693878	1.5150000000000001	69	1084	4	24	9	0	0	-1	0	0	0	3.0	
i 1	0.26622448979591834	0.2525	74	1084	4	4	13	17	0	2	17	0	0	3.0	
i 1	0.26622448979591834	0.2525	77	698	4	4	11	16	0	1	16	0	0	3.0	
i 1	0.48665986394557825	0.505	74	698	3	9	8	17	0	2	17	0	0	2.0	
i 1	0.509734693877551	0.505	74	200	7	2	4	16	0	1	16	0	0	3.0	
i 1	0.990265306122449	0.505	74	1084	4	3	1	17	0	1	17	0	0	3.0	
i 1	0.9924285714285714	1.2625	74	698	3	5	2	17	0	2	17	0	0	5.0	
i 1	1.0039659863945578	0.505	77	698	5	3	11	16	0	2	16	0	0	3.0	
i 1	1.0082925170068027	0.505	77	1084	3	5	11	17	0	1	17	0	0	5.0	
i 1	1.48521768707483	1.01	74	200	5	2	14	16	0	2	16	0	0	3.0	
i 1	1.4989183673469388	0.7575000000000001	77	1084	6	5	2	17	0	1	17	0	0	5.0	
i 1	1.5090136054421768	1.01	77	698	3	9	5	17	0	2	17	0	0	2.0	
i 1	1.5155034013605442	0.2525	71	698	3	24	6	2	0	1	2	0	0	4.0	
i 1	1.749639455782313	0.505	69	200	7	1	9	1	0	0	1	0	0	2.0	
i 1	1.7510816326530612	0.7575000000000001	74	698	3	24	13	2	0	1	2	0	0	4.0	
i 1	1.7633401360544219	0.505	72	698	5	1	11	1	0	-1	1	0	0	2.0	
i 1	2.2337755102040817	1.01	74	698	3	5	6	17	0	1	17	0	0	5.0	
i 1	2.2388231292517005	1.01	74	200	5	5	15	16	0	1	16	0	0	5.0	
i 1	2.251081632653061	1.2625	72	1084	5	1	14	1	0	0	1	0	0	2.0	
i 1	2.2575714285714286	1.2625	69	698	3	1	12	1	0	-1	1	0	0	2.0	
i 1	2.485938775510204	1.01	74	1084	4	4	12	17	0	2	17	0	0	3.0	
i 1	2.513340136054422	1.01	77	698	4	4	7	16	0	1	16	0	0	3.0	
i 1	2.51478231292517	0.2525	71	698	3	24	1	2	0	1	2	0	0	4.0	
i 1	2.751081632653061	0.505	74	698	3	24	7	2	0	1	2	0	0	4.0	
i 1	3.2373809523809522	0.2525	77	1084	6	5	11	16	0	2	16	0	0	5.0	
i 1	3.2438707482993197	0.2525	71	698	3	24	14	2	0	1	2	0	0	4.0	
i 1	3.264061224489796	0.2525	77	698	3	5	8	16	0	2	16	0	0	5.0	
i 1	3.4888231292517005	1.5150000000000001	74	698	3	5	6	16	0	2	16	0	0	5.0	
i 1	3.490265306122449	0.505	69	698	3	1	2	1	0	0	1	0	0	2.0	
i 1	3.4909863945578232	0.2525	74	698	4	9	6	17	0	2	17	0	0	2.0	
i 1	3.4917074829931973	0.505	69	200	6	1	3	1	0	0	1	0	0	2.0	
i 1	3.499639455782313	1.5150000000000001	74	200	7	5	8	17	0	2	17	0	0	5.0	
i 1	3.500360544217687	1.01	74	698	3	24	2	2	0	1	2	0	0	4.0	
i 1	3.5176666666666665	0.2525	74	200	7	2	4	16	0	1	16	0	0	3.0	
i 1	3.7438707482993197	0.2525	74	1084	4	3	11	17	0	1	17	0	0	3.0	
i 1	3.763340136054422	0.2525	77	698	3	3	11	16	0	2	16	0	0	3.0	
i 1	3.9830544217687076	0.505	74	200	5	2	15	16	0	2	16	0	0	3.0	
i 1	3.9837755102040817	0.7575000000000001	69	1084	4	24	6	0	0	-1	0	0	0	3.0	
i 1	4.015503401360545	0.505	77	698	3	9	4	17	0	2	17	0	0	2.0	
i 1	4.017666666666667	0.7575000000000001	72	698	3	24	12	0	0	0	0	0	0	3.0	
i 1	4.482333333333333	0.505	77	698	4	4	6	16	0	1	16	0	0	3.0	
i 1	4.483054421768707	0.505	74	1084	4	4	6	17	0	2	17	0	0	3.0	
i 1	4.491707482993197	0.2525	71	698	3	24	13	2	0	1	2	0	0	4.0	
i 1	4.73521768707483	0.505	71	698	3	24	12	2	0	1	2	0	0	4.0	
i 1	4.742428571428571	0.2525	72	698	5	1	9	1	0	-1	1	0	0	2.0	
i 1	4.762619047619047	0.2525	69	200	7	1	12	1	0	0	1	0	0	2.0	
i 1	4.984496598639455	1.5150000000000001	72	1084	5	1	8	1	0	0	1	0	0	2.0	
i 1	4.987380952380953	1.5150000000000001	77	1084	6	5	2	17	0	1	17	0	0	5.0	
i 1	4.987380952380953	1.5150000000000001	74	698	3	5	16	17	0	2	17	0	0	5.0	
i 1	4.988823129251701	1.01	74	698	4	9	4	17	0	2	17	0	0	2.0	
i 1	4.995312925170068	1.5150000000000001	69	698	3	1	15	1	0	-1	1	0	0	2.0	
i 1	5.01478231292517	1.01	74	200	7	2	3	16	0	1	16	0	0	3.0	
i 1	5.233775510204081	0.2525	71	1084	3	24	9	2	0	-2	2	0	0	4.0	
i 1	5.248197278911564	0.505	74	698	3	24	10	2	0	1	2	0	0	4.0	
i 1	5.257571428571429	0.2525	71	698	3	24	4	2	0	1	2	0	0	4.0	
i 1	5.741707482993197	8.8375	63	200	6	13	1	16	0	1	16	0	0	2.7834134008011198	
i 1	5.7431496598639455	8.8375	63	200	6	25	7	1	0	1	1	0	0	2.2996626092540455	
i 1	5.744591836734694	1.01	74	698	2	20	3	2	0	1	2	0	0	3.409894482351147	
i 1	5.744591836734694	5.8075	63	200	4	14	6	16	0	2	16	0	0	5.642238441933669	
i 1	5.751802721088436	1.5150000000000001	74	698	3	24	15	2	0	1	2	0	0	7.409894482351147	
i 1	5.753965986394558	1.01	71	698	1	24	8	2	0	248	2	308	0	7.409894482351147	
i 1	5.763340136054421	0.7575000000000001	71	698	3	24	13	2	0	1	2	0	0	7.409894482351147	
i 1	5.765503401360545	8.8375	63	200	6	14	1	16	0	1	16	0	0	5.642238441933669	
i 1	5.766945578231293	0.7575000000000001	74	698	3	20	4	8	0	1	8	0	0	3.409894482351147	
i 1	5.982333333333333	1.01	77	698	3	3	6	16	0	2	16	0	0	3.0	
i 1	6.003244897959184	1.01	74	1084	4	3	12	17	0	1	17	0	0	3.0	
i 1	6.482333333333333	0.2525	74	698	3	20	15	2	0	-2	2	0	0	3.409894482351147	
i 1	6.49747619047619	0.505	69	698	3	1	14	1	0	0	1	0	0	2.0	
i 1	6.49747619047619	0.7575000000000001	74	698	3	5	10	17	0	1	17	0	0	5.0	
i 1	6.498918367346938	0.505	69	200	7	1	10	1	0	0	1	0	0	2.0	
i 1	6.501802721088436	1.01	74	200	5	5	8	16	0	1	16	0	0	5.0	
i 1	6.516945578231293	0.2525	74	698	2	20	11	2	0	-2	2	0	0	3.409894482351147	
i 1	6.732333333333333	0.505	74	1084	3	24	13	2	0	-2	2	0	0	7.409894482351147	
i 1	6.732333333333333	1.01	71	698	3	24	1	2	0	1	2	0	0	7.409894482351147	
i 1	6.733775510204081	0.505	74	200	3	20	12	2	0	-2	2	0	0	3.409894482351147	
i 1	6.982333333333333	1.2625	72	698	3	24	8	0	0	0	0	0	0	3.0	
i 1	6.986659863945579	0.2525	74	200	7	2	2	16	0	2	16	0	0	3.0	
i 1	6.988823129251701	1.2625	69	1084	4	24	16	0	0	-1	0	0	0	3.0	
i 1	6.990265306122449	0.2525	77	698	3	9	6	17	0	2	17	0	0	2.0	
i 1	7.244591836734694	0.2525	77	698	3	4	10	16	0	1	16	0	0	3.0	
i 1	7.2496394557823125	0.2525	74	698	6	5	1	17	0	1	17	0	0	5.0	
i 1	7.254687074829932	0.7575000000000001	74	698	3	20	1	2	0	1	2	0	0	3.409894482351147	
i 1	7.25612925170068	0.2525	74	1084	4	4	1	17	0	2	17	0	0	3.0	
i 1	7.2568503401360545	0.505	74	698	3	20	2	2	0	1	2	0	0	3.409894482351147	
i 1	7.26478231292517	0.505	71	698	3	24	5	2	0	1	2	0	0	7.409894482351147	
i 1	7.483775510204081	1.2625	77	698	3	5	11	16	0	2	16	0	0	5.0	
i 1	7.4931496598639455	0.505	74	698	4	9	9	17	0	2	17	0	0	2.0	
i 1	7.5068503401360545	0.505	74	200	7	2	13	16	0	1	16	0	0	3.0	
i 1	7.516945578231293	1.2625	77	1084	6	5	13	16	0	2	16	0	0	5.0	
i 1	7.742428571428571	0.2525	74	200	3	20	16	2	0	-2	2	0	0	3.409894482351147	
i 1	7.751802721088436	0.505	74	698	3	20	12	2	0	-2	2	0	0	3.409894482351147	
i 1	7.761176870748299	0.2525	74	1084	3	20	3	2	0	1	2	0	0	3.409894482351147	
i 1	7.983054421768707	0.2525	74	698	2	20	6	2	0	-2	2	0	0	3.409894482351147	
i 1	7.98521768707483	0.2525	71	698	2	20	11	2	0	-2	2	0	0	3.409894482351147	
i 1	7.991707482993197	0.505	74	698	3	24	4	2	0	1	2	0	0	7.409894482351147	
i 1	8.006850340136054	0.505	77	698	3	3	1	16	0	2	16	0	0	3.0	
i 1	8.015503401360544	0.505	74	1084	4	3	13	17	0	1	17	0	0	3.0	
i 1	8.235938775510204	0.505	69	200	7	1	4	1	0	0	1	0	0	2.0	
i 1	8.237380952380953	0.505	71	698	3	24	2	2	0	1	2	0	0	7.409894482351147	
i 1	8.248197278911565	0.2525	74	1084	3	24	4	8	0	-2	8	0	0	7.409894482351147	
i 1	8.249639455782313	0.505	72	698	5	1	2	1	0	-1	1	0	0	2.0	
i 1	8.49242857142857	1.01	77	698	4	9	8	17	0	2	17	0	0	2.0	
i 1	8.509013605442178	1.01	74	200	7	2	16	16	0	2	16	0	0	3.0	
i 1	8.510455782312926	0.505	74	698	3	20	13	2	0	1	2	0	0	3.409894482351147	
i 1	8.73521768707483	0.7575000000000001	69	698	3	1	5	1	0	-1	1	0	0	2.0	
i 1	8.748197278911565	1.2625	74	698	3	20	12	2	0	-2	2	0	0	3.409894482351147	
i 1	8.750360544217687	0.2525	74	200	3	20	10	8	0	1	8	0	0	3.409894482351147	
i 1	8.753244897959183	1.01	74	698	3	5	9	16	0	2	16	0	0	5.0	
i 1	8.761176870748299	0.7575000000000001	72	1084	5	1	5	1	0	0	1	0	0	2.0	
i 1	8.765503401360544	1.01	74	200	5	5	9	17	0	2	17	0	0	5.0	
i 1	8.766945578231292	0.2525	74	1084	3	20	12	2	0	1	2	0	0	3.409894482351147	
i 1	8.986659863945578	1.01	74	698	2	20	16	2	0	1	2	0	0	3.409894482351147	
i 1	8.99747619047619	1.2625	74	698	3	24	10	2	0	1	2	0	0	7.409894482351147	
i 1	9.015503401360544	1.01	74	698	2	20	15	2	0	1	2	0	0	3.409894482351147	
i 1	9.485938775510204	1.01	77	698	3	4	13	16	0	1	16	0	0	3.0	
i 1	9.498918367346938	1.01	74	1084	4	4	6	17	0	2	17	0	0	3.0	
i 1	9.50252380952381	0.2525	69	698	5	1	13	1	0	0	1	0	0	2.0	
i 1	9.504687074829931	0.2525	69	200	7	1	10	1	0	0	1	0	0	2.0	
i 1	9.732333333333333	1.5150000000000001	72	698	3	24	1	0	0	0	0	0	0	3.0	
i 1	9.754687074829931	0.2525	74	698	3	5	1	17	0	2	17	0	0	5.0	
i 1	9.75612925170068	1.5150000000000001	69	1084	4	24	3	0	0	-1	0	0	0	3.0	
i 1	9.76478231292517	0.2525	77	1084	6	5	4	17	0	1	17	0	0	5.0	
i 1	9.983775510204081	0.2525	74	1084	3	20	8	2	0	-2	2	0	0	3.409894482351147	
i 1	9.999639455782313	1.5150000000000001	74	200	5	5	7	16	0	1	16	0	0	5.0	
i 1	10.011897959183674	1.5150000000000001	74	698	6	5	3	17	0	1	17	0	0	5.0	
i 1	10.012619047619047	0.505	74	698	3	20	12	2	0	1	2	0	0	3.409894482351147	
i 1	10.015503401360544	0.2525	74	1084	3	24	6	2	0	1	2	0	0	7.409894482351147	
i 1	10.232333333333333	1.2625	71	698	3	24	12	2	0	1	2	0	0	7.409894482351147	
i 1	10.240986394557822	1.2625	74	698	3	20	11	2	0	1	2	0	0	3.409894482351147	
i 1	10.256850340136054	0.2525	74	698	3	24	9	8	0	-2	8	0	0	7.409894482351147	
i 1	10.498197278911565	1.01	74	698	2	20	10	8	0	-2	8	0	0	3.409894482351147	
i 1	10.501802721088435	1.01	74	698	3	24	8	2	0	1	2	0	0	7.409894482351147	
i 1	10.515503401360544	0.2525	74	698	4	9	4	17	0	2	17	0	0	2.0	
i 1	10.516945578231292	0.2525	74	200	7	2	14	16	0	1	16	0	0	3.0	
i 1	10.74747619047619	0.2525	74	1084	4	3	3	17	0	1	17	0	0	3.0	
i 1	10.765503401360544	0.2525	77	698	3	3	15	16	0	2	16	0	0	3.0	
i 1	11.00612925170068	0.505	74	200	7	2	6	16	0	2	16	0	0	3.0	
i 1	11.006850340136054	0.505	77	698	4	9	10	17	0	2	17	0	0	2.0	
i 1	11.249639455782313	0.505	69	200	7	1	12	1	0	0	1	0	0	2.0	
i 1	11.266224489795919	0.505	72	698	5	1	12	1	0	-1	1	0	0	2.0	
i 1	11.483054421768708	1.2625	74	698	2	20	1	2	0	1	2	0	0	5.161005743443372	
i 1	11.488823129251701	0.505	74	1084	4	4	1	17	0	2	17	0	0	3.0	
i 1	11.49026530612245	0.505	77	698	3	4	6	16	0	1	16	0	0	3.0	
i 1	11.49387074829932	1.2625	71	698	3	24	15	2	0	1	2	0	0	9.161005743443372	
i 1	11.494591836734694	3.0300000000000002	63	1084	5	25	5	1	0	2	1	0	0	2.2996626092540455	
i 1	11.495312925170069	1.5150000000000001	77	1084	4	5	11	16	0	2	16	0	0	5.0	
i 1	11.496034013605442	3.0300000000000002	63	1084	3	13	7	1	0	1	1	0	0	1.4105596104834173	
i 1	11.501081632653062	3.0300000000000002	74	698	3	24	7	2	0	1	2	0	0	9.161005743443372	
i 1	11.506850340136054	3.0300000000000002	63	1084	5	15	2	1	0	2	1	0	0	3.247315634267973	
i 1	11.509013605442178	3.0300000000000002	61	200	6	14	6	1	0	1	1	0	0	4.17512010120168	
i 1	11.511897959183674	3.0300000000000002	74	698	1	24	3	8	0	248	8	308	0	9.161005743443372	
i 1	11.512619047619047	1.5150000000000001	77	698	3	5	6	16	0	2	16	0	0	5.0	
i 1	11.515503401360544	3.0300000000000002	63	200	6	14	15	16	0	2	16	0	0	5.642238441933669	
i 1	11.516224489795919	3.0300000000000002	74	698	2	20	10	8	0	-2	8	0	0	5.161005743443372	
i 1	11.743149659863946	1.2625	72	1084	6	1	11	1	0	0	1	0	0	2.0	
i 1	11.743149659863946	1.2625	69	698	3	1	3	1	0	-1	1	0	0	2.0	
i 1	11.982333333333333	1.01	74	200	7	2	3	16	0	1	16	0	0	3.0	
i 1	12.00973469387755	1.01	74	698	4	9	2	17	0	2	17	0	0	2.0	
i 1	12.767666666666667	0.505	71	698	1	24	6	2	0	252	2	307	0	9.161005743443372	
i 1	12.989544217687074	1.01	74	698	6	5	4	16	0	2	16	0	0	5.0	
i 1	12.99387074829932	0.505	69	698	5	1	7	1	0	0	1	0	0	2.0	
i 1	12.995312925170069	1.01	77	698	4	3	14	16	0	2	16	0	0	3.0	
i 1	13.001081632653062	0.505	69	200	7	1	16	1	0	0	1	0	0	2.0	
i 1	13.006850340136054	1.01	74	200	5	5	12	17	0	2	17	0	0	5.0	
i 1	13.00757142857143	1.01	74	1084	5	3	1	17	0	1	17	0	0	3.0	
i 1	13.246034013605442	1.01	71	698	3	24	15	2	0	1	2	0	0	9.161005743443372	
i 1	13.249639455782313	1.01	74	698	2	20	14	2	0	1	2	0	0	5.161005743443372	
i 1	13.482333333333333	0.7575000000000001	69	1084	4	24	9	0	0	-1	0	0	0	3.0	
i 1	13.515503401360544	0.7575000000000001	72	698	3	24	4	0	0	0	0	0	0	3.0	
i 1	13.999639455782313	0.2525	77	698	4	9	4	17	0	2	17	0	0	2.0	
i 1	14.001802721088435	0.505	77	1084	6	5	3	17	0	1	17	0	0	5.0	
i 1	14.014061224489796	0.2525	74	200	7	2	15	16	0	2	16	0	0	3.0	
i 1	14.01478231292517	0.505	74	698	3	5	8	17	0	2	17	0	0	5.0	
i 1	14.232333333333333	0.2525	69	200	7	1	9	1	0	0	1	0	0	2.0	
i 1	14.233775510204081	0.2525	77	698	3	4	14	16	0	1	16	0	0	3.0	
i 1	14.24026530612245	0.2525	74	1084	4	4	8	17	0	2	17	0	0	3.0	
i 1	14.254687074829931	0.2525	72	698	5	1	2	1	0	-1	1	0	0	2.0	
i 1	14.483054421768708	1.2625	69	386	5	1	7	1	0	-1	1	0	0	2.0	
i 1	14.483054421768708	1.2625	61	386	4	13	2	1	0	2	1	0	0	1.4105596104834173	
i 1	14.48521768707483	0.2525	71	1088	3	20	7	2	0	-2	2	0	0	5.161005743443372	
i 1	14.485938775510204	31.5625	61	702	5	14	1	16	0	1	16	0	0	5.642238441933669	
i 1	14.488823129251701	14.3925	61	702	5	25	5	1	0	2	1	0	0	2.2996626092540455	
i 1	14.489544217687074	1.2625	72	702	6	1	12	1	0	0	1	0	0	2.0	
i 1	14.49026530612245	2.7775	63	702	5	13	4	1	0	2	1	0	0	2.7834134008011198	
i 1	14.491707482993197	0.2525	74	1088	2	20	5	2	0	-2	2	0	0	5.161005743443372	
i 1	14.49242857142857	20.2	63	386	1	27	6	1	0	252	1	307	0	3.0662168123387277	
i 1	14.493149659863946	31.5625	61	702	5	14	8	1	0	1	1	0	0	5.642238441933669	
i 1	14.494591836734694	1.2625	61	386	4	7	2	1	0	1	1	0	0	4.231678831450252	
i 1	14.495312925170069	20.2	63	702	5	25	13	1	0	1	1	0	0	2.2996626092540455	
i 1	14.49747619047619	0.505	77	386	5	3	2	17	0	1	17	0	0	3.0	
i 1	14.498197278911565	0.2525	71	386	3	24	2	2	0	1	2	0	0	9.161005743443372	
i 1	14.499639455782313	0.505	77	386	3	4	9	17	0	2	17	0	0	3.0	
i 1	14.500360544217687	1.01	74	386	3	5	2	16	0	1	16	0	0	5.0	
i 1	14.503244897959183	1.01	77	386	5	5	6	16	0	1	16	0	0	5.0	
i 1	14.50757142857143	0.2525	74	1088	2	20	14	8	0	1	8	0	0	5.161005743443372	
i 1	14.514061224489796	1.2625	61	386	5	15	13	1	0	1	1	0	0	3.247315634267973	
i 1	14.515503401360544	31.5625	61	702	5	14	9	16	0	1	16	0	0	4.17512010120168	
i 1	14.516945578231292	1.2625	61	386	5	25	2	1	0	2	1	0	0	2.2996626092540455	
i 1	14.732333333333333	1.01	71	1088	3	24	4	2	0	-2	2	0	0	9.161005743443372	
i 1	14.753244897959183	0.7575000000000001	74	386	2	20	2	2	0	-2	2	0	0	5.161005743443372	
i 1	14.75612925170068	0.7575000000000001	74	386	3	20	7	2	0	1	2	0	0	5.161005743443372	
i 1	14.75757142857143	0.7575000000000001	74	386	3	24	4	2	0	-2	2	0	0	9.161005743443372	
i 1	15.011897959183674	0.505	77	386	4	3	14	16	0	1	16	0	0	3.0	
i 1	15.015503401360544	0.505	77	702	6	2	9	16	0	2	16	0	0	3.0	
i 1	15.482333333333333	0.2525	77	386	4	4	9	17	0	1	17	0	0	3.0	
i 1	15.483054421768708	0.2525	77	386	3	5	8	17	0	1	17	0	0	5.0	
i 1	15.48521768707483	0.2525	71	702	3	20	13	2	0	1	2	0	0	5.161005743443372	
i 1	15.494591836734694	0.2525	71	386	3	24	11	2	0	1	2	0	0	9.161005743443372	
i 1	15.500360544217687	0.2525	74	386	3	20	10	2	0	-2	2	0	0	5.161005743443372	
i 1	15.501081632653062	0.2525	77	702	5	5	5	17	0	1	17	0	0	5.0	
i 1	15.506850340136054	0.2525	77	1088	4	9	13	16	0	2	16	0	0	2.0	
i 1	15.733775510204081	1.5150000000000001	77	702	5	5	4	16	0	2	16	0	0	5.0	
i 1	15.734496598639456	0.505	74	386	2	20	6	2	0	-2	2	0	0	5.161005743443372	
i 1	15.738823129251701	1.5150000000000001	77	1088	6	5	16	16	0	2	16	0	0	5.0	
i 1	15.741707482993197	1.01	77	386	4	3	12	16	0	1	16	0	0	3.0	
i 1	15.745312925170069	1.01	74	386	3	20	3	2	0	1	2	0	0	5.161005743443372	
i 1	15.746034013605442	7.3225	63	702	5	15	9	1	0	1	1	0	0	3.247315634267973	
i 1	15.751802721088435	1.5150000000000001	61	702	4	7	3	16	0	2	16	0	0	4.231678831450252	
i 1	15.75252380952381	0.505	71	1088	3	20	12	2	0	-2	2	0	0	5.161005743443372	
i 1	15.753244897959183	24.745	61	702	5	25	5	1	0	2	1	0	0	2.2996626092540455	
i 1	15.760455782312926	0.505	72	702	6	1	13	1	0	0	1	0	0	2.0	
i 1	15.760455782312926	0.505	74	1088	2	20	12	8	0	-2	8	0	0	5.161005743443372	
i 1	15.760455782312926	1.5150000000000001	61	702	4	13	7	1	0	1	1	0	0	1.4105596104834173	
i 1	15.761176870748299	1.01	74	702	5	3	11	16	0	1	16	0	0	3.0	
i 1	15.761897959183674	0.505	72	1088	5	1	3	1	0	0	1	0	0	2.0	
i 1	16.23521768707483	0.2525	71	702	3	20	13	2	0	1	2	0	0	5.161005743443372	
i 1	16.248197278911565	1.2625	69	386	5	1	10	1	0	-1	1	0	0	2.0	
i 1	16.253244897959185	0.2525	74	702	4	24	9	2	0	-2	2	0	0	9.161005743443372	
i 1	16.255408163265304	1.2625	72	702	6	1	14	1	0	0	1	0	0	2.0	
i 1	16.264061224489797	0.2525	71	386	3	24	7	2	0	1	2	0	0	9.161005743443372	
i 1	16.492428571428572	0.2525	74	386	3	24	13	2	0	1	2	0	0	9.161005743443372	
i 1	16.49531292517007	0.505	71	1088	3	24	9	2	0	-2	2	0	0	9.161005743443372	
i 1	16.50468707482993	0.2525	71	386	2	20	4	2	0	-2	2	0	0	5.161005743443372	
i 1	16.737380952380953	0.2525	74	1088	4	9	2	16	0	1	16	0	0	2.0	
i 1	16.738102040816326	0.2525	74	702	3	20	15	2	0	-2	2	0	0	5.161005743443372	
i 1	16.75036054421769	0.2525	71	702	3	20	15	2	0	-2	2	0	0	5.161005743443372	
i 1	16.752523809523808	0.2525	71	386	3	24	3	2	0	1	2	0	0	9.161005743443372	
i 1	16.765503401360544	0.2525	77	702	6	2	12	16	0	2	16	0	0	3.0	
i 1	16.983054421768706	2.02	74	1088	2	20	6	2	0	-2	2	0	0	5.161005743443372	
i 1	16.985938775510203	2.02	71	1088	3	20	2	2	0	-2	2	0	0	5.161005743443372	
i 1	16.9888231292517	0.2525	77	386	3	4	16	17	0	2	17	0	0	3.0	
i 1	16.996755102040815	0.7575000000000001	74	386	3	20	9	2	0	1	2	0	0	5.161005743443372	
i 1	16.99963945578231	0.2525	77	702	4	4	5	17	0	1	17	0	0	3.0	
i 1	17.003244897959185	0.7575000000000001	74	386	2	20	6	2	0	-2	2	0	0	5.161005743443372	
i 1	17.237380952380953	40.6525	61	702	5	13	16	1	0	1	1	0	0	1.4105596104834173	
i 1	17.238102040816326	0.505	74	702	6	2	10	17	0	2	17	0	0	3.0	
i 1	17.238102040816326	5.8075	61	702	4	7	13	16	0	2	16	0	0	4.231678831450252	
i 1	17.24531292517007	1.5150000000000001	77	386	3	5	8	17	0	1	17	0	0	5.0	
i 1	17.25108163265306	1.5150000000000001	74	702	5	5	4	17	0	1	17	0	0	5.0	
i 1	17.251802721088435	28.785	63	702	5	13	16	1	0	2	1	0	0	2.7834134008011198	
i 1	17.259013605442178	11.615	63	702	5	15	4	1	0	2	1	0	0	3.247315634267973	
i 1	17.25973469387755	29.0375	63	702	5	25	4	1	0	2	1	0	0	2.2996626092540455	
i 1	17.265503401360544	0.505	77	1088	4	9	4	16	0	2	16	0	0	2.0	
i 1	17.488102040816326	0.505	72	702	6	1	5	1	0	0	1	0	0	2.0	
i 1	17.49891836734694	0.505	72	1088	5	1	15	0	0	0	0	0	0	2.0	
i 1	17.73665986394558	0.505	77	386	4	3	15	16	0	1	16	0	0	3.0	
i 1	17.757571428571428	0.505	74	702	5	3	2	16	0	1	16	0	0	3.0	
i 1	18.010455782312924	0.7575000000000001	69	702	4	24	12	0	0	0	0	0	0	3.0	
i 1	18.01334013605442	0.7575000000000001	72	386	3	24	10	1	0	-1	1	0	0	3.0	
i 1	18.23665986394558	1.01	77	702	6	2	1	16	0	2	16	0	0	3.0	
i 1	18.240986394557822	1.01	74	1088	4	9	8	16	0	1	16	0	0	2.0	
i 1	18.737380952380953	0.2525	72	1088	5	1	16	1	0	0	1	0	0	2.0	
i 1	18.74531292517007	0.2525	72	702	6	1	15	1	0	0	1	0	0	2.0	
i 1	18.747476190476192	1.01	77	702	5	5	15	17	0	1	17	0	0	5.0	
i 1	18.767666666666667	1.01	74	1088	6	5	10	16	0	2	16	0	0	5.0	
i 1	18.996034013605442	1.5150000000000001	69	386	5	1	8	1	0	-1	1	0	0	2.0	
i 1	19.001802721088435	0.2525	74	702	3	20	1	2	0	1	2	0	0	5.161005743443372	
i 1	19.00612925170068	0.2525	71	702	3	20	4	2	0	1	2	0	0	5.161005743443372	
i 1	19.00612925170068	0.2525	71	386	3	24	2	2	0	1	2	0	0	9.161005743443372	
i 1	19.009013605442178	1.5150000000000001	72	702	6	1	10	1	0	0	1	0	0	2.0	
i 1	19.011897959183674	0.7575000000000001	71	1088	3	24	10	2	0	-2	2	0	0	9.161005743443372	
i 1	19.244591836734696	1.01	77	702	4	4	2	17	0	1	17	0	0	3.0	
i 1	19.246034013605442	1.01	77	386	4	4	16	17	0	2	17	0	0	3.0	
i 1	19.25036054421769	0.2525	74	386	2	24	13	2	0	-2	2	0	0	9.161005743443372	
i 1	19.255408163265304	0.505	74	386	3	20	6	2	0	1	2	0	0	5.161005743443372	
i 1	19.257571428571428	0.2525	74	386	2	20	7	2	0	-2	2	0	0	5.161005743443372	
i 1	19.50036054421769	0.2525	74	702	3	24	5	2	0	1	2	0	0	9.161005743443372	
i 1	19.50468707482993	0.2525	74	702	3	20	12	2	0	1	2	0	0	5.161005743443372	
i 1	19.734496598639456	1.2625	74	702	5	5	16	17	0	2	17	0	0	5.0	
i 1	19.737380952380953	0.505	71	1088	3	20	7	2	0	-2	2	0	0	5.161005743443372	
i 1	19.743149659863946	1.2625	74	386	3	5	6	16	0	1	16	0	0	5.0	
i 1	19.74531292517007	2.02	71	1088	1	24	13	2	0	252	2	307	0	9.161005743443372	
i 1	19.756850340136054	0.505	74	1088	2	20	14	2	0	1	2	0	0	5.161005743443372	
i 1	20.233054421768706	0.2525	74	702	6	2	9	17	0	2	17	0	0	3.0	
i 1	20.240986394557822	0.7575000000000001	71	386	2	20	9	2	0	1	2	0	0	5.161005743443372	
i 1	20.243149659863946	0.7575000000000001	74	386	3	20	8	2	0	1	2	0	0	5.161005743443372	
i 1	20.267666666666667	0.2525	77	1088	4	9	9	16	0	2	16	0	0	2.0	
i 1	20.488102040816326	0.505	72	702	6	1	5	1	0	0	1	0	0	2.0	
i 1	20.50108163265306	0.505	72	1088	5	1	11	0	0	0	0	0	0	2.0	
i 1	20.506850340136054	0.2525	74	702	5	3	3	16	0	1	16	0	0	3.0	
i 1	20.507571428571428	0.2525	77	386	4	3	4	16	0	1	16	0	0	3.0	
i 1	20.75036054421769	0.505	77	702	6	2	1	16	0	2	16	0	0	3.0	
i 1	20.75468707482993	0.505	74	1088	4	9	3	16	0	1	16	0	0	2.0	
i 1	20.994591836734696	0.2525	71	386	3	24	3	2	0	1	2	0	0	9.161005743443372	
i 1	20.998197278911565	1.01	77	1088	6	5	4	16	0	2	16	0	0	5.0	
i 1	21.002523809523808	1.01	77	702	5	5	14	16	0	2	16	0	0	5.0	
i 1	21.00973469387755	1.2625	69	702	4	24	12	0	0	0	0	0	0	3.0	
i 1	21.0111768707483	1.2625	72	386	4	24	12	1	0	-1	1	0	0	3.0	
i 1	21.011897959183674	0.2525	71	702	3	20	15	2	0	-2	2	0	0	5.161005743443372	
i 1	21.233054421768706	0.505	71	386	2	20	7	2	0	1	2	0	0	5.161005743443372	
i 1	21.233054421768706	0.505	74	386	3	20	10	2	0	1	2	0	0	5.161005743443372	
i 1	21.25108163265306	0.505	77	386	4	4	6	17	0	2	17	0	0	3.0	
i 1	21.25108163265306	0.505	71	1088	3	20	4	2	0	-2	2	0	0	5.161005743443372	
i 1	21.255408163265304	0.505	74	1088	2	20	8	2	0	1	2	0	0	5.161005743443372	
i 1	21.2611768707483	0.505	77	702	4	4	16	17	0	1	17	0	0	3.0	
i 1	21.733775510204083	1.01	77	1088	4	9	8	16	0	2	16	0	0	2.0	
i 1	21.752523809523808	1.01	74	702	6	2	1	17	0	2	17	0	0	3.0	
i 1	21.764061224489797	0.7575000000000001	71	386	2	24	3	2	0	1	2	0	0	9.161005743443372	
i 1	21.76478231292517	1.01	71	1088	3	24	7	2	0	-2	2	0	0	9.161005743443372	
i 1	21.982333333333333	0.2525	74	702	5	5	3	17	0	1	17	0	0	5.0	
i 1	21.989544217687076	0.2525	77	386	6	5	9	17	0	1	17	0	0	5.0	
i 1	22.24963945578231	1.5150000000000001	77	702	5	5	9	17	0	1	17	0	0	5.0	
i 1	22.256850340136054	0.505	72	702	6	1	10	1	0	0	1	0	0	2.0	
i 1	22.25973469387755	0.505	72	1088	5	1	5	1	0	0	1	0	0	2.0	
i 1	22.25973469387755	1.5150000000000001	74	1088	6	5	7	16	0	2	16	0	0	5.0	
i 1	22.48665986394558	0.2525	74	702	3	24	1	2	0	-2	2	0	0	9.161005743443372	
i 1	22.489544217687076	0.2525	71	702	3	20	8	8	0	-2	8	0	0	5.161005743443372	
i 1	22.493149659863946	0.505	74	386	3	20	15	2	0	1	2	0	0	5.161005743443372	
i 1	22.73521768707483	0.7575000000000001	72	702	6	1	9	1	0	0	1	0	0	2.0	
i 1	22.738102040816326	0.2525	71	1088	3	20	3	2	0	-2	2	0	0	5.161005743443372	
i 1	22.74387074829932	0.2525	74	386	2	20	4	2	0	-2	2	0	0	5.161005743443372	
i 1	22.747476190476192	1.01	77	386	4	3	8	16	0	1	16	0	0	3.0	
i 1	22.74891836734694	0.7575000000000001	69	386	5	1	15	1	0	-1	1	0	0	2.0	
i 1	22.753965986394558	1.01	74	702	5	3	2	16	0	1	16	0	0	3.0	
i 1	22.762619047619047	0.2525	74	1088	2	20	8	2	0	-2	2	0	0	5.161005743443372	
i 1	22.988102040816326	0.505	71	1088	3	20	15	2	0	-2	2	0	0	5.597064345973514	
i 1	22.991707482993196	0.505	71	386	1	24	3	2	0	248	2	308	0	9.597064345973514	
i 1	22.99387074829932	34.845	63	702	5	15	8	1	0	1	1	0	0	3.247315634267973	
i 1	22.99531292517007	36.1075	61	702	6	7	8	16	0	2	16	0	0	4.231678831450252	
i 1	23.006850340136054	11.615	63	1088	4	16	3	1	0	2	1	0	0	3.711217867734826	
i 1	23.012619047619047	0.7575000000000001	74	386	2	20	12	2	0	-2	2	0	0	5.597064345973514	
i 1	23.012619047619047	1.7675	74	386	3	20	6	2	0	1	2	0	0	5.597064345973514	
i 1	23.01334013605442	0.505	74	1088	2	20	10	2	0	-2	2	0	0	5.597064345973514	
i 1	23.01478231292517	22.9775	61	1088	4	26	7	16	0	2	16	0	0	2.2996626092540455	
i 1	23.498197278911565	0.2525	72	1088	5	1	13	0	0	0	0	0	0	2.0	
i 1	23.49891836734694	0.505	71	1088	2	24	10	2	0	-2	2	0	0	9.597064345973514	
i 1	23.50036054421769	0.2525	71	386	2	24	1	2	0	1	2	0	0	9.597064345973514	
i 1	23.514061224489797	0.2525	72	702	6	1	8	1	0	0	1	0	0	2.0	
i 1	23.735938775510203	0.7575000000000001	74	386	3	5	6	16	0	1	16	0	0	5.0	
i 1	23.74387074829932	1.5150000000000001	72	386	4	24	4	1	0	-1	1	0	0	3.0	
i 1	23.746755102040815	0.2525	77	702	6	2	7	16	0	2	16	0	0	3.0	
i 1	23.753965986394558	0.2525	74	702	3	20	9	2	0	1	2	0	0	5.597064345973514	
i 1	23.75973469387755	1.5150000000000001	69	702	4	24	14	0	0	0	0	0	0	3.0	
i 1	23.76334013605442	0.2525	74	702	3	24	10	2	0	-2	2	0	0	9.597064345973514	
i 1	23.765503401360544	1.5150000000000001	74	702	5	5	5	17	0	2	17	0	0	5.0	
i 1	23.766945578231294	0.2525	74	1088	4	9	14	16	0	1	16	0	0	2.0	
i 1	23.985938775510203	1.7675	74	1088	2	20	6	8	0	-2	8	0	0	5.597064345973514	
i 1	23.988102040816326	0.2525	77	386	4	4	12	17	0	2	17	0	0	3.0	
i 1	24.005408163265304	1.7675	71	1088	3	20	16	2	0	-2	2	0	0	5.597064345973514	
i 1	24.006850340136054	0.7575000000000001	71	386	1	24	9	2	0	252	2	307	0	9.597064345973514	
i 1	24.011897959183674	0.7575000000000001	71	386	2	20	9	2	0	-2	2	0	0	5.597064345973514	
i 1	24.012619047619047	0.2525	77	702	4	4	1	17	0	1	17	0	0	3.0	
i 1	24.252523809523808	0.505	77	1088	5	9	7	16	0	2	16	0	0	2.0	
i 1	24.267666666666667	0.505	74	702	6	2	9	17	0	2	17	0	0	3.0	
i 1	24.49026530612245	0.7575000000000001	74	386	6	5	5	16	0	1	16	0	0	5.0	
i 1	24.740986394557822	1.7675	71	1088	2	24	14	2	0	-2	2	0	0	9.597064345973514	
i 1	24.746034013605442	1.01	71	386	2	24	7	2	0	1	2	0	0	9.597064345973514	
i 1	24.755408163265304	0.505	77	386	4	3	3	16	0	1	16	0	0	3.0	
i 1	24.760455782312924	0.505	74	702	5	3	11	16	0	1	16	0	0	3.0	
i 1	25.24387074829932	0.505	72	1088	6	1	10	1	0	0	1	0	0	2.0	
i 1	25.246755102040815	1.01	77	702	6	2	1	16	0	2	16	0	0	3.0	
i 1	25.25973469387755	0.505	72	702	4	1	13	1	0	0	1	0	0	2.0	
i 1	25.2611768707483	1.01	77	702	5	5	2	16	0	2	16	0	0	5.0	
i 1	25.261897959183674	1.01	77	1088	4	5	15	16	0	2	16	0	0	5.0	
i 1	25.26478231292517	1.01	74	1088	4	9	7	16	0	1	16	0	0	2.0	
i 1	25.742428571428572	1.2625	72	702	6	1	6	1	0	0	1	0	0	2.0	
i 1	25.744591836734696	1.2625	69	386	5	1	9	1	0	-1	1	0	0	2.0	
i 1	25.74891836734694	0.2525	71	386	3	24	12	2	0	1	2	0	0	9.597064345973514	
i 1	25.76478231292517	0.2525	74	702	3	20	10	2	0	-2	2	0	0	5.597064345973514	
i 1	25.766224489795917	0.2525	74	702	3	20	6	8	0	1	8	0	0	5.597064345973514	
i 1	25.989544217687076	0.505	71	386	2	24	16	8	0	-2	8	0	0	9.597064345973514	
i 1	25.994591836734696	3.0300000000000002	74	386	3	20	13	2	0	1	2	0	0	5.597064345973514	
i 1	26.014061224489797	0.505	74	386	2	20	16	2	0	1	2	0	0	5.597064345973514	
i 1	26.239544217687076	1.01	77	386	4	4	8	17	0	2	17	0	0	3.0	
i 1	26.248197278911565	1.2625	77	386	6	5	10	17	0	1	17	0	0	5.0	
i 1	26.253244897959185	1.2625	74	702	5	5	6	17	0	1	17	0	0	5.0	
i 1	26.25612925170068	1.01	77	702	4	4	10	17	0	1	17	0	0	3.0	
i 1	26.488102040816326	0.2525	71	386	3	24	9	2	0	1	2	0	0	9.597064345973514	
i 1	26.514061224489797	0.2525	71	702	3	24	14	2	0	-2	2	0	0	9.597064345973514	
i 1	26.517666666666667	0.2525	71	702	3	20	16	2	0	-2	2	0	0	5.597064345973514	
i 1	26.733054421768706	2.02	71	386	2	20	12	8	0	-2	8	0	0	5.597064345973514	
i 1	26.74963945578231	1.2625	71	1088	3	20	6	2	0	-2	2	0	0	5.597064345973514	
i 1	26.762619047619047	1.2625	71	1088	2	20	11	8	0	1	8	0	0	5.597064345973514	
i 1	26.993149659863946	0.505	72	1088	5	1	2	0	0	0	0	0	0	2.0	
i 1	27.002523809523808	0.505	72	702	6	1	15	1	0	0	1	0	0	2.0	
i 1	27.25108163265306	0.2525	74	702	6	2	15	17	0	2	17	0	0	3.0	
i 1	27.25108163265306	0.2525	77	1088	5	9	2	16	0	2	16	0	0	2.0	
i 1	27.482333333333333	0.7575000000000001	72	386	4	24	3	1	0	-1	1	0	0	3.0	
i 1	27.496755102040815	0.2525	74	702	5	3	9	16	0	1	16	0	0	3.0	
i 1	27.496755102040815	1.01	74	1088	6	5	2	16	0	2	16	0	0	5.0	
i 1	27.498197278911565	0.7575000000000001	69	702	4	24	8	0	0	0	0	0	0	3.0	
i 1	27.501802721088435	0.2525	77	386	4	3	6	16	0	1	16	0	0	3.0	
i 1	27.502523809523808	1.01	77	702	5	5	6	17	0	1	17	0	0	5.0	
i 1	27.739544217687076	0.505	74	1088	4	9	16	16	0	1	16	0	0	2.0	
i 1	27.75612925170068	0.505	77	702	6	2	16	16	0	2	16	0	0	3.0	
i 1	27.996755102040815	0.7575000000000001	71	386	3	24	3	2	0	1	2	0	0	9.597064345973514	
i 1	28.003244897959185	0.7575000000000001	71	1088	2	20	12	2	0	1	2	0	0	5.597064345973514	
i 1	28.235938775510203	0.505	77	386	4	4	3	17	0	2	17	0	0	3.0	
i 1	28.246034013605442	0.2525	72	702	4	1	2	1	0	0	1	0	0	2.0	
i 1	28.252523809523808	0.505	77	702	4	4	16	17	0	1	17	0	0	3.0	
i 1	28.255408163265304	0.2525	72	1088	6	1	9	1	0	0	1	0	0	2.0	
i 1	28.492428571428572	0.2525	74	386	6	5	5	16	0	1	16	0	0	5.0	
i 1	28.494591836734696	1.5150000000000001	69	386	5	1	10	1	0	-1	1	0	0	2.0	
i 1	28.50036054421769	0.2525	74	702	5	5	10	17	0	2	17	0	0	5.0	
i 1	28.5111768707483	1.5150000000000001	72	702	6	1	2	1	0	0	1	0	0	2.0	
i 1	28.733054421768706	1.5150000000000001	77	702	5	5	2	16	0	2	16	0	0	5.0	
i 1	28.737380952380953	11.615	63	1088	4	16	6	16	0	2	16	0	0	3.711217867734826	
i 1	28.748197278911565	1.01	77	1088	5	9	8	16	0	2	16	0	0	2.0	
i 1	28.74963945578231	1.01	74	702	6	2	7	17	0	2	17	0	0	3.0	
i 1	28.75108163265306	30.3	63	702	5	15	13	1	0	2	1	0	0	3.247315634267973	
i 1	28.75612925170068	1.5150000000000001	77	1088	4	5	16	16	0	2	16	0	0	5.0	
i 1	28.75612925170068	1.01	71	1088	2	20	5	2	0	-2	2	0	0	5.597064345973514	
i 1	28.758292517006804	0.2525	71	702	3	24	6	2	0	-2	2	0	0	9.597064345973514	
i 1	28.75973469387755	0.2525	74	702	3	20	13	2	0	-2	2	0	0	5.597064345973514	
i 1	28.76334013605442	17.17	63	1088	4	26	15	1	0	1	1	0	0	2.2996626092540455	
i 1	28.988102040816326	0.7575000000000001	71	386	2	24	1	2	0	1	2	0	0	9.597064345973514	
i 1	28.99963945578231	1.01	71	1088	2	24	14	2	0	-2	2	0	0	9.597064345973514	
i 1	29.00612925170068	0.7575000000000001	71	1088	3	20	14	2	0	-2	2	0	0	5.597064345973514	
i 1	29.73521768707483	0.2525	71	702	3	20	2	2	0	1	2	0	0	5.597064345973514	
i 1	29.74387074829932	1.2625	71	386	3	24	5	2	0	1	2	0	0	9.597064345973514	
i 1	29.746755102040815	0.2525	74	702	4	20	15	2	0	1	2	0	0	5.597064345973514	
i 1	29.748197278911565	1.01	74	702	5	3	16	16	0	1	16	0	0	3.0	
i 1	29.766224489795917	1.01	77	386	4	3	1	16	0	1	16	0	0	3.0	
i 1	29.989544217687076	2.2725	74	386	3	20	12	2	0	1	2	0	0	5.597064345973514	
i 1	29.99026530612245	0.505	72	702	4	1	12	1	0	0	1	0	0	2.0	
i 1	29.99387074829932	2.2725	71	386	2	20	12	8	0	-2	8	0	0	5.597064345973514	
i 1	29.998197278911565	1.01	74	1088	2	20	5	2	0	1	2	0	0	5.597064345973514	
i 1	30.006850340136054	0.505	72	1088	6	1	12	0	0	0	0	0	0	2.0	
i 1	30.24387074829932	1.5150000000000001	74	702	5	5	9	17	0	1	17	0	0	5.0	
i 1	30.262619047619047	1.5150000000000001	77	386	6	5	8	17	0	1	17	0	0	5.0	
i 1	30.492428571428572	1.2625	69	702	4	24	3	0	0	0	0	0	0	3.0	
i 1	30.50612925170068	1.2625	72	386	4	24	8	1	0	-1	1	0	0	3.0	
i 1	30.75612925170068	0.2525	77	702	6	2	6	16	0	2	16	0	0	3.0	
i 1	30.756850340136054	0.2525	74	1088	5	9	4	16	0	1	16	0	0	2.0	
i 1	30.988102040816326	3.535	71	386	2	24	8	8	0	1	8	0	0	9.597064345973514	
i 1	30.9888231292517	0.2525	77	702	4	4	3	17	0	1	17	0	0	3.0	
i 1	30.9888231292517	0.2525	77	386	4	4	4	17	0	2	17	0	0	3.0	
i 1	30.993149659863946	3.535	71	1088	2	24	4	2	0	-2	2	0	0	9.597064345973514	
i 1	31.233054421768706	0.505	74	702	6	2	1	17	0	2	17	0	0	3.0	
i 1	31.242428571428572	0.505	77	1088	5	9	8	16	0	2	16	0	0	2.0	
i 1	31.732333333333333	1.01	74	1088	4	5	14	16	0	2	16	0	0	5.0	
i 1	31.734496598639456	0.505	72	702	4	1	9	1	0	0	1	0	0	2.0	
i 1	31.747476190476192	1.01	77	702	5	5	7	17	0	1	17	0	0	5.0	
i 1	31.75108163265306	0.505	72	1088	6	1	1	1	0	0	1	0	0	2.0	
i 1	31.75108163265306	0.505	77	386	4	3	10	16	0	1	16	0	0	3.0	
i 1	31.751802721088435	0.505	74	702	5	3	5	16	0	1	16	0	0	3.0	
i 1	32.243149659863946	0.7575000000000001	72	702	6	1	9	1	0	0	1	0	0	2.0	
i 1	32.24747619047619	1.01	77	702	6	2	14	16	0	2	16	0	0	3.0	
i 1	32.24819727891156	0.7575000000000001	74	1088	2	20	15	2	0	1	2	0	0	5.597064345973514	
i 1	32.25180272108844	0.7575000000000001	69	386	5	1	13	1	0	-1	1	0	0	2.0	
i 1	32.2611768707483	1.01	74	1088	5	9	11	16	0	1	16	0	0	2.0	
i 1	32.2611768707483	0.7575000000000001	71	386	3	24	1	2	0	1	2	0	0	9.597064345973514	
i 1	32.73810204081633	1.2625	74	702	5	5	11	17	0	2	17	0	0	5.0	
i 1	32.75252380952381	1.2625	74	386	6	5	3	16	0	1	16	0	0	5.0	
i 1	32.98521768707483	1.01	71	386	2	20	3	8	0	-2	8	0	0	5.597064345973514	
i 1	32.99531292517007	0.2525	72	702	4	1	11	1	0	0	1	0	0	2.0	
i 1	33.00252380952381	1.01	74	386	3	20	4	2	0	1	2	0	0	5.597064345973514	
i 1	33.01478231292517	0.2525	72	1088	6	1	16	0	0	0	0	0	0	2.0	
i 1	33.23449659863945	1.01	77	702	4	4	6	17	0	1	17	0	0	3.0	
i 1	33.236659863945576	1.5150000000000001	72	386	4	24	16	1	0	-1	1	0	0	3.0	
i 1	33.24098639455782	1.01	77	386	4	4	12	17	0	2	17	0	0	3.0	
i 1	33.24747619047619	1.5150000000000001	69	702	4	24	13	0	0	0	0	0	0	3.0	
i 1	33.98521768707483	1.01	77	1088	4	5	16	16	0	2	16	0	0	5.0	
i 1	33.99387074829932	0.505	77	702	5	5	1	16	0	2	16	0	0	5.0	
i 1	34.00180272108844	0.505	71	1088	2	20	1	2	0	-2	2	0	0	5.597064345973514	
i 1	34.0082925170068	0.505	71	1088	3	20	11	2	0	-2	2	0	0	5.597064345973514	
i 1	34.239544217687076	0.2525	74	702	6	2	5	17	0	2	17	0	0	3.0	
i 1	34.240265306122446	0.2525	77	1088	5	9	1	16	0	2	16	0	0	2.0	
i 1	34.48233333333334	11.3625	63	1088	4	16	1	1	0	2	1	0	0	3.711217867734826	
i 1	34.4917074829932	11.3625	63	386	3	27	1	1	0	2	1	0	0	3.0662168123387277	
i 1	34.503244897959185	0.2525	71	1088	2	24	6	2	0	-2	2	0	0	9.061800852638406	
i 1	34.506850340136054	0.2525	77	386	5	3	4	16	0	1	16	0	0	3.0	
i 1	34.509734693877554	0.2525	74	702	5	3	4	16	0	1	16	0	0	3.0	
i 1	34.510455782312924	0.505	77	702	4	5	4	16	0	2	16	0	0	5.0	
i 1	34.513340136054424	0.2525	71	386	2	24	16	8	0	1	8	0	0	9.061800852638406	
i 1	34.513340136054424	0.505	71	1088	2	20	6	2	0	-2	2	0	0	5.061800852638406	
i 1	34.514061224489794	11.3625	61	386	5	12	4	16	0	1	16	0	0	3.711217867734826	
i 1	34.739544217687076	0.505	72	702	5	1	11	1	0	0	1	0	0	2.0	
i 1	34.74242857142857	0.2525	71	702	3	20	1	2	0	1	2	0	0	5.061800852638406	
i 1	34.743149659863946	1.2625	71	386	2	24	3	2	0	1	2	0	0	9.061800852638406	
i 1	34.74459183673469	0.505	74	1088	5	9	8	16	0	1	16	0	0	2.0	
i 1	34.746034013605446	0.505	77	702	6	2	15	16	0	2	16	0	0	3.0	
i 1	34.75108163265306	0.2525	71	702	4	20	4	2	0	-2	2	0	0	5.061800852638406	
i 1	34.76189795918367	0.505	72	1088	6	1	2	1	0	0	1	0	0	2.0	
i 1	34.98738095238095	0.2525	77	386	4	5	10	17	0	1	17	0	0	5.0	
i 1	35.00180272108844	2.2725	71	386	2	20	2	2	0	1	2	0	0	5.061800852638406	
i 1	35.0082925170068	0.2525	74	702	5	5	14	17	0	1	17	0	0	5.0	
i 1	35.0111768707483	1.01	74	1088	3	20	3	8	0	-2	8	0	0	5.061800852638406	
i 1	35.01622448979592	2.2725	74	386	3	20	13	2	0	1	2	0	0	5.061800852638406	
i 1	35.23449659863945	0.505	77	702	4	4	9	17	0	1	17	0	0	3.0	
i 1	35.246034013605446	1.5150000000000001	74	1088	4	5	1	16	0	2	16	0	0	5.0	
i 1	35.25252380952381	1.2625	69	386	6	1	15	1	0	-1	1	0	0	2.0	
i 1	35.25468707482993	1.5150000000000001	77	702	5	5	6	17	0	1	17	0	0	5.0	
i 1	35.26478231292517	1.2625	72	702	4	1	10	1	0	0	1	0	0	2.0	
i 1	35.266945578231294	0.505	77	386	4	4	16	17	0	2	17	0	0	3.0	
i 1	35.736659863945576	1.01	77	1088	5	9	15	16	0	2	16	0	0	2.0	
i 1	35.74387074829932	1.01	74	702	6	2	12	17	0	2	17	0	0	3.0	
i 1	35.996755102040815	1.5150000000000001	71	386	2	24	15	2	0	1	2	0	0	9.061800852638406	
i 1	36.0111768707483	1.5150000000000001	71	1088	2	24	5	2	0	-2	2	0	0	9.061800852638406	
i 1	36.4917074829932	0.505	72	702	4	1	12	1	0	0	1	0	0	2.0	
i 1	36.50540816326531	0.505	72	1088	6	1	5	0	0	0	0	0	0	2.0	
i 1	36.7388231292517	1.5150000000000001	74	702	5	5	8	17	0	2	17	0	0	5.0	
i 1	36.753244897959185	1.5150000000000001	74	386	6	5	11	16	0	1	16	0	0	5.0	
i 1	36.75757142857143	1.01	77	386	5	3	1	16	0	1	16	0	0	3.0	
i 1	36.766945578231294	1.01	74	702	5	3	13	16	0	1	16	0	0	3.0	
i 1	37.010455782312924	0.7575000000000001	69	702	4	24	14	0	0	0	0	0	0	3.0	
i 1	37.010455782312924	0.7575000000000001	72	386	4	24	13	1	0	-1	1	0	0	3.0	
i 1	37.25252380952381	0.2525	71	386	2	24	4	2	0	1	2	0	0	9.061800852638406	
i 1	37.26550340136055	0.2525	74	1088	3	20	8	8	0	-2	8	0	0	5.061800852638406	
i 1	37.48449659863945	1.01	74	386	3	20	4	2	0	1	2	0	0	5.061800852638406	
i 1	37.4917074829932	0.2525	74	702	3	24	3	2	0	-2	2	0	0	9.061800852638406	
i 1	37.50108163265306	0.2525	74	702	4	20	15	2	0	1	2	0	0	5.061800852638406	
i 1	37.51261904761905	0.2525	71	1088	2	20	13	2	0	-2	2	0	0	5.061800852638406	
i 1	37.73377551020408	1.5150000000000001	71	386	2	24	10	2	0	1	2	0	0	9.061800852638406	
i 1	37.739544217687076	0.2525	74	1088	5	9	1	16	0	1	16	0	0	2.0	
i 1	37.74819727891156	0.7575000000000001	71	1088	3	20	13	2	0	1	2	0	0	5.061800852638406	
i 1	37.750360544217685	0.2525	72	702	5	1	16	1	0	0	1	0	0	2.0	
i 1	37.75108163265306	0.7575000000000001	71	386	2	20	12	2	0	-2	2	0	0	5.061800852638406	
i 1	37.75468707482993	0.2525	77	702	6	2	1	16	0	2	16	0	0	3.0	
i 1	37.76550340136055	0.2525	72	1088	6	1	14	1	0	0	1	0	0	2.0	
i 1	37.98377551020408	0.2525	77	386	4	4	14	17	0	2	17	0	0	3.0	
i 1	38.0111768707483	0.2525	77	702	4	4	2	17	0	1	17	0	0	3.0	
i 1	38.013340136054424	1.5150000000000001	72	702	4	1	12	1	0	0	1	0	0	2.0	
i 1	38.014061224489794	1.5150000000000001	69	386	6	1	8	1	0	-1	1	0	0	2.0	
i 1	38.23738095238095	0.505	77	1088	5	9	16	16	0	2	16	0	0	2.0	
i 1	38.240265306122446	0.505	74	702	6	2	2	17	0	2	17	0	0	3.0	
i 1	38.24531292517007	1.01	77	702	4	5	16	16	0	2	16	0	0	5.0	
i 1	38.246034013605446	1.01	77	1088	4	5	14	16	0	2	16	0	0	5.0	
i 1	38.48377551020408	0.2525	74	702	3	20	7	2	0	1	2	0	0	5.061800852638406	
i 1	38.48449659863945	0.2525	71	702	4	20	1	2	0	1	2	0	0	5.061800852638406	
i 1	38.50612925170068	0.2525	71	1088	2	20	4	2	0	-2	2	0	0	5.061800852638406	
i 1	38.733054421768706	0.505	77	386	5	3	14	16	0	1	16	0	0	3.0	
i 1	38.74459183673469	0.505	74	702	5	3	3	16	0	1	16	0	0	3.0	
i 1	38.75108163265306	0.505	71	1088	2	24	7	2	0	-2	2	0	0	9.061800852638406	
i 1	38.75901360544218	0.505	71	1088	3	20	11	2	0	-2	2	0	0	5.061800852638406	
i 1	38.76478231292517	0.505	71	386	2	24	2	2	0	1	2	0	0	9.061800852638406	
i 1	39.23233333333334	1.2625	74	702	5	5	9	17	0	1	17	0	0	5.0	
i 1	39.2417074829932	0.2525	74	702	3	24	7	2	0	-2	2	0	0	9.061800852638406	
i 1	39.243149659863946	1.2625	77	386	4	5	14	17	0	1	17	0	0	5.0	
i 1	39.24459183673469	0.2525	74	702	4	20	16	2	0	1	2	0	0	5.061800852638406	
i 1	39.24531292517007	1.01	71	1088	1	24	13	2	0	248	2	308	0	9.061800852638406	
i 1	39.246755102040815	1.01	77	702	6	2	6	16	0	2	16	0	0	3.0	
i 1	39.24747619047619	0.7575000000000001	74	386	3	20	5	2	0	1	2	0	0	5.061800852638406	
i 1	39.253965986394554	1.01	74	1088	5	9	12	16	0	1	16	0	0	2.0	
i 1	39.25901360544218	0.2525	71	1088	2	20	1	2	0	-2	2	0	0	5.061800852638406	
i 1	39.48233333333334	0.505	71	1088	3	20	4	2	0	-2	2	0	0	5.061800852638406	
i 1	39.490265306122446	0.505	71	386	2	20	14	2	0	-2	2	0	0	5.061800852638406	
i 1	39.50252380952381	0.505	71	386	1	24	3	2	0	252	2	307	0	9.061800852638406	
i 1	39.509734693877554	0.505	72	702	4	1	3	1	0	0	1	0	0	2.0	
i 1	39.51478231292517	0.505	72	1088	6	1	3	0	0	0	0	0	0	2.0	
i 1	39.51766666666666	0.505	71	386	2	24	6	2	0	1	2	0	0	9.061800852638406	
i 1	39.98233333333334	0.2525	72	386	4	24	6	1	0	-1	1	0	0	3.0	
i 1	39.986659863945576	0.2525	74	702	4	20	16	2	0	1	2	0	0	5.061800852638406	
i 1	39.990265306122446	0.2525	71	1088	2	20	3	2	0	-2	2	0	0	5.061800852638406	
i 1	40.00468707482993	0.2525	69	702	4	24	4	0	0	0	0	0	0	3.0	
i 1	40.235938775510206	5.555	61	386	3	27	7	1	0	2	1	0	0	3.0662168123387277	
i 1	40.2388231292517	0.505	71	1088	2	24	7	2	0	-2	2	0	0	9.061800852638406	
i 1	40.2417074829932	1.01	72	386	4	24	9	1	0	-1	1	0	0	3.0	
i 1	40.2417074829932	5.555	63	1088	4	16	9	16	0	2	16	0	0	3.711217867734826	
i 1	40.24387074829932	0.505	74	386	2	24	2	2	0	1	2	0	0	9.061800852638406	
i 1	40.24747619047619	1.01	77	386	4	4	5	17	0	2	17	0	0	3.0	
i 1	40.25252380952381	1.01	77	702	4	4	6	17	0	1	17	0	0	3.0	
i 1	40.25612925170068	0.505	71	386	2	24	16	2	0	1	2	0	0	9.061800852638406	
i 1	40.263340136054424	1.01	69	702	4	24	11	0	0	0	0	0	0	3.0	
i 1	40.26766666666666	5.555	61	386	5	12	1	16	0	2	16	0	0	3.711217867734826	
i 1	40.49531292517007	1.01	74	1088	4	5	8	16	0	2	16	0	0	5.0	
i 1	40.50252380952381	1.01	77	702	4	5	15	17	0	1	17	0	0	5.0	
i 1	40.733054421768706	0.7575000000000001	71	702	3	24	5	2	0	-2	2	0	0	9.061800852638406	
i 1	40.73521768707483	0.7575000000000001	71	702	1	20	5	2	0	1	2	0	0	5.061800852638406	
i 1	40.739544217687076	0.7575000000000001	74	386	2	20	8	2	0	1	2	0	0	5.061800852638406	
i 1	40.753244897959185	0.7575000000000001	71	1088	2	20	13	2	0	-2	2	0	0	5.061800852638406	
i 1	41.25108163265306	0.505	72	702	5	1	14	1	0	0	1	0	0	2.0	
i 1	41.25757142857143	0.2525	77	1088	5	9	10	16	0	2	16	0	0	2.0	
i 1	41.260455782312924	0.2525	74	702	6	2	10	17	0	2	17	0	0	3.0	
i 1	41.266945578231294	0.505	72	1088	6	1	16	1	0	0	1	0	0	2.0	
i 1	41.483054421768706	0.2525	74	386	4	5	13	16	0	1	16	0	0	5.0	
i 1	41.503244897959185	0.2525	74	702	5	5	7	17	0	2	17	0	0	5.0	
i 1	41.5111768707483	0.2525	74	702	5	3	7	16	0	1	16	0	0	3.0	
i 1	41.51189795918367	0.2525	77	386	5	3	11	16	0	1	16	0	0	3.0	
i 1	41.51622448979592	2.525	71	386	2	24	11	2	0	1	2	0	0	9.061800852638406	
i 1	41.73738095238095	1.5150000000000001	77	702	4	5	15	16	0	2	16	0	0	5.0	
i 1	41.740265306122446	0.505	77	702	6	2	12	16	0	2	16	0	0	3.0	
i 1	41.74098639455782	0.7575000000000001	72	702	4	1	2	1	0	0	1	0	0	2.0	
i 1	41.7417074829932	1.5150000000000001	77	1088	4	5	1	16	0	2	16	0	0	5.0	
i 1	41.74242857142857	0.7575000000000001	69	386	6	1	6	1	0	-1	1	0	0	2.0	
i 1	41.74819727891156	0.505	74	1088	5	9	7	16	0	1	16	0	0	2.0	
i 1	42.23738095238095	0.505	77	702	4	4	15	17	0	1	17	0	0	3.0	
i 1	42.26550340136055	0.505	77	386	4	4	12	17	0	2	17	0	0	3.0	
i 1	42.510455782312924	0.2525	72	702	5	1	16	1	0	0	1	0	0	2.0	
i 1	42.513340136054424	0.2525	72	1088	6	1	15	0	0	0	0	0	0	2.0	
i 1	42.7388231292517	1.01	74	386	2	24	8	2	0	-2	2	0	0	9.061800852638406	
i 1	42.74387074829932	1.01	77	1088	5	9	4	16	0	2	16	0	0	2.0	
i 1	42.746034013605446	1.5150000000000001	72	386	4	24	13	1	0	-1	1	0	0	3.0	
i 1	42.75180272108844	1.01	74	702	6	2	14	17	0	2	17	0	0	3.0	
i 1	42.756850340136054	1.5150000000000001	69	702	4	24	11	0	0	0	0	0	0	3.0	
i 1	42.764061224489794	1.01	71	1088	2	24	7	2	0	-2	2	0	0	9.061800852638406	
i 1	43.233054421768706	1.5150000000000001	74	702	5	5	5	17	0	1	17	0	0	5.0	
i 1	43.25901360544218	1.5150000000000001	77	386	4	5	9	17	0	1	17	0	0	5.0	
i 1	43.736659863945576	0.2525	71	702	3	24	7	2	0	-2	2	0	0	9.061800852638406	
i 1	43.73738095238095	1.01	74	702	5	3	11	16	0	1	16	0	0	3.0	
i 1	43.760455782312924	0.7575000000000001	74	386	2	20	12	2	0	1	2	0	0	5.061800852638406	
i 1	43.76189795918367	0.2525	71	702	4	20	5	2	0	1	2	0	0	5.061800852638406	
i 1	43.76478231292517	1.01	77	386	5	3	10	16	0	1	16	0	0	3.0	
i 1	44.00252380952381	0.505	71	386	3	20	9	2	0	-2	2	0	0	5.061800852638406	
i 1	44.0111768707483	0.7575000000000001	71	1088	2	20	12	2	0	-2	2	0	0	5.061800852638406	
i 1	44.243149659863946	0.505	72	1088	6	1	5	1	0	0	1	0	0	2.0	
i 1	44.253965986394554	0.505	72	702	5	1	13	1	0	0	1	0	0	2.0	
i 1	44.496034013605446	1.2625	71	1088	2	24	15	2	0	-2	2	0	0	9.061800852638406	
i 1	44.50252380952381	0.2525	71	702	1	20	16	2	0	-2	2	0	0	5.061800852638406	
i 1	44.50252380952381	0.2525	71	702	1	20	5	2	0	-2	2	0	0	5.061800852638406	
i 1	44.733054421768706	1.01	71	386	2	24	13	2	0	1	2	0	0	9.061800852638406	
i 1	44.7388231292517	0.2525	77	702	6	2	9	16	0	2	16	0	0	3.0	
i 1	44.7417074829932	1.01	74	1088	4	5	10	16	0	2	16	0	0	5.0	
i 1	44.746034013605446	1.01	74	386	2	24	2	2	0	1	2	0	0	9.061800852638406	
i 1	44.75252380952381	1.01	77	702	4	5	8	17	0	1	17	0	0	5.0	
i 1	44.76261904761905	1.01	72	702	4	1	10	1	0	0	1	0	0	2.0	
i 1	44.76622448979592	0.2525	74	1088	5	9	13	16	0	1	16	0	0	2.0	
i 1	44.766945578231294	1.01	69	386	6	1	15	1	0	-1	1	0	0	2.0	
i 1	44.986659863945576	0.2525	77	386	4	4	2	17	0	2	17	0	0	3.0	
i 1	45.0082925170068	0.2525	77	702	4	4	2	17	0	1	17	0	0	3.0	
i 1	45.25612925170068	0.505	74	702	6	2	14	17	0	2	17	0	0	3.0	
i 1	45.25901360544218	0.505	77	1088	5	9	7	16	0	2	16	0	0	2.0	
i 1	45.736659863945576	0.505	74	204	6	3	6	16	0	2	16	0	0	3.0	
i 1	45.740265306122446	0.2525	63	906	5	14	4	1	0	1	1	0	0	5.642238441933669	
i 1	45.74747619047619	23.4825	61	204	5	16	3	16	0	1	16	0	0	3.711217867734826	
i 1	45.74747619047619	0.2525	61	204	6	12	5	16	0	1	16	0	0	3.711217867734826	
i 1	45.749639455782315	1.2625	77	204	5	5	1	17	0	2	17	0	0	5.0	
i 1	45.750360544217685	0.505	74	906	6	2	13	16	0	1	16	0	0	3.0	
i 1	45.75108163265306	0.2525	74	204	3	20	6	2	0	-2	2	0	0	5.061800852638406	
i 1	45.75540816326531	0.2525	61	906	5	14	14	16	0	2	16	0	0	4.17512010120168	
i 1	45.75612925170068	11.8675	61	204	5	26	9	16	0	2	16	0	0	2.2996626092540455	
i 1	45.756850340136054	6.0600000000000005	63	204	6	12	7	1	0	2	1	0	0	3.711217867734826	
i 1	45.75757142857143	14.645	63	204	4	27	1	16	0	1	16	0	0	3.0662168123387277	
i 1	45.7582925170068	0.2525	69	204	7	1	2	1	0	0	1	0	0	2.0	
i 1	45.75901360544218	0.7575000000000001	71	204	2	24	11	2	0	-2	2	0	0	9.061800852638406	
i 1	45.75901360544218	1.01	71	204	2	20	5	2	0	1	2	0	0	5.061800852638406	
i 1	45.760455782312924	0.2525	74	906	4	5	2	16	0	1	16	0	0	5.0	
i 1	45.7611768707483	6.0600000000000005	61	906	5	13	2	16	0	1	16	0	0	2.7834134008011198	
i 1	45.76261904761905	0.505	69	702	4	24	3	0	0	0	0	0	0	3.0	
i 1	45.76478231292517	6.0600000000000005	63	204	5	26	15	1	0	1	1	0	0	2.2996626092540455	
i 1	45.76550340136055	14.645	61	204	4	27	7	1	0	1	1	0	0	3.0662168123387277	
i 1	45.76622448979592	6.0600000000000005	63	906	5	14	14	1	0	1	1	0	0	5.642238441933669	
i 1	45.766945578231294	0.2525	71	204	2	24	4	2	0	-2	2	0	0	9.061800852638406	
i 1	45.76766666666666	29.29	63	204	5	16	14	1	0	2	1	0	0	3.711217867734826	
i 1	45.99098639455782	0.505	71	204	3	24	6	2	0	-2	2	0	0	9.061800852638406	
i 1	45.99531292517007	1.01	74	906	6	5	12	16	0	1	16	0	0	5.0	
i 1	46.00252380952381	14.3925	63	906	3	14	13	1	0	1	1	0	0	5.642238441933669	
i 1	46.00612925170068	14.3925	61	204	5	12	11	16	0	1	16	0	0	3.711217867734826	
i 1	46.006850340136054	0.2525	69	204	4	1	10	1	0	0	1	0	0	2.0	
i 1	46.01766666666666	5.8075	61	906	5	14	15	16	0	2	16	0	0	4.17512010120168	
i 1	46.240265306122446	1.01	74	204	6	9	15	16	0	1	16	0	0	2.0	
i 1	46.24098639455782	0.7575000000000001	72	204	7	1	15	0	0	-1	0	0	0	2.0	
i 1	46.2582925170068	0.7575000000000001	72	906	5	1	13	0	0	0	0	0	0	2.0	
i 1	46.25901360544218	1.01	77	702	4	4	12	17	0	1	17	0	0	3.0	
i 1	46.490265306122446	0.2525	71	906	1	20	13	2	0	-2	2	0	0	5.061800852638406	
i 1	46.509734693877554	0.505	71	204	3	20	5	2	0	-2	2	0	0	5.061800852638406	
i 1	46.51478231292517	0.2525	74	702	1	20	5	2	0	1	2	0	0	5.061800852638406	
i 1	46.735938775510206	0.505	71	204	3	24	15	2	0	-2	2	0	0	9.061800852638406	
i 1	46.73738095238095	0.2525	74	204	1	20	13	2	0	-2	2	0	0	5.061800852638406	
i 1	46.7417074829932	0.2525	71	204	1	20	9	2	0	1	2	0	0	5.061800852638406	
i 1	46.986659863945576	0.2525	71	906	1	20	11	8	0	-2	8	0	0	5.061800852638406	
i 1	46.98738095238095	1.01	74	204	4	5	7	17	0	1	17	0	0	5.0	
i 1	46.98810204081633	0.2525	74	702	4	24	1	8	0	-2	8	0	0	9.061800852638406	
i 1	46.99819727891156	1.01	74	702	4	5	3	17	0	1	17	0	0	5.0	
i 1	47.010455782312924	0.2525	72	702	5	1	11	1	0	0	1	0	0	2.0	
i 1	47.0111768707483	0.2525	69	204	5	24	4	0	0	-1	0	0	0	3.0	
i 1	47.01550340136055	1.2625	71	204	2	24	11	2	0	-2	2	0	0	9.061800852638406	
i 1	47.23449659863945	2.02	74	204	3	24	12	2	0	1	2	0	0	9.061800852638406	
i 1	47.2388231292517	2.7775	71	204	2	20	11	2	0	1	2	0	0	5.061800852638406	
i 1	47.24387074829932	1.01	77	906	6	2	7	16	0	2	16	0	0	3.0	
i 1	47.25540816326531	1.5150000000000001	69	204	6	1	6	0	0	0	0	0	0	2.0	
i 1	47.2611768707483	1.01	77	204	6	9	6	16	0	2	16	0	0	2.0	
i 1	47.26766666666666	1.5150000000000001	72	906	5	1	15	0	0	0	0	0	0	2.0	
i 1	47.983054421768706	0.2525	74	906	4	5	10	16	0	2	16	0	0	5.0	
i 1	48.00612925170068	0.2525	77	204	4	5	12	17	0	1	17	0	0	5.0	
i 1	48.246034013605446	1.5150000000000001	77	204	5	5	12	17	0	2	17	0	0	5.0	
i 1	48.253244897959185	1.01	71	204	3	20	16	2	0	-2	2	0	0	5.061800852638406	
i 1	48.256850340136054	0.2525	74	204	5	4	16	17	0	1	17	0	0	3.0	
i 1	48.26189795918367	1.01	74	204	1	20	12	2	0	-2	2	0	0	5.061800852638406	
i 1	48.264061224489794	1.5150000000000001	74	702	5	5	14	17	0	2	17	0	0	5.0	
i 1	48.26478231292517	0.2525	74	702	5	3	9	16	0	1	16	0	0	3.0	
i 1	48.49387074829932	0.2525	74	906	6	2	2	16	0	1	16	0	0	3.0	
i 1	48.50468707482993	0.2525	74	204	6	3	1	16	0	2	16	0	0	3.0	
i 1	48.74531292517007	0.505	74	204	6	9	12	16	0	1	16	0	0	2.0	
i 1	48.750360544217685	0.505	77	702	4	4	11	17	0	1	17	0	0	3.0	
i 1	48.753244897959185	0.505	69	702	4	24	13	0	0	0	0	0	0	3.0	
i 1	48.7582925170068	0.505	69	204	4	1	8	1	0	0	1	0	0	2.0	
i 1	49.236659863945576	0.2525	71	702	4	24	12	8	0	1	8	0	0	9.061800852638406	
i 1	49.240265306122446	0.505	77	204	6	9	6	16	0	2	16	0	0	2.0	
i 1	49.24819727891156	1.2625	72	906	5	1	13	0	0	0	0	0	0	2.0	
i 1	49.25180272108844	0.2525	74	702	1	20	3	2	0	1	2	0	0	5.061800852638406	
i 1	49.25180272108844	0.7575000000000001	71	204	3	24	12	2	0	-2	2	0	0	9.061800852638406	
i 1	49.259734693877554	1.2625	72	204	7	1	1	0	0	-1	0	0	0	2.0	
i 1	49.263340136054424	0.505	77	906	6	2	7	16	0	2	16	0	0	3.0	
i 1	49.499639455782315	0.505	71	204	3	24	8	8	0	1	8	0	0	9.061800852638406	
i 1	49.503965986394554	0.505	74	204	1	20	15	2	0	1	2	0	0	5.061800852638406	
i 1	49.733054421768706	1.01	74	204	5	4	9	17	0	1	17	0	0	3.0	
i 1	49.739544217687076	1.5150000000000001	74	906	6	5	7	16	0	1	16	0	0	5.0	
i 1	49.753965986394554	1.01	74	702	5	3	13	16	0	1	16	0	0	3.0	
i 1	49.753965986394554	1.5150000000000001	77	204	5	5	8	17	0	2	17	0	0	5.0	
i 1	49.989544217687076	0.2525	71	906	1	20	6	8	0	1	8	0	0	5.061800852638406	
i 1	50.000360544217685	0.505	71	204	2	24	12	2	0	-2	2	0	0	9.061800852638406	
i 1	50.01550340136055	0.505	71	204	3	20	15	2	0	-2	2	0	0	5.061800852638406	
i 1	50.01622448979592	0.2525	74	906	1	20	6	2	0	1	2	0	0	5.061800852638406	
i 1	50.26550340136055	0.2525	74	204	1	20	7	8	0	-2	8	0	0	5.061800852638406	
i 1	50.49387074829932	0.505	71	702	4	24	1	2	0	1	2	0	0	9.061800852638406	
i 1	50.49459183673469	0.505	69	204	4	1	2	1	0	0	1	0	0	2.0	
i 1	50.49891836734694	1.01	71	204	2	20	8	2	0	1	2	0	0	5.061800852638406	
i 1	50.503244897959185	0.505	74	702	1	20	13	2	0	-2	2	0	0	5.061800852638406	
i 1	50.50612925170068	0.505	69	702	4	24	16	0	0	0	0	0	0	3.0	
i 1	50.51622448979592	1.01	71	204	3	24	4	2	0	-2	2	0	0	9.061800852638406	
i 1	50.75540816326531	1.01	74	204	6	3	12	16	0	2	16	0	0	3.0	
i 1	50.763340136054424	1.01	74	906	6	2	6	16	0	1	16	0	0	3.0	
i 1	50.986659863945576	0.7575000000000001	72	906	5	1	12	0	0	0	0	0	0	2.0	
i 1	50.99891836734694	0.2525	74	204	5	4	15	17	0	1	17	0	0	3.0	
i 1	51.000360544217685	0.505	74	204	3	24	1	2	0	-2	2	0	0	9.061800852638406	
i 1	51.00108163265306	0.505	71	204	1	20	14	2	0	1	2	0	0	5.061800852638406	
i 1	51.00252380952381	0.7575000000000001	69	204	6	1	4	0	0	0	0	0	0	2.0	
i 1	51.01766666666666	0.2525	74	702	5	5	15	17	0	2	17	0	0	5.0	
i 1	51.240265306122446	1.01	74	702	4	5	7	17	0	1	17	0	0	5.0	
i 1	51.249639455782315	0.505	71	204	3	20	15	2	0	-2	2	0	0	5.061800852638406	
i 1	51.25901360544218	1.01	74	204	4	5	3	17	0	1	17	0	0	5.0	
i 1	51.486659863945576	0.2525	77	204	4	5	13	17	0	1	17	0	0	5.0	
i 1	51.4888231292517	0.2525	71	906	1	20	6	2	0	-2	2	0	0	5.061800852638406	
i 1	51.73521768707483	5.8075	61	906	5	13	16	16	0	1	16	0	0	2.7834134008011198	
i 1	51.73521768707483	1.01	71	204	2	24	6	2	0	-2	2	0	0	7.898945826134887	
i 1	51.74098639455782	0.2525	69	702	4	24	3	0	0	0	0	0	0	3.0	
i 1	51.74531292517007	8.585	63	906	3	14	8	1	0	1	1	0	0	5.642238441933669	
i 1	51.749639455782315	0.2525	74	204	6	9	12	16	0	1	16	0	0	2.0	
i 1	51.75180272108844	0.7575000000000001	74	204	1	20	12	2	0	-2	2	0	0	3.898945826134887	
i 1	51.75468707482993	0.2525	69	204	4	1	14	1	0	0	1	0	0	2.0	
i 1	51.75468707482993	0.2525	71	204	3	20	4	2	0	-2	2	0	0	3.898945826134887	
i 1	51.75540816326531	8.585	63	204	5	12	2	1	0	2	1	0	0	3.711217867734826	
i 1	51.756850340136054	0.2525	77	702	4	4	4	17	0	1	17	0	0	3.0	
i 1	51.766945578231294	2.7775	71	204	4	24	16	2	0	-2	2	0	0	7.898945826134887	
i 1	51.983054421768706	0.2525	77	906	6	2	9	16	0	2	16	0	0	3.0	
i 1	52.01550340136055	1.5150000000000001	72	204	4	1	11	0	0	-1	0	0	0	2.0	
i 1	52.01550340136055	0.2525	77	204	6	9	4	16	0	2	16	0	0	2.0	
i 1	52.01766666666666	1.5150000000000001	72	906	5	1	8	0	0	0	0	0	0	2.0	
i 1	52.23449659863945	0.7575000000000001	74	204	5	4	7	17	0	1	17	0	0	3.0	
i 1	52.24387074829932	0.7575000000000001	74	702	5	3	9	16	0	1	16	0	0	3.0	
i 1	52.25612925170068	1.2625	74	906	6	5	6	16	0	2	16	0	0	5.0	
i 1	52.260455782312924	1.2625	77	204	4	5	14	17	0	1	17	0	0	5.0	
i 1	52.48738095238095	0.2525	77	204	6	9	7	16	0	2	16	0	0	2.0	
i 1	52.499639455782315	0.2525	74	702	1	24	1	2	0	1	2	0	0	7.898945826134887	
i 1	52.51189795918367	0.2525	71	906	1	20	7	2	0	1	2	0	0	3.898945826134887	
i 1	52.733054421768706	5.8075	71	204	2	20	13	2	0	1	2	0	0	3.898945826134887	
i 1	52.73810204081633	0.7575000000000001	74	204	6	3	16	16	0	2	16	0	0	3.0	
i 1	52.753965986394554	1.7675	71	204	1	20	4	2	0	-2	2	0	0	3.898945826134887	
i 1	52.76478231292517	0.7575000000000001	74	906	6	2	9	16	0	1	16	0	0	3.0	
i 1	53.236659863945576	1.01	74	204	6	9	14	16	0	1	16	0	0	2.0	
i 1	53.26478231292517	1.01	77	702	4	4	12	17	0	1	17	0	0	3.0	
i 1	53.48738095238095	1.2625	74	702	4	5	8	17	0	2	17	0	0	5.0	
i 1	53.49098639455782	1.2625	77	204	5	5	12	17	0	2	17	0	0	5.0	
i 1	53.49747619047619	0.2525	69	702	4	24	11	0	0	0	0	0	0	3.0	
i 1	53.49819727891156	0.505	69	204	5	24	3	0	0	-1	0	0	0	3.0	
i 1	53.51478231292517	0.505	72	702	5	1	3	1	0	0	1	0	0	2.0	
i 1	53.739544217687076	0.2525	77	204	4	5	9	17	0	1	17	0	0	5.0	
i 1	53.74098639455782	0.2525	74	204	6	3	13	16	0	2	16	0	0	3.0	
i 1	53.746034013605446	1.7675	72	906	5	1	14	0	0	0	0	0	0	2.0	
i 1	53.99387074829932	1.5150000000000001	69	204	6	1	5	0	0	0	0	0	0	2.0	
i 1	53.99819727891156	1.2625	77	906	6	2	2	16	0	2	16	0	0	3.0	
i 1	54.00180272108844	1.01	71	204	3	20	6	2	0	-2	2	0	0	3.898945826134887	
i 1	54.00901360544218	0.7575000000000001	71	204	1	20	4	2	0	-2	2	0	0	3.898945826134887	
i 1	54.01550340136055	1.2625	77	204	6	9	16	16	0	2	16	0	0	2.0	
i 1	54.2388231292517	0.505	74	906	6	5	3	16	0	1	16	0	0	5.0	
i 1	54.26261904761905	0.505	77	204	5	5	3	17	0	2	17	0	0	5.0	
i 1	54.48449659863945	0.505	74	204	6	3	6	16	0	2	16	0	0	3.0	
i 1	54.489544217687076	1.7675	74	204	4	5	7	17	0	1	17	0	0	5.0	
i 1	54.50180272108844	1.7675	74	702	4	5	15	17	0	1	17	0	0	5.0	
i 1	54.74531292517007	0.2525	71	906	1	20	13	2	0	-2	2	0	0	3.898945826134887	
i 1	54.756850340136054	0.505	71	204	4	24	5	2	0	-2	2	0	0	7.898945826134887	
i 1	54.760455782312924	0.505	71	702	1	20	4	2	0	-2	2	0	0	3.898945826134887	
i 1	54.760455782312924	0.505	74	702	1	24	16	2	0	-2	2	0	0	7.898945826134887	
i 1	54.983054421768706	1.2625	71	204	2	24	7	2	0	-2	2	0	0	7.898945826134887	
i 1	55.2388231292517	0.2525	77	204	4	5	1	17	0	1	17	0	0	5.0	
i 1	55.240265306122446	0.505	69	204	4	1	5	1	0	0	1	0	0	2.0	
i 1	55.243149659863946	0.505	69	702	4	24	7	0	0	0	0	0	0	3.0	
i 1	55.246755102040815	0.505	74	204	5	4	4	17	0	1	17	0	0	3.0	
i 1	55.25180272108844	0.2525	74	702	5	3	6	16	0	1	16	0	0	3.0	
i 1	55.496755102040815	0.505	74	906	6	2	10	16	0	1	16	0	0	3.0	
i 1	55.50612925170068	0.505	74	204	6	3	10	16	0	2	16	0	0	3.0	
i 1	55.74891836734694	0.2525	69	204	6	1	4	0	0	0	0	0	0	2.0	
i 1	55.753965986394554	1.01	72	906	5	1	1	0	0	0	0	0	0	2.0	
i 1	55.756850340136054	0.505	77	702	4	4	10	17	0	1	17	0	0	3.0	
i 1	55.764061224489794	0.505	74	204	6	9	7	16	0	1	16	0	0	2.0	
i 1	55.76766666666666	1.01	72	204	4	1	2	0	0	-1	0	0	0	2.0	
i 1	55.98738095238095	0.2525	74	702	4	5	5	17	0	2	17	0	0	5.0	
i 1	56.000360544217685	2.2725	71	204	1	20	4	2	0	-2	2	0	0	3.898945826134887	
i 1	56.003244897959185	0.7575000000000001	77	906	6	2	5	16	0	2	16	0	0	3.0	
i 1	56.003965986394554	1.5150000000000001	71	204	3	20	10	2	0	-2	2	0	0	3.898945826134887	
i 1	56.0111768707483	0.7575000000000001	77	204	6	9	12	16	0	2	16	0	0	2.0	
i 1	56.233054421768706	2.02	71	204	1	24	13	2	0	252	2	307	0	7.898945826134887	
i 1	56.25540816326531	1.7675	74	906	6	5	13	16	0	2	16	0	0	5.0	
i 1	56.25901360544218	1.7675	77	204	4	5	2	17	0	1	17	0	0	5.0	
i 1	56.493149659863946	0.2525	74	702	4	5	16	17	0	1	17	0	0	5.0	
i 1	56.503244897959185	0.505	69	204	4	1	5	1	0	0	1	0	0	2.0	
i 1	56.50612925170068	2.02	72	906	5	1	13	0	0	0	0	0	0	2.0	
i 1	56.50757142857143	0.505	69	702	4	24	1	0	0	0	0	0	0	3.0	
i 1	56.51622448979592	1.01	69	204	6	1	12	0	0	0	0	0	0	2.0	
i 1	56.75180272108844	1.2625	74	702	5	3	2	16	0	1	16	0	0	3.0	
i 1	56.76550340136055	1.2625	74	204	5	4	13	17	0	1	17	0	0	3.0	
i 1	56.98377551020408	0.2525	74	702	4	5	10	17	0	1	17	0	0	5.0	
i 1	56.99531292517007	0.2525	72	906	5	1	13	0	0	0	0	0	0	2.0	
i 1	57.000360544217685	0.505	77	702	4	4	6	17	0	1	17	0	0	3.0	
i 1	57.23521768707483	0.2525	69	204	5	24	1	0	0	-1	0	0	0	3.0	
i 1	57.24531292517007	0.2525	74	204	4	5	5	17	0	1	17	0	0	5.0	
i 1	57.483054421768706	1.2625	74	204	6	3	8	16	0	2	16	0	0	3.0	
i 1	57.48810204081633	0.2525	69	204	5	1	3	1	0	0	1	0	0	2.0	
i 1	57.49819727891156	2.7775	69	204	3	1	10	0	0	0	0	0	0	2.0	
i 1	57.50180272108844	1.2625	63	702	5	15	14	1	0	1	1	0	0	3.247315634267973	
i 1	57.50180272108844	1.2625	74	906	6	2	15	16	0	1	16	0	0	3.0	
i 1	57.50612925170068	1.01	71	204	4	20	7	2	0	-2	2	0	0	3.898945826134887	
i 1	57.50757142857143	2.7775	63	906	5	25	7	16	0	1	16	0	0	2.2996626092540455	
i 1	57.50757142857143	1.2625	61	702	3	13	6	1	0	1	1	0	0	1.4105596104834173	
i 1	57.74242857142857	1.01	74	702	4	5	10	17	0	2	17	0	0	5.0	
i 1	57.7611768707483	1.2625	77	204	4	5	5	17	0	2	17	0	0	5.0	
i 1	57.98521768707483	0.2525	77	204	5	5	15	17	0	2	17	0	0	5.0	
i 1	57.99459183673469	0.7575000000000001	69	702	4	24	6	0	0	0	0	0	0	3.0	
i 1	58.00108163265306	0.7575000000000001	69	204	5	1	4	1	0	0	1	0	0	2.0	
i 1	58.2388231292517	0.505	71	906	1	20	1	2	0	1	2	0	0	3.898945826134887	
i 1	58.25180272108844	0.505	74	702	1	24	2	2	0	1	2	0	0	7.898945826134887	
i 1	58.25540816326531	0.2525	77	204	6	9	11	16	0	2	16	0	0	2.0	
i 1	58.260455782312924	0.7575000000000001	71	204	1	24	2	2	0	-2	2	0	0	7.898945826134887	
i 1	58.2611768707483	1.5150000000000001	71	204	2	24	2	2	0	-2	2	0	0	7.898945826134887	
i 1	58.51261904761905	2.525	77	204	5	5	5	17	0	2	17	0	0	5.0	
i 1	58.51766666666666	1.7675	74	906	6	5	6	16	0	2	16	0	0	5.0	
i 1	58.73449659863945	1.5150000000000001	63	590	5	15	12	1	0	1	1	0	0	3.247315634267973	
i 1	58.73738095238095	0.2525	74	590	4	5	11	16	0	1	16	0	0	5.0	
i 1	58.73738095238095	1.5150000000000001	61	590	3	13	6	1	0	1	1	0	0	1.4105596104834173	
i 1	58.739544217687076	1.5150000000000001	63	590	6	7	14	16	0	2	16	0	0	4.231678831450252	
i 1	58.743149659863946	1.5150000000000001	71	204	2	20	6	2	0	1	2	0	0	3.898945826134887	
i 1	58.74531292517007	0.505	74	204	6	9	5	16	0	1	16	0	0	2.0	
i 1	58.746034013605446	0.2525	72	204	4	1	11	0	0	-1	0	0	0	2.0	
i 1	58.746034013605446	1.01	77	204	6	9	5	16	0	2	16	0	0	2.0	
i 1	58.74747619047619	0.505	77	906	5	2	4	16	0	2	16	0	0	3.0	
i 1	58.75180272108844	1.5150000000000001	61	590	5	15	16	16	0	1	16	0	0	3.247315634267973	
i 1	58.763340136054424	1.5150000000000001	72	590	5	1	15	0	0	-1	0	0	0	2.0	
i 1	58.76478231292517	0.2525	74	204	1	20	12	2	0	1	2	0	0	3.898945826134887	
i 1	58.990265306122446	0.505	74	204	6	3	2	16	0	2	16	0	0	3.0	
i 1	58.99098639455782	0.7575000000000001	74	906	6	2	3	16	0	1	16	0	0	3.0	
i 1	58.9917074829932	0.505	77	590	5	3	8	16	0	2	16	0	0	3.0	
i 1	59.26766666666666	0.2525	72	906	5	1	11	0	0	0	0	0	0	2.0	
i 1	59.49387074829932	0.7575000000000001	77	590	4	4	3	17	0	2	17	0	0	3.0	
i 1	59.496755102040815	0.7575000000000001	74	204	5	4	12	17	0	1	17	0	0	3.0	
i 1	59.49747619047619	0.505	74	590	1	24	14	2	0	-2	2	0	0	7.898945826134887	
i 1	59.49747619047619	5.3025	71	204	1	24	3	2	0	-2	2	0	0	7.898945826134887	
i 1	59.50612925170068	0.505	74	590	1	20	16	2	0	-2	2	0	0	3.898945826134887	
i 1	59.73449659863945	0.505	71	204	4	20	1	2	0	-2	2	0	0	3.898945826134887	
i 1	59.749639455782315	0.2525	72	906	5	1	10	0	0	0	0	0	0	2.0	
i 1	59.76261904761905	0.2525	71	906	1	20	5	2	0	-2	2	0	0	3.898945826134887	
i 1	59.98449659863945	0.7575000000000001	69	204	5	1	7	1	0	0	1	0	0	2.0	
i 1	59.98810204081633	1.2625	71	204	1	20	2	2	0	1	2	0	0	3.898945826134887	
i 1	59.99387074829932	0.2525	69	590	4	24	3	0	0	-1	0	0	0	3.0	
i 1	59.996034013605446	0.2525	71	204	2	24	13	2	0	-2	2	0	0	7.898945826134887	
i 1	59.999639455782315	0.2525	74	906	6	5	8	16	0	1	16	0	0	5.0	
i 1	60.003244897959185	0.2525	77	590	5	3	12	16	0	2	16	0	0	3.0	
i 1	60.233054421768706	1.2625	77	702	5	3	12	17	0	1	17	0	0	3.0	
i 1	60.23377551020408	0.2525	69	702	3	1	4	1	0	-1	1	0	0	2.0	
i 1	60.23449659863945	26.26	63	702	5	12	16	1	0	1	1	0	0	3.711217867734826	
i 1	60.23449659863945	8.8375	63	702	3	27	15	16	0	1	16	0	0	3.0662168123387277	
i 1	60.235938775510206	1.2625	61	702	5	15	11	16	0	1	16	0	0	3.247315634267973	
i 1	60.23738095238095	1.01	71	702	1	24	16	2	0	248	2	308	0	7.898945826134887	
i 1	60.240265306122446	1.2625	63	702	5	15	7	1	0	1	1	0	0	3.247315634267973	
i 1	60.240265306122446	26.26	63	1088	3	14	10	1	0	1	1	0	0	5.642238441933669	
i 1	60.24242857142857	0.2525	74	702	4	4	9	17	0	2	17	0	0	3.0	
i 1	60.250360544217685	1.2625	77	702	4	4	8	17	0	2	17	0	0	3.0	
i 1	60.25180272108844	3.0300000000000002	61	702	3	27	2	16	0	1	16	0	0	3.0662168123387277	
i 1	60.25252380952381	20.4525	61	1088	3	14	3	16	0	2	16	0	0	5.642238441933669	
i 1	60.2582925170068	1.2625	63	702	6	7	4	16	0	1	16	0	0	4.231678831450252	
i 1	60.25901360544218	1.5150000000000001	71	702	2	24	10	8	0	1	8	0	0	7.898945826134887	
i 1	60.259734693877554	20.4525	61	702	5	12	5	16	0	1	16	0	0	3.711217867734826	
i 1	60.260455782312924	0.505	74	1088	6	5	11	16	0	1	16	0	0	5.0	
i 1	60.2611768707483	0.2525	69	702	5	1	4	0	0	-1	0	0	0	2.0	
i 1	60.2611768707483	26.26	63	1088	5	25	6	1	0	1	1	0	0	2.2996626092540455	
i 1	60.26261904761905	1.2625	61	702	3	13	4	16	0	2	16	0	0	1.4105596104834173	
i 1	60.264061224489794	0.505	69	702	4	24	12	1	0	0	1	0	0	3.0	
i 1	60.483054421768706	1.01	77	702	6	5	1	17	0	2	17	0	0	5.0	
i 1	60.49242857142857	1.2625	72	204	4	1	6	0	0	-1	0	0	0	2.0	
i 1	60.49387074829932	1.2625	72	1088	5	1	4	0	0	-1	0	0	0	2.0	
i 1	60.513340136054424	2.7775	77	702	4	5	14	16	0	2	16	0	0	5.0	
i 1	60.764061224489794	0.2525	69	1088	5	1	1	0	0	0	0	0	0	2.0	
i 1	60.76478231292517	0.2525	77	702	5	3	7	17	0	1	17	0	0	3.0	
i 1	60.99891836734694	2.02	74	702	2	20	2	2	0	-2	2	0	0	3.898945826134887	
i 1	61.23738095238095	0.2525	71	702	1	24	13	2	0	1	2	0	0	7.898945826134887	
i 1	61.24387074829932	0.2525	74	702	1	20	12	2	0	-2	2	0	0	3.898945826134887	
i 1	61.24891836734694	2.02	72	702	4	24	8	0	0	-1	0	0	0	3.0	
i 1	61.25252380952381	0.2525	77	204	6	9	10	16	0	2	16	0	0	2.0	
i 1	61.253965986394554	0.2525	71	1088	1	20	2	2	0	1	2	0	0	3.898945826134887	
i 1	61.483054421768706	12.120000000000001	63	590	3	13	13	1	0	1	1	0	0	1.4105596104834173	
i 1	61.48738095238095	1.7675	77	590	4	5	8	17	0	1	17	0	0	5.0	
i 1	61.49098639455782	1.7675	63	590	5	15	11	16	0	1	16	0	0	3.247315634267973	
i 1	61.49387074829932	0.2525	69	1088	5	1	15	0	0	0	0	0	0	2.0	
i 1	61.49747619047619	1.2625	71	702	1	24	7	2	0	252	2	307	0	7.898945826134887	
i 1	61.49891836734694	0.2525	74	590	6	5	8	16	0	1	16	0	0	5.0	
i 1	61.50108163265306	0.2525	77	1088	5	2	6	17	0	2	17	0	0	3.0	
i 1	61.5082925170068	1.7675	63	590	6	7	5	1	0	2	1	0	0	4.231678831450252	
i 1	61.509734693877554	0.505	74	204	6	9	4	16	0	1	16	0	0	2.0	
i 1	61.514061224489794	1.7675	61	590	5	15	2	16	0	1	16	0	0	3.247315634267973	
i 1	61.51766666666666	2.02	69	590	4	24	2	0	0	-1	0	0	0	3.0	
i 1	61.739544217687076	0.2525	74	1088	6	5	9	16	0	1	16	0	0	5.0	
i 1	61.74387074829932	1.7675	77	702	5	3	7	17	0	1	17	0	0	3.0	
i 1	61.763340136054424	1.5150000000000001	77	590	5	3	15	17	0	2	17	0	0	3.0	
i 1	61.99387074829932	0.7575000000000001	77	204	6	9	15	16	0	2	16	0	0	2.0	
i 1	62.00108163265306	0.7575000000000001	74	1088	6	2	13	17	0	2	17	0	0	3.0	
i 1	62.00901360544218	0.2525	72	204	4	1	3	0	0	-1	0	0	0	2.0	
i 1	62.23810204081633	2.02	74	1088	6	5	13	16	0	1	16	0	0	5.0	
i 1	62.26622448979592	0.2525	69	1088	5	1	12	0	0	0	0	0	0	2.0	
i 1	62.493149659863946	0.2525	74	204	1	20	5	2	0	1	2	0	0	3.898945826134887	
i 1	62.500360544217685	0.7575000000000001	71	702	2	24	12	8	0	1	8	0	0	7.898945826134887	
i 1	62.739544217687076	1.5150000000000001	77	204	4	5	13	17	0	2	17	0	0	5.0	
i 1	62.740265306122446	0.2525	74	590	1	20	14	2	0	-2	2	0	0	3.898945826134887	
i 1	62.74531292517007	0.2525	71	1088	1	20	5	2	0	-2	2	0	0	3.898945826134887	
i 1	62.753244897959185	0.2525	74	590	4	4	16	17	0	1	17	0	0	3.0	
i 1	62.75901360544218	0.2525	74	590	1	24	2	8	0	-2	8	0	0	7.898945826134887	
i 1	62.766945578231294	0.505	71	204	4	20	10	2	0	-2	2	0	0	3.898945826134887	
i 1	62.99098639455782	1.2625	77	1088	5	2	1	17	0	2	17	0	0	3.0	
i 1	62.99098639455782	1.2625	74	204	6	9	9	16	0	1	16	0	0	2.0	
i 1	62.99459183673469	1.01	69	1088	5	1	3	0	0	0	0	0	0	2.0	
i 1	63.01261904761905	2.7775	74	204	1	20	6	2	0	-2	2	0	0	3.898945826134887	
i 1	63.24098639455782	5.8075	61	590	5	15	7	16	0	1	16	0	0	3.247315634267973	
i 1	63.2417074829932	0.2525	72	702	3	24	11	0	0	-1	0	0	0	3.0	
i 1	63.24531292517007	23.23	63	1088	5	25	16	1	0	2	1	0	0	2.2996626092540455	
i 1	63.24891836734694	1.7675	71	702	1	24	7	8	0	248	8	308	0	7.898945826134887	
i 1	63.25180272108844	2.525	71	204	1	20	3	2	0	-2	2	0	0	3.898945826134887	
i 1	63.256850340136054	0.2525	77	204	4	5	4	17	0	2	17	0	0	5.0	
i 1	63.2611768707483	0.7575000000000001	72	204	5	1	14	0	0	-1	0	0	0	2.0	
i 1	63.26261904761905	23.23	61	702	1	27	9	16	0	252	16	307	0	3.0662168123387277	
i 1	63.264061224489794	10.352500000000001	63	590	4	7	10	1	0	2	1	0	0	4.231678831450252	
i 1	63.5082925170068	0.2525	74	590	4	4	10	17	0	1	17	0	0	3.0	
i 1	63.73521768707483	1.7675	69	702	3	1	13	1	0	-1	1	0	0	2.0	
i 1	63.74819727891156	1.7675	77	702	5	3	12	17	0	1	17	0	0	3.0	
i 1	63.76550340136055	1.7675	77	590	5	3	4	17	0	2	17	0	0	3.0	
i 1	63.766945578231294	1.7675	69	590	5	1	4	0	0	0	0	0	0	2.0	
i 1	63.98521768707483	0.2525	74	702	4	5	14	17	0	1	17	0	0	5.0	
i 1	64.00036054421768	0.505	69	590	4	24	13	0	0	-1	0	0	0	3.0	
i 1	64.23233333333333	2.525	74	1088	6	5	11	17	0	2	17	0	0	5.0	
i 1	64.24026530612245	2.525	77	204	4	5	9	17	0	2	17	0	0	5.0	
i 1	64.25108163265305	0.2525	74	1088	5	2	16	17	0	2	17	0	0	3.0	
i 1	64.4888231292517	0.2525	74	702	4	5	5	17	0	1	17	0	0	5.0	
i 1	64.50757142857142	0.2525	72	204	5	1	3	0	0	-1	0	0	0	2.0	
i 1	64.73233333333333	1.01	77	204	4	5	11	17	0	2	17	0	0	5.0	
i 1	64.73233333333333	0.505	71	204	1	24	2	2	0	252	2	307	0	7.898945826134887	
i 1	64.74819727891156	0.2525	72	1088	6	1	6	0	0	-1	0	0	0	2.0	
i 1	64.7611768707483	1.01	77	702	4	4	5	17	0	2	17	0	0	3.0	
i 1	64.99242857142858	0.7575000000000001	74	590	4	4	8	17	0	1	17	0	0	3.0	
i 1	65.00036054421768	0.2525	71	702	3	24	5	8	0	1	8	0	0	7.898945826134887	
i 1	65.0054081632653	1.01	72	204	5	1	10	0	0	-1	0	0	0	2.0	
i 1	65.0140612244898	1.01	69	1088	5	1	6	0	0	0	0	0	0	2.0	
i 1	65.23521768707484	3.7875	71	204	1	24	16	2	0	-2	2	0	0	7.898945826134887	
i 1	65.24531292517007	1.01	74	204	6	9	7	16	0	1	16	0	0	2.0	
i 1	65.2611768707483	2.2725	74	702	2	20	1	2	0	-2	2	0	0	3.898945826134887	
i 1	65.26261904761905	1.01	77	1088	5	2	4	17	0	2	17	0	0	3.0	
i 1	65.50901360544218	5.05	69	590	4	24	14	0	0	-1	0	0	0	3.0	
i 1	65.51189795918367	5.05	72	702	3	24	16	0	0	-1	0	0	0	3.0	
i 1	65.7359387755102	1.01	77	590	5	3	12	17	0	2	17	0	0	3.0	
i 1	65.73665986394558	0.2525	74	1088	6	5	14	16	0	1	16	0	0	5.0	
i 1	65.74531292517007	1.01	77	702	5	3	14	17	0	1	17	0	0	3.0	
i 1	65.99098639455782	1.01	77	590	6	5	12	17	0	1	17	0	0	5.0	
i 1	66.01766666666667	0.2525	69	702	3	1	5	1	0	-1	1	0	0	2.0	
i 1	66.24026530612245	0.7575000000000001	72	1088	6	1	16	0	0	-1	0	0	0	2.0	
i 1	66.24026530612245	1.5150000000000001	74	1088	5	2	5	17	0	2	17	0	0	3.0	
i 1	66.24531292517007	1.01	77	702	4	5	12	16	0	2	16	0	0	5.0	
i 1	66.25901360544218	1.5150000000000001	77	204	6	9	12	16	0	2	16	0	0	2.0	
i 1	66.26694557823129	0.7575000000000001	69	204	5	1	2	1	0	0	1	0	0	2.0	
i 1	66.4888231292517	0.505	74	204	1	20	2	2	0	-2	2	0	0	3.898945826134887	
i 1	66.49387074829932	2.525	71	204	1	20	14	2	0	-2	2	0	0	3.898945826134887	
i 1	66.51334013605442	2.02	77	204	4	5	15	17	0	2	17	0	0	5.0	
i 1	66.51550340136055	2.02	74	1088	6	5	11	16	0	1	16	0	0	5.0	
i 1	66.73233333333333	0.2525	74	590	4	4	12	17	0	1	17	0	0	3.0	
i 1	66.98665986394558	0.2525	69	702	3	1	8	1	0	-1	1	0	0	2.0	
i 1	66.99314965986395	0.2525	77	702	4	4	5	17	0	2	17	0	0	3.0	
i 1	67.00324489795918	0.2525	74	590	1	24	6	2	0	1	2	0	0	7.898945826134887	
i 1	67.00396598639456	0.2525	74	1088	1	20	16	2	0	-2	2	0	0	3.898945826134887	
i 1	67.23810204081633	1.7675	71	204	1	20	6	2	0	-2	2	0	0	3.898945826134887	
i 1	67.23954421768707	0.2525	77	590	6	5	9	17	0	1	17	0	0	5.0	
i 1	67.25324489795918	1.7675	74	702	1	24	2	8	0	248	8	308	0	7.898945826134887	
i 1	67.26334013605442	0.2525	69	1088	5	1	7	0	0	0	0	0	0	2.0	
i 1	67.26334013605442	1.7675	77	590	5	3	12	17	0	2	17	0	0	3.0	
i 1	67.26694557823129	1.7675	77	702	5	3	6	17	0	1	17	0	0	3.0	
i 1	67.48810204081633	0.2525	77	204	4	5	4	17	0	2	17	0	0	5.0	
i 1	67.73305442176871	0.2525	74	204	6	9	3	16	0	1	16	0	0	2.0	
i 1	67.73449659863945	0.2525	77	702	4	5	7	16	0	2	16	0	0	5.0	
i 1	67.75324489795918	0.2525	72	1088	6	1	8	0	0	-1	0	0	0	2.0	
i 1	67.99098639455782	2.02	74	590	6	5	11	16	0	1	16	0	0	5.0	
i 1	67.99675510204082	1.01	69	1088	5	1	3	0	0	0	0	0	0	2.0	
i 1	67.99819727891156	1.01	77	1088	5	2	12	17	0	2	17	0	0	3.0	
i 1	68.00180272108844	1.01	72	204	5	1	6	0	0	-1	0	0	0	2.0	
i 1	68.00324489795918	1.01	74	702	4	5	4	17	0	1	17	0	0	5.0	
i 1	68.25396598639456	0.7575000000000001	74	204	6	9	16	16	0	1	16	0	0	2.0	
i 1	68.50901360544218	0.2525	74	1088	6	5	12	17	0	2	17	0	0	5.0	
i 1	68.76334013605442	0.2525	77	590	6	5	5	17	0	1	17	0	0	5.0	
i 1	68.98305442176871	0.7575000000000001	77	702	5	3	11	17	0	1	17	0	0	3.0	
i 1	68.9859387755102	0.2525	72	1088	6	1	13	0	0	-1	0	0	0	2.0	
i 1	68.98738095238095	17.4225	63	702	1	27	16	16	0	248	16	308	0	3.0662168123387277	
i 1	68.99026530612245	1.01	74	702	3	5	11	17	0	1	17	0	0	5.0	
i 1	68.99531292517007	3.2825	71	204	1	24	13	2	0	-2	2	0	0	6.452229829159794	
i 1	68.99747619047619	4.545	63	590	5	25	15	1	0	1	1	0	0	2.2996626092540455	
i 1	69.00468707482993	0.505	71	204	1	20	5	2	0	-2	2	0	0	2.452229829159794	
i 1	69.00685034013605	5.8075	61	204	5	16	8	16	0	1	16	0	0	3.711217867734826	
i 1	69.01622448979592	1.5150000000000001	77	702	4	4	5	17	0	2	17	0	0	3.0	
i 1	69.01622448979592	2.02	71	204	1	20	8	2	0	-2	2	0	0	2.452229829159794	
i 1	69.01766666666667	0.7575000000000001	77	590	5	3	15	17	0	2	17	0	0	3.0	
i 1	69.24531292517007	1.01	74	590	4	4	10	17	0	1	17	0	0	3.0	
i 1	69.25180272108844	0.2525	77	702	4	5	13	16	0	2	16	0	0	5.0	
i 1	69.25612925170068	0.2525	69	702	4	1	2	1	0	-1	1	0	0	2.0	
i 1	69.49026530612245	1.7675	77	204	4	5	14	17	0	2	17	0	0	5.0	
i 1	69.49819727891156	0.2525	71	590	1	24	10	2	0	1	2	0	0	6.452229829159794	
i 1	69.50396598639456	2.02	74	1088	6	5	5	17	0	2	17	0	0	5.0	
i 1	69.50396598639456	0.2525	71	1088	1	20	4	8	0	1	8	0	0	2.452229829159794	
i 1	69.74170748299319	0.2525	69	204	5	1	14	1	0	0	1	0	0	2.0	
i 1	69.7554081632653	1.5150000000000001	74	204	6	9	9	16	0	1	16	0	0	2.0	
i 1	69.75685034013605	1.01	74	702	3	20	15	2	0	-2	2	0	0	2.452229829159794	
i 1	69.75901360544218	1.5150000000000001	77	1088	5	2	11	17	0	2	17	0	0	3.0	
i 1	69.75973469387755	0.2525	74	204	1	20	15	8	0	1	8	0	0	2.452229829159794	
i 1	69.98521768707484	1.01	72	204	5	1	8	0	0	-1	0	0	0	2.0	
i 1	69.99170748299319	0.505	71	1088	1	20	8	2	0	1	2	0	0	2.452229829159794	
i 1	69.99603401360544	0.505	71	590	1	24	14	2	0	1	2	0	0	6.452229829159794	
i 1	69.99747619047619	2.02	69	1088	6	1	12	0	0	0	0	0	0	2.0	
i 1	70.01261904761905	0.505	74	1088	6	5	2	16	0	1	16	0	0	5.0	
i 1	70.48233333333333	1.5150000000000001	74	204	1	20	11	2	0	1	2	0	0	2.452229829159794	
i 1	70.49675510204082	1.2625	69	590	5	1	16	0	0	0	0	0	0	2.0	
i 1	70.49747619047619	1.2625	69	702	4	1	13	1	0	-1	1	0	0	2.0	
i 1	70.49747619047619	0.505	71	204	1	20	8	2	0	-2	2	0	0	2.452229829159794	
i 1	70.50685034013605	1.5150000000000001	71	702	1	24	15	2	0	252	2	307	0	6.452229829159794	
i 1	70.51550340136055	3.2825	77	702	5	3	6	17	0	1	17	0	0	3.0	
i 1	70.51622448979592	0.2525	74	702	3	5	10	17	0	1	17	0	0	5.0	
i 1	70.73305442176871	1.7675	77	702	4	5	5	16	0	2	16	0	0	5.0	
i 1	70.73521768707484	2.7775	77	590	5	3	1	17	0	2	17	0	0	3.0	
i 1	70.75252380952381	1.7675	77	590	6	5	3	17	0	1	17	0	0	5.0	
i 1	71.25396598639456	1.01	72	204	5	1	9	0	0	-1	0	0	0	2.0	
i 1	71.26766666666667	0.2525	74	1088	5	2	11	17	0	2	17	0	0	3.0	
i 1	71.48449659863945	0.2525	77	204	7	5	10	17	0	2	17	0	0	5.0	
i 1	71.48954421768707	0.2525	74	590	4	4	4	17	0	1	17	0	0	3.0	
i 1	71.50180272108844	2.02	69	590	4	24	7	0	0	-1	0	0	0	3.0	
i 1	71.50468707482993	2.02	72	702	3	24	11	0	0	-1	0	0	0	3.0	
i 1	71.74603401360544	8.3325	71	204	1	20	13	2	0	-2	2	0	0	2.452229829159794	
i 1	71.74963945578232	0.2525	74	1088	6	5	11	17	0	2	17	0	0	5.0	
i 1	71.75324489795918	0.7575000000000001	77	204	6	9	14	16	0	2	16	0	0	2.0	
i 1	71.76766666666667	0.7575000000000001	74	1088	5	2	3	17	0	2	17	0	0	3.0	
i 1	71.99170748299319	0.2525	71	1088	1	20	1	2	0	-2	2	0	0	2.452229829159794	
i 1	72.00685034013605	0.2525	74	1088	1	20	7	2	0	-2	2	0	0	2.452229829159794	
i 1	72.0111768707483	3.2825	77	204	7	5	2	17	0	2	17	0	0	5.0	
i 1	72.01478231292516	1.5150000000000001	74	1088	6	5	14	16	0	1	16	0	0	5.0	
i 1	72.01622448979592	0.2525	71	590	1	24	12	2	0	-2	2	0	0	6.452229829159794	
i 1	72.23233333333333	0.2525	69	204	5	1	8	1	0	0	1	0	0	2.0	
i 1	72.23305442176871	1.01	77	1088	5	2	13	17	0	2	17	0	0	3.0	
i 1	72.23521768707484	0.7575000000000001	71	204	1	20	3	8	0	1	8	0	0	2.452229829159794	
i 1	72.24963945578232	2.7775	74	204	6	9	13	16	0	1	16	0	0	2.0	
i 1	72.25180272108844	0.7575000000000001	71	204	1	20	3	2	0	-2	2	0	0	2.452229829159794	
i 1	72.49387074829932	0.2525	72	204	5	1	11	0	0	-1	0	0	0	2.0	
i 1	72.50108163265305	0.2525	74	702	3	5	11	17	0	1	17	0	0	5.0	
i 1	72.73233333333333	1.01	69	204	5	1	2	1	0	0	1	0	0	2.0	
i 1	72.74747619047619	2.2725	71	204	1	24	16	2	0	-2	2	0	0	6.452229829159794	
i 1	72.75180272108844	0.2525	77	590	6	5	7	17	0	1	17	0	0	5.0	
i 1	72.76334013605442	0.7575000000000001	74	702	3	20	3	2	0	-2	2	0	0	2.452229829159794	
i 1	72.99314965986395	0.7575000000000001	74	1088	6	5	12	17	0	2	17	0	0	5.0	
i 1	72.9945918367347	0.7575000000000001	72	1088	6	1	14	0	0	-1	0	0	0	2.0	
i 1	72.9945918367347	0.2525	74	590	1	24	10	8	0	1	8	0	0	6.452229829159794	
i 1	72.99603401360544	0.2525	71	1088	1	20	6	2	0	-2	2	0	0	2.452229829159794	
i 1	73.00180272108844	0.7575000000000001	77	204	4	5	7	17	0	2	17	0	0	5.0	
i 1	73.00757142857142	0.2525	71	1088	1	20	3	2	0	1	2	0	0	2.452229829159794	
i 1	73.23233333333333	0.2525	77	590	6	5	11	17	0	1	17	0	0	5.0	
i 1	73.25180272108844	5.05	69	1088	6	1	5	0	0	0	0	0	0	2.0	
i 1	73.25612925170068	0.2525	74	590	4	4	3	17	0	1	17	0	0	3.0	
i 1	73.25612925170068	1.5150000000000001	74	204	1	20	15	2	0	-2	2	0	0	2.452229829159794	
i 1	73.25901360544218	5.05	69	702	4	1	5	1	0	-1	1	0	0	2.0	
i 1	73.48449659863945	0.2525	74	386	5	3	14	17	0	2	17	0	0	3.0	
i 1	73.48810204081633	1.2625	74	386	4	4	5	16	0	2	16	0	0	3.0	
i 1	73.49098639455782	12.8775	61	386	3	13	10	1	0	2	1	0	0	1.4105596104834173	
i 1	73.50252380952381	12.8775	61	386	4	7	3	16	0	1	16	0	0	4.231678831450252	
i 1	73.50612925170068	12.8775	61	386	5	25	15	1	0	2	1	0	0	2.2996626092540455	
i 1	73.51045578231293	1.7675	74	386	6	5	11	16	0	2	16	0	0	5.0	
i 1	73.74819727891156	0.2525	72	204	5	1	7	0	0	-1	0	0	0	2.0	
i 1	73.75036054421768	0.2525	74	1088	6	5	13	16	0	1	16	0	0	5.0	
i 1	73.75829251700681	0.505	74	1088	5	2	12	17	0	2	17	0	0	3.0	
i 1	73.99603401360544	0.2525	69	204	5	1	8	1	0	0	1	0	0	2.0	
i 1	74.00829251700681	0.2525	77	702	4	5	13	16	0	2	16	0	0	5.0	
i 1	74.25252380952381	1.5150000000000001	77	1088	5	2	16	17	0	2	17	0	0	3.0	
i 1	74.25612925170068	1.5150000000000001	77	204	6	9	2	16	0	2	16	0	0	2.0	
i 1	74.26045578231293	0.2525	69	386	4	24	1	1	0	0	1	0	0	3.0	
i 1	74.4859387755102	1.2625	69	204	5	1	7	1	0	0	1	0	0	2.0	
i 1	74.5140612244898	0.2525	77	386	6	5	16	17	0	1	17	0	0	5.0	
i 1	74.73305442176871	11.615	63	386	5	25	9	16	0	2	16	0	0	2.2996626092540455	
i 1	74.73665986394558	1.01	69	386	4	24	4	1	0	0	1	0	0	3.0	
i 1	74.74170748299319	2.02	77	204	7	5	4	17	0	2	17	0	0	5.0	
i 1	74.74819727891156	0.7575000000000001	74	204	1	20	15	8	0	-2	8	0	0	2.452229829159794	
i 1	74.74891836734695	2.2725	74	1088	6	5	7	16	0	1	16	0	0	5.0	
i 1	74.76694557823129	5.8075	63	204	5	16	2	1	0	2	1	0	0	3.711217867734826	
i 1	74.76766666666667	0.7575000000000001	74	204	4	20	5	2	0	-2	2	0	0	2.452229829159794	
i 1	75.00685034013605	0.2525	74	386	4	4	14	16	0	2	16	0	0	3.0	
i 1	75.24963945578232	0.505	77	386	6	5	6	17	0	1	17	0	0	5.0	
i 1	75.2554081632653	6.565	77	702	4	4	2	17	0	2	17	0	0	3.0	
i 1	75.25757142857142	6.565	74	386	5	3	6	17	0	2	17	0	0	3.0	
i 1	75.26622448979592	3.0300000000000002	71	204	1	24	15	2	0	-2	2	0	0	6.452229829159794	
i 1	75.48449659863945	0.2525	74	1088	1	20	15	2	0	-2	2	0	0	2.452229829159794	
i 1	75.48665986394558	0.2525	74	1088	4	20	2	2	0	1	2	0	0	2.452229829159794	
i 1	75.48665986394558	0.2525	74	386	1	24	14	8	0	-2	8	0	0	6.452229829159794	
i 1	75.51045578231293	0.7575000000000001	77	702	5	3	12	17	0	1	17	0	0	3.0	
i 1	75.5140612244898	0.7575000000000001	74	1088	5	2	4	17	0	2	17	0	0	3.0	
i 1	75.73738095238095	1.5150000000000001	71	702	1	24	16	2	0	252	2	307	0	6.452229829159794	
i 1	75.75108163265305	1.5150000000000001	74	204	4	20	1	8	0	1	8	0	0	2.452229829159794	
i 1	75.75468707482993	0.2525	74	204	1	20	1	8	0	1	8	0	0	2.452229829159794	
i 1	75.75685034013605	0.2525	77	702	3	5	13	16	0	2	16	0	0	5.0	
i 1	75.7611768707483	1.01	69	386	6	1	13	0	0	-1	0	0	0	2.0	
i 1	75.99747619047619	3.2825	74	1088	6	5	13	17	0	2	17	0	0	5.0	
i 1	76.01478231292516	1.01	72	702	4	24	11	0	0	-1	0	0	0	3.0	
i 1	76.25036054421768	3.0300000000000002	74	702	3	5	9	17	0	1	17	0	0	5.0	
i 1	76.25829251700681	1.01	77	204	6	9	2	16	0	2	16	0	0	2.0	
i 1	76.26694557823129	1.01	77	1088	5	2	14	17	0	2	17	0	0	3.0	
i 1	76.98377551020408	0.2525	72	204	5	1	15	0	0	-1	0	0	0	2.0	
i 1	77.00468707482993	0.2525	77	204	7	5	14	17	0	2	17	0	0	5.0	
i 1	77.23810204081633	0.2525	74	1088	5	2	11	17	0	2	17	0	0	3.0	
i 1	77.24170748299319	0.2525	74	1088	4	20	3	2	0	-2	2	0	0	2.452229829159794	
i 1	77.2445918367347	0.2525	72	702	4	24	14	0	0	-1	0	0	0	3.0	
i 1	77.25396598639456	0.2525	74	386	1	24	16	8	0	-2	8	0	0	6.452229829159794	
i 1	77.26189795918367	0.2525	77	702	3	5	3	16	0	2	16	0	0	5.0	
i 1	77.4888231292517	0.2525	77	386	6	5	5	17	0	1	17	0	0	5.0	
i 1	77.49387074829932	0.2525	74	386	4	4	10	16	0	2	16	0	0	3.0	
i 1	77.51550340136055	1.2625	69	386	4	24	13	1	0	0	1	0	0	3.0	
i 1	77.51622448979592	0.2525	71	204	4	20	10	2	0	1	2	0	0	2.452229829159794	
i 1	77.73377551020408	0.2525	74	386	1	24	4	2	0	-2	2	0	0	6.452229829159794	
i 1	77.74098639455782	0.2525	71	386	1	20	5	2	0	-2	2	0	0	2.452229829159794	
i 1	77.74242857142858	0.2525	71	1088	4	20	4	2	0	1	2	0	0	2.452229829159794	
i 1	77.74603401360544	1.01	69	204	5	1	3	1	0	0	1	0	0	2.0	
i 1	77.75757142857142	0.505	74	386	6	5	3	16	0	2	16	0	0	5.0	
i 1	78.00324489795918	0.2525	74	386	4	4	15	16	0	2	16	0	0	3.0	
i 1	78.01045578231293	1.2625	74	204	4	20	4	2	0	1	2	0	0	2.452229829159794	
i 1	78.24747619047619	1.2625	74	204	6	9	14	16	0	1	16	0	0	2.0	
i 1	78.24819727891156	2.02	72	204	5	1	10	0	0	-1	0	0	0	2.0	
i 1	78.25252380952381	0.2525	74	1088	6	5	11	16	0	1	16	0	0	5.0	
i 1	78.2640612244898	2.02	72	1088	6	1	13	0	0	-1	0	0	0	2.0	
i 1	78.4859387755102	1.2625	71	204	1	24	3	2	0	-2	2	0	0	6.452229829159794	
i 1	78.49891836734695	0.2525	77	204	7	5	5	17	0	2	17	0	0	5.0	
i 1	78.73521768707484	0.7575000000000001	71	204	1	20	14	2	0	1	2	0	0	2.452229829159794	
i 1	78.7359387755102	1.5150000000000001	77	204	7	5	4	17	0	2	17	0	0	5.0	
i 1	78.74314965986395	0.7575000000000001	74	386	4	4	10	16	0	2	16	0	0	3.0	
i 1	78.7445918367347	1.5150000000000001	74	386	6	5	9	16	0	2	16	0	0	5.0	
i 1	78.7554081632653	0.2525	72	702	4	24	8	0	0	-1	0	0	0	3.0	
i 1	78.99387074829932	0.7575000000000001	77	204	6	9	14	16	0	2	16	0	0	2.0	
i 1	79.0054081632653	0.7575000000000001	77	1088	5	2	10	17	0	2	17	0	0	3.0	
i 1	79.01334013605442	0.2525	69	702	4	1	7	1	0	-1	1	0	0	2.0	
i 1	79.23449659863945	0.505	72	702	4	24	3	0	0	-1	0	0	0	3.0	
i 1	79.26478231292516	1.2625	74	1088	6	5	13	16	0	1	16	0	0	5.0	
i 1	79.4888231292517	0.2525	74	1088	1	20	1	2	0	-2	2	0	0	2.452229829159794	
i 1	79.51622448979592	0.2525	74	386	1	24	4	2	0	-2	2	0	0	6.452229829159794	
i 1	79.73665986394558	1.01	77	702	5	3	16	17	0	1	17	0	0	3.0	
i 1	79.73738095238095	0.7575000000000001	69	386	4	24	2	1	0	0	1	0	0	3.0	
i 1	79.73738095238095	1.01	69	204	5	1	7	1	0	0	1	0	0	2.0	
i 1	79.74026530612245	0.7575000000000001	74	204	1	20	3	2	0	-2	2	0	0	2.452229829159794	
i 1	79.75252380952381	0.7575000000000001	77	204	7	5	12	17	0	2	17	0	0	5.0	
i 1	79.76189795918367	1.01	74	1088	5	2	11	17	0	2	17	0	0	3.0	
i 1	79.99314965986395	0.2525	71	204	1	24	11	2	0	-2	2	0	0	6.452229829159794	
i 1	80.01478231292516	0.505	74	702	3	5	5	17	0	1	17	0	0	5.0	
i 1	80.01694557823129	3.535	74	1088	6	5	1	17	0	2	17	0	0	5.0	
i 1	80.25324489795918	5.05	69	702	4	1	7	1	0	-1	1	0	0	2.0	
i 1	80.2554081632653	5.05	69	1088	6	1	14	0	0	0	0	0	0	2.0	
i 1	80.48377551020408	0.7575000000000001	74	204	4	20	13	8	0	-2	8	0	0	2.452229829159794	
i 1	80.49170748299319	0.2525	69	386	4	24	6	1	0	0	1	0	0	3.0	
i 1	80.49819727891156	2.2725	71	204	1	20	3	2	0	-2	2	0	0	2.452229829159794	
i 1	80.50036054421768	5.8075	63	204	5	26	3	1	0	1	1	0	0	2.2996626092540455	
i 1	80.50036054421768	0.505	74	204	4	20	4	2	0	-2	2	0	0	2.452229829159794	
i 1	80.50396598639456	5.8075	61	702	5	12	11	16	0	1	16	0	0	3.711217867734826	
i 1	80.50396598639456	0.2525	77	386	6	5	1	17	0	1	17	0	0	5.0	
i 1	80.50612925170068	5.8075	61	1088	5	14	9	16	0	2	16	0	0	5.642238441933669	
i 1	80.51261904761905	3.0300000000000002	74	702	6	5	11	17	0	1	17	0	0	5.0	
i 1	80.7445918367347	0.2525	69	386	6	1	11	0	0	-1	0	0	0	2.0	
i 1	80.7445918367347	0.2525	74	386	4	4	7	16	0	2	16	0	0	3.0	
i 1	80.75252380952381	0.2525	77	204	7	5	2	17	0	2	17	0	0	5.0	
i 1	80.99891836734695	0.2525	74	204	5	9	7	16	0	1	16	0	0	2.0	
i 1	81.00036054421768	1.5150000000000001	71	204	1	24	6	2	0	-2	2	0	0	6.452229829159794	
i 1	81.01478231292516	1.2625	69	204	5	1	10	1	0	0	1	0	0	2.0	
i 1	81.01622448979592	0.7575000000000001	69	386	4	24	11	1	0	0	1	0	0	3.0	
i 1	81.23954421768707	0.2525	74	1088	4	20	3	2	0	-2	2	0	0	2.452229829159794	
i 1	81.2445918367347	0.2525	71	386	1	24	4	2	0	1	2	0	0	6.452229829159794	
i 1	81.24819727891156	1.5150000000000001	77	1088	6	2	13	17	0	2	17	0	0	3.0	
i 1	81.24891836734695	1.5150000000000001	77	204	6	9	6	16	0	2	16	0	0	2.0	
i 1	81.25036054421768	0.2525	77	204	7	5	1	17	0	2	17	0	0	5.0	
i 1	81.25829251700681	0.2525	74	386	1	20	14	2	0	-2	2	0	0	2.452229829159794	
i 1	81.49603401360544	1.01	71	204	4	20	11	2	0	1	2	0	0	2.452229829159794	
i 1	81.49675510204082	0.7575000000000001	77	204	7	5	2	17	0	2	17	0	0	5.0	
i 1	81.76261904761905	0.2525	74	386	4	4	14	16	0	2	16	0	0	3.0	
i 1	82.00901360544218	1.2625	74	204	4	20	6	2	0	-2	2	0	0	2.452229829159794	
i 1	82.01766666666667	1.2625	77	702	4	4	4	17	0	2	17	0	0	3.0	
i 1	82.23305442176871	1.01	74	386	5	3	9	17	0	2	17	0	0	3.0	
i 1	82.24242857142858	0.2525	74	386	6	5	13	16	0	2	16	0	0	5.0	
i 1	82.26478231292516	0.2525	69	386	4	24	9	1	0	0	1	0	0	3.0	
i 1	82.50180272108844	0.2525	77	204	7	5	14	17	0	2	17	0	0	5.0	
i 1	82.51189795918367	1.2625	72	702	4	24	14	0	0	-1	0	0	0	3.0	
i 1	82.73233333333333	1.01	69	386	6	1	1	0	0	-1	0	0	0	2.0	
i 1	82.73521768707484	1.01	74	204	5	9	5	16	0	1	16	0	0	2.0	
i 1	82.74387074829932	0.2525	77	386	6	5	4	17	0	1	17	0	0	5.0	
i 1	82.74747619047619	1.01	74	386	4	4	1	16	0	2	16	0	0	3.0	
i 1	82.99603401360544	1.7675	77	204	7	5	9	17	0	2	17	0	0	5.0	
i 1	82.99891836734695	2.2725	74	386	6	5	14	16	0	2	16	0	0	5.0	
i 1	83.0054081632653	1.5150000000000001	71	204	1	20	13	2	0	-2	2	0	0	2.452229829159794	
i 1	83.25252380952381	1.01	74	1088	4	20	10	8	0	1	8	0	0	2.452229829159794	
i 1	83.26189795918367	1.01	77	204	6	9	4	16	0	2	16	0	0	2.0	
i 1	83.26766666666667	1.5150000000000001	77	1088	6	2	15	17	0	2	17	0	0	3.0	
i 1	83.49098639455782	0.7575000000000001	71	386	1	24	2	2	0	1	2	0	0	6.452229829159794	
i 1	83.49603401360544	0.2525	77	702	3	5	16	16	0	2	16	0	0	5.0	
i 1	83.73233333333333	0.2525	69	386	4	24	3	1	0	0	1	0	0	3.0	
i 1	83.74314965986395	1.5150000000000001	74	386	5	3	14	17	0	2	17	0	0	3.0	
i 1	83.74963945578232	0.2525	77	204	7	5	2	17	0	2	17	0	0	5.0	
i 1	83.75685034013605	1.5150000000000001	77	702	4	4	2	17	0	2	17	0	0	3.0	
i 1	84.00901360544218	0.2525	72	204	5	1	15	0	0	-1	0	0	0	2.0	
i 1	84.01261904761905	3.0300000000000002	71	204	1	24	5	2	0	-2	2	0	0	6.452229829159794	
i 1	84.01694557823129	0.2525	77	386	6	5	1	17	0	1	17	0	0	5.0	
i 1	84.23954421768707	1.7675	77	204	7	5	12	17	0	2	17	0	0	5.0	
i 1	84.24603401360544	1.7675	74	1088	6	5	5	16	0	1	16	0	0	5.0	
i 1	84.24747619047619	1.5150000000000001	74	204	4	20	9	2	0	-2	2	0	0	2.452229829159794	
i 1	84.51189795918367	0.2525	72	1088	6	1	11	0	0	-1	0	0	0	2.0	
i 1	84.73305442176871	1.5150000000000001	74	1088	5	2	4	17	0	2	17	0	0	3.0	
i 1	84.73665986394558	1.5150000000000001	69	204	5	1	5	1	0	0	1	0	0	2.0	
i 1	84.73954421768707	1.5150000000000001	77	702	5	3	7	17	0	1	17	0	0	3.0	
i 1	84.74531292517007	1.01	69	386	4	24	13	1	0	0	1	0	0	3.0	
i 1	85.2359387755102	1.01	72	1088	6	1	16	0	0	-1	0	0	0	2.0	
i 1	85.24026530612245	0.505	74	204	4	20	3	2	0	-2	2	0	0	2.452229829159794	
i 1	85.2445918367347	1.01	72	204	5	1	5	0	0	-1	0	0	0	2.0	
i 1	85.26045578231293	0.7575000000000001	71	204	1	20	14	2	0	-2	2	0	0	2.452229829159794	
i 1	85.26261904761905	1.01	74	702	6	5	6	17	0	1	17	0	0	5.0	
i 1	85.26766666666667	0.2525	74	386	4	4	8	16	0	2	16	0	0	3.0	
i 1	85.49819727891156	0.7575000000000001	77	702	4	4	12	17	0	2	17	0	0	3.0	
i 1	85.51478231292516	0.7575000000000001	74	1088	6	5	12	17	0	2	17	0	0	5.0	
i 1	85.73521768707484	0.2525	71	386	1	24	5	2	0	1	2	0	0	6.452229829159794	
i 1	85.7359387755102	0.2525	71	1088	4	20	3	2	0	-2	2	0	0	2.452229829159794	
i 1	85.73665986394558	0.505	74	386	5	3	4	17	0	2	17	0	0	3.0	
i 1	85.76189795918367	0.2525	74	386	1	20	3	2	0	1	2	0	0	2.452229829159794	
i 1	85.98305442176871	0.2525	77	386	6	5	3	17	0	1	17	0	0	5.0	
i 1	85.98738095238095	0.2525	71	204	4	20	9	2	0	1	2	0	0	2.452229829159794	
i 1	85.99891836734695	0.2525	69	386	4	24	7	1	0	0	1	0	0	3.0	
i 1	85.99963945578232	0.2525	77	1088	6	2	14	17	0	2	17	0	0	3.0	
i 1	86.00108163265305	0.2525	77	204	6	9	12	16	0	2	16	0	0	2.0	
i 1	86.0140612244898	2.02	71	702	1	24	7	2	0	252	2	307	0	6.452229829159794	
i 1	86.23233333333333	0.505	69	204	7	1	8	1	0	0	1	0	0	9.0	
i 1	86.23233333333333	5.3025	63	702	1	27	2	16	0	252	16	307	0	2.646775903379499	
i 1	86.23305442176871	1.5150000000000001	77	702	4	4	12	17	0	2	17	0	0	3.3790095335108274	
i 1	86.23305442176871	5.3025	63	1088	5	25	16	1	0	2	1	0	0	1.8802217002948172	
i 1	86.23305442176871	5.3025	63	1088	5	14	6	1	0	1	1	0	0	2.8211192209668345	
i 1	86.23449659863945	1.01	74	702	6	5	8	17	0	1	17	0	0	2.0	
i 1	86.23665986394558	18.4325	63	204	5	26	16	1	0	1	1	0	0	1.8802217002948172	
i 1	86.23954421768707	0.2525	72	1088	6	1	10	0	0	-1	0	0	0	9.0	
i 1	86.23954421768707	5.3025	61	1088	5	14	15	16	0	2	16	0	0	2.8211192209668345	
i 1	86.24098639455782	5.3025	61	386	5	25	16	1	0	2	1	0	0	1.8802217002948172	
i 1	86.24242857142858	0.505	77	204	5	9	12	16	0	2	16	0	0	2.3790095335108274	
i 1	86.24242857142858	5.3025	63	386	5	25	2	16	0	2	16	0	0	1.8802217002948172	
i 1	86.2445918367347	0.505	74	1088	6	5	15	16	0	1	16	0	0	2.0	
i 1	86.24531292517007	5.3025	63	1088	5	25	9	1	0	1	1	0	0	1.8802217002948172	
i 1	86.24603401360544	1.7675	74	386	5	3	6	17	0	2	17	0	0	3.3790095335108274	
i 1	86.24675510204082	5.3025	69	702	4	1	5	1	0	-1	1	0	0	9.0	
i 1	86.24747619047619	0.2525	72	204	5	1	10	0	0	-1	0	0	0	9.0	
i 1	86.25036054421768	18.4325	61	204	5	26	16	16	0	2	16	0	0	1.8802217002948172	
i 1	86.26334013605442	0.505	77	1088	6	2	12	17	0	2	17	0	0	3.3790095335108274	
i 1	86.26334013605442	5.3025	61	386	4	7	3	16	0	1	16	0	0	1.4105596104834173	
i 1	86.2640612244898	5.3025	69	1088	6	1	5	0	0	0	0	0	0	9.0	
i 1	86.2640612244898	0.505	69	386	4	24	13	1	0	0	1	0	0	10.0	
i 1	86.26478231292516	1.01	74	1088	6	5	1	17	0	2	17	0	0	2.0	
i 1	86.26766666666667	5.3025	61	702	1	27	10	16	0	248	16	308	0	2.646775903379499	
i 1	86.26766666666667	0.7575000000000001	71	702	3	20	4	2	0	-2	2	0	0	2.452229829159794	
i 1	86.48233333333333	1.5150000000000001	74	204	4	20	5	2	0	1	2	0	0	2.452229829159794	
i 1	86.48305442176871	5.555	71	204	1	20	2	2	0	-2	2	0	0	2.452229829159794	
i 1	86.49819727891156	1.5150000000000001	71	204	4	20	14	2	0	1	2	0	0	2.452229829159794	
i 1	86.74387074829932	0.2525	69	386	6	1	16	0	0	-1	0	0	0	9.0	
i 1	86.74675510204082	2.02	74	386	4	4	6	16	0	2	16	0	0	3.3790095335108274	
i 1	86.74675510204082	2.2725	77	204	7	5	11	17	0	2	17	0	0	2.0	
i 1	86.75324489795918	2.02	74	386	6	5	4	16	0	2	16	0	0	2.0	
i 1	86.98738095238095	0.2525	72	204	5	1	2	0	0	-1	0	0	0	9.0	
i 1	87.25901360544218	1.5150000000000001	74	204	5	9	16	16	0	1	16	0	0	2.3790095335108274	
i 1	87.26478231292516	0.2525	77	386	6	5	16	17	0	1	17	0	0	2.0	
i 1	87.4859387755102	0.505	71	702	3	20	11	2	0	-2	2	0	0	2.452229829159794	
i 1	87.48665986394558	0.2525	74	1088	6	5	8	16	0	1	16	0	0	2.0	
i 1	87.50036054421768	0.2525	72	204	5	1	11	0	0	-1	0	0	0	9.0	
i 1	87.7445918367347	1.01	69	204	7	1	1	1	0	0	1	0	0	9.0	
i 1	87.75973469387755	1.01	69	386	4	24	1	1	0	0	1	0	0	10.0	
i 1	87.76334013605442	2.02	71	204	1	24	7	2	0	-2	2	0	0	6.452229829159794	
i 1	87.98521768707484	1.7675	77	204	5	9	8	16	0	2	16	0	0	2.3790095335108274	
i 1	87.9859387755102	0.2525	77	702	6	5	7	16	0	2	16	0	0	2.0	
i 1	88.00108163265305	0.2525	71	386	1	24	9	8	0	-2	8	0	0	6.452229829159794	
i 1	88.0054081632653	0.2525	74	386	4	20	14	2	0	-2	2	0	0	2.452229829159794	
i 1	88.01766666666667	0.2525	74	1088	4	20	14	2	0	1	2	0	0	2.452229829159794	
i 1	88.24242857142858	0.505	74	204	4	20	13	2	0	1	2	0	0	2.452229829159794	
i 1	88.24603401360544	2.02	77	204	7	5	5	17	0	2	17	0	0	2.0	
i 1	88.25036054421768	1.5150000000000001	77	1088	6	2	15	17	0	2	17	0	0	3.3790095335108274	
i 1	88.26550340136055	2.02	74	1088	6	5	8	16	0	1	16	0	0	2.0	
i 1	88.73449659863945	0.2525	71	1088	4	20	11	2	0	-2	2	0	0	2.452229829159794	
i 1	88.73954421768707	0.2525	71	386	4	20	15	2	0	-2	2	0	0	2.452229829159794	
i 1	88.74314965986395	0.2525	77	702	4	4	10	17	0	2	17	0	0	3.3790095335108274	
i 1	88.76334013605442	0.2525	71	386	1	24	8	2	0	-2	2	0	0	6.452229829159794	
i 1	88.76766666666667	0.2525	72	204	5	1	14	0	0	-1	0	0	0	9.0	
i 1	88.98377551020408	0.2525	74	204	5	9	7	16	0	1	16	0	0	2.3790095335108274	
i 1	88.98449659863945	0.2525	71	204	4	20	12	2	0	-2	2	0	0	2.452229829159794	
i 1	88.99819727891156	0.2525	72	1088	6	1	4	0	0	-1	0	0	0	9.0	
i 1	88.99963945578232	0.2525	74	702	6	5	2	17	0	1	17	0	0	2.0	
i 1	89.24026530612245	2.2725	74	386	5	3	2	17	0	2	17	0	0	3.3790095335108274	
i 1	89.24819727891156	0.2525	74	386	4	20	10	2	0	-2	2	0	0	2.452229829159794	
i 1	89.25468707482993	2.2725	77	702	4	4	1	17	0	2	17	0	0	3.3790095335108274	
i 1	89.25829251700681	0.2525	77	386	6	5	15	17	0	1	17	0	0	2.0	
i 1	89.25973469387755	0.2525	71	1088	4	20	12	2	0	1	2	0	0	2.452229829159794	
i 1	89.48377551020408	0.7575000000000001	77	702	5	3	4	17	0	1	17	0	0	3.3790095335108274	
i 1	89.48810204081633	0.2525	69	204	7	1	9	1	0	0	1	0	0	9.0	
i 1	89.50396598639456	0.7575000000000001	74	1088	6	2	1	17	0	2	17	0	0	3.3790095335108274	
i 1	89.50973469387755	1.2625	74	204	4	20	9	2	0	-2	2	0	0	2.452229829159794	
i 1	89.51550340136055	0.2525	77	204	7	5	15	17	0	2	17	0	0	2.0	
i 1	89.74026530612245	1.01	69	386	6	1	12	0	0	-1	0	0	0	9.0	
i 1	89.7445918367347	1.01	72	702	4	24	10	0	0	-1	0	0	0	10.0	
i 1	89.74963945578232	1.7675	74	702	6	5	3	17	0	1	17	0	0	2.0	
i 1	89.76694557823129	1.7675	74	1088	6	5	5	17	0	2	17	0	0	2.0	
i 1	89.99675510204082	0.7575000000000001	74	204	4	20	11	2	0	1	2	0	0	2.452229829159794	
i 1	90.25612925170068	1.01	77	1088	6	2	10	17	0	2	17	0	0	3.3790095335108274	
i 1	90.25901360544218	0.2525	77	386	6	5	8	17	0	1	17	0	0	2.0	
i 1	90.2640612244898	1.01	77	204	5	9	12	16	0	2	16	0	0	2.3790095335108274	
i 1	90.50901360544218	0.2525	74	386	6	5	9	16	0	2	16	0	0	2.0	
i 1	90.51261904761905	1.2625	71	204	1	24	6	2	0	-2	2	0	0	6.452229829159794	
i 1	90.73738095238095	0.7575000000000001	69	386	4	24	9	1	0	0	1	0	0	10.0	
i 1	90.74026530612245	0.2525	71	386	1	24	10	2	0	-2	2	0	0	6.452229829159794	
i 1	90.75036054421768	0.2525	74	1088	4	20	1	2	0	1	2	0	0	2.452229829159794	
i 1	90.75180272108844	0.2525	71	1088	4	20	15	2	0	1	2	0	0	2.452229829159794	
i 1	90.99026530612245	0.2525	74	204	4	20	7	2	0	-2	2	0	0	2.452229829159794	
i 1	90.99963945578232	0.505	74	204	4	20	1	8	0	-2	8	0	0	2.452229829159794	
i 1	91.0054081632653	0.7575000000000001	69	204	7	1	9	1	0	0	1	0	0	9.0	
i 1	91.24387074829932	1.5150000000000001	77	204	7	5	5	17	0	2	17	0	0	2.0	
i 1	91.25396598639456	0.2525	74	386	4	4	5	16	0	2	16	0	0	3.3790095335108274	
i 1	91.26045578231293	0.2525	72	702	4	24	1	0	0	-1	0	0	0	10.0	
i 1	91.48449659863945	14.645	63	906	5	25	13	16	0	1	16	0	0	1.8802217002948172	
i 1	91.4859387755102	0.505	74	590	1	24	14	8	0	-2	8	0	0	6.452229829159794	
i 1	91.48738095238095	0.2525	74	204	6	5	5	16	0	1	16	0	0	2.0	
i 1	91.48810204081633	0.505	61	204	1	27	13	16	0	252	16	307	0	2.646775903379499	
i 1	91.49314965986395	12.120000000000001	61	590	5	25	5	1	0	2	1	0	0	1.8802217002948172	
i 1	91.4945918367347	0.505	71	906	4	20	16	2	0	-2	2	0	0	2.452229829159794	
i 1	91.49603401360544	1.2625	77	906	6	5	7	16	0	2	16	0	0	2.0	
i 1	91.49819727891156	6.3125	63	590	4	7	13	16	0	1	16	0	0	1.4105596104834173	
i 1	91.49891836734695	0.2525	77	590	5	3	3	16	0	2	16	0	0	3.3790095335108274	
i 1	91.50324489795918	6.3125	61	590	5	25	1	1	0	2	1	0	0	1.8802217002948172	
i 1	91.50612925170068	1.2625	77	590	4	4	1	16	0	2	16	0	0	3.3790095335108274	
i 1	91.50685034013605	0.505	63	906	5	25	9	16	0	1	16	0	0	1.8802217002948172	
i 1	91.50757142857142	3.7875	69	590	4	24	1	1	0	-1	1	0	0	10.0	
i 1	91.50757142857142	14.645	61	906	5	14	2	16	0	2	16	0	0	2.8211192209668345	
i 1	91.51261904761905	14.645	61	906	5	14	3	1	0	1	1	0	0	2.8211192209668345	
i 1	91.5140612244898	1.2625	77	204	5	4	6	17	0	2	17	0	0	3.3790095335108274	
i 1	91.51550340136055	3.7875	72	204	4	24	16	0	0	-1	0	0	0	10.0	
i 1	91.74098639455782	0.2525	71	906	4	20	1	8	0	-2	8	0	0	2.452229829159794	
i 1	91.74314965986395	0.2525	72	204	5	1	12	0	0	-1	0	0	0	9.0	
i 1	91.76045578231293	0.2525	77	204	6	5	4	16	0	2	16	0	0	2.0	
i 1	91.98233333333333	3.7875	71	204	1	24	14	2	0	-2	2	0	0	5.0653834244099585	
i 1	91.98449659863945	0.7575000000000001	71	204	1	20	15	2	0	-2	2	0	0	1.0653834244099585	
i 1	91.98521768707484	0.7575000000000001	69	204	7	1	3	1	0	0	1	0	0	9.0	
i 1	91.98738095238095	0.2525	74	204	4	20	16	2	0	-2	2	0	0	1.0653834244099585	
i 1	91.98954421768707	2.525	77	906	6	5	12	17	0	1	17	0	0	2.0	
i 1	91.99387074829932	0.2525	71	204	3	24	8	8	0	1	8	0	0	5.0653834244099585	
i 1	92.00036054421768	14.14	63	906	5	25	16	16	0	1	16	0	0	1.8802217002948172	
i 1	92.00757142857142	12.625	61	204	4	27	5	16	0	1	16	0	0	2.646775903379499	
i 1	92.24242857142858	2.2725	77	204	7	5	14	17	0	2	17	0	0	2.0	
i 1	92.24891836734695	0.2525	74	590	4	24	10	2	0	1	2	0	0	5.0653834244099585	
i 1	92.25612925170068	0.7575000000000001	74	204	5	9	12	16	0	1	16	0	0	2.3790095335108274	
i 1	92.25829251700681	0.7575000000000001	74	906	6	2	6	17	0	2	17	0	0	3.3790095335108274	
i 1	92.4888231292517	1.7675	77	590	5	3	14	16	0	2	16	0	0	3.3790095335108274	
i 1	92.49242857142858	1.2625	74	204	4	20	14	2	0	-2	2	0	0	1.0653834244099585	
i 1	92.49531292517007	1.7675	77	204	4	3	14	17	0	2	17	0	0	3.3790095335108274	
i 1	92.49891836734695	0.2525	71	204	4	20	1	8	0	1	8	0	0	1.0653834244099585	
i 1	92.51189795918367	1.2625	74	204	3	24	16	2	0	1	2	0	0	5.0653834244099585	
i 1	92.73521768707484	1.01	72	204	7	1	11	0	0	-1	0	0	0	9.0	
i 1	92.7359387755102	1.01	72	906	6	1	11	1	0	0	1	0	0	9.0	
i 1	92.7359387755102	1.01	74	906	6	2	3	17	0	2	17	0	0	3.3790095335108274	
i 1	92.73738095238095	1.01	77	204	5	9	6	16	0	2	16	0	0	2.3790095335108274	
i 1	92.76694557823129	0.505	77	204	6	5	2	16	0	2	16	0	0	2.0	
i 1	93.23954421768707	0.2525	77	204	7	5	16	17	0	2	17	0	0	2.0	
i 1	93.49387074829932	0.7575000000000001	71	204	1	20	16	2	0	-2	2	0	0	1.0653834244099585	
i 1	93.50901360544218	0.2525	74	204	6	5	6	16	0	1	16	0	0	2.0	
i 1	93.73233333333333	1.5150000000000001	77	590	4	4	7	16	0	2	16	0	0	3.3790095335108274	
i 1	93.73521768707484	1.5150000000000001	77	204	5	4	10	17	0	2	17	0	0	3.3790095335108274	
i 1	93.74242857142858	0.2525	69	204	7	1	2	1	0	0	1	0	0	9.0	
i 1	93.74314965986395	0.505	71	590	4	24	8	2	0	1	2	0	0	5.0653834244099585	
i 1	93.7445918367347	0.505	71	906	4	20	11	2	0	-2	2	0	0	1.0653834244099585	
i 1	93.75036054421768	0.505	71	906	4	20	8	8	0	-2	8	0	0	1.0653834244099585	
i 1	93.7640612244898	0.2525	77	204	7	5	9	17	0	2	17	0	0	2.0	
i 1	94.00612925170068	0.2525	69	204	4	1	14	0	0	-1	0	0	0	9.0	
i 1	94.0111768707483	2.02	77	590	6	5	14	17	0	1	17	0	0	2.0	
i 1	94.01622448979592	2.2725	77	204	6	5	2	16	0	2	16	0	0	2.0	
i 1	94.2388231292517	0.2525	77	204	5	9	2	16	0	2	16	0	0	2.3790095335108274	
i 1	94.24675510204082	1.01	74	204	3	24	11	2	0	1	2	0	0	5.0653834244099585	
i 1	94.2554081632653	1.01	71	204	4	20	1	8	0	1	8	0	0	1.0653834244099585	
i 1	94.26766666666667	0.2525	74	204	4	20	10	2	0	-2	2	0	0	1.0653834244099585	
i 1	94.50108163265305	0.2525	74	204	5	9	4	16	0	1	16	0	0	2.3790095335108274	
i 1	94.50901360544218	0.2525	69	204	4	1	12	0	0	-1	0	0	0	9.0	
i 1	94.51550340136055	0.505	77	590	6	5	9	16	0	2	16	0	0	2.0	
i 1	94.73954421768707	1.7675	77	590	5	3	16	16	0	2	16	0	0	3.3790095335108274	
i 1	94.74026530612245	1.7675	77	204	4	3	16	17	0	2	17	0	0	3.3790095335108274	
i 1	94.74819727891156	1.01	72	906	6	1	9	1	0	0	1	0	0	9.0	
i 1	94.75036054421768	1.01	72	204	7	1	10	0	0	-1	0	0	0	9.0	
i 1	95.00685034013605	0.2525	77	906	6	5	10	16	0	2	16	0	0	2.0	
i 1	95.00901360544218	2.525	71	204	1	20	9	2	0	-2	2	0	0	1.0653834244099585	
i 1	95.01189795918367	0.2525	74	204	4	20	12	2	0	-2	2	0	0	1.0653834244099585	
i 1	95.2359387755102	0.2525	71	590	4	24	3	2	0	-2	2	0	0	5.0653834244099585	
i 1	95.24242857142858	0.2525	71	906	4	20	14	2	0	-2	2	0	0	1.0653834244099585	
i 1	95.2445918367347	0.2525	74	906	6	2	7	17	0	2	17	0	0	3.3790095335108274	
i 1	95.24603401360544	0.2525	77	204	7	5	3	17	0	2	17	0	0	2.0	
i 1	95.24819727891156	1.2625	72	590	6	1	2	1	0	0	1	0	0	9.0	
i 1	95.25685034013605	1.2625	69	204	4	1	16	0	0	-1	0	0	0	9.0	
i 1	95.25901360544218	0.2525	71	906	4	20	11	2	0	-2	2	0	0	1.0653834244099585	
i 1	95.4859387755102	0.2525	74	204	4	20	14	8	0	-2	8	0	0	1.0653834244099585	
i 1	95.49314965986395	1.7675	77	204	7	5	7	17	0	2	17	0	0	2.0	
i 1	95.49747619047619	0.2525	74	204	5	9	13	16	0	1	16	0	0	2.3790095335108274	
i 1	95.50180272108844	1.01	71	204	4	20	1	2	0	-2	2	0	0	1.0653834244099585	
i 1	95.50829251700681	1.7675	77	906	6	5	9	16	0	2	16	0	0	2.0	
i 1	95.74747619047619	0.7575000000000001	71	204	3	20	9	8	0	-2	8	0	0	1.0653834244099585	
i 1	95.74963945578232	1.01	77	590	4	4	12	16	0	2	16	0	0	3.3790095335108274	
i 1	95.75901360544218	0.2525	72	204	4	24	7	0	0	-1	0	0	0	10.0	
i 1	95.9888231292517	0.7575000000000001	77	204	5	4	3	17	0	2	17	0	0	3.3790095335108274	
i 1	95.99314965986395	1.7675	71	204	1	24	10	2	0	-2	2	0	0	5.0653834244099585	
i 1	95.9945918367347	0.7575000000000001	72	204	7	1	15	0	0	-1	0	0	0	9.0	
i 1	95.99603401360544	0.7575000000000001	72	906	6	1	12	1	0	0	1	0	0	9.0	
i 1	96.0054081632653	0.505	74	204	3	24	2	2	0	1	2	0	0	5.0653834244099585	
i 1	96.25108163265305	5.3025	69	590	4	24	7	1	0	-1	1	0	0	10.0	
i 1	96.25468707482993	0.505	77	590	6	5	15	17	0	1	17	0	0	2.0	
i 1	96.25901360544218	1.01	74	204	5	9	14	16	0	1	16	0	0	2.3790095335108274	
i 1	96.26045578231293	5.3025	72	204	4	24	12	0	0	-1	0	0	0	10.0	
i 1	96.2611768707483	1.01	74	906	6	2	15	17	0	2	17	0	0	3.3790095335108274	
i 1	96.49747619047619	0.2525	71	590	4	24	8	2	0	-2	2	0	0	5.0653834244099585	
i 1	96.50036054421768	0.2525	71	906	4	20	13	2	0	-2	2	0	0	1.0653834244099585	
i 1	96.50829251700681	0.2525	71	590	4	20	15	2	0	1	2	0	0	1.0653834244099585	
i 1	96.51550340136055	0.2525	74	906	4	20	14	2	0	1	2	0	0	1.0653834244099585	
i 1	96.73233333333333	1.01	77	590	5	3	3	16	0	2	16	0	0	3.3790095335108274	
i 1	96.73738095238095	0.2525	71	204	3	24	6	2	0	-2	2	0	0	5.0653834244099585	
i 1	96.7388231292517	1.01	77	204	4	3	14	17	0	2	17	0	0	3.3790095335108274	
i 1	96.74026530612245	0.2525	69	204	4	1	13	0	0	-1	0	0	0	9.0	
i 1	96.75036054421768	2.7775	77	906	6	5	1	17	0	1	17	0	0	2.0	
i 1	96.75180272108844	0.2525	74	204	4	20	8	2	0	-2	2	0	0	1.0653834244099585	
i 1	96.75396598639456	0.2525	71	204	4	20	2	8	0	1	8	0	0	1.0653834244099585	
i 1	96.76189795918367	2.7775	77	204	7	5	3	17	0	2	17	0	0	2.0	
i 1	96.76622448979592	0.2525	74	204	3	20	3	2	0	-2	2	0	0	1.0653834244099585	
i 1	96.98810204081633	0.2525	71	590	4	20	2	2	0	1	2	0	0	1.0653834244099585	
i 1	96.99170748299319	0.2525	71	906	4	20	7	2	0	-2	2	0	0	1.0653834244099585	
i 1	97.0054081632653	0.2525	71	590	4	24	4	8	0	1	8	0	0	5.0653834244099585	
i 1	97.01261904761905	0.2525	69	906	6	1	5	1	0	0	1	0	0	9.0	
i 1	97.25468707482993	0.505	74	906	6	2	7	17	0	2	17	0	0	3.3790095335108274	
i 1	97.25468707482993	0.7575000000000001	74	204	6	5	11	16	0	1	16	0	0	2.0	
i 1	97.25612925170068	1.5150000000000001	77	204	5	9	3	16	0	2	16	0	0	2.3790095335108274	
i 1	97.48449659863945	0.2525	74	590	4	24	11	2	0	1	2	0	0	5.0653834244099585	
i 1	97.49026530612245	0.2525	74	906	4	20	9	2	0	1	2	0	0	1.0653834244099585	
i 1	97.49531292517007	0.2525	71	590	4	20	5	2	0	-2	2	0	0	1.0653834244099585	
i 1	97.49603401360544	0.2525	72	906	6	1	1	1	0	0	1	0	0	9.0	
i 1	97.7388231292517	0.2525	77	204	4	4	8	17	0	2	17	0	0	3.3790095335108274	
i 1	97.74098639455782	1.2625	69	204	7	1	2	1	0	0	1	0	0	9.0	
i 1	97.7445918367347	5.3025	71	204	4	20	15	2	0	1	2	0	0	1.0653834244099585	
i 1	97.74675510204082	1.01	69	906	6	1	6	1	0	0	1	0	0	9.0	
i 1	97.74675510204082	1.7675	71	204	3	20	6	2	0	1	2	0	0	1.0653834244099585	
i 1	97.75252380952381	8.3325	61	590	5	25	16	1	0	2	1	0	0	1.8802217002948172	
i 1	97.75468707482993	1.01	74	906	6	2	9	17	0	2	17	0	0	3.3790095335108274	
i 1	97.75685034013605	6.8175	61	204	4	27	5	1	0	1	1	0	0	2.646775903379499	
i 1	97.76622448979592	8.3325	63	590	6	7	3	16	0	1	16	0	0	1.4105596104834173	
i 1	97.99531292517007	2.7775	77	204	4	3	2	17	0	2	17	0	0	3.3790095335108274	
i 1	98.00612925170068	0.2525	77	906	6	5	8	16	0	2	16	0	0	2.0	
i 1	98.24675510204082	2.525	77	590	5	3	12	16	0	2	16	0	0	3.3790095335108274	
i 1	98.2554081632653	0.505	77	590	6	5	9	17	0	1	17	0	0	2.0	
i 1	98.73377551020408	0.2525	74	906	6	2	1	17	0	2	17	0	0	3.3790095335108274	
i 1	98.75973469387755	0.2525	77	204	7	5	6	17	0	2	17	0	0	2.0	
i 1	98.9888231292517	0.7575000000000001	77	590	6	5	6	17	0	1	17	0	0	2.0	
i 1	99.01334013605442	0.2525	74	906	6	2	11	17	0	2	17	0	0	3.3790095335108274	
i 1	99.01334013605442	1.01	77	204	6	5	16	16	0	2	16	0	0	2.0	
i 1	99.0140612244898	0.2525	69	906	6	1	14	1	0	0	1	0	0	9.0	
i 1	99.24387074829932	0.7575000000000001	77	204	4	4	8	17	0	2	17	0	0	3.3790095335108274	
i 1	99.24675510204082	0.7575000000000001	77	590	4	4	7	16	0	2	16	0	0	3.3790095335108274	
i 1	99.24819727891156	2.02	77	906	6	5	4	16	0	2	16	0	0	2.0	
i 1	99.24891836734695	0.505	69	204	7	1	13	0	0	-1	0	0	0	9.0	
i 1	99.26189795918367	2.02	77	204	7	5	5	17	0	2	17	0	0	2.0	
i 1	99.48233333333333	2.02	71	204	4	24	1	2	0	-2	2	0	0	5.0653834244099585	
i 1	99.49675510204082	2.02	71	204	3	24	8	2	0	-2	2	0	0	5.0653834244099585	
i 1	99.74603401360544	1.01	72	204	7	1	3	0	0	-1	0	0	0	9.0	
i 1	99.74747619047619	2.02	72	906	6	1	2	1	0	0	1	0	0	9.0	
i 1	100.00685034013605	0.2525	74	204	6	5	4	16	0	1	16	0	0	2.0	
i 1	100.00973469387755	0.2525	77	204	5	9	15	16	0	2	16	0	0	2.3790095335108274	
i 1	100.24387074829932	1.01	77	590	4	4	15	16	0	2	16	0	0	3.3790095335108274	
i 1	100.25612925170068	0.2525	77	906	6	5	16	17	0	1	17	0	0	2.0	
i 1	100.25973469387755	1.01	77	204	4	4	10	17	0	2	17	0	0	3.3790095335108274	
i 1	100.50612925170068	0.2525	77	204	6	5	3	16	0	2	16	0	0	2.0	
i 1	100.74819727891156	3.0300000000000002	77	204	7	5	9	17	0	2	17	0	0	2.0	
i 1	100.74963945578232	3.2825	77	906	6	5	14	17	0	1	17	0	0	2.0	
i 1	100.75973469387755	1.5150000000000001	74	204	5	9	8	16	0	1	16	0	0	2.3790095335108274	
i 1	100.76694557823129	1.7675	74	906	6	2	15	17	0	2	17	0	0	3.3790095335108274	
i 1	100.98377551020408	2.02	74	204	4	20	6	2	0	1	2	0	0	1.0653834244099585	
i 1	100.98810204081633	1.01	72	204	7	1	3	0	0	-1	0	0	0	9.0	
i 1	100.99170748299319	2.02	71	204	1	20	9	2	0	-2	2	0	0	1.0653834244099585	
i 1	101.25973469387755	0.505	77	590	6	5	10	17	0	1	17	0	0	2.0	
i 1	101.26478231292516	2.02	72	590	6	1	2	1	0	0	1	0	0	9.0	
i 1	101.26622448979592	2.02	69	204	7	1	16	0	0	-1	0	0	0	9.0	
i 1	101.26766666666667	0.2525	74	906	6	2	16	17	0	2	17	0	0	3.3790095335108274	
i 1	101.5054081632653	0.2525	77	590	4	4	3	16	0	2	16	0	0	3.3790095335108274	
i 1	101.73521768707484	1.7675	77	590	5	3	6	16	0	2	16	0	0	3.3790095335108274	
i 1	101.75180272108844	2.7775	77	204	4	3	8	17	0	2	17	0	0	3.3790095335108274	
i 1	101.75396598639456	0.2525	74	204	6	5	2	16	0	1	16	0	0	2.0	
i 1	102.0054081632653	0.2525	77	590	6	5	16	17	0	1	17	0	0	2.0	
i 1	102.00685034013605	0.2525	72	204	4	24	12	0	0	-1	0	0	0	10.0	
i 1	102.25468707482993	0.2525	69	204	7	1	5	1	0	0	1	0	0	9.0	
i 1	102.26478231292516	0.2525	77	906	6	5	16	16	0	2	16	0	0	2.0	
i 1	102.4859387755102	0.7575000000000001	71	204	3	24	7	2	0	-2	2	0	0	5.0653834244099585	
i 1	102.49387074829932	0.2525	69	906	6	1	4	1	0	0	1	0	0	9.0	
i 1	102.50252380952381	0.7575000000000001	71	204	3	20	1	2	0	1	2	0	0	1.0653834244099585	
i 1	102.50685034013605	1.01	71	204	4	24	14	2	0	-2	2	0	0	5.0653834244099585	
i 1	102.73665986394558	0.7575000000000001	72	204	7	1	15	0	0	-1	0	0	0	9.0	
i 1	102.73738095238095	0.7575000000000001	72	906	6	1	4	1	0	0	1	0	0	9.0	
i 1	102.74387074829932	0.2525	77	590	6	5	10	16	0	2	16	0	0	2.0	
i 1	102.7445918367347	0.7575000000000001	77	204	5	9	14	16	0	2	16	0	0	2.3790095335108274	
i 1	102.75612925170068	0.7575000000000001	74	906	6	2	4	17	0	2	17	0	0	3.3790095335108274	
i 1	102.98449659863945	2.2725	77	590	6	5	15	17	0	1	17	0	0	2.0	
i 1	103.23665986394558	0.2525	71	590	4	24	4	2	0	-2	2	0	0	5.0653834244099585	
i 1	103.23810204081633	2.7775	69	590	4	24	14	1	0	-1	1	0	0	10.0	
i 1	103.25036054421768	0.505	71	590	4	20	14	2	0	1	2	0	0	1.0653834244099585	
i 1	103.25324489795918	0.2525	72	204	4	24	16	0	0	-1	0	0	0	10.0	
i 1	103.25901360544218	1.01	77	590	4	4	13	16	0	2	16	0	0	3.3790095335108274	
i 1	103.26334013605442	1.2625	77	204	4	4	5	17	0	2	17	0	0	3.3790095335108274	
i 1	103.4859387755102	1.01	77	204	6	5	16	16	0	2	16	0	0	2.0	
i 1	103.49819727891156	2.525	61	590	5	25	2	1	0	2	1	0	0	1.8802217002948172	
i 1	103.50757142857142	2.02	77	590	5	3	12	16	0	2	16	0	0	3.3790095335108274	
i 1	103.51261904761905	1.01	72	204	5	24	5	0	0	-1	0	0	0	10.0	
i 1	103.73810204081633	0.2525	71	204	3	20	5	2	0	1	2	0	0	1.0653834244099585	
i 1	103.74675510204082	0.505	71	204	4	20	13	2	0	-2	2	0	0	1.0653834244099585	
i 1	103.76622448979592	0.2525	69	204	7	1	14	0	0	-1	0	0	0	9.0	
i 1	103.9859387755102	0.2525	74	204	6	5	6	16	0	1	16	0	0	2.0	
i 1	103.98810204081633	0.505	71	204	4	24	7	2	0	-2	2	0	0	5.0653834244099585	
i 1	103.99098639455782	0.2525	71	590	4	24	2	2	0	-2	2	0	0	5.0653834244099585	
i 1	104.00324489795918	0.2525	74	590	4	20	10	2	0	1	2	0	0	1.0653834244099585	
i 1	104.00757142857142	0.505	69	906	6	1	12	1	0	0	1	0	0	9.0	
i 1	104.01622448979592	0.2525	74	906	4	20	9	2	0	1	2	0	0	1.0653834244099585	
i 1	104.23665986394558	0.2525	77	204	7	5	2	17	0	2	17	0	0	2.0	
i 1	104.2388231292517	0.2525	74	204	3	24	12	2	0	-2	2	0	0	5.0653834244099585	
i 1	104.26622448979592	0.2525	71	204	4	20	3	2	0	-2	2	0	0	1.0653834244099585	
i 1	104.48305442176871	0.2525	77	1172	5	9	7	16	0	1	16	0	0	2.3790095335108274	
i 1	104.48521768707484	1.5150000000000001	74	1172	4	20	14	2	0	-2	2	0	0	1.0653834244099585	
i 1	104.49098639455782	1.5150000000000001	74	203	3	20	12	2	0	-2	2	0	0	1.0653834244099585	
i 1	104.4945918367347	1.5150000000000001	74	1172	4	20	2	2	0	-2	2	0	0	1.0653834244099585	
i 1	104.50036054421768	1.5150000000000001	61	1172	4	26	10	1	0	1	1	0	0	1.8802217002948172	
i 1	104.50108163265305	1.5150000000000001	63	1172	4	26	3	1	0	2	1	0	0	1.8802217002948172	
i 1	104.50685034013605	1.2625	77	203	4	3	8	16	0	2	16	0	0	3.3790095335108274	
i 1	104.51261904761905	1.5150000000000001	63	203	4	27	15	1	0	1	1	0	0	2.646775903379499	
i 1	104.51622448979592	1.5150000000000001	72	203	5	24	12	0	0	-1	0	0	0	10.0	
i 1	104.51694557823129	1.5150000000000001	61	203	4	27	8	1	0	2	1	0	0	2.646775903379499	
i 1	104.51694557823129	0.7575000000000001	74	203	6	5	5	16	0	1	16	0	0	2.0	
i 1	104.73233333333333	1.2625	74	1172	6	5	15	17	0	2	17	0	0	2.0	
i 1	104.73810204081633	0.2525	77	1172	5	9	16	16	0	2	16	0	0	2.3790095335108274	
i 1	104.7388231292517	1.01	69	906	6	1	8	1	0	0	1	0	0	9.0	
i 1	104.74675510204082	1.2625	77	906	6	5	5	16	0	2	16	0	0	2.0	
i 1	104.74891836734695	1.2625	72	1172	6	1	14	0	0	0	0	0	0	9.0	
i 1	105.23377551020408	0.2525	77	906	6	5	15	17	0	1	17	0	0	2.0	
i 1	105.26189795918367	0.2525	74	906	6	2	3	17	0	2	17	0	0	3.3790095335108274	
i 1	105.48233333333333	0.505	77	590	4	4	4	16	0	2	16	0	0	3.3790095335108274	
i 1	105.49026530612245	0.2525	77	590	6	5	2	16	0	2	16	0	0	2.0	
i 1	105.49098639455782	0.505	74	203	4	4	3	16	0	1	16	0	0	3.3790095335108274	
i 1	105.75396598639456	0.2525	77	590	5	3	8	16	0	2	16	0	0	3.3790095335108274	
i 1	105.75468707482993	0.2525	77	203	6	5	14	16	0	2	16	0	0	2.0	
i 1	105.98233333333333	3.2825	63	1092	4	26	6	16	0	1	16	0	0	1.8802217002948172	
i 1	105.98233333333333	0.505	77	706	5	5	15	17	0	1	17	0	0	2.0	
i 1	105.98377551020408	0.7575000000000001	77	706	6	2	1	16	0	1	16	0	0	3.3790095335108274	
i 1	105.98449659863945	0.2525	77	1092	6	5	11	17	0	1	17	0	0	2.0	
i 1	105.98665986394558	20.705000000000002	61	706	3	27	4	1	0	1	1	0	0	2.646775903379499	
i 1	105.98738095238095	0.2525	74	208	4	20	10	2	0	1	2	0	0	1.0653834244099585	
i 1	105.98810204081633	32.32	63	706	5	25	2	16	0	1	16	0	0	1.8802217002948172	
i 1	105.9888231292517	4.545	77	208	6	3	6	16	0	1	16	0	0	3.3790095335108274	
i 1	105.98954421768707	0.2525	69	1092	6	1	12	0	0	-1	0	0	0	9.0	
i 1	105.98954421768707	0.7575000000000001	77	706	3	3	9	17	0	2	17	0	0	3.3790095335108274	
i 1	105.99242857142858	0.2525	74	208	5	4	4	17	0	1	17	0	0	3.3790095335108274	
i 1	105.99242857142858	14.8975	61	706	3	27	15	1	0	2	1	0	0	2.646775903379499	
i 1	105.99242857142858	0.2525	74	706	4	20	14	2	0	-2	2	0	0	1.0653834244099585	
i 1	105.99531292517007	38.1275	61	706	5	25	1	1	0	1	1	0	0	1.8802217002948172	
i 1	105.99891836734695	4.545	74	706	3	4	15	17	0	2	17	0	0	3.3790095335108274	
i 1	106.00396598639456	9.09	63	1092	4	26	2	1	0	2	1	0	0	1.8802217002948172	
i 1	106.0054081632653	43.935	63	208	6	25	1	1	0	2	1	0	0	1.8802217002948172	
i 1	106.00685034013605	4.04	74	706	1	24	10	2	0	252	2	307	0	5.0653834244099585	
i 1	106.00829251700681	9.09	61	706	5	14	15	16	0	2	16	0	0	2.8211192209668345	
i 1	106.0111768707483	3.2825	61	706	5	14	13	1	0	1	1	0	0	2.8211192209668345	
i 1	106.01261904761905	0.2525	69	706	6	1	6	0	0	0	0	0	0	9.0	
i 1	106.01261904761905	0.505	74	706	6	5	4	16	0	1	16	0	0	2.0	
i 1	106.01478231292516	0.2525	72	208	5	24	8	0	0	0	0	0	0	10.0	
i 1	106.01550340136055	46.2075	61	208	6	25	3	16	0	1	16	0	0	1.8802217002948172	
i 1	106.01694557823129	20.705000000000002	61	208	6	7	13	16	0	1	16	0	0	1.4105596104834173	
i 1	106.23233333333333	1.7675	72	706	6	1	3	0	0	-1	0	0	0	9.0	
i 1	106.23233333333333	2.525	74	1092	3	20	13	2	0	1	2	0	0	1.0653834244099585	
i 1	106.23377551020408	1.2625	71	1092	3	20	1	2	0	-2	2	0	0	1.0653834244099585	
i 1	106.23449659863945	0.2525	69	1092	6	1	2	1	0	0	1	0	0	9.0	
i 1	106.24819727891156	3.2825	74	1092	6	5	7	17	0	1	17	0	0	2.0	
i 1	106.25180272108844	1.01	74	706	2	24	9	2	0	1	2	0	0	5.0653834244099585	
i 1	106.25685034013605	1.7675	72	706	6	1	5	1	0	-1	1	0	0	9.0	
i 1	106.25901360544218	0.2525	74	706	2	20	9	2	0	-2	2	0	0	1.0653834244099585	
i 1	106.26550340136055	3.2825	77	208	7	5	5	16	0	1	16	0	0	2.0	
i 1	106.50180272108844	0.2525	77	1092	6	5	5	17	0	1	17	0	0	2.0	
i 1	106.73521768707484	1.01	74	1092	3	24	9	8	0	1	8	0	0	5.0653834244099585	
i 1	106.74098639455782	0.7575000000000001	74	1092	3	20	5	2	0	1	2	0	0	1.0653834244099585	
i 1	106.74531292517007	0.2525	69	1092	6	1	6	1	0	0	1	0	0	9.0	
i 1	106.74675510204082	0.2525	74	706	5	5	3	17	0	1	17	0	0	2.0	
i 1	106.75829251700681	1.01	74	208	5	4	16	17	0	1	17	0	0	3.3790095335108274	
i 1	106.76622448979592	1.01	74	1092	5	9	15	17	0	2	17	0	0	2.3790095335108274	
i 1	107.01189795918367	0.2525	69	706	6	1	1	0	0	0	0	0	0	9.0	
i 1	107.23810204081633	2.7775	69	208	7	1	1	1	0	0	1	0	0	9.0	
i 1	107.26766666666667	0.2525	74	706	2	20	9	2	0	-2	2	0	0	1.0653834244099585	
i 1	107.48233333333333	0.2525	74	706	4	20	6	2	0	1	2	0	0	1.0653834244099585	
i 1	107.49242857142858	0.2525	77	706	5	5	6	17	0	1	17	0	0	2.0	
i 1	107.49603401360544	2.525	72	706	4	24	15	1	0	-1	1	0	0	10.0	
i 1	107.50829251700681	0.2525	71	208	4	20	10	8	0	-2	8	0	0	1.0653834244099585	
i 1	107.5111768707483	0.2525	71	706	4	20	9	2	0	-2	2	0	0	1.0653834244099585	
i 1	107.7388231292517	0.7575000000000001	71	1092	3	20	11	2	0	-2	2	0	0	1.0653834244099585	
i 1	107.74242857142858	0.2525	77	706	3	3	12	17	0	2	17	0	0	3.3790095335108274	
i 1	107.7445918367347	0.7575000000000001	71	706	2	20	12	8	0	1	8	0	0	1.0653834244099585	
i 1	107.75396598639456	0.505	77	1092	6	5	7	17	0	1	17	0	0	2.0	
i 1	107.99026530612245	0.2525	74	706	6	2	7	16	0	2	16	0	0	3.3790095335108274	
i 1	108.26334013605442	0.2525	77	706	6	2	7	16	0	1	16	0	0	3.3790095335108274	
i 1	108.48233333333333	0.2525	71	706	4	20	13	2	0	1	2	0	0	1.0653834244099585	
i 1	108.4859387755102	0.2525	77	208	7	5	6	16	0	1	16	0	0	2.0	
i 1	108.49963945578232	0.2525	71	706	4	20	6	2	0	-2	2	0	0	1.0653834244099585	
i 1	108.74387074829932	0.2525	74	706	5	5	14	17	0	1	17	0	0	2.0	
i 1	108.7554081632653	1.01	74	1092	3	24	15	8	0	1	8	0	0	5.0653834244099585	
i 1	108.75612925170068	0.2525	74	706	6	2	11	16	0	2	16	0	0	3.3790095335108274	
i 1	108.76622448979592	1.01	71	1092	3	20	2	2	0	1	2	0	0	1.0653834244099585	
i 1	108.9859387755102	3.0300000000000002	77	706	5	5	14	17	0	1	17	0	0	2.0	
i 1	108.98665986394558	0.2525	72	706	6	1	7	0	0	-1	0	0	0	9.0	
i 1	108.99747619047619	3.0300000000000002	74	706	6	5	1	16	0	1	16	0	0	2.0	
i 1	109.01045578231293	0.2525	74	706	2	24	4	2	0	-2	2	0	0	5.0653834244099585	
i 1	109.2359387755102	1.2625	74	706	6	2	5	16	0	2	16	0	0	3.3790095335108274	
i 1	109.24963945578232	11.615	61	706	5	14	15	1	0	1	1	0	0	2.8211192209668345	
i 1	109.25757142857142	42.925	63	1092	4	26	12	16	0	1	16	0	0	1.8802217002948172	
i 1	109.48738095238095	0.505	74	1092	5	9	13	17	0	2	17	0	0	2.3790095335108274	
i 1	109.49026530612245	0.2525	77	706	6	5	7	17	0	2	17	0	0	2.0	
i 1	109.49098639455782	0.7575000000000001	72	208	5	24	11	0	0	0	0	0	0	10.0	
i 1	109.49242857142858	0.505	74	208	5	4	2	17	0	1	17	0	0	3.3790095335108274	
i 1	109.49603401360544	0.7575000000000001	69	1092	6	1	12	0	0	-1	0	0	0	9.0	
i 1	109.49603401360544	0.7575000000000001	77	1092	5	9	8	17	0	2	17	0	0	2.3790095335108274	
i 1	109.50036054421768	0.2525	71	706	2	20	9	2	0	1	2	0	0	1.0653834244099585	
i 1	109.50252380952381	2.525	74	1092	3	20	9	2	0	1	2	0	0	1.0653834244099585	
i 1	109.7388231292517	0.2525	77	208	7	5	1	16	0	1	16	0	0	2.0	
i 1	109.74675510204082	0.2525	74	706	4	20	4	2	0	1	2	0	0	1.0653834244099585	
i 1	109.7640612244898	0.2525	74	208	4	20	10	8	0	-2	8	0	0	1.0653834244099585	
i 1	109.9888231292517	1.5150000000000001	74	1092	3	20	8	2	0	1	2	0	0	1.0653834244099585	
i 1	109.99675510204082	0.505	71	706	2	20	7	8	0	1	8	0	0	1.0653834244099585	
i 1	110.00108163265305	1.5150000000000001	71	1092	3	20	11	8	0	1	8	0	0	1.0653834244099585	
i 1	110.00973469387755	1.2625	69	706	5	1	14	0	0	0	0	0	0	9.0	
i 1	110.01189795918367	0.505	74	706	2	24	6	2	0	1	2	0	0	5.0653834244099585	
i 1	110.01550340136055	1.5150000000000001	69	1092	6	1	3	1	0	0	1	0	0	9.0	
i 1	110.25036054421768	0.505	72	706	6	1	5	0	0	-1	0	0	0	9.0	
i 1	110.26261904761905	3.0300000000000002	74	1092	3	24	10	8	0	1	8	0	0	5.0653834244099585	
i 1	110.48665986394558	0.505	77	706	6	2	8	16	0	1	16	0	0	3.3790095335108274	
i 1	110.49531292517007	0.505	77	706	3	3	7	17	0	2	17	0	0	3.3790095335108274	
i 1	110.74675510204082	0.2525	74	1092	6	5	4	17	0	1	17	0	0	2.0	
i 1	110.75757142857142	0.2525	74	1092	5	9	16	17	0	2	17	0	0	2.3790095335108274	
i 1	110.99531292517007	4.04	72	706	6	1	6	0	0	-1	0	0	0	9.0	
i 1	110.99603401360544	4.04	72	706	6	1	3	1	0	-1	1	0	0	9.0	
i 1	111.00180272108844	1.01	74	706	3	4	1	17	0	2	17	0	0	3.3790095335108274	
i 1	111.00324489795918	0.2525	74	208	5	4	15	17	0	1	17	0	0	3.3790095335108274	
i 1	111.01189795918367	0.2525	72	208	5	24	4	0	0	0	0	0	0	10.0	
i 1	111.01261904761905	0.2525	69	1092	6	1	4	0	0	-1	0	0	0	9.0	
i 1	111.01550340136055	0.2525	74	706	5	5	4	17	0	1	17	0	0	2.0	
i 1	111.01694557823129	1.01	77	208	6	3	14	16	0	1	16	0	0	3.3790095335108274	
i 1	111.49891836734695	0.2525	71	706	4	20	10	8	0	1	8	0	0	1.0653834244099585	
i 1	111.49963945578232	1.5150000000000001	74	1092	6	5	14	17	0	1	17	0	0	2.0	
i 1	111.50757142857142	0.2525	69	208	7	1	14	1	0	0	1	0	0	9.0	
i 1	111.5140612244898	0.2525	74	706	4	20	10	8	0	1	8	0	0	1.0653834244099585	
i 1	111.51478231292516	0.2525	74	208	4	24	2	2	0	1	2	0	0	5.0653834244099585	
i 1	111.51550340136055	1.2625	77	208	7	5	7	16	0	1	16	0	0	2.0	
i 1	111.51694557823129	0.2525	77	706	6	2	16	16	0	1	16	0	0	3.3790095335108274	
i 1	111.73810204081633	1.5150000000000001	71	1092	3	20	7	2	0	1	2	0	0	1.0653834244099585	
i 1	111.7388231292517	1.2625	74	208	5	4	1	17	0	1	17	0	0	3.3790095335108274	
i 1	111.7445918367347	1.2625	74	1092	5	9	4	17	0	2	17	0	0	2.3790095335108274	
i 1	111.75108163265305	0.2525	69	706	5	1	2	0	0	0	0	0	0	9.0	
i 1	111.76189795918367	1.01	74	706	2	24	12	2	0	-2	2	0	0	5.0653834244099585	
i 1	112.00180272108844	0.2525	74	706	6	2	10	16	0	2	16	0	0	3.3790095335108274	
i 1	112.24819727891156	1.01	74	706	2	24	1	2	0	1	2	0	0	5.0653834244099585	
i 1	112.24963945578232	0.2525	77	706	5	5	9	17	0	1	17	0	0	2.0	
i 1	112.2611768707483	0.2525	69	208	7	1	5	1	0	0	1	0	0	9.0	
i 1	112.26189795918367	1.01	74	706	2	20	15	2	0	1	2	0	0	1.0653834244099585	
i 1	112.26478231292516	0.2525	77	706	6	2	12	16	0	1	16	0	0	3.3790095335108274	
i 1	112.49026530612245	0.7575000000000001	69	1092	6	1	4	0	0	-1	0	0	0	9.0	
i 1	112.49603401360544	0.7575000000000001	72	208	5	24	4	0	0	0	0	0	0	10.0	
i 1	112.50829251700681	0.7575000000000001	77	706	6	5	3	17	0	2	17	0	0	2.0	
i 1	112.51550340136055	1.01	77	208	6	3	13	16	0	1	16	0	0	3.3790095335108274	
i 1	112.75036054421768	0.7575000000000001	74	706	3	4	7	17	0	2	17	0	0	3.3790095335108274	
i 1	112.75973469387755	0.7575000000000001	77	1092	6	5	3	17	0	1	17	0	0	2.0	
i 1	112.99314965986395	3.2825	74	706	6	5	1	16	0	1	16	0	0	2.0	
i 1	112.99819727891156	3.2825	77	706	5	5	12	17	0	1	17	0	0	2.0	
i 1	113.00757142857142	0.505	74	706	2	24	7	2	0	-2	2	0	0	5.0653834244099585	
i 1	113.01045578231293	1.01	74	1092	3	20	14	2	0	1	2	0	0	1.0653834244099585	
i 1	113.01550340136055	0.505	74	1092	3	20	7	2	0	1	2	0	0	1.0653834244099585	
i 1	113.23738095238095	0.2525	69	208	7	1	14	1	0	0	1	0	0	9.0	
i 1	113.48233333333333	0.2525	69	1092	6	1	16	0	0	-1	0	0	0	9.0	
i 1	113.48521768707484	0.2525	71	706	4	20	6	2	0	1	2	0	0	1.0653834244099585	
i 1	113.48665986394558	0.2525	74	706	4	20	16	2	0	-2	2	0	0	1.0653834244099585	
i 1	113.50252380952381	1.2625	77	1092	5	9	4	17	0	2	17	0	0	2.3790095335108274	
i 1	113.50396598639456	0.505	74	1092	5	9	7	17	0	2	17	0	0	2.3790095335108274	
i 1	113.51045578231293	0.505	74	208	5	4	7	17	0	1	17	0	0	3.3790095335108274	
i 1	113.51334013605442	0.505	74	706	2	24	13	2	0	1	2	0	0	5.0653834244099585	
i 1	113.73233333333333	1.01	74	1092	3	20	14	2	0	1	2	0	0	1.0653834244099585	
i 1	113.73449659863945	0.7575000000000001	74	706	6	2	15	16	0	2	16	0	0	3.3790095335108274	
i 1	113.73810204081633	1.2625	74	1092	3	24	7	8	0	1	8	0	0	5.0653834244099585	
i 1	113.74098639455782	0.2525	74	1092	3	20	15	2	0	-2	2	0	0	1.0653834244099585	
i 1	113.74819727891156	1.01	71	706	2	24	11	2	0	-2	2	0	0	5.0653834244099585	
i 1	113.76334013605442	0.2525	69	208	7	1	3	1	0	0	1	0	0	9.0	
i 1	113.76622448979592	0.2525	74	1092	6	5	8	17	0	1	17	0	0	2.0	
i 1	113.9859387755102	1.01	74	706	1	24	10	2	0	252	2	307	0	5.0653834244099585	
i 1	114.00468707482993	0.2525	77	706	6	2	9	16	0	1	16	0	0	3.3790095335108274	
i 1	114.49242857142858	0.2525	74	706	5	5	8	17	0	1	17	0	0	2.0	
i 1	114.49747619047619	1.5150000000000001	72	706	4	24	13	1	0	-1	1	0	0	10.0	
i 1	114.5054081632653	1.2625	74	706	3	4	8	17	0	2	17	0	0	3.3790095335108274	
i 1	114.50829251700681	1.5150000000000001	69	208	7	1	2	1	0	0	1	0	0	9.0	
i 1	114.51622448979592	1.2625	77	208	6	3	6	16	0	1	16	0	0	3.3790095335108274	
i 1	114.73521768707484	0.2525	71	208	4	24	3	2	0	-2	2	0	0	5.0653834244099585	
i 1	114.75396598639456	0.2525	71	706	4	20	6	2	0	1	2	0	0	1.0653834244099585	
i 1	114.75685034013605	0.2525	74	1092	3	20	1	2	0	1	2	0	0	1.0653834244099585	
i 1	114.76045578231293	0.2525	74	1092	6	5	9	17	0	1	17	0	0	2.0	
i 1	114.7611768707483	0.2525	71	706	4	20	10	8	0	1	8	0	0	1.0653834244099585	
i 1	114.9859387755102	1.5150000000000001	77	706	6	2	13	16	0	1	16	0	0	3.3790095335108274	
i 1	114.99170748299319	1.01	74	1092	3	20	1	2	0	-2	2	0	0	0.08213717458221925	
i 1	114.99747619047619	0.2525	69	1092	6	1	2	0	0	-1	0	0	0	9.0	
i 1	115.00036054421768	37.1175	63	1092	4	26	1	1	0	2	1	0	0	1.8802217002948172	
i 1	115.00180272108844	0.2525	77	208	7	5	9	16	0	1	16	0	0	2.0	
i 1	115.0140612244898	11.615	61	706	5	14	5	16	0	2	16	0	0	2.8211192209668345	
i 1	115.01478231292516	1.2625	74	1092	3	20	6	2	0	1	2	0	0	0.08213717458221925	
i 1	115.01622448979592	1.01	74	706	2	20	15	2	0	1	2	0	0	0.08213717458221925	
i 1	115.01766666666667	1.01	74	706	2	24	14	8	0	-2	8	0	0	4.082137174582219	
i 1	115.23305442176871	1.2625	77	706	4	3	9	17	0	2	17	0	0	3.3790095335108274	
i 1	115.24675510204082	0.2525	72	706	6	1	10	1	0	-1	1	0	0	9.0	
i 1	115.4859387755102	0.2525	77	208	7	5	15	16	0	1	16	0	0	2.0	
i 1	115.50036054421768	0.505	69	706	5	1	9	0	0	0	0	0	0	9.0	
i 1	115.73738095238095	0.2525	74	706	2	24	2	2	0	1	2	0	0	4.082137174582219	
i 1	115.75108163265305	0.2525	74	1092	3	20	14	8	0	1	8	0	0	0.08213717458221925	
i 1	115.75612925170068	2.7775	77	208	7	5	13	16	0	1	16	0	0	2.0	
i 1	115.75685034013605	0.2525	74	706	2	20	7	2	0	-2	2	0	0	0.08213717458221925	
i 1	115.76334013605442	2.7775	74	1092	6	5	2	17	0	1	17	0	0	2.0	
i 1	115.76622448979592	2.525	74	1092	3	24	14	8	0	1	8	0	0	4.082137174582219	
i 1	115.99170748299319	0.2525	71	706	4	20	2	2	0	1	2	0	0	0.08213717458221925	
i 1	116.00108163265305	0.2525	72	208	5	24	7	0	0	0	0	0	0	10.0	
i 1	116.01478231292516	0.2525	69	1092	6	1	16	0	0	-1	0	0	0	9.0	
i 1	116.01622448979592	0.2525	74	208	4	24	4	8	0	-2	8	0	0	4.082137174582219	
i 1	116.23233333333333	1.5150000000000001	69	706	5	1	9	0	0	0	0	0	0	9.0	
i 1	116.24026530612245	1.01	74	1092	3	20	8	2	0	1	2	0	0	0.08213717458221925	
i 1	116.24170748299319	1.2625	71	706	2	24	10	2	0	-2	2	0	0	4.082137174582219	
i 1	116.2554081632653	1.5150000000000001	69	1092	6	1	15	1	0	0	1	0	0	9.0	
i 1	116.26766666666667	1.5150000000000001	74	706	2	20	5	2	0	1	2	0	0	0.08213717458221925	
i 1	116.4859387755102	1.5150000000000001	74	706	3	4	10	17	0	2	17	0	0	3.3790095335108274	
i 1	116.50036054421768	1.5150000000000001	77	208	6	3	2	16	0	1	16	0	0	3.3790095335108274	
i 1	116.51550340136055	0.505	72	208	5	24	14	0	0	0	0	0	0	10.0	
i 1	116.7359387755102	0.505	74	208	5	4	14	17	0	1	17	0	0	3.3790095335108274	
i 1	116.75036054421768	0.2525	74	1092	5	9	14	17	0	2	17	0	0	2.3790095335108274	
i 1	116.98449659863945	0.505	71	706	2	20	1	8	0	1	8	0	0	0.08213717458221925	
i 1	116.99675510204082	0.505	74	706	2	24	2	2	0	1	2	0	0	4.082137174582219	
i 1	117.2359387755102	0.2525	77	1092	6	5	13	17	0	1	17	0	0	2.0	
i 1	117.48449659863945	0.2525	74	208	4	20	2	2	0	1	2	0	0	0.08213717458221925	
i 1	117.50901360544218	0.2525	71	208	4	24	10	2	0	1	2	0	0	4.082137174582219	
i 1	117.74098639455782	0.505	69	1092	6	1	14	0	0	-1	0	0	0	9.0	
i 1	117.74531292517007	0.2525	74	706	2	20	8	8	0	1	8	0	0	0.08213717458221925	
i 1	117.75324489795918	0.2525	77	706	6	2	8	16	0	1	16	0	0	3.3790095335108274	
i 1	117.75324489795918	2.525	74	706	2	24	15	2	0	1	2	0	0	4.082137174582219	
i 1	117.76622448979592	0.505	72	208	5	24	11	0	0	0	0	0	0	10.0	
i 1	117.98521768707484	0.2525	71	208	4	20	15	2	0	1	2	0	0	0.08213717458221925	
i 1	117.9859387755102	0.2525	71	208	4	24	13	2	0	-2	2	0	0	4.082137174582219	
i 1	117.9888231292517	1.7675	74	706	2	20	3	2	0	1	2	0	0	0.08213717458221925	
i 1	118.00901360544218	0.2525	74	706	4	20	6	2	0	1	2	0	0	0.08213717458221925	
i 1	118.01261904761905	1.2625	74	208	5	4	11	17	0	1	17	0	0	3.3790095335108274	
i 1	118.0140612244898	0.2525	77	208	7	5	2	16	0	1	16	0	0	2.0	
i 1	118.01478231292516	1.2625	74	1092	5	9	7	17	0	2	17	0	0	2.3790095335108274	
i 1	118.01550340136055	0.2525	74	1092	3	20	14	2	0	1	2	0	0	0.08213717458221925	
i 1	118.23738095238095	1.5150000000000001	72	706	5	1	13	0	0	-1	0	0	0	9.0	
i 1	118.24242857142858	1.5150000000000001	74	706	2	20	4	2	0	1	2	0	0	0.08213717458221925	
i 1	118.24603401360544	1.5150000000000001	74	1092	1	24	11	8	0	252	8	307	0	4.082137174582219	
i 1	118.2611768707483	0.2525	77	1092	6	5	9	17	0	1	17	0	0	2.0	
i 1	118.26189795918367	1.5150000000000001	72	706	6	1	10	1	0	-1	1	0	0	9.0	
i 1	118.2640612244898	1.5150000000000001	74	706	2	24	5	2	0	-2	2	0	0	4.082137174582219	
i 1	118.50829251700681	1.5150000000000001	74	706	6	5	11	16	0	1	16	0	0	2.0	
i 1	118.51550340136055	1.2625	77	706	5	5	13	17	0	1	17	0	0	2.0	
i 1	118.73305442176871	1.2625	77	1092	5	9	8	17	0	2	17	0	0	2.3790095335108274	
i 1	118.75036054421768	0.2525	69	1092	6	1	14	0	0	-1	0	0	0	9.0	
i 1	118.75036054421768	1.2625	74	706	6	2	12	16	0	2	16	0	0	3.3790095335108274	
i 1	118.99675510204082	0.2525	74	1092	6	5	1	17	0	1	17	0	0	2.0	
i 1	119.49531292517007	0.7575000000000001	69	1092	6	1	8	0	0	-1	0	0	0	9.0	
i 1	119.50901360544218	0.7575000000000001	72	208	5	24	6	0	0	0	0	0	0	10.0	
i 1	119.73305442176871	1.5150000000000001	74	1092	6	5	15	17	0	1	17	0	0	2.0	
i 1	119.74387074829932	0.2525	74	706	4	20	2	2	0	1	2	0	0	0.08213717458221925	
i 1	119.74531292517007	0.505	74	1092	3	24	12	8	0	1	8	0	0	4.082137174582219	
i 1	119.75612925170068	1.5150000000000001	77	208	7	5	16	16	0	1	16	0	0	2.0	
i 1	119.76261904761905	0.2525	71	208	4	24	16	2	0	-2	2	0	0	4.082137174582219	
i 1	119.98738095238095	0.2525	77	706	6	5	12	17	0	2	17	0	0	2.0	
i 1	119.99387074829932	0.2525	71	706	2	20	2	2	0	-2	2	0	0	0.08213717458221925	
i 1	120.00180272108844	0.2525	71	1092	3	20	9	2	0	-2	2	0	0	0.08213717458221925	
i 1	120.01045578231293	0.2525	77	208	6	3	11	16	0	1	16	0	0	3.3790095335108274	
i 1	120.01261904761905	0.2525	74	706	3	4	3	17	0	2	17	0	0	3.3790095335108274	
i 1	120.23305442176871	0.505	74	1092	3	20	3	2	0	1	2	0	0	0.08213717458221925	
i 1	120.23377551020408	0.7575000000000001	72	706	6	1	5	1	0	-1	1	0	0	9.0	
i 1	120.24387074829932	1.2625	74	1092	1	24	11	8	0	252	8	307	0	4.082137174582219	
i 1	120.24531292517007	1.7675	74	706	2	20	1	2	0	1	2	0	0	0.08213717458221925	
i 1	120.24603401360544	0.2525	77	706	4	3	11	17	0	2	17	0	0	3.3790095335108274	
i 1	120.25036054421768	0.7575000000000001	72	706	5	1	16	0	0	-1	0	0	0	9.0	
i 1	120.2554081632653	0.2525	77	706	6	2	13	16	0	1	16	0	0	3.3790095335108274	
i 1	120.49098639455782	0.2525	74	1092	3	20	16	2	0	1	2	0	0	0.08213717458221925	
i 1	120.49314965986395	1.01	74	706	2	20	11	2	0	1	2	0	0	0.08213717458221925	
i 1	120.50468707482993	0.7575000000000001	77	208	6	3	16	16	0	1	16	0	0	3.3790095335108274	
i 1	120.50757142857142	1.01	71	706	2	24	7	2	0	1	2	0	0	4.082137174582219	
i 1	120.5111768707483	1.01	74	706	2	24	3	2	0	1	2	0	0	4.082137174582219	
i 1	120.51766666666667	0.2525	74	706	3	4	14	17	0	2	17	0	0	3.3790095335108274	
i 1	120.75468707482993	11.615	61	706	3	14	13	1	0	1	1	0	0	2.8211192209668345	
i 1	120.75685034013605	0.505	74	706	4	4	2	17	0	2	17	0	0	3.3790095335108274	
i 1	120.75901360544218	31.31	61	706	3	27	8	1	0	2	1	0	0	2.646775903379499	
i 1	120.98305442176871	1.7675	69	208	5	1	1	1	0	0	1	0	0	9.0	
i 1	120.99026530612245	1.7675	72	706	4	24	4	1	0	-1	1	0	0	10.0	
i 1	121.00396598639456	0.2525	69	706	5	1	16	0	0	0	0	0	0	9.0	
i 1	121.00396598639456	0.7575000000000001	74	1092	5	9	10	17	0	2	17	0	0	2.3790095335108274	
i 1	121.01261904761905	0.7575000000000001	74	208	5	4	11	17	0	1	17	0	0	3.3790095335108274	
i 1	121.24819727891156	1.5150000000000001	77	706	6	5	10	17	0	2	17	0	0	2.0	
i 1	121.2554081632653	0.2525	72	706	6	1	16	1	0	-1	1	0	0	9.0	
i 1	121.25901360544218	1.5150000000000001	77	1092	6	5	5	17	0	1	17	0	0	2.0	
i 1	121.49026530612245	2.02	77	208	6	3	14	16	0	1	16	0	0	3.3790095335108274	
i 1	121.49314965986395	0.505	74	208	4	20	10	2	0	-2	2	0	0	0.08213717458221925	
i 1	121.4945918367347	2.02	74	706	4	4	1	17	0	2	17	0	0	3.3790095335108274	
i 1	121.49531292517007	2.02	74	1092	3	24	4	8	0	1	8	0	0	4.082137174582219	
i 1	121.50757142857142	0.2525	74	706	5	5	1	17	0	1	17	0	0	2.0	
i 1	121.51694557823129	0.505	71	208	4	24	1	8	0	-2	8	0	0	4.082137174582219	
i 1	121.73449659863945	0.2525	77	208	7	5	13	16	0	1	16	0	0	2.0	
i 1	121.76334013605442	0.2525	69	1092	6	1	1	1	0	0	1	0	0	9.0	
i 1	121.99963945578232	1.5150000000000001	74	706	2	24	1	2	0	1	2	0	0	4.082137174582219	
i 1	122.00901360544218	1.5150000000000001	71	1092	3	20	1	8	0	1	8	0	0	0.08213717458221925	
i 1	122.00901360544218	1.5150000000000001	71	706	2	20	14	2	0	-2	2	0	0	0.08213717458221925	
i 1	122.25685034013605	1.01	69	1092	6	1	5	0	0	-1	0	0	0	9.0	
i 1	122.49747619047619	0.7575000000000001	72	208	5	24	12	0	0	0	0	0	0	10.0	
i 1	122.51478231292516	0.2525	77	706	4	3	9	17	0	2	17	0	0	3.3790095335108274	
i 1	122.73810204081633	2.7775	77	706	5	5	4	17	0	1	17	0	0	2.0	
i 1	122.75396598639456	2.7775	74	706	6	5	4	16	0	1	16	0	0	2.0	
i 1	122.7554081632653	0.2525	77	208	7	5	15	16	0	1	16	0	0	2.0	
i 1	122.99170748299319	0.2525	77	208	7	5	8	16	0	1	16	0	0	2.0	
i 1	123.25036054421768	1.5150000000000001	69	1092	6	1	11	1	0	0	1	0	0	9.0	
i 1	123.26045578231293	1.5150000000000001	69	706	5	1	3	0	0	0	0	0	0	9.0	
i 1	123.4945918367347	0.2525	74	706	4	20	16	8	0	-2	8	0	0	0.08213717458221925	
i 1	123.4945918367347	1.2625	74	706	2	20	15	2	0	1	2	0	0	0.08213717458221925	
i 1	123.50108163265305	0.2525	74	1092	3	20	1	2	0	1	2	0	0	0.08213717458221925	
i 1	123.50252380952381	0.2525	71	208	4	20	6	2	0	-2	2	0	0	0.08213717458221925	
i 1	123.50396598639456	0.7575000000000001	74	1092	1	24	5	8	0	248	8	308	0	4.082137174582219	
i 1	123.50468707482993	0.2525	74	208	5	4	10	17	0	1	17	0	0	3.3790095335108274	
i 1	123.50901360544218	0.2525	74	1092	5	9	3	17	0	2	17	0	0	2.3790095335108274	
i 1	123.73233333333333	0.505	71	706	2	24	6	2	0	1	2	0	0	4.082137174582219	
i 1	123.73449659863945	0.505	71	706	2	20	14	2	0	1	2	0	0	0.08213717458221925	
i 1	123.73521768707484	0.2525	74	706	4	2	1	16	0	2	16	0	0	3.3790095335108274	
i 1	123.73521768707484	0.505	74	706	2	24	15	2	0	1	2	0	0	4.082137174582219	
i 1	123.75757142857142	0.2525	77	1092	5	9	2	17	0	2	17	0	0	2.3790095335108274	
i 1	123.99170748299319	0.2525	77	706	6	2	14	16	0	1	16	0	0	3.3790095335108274	
i 1	123.99675510204082	0.505	77	208	6	3	3	16	0	1	16	0	0	3.3790095335108274	
i 1	124.01045578231293	0.505	74	706	4	4	4	17	0	2	17	0	0	3.3790095335108274	
i 1	124.2359387755102	0.505	74	1092	3	24	8	8	0	1	8	0	0	4.082137174582219	
i 1	124.25252380952381	0.505	71	208	4	20	16	2	0	1	2	0	0	0.08213717458221925	
i 1	124.25685034013605	0.505	74	208	4	24	11	8	0	-2	8	0	0	4.082137174582219	
i 1	124.48305442176871	0.7575000000000001	69	1092	6	1	13	0	0	-1	0	0	0	9.0	
i 1	124.48521768707484	0.7575000000000001	72	208	5	24	7	0	0	0	0	0	0	10.0	
i 1	124.49026530612245	0.505	77	706	4	3	8	17	0	2	17	0	0	3.3790095335108274	
i 1	124.49747619047619	3.2825	74	1092	3	20	7	2	0	1	2	0	0	0.08213717458221925	
i 1	124.49819727891156	1.2625	74	706	2	24	10	2	0	1	2	0	0	4.082137174582219	
i 1	124.49891836734695	0.2525	74	706	4	20	6	8	0	-2	8	0	0	0.08213717458221925	
i 1	124.50901360544218	0.505	77	706	6	2	4	16	0	1	16	0	0	3.3790095335108274	
i 1	124.73233333333333	3.0300000000000002	71	1092	3	20	9	2	0	-2	2	0	0	0.08213717458221925	
i 1	124.75396598639456	1.01	74	706	2	20	14	2	0	1	2	0	0	0.08213717458221925	
i 1	124.98810204081633	1.01	72	706	5	1	13	0	0	-1	0	0	0	9.0	
i 1	124.9945918367347	0.2525	74	208	5	4	8	17	0	1	17	0	0	3.3790095335108274	
i 1	125.00036054421768	1.01	72	706	6	1	14	1	0	-1	1	0	0	9.0	
i 1	125.00324489795918	1.01	74	706	4	4	1	17	0	2	17	0	0	3.3790095335108274	
i 1	125.00973469387755	1.01	77	208	6	3	11	16	0	1	16	0	0	3.3790095335108274	
i 1	125.24026530612245	1.2625	74	1092	6	5	1	17	0	1	17	0	0	2.0	
i 1	125.24747619047619	1.2625	77	208	7	5	2	16	0	1	16	0	0	2.0	
i 1	125.74387074829932	1.01	74	706	2	20	2	2	0	1	2	0	0	0.08213717458221925	
i 1	125.75757142857142	1.01	74	706	2	24	7	2	0	-2	2	0	0	4.082137174582219	
i 1	125.98305442176871	0.2525	69	1092	6	1	15	0	0	-1	0	0	0	9.0	
i 1	125.99675510204082	1.01	74	1092	5	9	4	17	0	2	17	0	0	2.3790095335108274	
i 1	126.00180272108844	0.2525	72	208	5	24	16	0	0	0	0	0	0	10.0	
i 1	126.01766666666667	1.01	74	208	5	4	8	17	0	1	17	0	0	3.3790095335108274	
i 1	126.24675510204082	1.5150000000000001	72	706	6	1	4	1	0	-1	1	0	0	9.0	
i 1	126.25180272108844	1.5150000000000001	72	706	5	1	1	0	0	-1	0	0	0	9.0	
i 1	126.49387074829932	25.5025	61	706	3	27	16	1	0	1	1	0	0	2.646775903379499	
i 1	126.50757142857142	3.0300000000000002	77	706	5	5	11	17	0	1	17	0	0	2.0	
i 1	126.50973469387755	11.615	61	706	3	14	15	16	0	2	16	0	0	2.8211192209668345	
i 1	126.51334013605442	11.615	61	208	5	7	1	16	0	1	16	0	0	1.4105596104834173	
i 1	126.51766666666667	3.0300000000000002	74	706	6	5	4	16	0	1	16	0	0	2.0	
i 1	126.73305442176871	1.01	74	706	2	20	7	2	0	1	2	0	0	0.08213717458221925	
i 1	126.73738095238095	1.01	74	706	2	24	9	2	0	1	2	0	0	4.082137174582219	
i 1	126.75757142857142	1.01	74	706	1	24	1	2	0	252	2	307	0	4.082137174582219	
i 1	126.99098639455782	0.505	77	208	6	3	2	16	0	1	16	0	0	3.3790095335108274	
i 1	127.01045578231293	0.505	74	706	4	4	11	17	0	2	17	0	0	3.3790095335108274	
i 1	127.5054081632653	0.505	74	208	5	4	11	17	0	1	17	0	0	3.3790095335108274	
i 1	127.50973469387755	0.505	74	1092	5	9	12	17	0	2	17	0	0	2.3790095335108274	
i 1	127.73377551020408	0.2525	74	1092	3	24	8	8	0	1	8	0	0	4.082137174582219	
i 1	127.7359387755102	0.2525	71	208	4	20	1	2	0	-2	2	0	0	0.08213717458221925	
i 1	127.75324489795918	0.2525	74	208	4	24	4	2	0	1	2	0	0	4.082137174582219	
i 1	127.75324489795918	1.2625	74	706	2	20	7	2	0	1	2	0	0	0.08213717458221925	
i 1	127.76189795918367	2.02	69	208	5	1	11	1	0	0	1	0	0	9.0	
i 1	127.76189795918367	2.02	72	706	4	24	5	1	0	-1	1	0	0	10.0	
i 1	127.98521768707484	0.505	77	1092	5	9	15	17	0	2	17	0	0	2.3790095335108274	
i 1	127.98521768707484	1.01	71	706	2	20	11	2	0	1	2	0	0	0.08213717458221925	
i 1	127.98810204081633	1.01	74	706	2	24	3	2	0	1	2	0	0	4.082137174582219	
i 1	127.99531292517007	0.505	74	706	4	2	11	16	0	2	16	0	0	3.3790095335108274	
i 1	128.00612925170068	1.01	74	706	2	24	1	2	0	1	2	0	0	4.082137174582219	
i 1	128.4917074829932	1.01	74	706	4	4	10	17	0	2	17	0	0	3.3790095335108274	
i 1	128.49459183673468	1.01	77	208	6	3	8	16	0	1	16	0	0	3.3790095335108274	
i 1	128.9974761904762	0.2525	74	1092	3	20	4	2	0	1	2	0	0	0.08213717458221925	
i 1	128.9996394557823	0.2525	74	1092	3	20	7	8	0	1	8	0	0	0.08213717458221925	
i 1	129.2366598639456	0.2525	71	706	4	20	15	2	0	1	2	0	0	0.08213717458221925	
i 1	129.23738095238096	0.2525	74	706	2	24	13	2	0	1	2	0	0	4.082137174582219	
i 1	129.2582925170068	0.7575000000000001	74	1092	3	24	12	8	0	1	8	0	0	4.082137174582219	
i 1	129.2640612244898	0.2525	74	208	4	24	1	2	0	1	2	0	0	4.082137174582219	
i 1	129.49026530612244	1.01	77	706	4	2	12	16	0	1	16	0	0	3.3790095335108274	
i 1	129.49026530612244	1.2625	77	208	7	5	4	16	0	1	16	0	0	2.0	
i 1	129.4917074829932	1.01	77	706	5	3	14	17	0	2	17	0	0	3.3790095335108274	
i 1	129.50108163265307	0.505	74	1092	3	20	13	2	0	-2	2	0	0	0.08213717458221925	
i 1	129.50396598639455	0.505	74	706	2	20	5	2	0	1	2	0	0	0.08213717458221925	
i 1	129.51766666666666	1.2625	74	1092	6	5	15	17	0	1	17	0	0	2.0	
i 1	129.51766666666666	0.505	74	706	2	24	5	2	0	1	2	0	0	4.082137174582219	
i 1	129.74459183673468	0.505	72	208	5	24	11	0	0	0	0	0	0	10.0	
i 1	129.75612925170068	0.505	69	1092	6	1	6	0	0	-1	0	0	0	9.0	
i 1	129.9830544217687	0.505	74	706	2	24	6	2	0	1	2	0	0	4.082137174582219	
i 1	130.0111768707483	0.2525	74	706	4	20	3	2	0	-2	2	0	0	0.08213717458221925	
i 1	130.01189795918367	1.01	74	1092	3	20	16	2	0	1	2	0	0	0.08213717458221925	
i 1	130.01478231292518	0.2525	71	706	4	20	10	2	0	-2	2	0	0	0.08213717458221925	
i 1	130.2388231292517	0.7575000000000001	69	706	5	1	2	0	0	0	0	0	0	9.0	
i 1	130.2417074829932	0.7575000000000001	69	1092	6	1	9	1	0	0	1	0	0	9.0	
i 1	130.2669455782313	0.7575000000000001	71	1092	3	20	15	8	0	-2	8	0	0	0.08213717458221925	
i 1	130.26766666666666	0.2525	74	706	2	20	4	2	0	-2	2	0	0	0.08213717458221925	
i 1	130.4888231292517	0.2525	74	706	4	4	9	17	0	2	17	0	0	3.3790095335108274	
i 1	130.4996394557823	0.2525	77	208	6	3	7	16	0	1	16	0	0	3.3790095335108274	
i 1	130.73810204081633	1.2625	77	706	6	5	1	17	0	2	17	0	0	2.0	
i 1	130.74675510204082	0.2525	74	208	5	4	4	17	0	1	17	0	0	3.3790095335108274	
i 1	130.75973469387756	0.2525	74	1092	5	9	11	17	0	2	17	0	0	2.3790095335108274	
i 1	130.7640612244898	1.2625	77	1092	6	5	7	17	0	1	17	0	0	2.0	
i 1	130.98377551020408	0.2525	74	208	4	20	15	2	0	1	2	0	0	0.08213717458221925	
i 1	130.98738095238096	1.01	77	208	6	3	1	16	0	1	16	0	0	3.3790095335108274	
i 1	130.9888231292517	0.2525	69	1092	6	1	1	0	0	-1	0	0	0	9.0	
i 1	130.99675510204082	2.02	74	706	2	24	15	2	0	1	2	0	0	4.082137174582219	
i 1	130.9996394557823	1.01	74	706	4	4	8	17	0	2	17	0	0	3.3790095335108274	
i 1	131.00180272108844	0.2525	72	208	5	24	6	0	0	0	0	0	0	10.0	
i 1	131.01045578231293	0.2525	71	706	4	20	9	8	0	1	8	0	0	0.08213717458221925	
i 1	131.01189795918367	1.2625	74	706	2	20	7	2	0	1	2	0	0	0.08213717458221925	
i 1	131.24387074829932	1.7675	74	706	2	20	7	8	0	1	8	0	0	0.08213717458221925	
i 1	131.24459183673468	1.01	74	706	2	24	5	2	0	-2	2	0	0	4.082137174582219	
i 1	131.24819727891156	1.5150000000000001	72	706	5	1	9	0	0	-1	0	0	0	9.0	
i 1	131.25757142857142	1.5150000000000001	72	706	6	1	1	1	0	-1	1	0	0	9.0	
i 1	131.99242857142858	0.2525	74	208	5	4	14	17	0	1	17	0	0	3.3790095335108274	
i 1	131.99531292517005	1.2625	77	706	5	5	4	17	0	1	17	0	0	2.0	
i 1	132.00540816326532	1.2625	74	706	6	5	10	16	0	1	16	0	0	2.0	
i 1	132.0082925170068	1.01	74	1092	5	9	3	17	0	2	17	0	0	2.3790095335108274	
i 1	132.23449659863945	0.7575000000000001	74	1092	3	24	14	8	0	1	8	0	0	4.082137174582219	
i 1	132.25901360544216	0.7575000000000001	74	208	5	4	10	17	0	1	17	0	0	3.3790095335108274	
i 1	132.26261904761904	0.7575000000000001	74	1092	1	20	1	2	0	-2	2	0	0	0.08213717458221925	
i 1	132.2669455782313	19.695	61	706	5	14	8	1	0	1	1	0	0	2.8211192209668345	
i 1	132.7474761904762	0.505	69	1092	4	1	4	0	0	-1	0	0	0	9.0	
i 1	132.7669455782313	0.505	72	208	5	24	10	0	0	0	0	0	0	10.0	
i 1	132.98521768707482	0.2525	74	1092	3	20	11	2	0	1	2	0	0	0.08213717458221925	
i 1	132.98738095238096	0.505	74	706	2	20	6	2	0	1	2	0	0	0.08213717458221925	
i 1	132.98954421768707	1.01	77	1092	5	9	7	17	0	2	17	0	0	2.3790095335108274	
i 1	132.99387074829932	1.01	74	706	6	2	8	16	0	2	16	0	0	3.3790095335108274	
i 1	133.00180272108844	0.2525	74	208	4	20	2	2	0	1	2	0	0	0.08213717458221925	
i 1	133.0169455782313	0.2525	71	706	2	20	2	2	0	1	2	0	0	0.08213717458221925	
i 1	133.2330544217687	0.505	74	1092	3	24	10	8	0	1	8	0	0	4.082137174582219	
i 1	133.2474761904762	1.5150000000000001	72	706	5	1	6	0	0	-1	0	0	0	9.0	
i 1	133.2474761904762	1.5150000000000001	72	706	6	1	10	1	0	-1	1	0	0	9.0	
i 1	133.26045578231293	0.2525	71	1092	1	20	3	8	0	-2	8	0	0	0.08213717458221925	
i 1	133.26261904761904	3.0300000000000002	77	208	6	5	10	16	0	1	16	0	0	2.0	
i 1	133.26261904761904	3.0300000000000002	74	1092	6	5	15	17	0	1	17	0	0	2.0	
i 1	133.26622448979592	0.2525	71	706	2	24	13	8	0	-2	8	0	0	4.082137174582219	
i 1	133.48449659863945	0.2525	71	208	4	24	5	2	0	-2	2	0	0	4.082137174582219	
i 1	133.50612925170068	0.2525	71	706	4	20	9	2	0	-2	2	0	0	0.08213717458221925	
i 1	133.51045578231293	2.2725	74	706	2	24	7	2	0	1	2	0	0	4.082137174582219	
i 1	133.73377551020408	5.8075	74	1092	1	24	7	8	0	252	8	307	0	4.082137174582219	
i 1	133.74675510204082	1.5150000000000001	74	706	2	20	13	8	0	-2	8	0	0	0.08213717458221925	
i 1	133.7474761904762	1.5150000000000001	74	1092	3	20	14	2	0	1	2	0	0	0.08213717458221925	
i 1	133.75324489795918	1.5150000000000001	74	1092	3	20	10	2	0	-2	2	0	0	0.08213717458221925	
i 1	133.98810204081633	0.2525	74	706	4	4	4	17	0	2	17	0	0	3.3790095335108274	
i 1	133.99819727891156	0.2525	77	208	4	3	10	16	0	1	16	0	0	3.3790095335108274	
i 1	134.23521768707482	0.2525	77	706	4	2	11	16	0	1	16	0	0	3.3790095335108274	
i 1	134.26045578231293	0.2525	77	706	5	3	14	17	0	2	17	0	0	3.3790095335108274	
i 1	134.49531292517005	0.505	74	706	4	4	16	17	0	2	17	0	0	3.3790095335108274	
i 1	134.51550340136055	0.505	77	208	4	3	8	16	0	1	16	0	0	3.3790095335108274	
i 1	134.7474761904762	1.2625	72	706	4	24	2	1	0	-1	1	0	0	10.0	
i 1	134.7611768707483	1.2625	69	208	5	1	14	1	0	0	1	0	0	9.0	
i 1	134.99387074829932	0.505	74	1092	5	9	3	17	0	2	17	0	0	2.3790095335108274	
i 1	135.00973469387756	0.505	74	208	5	4	5	17	0	1	17	0	0	3.3790095335108274	
i 1	135.24675510204082	0.505	71	706	4	20	1	2	0	1	2	0	0	0.08213717458221925	
i 1	135.25324489795918	0.505	74	208	4	20	3	2	0	-2	2	0	0	0.08213717458221925	
i 1	135.2669455782313	1.5150000000000001	74	706	2	20	8	2	0	1	2	0	0	0.08213717458221925	
i 1	135.49026530612244	2.02	77	208	4	3	11	16	0	1	16	0	0	3.3790095335108274	
i 1	135.49531292517005	2.02	74	706	4	4	14	17	0	2	17	0	0	3.3790095335108274	
i 1	135.7417074829932	2.2725	74	1092	3	20	16	2	0	1	2	0	0	0.08213717458221925	
i 1	135.75324489795918	1.01	71	706	2	24	11	2	0	1	2	0	0	4.082137174582219	
i 1	135.76045578231293	2.2725	71	1092	3	20	16	2	0	1	2	0	0	0.08213717458221925	
i 1	135.98954421768707	0.2525	72	208	5	24	2	0	0	0	0	0	0	10.0	
i 1	136.0169455782313	0.2525	69	1092	4	1	1	0	0	-1	0	0	0	9.0	
i 1	136.2330544217687	2.525	77	706	5	5	11	17	0	1	17	0	0	2.0	
i 1	136.25180272108844	1.5150000000000001	69	1092	6	1	15	1	0	0	1	0	0	9.0	
i 1	136.25540816326532	1.5150000000000001	69	706	5	1	13	0	0	0	0	0	0	9.0	
i 1	136.2633401360544	2.525	74	706	6	5	13	16	0	1	16	0	0	2.0	
i 1	136.73521768707482	1.2625	74	706	2	24	15	2	0	1	2	0	0	4.082137174582219	
i 1	136.7640612244898	1.2625	74	706	2	20	2	2	0	1	2	0	0	0.08213717458221925	
i 1	137.49891836734693	0.2525	74	208	5	4	15	17	0	1	17	0	0	3.3790095335108274	
i 1	137.51622448979592	0.2525	74	1092	5	9	7	17	0	2	17	0	0	2.3790095335108274	
i 1	137.74603401360545	0.2525	74	706	6	2	16	16	0	2	16	0	0	3.3790095335108274	
i 1	137.75468707482995	0.2525	77	1092	5	9	6	17	0	2	17	0	0	2.3790095335108274	
i 1	137.75612925170068	0.505	69	1092	4	1	6	0	0	-1	0	0	0	9.0	
i 1	137.76766666666666	0.505	72	208	5	24	15	0	0	0	0	0	0	10.0	
i 1	137.98233333333334	0.505	71	208	1	24	9	2	0	248	2	308	0	4.082137174582219	
i 1	137.98521768707482	0.505	74	706	2	20	7	2	0	1	2	0	0	0.08213717458221925	
i 1	137.98738095238096	0.505	77	208	4	3	6	16	0	1	16	0	0	3.3790095335108274	
i 1	137.98738095238096	13.8875	61	706	5	14	1	16	0	2	16	0	0	2.8211192209668345	
i 1	137.99531292517005	0.505	74	706	4	4	1	17	0	2	17	0	0	3.3790095335108274	
i 1	137.99819727891156	0.505	74	208	4	20	8	2	0	-2	2	0	0	0.08213717458221925	
i 1	138.00468707482995	13.8875	63	706	5	25	6	16	0	1	16	0	0	1.8802217002948172	
i 1	138.00468707482995	11.615	61	208	4	7	9	16	0	1	16	0	0	1.4105596104834173	
i 1	138.23377551020408	1.5150000000000001	72	706	6	1	16	1	0	-1	1	0	0	9.0	
i 1	138.23377551020408	0.2525	74	706	2	20	8	2	0	1	2	0	0	0.08213717458221925	
i 1	138.23738095238096	1.5150000000000001	72	706	5	1	8	0	0	-1	0	0	0	9.0	
i 1	138.23810204081633	1.7675	74	706	2	24	2	2	0	1	2	0	0	4.082137174582219	
i 1	138.48233333333334	0.505	77	706	5	3	15	17	0	2	17	0	0	3.3790095335108274	
i 1	138.4996394557823	1.01	71	1092	1	20	3	2	0	1	2	0	0	0.08213717458221925	
i 1	138.5025238095238	0.505	77	706	6	2	3	16	0	1	16	0	0	3.3790095335108274	
i 1	138.50540816326532	1.01	74	1092	3	20	7	2	0	1	2	0	0	0.08213717458221925	
i 1	138.51622448979592	1.01	74	706	2	20	1	2	0	-2	2	0	0	0.08213717458221925	
i 1	138.74098639455784	1.01	74	1092	5	5	10	17	0	1	17	0	0	2.0	
i 1	138.76478231292518	1.01	77	208	6	5	4	16	0	1	16	0	0	2.0	
i 1	138.9866598639456	1.01	74	706	4	4	4	17	0	2	17	0	0	3.3790095335108274	
i 1	139.0082925170068	1.01	77	208	4	3	8	16	0	1	16	0	0	3.3790095335108274	
i 1	139.50108163265307	0.505	71	706	2	20	3	8	0	1	8	0	0	0.08213717458221925	
i 1	139.50396598639455	0.505	74	1092	3	24	15	8	0	1	8	0	0	4.082137174582219	
i 1	139.50468707482995	0.505	71	208	4	24	5	2	0	-2	2	0	0	4.082137174582219	
i 1	139.7330544217687	0.505	72	208	5	24	5	0	0	0	0	0	0	10.0	
i 1	139.74242857142858	0.505	69	1092	4	1	3	0	0	-1	0	0	0	9.0	
i 1	139.74242857142858	0.2525	77	1092	6	5	13	17	0	1	17	0	0	2.0	
i 1	139.74603401360545	0.2525	77	706	6	5	3	17	0	2	17	0	0	2.0	
i 1	139.99026530612244	1.01	74	706	2	20	10	2	0	1	2	0	0	0.08213717458221925	
i 1	139.99603401360545	3.0300000000000002	77	706	5	5	10	17	0	1	17	0	0	2.0	
i 1	139.99603401360545	1.01	74	706	2	24	13	8	0	1	8	0	0	4.082137174582219	
i 1	139.99819727891156	3.0300000000000002	74	706	6	5	11	16	0	1	16	0	0	2.0	
i 1	140.0140612244898	1.01	74	1092	1	20	9	2	0	-2	2	0	0	0.08213717458221925	
i 1	140.01622448979592	1.01	74	1092	5	9	13	17	0	2	17	0	0	2.3790095335108274	
i 1	140.01766666666666	1.01	74	208	4	4	11	17	0	1	17	0	0	3.3790095335108274	
i 1	140.01766666666666	1.01	74	1092	3	20	3	2	0	1	2	0	0	0.08213717458221925	
i 1	140.2496394557823	0.7575000000000001	72	706	5	1	7	0	0	-1	0	0	0	9.0	
i 1	140.25685034013605	0.7575000000000001	72	706	6	1	11	1	0	-1	1	0	0	9.0	
i 1	140.9866598639456	1.2625	74	706	2	24	7	2	0	1	2	0	0	4.082137174582219	
i 1	140.9888231292517	1.7675	69	208	5	1	4	1	0	0	1	0	0	9.0	
i 1	140.9974761904762	0.505	77	208	4	3	2	16	0	1	16	0	0	3.3790095335108274	
i 1	141.00108163265307	0.7575000000000001	74	706	1	24	6	8	0	252	8	307	0	4.082137174582219	
i 1	141.00612925170068	0.7575000000000001	74	706	2	20	4	8	0	1	8	0	0	0.08213717458221925	
i 1	141.0133401360544	0.505	74	706	4	4	16	17	0	2	17	0	0	3.3790095335108274	
i 1	141.0169455782313	1.7675	72	706	4	24	5	1	0	-1	1	0	0	10.0	
i 1	141.49314965986395	0.505	74	1092	5	9	12	17	0	2	17	0	0	2.3790095335108274	
i 1	141.50324489795918	0.505	74	208	4	4	1	17	0	1	17	0	0	3.3790095335108274	
i 1	141.7359387755102	0.505	71	706	2	20	6	2	0	-2	2	0	0	0.08213717458221925	
i 1	141.7611768707483	0.2525	74	1092	3	24	8	8	0	1	8	0	0	4.082137174582219	
i 1	141.76550340136055	0.2525	74	208	4	24	7	2	0	1	2	0	0	4.082137174582219	
i 1	141.98449659863945	0.2525	74	208	4	20	8	2	0	-2	2	0	0	0.08213717458221925	
i 1	141.99531292517005	0.505	77	1092	5	9	16	17	0	2	17	0	0	2.3790095335108274	
i 1	142.00108163265307	0.505	74	706	2	20	1	2	0	1	2	0	0	0.08213717458221925	
i 1	142.00685034013605	0.505	74	706	6	2	15	16	0	2	16	0	0	3.3790095335108274	
i 1	142.26622448979592	0.2525	74	1092	3	20	3	2	0	1	2	0	0	0.08213717458221925	
i 1	142.4888231292517	0.2525	74	208	4	24	8	2	0	-2	2	0	0	4.082137174582219	
i 1	142.48954421768707	1.01	77	208	4	3	14	16	0	1	16	0	0	3.3790095335108274	
i 1	142.48954421768707	1.01	74	706	4	4	12	17	0	2	17	0	0	3.3790095335108274	
i 1	142.49314965986395	0.2525	74	1092	3	24	5	8	0	1	8	0	0	4.082137174582219	
i 1	142.51189795918367	0.2525	74	706	2	24	14	2	0	1	2	0	0	4.082137174582219	
i 1	142.51766666666666	0.2525	71	706	2	20	3	2	0	-2	2	0	0	0.08213717458221925	
i 1	142.73738095238096	1.01	74	1092	3	20	8	2	0	1	2	0	0	0.08213717458221925	
i 1	142.74026530612244	0.505	69	1092	4	1	7	0	0	-1	0	0	0	9.0	
i 1	142.74819727891156	0.505	72	208	5	24	15	0	0	0	0	0	0	10.0	
i 1	142.76550340136055	1.01	74	1092	1	20	11	2	0	1	2	0	0	0.08213717458221925	
i 1	143.0025238095238	2.525	77	208	6	5	1	16	0	1	16	0	0	2.0	
i 1	143.00468707482995	2.525	74	1092	5	5	6	17	0	1	17	0	0	2.0	
i 1	143.2359387755102	1.5150000000000001	69	706	6	1	2	0	0	0	0	0	0	9.0	
i 1	143.24675510204082	1.5150000000000001	69	1092	4	1	5	1	0	0	1	0	0	9.0	
i 1	143.50324489795918	1.01	77	706	5	3	9	17	0	2	17	0	0	3.3790095335108274	
i 1	143.50540816326532	1.01	77	706	6	2	16	16	0	1	16	0	0	3.3790095335108274	
i 1	143.76045578231293	8.08	61	706	5	25	3	1	0	1	1	0	0	1.8802217002948172	
i 1	143.76189795918367	0.2525	74	706	2	24	12	2	0	1	2	0	0	4.0	
i 1	143.9866598639456	0.2525	71	706	2	24	1	2	0	1	2	0	0	4.0	
i 1	144.48449659863945	0.2525	77	208	6	3	15	16	0	1	16	0	0	3.3790095335108274	
i 1	144.51045578231293	0.2525	74	706	4	4	5	17	0	2	17	0	0	3.3790095335108274	
i 1	144.7366598639456	0.505	69	1092	4	1	6	0	0	-1	0	0	0	9.0	
i 1	144.74459183673468	0.2525	74	208	4	4	7	17	0	1	17	0	0	3.3790095335108274	
i 1	144.74675510204082	0.2525	74	1092	3	9	7	17	0	2	17	0	0	2.3790095335108274	
i 1	144.74891836734693	0.505	72	208	5	24	3	0	0	0	0	0	0	10.0	
i 1	144.7525238095238	1.01	74	1092	3	24	16	8	0	1	8	0	0	4.0	
i 1	144.9866598639456	1.01	77	208	6	3	12	16	0	1	16	0	0	3.3790095335108274	
i 1	144.9866598639456	1.01	74	706	4	4	1	17	0	2	17	0	0	3.3790095335108274	
i 1	145.24098639455784	0.7575000000000001	72	706	3	1	1	1	0	-1	1	0	0	9.0	
i 1	145.2582925170068	0.7575000000000001	72	706	6	1	15	0	0	-1	0	0	0	9.0	
i 1	145.49603401360545	1.2625	77	706	5	5	16	17	0	1	17	0	0	2.0	
i 1	145.50757142857142	1.2625	74	706	6	5	7	16	0	1	16	0	0	2.0	
i 1	145.7474761904762	0.2525	74	706	2	24	14	2	0	1	2	0	0	4.0	
i 1	145.98738095238096	0.2525	72	208	5	24	1	0	0	0	0	0	0	10.0	
i 1	145.99098639455784	1.01	74	208	4	4	2	17	0	1	17	0	0	3.3790095335108274	
i 1	146.0003605442177	1.01	74	1092	3	9	12	17	0	2	17	0	0	2.3790095335108274	
i 1	146.00180272108844	0.2525	69	1092	4	1	2	0	0	-1	0	0	0	9.0	
i 1	146.23954421768707	1.5150000000000001	72	706	3	1	8	1	0	-1	1	0	0	9.0	
i 1	146.24531292517005	1.5150000000000001	72	706	6	1	13	0	0	-1	0	0	0	9.0	
i 1	146.75108163265307	0.2525	74	706	2	24	15	2	0	1	2	0	0	4.0	
i 1	146.75757142857142	1.5150000000000001	77	208	6	5	16	16	0	1	16	0	0	2.0	
i 1	146.76189795918367	1.5150000000000001	74	1092	5	5	11	17	0	1	17	0	0	2.0	
i 1	146.98449659863945	1.01	77	1092	5	9	4	17	0	2	17	0	0	2.3790095335108274	
i 1	146.9866598639456	1.01	74	706	6	2	6	16	0	2	16	0	0	3.3790095335108274	
i 1	147.0133401360544	0.7575000000000001	74	1092	3	24	14	8	0	1	8	0	0	4.0	
i 1	147.73233333333334	1.7675	69	208	5	1	7	1	0	0	1	0	0	9.0	
i 1	147.74314965986395	1.7675	72	706	4	24	14	1	0	-1	1	0	0	10.0	
i 1	147.75612925170068	0.2525	74	706	2	24	7	2	0	1	2	0	0	4.0	
i 1	147.9859387755102	0.2525	77	208	6	3	6	16	0	1	16	0	0	3.3790095335108274	
i 1	147.99242857142858	0.2525	74	706	4	4	9	17	0	2	17	0	0	3.3790095335108274	
i 1	148.23954421768707	1.5150000000000001	77	1092	5	5	15	17	0	1	17	0	0	2.0	
i 1	148.24459183673468	0.2525	77	706	6	2	8	16	0	1	16	0	0	3.3790095335108274	
i 1	148.24675510204082	0.2525	74	706	2	24	1	2	0	1	2	0	0	4.0	
i 1	148.2582925170068	0.2525	77	706	5	3	4	17	0	2	17	0	0	3.3790095335108274	
i 1	148.26550340136055	1.5150000000000001	77	706	6	5	9	17	0	2	17	0	0	2.0	
i 1	148.4917074829932	0.505	77	208	6	3	5	16	0	1	16	0	0	3.3790095335108274	
i 1	148.49242857142858	0.505	74	706	4	4	15	17	0	2	17	0	0	3.3790095335108274	
i 1	148.5169455782313	1.5150000000000001	74	706	1	24	4	2	0	248	2	308	0	4.0	
i 1	148.99675510204082	0.505	74	208	4	4	8	17	0	1	17	0	0	3.3790095335108274	
i 1	149.00540816326532	0.505	74	1092	3	9	7	17	0	2	17	0	0	2.3790095335108274	
i 1	149.4830544217687	2.2725	61	208	5	7	15	16	0	1	16	0	0	1.4105596104834173	
i 1	149.48377551020408	0.2525	72	706	3	24	15	1	0	-1	1	0	0	10.0	
i 1	149.48521768707482	0.2525	69	208	6	1	16	1	0	0	1	0	0	9.0	
i 1	149.4974761904762	2.02	74	706	4	4	9	17	0	2	17	0	0	3.3790095335108274	
i 1	149.50324489795918	2.2725	63	208	5	25	3	1	0	2	1	0	0	1.8802217002948172	
i 1	149.5140612244898	2.02	77	208	6	3	5	16	0	1	16	0	0	3.3790095335108274	
i 1	149.7474761904762	0.505	69	1092	4	1	3	0	0	-1	0	0	0	9.0	
i 1	149.75757142857142	0.505	72	208	5	24	2	0	0	0	0	0	0	10.0	
i 1	149.7633401360544	2.02	74	706	6	5	12	16	0	1	16	0	0	2.0	
i 1	149.7669455782313	2.02	77	706	4	5	1	17	0	1	17	0	0	2.0	
i 1	149.99531292517005	1.01	69	706	6	1	12	0	0	0	0	0	0	9.0	
i 1	149.99531292517005	1.01	69	1092	4	1	3	1	0	0	1	0	0	9.0	
i 1	150.01622448979592	0.7575000000000001	74	706	2	24	1	2	0	1	2	0	0	4.0	
i 1	150.75180272108844	0.505	72	208	5	24	11	0	0	0	0	0	0	10.0	
i 1	150.76045578231293	0.505	69	1092	4	1	7	0	0	-1	0	0	0	9.0	
i 1	150.98449659863945	0.7575000000000001	74	706	2	24	2	2	0	1	2	0	0	4.0	
i 1	150.99026530612244	0.2525	77	208	6	5	6	16	0	1	16	0	0	2.0	
i 1	151.24531292517005	0.505	72	706	3	1	1	1	0	-1	1	0	0	9.0	
i 1	151.2496394557823	0.505	74	208	1	24	8	8	0	252	8	307	0	4.0	
i 1	151.2525238095238	0.505	72	706	6	1	15	0	0	-1	0	0	0	9.0	
i 1	151.25612925170068	0.505	74	208	5	4	2	17	0	1	17	0	0	3.3790095335108274	
i 1	151.25973469387756	0.505	74	1092	3	9	14	17	0	2	17	0	0	2.3790095335108274	
i 1	151.50973469387756	0.2525	77	706	6	5	13	17	0	2	17	0	0	2.0	
i 1	151.73233333333334	0.2525	77	198	4	9	8	17	0	1	17	0	0	2.3790095335108274	
i 1	151.7330544217687	20.9575	63	198	4	27	9	16	0	2	16	0	0	2.646775903379499	
i 1	151.73810204081633	20.9575	61	900	5	25	14	1	0	1	1	0	0	1.8802217002948172	
i 1	151.74098639455784	0.2525	74	584	4	4	9	16	0	2	16	0	0	3.3790095335108274	
i 1	151.74242857142858	0.505	72	198	5	1	6	1	0	-1	1	0	0	9.0	
i 1	151.74242857142858	9.3425	63	198	5	26	7	1	0	2	1	0	0	1.8802217002948172	
i 1	151.74242857142858	20.9575	63	900	5	14	11	16	0	1	16	0	0	2.8211192209668345	
i 1	151.74387074829932	0.2525	74	198	6	3	2	17	0	1	17	0	0	3.3790095335108274	
i 1	151.74459183673468	20.9575	63	198	4	27	8	1	0	2	1	0	0	2.646775903379499	
i 1	151.74531292517005	20.9575	61	584	5	25	2	16	0	1	16	0	0	1.8802217002948172	
i 1	151.74603401360545	20.9575	63	900	5	14	14	16	0	2	16	0	0	2.8211192209668345	
i 1	151.74819727891156	1.2625	77	198	6	5	9	17	0	1	17	0	0	2.0	
i 1	151.74891836734693	0.505	72	900	6	1	12	1	0	-1	1	0	0	9.0	
i 1	151.74891836734693	3.535	61	584	5	25	7	16	0	2	16	0	0	1.8802217002948172	
i 1	151.74891836734693	15.15	61	198	5	26	1	1	0	1	1	0	0	1.8802217002948172	
i 1	151.7503605442177	0.505	74	900	6	2	2	16	0	1	16	0	0	3.3790095335108274	
i 1	151.75180272108844	20.9575	61	900	5	25	6	16	0	1	16	0	0	1.8802217002948172	
i 1	151.75180272108844	1.2625	77	584	6	5	14	17	0	2	17	0	0	2.0	
i 1	151.75468707482995	0.2525	74	584	5	3	15	16	0	1	16	0	0	3.3790095335108274	
i 1	151.75757142857142	0.505	74	198	4	9	6	16	0	2	16	0	0	2.3790095335108274	
i 1	151.76766666666666	20.9575	63	584	5	7	8	16	0	1	16	0	0	1.4105596104834173	
i 1	152.24531292517005	1.01	71	198	3	24	14	2	0	-2	2	0	0	4.0	
i 1	152.24603401360545	0.7575000000000001	74	584	5	3	4	16	0	1	16	0	0	3.3790095335108274	
i 1	152.24891836734693	0.7575000000000001	74	198	6	3	13	17	0	1	17	0	0	3.3790095335108274	
i 1	152.25324489795918	2.02	72	584	6	1	9	0	0	0	0	0	0	9.0	
i 1	152.2640612244898	2.02	69	198	4	1	7	0	0	-1	0	0	0	9.0	
i 1	152.48810204081633	1.2625	74	198	5	4	9	17	0	2	17	0	0	3.3790095335108274	
i 1	152.50757142857142	0.2525	69	198	5	1	3	0	0	0	0	0	0	9.0	
i 1	152.51045578231293	1.2625	74	584	4	4	11	16	0	2	16	0	0	3.3790095335108274	
i 1	152.7388231292517	2.02	74	900	6	5	10	17	0	1	17	0	0	2.0	
i 1	152.74459183673468	2.02	74	198	6	5	8	17	0	1	17	0	0	2.0	
i 1	152.74531292517005	0.505	74	198	4	24	5	2	0	-2	2	0	0	4.0	
i 1	152.99531292517005	0.2525	72	198	5	1	3	1	0	-1	1	0	0	9.0	
i 1	153.00180272108844	0.2525	77	198	5	5	16	17	0	1	17	0	0	2.0	
i 1	153.25396598639455	0.505	72	198	4	24	10	0	0	-1	0	0	0	10.0	
i 1	153.49026530612244	0.2525	77	198	4	9	8	17	0	1	17	0	0	2.3790095335108274	
i 1	153.51261904761904	0.2525	77	584	6	5	4	17	0	2	17	0	0	2.0	
i 1	153.74098639455784	1.2625	74	198	6	3	4	17	0	1	17	0	0	3.3790095335108274	
i 1	153.74675510204082	0.2525	69	198	5	1	7	0	0	0	0	0	0	9.0	
i 1	153.76478231292518	1.2625	74	584	5	3	11	16	0	1	16	0	0	3.3790095335108274	
i 1	153.9917074829932	0.2525	77	198	5	5	3	17	0	1	17	0	0	2.0	
i 1	154.00468707482995	3.0300000000000002	72	198	4	24	9	0	0	-1	0	0	0	10.0	
i 1	154.00612925170068	0.2525	74	198	4	24	10	2	0	-2	2	0	0	4.0	
i 1	154.01622448979592	1.2625	69	584	4	24	6	0	0	0	0	0	0	10.0	
i 1	154.23954421768707	1.7675	77	584	6	5	12	17	0	2	17	0	0	2.0	
i 1	154.24314965986395	0.2525	74	900	6	2	3	17	0	1	17	0	0	3.3790095335108274	
i 1	154.24819727891156	1.01	77	198	6	5	13	17	0	1	17	0	0	2.0	
i 1	154.26550340136055	0.2525	72	900	6	1	7	1	0	-1	1	0	0	9.0	
i 1	154.73233333333334	0.505	72	900	6	1	3	1	0	-1	1	0	0	9.0	
i 1	154.74603401360545	0.2525	74	198	1	24	8	8	0	-2	8	0	0	4.0	
i 1	154.76189795918367	0.505	69	198	5	1	13	0	0	0	0	0	0	9.0	
i 1	154.9830544217687	0.2525	74	198	5	4	3	17	0	2	17	0	0	3.3790095335108274	
i 1	155.0003605442177	0.2525	74	584	4	4	1	16	0	2	16	0	0	3.3790095335108274	
i 1	155.0133401360544	0.2525	74	198	6	5	10	17	0	1	17	0	0	2.0	
i 1	155.24242857142858	0.7575000000000001	77	198	5	5	4	17	0	1	17	0	0	2.0	
i 1	155.24314965986395	17.4225	61	584	5	25	3	16	0	2	16	0	0	1.8802217002948172	
i 1	155.2525238095238	0.505	77	198	6	9	7	17	0	1	17	0	0	2.3790095335108274	
i 1	155.26478231292518	1.7675	69	584	4	24	5	0	0	0	0	0	0	10.0	
i 1	155.26766666666666	0.505	74	900	6	2	9	17	0	1	17	0	0	3.3790095335108274	
i 1	155.49242857142858	0.2525	72	900	6	1	14	1	0	-1	1	0	0	9.0	
i 1	155.49675510204082	0.7575000000000001	74	198	3	3	6	17	0	1	17	0	0	3.3790095335108274	
i 1	155.50180272108844	0.7575000000000001	74	584	5	3	4	16	0	1	16	0	0	3.3790095335108274	
i 1	155.73521768707482	1.5150000000000001	74	900	6	5	4	17	0	1	17	0	0	2.0	
i 1	155.73738095238096	1.5150000000000001	74	198	6	5	7	16	0	2	16	0	0	2.0	
i 1	155.74531292517005	0.505	71	198	3	24	13	2	0	-2	2	0	0	4.0	
i 1	155.7474761904762	0.505	74	198	2	24	6	2	0	-2	2	0	0	4.0	
i 1	155.7633401360544	0.2525	74	584	4	24	7	2	0	-2	2	0	0	4.0	
i 1	155.99603401360545	1.01	74	900	6	2	1	16	0	1	16	0	0	3.3790095335108274	
i 1	156.0025238095238	1.01	74	198	4	9	2	16	0	2	16	0	0	2.3790095335108274	
i 1	156.00901360544216	0.2525	74	900	6	5	16	17	0	1	17	0	0	2.0	
i 1	156.01622448979592	1.01	74	198	3	24	8	2	0	1	2	0	0	4.0	
i 1	156.25685034013605	0.2525	74	198	6	5	11	17	0	1	17	0	0	2.0	
i 1	156.48738095238096	1.01	72	198	5	1	3	1	0	-1	1	0	0	9.0	
i 1	156.5025238095238	0.2525	77	198	6	9	4	17	0	1	17	0	0	2.3790095335108274	
i 1	156.50973469387756	1.01	72	900	6	1	12	1	0	-1	1	0	0	9.0	
i 1	156.7366598639456	2.7775	74	900	6	5	9	17	0	1	17	0	0	2.0	
i 1	156.7611768707483	2.2725	74	198	3	3	2	17	0	1	17	0	0	3.3790095335108274	
i 1	156.76766666666666	2.2725	74	584	5	3	2	16	0	1	16	0	0	3.3790095335108274	
i 1	156.9866598639456	0.2525	74	198	5	4	3	17	0	2	17	0	0	3.3790095335108274	
i 1	157.00973469387756	0.2525	74	198	2	24	3	2	0	-2	2	0	0	4.0	
i 1	157.01261904761904	0.2525	72	900	6	1	6	1	0	-1	1	0	0	9.0	
i 1	157.23521768707482	0.2525	77	584	6	5	5	16	0	1	16	0	0	2.0	
i 1	157.24675510204082	1.7675	72	198	4	24	11	0	0	-1	0	0	0	10.0	
i 1	157.25612925170068	1.7675	69	584	4	24	9	0	0	0	0	0	0	10.0	
i 1	157.26550340136055	2.2725	74	198	6	5	15	17	0	1	17	0	0	2.0	
i 1	157.50324489795918	0.2525	77	198	5	5	10	17	0	1	17	0	0	2.0	
i 1	157.50612925170068	2.02	74	584	4	4	10	16	0	2	16	0	0	3.3790095335108274	
i 1	157.74098639455784	1.7675	74	198	5	4	14	17	0	2	17	0	0	3.3790095335108274	
i 1	158.00540816326532	0.2525	72	900	6	1	8	1	0	-1	1	0	0	9.0	
i 1	158.00901360544216	0.2525	74	198	2	24	9	2	0	-2	2	0	0	4.0	
i 1	158.24387074829932	1.2625	71	198	3	24	6	2	0	-2	2	0	0	4.0	
i 1	158.25108163265307	0.2525	69	198	4	1	6	0	0	-1	0	0	0	9.0	
i 1	158.25468707482995	0.505	74	198	3	24	13	2	0	1	2	0	0	4.0	
i 1	158.4974761904762	1.01	72	900	6	1	14	1	0	-1	1	0	0	9.0	
i 1	158.5111768707483	1.01	72	198	5	1	3	1	0	-1	1	0	0	9.0	
i 1	158.73449659863945	0.2525	74	198	6	5	9	16	0	2	16	0	0	2.0	
i 1	158.76766666666666	0.505	71	584	4	24	8	2	0	-2	2	0	0	4.0	
i 1	158.99891836734693	1.5150000000000001	69	198	4	1	3	0	0	-1	0	0	0	9.0	
i 1	159.00324489795918	1.5150000000000001	72	584	6	1	11	0	0	0	0	0	0	9.0	
i 1	159.23233333333334	2.2725	77	584	6	5	10	17	0	2	17	0	0	2.0	
i 1	159.2359387755102	1.2625	71	198	3	24	13	2	0	1	2	0	0	4.0	
i 1	159.2417074829932	1.5150000000000001	77	198	6	9	14	17	0	1	17	0	0	2.3790095335108274	
i 1	159.24675510204082	1.2625	74	900	6	2	4	17	0	1	17	0	0	3.3790095335108274	
i 1	159.25612925170068	2.2725	77	198	5	5	15	17	0	1	17	0	0	2.0	
i 1	159.49387074829932	0.2525	74	900	6	2	10	16	0	1	16	0	0	3.3790095335108274	
i 1	159.50757142857142	0.2525	69	198	5	1	15	0	0	0	0	0	0	9.0	
i 1	159.50901360544216	0.7575000000000001	71	198	1	24	16	2	0	248	2	308	0	4.0	
i 1	159.74675510204082	4.04	74	198	3	3	15	17	0	1	17	0	0	3.3790095335108274	
i 1	159.7474761904762	0.2525	72	198	5	1	11	1	0	-1	1	0	0	9.0	
i 1	159.76550340136055	0.2525	74	900	6	5	1	17	0	1	17	0	0	2.0	
i 1	159.9917074829932	0.2525	69	198	5	1	7	0	0	0	0	0	0	9.0	
i 1	160.0133401360544	3.7875	74	584	5	3	16	16	0	1	16	0	0	3.3790095335108274	
i 1	160.01550340136055	0.7575000000000001	74	198	2	24	3	2	0	-2	2	0	0	4.0	
i 1	160.24098639455784	5.05	72	198	4	24	9	0	0	-1	0	0	0	10.0	
i 1	160.25612925170068	0.2525	74	900	6	5	9	17	0	1	17	0	0	2.0	
i 1	160.26045578231293	5.05	69	584	4	24	3	0	0	0	0	0	0	10.0	
i 1	160.26622448979592	1.2625	71	198	3	24	2	2	0	-2	2	0	0	4.0	
i 1	160.50757142857142	0.2525	77	584	6	5	13	16	0	1	16	0	0	2.0	
i 1	160.51045578231293	0.2525	72	900	6	1	16	1	0	-1	1	0	0	9.0	
i 1	160.74026530612244	0.2525	74	198	5	4	16	17	0	2	17	0	0	3.3790095335108274	
i 1	160.7525238095238	3.7875	74	198	6	5	5	17	0	1	17	0	0	2.0	
i 1	160.75973469387756	0.505	69	198	4	1	7	0	0	-1	0	0	0	9.0	
i 1	160.98377551020408	0.7575000000000001	74	900	6	2	8	16	0	1	16	0	0	3.3790095335108274	
i 1	161.00180272108844	11.615	63	198	5	26	10	1	0	2	1	0	0	1.8802217002948172	
i 1	161.00540816326532	0.7575000000000001	74	198	6	9	1	16	0	2	16	0	0	2.3790095335108274	
i 1	161.00757142857142	3.2825	74	900	6	5	13	17	0	1	17	0	0	2.0	
i 1	161.25396598639455	1.2625	72	900	6	1	15	1	0	-1	1	0	0	9.0	
i 1	161.48233333333334	1.01	74	198	3	4	7	17	0	2	17	0	0	3.3790095335108274	
i 1	161.49675510204082	1.2625	69	198	6	1	9	0	0	0	0	0	0	9.0	
i 1	161.49675510204082	0.7575000000000001	74	584	4	4	12	16	0	2	16	0	0	3.3790095335108274	
i 1	161.5133401360544	0.2525	74	900	6	5	12	17	0	1	17	0	0	2.0	
i 1	161.74314965986395	0.2525	77	584	6	5	5	17	0	2	17	0	0	2.0	
i 1	161.75540816326532	1.01	71	198	3	24	1	2	0	-2	2	0	0	4.0	
i 1	162.25540816326532	3.2825	74	198	4	24	7	2	0	-2	2	0	0	4.0	
i 1	162.51189795918367	0.2525	77	198	6	9	11	17	0	1	17	0	0	2.3790095335108274	
i 1	162.74314965986395	0.7575000000000001	69	198	4	1	2	0	0	-1	0	0	0	9.0	
i 1	162.7525238095238	0.7575000000000001	71	198	1	24	6	2	0	252	2	307	0	4.0	
i 1	162.75324489795918	0.2525	74	900	6	2	16	16	0	1	16	0	0	3.3790095335108274	
i 1	163.00901360544216	0.7575000000000001	74	198	3	24	6	2	0	-2	2	0	0	4.0	
i 1	163.01261904761904	1.7675	74	198	3	4	2	17	0	2	17	0	0	3.3790095335108274	
i 1	163.2669455782313	1.5150000000000001	74	584	4	4	4	16	0	2	16	0	0	3.3790095335108274	
i 1	163.49242857142858	1.01	72	198	5	1	7	1	0	-1	1	0	0	9.0	
i 1	163.50685034013605	3.2825	71	198	3	24	13	2	0	-2	2	0	0	4.0	
i 1	163.50901360544216	0.2525	77	198	5	5	11	17	0	1	17	0	0	2.0	
i 1	163.51261904761904	2.02	72	900	6	1	6	1	0	-1	1	0	0	9.0	
i 1	163.73233333333334	1.7675	77	584	6	5	2	17	0	2	17	0	0	2.0	
i 1	163.7474761904762	0.2525	77	198	6	9	14	17	0	1	17	0	0	2.3790095335108274	
i 1	163.75324489795918	0.2525	74	584	4	24	11	8	0	-2	8	0	0	4.0	
i 1	163.76550340136055	1.7675	77	198	5	5	16	17	0	1	17	0	0	2.0	
i 1	163.9996394557823	0.2525	74	198	3	3	5	17	0	1	17	0	0	3.3790095335108274	
i 1	164.01622448979592	0.2525	74	198	3	24	8	2	0	1	2	0	0	4.0	
i 1	164.24242857142858	0.7575000000000001	74	900	6	2	4	17	0	1	17	0	0	3.3790095335108274	
i 1	164.24819727891156	0.2525	71	584	4	24	9	2	0	1	2	0	0	4.0	
i 1	164.25973469387756	0.7575000000000001	77	198	6	9	6	17	0	1	17	0	0	2.3790095335108274	
i 1	164.48521768707482	0.505	74	198	3	24	10	2	0	1	2	0	0	4.0	
i 1	164.4859387755102	0.2525	74	198	6	5	1	16	0	2	16	0	0	2.0	
i 1	164.4996394557823	1.5150000000000001	74	198	3	3	14	17	0	1	17	0	0	3.3790095335108274	
i 1	164.5169455782313	1.5150000000000001	74	584	5	3	5	16	0	1	16	0	0	3.3790095335108274	
i 1	164.7359387755102	0.2525	74	198	6	5	6	17	0	1	17	0	0	2.0	
i 1	164.73738095238096	0.7575000000000001	72	198	5	1	9	1	0	-1	1	0	0	9.0	
i 1	164.75757142857142	0.7575000000000001	74	198	6	9	4	16	0	2	16	0	0	2.3790095335108274	
i 1	164.76478231292518	0.7575000000000001	74	900	6	2	14	16	0	1	16	0	0	3.3790095335108274	
i 1	164.9866598639456	1.7675	74	198	6	5	14	16	0	2	16	0	0	2.0	
i 1	164.98810204081633	2.525	69	198	4	1	1	0	0	-1	0	0	0	9.0	
i 1	165.0003605442177	0.2525	71	584	4	24	14	2	0	-2	2	0	0	4.0	
i 1	165.01189795918367	1.5150000000000001	74	900	6	5	7	17	0	1	17	0	0	2.0	
i 1	165.0169455782313	1.7675	72	584	6	1	15	0	0	0	0	0	0	9.0	
i 1	165.2417074829932	0.2525	74	198	3	24	9	2	0	-2	2	0	0	4.0	
i 1	165.50468707482995	1.5150000000000001	74	198	3	4	9	17	0	2	17	0	0	3.3790095335108274	
i 1	165.5133401360544	1.5150000000000001	74	584	4	4	1	16	0	2	16	0	0	3.3790095335108274	
i 1	165.51550340136055	0.2525	77	584	6	5	13	16	0	1	16	0	0	2.0	
i 1	165.5169455782313	0.505	72	900	6	1	9	1	0	-1	1	0	0	9.0	
i 1	165.74891836734693	0.2525	77	198	5	5	12	17	0	1	17	0	0	2.0	
i 1	165.99026530612244	2.525	74	900	6	5	13	17	0	1	17	0	0	2.0	
i 1	165.9917074829932	2.2725	74	198	6	5	7	17	0	1	17	0	0	2.0	
i 1	166.00973469387756	0.2525	77	198	6	9	11	17	0	1	17	0	0	2.3790095335108274	
i 1	166.0111768707483	0.2525	72	198	4	24	7	0	0	-1	0	0	0	10.0	
i 1	166.2359387755102	0.2525	74	900	6	2	9	16	0	1	16	0	0	3.3790095335108274	
i 1	166.23954421768707	0.505	69	584	4	24	4	0	0	0	0	0	0	10.0	
i 1	166.24242857142858	0.505	74	198	3	24	7	2	0	-2	2	0	0	4.0	
i 1	166.4859387755102	0.2525	74	198	3	3	2	17	0	1	17	0	0	3.3790095335108274	
i 1	166.49026530612244	3.0300000000000002	74	584	5	3	12	16	0	1	16	0	0	3.3790095335108274	
i 1	166.51766666666666	1.01	74	198	4	24	16	2	0	-2	2	0	0	4.0	
i 1	166.7366598639456	0.505	74	584	4	24	4	2	0	1	2	0	0	4.0	
i 1	166.74098639455784	2.525	74	198	6	3	9	17	0	1	17	0	0	3.3790095335108274	
i 1	166.74314965986395	0.505	77	198	5	5	5	17	0	1	17	0	0	2.0	
i 1	166.7503605442177	0.7575000000000001	72	584	6	1	3	0	0	0	0	0	0	9.0	
i 1	166.75612925170068	0.2525	72	900	6	1	6	1	0	-1	1	0	0	9.0	
i 1	166.76550340136055	5.8075	61	198	5	26	15	1	0	1	1	0	0	1.8802217002948172	
i 1	166.76622448979592	0.7575000000000001	71	198	1	24	13	2	0	-2	2	0	0	4.0	
i 1	166.98449659863945	4.7975	69	584	4	24	7	0	0	0	0	0	0	10.0	
i 1	166.9866598639456	4.7975	72	198	4	24	3	0	0	-1	0	0	0	10.0	
i 1	166.99242857142858	0.7575000000000001	74	198	6	9	14	16	0	2	16	0	0	2.3790095335108274	
i 1	167.2582925170068	0.2525	74	900	6	5	6	17	0	1	17	0	0	2.0	
i 1	167.2582925170068	0.2525	71	198	3	24	15	2	0	1	2	0	0	4.0	
i 1	167.4830544217687	0.2525	69	198	6	1	2	0	0	0	0	0	0	9.0	
i 1	167.51261904761904	0.2525	74	198	6	5	1	16	0	2	16	0	0	2.0	
i 1	167.73954421768707	0.7575000000000001	74	584	4	4	2	16	0	2	16	0	0	3.3790095335108274	
i 1	167.74026530612244	0.2525	72	584	6	1	12	0	0	0	0	0	0	9.0	
i 1	167.7474761904762	3.2825	77	584	6	5	11	17	0	2	17	0	0	2.0	
i 1	167.75180272108844	3.2825	77	198	5	5	16	17	0	1	17	0	0	2.0	
i 1	167.75468707482995	0.7575000000000001	74	198	3	4	6	17	0	2	17	0	0	3.3790095335108274	
i 1	167.76550340136055	1.01	71	198	1	24	4	2	0	-2	2	0	0	4.0	
i 1	167.99098639455784	0.2525	72	198	6	1	13	1	0	-1	1	0	0	9.0	
i 1	167.99819727891156	0.7575000000000001	77	198	6	9	12	17	0	1	17	0	0	2.3790095335108274	
i 1	168.01766666666666	0.7575000000000001	74	900	5	2	11	17	0	1	17	0	0	3.3790095335108274	
i 1	168.23738095238096	1.2625	74	198	4	24	5	2	0	-2	2	0	0	4.0	
i 1	168.25757142857142	1.2625	72	900	6	1	3	1	0	-1	1	0	0	9.0	
i 1	168.26766666666666	0.2525	74	584	4	24	1	8	0	-2	8	0	0	4.0	
i 1	168.48810204081633	3.535	74	198	3	24	14	2	0	-2	2	0	0	4.0	
i 1	168.50612925170068	0.2525	77	198	5	5	10	17	0	1	17	0	0	2.0	
i 1	168.5111768707483	1.01	69	198	6	1	15	0	0	0	0	0	0	9.0	
i 1	168.74819727891156	1.5150000000000001	74	900	6	2	9	16	0	1	16	0	0	3.3790095335108274	
i 1	168.75757142857142	1.01	74	198	6	5	11	16	0	2	16	0	0	2.0	
i 1	168.76189795918367	1.7675	74	198	6	9	10	16	0	2	16	0	0	2.3790095335108274	
i 1	169.4917074829932	0.2525	69	198	4	1	14	0	0	-1	0	0	0	9.0	
i 1	169.50540816326532	0.2525	74	198	3	4	15	17	0	2	17	0	0	3.3790095335108274	
i 1	169.74459183673468	2.2725	74	584	5	3	7	16	0	1	16	0	0	3.3790095335108274	
i 1	169.74531292517005	2.2725	74	198	6	3	6	17	0	1	17	0	0	3.3790095335108274	
i 1	169.7474761904762	0.7575000000000001	72	900	6	1	1	1	0	-1	1	0	0	9.0	
i 1	169.7503605442177	0.505	77	198	5	5	9	17	0	1	17	0	0	2.0	
i 1	169.76261904761904	1.01	72	198	6	1	8	1	0	-1	1	0	0	9.0	
i 1	170.25612925170068	0.2525	74	900	6	5	4	17	0	1	17	0	0	2.0	
i 1	170.49675510204082	0.2525	77	198	6	9	11	17	0	1	17	0	0	2.3790095335108274	
i 1	170.50757142857142	2.02	74	198	6	5	11	17	0	1	17	0	0	2.0	
i 1	170.50973469387756	2.02	74	900	6	5	14	17	0	1	17	0	0	2.0	
i 1	170.73738095238096	1.7675	74	584	4	4	16	16	0	2	16	0	0	3.3790095335108274	
i 1	170.7417074829932	0.505	72	900	6	1	2	1	0	-1	1	0	0	9.0	
i 1	170.7640612244898	1.5150000000000001	74	198	3	4	2	17	0	2	17	0	0	3.3790095335108274	
i 1	171.00973469387756	0.2525	74	198	6	5	11	16	0	2	16	0	0	2.0	
i 1	171.23738095238096	0.2525	74	900	6	5	1	17	0	1	17	0	0	2.0	
i 1	171.25901360544216	0.2525	72	198	6	1	11	1	0	-1	1	0	0	9.0	
i 1	171.49314965986395	0.2525	72	900	6	1	2	1	0	-1	1	0	0	9.0	
i 1	171.5140612244898	0.2525	77	584	6	5	1	17	0	2	17	0	0	2.0	
i 1	171.7330544217687	0.505	72	900	6	1	12	1	0	-1	1	0	0	9.0	
i 1	171.73377551020408	0.505	71	198	1	24	15	2	0	-2	2	0	0	4.0	
i 1	171.74387074829932	0.7575000000000001	69	198	4	1	15	0	0	-1	0	0	0	9.0	
i 1	171.75108163265307	0.505	72	198	6	1	9	1	0	-1	1	0	0	9.0	
i 1	171.9830544217687	0.505	77	198	6	9	4	17	0	1	17	0	0	2.3790095335108274	
i 1	171.98449659863945	0.505	74	900	5	2	15	17	0	1	17	0	0	3.3790095335108274	
i 1	172.00468707482995	0.2525	77	198	5	5	3	17	0	1	17	0	0	2.0	
i 1	172.01189795918367	0.505	72	584	6	1	7	0	0	0	0	0	0	9.0	
i 1	172.2388231292517	0.2525	77	198	5	5	16	17	0	1	17	0	0	2.0	
i 1	172.24603401360545	0.2525	72	198	4	24	13	0	0	-1	0	0	0	10.0	
i 1	172.24603401360545	0.2525	74	198	4	24	5	2	0	-2	2	0	0	4.0	
i 1	172.48233333333334	10.605	63	900	5	13	10	1	0	2	1	0	0	2.783413400801119	
i 1	172.48377551020408	10.605	61	584	5	15	14	1	0	1	1	0	0	3.2473156342679723	
i 1	172.48377551020408	10.605	61	198	4	12	14	1	0	1	1	0	0	3.7112178677348253	
i 1	172.48377551020408	1.01	74	900	5	2	11	17	0	1	17	0	0	3.4392260014518	
i 1	172.48521768707482	1.5150000000000001	74	198	4	20	4	2	0	1	2	0	0	0.013049016299054639	
i 1	172.48738095238096	10.605	61	584	5	25	3	16	0	2	16	0	0	1.0137921208505258	
i 1	172.49026530612244	10.605	63	198	4	27	14	16	0	2	16	0	0	1.780346323935208	
i 1	172.4917074829932	2.02	69	198	5	1	3	0	0	-1	0	0	0	2.0	
i 1	172.49242857142858	0.7575000000000001	74	198	6	5	2	17	0	1	17	0	0	7.0	
i 1	172.49459183673468	0.2525	69	198	6	1	7	0	0	0	0	0	0	2.0	
i 1	172.49531292517005	10.605	61	900	5	25	9	1	0	1	1	0	0	1.0137921208505258	
i 1	172.4996394557823	25.25	61	198	5	26	12	1	0	1	1	0	0	1.0137921208505258	
i 1	172.4996394557823	2.7775	74	198	4	24	15	2	0	-2	2	0	0	4.013049016299055	
i 1	172.50108163265307	25.25	63	198	5	26	13	1	0	2	1	0	0	1.0137921208505258	
i 1	172.50324489795918	2.02	72	584	6	1	11	0	0	0	0	0	0	2.0	
i 1	172.50324489795918	17.4225	61	198	5	16	6	16	0	2	16	0	0	3.7112178677348253	
i 1	172.50540816326532	1.01	74	198	4	20	12	8	0	-2	8	0	0	0.013049016299054639	
i 1	172.50612925170068	0.7575000000000001	74	900	6	5	16	17	0	1	17	0	0	7.0	
i 1	172.50685034013605	10.605	61	198	4	12	3	16	0	1	16	0	0	3.7112178677348253	
i 1	172.50757142857142	10.605	61	900	5	14	3	1	0	1	1	0	0	4.175120101201679	
i 1	172.5111768707483	23.23	61	198	5	16	7	16	0	1	16	0	0	3.7112178677348253	
i 1	172.5111768707483	0.2525	74	900	5	2	14	16	0	1	16	0	0	3.4392260014518	
i 1	172.51189795918367	1.01	77	198	6	9	1	17	0	1	17	0	0	2.4392260014518	
i 1	172.51189795918367	5.8075	63	198	4	27	16	1	0	2	1	0	0	1.780346323935208	
i 1	172.51261904761904	5.8075	63	584	5	15	10	16	0	1	16	0	0	3.2473156342679723	
i 1	172.5133401360544	1.01	74	198	4	20	8	2	0	-2	2	0	0	0.013049016299054639	
i 1	172.51550340136055	10.605	61	584	5	25	1	16	0	1	16	0	0	1.0137921208505258	
i 1	172.51622448979592	10.605	61	900	5	25	1	16	0	1	16	0	0	1.0137921208505258	
i 1	172.75901360544216	0.7575000000000001	77	584	6	5	2	17	0	2	17	0	0	7.0	
i 1	172.76622448979592	0.7575000000000001	77	198	5	5	2	17	0	1	17	0	0	7.0	
i 1	172.98233333333334	3.7875	74	584	5	3	16	16	0	1	16	0	0	3.4392260014518	
i 1	172.9859387755102	1.2625	74	198	6	3	3	17	0	1	17	0	0	3.4392260014518	
i 1	172.99603401360545	0.2525	72	900	6	1	1	1	0	-1	1	0	0	2.0	
i 1	173.00324489795918	2.02	74	198	6	5	8	16	0	2	16	0	0	7.0	
i 1	173.00396598639455	2.02	74	900	6	5	6	17	0	1	17	0	0	7.0	
i 1	173.2417074829932	0.2525	74	198	3	24	8	8	0	1	8	0	0	4.013049016299055	
i 1	173.48377551020408	0.2525	71	584	4	24	11	2	0	-2	2	0	0	4.013049016299055	
i 1	173.48521768707482	0.2525	71	900	4	20	7	2	0	-2	2	0	0	0.013049016299054639	
i 1	173.49387074829932	0.2525	74	198	6	9	8	16	0	2	16	0	0	2.4392260014518	
i 1	173.49819727891156	0.2525	71	900	4	20	11	8	0	-2	8	0	0	0.013049016299054639	
i 1	173.5111768707483	1.5150000000000001	74	198	1	20	1	2	0	1	2	0	0	0.013049016299054639	
i 1	173.51189795918367	0.2525	74	900	6	5	15	17	0	1	17	0	0	7.0	
i 1	173.5133401360544	0.2525	72	900	6	1	9	1	0	-1	1	0	0	2.0	
i 1	173.73738095238096	1.01	71	198	3	24	9	2	0	1	2	0	0	4.013049016299055	
i 1	173.74314965986395	1.01	74	198	4	20	6	2	0	1	2	0	0	0.013049016299054639	
i 1	173.76261904761904	0.2525	69	198	6	1	3	0	0	0	0	0	0	2.0	
i 1	173.9996394557823	0.505	77	584	6	5	3	17	0	2	17	0	0	7.0	
i 1	174.0082925170068	1.01	72	198	4	24	6	0	0	-1	0	0	0	3.0	
i 1	174.0111768707483	0.7575000000000001	74	198	6	9	9	16	0	2	16	0	0	2.4392260014518	
i 1	174.23233333333334	0.7575000000000001	69	584	4	24	11	0	0	0	0	0	0	3.0	
i 1	174.2582925170068	0.505	74	900	5	2	4	16	0	1	16	0	0	3.4392260014518	
i 1	174.4859387755102	2.2725	74	198	6	3	9	17	0	1	17	0	0	3.4392260014518	
i 1	174.4917074829932	3.0300000000000002	74	198	6	5	9	17	0	1	17	0	0	7.0	
i 1	174.50468707482995	3.2825	74	198	5	4	14	17	0	2	17	0	0	3.4392260014518	
i 1	174.50757142857142	3.0300000000000002	74	900	6	5	8	17	0	1	17	0	0	7.0	
i 1	174.5082925170068	0.7575000000000001	74	584	4	4	16	16	0	2	16	0	0	3.4392260014518	
i 1	174.50901360544216	0.7575000000000001	71	198	3	24	7	2	0	-2	2	0	0	4.013049016299055	
i 1	174.50973469387756	0.2525	72	900	6	1	5	1	0	-1	1	0	0	2.0	
i 1	174.51189795918367	0.2525	74	198	4	20	12	2	0	-2	2	0	0	0.013049016299054639	
i 1	174.74026530612244	0.2525	74	900	4	20	1	2	0	1	2	0	0	0.013049016299054639	
i 1	174.74098639455784	0.2525	72	900	6	1	4	1	0	-1	1	0	0	2.0	
i 1	174.74675510204082	0.2525	74	584	4	24	4	2	0	-2	2	0	0	4.013049016299055	
i 1	174.7611768707483	5.3025	74	198	4	20	7	2	0	1	2	0	0	0.013049016299054639	
i 1	174.99026530612244	0.2525	77	198	5	5	4	17	0	1	17	0	0	7.0	
i 1	174.9974761904762	0.2525	69	198	5	1	6	0	0	-1	0	0	0	2.0	
i 1	175.0082925170068	3.7875	71	198	4	20	11	2	0	-2	2	0	0	0.013049016299054639	
i 1	175.00901360544216	0.505	72	900	6	1	10	1	0	-1	1	0	0	2.0	
i 1	175.00901360544216	0.505	69	198	6	1	2	0	0	0	0	0	0	2.0	
i 1	175.0133401360544	0.2525	74	198	3	24	8	2	0	1	2	0	0	4.013049016299055	
i 1	175.25468707482995	3.7875	69	584	4	24	13	0	0	0	0	0	0	3.0	
i 1	175.25973469387756	3.0300000000000002	72	198	4	24	8	0	0	-1	0	0	0	3.0	
i 1	175.26261904761904	0.2525	77	198	5	5	2	17	0	1	17	0	0	7.0	
i 1	175.50180272108844	2.7775	74	198	1	20	6	2	0	1	2	0	0	0.013049016299054639	
i 1	175.5025238095238	0.2525	72	584	6	1	6	0	0	0	0	0	0	2.0	
i 1	175.50324489795918	3.2825	74	198	3	24	5	2	0	1	2	0	0	4.013049016299055	
i 1	175.74026530612244	0.2525	69	198	5	1	1	0	0	-1	0	0	0	2.0	
i 1	175.7417074829932	0.2525	77	198	5	5	12	17	0	1	17	0	0	7.0	
i 1	176.24026530612244	0.2525	72	198	6	1	3	1	0	-1	1	0	0	2.0	
i 1	176.26189795918367	1.5150000000000001	74	584	4	4	8	16	0	2	16	0	0	3.4392260014518	
i 1	176.48738095238096	0.2525	77	584	6	5	14	16	0	1	16	0	0	7.0	
i 1	176.49675510204082	1.01	72	900	6	1	9	1	0	-1	1	0	0	2.0	
i 1	176.75901360544216	0.7575000000000001	72	198	6	1	11	1	0	-1	1	0	0	2.0	
i 1	176.76766666666666	0.2525	74	900	5	2	16	17	0	1	17	0	0	3.4392260014518	
i 1	177.00685034013605	0.2525	74	198	6	3	8	17	0	1	17	0	0	3.4392260014518	
i 1	177.01622448979592	0.2525	77	198	5	5	15	17	0	1	17	0	0	7.0	
i 1	177.23449659863945	2.7775	77	198	5	5	3	17	0	1	17	0	0	7.0	
i 1	177.24675510204082	1.01	74	900	5	2	13	17	0	1	17	0	0	3.4392260014518	
i 1	177.25685034013605	0.7575000000000001	77	198	6	9	12	17	0	1	17	0	0	2.4392260014518	
i 1	177.26766666666666	2.7775	77	584	6	5	16	17	0	2	17	0	0	7.0	
i 1	177.48954421768707	0.505	74	198	6	3	4	17	0	1	17	0	0	3.4392260014518	
i 1	177.50540816326532	0.2525	74	198	6	5	4	16	0	2	16	0	0	7.0	
i 1	177.50973469387756	0.505	74	584	5	3	1	16	0	1	16	0	0	3.4392260014518	
i 1	177.75396598639455	0.505	74	900	5	2	12	16	0	1	16	0	0	3.4392260014518	
i 1	177.75685034013605	0.505	74	198	6	9	16	16	0	2	16	0	0	2.4392260014518	
i 1	177.99891836734693	0.2525	77	584	6	5	13	16	0	1	16	0	0	7.0	
i 1	178.23377551020408	0.2525	74	198	6	5	6	17	0	1	17	0	0	7.0	
i 1	178.2359387755102	0.7575000000000001	72	198	5	24	8	0	0	-1	0	0	0	3.0	
i 1	178.24026530612244	4.7975	63	198	4	27	14	1	0	2	1	0	0	1.780346323935208	
i 1	178.24098639455784	0.2525	69	198	7	1	6	0	0	0	0	0	0	2.0	
i 1	178.25108163265307	4.7975	63	584	5	15	9	16	0	1	16	0	0	3.2473156342679723	
i 1	178.25108163265307	0.7575000000000001	74	584	5	3	5	16	0	1	16	0	0	3.4392260014518	
i 1	178.25180272108844	0.7575000000000001	74	198	3	20	13	2	0	1	2	0	0	0.013049016299054639	
i 1	178.25396598639455	0.505	71	198	4	20	9	2	0	-2	2	0	0	0.013049016299054639	
i 1	178.25540816326532	0.7575000000000001	74	198	4	24	10	2	0	-2	2	0	0	4.013049016299055	
i 1	178.25901360544216	0.7575000000000001	74	198	6	3	11	17	0	1	17	0	0	3.4392260014518	
i 1	178.48377551020408	1.01	72	900	6	1	10	1	0	-1	1	0	0	2.0	
i 1	178.49531292517005	1.5150000000000001	74	198	5	4	1	17	0	2	17	0	0	3.4392260014518	
i 1	178.4974761904762	1.01	72	198	6	1	8	1	0	-1	1	0	0	2.0	
i 1	178.50901360544216	2.02	71	198	3	24	2	2	0	-2	2	0	0	4.013049016299055	
i 1	178.5169455782313	1.5150000000000001	74	584	4	4	16	16	0	2	16	0	0	3.4392260014518	
i 1	178.73449659863945	0.2525	71	584	4	24	14	2	0	-2	2	0	0	4.013049016299055	
i 1	178.75180272108844	0.505	74	900	4	20	12	8	0	1	8	0	0	0.013049016299054639	
i 1	178.75468707482995	0.505	71	900	4	20	11	2	0	1	2	0	0	0.013049016299054639	
i 1	178.99387074829932	1.2625	72	584	6	1	6	0	0	0	0	0	0	2.0	
i 1	179.01622448979592	1.2625	69	198	5	1	5	0	0	-1	0	0	0	2.0	
i 1	179.25180272108844	0.2525	71	198	4	20	2	2	0	1	2	0	0	0.013049016299054639	
i 1	179.2611768707483	0.505	74	198	4	20	7	2	0	-2	2	0	0	0.013049016299054639	
i 1	179.4830544217687	2.2725	74	198	6	5	10	17	0	1	17	0	0	7.0	
i 1	179.4888231292517	2.2725	74	900	6	5	11	17	0	1	17	0	0	7.0	
i 1	179.4888231292517	0.2525	71	198	3	24	3	8	0	-2	8	0	0	4.013049016299055	
i 1	179.49891836734693	2.7775	74	198	6	3	7	17	0	1	17	0	0	3.4392260014518	
i 1	179.50180272108844	2.7775	74	584	5	3	6	16	0	1	16	0	0	3.4392260014518	
i 1	179.50612925170068	1.7675	74	198	4	24	5	2	0	-2	2	0	0	4.013049016299055	
i 1	179.74675510204082	0.2525	72	900	6	1	13	1	0	-1	1	0	0	2.0	
i 1	179.75396598639455	0.505	74	584	4	24	8	8	0	-2	8	0	0	4.013049016299055	
i 1	179.75540816326532	0.505	74	900	4	20	4	2	0	1	2	0	0	0.013049016299054639	
i 1	179.98233333333334	0.2525	74	900	5	2	15	17	0	1	17	0	0	3.4392260014518	
i 1	179.9917074829932	0.2525	74	900	6	5	6	17	0	1	17	0	0	7.0	
i 1	179.99314965986395	3.0300000000000002	72	198	5	24	12	0	0	-1	0	0	0	3.0	
i 1	179.9996394557823	3.0300000000000002	69	584	4	24	14	0	0	0	0	0	0	3.0	
i 1	180.2388231292517	1.01	74	198	3	20	14	2	0	1	2	0	0	0.013049016299054639	
i 1	180.24314965986395	0.2525	77	584	6	5	10	16	0	1	16	0	0	7.0	
i 1	180.24675510204082	0.2525	69	198	7	1	11	0	0	0	0	0	0	2.0	
i 1	180.2496394557823	0.2525	74	198	4	20	2	2	0	1	2	0	0	0.013049016299054639	
i 1	180.25468707482995	0.7575000000000001	71	198	4	20	9	2	0	1	2	0	0	0.013049016299054639	
i 1	180.26045578231293	0.7575000000000001	74	198	3	24	6	2	0	-2	2	0	0	4.013049016299055	
i 1	180.4866598639456	0.505	71	198	1	24	9	2	0	252	2	307	0	4.013049016299055	
i 1	180.5025238095238	0.2525	72	900	6	1	14	1	0	-1	1	0	0	2.0	
i 1	180.50324489795918	0.2525	77	584	6	5	2	17	0	2	17	0	0	7.0	
i 1	180.73233333333334	1.01	74	198	5	4	3	17	0	2	17	0	0	3.4392260014518	
i 1	180.75612925170068	0.7575000000000001	74	584	4	4	16	16	0	2	16	0	0	3.4392260014518	
i 1	180.9866598639456	0.2525	74	900	4	20	16	8	0	1	8	0	0	0.013049016299054639	
i 1	180.9866598639456	0.2525	71	900	4	20	10	2	0	1	2	0	0	0.013049016299054639	
i 1	180.98738095238096	2.02	71	198	3	24	1	2	0	-2	2	0	0	4.013049016299055	
i 1	180.9888231292517	0.2525	71	584	4	24	7	8	0	-2	8	0	0	4.013049016299055	
i 1	180.99242857142858	0.505	77	198	6	9	9	17	0	1	17	0	0	2.4392260014518	
i 1	181.00612925170068	3.2825	74	198	4	20	13	2	0	1	2	0	0	0.013049016299054639	
i 1	181.0169455782313	0.505	74	900	5	2	5	17	0	1	17	0	0	3.4392260014518	
i 1	181.23233333333334	1.7675	77	198	5	5	12	17	0	1	17	0	0	7.0	
i 1	181.23521768707482	0.2525	69	198	7	1	1	0	0	0	0	0	0	2.0	
i 1	181.24314965986395	1.2625	74	198	1	24	9	2	0	248	2	308	0	4.013049016299055	
i 1	181.24675510204082	0.2525	71	198	4	20	8	2	0	-2	2	0	0	0.013049016299054639	
i 1	181.25540816326532	1.7675	77	584	6	5	3	17	0	2	17	0	0	7.0	
i 1	181.25612925170068	2.2725	71	198	4	20	9	2	0	-2	2	0	0	0.013049016299054639	
i 1	181.51622448979592	1.5150000000000001	74	198	3	20	2	2	0	-2	2	0	0	0.013049016299054639	
i 1	181.7388231292517	1.5150000000000001	74	198	6	9	10	16	0	2	16	0	0	2.4392260014518	
i 1	181.74891836734693	1.2625	74	900	5	2	5	16	0	1	16	0	0	3.4392260014518	
i 1	181.75324489795918	0.505	74	198	7	5	14	16	0	2	16	0	0	7.0	
i 1	181.75540816326532	0.7575000000000001	72	900	6	1	5	1	0	-1	1	0	0	2.0	
i 1	181.75973469387756	0.7575000000000001	69	198	7	1	3	0	0	0	0	0	0	2.0	
i 1	182.48377551020408	0.2525	77	584	6	5	3	16	0	1	16	0	0	7.0	
i 1	182.48738095238096	1.7675	74	198	4	24	13	2	0	-2	2	0	0	4.013049016299055	
i 1	182.48954421768707	1.5150000000000001	77	198	6	9	4	17	0	1	17	0	0	2.4392260014518	
i 1	182.5003605442177	1.01	71	198	4	20	10	2	0	-2	2	0	0	0.013049016299054639	
i 1	182.7330544217687	0.2525	74	900	6	5	12	17	0	1	17	0	0	7.0	
i 1	182.75180272108844	0.2525	74	584	4	4	7	16	0	2	16	0	0	3.4392260014518	
i 1	182.75468707482995	0.2525	77	198	5	5	7	17	0	1	17	0	0	7.0	
i 1	182.9830544217687	14.645	61	1082	5	25	16	16	0	1	16	0	0	1.0137921208505258	
i 1	182.98377551020408	15.9075	63	696	5	15	13	16	5000	1	16	0	0	3.2473156342679723	
i 1	182.98954421768707	14.645	63	1082	5	25	14	1	0	2	1	0	0	1.0137921208505258	
i 1	182.99098639455784	0.2525	72	198	6	1	9	1	0	-1	1	0	0	2.0	
i 1	182.99531292517005	1.01	77	696	4	4	9	16	5000	1	16	0	0	3.4392260014518	
i 1	182.99531292517005	0.505	74	696	5	5	5	17	0	1	17	0	0	7.0	
i 1	182.99603401360545	0.7575000000000001	72	696	4	24	7	0	5000	0	0	0	0	3.0	
i 1	182.99675510204082	1.01	63	696	5	15	11	1	5000	2	1	0	0	3.2473156342679723	
i 1	182.99675510204082	14.645	61	696	4	12	10	16	0	2	16	0	0	3.7112178677348253	
i 1	182.9974761904762	0.7575000000000001	69	198	7	1	11	0	0	0	0	0	0	2.0	
i 1	182.99819727891156	15.9075	61	696	5	25	11	1	5000	2	1	0	0	1.0137921208505258	
i 1	182.9996394557823	14.645	61	1082	5	13	6	16	0	2	16	0	0	2.783413400801119	
i 1	183.0003605442177	14.645	63	696	4	12	14	16	0	2	16	0	0	3.7112178677348253	
i 1	183.00180272108844	2.525	74	696	5	5	3	17	0	2	17	0	0	7.0	
i 1	183.0025238095238	14.645	61	696	3	27	11	16	0	2	16	0	0	1.780346323935208	
i 1	183.00396598639455	14.645	63	1082	5	14	6	1	0	1	1	0	0	4.175120101201679	
i 1	183.00468707482995	2.525	74	1082	6	5	1	16	0	1	16	0	0	7.0	
i 1	183.00612925170068	15.9075	63	696	5	25	14	16	5000	1	16	0	0	1.0137921208505258	
i 1	183.01766666666666	0.2525	74	1082	5	2	8	16	0	2	16	0	0	3.4392260014518	
i 1	183.01766666666666	14.645	61	696	3	27	9	1	0	1	1	0	0	1.780346323935208	
i 1	183.25612925170068	1.01	69	1082	6	1	14	0	0	0	0	0	0	2.0	
i 1	183.2640612244898	1.01	69	696	5	1	7	0	0	0	0	0	0	2.0	
i 1	183.50396598639455	0.2525	74	1082	5	2	5	16	0	1	16	0	0	3.4392260014518	
i 1	183.5111768707483	0.7575000000000001	71	1082	4	20	2	2	0	1	2	0	0	0.013049016299054639	
i 1	183.51261904761904	0.505	71	1082	4	20	5	2	0	1	2	0	0	0.013049016299054639	
i 1	183.9866598639456	14.8975	63	696	5	15	13	1	5000	2	1	0	0	3.2473156342679723	
i 1	184.00324489795918	0.2525	71	1082	3	20	6	2	0	1	2	0	0	0.013049016299054639	
i 1	184.00612925170068	0.7575000000000001	77	696	5	3	1	17	5000	1	17	0	0	3.4392260014518	
i 1	184.00612925170068	0.7575000000000001	77	696	4	4	3	17	0	2	17	0	0	3.4392260014518	
i 1	184.2359387755102	1.7675	69	696	4	24	15	1	0	0	1	0	0	3.0	
i 1	184.2359387755102	0.2525	74	198	4	20	13	2	0	-2	2	0	0	0.013049016299054639	
i 1	184.24242857142858	1.2625	74	1082	5	2	15	16	0	1	16	0	0	3.4392260014518	
i 1	184.24531292517005	1.7675	72	696	6	1	14	1	5000	0	1	0	0	2.0	
i 1	184.25108163265307	0.505	74	696	3	24	2	8	0	1	8	0	0	4.013049016299055	
i 1	184.25468707482995	0.2525	71	198	3	20	1	2	0	-2	2	0	0	0.013049016299054639	
i 1	184.49675510204082	0.7575000000000001	74	198	6	9	7	16	0	2	16	0	0	2.4392260014518	
i 1	184.49675510204082	0.505	74	198	4	24	5	2	0	-2	2	0	0	4.013049016299055	
i 1	184.5111768707483	1.5150000000000001	74	198	4	20	7	2	0	1	2	0	0	0.013049016299054639	
i 1	184.5169455782313	0.2525	74	1082	3	20	4	8	0	-2	8	0	0	0.013049016299054639	
i 1	184.7330544217687	0.2525	74	198	4	20	13	2	0	1	2	0	0	0.013049016299054639	
i 1	184.73954421768707	0.7575000000000001	71	198	3	20	2	8	0	1	8	0	0	0.013049016299054639	
i 1	184.7582925170068	0.2525	74	696	6	5	7	17	5000	1	17	0	0	7.0	
i 1	184.99098639455784	0.2525	69	198	7	1	12	0	0	0	0	0	0	2.0	
i 1	185.0082925170068	0.2525	74	198	7	5	1	17	0	1	17	0	0	7.0	
i 1	185.25468707482995	1.01	77	696	4	4	4	17	0	2	17	0	0	3.4392260014518	
i 1	185.25540816326532	1.01	77	696	5	3	9	17	5000	1	17	0	0	3.4392260014518	
i 1	185.25685034013605	0.7575000000000001	74	198	4	24	14	2	0	-2	2	0	0	4.013049016299055	
i 1	185.4888231292517	1.2625	74	696	3	24	7	8	0	1	8	0	0	4.013049016299055	
i 1	185.49026530612244	1.2625	74	198	7	5	9	16	0	2	16	0	0	7.0	
i 1	185.49531292517005	0.2525	74	696	5	5	10	17	0	1	17	0	0	7.0	
i 1	185.5140612244898	1.2625	74	696	6	5	1	17	5000	1	17	0	0	7.0	
i 1	185.51622448979592	0.2525	71	1082	3	20	14	2	0	-2	2	0	0	0.013049016299054639	
i 1	185.51622448979592	0.2525	74	1082	4	20	5	2	0	1	2	0	0	0.013049016299054639	
i 1	185.7366598639456	0.2525	77	696	4	4	8	16	5000	1	16	0	0	3.4392260014518	
i 1	185.75468707482995	0.2525	69	1082	6	1	8	0	0	0	0	0	0	2.0	
i 1	185.7669455782313	0.2525	74	198	3	20	4	2	0	-2	2	0	0	0.013049016299054639	
i 1	185.7669455782313	0.7575000000000001	74	198	4	20	4	2	0	1	2	0	0	0.013049016299054639	
i 1	185.99098639455784	0.505	72	696	4	24	11	0	5000	0	0	0	0	3.0	
i 1	186.0025238095238	1.5150000000000001	74	1082	5	2	6	16	0	2	16	0	0	3.4392260014518	
i 1	186.01478231292518	0.505	69	198	7	1	3	0	0	0	0	0	0	2.0	
i 1	186.01766666666666	1.7675	77	696	5	3	6	16	0	2	16	0	0	3.4392260014518	
i 1	186.24603401360545	0.2525	71	696	3	20	12	2	0	-2	2	0	0	0.013049016299054639	
i 1	186.25757142857142	1.7675	72	198	7	1	15	1	0	-1	1	0	0	2.0	
i 1	186.49531292517005	0.2525	69	1082	6	1	5	0	0	0	0	0	0	2.0	
i 1	186.5003605442177	0.2525	71	1082	4	20	11	2	0	-2	2	0	0	0.013049016299054639	
i 1	186.50108163265307	0.2525	74	1082	3	20	10	2	0	1	2	0	0	0.013049016299054639	
i 1	186.5082925170068	1.5150000000000001	69	1082	6	1	5	0	0	-1	0	0	0	2.0	
i 1	186.51045578231293	2.02	74	198	4	20	3	2	0	1	2	0	0	0.013049016299054639	
i 1	186.5133401360544	0.2525	74	1082	6	5	7	17	0	2	17	0	0	7.0	
i 1	186.51550340136055	0.505	74	198	4	24	4	2	0	-2	2	0	0	4.013049016299055	
i 1	186.7366598639456	3.0300000000000002	74	1082	6	5	7	16	0	1	16	0	0	7.0	
i 1	186.73810204081633	0.2525	77	198	6	9	5	17	0	1	17	0	0	2.4392260014518	
i 1	186.7417074829932	0.2525	74	198	7	5	8	17	0	1	17	0	0	7.0	
i 1	186.74603401360545	1.2625	71	198	3	20	2	2	0	1	2	0	0	0.013049016299054639	
i 1	186.7474761904762	3.0300000000000002	74	696	5	5	7	17	0	2	17	0	0	7.0	
i 1	186.75324489795918	0.2525	72	696	4	24	5	0	5000	0	0	0	0	3.0	
i 1	186.76550340136055	0.505	74	198	4	20	14	2	0	-2	2	0	0	0.013049016299054639	
i 1	187.23521768707482	0.2525	77	696	4	4	10	17	0	2	17	0	0	3.4392260014518	
i 1	187.23738095238096	0.2525	72	696	6	1	6	1	5000	0	1	0	0	2.0	
i 1	187.25612925170068	0.7575000000000001	77	198	6	9	14	17	0	1	17	0	0	2.4392260014518	
i 1	187.25685034013605	0.7575000000000001	77	696	4	4	9	16	5000	1	16	0	0	3.4392260014518	
i 1	187.2582925170068	0.2525	77	696	5	3	7	17	5000	1	17	0	0	3.4392260014518	
i 1	187.50108163265307	0.2525	74	696	6	5	4	17	5000	1	17	0	0	7.0	
i 1	187.50685034013605	0.505	74	198	4	20	16	2	0	-2	2	0	0	0.013049016299054639	
i 1	187.7359387755102	1.2625	74	198	4	24	8	2	0	-2	2	0	0	4.013049016299055	
i 1	187.74026530612244	0.7575000000000001	72	696	4	24	12	0	5000	0	0	0	0	3.0	
i 1	187.75180272108844	1.7675	77	696	5	3	7	17	5000	1	17	0	0	3.4392260014518	
i 1	187.7582925170068	1.7675	77	696	4	4	12	17	0	2	17	0	0	3.4392260014518	
i 1	187.75973469387756	0.7575000000000001	69	198	7	1	8	0	0	0	0	0	0	2.0	
i 1	188.00540816326532	0.2525	74	1082	3	20	10	8	0	1	8	0	0	0.013049016299054639	
i 1	188.00540816326532	0.2525	74	1082	4	20	16	2	0	-2	2	0	0	0.013049016299054639	
i 1	188.00685034013605	0.2525	74	1082	5	2	6	16	0	2	16	0	0	3.4392260014518	
i 1	188.2330544217687	0.2525	74	198	3	20	9	2	0	-2	2	0	0	0.013049016299054639	
i 1	188.24675510204082	1.01	69	1082	6	1	2	0	0	0	0	0	0	2.0	
i 1	188.25108163265307	1.01	69	696	5	1	3	0	0	0	0	0	0	2.0	
i 1	188.2611768707483	0.505	71	198	4	20	13	2	0	1	2	0	0	0.013049016299054639	
i 1	188.2669455782313	0.505	74	696	3	24	6	8	0	1	8	0	0	4.013049016299055	
i 1	188.49242857142858	0.505	74	696	3	24	5	8	5000	-2	8	0	0	4.013049016299055	
i 1	188.75540816326532	0.2525	74	696	5	5	5	17	0	1	17	0	0	7.0	
i 1	188.9830544217687	0.2525	71	696	4	20	15	2	5000	1	2	0	0	0.013049016299054639	
i 1	189.00324489795918	0.2525	74	696	6	5	1	17	5000	1	17	0	0	7.0	
i 1	189.00468707482995	0.505	71	696	3	20	5	2	0	-2	2	0	0	0.013049016299054639	
i 1	189.00973469387756	0.2525	74	696	4	24	15	8	5000	-2	8	0	0	4.013049016299055	
i 1	189.01045578231293	0.2525	74	1082	5	2	13	16	0	2	16	0	0	3.4392260014518	
i 1	189.23377551020408	0.505	69	198	7	1	3	0	0	0	0	0	0	2.0	
i 1	189.23377551020408	0.2525	69	696	4	24	7	1	0	0	1	0	0	3.0	
i 1	189.24675510204082	1.2625	74	198	6	9	8	16	0	2	16	0	0	2.4392260014518	
i 1	189.24819727891156	0.505	72	696	4	24	12	0	5000	0	0	0	0	3.0	
i 1	189.25108163265307	1.5150000000000001	74	696	3	24	11	8	5000	-2	8	0	0	4.013049016299055	
i 1	189.2582925170068	1.5150000000000001	74	198	4	24	11	2	0	-2	2	0	0	4.013049016299055	
i 1	189.2640612244898	1.2625	74	1082	5	2	11	16	0	1	16	0	0	3.4392260014518	
i 1	189.4996394557823	0.505	74	696	5	5	13	17	0	1	17	0	0	7.0	
i 1	189.50108163265307	0.2525	69	696	5	1	10	0	0	0	0	0	0	2.0	
i 1	189.51766666666666	1.5150000000000001	69	1082	6	1	10	0	0	0	0	0	0	2.0	
i 1	189.7330544217687	7.8275	61	198	5	16	3	16	0	2	16	0	0	3.7112178677348253	
i 1	189.73738095238096	1.2625	69	696	6	1	11	0	0	0	0	0	0	2.0	
i 1	189.74459183673468	1.2625	74	198	7	5	6	16	0	2	16	0	0	7.0	
i 1	189.7525238095238	1.2625	74	696	6	5	3	17	5000	1	17	0	0	7.0	
i 1	189.99891836734693	0.2525	74	1082	5	2	16	16	0	2	16	0	0	3.4392260014518	
i 1	190.4830544217687	0.2525	77	696	4	4	4	17	0	2	17	0	0	3.4392260014518	
i 1	190.48377551020408	0.2525	77	696	4	4	12	16	5000	1	16	0	0	3.4392260014518	
i 1	190.48810204081633	0.2525	77	696	5	3	11	17	5000	1	17	0	0	3.4392260014518	
i 1	190.4917074829932	0.2525	72	198	7	1	1	1	0	-1	1	0	0	2.0	
i 1	190.73738095238096	0.505	71	696	3	20	12	2	0	-2	2	0	0	0.013049016299054639	
i 1	190.74026530612244	0.2525	69	1082	6	1	16	0	0	-1	0	0	0	2.0	
i 1	190.74026530612244	0.2525	74	1082	5	2	15	16	0	2	16	0	0	3.4392260014518	
i 1	190.74675510204082	0.505	74	696	4	24	15	8	5000	-2	8	0	0	4.013049016299055	
i 1	190.75180272108844	0.2525	77	696	5	3	1	16	0	2	16	0	0	3.4392260014518	
i 1	190.9830544217687	2.02	69	696	4	24	11	1	0	0	1	0	0	3.0	
i 1	190.98521768707482	1.2625	74	198	7	5	13	17	0	1	17	0	0	7.0	
i 1	190.99387074829932	2.02	72	696	6	1	7	1	5000	0	1	0	0	2.0	
i 1	191.01261904761904	0.2525	77	696	4	4	15	17	0	2	17	0	0	3.4392260014518	
i 1	191.01478231292518	0.2525	77	696	5	3	2	17	5000	1	17	0	0	3.4392260014518	
i 1	191.0169455782313	1.2625	74	1082	6	5	16	17	0	2	17	0	0	7.0	
i 1	191.24675510204082	0.2525	74	696	3	24	13	8	5000	-2	8	0	0	4.013049016299055	
i 1	191.26045578231293	0.505	77	198	5	9	13	17	0	1	17	0	0	2.4392260014518	
i 1	191.26261904761904	0.505	77	696	4	4	7	16	5000	1	16	0	0	3.4392260014518	
i 1	191.26550340136055	0.2525	74	198	4	24	16	2	0	-2	2	0	0	4.013049016299055	
i 1	191.50180272108844	0.2525	74	1082	5	2	12	16	0	1	16	0	0	3.4392260014518	
i 1	191.50396598639455	0.505	71	198	3	20	2	2	0	1	2	0	0	0.013049016299054639	
i 1	191.50901360544216	0.505	74	696	3	24	7	8	0	1	8	0	0	4.013049016299055	
i 1	191.74603401360545	2.2725	77	696	4	4	10	17	0	2	17	0	0	3.4392260014518	
i 1	191.75612925170068	2.2725	77	696	5	3	6	17	5000	1	17	0	0	3.4392260014518	
i 1	191.98233333333334	0.2525	74	696	3	24	10	8	5000	-2	8	0	0	4.013049016299055	
i 1	191.98954421768707	0.2525	74	198	4	24	11	2	0	-2	2	0	0	4.013049016299055	
i 1	191.99819727891156	1.5150000000000001	74	1082	6	5	7	16	0	1	16	0	0	7.0	
i 1	191.99819727891156	1.5150000000000001	74	696	6	5	12	17	0	2	17	0	0	7.0	
i 1	192.23738095238096	0.2525	74	696	4	24	9	8	5000	-2	8	0	0	4.013049016299055	
i 1	192.2417074829932	0.2525	77	198	5	9	8	17	0	1	17	0	0	2.4392260014518	
i 1	192.2474761904762	0.2525	71	696	3	20	6	2	0	-2	2	0	0	0.013049016299054639	
i 1	192.26189795918367	0.2525	69	696	6	1	16	0	0	0	0	0	0	2.0	
i 1	192.4917074829932	1.7675	74	696	3	24	8	8	5000	-2	8	0	0	4.013049016299055	
i 1	192.51189795918367	0.2525	71	696	3	20	13	2	5000	1	2	0	0	0.013049016299054639	
i 1	192.51189795918367	1.7675	74	198	4	24	14	2	0	-2	2	0	0	4.013049016299055	
i 1	192.74819727891156	0.505	74	1082	5	2	16	16	0	2	16	0	0	3.4392260014518	
i 1	192.99459183673468	0.505	72	696	4	24	15	0	5000	0	0	0	0	3.0	
i 1	192.99891836734693	0.505	69	198	7	1	11	0	0	0	0	0	0	2.0	
i 1	193.25108163265307	2.2725	74	198	7	5	2	16	0	2	16	0	0	7.0	
i 1	193.2611768707483	3.2825	74	696	6	5	9	17	5000	1	17	0	0	7.0	
i 1	193.4888231292517	0.7575000000000001	69	1082	6	1	5	0	0	-1	0	0	0	2.0	
i 1	193.5025238095238	0.7575000000000001	72	198	7	1	13	1	0	-1	1	0	0	2.0	
i 1	193.5111768707483	0.2525	74	1082	5	2	5	16	0	2	16	0	0	3.4392260014518	
i 1	193.74026530612244	0.2525	74	1082	6	5	8	17	0	2	17	0	0	7.0	
i 1	193.98233333333334	1.5150000000000001	74	696	3	24	13	8	0	1	8	0	0	4.013049016299055	
i 1	193.98377551020408	0.7575000000000001	74	198	3	20	16	2	0	-2	2	0	0	0.013049016299054639	
i 1	193.98810204081633	0.2525	74	1082	5	2	9	16	0	1	16	0	0	3.4392260014518	
i 1	194.01550340136055	0.2525	74	198	6	9	5	16	0	2	16	0	0	2.4392260014518	
i 1	194.2330544217687	0.2525	72	696	4	24	15	0	5000	0	0	0	0	3.0	
i 1	194.23449659863945	0.2525	77	696	4	4	12	17	0	2	17	0	0	3.4392260014518	
i 1	194.24603401360545	0.2525	77	696	5	3	1	17	5000	1	17	0	0	3.4392260014518	
i 1	194.25973469387756	0.2525	74	696	6	5	14	17	0	2	17	0	0	7.0	
i 1	194.2611768707483	0.2525	69	198	7	1	9	0	0	0	0	0	0	2.0	
i 1	194.5003605442177	1.2625	74	198	4	20	8	2	0	1	2	0	0	0.013049016299054639	
i 1	194.50180272108844	0.505	74	1082	5	2	6	16	0	2	16	0	0	3.4392260014518	
i 1	194.5025238095238	0.505	77	696	5	3	11	16	0	2	16	0	0	3.4392260014518	
i 1	194.50685034013605	1.5150000000000001	69	1082	6	1	1	0	0	0	0	0	0	2.0	
i 1	194.50757142857142	1.5150000000000001	69	696	6	1	8	0	0	0	0	0	0	2.0	
i 1	194.74531292517005	0.2525	71	1082	4	20	2	2	0	1	2	0	0	0.013049016299054639	
i 1	194.7474761904762	0.2525	71	1082	3	20	1	2	0	-2	2	0	0	0.013049016299054639	
i 1	194.74819727891156	1.2625	77	696	4	4	6	17	0	2	17	0	0	3.4392260014518	
i 1	195.00685034013605	0.505	71	198	3	20	16	2	0	1	2	0	0	0.013049016299054639	
i 1	195.01045578231293	0.2525	74	1082	5	2	7	16	0	1	16	0	0	3.4392260014518	
i 1	195.0133401360544	0.505	71	198	4	20	12	2	0	-2	2	0	0	0.013049016299054639	
i 1	195.01766666666666	1.01	77	696	5	3	5	17	5000	1	17	0	0	3.4392260014518	
i 1	195.2503605442177	0.2525	74	696	6	5	14	17	5000	1	17	0	0	7.0	
i 1	195.25757142857142	0.505	74	198	4	24	13	2	0	-2	2	0	0	4.013049016299055	
i 1	195.4917074829932	2.02	61	198	5	16	15	16	0	1	16	0	0	3.7112178677348253	
i 1	195.5025238095238	1.01	74	198	7	5	9	16	0	2	16	0	0	7.0	
i 1	195.51550340136055	0.2525	71	1082	4	20	8	2	0	1	2	0	0	0.013049016299054639	
i 1	195.51766666666666	0.2525	71	1082	4	20	14	8	0	1	8	0	0	0.013049016299054639	
i 1	195.7330544217687	1.01	74	696	3	24	4	8	0	1	8	0	0	4.013049016299055	
i 1	195.74314965986395	1.01	74	198	4	20	11	8	0	-2	8	0	0	0.013049016299054639	
i 1	195.98377551020408	1.01	77	696	4	4	9	16	5000	1	16	0	0	3.4392260014518	
i 1	195.9917074829932	0.505	69	198	7	1	10	0	0	0	0	0	0	2.0	
i 1	196.00468707482995	0.505	72	696	4	24	13	0	5000	0	0	0	0	3.0	
i 1	196.00540816326532	1.01	77	198	5	9	12	17	0	1	17	0	0	2.4392260014518	
i 1	196.4859387755102	1.01	74	1082	6	5	12	16	0	1	16	0	0	7.0	
i 1	196.4917074829932	1.01	74	696	6	5	15	17	0	2	17	0	0	7.0	
i 1	196.50685034013605	1.01	69	1082	6	1	10	0	0	0	0	0	0	2.0	
i 1	196.5111768707483	1.01	69	696	6	1	13	0	0	0	0	0	0	2.0	
i 1	196.7496394557823	0.2525	74	198	4	24	14	2	0	-2	2	0	0	4.013049016299055	
i 1	196.7496394557823	0.7575000000000001	74	198	4	20	8	2	0	1	2	0	0	0.013049016299054639	
i 1	196.76189795918367	0.2525	71	1082	4	20	15	8	0	1	8	0	0	0.013049016299054639	
i 1	196.76766666666666	0.2525	71	1082	4	20	12	2	0	-2	2	0	0	0.013049016299054639	
i 1	196.98810204081633	0.505	77	696	4	4	7	17	0	2	17	0	0	3.4392260014518	
i 1	196.99675510204082	0.2525	71	198	4	20	14	2	0	-2	2	0	0	0.013049016299054639	
i 1	197.01261904761904	0.505	77	696	5	3	8	17	5000	1	17	0	0	3.4392260014518	
i 1	197.48233333333334	9.595	61	8	6	13	5	1	0	1	1	0	0	2.783413400801119	
i 1	197.48233333333334	31.5625	61	394	4	26	12	16	0	2	16	0	0	1.0137921208505258	
i 1	197.48521768707482	3.7875	63	8	6	14	2	16	0	2	16	0	0	4.175120101201679	
i 1	197.48810204081633	1.2625	77	8	6	5	1	16	0	1	16	0	0	7.0	
i 1	197.49459183673468	15.4025	61	8	6	25	8	1	0	2	1	0	0	1.0137921208505258	
i 1	197.49531292517005	31.5625	61	8	4	27	8	1	0	1	1	0	0	1.780346323935208	
i 1	197.4996394557823	0.505	72	696	6	1	1	1	5000	0	1	0	0	2.0	
i 1	197.50180272108844	0.2525	74	8	6	2	5	16	0	2	16	0	0	3.4392260014518	
i 1	197.5025238095238	31.5625	63	394	4	26	16	1	0	1	1	0	0	1.0137921208505258	
i 1	197.50324489795918	9.595	61	8	4	12	5	1	0	1	1	0	0	3.7112178677348253	
i 1	197.50324489795918	1.2625	74	696	6	5	13	17	5000	1	17	0	0	7.0	
i 1	197.50685034013605	27.017500000000002	61	394	4	16	3	1	0	2	1	0	0	3.7112178677348253	
i 1	197.50685034013605	0.2525	77	394	5	9	11	17	0	2	17	0	0	2.4392260014518	
i 1	197.50757142857142	0.505	69	8	7	1	5	0	0	0	0	0	0	2.0	
i 1	197.50757142857142	9.595	61	8	6	25	8	16	0	1	16	0	0	1.0137921208505258	
i 1	197.51622448979592	31.5625	61	394	4	16	5	1	0	1	1	0	0	3.7112178677348253	
i 1	197.5169455782313	3.7875	63	8	4	12	6	16	0	1	16	0	0	3.7112178677348253	
i 1	197.5169455782313	31.5625	61	8	4	27	7	16	0	2	16	0	0	1.780346323935208	
i 1	197.74675510204082	1.5150000000000001	71	394	4	20	13	8	0	1	8	0	0	0.013049016299054639	
i 1	197.75108163265307	0.505	77	8	6	3	3	17	0	1	17	0	0	3.4392260014518	
i 1	197.75180272108844	0.505	77	696	5	3	13	17	5000	1	17	0	0	3.4392260014518	
i 1	197.76478231292518	0.2525	74	8	4	20	4	8	0	1	8	0	0	0.013049016299054639	
i 1	197.7669455782313	0.2525	71	8	4	20	4	2	0	1	2	0	0	0.013049016299054639	
i 1	197.76766666666666	0.2525	74	394	4	24	9	2	0	-2	2	0	0	4.013049016299055	
i 1	197.98738095238096	1.01	71	394	4	20	11	8	0	1	8	0	0	0.013049016299054639	
i 1	197.9888231292517	0.7575000000000001	69	8	5	24	14	1	0	-1	1	0	0	3.0	
i 1	198.01189795918367	1.01	71	394	4	20	3	2	0	-2	2	0	0	0.013049016299054639	
i 1	198.0140612244898	0.7575000000000001	72	696	4	24	2	0	5000	0	0	0	0	3.0	
i 1	198.01478231292518	1.01	74	8	3	24	2	2	0	-2	2	0	0	4.013049016299055	
i 1	198.24603401360545	0.505	77	8	6	2	9	16	0	1	16	0	0	3.4392260014518	
i 1	198.2525238095238	0.505	77	394	5	9	9	16	0	2	16	0	0	2.4392260014518	
i 1	198.7330544217687	19.9475	63	892	5	25	6	1	0	2	1	0	0	1.0137921208505258	
i 1	198.74026530612244	0.505	72	394	6	1	14	1	0	-1	1	0	0	2.0	
i 1	198.74026530612244	1.2625	74	8	6	5	7	16	0	2	16	0	0	7.0	
i 1	198.7417074829932	19.9475	61	892	5	15	11	1	0	1	1	0	0	3.2473156342679723	
i 1	198.74675510204082	0.505	69	892	4	24	5	0	0	-1	0	0	0	3.0	
i 1	198.75757142857142	0.7575000000000001	77	394	5	9	11	17	0	2	17	0	0	2.4392260014518	
i 1	198.76045578231293	14.14	61	892	5	15	10	1	0	1	1	0	0	3.2473156342679723	
i 1	198.76261904761904	0.7575000000000001	77	892	4	4	4	17	0	1	17	0	0	3.4392260014518	
i 1	198.76261904761904	25.755	61	892	5	25	4	1	0	2	1	0	0	1.0137921208505258	
i 1	198.76766666666666	1.2625	77	8	7	5	13	16	0	1	16	0	0	7.0	
i 1	199.00973469387756	0.2525	71	8	4	20	13	2	0	-2	2	0	0	0.013049016299054639	
i 1	199.2474761904762	1.5150000000000001	72	8	7	1	2	0	0	0	0	0	0	2.0	
i 1	199.2503605442177	0.7575000000000001	74	8	3	24	10	2	0	-2	2	0	0	4.013049016299055	
i 1	199.25540816326532	1.5150000000000001	69	8	7	1	6	0	0	0	0	0	0	2.0	
i 1	199.25612925170068	0.7575000000000001	74	394	4	20	7	2	0	1	2	0	0	0.013049016299054639	
i 1	199.49603401360545	0.7575000000000001	77	892	5	3	4	16	0	2	16	0	0	3.4392260014518	
i 1	199.5082925170068	0.7575000000000001	77	8	5	4	16	16	0	1	16	0	0	3.4392260014518	
i 1	199.98377551020408	0.2525	74	8	4	20	15	8	0	-2	8	0	0	0.013049016299054639	
i 1	199.99387074829932	1.2625	74	8	7	5	8	17	0	2	17	0	0	7.0	
i 1	199.9996394557823	1.2625	77	394	6	5	13	17	0	1	17	0	0	7.0	
i 1	200.00396598639455	0.505	71	394	4	20	14	8	0	1	8	0	0	0.013049016299054639	
i 1	200.01045578231293	0.2525	74	8	4	20	8	8	0	1	8	0	0	0.013049016299054639	
i 1	200.01045578231293	0.2525	74	394	4	24	3	2	0	-2	2	0	0	4.013049016299055	
i 1	200.2330544217687	0.2525	74	8	3	24	15	2	0	-2	2	0	0	4.013049016299055	
i 1	200.2503605442177	0.505	77	394	5	9	9	16	0	2	16	0	0	2.4392260014518	
i 1	200.25468707482995	0.2525	74	394	4	20	15	8	0	1	8	0	0	0.013049016299054639	
i 1	200.25973469387756	0.505	74	8	6	2	4	16	0	2	16	0	0	3.4392260014518	
i 1	200.26261904761904	0.2525	74	394	4	20	16	2	0	-2	2	0	0	0.013049016299054639	
i 1	200.4830544217687	0.7575000000000001	74	8	3	24	13	2	0	1	2	0	0	4.013049016299055	
i 1	200.49387074829932	0.7575000000000001	74	394	4	24	3	2	0	-2	2	0	0	4.013049016299055	
i 1	200.73521768707482	0.505	72	394	6	1	11	1	0	-1	1	0	0	2.0	
i 1	200.7366598639456	1.01	77	892	5	3	8	16	0	2	16	0	0	3.4392260014518	
i 1	200.7388231292517	0.505	69	892	4	24	11	0	0	-1	0	0	0	3.0	
i 1	200.74314965986395	1.01	77	8	5	4	8	16	0	1	16	0	0	3.4392260014518	
i 1	201.23233333333334	27.775	63	8	6	14	6	16	0	2	16	0	0	4.175120101201679	
i 1	201.23377551020408	0.2525	74	8	6	5	11	17	0	2	17	0	0	7.0	
i 1	201.23954421768707	27.775	63	8	5	12	4	16	0	1	16	0	0	3.7112178677348253	
i 1	201.24387074829932	1.5150000000000001	69	8	7	1	13	0	0	0	0	0	0	2.0	
i 1	201.2496394557823	0.2525	77	394	6	5	16	17	0	1	17	0	0	7.0	
i 1	201.25396598639455	1.7675	74	8	3	20	16	8	0	1	8	0	0	0.013049016299054639	
i 1	201.25468707482995	0.2525	74	892	3	24	9	2	0	1	2	0	0	4.013049016299055	
i 1	201.26189795918367	1.5150000000000001	72	8	7	1	12	0	0	0	0	0	0	2.0	
i 1	201.48954421768707	1.5150000000000001	74	892	6	5	2	16	0	2	16	0	0	7.0	
i 1	201.49459183673468	1.5150000000000001	74	394	4	24	9	2	0	-2	2	0	0	4.013049016299055	
i 1	201.51189795918367	1.5150000000000001	77	394	6	5	13	16	0	2	16	0	0	7.0	
i 1	201.5133401360544	1.5150000000000001	71	8	3	20	10	2	0	1	2	0	0	0.013049016299054639	
i 1	201.5169455782313	1.5150000000000001	74	8	2	24	5	2	0	1	2	0	0	4.013049016299055	
i 1	201.73954421768707	0.7575000000000001	77	8	4	3	12	17	0	1	17	0	0	3.4392260014518	
i 1	201.75973469387756	0.7575000000000001	77	8	6	2	5	16	0	1	16	0	0	3.4392260014518	
i 1	202.50180272108844	0.2525	77	8	5	4	1	16	0	1	16	0	0	3.4392260014518	
i 1	202.5082925170068	0.2525	77	892	5	3	1	16	0	2	16	0	0	3.4392260014518	
i 1	202.7359387755102	0.2525	77	394	5	9	2	17	0	2	17	0	0	2.4392260014518	
i 1	202.7388231292517	0.2525	77	892	4	4	10	17	0	1	17	0	0	3.4392260014518	
i 1	202.7503605442177	1.2625	69	892	6	1	4	0	0	-1	0	0	0	2.0	
i 1	202.7633401360544	1.2625	69	8	5	24	10	1	0	-1	1	0	0	3.0	
i 1	202.9917074829932	0.2525	71	394	4	20	11	8	0	-2	8	0	0	0.013049016299054639	
i 1	202.99314965986395	1.7675	77	892	5	3	2	16	0	2	16	0	0	3.4392260014518	
i 1	202.99314965986395	2.525	77	8	7	5	16	16	0	1	16	0	0	7.0	
i 1	202.9996394557823	0.2525	74	394	4	20	11	2	0	-2	2	0	0	0.013049016299054639	
i 1	203.00540816326532	2.525	74	8	6	5	3	16	0	2	16	0	0	7.0	
i 1	203.0133401360544	0.505	71	394	4	20	7	8	0	1	8	0	0	0.013049016299054639	
i 1	203.0140612244898	1.7675	77	8	5	4	1	16	0	1	16	0	0	3.4392260014518	
i 1	203.01478231292518	0.2525	74	8	3	24	7	2	0	-2	2	0	0	4.013049016299055	
i 1	203.23738095238096	0.2525	74	8	4	20	11	2	0	1	2	0	0	0.013049016299054639	
i 1	203.23810204081633	0.2525	74	394	4	24	11	2	0	-2	2	0	0	4.013049016299055	
i 1	203.24675510204082	0.2525	71	8	4	20	5	8	0	1	8	0	0	0.013049016299054639	
i 1	203.9830544217687	0.2525	71	892	3	24	7	2	0	1	2	0	0	4.013049016299055	
i 1	203.98810204081633	2.525	69	892	4	24	4	0	0	-1	0	0	0	3.0	
i 1	203.99242857142858	0.2525	71	892	4	20	11	2	0	-2	2	0	0	0.013049016299054639	
i 1	203.99819727891156	2.525	72	394	6	1	2	1	0	-1	1	0	0	2.0	
i 1	203.99891836734693	0.7575000000000001	74	8	3	20	12	8	0	1	8	0	0	0.013049016299054639	
i 1	204.0082925170068	0.2525	74	8	3	24	7	2	0	-2	2	0	0	4.013049016299055	
i 1	204.24242857142858	0.505	74	8	3	20	13	2	0	-2	2	0	0	0.013049016299054639	
i 1	204.7330544217687	0.7575000000000001	77	394	5	9	3	16	0	2	16	0	0	2.4392260014518	
i 1	204.73738095238096	0.2525	74	8	3	24	7	2	0	-2	2	0	0	4.013049016299055	
i 1	204.73954421768707	0.2525	74	8	4	20	6	2	0	1	2	0	0	0.013049016299054639	
i 1	204.74819727891156	0.7575000000000001	74	8	7	2	12	16	0	2	16	0	0	3.4392260014518	
i 1	204.7582925170068	0.2525	74	892	4	20	7	2	0	-2	2	0	0	0.013049016299054639	
i 1	204.7582925170068	0.7575000000000001	74	394	4	24	4	2	0	-2	2	0	0	4.013049016299055	
i 1	204.99531292517005	0.505	71	394	4	20	6	2	0	1	2	0	0	0.013049016299054639	
i 1	205.0025238095238	0.505	71	394	4	20	10	8	0	1	8	0	0	0.013049016299054639	
i 1	205.00324489795918	0.505	74	8	2	24	2	8	0	1	8	0	0	4.013049016299055	
i 1	205.48738095238096	0.2525	74	394	4	20	4	8	0	-2	8	0	0	0.013049016299054639	
i 1	205.49242857142858	0.2525	77	892	5	3	4	16	0	2	16	0	0	3.4392260014518	
i 1	205.49531292517005	1.01	74	892	6	5	9	16	0	2	16	0	0	7.0	
i 1	205.4996394557823	0.2525	71	8	3	20	11	2	0	-2	2	0	0	0.013049016299054639	
i 1	205.50324489795918	0.2525	77	8	5	4	9	16	0	1	16	0	0	3.4392260014518	
i 1	205.50757142857142	0.2525	74	8	3	24	16	2	0	-2	2	0	0	4.013049016299055	
i 1	205.51261904761904	1.01	77	394	6	5	5	16	0	2	16	0	0	7.0	
i 1	205.51478231292518	0.2525	74	8	3	20	5	8	0	1	8	0	0	0.013049016299054639	
i 1	205.73377551020408	0.2525	77	8	4	3	12	17	0	1	17	0	0	3.4392260014518	
i 1	205.73377551020408	0.2525	74	8	4	20	13	2	0	-2	2	0	0	0.013049016299054639	
i 1	205.74891836734693	0.2525	77	8	6	2	3	16	0	1	16	0	0	3.4392260014518	
i 1	205.75540816326532	0.2525	71	394	4	20	5	8	0	1	8	0	0	0.013049016299054639	
i 1	206.00468707482995	0.2525	77	892	5	3	8	16	0	2	16	0	0	3.4392260014518	
i 1	206.00685034013605	0.2525	77	8	5	4	3	16	0	1	16	0	0	3.4392260014518	
i 1	206.00685034013605	0.7575000000000001	74	8	3	24	15	2	0	-2	2	0	0	4.013049016299055	
i 1	206.2503605442177	0.505	77	394	5	9	10	17	0	2	17	0	0	2.4392260014518	
i 1	206.25901360544216	0.505	77	892	4	4	3	17	0	1	17	0	0	3.4392260014518	
i 1	206.4859387755102	1.5150000000000001	72	8	7	1	7	0	0	0	0	0	0	2.0	
i 1	206.48738095238096	1.5150000000000001	69	8	7	1	9	0	0	0	0	0	0	2.0	
i 1	206.48738095238096	0.2525	74	8	6	5	3	17	0	2	17	0	0	7.0	
i 1	206.49098639455784	0.2525	74	8	3	20	15	2	0	-2	2	0	0	0.013049016299054639	
i 1	206.49459183673468	0.2525	77	394	6	5	9	17	0	1	17	0	0	7.0	
i 1	206.49603401360545	0.2525	74	8	3	20	7	8	0	1	8	0	0	0.013049016299054639	
i 1	206.5169455782313	0.2525	74	394	4	20	12	2	0	-2	2	0	0	0.013049016299054639	
i 1	206.74098639455784	2.02	77	892	5	3	10	16	0	2	16	0	0	3.4392260014518	
i 1	206.74242857142858	0.2525	77	8	5	4	1	16	0	1	16	0	0	3.4392260014518	
i 1	206.75612925170068	0.2525	77	8	7	5	1	16	0	1	16	0	0	7.0	
i 1	206.75612925170068	0.2525	74	8	4	20	3	2	0	1	2	0	0	0.013049016299054639	
i 1	206.75757142857142	0.2525	71	394	4	20	7	8	0	1	8	0	0	0.013049016299054639	
i 1	206.75901360544216	0.2525	74	8	6	5	16	16	0	2	16	0	0	7.0	
i 1	206.98521768707482	2.7775	77	8	6	5	8	16	0	1	16	0	0	7.0	
i 1	206.98521768707482	2.7775	74	8	7	5	16	16	0	2	16	0	0	7.0	
i 1	206.98738095238096	1.7675	77	8	4	4	16	16	0	1	16	0	0	3.4392260014518	
i 1	206.99459183673468	0.505	71	394	4	20	2	2	0	1	2	0	0	0.49831441235639584	
i 1	206.99891836734693	0.505	74	8	3	24	11	2	0	-2	2	0	0	4.498314412356396	
i 1	207.00757142857142	0.7575000000000001	74	394	1	24	10	2	0	248	2	308	0	4.498314412356396	
i 1	207.0140612244898	21.9675	61	8	5	12	11	1	0	1	1	0	0	3.7112178677348253	
i 1	207.0169455782313	21.9675	61	8	6	13	14	1	0	1	1	0	0	2.783413400801119	
i 1	207.48449659863945	0.2525	71	394	4	20	7	2	0	1	2	0	0	0.49831441235639584	
i 1	207.4859387755102	2.525	74	8	3	20	11	8	0	1	8	0	0	0.49831441235639584	
i 1	207.5025238095238	0.2525	71	8	3	20	5	2	0	-2	2	0	0	0.49831441235639584	
i 1	207.5169455782313	0.2525	71	394	4	20	13	8	0	1	8	0	0	0.49831441235639584	
i 1	207.75180272108844	0.7575000000000001	74	892	4	24	8	2	0	1	2	0	0	4.498314412356396	
i 1	207.75685034013605	0.7575000000000001	74	8	4	20	1	2	0	1	2	0	0	0.49831441235639584	
i 1	207.75973469387756	2.2725	74	394	3	24	9	2	0	-2	2	0	0	4.498314412356396	
i 1	207.9830544217687	0.505	69	892	4	24	3	0	0	-1	0	0	0	3.0	
i 1	207.9917074829932	0.505	72	394	6	1	3	1	0	-1	1	0	0	2.0	
i 1	208.48377551020408	0.7575000000000001	69	8	7	1	3	0	0	0	0	0	0	2.0	
i 1	208.49675510204082	1.5150000000000001	74	8	3	20	2	2	0	-2	2	0	0	0.49831441235639584	
i 1	208.50973469387756	0.7575000000000001	72	8	7	1	4	0	0	0	0	0	0	2.0	
i 1	208.51622448979592	1.5150000000000001	74	8	3	24	11	2	0	-2	2	0	0	4.498314412356396	
i 1	208.7388231292517	0.2525	77	394	5	9	3	16	0	2	16	0	0	2.4392260014518	
i 1	208.74459183673468	0.2525	74	8	7	2	5	16	0	2	16	0	0	3.4392260014518	
i 1	208.99459183673468	0.2525	77	892	5	3	4	16	0	2	16	0	0	3.4392260014518	
i 1	209.01766666666666	0.2525	77	8	4	4	12	16	0	1	16	0	0	3.4392260014518	
i 1	209.23954421768707	2.02	69	8	5	24	15	1	0	-1	1	0	0	3.0	
i 1	209.24459183673468	0.505	77	8	4	3	3	17	0	1	17	0	0	3.4392260014518	
i 1	209.2611768707483	0.505	77	8	7	2	2	16	0	1	16	0	0	3.4392260014518	
i 1	209.2640612244898	2.02	69	892	6	1	16	0	0	-1	0	0	0	2.0	
i 1	209.7503605442177	1.2625	77	394	6	5	3	17	0	1	17	0	0	7.0	
i 1	209.75108163265307	1.2625	74	8	7	5	14	17	0	2	17	0	0	7.0	
i 1	209.75180272108844	1.01	77	8	4	4	11	16	0	1	16	0	0	3.4392260014518	
i 1	209.7525238095238	1.01	77	892	5	3	9	16	0	2	16	0	0	3.4392260014518	
i 1	209.9974761904762	0.2525	68	892	4	20	2	0	0	-1	0	0	0	0.49831441235639584	
i 1	210.0140612244898	0.2525	74	8	3	24	1	2	0	-2	2	0	0	4.498314412356396	
i 1	210.24026530612244	2.2725	74	8	3	20	7	8	0	1	8	0	0	0.49831441235639584	
i 1	210.24098639455784	0.2525	71	394	4	20	11	8	0	1	8	0	0	0.49831441235639584	
i 1	210.2611768707483	0.2525	68	8	3	20	3	0	0	-1	0	0	0	0.49831441235639584	
i 1	210.2633401360544	0.2525	68	394	4	20	2	0	0	-1	0	0	0	0.49831441235639584	
i 1	210.50973469387756	0.505	74	394	3	24	3	2	0	-2	2	0	0	4.498314412356396	
i 1	210.7388231292517	1.7675	68	8	3	20	13	0	0	0	0	0	0	0.49831441235639584	
i 1	210.74459183673468	0.7575000000000001	77	394	5	9	7	17	0	2	17	0	0	2.4392260014518	
i 1	210.7474761904762	0.7575000000000001	77	892	4	4	3	17	0	1	17	0	0	3.4392260014518	
i 1	210.7669455782313	0.2525	68	8	3	24	16	1	0	-1	1	0	0	4.498314412356396	
i 1	210.98377551020408	1.5150000000000001	71	394	4	20	10	1	0	-1	1	0	0	0.49831441235639584	
i 1	210.9974761904762	1.2625	74	892	6	5	15	16	0	2	16	0	0	7.0	
i 1	210.99891836734693	1.5150000000000001	74	8	3	24	13	2	0	-2	2	0	0	4.498314412356396	
i 1	211.00757142857142	1.2625	77	394	6	5	14	16	0	2	16	0	0	7.0	
i 1	211.23449659863945	2.525	72	394	6	1	8	1	0	-1	1	0	0	2.0	
i 1	211.25685034013605	2.525	69	892	4	24	12	0	0	-1	0	0	0	3.0	
i 1	211.50612925170068	0.7575000000000001	77	8	4	4	14	16	0	1	16	0	0	3.4392260014518	
i 1	211.51261904761904	0.7575000000000001	77	892	5	3	15	16	0	2	16	0	0	3.4392260014518	
i 1	212.24314965986395	1.2625	74	8	7	5	15	16	0	2	16	0	0	7.0	
i 1	212.24819727891156	0.505	74	8	7	2	6	16	0	2	16	0	0	3.4392260014518	
i 1	212.25108163265307	0.505	77	8	6	5	1	16	0	1	16	0	0	7.0	
i 1	212.25901360544216	0.505	77	394	5	9	7	16	0	2	16	0	0	2.4392260014518	
i 1	212.49891836734693	0.2525	71	8	4	20	12	1	0	-1	1	0	0	0.49831441235639584	
i 1	212.50324489795918	0.2525	71	394	4	20	13	8	0	1	8	0	0	0.49831441235639584	
i 1	212.7330544217687	1.01	77	892	5	3	11	16	0	2	16	0	0	3.4392260014518	
i 1	212.7330544217687	1.2625	68	394	4	20	14	1	0	-1	1	0	0	0.49831441235639584	
i 1	212.73810204081633	1.2625	71	394	3	20	15	8	0	1	8	0	0	0.49831441235639584	
i 1	212.74026530612244	1.2625	71	394	4	20	10	1	0	0	1	0	0	0.49831441235639584	
i 1	212.7496394557823	1.7675	74	8	3	24	16	2	0	-2	2	0	0	4.498314412356396	
i 1	212.7503605442177	1.01	77	8	4	4	14	16	0	1	16	0	0	3.4392260014518	
i 1	212.75685034013605	29.0375	61	892	5	15	6	1	0	1	1	0	0	3.2473156342679723	
i 1	212.7611768707483	0.7575000000000001	77	8	7	5	2	16	0	1	16	0	0	7.0	
i 1	213.50396598639455	1.5150000000000001	74	892	6	5	6	16	0	2	16	0	0	7.0	
i 1	213.51261904761904	1.5150000000000001	77	394	6	5	15	16	0	2	16	0	0	7.0	
i 1	213.74603401360545	0.7575000000000001	77	8	4	3	15	17	0	1	17	0	0	3.4392260014518	
i 1	213.75973469387756	0.7575000000000001	69	8	7	1	6	0	0	0	0	0	0	2.0	
i 1	213.75973469387756	0.7575000000000001	77	8	7	2	5	16	0	1	16	0	0	3.4392260014518	
i 1	213.7633401360544	0.7575000000000001	72	8	7	1	1	0	0	0	0	0	0	2.0	
i 1	213.99459183673468	0.2525	71	892	4	20	14	0	0	-1	0	0	0	0.49831441235639584	
i 1	214.00685034013605	0.2525	68	8	4	20	12	0	0	-1	0	0	0	0.49831441235639584	
i 1	214.01189795918367	0.2525	74	394	4	24	16	2	0	-2	2	0	0	4.498314412356396	
i 1	214.23954421768707	2.02	68	8	3	20	15	1	0	-1	1	0	0	0.49831441235639584	
i 1	214.24026530612244	2.02	74	8	3	20	9	8	0	1	8	0	0	0.49831441235639584	
i 1	214.26261904761904	0.2525	71	394	4	20	6	1	0	0	1	0	0	0.49831441235639584	
i 1	214.48954421768707	0.505	69	892	4	24	14	0	0	-1	0	0	0	3.0	
i 1	214.49098639455784	0.2525	77	8	4	4	15	16	0	1	16	0	0	3.4392260014518	
i 1	214.49314965986395	0.2525	71	8	3	24	4	1	0	-1	1	0	0	4.498314412356396	
i 1	214.50180272108844	0.505	72	394	6	1	8	1	0	-1	1	0	0	2.0	
i 1	214.50324489795918	0.2525	77	892	5	3	12	16	0	2	16	0	0	3.4392260014518	
i 1	214.50612925170068	0.2525	74	394	4	24	16	2	0	-2	2	0	0	4.498314412356396	
i 1	214.73377551020408	1.5150000000000001	74	8	3	24	3	2	0	-2	2	0	0	4.498314412356396	
i 1	214.76189795918367	0.2525	77	892	4	4	15	17	0	1	17	0	0	3.4392260014518	
i 1	214.7640612244898	0.2525	77	394	5	9	2	17	0	2	17	0	0	2.4392260014518	
i 1	214.76622448979592	1.5150000000000001	71	394	4	20	9	1	0	0	1	0	0	0.49831441235639584	
i 1	214.9830544217687	1.7675	77	8	4	4	16	16	0	1	16	0	0	3.4392260014518	
i 1	214.98810204081633	1.5150000000000001	69	8	7	1	13	0	0	0	0	0	0	2.0	
i 1	214.98954421768707	1.7675	77	892	5	3	2	16	0	2	16	0	0	3.4392260014518	
i 1	214.99387074829932	1.5150000000000001	74	8	7	5	11	17	0	2	17	0	0	7.0	
i 1	214.99675510204082	1.5150000000000001	72	8	7	1	1	0	0	0	0	0	0	2.0	
i 1	215.01045578231293	1.5150000000000001	77	394	6	5	13	17	0	1	17	0	0	7.0	
i 1	216.2330544217687	2.2725	74	394	4	24	3	2	0	-2	2	0	0	4.498314412356396	
i 1	216.23449659863945	1.01	71	394	4	20	7	0	0	0	0	0	0	0.49831441235639584	
i 1	216.23738095238096	1.01	71	8	3	24	12	1	0	-1	1	0	0	4.498314412356396	
i 1	216.23810204081633	1.01	71	394	3	20	14	8	0	1	8	0	0	0.49831441235639584	
i 1	216.49098639455784	2.525	77	8	7	5	3	16	0	1	16	0	0	7.0	
i 1	216.49314965986395	2.02	69	8	5	24	5	1	0	-1	1	0	0	3.0	
i 1	216.4996394557823	2.02	69	892	6	1	11	0	0	-1	0	0	0	2.0	
i 1	216.5140612244898	2.525	74	8	7	5	6	16	0	2	16	0	0	7.0	
i 1	216.7366598639456	0.7575000000000001	77	394	5	9	1	16	0	2	16	0	0	2.4392260014518	
i 1	216.7503605442177	0.7575000000000001	74	8	7	2	10	16	0	2	16	0	0	3.4392260014518	
i 1	217.23810204081633	0.505	71	892	4	24	11	0	0	0	0	0	0	4.498314412356396	
i 1	217.25180272108844	0.505	68	8	4	20	9	1	0	-1	1	0	0	0.49831441235639584	
i 1	217.25324489795918	3.2825	74	8	3	20	15	8	0	1	8	0	0	0.49831441235639584	
i 1	217.4974761904762	0.2525	77	892	5	3	9	16	0	2	16	0	0	3.4392260014518	
i 1	217.50468707482995	0.2525	77	8	4	4	15	16	0	1	16	0	0	3.4392260014518	
i 1	217.7366598639456	0.2525	77	8	7	2	14	16	0	1	16	0	0	3.4392260014518	
i 1	217.7474761904762	0.2525	77	8	4	3	14	17	0	1	17	0	0	3.4392260014518	
i 1	217.7525238095238	2.7775	71	8	3	20	9	1	0	0	1	0	0	0.49831441235639584	
i 1	217.76550340136055	0.7575000000000001	68	8	3	24	11	1	0	0	1	0	0	4.498314412356396	
i 1	218.00396598639455	0.2525	77	892	5	3	9	16	0	2	16	0	0	3.4392260014518	
i 1	218.24675510204082	0.505	77	394	5	9	4	17	0	2	17	0	0	2.4392260014518	
i 1	218.4888231292517	0.2525	74	8	2	24	11	2	0	-2	2	0	0	4.498314412356396	
i 1	218.48954421768707	1.7675	69	892	4	24	8	0	0	-1	0	0	0	3.0	
i 1	218.49026530612244	1.7675	72	394	6	1	10	1	0	-1	1	0	0	2.0	
i 1	218.49603401360545	0.2525	77	892	4	4	6	17	0	1	17	0	0	3.4392260014518	
i 1	218.51550340136055	23.4825	61	892	5	15	4	1	0	1	1	0	0	3.2473156342679723	
i 1	218.51550340136055	0.2525	71	394	4	20	10	0	0	0	0	0	0	0.49831441235639584	
i 1	218.7503605442177	2.02	77	892	5	3	5	16	0	2	16	0	0	3.4392260014518	
i 1	218.75180272108844	2.02	77	8	4	4	9	16	0	1	16	0	0	3.4392260014518	
i 1	218.7525238095238	0.2525	74	394	4	24	8	2	0	-2	2	0	0	4.498314412356396	
i 1	218.76550340136055	0.2525	68	8	3	24	15	1	0	0	1	0	0	4.498314412356396	
i 1	218.9859387755102	1.5150000000000001	71	394	4	20	3	0	0	0	0	0	0	0.49831441235639584	
i 1	218.98810204081633	1.01	74	8	7	5	4	17	0	2	17	0	0	7.0	
i 1	219.0003605442177	1.01	77	394	6	5	1	17	0	1	17	0	0	7.0	
i 1	219.0082925170068	1.5150000000000001	74	8	2	24	13	2	0	-2	2	0	0	4.498314412356396	
i 1	219.9866598639456	0.2525	77	394	6	5	7	16	0	2	16	0	0	7.0	
i 1	220.01478231292518	0.2525	74	892	5	5	1	16	0	2	16	0	0	7.0	
i 1	220.25396598639455	1.5150000000000001	72	8	7	1	14	0	0	0	0	0	0	2.0	
i 1	220.25901360544216	1.5150000000000001	69	8	7	1	5	0	0	0	0	0	0	2.0	
i 1	220.26045578231293	3.0300000000000002	77	8	7	5	4	16	0	1	16	0	0	7.0	
i 1	220.26189795918367	3.0300000000000002	74	8	7	5	10	16	0	2	16	0	0	7.0	
i 1	220.48377551020408	1.01	71	394	4	20	10	0	0	0	0	0	0	0.49831441235639584	
i 1	220.4974761904762	2.2725	74	394	4	24	16	2	0	-2	2	0	0	4.498314412356396	
i 1	220.51045578231293	1.01	71	394	4	20	11	8	0	1	8	0	0	0.49831441235639584	
i 1	220.5140612244898	1.01	68	8	3	24	2	1	0	0	1	0	0	4.498314412356396	
i 1	220.7525238095238	0.2525	77	394	5	9	5	16	0	2	16	0	0	2.4392260014518	
i 1	220.75973469387756	0.2525	74	8	7	2	2	16	0	2	16	0	0	3.4392260014518	
i 1	221.01045578231293	0.2525	77	8	4	4	11	16	0	1	16	0	0	3.4392260014518	
i 1	221.01550340136055	0.2525	77	892	5	3	16	16	0	2	16	0	0	3.4392260014518	
i 1	221.23954421768707	0.505	77	8	7	2	6	16	0	1	16	0	0	3.4392260014518	
i 1	221.26261904761904	0.505	77	8	4	3	4	17	0	1	17	0	0	3.4392260014518	
i 1	221.49387074829932	0.2525	71	8	4	20	15	1	0	-1	1	0	0	0.49831441235639584	
i 1	221.50180272108844	0.2525	71	892	4	24	11	1	0	0	1	0	0	4.498314412356396	
i 1	221.50901360544216	0.2525	74	8	3	20	7	8	0	1	8	0	0	0.49831441235639584	
i 1	221.73233333333334	0.505	69	892	4	24	16	0	0	-1	0	0	0	3.0	
i 1	221.73810204081633	1.2625	68	394	4	20	8	0	0	-1	0	0	0	0.49831441235639584	
i 1	221.75324489795918	1.01	77	8	4	4	4	16	0	1	16	0	0	3.4392260014518	
i 1	221.75324489795918	1.5150000000000001	74	8	2	24	16	2	0	-2	2	0	0	4.498314412356396	
i 1	221.76478231292518	0.505	72	394	6	1	4	1	0	-1	1	0	0	2.0	
i 1	221.76550340136055	1.01	71	8	3	24	14	1	0	0	1	0	0	4.498314412356396	
i 1	221.76766666666666	1.01	77	892	5	3	9	16	0	2	16	0	0	3.4392260014518	
i 1	222.24459183673468	1.5150000000000001	72	8	7	1	11	0	0	0	0	0	0	2.0	
i 1	222.24819727891156	1.5150000000000001	69	8	7	1	6	0	0	0	0	0	0	2.0	
i 1	222.73738095238096	0.7575000000000001	77	892	4	4	7	17	0	1	17	0	0	3.4392260014518	
i 1	222.73810204081633	0.2525	71	8	3	20	10	1	0	-1	1	0	0	0.49831441235639584	
i 1	222.75612925170068	0.7575000000000001	77	394	5	9	13	17	0	2	17	0	0	2.4392260014518	
i 1	222.76478231292518	0.2525	74	8	3	20	8	8	0	1	8	0	0	0.49831441235639584	
i 1	222.9974761904762	0.2525	71	892	4	20	3	1	0	-1	1	0	0	0.49831441235639584	
i 1	223.0025238095238	0.2525	74	394	4	24	2	2	0	-2	2	0	0	4.498314412356396	
i 1	223.00324489795918	0.2525	71	8	4	20	6	0	0	-1	0	0	0	0.49831441235639584	
i 1	223.2366598639456	1.2625	68	8	3	20	10	1	0	0	1	0	0	0.49831441235639584	
i 1	223.23738095238096	1.01	77	394	6	5	3	16	0	2	16	0	0	7.0	
i 1	223.24675510204082	1.01	74	892	5	5	11	16	0	2	16	0	0	7.0	
i 1	223.2525238095238	1.2625	68	394	4	20	4	1	0	-1	1	0	0	0.49831441235639584	
i 1	223.2525238095238	3.2825	71	394	4	20	5	8	0	1	8	0	0	0.49831441235639584	
i 1	223.26189795918367	1.01	74	8	3	20	4	8	0	1	8	0	0	0.49831441235639584	
i 1	223.48449659863945	0.7575000000000001	77	892	5	3	15	16	0	2	16	0	0	3.4392260014518	
i 1	223.50757142857142	0.7575000000000001	77	8	4	4	7	16	0	1	16	0	0	3.4392260014518	
i 1	223.75612925170068	1.2625	69	8	5	24	13	1	0	-1	1	0	0	3.0	
i 1	223.76478231292518	1.2625	69	892	6	1	13	0	0	-1	0	0	0	2.0	
i 1	224.2359387755102	0.2525	74	892	6	5	5	16	0	2	16	0	0	7.0	
i 1	224.24098639455784	0.505	74	8	7	2	11	16	0	2	16	0	0	3.4392260014518	
i 1	224.24387074829932	0.2525	74	8	2	20	5	8	0	1	8	0	0	0.49831441235639584	
i 1	224.2474761904762	0.505	77	394	5	9	10	16	0	2	16	0	0	2.4392260014518	
i 1	224.26550340136055	4.545	61	394	4	16	7	1	0	2	1	0	0	3.7112178677348253	
i 1	224.26622448979592	0.2525	77	394	5	5	16	16	0	2	16	0	0	7.0	
i 1	224.49098639455784	0.7575000000000001	74	394	4	24	5	2	0	-2	2	0	0	4.498314412356396	
i 1	224.4974761904762	0.7575000000000001	68	8	4	20	2	1	0	-1	1	0	0	0.49831441235639584	
i 1	224.50901360544216	1.2625	77	394	6	5	10	17	0	1	17	0	0	7.0	
i 1	224.50901360544216	0.7575000000000001	71	8	4	20	2	0	0	-1	0	0	0	0.49831441235639584	
i 1	224.51766666666666	1.2625	74	8	7	5	2	17	0	2	17	0	0	7.0	
i 1	224.74603401360545	1.01	77	892	5	3	14	16	0	2	16	0	0	3.4392260014518	
i 1	224.76766666666666	1.01	77	8	4	4	14	16	0	1	16	0	0	3.4392260014518	
i 1	224.99459183673468	2.525	69	892	4	24	2	0	0	-1	0	0	0	3.0	
i 1	225.01045578231293	2.525	72	394	6	1	3	1	0	-1	1	0	0	2.0	
i 1	225.2330544217687	0.7575000000000001	74	8	3	24	12	2	0	-2	2	0	0	4.498314412356396	
i 1	225.23738095238096	0.2525	68	394	4	20	9	1	0	-1	1	0	0	0.49831441235639584	
i 1	225.25612925170068	0.2525	71	394	4	20	11	0	0	0	0	0	0	0.49831441235639584	
i 1	225.4996394557823	0.505	68	892	4	20	12	1	0	-1	1	0	0	0.49831441235639584	
i 1	225.50685034013605	0.505	71	8	4	20	13	1	0	0	1	0	0	0.49831441235639584	
i 1	225.73233333333334	0.7575000000000001	77	8	4	3	8	17	0	1	17	0	0	3.4392260014518	
i 1	225.74819727891156	0.7575000000000001	77	8	7	2	2	16	0	1	16	0	0	3.4392260014518	
i 1	225.7503605442177	1.2625	77	8	7	5	1	16	0	1	16	0	0	7.0	
i 1	225.76045578231293	1.2625	74	8	7	5	8	16	0	2	16	0	0	7.0	
i 1	225.99098639455784	0.2525	71	394	4	20	9	1	0	0	1	0	0	0.49831441235639584	
i 1	226.01261904761904	0.2525	68	8	3	20	8	1	0	0	1	0	0	0.49831441235639584	
i 1	226.01478231292518	0.2525	74	8	2	20	16	8	0	1	8	0	0	0.49831441235639584	
i 1	226.2366598639456	0.2525	74	394	4	24	9	2	0	-2	2	0	0	4.498314412356396	
i 1	226.24675510204082	0.2525	71	8	4	20	5	1	0	-1	1	0	0	0.49831441235639584	
i 1	226.25973469387756	0.2525	68	8	4	20	11	0	0	-1	0	0	0	0.49831441235639584	
i 1	226.4888231292517	1.01	68	394	4	20	5	0	0	-1	0	0	0	0.49831441235639584	
i 1	226.50540816326532	1.2625	74	8	3	24	11	2	0	-2	2	0	0	4.498314412356396	
i 1	226.50973469387756	0.2525	77	892	5	3	16	16	0	2	16	0	0	3.4392260014518	
i 1	226.51766666666666	0.2525	77	8	4	4	12	16	0	1	16	0	0	3.4392260014518	
i 1	226.74531292517005	0.2525	77	394	5	9	1	17	0	2	17	0	0	2.4392260014518	
i 1	226.75973469387756	0.2525	77	892	4	4	13	17	0	1	17	0	0	3.4392260014518	
i 1	226.98521768707482	1.5150000000000001	77	394	6	5	5	17	0	1	17	0	0	7.0	
i 1	226.99387074829932	1.7675	77	8	4	4	11	16	0	1	16	0	0	3.4392260014518	
i 1	226.99603401360545	2.525	77	892	5	3	8	16	0	2	16	0	0	3.4392260014518	
i 1	226.99819727891156	1.5150000000000001	74	8	7	5	8	17	0	2	17	0	0	7.0	
i 1	227.4917074829932	0.2525	74	394	4	24	1	2	0	-2	2	0	0	4.498314412356396	
i 1	227.4974761904762	1.2625	72	8	7	1	13	0	0	0	0	0	0	2.0	
i 1	227.4974761904762	1.2625	69	8	7	1	1	0	0	0	0	0	0	2.0	
i 1	227.50685034013605	0.2525	68	8	4	20	2	0	0	0	0	0	0	0.49831441235639584	
i 1	227.5082925170068	0.2525	68	892	4	20	3	0	0	0	0	0	0	0.49831441235639584	
i 1	227.73810204081633	1.01	74	8	2	20	9	8	0	1	8	0	0	0.49831441235639584	
i 1	227.74891836734693	1.01	71	8	3	20	12	1	0	-1	1	0	0	0.49831441235639584	
i 1	227.7582925170068	1.01	68	8	1	24	13	1	0	252	1	307	0	4.498314412356396	
i 1	227.7640612244898	1.01	71	394	4	20	7	8	0	1	8	0	0	0.49831441235639584	
i 1	227.7669455782313	1.01	71	394	4	20	6	1	0	0	1	0	0	0.49831441235639584	
i 1	228.50757142857142	0.2525	74	892	6	5	2	16	0	2	16	0	0	7.0	
i 1	228.50757142857142	0.2525	77	394	5	5	12	16	0	2	16	0	0	7.0	
i 1	228.73377551020408	12.8775	66	190	5	12	4	9	0	2	9	0	0	3.7112178677348253	
i 1	228.73449659863945	1.2625	66	190	5	16	2	6	0	1	6	0	0	3.7112178677348253	
i 1	228.73521768707482	0.505	74	190	7	1	9	17	0	1	17	0	0	2.0	
i 1	228.73521768707482	12.8775	66	190	4	27	8	9	0	2	9	0	0	1.780346323935208	
i 1	228.7366598639456	14.645	61	190	4	27	1	9	0	2	9	0	0	1.780346323935208	
i 1	228.73738095238096	0.505	74	1074	6	1	9	17	0	1	17	0	0	2.0	
i 1	228.73738095238096	7.07	66	190	5	12	7	9	0	2	9	0	0	3.7112178677348253	
i 1	228.73738095238096	1.2625	71	1074	6	5	12	8	0	-2	8	0	0	7.0	
i 1	228.7388231292517	1.5150000000000001	71	190	4	24	7	1	0	-1	1	0	0	4.498314412356396	
i 1	228.73954421768707	24.4925	61	190	5	16	13	9	0	2	9	0	0	3.7112178677348253	
i 1	228.7417074829932	3.7875	68	190	4	20	2	1	0	0	1	0	0	0.49831441235639584	
i 1	228.74459183673468	3.7875	68	190	4	20	1	0	0	0	0	0	0	0.49831441235639584	
i 1	228.74531292517005	7.07	66	1074	5	13	3	9	0	2	9	0	0	2.783413400801119	
i 1	228.74819727891156	7.07	66	190	5	26	13	9	0	1	9	0	0	1.0137921208505258	
i 1	228.7525238095238	1.2625	61	190	5	26	15	6	0	1	6	0	0	1.0137921208505258	
i 1	228.75685034013605	0.7575000000000001	75	190	4	3	9	2	0	-2	2	0	0	3.4392260014518	
i 1	228.75685034013605	1.2625	71	190	7	5	6	8	0	-2	8	0	0	7.0	
i 1	228.75973469387756	1.5150000000000001	71	190	4	20	9	1	0	-1	1	0	0	0.49831441235639584	
i 1	228.76189795918367	1.2625	61	1074	5	14	16	6	0	1	6	0	0	4.175120101201679	
i 1	229.2388231292517	1.2625	69	892	6	1	5	0	0	-1	0	0	0	2.0	
i 1	229.25108163265307	1.2625	74	190	7	1	13	17	0	2	17	0	0	2.0	
i 1	229.49459183673468	0.2525	72	190	5	9	12	2	0	-2	2	0	0	2.4392260014518	
i 1	229.50396598639455	0.2525	72	1074	6	2	14	2	0	-2	2	0	0	3.4392260014518	
i 1	229.73954421768707	0.2525	75	190	4	3	2	2	0	-2	2	0	0	3.4392260014518	
i 1	229.76622448979592	0.2525	77	892	5	3	7	16	0	2	16	0	0	3.4392260014518	
i 1	229.9830544217687	0.2525	77	892	4	4	9	17	0	1	17	0	0	3.4392260014518	
i 1	229.98377551020408	0.2525	75	190	4	4	4	2	0	-2	2	0	0	3.4392260014518	
i 1	229.99675510204082	1.2625	74	892	6	5	15	16	0	2	16	0	0	7.0	
i 1	230.00108163265307	26.765	66	190	5	16	1	6	0	1	6	0	0	3.7112178677348253	
i 1	230.00685034013605	1.2625	71	190	7	5	3	2	0	-2	2	0	0	7.0	
i 1	230.00901360544216	13.3825	61	1074	5	14	14	6	0	1	6	0	0	4.175120101201679	
i 1	230.23233333333334	0.505	71	190	3	24	9	1	0	0	1	0	0	4.498314412356396	
i 1	230.2496394557823	0.505	77	892	5	3	1	16	0	2	16	0	0	3.4392260014518	
i 1	230.25973469387756	0.505	71	190	3	20	12	1	0	-1	1	0	0	0.49831441235639584	
i 1	230.2640612244898	0.505	75	190	4	3	8	2	0	-2	2	0	0	3.4392260014518	
i 1	230.48810204081633	3.535	69	892	4	24	13	0	0	-1	0	0	0	3.0	
i 1	230.51622448979592	3.535	74	190	5	24	7	17	0	1	17	0	0	3.0	
i 1	230.75468707482995	0.505	71	190	4	20	12	1	0	-1	1	0	0	0.49831441235639584	
i 1	230.75973469387756	1.01	72	190	6	9	16	2	0	-2	2	0	0	2.4392260014518	
i 1	230.7611768707483	1.01	72	1074	6	2	8	2	0	-2	2	0	0	3.4392260014518	
i 1	230.76622448979592	0.505	71	190	4	24	4	1	0	-1	1	0	0	4.498314412356396	
i 1	231.23377551020408	1.2625	71	190	3	20	9	1	0	-1	1	0	0	0.49831441235639584	
i 1	231.25901360544216	1.01	74	1074	6	5	2	8	0	-1	8	0	0	7.0	
i 1	231.25973469387756	1.2625	71	190	3	24	10	1	0	0	1	0	0	4.498314412356396	
i 1	231.26766666666666	1.01	71	190	7	5	10	2	0	-1	2	0	0	7.0	
i 1	231.73449659863945	0.7575000000000001	75	190	4	3	1	2	0	-2	2	0	0	3.4392260014518	
i 1	231.76045578231293	0.7575000000000001	77	892	5	3	10	16	0	2	16	0	0	3.4392260014518	
i 1	232.23233333333334	1.7675	71	190	5	5	14	8	0	-2	8	0	0	7.0	
i 1	232.24459183673468	1.7675	71	1074	6	5	14	8	0	-2	8	0	0	7.0	
i 1	232.48954421768707	0.2525	75	1074	6	2	6	2	0	-2	2	0	0	3.4392260014518	
i 1	232.49819727891156	0.2525	72	190	6	9	7	2	0	1	2	0	0	2.4392260014518	
i 1	232.50324489795918	0.7575000000000001	71	190	3	24	16	0	0	0	0	0	0	4.498314412356396	
i 1	232.50468707482995	0.505	71	190	4	24	1	1	0	-1	1	0	0	4.498314412356396	
i 1	232.50901360544216	0.505	68	190	3	20	15	1	0	0	1	0	0	0.49831441235639584	
i 1	232.51045578231293	0.505	71	190	4	20	16	1	0	-1	1	0	0	0.49831441235639584	
i 1	232.51766666666666	0.505	71	190	1	24	4	1	0	252	1	307	0	4.498314412356396	
i 1	232.74098639455784	0.2525	75	190	4	3	3	2	0	-2	2	0	0	3.4392260014518	
i 1	232.74459183673468	0.2525	77	892	5	3	13	16	0	2	16	0	0	3.4392260014518	
i 1	232.98810204081633	0.2525	72	1074	6	2	9	2	0	-2	2	0	0	3.4392260014518	
i 1	232.99603401360545	0.2525	72	190	6	9	5	2	0	-2	2	0	0	2.4392260014518	
i 1	233.00396598639455	0.2525	68	1074	4	20	3	0	0	0	0	0	0	0.49831441235639584	
i 1	233.00612925170068	1.2625	68	190	4	20	8	1	0	0	1	0	0	0.49831441235639584	
i 1	233.00901360544216	0.2525	71	1074	4	20	12	1	0	0	1	0	0	0.49831441235639584	
i 1	233.23521768707482	0.505	77	892	5	3	7	16	0	2	16	0	0	3.4392260014518	
i 1	233.23521768707482	0.505	68	190	4	20	15	0	0	-1	0	0	0	0.49831441235639584	
i 1	233.2388231292517	0.505	68	190	4	20	3	0	0	-1	0	0	0	0.49831441235639584	
i 1	233.24675510204082	0.505	71	190	4	24	2	1	0	-1	1	0	0	4.498314412356396	
i 1	233.25324489795918	0.505	75	190	4	3	7	2	0	-2	2	0	0	3.4392260014518	
i 1	233.73449659863945	0.505	68	1074	4	20	14	1	0	-1	1	0	0	0.49831441235639584	
i 1	233.73954421768707	1.01	71	1074	4	20	10	1	0	0	1	0	0	0.49831441235639584	
i 1	233.74026530612244	1.01	71	190	3	24	10	0	0	0	0	0	0	4.498314412356396	
i 1	233.7417074829932	1.01	75	190	4	4	16	2	0	-2	2	0	0	3.4392260014518	
i 1	233.7669455782313	1.01	77	892	4	4	7	17	0	1	17	0	0	3.4392260014518	
i 1	233.98521768707482	0.505	74	190	7	1	15	17	0	1	17	0	0	2.0	
i 1	233.9996394557823	1.5150000000000001	71	190	7	5	10	2	0	-1	2	0	0	7.0	
i 1	234.00468707482995	1.5150000000000001	74	1074	6	5	6	8	0	-1	8	0	0	7.0	
i 1	234.01622448979592	0.505	74	1074	5	1	16	17	0	1	17	0	0	2.0	
i 1	234.24242857142858	0.505	68	892	4	24	9	0	0	0	0	0	0	4.498314412356396	
i 1	234.24242857142858	3.7875	71	190	4	24	13	1	0	-1	1	0	0	4.498314412356396	
i 1	234.4917074829932	0.7575000000000001	74	190	5	24	4	17	0	1	17	0	0	3.0	
i 1	234.49819727891156	0.7575000000000001	69	892	4	24	11	0	0	-1	0	0	0	3.0	
i 1	234.7330544217687	1.01	71	190	3	20	8	1	0	-1	1	0	0	0.49831441235639584	
i 1	234.73377551020408	0.7575000000000001	77	892	5	3	3	16	0	2	16	0	0	3.4392260014518	
i 1	234.73810204081633	0.7575000000000001	75	190	4	3	1	2	0	-2	2	0	0	3.4392260014518	
i 1	234.7633401360544	1.01	71	190	4	20	7	1	0	0	1	0	0	0.49831441235639584	
i 1	234.7640612244898	1.01	68	190	3	24	7	1	0	-1	1	0	0	4.498314412356396	
i 1	235.24675510204082	0.505	74	1074	5	1	12	17	0	1	17	0	0	2.0	
i 1	235.2474761904762	0.505	74	190	7	1	12	17	0	1	17	0	0	2.0	
i 1	235.49242857142858	1.2625	74	892	6	5	7	16	0	2	16	0	0	7.0	
i 1	235.4996394557823	0.2525	72	1074	6	2	16	2	0	-2	2	0	0	3.4392260014518	
i 1	235.51478231292518	0.2525	72	190	6	9	12	2	0	-2	2	0	0	2.4392260014518	
i 1	235.51622448979592	1.2625	71	190	7	5	12	2	0	-2	2	0	0	7.0	
i 1	235.73233333333334	7.575	66	1074	5	25	16	9	0	1	9	0	0	1.0137921208505258	
i 1	235.74459183673468	2.02	69	892	5	1	16	0	0	-1	0	0	0	2.0	
i 1	235.74603401360545	0.2525	68	892	4	24	5	0	0	0	0	0	0	4.498314412356396	
i 1	235.74675510204082	0.2525	71	1074	4	20	12	0	0	-1	0	0	0	0.49831441235639584	
i 1	235.7496394557823	2.02	74	190	7	1	6	17	0	2	17	0	0	2.0	
i 1	235.75468707482995	7.575	66	190	6	12	12	9	0	2	9	0	0	3.7112178677348253	
i 1	235.75612925170068	0.2525	75	190	5	3	7	2	0	-2	2	0	0	3.4392260014518	
i 1	235.75757142857142	0.2525	68	190	4	20	14	1	0	0	1	0	0	0.49831441235639584	
i 1	235.75901360544216	7.575	66	1074	5	13	12	9	0	2	9	0	0	2.783413400801119	
i 1	235.7640612244898	0.2525	77	892	5	3	1	16	0	2	16	0	0	3.4392260014518	
i 1	235.99387074829932	0.2525	75	1074	6	2	16	2	0	-2	2	0	0	3.4392260014518	
i 1	236.00108163265307	0.505	68	190	3	24	7	1	0	-1	1	0	0	4.498314412356396	
i 1	236.00685034013605	0.2525	72	190	6	9	2	2	0	1	2	0	0	2.4392260014518	
i 1	236.00757142857142	0.505	71	190	3	20	9	1	0	-1	1	0	0	0.49831441235639584	
i 1	236.0111768707483	0.505	68	190	4	20	12	1	0	0	1	0	0	0.49831441235639584	
i 1	236.2503605442177	0.505	75	190	5	3	5	2	0	-2	2	0	0	3.4392260014518	
i 1	236.26766666666666	0.505	77	892	5	3	15	16	0	2	16	0	0	3.4392260014518	
i 1	236.48954421768707	0.7575000000000001	68	190	4	20	6	1	0	0	1	0	0	0.49831441235639584	
i 1	236.50540816326532	0.7575000000000001	71	1074	4	20	7	0	0	0	0	0	0	0.49831441235639584	
i 1	236.51766666666666	0.7575000000000001	71	892	4	24	6	0	0	0	0	0	0	4.498314412356396	
i 1	236.74026530612244	2.2725	71	190	7	5	12	8	0	-2	8	0	0	7.0	
i 1	236.74387074829932	1.01	72	1074	6	2	2	2	0	-2	2	0	0	3.4392260014518	
i 1	236.75324489795918	1.01	72	190	6	9	9	2	0	-2	2	0	0	2.4392260014518	
i 1	236.75685034013605	2.2725	71	1074	6	5	14	8	0	-2	8	0	0	7.0	
i 1	237.24531292517005	0.505	68	190	3	24	10	1	0	-1	1	0	0	4.498314412356396	
i 1	237.2640612244898	0.505	68	190	4	20	12	0	0	-1	0	0	0	0.49831441235639584	
i 1	237.26550340136055	0.505	71	190	3	20	10	1	0	-1	1	0	0	0.49831441235639584	
i 1	237.7366598639456	0.7575000000000001	77	892	5	3	2	16	0	2	16	0	0	3.4392260014518	
i 1	237.7388231292517	0.2525	68	1074	4	20	4	1	0	-1	1	0	0	0.49831441235639584	
i 1	237.75108163265307	5.555	74	190	5	24	1	17	0	1	17	0	0	3.0	
i 1	237.75108163265307	0.2525	68	892	4	24	7	0	0	-1	0	0	0	4.498314412356396	
i 1	237.75108163265307	0.2525	68	190	4	20	8	1	0	0	1	0	0	0.49831441235639584	
i 1	237.75612925170068	0.7575000000000001	75	190	5	3	1	2	0	-2	2	0	0	3.4392260014518	
i 1	237.75973469387756	3.7875	69	892	4	24	8	0	0	-1	0	0	0	3.0	
i 1	237.9888231292517	1.2625	71	190	3	20	7	1	0	-1	1	0	0	0.49831441235639584	
i 1	238.00685034013605	1.2625	71	190	3	24	9	1	0	0	1	0	0	4.498314412356396	
i 1	238.49314965986395	0.2525	75	190	4	4	3	2	0	-2	2	0	0	3.4392260014518	
i 1	238.5025238095238	0.2525	77	892	4	4	3	17	0	1	17	0	0	3.4392260014518	
i 1	238.74387074829932	0.2525	77	892	5	3	12	16	0	2	16	0	0	3.4392260014518	
i 1	238.76622448979592	0.2525	75	190	5	3	14	2	0	-2	2	0	0	3.4392260014518	
i 1	238.98810204081633	0.2525	72	1074	6	2	2	2	0	-2	2	0	0	3.4392260014518	
i 1	238.9888231292517	0.2525	71	190	7	5	13	2	0	-2	2	0	0	7.0	
i 1	239.0111768707483	0.2525	72	190	6	9	3	2	0	-2	2	0	0	2.4392260014518	
i 1	239.01478231292518	0.2525	74	892	6	5	15	16	0	2	16	0	0	7.0	
i 1	239.23233333333334	1.7675	74	1074	6	5	14	8	0	-1	8	0	0	7.0	
i 1	239.2388231292517	0.7575000000000001	77	892	5	3	8	16	0	2	16	0	0	3.4392260014518	
i 1	239.24891836734693	2.02	71	190	7	5	14	2	0	-1	2	0	0	7.0	
i 1	239.25396598639455	0.2525	71	892	4	24	4	0	0	0	0	0	0	4.498314412356396	
i 1	239.2611768707483	1.01	71	190	4	24	2	1	0	-1	1	0	0	4.498314412356396	
i 1	239.26622448979592	0.7575000000000001	75	190	5	3	5	2	0	-2	2	0	0	3.4392260014518	
i 1	239.4859387755102	0.2525	71	190	3	24	9	1	0	-1	1	0	0	4.498314412356396	
i 1	239.4866598639456	0.2525	71	190	4	20	16	1	0	-1	1	0	0	0.49831441235639584	
i 1	239.51766666666666	0.2525	71	190	3	20	2	1	0	-1	1	0	0	0.49831441235639584	
i 1	239.74242857142858	1.2625	72	190	6	9	6	2	0	1	2	0	0	2.4392260014518	
i 1	239.74314965986395	1.2625	75	1074	6	2	8	2	0	-2	2	0	0	3.4392260014518	
i 1	239.74314965986395	0.505	71	1074	4	20	9	0	0	-1	0	0	0	0.49831441235639584	
i 1	239.7496394557823	0.505	71	892	4	24	15	1	0	-1	1	0	0	4.498314412356396	
i 1	239.75324489795918	0.505	68	190	4	20	6	1	0	0	1	0	0	0.49831441235639584	
i 1	239.7640612244898	0.2525	74	190	7	1	5	17	0	1	17	0	0	2.0	
i 1	239.98377551020408	0.2525	77	892	4	4	14	17	0	1	17	0	0	3.4392260014518	
i 1	240.01622448979592	0.2525	71	1074	6	5	1	8	0	-2	8	0	0	7.0	
i 1	240.2366598639456	0.505	71	190	3	24	8	0	0	-1	0	0	0	4.498314412356396	
i 1	240.23810204081633	0.505	71	190	3	20	14	1	0	-1	1	0	0	0.49831441235639584	
i 1	240.2496394557823	0.2525	74	190	7	1	2	16	0	2	16	0	0	2.0	
i 1	240.4917074829932	0.7575000000000001	74	190	7	1	7	17	0	1	17	0	0	2.0	
i 1	240.49675510204082	1.2625	71	1074	6	5	9	8	0	-2	8	0	0	7.0	
i 1	240.49675510204082	4.04	71	190	7	5	4	8	0	-2	8	0	0	7.0	
i 1	240.5025238095238	0.7575000000000001	74	1074	5	1	6	17	0	1	17	0	0	2.0	
i 1	240.7359387755102	0.7575000000000001	68	190	4	20	14	1	0	0	1	0	0	0.49831441235639584	
i 1	240.74098639455784	0.505	68	190	4	20	8	0	0	-1	0	0	0	0.49831441235639584	
i 1	240.74459183673468	0.505	68	190	4	20	5	0	0	-1	0	0	0	0.49831441235639584	
i 1	240.74531292517005	1.01	77	892	5	3	6	16	0	2	16	0	0	3.4392260014518	
i 1	240.74603401360545	0.7575000000000001	75	190	5	3	11	2	0	-2	2	0	0	3.4392260014518	
i 1	240.74819727891156	0.7575000000000001	71	190	4	24	5	1	0	-1	1	0	0	4.498314412356396	
i 1	241.24098639455784	0.2525	68	1074	4	20	3	1	0	0	1	0	0	0.49831441235639584	
i 1	241.25973469387756	0.2525	74	190	7	1	3	16	0	2	16	0	0	2.0	
i 1	241.26550340136055	0.2525	68	1074	4	20	5	1	0	-1	1	0	0	0.49831441235639584	
i 1	241.2669455782313	0.7575000000000001	72	190	6	9	1	2	0	-2	2	0	0	2.4392260014518	
i 1	241.48233333333334	1.7675	66	190	6	12	11	9	0	2	9	0	0	3.7112178677348253	
i 1	241.48377551020408	0.505	72	1074	6	2	5	2	0	-2	2	0	0	3.4392260014518	
i 1	241.4859387755102	1.01	71	190	4	24	5	1	0	-1	1	0	0	4.941908991581915	
i 1	241.4866598639456	0.2525	61	892	5	15	8	1	0	1	1	0	0	3.2473156342679723	
i 1	241.49314965986395	1.01	71	190	4	20	1	0	0	-1	0	0	0	0.941908991581915	
i 1	241.49531292517005	0.2525	69	892	4	24	12	0	0	-1	0	0	0	3.0	
i 1	241.50108163265307	0.2525	77	1074	5	1	13	16	0	2	16	0	0	2.0	
i 1	241.50612925170068	0.2525	77	892	4	4	13	17	0	1	17	0	0	3.4392260014518	
i 1	241.50612925170068	0.505	72	190	6	9	13	2	0	1	2	0	0	2.4392260014518	
i 1	241.5111768707483	0.2525	75	190	6	3	10	2	0	-2	2	0	0	3.4392260014518	
i 1	241.51189795918367	1.7675	66	1074	5	25	15	6	0	2	6	0	0	1.0137921208505258	
i 1	241.51550340136055	15.15	66	190	1	27	5	9	0	252	9	307	0	1.780346323935208	
i 1	241.7330544217687	0.2525	75	688	4	4	12	2	0	-2	2	0	0	3.4392260014518	
i 1	241.73377551020408	0.2525	77	688	4	24	2	17	0	2	17	0	0	3.0	
i 1	241.73377551020408	0.7575000000000001	75	190	5	4	7	2	0	-2	2	0	0	3.4392260014518	
i 1	241.7366598639456	2.7775	75	688	5	3	14	2	0	1	2	0	0	3.4392260014518	
i 1	241.74026530612244	1.5150000000000001	74	1074	6	5	9	8	0	-1	8	0	0	7.0	
i 1	241.74387074829932	0.2525	71	190	4	5	13	2	0	-2	2	0	0	7.0	
i 1	241.74459183673468	0.505	74	1074	5	1	9	17	0	1	17	0	0	2.0	
i 1	241.74603401360545	2.7775	61	688	5	15	13	9	0	1	9	0	0	3.2473156342679723	
i 1	241.76045578231293	0.505	74	190	7	1	15	17	0	2	17	0	0	2.0	
i 1	241.76622448979592	2.7775	61	688	5	15	11	9	0	2	9	0	0	3.2473156342679723	
i 1	241.9917074829932	0.7575000000000001	75	190	6	3	15	2	0	-2	2	0	0	3.4392260014518	
i 1	242.24026530612244	0.2525	77	1074	5	1	10	16	0	2	16	0	0	2.0	
i 1	242.25612925170068	0.505	72	1074	6	2	16	2	0	-2	2	0	0	3.4392260014518	
i 1	242.2669455782313	1.01	74	688	5	1	1	16	0	2	16	0	0	2.0	
i 1	242.4830544217687	0.2525	68	1074	4	20	9	1	0	0	1	0	0	0.941908991581915	
i 1	242.48738095238096	0.2525	74	688	6	5	8	8	0	-1	8	0	0	7.0	
i 1	242.4917074829932	1.2625	68	190	4	20	12	1	0	0	1	0	0	0.941908991581915	
i 1	242.50685034013605	0.505	71	190	3	24	9	0	0	0	0	0	0	4.941908991581915	
i 1	242.73233333333334	0.505	71	190	7	5	16	2	0	-1	2	0	0	7.0	
i 1	242.7330544217687	0.2525	71	190	4	24	5	1	0	-1	1	0	0	4.941908991581915	
i 1	242.7388231292517	0.505	71	688	6	5	15	8	0	-2	8	0	0	7.0	
i 1	242.74026530612244	0.2525	71	190	4	20	6	1	0	-1	1	0	0	0.941908991581915	
i 1	242.74603401360545	0.2525	68	190	4	20	15	0	0	-1	0	0	0	0.941908991581915	
i 1	242.75901360544216	0.505	75	190	5	4	16	2	0	-2	2	0	0	3.4392260014518	
i 1	243.00540816326532	0.2525	75	688	4	4	7	2	0	-2	2	0	0	3.4392260014518	
i 1	243.00612925170068	0.2525	71	1074	6	5	7	8	0	-2	8	0	0	7.0	
i 1	243.0082925170068	0.2525	71	1074	4	20	3	0	0	0	0	0	0	0.941908991581915	
i 1	243.01045578231293	1.5150000000000001	77	688	4	24	4	17	0	2	17	0	0	3.0	
i 1	243.01189795918367	0.2525	71	1074	4	20	9	0	0	-1	0	0	0	0.941908991581915	
i 1	243.23377551020408	4.2925	71	892	6	5	6	8	0	-1	8	0	0	7.0	
i 1	243.2359387755102	0.505	68	190	1	24	3	0	0	252	0	307	0	4.941908991581915	
i 1	243.2366598639456	13.3825	66	190	5	12	5	9	0	2	9	0	0	3.7112178677348253	
i 1	243.23954421768707	2.02	75	190	5	3	13	2	0	-2	2	0	0	3.4392260014518	
i 1	243.24314965986395	9.8475	66	892	5	13	10	9	0	1	9	0	0	2.783413400801119	
i 1	243.24531292517005	13.3825	66	190	5	12	15	9	0	2	9	0	0	3.7112178677348253	
i 1	243.2474761904762	0.2525	75	190	4	4	1	2	0	-2	2	0	0	3.4392260014518	
i 1	243.25180272108844	0.505	68	190	4	20	15	0	0	0	0	0	0	0.941908991581915	
i 1	243.25468707482995	4.04	61	892	5	14	12	9	0	1	9	0	0	4.175120101201679	
i 1	243.25540816326532	0.2525	74	892	5	1	2	16	0	1	16	0	0	2.0	
i 1	243.26261904761904	4.04	61	190	3	27	11	9	0	2	9	0	0	1.780346323935208	
i 1	243.26261904761904	0.505	71	190	4	20	3	1	0	0	1	0	0	0.941908991581915	
i 1	243.2640612244898	15.655	61	892	5	25	4	6	0	1	6	0	0	1.0137921208505258	
i 1	243.2640612244898	0.505	71	190	4	24	16	1	0	-1	1	0	0	4.941908991581915	
i 1	243.26550340136055	1.5150000000000001	74	190	5	24	14	17	0	1	17	0	0	3.0	
i 1	243.2669455782313	15.655	66	892	5	25	16	9	0	1	9	0	0	1.0137921208505258	
i 1	243.48521768707482	0.2525	74	190	7	1	12	17	0	1	17	0	0	2.0	
i 1	243.48954421768707	0.2525	71	190	2	20	6	0	0	0	0	0	0	0.941908991581915	
i 1	243.49891836734693	1.01	71	190	2	20	10	1	0	-1	1	0	0	0.941908991581915	
i 1	243.5169455782313	8.585	71	190	2	24	9	0	0	0	0	0	0	4.941908991581915	
i 1	243.73521768707482	0.7575000000000001	72	190	6	9	13	2	0	-2	2	0	0	2.4392260014518	
i 1	243.75108163265307	0.7575000000000001	71	892	4	20	4	1	0	0	1	0	0	0.941908991581915	
i 1	243.75324489795918	0.7575000000000001	68	688	4	20	3	1	0	0	1	0	0	0.941908991581915	
i 1	243.76766666666666	1.5150000000000001	75	892	6	2	1	2	0	1	2	0	0	3.4392260014518	
i 1	244.00973469387756	0.505	71	190	3	5	11	2	0	-2	2	0	0	7.0	
i 1	244.01189795918367	0.505	71	688	6	5	11	8	0	-2	8	0	0	7.0	
i 1	244.24675510204082	0.505	75	190	4	4	2	2	0	-2	2	0	0	3.4392260014518	
i 1	244.26189795918367	3.2825	71	190	6	5	8	8	0	-1	8	0	0	7.0	
i 1	244.26766666666666	0.2525	74	190	6	1	14	17	0	2	17	0	0	2.0	
i 1	244.4830544217687	0.505	72	576	5	3	2	2	0	-2	2	0	0	3.4392260014518	
i 1	244.4917074829932	0.2525	71	892	4	20	2	1	0	-1	1	0	0	0.941908991581915	
i 1	244.4996394557823	14.3925	61	576	5	15	14	6	0	2	6	0	0	3.2473156342679723	
i 1	244.50324489795918	0.7575000000000001	74	190	7	1	13	16	0	2	16	0	0	2.0	
i 1	244.50540816326532	2.7775	61	576	5	15	7	6	0	2	6	0	0	3.2473156342679723	
i 1	244.51045578231293	0.2525	68	576	4	20	15	0	0	0	0	0	0	0.941908991581915	
i 1	244.51261904761904	0.7575000000000001	74	576	4	24	5	17	0	2	17	0	0	3.0	
i 1	244.51261904761904	0.2525	71	190	4	24	2	1	0	-1	1	0	0	4.941908991581915	
i 1	244.5140612244898	0.505	71	190	7	5	16	2	0	-1	2	0	0	7.0	
i 1	244.73521768707482	1.7675	68	190	4	20	4	1	0	0	1	0	0	0.941908991581915	
i 1	244.74242857142858	3.2825	71	190	4	20	1	1	0	-1	1	0	0	0.941908991581915	
i 1	244.74531292517005	1.7675	68	190	4	20	9	0	0	-1	0	0	0	0.941908991581915	
i 1	244.99314965986395	3.7875	74	892	5	1	5	16	0	1	16	0	0	2.0	
i 1	244.99387074829932	3.7875	74	190	6	1	7	17	0	2	17	0	0	2.0	
i 1	244.9974761904762	0.2525	75	576	4	4	14	2	0	-2	2	0	0	3.4392260014518	
i 1	245.23810204081633	0.2525	71	190	7	5	7	2	0	-1	2	0	0	7.0	
i 1	245.24459183673468	1.2625	75	190	4	4	8	2	0	-2	2	0	0	3.4392260014518	
i 1	245.24531292517005	0.2525	77	892	5	1	6	16	0	2	16	0	0	2.0	
i 1	245.24819727891156	1.2625	72	576	5	3	15	2	0	-2	2	0	0	3.4392260014518	
i 1	245.25540816326532	0.505	75	892	6	2	4	2	0	-2	2	0	0	3.4392260014518	
i 1	245.50973469387756	0.2525	71	190	3	5	6	2	0	-2	2	0	0	7.0	
i 1	245.5111768707483	0.2525	74	190	7	1	4	17	0	1	17	0	0	2.0	
i 1	245.74675510204082	0.2525	72	190	6	9	13	2	0	-2	2	0	0	2.4392260014518	
i 1	245.9866598639456	0.2525	77	892	5	1	9	16	0	2	16	0	0	2.0	
i 1	246.01189795918367	0.2525	75	892	6	2	9	2	0	1	2	0	0	3.4392260014518	
i 1	246.24242857142858	1.2625	71	190	4	24	5	1	0	-1	1	0	0	4.941908991581915	
i 1	246.24675510204082	0.7575000000000001	75	892	6	2	13	2	0	-2	2	0	0	3.4392260014518	
i 1	246.25396598639455	0.2525	71	576	6	5	15	2	0	-1	2	0	0	7.0	
i 1	246.25757142857142	0.7575000000000001	72	190	6	9	7	2	0	-2	2	0	0	2.4392260014518	
i 1	246.2633401360544	1.2625	71	190	2	24	11	0	0	0	0	0	0	4.941908991581915	
i 1	246.50396598639455	0.2525	72	190	6	9	15	2	0	1	2	0	0	2.4392260014518	
i 1	246.50540816326532	0.2525	74	190	7	1	13	16	0	2	16	0	0	2.0	
i 1	246.73449659863945	0.7575000000000001	72	576	5	3	12	2	0	-2	2	0	0	3.4392260014518	
i 1	246.74242857142858	0.7575000000000001	74	576	4	24	6	17	0	2	17	0	0	3.0	
i 1	246.74819727891156	0.2525	74	892	6	5	14	2	0	-2	2	0	0	7.0	
i 1	246.75901360544216	0.505	75	190	4	4	12	2	0	-2	2	0	0	3.4392260014518	
i 1	246.99603401360545	4.04	68	190	4	20	5	1	0	0	1	0	0	0.941908991581915	
i 1	247.00757142857142	0.2525	71	190	7	5	5	8	0	-2	8	0	0	7.0	
i 1	247.00973469387756	1.01	68	190	4	20	7	0	0	-1	0	0	0	0.941908991581915	
i 1	247.01261904761904	1.01	75	190	5	3	15	2	0	-2	2	0	0	3.4392260014518	
i 1	247.24603401360545	11.615	61	576	5	25	10	6	0	1	6	0	0	1.0137921208505258	
i 1	247.2496394557823	0.7575000000000001	75	892	6	2	11	2	0	1	2	0	0	3.4392260014518	
i 1	247.25180272108844	0.505	75	190	5	4	7	2	0	-2	2	0	0	3.4392260014518	
i 1	247.25612925170068	9.3425	61	190	1	27	8	9	0	252	9	307	0	1.780346323935208	
i 1	247.26189795918367	11.615	61	576	5	15	7	6	0	2	6	0	0	3.2473156342679723	
i 1	247.26766666666666	11.615	61	892	5	14	3	9	0	1	9	0	0	4.175120101201679	
i 1	247.5025238095238	0.2525	77	892	5	1	3	16	0	2	16	0	0	2.0	
i 1	247.50612925170068	1.5150000000000001	74	892	6	5	1	2	0	-2	2	0	0	7.0	
i 1	247.50901360544216	1.5150000000000001	71	190	7	5	1	8	0	-2	8	0	0	7.0	
i 1	247.7359387755102	0.2525	74	190	7	1	1	17	0	1	17	0	0	2.0	
i 1	247.7366598639456	0.2525	68	190	2	20	14	1	0	-1	1	0	0	0.941908991581915	
i 1	247.73738095238096	0.7575000000000001	72	190	6	9	9	2	0	1	2	0	0	2.4392260014518	
i 1	247.75324489795918	0.7575000000000001	75	576	4	4	1	2	0	-2	2	0	0	3.4392260014518	
i 1	247.76622448979592	0.2525	71	190	7	5	4	2	0	-1	2	0	0	7.0	
i 1	247.98954421768707	0.2525	77	892	5	1	7	16	0	2	16	0	0	2.0	
i 1	247.99891836734693	0.505	68	576	4	20	7	0	0	0	0	0	0	0.941908991581915	
i 1	248.00324489795918	0.505	68	892	4	20	7	1	0	-1	1	0	0	0.941908991581915	
i 1	248.00468707482995	1.5150000000000001	75	190	5	4	13	2	0	-2	2	0	0	3.4392260014518	
i 1	248.00540816326532	1.5150000000000001	72	576	5	3	9	2	0	-2	2	0	0	3.4392260014518	
i 1	248.0169455782313	0.2525	74	576	6	5	9	2	0	-2	2	0	0	7.0	
i 1	248.23738095238096	2.2725	74	576	4	24	15	17	0	2	17	0	0	3.0	
i 1	248.2633401360544	2.2725	74	190	5	1	12	16	0	2	16	0	0	2.0	
i 1	248.48810204081633	1.7675	71	576	6	5	6	2	0	-1	2	0	0	7.0	
i 1	248.49026530612244	0.2525	71	190	2	20	12	0	0	-1	0	0	0	0.941908991581915	
i 1	248.49891836734693	1.7675	71	190	7	5	14	2	0	-1	2	0	0	7.0	
i 1	248.51550340136055	0.505	71	190	4	20	16	1	0	0	1	0	0	0.941908991581915	
i 1	248.73377551020408	0.2525	75	892	4	2	3	2	0	-2	2	0	0	3.4392260014518	
i 1	248.75901360544216	0.2525	71	190	4	20	1	0	0	-1	0	0	0	0.941908991581915	
i 1	248.7633401360544	0.7575000000000001	71	190	4	24	9	1	0	-1	1	0	0	4.941908991581915	
i 1	248.99026530612244	0.2525	71	892	4	20	6	1	0	0	1	0	0	0.941908991581915	
i 1	248.99242857142858	0.2525	71	190	6	5	2	8	0	-1	8	0	0	7.0	
i 1	248.99387074829932	1.2625	75	892	6	2	1	2	0	1	2	0	0	3.4392260014518	
i 1	248.99891836734693	0.2525	71	892	4	20	10	1	0	0	1	0	0	0.941908991581915	
i 1	249.01045578231293	1.2625	75	190	5	3	12	2	0	-2	2	0	0	3.4392260014518	
i 1	249.0140612244898	0.505	74	190	6	1	14	17	0	2	17	0	0	2.0	
i 1	249.24387074829932	0.2525	71	190	6	5	1	2	0	-2	2	0	0	7.0	
i 1	249.2496394557823	1.7675	71	190	4	20	5	1	0	0	1	0	0	0.941908991581915	
i 1	249.25396598639455	2.2725	68	190	4	20	11	1	0	-1	1	0	0	0.941908991581915	
i 1	249.49603401360545	0.2525	72	190	6	9	6	2	0	-2	2	0	0	2.4392260014518	
i 1	249.74603401360545	0.2525	74	190	7	1	12	17	0	1	17	0	0	2.0	
i 1	249.75108163265307	1.5150000000000001	74	892	6	5	4	2	0	-2	2	0	0	7.0	
i 1	249.75685034013605	1.5150000000000001	71	190	7	5	10	8	0	-2	8	0	0	7.0	
i 1	249.99026530612244	0.7575000000000001	75	892	4	2	2	2	0	-2	2	0	0	3.4392260014518	
i 1	249.9974761904762	1.01	75	190	5	4	2	2	0	-2	2	0	0	3.4392260014518	
i 1	250.00324489795918	5.555	74	190	6	1	15	17	0	2	17	0	0	2.0	
i 1	250.01189795918367	5.555	74	892	5	1	11	16	0	1	16	0	0	2.0	
i 1	250.0133401360544	0.7575000000000001	72	190	6	9	13	2	0	-2	2	0	0	2.4392260014518	
i 1	250.0169455782313	1.2625	72	576	5	3	13	2	0	-2	2	0	0	3.4392260014518	
i 1	250.49242857142858	0.2525	77	892	5	1	1	16	0	2	16	0	0	2.0	
i 1	250.49387074829932	2.02	75	190	5	3	9	2	0	-2	2	0	0	3.4392260014518	
i 1	250.49603401360545	1.01	68	190	2	24	2	0	0	0	0	0	0	4.941908991581915	
i 1	250.50685034013605	6.0600000000000005	71	190	4	24	15	1	0	-1	1	0	0	4.941908991581915	
i 1	250.50973469387756	2.2725	75	892	6	2	13	2	0	1	2	0	0	3.4392260014518	
i 1	250.51189795918367	0.2525	71	576	6	5	8	2	0	-1	2	0	0	7.0	
i 1	250.73449659863945	1.01	71	190	6	5	10	8	0	-1	8	0	0	7.0	
i 1	250.7388231292517	0.2525	74	190	5	24	4	17	0	1	17	0	0	3.0	
i 1	250.74026530612244	1.01	71	892	6	5	11	8	0	-1	8	0	0	7.0	
i 1	250.98810204081633	2.2725	71	576	6	5	13	2	0	-1	2	0	0	7.0	
i 1	250.99314965986395	2.2725	71	190	7	5	9	2	0	-1	2	0	0	7.0	
i 1	251.00180272108844	0.2525	74	576	4	24	6	17	0	2	17	0	0	3.0	
i 1	251.2330544217687	0.2525	74	190	5	24	3	17	0	1	17	0	0	3.0	
i 1	251.23738095238096	0.2525	72	190	6	9	2	2	0	-2	2	0	0	2.4392260014518	
i 1	251.23738095238096	0.7575000000000001	71	190	2	20	7	1	0	-1	1	0	0	0.941908991581915	
i 1	251.48738095238096	0.2525	71	892	4	20	15	0	0	-1	0	0	0	0.941908991581915	
i 1	251.49675510204082	0.2525	68	576	4	24	2	1	0	0	1	0	0	4.941908991581915	
i 1	251.4996394557823	0.2525	75	576	4	4	3	2	0	-2	2	0	0	3.4392260014518	
i 1	251.51189795918367	1.01	74	576	4	24	16	17	0	2	17	0	0	3.0	
i 1	251.51189795918367	1.01	74	190	5	1	12	16	0	2	16	0	0	2.0	
i 1	251.7359387755102	0.2525	72	190	6	9	1	2	0	-2	2	0	0	2.4392260014518	
i 1	251.73738095238096	1.5150000000000001	72	190	6	9	14	2	0	1	2	0	0	2.4392260014518	
i 1	251.7417074829932	0.2525	71	190	4	20	16	1	0	0	1	0	0	0.941908991581915	
i 1	251.7474761904762	1.7675	71	190	2	24	3	1	0	0	1	0	0	4.941908991581915	
i 1	251.7582925170068	0.2525	71	190	6	5	14	2	0	-2	2	0	0	7.0	
i 1	252.00396598639455	0.7575000000000001	71	190	1	24	5	0	0	248	0	308	0	4.941908991581915	
i 1	252.00685034013605	2.02	68	190	4	20	7	1	0	0	1	0	0	0.941908991581915	
i 1	252.0082925170068	1.2625	75	576	4	4	3	2	0	-2	2	0	0	3.4392260014518	
i 1	252.0133401360544	0.2525	71	190	6	5	8	8	0	-1	8	0	0	7.0	
i 1	252.25324489795918	2.2725	74	892	6	5	16	2	0	-2	2	0	0	7.0	
i 1	252.25540816326532	2.7775	71	190	2	20	8	1	0	-1	1	0	0	0.941908991581915	
i 1	252.25901360544216	1.01	68	190	2	20	15	1	0	-1	1	0	0	0.941908991581915	
i 1	252.26622448979592	1.01	71	190	4	20	8	0	0	0	0	0	0	0.941908991581915	
i 1	252.48521768707482	2.2725	71	190	7	5	15	8	0	-2	8	0	0	7.0	
i 1	252.51550340136055	0.2525	77	576	5	1	12	16	0	2	16	0	0	2.0	
i 1	252.73521768707482	2.7775	75	190	5	4	12	2	0	-2	2	0	0	3.4392260014518	
i 1	252.75685034013605	0.2525	77	892	5	1	6	16	0	2	16	0	0	2.0	
i 1	252.75973469387756	1.01	71	190	2	24	13	0	0	0	0	0	0	4.941908991581915	
i 1	252.7633401360544	2.7775	72	576	5	3	5	2	0	-2	2	0	0	3.4392260014518	
i 1	252.76550340136055	0.7575000000000001	71	190	4	20	9	1	0	0	1	0	0	0.941908991581915	
i 1	253.00468707482995	0.7575000000000001	75	892	4	2	4	2	0	1	2	0	0	3.4392260014518	
i 1	253.00540816326532	0.7575000000000001	75	190	5	3	6	2	0	-2	2	0	0	3.4392260014518	
i 1	253.00757142857142	5.8075	61	576	5	25	11	6	0	2	6	0	0	1.0137921208505258	
i 1	253.00901360544216	3.535	61	190	5	16	7	9	0	2	9	0	0	3.7112178677348253	
i 1	253.01550340136055	5.8075	66	892	5	13	8	9	0	1	9	0	0	2.783413400801119	
i 1	253.25468707482995	3.2825	71	190	6	5	10	8	0	-1	8	0	0	7.0	
i 1	253.26045578231293	0.2525	74	190	5	1	10	17	0	1	17	0	0	2.0	
i 1	253.50468707482995	0.505	74	576	4	24	7	17	0	2	17	0	0	3.0	
i 1	253.50540816326532	0.2525	71	576	4	24	5	1	0	-1	1	0	0	4.941908991581915	
i 1	253.50973469387756	1.2625	75	892	4	2	2	2	0	-2	2	0	0	3.4392260014518	
i 1	253.51478231292518	1.2625	72	190	6	9	11	2	0	-2	2	0	0	2.4392260014518	
i 1	253.51766666666666	0.2525	68	892	4	20	14	0	0	-1	0	0	0	0.941908991581915	
i 1	253.7359387755102	0.2525	74	190	5	24	7	17	0	1	17	0	0	3.0	
i 1	253.74603401360545	0.505	71	190	2	24	14	1	0	-1	1	0	0	4.941908991581915	
i 1	253.7496394557823	3.2825	71	892	6	5	15	8	0	-1	8	0	0	7.0	
i 1	253.75757142857142	0.2525	71	190	4	20	12	0	0	0	0	0	0	0.941908991581915	
i 1	254.0133401360544	0.505	74	190	5	1	13	16	0	2	16	0	0	2.0	
i 1	254.24314965986395	1.7675	71	190	2	24	11	0	0	0	0	0	0	4.941908991581915	
i 1	254.25180272108844	0.505	71	892	4	20	10	1	0	0	1	0	0	0.941908991581915	
i 1	254.25324489795918	0.505	68	576	4	24	4	1	0	-1	1	0	0	4.941908991581915	
i 1	254.5003605442177	0.2525	74	190	5	24	8	17	0	1	17	0	0	3.0	
i 1	254.73233333333334	1.7675	74	190	5	1	10	16	0	2	16	0	0	2.0	
i 1	254.73810204081633	1.01	68	190	2	24	2	1	0	-1	1	0	0	4.941908991581915	
i 1	254.74675510204082	0.2525	71	190	6	5	15	2	0	-2	2	0	0	7.0	
i 1	254.75757142857142	1.7675	75	190	5	3	11	2	0	-2	2	0	0	3.4392260014518	
i 1	254.75973469387756	3.535	74	576	4	24	10	17	0	2	17	0	0	3.0	
i 1	254.76550340136055	1.01	71	190	4	20	8	1	0	0	1	0	0	0.941908991581915	
i 1	254.7669455782313	0.2525	71	576	6	5	15	2	0	-1	2	0	0	7.0	
i 1	255.00540816326532	2.7775	75	892	4	2	16	2	0	1	2	0	0	3.4392260014518	
i 1	255.00901360544216	0.505	74	576	6	5	8	2	0	-2	2	0	0	7.0	
i 1	255.26261904761904	0.505	74	892	6	5	10	2	0	-2	2	0	0	7.0	
i 1	255.48377551020408	0.2525	75	892	4	2	3	2	0	-2	2	0	0	3.4392260014518	
i 1	255.50612925170068	1.01	71	190	2	20	5	1	0	-1	1	0	0	0.941908991581915	
i 1	255.50757142857142	0.2525	77	576	5	1	8	16	0	2	16	0	0	2.0	
i 1	255.50901360544216	1.01	68	190	4	20	7	1	0	0	1	0	0	0.941908991581915	
i 1	255.5140612244898	0.2525	77	892	5	1	15	16	0	2	16	0	0	2.0	
i 1	255.7496394557823	0.2525	71	576	6	5	13	2	0	-1	2	0	0	7.0	
i 1	255.75180272108844	0.2525	74	892	5	1	15	16	0	1	16	0	0	2.0	
i 1	255.75468707482995	0.7575000000000001	72	190	6	9	9	2	0	1	2	0	0	2.4392260014518	
i 1	255.75973469387756	0.505	71	892	4	20	8	1	0	0	1	0	0	0.941908991581915	
i 1	255.76189795918367	0.505	71	576	4	24	4	0	0	0	0	0	0	4.941908991581915	
i 1	255.76478231292518	0.7575000000000001	74	190	5	24	10	17	0	1	17	0	0	3.0	
i 1	255.76550340136055	1.01	75	576	4	4	13	2	0	-2	2	0	0	3.4392260014518	
i 1	255.9866598639456	0.2525	71	190	7	5	4	2	0	-1	2	0	0	7.0	
i 1	255.99819727891156	2.525	72	576	5	3	13	2	0	-2	2	0	0	3.4392260014518	
i 1	256.0032448979592	0.505	75	190	5	4	12	2	0	-2	2	0	0	3.4392260014518	
i 1	256.01261904761907	2.7775	74	892	6	5	15	2	0	-2	2	0	0	7.0	
i 1	256.23521768707485	0.2525	71	190	2	24	9	0	0	-1	0	0	0	4.941908991581915	
i 1	256.2388231292517	0.2525	71	190	7	5	3	8	0	-2	8	0	0	7.0	
i 1	256.2582925170068	0.2525	71	190	4	20	12	1	0	0	1	0	0	0.941908991581915	
i 1	256.4830544217687	2.2725	66	1158	4	16	12	9	0	1	9	0	0	3.7112178677348253	
i 1	256.48954421768707	2.2725	66	189	1	27	12	9	0	252	9	307	0	1.780346323935208	
i 1	256.48954421768707	0.505	71	1158	4	24	8	0	0	0	0	0	0	4.941908991581915	
i 1	256.4945918367347	0.2525	71	1158	4	20	16	0	0	-1	0	0	0	0.941908991581915	
i 1	256.4967551020408	0.2525	68	1158	4	20	13	0	0	0	0	0	0	0.941908991581915	
i 1	256.49819727891156	2.2725	61	189	5	12	1	6	0	2	6	0	0	3.7112178677348253	
i 1	256.49819727891156	1.5150000000000001	72	189	5	3	11	2	0	-2	2	0	0	3.4392260014518	
i 1	256.4996394557823	0.2525	77	189	5	24	3	16	0	2	16	0	0	3.0	
i 1	256.5003605442177	1.2625	71	189	2	24	3	0	0	-1	0	0	0	4.941908991581915	
i 1	256.50108163265304	2.2725	61	1158	4	16	14	9	0	2	9	0	0	3.7112178677348253	
i 1	256.50180272108844	2.2725	72	189	5	4	1	2	0	1	2	0	0	3.4392260014518	
i 1	256.5039659863946	2.2725	71	1158	6	5	9	8	0	-1	8	0	0	7.0	
i 1	256.5054081632653	0.505	71	189	6	5	2	8	0	-2	8	0	0	7.0	
i 1	256.51045578231293	1.5150000000000001	74	1158	5	1	12	16	0	2	16	0	0	2.0	
i 1	256.51478231292515	2.2725	66	189	5	12	9	6	0	1	6	0	0	3.7112178677348253	
i 1	256.5169455782313	0.2525	72	1158	5	9	1	2	0	1	2	0	0	2.4392260014518	
i 1	256.5169455782313	2.2725	66	189	1	27	11	6	0	248	6	308	0	1.780346323935208	
i 1	256.5176666666667	2.2725	68	189	2	20	7	0	0	-1	0	0	0	0.941908991581915	
i 1	256.73738095238093	0.2525	68	1158	4	20	14	0	0	0	0	0	0	0.941908991581915	
i 1	256.7496394557823	6.0600000000000005	74	892	5	1	6	16	0	1	16	0	0	2.0	
i 1	256.7676666666667	0.2525	77	1158	5	1	5	16	0	2	16	0	0	2.0	
i 1	257.01550340136055	0.505	74	576	6	5	1	2	0	-2	2	0	0	7.0	
i 1	257.01550340136055	0.7575000000000001	71	1158	4	20	2	0	0	-1	0	0	0	0.941908991581915	
i 1	257.0176666666667	1.7675	77	189	6	1	15	16	0	2	16	0	0	2.0	
i 1	257.2417074829932	1.5150000000000001	71	1158	6	5	16	2	0	-2	2	0	0	7.0	
i 1	257.24242857142855	1.2625	71	1158	4	24	12	0	0	0	0	0	0	4.941908991581915	
i 1	257.2532448979592	1.2625	71	189	2	24	11	1	0	-1	1	0	0	4.941908991581915	
i 1	257.48954421768707	4.545	68	1158	4	20	11	0	0	0	0	0	0	0.941908991581915	
i 1	257.49747619047616	0.7575000000000001	71	576	6	5	2	2	0	-1	2	0	0	7.0	
i 1	257.74387074829934	0.2525	68	576	4	24	3	1	0	0	1	0	0	4.941908991581915	
i 1	257.75973469387753	0.2525	68	892	4	20	15	0	0	-1	0	0	0	0.941908991581915	
i 1	257.99242857142855	0.7575000000000001	75	892	4	2	4	2	0	-2	2	0	0	3.4392260014518	
i 1	257.99242857142855	0.7575000000000001	68	189	2	24	1	1	0	0	1	0	0	4.941908991581915	
i 1	258.0003605442177	4.2925	71	1158	4	20	16	1	0	0	1	0	0	0.941908991581915	
i 1	258.0082925170068	0.505	77	892	5	1	9	16	0	2	16	0	0	2.0	
i 1	258.00973469387753	0.7575000000000001	72	1158	5	9	4	8	0	1	8	0	0	2.4392260014518	
i 1	258.24026530612247	0.2525	77	1158	5	1	2	16	0	2	16	0	0	2.0	
i 1	258.24242857142855	0.505	74	576	6	5	4	2	0	-2	2	0	0	7.0	
i 1	258.48449659863945	1.2625	74	1158	5	1	7	16	0	2	16	0	0	2.0	
i 1	258.4945918367347	1.2625	74	576	4	24	3	17	0	2	17	0	0	3.0	
i 1	258.4945918367347	0.2525	72	189	5	3	9	2	0	-2	2	0	0	3.4392260014518	
i 1	258.73521768707485	15.9075	61	576	5	25	14	6	0	2	6	0	0	0.04036883330323932	
i 1	258.74242857142855	0.2525	74	576	6	5	14	2	0	-2	2	0	0	3.0	
i 1	258.74314965986395	15.9075	61	576	5	13	2	9	0	2	9	0	0	1.4105596104834164	
i 1	258.7453129251701	1.2625	71	1158	6	5	4	8	0	-1	8	0	0	3.0	
i 1	258.7460340136054	0.505	75	892	4	2	15	2	0	-2	2	0	0	3.2846036643348273	
i 1	258.74747619047616	0.505	72	1158	5	9	15	8	0	1	8	0	0	2.2846036643348273	
i 1	258.7496394557823	11.615	66	892	5	25	3	9	0	1	9	0	0	0.04036883330323932	
i 1	258.7496394557823	11.615	61	576	5	25	12	6	0	1	6	0	0	0.04036883330323932	
i 1	258.7503605442177	2.7775	71	892	6	5	9	8	0	-1	8	0	0	3.0	
i 1	258.7554081632653	1.2625	74	892	6	5	5	2	0	-2	2	0	0	3.0	
i 1	258.75685034013605	4.7975	72	576	4	3	13	2	0	-2	2	0	0	3.2846036643348273	
i 1	258.75685034013605	0.2525	71	189	2	24	9	1	0	-1	1	0	0	4.941908991581915	
i 1	258.7611768707483	15.9075	66	1158	4	26	6	9	0	1	9	0	0	0.04036883330323932	
i 1	258.76261904761907	5.8075	61	576	4	7	3	6	0	2	6	0	0	4.2316788314502505	
i 1	258.76550340136055	5.8075	61	892	5	25	16	6	0	1	6	0	0	0.04036883330323932	
i 1	258.76622448979595	5.05	72	189	5	4	10	2	0	1	2	0	0	3.2846036643348273	
i 1	258.76622448979595	5.8075	61	892	5	14	7	9	0	2	9	0	0	5.642238441933668	
i 1	258.7669455782313	4.545	77	189	3	1	12	16	0	2	16	0	0	2.0	
i 1	258.7669455782313	11.615	66	892	5	14	1	9	0	2	9	0	0	5.642238441933668	
i 1	259.0003605442177	1.01	75	892	4	2	15	2	0	1	2	0	0	3.2846036643348273	
i 1	259.00612925170066	1.2625	68	189	2	20	3	0	0	-1	0	0	0	0.941908991581915	
i 1	259.00973469387753	1.2625	68	189	2	24	3	1	0	0	1	0	0	4.941908991581915	
i 1	259.01261904761907	1.01	72	189	5	3	9	2	0	-2	2	0	0	3.2846036643348273	
i 1	259.2640612244898	2.2725	71	189	6	5	2	8	0	-2	8	0	0	3.0	
i 1	259.4830544217687	1.2625	72	1158	5	9	12	2	0	1	2	0	0	2.2846036643348273	
i 1	259.50180272108844	1.2625	75	576	4	4	1	2	0	-2	2	0	0	3.2846036643348273	
i 1	259.5039659863946	2.525	71	189	2	20	16	1	0	0	1	0	0	0.941908991581915	
i 1	259.50685034013605	2.525	71	189	2	24	6	1	0	-1	1	0	0	4.941908991581915	
i 1	259.76622448979595	0.2525	77	189	5	24	6	16	0	2	16	0	0	3.0	
i 1	259.98449659863945	0.505	74	576	6	5	13	2	0	-2	2	0	0	3.0	
i 1	260.0140612244898	0.2525	77	1158	5	1	6	16	0	2	16	0	0	2.0	
i 1	260.26189795918367	0.2525	77	576	5	1	1	16	0	2	16	0	0	2.0	
i 1	260.49387074829934	2.2725	71	576	6	5	4	2	0	-1	2	0	0	3.0	
i 1	260.49891836734696	2.2725	71	1158	6	5	4	2	0	-2	2	0	0	3.0	
i 1	260.7366598639456	0.2525	74	576	4	24	15	17	0	2	17	0	0	3.0	
i 1	260.7388231292517	5.3025	72	189	5	3	10	2	0	-2	2	0	0	3.2846036643348273	
i 1	260.75973469387753	5.3025	75	892	4	2	2	2	0	1	2	0	0	3.2846036643348273	
i 1	261.24387074829934	0.2525	77	892	5	1	5	16	0	2	16	0	0	2.0	
i 1	261.2467551020408	3.7875	68	189	2	24	10	1	0	0	1	0	0	4.941908991581915	
i 1	261.2546870748299	5.3025	74	576	4	24	11	17	0	2	17	0	0	3.0	
i 1	261.2546870748299	2.02	68	189	2	20	1	0	0	-1	0	0	0	0.941908991581915	
i 1	261.4945918367347	5.3025	74	892	6	5	12	2	0	-2	2	0	0	3.0	
i 1	261.4945918367347	0.2525	74	189	6	5	8	8	0	-2	8	0	0	3.0	
i 1	261.50973469387753	5.05	74	1158	5	1	10	16	0	2	16	0	0	2.0	
i 1	261.75757142857145	5.05	71	1158	6	5	10	8	0	-1	8	0	0	3.0	
i 1	261.76189795918367	1.2625	72	1158	5	9	3	8	0	1	8	0	0	2.2846036643348273	
i 1	261.7669455782313	1.2625	75	892	4	2	1	2	0	-2	2	0	0	3.2846036643348273	
i 1	262.01261904761907	0.2525	71	1158	4	24	3	0	0	0	0	0	0	4.941908991581915	
i 1	262.25685034013605	4.04	71	189	2	24	2	1	0	-1	1	0	0	4.941908991581915	
i 1	262.2590136054422	3.0300000000000002	71	189	2	20	14	1	0	0	1	0	0	0.941908991581915	
i 1	262.7467551020408	0.2525	74	576	6	5	6	2	0	-2	2	0	0	3.0	
i 1	262.75108163265304	2.525	71	189	6	5	8	8	0	-2	8	0	0	3.0	
i 1	262.76261904761907	0.2525	77	1158	5	1	8	16	0	2	16	0	0	2.0	
i 1	263.00973469387753	2.2725	71	892	6	5	5	8	0	-1	8	0	0	3.0	
i 1	263.01261904761907	0.2525	77	576	5	1	7	16	0	2	16	0	0	2.0	
i 1	263.2359387755102	0.2525	68	1158	4	20	4	0	0	-1	0	0	0	0.941908991581915	
i 1	263.26189795918367	0.7575000000000001	77	1158	5	1	15	16	0	2	16	0	0	2.0	
i 1	263.48521768707485	5.3025	68	1158	4	20	11	0	0	0	0	0	0	0.941908991581915	
i 1	263.4953129251701	1.01	75	576	4	4	14	2	0	-2	2	0	0	3.2846036643348273	
i 1	263.5046870748299	1.5150000000000001	68	189	2	20	2	0	0	-1	0	0	0	0.941908991581915	
i 1	263.5082925170068	1.7675	71	1158	4	20	11	1	0	0	1	0	0	0.941908991581915	
i 1	263.7417074829932	1.7675	72	1158	5	9	6	2	0	1	2	0	0	2.2846036643348273	
i 1	263.9823333333333	0.2525	77	892	5	1	11	16	0	2	16	0	0	2.0	
i 1	263.9917074829932	0.2525	77	576	5	1	6	16	0	2	16	0	0	2.0	
i 1	264.2539659863946	6.0600000000000005	77	189	3	1	2	16	0	2	16	0	0	2.0	
i 1	264.25685034013605	5.8075	74	892	5	1	3	16	0	1	16	0	0	2.0	
i 1	264.5003605442177	10.1	61	892	5	25	4	6	0	1	6	0	0	0.04036883330323932	
i 1	264.5046870748299	3.2825	72	189	5	4	1	2	0	1	2	0	0	3.2846036643348273	
i 1	264.5054081632653	10.1	66	1158	4	26	14	9	0	2	9	0	0	0.04036883330323932	
i 1	264.5054081632653	10.1	61	576	6	7	7	6	0	2	6	0	0	4.2316788314502505	
i 1	264.51045578231293	10.1	61	892	5	14	16	9	0	2	9	0	0	5.642238441933668	
i 1	264.51261904761907	1.01	75	576	4	4	6	2	0	-2	2	0	0	3.2846036643348273	
i 1	264.5169455782313	3.2825	72	576	4	3	12	2	0	-2	2	0	0	3.2846036643348273	
i 1	265.23521768707485	1.01	68	892	4	20	10	0	0	0	0	0	0	0.941908991581915	
i 1	265.24314965986395	0.505	74	576	6	5	16	2	0	-2	2	0	0	3.0	
i 1	265.2460340136054	1.2625	68	892	1	20	1	0	0	-1	0	0	0	0.941908991581915	
i 1	265.24819727891156	0.505	71	576	4	20	13	1	0	-1	1	0	0	0.941908991581915	
i 1	265.2503605442177	0.2525	74	189	6	5	16	8	0	-2	8	0	0	3.0	
i 1	265.25180272108844	1.2625	71	576	4	24	4	1	0	0	1	0	0	4.941908991581915	
i 1	265.25685034013605	3.535	71	1158	4	24	11	0	0	0	0	0	0	4.941908991581915	
i 1	265.2590136054422	1.5150000000000001	72	1158	5	9	7	8	0	1	8	0	0	2.2846036643348273	
i 1	265.26478231292515	1.5150000000000001	75	892	4	2	2	2	0	-2	2	0	0	3.2846036643348273	
i 1	265.50973469387753	2.7775	71	576	6	5	15	2	0	-1	2	0	0	3.0	
i 1	265.74891836734696	2.7775	71	1158	6	5	4	2	0	-2	2	0	0	3.0	
i 1	266.00757142857145	3.0300000000000002	68	189	2	20	8	0	0	-1	0	0	0	0.941908991581915	
i 1	266.4953129251701	0.7575000000000001	71	1158	1	20	9	1	0	-1	1	0	0	0.941908991581915	
i 1	266.4960340136054	0.505	77	189	3	24	13	16	0	2	16	0	0	3.0	
i 1	266.51478231292515	0.2525	77	892	4	1	10	16	0	2	16	0	0	2.0	
i 1	266.5169455782313	0.7575000000000001	68	189	2	24	7	0	0	-1	0	0	0	4.941908991581915	
i 1	266.7323333333333	3.0300000000000002	72	189	5	3	3	2	0	-2	2	0	0	3.2846036643348273	
i 1	266.73449659863945	3.0300000000000002	75	892	4	2	1	2	0	1	2	0	0	3.2846036643348273	
i 1	266.7359387755102	0.2525	77	1158	5	1	4	16	0	2	16	0	0	2.0	
i 1	266.7409863945578	0.505	68	189	2	20	16	1	0	0	1	0	0	0.941908991581915	
i 1	266.7554081632653	0.505	68	1158	4	20	12	0	0	-1	0	0	0	0.941908991581915	
i 1	266.75973469387753	0.2525	71	189	6	5	11	8	0	-2	8	0	0	3.0	
i 1	266.76550340136055	0.2525	74	189	6	5	4	8	0	-2	8	0	0	3.0	
i 1	266.7669455782313	7.8275	71	189	2	24	7	1	0	-1	1	0	0	4.941908991581915	
i 1	267.00685034013605	0.505	74	1158	5	1	10	16	0	2	16	0	0	2.0	
i 1	267.0090136054422	0.2525	74	576	6	5	14	2	0	-2	2	0	0	3.0	
i 1	267.0111768707483	2.525	71	1158	6	5	11	8	0	-1	8	0	0	3.0	
i 1	267.2554081632653	0.2525	68	892	1	20	7	1	0	-1	1	0	0	0.941908991581915	
i 1	267.25612925170066	0.2525	68	576	4	24	16	1	0	-1	1	0	0	4.941908991581915	
i 1	267.25757142857145	0.2525	68	576	4	20	8	0	0	0	0	0	0	0.941908991581915	
i 1	267.26478231292515	2.2725	74	892	6	5	16	2	0	-2	2	0	0	3.0	
i 1	267.2669455782313	0.2525	71	892	4	20	7	0	0	-1	0	0	0	0.941908991581915	
i 1	267.49747619047616	0.2525	71	189	2	20	5	0	0	-1	0	0	0	0.941908991581915	
i 1	267.50108163265304	0.2525	68	1158	1	20	2	1	0	-1	1	0	0	0.941908991581915	
i 1	267.50757142857145	0.2525	71	189	2	24	15	1	0	-1	1	0	0	4.941908991581915	
i 1	267.5082925170068	0.2525	71	1158	4	20	7	0	0	0	0	0	0	0.941908991581915	
i 1	267.50973469387753	0.2525	74	576	4	24	1	17	0	2	17	0	0	3.0	
i 1	267.7503605442177	0.505	71	576	4	20	7	0	0	0	0	0	0	0.941908991581915	
i 1	267.75252380952384	0.505	71	892	4	20	1	1	0	0	1	0	0	0.941908991581915	
i 1	267.7532448979592	1.2625	75	576	4	4	7	2	0	-2	2	0	0	3.2846036643348273	
i 1	267.75685034013605	0.505	68	576	4	24	14	1	0	-1	1	0	0	4.941908991581915	
i 1	267.75757142857145	0.505	68	892	1	20	6	1	0	0	1	0	0	0.941908991581915	
i 1	267.76189795918367	0.7575000000000001	77	576	5	1	4	16	0	2	16	0	0	2.0	
i 1	267.7633401360544	1.2625	72	1158	5	9	16	2	0	1	2	0	0	2.2846036643348273	
i 1	267.98738095238093	6.565	72	189	5	4	1	2	0	1	2	0	0	3.2846036643348273	
i 1	268.01189795918367	6.565	72	576	4	3	3	2	0	-2	2	0	0	3.2846036643348273	
i 1	268.01550340136055	0.2525	74	1158	5	1	9	16	0	2	16	0	0	2.0	
i 1	268.2366598639456	0.2525	74	576	6	5	16	2	0	-2	2	0	0	3.0	
i 1	268.23810204081633	0.505	77	189	3	24	7	16	0	2	16	0	0	3.0	
i 1	268.24747619047616	3.0300000000000002	68	189	2	20	12	1	0	0	1	0	0	0.941908991581915	
i 1	268.2633401360544	1.01	68	189	2	24	5	1	0	-1	1	0	0	4.941908991581915	
i 1	268.2640612244898	0.505	68	1158	1	20	4	0	0	0	0	0	0	0.941908991581915	
i 1	268.50108163265304	2.2725	71	892	6	5	5	8	0	-1	8	0	0	3.0	
i 1	268.51622448979595	3.535	74	1158	5	1	8	16	0	2	16	0	0	2.0	
i 1	268.5169455782313	2.2725	71	189	6	5	1	8	0	-2	8	0	0	3.0	
i 1	268.73521768707485	0.2525	77	1158	5	1	15	16	0	2	16	0	0	2.0	
i 1	268.9859387755102	0.2525	71	1158	4	24	14	0	0	0	0	0	0	4.941908991581915	
i 1	269.0003605442177	2.7775	74	576	4	24	3	17	0	2	17	0	0	3.0	
i 1	269.23449659863945	1.5150000000000001	71	1158	1	24	14	0	0	252	0	307	0	4.941908991581915	
i 1	269.23521768707485	2.525	68	1158	4	20	16	0	0	0	0	0	0	0.941908991581915	
i 1	269.2409863945578	0.2525	68	1158	1	20	15	0	0	0	0	0	0	0.941908991581915	
i 1	269.50108163265304	0.7575000000000001	71	1158	4	20	4	1	0	-1	1	0	0	0.941908991581915	
i 1	269.50252380952384	0.2525	74	576	6	5	11	2	0	-2	2	0	0	3.0	
i 1	269.5133401360544	2.2725	71	576	6	5	4	2	0	-1	2	0	0	3.0	
i 1	269.75612925170066	0.505	75	892	4	2	10	2	0	-2	2	0	0	3.2846036643348273	
i 1	269.75973469387753	2.02	71	1158	6	5	11	2	0	-2	2	0	0	3.0	
i 1	269.76622448979595	1.7675	72	1158	5	9	3	8	0	1	8	0	0	2.2846036643348273	
i 1	270.00685034013605	0.2525	77	189	3	24	3	16	0	2	16	0	0	3.0	
i 1	270.2388231292517	4.2925	61	576	5	25	10	6	0	1	6	0	0	0.04036883330323932	
i 1	270.2460340136054	0.2525	77	1158	5	1	10	16	0	2	16	0	0	2.0	
i 1	270.2467551020408	4.2925	66	189	3	27	8	9	0	2	9	0	0	0.8069230363879212	
i 1	270.25252380952384	1.2625	75	892	6	2	1	2	0	-2	2	0	0	3.2846036643348273	
i 1	270.25757142857145	1.01	71	1158	1	20	5	1	0	-1	1	0	0	0.941908991581915	
i 1	270.2611768707483	4.2925	66	892	5	14	7	9	0	2	9	0	0	5.642238441933668	
i 1	270.2669455782313	0.505	77	576	5	1	9	16	0	2	16	0	0	2.0	
i 1	270.5133401360544	0.2525	77	892	4	1	7	16	0	2	16	0	0	2.0	
i 1	270.73377551020405	1.2625	71	1158	6	5	16	8	0	-1	8	0	0	3.0	
i 1	270.74026530612247	3.7875	74	892	4	1	3	16	0	1	16	0	0	2.0	
i 1	270.7409863945578	1.5150000000000001	72	189	5	3	5	2	0	-2	2	0	0	3.2846036643348273	
i 1	270.75180272108844	2.2725	71	1158	4	24	12	0	0	0	0	0	0	4.941908991581915	
i 1	270.7554081632653	1.2625	74	892	6	5	7	2	0	-2	2	0	0	3.0	
i 1	270.75612925170066	0.505	68	189	2	24	5	1	0	-1	1	0	0	4.941908991581915	
i 1	270.75757142857145	3.7875	77	189	3	1	16	16	0	2	16	0	0	2.0	
i 1	270.7676666666667	1.5150000000000001	75	892	4	2	4	2	0	1	2	0	0	3.2846036643348273	
i 1	270.9830544217687	2.02	68	189	2	20	16	0	0	-1	0	0	0	0.941908991581915	
i 1	270.99314965986395	3.535	71	892	6	5	16	8	0	-1	8	0	0	3.0	
i 1	271.0169455782313	3.535	71	189	6	5	15	8	0	-2	8	0	0	3.0	
i 1	271.23377551020405	1.5150000000000001	72	1158	4	9	1	2	0	1	2	0	0	2.2846036643348273	
i 1	271.24242857142855	0.2525	68	576	4	24	9	0	0	-1	0	0	0	4.941908991581915	
i 1	271.2460340136054	1.5150000000000001	75	576	4	4	9	2	0	-2	2	0	0	3.2846036643348273	
i 1	271.2467551020408	0.2525	71	576	4	20	1	1	0	0	1	0	0	0.941908991581915	
i 1	271.25973469387753	0.2525	71	892	1	20	13	1	0	0	1	0	0	0.941908991581915	
i 1	271.5054081632653	0.7575000000000001	71	189	2	24	16	0	0	-1	0	0	0	4.941908991581915	
i 1	271.5090136054422	0.7575000000000001	68	189	2	20	12	1	0	-1	1	0	0	0.941908991581915	
i 1	271.5133401360544	0.7575000000000001	68	1158	1	20	11	1	0	-1	1	0	0	0.941908991581915	
i 1	271.7633401360544	0.505	77	576	5	1	9	16	0	2	16	0	0	2.0	
i 1	271.98738095238093	1.7675	74	576	4	24	12	17	0	2	17	0	0	3.0	
i 1	271.9945918367347	2.525	68	1158	4	20	7	0	0	0	0	0	0	0.941908991581915	
i 1	271.9953129251701	0.2525	74	189	6	5	5	8	0	-2	8	0	0	3.0	
i 1	272.0003605442177	0.505	71	1158	6	5	6	2	0	-2	2	0	0	3.0	
i 1	272.23449659863945	0.2525	68	576	4	20	13	1	0	-1	1	0	0	0.941908991581915	
i 1	272.2453129251701	0.2525	71	892	1	20	13	1	0	0	1	0	0	0.941908991581915	
i 1	272.2539659863946	1.5150000000000001	74	1158	5	1	14	16	0	2	16	0	0	2.0	
i 1	272.2640612244898	0.2525	71	576	4	24	12	1	0	0	1	0	0	4.941908991581915	
i 1	272.26550340136055	0.2525	74	892	6	5	4	2	0	-2	2	0	0	3.0	
i 1	272.4909863945578	0.2525	71	576	6	5	14	2	0	-1	2	0	0	3.0	
i 1	272.4953129251701	0.505	68	189	2	24	2	1	0	-1	1	0	0	4.941908991581915	
i 1	272.49819727891156	0.505	74	576	6	5	7	2	0	-2	2	0	0	3.0	
i 1	272.50108163265304	0.7575000000000001	68	1158	1	20	14	1	0	0	1	0	0	0.941908991581915	
i 1	272.51478231292515	0.7575000000000001	68	189	2	20	6	1	0	-1	1	0	0	0.941908991581915	
i 1	272.74314965986395	1.7675	72	189	5	3	10	2	0	-2	2	0	0	3.2846036643348273	
i 1	272.7467551020408	0.7575000000000001	74	892	6	5	2	2	0	-2	2	0	0	3.0	
i 1	272.7611768707483	1.7675	75	892	4	2	2	2	0	1	2	0	0	3.2846036643348273	
i 1	272.9866598639456	0.2525	71	576	6	5	11	2	0	-1	2	0	0	3.0	
i 1	273.2417074829932	0.2525	71	576	4	20	15	1	0	0	1	0	0	0.941908991581915	
i 1	273.24387074829934	0.2525	71	892	1	20	9	0	0	-1	0	0	0	0.941908991581915	
i 1	273.24891836734696	0.505	71	1158	6	5	12	8	0	-1	8	0	0	3.0	
i 1	273.48810204081633	0.2525	74	576	6	5	13	2	0	-2	2	0	0	3.0	
i 1	273.50685034013605	1.01	68	189	2	20	9	1	0	0	1	0	0	0.941908991581915	
i 1	273.5140612244898	1.01	71	1158	1	20	8	1	0	-1	1	0	0	0.941908991581915	
i 1	273.73449659863945	0.2525	71	1158	6	5	2	2	0	-2	2	0	0	3.0	
i 1	273.73738095238093	0.2525	74	892	6	5	7	2	0	-2	2	0	0	3.0	
i 1	273.73810204081633	0.7575000000000001	75	892	6	2	11	2	0	-2	2	0	0	3.2846036643348273	
i 1	273.74242857142855	0.7575000000000001	71	189	2	24	7	0	0	0	0	0	0	4.941908991581915	
i 1	273.7460340136054	0.7575000000000001	68	189	2	20	14	0	0	-1	0	0	0	0.941908991581915	
i 1	273.7611768707483	0.2525	77	189	3	24	8	16	0	2	16	0	0	3.0	
i 1	273.76261904761907	0.7575000000000001	72	1158	5	9	4	8	0	1	8	0	0	2.2846036643348273	
i 1	273.7640612244898	0.7575000000000001	77	1158	5	1	8	16	0	2	16	0	0	2.0	
i 1	273.99026530612247	0.505	71	1158	4	24	7	0	0	0	0	0	0	4.941908991581915	
i 1	273.9967551020408	0.505	74	576	4	24	6	17	0	2	17	0	0	3.0	
i 1	274.01261904761907	0.505	71	576	6	5	14	2	0	-1	2	0	0	3.0	
i 1	274.0176666666667	0.505	74	189	6	5	4	8	0	-2	8	0	0	3.0	
i 1	274.4830544217687	6.0600000000000005	77	203	5	24	6	17	0	1	17	0	0	3.0	
i 1	274.48377551020405	0.2525	71	203	4	24	9	0	0	-1	0	0	0	4.941908991581915	
i 1	274.48449659863945	13.13	61	1087	4	26	9	6	0	2	6	0	0	0.04036883330323932	
i 1	274.4866598639456	0.2525	68	203	4	20	10	1	0	-1	1	0	0	0.941908991581915	
i 1	274.48738095238093	18.9375	66	701	3	27	12	6	0	2	6	0	0	0.8069230363879212	
i 1	274.48810204081633	1.5150000000000001	61	701	5	25	6	6	0	1	6	0	0	0.04036883330323932	
i 1	274.4888231292517	7.3225	68	1087	3	20	14	0	0	0	0	0	0	0.941908991581915	
i 1	274.48954421768707	0.7575000000000001	71	1087	3	24	12	1	0	-1	1	0	0	4.941908991581915	
i 1	274.49026530612247	13.13	66	701	5	14	13	9	0	2	9	0	0	5.642238441933668	
i 1	274.4909863945578	0.2525	75	203	4	3	2	2	0	1	2	0	0	3.2846036643348273	
i 1	274.4909863945578	1.7675	71	701	6	5	7	2	0	-1	2	0	0	3.0	
i 1	274.4917074829932	6.0600000000000005	74	701	3	24	14	16	0	1	16	0	0	3.0	
i 1	274.49242857142855	1.01	77	1087	4	1	11	17	0	2	17	0	0	2.0	
i 1	274.49387074829934	0.7575000000000001	74	701	6	5	3	8	0	-1	8	0	0	3.0	
i 1	274.4967551020408	0.7575000000000001	71	701	6	5	16	8	0	-2	8	0	0	3.0	
i 1	274.4967551020408	1.5150000000000001	66	203	6	13	2	6	0	2	6	0	0	1.4105596104834164	
i 1	274.49747619047616	1.2625	75	701	4	2	9	2	0	1	2	0	0	3.2846036643348273	
i 1	274.49747619047616	1.2625	75	1087	5	9	5	2	0	-2	2	0	0	2.2846036643348273	
i 1	274.4996394557823	18.9375	61	701	5	14	13	6	0	1	6	0	0	5.642238441933668	
i 1	274.5003605442177	0.2525	71	701	1	20	5	0	0	0	0	0	0	0.941908991581915	
i 1	274.50108163265304	7.3225	61	1087	4	26	15	9	0	1	9	0	0	0.04036883330323932	
i 1	274.50180272108844	2.2725	72	701	4	4	1	2	0	-2	2	0	0	3.2846036643348273	
i 1	274.50252380952384	1.7675	74	203	7	5	14	8	0	-2	8	0	0	3.0	
i 1	274.5032448979592	1.5150000000000001	66	203	5	25	3	9	0	2	9	0	0	0.04036883330323932	
i 1	274.5032448979592	1.5150000000000001	61	701	1	27	3	6	0	252	6	307	0	0.8069230363879212	
i 1	274.5032448979592	2.525	71	701	2	24	6	1	0	0	1	0	0	4.941908991581915	
i 1	274.5054081632653	1.01	77	701	4	1	11	16	0	2	16	0	0	2.0	
i 1	274.50612925170066	7.3225	61	203	6	7	7	6	0	2	6	0	0	4.2316788314502505	
i 1	274.51189795918367	7.3225	66	203	6	25	1	6	0	2	6	0	0	0.04036883330323932	
i 1	274.51189795918367	3.2825	71	701	2	20	4	0	0	0	0	0	0	0.941908991581915	
i 1	274.51478231292515	0.505	77	701	3	1	16	17	0	1	17	0	0	2.0	
i 1	274.5176666666667	0.505	72	701	6	2	5	2	0	1	2	0	0	3.2846036643348273	
i 1	274.74387074829934	0.7575000000000001	68	701	2	24	1	0	0	-1	0	0	0	4.941908991581915	
i 1	274.7460340136054	2.02	75	203	4	4	10	2	0	-2	2	0	0	3.2846036643348273	
i 1	274.9996394557823	0.505	71	701	2	20	15	1	0	0	1	0	0	0.941908991581915	
i 1	275.25108163265304	2.2725	71	701	6	5	1	8	0	-2	8	0	0	3.0	
i 1	275.26550340136055	2.2725	74	1087	6	5	10	8	0	-2	8	0	0	3.0	
i 1	275.4945918367347	0.2525	74	701	4	1	9	16	0	2	16	0	0	2.0	
i 1	275.5039659863946	0.2525	77	203	5	1	4	16	0	2	16	0	0	2.0	
i 1	275.5082925170068	0.2525	68	701	1	20	15	1	0	0	1	0	0	0.941908991581915	
i 1	275.5090136054422	0.2525	68	203	4	20	13	0	0	0	0	0	0	0.941908991581915	
i 1	275.7330544217687	3.535	75	203	4	3	4	2	0	1	2	0	0	3.2846036643348273	
i 1	275.7359387755102	0.2525	77	701	4	1	2	16	0	2	16	0	0	2.0	
i 1	275.75180272108844	0.505	77	1087	4	1	11	17	0	2	17	0	0	2.0	
i 1	275.75180272108844	0.2525	68	701	2	20	4	1	0	-1	1	0	0	0.941908991581915	
i 1	275.7582925170068	3.0300000000000002	75	701	5	3	5	2	0	1	2	0	0	3.2846036643348273	
i 1	275.9953129251701	0.505	77	203	4	1	12	16	0	2	16	0	0	2.0	
i 1	276.0003605442177	11.615	66	203	6	25	2	9	0	2	9	0	0	0.04036883330323932	
i 1	276.00252380952384	23.23	66	203	5	13	11	6	0	2	6	0	0	1.4105596104834164	
i 1	276.00685034013605	1.7675	71	701	2	24	12	0	0	0	0	0	0	4.941908991581915	
i 1	276.0140612244898	23.23	61	701	3	27	3	6	0	1	6	0	0	0.8069230363879212	
i 1	276.23810204081633	0.2525	74	203	7	5	9	8	0	-1	8	0	0	3.0	
i 1	276.2633401360544	0.2525	77	1087	4	1	2	17	0	2	17	0	0	2.0	
i 1	276.26478231292515	0.2525	71	701	6	5	3	8	0	-2	8	0	0	3.0	
i 1	276.4859387755102	0.2525	77	1087	4	1	6	17	0	2	17	0	0	2.0	
i 1	276.49242857142855	2.02	74	701	6	5	1	8	0	-1	8	0	0	3.0	
i 1	276.50973469387753	0.2525	77	701	4	1	8	16	0	2	16	0	0	2.0	
i 1	276.5111768707483	4.7975	75	1087	3	9	7	2	0	-2	2	0	0	2.2846036643348273	
i 1	276.5140612244898	4.7975	75	701	6	2	12	2	0	1	2	0	0	3.2846036643348273	
i 1	276.5140612244898	2.02	74	1087	6	5	14	8	0	-2	8	0	0	3.0	
i 1	276.7323333333333	0.2525	77	1087	4	1	3	17	0	2	17	0	0	2.0	
i 1	276.7359387755102	5.05	71	1087	3	24	11	1	0	-1	1	0	0	4.941908991581915	
i 1	276.74387074829934	0.505	77	203	4	1	8	16	0	2	16	0	0	2.0	
i 1	276.9945918367347	1.7675	77	701	4	1	14	16	0	2	16	0	0	2.0	
i 1	276.9945918367347	1.2625	72	701	6	2	11	2	0	1	2	0	0	3.2846036643348273	
i 1	277.00180272108844	1.2625	75	1087	3	9	14	2	0	1	2	0	0	2.2846036643348273	
i 1	277.0111768707483	1.2625	71	701	1	24	1	1	0	252	1	307	0	4.941908991581915	
i 1	277.2611768707483	5.555	77	1087	4	1	16	17	0	2	17	0	0	2.0	
i 1	277.4945918367347	1.2625	74	203	7	5	15	8	0	-2	8	0	0	3.0	
i 1	277.4967551020408	1.2625	71	701	6	5	12	2	0	-1	2	0	0	3.0	
i 1	277.74891836734696	2.7775	74	1087	6	5	6	8	0	-2	8	0	0	3.0	
i 1	277.75108163265304	2.525	71	701	6	5	16	8	0	-2	8	0	0	3.0	
i 1	278.2417074829932	3.2825	71	701	2	24	1	1	0	0	1	0	0	4.941908991581915	
i 1	278.7388231292517	0.2525	68	701	1	20	3	0	0	0	0	0	0	0.941908991581915	
i 1	278.74242857142855	0.2525	72	701	4	4	12	2	0	-2	2	0	0	3.2846036643348273	
i 1	278.7445918367347	0.2525	71	701	6	5	5	8	0	-2	8	0	0	3.0	
i 1	278.7460340136054	0.2525	74	1087	6	5	16	8	0	-2	8	0	0	3.0	
i 1	278.7503605442177	0.2525	71	203	1	20	2	1	0	0	1	0	0	0.941908991581915	
i 1	278.7539659863946	0.2525	71	701	1	20	15	1	0	0	1	0	0	0.941908991581915	
i 1	278.7554081632653	0.2525	77	1087	4	1	10	17	0	2	17	0	0	2.0	
i 1	278.76550340136055	1.2625	71	701	2	20	15	0	0	0	0	0	0	0.941908991581915	
i 1	278.9909863945578	4.04	74	701	6	5	12	8	0	-1	8	0	0	3.0	
i 1	278.99387074829934	0.2525	75	1087	3	9	11	2	0	1	2	0	0	2.2846036643348273	
i 1	279.00180272108844	0.2525	74	203	7	5	11	8	0	-1	8	0	0	3.0	
i 1	279.01261904761907	0.2525	74	701	4	1	14	16	0	2	16	0	0	2.0	
i 1	279.2323333333333	0.2525	71	203	1	20	12	1	0	0	1	0	0	0.941908991581915	
i 1	279.23521768707485	1.5150000000000001	75	203	4	4	9	2	0	-2	2	0	0	3.2846036643348273	
i 1	279.2409863945578	0.2525	71	701	1	20	16	0	0	-1	0	0	0	0.941908991581915	
i 1	279.2503605442177	2.7775	77	701	4	1	14	16	0	2	16	0	0	2.0	
i 1	279.2582925170068	1.5150000000000001	72	701	4	4	10	2	0	-2	2	0	0	3.2846036643348273	
i 1	279.25973469387753	0.2525	71	701	1	20	14	0	0	-1	0	0	0	0.941908991581915	
i 1	279.26189795918367	4.04	74	1087	6	5	1	8	0	-2	8	0	0	3.0	
i 1	279.75973469387753	2.02	75	203	4	3	2	2	0	1	2	0	0	3.2846036643348273	
i 1	279.75973469387753	2.02	75	701	5	3	8	2	0	1	2	0	0	3.2846036643348273	
i 1	280.00973469387753	0.2525	68	701	1	20	7	1	0	-1	1	0	0	0.941908991581915	
i 1	280.0111768707483	0.2525	68	701	1	20	15	1	0	0	1	0	0	0.941908991581915	
i 1	280.0176666666667	0.2525	71	203	1	20	6	1	0	0	1	0	0	0.941908991581915	
i 1	280.2460340136054	0.2525	74	203	7	5	16	8	0	-1	8	0	0	3.0	
i 1	280.25108163265304	1.2625	71	701	2	20	11	0	0	0	0	0	0	0.941908991581915	
i 1	280.48738095238093	0.505	77	1087	4	1	12	17	0	2	17	0	0	2.0	
i 1	280.48810204081633	0.2525	71	701	6	5	12	2	0	-1	2	0	0	3.0	
i 1	280.5046870748299	0.2525	71	701	6	5	14	8	0	-2	8	0	0	3.0	
i 1	280.50685034013605	0.505	74	701	4	1	16	16	0	2	16	0	0	2.0	
i 1	280.74387074829934	2.02	75	1087	3	9	3	2	0	1	2	0	0	2.2846036643348273	
i 1	280.7496394557823	0.2525	71	701	1	20	14	0	0	-1	0	0	0	0.941908991581915	
i 1	280.7546870748299	2.02	72	701	6	2	14	2	0	1	2	0	0	3.2846036643348273	
i 1	280.7590136054422	0.2525	71	203	1	20	15	0	0	-1	0	0	0	0.941908991581915	
i 1	280.7611768707483	0.2525	74	1087	6	5	8	8	0	-2	8	0	0	3.0	
i 1	280.76478231292515	0.2525	71	701	1	20	6	1	0	0	1	0	0	0.941908991581915	
i 1	280.76550340136055	0.505	74	203	7	5	4	8	0	-1	8	0	0	3.0	
i 1	280.9859387755102	0.7575000000000001	77	203	5	24	10	17	0	1	17	0	0	3.0	
i 1	280.99026530612247	5.555	74	701	3	24	12	16	0	1	16	0	0	3.0	
i 1	280.99819727891156	0.505	71	701	6	5	3	8	0	-2	8	0	0	3.0	
i 1	281.2359387755102	0.2525	71	701	6	5	15	8	0	-2	8	0	0	3.0	
i 1	281.4823333333333	0.2525	74	203	7	5	8	8	0	-2	8	0	0	3.0	
i 1	281.50108163265304	0.2525	74	1087	6	5	5	8	0	-2	8	0	0	3.0	
i 1	281.73377551020405	2.7775	75	701	2	3	16	2	0	1	2	0	0	3.2846036643348273	
i 1	281.73521768707485	0.2525	71	701	6	5	13	2	0	-1	2	0	0	3.0	
i 1	281.7359387755102	11.615	68	1087	3	20	15	0	0	0	0	0	0	1.0866308479764326	
i 1	281.7366598639456	3.535	71	701	6	5	7	8	0	-2	8	0	0	3.0	
i 1	281.73738095238093	11.615	61	1087	4	26	10	9	0	1	9	0	0	0.04036883330323932	
i 1	281.7503605442177	1.2625	71	1087	3	24	4	1	0	-1	1	0	0	5.086630847976433	
i 1	281.75108163265304	23.23	61	203	5	7	11	6	0	2	6	0	0	4.2316788314502505	
i 1	281.75612925170066	4.7975	77	203	4	24	16	17	0	1	17	0	0	3.0	
i 1	281.7590136054422	2.7775	75	203	6	3	15	2	0	1	2	0	0	3.2846036643348273	
i 1	281.9888231292517	3.7875	71	701	2	24	6	1	0	0	1	0	0	5.086630847976433	
i 1	281.99387074829934	0.2525	77	203	4	1	5	16	0	2	16	0	0	2.0	
i 1	282.0046870748299	3.2825	74	1087	6	5	8	8	0	-2	8	0	0	3.0	
i 1	282.25685034013605	0.2525	77	701	4	1	8	16	0	2	16	0	0	2.0	
i 1	282.4967551020408	0.2525	71	701	1	20	12	1	0	-1	1	0	0	1.0866308479764326	
i 1	282.5032448979592	0.2525	71	203	1	20	9	1	0	-1	1	0	0	1.0866308479764326	
i 1	282.5111768707483	3.2825	75	701	6	2	2	2	0	1	2	0	0	3.2846036643348273	
i 1	282.51478231292515	3.2825	75	1087	3	9	5	2	0	-2	2	0	0	2.2846036643348273	
i 1	282.51478231292515	0.2525	71	701	1	20	6	1	0	-1	1	0	0	1.0866308479764326	
i 1	282.75973469387753	0.2525	74	701	4	1	8	16	0	2	16	0	0	2.0	
i 1	282.7669455782313	0.2525	77	1087	4	1	9	17	0	2	17	0	0	2.0	
i 1	282.9830544217687	0.7575000000000001	77	701	4	1	14	16	0	2	16	0	0	2.0	
i 1	283.0003605442177	1.2625	72	701	4	4	13	2	0	-2	2	0	0	3.2846036643348273	
i 1	283.0032448979592	1.2625	75	203	4	4	11	2	0	-2	2	0	0	3.2846036643348273	
i 1	283.0039659863946	0.2525	74	203	7	5	14	8	0	-1	8	0	0	3.0	
i 1	283.0133401360544	1.2625	71	701	2	20	14	0	0	0	0	0	0	1.0866308479764326	
i 1	283.01478231292515	0.505	77	203	4	1	6	16	0	2	16	0	0	2.0	
i 1	283.2417074829932	2.7775	71	701	6	5	4	2	0	-1	2	0	0	3.0	
i 1	283.2453129251701	2.2725	74	203	7	5	7	8	0	-2	8	0	0	3.0	
i 1	283.5003605442177	0.2525	77	1087	4	1	8	17	0	2	17	0	0	2.0	
i 1	283.7366598639456	0.2525	74	701	4	1	16	16	0	2	16	0	0	2.0	
i 1	283.7467551020408	0.2525	77	1087	4	1	12	17	0	2	17	0	0	2.0	
i 1	284.23449659863945	0.2525	74	701	4	1	12	16	0	2	16	0	0	2.0	
i 1	284.25685034013605	0.2525	77	701	3	1	5	17	0	1	17	0	0	2.0	
i 1	284.48954421768707	4.7975	77	701	4	1	14	16	0	2	16	0	0	2.0	
i 1	284.49747619047616	0.2525	75	1087	3	9	1	2	0	1	2	0	0	2.2846036643348273	
i 1	284.50108163265304	5.05	77	1087	4	1	7	17	0	2	17	0	0	2.0	
i 1	284.74314965986395	2.2725	75	203	6	3	5	2	0	1	2	0	0	3.2846036643348273	
i 1	284.7445918367347	2.2725	74	701	6	5	13	8	0	-1	8	0	0	3.0	
i 1	284.7640612244898	2.2725	74	1087	6	5	15	8	0	-2	8	0	0	3.0	
i 1	284.7676666666667	2.02	75	701	2	3	14	2	0	1	2	0	0	3.2846036643348273	
i 1	284.9960340136054	0.7575000000000001	71	701	2	20	1	0	0	0	0	0	0	1.0866308479764326	
i 1	285.0003605442177	1.7675	71	1087	3	24	5	1	0	-1	1	0	0	5.086630847976433	
i 1	285.4917074829932	0.2525	74	203	7	5	10	8	0	-1	8	0	0	3.0	
i 1	285.4945918367347	1.01	72	701	6	2	1	2	0	1	2	0	0	3.2846036643348273	
i 1	285.5133401360544	1.01	75	1087	3	9	10	2	0	1	2	0	0	2.2846036643348273	
i 1	286.0054081632653	3.7875	71	701	2	24	4	1	0	0	1	0	0	5.086630847976433	
i 1	286.00757142857145	2.525	74	203	7	5	3	8	0	-2	8	0	0	3.0	
i 1	286.23377551020405	1.5150000000000001	75	1087	3	9	16	2	0	-2	2	0	0	2.2846036643348273	
i 1	286.2460340136054	2.525	71	701	6	5	1	2	0	-1	2	0	0	3.0	
i 1	286.2503605442177	0.505	68	701	1	20	16	0	0	0	0	0	0	1.0866308479764326	
i 1	286.25757142857145	1.5150000000000001	75	701	6	2	4	2	0	1	2	0	0	3.2846036643348273	
i 1	286.2633401360544	0.505	71	203	1	20	6	1	0	-1	1	0	0	1.0866308479764326	
i 1	286.26478231292515	0.505	68	701	1	20	3	0	0	-1	0	0	0	1.0866308479764326	
i 1	286.4859387755102	0.505	77	701	3	1	7	17	0	1	17	0	0	2.0	
i 1	286.49314965986395	0.7575000000000001	74	701	4	1	12	16	0	2	16	0	0	2.0	
i 1	286.9859387755102	0.505	75	203	4	4	7	2	0	-2	2	0	0	3.2846036643348273	
i 1	287.00757142857145	0.505	74	203	7	5	11	8	0	-1	8	0	0	3.0	
i 1	287.0140612244898	0.2525	71	701	6	5	3	8	0	-2	8	0	0	3.0	
i 1	287.01550340136055	0.505	72	701	4	4	3	2	0	-2	2	0	0	3.2846036643348273	
i 1	287.24387074829934	0.2525	74	701	3	24	4	16	0	1	16	0	0	3.0	
i 1	287.25757142857145	0.2525	71	701	6	5	10	8	0	-2	8	0	0	3.0	
i 1	287.4823333333333	1.2625	72	701	2	4	4	2	0	-2	2	0	0	3.2846036643348273	
i 1	287.4859387755102	0.2525	77	701	3	1	11	17	0	1	17	0	0	2.0	
i 1	287.49314965986395	2.525	71	701	6	5	9	8	0	-2	8	0	0	3.0	
i 1	287.49747619047616	1.2625	75	203	5	4	10	2	0	-2	2	0	0	3.2846036643348273	
i 1	287.49891836734696	0.2525	77	203	4	1	4	16	0	2	16	0	0	2.0	
i 1	287.50685034013605	11.615	61	1087	4	26	3	6	0	2	6	0	0	0.04036883330323932	
i 1	287.5082925170068	5.8075	66	701	5	14	2	9	0	2	9	0	0	5.642238441933668	
i 1	287.50973469387753	2.2725	74	1087	6	5	3	8	0	-2	8	0	0	3.0	
i 1	287.50973469387753	1.01	71	701	2	20	6	0	0	0	0	0	0	1.0866308479764326	
i 1	287.7409863945578	0.2525	77	1087	3	1	4	17	0	2	17	0	0	2.0	
i 1	287.75252380952384	6.0600000000000005	77	203	4	24	10	17	0	1	17	0	0	3.0	
i 1	287.7582925170068	0.2525	72	701	6	2	3	2	0	1	2	0	0	3.2846036643348273	
i 1	287.7669455782313	3.2825	75	701	2	3	15	2	0	1	2	0	0	3.2846036643348273	
i 1	287.9996394557823	2.525	75	203	6	3	7	2	0	1	2	0	0	3.2846036643348273	
i 1	288.2611768707483	5.555	74	701	3	24	7	16	0	1	16	0	0	3.0	
i 1	288.4945918367347	1.2625	75	1087	3	9	1	2	0	-2	2	0	0	2.2846036643348273	
i 1	288.5133401360544	1.2625	75	701	6	2	5	2	0	1	2	0	0	3.2846036643348273	
i 1	288.7359387755102	3.0300000000000002	74	1087	6	5	11	8	0	-2	8	0	0	3.0	
i 1	288.74747619047616	0.2525	74	203	7	5	12	8	0	-1	8	0	0	3.0	
i 1	288.98377551020405	1.01	71	701	2	20	3	0	0	0	0	0	0	1.0866308479764326	
i 1	288.98449659863945	2.7775	74	701	6	5	9	8	0	-1	8	0	0	3.0	
i 1	288.99387074829934	1.01	75	1087	3	9	8	2	0	1	2	0	0	2.2846036643348273	
i 1	289.0003605442177	1.01	72	701	6	2	3	2	0	1	2	0	0	3.2846036643348273	
i 1	289.25757142857145	0.2525	74	701	4	1	5	16	0	2	16	0	0	2.0	
i 1	289.5039659863946	0.2525	77	1087	3	1	5	17	0	2	17	0	0	2.0	
i 1	289.5140612244898	0.2525	77	203	4	1	10	16	0	2	16	0	0	2.0	
i 1	289.74891836734696	0.2525	74	701	4	1	4	16	0	2	16	0	0	2.0	
i 1	289.74891836734696	0.2525	74	203	7	5	3	8	0	-1	8	0	0	3.0	
i 1	289.98810204081633	3.0300000000000002	75	1087	3	9	10	2	0	-2	2	0	0	2.2846036643348273	
i 1	290.00180272108844	1.7675	71	701	2	24	5	1	0	0	1	0	0	5.086630847976433	
i 1	290.0032448979592	0.2525	77	203	4	1	9	16	0	2	16	0	0	2.0	
i 1	290.0082925170068	0.2525	71	701	6	5	3	8	0	-2	8	0	0	3.0	
i 1	290.01045578231293	3.0300000000000002	75	701	6	2	5	2	0	1	2	0	0	3.2846036643348273	
i 1	290.24026530612247	0.2525	74	1087	6	5	16	8	0	-2	8	0	0	3.0	
i 1	290.2532448979592	0.2525	68	701	1	20	7	1	0	-1	1	0	0	1.0866308479764326	
i 1	290.2546870748299	0.2525	68	701	1	20	14	0	0	-1	0	0	0	1.0866308479764326	
i 1	290.26622448979595	0.2525	71	203	1	20	6	0	0	-1	0	0	0	1.0866308479764326	
i 1	290.5003605442177	0.2525	77	701	4	1	6	16	0	2	16	0	0	2.0	
i 1	290.73449659863945	0.2525	71	701	6	5	14	2	0	-1	2	0	0	3.0	
i 1	290.7669455782313	0.2525	77	701	3	1	7	17	0	1	17	0	0	2.0	
i 1	290.98954421768707	1.2625	77	1087	4	1	16	17	0	2	17	0	0	2.0	
i 1	290.9909863945578	1.2625	77	701	4	1	14	16	0	2	16	0	0	2.0	
i 1	290.9917074829932	0.2525	72	701	2	4	4	2	0	-2	2	0	0	3.2846036643348273	
i 1	291.00973469387753	0.2525	71	701	6	5	12	8	0	-2	8	0	0	3.0	
i 1	291.23449659863945	1.01	71	701	6	5	3	8	0	-2	8	0	0	3.0	
i 1	291.23449659863945	0.7575000000000001	74	1087	6	5	15	8	0	-2	8	0	0	3.0	
i 1	291.2359387755102	0.505	75	701	2	3	11	2	0	1	2	0	0	3.2846036643348273	
i 1	291.23738095238093	3.7875	71	701	2	20	13	0	0	0	0	0	0	1.0866308479764326	
i 1	291.24387074829934	0.2525	75	203	5	4	9	2	0	-2	2	0	0	3.2846036643348273	
i 1	291.4866598639456	2.02	74	203	7	5	4	8	0	-2	8	0	0	3.0	
i 1	291.49026530612247	2.02	71	701	6	5	13	2	0	-1	2	0	0	3.0	
i 1	291.7359387755102	0.2525	68	701	1	20	16	1	0	-1	1	0	0	1.0866308479764326	
i 1	291.7496394557823	0.2525	71	203	1	24	16	0	0	-1	0	0	0	5.086630847976433	
i 1	291.76045578231293	0.7575000000000001	72	701	2	4	6	2	0	-2	2	0	0	3.2846036643348273	
i 1	291.76261904761907	0.7575000000000001	75	203	5	4	2	2	0	-2	2	0	0	3.2846036643348273	
i 1	291.9945918367347	3.2825	75	701	2	3	4	2	0	1	2	0	0	3.2846036643348273	
i 1	292.0003605442177	1.5150000000000001	75	203	6	3	4	2	0	1	2	0	0	3.2846036643348273	
i 1	292.00108163265304	0.2525	74	203	7	5	2	8	0	-1	8	0	0	3.0	
i 1	292.23449659863945	0.2525	74	701	4	1	1	16	0	2	16	0	0	2.0	
i 1	292.2359387755102	0.2525	74	1087	6	5	7	8	0	-2	8	0	0	3.0	
i 1	292.23738095238093	0.505	74	701	6	5	12	8	0	-1	8	0	0	3.0	
i 1	292.26045578231293	1.2625	71	701	2	24	8	1	0	0	1	0	0	5.086630847976433	
i 1	292.48449659863945	0.2525	71	203	1	24	14	0	0	-1	0	0	0	5.086630847976433	
i 1	292.4953129251701	0.2525	68	203	1	20	10	0	0	0	0	0	0	1.0866308479764326	
i 1	292.50108163265304	0.2525	77	701	3	1	16	17	0	1	17	0	0	2.0	
i 1	292.51189795918367	0.2525	71	701	1	20	8	1	0	0	1	0	0	1.0866308479764326	
i 1	292.51261904761907	0.2525	77	203	4	1	11	16	0	2	16	0	0	2.0	
i 1	292.73377551020405	2.2725	71	701	6	5	1	8	0	-2	8	0	0	3.0	
i 1	292.98954421768707	0.2525	68	701	1	20	2	0	0	-1	0	0	0	1.0866308479764326	
i 1	292.9917074829932	1.5150000000000001	72	701	6	2	10	2	0	1	2	0	0	3.2846036643348273	
i 1	292.9996394557823	0.2525	68	203	1	24	13	0	0	0	0	0	0	5.086630847976433	
i 1	293.0003605442177	0.2525	75	1087	3	9	16	2	0	1	2	0	0	2.2846036643348273	
i 1	293.0133401360544	0.2525	68	203	1	20	8	0	0	0	0	0	0	1.0866308479764326	
i 1	293.01550340136055	2.02	74	1087	6	5	10	8	0	-2	8	0	0	3.0	
i 1	293.0176666666667	0.2525	77	701	3	1	6	17	0	1	17	0	0	2.0	
i 1	293.23449659863945	27.27	66	701	5	14	3	9	0	2	9	0	0	5.642238441933668	
i 1	293.24026530612247	11.615	66	701	3	27	4	6	0	2	6	0	0	0.8069230363879212	
i 1	293.2496394557823	1.2625	75	1087	5	9	7	2	0	1	2	0	0	2.2846036643348273	
i 1	293.25252380952384	3.0300000000000002	77	1087	3	1	12	17	0	2	17	0	0	2.0	
i 1	293.2590136054422	5.8075	61	701	5	14	2	6	0	1	6	0	0	5.642238441933668	
i 1	293.26478231292515	3.0300000000000002	77	701	4	1	7	16	0	2	16	0	0	2.0	
i 1	293.4823333333333	1.01	74	203	7	5	12	8	0	-1	8	0	0	3.0	
i 1	293.5133401360544	0.505	74	1087	6	5	10	8	0	-2	8	0	0	3.0	
i 1	293.73810204081633	0.2525	77	203	4	1	4	16	0	2	16	0	0	2.0	
i 1	293.9953129251701	1.2625	75	203	6	3	2	2	0	1	2	0	0	3.2846036643348273	
i 1	294.00685034013605	0.2525	77	1087	3	1	6	17	0	2	17	0	0	2.0	
i 1	294.01622448979595	2.2725	71	701	2	24	12	1	0	0	1	0	0	5.086630847976433	
i 1	294.23521768707485	0.2525	68	203	1	24	15	1	0	-1	1	0	0	5.086630847976433	
i 1	294.2496394557823	0.2525	71	203	1	20	7	1	0	-1	1	0	0	1.0866308479764326	
i 1	294.2590136054422	0.2525	71	701	1	20	2	1	0	0	1	0	0	1.0866308479764326	
i 1	294.48449659863945	0.2525	72	701	2	4	9	2	0	-2	2	0	0	3.2846036643348273	
i 1	294.48738095238093	1.7675	74	701	6	5	2	8	0	-1	8	0	0	3.0	
i 1	294.49242857142855	1.7675	74	1087	6	5	1	8	0	-2	8	0	0	3.0	
i 1	294.7366598639456	1.01	75	701	6	2	16	2	0	1	2	0	0	3.2846036643348273	
i 1	294.74314965986395	0.2525	77	203	4	1	11	16	0	2	16	0	0	2.0	
i 1	294.75757142857145	1.01	75	1087	3	9	1	2	0	-2	2	0	0	2.2846036643348273	
i 1	295.23521768707485	0.7575000000000001	75	203	5	4	2	2	0	-2	2	0	0	3.2846036643348273	
i 1	295.2359387755102	0.2525	74	203	7	5	15	8	0	-2	8	0	0	3.0	
i 1	295.2388231292517	0.7575000000000001	72	701	2	4	16	2	0	-2	2	0	0	3.2846036643348273	
i 1	295.48810204081633	1.01	75	203	6	3	13	2	0	1	2	0	0	3.2846036643348273	
i 1	295.49242857142855	1.01	75	701	2	3	1	2	0	1	2	0	0	3.2846036643348273	
i 1	295.49747619047616	0.2525	77	701	3	1	12	17	0	1	17	0	0	2.0	
i 1	295.51261904761907	2.02	71	701	6	5	11	2	0	-1	2	0	0	3.0	
i 1	295.7445918367347	2.02	71	701	2	20	13	0	0	0	0	0	0	1.0866308479764326	
i 1	295.75108163265304	3.0300000000000002	74	701	3	24	4	16	0	1	16	0	0	3.0	
i 1	295.7554081632653	1.7675	74	203	7	5	14	8	0	-2	8	0	0	3.0	
i 1	295.7590136054422	3.0300000000000002	77	203	4	24	11	17	0	1	17	0	0	3.0	
i 1	295.98954421768707	1.5150000000000001	75	701	6	2	7	2	0	1	2	0	0	3.2846036643348273	
i 1	296.01045578231293	1.5150000000000001	75	1087	3	9	9	2	0	-2	2	0	0	2.2846036643348273	
i 1	296.24314965986395	0.2525	77	701	3	1	2	17	0	1	17	0	0	2.0	
i 1	296.24314965986395	0.2525	74	1087	6	5	13	8	0	-2	8	0	0	3.0	
i 1	296.4888231292517	0.2525	75	203	5	4	5	2	0	-2	2	0	0	3.2846036643348273	
i 1	296.51478231292515	0.2525	74	701	6	5	7	8	0	-1	8	0	0	3.0	
i 1	296.5176666666667	0.2525	77	1087	3	1	15	17	0	2	17	0	0	2.0	
i 1	296.9859387755102	0.2525	77	203	4	1	11	16	0	2	16	0	0	2.0	
i 1	296.9960340136054	1.7675	75	203	6	3	4	2	0	1	2	0	0	3.2846036643348273	
i 1	296.99819727891156	1.7675	75	701	2	3	9	2	0	1	2	0	0	3.2846036643348273	
i 1	297.01045578231293	0.2525	74	203	7	5	14	8	0	-1	8	0	0	3.0	
i 1	297.2323333333333	1.2625	71	701	6	5	15	8	0	-2	8	0	0	3.0	
i 1	297.2633401360544	1.7675	71	701	2	24	1	1	0	0	1	0	0	5.086630847976433	
i 1	297.2640612244898	1.2625	74	1087	6	5	4	8	0	-2	8	0	0	3.0	
i 1	297.4866598639456	0.2525	74	1087	6	5	11	8	0	-2	8	0	0	3.0	
i 1	297.48954421768707	0.2525	68	203	1	24	13	1	0	0	1	0	0	5.086630847976433	
i 1	297.4917074829932	0.2525	71	203	1	20	7	1	0	0	1	0	0	1.0866308479764326	
i 1	297.49387074829934	0.2525	68	701	1	20	10	0	0	-1	0	0	0	1.0866308479764326	
i 1	297.5039659863946	0.505	77	203	4	1	14	16	0	2	16	0	0	2.0	
i 1	297.51261904761907	0.2525	75	203	5	4	12	2	0	-2	2	0	0	3.2846036643348273	
i 1	297.73449659863945	0.7575000000000001	68	701	1	24	8	1	0	252	1	307	0	5.086630847976433	
i 1	297.74747619047616	0.2525	71	701	6	5	10	2	0	-1	2	0	0	3.0	
i 1	297.74819727891156	0.505	75	1087	5	9	14	2	0	1	2	0	0	2.2846036643348273	
i 1	297.7582925170068	0.505	72	701	6	2	6	2	0	1	2	0	0	3.2846036643348273	
i 1	297.9830544217687	0.2525	77	1087	3	1	13	17	0	2	17	0	0	2.0	
i 1	297.99314965986395	0.2525	71	701	6	5	12	8	0	-2	8	0	0	3.0	
i 1	298.24891836734696	2.02	74	701	6	5	15	8	0	-1	8	0	0	3.0	
i 1	298.2590136054422	1.01	71	701	2	20	4	0	0	0	0	0	0	1.0866308479764326	
i 1	298.25973469387753	0.7575000000000001	75	1087	3	9	16	2	0	-2	2	0	0	2.2846036643348273	
i 1	298.26189795918367	2.02	74	1087	6	5	2	8	0	-2	8	0	0	3.0	
i 1	298.48521768707485	0.2525	71	701	1	20	8	0	0	0	0	0	0	1.0866308479764326	
i 1	298.48810204081633	0.2525	68	203	1	24	7	1	0	-1	1	0	0	5.086630847976433	
i 1	298.4909863945578	1.2625	77	701	4	1	16	16	0	2	16	0	0	2.0	
i 1	298.49891836734696	1.01	75	701	6	2	13	2	0	1	2	0	0	3.2846036643348273	
i 1	298.5133401360544	0.2525	71	701	6	5	10	2	0	-1	2	0	0	3.0	
i 1	298.51622448979595	0.2525	71	203	1	20	6	0	0	0	0	0	0	1.0866308479764326	
i 1	298.5176666666667	1.01	77	1087	3	1	10	17	0	2	17	0	0	2.0	
i 1	298.75685034013605	1.5150000000000001	75	203	5	4	5	2	0	-2	2	0	0	3.2846036643348273	
i 1	298.76478231292515	0.7575000000000001	74	203	7	5	9	8	0	-2	8	0	0	3.0	
i 1	298.98521768707485	2.02	77	203	4	24	11	17	0	1	17	0	0	3.0	
i 1	298.99026530612247	1.2625	72	701	2	4	11	2	0	-2	2	0	0	3.2846036643348273	
i 1	298.9967551020408	21.4625	61	701	5	14	13	6	0	1	6	0	0	5.642238441933668	
i 1	298.99819727891156	2.02	74	701	3	24	8	16	0	1	16	0	0	3.0	
i 1	299.00252380952384	5.8075	66	203	6	13	6	6	0	2	6	0	0	1.4105596104834164	
i 1	299.00685034013605	0.505	75	1087	5	9	15	2	0	-2	2	0	0	2.2846036643348273	
i 1	299.0140612244898	11.615	61	701	3	27	7	6	0	1	6	0	0	0.8069230363879212	
i 1	299.2539659863946	0.2525	71	203	1	24	11	1	0	0	1	0	0	5.086630847976433	
i 1	299.2676666666667	0.2525	68	701	1	20	13	0	0	0	0	0	0	1.0866308479764326	
i 1	299.4945918367347	0.2525	72	701	6	2	3	2	0	1	2	0	0	3.2846036643348273	
i 1	299.4945918367347	2.525	71	701	6	5	15	8	0	-2	8	0	0	3.0	
i 1	299.5003605442177	0.7575000000000001	71	701	2	20	8	0	0	0	0	0	0	1.0866308479764326	
i 1	299.74314965986395	2.02	74	1087	6	5	4	8	0	-2	8	0	0	3.0	
i 1	299.75612925170066	0.505	77	203	4	1	16	16	0	2	16	0	0	2.0	
i 1	299.75685034013605	0.2525	75	1087	5	9	16	2	0	1	2	0	0	2.2846036643348273	
i 1	299.9859387755102	1.01	75	203	6	3	5	2	0	1	2	0	0	3.2846036643348273	
i 1	300.00252380952384	1.01	75	701	2	3	13	2	0	1	2	0	0	3.2846036643348273	
i 1	300.25180272108844	0.2525	68	701	1	20	9	0	0	0	0	0	0	1.0866308479764326	
i 1	300.2532448979592	0.2525	71	203	1	24	10	1	0	0	1	0	0	5.086630847976433	
i 1	300.2676666666667	0.2525	72	701	6	2	16	2	0	1	2	0	0	3.2846036643348273	
i 1	300.50612925170066	0.2525	71	701	6	5	5	2	0	-1	2	0	0	3.0	
i 1	300.73377551020405	1.7675	77	1087	3	1	9	17	0	2	17	0	0	2.0	
i 1	300.74242857142855	0.7575000000000001	75	701	6	2	4	2	0	1	2	0	0	3.2846036643348273	
i 1	300.7453129251701	1.7675	77	701	4	1	8	16	0	2	16	0	0	2.0	
i 1	300.7669455782313	0.7575000000000001	75	1087	5	9	13	2	0	-2	2	0	0	2.2846036643348273	
i 1	300.9823333333333	0.2525	77	1087	3	1	11	17	0	2	17	0	0	2.0	
i 1	301.2366598639456	1.01	75	203	6	3	5	2	0	1	2	0	0	3.2846036643348273	
i 1	301.23738095238093	1.2625	75	701	2	3	4	2	0	1	2	0	0	3.2846036643348273	
i 1	301.2539659863946	1.5150000000000001	71	701	6	5	4	2	0	-1	2	0	0	3.0	
i 1	301.2554081632653	1.5150000000000001	74	203	7	5	8	8	0	-2	8	0	0	3.0	
i 1	301.25612925170066	0.505	72	701	6	2	7	2	0	1	2	0	0	3.2846036643348273	
i 1	301.26261904761907	0.2525	74	701	4	1	2	16	0	2	16	0	0	2.0	
i 1	301.26550340136055	0.505	75	1087	5	9	4	2	0	1	2	0	0	2.2846036643348273	
i 1	301.5111768707483	0.505	77	1087	3	1	4	17	0	2	17	0	0	2.0	
i 1	301.9859387755102	2.02	75	1087	5	9	2	2	0	-2	2	0	0	2.2846036643348273	
i 1	301.9917074829932	0.2525	77	701	2	1	5	17	0	1	17	0	0	2.0	
i 1	302.00973469387753	2.02	75	701	6	2	2	2	0	1	2	0	0	3.2846036643348273	
i 1	302.01261904761907	0.7575000000000001	71	701	2	20	15	0	0	0	0	0	0	1.0866308479764326	
i 1	302.2590136054422	2.525	74	701	3	24	1	16	0	1	16	0	0	3.0	
i 1	302.48521768707485	0.2525	71	203	1	24	4	1	0	-1	1	0	0	5.086630847976433	
i 1	302.4859387755102	3.535	77	203	4	24	6	17	0	1	17	0	0	3.0	
i 1	302.4960340136054	0.2525	68	701	1	20	2	1	0	-1	1	0	0	1.0866308479764326	
i 1	302.5054081632653	0.2525	74	203	6	5	4	8	0	-1	8	0	0	3.0	
i 1	302.5176666666667	0.2525	68	701	1	20	11	1	0	0	1	0	0	1.0866308479764326	
i 1	302.7453129251701	0.505	74	701	6	5	10	8	0	-1	8	0	0	3.0	
i 1	302.7460340136054	1.2625	71	701	6	5	15	8	0	-2	8	0	0	3.0	
i 1	302.74747619047616	1.2625	74	1087	6	5	2	8	0	-2	8	0	0	3.0	
i 1	303.0046870748299	0.2525	74	701	4	1	15	16	0	2	16	0	0	2.0	
i 1	303.2409863945578	0.7575000000000001	71	701	2	20	3	0	0	0	0	0	0	1.0866308479764326	
i 1	303.2532448979592	0.2525	74	203	7	5	9	8	0	-2	8	0	0	3.0	
i 1	303.4823333333333	0.2525	74	701	6	5	2	8	0	-1	8	0	0	3.0	
i 1	303.50612925170066	0.2525	75	701	2	3	5	2	0	1	2	0	0	3.2846036643348273	
i 1	303.7323333333333	0.2525	68	701	1	20	10	0	0	-1	0	0	0	1.0866308479764326	
i 1	303.73810204081633	0.7575000000000001	75	203	5	4	11	2	0	-2	2	0	0	3.2846036643348273	
i 1	303.75252380952384	0.2525	71	203	1	20	6	1	0	0	1	0	0	1.0866308479764326	
i 1	303.75973469387753	0.2525	71	701	1	20	8	0	0	0	0	0	0	1.0866308479764326	
i 1	303.76550340136055	0.2525	71	203	1	24	2	1	0	-1	1	0	0	5.086630847976433	
i 1	303.7676666666667	0.7575000000000001	72	701	2	4	9	2	0	-2	2	0	0	3.2846036643348273	
i 1	303.9888231292517	1.01	74	701	6	5	8	8	0	-1	8	0	0	3.0	
i 1	304.0133401360544	1.01	74	1087	6	5	4	8	0	-2	8	0	0	3.0	
i 1	304.2323333333333	0.505	75	701	6	2	5	2	0	1	2	0	0	3.2846036643348273	
i 1	304.23521768707485	0.505	75	701	2	3	3	2	0	1	2	0	0	3.2846036643348273	
i 1	304.24242857142855	1.2625	75	203	6	3	5	2	0	1	2	0	0	3.2846036643348273	
i 1	304.24314965986395	0.2525	74	203	6	5	11	8	0	-1	8	0	0	3.0	
i 1	304.2532448979592	0.505	75	1087	5	9	9	2	0	-2	2	0	0	2.2846036643348273	
i 1	304.49242857142855	0.2525	71	203	1	20	6	1	0	-1	1	0	0	1.0866308479764326	
i 1	304.5054081632653	0.2525	71	701	2	20	12	0	0	0	0	0	0	1.0866308479764326	
i 1	304.5140612244898	0.2525	71	701	1	20	8	1	0	-1	1	0	0	1.0866308479764326	
i 1	304.5169455782313	0.2525	74	203	7	5	9	8	0	-2	8	0	0	3.0	
i 1	304.5169455782313	0.2525	68	701	1	20	2	1	0	-1	1	0	0	1.0866308479764326	
i 1	304.73449659863945	0.2525	77	701	2	1	1	17	0	1	17	0	0	2.0	
i 1	304.73954421768707	1.2625	74	701	2	24	10	16	0	1	16	0	0	3.0	
i 1	304.7453129251701	0.2525	75	203	5	4	5	2	0	-2	2	0	0	3.2846036643348273	
i 1	304.74747619047616	5.8075	61	203	6	7	15	6	0	2	6	0	0	4.2316788314502505	
i 1	304.75252380952384	0.7575000000000001	75	701	5	3	11	2	0	1	2	0	0	3.2846036643348273	
i 1	304.7590136054422	15.655	66	203	6	13	8	6	0	2	6	0	0	1.4105596104834164	
i 1	304.98810204081633	0.505	74	203	6	5	1	8	0	-2	8	0	0	3.0	
i 1	304.9945918367347	0.505	71	701	6	5	6	2	0	-1	2	0	0	3.0	
i 1	304.9953129251701	1.2625	72	701	6	2	6	2	0	1	2	0	0	3.2846036643348273	
i 1	305.2359387755102	1.5150000000000001	71	701	6	5	2	8	0	-2	8	0	0	3.0	
i 1	305.24242857142855	1.5150000000000001	74	1087	6	5	5	8	0	-2	8	0	0	3.0	
i 1	305.2503605442177	1.01	75	1087	5	9	5	2	0	1	2	0	0	2.2846036643348273	
i 1	305.9953129251701	0.505	77	1087	3	1	11	17	0	2	17	0	0	2.0	
i 1	306.0039659863946	0.505	77	701	4	1	14	16	0	2	16	0	0	2.0	
i 1	306.2445918367347	0.7575000000000001	75	701	5	3	12	2	0	1	2	0	0	3.2846036643348273	
i 1	306.2582925170068	0.7575000000000001	75	203	6	3	4	2	0	1	2	0	0	3.2846036643348273	
i 1	306.4953129251701	0.7575000000000001	74	701	2	24	11	16	0	1	16	0	0	3.0	
i 1	306.5054081632653	0.7575000000000001	77	203	4	24	3	17	0	1	17	0	0	3.0	
i 1	306.7330544217687	2.7775	74	701	6	5	13	8	0	-1	8	0	0	3.0	
i 1	306.7554081632653	2.7775	74	1087	6	5	10	8	0	-2	8	0	0	3.0	
i 1	306.99387074829934	0.505	75	1087	5	9	10	2	0	-2	2	0	0	2.2846036643348273	
i 1	307.0140612244898	0.505	75	701	6	2	6	2	0	1	2	0	0	3.2846036643348273	
i 1	307.24242857142855	2.525	77	701	4	1	4	16	0	2	16	0	0	2.0	
i 1	307.25108163265304	2.525	77	1087	3	1	16	17	0	2	17	0	0	2.0	
i 1	307.48449659863945	0.2525	72	701	2	4	16	2	0	-2	2	0	0	3.2846036643348273	
i 1	307.49747619047616	0.2525	71	701	1	20	5	0	0	-1	0	0	0	1.0866308479764326	
i 1	307.5039659863946	0.2525	75	203	5	4	13	2	0	-2	2	0	0	3.2846036643348273	
i 1	307.5111768707483	0.2525	71	203	1	20	6	1	0	0	1	0	0	1.0866308479764326	
i 1	307.73738095238093	0.505	75	701	5	3	2	2	0	1	2	0	0	3.2846036643348273	
i 1	307.76622448979595	0.505	75	203	6	3	1	2	0	1	2	0	0	3.2846036643348273	
i 1	308.23377551020405	1.01	75	1087	5	9	13	2	0	-2	2	0	0	2.2846036643348273	
i 1	308.26189795918367	1.01	75	701	6	2	3	2	0	1	2	0	0	3.2846036643348273	
i 1	309.25180272108844	0.7575000000000001	75	203	6	3	9	2	0	1	2	0	0	3.2846036643348273	
i 1	309.25180272108844	0.7575000000000001	75	701	5	3	2	2	0	1	2	0	0	3.2846036643348273	
i 1	309.48377551020405	1.2625	71	701	6	5	7	8	0	-2	8	0	0	3.0	
i 1	309.4945918367347	1.01	74	1087	6	5	6	8	0	-2	8	0	0	3.0	
i 1	309.7467551020408	2.7775	74	701	2	24	5	16	0	1	16	0	0	3.0	
i 1	309.7539659863946	2.7775	77	203	4	24	12	17	0	1	17	0	0	3.0	
i 1	309.9866598639456	0.2525	72	701	6	2	5	2	0	1	2	0	0	3.2846036643348273	
i 1	309.99242857142855	0.2525	75	1087	5	9	15	2	0	1	2	0	0	2.2846036643348273	
i 1	310.23738095238093	0.2525	75	203	6	3	8	2	0	1	2	0	0	3.2846036643348273	
i 1	310.26478231292515	0.2525	75	701	5	3	6	2	0	1	2	0	0	3.2846036643348273	
i 1	310.48449659863945	0.7575000000000001	75	701	6	2	11	2	0	1	2	0	0	3.2846036643348273	
i 1	310.4866598639456	24.4925	61	701	1	27	14	6	0	248	6	308	0	0.8069230363879212	
i 1	310.48810204081633	0.7575000000000001	75	1087	5	9	4	2	0	-2	2	0	0	2.2846036643348273	
i 1	310.50108163265304	0.2525	74	1087	5	5	3	8	0	-2	8	0	0	3.0	
i 1	310.5082925170068	9.8475	61	203	7	7	14	6	0	2	6	0	0	4.2316788314502505	
i 1	310.7359387755102	0.505	71	701	1	20	14	1	0	-1	1	0	0	1.0866308479764326	
i 1	310.74314965986395	1.01	74	203	6	5	13	8	0	-2	8	0	0	3.0	
i 1	310.7640612244898	1.01	71	701	6	5	3	2	0	-1	2	0	0	3.0	
i 1	310.7669455782313	0.505	68	203	1	24	16	0	0	-1	0	0	0	5.086630847976433	
i 1	311.23738095238093	1.01	75	203	5	4	8	2	0	-2	2	0	0	3.2846036643348273	
i 1	311.2539659863946	1.01	72	701	4	4	1	2	0	-2	2	0	0	3.2846036643348273	
i 1	311.7554081632653	0.505	71	203	1	20	13	0	0	0	0	0	0	1.0866308479764326	
i 1	311.7611768707483	0.505	68	701	1	20	11	1	0	-1	1	0	0	1.0866308479764326	
i 1	311.76550340136055	0.2525	71	701	6	5	6	8	0	-2	8	0	0	3.0	
i 1	311.7676666666667	0.2525	74	1087	5	5	5	8	0	-2	8	0	0	3.0	
i 1	311.98521768707485	1.5150000000000001	74	701	6	5	8	8	0	-1	8	0	0	3.0	
i 1	311.99242857142855	1.5150000000000001	74	1087	6	5	1	8	0	-2	8	0	0	3.0	
i 1	312.23954421768707	0.7575000000000001	75	701	5	3	7	2	0	1	2	0	0	3.2846036643348273	
i 1	312.25612925170066	0.7575000000000001	75	203	6	3	6	2	0	1	2	0	0	3.2846036643348273	
i 1	312.4888231292517	0.505	77	1087	3	1	9	17	0	2	17	0	0	2.0	
i 1	312.51261904761907	0.505	77	701	6	1	14	16	0	2	16	0	0	2.0	
i 1	312.74819727891156	0.505	71	701	1	20	9	0	0	0	0	0	0	1.0866308479764326	
i 1	312.7669455782313	0.505	71	203	1	24	7	0	0	0	0	0	0	5.086630847976433	
i 1	312.98738095238093	1.5150000000000001	77	203	4	24	2	17	0	1	17	0	0	3.0	
i 1	312.99026530612247	0.2525	75	701	6	2	16	2	0	1	2	0	0	3.2846036643348273	
i 1	313.00973469387753	0.2525	75	1087	5	9	7	2	0	-2	2	0	0	2.2846036643348273	
i 1	313.01261904761907	1.5150000000000001	74	701	2	24	13	16	0	1	16	0	0	3.0	
i 1	313.2640612244898	0.2525	75	701	5	3	16	2	0	1	2	0	0	3.2846036643348273	
i 1	313.2669455782313	0.2525	75	203	6	3	5	2	0	1	2	0	0	3.2846036643348273	
i 1	313.4967551020408	1.5150000000000001	71	701	6	5	15	2	0	-1	2	0	0	3.0	
i 1	313.4996394557823	0.2525	72	701	6	2	11	2	0	1	2	0	0	3.2846036643348273	
i 1	313.5054081632653	0.2525	75	1087	5	9	14	2	0	1	2	0	0	2.2846036643348273	
i 1	313.51550340136055	1.5150000000000001	74	203	6	5	15	8	0	-2	8	0	0	3.0	
i 1	313.7366598639456	0.505	75	701	5	3	15	2	0	1	2	0	0	3.2846036643348273	
i 1	313.75108163265304	0.505	75	203	6	3	2	2	0	1	2	0	0	3.2846036643348273	
i 1	313.76261904761907	0.2525	68	203	1	20	12	1	0	-1	1	0	0	1.0866308479764326	
i 1	313.7669455782313	0.2525	71	701	1	20	9	1	0	0	1	0	0	1.0866308479764326	
i 1	314.24314965986395	0.7575000000000001	71	701	1	20	10	1	0	0	1	0	0	1.0866308479764326	
i 1	314.24387074829934	0.7575000000000001	68	203	1	20	14	1	0	0	1	0	0	1.0866308479764326	
i 1	314.2590136054422	1.7675	75	1087	5	9	10	2	0	-2	2	0	0	2.2846036643348273	
i 1	314.26189795918367	1.7675	75	701	6	2	14	2	0	1	2	0	0	3.2846036643348273	
i 1	314.48449659863945	2.525	77	701	6	1	1	16	0	2	16	0	0	2.0	
i 1	314.50685034013605	2.525	77	1087	3	1	10	17	0	2	17	0	0	2.0	
i 1	314.9960340136054	1.2625	74	1087	5	5	4	8	0	-2	8	0	0	3.0	
i 1	315.0176666666667	1.2625	71	701	6	5	8	8	0	-2	8	0	0	3.0	
i 1	315.9823333333333	0.2525	72	701	4	4	10	2	0	-2	2	0	0	3.2846036643348273	
i 1	315.98738095238093	0.2525	75	203	5	4	8	2	0	-2	2	0	0	3.2846036643348273	
i 1	316.2409863945578	0.2525	75	203	6	3	9	2	0	1	2	0	0	3.2846036643348273	
i 1	316.24891836734696	0.2525	75	701	5	3	5	2	0	1	2	0	0	3.2846036643348273	
i 1	316.25757142857145	0.2525	71	1087	2	20	15	1	0	-1	1	0	0	1.0866308479764326	
i 1	316.26478231292515	2.2725	74	701	6	5	5	8	0	-1	8	0	0	3.0	
i 1	316.26622448979595	2.2725	74	1087	5	5	9	8	0	-2	8	0	0	3.0	
i 1	316.4888231292517	0.2525	75	701	6	2	13	2	0	1	2	0	0	3.2846036643348273	
i 1	316.49891836734696	0.2525	75	1087	5	9	7	2	0	-2	2	0	0	2.2846036643348273	
i 1	316.49891836734696	0.2525	68	701	1	20	8	1	0	-1	1	0	0	1.0866308479764326	
i 1	316.7445918367347	1.2625	68	1087	2	20	8	0	0	0	0	0	0	1.0866308479764326	
i 1	316.75973469387753	0.505	75	203	6	3	6	2	0	1	2	0	0	3.2846036643348273	
i 1	316.7676666666667	0.505	75	701	5	3	16	2	0	1	2	0	0	3.2846036643348273	
i 1	316.98377551020405	2.7775	74	701	2	24	15	16	0	1	16	0	0	3.0	
i 1	316.9960340136054	2.7775	77	203	4	24	8	17	0	1	17	0	0	3.0	
i 1	317.2323333333333	1.01	72	701	6	2	1	2	0	1	2	0	0	3.2846036643348273	
i 1	317.2539659863946	1.01	75	1087	5	9	9	2	0	1	2	0	0	2.2846036643348273	
i 1	317.9967551020408	0.2525	68	701	1	20	8	1	0	0	1	0	0	1.0866308479764326	
i 1	318.00685034013605	0.2525	68	203	1	20	10	0	0	-1	0	0	0	1.0866308479764326	
i 1	318.24314965986395	0.7575000000000001	75	701	5	3	14	2	0	1	2	0	0	3.2846036643348273	
i 1	318.26478231292515	0.7575000000000001	75	203	6	3	2	2	0	1	2	0	0	3.2846036643348273	
i 1	318.48449659863945	0.2525	71	701	6	5	12	8	0	-2	8	0	0	3.0	
i 1	318.50973469387753	0.2525	74	1087	5	5	11	8	0	-2	8	0	0	3.0	
i 1	318.75180272108844	1.5150000000000001	74	203	6	5	10	8	0	-2	8	0	0	3.0	
i 1	318.75180272108844	1.5150000000000001	71	701	6	5	8	2	0	-1	2	0	0	3.0	
i 1	318.9888231292517	0.505	75	701	6	2	3	2	0	1	2	0	0	3.2846036643348273	
i 1	318.99819727891156	0.505	75	1087	5	9	7	2	0	-2	2	0	0	2.2846036643348273	
i 1	319.4823333333333	0.2525	75	203	5	4	13	2	0	-2	2	0	0	3.2846036643348273	
i 1	319.4866598639456	0.2525	72	701	4	4	1	2	0	-2	2	0	0	3.2846036643348273	
i 1	319.4866598639456	0.505	68	701	3	20	10	0	0	0	0	0	0	1.0866308479764326	
i 1	319.4960340136054	0.505	68	701	1	20	9	0	0	-1	0	0	0	1.0866308479764326	
i 1	319.7366598639456	0.505	75	203	6	3	14	2	0	1	2	0	0	3.2846036643348273	
i 1	319.74026530612247	0.505	77	701	6	1	2	16	0	2	16	0	0	2.0	
i 1	319.75757142857145	0.505	77	1087	3	1	3	17	0	2	17	0	0	2.0	
i 1	319.75973469387753	0.505	75	701	5	3	5	2	0	1	2	0	0	3.2846036643348273	
i 1	319.9967551020408	0.2525	68	1087	2	20	4	0	0	0	0	0	0	1.0866308479764326	
i 1	320.23377551020405	2.7775	77	1087	6	1	15	16	0	1	16	0	0	2.0	
i 1	320.23521768707485	0.2525	68	203	1	24	4	1	0	0	1	0	0	5.086630847976433	
i 1	320.2388231292517	0.2525	68	701	1	20	8	0	0	-1	0	0	0	1.0866308479764326	
i 1	320.2388231292517	14.645	61	1087	5	14	16	9	0	2	9	0	0	5.642238441933668	
i 1	320.23954421768707	1.01	72	701	5	3	9	2	0	-2	2	0	0	3.2846036643348273	
i 1	320.24026530612247	1.5150000000000001	74	1087	6	5	12	2	0	-2	2	0	0	3.0	
i 1	320.2460340136054	24.9975	61	701	5	13	2	6	0	2	6	0	0	1.4105596104834164	
i 1	320.2467551020408	0.2525	68	1087	3	20	2	0	0	0	0	0	0	1.0866308479764326	
i 1	320.24747619047616	1.01	72	701	4	4	11	2	0	-2	2	0	0	3.2846036643348273	
i 1	320.24747619047616	14.645	61	1087	5	14	8	6	0	1	6	0	0	5.642238441933668	
i 1	320.2539659863946	24.9975	61	701	6	7	5	6	0	2	6	0	0	4.2316788314502505	
i 1	320.2582925170068	2.7775	77	701	2	1	9	17	0	1	17	0	0	2.0	
i 1	320.26478231292515	1.5150000000000001	71	701	6	5	9	8	0	-2	8	0	0	3.0	
i 1	321.2503605442177	0.7575000000000001	72	1087	6	2	14	2	0	1	2	0	0	3.2846036643348273	
i 1	321.2546870748299	0.7575000000000001	75	203	6	9	3	2	0	-2	2	0	0	2.2846036643348273	
i 1	321.73449659863945	1.2625	74	203	6	5	5	8	0	-1	8	0	0	3.0	
i 1	321.74819727891156	1.2625	74	701	6	5	5	2	0	-2	2	0	0	3.0	
i 1	321.7532448979592	0.2525	71	203	1	20	10	1	0	0	1	0	0	1.0866308479764326	
i 1	321.9909863945578	7.07	71	701	1	24	15	1	0	252	1	307	0	4.92669720094845	
i 1	321.99891836734696	0.2525	72	701	5	3	12	2	0	-2	2	0	0	3.2846036643348273	
i 1	322.0054081632653	1.5150000000000001	71	203	3	20	1	1	0	0	1	0	0	0.9266972009484502	
i 1	322.0111768707483	0.2525	72	701	4	4	5	2	0	-2	2	0	0	3.2846036643348273	
i 1	322.2554081632653	0.505	75	701	5	3	4	2	0	1	2	0	0	3.2846036643348273	
i 1	322.2590136054422	0.505	72	1087	6	2	16	2	0	1	2	0	0	3.2846036643348273	
i 1	322.75252380952384	0.505	72	203	6	9	7	2	0	1	2	0	0	2.2846036643348273	
i 1	322.7633401360544	0.505	75	701	4	4	9	2	0	-2	2	0	0	3.2846036643348273	
i 1	322.9830544217687	1.2625	74	203	6	5	11	2	0	-2	2	0	0	3.0	
i 1	322.98810204081633	1.2625	74	1087	6	5	14	2	0	-1	2	0	0	3.0	
i 1	323.0046870748299	2.525	74	203	4	1	2	16	0	2	16	0	0	2.0	
i 1	323.0054081632653	2.525	74	701	4	24	6	17	0	1	17	0	0	3.0	
i 1	323.24242857142855	1.01	72	701	5	3	13	2	0	-2	2	0	0	3.2846036643348273	
i 1	323.24387074829934	1.01	72	701	4	4	2	2	0	-2	2	0	0	3.2846036643348273	
i 1	323.49819727891156	0.505	68	203	1	24	10	1	0	0	1	0	0	4.92669720094845	
i 1	323.49891836734696	0.7575000000000001	71	203	1	20	4	0	0	-1	0	0	0	0.9266972009484502	
i 1	323.5054081632653	0.505	68	1087	3	20	14	0	0	0	0	0	0	0.9266972009484502	
i 1	323.5133401360544	0.505	68	1087	3	20	13	0	0	-1	0	0	0	0.9266972009484502	
i 1	323.9953129251701	0.2525	71	203	3	20	11	0	0	0	0	0	0	0.9266972009484502	
i 1	324.2323333333333	0.7575000000000001	72	1087	6	2	6	2	0	1	2	0	0	3.2846036643348273	
i 1	324.23521768707485	1.2625	74	1087	6	5	1	2	0	-2	2	0	0	3.0	
i 1	324.2467551020408	0.7575000000000001	75	701	5	3	15	2	0	1	2	0	0	3.2846036643348273	
i 1	324.2503605442177	0.505	68	701	1	20	5	0	0	-1	0	0	0	0.9266972009484502	
i 1	324.26478231292515	1.2625	71	701	4	5	13	8	0	-2	8	0	0	3.0	
i 1	324.74891836734696	1.01	71	203	3	20	6	0	0	-1	0	0	0	0.9266972009484502	
i 1	324.9823333333333	0.2525	72	701	5	3	12	2	0	-2	2	0	0	3.2846036643348273	
i 1	325.0039659863946	0.2525	72	701	4	4	6	2	0	-2	2	0	0	3.2846036643348273	
i 1	325.2460340136054	0.2525	75	203	6	9	4	2	0	-2	2	0	0	2.2846036643348273	
i 1	325.25612925170066	0.2525	72	1087	5	2	6	2	0	1	2	0	0	3.2846036643348273	
i 1	325.48449659863945	0.2525	72	701	5	3	1	2	0	-2	2	0	0	3.2846036643348273	
i 1	325.48449659863945	1.5150000000000001	74	203	6	5	13	2	0	-2	2	0	0	3.0	
i 1	325.49026530612247	1.5150000000000001	77	701	2	1	2	17	0	1	17	0	0	2.0	
i 1	325.49387074829934	1.5150000000000001	74	1087	6	5	15	2	0	-1	2	0	0	3.0	
i 1	325.4945918367347	0.2525	72	701	4	4	7	2	0	-2	2	0	0	3.2846036643348273	
i 1	325.49819727891156	1.5150000000000001	77	1087	6	1	10	16	0	1	16	0	0	2.0	
i 1	325.73738095238093	0.2525	68	203	1	24	13	1	0	0	1	0	0	4.92669720094845	
i 1	325.7417074829932	1.5150000000000001	75	701	5	3	14	2	0	1	2	0	0	3.2846036643348273	
i 1	325.74819727891156	0.2525	68	1087	3	20	15	1	0	0	1	0	0	0.9266972009484502	
i 1	325.75685034013605	0.2525	71	1087	3	20	5	0	0	-1	0	0	0	0.9266972009484502	
i 1	325.7582925170068	1.2625	71	203	1	20	14	0	0	-1	0	0	0	0.9266972009484502	
i 1	325.76622448979595	1.5150000000000001	72	1087	6	2	1	2	0	1	2	0	0	3.2846036643348273	
i 1	326.0140612244898	1.01	68	203	3	20	4	1	0	0	1	0	0	0.9266972009484502	
i 1	326.9830544217687	1.5150000000000001	74	701	6	5	2	2	0	-2	2	0	0	3.0	
i 1	326.98377551020405	0.505	74	701	4	24	6	17	0	1	17	0	0	3.0	
i 1	326.98377551020405	0.505	68	203	1	24	10	1	0	0	1	0	0	4.92669720094845	
i 1	326.9866598639456	0.505	68	203	3	20	2	0	0	0	0	0	0	0.9266972009484502	
i 1	327.0111768707483	1.5150000000000001	74	203	6	5	15	8	0	-1	8	0	0	3.0	
i 1	327.01622448979595	0.505	74	203	4	1	5	16	0	2	16	0	0	2.0	
i 1	327.2323333333333	0.7575000000000001	72	203	6	9	6	2	0	1	2	0	0	2.2846036643348273	
i 1	327.25685034013605	0.7575000000000001	75	701	4	4	16	2	0	-2	2	0	0	3.2846036643348273	
i 1	327.4859387755102	2.7775	77	701	2	1	14	17	0	1	17	0	0	2.0	
i 1	327.51622448979595	2.7775	77	1087	6	1	2	16	0	1	16	0	0	2.0	
i 1	327.74747619047616	0.2525	68	701	3	20	15	0	0	-1	0	0	0	0.9266972009484502	
i 1	327.7590136054422	1.2625	71	203	1	20	12	0	0	-1	0	0	0	0.9266972009484502	
i 1	327.75973469387753	0.2525	68	1087	3	20	3	0	0	0	0	0	0	0.9266972009484502	
i 1	327.9823333333333	1.01	71	203	3	20	10	0	0	-1	0	0	0	0.9266972009484502	
i 1	327.9830544217687	0.2525	72	701	5	3	13	2	0	-2	2	0	0	3.2846036643348273	
i 1	327.98377551020405	1.01	68	203	3	20	14	1	0	0	1	0	0	0.9266972009484502	
i 1	328.0111768707483	0.2525	72	701	4	4	8	2	0	-2	2	0	0	3.2846036643348273	
i 1	328.23449659863945	0.2525	72	1087	5	2	1	2	0	1	2	0	0	3.2846036643348273	
i 1	328.2496394557823	0.2525	75	701	5	3	5	2	0	1	2	0	0	3.2846036643348273	
i 1	328.48377551020405	0.2525	72	701	5	3	15	2	0	-2	2	0	0	3.2846036643348273	
i 1	328.48738095238093	1.2625	74	203	6	5	2	2	0	-2	2	0	0	3.0	
i 1	328.49242857142855	0.2525	72	701	4	4	7	2	0	-2	2	0	0	3.2846036643348273	
i 1	328.5111768707483	1.2625	74	1087	6	5	7	2	0	-1	2	0	0	3.0	
i 1	328.73449659863945	0.505	75	203	6	9	14	2	0	-2	2	0	0	2.2846036643348273	
i 1	328.7676666666667	0.505	72	1087	5	2	16	2	0	1	2	0	0	3.2846036643348273	
i 1	328.9866598639456	1.2625	68	203	1	24	6	1	0	0	1	0	0	4.92669720094845	
i 1	328.98738095238093	0.2525	71	701	1	24	13	1	0	-1	1	0	0	4.92669720094845	
i 1	329.0176666666667	0.2525	71	1087	3	20	7	0	0	-1	0	0	0	0.9266972009484502	
i 1	329.2633401360544	1.01	72	701	5	3	7	2	0	-2	2	0	0	3.2846036643348273	
i 1	329.26622448979595	1.01	72	701	4	4	14	2	0	-2	2	0	0	3.2846036643348273	
i 1	329.74891836734696	1.2625	71	701	4	5	13	8	0	-2	8	0	0	3.0	
i 1	329.7640612244898	1.2625	74	1087	6	5	14	2	0	-2	2	0	0	3.0	
i 1	330.23377551020405	0.505	68	701	1	20	10	0	0	-1	0	0	0	0.9266972009484502	
i 1	330.23738095238093	2.525	74	203	6	1	5	16	0	2	16	0	0	2.0	
i 1	330.2409863945578	2.02	68	203	3	20	5	1	0	-1	1	0	0	0.9266972009484502	
i 1	330.24387074829934	1.01	75	701	5	3	14	2	0	1	2	0	0	3.2846036643348273	
i 1	330.24819727891156	1.01	72	1087	5	2	13	2	0	1	2	0	0	3.2846036643348273	
i 1	330.25973469387753	2.525	74	701	4	24	3	17	0	1	17	0	0	3.0	
i 1	330.7409863945578	1.01	68	203	1	24	11	1	0	0	1	0	0	4.92669720094845	
i 1	330.9945918367347	1.01	74	701	6	5	11	2	0	-2	2	0	0	3.0	
i 1	331.00685034013605	1.01	74	203	6	5	4	8	0	-1	8	0	0	3.0	
i 1	331.23810204081633	0.2525	75	701	4	4	7	2	0	-2	2	0	0	3.2846036643348273	
i 1	331.25685034013605	0.2525	72	203	6	9	13	2	0	1	2	0	0	2.2846036643348273	
i 1	331.48449659863945	0.2525	72	701	5	3	6	2	0	-2	2	0	0	3.2846036643348273	
i 1	331.50180272108844	0.2525	72	701	4	4	16	2	0	-2	2	0	0	3.2846036643348273	
i 1	331.73954421768707	0.505	68	701	1	20	15	0	0	-1	0	0	0	0.9266972009484502	
i 1	331.7496394557823	0.505	72	1087	5	2	15	2	0	1	2	0	0	3.2846036643348273	
i 1	331.76189795918367	0.505	75	701	5	3	2	2	0	1	2	0	0	3.2846036643348273	
i 1	332.00973469387753	0.2525	74	203	6	5	15	2	0	-2	2	0	0	3.0	
i 1	332.01550340136055	0.2525	74	1087	6	5	11	2	0	-1	2	0	0	3.0	
i 1	332.2330544217687	1.01	72	701	5	3	4	2	0	-2	2	0	0	3.2846036643348273	
i 1	332.23954421768707	0.2525	71	203	1	20	1	0	0	-1	0	0	0	0.9266972009484502	
i 1	332.2496394557823	1.01	72	701	4	4	7	2	0	-2	2	0	0	3.2846036643348273	
i 1	332.25252380952384	2.525	74	1087	6	5	5	2	0	-2	2	0	0	3.0	
i 1	332.25757142857145	2.525	71	701	4	5	1	8	0	-2	8	0	0	3.0	
i 1	332.25757142857145	0.2525	71	701	1	24	5	1	0	-1	1	0	0	4.92669720094845	
i 1	332.26261904761907	0.2525	71	1087	3	20	11	0	0	-1	0	0	0	0.9266972009484502	
i 1	332.4866598639456	1.2625	71	203	3	20	1	1	0	-1	1	0	0	0.9266972009484502	
i 1	332.49387074829934	1.7675	68	203	1	24	1	1	0	0	1	0	0	4.92669720094845	
i 1	332.51550340136055	1.01	71	701	1	24	10	1	0	252	1	307	0	4.92669720094845	
i 1	332.7388231292517	0.7575000000000001	77	701	2	1	6	17	0	1	17	0	0	2.0	
i 1	332.7669455782313	0.7575000000000001	77	1087	6	1	4	16	0	1	16	0	0	2.0	
i 1	333.23810204081633	0.7575000000000001	75	203	6	9	9	2	0	-2	2	0	0	2.2846036643348273	
i 1	333.25180272108844	0.7575000000000001	72	1087	5	2	13	2	0	1	2	0	0	3.2846036643348273	
i 1	333.48954421768707	0.505	74	203	6	1	15	16	0	2	16	0	0	2.0	
i 1	333.50252380952384	0.505	71	701	1	24	11	1	0	-1	1	0	0	4.92669720094845	
i 1	333.50973469387753	0.505	74	701	4	24	14	17	0	1	17	0	0	3.0	
i 1	333.74026530612247	0.2525	71	203	3	20	10	0	0	-1	0	0	0	0.9266972009484502	
i 1	333.7460340136054	1.2625	71	203	1	20	12	0	0	-1	0	0	0	0.9266972009484502	
i 1	333.9823333333333	0.2525	71	1087	3	20	10	0	0	-1	0	0	0	0.9266972009484502	
i 1	333.9830544217687	0.7575000000000001	77	1087	6	1	8	16	0	1	16	0	0	2.0	
i 1	334.0032448979592	0.2525	68	1087	3	20	4	0	0	-1	0	0	0	0.9266972009484502	
i 1	334.01478231292515	0.2525	72	701	4	4	1	2	0	-2	2	0	0	3.2846036643348273	
i 1	334.01622448979595	0.2525	72	701	5	3	7	2	0	-2	2	0	0	3.2846036643348273	
i 1	334.0169455782313	0.7575000000000001	77	701	2	1	8	17	0	1	17	0	0	2.0	
i 1	334.23954421768707	0.505	68	203	3	20	5	0	0	-1	0	0	0	0.9266972009484502	
i 1	334.23954421768707	0.505	68	203	3	20	15	1	0	0	1	0	0	0.9266972009484502	
i 1	334.25108163265304	0.505	75	701	5	3	14	2	0	1	2	0	0	3.2846036643348273	
i 1	334.26478231292515	0.505	72	1087	5	2	13	2	0	1	2	0	0	3.2846036643348273	
i 1	334.73810204081633	1.2625	74	1087	4	5	3	8	0	-2	8	0	0	3.0	
i 1	334.73954421768707	0.7575000000000001	74	203	7	1	5	16	0	2	16	0	0	2.0	
i 1	334.74242857142855	1.2625	74	701	6	5	1	2	0	-2	2	0	0	3.0	
i 1	334.7445918367347	0.7575000000000001	72	701	5	3	7	2	0	-2	2	0	0	3.2846036643348273	
i 1	334.75108163265304	10.352500000000001	61	1087	1	27	16	9	0	248	9	308	0	0.8069230363879212	
i 1	334.7532448979592	0.7575000000000001	75	1087	5	3	14	2	0	-2	2	0	0	3.2846036643348273	
i 1	334.7539659863946	16.4125	68	1087	1	24	9	0	0	252	0	307	0	4.92669720094845	
i 1	334.7539659863946	10.352500000000001	66	203	6	14	3	9	0	2	9	0	0	5.642238441933668	
i 1	334.7539659863946	10.352500000000001	61	203	6	14	4	9	0	1	9	0	0	5.642238441933668	
i 1	334.7554081632653	0.2525	68	203	4	20	14	0	0	-1	0	0	0	0.9266972009484502	
i 1	334.7582925170068	0.2525	68	203	4	20	14	1	0	0	1	0	0	0.9266972009484502	
i 1	334.7611768707483	0.7575000000000001	74	203	6	1	3	16	0	2	16	0	0	2.0	
i 1	334.9967551020408	0.7575000000000001	68	203	3	20	7	0	0	-1	0	0	0	0.9266972009484502	
i 1	335.01478231292515	0.7575000000000001	68	203	1	24	6	1	0	0	1	0	0	4.92669720094845	
i 1	335.4823333333333	1.5150000000000001	74	1087	2	1	4	16	0	1	16	0	0	2.0	
i 1	335.49819727891156	1.01	75	203	6	9	7	2	0	-2	2	0	0	2.2846036643348273	
i 1	335.5039659863946	1.5150000000000001	77	701	6	1	3	17	0	2	17	0	0	2.0	
i 1	335.50612925170066	1.01	72	203	6	2	12	2	0	1	2	0	0	3.2846036643348273	
i 1	335.73377551020405	1.5150000000000001	71	1087	1	24	12	0	0	0	0	0	0	4.92669720094845	
i 1	335.7366598639456	1.5150000000000001	68	203	3	20	7	1	0	0	1	0	0	0.9266972009484502	
i 1	335.7633401360544	1.5150000000000001	71	203	1	20	5	0	0	-1	0	0	0	0.9266972009484502	
i 1	335.99026530612247	1.2625	71	203	7	5	3	8	0	-2	8	0	0	3.0	
i 1	335.9960340136054	1.2625	74	203	6	5	14	8	0	-1	8	0	0	3.0	
i 1	336.4859387755102	0.7575000000000001	75	1087	5	3	5	2	0	-2	2	0	0	3.2846036643348273	
i 1	336.4996394557823	0.7575000000000001	72	701	5	3	5	2	0	-2	2	0	0	3.2846036643348273	
i 1	336.9909863945578	1.2625	74	701	4	24	16	17	0	1	17	0	0	3.0	
i 1	337.0054081632653	1.2625	74	1087	2	24	2	16	0	2	16	0	0	3.0	
i 1	337.2323333333333	0.7575000000000001	74	203	6	5	6	2	0	-2	2	0	0	3.0	
i 1	337.2453129251701	0.2525	68	203	1	24	15	1	0	0	1	0	0	4.92669720094845	
i 1	337.24891836734696	0.2525	72	203	6	9	15	2	0	1	2	0	0	2.2846036643348273	
i 1	337.2532448979592	0.7575000000000001	71	203	7	5	13	8	0	-1	8	0	0	3.0	
i 1	337.2539659863946	0.2525	68	203	3	20	4	0	0	-1	0	0	0	0.9266972009484502	
i 1	337.2554081632653	0.2525	75	203	6	2	7	2	0	-2	2	0	0	3.2846036643348273	
i 1	337.49026530612247	0.2525	68	203	4	20	14	0	0	-1	0	0	0	0.9266972009484502	
i 1	337.49026530612247	0.2525	68	203	4	20	16	1	0	0	1	0	0	0.9266972009484502	
i 1	337.49819727891156	1.2625	71	203	1	20	7	0	0	-1	0	0	0	0.9266972009484502	
i 1	337.5082925170068	0.2525	75	1087	5	3	4	2	0	-2	2	0	0	3.2846036643348273	
i 1	337.51550340136055	0.2525	72	701	5	3	14	2	0	-2	2	0	0	3.2846036643348273	
i 1	337.7366598639456	1.01	75	203	6	9	4	2	0	-2	2	0	0	2.2846036643348273	
i 1	337.73810204081633	1.01	68	203	3	20	13	1	0	0	1	0	0	0.9266972009484502	
i 1	337.73954421768707	1.01	72	203	6	2	6	2	0	1	2	0	0	3.2846036643348273	
i 1	337.7453129251701	0.505	68	203	1	24	14	1	0	0	1	0	0	4.92669720094845	
i 1	337.7460340136054	0.505	68	203	3	20	1	0	0	-1	0	0	0	0.9266972009484502	
i 1	337.7640612244898	0.505	71	1087	1	24	3	1	0	252	1	307	0	4.92669720094845	
i 1	337.98377551020405	1.7675	74	203	6	5	3	8	0	-1	8	0	0	3.0	
i 1	338.01550340136055	1.7675	71	203	7	5	13	8	0	-2	8	0	0	3.0	
i 1	338.26478231292515	0.505	74	203	6	1	8	16	0	2	16	0	0	2.0	
i 1	338.26550340136055	0.505	74	203	7	1	11	16	0	2	16	0	0	2.0	
i 1	338.26622448979595	0.505	71	1087	1	24	10	1	0	0	1	0	0	4.92669720094845	
i 1	338.73377551020405	0.2525	68	203	4	20	1	1	0	0	1	0	0	0.9266972009484502	
i 1	338.7417074829932	1.5150000000000001	74	701	4	24	16	17	0	1	17	0	0	3.0	
i 1	338.74242857142855	0.505	75	701	4	4	4	2	0	-2	2	0	0	3.2846036643348273	
i 1	338.74819727891156	1.5150000000000001	74	1087	2	24	3	16	0	2	16	0	0	3.0	
i 1	338.75108163265304	0.2525	71	701	3	24	8	1	0	-1	1	0	0	4.92669720094845	
i 1	338.75252380952384	0.2525	68	203	1	24	6	1	0	0	1	0	0	4.92669720094845	
i 1	338.76550340136055	1.01	72	1087	4	4	4	2	0	1	2	0	0	3.2846036643348273	
i 1	338.9866598639456	0.7575000000000001	68	1087	1	20	8	0	0	-1	0	0	0	0.9266972009484502	
i 1	339.2554081632653	5.8075	61	203	6	25	9	9	0	2	9	0	0	0.04036883330323932	
i 1	339.2676666666667	0.505	75	701	4	4	8	2	0	-2	2	0	0	3.2846036643348273	
i 1	339.73449659863945	0.7575000000000001	72	701	5	3	4	2	0	-2	2	0	0	3.2846036643348273	
i 1	339.7467551020408	0.7575000000000001	75	1087	5	3	14	2	0	-2	2	0	0	3.2846036643348273	
i 1	339.7467551020408	0.2525	71	701	3	20	2	0	0	0	0	0	0	0.9266972009484502	
i 1	339.75108163265304	2.7775	71	203	7	5	13	8	0	-1	8	0	0	3.0	
i 1	339.75685034013605	2.7775	74	203	6	5	7	2	0	-2	2	0	0	3.0	
i 1	339.7676666666667	0.2525	68	203	4	20	5	1	0	0	1	0	0	0.9266972009484502	
i 1	339.98377551020405	0.7575000000000001	71	203	1	20	8	0	0	-1	0	0	0	0.9266972009484502	
i 1	340.00252380952384	0.7575000000000001	68	1087	1	24	4	1	0	0	1	0	0	4.92669720094845	
i 1	340.0111768707483	0.7575000000000001	68	203	3	20	6	1	0	0	1	0	0	0.9266972009484502	
i 1	340.24026530612247	2.7775	74	203	7	1	13	16	0	2	16	0	0	2.0	
i 1	340.2496394557823	2.7775	74	203	6	1	14	16	0	2	16	0	0	2.0	
i 1	340.4967551020408	0.2525	72	203	6	2	14	2	0	1	2	0	0	3.2846036643348273	
i 1	340.5039659863946	0.2525	75	203	6	9	11	2	0	-2	2	0	0	2.2846036643348273	
i 1	340.73377551020405	0.2525	68	203	3	20	14	0	0	-1	0	0	0	0.9266972009484502	
i 1	340.7409863945578	0.2525	75	1087	5	3	15	2	0	-2	2	0	0	3.2846036643348273	
i 1	340.74242857142855	0.2525	72	701	5	3	3	2	0	-2	2	0	0	3.2846036643348273	
i 1	340.7590136054422	0.2525	68	203	3	24	14	1	0	0	1	0	0	4.92669720094845	
i 1	340.98377551020405	1.01	71	1087	1	20	2	0	0	0	0	0	0	0.9266972009484502	
i 1	341.00685034013605	0.2525	72	203	6	9	16	2	0	1	2	0	0	2.2846036643348273	
i 1	341.0082925170068	0.2525	75	203	6	2	13	2	0	-2	2	0	0	3.2846036643348273	
i 1	341.01478231292515	1.01	68	1087	1	24	16	1	0	0	1	0	0	4.92669720094845	
i 1	341.2323333333333	0.7575000000000001	75	1087	5	3	7	2	0	-2	2	0	0	3.2846036643348273	
i 1	341.24242857142855	0.7575000000000001	72	701	5	3	1	2	0	-2	2	0	0	3.2846036643348273	
i 1	341.99026530612247	1.7675	72	203	6	2	3	2	0	1	2	0	0	3.2846036643348273	
i 1	341.9945918367347	0.2525	68	701	3	20	1	0	0	-1	0	0	0	0.9266972009484502	
i 1	341.9960340136054	1.7675	75	203	6	9	12	2	0	-2	2	0	0	2.2846036643348273	
i 1	342.00180272108844	0.2525	68	701	3	24	9	1	0	0	1	0	0	4.92669720094845	
i 1	342.0090136054422	0.2525	68	203	3	24	5	1	0	0	1	0	0	4.92669720094845	
i 1	342.2330544217687	2.7775	71	203	1	20	9	0	0	-1	0	0	0	0.9266972009484502	
i 1	342.25612925170066	2.525	68	203	3	20	11	1	0	0	1	0	0	0.9266972009484502	
i 1	342.26478231292515	1.5150000000000001	68	1087	1	24	15	1	0	0	1	0	0	4.92669720094845	
i 1	342.4823333333333	1.2625	71	203	7	5	11	8	0	-2	8	0	0	3.0	
i 1	342.49747619047616	1.2625	74	203	6	5	15	8	0	-1	8	0	0	3.0	
i 1	342.9888231292517	0.7575000000000001	77	701	6	1	8	17	0	2	17	0	0	2.0	
i 1	343.00685034013605	0.7575000000000001	74	1087	4	1	9	16	0	1	16	0	0	2.0	
i 1	343.7359387755102	0.7575000000000001	74	1087	4	5	10	8	0	-2	8	0	0	3.0	
i 1	343.7445918367347	1.2625	74	1087	2	24	16	16	0	2	16	0	0	3.0	
i 1	343.7453129251701	0.2525	72	1087	4	4	15	2	0	1	2	0	0	3.2846036643348273	
i 1	343.7460340136054	1.01	68	203	3	20	8	0	0	-1	0	0	0	0.9266972009484502	
i 1	343.7590136054422	1.01	68	203	3	24	7	1	0	0	1	0	0	4.92669720094845	
i 1	343.7669455782313	2.02	74	701	4	24	16	17	0	1	17	0	0	3.0	
i 1	343.7669455782313	0.2525	75	701	4	4	10	2	0	-2	2	0	0	3.2846036643348273	
i 1	343.7669455782313	0.7575000000000001	74	701	6	5	10	2	0	-2	2	0	0	3.0	
i 1	344.00612925170066	0.2525	75	1087	5	3	16	2	0	-2	2	0	0	3.2846036643348273	
i 1	344.01261904761907	0.2525	72	701	5	3	4	2	0	-2	2	0	0	3.2846036643348273	
i 1	344.23738095238093	0.2525	75	203	6	9	8	2	0	-2	2	0	0	2.2846036643348273	
i 1	344.24747619047616	0.2525	72	203	6	2	15	2	0	1	2	0	0	3.2846036643348273	
i 1	344.48954421768707	0.505	75	1087	5	3	9	2	0	-2	2	0	0	3.2846036643348273	
i 1	344.4967551020408	0.505	72	701	5	3	15	2	0	-2	2	0	0	3.2846036643348273	
i 1	344.50180272108844	0.2525	71	203	7	5	13	8	0	-2	8	0	0	3.0	
i 1	344.51045578231293	0.2525	74	203	6	5	15	8	0	-1	8	0	0	3.0	
i 1	344.73954421768707	2.525	68	203	4	20	12	0	0	-1	0	0	0	0.9266972009484502	
i 1	344.74747619047616	0.2525	74	203	6	5	12	2	0	-2	2	0	0	3.0	
i 1	344.7611768707483	0.2525	71	203	7	5	7	8	0	-1	8	0	0	3.0	
i 1	344.9909863945578	0.2525	72	701	5	3	8	2	0	-2	2	0	0	3.0190967826718174	
i 1	344.99387074829934	0.2525	75	1087	5	3	15	2	0	-2	2	0	0	3.0190967826718174	
i 1	344.9960340136054	0.2525	68	203	3	24	3	1	0	0	1	0	0	4.92669720094845	
i 1	344.99747619047616	1.2625	71	203	7	5	16	8	0	-1	8	0	0	2.0	
i 1	345.00685034013605	5.8075	66	701	5	15	15	6	0	2	6	0	0	0.4639022334668533	
i 1	345.0082925170068	0.7575000000000001	74	1087	4	24	6	16	0	2	16	0	0	3.0	
i 1	345.00973469387753	34.845	66	701	5	15	2	6	0	2	6	0	0	0.4639022334668533	
i 1	345.00973469387753	1.2625	74	203	6	5	1	2	0	-2	2	0	0	2.0	
i 1	345.0140612244898	23.23	61	203	6	14	13	9	0	2	9	0	0	1.3917067004005599	
i 1	345.01478231292515	11.615	61	203	5	16	1	6	0	1	6	0	0	0.9278044669337066	
i 1	345.23954421768707	1.01	71	203	3	20	2	0	0	-1	0	0	0	0.9266972009484502	
i 1	345.2546870748299	1.01	72	203	5	9	8	2	0	1	2	0	0	2.0190967826718174	
i 1	345.2554081632653	1.01	75	203	6	2	1	2	0	-2	2	0	0	3.0190967826718174	
i 1	345.25757142857145	0.2525	68	203	4	20	11	1	0	0	1	0	0	0.9266972009484502	
i 1	345.5003605442177	0.2525	68	203	3	20	4	1	0	0	1	0	0	0.9266972009484502	
i 1	345.51189795918367	0.2525	68	203	3	24	10	1	0	0	1	0	0	4.92669720094845	
i 1	345.7417074829932	0.7575000000000001	74	203	7	1	9	16	0	2	16	0	0	2.0	
i 1	345.7445918367347	0.7575000000000001	74	203	6	1	1	16	0	2	16	0	0	2.0	
i 1	346.24026530612247	1.01	68	203	3	24	14	1	0	0	1	0	0	4.92669720094845	
i 1	346.24387074829934	0.7575000000000001	75	1087	5	3	7	2	0	-2	2	0	0	3.0190967826718174	
i 1	346.2445918367347	2.7775	74	203	6	5	15	8	0	-1	8	0	0	2.0	
i 1	346.25108163265304	0.7575000000000001	72	701	5	3	13	2	0	-2	2	0	0	3.0190967826718174	
i 1	346.2590136054422	2.7775	71	203	7	5	1	8	0	-2	8	0	0	2.0	
i 1	346.5054081632653	1.5150000000000001	74	701	4	24	8	17	0	1	17	0	0	3.0	
i 1	346.51550340136055	1.5150000000000001	74	1087	4	24	7	16	0	2	16	0	0	3.0	
i 1	347.0046870748299	0.505	72	203	6	2	5	2	0	1	2	0	0	3.0190967826718174	
i 1	347.00973469387753	0.505	75	203	6	9	13	2	0	-2	2	0	0	2.0190967826718174	
i 1	347.23449659863945	1.01	68	1087	1	20	12	1	0	-1	1	0	0	0.9266972009484502	
i 1	347.25685034013605	1.01	68	1087	1	24	16	0	0	0	0	0	0	4.92669720094845	
i 1	347.4866598639456	0.2525	75	701	4	4	7	2	0	-2	2	0	0	3.0190967826718174	
i 1	347.4996394557823	0.2525	72	1087	4	4	2	2	0	1	2	0	0	3.0190967826718174	
i 1	347.73954421768707	0.7575000000000001	75	1087	5	3	14	2	0	-2	2	0	0	3.0190967826718174	
i 1	347.75180272108844	0.7575000000000001	72	701	5	3	12	2	0	-2	2	0	0	3.0190967826718174	
i 1	347.9967551020408	1.7675	74	203	6	1	6	16	0	2	16	0	0	2.0	
i 1	347.99891836734696	1.7675	74	203	7	1	12	16	0	2	16	0	0	2.0	
i 1	348.23810204081633	0.7575000000000001	68	203	4	20	1	0	0	-1	0	0	0	0.9266972009484502	
i 1	348.2590136054422	0.2525	71	203	3	20	8	0	0	-1	0	0	0	0.9266972009484502	
i 1	348.25973469387753	0.505	68	203	3	24	1	1	0	0	1	0	0	4.92669720094845	
i 1	348.2633401360544	0.2525	68	203	3	20	15	1	0	0	1	0	0	0.9266972009484502	
i 1	348.49314965986395	1.01	75	203	6	9	7	2	0	-2	2	0	0	2.0190967826718174	
i 1	348.49387074829934	0.2525	68	1087	1	24	2	0	0	0	0	0	0	4.92669720094845	
i 1	348.5032448979592	1.01	72	203	6	2	15	2	0	1	2	0	0	3.0190967826718174	
i 1	348.76478231292515	0.2525	71	701	3	20	16	0	0	0	0	0	0	0.9266972009484502	
i 1	349.00685034013605	2.02	74	203	6	5	10	2	0	-2	2	0	0	2.0	
i 1	349.00685034013605	0.2525	68	1087	1	20	11	1	0	-1	1	0	0	0.9266972009484502	
i 1	349.0111768707483	2.02	71	203	7	5	5	8	0	-1	8	0	0	2.0	
i 1	349.2539659863946	0.505	68	701	3	20	2	0	0	0	0	0	0	0.9266972009484502	
i 1	349.25612925170066	0.505	71	701	3	24	3	1	0	-1	1	0	0	4.92669720094845	
i 1	349.2669455782313	1.5150000000000001	68	203	3	24	3	1	0	0	1	0	0	4.92669720094845	
i 1	349.49387074829934	0.7575000000000001	72	701	5	3	6	2	0	-2	2	0	0	3.0190967826718174	
i 1	349.5082925170068	0.7575000000000001	75	1087	5	3	6	2	0	-2	2	0	0	3.0190967826718174	
i 1	349.74314965986395	1.2625	68	203	4	20	10	0	0	-1	0	0	0	0.9266972009484502	
i 1	349.7445918367347	1.5150000000000001	74	1087	4	1	14	16	0	1	16	0	0	2.0	
i 1	349.74891836734696	1.01	68	1087	1	24	8	1	0	-1	1	0	0	4.92669720094845	
i 1	349.76622448979595	1.5150000000000001	77	701	6	1	13	17	0	2	17	0	0	2.0	
i 1	350.23521768707485	0.2525	75	203	6	2	6	2	0	-2	2	0	0	3.0190967826718174	
i 1	350.25685034013605	0.2525	72	203	5	9	5	2	0	1	2	0	0	2.0190967826718174	
i 1	350.48810204081633	0.2525	72	701	5	3	12	2	0	-2	2	0	0	3.0190967826718174	
i 1	350.50252380952384	0.2525	75	1087	5	3	10	2	0	-2	2	0	0	3.0190967826718174	
i 1	350.73954421768707	1.01	75	203	5	9	13	2	0	-2	2	0	0	2.0190967826718174	
i 1	350.7417074829932	11.615	66	203	5	16	3	9	0	2	9	0	0	0.9278044669337066	
i 1	350.74387074829934	1.01	72	203	6	2	9	2	0	1	2	0	0	3.0190967826718174	
i 1	350.7554081632653	0.7575000000000001	71	203	3	20	6	0	0	-1	0	0	0	0.9266972009484502	
i 1	350.7590136054422	0.2525	71	701	3	20	1	1	0	-1	1	0	0	0.9266972009484502	
i 1	350.7669455782313	30.0475	66	701	5	15	3	6	0	2	6	0	0	0.4639022334668533	
i 1	350.98954421768707	0.2525	74	203	6	5	11	8	0	-1	8	0	0	2.0	
i 1	350.99026530612247	0.2525	71	203	7	5	15	8	0	-2	8	0	0	2.0	
i 1	350.9953129251701	1.01	68	1087	1	24	16	0	0	0	0	0	0	4.92669720094845	
i 1	350.99747619047616	0.505	68	1087	1	20	9	1	0	0	1	0	0	0.9266972009484502	
i 1	351.0054081632653	1.01	68	203	4	20	3	1	0	0	1	0	0	0.9266972009484502	
i 1	351.2496394557823	2.2725	74	1087	4	24	7	16	0	2	16	0	0	3.0	
i 1	351.25252380952384	1.5150000000000001	74	1087	4	5	7	8	0	-2	8	0	0	2.0	
i 1	351.25612925170066	2.2725	74	701	4	24	7	17	0	1	17	0	0	3.0	
i 1	351.2669455782313	1.5150000000000001	74	701	6	5	6	2	0	-2	2	0	0	2.0	
i 1	351.48449659863945	1.01	68	203	3	24	14	1	0	0	1	0	0	4.92669720094845	
i 1	351.50252380952384	0.505	71	701	3	24	7	0	0	-1	0	0	0	4.92669720094845	
i 1	351.73449659863945	1.01	72	1087	4	4	4	2	0	1	2	0	0	3.0190967826718174	
i 1	351.74819727891156	1.01	75	701	4	4	15	2	0	-2	2	0	0	3.0190967826718174	
i 1	351.9830544217687	0.505	68	1087	1	24	13	1	0	-1	1	0	0	4.92669720094845	
i 1	352.0039659863946	0.7575000000000001	68	203	4	20	11	0	0	-1	0	0	0	0.9266972009484502	
i 1	352.49387074829934	1.01	68	203	4	20	2	1	0	0	1	0	0	0.9266972009484502	
i 1	352.49819727891156	0.2525	68	1087	1	24	9	0	0	0	0	0	0	4.92669720094845	
i 1	352.51550340136055	0.7575000000000001	71	203	3	20	12	0	0	-1	0	0	0	0.9266972009484502	
i 1	352.73377551020405	0.505	68	1087	1	24	15	0	0	252	0	307	0	4.92669720094845	
i 1	352.7467551020408	0.7575000000000001	72	701	5	3	5	2	0	-2	2	0	0	3.0190967826718174	
i 1	352.75612925170066	0.7575000000000001	75	1087	5	3	16	2	0	-2	2	0	0	3.0190967826718174	
i 1	352.75757142857145	1.5150000000000001	71	203	7	5	10	8	0	-2	8	0	0	2.0	
i 1	352.75973469387753	1.5150000000000001	74	203	6	5	10	8	0	-1	8	0	0	2.0	
i 1	353.2366598639456	0.2525	71	701	3	24	6	1	0	-1	1	0	0	4.92669720094845	
i 1	353.25180272108844	2.2725	68	203	3	24	3	1	0	0	1	0	0	4.92669720094845	
i 1	353.2532448979592	0.2525	68	1087	1	24	3	0	0	0	0	0	0	4.92669720094845	
i 1	353.48810204081633	0.2525	75	203	5	9	9	2	0	-2	2	0	0	2.0190967826718174	
i 1	353.4967551020408	3.0300000000000002	68	203	4	20	16	0	0	-1	0	0	0	0.9266972009484502	
i 1	353.50252380952384	0.7575000000000001	68	1087	1	24	4	0	0	252	0	307	0	4.92669720094845	
i 1	353.5046870748299	0.2525	72	203	6	2	9	2	0	1	2	0	0	3.0190967826718174	
i 1	353.50685034013605	0.505	74	203	6	1	1	16	0	2	16	0	0	2.0	
i 1	353.5082925170068	0.7575000000000001	68	1087	1	24	15	0	0	0	0	0	0	4.92669720094845	
i 1	353.51189795918367	0.505	74	203	7	1	13	16	0	2	16	0	0	2.0	
i 1	353.74819727891156	0.2525	75	1087	5	3	7	2	0	-2	2	0	0	3.0190967826718174	
i 1	353.7546870748299	0.2525	72	701	5	3	11	2	0	-2	2	0	0	3.0190967826718174	
i 1	353.98449659863945	0.7575000000000001	74	1087	4	24	12	16	0	2	16	0	0	3.0	
i 1	353.9953129251701	0.7575000000000001	74	701	4	24	4	17	0	1	17	0	0	3.0	
i 1	354.00612925170066	0.2525	75	203	7	2	3	2	0	-2	2	0	0	3.0190967826718174	
i 1	354.01550340136055	0.2525	72	203	5	9	16	2	0	1	2	0	0	2.0190967826718174	
i 1	354.23449659863945	0.7575000000000001	75	1087	5	3	16	2	0	-2	2	0	0	3.0190967826718174	
i 1	354.2417074829932	1.2625	74	203	6	5	9	2	0	-2	2	0	0	2.0	
i 1	354.24314965986395	0.7575000000000001	72	701	5	3	13	2	0	-2	2	0	0	3.0190967826718174	
i 1	354.25108163265304	1.2625	71	203	7	5	1	8	0	-1	8	0	0	2.0	
i 1	354.2532448979592	1.2625	68	1087	1	24	4	0	0	0	0	0	0	4.92669720094845	
i 1	354.26189795918367	1.2625	68	1087	1	20	10	0	0	-1	0	0	0	0.9266972009484502	
i 1	354.7582925170068	2.7775	74	203	7	1	11	16	0	2	16	0	0	2.0	
i 1	354.7669455782313	2.7775	74	203	6	1	12	16	0	2	16	0	0	2.0	
i 1	354.9830544217687	1.7675	75	203	5	9	10	2	0	-2	2	0	0	2.0190967826718174	
i 1	354.99891836734696	1.5150000000000001	72	203	6	2	11	2	0	1	2	0	0	3.0190967826718174	
i 1	355.4953129251701	2.02	74	203	6	5	4	8	0	-1	8	0	0	2.0	
i 1	355.4953129251701	0.2525	71	203	3	20	4	0	0	-1	0	0	0	0.9266972009484502	
i 1	355.5169455782313	1.01	71	203	7	5	16	8	0	-2	8	0	0	2.0	
i 1	355.7633401360544	0.7575000000000001	71	1087	1	24	11	0	0	-1	0	0	0	4.92669720094845	
i 1	355.7633401360544	2.7775	68	203	3	24	9	1	0	0	1	0	0	4.92669720094845	
i 1	356.48377551020405	1.01	71	203	7	5	12	8	0	-2	8	0	0	2.0	
i 1	356.48738095238093	9.595	61	203	5	16	9	6	0	1	6	0	0	0.9278044669337066	
i 1	356.4996394557823	9.595	66	1087	3	12	1	9	0	2	9	0	0	0.9278044669337066	
i 1	356.50757142857145	0.2525	72	203	7	2	7	2	0	1	2	0	0	3.0190967826718174	
i 1	356.50757142857145	0.2525	68	1087	1	20	12	1	0	0	1	0	0	0.9266972009484502	
i 1	356.5133401360544	0.2525	71	701	3	24	6	1	0	-1	1	0	0	4.92669720094845	
i 1	356.51550340136055	0.2525	71	701	4	20	6	1	0	-1	1	0	0	0.9266972009484502	
i 1	356.73738095238093	0.2525	68	1087	1	24	14	0	0	0	0	0	0	4.92669720094845	
i 1	356.7417074829932	0.2525	72	1087	4	4	7	2	0	1	2	0	0	3.0190967826718174	
i 1	356.7467551020408	0.2525	75	701	4	4	4	2	0	-2	2	0	0	3.0190967826718174	
i 1	356.7496394557823	0.2525	68	1087	2	20	9	0	0	0	0	0	0	0.9266972009484502	
i 1	356.76045578231293	1.7675	68	203	4	20	12	0	0	-1	0	0	0	0.9266972009484502	
i 1	356.99891836734696	0.7575000000000001	68	203	4	20	16	1	0	0	1	0	0	0.9266972009484502	
i 1	357.01478231292515	0.2525	75	1087	3	3	11	2	0	-2	2	0	0	3.0190967826718174	
i 1	357.0169455782313	0.7575000000000001	71	203	3	20	5	0	0	-1	0	0	0	0.9266972009484502	
i 1	357.23377551020405	0.2525	72	203	7	2	11	2	0	1	2	0	0	3.0190967826718174	
i 1	357.23449659863945	0.2525	75	203	5	9	4	2	0	-2	2	0	0	2.0190967826718174	
i 1	357.48521768707485	1.5150000000000001	74	1087	4	1	4	16	0	1	16	0	0	2.0	
i 1	357.49026530612247	1.5150000000000001	77	701	6	1	3	17	0	2	17	0	0	2.0	
i 1	357.4917074829932	1.7675	71	203	7	5	16	8	0	-1	8	0	0	2.0	
i 1	357.4960340136054	0.7575000000000001	72	701	5	3	1	2	0	-2	2	0	0	3.0190967826718174	
i 1	357.50252380952384	0.7575000000000001	75	1087	3	3	13	2	0	-2	2	0	0	3.0190967826718174	
i 1	357.50612925170066	1.7675	74	203	6	5	7	2	0	-2	2	0	0	2.0	
i 1	358.23521768707485	0.2525	71	203	3	20	3	0	0	-1	0	0	0	0.9266972009484502	
i 1	358.24314965986395	1.01	72	203	5	9	3	2	0	1	2	0	0	2.0190967826718174	
i 1	358.2611768707483	1.01	75	203	7	2	16	2	0	-2	2	0	0	3.0190967826718174	
i 1	358.26189795918367	0.2525	68	701	3	24	11	1	0	-1	1	0	0	4.92669720094845	
i 1	358.4953129251701	0.7575000000000001	68	1087	1	24	15	0	0	0	0	0	0	4.92669720094845	
i 1	358.5046870748299	0.7575000000000001	68	1087	1	24	16	0	0	0	0	0	0	4.92669720094845	
i 1	358.5054081632653	1.5150000000000001	68	1087	1	20	3	1	0	0	1	0	0	0.9266972009484502	
i 1	358.51550340136055	0.7575000000000001	68	1087	2	20	16	0	0	-1	0	0	0	0.9266972009484502	
i 1	358.99026530612247	1.2625	74	1087	4	24	10	16	0	2	16	0	0	3.0	
i 1	359.0133401360544	1.2625	74	701	4	24	3	17	0	1	17	0	0	3.0	
i 1	359.2359387755102	0.2525	71	701	3	24	10	0	0	-1	0	0	0	4.92669720094845	
i 1	359.23738095238093	1.5150000000000001	71	203	7	5	15	8	0	-2	8	0	0	2.0	
i 1	359.24387074829934	0.7575000000000001	75	1087	3	3	15	2	0	-2	2	0	0	3.0190967826718174	
i 1	359.2467551020408	0.7575000000000001	68	203	3	24	16	1	0	0	1	0	0	4.92669720094845	
i 1	359.2539659863946	0.7575000000000001	72	701	5	3	14	2	0	-2	2	0	0	3.0190967826718174	
i 1	359.2582925170068	1.5150000000000001	74	203	6	5	4	8	0	-1	8	0	0	2.0	
i 1	359.26045578231293	0.2525	68	701	4	20	13	0	0	-1	0	0	0	0.9266972009484502	
i 1	359.48521768707485	0.505	71	1087	1	24	15	0	0	0	0	0	0	4.92669720094845	
i 1	359.5032448979592	0.505	68	203	4	20	15	0	0	-1	0	0	0	0.9266972009484502	
i 1	359.99819727891156	0.7575000000000001	71	203	3	20	12	0	0	-1	0	0	0	0.9266972009484502	
i 1	359.99891836734696	0.505	72	203	7	2	9	2	0	1	2	0	0	3.0190967826718174	
i 1	360.0054081632653	0.7575000000000001	68	203	4	20	1	1	0	0	1	0	0	0.9266972009484502	
i 1	360.01189795918367	0.505	75	203	5	9	11	2	0	-2	2	0	0	2.0190967826718174	
i 1	360.01189795918367	0.7575000000000001	68	203	1	24	12	1	0	248	1	308	0	4.92669720094845	
i 1	360.2366598639456	0.505	74	203	6	1	8	16	0	2	16	0	0	2.0	
i 1	360.2539659863946	0.505	74	203	7	1	11	16	0	2	16	0	0	2.0	
i 1	360.48449659863945	0.2525	72	1087	4	4	10	2	0	1	2	0	0	3.0190967826718174	
i 1	360.50973469387753	0.2525	75	701	4	4	13	2	0	-2	2	0	0	3.0190967826718174	
i 1	360.73377551020405	1.5150000000000001	74	701	4	24	6	17	0	1	17	0	0	3.0	
i 1	360.74387074829934	1.2625	74	1087	4	5	2	8	0	-2	8	0	0	2.0	
i 1	360.74891836734696	1.5150000000000001	74	1087	4	24	7	16	0	2	16	0	0	3.0	
i 1	360.7503605442177	1.5150000000000001	68	203	3	24	12	1	0	0	1	0	0	4.92669720094845	
i 1	360.75252380952384	0.7575000000000001	72	701	5	3	8	2	0	-2	2	0	0	3.0190967826718174	
i 1	360.75252380952384	0.7575000000000001	75	1087	3	3	14	2	0	-2	2	0	0	3.0190967826718174	
i 1	360.7532448979592	1.5150000000000001	68	1087	1	20	7	1	0	0	1	0	0	0.9266972009484502	
i 1	360.7539659863946	1.2625	74	701	6	5	6	2	0	-2	2	0	0	2.0	
i 1	360.7633401360544	1.5150000000000001	68	203	4	20	3	0	0	-1	0	0	0	0.9266972009484502	
i 1	360.76550340136055	1.5150000000000001	71	1087	1	24	16	0	0	0	0	0	0	4.92669720094845	
i 1	361.49242857142855	1.01	72	203	7	2	11	2	0	1	2	0	0	3.0190967826718174	
i 1	361.5090136054422	1.01	75	203	5	9	15	2	0	-2	2	0	0	2.0190967826718174	
i 1	361.98449659863945	1.2625	74	203	6	5	12	8	0	-1	8	0	0	2.0	
i 1	362.00612925170066	1.2625	71	203	7	5	8	8	0	-2	8	0	0	2.0	
i 1	362.2388231292517	3.7875	66	1087	3	12	6	9	0	1	9	0	0	0.9278044669337066	
i 1	362.24026530612247	0.505	68	203	3	24	4	1	0	0	1	0	0	4.569012066072285	
i 1	362.24242857142855	2.2725	68	203	4	20	2	0	0	-1	0	0	0	0.5690120660722853	
i 1	362.24819727891156	2.7775	74	203	6	1	8	16	0	2	16	0	0	2.0	
i 1	362.2539659863946	1.7675	71	203	3	20	3	0	0	-1	0	0	0	0.5690120660722853	
i 1	362.2633401360544	3.7875	66	203	5	16	2	9	0	2	9	0	0	0.9278044669337066	
i 1	362.2640612244898	0.505	68	203	4	20	10	1	0	0	1	0	0	0.5690120660722853	
i 1	362.26622448979595	2.7775	74	203	6	1	16	16	0	2	16	0	0	2.0	
i 1	362.4823333333333	0.7575000000000001	72	701	5	3	2	2	0	-2	2	0	0	3.0190967826718174	
i 1	362.51622448979595	0.7575000000000001	75	1087	3	3	1	2	0	-2	2	0	0	3.0190967826718174	
i 1	362.98377551020405	1.01	68	203	4	20	8	1	0	0	1	0	0	0.5690120660722853	
i 1	362.98521768707485	1.5150000000000001	68	203	3	24	14	1	0	0	1	0	0	4.569012066072285	
i 1	363.23449659863945	0.7575000000000001	74	203	6	5	2	2	0	-2	2	0	0	2.0	
i 1	363.23954421768707	0.7575000000000001	71	203	7	5	14	8	0	-1	8	0	0	2.0	
i 1	363.24026530612247	0.2525	72	203	5	9	6	2	0	1	2	0	0	2.0190967826718174	
i 1	363.24387074829934	0.2525	75	203	7	2	4	2	0	-2	2	0	0	3.0190967826718174	
i 1	363.4960340136054	0.2525	75	1087	3	3	12	2	0	-2	2	0	0	3.0190967826718174	
i 1	363.50108163265304	0.2525	72	701	5	3	14	2	0	-2	2	0	0	3.0190967826718174	
i 1	363.74819727891156	1.01	72	203	7	2	8	2	0	1	2	0	0	3.0190967826718174	
i 1	363.7503605442177	1.01	75	203	5	9	16	2	0	-2	2	0	0	2.0190967826718174	
i 1	363.9953129251701	1.7675	71	203	7	5	5	8	0	-2	8	0	0	2.0	
i 1	363.9967551020408	0.2525	71	1087	2	20	10	1	0	0	1	0	0	0.5690120660722853	
i 1	364.00757142857145	1.7675	74	203	6	5	11	8	0	-1	8	0	0	2.0	
i 1	364.01550340136055	0.2525	68	1087	1	24	15	0	0	0	0	0	0	4.569012066072285	
i 1	364.25252380952384	0.2525	71	203	3	20	9	0	0	-1	0	0	0	0.5690120660722853	
i 1	364.26550340136055	0.2525	68	701	4	24	14	1	0	0	1	0	0	4.569012066072285	
i 1	364.48377551020405	1.5150000000000001	68	1087	2	24	6	0	0	0	0	0	0	4.569012066072285	
i 1	364.48810204081633	1.5150000000000001	68	1087	1	20	10	1	0	0	1	0	0	0.5690120660722853	
i 1	364.4953129251701	1.5150000000000001	68	1087	1	24	8	0	0	0	0	0	0	4.569012066072285	
i 1	364.4960340136054	1.5150000000000001	71	1087	2	20	16	0	0	-1	0	0	0	0.5690120660722853	
i 1	364.7323333333333	1.01	72	1087	3	4	6	2	0	1	2	0	0	3.0190967826718174	
i 1	364.73449659863945	1.01	75	701	4	4	11	2	0	-2	2	0	0	3.0190967826718174	
i 1	364.9859387755102	0.7575000000000001	77	701	6	1	2	17	0	2	17	0	0	2.0	
i 1	365.0054081632653	0.7575000000000001	74	1087	4	1	8	16	0	1	16	0	0	2.0	
i 1	365.73377551020405	2.02	74	701	4	24	13	17	0	1	17	0	0	3.0	
i 1	365.73954421768707	0.2525	74	203	6	5	7	2	0	-2	2	0	0	2.0	
i 1	365.74387074829934	0.2525	75	1087	3	3	9	2	0	-2	2	0	0	3.0190967826718174	
i 1	365.7445918367347	2.7775	71	203	7	5	15	8	0	-1	8	0	0	2.0	
i 1	365.7503605442177	0.2525	74	1087	4	24	14	16	0	2	16	0	0	3.0	
i 1	365.7546870748299	0.7575000000000001	72	701	5	3	13	2	0	-2	2	0	0	3.0190967826718174	
i 1	365.98377551020405	14.645	61	1087	4	16	2	6	0	1	6	0	0	0.9278044669337066	
i 1	365.98521768707485	2.02	61	701	3	12	16	9	0	2	9	0	0	0.9278044669337066	
i 1	365.98738095238093	0.2525	71	701	4	24	5	0	0	-1	0	0	0	4.569012066072285	
i 1	365.9909863945578	0.2525	68	701	4	20	1	0	0	0	0	0	0	0.5690120660722853	
i 1	365.9960340136054	14.645	66	1087	4	16	13	6	0	1	6	0	0	0.9278044669337066	
i 1	365.9967551020408	7.8275	61	701	3	12	7	6	0	1	6	0	0	0.9278044669337066	
i 1	365.99891836734696	2.525	74	1087	5	5	9	2	0	-2	2	0	0	2.0	
i 1	366.00180272108844	0.505	75	701	3	3	13	2	0	-2	2	0	0	3.0190967826718174	
i 1	366.00252380952384	1.7675	71	701	1	20	4	0	0	-1	0	0	0	0.5690120660722853	
i 1	366.01189795918367	1.7675	77	701	4	24	3	16	0	2	16	0	0	3.0	
i 1	366.0133401360544	1.7675	68	1087	2	24	16	0	0	-1	0	0	0	4.569012066072285	
i 1	366.2409863945578	1.5150000000000001	68	1087	3	20	2	0	0	-1	0	0	0	0.5690120660722853	
i 1	366.26261904761907	1.5150000000000001	71	701	2	24	10	0	0	-1	0	0	0	4.569012066072285	
i 1	366.51189795918367	0.2525	72	203	7	2	15	2	0	1	2	0	0	3.0190967826718174	
i 1	366.5140612244898	0.2525	72	1087	4	9	1	8	0	-2	8	0	0	2.0190967826718174	
i 1	366.75685034013605	0.2525	72	701	5	3	11	2	0	-2	2	0	0	3.0190967826718174	
i 1	366.75757142857145	0.2525	75	701	3	3	3	2	0	-2	2	0	0	3.0190967826718174	
i 1	367.0046870748299	0.2525	72	1087	4	9	3	2	0	1	2	0	0	2.0190967826718174	
i 1	367.0090136054422	0.2525	75	203	7	2	8	2	0	-2	2	0	0	3.0190967826718174	
i 1	367.23954421768707	0.7575000000000001	72	701	5	3	13	2	0	-2	2	0	0	3.0190967826718174	
i 1	367.25180272108844	0.7575000000000001	75	701	3	3	1	2	0	-2	2	0	0	3.0190967826718174	
i 1	367.7388231292517	0.7575000000000001	74	203	6	1	3	16	0	2	16	0	0	2.0	
i 1	367.75685034013605	0.7575000000000001	74	1087	5	1	7	16	0	1	16	0	0	2.0	
i 1	367.76045578231293	1.01	68	1087	3	20	13	0	0	0	0	0	0	0.5690120660722853	
i 1	367.7640612244898	1.01	71	1087	2	20	9	1	0	0	1	0	0	0.5690120660722853	
i 1	367.99747619047616	12.625	61	701	5	12	14	9	0	2	9	0	0	0.9278044669337066	
i 1	367.99891836734696	1.7675	72	203	7	2	6	2	0	1	2	0	0	3.0190967826718174	
i 1	368.00180272108844	11.615	61	203	6	14	8	9	0	2	9	0	0	1.3917067004005599	
i 1	368.01622448979595	1.7675	72	1087	4	9	4	8	0	-2	8	0	0	2.0190967826718174	
i 1	368.48738095238093	1.2625	71	203	7	5	6	8	0	-2	8	0	0	2.0	
i 1	368.48810204081633	1.2625	71	1087	5	5	7	8	0	-1	8	0	0	2.0	
i 1	368.5032448979592	1.5150000000000001	77	701	4	24	2	16	0	2	16	0	0	3.0	
i 1	368.50757142857145	1.5150000000000001	74	701	4	24	4	17	0	1	17	0	0	3.0	
i 1	368.7445918367347	0.2525	71	701	2	24	4	0	0	-1	0	0	0	4.569012066072285	
i 1	368.74819727891156	2.2725	71	701	1	20	4	0	0	-1	0	0	0	0.5690120660722853	
i 1	368.7496394557823	0.2525	68	1087	2	20	2	0	0	-1	0	0	0	0.5690120660722853	
i 1	368.7590136054422	0.7575000000000001	68	1087	3	24	2	0	0	-1	0	0	0	4.569012066072285	
i 1	368.98954421768707	0.505	71	701	4	24	13	0	0	-1	0	0	0	4.569012066072285	
i 1	368.9953129251701	0.505	68	701	4	20	6	0	0	0	0	0	0	0.5690120660722853	
i 1	369.49314965986395	1.5150000000000001	68	701	1	24	9	0	0	0	0	0	0	4.569012066072285	
i 1	369.50757142857145	1.5150000000000001	71	701	2	24	8	0	0	-1	0	0	0	4.569012066072285	
i 1	369.51189795918367	1.5150000000000001	68	701	2	20	2	0	0	0	0	0	0	0.5690120660722853	
i 1	369.73377551020405	0.2525	75	701	4	4	12	2	0	-2	2	0	0	3.0190967826718174	
i 1	369.73521768707485	0.7575000000000001	74	701	6	5	4	2	0	-2	2	0	0	2.0	
i 1	369.7532448979592	0.7575000000000001	71	701	4	5	8	2	0	-1	2	0	0	2.0	
i 1	369.76478231292515	0.2525	72	701	3	4	13	2	0	-2	2	0	0	3.0190967826718174	
i 1	369.98954421768707	0.2525	75	701	3	3	3	2	0	-2	2	0	0	3.0190967826718174	
i 1	369.99747619047616	0.2525	72	701	5	3	15	2	0	-2	2	0	0	3.0190967826718174	
i 1	370.0090136054422	1.7675	74	1087	5	1	15	16	0	1	16	0	0	2.0	
i 1	370.0169455782313	1.7675	74	203	6	1	13	16	0	2	16	0	0	2.0	
i 1	370.23954421768707	0.2525	72	203	7	2	4	2	0	1	2	0	0	3.0190967826718174	
i 1	370.2496394557823	0.2525	72	1087	4	9	10	8	0	-2	8	0	0	2.0190967826718174	
i 1	370.4909863945578	0.7575000000000001	75	701	3	3	1	2	0	-2	2	0	0	3.0190967826718174	
i 1	370.4917074829932	0.2525	71	203	7	5	11	8	0	-2	8	0	0	2.0	
i 1	370.4967551020408	0.7575000000000001	72	701	5	3	15	2	0	-2	2	0	0	3.0190967826718174	
i 1	370.4996394557823	0.2525	71	1087	5	5	13	8	0	-1	8	0	0	2.0	
i 1	370.75612925170066	1.5150000000000001	74	1087	5	5	6	2	0	-2	2	0	0	2.0	
i 1	370.7640612244898	1.5150000000000001	71	203	7	5	12	8	0	-1	8	0	0	2.0	
i 1	370.99314965986395	1.01	68	1087	2	20	14	1	0	-1	1	0	0	0.5690120660722853	
i 1	371.00973469387753	1.01	68	1087	3	24	9	0	0	-1	0	0	0	4.569012066072285	
i 1	371.2388231292517	1.01	72	1087	4	9	13	2	0	1	2	0	0	2.0190967826718174	
i 1	371.2532448979592	1.01	75	203	7	2	5	2	0	-2	2	0	0	3.0190967826718174	
i 1	371.7417074829932	1.5150000000000001	77	701	5	1	13	17	0	2	17	0	0	2.0	
i 1	371.7445918367347	1.5150000000000001	74	701	4	1	14	17	0	1	17	0	0	2.0	
i 1	371.98449659863945	0.2525	68	203	4	20	10	0	0	0	0	0	0	0.5690120660722853	
i 1	371.98738095238093	0.2525	68	701	1	24	7	0	0	0	0	0	0	4.569012066072285	
i 1	371.9960340136054	1.2625	71	1087	2	20	13	1	0	0	1	0	0	0.5690120660722853	
i 1	372.01261904761907	0.2525	68	203	4	20	10	1	0	0	1	0	0	0.5690120660722853	
i 1	372.2330544217687	2.7775	71	203	7	5	2	8	0	-2	8	0	0	2.0	
i 1	372.24387074829934	0.7575000000000001	72	701	5	3	12	2	0	-2	2	0	0	3.0190967826718174	
i 1	372.2467551020408	0.7575000000000001	68	1087	3	24	1	0	0	-1	0	0	0	4.569012066072285	
i 1	372.2539659863946	0.7575000000000001	75	701	3	3	11	2	0	-2	2	0	0	3.0190967826718174	
i 1	372.2546870748299	0.7575000000000001	68	1087	2	20	3	0	0	0	0	0	0	0.5690120660722853	
i 1	372.26622448979595	0.7575000000000001	68	1087	3	20	12	0	0	0	0	0	0	0.5690120660722853	
i 1	372.2669455782313	2.7775	71	1087	5	5	5	8	0	-1	8	0	0	2.0	
i 1	372.98521768707485	0.2525	68	203	4	20	8	0	0	-1	0	0	0	0.5690120660722853	
i 1	372.9909863945578	0.505	72	203	7	2	2	2	0	1	2	0	0	3.0190967826718174	
i 1	373.0090136054422	0.505	72	1087	4	9	15	8	0	-2	8	0	0	2.0190967826718174	
i 1	373.23810204081633	0.505	74	701	4	24	5	17	0	1	17	0	0	3.0	
i 1	373.2409863945578	0.2525	68	1087	3	24	10	0	0	-1	0	0	0	4.569012066072285	
i 1	373.25108163265304	2.2725	77	701	4	24	7	16	0	2	16	0	0	3.0	
i 1	373.25757142857145	0.2525	68	1087	2	20	10	1	0	-1	1	0	0	0.5690120660722853	
i 1	373.48810204081633	0.2525	75	701	4	4	3	2	0	-2	2	0	0	3.0190967826718174	
i 1	373.49819727891156	0.2525	68	203	4	20	8	1	0	0	1	0	0	0.5690120660722853	
i 1	373.49819727891156	0.2525	71	1087	2	20	10	1	0	0	1	0	0	0.5690120660722853	
i 1	373.50108163265304	0.2525	68	701	1	24	3	0	0	0	0	0	0	4.569012066072285	
i 1	373.50612925170066	0.2525	68	203	4	20	7	1	0	0	1	0	0	0.5690120660722853	
i 1	373.50973469387753	0.2525	72	701	3	4	6	2	0	-2	2	0	0	3.0190967826718174	
i 1	373.7388231292517	1.7675	74	701	4	24	11	17	0	1	17	0	0	3.0	
i 1	373.7417074829932	1.5150000000000001	68	1087	2	20	11	1	0	-1	1	0	0	0.5690120660722853	
i 1	373.7467551020408	0.7575000000000001	71	1087	2	20	12	0	0	-1	0	0	0	0.5690120660722853	
i 1	373.7532448979592	0.7575000000000001	72	701	5	3	11	2	0	-2	2	0	0	3.0190967826718174	
i 1	373.7554081632653	0.7575000000000001	75	701	3	3	6	2	0	-2	2	0	0	3.0190967826718174	
i 1	373.7554081632653	1.7675	68	1087	3	24	14	0	0	-1	0	0	0	4.569012066072285	
i 1	373.75612925170066	6.8175	61	203	6	17	10	6	0	1	6	0	0	3.030108362368967	
i 1	373.75757142857145	6.8175	61	701	5	12	15	6	0	1	6	0	0	0.9278044669337066	
i 1	373.76478231292515	0.7575000000000001	71	1087	3	20	15	1	0	0	1	0	0	0.5690120660722853	
i 1	374.48810204081633	1.01	72	1087	4	9	16	8	0	-2	8	0	0	2.0190967826718174	
i 1	374.49026530612247	0.7575000000000001	68	701	1	24	16	0	0	0	0	0	0	4.569012066072285	
i 1	374.49747619047616	0.7575000000000001	68	701	2	20	10	0	0	0	0	0	0	0.5690120660722853	
i 1	374.51045578231293	1.01	72	203	7	2	12	2	0	1	2	0	0	3.0190967826718174	
i 1	375.0054081632653	2.02	71	203	7	5	11	8	0	-1	8	0	0	2.0	
i 1	375.00685034013605	2.02	74	1087	5	5	2	2	0	-2	2	0	0	2.0	
i 1	375.23954421768707	0.2525	71	701	4	24	2	0	0	-1	0	0	0	4.569012066072285	
i 1	375.26189795918367	0.2525	68	701	4	20	14	0	0	0	0	0	0	0.5690120660722853	
i 1	375.26622448979595	0.7575000000000001	71	701	1	20	16	0	0	-1	0	0	0	0.5690120660722853	
i 1	375.48738095238093	0.505	71	701	2	24	13	0	0	-1	0	0	0	4.569012066072285	
i 1	375.4917074829932	0.7575000000000001	75	701	3	3	11	2	0	-2	2	0	0	3.0190967826718174	
i 1	375.4953129251701	0.505	74	1087	5	1	13	16	0	1	16	0	0	2.0	
i 1	375.5046870748299	0.505	74	203	7	1	14	16	0	2	16	0	0	2.0	
i 1	375.5169455782313	0.7575000000000001	72	701	5	3	15	2	0	-2	2	0	0	3.0190967826718174	
i 1	375.99242857142855	0.7575000000000001	74	701	4	24	1	17	0	1	17	0	0	3.0	
i 1	375.99891836734696	2.02	68	1087	3	24	7	0	0	-1	0	0	0	4.569012066072285	
i 1	376.0054081632653	0.2525	71	701	4	24	5	0	0	-1	0	0	0	4.569012066072285	
i 1	376.0054081632653	0.2525	71	1087	3	20	6	1	0	0	1	0	0	0.5690120660722853	
i 1	376.0090136054422	0.2525	71	203	4	20	16	0	0	-1	0	0	0	0.5690120660722853	
i 1	376.01550340136055	0.7575000000000001	77	701	4	24	8	16	0	2	16	0	0	3.0	
i 1	376.2388231292517	1.5150000000000001	68	701	1	24	12	0	0	0	0	0	0	4.569012066072285	
i 1	376.2503605442177	0.2525	72	1087	5	9	4	2	0	1	2	0	0	2.0190967826718174	
i 1	376.2503605442177	1.5150000000000001	68	701	2	20	2	0	0	0	0	0	0	0.5690120660722853	
i 1	376.25612925170066	1.5150000000000001	71	1087	2	20	5	0	0	0	0	0	0	0.5690120660722853	
i 1	376.2633401360544	0.2525	75	203	7	2	6	2	0	-2	2	0	0	3.0190967826718174	
i 1	376.4909863945578	0.2525	72	701	5	3	1	2	0	-2	2	0	0	3.0190967826718174	
i 1	376.4909863945578	0.2525	75	701	3	3	9	2	0	-2	2	0	0	3.0190967826718174	
i 1	376.7460340136054	1.01	72	203	7	2	5	2	0	1	2	0	0	3.0190967826718174	
i 1	376.74747619047616	2.7775	74	1087	5	1	12	16	0	1	16	0	0	2.0	
i 1	376.7532448979592	1.01	72	1087	4	9	13	8	0	-2	8	0	0	2.0190967826718174	
i 1	376.7669455782313	2.7775	74	203	7	1	8	16	0	2	16	0	0	2.0	
i 1	376.98954421768707	0.2525	71	203	7	5	6	8	0	-2	8	0	0	2.0	
i 1	377.00108163265304	0.2525	71	1087	5	5	6	8	0	-1	8	0	0	2.0	
i 1	377.2546870748299	1.5150000000000001	71	701	4	5	10	2	0	-1	2	0	0	2.0	
i 1	377.26045578231293	1.5150000000000001	74	701	6	5	14	2	0	-2	2	0	0	2.0	
i 1	377.7323333333333	0.2525	71	701	4	24	14	0	0	-1	0	0	0	4.569012066072285	
i 1	377.7460340136054	1.01	75	701	4	4	6	2	0	-2	2	0	0	3.0190967826718174	
i 1	377.75252380952384	1.01	72	701	3	4	5	2	0	-2	2	0	0	3.0190967826718174	
i 1	377.7590136054422	0.2525	68	701	4	20	9	0	0	0	0	0	0	0.5690120660722853	
i 1	377.76261904761907	0.7575000000000001	71	701	1	20	10	0	0	-1	0	0	0	0.5690120660722853	
i 1	377.99891836734696	0.2525	71	701	2	24	10	0	0	-1	0	0	0	4.569012066072285	
i 1	378.01045578231293	0.2525	68	701	1	24	13	0	0	0	0	0	0	4.569012066072285	
i 1	378.01261904761907	0.2525	68	701	2	20	9	0	0	0	0	0	0	0.5690120660722853	
i 1	378.50973469387753	0.2525	68	1087	2	20	14	1	0	-1	1	0	0	0.5690120660722853	
i 1	378.51045578231293	0.505	68	1087	3	24	8	0	0	-1	0	0	0	4.569012066072285	
i 1	378.7359387755102	0.7575000000000001	72	701	5	3	10	2	0	-2	2	0	0	3.0190967826718174	
i 1	378.7388231292517	0.7575000000000001	75	701	3	3	3	2	0	-2	2	0	0	3.0190967826718174	
i 1	378.73954421768707	0.7575000000000001	71	1087	5	5	14	8	0	-1	8	0	0	2.0	
i 1	378.7503605442177	1.5150000000000001	71	203	7	5	5	8	0	-2	8	0	0	2.0	
i 1	378.7640612244898	1.7675	71	701	1	20	5	0	0	-1	0	0	0	0.5690120660722853	
i 1	378.76478231292515	0.2525	68	701	4	20	10	0	0	0	0	0	0	0.5690120660722853	
i 1	378.76622448979595	0.2525	71	701	4	24	2	0	0	-1	0	0	0	4.569012066072285	
i 1	378.9953129251701	0.505	68	701	1	24	2	0	0	0	0	0	0	4.569012066072285	
i 1	379.0082925170068	1.5150000000000001	68	1087	1	24	9	0	0	252	0	307	0	4.569012066072285	
i 1	379.01189795918367	1.5150000000000001	71	701	2	24	9	0	0	-1	0	0	0	4.569012066072285	
i 1	379.01550340136055	0.505	68	701	2	20	4	0	0	0	0	0	0	0.5690120660722853	
i 1	379.4823333333333	1.01	68	701	2	24	3	0	0	0	0	0	0	4.569012066072285	
i 1	379.48521768707485	1.01	68	701	1	20	11	0	0	0	0	0	0	0.5690120660722853	
i 1	379.4909863945578	1.01	77	701	6	1	16	17	0	2	17	0	0	2.0	
i 1	379.49314965986395	1.01	66	701	5	15	3	6	0	2	6	0	0	0.4639022334668533	
i 1	379.49819727891156	0.2525	72	203	7	2	4	2	0	1	2	0	0	3.0190967826718174	
i 1	379.49819727891156	0.7575000000000001	71	1087	6	5	5	8	0	-1	8	0	0	2.0	
i 1	379.50612925170066	0.2525	72	1087	5	9	15	8	0	-2	8	0	0	2.0190967826718174	
i 1	379.5140612244898	1.01	74	701	4	1	10	17	0	1	17	0	0	2.0	
i 1	379.51478231292515	1.01	61	203	6	14	9	9	0	2	9	0	0	1.3917067004005599	
i 1	379.5176666666667	1.01	66	203	6	17	1	9	0	2	9	0	0	3.030108362368967	
i 1	379.7359387755102	0.2525	72	701	5	3	1	2	0	-2	2	0	0	3.0190967826718174	
i 1	379.74891836734696	0.2525	75	701	3	3	13	2	0	-2	2	0	0	3.0190967826718174	
i 1	379.99747619047616	0.2525	75	203	7	2	5	2	0	-2	2	0	0	3.0190967826718174	
i 1	380.2388231292517	0.2525	71	203	7	5	11	8	0	-1	8	0	0	2.0	
i 1	380.24819727891156	0.2525	72	701	5	3	3	2	0	-2	2	0	0	3.0190967826718174	
i 1	380.2532448979592	0.2525	75	701	3	3	5	2	0	-2	2	0	0	3.0190967826718174	
i 1	380.26478231292515	0.2525	74	1087	5	5	3	2	0	-2	2	0	0	2.0	
i 1	380.4830544217687	0.7575000000000001	71	884	1	20	5	1	0	-1	1	0	0	0.5690120660722853	
i 1	380.4859387755102	1.2625	66	702	5	15	11	6	0	1	6	0	0	0.4639022334668533	
i 1	380.4888231292517	4.7975	66	0	6	14	15	6	0	2	6	0	0	1.3917067004005599	
i 1	380.49026530612247	22.22	61	884	5	12	15	9	0	2	9	0	0	0.9278044669337066	
i 1	380.4917074829932	2.02	71	0	6	5	2	8	0	-1	8	0	0	2.0	
i 1	380.4945918367347	16.4125	66	0	5	16	8	9	0	2	9	0	0	0.9278044669337066	
i 1	380.49891836734696	1.2625	71	0	7	5	6	2	0	-1	2	0	0	2.0	
i 1	380.50252380952384	1.2625	61	702	5	15	5	9	0	1	9	0	0	0.4639022334668533	
i 1	380.50612925170066	1.01	72	884	3	3	12	2	0	-2	2	0	0	3.0190967826718174	
i 1	380.50612925170066	22.22	66	0	6	17	13	6	0	1	6	0	0	3.030108362368967	
i 1	380.50757142857145	0.7575000000000001	68	884	1	20	15	0	0	-1	0	0	0	0.5690120660722853	
i 1	380.5090136054422	28.0275	66	0	6	17	9	6	0	1	6	0	0	3.030108362368967	
i 1	380.51045578231293	0.7575000000000001	68	884	2	24	6	0	0	-1	0	0	0	4.569012066072285	
i 1	380.51261904761907	0.505	77	0	5	1	13	17	0	2	17	0	0	2.0	
i 1	380.51478231292515	0.7575000000000001	71	0	4	24	15	1	0	0	1	0	0	4.569012066072285	
i 1	380.51622448979595	0.505	77	702	4	24	6	16	0	1	16	0	0	3.0	
i 1	380.5176666666667	10.605	61	0	5	16	3	9	0	2	9	0	0	0.9278044669337066	
i 1	380.5176666666667	28.0275	61	884	5	12	10	6	0	1	6	0	0	0.9278044669337066	
i 1	380.5176666666667	1.01	72	0	7	2	14	2	0	-2	2	0	0	3.0190967826718174	
i 1	380.9823333333333	0.7575000000000001	77	884	4	1	10	16	0	1	16	0	0	2.0	
i 1	380.98377551020405	3.535	74	0	7	1	1	16	0	1	16	0	0	2.0	
i 1	381.23377551020405	0.7575000000000001	68	0	3	20	10	0	0	-1	0	0	0	0.5690120660722853	
i 1	381.25757142857145	0.7575000000000001	71	884	2	24	3	1	0	-1	1	0	0	4.569012066072285	
i 1	381.51261904761907	0.505	75	0	6	9	11	2	0	1	2	0	0	2.0190967826718174	
i 1	381.5176666666667	0.2525	75	702	4	4	5	2	0	-2	2	0	0	3.0190967826718174	
i 1	381.7323333333333	0.7575000000000001	74	0	7	5	5	2	0	-2	2	0	0	2.0	
i 1	381.73377551020405	9.3425	61	618	5	15	10	9	0	1	9	0	0	0.4639022334668533	
i 1	381.73954421768707	0.2525	72	0	7	2	11	2	0	-2	2	0	0	3.0190967826718174	
i 1	381.7467551020408	3.535	66	618	5	15	1	9	0	2	9	0	0	0.4639022334668533	
i 1	381.7554081632653	2.7775	77	0	6	1	3	16	0	1	16	0	0	2.0	
i 1	381.98377551020405	0.2525	75	618	5	3	7	2	0	-2	2	0	0	3.0190967826718174	
i 1	381.9960340136054	0.2525	68	0	4	20	10	1	0	-1	1	0	0	0.5690120660722853	
i 1	382.0039659863946	0.2525	71	0	4	24	6	1	0	0	1	0	0	4.569012066072285	
i 1	382.01261904761907	0.7575000000000001	68	0	4	20	2	0	0	-1	0	0	0	0.5690120660722853	
i 1	382.01622448979595	0.2525	68	0	4	20	5	0	0	-1	0	0	0	0.5690120660722853	
i 1	382.23377551020405	0.2525	68	0	3	20	6	1	0	-1	1	0	0	0.5690120660722853	
i 1	382.2496394557823	0.2525	72	0	7	2	11	2	0	-2	2	0	0	3.0190967826718174	
i 1	382.25757142857145	0.2525	75	0	6	9	7	2	0	1	2	0	0	2.0190967826718174	
i 1	382.4866598639456	0.2525	71	0	7	5	2	8	0	-2	8	0	0	2.0	
i 1	382.4945918367347	0.2525	71	0	7	5	13	2	0	-1	2	0	0	2.0	
i 1	382.51045578231293	0.7575000000000001	75	618	5	3	5	2	0	-2	2	0	0	3.0190967826718174	
i 1	382.5176666666667	0.7575000000000001	72	884	3	3	10	2	0	-2	2	0	0	3.0190967826718174	
i 1	382.7359387755102	0.2525	68	0	3	20	14	0	0	-1	0	0	0	0.5690120660722853	
i 1	382.7467551020408	1.5150000000000001	74	884	4	5	14	8	0	-2	8	0	0	2.0	
i 1	382.75108163265304	0.2525	71	884	2	24	15	1	0	-1	1	0	0	4.569012066072285	
i 1	382.75973469387753	1.5150000000000001	71	618	6	5	2	2	0	-2	2	0	0	2.0	
i 1	382.98377551020405	1.7675	71	884	1	24	2	1	0	252	1	307	0	4.569012066072285	
i 1	382.98449659863945	0.505	71	0	4	24	1	1	0	0	1	0	0	4.569012066072285	
i 1	382.9909863945578	1.7675	68	0	4	20	1	0	0	-1	0	0	0	0.5690120660722853	
i 1	382.99747619047616	0.505	68	0	4	20	7	0	0	-1	0	0	0	0.5690120660722853	
i 1	383.0133401360544	0.505	68	0	4	20	14	1	0	-1	1	0	0	0.5690120660722853	
i 1	383.2359387755102	1.7675	72	0	7	2	5	2	0	-2	2	0	0	3.0190967826718174	
i 1	383.2539659863946	1.7675	75	0	6	9	7	2	0	-2	2	0	0	2.0190967826718174	
i 1	383.49314965986395	1.01	68	0	3	20	8	1	0	-1	1	0	0	0.5690120660722853	
i 1	384.2467551020408	1.5150000000000001	71	0	7	5	2	8	0	-2	8	0	0	2.0	
i 1	384.2640612244898	1.01	71	0	7	5	13	2	0	-1	2	0	0	2.0	
i 1	384.4823333333333	0.2525	68	0	4	20	14	0	0	-1	0	0	0	0.5690120660722853	
i 1	384.50612925170066	0.2525	68	618	4	24	1	0	0	0	0	0	0	4.569012066072285	
i 1	384.5090136054422	1.5150000000000001	74	618	6	1	9	17	0	2	17	0	0	2.0	
i 1	384.5111768707483	1.5150000000000001	77	884	4	1	15	16	0	1	16	0	0	2.0	
i 1	384.51478231292515	0.2525	71	884	1	20	14	1	0	-1	1	0	0	0.5690120660722853	
i 1	384.74314965986395	0.505	68	0	3	20	13	0	0	-1	0	0	0	0.5690120660722853	
i 1	384.7590136054422	0.505	71	884	2	24	9	1	0	-1	1	0	0	4.569012066072285	
i 1	384.9917074829932	0.2525	75	884	3	4	6	2	0	-2	2	0	0	3.0190967826718174	
i 1	384.9953129251701	0.2525	75	618	4	4	3	2	0	1	2	0	0	3.0190967826718174	
i 1	385.2323333333333	0.2525	68	0	4	20	15	0	0	-1	0	0	0	0.5690120660722853	
i 1	385.2388231292517	0.2525	72	884	5	3	10	2	0	-2	2	0	0	3.0190967826718174	
i 1	385.2388231292517	0.505	71	0	5	5	15	2	0	-1	2	0	0	2.0	
i 1	385.24026530612247	0.2525	68	0	4	20	1	1	0	-1	1	0	0	0.5690120660722853	
i 1	385.24242857142855	1.5150000000000001	71	0	4	24	12	1	0	0	1	0	0	4.569012066072285	
i 1	385.24387074829934	11.615	66	618	5	15	12	9	0	2	9	0	0	0.4639022334668533	
i 1	385.24747619047616	26.765	61	618	5	17	5	9	0	2	9	0	0	3.030108362368967	
i 1	385.2532448979592	0.2525	75	618	5	3	3	2	0	-2	2	0	0	3.0190967826718174	
i 1	385.2539659863946	2.02	68	0	4	20	1	0	0	-1	0	0	0	0.5690120660722853	
i 1	385.25612925170066	17.4225	66	0	6	14	7	6	0	2	6	0	0	1.3917067004005599	
i 1	385.4909863945578	0.2525	75	0	6	9	2	2	0	1	2	0	0	2.0190967826718174	
i 1	385.4945918367347	0.2525	72	0	7	2	7	2	0	-2	2	0	0	3.0190967826718174	
i 1	385.50108163265304	1.2625	68	884	1	24	10	1	0	0	1	0	0	4.569012066072285	
i 1	385.5032448979592	1.2625	68	0	3	20	5	1	0	-1	1	0	0	0.5690120660722853	
i 1	385.7323333333333	0.7575000000000001	75	618	5	3	5	2	0	-2	2	0	0	3.0190967826718174	
i 1	385.73521768707485	0.7575000000000001	72	884	5	3	3	2	0	-2	2	0	0	3.0190967826718174	
i 1	385.7366598639456	1.2625	74	0	7	5	1	2	0	-2	2	0	0	2.0	
i 1	385.7388231292517	1.2625	71	0	7	5	16	8	0	-1	8	0	0	2.0	
i 1	385.99891836734696	1.2625	74	884	4	24	3	17	0	1	17	0	0	3.0	
i 1	386.01045578231293	1.2625	77	618	4	24	12	16	0	1	16	0	0	3.0	
i 1	386.48449659863945	1.01	75	0	6	9	9	2	0	1	2	0	0	2.0190967826718174	
i 1	386.4917074829932	1.01	72	0	7	2	5	2	0	-2	2	0	0	3.0190967826718174	
i 1	386.7453129251701	0.505	71	618	3	24	14	0	0	-1	0	0	0	4.569012066072285	
i 1	386.75252380952384	0.505	71	884	2	20	5	1	0	-1	1	0	0	0.5690120660722853	
i 1	386.75612925170066	0.505	68	0	4	20	6	0	0	-1	0	0	0	0.5690120660722853	
i 1	387.0046870748299	2.02	71	0	5	5	6	2	0	-1	2	0	0	2.0	
i 1	387.0140612244898	2.02	71	0	7	5	4	8	0	-2	8	0	0	2.0	
i 1	387.2467551020408	0.2525	71	884	2	24	6	1	0	-1	1	0	0	4.569012066072285	
i 1	387.25685034013605	0.505	74	0	7	1	1	16	0	1	16	0	0	2.0	
i 1	387.2640612244898	0.2525	68	0	3	20	5	0	0	-1	0	0	0	0.5690120660722853	
i 1	387.2669455782313	0.505	77	0	5	1	9	16	0	1	16	0	0	2.0	
i 1	387.4830544217687	0.2525	68	0	4	20	11	0	0	-1	0	0	0	0.5690120660722853	
i 1	387.48377551020405	0.7575000000000001	75	618	5	3	7	2	0	-2	2	0	0	3.0190967826718174	
i 1	387.50180272108844	2.2725	71	0	4	24	2	1	0	0	1	0	0	4.569012066072285	
i 1	387.50612925170066	0.7575000000000001	72	884	5	3	15	2	0	-2	2	0	0	3.0190967826718174	
i 1	387.5082925170068	0.2525	68	0	4	20	13	1	0	-1	1	0	0	0.5690120660722853	
i 1	387.51478231292515	0.7575000000000001	68	0	4	20	11	0	0	-1	0	0	0	0.5690120660722853	
i 1	387.73449659863945	1.5150000000000001	71	884	1	24	11	0	0	-1	0	0	0	4.569012066072285	
i 1	387.7417074829932	1.5150000000000001	74	884	4	24	12	17	0	1	17	0	0	3.0	
i 1	387.74819727891156	0.505	68	0	3	20	10	1	0	-1	1	0	0	0.5690120660722853	
i 1	387.7669455782313	1.5150000000000001	77	618	4	24	16	16	0	1	16	0	0	3.0	
i 1	388.2323333333333	0.505	72	0	7	2	2	2	0	-2	2	0	0	3.0190967826718174	
i 1	388.23377551020405	0.2525	68	884	1	20	14	1	0	0	1	0	0	0.5690120660722853	
i 1	388.23738095238093	0.2525	71	884	2	20	13	1	0	-1	1	0	0	0.5690120660722853	
i 1	388.24387074829934	0.505	75	0	6	9	8	2	0	-2	2	0	0	2.0190967826718174	
i 1	388.4830544217687	0.7575000000000001	68	0	3	20	2	1	0	-1	1	0	0	0.5690120660722853	
i 1	388.5133401360544	1.7675	68	0	4	20	7	0	0	-1	0	0	0	0.5690120660722853	
i 1	388.74819727891156	0.2525	75	618	4	4	3	2	0	1	2	0	0	3.0190967826718174	
i 1	388.74891836734696	0.2525	75	884	3	4	15	2	0	-2	2	0	0	3.0190967826718174	
i 1	388.98521768707485	0.7575000000000001	72	884	5	3	14	2	0	-2	2	0	0	3.0190967826718174	
i 1	388.9888231292517	1.7675	74	0	7	5	12	2	0	-2	2	0	0	2.0	
i 1	389.00252380952384	0.7575000000000001	75	618	5	3	7	2	0	-2	2	0	0	3.0190967826718174	
i 1	389.0054081632653	1.7675	71	0	7	5	12	8	0	-1	8	0	0	2.0	
i 1	389.2323333333333	0.505	68	0	4	20	16	0	0	-1	0	0	0	0.5690120660722853	
i 1	389.25757142857145	2.7775	74	0	7	1	6	16	0	1	16	0	0	2.0	
i 1	389.25757142857145	2.7775	77	0	5	1	10	16	0	1	16	0	0	2.0	
i 1	389.2676666666667	0.505	68	0	4	20	15	1	0	-1	1	0	0	0.5690120660722853	
i 1	389.7359387755102	1.01	75	0	6	9	14	2	0	1	2	0	0	2.0190967826718174	
i 1	389.7453129251701	0.505	68	0	3	20	5	0	0	-1	0	0	0	0.5690120660722853	
i 1	389.75757142857145	0.505	71	884	2	24	13	1	0	-1	1	0	0	4.569012066072285	
i 1	389.7582925170068	1.01	72	0	7	2	8	2	0	-2	2	0	0	3.0190967826718174	
i 1	389.7676666666667	0.505	68	0	3	20	12	1	0	-1	1	0	0	0.5690120660722853	
i 1	390.23738095238093	0.2525	71	884	2	20	11	1	0	-1	1	0	0	0.5690120660722853	
i 1	390.24819727891156	0.2525	68	0	4	20	9	1	0	-1	1	0	0	0.5690120660722853	
i 1	390.25180272108844	0.7575000000000001	71	0	4	24	12	1	0	0	1	0	0	4.569012066072285	
i 1	390.2633401360544	0.2525	71	618	3	24	1	0	0	0	0	0	0	4.569012066072285	
i 1	390.4917074829932	0.505	68	0	4	20	12	0	0	-1	0	0	0	0.5690120660722853	
i 1	390.50180272108844	0.7575000000000001	71	884	1	24	12	0	0	-1	0	0	0	4.569012066072285	
i 1	390.51478231292515	0.505	68	0	3	20	15	1	0	-1	1	0	0	0.5690120660722853	
i 1	390.7366598639456	0.7575000000000001	75	618	5	3	1	2	0	-2	2	0	0	3.0190967826718174	
i 1	390.74242857142855	0.7575000000000001	72	884	5	3	5	2	0	-2	2	0	0	3.0190967826718174	
i 1	390.74387074829934	1.5150000000000001	71	0	7	5	3	8	0	-2	8	0	0	2.0	
i 1	390.76261904761907	1.5150000000000001	71	0	5	5	6	2	0	-1	2	0	0	2.0	
i 1	390.98449659863945	5.8075	61	618	5	15	8	9	0	1	9	0	0	0.4639022334668533	
i 1	390.9866598639456	0.2525	71	0	3	24	12	1	0	0	1	0	0	4.569012066072285	
i 1	390.9953129251701	20.9575	61	618	5	17	13	9	0	1	9	0	0	3.030108362368967	
i 1	391.00757142857145	11.615	61	0	5	16	13	9	0	2	9	0	0	0.9278044669337066	
i 1	391.2453129251701	0.505	68	0	3	20	13	0	0	-1	0	0	0	0.5690120660722853	
i 1	391.24891836734696	0.505	71	884	2	24	14	1	0	-1	1	0	0	4.569012066072285	
i 1	391.2546870748299	1.01	68	0	4	20	16	0	0	-1	0	0	0	0.5690120660722853	
i 1	391.2669455782313	0.505	68	0	3	20	10	1	0	-1	1	0	0	0.5690120660722853	
i 1	391.50252380952384	0.2525	75	0	6	9	11	2	0	1	2	0	0	2.0190967826718174	
i 1	391.5054081632653	0.2525	72	0	5	2	4	2	0	-2	2	0	0	3.0190967826718174	
i 1	391.73521768707485	0.2525	75	618	5	3	4	2	0	-2	2	0	0	3.0190967826718174	
i 1	391.7366598639456	0.7575000000000001	71	884	2	20	5	1	0	-1	1	0	0	0.5690120660722853	
i 1	391.7496394557823	0.505	68	0	4	20	7	0	0	-1	0	0	0	0.5690120660722853	
i 1	391.75612925170066	0.2525	72	884	5	3	12	2	0	-2	2	0	0	3.0190967826718174	
i 1	391.7590136054422	0.7575000000000001	68	618	3	24	11	1	0	0	1	0	0	4.569012066072285	
i 1	391.9823333333333	1.01	72	0	7	2	8	2	0	-2	2	0	0	3.0190967826718174	
i 1	391.98738095238093	0.7575000000000001	74	618	6	1	2	17	0	2	17	0	0	2.0	
i 1	391.98954421768707	1.01	75	0	6	9	4	2	0	-2	2	0	0	2.0190967826718174	
i 1	392.0046870748299	0.7575000000000001	77	884	3	1	16	16	0	1	16	0	0	2.0	
i 1	392.23377551020405	1.2625	74	884	4	5	10	8	0	-2	8	0	0	2.0	
i 1	392.25108163265304	0.2525	71	618	3	20	3	0	0	-1	0	0	0	0.5690120660722853	
i 1	392.25252380952384	0.2525	71	884	2	24	14	1	0	-1	1	0	0	4.569012066072285	
i 1	392.2582925170068	1.2625	71	618	6	5	11	2	0	-2	2	0	0	2.0	
i 1	392.4953129251701	1.01	71	0	3	24	7	1	0	0	1	0	0	4.569012066072285	
i 1	392.50973469387753	0.7575000000000001	68	884	1	24	1	1	0	0	1	0	0	4.569012066072285	
i 1	392.73449659863945	2.02	74	884	4	24	10	17	0	1	17	0	0	3.0	
i 1	392.75108163265304	2.02	77	618	4	24	4	16	0	1	16	0	0	3.0	
i 1	392.99819727891156	1.01	75	884	4	4	3	2	0	-2	2	0	0	3.0190967826718174	
i 1	392.9996394557823	0.2525	68	0	3	20	15	1	0	-1	1	0	0	0.5690120660722853	
i 1	393.0039659863946	1.01	75	618	4	4	10	2	0	1	2	0	0	3.0190967826718174	
i 1	393.0054081632653	0.505	68	0	4	20	3	0	0	-1	0	0	0	0.5690120660722853	
i 1	393.2467551020408	0.2525	68	0	4	20	12	1	0	-1	1	0	0	0.5690120660722853	
i 1	393.26045578231293	0.2525	68	0	4	20	10	0	0	-1	0	0	0	0.5690120660722853	
i 1	393.4830544217687	1.01	68	0	3	20	13	0	0	-1	0	0	0	0.5690120660722853	
i 1	393.4830544217687	1.01	68	884	1	20	8	0	0	-1	0	0	0	0.5690120660722853	
i 1	393.48810204081633	1.2625	71	0	5	5	15	2	0	-1	2	0	0	2.0	
i 1	393.4888231292517	1.2625	71	884	2	20	6	1	0	-1	1	0	0	0.5690120660722853	
i 1	393.5003605442177	1.2625	71	0	7	5	16	8	0	-2	8	0	0	2.0	
i 1	393.51261904761907	1.2625	71	884	2	24	16	1	0	-1	1	0	0	4.569012066072285	
i 1	393.9830544217687	0.7575000000000001	72	884	5	3	10	2	0	-2	2	0	0	3.0190967826718174	
i 1	393.9967551020408	0.7575000000000001	75	618	5	3	10	2	0	-2	2	0	0	3.0190967826718174	
i 1	394.5003605442177	0.2525	71	618	3	20	1	0	0	0	0	0	0	0.5690120660722853	
i 1	394.51550340136055	0.2525	68	618	3	24	16	0	0	0	0	0	0	4.569012066072285	
i 1	394.7323333333333	0.7575000000000001	77	0	5	1	13	16	0	1	16	0	0	2.0	
i 1	394.73449659863945	0.7575000000000001	74	0	5	5	13	2	0	-2	2	0	0	2.0	
i 1	394.7359387755102	0.7575000000000001	71	0	7	5	13	8	0	-1	8	0	0	2.0	
i 1	394.73738095238093	0.7575000000000001	71	0	3	24	14	1	0	0	1	0	0	4.569012066072285	
i 1	394.7388231292517	0.7575000000000001	68	0	4	20	7	0	0	-1	0	0	0	0.5690120660722853	
i 1	394.7409863945578	0.7575000000000001	74	0	7	1	8	16	0	1	16	0	0	2.0	
i 1	394.74242857142855	0.505	71	884	1	24	13	1	0	-1	1	0	0	4.569012066072285	
i 1	394.75108163265304	0.2525	72	0	5	2	16	2	0	-2	2	0	0	3.0190967826718174	
i 1	394.7590136054422	0.505	68	0	3	20	11	1	0	-1	1	0	0	0.5690120660722853	
i 1	394.7640612244898	0.2525	75	0	6	9	12	2	0	1	2	0	0	2.0190967826718174	
i 1	394.9967551020408	0.2525	75	618	5	3	3	2	0	-2	2	0	0	3.0190967826718174	
i 1	395.01550340136055	0.2525	72	884	5	3	9	2	0	-2	2	0	0	3.0190967826718174	
i 1	395.25612925170066	0.2525	72	0	5	2	4	2	0	-2	2	0	0	3.0190967826718174	
i 1	395.25685034013605	0.2525	68	0	4	20	8	1	0	-1	1	0	0	0.5690120660722853	
i 1	395.2582925170068	0.2525	68	0	4	20	16	0	0	-1	0	0	0	0.5690120660722853	
i 1	395.2676666666667	0.2525	75	0	6	9	8	2	0	1	2	0	0	2.0190967826718174	
i 1	395.4823333333333	1.01	71	884	2	20	14	1	0	-1	1	0	0	0.5690120660722853	
i 1	395.48449659863945	1.2625	71	0	5	5	14	2	0	-1	2	0	0	2.0	
i 1	395.4859387755102	1.2625	74	884	4	24	6	17	0	1	17	0	0	3.0	
i 1	395.4866598639456	0.7575000000000001	72	884	5	3	1	2	0	-2	2	0	0	3.0190967826718174	
i 1	395.5003605442177	1.7675	71	0	7	5	2	8	0	-2	8	0	0	2.0	
i 1	395.50252380952384	0.7575000000000001	71	884	1	20	16	0	0	-1	0	0	0	0.5690120660722853	
i 1	395.50252380952384	0.2525	71	884	2	24	16	1	0	-1	1	0	0	4.569012066072285	
i 1	395.51045578231293	1.5150000000000001	77	618	4	24	15	16	0	1	16	0	0	3.0	
i 1	395.5140612244898	0.2525	68	0	3	20	13	0	0	-1	0	0	0	0.5690120660722853	
i 1	395.5169455782313	0.7575000000000001	75	618	5	3	12	2	0	-2	2	0	0	3.0190967826718174	
i 1	395.73449659863945	1.01	71	0	3	24	1	1	0	0	1	0	0	4.569012066072285	
i 1	395.73521768707485	0.505	71	884	1	24	4	0	0	-1	0	0	0	4.569012066072285	
i 1	396.2546870748299	1.7675	75	0	6	9	5	2	0	-2	2	0	0	2.0190967826718174	
i 1	396.2546870748299	0.2525	68	0	4	20	9	1	0	-1	1	0	0	0.5690120660722853	
i 1	396.25757142857145	0.505	72	0	7	2	4	2	0	-2	2	0	0	3.0190967826718174	
i 1	396.2676666666667	0.2525	68	618	3	24	15	1	0	0	1	0	0	4.569012066072285	
i 1	396.49819727891156	0.2525	68	884	1	24	6	1	0	0	1	0	0	4.569012066072285	
i 1	396.5140612244898	0.505	71	884	2	24	10	1	0	-1	1	0	0	4.569012066072285	
i 1	396.5176666666667	0.2525	68	0	3	20	8	0	0	-1	0	0	0	0.5690120660722853	
i 1	396.7445918367347	5.8075	66	618	5	15	12	9	0	2	9	0	0	0.4639022334668533	
i 1	396.74819727891156	11.615	66	0	5	16	10	9	0	2	9	0	0	0.9278044669337066	
i 1	396.75108163265304	15.15	66	0	5	18	9	9	0	2	9	0	0	3.030108362368967	
i 1	396.76189795918367	0.2525	68	0	3	20	13	0	0	-1	0	0	0	0.5690120660722853	
i 1	396.76261904761907	15.15	61	618	5	15	12	9	0	1	9	0	0	0.4639022334668533	
i 1	396.7633401360544	0.505	71	0	7	5	1	2	0	-1	2	0	0	2.0	
i 1	396.7640612244898	0.2525	74	884	3	24	7	17	0	1	17	0	0	3.0	
i 1	396.76550340136055	1.2625	72	0	5	2	2	2	0	-2	2	0	0	3.0190967826718174	
i 1	396.9866598639456	1.7675	74	0	7	1	6	16	0	1	16	0	0	2.0	
i 1	396.9909863945578	1.7675	77	0	6	1	5	16	0	1	16	0	0	2.0	
i 1	397.00252380952384	0.505	71	884	2	20	2	1	0	-1	1	0	0	0.5690120660722853	
i 1	397.26189795918367	0.2525	71	618	3	24	14	0	0	0	0	0	0	4.569012066072285	
i 1	397.26550340136055	2.7775	74	0	5	5	2	2	0	-2	2	0	0	2.0	
i 1	397.2669455782313	2.7775	71	0	7	5	15	8	0	-1	8	0	0	2.0	
i 1	397.48449659863945	1.01	71	884	2	24	9	1	0	-1	1	0	0	4.569012066072285	
i 1	397.49242857142855	1.01	71	0	3	24	14	1	0	0	1	0	0	4.569012066072285	
i 1	397.50252380952384	1.01	71	884	1	24	6	1	0	0	1	0	0	4.569012066072285	
i 1	397.50973469387753	1.01	68	0	3	20	10	0	0	-1	0	0	0	0.5690120660722853	
i 1	397.98954421768707	0.2525	75	884	4	4	14	2	0	-2	2	0	0	3.0190967826718174	
i 1	398.0046870748299	0.2525	75	618	4	4	16	2	0	1	2	0	0	3.0190967826718174	
i 1	398.26189795918367	0.2525	75	618	5	3	1	2	0	-2	2	0	0	3.0190967826718174	
i 1	398.26550340136055	0.2525	72	884	5	3	14	2	0	-2	2	0	0	3.0190967826718174	
i 1	398.48521768707485	0.2525	72	0	5	2	6	2	0	-2	2	0	0	3.0190967826718174	
i 1	398.4859387755102	0.505	68	884	1	20	1	1	0	0	1	0	0	0.5690120660722853	
i 1	398.4859387755102	0.7575000000000001	71	884	2	20	3	1	0	-1	1	0	0	0.5690120660722853	
i 1	398.4888231292517	0.505	68	0	3	20	12	0	0	-1	0	0	0	0.5690120660722853	
i 1	398.4953129251701	0.2525	75	0	6	9	15	2	0	1	2	0	0	2.0190967826718174	
i 1	398.4953129251701	0.505	68	0	3	20	13	1	0	-1	1	0	0	0.5690120660722853	
i 1	398.73810204081633	0.7575000000000001	72	884	5	3	13	2	0	-2	2	0	0	3.0190967826718174	
i 1	398.7409863945578	1.5150000000000001	74	618	6	1	6	17	0	2	17	0	0	2.0	
i 1	398.74242857142855	0.7575000000000001	75	618	5	3	7	2	0	-2	2	0	0	3.0190967826718174	
i 1	398.75757142857145	1.5150000000000001	77	884	3	1	12	16	0	1	16	0	0	2.0	
i 1	398.99747619047616	0.2525	71	884	2	24	13	1	0	-1	1	0	0	4.569012066072285	
i 1	399.0039659863946	0.2525	68	618	3	24	13	0	0	-1	0	0	0	4.569012066072285	
i 1	399.01261904761907	0.2525	71	618	3	20	6	1	0	0	1	0	0	0.5690120660722853	
i 1	399.2417074829932	0.505	68	884	1	24	5	1	0	0	1	0	0	4.569012066072285	
i 1	399.25108163265304	0.7575000000000001	71	0	3	24	2	1	0	0	1	0	0	4.569012066072285	
i 1	399.49314965986395	1.01	72	0	5	2	3	2	0	-2	2	0	0	3.0190967826718174	
i 1	399.49819727891156	1.01	75	0	6	9	11	2	0	1	2	0	0	2.0190967826718174	
i 1	399.7503605442177	0.2525	68	618	3	24	1	0	0	0	0	0	0	4.569012066072285	
i 1	399.75685034013605	0.2525	68	0	4	20	5	1	0	-1	1	0	0	0.5690120660722853	
i 1	399.7611768707483	0.505	71	884	2	20	9	1	0	-1	1	0	0	0.5690120660722853	
i 1	399.9830544217687	0.2525	68	0	3	20	3	1	0	-1	1	0	0	0.5690120660722853	
i 1	399.98377551020405	0.2525	71	884	1	20	6	0	0	0	0	0	0	0.5690120660722853	
i 1	399.99242857142855	1.2625	71	0	7	5	16	2	0	-1	2	0	0	2.0	
i 1	400.00180272108844	1.2625	71	0	7	5	11	8	0	-2	8	0	0	2.0	
i 1	400.01622448979595	0.2525	68	0	3	20	13	0	0	-1	0	0	0	0.5690120660722853	
i 1	400.2330544217687	1.01	68	0	3	20	2	0	0	-1	0	0	0	0.5690120660722853	
i 1	400.24314965986395	1.01	71	884	2	24	14	1	0	-1	1	0	0	4.569012066072285	
i 1	400.24747619047616	2.2725	77	618	4	24	8	16	0	1	16	0	0	3.0	
i 1	400.25108163265304	1.01	68	884	1	24	13	1	0	0	1	0	0	4.569012066072285	
i 1	400.2546870748299	1.01	71	0	3	24	13	1	0	0	1	0	0	4.569012066072285	
i 1	400.25973469387753	2.2725	74	884	3	24	14	17	0	1	17	0	0	3.0	
i 1	400.48738095238093	0.7575000000000001	72	884	5	3	11	2	0	-2	2	0	0	3.0190967826718174	
i 1	400.50685034013605	0.7575000000000001	75	618	5	3	7	2	0	-2	2	0	0	3.0190967826718174	
i 1	401.23377551020405	0.505	72	0	5	2	5	2	0	-2	2	0	0	3.0190967826718174	
i 1	401.23449659863945	1.2625	71	884	2	20	2	1	0	-1	1	0	0	0.5690120660722853	
i 1	401.24819727891156	0.505	75	0	6	9	12	2	0	-2	2	0	0	2.0190967826718174	
i 1	401.25757142857145	0.7575000000000001	74	884	5	5	8	8	0	-2	8	0	0	2.0	
i 1	401.2582925170068	0.7575000000000001	71	618	6	5	12	2	0	-2	2	0	0	2.0	
i 1	401.2640612244898	0.2525	71	618	3	24	6	1	0	0	1	0	0	4.569012066072285	
i 1	401.49026530612247	1.01	68	884	1	20	8	1	0	-1	1	0	0	0.5690120660722853	
i 1	401.5003605442177	1.01	68	0	3	20	9	1	0	-1	1	0	0	0.5690120660722853	
i 1	401.51261904761907	1.5150000000000001	68	0	3	20	2	0	0	-1	0	0	0	0.5690120660722853	
i 1	401.7417074829932	0.2525	75	884	4	4	13	2	0	-2	2	0	0	3.0190967826718174	
i 1	401.75973469387753	0.2525	75	618	4	4	7	2	0	1	2	0	0	3.0190967826718174	
i 1	401.98810204081633	0.505	75	618	5	3	1	2	0	-2	2	0	0	3.0190967826718174	
i 1	402.0003605442177	0.2525	71	0	7	5	10	8	0	-2	8	0	0	2.0	
i 1	402.00685034013605	0.7575000000000001	72	884	5	3	7	2	0	-2	2	0	0	3.0190967826718174	
i 1	402.01550340136055	0.2525	71	0	7	5	11	2	0	-1	2	0	0	2.0	
i 1	402.2388231292517	0.2525	74	0	5	5	7	2	0	-2	2	0	0	2.0	
i 1	402.2409863945578	1.5150000000000001	71	0	7	5	15	8	0	-1	8	0	0	2.0	
i 1	402.4830544217687	0.505	74	0	7	1	1	16	0	1	16	0	0	2.0	
i 1	402.4859387755102	9.3425	66	0	7	17	8	6	0	1	6	0	0	3.030108362368967	
i 1	402.49026530612247	9.3425	61	884	4	12	6	9	0	2	9	0	0	0.9278044669337066	
i 1	402.4917074829932	1.2625	74	0	7	5	6	2	0	-2	2	0	0	2.0	
i 1	402.49314965986395	0.505	71	884	1	24	11	1	0	-1	1	0	0	4.569012066072285	
i 1	402.4945918367347	0.505	77	0	6	1	15	16	0	1	16	0	0	2.0	
i 1	402.50252380952384	9.3425	66	618	5	15	3	9	0	2	9	0	0	0.4639022334668533	
i 1	402.50757142857145	5.8075	61	0	5	16	9	9	0	2	9	0	0	0.9278044669337066	
i 1	402.50757142857145	0.2525	68	0	4	20	8	0	0	-1	0	0	0	0.5690120660722853	
i 1	402.5082925170068	9.3425	61	0	5	18	15	9	0	1	9	0	0	3.030108362368967	
i 1	402.5082925170068	0.2525	71	618	3	20	2	0	0	-1	0	0	0	0.5690120660722853	
i 1	402.5111768707483	0.2525	75	618	4	3	5	2	0	-2	2	0	0	3.0190967826718174	
i 1	402.74387074829934	1.01	75	0	6	9	3	2	0	1	2	0	0	2.0190967826718174	
i 1	402.7445918367347	0.2525	68	0	3	20	15	1	0	-1	1	0	0	0.5690120660722853	
i 1	402.76261904761907	1.01	72	0	5	2	13	2	0	-2	2	0	0	3.0190967826718174	
i 1	402.76261904761907	0.2525	68	0	3	20	5	0	0	-1	0	0	0	0.5690120660722853	
i 1	402.98810204081633	0.7575000000000001	77	618	4	24	6	16	0	1	16	0	0	3.0	
i 1	403.0032448979592	0.7575000000000001	74	884	3	24	5	17	0	1	17	0	0	3.0	
i 1	403.2460340136054	0.2525	71	884	2	20	6	1	0	-1	1	0	0	0.5690120660722853	
i 1	403.2496394557823	0.2525	68	618	3	24	13	1	0	0	1	0	0	4.569012066072285	
i 1	403.4888231292517	0.505	68	884	1	24	11	1	0	-1	1	0	0	4.569012066072285	
i 1	403.4888231292517	1.5150000000000001	71	0	3	24	9	1	0	0	1	0	0	4.569012066072285	
i 1	403.49026530612247	0.505	68	0	3	20	16	1	0	-1	1	0	0	0.5690120660722853	
i 1	403.5140612244898	0.505	68	0	3	20	5	0	0	-1	0	0	0	0.5690120660722853	
i 1	403.73377551020405	0.7575000000000001	75	618	4	3	6	2	0	-2	2	0	0	3.0190967826718174	
i 1	403.74819727891156	2.7775	71	0	7	5	12	2	0	-1	2	0	0	2.0	
i 1	403.75108163265304	0.7575000000000001	72	884	5	3	10	2	0	-2	2	0	0	3.0190967826718174	
i 1	403.75757142857145	2.7775	77	0	6	1	9	16	0	1	16	0	0	2.0	
i 1	403.76478231292515	2.7775	74	0	7	1	6	16	0	1	16	0	0	2.0	
i 1	403.76478231292515	2.7775	71	0	7	5	6	8	0	-2	8	0	0	2.0	
i 1	403.98377551020405	0.505	71	618	3	20	13	1	0	-1	1	0	0	0.5690120660722853	
i 1	403.98954421768707	0.505	71	884	1	24	11	1	0	-1	1	0	0	4.569012066072285	
i 1	404.01045578231293	0.505	68	0	4	20	12	1	0	-1	1	0	0	0.5690120660722853	
i 1	404.48377551020405	0.505	68	884	1	24	15	0	0	-1	0	0	0	4.569012066072285	
i 1	404.5039659863946	0.2525	75	0	6	9	4	2	0	1	2	0	0	2.0190967826718174	
i 1	404.5046870748299	0.2525	72	0	5	2	9	2	0	-2	2	0	0	3.0190967826718174	
i 1	404.7445918367347	0.2525	75	618	4	3	1	2	0	-2	2	0	0	3.0190967826718174	
i 1	404.7633401360544	0.2525	72	884	5	3	12	2	0	-2	2	0	0	3.0190967826718174	
i 1	404.9823333333333	0.505	71	884	2	20	11	1	0	-1	1	0	0	0.5690120660722853	
i 1	405.0039659863946	1.01	75	0	6	9	12	2	0	-2	2	0	0	2.0190967826718174	
i 1	405.0133401360544	1.01	72	0	5	2	12	2	0	-2	2	0	0	3.0190967826718174	
i 1	405.01478231292515	0.505	71	618	3	24	4	1	0	0	1	0	0	4.569012066072285	
i 1	405.4967551020408	0.2525	68	0	3	20	12	1	0	-1	1	0	0	0.5690120660722853	
i 1	405.5090136054422	0.2525	68	884	1	24	16	0	0	0	0	0	0	4.569012066072285	
i 1	405.51622448979595	0.2525	71	0	3	24	10	1	0	0	1	0	0	4.569012066072285	
i 1	405.5169455782313	0.2525	68	0	3	20	8	0	0	-1	0	0	0	0.5690120660722853	
i 1	405.73521768707485	0.7575000000000001	71	884	2	20	6	1	0	-1	1	0	0	0.5690120660722853	
i 1	405.74387074829934	0.7575000000000001	68	0	3	20	14	0	0	-1	0	0	0	0.5690120660722853	
i 1	405.74891836734696	0.7575000000000001	68	884	1	20	3	1	0	-1	1	0	0	0.5690120660722853	
i 1	405.7582925170068	0.7575000000000001	71	0	1	24	13	1	0	252	1	307	0	4.569012066072285	
i 1	405.7582925170068	0.7575000000000001	71	884	1	24	5	1	0	-1	1	0	0	4.569012066072285	
i 1	405.99242857142855	1.01	75	884	4	4	12	2	0	-2	2	0	0	3.0190967826718174	
i 1	405.99747619047616	1.01	75	618	4	4	14	2	0	1	2	0	0	3.0190967826718174	
i 1	406.4830544217687	1.5150000000000001	77	884	4	1	9	16	0	1	16	0	0	2.0	
i 1	406.48377551020405	0.2525	68	0	3	20	9	1	0	-1	1	0	0	0.5690120660722853	
i 1	406.4945918367347	0.2525	68	884	1	24	6	0	0	0	0	0	0	4.569012066072285	
i 1	406.49747619047616	0.2525	71	0	3	24	2	1	0	0	1	0	0	4.569012066072285	
i 1	406.50252380952384	1.5150000000000001	74	618	6	1	11	17	0	2	17	0	0	2.0	
i 1	406.5090136054422	2.02	71	0	7	5	6	8	0	-1	8	0	0	2.0	
i 1	406.5133401360544	2.02	74	0	7	5	2	2	0	-2	2	0	0	2.0	
i 1	406.5169455782313	0.2525	68	0	3	20	11	0	0	-1	0	0	0	0.5690120660722853	
i 1	406.7460340136054	0.2525	68	618	3	20	8	1	0	-1	1	0	0	0.5690120660722853	
i 1	406.7532448979592	0.2525	71	884	1	24	11	1	0	-1	1	0	0	4.569012066072285	
i 1	406.7539659863946	0.2525	71	618	3	24	9	1	0	-1	1	0	0	4.569012066072285	
i 1	406.7633401360544	0.2525	71	884	2	20	6	1	0	-1	1	0	0	0.5690120660722853	
i 1	406.98954421768707	0.7575000000000001	72	884	5	3	8	2	0	-2	2	0	0	3.0190967826718174	
i 1	407.0003605442177	0.7575000000000001	75	618	4	3	16	2	0	-2	2	0	0	3.0190967826718174	
i 1	407.01189795918367	0.505	71	0	3	24	3	1	0	0	1	0	0	4.569012066072285	
i 1	407.0176666666667	0.505	71	884	1	24	11	1	0	0	1	0	0	4.569012066072285	
i 1	407.4830544217687	0.7575000000000001	68	0	3	20	2	0	0	-1	0	0	0	0.5690120660722853	
i 1	407.4859387755102	0.505	68	884	1	20	9	0	0	0	0	0	0	0.5690120660722853	
i 1	407.49314965986395	0.505	71	884	2	20	1	1	0	-1	1	0	0	0.5690120660722853	
i 1	407.5111768707483	0.7575000000000001	68	0	3	20	5	1	0	-1	1	0	0	0.5690120660722853	
i 1	407.7417074829932	0.2525	72	0	5	2	2	2	0	-2	2	0	0	3.0190967826718174	
i 1	407.74242857142855	0.2525	75	0	6	9	1	2	0	1	2	0	0	2.0190967826718174	
i 1	407.9830544217687	0.2525	75	618	4	3	14	2	0	-2	2	0	0	3.0190967826718174	
i 1	407.9917074829932	0.2525	72	884	5	3	11	2	0	-2	2	0	0	3.0190967826718174	
i 1	407.99314965986395	0.2525	71	884	1	24	8	1	0	0	1	0	0	4.569012066072285	
i 1	408.0046870748299	0.2525	74	884	3	24	1	17	0	1	17	0	0	3.0	
i 1	408.0054081632653	0.2525	71	0	3	24	2	1	0	0	1	0	0	4.569012066072285	
i 1	408.0176666666667	1.2625	77	618	4	24	4	16	0	1	16	0	0	3.0	
i 1	408.2359387755102	3.535	66	0	5	16	12	9	0	2	9	0	0	0.9278044669337066	
i 1	408.23738095238093	1.01	74	884	4	24	3	17	0	1	17	0	0	3.0	
i 1	408.23810204081633	0.505	68	884	1	20	14	0	0	0	0	0	0	0.12101100041360136	
i 1	408.23810204081633	0.505	71	884	1	24	10	1	0	-1	1	0	0	4.121011000413601	
i 1	408.24026530612247	3.535	66	0	7	17	16	6	0	1	6	0	0	3.030108362368967	
i 1	408.2460340136054	3.535	61	884	4	12	14	6	0	1	6	0	0	0.9278044669337066	
i 1	408.24891836734696	3.535	61	0	5	16	2	9	0	2	9	0	0	0.9278044669337066	
i 1	408.25180272108844	0.2525	75	0	6	9	4	2	0	1	2	0	0	2.0190967826718174	
i 1	408.25757142857145	0.505	71	884	1	20	5	1	0	-1	1	0	0	0.12101100041360136	
i 1	408.26261904761907	3.535	66	884	3	19	15	9	0	1	9	0	0	3.030108362368967	
i 1	408.2633401360544	0.505	68	0	3	20	2	0	0	-1	0	0	0	0.12101100041360136	
i 1	408.2669455782313	0.2525	72	0	5	2	8	2	0	-2	2	0	0	3.0190967826718174	
i 1	408.2676666666667	0.505	71	884	1	24	9	1	0	252	1	307	0	4.121011000413601	
i 1	408.4996394557823	0.7575000000000001	75	618	4	3	10	2	0	-2	2	0	0	3.0190967826718174	
i 1	408.5003605442177	0.2525	71	0	7	5	3	2	0	-1	2	0	0	2.0	
i 1	408.50612925170066	0.7575000000000001	72	884	5	3	6	2	0	-2	2	0	0	3.0190967826718174	
i 1	408.50973469387753	0.2525	71	0	4	5	11	8	0	-2	8	0	0	2.0	
i 1	408.7330544217687	1.5150000000000001	71	618	4	5	5	2	0	-2	2	0	0	2.0	
i 1	408.74314965986395	1.5150000000000001	74	884	5	5	14	8	0	-2	8	0	0	2.0	
i 1	408.7554081632653	0.2525	71	0	3	24	11	1	0	0	1	0	0	4.121011000413601	
i 1	408.7554081632653	1.7675	68	0	3	20	13	0	0	-1	0	0	0	0.12101100041360136	
i 1	408.7590136054422	0.2525	68	0	4	20	13	0	0	-1	0	0	0	0.12101100041360136	
i 1	408.75973469387753	0.2525	68	0	4	20	12	1	0	-1	1	0	0	0.12101100041360136	
i 1	408.99747619047616	1.5150000000000001	68	0	3	20	10	1	0	-1	1	0	0	0.12101100041360136	
i 1	409.2445918367347	0.505	77	0	6	1	5	16	0	1	16	0	0	2.0	
i 1	409.2445918367347	1.7675	75	0	6	9	6	2	0	-2	2	0	0	2.0190967826718174	
i 1	409.25612925170066	0.505	74	0	7	1	3	16	0	1	16	0	0	2.0	
i 1	409.2582925170068	1.7675	72	0	5	2	1	2	0	-2	2	0	0	3.0190967826718174	
i 1	409.74314965986395	1.5150000000000001	74	884	4	24	11	17	0	1	17	0	0	3.0	
i 1	409.7669455782313	1.5150000000000001	77	618	4	24	16	16	0	1	16	0	0	3.0	
i 1	410.23377551020405	1.5150000000000001	71	0	4	5	5	8	0	-2	8	0	0	2.0	
i 1	410.24026530612247	1.5150000000000001	71	0	7	5	9	2	0	-1	2	0	0	2.0	
i 1	410.4909863945578	0.505	71	0	3	24	3	1	0	0	1	0	0	4.121011000413601	
i 1	410.5082925170068	0.505	71	884	1	24	12	1	0	0	1	0	0	4.121011000413601	
i 1	410.9830544217687	0.505	71	884	1	20	9	0	0	-1	0	0	0	0.12101100041360136	
i 1	410.9866598639456	0.505	71	884	1	20	2	1	0	-1	1	0	0	0.12101100041360136	
i 1	410.9909863945578	0.7575000000000001	68	0	3	20	9	0	0	-1	0	0	0	0.12101100041360136	
i 1	410.99891836734696	0.505	71	884	1	24	14	1	0	252	1	307	0	4.121011000413601	
i 1	411.0054081632653	0.2525	75	884	4	4	12	2	0	-2	2	0	0	3.0190967826718174	
i 1	411.0054081632653	0.505	68	0	3	20	11	1	0	-1	1	0	0	0.12101100041360136	
i 1	411.01189795918367	0.2525	75	618	4	4	11	2	0	1	2	0	0	3.0190967826718174	
i 1	411.23954421768707	0.2525	75	618	4	3	14	2	0	-2	2	0	0	3.0190967826718174	
i 1	411.2409863945578	0.2525	72	884	5	3	7	2	0	-2	2	0	0	3.0190967826718174	
i 1	411.2417074829932	0.505	74	0	7	1	2	16	0	1	16	0	0	2.0	
i 1	411.25612925170066	0.505	77	0	6	1	10	16	0	1	16	0	0	2.0	
i 1	411.48810204081633	0.2525	72	0	5	2	2	2	0	-2	2	0	0	3.0190967826718174	
i 1	411.49747619047616	0.2525	71	884	1	24	1	1	0	-1	1	0	0	4.121011000413601	
i 1	411.5003605442177	0.2525	68	0	4	20	10	0	0	-1	0	0	0	0.12101100041360136	
i 1	411.50108163265304	0.2525	75	0	6	9	2	2	0	1	2	0	0	2.0190967826718174	
i 1	411.51550340136055	0.2525	68	618	3	20	1	0	0	0	0	0	0	0.12101100041360136	
i 1	411.73377551020405	2.2725	66	1090	4	12	9	6	0	1	6	0	0	0.9278044669337066	
i 1	411.73521768707485	0.7575000000000001	72	1090	4	2	16	8	0	-2	8	0	0	3.0190967826718174	
i 1	411.73521768707485	14.645	66	1090	6	17	4	9	0	2	9	0	0	3.030108362368967	
i 1	411.7359387755102	0.505	68	1090	3	20	9	1	0	0	1	0	0	0.12101100041360136	
i 1	411.7388231292517	1.5150000000000001	74	1090	4	1	5	16	0	2	16	0	0	2.0	
i 1	411.7388231292517	8.08	61	1090	4	12	10	6	0	2	6	0	0	0.9278044669337066	
i 1	411.73954421768707	0.505	68	206	3	20	12	1	0	0	1	0	0	0.12101100041360136	
i 1	411.74026530612247	2.525	74	1090	6	5	10	8	0	-1	8	0	0	2.0	
i 1	411.7409863945578	13.13	61	1090	3	19	6	9	0	1	9	0	0	3.030108362368967	
i 1	411.74242857142855	13.8875	66	206	5	16	11	9	0	2	9	0	0	0.9278044669337066	
i 1	411.74242857142855	2.2725	71	206	7	5	12	2	0	-1	2	0	0	2.0	
i 1	411.7460340136054	2.2725	66	704	5	15	4	9	0	2	9	0	0	0.4639022334668533	
i 1	411.7467551020408	8.08	61	704	5	15	13	9	0	1	9	0	0	0.4639022334668533	
i 1	411.74819727891156	0.7575000000000001	72	206	6	9	1	2	0	-2	2	0	0	2.0190967826718174	
i 1	411.74819727891156	8.08	66	704	5	17	6	6	0	1	6	0	0	3.030108362368967	
i 1	411.74819727891156	0.505	68	1090	1	24	5	0	0	0	0	0	0	4.121011000413601	
i 1	411.75180272108844	14.645	66	1090	6	17	3	9	0	2	9	0	0	3.030108362368967	
i 1	411.7554081632653	1.5150000000000001	77	1090	6	1	11	17	0	1	17	0	0	2.0	
i 1	411.75612925170066	13.8875	61	206	5	18	13	6	0	1	6	0	0	3.030108362368967	
i 1	411.7590136054422	0.505	68	1090	3	20	7	1	0	-1	1	0	0	0.12101100041360136	
i 1	411.76189795918367	2.2725	66	704	5	17	6	6	0	1	6	0	0	3.030108362368967	
i 1	411.7633401360544	2.2725	61	206	5	16	7	6	0	2	6	0	0	0.9278044669337066	
i 1	411.76550340136055	19.695	66	206	5	18	6	9	0	1	9	0	0	3.030108362368967	
i 1	412.2467551020408	0.2525	71	206	3	20	14	1	0	-1	1	0	0	0.12101100041360136	
i 1	412.2496394557823	0.2525	71	206	3	24	6	1	0	0	1	0	0	4.121011000413601	
i 1	412.49891836734696	1.01	75	1090	4	4	1	2	0	1	2	0	0	3.0190967826718174	
i 1	412.50612925170066	1.5150000000000001	68	1090	1	24	5	0	0	-1	0	0	0	4.121011000413601	
i 1	412.5111768707483	1.5150000000000001	71	1090	1	20	5	0	0	0	0	0	0	0.12101100041360136	
i 1	412.5140612244898	1.01	75	704	4	3	11	8	0	1	8	0	0	3.0190967826718174	
i 1	413.2669455782313	1.2625	77	704	6	1	16	16	0	1	16	0	0	2.0	
i 1	413.2676666666667	1.2625	77	1090	4	24	1	17	0	1	17	0	0	3.0	
i 1	413.48738095238093	1.01	75	1090	5	3	14	2	0	-2	2	0	0	3.0190967826718174	
i 1	413.50757142857145	1.01	72	1090	4	2	1	2	0	1	2	0	0	3.0190967826718174	
i 1	413.9866598639456	2.02	68	206	3	20	8	1	0	0	1	0	0	0.12101100041360136	
i 1	413.99026530612247	5.8075	66	1090	5	12	9	6	0	1	6	0	0	0.9278044669337066	
i 1	413.9909863945578	0.2525	71	1090	3	20	3	0	0	0	0	0	0	0.12101100041360136	
i 1	413.99747619047616	0.2525	71	206	4	5	9	2	0	-1	2	0	0	2.0	
i 1	413.99819727891156	17.4225	66	704	6	17	10	6	0	1	6	0	0	3.030108362368967	
i 1	414.00612925170066	17.4225	61	206	5	16	2	6	0	2	6	0	0	0.9278044669337066	
i 1	414.0111768707483	0.2525	71	704	3	24	4	1	0	0	1	0	0	4.121011000413601	
i 1	414.01189795918367	0.7575000000000001	71	206	3	24	7	1	0	0	1	0	0	4.121011000413601	
i 1	414.0176666666667	10.8575	66	1090	3	19	6	6	0	2	6	0	0	3.030108362368967	
i 1	414.2330544217687	0.505	71	206	3	20	11	0	0	0	0	0	0	0.12101100041360136	
i 1	414.23521768707485	1.7675	71	206	3	20	4	1	0	-1	1	0	0	0.12101100041360136	
i 1	414.2539659863946	1.01	74	1090	5	5	3	8	0	-2	8	0	0	2.0	
i 1	414.25612925170066	1.01	74	1090	6	5	8	2	0	-2	2	0	0	2.0	
i 1	414.4830544217687	0.505	74	704	4	24	4	17	0	1	17	0	0	3.0	
i 1	414.50108163265304	0.2525	75	206	4	9	1	2	0	1	2	0	0	2.0190967826718174	
i 1	414.50252380952384	0.505	77	206	6	1	13	17	0	1	17	0	0	2.0	
i 1	414.5176666666667	0.2525	72	704	4	4	16	8	0	1	8	0	0	3.0190967826718174	
i 1	414.73521768707485	2.02	68	1090	1	24	16	1	0	-1	1	0	0	4.121011000413601	
i 1	414.73954421768707	0.2525	75	1090	4	4	8	2	0	1	2	0	0	3.0190967826718174	
i 1	414.7503605442177	0.2525	75	704	4	3	3	8	0	1	8	0	0	3.0190967826718174	
i 1	414.7611768707483	2.02	71	1090	1	20	1	0	0	0	0	0	0	0.12101100041360136	
i 1	414.98521768707485	1.5150000000000001	77	1090	6	1	13	17	0	1	17	0	0	2.0	
i 1	414.98521768707485	1.5150000000000001	74	1090	4	1	9	16	0	2	16	0	0	2.0	
i 1	414.99747619047616	0.7575000000000001	72	206	6	9	14	2	0	-2	2	0	0	2.0190967826718174	
i 1	415.01550340136055	0.7575000000000001	72	1090	4	2	6	8	0	-2	8	0	0	3.0190967826718174	
i 1	415.2611768707483	0.2525	74	704	6	5	5	8	0	-1	8	0	0	2.0	
i 1	415.2669455782313	0.2525	74	1090	5	5	6	2	0	-2	2	0	0	2.0	
i 1	415.51189795918367	1.5150000000000001	74	1090	6	5	3	8	0	-1	8	0	0	2.0	
i 1	415.51478231292515	1.5150000000000001	71	206	4	5	5	2	0	-1	2	0	0	2.0	
i 1	415.73449659863945	1.01	75	1090	4	4	6	2	0	1	2	0	0	3.0190967826718174	
i 1	415.7546870748299	1.01	75	704	4	3	15	8	0	1	8	0	0	3.0190967826718174	
i 1	415.9960340136054	0.2525	71	206	3	20	1	0	0	0	0	0	0	0.12101100041360136	
i 1	416.00973469387753	0.2525	71	206	3	24	8	1	0	0	1	0	0	4.121011000413601	
i 1	416.4917074829932	0.7575000000000001	74	704	4	24	8	17	0	1	17	0	0	3.0	
i 1	416.5111768707483	0.7575000000000001	77	206	6	1	13	17	0	1	17	0	0	2.0	
i 1	416.7539659863946	0.2525	68	1090	3	20	8	0	0	0	0	0	0	0.12101100041360136	
i 1	416.7539659863946	0.7575000000000001	71	206	3	24	10	1	0	0	1	0	0	4.121011000413601	
i 1	416.7554081632653	0.2525	68	206	3	20	16	1	0	0	1	0	0	0.12101100041360136	
i 1	416.76478231292515	0.7575000000000001	72	1090	4	2	2	8	0	-2	8	0	0	3.0190967826718174	
i 1	416.76478231292515	0.7575000000000001	72	206	6	9	5	2	0	-2	2	0	0	2.0190967826718174	
i 1	416.7676666666667	0.2525	71	704	3	24	16	0	0	-1	0	0	0	4.121011000413601	
i 1	416.98521768707485	1.5150000000000001	74	206	4	5	12	2	0	-2	2	0	0	2.0	
i 1	416.99026530612247	0.2525	71	206	3	20	14	0	0	-1	0	0	0	0.12101100041360136	
i 1	416.9953129251701	1.5150000000000001	71	704	6	5	16	2	0	-1	2	0	0	2.0	
i 1	417.23449659863945	2.7775	77	1090	6	1	7	17	0	1	17	0	0	2.0	
i 1	417.23521768707485	0.2525	68	704	3	24	12	0	0	0	0	0	0	4.121011000413601	
i 1	417.23521768707485	0.2525	68	206	3	20	5	1	0	0	1	0	0	0.12101100041360136	
i 1	417.24819727891156	0.2525	68	1090	3	20	16	0	0	0	0	0	0	0.12101100041360136	
i 1	417.25252380952384	2.7775	74	1090	4	1	9	16	0	2	16	0	0	2.0	
i 1	417.48738095238093	0.2525	75	1090	4	4	10	2	0	1	2	0	0	3.0190967826718174	
i 1	417.4909863945578	0.2525	75	704	4	3	6	8	0	1	8	0	0	3.0190967826718174	
i 1	417.49747619047616	1.01	71	1090	1	20	11	0	0	0	0	0	0	0.12101100041360136	
i 1	417.50685034013605	1.01	68	1090	1	24	3	1	0	-1	1	0	0	4.121011000413601	
i 1	417.76189795918367	0.505	72	1090	4	2	7	2	0	1	2	0	0	3.0190967826718174	
i 1	417.7676666666667	0.505	75	1090	5	3	2	2	0	-2	2	0	0	3.0190967826718174	
i 1	418.2467551020408	0.7575000000000001	72	704	4	4	9	8	0	1	8	0	0	3.0190967826718174	
i 1	418.2676666666667	0.7575000000000001	75	206	4	9	5	2	0	1	2	0	0	2.0190967826718174	
i 1	418.4830544217687	0.2525	71	1090	1	20	9	1	0	0	1	0	0	0.12101100041360136	
i 1	418.49314965986395	1.2625	74	1090	6	5	5	8	0	-1	8	0	0	2.0	
i 1	418.4953129251701	1.01	68	206	3	20	7	1	0	-1	1	0	0	0.12101100041360136	
i 1	418.50108163265304	1.2625	71	206	4	5	4	2	0	-1	2	0	0	2.0	
i 1	418.5090136054422	1.01	71	206	3	24	9	1	0	0	1	0	0	4.121011000413601	
i 1	418.51189795918367	0.2525	68	1090	1	24	6	0	0	0	0	0	0	4.121011000413601	
i 1	418.74819727891156	0.7575000000000001	68	1090	1	24	13	1	0	-1	1	0	0	4.121011000413601	
i 1	418.74891836734696	0.7575000000000001	71	1090	1	20	6	0	0	0	0	0	0	0.12101100041360136	
i 1	418.9859387755102	1.01	75	1090	4	4	9	2	0	1	2	0	0	3.0190967826718174	
i 1	419.00180272108844	1.01	75	704	4	3	14	8	0	1	8	0	0	3.0190967826718174	
i 1	419.48810204081633	0.2525	68	206	3	20	7	1	0	0	1	0	0	0.12101100041360136	
i 1	419.4967551020408	0.2525	70	1090	3	20	7	2	0	-2	2	0	0	0.12101100041360136	
i 1	419.73377551020405	1.2625	74	1090	6	5	8	2	0	-2	2	0	0	2.0	
i 1	419.73449659863945	11.615	66	704	6	17	7	6	0	1	6	0	0	3.030108362368967	
i 1	419.7366598639456	1.2625	74	1090	2	5	12	8	0	-2	8	0	0	2.0	
i 1	419.74891836734696	0.7575000000000001	71	1090	1	20	11	0	0	0	0	0	0	0.12101100041360136	
i 1	419.75252380952384	5.05	61	1090	5	12	1	6	0	2	6	0	0	0.9278044669337066	
i 1	419.75757142857145	0.7575000000000001	70	206	3	20	8	8	0	-1	8	0	0	0.12101100041360136	
i 1	419.7582925170068	0.7575000000000001	70	1090	1	24	8	2	0	-1	2	0	0	4.121011000413601	
i 1	419.76045578231293	1.5150000000000001	71	206	3	24	7	1	0	0	1	0	0	4.121011000413601	
i 1	419.7640612244898	5.05	66	1090	3	12	4	6	0	1	6	0	0	0.9278044669337066	
i 1	419.9960340136054	0.7575000000000001	72	1090	4	2	13	8	0	-2	8	0	0	3.0190967826718174	
i 1	419.99747619047616	2.02	77	1090	4	24	12	17	0	1	17	0	0	3.0	
i 1	420.0133401360544	2.02	77	704	6	1	11	16	0	1	16	0	0	2.0	
i 1	420.01478231292515	0.7575000000000001	72	206	4	9	11	2	0	-2	2	0	0	2.0190967826718174	
i 1	420.4859387755102	0.2525	73	704	3	24	11	2	0	-2	2	0	0	4.121011000413601	
i 1	420.7445918367347	0.505	70	206	3	20	10	2	0	-1	2	0	0	0.12101100041360136	
i 1	420.7467551020408	0.505	70	1090	1	24	16	8	0	-1	8	0	0	4.121011000413601	
i 1	420.75108163265304	0.2525	75	704	4	3	5	8	0	1	8	0	0	3.0190967826718174	
i 1	420.7532448979592	0.505	71	1090	1	20	13	0	0	0	0	0	0	0.12101100041360136	
i 1	420.7676666666667	0.2525	75	1090	4	4	8	2	0	1	2	0	0	3.0190967826718174	
i 1	420.9859387755102	1.5150000000000001	71	206	4	5	6	2	0	-1	2	0	0	2.0	
i 1	420.98954421768707	0.2525	72	206	4	9	14	2	0	-2	2	0	0	2.0190967826718174	
i 1	420.99026530612247	0.2525	72	1090	4	2	1	2	0	1	2	0	0	3.0190967826718174	
i 1	420.99747619047616	0.2525	72	1090	4	2	6	8	0	-2	8	0	0	3.0190967826718174	
i 1	421.00612925170066	1.5150000000000001	74	1090	5	5	1	8	0	-1	8	0	0	2.0	
i 1	421.2359387755102	0.2525	75	1090	4	4	3	2	0	1	2	0	0	3.0190967826718174	
i 1	421.23810204081633	0.2525	73	1090	3	20	8	8	0	-2	8	0	0	0.12101100041360136	
i 1	421.24242857142855	0.2525	75	704	4	3	6	8	0	1	8	0	0	3.0190967826718174	
i 1	421.26478231292515	0.2525	68	206	3	20	9	1	0	0	1	0	0	0.12101100041360136	
i 1	421.4888231292517	0.2525	70	206	3	20	14	8	0	-1	8	0	0	0.12101100041360136	
i 1	421.4909863945578	1.2625	71	1090	1	20	9	0	0	0	0	0	0	0.12101100041360136	
i 1	421.49387074829934	0.2525	73	1090	1	24	10	8	0	-2	8	0	0	4.121011000413601	
i 1	421.5082925170068	1.2625	71	206	3	24	3	1	0	0	1	0	0	4.121011000413601	
i 1	421.50973469387753	2.2725	72	1090	4	2	15	2	0	1	2	0	0	3.0190967826718174	
i 1	421.50973469387753	1.7675	75	1090	5	3	8	2	0	-2	2	0	0	3.0190967826718174	
i 1	421.73810204081633	0.2525	73	1090	3	20	1	2	0	-1	2	0	0	0.12101100041360136	
i 1	421.75757142857145	0.2525	72	206	4	9	12	2	0	-2	2	0	0	2.0190967826718174	
i 1	421.76550340136055	0.2525	73	704	3	24	1	2	0	-1	2	0	0	4.121011000413601	
i 1	421.98377551020405	2.02	74	1090	2	5	5	8	0	-2	8	0	0	2.0	
i 1	421.9866598639456	0.7575000000000001	70	1090	1	24	10	2	0	-2	2	0	0	4.121011000413601	
i 1	421.99819727891156	1.01	77	206	7	1	5	17	0	1	17	0	0	2.0	
i 1	422.0003605442177	2.02	74	1090	6	5	5	2	0	-2	2	0	0	2.0	
i 1	422.00685034013605	0.7575000000000001	73	206	3	20	10	8	0	-1	8	0	0	0.12101100041360136	
i 1	422.0169455782313	1.01	74	704	4	24	15	17	0	1	17	0	0	3.0	
i 1	422.2669455782313	0.2525	72	1090	4	2	3	8	0	-2	8	0	0	3.0190967826718174	
i 1	422.48954421768707	1.7675	74	1090	4	1	9	16	0	2	16	0	0	2.0	
i 1	422.4953129251701	0.2525	75	1090	4	4	11	2	0	1	2	0	0	3.0190967826718174	
i 1	422.51189795918367	1.7675	77	1090	6	1	16	17	0	1	17	0	0	2.0	
i 1	422.5133401360544	0.2525	74	206	7	5	4	2	0	-2	2	0	0	2.0	
i 1	422.7359387755102	0.505	68	206	3	20	12	1	0	0	1	0	0	0.12101100041360136	
i 1	422.74242857142855	0.2525	72	206	4	9	2	2	0	-2	2	0	0	2.0190967826718174	
i 1	422.7676666666667	0.2525	73	1090	3	20	2	2	0	-1	2	0	0	0.12101100041360136	
i 1	422.9823333333333	1.2625	71	206	3	24	14	1	0	0	1	0	0	4.121011000413601	
i 1	422.9967551020408	1.01	75	206	4	9	2	2	0	1	2	0	0	2.0190967826718174	
i 1	423.0090136054422	1.2625	73	206	3	20	12	2	0	-1	2	0	0	0.12101100041360136	
i 1	423.01261904761907	1.2625	71	1090	1	20	7	0	0	0	0	0	0	0.12101100041360136	
i 1	423.0140612244898	1.01	72	704	4	4	10	8	0	1	8	0	0	3.0190967826718174	
i 1	423.01478231292515	1.2625	73	1090	1	24	16	8	0	-1	8	0	0	4.121011000413601	
i 1	423.2330544217687	0.2525	77	1090	4	24	9	17	0	1	17	0	0	3.0	
i 1	423.49819727891156	0.2525	74	704	4	24	10	17	0	1	17	0	0	3.0	
i 1	423.5039659863946	1.2625	74	1090	5	5	8	2	0	-2	2	0	0	2.0	
i 1	423.50685034013605	1.7675	74	704	6	5	9	8	0	-1	8	0	0	2.0	
i 1	423.7503605442177	0.505	75	1090	4	4	10	2	0	1	2	0	0	3.0190967826718174	
i 1	423.9830544217687	0.2525	71	704	6	5	1	2	0	-1	2	0	0	2.0	
i 1	423.9859387755102	0.7575000000000001	68	1090	1	24	7	0	0	0	0	0	0	4.121011000413601	
i 1	423.99314965986395	1.01	75	704	4	3	5	8	0	1	8	0	0	3.0190967826718174	
i 1	424.00108163265304	1.5150000000000001	68	206	3	20	8	1	0	0	1	0	0	0.12101100041360136	
i 1	424.0032448979592	0.2525	70	206	3	20	14	8	0	-1	8	0	0	0.12101100041360136	
i 1	424.00612925170066	0.505	72	1090	4	2	15	8	0	-2	8	0	0	3.0190967826718174	
i 1	424.01189795918367	0.2525	73	1090	1	20	1	8	0	-1	8	0	0	0.12101100041360136	
i 1	424.01622448979595	0.2525	77	1090	4	24	9	17	0	1	17	0	0	3.0	
i 1	424.23810204081633	0.505	77	206	7	1	1	17	0	1	17	0	0	2.0	
i 1	424.23954421768707	0.505	74	704	4	24	16	17	0	1	17	0	0	3.0	
i 1	424.2467551020408	0.505	70	1090	3	20	12	2	0	-2	2	0	0	0.12101100041360136	
i 1	424.24819727891156	0.505	73	1090	3	20	6	2	0	-1	2	0	0	0.12101100041360136	
i 1	424.26045578231293	0.2525	74	1090	5	5	2	8	0	-1	8	0	0	2.0	
i 1	424.26550340136055	0.2525	72	206	4	9	10	2	0	-2	2	0	0	2.0190967826718174	
i 1	424.4859387755102	0.2525	75	1090	4	4	4	2	0	1	2	0	0	3.0190967826718174	
i 1	424.4953129251701	0.2525	74	1090	4	1	5	16	0	2	16	0	0	2.0	
i 1	424.49819727891156	1.01	77	1090	6	1	6	17	0	1	17	0	0	2.0	
i 1	424.5039659863946	0.2525	72	1090	4	2	6	2	0	1	2	0	0	3.0190967826718174	
i 1	424.7330544217687	0.7575000000000001	73	2	2	20	12	8	0	-2	8	0	0	0.12101100041360136	
i 1	424.73738095238093	0.2525	75	2	3	5	16	2	0	1	2	0	0	2.0	
i 1	424.73810204081633	1.5150000000000001	60	2	4	19	9	0	0	0	0	0	0	3.030108362368967	
i 1	424.7445918367347	0.2525	77	206	6	1	1	17	0	2	17	0	0	2.0	
i 1	424.7467551020408	1.5150000000000001	60	2	4	19	10	5	0	1	5	0	0	3.030108362368967	
i 1	424.74747619047616	1.5150000000000001	60	2	4	12	4	0	0	0	0	0	0	0.9278044669337066	
i 1	424.75108163265304	0.505	75	2	6	5	14	2	0	-2	2	0	0	2.0	
i 1	424.75180272108844	2.525	72	206	4	9	8	2	0	-2	2	0	0	2.0190967826718174	
i 1	424.75252380952384	1.01	72	1090	4	2	9	8	0	-2	8	0	0	3.0190967826718174	
i 1	424.7532448979592	1.5150000000000001	74	2	5	1	2	8	0	-1	8	0	0	2.0	
i 1	424.7546870748299	0.7575000000000001	60	2	6	12	7	0	0	0	0	0	0	0.9278044669337066	
i 1	424.76045578231293	1.01	73	206	3	20	11	2	0	-1	2	0	0	0.12101100041360136	
i 1	424.7633401360544	0.7575000000000001	73	2	2	24	7	2	0	-2	2	0	0	4.121011000413601	
i 1	424.98521768707485	1.2625	74	1090	5	5	12	8	0	-1	8	0	0	2.0	
i 1	425.00252380952384	0.2525	72	1090	4	2	8	2	0	1	2	0	0	3.0190967826718174	
i 1	425.0054081632653	0.505	71	206	4	5	15	2	0	-1	2	0	0	2.0	
i 1	425.24314965986395	3.2825	73	206	3	20	12	8	0	-2	8	0	0	0.12101100041360136	
i 1	425.2460340136054	2.2725	71	206	3	24	5	1	0	0	1	0	0	4.121011000413601	
i 1	425.2503605442177	1.2625	75	704	4	3	5	8	0	1	8	0	0	3.0190967826718174	
i 1	425.26261904761907	0.2525	71	2	5	24	7	2	0	-1	2	0	0	3.0	
i 1	425.4859387755102	0.7575000000000001	77	1090	6	1	4	17	0	1	17	0	0	2.0	
i 1	425.4960340136054	1.01	71	206	7	5	9	2	0	-1	2	0	0	2.0	
i 1	425.50108163265304	0.7575000000000001	71	2	5	4	14	8	0	-2	8	0	0	3.0190967826718174	
i 1	425.50180272108844	5.8075	61	206	5	18	16	6	0	1	6	0	0	3.030108362368967	
i 1	425.51189795918367	0.7575000000000001	60	2	4	12	5	0	0	0	0	0	0	0.9278044669337066	
i 1	425.73810204081633	0.2525	70	2	2	20	8	2	0	-1	2	0	0	0.12101100041360136	
i 1	425.7460340136054	0.2525	77	206	7	1	1	17	0	1	17	0	0	2.0	
i 1	425.9953129251701	1.7675	74	206	7	5	9	2	0	-2	2	0	0	2.0	
i 1	425.9953129251701	0.2525	73	2	2	24	12	2	0	-1	2	0	0	4.121011000413601	
i 1	426.0169455782313	0.2525	72	1090	4	2	5	2	0	1	2	0	0	3.0190967826718174	
i 1	426.0176666666667	2.7775	68	206	3	20	8	1	0	0	1	0	0	0.12101100041360136	
i 1	426.2330544217687	5.05	67	206	4	19	16	5	0	1	5	0	0	3.030108362368967	
i 1	426.23449659863945	0.2525	71	908	6	1	2	2	0	-1	2	0	0	2.0	
i 1	426.23449659863945	0.2525	71	206	5	4	8	2	0	-1	2	0	0	3.0190967826718174	
i 1	426.24242857142855	5.05	67	908	6	17	8	5	0	0	5	0	0	3.030108362368967	
i 1	426.24242857142855	1.2625	73	206	2	24	6	8	0	-1	8	0	0	4.121011000413601	
i 1	426.24387074829934	5.05	60	908	6	17	12	5	0	0	5	0	0	3.030108362368967	
i 1	426.2445918367347	5.05	67	206	4	12	9	5	0	1	5	0	0	0.9278044669337066	
i 1	426.2460340136054	5.05	60	206	4	12	14	0	0	1	0	0	0	0.9278044669337066	
i 1	426.2503605442177	1.01	71	206	5	1	9	2	0	-1	2	0	0	2.0	
i 1	426.25180272108844	1.01	71	908	4	2	12	2	0	-2	2	0	0	3.0190967826718174	
i 1	426.25252380952384	5.05	60	206	4	19	7	0	0	1	0	0	0	3.030108362368967	
i 1	426.2532448979592	1.2625	77	704	6	1	11	16	0	1	16	0	0	2.0	
i 1	426.2554081632653	3.535	70	206	1	24	1	2	0	248	2	308	0	4.121011000413601	
i 1	426.25757142857145	1.5150000000000001	72	908	5	5	8	2	0	1	2	0	0	2.0	
i 1	426.4960340136054	0.2525	71	206	3	3	14	8	0	-2	8	0	0	3.0190967826718174	
i 1	426.50252380952384	0.2525	71	704	6	5	15	2	0	-1	2	0	0	2.0	
i 1	426.5046870748299	0.2525	77	206	7	1	8	17	0	2	17	0	0	2.0	
i 1	426.73449659863945	3.2825	74	206	5	24	3	2	0	-2	2	0	0	3.0	
i 1	426.73954421768707	0.7575000000000001	71	206	5	4	10	2	0	-1	2	0	0	3.0190967826718174	
i 1	426.7503605442177	3.535	74	704	4	24	3	17	0	1	17	0	0	3.0	
i 1	426.7590136054422	0.2525	75	206	3	5	12	2	0	1	2	0	0	2.0	
i 1	426.76189795918367	0.7575000000000001	72	704	4	4	13	8	0	1	8	0	0	3.0190967826718174	
i 1	426.98738095238093	1.7675	75	704	4	3	12	8	0	1	8	0	0	3.0190967826718174	
i 1	426.9953129251701	1.5150000000000001	70	206	2	20	9	8	0	-2	8	0	0	0.12101100041360136	
i 1	427.00108163265304	0.2525	74	704	6	5	5	8	0	-1	8	0	0	2.0	
i 1	427.01261904761907	1.5150000000000001	70	206	2	20	14	8	0	-1	8	0	0	0.12101100041360136	
i 1	427.0176666666667	1.7675	71	206	3	3	16	8	0	-2	8	0	0	3.0190967826718174	
i 1	427.23449659863945	1.5150000000000001	75	908	5	5	8	2	0	1	2	0	0	2.0	
i 1	427.2467551020408	0.7575000000000001	75	206	4	9	15	2	0	1	2	0	0	2.0190967826718174	
i 1	427.24747619047616	0.7575000000000001	71	908	4	2	16	8	0	-1	8	0	0	3.0190967826718174	
i 1	427.2611768707483	1.7675	71	206	7	5	8	2	0	-1	2	0	0	2.0	
i 1	427.48810204081633	0.2525	71	206	5	1	12	2	0	-1	2	0	0	2.0	
i 1	427.7460340136054	0.2525	77	704	6	1	6	16	0	1	16	0	0	2.0	
i 1	427.75252380952384	0.2525	71	704	6	5	8	2	0	-1	2	0	0	2.0	
i 1	427.9888231292517	0.2525	72	704	4	4	3	8	0	1	8	0	0	3.0190967826718174	
i 1	427.9960340136054	3.2825	71	908	6	1	13	2	0	-1	2	0	0	2.0	
i 1	428.0003605442177	2.7775	74	206	7	5	4	2	0	-2	2	0	0	2.0	
i 1	428.01261904761907	1.5150000000000001	71	206	3	24	10	1	0	0	1	0	0	4.121011000413601	
i 1	428.01550340136055	0.505	73	206	2	24	6	8	0	-1	8	0	0	4.121011000413601	
i 1	428.2467551020408	1.5150000000000001	72	206	4	9	11	2	0	-2	2	0	0	2.0190967826718174	
i 1	428.24819727891156	2.2725	72	908	5	5	5	2	0	1	2	0	0	2.0	
i 1	428.25757142857145	1.5150000000000001	71	908	4	2	14	2	0	-2	2	0	0	3.0190967826718174	
i 1	428.2676666666667	1.01	77	206	7	1	3	17	0	2	17	0	0	2.0	
i 1	428.4866598639456	0.505	70	704	3	24	11	2	0	-2	2	0	0	4.121011000413601	
i 1	428.4909863945578	0.7575000000000001	70	908	3	20	8	8	0	-1	8	0	0	0.12101100041360136	
i 1	428.7640612244898	0.505	71	908	4	2	5	8	0	-1	8	0	0	3.0190967826718174	
i 1	428.99891836734696	1.01	68	206	3	20	13	1	0	0	1	0	0	0.12101100041360136	
i 1	428.9996394557823	0.505	75	206	3	5	2	2	0	1	2	0	0	2.0	
i 1	429.23810204081633	1.2625	71	206	3	3	11	8	0	-2	8	0	0	3.0190967826718174	
i 1	429.2388231292517	0.7575000000000001	70	206	3	20	16	2	0	-2	2	0	0	0.12101100041360136	
i 1	429.26045578231293	1.2625	75	704	4	3	2	8	0	1	8	0	0	3.0190967826718174	
i 1	429.50180272108844	0.505	73	206	2	20	4	2	0	-1	2	0	0	0.12101100041360136	
i 1	429.50685034013605	1.7675	77	206	7	1	9	17	0	2	17	0	0	2.0	
i 1	429.50973469387753	0.2525	71	206	7	5	10	2	0	-1	2	0	0	2.0	
i 1	429.50973469387753	0.7575000000000001	70	206	2	20	8	8	0	-1	8	0	0	0.12101100041360136	
i 1	429.7467551020408	1.01	71	206	3	24	6	1	0	0	1	0	0	4.121011000413601	
i 1	429.74891836734696	0.2525	75	206	3	5	5	2	0	1	2	0	0	2.0	
i 1	429.75252380952384	0.2525	71	206	5	4	4	2	0	-1	2	0	0	3.0190967826718174	
i 1	429.76550340136055	5.555	70	206	2	24	16	2	0	-1	2	0	0	4.121011000413601	
i 1	429.98449659863945	0.505	70	908	3	20	4	2	0	-2	2	0	0	0.12101100041360136	
i 1	429.9909863945578	1.2625	71	206	7	5	11	2	0	-1	2	0	0	2.0	
i 1	430.0003605442177	1.2625	75	908	5	5	10	2	0	1	2	0	0	2.0	
i 1	430.00973469387753	1.01	71	908	4	2	6	2	0	-2	2	0	0	3.0190967826718174	
i 1	430.01550340136055	1.01	72	206	4	9	2	2	0	-2	2	0	0	2.0190967826718174	
i 1	430.01550340136055	0.505	73	704	3	20	6	2	0	-1	2	0	0	0.12101100041360136	
i 1	430.2359387755102	3.0300000000000002	68	206	3	20	1	1	0	0	1	0	0	0.12101100041360136	
i 1	430.2460340136054	0.2525	70	908	3	20	10	2	0	-1	2	0	0	0.12101100041360136	
i 1	430.25757142857145	0.2525	71	206	5	1	8	2	0	-1	2	0	0	2.0	
i 1	430.4859387755102	0.505	73	206	1	24	10	2	0	252	2	307	0	4.121011000413601	
i 1	430.4917074829932	0.7575000000000001	72	704	4	4	2	8	0	1	8	0	0	3.0190967826718174	
i 1	430.49747619047616	0.2525	77	206	7	1	1	17	0	1	17	0	0	2.0	
i 1	430.49819727891156	0.7575000000000001	71	206	5	4	15	2	0	-1	2	0	0	3.0190967826718174	
i 1	430.50757142857145	0.505	70	206	3	20	10	2	0	-1	2	0	0	0.12101100041360136	
i 1	430.5090136054422	0.505	70	206	2	20	16	8	0	-2	8	0	0	0.12101100041360136	
i 1	430.5176666666667	0.505	70	206	3	20	13	8	0	-1	8	0	0	0.12101100041360136	
i 1	430.73521768707485	0.2525	74	704	6	5	5	8	0	-1	8	0	0	2.0	
i 1	430.7554081632653	0.505	75	704	4	3	4	8	0	1	8	0	0	3.0190967826718174	
i 1	430.76189795918367	0.505	71	206	3	3	4	8	0	-2	8	0	0	3.0190967826718174	
i 1	430.9953129251701	0.2525	70	908	3	20	13	8	0	-1	8	0	0	0.12101100041360136	
i 1	430.9967551020408	0.2525	73	704	3	20	2	2	0	-2	2	0	0	0.12101100041360136	
i 1	431.00180272108844	0.7575000000000001	70	206	2	20	13	8	0	-1	8	0	0	0.12101100041360136	
i 1	431.00757142857145	0.2525	73	908	3	20	6	2	0	-2	2	0	0	0.12101100041360136	
i 1	431.0090136054422	0.2525	75	206	3	5	3	2	0	1	2	0	0	2.0	
i 1	431.0176666666667	0.2525	74	704	4	24	7	17	0	1	17	0	0	3.0	
i 1	431.2323333333333	1.5150000000000001	71	908	6	1	3	2	0	-1	2	0	0	4.0	
i 1	431.23377551020405	0.2525	71	206	7	1	7	2	0	-1	2	0	0	4.0	
i 1	431.23449659863945	40.6525	61	206	5	18	16	6	0	1	6	0	0	5.188252614165814	
i 1	431.2359387755102	0.2525	73	206	3	20	9	2	0	-1	2	0	0	0.12101100041360136	
i 1	431.23738095238093	0.7575000000000001	71	206	7	5	11	2	0	-1	2	0	0	9.0	
i 1	431.23738095238093	0.2525	70	206	2	20	8	2	0	-2	2	0	0	0.12101100041360136	
i 1	431.24242857142855	0.2525	71	704	6	5	15	2	0	-1	2	0	0	9.0	
i 1	431.24387074829934	0.7575000000000001	71	206	3	3	11	8	0	-2	8	0	0	3.0	
i 1	431.2467551020408	23.23	60	908	6	17	2	5	0	0	5	0	0	5.188252614165814	
i 1	431.2467551020408	11.615	67	206	4	19	15	5	0	1	5	0	0	5.188252614165814	
i 1	431.24819727891156	17.4225	67	908	6	17	1	5	0	0	5	0	0	5.188252614165814	
i 1	431.24891836734696	26.5125	66	704	6	17	10	6	0	1	6	0	0	5.188252614165814	
i 1	431.25108163265304	1.5150000000000001	77	206	7	1	10	17	0	2	17	0	0	4.0	
i 1	431.25108163265304	11.615	60	206	4	12	1	0	0	1	0	0	0	0.4639022334668534	
i 1	431.25180272108844	5.8075	67	206	4	12	6	5	0	1	5	0	0	0.4639022334668534	
i 1	431.25180272108844	0.7575000000000001	71	206	3	24	9	1	0	0	1	0	0	4.121011000413601	
i 1	431.2554081632653	5.8075	60	206	4	19	15	0	0	1	0	0	0	5.188252614165814	
i 1	431.25685034013605	26.5125	66	704	6	17	3	6	0	1	6	0	0	5.188252614165814	
i 1	431.26045578231293	2.02	75	206	4	9	2	2	0	1	2	0	0	2.0	
i 1	431.26189795918367	41.1575	66	206	5	18	7	9	0	1	9	0	0	5.188252614165814	
i 1	431.26189795918367	1.01	75	908	5	5	13	2	0	1	2	0	0	9.0	
i 1	431.26550340136055	0.2525	73	206	3	20	11	8	0	-1	8	0	0	0.12101100041360136	
i 1	431.2676666666667	0.7575000000000001	75	704	4	3	6	8	0	1	8	0	0	3.0	
i 1	431.48449659863945	1.5150000000000001	71	908	5	2	15	8	0	-1	8	0	0	3.0	
i 1	431.48738095238093	1.7675	74	704	5	5	16	8	0	-1	8	0	0	9.0	
i 1	431.49819727891156	1.7675	75	206	7	5	6	2	0	1	2	0	0	9.0	
i 1	431.50757142857145	0.2525	73	908	3	20	3	8	0	-1	8	0	0	0.12101100041360136	
i 1	431.7445918367347	3.535	70	206	3	20	16	2	0	-2	2	0	0	0.12101100041360136	
i 1	431.7460340136054	0.2525	70	206	2	20	7	2	0	-1	2	0	0	0.12101100041360136	
i 1	431.7582925170068	1.5150000000000001	73	206	3	20	15	8	0	-1	8	0	0	0.12101100041360136	
i 1	431.99314965986395	0.2525	74	704	4	24	8	17	0	1	17	0	0	5.0	
i 1	431.9967551020408	0.505	71	206	3	4	3	2	0	-1	2	0	0	3.0	
i 1	432.23449659863945	2.525	71	206	7	1	13	2	0	-1	2	0	0	4.0	
i 1	432.2554081632653	2.7775	77	704	6	1	4	16	0	1	16	0	0	4.0	
i 1	432.2640612244898	0.505	71	206	7	5	13	2	0	-1	2	0	0	9.0	
i 1	432.4967551020408	2.02	71	206	3	3	14	8	0	-2	8	0	0	3.0	
i 1	432.51550340136055	1.7675	75	704	4	3	13	8	0	1	8	0	0	3.0	
i 1	432.73449659863945	1.7675	74	206	7	5	1	2	0	-2	2	0	0	9.0	
i 1	432.74387074829934	1.7675	72	908	4	5	5	2	0	1	2	0	0	9.0	
i 1	432.75973469387753	0.2525	74	704	4	24	3	17	0	1	17	0	0	5.0	
i 1	432.98521768707485	0.2525	77	206	7	1	1	17	0	1	17	0	0	4.0	
i 1	433.25252380952384	0.505	72	206	4	9	1	2	0	-2	2	0	0	2.0	
i 1	433.2539659863946	0.2525	70	206	2	20	8	8	0	-1	8	0	0	0.12101100041360136	
i 1	433.26261904761907	0.2525	74	704	4	24	12	17	0	1	17	0	0	5.0	
i 1	433.2640612244898	0.2525	75	206	3	5	10	2	0	1	2	0	0	9.0	
i 1	433.2669455782313	0.505	71	908	4	2	4	2	0	-2	2	0	0	3.0	
i 1	433.48449659863945	0.2525	75	206	7	5	6	2	0	1	2	0	0	9.0	
i 1	433.4996394557823	0.2525	71	206	3	24	7	1	0	0	1	0	0	4.121011000413601	
i 1	433.7445918367347	0.2525	74	704	5	5	5	8	0	-1	8	0	0	9.0	
i 1	433.74819727891156	2.525	70	206	2	20	6	2	0	-1	2	0	0	0.12101100041360136	
i 1	433.7554081632653	0.2525	71	206	3	4	3	2	0	-1	2	0	0	3.0	
i 1	433.75973469387753	4.04	70	206	2	20	10	8	0	-1	8	0	0	0.12101100041360136	
i 1	433.9830544217687	1.01	72	206	4	9	9	2	0	-2	2	0	0	2.0	
i 1	433.99387074829934	0.2525	77	206	7	1	11	17	0	2	17	0	0	4.0	
i 1	434.0039659863946	1.01	71	908	4	2	14	2	0	-2	2	0	0	3.0	
i 1	434.24891836734696	2.7775	74	704	4	24	5	17	0	1	17	0	0	5.0	
i 1	434.25180272108844	1.01	71	704	6	5	16	2	0	-1	2	0	0	9.0	
i 1	434.2532448979592	2.7775	74	206	5	24	9	2	0	-2	2	0	0	5.0	
i 1	434.25685034013605	1.01	75	206	3	5	10	2	0	1	2	0	0	9.0	
i 1	434.49026530612247	0.7575000000000001	71	206	3	24	7	1	0	0	1	0	0	4.121011000413601	
i 1	434.4960340136054	0.505	75	206	7	5	16	2	0	1	2	0	0	9.0	
i 1	434.50973469387753	0.7575000000000001	70	206	2	24	14	2	0	-1	2	0	0	4.121011000413601	
i 1	434.74747619047616	1.5150000000000001	71	206	3	4	6	2	0	-1	2	0	0	3.0	
i 1	434.7676666666667	1.5150000000000001	72	704	4	4	8	8	0	1	8	0	0	3.0	
i 1	434.9823333333333	0.7575000000000001	72	908	4	5	7	2	0	1	2	0	0	9.0	
i 1	434.98449659863945	0.7575000000000001	74	206	7	5	3	2	0	-2	2	0	0	9.0	
i 1	434.98738095238093	0.7575000000000001	71	908	6	1	8	2	0	-1	2	0	0	4.0	
i 1	435.01189795918367	0.2525	75	704	4	3	14	8	0	1	8	0	0	3.0	
i 1	435.01622448979595	0.7575000000000001	77	206	7	1	16	17	0	2	17	0	0	4.0	
i 1	435.48954421768707	1.5150000000000001	75	908	5	5	5	2	0	1	2	0	0	9.0	
i 1	435.49891836734696	1.7675	71	206	7	5	1	2	0	-1	2	0	0	9.0	
i 1	435.50612925170066	0.2525	73	206	3	20	11	8	0	-1	8	0	0	0.12101100041360136	
i 1	435.5111768707483	0.2525	75	206	4	9	3	2	0	1	2	0	0	2.0	
i 1	435.7323333333333	1.5150000000000001	71	206	3	3	11	8	0	-2	8	0	0	3.0	
i 1	435.7330544217687	0.2525	71	704	6	5	16	2	0	-1	2	0	0	9.0	
i 1	435.7388231292517	0.2525	77	206	7	1	10	17	0	1	17	0	0	4.0	
i 1	435.7409863945578	0.2525	70	206	2	24	7	2	0	-1	2	0	0	4.121011000413601	
i 1	435.7496394557823	1.5150000000000001	75	704	4	3	11	8	0	1	8	0	0	3.0	
i 1	436.00108163265304	0.2525	72	908	4	5	13	2	0	1	2	0	0	9.0	
i 1	436.0082925170068	0.2525	74	908	5	1	14	2	0	-1	2	0	0	4.0	
i 1	436.2330544217687	0.2525	73	704	3	20	2	2	0	-2	2	0	0	0.12101100041360136	
i 1	436.24314965986395	1.5150000000000001	68	206	3	20	4	1	0	0	1	0	0	0.12101100041360136	
i 1	436.24387074829934	0.2525	75	206	7	5	5	2	0	1	2	0	0	9.0	
i 1	436.2445918367347	0.505	71	206	3	24	2	1	0	0	1	0	0	4.121011000413601	
i 1	436.26045578231293	0.2525	73	908	3	20	12	8	0	-2	8	0	0	0.12101100041360136	
i 1	436.2611768707483	0.505	70	206	2	24	6	2	0	-1	2	0	0	4.121011000413601	
i 1	436.48449659863945	0.505	71	908	5	2	10	8	0	-1	8	0	0	3.0	
i 1	436.48738095238093	3.535	72	908	4	5	10	2	0	1	2	0	0	9.0	
i 1	436.48738095238093	1.2625	70	206	3	20	12	2	0	-1	2	0	0	0.12101100041360136	
i 1	436.5054081632653	0.505	75	206	4	9	10	2	0	1	2	0	0	2.0	
i 1	436.5090136054422	1.2625	70	206	2	20	13	2	0	-2	2	0	0	0.12101100041360136	
i 1	436.7503605442177	0.2525	71	206	7	1	1	2	0	-1	2	0	0	4.0	
i 1	436.76550340136055	3.2825	74	206	7	5	15	2	0	-2	2	0	0	9.0	
i 1	436.99747619047616	35.35	60	206	5	19	7	0	0	1	0	0	0	5.188252614165814	
i 1	437.00612925170066	0.7575000000000001	74	704	4	24	11	17	0	1	17	0	0	5.0	
i 1	437.00685034013605	0.505	75	908	4	5	1	2	0	1	2	0	0	9.0	
i 1	437.00973469387753	3.2825	77	206	7	1	7	17	0	2	17	0	0	4.0	
i 1	437.01189795918367	3.2825	71	908	5	1	7	2	0	-1	2	0	0	4.0	
i 1	437.01622448979595	0.505	74	206	5	24	7	2	0	-2	2	0	0	5.0	
i 1	437.23449659863945	0.505	72	206	4	9	4	2	0	-2	2	0	0	2.0	
i 1	437.2503605442177	0.2525	71	908	5	2	13	8	0	-1	8	0	0	3.0	
i 1	437.25685034013605	0.505	71	908	5	2	13	2	0	-2	2	0	0	3.0	
i 1	437.49026530612247	0.2525	74	704	5	5	10	8	0	-1	8	0	0	9.0	
i 1	437.4945918367347	0.7575000000000001	70	206	2	24	13	2	0	-1	2	0	0	4.121011000413601	
i 1	437.5046870748299	1.01	75	704	4	3	12	8	0	1	8	0	0	3.0	
i 1	437.5090136054422	0.505	73	206	3	20	2	2	0	-1	2	0	0	0.12101100041360136	
i 1	437.51478231292515	1.01	71	206	3	3	3	8	0	-2	8	0	0	3.0	
i 1	437.73377551020405	0.2525	77	206	7	1	4	17	0	1	17	0	0	4.0	
i 1	437.74387074829934	0.2525	71	206	7	5	3	2	0	-1	2	0	0	9.0	
i 1	437.75757142857145	1.7675	71	206	3	24	7	1	0	0	1	0	0	4.121011000413601	
i 1	437.7590136054422	0.2525	71	206	3	4	2	2	0	-1	2	0	0	3.0	
i 1	437.98377551020405	1.5150000000000001	68	206	3	20	6	1	0	0	1	0	0	0.12101100041360136	
i 1	437.9859387755102	2.02	72	206	4	9	6	2	0	-2	2	0	0	2.0	
i 1	437.99314965986395	2.525	70	206	2	20	2	8	0	-1	8	0	0	0.12101100041360136	
i 1	437.9953129251701	0.2525	70	908	3	20	5	8	0	-1	8	0	0	0.12101100041360136	
i 1	437.9953129251701	0.2525	73	704	3	24	1	8	0	-2	8	0	0	4.121011000413601	
i 1	437.99891836734696	0.2525	74	206	5	24	4	2	0	-2	2	0	0	5.0	
i 1	438.00180272108844	2.02	71	908	5	2	12	2	0	-2	2	0	0	3.0	
i 1	438.01478231292515	0.2525	73	704	3	20	4	2	0	-1	2	0	0	0.12101100041360136	
i 1	438.0176666666667	0.505	75	908	4	5	2	2	0	1	2	0	0	9.0	
i 1	438.2445918367347	0.505	70	206	2	24	6	2	0	-1	2	0	0	4.121011000413601	
i 1	438.2532448979592	0.7575000000000001	73	206	3	20	9	8	0	-2	8	0	0	0.12101100041360136	
i 1	438.2554081632653	0.2525	70	206	3	20	15	2	0	-1	2	0	0	0.12101100041360136	
i 1	438.26261904761907	0.7575000000000001	70	206	2	20	2	2	0	-1	2	0	0	0.12101100041360136	
i 1	438.4953129251701	0.2525	71	704	5	5	6	2	0	-1	2	0	0	9.0	
i 1	438.5054081632653	0.2525	71	206	3	4	4	2	0	-1	2	0	0	3.0	
i 1	438.74387074829934	0.7575000000000001	71	206	3	3	2	8	0	-2	8	0	0	3.0	
i 1	438.7640612244898	0.2525	74	206	5	24	14	2	0	-2	2	0	0	5.0	
i 1	438.98377551020405	0.2525	70	908	3	20	1	8	0	-1	8	0	0	0.12101100041360136	
i 1	438.98377551020405	0.2525	70	704	3	20	10	8	0	-2	8	0	0	0.12101100041360136	
i 1	438.98810204081633	0.2525	70	908	3	20	15	8	0	-1	8	0	0	0.12101100041360136	
i 1	438.9888231292517	3.7875	70	206	2	24	15	2	0	-1	2	0	0	4.121011000413601	
i 1	438.99891836734696	0.7575000000000001	74	704	4	24	2	17	0	1	17	0	0	5.0	
i 1	439.0111768707483	0.2525	71	704	5	5	10	2	0	-1	2	0	0	9.0	
i 1	439.24242857142855	1.2625	70	206	2	20	11	2	0	-1	2	0	0	0.12101100041360136	
i 1	439.2467551020408	0.2525	70	206	3	20	1	8	0	-1	8	0	0	0.12101100041360136	
i 1	439.25973469387753	1.7675	71	206	7	5	16	2	0	-1	2	0	0	9.0	
i 1	439.2640612244898	2.2725	73	206	3	20	9	2	0	-2	2	0	0	0.12101100041360136	
i 1	439.4953129251701	1.5150000000000001	75	908	4	5	16	2	0	1	2	0	0	9.0	
i 1	439.5176666666667	0.2525	75	704	4	3	14	8	0	1	8	0	0	3.0	
i 1	439.7496394557823	0.2525	71	908	5	2	12	8	0	-1	8	0	0	3.0	
i 1	439.75685034013605	1.7675	71	206	7	1	13	2	0	-1	2	0	0	4.0	
i 1	439.7640612244898	1.7675	77	704	6	1	12	16	0	1	16	0	0	4.0	
i 1	439.98521768707485	0.505	71	206	3	4	12	2	0	-1	2	0	0	3.0	
i 1	439.99314965986395	0.505	72	704	4	4	8	8	0	1	8	0	0	3.0	
i 1	440.2366598639456	1.2625	70	206	2	24	1	2	0	-2	2	0	0	4.121011000413601	
i 1	440.24314965986395	1.2625	75	704	4	3	11	8	0	1	8	0	0	3.0	
i 1	440.2554081632653	1.2625	71	206	3	24	2	1	0	0	1	0	0	4.121011000413601	
i 1	440.2590136054422	0.7575000000000001	75	206	4	9	11	2	0	1	2	0	0	2.0	
i 1	440.25973469387753	0.7575000000000001	71	908	5	2	3	8	0	-1	8	0	0	3.0	
i 1	440.26478231292515	0.2525	75	206	7	5	15	2	0	1	2	0	0	9.0	
i 1	440.26622448979595	1.2625	71	206	3	3	11	8	0	-2	8	0	0	3.0	
i 1	440.7366598639456	0.2525	77	206	7	1	9	17	0	2	17	0	0	4.0	
i 1	440.7388231292517	0.2525	72	908	4	5	4	2	0	1	2	0	0	9.0	
i 1	440.98810204081633	1.01	75	206	7	5	10	2	0	1	2	0	0	9.0	
i 1	440.99387074829934	1.01	74	704	5	5	4	8	0	-1	8	0	0	9.0	
i 1	441.00612925170066	0.2525	75	206	7	5	4	2	0	1	2	0	0	9.0	
i 1	441.01478231292515	2.02	74	704	4	24	4	17	0	1	17	0	0	5.0	
i 1	441.01478231292515	2.02	74	206	5	24	15	2	0	-2	2	0	0	5.0	
i 1	441.2453129251701	0.7575000000000001	70	206	2	20	2	8	0	-1	8	0	0	0.12101100041360136	
i 1	441.26045578231293	0.2525	71	206	7	5	16	2	0	-1	2	0	0	9.0	
i 1	441.26045578231293	0.7575000000000001	70	206	2	20	7	2	0	-1	2	0	0	0.12101100041360136	
i 1	441.48377551020405	1.2625	71	908	5	2	12	2	0	-2	2	0	0	3.0	
i 1	441.49242857142855	1.01	72	206	4	9	12	2	0	-2	2	0	0	2.0	
i 1	441.51045578231293	0.2525	72	704	4	4	3	8	0	1	8	0	0	3.0	
i 1	441.7409863945578	0.7575000000000001	71	206	3	24	10	1	0	0	1	0	0	4.121011000413601	
i 1	441.75180272108844	0.2525	70	206	3	20	10	8	0	-1	8	0	0	0.12101100041360136	
i 1	441.98377551020405	0.505	74	206	7	5	3	2	0	-2	2	0	0	9.0	
i 1	441.99026530612247	0.2525	73	908	3	20	1	8	0	-2	8	0	0	0.12101100041360136	
i 1	441.9917074829932	0.505	72	908	4	5	1	2	0	1	2	0	0	9.0	
i 1	442.00685034013605	0.2525	71	908	5	1	6	2	0	-1	2	0	0	4.0	
i 1	442.0133401360544	0.2525	70	704	3	20	1	8	0	-2	8	0	0	0.12101100041360136	
i 1	442.23738095238093	1.7675	71	704	5	5	5	2	0	-1	2	0	0	9.0	
i 1	442.23954421768707	0.2525	74	908	5	1	6	2	0	-1	2	0	0	4.0	
i 1	442.2467551020408	0.505	75	704	4	3	8	8	0	1	8	0	0	3.0	
i 1	442.25108163265304	0.2525	73	206	2	20	5	2	0	-2	2	0	0	0.12101100041360136	
i 1	442.25612925170066	1.7675	75	206	7	5	16	2	0	1	2	0	0	9.0	
i 1	442.2590136054422	1.01	71	206	3	3	10	8	0	-2	8	0	0	3.0	
i 1	442.26045578231293	0.7575000000000001	68	206	3	20	8	1	0	0	1	0	0	0.12101100041360136	
i 1	442.4909863945578	0.2525	70	908	3	20	2	8	0	-1	8	0	0	0.12101100041360136	
i 1	442.4909863945578	0.2525	73	704	3	20	9	8	0	-2	8	0	0	0.12101100041360136	
i 1	442.49387074829934	0.2525	73	908	3	20	7	2	0	-1	2	0	0	0.12101100041360136	
i 1	442.5111768707483	0.2525	75	206	7	5	7	2	0	1	2	0	0	9.0	
i 1	442.51261904761907	1.5150000000000001	77	206	7	1	4	17	0	2	17	0	0	4.0	
i 1	442.5133401360544	1.2625	71	908	5	1	3	2	0	-1	2	0	0	4.0	
i 1	442.5133401360544	1.5150000000000001	70	206	2	20	9	8	0	-1	8	0	0	0.12101100041360136	
i 1	442.73521768707485	1.2625	73	206	2	20	14	8	0	-1	8	0	0	0.12101100041360136	
i 1	442.7388231292517	29.5425	67	206	5	19	8	5	0	1	5	0	0	5.188252614165814	
i 1	442.7640612244898	0.2525	75	206	4	9	13	2	0	1	2	0	0	2.0	
i 1	442.76622448979595	0.505	75	704	5	3	7	8	0	1	8	0	0	3.0	
i 1	443.0046870748299	1.01	72	206	4	9	6	2	0	-2	2	0	0	2.0	
i 1	443.0133401360544	0.2525	75	206	7	5	10	2	0	1	2	0	0	9.0	
i 1	443.01550340136055	1.01	71	908	5	2	1	2	0	-2	2	0	0	3.0	
i 1	443.24242857142855	0.2525	68	206	3	20	8	1	0	0	1	0	0	0.12101100041360136	
i 1	443.2453129251701	2.02	74	704	4	24	14	17	0	1	17	0	0	5.0	
i 1	443.25612925170066	1.01	71	206	3	4	13	2	0	-1	2	0	0	3.0	
i 1	443.26189795918367	2.02	74	206	5	24	14	2	0	-2	2	0	0	5.0	
i 1	443.49314965986395	0.2525	70	206	3	20	7	8	0	-2	8	0	0	0.12101100041360136	
i 1	443.50612925170066	1.01	72	704	4	4	3	8	0	1	8	0	0	3.0	
i 1	443.5090136054422	1.7675	74	206	5	5	15	2	0	-2	2	0	0	9.0	
i 1	443.7417074829932	1.2625	71	206	3	3	9	8	0	-2	8	0	0	3.0	
i 1	443.7590136054422	0.2525	68	206	3	20	11	1	0	0	1	0	0	0.12101100041360136	
i 1	443.7669455782313	1.5150000000000001	72	908	4	5	4	2	0	1	2	0	0	9.0	
i 1	443.7676666666667	1.2625	75	704	5	3	3	8	0	1	8	0	0	3.0	
i 1	443.99242857142855	0.505	73	908	3	20	8	8	0	-2	8	0	0	0.12101100041360136	
i 1	443.99242857142855	0.505	71	206	3	24	13	1	0	0	1	0	0	4.121011000413601	
i 1	444.00612925170066	3.0300000000000002	70	206	2	24	12	2	0	-1	2	0	0	4.121011000413601	
i 1	444.0090136054422	0.505	73	704	3	20	4	2	0	-2	2	0	0	0.12101100041360136	
i 1	444.23954421768707	0.2525	71	206	7	1	16	2	0	-1	2	0	0	4.0	
i 1	444.26550340136055	0.505	71	704	5	5	9	2	0	-1	2	0	0	9.0	
i 1	444.4823333333333	1.01	71	206	1	24	15	1	0	248	1	308	0	4.121011000413601	
i 1	444.4830544217687	1.2625	70	206	3	20	1	8	0	-1	8	0	0	0.12101100041360136	
i 1	444.4960340136054	1.2625	75	206	4	9	9	2	0	1	2	0	0	2.0	
i 1	444.50108163265304	1.2625	68	206	3	20	8	1	0	0	1	0	0	0.12101100041360136	
i 1	444.50180272108844	1.2625	71	908	5	2	8	8	0	-1	8	0	0	3.0	
i 1	444.5032448979592	1.5150000000000001	70	206	3	20	7	2	0	-2	2	0	0	0.12101100041360136	
i 1	444.76045578231293	2.02	71	908	5	1	7	2	0	-1	2	0	0	4.0	
i 1	444.7640612244898	2.02	77	206	7	1	2	17	0	2	17	0	0	4.0	
i 1	444.99026530612247	0.2525	71	206	3	4	6	2	0	-1	2	0	0	3.0	
i 1	444.99242857142855	2.02	75	908	4	5	4	2	0	1	2	0	0	9.0	
i 1	445.00180272108844	1.7675	71	206	7	5	2	2	0	-1	2	0	0	9.0	
i 1	445.48377551020405	0.505	71	206	3	24	12	1	0	0	1	0	0	4.121011000413601	
i 1	445.4917074829932	1.7675	75	704	5	3	6	8	0	1	8	0	0	3.0	
i 1	445.4996394557823	0.505	70	206	2	24	9	2	0	-2	2	0	0	4.121011000413601	
i 1	445.51045578231293	1.01	71	206	3	3	8	8	0	-2	8	0	0	3.0	
i 1	445.7388231292517	0.2525	77	704	5	1	2	16	0	1	16	0	0	4.0	
i 1	445.74026530612247	1.7675	70	206	2	20	3	8	0	-1	8	0	0	0.12101100041360136	
i 1	445.7582925170068	0.2525	72	908	4	5	6	2	0	1	2	0	0	9.0	
i 1	445.7611768707483	0.2525	70	206	2	20	16	8	0	-2	8	0	0	0.12101100041360136	
i 1	445.9909863945578	0.2525	71	704	5	5	7	2	0	-1	2	0	0	9.0	
i 1	445.99819727891156	1.2625	71	206	1	24	10	1	0	252	1	307	0	4.121011000413601	
i 1	446.00180272108844	0.2525	71	908	5	2	9	8	0	-1	8	0	0	3.0	
i 1	446.0046870748299	0.7575000000000001	70	704	3	24	16	8	0	-2	8	0	0	4.121011000413601	
i 1	446.01550340136055	0.7575000000000001	73	704	3	20	10	8	0	-2	8	0	0	0.12101100041360136	
i 1	446.2503605442177	3.0300000000000002	77	704	5	1	10	16	0	1	16	0	0	4.0	
i 1	446.2590136054422	2.525	74	206	5	5	5	2	0	-2	2	0	0	9.0	
i 1	446.4830544217687	2.2725	72	908	4	5	1	2	0	1	2	0	0	9.0	
i 1	446.49026530612247	0.2525	71	908	5	2	2	2	0	-2	2	0	0	3.0	
i 1	446.51189795918367	2.7775	71	206	7	1	16	2	0	-1	2	0	0	4.0	
i 1	446.5169455782313	0.2525	72	206	4	9	10	2	0	-2	2	0	0	2.0	
i 1	446.73810204081633	0.7575000000000001	73	206	2	20	2	8	0	-2	8	0	0	0.12101100041360136	
i 1	446.7409863945578	0.7575000000000001	70	206	3	20	14	2	0	-2	2	0	0	0.12101100041360136	
i 1	446.7503605442177	0.2525	73	206	2	24	15	8	0	-1	8	0	0	4.121011000413601	
i 1	446.7582925170068	0.7575000000000001	68	206	3	20	16	1	0	0	1	0	0	0.12101100041360136	
i 1	446.76478231292515	0.505	71	206	3	3	15	8	0	-2	8	0	0	3.0	
i 1	446.9866598639456	1.01	71	908	5	2	6	2	0	-2	2	0	0	3.0	
i 1	447.0003605442177	1.01	72	206	4	9	4	2	0	-2	2	0	0	2.0	
i 1	447.2330544217687	0.7575000000000001	71	206	3	24	2	1	0	0	1	0	0	4.121011000413601	
i 1	447.2359387755102	0.7575000000000001	70	206	2	24	15	2	0	-1	2	0	0	4.121011000413601	
i 1	447.2366598639456	0.7575000000000001	73	206	2	24	9	8	0	-1	8	0	0	4.121011000413601	
i 1	447.23954421768707	0.2525	74	704	4	5	6	8	0	-1	8	0	0	9.0	
i 1	447.2409863945578	0.2525	71	908	5	1	15	2	0	-1	2	0	0	4.0	
i 1	447.25108163265304	0.7575000000000001	73	206	3	20	13	8	0	-1	8	0	0	0.12101100041360136	
i 1	447.7467551020408	0.2525	75	206	7	5	11	2	0	1	2	0	0	9.0	
i 1	447.74819727891156	0.7575000000000001	68	206	3	20	15	1	0	0	1	0	0	0.12101100041360136	
i 1	447.7554081632653	0.2525	71	206	3	3	8	8	0	-2	8	0	0	3.0	
i 1	447.9866598639456	0.2525	70	908	3	20	13	2	0	-2	2	0	0	0.12101100041360136	
i 1	447.9917074829932	1.2625	71	206	3	4	15	2	0	-1	2	0	0	3.0	
i 1	448.0003605442177	0.505	72	704	4	4	11	8	0	1	8	0	0	3.0	
i 1	448.00108163265304	0.2525	70	908	3	20	5	2	0	-1	2	0	0	0.12101100041360136	
i 1	448.2359387755102	0.2525	70	206	2	24	2	2	0	-1	2	0	0	4.121011000413601	
i 1	448.24387074829934	0.2525	73	206	2	24	13	8	0	-2	8	0	0	4.121011000413601	
i 1	448.24747619047616	0.7575000000000001	70	206	2	20	3	8	0	-1	8	0	0	0.12101100041360136	
i 1	448.25108163265304	0.2525	71	206	3	24	8	1	0	0	1	0	0	4.121011000413601	
i 1	448.25180272108844	0.2525	73	206	3	20	14	2	0	-1	2	0	0	0.12101100041360136	
i 1	448.2633401360544	0.2525	71	908	5	2	1	2	0	-2	2	0	0	3.0	
i 1	448.4830544217687	3.2825	74	704	4	24	3	17	0	1	17	0	0	5.0	
i 1	448.4888231292517	0.2525	70	704	3	24	14	2	0	-2	2	0	0	4.121011000413601	
i 1	448.50108163265304	0.7575000000000001	72	704	4	4	6	8	0	1	8	0	0	3.0	
i 1	448.5032448979592	0.505	71	206	5	5	3	2	0	-1	2	0	0	9.0	
i 1	448.50757142857145	0.505	75	908	4	5	16	2	0	1	2	0	0	9.0	
i 1	448.51478231292515	0.2525	71	908	5	2	16	8	0	-1	8	0	0	3.0	
i 1	448.5169455782313	5.8075	67	908	6	17	8	5	0	0	5	0	0	5.188252614165814	
i 1	448.73377551020405	1.01	75	704	5	3	14	8	0	1	8	0	0	3.0	
i 1	448.73449659863945	2.525	73	206	3	20	12	8	0	-2	8	0	0	0.12101100041360136	
i 1	448.73521768707485	0.7575000000000001	73	206	2	24	6	2	0	-1	2	0	0	4.121011000413601	
i 1	448.74026530612247	3.0300000000000002	74	206	5	24	14	2	0	-2	2	0	0	5.0	
i 1	448.74819727891156	0.7575000000000001	71	206	3	24	13	1	0	0	1	0	0	4.121011000413601	
i 1	448.75180272108844	2.7775	70	206	2	24	16	2	0	-1	2	0	0	4.121011000413601	
i 1	448.76261904761907	1.01	71	206	3	3	1	8	0	-2	8	0	0	3.0	
i 1	448.9888231292517	1.5150000000000001	74	704	4	5	13	8	0	-1	8	0	0	9.0	
i 1	448.99314965986395	1.5150000000000001	75	206	7	5	5	2	0	1	2	0	0	9.0	
i 1	449.2445918367347	0.2525	74	206	5	5	14	2	0	-2	2	0	0	9.0	
i 1	449.4909863945578	1.01	68	206	3	20	11	1	0	0	1	0	0	0.12101100041360136	
i 1	449.5046870748299	1.7675	71	206	1	24	3	1	0	252	1	307	0	4.121011000413601	
i 1	449.5082925170068	1.5150000000000001	73	206	1	24	2	2	0	252	2	307	0	4.121011000413601	
i 1	449.51045578231293	0.2525	71	704	4	5	3	2	0	-1	2	0	0	9.0	
i 1	449.51478231292515	1.01	70	206	3	20	7	2	0	-2	2	0	0	0.12101100041360136	
i 1	449.74387074829934	0.2525	75	206	4	9	9	2	0	1	2	0	0	2.0	
i 1	449.75757142857145	0.2525	71	908	5	2	12	8	0	-1	8	0	0	3.0	
i 1	449.9823333333333	1.5150000000000001	75	704	5	3	16	8	0	1	8	0	0	3.0	
i 1	449.9909863945578	1.5150000000000001	71	206	3	3	16	8	0	-2	8	0	0	3.0	
i 1	449.99819727891156	0.2525	72	908	4	5	6	2	0	1	2	0	0	9.0	
i 1	450.0169455782313	0.2525	77	704	5	1	1	16	0	1	16	0	0	4.0	
i 1	450.24387074829934	0.7575000000000001	71	908	4	1	3	2	0	-1	2	0	0	4.0	
i 1	450.25252380952384	0.7575000000000001	77	206	6	1	3	17	0	2	17	0	0	4.0	
i 1	450.26045578231293	0.2525	71	908	5	2	14	2	0	-2	2	0	0	3.0	
i 1	450.26261904761907	0.2525	72	206	4	9	2	2	0	-2	2	0	0	2.0	
i 1	450.48377551020405	1.5150000000000001	74	206	5	5	9	2	0	-2	2	0	0	9.0	
i 1	450.50685034013605	0.2525	71	704	4	5	14	2	0	-1	2	0	0	9.0	
i 1	450.5176666666667	1.5150000000000001	72	908	4	5	6	2	0	1	2	0	0	9.0	
i 1	451.00252380952384	1.5150000000000001	70	206	2	20	6	8	0	-1	8	0	0	0.12101100041360136	
i 1	451.01550340136055	1.5150000000000001	68	206	3	20	7	1	0	0	1	0	0	0.12101100041360136	
i 1	451.0176666666667	0.2525	73	206	2	24	6	2	0	-1	2	0	0	4.121011000413601	
i 1	451.2330544217687	0.2525	73	908	3	20	16	8	0	-2	8	0	0	0.12101100041360136	
i 1	451.23449659863945	0.2525	71	206	7	1	3	2	0	-1	2	0	0	4.0	
i 1	451.2366598639456	0.2525	73	908	3	20	7	8	0	-2	8	0	0	0.12101100041360136	
i 1	451.2417074829932	0.2525	71	206	5	5	16	2	0	-1	2	0	0	9.0	
i 1	451.2453129251701	2.02	72	206	4	9	6	2	0	-2	2	0	0	2.0	
i 1	451.25612925170066	1.7675	71	908	5	2	4	2	0	-2	2	0	0	3.0	
i 1	451.26478231292515	0.2525	70	704	3	24	8	2	0	-1	2	0	0	4.121011000413601	
i 1	451.2676666666667	0.7575000000000001	71	206	3	24	15	1	0	0	1	0	0	4.121011000413601	
i 1	451.48810204081633	0.505	70	206	2	24	5	2	0	-2	2	0	0	4.121011000413601	
i 1	451.49314965986395	0.2525	71	704	4	5	16	2	0	-1	2	0	0	9.0	
i 1	451.4967551020408	0.505	70	206	3	20	7	8	0	-1	8	0	0	0.12101100041360136	
i 1	451.49891836734696	0.505	70	206	3	20	4	2	0	-1	2	0	0	0.12101100041360136	
i 1	451.5140612244898	0.2525	72	704	4	4	2	8	0	1	8	0	0	3.0	
i 1	451.7539659863946	0.2525	74	704	4	5	3	8	0	-1	8	0	0	9.0	
i 1	451.7633401360544	2.7775	77	206	6	1	9	17	0	2	17	0	0	4.0	
i 1	451.76622448979595	0.2525	75	704	5	3	1	8	0	1	8	0	0	3.0	
i 1	451.7669455782313	2.7775	71	908	4	1	14	2	0	-1	2	0	0	4.0	
i 1	451.99891836734696	0.2525	73	704	3	24	4	8	0	-2	8	0	0	4.121011000413601	
i 1	452.00108163265304	1.5150000000000001	71	704	4	5	2	2	0	-1	2	0	0	9.0	
i 1	452.0032448979592	0.2525	73	908	3	20	11	2	0	-1	2	0	0	0.12101100041360136	
i 1	452.00757142857145	0.2525	72	704	4	4	12	8	0	1	8	0	0	3.0	
i 1	452.0090136054422	1.5150000000000001	75	206	7	5	9	2	0	1	2	0	0	9.0	
i 1	452.24026530612247	0.2525	74	704	4	5	16	8	0	-1	8	0	0	9.0	
i 1	452.2460340136054	2.02	73	206	3	20	2	2	0	-2	2	0	0	0.12101100041360136	
i 1	452.2590136054422	0.2525	73	206	2	24	15	8	0	-2	8	0	0	4.121011000413601	
i 1	452.26622448979595	2.02	70	206	2	24	16	2	0	-1	2	0	0	4.121011000413601	
i 1	452.4953129251701	0.2525	71	908	5	2	6	8	0	-1	8	0	0	3.0	
i 1	453.0032448979592	0.2525	71	206	3	4	5	2	0	-1	2	0	0	3.0	
i 1	453.0032448979592	0.7575000000000001	71	206	3	24	13	1	0	0	1	0	0	4.121011000413601	
i 1	453.01189795918367	0.2525	72	704	4	4	9	8	0	1	8	0	0	3.0	
i 1	453.0169455782313	0.7575000000000001	73	206	2	24	2	8	0	-2	8	0	0	4.121011000413601	
i 1	453.2417074829932	0.2525	71	206	3	3	13	8	0	-2	8	0	0	3.0	
i 1	453.24242857142855	0.2525	74	704	4	24	12	17	0	1	17	0	0	5.0	
i 1	453.2546870748299	1.01	74	206	5	5	11	2	0	-2	2	0	0	9.0	
i 1	453.26550340136055	1.01	72	908	4	5	9	2	0	1	2	0	0	9.0	
i 1	453.2676666666667	0.2525	75	704	5	3	5	8	0	1	8	0	0	3.0	
i 1	453.5090136054422	0.2525	71	908	5	2	1	8	0	-1	8	0	0	3.0	
i 1	453.73738095238093	0.7575000000000001	75	704	5	3	11	8	0	1	8	0	0	3.0	
i 1	453.74026530612247	0.505	68	206	3	20	2	1	0	0	1	0	0	0.12101100041360136	
i 1	453.74242857142855	0.2525	72	704	4	4	8	8	0	1	8	0	0	3.0	
i 1	453.74819727891156	0.505	70	206	3	20	12	8	0	-1	8	0	0	0.12101100041360136	
i 1	453.75180272108844	0.7575000000000001	71	206	3	3	1	8	0	-2	8	0	0	3.0	
i 1	453.7633401360544	0.505	71	206	1	24	1	1	0	252	1	307	0	4.121011000413601	
i 1	454.24026530612247	1.2625	72	206	4	9	9	2	0	-2	2	0	0	2.0	
i 1	454.2445918367347	0.2525	72	908	6	5	6	2	0	1	2	0	0	9.0	
i 1	454.2453129251701	1.2625	71	908	5	2	2	2	0	-2	2	0	0	3.0	
i 1	454.2467551020408	5.8075	60	908	6	17	3	5	0	0	5	0	0	5.188252614165814	
i 1	454.26189795918367	0.2525	74	206	4	5	7	2	0	-2	2	0	0	9.0	
i 1	454.26189795918367	1.2625	70	206	2	24	6	2	0	-1	2	0	0	4.0	
i 1	454.48521768707485	2.2725	71	206	5	1	2	2	0	-1	2	0	0	4.0	
i 1	454.50252380952384	1.01	75	908	4	5	3	2	0	1	2	0	0	9.0	
i 1	454.5046870748299	2.2725	77	704	4	1	5	16	0	1	16	0	0	4.0	
i 1	454.5046870748299	0.2525	71	206	3	4	1	2	0	-1	2	0	0	3.0	
i 1	454.51261904761907	1.01	71	206	5	5	16	2	0	-1	2	0	0	9.0	
i 1	455.0090136054422	0.7575000000000001	71	206	3	24	4	1	0	0	1	0	0	4.0	
i 1	455.0111768707483	0.505	73	206	2	24	16	8	0	-2	8	0	0	4.0	
i 1	455.4866598639456	1.7675	74	206	4	5	8	2	0	-2	2	0	0	9.0	
i 1	455.49387074829934	0.7575000000000001	71	206	3	3	2	8	0	-2	8	0	0	3.0	
i 1	455.5039659863946	1.7675	72	908	6	5	2	2	0	1	2	0	0	9.0	
i 1	455.50685034013605	0.7575000000000001	75	704	5	3	10	8	0	1	8	0	0	3.0	
i 1	455.7359387755102	0.505	74	908	6	1	2	2	0	-1	2	0	0	4.0	
i 1	455.7467551020408	0.7575000000000001	70	206	2	24	8	2	0	-1	2	0	0	4.0	
i 1	455.7503605442177	0.2525	75	206	4	5	1	2	0	1	2	0	0	9.0	
i 1	456.2330544217687	1.01	74	704	4	24	6	17	0	1	17	0	0	5.0	
i 1	456.24314965986395	1.01	74	206	5	24	1	2	0	-2	2	0	0	5.0	
i 1	456.24314965986395	0.505	71	908	5	2	2	2	0	-2	2	0	0	3.0	
i 1	456.24314965986395	0.505	72	206	4	9	8	2	0	-2	2	0	0	2.0	
i 1	456.49387074829934	0.2525	73	704	3	24	1	8	0	-1	8	0	0	4.0	
i 1	456.50252380952384	0.2525	75	704	5	3	4	8	0	1	8	0	0	3.0	
i 1	456.73521768707485	0.2525	73	206	2	24	1	8	0	-2	8	0	0	4.0	
i 1	456.7359387755102	0.2525	71	206	3	4	14	2	0	-1	2	0	0	3.0	
i 1	456.7417074829932	0.505	71	206	3	24	5	1	0	0	1	0	0	4.0	
i 1	456.76622448979595	0.2525	72	704	4	4	3	8	0	1	8	0	0	3.0	
i 1	456.76622448979595	0.2525	70	206	2	24	5	2	0	-1	2	0	0	4.0	
i 1	456.98810204081633	0.505	71	206	3	3	4	8	0	-2	8	0	0	3.0	
i 1	457.0054081632653	0.505	75	704	5	3	6	8	0	1	8	0	0	3.0	
i 1	457.23810204081633	1.5150000000000001	71	206	5	5	2	2	0	-1	2	0	0	9.0	
i 1	457.2445918367347	2.7775	71	908	4	1	6	2	0	-1	2	0	0	4.0	
i 1	457.2503605442177	2.02	70	206	2	24	15	2	0	-1	2	0	0	4.0	
i 1	457.25612925170066	0.505	77	206	6	1	4	17	0	2	17	0	0	4.0	
i 1	457.25612925170066	0.505	75	908	4	5	4	2	0	1	2	0	0	9.0	
i 1	457.49387074829934	8.3325	60	592	6	17	16	5	0	1	5	0	0	5.188252614165814	
i 1	457.49747619047616	1.2625	72	908	6	5	12	2	0	1	2	0	0	9.0	
i 1	457.49891836734696	1.01	71	592	5	3	12	8	0	-2	8	0	0	3.0	
i 1	457.50108163265304	1.01	71	206	3	4	1	2	0	-1	2	0	0	3.0	
i 1	457.5133401360544	3.7875	71	206	5	1	5	2	0	-1	2	0	0	4.0	
i 1	457.5140612244898	2.525	60	592	6	17	10	5	0	1	5	0	0	5.188252614165814	
i 1	457.75612925170066	0.2525	75	206	5	9	3	2	0	1	2	0	0	2.0	
i 1	458.4996394557823	0.7575000000000001	71	908	5	2	16	2	0	-2	2	0	0	3.0	
i 1	458.5054081632653	0.7575000000000001	71	206	3	3	8	8	0	-2	8	0	0	3.0	
i 1	458.7366598639456	1.2625	74	206	4	5	10	2	0	-2	2	0	0	9.0	
i 1	458.74747619047616	1.2625	75	592	4	5	9	2	0	1	2	0	0	9.0	
i 1	459.2539659863946	0.2525	71	206	3	4	7	2	0	-1	2	0	0	3.0	
i 1	459.26478231292515	0.2525	71	592	5	3	5	8	0	-2	8	0	0	3.0	
i 1	459.2669455782313	0.2525	71	206	3	24	2	1	0	0	1	0	0	4.0	
i 1	459.4909863945578	0.505	71	908	5	2	6	2	0	-2	2	0	0	3.0	
i 1	459.5039659863946	1.01	70	206	2	24	15	2	0	-1	2	0	0	4.0	
i 1	459.5054081632653	0.505	71	206	3	3	2	8	0	-2	8	0	0	3.0	
i 1	459.9823333333333	1.01	71	206	4	5	3	2	0	-1	2	0	0	9.0	
i 1	459.99819727891156	1.01	72	908	6	5	5	2	0	1	2	0	0	9.0	
i 1	459.99891836734696	0.7575000000000001	75	206	5	9	5	2	0	1	2	0	0	2.0	
i 1	460.00612925170066	0.7575000000000001	74	592	4	4	1	2	0	-1	2	0	0	3.0	
i 1	460.01550340136055	1.2625	71	908	6	1	10	2	0	-1	2	0	0	4.0	
i 1	460.0169455782313	5.8075	60	592	6	17	12	5	0	1	5	0	0	5.188252614165814	
i 1	460.50612925170066	1.01	70	206	1	24	11	2	0	252	2	307	0	4.0	
i 1	460.7496394557823	1.01	71	592	5	3	12	8	0	-2	8	0	0	3.0	
i 1	460.7611768707483	1.01	71	206	3	4	10	2	0	-1	2	0	0	3.0	
i 1	460.98377551020405	0.2525	75	206	4	5	9	2	0	1	2	0	0	9.0	
i 1	460.99242857142855	0.2525	75	908	6	5	8	2	0	1	2	0	0	9.0	
i 1	461.23449659863945	3.0300000000000002	71	206	4	5	10	2	0	-1	2	0	0	9.0	
i 1	461.2539659863946	1.2625	71	592	4	1	7	8	0	-2	8	0	0	4.0	
i 1	461.2582925170068	1.2625	74	206	5	24	16	2	0	-2	2	0	0	5.0	
i 1	461.2640612244898	3.0300000000000002	72	908	6	5	3	2	0	1	2	0	0	9.0	
i 1	461.5082925170068	1.01	70	206	2	24	6	2	0	-1	2	0	0	4.0	
i 1	461.73521768707485	0.7575000000000001	71	908	4	2	7	8	0	-1	8	0	0	3.0	
i 1	461.76261904761907	0.7575000000000001	72	206	5	9	1	2	0	-2	2	0	0	2.0	
i 1	462.48954421768707	0.505	71	592	4	24	14	8	0	-2	8	0	0	5.0	
i 1	462.49314965986395	0.2525	71	592	5	3	4	8	0	-2	8	0	0	3.0	
i 1	462.49387074829934	0.505	77	206	5	1	16	17	0	1	17	0	0	4.0	
i 1	462.5090136054422	0.2525	71	206	3	4	16	2	0	-1	2	0	0	3.0	
i 1	462.7532448979592	0.2525	71	908	4	2	7	2	0	-2	2	0	0	3.0	
i 1	462.76478231292515	0.2525	71	206	3	3	15	8	0	-2	8	0	0	3.0	
i 1	462.98810204081633	1.5150000000000001	71	206	5	1	10	2	0	-1	2	0	0	4.0	
i 1	462.9960340136054	1.5150000000000001	71	908	6	1	10	2	0	-1	2	0	0	4.0	
i 1	463.0133401360544	0.2525	71	206	3	4	7	2	0	-1	2	0	0	3.0	
i 1	463.0133401360544	1.2625	70	206	2	24	5	2	0	-1	2	0	0	4.0	
i 1	463.01478231292515	0.2525	71	592	5	3	4	8	0	-2	8	0	0	3.0	
i 1	463.2359387755102	1.7675	71	908	4	2	2	2	0	-2	2	0	0	3.0	
i 1	463.25757142857145	1.7675	71	206	3	3	14	8	0	-2	8	0	0	3.0	
i 1	464.2323333333333	1.2625	75	908	6	5	12	2	0	1	2	0	0	9.0	
i 1	464.2445918367347	1.2625	75	206	4	5	9	2	0	1	2	0	0	9.0	
i 1	464.5003605442177	0.7575000000000001	77	206	5	1	13	17	0	1	17	0	0	4.0	
i 1	464.5054081632653	0.7575000000000001	71	592	4	24	6	8	0	-2	8	0	0	5.0	
i 1	465.0082925170068	0.7575000000000001	74	592	4	4	4	2	0	-1	2	0	0	3.0	
i 1	465.0111768707483	1.01	70	206	2	24	15	2	0	-1	2	0	0	4.0	
i 1	465.0133401360544	0.7575000000000001	75	206	5	9	5	2	0	1	2	0	0	2.0	
i 1	465.23954421768707	0.505	71	206	5	1	8	2	0	-1	2	0	0	4.0	
i 1	465.2453129251701	2.7775	71	908	6	1	15	2	0	-1	2	0	0	4.0	
i 1	465.4917074829932	0.2525	75	592	4	5	15	8	0	-2	8	0	0	9.0	
i 1	465.51622448979595	1.2625	75	206	4	5	8	2	0	1	2	0	0	9.0	
i 1	465.7546870748299	0.2525	71	592	4	3	12	8	0	-2	8	0	0	3.0	
i 1	465.75612925170066	1.01	75	592	6	5	11	8	0	-2	8	0	0	9.0	
i 1	465.75685034013605	0.2525	71	206	3	4	5	2	0	-1	2	0	0	3.0	
i 1	465.76045578231293	2.2725	71	206	4	1	3	2	0	-1	2	0	0	4.0	
i 1	465.7676666666667	5.8075	60	592	6	17	9	5	0	1	5	0	0	5.188252614165814	
i 1	465.9953129251701	0.2525	71	908	6	2	12	8	0	-1	8	0	0	3.0	
i 1	466.00252380952384	0.2525	72	206	5	9	8	2	0	-2	2	0	0	2.0	
i 1	466.24891836734696	0.2525	71	206	3	4	10	2	0	-1	2	0	0	3.0	
i 1	466.26045578231293	0.2525	71	592	4	3	12	8	0	-2	8	0	0	3.0	
i 1	466.4909863945578	0.7575000000000001	71	908	4	2	15	2	0	-2	2	0	0	3.0	
i 1	466.4953129251701	0.7575000000000001	71	206	4	3	16	8	0	-2	8	0	0	3.0	
i 1	466.7460340136054	1.01	72	908	6	5	12	2	0	1	2	0	0	9.0	
i 1	466.7467551020408	1.01	71	206	4	5	5	2	0	-1	2	0	0	9.0	
i 1	466.9917074829932	1.7675	70	206	2	24	11	2	0	-1	2	0	0	4.0	
i 1	467.25757142857145	1.01	71	206	3	4	14	2	0	-1	2	0	0	3.0	
i 1	467.26189795918367	1.01	71	592	4	3	12	8	0	-2	8	0	0	3.0	
i 1	467.7330544217687	0.2525	74	206	4	5	7	2	0	-2	2	0	0	9.0	
i 1	467.7445918367347	0.2525	75	592	4	5	9	2	0	1	2	0	0	9.0	
i 1	467.98521768707485	2.02	74	206	5	24	8	2	0	-2	2	0	0	5.0	
i 1	468.0032448979592	2.02	71	592	6	1	7	8	0	-2	8	0	0	4.0	
i 1	468.0054081632653	1.5150000000000001	71	206	4	5	12	2	0	-1	2	0	0	9.0	
i 1	468.0176666666667	1.5150000000000001	72	908	6	5	12	2	0	1	2	0	0	9.0	
i 1	468.23810204081633	1.01	71	206	4	3	3	8	0	-2	8	0	0	3.0	
i 1	468.2546870748299	1.01	71	908	4	2	15	2	0	-2	2	0	0	3.0	
i 1	468.75180272108844	0.2525	70	592	3	24	11	2	0	-1	2	0	0	4.0	
i 1	468.99242857142855	0.7575000000000001	70	206	2	24	15	2	0	-1	2	0	0	4.0	
i 1	468.99314965986395	3.0300000000000002	70	206	2	24	8	2	0	-1	2	0	0	4.0	
i 1	468.9967551020408	0.7575000000000001	71	206	3	24	11	1	0	0	1	0	0	4.0	
i 1	469.2409863945578	0.2525	75	206	5	9	11	2	0	1	2	0	0	2.0	
i 1	469.24819727891156	0.2525	74	592	4	4	8	2	0	-1	2	0	0	3.0	
i 1	469.48449659863945	0.2525	71	206	3	4	8	2	0	-1	2	0	0	3.0	
i 1	469.48521768707485	0.2525	71	592	4	3	2	8	0	-2	8	0	0	3.0	
i 1	469.48954421768707	1.5150000000000001	75	908	6	5	13	2	0	1	2	0	0	9.0	
i 1	469.50973469387753	1.5150000000000001	75	206	3	5	14	2	0	1	2	0	0	9.0	
i 1	469.7467551020408	0.7575000000000001	71	908	6	2	5	8	0	-1	8	0	0	3.0	
i 1	469.75252380952384	0.7575000000000001	72	206	5	9	10	2	0	-2	2	0	0	2.0	
i 1	470.0032448979592	0.7575000000000001	77	206	4	1	8	17	0	1	17	0	0	4.0	
i 1	470.0090136054422	0.7575000000000001	71	592	4	24	4	8	0	-2	8	0	0	5.0	
i 1	470.49387074829934	1.01	71	206	3	4	4	2	0	-1	2	0	0	3.0	
i 1	470.4960340136054	1.01	71	592	4	3	11	8	0	-2	8	0	0	3.0	
i 1	470.73521768707485	1.2625	71	206	4	1	10	2	0	-1	2	0	0	4.0	
i 1	470.75973469387753	0.7575000000000001	71	908	6	1	7	2	0	-1	2	0	0	4.0	
i 1	470.9967551020408	1.01	72	908	6	5	3	2	0	1	2	0	0	9.0	
i 1	471.00973469387753	1.01	71	206	4	5	10	2	0	-1	2	0	0	9.0	
i 1	471.48954421768707	0.505	61	206	5	18	5	6	0	1	6	0	0	5.188252614165814	
i 1	471.5003605442177	0.505	71	206	4	3	15	8	0	-2	8	0	0	3.0	
i 1	471.50757142857145	0.505	71	908	6	2	14	2	0	-2	2	0	0	3.0	
i 1	471.51261904761907	0.505	71	908	6	1	12	2	0	-1	2	0	0	4.0	
i 1	471.9823333333333	5.3025	60	1090	4	18	5	0	0	1	0	0	0	5.188252614165814	
i 1	471.98377551020405	1.7675	71	1090	6	1	8	2	0	-2	2	0	0	4.0	
i 1	471.98810204081633	5.3025	60	1090	4	18	10	0	0	0	0	0	0	5.188252614165814	
i 1	471.99387074829934	0.505	71	1090	6	2	8	2	0	-2	2	0	0	3.0	
i 1	471.99387074829934	1.2625	72	1090	3	5	15	2	0	1	2	0	0	9.0	
i 1	472.00180272108844	1.5150000000000001	70	276	2	24	6	2	0	-1	2	0	0	4.0	
i 1	472.0046870748299	0.505	71	1090	4	9	8	2	0	-1	2	0	0	2.0	
i 1	472.00612925170066	1.2625	75	1090	6	5	14	2	0	1	2	0	0	9.0	
i 1	472.00685034013605	16.9175	67	276	5	19	14	5	0	0	5	0	0	5.188252614165814	
i 1	472.00757142857145	11.11	60	276	5	19	7	0	0	1	0	0	0	5.188252614165814	
i 1	472.00973469387753	1.7675	71	1090	3	1	7	2	0	-1	2	0	0	4.0	
i 1	472.49314965986395	0.2525	71	276	4	4	16	2	0	-2	2	0	0	3.0	
i 1	472.51622448979595	0.2525	74	592	4	4	5	2	0	-1	2	0	0	3.0	
i 1	472.73521768707485	0.7575000000000001	74	276	4	3	14	8	0	-2	8	0	0	3.0	
i 1	472.75685034013605	0.7575000000000001	73	1090	2	24	8	2	0	-2	2	0	0	4.0	
i 1	472.7590136054422	0.7575000000000001	71	592	4	3	4	8	0	-2	8	0	0	3.0	
i 1	473.2460340136054	1.01	72	276	3	5	1	2	0	-2	2	0	0	9.0	
i 1	473.2669455782313	1.01	75	592	6	5	9	8	0	-2	8	0	0	9.0	
i 1	473.48521768707485	1.01	74	1090	4	9	11	2	0	-1	2	0	0	2.0	
i 1	473.51550340136055	1.01	71	1090	6	2	3	8	0	-1	8	0	0	3.0	
i 1	473.74026530612247	2.2725	71	276	4	1	14	8	0	-1	8	0	0	4.0	
i 1	473.74891836734696	1.01	73	1090	2	24	7	2	0	-2	2	0	0	4.0	
i 1	473.7669455782313	2.2725	71	592	6	1	13	8	0	-2	8	0	0	4.0	
i 1	474.2539659863946	0.2525	72	1090	3	5	8	2	0	1	2	0	0	9.0	
i 1	474.26189795918367	0.2525	75	1090	6	5	9	2	0	1	2	0	0	9.0	
i 1	474.48377551020405	1.5150000000000001	75	276	3	5	5	2	0	-2	2	0	0	9.0	
i 1	474.4888231292517	0.7575000000000001	74	276	4	3	6	8	0	-2	8	0	0	3.0	
i 1	474.49387074829934	0.7575000000000001	71	592	4	3	14	8	0	-2	8	0	0	3.0	
i 1	474.4953129251701	1.5150000000000001	75	592	6	5	2	2	0	1	2	0	0	9.0	
i 1	474.7611768707483	1.01	70	276	2	24	7	2	0	-1	2	0	0	4.0	
i 1	475.01478231292515	0.7575000000000001	73	1090	2	24	9	2	0	-2	2	0	0	4.0	
i 1	475.2467551020408	0.2525	71	1090	6	2	16	2	0	-2	2	0	0	3.0	
i 1	475.26189795918367	0.2525	71	1090	4	9	7	2	0	-1	2	0	0	2.0	
i 1	475.4945918367347	0.2525	74	276	4	3	13	8	0	-2	8	0	0	3.0	
i 1	475.49747619047616	0.2525	71	592	4	3	13	8	0	-2	8	0	0	3.0	
i 1	475.75180272108844	1.7675	70	276	1	24	12	2	0	248	2	308	0	4.0	
i 1	475.75757142857145	1.01	71	1090	4	9	12	2	0	-1	2	0	0	2.0	
i 1	475.76189795918367	1.01	71	1090	6	2	2	2	0	-2	2	0	0	3.0	
i 1	475.98449659863945	2.7775	75	1090	6	5	10	2	0	1	2	0	0	9.0	
i 1	475.9859387755102	1.5150000000000001	71	592	4	24	3	8	0	-2	8	0	0	5.0	
i 1	475.99819727891156	1.5150000000000001	71	276	4	24	11	8	0	-1	8	0	0	5.0	
i 1	476.01189795918367	2.7775	72	1090	3	5	10	2	0	1	2	0	0	9.0	
i 1	476.23954421768707	2.2725	73	276	1	24	5	2	0	252	2	307	0	4.0	
i 1	476.2611768707483	1.2625	73	1090	2	24	15	2	0	-2	2	0	0	4.0	
i 1	476.75685034013605	1.01	74	592	4	4	3	2	0	-1	2	0	0	3.0	
i 1	476.76622448979595	1.01	71	276	4	4	7	2	0	-2	2	0	0	3.0	
i 1	477.25973469387753	5.8075	60	1090	4	18	7	0	0	1	0	0	0	5.188252614165814	
i 1	477.48954421768707	1.5150000000000001	70	276	2	24	5	2	0	-1	2	0	0	4.0	
i 1	477.4909863945578	0.505	71	1090	3	1	11	2	0	-1	2	0	0	4.0	
i 1	477.50757142857145	0.505	71	1090	6	1	13	2	0	-2	2	0	0	4.0	
i 1	477.7532448979592	0.7575000000000001	71	592	5	3	3	8	0	-2	8	0	0	3.0	
i 1	477.7640612244898	0.7575000000000001	74	276	4	3	6	8	0	-2	8	0	0	3.0	
i 1	477.9945918367347	0.7575000000000001	71	592	4	24	16	8	0	-2	8	0	0	5.0	
i 1	478.01045578231293	0.7575000000000001	71	276	4	24	1	8	0	-1	8	0	0	5.0	
i 1	478.49387074829934	0.2525	71	1090	6	2	10	8	0	-1	8	0	0	3.0	
i 1	478.51478231292515	0.2525	74	1090	3	9	10	2	0	-1	2	0	0	2.0	
i 1	478.7445918367347	2.2725	72	1090	5	5	14	2	0	1	2	0	0	9.0	
i 1	478.74891836734696	2.7775	71	1090	3	1	7	2	0	-1	2	0	0	4.0	
i 1	478.75180272108844	2.7775	71	1090	6	1	8	2	0	-2	2	0	0	4.0	
i 1	478.75180272108844	0.2525	71	592	5	3	1	8	0	-2	8	0	0	3.0	
i 1	478.7554081632653	2.2725	75	1090	6	5	7	2	0	1	2	0	0	9.0	
i 1	478.76478231292515	0.2525	74	276	4	3	12	8	0	-2	8	0	0	3.0	
i 1	478.9953129251701	0.2525	71	1090	4	9	5	2	0	-1	2	0	0	2.0	
i 1	478.9967551020408	0.2525	71	1090	6	2	8	2	0	-2	2	0	0	3.0	
i 1	478.99819727891156	0.7575000000000001	70	276	1	24	9	2	0	248	2	308	0	4.0	
i 1	479.01261904761907	0.7575000000000001	73	1090	2	24	9	2	0	-2	2	0	0	4.0	
i 1	479.2417074829932	0.7575000000000001	74	276	4	3	1	8	0	-2	8	0	0	3.0	
i 1	479.2453129251701	0.7575000000000001	71	592	5	3	9	8	0	-2	8	0	0	3.0	
i 1	479.75612925170066	1.01	73	1090	1	24	7	2	0	252	2	307	0	4.0	
i 1	479.76478231292515	0.505	70	276	2	24	8	2	0	-1	2	0	0	4.0	
i 1	479.98449659863945	1.7675	71	1090	6	2	11	2	0	-2	2	0	0	3.0	
i 1	479.98738095238093	1.7675	71	1090	4	9	12	2	0	-1	2	0	0	2.0	
i 1	480.7582925170068	0.2525	73	1090	2	24	3	2	0	-2	2	0	0	4.0	
i 1	481.0082925170068	1.01	70	276	2	24	10	2	0	-1	2	0	0	4.0	
i 1	481.0169455782313	0.2525	75	1090	6	5	8	2	0	1	2	0	0	9.0	
i 1	481.0169455782313	0.2525	72	1090	3	5	7	2	0	1	2	0	0	9.0	
i 1	481.2359387755102	0.7575000000000001	73	276	1	24	14	8	0	248	8	308	0	4.0	
i 1	481.24891836734696	1.5150000000000001	75	592	6	5	11	8	0	-2	8	0	0	9.0	
i 1	481.2611768707483	1.5150000000000001	72	276	3	5	12	2	0	-2	2	0	0	9.0	
i 1	481.48738095238093	2.02	71	276	3	1	4	8	0	-1	8	0	0	4.0	
i 1	481.5090136054422	2.02	71	592	6	1	16	8	0	-2	8	0	0	4.0	
i 1	481.73377551020405	0.2525	74	592	4	4	9	2	0	-1	2	0	0	3.0	
i 1	481.75108163265304	0.2525	71	276	4	4	4	2	0	-2	2	0	0	3.0	
i 1	481.9823333333333	0.2525	71	592	5	3	6	8	0	-2	8	0	0	3.0	
i 1	482.0003605442177	0.2525	74	276	4	3	11	8	0	-2	8	0	0	3.0	
i 1	482.24242857142855	0.2525	71	1090	6	2	13	8	0	-1	8	0	0	3.0	
i 1	482.2611768707483	0.2525	74	1090	3	9	6	2	0	-1	2	0	0	2.0	
i 1	482.26261904761907	1.2625	70	276	2	24	16	2	0	-1	2	0	0	4.0	
i 1	482.4859387755102	0.7575000000000001	74	276	4	3	16	8	0	-2	8	0	0	3.0	
i 1	482.49819727891156	0.7575000000000001	71	592	5	3	2	8	0	-2	8	0	0	3.0	
i 1	482.7388231292517	1.5150000000000001	72	1090	5	5	4	2	0	1	2	0	0	9.0	
i 1	482.7417074829932	1.5150000000000001	75	1090	6	5	7	2	0	1	2	0	0	9.0	
i 1	482.9866598639456	5.8075	60	276	5	19	4	0	0	1	0	0	0	5.188252614165814	
i 1	483.25108163265304	1.01	71	1090	3	9	6	2	0	-1	2	0	0	2.0	
i 1	483.25252380952384	1.01	71	1090	6	2	10	2	0	-2	2	0	0	3.0	
i 1	483.49819727891156	0.7575000000000001	71	592	4	24	2	8	0	-2	8	0	0	5.0	
i 1	483.4996394557823	0.7575000000000001	71	276	3	24	9	8	0	-1	8	0	0	5.0	
i 1	484.2366598639456	0.7575000000000001	71	592	5	3	11	8	0	-2	8	0	0	3.0	
i 1	484.2496394557823	1.2625	75	592	6	5	10	2	0	1	2	0	0	9.0	
i 1	484.25180272108844	0.7575000000000001	71	1090	5	1	1	2	0	-1	2	0	0	4.0	
i 1	484.25180272108844	0.7575000000000001	74	276	4	3	14	8	0	-2	8	0	0	3.0	
i 1	484.26045578231293	1.2625	75	276	3	5	3	2	0	-2	2	0	0	9.0	
i 1	484.26550340136055	1.7675	70	276	2	24	13	2	0	-1	2	0	0	4.0	
i 1	484.2676666666667	0.7575000000000001	71	1090	6	1	9	2	0	-2	2	0	0	4.0	
i 1	484.4909863945578	0.2525	71	1090	6	2	15	8	0	-1	8	0	0	3.0	
i 1	484.4967551020408	0.2525	71	276	3	1	5	8	0	-1	8	0	0	4.0	
i 1	484.74026530612247	0.7575000000000001	71	1090	3	9	4	2	0	-1	2	0	0	2.0	
i 1	484.7539659863946	1.5150000000000001	71	592	4	24	11	8	0	-2	8	0	0	5.0	
i 1	484.7546870748299	1.5150000000000001	71	276	3	24	16	8	0	-1	8	0	0	5.0	
i 1	484.9830544217687	0.505	71	1090	6	2	10	2	0	-2	2	0	0	3.0	
i 1	485.00252380952384	0.2525	72	1090	5	5	7	2	0	1	2	0	0	9.0	
i 1	485.2366598639456	0.2525	71	592	6	1	4	8	0	-2	8	0	0	4.0	
i 1	485.23810204081633	2.525	72	1090	5	5	3	2	0	1	2	0	0	9.0	
i 1	485.2388231292517	0.505	71	276	4	4	9	2	0	-2	2	0	0	3.0	
i 1	485.2640612244898	0.505	74	592	4	4	7	2	0	-1	2	0	0	3.0	
i 1	485.4967551020408	0.2525	71	1090	6	1	16	8	0	-1	8	0	0	4.0	
i 1	485.5039659863946	2.2725	75	1090	6	5	15	2	0	1	2	0	0	9.0	
i 1	485.73521768707485	0.2525	75	592	6	5	11	2	0	1	2	0	0	9.0	
i 1	485.74314965986395	1.01	71	592	5	3	3	8	0	-2	8	0	0	3.0	
i 1	485.74891836734696	0.2525	71	1090	6	2	2	8	0	-1	8	0	0	3.0	
i 1	485.75180272108844	1.01	74	276	4	3	1	8	0	-2	8	0	0	3.0	
i 1	485.9866598639456	0.2525	71	276	4	4	5	2	0	-2	2	0	0	3.0	
i 1	486.0003605442177	0.2525	71	276	3	1	15	8	0	-1	8	0	0	4.0	
i 1	486.2417074829932	0.505	70	592	1	24	9	2	0	-2	2	0	0	4.0	
i 1	486.24387074829934	3.0300000000000002	71	1090	6	1	3	2	0	-2	2	0	0	4.0	
i 1	486.2503605442177	3.0300000000000002	71	1090	5	1	15	2	0	-1	2	0	0	4.0	
i 1	486.2532448979592	0.2525	74	592	4	4	10	2	0	-1	2	0	0	3.0	
i 1	486.26261904761907	1.01	70	276	2	24	4	2	0	-1	2	0	0	4.0	
i 1	486.50180272108844	0.2525	71	1090	6	1	8	8	0	-1	8	0	0	4.0	
i 1	486.5039659863946	1.2625	71	1090	6	2	3	8	0	-1	8	0	0	3.0	
i 1	486.50973469387753	1.2625	74	1090	3	9	13	2	0	-1	2	0	0	2.0	
i 1	486.7633401360544	0.2525	71	276	3	1	3	8	0	-1	8	0	0	4.0	
i 1	486.9960340136054	0.2525	73	592	1	24	10	2	0	-2	2	0	0	4.0	
i 1	487.2330544217687	1.01	74	276	4	3	14	8	0	-2	8	0	0	3.0	
i 1	487.2417074829932	1.01	71	592	5	3	16	8	0	-2	8	0	0	3.0	
i 1	487.48377551020405	3.0300000000000002	70	276	2	24	1	2	0	-1	2	0	0	4.0	
i 1	487.48810204081633	0.2525	71	276	3	24	8	8	0	-1	8	0	0	5.0	
i 1	487.50108163265304	0.2525	70	592	1	24	8	2	0	-2	2	0	0	4.0	
i 1	487.51622448979595	2.02	72	1090	5	5	6	2	0	1	2	0	0	9.0	
i 1	487.7460340136054	1.01	75	1090	6	5	14	2	0	1	2	0	0	9.0	
i 1	487.74891836734696	0.2525	74	592	4	4	8	2	0	-1	2	0	0	3.0	
i 1	487.7669455782313	0.2525	75	592	6	5	7	2	0	1	2	0	0	9.0	
i 1	488.00612925170066	0.2525	71	1090	6	2	8	8	0	-1	8	0	0	3.0	
i 1	488.24026530612247	0.2525	71	276	3	1	8	8	0	-1	8	0	0	4.0	
i 1	488.25685034013605	0.2525	71	1090	3	9	12	2	0	-1	2	0	0	2.0	
i 1	488.48954421768707	0.2525	71	592	4	24	1	8	0	-2	8	0	0	5.0	
i 1	488.50685034013605	0.505	71	592	5	3	4	8	0	-2	8	0	0	3.0	
i 1	488.50685034013605	0.2525	74	592	4	4	14	2	0	-1	2	0	0	3.0	
i 1	488.73738095238093	0.2525	74	276	3	3	14	8	0	-2	8	0	0	3.0	
i 1	488.7417074829932	1.2625	71	1090	3	9	14	2	0	-1	2	0	0	2.0	
i 1	488.74242857142855	1.2625	71	1090	6	2	5	2	0	-2	2	0	0	3.0	
i 1	488.74387074829934	0.7575000000000001	75	1090	6	5	6	2	0	1	2	0	0	9.0	
i 1	488.7453129251701	0.2525	74	1090	6	1	10	2	0	-1	2	0	0	4.0	
i 1	488.75180272108844	5.8075	67	276	5	19	10	5	0	0	5	0	0	5.188252614165814	
i 1	488.7640612244898	14.645	67	1090	6	17	5	5	0	0	5	0	0	5.188252614165814	
i 1	488.9830544217687	1.5150000000000001	71	276	5	1	4	8	0	-1	8	0	0	4.0	
i 1	488.99819727891156	1.5150000000000001	71	592	6	1	7	8	0	-2	8	0	0	4.0	
i 1	488.99891836734696	0.2525	75	276	3	5	9	2	0	-2	2	0	0	9.0	
i 1	489.2453129251701	0.2525	71	592	5	3	5	8	0	-2	8	0	0	3.0	
i 1	489.2496394557823	2.2725	75	1090	6	5	15	2	0	1	2	0	0	9.0	
i 1	489.25252380952384	2.02	72	1090	5	5	9	2	0	1	2	0	0	9.0	
i 1	489.4945918367347	1.5150000000000001	71	276	4	4	7	2	0	-2	2	0	0	3.0	
i 1	489.4967551020408	0.2525	71	1090	6	1	16	8	0	-1	8	0	0	4.0	
i 1	489.5140612244898	1.5150000000000001	74	592	4	4	15	2	0	-1	2	0	0	3.0	
i 1	489.76045578231293	0.2525	74	1090	6	1	3	2	0	-1	2	0	0	4.0	
i 1	489.99891836734696	0.2525	70	592	1	24	14	8	0	-1	8	0	0	4.0	
i 1	490.01189795918367	0.2525	75	1090	6	5	3	2	0	1	2	0	0	9.0	
i 1	490.2359387755102	0.2525	72	1090	5	5	16	2	0	1	2	0	0	9.0	
i 1	490.24387074829934	0.2525	71	1090	3	9	14	2	0	-1	2	0	0	2.0	
i 1	490.2460340136054	1.7675	71	276	3	24	12	8	0	-1	8	0	0	5.0	
i 1	490.2633401360544	1.7675	71	592	4	24	5	8	0	-2	8	0	0	5.0	
i 1	490.4830544217687	2.525	71	592	5	3	8	8	0	-2	8	0	0	3.0	
i 1	490.4953129251701	2.525	74	276	3	3	14	8	0	-2	8	0	0	3.0	
i 1	490.5003605442177	0.505	75	592	6	5	12	2	0	1	2	0	0	9.0	
i 1	490.5054081632653	0.2525	74	1090	6	1	12	2	0	-1	2	0	0	4.0	
i 1	490.7388231292517	3.7875	70	276	2	24	13	2	0	-1	2	0	0	4.0	
i 1	490.74242857142855	0.2525	71	1090	6	1	6	8	0	-1	8	0	0	4.0	
i 1	490.9909863945578	1.5150000000000001	72	276	5	5	4	2	0	-2	2	0	0	9.0	
i 1	491.0046870748299	0.505	71	276	5	1	1	8	0	-1	8	0	0	4.0	
i 1	491.01045578231293	1.7675	75	592	6	5	16	8	0	-2	8	0	0	9.0	
i 1	491.0140612244898	0.2525	73	592	1	24	2	2	0	-1	2	0	0	4.0	
i 1	491.2669455782313	0.2525	71	1090	3	9	7	2	0	-1	2	0	0	2.0	
i 1	491.48377551020405	1.2625	71	1090	6	1	4	2	0	-2	2	0	0	4.0	
i 1	491.4953129251701	1.2625	71	1090	5	1	8	2	0	-1	2	0	0	4.0	
i 1	491.49891836734696	0.505	71	1090	6	2	2	8	0	-1	8	0	0	3.0	
i 1	491.50180272108844	0.505	74	1090	5	9	4	2	0	-1	2	0	0	2.0	
i 1	491.50252380952384	0.2525	75	592	6	5	10	2	0	1	2	0	0	9.0	
i 1	491.7453129251701	0.7575000000000001	71	1090	3	9	14	2	0	-1	2	0	0	2.0	
i 1	491.75612925170066	0.2525	75	1090	6	5	16	2	0	1	2	0	0	9.0	
i 1	491.76189795918367	0.7575000000000001	71	1090	6	2	5	2	0	-2	2	0	0	3.0	
i 1	491.9917074829932	0.2525	71	592	6	1	7	8	0	-2	8	0	0	4.0	
i 1	491.99891836734696	1.7675	72	1090	5	5	9	2	0	1	2	0	0	9.0	
i 1	492.00612925170066	1.7675	75	1090	6	5	16	2	0	1	2	0	0	9.0	
i 1	492.2460340136054	2.2725	71	592	4	24	11	8	0	-2	8	0	0	5.0	
i 1	492.2496394557823	2.2725	71	276	3	24	8	8	0	-1	8	0	0	5.0	
i 1	492.50108163265304	0.2525	74	592	4	4	1	2	0	-1	2	0	0	3.0	
i 1	492.73954421768707	0.2525	74	1090	6	1	9	2	0	-1	2	0	0	4.0	
i 1	492.75252380952384	1.7675	71	1090	3	9	2	2	0	-1	2	0	0	2.0	
i 1	492.75612925170066	1.7675	71	1090	6	2	12	2	0	-2	2	0	0	3.0	
i 1	492.76045578231293	0.2525	72	276	5	5	10	2	0	-2	2	0	0	9.0	
i 1	492.9909863945578	0.2525	74	592	4	4	13	2	0	-1	2	0	0	3.0	
i 1	492.99891836734696	0.2525	71	276	5	1	6	8	0	-1	8	0	0	4.0	
i 1	493.23810204081633	1.2625	75	592	6	5	9	2	0	1	2	0	0	9.0	
i 1	493.24819727891156	0.2525	74	276	3	3	14	8	0	-2	8	0	0	3.0	
i 1	493.2611768707483	1.2625	75	276	3	5	11	2	0	-2	2	0	0	9.0	
i 1	493.48738095238093	2.525	71	1090	6	1	15	2	0	-2	2	0	0	4.0	
i 1	493.49314965986395	1.01	71	1090	5	1	13	2	0	-1	2	0	0	4.0	
i 1	493.5003605442177	0.505	71	592	5	3	10	8	0	-2	8	0	0	3.0	
i 1	493.7532448979592	0.2525	75	592	6	5	10	8	0	-2	8	0	0	9.0	
i 1	494.0090136054422	2.525	72	1090	5	5	16	2	0	1	2	0	0	9.0	
i 1	494.0169455782313	0.505	75	1090	6	5	6	2	0	1	2	0	0	9.0	
i 1	494.2409863945578	0.2525	74	1090	5	9	3	2	0	-1	2	0	0	2.0	
i 1	494.48738095238093	1.7675	71	1090	6	1	15	2	0	-1	2	0	0	4.0	
i 1	494.48810204081633	0.7575000000000001	75	276	5	5	10	2	0	-2	2	0	0	9.0	
i 1	494.4967551020408	0.505	71	1090	6	2	14	2	0	-2	2	0	0	3.0	
i 1	494.4967551020408	1.01	71	276	3	4	9	2	0	-2	2	0	0	3.0	
i 1	494.5039659863946	0.505	71	1090	6	1	2	8	0	-1	8	0	0	4.0	
i 1	494.5054081632653	1.01	74	592	4	4	11	2	0	-1	2	0	0	3.0	
i 1	494.50973469387753	0.2525	71	592	6	1	16	8	0	-2	8	0	0	4.0	
i 1	494.51261904761907	8.8375	67	1090	5	14	1	5	0	1	5	0	0	0.9278044669337066	
i 1	494.51261904761907	0.505	71	1090	5	9	14	2	0	-1	2	0	0	2.0	
i 1	494.51550340136055	0.2525	75	592	6	5	5	2	0	1	2	0	0	9.0	
i 1	494.5169455782313	2.02	75	1090	6	5	7	2	0	1	2	0	0	9.0	
i 1	494.5176666666667	8.8375	60	1090	6	17	10	5	0	0	5	0	0	5.188252614165814	
i 1	494.7330544217687	1.7675	74	276	3	3	2	8	0	-2	8	0	0	3.0	
i 1	494.74891836734696	1.7675	71	592	5	3	12	8	0	-2	8	0	0	3.0	
i 1	495.0082925170068	1.01	71	1090	6	2	3	8	0	-1	8	0	0	3.0	
i 1	495.01189795918367	0.505	71	276	5	24	7	8	0	-1	8	0	0	5.0	
i 1	495.01622448979595	1.01	74	1090	5	9	7	2	0	-1	2	0	0	2.0	
i 1	495.2359387755102	0.2525	75	592	6	5	14	8	0	-2	8	0	0	9.0	
i 1	495.24314965986395	0.505	72	1090	5	5	8	2	0	1	2	0	0	9.0	
i 1	495.4830544217687	2.7775	71	276	5	1	7	8	0	-1	8	0	0	4.0	
i 1	495.5082925170068	0.2525	75	276	5	5	15	2	0	-2	2	0	0	9.0	
i 1	495.50973469387753	2.7775	71	592	6	1	5	8	0	-2	8	0	0	4.0	
i 1	495.51622448979595	0.2525	73	592	1	24	5	2	0	-1	2	0	0	4.0	
i 1	495.73377551020405	3.535	75	1090	6	5	10	2	0	1	2	0	0	9.0	
i 1	495.7640612244898	1.7675	71	1090	6	2	2	2	0	-2	2	0	0	3.0	
i 1	495.76478231292515	1.7675	71	1090	5	9	1	2	0	-1	2	0	0	2.0	
i 1	495.98810204081633	4.04	72	1090	5	5	11	2	0	1	2	0	0	9.0	
i 1	496.2445918367347	0.2525	71	276	5	24	5	8	0	-1	8	0	0	5.0	
i 1	496.4830544217687	0.2525	74	1090	6	1	9	2	0	-1	2	0	0	4.0	
i 1	496.49387074829934	0.2525	71	1090	6	1	9	2	0	-1	2	0	0	4.0	
i 1	496.49387074829934	0.2525	72	276	5	5	2	2	0	-2	2	0	0	9.0	
i 1	496.5039659863946	0.2525	71	1090	6	2	3	8	0	-1	8	0	0	3.0	
i 1	496.73449659863945	0.2525	75	592	6	5	16	2	0	1	2	0	0	9.0	
i 1	496.75252380952384	0.2525	70	592	1	24	11	2	0	-1	2	0	0	4.0	
i 1	496.7633401360544	0.2525	71	276	3	4	8	2	0	-2	2	0	0	3.0	
i 1	496.9823333333333	1.2625	74	276	3	3	1	8	0	-2	8	0	0	3.0	
i 1	496.9859387755102	0.2525	71	276	5	24	12	8	0	-1	8	0	0	5.0	
i 1	496.98738095238093	1.2625	71	592	5	3	6	8	0	-2	8	0	0	3.0	
i 1	496.98954421768707	4.04	71	592	4	24	10	8	0	-2	8	0	0	5.0	
i 1	496.9917074829932	2.02	70	276	1	24	1	8	0	252	8	307	0	4.0	
i 1	497.4888231292517	3.535	71	276	5	24	10	8	0	-1	8	0	0	5.0	
i 1	497.48954421768707	0.2525	71	1090	6	2	5	8	0	-1	8	0	0	3.0	
i 1	497.50612925170066	0.2525	74	592	4	4	16	2	0	-1	2	0	0	3.0	
i 1	497.73954421768707	1.01	71	1090	6	2	6	2	0	-2	2	0	0	3.0	
i 1	497.7532448979592	1.01	71	1090	5	9	8	2	0	-1	2	0	0	2.0	
i 1	498.0111768707483	1.01	74	592	4	4	2	2	0	-1	2	0	0	3.0	
i 1	498.0111768707483	1.2625	71	276	3	4	8	2	0	-2	2	0	0	3.0	
i 1	498.25108163265304	0.2525	71	1090	6	1	16	8	0	-1	8	0	0	4.0	
i 1	498.4830544217687	1.2625	74	276	3	3	5	8	0	-2	8	0	0	3.0	
i 1	498.48521768707485	0.2525	75	592	6	5	9	2	0	1	2	0	0	9.0	
i 1	498.4953129251701	1.2625	71	592	5	3	5	8	0	-2	8	0	0	3.0	
i 1	498.5111768707483	0.505	71	592	6	1	14	8	0	-2	8	0	0	4.0	
i 1	498.51550340136055	0.2525	71	1090	6	1	12	2	0	-1	2	0	0	4.0	
i 1	498.73738095238093	2.02	72	1090	5	5	12	2	0	1	2	0	0	9.0	
i 1	498.7388231292517	0.2525	71	1090	6	1	7	8	0	-1	8	0	0	4.0	
i 1	498.73954421768707	2.02	75	1090	6	5	3	2	0	1	2	0	0	9.0	
i 1	498.98954421768707	4.2925	71	1090	6	1	5	2	0	-2	2	0	0	4.0	
i 1	498.9909863945578	5.3025	71	1090	6	1	10	2	0	-1	2	0	0	4.0	
i 1	499.00757142857145	0.2525	73	592	1	24	9	8	0	-2	8	0	0	4.0	
i 1	499.2417074829932	1.7675	71	1090	6	2	9	8	0	-1	8	0	0	3.0	
i 1	499.26261904761907	1.7675	74	1090	5	9	11	2	0	-1	2	0	0	2.0	
i 1	499.2633401360544	0.2525	75	592	6	5	1	8	0	-2	8	0	0	9.0	
i 1	499.74387074829934	0.2525	74	592	4	4	13	2	0	-1	2	0	0	3.0	
i 1	499.7496394557823	0.505	71	276	3	4	16	2	0	-2	2	0	0	3.0	
i 1	499.7640612244898	2.02	72	276	5	5	8	2	0	-2	2	0	0	9.0	
i 1	499.98377551020405	0.2525	74	276	3	3	13	8	0	-2	8	0	0	3.0	
i 1	500.0133401360544	0.2525	75	592	6	5	16	8	0	-2	8	0	0	9.0	
i 1	500.24387074829934	16.16	60	592	6	17	8	5	0	1	5	0	0	5.188252614165814	
i 1	500.2467551020408	2.02	71	592	5	3	8	8	0	-2	8	0	0	3.0	
i 1	500.2611768707483	1.5150000000000001	75	592	6	5	4	8	0	-2	8	0	0	9.0	
i 1	500.2640612244898	2.02	74	276	5	3	16	8	0	-2	8	0	0	3.0	
i 1	500.7445918367347	3.7875	71	1090	5	9	6	2	0	-1	2	0	0	2.0	
i 1	500.74747619047616	1.2625	72	1090	6	5	14	2	0	1	2	0	0	9.0	
i 1	500.75180272108844	2.525	71	1090	6	2	6	2	0	-2	2	0	0	3.0	
i 1	500.7532448979592	1.7675	75	1090	6	5	15	2	0	1	2	0	0	9.0	
i 1	500.9823333333333	2.525	75	592	6	5	16	2	0	1	2	0	0	9.0	
i 1	500.98738095238093	0.2525	71	276	7	1	16	8	0	-1	8	0	0	4.0	
i 1	500.99387074829934	2.2725	75	276	5	5	16	2	0	-2	2	0	0	9.0	
i 1	500.99891836734696	0.2525	74	1090	6	1	7	2	0	-1	2	0	0	4.0	
i 1	501.24026530612247	0.2525	71	276	5	24	12	8	0	-1	8	0	0	5.0	
i 1	501.2640612244898	0.2525	71	592	4	24	4	8	0	-2	8	0	0	5.0	
i 1	502.0039659863946	0.505	73	592	1	24	11	8	0	-2	8	0	0	4.0	
i 1	502.23521768707485	1.01	71	276	3	4	13	2	0	-2	2	0	0	3.0	
i 1	502.2359387755102	0.2525	71	276	7	1	3	8	0	-1	8	0	0	4.0	
i 1	502.23810204081633	1.5150000000000001	74	592	4	4	11	2	0	-1	2	0	0	3.0	
i 1	502.23810204081633	0.2525	75	592	6	5	11	8	0	-2	8	0	0	9.0	
i 1	502.4859387755102	0.2525	74	1090	6	1	14	2	0	-1	2	0	0	4.0	
i 1	502.5046870748299	0.7575000000000001	75	1090	6	5	4	2	0	1	2	0	0	9.0	
i 1	502.51261904761907	0.7575000000000001	71	276	5	24	8	8	0	-1	8	0	0	5.0	
i 1	502.51478231292515	3.535	72	1090	5	5	9	2	0	1	2	0	0	9.0	
i 1	502.7366598639456	2.525	71	592	6	1	9	8	0	-2	8	0	0	4.0	
i 1	502.74387074829934	0.505	75	1090	6	5	14	2	0	1	2	0	0	9.0	
i 1	502.7496394557823	0.505	71	1090	6	2	6	8	0	-1	8	0	0	3.0	
i 1	502.76045578231293	0.2525	73	592	1	24	1	2	0	-1	2	0	0	4.0	
i 1	503.23954421768707	2.02	74	388	4	24	15	2	5001	-1	2	0	0	5.0	
i 1	503.23954421768707	3.0300000000000002	72	704	6	5	14	2	0	-2	2	0	0	9.0	
i 1	503.2453129251701	14.3925	60	704	6	17	4	0	0	1	0	0	0	5.188252614165814	
i 1	503.24747619047616	14.3925	67	704	6	17	16	0	0	1	0	0	0	5.188252614165814	
i 1	503.24891836734696	14.3925	60	704	5	14	5	5	0	0	5	0	0	0.9278044669337066	
i 1	503.25685034013605	1.2625	71	704	6	2	1	8	0	-2	8	0	0	3.0	
i 1	503.26045578231293	0.7575000000000001	75	704	6	5	14	2	0	1	2	0	0	9.0	
i 1	503.2633401360544	2.02	74	388	3	4	2	2	5001	-1	2	0	0	3.0	
i 1	503.26550340136055	0.7575000000000001	74	704	6	1	10	2	0	-2	2	0	0	4.0	
i 1	503.2669455782313	0.2525	75	388	5	5	3	8	5001	1	8	0	0	9.0	
i 1	503.51261904761907	1.7675	71	592	5	3	10	8	0	-2	8	0	0	3.0	
i 1	503.51622448979595	0.2525	72	1090	6	5	15	2	0	1	2	0	0	9.0	
i 1	503.75757142857145	3.2825	74	388	5	3	10	8	5001	-2	8	0	0	3.0	
i 1	503.76550340136055	3.2825	71	704	6	2	8	2	0	-2	2	0	0	3.0	
i 1	503.9960340136054	0.505	75	592	6	5	9	8	0	-2	8	0	0	9.0	
i 1	504.0176666666667	0.2525	74	704	6	1	4	2	0	-1	2	0	0	4.0	
i 1	504.2330544217687	2.7775	71	592	4	24	8	8	0	-2	8	0	0	5.0	
i 1	504.2503605442177	3.0300000000000002	74	1090	6	1	6	2	0	-1	2	0	0	4.0	
i 1	504.49747619047616	0.505	75	704	6	5	14	2	0	1	2	0	0	9.0	
i 1	504.7323333333333	6.0600000000000005	74	388	6	1	14	8	5001	-1	8	0	0	4.0	
i 1	504.7582925170068	1.2625	74	704	6	1	9	2	0	-2	2	0	0	4.0	
i 1	504.99026530612247	0.2525	75	592	6	5	6	2	0	1	2	0	0	9.0	
i 1	505.0054081632653	2.2725	75	388	5	5	9	8	5001	1	8	0	0	9.0	
i 1	505.2366598639456	2.02	75	704	6	5	5	2	0	1	2	0	0	9.0	
i 1	505.2496394557823	0.2525	74	592	4	4	3	2	0	-1	2	0	0	3.0	
i 1	505.2676666666667	0.505	71	1090	5	9	12	2	0	-1	2	0	0	2.0	
i 1	505.50973469387753	0.2525	74	1090	5	9	15	2	0	-1	2	0	0	2.0	
i 1	505.7445918367347	0.2525	74	388	3	4	13	2	5001	-1	2	0	0	3.0	
i 1	505.74747619047616	0.2525	73	592	1	24	9	2	0	-2	2	0	0	4.0	
i 1	505.76622448979595	0.2525	71	592	5	3	7	8	0	-2	8	0	0	3.0	
i 1	505.98521768707485	1.7675	74	1090	5	9	6	2	0	-1	2	0	0	2.0	
i 1	505.9866598639456	0.505	70	388	1	24	7	2	0	252	2	307	0	4.0	
i 1	505.99314965986395	0.2525	72	1090	6	5	6	2	0	1	2	0	0	9.0	
i 1	505.99387074829934	1.7675	74	592	4	4	5	2	0	-1	2	0	0	3.0	
i 1	505.9996394557823	10.352500000000001	60	592	6	17	3	5	0	1	5	0	0	5.188252614165814	
i 1	506.0039659863946	4.7975	74	704	6	1	14	2	0	-2	2	0	0	4.0	
i 1	506.24242857142855	1.2625	75	388	5	5	3	8	5001	1	8	0	0	9.0	
i 1	506.26478231292515	1.7675	75	592	6	5	4	8	0	-2	8	0	0	9.0	
i 1	506.48738095238093	2.525	72	704	6	5	12	2	0	-2	2	0	0	9.0	
i 1	506.49314965986395	3.0300000000000002	72	1090	6	5	12	2	0	1	2	0	0	9.0	
i 1	506.49387074829934	0.505	70	592	1	24	7	8	0	-2	8	0	0	4.0	
i 1	506.7445918367347	3.535	71	592	5	3	2	8	0	-2	8	0	0	3.0	
i 1	506.75973469387753	3.535	74	388	4	4	5	2	5001	-1	2	0	0	3.0	
i 1	506.98449659863945	1.2625	71	1090	5	9	16	2	0	-1	2	0	0	2.0	
i 1	506.98810204081633	1.2625	71	704	4	2	1	8	0	-2	8	0	0	3.0	
i 1	507.01622448979595	0.2525	74	388	4	24	10	2	5001	-1	2	0	0	5.0	
i 1	507.24387074829934	0.505	74	704	6	1	7	2	0	-1	2	0	0	4.0	
i 1	507.2669455782313	0.2525	71	592	4	24	16	8	0	-2	8	0	0	5.0	
i 1	507.48521768707485	3.7875	74	388	5	3	3	8	5001	-2	8	0	0	3.0	
i 1	507.48954421768707	0.2525	72	1090	6	5	8	2	0	1	2	0	0	9.0	
i 1	507.51045578231293	3.7875	71	704	6	2	1	2	0	-2	2	0	0	3.0	
i 1	507.74314965986395	0.2525	71	1090	6	1	16	2	0	-1	2	0	0	4.0	
i 1	507.7546870748299	0.2525	75	388	5	5	14	8	5001	1	8	0	0	9.0	
i 1	507.98954421768707	0.2525	74	1090	6	1	13	2	0	-1	2	0	0	4.0	
i 1	507.99314965986395	0.2525	74	388	4	24	16	2	5001	-1	2	0	0	5.0	
i 1	508.0133401360544	2.7775	75	592	6	5	1	2	0	1	2	0	0	9.0	
i 1	508.0140612244898	2.7775	72	1090	6	5	16	2	0	1	2	0	0	9.0	
i 1	508.2366598639456	0.505	71	592	4	24	10	8	0	-2	8	0	0	5.0	
i 1	508.25252380952384	0.2525	74	704	6	1	13	2	0	-1	2	0	0	4.0	
i 1	508.5054081632653	0.7575000000000001	71	1090	6	1	6	2	0	-1	2	0	0	4.0	
i 1	508.74387074829934	0.2525	74	704	6	1	11	2	0	-1	2	0	0	4.0	
i 1	508.9909863945578	0.505	74	1090	6	1	5	2	0	-1	2	0	0	4.0	
i 1	508.99747619047616	0.2525	75	704	6	5	2	2	0	1	2	0	0	9.0	
i 1	509.24026530612247	0.505	71	592	6	1	3	8	0	-2	8	0	0	4.0	
i 1	509.25612925170066	0.505	73	592	1	24	11	2	0	-2	2	0	0	4.0	
i 1	509.26261904761907	2.525	75	388	5	5	15	8	5001	1	8	0	0	9.0	
i 1	509.48738095238093	6.3125	75	704	6	5	4	2	0	1	2	0	0	9.0	
i 1	509.48810204081633	0.2525	74	388	4	24	1	2	5001	-1	2	0	0	5.0	
i 1	509.7467551020408	5.05	71	592	4	24	12	8	0	-2	8	0	0	5.0	
i 1	509.7496394557823	2.7775	74	1090	6	1	5	2	0	-1	2	0	0	4.0	
i 1	510.2388231292517	1.2625	74	1090	5	9	5	2	0	-1	2	0	0	2.0	
i 1	510.24314965986395	1.2625	74	592	4	4	7	2	0	-1	2	0	0	3.0	
i 1	510.25973469387753	1.7675	74	388	4	24	13	2	5001	-1	2	0	0	5.0	
i 1	510.26622448979595	1.5150000000000001	71	592	6	1	12	8	0	-2	8	0	0	4.0	
i 1	510.4830544217687	4.04	74	388	4	4	14	2	5001	-1	2	0	0	3.0	
i 1	510.49819727891156	4.04	71	592	5	3	15	8	0	-2	8	0	0	3.0	
i 1	510.7323333333333	0.2525	75	388	5	5	12	8	5001	1	8	0	0	9.0	
i 1	510.76261904761907	1.7675	71	704	4	2	3	8	0	-2	8	0	0	3.0	
i 1	510.76622448979595	1.7675	71	1090	5	9	7	2	0	-1	2	0	0	2.0	
i 1	510.7669455782313	1.01	72	704	6	5	13	2	0	-2	2	0	0	9.0	
i 1	510.9996394557823	0.2525	75	592	6	5	16	2	0	1	2	0	0	9.0	
i 1	511.5039659863946	5.3025	74	704	6	1	15	2	0	-2	2	0	0	4.0	
i 1	511.50612925170066	6.0600000000000005	74	388	6	1	4	8	5001	-1	8	0	0	4.0	
i 1	511.7388231292517	0.2525	72	1090	5	5	9	2	0	1	2	0	0	9.0	
i 1	511.7453129251701	5.8075	60	1090	4	18	7	0	0	0	0	0	0	5.188252614165814	
i 1	511.7467551020408	1.2625	75	388	6	5	1	8	5001	1	8	0	0	9.0	
i 1	511.75757142857145	0.2525	71	592	6	1	9	8	0	-2	8	0	0	4.0	
i 1	511.76045578231293	0.2525	75	592	6	5	13	2	0	1	2	0	0	9.0	
i 1	511.98377551020405	2.2725	72	1090	6	5	3	2	0	1	2	0	0	9.0	
i 1	512.0104557823129	2.2725	72	704	6	5	14	2	0	-2	2	0	0	9.0	
i 1	512.2467551020408	0.2525	70	592	1	24	2	2	0	-2	2	0	0	4.0	
i 1	512.5025238095238	2.525	71	704	4	2	2	2	0	-2	2	0	0	3.0	
i 1	512.5082925170068	0.505	71	1090	6	1	14	2	0	-1	2	0	0	4.0	
i 1	512.5104557823129	2.525	74	388	5	3	13	8	5001	-2	8	0	0	3.0	
i 1	512.7323333333334	0.505	73	592	1	24	11	2	0	-1	2	0	0	4.0	
i 1	512.9953129251701	2.2725	74	1090	6	1	7	2	0	-1	2	0	0	4.0	
i 1	513.0032448979592	0.2525	72	1090	5	5	8	2	0	1	2	0	0	9.0	
i 1	513.2503605442176	2.525	75	388	6	5	13	8	5001	1	8	0	0	9.0	
i 1	514.0018027210884	1.7675	74	1090	5	9	13	2	0	-1	2	0	0	2.0	
i 1	514.0169455782313	0.2525	73	592	1	24	10	8	0	-2	8	0	0	4.0	
i 1	514.0176666666666	1.7675	74	592	4	4	13	2	0	-1	2	0	0	3.0	
i 1	514.2597346938776	0.2525	75	388	5	5	13	8	5001	1	8	0	0	9.0	
i 1	514.2626190476191	0.2525	72	1090	5	5	9	2	0	1	2	0	0	9.0	
i 1	514.4902653061224	0.2525	75	592	6	5	5	2	0	1	2	0	0	9.0	
i 1	514.5097346938776	1.7675	75	592	6	5	9	8	0	-2	8	0	0	9.0	
i 1	514.7373809523809	2.02	74	388	4	4	6	2	5001	-1	2	0	0	3.0	
i 1	514.7438707482993	2.7775	75	388	5	5	7	8	5001	1	8	0	0	9.0	
i 1	514.7582925170068	0.2525	71	1090	6	1	7	2	0	-1	2	0	0	4.0	
i 1	514.7597346938776	1.5150000000000001	71	592	5	3	9	8	0	-2	8	0	0	3.0	
i 1	514.9823333333334	0.505	70	592	1	24	9	8	0	-1	8	0	0	4.0	
i 1	515.0039659863945	0.505	74	388	4	24	3	2	5001	-1	2	0	0	5.0	
i 1	515.2518027210884	0.2525	71	1090	6	1	6	2	0	-1	2	0	0	4.0	
i 1	515.4967551020408	0.7575000000000001	71	592	4	24	16	8	0	-2	8	0	0	5.0	
i 1	515.5126190476191	0.2525	74	1090	6	1	12	2	0	-1	2	0	0	4.0	
i 1	515.733775510204	2.2725	74	388	5	3	6	8	5001	-2	8	0	0	3.0	
i 1	515.748918367347	1.7675	74	388	4	24	9	2	5001	-1	2	0	0	5.0	
i 1	515.7518027210884	0.505	75	592	6	5	10	2	0	1	2	0	0	9.0	
i 1	515.7618979591837	0.2525	72	704	6	5	15	2	0	-2	2	0	0	9.0	
i 1	515.7633401360545	0.2525	71	704	4	2	14	2	0	-2	2	0	0	3.0	
i 1	515.9909863945578	0.2525	72	1090	5	5	10	2	0	1	2	0	0	9.0	
i 1	515.9938707482993	0.2525	73	592	1	24	2	8	0	-1	8	0	0	4.0	
i 1	516.0126190476191	0.2525	74	1090	5	9	8	2	0	-1	2	0	0	2.0	
i 1	516.233775510204	1.2625	74	388	5	3	3	8	0	-1	8	0	0	3.0	
i 1	516.2402653061224	1.2625	67	388	6	17	14	5	0	1	5	0	0	5.188252614165814	
i 1	516.2467551020408	1.2625	71	388	4	24	12	8	0	-2	8	0	0	5.0	
i 1	516.2481972789116	1.2625	75	388	6	5	11	2	0	1	2	0	0	9.0	
i 1	516.2554081632653	1.2625	67	388	6	17	14	0	0	0	0	0	0	5.188252614165814	
i 1	516.2590136054422	0.2525	71	704	4	2	9	8	0	-2	8	0	0	3.0	
i 1	516.2669455782313	0.505	75	388	6	5	10	2	0	1	2	0	0	9.0	
i 1	516.493149659864	1.01	71	1090	5	9	10	2	0	-1	2	0	0	2.0	
i 1	516.5032448979592	1.01	71	388	6	1	11	8	0	-2	8	0	0	4.0	
i 1	516.5140612244898	1.2625	71	704	4	2	16	2	0	-2	2	0	0	3.0	
i 1	516.7503605442176	0.7575000000000001	72	1090	6	5	16	2	0	1	2	0	0	9.0	
i 1	516.7604557823129	0.2525	72	704	6	5	4	2	0	-2	2	0	0	9.0	
i 1	517.0111768707483	0.505	75	704	6	5	6	2	0	1	2	0	0	9.0	
i 1	517.0176666666666	0.2525	73	388	1	24	13	8	0	-2	8	0	0	4.0	
i 1	517.2518027210884	1.7675	74	388	4	4	15	2	5001	-1	2	0	0	3.0	
i 1	517.2669455782313	0.2525	74	1090	6	1	2	2	0	-1	2	0	0	4.0	
i 1	517.4823333333334	0.2525	67	704	5	13	13	5	0	1	5	0	0	1.8556089338674135	
i 1	517.4844965986395	0.2525	72	704	6	5	8	2	0	-2	2	0	0	2.0	
i 1	517.4844965986395	0.505	75	388	6	5	9	8	5001	1	8	0	0	2.0	
i 1	517.4866598639455	0.2525	60	704	5	14	8	5	0	0	5	0	0	3.247315634267973	
i 1	517.4866598639455	0.2525	60	704	5	14	14	5	0	0	5	0	0	2.8211192209668345	
i 1	517.4895442176871	0.2525	60	388	5	15	13	0	0	0	0	0	0	2.3195111673342668	
i 1	517.4909863945578	0.2525	71	1090	5	9	16	2	0	-1	2	0	0	2.0	
i 1	517.493149659864	0.2525	71	388	6	1	5	8	0	-2	8	0	0	5.0	
i 1	517.493149659864	0.2525	75	704	6	5	8	2	0	1	2	0	0	2.0	
i 1	517.4938707482993	0.2525	72	1090	5	5	3	2	0	1	2	0	0	2.0	
i 1	517.5003605442176	0.2525	74	1090	6	1	16	2	0	-1	2	0	0	5.0	
i 1	517.5003605442176	0.2525	60	1090	4	16	15	5	0	1	5	0	0	2.78341340080112	
i 1	517.5003605442176	0.2525	67	388	6	7	1	5	0	1	5	0	0	1.4105596104834173	
i 1	517.5018027210884	0.2525	71	388	4	24	9	8	0	-2	8	0	0	6.0	
i 1	517.5018027210884	0.2525	74	388	4	3	1	8	0	-1	8	0	0	3.0	
i 1	517.5032448979592	0.2525	60	704	6	17	1	0	0	1	0	0	0	4.760913760899764	
i 1	517.5039659863945	0.2525	67	704	5	14	9	5	0	1	5	0	0	2.8211192209668345	
i 1	517.5075714285714	0.2525	60	388	5	15	5	0	0	0	0	0	0	2.3195111673342668	
i 1	517.5082925170068	0.2525	67	704	6	17	7	0	0	1	0	0	0	4.760913760899764	
i 1	517.5090136054422	0.2525	75	388	6	5	14	2	0	1	2	0	0	2.0	
i 1	517.5104557823129	1.5150000000000001	74	388	6	1	4	8	5001	-1	8	0	0	5.0	
i 1	517.5111768707483	0.2525	60	1090	4	18	13	0	0	0	0	0	0	4.760913760899764	
i 1	517.5126190476191	0.2525	67	388	6	17	10	0	0	0	0	0	0	4.760913760899764	
i 1	517.5140612244898	0.2525	60	1090	4	18	7	0	0	1	0	0	0	4.760913760899764	
i 1	517.5169455782313	0.7575000000000001	74	388	4	24	12	2	5001	-1	2	0	0	6.0	
i 1	517.5176666666666	0.2525	67	388	6	17	2	5	0	1	5	0	0	4.760913760899764	
i 1	517.7373809523809	22.9775	60	1193	6	17	15	5	0	0	5	0	0	4.760913760899764	
i 1	517.7381020408163	0.7575000000000001	71	379	5	9	9	8	0	-2	8	0	0	2.0	
i 1	517.7388231292517	1.2625	71	695	4	3	8	2	0	-1	2	0	0	3.0	
i 1	517.7388231292517	1.2625	60	695	6	7	6	5	0	0	5	0	0	1.4105596104834173	
i 1	517.743149659864	1.2625	73	379	1	24	16	8	0	-1	8	0	0	4.0	
i 1	517.7445918367347	0.2525	74	695	6	1	12	2	0	-1	2	0	0	5.0	
i 1	517.7445918367347	1.2625	72	379	6	5	12	2	0	-2	2	0	0	2.0	
i 1	517.7453129251701	1.2625	71	695	4	24	9	2	0	-2	2	0	0	6.0	
i 1	517.7467551020408	1.2625	74	379	6	1	7	8	0	-1	8	0	0	5.0	
i 1	517.748918367347	1.5150000000000001	72	1193	6	5	4	8	0	1	8	0	0	2.0	
i 1	517.748918367347	31.5625	60	1193	5	14	16	5	0	1	5	0	0	2.8211192209668345	
i 1	517.7496394557824	17.17	60	1193	5	13	3	5	0	0	5	0	0	1.8556089338674135	
i 1	517.7525238095238	1.2625	60	695	6	17	7	0	0	0	0	0	0	4.760913760899764	
i 1	517.7525238095238	0.2525	75	695	6	5	2	2	0	-2	2	0	0	2.0	
i 1	517.7525238095238	28.785	60	1193	5	14	7	0	0	0	0	0	0	2.8211192209668345	
i 1	517.7532448979592	0.505	72	1193	6	5	4	8	0	-2	8	0	0	2.0	
i 1	517.7597346938776	1.2625	60	695	5	15	11	0	0	0	0	0	0	2.3195111673342668	
i 1	517.7604557823129	1.2625	67	695	5	15	11	0	0	1	0	0	0	2.3195111673342668	
i 1	517.7626190476191	1.2625	60	379	4	18	3	0	0	0	0	0	0	4.760913760899764	
i 1	517.7626190476191	1.2625	67	379	4	18	11	0	0	1	0	0	0	4.760913760899764	
i 1	517.7655034013605	28.785	67	1193	6	17	5	5	0	1	5	0	0	4.760913760899764	
i 1	517.766224489796	11.3625	67	1193	5	14	12	5	0	1	5	0	0	3.247315634267973	
i 1	517.766224489796	1.2625	67	379	4	16	7	0	0	1	0	0	0	2.78341340080112	
i 1	517.7676666666666	0.505	71	1193	5	2	12	8	0	-1	8	0	0	3.0	
i 1	517.7676666666666	1.2625	60	695	6	17	16	0	0	0	0	0	0	4.760913760899764	
i 1	517.9873809523809	2.02	71	1193	6	1	16	2	0	-2	2	0	0	5.0	
i 1	518.0082925170068	1.01	72	379	6	5	8	2	0	1	2	0	0	2.0	
i 1	518.2395442176871	0.7575000000000001	75	695	6	5	9	2	0	-2	2	0	0	2.0	
i 1	518.2525238095238	0.2525	71	1193	5	2	4	8	0	-1	8	0	0	3.0	
i 1	518.4844965986395	0.505	74	388	5	3	16	8	5001	-2	8	0	0	3.0	
i 1	518.5039659863945	0.505	71	379	6	1	8	8	0	-1	8	0	0	5.0	
i 1	518.5104557823129	0.505	75	695	6	5	1	2	0	1	2	0	0	2.0	
i 1	518.5126190476191	0.2525	71	379	5	9	15	8	0	-2	8	0	0	2.0	
i 1	518.5155034013605	0.505	75	388	6	5	6	8	5001	1	8	0	0	2.0	
i 1	518.9844965986395	6.3125	71	610	4	24	11	2	0	-1	2	0	0	6.0	
i 1	518.9852176870749	0.2525	71	926	4	4	2	2	0	-2	2	0	0	3.0	
i 1	518.9873809523809	0.7575000000000001	72	224	6	5	6	2	0	-2	2	0	0	2.0	
i 1	518.9881020408163	4.2925	74	610	5	3	4	2	0	-2	2	0	0	3.0	
i 1	518.9881020408163	0.505	71	610	4	4	5	2	0	-2	2	0	0	3.0	
i 1	518.9888231292517	21.715	60	926	5	15	1	0	0	1	0	0	0	2.3195111673342668	
i 1	518.993149659864	6.8175	74	926	4	3	4	2	0	-1	2	0	0	3.0	
i 1	518.9945918367347	2.02	72	610	6	5	8	2	0	-2	2	0	0	2.0	
i 1	518.9945918367347	43.43	67	926	6	7	14	0	0	1	0	0	0	1.4105596104834173	
i 1	518.9967551020408	0.505	72	926	6	5	9	2	0	1	2	0	0	2.0	
i 1	518.9974761904762	33.33	67	224	5	16	9	0	0	0	0	0	0	2.78341340080112	
i 1	518.998918367347	1.7675	70	224	1	24	3	8	0	-2	8	0	0	4.0	
i 1	518.9996394557824	2.525	75	926	6	5	1	2	0	1	2	0	0	2.0	
i 1	519.0046870748299	1.01	74	224	7	1	8	2	0	-1	2	0	0	5.0	
i 1	519.0082925170068	6.3125	74	926	4	24	16	8	0	-1	8	0	0	6.0	
i 1	519.0097346938776	0.505	74	610	6	1	2	2	0	-2	2	0	0	5.0	
i 1	519.0104557823129	0.2525	75	224	6	5	5	2	0	1	2	0	0	2.0	
i 1	519.0118979591837	39.1375	67	926	6	17	1	5	0	1	5	0	0	4.760913760899764	
i 1	519.0147823129251	44.945	60	224	5	18	10	0	0	1	0	0	0	4.760913760899764	
i 1	519.0155034013605	50.7525	60	224	5	18	3	5	0	1	5	0	0	4.760913760899764	
i 1	519.016224489796	27.5225	67	926	5	15	16	5	0	0	5	0	0	2.3195111673342668	
i 1	519.0176666666666	33.33	60	926	6	17	12	5	0	1	5	0	0	4.760913760899764	
i 1	519.251081632653	3.2825	71	1193	5	2	2	8	0	-1	8	0	0	3.0	
i 1	519.2611768707483	2.7775	74	224	6	9	9	8	0	-1	8	0	0	2.0	
i 1	519.5140612244898	0.2525	72	1193	6	5	14	8	0	-2	8	0	0	2.0	
i 1	519.733775510204	0.2525	75	224	6	5	7	2	0	1	2	0	0	2.0	
i 1	519.7539659863945	0.2525	75	610	6	5	8	2	0	1	2	0	0	2.0	
i 1	519.9888231292517	2.2725	72	224	6	5	16	2	0	-2	2	0	0	2.0	
i 1	519.9909863945578	1.5150000000000001	74	610	6	1	13	2	0	-2	2	0	0	5.0	
i 1	519.9924285714286	2.7775	72	1193	6	5	7	8	0	1	8	0	0	2.0	
i 1	520.006850340136	1.2625	71	926	6	1	8	2	0	-2	2	0	0	5.0	
i 1	520.2460340136055	0.505	73	610	1	24	10	8	0	248	8	308	0	4.0	
i 1	521.0104557823129	0.2525	75	224	6	5	7	2	0	1	2	0	0	2.0	
i 1	521.2366598639455	0.505	71	224	7	1	3	8	0	-1	8	0	0	5.0	
i 1	521.2597346938776	2.525	72	926	6	5	12	2	0	1	2	0	0	2.0	
i 1	521.4967551020408	0.2525	71	926	6	1	1	2	0	-2	2	0	0	5.0	
i 1	521.5133401360545	2.2725	75	610	6	5	11	2	0	1	2	0	0	2.0	
i 1	521.7330544217687	0.2525	74	1193	6	1	13	8	0	-2	8	0	0	5.0	
i 1	521.7330544217687	0.2525	74	610	6	1	14	2	0	-2	2	0	0	5.0	
i 1	521.7561292517007	0.2525	70	224	1	24	3	8	0	-2	8	0	0	4.0	
i 1	521.9888231292517	1.5150000000000001	71	1193	6	1	5	2	0	-2	2	0	0	5.0	
i 1	521.9895442176871	0.2525	74	224	6	9	13	2	0	-2	2	0	0	2.0	
i 1	522.0025238095238	1.5150000000000001	74	224	7	1	6	2	0	-1	2	0	0	5.0	
i 1	522.2388231292517	2.02	70	224	1	24	7	8	0	-2	8	0	0	4.0	
i 1	522.2438707482993	0.2525	75	224	6	5	15	2	0	1	2	0	0	2.0	
i 1	522.2582925170068	0.2525	71	926	4	4	12	2	0	-2	2	0	0	3.0	
i 1	522.4981972789116	1.5150000000000001	74	224	6	9	5	2	0	-2	2	0	0	2.0	
i 1	522.5169455782313	0.2525	72	610	6	5	7	2	0	-2	2	0	0	2.0	
i 1	522.743149659864	1.2625	71	1193	5	2	16	8	0	-1	8	0	0	3.0	
i 1	522.7445918367347	0.505	72	1193	6	5	8	8	0	-2	8	0	0	2.0	
i 1	522.7453129251701	3.2825	75	224	6	5	6	2	0	1	2	0	0	2.0	
i 1	523.2395442176871	26.0075	67	610	4	19	11	5	0	1	5	0	0	4.760913760899764	
i 1	523.2424285714286	4.04	71	1193	5	2	11	8	0	-1	8	0	0	3.0	
i 1	523.251081632653	34.845	67	224	5	16	7	5	0	1	5	0	0	2.78341340080112	
i 1	523.2532448979592	4.04	74	224	6	9	15	8	0	-1	8	0	0	2.0	
i 1	523.2575714285714	2.525	74	610	5	3	9	2	0	-2	2	0	0	3.0	
i 1	523.2618979591837	2.7775	72	1193	6	5	7	8	0	-2	8	0	0	2.0	
i 1	523.4909863945578	0.2525	74	610	6	1	3	2	0	-2	2	0	0	5.0	
i 1	523.7503605442176	0.2525	72	224	6	5	4	2	0	-2	2	0	0	2.0	
i 1	523.7626190476191	0.2525	74	1193	6	1	8	8	0	-2	8	0	0	5.0	
i 1	523.7676666666666	0.2525	71	1193	6	1	10	2	0	-2	2	0	0	5.0	
i 1	524.0025238095238	1.01	75	926	6	5	4	2	0	1	2	0	0	2.0	
i 1	524.0061292517007	0.505	71	224	6	1	3	8	0	-1	8	0	0	5.0	
i 1	524.251081632653	0.2525	72	1193	6	5	6	8	0	1	8	0	0	2.0	
i 1	524.2597346938776	0.2525	74	1193	6	1	5	8	0	-2	8	0	0	5.0	
i 1	524.4924285714286	0.2525	72	926	6	5	7	2	0	1	2	0	0	2.0	
i 1	524.4953129251701	2.525	70	224	1	24	5	8	0	-2	8	0	0	4.0	
i 1	524.4960340136055	2.7775	74	224	7	1	6	2	0	-1	2	0	0	5.0	
i 1	524.5104557823129	2.7775	71	1193	6	1	3	2	0	-2	2	0	0	5.0	
i 1	524.7481972789116	0.2525	72	610	5	5	11	2	0	-2	2	0	0	2.0	
i 1	525.0032448979592	1.2625	72	224	6	5	1	2	0	-2	2	0	0	2.0	
i 1	525.0176666666666	1.2625	72	1193	6	5	10	8	0	1	8	0	0	2.0	
i 1	525.2359387755102	2.525	72	926	6	5	1	2	0	1	2	0	0	2.0	
i 1	525.2381020408163	2.7775	75	610	6	5	13	2	0	1	2	0	0	2.0	
i 1	525.2561292517007	0.2525	74	1193	6	1	13	8	0	-2	8	0	0	5.0	
i 1	525.5176666666666	0.2525	71	926	6	1	15	2	0	-2	2	0	0	5.0	
i 1	525.7561292517007	0.2525	71	926	4	4	6	2	0	-2	2	0	0	3.0	
i 1	525.9974761904762	3.0300000000000002	74	926	4	3	14	2	0	-1	2	0	0	3.0	
i 1	526.0025238095238	0.2525	74	610	5	3	13	2	0	-2	2	0	0	3.0	
i 1	526.0147823129251	6.565	71	610	4	24	2	2	0	-1	2	0	0	6.0	
i 1	526.0155034013605	0.2525	71	926	6	1	10	2	0	-2	2	0	0	5.0	
i 1	526.2381020408163	0.7575000000000001	75	926	6	5	13	2	0	1	2	0	0	2.0	
i 1	526.2409863945578	0.2525	71	610	4	4	16	2	0	-2	2	0	0	3.0	
i 1	526.2445918367347	0.2525	75	224	6	5	11	2	0	1	2	0	0	2.0	
i 1	526.2604557823129	6.0600000000000005	74	926	4	24	10	8	0	-1	8	0	0	6.0	
i 1	526.4895442176871	0.2525	72	1193	6	5	7	8	0	1	8	0	0	2.0	
i 1	526.5090136054422	2.2725	74	610	5	3	4	2	0	-2	2	0	0	3.0	
i 1	526.7611768707483	0.2525	72	610	5	5	7	2	0	-2	2	0	0	2.0	
i 1	526.9873809523809	1.01	71	1193	5	2	13	8	0	-1	8	0	0	3.0	
i 1	527.0039659863945	0.7575000000000001	74	224	6	9	8	2	0	-2	2	0	0	2.0	
i 1	527.006850340136	2.2725	72	1193	6	5	16	8	0	-2	8	0	0	2.0	
i 1	527.0082925170068	2.525	75	224	6	5	9	2	0	1	2	0	0	2.0	
i 1	527.2424285714286	0.2525	74	610	6	1	8	2	0	-2	2	0	0	5.0	
i 1	527.4823333333334	0.2525	74	224	7	1	8	2	0	-1	2	0	0	5.0	
i 1	527.4909863945578	0.2525	74	1193	6	1	3	8	0	-2	8	0	0	5.0	
i 1	527.7481972789116	1.7675	74	610	6	1	4	2	0	-2	2	0	0	5.0	
i 1	527.7604557823129	3.535	74	224	6	9	6	8	0	-1	8	0	0	2.0	
i 1	527.7618979591837	1.5150000000000001	71	926	6	1	15	2	0	-2	2	0	0	5.0	
i 1	527.7676666666666	0.2525	72	224	6	5	7	2	0	-2	2	0	0	2.0	
i 1	527.9974761904762	3.2825	71	1193	5	2	9	8	0	-1	8	0	0	3.0	
i 1	528.0025238095238	2.7775	72	610	5	5	1	2	0	-2	2	0	0	2.0	
i 1	528.2647823129251	0.7575000000000001	75	926	6	5	9	2	0	1	2	0	0	2.0	
i 1	528.493149659864	1.7675	70	224	1	24	9	8	0	-2	8	0	0	4.0	
i 1	528.766224489796	0.2525	71	926	4	4	6	2	0	-2	2	0	0	3.0	
i 1	528.9830544217687	0.2525	74	224	4	9	4	2	0	-2	2	0	0	2.0	
i 1	528.9917074829932	20.2	60	610	5	12	8	5	0	1	5	0	0	2.78341340080112	
i 1	528.9974761904762	1.5150000000000001	75	926	6	5	3	2	0	1	2	0	0	2.0	
i 1	529.006850340136	20.2	67	1193	5	14	13	5	0	1	5	0	0	3.247315634267973	
i 1	529.0097346938776	20.2	60	610	4	19	2	0	0	1	0	0	0	4.760913760899764	
i 1	529.2330544217687	0.505	71	1193	6	1	1	2	0	-2	2	0	0	5.0	
i 1	529.243149659864	5.555	74	926	4	3	8	2	0	-1	2	0	0	3.0	
i 1	529.2481972789116	5.3025	74	610	5	3	9	2	0	-2	2	0	0	3.0	
i 1	529.498918367347	2.2725	72	224	6	5	8	2	0	-2	2	0	0	2.0	
i 1	529.5054081632653	2.2725	72	1193	6	5	13	8	0	1	8	0	0	2.0	
i 1	529.7388231292517	0.2525	74	224	6	1	8	2	0	-1	2	0	0	5.0	
i 1	529.7402653061224	0.2525	74	1193	6	1	15	8	0	-2	8	0	0	5.0	
i 1	529.9938707482993	0.2525	74	610	6	1	9	2	0	-2	2	0	0	5.0	
i 1	530.2611768707483	1.2625	71	1193	6	1	6	2	0	-2	2	0	0	5.0	
i 1	530.2647823129251	1.2625	74	224	6	1	14	2	0	-1	2	0	0	5.0	
i 1	530.4945918367347	0.2525	72	1193	6	5	3	8	0	-2	8	0	0	2.0	
i 1	530.7438707482993	0.2525	75	926	6	5	8	2	0	1	2	0	0	2.0	
i 1	530.9881020408163	1.5150000000000001	75	610	5	5	7	2	0	1	2	0	0	2.0	
i 1	530.9917074829932	1.5150000000000001	72	926	6	5	1	2	0	1	2	0	0	2.0	
i 1	531.266224489796	0.2525	71	926	4	4	11	2	0	-2	2	0	0	3.0	
i 1	531.4830544217687	0.2525	71	926	6	1	11	2	0	-2	2	0	0	5.0	
i 1	531.4881020408163	0.2525	71	610	4	4	5	2	0	-2	2	0	0	3.0	
i 1	531.4981972789116	0.2525	74	610	6	1	14	2	0	-2	2	0	0	5.0	
i 1	531.5126190476191	2.02	74	224	4	9	11	2	0	-2	2	0	0	2.0	
i 1	531.7352176870749	2.525	72	1193	6	5	11	8	0	-2	8	0	0	2.0	
i 1	531.7424285714286	3.0300000000000002	71	1193	6	1	16	2	0	-2	2	0	0	5.0	
i 1	531.7474761904762	3.2825	74	224	6	1	5	2	0	-1	2	0	0	5.0	
i 1	531.7496394557824	1.7675	71	1193	5	2	9	8	0	-1	8	0	0	3.0	
i 1	531.7626190476191	3.0300000000000002	75	224	6	5	6	2	0	1	2	0	0	2.0	
i 1	532.2539659863945	0.2525	71	224	6	1	15	8	0	-1	8	0	0	5.0	
i 1	532.4873809523809	0.2525	71	926	6	1	13	2	0	-2	2	0	0	5.0	
i 1	532.5126190476191	0.2525	72	610	5	5	2	2	0	-2	2	0	0	2.0	
i 1	532.7467551020408	0.2525	75	926	6	5	6	2	0	1	2	0	0	2.0	
i 1	533.2344965986395	1.5150000000000001	74	224	6	9	7	8	0	-1	8	0	0	2.0	
i 1	533.2438707482993	0.2525	74	1193	6	1	7	8	0	-2	8	0	0	5.0	
i 1	533.2655034013605	0.2525	75	926	6	5	5	2	0	1	2	0	0	2.0	
i 1	533.266224489796	2.7775	71	1193	5	2	8	8	0	-1	8	0	0	3.0	
i 1	533.4852176870749	2.525	72	1193	6	5	8	8	0	1	8	0	0	2.0	
i 1	533.5126190476191	0.505	74	610	6	1	13	2	0	-2	2	0	0	5.0	
i 1	533.7532448979592	2.2725	72	224	6	5	7	2	0	-2	2	0	0	2.0	
i 1	533.7647823129251	0.2525	71	926	6	1	9	2	0	-2	2	0	0	5.0	
i 1	533.9852176870749	6.3125	71	610	4	24	6	2	0	-1	2	0	0	6.0	
i 1	534.0104557823129	0.2525	74	1193	6	1	3	8	0	-2	8	0	0	5.0	
i 1	534.2381020408163	1.01	70	224	1	24	1	8	0	-2	8	0	0	4.0	
i 1	534.2474761904762	5.8075	74	926	4	24	6	8	0	-1	8	0	0	6.0	
i 1	534.5082925170068	0.505	74	224	4	9	11	2	0	-2	2	0	0	2.0	
i 1	534.7453129251701	0.2525	71	1193	6	1	4	2	0	-2	2	0	0	5.0	
i 1	534.7460340136055	1.2625	74	224	4	9	6	8	0	-1	8	0	0	2.0	
i 1	534.748918367347	14.3925	67	610	5	12	16	0	0	0	0	0	0	2.78341340080112	
i 1	534.7496394557824	2.2725	72	926	6	5	8	2	0	1	2	0	0	2.0	
i 1	534.766224489796	14.3925	60	1193	5	13	2	5	0	0	5	0	0	1.8556089338674135	
i 1	534.9844965986395	2.02	75	610	5	5	11	2	0	1	2	0	0	2.0	
i 1	534.9881020408163	4.7975	74	926	4	3	15	2	0	-1	2	0	0	3.0	
i 1	534.9974761904762	0.2525	71	926	6	1	9	2	0	-2	2	0	0	5.0	
i 1	535.016224489796	0.505	74	1193	6	1	15	8	0	-2	8	0	0	5.0	
i 1	535.2323333333334	4.04	74	610	5	3	2	2	0	-2	2	0	0	3.0	
i 1	535.4888231292517	0.2525	71	1193	6	1	12	2	0	-2	2	0	0	5.0	
i 1	535.5090136054422	0.2525	74	224	6	1	7	2	0	-1	2	0	0	5.0	
i 1	535.733775510204	1.2625	74	610	5	1	9	2	0	-2	2	0	0	5.0	
i 1	535.7481972789116	1.2625	71	926	6	1	12	2	0	-2	2	0	0	5.0	
i 1	535.7626190476191	0.7575000000000001	70	224	1	24	13	8	0	-2	8	0	0	4.0	
i 1	535.9945918367347	0.505	71	1193	5	2	2	8	0	-1	8	0	0	3.0	
i 1	535.9953129251701	0.2525	72	1193	6	5	16	8	0	-2	8	0	0	2.0	
i 1	536.2597346938776	0.505	71	926	4	4	5	2	0	-2	2	0	0	3.0	
i 1	536.2597346938776	0.2525	75	926	6	5	8	2	0	1	2	0	0	2.0	
i 1	536.501081632653	1.7675	72	1193	6	5	11	8	0	-2	8	0	0	2.0	
i 1	536.5133401360545	1.7675	75	224	6	5	14	2	0	1	2	0	0	2.0	
i 1	536.7496394557824	1.01	71	1193	5	2	7	8	0	-1	8	0	0	3.0	
i 1	536.766224489796	1.2625	70	610	1	24	2	8	0	248	8	308	0	4.0	
i 1	536.983775510204	0.7575000000000001	74	224	4	9	3	2	0	-2	2	0	0	2.0	
i 1	537.0025238095238	2.2725	72	610	5	5	8	2	0	-2	2	0	0	2.0	
i 1	537.0054081632653	0.2525	74	224	6	1	4	2	0	-1	2	0	0	5.0	
i 1	537.2417074829932	1.2625	71	1193	6	1	9	2	0	-2	2	0	0	5.0	
i 1	537.4852176870749	1.01	71	1193	5	2	2	8	0	-1	8	0	0	3.0	
i 1	537.4960340136055	0.7575000000000001	74	224	4	9	1	8	0	-1	8	0	0	2.0	
i 1	537.5147823129251	1.01	74	224	6	1	12	2	0	-1	2	0	0	5.0	
i 1	537.7655034013605	1.5150000000000001	75	926	6	5	16	2	0	1	2	0	0	2.0	
i 1	538.2647823129251	0.505	72	926	6	5	6	2	0	1	2	0	0	2.0	
i 1	538.5046870748299	0.2525	71	610	4	4	10	2	0	-2	2	0	0	3.0	
i 1	538.5126190476191	0.2525	70	224	1	24	8	8	0	-2	8	0	0	4.0	
i 1	538.5140612244898	0.2525	71	926	6	1	5	2	0	-2	2	0	0	5.0	
i 1	538.733775510204	2.2725	74	224	4	9	15	8	0	-1	8	0	0	2.0	
i 1	538.733775510204	0.7575000000000001	72	224	6	5	6	2	0	-2	2	0	0	2.0	
i 1	538.7352176870749	0.2525	71	1193	6	1	7	2	0	-2	2	0	0	5.0	
i 1	538.7532448979592	0.7575000000000001	72	1193	6	5	4	8	0	1	8	0	0	2.0	
i 1	538.7539659863945	2.2725	71	1193	5	2	9	8	0	-1	8	0	0	3.0	
i 1	539.0126190476191	2.02	72	926	6	5	15	2	0	1	2	0	0	2.0	
i 1	539.0147823129251	0.2525	71	224	6	1	8	8	0	-1	8	0	0	5.0	
i 1	539.0176666666666	2.2725	75	610	5	5	16	2	0	1	2	0	0	2.0	
i 1	539.2575714285714	3.535	71	1193	6	1	6	2	0	-2	2	0	0	5.0	
i 1	539.4953129251701	3.2825	74	224	6	1	16	2	0	-1	2	0	0	5.0	
i 1	539.5111768707483	0.2525	72	610	5	5	12	2	0	-2	2	0	0	2.0	
i 1	539.7323333333334	0.2525	72	224	6	5	13	2	0	-2	2	0	0	2.0	
i 1	539.7438707482993	0.2525	71	926	4	4	15	2	0	-2	2	0	0	3.0	
i 1	540.001081632653	0.2525	74	610	5	3	9	2	0	-2	2	0	0	3.0	
i 1	540.0046870748299	0.2525	75	926	6	5	3	2	0	1	2	0	0	2.0	
i 1	540.2409863945578	2.7775	74	926	4	3	10	2	0	-1	2	0	0	3.0	
i 1	540.2561292517007	0.2525	71	224	6	1	12	8	0	-1	8	0	0	5.0	
i 1	540.2640612244898	3.7875	72	1193	6	5	10	8	0	-2	8	0	0	2.0	
i 1	540.4859387755102	21.715	60	926	5	15	13	0	0	1	0	0	0	2.3195111673342668	
i 1	540.4938707482993	2.2725	74	610	3	3	6	2	0	-2	2	0	0	3.0	
i 1	540.4953129251701	0.2525	71	926	5	1	11	2	0	-2	2	0	0	5.0	
i 1	540.4960340136055	3.2825	75	224	6	5	6	2	0	1	2	0	0	2.0	
i 1	540.983775510204	1.2625	71	1193	5	2	12	8	0	-1	8	0	0	3.0	
i 1	540.9981972789116	0.7575000000000001	74	224	4	9	16	2	0	-2	2	0	0	2.0	
i 1	541.0082925170068	0.2525	74	926	4	24	14	8	0	-1	8	0	0	6.0	
i 1	541.2539659863945	0.2525	72	224	7	5	12	2	0	-2	2	0	0	2.0	
i 1	541.2575714285714	0.505	74	1193	6	1	10	8	0	-2	8	0	0	5.0	
i 1	541.4981972789116	0.2525	75	610	5	5	13	2	0	1	2	0	0	2.0	
i 1	541.7323333333334	0.2525	71	610	4	24	11	2	0	-1	2	0	0	6.0	
i 1	541.7453129251701	0.505	70	224	1	24	3	8	0	-2	8	0	0	4.0	
i 1	541.756850340136	0.2525	72	610	5	5	13	2	0	-2	2	0	0	2.0	
i 1	542.0075714285714	0.505	72	224	7	5	16	2	0	-2	2	0	0	2.0	
i 1	542.0169455782313	3.7875	74	926	4	24	5	8	0	-1	8	0	0	6.0	
i 1	542.2539659863945	1.5150000000000001	71	1193	5	2	2	8	0	-1	8	0	0	3.0	
i 1	542.2590136054422	1.5150000000000001	74	224	4	9	4	8	0	-1	8	0	0	2.0	
i 1	542.2597346938776	3.535	71	610	4	24	7	2	0	-1	2	0	0	6.0	
i 1	542.4967551020408	0.2525	75	926	6	5	9	2	0	1	2	0	0	2.0	
i 1	542.5147823129251	0.2525	70	926	1	24	5	2	0	-2	2	0	0	4.0	
i 1	542.5147823129251	1.2625	70	224	1	24	10	8	0	-2	8	0	0	4.0	
i 1	542.7381020408163	1.5150000000000001	71	926	5	1	6	2	0	-2	2	0	0	5.0	
i 1	542.7467551020408	0.2525	75	610	5	5	6	2	0	1	2	0	0	2.0	
i 1	542.9967551020408	0.2525	71	926	4	4	3	2	0	-2	2	0	0	3.0	
i 1	543.0082925170068	0.2525	75	926	6	5	16	2	0	1	2	0	0	2.0	
i 1	543.2402653061224	1.7675	72	1193	6	5	12	8	0	1	8	0	0	2.0	
i 1	543.2424285714286	3.2825	74	926	4	3	13	2	0	-1	2	0	0	3.0	
i 1	543.2626190476191	3.0300000000000002	74	610	3	3	4	2	0	-2	2	0	0	3.0	
i 1	543.2633401360545	1.7675	72	224	7	5	13	2	0	-2	2	0	0	2.0	
i 1	543.266224489796	1.01	74	610	5	1	3	2	0	-2	2	0	0	5.0	
i 1	543.4902653061224	0.2525	70	926	1	24	8	8	0	-2	8	0	0	4.0	
i 1	543.7373809523809	0.2525	74	224	4	9	14	2	0	-2	2	0	0	2.0	
i 1	543.9873809523809	0.2525	72	610	5	5	3	2	0	-2	2	0	0	2.0	
i 1	543.993149659864	1.2625	71	1193	5	2	1	8	0	-1	8	0	0	3.0	
i 1	544.0018027210884	1.01	74	224	4	9	7	8	0	-1	8	0	0	2.0	
i 1	544.0155034013605	0.2525	70	224	1	24	10	8	0	-2	8	0	0	4.0	
i 1	544.2417074829932	0.2525	72	1193	6	5	1	8	0	-2	8	0	0	2.0	
i 1	544.2590136054422	3.0300000000000002	70	224	1	24	14	8	0	252	8	307	0	4.0	
i 1	544.2626190476191	0.2525	74	224	6	1	1	2	0	-1	2	0	0	5.0	
i 1	544.4909863945578	1.5150000000000001	75	610	5	5	8	2	0	1	2	0	0	2.0	
i 1	544.501081632653	0.2525	71	224	6	1	5	8	0	-1	8	0	0	5.0	
i 1	544.5054081632653	1.5150000000000001	72	926	6	5	1	2	0	1	2	0	0	2.0	
i 1	544.7330544217687	0.2525	74	610	5	1	4	2	0	-2	2	0	0	5.0	
i 1	544.9830544217687	1.5150000000000001	71	1193	6	1	14	2	0	-2	2	0	0	5.0	
i 1	545.0140612244898	0.2525	72	1193	6	5	16	8	0	-2	8	0	0	2.0	
i 1	545.2366598639455	1.2625	74	224	6	1	10	2	0	-1	2	0	0	5.0	
i 1	545.2438707482993	0.2525	71	926	4	4	11	2	0	-2	2	0	0	3.0	
i 1	545.2640612244898	0.2525	75	926	6	5	2	2	0	1	2	0	0	2.0	
i 1	545.483775510204	0.7575000000000001	72	1193	6	5	5	8	0	-2	8	0	0	2.0	
i 1	545.4844965986395	1.7675	71	1193	5	2	16	8	0	-1	8	0	0	3.0	
i 1	545.506850340136	0.7575000000000001	75	224	6	5	16	2	0	1	2	0	0	2.0	
i 1	545.7344965986395	2.2725	72	610	5	5	14	2	0	-2	2	0	0	2.0	
i 1	545.7373809523809	2.02	75	926	6	5	9	2	0	1	2	0	0	2.0	
i 1	545.7438707482993	1.5150000000000001	74	224	4	9	2	2	0	-2	2	0	0	2.0	
i 1	545.756850340136	0.2525	71	926	5	1	13	2	0	-2	2	0	0	5.0	
i 1	545.9852176870749	0.2525	74	926	4	24	4	8	0	-1	8	0	0	6.0	
i 1	545.9902653061224	2.02	71	610	4	24	3	2	0	-1	2	0	0	6.0	
i 1	546.2330544217687	0.505	72	1193	6	5	6	8	0	1	8	0	0	2.0	
i 1	546.2467551020408	15.9075	67	926	5	15	8	5	0	0	5	0	0	2.3195111673342668	
i 1	546.2503605442176	2.7775	60	1193	5	14	7	0	0	0	0	0	0	2.8211192209668345	
i 1	546.2626190476191	1.7675	74	926	4	24	4	8	0	-1	8	0	0	6.0	
i 1	546.4902653061224	0.2525	71	224	6	1	10	8	0	-1	8	0	0	5.0	
i 1	546.516224489796	0.2525	71	926	4	4	11	2	0	-2	2	0	0	3.0	
i 1	546.7366598639455	0.2525	71	926	5	1	14	2	0	-2	2	0	0	5.0	
i 1	546.7417074829932	3.535	74	926	4	3	2	2	0	-1	2	0	0	3.0	
i 1	546.7546870748299	1.7675	74	610	3	3	4	2	0	-2	2	0	0	3.0	
i 1	546.7676666666666	0.2525	75	610	5	5	9	2	0	1	2	0	0	2.0	
i 1	547.0003605442176	0.2525	75	224	7	5	1	2	0	1	2	0	0	2.0	
i 1	547.2460340136055	1.7675	72	1193	6	5	11	8	0	1	8	0	0	2.0	
i 1	547.2467551020408	0.2525	71	926	5	1	6	2	0	-2	2	0	0	5.0	
i 1	547.2467551020408	0.2525	71	926	4	4	8	2	0	-2	2	0	0	3.0	
i 1	547.2618979591837	2.2725	70	224	1	24	15	8	0	-2	8	0	0	4.0	
i 1	547.2626190476191	2.02	72	224	7	5	16	2	0	-2	2	0	0	2.0	
i 1	547.4823333333334	1.7675	74	224	4	9	1	8	0	-1	8	0	0	2.0	
i 1	547.498918367347	1.5150000000000001	71	1193	5	2	9	8	0	-1	8	0	0	3.0	
i 1	547.4996394557824	1.7675	74	224	6	1	7	2	0	-1	2	0	0	5.0	
i 1	547.5147823129251	1.5150000000000001	71	1193	6	1	14	2	0	-2	2	0	0	5.0	
i 1	547.9917074829932	0.505	71	224	6	1	12	8	0	-1	8	0	0	5.0	
i 1	548.006850340136	0.2525	72	1193	6	5	4	8	0	-2	8	0	0	2.0	
i 1	548.0126190476191	1.01	70	610	1	24	10	2	0	248	2	308	0	4.0	
i 1	548.2445918367347	0.2525	75	926	6	5	13	2	0	1	2	0	0	2.0	
i 1	548.5032448979592	1.2625	74	926	4	24	2	8	0	-1	8	0	0	6.0	
i 1	548.7460340136055	0.2525	72	610	5	5	9	2	0	-2	2	0	0	2.0	
i 1	548.748918367347	1.2625	71	224	6	1	16	8	0	-1	8	0	0	5.0	
i 1	548.7618979591837	0.2525	71	610	3	4	3	2	0	-2	2	0	0	3.0	
i 1	548.983775510204	14.645	67	722	5	12	8	5	0	0	5	0	0	2.78341340080112	
i 1	548.9859387755102	0.2525	74	1108	4	2	1	8	0	-2	8	0	0	3.0	
i 1	548.9859387755102	8.8375	60	1108	5	14	8	0	0	0	0	0	0	2.8211192209668345	
i 1	548.9895442176871	3.0300000000000002	75	722	5	5	10	2	0	1	2	0	0	2.0	
i 1	548.9917074829932	1.2625	71	722	3	4	6	8	0	-1	8	0	0	3.0	
i 1	548.9960340136055	0.2525	74	1108	5	1	4	2	0	-2	2	0	0	5.0	
i 1	548.9996394557824	0.2525	70	926	1	24	3	2	0	-2	2	0	0	4.0	
i 1	549.0003605442176	14.645	60	722	5	12	9	5	0	0	5	0	0	2.78341340080112	
i 1	549.0018027210884	14.645	60	722	4	19	14	5	0	1	5	0	0	4.760913760899764	
i 1	549.0025238095238	3.0300000000000002	60	1108	5	14	6	0	0	1	0	0	0	2.8211192209668345	
i 1	549.0082925170068	2.7775	75	1108	6	5	11	2	0	-2	2	0	0	2.0	
i 1	549.0111768707483	14.645	60	722	4	19	7	0	0	0	0	0	0	4.760913760899764	
i 1	549.0147823129251	8.8375	67	1108	5	14	6	0	0	0	0	0	0	3.247315634267973	
i 1	549.0155034013605	14.645	67	1108	5	13	16	5	0	0	5	0	0	1.8556089338674135	
i 1	549.2330544217687	2.02	71	926	5	1	15	2	0	-2	2	0	0	5.0	
i 1	549.2438707482993	2.02	74	722	4	24	5	2	0	-2	2	0	0	6.0	
i 1	549.2453129251701	0.2525	74	224	4	9	10	2	0	-2	2	0	0	2.0	
i 1	549.2655034013605	0.2525	75	926	6	5	15	2	0	1	2	0	0	2.0	
i 1	549.4917074829932	1.5150000000000001	71	1108	4	2	1	2	0	-2	2	0	0	3.0	
i 1	549.4917074829932	0.505	72	224	7	5	14	2	0	-2	2	0	0	2.0	
i 1	549.7633401360545	1.2625	74	224	4	9	14	8	0	-1	8	0	0	2.0	
i 1	549.993149659864	1.2625	70	224	1	24	9	8	0	-2	8	0	0	4.0	
i 1	549.9981972789116	0.2525	72	1108	6	5	4	2	0	-2	2	0	0	2.0	
i 1	550.0003605442176	0.2525	74	722	5	1	15	2	0	-2	2	0	0	5.0	
i 1	550.0075714285714	0.2525	70	926	1	24	2	8	0	-2	8	0	0	4.0	
i 1	550.2344965986395	0.2525	72	722	5	5	5	2	0	1	2	0	0	2.0	
i 1	550.2366598639455	0.2525	71	926	4	4	15	2	0	-2	2	0	0	3.0	
i 1	550.248918367347	0.2525	74	926	4	24	15	8	0	-1	8	0	0	6.0	
i 1	550.4844965986395	0.505	73	926	1	24	5	8	0	-1	8	0	0	4.0	
i 1	550.4859387755102	1.5150000000000001	71	224	6	1	10	8	0	-1	8	0	0	5.0	
i 1	550.5018027210884	1.5150000000000001	71	722	3	4	9	8	0	-1	8	0	0	3.0	
i 1	550.5140612244898	1.2625	74	926	4	3	11	2	0	-1	2	0	0	3.0	
i 1	550.7359387755102	1.2625	74	926	4	24	12	8	0	-1	8	0	0	6.0	
i 1	550.7626190476191	3.0300000000000002	74	722	3	3	9	8	0	-2	8	0	0	3.0	
i 1	550.7633401360545	3.0300000000000002	74	1108	4	2	4	8	0	-2	8	0	0	3.0	
i 1	550.9866598639455	0.2525	72	926	6	5	3	2	0	1	2	0	0	2.0	
i 1	551.2438707482993	5.8075	74	1108	5	1	13	2	0	-2	2	0	0	5.0	
i 1	551.2460340136055	1.7675	72	1108	6	5	11	2	0	-2	2	0	0	2.0	
i 1	551.2604557823129	1.5150000000000001	75	224	7	5	15	2	0	1	2	0	0	2.0	
i 1	551.4996394557824	5.555	74	722	5	1	16	2	0	-2	2	0	0	5.0	
i 1	551.7417074829932	0.2525	70	224	1	24	13	8	0	-2	8	0	0	4.0	
i 1	551.9844965986395	11.615	60	1108	5	14	6	0	0	1	0	0	0	2.8211192209668345	
i 1	551.9902653061224	24.9975	67	224	5	16	15	0	0	0	0	0	0	2.78341340080112	
i 1	551.9981972789116	0.2525	74	224	6	1	3	2	0	-1	2	0	0	5.0	
i 1	552.0090136054422	2.2725	75	722	6	5	6	2	0	1	2	0	0	2.0	
i 1	552.016224489796	0.2525	74	926	4	3	8	2	0	-1	2	0	0	3.0	
i 1	552.2417074829932	0.7575000000000001	70	224	1	24	15	8	0	-2	8	0	0	4.0	
i 1	552.2467551020408	0.2525	74	926	4	24	13	8	0	-1	8	0	0	6.0	
i 1	552.2575714285714	0.2525	71	926	4	4	12	2	0	-2	2	0	0	3.0	
i 1	552.2611768707483	2.02	75	1108	6	5	1	2	0	-2	2	0	0	2.0	
i 1	552.2676666666666	0.2525	73	926	1	24	15	8	0	-1	8	0	0	4.0	
i 1	552.4924285714286	0.505	74	224	6	1	7	2	0	-1	2	0	0	5.0	
i 1	552.5082925170068	0.7575000000000001	74	224	4	9	15	8	0	-1	8	0	0	2.0	
i 1	552.7445918367347	0.505	73	926	1	24	7	2	0	-1	2	0	0	4.0	
i 1	552.9960340136055	0.2525	72	722	5	5	16	2	0	1	2	0	0	2.0	
i 1	553.0032448979592	1.01	74	722	4	24	11	2	0	-2	2	0	0	6.0	
i 1	553.0169455782313	1.01	71	926	5	1	1	2	0	-2	2	0	0	5.0	
i 1	553.2366598639455	2.02	71	722	3	4	15	8	0	-1	8	0	0	3.0	
i 1	553.2467551020408	0.2525	72	926	6	5	10	2	0	1	2	0	0	2.0	
i 1	553.2503605442176	2.02	74	926	4	3	5	2	0	-1	2	0	0	3.0	
i 1	553.4873809523809	0.2525	75	224	7	5	3	2	0	1	2	0	0	2.0	
i 1	553.498918367347	2.7775	70	224	1	24	6	8	0	-2	8	0	0	4.0	
i 1	553.5140612244898	0.2525	73	926	1	24	3	2	0	-1	2	0	0	4.0	
i 1	553.7366598639455	2.02	75	926	6	5	10	2	0	1	2	0	0	2.0	
i 1	553.7546870748299	0.2525	71	926	4	4	6	2	0	-2	2	0	0	3.0	
i 1	553.7546870748299	2.2725	72	722	5	5	15	2	0	1	2	0	0	2.0	
i 1	553.9859387755102	0.2525	74	926	4	24	5	8	0	-1	8	0	0	6.0	
i 1	554.0090136054422	1.01	71	1108	4	2	1	2	0	-2	2	0	0	3.0	
i 1	554.2438707482993	0.2525	71	224	5	1	7	8	0	-1	8	0	0	5.0	
i 1	554.2582925170068	0.7575000000000001	74	224	4	9	4	8	0	-1	8	0	0	2.0	
i 1	554.2655034013605	0.2525	75	224	7	5	2	2	0	1	2	0	0	2.0	
i 1	554.4895442176871	0.505	71	926	5	1	13	2	0	-2	2	0	0	5.0	
i 1	554.4917074829932	0.505	75	1108	6	5	10	2	0	-2	2	0	0	2.0	
i 1	554.7496394557824	1.5150000000000001	74	722	3	3	12	8	0	-2	8	0	0	3.0	
i 1	554.7518027210884	3.535	74	1108	4	2	12	8	0	-2	8	0	0	3.0	
i 1	554.9895442176871	0.2525	71	224	5	1	11	8	0	-1	8	0	0	5.0	
i 1	554.9924285714286	0.2525	70	926	1	24	13	8	0	-2	8	0	0	4.0	
i 1	555.0054081632653	2.02	72	1108	6	5	13	2	0	-2	2	0	0	2.0	
i 1	555.2409863945578	0.2525	74	224	4	9	1	2	0	-2	2	0	0	2.0	
i 1	555.2575714285714	1.7675	75	224	7	5	15	2	0	1	2	0	0	2.0	
i 1	555.2582925170068	0.2525	74	224	6	1	2	2	0	-1	2	0	0	5.0	
i 1	555.493149659864	0.2525	71	1108	4	2	14	2	0	-2	2	0	0	3.0	
i 1	555.7417074829932	1.5150000000000001	71	722	3	4	9	8	0	-1	8	0	0	3.0	
i 1	555.748918367347	1.5150000000000001	74	926	4	3	4	2	0	-1	2	0	0	3.0	
i 1	556.0054081632653	0.505	75	926	6	5	14	2	0	1	2	0	0	2.0	
i 1	556.2503605442176	0.505	70	224	1	24	7	8	0	252	8	307	0	4.0	
i 1	556.2633401360545	0.2525	74	1108	5	1	5	8	0	-2	8	0	0	5.0	
i 1	556.4823333333334	1.2625	71	224	5	1	8	8	0	-1	8	0	0	5.0	
i 1	556.5097346938776	1.2625	74	926	4	24	2	8	0	-1	8	0	0	6.0	
i 1	556.5111768707483	1.7675	72	224	7	5	5	2	0	-2	2	0	0	2.0	
i 1	556.5147823129251	1.7675	72	926	6	5	14	2	0	1	2	0	0	2.0	
i 1	556.7546870748299	1.5150000000000001	74	722	3	3	5	8	0	-2	8	0	0	3.0	
i 1	556.7604557823129	2.7775	70	224	1	24	6	8	0	-2	8	0	0	4.0	
i 1	556.9873809523809	0.505	70	926	1	24	7	8	0	-1	8	0	0	4.0	
i 1	557.0046870748299	0.2525	75	1108	6	5	6	2	0	-2	2	0	0	2.0	
i 1	557.0075714285714	0.2525	74	224	6	1	10	2	0	-1	2	0	0	5.0	
i 1	557.2352176870749	0.2525	71	1108	4	2	16	2	0	-2	2	0	0	3.0	
i 1	557.2402653061224	2.02	71	926	5	1	16	2	0	-2	2	0	0	5.0	
i 1	557.2525238095238	2.02	74	722	4	24	9	2	0	-2	2	0	0	6.0	
i 1	557.2532448979592	0.2525	72	1108	6	5	8	2	0	-2	2	0	0	2.0	
i 1	557.483775510204	0.2525	74	224	4	9	14	8	0	-1	8	0	0	2.0	
i 1	557.5061292517007	0.2525	75	224	7	5	1	2	0	1	2	0	0	2.0	
i 1	557.7388231292517	1.5150000000000001	75	722	6	5	5	2	0	1	2	0	0	2.0	
i 1	557.7445918367347	19.19	67	224	5	16	15	5	0	1	5	0	0	2.78341340080112	
i 1	557.7467551020408	1.7675	75	1108	6	5	14	2	0	-2	2	0	0	2.0	
i 1	557.751081632653	0.2525	74	1108	5	1	1	2	0	-2	2	0	0	5.0	
i 1	557.7582925170068	1.01	71	722	3	4	9	8	0	-1	8	0	0	3.0	
i 1	557.766224489796	5.8075	60	1108	4	14	1	0	0	0	0	0	0	2.8211192209668345	
i 1	557.7669455782313	3.0300000000000002	74	926	4	3	5	2	0	-1	2	0	0	3.0	
i 1	557.9924285714286	0.2525	74	224	5	1	16	2	0	-1	2	0	0	5.0	
i 1	558.2330544217687	1.5150000000000001	71	1108	4	2	8	2	0	-2	2	0	0	3.0	
i 1	558.248918367347	0.2525	74	1108	5	1	13	2	0	-2	2	0	0	5.0	
i 1	558.2525238095238	1.5150000000000001	74	224	4	9	1	8	0	-1	8	0	0	2.0	
i 1	558.2626190476191	4.04	75	224	7	5	8	2	0	1	2	0	0	2.0	
i 1	558.5032448979592	0.2525	73	926	1	24	1	8	0	-1	8	0	0	4.0	
i 1	558.5061292517007	1.2625	71	224	5	1	1	8	0	-1	8	0	0	5.0	
i 1	558.7417074829932	3.535	72	1108	6	5	10	2	0	-2	2	0	0	2.0	
i 1	558.7546870748299	1.01	74	926	4	24	2	8	0	-1	8	0	0	6.0	
i 1	559.2503605442176	1.5150000000000001	71	722	3	4	12	8	0	-1	8	0	0	3.0	
i 1	559.251081632653	0.2525	73	926	1	24	5	8	0	-1	8	0	0	4.0	
i 1	559.256850340136	3.0300000000000002	74	722	5	1	14	2	0	-2	2	0	0	5.0	
i 1	559.2647823129251	3.7875	74	1108	5	1	5	2	0	-2	2	0	0	5.0	
i 1	559.5155034013605	0.2525	75	722	6	5	5	2	0	1	2	0	0	2.0	
i 1	559.516224489796	1.01	70	224	1	24	3	8	0	252	8	307	0	4.0	
i 1	559.7467551020408	2.525	74	1108	4	2	7	8	0	-2	8	0	0	3.0	
i 1	559.7539659863945	0.2525	74	224	5	1	10	2	0	-1	2	0	0	5.0	
i 1	559.7575714285714	0.2525	75	926	6	5	7	2	0	1	2	0	0	2.0	
i 1	560.0140612244898	1.2625	71	926	5	1	4	2	0	-2	2	0	0	5.0	
i 1	560.2395442176871	3.2825	74	722	3	3	12	8	0	-2	8	0	0	3.0	
i 1	560.2402653061224	1.01	74	722	4	24	2	2	0	-2	2	0	0	6.0	
i 1	560.4902653061224	1.01	70	224	1	24	1	8	0	-2	8	0	0	4.0	
i 1	560.7330544217687	0.2525	71	926	4	4	3	2	0	-2	2	0	0	3.0	
i 1	560.7481972789116	0.2525	70	926	1	24	8	8	0	-2	8	0	0	4.0	
i 1	560.9888231292517	0.7575000000000001	71	722	3	4	8	8	0	-1	8	0	0	3.0	
i 1	561.0111768707483	1.01	74	926	4	3	5	2	0	-1	2	0	0	3.0	
i 1	561.243149659864	0.2525	74	224	5	1	7	2	0	-1	2	0	0	5.0	
i 1	561.2604557823129	0.2525	73	926	1	24	10	8	0	-2	8	0	0	4.0	
i 1	561.498918367347	0.2525	74	722	4	24	15	2	0	-2	2	0	0	6.0	
i 1	561.7381020408163	1.7675	75	722	6	5	2	2	0	1	2	0	0	2.0	
i 1	561.7539659863945	1.5150000000000001	74	224	5	1	15	2	0	-1	2	0	0	5.0	
i 1	561.7647823129251	0.2525	75	926	6	5	1	2	0	1	2	0	0	2.0	
i 1	562.0032448979592	1.5150000000000001	67	722	6	7	3	0	0	0	0	0	0	1.4105596104834173	
i 1	562.0075714285714	2.7775	67	722	5	15	3	0	0	1	0	0	0	2.3195111673342668	
i 1	562.0082925170068	2.7775	60	722	5	15	5	5	0	0	5	0	0	2.3195111673342668	
i 1	562.0126190476191	1.5150000000000001	72	722	6	5	14	2	0	-2	2	0	0	2.0	
i 1	562.0140612244898	1.2625	74	722	4	3	11	2	0	-1	2	0	0	3.0	
i 1	562.2409863945578	0.2525	74	224	4	9	14	8	0	-1	8	0	0	2.0	
i 1	562.2438707482993	0.2525	72	224	7	5	7	2	0	-2	2	0	0	2.0	
i 1	562.2496394557824	0.2525	71	224	5	1	5	8	0	-1	8	0	0	5.0	
i 1	562.4902653061224	1.7675	74	722	4	24	15	2	0	-2	2	0	0	6.0	
i 1	562.5054081632653	1.01	72	1108	6	5	1	2	0	-2	2	0	0	2.0	
i 1	562.5075714285714	1.01	74	722	4	24	10	2	0	-2	2	0	0	6.0	
i 1	562.5118979591837	0.2525	71	722	3	4	12	8	0	-1	8	0	0	3.0	
i 1	562.7388231292517	0.2525	70	722	1	24	8	8	0	-2	8	0	0	4.0	
i 1	562.7460340136055	1.01	74	224	4	9	5	2	0	-2	2	0	0	2.0	
i 1	562.7561292517007	4.2925	70	224	1	24	15	8	0	-2	8	0	0	4.0	
i 1	562.7626190476191	0.7575000000000001	71	1108	4	2	1	2	0	-2	2	0	0	3.0	
i 1	563.0111768707483	0.7575000000000001	72	224	7	5	1	2	0	-2	2	0	0	2.0	
i 1	563.2366598639455	1.01	71	224	5	1	1	8	0	-1	8	0	0	5.0	
i 1	563.2395442176871	0.2525	74	1108	4	2	11	8	0	-2	8	0	0	3.0	
i 1	563.2633401360545	0.2525	75	1108	6	5	7	2	0	-2	2	0	0	2.0	
i 1	563.483775510204	0.2525	72	926	6	5	4	2	0	1	2	0	0	2.0	
i 1	563.4859387755102	1.2625	67	722	5	7	13	0	0	0	0	0	0	1.4105596104834173	
i 1	563.4917074829932	0.2525	70	722	1	24	16	8	0	-2	8	0	0	4.0	
i 1	563.4938707482993	2.7775	74	224	3	3	2	2	0	-2	2	0	0	3.0	
i 1	563.4938707482993	31.5625	60	926	5	14	6	0	0	0	0	0	0	2.8211192209668345	
i 1	563.4945918367347	11.615	60	224	5	19	9	0	0	1	0	0	0	4.760913760899764	
i 1	563.4967551020408	13.3825	67	224	6	12	1	0	0	0	0	0	0	2.78341340080112	
i 1	563.4974761904762	3.0300000000000002	72	926	6	5	3	2	0	-2	2	0	0	2.0	
i 1	563.4996394557824	0.2525	74	224	5	24	4	2	0	-1	2	0	0	6.0	
i 1	563.5003605442176	1.2625	75	224	7	5	10	2	0	-2	2	0	0	2.0	
i 1	563.5025238095238	0.2525	71	926	6	2	9	8	0	-1	8	0	0	3.0	
i 1	563.5054081632653	1.5150000000000001	71	926	4	2	1	8	0	-2	8	0	0	3.0	
i 1	563.5090136054422	13.3825	67	224	5	19	8	0	0	1	0	0	0	4.760913760899764	
i 1	563.5097346938776	5.8075	60	926	4	14	1	5	0	1	5	0	0	2.8211192209668345	
i 1	563.5104557823129	5.8075	60	224	5	12	8	0	0	1	0	0	0	2.78341340080112	
i 1	563.7388231292517	3.2825	71	926	5	1	13	8	0	-1	8	0	0	5.0	
i 1	563.7402653061224	1.01	71	224	3	4	16	2	0	-1	2	0	0	3.0	
i 1	563.7424285714286	1.2625	71	224	4	1	13	8	0	-1	8	0	0	5.0	
i 1	563.7655034013605	0.2525	75	224	7	5	2	2	0	1	2	0	0	2.0	
i 1	563.9960340136055	0.7575000000000001	74	722	4	3	9	2	0	-1	2	0	0	3.0	
i 1	563.9960340136055	2.525	75	224	7	5	3	2	0	1	2	0	0	2.0	
i 1	564.2381020408163	0.505	70	722	1	24	10	8	0	-2	8	0	0	4.0	
i 1	564.2409863945578	0.7575000000000001	72	926	6	5	2	2	0	1	2	0	0	2.0	
i 1	564.2467551020408	0.2525	74	224	5	24	11	2	0	-1	2	0	0	6.0	
i 1	564.493149659864	2.525	74	224	5	1	13	2	0	-1	2	0	0	5.0	
i 1	564.7366598639455	1.5150000000000001	74	610	4	3	16	2	0	-2	2	0	0	3.0	
i 1	564.7453129251701	4.545	67	610	5	15	9	5	0	1	5	0	0	2.3195111673342668	
i 1	564.7453129251701	10.352500000000001	60	610	5	15	15	5	0	1	5	0	0	2.3195111673342668	
i 1	564.7460340136055	10.352500000000001	60	610	5	7	9	0	0	1	0	0	0	1.4105596104834173	
i 1	564.7503605442176	0.2525	73	610	1	24	1	8	0	-1	8	0	0	4.0	
i 1	564.9844965986395	0.2525	74	610	4	4	9	2	0	-1	2	0	0	3.0	
i 1	564.9873809523809	0.2525	75	224	7	5	7	2	0	1	2	0	0	2.0	
i 1	565.0140612244898	0.2525	74	926	5	1	8	2	0	-1	2	0	0	5.0	
i 1	565.2395442176871	0.2525	72	224	7	5	2	2	0	-2	2	0	0	2.0	
i 1	565.2604557823129	0.505	71	610	5	1	16	2	0	-1	2	0	0	5.0	
i 1	565.2633401360545	0.2525	71	224	3	4	5	2	0	-1	2	0	0	3.0	
i 1	565.266224489796	0.2525	70	610	1	24	4	2	0	-2	2	0	0	4.0	
i 1	565.4888231292517	2.02	74	224	4	9	1	2	0	-2	2	0	0	2.0	
i 1	565.5111768707483	0.2525	72	926	6	5	8	2	0	1	2	0	0	2.0	
i 1	565.7539659863945	0.2525	74	926	5	1	12	2	0	-1	2	0	0	5.0	
i 1	565.7575714285714	2.02	75	224	7	5	10	2	0	-2	2	0	0	2.0	
i 1	565.7676666666666	1.5150000000000001	71	926	6	2	8	8	0	-1	8	0	0	3.0	
i 1	565.9974761904762	2.02	72	610	6	5	4	8	0	1	8	0	0	2.0	
i 1	566.0104557823129	0.2525	71	224	5	1	3	8	0	-1	8	0	0	5.0	
i 1	566.2532448979592	0.2525	71	926	4	2	11	8	0	-2	8	0	0	3.0	
i 1	566.2597346938776	0.2525	74	610	4	24	13	8	0	-1	8	0	0	6.0	
i 1	566.4844965986395	1.2625	71	610	5	1	13	2	0	-1	2	0	0	5.0	
i 1	566.4844965986395	2.02	74	610	4	3	15	2	0	-2	2	0	0	3.0	
i 1	566.4873809523809	0.2525	70	610	1	24	13	8	0	-2	8	0	0	4.0	
i 1	566.4938707482993	0.2525	72	224	7	5	5	2	0	-2	2	0	0	2.0	
i 1	566.5032448979592	1.2625	71	224	4	1	16	8	0	-1	8	0	0	5.0	
i 1	566.7388231292517	1.7675	74	224	3	3	9	2	0	-2	2	0	0	3.0	
i 1	566.7388231292517	1.01	73	224	1	24	3	8	0	248	8	308	0	4.0	
i 1	566.7676666666666	0.2525	72	926	6	5	6	2	0	1	2	0	0	2.0	
i 1	566.9996394557824	0.2525	72	926	6	5	16	2	0	-2	2	0	0	2.0	
i 1	567.0061292517007	3.7875	74	610	4	24	9	8	0	-1	8	0	0	6.0	
i 1	567.2388231292517	2.02	74	224	5	24	12	2	0	-1	2	0	0	6.0	
i 1	567.2417074829932	1.7675	72	224	7	5	6	2	0	-2	2	0	0	2.0	
i 1	567.2474761904762	1.7675	72	926	6	5	12	2	0	1	2	0	0	2.0	
i 1	567.4823333333334	1.2625	74	224	4	9	12	8	0	-1	8	0	0	2.0	
i 1	567.4945918367347	1.2625	71	926	4	2	16	8	0	-2	8	0	0	3.0	
i 1	567.4967551020408	0.7575000000000001	70	224	1	24	8	8	0	-2	8	0	0	4.0	
i 1	567.7460340136055	0.505	71	224	5	1	14	8	0	-1	8	0	0	5.0	
i 1	567.7582925170068	0.2525	73	610	1	24	7	2	0	-1	2	0	0	4.0	
i 1	568.0025238095238	0.2525	72	610	6	5	5	2	0	-2	2	0	0	2.0	
i 1	568.2402653061224	1.7675	71	926	6	2	12	8	0	-1	8	0	0	3.0	
i 1	568.2438707482993	0.2525	71	224	4	1	6	8	0	-1	8	0	0	5.0	
i 1	568.2503605442176	1.5150000000000001	74	224	4	9	16	2	0	-2	2	0	0	2.0	
i 1	568.2655034013605	0.2525	72	610	6	5	7	8	0	1	8	0	0	2.0	
i 1	568.4823333333334	0.2525	71	224	5	1	15	8	0	-1	8	0	0	5.0	
i 1	568.501081632653	1.5150000000000001	75	224	7	5	5	2	0	1	2	0	0	2.0	
i 1	568.5082925170068	1.2625	72	610	6	5	8	2	0	-2	2	0	0	2.0	
i 1	568.7373809523809	0.505	73	610	1	24	14	2	0	-1	2	0	0	4.0	
i 1	568.7409863945578	1.01	71	610	5	1	11	2	0	-1	2	0	0	5.0	
i 1	568.7474761904762	4.545	74	224	3	3	8	2	0	-2	2	0	0	3.0	
i 1	568.7503605442176	1.01	71	224	4	1	10	8	0	-1	8	0	0	5.0	
i 1	568.9881020408163	0.2525	72	610	6	5	11	8	0	1	8	0	0	2.0	
i 1	569.2344965986395	25.755	60	926	5	14	11	5	0	1	5	0	0	2.8211192209668345	
i 1	569.2460340136055	1.5150000000000001	74	224	4	24	14	2	0	-1	2	0	0	6.0	
i 1	569.2554081632653	4.04	74	610	4	3	7	2	0	-2	2	0	0	3.0	
i 1	569.2590136054422	2.2725	72	926	6	5	14	2	0	-2	2	0	0	2.0	
i 1	569.2618979591837	7.575	60	224	6	12	14	0	0	1	0	0	0	2.78341340080112	
i 1	569.2633401360545	2.2725	75	224	7	5	2	2	0	1	2	0	0	2.0	
i 1	569.2655034013605	0.7575000000000001	70	224	1	24	12	8	0	-2	8	0	0	4.0	
i 1	569.5061292517007	0.2525	73	610	1	24	14	2	0	-2	2	0	0	4.0	
i 1	569.756850340136	1.7675	74	224	5	1	16	2	0	-1	2	0	0	5.0	
i 1	569.9823333333334	0.7575000000000001	72	610	6	5	2	8	0	1	8	0	0	2.0	
i 1	570.0082925170068	0.2525	74	224	4	9	6	2	0	-2	2	0	0	2.0	
i 1	570.2474761904762	0.2525	70	610	1	24	5	8	0	-2	8	0	0	4.0	
i 1	570.248918367347	1.01	71	926	5	1	15	8	0	-1	8	0	0	5.0	
i 1	570.2496394557824	0.2525	71	224	3	4	5	2	0	-1	2	0	0	3.0	
i 1	570.7381020408163	0.2525	74	224	4	9	5	8	0	-1	8	0	0	2.0	
i 1	570.7388231292517	2.02	71	224	4	1	11	8	0	-1	8	0	0	5.0	
i 1	570.7424285714286	2.2725	71	610	5	1	1	2	0	-1	2	0	0	5.0	
i 1	570.7460340136055	3.535	72	926	6	5	3	2	0	1	2	0	0	2.0	
i 1	570.9888231292517	3.2825	72	224	7	5	15	2	0	-2	2	0	0	2.0	
i 1	570.9895442176871	0.7575000000000001	74	224	4	9	1	2	0	-2	2	0	0	2.0	
i 1	570.9960340136055	0.7575000000000001	71	926	6	2	3	8	0	-1	8	0	0	3.0	
i 1	571.4844965986395	0.505	75	224	7	5	4	2	0	1	2	0	0	2.0	
i 1	571.5111768707483	0.7575000000000001	71	926	6	2	11	8	0	-2	8	0	0	3.0	
i 1	571.516224489796	0.7575000000000001	74	224	4	9	5	8	0	-1	8	0	0	2.0	
i 1	571.5176666666666	0.2525	74	610	4	24	10	8	0	-1	8	0	0	6.0	
i 1	571.7481972789116	0.2525	74	224	5	1	5	2	0	-1	2	0	0	5.0	
i 1	571.9938707482993	0.505	72	610	6	5	10	8	0	1	8	0	0	2.0	
i 1	572.0032448979592	0.2525	74	610	4	24	1	8	0	-1	8	0	0	6.0	
i 1	572.2352176870749	2.7775	74	224	5	1	15	2	0	-1	2	0	0	5.0	
i 1	572.2352176870749	0.2525	74	224	4	9	9	2	0	-2	2	0	0	2.0	
i 1	572.2424285714286	2.7775	71	926	5	1	11	8	0	-1	8	0	0	5.0	
i 1	572.4953129251701	0.2525	75	224	7	5	4	2	0	-2	2	0	0	2.0	
i 1	572.5176666666666	0.2525	71	224	3	4	5	2	0	-1	2	0	0	3.0	
i 1	572.7352176870749	1.7675	70	224	1	24	14	8	0	-2	8	0	0	4.0	
i 1	572.7402653061224	0.2525	72	610	6	5	15	8	0	1	8	0	0	2.0	
i 1	572.7409863945578	1.5150000000000001	71	926	6	2	4	8	0	-2	8	0	0	3.0	
i 1	572.7561292517007	1.5150000000000001	74	224	4	9	14	8	0	-1	8	0	0	2.0	
i 1	573.0147823129251	0.2525	71	224	5	1	5	8	0	-1	8	0	0	5.0	
i 1	573.2352176870749	0.2525	71	224	3	4	16	2	0	-1	2	0	0	3.0	
i 1	573.2395442176871	0.2525	74	224	4	24	12	2	0	-1	2	0	0	6.0	
i 1	573.5054081632653	2.2725	74	224	4	9	9	2	0	-2	2	0	0	2.0	
i 1	573.5133401360545	0.2525	75	224	7	5	16	2	0	-2	2	0	0	2.0	
i 1	573.733775510204	1.2625	71	926	6	2	2	8	0	-1	8	0	0	3.0	
i 1	573.7424285714286	1.2625	72	926	6	5	2	2	0	-2	2	0	0	2.0	
i 1	573.7474761904762	1.7675	75	224	7	5	15	2	0	1	2	0	0	2.0	
i 1	574.2445918367347	0.2525	72	610	6	5	14	2	0	-2	2	0	0	2.0	
i 1	574.2481972789116	0.2525	74	926	5	1	4	2	0	-1	2	0	0	5.0	
i 1	574.2481972789116	0.7575000000000001	74	610	4	3	11	2	0	-2	2	0	0	3.0	
i 1	574.4953129251701	1.2625	71	224	4	1	4	8	0	-1	8	0	0	5.0	
i 1	574.4967551020408	1.01	71	610	5	1	10	2	0	-1	2	0	0	5.0	
i 1	574.506850340136	1.01	70	224	1	24	14	8	0	248	8	308	0	4.0	
i 1	574.5147823129251	2.2725	74	224	3	3	12	2	0	-2	2	0	0	3.0	
i 1	574.5147823129251	1.7675	75	224	7	5	8	2	0	-2	2	0	0	2.0	
i 1	574.9830544217687	5.8075	60	610	4	7	16	0	0	1	0	0	0	1.4105596104834173	
i 1	574.9866598639455	1.7675	74	610	5	3	14	2	0	-2	2	0	0	3.0	
i 1	574.9981972789116	0.505	72	926	6	5	7	2	0	-2	2	0	0	2.0	
i 1	575.0046870748299	3.535	74	610	4	24	6	8	0	-1	8	0	0	6.0	
i 1	575.0090136054422	1.2625	72	610	6	5	10	8	0	1	8	0	0	2.0	
i 1	575.0118979591837	1.7675	74	224	4	24	3	2	0	-1	2	0	0	6.0	
i 1	575.0118979591837	0.7575000000000001	71	926	5	2	15	8	0	-1	8	0	0	3.0	
i 1	575.4953129251701	1.2625	70	224	1	24	3	8	0	-2	8	0	0	4.0	
i 1	575.4974761904762	1.01	72	926	6	5	8	2	0	1	2	0	0	2.0	
i 1	575.7611768707483	0.7575000000000001	72	224	7	5	14	2	0	-2	2	0	0	2.0	
i 1	575.7618979591837	0.2525	74	926	5	1	9	2	0	-1	2	0	0	5.0	
i 1	575.7647823129251	0.2525	74	224	4	9	5	8	0	-1	8	0	0	2.0	
i 1	575.9852176870749	1.7675	71	926	6	2	11	8	0	-2	8	0	0	3.0	
i 1	575.9917074829932	0.7575000000000001	75	224	7	5	15	2	0	1	2	0	0	2.0	
i 1	575.9981972789116	0.7575000000000001	71	224	4	1	7	8	0	-1	8	0	0	5.0	
i 1	576.001081632653	1.2625	71	610	5	1	6	2	0	-1	2	0	0	5.0	
i 1	576.001081632653	2.2725	72	610	6	5	7	2	0	-2	2	0	0	2.0	
i 1	576.2438707482993	0.505	74	224	4	9	2	8	0	-1	8	0	0	2.0	
i 1	576.5003605442176	0.2525	75	224	7	5	11	2	0	-2	2	0	0	2.0	
i 1	576.7323333333334	0.2525	74	610	4	4	10	2	0	-1	2	0	0	3.0	
i 1	576.733775510204	4.04	60	1192	4	16	2	5	0	0	5	0	0	2.78341340080112	
i 1	576.7366598639455	0.2525	74	223	4	1	16	8	0	-2	8	0	0	5.0	
i 1	576.743149659864	4.04	67	223	5	19	12	0	0	0	0	0	0	4.760913760899764	
i 1	576.7438707482993	0.2525	72	223	7	5	7	2	0	-2	2	0	0	2.0	
i 1	576.7460340136055	1.2625	72	223	7	5	9	2	0	1	2	0	0	2.0	
i 1	576.7496394557824	18.18	60	223	6	12	2	5	0	0	5	0	0	2.78341340080112	
i 1	576.7539659863945	1.01	74	1192	4	9	1	2	0	-2	2	0	0	2.0	
i 1	576.7554081632653	1.7675	74	223	4	24	14	2	0	-2	2	0	0	6.0	
i 1	576.7597346938776	1.7675	73	1192	1	24	12	8	0	-1	8	0	0	4.0	
i 1	576.7611768707483	15.655	67	223	6	12	10	0	0	1	0	0	0	2.78341340080112	
i 1	576.7647823129251	9.8475	60	1192	4	16	8	5	0	0	5	0	0	2.78341340080112	
i 1	576.9996394557824	3.2825	74	610	5	3	4	2	0	-2	2	0	0	3.0	
i 1	577.2395442176871	0.2525	74	926	5	1	7	2	0	-1	2	0	0	5.0	
i 1	577.243149659864	5.3025	71	223	3	3	11	2	0	-1	2	0	0	3.0	
i 1	577.2640612244898	0.2525	75	1192	6	5	1	2	0	-2	2	0	0	2.0	
i 1	577.4823333333334	0.2525	70	610	1	24	7	8	0	-1	8	0	0	4.0	
i 1	577.4902653061224	3.2825	75	1192	6	5	2	2	0	-2	2	0	0	2.0	
i 1	577.4981972789116	0.2525	71	1192	5	1	8	8	0	-2	8	0	0	5.0	
i 1	577.5140612244898	3.2825	72	926	6	5	15	2	0	-2	2	0	0	2.0	
i 1	577.7424285714286	0.2525	74	223	3	4	3	8	0	-1	8	0	0	3.0	
i 1	577.7525238095238	1.5150000000000001	71	926	5	1	10	8	0	-1	8	0	0	5.0	
i 1	577.9953129251701	1.2625	74	1192	5	1	11	8	0	-2	8	0	0	5.0	
i 1	577.9953129251701	0.7575000000000001	74	1192	4	9	15	2	0	-2	2	0	0	2.0	
i 1	578.0118979591837	0.7575000000000001	71	926	6	2	4	8	0	-2	8	0	0	3.0	
i 1	578.2366598639455	1.01	71	926	5	2	11	8	0	-1	8	0	0	3.0	
i 1	578.2467551020408	0.2525	73	610	1	24	3	8	0	-2	8	0	0	4.0	
i 1	578.251081632653	0.7575000000000001	74	1192	4	9	8	8	0	-1	8	0	0	2.0	
i 1	578.2669455782313	0.2525	72	223	7	5	11	2	0	-2	2	0	0	2.0	
i 1	578.4974761904762	2.2725	71	610	5	1	8	2	0	-1	2	0	0	5.0	
i 1	578.5104557823129	0.2525	72	223	7	5	5	2	0	1	2	0	0	2.0	
i 1	578.7330544217687	2.02	74	223	4	1	6	8	0	-2	8	0	0	5.0	
i 1	579.2395442176871	0.2525	74	223	4	24	14	2	0	-2	2	0	0	6.0	
i 1	579.2676666666666	0.2525	74	223	3	4	1	8	0	-1	8	0	0	3.0	
i 1	579.4953129251701	0.505	74	610	4	24	4	8	0	-1	8	0	0	6.0	
i 1	579.5075714285714	0.2525	72	223	7	5	15	2	0	-2	2	0	0	2.0	
i 1	579.5082925170068	0.2525	74	1192	4	9	3	2	0	-2	2	0	0	2.0	
i 1	579.7496394557824	1.5150000000000001	71	926	5	2	4	8	0	-1	8	0	0	3.0	
i 1	579.7525238095238	0.505	72	223	7	5	4	2	0	1	2	0	0	2.0	
i 1	579.7640612244898	1.7675	74	1192	4	9	15	8	0	-1	8	0	0	2.0	
i 1	580.001081632653	2.2725	74	1192	5	1	16	8	0	-2	8	0	0	5.0	
i 1	580.2481972789116	0.505	75	1192	6	5	2	2	0	-2	2	0	0	2.0	
i 1	580.248918367347	2.02	71	926	5	1	11	8	0	-1	8	0	0	5.0	
i 1	580.2640612244898	2.525	72	926	6	5	6	2	0	1	2	0	0	2.0	
i 1	580.7496394557824	0.2525	74	610	4	24	9	8	0	-1	8	0	0	6.0	
i 1	580.7518027210884	1.7675	74	610	5	3	13	2	0	-2	2	0	0	3.0	
i 1	580.7561292517007	0.2525	72	223	7	5	9	2	0	-2	2	0	0	2.0	
i 1	580.7582925170068	14.14	60	610	6	7	9	0	0	1	0	0	0	1.4105596104834173	
i 1	580.7590136054422	2.02	75	1192	6	5	7	2	0	-2	2	0	0	2.0	
i 1	580.9895442176871	0.2525	75	1192	6	5	11	2	0	-2	2	0	0	2.0	
i 1	581.0082925170068	0.2525	71	1192	5	1	13	8	0	-2	8	0	0	5.0	
i 1	581.2604557823129	0.2525	74	926	5	1	1	2	0	-1	2	0	0	5.0	
i 1	581.5111768707483	1.2625	74	1192	4	9	8	2	0	-2	2	0	0	2.0	
i 1	581.5169455782313	1.2625	71	610	5	1	6	2	0	-1	2	0	0	5.0	
i 1	581.5176666666666	1.2625	71	926	5	2	6	8	0	-2	8	0	0	3.0	
i 1	581.7597346938776	1.01	74	223	4	1	16	8	0	-2	8	0	0	5.0	
i 1	581.9902653061224	0.2525	72	223	7	5	2	2	0	1	2	0	0	2.0	
i 1	582.2323333333334	0.7575000000000001	72	926	6	5	11	2	0	-2	2	0	0	2.0	
i 1	582.2344965986395	2.02	74	223	4	24	14	2	0	-2	2	0	0	6.0	
i 1	582.2409863945578	1.5150000000000001	71	926	5	2	1	8	0	-1	8	0	0	3.0	
i 1	582.2503605442176	0.7575000000000001	75	1192	6	5	3	2	0	-2	2	0	0	2.0	
i 1	582.251081632653	2.02	74	610	4	24	6	8	0	-1	8	0	0	6.0	
i 1	582.2655034013605	1.7675	74	1192	4	9	11	8	0	-1	8	0	0	2.0	
i 1	582.4953129251701	1.2625	73	1192	1	24	13	8	0	-1	8	0	0	4.0	
i 1	582.5097346938776	2.02	72	610	6	5	15	8	0	1	8	0	0	2.0	
i 1	582.5147823129251	2.02	72	223	7	5	5	2	0	-2	2	0	0	2.0	
i 1	582.7388231292517	0.2525	71	223	3	3	5	2	0	-1	2	0	0	3.0	
i 1	582.7561292517007	0.7575000000000001	74	926	5	1	5	2	0	-1	2	0	0	5.0	
i 1	582.9895442176871	0.2525	74	1192	4	9	10	2	0	-2	2	0	0	2.0	
i 1	583.0169455782313	0.2525	72	223	7	5	9	2	0	1	2	0	0	2.0	
i 1	583.2366598639455	4.04	71	223	3	3	8	2	0	-1	2	0	0	3.0	
i 1	583.2381020408163	3.2825	74	610	5	3	10	2	0	-2	2	0	0	3.0	
i 1	583.2481972789116	0.505	72	926	6	5	2	2	0	1	2	0	0	2.0	
i 1	583.5025238095238	1.5150000000000001	71	610	5	1	1	2	0	-1	2	0	0	5.0	
i 1	583.733775510204	1.2625	74	223	4	1	9	8	0	-2	8	0	0	5.0	
i 1	583.7597346938776	0.2525	75	1192	6	5	15	2	0	-2	2	0	0	2.0	
i 1	583.9881020408163	0.2525	71	926	5	2	2	8	0	-2	8	0	0	3.0	
i 1	583.9888231292517	2.2725	72	926	6	5	7	2	0	1	2	0	0	2.0	
i 1	583.993149659864	3.2825	73	1192	1	24	15	8	0	-1	8	0	0	4.0	
i 1	584.0126190476191	2.02	75	1192	6	5	2	2	0	-2	2	0	0	2.0	
i 1	584.2330544217687	0.2525	71	926	5	1	11	8	0	-1	8	0	0	5.0	
i 1	584.251081632653	0.2525	74	610	4	4	13	2	0	-1	2	0	0	3.0	
i 1	584.4917074829932	2.02	74	223	4	24	5	2	0	-2	2	0	0	6.0	
i 1	584.4960340136055	0.2525	74	223	3	4	12	8	0	-1	8	0	0	3.0	
i 1	584.5054081632653	0.2525	72	610	6	5	8	2	0	-2	2	0	0	2.0	
i 1	584.5104557823129	2.02	74	610	4	24	7	8	0	-1	8	0	0	6.0	
i 1	584.7525238095238	0.2525	72	610	6	5	4	8	0	1	8	0	0	2.0	
i 1	584.7582925170068	1.01	74	1192	4	9	13	8	0	-1	8	0	0	2.0	
i 1	584.9881020408163	0.2525	72	926	6	5	13	2	0	-2	2	0	0	2.0	
i 1	585.0046870748299	0.2525	71	926	5	1	5	8	0	-1	8	0	0	5.0	
i 1	585.0090136054422	0.7575000000000001	71	926	5	2	4	8	0	-1	8	0	0	3.0	
i 1	585.2445918367347	0.2525	71	1192	5	1	13	8	0	-2	8	0	0	5.0	
i 1	585.2481972789116	0.2525	73	610	1	24	12	8	0	-1	8	0	0	4.0	
i 1	585.2546870748299	2.7775	72	223	7	5	8	2	0	1	2	0	0	2.0	
i 1	585.4917074829932	1.01	72	610	6	5	7	2	0	-2	2	0	0	2.0	
i 1	585.5061292517007	0.7575000000000001	71	926	5	2	2	8	0	-2	8	0	0	3.0	
i 1	585.5090136054422	0.7575000000000001	74	1192	4	9	14	2	0	-2	2	0	0	2.0	
i 1	585.7359387755102	0.2525	71	610	5	1	8	2	0	-1	2	0	0	5.0	
i 1	585.983775510204	1.01	71	926	5	1	14	8	0	-1	8	0	0	5.0	
i 1	585.9924285714286	1.01	74	1192	5	1	5	8	0	-2	8	0	0	5.0	
i 1	586.2438707482993	0.2525	73	610	1	24	1	2	0	-2	2	0	0	4.0	
i 1	586.2655034013605	0.2525	72	610	6	5	7	8	0	1	8	0	0	2.0	
i 1	586.266224489796	0.505	74	223	3	4	12	8	0	-1	8	0	0	3.0	
i 1	586.4830544217687	0.7575000000000001	72	610	6	5	1	2	0	-2	2	0	0	2.0	
i 1	586.483775510204	1.7675	71	610	5	1	4	2	0	-1	2	0	0	5.0	
i 1	586.4852176870749	3.2825	72	926	6	5	8	2	0	-2	2	0	0	2.0	
i 1	586.5039659863945	0.7575000000000001	74	610	5	3	4	2	0	-2	2	0	0	3.0	
i 1	586.5061292517007	1.5150000000000001	74	223	4	1	11	8	0	-2	8	0	0	5.0	
i 1	586.7366598639455	1.5150000000000001	71	926	5	2	7	8	0	-2	8	0	0	3.0	
i 1	586.7481972789116	2.525	75	1192	6	5	13	2	0	-2	2	0	0	2.0	
i 1	586.7532448979592	1.5150000000000001	74	1192	4	9	7	2	0	-2	2	0	0	2.0	
i 1	586.998918367347	0.505	74	610	4	24	5	8	0	-1	8	0	0	6.0	
i 1	587.2640612244898	0.2525	74	610	4	4	12	2	0	-1	2	0	0	3.0	
i 1	587.4852176870749	2.2725	74	1192	5	9	14	8	0	-1	8	0	0	2.0	
i 1	587.4902653061224	2.7775	74	1192	5	1	14	8	0	-2	8	0	0	5.0	
i 1	587.5155034013605	2.7775	71	926	5	1	7	8	0	-1	8	0	0	5.0	
i 1	587.7453129251701	2.02	71	926	5	2	16	8	0	-1	8	0	0	3.0	
i 1	588.0155034013605	0.2525	72	610	6	5	12	8	0	1	8	0	0	2.0	
i 1	588.2453129251701	0.2525	74	223	4	1	5	8	0	-2	8	0	0	5.0	
i 1	588.2525238095238	0.2525	72	610	6	5	15	2	0	-2	2	0	0	2.0	
i 1	588.2546870748299	0.2525	74	610	4	4	13	2	0	-1	2	0	0	3.0	
i 1	588.4881020408163	6.0600000000000005	74	610	5	3	10	2	0	-2	2	0	0	3.0	
i 1	588.4881020408163	2.525	73	223	1	24	2	8	0	252	8	307	0	4.0	
i 1	588.493149659864	0.2525	71	1192	5	1	3	8	0	-2	8	0	0	5.0	
i 1	588.4945918367347	2.7775	72	926	6	5	8	2	0	1	2	0	0	2.0	
i 1	588.4996394557824	2.2725	71	223	3	3	2	2	0	-1	2	0	0	3.0	
i 1	588.743149659864	2.525	75	1192	6	5	8	2	0	-2	2	0	0	2.0	
i 1	589.2518027210884	0.2525	74	610	4	24	10	8	0	-1	8	0	0	6.0	
i 1	589.483775510204	1.2625	71	610	5	1	10	2	0	-1	2	0	0	5.0	
i 1	589.4844965986395	0.2525	73	1192	1	24	14	8	0	-1	8	0	0	4.0	
i 1	589.4895442176871	1.2625	74	223	4	1	6	8	0	-2	8	0	0	5.0	
i 1	589.7546870748299	0.2525	74	223	3	4	10	8	0	-1	8	0	0	3.0	
i 1	589.7554081632653	0.2525	71	926	5	2	9	8	0	-2	8	0	0	3.0	
i 1	589.7554081632653	0.2525	72	610	6	5	14	8	0	1	8	0	0	2.0	
i 1	589.983775510204	4.04	74	610	4	24	5	8	0	-1	8	0	0	6.0	
i 1	589.9945918367347	0.505	72	610	6	5	12	2	0	-2	2	0	0	2.0	
i 1	590.0046870748299	4.04	74	223	4	24	2	2	0	-2	2	0	0	6.0	
i 1	590.0090136054422	1.7675	74	1192	4	9	16	2	0	-2	2	0	0	2.0	
i 1	590.266224489796	1.5150000000000001	71	926	5	2	14	8	0	-2	8	0	0	3.0	
i 1	590.4859387755102	2.02	75	1192	6	5	12	2	0	-2	2	0	0	2.0	
i 1	590.5104557823129	2.02	72	926	6	5	11	2	0	-2	2	0	0	2.0	
i 1	590.7604557823129	0.2525	74	926	5	1	1	2	0	-1	2	0	0	5.0	
i 1	590.7655034013605	0.2525	74	1192	5	9	4	8	0	-1	8	0	0	2.0	
i 1	590.766224489796	0.2525	71	1192	5	1	9	8	0	-2	8	0	0	5.0	
i 1	590.9873809523809	0.2525	74	223	4	1	9	8	0	-2	8	0	0	5.0	
i 1	591.2438707482993	1.5150000000000001	71	610	5	1	5	2	0	-1	2	0	0	5.0	
i 1	591.251081632653	3.535	71	223	3	3	8	2	0	-1	2	0	0	3.0	
i 1	591.2640612244898	3.0300000000000002	72	610	6	5	6	8	0	1	8	0	0	2.0	
i 1	591.2640612244898	0.2525	72	223	7	5	15	2	0	-2	2	0	0	2.0	
i 1	591.5054081632653	1.2625	74	223	4	1	8	8	0	-2	8	0	0	5.0	
i 1	591.7359387755102	0.505	72	223	7	5	5	2	0	-2	2	0	0	2.0	
i 1	591.7481972789116	0.2525	74	610	4	4	1	2	0	-1	2	0	0	3.0	
i 1	592.0054081632653	0.2525	74	1192	4	9	1	2	0	-2	2	0	0	2.0	
i 1	592.0082925170068	1.01	71	926	5	2	5	8	0	-2	8	0	0	3.0	
i 1	592.2402653061224	1.7675	73	1192	1	24	12	8	0	-1	8	0	0	4.0	
i 1	592.2417074829932	0.7575000000000001	74	1192	5	9	5	2	0	-2	2	0	0	2.0	
i 1	592.2424285714286	1.7675	72	223	5	5	13	2	0	-2	2	0	0	2.0	
i 1	592.243149659864	1.01	74	1192	5	9	9	8	0	-1	8	0	0	2.0	
i 1	592.251081632653	1.2625	71	926	5	2	6	8	0	-1	8	0	0	3.0	
i 1	592.5155034013605	0.2525	75	1192	6	5	11	2	0	-2	2	0	0	2.0	
i 1	592.743149659864	0.2525	71	1192	5	1	10	8	0	-2	8	0	0	5.0	
i 1	592.7481972789116	2.02	72	926	6	5	3	2	0	1	2	0	0	2.0	
i 1	592.7669455782313	0.2525	72	926	6	5	10	2	0	-2	2	0	0	2.0	
i 1	593.0032448979592	0.2525	70	610	1	24	8	8	0	-2	8	0	0	4.0	
i 1	593.0075714285714	1.2625	74	1192	5	1	1	8	0	-2	8	0	0	5.0	
i 1	593.2582925170068	1.5150000000000001	75	1192	6	5	12	2	0	-2	2	0	0	2.0	
i 1	593.2590136054422	0.2525	74	1192	5	9	11	2	0	-2	2	0	0	2.0	
i 1	593.2669455782313	1.01	71	926	5	1	3	8	0	-1	8	0	0	5.0	
i 1	593.483775510204	1.2625	74	223	4	1	2	8	0	-2	8	0	0	5.0	
i 1	593.4902653061224	1.2625	71	610	5	1	7	2	0	-1	2	0	0	5.0	
i 1	593.4953129251701	1.2625	74	1192	5	9	13	8	0	-1	8	0	0	2.0	
i 1	593.7676666666666	1.01	71	926	5	2	5	8	0	-1	8	0	0	3.0	
i 1	594.2373809523809	0.505	72	223	5	5	3	2	0	-2	2	0	0	2.0	
i 1	594.2381020408163	0.2525	71	1192	5	1	4	8	0	-2	8	0	0	5.0	
i 1	594.2381020408163	0.505	71	926	5	2	2	8	0	-2	8	0	0	3.0	
i 1	594.251081632653	0.505	72	926	6	5	8	2	0	-2	2	0	0	2.0	
i 1	594.4902653061224	0.2525	71	926	5	1	4	8	0	-1	8	0	0	5.0	
i 1	594.7424285714286	1.5150000000000001	71	373	3	3	6	2	5001	-1	2	0	0	3.0	
i 1	594.7445918367347	1.5150000000000001	74	689	5	2	3	8	5003	-2	8	0	0	3.0	
i 1	594.7453129251701	1.01	71	373	4	1	3	8	5001	-1	8	0	0	5.0	
i 1	594.7453129251701	1.5150000000000001	75	373	5	5	6	8	5001	-2	8	0	0	2.0	
i 1	594.7496394557824	1.01	74	689	5	1	8	8	5003	-1	8	0	0	5.0	
i 1	594.7539659863945	1.7675	72	689	6	5	5	2	5003	-2	2	0	0	2.0	
i 1	594.7582925170068	0.2525	74	1075	5	9	1	2	0	-1	2	0	0	2.0	
i 1	594.7582925170068	9.09	60	689	6	7	9	5	5001	1	5	0	0	1.4105596104834173	
i 1	594.7633401360545	0.7575000000000001	72	1075	6	5	7	2	0	1	2	0	0	2.0	
i 1	594.7640612244898	0.2525	71	689	5	2	16	8	5003	-1	8	0	0	3.0	
i 1	594.7647823129251	3.2825	60	373	5	12	12	0	5001	0	0	0	0	2.78341340080112	
i 1	594.7647823129251	9.09	67	689	5	14	14	0	5003	1	0	0	0	2.8211192209668345	
i 1	594.7655034013605	0.505	75	689	6	5	13	2	5003	-2	2	0	0	2.0	
i 1	594.7655034013605	9.09	60	689	5	14	2	5	5003	1	5	0	0	2.8211192209668345	
i 1	595.0133401360545	5.05	74	689	5	3	6	2	5001	-2	2	0	0	3.0	
i 1	595.0155034013605	0.2525	71	1075	4	1	2	2	0	-1	2	0	0	5.0	
i 1	595.2417074829932	0.2525	72	373	6	5	15	2	5001	1	2	0	0	2.0	
i 1	595.2496394557824	3.535	71	689	5	1	6	8	5001	-2	8	0	0	5.0	
i 1	595.251081632653	3.535	71	373	4	24	9	8	5001	-2	8	0	0	6.0	
i 1	595.2518027210884	5.05	71	373	3	4	8	2	5001	-1	2	0	0	3.0	
i 1	595.483775510204	3.7875	75	689	6	5	3	2	5003	-2	2	0	0	2.0	
i 1	595.506850340136	2.525	75	1075	5	5	10	2	0	1	2	0	0	2.0	
i 1	595.7496394557824	0.7575000000000001	74	1075	5	9	7	2	0	-1	2	0	0	2.0	
i 1	595.7525238095238	1.01	71	689	5	2	16	8	5003	-1	8	0	0	3.0	
i 1	595.7611768707483	0.2525	74	1075	4	1	14	8	0	-1	8	0	0	5.0	
i 1	595.9823333333334	0.2525	73	689	1	24	11	8	5001	-1	8	0	0	4.0	
i 1	595.9873809523809	0.2525	74	689	4	24	13	8	5001	-1	8	0	0	6.0	
i 1	595.9917074829932	0.2525	71	373	4	1	9	8	5001	-1	8	0	0	5.0	
i 1	596.2323333333334	0.2525	74	689	5	1	4	8	5003	-1	8	0	0	5.0	
i 1	596.4902653061224	3.0300000000000002	74	689	4	24	7	8	5001	-1	8	0	0	6.0	
i 1	596.4902653061224	0.2525	75	689	6	5	4	2	5001	1	2	0	0	2.0	
i 1	596.5032448979592	3.0300000000000002	71	1075	4	1	14	2	0	-1	2	0	0	5.0	
i 1	596.5126190476191	0.7575000000000001	74	1075	5	9	3	2	0	-1	2	0	0	2.0	
i 1	596.7359387755102	0.2525	74	689	4	4	5	8	5001	-1	8	0	0	3.0	
i 1	596.7395442176871	0.2525	70	689	1	24	13	2	5001	-1	2	0	0	4.0	
i 1	596.7590136054422	0.505	72	1075	6	5	10	2	0	1	2	0	0	2.0	
i 1	596.9974761904762	0.2525	72	373	6	5	7	2	5001	1	2	0	0	2.0	
i 1	597.233775510204	0.2525	72	689	6	5	14	2	5001	1	2	0	0	2.0	
i 1	597.2366598639455	0.2525	72	689	6	5	6	2	5003	-2	2	0	0	2.0	
i 1	597.243149659864	0.2525	74	689	5	2	4	8	5003	-2	8	0	0	3.0	
i 1	597.2525238095238	0.2525	74	689	4	4	8	8	5001	-1	8	0	0	3.0	
i 1	597.506850340136	2.02	71	689	5	2	16	8	5003	-1	8	0	0	3.0	
i 1	597.5075714285714	0.7575000000000001	72	1075	6	5	1	2	0	1	2	0	0	2.0	
i 1	597.7424285714286	1.7675	74	1075	5	9	15	2	0	-1	2	0	0	2.0	
i 1	597.9909863945578	2.7775	72	689	6	5	13	2	5003	-2	2	0	0	2.0	
i 1	598.0155034013605	1.2625	75	1075	6	5	6	2	0	1	2	0	0	2.0	
i 1	598.2647823129251	2.2725	75	373	5	5	13	8	5001	-2	8	0	0	2.0	
i 1	598.7323333333334	0.2525	70	689	1	24	15	2	5001	-2	2	0	0	4.0	
i 1	598.7453129251701	2.525	71	373	5	3	11	2	5001	-1	2	0	0	3.0	
i 1	598.7518027210884	5.05	71	373	4	1	5	8	5001	-1	8	0	0	5.0	
i 1	598.7561292517007	2.525	74	689	5	2	16	8	5003	-2	8	0	0	3.0	
i 1	598.7676666666666	5.05	74	689	4	1	3	8	5003	-1	8	0	0	5.0	
i 1	599.2438707482993	2.525	72	689	6	5	16	2	5001	1	2	0	0	2.0	
i 1	599.4960340136055	0.505	74	1075	4	1	13	8	0	-1	8	0	0	5.0	
i 1	599.498918367347	0.2525	71	373	4	24	5	8	5001	-2	8	0	0	6.0	
i 1	599.5054081632653	2.2725	72	373	5	5	12	2	5001	1	2	0	0	2.0	
i 1	599.7546870748299	2.2725	71	689	5	1	7	8	5001	-2	8	0	0	5.0	
i 1	599.9909863945578	1.7675	71	373	4	24	16	8	5001	-2	8	0	0	6.0	
i 1	600.2597346938776	3.2825	74	1075	5	9	11	2	0	-1	2	0	0	2.0	
i 1	600.266224489796	3.2825	71	689	5	2	10	8	5003	-1	8	0	0	3.0	
i 1	600.4974761904762	0.2525	73	689	1	24	5	8	5001	-2	8	0	0	4.0	
i 1	600.5025238095238	2.2725	72	1075	6	5	11	2	0	1	2	0	0	2.0	
i 1	600.7467551020408	1.01	70	373	1	24	2	2	5001	252	2	307	0	4.0	
i 1	600.9881020408163	2.02	75	689	6	5	3	2	5001	1	2	0	0	2.0	
i 1	601.2532448979592	9.3425	74	689	5	3	2	2	5001	-2	2	0	0	3.0	
i 1	601.2532448979592	2.525	71	373	3	4	7	2	5001	-1	2	0	0	3.0	
i 1	601.7424285714286	2.02	72	689	6	5	6	2	5003	-2	2	0	0	2.0	
i 1	601.7467551020408	0.2525	74	689	4	24	11	8	5001	-1	8	0	0	6.0	
i 1	601.7590136054422	2.02	75	373	5	5	12	8	5001	-2	8	0	0	2.0	
i 1	601.7647823129251	0.505	70	689	1	24	5	2	5001	-1	2	0	0	4.0	
i 1	601.9967551020408	0.2525	74	1075	4	1	11	8	0	-1	8	0	0	5.0	
i 1	601.998918367347	0.2525	71	373	4	24	3	8	5001	-2	8	0	0	6.0	
i 1	602.2330544217687	0.2525	71	1075	4	1	10	2	0	-1	2	0	0	5.0	
i 1	602.5046870748299	1.2625	71	373	4	24	2	8	5001	-2	8	0	0	6.0	
i 1	602.5061292517007	0.2525	74	1075	4	1	9	8	0	-1	8	0	0	5.0	
i 1	602.7323333333334	0.505	72	373	5	5	1	2	5001	1	2	0	0	2.0	
i 1	602.751081632653	3.7875	71	373	5	3	15	2	5001	-1	2	0	0	3.0	
i 1	602.756850340136	1.01	71	689	5	1	8	8	5001	-2	8	0	0	5.0	
i 1	602.7647823129251	3.7875	74	689	5	2	13	8	5003	-2	8	0	0	3.0	
i 1	603.0118979591837	0.2525	72	689	6	5	5	2	5001	1	2	0	0	2.0	
i 1	603.2344965986395	0.2525	75	1075	6	5	5	2	0	1	2	0	0	2.0	
i 1	603.2460340136055	0.2525	75	689	6	5	8	2	5001	1	2	0	0	2.0	
i 1	603.4924285714286	0.2525	75	689	6	5	13	2	5003	-2	2	0	0	2.0	
i 1	603.506850340136	0.2525	72	1075	6	5	16	2	0	1	2	0	0	2.0	
i 1	603.733775510204	0.505	75	689	6	5	16	2	5001	1	2	0	0	6.999999999999999	
i 1	603.7402653061224	1.5150000000000001	74	689	4	24	13	8	5001	-1	8	0	0	3.0	
i 1	603.7453129251701	5.8075	60	689	5	25	2	0	5001	1	0	0	0	1.6811266342228133	
i 1	603.7481972789116	2.2725	75	373	6	5	3	8	5001	-2	8	0	0	6.999999999999999	
i 1	603.751081632653	3.0300000000000002	71	689	4	1	15	8	5001	-2	8	0	0	2.0	
i 1	603.751081632653	7.3225	71	373	4	4	8	2	5001	-1	2	0	0	3.0	
i 1	603.7525238095238	4.04	67	1075	4	26	14	0	0	0	0	0	0	1.6811266342228133	
i 1	603.7532448979592	18.9375	67	373	3	27	15	0	5001	1	0	0	0	2.447680837307495	
i 1	603.7539659863945	4.04	60	1075	4	26	4	5	0	1	5	0	0	1.6811266342228133	
i 1	603.7539659863945	2.2725	72	689	6	5	6	2	5003	-2	2	0	0	6.999999999999999	
i 1	603.7626190476191	1.7675	71	1075	4	1	16	2	0	-1	2	0	0	2.0	
i 1	603.7626190476191	18.9375	67	373	3	27	11	0	5001	0	0	0	0	2.447680837307495	
i 1	603.766224489796	3.0300000000000002	71	373	4	24	6	8	5001	-2	8	0	0	3.0	
i 1	603.9996394557824	0.2525	72	689	6	5	16	2	5001	1	2	0	0	6.999999999999999	
i 1	604.2395442176871	0.2525	72	373	5	5	7	2	5001	1	2	0	0	6.999999999999999	
i 1	604.2518027210884	0.2525	75	1075	6	5	12	2	0	1	2	0	0	6.999999999999999	
i 1	604.4974761904762	0.2525	72	1075	6	5	11	2	0	1	2	0	0	6.999999999999999	
i 1	604.7388231292517	3.535	75	689	6	5	15	2	5003	-2	2	0	0	6.999999999999999	
i 1	604.7618979591837	3.0300000000000002	75	1075	6	5	9	2	0	1	2	0	0	6.999999999999999	
i 1	605.2525238095238	0.2525	74	689	4	1	7	8	5003	-1	8	0	0	2.0	
i 1	605.483775510204	2.7775	71	689	6	2	14	8	5003	-1	8	0	0	3.0	
i 1	605.4844965986395	2.2725	74	1075	4	9	1	2	0	-1	2	0	0	2.0	
i 1	605.4981972789116	2.02	74	689	4	24	11	8	5001	-1	8	0	0	3.0	
i 1	605.506850340136	0.2525	74	1075	4	1	15	8	0	-1	8	0	0	2.0	
i 1	605.7582925170068	2.02	71	1075	4	1	4	2	0	-1	2	0	0	2.0	
i 1	605.9866598639455	0.2525	72	373	5	5	4	2	5001	1	2	0	0	6.999999999999999	
i 1	606.016224489796	0.2525	72	1075	6	5	4	2	0	1	2	0	0	6.999999999999999	
i 1	606.2409863945578	0.2525	72	689	6	5	14	2	5003	-2	2	0	0	6.999999999999999	
i 1	606.2597346938776	0.2525	75	373	6	5	14	8	5001	-2	8	0	0	6.999999999999999	
i 1	606.483775510204	4.545	74	689	4	1	8	8	5003	-1	8	0	0	2.0	
i 1	606.4895442176871	4.545	71	373	4	1	6	8	5001	-1	8	0	0	2.0	
i 1	606.498918367347	0.2525	72	689	6	5	13	2	5001	1	2	0	0	6.999999999999999	
i 1	606.501081632653	0.2525	75	689	6	5	4	2	5001	1	2	0	0	6.999999999999999	
i 1	606.7330544217687	0.505	72	373	5	5	4	2	5001	1	2	0	0	6.999999999999999	
i 1	606.9823333333334	0.2525	73	689	1	24	3	8	5001	-1	8	0	0	4.0	
i 1	607.0155034013605	0.2525	75	689	6	5	4	2	5001	1	2	0	0	6.999999999999999	
i 1	607.2438707482993	1.7675	75	373	6	5	3	8	5001	-2	8	0	0	6.999999999999999	
i 1	607.2453129251701	1.7675	72	689	6	5	13	2	5003	-2	2	0	0	6.999999999999999	
i 1	607.4844965986395	2.02	71	373	4	24	11	8	5001	-2	8	0	0	3.0	
i 1	607.516224489796	0.505	73	689	1	24	14	2	5001	-2	2	0	0	4.0	
i 1	607.7344965986395	0.505	71	947	4	9	5	8	0	-1	8	0	0	2.0	
i 1	607.7474761904762	1.5150000000000001	67	947	4	26	7	0	0	1	0	0	0	1.6811266342228133	
i 1	607.7532448979592	1.5150000000000001	67	947	4	26	3	0	0	1	0	0	0	1.6811266342228133	
i 1	607.7561292517007	2.02	71	689	4	1	2	8	5001	-2	8	0	0	2.0	
i 1	607.7633401360545	0.505	75	947	6	5	10	2	0	-2	2	0	0	6.999999999999999	
i 1	608.0032448979592	1.2625	72	373	5	5	10	2	5001	1	2	0	0	6.999999999999999	
i 1	608.0147823129251	2.02	72	689	6	5	3	2	5001	1	2	0	0	6.999999999999999	
i 1	608.2546870748299	0.2525	70	689	1	24	16	8	5001	-1	8	0	0	4.0	
i 1	608.2554081632653	1.01	72	947	6	5	15	2	0	1	2	0	0	6.999999999999999	
i 1	608.256850340136	1.2625	71	373	5	3	3	2	5001	-1	2	0	0	3.0	
i 1	608.2582925170068	1.2625	74	689	5	2	6	8	5003	-2	8	0	0	3.0	
i 1	608.2611768707483	1.2625	75	689	6	5	8	2	5001	1	2	0	0	6.999999999999999	
i 1	609.2453129251701	1.2625	67	1066	4	26	9	5	0	0	5	0	0	1.6811266342228133	
i 1	609.2474761904762	0.2525	72	1066	6	5	13	2	0	1	2	0	0	6.999999999999999	
i 1	609.2546870748299	1.2625	70	1066	1	24	16	2	0	252	2	307	0	4.0	
i 1	609.2561292517007	1.2625	60	1066	4	26	9	5	0	1	5	0	0	1.6811266342228133	
i 1	609.2604557823129	1.2625	75	1066	6	5	13	2	0	-2	2	0	0	6.999999999999999	
i 1	609.4823333333334	1.01	74	689	6	2	16	8	5003	-2	8	0	0	3.0	
i 1	609.4830544217687	1.01	71	373	4	3	1	2	5001	-1	2	0	0	3.0	
i 1	609.4844965986395	0.505	75	373	6	5	7	8	5001	-2	8	0	0	6.999999999999999	
i 1	609.4945918367347	2.525	71	689	6	2	10	8	5003	-1	8	0	0	3.0	
i 1	609.4960340136055	0.2525	74	689	4	24	1	8	5001	-1	8	0	0	3.0	
i 1	609.5082925170068	1.01	71	1066	4	9	1	2	0	-2	2	0	0	2.0	
i 1	609.5126190476191	1.01	75	689	6	5	5	2	5001	1	2	0	0	6.999999999999999	
i 1	609.7445918367347	0.2525	71	1066	4	1	1	8	0	-2	8	0	0	2.0	
i 1	609.7525238095238	0.2525	71	1066	4	1	15	8	0	-1	8	0	0	2.0	
i 1	609.9852176870749	2.525	72	689	6	5	11	2	5003	-2	2	0	0	6.999999999999999	
i 1	609.9866598639455	0.505	74	689	4	24	15	8	5001	-1	8	0	0	3.0	
i 1	609.9881020408163	0.505	72	1066	6	5	1	2	0	1	2	0	0	6.999999999999999	
i 1	609.9953129251701	4.545	71	373	4	24	1	8	5001	-2	8	0	0	3.0	
i 1	610.0133401360545	0.505	71	1066	4	9	15	2	0	-1	2	0	0	2.0	
i 1	610.4888231292517	10.605	60	97	5	26	15	0	5004	1	0	0	0	1.6811266342228133	
i 1	610.4960340136055	0.505	70	97	1	24	11	2	5004	-1	2	0	0	4.0	
i 1	610.4967551020408	4.7975	67	97	5	26	4	5	5004	0	5	0	0	1.6811266342228133	
i 1	610.4974761904762	4.2925	71	595	4	24	4	8	0	-2	8	0	0	3.0	
i 1	610.5054081632653	2.7775	74	595	5	3	9	8	0	-2	8	0	0	3.0	
i 1	610.5111768707483	0.7575000000000001	75	595	6	5	16	2	0	-2	2	0	0	6.999999999999999	
i 1	610.5126190476191	1.5150000000000001	74	97	5	9	7	8	5004	-1	8	0	0	2.0	
i 1	610.5155034013605	0.505	72	97	7	5	13	8	5004	1	8	0	0	6.999999999999999	
i 1	610.516224489796	0.2525	73	595	1	24	5	8	0	-1	8	0	0	4.0	
i 1	610.5169455782313	0.2525	71	97	5	9	1	2	5004	-1	2	0	0	2.0	
i 1	610.5176666666666	2.525	72	97	7	5	4	2	5004	-2	2	0	0	6.999999999999999	
i 1	610.9873809523809	0.2525	73	595	1	24	4	8	0	-2	8	0	0	4.0	
i 1	610.9888231292517	0.505	74	689	4	1	7	2	5003	-2	2	0	0	2.0	
i 1	610.9888231292517	0.2525	74	595	4	1	5	8	0	-2	8	0	0	2.0	
i 1	610.9960340136055	2.2725	71	373	4	3	4	2	5001	-1	2	0	0	3.0	
i 1	611.0126190476191	3.535	75	689	6	5	9	2	5003	-2	2	0	0	6.999999999999999	
i 1	611.243149659864	3.2825	72	97	7	5	4	8	5004	1	8	0	0	6.999999999999999	
i 1	611.2582925170068	0.2525	74	689	4	1	11	8	5003	-1	8	0	0	2.0	
i 1	611.4938707482993	2.02	74	595	4	1	8	8	0	-2	8	0	0	2.0	
i 1	611.4967551020408	2.02	71	373	4	1	11	8	5001	-1	8	0	0	2.0	
i 1	611.516224489796	1.2625	70	97	1	24	11	2	5004	-1	2	0	0	4.0	
i 1	611.7352176870749	1.7675	74	689	6	2	12	8	5003	-2	8	0	0	3.0	
i 1	611.7373809523809	1.7675	71	97	5	9	5	2	5004	-1	2	0	0	2.0	
i 1	612.5018027210884	2.02	74	97	5	9	16	8	5004	-1	8	0	0	2.0	
i 1	612.5018027210884	0.505	75	595	6	5	12	2	0	-2	2	0	0	6.999999999999999	
i 1	612.506850340136	2.02	71	689	6	2	15	8	5003	-1	8	0	0	3.0	
i 1	612.998918367347	0.505	75	373	6	5	16	8	5001	-2	8	0	0	6.999999999999999	
i 1	613.0176666666666	0.2525	72	373	6	5	10	2	5001	1	2	0	0	6.999999999999999	
i 1	613.2395442176871	1.5150000000000001	72	689	6	5	13	2	5003	-2	2	0	0	6.999999999999999	
i 1	613.4830544217687	1.7675	71	373	4	4	10	2	5001	-1	2	0	0	3.0	
i 1	613.4881020408163	4.545	71	97	5	1	11	8	5004	-2	8	0	0	2.0	
i 1	613.5046870748299	4.545	74	689	4	1	16	8	5003	-1	8	0	0	2.0	
i 1	613.5054081632653	2.02	71	595	4	4	2	2	0	-1	2	0	0	3.0	
i 1	613.5169455782313	1.2625	72	97	7	5	16	2	5004	-2	2	0	0	6.999999999999999	
i 1	613.7373809523809	2.7775	75	595	6	5	3	2	0	1	2	0	0	6.999999999999999	
i 1	613.7647823129251	2.525	75	373	6	5	16	8	5001	-2	8	0	0	6.999999999999999	
i 1	614.4830544217687	0.7575000000000001	74	595	5	3	3	8	0	-2	8	0	0	3.0	
i 1	614.4967551020408	3.535	71	373	4	3	1	2	5001	-1	2	0	0	3.0	
i 1	614.5147823129251	0.505	74	595	4	1	2	8	0	-2	8	0	0	2.0	
i 1	614.7344965986395	0.2525	74	97	5	1	12	2	5004	-2	2	0	0	2.0	
i 1	614.7373809523809	0.2525	72	373	6	5	3	2	5001	1	2	0	0	6.999999999999999	
i 1	614.7417074829932	0.2525	75	689	6	5	7	2	5003	-2	2	0	0	6.999999999999999	
i 1	614.9895442176871	0.2525	71	373	4	1	2	8	5001	-1	8	0	0	2.0	
i 1	614.993149659864	0.2525	71	373	4	24	3	8	5001	-2	8	0	0	3.0	
i 1	614.9974761904762	0.2525	72	97	7	5	4	8	5004	1	8	0	0	6.999999999999999	
i 1	615.016224489796	0.2525	72	97	7	5	16	2	5004	-2	2	0	0	6.999999999999999	
i 1	615.2323333333334	1.2625	71	689	6	2	8	8	5003	-1	8	0	0	3.0	
i 1	615.2352176870749	2.7775	74	595	5	3	3	8	0	-2	8	0	0	3.0	
i 1	615.2381020408163	3.7875	72	373	6	5	13	2	5001	1	2	0	0	6.999999999999999	
i 1	615.2388231292517	0.2525	71	373	4	4	3	2	5001	-1	2	0	0	3.0	
i 1	615.251081632653	4.04	75	595	6	5	10	2	0	-2	2	0	0	6.999999999999999	
i 1	615.2554081632653	1.2625	74	97	5	9	6	8	5004	-1	8	0	0	2.0	
i 1	615.7626190476191	3.2825	74	689	6	2	1	8	5003	-2	8	0	0	3.0	
i 1	615.7655034013605	3.2825	71	97	5	9	9	2	5004	-1	2	0	0	2.0	
i 1	616.0018027210884	0.2525	74	689	4	1	8	2	5003	-2	2	0	0	2.0	
i 1	616.2366598639455	0.505	74	595	4	1	1	8	0	-2	8	0	0	2.0	
i 1	616.2554081632653	0.2525	75	689	6	5	13	2	5003	-2	2	0	0	6.999999999999999	
i 1	616.4996394557824	0.2525	72	689	6	5	9	2	5003	-2	2	0	0	6.999999999999999	
i 1	616.5126190476191	0.505	72	97	7	5	1	2	5004	-2	2	0	0	6.999999999999999	
i 1	616.7575714285714	0.2525	71	373	4	24	11	8	5001	-2	8	0	0	3.0	
i 1	616.7669455782313	2.02	71	373	4	1	15	8	5001	-1	8	0	0	2.0	
i 1	616.9902653061224	0.505	75	689	6	5	6	2	5003	-2	2	0	0	6.999999999999999	
i 1	617.0133401360545	1.7675	74	595	4	1	7	8	0	-2	8	0	0	2.0	
i 1	617.4960340136055	0.2525	75	595	6	5	11	2	0	1	2	0	0	6.999999999999999	
i 1	617.7323333333334	0.2525	75	689	6	5	9	2	5003	-2	2	0	0	6.999999999999999	
i 1	617.7366598639455	3.7875	71	373	4	24	13	8	5001	-2	8	0	0	3.0	
i 1	617.7366598639455	3.2825	72	97	7	5	16	2	5004	-2	2	0	0	6.999999999999999	
i 1	617.7546870748299	3.7875	71	595	4	24	7	8	0	-2	8	0	0	3.0	
i 1	617.9844965986395	3.535	72	689	6	5	14	2	5003	-2	2	0	0	6.999999999999999	
i 1	617.9996394557824	2.525	74	97	5	9	8	8	5004	-1	8	0	0	2.0	
i 1	618.0018027210884	2.525	71	689	6	2	5	8	5003	-1	8	0	0	3.0	
i 1	618.256850340136	1.2625	70	97	1	24	13	2	5004	-1	2	0	0	4.0	
i 1	618.7453129251701	0.2525	74	689	4	1	10	2	5003	-2	2	0	0	2.0	
i 1	618.7503605442176	1.2625	71	373	4	4	9	2	5001	-1	2	0	0	3.0	
i 1	618.7582925170068	0.2525	74	689	4	1	10	8	5003	-1	8	0	0	2.0	
i 1	618.766224489796	1.2625	71	595	4	4	1	2	0	-1	2	0	0	3.0	
i 1	618.9873809523809	3.535	71	373	4	3	11	2	5001	-1	2	0	0	3.0	
i 1	618.9873809523809	0.2525	75	689	6	5	15	2	5003	-2	2	0	0	6.999999999999999	
i 1	619.0003605442176	3.535	74	595	5	3	5	8	0	-2	8	0	0	3.0	
i 1	619.006850340136	1.5150000000000001	74	595	4	1	16	8	0	-2	8	0	0	2.0	
i 1	619.0104557823129	1.5150000000000001	71	373	4	1	8	8	5001	-1	8	0	0	2.0	
i 1	619.2554081632653	0.2525	75	595	6	5	8	2	0	1	2	0	0	6.999999999999999	
i 1	619.2590136054422	0.505	72	373	6	5	7	2	5001	1	2	0	0	6.999999999999999	
i 1	619.498918367347	0.7575000000000001	75	595	6	5	4	2	0	-2	2	0	0	6.999999999999999	
i 1	619.7481972789116	0.2525	75	689	6	5	1	2	5003	-2	2	0	0	6.999999999999999	
i 1	619.993149659864	1.2625	70	97	1	24	9	2	5004	-1	2	0	0	4.0	
i 1	620.016224489796	3.2825	72	97	7	5	5	8	5004	1	8	0	0	6.999999999999999	
i 1	620.2676666666666	2.2725	75	689	6	5	9	2	5003	-2	2	0	0	6.999999999999999	
i 1	620.4960340136055	2.02	74	689	4	1	2	8	5003	-1	8	0	0	2.0	
i 1	620.498918367347	2.02	74	689	6	2	6	8	5003	-2	8	0	0	3.0	
i 1	620.5061292517007	4.04	71	97	5	9	10	2	5004	-1	2	0	0	2.0	
i 1	620.5090136054422	0.505	71	97	5	1	13	8	5004	-2	8	0	0	2.0	
i 1	620.9852176870749	2.02	71	97	4	1	13	8	5004	-2	8	0	0	2.0	
i 1	621.0133401360545	0.2525	72	97	7	5	14	2	5004	-2	2	0	0	6.999999999999999	
i 1	621.2676666666666	0.2525	75	595	6	5	6	2	0	1	2	0	0	6.999999999999999	
i 1	621.4852176870749	0.2525	74	689	4	1	14	2	5003	-2	2	0	0	2.0	
i 1	621.5061292517007	0.505	75	595	6	5	4	2	0	-2	2	0	0	6.999999999999999	
i 1	621.5082925170068	0.2525	71	373	4	1	6	8	5001	-1	8	0	0	2.0	
i 1	621.7373809523809	0.2525	71	373	4	24	16	8	5001	-2	8	0	0	3.0	
i 1	621.7539659863945	0.2525	74	595	4	1	13	8	0	-2	8	0	0	2.0	
i 1	621.7626190476191	0.2525	75	373	6	5	14	8	5001	-2	8	0	0	6.999999999999999	
i 1	621.9881020408163	0.2525	74	97	4	1	2	2	5004	-2	2	0	0	2.0	
i 1	621.9924285714286	0.505	71	689	6	2	6	8	5003	-1	8	0	0	3.0	
i 1	621.9974761904762	0.505	71	373	4	1	12	8	5001	-1	8	0	0	2.0	
i 1	621.998918367347	0.505	75	595	6	5	9	2	0	1	2	0	0	6.999999999999999	
i 1	622.0118979591837	0.505	72	373	6	5	15	2	5001	1	2	0	0	6.999999999999999	
i 1	622.2582925170068	0.2525	71	595	4	4	12	2	0	-1	2	0	0	3.0	
i 1	622.2647823129251	1.2625	74	97	5	9	8	8	5004	-1	8	0	0	2.0	
i 1	622.4852176870749	2.02	75	372	6	5	12	2	0	-2	2	0	0	6.999999999999999	
i 1	622.4895442176871	1.01	71	372	4	4	5	8	0	-1	8	0	0	3.0	
i 1	622.4938707482993	0.2525	74	688	4	1	5	8	0	-1	8	0	0	2.0	
i 1	622.4967551020408	1.01	71	372	5	3	13	8	0	-2	8	0	0	3.0	
i 1	622.4981972789116	1.2625	71	372	4	1	15	2	0	-2	2	0	0	2.0	
i 1	622.501081632653	0.505	71	372	4	3	13	2	0	-2	2	0	0	3.0	
i 1	622.5039659863945	2.02	72	372	6	5	14	2	0	1	2	0	0	6.999999999999999	
i 1	622.5075714285714	4.2925	60	372	3	27	7	0	0	0	0	0	0	2.447680837307495	
i 1	622.5090136054422	0.2525	75	688	6	5	1	8	0	1	8	0	0	6.999999999999999	
i 1	622.5097346938776	2.02	71	688	6	2	7	2	0	-2	2	0	0	3.0	
i 1	622.5155034013605	10.1	67	372	3	27	1	5	0	1	5	0	0	2.447680837307495	
i 1	622.5169455782313	1.2625	71	688	4	1	5	2	0	-2	2	0	0	2.0	
i 1	622.7402653061224	2.7775	71	372	4	4	14	2	0	-1	2	0	0	3.0	
i 1	622.7460340136055	0.2525	72	97	7	5	16	2	5004	-2	2	0	0	6.999999999999999	
i 1	622.756850340136	3.535	74	372	4	24	3	8	0	-2	8	0	0	3.0	
i 1	622.7655034013605	3.535	71	372	4	1	10	2	0	-1	2	0	0	2.0	
i 1	623.2655034013605	0.2525	75	688	6	5	12	2	0	1	2	0	0	6.999999999999999	
i 1	623.266224489796	0.2525	75	372	6	5	9	2	0	-2	2	0	0	6.999999999999999	
i 1	623.5032448979592	3.2825	72	372	6	5	11	2	0	-2	2	0	0	6.999999999999999	
i 1	623.5126190476191	3.2825	72	97	7	5	6	8	5004	1	8	0	0	6.999999999999999	
i 1	623.7575714285714	0.2525	74	372	4	24	11	8	0	-2	8	0	0	3.0	
i 1	623.7590136054422	2.7775	71	372	5	3	2	8	0	-2	8	0	0	3.0	
i 1	623.766224489796	3.0300000000000002	74	97	4	1	14	2	5004	-2	2	0	0	2.0	
i 1	623.9888231292517	0.2525	71	688	4	1	2	2	0	-2	2	0	0	2.0	
i 1	624.2323333333334	1.01	74	372	4	24	3	8	0	-2	8	0	0	3.0	
i 1	624.5090136054422	0.2525	75	688	6	5	3	8	0	1	8	0	0	6.999999999999999	
i 1	624.5155034013605	0.2525	74	97	5	9	3	8	5004	-1	8	0	0	2.0	
i 1	624.516224489796	2.2725	71	688	6	2	2	8	0	-1	8	0	0	3.0	
i 1	624.7381020408163	0.2525	75	688	6	5	15	2	0	1	2	0	0	6.999999999999999	
i 1	624.7409863945578	2.02	71	372	4	3	14	2	0	-2	2	0	0	3.0	
i 1	624.7532448979592	0.2525	72	372	6	5	10	2	0	1	2	0	0	6.999999999999999	
i 1	624.9902653061224	0.505	72	97	7	5	14	2	5004	-2	2	0	0	6.999999999999999	
i 1	625.2381020408163	0.2525	71	688	4	1	13	2	0	-2	2	0	0	2.0	
i 1	625.4967551020408	2.2725	75	372	6	5	12	2	0	-2	2	0	0	6.999999999999999	
i 1	625.4974761904762	0.2525	75	372	6	5	14	2	0	-2	2	0	0	6.999999999999999	
i 1	625.5046870748299	0.2525	74	97	5	9	12	8	5004	-1	8	0	0	2.0	
i 1	625.5118979591837	1.2625	74	372	4	24	12	8	0	-2	8	0	0	3.0	
i 1	625.7373809523809	0.7575000000000001	71	372	4	4	14	2	0	-1	2	0	0	3.0	
i 1	625.9859387755102	1.2625	71	688	6	2	6	2	0	-2	2	0	0	3.0	
i 1	625.9859387755102	1.7675	72	372	6	5	15	2	0	1	2	0	0	6.999999999999999	
i 1	626.0039659863945	1.2625	71	97	5	9	12	2	5004	-1	2	0	0	2.0	
i 1	626.2582925170068	4.545	71	688	4	1	7	2	0	-2	2	0	0	2.0	
i 1	626.266224489796	0.505	71	372	4	1	3	2	0	-2	2	0	0	2.0	
i 1	626.5025238095238	1.5150000000000001	71	372	4	4	16	8	0	-1	8	0	0	3.0	
i 1	626.5075714285714	0.2525	74	97	5	9	10	8	5004	-1	8	0	0	2.0	
i 1	626.5155034013605	1.2625	70	97	1	24	2	2	5004	-1	2	0	0	4.0	
i 1	626.733775510204	1.2625	74	97	6	9	9	8	5004	-1	8	0	0	2.0	
i 1	626.7395442176871	0.2525	75	372	6	5	13	2	0	-2	2	0	0	6.999999999999999	
i 1	626.7582925170068	13.8875	67	688	5	14	13	5	0	1	5	0	0	2.3195111673342663	
i 1	626.7597346938776	0.2525	71	97	4	1	4	8	5004	-2	8	0	0	2.0	
i 1	626.7604557823129	0.7575000000000001	74	688	6	1	4	8	0	-1	8	0	0	2.0	
i 1	626.7604557823129	4.04	71	372	3	1	2	2	0	-2	2	0	0	2.0	
i 1	626.9823333333334	0.2525	72	97	7	5	13	8	5004	1	8	0	0	6.999999999999999	
i 1	626.9866598639455	0.2525	74	372	4	24	9	8	0	-2	8	0	0	3.0	
i 1	627.2402653061224	0.2525	71	372	4	3	16	2	0	-2	2	0	0	3.0	
i 1	627.2503605442176	0.7575000000000001	75	372	6	5	15	2	0	-2	2	0	0	6.999999999999999	
i 1	627.2590136054422	1.01	75	688	6	5	13	2	0	1	2	0	0	6.999999999999999	
i 1	627.483775510204	3.535	75	688	6	5	4	8	0	1	8	0	0	6.999999999999999	
i 1	627.4967551020408	1.5150000000000001	71	372	4	4	9	2	0	-1	2	0	0	3.0	
i 1	627.5133401360545	3.535	72	97	7	5	7	2	5004	-2	2	0	0	6.999999999999999	
i 1	627.5155034013605	1.5150000000000001	71	372	5	3	14	8	0	-2	8	0	0	3.0	
i 1	627.5169455782313	0.505	74	372	4	24	12	8	0	-2	8	0	0	3.0	
i 1	627.9945918367347	0.505	74	372	4	24	15	8	0	-2	8	0	0	3.0	
i 1	628.0054081632653	0.2525	72	97	7	5	12	8	5004	1	8	0	0	6.999999999999999	
i 1	628.006850340136	0.505	71	372	4	3	12	2	0	-2	2	0	0	3.0	
i 1	628.0147823129251	0.2525	71	688	6	2	14	2	0	-2	2	0	0	3.0	
i 1	628.2417074829932	0.505	74	372	4	24	6	8	0	-2	8	0	0	3.0	
i 1	628.2474761904762	0.2525	75	372	6	5	4	2	0	-2	2	0	0	6.999999999999999	
i 1	628.4830544217687	1.2625	71	688	6	2	8	2	0	-2	2	0	0	3.0	
i 1	628.4859387755102	0.505	72	372	6	5	11	2	0	-2	2	0	0	6.999999999999999	
i 1	628.5111768707483	1.2625	71	97	5	9	12	2	5004	-1	2	0	0	2.0	
i 1	628.5140612244898	0.2525	74	688	6	1	15	8	0	-1	8	0	0	2.0	
i 1	628.7373809523809	0.2525	74	372	4	24	11	8	0	-2	8	0	0	3.0	
i 1	628.9960340136055	0.2525	72	97	7	5	11	8	5004	1	8	0	0	6.999999999999999	
i 1	628.9967551020408	0.2525	72	372	6	5	11	2	0	1	2	0	0	6.999999999999999	
i 1	629.0018027210884	0.2525	71	372	4	3	10	2	0	-2	2	0	0	3.0	
i 1	629.2525238095238	1.2625	71	372	4	4	9	2	0	-1	2	0	0	3.0	
i 1	629.2532448979592	0.505	75	372	6	5	15	2	0	-2	2	0	0	6.999999999999999	
i 1	629.2633401360545	1.5150000000000001	71	372	5	3	8	8	0	-2	8	0	0	3.0	
i 1	629.483775510204	0.505	72	372	6	5	4	2	0	-2	2	0	0	6.999999999999999	
i 1	629.4909863945578	2.02	71	688	6	2	1	8	0	-1	8	0	0	3.0	
i 1	629.5032448979592	2.02	71	372	4	3	2	2	0	-2	2	0	0	3.0	
i 1	629.5090136054422	0.2525	74	372	4	24	2	8	0	-2	8	0	0	3.0	
i 1	629.7503605442176	0.505	71	97	4	1	10	8	5004	-2	8	0	0	2.0	
i 1	629.998918367347	0.2525	74	372	4	24	16	8	0	-2	8	0	0	3.0	
i 1	630.0111768707483	0.2525	75	372	6	5	15	2	0	-2	2	0	0	6.999999999999999	
i 1	630.2467551020408	3.535	71	372	4	1	12	2	0	-1	2	0	0	2.0	
i 1	630.2532448979592	2.02	75	372	6	5	10	2	0	-2	2	0	0	6.999999999999999	
i 1	630.2647823129251	2.2725	74	372	4	24	9	8	0	-2	8	0	0	3.0	
i 1	630.4981972789116	2.7775	70	97	1	24	3	2	5004	-1	2	0	0	4.0	
i 1	630.5155034013605	1.7675	75	688	6	5	11	2	0	1	2	0	0	6.999999999999999	
i 1	630.751081632653	0.2525	74	97	4	1	13	2	5004	-2	2	0	0	2.0	
i 1	630.7633401360545	1.7675	71	97	5	9	9	2	5004	-1	2	0	0	2.0	
i 1	630.993149659864	0.2525	74	688	6	1	4	8	0	-1	8	0	0	2.0	
i 1	631.0025238095238	1.5150000000000001	71	688	6	2	9	2	0	-2	2	0	0	3.0	
i 1	631.016224489796	0.2525	72	372	6	5	7	2	0	1	2	0	0	6.999999999999999	
i 1	631.233775510204	1.01	74	372	4	24	4	8	0	-2	8	0	0	3.0	
i 1	631.256850340136	0.2525	72	97	7	5	11	2	5004	-2	2	0	0	6.999999999999999	
i 1	631.2618979591837	1.01	74	97	4	1	14	2	5004	-2	2	0	0	2.0	
i 1	631.4960340136055	2.2725	72	372	6	5	9	2	0	1	2	0	0	6.999999999999999	
i 1	631.5140612244898	0.2525	71	372	4	4	9	8	0	-1	8	0	0	3.0	
i 1	631.7445918367347	0.2525	71	372	5	3	14	8	0	-2	8	0	0	3.0	
i 1	631.7539659863945	0.7575000000000001	75	372	6	5	16	2	0	-2	2	0	0	6.999999999999999	
i 1	631.9873809523809	1.2625	74	97	6	9	14	8	5004	-1	8	0	0	2.0	
i 1	632.0133401360545	1.2625	71	372	4	4	1	8	0	-1	8	0	0	3.0	
i 1	632.2330544217687	0.2525	75	688	6	5	6	8	0	1	8	0	0	6.999999999999999	
i 1	632.2344965986395	0.2525	73	372	1	24	9	8	0	-1	8	0	0	4.0	
i 1	632.248918367347	0.2525	71	372	3	1	1	2	0	-2	2	0	0	2.0	
i 1	632.4844965986395	1.01	75	372	6	5	8	2	0	-2	2	0	0	6.999999999999999	
i 1	632.4866598639455	1.2625	74	372	3	24	5	8	0	-2	8	0	0	3.0	
i 1	632.4902653061224	0.2525	71	688	6	2	10	8	0	-1	8	0	0	3.0	
i 1	632.4938707482993	0.2525	72	97	7	5	12	8	5004	1	8	0	0	6.999999999999999	
i 1	632.5104557823129	8.08	67	688	5	13	14	5	0	1	5	0	0	0.9278044669337063	
i 1	632.5111768707483	0.2525	74	372	4	24	10	8	0	-2	8	0	0	3.0	
i 1	632.7409863945578	1.2625	71	372	4	4	5	2	0	-1	2	0	0	3.0	
i 1	632.7503605442176	0.2525	72	97	7	5	16	2	5004	-2	2	0	0	6.999999999999999	
i 1	632.7618979591837	1.2625	71	372	5	3	9	8	0	-2	8	0	0	3.0	
i 1	632.9844965986395	1.7675	72	372	6	5	13	2	0	-2	2	0	0	6.999999999999999	
i 1	632.9945918367347	1.7675	72	97	7	5	2	8	5004	1	8	0	0	6.999999999999999	
i 1	633.0061292517007	0.7575000000000001	71	688	6	2	5	2	0	-2	2	0	0	3.0	
i 1	633.0090136054422	0.7575000000000001	71	97	6	9	14	2	5004	-1	2	0	0	2.0	
i 1	633.0126190476191	0.2525	71	372	3	1	6	2	0	-2	2	0	0	2.0	
i 1	633.2626190476191	1.7675	74	372	4	24	7	8	0	-2	8	0	0	3.0	
i 1	633.2655034013605	1.2625	74	97	4	1	6	2	5004	-2	2	0	0	2.0	
i 1	633.4996394557824	1.5150000000000001	71	372	4	3	1	2	0	-2	2	0	0	3.0	
i 1	633.5133401360545	1.5150000000000001	71	688	6	2	16	8	0	-1	8	0	0	3.0	
i 1	633.7453129251701	4.04	71	372	3	1	12	2	0	-2	2	0	0	2.0	
i 1	633.7597346938776	0.2525	75	688	6	5	11	8	0	1	8	0	0	6.999999999999999	
i 1	633.9823333333334	0.2525	74	97	6	9	12	8	5004	-1	8	0	0	2.0	
i 1	633.9996394557824	2.2725	72	372	6	5	12	2	0	1	2	0	0	6.999999999999999	
i 1	634.0140612244898	3.535	71	688	6	1	16	2	0	-2	2	0	0	2.0	
i 1	634.2366598639455	2.02	75	372	6	5	8	2	0	-2	2	0	0	6.999999999999999	
i 1	634.2546870748299	1.5150000000000001	71	372	4	4	9	2	0	-1	2	0	0	3.0	
i 1	634.4830544217687	1.2625	71	372	5	3	12	8	0	-2	8	0	0	3.0	
i 1	634.7655034013605	0.2525	72	97	7	5	14	2	5004	-2	2	0	0	6.999999999999999	
i 1	634.9909863945578	0.2525	71	688	6	2	3	2	0	-2	2	0	0	3.0	
i 1	634.9960340136055	0.2525	74	688	6	1	16	8	0	-1	8	0	0	2.0	
i 1	635.0075714285714	0.2525	72	372	6	5	12	2	0	-2	2	0	0	6.999999999999999	
i 1	635.2481972789116	0.2525	71	372	4	1	2	2	0	-1	2	0	0	2.0	
i 1	635.2575714285714	0.2525	71	97	6	9	12	2	5004	-1	2	0	0	2.0	
i 1	635.2633401360545	0.2525	72	97	7	5	10	8	5004	1	8	0	0	6.999999999999999	
i 1	635.4938707482993	1.2625	71	372	4	3	2	2	0	-2	2	0	0	3.0	
i 1	635.5061292517007	2.2725	75	372	6	5	3	2	0	-2	2	0	0	6.999999999999999	
i 1	635.5176666666666	1.2625	71	688	6	2	15	8	0	-1	8	0	0	3.0	
i 1	635.7330544217687	2.02	75	688	6	5	15	2	0	1	2	0	0	6.999999999999999	
i 1	636.0003605442176	0.2525	71	372	4	4	12	2	0	-1	2	0	0	3.0	
i 1	636.001081632653	0.505	70	97	1	24	14	2	5004	-1	2	0	0	4.0	
i 1	636.0111768707483	0.2525	74	688	6	1	14	8	0	-1	8	0	0	2.0	
i 1	636.2409863945578	2.02	71	688	6	2	5	2	0	-2	2	0	0	3.0	
i 1	636.2561292517007	2.525	71	97	6	9	1	2	5004	-1	2	0	0	2.0	
i 1	636.2575714285714	0.2525	74	372	3	24	14	8	0	-2	8	0	0	3.0	
i 1	636.2633401360545	0.2525	72	372	6	5	10	2	0	-2	2	0	0	6.999999999999999	
i 1	636.5025238095238	0.7575000000000001	71	372	4	4	8	8	0	-1	8	0	0	3.0	
i 1	636.5111768707483	0.7575000000000001	73	372	1	24	3	8	0	-1	8	0	0	4.0	
i 1	636.5176666666666	0.7575000000000001	74	97	6	9	5	8	5004	-1	8	0	0	2.0	
i 1	636.7474761904762	0.7575000000000001	71	372	5	3	8	8	0	-2	8	0	0	3.0	
i 1	636.7546870748299	0.7575000000000001	71	372	4	4	8	2	0	-1	2	0	0	3.0	
i 1	636.7640612244898	0.2525	72	372	6	5	12	2	0	1	2	0	0	6.999999999999999	
i 1	636.9924285714286	0.2525	72	97	7	5	11	8	5004	1	8	0	0	6.999999999999999	
i 1	636.9945918367347	1.01	70	97	1	24	4	2	5004	-1	2	0	0	4.0	
i 1	637.001081632653	0.2525	71	97	4	1	7	8	5004	-2	8	0	0	2.0	
i 1	637.2525238095238	1.01	71	372	4	1	14	2	0	-1	2	0	0	2.0	
i 1	637.2539659863945	2.02	74	372	3	24	10	8	0	-2	8	0	0	3.0	
i 1	637.2618979591837	2.7775	75	688	6	5	3	8	0	1	8	0	0	6.999999999999999	
i 1	637.4895442176871	2.525	72	97	7	5	13	2	5004	-2	2	0	0	6.999999999999999	
i 1	637.5025238095238	0.2525	71	372	4	3	14	2	0	-2	2	0	0	3.0	
i 1	637.7460340136055	0.2525	72	372	6	5	6	2	0	-2	2	0	0	6.999999999999999	
i 1	637.9844965986395	0.7575000000000001	70	97	1	24	11	2	5004	252	2	307	0	4.0	
i 1	637.9960340136055	1.7675	71	372	5	3	11	8	0	-2	8	0	0	3.0	
i 1	638.0018027210884	0.2525	74	97	4	1	16	2	5004	-2	2	0	0	2.0	
i 1	638.016224489796	1.5150000000000001	71	372	4	4	4	2	0	-1	2	0	0	3.0	
i 1	638.2402653061224	2.2725	71	372	6	1	5	2	0	-1	2	0	0	2.0	
i 1	638.243149659864	0.2525	71	688	5	2	12	2	0	-2	2	0	0	3.0	
i 1	638.2561292517007	2.2725	67	372	5	15	3	0	0	1	0	0	0	1.3917067004005597	
i 1	638.4945918367347	0.2525	71	97	4	1	15	8	5004	-2	8	0	0	2.0	
i 1	638.516224489796	0.2525	72	372	6	5	6	2	0	1	2	0	0	6.999999999999999	
i 1	638.7575714285714	1.7675	71	372	5	3	12	2	0	-2	2	0	0	3.0	
i 1	638.7611768707483	0.2525	70	97	1	24	10	2	5004	-1	2	0	0	4.0	
i 1	638.7676666666666	1.01	74	97	4	1	6	2	5004	-2	2	0	0	2.0	
i 1	638.7676666666666	0.2525	72	372	6	5	4	2	0	-2	2	0	0	6.999999999999999	
i 1	639.0140612244898	1.01	71	688	6	2	4	8	0	-1	8	0	0	3.0	
i 1	639.016224489796	0.7575000000000001	74	372	4	24	15	8	0	-2	8	0	0	3.0	
i 1	639.2496394557824	0.2525	75	372	6	5	6	2	0	-2	2	0	0	6.999999999999999	
i 1	639.498918367347	0.2525	72	97	7	5	2	8	5004	1	8	0	0	6.999999999999999	
i 1	639.516224489796	1.01	74	372	3	24	6	8	0	-2	8	0	0	3.0	
i 1	639.7344965986395	0.2525	71	372	3	1	6	2	0	-2	2	0	0	2.0	
i 1	639.7381020408163	0.505	72	372	6	5	13	2	0	1	2	0	0	6.999999999999999	
i 1	639.9844965986395	0.505	75	372	6	5	4	2	0	-2	2	0	0	6.999999999999999	
i 1	639.9866598639455	0.505	74	688	6	1	10	8	0	-1	8	0	0	2.0	
i 1	639.9981972789116	0.2525	71	372	4	4	13	2	0	-1	2	0	0	3.0	
i 1	639.998918367347	0.2525	71	372	5	3	2	8	0	-2	8	0	0	3.0	
i 1	640.0176666666666	0.505	75	688	6	5	10	2	0	1	2	0	0	6.999999999999999	
i 1	640.2575714285714	0.2525	75	688	6	5	5	8	0	1	8	0	0	6.999999999999999	
i 1	640.2676666666666	0.2525	71	688	6	2	5	8	0	-1	8	0	0	3.0	
i 1	640.4830544217687	26.765	66	584	5	15	6	9	0	0	9	0	0	1.3917067004005597	
i 1	640.4844965986395	0.2525	75	584	6	1	1	2	0	1	2	0	0	2.0	
i 1	640.4859387755102	20.9575	66	900	5	13	6	9	0	0	9	0	0	0.9278044669337063	
i 1	640.4873809523809	0.2525	69	584	4	4	1	1	0	-1	1	0	0	3.0	
i 1	640.4888231292517	32.5725	76	198	1	24	1	17	0	252	17	307	0	4.0	
i 1	640.4967551020408	1.7675	72	198	6	5	6	0	0	0	0	0	0	6.999999999999999	
i 1	640.498918367347	3.535	72	900	6	1	1	2	0	-2	2	0	0	2.0	
i 1	640.5018027210884	1.7675	69	584	6	5	12	0	0	-1	0	0	0	6.999999999999999	
i 1	640.5054081632653	1.5150000000000001	72	198	6	3	4	1	0	0	1	0	0	3.0	
i 1	640.506850340136	3.535	75	198	4	1	6	2	0	-2	2	0	0	2.0	
i 1	640.5104557823129	0.2525	72	198	4	4	7	1	0	0	1	0	0	3.0	
i 1	640.5140612244898	0.505	72	198	3	24	3	8	0	1	8	0	0	3.0	
i 1	640.5147823129251	46.2075	61	198	1	27	2	9	0	252	9	307	0	2.447680837307495	
i 1	640.516224489796	15.15	66	900	5	14	10	6	0	1	6	0	0	2.3195111673342663	
i 1	640.733775510204	1.2625	69	584	5	3	3	1	0	-1	1	0	0	3.0	
i 1	641.0082925170068	0.2525	69	584	6	5	1	0	0	-1	0	0	0	6.999999999999999	
i 1	641.2467551020408	0.2525	72	198	3	24	9	8	0	1	8	0	0	3.0	
i 1	641.4974761904762	1.2625	69	900	5	2	11	0	0	-1	0	0	0	3.0	
i 1	641.5061292517007	1.2625	69	198	6	9	7	1	0	0	1	0	0	2.0	
i 1	641.5104557823129	0.2525	75	198	3	1	11	2	0	-2	2	0	0	2.0	
i 1	641.9953129251701	0.2525	72	900	6	2	3	1	0	-1	1	0	0	3.0	
i 1	642.2323333333334	1.5150000000000001	69	584	6	5	7	0	0	-1	0	0	0	6.999999999999999	
i 1	642.2481972789116	1.2625	69	584	5	3	13	1	0	-1	1	0	0	3.0	
i 1	642.2554081632653	1.5150000000000001	72	198	6	5	14	1	0	0	1	0	0	6.999999999999999	
i 1	642.4852176870749	0.2525	72	900	6	5	8	0	0	-1	0	0	0	6.999999999999999	
i 1	642.5075714285714	1.01	72	198	6	3	15	1	0	0	1	0	0	3.0	
i 1	642.9924285714286	0.7575000000000001	72	198	6	9	1	0	0	-1	0	0	0	2.0	
i 1	643.2604557823129	0.505	72	900	6	2	12	1	0	-1	1	0	0	3.0	
i 1	643.4974761904762	1.5150000000000001	69	900	6	5	1	0	0	0	0	0	0	6.999999999999999	
i 1	643.5155034013605	1.5150000000000001	69	198	7	5	10	0	0	-1	0	0	0	6.999999999999999	
i 1	643.7597346938776	0.2525	69	584	5	3	4	1	0	-1	1	0	0	3.0	
i 1	643.7640612244898	0.2525	72	198	6	3	2	1	0	0	1	0	0	3.0	
i 1	643.9909863945578	0.2525	72	900	5	2	6	1	0	-1	1	0	0	3.0	
i 1	643.9974761904762	0.7575000000000001	75	584	6	1	16	2	0	1	2	0	0	2.0	
i 1	644.0111768707483	29.0375	66	584	5	15	12	6	0	1	6	0	0	1.3917067004005597	
i 1	644.0118979591837	0.2525	72	198	6	9	14	0	0	-1	0	0	0	2.0	
i 1	644.0133401360545	0.7575000000000001	75	198	3	1	8	2	0	-2	2	0	0	2.0	
i 1	644.2453129251701	1.01	69	900	5	2	2	0	0	-1	0	0	0	3.0	
i 1	644.2467551020408	1.01	69	198	6	9	1	1	0	0	1	0	0	2.0	
i 1	644.7417074829932	1.2625	75	584	4	24	2	2	0	1	2	0	0	3.0	
i 1	644.7453129251701	1.2625	72	198	3	24	12	8	0	1	8	0	0	3.0	
i 1	644.9902653061224	2.2725	72	900	6	5	10	0	0	-1	0	0	0	6.999999999999999	
i 1	645.0176666666666	2.2725	69	198	7	5	14	1	0	-1	1	0	0	6.999999999999999	
i 1	645.2575714285714	1.01	69	584	4	4	5	1	0	-1	1	0	0	3.0	
i 1	645.2575714285714	1.01	72	198	5	4	16	1	0	0	1	0	0	3.0	
i 1	645.4866598639455	1.5150000000000001	76	198	1	24	1	16	0	1	16	0	0	4.0	
i 1	645.9830544217687	0.505	75	584	6	1	11	2	0	1	2	0	0	2.0	
i 1	646.0147823129251	0.505	75	198	3	1	11	2	0	-2	2	0	0	2.0	
i 1	646.2359387755102	0.7575000000000001	69	584	5	3	14	1	0	-1	1	0	0	3.0	
i 1	646.2467551020408	0.7575000000000001	72	198	6	3	16	1	0	0	1	0	0	3.0	
i 1	646.4830544217687	1.01	75	584	4	24	14	2	0	1	2	0	0	3.0	
i 1	646.5147823129251	1.01	72	198	3	24	14	8	0	1	8	0	0	3.0	
i 1	646.9852176870749	0.2525	69	198	6	9	15	1	0	0	1	0	0	2.0	
i 1	647.0061292517007	0.2525	69	900	5	2	8	0	0	-1	0	0	0	3.0	
i 1	647.0155034013605	0.2525	73	584	1	24	1	16	0	1	16	0	0	4.0	
i 1	647.2539659863945	0.2525	69	198	7	5	15	0	0	-1	0	0	0	6.999999999999999	
i 1	647.2561292517007	0.2525	69	900	6	5	7	0	0	0	0	0	0	6.999999999999999	
i 1	647.256850340136	0.2525	72	198	6	3	10	1	0	0	1	0	0	3.0	
i 1	647.2618979591837	0.2525	69	584	5	3	13	1	0	-1	1	0	0	3.0	
i 1	647.4881020408163	1.5150000000000001	69	584	6	5	11	0	0	-1	0	0	0	6.999999999999999	
i 1	647.4902653061224	4.04	75	198	4	1	1	2	0	-2	2	0	0	2.0	
i 1	647.4981972789116	0.2525	72	198	6	9	12	0	0	-1	0	0	0	2.0	
i 1	647.5046870748299	0.2525	72	900	5	2	15	1	0	-1	1	0	0	3.0	
i 1	647.5075714285714	1.5150000000000001	72	198	6	5	9	1	0	0	1	0	0	6.999999999999999	
i 1	647.5111768707483	4.04	72	900	6	1	2	2	0	-2	2	0	0	2.0	
i 1	647.7344965986395	1.01	76	198	1	24	12	16	0	1	16	0	0	4.0	
i 1	647.7525238095238	1.01	72	198	6	3	13	1	0	0	1	0	0	3.0	
i 1	647.7597346938776	1.01	69	584	5	3	2	1	0	-1	1	0	0	3.0	
i 1	648.7424285714286	1.01	72	198	6	9	10	0	0	-1	0	0	0	2.0	
i 1	648.7445918367347	1.01	72	900	5	2	5	1	0	-1	1	0	0	3.0	
i 1	648.9844965986395	2.7775	72	198	6	5	2	0	0	0	0	0	0	6.999999999999999	
i 1	649.0018027210884	0.7575000000000001	69	584	6	5	11	0	0	-1	0	0	0	6.999999999999999	
i 1	649.2604557823129	0.2525	73	584	1	24	10	16	0	2	16	0	0	4.0	
i 1	649.498918367347	2.2725	76	198	1	24	15	16	0	1	16	0	0	4.0	
i 1	649.7373809523809	29.0375	61	198	5	16	10	9	0	0	9	0	0	1.8556089338674129	
i 1	649.7460340136055	0.7575000000000001	69	198	6	9	1	1	0	0	1	0	0	2.0	
i 1	649.7633401360545	0.7575000000000001	69	900	5	2	14	0	0	-1	0	0	0	3.0	
i 1	649.7655034013605	2.02	69	584	6	5	7	0	0	-1	0	0	0	6.999999999999999	
i 1	650.506850340136	0.2525	69	584	4	4	7	1	0	-1	1	0	0	3.0	
i 1	650.5082925170068	0.2525	72	198	5	4	4	1	0	0	1	0	0	3.0	
i 1	650.748918367347	0.2525	69	584	5	3	1	1	0	-1	1	0	0	3.0	
i 1	650.7554081632653	0.2525	72	198	6	3	9	1	0	0	1	0	0	3.0	
i 1	650.9960340136055	0.2525	69	198	6	9	5	1	0	0	1	0	0	2.0	
i 1	651.0075714285714	0.2525	69	900	5	2	15	0	0	-1	0	0	0	3.0	
i 1	651.2395442176871	1.01	72	198	6	3	9	1	0	0	1	0	0	3.0	
i 1	651.2402653061224	1.01	69	584	5	3	3	1	0	-1	1	0	0	3.0	
i 1	651.5090136054422	0.505	75	198	3	1	13	2	0	-2	2	0	0	2.0	
i 1	651.5176666666666	0.505	75	584	6	1	2	2	0	1	2	0	0	2.0	
i 1	651.7518027210884	1.2625	69	584	6	5	15	0	0	-1	0	0	0	6.999999999999999	
i 1	651.766224489796	1.2625	72	198	6	5	9	1	0	0	1	0	0	6.999999999999999	
i 1	652.0046870748299	1.01	75	584	4	24	8	2	0	1	2	0	0	3.0	
i 1	652.006850340136	1.01	72	198	3	24	13	8	0	1	8	0	0	3.0	
i 1	652.2467551020408	1.01	76	198	1	24	7	16	0	1	16	0	0	4.0	
i 1	652.2640612244898	1.01	72	198	6	9	10	0	0	-1	0	0	0	2.0	
i 1	652.2647823129251	1.01	72	900	5	2	11	1	0	-1	1	0	0	3.0	
i 1	652.9938707482993	1.01	69	198	7	5	5	0	0	-1	0	0	0	6.999999999999999	
i 1	652.9953129251701	0.505	75	198	3	1	5	2	0	-2	2	0	0	2.0	
i 1	653.0097346938776	1.01	69	900	6	5	13	0	0	0	0	0	0	6.999999999999999	
i 1	653.0126190476191	0.505	75	584	6	1	15	2	0	1	2	0	0	2.0	
i 1	653.256850340136	0.7575000000000001	69	584	5	3	12	1	0	-1	1	0	0	3.0	
i 1	653.2633401360545	0.7575000000000001	72	198	6	3	6	1	0	0	1	0	0	3.0	
i 1	653.4873809523809	0.505	73	584	1	24	13	16	0	2	16	0	0	4.0	
i 1	653.5039659863945	1.5150000000000001	72	198	3	24	5	8	0	1	8	0	0	3.0	
i 1	653.5133401360545	1.5150000000000001	75	584	4	24	1	2	0	1	2	0	0	3.0	
i 1	653.9895442176871	2.02	76	198	1	24	16	16	0	1	16	0	0	4.0	
i 1	654.001081632653	1.5150000000000001	69	198	7	5	5	1	0	-1	1	0	0	6.999999999999999	
i 1	654.0032448979592	0.2525	72	900	5	2	13	1	0	-1	1	0	0	3.0	
i 1	654.0032448979592	0.2525	72	198	6	9	2	0	0	-1	0	0	0	2.0	
i 1	654.006850340136	1.7675	72	900	6	5	1	0	0	-1	0	0	0	6.999999999999999	
i 1	654.2395442176871	0.2525	69	198	6	9	14	1	0	0	1	0	0	2.0	
i 1	654.251081632653	0.2525	69	900	5	2	8	0	0	-1	0	0	0	3.0	
i 1	654.4830544217687	0.2525	72	198	5	4	1	1	0	0	1	0	0	3.0	
i 1	654.5025238095238	0.2525	69	584	4	4	10	1	0	-1	1	0	0	3.0	
i 1	654.7323333333334	1.01	72	198	6	3	16	1	0	0	1	0	0	3.0	
i 1	654.7604557823129	1.01	69	584	5	3	6	1	0	-1	1	0	0	3.0	
i 1	654.9859387755102	3.535	72	900	6	1	12	2	0	-2	2	0	0	2.0	
i 1	655.0097346938776	0.505	75	198	4	1	7	2	0	-2	2	0	0	2.0	
i 1	655.4881020408163	31.0575	66	900	5	14	15	6	0	1	6	0	0	2.3195111673342663	
i 1	655.5118979591837	29.0375	66	198	5	16	1	9	0	1	9	0	0	1.8556089338674129	
i 1	655.5140612244898	3.0300000000000002	75	198	7	1	14	2	0	-2	2	0	0	2.0	
i 1	655.5140612244898	0.2525	69	198	6	5	4	1	0	-1	1	0	0	6.999999999999999	
i 1	655.7373809523809	1.01	69	900	5	2	4	0	0	-1	0	0	0	3.0	
i 1	655.7445918367347	1.5150000000000001	69	198	7	5	15	0	0	-1	0	0	0	6.999999999999999	
i 1	655.7554081632653	1.01	69	198	6	9	13	1	0	0	1	0	0	2.0	
i 1	655.7575714285714	1.5150000000000001	69	900	6	5	10	0	0	0	0	0	0	6.999999999999999	
i 1	656.4830544217687	1.01	76	198	1	24	1	16	0	1	16	0	0	4.0	
i 1	656.7453129251701	0.7575000000000001	72	198	6	3	16	1	0	0	1	0	0	3.0	
i 1	656.7647823129251	0.7575000000000001	69	584	5	3	1	1	0	-1	1	0	0	3.0	
i 1	657.2474761904762	1.2625	69	584	6	5	3	0	0	-1	0	0	0	6.999999999999999	
i 1	657.2532448979592	1.2625	72	198	6	5	13	1	0	0	1	0	0	6.999999999999999	
i 1	657.4902653061224	0.2525	72	198	6	9	10	0	0	-1	0	0	0	2.0	
i 1	657.5155034013605	0.2525	72	900	5	2	15	1	0	-1	1	0	0	3.0	
i 1	657.7474761904762	0.2525	69	584	5	3	8	1	0	-1	1	0	0	3.0	
i 1	657.7532448979592	0.2525	76	584	1	24	12	17	0	2	17	0	0	4.0	
i 1	657.7633401360545	0.2525	72	198	6	3	5	1	0	0	1	0	0	3.0	
i 1	657.9859387755102	0.2525	72	900	5	2	1	1	0	-1	1	0	0	3.0	
i 1	657.9938707482993	0.2525	72	198	6	9	7	0	0	-1	0	0	0	2.0	
i 1	657.9960340136055	2.525	76	198	1	24	4	16	0	1	16	0	0	4.0	
i 1	658.2445918367347	1.01	69	900	5	2	11	0	0	-1	0	0	0	3.0	
i 1	658.2647823129251	1.01	69	198	6	9	7	1	0	0	1	0	0	2.0	
i 1	658.4866598639455	2.2725	69	584	6	5	4	0	0	-1	0	0	0	6.999999999999999	
i 1	658.5097346938776	0.505	75	584	6	1	14	2	0	1	2	0	0	2.0	
i 1	658.5155034013605	2.2725	72	198	6	5	11	0	0	0	0	0	0	6.999999999999999	
i 1	658.5176666666666	0.505	75	198	3	1	5	2	0	-2	2	0	0	2.0	
i 1	658.9866598639455	1.5150000000000001	72	198	3	24	4	8	0	1	8	0	0	3.0	
i 1	659.016224489796	1.5150000000000001	75	584	4	24	10	2	0	1	2	0	0	3.0	
i 1	659.2532448979592	1.01	69	584	4	4	5	1	0	-1	1	0	0	3.0	
i 1	659.2676666666666	1.01	72	198	5	4	3	1	0	0	1	0	0	3.0	
i 1	660.0032448979592	0.505	73	584	1	24	5	16	0	2	16	0	0	4.0	
i 1	660.2460340136055	0.7575000000000001	72	198	6	3	9	1	0	0	1	0	0	3.0	
i 1	660.2554081632653	0.7575000000000001	69	584	5	3	1	1	0	-1	1	0	0	3.0	
i 1	660.4945918367347	0.7575000000000001	75	198	3	1	5	2	0	-2	2	0	0	2.0	
i 1	660.4981972789116	0.7575000000000001	76	198	1	24	14	16	0	252	16	307	0	4.0	
i 1	660.5176666666666	0.7575000000000001	75	584	6	1	5	2	0	1	2	0	0	2.0	
i 1	660.7481972789116	0.2525	69	584	6	5	12	0	0	-1	0	0	0	6.999999999999999	
i 1	660.756850340136	0.2525	72	198	6	5	7	1	0	0	1	0	0	6.999999999999999	
i 1	660.9830544217687	0.2525	69	198	6	9	6	1	0	0	1	0	0	2.0	
i 1	660.9888231292517	0.2525	69	900	5	2	5	0	0	-1	0	0	0	3.0	
i 1	660.9945918367347	1.5150000000000001	69	900	6	5	2	0	0	0	0	0	0	6.999999999999999	
i 1	660.998918367347	0.2525	69	198	7	5	5	0	0	-1	0	0	0	6.999999999999999	
i 1	661.2323333333334	25.25	66	198	5	12	6	6	0	0	6	0	0	1.8556089338674129	
i 1	661.2344965986395	25.25	66	900	5	13	4	9	0	0	9	0	0	0.9278044669337063	
i 1	661.2424285714286	1.2625	75	584	4	24	12	2	0	1	2	0	0	3.0	
i 1	661.2453129251701	1.2625	76	198	1	24	15	16	0	1	16	0	0	4.0	
i 1	661.2474761904762	0.2525	69	584	5	3	14	1	0	-1	1	0	0	3.0	
i 1	661.248918367347	0.2525	72	198	6	3	13	1	0	0	1	0	0	3.0	
i 1	661.2539659863945	1.2625	69	198	6	5	6	0	0	-1	0	0	0	6.999999999999999	
i 1	661.2554081632653	1.2625	72	198	3	24	6	8	0	1	8	0	0	3.0	
i 1	661.4909863945578	0.2525	72	900	5	2	8	1	0	-1	1	0	0	3.0	
i 1	661.5025238095238	0.2525	72	198	6	9	3	0	0	-1	0	0	0	2.0	
i 1	661.7445918367347	1.01	69	584	5	3	12	1	0	-1	1	0	0	3.0	
i 1	661.7532448979592	1.01	72	198	6	3	3	1	0	0	1	0	0	3.0	
i 1	662.2496394557824	0.2525	76	584	1	24	12	17	0	2	17	0	0	4.0	
i 1	662.4830544217687	3.535	75	198	7	1	1	2	0	-2	2	0	0	2.0	
i 1	662.4938707482993	3.535	72	900	4	1	15	2	0	-2	2	0	0	2.0	
i 1	662.4953129251701	2.7775	72	900	6	5	11	0	0	-1	0	0	0	6.999999999999999	
i 1	662.4967551020408	2.7775	69	198	6	5	12	1	0	-1	1	0	0	6.999999999999999	
i 1	662.5169455782313	0.505	76	198	1	24	3	16	0	252	16	307	0	4.0	
i 1	662.7561292517007	1.01	72	198	6	9	2	0	0	-1	0	0	0	2.0	
i 1	662.7582925170068	1.01	72	900	5	2	1	1	0	-1	1	0	0	3.0	
i 1	663.0032448979592	1.2625	76	198	1	24	1	16	0	1	16	0	0	4.0	
i 1	663.7496394557824	0.7575000000000001	69	198	5	9	7	1	0	0	1	0	0	2.0	
i 1	663.7655034013605	0.7575000000000001	69	900	4	2	12	0	0	-1	0	0	0	3.0	
i 1	664.0111768707483	0.2525	73	584	1	24	4	16	0	1	16	0	0	4.0	
i 1	664.4888231292517	0.2525	72	198	5	4	6	1	0	0	1	0	0	3.0	
i 1	664.4917074829932	0.2525	69	584	4	4	3	1	0	-1	1	0	0	3.0	
i 1	664.7395442176871	0.2525	69	584	5	3	3	1	0	-1	1	0	0	3.0	
i 1	664.7402653061224	0.2525	72	198	6	3	14	1	0	0	1	0	0	3.0	
i 1	664.7532448979592	1.01	76	198	1	24	12	16	0	1	16	0	0	4.0	
i 1	664.998918367347	0.2525	69	198	5	9	10	1	0	0	1	0	0	2.0	
i 1	665.0054081632653	0.2525	69	900	4	2	14	0	0	-1	0	0	0	3.0	
i 1	665.2323333333334	0.505	76	584	1	24	15	16	0	2	16	0	0	4.0	
i 1	665.2366598639455	1.01	69	584	5	3	16	1	0	-1	1	0	0	3.0	
i 1	665.243149659864	1.2625	69	198	6	5	10	0	0	-1	0	0	0	6.999999999999999	
i 1	665.2582925170068	1.01	72	198	6	3	13	1	0	0	1	0	0	3.0	
i 1	665.2611768707483	1.2625	69	900	6	5	15	0	0	0	0	0	0	6.999999999999999	
i 1	666.001081632653	0.7575000000000001	75	198	7	1	10	2	0	-2	2	0	0	2.0	
i 1	666.0018027210884	0.7575000000000001	75	584	6	1	12	2	0	1	2	0	0	2.0	
i 1	666.2445918367347	0.7575000000000001	72	900	5	2	2	1	0	-1	1	0	0	3.0	
i 1	666.2474761904762	0.7575000000000001	72	198	6	9	3	0	0	-1	0	0	0	2.0	
i 1	666.2525238095238	0.2525	76	198	1	24	7	16	0	1	16	0	0	4.0	
i 1	666.4852176870749	0.505	72	198	6	5	1	1	0	0	1	0	0	6.999999999999999	
i 1	666.4909863945578	1.01	69	584	6	5	8	0	0	-1	0	0	0	6.999999999999999	
i 1	666.4967551020408	0.7575000000000001	76	198	1	24	1	16	0	252	16	307	0	4.0	
i 1	666.7532448979592	1.2625	75	584	4	24	14	2	0	1	2	0	0	3.0	
i 1	666.7575714285714	0.2525	72	198	3	24	5	8	0	1	8	0	0	3.0	
i 1	666.9830544217687	19.4425	66	198	5	12	4	6	0	1	6	0	0	1.8556089338674129	
i 1	666.9895442176871	19.4425	66	584	5	15	9	9	0	0	9	0	0	1.3917067004005597	
i 1	666.9902653061224	0.2525	72	900	4	2	13	1	0	-1	1	0	0	3.0	
i 1	666.9981972789116	1.01	72	198	5	24	3	8	0	1	8	0	0	3.0	
i 1	667.0046870748299	0.2525	72	198	5	9	9	0	0	-1	0	0	0	2.0	
i 1	667.0097346938776	0.2525	73	584	1	24	4	16	0	1	16	0	0	4.0	
i 1	667.0169455782313	0.505	72	198	5	5	15	1	0	0	1	0	0	6.999999999999999	
i 1	667.2409863945578	0.7575000000000001	69	584	5	3	16	1	0	-1	1	0	0	3.0	
i 1	667.2474761904762	0.7575000000000001	72	198	6	3	7	1	0	0	1	0	0	3.0	
i 1	667.2626190476191	0.7575000000000001	76	198	1	24	7	16	0	1	16	0	0	4.0	
i 1	667.493149659864	1.7675	72	198	6	5	1	0	0	0	0	0	0	6.999999999999999	
i 1	667.5032448979592	1.7675	69	584	6	5	12	0	0	-1	0	0	0	6.999999999999999	
i 1	667.9888231292517	0.505	75	584	4	1	8	2	0	1	2	0	0	2.0	
i 1	667.9888231292517	0.2525	72	198	5	9	13	0	0	-1	0	0	0	2.0	
i 1	667.9902653061224	0.7575000000000001	76	198	1	24	8	16	0	252	16	307	0	4.0	
i 1	668.0075714285714	0.505	75	198	7	1	6	2	0	-2	2	0	0	2.0	
i 1	668.0104557823129	0.2525	72	900	4	2	2	1	0	-1	1	0	0	3.0	
i 1	668.2359387755102	0.2525	69	900	4	2	9	0	0	-1	0	0	0	3.0	
i 1	668.2647823129251	0.2525	69	198	5	9	4	1	0	0	1	0	0	2.0	
i 1	668.483775510204	1.01	72	198	5	24	9	8	0	1	8	0	0	3.0	
i 1	668.4852176870749	0.2525	76	584	1	24	13	17	0	1	17	0	0	4.0	
i 1	668.498918367347	0.2525	69	584	4	4	3	1	0	-1	1	0	0	3.0	
i 1	668.5126190476191	0.2525	72	198	5	4	13	1	0	0	1	0	0	3.0	
i 1	668.5140612244898	1.01	75	584	4	24	5	2	0	1	2	0	0	3.0	
i 1	668.7539659863945	1.01	69	584	5	3	3	1	0	-1	1	0	0	3.0	
i 1	668.7539659863945	0.7575000000000001	76	198	1	24	9	16	0	1	16	0	0	4.0	
i 1	668.7633401360545	1.01	72	198	6	3	8	1	0	0	1	0	0	3.0	
i 1	669.2323333333334	1.5150000000000001	69	584	6	5	7	0	0	-1	0	0	0	6.999999999999999	
i 1	669.2669455782313	1.5150000000000001	72	198	5	5	11	1	0	0	1	0	0	6.999999999999999	
i 1	669.5097346938776	4.04	72	900	4	1	2	2	0	-2	2	0	0	2.0	
i 1	669.5097346938776	4.04	75	198	7	1	1	2	0	-2	2	0	0	2.0	
i 1	669.7590136054422	1.01	69	198	5	9	11	1	0	0	1	0	0	2.0	
i 1	669.7633401360545	1.01	69	900	4	2	9	0	0	-1	0	0	0	3.0	
i 1	670.7395442176871	0.7575000000000001	72	198	6	3	10	1	0	0	1	0	0	3.0	
i 1	670.7532448979592	1.2625	69	900	6	5	9	0	0	0	0	0	0	6.999999999999999	
i 1	670.7575714285714	1.2625	69	198	6	5	4	0	0	-1	0	0	0	6.999999999999999	
i 1	670.7590136054422	0.7575000000000001	69	584	5	3	15	1	0	-1	1	0	0	3.0	
i 1	670.9938707482993	0.2525	76	198	1	24	7	16	0	1	16	0	0	4.0	
i 1	671.5155034013605	0.2525	72	900	4	2	10	1	0	-1	1	0	0	3.0	
i 1	671.5176666666666	0.2525	72	198	5	9	15	0	0	-1	0	0	0	2.0	
i 1	671.7395442176871	0.2525	72	198	6	3	4	1	0	0	1	0	0	3.0	
i 1	671.7561292517007	0.2525	69	584	5	3	10	1	0	-1	1	0	0	3.0	
i 1	671.7626190476191	1.01	76	198	1	24	16	16	0	1	16	0	0	4.0	
i 1	671.9866598639455	0.2525	72	900	4	2	6	1	0	-1	1	0	0	3.0	
i 1	671.9974761904762	2.2725	69	198	6	5	13	1	0	-1	1	0	0	6.999999999999999	
i 1	672.0003605442176	0.7575000000000001	72	900	6	5	14	0	0	-1	0	0	0	6.999999999999999	
i 1	672.006850340136	0.2525	72	198	5	9	4	0	0	-1	0	0	0	2.0	
i 1	672.2467551020408	0.505	69	900	4	2	3	0	0	-1	0	0	0	3.0	
i 1	672.2496394557824	1.01	69	198	5	9	15	1	0	0	1	0	0	2.0	
i 1	672.7330544217687	0.505	69	900	6	2	1	0	0	-1	0	0	0	3.0	
i 1	672.7381020408163	2.7775	76	198	1	24	14	17	0	252	17	307	0	4.645838233520012	
i 1	672.7424285714286	13.635	66	584	5	15	10	6	0	1	6	0	0	1.3917067004005597	
i 1	672.7438707482993	1.5150000000000001	72	900	4	5	1	0	0	-1	0	0	0	6.999999999999999	
i 1	672.7453129251701	2.2725	76	198	1	20	12	17	0	1	17	0	0	0.6458382335200121	
i 1	672.7640612244898	2.2725	76	198	1	20	5	16	0	1	16	0	0	0.6458382335200121	
i 1	673.2381020408163	1.01	69	584	4	4	13	1	0	-1	1	0	0	3.0	
i 1	673.2647823129251	1.01	72	198	5	4	6	1	0	0	1	0	0	3.0	
i 1	673.4852176870749	0.505	75	584	4	1	4	2	0	1	2	0	0	2.0	
i 1	673.493149659864	0.505	75	198	7	1	12	2	0	-2	2	0	0	2.0	
i 1	673.993149659864	1.01	72	198	5	24	12	8	0	1	8	0	0	3.0	
i 1	674.0039659863945	1.01	75	584	4	24	13	2	0	1	2	0	0	3.0	
i 1	674.2481972789116	0.2525	69	900	6	5	7	0	0	0	0	0	0	6.999999999999999	
i 1	674.2525238095238	0.7575000000000001	69	584	4	3	16	1	0	-1	1	0	0	3.0	
i 1	674.2626190476191	0.7575000000000001	72	198	4	3	8	1	0	0	1	0	0	3.0	
i 1	674.2647823129251	0.2525	69	198	6	5	3	0	0	-1	0	0	0	6.999999999999999	
i 1	674.4960340136055	1.5150000000000001	69	584	6	5	3	0	0	-1	0	0	0	6.999999999999999	
i 1	674.5104557823129	1.5150000000000001	72	198	5	5	5	1	0	0	1	0	0	6.999999999999999	
i 1	674.9852176870749	0.505	73	198	1	20	12	17	0	1	17	0	0	0.6458382335200121	
i 1	674.9902653061224	0.505	75	584	4	1	3	2	0	1	2	0	0	2.0	
i 1	674.9924285714286	0.505	75	198	7	1	15	2	0	-2	2	0	0	2.0	
i 1	674.9981972789116	0.2525	69	900	6	2	15	0	0	-1	0	0	0	3.0	
i 1	675.0054081632653	0.2525	69	198	5	9	1	1	0	0	1	0	0	2.0	
i 1	675.2575714285714	0.2525	69	584	4	3	12	1	0	-1	1	0	0	3.0	
i 1	675.2582925170068	0.2525	72	198	4	3	9	1	0	0	1	0	0	3.0	
i 1	675.4852176870749	0.2525	72	198	5	9	1	0	0	-1	0	0	0	2.0	
i 1	675.4873809523809	1.01	76	198	1	20	2	17	0	1	17	0	0	0.6458382335200121	
i 1	675.4917074829932	0.2525	76	198	1	24	11	16	0	1	16	0	0	4.645838233520012	
i 1	675.4960340136055	0.2525	72	900	4	2	12	1	0	-1	1	0	0	3.0	
i 1	675.4996394557824	0.2525	73	900	1	20	3	16	0	1	16	0	0	0.6458382335200121	
i 1	675.5082925170068	1.5150000000000001	75	584	4	24	2	2	0	1	2	0	0	3.0	
i 1	675.5082925170068	0.2525	73	900	1	20	10	16	0	1	16	0	0	0.6458382335200121	
i 1	675.5147823129251	1.5150000000000001	72	198	5	24	9	8	0	1	8	0	0	3.0	
i 1	675.756850340136	0.505	73	198	1	20	8	17	0	2	17	0	0	0.6458382335200121	
i 1	675.7575714285714	1.5150000000000001	76	198	1	24	4	16	0	248	16	308	0	4.645838233520012	
i 1	675.7626190476191	1.01	69	584	4	3	7	1	0	-1	1	0	0	3.0	
i 1	675.7626190476191	1.01	72	198	4	3	10	1	0	0	1	0	0	3.0	
i 1	675.7676666666666	0.505	73	198	1	20	6	17	0	1	17	0	0	0.6458382335200121	
i 1	675.9844965986395	2.7775	69	584	6	5	1	0	0	-1	0	0	0	6.999999999999999	
i 1	675.9953129251701	2.7775	72	198	5	5	13	0	0	0	0	0	0	6.999999999999999	
i 1	676.2417074829932	0.2525	76	584	1	20	15	16	0	1	16	0	0	0.6458382335200121	
i 1	676.2438707482993	0.2525	76	900	1	20	4	16	0	1	16	0	0	0.6458382335200121	
i 1	676.5126190476191	0.2525	76	198	1	20	15	16	0	1	16	0	0	0.6458382335200121	
i 1	676.7373809523809	0.505	76	198	1	20	1	17	0	1	17	0	0	0.6458382335200121	
i 1	676.7503605442176	0.505	76	198	1	20	14	16	0	1	16	0	0	0.6458382335200121	
i 1	676.7539659863945	1.01	72	198	5	9	5	0	0	-1	0	0	0	2.0	
i 1	676.766224489796	1.01	72	900	4	2	10	1	0	-1	1	0	0	3.0	
i 1	676.993149659864	3.535	75	198	7	1	12	2	0	-2	2	0	0	2.0	
i 1	677.0032448979592	3.535	72	900	4	1	10	2	0	-2	2	0	0	2.0	
i 1	677.2561292517007	0.2525	76	900	1	20	7	17	0	2	17	0	0	0.6458382335200121	
i 1	677.2655034013605	0.2525	76	198	1	24	6	16	0	1	16	0	0	4.645838233520012	
i 1	677.501081632653	1.01	76	198	1	20	16	17	0	1	17	0	0	0.6458382335200121	
i 1	677.5090136054422	1.01	76	198	1	20	1	16	0	1	16	0	0	0.6458382335200121	
i 1	677.7352176870749	0.7575000000000001	69	198	5	9	13	1	0	0	1	0	0	2.0	
i 1	677.7554081632653	0.7575000000000001	69	900	6	2	10	0	0	-1	0	0	0	3.0	
i 1	678.4881020408163	0.2525	72	198	4	4	1	1	0	0	1	0	0	3.0	
i 1	678.4960340136055	0.2525	69	584	4	4	12	1	0	-1	1	0	0	3.0	
i 1	678.5090136054422	11.615	61	198	5	16	7	9	0	0	9	0	0	1.8556089338674129	
i 1	678.733775510204	0.2525	76	584	1	20	5	16	0	2	16	0	0	0.6458382335200121	
i 1	678.7388231292517	1.2625	72	198	5	5	13	1	0	0	1	0	0	6.999999999999999	
i 1	678.7424285714286	1.2625	69	584	6	5	1	0	0	-1	0	0	0	6.999999999999999	
i 1	678.7438707482993	1.2625	76	198	1	20	4	17	0	1	17	0	0	0.6458382335200121	
i 1	678.7518027210884	0.2525	72	198	4	3	6	1	0	0	1	0	0	3.0	
i 1	678.756850340136	0.2525	76	900	1	20	7	16	0	1	16	0	0	0.6458382335200121	
i 1	678.766224489796	0.2525	69	584	4	3	8	1	0	-1	1	0	0	3.0	
i 1	678.9859387755102	0.2525	69	198	5	9	15	1	0	0	1	0	0	2.0	
i 1	678.9866598639455	1.01	73	198	1	20	1	17	0	2	17	0	0	0.6458382335200121	
i 1	678.9924285714286	0.2525	69	900	6	2	10	0	0	-1	0	0	0	3.0	
i 1	678.9996394557824	0.2525	73	198	1	20	5	17	0	2	17	0	0	0.6458382335200121	
i 1	679.256850340136	1.01	69	584	4	3	10	1	0	-1	1	0	0	3.0	
i 1	679.2590136054422	1.01	72	198	4	3	10	1	0	0	1	0	0	3.0	
i 1	679.9909863945578	0.505	76	198	1	24	12	16	0	1	16	0	0	4.645838233520012	
i 1	679.9967551020408	0.505	73	900	1	20	13	17	0	2	17	0	0	0.6458382335200121	
i 1	680.0082925170068	1.01	69	198	6	5	11	0	0	-1	0	0	0	6.999999999999999	
i 1	680.0118979591837	1.01	69	900	4	5	2	0	0	0	0	0	0	6.999999999999999	
i 1	680.2359387755102	1.01	72	900	6	2	12	1	0	-1	1	0	0	3.0	
i 1	680.2611768707483	1.01	72	198	5	9	11	0	0	-1	0	0	0	2.0	
i 1	680.4866598639455	0.505	75	584	4	1	2	2	0	1	2	0	0	2.0	
i 1	680.4967551020408	1.2625	76	198	1	20	2	17	0	1	17	0	0	0.6458382335200121	
i 1	680.501081632653	0.505	75	198	7	1	5	2	0	-2	2	0	0	2.0	
i 1	680.5126190476191	1.2625	73	198	1	20	7	17	0	1	17	0	0	0.6458382335200121	
i 1	680.9866598639455	1.5150000000000001	72	198	5	24	3	8	0	1	8	0	0	3.0	
i 1	680.9895442176871	1.5150000000000001	75	584	4	24	9	2	0	1	2	0	0	3.0	
i 1	681.0126190476191	1.7675	69	198	6	5	10	1	0	-1	1	0	0	6.999999999999999	
i 1	681.0140612244898	1.7675	72	900	4	5	16	0	0	-1	0	0	0	6.999999999999999	
i 1	681.2323333333334	0.7575000000000001	69	584	4	3	13	1	0	-1	1	0	0	3.0	
i 1	681.2532448979592	0.7575000000000001	72	198	4	3	11	1	0	0	1	0	0	3.0	
i 1	681.7373809523809	0.505	76	198	1	24	4	16	0	1	16	0	0	4.645838233520012	
i 1	681.7417074829932	0.505	76	584	1	20	1	16	0	1	16	0	0	0.6458382335200121	
i 1	681.7575714285714	0.505	76	900	1	20	3	16	0	2	16	0	0	0.6458382335200121	
i 1	681.9938707482993	0.2525	72	198	5	9	14	0	0	-1	0	0	0	2.0	
i 1	682.0097346938776	0.2525	72	900	6	2	1	1	0	-1	1	0	0	3.0	
i 1	682.2373809523809	0.2525	69	198	5	9	6	1	0	0	1	0	0	2.0	
i 1	682.256850340136	0.505	76	198	1	20	2	16	0	2	16	0	0	0.6458382335200121	
i 1	682.2633401360545	0.2525	69	900	6	2	14	0	0	-1	0	0	0	3.0	
i 1	682.266224489796	0.505	76	198	1	20	12	17	0	1	17	0	0	0.6458382335200121	
i 1	682.4866598639455	0.7575000000000001	75	198	7	1	15	2	0	-2	2	0	0	2.0	
i 1	682.4888231292517	0.7575000000000001	75	584	4	1	7	2	0	1	2	0	0	2.0	
i 1	682.5018027210884	0.2525	69	584	4	4	13	1	0	-1	1	0	0	3.0	
i 1	682.5118979591837	0.2525	72	198	4	4	6	1	0	0	1	0	0	3.0	
i 1	682.7330544217687	1.5150000000000001	69	198	6	5	5	0	0	-1	0	0	0	6.999999999999999	
i 1	682.7445918367347	1.01	69	584	4	3	4	1	0	-1	1	0	0	3.0	
i 1	682.7445918367347	0.2525	73	900	1	20	10	17	0	2	17	0	0	0.6458382335200121	
i 1	682.7503605442176	0.2525	76	198	1	24	3	16	0	1	16	0	0	4.645838233520012	
i 1	682.7575714285714	1.5150000000000001	69	900	4	5	2	0	0	0	0	0	0	6.999999999999999	
i 1	682.7590136054422	1.01	72	198	4	3	8	1	0	0	1	0	0	3.0	
i 1	682.9823333333334	1.5150000000000001	73	198	1	20	5	17	0	2	17	0	0	0.6458382335200121	
i 1	682.9938707482993	1.5150000000000001	76	198	1	20	4	17	0	1	17	0	0	0.6458382335200121	
i 1	683.2424285714286	1.2625	72	198	5	24	8	8	0	1	8	0	0	3.0	
i 1	683.2633401360545	1.2625	75	584	4	24	1	2	0	1	2	0	0	3.0	
i 1	683.7417074829932	0.505	69	198	5	9	12	1	0	0	1	0	0	2.0	
i 1	683.7518027210884	1.01	69	900	6	2	12	0	0	-1	0	0	0	3.0	
i 1	684.2366598639455	5.8075	66	198	5	16	5	9	0	1	9	0	0	1.8556089338674129	
i 1	684.2453129251701	1.2625	69	584	4	5	4	0	0	-1	0	0	0	6.999999999999999	
i 1	684.2460340136055	1.2625	72	198	5	5	1	1	0	0	1	0	0	6.999999999999999	
i 1	684.2496394557824	0.505	69	198	4	9	4	1	0	0	1	0	0	2.0	
i 1	684.4866598639455	0.505	76	198	1	24	6	16	0	1	16	0	0	4.645838233520012	
i 1	684.4909863945578	0.505	76	198	1	20	9	16	0	1	16	0	0	0.6458382335200121	
i 1	684.4996394557824	1.7675	72	900	4	1	12	2	0	-2	2	0	0	2.0	
i 1	684.5111768707483	1.7675	75	198	4	1	2	2	0	-2	2	0	0	2.0	
i 1	684.733775510204	0.7575000000000001	72	198	4	3	7	1	0	0	1	0	0	3.0	
i 1	684.7438707482993	0.7575000000000001	69	584	5	3	14	1	0	-1	1	0	0	3.0	
i 1	684.9859387755102	0.2525	73	900	1	20	13	17	0	1	17	0	0	0.6458382335200121	
i 1	684.9866598639455	0.2525	76	198	1	20	10	17	0	1	17	0	0	0.6458382335200121	
i 1	684.9902653061224	0.2525	76	584	1	24	12	16	0	2	16	0	0	4.645838233520012	
i 1	685.2481972789116	0.7575000000000001	76	198	1	24	3	16	0	1	16	0	0	4.645838233520012	
i 1	685.4844965986395	0.2525	72	198	5	9	15	0	0	-1	0	0	0	2.0	
i 1	685.4967551020408	0.7575000000000001	69	584	6	5	2	0	0	-1	0	0	0	6.999999999999999	
i 1	685.4981972789116	0.2525	72	900	6	2	13	1	0	-1	1	0	0	3.0	
i 1	685.5169455782313	0.7575000000000001	72	198	5	5	12	0	0	0	0	0	0	6.999999999999999	
i 1	685.7395442176871	0.2525	72	198	4	3	13	1	0	0	1	0	0	3.0	
i 1	685.7409863945578	0.2525	69	584	5	3	14	1	0	-1	1	0	0	3.0	
i 1	686.0025238095238	0.2525	72	900	6	2	7	1	0	-1	1	0	0	3.0	
i 1	686.0054081632653	0.2525	73	584	1	24	15	16	0	1	16	0	0	4.645838233520012	
i 1	686.0075714285714	0.2525	72	198	5	9	16	0	0	-1	0	0	0	2.0	
i 1	686.233775510204	1.01	72	696	4	5	5	0	5005	-1	0	0	0	6.999999999999999	
i 1	686.2373809523809	3.7875	61	696	5	12	14	6	0	1	6	0	0	1.8556089338674129	
i 1	686.2395442176871	1.5150000000000001	75	696	4	1	9	2	5005	-2	2	0	0	2.0	
i 1	686.2395442176871	1.01	69	696	5	5	6	0	0	0	0	0	0	6.999999999999999	
i 1	686.2417074829932	1.01	72	696	4	4	15	1	5005	-1	1	0	0	3.0	
i 1	686.2474761904762	3.7875	61	696	5	12	3	6	0	1	6	0	0	1.8556089338674129	
i 1	686.2539659863945	3.7875	61	696	1	27	12	6	0	252	6	307	0	2.447680837307495	
i 1	686.2546870748299	3.7875	61	1082	5	14	12	6	0	1	6	0	0	2.3195111673342663	
i 1	686.2575714285714	3.7875	61	696	5	15	2	6	5005	1	6	0	0	1.3917067004005597	
i 1	686.2582925170068	0.505	73	198	1	20	6	16	0	2	16	0	0	0.6458382335200121	
i 1	686.2590136054422	3.7875	66	696	5	15	8	9	5005	1	9	0	0	1.3917067004005597	
i 1	686.2640612244898	0.505	76	198	1	24	6	16	0	1	16	0	0	4.645838233520012	
i 1	686.2647823129251	3.7875	66	1082	5	13	1	9	0	1	9	0	0	0.9278044669337063	
i 1	686.266224489796	1.5150000000000001	72	696	4	24	8	2	0	-2	2	0	0	3.0	
i 1	686.2676666666666	1.01	69	198	4	9	9	1	0	0	1	0	0	2.0	
i 1	686.7352176870749	0.2525	73	1082	1	20	3	17	0	2	17	0	0	0.6458382335200121	
i 1	686.7424285714286	0.2525	76	696	1	24	3	16	5005	1	16	0	0	4.645838233520012	
i 1	686.7676666666666	0.2525	76	198	1	20	10	17	0	1	17	0	0	0.6458382335200121	
i 1	686.998918367347	0.7575000000000001	76	198	1	24	11	16	0	1	16	0	0	4.645838233520012	
i 1	687.243149659864	1.01	72	696	4	4	13	0	0	-1	0	0	0	3.0	
i 1	687.243149659864	0.2525	72	1082	4	5	10	0	0	0	0	0	0	6.999999999999999	
i 1	687.2474761904762	0.2525	72	696	5	5	4	1	0	0	1	0	0	6.999999999999999	
i 1	687.2676666666666	1.01	72	696	5	3	15	0	5005	-1	0	0	0	3.0	
i 1	687.4924285714286	0.2525	76	198	1	20	14	17	0	1	17	0	0	0.6458382335200121	
i 1	687.4996394557824	0.2525	73	198	1	20	1	17	0	1	17	0	0	0.6458382335200121	
i 1	687.5140612244898	2.525	72	1082	4	5	13	0	0	-1	0	0	0	6.999999999999999	
i 1	687.516224489796	2.525	69	198	6	5	16	0	0	-1	0	0	0	6.999999999999999	
i 1	687.733775510204	0.7575000000000001	72	198	4	1	3	2	0	1	2	0	0	2.0	
i 1	687.733775510204	0.2525	76	696	1	24	4	16	5005	1	16	0	0	4.645838233520012	
i 1	687.7539659863945	0.2525	76	696	1	20	4	16	5005	1	16	0	0	0.6458382335200121	
i 1	687.7647823129251	0.7575000000000001	75	696	4	24	9	2	5005	1	2	0	0	3.0	
i 1	687.9924285714286	0.7575000000000001	76	198	1	20	4	17	0	1	17	0	0	0.6458382335200121	
i 1	687.993149659864	3.0300000000000002	76	696	1	24	5	16	5005	252	16	307	0	4.645838233520012	
i 1	688.0155034013605	0.7575000000000001	73	198	1	20	15	16	0	1	16	0	0	0.6458382335200121	
i 1	688.2597346938776	0.7575000000000001	72	198	5	9	6	0	0	-1	0	0	0	2.0	
i 1	688.2676666666666	0.7575000000000001	72	1082	6	2	13	0	0	-1	0	0	0	3.0	
i 1	688.4909863945578	1.2625	72	696	4	24	5	2	0	-2	2	0	0	3.0	
i 1	688.4967551020408	1.2625	75	696	4	1	7	2	5005	-2	2	0	0	2.0	
i 1	688.748918367347	0.2525	76	1082	1	20	16	16	0	2	16	0	0	0.6458382335200121	
i 1	688.7496394557824	0.2525	76	198	1	24	6	16	0	1	16	0	0	4.645838233520012	
i 1	688.9873809523809	0.2525	76	198	1	20	7	16	0	1	16	0	0	0.6458382335200121	
i 1	688.9888231292517	0.2525	72	696	4	4	1	0	0	-1	0	0	0	3.0	
i 1	688.9960340136055	0.2525	76	198	1	20	4	17	0	1	17	0	0	0.6458382335200121	
i 1	689.001081632653	0.2525	72	696	5	3	2	0	5005	-1	0	0	0	3.0	
i 1	689.2330544217687	0.2525	72	1082	6	2	14	0	0	-1	0	0	0	3.0	
i 1	689.2366598639455	0.2525	76	1082	1	20	1	16	0	2	16	0	0	0.6458382335200121	
i 1	689.2402653061224	0.2525	72	696	4	3	13	1	0	0	1	0	0	3.0	
i 1	689.2590136054422	0.2525	76	696	1	20	5	16	5005	1	16	0	0	0.6458382335200121	
i 1	689.2669455782313	0.2525	76	198	1	24	9	16	0	1	16	0	0	4.645838233520012	
i 1	689.501081632653	0.7575000000000001	73	198	1	20	13	17	0	2	17	0	0	0.6458382335200121	
i 1	689.5025238095238	0.7575000000000001	76	198	1	20	14	17	0	1	17	0	0	0.6458382335200121	
i 1	689.5061292517007	0.2525	72	696	5	3	16	0	5005	-1	0	0	0	3.0	
i 1	689.7424285714286	0.2525	72	198	5	9	1	0	0	-1	0	0	0	2.0	
i 1	689.7481972789116	0.2525	75	198	4	1	14	2	0	-2	2	0	0	2.0	
i 1	689.748918367347	2.02	72	1082	6	2	10	0	0	-1	0	0	0	3.0	
i 1	689.7597346938776	0.2525	75	1082	4	1	7	2	0	-2	2	0	0	2.0	
i 1	689.9844965986395	0.2525	75	198	4	1	2	2	0	-2	2	0	0	6.0	
i 1	689.9852176870749	0.505	72	1082	4	5	9	0	0	-1	0	0	0	2.0	
i 1	689.9909863945578	0.2525	75	1082	4	1	6	2	0	-2	2	0	0	6.0	
i 1	690.001081632653	10.8575	61	696	1	27	16	6	0	248	6	308	0	4.430396782360776	
i 1	690.006850340136	1.7675	72	198	4	9	11	0	0	-1	0	0	0	2.0	
i 1	690.0082925170068	0.505	69	198	6	5	1	0	0	-1	0	0	0	2.0	
i 1	690.2344965986395	3.7875	72	696	3	1	13	2	0	1	2	0	0	6.0	
i 1	690.2518027210884	3.7875	72	1082	4	1	15	2	0	1	2	0	0	6.0	
i 1	690.2561292517007	0.7575000000000001	76	198	1	24	2	16	0	1	16	0	0	4.645838233520012	
i 1	690.2611768707483	0.7575000000000001	73	198	1	20	15	16	0	1	16	0	0	0.6458382335200121	
i 1	690.4881020408163	1.2625	72	696	5	5	14	1	0	0	1	0	0	2.0	
i 1	690.5032448979592	1.2625	72	1082	4	5	11	0	0	0	0	0	0	2.0	
i 1	690.998918367347	0.2525	76	696	1	24	10	16	5005	1	16	0	0	4.645838233520012	
i 1	691.2590136054422	1.5150000000000001	73	198	1	20	10	17	0	1	17	0	0	0.6458382335200121	
i 1	691.2626190476191	1.5150000000000001	76	198	1	24	8	16	0	1	16	0	0	4.645838233520012	
i 1	691.7539659863945	0.7575000000000001	72	696	4	4	13	1	5005	-1	1	0	0	3.0	
i 1	691.7575714285714	1.2625	72	696	4	5	3	0	5005	-1	0	0	0	2.0	
i 1	691.7604557823129	0.7575000000000001	69	198	4	9	9	1	0	0	1	0	0	2.0	
i 1	691.7669455782313	1.2625	69	696	5	5	10	0	0	0	0	0	0	2.0	
i 1	692.4974761904762	0.2525	72	696	4	4	5	0	0	-1	0	0	0	3.0	
i 1	692.5054081632653	0.2525	72	696	5	3	2	0	5005	-1	0	0	0	3.0	
i 1	692.733775510204	0.2525	72	198	4	9	5	0	0	-1	0	0	0	2.0	
i 1	692.7474761904762	1.5150000000000001	76	198	1	20	7	17	0	1	17	0	0	0.6458382335200121	
i 1	692.7582925170068	1.5150000000000001	73	198	1	20	6	17	0	2	17	0	0	0.6458382335200121	
i 1	692.7618979591837	0.2525	72	1082	6	2	14	0	0	-1	0	0	0	3.0	
i 1	692.9823333333334	1.2625	69	198	7	5	1	1	0	-1	1	0	0	2.0	
i 1	692.9844965986395	0.2525	72	696	5	3	5	0	5005	-1	0	0	0	3.0	
i 1	692.9924285714286	0.2525	72	696	4	4	2	0	0	-1	0	0	0	3.0	
i 1	693.0176666666666	1.2625	72	696	4	5	6	1	5005	0	1	0	0	2.0	
i 1	693.2366598639455	1.01	72	1082	6	2	12	0	0	-1	0	0	0	3.0	
i 1	693.2539659863945	1.01	72	696	4	3	4	1	0	0	1	0	0	3.0	
i 1	693.9830544217687	1.2625	75	696	4	1	10	2	5005	-2	2	0	0	6.0	
i 1	694.0018027210884	1.2625	72	696	4	24	1	2	0	-2	2	0	0	7.0	
i 1	694.2409863945578	1.5150000000000001	72	696	4	5	2	0	5005	-1	0	0	0	2.0	
i 1	694.2503605442176	1.01	72	696	5	3	10	0	5005	-1	0	0	0	3.0	
i 1	694.2525238095238	1.01	72	696	4	4	9	0	0	-1	0	0	0	3.0	
i 1	694.256850340136	0.505	73	198	1	20	1	17	0	1	17	0	0	0.6458382335200121	
i 1	694.2647823129251	1.5150000000000001	69	696	5	5	15	0	0	0	0	0	0	2.0	
i 1	694.733775510204	0.7575000000000001	73	198	1	20	16	17	0	2	17	0	0	0.6458382335200121	
i 1	694.7575714285714	0.7575000000000001	76	198	1	20	13	17	0	1	17	0	0	0.6458382335200121	
i 1	695.2417074829932	0.505	75	696	4	24	11	2	5005	1	2	0	0	7.0	
i 1	695.2525238095238	1.01	72	1082	6	2	13	0	0	-1	0	0	0	3.0	
i 1	695.2539659863945	1.01	72	198	4	9	10	0	0	-1	0	0	0	2.0	
i 1	695.266224489796	0.505	72	198	4	1	7	2	0	1	2	0	0	6.0	
i 1	695.4844965986395	0.7575000000000001	76	198	1	24	9	16	0	1	16	0	0	4.645838233520012	
i 1	695.4902653061224	0.7575000000000001	73	198	1	20	15	17	0	1	17	0	0	0.6458382335200121	
i 1	695.7597346938776	1.5150000000000001	72	1082	4	5	11	0	0	0	0	0	0	2.0	
i 1	695.7604557823129	1.01	75	696	4	1	14	2	5005	-2	2	0	0	6.0	
i 1	695.7611768707483	5.05	61	1082	5	25	7	6	0	0	6	0	0	3.6638425792760945	
i 1	695.7626190476191	1.01	72	696	3	24	10	2	0	-2	2	0	0	7.0	
i 1	695.7669455782313	1.5150000000000001	72	696	5	5	5	1	0	0	1	0	0	2.0	
i 1	696.2330544217687	0.2525	69	198	6	9	11	1	0	0	1	0	0	2.0	
i 1	696.2611768707483	0.2525	76	696	1	24	15	16	5005	1	16	0	0	4.645838233520012	
i 1	696.2626190476191	0.2525	72	696	4	4	8	1	5005	-1	1	0	0	3.0	
i 1	696.5025238095238	0.2525	72	696	4	4	5	0	0	-1	0	0	0	3.0	
i 1	696.5075714285714	0.2525	72	696	5	3	1	0	5005	-1	0	0	0	3.0	
i 1	696.5075714285714	1.5150000000000001	76	198	1	24	13	16	0	1	16	0	0	4.645838233520012	
i 1	696.5097346938776	1.5150000000000001	73	198	1	20	8	16	0	1	16	0	0	0.6458382335200121	
i 1	696.7330544217687	0.505	75	198	4	1	16	2	0	-2	2	0	0	6.0	
i 1	696.7438707482993	1.01	72	1082	6	2	5	0	0	-1	0	0	0	3.0	
i 1	696.751081632653	1.01	72	198	4	9	6	0	0	-1	0	0	0	2.0	
i 1	696.7532448979592	0.505	75	1082	5	1	7	2	0	-2	2	0	0	6.0	
i 1	697.2366598639455	2.525	72	1082	6	5	11	0	0	-1	0	0	0	2.0	
i 1	697.251081632653	3.535	72	1082	4	1	3	2	0	1	2	0	0	6.0	
i 1	697.266224489796	3.535	72	696	3	1	16	2	0	1	2	0	0	6.0	
i 1	697.2676666666666	2.525	69	198	7	5	1	0	0	-1	0	0	0	2.0	
i 1	697.7366598639455	1.01	72	696	4	4	16	0	0	-1	0	0	0	3.0	
i 1	697.7402653061224	1.01	72	696	5	3	2	0	5005	-1	0	0	0	3.0	
i 1	697.983775510204	0.2525	73	1082	1	20	8	17	0	1	17	0	0	0.6458382335200121	
i 1	698.001081632653	0.2525	76	696	1	20	10	16	5005	1	16	0	0	0.6458382335200121	
i 1	698.0176666666666	0.2525	76	198	1	20	14	17	0	1	17	0	0	0.6458382335200121	
i 1	698.2409863945578	0.7575000000000001	76	198	1	24	12	16	0	1	16	0	0	4.645838233520012	
i 1	698.7438707482993	0.7575000000000001	72	696	3	3	2	1	0	0	1	0	0	3.0	
i 1	698.7467551020408	0.7575000000000001	72	1082	6	2	16	0	0	-1	0	0	0	3.0	
i 1	698.983775510204	0.2525	76	696	1	24	14	16	5005	1	16	0	0	4.645838233520012	
i 1	699.233775510204	0.2525	76	198	1	24	4	16	0	1	16	0	0	4.645838233520012	
i 1	699.2525238095238	0.2525	76	198	1	20	16	16	0	1	16	0	0	0.6458382335200121	
i 1	699.4909863945578	0.505	76	696	1	20	13	16	5005	1	16	0	0	0.6458382335200121	
i 1	699.5118979591837	0.2525	72	696	5	3	9	0	5005	-1	0	0	0	3.0	
i 1	699.5126190476191	0.505	73	1082	1	20	8	16	0	1	16	0	0	0.6458382335200121	
i 1	699.516224489796	0.2525	72	696	4	4	3	0	0	-1	0	0	0	3.0	
i 1	699.516224489796	0.505	76	198	1	20	16	17	0	1	17	0	0	0.6458382335200121	
i 1	699.7438707482993	0.505	72	198	4	9	7	0	0	-1	0	0	0	2.0	
i 1	699.7525238095238	1.01	72	696	5	5	2	1	0	0	1	0	0	2.0	
i 1	699.7597346938776	0.505	72	1082	6	2	6	0	0	-1	0	0	0	3.0	
i 1	699.766224489796	1.01	72	1082	4	5	7	0	0	0	0	0	0	2.0	
i 1	700.0133401360545	0.7575000000000001	76	198	1	24	5	16	0	1	16	0	0	4.645838233520012	
i 1	700.2438707482993	0.505	72	696	4	4	5	1	5005	-1	1	0	0	3.0	
i 1	700.2626190476191	0.505	69	198	6	9	9	1	0	0	1	0	0	2.0	
i 1	700.7395442176871	6.565	61	3	6	25	1	6	0	1	6	0	0	3.6638425792760945	
i 1	700.7445918367347	1.2625	66	389	1	27	10	6	0	252	6	307	0	4.430396782360776	
i 1	700.7467551020408	0.505	75	696	4	1	5	2	5005	-2	2	0	0	6.0	
i 1	700.7467551020408	1.01	72	3	7	2	9	0	0	0	0	0	0	3.0	
i 1	700.751081632653	1.01	72	3	6	9	13	0	0	0	0	0	0	2.0	
i 1	700.7525238095238	1.2625	72	389	5	5	10	1	0	-1	1	0	0	2.0	
i 1	700.7532448979592	1.2625	61	389	1	27	7	9	0	252	9	307	0	4.430396782360776	
i 1	700.7575714285714	1.7675	72	696	4	5	6	1	5005	0	1	0	0	2.0	
i 1	700.7590136054422	0.505	75	389	3	1	14	2	0	1	2	0	0	6.0	
i 1	701.2438707482993	0.7575000000000001	72	389	3	24	10	2	0	1	2	0	0	7.0	
i 1	701.248918367347	1.01	75	696	4	24	14	2	5005	1	2	0	0	7.0	
i 1	701.5025238095238	11.615	66	3	6	25	1	9	0	1	9	0	0	3.6638425792760945	
i 1	701.5097346938776	0.505	69	389	3	3	16	1	0	0	1	0	0	3.0	
i 1	701.733775510204	0.7575000000000001	72	696	5	3	4	0	5005	-1	0	0	0	3.0	
i 1	701.9909863945578	30.3	61	3	1	27	8	9	0	252	9	307	0	4.430396782360776	
i 1	701.9924285714286	0.505	69	3	5	5	16	1	0	0	1	0	0	2.0	
i 1	701.9938707482993	0.2525	72	3	3	24	6	2	0	-2	2	0	0	7.0	
i 1	701.9974761904762	0.7575000000000001	73	389	1	20	8	17	0	1	17	0	0	0.6458382335200121	
i 1	702.0054081632653	0.505	69	3	3	3	15	0	0	0	0	0	0	3.0	
i 1	702.0133401360545	30.3	76	3	1	24	16	16	0	248	16	308	0	4.645838233520012	
i 1	702.0147823129251	0.2525	72	389	5	9	9	1	0	0	1	0	0	2.0	
i 1	702.2539659863945	0.505	75	696	4	1	15	2	5005	-2	2	0	0	6.0	
i 1	702.266224489796	0.505	75	3	3	1	2	2	0	1	2	0	0	6.0	
i 1	702.4888231292517	1.5150000000000001	72	696	4	5	14	0	5005	-1	0	0	0	2.0	
i 1	702.5025238095238	1.5150000000000001	69	3	7	5	10	0	0	-1	0	0	0	2.0	
i 1	702.5032448979592	0.2525	69	3	7	2	16	0	0	0	0	0	0	3.0	
i 1	702.5097346938776	0.2525	72	389	5	9	6	1	0	0	1	0	0	2.0	
i 1	702.7352176870749	0.505	69	3	3	3	11	0	0	0	0	0	0	3.0	
i 1	702.7352176870749	1.01	73	389	1	24	9	17	0	2	17	0	0	4.645838233520012	
i 1	702.7561292517007	0.2525	72	696	4	4	11	1	5005	-1	1	0	0	3.0	
i 1	702.7611768707483	0.505	72	696	5	3	16	0	5005	-1	0	0	0	3.0	
i 1	702.7618979591837	1.5150000000000001	72	3	6	1	4	2	0	1	2	0	0	6.0	
i 1	702.7633401360545	1.5150000000000001	75	389	4	1	13	2	0	-2	2	0	0	6.0	
i 1	703.0039659863945	1.2625	72	389	5	9	15	1	0	0	1	0	0	2.0	
i 1	703.0155034013605	1.2625	72	3	7	2	16	0	0	0	0	0	0	3.0	
i 1	703.756850340136	0.7575000000000001	73	389	1	20	1	17	0	1	17	0	0	0.6458382335200121	
i 1	703.7575714285714	0.2525	69	3	7	2	15	0	0	0	0	0	0	3.0	
i 1	703.9873809523809	1.2625	69	3	7	5	16	0	0	-1	0	0	0	2.0	
i 1	703.9895442176871	1.2625	72	696	4	4	12	1	5005	-1	1	0	0	3.0	
i 1	703.9945918367347	1.2625	69	389	4	5	15	0	0	0	0	0	0	2.0	
i 1	704.2409863945578	3.535	75	389	4	1	7	2	0	1	2	0	0	6.0	
i 1	704.2481972789116	1.01	72	3	3	4	9	1	0	0	1	0	0	3.0	
i 1	704.2604557823129	3.535	72	3	6	1	1	2	0	-2	2	0	0	6.0	
i 1	704.5032448979592	0.2525	72	389	5	9	14	1	0	0	1	0	0	2.0	
i 1	704.5155034013605	1.2625	73	389	1	24	13	17	0	2	17	0	0	4.645838233520012	
i 1	705.0155034013605	2.2725	69	3	7	5	1	1	0	-1	1	0	0	2.0	
i 1	705.0155034013605	2.525	69	389	4	5	12	0	0	-1	0	0	0	2.0	
i 1	705.0169455782313	1.5150000000000001	69	3	3	3	7	0	0	0	0	0	0	3.0	
i 1	705.2323333333334	0.2525	73	3	3	20	14	16	0	2	16	0	0	0.6458382335200121	
i 1	705.2344965986395	0.2525	75	696	4	1	2	2	5005	-2	2	0	0	6.0	
i 1	705.2388231292517	0.2525	72	3	7	2	16	0	0	0	0	0	0	3.0	
i 1	705.2453129251701	0.505	73	389	1	20	13	16	0	1	16	0	0	0.6458382335200121	
i 1	705.2546870748299	0.2525	73	696	1	20	12	16	5005	2	16	0	0	0.6458382335200121	
i 1	705.2582925170068	0.2525	73	696	1	24	3	16	5005	1	16	0	0	4.645838233520012	
i 1	705.2618979591837	1.2625	72	696	5	3	1	0	5005	-1	0	0	0	3.0	
i 1	705.5046870748299	0.2525	72	389	5	9	8	1	0	0	1	0	0	2.0	
i 1	705.5097346938776	0.2525	76	389	2	20	11	17	0	1	17	0	0	0.6458382335200121	
i 1	705.7323333333334	0.2525	73	696	1	20	10	17	5005	2	17	0	0	0.6458382335200121	
i 1	705.756850340136	0.2525	76	696	1	24	7	17	5005	1	17	0	0	4.645838233520012	
i 1	705.983775510204	1.7675	73	389	1	24	7	17	0	2	17	0	0	4.645838233520012	
i 1	706.0018027210884	0.2525	75	389	4	1	12	2	0	-2	2	0	0	6.0	
i 1	706.0061292517007	0.505	72	389	5	9	11	1	0	0	1	0	0	2.0	
i 1	706.0118979591837	0.505	72	3	7	2	12	0	0	0	0	0	0	3.0	
i 1	706.2344965986395	0.7575000000000001	72	389	5	9	6	1	0	0	1	0	0	2.0	
i 1	706.2467551020408	0.7575000000000001	69	3	7	2	14	0	0	0	0	0	0	3.0	
i 1	706.2539659863945	0.2525	72	3	3	24	8	2	0	-2	2	0	0	7.0	
i 1	706.7366598639455	0.505	69	3	3	3	2	0	0	0	0	0	0	3.0	
i 1	706.7395442176871	0.2525	76	389	2	20	12	16	0	2	16	0	0	0.6458382335200121	
i 1	706.7546870748299	0.2525	75	3	3	1	15	2	0	1	2	0	0	6.0	
i 1	706.7626190476191	1.01	72	696	5	3	2	0	5005	-1	0	0	0	3.0	
i 1	706.9823333333334	0.2525	73	696	1	20	7	17	5005	2	17	0	0	0.6458382335200121	
i 1	706.9981972789116	0.2525	76	3	3	20	5	17	0	1	17	0	0	0.6458382335200121	
i 1	706.998918367347	1.2625	73	389	1	20	8	16	0	1	16	0	0	0.6458382335200121	
i 1	707.0039659863945	0.2525	73	696	1	24	15	16	5005	1	16	0	0	4.645838233520012	
i 1	707.2359387755102	0.505	69	3	7	5	13	0	0	-1	0	0	0	2.0	
i 1	707.2373809523809	11.615	61	696	5	25	7	9	5005	1	9	0	0	3.6638425792760945	
i 1	707.2474761904762	0.2525	69	3	6	5	12	1	0	-1	1	0	0	2.0	
i 1	707.2554081632653	0.505	69	3	5	3	12	0	0	0	0	0	0	3.0	
i 1	707.2582925170068	0.2525	75	696	5	1	15	2	5005	-2	2	0	0	6.0	
i 1	707.2597346938776	11.615	61	3	6	25	8	6	0	1	6	0	0	3.6638425792760945	
i 1	707.2604557823129	0.505	69	389	4	5	3	0	0	0	0	0	0	2.0	
i 1	707.4823333333334	2.2725	72	3	7	2	15	0	0	0	0	0	0	3.0	
i 1	707.4852176870749	0.2525	76	696	1	24	7	16	5005	1	16	0	0	4.645838233520012	
i 1	707.4902653061224	2.7775	72	389	5	9	16	1	0	0	1	0	0	2.0	
i 1	707.4960340136055	0.2525	76	696	1	20	14	16	5005	2	16	0	0	0.6458382335200121	
i 1	707.5133401360545	0.2525	76	3	3	20	5	17	0	1	17	0	0	0.6458382335200121	
i 1	707.7344965986395	0.505	76	389	2	20	2	17	0	2	17	0	0	0.6458382335200121	
i 1	707.7417074829932	1.01	75	3	3	1	4	2	0	1	2	0	0	6.0	
i 1	707.7438707482993	0.7575000000000001	75	696	5	1	10	2	5005	-2	2	0	0	6.0	
i 1	707.7525238095238	1.7675	69	3	3	5	14	0	0	-1	0	0	0	2.0	
i 1	707.7640612244898	0.2525	69	3	6	5	5	1	0	-1	1	0	0	2.0	
i 1	707.7669455782313	1.7675	72	696	6	5	7	0	5005	-1	0	0	0	2.0	
i 1	708.2438707482993	1.5150000000000001	75	696	4	24	1	2	5005	1	2	0	0	7.0	
i 1	708.2460340136055	0.2525	73	3	3	20	2	17	0	2	17	0	0	0.6458382335200121	
i 1	708.2474761904762	1.7675	72	3	3	24	4	2	0	-2	2	0	0	7.0	
i 1	708.2539659863945	0.505	73	389	1	24	4	17	0	2	17	0	0	4.645838233520012	
i 1	708.483775510204	0.2525	73	389	2	20	12	16	0	1	16	0	0	0.6458382335200121	
i 1	708.4909863945578	3.2825	73	389	1	20	8	16	0	1	16	0	0	0.6458382335200121	
i 1	708.501081632653	0.2525	69	389	4	5	6	0	0	0	0	0	0	2.0	
i 1	708.7381020408163	0.2525	69	3	6	5	13	1	0	-1	1	0	0	2.0	
i 1	708.7647823129251	0.2525	73	3	3	20	10	17	0	2	17	0	0	0.6458382335200121	
i 1	708.7655034013605	0.2525	73	696	1	20	6	16	5005	2	16	0	0	0.6458382335200121	
i 1	708.766224489796	0.2525	75	389	4	1	16	2	0	-2	2	0	0	6.0	
i 1	708.9902653061224	2.2725	73	389	2	20	1	17	0	2	17	0	0	0.6458382335200121	
i 1	708.9917074829932	3.0300000000000002	72	696	4	5	1	1	5005	0	1	0	0	2.0	
i 1	709.0118979591837	0.2525	75	389	4	1	12	2	0	1	2	0	0	6.0	
i 1	709.2402653061224	2.7775	69	3	7	5	10	1	0	0	1	0	0	2.0	
i 1	709.4830544217687	0.505	72	696	5	3	13	0	5005	-1	0	0	0	3.0	
i 1	709.4852176870749	0.2525	72	3	3	4	13	1	0	0	1	0	0	3.0	
i 1	709.5118979591837	0.505	69	3	5	3	10	0	0	0	0	0	0	3.0	
i 1	709.5126190476191	0.2525	72	696	4	4	12	1	5005	-1	1	0	0	3.0	
i 1	709.7424285714286	0.7575000000000001	75	3	3	1	11	2	0	1	2	0	0	6.0	
i 1	709.7597346938776	0.7575000000000001	75	696	5	1	15	2	5005	-2	2	0	0	6.0	
i 1	710.0061292517007	0.2525	72	3	7	2	5	0	0	0	0	0	0	3.0	
i 1	710.2323333333334	0.2525	69	3	7	2	4	0	0	0	0	0	0	3.0	
i 1	710.2366598639455	1.2625	69	3	5	3	1	0	0	0	0	0	0	3.0	
i 1	710.2409863945578	1.2625	72	696	5	3	6	0	5005	-1	0	0	0	3.0	
i 1	710.2575714285714	0.2525	69	3	3	5	3	0	0	-1	0	0	0	2.0	
i 1	710.4924285714286	1.2625	72	3	6	1	13	2	0	1	2	0	0	6.0	
i 1	710.4938707482993	1.2625	75	389	4	1	15	2	0	-2	2	0	0	6.0	
i 1	710.7474761904762	0.2525	75	3	3	1	5	2	0	1	2	0	0	6.0	
i 1	710.748918367347	0.2525	72	3	3	4	14	1	0	0	1	0	0	3.0	
i 1	711.2402653061224	0.2525	73	3	3	20	6	16	0	2	16	0	0	0.6458382335200121	
i 1	711.2474761904762	0.505	73	389	1	24	13	17	0	2	17	0	0	4.645838233520012	
i 1	711.2539659863945	1.2625	72	389	5	9	16	1	0	0	1	0	0	2.0	
i 1	711.2597346938776	0.2525	76	3	3	20	7	17	0	1	17	0	0	0.6458382335200121	
i 1	711.2626190476191	1.2625	69	3	7	2	10	0	0	0	0	0	0	3.0	
i 1	711.4830544217687	0.505	73	389	2	20	6	16	0	2	16	0	0	0.6458382335200121	
i 1	711.4909863945578	0.2525	72	696	4	4	16	1	5005	-1	1	0	0	3.0	
i 1	711.5104557823129	3.7875	75	389	4	1	8	2	0	1	2	0	0	6.0	
i 1	711.5147823129251	0.2525	76	389	2	20	7	16	0	2	16	0	0	0.6458382335200121	
i 1	711.5155034013605	3.7875	72	3	6	1	8	2	0	-2	2	0	0	6.0	
i 1	711.7330544217687	1.5150000000000001	72	696	6	5	8	0	5005	-1	0	0	0	2.0	
i 1	711.7525238095238	1.5150000000000001	69	3	3	5	11	0	0	-1	0	0	0	2.0	
i 1	711.9974761904762	1.2625	72	696	5	3	10	0	5005	-1	0	0	0	3.0	
i 1	712.001081632653	1.2625	69	3	5	3	7	0	0	0	0	0	0	3.0	
i 1	712.0169455782313	0.2525	69	3	7	5	15	0	0	-1	0	0	0	2.0	
i 1	712.4866598639455	0.2525	73	389	1	24	2	17	0	2	17	0	0	4.645838233520012	
i 1	712.7546870748299	0.2525	75	696	4	24	1	2	5005	1	2	0	0	7.0	
i 1	712.7575714285714	0.7575000000000001	72	389	5	9	15	1	0	0	1	0	0	2.0	
i 1	712.7597346938776	1.7675	69	389	4	5	5	0	0	0	0	0	0	2.0	
i 1	712.766224489796	0.2525	72	3	7	2	12	0	0	0	0	0	0	3.0	
i 1	712.9823333333334	0.505	72	3	6	2	12	0	0	0	0	0	0	3.0	
i 1	712.9881020408163	11.615	66	3	6	25	9	9	0	1	9	0	0	3.6638425792760945	
i 1	712.9909863945578	0.2525	75	696	5	1	13	2	5005	-2	2	0	0	6.0	
i 1	712.9960340136055	0.2525	73	3	1	20	7	16	5005	2	16	0	0	0.6458382335200121	
i 1	713.0104557823129	1.5150000000000001	69	3	6	5	14	0	0	-1	0	0	0	2.0	
i 1	713.0133401360545	11.615	66	696	5	25	16	9	5005	1	9	0	0	3.6638425792760945	
i 1	713.233775510204	0.7575000000000001	76	3	3	20	1	16	0	1	16	0	0	0.6458382335200121	
i 1	713.2445918367347	0.2525	72	389	5	9	11	1	0	0	1	0	0	2.0	
i 1	713.2481972789116	1.01	73	389	1	24	3	17	0	2	17	0	0	4.645838233520012	
i 1	713.2496394557824	0.7575000000000001	73	696	2	20	9	16	5005	1	16	0	0	0.6458382335200121	
i 1	713.4852176870749	0.2525	72	696	4	4	14	1	5005	-1	1	0	0	3.0	
i 1	713.4866598639455	0.2525	72	3	3	24	7	2	0	-2	2	0	0	7.0	
i 1	713.5118979591837	0.2525	72	3	5	4	7	1	0	0	1	0	0	3.0	
i 1	713.7460340136055	1.01	69	3	5	3	6	0	0	0	0	0	0	3.0	
i 1	713.7539659863945	0.2525	75	696	4	24	1	2	5005	1	2	0	0	7.0	
i 1	713.7554081632653	1.01	72	696	5	3	8	0	5005	-1	0	0	0	3.0	
i 1	713.9909863945578	1.01	73	389	1	20	5	16	0	1	16	0	0	0.6458382335200121	
i 1	713.9967551020408	0.505	73	389	2	20	3	17	0	1	17	0	0	0.6458382335200121	
i 1	713.9996394557824	0.2525	72	696	4	4	1	1	5005	-1	1	0	0	3.0	
i 1	713.9996394557824	0.2525	72	696	6	5	1	1	5005	0	1	0	0	2.0	
i 1	714.0018027210884	0.2525	72	3	3	24	3	2	0	-2	2	0	0	7.0	
i 1	714.0046870748299	0.505	73	3	1	20	16	16	5005	1	16	0	0	0.6458382335200121	
i 1	714.0140612244898	0.505	76	389	2	20	8	17	0	2	17	0	0	0.6458382335200121	
i 1	714.2424285714286	2.02	69	389	4	5	5	0	0	-1	0	0	0	2.0	
i 1	714.251081632653	1.7675	69	3	6	5	15	1	0	-1	1	0	0	2.0	
i 1	714.4888231292517	0.2525	76	3	3	20	15	16	0	2	16	0	0	0.6458382335200121	
i 1	714.5075714285714	0.2525	72	389	5	9	2	1	0	0	1	0	0	2.0	
i 1	714.5111768707483	0.2525	73	696	2	20	3	16	5005	1	16	0	0	0.6458382335200121	
i 1	714.5176666666666	0.2525	73	3	3	20	9	17	0	1	17	0	0	0.6458382335200121	
i 1	714.7467551020408	0.7575000000000001	73	389	1	24	6	17	0	2	17	0	0	4.645838233520012	
i 1	714.7518027210884	1.5150000000000001	72	3	6	2	8	0	0	0	0	0	0	3.0	
i 1	714.7525238095238	1.2625	72	389	5	9	14	1	0	0	1	0	0	2.0	
i 1	714.7539659863945	0.2525	76	389	2	20	10	16	0	2	16	0	0	0.6458382335200121	
i 1	714.7604557823129	0.2525	69	3	3	5	7	0	0	-1	0	0	0	2.0	
i 1	714.7611768707483	0.2525	76	3	1	20	16	16	5005	2	16	0	0	0.6458382335200121	
i 1	714.7633401360545	1.2625	75	696	5	1	15	2	5005	-2	2	0	0	6.0	
i 1	714.7633401360545	0.2525	73	389	2	20	15	17	0	1	17	0	0	0.6458382335200121	
i 1	714.9852176870749	1.01	75	3	3	1	10	2	0	1	2	0	0	6.0	
i 1	714.9852176870749	0.505	73	3	3	20	12	17	0	2	17	0	0	0.6458382335200121	
i 1	714.9888231292517	0.505	73	696	2	20	12	16	5005	1	16	0	0	0.6458382335200121	
i 1	715.2525238095238	0.2525	72	696	5	3	12	0	5005	-1	0	0	0	3.0	
i 1	715.2554081632653	0.505	75	389	4	1	8	2	0	-2	2	0	0	6.0	
i 1	715.4888231292517	1.01	76	389	2	20	7	17	0	2	17	0	0	0.6458382335200121	
i 1	715.5025238095238	1.5150000000000001	69	3	5	3	16	0	0	0	0	0	0	3.0	
i 1	715.5025238095238	0.2525	69	3	3	5	12	1	0	0	1	0	0	2.0	
i 1	715.5082925170068	1.5150000000000001	76	389	2	20	16	17	0	1	17	0	0	0.6458382335200121	
i 1	715.516224489796	2.02	73	389	1	20	7	16	0	1	16	0	0	0.6458382335200121	
i 1	715.7561292517007	0.505	72	3	6	1	12	2	0	1	2	0	0	6.0	
i 1	715.7604557823129	1.2625	72	696	5	3	15	0	5005	-1	0	0	0	3.0	
i 1	715.9830544217687	1.7675	69	389	4	5	1	0	0	0	0	0	0	2.0	
i 1	716.0032448979592	1.7675	69	3	6	5	3	0	0	-1	0	0	0	2.0	
i 1	716.0126190476191	1.2625	75	696	4	24	2	2	5005	1	2	0	0	7.0	
i 1	716.0169455782313	1.2625	72	3	3	24	9	2	0	-2	2	0	0	7.0	
i 1	716.2424285714286	0.505	72	389	5	9	3	1	0	0	1	0	0	2.0	
i 1	716.2647823129251	0.505	69	3	7	2	4	0	0	0	0	0	0	3.0	
i 1	716.4981972789116	0.505	76	3	1	20	16	17	5005	2	17	0	0	0.6458382335200121	
i 1	716.7344965986395	0.2525	75	696	5	1	9	2	5005	-2	2	0	0	6.0	
i 1	716.7344965986395	0.2525	69	3	3	5	3	1	0	0	1	0	0	2.0	
i 1	716.9895442176871	0.2525	73	696	1	24	8	16	5005	1	16	0	0	4.645838233520012	
i 1	717.0018027210884	0.2525	75	389	4	1	6	2	0	1	2	0	0	6.0	
i 1	717.0097346938776	0.2525	73	3	3	20	5	16	0	1	16	0	0	0.6458382335200121	
i 1	717.0097346938776	0.2525	73	696	2	20	2	17	5005	1	17	0	0	0.6458382335200121	
i 1	717.0147823129251	1.7675	72	3	6	2	7	0	0	0	0	0	0	3.0	
i 1	717.0147823129251	1.5150000000000001	72	389	5	9	5	1	0	0	1	0	0	2.0	
i 1	717.2518027210884	0.7575000000000001	75	3	3	1	10	2	0	1	2	0	0	6.0	
i 1	717.2525238095238	0.2525	69	3	5	3	13	0	0	0	0	0	0	3.0	
i 1	717.2546870748299	1.2625	73	389	1	24	9	17	0	2	17	0	0	4.645838233520012	
i 1	717.2561292517007	0.2525	76	389	2	20	14	16	0	2	16	0	0	0.6458382335200121	
i 1	717.2626190476191	0.2525	73	3	1	20	13	16	5005	2	16	0	0	0.6458382335200121	
i 1	717.2633401360545	0.505	75	696	5	1	4	2	5005	-2	2	0	0	6.0	
i 1	717.483775510204	0.2525	73	3	3	20	6	16	0	1	16	0	0	0.6458382335200121	
i 1	717.4945918367347	1.2625	72	696	6	5	10	0	5005	-1	0	0	0	2.0	
i 1	717.4953129251701	0.2525	76	3	3	20	6	17	0	2	17	0	0	0.6458382335200121	
i 1	717.501081632653	1.5150000000000001	69	3	3	5	13	0	0	-1	0	0	0	2.0	
i 1	717.5126190476191	0.2525	72	3	3	24	6	2	0	-2	2	0	0	7.0	
i 1	717.733775510204	0.7575000000000001	73	389	1	20	6	16	0	1	16	0	0	0.6458382335200121	
i 1	717.7481972789116	0.7575000000000001	73	389	2	20	10	17	0	2	17	0	0	0.6458382335200121	
i 1	717.7539659863945	1.01	75	389	4	1	6	2	0	-2	2	0	0	6.0	
i 1	717.7597346938776	0.2525	69	3	7	2	7	0	0	0	0	0	0	3.0	
i 1	717.7676666666666	1.01	72	3	6	1	2	2	0	1	2	0	0	6.0	
i 1	717.9873809523809	1.5150000000000001	72	696	4	4	8	1	5005	-1	1	0	0	3.0	
i 1	718.0046870748299	0.2525	75	389	4	1	7	2	0	1	2	0	0	6.0	
i 1	718.0126190476191	1.5150000000000001	72	3	5	4	16	1	0	0	1	0	0	3.0	
i 1	718.2344965986395	0.2525	76	3	1	20	14	17	5005	1	17	0	0	0.6458382335200121	
i 1	718.4823333333334	2.7775	72	696	6	5	8	1	5005	0	1	0	0	2.0	
i 1	718.483775510204	4.545	72	3	6	1	10	2	0	-2	2	0	0	6.0	
i 1	718.4866598639455	0.2525	73	696	2	20	3	16	5005	2	16	0	0	0.6458382335200121	
i 1	718.4888231292517	4.545	75	389	4	1	5	2	0	1	2	0	0	6.0	
i 1	718.4960340136055	0.505	73	389	1	24	1	17	0	248	17	308	0	4.645838233520012	
i 1	718.4996394557824	0.2525	73	696	1	24	12	16	5005	1	16	0	0	4.645838233520012	
i 1	718.5018027210884	2.7775	69	3	3	5	12	1	0	0	1	0	0	2.0	
i 1	718.7344965986395	0.2525	72	696	5	5	13	0	5005	-1	0	0	0	2.0	
i 1	718.7359387755102	3.0300000000000002	72	696	5	3	7	0	5005	-1	0	0	0	3.0	
i 1	718.7381020408163	0.2525	75	389	5	1	16	2	0	-2	2	0	0	6.0	
i 1	718.7409863945578	11.615	61	696	5	25	11	9	5005	1	9	0	0	3.6638425792760945	
i 1	718.7417074829932	11.615	61	389	4	26	14	6	0	0	6	0	0	3.6638425792760945	
i 1	718.7424285714286	0.2525	76	3	1	20	10	16	5005	2	16	0	0	0.6458382335200121	
i 1	718.7561292517007	0.2525	73	389	2	20	16	16	0	1	16	0	0	0.6458382335200121	
i 1	718.7640612244898	2.02	73	389	1	20	14	16	0	1	16	0	0	0.6458382335200121	
i 1	718.9823333333334	2.7775	69	3	5	3	4	0	0	0	0	0	0	3.0	
i 1	718.9902653061224	0.2525	69	3	6	5	1	0	0	-1	0	0	0	2.0	
i 1	719.0082925170068	0.2525	75	3	3	1	11	2	0	1	2	0	0	6.0	
i 1	719.0176666666666	0.505	73	3	3	20	15	17	0	2	17	0	0	0.6458382335200121	
i 1	719.0176666666666	2.7775	73	389	1	24	3	17	0	2	17	0	0	4.645838233520012	
i 1	719.2352176870749	0.2525	76	696	2	24	1	17	5005	2	17	0	0	4.645838233520012	
i 1	719.4873809523809	1.2625	73	389	2	20	9	17	0	1	17	0	0	0.6458382335200121	
i 1	719.4873809523809	2.525	76	3	1	24	4	16	5005	1	16	0	0	4.645838233520012	
i 1	719.4924285714286	0.2525	75	696	4	24	16	2	5005	1	2	0	0	7.0	
i 1	719.5075714285714	0.505	72	696	5	5	10	0	5005	-1	0	0	0	2.0	
i 1	719.7626190476191	0.2525	75	389	5	1	8	2	0	-2	2	0	0	6.0	
i 1	719.9909863945578	0.505	72	389	5	9	16	1	0	0	1	0	0	2.0	
i 1	719.998918367347	0.505	72	3	6	2	15	0	0	0	0	0	0	3.0	
i 1	720.2474761904762	0.7575000000000001	72	389	5	9	7	1	0	0	1	0	0	2.0	
i 1	720.2503605442176	0.7575000000000001	69	3	6	2	5	0	0	0	0	0	0	3.0	
i 1	720.2561292517007	0.505	73	389	2	20	9	16	0	2	16	0	0	0.6458382335200121	
i 1	720.4981972789116	1.5150000000000001	76	3	1	20	14	17	5005	1	17	0	0	0.6458382335200121	
i 1	720.5003605442176	0.2525	69	389	4	5	16	0	0	0	0	0	0	2.0	
i 1	720.5133401360545	0.2525	75	389	5	1	8	2	0	-2	2	0	0	6.0	
i 1	720.7453129251701	0.505	75	696	5	1	14	2	5005	-2	2	0	0	6.0	
i 1	720.748918367347	0.7575000000000001	69	3	3	5	4	0	0	-1	0	0	0	2.0	
i 1	720.7575714285714	0.7575000000000001	72	696	5	5	2	0	5005	-1	0	0	0	2.0	
i 1	720.9844965986395	2.02	69	389	4	5	11	0	0	0	0	0	0	2.0	
i 1	720.9888231292517	2.02	69	3	6	5	5	0	0	-1	0	0	0	2.0	
i 1	721.2669455782313	0.2525	72	696	4	4	8	1	5005	-1	1	0	0	3.0	
i 1	721.4866598639455	0.505	73	389	2	20	10	16	0	2	16	0	0	0.6458382335200121	
i 1	721.493149659864	0.2525	69	389	6	5	15	0	0	-1	0	0	0	2.0	
i 1	721.4967551020408	2.7775	72	3	6	2	5	0	0	0	0	0	0	3.0	
i 1	721.5169455782313	3.0300000000000002	72	389	5	9	6	1	0	0	1	0	0	2.0	
i 1	721.7417074829932	0.2525	75	696	4	24	13	2	5005	1	2	0	0	7.0	
i 1	721.7438707482993	0.2525	69	3	3	5	3	1	0	0	1	0	0	2.0	
i 1	721.9888231292517	0.2525	73	696	2	20	12	17	5005	2	17	0	0	0.6458382335200121	
i 1	721.9888231292517	0.2525	76	696	2	24	8	16	5005	2	16	0	0	4.645838233520012	
i 1	721.9967551020408	0.2525	72	3	5	4	13	1	0	0	1	0	0	3.0	
i 1	721.998918367347	0.2525	75	3	3	1	13	2	0	1	2	0	0	6.0	
i 1	722.2344965986395	0.2525	76	3	1	24	13	17	5005	1	17	0	0	4.645838233520012	
i 1	722.2359387755102	0.2525	76	389	2	20	5	17	0	1	17	0	0	0.6458382335200121	
i 1	722.2359387755102	0.2525	76	3	1	20	3	17	5005	2	17	0	0	0.6458382335200121	
i 1	722.2503605442176	0.2525	72	3	6	1	5	2	0	1	2	0	0	6.0	
i 1	722.2503605442176	3.535	69	389	6	5	4	0	0	-1	0	0	0	2.0	
i 1	722.2518027210884	0.505	73	389	1	24	4	17	0	2	17	0	0	4.645838233520012	
i 1	722.2582925170068	0.505	69	3	5	3	8	0	0	0	0	0	0	3.0	
i 1	722.2618979591837	1.01	73	389	1	20	16	16	0	1	16	0	0	0.6458382335200121	
i 1	722.4888231292517	1.2625	75	3	3	1	12	2	0	1	2	0	0	6.0	
i 1	722.4974761904762	0.2525	73	696	2	24	13	17	5005	2	17	0	0	4.645838233520012	
i 1	722.5118979591837	1.01	75	696	5	1	16	2	5005	-2	2	0	0	6.0	
i 1	722.5118979591837	0.505	73	3	3	20	9	17	0	1	17	0	0	0.6458382335200121	
i 1	722.5133401360545	3.2825	69	3	6	5	8	1	0	-1	1	0	0	2.0	
i 1	722.7460340136055	0.505	72	389	5	9	3	1	0	0	1	0	0	2.0	
i 1	722.9866598639455	0.2525	69	3	3	5	2	0	0	-1	0	0	0	2.0	
i 1	722.9895442176871	0.2525	73	3	1	20	1	16	5005	1	16	0	0	0.6458382335200121	
i 1	722.9924285714286	1.2625	75	696	4	24	11	2	5005	1	2	0	0	7.0	
i 1	723.016224489796	1.2625	72	3	3	24	7	2	0	-2	2	0	0	7.0	
i 1	723.0169455782313	0.2525	73	389	2	20	5	17	0	1	17	0	0	0.6458382335200121	
i 1	723.2373809523809	1.01	72	3	5	4	14	1	0	0	1	0	0	3.0	
i 1	723.2409863945578	0.2525	76	3	3	20	10	16	0	1	16	0	0	0.6458382335200121	
i 1	723.251081632653	1.2625	73	389	1	24	16	17	0	2	17	0	0	4.645838233520012	
i 1	723.2525238095238	0.7575000000000001	72	696	4	4	9	1	5005	-1	1	0	0	3.0	
i 1	723.2546870748299	0.2525	72	696	6	5	5	1	5005	0	1	0	0	2.0	
i 1	723.2582925170068	0.2525	73	696	2	24	3	16	5005	2	16	0	0	4.645838233520012	
i 1	723.4823333333334	1.5150000000000001	73	3	1	24	6	17	5005	1	17	0	0	4.645838233520012	
i 1	723.4938707482993	0.2525	73	3	1	20	8	16	5005	2	16	0	0	0.6458382335200121	
i 1	723.4953129251701	2.02	76	389	2	20	2	17	0	1	17	0	0	0.6458382335200121	
i 1	723.5054081632653	0.505	72	696	5	3	2	0	5005	-1	0	0	0	3.0	
i 1	723.516224489796	0.505	69	3	5	3	10	0	0	0	0	0	0	3.0	
i 1	723.7640612244898	0.2525	75	389	4	1	8	2	0	1	2	0	0	6.0	
i 1	723.9844965986395	1.01	75	3	3	1	7	2	0	1	2	0	0	6.0	
i 1	723.9852176870749	1.01	75	696	5	1	3	2	5005	-2	2	0	0	6.0	
i 1	724.2546870748299	0.2525	72	696	5	3	12	0	5005	-1	0	0	0	3.0	
i 1	724.2626190476191	1.5150000000000001	69	3	5	3	12	0	0	0	0	0	0	3.0	
i 1	724.266224489796	0.2525	69	389	4	5	13	0	0	0	0	0	0	2.0	
i 1	724.493149659864	0.505	69	3	3	5	1	1	0	0	1	0	0	2.0	
i 1	724.4953129251701	2.02	72	3	6	1	16	2	0	1	2	0	0	6.0	
i 1	724.5003605442176	0.505	72	3	6	2	16	0	0	0	0	0	0	3.0	
i 1	724.5054081632653	0.505	73	389	2	24	14	17	0	2	17	0	0	4.645838233520012	
i 1	724.5075714285714	2.02	75	389	5	1	1	2	0	-2	2	0	0	6.0	
i 1	724.5111768707483	11.615	66	696	5	25	2	9	5005	1	9	0	0	3.6638425792760945	
i 1	724.5147823129251	7.575	61	389	4	26	9	6	0	0	6	0	0	3.6638425792760945	
i 1	724.5169455782313	1.01	72	696	5	3	16	0	5005	-1	0	0	0	3.0	
i 1	724.7366598639455	1.7675	73	389	1	20	16	16	0	1	16	0	0	0.6458382335200121	
i 1	724.7582925170068	1.5150000000000001	73	389	2	20	5	17	0	2	17	0	0	0.6458382335200121	
i 1	724.9844965986395	0.2525	72	3	3	24	11	2	0	-2	2	0	0	7.0	
i 1	725.0061292517007	2.02	69	389	6	5	16	0	0	0	0	0	0	2.0	
i 1	725.0082925170068	0.2525	72	696	4	4	11	1	5005	-1	1	0	0	3.0	
i 1	725.2366598639455	1.2625	69	3	6	2	7	0	0	0	0	0	0	3.0	
i 1	725.2460340136055	0.2525	72	3	6	1	2	2	0	-2	2	0	0	6.0	
i 1	725.2525238095238	1.7675	69	3	6	5	5	0	0	-1	0	0	0	2.0	
i 1	725.2582925170068	1.2625	72	389	5	9	1	1	0	0	1	0	0	2.0	
i 1	725.7388231292517	0.2525	75	696	5	1	4	2	5005	-2	2	0	0	6.0	
i 1	725.7604557823129	0.2525	69	3	3	5	10	1	0	0	1	0	0	2.0	
i 1	725.7676666666666	0.2525	72	3	6	2	1	0	0	0	0	0	0	3.0	
i 1	725.983775510204	1.2625	69	3	5	3	2	0	0	0	0	0	0	3.0	
i 1	725.9852176870749	0.7575000000000001	73	389	2	24	14	17	0	2	17	0	0	4.645838233520012	
i 1	725.9924285714286	4.04	75	389	5	1	2	2	0	1	2	0	0	6.0	
i 1	726.0003605442176	1.2625	72	696	5	3	1	0	5005	-1	0	0	0	3.0	
i 1	726.0046870748299	4.04	72	3	6	1	15	2	0	-2	2	0	0	6.0	
i 1	726.0061292517007	0.2525	73	3	1	20	14	16	5005	2	16	0	0	0.6458382335200121	
i 1	726.0104557823129	0.2525	69	389	6	5	3	0	0	-1	0	0	0	2.0	
i 1	726.2525238095238	0.2525	76	696	2	20	13	16	5005	2	16	0	0	0.6458382335200121	
i 1	726.2590136054422	0.2525	73	3	3	20	14	17	0	2	17	0	0	0.6458382335200121	
i 1	726.2655034013605	0.2525	73	3	3	20	1	17	0	1	17	0	0	0.6458382335200121	
i 1	726.266224489796	1.7675	72	696	5	5	4	0	5005	-1	0	0	0	2.0	
i 1	726.4844965986395	1.5150000000000001	69	3	3	5	1	0	0	-1	0	0	0	2.0	
i 1	726.4895442176871	0.2525	72	3	3	24	8	2	0	-2	2	0	0	7.0	
i 1	726.4974761904762	1.2625	72	389	5	9	5	1	0	0	1	0	0	2.0	
i 1	726.4974761904762	0.2525	76	389	2	20	6	17	0	2	17	0	0	0.6458382335200121	
i 1	726.5039659863945	1.5150000000000001	76	3	1	20	5	16	5005	1	16	0	0	0.6458382335200121	
i 1	726.5090136054422	2.02	73	389	2	20	4	17	0	2	17	0	0	0.6458382335200121	
i 1	726.7330544217687	1.01	72	3	6	2	3	0	0	0	0	0	0	3.0	
i 1	726.7366598639455	0.2525	75	389	5	1	15	2	0	-2	2	0	0	6.0	
i 1	726.9844965986395	0.2525	75	696	5	1	12	2	5005	-2	2	0	0	6.0	
i 1	726.9967551020408	1.01	73	389	2	24	4	17	0	2	17	0	0	4.645838233520012	
i 1	726.9996394557824	1.01	73	3	1	24	7	16	5005	2	16	0	0	4.645838233520012	
i 1	727.0104557823129	0.2525	69	389	6	5	6	0	0	-1	0	0	0	2.0	
i 1	727.2395442176871	2.525	72	696	5	5	3	1	5005	0	1	0	0	2.0	
i 1	727.2424285714286	0.7575000000000001	72	3	5	4	5	1	0	0	1	0	0	3.0	
i 1	727.2611768707483	1.01	72	696	4	4	5	1	5005	-1	1	0	0	3.0	
i 1	727.4823333333334	2.2725	69	3	3	5	3	1	0	0	1	0	0	2.0	
i 1	727.483775510204	0.505	75	389	5	1	5	2	0	-2	2	0	0	6.0	
i 1	727.4859387755102	2.7775	73	389	1	20	4	16	0	1	16	0	0	0.6458382335200121	
i 1	727.5090136054422	1.5150000000000001	72	696	5	3	6	0	5005	-1	0	0	0	3.0	
i 1	727.5155034013605	1.5150000000000001	69	3	5	3	7	0	0	0	0	0	0	3.0	
i 1	727.5169455782313	1.01	76	389	2	20	15	17	0	2	17	0	0	0.6458382335200121	
i 1	727.983775510204	0.2525	75	696	5	1	10	2	5005	-2	2	0	0	6.0	
i 1	728.0118979591837	0.2525	69	3	6	5	6	1	0	-1	1	0	0	2.0	
i 1	728.2402653061224	2.02	73	389	2	24	12	17	0	2	17	0	0	4.645838233520012	
i 1	728.2460340136055	0.2525	75	696	4	24	16	2	5005	1	2	0	0	7.0	
i 1	728.2474761904762	1.7675	72	3	6	2	1	0	0	0	0	0	0	3.0	
i 1	728.266224489796	0.2525	69	389	6	5	4	0	0	-1	0	0	0	2.0	
i 1	728.4830544217687	1.7675	72	389	5	9	8	1	0	0	1	0	0	2.0	
i 1	728.4866598639455	0.505	75	3	3	1	13	2	0	1	2	0	0	6.0	
i 1	728.5082925170068	0.2525	73	3	3	20	5	16	0	2	16	0	0	0.6458382335200121	
i 1	728.5097346938776	0.2525	76	696	2	24	3	16	5005	2	16	0	0	4.645838233520012	
i 1	728.5147823129251	0.2525	73	3	3	20	3	16	0	1	16	0	0	0.6458382335200121	
i 1	728.7381020408163	1.5150000000000001	73	3	1	24	8	16	5005	1	16	0	0	4.645838233520012	
i 1	728.7402653061224	0.2525	72	696	5	5	8	0	5005	-1	0	0	0	2.0	
i 1	728.756850340136	1.5150000000000001	76	389	2	20	1	16	0	2	16	0	0	0.6458382335200121	
i 1	728.993149659864	0.505	75	389	5	1	5	2	0	-2	2	0	0	6.0	
i 1	729.0126190476191	1.2625	69	3	3	5	7	0	0	-1	0	0	0	2.0	
i 1	729.0140612244898	0.2525	72	696	4	4	5	1	5005	-1	1	0	0	3.0	
i 1	729.243149659864	2.02	72	696	5	5	15	0	5005	-1	0	0	0	2.0	
i 1	729.248918367347	0.2525	72	3	5	4	10	1	0	0	1	0	0	3.0	
i 1	729.4917074829932	1.01	75	696	5	1	1	2	5005	-2	2	0	0	6.0	
i 1	729.4938707482993	1.7675	69	3	5	3	11	0	0	0	0	0	0	3.0	
i 1	729.5046870748299	0.7575000000000001	75	3	3	1	4	2	0	1	2	0	0	6.0	
i 1	729.5054081632653	1.7675	72	696	5	3	9	0	5005	-1	0	0	0	3.0	
i 1	729.7366598639455	1.01	76	3	1	20	8	17	5005	1	17	0	0	0.6458382335200121	
i 1	729.7518027210884	1.01	73	389	2	20	11	17	0	1	17	0	0	0.6458382335200121	
i 1	729.7554081632653	0.2525	69	389	6	5	4	0	0	-1	0	0	0	2.0	
i 1	729.9830544217687	0.2525	69	389	6	5	2	0	0	0	0	0	0	2.0	
i 1	729.9917074829932	2.02	75	696	4	24	16	2	5005	1	2	0	0	7.0	
i 1	730.0140612244898	2.02	72	3	3	24	2	2	0	-2	2	0	0	7.0	
i 1	730.2388231292517	1.7675	66	3	4	27	2	9	0	0	9	0	0	4.430396782360776	
i 1	730.2409863945578	1.7675	61	389	4	26	11	6	0	0	6	0	0	3.6638425792760945	
i 1	730.2438707482993	0.2525	75	3	4	1	1	2	0	1	2	0	0	6.0	
i 1	730.2532448979592	0.7575000000000001	72	389	5	9	4	1	0	0	1	0	0	2.0	
i 1	730.2539659863945	0.7575000000000001	69	3	6	2	6	0	0	0	0	0	0	3.0	
i 1	730.2669455782313	1.01	69	3	7	5	4	0	0	-1	0	0	0	2.0	
i 1	730.4844965986395	0.2525	73	3	1	24	6	16	5005	1	16	0	0	4.645838233520012	
i 1	730.4909863945578	0.2525	69	3	6	5	16	1	0	-1	1	0	0	2.0	
i 1	730.5082925170068	0.505	72	3	6	1	5	2	0	-2	2	0	0	6.0	
i 1	730.7409863945578	0.2525	76	696	2	24	3	17	5005	1	17	0	0	4.645838233520012	
i 1	730.7409863945578	1.01	73	389	2	24	13	17	0	2	17	0	0	4.645838233520012	
i 1	730.743149659864	1.2625	72	389	5	9	5	1	0	0	1	0	0	2.0	
i 1	730.743149659864	1.2625	69	389	6	5	4	0	0	0	0	0	0	2.0	
i 1	730.7460340136055	1.2625	69	3	6	5	4	0	0	-1	0	0	0	2.0	
i 1	730.7611768707483	0.2525	73	696	2	20	11	17	5005	2	17	0	0	0.6458382335200121	
i 1	730.7647823129251	1.2625	72	3	6	2	7	0	0	0	0	0	0	3.0	
i 1	730.7676666666666	0.2525	76	3	3	20	4	17	0	1	17	0	0	0.6458382335200121	
i 1	730.9881020408163	0.505	73	389	2	20	3	16	0	1	16	0	0	0.6458382335200121	
i 1	730.9981972789116	0.2525	76	3	1	20	6	16	5005	2	16	0	0	0.6458382335200121	
i 1	730.9981972789116	0.505	76	3	1	24	1	16	5005	1	16	0	0	4.645838233520012	
i 1	731.0176666666666	0.2525	75	696	5	1	5	2	5005	-2	2	0	0	6.0	
i 1	731.2445918367347	0.2525	72	389	5	9	16	1	0	0	1	0	0	2.0	
i 1	731.2467551020408	0.7575000000000001	69	3	6	5	6	1	0	-1	1	0	0	2.0	
i 1	731.2575714285714	0.2525	72	3	6	1	16	2	0	-2	2	0	0	6.0	
i 1	731.2590136054422	0.7575000000000001	73	389	2	20	4	16	0	1	16	0	0	0.6458382335200121	
i 1	731.4902653061224	0.2525	73	3	3	20	11	16	0	1	16	0	0	0.6458382335200121	
i 1	731.4945918367347	1.7675	72	696	5	3	2	0	5005	-1	0	0	0	3.0	
i 1	731.4967551020408	0.505	75	3	4	1	9	2	0	1	2	0	0	6.0	
i 1	731.4974761904762	1.01	75	696	5	1	5	2	5005	-2	2	0	0	6.0	
i 1	731.5075714285714	0.2525	73	3	3	20	14	16	0	1	16	0	0	0.6458382335200121	
i 1	731.5176666666666	0.2525	76	696	2	24	11	17	5005	2	17	0	0	4.645838233520012	
i 1	731.7409863945578	0.2525	73	3	1	20	5	17	5005	1	17	0	0	0.6458382335200121	
i 1	731.7453129251701	0.2525	73	389	2	20	1	17	0	1	17	0	0	0.6458382335200121	
i 1	731.7481972789116	0.2525	72	3	6	1	4	2	0	-2	2	0	0	6.0	
i 1	731.7546870748299	0.2525	73	389	2	20	13	17	0	2	17	0	0	0.6458382335200121	
i 1	731.7597346938776	0.2525	72	3	5	4	14	1	0	0	1	0	0	3.0	
i 1	731.766224489796	0.2525	76	3	1	24	1	16	5005	2	16	0	0	4.645838233520012	
i 1	731.983775510204	0.2525	76	1091	2	20	16	17	0	2	17	0	0	0.6458382335200121	
i 1	731.9866598639455	0.505	72	207	6	9	6	0	0	0	0	0	0	2.0	
i 1	731.9873809523809	4.04	73	207	2	24	7	17	0	2	17	0	0	4.645838233520012	
i 1	731.9924285714286	1.5150000000000001	69	207	7	5	6	0	0	0	0	0	0	2.0	
i 1	731.9960340136055	9.8475	66	207	5	26	10	9	0	1	9	0	0	3.6638425792760945	
i 1	731.9960340136055	1.5150000000000001	69	1091	5	5	4	0	0	0	0	0	0	2.0	
i 1	731.9996394557824	1.2625	69	207	5	4	3	0	0	-1	0	0	0	3.0	
i 1	732.0025238095238	3.535	72	207	4	1	2	2	0	1	2	0	0	6.0	
i 1	732.0025238095238	4.04	66	207	1	27	7	6	0	252	6	307	0	4.430396782360776	
i 1	732.0054081632653	9.8475	61	207	4	27	15	6	0	0	6	0	0	4.430396782360776	
i 1	732.0061292517007	0.2525	69	1091	5	2	2	0	0	-1	0	0	0	3.0	
i 1	732.006850340136	0.2525	69	1091	5	5	10	1	0	-1	1	0	0	2.0	
i 1	732.0133401360545	3.535	72	1091	5	1	1	2	0	1	2	0	0	6.0	
i 1	732.0140612244898	4.04	61	207	5	26	3	9	0	0	9	0	0	3.6638425792760945	
i 1	732.0169455782313	0.2525	73	696	2	24	7	16	5005	2	16	0	0	4.645838233520012	
i 1	732.2381020408163	1.5150000000000001	76	207	2	20	3	16	0	1	16	0	0	0.6458382335200121	
i 1	732.2381020408163	0.2525	73	207	1	20	3	17	5005	2	17	0	0	0.6458382335200121	
i 1	732.2409863945578	0.2525	72	696	5	5	5	0	5005	-1	0	0	0	2.0	
i 1	732.2539659863945	1.5150000000000001	76	207	1	24	15	17	5005	2	17	0	0	4.645838233520012	
i 1	732.4823333333334	1.5150000000000001	69	1091	5	2	2	0	0	-1	0	0	0	3.0	
i 1	732.4960340136055	0.2525	75	207	5	1	10	2	0	-2	2	0	0	6.0	
i 1	732.498918367347	0.505	72	696	5	5	9	1	5005	0	1	0	0	2.0	
i 1	732.7561292517007	1.2625	72	207	6	9	1	1	0	0	1	0	0	2.0	
i 1	732.7647823129251	0.2525	75	696	5	1	2	2	5005	-2	2	0	0	6.0	
i 1	733.0032448979592	1.5150000000000001	69	207	7	5	4	1	0	0	1	0	0	2.0	
i 1	733.0039659863945	1.5150000000000001	69	1091	5	5	5	1	0	-1	1	0	0	2.0	
i 1	733.0155034013605	0.505	72	207	3	24	16	2	0	1	2	0	0	7.0	
i 1	733.233775510204	0.7575000000000001	76	207	2	20	7	16	0	1	16	0	0	0.6458382335200121	
i 1	733.2409863945578	0.2525	72	1091	5	2	16	1	0	0	1	0	0	3.0	
i 1	733.2445918367347	0.505	76	207	2	20	14	16	0	1	16	0	0	0.6458382335200121	
i 1	733.4909863945578	0.2525	73	207	1	20	3	17	5005	2	17	0	0	0.6458382335200121	
i 1	733.498918367347	0.505	75	696	4	24	3	2	5005	1	2	0	0	7.0	
i 1	733.5025238095238	1.2625	72	696	5	3	1	0	5005	-1	0	0	0	3.0	
i 1	733.5075714285714	0.2525	69	207	3	5	13	1	0	-1	1	0	0	2.0	
i 1	733.5082925170068	1.2625	69	207	5	4	7	0	0	-1	0	0	0	3.0	
i 1	733.7381020408163	0.2525	69	207	5	5	15	0	0	-1	0	0	0	2.0	
i 1	733.7554081632653	0.7575000000000001	69	207	5	3	8	1	0	-1	1	0	0	3.0	
i 1	733.7597346938776	0.505	73	1091	2	20	3	16	0	2	16	0	0	0.6458382335200121	
i 1	733.7640612244898	0.7575000000000001	72	1091	5	2	15	1	0	0	1	0	0	3.0	
i 1	733.7676666666666	0.505	76	696	2	20	2	16	5005	2	16	0	0	0.6458382335200121	
i 1	733.9859387755102	0.7575000000000001	72	696	5	5	13	0	5005	-1	0	0	0	2.0	
i 1	734.001081632653	0.2525	73	1091	2	20	5	17	0	2	17	0	0	0.6458382335200121	
i 1	734.0090136054422	0.2525	75	1091	6	1	3	2	0	1	2	0	0	6.0	
i 1	734.0169455782313	1.01	69	207	3	5	4	1	0	-1	1	0	0	2.0	
i 1	734.233775510204	3.7875	72	696	5	5	12	1	5005	0	1	0	0	2.0	
i 1	734.2352176870749	0.2525	73	207	2	20	16	17	0	2	17	0	0	0.6458382335200121	
i 1	734.2359387755102	1.01	76	207	2	20	3	16	0	1	16	0	0	0.6458382335200121	
i 1	734.2424285714286	2.525	72	207	6	9	8	1	0	0	1	0	0	2.0	
i 1	734.2532448979592	3.535	69	207	5	5	12	0	0	-1	0	0	0	2.0	
i 1	734.2546870748299	0.2525	76	207	1	20	11	17	5005	2	17	0	0	0.6458382335200121	
i 1	734.2575714285714	2.525	69	1091	5	2	16	0	0	-1	0	0	0	3.0	
i 1	734.2676666666666	0.505	75	696	5	1	15	2	5005	-2	2	0	0	6.0	
i 1	734.4873809523809	0.2525	73	1091	2	20	10	17	0	1	17	0	0	0.6458382335200121	
i 1	734.7373809523809	0.2525	73	207	2	20	16	16	0	2	16	0	0	0.6458382335200121	
i 1	734.7532448979592	0.2525	75	207	5	1	4	2	0	-2	2	0	0	6.0	
i 1	734.7655034013605	0.2525	72	1091	5	2	12	1	0	0	1	0	0	3.0	
i 1	734.9859387755102	0.505	72	696	4	4	8	1	5005	-1	1	0	0	3.0	
i 1	734.9866598639455	2.02	75	696	5	1	12	2	5005	-2	2	0	0	6.0	
i 1	734.9888231292517	1.01	72	207	3	24	14	2	0	1	2	0	0	7.0	
i 1	735.0082925170068	0.2525	69	1091	5	5	16	1	0	-1	1	0	0	2.0	
i 1	735.0176666666666	0.2525	73	696	2	24	3	17	5005	1	17	0	0	4.645838233520012	
i 1	735.2438707482993	0.2525	69	207	7	5	10	1	0	0	1	0	0	2.0	
i 1	735.2438707482993	0.505	73	207	2	20	2	17	0	2	17	0	0	0.6458382335200121	
i 1	735.2611768707483	0.7575000000000001	76	207	1	24	8	16	5005	1	16	0	0	4.645838233520012	
i 1	735.2633401360545	0.2525	73	207	2	20	16	17	0	2	17	0	0	0.6458382335200121	
i 1	735.2633401360545	0.7575000000000001	76	207	1	20	2	16	5005	1	16	0	0	0.6458382335200121	
i 1	735.4895442176871	0.505	69	207	7	5	8	0	0	0	0	0	0	2.0	
i 1	735.5133401360545	0.2525	72	207	5	1	8	8	0	-2	8	0	0	6.0	
i 1	735.5176666666666	0.2525	69	207	5	3	16	1	0	-1	1	0	0	3.0	
i 1	735.7445918367347	0.2525	72	1091	5	1	12	2	0	1	2	0	0	6.0	
i 1	735.756850340136	0.2525	72	1091	5	2	4	1	0	0	1	0	0	3.0	
i 1	735.9938707482993	11.615	61	207	5	26	8	9	0	0	9	0	0	3.6638425792760945	
i 1	735.9945918367347	0.2525	75	207	5	1	2	2	0	-2	2	0	0	6.0	
i 1	735.9960340136055	0.2525	76	207	1	20	5	16	5005	1	16	0	0	1.8593942945992605	
i 1	736.0003605442176	1.01	72	207	4	24	8	2	0	1	2	0	0	7.0	
i 1	736.0003605442176	0.2525	69	207	5	5	9	0	0	0	0	0	0	2.0	
i 1	736.0032448979592	0.2525	72	696	5	3	1	0	5005	-1	0	0	0	3.0	
i 1	736.0046870748299	0.2525	76	207	1	24	11	16	5005	1	16	0	0	5.8593942945992605	
i 1	736.016224489796	10.605	66	207	4	27	10	6	0	1	6	0	0	4.430396782360776	
i 1	736.0169455782313	0.2525	73	207	2	20	5	17	0	2	17	0	0	1.8593942945992605	
i 1	736.0169455782313	1.2625	76	207	2	20	1	16	0	1	16	0	0	1.8593942945992605	
i 1	736.0176666666666	0.505	73	207	2	24	14	17	0	2	17	0	0	5.8593942945992605	
i 1	736.2381020408163	1.5150000000000001	75	696	4	24	7	2	5005	1	2	0	0	7.0	
i 1	736.2474761904762	1.2625	72	207	5	9	8	0	0	0	0	0	0	2.0	
i 1	736.251081632653	1.2625	72	696	4	4	6	1	5005	-1	1	0	0	3.0	
i 1	736.2561292517007	0.2525	76	1091	2	20	7	16	0	1	16	0	0	1.8593942945992605	
i 1	736.256850340136	0.2525	69	207	7	5	14	1	0	-1	1	0	0	2.0	
i 1	736.2575714285714	0.2525	76	696	2	20	4	16	5005	2	16	0	0	1.8593942945992605	
i 1	736.2582925170068	0.2525	73	696	2	24	5	17	5005	2	17	0	0	5.8593942945992605	
i 1	736.4844965986395	1.2625	75	207	5	1	11	2	0	-2	2	0	0	6.0	
i 1	736.4859387755102	0.2525	69	207	7	5	5	1	0	0	1	0	0	2.0	
i 1	736.4888231292517	0.505	73	207	2	20	2	17	0	1	17	0	0	1.8593942945992605	
i 1	736.5032448979592	0.2525	73	207	1	24	13	16	5005	2	16	0	0	5.8593942945992605	
i 1	736.7366598639455	0.505	69	207	5	5	3	0	0	0	0	0	0	2.0	
i 1	736.7366598639455	1.2625	73	207	2	24	3	17	0	2	17	0	0	5.8593942945992605	
i 1	736.7373809523809	0.2525	72	1091	5	2	13	1	0	0	1	0	0	3.0	
i 1	736.7561292517007	0.7575000000000001	73	207	1	24	13	16	0	1	16	0	0	5.8593942945992605	
i 1	736.9902653061224	0.2525	75	1091	6	1	10	2	0	1	2	0	0	6.0	
i 1	736.9924285714286	1.2625	72	696	5	3	2	0	5005	-1	0	0	0	3.0	
i 1	737.0046870748299	1.2625	69	207	5	4	11	0	0	-1	0	0	0	3.0	
i 1	737.2323333333334	0.7575000000000001	69	1091	5	2	2	0	0	-1	0	0	0	3.0	
i 1	737.2409863945578	1.7675	69	207	7	5	16	1	0	-1	1	0	0	2.0	
i 1	737.2518027210884	1.7675	75	696	5	1	6	2	5005	-2	2	0	0	6.0	
i 1	737.2532448979592	1.7675	72	207	4	24	16	2	0	1	2	0	0	7.0	
i 1	737.2575714285714	1.7675	72	696	5	5	8	0	5005	-1	0	0	0	2.0	
i 1	737.2633401360545	0.7575000000000001	72	207	6	9	6	1	0	0	1	0	0	2.0	
i 1	737.266224489796	0.2525	73	207	1	24	15	17	5005	2	17	0	0	5.8593942945992605	
i 1	737.4895442176871	6.0600000000000005	76	207	2	20	8	16	0	1	16	0	0	1.8593942945992605	
i 1	737.501081632653	0.2525	76	696	2	20	11	16	5005	2	16	0	0	1.8593942945992605	
i 1	737.7344965986395	0.2525	76	207	1	24	13	17	5005	1	17	0	0	5.8593942945992605	
i 1	737.7424285714286	1.5150000000000001	72	1091	5	2	14	1	0	0	1	0	0	3.0	
i 1	737.7518027210884	0.2525	75	1091	6	1	16	2	0	1	2	0	0	6.0	
i 1	737.7561292517007	1.5150000000000001	69	207	5	3	10	1	0	-1	1	0	0	3.0	
i 1	737.7655034013605	1.7675	76	207	2	20	4	17	0	1	17	0	0	1.8593942945992605	
i 1	737.9996394557824	1.2625	73	207	1	24	16	17	0	248	17	308	0	5.8593942945992605	
i 1	738.0090136054422	0.2525	75	207	5	1	6	2	0	-2	2	0	0	6.0	
i 1	738.0126190476191	0.2525	69	207	5	5	7	0	0	0	0	0	0	2.0	
i 1	738.233775510204	0.2525	72	207	6	9	3	1	0	0	1	0	0	2.0	
i 1	738.2359387755102	1.5150000000000001	72	207	5	1	8	8	0	-2	8	0	0	6.0	
i 1	738.2590136054422	0.2525	72	696	5	5	15	1	5005	0	1	0	0	2.0	
i 1	738.4881020408163	1.7675	69	207	5	4	3	0	0	-1	0	0	0	3.0	
i 1	738.4924285714286	0.2525	73	207	2	20	15	17	0	2	17	0	0	1.8593942945992605	
i 1	738.498918367347	1.01	75	1091	6	1	13	2	0	1	2	0	0	6.0	
i 1	738.5032448979592	3.0300000000000002	69	1091	5	5	2	0	0	0	0	0	0	2.0	
i 1	738.5140612244898	3.2825	69	207	5	5	13	0	0	0	0	0	0	2.0	
i 1	738.7597346938776	1.7675	72	696	5	3	15	0	5005	-1	0	0	0	3.0	
i 1	738.9823333333334	4.2925	72	1091	6	1	8	2	0	1	2	0	0	6.0	
i 1	738.9881020408163	0.2525	76	207	1	24	13	17	5005	1	17	0	0	5.8593942945992605	
i 1	738.9902653061224	4.2925	72	207	4	1	4	2	0	1	2	0	0	6.0	
i 1	738.9917074829932	0.2525	69	207	5	5	7	0	0	-1	0	0	0	2.0	
i 1	739.2395442176871	0.2525	73	207	2	20	10	17	0	2	17	0	0	1.8593942945992605	
i 1	739.2438707482993	0.7575000000000001	73	207	2	24	15	17	0	2	17	0	0	5.8593942945992605	
i 1	739.2575714285714	0.2525	69	1091	5	2	7	0	0	-1	0	0	0	3.0	
i 1	739.2590136054422	0.505	69	1091	5	5	3	1	0	-1	1	0	0	2.0	
i 1	739.4830544217687	0.2525	73	1091	2	20	5	17	0	2	17	0	0	1.8593942945992605	
i 1	739.4938707482993	1.7675	73	207	1	24	3	16	0	1	16	0	0	5.8593942945992605	
i 1	739.5104557823129	0.2525	72	1091	5	2	10	1	0	0	1	0	0	3.0	
i 1	739.5169455782313	0.2525	76	1091	2	20	1	16	0	2	16	0	0	1.8593942945992605	
i 1	739.751081632653	3.0300000000000002	69	1091	5	2	7	0	0	-1	0	0	0	3.0	
i 1	739.7525238095238	0.2525	72	696	5	5	6	1	5005	0	1	0	0	2.0	
i 1	739.7554081632653	1.2625	73	207	2	20	6	17	0	1	17	0	0	1.8593942945992605	
i 1	739.7597346938776	2.02	72	207	6	9	9	1	0	0	1	0	0	2.0	
i 1	739.7640612244898	0.2525	75	207	5	1	4	2	0	-2	2	0	0	6.0	
i 1	739.7676666666666	1.2625	73	207	2	20	4	16	0	2	16	0	0	1.8593942945992605	
i 1	739.9902653061224	0.2525	75	1091	6	1	4	2	0	1	2	0	0	6.0	
i 1	739.9924285714286	0.2525	69	207	5	5	8	0	0	-1	0	0	0	2.0	
i 1	740.2604557823129	0.505	75	696	5	1	8	2	5005	-2	2	0	0	6.0	
i 1	740.4953129251701	1.01	72	696	4	4	2	1	5005	-1	1	0	0	3.0	
i 1	740.743149659864	0.2525	69	207	7	5	4	1	0	-1	1	0	0	2.0	
i 1	740.7460340136055	1.7675	73	207	2	24	5	17	0	2	17	0	0	5.8593942945992605	
i 1	740.7561292517007	0.2525	75	207	5	1	10	2	0	-2	2	0	0	6.0	
i 1	740.7626190476191	0.7575000000000001	72	207	5	9	14	0	0	0	0	0	0	2.0	
i 1	740.9902653061224	1.01	69	207	5	4	2	0	0	-1	0	0	0	3.0	
i 1	740.9981972789116	0.7575000000000001	72	696	5	3	5	0	5005	-1	0	0	0	3.0	
i 1	741.0039659863945	0.2525	75	696	5	1	3	2	5005	-2	2	0	0	6.0	
i 1	741.0054081632653	0.2525	73	1091	2	20	16	16	0	1	16	0	0	1.8593942945992605	
i 1	741.0061292517007	0.2525	76	1091	2	20	5	17	0	2	17	0	0	1.8593942945992605	
i 1	741.0126190476191	2.02	69	1091	5	5	7	1	0	-1	1	0	0	2.0	
i 1	741.0176666666666	0.7575000000000001	69	207	7	5	2	1	0	0	1	0	0	2.0	
i 1	741.2532448979592	1.2625	73	207	1	24	10	16	5005	2	16	0	0	5.8593942945992605	
i 1	741.2647823129251	2.525	76	207	2	20	15	16	0	2	16	0	0	1.8593942945992605	
i 1	741.5176666666666	0.2525	75	207	5	1	10	2	0	-2	2	0	0	6.0	
i 1	741.743149659864	4.7975	61	207	4	27	14	6	0	0	6	0	0	4.430396782360776	
i 1	741.7445918367347	0.505	75	696	6	1	16	2	5005	-2	2	0	0	6.0	
i 1	741.7467551020408	1.2625	69	207	4	5	16	1	0	0	1	0	0	2.0	
i 1	741.7626190476191	0.2525	69	207	7	5	7	1	0	-1	1	0	0	2.0	
i 1	741.7655034013605	1.01	72	207	5	9	11	1	0	0	1	0	0	2.0	
i 1	741.9830544217687	1.5150000000000001	73	207	1	24	10	16	0	1	16	0	0	5.8593942945992605	
i 1	741.9866598639455	1.5150000000000001	76	207	2	20	4	16	0	2	16	0	0	1.8593942945992605	
i 1	741.9945918367347	0.2525	72	696	5	5	9	1	5005	0	1	0	0	2.0	
i 1	742.0090136054422	0.2525	72	696	4	4	12	1	5005	-1	1	0	0	3.0	
i 1	742.2366598639455	1.5150000000000001	72	696	5	3	5	0	5005	-1	0	0	0	3.0	
i 1	742.2453129251701	0.2525	72	207	4	24	7	2	0	1	2	0	0	7.0	
i 1	742.2503605442176	2.2725	72	696	5	5	7	0	5005	-1	0	0	0	2.0	
i 1	742.2575714285714	1.5150000000000001	69	207	5	4	1	0	0	-1	0	0	0	3.0	
i 1	742.4844965986395	2.02	69	207	7	5	14	1	0	-1	1	0	0	2.0	
i 1	742.5169455782313	0.2525	75	696	4	24	10	2	5005	1	2	0	0	7.0	
i 1	742.7424285714286	3.2825	72	207	4	24	8	2	0	1	2	0	0	7.0	
i 1	742.748918367347	3.2825	75	696	6	1	4	2	5005	-2	2	0	0	6.0	
i 1	742.748918367347	0.505	72	696	4	4	13	1	5005	-1	1	0	0	3.0	
i 1	742.9960340136055	0.2525	69	207	5	5	7	0	0	0	0	0	0	2.0	
i 1	743.0061292517007	2.7775	73	207	2	24	10	17	0	2	17	0	0	5.8593942945992605	
i 1	743.0133401360545	0.7575000000000001	73	207	1	24	4	16	5005	2	16	0	0	5.8593942945992605	
i 1	743.2409863945578	0.505	75	207	5	1	3	2	0	-2	2	0	0	6.0	
i 1	743.2575714285714	0.2525	72	696	5	5	13	1	5005	0	1	0	0	2.0	
i 1	743.2590136054422	1.2625	69	207	5	3	2	1	0	-1	1	0	0	3.0	
i 1	743.2647823129251	1.2625	72	1091	5	2	3	1	0	0	1	0	0	3.0	
i 1	743.4895442176871	0.2525	69	1091	5	5	10	1	0	-1	1	0	0	2.0	
i 1	743.4909863945578	16.4125	73	207	1	24	4	16	0	252	16	307	0	5.8593942945992605	
i 1	743.5025238095238	2.2725	76	207	1	20	4	16	0	2	16	0	0	1.8593942945992605	
i 1	743.7352176870749	4.2925	69	207	5	5	3	0	0	-1	0	0	0	2.0	
i 1	743.7373809523809	0.2525	73	1091	2	20	14	17	0	1	17	0	0	1.8593942945992605	
i 1	743.7424285714286	0.2525	73	696	2	24	9	17	5005	1	17	0	0	5.8593942945992605	
i 1	743.7546870748299	0.2525	72	207	5	9	12	1	0	0	1	0	0	2.0	
i 1	743.7554081632653	0.2525	75	1091	6	1	11	2	0	1	2	0	0	6.0	
i 1	743.7575714285714	1.01	76	207	2	20	15	16	0	1	16	0	0	1.8593942945992605	
i 1	743.9981972789116	0.7575000000000001	69	207	5	4	8	0	0	-1	0	0	0	3.0	
i 1	744.0082925170068	2.7775	72	696	5	5	10	1	5005	0	1	0	0	2.0	
i 1	744.0097346938776	0.7575000000000001	72	696	5	3	4	0	5005	-1	0	0	0	3.0	
i 1	744.0140612244898	1.01	75	207	5	1	9	2	0	-2	2	0	0	6.0	
i 1	744.0147823129251	1.01	75	696	4	24	15	2	5005	1	2	0	0	7.0	
i 1	744.0155034013605	0.505	73	207	1	24	11	16	5005	1	16	0	0	5.8593942945992605	
i 1	744.016224489796	0.505	76	207	2	20	2	16	0	2	16	0	0	1.8593942945992605	
i 1	744.2388231292517	1.2625	69	1091	5	2	4	0	0	-1	0	0	0	3.0	
i 1	744.2669455782313	1.01	72	207	5	9	15	1	0	0	1	0	0	2.0	
i 1	744.4852176870749	0.2525	69	207	4	5	5	1	0	0	1	0	0	2.0	
i 1	744.4881020408163	0.2525	76	1091	2	20	9	17	0	2	17	0	0	1.8593942945992605	
i 1	744.5118979591837	0.2525	73	696	2	24	10	16	5005	1	16	0	0	5.8593942945992605	
i 1	744.7373809523809	0.2525	69	207	7	5	6	1	0	-1	1	0	0	2.0	
i 1	744.7539659863945	0.505	76	207	1	24	13	16	5005	1	16	0	0	5.8593942945992605	
i 1	744.7618979591837	1.5150000000000001	72	696	4	4	16	1	5005	-1	1	0	0	3.0	
i 1	744.7669455782313	1.5150000000000001	72	207	5	9	16	0	0	0	0	0	0	2.0	
i 1	744.9823333333334	1.5150000000000001	75	1091	6	1	11	2	0	1	2	0	0	6.0	
i 1	745.2417074829932	2.2725	76	207	2	20	4	16	0	1	16	0	0	1.8593942945992605	
i 1	745.2525238095238	0.2525	76	696	2	24	15	17	5005	2	17	0	0	5.8593942945992605	
i 1	745.2676666666666	0.2525	73	1091	2	20	7	17	0	1	17	0	0	1.8593942945992605	
i 1	745.4844965986395	2.525	72	207	5	1	13	8	0	-2	8	0	0	6.0	
i 1	745.5025238095238	0.2525	69	207	5	3	8	1	0	-1	1	0	0	3.0	
i 1	745.5046870748299	0.2525	73	207	1	24	4	17	5005	2	17	0	0	5.8593942945992605	
i 1	745.5090136054422	1.2625	76	207	2	20	15	16	0	2	16	0	0	1.8593942945992605	
i 1	745.7438707482993	0.7575000000000001	69	207	5	4	3	0	0	-1	0	0	0	3.0	
i 1	745.7546870748299	2.02	72	696	5	3	8	0	5005	-1	0	0	0	3.0	
i 1	745.7633401360545	0.7575000000000001	76	207	1	20	3	16	5005	1	16	0	0	1.8593942945992605	
i 1	745.9888231292517	0.505	72	207	4	1	11	2	0	1	2	0	0	6.0	
i 1	746.0082925170068	0.505	72	1091	6	1	3	2	0	1	2	0	0	6.0	
i 1	746.266224489796	0.2525	69	207	5	3	12	1	0	-1	1	0	0	3.0	
i 1	746.2669455782313	0.2525	69	1091	5	5	6	0	0	0	0	0	0	2.0	
i 1	746.4866598639455	0.2525	72	207	3	1	14	2	0	1	2	0	0	6.0	
i 1	746.4866598639455	0.2525	69	207	4	4	16	0	0	-1	0	0	0	3.0	
i 1	746.4938707482993	0.2525	76	207	2	20	5	16	0	2	16	0	0	1.8593942945992605	
i 1	746.4967551020408	1.5150000000000001	72	909	6	1	12	2	0	1	2	0	0	6.0	
i 1	746.501081632653	1.01	66	207	4	27	9	6	0	1	6	0	0	4.430396782360776	
i 1	746.5046870748299	6.8175	61	207	4	27	10	6	0	0	6	0	0	4.430396782360776	
i 1	746.5090136054422	1.01	69	207	4	3	8	1	0	-1	1	0	0	3.0	
i 1	746.5140612244898	1.01	69	909	5	5	10	1	0	-1	1	0	0	2.0	
i 1	746.7417074829932	0.2525	76	909	2	20	3	17	0	2	17	0	0	1.8593942945992605	
i 1	746.7467551020408	0.505	73	909	2	20	13	16	0	1	16	0	0	1.8593942945992605	
i 1	746.7474761904762	0.505	73	696	2	24	7	16	5005	1	16	0	0	5.8593942945992605	
i 1	746.7503605442176	0.2525	69	207	3	5	8	1	0	0	1	0	0	2.0	
i 1	746.7532448979592	0.2525	69	909	5	2	15	1	0	0	1	0	0	3.0	
i 1	746.756850340136	0.2525	75	696	4	24	5	2	5005	1	2	0	0	7.0	
i 1	746.9859387755102	0.7575000000000001	69	909	5	2	13	0	0	-1	0	0	0	3.0	
i 1	746.9895442176871	0.2525	69	207	5	5	14	0	0	0	0	0	0	2.0	
i 1	746.9924285714286	1.5150000000000001	72	207	5	9	6	1	0	0	1	0	0	2.0	
i 1	747.0039659863945	2.525	73	207	2	24	4	17	0	2	17	0	0	5.8593942945992605	
i 1	747.0046870748299	0.2525	72	207	3	24	15	2	0	1	2	0	0	7.0	
i 1	747.2611768707483	2.2725	69	207	3	5	5	1	0	0	1	0	0	2.0	
i 1	747.2676666666666	0.2525	76	207	2	20	5	16	0	1	16	0	0	1.8593942945992605	
i 1	747.4844965986395	0.2525	75	696	4	24	10	2	5005	1	2	0	0	7.0	
i 1	747.4917074829932	11.615	66	207	4	27	5	6	0	1	6	0	0	4.430396782360776	
i 1	747.4938707482993	0.7575000000000001	69	909	6	5	9	1	0	-1	1	0	0	2.0	
i 1	747.4960340136055	1.01	69	909	6	2	8	1	0	0	1	0	0	3.0	
i 1	747.4974761904762	0.505	69	207	3	3	5	1	0	-1	1	0	0	3.0	
i 1	747.5039659863945	1.01	75	207	5	1	4	2	0	-2	2	0	0	6.0	
i 1	747.5054081632653	2.02	69	909	5	5	13	1	0	-1	1	0	0	2.0	
i 1	747.7366598639455	0.2525	72	593	5	3	3	0	0	0	0	0	0	3.0	
i 1	747.7590136054422	0.7575000000000001	72	593	4	24	10	2	0	1	2	0	0	7.0	
i 1	747.7633401360545	0.2525	76	207	2	20	16	16	0	1	16	0	0	1.8593942945992605	
i 1	747.9823333333334	1.5150000000000001	72	593	4	4	11	1	0	-1	1	0	0	3.0	
i 1	747.9852176870749	3.7875	72	207	3	24	13	2	0	1	2	0	0	7.0	
i 1	747.9924285714286	0.2525	73	207	3	20	10	16	0	2	16	0	0	1.8593942945992605	
i 1	748.0104557823129	1.5150000000000001	72	207	5	9	9	0	0	0	0	0	0	2.0	
i 1	748.0111768707483	3.535	72	593	6	1	10	8	0	-2	8	0	0	6.0	
i 1	748.2474761904762	0.2525	69	207	3	5	9	1	0	-1	1	0	0	2.0	
i 1	748.2539659863945	0.2525	73	593	2	24	5	17	0	1	17	0	0	5.8593942945992605	
i 1	748.2582925170068	0.2525	76	909	3	20	16	17	0	1	17	0	0	1.8593942945992605	
i 1	748.2647823129251	0.2525	76	909	2	20	16	16	0	2	16	0	0	1.8593942945992605	
i 1	748.4852176870749	0.2525	72	909	6	1	7	2	0	1	2	0	0	6.0	
i 1	748.4852176870749	0.2525	72	593	5	5	1	0	0	-1	0	0	0	2.0	
i 1	748.5003605442176	0.2525	69	909	5	2	1	0	0	-1	0	0	0	3.0	
i 1	748.5082925170068	1.01	73	207	2	20	7	16	0	1	16	0	0	1.8593942945992605	
i 1	748.7460340136055	0.2525	69	909	6	5	5	1	0	-1	1	0	0	2.0	
i 1	748.756850340136	1.7675	72	593	5	3	15	0	0	0	0	0	0	3.0	
i 1	748.7611768707483	0.2525	72	207	3	1	14	2	0	1	2	0	0	6.0	
i 1	748.9924285714286	2.02	69	593	5	5	2	1	0	-1	1	0	0	2.0	
i 1	748.993149659864	2.525	69	207	3	5	3	1	0	-1	1	0	0	2.0	
i 1	748.9938707482993	1.5150000000000001	69	207	4	4	15	0	0	-1	0	0	0	3.0	
i 1	749.001081632653	3.0300000000000002	76	207	2	20	12	16	0	1	16	0	0	1.8593942945992605	
i 1	749.0082925170068	1.01	72	207	5	1	1	8	0	-2	8	0	0	6.0	
i 1	749.0090136054422	1.2625	75	909	6	1	5	2	0	1	2	0	0	6.0	
i 1	749.016224489796	1.2625	76	207	3	20	11	16	0	1	16	0	0	1.8593942945992605	
i 1	749.5147823129251	0.505	69	207	3	3	15	1	0	-1	1	0	0	3.0	
i 1	749.5155034013605	0.2525	69	909	6	5	2	1	0	-1	1	0	0	2.0	
i 1	749.7503605442176	0.505	73	207	2	20	1	16	0	1	16	0	0	1.8593942945992605	
i 1	749.7669455782313	0.2525	69	207	3	5	10	1	0	0	1	0	0	2.0	
i 1	749.9844965986395	0.2525	69	909	5	5	15	1	0	-1	1	0	0	2.0	
i 1	749.9866598639455	1.2625	72	207	5	9	16	1	0	0	1	0	0	2.0	
i 1	750.0090136054422	2.7775	73	207	2	24	2	17	0	2	17	0	0	5.8593942945992605	
i 1	750.0126190476191	1.2625	69	909	6	2	3	1	0	0	1	0	0	3.0	
i 1	750.2590136054422	0.7575000000000001	73	909	3	20	7	17	0	1	17	0	0	1.8593942945992605	
i 1	750.2597346938776	0.7575000000000001	73	909	2	20	8	16	0	2	16	0	0	1.8593942945992605	
i 1	750.2604557823129	3.2825	69	207	5	5	8	0	0	-1	0	0	0	2.0	
i 1	750.2640612244898	0.2525	72	593	4	24	1	2	0	1	2	0	0	7.0	
i 1	750.5118979591837	3.0300000000000002	72	593	5	5	8	0	0	-1	0	0	0	2.0	
i 1	750.516224489796	0.2525	75	909	6	1	5	2	0	1	2	0	0	6.0	
i 1	750.5176666666666	0.2525	69	909	5	2	5	0	0	-1	0	0	0	3.0	
i 1	750.7626190476191	0.7575000000000001	72	593	5	3	3	0	0	0	0	0	0	3.0	
i 1	750.7640612244898	0.7575000000000001	69	207	4	4	7	0	0	-1	0	0	0	3.0	
i 1	750.7676666666666	0.2525	72	593	4	24	11	2	0	1	2	0	0	7.0	
i 1	750.9830544217687	3.0300000000000002	72	909	6	1	15	2	0	1	2	0	0	6.0	
i 1	750.9859387755102	0.2525	76	207	3	20	14	16	0	2	16	0	0	1.8593942945992605	
i 1	750.9909863945578	0.7575000000000001	69	909	5	2	16	0	0	-1	0	0	0	3.0	
i 1	750.9996394557824	3.0300000000000002	72	207	3	1	9	2	0	1	2	0	0	6.0	
i 1	751.0032448979592	0.7575000000000001	69	207	3	3	5	1	0	-1	1	0	0	3.0	
i 1	751.0075714285714	0.2525	76	207	2	20	15	17	0	2	17	0	0	1.8593942945992605	
i 1	751.2417074829932	1.01	72	593	4	4	16	1	0	-1	1	0	0	3.0	
i 1	751.2438707482993	0.2525	76	909	2	20	5	17	0	2	17	0	0	1.8593942945992605	
i 1	751.2496394557824	0.2525	73	909	3	20	2	16	0	2	16	0	0	1.8593942945992605	
i 1	751.2604557823129	1.01	72	207	5	9	15	0	0	0	0	0	0	2.0	
i 1	751.4823333333334	0.2525	69	593	5	5	11	1	0	-1	1	0	0	2.0	
i 1	751.4902653061224	0.505	76	207	3	20	13	17	0	2	17	0	0	1.8593942945992605	
i 1	751.5090136054422	3.2825	73	207	1	24	12	17	0	252	17	307	0	5.8593942945992605	
i 1	751.5176666666666	1.7675	73	207	2	20	1	17	0	1	17	0	0	1.8593942945992605	
i 1	751.7575714285714	0.2525	72	593	4	24	16	2	0	1	2	0	0	7.0	
i 1	751.7611768707483	2.525	72	207	5	9	2	1	0	0	1	0	0	2.0	
i 1	751.7655034013605	2.525	69	909	6	2	16	1	0	0	1	0	0	3.0	
i 1	751.766224489796	0.2525	69	909	6	5	14	1	0	-1	1	0	0	2.0	
i 1	751.993149659864	0.2525	72	207	5	1	11	8	0	-2	8	0	0	6.0	
i 1	752.2395442176871	0.2525	69	207	4	4	8	0	0	-1	0	0	0	3.0	
i 1	752.2474761904762	1.01	76	207	3	20	12	17	0	2	17	0	0	1.8593942945992605	
i 1	752.251081632653	1.7675	76	207	2	20	13	16	0	1	16	0	0	1.8593942945992605	
i 1	752.4924285714286	0.2525	72	593	4	4	11	1	0	-1	1	0	0	3.0	
i 1	752.7539659863945	0.2525	69	909	6	5	1	1	0	-1	1	0	0	2.0	
i 1	752.9823333333334	1.5150000000000001	69	593	5	5	15	1	0	-1	1	0	0	2.0	
i 1	753.001081632653	1.5150000000000001	69	207	3	5	3	1	0	-1	1	0	0	2.0	
i 1	753.2323333333334	0.2525	72	593	4	24	1	2	0	1	2	0	0	7.0	
i 1	753.2323333333334	0.7575000000000001	73	207	3	20	8	17	0	1	17	0	0	1.8593942945992605	
i 1	753.2409863945578	0.7575000000000001	76	207	1	20	4	17	0	2	17	0	0	1.8593942945992605	
i 1	753.248918367347	0.2525	72	593	5	3	9	0	0	0	0	0	0	3.0	
i 1	753.4852176870749	3.535	72	593	6	1	16	8	0	-2	8	0	0	6.0	
i 1	753.4873809523809	1.5150000000000001	72	593	4	4	13	1	0	-1	1	0	0	3.0	
i 1	753.4938707482993	0.2525	69	207	3	5	10	1	0	0	1	0	0	2.0	
i 1	753.498918367347	3.535	72	207	3	24	11	2	0	1	2	0	0	7.0	
i 1	753.5075714285714	1.7675	73	207	2	24	9	17	0	2	17	0	0	5.8593942945992605	
i 1	753.7424285714286	1.2625	72	207	5	9	11	0	0	0	0	0	0	2.0	
i 1	753.7453129251701	2.7775	69	909	4	5	10	1	0	-1	1	0	0	2.0	
i 1	753.9974761904762	0.2525	75	909	6	1	2	2	0	1	2	0	0	6.0	
i 1	754.0003605442176	2.2725	69	207	5	5	7	0	0	0	0	0	0	2.0	
i 1	754.2438707482993	0.2525	69	207	3	3	12	1	0	-1	1	0	0	3.0	
i 1	754.2445918367347	1.5150000000000001	72	593	4	24	1	2	0	1	2	0	0	7.0	
i 1	754.4823333333334	1.5150000000000001	72	593	5	3	12	0	0	0	0	0	0	3.0	
i 1	754.483775510204	0.2525	69	207	3	5	3	1	0	0	1	0	0	2.0	
i 1	754.4852176870749	1.7675	69	207	3	4	10	0	0	-1	0	0	0	3.0	
i 1	754.4917074829932	0.2525	76	207	1	20	11	17	0	2	17	0	0	1.8593942945992605	
i 1	754.4938707482993	1.01	75	207	7	1	5	2	0	-2	2	0	0	6.0	
i 1	754.7388231292517	0.2525	76	909	1	20	11	16	0	1	16	0	0	1.8593942945992605	
i 1	754.7445918367347	0.2525	73	909	3	20	6	16	0	2	16	0	0	1.8593942945992605	
i 1	754.7481972789116	0.505	69	909	6	5	7	1	0	-1	1	0	0	2.0	
i 1	754.7582925170068	0.7575000000000001	69	909	6	2	2	1	0	0	1	0	0	3.0	
i 1	754.7611768707483	0.2525	73	593	2	24	9	16	0	2	16	0	0	5.8593942945992605	
i 1	754.7618979591837	2.02	76	207	2	20	11	16	0	1	16	0	0	1.8593942945992605	
i 1	754.7640612244898	0.7575000000000001	72	207	5	9	5	1	0	0	1	0	0	2.0	
i 1	754.9909863945578	1.01	76	207	3	20	1	16	0	2	16	0	0	1.8593942945992605	
i 1	754.9967551020408	1.01	76	207	1	20	7	16	0	1	16	0	0	1.8593942945992605	
i 1	755.2604557823129	0.2525	69	207	5	5	15	0	0	-1	0	0	0	2.0	
i 1	755.4866598639455	0.2525	72	593	5	5	15	0	0	-1	0	0	0	2.0	
i 1	755.4909863945578	1.5150000000000001	69	207	3	3	3	1	0	-1	1	0	0	3.0	
i 1	755.5003605442176	1.5150000000000001	69	909	6	2	6	0	0	-1	0	0	0	3.0	
i 1	755.733775510204	0.505	72	207	3	1	6	2	0	1	2	0	0	6.0	
i 1	755.7424285714286	3.2825	69	207	3	5	14	1	0	0	1	0	0	2.0	
i 1	755.7474761904762	1.01	73	207	2	24	3	17	0	2	17	0	0	5.8593942945992605	
i 1	755.7611768707483	3.2825	69	909	6	5	11	1	0	-1	1	0	0	2.0	
i 1	755.998918367347	0.505	76	909	1	20	8	17	0	1	17	0	0	1.8593942945992605	
i 1	756.0054081632653	0.505	73	909	3	20	10	16	0	2	16	0	0	1.8593942945992605	
i 1	756.2467551020408	1.5150000000000001	72	207	5	1	5	8	0	-2	8	0	0	6.0	
i 1	756.2640612244898	1.7675	72	207	5	9	4	0	0	0	0	0	0	2.0	
i 1	756.4909863945578	0.505	76	207	1	20	1	17	0	1	17	0	0	1.8593942945992605	
i 1	756.498918367347	1.7675	72	593	4	4	2	1	0	-1	1	0	0	3.0	
i 1	756.5090136054422	0.2525	69	593	5	5	13	1	0	-1	1	0	0	2.0	
i 1	756.5104557823129	1.2625	75	909	6	1	11	2	0	1	2	0	0	6.0	
i 1	756.516224489796	1.5150000000000001	76	207	3	20	3	17	0	1	17	0	0	1.8593942945992605	
i 1	756.7481972789116	0.505	69	207	3	5	16	1	0	-1	1	0	0	2.0	
i 1	757.0140612244898	0.2525	72	909	6	1	5	2	0	1	2	0	0	6.0	
i 1	757.0169455782313	0.2525	72	207	5	9	16	1	0	0	1	0	0	2.0	
i 1	757.2409863945578	2.525	76	207	2	20	15	16	0	1	16	0	0	1.8593942945992605	
i 1	757.2532448979592	1.7675	72	207	3	24	7	2	0	1	2	0	0	7.0	
i 1	757.256850340136	0.2525	69	207	5	5	5	0	0	-1	0	0	0	2.0	
i 1	757.2575714285714	2.02	72	593	6	1	8	8	0	-2	8	0	0	6.0	
i 1	757.2640612244898	1.7675	69	909	6	2	15	1	0	0	1	0	0	3.0	
i 1	757.4859387755102	1.01	76	207	1	20	13	17	0	1	17	0	0	1.8593942945992605	
i 1	757.4873809523809	1.5150000000000001	72	207	5	9	8	1	0	0	1	0	0	2.0	
i 1	757.4938707482993	0.505	72	593	5	5	2	0	0	-1	0	0	0	2.0	
i 1	757.4960340136055	2.2725	73	207	2	24	8	17	0	2	17	0	0	5.8593942945992605	
i 1	757.7597346938776	0.2525	72	593	4	24	1	2	0	1	2	0	0	7.0	
i 1	757.9917074829932	0.2525	69	207	5	5	5	0	0	0	0	0	0	2.0	
i 1	758.0155034013605	0.2525	72	909	6	1	8	2	0	1	2	0	0	6.0	
i 1	758.2388231292517	0.2525	76	207	3	20	3	17	0	1	17	0	0	1.8593942945992605	
i 1	758.2438707482993	0.2525	72	593	5	5	11	0	0	-1	0	0	0	2.0	
i 1	758.2532448979592	0.2525	69	207	3	3	15	1	0	-1	1	0	0	3.0	
i 1	758.2546870748299	0.2525	72	593	4	24	4	2	0	1	2	0	0	7.0	
i 1	758.4823333333334	0.505	69	593	5	5	2	1	0	-1	1	0	0	2.0	
i 1	758.4859387755102	1.2625	72	207	3	1	7	2	0	1	2	0	0	6.0	
i 1	758.4873809523809	2.525	72	909	6	1	4	2	0	1	2	0	0	6.0	
i 1	758.4938707482993	0.2525	73	909	3	20	15	17	0	1	17	0	0	1.8593942945992605	
i 1	758.5018027210884	0.7575000000000001	72	593	4	4	12	1	0	-1	1	0	0	3.0	
i 1	758.5046870748299	1.2625	69	207	3	5	4	1	0	-1	1	0	0	2.0	
i 1	758.5061292517007	0.2525	76	593	2	24	12	17	0	2	17	0	0	5.8593942945992605	
i 1	758.5126190476191	0.2525	73	909	1	20	6	17	0	1	17	0	0	1.8593942945992605	
i 1	758.5176666666666	0.7575000000000001	72	207	5	9	13	0	0	0	0	0	0	2.0	
i 1	758.7330544217687	1.01	69	207	3	4	14	0	0	-1	0	0	0	3.0	
i 1	758.7417074829932	0.2525	72	593	5	3	6	0	0	0	0	0	0	3.0	
i 1	758.743149659864	0.505	76	207	1	24	1	17	0	252	17	307	0	5.8593942945992605	
i 1	758.7460340136055	0.505	73	207	1	20	5	16	0	2	16	0	0	1.8593942945992605	
i 1	759.0097346938776	0.2525	76	207	1	20	11	17	0	1	17	0	0	1.8593942945992605	
i 1	759.0111768707483	0.7575000000000001	72	593	5	3	11	0	0	0	0	0	0	3.0	
i 1	759.016224489796	0.2525	76	207	1	20	1	16	0	2	16	0	0	1.8593942945992605	
i 1	759.0176666666666	0.2525	69	909	4	5	7	1	0	-1	1	0	0	2.0	
i 1	759.0176666666666	1.2625	69	593	6	5	14	1	0	-1	1	0	0	2.0	
i 1	759.2330544217687	0.2525	72	207	3	24	15	2	0	1	2	0	0	7.0	
i 1	759.2453129251701	0.505	72	207	5	9	16	1	0	0	1	0	0	2.0	
i 1	759.2460340136055	0.505	73	909	1	20	7	16	0	1	16	0	0	1.8593942945992605	
i 1	759.248918367347	1.5150000000000001	69	909	6	2	13	1	0	0	1	0	0	3.0	
i 1	759.2525238095238	0.2525	69	207	5	5	4	0	0	0	0	0	0	2.0	
i 1	759.2546870748299	0.505	73	593	3	20	3	16	0	1	16	0	0	1.8593942945992605	
i 1	759.2604557823129	0.505	73	909	1	20	16	17	0	1	17	0	0	1.8593942945992605	
i 1	759.4888231292517	0.2525	72	207	7	1	4	8	0	-2	8	0	0	6.0	
i 1	759.506850340136	0.2525	69	909	4	5	13	1	0	-1	1	0	0	2.0	
i 1	759.7359387755102	0.505	72	206	3	5	3	0	0	-1	0	0	0	2.0	
i 1	759.7395442176871	0.2525	73	1175	1	20	14	16	0	2	16	0	0	1.8593942945992605	
i 1	759.7395442176871	1.01	73	1175	2	24	11	16	0	2	16	0	0	5.8593942945992605	
i 1	759.7424285714286	16.665	61	206	1	27	15	6	0	252	6	307	0	4.430396782360776	
i 1	759.7460340136055	1.7675	75	206	3	1	1	2	0	-2	2	0	0	6.0	
i 1	759.7460340136055	0.2525	72	593	4	4	10	1	0	-1	1	0	0	3.0	
i 1	759.7481972789116	2.02	72	1175	5	5	3	1	0	0	1	0	0	2.0	
i 1	759.7525238095238	4.7975	76	1175	2	20	6	17	0	1	17	0	0	1.8593942945992605	
i 1	759.7539659863945	0.2525	76	1175	1	20	4	16	0	1	16	0	0	1.8593942945992605	
i 1	759.7561292517007	1.01	72	1175	5	9	9	1	0	-1	1	0	0	2.0	
i 1	759.7618979591837	1.7675	72	593	5	5	16	0	0	-1	0	0	0	2.0	
i 1	759.7626190476191	16.665	61	206	1	27	9	9	0	252	9	307	0	4.430396782360776	
i 1	759.9844965986395	0.505	73	909	1	20	6	16	0	2	16	0	0	1.8593942945992605	
i 1	759.9859387755102	0.505	76	909	1	20	5	16	0	1	16	0	0	1.8593942945992605	
i 1	760.0147823129251	0.2525	69	909	6	2	5	0	0	-1	0	0	0	3.0	
i 1	760.2352176870749	0.2525	75	909	5	1	8	2	0	1	2	0	0	6.0	
i 1	760.2388231292517	0.505	69	206	3	5	12	0	0	-1	0	0	0	2.0	
i 1	760.2518027210884	1.5150000000000001	72	593	5	3	2	0	0	0	0	0	0	3.0	
i 1	760.2525238095238	1.5150000000000001	69	206	3	4	1	1	0	-1	1	0	0	3.0	
i 1	760.4844965986395	2.02	72	206	3	24	10	2	0	-2	2	0	0	7.0	
i 1	760.4974761904762	1.01	76	1175	1	20	5	16	0	1	16	0	0	1.8593942945992605	
i 1	760.5133401360545	2.02	72	593	6	1	2	8	0	-2	8	0	0	6.0	
i 1	760.5169455782313	1.01	73	1175	1	20	5	16	0	2	16	0	0	1.8593942945992605	
i 1	760.7445918367347	0.2525	69	1175	5	9	15	1	0	-1	1	0	0	2.0	
i 1	760.7575714285714	0.2525	69	1175	5	5	12	1	0	-1	1	0	0	2.0	
i 1	760.9881020408163	2.2725	69	593	6	5	7	1	0	-1	1	0	0	2.0	
i 1	761.0003605442176	1.5150000000000001	69	909	6	2	15	0	0	-1	0	0	0	3.0	
i 1	761.0090136054422	2.02	72	206	3	5	5	0	0	-1	0	0	0	2.0	
i 1	761.233775510204	1.2625	69	206	3	3	4	1	0	-1	1	0	0	3.0	
i 1	761.233775510204	0.2525	76	206	1	20	16	17	0	2	17	0	0	1.8593942945992605	
i 1	761.4866598639455	0.2525	76	593	3	20	7	16	0	1	16	0	0	1.8593942945992605	
i 1	761.4888231292517	0.2525	72	1175	6	1	1	8	0	-2	8	0	0	6.0	
i 1	761.4888231292517	0.2525	76	909	1	20	3	17	0	2	17	0	0	1.8593942945992605	
i 1	761.5147823129251	0.2525	76	909	1	20	10	16	0	2	16	0	0	1.8593942945992605	
i 1	761.7388231292517	0.2525	69	1175	5	5	8	1	0	-1	1	0	0	2.0	
i 1	761.7402653061224	2.7775	72	593	4	4	6	1	0	-1	1	0	0	3.0	
i 1	761.7467551020408	1.2625	76	1175	1	20	9	16	0	2	16	0	0	1.8593942945992605	
i 1	761.748918367347	2.02	76	1175	1	20	9	17	0	2	17	0	0	1.8593942945992605	
i 1	761.7539659863945	0.2525	72	909	6	1	4	2	0	1	2	0	0	6.0	
i 1	761.7590136054422	0.505	76	206	1	20	10	17	0	1	17	0	0	1.8593942945992605	
i 1	761.9881020408163	0.2525	69	909	4	5	9	1	0	-1	1	0	0	2.0	
i 1	761.998918367347	0.7575000000000001	69	1175	5	9	4	1	0	-1	1	0	0	2.0	
i 1	762.0003605442176	1.5150000000000001	72	593	4	24	13	2	0	1	2	0	0	7.0	
i 1	762.0147823129251	1.2625	72	1175	6	1	7	8	0	-2	8	0	0	6.0	
i 1	762.2525238095238	1.2625	72	1175	5	9	10	1	0	-1	1	0	0	2.0	
i 1	762.2597346938776	0.2525	69	909	4	5	11	1	0	-1	1	0	0	2.0	
i 1	762.2647823129251	1.2625	69	909	6	2	16	1	0	0	1	0	0	3.0	
i 1	762.4823333333334	3.2825	69	1175	5	5	4	1	0	-1	1	0	0	2.0	
i 1	762.4960340136055	3.2825	69	909	4	5	2	1	0	-1	1	0	0	2.0	
i 1	762.5046870748299	0.2525	75	909	5	1	16	2	0	1	2	0	0	6.0	
i 1	762.7366598639455	3.2825	72	593	6	1	9	8	0	-2	8	0	0	6.0	
i 1	762.7474761904762	3.2825	72	206	3	24	12	2	0	-2	2	0	0	7.0	
i 1	762.9844965986395	1.5150000000000001	69	1175	5	9	13	1	0	-1	1	0	0	2.0	
i 1	763.0061292517007	0.2525	73	1175	2	24	4	16	0	2	16	0	0	5.8593942945992605	
i 1	763.2460340136055	0.2525	76	206	1	20	6	17	0	1	17	0	0	1.8593942945992605	
i 1	763.2597346938776	0.505	72	206	3	5	6	0	0	-1	0	0	0	2.0	
i 1	763.4881020408163	0.2525	76	1175	1	20	8	16	0	2	16	0	0	1.8593942945992605	
i 1	763.4895442176871	1.01	73	1175	2	24	7	16	0	2	16	0	0	5.8593942945992605	
i 1	763.5003605442176	0.2525	69	909	6	2	15	0	0	-1	0	0	0	3.0	
i 1	763.501081632653	0.2525	75	206	3	1	4	2	0	-2	2	0	0	6.0	
i 1	763.7453129251701	0.505	73	909	1	20	3	16	0	2	16	0	0	1.8593942945992605	
i 1	763.748918367347	1.2625	75	1175	6	1	1	2	0	-2	2	0	0	6.0	
i 1	763.748918367347	0.2525	69	593	6	5	11	1	0	-1	1	0	0	2.0	
i 1	763.7626190476191	1.7675	72	593	5	3	1	0	0	0	0	0	0	3.0	
i 1	763.766224489796	0.505	76	909	1	20	8	17	0	2	17	0	0	1.8593942945992605	
i 1	763.993149659864	1.5150000000000001	69	206	3	4	2	1	0	-1	1	0	0	3.0	
i 1	763.993149659864	0.2525	73	593	3	20	10	16	0	2	16	0	0	1.8593942945992605	
i 1	764.001081632653	0.2525	72	593	5	5	9	0	0	-1	0	0	0	2.0	
i 1	764.0147823129251	1.01	75	909	5	1	8	2	0	1	2	0	0	6.0	
i 1	764.2366598639455	0.505	73	206	1	20	16	17	0	2	17	0	0	1.8593942945992605	
i 1	764.2373809523809	0.2525	73	1175	1	20	7	16	0	2	16	0	0	1.8593942945992605	
i 1	764.2445918367347	1.2625	73	1175	1	20	11	16	0	2	16	0	0	1.8593942945992605	
i 1	764.4873809523809	0.2525	72	593	5	5	6	0	0	-1	0	0	0	2.0	
i 1	764.5140612244898	0.2525	69	909	6	2	4	0	0	-1	0	0	0	3.0	
i 1	764.7344965986395	0.2525	69	1175	5	9	12	1	0	-1	1	0	0	2.0	
i 1	764.7438707482993	0.505	69	593	4	5	16	1	0	-1	1	0	0	2.0	
i 1	764.9938707482993	1.2625	72	1175	5	9	3	1	0	-1	1	0	0	2.0	
i 1	765.0032448979592	0.2525	72	1175	6	1	3	8	0	-2	8	0	0	6.0	
i 1	765.0147823129251	1.2625	69	909	6	2	7	1	0	0	1	0	0	3.0	
i 1	765.2373809523809	2.7775	69	206	3	5	14	0	0	-1	0	0	0	2.0	
i 1	765.2381020408163	0.2525	73	1175	1	20	13	16	0	2	16	0	0	1.8593942945992605	
i 1	765.248918367347	0.7575000000000001	73	1175	2	24	10	16	0	2	16	0	0	5.8593942945992605	
i 1	765.2518027210884	2.7775	69	909	4	5	5	1	0	-1	1	0	0	2.0	
i 1	765.2633401360545	3.535	75	206	6	1	1	2	0	-2	2	0	0	6.0	
i 1	765.4881020408163	0.2525	76	593	1	20	11	16	0	1	16	0	0	1.8593942945992605	
i 1	765.4945918367347	3.2825	72	909	5	1	4	2	0	1	2	0	0	6.0	
i 1	765.501081632653	3.7875	76	1175	2	20	13	17	0	1	17	0	0	1.8593942945992605	
i 1	765.5039659863945	0.2525	69	206	3	3	3	1	0	-1	1	0	0	3.0	
i 1	765.5133401360545	0.2525	73	909	1	20	7	16	0	1	16	0	0	1.8593942945992605	
i 1	765.5147823129251	0.2525	76	909	1	20	16	16	0	2	16	0	0	1.8593942945992605	
i 1	765.7344965986395	1.5150000000000001	76	206	1	24	15	17	0	252	17	307	0	5.8593942945992605	
i 1	765.7359387755102	1.5150000000000001	76	1175	1	20	15	17	0	2	17	0	0	1.8593942945992605	
i 1	765.7503605442176	1.5150000000000001	76	1175	1	20	12	16	0	2	16	0	0	1.8593942945992605	
i 1	765.7525238095238	0.7575000000000001	69	206	3	4	12	1	0	-1	1	0	0	3.0	
i 1	765.7554081632653	0.7575000000000001	72	593	5	3	14	0	0	0	0	0	0	3.0	
i 1	765.7575714285714	0.2525	72	206	3	5	3	0	0	-1	0	0	0	2.0	
i 1	765.993149659864	0.7575000000000001	69	909	6	2	11	0	0	-1	0	0	0	3.0	
i 1	765.9945918367347	0.7575000000000001	69	206	3	3	3	1	0	-1	1	0	0	3.0	
i 1	766.0003605442176	0.2525	75	1175	6	1	9	2	0	-2	2	0	0	6.0	
i 1	766.0169455782313	0.2525	72	1175	5	5	2	1	0	0	1	0	0	2.0	
i 1	766.2532448979592	0.2525	72	593	6	1	8	8	0	-2	8	0	0	6.0	
i 1	766.2546870748299	1.01	72	593	4	4	2	1	0	-1	1	0	0	3.0	
i 1	766.2647823129251	1.01	69	1175	5	9	6	1	0	-1	1	0	0	2.0	
i 1	766.7330544217687	2.525	72	1175	5	9	13	1	0	-1	1	0	0	2.0	
i 1	766.7611768707483	2.7775	69	909	6	2	2	1	0	0	1	0	0	3.0	
i 1	767.001081632653	0.2525	69	1175	5	5	6	1	0	-1	1	0	0	2.0	
i 1	767.2373809523809	0.505	76	909	1	20	15	16	0	2	16	0	0	1.8593942945992605	
i 1	767.2402653061224	0.505	73	909	1	20	8	17	0	2	17	0	0	1.8593942945992605	
i 1	767.2438707482993	0.2525	72	593	5	3	7	0	0	0	0	0	0	3.0	
i 1	767.2453129251701	1.01	72	206	3	5	5	0	0	-1	0	0	0	2.0	
i 1	767.2460340136055	0.505	73	593	1	20	6	16	0	2	16	0	0	1.8593942945992605	
i 1	767.2582925170068	0.505	76	593	1	24	10	17	0	252	17	307	0	5.8593942945992605	
i 1	767.5025238095238	0.2525	69	909	6	2	13	0	0	-1	0	0	0	3.0	
i 1	767.506850340136	0.7575000000000001	69	593	4	5	2	1	0	-1	1	0	0	2.0	
i 1	767.7344965986395	2.7775	72	593	6	5	12	0	0	-1	0	0	0	2.0	
i 1	767.7402653061224	2.2725	69	1175	5	9	9	1	0	-1	1	0	0	2.0	
i 1	767.7402653061224	2.7775	72	1175	5	5	6	1	0	0	1	0	0	2.0	
i 1	767.7525238095238	0.2525	76	1175	1	20	16	16	0	1	16	0	0	1.8593942945992605	
i 1	767.7525238095238	0.2525	76	1175	1	20	10	17	0	1	17	0	0	1.8593942945992605	
i 1	767.7575714285714	1.5150000000000001	73	1175	2	24	16	16	0	2	16	0	0	5.8593942945992605	
i 1	767.9974761904762	0.2525	76	909	1	20	11	17	0	2	17	0	0	1.8593942945992605	
i 1	768.001081632653	0.2525	76	909	1	20	8	17	0	2	17	0	0	1.8593942945992605	
i 1	768.001081632653	0.2525	73	593	1	20	5	16	0	1	16	0	0	1.8593942945992605	
i 1	768.0126190476191	0.2525	75	1175	6	1	12	2	0	-2	2	0	0	6.0	
i 1	768.2395442176871	2.2725	72	593	6	1	15	8	0	-2	8	0	0	6.0	
i 1	768.2417074829932	1.01	76	1175	1	20	12	17	0	2	17	0	0	1.8593942945992605	
i 1	768.2438707482993	2.02	73	1175	1	20	9	16	0	1	16	0	0	1.8593942945992605	
i 1	768.2611768707483	2.2725	72	206	3	24	7	2	0	-2	2	0	0	7.0	
i 1	768.2640612244898	0.2525	69	206	3	5	6	0	0	-1	0	0	0	2.0	
i 1	768.266224489796	1.01	76	206	1	24	11	17	0	2	17	0	0	5.8593942945992605	
i 1	768.4852176870749	0.2525	72	206	3	5	2	0	0	-1	0	0	0	2.0	
i 1	768.7373809523809	0.2525	75	1175	6	1	13	2	0	-2	2	0	0	6.0	
i 1	768.7395442176871	0.7575000000000001	69	593	4	5	6	1	0	-1	1	0	0	2.0	
i 1	768.7669455782313	1.2625	72	593	4	4	2	1	0	-1	1	0	0	3.0	
i 1	769.0140612244898	0.2525	75	909	5	1	4	2	0	1	2	0	0	6.0	
i 1	769.2438707482993	1.2625	72	593	4	24	14	2	0	1	2	0	0	7.0	
i 1	769.2647823129251	0.7575000000000001	73	1175	1	24	15	16	0	252	16	307	0	5.8593942945992605	
i 1	769.4823333333334	1.5150000000000001	72	593	5	3	9	0	0	0	0	0	0	3.0	
i 1	769.483775510204	1.5150000000000001	69	206	3	4	16	1	0	-1	1	0	0	3.0	
i 1	769.5082925170068	1.01	72	1175	6	1	8	8	0	-2	8	0	0	6.0	
i 1	769.5169455782313	0.7575000000000001	69	909	4	5	9	1	0	-1	1	0	0	2.0	
i 1	769.7352176870749	0.7575000000000001	69	909	6	2	2	1	0	0	1	0	0	3.0	
i 1	769.7604557823129	0.7575000000000001	72	1175	5	9	11	1	0	-1	1	0	0	2.0	
i 1	769.9823333333334	0.505	73	1175	2	24	9	16	0	2	16	0	0	5.8593942945992605	
i 1	769.9881020408163	0.2525	76	1175	1	20	9	17	0	2	17	0	0	1.8593942945992605	
i 1	770.2344965986395	6.0600000000000005	76	1175	2	20	9	17	0	1	17	0	0	1.8593942945992605	
i 1	770.2445918367347	0.2525	69	1175	5	5	11	1	0	-1	1	0	0	2.0	
i 1	770.251081632653	0.2525	76	909	1	20	13	17	0	2	17	0	0	1.8593942945992605	
i 1	770.2597346938776	0.2525	73	909	1	20	12	17	0	2	17	0	0	1.8593942945992605	
i 1	770.2676666666666	0.2525	73	593	1	20	12	16	0	1	16	0	0	1.8593942945992605	
i 1	770.4881020408163	0.7575000000000001	72	593	4	5	10	0	0	-1	0	0	0	2.0	
i 1	770.4888231292517	0.2525	72	909	5	1	2	2	0	1	2	0	0	6.0	
i 1	770.4945918367347	0.7575000000000001	72	1175	6	5	15	1	0	0	1	0	0	2.0	
i 1	770.5032448979592	1.5150000000000001	69	909	6	2	10	0	0	-1	0	0	0	3.0	
i 1	770.5090136054422	2.2725	73	1175	3	24	8	16	0	2	16	0	0	5.8593942945992605	
i 1	770.5140612244898	3.0300000000000002	72	206	5	24	2	2	0	-2	2	0	0	7.0	
i 1	770.5155034013605	1.5150000000000001	69	206	3	3	7	1	0	-1	1	0	0	3.0	
i 1	770.516224489796	0.2525	69	909	4	5	11	1	0	-1	1	0	0	2.0	
i 1	770.5169455782313	3.0300000000000002	72	593	5	1	11	8	0	-2	8	0	0	6.0	
i 1	770.7323333333334	1.7675	72	206	3	5	7	0	0	-1	0	0	0	2.0	
i 1	770.7366598639455	0.2525	76	909	1	20	16	17	0	2	17	0	0	1.8593942945992605	
i 1	770.7395442176871	2.02	69	593	4	5	5	1	0	-1	1	0	0	2.0	
i 1	770.7417074829932	0.2525	73	909	1	20	8	17	0	1	17	0	0	1.8593942945992605	
i 1	770.7424285714286	0.2525	72	593	4	24	7	2	0	1	2	0	0	7.0	
i 1	770.7481972789116	0.2525	73	593	1	20	10	17	0	1	17	0	0	1.8593942945992605	
i 1	770.9881020408163	0.2525	72	593	4	4	12	1	0	-1	1	0	0	3.0	
i 1	770.9917074829932	1.2625	76	1175	1	20	4	16	0	2	16	0	0	1.8593942945992605	
i 1	771.001081632653	1.01	75	1175	6	1	3	2	0	-2	2	0	0	6.0	
i 1	771.0018027210884	1.2625	76	1175	1	20	1	17	0	2	17	0	0	1.8593942945992605	
i 1	771.0054081632653	1.5150000000000001	75	909	5	1	10	2	0	1	2	0	0	6.0	
i 1	771.2496394557824	0.2525	72	593	5	3	4	0	0	0	0	0	0	3.0	
i 1	771.2539659863945	0.2525	69	909	4	5	1	1	0	-1	1	0	0	2.0	
i 1	771.4967551020408	1.5150000000000001	72	593	4	4	14	1	0	-1	1	0	0	3.0	
i 1	771.4974761904762	3.2825	69	1175	5	5	5	1	0	-1	1	0	0	2.0	
i 1	771.5118979591837	1.7675	69	1175	5	9	9	1	0	-1	1	0	0	2.0	
i 1	771.9917074829932	3.0300000000000002	69	909	4	5	12	1	0	-1	1	0	0	2.0	
i 1	772.0147823129251	0.2525	69	909	5	2	10	1	0	0	1	0	0	3.0	
i 1	772.2467551020408	0.2525	76	593	1	20	10	16	0	2	16	0	0	1.8593942945992605	
i 1	772.2575714285714	0.2525	72	593	5	3	8	0	0	0	0	0	0	3.0	
i 1	772.2633401360545	0.2525	73	909	1	20	16	17	0	2	17	0	0	1.8593942945992605	
i 1	772.2655034013605	0.2525	76	909	1	20	7	17	0	2	17	0	0	1.8593942945992605	
i 1	772.483775510204	1.5150000000000001	72	1175	5	9	13	1	0	-1	1	0	0	2.0	
i 1	772.5054081632653	3.535	72	909	5	1	16	2	0	1	2	0	0	6.0	
i 1	772.5054081632653	0.2525	73	1175	1	20	6	17	0	2	17	0	0	1.8593942945992605	
i 1	772.5126190476191	1.5150000000000001	69	909	5	2	12	1	0	0	1	0	0	3.0	
i 1	772.5147823129251	0.2525	76	1175	1	20	14	16	0	2	16	0	0	1.8593942945992605	
i 1	772.7330544217687	0.505	73	909	1	20	12	16	0	2	16	0	0	1.8593942945992605	
i 1	772.7467551020408	0.505	76	593	1	24	7	17	0	252	17	307	0	5.8593942945992605	
i 1	772.7575714285714	0.2525	72	593	4	5	8	0	0	-1	0	0	0	2.0	
i 1	772.9844965986395	3.2825	75	206	6	1	8	2	0	-2	2	0	0	6.0	
i 1	772.9938707482993	0.2525	72	1175	6	5	15	1	0	0	1	0	0	2.0	
i 1	773.2438707482993	1.01	76	1175	1	20	11	17	0	2	17	0	0	1.8593942945992605	
i 1	773.256850340136	3.0300000000000002	73	1175	3	24	4	16	0	2	16	0	0	5.8593942945992605	
i 1	773.2582925170068	0.2525	69	206	3	4	15	1	0	-1	1	0	0	3.0	
i 1	773.2655034013605	1.01	73	1175	1	20	11	16	0	1	16	0	0	1.8593942945992605	
i 1	773.4938707482993	0.7575000000000001	72	593	4	24	10	2	0	1	2	0	0	7.0	
i 1	773.5032448979592	0.7575000000000001	69	1175	5	9	16	1	0	-1	1	0	0	2.0	
i 1	773.5039659863945	0.7575000000000001	72	593	4	4	3	1	0	-1	1	0	0	3.0	
i 1	773.7381020408163	1.01	72	593	5	3	8	0	0	0	0	0	0	3.0	
i 1	773.7388231292517	1.2625	69	206	3	4	16	1	0	-1	1	0	0	3.0	
i 1	773.9866598639455	0.2525	72	206	3	5	8	0	0	-1	0	0	0	2.0	
i 1	774.2352176870749	0.2525	75	1175	6	1	11	2	0	-2	2	0	0	6.0	
i 1	774.2352176870749	1.5150000000000001	72	1175	5	9	10	1	0	-1	1	0	0	2.0	
i 1	774.2395442176871	0.2525	73	909	1	20	3	16	0	1	16	0	0	1.8593942945992605	
i 1	774.2409863945578	1.5150000000000001	69	909	5	2	10	1	0	0	1	0	0	3.0	
i 1	774.2417074829932	2.2725	69	206	3	5	6	0	0	-1	0	0	0	2.0	
i 1	774.2532448979592	2.2725	69	909	4	5	15	1	0	-1	1	0	0	2.0	
i 1	774.2554081632653	0.2525	76	909	1	20	13	16	0	1	16	0	0	1.8593942945992605	
i 1	774.4823333333334	0.505	76	1175	1	20	7	17	0	2	17	0	0	1.8593942945992605	
i 1	774.483775510204	0.505	72	1175	6	1	12	8	0	-2	8	0	0	6.0	
i 1	774.5082925170068	0.505	73	1175	1	20	9	16	0	1	16	0	0	1.8593942945992605	
i 1	774.9881020408163	0.2525	73	909	1	20	4	16	0	1	16	0	0	1.8593942945992605	
i 1	775.0046870748299	0.2525	73	909	1	20	9	16	0	1	16	0	0	1.8593942945992605	
i 1	775.0054081632653	0.2525	72	593	4	5	9	0	0	-1	0	0	0	2.0	
i 1	775.0111768707483	0.2525	72	206	5	24	14	2	0	-2	2	0	0	7.0	
i 1	775.0155034013605	0.2525	69	909	6	2	2	0	0	-1	0	0	0	3.0	
i 1	775.233775510204	0.2525	73	1175	1	20	13	16	0	2	16	0	0	1.8593942945992605	
i 1	775.2388231292517	0.2525	75	909	5	1	9	2	0	1	2	0	0	6.0	
i 1	775.2561292517007	2.525	73	1175	1	20	1	17	0	2	17	0	0	1.8593942945992605	
i 1	775.2582925170068	1.01	72	593	5	3	5	0	0	0	0	0	0	3.0	
i 1	775.2669455782313	1.01	69	206	3	4	3	1	0	-1	1	0	0	3.0	
i 1	775.2676666666666	0.505	69	1175	5	5	4	1	0	-1	1	0	0	2.0	
i 1	775.4924285714286	0.7575000000000001	72	593	5	1	14	8	0	-2	8	0	0	6.0	
i 1	775.5046870748299	0.7575000000000001	72	206	5	24	5	2	0	-2	2	0	0	7.0	
i 1	775.7395442176871	2.02	73	1175	1	20	3	16	0	2	16	0	0	1.8593942945992605	
i 1	775.7417074829932	0.2525	72	593	4	4	16	1	0	-1	1	0	0	3.0	
i 1	775.7626190476191	2.02	72	206	3	5	6	0	0	-1	0	0	0	2.0	
i 1	775.9852176870749	0.2525	69	909	5	2	13	1	0	0	1	0	0	3.0	
i 1	775.9888231292517	1.7675	69	593	4	5	4	1	0	-1	1	0	0	2.0	
i 1	776.2330544217687	1.5150000000000001	72	593	5	1	5	8	0	-2	8	0	0	2.0	
i 1	776.2330544217687	1.5150000000000001	61	593	5	15	1	6	0	1	6	0	0	2.7834134008011198	
i 1	776.2359387755102	1.5150000000000001	61	909	5	14	11	9	0	1	9	0	0	9.87391727338392	
i 1	776.2395442176871	1.2625	69	909	5	2	12	0	0	-1	0	0	0	3.6280606234043393	
i 1	776.2402653061224	1.5150000000000001	66	1175	4	16	11	6	0	0	6	0	0	3.247315634267973	
i 1	776.2417074829932	1.5150000000000001	61	206	1	27	13	9	0	252	9	307	0	5.381975256673252	
i 1	776.2438707482993	1.5150000000000001	66	206	4	12	3	6	0	0	6	0	0	3.247315634267973	
i 1	776.2460340136055	1.5150000000000001	66	593	6	7	11	6	0	0	6	0	0	8.463357662900505	
i 1	776.2474761904762	1.5150000000000001	66	909	5	14	16	6	0	1	6	0	0	3.711217867734826	
i 1	776.2481972789116	1.5150000000000001	66	593	5	15	10	9	0	0	9	0	0	2.7834134008011198	
i 1	776.2481972789116	0.505	69	206	3	4	2	1	0	-1	1	0	0	3.6280606234043393	
i 1	776.2503605442176	1.5150000000000001	66	206	4	12	10	6	0	0	6	0	0	3.247315634267973	
i 1	776.2539659863945	1.5150000000000001	61	1175	4	16	10	6	0	1	6	0	0	3.247315634267973	
i 1	776.2539659863945	1.5150000000000001	76	1175	3	20	5	17	0	1	17	0	0	1.8593942945992605	
i 1	776.2546870748299	0.2525	75	909	4	1	13	2	0	1	2	0	0	2.0	
i 1	776.2546870748299	1.2625	69	206	3	3	5	1	0	-1	1	0	0	3.6280606234043393	
i 1	776.2546870748299	1.5150000000000001	61	206	1	27	10	6	0	252	6	307	0	5.381975256673252	
i 1	776.2575714285714	1.5150000000000001	72	206	5	24	10	2	0	-2	2	0	0	3.0	
i 1	776.2575714285714	0.505	72	593	5	3	16	0	0	0	0	0	0	3.6280606234043393	
i 1	776.2640612244898	1.5150000000000001	66	909	5	13	15	9	0	0	9	0	0	2.3195111673342663	
i 1	776.2647823129251	1.5150000000000001	61	909	5	14	9	9	0	0	9	0	0	9.87391727338392	
i 1	776.2647823129251	1.5150000000000001	66	593	5	13	10	9	0	0	9	0	0	5.642238441933669	
i 1	776.5018027210884	0.2525	72	1175	4	5	12	1	0	0	1	0	0	2.0	
i 1	776.5104557823129	1.01	72	593	4	24	11	2	0	1	2	0	0	3.0	
i 1	776.5176666666666	1.01	72	1175	6	1	15	8	0	-2	8	0	0	2.0	
i 1	776.7467551020408	1.01	69	1175	5	9	16	1	0	-1	1	0	0	2.6280606234043393	
i 1	776.748918367347	0.505	69	909	6	5	12	1	0	-1	1	0	0	2.0	
i 1	776.9917074829932	0.7575000000000001	72	593	4	4	10	1	0	-1	1	0	0	3.6280606234043393	
i 1	777.2445918367347	0.505	72	593	4	5	8	0	0	-1	0	0	0	2.0	
i 1	777.2496394557824	0.505	73	1175	1	24	11	16	0	2	16	0	0	5.8593942945992605	
i 1	777.2503605442176	0.505	72	1175	5	9	2	1	0	-1	1	0	0	2.6280606234043393	
i 1	777.2590136054422	0.505	69	909	5	2	7	1	0	0	1	0	0	3.6280606234043393	
i 1	777.4938707482993	0.2525	69	206	3	4	1	1	0	-1	1	0	0	3.6280606234043393	
i 1	777.5090136054422	0.2525	75	206	6	1	8	2	0	-2	2	0	0	2.0	
i 1	777.7330544217687	0.2525	69	699	5	2	9	1	0	0	1	0	0	3.6280606234043393	
i 1	777.7344965986395	0.2525	72	201	4	5	11	0	0	0	0	0	0	2.0	
i 1	777.7359387755102	1.01	72	699	6	1	7	8	0	1	8	0	0	2.0	
i 1	777.7366598639455	60.8525	61	699	1	27	2	9	0	248	9	308	0	5.381975256673252	
i 1	777.7395442176871	33.33	61	1085	4	16	1	6	0	1	6	0	0	3.247315634267973	
i 1	777.7417074829932	27.5225	61	1085	4	16	15	6	0	0	6	0	0	3.247315634267973	
i 1	777.743149659864	0.2525	72	1085	5	9	9	0	0	-1	0	0	0	2.6280606234043393	
i 1	777.743149659864	33.33	61	699	5	14	6	9	0	1	9	0	0	9.87391727338392	
i 1	777.7453129251701	21.715	66	201	6	15	5	9	0	1	9	0	0	2.7834134008011198	
i 1	777.7467551020408	0.2525	72	699	4	24	15	8	0	-2	8	0	0	3.0	
i 1	777.7467551020408	60.8525	66	699	1	27	13	9	0	252	9	307	0	5.381975256673252	
i 1	777.7481972789116	1.01	72	201	5	4	16	0	0	0	0	0	0	3.6280606234043393	
i 1	777.7481972789116	1.5150000000000001	72	201	4	5	11	1	0	-1	1	0	0	2.0	
i 1	777.748918367347	1.7675	76	1085	2	20	15	17	0	1	17	0	0	1.8593942945992605	
i 1	777.7503605442176	39.1375	66	699	4	12	3	9	0	1	9	0	0	3.247315634267973	
i 1	777.751081632653	15.9075	61	201	6	15	5	6	0	0	6	0	0	2.7834134008011198	
i 1	777.751081632653	0.7575000000000001	69	699	3	4	2	1	0	0	1	0	0	3.6280606234043393	
i 1	777.7539659863945	1.01	75	201	5	1	14	2	0	-2	2	0	0	2.0	
i 1	777.7539659863945	27.5225	61	699	5	14	1	6	0	1	6	0	0	9.87391727338392	
i 1	777.7554081632653	4.2925	66	699	5	14	7	6	0	1	6	0	0	3.711217867734826	
i 1	777.7561292517007	4.2925	66	201	6	13	10	6	0	1	6	0	0	5.642238441933669	
i 1	777.7590136054422	1.5150000000000001	72	699	3	5	9	1	0	-1	1	0	0	2.0	
i 1	777.7604557823129	10.1	61	201	6	7	11	6	0	0	6	0	0	8.463357662900505	
i 1	777.7611768707483	10.1	66	699	5	13	7	6	0	1	6	0	0	2.3195111673342663	
i 1	777.7676666666666	44.945	61	699	4	12	9	6	0	0	6	0	0	3.247315634267973	
i 1	777.9866598639455	1.5150000000000001	69	201	6	3	4	1	0	-1	1	0	0	3.6280606234043393	
i 1	777.9967551020408	3.535	72	1085	6	1	12	2	0	-2	2	0	0	2.0	
i 1	778.0075714285714	0.505	69	699	3	5	2	0	0	-1	0	0	0	2.0	
i 1	778.0155034013605	1.5150000000000001	72	699	3	3	3	1	0	0	1	0	0	3.6280606234043393	
i 1	778.233775510204	3.2825	75	699	5	1	10	2	0	1	2	0	0	2.0	
i 1	778.2352176870749	0.2525	73	699	1	20	10	16	0	1	16	0	0	1.8593942945992605	
i 1	778.2633401360545	0.2525	76	201	1	24	15	17	0	2	17	0	0	5.8593942945992605	
i 1	778.5140612244898	0.2525	69	1085	3	5	6	0	0	-1	0	0	0	2.0	
i 1	778.7323333333334	0.2525	75	1085	6	1	16	8	0	-2	8	0	0	2.0	
i 1	778.7352176870749	0.505	76	201	1	24	15	17	0	2	17	0	0	5.8593942945992605	
i 1	778.7359387755102	2.02	69	699	5	2	11	1	0	0	1	0	0	3.6280606234043393	
i 1	778.7445918367347	1.7675	72	201	4	5	14	0	0	0	0	0	0	2.0	
i 1	778.7554081632653	0.505	76	699	1	20	6	16	0	2	16	0	0	1.8593942945992605	
i 1	778.7633401360545	1.7675	69	699	3	5	5	0	0	-1	0	0	0	2.0	
i 1	778.9909863945578	0.2525	72	699	4	1	11	2	0	1	2	0	0	2.0	
i 1	779.0003605442176	1.5150000000000001	69	1085	5	9	1	1	0	-1	1	0	0	2.6280606234043393	
i 1	779.243149659864	0.2525	72	699	6	5	14	1	0	-1	1	0	0	2.0	
i 1	779.2496394557824	0.2525	72	699	4	24	10	8	0	-2	8	0	0	3.0	
i 1	779.483775510204	0.2525	69	1085	6	5	11	0	0	-1	0	0	0	2.0	
i 1	779.4844965986395	0.2525	69	699	3	4	6	1	0	0	1	0	0	3.6280606234043393	
i 1	779.4859387755102	0.7575000000000001	72	201	5	24	8	2	0	-2	2	0	0	3.0	
i 1	779.7467551020408	0.2525	72	201	4	5	10	1	0	-1	1	0	0	2.0	
i 1	779.7604557823129	0.2525	72	1085	5	9	5	0	0	-1	0	0	0	2.6280606234043393	
i 1	779.9823333333334	1.7675	69	1085	3	5	16	0	0	-1	0	0	0	2.0	
i 1	779.9953129251701	1.7675	72	699	6	5	16	1	0	-1	1	0	0	2.0	
i 1	780.0104557823129	1.2625	72	699	3	3	16	1	0	0	1	0	0	3.6280606234043393	
i 1	780.0140612244898	1.2625	69	201	6	3	10	1	0	-1	1	0	0	3.6280606234043393	
i 1	780.2575714285714	0.2525	72	699	4	1	6	2	0	1	2	0	0	2.0	
i 1	780.4852176870749	0.505	72	699	3	5	5	1	0	-1	1	0	0	2.0	
i 1	780.4852176870749	1.5150000000000001	76	1085	2	20	5	17	0	1	17	0	0	1.8593942945992605	
i 1	780.5118979591837	0.2525	75	201	5	1	2	2	0	-2	2	0	0	2.0	
i 1	780.7417074829932	0.2525	72	201	5	24	16	2	0	-2	2	0	0	3.0	
i 1	780.7424285714286	0.2525	76	201	1	24	1	17	0	2	17	0	0	5.8593942945992605	
i 1	780.7445918367347	0.7575000000000001	69	699	5	2	10	1	0	-1	1	0	0	3.6280606234043393	
i 1	780.748918367347	0.2525	73	699	1	20	12	16	0	1	16	0	0	1.8593942945992605	
i 1	780.7525238095238	0.7575000000000001	72	1085	5	9	9	0	0	-1	0	0	0	2.6280606234043393	
i 1	780.9823333333334	1.01	69	699	3	4	1	1	0	0	1	0	0	3.6280606234043393	
i 1	780.9917074829932	1.01	75	201	5	1	7	2	0	-2	2	0	0	2.0	
i 1	781.0046870748299	1.2625	72	699	6	1	4	8	0	1	8	0	0	2.0	
i 1	781.0082925170068	0.2525	72	201	4	5	12	0	0	0	0	0	0	2.0	
i 1	781.016224489796	0.7575000000000001	72	201	5	4	1	0	0	0	0	0	0	3.6280606234043393	
i 1	781.248918367347	0.7575000000000001	69	699	4	5	14	0	0	0	0	0	0	2.0	
i 1	781.2554081632653	2.02	69	1085	5	9	6	1	0	-1	1	0	0	2.6280606234043393	
i 1	781.2561292517007	0.7575000000000001	69	1085	6	5	7	0	0	-1	0	0	0	2.0	
i 1	781.2597346938776	0.7575000000000001	69	699	5	2	5	1	0	0	1	0	0	3.6280606234043393	
i 1	781.4852176870749	0.2525	73	201	1	24	8	17	0	1	17	0	0	5.8593942945992605	
i 1	781.5118979591837	2.02	72	201	5	24	10	2	0	-2	2	0	0	3.0	
i 1	781.5118979591837	0.2525	76	699	1	20	7	16	0	2	16	0	0	1.8593942945992605	
i 1	781.5118979591837	0.2525	76	201	1	20	4	17	0	2	17	0	0	1.8593942945992605	
i 1	781.5133401360545	2.2725	72	699	4	24	4	8	0	-2	8	0	0	3.0	
i 1	781.7445918367347	0.2525	72	201	4	5	3	0	0	0	0	0	0	2.0	
i 1	781.9844965986395	2.7775	69	1085	3	5	10	0	0	-1	0	0	0	2.0	
i 1	781.9873809523809	0.2525	72	699	6	5	6	1	0	-1	1	0	0	2.0	
i 1	781.9945918367347	1.5150000000000001	69	699	6	2	5	1	0	0	1	0	0	3.6280606234043393	
i 1	781.9996394557824	17.4225	66	699	5	14	14	6	0	1	6	0	0	3.711217867734826	
i 1	781.9996394557824	0.2525	69	201	5	3	13	1	0	-1	1	0	0	3.6280606234043393	
i 1	782.0025238095238	4.545	76	699	1	24	1	16	0	1	16	0	0	5.8593942945992605	
i 1	782.0111768707483	3.0300000000000002	69	699	6	5	2	0	0	0	0	0	0	2.0	
i 1	782.0133401360545	34.845	66	201	6	13	8	6	0	1	6	0	0	5.642238441933669	
i 1	782.2381020408163	0.2525	72	201	4	5	1	1	0	-1	1	0	0	2.0	
i 1	782.2561292517007	0.2525	72	201	5	4	6	0	0	0	0	0	0	3.6280606234043393	
i 1	782.266224489796	0.2525	75	1085	4	1	10	8	0	-2	8	0	0	2.0	
i 1	782.4881020408163	0.505	72	699	6	5	9	1	0	-1	1	0	0	2.0	
i 1	782.4909863945578	0.2525	72	699	4	1	12	2	0	1	2	0	0	2.0	
i 1	782.4974761904762	1.7675	69	699	3	4	5	1	0	0	1	0	0	3.6280606234043393	
i 1	782.7381020408163	0.2525	75	699	4	1	4	2	0	1	2	0	0	2.0	
i 1	782.7633401360545	1.5150000000000001	72	201	5	4	9	0	0	0	0	0	0	3.6280606234043393	
i 1	782.9996394557824	0.2525	69	699	6	5	9	0	0	-1	0	0	0	2.0	
i 1	783.0140612244898	1.2625	75	201	5	1	9	2	0	-2	2	0	0	2.0	
i 1	783.0147823129251	1.2625	72	699	6	1	5	8	0	1	8	0	0	2.0	
i 1	783.2373809523809	0.2525	72	699	3	5	7	1	0	-1	1	0	0	2.0	
i 1	783.4960340136055	0.2525	69	1085	5	9	10	1	0	-1	1	0	0	2.6280606234043393	
i 1	783.5090136054422	0.2525	73	201	1	20	12	16	0	2	16	0	0	1.8593942945992605	
i 1	783.5126190476191	0.2525	76	699	1	20	8	17	0	1	17	0	0	1.8593942945992605	
i 1	783.7344965986395	1.7675	69	201	5	3	11	1	0	-1	1	0	0	3.6280606234043393	
i 1	783.7366598639455	1.7675	72	699	4	3	4	1	0	0	1	0	0	3.6280606234043393	
i 1	783.7676666666666	1.7675	72	699	4	1	5	2	0	1	2	0	0	2.0	
i 1	783.7676666666666	1.7675	75	1085	4	1	7	8	0	-2	8	0	0	2.0	
i 1	783.9981972789116	0.2525	73	699	1	20	8	16	0	1	16	0	0	1.8593942945992605	
i 1	784.0025238095238	0.2525	73	699	1	20	13	16	0	1	16	0	0	1.8593942945992605	
i 1	784.0046870748299	0.2525	73	201	1	20	8	16	0	2	16	0	0	1.8593942945992605	
i 1	784.0147823129251	0.2525	69	1085	3	5	9	0	0	-1	0	0	0	2.0	
i 1	784.248918367347	1.01	69	699	6	2	10	1	0	0	1	0	0	3.6280606234043393	
i 1	784.2546870748299	0.2525	72	699	4	24	4	8	0	-2	8	0	0	3.0	
i 1	784.256850340136	1.7675	72	201	4	5	10	0	0	0	0	0	0	2.0	
i 1	784.2633401360545	1.7675	69	699	6	5	3	0	0	-1	0	0	0	2.0	
i 1	784.501081632653	0.2525	72	1085	6	1	1	2	0	-2	2	0	0	2.0	
i 1	784.516224489796	0.7575000000000001	69	1085	5	9	9	1	0	-1	1	0	0	2.6280606234043393	
i 1	784.7575714285714	1.2625	75	201	5	1	7	2	0	-2	2	0	0	2.0	
i 1	784.983775510204	1.01	69	699	5	2	2	1	0	-1	1	0	0	3.6280606234043393	
i 1	785.0082925170068	0.2525	72	699	6	5	12	1	0	-1	1	0	0	2.0	
i 1	785.0126190476191	1.01	72	699	6	1	12	8	0	1	8	0	0	2.0	
i 1	785.0176666666666	1.01	72	1085	5	9	16	0	0	-1	0	0	0	2.6280606234043393	
i 1	785.2381020408163	2.525	72	699	3	5	4	1	0	-1	1	0	0	2.0	
i 1	785.4873809523809	2.2725	72	1085	6	1	5	2	0	-2	2	0	0	2.0	
i 1	785.4909863945578	2.7775	72	201	4	5	9	1	0	-1	1	0	0	2.0	
i 1	785.4974761904762	1.7675	72	201	5	4	14	0	0	0	0	0	0	3.6280606234043393	
i 1	785.5075714285714	1.5150000000000001	69	699	3	4	14	1	0	0	1	0	0	3.6280606234043393	
i 1	785.5104557823129	3.535	75	699	4	1	10	2	0	1	2	0	0	2.0	
i 1	786.0090136054422	0.505	72	699	6	5	14	1	0	-1	1	0	0	2.0	
i 1	786.0111768707483	0.2525	72	699	4	3	15	1	0	0	1	0	0	3.6280606234043393	
i 1	786.0155034013605	0.2525	72	201	5	24	3	2	0	-2	2	0	0	3.0	
i 1	786.2424285714286	0.2525	72	699	4	1	6	2	0	1	2	0	0	2.0	
i 1	786.2546870748299	0.2525	72	1085	5	9	11	0	0	-1	0	0	0	2.6280606234043393	
i 1	786.4960340136055	0.2525	69	1085	3	5	6	0	0	-1	0	0	0	2.0	
i 1	786.5097346938776	3.2825	69	699	6	2	4	1	0	0	1	0	0	3.6280606234043393	
i 1	786.5155034013605	3.2825	69	1085	5	9	5	1	0	-1	1	0	0	2.6280606234043393	
i 1	786.7618979591837	1.01	76	699	1	24	16	16	0	1	16	0	0	5.8593942945992605	
i 1	786.7647823129251	0.2525	72	201	4	5	15	0	0	0	0	0	0	2.0	
i 1	786.9888231292517	0.2525	76	699	1	20	4	16	0	1	16	0	0	1.8593942945992605	
i 1	786.993149659864	0.2525	76	699	1	20	16	17	0	1	17	0	0	1.8593942945992605	
i 1	786.9945918367347	0.2525	76	201	1	24	7	16	0	2	16	0	0	5.8593942945992605	
i 1	787.006850340136	0.2525	72	699	6	5	10	1	0	-1	1	0	0	2.0	
i 1	787.0155034013605	0.2525	73	201	1	20	13	16	0	2	16	0	0	1.8593942945992605	
i 1	787.2381020408163	0.2525	69	201	5	3	1	1	0	-1	1	0	0	3.6280606234043393	
i 1	787.2424285714286	0.505	69	699	6	5	14	0	0	-1	0	0	0	2.0	
i 1	787.4866598639455	0.2525	69	699	5	2	3	1	0	-1	1	0	0	3.6280606234043393	
i 1	787.7373809523809	0.7575000000000001	72	201	7	5	14	0	0	0	0	0	0	2.0	
i 1	787.7460340136055	1.2625	72	1085	4	1	7	2	0	-2	2	0	0	2.0	
i 1	787.7474761904762	0.7575000000000001	69	699	2	5	4	0	0	-1	0	0	0	2.0	
i 1	787.7518027210884	0.2525	76	201	1	24	16	16	0	1	16	0	0	5.8593942945992605	
i 1	787.7546870748299	0.2525	73	201	1	20	7	17	0	1	17	0	0	1.8593942945992605	
i 1	787.7575714285714	17.4225	66	699	5	13	7	6	0	1	6	0	0	2.3195111673342663	
i 1	787.7597346938776	0.505	72	699	6	5	9	1	0	-1	1	0	0	2.0	
i 1	787.7604557823129	0.2525	76	699	1	20	16	17	0	1	17	0	0	1.8593942945992605	
i 1	787.7604557823129	1.7675	73	699	1	20	11	17	0	2	17	0	0	1.8593942945992605	
i 1	787.7618979591837	0.2525	69	201	5	3	11	1	0	-1	1	0	0	3.6280606234043393	
i 1	787.7626190476191	0.2525	73	699	1	20	1	16	0	2	16	0	0	1.8593942945992605	
i 1	787.766224489796	34.845	61	201	7	7	2	6	0	0	6	0	0	8.463357662900505	
i 1	787.9881020408163	1.01	72	201	5	4	8	0	0	0	0	0	0	3.6280606234043393	
i 1	787.9960340136055	3.535	69	1085	3	5	1	0	0	-1	0	0	0	2.0	
i 1	788.0169455782313	3.7875	72	699	6	5	4	1	0	-1	1	0	0	2.0	
i 1	788.2402653061224	0.7575000000000001	69	699	4	4	9	1	0	0	1	0	0	3.6280606234043393	
i 1	788.2438707482993	0.2525	72	699	4	24	9	8	0	-2	8	0	0	3.0	
i 1	788.4873809523809	1.5150000000000001	75	201	4	1	5	2	0	-2	2	0	0	2.0	
i 1	788.5003605442176	1.2625	72	699	6	1	10	8	0	1	8	0	0	2.0	
i 1	788.5032448979592	2.2725	72	699	4	3	13	1	0	0	1	0	0	3.6280606234043393	
i 1	788.5039659863945	2.2725	69	201	5	3	2	1	0	-1	1	0	0	3.6280606234043393	
i 1	788.5039659863945	0.2525	69	1085	3	5	2	0	0	-1	0	0	0	2.0	
i 1	788.7359387755102	0.2525	69	699	2	5	12	0	0	-1	0	0	0	2.0	
i 1	789.0003605442176	2.02	72	699	4	24	16	8	0	-2	8	0	0	3.0	
i 1	789.2366598639455	1.7675	72	201	5	24	4	2	0	-2	2	0	0	3.0	
i 1	789.2496394557824	0.505	73	699	1	20	2	16	0	1	16	0	0	1.8593942945992605	
i 1	789.2539659863945	0.505	73	699	1	20	13	17	0	1	17	0	0	1.8593942945992605	
i 1	789.256850340136	0.2525	73	201	1	24	9	17	0	1	17	0	0	5.8593942945992605	
i 1	789.4981972789116	0.2525	69	699	2	5	4	0	0	-1	0	0	0	2.0	
i 1	789.5169455782313	0.2525	73	201	1	20	7	16	0	1	16	0	0	1.8593942945992605	
i 1	789.7575714285714	0.505	69	699	6	5	3	0	0	0	0	0	0	2.0	
i 1	789.7633401360545	0.2525	69	699	6	2	12	1	0	-1	1	0	0	3.6280606234043393	
i 1	789.983775510204	0.505	72	699	4	1	6	2	0	1	2	0	0	2.0	
i 1	789.9953129251701	0.2525	69	1085	5	9	10	1	0	-1	1	0	0	2.6280606234043393	
i 1	790.2352176870749	1.5150000000000001	69	699	6	2	11	1	0	-1	1	0	0	3.6280606234043393	
i 1	790.2532448979592	1.5150000000000001	72	1085	5	9	2	0	0	-1	0	0	0	2.6280606234043393	
i 1	790.2575714285714	0.2525	72	201	4	5	1	1	0	-1	1	0	0	2.0	
i 1	790.4945918367347	1.01	75	201	4	1	11	2	0	-2	2	0	0	2.0	
i 1	790.4945918367347	0.2525	69	699	2	5	9	0	0	-1	0	0	0	2.0	
i 1	790.5097346938776	1.01	72	699	6	1	14	8	0	1	8	0	0	2.0	
i 1	790.7388231292517	0.2525	72	201	5	4	16	0	0	0	0	0	0	3.6280606234043393	
i 1	790.7532448979592	3.2825	69	1085	3	5	13	0	0	-1	0	0	0	2.0	
i 1	790.9823333333334	1.5150000000000001	72	699	4	1	11	2	0	1	2	0	0	2.0	
i 1	790.9953129251701	1.5150000000000001	75	1085	4	1	9	8	0	-2	8	0	0	2.0	
i 1	791.0061292517007	0.2525	69	699	6	2	13	1	0	0	1	0	0	3.6280606234043393	
i 1	791.0090136054422	2.525	73	699	1	20	5	17	0	2	17	0	0	1.8593942945992605	
i 1	791.0155034013605	3.535	69	699	6	5	9	0	0	0	0	0	0	2.0	
i 1	791.2402653061224	2.2725	69	699	4	4	4	1	0	0	1	0	0	3.6280606234043393	
i 1	791.2575714285714	2.525	72	201	5	4	11	0	0	0	0	0	0	3.6280606234043393	
i 1	791.5090136054422	0.2525	72	1085	4	1	7	2	0	-2	2	0	0	2.0	
i 1	791.7395442176871	1.2625	75	201	4	1	8	2	0	-2	2	0	0	2.0	
i 1	791.7582925170068	0.2525	69	201	5	3	4	1	0	-1	1	0	0	3.6280606234043393	
i 1	791.7618979591837	0.2525	69	1085	3	5	13	0	0	-1	0	0	0	2.0	
i 1	791.998918367347	0.2525	69	699	2	5	11	0	0	-1	0	0	0	2.0	
i 1	792.0025238095238	1.01	69	699	6	2	13	1	0	0	1	0	0	3.6280606234043393	
i 1	792.0155034013605	1.01	72	699	6	1	1	8	0	1	8	0	0	2.0	
i 1	792.0169455782313	1.01	69	1085	5	9	15	1	0	-1	1	0	0	2.6280606234043393	
i 1	792.4852176870749	4.04	75	699	4	1	4	2	0	1	2	0	0	2.0	
i 1	792.5018027210884	4.04	72	1085	4	1	3	2	0	-2	2	0	0	2.0	
i 1	793.0118979591837	0.2525	72	201	5	24	12	2	0	-2	2	0	0	3.0	
i 1	793.0118979591837	0.2525	72	699	6	5	14	1	0	-1	1	0	0	2.0	
i 1	793.0140612244898	1.7675	72	699	4	3	6	1	0	0	1	0	0	3.6280606234043393	
i 1	793.0155034013605	0.505	69	201	5	3	14	1	0	-1	1	0	0	3.6280606234043393	
i 1	793.2409863945578	0.2525	75	201	4	1	1	2	0	-2	2	0	0	2.0	
i 1	793.2409863945578	0.2525	76	699	1	20	16	16	0	1	16	0	0	1.8593942945992605	
i 1	793.2575714285714	0.2525	73	699	1	20	1	17	0	2	17	0	0	1.8593942945992605	
i 1	793.2604557823129	0.2525	73	201	1	24	13	16	0	1	16	0	0	5.8593942945992605	
i 1	793.2655034013605	2.02	69	699	2	5	10	0	0	-1	0	0	0	2.0	
i 1	793.4974761904762	1.01	69	201	6	3	5	1	0	-1	1	0	0	3.6280606234043393	
i 1	793.5104557823129	0.2525	75	1085	4	1	15	8	0	-2	8	0	0	2.0	
i 1	793.5111768707483	1.5150000000000001	72	201	7	5	9	0	0	0	0	0	0	2.0	
i 1	793.5133401360545	17.4225	61	201	6	15	14	6	0	0	6	0	0	2.7834134008011198	
i 1	793.7481972789116	0.2525	69	699	4	4	4	1	0	0	1	0	0	3.6280606234043393	
i 1	793.7496394557824	0.7575000000000001	72	699	4	24	9	8	0	-2	8	0	0	3.0	
i 1	794.0111768707483	1.5150000000000001	69	1085	4	9	15	1	0	-1	1	0	0	2.6280606234043393	
i 1	794.0140612244898	1.5150000000000001	69	699	6	2	14	1	0	0	1	0	0	3.6280606234043393	
i 1	794.4895442176871	2.2725	72	699	3	5	16	1	0	-1	1	0	0	2.0	
i 1	794.4945918367347	2.2725	72	201	7	5	9	1	0	-1	1	0	0	2.0	
i 1	794.5003605442176	0.2525	72	699	3	1	12	8	0	1	8	0	0	2.0	
i 1	794.7518027210884	0.2525	72	699	4	1	5	2	0	1	2	0	0	2.0	
i 1	794.7655034013605	0.2525	72	1085	5	9	1	0	0	-1	0	0	0	2.6280606234043393	
i 1	794.993149659864	1.2625	72	699	4	3	16	1	0	0	1	0	0	3.6280606234043393	
i 1	795.0018027210884	1.2625	69	201	6	3	14	1	0	-1	1	0	0	3.6280606234043393	
i 1	795.2604557823129	0.2525	75	201	4	1	16	2	0	-2	2	0	0	2.0	
i 1	795.2626190476191	0.2525	69	1085	3	5	8	0	0	-1	0	0	0	2.0	
i 1	795.493149659864	0.2525	72	699	4	5	4	1	0	-1	1	0	0	2.0	
i 1	795.4996394557824	0.505	72	201	4	24	11	2	0	-2	2	0	0	3.0	
i 1	795.5061292517007	0.2525	69	699	4	4	8	1	0	0	1	0	0	3.6280606234043393	
i 1	795.7618979591837	0.7575000000000001	72	1085	5	9	1	0	0	-1	0	0	0	2.6280606234043393	
i 1	795.766224489796	0.7575000000000001	69	699	6	2	14	1	0	-1	1	0	0	3.6280606234043393	
i 1	795.9852176870749	1.01	72	699	3	1	7	8	0	1	8	0	0	2.0	
i 1	795.9981972789116	1.01	75	201	4	1	7	2	0	-2	2	0	0	2.0	
i 1	796.0032448979592	0.7575000000000001	72	201	5	4	12	0	0	0	0	0	0	3.6280606234043393	
i 1	796.0054081632653	0.2525	69	1085	3	5	1	0	0	-1	0	0	0	2.0	
i 1	796.0126190476191	0.7575000000000001	69	699	4	4	14	1	0	0	1	0	0	3.6280606234043393	
i 1	796.2323333333334	2.02	69	699	2	5	14	0	0	-1	0	0	0	2.0	
i 1	796.2381020408163	0.2525	76	201	1	24	4	16	0	1	16	0	0	5.8593942945992605	
i 1	796.2424285714286	2.02	69	699	6	2	16	1	0	0	1	0	0	3.6280606234043393	
i 1	796.2474761904762	2.02	69	1085	4	9	5	1	0	-1	1	0	0	2.6280606234043393	
i 1	796.2481972789116	0.2525	76	699	1	20	11	16	0	1	16	0	0	1.8593942945992605	
i 1	796.2640612244898	2.2725	72	201	7	5	6	0	0	0	0	0	0	2.0	
i 1	796.2669455782313	0.2525	76	699	1	20	5	16	0	2	16	0	0	1.8593942945992605	
i 1	796.5090136054422	1.5150000000000001	72	201	4	24	14	2	0	-2	2	0	0	3.0	
i 1	796.5090136054422	1.5150000000000001	72	699	4	24	14	8	0	-2	8	0	0	3.0	
i 1	796.7460340136055	0.505	72	1085	5	9	4	0	0	-1	0	0	0	2.6280606234043393	
i 1	796.748918367347	0.2525	69	699	6	5	2	0	0	0	0	0	0	2.0	
i 1	796.9830544217687	0.2525	75	699	4	1	16	2	0	1	2	0	0	2.0	
i 1	796.9953129251701	0.2525	72	699	3	5	1	1	0	-1	1	0	0	2.0	
i 1	797.2366598639455	0.505	72	699	4	3	7	1	0	0	1	0	0	3.6280606234043393	
i 1	797.2546870748299	0.2525	75	1085	4	1	2	8	0	-2	8	0	0	2.0	
i 1	797.4924285714286	1.01	72	699	3	1	5	8	0	1	8	0	0	2.0	
i 1	797.5003605442176	0.2525	69	699	6	5	15	0	0	0	0	0	0	2.0	
i 1	797.5082925170068	1.01	75	201	4	1	5	2	0	-2	2	0	0	2.0	
i 1	797.7359387755102	1.5150000000000001	69	699	4	4	9	1	0	0	1	0	0	3.6280606234043393	
i 1	797.748918367347	1.5150000000000001	69	1085	3	5	5	0	0	-1	0	0	0	2.0	
i 1	797.7539659863945	1.5150000000000001	72	201	5	4	14	0	0	0	0	0	0	3.6280606234043393	
i 1	797.7618979591837	3.0300000000000002	72	699	4	5	8	1	0	-1	1	0	0	2.0	
i 1	798.0046870748299	2.02	72	699	4	1	5	2	0	1	2	0	0	2.0	
i 1	798.0090136054422	1.2625	75	1085	4	1	16	8	0	-2	8	0	0	2.0	
i 1	798.2496394557824	0.2525	69	201	6	3	9	1	0	-1	1	0	0	3.6280606234043393	
i 1	798.4895442176871	2.02	72	699	4	3	6	1	0	0	1	0	0	3.6280606234043393	
i 1	798.498918367347	0.2525	75	699	4	1	15	2	0	1	2	0	0	2.0	
i 1	798.5097346938776	0.505	72	201	7	5	5	1	0	-1	1	0	0	2.0	
i 1	798.7366598639455	0.2525	75	201	4	1	8	2	0	-2	2	0	0	2.0	
i 1	798.7460340136055	1.7675	69	201	6	3	11	1	0	-1	1	0	0	3.6280606234043393	
i 1	798.9924285714286	0.2525	69	699	2	5	9	0	0	-1	0	0	0	2.0	
i 1	798.9960340136055	0.505	75	699	4	1	8	2	0	1	2	0	0	2.0	
i 1	799.233775510204	1.5150000000000001	69	1085	6	5	11	0	0	-1	0	0	0	2.0	
i 1	799.2344965986395	17.4225	66	201	6	15	10	9	0	1	9	0	0	2.7834134008011198	
i 1	799.2402653061224	0.505	76	699	1	20	1	17	0	1	17	0	0	3.0500158916876474	
i 1	799.2539659863945	0.2525	72	1085	4	9	12	0	0	-1	0	0	0	2.6280606234043393	
i 1	799.2554081632653	0.505	73	201	1	24	3	17	0	1	17	0	0	7.050015891687647	
i 1	799.256850340136	1.01	75	1085	3	1	7	8	0	-2	8	0	0	2.0	
i 1	799.256850340136	0.2525	73	699	1	20	11	17	0	1	17	0	0	3.0500158916876474	
i 1	799.2575714285714	0.2525	69	699	4	5	9	0	0	0	0	0	0	2.0	
i 1	799.4859387755102	0.7575000000000001	69	699	6	2	11	1	0	0	1	0	0	3.6280606234043393	
i 1	799.4917074829932	0.2525	72	201	7	5	13	1	0	-1	1	0	0	2.0	
i 1	799.4981972789116	1.2625	72	699	3	1	15	8	0	1	8	0	0	2.0	
i 1	799.5061292517007	0.7575000000000001	69	1085	4	9	11	1	0	-1	1	0	0	2.6280606234043393	
i 1	799.5075714285714	1.2625	75	201	4	1	15	2	0	-2	2	0	0	2.0	
i 1	799.9902653061224	1.01	72	1085	4	9	4	0	0	-1	0	0	0	2.6280606234043393	
i 1	800.0075714285714	1.2625	69	699	6	2	6	1	0	-1	1	0	0	3.6280606234043393	
i 1	800.0111768707483	0.2525	72	201	7	5	15	0	0	0	0	0	0	2.0	
i 1	800.2388231292517	1.7675	69	1085	3	5	6	0	0	-1	0	0	0	2.0	
i 1	800.2409863945578	3.2825	72	1085	4	1	16	2	0	-2	2	0	0	2.0	
i 1	800.2474761904762	1.7675	69	699	4	5	4	0	0	0	0	0	0	2.0	
i 1	800.2532448979592	3.2825	75	699	4	1	5	2	0	1	2	0	0	2.0	
i 1	800.5039659863945	1.5150000000000001	72	201	5	4	6	0	0	0	0	0	0	3.6280606234043393	
i 1	800.5097346938776	1.5150000000000001	69	699	4	4	13	1	0	0	1	0	0	3.6280606234043393	
i 1	800.743149659864	0.7575000000000001	72	699	3	5	6	1	0	-1	1	0	0	2.0	
i 1	800.7669455782313	0.2525	72	699	3	24	3	8	0	-2	8	0	0	3.0	
i 1	801.0054081632653	0.2525	72	201	4	24	4	2	0	-2	2	0	0	3.0	
i 1	801.2330544217687	0.2525	72	699	4	3	12	1	0	0	1	0	0	3.6280606234043393	
i 1	801.248918367347	0.505	76	699	1	20	2	17	0	1	17	0	0	3.0500158916876474	
i 1	801.251081632653	0.505	76	699	1	20	6	16	0	1	16	0	0	3.0500158916876474	
i 1	801.4830544217687	0.2525	76	201	1	24	16	17	0	2	17	0	0	7.050015891687647	
i 1	801.5061292517007	2.02	72	201	7	5	3	0	0	0	0	0	0	2.0	
i 1	801.5075714285714	3.2825	69	699	6	2	2	1	0	0	1	0	0	3.6280606234043393	
i 1	801.5075714285714	3.2825	69	1085	4	9	7	1	0	-1	1	0	0	2.6280606234043393	
i 1	801.516224489796	2.525	69	699	2	5	6	0	0	-1	0	0	0	2.0	
i 1	801.9917074829932	0.2525	72	699	4	5	4	1	0	-1	1	0	0	2.0	
i 1	801.998918367347	0.2525	72	1085	4	9	16	0	0	-1	0	0	0	2.6280606234043393	
i 1	802.2359387755102	0.2525	69	1085	3	5	2	0	0	-1	0	0	0	2.0	
i 1	802.2388231292517	0.2525	69	699	6	2	4	1	0	-1	1	0	0	3.6280606234043393	
i 1	802.2546870748299	0.2525	75	1085	3	1	2	8	0	-2	8	0	0	2.0	
i 1	802.5025238095238	1.5150000000000001	75	201	4	1	1	2	0	-2	2	0	0	2.0	
i 1	802.5075714285714	0.505	72	699	4	5	8	1	0	-1	1	0	0	2.0	
i 1	802.7445918367347	0.2525	69	699	6	2	3	1	0	-1	1	0	0	3.6280606234043393	
i 1	802.9902653061224	3.2825	72	699	3	5	14	1	0	-1	1	0	0	2.0	
i 1	803.0054081632653	1.01	72	699	3	1	8	8	0	1	8	0	0	2.0	
i 1	803.0147823129251	1.01	69	699	4	4	10	1	0	0	1	0	0	3.6280606234043393	
i 1	803.0169455782313	3.535	72	201	7	5	3	1	0	-1	1	0	0	2.0	
i 1	803.2438707482993	0.7575000000000001	72	201	5	4	7	0	0	0	0	0	0	3.6280606234043393	
i 1	803.4909863945578	1.5150000000000001	72	699	4	3	16	1	0	0	1	0	0	3.6280606234043393	
i 1	803.4960340136055	2.2725	72	201	4	24	2	2	0	-2	2	0	0	3.0	
i 1	803.4981972789116	2.2725	69	201	6	3	4	1	0	-1	1	0	0	3.6280606234043393	
i 1	803.5140612244898	2.02	72	699	3	24	11	8	0	-2	8	0	0	3.0	
i 1	803.9960340136055	0.2525	72	201	7	5	8	0	0	0	0	0	0	2.0	
i 1	804.0133401360545	0.2525	72	1085	4	1	7	2	0	-2	2	0	0	2.0	
i 1	804.2366598639455	0.2525	72	699	4	1	12	2	0	1	2	0	0	2.0	
i 1	804.266224489796	0.2525	69	699	2	5	13	0	0	-1	0	0	0	2.0	
i 1	804.516224489796	0.505	69	1085	3	5	2	0	0	-1	0	0	0	2.0	
i 1	804.748918367347	0.2525	75	1085	3	1	13	8	0	-2	8	0	0	2.0	
i 1	804.7554081632653	0.2525	72	1085	4	9	16	0	0	-1	0	0	0	2.6280606234043393	
i 1	804.9859387755102	5.8075	61	699	5	14	2	6	0	1	6	0	0	9.87391727338392	
i 1	804.9866598639455	0.2525	69	699	4	4	6	1	0	0	1	0	0	3.6280606234043393	
i 1	804.9866598639455	0.2525	76	699	1	20	1	17	0	1	17	0	0	3.0500158916876474	
i 1	804.9917074829932	1.2625	75	201	4	1	5	2	0	-2	2	0	0	2.0	
i 1	804.9967551020408	0.2525	76	201	1	24	3	16	0	2	16	0	0	7.050015891687647	
i 1	804.9974761904762	0.2525	76	699	4	20	10	16	0	2	16	0	0	3.0500158916876474	
i 1	804.9996394557824	0.7575000000000001	72	699	3	3	2	1	0	0	1	0	0	3.6280606234043393	
i 1	804.9996394557824	0.2525	69	1085	6	5	11	0	0	-1	0	0	0	2.0	
i 1	805.0018027210884	1.5150000000000001	72	699	3	1	10	8	0	1	8	0	0	2.0	
i 1	805.016224489796	17.4225	61	1085	4	16	11	6	0	0	6	0	0	3.247315634267973	
i 1	805.2453129251701	0.2525	69	699	2	5	8	0	0	-1	0	0	0	2.0	
i 1	805.2460340136055	1.5150000000000001	69	699	6	2	6	1	0	-1	1	0	0	3.6280606234043393	
i 1	805.2554081632653	1.5150000000000001	72	1085	4	9	5	0	0	-1	0	0	0	2.6280606234043393	
i 1	805.2647823129251	0.2525	73	1085	3	20	13	16	0	1	16	0	0	3.0500158916876474	
i 1	805.4909863945578	0.2525	72	699	4	5	5	1	0	-1	1	0	0	2.0	
i 1	805.4909863945578	0.505	76	699	1	20	9	17	0	2	17	0	0	3.0500158916876474	
i 1	805.4924285714286	0.505	76	201	1	20	4	16	0	2	16	0	0	3.0500158916876474	
i 1	805.7352176870749	1.7675	72	699	4	1	1	2	0	1	2	0	0	2.0	
i 1	805.7402653061224	0.2525	69	1085	5	9	10	1	0	-1	1	0	0	2.6280606234043393	
i 1	805.7460340136055	2.2725	69	699	2	5	16	0	0	-1	0	0	0	2.0	
i 1	805.7597346938776	1.7675	72	201	4	5	13	0	0	0	0	0	0	2.0	
i 1	805.766224489796	1.7675	75	1085	3	1	13	8	0	-2	8	0	0	2.0	
i 1	805.9859387755102	2.525	72	201	5	4	8	0	0	0	0	0	0	3.6280606234043393	
i 1	806.243149659864	2.2725	69	699	4	4	16	1	0	0	1	0	0	3.6280606234043393	
i 1	806.4938707482993	0.2525	69	1085	6	5	14	0	0	-1	0	0	0	2.0	
i 1	806.5126190476191	0.505	75	699	4	1	14	2	0	1	2	0	0	2.0	
i 1	806.7503605442176	0.2525	73	1085	3	20	7	17	0	1	17	0	0	3.0500158916876474	
i 1	806.7597346938776	0.2525	72	201	7	5	5	1	0	-1	1	0	0	2.0	
i 1	806.7647823129251	1.2625	69	1085	5	9	4	1	0	-1	1	0	0	2.6280606234043393	
i 1	806.983775510204	2.02	72	699	4	5	10	1	0	-1	1	0	0	2.0	
i 1	806.9866598639455	0.505	76	699	4	20	4	17	0	2	17	0	0	3.0500158916876474	
i 1	806.9945918367347	0.2525	76	201	1	20	11	16	0	1	16	0	0	3.0500158916876474	
i 1	807.0054081632653	1.01	75	201	4	1	8	2	0	-2	2	0	0	2.0	
i 1	807.0118979591837	1.01	69	699	4	2	3	1	0	0	1	0	0	3.6280606234043393	
i 1	807.0140612244898	1.7675	69	1085	6	5	8	0	0	-1	0	0	0	2.0	
i 1	807.0155034013605	1.01	72	699	3	1	9	8	0	1	8	0	0	2.0	
i 1	807.0176666666666	0.505	73	699	1	20	8	17	0	1	17	0	0	3.0500158916876474	
i 1	807.4873809523809	3.535	72	1085	3	1	6	2	0	-2	2	0	0	2.0	
i 1	807.4895442176871	3.535	75	699	4	1	12	2	0	1	2	0	0	2.0	
i 1	807.5018027210884	1.5150000000000001	76	1085	3	20	3	16	0	2	16	0	0	3.0500158916876474	
i 1	807.9945918367347	0.2525	72	699	3	24	8	8	0	-2	8	0	0	3.0	
i 1	808.0039659863945	1.7675	69	201	6	3	7	1	0	-1	1	0	0	3.6280606234043393	
i 1	808.0061292517007	1.5150000000000001	72	699	3	3	6	1	0	0	1	0	0	3.6280606234043393	
i 1	808.0118979591837	3.7875	69	699	4	5	10	0	0	0	0	0	0	2.0	
i 1	808.2381020408163	3.535	69	1085	6	5	7	0	0	-1	0	0	0	2.0	
i 1	808.251081632653	0.2525	72	699	3	1	13	8	0	1	8	0	0	2.0	
i 1	808.498918367347	2.02	69	699	4	2	2	1	0	0	1	0	0	3.6280606234043393	
i 1	808.9823333333334	0.2525	73	699	4	20	4	16	0	2	16	0	0	3.0500158916876474	
i 1	808.9852176870749	0.2525	76	699	1	20	13	16	0	1	16	0	0	3.0500158916876474	
i 1	809.0046870748299	0.2525	76	201	1	20	15	17	0	2	17	0	0	3.0500158916876474	
i 1	809.006850340136	1.5150000000000001	69	1085	5	9	6	1	0	-1	1	0	0	2.6280606234043393	
i 1	809.0075714285714	0.2525	72	699	3	5	2	1	0	-1	1	0	0	2.0	
i 1	809.2373809523809	0.2525	72	699	4	5	8	1	0	-1	1	0	0	2.0	
i 1	809.2655034013605	0.505	76	1085	3	20	10	16	0	1	16	0	0	3.0500158916876474	
i 1	809.743149659864	0.2525	72	201	4	5	11	0	0	0	0	0	0	2.0	
i 1	809.7474761904762	1.01	73	699	4	20	15	16	0	1	16	0	0	3.0500158916876474	
i 1	809.7582925170068	1.01	73	699	1	20	1	16	0	2	16	0	0	3.0500158916876474	
i 1	809.7597346938776	0.2525	72	1085	4	9	6	0	0	-1	0	0	0	2.6280606234043393	
i 1	809.9859387755102	1.2625	72	699	3	3	15	1	0	0	1	0	0	3.6280606234043393	
i 1	809.9924285714286	1.2625	69	201	6	3	4	1	0	-1	1	0	0	3.6280606234043393	
i 1	809.998918367347	0.2525	72	699	4	1	4	2	0	1	2	0	0	2.0	
i 1	810.0039659863945	0.505	72	699	3	5	5	1	0	-1	1	0	0	2.0	
i 1	810.2460340136055	1.5150000000000001	75	201	4	1	1	2	0	-2	2	0	0	2.0	
i 1	810.5003605442176	0.2525	72	201	5	4	14	0	0	0	0	0	0	3.6280606234043393	
i 1	810.5039659863945	0.2525	72	699	3	1	4	8	0	1	8	0	0	2.0	
i 1	810.506850340136	0.2525	69	1085	6	5	15	0	0	-1	0	0	0	2.0	
i 1	810.5090136054422	0.2525	73	201	1	20	6	17	0	2	17	0	0	3.0500158916876474	
i 1	810.7323333333334	17.4225	61	1085	4	16	8	6	0	1	6	0	0	3.247315634267973	
i 1	810.7323333333334	0.7575000000000001	72	1085	5	9	6	0	0	-1	0	0	0	2.6280606234043393	
i 1	810.7388231292517	0.505	72	699	3	5	4	1	0	-1	1	0	0	2.0	
i 1	810.7388231292517	0.2525	76	1085	3	20	11	17	0	2	17	0	0	3.0500158916876474	
i 1	810.7467551020408	27.5225	61	699	3	14	2	6	0	1	6	0	0	9.87391727338392	
i 1	810.7518027210884	0.2525	73	1085	3	20	15	16	0	2	16	0	0	3.0500158916876474	
i 1	810.7539659863945	5.8075	61	699	5	14	2	9	0	1	9	0	0	9.87391727338392	
i 1	810.7604557823129	0.7575000000000001	69	699	4	2	10	1	0	-1	1	0	0	3.6280606234043393	
i 1	810.7669455782313	1.01	72	699	2	1	10	8	0	1	8	0	0	2.0	
i 1	810.9917074829932	0.2525	73	699	4	20	15	16	0	2	16	0	0	3.0500158916876474	
i 1	810.9938707482993	0.2525	76	201	1	20	6	16	0	1	16	0	0	3.0500158916876474	
i 1	810.9996394557824	2.02	72	699	3	24	15	8	0	-2	8	0	0	3.0	
i 1	811.0025238095238	0.2525	76	699	4	20	2	16	0	2	16	0	0	3.0500158916876474	
i 1	811.006850340136	0.7575000000000001	69	699	3	4	12	1	0	0	1	0	0	3.6280606234043393	
i 1	811.0097346938776	0.7575000000000001	72	201	5	4	15	0	0	0	0	0	0	3.6280606234043393	
i 1	811.2373809523809	2.02	69	1085	5	9	3	1	0	-1	1	0	0	2.6280606234043393	
i 1	811.2388231292517	1.7675	72	201	4	24	9	2	0	-2	2	0	0	3.0	
i 1	811.2388231292517	1.7675	69	699	6	5	16	0	0	-1	0	0	0	2.0	
i 1	811.2424285714286	1.7675	76	1085	3	20	16	17	0	2	17	0	0	3.0500158916876474	
i 1	811.2445918367347	2.02	72	201	4	5	7	0	0	0	0	0	0	2.0	
i 1	811.2539659863945	2.2725	69	699	4	2	9	1	0	0	1	0	0	3.6280606234043393	
i 1	811.2647823129251	1.7675	73	699	1	24	10	16	0	252	16	307	0	7.050015891687647	
i 1	811.2655034013605	1.2625	76	1085	3	20	8	16	0	2	16	0	0	3.0500158916876474	
i 1	811.756850340136	0.2525	72	699	4	1	7	2	0	1	2	0	0	2.0	
i 1	811.7575714285714	0.2525	72	699	4	5	5	1	0	-1	1	0	0	2.0	
i 1	811.7582925170068	0.2525	72	1085	5	9	9	0	0	-1	0	0	0	2.6280606234043393	
i 1	811.9917074829932	0.505	75	699	4	1	5	2	0	1	2	0	0	2.0	
i 1	812.0025238095238	0.2525	72	699	3	5	13	1	0	-1	1	0	0	2.0	
i 1	812.0176666666666	0.2525	69	201	6	3	7	1	0	-1	1	0	0	3.6280606234043393	
i 1	812.2445918367347	0.2525	69	1085	6	5	7	0	0	-1	0	0	0	2.0	
i 1	812.4844965986395	0.2525	69	201	6	3	4	1	0	-1	1	0	0	3.6280606234043393	
i 1	812.4859387755102	1.01	72	699	2	1	11	8	0	1	8	0	0	2.0	
i 1	812.4873809523809	2.7775	72	699	3	5	5	1	0	-1	1	0	0	2.0	
i 1	812.501081632653	2.7775	72	201	4	5	13	1	0	-1	1	0	0	2.0	
i 1	812.5090136054422	1.01	75	201	4	1	4	2	0	-2	2	0	0	2.0	
i 1	812.7330544217687	1.5150000000000001	72	201	5	4	9	0	0	0	0	0	0	3.6280606234043393	
i 1	812.7633401360545	1.5150000000000001	69	699	3	4	16	1	0	0	1	0	0	3.6280606234043393	
i 1	812.9945918367347	0.2525	73	201	1	20	12	17	0	2	17	0	0	3.0500158916876474	
i 1	812.9981972789116	0.2525	73	699	4	20	2	16	0	1	16	0	0	3.0500158916876474	
i 1	813.001081632653	1.5150000000000001	75	1085	3	1	1	8	0	-2	8	0	0	2.0	
i 1	813.0097346938776	0.2525	76	201	1	24	10	17	0	2	17	0	0	7.050015891687647	
i 1	813.0111768707483	1.5150000000000001	72	699	4	1	8	2	0	1	2	0	0	2.0	
i 1	813.2647823129251	0.2525	72	699	4	5	12	1	0	-1	1	0	0	2.0	
i 1	813.2669455782313	0.7575000000000001	76	1085	3	20	14	16	0	2	16	0	0	3.0500158916876474	
i 1	813.501081632653	0.2525	69	699	4	2	16	1	0	-1	1	0	0	3.6280606234043393	
i 1	813.5025238095238	0.2525	72	201	4	24	5	2	0	-2	2	0	0	3.0	
i 1	813.5169455782313	0.505	69	699	6	5	13	0	0	-1	0	0	0	2.0	
i 1	813.7424285714286	0.2525	75	699	4	1	10	2	0	1	2	0	0	2.0	
i 1	813.756850340136	1.7675	72	699	3	3	10	1	0	0	1	0	0	3.6280606234043393	
i 1	813.7669455782313	1.7675	69	201	6	3	13	1	0	-1	1	0	0	3.6280606234043393	
i 1	813.9859387755102	0.2525	73	201	1	24	3	16	0	2	16	0	0	7.050015891687647	
i 1	813.9996394557824	0.2525	73	699	4	20	3	17	0	2	17	0	0	3.0500158916876474	
i 1	813.9996394557824	0.2525	76	201	1	20	8	16	0	2	16	0	0	3.0500158916876474	
i 1	814.0018027210884	1.01	72	699	2	1	6	8	0	1	8	0	0	2.0	
i 1	814.0118979591837	0.505	69	1085	6	5	1	0	0	-1	0	0	0	2.0	
i 1	814.0140612244898	1.01	75	201	4	1	12	2	0	-2	2	0	0	2.0	
i 1	814.256850340136	1.5150000000000001	73	699	1	24	15	16	0	252	16	307	0	7.050015891687647	
i 1	814.2611768707483	1.5150000000000001	73	1085	3	20	8	17	0	1	17	0	0	3.0500158916876474	
i 1	814.2640612244898	1.5150000000000001	73	1085	3	20	15	16	0	2	16	0	0	3.0500158916876474	
i 1	814.2676666666666	0.2525	69	699	4	2	14	1	0	-1	1	0	0	3.6280606234043393	
i 1	814.493149659864	0.7575000000000001	69	1085	5	9	11	1	0	-1	1	0	0	2.6280606234043393	
i 1	814.4945918367347	0.2525	72	699	4	5	1	1	0	-1	1	0	0	2.0	
i 1	814.5061292517007	0.7575000000000001	69	699	4	2	2	1	0	0	1	0	0	3.6280606234043393	
i 1	814.5090136054422	4.04	75	699	4	1	9	2	0	1	2	0	0	2.0	
i 1	814.5155034013605	4.04	72	1085	3	1	7	2	0	-2	2	0	0	2.0	
i 1	814.7373809523809	0.7575000000000001	69	699	6	5	11	0	0	-1	0	0	0	2.0	
i 1	814.7669455782313	0.7575000000000001	72	201	4	5	10	0	0	0	0	0	0	2.0	
i 1	814.9852176870749	0.2525	72	699	3	24	13	8	0	-2	8	0	0	3.0	
i 1	814.9873809523809	1.5150000000000001	69	1085	6	5	4	0	0	-1	0	0	0	2.0	
i 1	814.9895442176871	3.535	72	699	4	5	12	1	0	-1	1	0	0	2.0	
i 1	814.9996394557824	1.01	69	699	4	2	3	1	0	-1	1	0	0	3.6280606234043393	
i 1	815.0097346938776	1.01	72	1085	5	9	1	0	0	-1	0	0	0	2.6280606234043393	
i 1	815.2460340136055	0.2525	72	699	4	1	8	2	0	1	2	0	0	2.0	
i 1	815.4981972789116	0.2525	69	699	4	5	16	0	0	0	0	0	0	2.0	
i 1	815.501081632653	1.7675	72	201	5	4	15	0	0	0	0	0	0	3.6280606234043393	
i 1	815.5025238095238	1.5150000000000001	69	699	3	4	6	1	0	0	1	0	0	3.6280606234043393	
i 1	815.7402653061224	0.2525	73	699	4	20	8	16	0	1	16	0	0	3.0500158916876474	
i 1	815.7424285714286	0.2525	75	201	4	1	9	2	0	-2	2	0	0	2.0	
i 1	815.7554081632653	0.2525	73	201	1	20	4	16	0	1	16	0	0	3.0500158916876474	
i 1	815.756850340136	0.7575000000000001	69	1085	6	5	4	0	0	-1	0	0	0	2.0	
i 1	815.7597346938776	0.2525	73	699	4	20	4	17	0	1	17	0	0	3.0500158916876474	
i 1	816.0018027210884	0.505	72	699	4	1	16	2	0	1	2	0	0	2.0	
i 1	816.0046870748299	0.2525	73	1085	3	20	11	17	0	1	17	0	0	3.0500158916876474	
i 1	816.0075714285714	0.505	73	1085	3	20	9	16	0	1	16	0	0	3.0500158916876474	
i 1	816.0111768707483	0.2525	69	201	6	3	13	1	0	-1	1	0	0	3.6280606234043393	
i 1	816.2438707482993	3.535	69	1085	5	9	13	1	0	-1	1	0	0	2.6280606234043393	
i 1	816.4888231292517	0.2525	69	699	4	5	15	0	0	0	0	0	0	2.0	
i 1	816.4917074829932	17.4225	66	699	5	12	16	9	0	1	9	0	0	3.247315634267973	
i 1	816.4917074829932	5.8075	66	201	6	13	3	6	0	1	6	0	0	5.642238441933669	
i 1	816.4924285714286	3.2825	69	699	5	2	8	1	0	0	1	0	0	3.6280606234043393	
i 1	816.493149659864	0.2525	72	699	6	1	9	2	0	1	2	0	0	2.0	
i 1	816.4945918367347	0.2525	73	201	4	20	4	17	0	2	17	0	0	3.0500158916876474	
i 1	816.4960340136055	0.2525	76	699	4	20	1	16	0	2	16	0	0	3.0500158916876474	
i 1	816.5018027210884	21.715	61	699	3	14	14	9	0	1	9	0	0	9.87391727338392	
i 1	816.5025238095238	0.2525	76	699	4	20	12	17	0	1	17	0	0	3.0500158916876474	
i 1	816.5097346938776	2.02	69	1085	3	5	16	0	0	-1	0	0	0	2.0	
i 1	816.5147823129251	0.2525	76	201	1	24	16	16	0	1	16	0	0	7.050015891687647	
i 1	816.7381020408163	1.2625	73	1085	3	20	12	16	0	1	16	0	0	3.0500158916876474	
i 1	816.7453129251701	0.2525	76	1085	3	20	1	17	0	2	17	0	0	3.0500158916876474	
i 1	816.7503605442176	0.2525	72	201	4	5	1	0	0	0	0	0	0	2.0	
i 1	816.7626190476191	0.2525	72	699	2	1	12	8	0	1	8	0	0	2.0	
i 1	816.9938707482993	0.505	75	1085	3	1	7	8	0	-2	8	0	0	2.0	
i 1	817.0046870748299	0.505	69	699	6	5	6	0	0	-1	0	0	0	2.0	
i 1	817.2467551020408	0.2525	72	1085	5	9	11	0	0	-1	0	0	0	2.6280606234043393	
i 1	817.2669455782313	0.7575000000000001	76	1085	3	20	12	17	0	2	17	0	0	3.0500158916876474	
i 1	817.4859387755102	0.2525	72	699	5	3	13	1	0	0	1	0	0	3.6280606234043393	
i 1	817.4938707482993	0.505	73	699	2	20	12	16	0	1	16	0	0	3.0500158916876474	
i 1	817.5039659863945	0.2525	72	201	4	5	11	1	0	-1	1	0	0	2.0	
i 1	817.5118979591837	0.2525	72	699	6	1	8	2	0	1	2	0	0	2.0	
i 1	817.7518027210884	0.2525	69	201	4	3	7	1	0	-1	1	0	0	3.6280606234043393	
i 1	817.7546870748299	3.2825	69	1085	6	5	8	0	0	-1	0	0	0	2.0	
i 1	817.7655034013605	0.2525	75	1085	3	1	11	8	0	-2	8	0	0	2.0	
i 1	817.9830544217687	0.505	76	699	4	20	5	16	0	2	16	0	0	3.0500158916876474	
i 1	817.9888231292517	0.505	76	201	4	20	12	16	0	2	16	0	0	3.0500158916876474	
i 1	817.9996394557824	1.01	72	699	2	1	11	8	0	1	8	0	0	2.0	
i 1	818.0018027210884	0.2525	76	699	4	20	2	16	0	1	16	0	0	3.0500158916876474	
i 1	818.0090136054422	1.01	75	201	4	1	4	2	0	-2	2	0	0	2.0	
i 1	818.0097346938776	3.0300000000000002	69	699	4	5	9	0	0	0	0	0	0	2.0	
i 1	818.0133401360545	1.01	69	699	3	4	9	1	0	0	1	0	0	3.6280606234043393	
i 1	818.2388231292517	0.7575000000000001	72	201	5	4	9	0	0	0	0	0	0	3.6280606234043393	
i 1	818.266224489796	0.2525	73	201	1	24	3	17	0	1	17	0	0	7.050015891687647	
i 1	818.483775510204	0.505	69	699	6	5	15	0	0	-1	0	0	0	2.0	
i 1	818.4873809523809	2.2725	69	201	4	3	16	1	0	-1	1	0	0	3.6280606234043393	
i 1	818.4881020408163	1.5150000000000001	72	201	4	24	8	2	0	-2	2	0	0	3.0	
i 1	818.4909863945578	2.525	72	699	5	3	5	1	0	0	1	0	0	3.6280606234043393	
i 1	818.493149659864	0.2525	73	699	2	20	10	16	0	1	16	0	0	3.0500158916876474	
i 1	818.506850340136	3.2825	76	1085	3	20	3	16	0	2	16	0	0	3.0500158916876474	
i 1	818.5147823129251	1.5150000000000001	72	699	2	24	4	8	0	-2	8	0	0	3.0	
i 1	818.9953129251701	0.2525	72	699	6	1	4	2	0	1	2	0	0	2.0	
i 1	819.0046870748299	0.2525	72	201	4	5	4	0	0	0	0	0	0	2.0	
i 1	819.2546870748299	0.2525	72	699	4	5	11	1	0	-1	1	0	0	2.0	
i 1	819.256850340136	0.2525	75	1085	3	1	14	8	0	-2	8	0	0	2.0	
i 1	819.4888231292517	0.505	69	1085	3	5	4	0	0	-1	0	0	0	2.0	
i 1	819.5032448979592	1.01	72	699	2	1	15	8	0	1	8	0	0	2.0	
i 1	819.5090136054422	1.01	75	201	4	1	1	2	0	-2	2	0	0	2.0	
i 1	819.7352176870749	2.2725	73	699	2	20	4	16	0	1	16	0	0	3.0500158916876474	
i 1	819.766224489796	0.505	69	699	3	4	2	1	0	0	1	0	0	3.6280606234043393	
i 1	819.9953129251701	2.02	75	1085	3	1	14	8	0	-2	8	0	0	2.0	
i 1	820.0025238095238	0.2525	69	699	6	5	4	0	0	-1	0	0	0	2.0	
i 1	820.0061292517007	2.02	72	699	6	1	14	2	0	1	2	0	0	2.0	
i 1	820.2409863945578	1.7675	72	1085	5	9	2	0	0	-1	0	0	0	2.6280606234043393	
i 1	820.2518027210884	1.5150000000000001	69	699	4	2	6	1	0	-1	1	0	0	3.6280606234043393	
i 1	820.266224489796	0.2525	72	699	6	5	14	1	0	-1	1	0	0	2.0	
i 1	820.4924285714286	0.2525	75	699	4	1	9	2	0	1	2	0	0	2.0	
i 1	820.4967551020408	1.7675	72	201	4	5	16	0	0	0	0	0	0	2.0	
i 1	820.4974761904762	1.5150000000000001	69	699	6	5	5	0	0	-1	0	0	0	2.0	
i 1	820.7323333333334	0.2525	72	201	4	24	9	2	0	-2	2	0	0	3.0	
i 1	820.983775510204	0.2525	69	201	4	3	8	1	0	-1	1	0	0	3.6280606234043393	
i 1	821.0118979591837	0.2525	72	699	4	5	10	1	0	-1	1	0	0	2.0	
i 1	821.233775510204	0.2525	69	699	4	5	2	0	0	0	0	0	0	2.0	
i 1	821.2373809523809	1.01	69	699	3	4	15	1	0	0	1	0	0	3.6280606234043393	
i 1	821.2467551020408	1.01	72	201	5	4	1	0	0	0	0	0	0	3.6280606234043393	
i 1	821.2561292517007	0.2525	75	699	4	1	2	2	0	1	2	0	0	2.0	
i 1	821.266224489796	0.7575000000000001	76	1085	3	20	2	16	0	2	16	0	0	3.0500158916876474	
i 1	821.4873809523809	2.2725	72	201	4	5	8	1	0	-1	1	0	0	2.0	
i 1	821.4924285714286	1.2625	72	699	2	1	1	8	0	1	8	0	0	2.0	
i 1	821.4953129251701	2.2725	72	699	6	5	5	1	0	-1	1	0	0	2.0	
i 1	821.501081632653	1.2625	75	201	4	1	13	2	0	-2	2	0	0	2.0	
i 1	821.9881020408163	0.2525	73	201	1	24	15	16	0	2	16	0	0	7.050015891687647	
i 1	821.9945918367347	0.2525	73	699	4	20	9	17	0	1	17	0	0	3.0500158916876474	
i 1	821.9953129251701	0.2525	76	201	4	20	8	16	0	2	16	0	0	3.0500158916876474	
i 1	821.9967551020408	1.01	69	1085	5	9	3	1	0	-1	1	0	0	2.6280606234043393	
i 1	821.998918367347	1.01	69	699	5	2	15	1	0	0	1	0	0	3.6280606234043393	
i 1	822.016224489796	0.2525	72	699	2	24	13	8	0	-2	8	0	0	3.0	
i 1	822.2344965986395	0.2525	73	1085	3	20	1	16	0	2	16	0	0	3.0500158916876474	
i 1	822.2366598639455	3.2825	76	699	2	24	3	17	0	2	17	0	0	7.050015891687647	
i 1	822.2395442176871	3.2825	75	699	6	1	4	2	0	1	2	0	0	2.0	
i 1	822.2395442176871	15.9075	66	201	3	13	8	6	0	1	6	0	0	5.642238441933669	
i 1	822.2474761904762	3.0300000000000002	76	699	2	20	4	16	0	1	16	0	0	3.0500158916876474	
i 1	822.2481972789116	5.8075	61	201	6	7	11	6	0	0	6	0	0	8.463357662900505	
i 1	822.248918367347	1.2625	72	201	4	4	13	0	0	0	0	0	0	3.6280606234043393	
i 1	822.2525238095238	15.9075	61	699	5	12	2	6	0	0	6	0	0	3.247315634267973	
i 1	822.2561292517007	1.2625	69	699	4	4	6	1	0	0	1	0	0	3.6280606234043393	
i 1	822.2640612244898	3.2825	72	1085	3	1	6	2	0	-2	2	0	0	2.0	
i 1	822.2640612244898	0.2525	69	699	6	5	4	0	0	-1	0	0	0	2.0	
i 1	822.483775510204	0.2525	69	1085	3	5	5	0	0	-1	0	0	0	2.0	
i 1	822.7388231292517	0.2525	75	1085	3	1	7	8	0	-2	8	0	0	2.0	
i 1	822.7409863945578	0.2525	72	201	4	5	6	0	0	0	0	0	0	2.0	
i 1	822.9830544217687	0.2525	72	201	4	24	14	2	0	-2	2	0	0	3.0	
i 1	822.9953129251701	1.5150000000000001	69	201	4	3	16	1	0	-1	1	0	0	3.6280606234043393	
i 1	822.9981972789116	1.7675	72	699	5	3	16	1	0	0	1	0	0	3.6280606234043393	
i 1	823.001081632653	2.2725	69	699	6	5	8	0	0	-1	0	0	0	2.0	
i 1	823.2532448979592	2.02	72	201	4	5	6	0	0	0	0	0	0	2.0	
i 1	823.5097346938776	0.2525	72	1085	5	9	2	0	0	-1	0	0	0	2.6280606234043393	
i 1	823.7381020408163	0.2525	69	699	4	5	13	0	0	0	0	0	0	2.0	
i 1	823.7402653061224	0.2525	72	201	4	4	13	0	0	0	0	0	0	3.6280606234043393	
i 1	823.9902653061224	0.2525	72	699	6	5	12	1	0	-1	1	0	0	2.0	
i 1	824.0018027210884	1.5150000000000001	69	1085	5	9	6	1	0	-1	1	0	0	2.6280606234043393	
i 1	824.0133401360545	1.5150000000000001	69	699	5	2	13	1	0	0	1	0	0	3.6280606234043393	
i 1	824.4859387755102	0.2525	69	1085	3	5	2	0	0	-1	0	0	0	2.0	
i 1	824.7395442176871	0.2525	72	699	2	24	12	8	0	-2	8	0	0	3.0	
i 1	824.748918367347	2.7775	72	699	6	5	15	1	0	-1	1	0	0	2.0	
i 1	824.7597346938776	2.7775	69	1085	3	5	12	0	0	-1	0	0	0	2.0	
i 1	824.7640612244898	0.2525	69	699	5	2	13	1	0	-1	1	0	0	3.6280606234043393	
i 1	824.9881020408163	1.01	69	201	4	3	6	1	0	-1	1	0	0	3.6280606234043393	
i 1	824.9902653061224	0.7575000000000001	75	201	4	1	6	2	0	-2	2	0	0	2.0	
i 1	824.9960340136055	1.01	72	699	5	3	2	1	0	0	1	0	0	3.6280606234043393	
i 1	825.0118979591837	0.7575000000000001	72	699	2	1	16	8	0	1	8	0	0	2.0	
i 1	825.248918367347	0.505	72	699	6	5	16	1	0	-1	1	0	0	2.0	
i 1	825.2575714285714	0.2525	73	1085	3	20	11	16	0	2	16	0	0	3.0500158916876474	
i 1	825.4924285714286	2.02	72	201	4	24	2	2	0	-2	2	0	0	3.0	
i 1	825.4974761904762	2.02	72	699	2	24	8	8	0	-2	8	0	0	3.0	
i 1	825.5082925170068	0.2525	69	699	4	4	3	1	0	0	1	0	0	3.6280606234043393	
i 1	825.5097346938776	0.2525	76	201	4	20	15	16	0	1	16	0	0	3.0500158916876474	
i 1	825.5104557823129	0.2525	73	699	4	20	15	17	0	1	17	0	0	3.0500158916876474	
i 1	825.5176666666666	0.2525	76	201	4	24	1	16	0	2	16	0	0	7.050015891687647	
i 1	825.7532448979592	0.2525	72	201	4	5	3	1	0	-1	1	0	0	2.0	
i 1	825.7554081632653	0.7575000000000001	69	699	5	2	6	1	0	-1	1	0	0	3.6280606234043393	
i 1	825.7618979591837	0.2525	75	699	6	1	6	2	0	1	2	0	0	2.0	
i 1	825.7626190476191	0.7575000000000001	72	1085	5	9	10	0	0	-1	0	0	0	2.6280606234043393	
i 1	825.9823333333334	0.2525	76	201	4	20	10	17	0	2	17	0	0	3.0500158916876474	
i 1	825.9960340136055	0.2525	72	1085	3	1	14	2	0	-2	2	0	0	2.0	
i 1	826.0003605442176	0.7575000000000001	72	201	4	4	3	0	0	0	0	0	0	3.6280606234043393	
i 1	826.0054081632653	0.2525	76	699	4	20	16	17	0	2	17	0	0	3.0500158916876474	
i 1	826.0104557823129	0.505	72	201	4	5	13	0	0	0	0	0	0	2.0	
i 1	826.0169455782313	0.2525	73	201	4	24	12	16	0	2	16	0	0	7.050015891687647	
i 1	826.2409863945578	1.7675	69	1085	5	9	3	1	0	-1	1	0	0	2.6280606234043393	
i 1	826.2409863945578	0.505	73	699	2	24	16	16	0	2	16	0	0	7.050015891687647	
i 1	826.2445918367347	0.505	73	699	2	20	9	16	0	1	16	0	0	3.0500158916876474	
i 1	826.2640612244898	2.02	69	699	5	2	4	1	0	0	1	0	0	3.6280606234043393	
i 1	826.266224489796	0.505	69	699	4	4	8	1	0	0	1	0	0	3.6280606234043393	
i 1	826.4823333333334	0.2525	72	201	4	5	4	1	0	-1	1	0	0	2.0	
i 1	826.5169455782313	0.2525	72	699	6	1	13	2	0	1	2	0	0	2.0	
i 1	826.7344965986395	0.2525	69	201	4	3	9	1	0	-1	1	0	0	3.6280606234043393	
i 1	826.7438707482993	0.2525	69	1085	3	5	12	0	0	-1	0	0	0	2.0	
i 1	826.751081632653	0.505	73	201	4	24	3	17	0	1	17	0	0	7.050015891687647	
i 1	826.7640612244898	0.505	73	201	4	20	15	17	0	2	17	0	0	3.0500158916876474	
i 1	826.9823333333334	1.7675	72	699	2	1	6	8	0	1	8	0	0	2.0	
i 1	826.9844965986395	1.01	69	699	4	5	2	0	0	0	0	0	0	2.0	
i 1	827.0155034013605	1.01	75	201	4	1	5	2	0	-2	2	0	0	2.0	
i 1	827.2344965986395	0.2525	73	1085	3	20	1	17	0	1	17	0	0	3.0500158916876474	
i 1	827.2417074829932	0.2525	76	699	2	20	6	16	0	1	16	0	0	3.0500158916876474	
i 1	827.2496394557824	1.7675	69	1085	3	5	5	0	0	-1	0	0	0	2.0	
i 1	827.256850340136	0.2525	73	699	2	24	4	17	0	2	17	0	0	7.050015891687647	
i 1	827.2575714285714	0.2525	72	1085	5	9	6	0	0	-1	0	0	0	2.6280606234043393	
i 1	827.4859387755102	0.2525	76	201	4	20	8	16	0	2	16	0	0	3.0500158916876474	
i 1	827.4881020408163	0.2525	73	699	4	20	15	16	0	1	16	0	0	3.0500158916876474	
i 1	827.4945918367347	1.7675	72	201	4	4	16	0	0	0	0	0	0	3.6280606234043393	
i 1	827.5090136054422	0.2525	72	201	4	5	15	1	0	-1	1	0	0	2.0	
i 1	827.5111768707483	0.2525	76	201	4	24	6	17	0	1	17	0	0	7.050015891687647	
i 1	827.7323333333334	1.5150000000000001	69	699	4	4	14	1	0	0	1	0	0	3.6280606234043393	
i 1	827.7590136054422	1.5150000000000001	72	699	6	1	10	2	0	1	2	0	0	2.0	
i 1	827.7590136054422	0.2525	69	1085	3	5	13	0	0	-1	0	0	0	2.0	
i 1	827.9953129251701	0.2525	75	201	6	1	8	2	0	-2	2	0	0	2.0	
i 1	827.9974761904762	1.2625	75	1085	3	1	7	8	0	-2	8	0	0	2.0	
i 1	827.998918367347	0.2525	73	201	4	20	12	17	0	2	17	0	0	3.0500158916876474	
i 1	828.0003605442176	0.2525	73	1085	3	24	3	17	0	1	17	0	0	7.050015891687647	
i 1	828.0018027210884	1.01	69	699	6	5	1	0	0	0	0	0	0	2.0	
i 1	828.0039659863945	0.2525	73	201	4	24	9	17	0	1	17	0	0	7.050015891687647	
i 1	828.0046870748299	0.2525	69	1085	3	9	7	1	0	-1	1	0	0	2.6280606234043393	
i 1	828.0111768707483	0.2525	73	699	4	20	15	16	0	2	16	0	0	3.0500158916876474	
i 1	828.0176666666666	10.1	61	201	4	7	1	6	0	0	6	0	0	8.463357662900505	
i 1	828.233775510204	0.7575000000000001	76	1085	3	20	12	17	0	1	17	0	0	3.0500158916876474	
i 1	828.243149659864	0.7575000000000001	73	699	2	20	10	17	0	2	17	0	0	3.0500158916876474	
i 1	828.2460340136055	0.2525	69	1085	3	5	1	0	0	-1	0	0	0	2.0	
i 1	828.4953129251701	0.2525	72	699	5	3	15	1	0	0	1	0	0	3.6280606234043393	
i 1	828.4981972789116	1.7675	72	201	4	5	7	0	0	0	0	0	0	2.0	
i 1	828.506850340136	1.7675	69	699	2	5	3	0	0	-1	0	0	0	2.0	
i 1	828.7344965986395	0.2525	69	1085	3	9	3	1	0	-1	1	0	0	2.6280606234043393	
i 1	828.7669455782313	0.505	72	201	4	24	3	2	0	-2	2	0	0	3.0	
i 1	828.9881020408163	1.2625	72	699	5	3	9	1	0	0	1	0	0	3.6280606234043393	
i 1	828.9953129251701	0.2525	73	699	4	20	7	17	0	1	17	0	0	3.0500158916876474	
i 1	828.998918367347	0.505	73	1085	3	24	7	17	0	1	17	0	0	7.050015891687647	
i 1	829.0032448979592	1.2625	69	201	5	3	3	1	0	-1	1	0	0	3.6280606234043393	
i 1	829.0118979591837	0.2525	73	201	4	24	5	17	0	1	17	0	0	7.050015891687647	
i 1	829.2546870748299	0.505	72	699	2	1	13	8	0	1	8	0	0	2.0	
i 1	829.2582925170068	0.2525	76	1085	3	20	12	17	0	2	17	0	0	3.0500158916876474	
i 1	829.2618979591837	0.505	76	699	2	24	2	16	0	1	16	0	0	7.050015891687647	
i 1	829.2655034013605	0.505	73	699	2	20	3	16	0	1	16	0	0	3.0500158916876474	
i 1	829.266224489796	0.505	75	201	6	1	15	2	0	-2	2	0	0	2.0	
i 1	829.266224489796	0.2525	69	1085	3	5	7	0	0	-1	0	0	0	2.0	
i 1	829.4945918367347	0.2525	72	201	4	4	9	0	0	0	0	0	0	3.6280606234043393	
i 1	829.5176666666666	0.2525	72	699	6	5	6	1	0	-1	1	0	0	2.0	
i 1	829.7575714285714	0.505	73	201	4	20	10	16	0	2	16	0	0	3.0500158916876474	
i 1	829.7604557823129	2.2725	72	1085	3	1	14	2	0	-2	2	0	0	2.0	
i 1	829.7618979591837	2.2725	75	699	6	1	1	2	0	1	2	0	0	2.0	
i 1	829.7633401360545	0.505	69	1085	3	9	12	1	0	-1	1	0	0	2.6280606234043393	
i 1	829.766224489796	0.505	69	699	5	2	4	1	0	0	1	0	0	3.6280606234043393	
i 1	829.9823333333334	2.02	72	699	6	5	4	1	0	-1	1	0	0	2.0	
i 1	829.9996394557824	1.01	72	1085	5	9	16	0	0	-1	0	0	0	2.6280606234043393	
i 1	830.0097346938776	1.01	69	699	5	2	11	1	0	-1	1	0	0	3.6280606234043393	
i 1	830.0097346938776	2.02	72	201	4	5	4	1	0	-1	1	0	0	2.0	
i 1	830.2381020408163	0.2525	75	1085	3	1	4	8	0	-2	8	0	0	2.0	
i 1	830.2453129251701	0.2525	73	1085	3	20	3	17	0	2	17	0	0	3.0500158916876474	
i 1	830.2453129251701	0.2525	76	699	2	20	16	17	0	2	17	0	0	3.0500158916876474	
i 1	830.2503605442176	0.505	73	1085	3	24	10	17	0	1	17	0	0	7.050015891687647	
i 1	830.2611768707483	0.2525	76	699	2	24	7	17	0	1	17	0	0	7.050015891687647	
i 1	830.2669455782313	1.5150000000000001	69	699	4	4	2	1	0	0	1	0	0	3.6280606234043393	
i 1	830.4881020408163	0.2525	76	699	4	20	1	16	0	1	16	0	0	3.0500158916876474	
i 1	830.5039659863945	1.2625	72	201	4	4	14	0	0	0	0	0	0	3.6280606234043393	
i 1	830.5090136054422	0.2525	76	201	4	20	16	16	0	1	16	0	0	3.0500158916876474	
i 1	830.5118979591837	0.2525	73	201	4	24	2	17	0	2	17	0	0	7.050015891687647	
i 1	830.7366598639455	1.2625	73	699	2	20	1	17	0	2	17	0	0	3.0500158916876474	
i 1	830.7518027210884	1.2625	76	699	2	24	5	16	0	2	16	0	0	7.050015891687647	
i 1	831.2417074829932	0.2525	72	699	6	5	10	1	0	-1	1	0	0	2.0	
i 1	831.7417074829932	0.2525	69	699	5	2	11	1	0	0	1	0	0	3.6280606234043393	
i 1	831.7604557823129	0.2525	69	1085	3	9	4	1	0	-1	1	0	0	2.6280606234043393	
t0 106
</CsScore>
</CsoundSynthesizer>

