package Treex::Block::Print::Clauses;
use Moose;
use Treex::Core::Common;
use Treex::Core::TredView::Colors;
use Tk;
use Tk::Button;
use Treex::Block::Eval::EvalClauses;

extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';

sub build_language { return log_fatal "Parameter 'language' must be given"; }

has 'source_selector' => ( is => 'rw', isa => 'Str',  default => 'test', lazy => 1 );
has 'language'        => ( is => 'rw', isa => 'Str',  default => 'cs',   lazy => 1 );
has 'skip_correct'    => ( is => 'rw', isa => 'Bool', default => '0',    lazy => 1 );
has 'has_gold'        => ( is => 'rw', isa => 'Bool', default => '0',    lazy => 1 );

has '_colors' => (
    is      => 'ro',
    isa     => 'Treex::Core::TredView::Colors',
    default => sub { Treex::Core::TredView::Colors->new() }
);

has _eval => (
    is => 'ro',
    isa => 'Treex::Block::Eval::EvalClauses',
    default => sub {
        new Treex::Block::Eval::EvalClauses->new(
            {
                language        => $_[0]->language,
                source_selector => $_[0]->source_selector,
                _silent         => 1,
            }
        );
    }
);

sub BUILD {
    my $self = shift;  

    my @colors = map { $self->_colors->get_clause_color($_) } (0 .. 9);

    print {$self->_file_handle} '<html><head>',
        '<meta content="text/html; charset=utf-8" http-equiv="Content-Type">',
        '<style type="text/css">'
    ;

    foreach my $i ( 1 .. $#colors) {
         print {$self->_file_handle} ".clause$i { color: " . $colors[$i] . '; }';
    }

    print {$self->_file_handle} 
<<STYLE
.clause0 {background-color: #CCCCCC; }
.ok { border: 1px solid green; }
.ko { border: 3px solid red; }
h1 { font-size: 8pt; color:#CCCCCC; padding:0px; margin:0px; border:0px; text-align:right;}
p { margin:0px; padding-top: 0px; }
</style></head><body>
STYLE
    ;
}

sub process_bundle {
    my ( $self, $bundle ) = @_;
    
    my $test_zone = $bundle->get_zone( $self->language, $self->source_selector );
    if( not $test_zone ) {
        return log_fatal "Cannot find zone ". $self->language . ":" . $self->source_selector . "!";
    }
    my $test_root = $test_zone->get_atree;

    if ( $self->has_gold ) {
        my $gold_zone = $bundle->get_zone( $self->language, $self->selector );
        my $gold_root = $gold_zone->get_atree;
    
        my $pclass = $self->_eval->process_bundle ($bundle) ? 'ko' : 'ok';
        if( not $self->skip_correct or $pclass eq 'ko' ){
            print { $self->_file_handle }
                '<h1>',
                $gold_root->get_document->full_filename, '.treex#' ,
                $gold_root->id,
                '</h1>',
                "<p class=\"$pclass\">",
                $self->_get_sentence_html($test_root),
                $self->_get_sentence_html($gold_root),
                "</p>\n"
                ;
        }
    }
    else {
        print { $self->_file_handle }
            '<h1>',
            $test_root->get_document->full_filename, '.treex#',
            $test_root->id,
            '</h1>',
            "<p class=\"ok\">",
            $self->_get_sentence_html($test_root),
            $self->_get_clauses_html($test_root),
            "</p>\n"
            ;
    }
}

sub _get_sentence_html {
    my ( $self, $aroot ) = @_;  

    my @anodes = $aroot->get_descendants( { ordered => 1 } );
    my @out;
    for my $anode (@anodes) {
        if( defined $anode->clause_number ) {
            push @out,
                '<span class="clause' .
                $anode->clause_number .
                '">' . 
                $anode->form .
                '</span>'
                ;
        }
        else {
            push @out, $anode->form;
        }
        if ( !$anode->no_space_after ) {
            push @out, ' ';
        }
    }
    push @out, '<br>';
    return join '', @out;

}

sub _get_clauses_html {
    my ( $self, $aroot ) = @_;

    my @anodes = $aroot->get_descendants( { ordered => 1 } );

    my @clause_words;
    foreach (@anodes) {
        next unless $_->clause_number;
        push @{ $clause_words[ $_->clause_number ] }, $_;
    }

    my @html;
    my $num = 1;
    foreach (@clause_words) {
        next unless $#{$_} >= 0;
        push @html, "#$num&nbsp; ", '<span class="clause', $_->[0]->clause_number, '">';
        $num++;
        my $prev = undef;
        foreach ( @{$_} ) {
            push @html, q{ }
                unless $prev and $prev->no_space_after and $_->ord == $prev->ord + 1; 
            push @html, $_->form;
            $prev = $_;
        }
        push @html, '</span><br>';
    }
    return join '', @html;
}

sub DEMOLISH {
    my $self = shift;  
    print { $self->_file_handle } '</body></html>';
}

1;

=head1 NAME

Treex::Block::Print::Clauses

=head1 DESCRIPTION

Prints HTML formatted sentences segmented to clauses.

=cut

# Copyright 2011 Jan Popelka
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
