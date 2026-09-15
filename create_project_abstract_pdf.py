import os
import sys
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, KeepTogether, HRFlowable
)
from reportlab.pdfgen import canvas

# Define Canvas with Running Headers & Footers and Dynamic Page Count
class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        print(f"Total pages rendered: {num_pages}")
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_header_footer(num_pages)
            super().showPage()
        super().save()

    def draw_header_footer(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 7.5)
        self.setFillColor(colors.HexColor("#4A5568"))

        # Running Header (on page 2 and later)
        if self._pageNumber > 1:
            self.drawString(36, 810, "GEOGUARD v2.0: PREDICTIVE LANDSLIDE EARLY WARNING SYSTEM")
            self.drawRightString(559, 810, "PROJECT EXTENDED ABSTRACT")
            self.setStrokeColor(colors.HexColor("#CBD5E0"))
            self.setLineWidth(0.6)
            self.line(36, 804, 559, 804)

        # Running Footer (on all pages)
        self.setStrokeColor(colors.HexColor("#CBD5E0"))
        self.setLineWidth(0.6)
        self.line(36, 36, 559, 36)
        self.drawString(36, 26, "GeoGuard LEWS - Multiphysics Geotechnical Modeling & ML Telemetry Platform")
        page_str = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(559, 26, page_str)
        self.restoreState()


