% luke: "is it possilbe to use lowercase names? 
% uppercase breaks the syntax highlighting in textmate"
-include("debug.hrl").
-include("rtmp.hrl").
-define(APPLICATION, erlmedia).

-define(MAX_RESTART,      5).
-define(MAX_TIME,        60).
-define(RTMP_PORT,     1935).
-define(TIMEOUT,     120000).
-define(PREPUSH, 3000).
-define(RTMP_WINDOW_SIZE, 2500000).
-define(RTMP_PREF_CHUNK_SIZE, (4*1024)).

-define(CONTENT_TYPE, "application/x-fcs").
-define(SERVER_HEADER, {"Server", "RTMPT/1.0"}).

-define(RTMPT_TIMEOUT, 12000).
-define(DEFAULT_FLV_DIR, "/tmp").






% AMF commands
-define(AMF_COMMAND_ONMETADATA, "onMetaData").
-define(AMF_COMMAND_ONCUEPOINT, "onCuePoint").


%% FLV tag
-define(FLV_TAG_TYPE_AUDIO, 8).
-define(FLV_TAG_TYPE_VIDEO, 9).
-define(FLV_TAG_TYPE_META,  18).

%% FLV audio
-define(FLV_AUDIO_TYPE_MONO,   0).
-define(FLV_AUDIO_TYPE_STEREO, 1).
-define(FLV_AUDIO_SIZE_8BIT,   0).
-define(FLV_AUDIO_SIZE_16BIT,  1).
-define(FLV_AUDIO_RATE_5_5, 0).
-define(FLV_AUDIO_RATE_11, 1).
-define(FLV_AUDIO_RATE_22, 2).
-define(FLV_AUDIO_RATE_44, 3).
-define(FLV_AUDIO_FORMAT_UNCOMPRESSED, 0).
-define(FLV_AUDIO_FORMAT_ADPCM,        1).
-define(FLV_AUDIO_FORMAT_MP3,          2).
-define(FLV_AUDIO_FORMAT_NELLYMOSER8,  5).
-define(FLV_AUDIO_FORMAT_NELLYMOSER,   6).
-define(FLV_AUDIO_FORMAT_A_G711,       7).
-define(FLV_AUDIO_FORMAT_MU_G711,      8).
-define(FLV_AUDIO_FORMAT_RESERVED,     9).
-define(FLV_AUDIO_FORMAT_AAC,          10).
-define(FLV_AUDIO_FORMAT_MP3_8KHZ,     14).
-define(FLV_AUDIO_FORMAT_DEVICE,       15).
-define(FLV_AUDIO_AAC_SEQUENCE_HEADER, 0).
-define(FLV_AUDIO_AAC_RAW,             1).

%% FLV video
-define(FLV_VIDEO_FRAME_TYPE_KEYFRAME,        1).
-define(FLV_VIDEO_FRAME_TYPEINTER_FRAME,      2).
-define(FLV_VIDEO_FRAME_TYPEDISP_INTER_FRAME, 3).
-define(FLV_VIDEO_FRAME_TYPE_GENERATED,       4).
-define(FLV_VIDEO_FRAME_TYPE_COMMAND,         5).

-define(FLV_VIDEO_CODEC_JPEG,                 1).
-define(FLV_VIDEO_CODEC_SORENSEN,             2).
-define(FLV_VIDEO_CODEC_SCREENVIDEO,          3).
-define(FLV_VIDEO_CODEC_ON2VP6,               4).
-define(FLV_VIDEO_CODEC_ON2VP6_ALPHA,         5).
-define(FLV_VIDEO_CODEC_SCREENVIDEO2,         6).
-define(FLV_VIDEO_CODEC_AVC,                  7).

-define(FLV_VIDEO_AVC_SEQUENCE_HEADER,        0).
-define(FLV_VIDEO_AVC_NALU,                   1).
-define(FLV_VIDEO_AVC_SEQUENCE_END,           2).

