Summary: An high level argument parsing library for bash.
Name: bash-argsparse
Version: 1.5
Release: 0%{?dist}
License: WTFPLv2
URL: https://github.com/Anvil/bash-argsparse
Source0: http://argsparse.livna.org/%{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArch: noarch
# The interpreter, with its minimal version.
Requires: bash >= 4.1
# Argsparse some very few binaries: getopt contained in util-linux,
# getent contained in glibc-common and host contained in bind-utils.
Requires: util-linux glibc-common bind-utils

%description
An high level argument parsing library for bash.

The purpose is to replace the option-parsing and usage-describing
functions commonly rewritten in all scripts.

This library is implemented for bash version 4. Prior versions of bash
will fail at interpreting that code.

%prep
%setup -q

%build

%install
mkdir -p $RPM_BUILD_ROOT/%{_bindir}
install -m 0755 argsparse.sh $RPM_BUILD_ROOT/%{_bindir}
ln -s argsparse.sh $RPM_BUILD_ROOT/%{_bindir}/argsparse


%files
%doc tutorial README.md
%{_bindir}/argsparse
%{_bindir}/argsparse.sh


%changelog
* Thu Mar 21 2013 Dams <bash-argsparse[AT]livna.org> - 1.5-0
- Version 1.5
- Updated Requires
- Removed old/fedora-obsolete directives/noise

* Thu Mar 14 2013 Dams <bash-argsparse[AT]livna.org> - 1.4-0
- Initial build.

