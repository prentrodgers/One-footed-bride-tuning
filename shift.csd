; The next section added on 5/4/22 to ensure that a sample file out of range is not selected.
  iLength ftlen iSampWaveTable ; length of the table (128). How many steps it could hold.
  indx = 0
  iLowValue table indx, iSampWaveTable
  iHighValue table iLength, iSampWaveTable
  loop:
      iCurValue table indx, iSampWaveTable
      if iFtable == iCurValue goto iFound
      loop_lt indx, 1, iLength, loop ; this is basically a conditional goto statement
; it's not in the list of valid samples. It could be too low or too high  - for now reset it to what it originally was
; it went to far
; if the upsample went to a higher sample file, set it to the maximum in the table
  giMoved = giMoved + 1
;   printf_i "upsample moved sample number out of range of available samples. requested %i ", 1, iFtable 
  if iFtable > iFtableTemp then       
     iFtable = iHighValue 
  else 
     iFtable = iLowValue 
  endif
;   printf_i "switched to %i. giMoved now: %d\n", 1, iFtableTemp , giMoved
printf_i "voice: %i. switched sample from %i to %i. Total moved so far: %i\n", 1, iVoice, iFtableTemp, iFtable, giMoved
  iFound:
 ; End of modification 5/4/22