%% NetConnection Status
-define(NC_CALL_FAILED, "NetConnection.Call.Failed").
-define(NC_CALL_BAD_VERSION, "NetConnection.Call.BadVersion").
-define(NC_CONNECT_APP_SHUTDOWN, "NetConnection.Connect.AppShutdown").
-define(NC_CONNECT_CLOSED, "NetConnection.Connect.Closed").
-define(NC_CONNECT_FAILED, "NetConnection.Connect.Failed").
-define(NC_CONNECT_REJECTED, "NetConnection.Connect.Rejected").
-define(NC_CONNECT_SUCCESS, "NetConnection.Connect.Success").
-define(NC_CONNECT_INVALID_APP, "NetConnection.Connect.InvalidApp").

%% NetStream Status
-define(NS_INVALID_ARG, "NetStream.InvalidArg").
-define(NS_CLEAR_SUCCESS, "NetStream.Clear.Success").
-define(NS_CLEAR_FAILED, "NetStream.Clear.Failed").
-define(NS_PUBLISH_START, "NetStream.Publish.Start").
-define(NS_PUBLISH_BAD_NAME, "NetStream.Publish.BadName").
-define(NS_FAILED, "NetStream.Failed").
-define(NS_UNPUBLISHED_SUCCESS, "NetStream.Unpublish.Success").
-define(NS_RECORD_START, "NetStream.Record.Start").
-define(NS_RECORD_NO_ACCESS, "NetStream.Record.NoAccess").
-define(NS_RECORD_STOP, "NetStream.Record.Stop").
-define(NS_RECORD_FAILED, "NetStream.Record.Failed").
-define(NS_PLAY_INSUFFICIENT_BW, "NetStream.Play.InsufficientBW").
-define(NS_PLAY_START, "NetStream.Play.Start").
-define(NS_PLAY_STREAM_NOT_FOUND, "NetStream.Play.StreamNotFound").
-define(NS_PLAY_STOP, "NetStream.Play.Stop").
-define(NS_PLAY_FAILED, "NetStream.Play.Failed").
-define(NS_PLAY_RESET, "NetStream.Play.Reset").
-define(NS_PLAY_PUBLISH_NOTIFY, "NetStream.Play.PublishNotify").
-define(NS_PLAY_UNPUBLISH_NOTIFY, "NetStream.Play.UnpublishNotify").
-define(NS_PLAY_SWITCH, "NetStream.Play.Switch").
-define(NS_PLAY_COMPLETE, "NetStream.Play.Complete").
-define(NS_SEEK_NOTIFY, "NetStream.Seek.Notify").
-define(NS_SEEK_FAILED, "NetStream.Seek.Failed").
-define(NS_PAUSE_NOTIFY, "NetStream.Pause.Notify").
-define(NS_UNPAUSE_NOTIFY, "NetStream.Unpause.Notify").
-define(NS_DATA_START, "NetStream.Data.Start").

%% Application Status
-define(APP_SCRIPT_ERROR, "Application.Script.Error").
-define(APP_SCRIPT_WARNING, "Application.Script.Warning").
-define(APP_RESOURCE_LOW_MEMORY, "Application.Resource.LowMemory").
-define(APP_SHUTDOWN, "Application.Shutdown").
-define(APP_GC, "Application.GC").

%% Shared Object Status
-define(SO_NO_READ_ACCESS, "SharedObject.NoReadAccess").
-define(SO_NO_WRITE_ACCESS, "SharedObject.NoWriteAccess").
-define(SO_OBJECT_CREATION_FAILED, "SharedObject.ObjectCreationFailed").
-define(SO_BAD_PERSISTENCE, "SharedObject.BadPersistence").


-record(rtmp_session, {
  host,
  path,
	socket,    % client socket
	addr,      % client address
	port,
	session_id,
	user_id     = undefined,
	player_info = [],
	streams      = undefined
	}).

-record(file_frame, {
  id,
  timestamp,
  type,
  offset,
  size,
  keyframe
}).

-record(flv_header,{
	version = 1,
	audio = 0,
	video = 0
	}).
		
-record(video_frame,{
  decoder_config = false,
  raw_body       = false,
	type           = undefined,
	timestamp      = undefined,
	timestamp_ext  = undefined,
	stream_id      = 0,
	body           = <<>>,
	codec_id 	     = undefined,
	frame_type     = undefined,
	sound_type	   = undefined,
	sound_size	   = undefined,
	sound_rate	   = undefined,
	sound_format	 = undefined
	}).
	
