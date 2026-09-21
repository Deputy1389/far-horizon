#include "FHFrontierWorld.h"

#include "FHEnemyCharacter.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/ExponentialHeightFogComponent.h"
#include "Components/HierarchicalInstancedStaticMeshComponent.h"
#include "Components/SceneComponent.h"
#include "Components/SkyAtmosphereComponent.h"
#include "Components/SkyLightComponent.h"
#include "Engine/DirectionalLight.h"
#include "Engine/ExponentialHeightFog.h"
#include "Engine/SkyLight.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "Materials/MaterialInterface.h"
#include "NavMesh/NavMeshBoundsVolume.h"
#include "NavigationSystem.h"

AFHFrontierWorld::AFHFrontierWorld()
    : RandomStream(1389)
{
    PrimaryActorTick.bCanEverTick = false;

    SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
    SetRootComponent(SceneRoot);

    CubeMesh = LoadObject<UStaticMesh>(
        nullptr,
        TEXT("/Engine/BasicShapes/Cube.Cube"));

    CylinderMesh = LoadObject<UStaticMesh>(
        nullptr,
        TEXT("/Engine/BasicShapes/Cylinder.Cylinder"));

    SphereMesh = LoadObject<UStaticMesh>(
        nullptr,
        TEXT("/Engine/BasicShapes/Sphere.Sphere"));

    auto CreateInstances = [this](
        const TCHAR* Name,
        UStaticMesh* Mesh,
        UMaterialInterface* Material,
        bool bCollision)
    {
        UHierarchicalInstancedStaticMeshComponent* Component =
            CreateDefaultSubobject<UHierarchicalInstancedStaticMeshComponent>(Name);

        Component->SetupAttachment(SceneRoot);
        Component->SetStaticMesh(Mesh);
        Component->SetMobility(EComponentMobility::Movable);
        Component->SetCollisionProfileName(
            bCollision ? TEXT("BlockAll") : TEXT("NoCollision"));
        Component->SetCollisionEnabled(
            bCollision
                ? ECollisionEnabled::QueryAndPhysics
                : ECollisionEnabled::NoCollision);
        Component->SetCanEverAffectNavigation(bCollision);
        Component->SetCastShadow(true);

        if (Material)
        {
            Component->SetMaterial(0, Material);
        }

        return Component;
    };

    UMaterialInterface* Sand = LoadLocalMaterial(
        TEXT("/Game/FarHorizon/LocalSWG/Materials/M_SWG_Sand.M_SWG_Sand"));
    UMaterialInterface* Road = LoadLocalMaterial(
        TEXT("/Game/FarHorizon/LocalSWG/Materials/M_SWG_Road.M_SWG_Road"));
    UMaterialInterface* Wall = LoadLocalMaterial(
        TEXT("/Game/FarHorizon/LocalSWG/Materials/M_SWG_Wall.M_SWG_Wall"));
    UMaterialInterface* CapitalWall = LoadLocalMaterial(
        TEXT("/Game/FarHorizon/LocalSWG/Materials/M_SWG_CapitalWall.M_SWG_CapitalWall"));
    UMaterialInterface* Concrete = LoadLocalMaterial(
        TEXT("/Game/FarHorizon/LocalSWG/Materials/M_SWG_Concrete.M_SWG_Concrete"));
    UMaterialInterface* Metal = LoadLocalMaterial(
        TEXT("/Game/FarHorizon/LocalSWG/Materials/M_SWG_Metal.M_SWG_Metal"));
    UMaterialInterface* Pad = LoadLocalMaterial(
        TEXT("/Game/FarHorizon/LocalSWG/Materials/M_SWG_Pad.M_SWG_Pad"));

    SandInstances =
        CreateInstances(TEXT("Sand"), CubeMesh, Sand, true);

    DuneInstances =
        CreateInstances(TEXT("Dunes"), SphereMesh, Sand, false);

    RoadInstances =
        CreateInstances(TEXT("Roads"), CubeMesh, Road, true);

    WallInstances =
        CreateInstances(TEXT("Walls"), CubeMesh, Wall, true);

    CapitalWallInstances =
        CreateInstances(TEXT("CapitalWalls"), CubeMesh, CapitalWall, true);

    ConcreteInstances =
        CreateInstances(TEXT("Concrete"), CubeMesh, Concrete, true);

    MetalInstances =
        CreateInstances(TEXT("Metal"), CubeMesh, Metal, true);

    DomeInstances =
        CreateInstances(TEXT("Domes"), SphereMesh, CapitalWall, false);

    LandingPadInstances =
        CreateInstances(TEXT("LandingPads"), CylinderMesh, Pad, true);

    AntennaInstances =
        CreateInstances(TEXT("Antennas"), CylinderMesh, Metal, false);

    UStaticMesh* LocalVaporator = LoadObject<UStaticMesh>(
        nullptr,
        TEXT("/Game/FarHorizon/LocalSWG/Models/SM_SWG_MoistureVaporator.SM_SWG_MoistureVaporator"));

    VaporatorInstances =
        CreateInstances(
            TEXT("LocalSWGVaporators"),
            LocalVaporator ? LocalVaporator : CylinderMesh,
            Metal,
            true);
}

