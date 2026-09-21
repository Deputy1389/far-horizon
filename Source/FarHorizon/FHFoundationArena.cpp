#include "FHFoundationArena.h"

#include "FHEnemyCharacter.h"
#include "Components/BoxComponent.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/ExponentialHeightFogComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Components/SkyAtmosphereComponent.h"
#include "Components/SkyLightComponent.h"
#include "Engine/DirectionalLight.h"
#include "Engine/ExponentialHeightFog.h"
#include "Engine/SkyLight.h"
#include "Engine/StaticMeshActor.h"
#include "Engine/World.h"
#include "NavMesh/NavMeshBoundsVolume.h"
#include "NavigationSystem.h"

AFHFoundationArena::AFHFoundationArena()
{
    PrimaryActorTick.bCanEverTick = false;

    CubeMesh = LoadObject<UStaticMesh>(
        nullptr,
        TEXT("/Engine/BasicShapes/Cube.Cube"));
}

void AFHFoundationArena::BeginPlay()
{
    Super::BeginPlay();

    if (!CubeMesh)
    {
        UE_LOG(LogTemp, Error, TEXT("Far Horizon foundation arena could not load the engine cube mesh."));
        return;
    }

    // Deliberately readable greybox combat space: a central lane, broken cover,
    // flanking routes and elevated silhouettes. This remains a systems harness,
    // but it should feel like a place rather than an empty light-test box.
    SpawnBox(FVector(0.0, 0.0, -50.0), FVector(55.0, 45.0, 1.0));

    // Outer perimeter / skyline breaks.
    SpawnBox(FVector(0.0, 4300.0, 350.0), FVector(55.0, 2.0, 8.0));
    SpawnBox(FVector(0.0, -4300.0, 350.0), FVector(55.0, 2.0, 8.0));
    SpawnBox(FVector(5200.0, 0.0, 350.0), FVector(2.0, 45.0, 8.0));
    SpawnBox(FVector(-5200.0, 0.0, 350.0), FVector(2.0, 45.0, 8.0));

    // Near cover.
    SpawnBox(FVector(-700.0, 520.0, 90.0), FVector(1.8, 0.7, 1.8));
    SpawnBox(FVector(-450.0, -650.0, 120.0), FVector(0.7, 2.4, 2.4));
    SpawnBox(FVector(100.0, 850.0, 140.0), FVector(2.6, 0.8, 2.8));
    SpawnBox(FVector(300.0, -950.0, 100.0), FVector(2.0, 0.7, 2.0));

    // Mid-field fighting positions.
    SpawnBox(FVector(900.0, 180.0, 85.0), FVector(1.1, 2.8, 1.7));
    SpawnBox(FVector(1350.0, 700.0, 125.0), FVector(2.6, 0.75, 2.5));
    SpawnBox(FVector(1500.0, -700.0, 125.0), FVector(2.6, 0.75, 2.5));
    SpawnBox(FVector(2050.0, 0.0, 60.0), FVector(1.3, 3.6, 1.2));

    // Raised flank platforms and crude ramps.
    SpawnBox(FVector(400.0, 1900.0, 190.0), FVector(4.0, 5.0, 0.5));
    SpawnBox(FVector(400.0, 1450.0, 90.0), FVector(4.0, 2.4, 0.35), FRotator(18.0, 0.0, 0.0));
    SpawnBox(FVector(1000.0, -1900.0, 220.0), FVector(4.5, 4.0, 0.5));
    SpawnBox(FVector(650.0, -1500.0, 105.0), FVector(3.5, 2.2, 0.35), FRotator(-18.0, 0.0, 0.0));

    // Distant vertical landmarks so orientation is immediate.
    SpawnBox(FVector(3000.0, 1800.0, 700.0), FVector(3.5, 3.5, 14.0));
    SpawnBox(FVector(3300.0, -1700.0, 500.0), FVector(2.5, 2.5, 10.0));
    SpawnBox(FVector(-2600.0, 2100.0, 600.0), FVector(3.0, 3.0, 12.0));

    SpawnLighting();
    SpawnNavigationBounds();
    SpawnEnemy();
}

