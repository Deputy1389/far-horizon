#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "FHEnemyCharacter.generated.h"

class UFHBlasterComponent;
class UFHHealthComponent;
class USceneComponent;

UCLASS()
class FARHORIZON_API AFHEnemyCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    AFHEnemyCharacter();

    bool TryFireAt(AActor* Target);

    UFUNCTION(BlueprintPure, Category="Combat")
    UFHHealthComponent* GetHealthComponent() const { return Health; }

protected:
    virtual void BeginPlay() override;

private:
    UFUNCTION()
    void HandleDeath(AActor* DeadActor);

    UPROPERTY(VisibleAnywhere, Category="Combat")
    TObjectPtr<UFHBlasterComponent> Blaster;

    UPROPERTY(VisibleAnywhere, Category="Combat")
    TObjectPtr<UFHHealthComponent> Health;

    UPROPERTY(VisibleAnywhere, Category="Combat")
    TObjectPtr<USceneComponent> WeaponMuzzle;
};
