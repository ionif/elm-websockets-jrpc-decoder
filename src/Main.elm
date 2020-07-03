port module Main exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as D
import WSDecoder exposing (responseDecoder, stringDecoder)

-- MAIN

main : Program () Model Msg
main =
  Browser.element
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

-- PORTS

port sendMessage : String -> Cmd msg
port messageReceiver : (String -> msg) -> Sub msg

-- MODEL

type alias Model =
  { draft : String
  , messages : List String
  }


init : () -> ( Model, Cmd Msg )
init flags =
  ( { draft = "", messages = [] }
  , Cmd.none
  )


-- UPDATE

type Msg
  = DraftChanged String
  | Send
  | PlayPause
  | Skip
  | Recv String


-- Use the `sendMessage` port when someone presses ENTER or clicks
-- the "Send" button. Check out index.html to see the corresponding
-- JS where this is piped into a WebSocket.
--
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    DraftChanged draft ->
      ( { model | draft = draft }
      , Cmd.none
      )

    Send ->
      ( { model | draft = "" }
      , sendMessage model.draft
      )

    PlayPause ->
      ( { model | draft = "" }
      , sendMessage """{ "jsonrpc": "2.0", "method": "Input.ExecuteAction", "params": { "action": "playpause" }, "id": 1 }"""
      )

    Skip ->
      ( { model | draft = "" }
      , sendMessage """{ "jsonrpc": "2.0", "method": "Input.ExecuteAction", "params": { "action": "skipnext" }, "id": 1 }"""
      )

    Recv message ->
      ( { model | messages = model.messages ++ [message] }
      , Cmd.none
      )


-- SUBSCRIPTIONS
decodeWS message = 
    case D.decodeString responseDecoder message of 
      Ok wsMessage -> 
          Recv wsMessage.result.data.item.itype
      Err err ->
          case D.decodeString stringDecoder message of 
            Ok wsMessage -> 
              Recv wsMessage
            Err err2 ->
              Recv "err2"

-- Subscribe to the `messageReceiver` port to hear about messages coming in
-- from JS. Check out the index.html file to see how this is hooked up to a
-- WebSocket.
--
subscriptions : Model -> Sub Msg
subscriptions _ =
  messageReceiver decodeWS



-- VIEW


view : Model -> Html Msg
view model =
  div []
    [ h1 [] [ text "Echo Chat" ]
    , ul []
        (List.map (\msg -> li [] [ text msg ]) model.messages)
    , input
        [ type_ "text"
        , placeholder "Draft"
        , onInput DraftChanged
        , on "keydown" (ifIsEnter Send)
        , value model.draft
        ]
        []
    , button [ onClick Send ] [ text "Send" ]
    , button [ onClick PlayPause ] [ text "Play/Pause" ]
    , button [ onClick Skip ] [ text "Skip" ]
    ]
    



-- DETECT ENTER


ifIsEnter : msg -> D.Decoder msg
ifIsEnter msg =
  D.field "key" D.string
    |> D.andThen (\key -> if key == "Enter" then D.succeed msg else D.fail "some other key")
