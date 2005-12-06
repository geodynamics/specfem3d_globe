#!/usr/bin/env python


from Script import Script
import Specfem3DGlobeCode


class Specfem(Script):
    
    def __init__(self):
        Script.__init__(self, "specfem")

    def main(self, *args, **kwds):
        Specfem3DGlobeCode.specfem3D(self)


# end of file
