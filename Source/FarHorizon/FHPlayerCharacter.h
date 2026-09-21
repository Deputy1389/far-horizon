#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "FHPlayerCharacter.generated.h"

class UCameraComponent;

UCLASS()
class FARHORIZON_API AFHPlayerCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    AFHPlayerCharacter();

protected:
    virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;

private:
    UPROPERTY(VisibleAnywhere, Category="Camera")
    TObjectPtr<UCameraComponent> FirstPersonCamera;

    UPROPERTY(EditDefaultsOnly, Category="Movement")
    float WalkSpeed = 500.0f;

    UPROPERTY(EditDefaultsOnly, Category="Movement")
    float SprintSpeed = 900.0f;

    void MoveForward(float Value);
    void MoveRight(float Value);
    void StartSprint();
    void StopSprint();
};
