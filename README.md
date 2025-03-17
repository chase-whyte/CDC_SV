CDC modules:  
1. async fifo with configurable bit-width and depth  
  -can be used with any clock frequency
     
3. pulse synchronization module  
  -only used for synchronizing a pulse from slow domain to fast domain.  
  -if used when going from a fast clock doain to slow, it is possible that the pulse will not be detected. To guarantee the pulse will be detected, the period of the receiving clock
  should be at least 1.5x the period of the sending clock.
  
5. pulse synchronization module using graycode counter  
  -can be used with any clock frequency  
