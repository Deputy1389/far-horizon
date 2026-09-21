#include "FHBlasterComponent.h"

#include "DrawDebugHelpers.h"
#include "Engine/World.h"
#include "GameFramework/Controller.h"
#include "Kismet/GameplayStatics.h"

UFHBlasterComponent::UFHBlasterComponent()
{
    PrimaryComponentTick.bCanEverTick = false;
}

FVector UFHBlasterComponent::ComputeDirectionToAimPoint(
    const FVector& MuzzleLocation,
    const FVector& AimPoint)
{
    return (AimPoint - MuzzleLocation).GetSafeNormal();
}

bool UFHBlasterComponent::TryFire(
    const FVector& ViewLocation,
    const FVector& ViewDirection,
    const FVector& MuzzleLocation,
    AController* InstigatorController,
    FFHBlasterShotResult* OutResult)
{
    UWorld* World = GetWorld();
    if (!World)
    {
        return false;
    }

    const double Now = World->GetTimeSeconds();
    const double FireInterval = 1.0 / FMath::Max(0.1f, RoundsPerSecond);
    if (Now < NextAllowedFireTime)
    {
        return false;
    }
    NextAllowedFireTime = Now + FireInterval;

    FCollisionQueryParams QueryParams(SCENE_QUERY_STAT(FarHorizonBlaster), true);
    QueryParams.AddIgnoredActor(GetOwner());

    const FVector SafeViewDirection = ViewDirection.GetSafeNormal();
    const FVector ViewEnd = ViewLocation + SafeViewDirection * Range;

    FHitResult ViewHit;
    const bool bViewHit = World->LineTraceSingleByChannel(
        ViewHit,
        ViewLocation,
        ViewEnd,
        ECC_Visibility,
        QueryParams);

    const FVector AimPoint = bViewHit ? ViewHit.ImpactPoint : ViewEnd;
    const FVector MuzzleDirection = ComputeDirectionToAimPoint(MuzzleLocation, AimPoint);
    const FVector MuzzleEnd = MuzzleLocation + MuzzleDirection * Range;

    FHitResult MuzzleHit;
    const bool bMuzzleHit = World->LineTraceSingleByChannel(
        MuzzleHit,
        MuzzleLocation,
        MuzzleEnd,
        ECC_Visibility,
        QueryParams);

    const FVector ImpactPoint = bMuzzleHit ? MuzzleHit.ImpactPoint : MuzzleEnd;

    if (bMuzzleHit && MuzzleHit.GetActor())
    {
        UGameplayStatics::ApplyPointDamage(
            MuzzleHit.GetActor(),
            Damage,
            MuzzleDirection,
            MuzzleHit,
            InstigatorController,
            GetOwner(),
            nullptr);
    }

    if (bDrawDebugShot)
    {
        DrawDebugLine(World, ViewLocation, AimPoint, FColor::Cyan, false, 0.12f, 0, 0.75f);
        DrawDebugLine(World, MuzzleLocation, ImpactPoint, FColor::Yellow, false, 0.12f, 0, 1.25f);
    }

    if (OutResult)
    {
        OutResult->bHit = bMuzzleHit;
        OutResult->AimPoint = AimPoint;
        OutResult->ImpactPoint = ImpactPoint;
        OutResult->HitActor = bMuzzleHit ? MuzzleHit.GetActor() : nullptr;
    }

    return true;
}
