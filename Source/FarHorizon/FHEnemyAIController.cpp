#include "FHEnemyAIController.h"

#include "FHEnemyCharacter.h"
#include "Components/StateTreeAIComponent.h"
#include "NavigationSystem.h"
#include "Perception/AIPerceptionComponent.h"
#include "Perception/AISenseConfig_Sight.h"
#include "StateTree.h"

AFHEnemyAIController::AFHEnemyAIController()
{
    PrimaryActorTick.bCanEverTick = true;

    Perception = CreateDefaultSubobject<UAIPerceptionComponent>(TEXT("Perception"));
    SetPerceptionComponent(*Perception);

    SightConfig = CreateDefaultSubobject<UAISenseConfig_Sight>(TEXT("SightConfig"));
    SightConfig->SightRadius = 5200.0f;
    SightConfig->LoseSightRadius = 6200.0f;
    SightConfig->PeripheralVisionAngleDegrees = 78.0f;
    SightConfig->SetMaxAge(4.0f);
    SightConfig->DetectionByAffiliation.bDetectEnemies = true;
    SightConfig->DetectionByAffiliation.bDetectFriendlies = true;
    SightConfig->DetectionByAffiliation.bDetectNeutrals = true;

    Perception->ConfigureSense(*SightConfig);
    Perception->SetDominantSense(SightConfig->GetSenseImplementation());

    StateTreeComponent = CreateDefaultSubobject<UStateTreeAIComponent>(TEXT("StateTreeAI"));
    StateTreeComponent->SetStartLogicAutomatically(false);

    bSetControlRotationFromPawnOrientation = false;
}

void AFHEnemyAIController::BeginPlay()
{
    Super::BeginPlay();

    Perception->OnTargetPerceptionUpdated.AddDynamic(
        this,
        &AFHEnemyAIController::HandleTargetPerceptionUpdated);
}

void AFHEnemyAIController::OnPossess(APawn* InPawn)
{
    Super::OnPossess(InPawn);

    HomeLocation = InPawn ? InPawn->GetActorLocation() : FVector::ZeroVector;

    bUsingStateTree = false;
    if (BehaviorStateTree && StateTreeComponent)
    {
        StateTreeComponent->SetStateTree(BehaviorStateTree);
        StateTreeComponent->StartLogic();
        bUsingStateTree = StateTreeComponent->IsRunning();
    }
}

FVector AFHEnemyAIController::ComputeTacticalPoint(
    const FVector& SelfLocation,
    const FVector& TargetLocation,
    float SideSign,
    float DesiredRange,
    float LateralOffset)
{
    FVector AwayFromTarget = SelfLocation - TargetLocation;
    AwayFromTarget.Z = 0.0;

    if (!AwayFromTarget.Normalize())
    {
        AwayFromTarget = FVector::ForwardVector;
    }

    FVector Tangent = FVector::CrossProduct(FVector::UpVector, AwayFromTarget).GetSafeNormal();
    Tangent *= FMath::Sign(FMath::IsNearlyZero(SideSign) ? 1.0f : SideSign);

    return TargetLocation
        + AwayFromTarget * DesiredRange
        + Tangent * LateralOffset;
}

void AFHEnemyAIController::HandleTargetPerceptionUpdated(
    AActor* Actor,
    FAIStimulus Stimulus)
{
    APawn* PawnTarget = Cast<APawn>(Actor);
    if (!PawnTarget || !PawnTarget->IsPlayerControlled())
    {
        return;
    }

    LastKnownTargetLocation = Stimulus.StimulusLocation;

    if (Stimulus.WasSuccessfullySensed())
    {
        CombatTarget = Actor;
        bHasTargetSight = true;
        SetFocus(Actor);
        MovementDecisionRemaining = 0.0f;
        return;
    }

    if (CombatTarget.Get() == Actor)
    {
        bHasTargetSight = false;
        ClearFocus(EAIFocusPriority::Gameplay);
        MoveToLocation(LastKnownTargetLocation, 100.0f, true, true, true, false);
    }
}

