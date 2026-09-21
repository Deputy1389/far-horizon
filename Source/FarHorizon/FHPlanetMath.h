#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "FHPlanetMath.generated.h"

UCLASS()
class FARHORIZON_API UFHPlanetMath : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()

public:
    UFUNCTION(BlueprintPure, Category="Far Horizon|Planet")
    static FVector RadialUp(const FVector& WorldPosition, const FVector& PlanetCenter);

    UFUNCTION(BlueprintPure, Category="Far Horizon|Planet")
    static double AltitudeAboveSphere(const FVector& WorldPosition, const FVector& PlanetCenter, double PlanetRadius);
};
