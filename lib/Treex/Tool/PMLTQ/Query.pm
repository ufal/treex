package Treex::Tool::PMLTQ::Query;
use utf8;

use 5.008;
use strict;
use warnings;
use autodie;
use Carp;
use Readonly;

require Exporter;

our @ISA     = qw(Exporter);
our @EXPORT  = qw();
our $VERSION = '0.01';
our $DEBUG   = 0;
our $cachedFsfile = 0;

#####################
# Initialization: @INC, needed libraries, Treex resource path
#####################

# Use the same TrEd library directories as Treex
use Treex::Core::Config;
use File::Spec;

my $libDir;

BEGIN {
    my $tred_dir = Treex::Core::Config->tred_dir();
    log_fatal('TrEd not installed or tred_dir not set') if !defined $tred_dir;
    $libDir = File::Spec->catdir($tred_dir, 'tredlib');
    push @INC, $libDir;
    push @INC, File::Spec->catdir( Treex::Core::Config->lib_core_dir(), 'share', 'tred_extension', 'treex', 'libs' );
}

{ # Fake the package to suppress warnings
    package main;

    our $VERSION = '0.1';
}

use TrEd::Config qw(&read_config &set_default_config_file_search_list);
$TrEd::Config::libDir = $libDir;
$TrEd::Config::quiet = 0;

use TrEd::Utils qw(uniq);
use TrEd::Extensions;
use TrEd::Macros;
use TrEd::Error::Message;
use Treex::PML;

BEGIN {
    $TrEd::Macros::on_error = sub { confess $_[1]; };
    $TrEd::Error::Message::on_error = sub { confess $_[1]; };
}

# Load extensions
set_default_config_file_search_list();
read_config();
load_extensions();

my $grp = {
    treeNo       => 0,
    FSFile       => undef,
    macroContext => 'TredMacro',
    currentNode => undef,
    root        => undef
};

$TrEd::Macros::macrosEvaluated = 0;
TrEd::Macros::initialize_macros($grp);

sub load_extensions {
    require TrEd::MacroAPI::Default; # this loads TredMacro API

    $TredMacro::libDir = $libDir;
    my $ext_directory = TrEd::Extensions::get_extensions_dir();

    # update paths
    Treex::PML::AddResourcePath(File::Spec->catdir($ext_directory, 'pmltq', 'resources'));
    unshift @INC, File::Spec->catdir($ext_directory, 'pmltq', 'contrib', 'pmltq');

    my @extension_list = grep { $_ ne 'pmltq' } uniq (@{TrEd::Extensions::get_preinstalled_extension_list()}, qw(pdt_vallex pdt20 treex));
    TrEd::Extensions::init_extensions(\@extension_list, $ext_directory);

    for my $ext_contrib ( TrEd::Extensions::get_extension_macro_paths(\@extension_list, $ext_directory) ) {
        push @TrEd::Macros::macros,
            qq(\n#line 0 "$ext_contrib"\n{\npackage TredMacro;\n);
        read_macros( $ext_contrib, $libDir, 1 );
        push @TrEd::Macros::macros,
            qq(\n\n=pod\n\n=cut\n\n} # end of "$ext_contrib"\n);
    }
}

#####################
# Code to provide stuff required from btred
#####################

{

	package PML;

	sub Schema {
		my ($pmldoc) = @_;
        return $pmldoc->schema();
	}

	sub GetNodeByID {
		my ($id, $fsfile) = @_;

		# a) not used, appData are not populated
		#my $h = $fsfile->appData('id-hash');
		#return $h && $id && $h->{$id};

		# b) pure fsfile implementation - recompute the id-hash
		#my $h = GetNodeHash($fsfile);
		#return $h && $id && $h->{$id};

		# c) tectomt specific implementation
		# reuses TectoMT::Document, so could be faster
		return undef unless $id && $fsfile;
		my $d = $fsfile->appData('tmt-document');
		return undef unless $d;
		my $n = $d->get_node_by_id($id);
		return undef unless $n;
		return $n;

	}

	sub GetNodeHash {
		my $fsfile = $_[0];
		return {} unless ref($fsfile);
		unless (ref($fsfile->appData('id-hash'))) {
			my %ids;
			my $trees = $fsfile->treeList;
			for (my $i = 0; $i <= $#$trees; $i++) {
				my $node = $trees->[$i];
				while ($node) {
					weaken($ids{ $node->{id} } = $node);
				} continue {
					$node = $node->following;
				}
			}
			$fsfile->changeAppData('id-hash', \%ids);
		}
		return $fsfile->appData('id-hash');
	}
}
{
	package PML_T;
	no warnings qw(redefine);

	sub GetEChildren {
		return PML_T2::GetEChildren(@_);
	}

}

# do not use 'use' or import will be triggered multiple times and new method from TypeMapper will be imported to this block
# and Scenario will be unable to instantiate this block
require Tree_Query::TypeMapper;
require Tree_Query::BtredEvaluator;
require PMLTQ::Relation;
require PMLTQ::Relation::PDT20;
require PMLTQ::Relation::Treex;

#################################################
#
# Compile query and initialize the query engine

#my $evaluator = Tree_Query::BtredEvaluator->new($query, {
#  fsfile => $fsfile,
# tree => $fsfile->tree(0), # query only a specific tree
# no_plan => 1, # do not let the planner rewrite my query
# in this case, the query must not be a forest!
#});

sub new {
	my ($class, $query, $opts) = @_;
	use Data::Dumper;

	#print "in new Query: class: $class query: $query opts" . Dumper($opts). "\n";
	$opts ||= {};

	if (defined $opts->{tree_root}) {
		$opts->{treex_document} = $opts->{tree_root}->get_document();
		$opts->{fsfile}       = $opts->{treex_document}->_pmldoc;
		$opts->{tree}         = $opts->{tree_root};

		#use Data::Dumper;
		#print STDERR Data::Dumper->new([$opts->{tree}],[qw(root)])->Indent(2)->Quotekeys(0)->Maxdepth(2)->Dump . "\n";
	}
	elsif (defined $opts->{treex_document}) {
		$opts->{fsfile} = $opts->{treex_document}->_pmldoc;
	}

	# remember the tmt-document, so overidden PML::GetNodeByID can use it
	# beware: this may cause leaks, consult with ZZ!
	$opts->{fsfile}->changeAppData('tmt-document', $opts->{treex_document});
        return Tree_Query::BtredEvaluator->new($query, $opts);
}

1;

__END__

=head1 NAME

Treex::Tool::PMLTQ::Query

=head1 SYNOPSIS

    use Treex::Tool::PMLTQ::Query;

    my $query = Treex::Tool::PMLTQ::Query->new(
        't-node [ t_lemma = "být" ];',      # Any PML-TQ query string
        { treex_document => $document }     # Treex document
    );

    $query = Treex::Tool::PMLTQ::Query->new(
        't-node [ t_lemma = "být" ];',
        { tree_root => $troot }     # A Treex [tanp]-tree root
    );

=head1 DESCRIPTION

This is a tiny wrapper around the L<Tree_Query::BtredEvaluator> PML-TQ module,
which exists just to set up what is needed for the BtredEvaluator to feel like at home,
i.e. running inside C<btred>.

Stuff needed for C<Treex::PML::Document> loading is commented out: we expect that the
end user of this module provides an already created document/tree.

This module requires TrEd 2.0 and higher; the required C<Tree_Query> and C<PMLTQ>
libraries are downloaded automatically from their SVN directories.

=head1 AUTHORS

Petr Pajas

Jan Ptáček

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2009-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.cut
