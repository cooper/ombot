ombot
=====

Omegle IRC Bot in Perl

## Required Packages (obtainable through cpan)
+ IO::Async
+ IO::Async::Timer::Periodic
+ IO::Socket::IP
+ Config::JSON
+ URI
+ URI::Escape::XS

## Commands
### All commands can be executed either by using ! or . as a prefix
+ start / begin [\<common intersts (space separated)\>] - starts a new session
+ stop / end - ends current session
+ captcha / submit \<response\> - sends captcha response to omegle
+ send / say \<message\> - sends message to omegle stranger
+ asl [\<sex\>] - sends a random asl, if a parameter is given 's' is replaced with that
+ troll - sends the result of a http request to omegle/trollsrc

