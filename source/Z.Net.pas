(*
MIT License

Copyright (c) 2026 by.LaoZhang qq600585

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*)
{
  * ****************************************************************************
  * Z.Net - High-performance, cross-platform network communication framework
  *
  * ============================================================================
  * DEPENDENCIES (uses clause)
  * ============================================================================
  * This unit relies on the following core libraries from the Z framework:
  *
  *   Z.Core                                      - base object model, threading primitives
  *   Z.PascalStrings, Z.UPascalStrings           - string types and manipulation
  *   Z.HashList.Templet                          - generic hash/list templates
  *   Z.ListEngine                                - advanced list containers
  *   Z.UnicodeMixedLib                           - mixed-encoding string helpers
  *   Z.Status                                    - global debug/status logging
  *   Z.DFE                                       - Data Frame Exchange (binary serialisation)
  *   Z.MemoryStream                              - memory stream enhancements
  *   Z.Cipher                                    - encryption, hashing, key management
  *   Z.Notify                                    - notification / callback infrastructure
  *   Z.Cadencer                                  - time-based event scheduler
  *   Z.ZDB2                                      - ZDB2 database engine (used for swap space)
  *
  * ============================================================================
  * KEY FUNCTIONALITY
  * ============================================================================
  * This unit provides a complete, scalable, and secure networking stack suitable
  * for client-server and peer-to-peer applications. It supports multiple data
  * carriers and is optimised for high throughput and low latency.
  *
  * Core features:
  *   - Rich command-based protocol with synchronous, asynchronous,
  *     and fire-and-forget variants.
  *   - Multiple data payload types:
  *       - Console strings (plain text / UTF-8)
  *       - DFE streams (structured binary data)
  *       - Direct (no-reply) commands for one-way messaging
  *       - Big streams (e.g., file transfers) with fragmentation
  *         and flow control
  *       - Complete buffers (atomic blocks) with optional compression
  *         and disk swapping
  *   - Built-in encryption (multiple ciphers, CBC mode, fast instance reuse)
  *   - Built-in compression (ZLib) for payloads and complete buffers
  *   - Reliable ordered packet layer (Sequence Packet model) over
  *     unreliable transports (e.g., UDP) with automatic retransmission
  *     and acknowledgment
  *   - P2P Virtual Machine (P2PVM) overlay for NAT traversal and logical
  *     tunnelling over existing connections
  *   - StableIO - persistent session layer that survives reconnections
  *   - HPC (High-Performance Computing) - thread-pool based command execution
  *     for CPU-intensive tasks without blocking the main loop
  *   - Automated P2PVM service discovery and tunnel establishment
  *   - Extensive statistics, monitoring, and debugging hooks
  *
  * ============================================================================
  * CRITICAL SUBSYSTEMS (key classes)
  * ============================================================================
  *   TPeerIO              - per-connection state machine; handles send/receive
  *                          queues, big-stream reassembly, complete-buffer
  *                          assembly, and sequence-packet reliability.
  *   TZNet                - base framework; command registration, IO management,
  *                          progress engine, P2PVM integration.
  *   TZNet_Server         - concrete server implementation; manages incoming
  *                          connections, broadcasting, and per-IO sends.
  *   TZNet_Client         - concrete client implementation; manages single
  *                          connection, synchronous/asynchronous connect, and
  *                          server state synchronisation.
  *   TZNet_P2PVM          - virtual network overlay; provides P2P connectivity
  *                          over an existing IO, with authentication, listening,
  *                          and virtual IO routing.
  *   TZNet_WithP2PVM_Server - server variant that can be exposed over P2PVM.
  *   TZNet_WithP2PVM_Client - client variant that connects over P2PVM; supports
  *                            cloning to create multiple virtual channels.
  *   TZNet_StableServer/Client - stable session layer; maintains connection
  *                               state across physical disconnections.
  *   THPC_Stream / THPC_Console etc. - task objects for thread-pool execution.
  *
  * ============================================================================
  * DESIGN PHILOSOPHY
  * ============================================================================
  *   - Asynchronous, non-blocking I/O with a single-threaded progress loop
  *     (all operations are driven by repeated calls to Progress()).
  *   - Zero-copy buffer handling where possible.
  *   - Modular architecture with clear separation between physical transport,
  *     reliable framing, command protocol, and application logic.
  *   - Extensible via callbacks (C-style, methods, anonymous/nested) and
  *     user-definable objects attached to each IO.
  *   - Secure by default - authentication, encryption, and hash verification
  *     are built into the protocol.
  *
  * ============================================================================
  * NOTES
  * ============================================================================
  *   - The framework is used in game servers, real-time data distribution,
  *     file transfer, and distributed computing systems.
  *   - It is designed to run on both FPC (Free Pascal) and Delphi, with
  *     conditionals for platform-specific features.
  *   - Many constants and defaults can be overridden at runtime via the
  *     properties of TZNet and its derivatives.
  *   - The implementation is highly performant but also memory-conscious,
  *     offering optional disk swapping for large data items.
  *
  * ****************************************************************************
}
unit Z.Net;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses Classes, SysUtils, Variants, TypInfo,
{$IFDEF FPC}
  Z.FPC.GenericList,
{$ELSE FPC}
  System.IOUtils,
{$ENDIF FPC}
  Z.Core, Z.PascalStrings, Z.UPascalStrings, Z.HashList.Templet, Z.ListEngine, Z.UnicodeMixedLib, Z.Status,
  Z.DFE, Z.MemoryStream, Z.Cipher, Z.Notify, Z.Cadencer, Z.ZDB2;

const
  C_ZNet_Edition = '5.02';

{$REGION 'base Decl'}

  {
    * Forward declarations of core classes and interfaces used throughout the unit.
    * These allow circular references to be resolved at compile time.
  }
type
  TPeerIO = class; { Core per-connection state machine. }
  TZNet = class; { Base network framework class. }
  TStream_Event_Bridge = class; { Stream-oriented event bridge for command callbacks. }
  TConsole_Event_Bridge = class; { Console-oriented event bridge for command callbacks. }
  TZNet_WithP2PVM_Server = class; { Server that can be exposed over a P2PVM tunnel. }
  TZNet_WithP2PVM_Client = class; { Client that connects over a P2PVM tunnel. }
  TZNet_Progress = class; { Progress event attached to a TZNet instance. }
  TZNet_Progress_Class = class of TZNet_Progress;
  TCommandCompleteBuffer_NoWait_Bridge = class; { Bridge for no-wait complete-buffer commands. }
  TCompleteBuffer_Stream_Event_Bridge = class; { Event bridge for complete-buffer stream commands. }
  TUID___ = TSHA3_256_Digest; { 256-bit SHA3-256 digest type used as the global unique identifier (UID). }
  PUID___ = PSHA3_256_Digest;
  TAtomUID___ = TAtomVar<TUID___>; { Thread-safe atomic wrapper around TUID___, providing synchronized read/write access. }

  TIPV4 = array [0 .. 3] of Byte; { IPv4 address as 4 bytes. }
  PIPV4 = ^TIPV4;
  TIPV6 = array [0 .. 7] of Word; { IPv6 address as 8 words (16 bytes). }
  PIPV6 = ^TIPV6;

  {
    * Callback type: Method-style console command result handler.
    * Triggered by TZNet Command Dispatcher on response.
    * Purpose: Handle successful console command result and access instance state.
    * @Param Sender: The IO connection that initiated the command.
    * @Param Result_: The response string from the remote peer.
  }
  TOnConsole_M = procedure(Sender: TPeerIO; Result_: SystemString) of object;

  {
    * Callback type: Method-style console command result handler with parameters.
    * Triggered by TZNet Command Dispatcher on response.
    * Purpose: Process console command result with custom parameters for complex business context.
    * @Param Sender: The IO connection that initiated the command.
    * @Param Param1: User-defined pointer parameter passed during send.
    * @Param Param2: User-defined object parameter passed during send.
    * @Param SendData: The original data that was sent.
    * @Param Result_: The response string from the remote peer.
  }
  TOnConsoleParam_M = procedure(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: SystemString) of object;

  {
    * Callback type: Method-style console command failure handler.
    * Triggered by TZNet Command Dispatcher on timeout or error.
    * Purpose: Notify console command failure and carry original sent data for retry logic.
    * @Param Sender: The IO connection that initiated the command.
    * @Param Param1: User-defined pointer parameter passed during send.
    * @Param Param2: User-defined object parameter passed during send.
    * @Param SendData: The original data that was sent.
  }
  TOnConsoleFailed_M = procedure(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: SystemString) of object;

  {
    * Callback type: Method-style stream command result handler.
    * Triggered by TZNet Command Dispatcher on response.
    * Purpose: Handle successful stream command result and parse received payload.
    * @Param Sender: The IO connection that initiated the command.
    * @Param Result_: The response DFE (Data Frame Exchange) containing structured data.
  }
  TOnStream_M = procedure(Sender: TPeerIO; Result_: TDFE) of object;

  {
    * Callback type: Method-style stream command result handler with parameters.
    * Triggered by TZNet Command Dispatcher on response.
    * Purpose: Process stream command result with parameters for large or chunked data transfers.
    * @Param Sender: The IO connection that initiated the command.
    * @Param Param1: User-defined pointer parameter passed during send.
    * @Param Param2: User-defined object parameter passed during send.
    * @Param SendData: The original data that was sent.
    * @Param Result_: The response DFE containing structured data.
  }
  TOnStreamParam_M = procedure(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: TDFE) of object;

  {
    * Callback type: Method-style stream command failure handler.
    * Triggered by TZNet Command Dispatcher on timeout or error.
    * Purpose: Notify stream command failure and carry original payload for recovery.
    * @Param Sender: The IO connection that initiated the command.
    * @Param Param1: User-defined pointer parameter passed during send.
    * @Param Param2: User-defined object parameter passed during send.
    * @Param SendData: The original DFE that was sent.
  }
  TOnStreamFailed_M = procedure(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: TDFE) of object;

  {
    * Callback type: C-style simple state change handler (no object).
    * Triggered by Connection Manager (TZNet/TPeerIO).
    * Purpose: Monitor global or basic connection state transitions such as online/offline.
    * @Param State: True if connected/active, False if disconnected/inactive.
  }
  TOnState_C = procedure(const State: Boolean);

  {
    * Callback type: Method-style state change handler (with object).
    * Triggered by Connection Manager (TZNet/TPeerIO).
    * Purpose: Notify object-level state change and update UI or business logic accordingly.
    * @Param State: True if connected/active, False if disconnected/inactive.
  }
  TOnState_M = procedure(const State: Boolean) of object;

  {
    * Callback type: C-style IO state change handler.
    * Triggered by TPeerIO State Machine.
    * Purpose: Monitor specific connection IO state transitions including handshake completion,
    *          disconnect, or keepalive heartbeat.
    * @Param P_IO: The IO connection whose state changed.
    * @Param State: True if connected/active, False if disconnected/inactive.
  }
  TOnIOState_C = procedure(P_IO: TPeerIO; State: Boolean);

  {
    * Callback type: Method-style IO state change handler.
    * Triggered by TPeerIO State Machine.
    * Purpose: Notify object-level IO state change for multi-connection context management.
    * @Param P_IO: The IO connection whose state changed.
    * @Param State: True if connected/active, False if disconnected/inactive.
  }
  TOnIOState_M = procedure(P_IO: TPeerIO; State: Boolean) of object;

  {
    * Callback type: C-style parameterized state handler.
    * Triggered by Custom State Manager or Bridge Engine.
    * Purpose: Pass dual-parameter context alongside state change for cross-module event routing.
    * @Param Param1: First user-defined parameter.
    * @Param Param2: Second user-defined parameter.
    * @Param State: The state value (True/False).
  }
  TOnParamState_C = procedure(Param1: Pointer; Param2: TObject; const State: Boolean);

  {
    * Callback type: Method-style parameterized state handler.
    * Triggered by Custom State Manager or Bridge Engine.
    * Purpose: Object-level parameterized state change for plugin or modular architecture integration.
    * @Param Param1: First user-defined parameter.
    * @Param Param2: Second user-defined parameter.
    * @Param State: The state value (True/False).
  }
  TOnParamState_M = procedure(Param1: Pointer; Param2: TObject; const State: Boolean) of object;

  {
    * Callback type: C-style simple notification (no parameters, no object).
    * Triggered by Framework Async Task Queue or Background Thread.
    * Purpose: Deliver lightweight parameterless notification to decouple heavy operations from main IO thread.
  }
  TOnNotify_C = procedure();

  {
    * Callback type: Method-style simple notification.
    * Triggered by Framework Async Task Queue or Background Thread.
    * Purpose: Object-level parameterless notification allowing safe access to instance members during async execution.
  }
  TOnNotify_M = procedure() of object;

  {
    * Callback type: C-style data notification.
    * Triggered by Data Distributor or Message Bus.
    * Purpose: Notify arrival of generic raw data for non-command stream processing.
    * @Param data: The data object being delivered.
  }
  TOnDataNotify_C = procedure(data: TCore_Object);

  {
    * Callback type: Method-style data notification.
    * Triggered by Data Distributor or Message Bus.
    * Purpose: Object-level data arrival notification enabling in-class aggregation or routing logic.
    * @Param data: The data object being delivered.
  }
  TOnDataNotify_M = procedure(data: TCore_Object) of object;

  {
    * Callback type: C-style IO notification.
    * Triggered by TPeerIO Connection Manager.
    * Purpose: Notify activity or idle state of specific connection for heartbeat detection or keepalive scheduling.
    * @Param P_IO: The IO connection that triggered the notification.
  }
  TOnIONotify_C = procedure(P_IO: TPeerIO);

  {
    * Callback type: Method-style IO notification.
    * Triggered by TPeerIO Connection Manager.
    * Purpose: Object-level IO activity notification supporting concurrent multi-connection management.
    * @Param P_IO: The IO connection that triggered the notification.
  }
  TOnIONotify_M = procedure(P_IO: TPeerIO) of object;

  {
    * Callback type: C-style progress background notification.
    * Triggered by HPC Background Progress Engine or Timer.
    * Purpose: Provide periodic background progress polling for non-blocking task status updates.
  }
  TOnProgressBackground_C = procedure();

  {
    * Callback type: Method-style progress background notification.
    * Triggered by HPC Background Progress Engine or Timer.
    * Purpose: Object-level periodic progress polling to check instance task state and advance logic.
  }
  TOnProgressBackground_M = procedure() of object;

  {
    * Callback type: C-style stream event bridge event handler.
    * Triggered by Stream Event Bridge Engine.
    * Purpose: Intercept or route stream data between two connections and process bridged payload.
    * @Param Sender: The bridge instance that triggered the event.
    * @Param SourceIO: The IO connection where the data originated.
    * @Param BridgeIO: The IO connection where the data is being bridged to.
    * @Param Result_: The DFE data being bridged.
  }
  TOnStream_Event_Bridge_Event_C = procedure(Sender: TStream_Event_Bridge; SourceIO, BridgeIO: TPeerIO; Result_: TDFE);

  {
    * Callback type: Method-style stream event bridge event handler.
    * Triggered by Stream Event Bridge Engine.
    * Purpose: Object-level stream routing interception allowing dynamic modification of bridge behavior via instance config.
    * @Param Sender: The bridge instance that triggered the event.
    * @Param SourceIO: The IO connection where the data originated.
    * @Param BridgeIO: The IO connection where the data is being bridged to.
    * @Param Result_: The DFE data being bridged.
  }
  TOnStream_Event_Bridge_Event_M = procedure(Sender: TStream_Event_Bridge; SourceIO, BridgeIO: TPeerIO; Result_: TDFE) of object;

  {
    * Callback type: C-style console event bridge event handler.
    * Triggered by Console Event Bridge Engine.
    * Purpose: Intercept or route console string commands between two connections for protocol translation or forwarding.
    * @Param Sender: The bridge instance that triggered the event.
    * @Param SourceIO: The IO connection where the command originated.
    * @Param BridgeIO: The IO connection where the command is being bridged to.
    * @Param Result_: The console string being bridged.
  }
  TOnConsole_Event_Bridge_Event_C = procedure(Sender: TConsole_Event_Bridge; SourceIO, BridgeIO: TPeerIO; Result_: SystemString);

  {
    * Callback type: Method-style console event bridge event handler.
    * Triggered by Console Event Bridge Engine.
    * Purpose: Object-level console command routing interception supporting instance-based filtering or logging.
    * @Param Sender: The bridge instance that triggered the event.
    * @Param SourceIO: The IO connection where the command originated.
    * @Param BridgeIO: The IO connection where the command is being bridged to.
    * @Param Result_: The console string being bridged.
  }
  TOnConsole_Event_Bridge_Event_M = procedure(Sender: TConsole_Event_Bridge; SourceIO, BridgeIO: TPeerIO; Result_: SystemString) of object;

  {
    * Callback type: C-style P2PVM clone connection event handler.
    * Triggered by P2P Virtual Network Overlay Manager.
    * Purpose: Notify successful NAT traversal and tunnel establishment for virtual channel initialization.
    * @Param Sender: The cloned client instance that successfully connected.
  }
  TOnP2PVM_CloneConnectEvent_C = procedure(Sender: TZNet_WithP2PVM_Client);

  {
    * Callback type: Method-style P2PVM clone connection event handler.
    * Triggered by P2P Virtual Network Overlay Manager.
    * Purpose: Object-level P2P tunnel connection notification enabling multi-channel state maintenance in class.
    * @Param Sender: The cloned client instance that successfully connected.
  }
  TOnP2PVM_CloneConnectEvent_M = procedure(Sender: TZNet_WithP2PVM_Client) of object;

  {
    * Callback type: C-style stream command handler.
    * Triggered by TPeerIO Protocol Parser on stream command packet arrival.
    * Purpose: Execute stream command business logic and populate response payload via OutData parameter.
    * @Param Sender: The IO connection that received the command.
    * @Param InData: The input DFE containing the command payload.
    * @Param OutData: The output DFE to be filled with the response data.
  }
  TOnCommandStream_C = procedure(Sender: TPeerIO; InData, OutData: TDFE);

  {
    * Callback type: C-style console command handler.
    * Triggered by TPeerIO Protocol Parser on console command packet arrival.
    * Purpose: Execute console command business logic and return synchronous response string.
    * @Param Sender: The IO connection that received the command.
    * @Param InData: The input string containing the command data.
    * @Param OutData: The output string to be filled with the response (var parameter).
  }
  TOnCommandConsole_C = procedure(Sender: TPeerIO; InData: SystemString; var OutData: SystemString);

  {
    * Callback type: C-style direct stream notification handler (no reply).
    * Triggered by TPeerIO Protocol Parser on direct stream packet arrival.
    * Purpose: Process one-way stream data push without reply, suitable for real-time video or telemetry feeds.
    * @Param Sender: The IO connection that received the data.
    * @Param InData: The input DFE containing the data.
  }
  TOnCommandStreamNotify_C = procedure(Sender: TPeerIO; InData: TDFE);

  {
    * Callback type: C-style direct console notification handler (no reply).
    * Triggered by TPeerIO Protocol Parser on direct console packet arrival.
    * Purpose: Process one-way string command without reply, suitable for live logs or status broadcasts.
    * @Param Sender: The IO connection that received the data.
    * @Param InData: The input string containing the data.
  }
  TOnCommandConsoleNotify_C = procedure(Sender: TPeerIO; InData: SystemString);

  {
    * Callback type: C-style big-stream handler.
    * Triggered by TPeerIO Big Stream Handler on chunk or complete packet arrival.
    * Purpose: Handle large file or data stream reception progress and completion state for resume logic.
    * @Param Sender: The IO connection that received the stream.
    * @Param InData: The stream data being received.
    * @Param BigStreamTotal: The total size of the stream in bytes.
    * @Param BigStreamCompleteSize: The number of bytes received so far.
  }
  TOnCommandBigStream_C = procedure(Sender: TPeerIO; InData: TCore_Stream; BigStreamTotal, BigStreamCompleteSize: Int64);

  {
    * Callback type: C-style complete-buffer handler.
    * Triggered by TPeerIO Complete Buffer Reassembler after sequence validation passes.
    * Purpose: Process fully reassembled complete data block after network fragmentation and ordering.
    * @Param Sender: The IO connection that received the buffer.
    * @Param InData: Pointer to the reassembled data buffer.
    * @Param DataSize: The size of the data buffer in bytes.
  }
  TOnCommandCompleteBuffer_C = procedure(Sender: TPeerIO; InData: PByte; DataSize: NativeInt);

  {
    * Callback type: Method-style stream command handler.
    * Triggered by TPeerIO Protocol Parser on stream command packet arrival.
    * Purpose: Object-level stream command processing enabling multi-stream state management via instance fields.
    * @Param Sender: The IO connection that received the command.
    * @Param InData: The input DFE containing the command payload.
    * @Param OutData: The output DFE to be filled with the response data.
  }
  TOnCommandStream_M = procedure(Sender: TPeerIO; InData, OutData: TDFE) of object;

  {
    * Callback type: Method-style console command handler.
    * Triggered by TPeerIO Protocol Parser on console command packet arrival.
    * Purpose: Object-level console command processing allowing command context and response cache maintenance in class.
    * @Param Sender: The IO connection that received the command.
    * @Param InData: The input string containing the command data.
    * @Param OutData: The output string to be filled with the response (var parameter).
  }
  TOnCommandConsole_M = procedure(Sender: TPeerIO; InData: SystemString; var OutData: SystemString) of object;

  {
    * Callback type: Method-style direct stream notification handler (no reply).
    * Triggered by TPeerIO Protocol Parser on direct stream packet arrival.
    * Purpose: Object-level one-way stream processing for real-time data aggregation or state machine updates.
    * @Param Sender: The IO connection that received the data.
    * @Param InData: The input DFE containing the data.
  }
  TOnCommandStreamNotify_M = procedure(Sender: TPeerIO; InData: TDFE) of object;

  {
    * Callback type: Method-style direct console notification handler (no reply).
    * Triggered by TPeerIO Protocol Parser on direct console packet arrival.
    * Purpose: Object-level one-way command processing for event dispatching or broadcast log recording.
    * @Param Sender: The IO connection that received the data.
    * @Param InData: The input string containing the data.
  }
  TOnCommandConsoleNotify_M = procedure(Sender: TPeerIO; InData: SystemString) of object;

  {
    * Callback type: Method-style big-stream handler.
    * Triggered by TPeerIO Big Stream Handler on chunk or complete packet arrival.
    * Purpose: Object-level big stream processing for transfer state management with progress tracking or cache pools.
    * @Param Sender: The IO connection that received the stream.
    * @Param InData: The stream data being received.
    * @Param BigStreamTotal: The total size of the stream in bytes.
    * @Param BigStreamCompleteSize: The number of bytes received so far.
  }
  TOnCommandBigStream_M = procedure(Sender: TPeerIO; InData: TCore_Stream; BigStreamTotal, BigStreamCompleteSize: Int64) of object;

  {
    * Callback type: Method-style complete-buffer handler.
    * Triggered by TPeerIO Complete Buffer Reassembler after sequence validation passes.
    * Purpose: Object-level complete block processing for routing reassembled business data within class scope.
    * @Param Sender: The IO connection that received the buffer.
    * @Param InData: Pointer to the reassembled data buffer.
    * @Param DataSize: The size of the data buffer in bytes.
  }
  TOnCommandCompleteBuffer_M = procedure(Sender: TPeerIO; InData: PByte; DataSize: NativeInt) of object;

  {
    * Callback type: C-style progress event handler.
    * Triggered by TZNet Progress Engine Instance.
    * Purpose: Deliver async task progress update event for UI refresh or background synchronization.
    * @Param Sender: The TZNet_Progress instance that triggered the event.
  }
  TZNet_Progress_OnEvent_C = procedure(Sender: TZNet_Progress);

  {
    * Callback type: Method-style progress event handler.
    * Triggered by TZNet Progress Engine Instance.
    * Purpose: Object-level progress update allowing safe access to task context and configuration in class.
    * @Param Sender: The TZNet_Progress instance that triggered the event.
  }
  TZNet_Progress_OnEvent_M = procedure(Sender: TZNet_Progress) of object;

  {
    * Callback type: C-style automated P2PVM client connection done handler.
    * Triggered by Automated P2PVM Discovery Module on tunnel ready or timeout.
    * Purpose: Notify client virtual network channel is operational and pass connection handle for subsequent communication.
    * @Param Sender: The TZNet instance that initiated the P2PVM connection.
    * @Param P_IO: The IO connection that was established.
  }
  TOnAutomatedP2PVMClientConnectionDone_C = procedure(Sender: TZNet; P_IO: TPeerIO);

  {
    * Callback type: Method-style automated P2PVM client connection done handler.
    * Triggered by Automated P2PVM Discovery Module on tunnel ready or timeout.
    * Purpose: Object-level P2P channel ready notification supporting auto-tunnel state maintenance in class.
    * @Param Sender: The TZNet instance that initiated the P2PVM connection.
    * @Param P_IO: The IO connection that was established.
  }
  TOnAutomatedP2PVMClientConnectionDone_M = procedure(Sender: TZNet; P_IO: TPeerIO) of object;

  {
    * Callback type: Progress free event.
    * Triggered by TZNet Progress Engine during destruction or release.
    * Purpose: Notify resource cleanup and garbage collection for associated async tasks or memory caches.
    * @Param Sender: The TZNet_Progress instance being freed.
  }
  TZNet_Progress_Free_OnEvent = procedure(Sender: TZNet_Progress) of object;

  {
    * Callback type: C-style complete-buffer bridge stream command handler.
    * Triggered by Non-blocking Complete Buffer Bridge Component.
    * Purpose: Process stream bridging data without waiting for reassembly and handle in/out payloads.
    * @Param Sender: The bridge component that triggered the event.
    * @Param InData: The input DFE.
    * @Param OutData: The output DFE to be filled with response data.
  }
  TOnCommand_CompleteBuffer_NoWait_Bridge_Stream_C = procedure(Sender: TCommandCompleteBuffer_NoWait_Bridge; InData, OutData: TDFE);

  {
    * Callback type: Method-style complete-buffer bridge stream command handler.
    * Triggered by Non-blocking Complete Buffer Bridge Component.
    * Purpose: Object-level non-blocking stream bridge processing enabling instance-based routing or flow control.
    * @Param Sender: The bridge component that triggered the event.
    * @Param InData: The input DFE.
    * @Param OutData: The output DFE to be filled with response data.
  }
  TOnCommand_CompleteBuffer_NoWait_Bridge_Stream_M = procedure(Sender: TCommandCompleteBuffer_NoWait_Bridge; InData, OutData: TDFE) of object;

  {
    * Callback type: C-style complete-buffer stream bridge completion handler.
    * Triggered by Complete Buffer Stream Event Bridge after reassembly completes.
    * Purpose: Notify underlying bridge component that data is fully ordered and pass final payload for consumption.
    * @Param Sender: The event bridge that triggered the event.
    * @Param Source_Bridge: The underlying no-wait bridge that provided the data.
    * @Param BridgeIO: The IO connection where the data is being bridged to.
    * @Param Result_: The fully reassembled DFE data.
  }
  TOnCompleteBuffer_Stream_Event_Bridge_C = procedure(Sender: TCompleteBuffer_Stream_Event_Bridge; Source_Bridge: TCommandCompleteBuffer_NoWait_Bridge; BridgeIO: TPeerIO; Result_: TDFE);

  {
    * Callback type: Method-style complete-buffer stream bridge completion handler.
    * Triggered by Complete Buffer Stream Event Bridge after reassembly completes.
    * Purpose: Object-level reassembly completion notification triggering downstream business logic or state machine transition.
    * @Param Sender: The event bridge that triggered the event.
    * @Param Source_Bridge: The underlying no-wait bridge that provided the data.
    * @Param BridgeIO: The IO connection where the data is being bridged to.
    * @Param Result_: The fully reassembled DFE data.
  }
  TOnCompleteBuffer_Stream_Event_Bridge_M = procedure(Sender: TCompleteBuffer_Stream_Event_Bridge; Source_Bridge: TCommandCompleteBuffer_NoWait_Bridge; BridgeIO: TPeerIO; Result_: TDFE) of object;

