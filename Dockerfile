FROM perl:5.20

# graphviz ... AI::DecisionTree dependency
# default-jre ... MSTperl parser is in Java
RUN apt-get update && apt-get install -y \
	graphviz \
	default-jre \
    libboost-all-dev \
    cmake

# Modules, that are needed to run treex -h (and the Hello world
RUN cpanm \
	YAML/Tiny.pm \
	XML::LibXML \
	Moose \
	MooseX \
	MooseX::NonMoose \
	MooseX::Getopt \
	MooseX::Role::Parameterized  \
	MooseX::Role::AttributeOverride \
	MooseX::SemiAffordanceAccessor \
	Readonly \
	File::HomeDir \
	File::ShareDir \
	File::Slurp \
	File::chdir \
	YAML \
	LWP::Simple \
	String::Util \
	PerlIO::gzip \
	Class::Std

# The PerlIO:Util has bug in its tests
RUN cpanm -n PerlIO::Util
RUN cpanm PerlIO::via::gzip

# Other, "optional" Treex dependencies
RUN cpanm \
	autodie \
	threads \
	threads::shared \
	forks \
	namespace::autoclean \
	Module::Reload \
	IO::Interactive \
	App::whichpm \
	Treex::PML \
	Cache::Memcached \
    List::Pairwise \
    Algorithm::NaiveBayes \
    AI::DecisionTree \
	Algorithm \
    Algorithm::DecisionTree \
	AnyEvent \
	AnyEvent::Fork \
	Bash::Completion::Utils \
	Carp \
	Carp::Always \
	Carp::Assert \
	Clone \
	Compress::Zlib \
	DBI \
	DateTime \
	EV \
	Email::Find \
	Encode::Arabic \
	Frontier::Client \
	Graph \
	Graph::ChuLiuEdmonds \
	Graph::MaxFlow \
	HTML::FormatText \
	JSON \
	Lingua::EN::Tagger \
	Modern::Perl \
	MooseX::ClassAttribute \
	MooseX::FollowPBP \
	MooseX::Types::Moose \
	PML \
	POE \
	String::Diff \
	Test::Files \
	Test::Output \
	Text::Brew \
	Text::JaroWinkler \
	Text::Table \
	Text::Unidecode \
	Tk \
	Tree::Trie \
	URL::Encode \
	XML::Simple

# One of the subtests failed during image build
RUN cpanm -n  AI::MaxEntropy

# Create root dir for treex checkout, share and tmp
RUN mkdir ~/tectomt && cd ~/tectomt && git clone https://github.com/ufal/treex.git

ENV TMT_ROOT=/root/tectomt
ENV TREEX_ROOT="${TMT_ROOT}/treex"
ENV PATH="${TREEX_ROOT}/bin:$PATH"
ENV PERL5LIB="${TREEX_ROOT}/lib:$PERL5LIB"
ENV PERLLIB=$PERL5LIB

RUN mkdir -p /root/.treex/share/installed_tools
RUN ln -s /root/.treex/share $TMT_ROOT/share
RUN ln -s /tmp $TMT_ROOT/tmp

# Some UFAL modules used by treex
RUN cpanm Text::Iconv
RUN cpanm Ufal::NameTag
RUN cpanm Ufal::MorphoDiTa
RUN cpanm Lingua::Interset
RUN cpanm URI::Find
RUN cpanm Cache::LRU

# install Morce tagger
RUN svn --username public --password public export https://svn.ms.mff.cuni.cz/svn/tectomt_devel/trunk/libs/packaged /tmp/packaged
RUN cd /tmp/packaged/Morce-English && perl Build.PL && ./Build && ./Build install --prefix /usr/local/
# download models
RUN mkdir -p /root/.treex/share/data/models/morce/en
RUN cd tectomt/share/data/models/morce/en && wget http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/morce/en/morce.alph http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/morce/en/morce.dct http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/morce/en/morce.ft http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/morce/en/morce.ftrs http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/morce/en/tags_for_form-from_wsj.dat

# install NADA
RUN svn --username public --password public export https://svn.ms.mff.cuni.cz/svn/tectomt_devel/trunk/install/tool_installation /tmp/tool_installation
RUN cd /tmp/tool_installation/NADA && perl Makefile.PL && make && make install

# simple Hello world test
RUN bash -c "echo 'Hello world' | treex -Len Read::Sentences Write::Sentences"
