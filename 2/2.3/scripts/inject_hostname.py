#!/usr/bin/python
#
# Copyright 2019 Google LLC
#
# This software is licensed under the Open Software License version
# 3.0. The full text of this license can be found in https://opensource.org/licenses/OSL-3.0
# or in the file LICENSE which is distributed along with the software.

# The purpose of this file is:
# - inject inc/hostname_fix in Magento entrypoint (app/pub/index.php)
# - and assure the patch cannot be injected more than once
# The patch is important so the user can access from a different hostname than localhost.
# Such as a public ip or even a domain if its well-configured.

import re
import argparse


def get_include_contents(include_file):
    """Reads the include file and returns its contents.

    Keyword arguments:
    include_file -- path of the include file which will be read
    """
    with open(include_file, 'r') as f:
        contents = f.read()
    return contents


def inject(source_file, include_file):
    """Injects include file into the source one

    Keyword arguments:
    source_file -- path of the file which will receive the injection
    include_file -- path of the file which will be injected
    """
    new_file = []
    should_write_file = True

    # Read source file
    with open(source_file) as f:
        # Iterate over all lines
        for line in f:
            # Try to find the point of inject
            match = re.search('\$bootstrap->createApplication', line)
            new_file.append(line)

            # If point of inject is found, include the injection content
            if match:
                new_file.append(get_include_contents(include_file))
                new_file.append('\n')

            # Try to check if source file has been already injected
            match = line.find('use \\Magento\\Framework\\App\\ObjectManager;') >= 0

            # If source file has already been injected, bypass it.
            # It avoids to duplicate the patch
            if match:
                should_write_file = False
                break
        f.close()

    # Only writes the new file, if source is not patched
    if should_write_file:
        write_new_file(source_file, ''.join(new_file))


def write_new_file(source_file, contents):
    """Injects include file into the source one

    Keyword arguments:
    source_file -- path of the file which will receive the injection
    contents -- new content received
    """
    # Write new contents on source file
    with open(source_file, 'w') as f:
        f.write(contents)


def main():
    """Application entrypoint"""

    # Declare CLI arguments and parses it
    parser = argparse.ArgumentParser(description='Inject simple script')
    parser.add_argument('--source')
    parser.add_argument('--include')
    cli_args = parser.parse_args()

    # Inject file
    inject(
        source_file=cli_args.source,
        include_file=cli_args.include
    )


if __name__ == '__main__':
    main()