{$IFDEF FPC}
  {
    * Nested procedure equivalents for all callback types (FPC only).
    * These allow callbacks to capture local variables from the enclosing scope.
    * Triggered by the same events as their C/M counterparts.
    * Purpose: Same as C/M versions, but with nested/local variable capture support.
  }
  TOnConsole_P = procedure(Sender: TPeerIO; Result_: SystemString) is nested;
  TOnConsoleParam_P = procedure(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: SystemString) is nested;
  TOnConsoleFailed_P = procedure(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: SystemString) is nested;
  TOnStream_P = procedure(Sender: TPeerIO; Result_: TDFE) is nested;
  TOnStreamParam_P = procedure(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: TDFE) is nested;
  TOnStreamFailed_P = procedure(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: TDFE) is nested;
  TOnState_P = procedure(const State: Boolean) is nested;
  TOnIOState_P = procedure(P_IO: TPeerIO; State: Boolean) is nested;
  TOnParamState_P = procedure(Param1: Pointer; Param2: TObject; const State: Boolean) is nested;
  TOnNotify_P = procedure() is nested;
  TOnDataNotify_P = procedure(data: TCore_Object) is nested;
  TOnIONotify_P = procedure(P_IO: TPeerIO) is nested;
  TOnStream_Event_Bridge_Event_P = procedure(Sender: TStream_Event_Bridge; SourceIO, BridgeIO: TPeerIO; Result_: TDFE) is nested;
  TOnConsole_Event_Bridge_Event_P = procedure(Sender: TConsole_Event_Bridge; SourceIO, BridgeIO: TPeerIO; Result_: SystemString) is nested;
  TOnP2PVM_CloneConnectEvent_P = procedure(Sender: TZNet_WithP2PVM_Client) is nested;
  TOnCommandStream_P = procedure(Sender: TPeerIO; InData, OutData: TDFE) is nested;
  TOnCommandConsole_P = procedure(Sender: TPeerIO; InData: SystemString; var OutData: SystemString) is nested;
  TOnCommandStreamNotify_P = procedure(Sender: TPeerIO; InData: TDFE) is nested;
  TOnCommandConsoleNotify_P = procedure(Sender: TPeerIO; InData: SystemString) is nested;
  TOnCommandBigStream_P = procedure(Sender: TPeerIO; InData: TCore_Stream; BigStreamTotal, BigStreamCompleteSize: Int64) is nested;
  TOnCommandCompleteBuffer_P = procedure(Sender: TPeerIO; InData: PByte; DataSize: NativeInt) is nested;
  TZNet_Progress_OnEvent_P = procedure(Sender: TZNet_Progress) is nested;
  TOnAutomatedP2PVMClientConnectionDone_P = procedure(Sender: TZNet; P_IO: TPeerIO) is nested;
  TOnCommand_CompleteBuffer_NoWait_Bridge_Stream_P = procedure(Sender: TCommandCompleteBuffer_NoWait_Bridge; InData, OutData: TDFE) is nested;
  TOnCompleteBuffer_Stream_Event_Bridge_P = procedure(Sender: TCompleteBuffer_Stream_Event_Bridge; Source_Bridge: TCommandCompleteBuffer_NoWait_Bridge; BridgeIO: TPeerIO; Result_: TDFE) is nested;
{$ELSE FPC}
  {
    * Reference-to-procedure equivalents for all callback types (Delphi only).
    * These are anonymous methods that can capture local variables.
    * Triggered by the same events as their C/M counterparts.
    * Purpose: Same as C/M versions, with anonymous method capture support.
  }
  TOnConsole_P = reference to procedure(Sender: TPeerIO; Result_: SystemString);
  TOnConsoleParam_P = reference to procedure(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: SystemString);
  TOnConsoleFailed_P = reference to procedure(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: SystemString);
  TOnStream_P = reference to procedure(Sender: TPeerIO; Result_: TDFE);
  TOnStreamParam_P = reference to procedure(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: TDFE);
  TOnStreamFailed_P = reference to procedure(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: TDFE);
  TOnState_P = reference to procedure(const State: Boolean);
  TOnIOState_P = reference to procedure(P_IO: TPeerIO; State: Boolean);
  TOnParamState_P = reference to procedure(Param1: Pointer; Param2: TObject; const State: Boolean);
  TOnNotify_P = reference to procedure();
  TOnDataNotify_P = reference to procedure(data: TCore_Object);
  TOnIONotify_P = reference to procedure(P_IO: TPeerIO);
  TOnStream_Event_Bridge_Event_P = reference to procedure(Sender: TStream_Event_Bridge; SourceIO, BridgeIO: TPeerIO; Result_: TDFE);
  TOnConsole_Event_Bridge_Event_P = reference to procedure(Sender: TConsole_Event_Bridge; SourceIO, BridgeIO: TPeerIO; Result_: SystemString);
  TOnP2PVM_CloneConnectEvent_P = reference to procedure(Sender: TZNet_WithP2PVM_Client);
  TOnCommandStream_P = reference to procedure(Sender: TPeerIO; InData, OutData: TDFE);
  TOnCommandConsole_P = reference to procedure(Sender: TPeerIO; InData: SystemString; var OutData: SystemString);
  TOnCommandStreamNotify_P = reference to procedure(Sender: TPeerIO; InData: TDFE);
  TOnCommandConsoleNotify_P = reference to procedure(Sender: TPeerIO; InData: SystemString);
  TOnCommandBigStream_P = reference to procedure(Sender: TPeerIO; InData: TCore_Stream; BigStreamTotal, BigStreamCompleteSize: Int64);
  TOnCommandCompleteBuffer_P = reference to procedure(Sender: TPeerIO; InData: PByte; DataSize: NativeInt);
  TZNet_Progress_OnEvent_P = reference to procedure(Sender: TZNet_Progress);
  TOnAutomatedP2PVMClientConnectionDone_P = reference to procedure(Sender: TZNet; P_IO: TPeerIO);
  TOnCommand_CompleteBuffer_NoWait_Bridge_Stream_P = reference to procedure(Sender: TCommandCompleteBuffer_NoWait_Bridge; InData, OutData: TDFE);
  TOnCompleteBuffer_Stream_Event_Bridge_P = reference to procedure(Sender: TCompleteBuffer_Stream_Event_Bridge; Source_Bridge: TCommandCompleteBuffer_NoWait_Bridge; BridgeIO: TPeerIO; Result_: TDFE);
{$ENDIF FPC}

  {
    * TIO_ID_Pool: Pool of IO IDs (Cardinals).
    * Uses TBigList to store and manage connection IDs with recycling capability.
    * Each TPeerIO instance is assigned a unique ID from this pool or a generator.
  }
  TIO_ID_Pool = class(TBigList<Cardinal>)
  end;

  {
    * TIO_ID_List: Simple list of IO IDs.
    * Uses TGenericsList for basic storage and iteration of connection identifiers.
  }
  TIO_ID_List = class(TGenericsList<Cardinal>)
  end;

  {
    * TOnStateStruct: Structure holding three styles of state callback.
    * Allows a single event to be handled by C-style, method, or nested procedure.
    * This provides flexibility for different programming styles and scoping needs.
    * @Field On_C: C-style callback.
    * @Field On_M: Method-style callback.
    * @Field On_P: Nested/reference callback.
  }
  TOnStateStruct = record
    On_C: TOnState_C;
    On_M: TOnState_M;
    On_P: TOnState_P;
    procedure Init;
  end;

  POnStateStruct = ^TOnStateStruct;

  {
    * TOnResult_Bridge_Templet: Base class for bridging callbacks.
    * Provides virtual methods for console, stream, and complete-buffer result handling.
    * Subclasses override these to implement custom behaviour.
    * This is the foundation for the bridge pattern used throughout the framework.
    * @Example:
    *   type
    *     TMyBridge = class(TOnResult_Bridge_Templet)
    *       procedure DoStreamEvent(Sender: TPeerIO; Result_: TDFE); override;
    *     end;
    *   // Then:
    *   Bridge := TMyBridge.Create;
    *   // The bridge will automatically receive and process stream results.
  }
  TOnResult_Bridge_Templet = class(TCore_Object_Intermediate)
  public
    procedure DoConsoleEvent(Sender: TPeerIO; Result_: SystemString); virtual;
    procedure DoConsoleParamEvent(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: SystemString); virtual;
    procedure DoConsoleFailedEvent(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: SystemString); virtual;
    procedure DoStreamEvent(Sender: TPeerIO; Result_: TDFE); virtual;
    procedure DoStreamParamEvent(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: TDFE); virtual;
    procedure DoStreamFailedEvent(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: TDFE); virtual;
    procedure DoCompleteBufferStreamEvent(Sender: TCommandCompleteBuffer_NoWait_Bridge; InData, OutData: TDFE); virtual;
  end;

  {
    * TOnResult_Bridge: Concrete bridge implementation.
    * Provides a ready-to-use bridge instance. Can be extended or used directly.
  }
  TOnResult_Bridge = class(TOnResult_Bridge_Templet)
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TOnResultBridge = TOnResult_Bridge;

  {
    * TProgress_Bridge: Bridge that attaches a progress callback to a TZNet instance.
    * Used to receive periodic progress notifications from the framework.
    * @Example:
    *   var Bridge: TProgress_Bridge;
    *   begin
    *     Bridge := TProgress_Bridge.Create(MyNet);
    *     // Override Progress method to handle progress events.
    *   end;
  }
  TProgress_Bridge = class(TCore_Object_Intermediate)
  private
    procedure DoFree(Sender: TZNet_Progress);
  public
    Framework: TZNet; { Target framework. Assigned by constructor. }
    ProgressInstance: TZNet_Progress; { Progress event instance. Created by constructor. }
    constructor Create(Framework_: TZNet); virtual;
    destructor Destroy; override;
    procedure Progress(Sender: TZNet_Progress); virtual;
  end;

  {
    * TState_Param_Bridge: Bridges a parameterised state callback.
    * Holds user parameters and invokes the appropriate callback when the state changes.
    * Automatically frees itself after delivery.
    * @Example:
    *   Bridge := TState_Param_Bridge.Create;
    *   Bridge.Param1 := MyPointer;
    *   Bridge.Param2 := MyObject;
    *   Bridge.OnNotifyC := MyStateHandler;
    *   // When the state changes, DoStateResult is called with the parameters.
  }
  TState_Param_Bridge = class(TCore_Object_Intermediate)
  public
    OnNotifyC: TOnParamState_C; { C-style callback. Set by caller. }
    OnNotifyM: TOnParamState_M; { Method callback. Set by caller. }
    OnNotifyP: TOnParamState_P; { Nested/reference callback. Set by caller. }
    Param1: Pointer; { User parameter 1. Set by caller. }
    Param2: TObject; { User parameter 2. Set by caller. }
    OnStateMethod: TOnState_M; { Internal state method. Set by constructor. }
    constructor Create; virtual;
    destructor Destroy; override;
    procedure DoStateResult(const State: Boolean);
  end;

  {
    * TCustom_Event_Bridge: Base class for event bridges attached to a specific IO.
    * Monitors a single IO connection and provides a progress hook.
    * @Example:
    *   Bridge := TCustom_Event_Bridge.Create(MyIO);
    *   // Override Progress method to handle IO-specific events.
  }
  TCustom_Event_Bridge = class(TCore_Object_Intermediate)
  private
    procedure DoFree(Sender: TZNet_Progress);
  public
    Framework_: TZNet; { Parent framework. Set by constructor. }
    ID_: Cardinal; { IO identifier. Set by constructor. }
    ProgressInstance: TZNet_Progress; { Progress event. Created by constructor. }
    constructor Create(IO_: TPeerIO); virtual;
    destructor Destroy; override;
    function CheckIO: Boolean; virtual;
    function IO: TPeerIO; virtual;
    procedure Progress(Sender: TZNet_Progress); virtual;
  end;

  TCustomEventBridge = TCustom_Event_Bridge;

  {
    * TStream_Event_Bridge: Stream-oriented event bridge.
    * Attaches to a stream command and provides a callback when the result is received.
    * Supports pause/resume of the result send.
    * @Example:
    *   var Bridge: TStream_Event_Bridge;
    *   begin
    *     Bridge := TStream_Event_Bridge.Create(MyIO);
    *     Bridge.OnResultC := MyStreamHandler;  // Handle the result
    *     // Data will be processed when the response arrives.
    *   end;
  }
  TStream_Event_Bridge = class(TCore_Object_Intermediate)
  private
    procedure Init(IO_: TPeerIO; AutoPause_: Boolean);
    procedure DoFree(Sender: TZNet_Progress);
  public
    Framework_: TZNet; { Parent framework. Set by Init. }
    ID_: Cardinal; { IO identifier. Set by Init. }
    LCMD_: SystemString; { Command name. Set by Init. }
    ProgressInstance: TZNet_Progress; { Progress event. Created by Init. }
    OnResultC: TOnStream_Event_Bridge_Event_C; { C-style callback. Set by user. }
    OnResultM: TOnStream_Event_Bridge_Event_M; { Method callback. Set by user. }
    OnResultP: TOnStream_Event_Bridge_Event_P; { Nested/reference callback. Set by user. }
    AutoPause: Boolean; { Whether to auto-pause result sending. Set by constructor. }
    AutoFree: Boolean; { Whether to auto-free after completion. Set by constructor. }
    constructor Create(IO_: TPeerIO; AutoPause_: Boolean); overload;
    constructor Create(IO_: TPeerIO); overload;
    destructor Destroy; override;
    procedure Pause;
    procedure Play(ResultData_: TDFE);
    procedure DoStreamParamEvent(Sender_: TPeerIO; Param1_: Pointer; Param2_: TObject; SendData_, ResultData_: TDFE); virtual;
    procedure DoStreamFailed(Sender_: TPeerIO; Param1: Pointer; Param2: TObject; SendData_: TDFE); virtual;
    procedure DoStreamEvent(Sender_: TPeerIO; ResultData_: TDFE); virtual;
    procedure Progress(Sender: TZNet_Progress); virtual;
  end;

  {
    * TConsole_Event_Bridge: Console-oriented event bridge.
    * Similar to TStream_Event_Bridge but for console (string) commands.
    * @Example:
    *   var Bridge: TConsole_Event_Bridge;
    *   begin
    *     Bridge := TConsole_Event_Bridge.Create(MyIO);
    *     Bridge.OnResultC := MyConsoleHandler;
    *     // String response will be delivered to the handler.
    *   end;
  }
  TConsole_Event_Bridge = class(TCore_Object_Intermediate)
  private
    procedure Init(IO_: TPeerIO; AutoPause_: Boolean);
    procedure DoFree(Sender: TZNet_Progress);
  public
    Framework_: TZNet; { Parent framework. Set by Init. }
    ID_: Cardinal; { IO identifier. Set by Init. }
    LCMD_: SystemString; { Command name. Set by Init. }
    ProgressInstance: TZNet_Progress; { Progress event. Created by Init. }
    OnResultC: TOnConsole_Event_Bridge_Event_C; { C-style callback. Set by user. }
    OnResultM: TOnConsole_Event_Bridge_Event_M; { Method callback. Set by user. }
    OnResultP: TOnConsole_Event_Bridge_Event_P; { Nested/reference callback. Set by user. }
    AutoPause: Boolean; { Whether to auto-pause result sending. Set by constructor. }
    AutoFree: Boolean; { Whether to auto-free after completion. Set by constructor. }
    constructor Create(IO_: TPeerIO; AutoPause_: Boolean); overload;
    constructor Create(IO_: TPeerIO); overload;
    destructor Destroy; override;
    procedure Pause;
    procedure Play(ResultData_: SystemString);
    procedure DoConsoleParamEvent(Sender_: TPeerIO; Param1_: Pointer; Param2_: TObject; SendData_, ResultData_: SystemString); virtual;
    procedure DoStreamFailed(Sender_: TPeerIO; Param1: Pointer; Param2: TObject; SendData_: SystemString);
    procedure DoConsoleEvent(Sender_: TPeerIO; ResultData_: SystemString); virtual;
    procedure Progress(Sender: TZNet_Progress); virtual;
  end;

  {
    * TCustom_CompleteBuffer_Stream_Bridge: Base bridge for complete-buffer streams.
    * Provides progress monitoring for no-wait complete-buffer operations.
  }
  TCustom_CompleteBuffer_Stream_Bridge = class(TCore_Object_Intermediate)
  private
    procedure DoFree(Sender: TZNet_Progress);
  public
    Bridge: TCommandCompleteBuffer_NoWait_Bridge; { Associated bridge. Set by constructor. }
    ProgressInstance: TZNet_Progress; { Progress event. Created by constructor. }
    constructor Create(Bridge_: TCommandCompleteBuffer_NoWait_Bridge); virtual;
    destructor Destroy; override;
    function CheckIO: Boolean; virtual;
    function IO: TPeerIO; virtual;
    procedure Progress(Sender: TZNet_Progress); virtual;
  end;

  {
    * TCompleteBuffer_Stream_Event_Bridge: Event bridge for complete-buffer commands.
    * Handles callbacks for commands registered with RegisterCompleteBuffer_NoWait_Bridge_Stream.
    * @Example:
    *   // Register a bridge command:
    *   Net.RegisterCompleteBuffer_NoWait_Bridge_Stream('myBridgeCmd').OnExecute := MyBridgeHandler;
    *   // Then create a bridge event:
    *   Bridge := TCompleteBuffer_Stream_Event_Bridge.Create(MyBridge);
    *   Bridge.OnResultC := MyCompletionHandler;
  }
  TCompleteBuffer_Stream_Event_Bridge = class(TCore_Object_Intermediate)
  private
    procedure Init(Bridge_: TCommandCompleteBuffer_NoWait_Bridge; AutoPause_: Boolean);
    procedure DoFree(Sender: TZNet_Progress);
  public
    Framework_: TZNet; { Parent framework. Set by Init. }
    Bridge: TCommandCompleteBuffer_NoWait_Bridge; { Source bridge. Set by Init. }
    LCMD_: SystemString; { Command name. Set by Init. }
    ProgressInstance: TZNet_Progress; { Progress event. Created by Init. }
    OnResultC: TOnCompleteBuffer_Stream_Event_Bridge_C; { C-style callback. Set by user. }
    OnResultM: TOnCompleteBuffer_Stream_Event_Bridge_M; { Method callback. Set by user. }
    OnResultP: TOnCompleteBuffer_Stream_Event_Bridge_P; { Nested/reference callback. Set by user. }
    AutoPause: Boolean; { Whether to auto-pause result sending. Set by constructor. }
    AutoFree: Boolean; { Whether to auto-free after completion. Set by constructor. }
    constructor Create(Bridge_: TCommandCompleteBuffer_NoWait_Bridge; AutoPause_: Boolean); overload;
    constructor Create(Bridge_: TCommandCompleteBuffer_NoWait_Bridge); overload;
    destructor Destroy; override;
    procedure Pause;
    procedure Play(ResultData_: TDFE);
    procedure DoStreamEvent(Sender_: TPeerIO; ResultData_: TDFE); virtual;
    procedure Progress(Sender: TZNet_Progress); virtual;
  end;

  {
    * TP2PVM_CloneConnectEventBridge: Bridges clone connection events for P2PVM.
    * Used when creating a clone client via TZNet_WithP2PVM_Client.CloneConnect*.
    * @Example:
    *   var Bridge: TP2PVM_CloneConnectEventBridge;
    *   begin
    *     Bridge := SourceClient.CloneConnectM(MyCloneHandler);
    *     // The handler receives the new clone client when connection is ready.
    *   end;
  }
  TP2PVM_CloneConnectEventBridge = class(TCore_Object_Intermediate)
  private
    OnResultC: TOnP2PVM_CloneConnectEvent_C; { C-style callback. Set by caller. }
    OnResultM: TOnP2PVM_CloneConnectEvent_M; { Method callback. Set by caller. }
    OnResultP: TOnP2PVM_CloneConnectEvent_P; { Nested/reference callback. Set by caller. }
    procedure DoAsyncConnectState(const State: Boolean);
  public
    Source: TZNet_WithP2PVM_Client; { Source client for cloning. Set by constructor. }
    NewClient: TZNet_WithP2PVM_Client; { Newly created clone client. Set during connection. }
    constructor Create(Source_: TZNet_WithP2PVM_Client);
    destructor Destroy; override;
  end;

  {
    * TDoubleTunnel_IO_ID: Record for double-tunnel IO identification.
    * Contains both receive (R) and send (S) tunnel IDs for a single logical connection.
    * Used in double-tunnel scenarios where send and receive use separate channels.
    * @Field R: Receive tunnel ID.
    * @Field S: Send tunnel ID.
  }
  TDoubleTunnel_IO_ID = record
    R, S: Cardinal;
  end;

  TDoubleTunnel_IO_ID_Big_List = class(TBigList<TDoubleTunnel_IO_ID>); { Big list for double-tunnel IO IDs. }

  TDoubleTunnel_IO_ID_List = class(TGenericsList<TDoubleTunnel_IO_ID>) { Generic list for double-tunnel IO IDs with helper. }
  public
    procedure Add_DT_ID(R, S: Cardinal);
  end;
{$ENDREGION 'base Decl'}
{$REGION 'CacheTechnology'}

  TFile_Swap_Space_Stream = class; { A file stream that uses a swap space pool for temporary storage of large data. }

  {
    * TFile_Swap_Space_Pool: Pool managing TFile_Swap_Space_Stream instances.
    * All streams in the pool share a common working directory and are automatically cleaned up.
    * @Field WorkPath: Working directory for swap files. Set by user.
    * @Example:
    *   var Pool: TFile_Swap_Space_Pool;
    *   begin
    *     Pool := TFile_Swap_Space_Pool.Create;
    *     Pool.WorkPath := './temp';
    *     // Streams created using this pool will store temporary files in './temp'.
    *   end;
  }
  TFile_Swap_Space_Pool = class(TCritical_BigList<TFile_Swap_Space_Stream>)
  public
    WorkPath: U_String; { Working directory for swap files. Set by user. }
    constructor Create;
    destructor Destroy; override;
    procedure DoFree(var data: TFile_Swap_Space_Stream); override;
    function CompareData(const Data_1, Data_2: TFile_Swap_Space_Stream): Boolean; override;
    class function RunTime_Pool(): TFile_Swap_Space_Pool;
  end;

  {
    * TFile_Swap_Space_Stream: A file stream that belongs to a swap space pool.
    * Created by Create_BigStream to store large data in temporary files.
    * @Field FOwnerSwapSpace: Owner pool. Set by Create_BigStream.
    * @Field FPoolPtr: Pointer in owner pool. Set by Create_BigStream.
    * @Example:
    *   var Stream: TFile_Swap_Space_Stream;
    *   begin
    *     Stream := TFile_Swap_Space_Stream.Create_BigStream(MyLargeData, MyPool);
    *     // The stream is automatically managed and cleaned up when freed.
    *   end;
  }
  TFile_Swap_Space_Stream = class(TCore_FileStream)
  private
    FOwnerSwapSpace: TFile_Swap_Space_Pool; { Owner pool. Set by Create_BigStream. }
    FPoolPtr: TFile_Swap_Space_Pool.PQueueStruct; { Pointer in owner pool. Set by Create_BigStream. }
  public
    class function Create_BigStream(stream_: TCore_Stream; OwnerSwapSpace_: TFile_Swap_Space_Pool): TFile_Swap_Space_Stream;
    destructor Destroy; override;
  end;

  TZDB2_Swap_Space_Technology_Memory = class; { Forward declaration for ZDB2 swap memory. }

  {
    * TZDB2_Swap_Space_Technology: A ZDB2-based swap space for complete buffers.
    * Uses a ZDB2 database to store large buffers on disk with optional encryption.
    * Provides a persistent, transactional swap area.
    * @Example:
    *   var Swap: TZDB2_Swap_Space_Technology;
    *   begin
    *     Swap := TZDB2_Swap_Space_Technology.RunTime_Pool;
    *     Mem := Swap.Create_Memory(Data, DataSize, False);
    *     // Mem can be used as a persistent memory object backed by the database.
    *   end;
  }
  TZDB2_Swap_Space_Technology = class(TZDB2_Core_Space)
  public
    class var ZDB2_Swap_Space_Pool___: TZDB2_Swap_Space_Technology;
    class var ZDB2_Swap_Space_Pool_Cipher___: TZDB2_Cipher;
  private
    tmp_swap_space_file: U_String; { Temporary database file. Set by constructor. }
    procedure DoNoSpace(Trigger: TZDB2_Core_Space; Siz_: Int64; var retry: Boolean);
  public
    Critical: TCritical; { Synchronisation lock. Created by constructor. }
    constructor Create();
    destructor Destroy; override;
    function Create_Memory(buff: PByte; BuffSiz: NativeInt; BuffProtected_: Boolean): TZDB2_Swap_Space_Technology_Memory;
    class function RunTime_Pool(): TZDB2_Swap_Space_Technology;
  end;

  {
    * TZDB2_Swap_Space_Technology_Memory: A memory view into a ZDB2 swap entry.
    * Allows a large buffer to be stored in the ZDB2 swap space and later retrieved as a TMem64.
    * @Field FOwner: Owner swap space. Set by constructor.
    * @Field FID: Database entry ID. Set by constructor.
    * @Example:
    *   var Mem: TZDB2_Swap_Space_Technology_Memory;
    *   begin
    *     Mem := TZDB2_Swap_Space_Technology_Memory.Create(MySwap, 123);
    *     if Mem.Prepare then  // Load data from the database
    *       UseData(Mem.Memory, Mem.Size);
    *   end;
  }
  TZDB2_Swap_Space_Technology_Memory = class(TMem64)
  private
    FOwner: TZDB2_Swap_Space_Technology; { Owner swap space. Set by constructor. }
    FID: Integer; { Database entry ID. Set by constructor. }
  public
    constructor Create(); overload;
    constructor Create(Owner_: TZDB2_Swap_Space_Technology; ID_: Integer); overload;
    destructor Destroy; override;
    function Prepare: Boolean;
  end;
{$ENDREGION 'CacheTechnology'}
{$REGION 'Queue'}

  {
    * TQueueState: Possible states for a queued command.
    * Determines how the command will be processed and sent.
    * @Enum qsUnknow: Unknown state.
    * @Enum qsSendConsoleCMD: Send a console command and expect a result.
    * @Enum qsSendStreamCMD: Send a stream command and expect a result.
    * @Enum qsSendConsoleNotifyCMD: Send a console notification (no reply expected).
    * @Enum qsSendStreamNotifyCMD: Send a stream notification (no reply expected).
    * @Enum qsSendBigStream: Send a large stream (file transfer).
    * @Enum qsSendCompleteBuffer: Send a complete buffer (atomic data block).
  }
  TQueueState = (
    qsUnknow,
    qsSendConsoleCMD,
    qsSendStreamCMD,
    qsSendConsoleNotifyCMD,
    qsSendStreamNotifyCMD,
    qsSendBigStream,
    qsSendCompleteBuffer
    );

  {
    * TQueueData: A complete command to be sent to a remote peer.
    * Contains all information needed to send a command, including the command name,
    * payload (console string, stream, or buffer), cipher settings, and callback handlers.
    * @Field IP: Remote IP address. Set by NewQueueData.
    * @Field State: Command type. Set by sender.
    * @Field IO_ID: Target IO identifier. Set by NewQueueData.
    * @Field Cmd: Command name. Set by sender.
    * @Field Cipher: Cipher for this command. Set by sender.
    * @Field ConsoleData: Payload for console commands. Set by sender.
    * @Field StreamData: Payload for stream commands. Set by sender.
    * @Field BigStream: Payload for big-stream commands. Set by sender.
    * @Field Buffer: Raw buffer for complete-buffer commands. Set by sender.
    * @Field BufferSize: Size of Buffer. Set by sender.
    * @Field Buffer_Swap_Memory: Swap memory for large buffers. Set by sender.
    * @Field DoneAutoFree: Whether to auto-free payload after send. Set by sender.
    * @Field Param1: User parameter 1. Set by sender.
    * @Field Param2: User parameter 2. Set by sender.
    * @Example:
    *   var Q: PQueueData;
    *   begin
    *     Q := NewQueueData(MyIO);
    *     Q^.State := qsSendConsoleCMD;
    *     Q^.Cmd := 'ping';
    *     Q^.ConsoleData := 'hello';
    *     Q^.OnConsoleM := MyResultHandler;
    *     MyIO.PostQueueData(Q);  // Sends asynchronously
    *   end;
  }
  TQueueData = record
    IP: SystemString;
    State: TQueueState;
    IO_ID: Cardinal;
    Cmd: SystemString;
    Cipher: TCipherSecurity;
    ConsoleData: SystemString;
    OnConsoleM: TOnConsole_M;
    OnConsoleParamM: TOnConsoleParam_M;
    OnConsoleFailedM: TOnConsoleFailed_M;
    OnConsoleP: TOnConsole_P;
    OnConsoleParamP: TOnConsoleParam_P;
    OnConsoleFailedP: TOnConsoleFailed_P;
    StreamData: TMS64;
    OnStreamM: TOnStream_M;
    OnStreamParamM: TOnStreamParam_M;
    OnStreamFailedM: TOnStreamFailed_M;
    OnStreamP: TOnStream_P;
    OnStreamParamP: TOnStreamParam_P;
    OnStreamFailedP: TOnStreamFailed_P;
    BigStreamStartPos: Int64;
    BigStream: TCore_Stream;
    Buffer: PByte;
    BufferSize: NativeInt;
    Buffer_Swap_Memory: TZDB2_Swap_Space_Technology_Memory;
    DoneAutoFree: Boolean;
    Param1: Pointer;
    Param2: TObject;
  end;

  PQueueData = ^TQueueData;

  TQueueData_Order = class(TOrderStruct<PQueueData>); { FIFO queue for queue data items (non-thread-safe). }
  TQueueData_Pool = class(TBigList<PQueueData>);
{$ENDREGION 'Queue'}
{$REGION 'Command_Instance'}

  TCommand_base = class(TCore_Object_Intermediate) { Abstract base class for all registered commands. }
  public
  end;

  {
    * TCommandStream: Command that receives and returns a DFE (stream) payload.
    * @Field FOnExecute_C: C-style handler. Set by user.
    * @Field FOnExecute_M: Method handler. Set by user.
    * @Field FOnExecute_P: Nested/reference handler. Set by user.
    * @Example:
    *   // Register a stream command:
    *   var Cmd: TCommandStream;
    *   begin
    *     Cmd := MyNet.RegisterStream('myStreamCmd');
    *     Cmd.OnExecute := procedure(Sender: TPeerIO; InData, OutData: TDFE)
    *     begin
    *       // Process InData and fill OutData with response
    *       OutData.WriteString('response');
    *     end;
    *   end;
    *   // Then send from client:
    *   MyClient.SendStreamCmd('myStreamCmd', MyData);
  }
  TCommandStream = class(TCommand_base)
  protected
    FOnExecute_C: TOnCommandStream_C; { C-style handler. Set by user. }
    FOnExecute_M: TOnCommandStream_M; { Method handler. Set by user. }
    FOnExecute_P: TOnCommandStream_P; { Nested/reference handler. Set by user. }
  public
    constructor Create;
    destructor Destroy; override;
    function Execute(Sender: TPeerIO; InData, OutData: TDFE): Boolean;
    function Execute_Complete_Stream(Sender: TPeerIO; InData: PByte; DataSize: NativeInt): Boolean;
    property OnExecute: TOnCommandStream_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_C: TOnCommandStream_C read FOnExecute_C write FOnExecute_C;
    property OnExecute_M: TOnCommandStream_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_P: TOnCommandStream_P read FOnExecute_P write FOnExecute_P;
  end;

  {
    * TCommandConsole: Command that receives and returns a string (console) payload.
    * @Field FOnExecute_C: C-style handler. Set by user.
    * @Field FOnExecute_M: Method handler. Set by user.
    * @Field FOnExecute_P: Nested/reference handler. Set by user.
    * @Example:
    *   var Cmd: TCommandConsole;
    *   begin
    *     Cmd := MyNet.RegisterConsole('ping');
    *     Cmd.OnExecute := procedure(Sender: TPeerIO; InData: string; var OutData: string)
    *     begin
    *       OutData := 'pong: ' + InData;
    *     end;
    *   end;
    *   // Send from client:
    *   var Response := MyClient.SendConsoleCmd('ping', 'hello');
  }
  TCommandConsole = class(TCommand_base)
  protected
    FOnExecute_C: TOnCommandConsole_C; { C-style handler. Set by user. }
    FOnExecute_M: TOnCommandConsole_M; { Method handler. Set by user. }
    FOnExecute_P: TOnCommandConsole_P; { Nested/reference handler. Set by user. }
  public
    constructor Create;
    destructor Destroy; override;
    function Execute(Sender: TPeerIO; InData: SystemString; var OutData: SystemString): Boolean;
    property OnExecute: TOnCommandConsole_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_C: TOnCommandConsole_C read FOnExecute_C write FOnExecute_C;
    property OnExecute_M: TOnCommandConsole_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_P: TOnCommandConsole_P read FOnExecute_P write FOnExecute_P;
  end;

  {
    * TCommandStreamNotify: Command that receives a DFE but sends no reply (fire-and-forget).
    * @Field FOnExecute_C: C-style handler. Set by user.
    * @Field FOnExecute_M: Method handler. Set by user.
    * @Field FOnExecute_P: Nested/reference handler. Set by user.
    * @Example:
    *   var Cmd: TCommandStreamNotify;
    *   begin
    *     Cmd := MyNet.RegisterStreamNotify('log');
    *     Cmd.OnExecute := procedure(Sender: TPeerIO; InData: TDFE)
    *     begin
    *       // Log the data, no reply needed
    *     end;
    *   end;
    *   // Send from client (no response expected):
    *   MyClient.SendStreamNotifyCmd('log', MyData);
  }
  TCommandStreamNotify = class(TCommand_base)
  protected
    FOnExecute_C: TOnCommandStreamNotify_C; { C-style handler. Set by user. }
    FOnExecute_M: TOnCommandStreamNotify_M; { Method handler. Set by user. }
    FOnExecute_P: TOnCommandStreamNotify_P; { Nested/reference handler. Set by user. }
  public
    constructor Create;
    destructor Destroy; override;
    function Execute(Sender: TPeerIO; InData: TDFE): Boolean;
    property OnExecute: TOnCommandStreamNotify_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_C: TOnCommandStreamNotify_C read FOnExecute_C write FOnExecute_C;
    property OnExecute_M: TOnCommandStreamNotify_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_P: TOnCommandStreamNotify_P read FOnExecute_P write FOnExecute_P;
  end;

  {
    * TCommandConsoleNotify: Command that receives a string but sends no reply (fire-and-forget).
    * @Field FOnExecute_C: C-style handler. Set by user.
    * @Field FOnExecute_M: Method handler. Set by user.
    * @Field FOnExecute_P: Nested/reference handler. Set by user.
    * @Example:
    *   var Cmd: TCommandConsoleNotify;
    *   begin
    *     Cmd := MyNet.RegisterConsoleNotify('status');
    *     Cmd.OnExecute := procedure(Sender: TPeerIO; InData: string)
    *     begin
    *       // Update status, no reply needed
    *     end;
    *   end;
  }
  TCommandConsoleNotify = class(TCommand_base)
  protected
    FOnExecute_C: TOnCommandConsoleNotify_C; { C-style handler. Set by user. }
    FOnExecute_M: TOnCommandConsoleNotify_M; { Method handler. Set by user. }
    FOnExecute_P: TOnCommandConsoleNotify_P; { Nested/reference handler. Set by user. }
  public
    constructor Create;
    destructor Destroy; override;
    function Execute(Sender: TPeerIO; InData: SystemString): Boolean;
    property OnExecute: TOnCommandConsoleNotify_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_C: TOnCommandConsoleNotify_C read FOnExecute_C write FOnExecute_C;
    property OnExecute_M: TOnCommandConsoleNotify_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_P: TOnCommandConsoleNotify_P read FOnExecute_P write FOnExecute_P;
  end;

  {
    * TCommandBigStream: Command that receives a stream (big data) with progress tracking.
    * @Field FOnExecute_C: C-style handler. Set by user.
    * @Field FOnExecute_M: Method handler. Set by user.
    * @Field FOnExecute_P: Nested/reference handler. Set by user.
    * @Example:
    *   var Cmd: TCommandBigStream;
    *   begin
    *     Cmd := MyNet.RegisterBigStream('upload');
    *     Cmd.OnExecute := procedure(Sender: TPeerIO; InData: TCore_Stream; Total, Complete: Int64)
    *     begin
    *       // Stream the file to disk or database
    *       MyFileStream.CopyFrom(InData, Total - Complete);
    *     end;
    *   end;
    *   // Send a large file:
    *   MyClient.SendBigStream('upload', MyFileStream);
  }
  TCommandBigStream = class(TCommand_base)
  protected
    FOnExecute_C: TOnCommandBigStream_C; { C-style handler. Set by user. }
    FOnExecute_M: TOnCommandBigStream_M; { Method handler. Set by user. }
    FOnExecute_P: TOnCommandBigStream_P; { Nested/reference handler. Set by user. }
  public
    constructor Create;
    destructor Destroy; override;
    function Execute(Sender: TPeerIO; InData: TCore_Stream; BigStreamTotal, BigStreamCompleteSize: Int64): Boolean;
    property OnExecute: TOnCommandBigStream_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_C: TOnCommandBigStream_C read FOnExecute_C write FOnExecute_C;
    property OnExecute_M: TOnCommandBigStream_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_P: TOnCommandBigStream_P read FOnExecute_P write FOnExecute_P;
  end;

  {
    * TCommandCompleteBuffer: Command that receives a raw complete buffer (pre-assembled).
    * @Field FOnExecute_C: C-style handler. Set by user.
    * @Field FOnExecute_M: Method handler. Set by user.
    * @Field FOnExecute_P: Nested/reference handler. Set by user.
    * @Example:
    *   var Cmd: TCommandCompleteBuffer;
    *   begin
    *     Cmd := MyNet.RegisterCompleteBuffer('rawData');
    *     Cmd.OnExecute := procedure(Sender: TPeerIO; InData: PByte; DataSize: NativeInt)
    *     begin
    *       // Process raw data block
    *       ProcessMyData(InData, DataSize);
    *     end;
    *   end;
  }
  TCommandCompleteBuffer = class(TCommand_base)
  protected
    FOnExecute_C: TOnCommandCompleteBuffer_C; { C-style handler. Set by user. }
    FOnExecute_M: TOnCommandCompleteBuffer_M; { Method handler. Set by user. }
    FOnExecute_P: TOnCommandCompleteBuffer_P; { Nested/reference handler. Set by user. }
  public
    constructor Create;
    destructor Destroy; override;
    function Execute(Sender: TPeerIO; InData: PByte; DataSize: NativeInt): Boolean;
    property OnExecute: TOnCommandCompleteBuffer_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_C: TOnCommandCompleteBuffer_C read FOnExecute_C write FOnExecute_C;
    property OnExecute_M: TOnCommandCompleteBuffer_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_P: TOnCommandCompleteBuffer_P read FOnExecute_P write FOnExecute_P;
  end;

  TCommandCompleteBuffer_StreamNotify = class; { Internal thread class for async decryption of complete buffers. }

  {
    * TCommandCompleteBuffer_StreamNotify_Thread: Thread for asynchronous decryption of complete buffers.
    * Processes data in the background to avoid blocking the main thread.
  }
  TCommandCompleteBuffer_StreamNotify_Thread = class(TCore_Object_Intermediate)
  protected
    Owner: TCommandCompleteBuffer_StreamNotify; { Owner command. Set by constructor. }
    Framework: TZNet; { Parent framework. Set by constructor. }
    ID: Cardinal; { IO identifier. Set by constructor. }
    buff: TMS64; { Buffer to decrypt. Set by constructor. }
    procedure Do_Run_Decrypt_Thread(thSender: TCompute);
    procedure Do_Post_Run(Sender: TN_Post_Execute);
  public
    constructor Create;
    destructor Destroy; override;
  end;

  {
    * TCommandCompleteBuffer_StreamNotify: Variant that decodes the complete buffer into a DFE.
    * Executes synchronously or asynchronously depending on Sync_Decrypt flag.
    * @Field FOnExecute_C: C-style handler. Set by user.
    * @Field FOnExecute_M: Method handler. Set by user.
    * @Field FOnExecute_P: Nested/reference handler. Set by user.
    * @Field FSync_Decrypt: Whether to decrypt synchronously. Set by user.
    * @Field FDecript_Activted_Thread_Num: Active decryption threads. Managed internally.
    * @Example:
    *   var Cmd: TCommandCompleteBuffer_StreamNotify;
    *   begin
    *     Cmd := MyNet.RegisterCompleteBuffer_StreamNotify('decryptData');
    *     Cmd.Sync_Decrypt := False;  // Process asynchronously
    *     Cmd.OnExecute := procedure(Sender: TPeerIO; InData: TDFE)
    *     begin
    *       // Process the decrypted data
    *     end;
    *   end;
  }
  TCommandCompleteBuffer_StreamNotify = class(TCommand_base)
  protected
    FOnExecute_C: TOnCommandStreamNotify_C; { C-style handler. Set by user. }
    FOnExecute_M: TOnCommandStreamNotify_M; { Method handler. Set by user. }
    FOnExecute_P: TOnCommandStreamNotify_P; { Nested/reference handler. Set by user. }
    FSync_Decrypt: Boolean; { Whether to decrypt synchronously. Set by user. }
    FDecript_Activted_Thread_Num: Integer; { Active decryption threads. Managed internally. }
  public
    constructor Create;
    destructor Destroy; override;
    function Execute(Sender: TPeerIO; InData: PByte; DataSize: NativeInt): Boolean;
    property OnExecute: TOnCommandStreamNotify_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_C: TOnCommandStreamNotify_C read FOnExecute_C write FOnExecute_C;
    property OnExecute_M: TOnCommandStreamNotify_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_P: TOnCommandStreamNotify_P read FOnExecute_P write FOnExecute_P;
    property Sync_Decrypt: Boolean read FSync_Decrypt write FSync_Decrypt;
  end;

  TCommandCompleteBuffer_NoWait_Stream = class; { Data record for no-wait stream commands. }

  {
    * TCommandCompleteBuffer_NoWait_Stream_Data: Data record for no-wait stream commands.
    * Holds callback references and ID for the response handler.
    * @Field ID: IO identifier. Set by sender.
    * @Field OnStreamM: Method callback. Set by sender.
    * @Field OnStreamP: Nested callback. Set by sender.
  }
  TCommandCompleteBuffer_NoWait_Stream_Data = record
    ID: Cardinal;
    OnStreamM: TOnStream_M;
    OnStreamP: TOnStream_P;
    procedure Init();
  end;

  PCommandCompleteBuffer_NoWait_Stream_Data = ^TCommandCompleteBuffer_NoWait_Stream_Data;

  {
    * TCommandCompleteBuffer_NoWait_Stream_Execute_Thread: Thread for executing no-wait stream commands.
    * Runs the command in a background thread to avoid blocking the main loop.
  }
  TCommandCompleteBuffer_NoWait_Stream_Execute_Thread = class(TCore_Object_Intermediate)
  protected
    Owner: TCommandCompleteBuffer_NoWait_Stream; { Owner command. Set by constructor. }
    R_Framework: TZNet; { Receive framework. Set by constructor. }
    R_ID: Cardinal; { Receive IO ID. Set by constructor. }
    S_Framework: TZNet; { Send framework. Set by constructor. }
    S_ID: Cardinal; { Send IO ID. Set by constructor. }
    buff: TMS64; { Buffer to process. Set by constructor. }
    procedure Do_Execute_Thread(thSender: TCompute);
  public
    constructor Create;
    destructor Destroy; override;
  end;

  {
    * TCommandCompleteBuffer_NoWait_Stream: High-speed, non-blocking stream command.
    * Executes without waiting for a reply. Can be run on the main thread or in a background thread.
    * @Field FOnExecute_C: C-style handler. Set by user.
    * @Field FOnExecute_M: Method handler. Set by user.
    * @Field FOnExecute_P: Nested/reference handler. Set by user.
    * @Field FExecute_In_Thread: Whether to execute in a background thread. Set by user.
    * @Field FExecute_Activted_Thread_Num: Active execution threads. Managed internally.
    * @Example:
    *   var Cmd: TCommandCompleteBuffer_NoWait_Stream;
    *   begin
    *     Cmd := MyNet.RegisterCompleteBuffer_NoWait_Stream('fastData');
    *     Cmd.Execute_In_Thread := True;  // Run in background thread
    *     Cmd.OnExecute := procedure(Sender: TPeerIO; InData, OutData: TDFE)
    *     begin
    *       // Process data, no wait for response
    *     end;
    *   end;
  }
  TCommandCompleteBuffer_NoWait_Stream = class(TCommand_base)
  protected
    FOnExecute_C: TOnCommandStream_C; { C-style handler. Set by user. }
    FOnExecute_M: TOnCommandStream_M; { Method handler. Set by user. }
    FOnExecute_P: TOnCommandStream_P; { Nested/reference handler. Set by user. }
    FExecute_In_Thread: Boolean; { Whether to execute in a background thread. Set by user. }
    FExecute_Activted_Thread_Num: Integer; { Active execution threads. Managed internally. }
  public
    constructor Create;
    destructor Destroy; override;
    function Execute(Sender: TPeerIO; InData: PByte; DataSize: NativeInt): Boolean;
    property OnExecute: TOnCommandStream_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_C: TOnCommandStream_C read FOnExecute_C write FOnExecute_C;
    property OnExecute_M: TOnCommandStream_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_P: TOnCommandStream_P read FOnExecute_P write FOnExecute_P;
    property Execute_In_Thread: Boolean read FExecute_In_Thread write FExecute_In_Thread;
  end;

  {
    * TCommandCompleteBuffer_NoWait_Bridge_Stream: Advanced bridge command.
    * Provides pause/resume capability for the result send, allowing the command handler to delay its response.
    * @Field FOnExecute_C: C-style handler. Set by user.
    * @Field FOnExecute_M: Method handler. Set by user.
    * @Field FOnExecute_P: Nested/reference handler. Set by user.
    * @Example:
    *   var Cmd: TCommandCompleteBuffer_NoWait_Bridge_Stream;
    *   begin
    *     Cmd := MyNet.RegisterCompleteBuffer_NoWait_Bridge_Stream('bridgeCmd');
    *     Cmd.OnExecute := procedure(Bridge: TCommandCompleteBuffer_NoWait_Bridge; InData, OutData: TDFE)
    *     begin
    *       // Process data
    *       Bridge.Pause;  // Pause response sending
    *       // ... later ...
    *       Bridge.Resume; // Send the response
    *     end;
    *   end;
  }
  TCommandCompleteBuffer_NoWait_Bridge_Stream = class(TCommand_base)
  protected
    FOnExecute_C: TOnCommand_CompleteBuffer_NoWait_Bridge_Stream_C; { C-style handler. Set by user. }
    FOnExecute_M: TOnCommand_CompleteBuffer_NoWait_Bridge_Stream_M; { Method handler. Set by user. }
    FOnExecute_P: TOnCommand_CompleteBuffer_NoWait_Bridge_Stream_P; { Nested/reference handler. Set by user. }
  public
    constructor Create;
    destructor Destroy; override;
    function Execute(Sender: TPeerIO; InData: PByte; DataSize: NativeInt): Boolean;
    property OnExecute: TOnCommand_CompleteBuffer_NoWait_Bridge_Stream_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_C: TOnCommand_CompleteBuffer_NoWait_Bridge_Stream_C read FOnExecute_C write FOnExecute_C;
    property OnExecute_M: TOnCommand_CompleteBuffer_NoWait_Bridge_Stream_M read FOnExecute_M write FOnExecute_M;
    property OnExecute_P: TOnCommand_CompleteBuffer_NoWait_Bridge_Stream_P read FOnExecute_P write FOnExecute_P;
  end;

  {
    * TCommandCompleteBuffer_NoWait_Bridge: Bridge instance for no-wait commands.
    * Holds the incoming and outgoing DFE data, and allows the command handler to pause result sending.
    * @Field Pause_Result_Send: Whether result send is paused. Set by Pause/Resume.
    * @Field Owner: Owner command. Set by Execute.
    * @Field Cmd: Command name. Set by Execute.
    * @Field R_Framework: Receive framework. Set by Execute.
    * @Field R_ID: Receive IO ID. Set by Execute.
    * @Field S_Framework: Send framework. Set by Execute.
    * @Field S_ID: Send IO ID. Set by Execute.
    * @Field UserData: User data token. Set by Execute.
    * @Field InData, OutData: Input and output data frames. Created by constructor.
    * @Example:
    *   // Inside a bridge command handler:
    *   Bridge.Pause;                  // Delay the response
    *   // ... perform async operation ...
    *   Bridge.OutData.WriteString('result');
    *   Bridge.Resume;                 // Send the response
  }
  TCommandCompleteBuffer_NoWait_Bridge = class(TCore_Object_Intermediate)
  private
    Pause_Result_Send: Boolean; { Whether result send is paused. Set by Pause/Resume. }
  public
    Owner: TCommandCompleteBuffer_NoWait_Bridge_Stream; { Owner command. Set by Execute. }
    Cmd: SystemString; { Command name. Set by Execute. }
    R_Framework: TZNet; { Receive framework. Set by Execute. }
    R_ID: Cardinal; { Receive IO ID. Set by Execute. }
    S_Framework: TZNet; { Send framework. Set by Execute. }
    S_ID: Cardinal; { Send IO ID. Set by Execute. }
    UserData: UInt64; { User data token. Set by Execute. }
    InData, OutData: TDFE; { Input and output data frames. Created by constructor. }
    constructor Create;
    destructor Destroy; override;
    function R_IO: TPeerIO;
    function S_IO: TPeerIO;
    procedure Pause;
    procedure PauseResultSend;
    procedure BreakResultSend;
    procedure SkipResultSend;
    procedure NoResultSend;
    procedure StopResultSend;
    procedure Resume;
    procedure ContinueResultSend;
    procedure Continue_Send_Result;
    procedure ResumeResultSend;
    procedure NowResultSend;
    property InDataFrame: TDFE read InData;
    property InDFE: TDFE read InData;
    property OutDataFrame: TDFE read OutData;
    property OutDFE: TDFE read OutData;
    property ResultSendIsPaused: Boolean read Pause_Result_Send;
    property ResultIsPaused: Boolean read Pause_Result_Send;
  end;
{$ENDREGION 'Command_Instance'}
{$REGION 'IO_MISC'}

  PBigStreamBatchPostData = ^TBigStreamBatchPostData; { Data for a big-stream batch post operation. }

  {
    * TBigStreamBatchPostData: Data for a big-stream batch post operation.
    * Manages the state of a single large file transfer in a batch.
    * @Field Source: Source data. Created by NewPostData.
    * @Field CompletedBackcallPtr: Pointer to completion callback. Set by sender.
    * @Field RemoteMD5: MD5 of remote data. Set by sender.
    * @Field SourceMD5: MD5 of source data. Computed during processing.
    * @Field index: Index in list. Set by NewPostData.
    * @Field DBStorePos: Database storage position. Set by storage layer.
  }
  TBigStreamBatchPostData = record
    Source: TMS64;
    CompletedBackcallPtr: UInt64;
    RemoteMD5: TMD5;
    SourceMD5: TMD5;
    index: Integer;
    DBStorePos: Int64;
    procedure Init;
    procedure Encode(d: TDFE);
    procedure Decode(d: TDFE);
  end;

  TBigStreamBatchPostData_List = class(TGenericsList<PBigStreamBatchPostData>); { List of big-stream batch post data pointers. }

  {
    * TBigStreamBatch: Manages a batch of big-stream posts.
    * Used to queue multiple file transfers or large data blocks for sequential or parallel processing.
    * @Field FOwner: Owner IO. Set by constructor.
    * @Field FList: Internal list. Created by constructor.
    * @Example:
    *   var Batch: TBigStreamBatch;
    *   var Data: PBigStreamBatchPostData;
    *   begin
    *     Batch := MyIO.BigStreamBatch;
    *     Data := Batch.NewPostData;
    *     Data.Source := MyData;  // Set the data to transfer
    *     // The batch manages multiple transfers
    *   end;
  }
  TBigStreamBatch = class(TCore_Object_Intermediate)
  protected
    FOwner: TPeerIO; { Owner IO. Set by constructor. }
    FList: TBigStreamBatchPostData_List; { Internal list. Created by constructor. }
    function GetItems(const index: Integer): PBigStreamBatchPostData;
  public
    constructor Create(Owner_: TPeerIO);
    destructor Destroy; override;
    procedure Clear;
    function Count: Integer;
    property Items[const index: Integer]: PBigStreamBatchPostData read GetItems; default;
    function NewPostData: PBigStreamBatchPostData;
    function First: PBigStreamBatchPostData;
    function Last: PBigStreamBatchPostData;
    procedure DeleteLast;
    procedure Delete(const index: Integer);
  end;

  {
    * TPeer_IO_User_Define: User-extensible per-IO object.
    * Each TPeerIO can have an associated user-defined instance that persists for the lifetime of the connection.
    * @Field FOwner: Owner IO. Set by constructor.
    * @Field FWorkPlatform: Execution platform. Set by user.
    * @Field FBigStreamBatch: Batch stream list. Created by constructor.
    * @Field FBusy: Busy flag. Set by user.
    * @Field FBusyNum: Busy counter. Managed internally.
    * @Example:
    *   type
    *     TMyIOData = class(TPeer_IO_User_Define)
    *       MyCustomData: Integer;
    *     end;
    *   // Then in the server:
    *   Net.UserDefineClass := TMyIOData;
    *   // Each connection now has MyCustomData available via IO.UserDefine
  }
  TPeer_IO_User_Define = class(TCore_InterfacedObject_Intermediate)
  private
    FOwner: TPeerIO; { Owner IO. Set by constructor. }
    FWorkPlatform: TExecutePlatform; { Execution platform. Set by user. }
    FBigStreamBatch: TBigStreamBatch; { Batch stream list. Created by constructor. }
    FBusy: Boolean; { Busy flag. Set by user. }
    FBusyNum: Integer; { Busy counter. Managed internally. }
    procedure DelayFreeOnBusy;
  public
    constructor Create(Owner_: TPeerIO); virtual;
    destructor Destroy; override;
    procedure Progress; virtual;
    property Owner: TPeerIO read FOwner;
    property WorkPlatform: TExecutePlatform read FWorkPlatform write FWorkPlatform;
    property BigStreamBatchList: TBigStreamBatch read FBigStreamBatch;
    property BigStreamBatch: TBigStreamBatch read FBigStreamBatch;
    property BatchStream: TBigStreamBatch read FBigStreamBatch;
    property BatchList: TBigStreamBatch read FBigStreamBatch;
    property Busy: Boolean read FBusy write FBusy;
    function BusyNum: PInteger;
  end;

  TPeer_IO_User_Define_Class = class of TPeer_IO_User_Define;

  {
    * TPeer_IO_User_Special: A second user-extensible per-IO object.
    * Allows two separate user objects to be attached to the same IO.
    * Similar to UserDefine but provides a second independent storage slot.
    * @Field FOwner: Owner IO. Set by constructor.
    * @Field FBusy: Busy flag. Set by user.
    * @Field FBusyNum: Busy counter. Managed internally.
  }
  TPeer_IO_User_Special = class(TCore_InterfacedObject_Intermediate)
  private
    FOwner: TPeerIO; { Owner IO. Set by constructor. }
    FBusy: Boolean; { Busy flag. Set by user. }
    FBusyNum: Integer; { Busy counter. Managed internally. }
    procedure DelayFreeOnBusy;
  public
    constructor Create(Owner_: TPeerIO); virtual;
    destructor Destroy; override;
    procedure Progress; virtual;
    property Owner: TPeerIO read FOwner;
    property Busy: Boolean read FBusy write FBusy;
    function BusyNum: PInteger;
  end;

  TPeer_IO_User_Special_Class = class of TPeer_IO_User_Special;

  TPeerClientUserDefine = TPeer_IO_User_Define; { Aliases for convenience. }
  TPeerClientUserSpecial = TPeer_IO_User_Special;

  PSequencePacket = ^TSequencePacket; { Sequence packet structure used in the reliable packet model. }

  {
    * TSequencePacket: Sequence packet structure used in the reliable ordered packet model.
    * Each packet has a unique sequence number, payload size, hash for verification, and timestamp.
    * @Field SequenceNumber: Packet sequence number. Set by sender.
    * @Field Size: Data size. Set by sender.
    * @Field hash: Data hash. Computed by sender.
    * @Field data: Packet payload. Set by sender.
    * @Field tick: Timestamp. Set by sender.
  }
  TSequencePacket = record
    SequenceNumber: Cardinal;
    Size: Word;
    hash: TMD5;
    data: TMS64;
    tick: TTimeTick;
  end;

  PIDLE_Trace = ^TIDLE_Trace; { IDLE trace data for delayed execution when IO becomes idle. }

  {
    * TIDLE_Trace: IDLE trace data for delayed execution when IO becomes idle.
    * Stores a callback to be executed when the IO is no longer busy.
    * @Field ID: IO identifier. Set by tracer.
    * @Field data: User data. Set by tracer.
    * @Field OnNotifyC: C-style callback. Set by tracer.
    * @Field OnNotifyM: Method callback. Set by tracer.
    * @Field OnNotifyP: Nested/reference callback. Set by tracer.
  }
  TIDLE_Trace = record
    ID: Cardinal;
    data: TCore_Object;
    OnNotifyC: TOnDataNotify_C;
    OnNotifyM: TOnDataNotify_M;
    OnNotifyP: TOnDataNotify_P;
  end;

  PP2PVM_ECHO = ^TP2PVM_ECHO; { P2PVM echo record for keep-alive and latency measurement. }
  TP2PVM_ECHO_List = TGenericsList<PP2PVM_ECHO>;

  {
    * TP2PVM_ECHO: P2PVM echo record for keep-alive and latency measurement.
    * Used for ping-like functionality over the P2PVM tunnel.
    * @Field OnEcho_C: C-style echo callback. Set by caller.
    * @Field OnEcho_M: Method echo callback. Set by caller.
    * @Field OnEcho_P: Nested/reference echo callback. Set by caller.
    * @Field TimeOut_: Timeout tick. Set by caller.
  }
  TP2PVM_ECHO = record
    OnEcho_C: TOnState_C;
    OnEcho_M: TOnState_M;
    OnEcho_P: TOnState_P;
    TimeOut_: TTimeTick;
  end;

  {
    * TBigStreamFragmentHead: Header for a big-stream fragment.
    * Contains the fragment size and compression flag.
    * @Field Size: Fragment size. Set by sender.
    * @Field Compressed: Whether fragment is compressed. Set by sender.
  }
  TBigStreamFragmentHead = packed record
    Size: Integer;
    Compressed: Boolean;
  end;

  PBigStreamFragmentHead = ^TBigStreamFragmentHead;
{$ENDREGION 'IO_MISC'}
{$REGION 'IO'}
  TInternalSendByteBuffer = procedure(const Sender: TPeerIO; const buff: PByte; siz: NativeInt) of object;
  TInternalSaveReceiveBuffer = procedure(const Sender: TPeerIO; const buff: Pointer; siz: Int64) of object;
  TInternalProcessReceiveBuffer = procedure(const Sender: TPeerIO) of object;
  TInternalProcessSendBuffer = procedure(const Sender: TPeerIO) of object;
  TInternal_IO_Create = procedure(const Sender: TPeerIO) of object;
  TInternal_IO_Destory = procedure(const Sender: TPeerIO) of object;

  TSequence_Packet_Hash_Pool = TBig_Hash_Pair_Pool<Cardinal, PSequencePacket>; { Hash pool for sequence packets keyed by sequence number. }

  TPhysics_Fragment_Pool_Decl = TOrderStruct<TMem64>; { FIFO pool for physics fragments (raw received data). }

  {
    * TPhysics_Fragment_Pool: FIFO pool for physics fragments.
    * Automatically frees data when removed from the pool.
  }
  TPhysics_Fragment_Pool = class(TPhysics_Fragment_Pool_Decl)
  public
    procedure DoFree(var data: TMem64); override;
  end;

  TZNet_P2PVM = class;

  {
    * TPeerIO: Core per-connection state machine.
    * This class manages all aspects of a single network connection, including:
    * - Send and receive queues
    * - Command parsing and execution
    * - Big-stream and complete-buffer reassembly
    * - Sequence-packet reliability
    * - P2P virtual machine (P2PVM) tunnelling
    * - Encryption/decryption
    * - User-defined data storage
    * It is the fundamental building block of the Z.Net framework.
    * @Field FOwnerFramework: Parent framework. Set by constructor.
    * @Field FIOInterface: External interface object. Set by constructor.
    * @Field FDisable_Progress: Disable progress flag.
    * @Field FID: Unique IO identifier. Assigned by OwnerFramework.
    * @Field FIO_Create_TimeTick: Creation timestamp. Set by constructor.
    * @Field FHeadToken: Protocol head token. Set by constructor.
    * @Field FTailToken: Protocol tail token. Set by constructor.
    * @Field FConsoleToken: Console command token. Set by constructor.
    * @Field FStreamToken: Stream command token. Set by constructor.
    * @Field FConsoleNotifyToken: Direct console token. Set by constructor.
    * @Field FStreamNotifyToken: Direct stream token. Set by constructor.
    * @Field FBigStreamToken: Big-stream command token. Set by constructor.
    * @Field FBigStreamReceiveFragmentSignal: Fragment signal token. Set by constructor.
    * @Field FBigStreamReceiveDoneSignal: Done signal token. Set by constructor.
    * @Field FCompleteBufferToken: Complete-buffer token. Set by constructor.
    * @Field FReceived_Physics_Critical: Lock for fragment pool. Created by constructor.
    * @Field FReceived_Physics_Fragment_Pool: Incoming fragment pool. Created by constructor.
    * @Field FReceivedBuffer: Primary receive buffer. Created by constructor.
    * @Field FReceivedBuffer_Busy: Secondary buffer for busy state. Created by constructor.
    * @Field FBigStreamReceiveProcessing: Whether a big-stream is being received.
    * @Field FBigStreamTotal: Total size of receiving big-stream.
    * @Field FBigStreamCompleted: Bytes completed for receiving big-stream.
    * @Field FBigStreamCmd: Command name of receiving big-stream.
    * @Field FSyncBigStreamReceive: Stream being received synchronously.
    * @Field FBigStreamSending: Stream currently being sent.
    * @Field FCompleteBufferReceiveProcessing: Whether a complete-buffer is being received.
    * @Field FCompleteBufferTotal: Total size of receiving buffer.
    * @Field FCompleteBufferCompressedSize: Compressed size (0 if not compressed).
    * @Field FCompleteBufferCompleted: Bytes completed.
    * @Field FCompleteBufferCmd: Command name.
    * @Field FCompleteBufferReceivedStream: Stream being assembled.
    * @Field FCompleteBuffer_Current_Trigger: Current trigger buffer.
    * @Field FCurrentQueueData: Currently processed queue item.
    * @Field FWaitOnResult: Waiting for a result.
    * @Field FPause_Result_Send: Whether result send is paused.
    * @Field FReceiveTriggerRuning: Receive trigger running flag.
    * @Field FReceiveDataCipherSecurity: Cipher for received data.
    * @Field FResultDataBuffer: Buffer for result data.
    * @Field FSendDataCipherSecurity: Cipher for sent data.
    * @Field FCipherKey: Cipher key. Generated by constructor.
    * @Field FDecryptInstance: Decryption instance. Created on demand.
    * @Field FEncryptInstance: Encryption instance. Created on demand.
    * @Field FSend_Queue_Critical: Lock for send queue. Created by constructor.
    * @Field FSend_Queue_Pool: Send queue. Created by constructor.
    * @Field FLastCommunicationTick: Last communication timestamp. Updated by writes.
    * @Field FRemoteExecutedForConnectInit: Whether remote init is done.
    * @Field FInCmd: Current incoming command.
    * @Field FInText: Incoming console data.
    * @Field FOutText: Outgoing console data.
    * @Field FInDataFrame: Incoming stream data.
    * @Field FOutDataFrame: Outgoing stream data.
    * @Field FResult_Text: Result text for console.
    * @Field FResult_DFE: Result stream data.
    * @Field FSyncPick: Queue item being processed synchronously.
    * @Field FWaitSendBusy: Wait-send busy flag.
    * @Field FReceiveCommandRuning: Command execution flag.
    * @Field FReceiveResultRuning: Result execution flag.
    * @Field FProgressRunning: Progress re-entry guard.
    * @Field FTimeOutProcessDone: Timeout processing done flag.
    * @Field FLast_IO_Is_IDLE: Last idle state.
    * @Field FLast_IO_IDLE_Time: Last idle timestamp.
    * @Example:
    *   // TPeerIO is created by the framework when a connection is established.
    *   // Users typically interact with it through TZNet methods.
    *   MyIO.SendConsoleCmd('ping', 'hello');  // Send a command
    *   MyIO.UserDefine.MyCustomData := 123;   // Store custom data
  }
  TPeerIO = class(TCore_InterfacedObject_Intermediate)
  private
    FOwnerFramework: TZNet; { Parent framework. Set by constructor. }

    FIOInterface: TCore_Object; { External interface object. Set by constructor. }

    FDisable_Progress: Boolean; { disable progress }

    FID: Cardinal; { Unique IO identifier. Assigned by OwnerFramework. }
    FIO_Create_TimeTick: TTimeTick; { Creation timestamp. Set by constructor. }

    FHeadToken: Cardinal; { Protocol head token. Set by constructor. }
    FTailToken: Cardinal; { Protocol tail token. Set by constructor. }

    FConsoleToken: Byte; { Console command token. Set by constructor. }
    FStreamToken: Byte; { Stream command token. Set by constructor. }
    FConsoleNotifyToken: Byte; { Direct console token. Set by constructor. }
    FStreamNotifyToken: Byte; { Direct stream token. Set by constructor. }
    FBigStreamToken: Byte; { Big-stream command token. Set by constructor. }
    FBigStreamReceiveFragmentSignal: Byte; { Fragment signal token. Set by constructor. }
    FBigStreamReceiveDoneSignal: Byte; { Done signal token. Set by constructor. }
    FCompleteBufferToken: Byte; { Complete-buffer token. Set by constructor. }

    FReceived_Physics_Critical: TCritical; { Lock for fragment pool. Created by constructor. }
    FReceived_Physics_Fragment_Pool: TPhysics_Fragment_Pool; { Incoming fragment pool. Created by constructor. }
    FLast_Process_Receive_Buffer_CPU_Is_Full: Boolean; { Whether last receive loop hit limit. Set by Internal_Process_Receive_Buffer. }
    FReceivedAbort: Boolean; { Abort flag. Set by Internal_Process_Receive_Buffer. }
    FReceivedBuffer: TMS64; { Primary receive buffer. Created by constructor. }
    FReceivedBuffer_Busy: TMS64; { Secondary buffer for busy state. Created by constructor. }

    FBigStreamReceiveProcessing: Boolean; { Whether a big-stream is being received. Set by protocol parser. }
    FBigStreamTotal: Int64; { Total size of receiving big-stream. Set by protocol parser. }
    FBigStreamCompleted: Int64; { Bytes completed for receiving big-stream. Set by protocol parser. }
    FBigStream_Current_Received: Int64; { Current received bytes. Set by protocol parser. }
    FBigStreamFragmentSignal_SendedState: Boolean; { True if the "request next fragment" signal has already been sent for the current fragment, preventing duplicate requests while waiting for remaining data. }
    FBigStreamCmd: SystemString; { Command name of receiving big-stream. Set by protocol parser. }
    FSyncBigStreamReceive: TCore_Stream; { Stream being received synchronously. Set by protocol parser. }
    FBigStreamSending: TCore_Stream; { Stream currently being sent. Set by Internal_Send_BigStream_Cmd. }
    FBigStreamSendCurrentPos: Int64; { Current send position. Set by Internal_Send_BigStream_Cmd. }
    FBigStreamSendDoneTimeFree: Boolean; { Whether to free stream after send. Set by Internal_Send_BigStream_Cmd. }
    FWaitBigStreamReceiveDoneSignal: Boolean; { Waiting for done signal. Set by Internal_Send_BigStream_Cmd. }

    FCompleteBufferReceiveProcessing: Boolean; { Whether a complete-buffer is being received. Set by protocol parser. }
    FCompleteBufferTotal: Cardinal; { Total size of receiving buffer. Set by protocol parser. }
    FCompleteBufferCompressedSize: Cardinal; { Compressed size (0 if not compressed). Set by protocol parser. }
    FCompleteBufferCompleted: Cardinal; { Bytes completed. Set by protocol parser. }
    FCompleteBufferCmd: SystemString; { Command name. Set by protocol parser. }
    FCompleteBufferReceivedStream: TMS64; { Stream being assembled. Created by constructor. }
    FCompleteBuffer_Current_Trigger: TMS64; { Current trigger buffer. Set by Internal_Execute_CompleteBuffer. }

    FCurrentQueueData: PQueueData; { Currently processed queue item. Set by Internal_Process_Send_Buffer. }
    FWaitOnResult: Boolean; { Waiting for a result. Set by Internal_Process_Send_Buffer. }
    FCurrentPauseResultSend_CommDataType: Byte; { Data type of paused result. Set by ExecuteDataFrame. }
    FCanPauseResultSend: Boolean; { Whether result send can be paused. Set by ExecuteDataFrame. }
    FPause_Result_Send: Boolean; { Whether result send is paused. Set by Pause/Resume. }
    FReceiveTriggerRuning: Boolean; { Receive trigger running flag. Set by ExecuteDataFrame. }
    FReceiveDataCipherSecurity: TCipherSecurity; { Cipher for received data. Set by protocol parser. }
    FResultDataBuffer: TMS64; { Buffer for result data. Created by constructor. }
    FSendDataCipherSecurity: TCipherSecurity; { Cipher for sent data. Set by constructor. }
    FCipherKey: TCipherKeyBuffer; { Cipher key. Generated by constructor. }
    FDecryptInstance: TCipher_Tool_Base; { Decryption instance. Created on demand. }
    FEncryptInstance: TCipher_Tool_Base; { Encryption instance. Created on demand. }
    FAllSendProcessing: Boolean; { Send processing flag. Set by Internal_Process_Send_Buffer. }
    FReceiveProcessing: Boolean; { Receive processing flag. Set by Internal_Process_Receive_Buffer. }
    FSend_Queue_Critical: TCritical; { Lock for send queue. Created by constructor. }
    FSend_Queue_Pool: TQueueData_Order; { Send queue. Created by constructor. }
    FLastCommunicationTick: TTimeTick; { Last communication timestamp. Updated by writes. }
    LastCommunicationTick_Received: TTimeTick; { Last receive timestamp. Updated on receive. }
    LastCommunicationTick_KeepAlive: TTimeTick; { Last keep-alive timestamp. Updated by keep-alive. }
    LastCommunicationTick_Sending: TTimeTick; { Last send timestamp. Updated on send. }
    FRemoteExecutedForConnectInit: Boolean; { Whether remote init is done. Set by cipher model. }
    FInCmd: SystemString; { Current incoming command. Set by ExecuteDataFrame. }
    FInText, FOutText: SystemString; { Incoming/outgoing console data. Set by ExecuteDataFrame. }
    FInDataFrame, FOutDataFrame: TDFE; { Incoming/outgoing stream data. Created by constructor. }
    FResult_Text: SystemString; { Result text for console. Set by FillWaitOnResultBuffer. }
    FResult_DFE: TDFE; { Result stream data. Created by constructor. }
    FSyncPick: PQueueData; { Queue item being processed synchronously. Set by Internal_Process_Send_Buffer. }
    FWaitSendBusy: Boolean; { Wait-send busy flag. Set by WaitSend methods. }
    FReceiveCommandRuning: Boolean; { Command execution flag. Set by Internal_Execute_*. }
    FReceiveResultRuning: Boolean; { Result execution flag. Set by DoExecuteResult. }
    FProgressRunning: Boolean; { Progress re-entry guard. Set by Progress. }
    FTimeOutProcessDone: Boolean; { Timeout processing done flag. Set by Progress. }
    FLast_IO_Is_IDLE: Boolean; { Last idle state. Set by IOBusy. }
    FLast_IO_IDLE_Time: TTimeTick; { Last idle timestamp. Set by IOBusy. }
  public
    function Connected: Boolean; virtual; // Returns True if the connection is established and active.
    procedure Disconnect; virtual; // Closes the connection and releases associated resources.
    procedure Write_IO_Buffer(const buff: PByte; const Size: NativeInt); virtual; // Writes raw data to the underlying transport; must be thread-safe.
    procedure WriteBufferOpen; virtual; // Called before a batch of writes; starts a write transaction.
    procedure WriteBufferFlush; virtual; // Flushes any buffered writes to the transport.
    procedure WriteBufferClose; virtual; // Called after a batch of writes; ends the write transaction.
    function GetPeerIP: SystemString; virtual; // Returns the remote peer's IP address as a string, or 'offline' if not connected.
    function WriteBuffer_is_NULL: Boolean; virtual; // Returns True if the write buffer is empty and no data is pending for transmission.
    function WriteBuffer_State(var WriteBuffer_Queue_Num, WriteBuffer_Size: Int64): Boolean; virtual; // Returns buffer state (queue count and total size); True if pending writes exist.
  protected
    { Sequence Packet Model }
    FSequencePacketActivted, FSequencePacketSignal: Boolean;
    SequenceNumberOnSendCounter, SequenceNumberOnReceivedCounter: Cardinal;
    SendingSequencePacketHistory: TSequence_Packet_Hash_Pool;
    SequencePacketReceivedPool: TSequence_Packet_Hash_Pool;
    SendingSequencePacketHistoryMemory, SequencePacketReceivedPoolMemory: Int64;
    IOSendBuffer, SequencePacketSendBuffer, SequencePacketReceivedBuffer: TMS64;
    FSequencePacketMTU: Word;
    FSequencePacketLimitPhysicsMemory: Int64;
    SequencePacketCloseDone: Boolean;
    SequencePacketVerifyTick: TTimeTick;
    procedure InitSequencePacketModel(const hashSize, MemoryDelta: Integer); // Initialises the reliable sequence-packet engine with hash pool and buffers.
    procedure FreeSequencePacketModel; // Releases all sequence-packet resources and clears history pools.
    procedure ResetSequencePacketBuffer; // Clears all sequence-packet send/receive buffers without freeing the model.
    procedure ProcessSequencePacketModel; // Drives sequence-packet retransmission and acknowledgment processing.
    function GetSequencePacketState: SystemString; // Returns a string describing current sequence-packet stats (history, pool, memory).
    function GetSequencePacketUsagePhysicsMemory: Int64; // Returns total memory used by all sequence-packet buffers.
    function ComputeSequencePacketHash(const p: PByte; const Count: nativeUInt): TMD5; // Calculates MD5 hash for a packet payload.
    function IsSequencePacketModel: Boolean; // Returns True if sequence-packet mode is active and protocol is ZServer.
    procedure FlushIOSendBuffer; // Sends all accumulated data in the internal IO send buffer.
    procedure SendSequencePacketBegin; // Starts a new sequence-packet assembly session.
    procedure SendSequencePacket(const buff: PByte; siz: NativeInt); // Appends data to the current sequence-packet assembly.
    procedure SendSequencePacketEnd; // Finalises and sends the assembled sequence packets (fragments if needed).
    procedure SendSequencePacketKeepAlive(p: Pointer; siz: Word); // Sends a keep-alive packet with optional user data.
    procedure DoSequencePacketEchoKeepAlive(p: Pointer; siz: Word); virtual; // Called when a keep-alive echo is received; override for custom handling.
    procedure WriteSequencePacket(p: PSequencePacket); // Writes a single sequence packet (header + data) to the send buffer.
    procedure ResendSequencePacket(SequenceNumber: Cardinal); // Forces retransmission of a specific packet by sequence number.
    function FillSequencePacketTo(const buff: Pointer; siz: Int64; ExtractDest: TMS64): Boolean; // Processes raw incoming data through sequence‑packet reassembly.
    procedure Send_Free_OnPtr(var Sequence_ID_: Cardinal; var p: PSequencePacket); // Callback to free a sending-history packet when acknowledged.
    procedure Send_Add_OnPtr(var Sequence_ID_: Cardinal; var p: PSequencePacket); // Callback to track a newly added sending-history packet.
    procedure Received_Free_OnPtr(var Sequence_ID_: Cardinal; var p: PSequencePacket); // Callback to free a received-pool packet when delivered.
    procedure Received_Add_OnPtr(var Sequence_ID_: Cardinal; var p: PSequencePacket); // Callback to track a newly added received-pool packet.
  protected
    { P2P Virtual Machine (P2PVM) support }
    FP2PVMTunnel: TZNet_P2PVM; { P2PVM tunnel instance. Created by OpenP2PVMTunnel. }
    FP2PVM_Auth_Token: TBytes; { Authentication token. Set by BuildP2PAuthToken. }
    FP2PVM_Cipher_Key: TCipherKeyBuffer; { P2PVM cipher key. Set by BuildP2PAuthToken. }
    FP2PVM_Cipher: TCipher_Tool_Base; { P2PVM cipher instance. Set by BuildP2PAuthToken. }
    On_Internal_Send_Byte_Buffer: TInternalSendByteBuffer; { Internal send hook. Set by constructor. }
    On_Internal_Save_Receive_Buffer: TInternalSaveReceiveBuffer; { Internal receive hook. Set by constructor. }
    On_Internal_Process_Receive_Buffer: TInternalProcessReceiveBuffer; { Internal receive process hook. Set by constructor. }
    On_Internal_Process_Send_Buffer: TInternalProcessSendBuffer; { Internal send process hook. Set by constructor. }
    OnCreate: TInternal_IO_Create; { Creation callback. Set by constructor. }
    OnDestroy: TInternal_IO_Destory; { Destruction callback. Set by constructor. }
    OnVMBuildAuthModelResult_C: TOnNotify_C; { VM auth build result callback (C). Set by caller. }
    OnVMBuildAuthModelResult_M: TOnNotify_M; { VM auth build result callback (method). Set by caller. }
    OnVMBuildAuthModelResult_P: TOnNotify_P; { VM auth build result callback (nested). Set by caller. }
    OnVMBuildAuthModelResultIO_C: TOnIONotify_C; { VM auth build result with IO (C). Set by caller. }
    OnVMBuildAuthModelResultIO_M: TOnIONotify_M; { VM auth build result with IO (method). Set by caller. }
    OnVMBuildAuthModelResultIO_P: TOnIONotify_P; { VM auth build result with IO (nested). Set by caller. }
    OnVMAuthResult_C: TOnState_C; { VM auth result (C). Set by caller. }
    OnVMAuthResult_M: TOnState_M; { VM auth result (method). Set by caller. }
    OnVMAuthResult_P: TOnState_P; { VM auth result (nested). Set by caller. }
    OnVMAuthResultIO_C: TOnIOState_C; { VM auth result with IO (C). Set by caller. }
    OnVMAuthResultIO_M: TOnIOState_M; { VM auth result with IO (method). Set by caller. }
    OnVMAuthResultIO_P: TOnIOState_P; { VM auth result with IO (nested). Set by caller. }
    procedure P2PVMAuthSuccess(Sender: TZNet_P2PVM);
  protected
    { Automated P2PVM }
    FOnAutomatedP2PVMClientConnectionDone_C: TOnIOState_C; { Automated P2PVM done (C). Set by caller. }
    FOnAutomatedP2PVMClientConnectionDone_M: TOnIOState_M; { Automated P2PVM done (method). Set by caller. }
    FOnAutomatedP2PVMClientConnectionDone_P: TOnIOState_P; { Automated P2PVM done (nested). Set by caller. }
  protected
    { User custom data }
    FUserData: Pointer; { Generic user pointer. Set by user. }
    FUserValue: Variant; { Generic user variant. Set by user. }
    FUserVariants: THashVariantList; { Key-value variant storage. Created on demand. }
    FUserObjects: THashObjectList; { Key-value object storage (not auto-freed). Created on demand. }
    FUserAutoFreeObjects: THashObjectList; { Key-value object storage (auto-freed). Created on demand. }
    FUser_Define: TPeer_IO_User_Define; { Primary user-defined object. Created by constructor. }
    FUser_Special: TPeer_IO_User_Special; { Secondary user-defined object. Created by constructor. }
    function GetUserVariants: THashVariantList;
    function GetUserObjects: THashObjectList;
    function GetUserAutoFreeObjects: THashObjectList;
  protected
    BeginSendState: Boolean; { Send state guard. Set by BeginSend/EndSend. }
    procedure BeginSend; // Begins a new send sequence; call before sending raw data.
    procedure Send(const buff: PByte; siz: NativeInt); // Appends raw binary data to the current send buffer.
    procedure EndSend; // Flushes the send buffer and transmits all queued data.
    procedure SendInteger(v: Integer); // Sends a 32‑bit signed integer.
    procedure SendCardinal(v: Cardinal); // Sends a 32‑bit unsigned integer.
    procedure SendInt64(v: Int64); // Sends a 64‑bit signed integer.
    procedure SendByte(v: Byte); // Sends a single unsigned byte.
    procedure SendWord(v: Word); // Sends a 16‑bit unsigned word.
    procedure SendVerifyCode(buff: Pointer; siz: NativeInt); // Sends a hash/checksum of the buffer for integrity verification.
    procedure SendEncryptBuffer(buff: PByte; siz: NativeInt; CS: TCipherSecurity); // Encrypts and sends the buffer using the specified cipher.
    procedure SendEncryptMemoryStream(Stream: TMS64; CS: TCipherSecurity); // Encrypts and sends the entire TMS64 stream.
    procedure Internal_Send_Console_Buff(buff: TMS64; CS: TCipherSecurity); // Sends a complete console‑command packet (header + encrypted payload).
    procedure Internal_Send_Stream_Buff(buff: TMS64; CS: TCipherSecurity); // Sends a complete stream‑command packet.
    procedure Internal_Send_ConsoleNotify_Buff(buff: TMS64; CS: TCipherSecurity); // Sends a fire‑and‑forget console notification packet.
    procedure Internal_Send_StreamNotify_Buff(buff: TMS64; CS: TCipherSecurity); // Sends a fire‑and‑forget stream notification packet.
    procedure Internal_Send_Big_Stream_Header(const Cmd: SystemString; streamSiz: Int64); // Sends the header for a big‑stream transfer.
    procedure Internal_Send_BigStream_Buff(var Queue: TQueueData); // Sends big‑stream data in chunks, with flow‑control signalling.
    procedure Internal_Send_Complete_Buffer_Header(const Cmd: SystemString; BuffSiz, compSiz: Cardinal); // Sends the header for a complete‑buffer command.
    procedure Internal_Send_CompleteBuffer_Buff(var Queue: TQueueData); // Sends the complete‑buffer payload, optionally compressed.
    procedure Internal_Send_BigStream_Fragment_Signal; // Sends a signal to request the next big‑stream fragment.
    procedure Internal_Send_BigStream_Done_Signal; // Sends a signal indicating the big‑stream transfer is complete.
    procedure SendBigStreamMiniPacket(buff: PByte; Size: NativeInt); // Sends a single fragment of a big‑stream, with compression header.
    procedure Internal_Send_Result_Data; // Flushes the pending result buffer (response after a pause).
    procedure Internal_Send_Console_Cmd; // Serialises and sends a console command from the queue.
    procedure Internal_Send_Stream_Cmd; // Serialises and sends a stream command from the queue.
    procedure Internal_Send_ConsoleNotify_Cmd; // Sends a console notification command (no reply expected).
    procedure Internal_Send_StreamNotify_Cmd; // Sends a stream notification command (no reply expected).
    procedure Internal_Send_BigStream_Cmd; // Sends a big‑stream command from the queue.
    procedure Internal_Send_CompleteBuffer_Cmd; // Sends a complete‑buffer command from the queue.
    procedure Internal_Execute_Console; // Executes a console command and populates the result string.
    procedure Internal_Execute_Stream; // Executes a stream command and populates the result DFE.
    procedure Internal_Execute_ConsoleNotify; // Executes a console notification (no result sent).
    procedure Internal_Execute_StreamNotify; // Executes a stream notification (no result sent).
    procedure SendConsoleResult; // Sends the result of a console command back to the caller.
    procedure SendStreamResult; // Sends the result of a stream command back to the caller.
    procedure ExecuteDataFrame(CommDataType: Byte; DFE_: TDFE); // Dispatches a parsed DFE command to the appropriate handler.
    procedure Internal_Execute_BigStream; // Executes a big‑stream command and triggers progress callbacks.
    function ReceivedBigStreamFragment(Source_: TMS64): Int64; // Processes an incoming big‑stream fragment; returns bytes consumed.
    procedure Internal_Execute_CompleteBuffer; // Executes a complete‑buffer command (sync or async).
    function FillCompleteBufferBuffer(Source_: TMS64): Int64; // Reassembles a complete‑buffer from fragments; returns bytes consumed.
    procedure Internal_ExecuteResult; // Triggers the result callback for a pending request.
    function FillWaitOnResultBuffer(Source_: TMS64): Int64; // Parses an incoming response packet and delivers the result.
    procedure Internal_Save_Receive_Buffer(const buff: Pointer; siz: Int64); // Appends raw received data to the receive buffer.
    function Internal_Process_Receive_Buffer(): Integer; // Parses all complete packets from the receive buffer.
    procedure Internal_Process_Send_Buffer(); // Drains the send queue and sends queued commands.
    procedure CheckAndTriggerFailedWaitResult; // Notifies failure for a pending request and cleans up.
    procedure Internal_Close_P2PVMTunnel; // Closes and frees the P2P virtual machine tunnel.
  public
    constructor Create(OwnerFramework_: TZNet; IOInterface_: TCore_Object);
    procedure CreateAfter; virtual;
    destructor Destroy; override;
    { IO state and idle tracing. }
    function IOBusy: Boolean;
    property IO_Create_TimeTick: TTimeTick read FIO_Create_TimeTick;
    procedure IO_IDLE_TraceC(data: TCore_Object; OnNotify: TOnDataNotify_C);
    procedure IO_IDLE_TraceM(data: TCore_Object; OnNotify: TOnDataNotify_M);
    procedure IO_IDLE_TraceP(data: TCore_Object; OnNotify: TOnDataNotify_P);
    { Double-tunnel support (separate receive/send channels). }
    function Is_Double_Tunnel: Boolean;
    function Is_Recveive_Tunnel: Boolean;
    function Is_Send_Tunnel: Boolean;
    function Is_Link_OK: Boolean;
    function Get_Send_Tunnel_IO: TPeerIO;
    function Get_Send_Tunnel(var Send_Tunnel: TZNet; var Send_Tunnel_ID: Cardinal): Boolean;
    function Get_Recv_Tunnel_IO: TPeerIO;
    function Get_Recv_Tunnel(var Recv_Tunnel: TZNet; var Recv_Tunnel_ID: Cardinal): Boolean;
    { Sequence Packet model support. }
    property SequencePacketSignal: Boolean read FSequencePacketSignal;
    property SequencePacketMTU: Word read FSequencePacketMTU write FSequencePacketMTU;
    property SequencePacketLimitOwnerIOMemory: Int64 read FSequencePacketLimitPhysicsMemory write FSequencePacketLimitPhysicsMemory;
    property SequencePacketUsagePhysicsMemory: Int64 read GetSequencePacketUsagePhysicsMemory;
    property SequencePacketState: SystemString read GetSequencePacketState;
    { P2PVM Tunnel support. }
    property P2PVM: TZNet_P2PVM read FP2PVMTunnel;
    property P2PVMTunnel: TZNet_P2PVM read FP2PVMTunnel;
    property P2PVM_Auth_Token: TBytes read FP2PVM_Auth_Token;
    property P2PVM_Cipher_Key: TCipherKeyBuffer read FP2PVM_Cipher_Key;
    property P2PVM_Cipher: TCipher_Tool_Base read FP2PVM_Cipher;
    function p2pVMTunnelReadyOk: Boolean;
    { Build P2P auth token (calls remote to exchange security credentials). }
    procedure BuildP2PAuthToken; overload;
    procedure BuildP2PAuthTokenC(const OnResult: TOnNotify_C);
    procedure BuildP2PAuthTokenM(const OnResult: TOnNotify_M);
    procedure BuildP2PAuthTokenP(const OnResult: TOnNotify_P);
    procedure BuildP2PAuthTokenIO_C(const OnResult: TOnIONotify_C);
    procedure BuildP2PAuthTokenIO_M(const OnResult: TOnIONotify_M);
    procedure BuildP2PAuthTokenIO_P(const OnResult: TOnIONotify_P);
    { Open P2PVM tunnel. }
    procedure DoP2PVM_Created(Sender: TZNet_P2PVM); virtual;
    procedure DoP2PVM_InstallLogicFramework(Inst: TZNet); virtual;
    procedure DoP2PVM_UninstallLogicFramework(Inst: TZNet); virtual;
    procedure OpenP2PVMTunnel(vmHashPoolSize: Integer; SendRemoteRequest: Boolean; const AuthToken: SystemString); overload;
    procedure OpenP2PVMTunnel(SendRemoteRequest: Boolean; const AuthToken: SystemString); overload;
    procedure OpenP2PVMTunnelC(SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnState_C); overload;
    procedure OpenP2PVMTunnelM(SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnState_M); overload;
    procedure OpenP2PVMTunnelP(SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnState_P); overload;
    procedure OpenP2PVMTunnelC(vmHashPoolSize: Integer; SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnState_C); overload;
    procedure OpenP2PVMTunnelM(vmHashPoolSize: Integer; SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnState_M); overload;
    procedure OpenP2PVMTunnelP(vmHashPoolSize: Integer; SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnState_P); overload;
    procedure OpenP2PVMTunnelIO_C(SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnIOState_C); overload;
    procedure OpenP2PVMTunnelIO_M(SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnIOState_M); overload;
    procedure OpenP2PVMTunnelIO_P(SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnIOState_P); overload;
    procedure OpenP2PVMTunnelIO_C(vmHashPoolSize: Integer; SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnIOState_C); overload;
    procedure OpenP2PVMTunnelIO_M(vmHashPoolSize: Integer; SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnIOState_M); overload;
    procedure OpenP2PVMTunnelIO_P(vmHashPoolSize: Integer; SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnIOState_P); overload;
    procedure OpenP2PVMTunnel; overload;
    { Close P2PVM tunnel. }
    procedure CloseP2PVMTunnel;
    { Print diagnostic messages. }
    procedure Print(const v: SystemString); overload;
    procedure Print(const v: SystemString; const Args: array of const); overload;
    procedure PrintCommand(const v, Args: SystemString);
    procedure PrintParam(const v, Args: SystemString);
    procedure PrintError(const v: SystemString); overload;
    procedure PrintError(const v: SystemString; const Args: array of const); overload;
    procedure PrintWarning(const v: SystemString); overload;
    procedure PrintWarning(const v: SystemString; const Args: array of const); overload;

    { Progress the IO state machine. }
    property Disable_Progress: Boolean read FDisable_Progress; { disable progress }
    procedure Progress; virtual;

    { Delay close/free operations. }
    procedure DelayClose; overload;
    procedure DelayClose(const t: Double); overload;
    procedure DelayFree; overload;
    procedure DelayFree(const t: Double); overload;
    { Packet buffer operations. }
    procedure Write_Physics_Fragment(const p: Pointer; siz: Int64);
    function Extract_Physics_Fragment_To_Receive_Buffer(): Int64;
    procedure Process_Receive_Buffer();
    procedure Process_Send_Buffer();
    procedure PostQueueData(p: PQueueData);
    { Custom protocol buffer writing. }
    procedure BeginWriteCustomBuffer;
    procedure EndWriteCustomBuffer;
    procedure WriteCustomBuffer(const Buffer: PByte; const Size: NativeInt); overload; virtual;
    procedure WriteCustomBuffer(const Buffer: TMS64); overload;
    procedure WriteCustomBuffer(const Buffer: TMem64); overload;
    procedure WriteCustomBuffer(const Buffer: TMS64; const doneFreeBuffer: Boolean); overload;
    procedure WriteCustomBuffer(const Buffer: TMem64; const doneFreeBuffer: Boolean); overload;
    { Pause/Resume result sending. }
    procedure Pause; virtual;
    procedure PauseResultSend;
    procedure BreakResultSend;
    procedure SkipResultSend;
    procedure NoResultSend;
    procedure StopResultSend;
    procedure Resume; virtual;
    procedure ContinueResultSend;
    procedure Continue_Send_Result;
    procedure ResumeResultSend;
    procedure NowResultSend;
    { Incoming/outgoing data access. }
    property InText: SystemString read FInText;
    property InConsole: SystemString read FInText;
    property OutText: SystemString read FOutText write FOutText;
    property OutConsole: SystemString read FOutText write FOutText;
    property InDataFrame: TDFE read FInDataFrame;
    property InDFE: TDFE read FInDataFrame;
    property OutDataFrame: TDFE read FOutDataFrame;
    property OutDFE: TDFE read FOutDataFrame;
    function ResultSendIsPaused: Boolean;
    property ResultIsPaused: Boolean read ResultSendIsPaused;
    { State access. }
    property CurrentBigStreamCommand: SystemString read FBigStreamCmd;
    property CurrentCommand: SystemString read FInCmd;
    property CurrentCmd: SystemString read FInCmd;
    property CompleteBufferCmd: SystemString read FCompleteBufferCmd;
    property WaitOnResult: Boolean read FWaitOnResult;
    property AllSendProcessing: Boolean read FAllSendProcessing;
    property BigStreamReceiveing: Boolean read FBigStreamReceiveProcessing;
    property WaitSendBusy: Boolean read FWaitSendBusy;
    property ReceiveProcessing: Boolean read FReceiveProcessing;
    property ReceiveCommandRuning: Boolean read FReceiveCommandRuning;
    property ReceiveResultRuning: Boolean read FReceiveResultRuning;
    function GetBigStreamReceiveState(var Total, Complete: Int64): Boolean;
    function GetBigStreamSendingState(var Total, Complete: Int64): Boolean;
    function GetBigStreamBatch: TBigStreamBatch;
    property BigStreamBatchList: TBigStreamBatch read GetBigStreamBatch;
    property BigStreamBatch: TBigStreamBatch read GetBigStreamBatch;
    property CompleteBufferReceivedStream: TMS64 read FCompleteBufferReceivedStream;
    property CompleteBuffer_Current_Trigger: TMS64 read FCompleteBuffer_Current_Trigger;
    function Get_Last_IO_IDLE_Time: TTimeTick;
    property Last_IO_IDLE_Time: TTimeTick read Get_Last_IO_IDLE_Time;
    { Framework and identity. }
    property OwnerFramework: TZNet read FOwnerFramework;
    property IOInterface: TCore_Object read FIOInterface write FIOInterface;
    procedure SetID(const Value: Cardinal);
    property ID: Cardinal read FID write SetID;
    property CipherKey: TCipherKeyBuffer read FCipherKey;
    function CipherKeyPtr: PCipherKeyBuffer;
    property SendCipherSecurity: TCipherSecurity read FSendDataCipherSecurity write FSendDataCipherSecurity;
    property RemoteExecutedForConnectInit: Boolean read FRemoteExecutedForConnectInit write FRemoteExecutedForConnectInit;
    property PeerIP: SystemString read GetPeerIP;
    { User data. }
    property UserVariants: THashVariantList read GetUserVariants;
    property UserObjects: THashObjectList read GetUserObjects;
    property UserAutoFreeObjects: THashObjectList read GetUserAutoFreeObjects;
    property UserData: Pointer read FUserData write FUserData;
    property UserValue: Variant read FUserValue write FUserValue;
    property UserDefine: TPeer_IO_User_Define read FUser_Define;
    property IODefine: TPeer_IO_User_Define read FUser_Define;
    property Define: TPeer_IO_User_Define read FUser_Define;
    property UserSpecial: TPeer_IO_User_Special read FUser_Special;
    property IOSpecial: TPeer_IO_User_Special read FUser_Special;
    property Special: TPeer_IO_User_Special read FUser_Special;
    { Hash and encryption utilities. }
    procedure GenerateHashCode(const hs: THashSecurity; buff: Pointer; siz: Integer; var output: TBytes);
    function VerifyHashCode(const hs: THashSecurity; buff: Pointer; siz: Integer; var Code: TBytes): Boolean;
    procedure Encrypt(CS: TCipherSecurity; DataPtr: Pointer; Size: Cardinal; var k: TCipherKeyBuffer; enc: Boolean);
    { Timeout tracking. }
    function NoneCommunicationTime: TTimeTick;
    property StopCommunicationTime: TTimeTick read NoneCommunicationTime;
    procedure UpdateLastCommunicationTime;
    property LastCommunicationTime: TTimeTick read FLastCommunicationTick;
    property LastCommunicationTimeTick: TTimeTick read FLastCommunicationTick;
    { Queue data access. }
    property CurrentQueueData: PQueueData read FCurrentQueueData;

    { ===========================================================================
      Send command methods – with and without result callbacks.
      ===========================================================================
      These methods queue a command for transmission to the remote peer.
      The command will be sent asynchronously during the next Progress() cycle.
      The caller must ensure the IO is connected before sending.

      All methods support three callback styles:
      - No suffix: fire-and-forget (no response expected).
      - M suffix: method-style callback (of object).
      - P suffix: nested or reference (anonymous) callback.
      Additionally, some methods accept custom parameters (Param1/Param2)
      that are passed back to the callback, and an optional OnFailed callback
      for timeout or error handling.

      For stream commands, the payload is a TDFE (Data Frame Exchange) which
      can contain structured binary data. For console commands, the payload
      is a string. BigStream and CompleteBuffer commands handle large data
      blocks with specialized mechanisms.

      WaitSendXXX methods block the caller until a response is received or a
      timeout occurs – use with caution as they suspend the calling thread.
    }

    // --- Console commands (request-response) ------------------------------------
    {
      * Sends a console command without expecting a response.
      * The command is queued and sent asynchronously. No callback is invoked.
      * @Param Cmd: Name of the command registered on the remote side.
      * @Param ConsoleData: String payload to send.
    }
    procedure SendConsoleCmd(const Cmd, ConsoleData: SystemString);

    {
      * Sends a console command and invokes a method callback when the response arrives.
      * @Param Cmd: Command name.
      * @Param ConsoleData: Payload string.
      * @Param OnResult: Method-style callback receiving the response string.
    }
    procedure SendConsoleCmdM(const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_M); overload;

    {
      * Sends a console command with custom parameters; callback receives them.
      * @Param Cmd: Command name.
      * @Param ConsoleData: Payload string.
      * @Param Param1, Param2: User-defined pointers/objects passed back.
      * @Param OnResult: Callback receiving the response and the parameters.
    }
    procedure SendConsoleCmdM(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M); overload;

    {
      * Sends a console command with parameters and an explicit failure handler.
      * @Param Cmd: Command name.
      * @Param ConsoleData: Payload string.
      * @Param Param1, Param2: User parameters.
      * @Param OnResult: Success callback.
      * @Param OnFailed: Failure callback (timeout or error).
    }
    procedure SendConsoleCmdM(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M; const OnFailed: TOnConsoleFailed_M); overload;

    // --- Console commands with nested/reference callbacks ----------------------
    {
      * Sends a console command with a nested (reference) callback.
      * @Param Cmd: Command name.
      * @Param ConsoleData: Payload.
      * @Param OnResult: Nested/reference callback receiving the response.
    }
    procedure SendConsoleCmdP(const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_P); overload;

    {
      * Sends a console command with parameters and a nested callback.
      * @Param Cmd: Command name.
      * @Param ConsoleData: Payload.
      * @Param Param1, Param2: User parameters.
      * @Param OnResult: Success callback with parameters.
    }
    procedure SendConsoleCmdP(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P); overload;

    {
      * Sends a console command with parameters and both success/failure nested callbacks.
      * @Param Cmd: Command name.
      * @Param ConsoleData: Payload.
      * @Param Param1, Param2: User parameters.
      * @Param OnResult: Success callback.
      * @Param OnFailed: Failure callback.
    }
    procedure SendConsoleCmdP(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P; const OnFailed: TOnConsoleFailed_P); overload;

    // --- Stream commands (request-response) ------------------------------------
    {
      * Sends a stream command without expecting a response.
      * The StreamData buffer is automatically freed after sending if DoneAutoFree=True.
      * @Param Cmd: Command name.
      * @Param StreamData: Payload as TMS64 (memory stream).
      * @Param DoneAutoFree: If True, the stream object is freed after send.
    }
    procedure SendStreamCmd(const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean); overload;

    {
      * Sends a stream command with a TDFE payload (no response expected).
      * The TDFE is encoded and sent asynchronously.
      * @Param Cmd: Command name.
      * @Param StreamData: Payload as TDFE.
    }
    procedure SendStreamCmd(const Cmd: SystemString; StreamData: TDFE); overload;

    {
      * Sends a stream command expecting a response via a method callback.
      * @Param Cmd: Command name.
      * @Param StreamData: Payload as TMS64.
      * @Param OnResult: Method callback receiving the response TDFE.
      * @Param DoneAutoFree: Whether to auto-free StreamData.
    }
    procedure SendStreamCmdM(const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_M; DoneAutoFree: Boolean); overload;

    {
      * Sends a stream command with a TDFE payload and method callback.
      * @Param Cmd: Command name.
      * @Param StreamData: Payload as TDFE.
      * @Param OnResult: Method callback receiving the response.
    }
    procedure SendStreamCmdM(const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_M); overload;

    {
      * Sends a stream command with parameters and method callback.
      * @Param Cmd: Command name.
      * @Param StreamData: Payload as TDFE.
      * @Param Param1, Param2: User parameters.
      * @Param OnResult: Success callback with parameters.
    }
    procedure SendStreamCmdM(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M); overload;

    {
      * Sends a stream command with parameters and both success/failure method callbacks.
      * @Param Cmd: Command name.
      * @Param StreamData: Payload as TDFE.
      * @Param Param1, Param2: User parameters.
      * @Param OnResult: Success callback.
      * @Param OnFailed: Failure callback.
    }
    procedure SendStreamCmdM(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M; const OnFailed: TOnStreamFailed_M); overload;

    // --- Stream commands with nested/reference callbacks -----------------------
    {
      * Sends a stream command with a nested callback for the response.
      * @Param Cmd: Command name.
      * @Param StreamData: Payload as TMS64.
      * @Param OnResult: Nested callback.
      * @Param DoneAutoFree: Whether to auto-free StreamData.
    }
    procedure SendStreamCmdP(const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_P; DoneAutoFree: Boolean); overload;

    {
      * Sends a stream command with a TDFE payload and nested callback.
      * @Param Cmd: Command name.
      * @Param StreamData: Payload as TDFE.
      * @Param OnResult: Nested callback.
    }
    procedure SendStreamCmdP(const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_P); overload;

    {
      * Sends a stream command with parameters and nested callback.
      * @Param Cmd: Command name.
      * @Param StreamData: Payload as TDFE.
      * @Param Param1, Param2: User parameters.
      * @Param OnResult: Success callback with parameters.
    }
    procedure SendStreamCmdP(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P); overload;

    {
      * Sends a stream command with parameters and both nested success/failure callbacks.
      * @Param Cmd: Command name.
      * @Param StreamData: Payload as TDFE.
      * @Param Param1, Param2: User parameters.
      * @Param OnResult: Success callback.
      * @Param OnFailed: Failure callback.
    }
    procedure SendStreamCmdP(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P; const OnFailed: TOnStreamFailed_P); overload;

    // --- Notification commands (no response) ------------------------------------
    {
      * Sends a console notification (fire-and-forget) with payload.
      * @Param Cmd: Command name.
      * @Param ConsoleData: Payload string.
    }
    procedure SendConsoleNotifyCmd(const Cmd, ConsoleData: SystemString); overload;

    {
      * Sends a console notification with an empty payload.
      * @Param Cmd: Command name.
    }
    procedure SendConsoleNotifyCmd(const Cmd: SystemString); overload;

    {
      * Sends a stream notification (fire-and-forget) with a TMS64 payload.
      * @Param Cmd: Command name.
      * @Param StreamData: Payload as TMS64.
      * @Param DoneAutoFree: Whether to auto-free StreamData.
    }
    procedure SendStreamNotifyCmd(const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean); overload;

    {
      * Sends a stream notification with a TDFE payload.
      * @Param Cmd: Command name.
      * @Param StreamData: Payload as TDFE.
    }
    procedure SendStreamNotifyCmd(const Cmd: SystemString; StreamData: TDFE); overload;

    {
      * Sends a stream notification with an empty payload (TDFE is built).
      * @Param Cmd: Command name.
    }
    procedure SendStreamNotifyCmd(const Cmd: SystemString); overload;

    // --- Synchronous (blocking) send methods ------------------------------------
    {
      * Sends a console command and waits for a response.
      * The caller blocks until the response is received or the timeout expires.
      * @Param Cmd: Command name.
      * @Param ConsoleData: Payload string.
      * @Param TimeOut_: Timeout in milliseconds (0 means no timeout, but may block indefinitely).
      * @Returns: The response string, or empty string on failure/timeout.
    }
    function WaitSendConsoleCmd(Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString;

    {
      * Sends a stream command and waits for a response.
      * The caller blocks until the response arrives or the timeout expires.
      * @Param Cmd: Command name.
      * @Param StreamData: Input TDFE payload.
      * @Param Result_: Output TDFE that receives the response.
      * @Param TimeOut_: Timeout in milliseconds.
    }
    procedure WaitSendStreamCmd(const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick);

    // --- Big-stream (large file/data) send -------------------------------------
    {
      * Sends a large stream (big-stream) starting from a specified position.
      * The stream is sent in chunks with flow control. The remote side must
      * have a matching big-stream command handler.
      * @Param Cmd: Command name.
      * @Param BigStream: The stream object containing the data.
      * @Param StartPos: Byte offset from which to start sending.
      * @Param DoneAutoFree: Whether to auto-free BigStream after send.
    }
    procedure SendBigStream(const Cmd: SystemString; BigStream: TCore_Stream; StartPos: Int64; DoneAutoFree: Boolean); overload;

    {
      * Sends a large stream from the beginning (StartPos = 0).
      * @Param Cmd: Command name.
      * @Param BigStream: The stream object.
      * @Param DoneAutoFree: Whether to auto-free BigStream.
    }
    procedure SendBigStream(const Cmd: SystemString; BigStream: TCore_Stream; DoneAutoFree: Boolean); overload;

    // --- Complete-buffer (atomic data block) send ------------------------------
    {
      * Sends a raw buffer as a complete-buffer command.
      * The buffer is sent atomically; the remote side must have a matching
      * complete-buffer command registered.
      * @Param Cmd: Command name.
      * @Param buff: Pointer to the data buffer.
      * @Param BuffSize: Size of the buffer in bytes.
      * @Param DoneAutoFree: Whether to auto-free the buffer after send.
    }
    procedure SendCompleteBuffer(const Cmd: SystemString; buff: PByte; BuffSize: NativeInt; DoneAutoFree: Boolean); overload;

    {
      * Sends a TMS64 stream as a complete-buffer command.
      * @Param Cmd: Command name.
      * @Param buff: TMS64 containing the data.
      * @Param DoneAutoFree: Whether to auto-free the stream.
    }
    procedure SendCompleteBuffer(const Cmd: SystemString; buff: TMS64; DoneAutoFree: Boolean); overload;

    {
      * Sends a TMem64 buffer as a complete-buffer command.
      * @Param Cmd: Command name.
      * @Param buff: TMem64 containing the data.
      * @Param DoneAutoFree: Whether to auto-free the buffer.
    }
    procedure SendCompleteBuffer(const Cmd: SystemString; buff: TMem64; DoneAutoFree: Boolean); overload;

    {
      * Sends a TDFE as a complete-buffer command.
      * The TDFE is encoded into a buffer and sent.
      * @Param Cmd: Command name.
      * @Param buff: TDFE payload.
    }
    procedure SendCompleteBuffer(const Cmd: SystemString; buff: TDFE); overload;

    // --- Complete-buffer optimized variants ------------------------------------
    {
      * Sends a TDFE as a complete-buffer command using the stream-notify model.
      * The handler on the remote side receives a TDFE (decoded from the buffer).
      * This is an optimized replacement for classic stream-notify.
      * @Param Cmd: Command name.
      * @Param buff: TDFE payload.
    }
    procedure SendCompleteBuffer_StreamNotify(const Cmd: SystemString; buff: TDFE);

    {
      * Sends a complete-buffer stream command expecting a response via a method callback.
      * Uses the no-wait model: the command is sent and the response is delivered
      * asynchronously without blocking the caller.
      * @Param Cmd: Command name.
      * @Param buff: TDFE payload.
      * @Param OnResult: Method callback receiving the response TDFE.
    }
    procedure SendCompleteBuffer_NoWait_StreamM(const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_M);

    {
      * Sends a complete-buffer stream command with a nested callback.
      * @Param Cmd: Command name.
      * @Param buff: TDFE payload.
      * @Param OnResult: Nested callback receiving the response.
    }
    procedure SendCompleteBuffer_NoWait_StreamP(const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_P);

    // --- NULL (keep-alive) command ---------------------------------------------
    {
      * Sends a special NULL command that does nothing but acts as a keep-alive.
      * It can also be used to force the remote side to process pending queue items.
    }
    procedure Send_NULL();
    procedure SendNULL();
  end;

  TPeerIOClass = class of TPeerIO;
  TPeerClient = TPeerIO;
  TPeerClientClass = TPeerIOClass;
{$ENDREGION 'IO'}
{$REGION 'Z-Net'}
  TPeerIOCMDNotify = procedure(Sender: TPeerIO; const Cmd: SystemString; var Allow: Boolean) of object; { Command notify callback. }

  {
    * TStatisticsType: Statistics types for performance monitoring.
    * Each statistic tracks a specific aspect of network activity.
    * @Enum stReceiveSize: Bytes received.
    * @Enum stSendSize: Bytes sent.
    * @Enum stPhysicsFragmentCache: Fragments cached.
    * @Enum stRequest: Requests received.
    * @Enum stResponse: Responses sent.
    * @Enum stConsole: Console commands sent.
    * @Enum stStream: Stream commands sent.
    * @Enum stDirestConsole: Direct console commands sent.
    * @Enum stDirestStream: Direct stream commands sent.
    * @Enum stReceiveBigStream: Big streams received.
    * @Enum stSendBigStream: Big streams sent.
    * @Enum stReceiveCompleteBuffer: Complete buffers received.
    * @Enum stSendCompleteBuffer: Complete buffers sent.
    * @Enum stExecConsole: Console commands executed.
    * @Enum stExecStream: Stream commands executed.
    * @Enum stExecDirestConsole: Direct console commands executed.
    * @Enum stExecDirestStream: Direct stream commands executed.
    * @Enum stExecBigStream: Big stream commands executed.
    * @Enum stExecCompleteBuffer: Complete buffer commands executed.
    * @Enum stConnected: Connections established.
    * @Enum stDisconnect: Connections closed.
    * @Enum stCommandExecute_Sum: Total commands executed.
    * @Enum stCommand_Send_Sum: Total commands sent.
    * @Enum stCommand_Reg_Sum: Total commands registered.
    * @Enum stEncrypt: Encryption operations.
    * @Enum stCompress: Compression operations.
    * @Enum stGenerateHash: Hash generation operations.
    * @Enum stSequencePacketMemoryOnSending: Memory used for sending sequence packets.
    * @Enum stSequencePacketMemoryOnReceived: Memory used for received sequence packets.
    * @Enum stSequencePacketReceived: Sequence packets received.
    * @Enum stSequencePacketEcho: Sequence packet echoes.
    * @Enum stSequencePacketRequestResend: Resend requests.
    * @Enum stSequencePacketMatched: Matched sequence packets.
    * @Enum stSequencePacketPlan: Planned sequence packets.
    * @Enum stSequencePacketDiscard: Discarded sequence packets.
    * @Enum stSequencePacketDiscardSize: Discarded sequence packet data size.
    * @Enum stPause: Pause operations.
    * @Enum stContinue: Continue/resume operations.
    * @Enum stTimeOutDisconnect: Timeout disconnections.
  }
  TStatisticsType = (
    stReceiveSize, stSendSize,
    stPhysicsFragmentCache,
    stRequest, stResponse,
    stConsole, stStream, stDirestConsole, stDirestStream, stReceiveBigStream, stSendBigStream, stReceiveCompleteBuffer, stSendCompleteBuffer,
    stExecConsole, stExecStream, stExecDirestConsole, stExecDirestStream, stExecBigStream, stExecCompleteBuffer,
    stConnected, stDisconnect,
    stCommandExecute_Sum, stCommand_Send_Sum, stCommand_Reg_Sum,
    stEncrypt, stCompress, stGenerateHash,
    stSequencePacketMemoryOnSending, stSequencePacketMemoryOnReceived,
    stSequencePacketReceived, stSequencePacketEcho, stSequencePacketRequestResend,
    stSequencePacketMatched, stSequencePacketPlan, stSequencePacketDiscard, stSequencePacketDiscardSize,
    stPause, stContinue,
    stTimeOutDisconnect
    );

  TPeerIOList_C = procedure(P_IO: TPeerIO); { Callback types for iterating over IO lists. }
  TPeerIOList_M = procedure(P_IO: TPeerIO) of object;
{$IFDEF FPC}
  TPeerIOList_P = procedure(P_IO: TPeerIO) is nested;
{$ELSE FPC}
  TPeerIOList_P = reference to procedure(P_IO: TPeerIO);
{$ENDIF FPC}

  {
    * IIOInterface: Interface for IO creation/destruction notifications.
    * Implement this interface to receive callbacks when connections are created or destroyed.
    * @Method PeerIO_Create: Called when a new connection is established.
    * @Method PeerIO_Destroy: Called when a connection is closed.
    * @Example:
    *   type
    *     TMyHandler = class(TInterfacedObject, IIOInterface)
    *       procedure PeerIO_Create(const Sender: TPeerIO);
    *       procedure PeerIO_Destroy(const Sender: TPeerIO);
    *     end;
  }
  IIOInterface = interface
    procedure PeerIO_Create(const Sender: TPeerIO);
    procedure PeerIO_Destroy(const Sender: TPeerIO);
  end;

  TIO_Array = array of Cardinal; { Array of IO IDs. }
  TIO_Order = class(TOrderStruct<Cardinal>); { Ordered FIFO of IO IDs. }

  {
    * IZNet_VMInterface: Interface for P2PVM tunnel events.
    * Implement this to handle P2PVM authentication and tunnel lifecycle events.
    * @Method p2pVMTunnelAuth: Called when authentication is requested.
    * @Method p2pVMTunnelOpenBefore: Called before the tunnel opens.
    * @Method p2pVMTunnelOpen: Called when the tunnel opens.
    * @Method p2pVMTunnelOpenAfter: Called after the tunnel opens.
    * @Method p2pVMTunnelClose: Called when the tunnel closes.
  }
  IZNet_VMInterface = interface
    procedure p2pVMTunnelAuth(Sender: TPeerIO; const Token: SystemString; var Accept: Boolean);
    procedure p2pVMTunnelOpenBefore(Sender: TPeerIO; P2PVMTunnel: TZNet_P2PVM);
    procedure p2pVMTunnelOpen(Sender: TPeerIO; P2PVMTunnel: TZNet_P2PVM);
    procedure p2pVMTunnelOpenAfter(Sender: TPeerIO; P2PVMTunnel: TZNet_P2PVM);
    procedure p2pVMTunnelClose(Sender: TPeerIO; P2PVMTunnel: TZNet_P2PVM);
  end;

  {
    * IOnBigStreamInterface: Interface for big-stream progress notifications.
    * Implement this to receive progress updates during large file transfers.
    * @Method BeginStream: Called when a big-stream transfer begins.
    * @Method Process: Called during the transfer with progress updates.
    * @Method EndStream: Called when the transfer completes.
    * @Example:
    *   type
    *     TMyProgress = class(TInterfacedObject, IOnBigStreamInterface)
    *       procedure BeginStream(Sender: TPeerIO; Total: Int64);
    *       procedure Process(Sender: TPeerIO; Total, current: Int64);
    *       procedure EndStream(Sender: TPeerIO; Total: Int64);
    *     end;
  }
  IOnBigStreamInterface = interface
    procedure BeginStream(Sender: TPeerIO; Total: Int64);
    procedure Process(Sender: TPeerIO; Total, current: Int64);
    procedure EndStream(Sender: TPeerIO; Total: Int64);
  end;

  TCommunicationProtocol = (cpZServer, cpCustom); { Communication protocol type. }
  TProgressOnZNet = procedure(Sender: TZNet) of object; { Progress callback for TZNet. }

  {
    * TAutomatedP2PVMServiceData: Data for automated P2PVM service binding.
    * @Field Service: P2PVM server instance. Set by AddService.
  }
  TAutomatedP2PVMServiceData = record
    Service: TZNet_WithP2PVM_Server; { P2PVM server instance. Set by AddService. }
  end;

  PAutomatedP2PVMServiceData = ^TAutomatedP2PVMServiceData;

  {
    * TAutomatedP2PVMServiceBind: Collection of automated P2PVM service bindings.
    * Manages multiple P2PVM servers that should be automatically exposed.
    * @Example:
    *   Bind := TAutomatedP2PVMServiceBind.Create;
    *   Bind.AddService(MyServer, '::1', 12345);  // Expose MyServer over P2PVM
  }
  TAutomatedP2PVMServiceBind = class(TGenericsList<PAutomatedP2PVMServiceData>)
  public
    procedure AddService(Service: TZNet_WithP2PVM_Server; IPV6: SystemString; Port: Word); overload;
    procedure AddService(Service: TZNet_WithP2PVM_Server); overload;
    procedure RemoveService(Service: TZNet_WithP2PVM_Server);
    procedure Clean;
    function FoundService(Service: TZNet_WithP2PVM_Server): PAutomatedP2PVMServiceData;
  end;

  {
    * TAutomatedP2PVMClientData: Data for automated P2PVM client binding.
    * @Field Client: P2PVM client instance. Set by AddClient.
    * @Field IPV6: IPv6 address for connection. Set by AddClient.
    * @Field Port: Port for connection. Set by AddClient.
    * @Field RequestConnecting: Whether a connection request is in progress. Set internally.
  }
  TAutomatedP2PVMClientData = record
    Client: TZNet_WithP2PVM_Client; { P2PVM client instance. Set by AddClient. }
    IPV6: SystemString; { IPv6 address for connection. Set by AddClient. }
    Port: Word; { Port for connection. Set by AddClient. }
    RequestConnecting: Boolean; { Whether a connection request is in progress. Set internally. }
  end;

  PAutomatedP2PVMClientData = ^TAutomatedP2PVMClientData;

  {
    * TAutomatedP2PVMClientBind: Collection of automated P2PVM client bindings.
    * Manages multiple P2PVM clients that should be automatically connected.
    * @Example:
    *   Bind := TAutomatedP2PVMClientBind.Create;
    *   Bind.AddClient(MyClient, '::1', 12345);  // Auto-connect MyClient over P2PVM
  }
  TAutomatedP2PVMClientBind = class(TGenericsList<PAutomatedP2PVMClientData>)
  public
    procedure AddClient(Client: TZNet_WithP2PVM_Client; IPV6: SystemString; Port: Word);
    procedure RemoveClient(Client: TZNet_WithP2PVM_Client);
    procedure Clean;
    function FoundClient(Client: TZNet_WithP2PVM_Client): PAutomatedP2PVMClientData;
  end;

  TZNet_Progress_Pool_ = TBigList<TZNet_Progress>; { Pool of progress objects. }

  {
    * TZNet_Progress_Pool: Pool for TZNet_Progress objects with automatic cleanup.
  }
  TZNet_Progress_Pool = class(TZNet_Progress_Pool_)
  public
    procedure DoFree(var data: TZNet_Progress); override;
  end;

  {
    * TZNet_Progress: A progress event attached to a TZNet instance.
    * This is the main event handler for periodic operations on the network framework.
    * @Field FPool_Ptr: Pointer in pool. Set by constructor.
    * @Field FOwnerFramework: Parent framework. Set by constructor.
    * @Field OnFree: Free callback. Set by user.
    * @Field OnProgress_C: C-style progress callback. Set by user.
    * @Field OnProgress_M: Method progress callback. Set by user.
    * @Field OnProgress_P: Nested/reference progress callback. Set by user.
    * @Field NextProgressDoFree: Whether to free on next progress. Set by user.
    * @Example:
    *   var Progress: TZNet_Progress;
    *   begin
    *     Progress := MyNet.AddProgresss;
    *     Progress.OnProgress_M := MyProgressHandler;
    *     // Progress() is called automatically during MyNet.Progress()
    *   end;
  }
  TZNet_Progress = class(TCore_Object_Intermediate)
  private
    FPool_Ptr: TZNet_Progress_Pool_.PQueueStruct; { Pointer in pool. Set by constructor. }
    FOwnerFramework: TZNet; { Parent framework. Set by constructor. }
  public
    OnFree: TZNet_Progress_Free_OnEvent; { Free callback. Set by user. }
    OnProgress_C: TZNet_Progress_OnEvent_C; { C-style progress callback. Set by user. }
    OnProgress_M: TZNet_Progress_OnEvent_M; { Method progress callback. Set by user. }
    OnProgress_P: TZNet_Progress_OnEvent_P; { Nested/reference progress callback. Set by user. }
    NextProgressDoFree: Boolean; { Whether to free on next progress. Set by user. }
    property OwnerFramework: TZNet read FOwnerFramework;
    constructor Create(OwnerFramework_: TZNet);
    destructor Destroy; override;
    procedure Progress; virtual;
    procedure ResetEvent;
  end;

  TPrint_Param_Hash_Pool = class(TCritical_String_Big_Hash_Pair_Pool<Boolean>) { Hash pool for print parameters (used to filter verbose output). }
  end;

  TPeer_IO_Hash_Pool = class(TCritical_Big_Hash_Pair_Pool<Cardinal, TPeerIO>) { Hash pool mapping IO ID to TPeerIO. }
  end;

  {
    * TZNet_Instance_Pool: Global pool of all TZNet instances (for debugging and status).
    * Tracks every active network framework instance.
  }
  TZNet_Instance_Pool = class(TCritical_BigList<TZNet>)
  public
    procedure Print_Status;
    procedure Print_Service_Statistics_Info;
    procedure Print_Service_CMD_Info;
    procedure Print_Client_Statistics_Info;
    procedure Print_Client_CMD_Info;
  end;

  TCommand_Tick_Hash_Pool = class(TCritical_String_Big_Hash_Pair_Pool<TTimeTick>) { Statistics for command execution times. }
  public
    procedure SetMax(Key_: SystemString; Value_: TTimeTick); overload;
    procedure SetMax(Source: TCommand_Tick_Hash_Pool); overload;
    procedure GetKeyList(output: TPascalStringList);
  end;

  TCommand_Num_Hash_Pool = class(TCritical_String_Big_Hash_Pair_Pool<Integer>) { Statistics for command counts. }
  public
    procedure IncValue(Key_: SystemString; Value_: Integer); overload;
    procedure IncValue(Source: TCommand_Num_Hash_Pool); overload;
    procedure GetKeyList(output: TPascalStringList);
  end;

  {
    * TCommand_Hash_Pool: Pool of registered commands.
    * Maps command names to their TCommand_base instances.
  }
  TCommand_Hash_Pool = class(TCritical_String_Big_Hash_Pair_Pool<TCommand_base>)
  public
    procedure DoFree(var Key: SystemString; var Value: TCommand_base); override;
  end;

  {
    * TZNet: Base network framework class.
    * Manages command registration, IO connections, progress callbacks, statistics,
    * security settings, and P2PVM integration. Both server and client implementations
    * inherit from this class.
    * @Field FCritical: Global lock for IO operations. Created by constructor.
    * @Field FZNet_Instance_Ptr__: Pointer in global instance pool. Set by constructor.
    * @Field FCommand_Hash_Pool: Registered command pool. Created by constructor.
    * @Field FPeerIO_HashPool: IO hash pool. Created by constructor.
    * @Field FIDSeed: ID generator seed. Initialised by constructor.
    * @Field FProgress_CPS: Progress CPS meter. Created by constructor.
    * @Field FProgress_Pool: Progress event pool. Created by constructor.
    * @Field FOnExecuteCommand: Command execution hook. Set by user.
    * @Field FOnSendCommand: Command send hook. Set by user.
    * @Field FIdleTimeOut: Idle timeout. Set by user.
    * @Field FSendDataCompressed: Whether to compress sent data. Set by user.
    * @Field FCompleteBufferCompressed: Whether to compress complete buffers. Set by user.
    * @Field FFastEncrypt: Whether to use fast encryption. Set by user.
    * @Field FUsedParallelEncrypt: Whether to use parallel encryption. Set by user.
    * @Field FSyncOnResult: Whether results are synchronously processed. Set by user.
    * @Field FSyncOnCompleteBuffer: Whether complete buffers are synchronously processed. Set by user.
    * @Field FBigStreamMemorySwapSpace: Whether to use memory swap for big streams. Set by user.
    * @Field FEnabledAtomicLockAndMultiThread: Whether atomic locking is enabled. Set by user.
    * @Field FTimeOutKeepAlive: Whether to send keep-alive on timeout. Set by user.
    * @Field FQuietMode: Quiet mode flag. Set by user.
    * @Field FPer_Progress_Loop_Limit: Max commands per progress loop. Set by constructor.
    * @Field FMaxCompleteBufferSize: Max complete-buffer size. Set by constructor.
    * @Field FCompleteBufferSwapSpace: Whether to use swap for complete buffers. Set by user.
    * @Field FFrameworkIsServer: Whether this framework is a server. Set by constructor.
    * @Field FFrameworkIsClient: Whether this framework is a client. Set by constructor.
    * @Field FProgressEnabled: Whether progress is enabled. Set by Enabled_Progress/Disable_Progress.
    * @Field FOnProgress: Progress callback. Set by user.
    * @Field FProtocol: Communication protocol. Set by user.
    * @Field FSequencePacketActivted: Whether sequence packet model is active. Set by user.
    * @Field FName: Name for logging. Set by user.
    * @Example:
    *   // TZNet is the base class for all network frameworks.
    *   // Typically you use TZNet_Server or TZNet_Client directly.
    *   var Net: TZNet_Server;
    *   begin
    *     Net := TZNet_Server.Create;
    *     Net.RegisterConsole('ping').OnExecute := MyPingHandler;
    *     Net.StartService('0.0.0.0', 8080);
    *     while Running do
    *       Net.Progress;  // Drive the network
    *   end;
  }
  TZNet = class(TCore_InterfacedObject_Intermediate)
  private
    FCritical, FSend_Critical: TCritical; { Global lock for IO operations. Created by constructor. }
    FZNet_Instance_Ptr__: TZNet_Instance_Pool.PQueueStruct; { Pointer in global instance pool. Set by constructor. }
    FCommand_Hash_Pool: TCommand_Hash_Pool; { Registered command pool. Created by constructor. }
    FPeerIO_HashPool: TPeer_IO_Hash_Pool; { IO hash pool. Created by constructor. }
    FIDSeed: Cardinal; { ID generator seed. Initialised by constructor. }
    FProgress_CPS: TCPS_Tool; { Progress CPS meter. Created by constructor. }
    FProgress_Pool: TZNet_Progress_Pool; { Progress event pool. Created by constructor. }
    FOnExecuteCommand: TPeerIOCMDNotify; { Command execution hook. Set by user. }
    FOnSendCommand: TPeerIOCMDNotify; { Command send hook. Set by user. }
    FPeerIOUserDefineClass: TPeer_IO_User_Define_Class; { Factory class for UserDefine. Set by constructor/property. }
    FPeerIOUserSpecialClass: TPeer_IO_User_Special_Class; { Factory class for UserSpecial. Set by constructor/property. }
    FIdleTimeOut: TTimeTick; { Idle timeout. Set by user. }
    FPhysicsFragmentSwapSpaceTechnology: Boolean; { Whether to use swap space for fragments. Set by user. }
    FPhysicsFragmentSwapSpaceTrigger: NativeInt; { Trigger size for fragment swap. Set by user. }
    FSend_Queue_Swap_Pool: TQueueData_Pool; { Global send queue swap pool. Created by constructor. }
    FSendFlushSize: NativeInt; { default ZNet_Def_SendFlushSize }
    FSendDataCompressed: Boolean; { Whether to compress sent data. Set by user. }
    FCompleteBufferCompressed: Boolean; { Whether to compress complete buffers. Set by user. }
    FFastEncrypt: Boolean; { Whether to use fast encryption. Set by user. }
    FUsedParallelEncrypt: Boolean; { Whether to use parallel encryption. Set by user. }
    FSyncOnResult: Boolean; { Whether results are synchronously processed. Set by user. }
    FSyncOnCompleteBuffer: Boolean; { Whether complete buffers are synchronously processed. Set by user. }
    FBigStreamMemorySwapSpace: Boolean; { Whether to use memory swap for big streams. Set by user. }
    FBigStreamSwapSpaceTriggerSize: Int64; { Trigger size for big-stream swap. Set by user. }
    FEnabledAtomicLockAndMultiThread: Boolean; { Whether atomic locking is enabled. Set by user. }
    FTimeOutKeepAlive: Boolean; { Whether to send keep-alive on timeout. Set by user. }
    FQuietMode: Boolean; { Quiet mode flag. Set by user. }
    FCipherSecurityArray: TCipherSecurityArray; { Available cipher list. Set by constructor. }
    FHashSecurity: THashSecurity; { Hash security level. Set by constructor. }
    FPer_Progress_Loop_Limit: Integer; { Max commands per progress loop. Set by constructor. }
    FExtract_Physics_Fragment_Max_Size: Int64; { Max fragment extraction size. Set by constructor. }
    FMaxCompleteBufferSize: Cardinal; { Max complete-buffer size. Set by constructor. }
    FCompleteBufferCompressionCondition: Cardinal; { Minimum size for compression. Set by constructor. }
    FCompleteBufferSwapSpace: Boolean; { Whether to use swap for complete buffers. Set by user. }
    FCompleteBufferSwapSpaceTriggerSize: Int64; { Trigger size for complete-buffer swap. Set by user. }
    FAutomaticWaitRemoteReponse: Boolean; { Whether to auto-wait for remote responses. Set by user. }
    FEncrypt_P2PVM_Packet: Boolean; { Whether to encrypt P2PVM packets. Set by user. }
    FPrintParams: TPrint_Param_Hash_Pool; { Print parameter filter. Created by constructor. }
    FPostProgress: TN_Progress_ToolWithCadencer; { Post-progress tool. Created by constructor. }
    FFrameworkIsServer: Boolean; { Whether this framework is a server. Set by constructor. }
    FFrameworkIsClient: Boolean; { Whether this framework is a client. Set by constructor. }
    FFrameworkInfo: SystemString; { Framework info string. Set by constructor. }
    FProgressRuning: Boolean; { Progress re-entry guard. Set by Progress. }
    FProgressEnabled: Boolean; { Whether progress is enabled. Set by Enabled_Progress/Disable_Progress. }
    FProgressWaitRuning: Boolean; { Progress-wait re-entry guard. Set by ProgressWaitSend. }
    FOnProgress: TProgressOnZNet; { Progress callback. Set by user. }
    FCMD_Thread_Runing_Num: Integer; { Number of running command threads. Managed internally. }
    FIOInterface: IIOInterface; { IO interface. Set by user. }
    FVMInterface: IZNet_VMInterface; { P2PVM interface. Set by user. }
    FOnBigStreamInterface: IOnBigStreamInterface; { Big-stream interface. Set by user. }
    FProtocol: TCommunicationProtocol; { Communication protocol. Set by user. }
    FSequencePacketActivted: Boolean; { Whether sequence packet model is active. Set by user. }
    FPrefixName: SystemString; { Prefix for logging. Set by user. }
    FName: SystemString; { Name for logging. Set by user. }
    FInitedTimeMD5: TMD5; { MD5 of init time. Set by constructor. }
    FDoubleChannelFramework: TCore_Object; { Double-tunnel framework reference. Set by user. }
    FCustomUserData: Pointer; { Custom user pointer. Set by user. }
    FCustomUserObject: TCore_Object; { Custom user object. Set by user. }
  protected
    procedure DoPrint(const v: SystemString); virtual;
    procedure DoError(const v: SystemString); virtual;
    procedure DoWarning(const v: SystemString); virtual;
    function GetIdleTimeOut: TTimeTick; virtual;
    procedure SetIdleTimeOut(const Value: TTimeTick); virtual;
    function CanExecuteCommand(Sender: TPeerIO; const Cmd: SystemString): Boolean; virtual;
    function CanSendCommand(Sender: TPeerIO; const Cmd: SystemString): Boolean; virtual;
    function CanRegCommand(Sender: TZNet; const Cmd: SystemString): Boolean; virtual;
    procedure DelayClose(Sender: TN_Post_Execute);
    procedure DelayFree(Sender: TN_Post_Execute);
    procedure DelayExecuteOnResultState(Sender: TN_Post_Execute);
    procedure DelayExecuteOnCompleteBufferState(Sender: TN_Post_Execute);
    procedure IDLE_Trace_Execute(Sender: TN_Post_Execute);
    procedure cmd_Complete_Buffer_Stream_Reponse(Sender: TPeerIO; InData: PByte; DataSize: NativeInt);
    function MakeID: Cardinal;
    procedure FillCustomBuffer(Sender: TPeerIO; const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean); virtual;
    procedure Framework_Internal_Send_Byte_Buffer(const Sender: TPeerIO; const buff: PByte; siz: NativeInt);
    procedure Framework_Internal_Save_Receive_Buffer(const Sender: TPeerIO; const buff: Pointer; siz: Int64);
    procedure Framework_Internal_Process_Receive_Buffer(const Sender: TPeerIO);
    procedure Framework_Internal_Process_Send_Buffer(const Sender: TPeerIO);
    procedure Framework_Internal_IO_Create(const Sender: TPeerIO); virtual;
    procedure Framework_Internal_IO_Destroy(const Sender: TPeerIO); virtual;
    procedure Build_P2PAuth_Token_Result_On_IO_IDLE(Sender: TCore_Object);
    procedure Do_CMD_Result_BuildP2PAuthToken(Sender: TPeerIO; Result_: TDFE);
    procedure CMD_BuildP2PAuthToken(Sender: TPeerIO; InData, OutData: TDFE);
    procedure CMD_InitP2PTunnel(Sender: TPeerIO; InData: SystemString);
    procedure CMD_CloseP2PTunnel(Sender: TPeerIO; InData: SystemString);
    procedure VMAuthSuccessAfterDelayExecute(Sender: TN_Post_Execute);
    procedure VMAuthSuccessDelayExecute(Sender: TN_Post_Execute);
    procedure VMAuthFailedDelayExecute(Sender: TN_Post_Execute);
    procedure CMD_NULL(Sender: TPeerIO; InData: SystemString; var OutData: SystemString);
    { Command execution. }
    function ExecuteConsole(Sender: TPeerIO; const Cmd: SystemString; const InData: SystemString; var OutData: SystemString): Boolean; virtual;
    function ExecuteStream(Sender: TPeerIO; const Cmd: SystemString; InData, OutData: TDFE): Boolean; virtual;
    function ExecuteStreamNotify(Sender: TPeerIO; const Cmd: SystemString; InData: TDFE): Boolean; virtual;
    function ExecuteConsoleNotify(Sender: TPeerIO; const Cmd: SystemString; const InData: SystemString): Boolean; virtual;
    function ExecuteBigStream(Sender: TPeerIO; const Cmd: SystemString; InData: TCore_Stream; BigStreamTotal, BigStreamCompleteSize: Int64): Boolean; virtual;
    function ExecuteCompleteBuffer(Sender: TPeerIO; const Cmd: SystemString; InData: PByte; DataSize: NativeInt): Boolean; virtual;
  protected
    { Automated P2PVM }
    FAutomatedP2PVMServiceBind: TAutomatedP2PVMServiceBind; { Automated P2PVM service bindings. Created by InitAutomatedP2PVM. }
    FAutomatedP2PVMService: Boolean; { Whether automated P2PVM service is enabled. Set by user. }
    FAutomatedP2PVMClientBind: TAutomatedP2PVMClientBind; { Automated P2PVM client bindings. Created by InitAutomatedP2PVM. }
    FAutomatedP2PVMClient: Boolean; { Whether automated P2PVM client is enabled. Set by user. }
    FAutomatedP2PVMClientDelayBoot: Double; { Delay before booting automated P2PVM client. Set by user. }
    FAutomatedP2PVMAuthToken: SystemString; { Authentication token for automated P2PVM. Set by user. }
    FOnAutomatedP2PVMClientConnectionDone_C: TOnAutomatedP2PVMClientConnectionDone_C; { Automated P2PVM done (C). Set by user. }
    FOnAutomatedP2PVMClientConnectionDone_M: TOnAutomatedP2PVMClientConnectionDone_M; { Automated P2PVM done (method). Set by user. }
    FOnAutomatedP2PVMClientConnectionDone_P: TOnAutomatedP2PVMClientConnectionDone_P; { Automated P2PVM done (nested). Set by user. }
    procedure InitAutomatedP2PVM;
    procedure FreeAutomatedP2PVM;
    procedure DoAutomatedP2PVMClient_DelayRequest(Sender: TN_Post_Execute);
    procedure DoAutomatedP2PVMClient_Request(IO_ID: Cardinal);
    procedure AutomatedP2PVMClient_BuildP2PAuthTokenResult(P_IO: TPeerIO);
    procedure AutomatedP2PVMClient_OpenP2PVMTunnelResult(P_IO: TPeerIO; VMauthState: Boolean);
    procedure AutomatedP2PVMClient_ConnectionResult(Param1: Pointer; Param2: TObject; const ConnectionState: Boolean);
    procedure AutomatedP2PVMClient_Delay_Done(Sender: TN_Post_Execute);
    procedure AutomatedP2PVMClient_Done(P_IO: TPeerIO);
  protected
    { Large-scale IO support }
    FProgress_LargeScale_IO_Pool: TIO_Order; { Large-scale IO progress order. Created by InitLargeScaleIOPool. }
    FProgressMaxDelay: TTimeTick; { Max delay for large-scale progress. Set by user. }
    procedure InitLargeScaleIOPool;
    procedure FreeLargeScaleIOPool;
    procedure ProgressLargeScaleIOPool;
  public
    Statistics: array [TStatisticsType] of Int64; { Performance statistics. }
    CmdRecvStatistics: TCommand_Num_Hash_Pool; { Received command statistics. Created by constructor. }
    CmdSendStatistics: TCommand_Num_Hash_Pool; { Sent command statistics. Created by constructor. }
    CmdMaxExecuteConsumeStatistics: TCommand_Tick_Hash_Pool; { Command execution time statistics. Created by constructor. }
  public
    constructor Create(HashPoolSize: Integer);
    procedure CreateAfter; virtual;
    destructor Destroy; override;
    property Send_Critical: TCritical read FSend_Critical;
    { Sequence packet activation. }
    property SequencePacketActivted: Boolean read FSequencePacketActivted write FSequencePacketActivted;
    { Queue swap technology. }
    procedure Post_Queue_Data_To_Swap_Queue(p: PQueueData);
    { Progress event pool. }
    property Progress_Pool: TZNet_Progress_Pool read FProgress_Pool;
    function AddProgresss(Progress_: TZNet_Progress_Class): TZNet_Progress; overload;
    function AddProgresss(): TZNet_Progress; overload;
    { User protocol support. }
    property Protocol: TCommunicationProtocol read FProtocol write FProtocol;
    procedure BeginWriteCustomBuffer(P_IO: TPeerIO);
    procedure EndWriteCustomBuffer(P_IO: TPeerIO);
    procedure WriteCustomBuffer(P_IO: TPeerIO; const Buffer: PByte; const Size: NativeInt);
    { debug support. }
    property PrefixName: SystemString read FPrefixName write FPrefixName;
    property name: SystemString read FName write FName;
    { IO backcall interface. }
    property IOInterface: IIOInterface read FIOInterface write FIOInterface;
    { P2PVM backcall interface. }
    property VMInterface: IZNet_VMInterface read FVMInterface write FVMInterface;
    property OnVMInterface: IZNet_VMInterface read FVMInterface write FVMInterface;
    property OnVM: IZNet_VMInterface read FVMInterface write FVMInterface;
    procedure p2pVMTunnelAuth(Sender: TPeerIO; const Token: SystemString; var Accept: Boolean); virtual;
    procedure p2pVMTunnelOpenBefore(Sender: TPeerIO; P2PVMTunnel: TZNet_P2PVM); virtual;
    procedure p2pVMTunnelOpen(Sender: TPeerIO; P2PVMTunnel: TZNet_P2PVM); virtual;
    procedure p2pVMTunnelOpenAfter(Sender: TPeerIO; P2PVMTunnel: TZNet_P2PVM); virtual;
    procedure p2pVMTunnelClose(Sender: TPeerIO; P2PVMTunnel: TZNet_P2PVM); virtual;
    { Automated P2PVM service support. }
    property AutomatedP2PVMServiceBind: TAutomatedP2PVMServiceBind read FAutomatedP2PVMServiceBind;
    property AutomatedP2PVMBindService: TAutomatedP2PVMServiceBind read FAutomatedP2PVMServiceBind;
    property AutomatedP2PVMService: Boolean read FAutomatedP2PVMService write FAutomatedP2PVMService;
    { Automated P2PVM client support. }
    property AutomatedP2PVMClientBind: TAutomatedP2PVMClientBind read FAutomatedP2PVMClientBind;
    property AutomatedP2PVMBindClient: TAutomatedP2PVMClientBind read FAutomatedP2PVMClientBind;
    property AutomatedP2PVMClient: Boolean read FAutomatedP2PVMClient write FAutomatedP2PVMClient;
    property AutomatedP2PVMClientDelayBoot: Double read FAutomatedP2PVMClientDelayBoot write FAutomatedP2PVMClientDelayBoot;
    property AutomatedP2PVMAuthToken: SystemString read FAutomatedP2PVMAuthToken write FAutomatedP2PVMAuthToken;
    property OnAutomatedP2PVMClientConnectionDone_C: TOnAutomatedP2PVMClientConnectionDone_C read FOnAutomatedP2PVMClientConnectionDone_C write FOnAutomatedP2PVMClientConnectionDone_C;
    property OnAutomatedP2PVMClientConnectionDone_M: TOnAutomatedP2PVMClientConnectionDone_M read FOnAutomatedP2PVMClientConnectionDone_M write FOnAutomatedP2PVMClientConnectionDone_M;
    property OnAutomatedP2PVMClientConnectionDone_P: TOnAutomatedP2PVMClientConnectionDone_P read FOnAutomatedP2PVMClientConnectionDone_P write FOnAutomatedP2PVMClientConnectionDone_P;
    function AutomatedP2PVMClientConnectionDone(P_IO: TPeerIO): Boolean; overload;
    function AutomatedP2PVMClientConnectionDone(): Boolean; overload;
    procedure AutomatedP2PVM_Open(P_IO: TPeerIO); overload;
    procedure AutomatedP2PVM_Open(); overload;
    procedure AutomatedP2PVM_Open_C(P_IO: TPeerIO; const OnResult: TOnIOState_C);
    procedure AutomatedP2PVM_Open_M(P_IO: TPeerIO; const OnResult: TOnIOState_M);
    procedure AutomatedP2PVM_Open_P(P_IO: TPeerIO; const OnResult: TOnIOState_P);
    procedure AutomatedP2PVM_Close(P_IO: TPeerIO); overload;
    procedure AutomatedP2PVM_Close(); overload;
    function p2pVMTunnelReadyOk(P_IO: TPeerIO): Boolean; overload;
    function p2pVMTunnelReadyOk(): Boolean; overload;
    { IO Big Stream interface. }
    property OnBigStreamInterface: IOnBigStreamInterface read FOnBigStreamInterface write FOnBigStreamInterface;
    property OnBigStream: IOnBigStreamInterface read FOnBigStreamInterface write FOnBigStreamInterface;
    { Security support. }
    procedure SwitchMaxPerformance; virtual;
    procedure SwitchMaxSecurity; virtual;
    procedure SwitchDefaultPerformance; virtual;
    { Atomic lock for send. }
    procedure LockSend;
    procedure UnLockSend;
    { Atomic lock for all IO. }
    procedure Lock_All_IO; virtual;
    procedure UnLock_All_IO; virtual;
    { Delay run support. }
    property ProgressEngine: TN_Progress_ToolWithCadencer read FPostProgress;
    property ProgressPost: TN_Progress_ToolWithCadencer read FPostProgress;
    property PostProgress: TN_Progress_ToolWithCadencer read FPostProgress;
    property PostRun: TN_Progress_ToolWithCadencer read FPostProgress;
    property PostExecute: TN_Progress_ToolWithCadencer read FPostProgress;
    { Framework identity. }
    property FrameworkIsServer: Boolean read FFrameworkIsServer;
    property FrameworkIsClient: Boolean read FFrameworkIsClient;
    property FrameworkInfo: SystemString read FFrameworkInfo;
    function IOBusy(): Boolean;
    { Main progress loop. }
    property Progress_CPS: TCPS_Tool read FProgress_CPS;
    procedure Enabled_Progress;
    procedure Disable_Progress;
    procedure Progress; virtual;
    property OnProgress: TProgressOnZNet read FOnProgress write FOnProgress;
    procedure Progress_IO_Now_Send(IO_: TPeerIO);
    { Progress all IO with callbacks. }
    procedure ProgressPeerIOC(const OnBackcall: TPeerIOList_C); overload;
    procedure ProgressPeerIOM(const OnBackcall: TPeerIOList_M); overload;
    procedure ProgressPeerIOP(const OnBackcall: TPeerIOList_P); overload;
    procedure FastProgressPeerIOC(const OnBackcall: TPeerIOList_C); overload;
    procedure FastProgressPeerIOM(const OnBackcall: TPeerIOList_M); overload;
    procedure FastProgressPeerIOP(const OnBackcall: TPeerIOList_P); overload;
    { IO array and order. }
    procedure GetIO_Array(out IO_Array: TIO_Array); overload;
    procedure GetIO_Order(Order_: TIO_Order); overload;
    { Block progress for wait-send. }
    procedure ProgressWaitSend(P_IO: TPeerIO); overload; virtual;
    function ProgressWaitSend(IO_ID: Cardinal): Boolean; overload;

    { Print diagnostics. }
    procedure Print(const v: SystemString; const Args: array of const); overload;
    procedure Print(const v: SystemString); overload;
    procedure PrintParam(const v, Args: SystemString);
    procedure Error(const v: SystemString; const Args: array of const); overload;
    procedure Error(const v: SystemString); overload;
    procedure ErrorParam(const v, Args: SystemString);
    procedure PrintError(const v: SystemString; const Args: array of const); overload;
    procedure PrintError(const v: SystemString); overload;
    procedure PrintErrorParam(const v, Args: SystemString);
    procedure Warning(const v: SystemString);
    procedure WarningParam(const v, Args: SystemString);
    procedure PrintWarning(const v: SystemString);
    procedure PrintWarningParam(const v, Args: SystemString);
    procedure PrintRegistedCMD; overload;
    procedure PrintRegistedCMD(prefix: SystemString; incl_internalCMD: Boolean); overload;
    procedure PrintRegistedCMD(prefix: SystemString); overload;

    { Command registration. }
    function RemoveRegistedCMD(const Cmd: SystemString): Boolean;
    function DeleteRegistedCMD(const Cmd: SystemString): Boolean;
    function UnRegisted(const Cmd: SystemString): Boolean;
    function ExistsRegistedCmd(const Cmd: SystemString): Boolean;

    {
      * Registers a console (string-based) command that expects a response.
      * The command handler receives the incoming string and can modify an
      * output string variable to send back a reply. This is the standard
      * synchronous request-response model for text-based commands.
      * @Param Cmd: The name of the command to register.
      * @Returns: A TCommandConsole instance. Assign its OnExecute event
      *           to implement the command logic.
      * @Example:
      *   var Cmd: TCommandConsole;
      *   begin
      *     Cmd := MyNet.RegisterConsole('ping');
      *     Cmd.OnExecute := procedure(S: TPeerIO; In: string; var Out: string)
      *     begin
      *       Out := 'pong: ' + In;
      *     end;
      *   end;
    }
    function RegisterConsole(const Cmd: SystemString): TCommandConsole;

    {
      * Registers a stream (DFE-based) command that expects a response.
      * The handler receives an input TDFE and fills an output TDFE with the
      * structured result. Suitable for binary or complex data exchanges.
      * @Param Cmd: The command name.
      * @Returns: A TCommandStream instance for setting the handler.
      * @Example:
      *   var Cmd: TCommandStream;
      *   begin
      *     Cmd := MyNet.RegisterStream('getData');
      *     Cmd.OnExecute := procedure(S: TPeerIO; In, Out: TDFE)
      *     begin
      *       Out.WriteString('data');
      *     end;
      *   end;
    }
    function RegisterStream(const Cmd: SystemString): TCommandStream;

    {
      * Registers a stream notification command (no response expected).
      * The handler receives an input TDFE but does not send a reply. Ideal
      * for one-way data pushes, logging, or telemetry.
      * @Param Cmd: The command name.
      * @Returns: A TCommandStreamNotify instance.
    }
    function RegisterStreamNotify(const Cmd: SystemString): TCommandStreamNotify;

    {
      * Registers a console notification command (no response expected).
      * The handler receives a string input without sending a reply. Used
      * for fire-and-forget text commands.
      * @Param Cmd: The command name.
      * @Returns: A TCommandConsoleNotify instance.
    }
    function RegisterConsoleNotify(const Cmd: SystemString): TCommandConsoleNotify;

    {
      * Registers a big-stream command for handling large data transfers.
      * The handler receives a TCore_Stream (e.g., file stream) and progress
      * information (total and completed bytes). Supports chunked reception.
      * @Param Cmd: The command name.
      * @Returns: A TCommandBigStream instance.
    }
    function RegisterBigStream(const Cmd: SystemString): TCommandBigStream;

    {
      * Registers a complete-buffer command. The handler receives a raw
      * memory block (PByte + size) that has been fully reassembled. Suitable
      * for atomic data blocks with guaranteed ordering and integrity.
      * @Param Cmd: The command name.
      * @Returns: A TCommandCompleteBuffer instance.
    }
    function RegisterCompleteBuffer(const Cmd: SystemString): TCommandCompleteBuffer;

    { Optimized replacement for StreamNotify using complete-buffer technology.
      This variant decodes the complete buffer into a DFE and executes the
      handler synchronously (on the main thread). It provides better
      performance than the classic StreamNotify model by reducing protocol
      overhead and simplifying buffer assembly. To use, register the command
      and assign its OnExecute event (which receives a TDFE).
    }
    function RegisterCompleteBuffer_StreamNotify(const Cmd: SystemString): TCommandCompleteBuffer_StreamNotify;

    { Optimized replacement for StreamNotify using complete-buffer + threading.
      Similar to RegisterCompleteBuffer_StreamNotify, but the decoding and
      handler execution are performed in a background thread (asynchronous).
      This avoids blocking the main loop and is ideal for heavy processing.
      Set Sync_Decrypt = False to enable threading mode; the handler will be
      invoked on the main thread after the background work completes.
    }
    function RegisterCompleteBuffer_Asynchronous_StreamNotify(const Cmd: SystemString): TCommandCompleteBuffer_StreamNotify;

    { Optimized replacement for Stream (request-response) using complete-buffer.
      This variant uses the complete-buffer protocol to send a stream command
      that expects a response, but without waiting for the reply (non-blocking).
      The response is delivered asynchronously via a callback. This model
      reduces latency and improves throughput for high-frequency requests.
      @Param Cmd: The command name.
      @Returns: A TCommandCompleteBuffer_NoWait_Stream instance.
      Set Execute_In_Thread = True to offload processing to a background thread.
    }
    function RegisterCompleteBuffer_NoWait_Stream(const Cmd: SystemString): TCommandCompleteBuffer_NoWait_Stream;

    { Optimized replacement for Stream using complete-buffer + threading.
      This is the threaded version of RegisterCompleteBuffer_NoWait_Stream:
      the handler always runs in a background thread, and the result is sent
      asynchronously. It is suitable for CPU-intensive tasks that should not
      block the main network loop. Simply assign the OnExecute event and
      the framework will dispatch it to the thread pool.
    }
    function RegisterCompleteBuffer_NoWait_Stream_Thread(const Cmd: SystemString): TCommandCompleteBuffer_NoWait_Stream;

    { New independent complete-buffer bridge model.
      This registers a command that uses the TCommandCompleteBuffer_NoWait_Bridge
      interface, which provides advanced control over result sending. The handler
      can pause, resume, or cancel the response delivery, and can work with
      separate receive and send tunnels. This is the most flexible complete-buffer
      command type, supporting complex asynchronous workflows and integration
      with TCompleteBuffer_Stream_Event_Bridge and HPC execution.
      @Param Cmd: The command name.
      @Returns: A TCommandCompleteBuffer_NoWait_Bridge_Stream instance.
      In the handler, you receive a TCommandCompleteBuffer_NoWait_Bridge object
      that holds InData and OutData TDFEs. Call Bridge.Pause() to delay the
      response, and Bridge.Resume() to send it later.
    }
    function RegisterCompleteBuffer_NoWait_Bridge_Stream(const Cmd: SystemString): TCommandCompleteBuffer_NoWait_Bridge_Stream;

    { IO access. }
    function FirstIO: TPeerIO;
    function LastIO: TPeerIO;
    property OnExecuteCommand: TPeerIOCMDNotify read FOnExecuteCommand write FOnExecuteCommand;
    property OnSendCommand: TPeerIOCMDNotify read FOnSendCommand write FOnSendCommand;
    function ExistsID(IO_ID: Cardinal): Boolean;
    { Security configuration. }
    property HashSecurity: THashSecurity read FHashSecurity;
    property CipherSecurityArray: TCipherSecurityArray read FCipherSecurityArray;
    function GetRandomCipherSecurity: TCipherSecurity;
    property RandomCipherSecurity: TCipherSecurity read GetRandomCipherSecurity;
    { Options. }
    property IdleTimeOut: TTimeTick read GetIdleTimeOut write SetIdleTimeOut;
    property TimeOutIDLE: TTimeTick read GetIdleTimeOut write SetIdleTimeOut;
    property FastEncrypt: Boolean read FFastEncrypt write FFastEncrypt;
    property UsedParallelEncrypt: Boolean read FUsedParallelEncrypt write FUsedParallelEncrypt;
    property SyncOnResult: Boolean read FSyncOnResult write FSyncOnResult;
    property SyncOnCompleteBuffer: Boolean read FSyncOnCompleteBuffer write FSyncOnCompleteBuffer;
    property BigStreamMemorySwapSpace: Boolean read FBigStreamMemorySwapSpace write FBigStreamMemorySwapSpace;
    property BigStreamSwapSpaceTriggerSize: Int64 read FBigStreamSwapSpaceTriggerSize write FBigStreamSwapSpaceTriggerSize;
    property EnabledAtomicLockAndMultiThread: Boolean read FEnabledAtomicLockAndMultiThread write FEnabledAtomicLockAndMultiThread;
    property TimeOutKeepAlive: Boolean read FTimeOutKeepAlive write FTimeOutKeepAlive;
    property QuietMode: Boolean read FQuietMode write FQuietMode;
    property TimeOut: TTimeTick read GetIdleTimeOut write SetIdleTimeOut;
    property PhysicsFragmentSwapSpaceTechnology: Boolean read FPhysicsFragmentSwapSpaceTechnology write FPhysicsFragmentSwapSpaceTechnology;
    property PhysicsFragmentSwapSpaceTrigger: NativeInt read FPhysicsFragmentSwapSpaceTrigger write FPhysicsFragmentSwapSpaceTrigger;
    property SendFlushSize: NativeInt read FSendFlushSize write FSendFlushSize;
    property SendDataCompressed: Boolean read FSendDataCompressed write FSendDataCompressed;
    property CompleteBufferCompressed: Boolean read FCompleteBufferCompressed write FCompleteBufferCompressed;
    property Per_Progress_Loop_Limit: Integer read FPer_Progress_Loop_Limit write FPer_Progress_Loop_Limit;
    property Extract_Physics_Fragment_Max_Size: Int64 read FExtract_Physics_Fragment_Max_Size write FExtract_Physics_Fragment_Max_Size;
    property MaxCompleteBufferSize: Cardinal read FMaxCompleteBufferSize write FMaxCompleteBufferSize;
    property CompleteBufferCompressionCondition: Cardinal read FCompleteBufferCompressionCondition write FCompleteBufferCompressionCondition;
    property CompleteBufferSwapSpace: Boolean read FCompleteBufferSwapSpace write FCompleteBufferSwapSpace;
    property CompleteBufferSwapSpaceTriggerSize: Int64 read FCompleteBufferSwapSpaceTriggerSize write FCompleteBufferSwapSpaceTriggerSize;
    property AutomaticWaitRemoteReponse: Boolean read FAutomaticWaitRemoteReponse write FAutomaticWaitRemoteReponse;
    property Encrypt_P2PVM_Packet: Boolean read FEncrypt_P2PVM_Packet write FEncrypt_P2PVM_Packet;
    property ProgressMaxDelay: TTimeTick read FProgressMaxDelay write FProgressMaxDelay;
    { copy options }
    procedure CopyParamFrom(Source: TZNet);
    procedure CopyParamTo(Dest: TZNet);
    { State. }
    property CMD_Thread_Runing_Num: Integer read FCMD_Thread_Runing_Num;
    property InitedTimeMD5: TMD5 read FInitedTimeMD5;
    { Double channel framework. }
    property DoubleChannelFramework: TCore_Object read FDoubleChannelFramework write FDoubleChannelFramework;
    { User custom. }
    property CustomUserData: Pointer read FCustomUserData write FCustomUserData;
    property CustomUserObject: TCore_Object read FCustomUserObject write FCustomUserObject;
    { Hash pool. }
    property PeerIO_HashPool: TPeer_IO_Hash_Pool read FPeerIO_HashPool;
    property IOPool: TPeer_IO_Hash_Pool read FPeerIO_HashPool;
    { User-definable class factories. }
    procedure SetPeerIOUserDefineClass(const Value: TPeer_IO_User_Define_Class);
    property PeerClientUserDefineClass: TPeer_IO_User_Define_Class read FPeerIOUserDefineClass write SetPeerIOUserDefineClass;
    property PeerIOUserDefineClass: TPeer_IO_User_Define_Class read FPeerIOUserDefineClass write SetPeerIOUserDefineClass;
    property IOUserDefineClass: TPeer_IO_User_Define_Class read FPeerIOUserDefineClass write SetPeerIOUserDefineClass;
    property IODefineClass: TPeer_IO_User_Define_Class read FPeerIOUserDefineClass write SetPeerIOUserDefineClass;
    property UserDefineClass: TPeer_IO_User_Define_Class read FPeerIOUserDefineClass write SetPeerIOUserDefineClass;
    property ExternalDefineClass: TPeer_IO_User_Define_Class read FPeerIOUserDefineClass write SetPeerIOUserDefineClass;
    { User-Special class factories. }
    procedure SetPeerIOUserSpecialClass(const Value: TPeer_IO_User_Special_Class);
    property PeerClientUserSpecialClass: TPeer_IO_User_Special_Class read FPeerIOUserSpecialClass write SetPeerIOUserSpecialClass;
    property PeerIOUserSpecialClass: TPeer_IO_User_Special_Class read FPeerIOUserSpecialClass write FPeerIOUserSpecialClass;
    property IOUserSpecialClass: TPeer_IO_User_Special_Class read FPeerIOUserSpecialClass write FPeerIOUserSpecialClass;
    property IOSpecialClass: TPeer_IO_User_Special_Class read FPeerIOUserSpecialClass write FPeerIOUserSpecialClass;
    property UserSpecialClass: TPeer_IO_User_Special_Class read FPeerIOUserSpecialClass write FPeerIOUserSpecialClass;
    property ExternalSpecialClass: TPeer_IO_User_Special_Class read FPeerIOUserSpecialClass write FPeerIOUserSpecialClass;
    { Misc. }
    property IDCounter: Cardinal read FIDSeed write FIDSeed;
    property IDSeed: Cardinal read FIDSeed write FIDSeed;
    property PrintParams: TPrint_Param_Hash_Pool read FPrintParams;
  end;
{$ENDREGION 'Z-Net'}
{$REGION 'ZNetServer'}

  TOnServerCustomProtocolReceiveBufferNotify = procedure(Sender: TPeerIO; const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean) of object; { Server-side custom protocol receive callback. }
  TZNet_StableServer = class;

  {
    * TZNet_Server: Server-side network framework.
    * Manages incoming connections, handles command execution, and provides
    * broadcast and per-IO send methods. Supports both ZServer protocol and custom protocols.
    * @Field FOnServerCustomProtocolReceiveBufferNotify: Custom protocol receive callback. Set by user.
    * @Field FStableIO: Stable IO server instance. Created on demand.
    * @Example:
    *   var Server: TZNet_Server;
    *   begin
    *     Server := TZNet_Server.Create;
    *     Server.RegisterConsole('hello').OnExecute := procedure(S: TPeerIO; I: string; var O: string)
    *     begin
    *       O := 'Hello, ' + I;
    *     end;
    *     Server.StartService('0.0.0.0', 8080);
    *     while True do
    *     begin
    *       Server.Progress;
    *       Sleep(10);
    *     end;
    *   end;
  }
  TZNet_Server = class(TZNet)
  protected
    function CanExecuteCommand(Sender: TPeerIO; const Cmd: SystemString): Boolean; override;
    function CanSendCommand(Sender: TPeerIO; const Cmd: SystemString): Boolean; override;
    function CanRegCommand(Sender: TZNet; const Cmd: SystemString): Boolean; override;
    procedure Command_CipherModel(Sender: TPeerIO; InData, OutData: TDFE); virtual;
    procedure Command_Wait(Sender: TPeerIO; InData: SystemString; var OutData: SystemString); virtual;
    procedure Framework_Internal_IO_Create(const Sender: TPeerIO); override;
    procedure Framework_Internal_IO_Destroy(const Sender: TPeerIO); override;
  protected
    FOnServerCustomProtocolReceiveBufferNotify: TOnServerCustomProtocolReceiveBufferNotify; { Custom protocol receive callback. Set by user. }
    procedure FillCustomBuffer(Sender: TPeerIO; const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean); override;
  protected
    FStableIOProgressing: Boolean; { Stable IO progress guard. Set by Progress. }
    FStableIO: TZNet_StableServer; { Stable IO server instance. Created on demand. }
  public
    constructor Create; virtual;
    constructor CreateCustomHashPool(HashPoolSize: Integer); virtual;
    destructor Destroy; override;
    procedure Progress; override;
    function StableIO: TZNet_StableServer;
    procedure Disconnect(ID: Cardinal); overload;
    procedure Disconnect(ID: Cardinal; delay: Double); overload;
    procedure OnReceiveBuffer(Sender: TPeerIO; const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean); virtual;
    procedure BeginWriteBuffer(P_IO: TPeerIO);
    procedure EndWriteBuffer(P_IO: TPeerIO);
    procedure WriteBuffer(P_IO: TPeerIO; const Buffer: PByte; const Size: NativeInt); overload; virtual;
    procedure WriteBuffer(P_IO: TPeerIO; const Buffer: TMS64); overload;
    procedure WriteBuffer(P_IO: TPeerIO; const Buffer: TMem64); overload;
    procedure WriteBuffer(P_IO: TPeerIO; const Buffer: TMS64; const doneFreeBuffer: Boolean); overload;
    procedure WriteBuffer(P_IO: TPeerIO; const Buffer: TMem64; const doneFreeBuffer: Boolean); overload;
    procedure StopService; virtual;
    function StartService(Host: SystemString; Port: Word): Boolean; virtual;
    procedure DoIOConnectBefore(Sender: TPeerIO); virtual;
    procedure DoIOConnectAfter(Sender: TPeerIO); virtual;
    procedure DoIODisconnect(Sender: TPeerIO); virtual;
    { Send console commands to a specific IO. }
    procedure SendConsoleCmd(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString); overload;
    procedure SendConsoleCmdM(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_M); overload;
    procedure SendConsoleCmdM(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M); overload;
    procedure SendConsoleCmdM(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M; const OnFailed: TOnConsoleFailed_M); overload;
    procedure SendConsoleCmdP(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_P); overload;
    procedure SendConsoleCmdP(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P); overload;
    procedure SendConsoleCmdP(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P; const OnFailed: TOnConsoleFailed_P); overload;
    procedure SendConsoleCmd(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString); overload;
    procedure SendConsoleCmdM(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_M); overload;
    procedure SendConsoleCmdM(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M); overload;
    procedure SendConsoleCmdM(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M; const OnFailed: TOnConsoleFailed_M); overload;
    procedure SendConsoleCmdP(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_P); overload;
    procedure SendConsoleCmdP(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P); overload;
    procedure SendConsoleCmdP(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P; const OnFailed: TOnConsoleFailed_P); overload;
    { Send stream commands to a specific IO. }
    procedure SendStreamCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean); overload;
    procedure SendStreamCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE); overload;
    procedure SendStreamCmdM(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_M; DoneAutoFree: Boolean); overload;
    procedure SendStreamCmdM(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_M); overload;
    procedure SendStreamCmdM(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M); overload;
    procedure SendStreamCmdM(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M; const OnFailed: TOnStreamFailed_M); overload;
    procedure SendStreamCmdP(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_P; DoneAutoFree: Boolean); overload;
    procedure SendStreamCmdP(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_P); overload;
    procedure SendStreamCmdP(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P); overload;
    procedure SendStreamCmdP(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P; const OnFailed: TOnStreamFailed_P); overload;
    procedure SendStreamCmd(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean); overload;
    procedure SendStreamCmd(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE); overload;
    procedure SendStreamCmdM(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_M; DoneAutoFree: Boolean); overload;
    procedure SendStreamCmdM(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_M); overload;
    procedure SendStreamCmdM(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M); overload;
    procedure SendStreamCmdM(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M; const OnFailed: TOnStreamFailed_M); overload;
    procedure SendStreamCmdP(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_P; DoneAutoFree: Boolean); overload;
    procedure SendStreamCmdP(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_P); overload;
    procedure SendStreamCmdP(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P); overload;
    procedure SendStreamCmdP(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P; const OnFailed: TOnStreamFailed_P); overload;
    { Send direct commands. }
    procedure SendConsoleNotifyCmd(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString); overload;
    procedure SendConsoleNotifyCmd(P_IO: TPeerIO; const Cmd: SystemString); overload;
    procedure SendConsoleNotifyCmd(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString); overload;
    procedure SendConsoleNotifyCmd(IO_ID: Cardinal; const Cmd: SystemString); overload;
    procedure SendStreamNotifyCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean); overload;
    procedure SendStreamNotifyCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE); overload;
    procedure SendStreamNotifyCmd(P_IO: TPeerIO; const Cmd: SystemString); overload;
    procedure SendStreamNotifyCmd(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean); overload;
    procedure SendStreamNotifyCmd(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE); overload;
    procedure SendStreamNotifyCmd(IO_ID: Cardinal; const Cmd: SystemString); overload;
    { Send big-stream commands. }
    procedure SendBigStream(P_IO: TPeerIO; const Cmd: SystemString; BigStream: TCore_Stream; StartPos: Int64; DoneAutoFree: Boolean); overload;
    procedure SendBigStream(P_IO: TPeerIO; const Cmd: SystemString; BigStream: TCore_Stream; DoneAutoFree: Boolean); overload;
    procedure SendBigStream(IO_ID: Cardinal; const Cmd: SystemString; BigStream: TCore_Stream; StartPos: Int64; DoneAutoFree: Boolean); overload;
    procedure SendBigStream(IO_ID: Cardinal; const Cmd: SystemString; BigStream: TCore_Stream; DoneAutoFree: Boolean); overload;
    { Send complete-buffer commands. }
    procedure SendCompleteBuffer(P_IO: TPeerIO; const Cmd: SystemString; buff: PByte; BuffSize: NativeInt; DoneAutoFree: Boolean); overload;
    procedure SendCompleteBuffer(P_IO: TPeerIO; const Cmd: SystemString; buff: TMS64; DoneAutoFree: Boolean); overload;
    procedure SendCompleteBuffer(P_IO: TPeerIO; const Cmd: SystemString; buff: TMem64; DoneAutoFree: Boolean); overload;
    procedure SendCompleteBuffer(P_IO: TPeerIO; const Cmd: SystemString; buff: TDFE); overload;
    procedure SendCompleteBuffer_StreamNotify(P_IO: TPeerIO; const Cmd: SystemString; buff: TDFE); overload;
    procedure SendCompleteBuffer_NoWait_StreamM(P_IO: TPeerIO; const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_M); overload;
    procedure SendCompleteBuffer_NoWait_StreamP(P_IO: TPeerIO; const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_P); overload;
    procedure SendCompleteBuffer(IO_ID: Cardinal; const Cmd: SystemString; buff: PByte; BuffSize: NativeInt; DoneAutoFree: Boolean); overload;
    procedure SendCompleteBuffer(IO_ID: Cardinal; const Cmd: SystemString; buff: TMS64; DoneAutoFree: Boolean); overload;
    procedure SendCompleteBuffer(IO_ID: Cardinal; const Cmd: SystemString; buff: TMem64; DoneAutoFree: Boolean); overload;
    procedure SendCompleteBuffer(IO_ID: Cardinal; const Cmd: SystemString; buff: TDFE); overload;
    procedure SendCompleteBuffer_NoWait_StreamM(IO_ID: Cardinal; const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_M); overload;
    procedure SendCompleteBuffer_NoWait_StreamP(IO_ID: Cardinal; const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_P); overload;
    procedure SendCompleteBuffer_StreamNotify(IO_ID: Cardinal; const Cmd: SystemString; buff: TDFE); overload;
    { Send NULL command (keep-alive). }
    procedure Send_NULL(P_IO: TPeerIO); overload;
    procedure SendNULL(P_IO: TPeerIO); overload;
    { wait send }
    function WaitSendConsoleCmd(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString; overload; virtual;
    procedure WaitSendStreamCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick); overload; virtual;
    function WaitSendConsoleCmd(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString; overload;
    procedure WaitSendStreamCmd(IO_ID: Cardinal; const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick); overload;
    procedure Send_NULL(IO_ID: Cardinal); overload;
    { Broadcast commands to all connected clients. }
    procedure BroadcastConsoleNotifyCmd(const Cmd, ConsoleData: SystemString);
    procedure BroadcastStreamNotifyCmd(const Cmd: SystemString; StreamData: TDFE);
    procedure BroadcastCompleteBufferCmd(const Cmd: SystemString; buff: PByte; BuffSize: NativeInt); overload;
    procedure BroadcastCompleteBufferCmd(const Cmd: SystemString; StreamData: TDFE); overload;
    { IO enumeration. }
    function GetCount: Integer;
    property Count: Integer read GetCount;
    function Exists(P_IO: TPeerIO): Boolean; overload;
    function Exists(P_IO: TPeer_IO_User_Define): Boolean; overload;
    function Exists(P_IO: TPeer_IO_User_Special): Boolean; overload;
    function Exists(IO_ID: Cardinal): Boolean; overload;
    function GetPeerIO(ID: Cardinal): TPeerIO;
    property IO[ID: Cardinal]: TPeerIO read GetPeerIO; default;
    property PeerIO[ID: Cardinal]: TPeerIO read GetPeerIO;
  end;

  TZNet_ServerClass = class of TZNet_Server;
{$ENDREGION 'ZNetServer'}
{$REGION 'ZNetClient'}
  TZNet_Client = class;

  IZNet_ClientInterface = interface { Client interface for connection events. }
    procedure ClientConnected(Sender: TZNet_Client);
    procedure ClientDisconnect(Sender: TZNet_Client);
  end;

  TOnClientCustomProtocolReceiveBufferNotify = procedure(Sender: TZNet_Client; const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean) of object; { Client-side custom protocol receive callback. }
  TOnCipherModelDone = procedure(Sender: TZNet_Client) of object; { Cipher model done callback. }
  TZNet_StableClient = class;

  PZNet_ServerState = ^TZNet_ServerState; { Server state snapshot (copied from the server during handshake). }

  {
    * TZNet_ServerState: Server state snapshot.
    * Copied from the server during handshake to synchronize client configuration.
    * @Field UsedParallelEncrypt: Whether parallel encryption is used.
    * @Field SyncOnResult: Whether results are synchronous.
    * @Field SyncOnCompleteBuffer: Whether complete buffers are synchronous.
    * @Field EnabledAtomicLockAndMultiThread: Whether atomic locking is enabled.
    * @Field TimeOutKeepAlive: Whether keep-alive is enabled.
    * @Field QuietMode: Quiet mode flag.
    * @Field IdleTimeOut: Idle timeout value.
    * @Field SendDataCompressed: Whether send data is compressed.
    * @Field CompleteBufferCompressed: Whether complete buffers are compressed.
    * @Field MaxCompleteBufferSize: Maximum complete buffer size.
    * @Field ProgressMaxDelay: Maximum progress delay.
  }
  TZNet_ServerState = record
    UsedParallelEncrypt, SyncOnResult, SyncOnCompleteBuffer, EnabledAtomicLockAndMultiThread, TimeOutKeepAlive, QuietMode: Boolean;
    IdleTimeOut: TTimeTick;
    SendDataCompressed, CompleteBufferCompressed: Boolean;
    MaxCompleteBufferSize: Cardinal;
    ProgressMaxDelay: TTimeTick;
    UID: TUID___;
    procedure Reset;
  end;

  {
    * TZNet_Client: Client-side network framework.
    * Manages a single connection to a server. Supports synchronous and
    * asynchronous connection, command sending, and receives callbacks for
    * connection events. Also provides P2PVM client functionality.
    * @Field FOnInterface: Client event interface. Set by user.
    * @Field FConnectInitWaiting: Whether waiting for connection initialisation.
    * @Field FAsyncConnectTimeout: Async connect timeout. Set by user.
    * @Field FOnCipherModelDone: Cipher model done callback. Set by user.
    * @Field FServerState: Server state snapshot. Set by Do_CipherModel_Result.
    * @Field FIgnoreProcessConnectedAndDisconnect: Whether to ignore connect/disconnect events.
    * @Field FLastConnectIsSuccessed: Last connect success flag.
    * @Field FStableIO: Stable IO client instance. Created on demand.
    * @Example:
    *   var Client: TZNet_Client;
    *   begin
    *     Client := TZNet_Client.Create;
    *     Client.Connect('127.0.0.1', 8080);
    *     Client.SendConsoleCmd('hello', 'world');
    *     while Client.Connected do
    *     begin
    *       Client.Progress;
    *       Sleep(10);
    *     end;
    *   end;
  }
  TZNet_Client = class(TZNet)
  private
    FOnInterface: IZNet_ClientInterface; { Client event interface. Set by user. }
    FConnectInitWaiting: Boolean; { Whether waiting for connection initialisation. Set by DoConnected. }
    FConnectInitWaitingTimeout: TTimeTick; { Timeout for connection init. Set by DoConnected. }
    FAsyncConnectTimeout: TTimeTick; { Async connect timeout. Set by user. }
    FOnCipherModelDone: TOnCipherModelDone; { Cipher model done callback. Set by user. }
    FServerState: TZNet_ServerState; { Server state snapshot. Set by Do_CipherModel_Result. }
    FIgnoreProcessConnectedAndDisconnect: Boolean; { Whether to ignore connect/disconnect events. Set by user. }
    FLastConnectIsSuccessed: Boolean; { Last connect success flag. Set by DoConnected. }
    FRequestTime: TTimeTick; { Request timestamp. Set by DoConnected. }
    FReponseTime: TTimeTick; { Response timestamp. Set by Do_CipherModel_Result. }
  private
    FStableIOProgressing: Boolean; { Stable IO progress guard. Set by Progress. }
    FStableIO: TZNet_StableClient; { Stable IO client instance. Created on demand. }
  protected
    function CanExecuteCommand(Sender: TPeerIO; const Cmd: SystemString): Boolean; override;
    function CanSendCommand(Sender: TPeerIO; const Cmd: SystemString): Boolean; override;
    function CanRegCommand(Sender: TZNet; const Cmd: SystemString): Boolean; override;
  protected
    FOnClientCustomProtocolReceiveBufferNotify: TOnClientCustomProtocolReceiveBufferNotify; { Custom protocol callback. Set by user. }
    procedure FillCustomBuffer(Sender: TPeerIO; const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean); override;
  private
    FWaiting: Boolean; { Waiting for response flag. Set by WaitC/M/P. }
    FWaitingTimeOut: TTimeTick; { Waiting timeout. Set by WaitC/M/P. }
    FOnWaitResult_C: TOnState_C; { Wait result callback (C). Set by WaitC. }
    FOnWaitResult_M: TOnState_M; { Wait result callback (method). Set by WaitM. }
    FOnWaitResult_P: TOnState_P; { Wait result callback (nested). Set by WaitP. }
    procedure ConsoleResult_Wait(Sender: TPeerIO; Result_: SystemString);
    function GetWaitTimeout(const t: TTimeTick): TTimeTick;
  private
    procedure Do_IO_IDLE_FreeSelf(Data_: TCore_Object);
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure DelayFreeSelf;
    { init interface }
    procedure Do_CipherModel_Result(Sender: TPeerIO; Result_: TDFE); virtual;
    procedure DoConnected(Sender: TPeerIO); virtual;
    procedure DoDisconnect(Sender: TPeerIO); virtual;
    { P2PVM tunnel access. }
    function GetP2PVMTunnel: TZNet_P2PVM;
    property P2PVM: TZNet_P2PVM read GetP2PVMTunnel;
    property P2PVMTunnel: TZNet_P2PVM read GetP2PVMTunnel;
    { IO IDLE trace. }
    procedure IO_IDLE_TraceC(data: TCore_Object; const OnNotify: TOnDataNotify_C);
    procedure IO_IDLE_TraceM(data: TCore_Object; const OnNotify: TOnDataNotify_M);
    procedure IO_IDLE_TraceP(data: TCore_Object; const OnNotify: TOnDataNotify_P);
    procedure IO_IDLE_Trace_And_FreeSelf(Additional_Object_: TCore_Object);
    { Custom protocol receive. }
    procedure OnReceiveBuffer(const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean); virtual;
    procedure BeginWriteBuffer();
    procedure EndWriteBuffer();
    procedure WriteBuffer(const Buffer: PByte; const Size: NativeInt); overload; virtual;
    procedure WriteBuffer(const Buffer: TMS64); overload;
    procedure WriteBuffer(const Buffer: TMem64); overload;
    procedure WriteBuffer(const Buffer: TMS64; const doneFreeBuffer: Boolean); overload;
    procedure WriteBuffer(const Buffer: TMem64; const doneFreeBuffer: Boolean); overload;
    { Server state. }
    function ServerState: PZNet_ServerState;
    { Network delay. }
    property ReponseTime: TTimeTick read FReponseTime;
    { Main progress. }
    procedure Progress; override;
    function StableIO: TZNet_StableClient;
    procedure TriggerDoDisconnect;
    { Connection state. }
    function Connected: Boolean; virtual;
    property LastConnectIsSuccessed: Boolean read FLastConnectIsSuccessed;
    function ClientIO: TPeerIO; virtual;
    procedure TriggerDoConnectFailed; virtual;
    procedure TriggerDoConnectFinished; virtual;
    procedure CipherModelDone; virtual;
    property OnCipherModelDone: TOnCipherModelDone read FOnCipherModelDone write FOnCipherModelDone;
    { Asynchronous connection. }
    property AsyncConnectTimeout: TTimeTick read FAsyncConnectTimeout write FAsyncConnectTimeout;
    procedure AsyncConnectC(addr: SystemString; Port: Word; const OnResult: TOnState_C); overload; virtual;
    procedure AsyncConnectM(addr: SystemString; Port: Word; const OnResult: TOnState_M); overload; virtual;
    procedure AsyncConnectP(addr: SystemString; Port: Word; const OnResult: TOnState_P); overload; virtual;
    procedure AsyncConnectC(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: TOnParamState_C); overload;
    procedure AsyncConnectM(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: TOnParamState_M); overload;
    procedure AsyncConnectP(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: TOnParamState_P); overload;
    { Synchronous connection. }
    function Connect(addr: SystemString; Port: Word): Boolean; virtual;
    { Disconnect. }
    procedure Disconnect; virtual;
    procedure DelayCloseIO; overload;
    procedure DelayCloseIO(const t: Double); overload;
    { Wait for a response (synchronous). }
    function Wait(TimeOut_: TTimeTick): SystemString; overload;
    { Wait for a response (asynchronous). }
    function WaitC(TimeOut_: TTimeTick; const OnResult: TOnState_C): Boolean;
    function WaitM(TimeOut_: TTimeTick; const OnResult: TOnState_M): Boolean;
    function WaitP(TimeOut_: TTimeTick; const OnResult: TOnState_P): Boolean;
    { IO state. }
    function WaitSendBusy: Boolean;
    function LastQueueData: PQueueData;
    function LastQueueCmd: SystemString;
    function QueueCmdCount: Integer;
    function Last_IO_IDLE_Time: TTimeTick;
    function Client_ID: Cardinal;
    { Send console commands. }
    procedure SendConsoleCmd(const Cmd, ConsoleData: SystemString); overload;
    procedure SendConsoleCmdM(const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_M); overload;
    procedure SendConsoleCmdM(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M); overload;
    procedure SendConsoleCmdM(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M; const OnFailed: TOnConsoleFailed_M); overload;
    procedure SendConsoleCmdP(const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_P); overload;
    procedure SendConsoleCmdP(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P); overload;
    procedure SendConsoleCmdP(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P; const OnFailed: TOnConsoleFailed_P); overload;
    { Send stream commands. }
    procedure SendStreamCmd(const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean); overload;
    procedure SendStreamCmd(const Cmd: SystemString; StreamData: TDFE); overload;
    procedure SendStreamCmdM(const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_M; DoneAutoFree: Boolean); overload;
    procedure SendStreamCmdM(const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_M); overload;
    procedure SendStreamCmdM(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M); overload;
    procedure SendStreamCmdM(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M; const OnFailed: TOnStreamFailed_M); overload;
    procedure SendStreamCmdP(const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_P; DoneAutoFree: Boolean); overload;
    procedure SendStreamCmdP(const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_P); overload;
    procedure SendStreamCmdP(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P); overload;
    procedure SendStreamCmdP(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P; const OnFailed: TOnStreamFailed_P); overload;
    { Send direct commands. }
    procedure SendConsoleNotifyCmd(const Cmd, ConsoleData: SystemString); overload;
    procedure SendConsoleNotifyCmd(const Cmd: SystemString); overload;
    procedure SendStreamNotifyCmd(const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean); overload;
    procedure SendStreamNotifyCmd(const Cmd: SystemString; StreamData: TDFE); overload;
    procedure SendStreamNotifyCmd(const Cmd: SystemString); overload;
    { Send big-stream commands. }
    procedure SendBigStream(const Cmd: SystemString; BigStream: TCore_Stream; StartPos: Int64; DoneAutoFree: Boolean); overload;
    procedure SendBigStream(const Cmd: SystemString; BigStream: TCore_Stream; DoneAutoFree: Boolean); overload;
    { Send complete-buffer commands. }
    procedure SendCompleteBuffer(const Cmd: SystemString; buff: PByte; BuffSize: NativeInt; DoneAutoFree: Boolean); overload;
    procedure SendCompleteBuffer(const Cmd: SystemString; buff: TMS64; DoneAutoFree: Boolean); overload;
    procedure SendCompleteBuffer(const Cmd: SystemString; buff: TMem64; DoneAutoFree: Boolean); overload;
    procedure SendCompleteBuffer(const Cmd: SystemString; buff: TDFE); overload;
    procedure SendCompleteBuffer_StreamNotify(const Cmd: SystemString; buff: TDFE);
    procedure SendCompleteBuffer_NoWait_StreamM(const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_M);
    procedure SendCompleteBuffer_NoWait_StreamP(const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_P);
    { Send NULL (keep-alive). }
    procedure Send_NULL();
    procedure SendNULL();
    { Wait send (synchronous with timeout). }
    function WaitSendConsoleCmd(const Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString; virtual;
    procedure WaitSendStreamCmd(const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick); virtual;
    { Client interface. }
    property OnInterface: IZNet_ClientInterface read FOnInterface write FOnInterface;
    property NotyifyInterface: IZNet_ClientInterface read FOnInterface write FOnInterface;
    property OnNotyifyInterface: IZNet_ClientInterface read FOnInterface write FOnInterface;
    { Remote server info. }
    function RemoteID: Cardinal;
    function RemoteKey: TCipherKeyBuffer;
    function RemoteInited: Boolean;
  end;

  TZNet_ClientClass = class of TZNet_Client;
{$ENDREGION 'ZNetClient'}
{$REGION 'P2pVM_IO'}
  PP2PVMFragmentPacket = ^TP2PVMFragmentPacket; { P2PVM fragment packet structure. }

  {
    * TP2PVMFragmentPacket: P2PVM fragment packet structure.
    * Used for sending data fragments over the P2PVM tunnel.
    * @Field BuffSiz: Payload size. Set by Build_P2PVM_Packet.
    * @Field FrameworkID: Target framework ID. Set by Build_P2PVM_Packet.
    * @Field p2pID: Target IO ID. Set by Build_P2PVM_Packet.
    * @Field pkType: Packet type. Set by Build_P2PVM_Packet.
    * @Field buff: Payload buffer. Set by Build_P2PVM_Packet.
  }
  TP2PVMFragmentPacket = record
    BuffSiz: Cardinal;
    FrameworkID: Cardinal;
    p2pID: Cardinal;
    pkType: Byte;
    buff: PByte;
    procedure Init;
    procedure Build_P2PVM_Send_Buffer(Stream: TMem64);
  end;

  TP2P_VM_Fragment_Packet_Pool = class(TOrderStruct<PP2PVMFragmentPacket>); { FIFO pool for P2PVM fragment packets. }

  {
    * TP2PVM_PeerIO: Virtual IO over a P2PVM tunnel.
    * This IO represents a remote peer connected via the P2PVM overlay.
    * It forwards writes to the P2PVM tunnel and receives data from it.
    * @Field FLinkVM: Parent P2PVM tunnel. Set by creator.
    * @Field FRealSendBuff: Send buffer. Created by constructor.
    * @Field FSendQueue: Fragment queue. Created by constructor.
    * @Field FRemote_frameworkID: Remote framework ID. Set by VMConnectSuccessed/Connecting.
    * @Field FRemote_p2pID: Remote IO ID. Set by VMConnectSuccessed/Connecting.
    * @Field FIP: Remote IPv6 address. Set by creator.
    * @Field FPort: Remote port. Set by creator.
    * @Field FDestroySyncRemote: Whether to sync remote disconnect. Set by creator.
  }
  TP2PVM_PeerIO = class(TPeerIO)
  private
    FLinkVM: TZNet_P2PVM; { Parent P2PVM tunnel. Set by creator. }
    FRealSendBuff: TMem64; { Send buffer. Created by constructor. }
    FSendQueue: TP2P_VM_Fragment_Packet_Pool; { Fragment queue. Created by constructor. }
    FRemote_frameworkID: Cardinal; { Remote framework ID. Set by VMConnectSuccessed/Connecting. }
    FRemote_p2pID: Cardinal; { Remote IO ID. Set by VMConnectSuccessed/Connecting. }
    FIP: TIPV6; { Remote IPv6 address. Set by creator. }
    FPort: Word; { Remote port. Set by creator. }
    FDestroySyncRemote: Boolean; { Whether to sync remote disconnect. Set by creator. }
  public
    procedure CreateAfter; override;
    destructor Destroy; override;
    function Connected: Boolean; override;
    procedure Disconnect; override;
    procedure Write_IO_Buffer(const buff: PByte; const Size: NativeInt); override;
    procedure WriteBufferOpen; override;
    procedure WriteBufferFlush; override;
    procedure WriteBufferClose; override;
    function GetPeerIP: SystemString; override;
    function WriteBuffer_is_NULL: Boolean; override;
    function WriteBuffer_State(var WriteBuffer_Queue_Num, WriteBuffer_Size: Int64): Boolean; override;
    procedure Progress; override;
    property LinkVM: TZNet_P2PVM read FLinkVM;
    property Remote_frameworkID: Cardinal read FRemote_frameworkID;
    property Remote_p2pID: Cardinal read FRemote_p2pID;
  end;
{$ENDREGION 'P2pVM_IO'}
{$REGION 'P2pVM_Server'}

  {
    * TP2PVMListen: P2PVM listen record.
    * @Field FrameworkID: Framework that owns this listen. Set by StartService.
    * @Field ListenHost: IPv6 address being listened on. Set by StartService.
    * @Field ListenPort: Port being listened on. Set by StartService.
    * @Field Listening: Whether listen is active. Set by StartService/StopService.
  }
  TP2PVMListen = record
    FrameworkID: Cardinal;
    ListenHost: TIPV6;
    ListenPort: Word;
    Listening: Boolean;
  end;

  PP2PVMListen = ^TP2PVMListen;

  TP2PVM_Listen_List = class(TGenericsList<PP2PVMListen>)

    {
      * TZNet_WithP2PVM_Server: Server that can be exposed over P2PVM.
      * When installed into a P2PVM tunnel, this server becomes reachable
      * from remote peers through the virtual network.
      * @Field FFrameworkListenPool: Listen records. Created by constructor.
      * @Field FLinkVMPool: Linked P2PVM instances. Created by constructor.
      * @Field FFrameworkWithVM_ID: Framework ID in P2PVM. Set by user or auto-assigned.
      * @Example:
      *   var Server: TZNet_WithP2PVM_Server;
      *   begin
      *     Server := TZNet_WithP2PVM_Server.Create;
      *     Server.StartService('::1', 12345);  // Listen on P2PVM
      *     // Install the server into a P2PVM tunnel:
      *     P2PVM.InstallLogicFramework(Server);
      *   end;
    }
  end;

  TZNet_WithP2PVM_Server = class(TZNet_Server)
  protected
    procedure Connecting(SenderVM: TZNet_P2PVM;
      const Remote_frameworkID, FrameworkID: Cardinal; const IPV6: TIPV6; const Port: Word; var Allowed: Boolean); virtual;
    procedure ListenState(SenderVM: TZNet_P2PVM; const IPV6: TIPV6; const Port: Word; const State: Boolean); virtual;
  protected
    FFrameworkListenPool: TCore_List; { Listen records. Created by constructor. }
    FLinkVMPool: TUInt32HashObjectList; { Linked P2PVM instances. Created by constructor. }
    FFrameworkWithVM_ID: Cardinal; { Framework ID in P2PVM. Set by user or auto-assigned. }
    procedure ProgressDisconnectClient(P_IO: TPeerIO);
    function ListenCount: Integer;
    function GetListen(const index: Integer): PP2PVMListen;
    function FindListen(const IPV6: TIPV6; const Port: Word): PP2PVMListen;
    function FindListening(const IPV6: TIPV6; const Port: Word): PP2PVMListen;
    procedure DeleteListen(const IPV6: TIPV6; const Port: Word);
    procedure ClearListen;
  public
    constructor Create; override;
    constructor CustomCreate(HashPoolSize: Integer; FrameworkID: Cardinal);
    destructor Destroy; override;
    procedure Progress; override;
    procedure CloseAllClient;
    procedure ProgressStopServiceWithPerVM(SenderVM: TZNet_P2PVM);
    procedure StopService; override;
    function StartService(Host_: SystemString; Port: Word): Boolean; override;
    function WaitSendConsoleCmd(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString; override;
    procedure WaitSendStreamCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick); override;
  end;
{$ENDREGION 'P2pVM_Server'}
{$REGION 'P2pVM_Client'}

  TZNet_WithP2PVM_Client_Clone_Pool = class(TBigList<TZNet_WithP2PVM_Client>) { Pool of P2PVM client clones. }

    {
      * TZNet_WithP2PVM_Client: Client that connects over P2PVM.
      * This client establishes a connection through a P2PVM tunnel to a remote
      * server exposed via P2PVM. It can also create clones (additional virtual
      * connections) over the same tunnel.
      * @Field FLinkVM: Parent P2PVM tunnel. Set by InstallLogicFramework.
      * @Field FFrameworkWithVM_ID: Framework ID in P2PVM. Set by user or auto-assigned.
      * @Field FVMClientIO: Virtual IO for this client. Created by Connect/AsyncConnect.
      * @Field FVMConnected: Whether the virtual connection is established.
      * @Field FP2PVM_ClonePool: Pool of clone clients. Created by constructor.
      * @Field FP2PVM_CloneOwner: Owner of this clone (if this is a clone).
      * @Example:
      *   var Client: TZNet_WithP2PVM_Client;
      *   begin
      *     Client := TZNet_WithP2PVM_Client.Create;
      *     // Install the client into a P2PVM tunnel:
      *     P2PVM.InstallLogicFramework(Client);
      *     Client.AsyncConnect('::1', 12345, MyHandler);
      *     // Create a clone:
      *     Client.CloneConnectM(MyCloneHandler);
      *   end;
    }
  end;

  TZNet_WithP2PVM_Client = class(TZNet_Client)
  protected
    procedure Framework_Internal_IO_Create(const Sender: TPeerIO); override;
    procedure Framework_Internal_IO_Destroy(const Sender: TPeerIO); override;
    procedure VMConnectSuccessed(SenderVM: TZNet_P2PVM; Remote_frameworkID, Remote_p2pID, FrameworkID: Cardinal); virtual;
    procedure VMDisconnect(SenderVM: TZNet_P2PVM); virtual;
  protected
    FLinkVM: TZNet_P2PVM; { Parent P2PVM tunnel. Set by InstallLogicFramework. }
    FFrameworkWithVM_ID: Cardinal; { Framework ID in P2PVM. Set by user or auto-assigned. }
    FVMClientIO: TP2PVM_PeerIO; { Virtual IO for this client. Created by Connect/AsyncConnect. }
    FVMConnected: Boolean; { Whether the virtual connection is established. Set by VMConnectSuccessed. }
    FP2PVM_ClonePool: TZNet_WithP2PVM_Client_Clone_Pool; { Pool of clone clients. Created by constructor. }
    FP2PVM_ClonePool_Ptr: TZNet_WithP2PVM_Client_Clone_Pool.PQueueStruct; { Pointer in clone pool (if this is a clone). Set by CloneConnect. }
    FP2PVM_CloneOwner: TZNet_WithP2PVM_Client; { Owner of this clone (if this is a clone). Set by CloneConnect. }
    FP2PVM_Clone_NextProgressDoFreeSelf: Boolean; { Whether to free self on next progress. Set by user. }
    FP2PVM_ProgressWaitSend_Busy: Boolean; { Progress-wait re-entry guard. Set by ProgressWaitSend. }
  private
    FOnP2PVMAsyncConnectNotify_C: TOnState_C; { Async connect result (C). Set by AsyncConnectC. }
    FOnP2PVMAsyncConnectNotify_M: TOnState_M; { Async connect result (method). Set by AsyncConnectM. }
    FOnP2PVMAsyncConnectNotify_P: TOnState_P; { Async connect result (nested). Set by AsyncConnectP. }
  public
    constructor Create; overload; override;
    constructor CustomCreate(FrameworkID: Cardinal); overload;
    destructor Destroy; override;
    property ClonePool: TZNet_WithP2PVM_Client_Clone_Pool read FP2PVM_ClonePool;
    function CloneConnectC(OnResult: TOnP2PVM_CloneConnectEvent_C): TP2PVM_CloneConnectEventBridge;
    function CloneConnectM(OnResult: TOnP2PVM_CloneConnectEvent_M): TP2PVM_CloneConnectEventBridge;
    function CloneConnectP(OnResult: TOnP2PVM_CloneConnectEvent_P): TP2PVM_CloneConnectEventBridge;
    property P2PVM_Clone_NextProgressDoFreeSelf: Boolean read FP2PVM_Clone_NextProgressDoFreeSelf write FP2PVM_Clone_NextProgressDoFreeSelf;
    procedure TriggerDoConnectFailed; override;
    procedure TriggerDoConnectFinished; override;
    function Connected: Boolean; override;
    function ClientIO: TPeerIO; override;
    procedure Progress; override;
    procedure AsyncConnect(addr: SystemString; Port: Word);
    procedure AsyncConnectC(addr: SystemString; Port: Word; const OnResult: TOnState_C); override;
    procedure AsyncConnectM(addr: SystemString; Port: Word; const OnResult: TOnState_M); override;
    procedure AsyncConnectP(addr: SystemString; Port: Word; const OnResult: TOnState_P); override;
    function Connect(addr: SystemString; Port: Word): Boolean; override;
    procedure AsyncConnectC(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: TOnParamState_C); overload;
    procedure AsyncConnectM(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: TOnParamState_M); overload;
    procedure AsyncConnectP(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: TOnParamState_P); overload;
    procedure Disconnect; override;
    procedure DoBackCall_Progress(Sender: TZNet);
    procedure ProgressWaitSend(P_IO: TPeerIO); override;
    property LinkVM: TZNet_P2PVM read FLinkVM;
    property FrameworkWithVM_ID: Cardinal read FFrameworkWithVM_ID;
    property VMClientIO: TP2PVM_PeerIO read FVMClientIO;
  end;
{$ENDREGION 'P2pVM_Client'}
{$REGION 'P2pVM'}

  TZNet_List_C = procedure(Sender: TZNet); { Callback types for iterating over ZNet instances in a P2PVM. }
  TZNet_List_M = procedure(Sender: TZNet) of object;
{$IFDEF FPC}
  TZNet_List_P = procedure(Sender: TZNet) is nested;
{$ELSE FPC}
  TZNet_List_P = reference to procedure(Sender: TZNet);
{$ENDIF FPC}
  TP2PVMAuthSuccessMethod = procedure(Sender: TZNet_P2PVM) of object; { Method for P2PVM auth success. }

  {
    * TZNet_P2PVM: Peer-to-Peer Virtual Machine overlay network.
    * This class establishes a virtual network over an existing TPeerIO connection.
    * It provides:
    * - Authentication (handshake with auth token)
    * - Virtual listening and connecting (NAT-traversal)
    * - Fragmented and encrypted data transfer
    * - Echo/keep-alive for latency and liveness
    * - Management of virtual framework instances
    * The P2PVM can host multiple logical ZNet frameworks (both server and client)
    * over a single physical connection.
    * @Field FOwner_IO: Underlying physical IO. Set by OpenP2PVMTunnel.
    * @Field FAuthWaiting: Whether authentication is waiting. Set by AuthWaiting.
    * @Field FAuthed: Whether authentication succeeded. Set by Hook_ProcessReceiveBuffer.
    * @Field FAuthSending: Whether authentication token is being sent. Set by AuthVM.
    * @Field FFrameworkPool: Installed frameworks. Created by constructor.
    * @Field FFrameworkListenPool: Listen records. Created by constructor.
    * @Field FMaxVMFragmentSize: Max fragment size. Set by user.
    * @Field FProgress_Send_Size: Max bytes to send per progress. Set by user.
    * @Field FQuietMode: Quiet mode. Set by user.
    * @Field FReceiveStream: Receive buffer. Created by constructor.
    * @Field FSendStream: Send buffer. Created by constructor.
    * @Field FWaitEchoList: Outstanding echo requests. Created by constructor.
    * @Field FVMID: Virtual machine ID. Set by OpenP2PVMTunnel.
    * @Field OnAuthSuccessOnesNotify: One-time auth success callback. Set by caller.
    * @Example:
    *   var VM: TZNet_P2PVM;
    *   begin
    *     VM := TZNet_P2PVM.Create(16384);
    *     VM.OpenP2PVMTunnel(MyIO);  // Establish tunnel over existing connection
    *     VM.AuthWaiting;            // Wait for auth
    *     VM.AuthVM;                 // Authenticate
    *     // Install frameworks into the VM
    *     VM.InstallLogicFramework(MyServer);
    *     VM.InstallLogicFramework(MyClient);
    *     while Running do
    *       VM.Progress;  // Drive the virtual network
    *   end;
  }
  TZNet_P2PVM = class(TCore_Object_Intermediate)
  protected
    FOwner_IO: TPeerIO; { Underlying physical IO. Set by OpenP2PVMTunnel. }
    FAuthWaiting: Boolean; { Whether authentication is waiting. Set by AuthWaiting. }
    FAuthed: Boolean; { Whether authentication succeeded. Set by Hook_ProcessReceiveBuffer. }
    FAuthSending: Boolean; { Whether authentication token is being sent. Set by AuthVM. }
    FFrameworkPool: TUInt32HashObjectList; { Installed frameworks. Created by constructor. }
    FFrameworkListenPool: TP2PVM_Listen_List; { Listen records. Created by constructor. }
    FMaxVMFragmentSize: Cardinal; { Max fragment size. Set by user. }
    FProgress_Send_Size: Int64; { Max bytes to send per progress. Set by user. }
    FQuietMode: Boolean; { Quiet mode. Set by user. }
    FReceiveStream: TMem64; { Receive buffer. Created by constructor. }
    FSendStream: TMem64; { Send buffer. Created by constructor. }
    FWaitEchoList: TP2PVM_ECHO_List; { Outstanding echo requests. Created by constructor. }
    FVMID: Cardinal; { Virtual machine ID. Set by OpenP2PVMTunnel. }
    OnAuthSuccessOnesNotify: TP2PVMAuthSuccessMethod; { One-time auth success callback. Set by caller. }
  protected
    procedure Hook_SendByteBuffer(const Sender: TPeerIO; const buff: PByte; siz: NativeInt);
    procedure Hook_SaveReceiveBuffer(const Sender: TPeerIO; const buff: Pointer; siz: Int64);
    procedure Hook_ProcessReceiveBuffer(const Sender: TPeerIO);
    procedure Hook_ClientDestroy(const Sender: TPeerIO);
    procedure SendVMBuffer(const buff: Pointer; const siz: NativeInt);
    procedure ReceivedEchoing(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
    procedure ReceivedEcho(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
    procedure ReceivedListen(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
    procedure ReceivedListenState(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
    procedure ReceivedConnecting(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
    procedure ReceivedConnectedReponse(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
    procedure ReceivedDisconnect(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
    procedure ReceivedLogicFragmentData(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
    procedure ReceivedOwnerIOFragmentData(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
    procedure DoProcessPerClientFragmentSend(P_IO: TPeerIO);
    procedure DoPerClientClose(P_IO: TPeerIO);
  public
    constructor Create(HashPoolSize: Integer);
    destructor Destroy; override;
    function Build_P2PVM_Packet(BuffSiz, FrameworkID, p2pID: Cardinal; pkType: Byte; buff: PByte): PP2PVMFragmentPacket;
    class procedure FreeP2PVMPacket(p: PP2PVMFragmentPacket);
    property Owner_IO: TPeerIO read FOwner_IO;
    procedure Progress;
    procedure ProgressZNet_C(const OnBackcall: TZNet_List_C);
    procedure ProgressZNet_M(const OnBackcall: TZNet_List_M);
    procedure ProgressZNet_P(const OnBackcall: TZNet_List_P);
    procedure OpenP2PVMTunnel(c: TPeerIO);
    procedure CloseP2PVMTunnel;
    property FrameworkPool: TUInt32HashObjectList read FFrameworkPool;
    procedure InstallLogicFramework(Inst: TZNet);
    procedure UninstallLogicFramework(Inst: TZNet);
    property MaxVMFragmentSize: Cardinal read FMaxVMFragmentSize write FMaxVMFragmentSize;
    property Progress_Send_Size: Int64 read FProgress_Send_Size write FProgress_Send_Size;
    property QuietMode: Boolean read FQuietMode write FQuietMode;
    procedure AuthWaiting;
    procedure AuthVM; overload;
    property WasAuthed: Boolean read FAuthed;
    procedure AuthSuccessed;
    procedure echoing(const OnEchoPtr: PP2PVM_ECHO; TimeOut_: TTimeTick);
    procedure echoingC(const OnResult: TOnState_C; TimeOut_: TTimeTick);
    procedure echoingM(const OnResult: TOnState_M; TimeOut_: TTimeTick);
    procedure echoingP(const OnResult: TOnState_P; TimeOut_: TTimeTick);
    procedure echoBuffer(const buff: Pointer; const siz: NativeInt);
    procedure SendListen(const FrameworkID: Cardinal; const IPV6: TIPV6; const Port: Word; const Listening: Boolean);
    procedure SendListenState(const FrameworkID: Cardinal; const IPV6: TIPV6; const Port: Word; const Listening: Boolean);
    procedure SendConnecting(const Remote_frameworkID, FrameworkID, p2pID: Cardinal; const IPV6: TIPV6; const Port: Word);
    procedure SendConnectedReponse(const Remote_frameworkID, Remote_p2pID, FrameworkID, p2pID: Cardinal);
    procedure SendDisconnect(const Remote_frameworkID, Remote_p2pID: Cardinal);
    function ListenCount: Integer;
    function GetListen(const index: Integer): PP2PVMListen;
    function FindListen(const IPV6: TIPV6; const Port: Word): PP2PVMListen;
    function FindListening(const IPV6: TIPV6; const Port: Word): PP2PVMListen;
    procedure DeleteListen(const IPV6: TIPV6; const Port: Word);
    procedure ClearListen;
  end;
{$ENDREGION 'P2pVM'}
{$REGION 'StableIO'}

  TStableServer_PeerIO = class; { User define for stable server owner IO. }

  {
    * TStableServer_OwnerIO_UserDefine: User define for stable server owner IO.
    * Holds a reference to the stable IO associated with this physical connection.
    * @Field BindStableIO: Associated stable IO. Set by cmd_BuildStableIO/cmd_OpenStableIO.
  }
  TStableServer_OwnerIO_UserDefine = class(TPeer_IO_User_Define)
  public
    BindStableIO: TStableServer_PeerIO; { Associated stable IO. Set by cmd_BuildStableIO/cmd_OpenStableIO. }
    constructor Create(Owner_: TPeerIO); override;
    destructor Destroy; override;
  end;

  {
    * TStableServer_PeerIO: Stable IO for server side.
    * This is a virtual peer that can survive reconnections of the underlying
    * physical IO. It maintains its state and buffer even if the physical
    * connection is lost and re-established.
    * @Field Activted: Whether stable IO is active. Set by cmd_BuildStableIO.
    * @Field DestroyRecycleOwnerIO: Whether to recycle owner IO on destroy. Set by user.
    * @Field Connection_Token: Unique connection token. Set by cmd_BuildStableIO.
    * @Field Internal_Bind_Owner_IO: Underlying physical IO. Set by cmd_BuildStableIO/cmd_OpenStableIO.
    * @Field OfflineTick: Offline timestamp. Updated by Progress.
    * @Example:
    *   // StableIO is managed automatically by TZNet_CustomStableServer.
    *   // Clients can reconnect and resume their session.
  }
  TStableServer_PeerIO = class(TPeerIO)
  public
    Activted: Boolean; { Whether stable IO is active. Set by cmd_BuildStableIO. }
    DestroyRecycleOwnerIO: Boolean; { Whether to recycle owner IO on destroy. Set by user. }
    Connection_Token: Cardinal; { Unique connection token. Set by cmd_BuildStableIO. }
    Internal_Bind_Owner_IO: TPeerIO; { Underlying physical IO. Set by cmd_BuildStableIO/cmd_OpenStableIO. }
    OfflineTick: TTimeTick; { Offline timestamp. Updated by Progress. }
    property BindOwnerIO: TPeerIO read Internal_Bind_Owner_IO write Internal_Bind_Owner_IO;
    procedure CreateAfter; override;
    destructor Destroy; override;
    function Connected: Boolean; override;
    procedure Disconnect; override;
    procedure Write_IO_Buffer(const buff: PByte; const Size: NativeInt); override;
    procedure WriteBufferOpen; override;
    procedure WriteBufferFlush; override;
    procedure WriteBufferClose; override;
    function GetPeerIP: SystemString; override;
    function WriteBuffer_is_NULL: Boolean; override;
    function WriteBuffer_State(var WriteBuffer_Queue_Num, WriteBuffer_Size: Int64): Boolean; override;
    procedure Progress; override;
  end;

  {
    * TZNet_CustomStableServer: Server that provides stable IO sessions.
    * Stable IO allows clients to reconnect and resume their sessions without
    * losing state. This is useful for long-lived connections that may
    * experience temporary network interruptions.
    * @Field Connection_Token_Counter: Token generator counter. Incremented by cmd_BuildStableIO.
    * @Field FOwnerIOServer: Underlying physics server. Set by SetOwnerIOServer.
    * @Field FOfflineTimeout: Offline timeout. Set by user.
    * @Field FLimitSequencePacketMemoryUsage: Memory limit for sequence packets. Set by user.
    * @Field FAutoFreeOwnerIOServer: Whether to auto-free owner server. Set by user.
    * @Field FAutoProgressOwnerIOServer: Whether to auto-progress owner server. Set by user.
    * @Example:
    *   var Server: TZNet_CustomStableServer;
    *   begin
    *     Server := TZNet_CustomStableServer.Create;
    *     Server.OwnerIOServer := MyPhysicsServer;  // Wraps a physical server
    *     Server.StartService('0.0.0.0', 8080);
    *     // Clients can now reconnect and resume their sessions.
    *   end;
  }
  TZNet_CustomStableServer = class(TZNet_Server)
  protected
    Connection_Token_Counter: Cardinal; { Token generator counter. Incremented by cmd_BuildStableIO. }
    FOwnerIOServer: TZNet_Server; { Underlying physics server. Set by SetOwnerIOServer. }
    FOfflineTimeout: TTimeTick; { Offline timeout. Set by user. }
    FLimitSequencePacketMemoryUsage: Int64; { Memory limit for sequence packets. Set by user. }
    FAutoFreeOwnerIOServer: Boolean; { Whether to auto-free owner server. Set by user. }
    FAutoProgressOwnerIOServer: Boolean; { Whether to auto-progress owner server. Set by user. }
    CustomStableServerProgressing: Boolean; { Progress re-entry guard. Set by Progress. }
    procedure ServerCustomProtocolReceiveBufferNotify(Sender: TPeerIO; const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean);
    procedure SetOwnerIOServer(const Value: TZNet_Server);
    procedure cmd_BuildStableIO(Sender: TPeerIO; InData, OutData: TDFE);
    procedure cmd_OpenStableIO(Sender: TPeerIO; InData, OutData: TDFE);
    procedure cmd_CloseStableIO(Sender: TPeerIO; InData: SystemString);
  public
    constructor Create; override;
    destructor Destroy; override;
    property OwnerIOServer: TZNet_Server read FOwnerIOServer write SetOwnerIOServer;
    property OfflineTimeout: TTimeTick read FOfflineTimeout write FOfflineTimeout;
    property LimitSequencePacketMemoryUsage: Int64 read FLimitSequencePacketMemoryUsage write FLimitSequencePacketMemoryUsage;
    property AutoFreeOwnerIOServer: Boolean read FAutoFreeOwnerIOServer write FAutoFreeOwnerIOServer;
    property AutoProgressOwnerIOServer: Boolean read FAutoProgressOwnerIOServer write FAutoProgressOwnerIOServer;
    function StartService(Host: SystemString; Port: Word): Boolean; override;
    procedure StopService; override;
    procedure Progress; override;
    function WaitSendConsoleCmd(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString; override;
    procedure WaitSendStreamCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick); override;
  end;

  TZNet_StableServer = class(TZNet_CustomStableServer);

  {
    * TStableClient_PeerIO: Stable IO for client side.
    * Maintains session state across reconnections.
    * @Field Activted: Whether stable IO is active. Set by BuildStableIO_Result/OpenStableIO_Result.
    * @Field WaitConnecting: Whether waiting for connection. Set by PostConnection/PostReconnection.
    * @Field OwnerIO_LastConnectTick: Last connect attempt timestamp. Set by PostReconnection.
    * @Field Connection_Token: Unique connection token. Set by BuildStableIO_Result/OpenStableIO_Result.
    * @Field BindOwnerIO: Underlying physical IO. Set by BuildStableIO_Result/OpenStableIO_Result.
  }
  TStableClient_PeerIO = class(TPeerIO)
  public
    Activted: Boolean; { Whether stable IO is active. Set by BuildStableIO_Result/OpenStableIO_Result. }
    WaitConnecting: Boolean; { Whether waiting for connection. Set by PostConnection/PostReconnection. }
    OwnerIO_LastConnectTick: TTimeTick; { Last connect attempt timestamp. Set by PostReconnection. }
    Connection_Token: Cardinal; { Unique connection token. Set by BuildStableIO_Result/OpenStableIO_Result. }
    BindOwnerIO: TPeerIO; { Underlying physical IO. Set by BuildStableIO_Result/OpenStableIO_Result. }
    procedure CreateAfter; override;
    destructor Destroy; override;
    function Connected: Boolean; override;
    procedure Disconnect; override;
    procedure Write_IO_Buffer(const buff: PByte; const Size: NativeInt); override;
    procedure WriteBufferOpen; override;
    procedure WriteBufferFlush; override;
    procedure WriteBufferClose; override;
    function GetPeerIP: SystemString; override;
    function WriteBuffer_is_NULL: Boolean; override;
    function WriteBuffer_State(var WriteBuffer_Queue_Num, WriteBuffer_Size: Int64): Boolean; override;
    procedure Progress; override;
  end;

  {
    * TZNet_CustomStableClient: Client that provides stable IO sessions.
    * Automatically reconnects when the physical connection is lost and
    * re-establishes the stable session with the same state.
    * @Field FOwnerIOClient: Underlying physics client. Set by SetOwnerIOClient.
    * @Field FStableClientIO: Stable IO instance. Created by constructor.
    * @Field FConnection_Addr: Connection address. Set by Connect/AsyncConnect.
    * @Field FConnection_Port: Connection port. Set by Connect/AsyncConnect.
    * @Field FAutomatedConnection: Whether automated reconnection is enabled. Set by user.
    * @Field FLimitSequencePacketMemoryUsage: Memory limit for sequence packets. Set by user.
    * @Field FAutoFreeOwnerIOClient: Whether to auto-free owner client. Set by user.
    * @Field FAutoProgressOwnerIOClient: Whether to auto-progress owner client. Set by user.
    * @Example:
    *   var Client: TZNet_CustomStableClient;
    *   begin
    *     Client := TZNet_CustomStableClient.Create;
    *     Client.OwnerIOClient := MyPhysicsClient;  // Wraps a physical client
    *     Client.Connect('127.0.0.1', 8080);
    *     // If the connection drops, Client will automatically reconnect.
    *   end;
  }
  TZNet_CustomStableClient = class(TZNet_Client)
  protected
    FOwnerIOClient: TZNet_Client; { Underlying physics client. Set by SetOwnerIOClient. }
    FStableClientIO: TStableClient_PeerIO; { Stable IO instance. Created by constructor. }
    FConnection_Addr: SystemString; { Connection address. Set by Connect/AsyncConnect. }
    FConnection_Port: Word; { Connection port. Set by Connect/AsyncConnect. }
    FAutomatedConnection: Boolean; { Whether automated reconnection is enabled. Set by user. }
    FLimitSequencePacketMemoryUsage: Int64; { Memory limit for sequence packets. Set by user. }
    FAutoFreeOwnerIOClient: Boolean; { Whether to auto-free owner client. Set by user. }
    FAutoProgressOwnerIOClient: Boolean; { Whether to auto-progress owner client. Set by user. }
    CustomStableClientProgressing: Boolean; { Progress re-entry guard. Set by Progress. }
    KeepAliveChecking: Boolean; { Whether keep-alive check is in progress. Set by Progress. }
    SaveLastCommunicationTick_Received: TTimeTick; { Saved receive tick for keep-alive. Set by Progress. }
    FOnAsyncConnectNotify_C: TOnState_C; { Async connect result (C). Set by AsyncConnectC. }
    FOnAsyncConnectNotify_M: TOnState_M; { Async connect result (method). Set by AsyncConnectM. }
    FOnAsyncConnectNotify_P: TOnState_P; { Async connect result (nested). Set by AsyncConnectP. }
    procedure ClientCustomProtocolReceiveBufferNotify(Sender: TZNet_Client; const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean);
    procedure SetOwnerIOClient(const Value: TZNet_Client);
    procedure BuildStableIO_Result(Sender: TPeerIO; Result_: TDFE);
    procedure AsyncConnectResult(const cState: Boolean);
    procedure PostConnection(Sender: TN_Post_Execute);
    procedure OpenStableIO_Result(Sender: TPeerIO; Result_: TDFE);
    procedure AsyncReconnectionResult(const cState: Boolean);
    procedure PostReconnection(Sender: TN_Post_Execute);
    procedure Reconnection;
    function GetStopCommunicationTimeTick: TTimeTick;
  public
    constructor Create; override;
    destructor Destroy; override;
    property OwnerIOClient: TZNet_Client read FOwnerIOClient write SetOwnerIOClient;
    property LimitSequencePacketMemoryUsage: Int64 read FLimitSequencePacketMemoryUsage write FLimitSequencePacketMemoryUsage;
    property AutoFreeOwnerIOClient: Boolean read FAutoFreeOwnerIOClient write FAutoFreeOwnerIOClient;
    property AutoProgressOwnerIOClient: Boolean read FAutoProgressOwnerIOClient write FAutoProgressOwnerIOClient;
    property AutomatedConnection: Boolean read FAutomatedConnection write FAutomatedConnection;
    property StopCommunicationTimeTick: TTimeTick read GetStopCommunicationTimeTick;
    property StableClientIO: TStableClient_PeerIO read FStableClientIO;
    procedure TriggerDoConnectFailed; override;
    procedure TriggerDoConnectFinished; override;
    procedure AsyncConnectC(addr: SystemString; Port: Word; const OnResult: TOnState_C); override;
    procedure AsyncConnectM(addr: SystemString; Port: Word; const OnResult: TOnState_M); override;
    procedure AsyncConnectP(addr: SystemString; Port: Word; const OnResult: TOnState_P); override;
    function Connect(addr: SystemString; Port: Word): Boolean; override;
    function Connected: Boolean; override;
    procedure Disconnect; override;
    function ClientIO: TPeerIO; override;
    procedure Progress; override;
  end;

  TZNet_StableClient = class(TZNet_CustomStableClient);
{$ENDREGION 'StableIO'}
{$REGION 'HPC Support Base'}
  THPC_Base = class; { Base class for HPC (High-Performance Computing) job objects. }

  THPC_Instance_Pool = class(TCritical_BigList<THPC_Base>) { Pool of HPC base objects. }
  public
    procedure DoFree(var data: THPC_Base); override;
  end;

  {
    * THPC_Base: Base class for thread-pool executed tasks.
    * All HPC task objects derive from this class. They are automatically
    * added to the global instance pool for lifecycle management.
    * @Field Instance_Ptr: Pointer in global instance pool. Set by constructor.
    * @Example:
    *   type
    *     TMyHPCTask = class(THPC_Base)
    *       procedure Execute;
    *     end;
    *   // The task will be automatically tracked in HPC_Instance_Pool.
  }
  THPC_Base = class(TCore_Object_Intermediate)
  public
    Instance_Ptr: THPC_Instance_Pool.PQueueStruct; { Pointer in global instance pool. Set by constructor. }
    constructor Create;
    procedure Do_Free_Instance_Ptr; virtual;
    destructor Destroy; override;
  end;
{$ENDREGION 'HPC Support Base'}
{$REGION 'HPC Stream Support'}

  THPC_Stream = class;
  TOnHPC_Stream_C = procedure(thSender: THPC_Stream; ThInData, ThOutData: TDFE);
  TOnHPC_Stream_M = procedure(thSender: THPC_Stream; ThInData, ThOutData: TDFE) of object;
  TOnHPC_Stream_Done_C = procedure(thSender: THPC_Stream; IO: TPeerIO; ThInData, ThOutData: TDFE);
  TOnHPC_Stream_Done_M = procedure(thSender: THPC_Stream; IO: TPeerIO; ThInData, ThOutData: TDFE) of object;
{$IFDEF FPC}
  TOnHPC_Stream_P = procedure(thSender: THPC_Stream; ThInData, ThOutData: TDFE) is nested;
  TOnHPC_Stream_Done_P = procedure(thSender: THPC_Stream; IO: TPeerIO; ThInData, ThOutData: TDFE) is nested;
{$ELSE FPC}
  TOnHPC_Stream_P = reference to procedure(thSender: THPC_Stream; ThInData, ThOutData: TDFE);
  TOnHPC_Stream_Done_P = reference to procedure(thSender: THPC_Stream; IO: TPeerIO; ThInData, ThOutData: TDFE);
{$ENDIF FPC}

  {
    * THPC_Stream: HPC task that executes a stream-style command in a thread.
    * The input and output are TDFE (data frame exchange) objects. The task
    * runs in a thread pool and delivers the result back to the main thread
    * via the OnDone callback.
    * @Field Thread: Worker thread. Set during execution.
    * @Field Framework: Parent framework. Set by caller.
    * @Field Cmd: Command name. Set by caller.
    * @Field TriggerTime: Creation timestamp. Set by constructor.
    * @Field WorkID: IO identifier. Set by caller.
    * @Field Send_Tunnel: Send tunnel framework. Set by caller.
    * @Field Send_Tunnel_ID: Send tunnel IO ID. Set by caller.
    * @Field UserData: User pointer. Set by caller.
    * @Field UserObject: User object. Set by caller.
    * @Field UserVariant: User variant. Set by caller.
    * @Field InData, OutData: Input and output data. Set by caller.
    * @Field OnDone_C: Done callback (C). Set by caller.
    * @Field OnDone_M: Done callback (method). Set by caller.
    * @Field OnDone_P: Done callback (nested). Set by caller.
    * @Example:
    *   // In a stream command handler:
    *   RunHPC_StreamM(Sender, MyData, MyObject, InData, OutData,
    *     procedure(thSender: THPC_Stream; ThInData, ThOutData: TDFE)
    *     begin
    *       // Process ThInData in a background thread
    *       ThOutData.WriteString('processed');
    *     end
    *   );
  }
  THPC_Stream = class sealed(THPC_Base)
  protected
    On_C: TOnHPC_Stream_C; { C-style execution callback. Set by caller. }
    On_M: TOnHPC_Stream_M; { Method execution callback. Set by caller. }
    On_P: TOnHPC_Stream_P; { Nested/reference execution callback. Set by caller. }
    procedure Run(Sender: TCompute);
    procedure RunDone();
  public
    Thread: TCompute; { Worker thread. Set during execution. }
    Framework: TZNet; { Parent framework. Set by caller. }
    Cmd: SystemString; { Command name. Set by caller. }
    TriggerTime: TTimeTick; { Creation timestamp. Set by constructor. }
    WorkID: Cardinal; { IO identifier. Set by caller. }
    Send_Tunnel: TZNet; { Send tunnel framework. Set by caller. }
    Send_Tunnel_ID: Cardinal; { Send tunnel IO ID. Set by caller. }
    UserData: Pointer; { User pointer. Set by caller. }
    UserObject: TCore_Object; { User object. Set by caller. }
    UserVariant: Variant; { User variant. Set by caller. }
    InData, OutData: TDFE; { Input and output data. Set by caller. }
    OnDone_C: TOnHPC_Stream_Done_C; { Done callback (C). Set by caller. }
    OnDone_M: TOnHPC_Stream_Done_M; { Done callback (method). Set by caller. }
    OnDone_P: TOnHPC_Stream_Done_P; { Done callback (nested). Set by caller. }
    property ID: Cardinal read WorkID;
    constructor Create;
    destructor Destroy; override;
    function IsOnline: Boolean;
    function IO: TPeerIO;
  end;

procedure RunHPC_StreamC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData, OutData: TDFE; const OnRun: TOnHPC_Stream_C); overload;
procedure RunHPC_StreamC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData, OutData: TDFE; const OnRun: TOnHPC_Stream_C); overload;
procedure RunHPC_StreamM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData, OutData: TDFE; const OnRun: TOnHPC_Stream_M); overload;
procedure RunHPC_StreamM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData, OutData: TDFE; const OnRun: TOnHPC_Stream_M); overload;
procedure RunHPC_StreamP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData, OutData: TDFE; const OnRun: TOnHPC_Stream_P); overload;
procedure RunHPC_StreamP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData, OutData: TDFE; const OnRun: TOnHPC_Stream_P); overload;
{$ENDREGION 'HPC Stream Support'}
{$REGION 'HPC StreamNotify Support'}


type
  THPC_StreamNotify = class;
  TOnHPC_StreamNotify_C = procedure(thSender: THPC_StreamNotify; ThInData: TDFE);
  TOnHPC_StreamNotify_M = procedure(thSender: THPC_StreamNotify; ThInData: TDFE) of object;
{$IFDEF FPC}
  TOnHPC_StreamNotify_P = procedure(thSender: THPC_StreamNotify; ThInData: TDFE) is nested;
{$ELSE FPC}
  TOnHPC_StreamNotify_P = reference to procedure(thSender: THPC_StreamNotify; ThInData: TDFE);
{$ENDIF FPC}

  {
    * THPC_StreamNotify: HPC task that executes a direct-stream command in a thread.
    * Unlike THPC_Stream, this task does not produce an output; it only processes
    * the incoming data.
    * @Field Thread: Worker thread. Set during execution.
    * @Field Framework: Parent framework. Set by caller.
    * @Field Cmd: Command name. Set by caller.
    * @Field TriggerTime: Creation timestamp. Set by constructor.
    * @Field WorkID: IO identifier. Set by caller.
    * @Field Send_Tunnel: Send tunnel framework. Set by caller.
    * @Field Send_Tunnel_ID: Send tunnel IO ID. Set by caller.
    * @Field UserData: User pointer. Set by caller.
    * @Field UserObject: User object. Set by caller.
    * @Field UserVariant: User variant. Set by caller.
    * @Field InData: Input data. Set by caller.
    * @Example:
    *   // In a stream notify command handler:
    *   RunHPC_StreamNotifyM(Sender, MyData, MyObject, InData,
    *     procedure(thSender: THPC_StreamNotify; ThInData: TDFE)
    *     begin
    *       // Process ThInData in a background thread
    *     end
    *   );
  }
  THPC_StreamNotify = class sealed(THPC_Base)
  protected
    On_C: TOnHPC_StreamNotify_C; { C-style execution callback. Set by caller. }
    On_M: TOnHPC_StreamNotify_M; { Method execution callback. Set by caller. }
    On_P: TOnHPC_StreamNotify_P; { Nested/reference execution callback. Set by caller. }
    procedure Run(Sender: TCompute);
  public
    Thread: TCompute; { Worker thread. Set during execution. }
    Framework: TZNet; { Parent framework. Set by caller. }
    Cmd: SystemString; { Command name. Set by caller. }
    TriggerTime: TTimeTick; { Creation timestamp. Set by constructor. }
    WorkID: Cardinal; { IO identifier. Set by caller. }
    Send_Tunnel: TZNet; { Send tunnel framework. Set by caller. }
    Send_Tunnel_ID: Cardinal; { Send tunnel IO ID. Set by caller. }
    UserData: Pointer; { User pointer. Set by caller. }
    UserObject: TCore_Object; { User object. Set by caller. }
    UserVariant: Variant; { User variant. Set by caller. }
    InData: TDFE; { Input data. Set by caller. }
    property ID: Cardinal read WorkID;
    constructor Create;
    destructor Destroy; override;
    function IsOnline: Boolean;
    function IO: TPeerIO;
  end;

procedure RunHPC_StreamNotifyC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: TDFE; const OnRun: TOnHPC_StreamNotify_C); overload;
procedure RunHPC_StreamNotifyC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: TDFE; const OnRun: TOnHPC_StreamNotify_C); overload;
procedure RunHPC_StreamNotifyM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: TDFE; const OnRun: TOnHPC_StreamNotify_M); overload;
procedure RunHPC_StreamNotifyM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: TDFE; const OnRun: TOnHPC_StreamNotify_M); overload;
procedure RunHPC_StreamNotifyP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: TDFE; const OnRun: TOnHPC_StreamNotify_P); overload;
procedure RunHPC_StreamNotifyP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: TDFE; const OnRun: TOnHPC_StreamNotify_P); overload;
{$ENDREGION 'HPC StreamNotify Support'}
{$REGION 'HPC Console Support'}


