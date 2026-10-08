# Cap OpenMP/BLAS threads so CPU time stays close to elapsed time on CRAN.
Sys.setenv(OMP_THREAD_LIMIT = 2)

library(testthat)
library(sbert)

test_check("sbert")

