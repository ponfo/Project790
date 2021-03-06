module PrintM

  use UtilitiesM
  
  use GIDDataOutputM

  use ProcessM
  
  implicit none

  private
  public :: PrintDT

  type, extends(NewProcessDT) :: PrintDT
   contains
     procedure :: initPrintFile
     procedure :: restartPrintFile
     procedure :: print
  end type PrintDT

contains

  subroutine initPrintFile(this)
    implicit none
    class(PrintDT), intent(inout) :: this
    call initDataOutput()
  end subroutine initPrintFile

  subroutine restartPrintFile(this)
    implicit none
    class(PrintDT), intent(inout) :: this
    call openDataOutput()
  end subroutine restartPrintFile
  
  subroutine print(this, step, density, internalEnergy&
       , mach, pressure, temperature, velocity        )
    implicit none
    class(PrintDT)             , intent(inout) :: this
    real(rkind), dimension(:,:), intent(inout) :: velocity
    real(rkind), dimension(:)  , intent(inout) :: density
    real(rkind), dimension(:)  , intent(inout) :: internalEnergy
    real(rkind), dimension(:)  , intent(inout) :: mach
    real(rkind), dimension(:)  , intent(inout) :: pressure
    real(rkind), dimension(:)  , intent(inout) :: Temperature
    integer(ikind)             , intent(inout) :: step
    call printResults(resultName = 'Density'          &
         , step         = step                        &
         , graphType    = 'Scalar'                    &
         , locationName = 'onNodes'                   &
         , resultNumber = size(density)               &
         , component1   = density                     )
    call printResults(resultName = 'Internal Energy'  &
         , step         = step                        &
         , graphType    = 'Scalar'                    &
         , locationName = 'onNodes'                   &
         , resultNumber = size(internalEnergy)        &
         , component1   = internalEnergy              )
    call printResults(resultName = 'Mach'             &
         , step         = step                        &
         , graphType    = 'Scalar'                    &
         , locationName = 'onNodes'                   &
         , resultNumber = size(mach)                  &
         , component1   = mach                        )
    call printResults(resultName = 'Pressure'         &
         , step         = step                        &
         , graphType    = 'Scalar'                    &
         , locationName = 'onNodes'                   &
         , resultNumber = size(pressure)              &
         , component1   = pressure                    )
    call printResults(resultName = 'Temperature'      &
         , step         = step                        &
         , graphType    = 'Scalar'                    &
         , locationName = 'onNodes'                   &
         , resultNumber = size(temperature)           &
         , component1   = temperature                 )
    call printResults(resultName = 'Velocity'         &
         , step         = step                        &
         , graphType    = 'Vector'                    &
         , locationName = 'onNodes'                   &
         , resultNumber = size(velocity(:,1))         &
         , component1   = velocity(:,1)               &
         , component2   = velocity(:,2)               )
  end subroutine print
  
end module PrintM
