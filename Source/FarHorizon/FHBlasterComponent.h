#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "FHBlasterComponent.generated.h"

class AController;

USTRUCT(BlueprintType)
struct FFHBlasterShotResult
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly)
    bool bHit = false;

    UPROPERTY(BlueprintReadOnly)
    FVector AimPoint = FVector::ZeroVector;

    UPROPERTY(BlueprintReadOnly)
    FVector ImpactPoint = FVector::ZeroVector;

    UPROPERTY(BlueprintReadOnly)
    TObjectPtr<AActor> HitActor = nullptr;
};

UCLASS(ClassGroup=(FarHorizon), meta=(BlueprintSpawnableComponent))
class FARHORIZON_API UFHBlasterComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UFHBlasterComponent();

    bool TryFire(
        const FVector& ViewLocation,
        const FVector& ViewDirection,
        const FVector& MuzzleLocation,
        AController* InstigatorController,
        FFHBlasterShotResult* OutResult = nullptr);

    static FVector ComputeDirectionToAimPoint(
        const FVector& MuzzleLocation,
        const FVector& AimPoint);

    UPROPERTY(EditDefaultsOnly, BlueprintReadWrite, Category="Blaster")
    float Range = 100000.0f;

    UPROPERTY(EditDefaultsOnly, BlueprintReadWrite, Category="Blaster")
    float Damage = 20.0f;

    UPROPERTY(EditDefaultsOnly, BlueprintReadWrite, Category="Blaster", meta=(ClampMin="0.1"))
    float RoundsPerSecond = 8.0f;

    UPROPERTY(EditDefaultsOnly, BlueprintReadWrite, Category="Blaster|Debug")
    bool bDrawDebugShot = false;

private:
    double NextAllowedFireTime = 0.0;
};
