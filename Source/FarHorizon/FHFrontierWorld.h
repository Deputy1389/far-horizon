#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FHFrontierWorld.generated.h"

class UHierarchicalInstancedStaticMeshComponent;
class UMaterialInterface;
class USceneComponent;
class UStaticMesh;

UCLASS()
class FARHORIZON_API AFHFrontierWorld : public AActor
{
    GENERATED_BODY()

public:
    AFHFrontierWorld();

protected:
    virtual void BeginPlay() override;

private:
    void BuildEnvironment();
    void BuildRoadNetwork();
    void BuildCity();
    void BuildStarport();
    void BuildOutskirts();
    void BuildLighting();
    void BuildNavigation();
    void SpawnCombatPopulation();

    void BuildBuilding(
        const FVector& Location,
        float Width,
        float Depth,
        float Height,
        float Yaw,
        float Density);

    void AddBox(
        UHierarchicalInstancedStaticMeshComponent* Component,
        const FVector& Location,
        const FVector& SizeCm,
        const FRotator& Rotation = FRotator::ZeroRotator);

    void AddCylinder(
        UHierarchicalInstancedStaticMeshComponent* Component,
        const FVector& Location,
        const FVector& SizeCm,
        const FRotator& Rotation = FRotator::ZeroRotator);

    void AddSphere(
        UHierarchicalInstancedStaticMeshComponent* Component,
        const FVector& Location,
        const FVector& SizeCm,
        const FRotator& Rotation = FRotator::ZeroRotator);

    UMaterialInterface* LoadLocalMaterial(const TCHAR* AssetPath) const;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<USceneComponent> SceneRoot;

    UPROPERTY()
    TObjectPtr<UStaticMesh> CubeMesh;

    UPROPERTY()
    TObjectPtr<UStaticMesh> CylinderMesh;

    UPROPERTY()
    TObjectPtr<UStaticMesh> SphereMesh;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UHierarchicalInstancedStaticMeshComponent> SandInstances;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UHierarchicalInstancedStaticMeshComponent> DuneInstances;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UHierarchicalInstancedStaticMeshComponent> RoadInstances;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UHierarchicalInstancedStaticMeshComponent> WallInstances;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UHierarchicalInstancedStaticMeshComponent> CapitalWallInstances;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UHierarchicalInstancedStaticMeshComponent> ConcreteInstances;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UHierarchicalInstancedStaticMeshComponent> MetalInstances;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UHierarchicalInstancedStaticMeshComponent> DomeInstances;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UHierarchicalInstancedStaticMeshComponent> LandingPadInstances;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UHierarchicalInstancedStaticMeshComponent> AntennaInstances;

    FRandomStream RandomStream;

    static constexpr float CityRadius = 110000.0f;
    static constexpr float GroundHalfExtent = 800000.0f;
    static constexpr float CityCell = 14000.0f;
};
