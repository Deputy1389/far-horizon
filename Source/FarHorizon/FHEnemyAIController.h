#pragma once

#include "CoreMinimal.h"
#include "AIController.h"
#include "Perception/AIPerceptionTypes.h"
#include "FHEnemyAIController.generated.h"

class UAIPerceptionComponent;
class UAISenseConfig_Sight;
class UStateTree;
class UStateTreeAIComponent;

UCLASS()
class FARHORIZON_API AFHEnemyAIController : public AAIController
{
    GENERATED_BODY()

public:
    AFHEnemyAIController();

    virtual void Tick(float DeltaSeconds) override;
    virtual void OnPossess(APawn* InPawn) override;

    static FVector ComputeTacticalPoint(
        const FVector& SelfLocation,
        const FVector& TargetLocation,
        float SideSign,
        float DesiredRange,
        float LateralOffset);

protected:
    virtual void BeginPlay() override;

private:
    UFUNCTION()
    void HandleTargetPerceptionUpdated(AActor* Actor, FAIStimulus Stimulus);

    void TickFallbackCombat(float DeltaSeconds);
    void UpdateFallbackMovement();
    void UpdatePatrol();
    bool ProjectToNavigation(const FVector& Desired, FVector& OutProjected) const;

    UPROPERTY(VisibleAnywhere, Category="AI")
    TObjectPtr<UAIPerceptionComponent> Perception;

    UPROPERTY()
    TObjectPtr<UAISenseConfig_Sight> SightConfig;

    UPROPERTY(VisibleAnywhere, Category="AI|StateTree")
    TObjectPtr<UStateTreeAIComponent> StateTreeComponent;

    UPROPERTY(EditDefaultsOnly, Category="AI|StateTree")
    TObjectPtr<UStateTree> BehaviorStateTree;

    UPROPERTY(EditDefaultsOnly, Category="AI|Combat")
    float PreferredMinRange = 750.0f;

    UPROPERTY(EditDefaultsOnly, Category="AI|Combat")
    float PreferredRange = 1350.0f;

    UPROPERTY(EditDefaultsOnly, Category="AI|Combat")
    float PreferredMaxRange = 2000.0f;

    UPROPERTY(EditDefaultsOnly, Category="AI|Combat")
    float FireRange = 3000.0f;

    UPROPERTY(EditDefaultsOnly, Category="AI|Combat")
    float LateralRepositionDistance = 550.0f;

    UPROPERTY(EditDefaultsOnly, Category="AI|Combat")
    float MovementDecisionInterval = 1.25f;

    UPROPERTY(EditDefaultsOnly, Category="AI|Patrol")
    float PatrolRadius = 1400.0f;

    UPROPERTY(EditDefaultsOnly, Category="AI|Patrol")
    float PatrolDecisionInterval = 4.0f;

    TWeakObjectPtr<AActor> CombatTarget;
    FVector LastKnownTargetLocation = FVector::ZeroVector;
    FVector HomeLocation = FVector::ZeroVector;

    float MovementDecisionRemaining = 0.0f;
    float PatrolDecisionRemaining = 0.0f;
    float StrafeSide = 1.0f;
    bool bHasTargetSight = false;
    bool bUsingStateTree = false;
};
