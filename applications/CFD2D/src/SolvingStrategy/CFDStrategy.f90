module CFDStrategyM 

  use UtilitiesM
  use SparseKit
  use DebuggerM

  use ProcessInfoM
  use ProcessM
  use CFDApplicationM

  use CFDElementM

  use NewStrategyM
  use SolvingStrategyM

  use PrintM
  use RestartPrintM

  use CFDSchemeM
  use CFDBuilderAndSolverM
  use SchemeM
  use BuilderAndSolverM

  use NavierStokes2DM

  use ExplicitEulerM

  implicit none

  private
  public :: CFDStrategyDT

  type, extends(NewStrategyDT) :: CFDStrategyDT
   contains
     procedure, nopass :: useNewStrategy => CFDStrategy 
  end type CFDStrategyDT


contains

  subroutine CFDStrategy(this)
    implicit none
    class(ProcessDT)  , intent(inout)       :: this
    type(CFDSchemeDT)                       :: scheme
    type(CFDBuilderAndSolverDT)             :: builderAndSolver
    type(PrintDT)                           :: writeOutput
    type(RestartPrintDT)                    :: writeRestart
    type(NavierStokes2DDT)                  :: NavierStokes2D
    type(ExplicitEulerDT)                   :: ExplicitEuler
    real(rkind), dimension(:) , allocatable :: oldDof
    real(rkind)                             :: dtMin, dtMin1, t
    real(rkind)                             :: factor, error, porc
    real(rkind)                             :: errorTol, error1(4), error2(4)
    integer(ikind)                          :: maxIter, iNode, nNode, i, iDof
    integer(ikind)                          :: step1, step2, printStep
    logical                                 :: multi_step = .false.
    select type(this)
    class is(SolvingStrategyDT)
       call debugLog('  *** Transient Strategy ***')
       print'(A)', '*** Transient Strategy ***'
       nNode = this%application%model%getnNode()
       call allocateMass(nNode)
       call allocateStabMat(4,nNode)
       allocate(this%process, source = WriteOutput)
       allocate(oldDof(4*nNode))
       this%scheme           = SetScheme(scheme)
       this%builderAndSolver = SetBuilderAndSolver(builderAndSolver)
       printStep = this%application%model%processInfo%getPrintStep()
       errorTol  = this%application%model%processInfo%getErrorTol()
       maxIter   = this%application%model%processInfo%getMaxIter()
       error     = errorTol+1
       error1    = errorTol+1
       error2    = 1._rkind
       step1     = this%application%model%processInfo%getStep()
       step2     = step1 + printStep
       t         = this%application%model%processInfo%getTime()
       call calculateMass(this%application)
       if(step1 == 0) then
          call writeOutput%initPrintFile()
       else
          call writeOutput%restartPrintFile()
       end if
       call builderAndSolver%applyDirichlet(this%application)
       do while (step1 < maxIter .and. error > errorTol)
          step1  = step1 + 1
          call calculateDT(this%application)
          dtMin  = this%application%model%processInfo%getDT()
          t      = t + dtmin
          oldDof = this%application%model%dof
          call this%application%model%processInfo%setStep(step1)
          call builderAndSolver%build(this%application)
          navierStokes2D = SetNavierStokes2D &
               (this%application%model%dof, this%application%model%rhs, ExplicitEuler, step1)
          call navierStokes2D%integrate(dtMin, multi_step)
          this%application%model%dof = navierStokes2D%getState()
          if (step1 == step2 .or. step1 == maxIter) then
             error1 = 0._rkind
             error2 = 0._rkind
             do iNode = 1, nNode
                do iDof = 1, 4
                   error1(iDof) = error1(iDof) &
                        + (this%application%model%dof(iNode*4-(4-iDof)) - oldDof(iNode*4-(4-iDof)))**2
                   error2(iDof) = error2(iDof) &
                        + oldDof(iNode*4-(4-iDof))**2
                end do
             end do
             error = maxval(sqrt(error1/error2))
             if (error >= 1.d2) then
                call debugLog('CONVERGENCE ERROR')
                print'(A)', 'CONVERGENCE ERROR'
                stop
             end if
             call scheme%calculateOutputs(this%application)
             call writeOutput%print(step1, this%application%model%results%density          &
                  , this%application%model%results%internalEnergy                          &
                  , this%application%model%results%mach                                    &
                  , this%application%model%results%pressure                                &
                  , this%application%model%results%temperature                             &
                  , this%application%model%results%velocity                                )
             call writeRestart%print(step1, nNode, t, this%application%model%dof)
             call debugLog('::::::::::::::::::::::::::::::::::::::::')
             call debugLog('Step     : ', step1)
             call debugLog('Error Ec. de Continuidad  = ', sqrt(error1(1)/error2(1)))
             call debugLog('Error Ec. de Momento x    = ', sqrt(error1(2)/error2(2)))
             call debugLog('Error Ec. de Momento y    = ', sqrt(error1(3)/error2(3)))
             call debugLog('Error Ec. de Energia      = ', sqrt(error1(4)/error2(4)))
             call debugLog('t        : ', t)
             call debugLog('dt       : ', dtMin)
             call debugLog('Mach Max = ', maxval(this%application%model%results%mach))
             call debugLog('::::::::::::::::::::::::::::::::::::::::')
             print'(A40)'      , '::::::::::::::::::::::::::::::::::::::::' 
             print'(A11,I10   )', 'Step     : ', step1
             print'(A29,E10.3)', 'Error Ec. de Continuidad  = ', sqrt(error1(1)/error2(1))
             print'(A29,E10.3)', 'Error Ec. de Momento x    = ', sqrt(error1(2)/error2(2))
             print'(A29,E10.3)', 'Error Ec. de Momento y    = ', sqrt(error1(3)/error2(3))
             print'(A29,E10.3)', 'Error Ec. de Energia      = ', sqrt(error1(4)/error2(4))
             print'(A11,E10.3)', 't        : ', t
             print'(A11,E10.3)', 'dt       : ', dtMin
             print'(A11,E10.3)', 'Mach Max = ', maxval(this%application%model%results%mach)
             print'(A40)'      , '::::::::::::::::::::::::::::::::::::::::' 
             step2 = step2 + printStep
          end if
          call builderAndSolver%applyDirichlet(this%application)
       end do
       call debugLog('*** Finished Integration ***')
       print'(A)', '*** Finished Integration ***'
    class default
       stop 'strategy: unsupported class.'
    end select
  end subroutine CFDStrategy

  subroutine calculateMass(app)
    implicit none
    type(CFDApplicationDT), intent(inout) :: app
    integer(ikind)                        :: iElem, nElem
    nElem = app%model%getnElement()
    do iElem = 1, nElem
       call app%element(iElem)%calculateMass()
    end do
!!$    write(11,*) '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%'
!!$    write(11,*) '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%'
!!$    write(11,*) 'mass'
!!$    write(11,*) '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%'
!!$    write(11,*) '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%'
!!$    do iElem = 1, app%model%getnNode()
!!$       write(11,'(A,I0,A,E16.8)') 'mass(', iElem, ') = ', lumpedMass(iElem)
!!$    end do
  end subroutine calculateMass

  subroutine calculateDT(app)
    implicit none
    type(CFDApplicationDT), intent(inout) :: app
    integer(ikind)                        :: iElem, nElem
    call app%model%processInfo%freeDT()
    nElem = app%model%getnElement()
    do iElem = 1, nElem
       call app%element(iElem)%calculateDT(app%model%processInfo)
    end do
  end subroutine calculateDT

end module CFDStrategyM