void AFHFoundationArena::SpawnBox(
    const FVector& Location,
    const FVector& Scale,
    const FRotator& Rotation)
{
    UWorld* World = GetWorld();
    if (!World || !CubeMesh)
    {
        return;
    }

    FActorSpawnParameters Params;
    Params.SpawnCollisionHandlingOverride =
        ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

    AStaticMeshActor* Box = World->SpawnActor<AStaticMeshActor>(
        Location,
        Rotation,
        Params);

    if (!Box)
    {
        return;
    }

    UStaticMeshComponent* Mesh = Box->GetStaticMeshComponent();
    Mesh->SetMobility(EComponentMobility::Movable);
    Mesh->SetStaticMesh(CubeMesh);
    Mesh->SetCollisionProfileName(TEXT("BlockAll"));
    Mesh->SetCanEverAffectNavigation(true);

    Box->SetActorScale3D(Scale);
}

void AFHFoundationArena::SpawnLighting()
{
    UWorld* World = GetWorld();
    if (!World)
    {
        return;
    }

    USkyAtmosphereComponent* Atmosphere =
        NewObject<USkyAtmosphereComponent>(this, TEXT("RuntimeSkyAtmosphere"));
    if (Atmosphere)
    {
        Atmosphere->SetMobility(EComponentMobility::Movable);
        Atmosphere->RegisterComponent();
    }

    ADirectionalLight* Sun = World->SpawnActor<ADirectionalLight>(
        FVector::ZeroVector,
        FRotator(-34.0f, -42.0f, 0.0f));

    if (Sun)
    {
        if (UDirectionalLightComponent* SunComponent =
            Cast<UDirectionalLightComponent>(Sun->GetLightComponent()))
        {
            SunComponent->SetMobility(EComponentMobility::Movable);
            SunComponent->SetIntensity(7.5f);
            SunComponent->SetLightColor(FLinearColor(1.0f, 0.82f, 0.62f));
            SunComponent->SetAtmosphereSunLight(true);
            SunComponent->SetAtmosphereSunLightIndex(0);
            SunComponent->SetDynamicShadowDistanceMovableLight(12000.0f);
        }
    }

    ASkyLight* Sky = World->SpawnActor<ASkyLight>();
    if (Sky && Sky->GetLightComponent())
    {
        Sky->GetLightComponent()->SetMobility(EComponentMobility::Movable);
        Sky->GetLightComponent()->SetIntensity(0.9f);
        Sky->GetLightComponent()->SetRealTimeCaptureEnabled(true);
    }

    AExponentialHeightFog* Fog = World->SpawnActor<AExponentialHeightFog>();
    if (Fog && Fog->GetComponent())
    {
        Fog->GetComponent()->SetMobility(EComponentMobility::Movable);
        Fog->GetComponent()->SetFogDensity(0.006f);
        Fog->GetComponent()->SetFogHeightFalloff(0.18f);
        Fog->GetComponent()->SetStartDistance(1200.0f);
        Fog->GetComponent()->SetVolumetricFog(true);
    }
}

void AFHFoundationArena::SpawnNavigationBounds()
{
    UWorld* World = GetWorld();
    if (!World)
    {
        return;
    }

    FActorSpawnParameters Params;
    Params.SpawnCollisionHandlingOverride =
        ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

    ANavMeshBoundsVolume* NavBounds =
        World->SpawnActor<ANavMeshBoundsVolume>(
            FVector(0.0, 0.0, 250.0),
            FRotator::ZeroRotator,
            Params);

    if (!NavBounds)
    {
        return;
    }

    UBoxComponent* BoundsBox = NewObject<UBoxComponent>(
        NavBounds,
        TEXT("FarHorizonRuntimeNavBounds"));

    BoundsBox->SetBoxExtent(FVector(2800.0, 2800.0, 600.0));
    BoundsBox->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    BoundsBox->SetCanEverAffectNavigation(false);
    BoundsBox->RegisterComponent();
    BoundsBox->AttachToComponent(
        NavBounds->GetRootComponent(),
        FAttachmentTransformRules::KeepRelativeTransform);

    if (UNavigationSystemV1* Navigation =
        FNavigationSystem::GetCurrent<UNavigationSystemV1>(World))
    {
        Navigation->OnNavigationBoundsUpdated(NavBounds);
    }
}

void AFHFoundationArena::SpawnEnemy()
{
    UWorld* World = GetWorld();
    if (!World)
    {
        return;
    }

    FActorSpawnParameters Params;
    Params.SpawnCollisionHandlingOverride =
        ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;

    World->SpawnActor<AFHEnemyCharacter>(
        FVector(1500.0, 250.0, 110.0),
        FRotator(0.0f, 180.0f, 0.0f),
        Params);
}
