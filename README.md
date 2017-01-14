ombot
=====

Omegle IRC Bot in Perl

## Required Packages (obtainable through cpan)
+ IO::Async
+ IO::Socket::IP
+ URI
+ URI::Escape::XS

## Commands
### All commands can be executed either by using ! or . as a prefix
+ start / begin [\<common interests (space separated)\>] - starts a new session
+ stop / end - ends current session
+ captcha / submit \<response\> - sends captcha response to omegle
+ send / say \<message\> - sends message to omegle stranger
+ asl [\<sex\>] - sends a random asl, if a parameter is given the sex is replaced with that
+ troll - sends the result of a http request to omegle/trollsrc
