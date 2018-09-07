gpg --import astro.pub
gpg --batch --yes -r Astro --trust-model always -o .env.enc -e .env