type
  THPC_Console = class;
  TOnHPC_Console_C = procedure(thSender: THPC_Console; ThInData: SystemString; var ThOutData: SystemString);
  TOnHPC_Console_M = procedure(thSender: THPC_Console; ThInData: SystemString; var ThOutData: SystemString) of object;
  TOnHPC_Console_Done_C = procedure(thSender: THPC_Console; IO: TPeerIO; ThInData: SystemString; var ThOutData: SystemString);
  TOnHPC_Console_Done_M = procedure(thSender: THPC_Console; IO: TPeerIO; ThInData: SystemString; var ThOutData: SystemString) of object;
{$IFDEF FPC}
  TOnHPC_Console_P = procedure(thSender: THPC_Console; ThInData: SystemString; var ThOutData: SystemString) is nested;
  TOnHPC_Console_Done_P = procedure(thSender: THPC_Console; IO: TPeerIO; ThInData: SystemString; var ThOutData: SystemString) is nested;
{$ELSE FPC}
  TOnHPC_Console_P = reference to procedure(thSender: THPC_Console; ThInData: SystemString; var ThOutData: SystemString);
  TOnHPC_Console_Done_P = reference to procedure(thSender: THPC_Console; IO: TPeerIO; ThInData: SystemString; var ThOutData: SystemString);
{$ENDIF FPC}

  {
    * THPC_Console: HPC task that executes a console command in a thread.
    * The input and output are strings. The task runs in a thread pool and
    * delivers the result back to the main thread.
    * @Field Thread: Worker thread. Set during execution.
    * @Field Framework: Parent framework. Set by caller.
    * @Field Cmd: Command name. Set by caller.
    * @Field TriggerTime: Creation timestamp. Set by constructor.
    * @Field WorkID: IO identifier. Set by caller.
    * @Field Send_Tunnel: Send tunnel framework. Set by caller.
    * @Field Send_Tunnel_ID: Send tunnel IO ID. Set by caller.
    * @Field UserData: User pointer. Set by caller.
    * @Field UserObject: User object. Set by caller.
    * @Field UserVariant: User variant. Set by caller.
    * @Field InData, OutData: Input and output strings. Set by caller.
    * @Field OnDone_C: Done callback (C). Set by caller.
    * @Field OnDone_M: Done callback (method). Set by caller.
    * @Field OnDone_P: Done callback (nested). Set by caller.
    * @Example:
    *   // In a console command handler:
    *   RunHPC_ConsoleM(Sender, MyData, MyObject, InData, OutData,
    *     procedure(thSender: THPC_Console; ThInData: string; var ThOutData: string)
    *     begin
    *       ThOutData := 'Processed: ' + ThInData;
    *     end
    *   );
  }
  THPC_Console = class sealed(THPC_Base)
  protected
    On_C: TOnHPC_Console_C; { C-style execution callback. Set by caller. }
    On_M: TOnHPC_Console_M; { Method execution callback. Set by caller. }
    On_P: TOnHPC_Console_P; { Nested/reference execution callback. Set by caller. }
    procedure Run(Sender: TCompute);
    procedure RunDone();
  public
    Thread: TCompute; { Worker thread. Set during execution. }
    Framework: TZNet; { Parent framework. Set by caller. }
    Cmd: SystemString; { Command name. Set by caller. }
    TriggerTime: TTimeTick; { Creation timestamp. Set by constructor. }
    WorkID: Cardinal; { IO identifier. Set by caller. }
    Send_Tunnel: TZNet; { Send tunnel framework. Set by caller. }
    Send_Tunnel_ID: Cardinal; { Send tunnel IO ID. Set by caller. }
    UserData: Pointer; { User pointer. Set by caller. }
    UserObject: TCore_Object; { User object. Set by caller. }
    UserVariant: Variant; { User variant. Set by caller. }
    InData, OutData: SystemString; { Input and output strings. Set by caller. }
    OnDone_C: TOnHPC_Console_Done_C; { Done callback (C). Set by caller. }
    OnDone_M: TOnHPC_Console_Done_M; { Done callback (method). Set by caller. }
    OnDone_P: TOnHPC_Console_Done_P; { Done callback (nested). Set by caller. }
    property ID: Cardinal read WorkID;
    constructor Create;
    destructor Destroy; override;
    function IsOnline: Boolean;
    function IO: TPeerIO;
  end;

