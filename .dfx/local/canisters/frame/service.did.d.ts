import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';

export interface CallbackStrategy {
  'token' : Token,
  'callback' : [Principal, string],
}
export type HeaderField = [string, string];
export interface HttpRequest {
  'url' : string,
  'method' : string,
  'body' : Uint8Array | number[],
  'headers' : Array<HeaderField>,
}
export interface HttpResponse {
  'body' : Uint8Array | number[],
  'headers' : Array<HeaderField>,
  'upgrade' : [] | [boolean],
  'streaming_strategy' : [] | [StreamingStrategy],
  'status_code' : number,
}
export interface StreamingCallbackHttpResponse {
  'token' : [] | [Token],
  'body' : Uint8Array | number[],
}
export type StreamingStrategy = { 'Callback' : CallbackStrategy };
export interface Token { 'arbitrary_data' : string }
export interface _SERVICE {
  'http_request' : ActorMethod<[HttpRequest], HttpResponse>,
  'http_request_update' : ActorMethod<[HttpRequest], HttpResponse>,
  'keys' : ActorMethod<[], Array<string>>,
}
