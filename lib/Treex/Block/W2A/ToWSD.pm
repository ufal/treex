package Treex::Block::W2A::ToWSD;
use Moose;
use Treex::Core::Log;
use open ':encoding(utf8)';
extends 'Treex::Core::Block';

# TODO: get W2A::ToWSD + W2A::RunDocWSD + W2A::FromWSD in a single block called
#       BatchWSD and rename W2A::WSD as W2A::OnlineWSD

has 'filename_prefix' => ( is => 'ro', isa => 'Str', required => 1 );

has file_handle => (
    isa           => 'Maybe[FileHandle]',
    is            => 'rw',
    writer        => '_set_file_handle',
    documentation => 'The open output file handle.',
);

has 'field_sep' => ( is => 'rw',  default => '\t' );
has 'token_sep' => ( is => 'rw',  default => '\n' );
has 'sent_sep' => ( is => 'rw',  default => '\n\n' );


sub process_atree {
    my ( $self, $a_root ) = @_;
    my $wsd_input = join "\n",
    	map { $self->format_token($_); }
    	$a_root->get_descendants({ ordered => 1 });
    print { $self->file_handle } $wsd_input."\n\n";
    return;
};

sub print_header {
    my ( $self, $document ) = @_;
	print { $self->file_handle } "form\tlemma\tpos\n";
    return;
}

sub format_token {
	my ( $self, $a_node ) = @_;
	my $form = $a_node->form || '';
	my $lemma = lc ($a_node->form || '');
	my $pos = $a_node->conll_pos || $a_node->tag || '';
	$form =~ s/ /_/;
	$lemma =~ s/ /_/;
	my $result = "$form\t$lemma\t$pos";
	return $result;
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
    $self->print_header($document);
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
    log_info "Writing to $filename";
    open ( $handle, '>', $filename );
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

Treex::Block::W2A::ToWSD;


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
