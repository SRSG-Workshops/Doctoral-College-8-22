#!/usr/bin/env bash

# Developer note: This is a local build file that broadly replicates the processes in the .github/workflows/website.yml
#                 if you are editing this file to make a local build work then the corresponding changes must be made in
#                 the github workflow.

# Get the name of the current git branch
MYBRANCH=$(git rev-parse --abbrev-ref HEAD)

clean_branch()
{
#pull down the venv
deactivate || source deactivate

# Clean the things not tracked by git
rm setup.md
rm -r _site/ venv/ collections/ _includes/rsg/*-lesson/ slides/ _includes/ submodules/
# Workshop Only
find -f ./data \! -name "*.md" -depth 1 -delete # This is for the workshop only the data should be preserved in the lessons
rm -r fig/*
# Workshop only over
rm assets/favicons/rsg/apple* assets/favicons/rsg/favicon* assets/favicons/rsg/mstile*
if [ 0 -lt $(ls _episodes_rmd/*.Rmd 2>/dev/null | wc -w) ]; then
  rm _episodes/*.md _episodes/_page_built_on.html
  rm -r _episodes_rmd/fig/
  # These files are created in r-novice day 3
  rm combo_plot_abun_weight.png name_of_file.png
fi

# Checkout main and cleanup branch
git checkout $MYBRANCH
git branch -d localbuild || echo 'branch local build does not exist to delete'
git add -u
git commit -m "cleanup"
exit
}

#Trap the teardown to avoid poor state on build failure
trap clean_branch 1 2 3 6

# Make a branch to build on to avoid messing up main
git branch -d localbuild || echo 'branch local build does not exist to delete'
git checkout -b localbuild

# Replicate GH actions =================================================================================================
python -m venv ./venv || echo 'venv already exists'

#TODO: Make this windows safe
source venv/bin/activate

rvm install 2.7.1
rvm use 2.7.1
#TODO: Check why we need sudo here on ubuntu
gem install github-pages bundler kramdown kramdown-parser-gfm

#TODO: Make this platform safe
# sudo apt-get install -y libcurl4-openssl-dev

python3 -m pip install --upgrade pip setuptools wheel pyyaml==5.3.1 requests
python3 -m pip install -r requirements.txt

python bin/get_submodules.py

if ls _episodes_rmd/*.Rmd >/dev/null 2>&1; then
  Rscript renv/activate.R
  script -e 'renv::restore()'
  RMD_PATH=$(find ./_episodes_rmd -name '*.Rmd')
  Rscript -e 'for (f in commandArgs(TRUE)) if (file.exists(f)) rmarkdown::render(f, knit_root_dir=getwd(), output_dir=dirname(sub("./collections/_episodes_rmd/", "./collections/_episodes/", f)))' ${RMD_PATH[*]}
  perl -pi -e "s/([>\s]*)(>\s)(.*?)(\{: \.[a-zA-Z]+\})/\1\2\3\n\1\4\n\1/g" ./collections/_episodes/r-novice-lesson/*.md
  perl -0777pi -e "s/(?<!\n){: .challenge}/\n{: .challenge}/g" ./collections/_episodes/r-novice-lesson/*.md
  cp ./collections/_episodes_rmd/**/fig/*.png ./fig/
fi

python bin/make_favicons.py
python bin/get_schedules.py
python bin/get_setup.py

# Build the site.
bundle install
bundle exec jekyll serve --baseurl=""
# All GH actions replicated=============================================================================================

#Note: the site is up here and will remain up until an interrupt (ctrl-c) is sent then the resto of this script triggers
#      and cleans out the build.
clean_branch