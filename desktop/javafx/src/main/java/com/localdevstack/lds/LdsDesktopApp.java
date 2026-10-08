package com.localdevstack.lds;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import javafx.application.Application;
import javafx.application.Platform;
import javafx.scene.Parent;
import javafx.beans.property.SimpleStringProperty;
import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import javafx.geometry.Insets;
import javafx.scene.Scene;
import javafx.scene.control.Button;
import javafx.scene.control.CheckBox;
import javafx.scene.control.Label;
import javafx.scene.control.ScrollPane;
import javafx.scene.control.Tab;
import javafx.scene.control.TabPane;
import javafx.scene.control.TableColumn;
import javafx.scene.control.TableView;
import javafx.scene.control.TextArea;
import javafx.scene.control.TextField;
import javafx.scene.control.ToggleButton;
import javafx.scene.layout.FlowPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.Priority;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;

import java.awt.SystemTray;
import java.awt.TrayIcon;
import java.awt.PopupMenu;
import java.awt.MenuItem;
import java.awt.AWTException;
import java.awt.event.ActionEvent;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * LDS Desktop (JavaFX) — the learning sibling of the Tauri variant in
 * {@code desktop/}. Same features, same "thin shell over the lds CLI" design,
 * different toolkit: this one is Java + JavaFX, run with {@code mvn javafx:run}.
 */
public class LdsDesktopApp extends Application {

    private final LdsCli cli = new LdsCli();
    private final ObjectMapper json = new ObjectMapper();

    // UI pieces that background tasks need to update (Platform.runLater).
    private TableView<ContainerRow> statusTable;
    private final ObservableList<ContainerRow> statusRows = FXCollections.observableArrayList();
    private TextArea logArea;
    private TextArea outputArea;
    private Label statusDot;
    private Label lastUpdated;
    private CheckBox autoRefresh;
    private Button streamBtn;
    private Button stopBtn;
    private Stage stage;

    // Auto-refresh: a daemon scheduler pokes refreshStatus() every 5s; the
    // AtomicBoolean guard drops overlapping runs (slow docker responses).
    private static final long AUTO_REFRESH_SECONDS = 5;
    private ScheduledExecutorService scheduler;
    private final AtomicBoolean refreshing = new AtomicBoolean(false);

    // Live log stream (docker compose logs --follow child process).
    private Process logStream;

    private static final String[] PROFILES = {
            "proxy", "mysql", "postgres", "mongo", "redis",
            "duckdb", "trino", "analytics", "tasks", "wiki",
            "semgrep", "zap", "trivy", "crg", "vaultwarden", "mail",
            "instatic", "erpnext", "playwright", "headlessx", "kafka"
    };

    /** label -> url (mirrors docs/en/12-ports.md) */
    private static final String[][] TOOLS = {
            {"phpCacheAdmin", "http://localhost:4500"},
            {"DBGate", "http://localhost:4501"},
            {"DrawDB", "http://localhost:4502"},
            {"Apache Hop", "http://localhost:4503"},
            {"Superset", "http://localhost:4504"},
            {"Metabase", "http://localhost:4541"},
            {"Hoppscotch", "http://localhost:4542"},
            {"Plane", "http://localhost:4543"},
            {"Semgrep", "http://localhost:4505"},
            {"Vaultwarden", "http://localhost:4506"},
            {"OpenWA", "http://localhost:4507"},
            {"RustFS", "http://localhost:4508"},
            {"ZAP", "http://localhost:4510"},
            {"Trivy", "http://localhost:4511"},
            {"Mailpit", "http://localhost:4513"},
            {"Penpot", "http://localhost:4515"},
            {"Analytics", "http://localhost:4520"},
            {"Tasks", "http://localhost:4522"},
            {"Wiki", "http://localhost:4524"},
            {"Playwright", "http://localhost:4526"},
            {"Instatic", "http://localhost:4528"},
            {"ERPNext", "http://localhost:4529"},
            {"code-review-graph", "http://localhost:4530"},
            {"Trino", "http://localhost:4451"},
            {"Dashboard", "http://localhost"},
    };

    // ------------------------------------------------------------------
    // Entry point
    // ------------------------------------------------------------------

    public static void main(String[] args) {
        launch(args);
    }

    @Override
    public void start(Stage stage) {
        this.stage = stage;
        stage.setTitle("LDS Desktop (JavaFX)");
        stage.setScene(new Scene(buildRoot(), 1080, 720));

        // Tray: keep the app alive when the window closes.
        if (SystemTray.isSupported()) {
            addTrayIcon();
        }

        stage.show();
        refreshStatus();
        startAutoRefresh();
        Runtime.getRuntime().addShutdownHook(new Thread(this::killLogStream,
                "lds-log-stream-cleanup"));
    }

