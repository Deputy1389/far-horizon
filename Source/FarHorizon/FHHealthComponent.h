#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "FHHealthComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(
    FFHHealthChangedSignature,
    float, CurrentHealth,
    float, MaxHealth);

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(
    FFHDeathSignature,
    AActor*, DeadActor);

UCLASS(ClassGroup=(FarHorizon), meta=(BlueprintSpawnableComponent))
class FARHORIZON_API UFHHealthComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UFHHealthComponent();

    UFUNCTION(BlueprintPure, Category="Health")
    float GetCurrentHealth() const { return CurrentHealth; }

    UFUNCTION(BlueprintPure, Category="Health")
    float GetMaxHealth() const { return MaxHealth; }

    UFUNCTION(BlueprintPure, Category="Health")
    bool IsDead() const { return CurrentHealth <= 0.0f; }

    UPROPERTY(BlueprintAssignable, Category="Health")
    FFHHealthChangedSignature OnHealthChanged;

    UPROPERTY(BlueprintAssignable, Category="Health")
    FFHDeathSignature OnDeath;

protected:
    virtual void BeginPlay() override;

private:
    UFUNCTION()
    void HandleAnyDamage(
        AActor* DamagedActor,
        float Damage,
        const UDamageType* DamageType,
        AController* InstigatedBy,
        AActor* DamageCauser);

    UPROPERTY(EditDefaultsOnly, Category="Health", meta=(ClampMin="1.0"))
    float MaxHealth = 100.0f;

    UPROPERTY(VisibleInstanceOnly, Category="Health")
    float CurrentHealth = 100.0f;
};
