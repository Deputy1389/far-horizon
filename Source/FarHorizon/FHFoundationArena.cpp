#include "FHFoundationArena.h"

#include "FHEnemyCharacter.h"
#include "Components/BoxComponent.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Components/SkyLightComponent.h"
#include "Engine/DirectionalLight.h"
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

    // 50m x 50m floor, with enough cover to immediately exercise lateral AI.
    SpawnBox(FVector(0.0, 0.0, -50.0), FVector(50.0, 50.0, 1.0));

    SpawnBox(FVector(350.0, 500.0, 100.0), FVector(2.0, 0.8, 2.0));
    SpawnBox(FVector(350.0, -500.0, 100.0), FVector(2.0, 0.8, 2.0));
    SpawnBox(FVector(950.0, 150.0, 75.0), FVector(1.2, 2.4, 1.5));
    SpawnBox(FVector(1450.0, -450.0, 125.0), FVector(2.5, 0.8, 2.5));
    SpawnBox(FVector(-450.0, 800.0, 100.0), FVector(0.8, 2.5, 2.0));
    SpawnBox(FVector(-650.0, -650.0, 125.0), FVector(2.2, 0.8, 2.5));

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
    Mesh->SetMobility(EComponentMobility::Static);
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

    ADirectionalLight* Sun = World->SpawnActor<ADirectionalLight>(
        FVector::ZeroVector,
        FRotator(-48.0f, -35.0f, 0.0f));

    if (Sun && Sun->GetLightComponent())
    {
        Sun->GetLightComponent()->SetIntensity(6.0f);
        Sun->GetLightComponent()->SetLightColor(FLinearColor(1.0f, 0.92f, 0.78f));
    }

    ASkyLight* Sky = World->SpawnActor<ASkyLight>();
    if (Sky && Sky->GetLightComponent())
    {
        Sky->GetLightComponent()->SetIntensity(0.65f);
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
