#!/usr/bin/env python


from cig.addyndum.applications import ParallelScript


class Specfem(ParallelScript):
    
    
    # name by which the user refers to this application
    componentName = "Specfem3DGlobe"
    
    
    #
    #--- inventory
    #
    
    import pyre.inventory as pyre
    import cig.addyndum.inventory as addyndum
    
    from Mesher import Mesher
    from Model import model
    from Solver import Solver
    
    LOCAL_PATH                    = pyre.str("local-path")
    outputDir                     = addyndum.outputdir("output-dir", default="OUTPUT_FILES")
        
    model                         = model("model", default="isotropic_prem")
    mesher                        = addyndum.facility("mesher", factory=Mesher)
    solver                        = addyndum.facility("solver", factory=Solver)
    
    command                       = pyre.str("command", validator=pyre.choice(['mesh', 'solve', 'go']), default="go")

    # default to LSF for Caltech cluster
    scheduler                     = addyndum.scheduler("scheduler", default="lsf")

    
    #
    #--- configuration
    #
    
    def _configure(self):
        ParallelScript._configure(self)
        
        self.OUTPUT_FILES = self.outputDir

        # declare the exectuables used for launching and computing
        from os.path import join
        self.computeExe = join(self.outputDir, "pyspecfem3D")
        self.launcherExe = self.computeExe

        # validate absorbing conditions
        if self.solver.ABSORBING_CONDITIONS:
            NCHUNKS = self.mesher.NCHUNKS
            if NCHUNKS == 6:
                raise ValueError("cannot have absorbing conditions in the full Earth")
            elif NCHUNKS == 3:
                raise ValueError("absorbing conditions not supported for three chunks yet")
        
        return


    #
    #--- executed on the login node in response to the user's command
    #
    
    def onLoginNode(self, *args, **kwds):
        
        import sys
        import shutil
        
        pyspecfem3D = sys.executable # the current executable
        
        # the launcher is simply a copy of the current executable
        shutil.copyfile(pyspecfem3D, self.launcherExe)
        
        # build the solver
        self.solver.build(self)
        
        # compute the total number of processors needed
        self.nodes = self.mesher.nproc()

        self.schedule() # bsub
        
        return


    #
    #--- executed when the batch job is scheduled
    #

    def onLauncherNode(self, *args, **kwds):
        self.launch(*args, **kwds) # mpirun
        # tar up results
        return

    
    #
    #--- executed in parallel on the compute nodes
    #
    
    def onComputeNodes(self, *args, **kwds):

        # execute mesher and/or solver
        
        if self.command == "mesh" or self.command == "go":
            self.mesher.execute(self)
        
        if self.command == "solve" or self.command == "go":
            self.solver.execute(self)

        return
            


def main():
    script = Specfem()
    script.run()


# end of file