void AFHEnemyAIController::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (bUsingStateTree)
    {
        return;
    }

    TickFallbackCombat(DeltaSeconds);
}

void AFHEnemyAIController::TickFallbackCombat(float DeltaSeconds)
{
    AFHEnemyCharacter* Enemy = Cast<AFHEnemyCharacter>(GetPawn());
    AActor* Target = CombatTarget.Get();

    if (!Enemy || !Target)
    {
        PatrolDecisionRemaining -= DeltaSeconds;
        if (PatrolDecisionRemaining <= 0.0f)
        {
            UpdatePatrol();
            PatrolDecisionRemaining = PatrolDecisionInterval;
        }
        return;
    }

    if (bHasTargetSight && LineOfSightTo(Target))
    {
        LastKnownTargetLocation = Target->GetActorLocation();

        const float Distance = FVector::Dist(
            Enemy->GetActorLocation(),
            Target->GetActorLocation());

        if (Distance <= FireRange)
        {
            Enemy->TryFireAt(Target);
        }
    }

    MovementDecisionRemaining -= DeltaSeconds;
    if (MovementDecisionRemaining <= 0.0f)
    {
        UpdateFallbackMovement();
        MovementDecisionRemaining = MovementDecisionInterval;
    }
}

void AFHEnemyAIController::UpdateFallbackMovement()
{
    APawn* ControlledPawn = GetPawn();
    AActor* Target = CombatTarget.Get();

    if (!ControlledPawn || !Target)
    {
        return;
    }

    if (!bHasTargetSight)
    {
        MoveToLocation(LastKnownTargetLocation, 100.0f, true, true, true, false);
        return;
    }

    const FVector SelfLocation = ControlledPawn->GetActorLocation();
    const FVector TargetLocation = Target->GetActorLocation();
    const float Distance = FVector::Dist(SelfLocation, TargetLocation);

    if (Distance > PreferredMaxRange)
    {
        MoveToActor(Target, PreferredRange, true, true, true, nullptr, true);
        return;
    }

    FVector DesiredLocation;

    if (Distance < PreferredMinRange)
    {
        FVector Away = SelfLocation - TargetLocation;
        Away.Z = 0.0f;
        Away = Away.GetSafeNormal();

        DesiredLocation = SelfLocation + Away * (PreferredRange - Distance + 350.0f);
    }
    else
    {
        DesiredLocation = ComputeTacticalPoint(
            SelfLocation,
            TargetLocation,
            StrafeSide,
            PreferredRange,
            LateralRepositionDistance);

        StrafeSide *= -1.0f;
    }

    FVector Projected;
    if (ProjectToNavigation(DesiredLocation, Projected))
    {
        MoveToLocation(Projected, 100.0f, true, true, true, false);
    }
}

void AFHEnemyAIController::UpdatePatrol()
{
    if (!GetPawn())
    {
        return;
    }

    UNavigationSystemV1* Navigation = UNavigationSystemV1::GetCurrent(GetWorld());
    if (!Navigation)
    {
        return;
    }

    FNavLocation Destination;
    if (Navigation->GetRandomReachablePointInRadius(
        HomeLocation,
        PatrolRadius,
        Destination))
    {
        MoveToLocation(Destination.Location, 100.0f, true, true, true, false);
    }
}

bool AFHEnemyAIController::ProjectToNavigation(
    const FVector& Desired,
    FVector& OutProjected) const
{
    UNavigationSystemV1* Navigation = UNavigationSystemV1::GetCurrent(GetWorld());
    if (!Navigation)
    {
        return false;
    }

    FNavLocation Result;
    if (!Navigation->ProjectPointToNavigation(Desired, Result))
    {
        return false;
    }

    OutProjected = Result.Location;
    return true;
}
