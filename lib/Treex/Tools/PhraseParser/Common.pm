package Treex::Tools::PhraseParser::Common;

use Moose;
use MooseX::FollowPBP;
use Treex::Core::Common;
use File::Temp;
use File::Slurp;

has language => ( isa => 'Str', is => 'rw', required => 1, default => 'en', );
has tmpdir => ( isa => 'Str', is => 'rw');

sub BUILD {
    my ( $self ) = @_;
    $self->set_tmpdir(
        File::Temp::tempdir( Treex::Core::Config->tmp_dir."/parser_XXXXXX") #, CLEANUP => 1
      );
    log_info "Temporary directory for a phrase-structure parser: ".$self->tmpdir."\n";
}

sub prepare_parser_input {
    my ($self, $zones_rf) = @_;
    open my $INPUT, ">:utf8", $self->tmpdir."/input.txt" or log_fatal $!;
    
    #get rid of spaces such as U. S.
#        foreach my $z (@$zones_rf) {
#       my @a_temp_nodes= $z->get_atree->get_descendants({ordered=>1});
#       
#       foreach my $a_node (@a_temp_nodes){
#       my $f = $a_node->form;
#       $f=~ s/\s+//g;
#       $a_node->set_attr( 'form', $f);
#       }
#              }
    
    foreach my $zone (@$zones_rf) {
        print $INPUT join " ", map{$_->form} $zone->get_atree->get_descendants({ordered=>1});
        print $INPUT "\n";
    }
    close $INPUT;
}

sub run_parser {
    log_fatal 'Treex::Tools::PhraseParser::Common is an abstract predecessor, tied with no real parser';
}

sub convert_parser_output_to_ptrees {
    my ($self, $zones_rf) = @_;
    my $output = read_file( $self->tmpdir."/output.txt" )
        or log_fatal "Empty or non-existing ".$self->tmpdir."/output.txt  $!";

    $output =~ s/\n\(/__START__\(/gsxm;
    $output =~ s/\s+/ /gsxm;
    my @mrg_strings = split /__START__/,$output;

    if (@mrg_strings != @$zones_rf) {
        log_fatal "There must be same number of zones and parse trees";
    }

    foreach my $zone (@$zones_rf) {
        if ($zone->has_ptree) {
            $zone->remove_tree('p');
        }
        my $proot = $zone->create_ptree;
        my $mrg_string = shift @mrg_strings;
        $proot->create_from_mrg($mrg_string);
    }
}


sub parse_zones {
    my ($self, $zones_rf) = @_;
    log_info (scalar(@$zones_rf). " sentences to be parsed");
    $self->prepare_parser_input($zones_rf);
    $self->run_parser();
    $self->convert_parser_output_to_ptrees($zones_rf);
}


1;

__END__


