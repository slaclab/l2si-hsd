libnames := hsd134
libsrcs_hsd134 := $(filter-out hsd_init.cc hsd_pgp.cc hsd_sim.cc hsd_valid.cc hsd_xvc.cc hsd_datadev.cc hsd_validate.cc hsd_validate_sim.cc hsd_eyescan.cc hsd_reg.cc hsdRead.cc promload.cc, $(wildcard *.cc))
libincs_hsd134 := Module134.hh ModuleBase.hh TprCore.hh AxiVersion.h Event.hh Globals.hh DmaDriver.h

tgtnames := hsd_init
tgtsrcs_hsd_init := hsd_init.cc
tgtlibs_hsd_init := hsd134
tgtslib_hsd_init := rt

tgtnames += hsd_reg
tgtsrcs_hsd_reg := hsd_reg.cc Histogram.cc
tgtlibs_hsd_reg := hsd134
tgtslib_hsd_reg := rt pthread

#tgtnames += hsd_xvc
tgtsrcs_hsd_xvc := hsd_xvc.cc
tgtlibs_hsd_xvc := hsd134
tgtslib_hsd_xvc := rt pthread

#tgtnames += hsd_pgp
#tgtsrcs_hsd_pgp := hsd_pgp.cc
#tgtlibs_hsd_pgp := hsd
#tgtslib_hsd_pgp := rt pthread

#tgtnames += hsd_sim
tgtsrcs_hsd_sim := hsd_sim.cc
tgtslib_hsd_sim := rt pthread

tgtnames += hsd_datadev
tgtsrcs_hsd_datadev := hsd_datadev.cc
tgtlibs_hsd_datadev := hsd134
tgtslib_hsd_datadev := rt pthread

#tgtnames += hsd_valid
#tgtsrcs_hsd_valid := hsd_valid.cc
#tgtslib_hsd_valid := rt pthread