UMaterialInterface* AFHFrontierWorld::LoadLocalMaterial(
    const TCHAR* AssetPath) const
{
    return LoadObject<UMaterialInterface>(nullptr, AssetPath);
}

void AFHFrontierWorld::BeginPlay()
{
    Super::BeginPlay();

    BuildEnvironment();
    BuildRoadNetwork();
    BuildCity();
    BuildStarport();
    BuildOutskirts();
    BuildLighting();
    BuildNavigation();
    SpawnCombatPopulation();

    UE_LOG(
        LogTemp,
        Display,
        TEXT("FAR_HORIZON_FRONTIER_READY seed=1389 cityRadiusMeters=%.0f buildings=%d"),
        CityRadius / 100.0f,
        WallInstances->GetInstanceCount() +
            CapitalWallInstances->GetInstanceCount() +
            ConcreteInstances->GetInstanceCount());
}

void AFHFrontierWorld::AddBox(
    UHierarchicalInstancedStaticMeshComponent* Component,
    const FVector& Location,
    const FVector& SizeCm,
    const FRotator& Rotation)
{
    if (!Component || !CubeMesh)
    {
        return;
    }

    Component->AddInstance(
        FTransform(
            Rotation,
            Location,
            FVector(
                SizeCm.X / 100.0f,
                SizeCm.Y / 100.0f,
                SizeCm.Z / 100.0f)));
}

void AFHFrontierWorld::AddCylinder(
    UHierarchicalInstancedStaticMeshComponent* Component,
    const FVector& Location,
    const FVector& SizeCm,
    const FRotator& Rotation)
{
    if (!Component || !CylinderMesh)
    {
        return;
    }

    Component->AddInstance(
        FTransform(
            Rotation,
            Location,
            FVector(
                SizeCm.X / 100.0f,
                SizeCm.Y / 100.0f,
                SizeCm.Z / 100.0f)));
}

void AFHFrontierWorld::AddSphere(
    UHierarchicalInstancedStaticMeshComponent* Component,
    const FVector& Location,
    const FVector& SizeCm,
    const FRotator& Rotation)
{
    if (!Component || !SphereMesh)
    {
        return;
    }

    Component->AddInstance(
        FTransform(
            Rotation,
            Location,
            FVector(
                SizeCm.X / 100.0f,
                SizeCm.Y / 100.0f,
                SizeCm.Z / 100.0f)));
}

void AFHFrontierWorld::BuildEnvironment()
{
    AddBox(
        SandInstances,
        FVector(0.0f, 0.0f, -90.0f),
        FVector(
            GroundHalfExtent * 2.0f,
            GroundHalfExtent * 2.0f,
            160.0f));

    for (int32 Index = 0; Index < 85; ++Index)
    {
        const float Angle =
            RandomStream.FRandRange(0.0f, UE_TWO_PI);

        const float Radius =
            RandomStream.FRandRange(
                CityRadius * 0.75f,
                GroundHalfExtent * 0.78f);

        const float Diameter =
            RandomStream.FRandRange(9000.0f, 28000.0f);

        const float Height =
            RandomStream.FRandRange(500.0f, 1800.0f);

        AddSphere(
            DuneInstances,
            FVector(
                FMath::Cos(Angle) * Radius,
                FMath::Sin(Angle) * Radius,
                -Height * 0.26f),
            FVector(Diameter, Diameter * 0.65f, Height),
            FRotator(
                0.0f,
                RandomStream.FRandRange(0.0f, 360.0f),
                0.0f));
    }
}