procedure RunHPC_ConsoleC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData, OutData: SystemString; const OnRun: TOnHPC_Console_C); overload;
procedure RunHPC_ConsoleC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData, OutData: SystemString; const OnRun: TOnHPC_Console_C); overload;
procedure RunHPC_ConsoleM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData, OutData: SystemString; const OnRun: TOnHPC_Console_M); overload;
procedure RunHPC_ConsoleM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData, OutData: SystemString; const OnRun: TOnHPC_Console_M); overload;
procedure RunHPC_ConsoleP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData, OutData: SystemString; const OnRun: TOnHPC_Console_P); overload;
procedure RunHPC_ConsoleP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData, OutData: SystemString; const OnRun: TOnHPC_Console_P); overload;
{$ENDREGION 'HPC Console Support'}
{$REGION 'HPC ConsoleNotify Support'}


type
  THPC_ConsoleNotify = class;
  TOnHPC_ConsoleNotify_C = procedure(thSender: THPC_ConsoleNotify; ThInData: SystemString);
  TOnHPC_ConsoleNotify_M = procedure(thSender: THPC_ConsoleNotify; ThInData: SystemString) of object;
{$IFDEF FPC}
  TOnHPC_ConsoleNotify_P = procedure(thSender: THPC_ConsoleNotify; ThInData: SystemString) is nested;
{$ELSE FPC}
  TOnHPC_ConsoleNotify_P = reference to procedure(thSender: THPC_ConsoleNotify; ThInData: SystemString);
{$ENDIF FPC}

  {
    * THPC_ConsoleNotify: HPC task that executes a direct console command in a thread (no output).
    * @Field Thread: Worker thread. Set during execution.
    * @Field Framework: Parent framework. Set by caller.
    * @Field Cmd: Command name. Set by caller.
    * @Field TriggerTime: Creation timestamp. Set by constructor.
    * @Field WorkID: IO identifier. Set by caller.
    * @Field Send_Tunnel: Send tunnel framework. Set by caller.
    * @Field Send_Tunnel_ID: Send tunnel IO ID. Set by caller.
    * @Field UserData: User pointer. Set by caller.
    * @Field UserObject: User object. Set by caller.
    * @Field UserVariant: User variant. Set by caller.
    * @Field InData: Input string. Set by caller.
    * @Example:
    *   // In a console notify command handler:
    *   RunHPC_ConsoleNotifyM(Sender, MyData, MyObject, InData,
    *     procedure(thSender: THPC_ConsoleNotify; ThInData: string)
    *     begin
    *       // Process ThInData in a background thread
    *     end
    *   );
  }
  THPC_ConsoleNotify = class sealed(THPC_Base)
  protected
    On_C: TOnHPC_ConsoleNotify_C; { C-style execution callback. Set by caller. }
    On_M: TOnHPC_ConsoleNotify_M; { Method execution callback. Set by caller. }
    On_P: TOnHPC_ConsoleNotify_P; { Nested/reference execution callback. Set by caller. }
    procedure Run(Sender: TCompute);
  public
    Thread: TCompute; { Worker thread. Set during execution. }
    Framework: TZNet; { Parent framework. Set by caller. }
    Cmd: SystemString; { Command name. Set by caller. }
    TriggerTime: TTimeTick; { Creation timestamp. Set by constructor. }
    WorkID: Cardinal; { IO identifier. Set by caller. }
    Send_Tunnel: TZNet; { Send tunnel framework. Set by caller. }
    Send_Tunnel_ID: Cardinal; { Send tunnel IO ID. Set by caller. }
    UserData: Pointer; { User pointer. Set by caller. }
    UserObject: TCore_Object; { User object. Set by caller. }
    UserVariant: Variant; { User variant. Set by caller. }
    InData: SystemString; { Input string. Set by caller. }
    property ID: Cardinal read WorkID;
    constructor Create;
    destructor Destroy; override;
    function IsOnline: Boolean;
    function IO: TPeerIO;
  end;

