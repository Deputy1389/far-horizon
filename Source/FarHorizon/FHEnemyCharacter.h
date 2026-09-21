#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "FHEnemyCharacter.generated.h"

class UAnimationAsset;
class UFHBlasterComponent;
class UFHHealthComponent;
class USceneComponent;

UCLASS()
class FARHORIZON_API AFHEnemyCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    AFHEnemyCharacter();

    virtual void Tick(float DeltaSeconds) override;

    bool TryFireAt(AActor* Target);

    UFUNCTION(BlueprintPure, Category="Combat")
    UFHHealthComponent* GetHealthComponent() const { return Health; }

protected:
    virtual void BeginPlay() override;

private:
    void UpdatePresentationAnimation(float DeltaSeconds);

    UFUNCTION()
    void HandleDeath(AActor* DeadActor);

    UPROPERTY(VisibleAnywhere, Category="Combat")
    TObjectPtr<UFHBlasterComponent> Blaster;

    UPROPERTY(VisibleAnywhere, Category="Combat")
    TObjectPtr<UFHHealthComponent> Health;

    UPROPERTY(VisibleAnywhere, Category="Combat")
    TObjectPtr<USceneComponent> WeaponMuzzle;

    UPROPERTY(Transient)
    TObjectPtr<UAnimationAsset> IdleAnimation;

    UPROPERTY(Transient)
    TObjectPtr<UAnimationAsset> WalkAnimation;

    UPROPERTY(Transient)
    TObjectPtr<UAnimationAsset> RunAnimation;

    UPROPERTY(Transient)
    TObjectPtr<UAnimationAsset> FireAnimation;

    UPROPERTY(Transient)
    TObjectPtr<UAnimationAsset> CurrentPresentationAnimation;

    bool bUsingLocalSwgPresentation = false;
    float FirePresentationRemaining = 0.0f;
};