void AFHFrontierWorld::BuildRoadNetwork()
{
    constexpr float MainRoadWidth = 2600.0f;
    constexpr float SideRoadWidth = 1200.0f;
    constexpr float RoadThickness = 18.0f;
    const float RoadLength = CityRadius * 2.35f;

    AddBox(
        RoadInstances,
        FVector(0.0f, 0.0f, 5.0f),
        FVector(RoadLength, MainRoadWidth, RoadThickness));

    AddBox(
        RoadInstances,
        FVector(0.0f, 0.0f, 5.0f),
        FVector(MainRoadWidth, RoadLength, RoadThickness));

    for (int32 Grid = -7; Grid <= 7; ++Grid)
    {
        if (Grid == 0)
        {
            continue;
        }

        const float Offset = Grid * CityCell;

        AddBox(
            RoadInstances,
            FVector(Offset, 0.0f, 4.0f),
            FVector(SideRoadWidth, RoadLength, RoadThickness));

        AddBox(
            RoadInstances,
            FVector(0.0f, Offset, 4.0f),
            FVector(RoadLength, SideRoadWidth, RoadThickness));
    }

    // Two diagonal arterials keep the city from reading as a pure square grid.
    AddBox(
        RoadInstances,
        FVector(0.0f, 0.0f, 7.0f),
        FVector(RoadLength * 0.94f, 1500.0f, RoadThickness),
        FRotator(0.0f, 31.0f, 0.0f));

    AddBox(
        RoadInstances,
        FVector(0.0f, 0.0f, 7.0f),
        FVector(RoadLength * 0.86f, 1450.0f, RoadThickness),
        FRotator(0.0f, -37.0f, 0.0f));
}

void AFHFrontierWorld::BuildBuilding(
    const FVector& Location,
    float Width,
    float Depth,
    float Height,
    float Yaw,
    float Density)
{
    UHierarchicalInstancedStaticMeshComponent* Facade =
        Density > 0.58f && RandomStream.FRand() > 0.48f
            ? CapitalWallInstances
            : WallInstances;

    AddBox(
        Facade,
        FVector(Location.X, Location.Y, Height * 0.5f),
        FVector(Width, Depth, Height),
        FRotator(0.0f, Yaw, 0.0f));

    const bool bRoundRoof =
        RandomStream.FRand() < (0.30f + Density * 0.18f);

    if (bRoundRoof)
    {
        const float DomeDiameter =
            FMath::Min(Width, Depth) * RandomStream.FRandRange(0.55f, 0.88f);

        AddSphere(
            DomeInstances,
            FVector(
                Location.X,
                Location.Y,
                Height + DomeDiameter * 0.12f),
            FVector(
                DomeDiameter,
                DomeDiameter,
                DomeDiameter * 0.52f));
    }
    else if (RandomStream.FRand() > 0.28f)
    {
        const float UpperHeight =
            RandomStream.FRandRange(260.0f, 900.0f) *
            (1.0f + Density);

        AddBox(
            ConcreteInstances,
            FVector(
                Location.X + RandomStream.FRandRange(-Width * 0.12f, Width * 0.12f),
                Location.Y + RandomStream.FRandRange(-Depth * 0.12f, Depth * 0.12f),
                Height + UpperHeight * 0.5f),
            FVector(
                Width * RandomStream.FRandRange(0.34f, 0.68f),
                Depth * RandomStream.FRandRange(0.34f, 0.68f),
                UpperHeight),
            FRotator(0.0f, Yaw, 0.0f));
    }

    // Dark metal doorway / service panel.
    const float DoorHeight = FMath::Min(360.0f, Height * 0.42f);
    AddBox(
        MetalInstances,
        FVector(
            Location.X + Width * 0.50f,
            Location.Y,
            DoorHeight * 0.5f),
        FVector(24.0f, 180.0f, DoorHeight),
        FRotator(0.0f, Yaw, 0.0f));

    // Sun shade / awning.
    if (RandomStream.FRand() > 0.48f)
    {
        AddBox(
            MetalInstances,
            FVector(
                Location.X + Width * 0.52f,
                Location.Y + RandomStream.FRandRange(-Depth * 0.22f, Depth * 0.22f),
                DoorHeight + 85.0f),
            FVector(260.0f, 420.0f, 24.0f),
            FRotator(0.0f, Yaw, 0.0f));
    }

    if (RandomStream.FRand() > 0.58f)
    {
        AddCylinder(
            AntennaInstances,
            FVector(
                Location.X + RandomStream.FRandRange(-Width * 0.25f, Width * 0.25f),
                Location.Y + RandomStream.FRandRange(-Depth * 0.25f, Depth * 0.25f),
                Height + RandomStream.FRandRange(500.0f, 1400.0f)),
            FVector(34.0f, 34.0f, RandomStream.FRandRange(900.0f, 2400.0f)));
    }
}

