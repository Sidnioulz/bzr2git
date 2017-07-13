#!/bin/bash

# bzr2git

# (c) Steve Dodier-Lazaro 2017. Forked from Tobias Frost's bzr2git.
# (c) Tobias Frost 2009. Released under the GPL3.
# http://blog.coldtobi.de

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# This script takes a bazaar (bzr) repository and makes a git repository out of
# it. The current dir should be the bzr one, the git one is created in
# new_git_repo.
#
# To commit to a different git branch, just remove the exit 1 below and before
# invoking the script, create the branch manually in git and change to it.
# (note: this is untested, but should work)

# NOTE: !!!ALWAYS USE BACKUPS!!! THIS SCRIPT MIGHT HAVE AN ERROR
# WHICH TRIGGERS DOOMSDAY



if [[ -e new_git_repo ]]
then
  echo "new_git_repo exits. Please remove it or edit this script"
  echo "alternativly, comment out the exit 1 below and go on on your own risk"
  echo "(you can then add branches to git...)"
  exit 1
else
  # generate a git repository staging directory
  # make a empty git repository	
  mkdir new_git_repo || exit 1
  (cd new_git_repo && git init) || exit 1
fi

if [[ -e rev_to_merge ]]
then
  echo "rev_to_merge exits. Please remove it or edit this script"
  exit 1
fi

# ok, so lets start extracting the revs from bzr.
limit=$((`bzr revno`))
for (( j=1; j<=$limit ; j++ ))
do	
    # Here you can pimp the revision to be checked out in order to manually merge
    # some branch...
    # e.g i="32.1.$j" to get the branch 32.1.x
    i=$j
    # check for log and determine if rev exists....
    bzr log --revision $i 2>/dev/null | tail -n +7 | cut -c3- > /tmp/revlog  || exit 1
    echo >>/tmp/revlog
    echo "original bzr status:" >>/tmp/revlog
    bzr log -r $i | tail -n +2 | head -n 4 >>/tmp/revlog

    #extract author and date
    AUTHOR=$(bzr log -r $i | grep ^committer: | cut -c12-)
    export GIT_COMMITTER_DATE=""
    export GIT_COMMITTER_DATE=$(bzr log -r $i | grep ^timestamp: | cut -c12-)
    export GIT_AUTHOR_DATE=$GIT_COMMITTER_DATE
    echo $GIT_COMMITTER_DATE

    [[ "x$AUTHOR" == "x" ]] && AUTHOR="unkown"

    echo "Extracting rev $i"
    # see if there is a tag associated with this revision
    # sed: expr1 -> remove revision number
    #      expr2 -> remove trailing blanks
    #	   expr3 -> replace blanks with underscores
    TAGS=$(bzr tags -r $i | sed -e "s/\(.*\).$i/\1/g" -e 's/[ \t]*$//' -e "s/\(.*\)/\'\1\'/g" -e "s/[[:blank:]]/_/g")
    if [[ "x$TAGS" != "x" ]]
    then
	echo "TAGS detected."
	echo TAGS $TAGS || hexdump -C
	
    fi

    bzr branch --revision $i . rev_to_merge || exit 1

    # make sure that we update the gitignore as well.
    rm -rf new_git_repo/* # remove old files or mv will complain
    mv -f rev_to_merge/.bzrignore new_git_repo/.gitignore
    mv -f rev_to_merge/* new_git_repo/ || exit 1

    # do the commit -- we ignore it if it 'fails' because some bzr operations
    # like committing an empty folder or removing files won't work, but that
    # will apparently not affect the viability of the final repository.
    ( cd new_git_repo && git add -A ) || exit 1
    ( cd new_git_repo && git commit --author "$AUTHOR" -F /tmp/revlog )

   if [[ "x$TAGS" != "x" ]]
   then
    for t in $TAGS
      do
	   echo "CREATING TAG $t"
	   ( cd new_git_repo && git tag -a $t -m "Autoimported tag $t from bzr repository" ) || exit 1
      done
    fi
    # remove the staging dir
    rm -rf rev_to_merge || exit 1
done