procedure RunHPC_ConsoleNotifyC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: SystemString; const OnRun: TOnHPC_ConsoleNotify_C); overload;
procedure RunHPC_ConsoleNotifyC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: SystemString; const OnRun: TOnHPC_ConsoleNotify_C); overload;
procedure RunHPC_ConsoleNotifyM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: SystemString; const OnRun: TOnHPC_ConsoleNotify_M); overload;
procedure RunHPC_ConsoleNotifyM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: SystemString; const OnRun: TOnHPC_ConsoleNotify_M); overload;
procedure RunHPC_ConsoleNotifyP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: SystemString; const OnRun: TOnHPC_ConsoleNotify_P); overload;
procedure RunHPC_ConsoleNotifyP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: SystemString; const OnRun: TOnHPC_ConsoleNotify_P); overload;
{$ENDREGION 'HPC ConsoleNotify Support'}
{$REGION 'HPC CompleteBuffer Support'}


type
  THPC_CompleteBuffer = class;
  TOnHPC_CompleteBuffer_C = procedure(thSender: THPC_CompleteBuffer; ThInData: PByte; ThDataSize: NativeInt);
  TOnHPC_CompleteBuffer_M = procedure(thSender: THPC_CompleteBuffer; ThInData: PByte; ThDataSize: NativeInt) of object;
{$IFDEF FPC}
  TOnHPC_CompleteBuffer_P = procedure(thSender: THPC_CompleteBuffer; ThInData: PByte; ThDataSize: NativeInt) is nested;
{$ELSE FPC}
  TOnHPC_CompleteBuffer_P = reference to procedure(thSender: THPC_CompleteBuffer; ThInData: PByte; ThDataSize: NativeInt);
{$ENDIF FPC}

  {
    * THPC_CompleteBuffer: HPC task that processes a complete buffer in a thread.
    * The input is a raw memory block. The task runs in a thread pool.
    * @Field Thread: Worker thread. Set during execution.
    * @Field Framework: Parent framework. Set by caller.
    * @Field Cmd: Command name. Set by caller.
    * @Field TriggerTime: Creation timestamp. Set by constructor.
    * @Field WorkID: IO identifier. Set by caller.
    * @Field Send_Tunnel: Send tunnel framework. Set by caller.
    * @Field Send_Tunnel_ID: Send tunnel IO ID. Set by caller.
    * @Field UserData: User pointer. Set by caller.
    * @Field UserObject: User object. Set by caller.
    * @Field UserVariant: User variant. Set by caller.
    * @Field InData: Input buffer. Set by caller.
    * @Example:
    *   // In a complete buffer command handler:
    *   RunHPC_CompleteBufferM(Sender, MyData, MyObject, InData, DataSize,
    *     procedure(thSender: THPC_CompleteBuffer; ThInData: PByte; ThDataSize: NativeInt)
    *     begin
    *       // Process ThInData in a background thread
    *     end
    *   );
  }
  THPC_CompleteBuffer = class sealed(THPC_Base)
  protected
    On_C: TOnHPC_CompleteBuffer_C; { C-style execution callback. Set by caller. }
    On_M: TOnHPC_CompleteBuffer_M; { Method execution callback. Set by caller. }
    On_P: TOnHPC_CompleteBuffer_P; { Nested/reference execution callback. Set by caller. }
    procedure Run(Sender: TCompute);
  public
    Thread: TCompute; { Worker thread. Set during execution. }
    Framework: TZNet; { Parent framework. Set by caller. }
    Cmd: SystemString; { Command name. Set by caller. }
    TriggerTime: TTimeTick; { Creation timestamp. Set by constructor. }
    WorkID: Cardinal; { IO identifier. Set by caller. }
    Send_Tunnel: TZNet; { Send tunnel framework. Set by caller. }
    Send_Tunnel_ID: Cardinal; { Send tunnel IO ID. Set by caller. }
    UserData: Pointer; { User pointer. Set by caller. }
    UserObject: TCore_Object; { User object. Set by caller. }
    UserVariant: Variant; { User variant. Set by caller. }
    InData: TMS64; { Input buffer. Set by caller. }
    property ID: Cardinal read WorkID;
    constructor Create;
    destructor Destroy; override;
    function IsOnline: Boolean;
    function IO: TPeerIO;
  end;