void AFHFrontierWorld::BuildCity()
{
    for (int32 GridX = -8; GridX <= 8; ++GridX)
    {
        for (int32 GridY = -8; GridY <= 8; ++GridY)
        {
            const FVector2D CellCenter(
                GridX * CityCell,
                GridY * CityCell);

            const float Radius = CellCenter.Size();

            if (Radius > CityRadius || Radius < 35000.0f)
            {
                continue;
            }

            const float Density =
                FMath::Clamp(
                    1.12f - Radius / CityRadius,
                    0.16f,
                    0.94f);

            const int32 BuildingCount =
                FMath::Clamp(
                    FMath::RoundToInt(
                        2.0f +
                        Density * 7.0f +
                        RandomStream.FRandRange(0.0f, 3.0f)),
                    2,
                    11);

            for (int32 BuildingIndex = 0;
                 BuildingIndex < BuildingCount;
                 ++BuildingIndex)
            {
                const float X =
                    CellCenter.X +
                    RandomStream.FRandRange(-4900.0f, 4900.0f);

                const float Y =
                    CellCenter.Y +
                    RandomStream.FRandRange(-4900.0f, 4900.0f);

                const FVector2D Candidate(X, Y);
                if (Candidate.Size() < 34000.0f)
                {
                    continue;
                }

                const float Width =
                    RandomStream.FRandRange(1800.0f, 5200.0f);

                const float Depth =
                    RandomStream.FRandRange(1700.0f, 4800.0f);

                const float BaseHeight =
                    RandomStream.FRandRange(650.0f, 1900.0f);

                const float Height =
                    BaseHeight *
                    (1.0f + Density * RandomStream.FRandRange(0.25f, 1.55f));

                BuildBuilding(
                    FVector(X, Y, 0.0f),
                    Width,
                    Depth,
                    Height,
                    RandomStream.FRandRange(-9.0f, 9.0f),
                    Density);
            }
        }
    }
}

void AFHFrontierWorld::BuildStarport()
{
    // Central concourse and terminal complex.
    AddCylinder(
        LandingPadInstances,
        FVector(0.0f, 0.0f, 45.0f),
        FVector(26000.0f, 26000.0f, 90.0f));

    AddCylinder(
        CapitalWallInstances,
        FVector(0.0f, 0.0f, 1700.0f),
        FVector(15000.0f, 15000.0f, 3400.0f));

    AddSphere(
        DomeInstances,
        FVector(0.0f, 0.0f, 3600.0f),
        FVector(13000.0f, 13000.0f, 6500.0f));

    AddCylinder(
        MetalInstances,
        FVector(0.0f, 0.0f, 6100.0f),
        FVector(3200.0f, 3200.0f, 5000.0f));

    AddCylinder(
        AntennaInstances,
        FVector(0.0f, 0.0f, 10200.0f),
        FVector(180.0f, 180.0f, 3200.0f));

    for (int32 HangarIndex = 0; HangarIndex < 6; ++HangarIndex)
    {
        const float Angle =
            static_cast<float>(HangarIndex) / 6.0f * UE_TWO_PI;

        const FVector HangarLocation(
            FMath::Cos(Angle) * 21000.0f,
            FMath::Sin(Angle) * 21000.0f,
            1150.0f);

        AddBox(
            CapitalWallInstances,
            HangarLocation,
            FVector(7200.0f, 4800.0f, 2300.0f),
            FRotator(0.0f, FMath::RadiansToDegrees(Angle) + 90.0f, 0.0f));

        AddSphere(
            DomeInstances,
            HangarLocation + FVector(0.0f, 0.0f, 1450.0f),
            FVector(6200.0f, 4300.0f, 2100.0f),
            FRotator(0.0f, FMath::RadiansToDegrees(Angle) + 90.0f, 0.0f));
    }

    for (int32 PadIndex = 0; PadIndex < 10; ++PadIndex)
    {
        const float Angle =
            static_cast<float>(PadIndex) / 10.0f * UE_TWO_PI;

        const float Radius =
            PadIndex % 2 == 0 ? 43000.0f : 52000.0f;

        const float Yaw =
            FMath::RadiansToDegrees(Angle);

        const FVector PadLocation(
            FMath::Cos(Angle) * Radius,
            FMath::Sin(Angle) * Radius,
            25.0f);

        AddCylinder(
            LandingPadInstances,
            PadLocation,
            FVector(10500.0f, 10500.0f, 50.0f));

        // Large readable parked-ship silhouette.
        AddCylinder(
            MetalInstances,
            PadLocation + FVector(0.0f, 0.0f, 950.0f),
            FVector(900.0f, 900.0f, 5200.0f),
            FRotator(0.0f, Yaw, 90.0f));

        AddBox(
            MetalInstances,
            PadLocation + FVector(0.0f, 0.0f, 850.0f),
            FVector(1700.0f, 7200.0f, 220.0f),
            FRotator(0.0f, Yaw, 0.0f));

        AddSphere(
            DomeInstances,
            PadLocation + FVector(1700.0f, 0.0f, 1180.0f),
            FVector(1500.0f, 1100.0f, 900.0f),
            FRotator(0.0f, Yaw, 0.0f));

        AddBox(
            MetalInstances,
            PadLocation + FVector(-2100.0f, 0.0f, 1650.0f),
            FVector(850.0f, 260.0f, 1900.0f),
            FRotator(0.0f, Yaw, 0.0f));
    }
}

