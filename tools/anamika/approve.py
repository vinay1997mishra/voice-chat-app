"""Bind explicit repository-owner approval to one PR head SHA."""
import os
import re
from repair import allowed, request_json


def verify(pr, sha, repo):
    if not re.fullmatch(r'[a-f0-9]{40}', sha):
        raise ValueError('Use the complete 40-character reviewed commit SHA')
    if pr['state'] != 'open' or pr['head']['sha'] != sha:
        raise ValueError('PR changed or is no longer open; review it again')
    if pr['head']['repo']['full_name'] != repo or pr['base']['ref'] != 'main':
        raise ValueError('Unexpected source repository or base branch')
    if not pr['head']['ref'].startswith('anamika/repair-'):
        raise ValueError('Only Anamika repair proposals are accepted')


def main():
    repo = os.environ['GITHUB_REPOSITORY']
    if os.environ['GITHUB_ACTOR'] != repo.split('/')[0]:
        raise ValueError('Only the repository owner can approve an upgrade')
    sha, number = os.environ['APPROVED_SHA'], os.environ['PROPOSAL_ID']
    if not number.isdigit():
        raise ValueError('Proposal ID must be a pull request number')
    api = 'https://api.github.com/repos/' + repo
    token = os.environ['GH_TOKEN']
    pr = request_json(api + '/pulls/' + number, token=token)
    verify(pr, sha, repo)
    page, count = 1, 0
    while True:
        files = request_json(api + '/pulls/' + number + '/files?per_page=100&page=' + str(page), token=token)
        for file in files:
            if file['status'] not in ('added', 'modified') or not allowed(file['filename']):
                raise ValueError('Proposal contains a protected change')
        count += len(files)
        if len(files) < 100:
            break
        page += 1
    if not count:
        raise ValueError('Proposal has no changes')
    with open(os.environ['GITHUB_OUTPUT'], 'a') as f:
        f.write('sha=' + sha + '\n')
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as f:
        f.write('Owner approved PR #' + number + ' at exact SHA `' + sha + '`.\n')


if __name__ == '__main__':
    main()