procedure RunHPC_CompleteBufferC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: PByte; const DataSize: NativeInt; const OnRun: TOnHPC_CompleteBuffer_C); overload;
procedure RunHPC_CompleteBufferC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: PByte; const DataSize: NativeInt; const OnRun: TOnHPC_CompleteBuffer_C); overload;
procedure RunHPC_CompleteBufferM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: PByte; const DataSize: NativeInt; const OnRun: TOnHPC_CompleteBuffer_M); overload;
procedure RunHPC_CompleteBufferM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: PByte; const DataSize: NativeInt; const OnRun: TOnHPC_CompleteBuffer_M); overload;
procedure RunHPC_CompleteBufferP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: PByte; const DataSize: NativeInt; const OnRun: TOnHPC_CompleteBuffer_P); overload;
procedure RunHPC_CompleteBufferP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: PByte; const DataSize: NativeInt; const OnRun: TOnHPC_CompleteBuffer_P); overload;
{$ENDREGION 'HPC CompleteBuffer Support'}
{$REGION 'HPC CompleteBuffer_Stream Support'}


type
  THPC_CompleteBuffer_Stream = class;
  TOnHPC_CompleteBuffer_Stream_C = procedure(thSender: THPC_CompleteBuffer_Stream; ThInData, ThOutData: TDFE);
  TOnHPC_CompleteBuffer_Stream_M = procedure(thSender: THPC_CompleteBuffer_Stream; ThInData, ThOutData: TDFE) of object;
{$IFDEF FPC}
  TOnHPC_CompleteBuffer_Stream_P = procedure(thSender: THPC_CompleteBuffer_Stream; ThInData, ThOutData: TDFE) is nested;
{$ELSE FPC}
  TOnHPC_CompleteBuffer_Stream_P = reference to procedure(thSender: THPC_CompleteBuffer_Stream; ThInData, ThOutData: TDFE);
{$ENDIF FPC}

  {
    * THPC_CompleteBuffer_Stream: HPC task that processes a complete-buffer
    * stream command in a thread. Uses the no-wait bridge for asynchronous
    * response delivery.
    * @Field Thread: Worker thread. Set during execution.
    * @Field Bridge: Associated bridge. Set by caller.
    * @Field Framework: Parent framework. Set by caller.
    * @Field Cmd: Command name. Set by caller.
    * @Field TriggerTime: Creation timestamp. Set by constructor.
    * @Field WorkID: IO identifier. Set by caller.
    * @Field Send_Tunnel: Send tunnel framework. Set by caller.
    * @Field Send_Tunnel_ID: Send tunnel IO ID. Set by caller.
    * @Field UserData: User pointer. Set by caller.
    * @Field UserObject: User object. Set by caller.
    * @Field UserVariant: User variant. Set by caller.
    * @Field InData, OutData: Input and output data. Set by caller.
    * @Example:
    *   // In a complete buffer bridge command handler:
    *   RunHPC_CompleteBuffer_StreamM(Bridge, MyData, MyObject, InData, OutData,
    *     procedure(thSender: THPC_CompleteBuffer_Stream; ThInData, ThOutData: TDFE)
    *     begin
    *       // Process ThInData in a background thread
    *       ThOutData.WriteString('processed');
    *     end
    *   );
  }
  THPC_CompleteBuffer_Stream = class sealed(THPC_Base)
  protected
    On_C: TOnHPC_CompleteBuffer_Stream_C; { C-style execution callback. Set by caller. }
    On_M: TOnHPC_CompleteBuffer_Stream_M; { Method execution callback. Set by caller. }
    On_P: TOnHPC_CompleteBuffer_Stream_P; { Nested/reference execution callback. Set by caller. }
    procedure Run(Sender: TCompute);
  public
    Thread: TCompute; { Worker thread. Set during execution. }
    Bridge: TCommandCompleteBuffer_NoWait_Bridge; { Associated bridge. Set by caller. }
    Framework: TZNet; { Parent framework. Set by caller. }
    Cmd: SystemString; { Command name. Set by caller. }
    TriggerTime: TTimeTick; { Creation timestamp. Set by constructor. }
    WorkID: Cardinal; { IO identifier. Set by caller. }
    Send_Tunnel: TZNet; { Send tunnel framework. Set by caller. }
    Send_Tunnel_ID: Cardinal; { Send tunnel IO ID. Set by caller. }
    UserData: Pointer; { User pointer. Set by caller. }
    UserObject: TCore_Object; { User object. Set by caller. }
    UserVariant: Variant; { User variant. Set by caller. }
    InData, OutData: TDFE; { Input and output data. Set by caller. }
    property ID: Cardinal read WorkID;
    constructor Create;
    destructor Destroy; override;
    function IsOnline: Boolean;
    function IO: TPeerIO;
  end;