    /** Run a blocking CLI call off the UI thread, then land the result back on it. */
    private void runAsync(String label, CliCall call) {
        appendOutput("$ " + label);
        CompletableFuture.runAsync(() -> {
            try {
                String result = call.run();
                Platform.runLater(() -> appendOutput(result));
            } catch (Exception e) {
                Platform.runLater(() -> appendOutput("ERROR: " + e.getMessage()));
            }
        });
    }

    private interface CliCall {
        String run() throws Exception;
    }

    // ------------------------------------------------------------------
    // UI construction
    // ------------------------------------------------------------------

    private Parent buildRoot() {
        VBox root = new VBox(10);
        root.setPadding(new Insets(12));

        // --- header ---------------------------------------------------
        HBox header = new HBox(8);
        statusDot = new Label("●");
        statusDot.setStyle("-fx-text-fill: #64748b; -fx-font-size: 16px;");
        lastUpdated = new Label("");
        lastUpdated.setStyle("-fx-text-fill: #94a3b8; -fx-font-size: 11px;");
        autoRefresh = new CheckBox("Auto-refresh");
        autoRefresh.setSelected(true);
        Button refresh = new Button("⟳ Refresh");
        refresh.setOnAction(e -> refreshStatus());
        Button hostsSync = new Button("hosts-sync");
        hostsSync.setOnAction(e -> runAsync("lds hosts-sync", () -> cli.hostsSync()));
        Button upAll = new Button("Start all");
        upAll.setOnAction(e -> runAsync("lds up all", () -> cli.lds("up", "all")));
        Button downAll = new Button("Stop all");
        downAll.setOnAction(e -> runAsync("lds down", () -> cli.lds("down")));
        header.getChildren().addAll(statusDot, lastUpdated, autoRefresh, refresh,
                hostsSync, upAll, downAll);

        // --- tabs -----------------------------------------------------
        TabPane tabs = new TabPane();
        tabs.getTabs().addAll(
                new Tab("Lifecycle", lifecycleTab()),
                new Tab("Profiles", profilesTab()),
                new Tab("Tools", toolsTab()),
                new Tab("Containers", statusTab()),
                new Tab("Logs", logsTab()),
                new Tab("Output", outputTab())
        );
        VBox.setVgrow(tabs, Priority.ALWAYS);

        root.getChildren().addAll(header, tabs);
        return root;
    }

    private Parent lifecycleTab() {
        FlowPane pane = new FlowPane(8, 8);
        addButton(pane, "lds start", () -> cli.lds("start"));
        addButton(pane, "lds stop", () -> cli.lds("stop"));
        addButton(pane, "lds down", () -> cli.lds("down"));
        addButton(pane, "lds ps", () -> cli.lds("ps"));
        addButton(pane, "lds logs", () -> cli.lds("logs"));
        addButton(pane, "certs", () -> cli.lds("certs"));
        addButton(pane, "db init all", () -> cli.lds("db", "init", "all"));
        return pane;
    }

    private Parent profilesTab() {
        FlowPane pane = new FlowPane(8, 8);
        for (String p : PROFILES) {
            ToggleButton chip = new ToggleButton(p);
            chip.setOnAction(e -> {
                boolean up = chip.isSelected();
                String op = up ? "up" : "down";
                runAsync("lds " + op + " " + p, () -> cli.lds(op, p));
            });
            pane.getChildren().add(chip);
        }
        return pane;
    }

    private Parent toolsTab() {
        FlowPane pane = new FlowPane(8, 8);
        for (String[] tool : TOOLS) {
            Button card = new Button(tool[0]);
            String url = tool[1];
            card.setOnAction(e -> {
                try {
                    cli.openUrl(url);
                } catch (Exception ex) {
                    appendOutput("ERROR opening " + url + ": " + ex.getMessage());
                }
            });
            card.setTooltip(new javafx.scene.control.Tooltip(url));
            pane.getChildren().add(card);
        }
        return pane;
    }

