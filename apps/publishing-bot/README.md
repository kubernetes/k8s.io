# Publishing Bot

The [publishing-bot] runs in the`publishing-bot` namespace in the `aaa`
cluster in the `kubernetes-public` project.

The GitHub token is in the publishing-bot repo and is encrypted
with git-crypt. The publishing-bot [OWNERS] have access to the token.

For more details on deploying the bot, please see these [instructions].


[publishing-bot]: https://github.com/kubernetes/publishing-bot
[OWNERS]: https://github.com/kubernetes/publishing-bot/blob/master/OWNERS
[instructions]: https://github.com/kubernetes/publishing-bot/blob/master/k8s-publishing-bot.md
