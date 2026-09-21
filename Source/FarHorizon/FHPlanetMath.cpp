#include "FHPlanetMath.h"

FVector UFHPlanetMath::RadialUp(const FVector& WorldPosition, const FVector& PlanetCenter)
{
    return (WorldPosition - PlanetCenter).GetSafeNormal();
}

double UFHPlanetMath::AltitudeAboveSphere(const FVector& WorldPosition, const FVector& PlanetCenter, double PlanetRadius)
{
    return FVector::Distance(WorldPosition, PlanetCenter) - PlanetRadius;
}