procedure RunHPC_CompleteBuffer_StreamC(Sender: TCommandCompleteBuffer_NoWait_Bridge;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData, OutData: TDFE; const OnRun: TOnHPC_CompleteBuffer_Stream_C); overload;
procedure RunHPC_CompleteBuffer_StreamC(Sender: TCommandCompleteBuffer_NoWait_Bridge;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData, OutData: TDFE; const OnRun: TOnHPC_CompleteBuffer_Stream_C); overload;
procedure RunHPC_CompleteBuffer_StreamM(Sender: TCommandCompleteBuffer_NoWait_Bridge;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData, OutData: TDFE; const OnRun: TOnHPC_CompleteBuffer_Stream_M); overload;
procedure RunHPC_CompleteBuffer_StreamM(Sender: TCommandCompleteBuffer_NoWait_Bridge;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData, OutData: TDFE; const OnRun: TOnHPC_CompleteBuffer_Stream_M); overload;
procedure RunHPC_CompleteBuffer_StreamP(Sender: TCommandCompleteBuffer_NoWait_Bridge;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData, OutData: TDFE; const OnRun: TOnHPC_CompleteBuffer_Stream_P); overload;
procedure RunHPC_CompleteBuffer_StreamP(Sender: TCommandCompleteBuffer_NoWait_Bridge;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData, OutData: TDFE; const OnRun: TOnHPC_CompleteBuffer_Stream_P); overload;
{$ENDREGION 'HPC CompleteBuffer_Stream Support'}
{$REGION 'api'}

