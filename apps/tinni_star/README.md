# Tinni Star

Tinni Star is a new, separate Flutter voice-room app foundation.

It does not modify the existing voice-chat demo or Anamika code.

## Current foundation

- New Tinni Star app shell
- Modular room state controller
- Seat join/request flow
- Seat lock support
- Mic state model
- Room chat
- Gift-engine integration slot
- Safe Function Pack runtime
- Owner approval requirement
- Pack compatibility validation
- Pack signature verifier interface
- Previous-pack rollback
- Anamika Connector contract
- Diagnostic snapshot for Anamika

## Function Pack boundary

Function Packs are designed for compatible runtime behavior such as seat rules,
invite/free-seat mode, chat/gift flags, gift combo limits and feature flags.

They do not execute arbitrary Dart/native code.

Compiled Flutter/Dart code, Android permissions, native SDKs, signing and low-level
RTC libraries still require a normal app build/update.

## Planned modules

Auth, Home/Discovery, RoomSession, SeatManager, MicManager, Moderation,
RTCAdapter, IMAdapter, Gift/Wallet/Store, Social/Messages, VIP/Effects,
CP/Relationship, Family, KTV, Games, Function Pack Runtime and Anamika Connector.

The current signature verifier is development-only. Production must replace it
with real public-key signature verification and persistent pack storage.
