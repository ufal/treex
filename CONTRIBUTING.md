# Contributing to Treex
Thank you for taking the time to contribute and reading these guidelines.

* You can report bugs or feature requests using [GitHub issues](https://github.com/ufal/treex/issues).
* We welcome code and documentation contributions using [Pull requests](https://github.com/ufal/treex/pulls).
* You can send questions to the developers responsible for a given file (listed at the end of POD)
  or to the Treex mailing list (see http://ufal.cz/treex/contact).

## Guidelines on commits
* Use branches for bigger (longer-term) changes that may influence more users and use a pull request for discussion.
  If you have push access to [the GitHub repo](https://github.com/ufal/treex), create a branch there,
  otherwise create the branch in your fork of the repo.
* If you have push access to the GitHub repo,
  you can push smaller changes directly to the master branch, but see the guidelines below.
  To **prevent superfluous merge commits** in [the history](https://github.com/ufal/treex/commits/master)
  use `git pull -r` (which is a shortcut for `git fetch; git rebase;`) instead of `git pull`
  (this of course applies only if your local unpushed commits were not published elsewhere and there are no merge conflicts).
* Make sure you have **set up git to use your email** and you have added this email to your GitHub account's setting.
  This way we can easily identify (and contact) the author of each commit.
  See https://help.github.com/articles/setting-your-email-in-git/.
* Limit the first line of the commit log to 50 or at most 72 characters (that is the title of the commit),
  follow with a blank line and a detailed explanatory text about the commit.
  Refer to the related GitHub issues (e.g. `#1` will be automatically hyperlinked to the issue number 1 on GitHub).
  See e.g. http://ablogaboutcode.com/2011/03/23/proper-git-commit-messages-and-an-elegant-git-history.
* Make sure you can publish the code under [the same license as Perl itself](http://dev.perl.org/licenses/),
  that is dual GNU GPL 1 or later and Artistic License.
  
## Code guidelines
* **Add your name** to the list of authors at the end of each Perl file (in POD).
  You can omit this only in case of tiny changes (e.g. fixing typos in comments).
  If possible add your email.
  The list of authors serves three purposes:
  1. Who was "involved" and possibly who could provide more details about the code?
  2. Who should I ask before refactoring the code?
  3. credit/acknowledgement (but `git blame` provides more details)
* When creating a new file by copying another file (e.g. adapting an English module for your language):
  * If you make bigger changes in the code or if the code is simple enough,
    you **can delete the original list of authors**.
    You can refer to the original file instead (e.g. in the SEE ALSO section of the POD).
    If you are in the habit of copying an unrelated file just to get the Perl/Treex boilerplate,
    then make sure to delete the original authors.
  * If you are not making bigger changes in the code and the code is not simple enough,
    then consider creating a (language independent) base class
    (e.g. `W2A::Tokenize` is a base class for all `W2A::XY::Tokenize`)
    or **prevent code duplication** by other means.
  
  
  
