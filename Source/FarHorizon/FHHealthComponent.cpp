#include "FHHealthComponent.h"

#include "GameFramework/Actor.h"

UFHHealthComponent::UFHHealthComponent()
{
    PrimaryComponentTick.bCanEverTick = false;
}

void UFHHealthComponent::BeginPlay()
{
    Super::BeginPlay();

    CurrentHealth = MaxHealth;

    if (AActor* Owner = GetOwner())
    {
        Owner->OnTakeAnyDamage.AddDynamic(this, &UFHHealthComponent::HandleAnyDamage);
    }
}

void UFHHealthComponent::HandleAnyDamage(
    AActor* DamagedActor,
    float Damage,
    const UDamageType* DamageType,
    AController* InstigatedBy,
    AActor* DamageCauser)
{
    if (Damage <= 0.0f || IsDead())
    {
        return;
    }

    CurrentHealth = FMath::Clamp(CurrentHealth - Damage, 0.0f, MaxHealth);
    OnHealthChanged.Broadcast(CurrentHealth, MaxHealth);

    if (IsDead())
    {
        OnDeath.Broadcast(DamagedActor);
    }
}
