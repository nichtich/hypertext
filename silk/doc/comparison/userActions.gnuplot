# move the legend out of the way
set key graph 0.55, graph 0.93


set terminal postscript eps
set output "userActions.eps"

set size .6,.6

set samples 16

set title "User actions needed to create links to \"Test Page\""
set xlabel "number of links created"
set ylabel "number of user actions"
#plot "31nodes_6M.data" using 1:($2-1049339196) title "time to reach receivers" with linespoints, 252 * ( log(x)/log(2) + 1) title "log bound" with lines
plot [x=0:15] [0:50]                                                  \
     ( x<=0 )? 0 :                                                    \
       ( ( x<=1 )? ( 19*x ):                                          \
         ( ( x<2 )? ( 19 + 10*(x-1) ):                                \
           ( 19 + 10 + 7*(x-2) ) ) ) title "Web" with linespoints 1 3,  \
     ( x<=0 )? 0 :                                                    \
       ( ( x<=1 )? ( 11*x ):                                          \
         ( ( x<2 )? ( 11 + 5*(x-1) ):                                 \
           ( 11 + 5 + 2*(x-2) ) ) ) title "Everything2" with linespoints 1 1, \
     ( x<=0 )? 0 :                                                    \
       ( ( x<=1 )? ( 9*x ):                                           \
         ( ( x<2 )? ( 9 + 5*(x-1) ):                                  \
           ( 9 + 5 + 2*(x-2) ) ) ) title "Wiki" with linespoints 1 4, \
     ( x<=0 )? 0 :                                                    \
       ( 3*x ) title "Tinderbox" with linespoints 1 5,                \
     ( x<=0 )? 0 :                                                    \
       ( ( x<=1 )? ( 2*x ):                                           \
         ( 2 + 1*(x-1) ) ) title "silk" with linespoints 1 2 

pause -1 "Hit any key to continue"

