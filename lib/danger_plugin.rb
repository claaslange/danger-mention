require 'open-uri'
require_relative 'finder'

module Danger

  # Automatically mention potential reviewers on pull requests.
  # It downloads and parses the blame information of changed files
  # to figure out who may be a good reviewer.
  #
  # @example Running plugin with reviewers count specified
  #
  #          # Find maximum two reviewers
  #          mention.run(2, [], [])
  #
  # @example Running plugin with some files blacklisted
  #
  #          # Find reviewers without parsing blame information
  #          # from files matching to 'Pods/*'
  #          mention.run(2, ["Pods/*"], [])
  #
  # @example Running plugin with some users blacklisted
  #
  #          # Find reviewers ignoring users 'wojteklu' and 'danger'
  #          mention.run(2, [], ["wojteklu", "danger"])
  #
  # @tags github, review, mention, blame

  class DangerMention < Plugin

    # Mention potential reviewers.
    #
    # @param   [Integer] max_reviewers
    #          Maximum number of people to ping in the PR message, default is 3.
    # @param   [Array<String>] file_blacklist
    #          Regexes of ignored files.
    # @param   [Array<String>] user_blacklist
    #          List of users that will never be mentioned.
    # @return  [void]
    #
    def run(max_reviewers = 3, file_blacklist = [], user_blacklist = [])
      files = select_files(file_blacklist)
      return if files.empty?

      authors = get_commits(files)
      reviewers = find_reviewers(authors, user_blacklist, max_reviewers)

      if reviewers.count > 0
        reviewers = reviewers.map { |r| '@' + r }

        result = format('By analyzing the blame information on this pull '\
        'request, we identified %s to be potential reviewer%s.',
                        reviewers.join(', '), reviewers.count > 1 ? 's' : '')

        markdown result
      end
    end

    private

    def select_files(file_blacklist)
      files = Finder.parse(env.scm.diff)

      file_blacklist = file_blacklist.map { |f| /#{f}/ }
      re = Regexp.union(file_blacklist)
      files = files.select { |f| !f.match(re) }

      files[0...3]
    end

    def get_commits(files)
      repo_slug = env.ci_source.repo_slug

      authors = {}
      files.each do |file|
        file_commits = github.api.commits(repo_slug, github.branch_for_base, { path: file })
        file_commits.each do |commit|
          author = commit.author.login
          if authors[author]
            authors[author] = authors[author].to_i + 1
           else
            authors[author] = 1
          end
        end
      end

      authors
    end

    def find_reviewers(users, user_blacklist, max_reviewers)
      user_blacklist << github.pr_author
      users = users.select { |k, _| !user_blacklist.include? k }
      users = users.sort_by { |_, value| value }.reverse

      users[0...max_reviewers].map { |u| u[0] }
    end

  end
end
