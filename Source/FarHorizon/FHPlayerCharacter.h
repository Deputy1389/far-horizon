#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "InputActionValue.h"
#include "FHPlayerCharacter.generated.h"

class UCameraComponent;
class USkeletalMeshComponent;
class USceneComponent;
class UInputAction;
class UInputMappingContext;
class UFHBlasterComponent;

UCLASS()
class FARHORIZON_API AFHPlayerCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    AFHPlayerCharacter();

    virtual void Tick(float DeltaSeconds) override;
    virtual void PawnClientRestart() override;

protected:
    virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;

private:
    void EnsureRuntimeInputObjects();
    void Move(const FInputActionValue& Value);
    void Look(const FInputActionValue& Value);
    void StartJump();
    void StopJump();
    void StartSprint();
    void StopSprint();
    void ToggleCrouch();
    void StartAim();
    void StopAim();
    void Fire();

    UPROPERTY(VisibleAnywhere, Category="Camera")
    TObjectPtr<UCameraComponent> FirstPersonCamera;

    UPROPERTY(VisibleAnywhere, Category="Presentation")
    TObjectPtr<USkeletalMeshComponent> FirstPersonArms;

    UPROPERTY(VisibleAnywhere, Category="Weapon")
    TObjectPtr<USceneComponent> WeaponRoot;

    UPROPERTY(VisibleAnywhere, Category="Weapon")
    TObjectPtr<USceneComponent> WeaponMuzzle;

    UPROPERTY(VisibleAnywhere, Category="Weapon")
    TObjectPtr<UFHBlasterComponent> Blaster;

    UPROPERTY(Transient)
    TObjectPtr<UInputMappingContext> DefaultInputContext;

    UPROPERTY(Transient)
    TObjectPtr<UInputAction> MoveAction;

    UPROPERTY(Transient)
    TObjectPtr<UInputAction> LookAction;

    UPROPERTY(Transient)
    TObjectPtr<UInputAction> JumpAction;

    UPROPERTY(Transient)
    TObjectPtr<UInputAction> SprintAction;

    UPROPERTY(Transient)
    TObjectPtr<UInputAction> CrouchAction;

    UPROPERTY(Transient)
    TObjectPtr<UInputAction> AimAction;

    UPROPERTY(Transient)
    TObjectPtr<UInputAction> FireAction;

    UPROPERTY(EditDefaultsOnly, Category="Movement")
    float WalkSpeed = 500.0f;

    UPROPERTY(EditDefaultsOnly, Category="Movement")
    float SprintSpeed = 850.0f;

    UPROPERTY(EditDefaultsOnly, Category="Camera")
    float HipFov = 90.0f;

    UPROPERTY(EditDefaultsOnly, Category="Camera")
    float AimFov = 72.0f;

    UPROPERTY(EditDefaultsOnly, Category="Camera")
    float AimFovInterpSpeed = 14.0f;

    UPROPERTY(EditDefaultsOnly, Category="Camera")
    float LookSensitivity = 1.0f;

    bool bIsSprinting = false;
    bool bIsAiming = false;
};