void AFHFrontierWorld::BuildOutskirts()
{
    for (int32 Index = 0; Index < 190; ++Index)
    {
        const float Angle =
            RandomStream.FRandRange(0.0f, UE_TWO_PI);

        const float Radius =
            RandomStream.FRandRange(
                CityRadius + 10000.0f,
                260000.0f);

        const float X = FMath::Cos(Angle) * Radius;
        const float Y = FMath::Sin(Angle) * Radius;

        if (RandomStream.FRand() < 0.56f)
        {
            const float Width =
                RandomStream.FRandRange(1400.0f, 4200.0f);

            const float Depth =
                RandomStream.FRandRange(1400.0f, 4200.0f);

            const float Height =
                RandomStream.FRandRange(500.0f, 1600.0f);

            BuildBuilding(
                FVector(X, Y, 0.0f),
                Width,
                Depth,
                Height,
                RandomStream.FRandRange(0.0f, 360.0f),
                0.12f);
        }
        else
        {
            UStaticMesh* VaporatorMesh =
                VaporatorInstances ? VaporatorInstances->GetStaticMesh() : nullptr;

            const bool bUsingRealVaporator =
                VaporatorMesh &&
                VaporatorMesh != CylinderMesh;

            if (bUsingRealVaporator)
            {
                VaporatorInstances->AddInstance(
                    FTransform(
                        FRotator(
                            0.0f,
                            RandomStream.FRandRange(0.0f, 360.0f),
                            0.0f),
                        FVector(X, Y, 0.0f),
                        FVector(RandomStream.FRandRange(0.85f, 1.3f))));
            }
            else
            {
                AddCylinder(
                    MetalInstances,
                    FVector(X, Y, 700.0f),
                    FVector(420.0f, 420.0f, 1400.0f));

                AddCylinder(
                    AntennaInstances,
                    FVector(X, Y, 2100.0f),
                    FVector(60.0f, 60.0f, 2800.0f));

                for (int32 Arm = 0; Arm < 3; ++Arm)
                {
                    const float ArmYaw = Arm * 120.0f;

                    AddBox(
                        MetalInstances,
                        FVector(X, Y, 2350.0f),
                        FVector(1600.0f, 100.0f, 100.0f),
                        FRotator(0.0f, ArmYaw, 0.0f));
                }
            }
        }
    }

    // Distant rock spires / mesas for a readable desert horizon.
    for (int32 Index = 0; Index < 55; ++Index)
    {
        const float Angle =
            RandomStream.FRandRange(0.0f, UE_TWO_PI);

        const float Radius =
            RandomStream.FRandRange(290000.0f, 520000.0f);

        const float Height =
            RandomStream.FRandRange(2600.0f, 11000.0f);

        AddCylinder(
            ConcreteInstances,
            FVector(
                FMath::Cos(Angle) * Radius,
                FMath::Sin(Angle) * Radius,
                Height * 0.5f),
            FVector(
                RandomStream.FRandRange(1600.0f, 6000.0f),
                RandomStream.FRandRange(1600.0f, 6000.0f),
                Height),
            FRotator(
                RandomStream.FRandRange(-8.0f, 8.0f),
                RandomStream.FRandRange(0.0f, 360.0f),
                RandomStream.FRandRange(-8.0f, 8.0f)));
    }
}

