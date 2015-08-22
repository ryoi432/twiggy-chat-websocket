# twiggy-chat-websocket

[miyagawa/Twiggy](https://github.com/miyagawa/Twiggy) の chat-websocket を Plack::App::WebSocket に対応させたものです。

## How to use

```
$ git clone https://github.com/ryoi432/twiggy-chat-websocket.git
$ cd twiggy-chat-websocket
$ carton install
$ carton exec -- plackup -s Twiggy -a chat.psgi
```