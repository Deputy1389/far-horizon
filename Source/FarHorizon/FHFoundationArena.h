#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FHFoundationArena.generated.h"

UCLASS()
class FARHORIZON_API AFHFoundationArena : public AActor
{
    GENERATED_BODY()

public:
    AFHFoundationArena();

protected:
    virtual void BeginPlay() override;

private:
    void SpawnBox(
        const FVector& Location,
        const FVector& Scale,
        const FRotator& Rotation = FRotator::ZeroRotator);

    void SpawnLighting();
    void SpawnNavigationBounds();
    void SpawnEnemy();

    UPROPERTY()
    TObjectPtr<UStaticMesh> CubeMesh;
};
