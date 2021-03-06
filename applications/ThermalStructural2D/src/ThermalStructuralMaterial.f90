module StructuralMaterialM
  use UtilitiesM
  use PropertyM

  use ThermalMaterialM

  implicit none

  private
  public :: StructuralMaterialDT, thermalStructuralMaterial

  type, extends(ThermalMaterialDT) :: StructuralMaterialDT
     real(rkind) :: young
     real(rkind) :: poissonCoef
     real(rkind) :: thermalCoef
     real(rkind) :: area
     real(rkind) :: thickness
     real(rkind) :: d11, d12, d21, d22, d33
     real(rkind) :: stableTemp
   contains
     procedure :: initThermalStructMat
  end type StructuralMaterialDT

  interface thermalStructuralMaterial
     procedure :: constructor
  end interface thermalStructuralMaterial

contains

  type(StructuralMaterialDT) function constructor &
       (kx, ky, young, poissonCoef, thermalCoef, area, thickness, stableTemp)
    implicit none
    real(rkind), intent(in) :: kx
    real(rkind), intent(in) :: ky
    real(rkind), intent(in) :: young
    real(rkind), intent(in) :: poissonCoef
    real(rkind), intent(in) :: thermalCoef
    real(rkind), intent(in) :: area
    real(rkind), intent(in) :: thickness
    real(rkind), intent(in) :: stableTemp
    call constructor%initThermalStructMat &
         (kx, ky, young, poissonCoef, thermalCoef, area, thickness, stableTemp)
  end function constructor

  subroutine initThermalStructMat &
       (this, kx, ky, young, poissonCoef, thermalCoef, area, thickness, stableTemp)
    implicit none
    class(StructuralMaterialDT), intent(inout) :: this
    real(rkind)                , intent(in)    :: kx
    real(rkind)                , intent(in)    :: ky
    real(rkind)                , intent(in)    :: young
    real(rkind)                , intent(in)    :: poissonCoef
    real(rkind)                , intent(in)    :: thermalCoef
    real(rkind)                , intent(in)    :: area
    real(rkind)                , intent(in)    :: thickness
    real(rkind)                , intent(in)    :: stableTemp
    real(rkind)                                :: factor
    this%conductivity = (/kx, ky/)
    this%young        = young
    this%poissonCoef  = poissonCoef
    this%thermalCoef  = thermalCoef
    this%area         = area
    this%thickness    = thickness
    this%stableTemp   = stableTemp
    !Deformación plana:
    factor = young/((1+poissonCoef)*(1-2*poissonCoef))
    this%d11 = factor*(1-poissonCoef)
    this%d12 = factor*poissonCoef
    this%d21 = factor*poissonCoef
    this%d22 = factor*(1-poissonCoef)
    this%d33 = factor*(1-2*poissonCoef)/2.d0
    !Tensión plana
!!$    factor = young/(1-poissonCoef**2)
!!$    this%d11 = factor
!!$    this%d12 = factor*poissonCoef
!!$    this%d21 = factor*poissonCoef
!!$    this%d22 = factor
!!$    this%d33 = factor*(1-poissonCoef)/2.d0
  end subroutine initThermalStructMat
  
end module StructuralMaterialM
    
    
     