procedure DisposeQueueData(const v: PQueueData); { Utility procedures for queue data lifecycle. }
procedure InitQueueData(var v: TQueueData);
function NewQueueData(IO: TPeerIO): PQueueData;
function IsSystemCMD(const Cmd: U_String): Boolean; { Check if a command is an internal system command. }
function StrToIPv4(const S: U_String; var Success: Boolean): TIPV4; { IPv4/IPv6 conversion utilities. }
function IPv4ToStr(const IPv4Addr_: TIPV4): U_String;
function StrToIPv6(const S: U_String; var Success: Boolean; var ScopeID: Cardinal): TIPV6; overload;
function StrToIPv6(const S: U_String; var Success: Boolean): TIPV6; overload;
function IPv6ToStr(const IPv6Addr: TIPV6): U_String;
function IsIPv4(const S: U_String): Boolean;
function IsIPV6(const S: U_String): Boolean;
function MakeRandomIPV6(): TIPV6;
function Null_UID(): TUID___;
function Is_Null_UID(UID: TUID___): Boolean;
function Generate_Global_UID(): TUID___; overload;
function Generate_Global_UID(UID: TUID___): TUID___; overload;
function Generate_Global_UID(UID1, UID2: TUID___): TUID___; overload;
function Generate_Global_UID(UID1, UID2, UID3: TUID___): TUID___; overload;
function Generate_Global_UID(UID1, UID2, UID3, UID4: TUID___): TUID___; overload;
function Generate_Global_UID(buff: TBytes): TUID___; overload;
function IsLocalNetworkIPV4(const S: U_String): Boolean;
function IsLoopbackIPV4(const S: U_String): Boolean;
function IsLoopbackIPV6(const S: U_String): Boolean;
function CompareIPV4(const IP1, IP2: TIPV4): Boolean;
function CompareIPV6(const IP1, IP2: TIPV6): Boolean;
function TranslateBindAddr(addr: SystemString): SystemString; { Host address parsing. }
procedure ExtractHostAddress(var Host: U_String; var Port: Word); overload;
procedure ExtractHostAddress(var Host, Port: U_String); overload;
function Build_Host_URL(Host, Port: SystemString): SystemString; overload;
function Build_Host_URL(Host: SystemString; Port: Word): SystemString; overload;
function Get_Link_OK_Send_Tunnel(IO_: TPeerIO; var Send_Tunnel: TZNet; var Send_Tunnel_ID: Cardinal): Boolean; overload; { Double-tunnel helper functions. }
function Get_Link_OK_Send_Tunnel(Framework_: TZNet; ID_: Cardinal; var Send_Tunnel: TZNet; var Send_Tunnel_ID: Cardinal): Boolean; overload;
function Get_Link_OK_Recv_Tunnel(IO_: TPeerIO; var Recv_Tunnel: TZNet; var Recv_Tunnel_ID: Cardinal): Boolean; overload;
function Get_Link_OK_Recv_Tunnel(Framework_: TZNet; ID_: Cardinal; var Recv_Tunnel: TZNet; var Recv_Tunnel_ID: Cardinal): Boolean; overload;
procedure DoExecuteResult(IO: TPeerIO; const QueuePtr: PQueueData; const Result_Text: SystemString; Result_DF: TDFE); { Execute a result callback. }
procedure Set_Instance_QuietMode(Inst: TZNet; QuietMode_: Boolean); { Set quiet mode for an entire instance (including clones). }
{$ENDREGION 'api'}
{$REGION 'ConstAndVariant'}


{
  ===========================================================================
  Global variables and constants - define protocol tokens, default sizes,
  and global state for the Z.Net communication framework.
  ===========================================================================
}
var
  {
    * ZNet_UID
    * ---------------------------------------------------------------------------
    * Global, thread-safe (atomic) 256-bit UID for the Z.Net framework.
    *
    * Type:
    *   TAtomUID___ = TAtomVar<TUID___>
    *   TUID___     = TSHA3_256_Digest
    *
    * Purpose:
    *   Holds the current global unique identifier used during the ZServer
    *   handshake / cipher-model exchange. The client sends
    *   Generate_Global_UID(ZNet_UID.V) to the server; the server derives a new
    *   UID and returns it; the client then updates ZNet_UID.V with
    *   Generate_Global_UID(ServerState.UID). This binds connection initialization
    *   to a synchronizable, globally unique identity.
    *
    * Access:
    *   Thread-safe via TAtomVar. Read/write through ZNet_UID.V.
    *   Initialized with Null_UID() at unit initialization.
  }
  ZNet_UID: TAtomUID___;
  {
    * ZNet_Instance_Pool: Global pool that tracks every TZNet instance.
    * Each instance registers itself upon construction and unregisters on destruction.
    * Used primarily for debugging, monitoring, and global operations such as
    * broadcasting progress or collecting statistics across all active frameworks.
    * Scenarios: server admin tools, status dashboards, forced shutdown cleanup,
    * and cross-instance event coordination.
  }
  ZNet_Instance_Pool: TZNet_Instance_Pool;
  {
    * HPC_Instance_Pool: Global pool of all active HPC task objects.
    * Each background thread task registers itself here to allow lifecycle tracking,
    * enumeration, and safe termination. Useful for debugging thread pools,
    * monitoring task completion, and ensuring all tasks are properly freed
    * when the application shuts down.
  }
  HPC_Instance_Pool: THPC_Instance_Pool;
  {
    * ZNet_Def_Sequence_Packet_HeadSize: Fixed size of the header for a sequence packet.
    * Excludes the type byte. Used when parsing or constructing sequence packets.
    * Value: $16 (22 decimal).
  }
  ZNet_Def_Sequence_Packet_HeadSize: Byte = $16;
  {
    * ZNet_Def_Sequence_QuietPacket: Token for a sequence packet sent without expecting acknowledgment.
    * Used when the reliable feature is disabled temporarily.
    * Value: $01.
  }
  ZNet_Def_Sequence_QuietPacket: Byte = $01;
  {
    * ZNet_Def_Sequence_Packet: Token for a normal sequence packet that carries data and requires acknowledgment.
    * The receiver will send back an echo packet when this is processed.
    * Value: $02.
  }
  ZNet_Def_Sequence_Packet: Byte = $02;
  {
    * ZNet_Def_Sequence_EchoPacket: Token for an acknowledgment packet sent by the receiver.
    * The sender uses it to discard the corresponding packet from its resend history.
    * Value: $03.
  }
  ZNet_Def_Sequence_EchoPacket: Byte = $03;
  {
    * ZNet_Def_Sequence_KeepAlive: Token for a keep-alive packet sent periodically to test connection liveliness.
    * The receiver replies with ZNet_Def_Sequence_EchoKeepAlive.
    * Value: $04.
  }
  ZNet_Def_Sequence_KeepAlive: Byte = $04;
  {
    * ZNet_Def_Sequence_EchoKeepAlive: Token for the reply to a keep-alive packet.
    * Indicates that the peer is still responsive and that the connection is healthy.
    * Value: $05.
  }
  ZNet_Def_Sequence_EchoKeepAlive: Byte = $05;
  {
    * ZNet_Def_Sequence_RequestResend: Token for a request to resend a specific sequence packet.
    * Sent when the receiver detects a gap in the expected sequence numbers.
    * Value: $06.
  }
  ZNet_Def_Sequence_RequestResend: Byte = $06;
  {
    * ZNet_Def_p2pVM_echoing: Token for a P2PVM echo request frame.
    * The sender requests a round-trip time measurement; the receiver must reply with ZNet_Def_p2pVM_echo.
    * Value: $01.
  }
  ZNet_Def_p2pVM_echoing: Byte = $01;
  {
    * ZNet_Def_p2pVM_echo: Token for a P2PVM echo reply frame.
    * Sent in response to an echoing request to complete the latency measurement.
    * Value: $02.
  }
  ZNet_Def_p2pVM_echo: Byte = $02;
  {
    * ZNet_Def_p2pVM_AuthSuccessed: Token for a frame that indicates successful authentication.
    * Once this is sent/received, the virtual network is considered established and ready for data exchange.
    * Value: $09.
  }
  ZNet_Def_p2pVM_AuthSuccessed: Byte = $09;
  {
    * ZNet_Def_p2pVM_Listen: Token for a frame that announces a listening endpoint on a P2PVM node.
    * Used to publish services so that other peers can connect virtually.
    * Value: $10.
  }
  ZNet_Def_p2pVM_Listen: Byte = $10;
  {
    * ZNet_Def_p2pVM_ListenState: Token for a frame that updates the status of a previously announced listener.
    * Allows peers to know when a service becomes available or unavailable.
    * Value: $11.
  }
  ZNet_Def_p2pVM_ListenState: Byte = $11;
  {
    * ZNet_Def_p2pVM_Connecting: Token for a connection request frame sent by a client.
    * Initiates a virtual connection to a remote listening endpoint.
    * Value: $20.
  }
  ZNet_Def_p2pVM_Connecting: Byte = $20;
  {
    * ZNet_Def_p2pVM_ConnectedReponse: Token for a connection response frame sent by the server.
    * Accepts or rejects a virtual connection request and contains the assigned virtual IDs.
    * Value: $21.
  }
  ZNet_Def_p2pVM_ConnectedReponse: Byte = $21;
  {
    * ZNet_Def_p2pVM_Disconnect: Token for a frame that gracefully closes a virtual connection.
    * Both peers can send this to terminate the virtual channel.
    * Value: $40.
  }
  ZNet_Def_p2pVM_Disconnect: Byte = $40;
  {
    * ZNet_Def_p2pVM_LogicFragmentData: Token for a data frame that carries application-level payload over the virtual network.
    * The primary data carrier for logical channels.
    * Value: $54.
  }
  ZNet_Def_p2pVM_LogicFragmentData: Byte = $54;
  {
    * ZNet_Def_p2pVM_OwnerIOFragmentData: Token for a data frame that carries raw physical-layer data forwarded through the P2PVM tunnel.
    * Used when the virtual network is layered on top of an existing connection.
    * Value: $64.
  }
  ZNet_Def_p2pVM_OwnerIOFragmentData: Byte = $64;
  {
    * ZNet_Def_DefaultConsoleToken: Token for a console command that expects a response.
    * Value: $F1.
  }
  ZNet_Def_DefaultConsoleToken: Byte = $F1;
  {
    * ZNet_Def_DefaultStreamToken: Token for a stream command that expects a response.
    * Value: $2F.
  }
  ZNet_Def_DefaultStreamToken: Byte = $2F;
  {
    * ZNet_Def_DefaultConsoleNotifyToken: Token for a console command that does NOT expect a response.
    * Fire-and-forget console command.
    * Value: $F3.
  }
  ZNet_Def_DefaultConsoleNotifyToken: Byte = $F3;
  {
    * ZNet_Def_DefaultStreamNotifyToken: Token for a stream command that does NOT expect a response.
    * Fire-and-forget stream command.
    * Value: $4F.
  }
  ZNet_Def_DefaultStreamNotifyToken: Byte = $4F;
  {
    * ZNet_Def_DefaultBigStreamToken: Token for a big-stream command.
    * Initiates the transfer of a large data block.
    * Value: $F5.
  }
  ZNet_Def_DefaultBigStreamToken: Byte = $F5;
  {
    * ZNet_Def_DefaultBigStreamReceiveFragmentSignal: Token for a signal sent by the receiver to request the next fragment.
    * Used for flow control during big-stream transfers.
    * Value: $F6.
  }
  ZNet_Def_DefaultBigStreamReceiveFragmentSignal: Byte = $F6;
  {
    * ZNet_Def_DefaultBigStreamReceiveDoneSignal: Token for a signal indicating the entire big-stream has been received.
    * Value: $F7.
  }
  ZNet_Def_DefaultBigStreamReceiveDoneSignal: Byte = $F7;
  {
    * ZNet_Def_DefaultCompleteBufferToken: Token for a complete-buffer command.
    * Used for small-to-medium sized transfers that must be processed as a whole.
    * Value: $6F.
  }
  ZNet_Def_DefaultCompleteBufferToken: Byte = $6F;
  {
    * ZNet_Def_DataHeadToken: Fixed 4-byte marker at the start of every command packet.
    * If this value is not found, the packet is considered corrupt and the connection is closed.
    * Value: $F0F0F0F0.
  }
  ZNet_Def_DataHeadToken: Cardinal = $F0F0F0F0;
  {
    * ZNet_Def_DataTailToken: Fixed 4-byte marker at the end of every command packet.
    * Verifies that the packet was fully received and not truncated.
    * Value: $F1F1F1F1.
  }
  ZNet_Def_DataTailToken: Cardinal = $F1F1F1F1;
  {
    * ZNet_Progress_Max_Delay: Maximum time the large-scale IO progress loop may spend processing a single batch.
    * Prevents the main loop from blocking too long when many connections are active.
    * Default: 1000 ms.
  }
  ZNet_Progress_Max_Delay: TTimeTick = 1000;
  {
    * ZNet_Def_SendFlushSize: Size of each chunk when flushing the send buffer.
    * Larger values may improve throughput but increase latency.
    * Default: 32 KB.
  }
  ZNet_Def_SendFlushSize: NativeInt = 32 * 1024;
  {
    * ZNet_Def_Extract_Physics_Fragment_Max_Size: Maximum total bytes extracted from the physical fragment pool per cycle.
    * Limits CPU usage during heavy receive bursts.
    * Default: 1 MB.
  }
  ZNet_Def_Extract_Physics_Fragment_Max_Size: Int64 = 1024 * 1024;
  {
    * ZNet_Def_Per_Progress_Loop_Limit: Maximum number of commands processed in one Progress() call for a given IO.
    * Prevents the loop from starving other IOs or the UI.
    * Default: 500.
  }
  ZNet_Def_Per_Progress_Loop_Limit: Integer = 500;
  {
    * ZNet_Def_MaxCompleteBufferSize: Maximum allowed size for a complete-buffer command.
    * If a received buffer exceeds this limit, the connection is closed to prevent memory exhaustion.
    * Default: 64 MB.
  }
  ZNet_Def_MaxCompleteBufferSize: Cardinal = 64 * 1024 * 1024;
  {
    * ZNet_Def_CompleteBufferCompressionCondition: Minimum buffer size for compression.
    * Smaller buffers are sent uncompressed to avoid overhead.
    * Default: 1024 bytes.
  }
  ZNet_Def_CompleteBufferCompressionCondition: Cardinal = 1024;
  {
    * ZNet_Def_CompleteBuffer_SwapSpace_Activted: Whether complete-buffer data may be swapped to disk when busy or large.
    * Reduces memory pressure.
    * Default: False.
  }
  ZNet_Def_CompleteBuffer_SwapSpace_Activted: Boolean = False;
  {
    * ZNet_Def_CompleteBuffer_SwapSpace_Trigger: Minimum buffer size that triggers swapping to disk.
    * Only effective if swap space is activated.
    * Default: 1024 bytes.
  }
  ZNet_Def_CompleteBuffer_SwapSpace_Trigger: Int64 = 1024;
  {
    * ZNet_Def_SequencePacketMTU: Maximum Transmission Unit for sequence packets.
    * Maximum payload size of each individual packet fragment.
    * Default: 1536 bytes.
  }
  ZNet_Def_SequencePacketMTU: Word = 1536;
  {
    * ZNet_Def_P2PVM_MaxVMFragmentSize: Maximum payload size for a single P2PVM fragment packet.
    * Default: 1536 bytes.
  }
  ZNet_Def_P2PVM_MaxVMFragmentSize: Cardinal = 1536;
  {
    * ZNet_Def_P2PVM_Progress_Send_Size: Maximum total bytes sent in one Progress() cycle for P2PVM.
    * Default: 500 KB.
  }
  ZNet_Def_P2PVM_Progress_Send_Size: Int64 = 500 * 1024;
  {
    * ZNet_Def_DoStatusID: Identifier used when printing debug status messages via DoStatus().
    * Helps filter or route log messages.
    * Default: $0FFFFFFF.
  }
  ZNet_Def_DoStatusID: Integer = $0FFFFFFF;
  {
    * ZNet_Def_VMAuthSize: Number of random 32-bit integers used to build the P2PVM authentication token.
    * Larger values increase security but also increase handshake size.
    * Default: 16 (64 bytes total).
  }
  ZNet_Def_VMAuthSize: Integer = 16;
  {
    * ZNet_Def_BigStream_ChunkSize: Size of each data chunk when sending a big-stream.
    * Default: 1 MB.
  }
  ZNet_Def_BigStream_ChunkSize: NativeInt = 1024 * 1024;
  {
    * ZNet_Def_BigStream_Memory_SwapSpace_Activted: Whether big-stream data may be swapped to disk for large streams.
    * Default: False.
  }
  ZNet_Def_BigStream_Memory_SwapSpace_Activted: Boolean = False;
  {
    * ZNet_Def_BigStream_SwapSpace_Trigger: Minimum size of a big-stream that triggers swapping to disk.
    * Only effective if swap space is activated.
    * Default: 1 MB.
  }
  ZNet_Def_BigStream_SwapSpace_Trigger: Int64 = 1024 * 1024;
  {
    * ZNet_Def_Physics_Fragment_Cache_Activted: Whether received physical fragments are cached before processing.
    * Helps smooth burst traffic.
    * Default: False.
  }
  ZNet_Def_Physics_Fragment_Cache_Activted: Boolean = False;
  {
    * ZNet_Def_Physics_Fragment_Cache_Trigger: Maximum number of fragments kept in the in-memory pool before swapping.
    * Default: 10000.
  }
  ZNet_Def_Physics_Fragment_Cache_Trigger: NativeInt = 10000;
  {
    * ZNet_Def_Swap_Space_Technology_Security_Model: Whether the ZDB2 swap space should be encrypted.
    * Enabling adds security but reduces performance.
    * Default: False.
  }
  ZNet_Def_Swap_Space_Technology_Security_Model: Boolean = False;
  {
    * ZNet_Def_Swap_Space_Technology_Delta: Space to add to the ZDB2 swap database when it runs out of free space.
    * Default: 64 MB.
  }
  ZNet_Def_Swap_Space_Technology_Delta: Int64 = 64 * 1024 * 1024;
  {
    * ZNet_Def_Swap_Space_Technology_Block: Block size used when expanding the ZDB2 swap database.
    * Value $FFFF means the database uses the maximum possible block size (65535).
    * Default: $FFFF.
  }
  ZNet_Def_Swap_Space_Technology_Block: Word = $FFFF;
  {
    * ZNet_Def_IPV6_Seed: Monotonically increasing seed used when generating random IPv6 addresses.
    * Ensures each generated address is unique across the process.
    * Default: 0.
  }
  ZNet_Def_IPV6_Seed: UInt64 = 0;
  {
    * ZNet_Global_UID_Seed__: Monotonically increasing seed used when generating globally unique identifiers (UIDs).
    * Each global UID generation increments this seed, ensuring process-wide uniqueness.
    * Default: 0.
  }
  ZNet_Global_UID_Seed: Int64 = 0;
  {
    * ProgressBackgroundProc: Global procedure called every progress cycle.
    * Use for lightweight background tasks that should run alongside the network engine.
    * Default: nil (disabled).
  }
  ProgressBackgroundProc: TOnProgressBackground_C = nil;
  {
    * ProgressBackgroundMethod: Global method called every progress cycle.
    * Allows stateful object methods for background tasks.
    * Default: nil (disabled).
  }
  ProgressBackgroundMethod: TOnProgressBackground_M = nil;

const
  { Internal system command names. }
  C_CipherModel: SystemString = '__@CipherModel';
  C_Wait: SystemString = '__@Wait';
  C_BuildP2PAuthToken: SystemString = '__@BuildP2PAuthToken';
  C_InitP2PTunnel: SystemString = '__@InitP2PTunnel';
  C_CloseP2PTunnel: SystemString = '__@CloseP2PTunnel';
  C_NULL: SystemString = '__@NULL';
  C_Complete_Buffer_Stream_Reponse: SystemString = '__@Complete_Buffer_Stream_Reponse';
  C_BuildStableIO: SystemString = '__@BuildStableIO';
  C_OpenStableIO: SystemString = '__@OpenStableIO';
  C_CloseStableIO: SystemString = '__@CloseStableIO';

  { Double-tunnel / data store command names. }
  C_FileInfo: SystemString = '__@FileInfo';
  C_PostFile: SystemString = '__@PostFile';
  C_PostFileOver: SystemString = '__@PostFileOver';
  C_PostBatchStreamDone: SystemString = '__@PostBatchStreamDone';
  C_UserDB: SystemString = 'UserDB';
  C_UserLogin: SystemString = '__@UserLogin';
  C_RegisterUser: SystemString = '__@RegisterUser';
  C_TunnelLink: SystemString = '__@TunnelLink';
  C_ChangePasswd: SystemString = '__@ChangePasswd';
  C_CustomNewUser: SystemString = '__@CustomNewUser';
  C_ProcessStoreQueueCMD: SystemString = '__@ProcessStoreQueueCMD';
  C_GetPublicFileList: SystemString = '__@GetPublicFileList';
  C_GetPrivateFileList: SystemString = '__@GetPrivateFileList';
  C_GetPrivateDirectoryList: SystemString = '__@GetPrivateDirectoryList';
  C_CreatePrivateDirectory: SystemString = '__@CreatePrivateDirectory';
  C_GetPublicFileInfo: SystemString = '__@GetPublicFileInfo';
  C_GetPrivateFileInfo: SystemString = '__@GetPrivateFileInfo';
  C_GetPublicFileMD5: SystemString = '__@GetPublicFileMD5';
  C_GetPrivateFileMD5: SystemString = '__@GetPrivateFileMD5';
  C_GetPublicFile: SystemString = '__@GetPublicFile';
  C_GetPrivateFile: SystemString = '__@GetPrivateFile';
  C_GetUserPrivateFile: SystemString = '__@GetUserPrivateFile';
  C_GetPublicFileAs: SystemString = '__@GetPublicFileAs';
  C_GetPrivateFileAs: SystemString = '__@GetPrivateFileAs';
  C_GetUserPrivateFileAs: SystemString = '__@GetUserPrivateFileAs';
  C_PostPublicFileInfo: SystemString = '__@PostPublicFileInfo';
  C_PostPrivateFileInfo: SystemString = '__@PostPrivateFileInfo';
  C_GetCurrentCadencer: SystemString = '__@GetCurrentCadencer';
  C_NewBatchStream: SystemString = '__@NewBatchStream';
  C_PostBatchStream: SystemString = '__@PostBatchStream';
  C_ClearBatchStream: SystemString = '__@ClearBatchStream';
  C_GetBatchStreamState: SystemString = '__@GetBatchStreamState';
  C_GetUserPrivateFileList: SystemString = '__@GetUserPrivateFileList';
  C_GetUserPrivateDirectoryList: SystemString = '__@GetUserPrivateDirectoryList';
  C_GetFileTime: SystemString = '__@GetFileTime';
  C_GetFileInfo: SystemString = '__@GetFileInfo';
  C_GetFileMD5: SystemString = '__@GetFileMD5';
  C_GetFile: SystemString = '__@GetFile';
  C_GetFileAs: SystemString = '__@GetFileAs';
  C_PostFileInfo: SystemString = '__@PostFileInfo';
  C_GetPublicFileFragmentData: SystemString = '__@GetPublicFileFragmentData';
  C_GetPrivateFileFragmentData: SystemString = '__@GetPrivateFileFragmentData';
  C_GetFileFragmentData: SystemString = '__@GetFileFragmentData';
  C_PostFileFragmentData: SystemString = '__@PostFileFragmentData';

  { Data store commands. }
  C_DataStoreSecurity: SystemString = '__@DataStoreSecurity';
  C_CompletedFragmentBigStream: SystemString = '__@CompletedFragmentBigStream';
  C_CompletedQuery: SystemString = '__@CompletedQuery';
  C_CompletedDownloadAssemble: SystemString = '__@CompletedDownloadAssemble';
  C_CompletedFastDownloadAssemble: SystemString = '__@CompletedFastDownloadAssemble';
  C_CompletedStorePosTransform: SystemString = '__@CompletedStorePosTransform';
  C_InitDB: SystemString = '__@InitDB';
  C_CloseDB: SystemString = '__@CloseDB';
  C_CopyDB: SystemString = '__@CopyDB';
  C_CompressDB: SystemString = '__@CompressDB';
  C_ReplaceDB: SystemString = '__@ReplaceDB';
  C_ResetData: SystemString = '__@ResetData';
  C_QueryDB: SystemString = '__@QueryDB';
  C_DownloadDB: SystemString = '__@DownloadDB';
  C_DownloadDBWithID: SystemString = '__@DownloadDBWithID';
  C_RequestDownloadAssembleStream: SystemString = '__@RequestDownloadAssembleStream';
  C_RequestFastDownloadAssembleStrea: SystemString = '__@RequestFastDownloadAssembleStream';
  C_FastPostCompleteBuffer: SystemString = '__@FastPostCompleteBuffer';
  C_FastInsertCompleteBuffer: SystemString = '__@FastInsertCompleteBuffer';
  C_FastModifyCompleteBuffer: SystemString = '__@FastModifyCompleteBuffer';
  C_CompletedPostAssembleStream: SystemString = '__@CompletedPostAssembleStream';
  C_CompletedInsertAssembleStream: SystemString = '__@CompletedInsertAssembleStream';
  C_CompletedModifyAssembleStream: SystemString = '__@CompletedModifyAssembleStream';
  C_DeleteData: SystemString = '__@DeleteData';
  C_GetDBList: SystemString = '__@GetDBList';
  C_GetQueryList: SystemString = '__@GetQueryList';
  C_GetQueryState: SystemString = '__@GetQueryState';
  C_QueryStop: SystemString = '__@QueryStop';
  C_QueryPause: SystemString = '__@QueryPause';
  C_QueryPlay: SystemString = '__@QueryPlay';
{$ENDREGION 'ConstAndVariant'}

implementation

uses Z.Net.DoubleTunnelIO, Z.Net.DoubleTunnelIO.VirtualAuth, Z.Net.DoubleTunnelIO.NoAuth;

{ ============================================================================
  Implementation is split into the following include files.
  The order below MUST be preserved because free procedures/functions
  (not class methods) must be defined before their callers.
  ============================================================================ }

{$I Z.Net.imp_Init.inc}                      { Initialization globals + Init/Free routines }
{$I Z.Net.imp_API.inc}                       { Free functions: IP utils, host parsing, helpers }
{$I Z.Net.imp_Queue.inc}                     { TWaitSend*Intf + QueueData helpers }
{$I Z.Net.imp_BaseDecl.inc}                  { Bridge classes and TOnStateStruct }
{$I Z.Net.imp_CacheTechnology.inc}           { Swap space technology (file + ZDB2) }
{$I Z.Net.imp_CommandInstance.inc}           { TCommand_* command classes }
{$I Z.Net.imp_IOMisc.inc}                    { TBigStreamBatch / TPeer_IO_User_* / TPhysics_Fragment_Pool }
{$I Z.Net.imp_IO.inc}                        { TPeerIO implementation }
{$I Z.Net.imp_ZNet.inc}                      { TZNet implementation + hash pools }
{$I Z.Net.imp_ZNetServer.inc}                { TZNet_Server implementation }
{$I Z.Net.imp_ZNetClient.inc}                { TZNet_Client implementation }
{$I Z.Net.imp_P2pVM_IO.inc}                  { TP2PVM_PeerIO + fragment packet }
{$I Z.Net.imp_P2pVM_Server.inc}              { TZNet_WithP2PVM_Server }
{$I Z.Net.imp_P2pVM_Client.inc}              { TZNet_WithP2PVM_Client }
{$I Z.Net.imp_P2pVM.inc}                     { TZNet_P2PVM core }
{$I Z.Net.imp_StableIO.inc}                  { StableIO (server/client + custom stable) }
{$I Z.Net.imp_HPC_Base.inc}                  { THPC_Base + THPC_Instance_Pool }
{$I Z.Net.imp_HPC_Stream.inc}                { THPC_Stream + RunHPC_Stream* }
{$I Z.Net.imp_HPC_StreamNotify.inc}          { THPC_StreamNotify + RunHPC_StreamNotify* }
{$I Z.Net.imp_HPC_Console.inc}               { THPC_Console + RunHPC_Console* }
{$I Z.Net.imp_HPC_ConsoleNotify.inc}         { THPC_ConsoleNotify + RunHPC_ConsoleNotify* }
{$I Z.Net.imp_HPC_CompleteBuffer.inc}        { THPC_CompleteBuffer + RunHPC_CompleteBuffer* }
{$I Z.Net.imp_HPC_CompleteBuffer_Stream.inc} { THPC_CompleteBuffer_Stream + RunHPC_CompleteBuffer_Stream* }

initialization

ProgressBackgroundProc := nil;
ProgressBackgroundMethod := nil;
HPC_Instance_Pool := THPC_Instance_Pool.Create;
ZNet_UID := TAtomUID___.Create(Null_UID());
Init_ZNet_Instance_Pool();
Init_SwapSpace_Tech();

finalization

DisposeObjectAndNil(HPC_Instance_Pool);
Free_SwapSpace_Tech();
Free_ZNet_Instance_Pool();
DisposeObject(ZNet_UID);

end.
 