void AFHFrontierWorld::BuildLighting()
{
    UWorld* World = GetWorld();
    if (!World)
    {
        return;
    }

    USkyAtmosphereComponent* Atmosphere =
        NewObject<USkyAtmosphereComponent>(
            this,
            TEXT("FrontierSkyAtmosphere"));

    if (Atmosphere)
    {
        Atmosphere->SetMobility(EComponentMobility::Movable);
        Atmosphere->RegisterComponent();
    }

    ADirectionalLight* Sun =
        World->SpawnActor<ADirectionalLight>(
            FVector::ZeroVector,
            FRotator(-24.0f, -36.0f, 0.0f));

    if (Sun)
    {
        if (UDirectionalLightComponent* SunComponent =
            Cast<UDirectionalLightComponent>(Sun->GetLightComponent()))
        {
            SunComponent->SetMobility(EComponentMobility::Movable);
            SunComponent->SetIntensity(8.0f);
            SunComponent->SetLightColor(
                FLinearColor(1.0f, 0.76f, 0.52f));
            SunComponent->SetAtmosphereSunLight(true);
            SunComponent->SetAtmosphereSunLightIndex(0);
            SunComponent->SetDynamicShadowDistanceMovableLight(180000.0f);
        }
    }

    ASkyLight* Sky = World->SpawnActor<ASkyLight>();
    if (Sky && Sky->GetLightComponent())
    {
        Sky->GetLightComponent()->SetMobility(EComponentMobility::Movable);
        Sky->GetLightComponent()->SetIntensity(0.78f);
        Sky->GetLightComponent()->SetRealTimeCaptureEnabled(true);
    }

    AExponentialHeightFog* Fog =
        World->SpawnActor<AExponentialHeightFog>();

    if (Fog && Fog->GetComponent())
    {
        Fog->GetComponent()->SetMobility(EComponentMobility::Movable);
        Fog->GetComponent()->SetFogDensity(0.0022f);
        Fog->GetComponent()->SetFogHeightFalloff(0.16f);
        Fog->GetComponent()->SetStartDistance(18000.0f);
        Fog->GetComponent()->SetVolumetricFog(true);
    }
}

void AFHFrontierWorld::BuildNavigation()
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
            FVector(0.0f, 0.0f, 3000.0f),
            FRotator::ZeroRotator,
            Params);

    if (!NavBounds)
    {
        return;
    }

    NavBounds->SetActorScale3D(
        FVector(700.0f, 700.0f, 30.0f));

    if (UNavigationSystemV1* Navigation =
        FNavigationSystem::GetCurrent<UNavigationSystemV1>(World))
    {
        Navigation->OnNavigationBoundsUpdated(NavBounds);
    }
}

void AFHFrontierWorld::SpawnCombatPopulation()
{
    UWorld* World = GetWorld();
    if (!World)
    {
        return;
    }

    const TArray<FVector> SpawnPoints = {
        FVector(-93000.0f, -64000.0f, 120.0f),
        FVector(-66000.0f, -36000.0f, 120.0f),
        FVector(-21000.0f, -71000.0f, 120.0f),
        FVector(28000.0f, -54000.0f, 120.0f),
        FVector(69000.0f, -22000.0f, 120.0f),
        FVector(81000.0f, 39000.0f, 120.0f),
        FVector(35000.0f, 76000.0f, 120.0f),
        FVector(-52000.0f, 69000.0f, 120.0f)
    };

    FActorSpawnParameters Params;
    Params.SpawnCollisionHandlingOverride =
        ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;

    for (const FVector& SpawnPoint : SpawnPoints)
    {
        World->SpawnActor<AFHEnemyCharacter>(
            SpawnPoint,
            FRotator::ZeroRotator,
            Params);
    }
}
