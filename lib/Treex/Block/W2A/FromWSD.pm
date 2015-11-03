package Treex::Block::W2A::FromWSD;
use Moose;
use Treex::Core::Log;
use open ':encoding(utf8)';
extends 'Treex::Core::Block';

has 'filename_prefix' => ( is => 'ro', isa => 'Str', required => 1 );

has file_handle => (
    isa           => 'Maybe[FileHandle]',
    is            => 'rw',
    writer        => '_set_file_handle',
    documentation => 'The open output file handle.',
);

sub process_atree {
    my ( $self, $a_root ) = @_;
    my $file_handle = $self->file_handle;
    foreach my $a_node ($a_root->get_descendants({ ordered => 1 })) {
    	my $wsd_output_line = <$file_handle>;
        chomp $wsd_output_line;
    	my ($form, $lemma, $pos, $_synsetids, $_supersenses) = split /\t/, $wsd_output_line;
        if ($a_node->form ne $form) {
            log_warn $a_node->form." != ".$form;
        } else {
            my @synsetids = split /\t/, $_synsetids;
            my @supersenses = split /\t/, $_supersenses;
            if (@synsetids) {
                log_debug $a_node->form." synsetid=".$synsetids[0]. " supersense=".$supersenses[0];
                $a_node->wild->{synsetid} = $synsetids[0] if $synsetids[0] ne '_';
                $a_node->wild->{supersense} = $supersenses[0] if $supersenses[0] ne '_';
            }
        }
    }
    my $empty_line = <$file_handle>;
    chomp $empty_line;
    if ($empty_line ne "") {
    	log_warn "expected empty line";
    }
    return;
}

sub read_header {
    my ( $self, $document ) = @_;
    my $file_handle = $self->file_handle;
    my $header = <$file_handle>;
    if ( $header ne "form\tlemma\tpos\tsynsetids\tsupersenses\n" ) {
        log_fatal "expected header line: form\\tlemma\\tpos\\tsynsetids\\tsupersenses\n"
    			 ."but I got:\n$header";
    }
    return;
}

# Default process_document method for all Writer blocks. 
override 'process_document' => sub {
    my ( $self, $document ) = @_;
    # set _file_handle properly
    $self->_prepare_file_handle($document);
    # call the original process_document with _file_handle set
    $self->_do_process_document($document);
	$self->_close_file_handle();
};

sub _do_process_document {
    my ($self, $document) = @_;
    $self->read_header($document);
    $self->Treex::Core::Block::process_document($document);
    return;
}

override 'process_end' => sub {
    my $self = shift;
    $self->_close_file_handle();
    return;
};

sub _prepare_file_handle {
    my $self = shift;
	$self->_close_file_handle();
    my $handle;
	my $filename = $self->filename_prefix.".$$";
    log_info "Reading from $filename";
    open ( $handle, '<', $filename );
    $self->_set_file_handle($handle);
}

sub _close_file_handle {
    my $self = shift;
    if (defined $self->file_handle) {
        close $self->file_handle;
        $self->_set_file_handle(undef);
     }
    return;
}

1;

__END__


=head1 NAME

Treex::Block::W2A::FromWSD;


=head1 SYNOPSIS

This block prints sentences in the formats expected by either:
 * the UKB Python wrapper (lib/python3/ukb.py)
 * the UKB Bash wrapper (tools/lx-wsd-module-vx.y) (by Steve Neale).

For the first format give format=tsv and for the second format=slash.

For more information about UKB see http://ixa2.si.ehu.es/ukb/.


=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