    private Parent statusTab() {
        statusTable = new TableView<>(statusRows);
        statusTable.setColumnResizePolicy(TableView.CONSTRAINED_RESIZE_POLICY);

        TableColumn<ContainerRow, String> service = new TableColumn<>("Service");
        service.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().service));

        TableColumn<ContainerRow, String> name = new TableColumn<>("Container");
        name.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().name));

        TableColumn<ContainerRow, String> state = new TableColumn<>("State");
        state.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().state));

        TableColumn<ContainerRow, String> health = new TableColumn<>("Health");
        health.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().health));

        TableColumn<ContainerRow, String> status = new TableColumn<>("Status");
        status.setCellValueFactory(c -> new SimpleStringProperty(c.getValue().status));

        statusTable.getColumns().addAll(service, name, state, health, status);
        return statusTable;
    }

    private Parent logsTab() {
        VBox box = new VBox(8);

        HBox row = new HBox(8);
        TextField service = new TextField("redis");
        service.setPromptText("service");
        TextField lines = new TextField("200");
        lines.setPrefWidth(70);
        streamBtn = new Button("Stream");
        streamBtn.setStyle("-fx-background-color: #0c4a6e; -fx-text-fill: white;");
        stopBtn = new Button("Stop");
        stopBtn.setDisable(true);
        Button tail = new Button("Tail");
        Button clear = new Button("Clear");
        clear.setOnAction(e -> logArea.clear());
        streamBtn.setOnAction(e -> {
            String svc = service.getText().trim();
            if (svc.isEmpty()) return;
            final int n = parseOrDefault(lines.getText().trim(), 200);
            startLogStream(svc, n);
        });
        stopBtn.setOnAction(e -> stopLogStream());
        tail.setOnAction(e -> {
            String svc = service.getText().trim();
            if (svc.isEmpty()) return;
            final int n = parseOrDefault(lines.getText().trim(), 200);
            runAsync("docker compose logs --tail " + n + " " + svc, () -> cli.serviceLogs(svc, n));
        });
        row.getChildren().addAll(service, lines, streamBtn, stopBtn, tail, clear);

        logArea = new TextArea();
        logArea.setEditable(false);
        logArea.setStyle("-fx-font-family: monospace; -fx-font-size: 11px;");
        VBox.setVgrow(logArea, Priority.ALWAYS);

        box.getChildren().addAll(row, logArea);
        return box;
    }

    private Parent outputTab() {
        outputArea = new TextArea();
        outputArea.setEditable(false);
        outputArea.setStyle("-fx-font-family: monospace; -fx-font-size: 11px;");
        return outputArea;
    }

    private void addButton(FlowPane pane, String text, CliCall call) {
        Button b = new Button(text);
        b.setOnAction(e -> runAsync(text, call));
        pane.getChildren().add(b);
    }

    private static int parseOrDefault(String s, int def) {
        try {
            return Integer.parseInt(s.trim());
        } catch (NumberFormatException e) {
            return def;
        }
    }

    private void appendOutput(String text) {
        if (outputArea != null) {
            outputArea.appendText(text + "\n");
        }
    }

    // ------------------------------------------------------------------
    // Status refresh (background)
    // ------------------------------------------------------------------

    private void refreshStatus() {
        if (!refreshing.compareAndSet(false, true)) return; // drop overlapping runs
        try {
            CompletableFuture.runAsync(() -> {
                try {
                    String raw = cli.stackStatusJson();
                    JsonNode rows = json.readTree(raw);
                    List<ContainerRow> parsed = new java.util.ArrayList<>();
                    boolean allRunning = true;
                    boolean any = false;
                    for (JsonNode r : rows) {
                        ContainerRow row = new ContainerRow(
                                r.path("Service").asText(""),
                                r.path("Name").asText(""),
                                r.path("State").asText(""),
                                r.path("Health").asText(""),
                                r.path("Status").asText(""));
                        parsed.add(row);
                        any = true;
                        if (!"running".equals(row.state)) allRunning = false;
                    }
                    boolean finalAllRunning = allRunning;
                    boolean finalAny = any;
                    Platform.runLater(() -> {
                        statusRows.setAll(parsed);
                        lastUpdated.setText("updated " + java.time.LocalTime.now().withNano(0));
                        if (!finalAny) {
                            statusDot.setText("●");
                            statusDot.setStyle("-fx-text-fill: #f87171;");
                        } else if (finalAllRunning) {
                            statusDot.setText("●");
                            statusDot.setStyle("-fx-text-fill: #34d399;");
                        } else {
                            statusDot.setText("●");
                            statusDot.setStyle("-fx-text-fill: #fbbf24;");
                        }
                    });
                } catch (Exception e) {
                    Platform.runLater(() -> appendOutput("ERROR: " + e.getMessage()));
                } finally {
                    refreshing.set(false);
                }
            });
        } catch (Exception e) {
            refreshing.set(false);
        }
    }

    // ------------------------------------------------------------------
    // Auto-refresh + live log streaming
    // ------------------------------------------------------------------

    private void startAutoRefresh() {
        scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "lds-status-refresh");
            t.setDaemon(true);
            return t;
        });
        scheduler.scheduleWithFixedDelay(() -> {
            if (autoRefresh != null && autoRefresh.isSelected()) {
                refreshStatus();
            }
        }, AUTO_REFRESH_SECONDS, AUTO_REFRESH_SECONDS, TimeUnit.SECONDS);
    }

    /** Live-follow a service: docker compose logs --tail N --follow <service>. */
    private void startLogStream(String svc, int n) {
        stopLogStream(); // switching services stops the previous stream
        Process p;
        try {
            p = cli.streamLogs(svc, n);
        } catch (IOException e) {
            appendOutput("ERROR: " + e.getMessage());
            return;
        }
        logStream = p;
        logArea.clear();
        logArea.appendText("$ docker compose logs --tail " + n + " --follow " + svc + "\n");
        setStreamingUi(true);

        BufferedReader reader = new BufferedReader(
                new InputStreamReader(p.getInputStream(), StandardCharsets.UTF_8));
        Thread readerThread = new Thread(() -> {
            try {
                String line;
                while ((line = reader.readLine()) != null) {
                    final String l = line;
                    Platform.runLater(() -> {
                        logArea.appendText(l + "\n");
                        logArea.positionCaret(logArea.getLength()); // scroll to bottom
                    });
                }
            } catch (IOException ignored) {
                // stream killed — normal on Stop
            } finally {
                try {
                    Platform.runLater(() -> {
                        logArea.appendText("\n[log stream ended]\n");
                        setStreamingUi(false);
                    });
                } catch (Exception ignored) {
                    // app shutting down
                }
            }
        }, "lds-log-reader");
        readerThread.setDaemon(true);
        readerThread.start();
    }

    /** Kill the stream child only (no UI) — safe for the shutdown hook. */
    private void killLogStream() {
        if (logStream != null) {
            logStream.destroy();
            try {
                logStream.waitFor(2, TimeUnit.SECONDS);
            } catch (InterruptedException ignored) {
                Thread.currentThread().interrupt();
            }
            logStream = null;
        }
    }

    private void stopLogStream() {
        killLogStream();
        setStreamingUi(false);
    }

    private void setStreamingUi(boolean on) {
        if (streamBtn != null) {
            streamBtn.setDisable(on);
            streamBtn.setText(on ? "Streaming…" : "Stream");
        }
        if (stopBtn != null) stopBtn.setDisable(!on);
    }

    // ------------------------------------------------------------------
    // System tray (AWT)
    // ------------------------------------------------------------------

    private void addTrayIcon() {
        PopupMenu menu = new PopupMenu();
        MenuItem open = new MenuItem("Open LDS Desktop");
        open.addActionListener(e -> Platform.runLater(() -> stage.show()));
        MenuItem up = new MenuItem("Start all profiles");
        up.addActionListener(e -> CompletableFuture.runAsync(() -> {
            try { cli.lds("up", "all"); } catch (Exception ignored) {}
        }));
        MenuItem down = new MenuItem("Stop all");
        down.addActionListener(e -> CompletableFuture.runAsync(() -> {
            try { cli.lds("down"); } catch (Exception ignored) {}
        }));
        MenuItem quit = new MenuItem("Quit");
        quit.addActionListener(e -> Platform.exit());
        menu.add(open);
        menu.addSeparator();
        menu.add(up);
        menu.add(down);
        menu.addSeparator();
        menu.add(quit);

        TrayIcon icon = new TrayIcon(
                java.awt.Toolkit.getDefaultToolkit().createImage(
                        getClass().getResource("/lds-tray.png")), "LDS Desktop", menu);
        icon.setImageAutoSize(true);
        icon.addActionListener(e -> Platform.runLater(() -> stage.show()));

        try {
            SystemTray.getSystemTray().add(icon);
        } catch (AWTException e) {
            appendOutput("WARN: tray unavailable: " + e.getMessage());
        }
    }

    /** One row of {@code docker compose ps}. */
    private static final class ContainerRow {
        final String service, name, state, health, status;
        ContainerRow(String service, String name, String state, String health, String status) {
            this.service = service;
            this.name = name;
            this.state = state;
            this.health = health;
            this.status = status;
        }
    }
}