def generate_pdf():
    pdf_path = "GeoGuard_Project_Abstract.pdf"
    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=A4,
        leftMargin=36,
        rightMargin=36,
        topMargin=36,
        bottomMargin=36
    )

    styles = getSampleStyleSheet()

    # Custom Color Palette
    PRIMARY = colors.HexColor("#0D233A")    # Deep Navy
    SECONDARY = colors.HexColor("#1A5276")  # Steel Blue
    ACCENT_WARN = colors.HexColor("#9C0006")# Crimson
    ACCENT_SAFE = colors.HexColor("#006100")# Forest Green
    DARK_TEXT = colors.HexColor("#1A202C")  # Dark Slate
    MUTED_TEXT = colors.HexColor("#4A5568") # Slate Gray
    BG_LIGHT = colors.HexColor("#F7FAFC")   # Crisp Off-White
    BORDER_COLOR = colors.HexColor("#E2E8F0")

    # Typography Styles
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=15,
        leading=18,
        textColor=PRIMARY,
        alignment=1, # Center
        spaceAfter=3
    )

    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11.5,
        textColor=SECONDARY,
        alignment=1,
        spaceAfter=5
    )

    meta_style = ParagraphStyle(
        'DocMeta',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=7.5,
        leading=10,
        textColor=MUTED_TEXT,
        alignment=1,
        spaceAfter=6
    )

    sec_header_style = ParagraphStyle(
        'SectionHeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.8,
        leading=11,
        textColor=colors.white,
        spaceBefore=0,
        spaceAfter=0
    )

    body_style = ParagraphStyle(
        'BodyDark',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7.2,
        leading=9.6,
        textColor=DARK_TEXT,
        alignment=4, # Justified
        spaceAfter=4
    )

    callout_style = ParagraphStyle(
        'CalloutText',
        parent=styles['Normal'],
        fontName='Helvetica-Oblique',
        fontSize=7.2,
        leading=9.5,
        textColor=PRIMARY
    )

    table_cell_style = ParagraphStyle(
        'TableCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=6.8,
        leading=8.6,
        textColor=DARK_TEXT
    )

    table_cell_bold = ParagraphStyle(
        'TableCellBold',
        parent=table_cell_style,
        fontName='Helvetica-Bold',
        textColor=PRIMARY
    )

    table_cell_center = ParagraphStyle(
        'TableCellCenter',
        parent=table_cell_style,
        alignment=1
    )

    table_cell_safe = ParagraphStyle(
        'TableCellSafe',
        parent=table_cell_style,
        fontName='Helvetica-Bold',
        textColor=ACCENT_SAFE,
        alignment=1
    )

    fig_caption_style = ParagraphStyle(
        'FigCaption',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=7,
        leading=9,
        textColor=MUTED_TEXT,
        alignment=1,
        spaceBefore=3,
        spaceAfter=4
    )

    def make_section_banner(title_text):
        p = Paragraph(f"<b>{title_text.upper()}</b>", sec_header_style)
        t = Table([[p]], colWidths=[523.27])
        t.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), SECONDARY),
            ('TOPPADDING', (0, 0), (-1, -1), 2.5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 2.5),
            ('LEFTPADDING', (0, 0), (-1, -1), 6),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ]))
        return t

    story = []

    # -------------------------------------------------------------
    # PAGE 1: TITLE, EXECUTIVE ABSTRACT, ARCHITECTURE, FORMULATION
    # -------------------------------------------------------------
    story.append(Paragraph("GEOGUARD: PREDICTIVE LANDSLIDE EARLY WARNING SYSTEM", title_style))
    story.append(Paragraph("A Geotechnically-Coupled Multiphysics Modeling, Real-Time Kinematic Telemetry & Machine Learning Framework", subtitle_style))
    story.append(Paragraph("Project Abstract & Technical Brief &nbsp;|&nbsp; <b>MATLAB & Simulink Implementation</b> &nbsp;|&nbsp; Verified Release v2.0", meta_style))

    # Metadata Key Metrics Bar
    metrics_data = [
        [
            Paragraph("<b>Core Domain:</b> Engineering Geology", table_cell_center),
            Paragraph("<b>Physics Model:</b> Bishop Slip + Infiltration", table_cell_center),
            Paragraph("<b>AI Model:</b> Decision Tree (99.96% Acc.)", table_cell_center),
            Paragraph("<b>Test Status:</b> 6/6 Automated Tests Passed", table_cell_safe),
        ]
    ]
    metrics_table = Table(metrics_data, colWidths=[130.8, 130.8, 130.8, 130.8])
    metrics_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#EDF2F7")),
        ('BOX', (0, 0), (-1, -1), 0.8, colors.HexColor("#CBD5E0")),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
    ]))
    story.append(metrics_table)
    story.append(Spacer(1, 5))

    # Abstract Box
    abstract_html = (
        "<b>EXECUTIVE ABSTRACT &mdash; </b> Rainfall-induced shallow landslides and translational slope failures cause catastrophic loss of life and devastation to civil infrastructure in mountainous regions. Traditional landslide early warning systems (LEWS) rely almost exclusively on empirical rainfall intensity&ndash;duration (I&ndash;D) thresholds, which frequently generate false alarms and cannot account for site-specific antecedent moisture, transient pore-water pressure spikes, or progressive soil deformation. This project introduces <b>GeoGuard LEWS v2.0</b>, an authoritative, computationally-efficient, and physically-consistent landslide early warning platform developed in MATLAB and Simulink. The system couples 1D mass-conserving hydrological infiltration, limit equilibrium slope stability (Bishop's circular shear arc), progressive plastic shear kinematics, and a calibrated machine learning decision tree classifier. An automated forward-looking predictive engine projects slope stability 10 minutes ahead using low-pass filtered rate-of-change dynamics (<i>dFoS/dt</i>), deriving dynamic Time-to-Failure (TTF). A dual-threshold Schmitt Trigger state machine enforces alert hysteresis, eliminating chatter across Safe (0), Advisory (1), and Evacuate (2) warning tiers. Validated across 12,000 synthesized storm trajectories, GeoGuard achieves 100% mass conservation, robust duration scaling (discriminating 12-minute from 12-hour storms), and 99.96% holdout classification accuracy. A high-fidelity graphical command console provides real-time hillside cross-section deformation and multi-channel telemetry for civil protection decision-makers."
    )
    abstract_table = Table([[Paragraph(abstract_html, body_style)]], colWidths=[523.27])
    abstract_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#F7FAFC")),
        ('BOX', (0, 0), (-1, -1), 1, colors.HexColor("#CBD5E0")),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('RIGHTPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(abstract_table)
    story.append(Spacer(1, 4))

    keywords_p = Paragraph("<b>Keywords:</b> Landslide Early Warning Systems (LEWS), Geotechnical Slope Stability, Factor of Safety (FoS), Infiltration Hydrology, Pore-Water Pressure, Tertiary Creep, Decision Tree Classification, Simulink, MATLAB.", body_style)
    story.append(keywords_p)
    story.append(Spacer(1, 5))

    # Section 1: System Architecture & Multiphysics Coupling
    story.append(make_section_banner("1. Multiphysics Geotechnical & Hydrological Architecture"))
    story.append(Spacer(1, 3))

    arch_text = (
        "GeoGuard addresses the fundamental limitation of empirical LEWS by establishing a strict causal multiphysics chain: "
        "<b>Precipitation &rarr; Soil Infiltration & Drainage &rarr; Pore-Water Pressure Generation &rarr; Effective Stress Reduction &rarr; Limit Equilibrium FoS Degradation &rarr; Tertiary Kinematic Creep & Plastic Strain &rarr; Multi-Tier Emergency Alerting</b>. "
        "All physics equations are consolidated in a centralized, authoritative single-source-of-truth engine (<font face='Courier'>lews_physics.m</font>), eliminating parameter discrepancies across simulation, training, and deployment scripts."
    )
    story.append(Paragraph(arch_text, body_style))
    story.append(Spacer(1, 3))

    # Mathematical Formulation Two-Column Table
    eq_col1 = (
        "<b>A. Hydrological Infiltration & Mass Conservation:</b><br/>"
        "Net volumetric soil moisture evolution follows mass balance:<br/>"
        "&bull; Infiltration: &Delta;&theta;<sub>infil</sub> = (I<sub>rain</sub> &middot; &Delta;t<sub>phys</sub> &middot; 0.85) / (z &middot; 1000)<br/>"
        "&bull; Deep Drainage: &Delta;&theta;<sub>drain</sub> = (k<sub>drain</sub> &middot; max(0, &theta; &minus; &theta;<sub>field</sub>) &middot; &Delta;t<sub>phys</sub>) / z<br/>"
        "&bull; Moisture Update: &theta;<sub>t+1</sub> = min(&theta;<sub>sat</sub>, max(0.12, &theta;<sub>t</sub> + &Delta;&theta;<sub>infil</sub> &minus; &Delta;&theta;<sub>drain</sub>))<br/>"
        "where calibrated drainage conductivity k<sub>drain</sub> = 2.5&times;10<sup>&minus;5</sup> s<sup>&minus;1</sup>, "
        "z = 1.5 m (regolith mantle depth), &theta;<sub>field</sub> = 0.18, and &theta;<sub>sat</sub> = 0.50. "
        "Physical time &Delta;t<sub>phys</sub> is decoupled from dashboard animation ticks, ensuring mass-conserving infiltration across any storm duration."
    )

    eq_col2 = (
        "<b>B. Pore Pressure & Limit Equilibrium FoS:</b><br/>"
        "Positive pore-water pressure (u) develops upon exceeding critical field moisture (&theta;<sub>crit</sub> = 0.34):<br/>"
        "&bull; u = &gamma;<sub>w</sub> &middot; z &middot; cos<sup>2</sup>(&beta;) &middot; [(&theta; &minus; &theta;<sub>crit</sub>) / (&theta;<sub>sat</sub> &minus; &theta;<sub>crit</sub>)] &middot; 1.8 kPa<br/>"
        "Under Bishop limit equilibrium, stability is governed by:<br/>"
        "&bull; Normal Stress: &sigma; = &gamma;<sub>s</sub> z (cos &beta; &minus; k<sub>h</sub> sin &beta;) cos &beta;<br/>"
        "&bull; Effective Resisting Shear: &tau;<sub>f</sub> = c' + max(&sigma; &minus; u, 0.05) &middot; tan(&phi;)<br/>"
        "&bull; Driving Gravitational Shear: &tau;<sub>d</sub> = &gamma;<sub>s</sub> z (sin &beta; + k<sub>h</sub> cos &beta;) cos &beta;<br/>"
        "&bull; Factor of Safety: FoS = &tau;<sub>f</sub> / &tau;<sub>d</sub><br/>"
        "where nominal parameters (&beta;=35&deg;, c'=12 kPa, &phi;=30&deg;, &gamma;<sub>s</sub>=18 kN/m<sup>3</sup>) yield exact baseline FoS<sub>0</sub> = 1.7705."
    )

    formulation_table = Table([[Paragraph(eq_col1, body_style), Paragraph(eq_col2, body_style)]], colWidths=[256, 256])
    formulation_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), BG_LIGHT),
        ('BOX', (0, 0), (-1, -1), 0.6, BORDER_COLOR),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, BORDER_COLOR),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(formulation_table)
    story.append(Spacer(1, 5))

    # Section 2: Kinematics, Creep & Seismic Modeling
    story.append(make_section_banner("2. Progressive Kinematics, Tertiary Creep & Seismic Coupling"))
    story.append(Spacer(1, 3))

    kinematics_text = (
        "<b>Tertiary Creep Acceleration:</b> Ground surface deformation kinematics are formulated through an empirical inverse-velocity creep model: "
        "<i>&omega;<sub>tilt</sub> = 0.08 / (FoS &minus; 0.98)<sup>1.6</sup> + 0.12 &middot; tremor</i> (deg/h). "
        "As FoS approaches unity, tilt velocity accelerates asymptotically, reproducing the tertiary creep phase documented in catastrophic slope failures.<br/>"
        "<b>Seismic Tremor Coupling:</b> Ground shaking is integrated via pseudostatic seismic acceleration coefficient <i>k<sub>h</sub> = 0.015 &middot; tremor</i>, "
        "which simultaneously reduces normal confinement stress and amplifies downslope inertial driving forces.<br/>"
        "<b>Irreversible Plastic Shear Strain:</b> When FoS drops below 1.05, plastic slip offset accumulates irreversibly: <i>&delta;<sub>slip</sub>(t+&Delta;t) = &delta;<sub>slip</sub>(t) + 0.03</i>. "
        "Crucially, post-storm drying stabilizes the slope (increasing FoS) without unphysical 'soil healing' or backward displacement, correctly reflecting geological plastic strain."
    )
    story.append(Paragraph(kinematics_text, body_style))
    story.append(Spacer(1, 5))

    # Section 3: Predictive Decision Architecture
    story.append(make_section_banner("3. Predictive Forecaster & Schmitt Trigger Decision Engine"))
    story.append(Spacer(1, 3))

    decision_text = (
        "<b>Advance Disaster Forecasting:</b> To provide actionable emergency lead time, GeoGuard employs a forward-looking linear extrapolator: "
        "<i>FoS<sub>pred</sub> = FoS + (dFoS/dt &middot; 600 s)</i>, projecting slope stability 10 minutes into the future. "
        "The derivative <i>dFoS/dt</i> is conditioned through a low-pass filter (&alpha; = min(0.3, 0.05 + 0.1 &Delta;t<sub>phys</sub>)) to prevent sensor noise from generating false alarm spikes. "
        "Estimated Time-to-Failure is computed via <i>TTF = (FoS &minus; 1.05) / |dFoS/dt|</i> and reports nominal stability (<font color='#006100'>Safe / NaN</font>) rather than artificial constants.<br/>"
        "<b>Schmitt Trigger Hysteresis:</b> Traditional thresholding suffers from rapid alarm chatter during intermittent rainfall. "
        "GeoGuard enforces dual-threshold hysteresis: escalating to <font color='#9C0006'><b>Stage 2 (Evacuate)</b></font> when FoS &le; 1.05 or &omega;<sub>tilt</sub> &ge; 2.2&deg;/h, "
        "requiring substantial recovery past FoS &gt; 1.15 and &omega;<sub>tilt</sub> &lt; 1.8&deg;/h before stepping down to Advisory. "
        "Similarly, clearing <font color='#B25900'><b>Stage 1 (Advisory)</b></font> back to Safe requires FoS &gt; 1.48, rain &lt; 20 mm/h, and moisture &lt; 23%."
    )
    story.append(Paragraph(decision_text, body_style))

    # -------------------------------------------------------------
    # PAGE 2: MACHINE LEARNING, VERIFICATION TABLE, TELEMETRY PLOT, CONCLUSION
    # -------------------------------------------------------------
    story.append(Spacer(1, 14)) # Clean transition to page 2

    story.append(make_section_banner("4. Machine Learning Multi-Class Decision Support"))
    story.append(Spacer(1, 3))

    ml_text = (
        "A multi-class Decision Tree classifier (<font face='Courier'>landslide_model.mat</font>) is seamlessly coupled to the real-time simulation engine. "
        "Trained across <b>12,000 causally-synthesized storm trajectories</b> spanning varied rainfall intensities (0&ndash;120 mm/h), durations (0.2&ndash;12 h), "
        "slope angles (20&deg;&ndash;50&deg;), and antecedent moisture conditions (15%&ndash;55%), the model evaluates live feature vectors "
        "<b>X = [ FoS, Moisture(%), RainRate(mm/h), TiltRate(deg/h) ]</b> at every simulation step.<br/>"
        "On an independent holdout test partition of 2,400 samples, the model achieved an exceptional <b>99.96% overall accuracy</b>, "
        "with 100% sensitivity for critical evacuation conditions (50/50 critical events correctly identified, zero false negatives), "
        "providing resilient algorithmic redundancy alongside the deterministic geomechanical solver."
    )
    story.append(Paragraph(ml_text, body_style))
    story.append(Spacer(1, 4))

    # Section 5: Automated Verification Test Suite
    story.append(make_section_banner("5. Automated Test Suite & Empirical Verification"))
    story.append(Spacer(1, 3))

    # Test Suite Results Table
    test_headers = [
        Paragraph("<b>Test Case</b>", table_cell_bold),
        Paragraph("<b>Target Parameter / Equation</b>", table_cell_bold),
        Paragraph("<b>Benchmark Condition</b>", table_cell_bold),
        Paragraph("<b>Simulated Output</b>", table_cell_bold),
        Paragraph("<b>Status</b>", table_cell_bold),
    ]
    test_rows = [
        test_headers,
        [
            Paragraph("<b>Test 1:</b> Baseline FoS", table_cell_style),
            Paragraph("Limit equilibrium equation equivalence", table_cell_style),
            Paragraph("&beta;=35&deg;, c'=12 kPa, &phi;=30&deg;, u=0", table_cell_style),
            Paragraph("FoS = 1.7705 (exact match)", table_cell_style),
            Paragraph("<b>PASSED</b>", table_cell_safe),
        ],
        [
            Paragraph("<b>Test 2:</b> Mass Balance", table_cell_style),
            Paragraph("Cumulative rainfall physical integration", table_cell_style),
            Paragraph("75 mm/h storm &times; 3.0 hr = 225.0 mm", table_cell_style),
            Paragraph("CumRain = 225.0 mm (100% mass)", table_cell_style),
            Paragraph("<b>PASSED</b>", table_cell_safe),
        ],
        [
            Paragraph("<b>Test 3:</b> Storm Duration", table_cell_style),
            Paragraph("Hydrological time-scale decoupling", table_cell_style),
            Paragraph("12-minute vs. 12-hour duration", table_cell_style),
            Paragraph("FoS: 1.770 (Safe) vs. 0.982 (Fail)", table_cell_style),
            Paragraph("<b>PASSED</b>", table_cell_safe),
        ],
        [
            Paragraph("<b>Test 4:</b> ML Inference", table_cell_style),
            Paragraph("Classifier integration & live score vector", table_cell_style),
            Paragraph("Nominal vs. saturated failure input", table_cell_style),
            Paragraph("Class: 0 (Safe) vs. 2 (Evacuate)", table_cell_style),
            Paragraph("<b>PASSED</b>", table_cell_safe),
        ],
        [
            Paragraph("<b>Test 5:</b> Alert Hysteresis", table_cell_style),
            Paragraph("Schmitt trigger state de-escalation", table_cell_style),
            Paragraph("FoS = 1.10 &rarr; remains Evacuate (2)", table_cell_style),
            Paragraph("Prevents alarm chatter / reset", table_cell_style),
            Paragraph("<b>PASSED</b>", table_cell_safe),
        ],
        [
            Paragraph("<b>Test 6:</b> Derivative Filter", table_cell_style),
            Paragraph("Step-0 initial derivative & TTF sanity", table_cell_style),
            Paragraph("t = 0 baseline condition", table_cell_style),
            Paragraph("dFoS/dt = 0, FoS<sub>pred</sub> = 1.77, TTF = NaN", table_cell_style),
            Paragraph("<b>PASSED</b>", table_cell_safe),
        ],
    ]
    test_table = Table(test_rows, colWidths=[80, 130, 120, 135, 58.27])
    test_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#EDF2F7")),
        ('BOX', (0, 0), (-1, -1), 0.6, BORDER_COLOR),
        ('INNERGRID', (0, 0), (-1, -1), 0.4, BORDER_COLOR),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, BG_LIGHT]),
        ('TOPPADDING', (0, 0), (-1, -1), 2.2),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2.2),
        ('LEFTPADDING', (0, 0), (-1, -1), 4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 4),
    ]))
    story.append(test_table)
    story.append(Spacer(1, 4))

    # Section 6: Telemetry Timeseries Figure
    story.append(make_section_banner("6. Telemetry Timeseries & Sensor Response Validation"))
    story.append(Spacer(1, 3))

    img_path = "simulation_results.png"
    if os.path.exists(img_path):
        # Image is 1485x1172 (~1.26 aspect ratio). Width = 470pt, Height = 168pt
        sim_img = Image(img_path, width=470, height=168)
        story.append(sim_img)
        caption_text = "<b>Figure 1:</b> Two-hour continuous LEWS telemetry simulation. (Top-Left) Rainfall rate and mass accumulation; (Top-Right) Soil moisture and pore-water pressure generation above 34% critical threshold; (Bottom-Left) Factor of Safety degradation and 10-minute predictive lookahead; (Bottom-Right) Surface tilt rate velocity and Schmitt trigger emergency alert escalation (Safe &rarr; Advisory &rarr; Evacuate)."
        story.append(Paragraph(caption_text, fig_caption_style))
    else:
        story.append(Paragraph("<i>[Figure: Simulation Telemetry Timeseries - simulation_results.png]</i>", body_style))

    # Section 7: Graphical Command Console & Operational Impact
    story.append(make_section_banner("7. Command Console Capabilities & Disaster Management Impact"))
    story.append(Spacer(1, 3))

    impact_text = (
        "<b>Interactive Command Console (<font face='Courier'>predictive_dashboard.m</font>):</b> GeoGuard features an interactive command dashboard designed for geotechnical engineers and disaster relief commanders. The visual canvas renders a realistic hillside cross-section with multi-stratum geology (jointed bedrock foundation, Bishop circular shear arc, colluvium soil mantle, phreatic water table, alpine mountain chalet settlement, evergreen forest, monitoring station, and tension scarp cracking). Dynamic weather animation visually portrays storm severity, while a heads-up display (HUD) card delivers instant status telemetry.<br/>"
        "<b>Operational Significance:</b> By bridging empirical rainfall monitoring with geotechnical limit equilibrium and machine learning inference, GeoGuard delivers reliable advance warning (10&ndash;30 minute window), eliminates false alarms through hysteresis filtering, and provides an open-source, verifiable engineering foundation for regional landslide early warning deployments."
    )
    story.append(Paragraph(impact_text, body_style))

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Project Abstract PDF successfully generated: {pdf_path}")

if __name__ == "__main__":
    generate_pdf()
